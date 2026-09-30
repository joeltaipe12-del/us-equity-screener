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

## Executive Summary

A five-factor screener over the S&P 100 produced a top-ten portfolio
returning +317% against the index's +131% over 2020–2025, with lower
volatility and half the drawdown.

The benchmark's figures match the real S&P 500, confirming the
calculation chain is correct.

The strategy result is not, however, evidence that the strategy works.
Factor scores were computed using data through the end of the test period and
applied from the start of it, the universe contains only companies that
survived to the present, and the risk factor is scored on the same window it
is measured over.

What the project demonstrates is a working, reproducible analytics pipeline —
extraction, validation, dimensional modelling, window-function analytics,
backtesting and visualisation — together with the judgement to identify why
its own headline result should not be believed.

## The five factors

Each factor is scored 1–10 using `NTILE(10)`, which splits the universe into
deciles. A score is a rank relative to the S&P 100, not an absolute judgement
— a value score of 10 means "cheapest tenth of the S&P 100", not "cheap".

| Factor | What I measured | Scores high when |
|---|---|---|
| Value | The P/E decile and the P/B decile, averaged | Cheap |
| Quality | Return on equity | Profitable on shareholder capital |
| Momentum | Rolling 12-month return | Rising |
| Risk | Trailing 12-month volatility | Steady |
| Growth | Revenue CAGR | Growing sales |

Two of the five sort the other way — low P/E and low volatility are the good
ends. Getting one backwards gives you a ranking that looks completely
plausible and is completely wrong. That happened to me: the risk score was
sorted the wrong way until I caught it and changed it to `DESC`.

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

Then I ran nine checks:

- Did I get the number of rows I expected?
- Does every company have a full price history?
- Are the fiscal years consistent?
- Do my tables agree with each other?
- Do the date ranges make sense?
- Are there nulls?
- Are there impossible values?
- Are there anomalies in the monthly returns?

### 3. What the checks found

**Short price histories.** GE Vernova had 22 months and Palantir had 64,
instead of the full period. Both joined the index recently. If you average a
22-month return against a 72-month one, the comparison is meaningless, so this
has to be accounted for rather than ignored.

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
you:

- **Monthly return** — `LAG()` to compare each month to the one before
- **Rolling 12-month return** — the momentum input
- **12-month volatility** — the risk input
- **Drawdown** — how far below the previous peak, using a running `MAX()`

These four are the raw material the scoring runs on.

### 6. Scoring and ranking

`NTILE(10)` on each measure to rank every company out of 10, for all five
factors. Then the composite — the average of the five, equal weighted — and
`RANK()` to order them.

### 7. The backtest

Take the top ten holdings, get their monthly returns, compound them, and
calculate the metrics: total return, annualised return, volatility, Sharpe
ratio and max drawdown. Then run SPY through **exactly the same code** and
compare.

### 8. The dashboard

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
the portfolio. Its numbers match the real index, including the −24% drawdown
in 2022. If my compounding were wrong, or the returns misaligned, or the
drawdown logic faulty, the benchmark would be wrong too. It isn't. So the
chain is correct.

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
LLY — but it picked them using volatility measured over the same window the
backtest runs on. It's circular. This is the most contaminated of the five
factors and it's the one driving the headline risk numbers.

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
- **Circular risk scoring.** As above — the risk factor is scored on the same
  window it's tested over.
- **Drawdown understated at the start.** `portfolio_cumulative` begins at the
  first month that has a return, so the opening level of 1.0 is never a peak
  and the March 2020 COVID drawdown comes out shallower than it was. It
  doesn't change the answer here because the 2022 drawdown was deeper anyway.
- **Sharpe uses a zero risk-free rate,** so both Sharpe figures are upper
  bounds.

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
data sources, so a filter could never reach across. The fix was a `Selected
Ticker` string parameter plus a calculated field `[Ticker] = [Selected
Ticker]` on the Company Detail sheets, driven by a Change Parameter action.
Because the parameter is workbook-global, it reaches where the filter couldn't.

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
| `06_3_volatility_12m.sql` | The risk input |
| `06_4_drawdown.sql` | Underwater curve using a running `MAX()` |
| `07_1_latest_fundamentals.sql` | Most recent fiscal year per company |
| `07_2_latest_price.sql` | Latest close per company |
| `07_3_fact_ratios.sql` | P/E, P/B, ROE, revenue CAGR |
| `08_1_fact_scores_table.sql` | Creates the scores table |
| `08_2_value_score.sql` | P/E and P/B deciles, averaged |
| `08_3_quality_score.sql` | ROE decile |
| `08_4_momentum_score.sql` | 12-month return decile |
| `08_5_risk_score.sql` | Volatility decile, `DESC` so low vol scores high |
| `08_7_growth_score_and_composite.sql` | Revenue CAGR decile, then the final composite and `RANK()` |
| `09_1_portfolio_holdings.sql` | The top ten |
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
