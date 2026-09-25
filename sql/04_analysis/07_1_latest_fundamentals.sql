with ranked as ( 
	select 
		ticker_id,
		fiscal_year,
		revenue,
		net_income,
		total_assets,
		total_equity,
		total_debt,
		eps,
		row_number() OVER (PARTITION BY ticker_id ORDER BY fiscal_year DESC) AS rn
    FROM fact_fundamentals
    )
    SELECT 
    	ticker_id,
		fiscal_year,
		revenue,
		net_income,
		total_assets,
		total_equity,
		total_debt,
		eps
FROM ranked
WHERE rn = 1;

