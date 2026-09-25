select ticker,
	MIN(date) as earliest_date,
	max(date) as latest_date
from stg_prices sp
group by ticker 
order by latest_date DESC;

/* Check 5 — Date range sanity:
  - All 102 tickers end at 2025-12-01 (no mystery delistings)
  - 100/102 tickers start at 2020-01-01 (full 6-year coverage)
  - GEV: starts 2024-03 (post-spin-off)
  - PLTR: starts 2020-09 (post-IPO)
  - Findings consistent with Check 2 (price coverage)



