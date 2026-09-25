select count(distinct ticker_id) 			 as companies, 
	   count(*) 				 			 as rows, 
	   count(revenue)            			 as revenue_present,
	   count(*) filter (where revenue <= 0 ) as revenue_non_positive               
from fact_fundamentals;

ALTER TABLE fact_scores ADD COLUMN growth_score NUMERIC(4,2);

with bounds as (
	select ticker_id, 
	min(fiscal_year) 		as first_year, 
	max(fiscal_year)        as last_year 
from fact_fundamentals 
where revenue is not null 
and revenue > 0 
group by ticker_id 
having count(*) >= 3
), 
rev as (
    select b.ticker_id,
           b.last_year - b.first_year as years,
           f1.revenue as first_revenue,
           f2.revenue as last_revenue
    from bounds b
    join fact_fundamentals f1
      on f1.ticker_id = b.ticker_id and f1.fiscal_year = b.first_year
    join fact_fundamentals f2
      on f2.ticker_id = b.ticker_id and f2.fiscal_year = b.last_year
),
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

SELECT rank_overall, ticker, sector,
       value_score, quality_score, momentum_score, risk_score, growth_score,
       composite_score
FROM fact_scores
ORDER BY rank_overall
LIMIT 15;
