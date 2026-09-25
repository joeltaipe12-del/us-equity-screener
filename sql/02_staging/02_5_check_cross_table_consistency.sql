select ticker from stg_prices sp 
EXCEPT
SELECT ticker FROM stg_fundamentals sf;


/*Check 4 — Cross-table consistency:
  - stg_companies ⊆ stg_prices: 100% overlap
  - stg_prices ⊆ stg_companies: no orphans
  - stg_companies ⊆ stg_fundamentals: SPY missing (expected — ETF)
  - All three tables internally consistent