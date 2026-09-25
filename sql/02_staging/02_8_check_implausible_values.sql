select Count(*) 
as close_unrealistic 
from stg_prices sp 
where close <= 1 ;

select Count(*) 
	as total_unrealistic
	from stg_fundamentals sf 
	where total_assets <= 0;
	
select count(*) 
as equity_unrealistic
from stg_fundamentals sf 
where sf.total_equity < 0;

SELECT ticker, COUNT(*) AS years_negative
FROM stg_fundamentals
WHERE total_equity < 0
GROUP BY ticker
ORDER BY years_negative DESC;
/*Layer 2 Check 3 — Implausible values:
  - Prices: 0 rows ≤ 0 ✅
  - Total assets: 0 rows ≤ 0 ✅
  - Total equity: 28 rows negative across 9 tickers
    Structurally negative (4 years): PM, LOW, MO, MCD, SBUX
    Partially negative (3 years): BA, BKNG
    Transient negative (1 year): ORCL, ABBV
    Root cause: Aggressive share buyback programmes outpacing retained earnings
    Implications: P/B, D/E, ROE become meaningless when equity is negative
    Decision: Keep in dataset; substitute sector median for affected ratios
             in Phase 8 factor scoring