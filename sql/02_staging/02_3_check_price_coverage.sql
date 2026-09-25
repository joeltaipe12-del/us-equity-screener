select sp.ticker ,count(*) as months
from stg_prices sp 
	group by ticker 
	order by months ASC;


/* Check 2 — Price coverage:
  - 100/102 tickers have full 72 months
  - GEV: 22 months (spun off from GE April 2024)
  - PLTR: 64 months (IPO September 2020)