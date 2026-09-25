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

select * from fact_scores t 