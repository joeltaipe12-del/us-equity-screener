# US Equity Screener

A five-factor screener and backtest over the S&P 100, 2020–2025.

**Stack:** Python · PostgreSQL · DBeaver · Tableau · Excel

**[→ Live dashboard on Tableau Public](https://public.tableau.com/app/profile/joel.taipe/viz/USEquityScreener/Screener)**

---

## What this is

This is a project about factor investing — the school of investing that says
you can predict which shares do well based on measurable traits rather than on
opinion. The five traits I used are the standard ones:

- **Value** — cheap shares beat expensive ones over time
- **Quality** — profitable companies with sensible debt beat weak ones
- **Momentum** — shares that have been going up tend to keep going up
- **Risk** — steady shares often do better than volatile ones
- **Growth** — companies growing sales faster

The question is whether that actually works. So I scored and ranked the
biggest US companies on all five, bought the best ten, and saw what happened.

## The question

If you rank the largest US companies on five measurable traits and buy the top
ten, would you have beaten the market?

## The five factors

Each factor is scored 1–10 using `NTILE(10)`, which splits the universe into
deciles. A score is a rank relative to the S&P 100, not an absolute judgement
— a value score of 10 means "cheapest tenth of the S&P 100", not "cheap".

| Factor | What I measured | Scores high when |
|---|---|---|
| Value | P/E decile and P/B decile, averaged | Cheap |
| Quality | Return on equity | Profitable on shareholder capital |
| Momentum | Rolling 12-month return | Rising |
| Risk | 12-month volatility decile and max drawdown decile, averaged | Steady |
| Growth | Revenue CAGR | Growing sales |

Several of these sort the other way round — low P/E, low volatility and a
shallow drawdown are the good ends. Getting one backwards gives you a ranking
that looks completely plausible and is completely wrong. That happened to me:
the volatility sort was the wrong way until I caught it.

The composite is the plain average of the five, then `RANK()` descending.
**Equal weights on purpose.** There's nothing in this data that says one factor
deserves more weight than another, and picking weights that make the backtest
look better is just fitting the model to the past. Equal weighting was also
what my mentor Ning recommended as the honest baseline.

---

## How I built it

### 1. Getting the data

I used the S&P 100 as the universe — a fixed list of the 100 largest US firms.
I got the constituent list from the iShares OEF ETF holdings file and cleaned
it into `universe.csv`. That gave me 101 tickers, not 100, because a couple of
companies are listed twice — Google is the same company in two share classes.
Add SPY as the benchmark and it's 102 tickers in total.

Then I built the Python pipeline. yfinance is a free Python library that pulls
market data through an API, so I looped through the 102 tickers and asked for
two things each:

- **Prices** — monthly closing prices, 2020 to 2025
- **Fundamentals** — four years of annual accounts: revenue, earnings, equity,
  debt, assets

That comes out as raw CSVs, which then go into PostgreSQL.

### 2. Staging, and loading the data dirty

Before anything went into the real tables I staged it. I created staging
tables and loaded the CSVs in **untouched** — no cleaning on the way in.

That's deliberate. If you clean the data as you load it, you can't see what
you actually received. You want to find out what's wrong with it *after* it's
in the database, where you can query it, not before, where you're guessing.

Then I ran nine checks: row counts, price coverage, fiscal-year consistency,
cross-table agreement, date ranges, nulls, impossible values and outlier
returns.

### 3. What the checks found

**Short price histories.** GE Vernova had 22 months and Palantir had 64,
instead of the full period. Both joined the index recently. If you average a
22-month return against a 72-month one, the comparison is meaningless — so
these are excluded at the portfolio stage rather than silently averaged in
(see step 7).

**Negative equity.** 28 rows across 9 companies: Philip Morris, Altria,
McDonald's, Starbucks, Boeing, Booking, Oracle, AbbVie and Lowe's. Equity is
assets minus liabilities — what shareholders own on paper — and it goes
negative when a company borrows to buy back its own shares year after year.
These companies aren't broken. But ROE is profit divided by equity, and
dividing by a negative number gives you a negative ROE for a company that is
doing fine. The *ratio* is broken, not the business.

**Exploding P/B.** Colgate's price-to-book came out at 1,172, same cause —
book equity near zero, so the ratio explodes.

None of these were bugs. They're real properties of real companies, and they
quietly corrupt the scores if you don't catch them. Finding them is what the
checks were for.

The fix is a guard on every ratio, so a broken input produces `NULL` rather
than a plausible-looking wrong number:

```sql
-- 07_3_fact_ratios.sql (excerpt)
case when
	fl.eps > 0 then pl.close_price / fl.eps
	else null end as pe_ratio,
case when
	fl.total_equity > 0 then (fl.net_income / fl.total_equity)
	else null
	end as roe,
case when
	fl.total_equity > 0 and fl.eps > 0 and fl.net_income > 0
    then (pl.close_price * fl.net_income) / (fl.total_equity * fl.eps)
    else null
	end as pb_ratio
```

P/B has no book-value-per-share column to work from, so it's derived:
price × net income over equity × EPS gives the same ratio out of the columns I
actually had.

### 4. The star schema

Then I reshaped the raw tables into a standard warehouse design.

**Dimension tables** describe things:
- `dim_company` — one row per company: ticker, name, sector
- `dim_date` — one row per date: year, month, quarter

**Fact tables** record measurements:
- `fact_prices` — one row per company per month
- `fact_fundamentals` — one row per company per year

Facts point at dimensions by an ID number rather than by name, which keeps the
joins clean and makes referencing different parts of the model easier.

### 5. Turning prices into signals

This is where the window functions come in — what the prices actually tell
you.

**Monthly return** — each month compared to the one before, using `LAG()`:

```sql
-- 06_1_monthly_return.sql
with returns as (
select
	ticker_id,
	date_id,
	(fp.close_price/ lag(fp.close_price) over(partition by ticker_id order by date_id)) - 1 as
	new_returns
	from fact_prices fp
)
update fact_prices fp
set monthly_turn = r.new_returns
from returns r
where fp.ticker_id = r.ticker_id
and fp.date_id = r.date_id;
```

**Drawdown** — how far below the previous peak. This compounds the returns
with a log-sum (adding logs is the same as multiplying the returns, and it
doesn't drift), tracks the running peak with `MAX()`, then measures the gap:

```sql
-- 06_4_drawdown.sql
with cumulative as (
		select
			ticker_id,
			date_id ,
			exp(sum(ln(monthly_turn + 1)) over (
				partition by ticker_id
				order by date_id
			 	ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT row
		)) as cum_return
	from fact_prices fp
	where monthly_turn is not null
),
peak as (
	select
			ticker_id,
			date_id,
			cum_return,
			max(cum_return) over (
				partition by ticker_id
				order by date_id
			 	ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT row
			 ) as running_peak
			from cumulative
),
dd as (
	select
        ticker_id,
        date_id,
        (cum_return / running_peak) - 1 AS new_drawdown
    FROM peak
)
UPDATE fact_prices fp
SET drawdown = dd.new_drawdown
FROM dd
WHERE fp.ticker_id = dd.ticker_id
  AND fp.date_id = dd.date_id;
```

Rolling 12-month return and 12-month volatility follow the same pattern and
feed momentum and risk.

### 6. Scoring and ranking

`NTILE(10)` on each measure to rank every company out of 10.

The risk score is the one worth showing, because it combines two measures and
both have to sort the right way — volatility `DESC` so the calmest companies
land in decile 10, drawdown `ASC` on the minimum so the shallowest land in
decile 10:

```sql
-- 08_5_risk_score.sql
with vol_deciles as (
	select
		fp.ticker_id,
		ntile(10) OVER (ORDER BY fp.volatility_12m DESC) AS vol_decile
   	 FROM fact_prices fp
    	JOIN dim_company dc ON fp.ticker_id = dc.ticker_id
    	WHERE fp.date_id = (SELECT MAX(date_id) FROM fact_prices)
      	AND dc.is_benchmark = FALSE
      	AND fp.volatility_12m IS NOT null
),
max_dd as (
	select
		fp.ticker_id,
		min(fp.drawdown) as max_drawdown
	from fact_prices fp
	join dim_company dc
	on fp.ticker_id = dc.ticker_id
	where dc.is_benchmark = false
	and fp.drawdown is not null
	group by fp.ticker_id
),
dd_deciles as (
	select ticker_id,
	ntile(10) over (order by max_drawdown asc ) as dd_decile
	from max_dd
),
risk as (
    SELECT v.ticker_id,
           (SELECT AVG(d) FROM unnest(ARRAY[v.vol_decile, dd.dd_decile]) AS d) AS risk_score
    FROM vol_deciles v
    LEFT JOIN dd_deciles dd ON v.ticker_id = dd.ticker_id
)
UPDATE fact_scores s
SET risk_score = r.risk_score
FROM risk r
WHERE s.ticker_id = r.ticker_id;
```

Growth needed building from scratch — there's no CAGR column, so it comes out
of first and last revenue and the number of years between them. Then the
composite and the rank:

```sql
-- 08_7_growth_score_and_composite.sql (excerpt)
cagr as (
    select ticker_id,
           power(last_revenue / first_revenue, 1.0 / years) - 1 as revenue_cagr
    from rev
    where years > 0
),
growth_deciles as (
    select ticker_id,
           ntile(10) over (order by revenue_cagr asc) as growth_decile
    from cagr
)
update fact_scores s
set growth_score = g.growth_decile
from growth_deciles g
where s.ticker_id = g.ticker_id;

UPDATE fact_scores
SET composite_score = (
    SELECT AVG(d)
    FROM unnest(ARRAY[value_score, quality_score, momentum_score,
                      risk_score, growth_score]) AS d
);

WITH ranked AS (
    SELECT ticker_id,
           RANK() OVER (ORDER BY composite_score DESC NULLS LAST) AS rnk
    FROM fact_scores
)
UPDATE fact_scores s
SET rank_overall = r.rnk
FROM ranked r
WHERE s.ticker_id = r.ticker_id;
```

`AVG` over `unnest` ignores nulls, so a company whose P/B or ROE came out null
is averaged over the factors it does have rather than being knocked out
entirely. That's a choice, not an accident — but it does mean a handful of
companies are ranked on four factors while everyone else is ranked on five.

### 7. Picking the portfolio

The top ten by composite — but with two eligibility rules first, which is
where the data-quality findings actually get used:

```sql
-- 09_1_portfolio_holdings.sql
with history as (
	select ticker_id,
	count(monthly_turn) as month_of_return
from fact_prices
group by ticker_id
),
eligible as (
	select s.ticker_id ,
	s.ticker,
	s.composite_score,
	s.rank_overall,
	s.sector
from fact_scores s
	join history h
	on s.ticker_id = h.ticker_id
	where h.month_of_return >= 71
	and s.ticker <> 'GOOG'
	and s.composite_score is not null
)
select ticker_id,
	   rank_overall,
	   composite_score,
	   ticker,
	   sector,
	   rank() over (order by composite_score desc ) as portfolio_rank
	from eligible
	order by composite_score desc
	limit 10;
```

`month_of_return >= 71` is what keeps GE Vernova and Palantir out — you can't
compare a 22-month track record to a 72-month one. `ticker <> 'GOOG'` stops
the portfolio holding the same company twice through two share classes.

### 8. The backtest

Compound the monthly portfolio return and the SPY return the same way, and
index both to 100 so they're comparable on one axis:

```sql
-- 09_3_cumulative_returns.sql
create table portfolio_cumulative as(
	select date,
		   date_id,
		   year_month,
		   portfolio_returns ,
		   spy_return,
		   exp(sum(ln(1 + portfolio_returns )) over w) as portfolio_value,
		   exp(sum(ln(1 + pmi.spy_return)) over w ) as spy_value,
		   100 * exp(sum(ln(1+ portfolio_returns)) over w ) as portfolio_index,
		   100 * exp(sum(ln(1 + pmi.spy_return)) over w) as spy_index
	from portfolio_monthly_returns pmi
	window w as (order by date_id rows between unbounded preceding and current row ));
```

Then the metrics — annualised return, annualised volatility, Sharpe and max
drawdown, calculated for both in the same query so neither gets special
treatment:

```sql
-- 09_4_performance_metrics.sql (excerpt)
SELECT
    ROUND((POWER(f.portfolio_value, 12.0 / s.n_months) - 1)::numeric, 4) AS port_ann_return,
    ROUND((POWER(f.spy_value,       12.0 / s.n_months) - 1)::numeric, 4) AS spy_ann_return,
    ROUND((s.port_sd * SQRT(12))::numeric, 4)                            AS port_ann_vol,
    ROUND((s.spy_sd  * SQRT(12))::numeric, 4)                            AS spy_ann_vol,
    ROUND(((POWER(f.portfolio_value, 12.0/s.n_months) - 1)
           / (s.port_sd * SQRT(12)))::numeric, 2)                        AS port_sharpe,
    ROUND((SELECT MIN(port_dd) FROM dd)::numeric, 4)                     AS port_max_dd,
    ROUND((SELECT MIN(spy_dd)  FROM dd)::numeric, 4)                     AS spy_max_dd
FROM spread s, final f;
```

Monthly standard deviation is annualised by `SQRT(12)`, and the monthly value
is annualised by raising it to `12 / n_months`.

### 9. The dashboard

Three pages in Tableau:

- **Screener** — every company, every score, colour graded across the 101
  stocks and six scores. Dark is high, light is low, so the pattern jumps out
  at you.
- **Company Detail** — one company at a time: price history, drawdown
  underneath it on the same time axis, factor profile as bars against the 5.5
  universe-average line, and a row of KPIs. A dropdown switches company and
  all four move together.
- **Backtest** — the portfolio line against the index, five KPI cards, and the
  top-ten table.

Two calculated fields do the work on the Company Detail page:

```
Latest Close
IF [Date] = { FIXED [Ticker] : MAX([Date]) } THEN [Close Price] END

Ticker Filter
[Ticker] = [Selected Ticker]
```

---

## Results

Top ten by composite: **PM, GS, LLY, MS, GOOGL, UBER, AMGN, AVGO, MO, JNJ.**
Held static 2020–2025, equal weighted, rebalanced monthly.

| Metric | Portfolio | S&P 500 (SPY) |
|---|---|---|
| Total return | +317% | +131% |
| Annualised return | 27.3% | 15.2% |
| Annualised volatility | 17.4% | 17.6% |
| Sharpe (risk-free = 0) | 1.57 | 0.86 |
| Max drawdown | −13.6% | −24.0% |

**The SPY column is the point.** It runs through the same loading, the same
return calculation, the same compounding chain and the same metric formulas as
the portfolio — the queries above compute both columns side by side. Its
numbers match the real index, including the −24% drawdown in 2022. If my
compounding were wrong, or the returns misaligned, or the drawdown logic
faulty, the benchmark would be wrong too. It isn't. So the chain is correct.

That answers one question — is the code right? — and it does not answer the
other one.

## What I actually found

**The outperformance all arrives after mid-2022.** The portfolio line and the
index line sit almost on top of each other from January 2020 until roughly
mid-2022. The entire 186-point gap opens after that — during the rally that
the factor scores were computed over. The chart makes the look-ahead bias
visible, which is more useful than a chart that hides it.

**Ten stocks were less volatile than five hundred.** That should be
suspicious, and it is. The risk factor picked defensives — PM, MO, JNJ, AMGN,
LLY — but it picked them using volatility *and drawdown* measured over the
same window the backtest runs on. It's circular twice over. This is the most
contaminated of the five factors and it's the one driving the headline risk
numbers.

**The composite hides opposites.** Two companies can land on the same
composite for completely different reasons. Lilly scores 10 on growth and 1.5
on value. Altria scores 10 on quality and value but 2 on growth. Averaging
them into one number throws that away — which is why the Company Detail page
shows the five bars separately.

**Trailing earnings are literal.** Capital One shows a 59.7× P/E and a 2.2%
ROE. Both are real. They come from a one-off CECL charge on the Discover
acquisition — an accounting provision, not a collapse in the business. A
screen built on trailing earnings cannot tell that apart from a bank that is
genuinely failing.

**Fiscal years don't line up.** 96 companies report FY2025, 5 report FY2026.
They're being compared as if they're the same period.

## What's wrong with it

- **Look-ahead bias.** The factor scores use data through the end of 2025 and
  are applied from the start of 2020. In 2020 I could not have known any of
  it. This is the dominant flaw and it isn't fixable without point-in-time
  fundamentals.
- **Survivorship bias.** The universe is today's S&P 100. Companies that
  dropped out of the index over the period aren't in it, so the sample is
  already the winners.
- **Circular risk scoring.** Both halves of the risk factor are measured over
  the same window they're tested on.
- **Static holdings.** The ten are picked once and held for the whole period.
  Weights are rebalanced monthly but the screen never re-runs, so this tests
  one ranking rather than a repeatable process.
- **Drawdown understated at the start.** `portfolio_cumulative` begins at the
  first month that has a return, so the opening level of 1.0 is never a peak
  and the March 2020 COVID drawdown comes out shallower than it was. It
  doesn't change the answer here because the 2022 drawdown was deeper anyway.
- **Sharpe uses a zero risk-free rate,** so both Sharpe figures are upper
  bounds.
- **Uneven factor coverage.** Companies with a null ratio are scored on four
  factors rather than five.

So: the pipeline works and the result is not evidence that the strategy works.
What this project demonstrates is the pipeline — extraction, validation,
dimensional modelling, window-function analytics, backtesting, visualisation —
and the judgement to say why its own headline number shouldn't be believed.

## Problems I hit building it

**The risk score sorted the wrong way.** Volatility needed `DESC` so that low
volatility scores high. Before I fixed it the screen was rewarding the most
volatile companies, and the output looked perfectly reasonable.

**Clicking a ticker on the Screener broke the Company Detail page.** I set it
up as a filter action first. It didn't work, and the drawdown chart broke. The
reason is that **filters in Tableau are scoped to a single data source, while
parameters are global to the whole workbook** — the two pages sit on different
data sources, so a filter could never reach across. The fix was the `Selected
Ticker` parameter and the `Ticker Filter` calculated field above, driven by a
Change Parameter action. Because the parameter is workbook-global, it reaches
where the filter couldn't.

**Tableau Public only accepts extracts.** I had to convert the live
connections to `.hyper` extracts before it would publish. The extracts then
failed to write silently — the cause was the workbook sitting in iCloud Drive.
Saving it as a `.twbx` outside iCloud fixed it.

---

## Every file

### `python/`
| File | What it does |
|---|---|
| `01_data_pull.ipynb` | Loops the 102 tickers through yfinance, pulls monthly prices and four years of annual fundamentals, writes the raw CSVs |

### `data/`
| File | What it is |
|---|---|
| `OEF_holdings.csv` | The S&P 100 constituent list, from the iShares OEF ETF |
| `universe.csv` | Cleaned ticker list — 101 companies plus SPY |
| `prices_raw.csv` | Monthly prices 2020–2025, ~7,286 rows |
| `fundamentals_raw.csv` | Four years of annual fundamentals |

### `data/exports/`
The eight tables exported out of Postgres with `COPY ... TO` and loaded into
Tableau: `dim_company.csv`, `dim_date.csv`, `fact_prices.csv`,
`fact_ratios.csv`, `fact_scores.csv`, `portfolio_holdings.csv`,
`portfolio_monthly_returns.csv`, `portfolio_cumulative.csv`.

### `sql/01_setup/`
| File | What it does |
|---|---|
| `01_1_create_staging_tables.sql` | Staging table DDL |

### `sql/02_staging/`
| File | What it does |
|---|---|
| `02_1_load_staging.sql` | Loads the raw CSVs in, uncleaned |
| `02_2_check_row_counts.sql` | Did I get the rows I expected |
| `02_3_check_price_coverage.sql` | Found GEV at 22 months and PLTR at 64 |
| `02_4_check_fundamentals_fiscal_years.sql` | Found the FY2025/FY2026 mix |
| `02_5_check_cross_table_consistency.sql` | Do the tables agree with each other |
| `02_6_check_date_ranges.sql` | Do the date ranges make sense |
| `02_7_check_nulls.sql` | Where are the nulls |
| `02_8_check_implausible_values.sql` | Found the 28 negative-equity rows and Colgate's P/B of 1,172 |
| `02_9_check_outlier_returns.sql` | Anomalies in the monthly returns |

### `sql/03_star_schema/`
| File | What it does |
|---|---|
| `03_1_dim_date.sql` | One row per date — year, month, quarter |
| `03_2_dim_company.sql` | One row per company — ticker, name, sector |
| `03_3_fact_prices.sql` | One row per company per month |
| `03_4_fact_fundamentals.sql` | One row per company per year |

### `sql/04_analysis/`
| File | What it does |
|---|---|
| `06_1_monthly_return.sql` | Monthly returns using `LAG()` |
| `06_2_rolling_12m_return.sql` | The momentum input |
| `06_3_volatility_12m.sql` | Half the risk input |
| `06_4_drawdown.sql` | Underwater curve — log-sum compounding and a running `MAX()` |
| `07_1_latest_fundamentals.sql` | Most recent fiscal year per company |
| `07_2_latest_price.sql` | Latest close per company |
| `07_3_fact_ratios.sql` | P/E, P/B, ROE, ROA, D/E — all guarded against negative equity |
| `08_1_fact_scores_table.sql` | Creates the scores table |
| `08_2_value_score.sql` | P/E and P/B deciles, averaged |
| `08_3_quality_score.sql` | ROE decile |
| `08_4_momentum_score.sql` | 12-month return decile |
| `08_5_risk_score.sql` | Volatility and drawdown deciles, averaged |
| `08_7_growth_score_and_composite.sql` | Revenue CAGR decile, then the composite and `RANK()` |
| `09_1_portfolio_holdings.sql` | Top ten, after the 71-month and duplicate-ticker filters |
| `09_2_portfolio_monthly_returns.sql` | Equal-weighted monthly portfolio return |
| `09_3_cumulative_returns.sql` | Growth-of-100 chain for portfolio and SPY |
| `09_4_performance_metrics.sql` | CAGR, volatility, Sharpe, max drawdown |

Working files I've kept rather than tidied away, so the build is visible:
`08_3_quality_score_draft.sql`, `08_4_momentum_score_draft.sql`,
`08_6_composite_and_rank_draft.sql` (superseded — the final composite lives at
the bottom of `08_7`), and `Phase 9_2.sql` (an earlier copy of `09_2`).

### `Tableau /`
| File | What it is |
|---|---|
| `Us Dashboard .twb` | The three-page workbook: Screener, Company Detail, Backtest |
| `Company Detail .hyper`, `fact_scores+.hyper`, `portfolio_cumulative.hyper`, `portfolio_holdings.hyper` | The extracts Tableau Public requires |

---

## Running it yourself

1. Run `python/01_data_pull.ipynb` — pulls prices and fundamentals into `data/`
2. Create a PostgreSQL database called `us_equity_screener`
3. Run the SQL in numeric order: `01_setup` → `02_staging` → `03_star_schema`
   → `04_analysis`. Read the `02_staging` checks rather than skipping them —
   that's where the data problems show up.
4. Export the tables with `COPY ... TO` into `data/exports/`
5. Open the Tableau workbook and point it at `data/exports/`
