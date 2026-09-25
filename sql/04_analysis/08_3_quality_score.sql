select count(*) as n , 
	   count(roe) as roe_present, 
	   count(roa) as roa_present,
	   count(de_ratio) as de_present,
	   min(roe) as min_roe, 
	   max(roe) as max_roe, 
	   min(roa) as min_roa,
	   max(roa) as max_roa
from fact_ratios
;

with roe_deciles as (
	select 
		ticker,
		ntile(10) over (order by roe asc ) as roe_decile
	from fact_ratios
where roe is not null 
),
roa_deciles as (
	select
	ticker,
	ntile(10) over (order by roa asc ) as roa_decile 
from fact_ratios
where roa is not null
),
de_deciles as (
	select 
		ticker,
		ntile(10) over (order by de_ratio desc ) as de_decile 
	from fact_ratios
	where de_ratio is not null
),
quality as (
	select 
	r.ticker,
	(select avg(d) from unnest(array[roe.roe_decile, roa.roa_decile, de.de_decile]) as d) as quality_score
	 FROM fact_ratios r
   LEFT JOIN roe_deciles roe ON r.ticker = roe.ticker
   LEFT JOIN roa_deciles roa ON r.ticker = roa.ticker
   LEFT JOIN de_deciles  de  ON r.ticker = de.ticker
)
update fact_scores s
set quality_score = q.quality_score
from quality q
where s.ticker = q.ticker;
