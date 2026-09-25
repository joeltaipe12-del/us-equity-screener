with returns as (
select
	ticker,
	close,
	date,
	lag(close) over (partition by ticker order by date) as prior_close, 
	(close / lag(close) over(partition by ticker order by date)) - 1 as 
	monthly_returns
	from stg_prices
	)
	
SELECT *
FROM returns
WHERE ABS(monthly_returns) > 0.50
ORDER BY ABS(monthly_returns) DESC;

 /* Layer 2 Check 4 — Outlier returns (|monthly return| > 50%):
  - 7 rows flagged out of ~7,200 (0.1%)
  - All 7 traced to documented business events:
    - PLTR x4: Post-IPO momentum, AI-narrative rallies, S&P inclusion
    - TSLA x1: 5-for-1 split announcement (Aug 2020)
    - AMD x1: AI data centre rally (Oct 2025)
    - SPG x1: COVID retail/REIT collapse (Mar 2020)
  - Verdict: No data errors. All extreme moves are genuine market events.
  - Decision: Retain all rows. Will affect momentum factor scores
    for these tickers — interpreted in Phase 8 commentary.