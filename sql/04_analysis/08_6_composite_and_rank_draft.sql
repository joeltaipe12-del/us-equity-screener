update fact_scores 
set composite_score = (
	select avg(d) 
		from unnest(array [value_score , quality_score, momentum_score, risk_score]) as d
);

with ranked as (
	select 
		ticker_id, 
		rank() over (order by composite_score asc) as rnk 
	from fact_scores t 
) 
update fact_scores t  
set rank_overall = r.rnk 
from ranked r 
where t.ticker_id  = r.ticker_id;

SELECT rank_overall,
       ticker,
       sector,
       value_score,
       quality_score,
       momentum_score,
       risk_score,
       composite_score,
       (value_score    IS NOT NULL)::int
     + (quality_score  IS NOT NULL)::int
     + (momentum_score IS NOT NULL)::int
     + (risk_score     IS NOT NULL)::int AS factors_used
FROM fact_scores
ORDER BY rank_overall
LIMIT 15;