select count(*) 								as n, 
	   count(pe_ratio)							as pe_present,
	   count(*) filter (where pe_ratio <= 0) 	as pe_non_positve, 
	   min(pe_ratio)							as min_pe, 
	   max(pe_ratio)							as max_pe
from fact_ratios

select pe_ratio, 
	   ticker,
	ntile(10) over (order by pe_ratio desc)
	 as pe_decile 
from fact_ratios 
where pe_ratio is not null;

select count(*)                              as n,
       count(pb_ratio)                       as pb_present,
       count(*) filter (where pb_ratio <= 0) as pb_non_positive,
       min(pb_ratio), max(pb_ratio)
from fact_ratios 

select pb_ratio, 
	   ticker,
	ntile(10) over (order by pb_ratio desc)
	 as pb_decile 
from fact_ratios 
where pb_ratio is not null;

with pe_deciles as (
    select ticker, ntile(10) over (order by pe_ratio desc) as pe_decile
    from fact_ratios where pe_ratio is not null 
),
pb_deciles as (
    select ticker, ntile(10) over (order by pb_ratio desc) as pb_decile
    from fact_ratios where pb_ratio is not null 
),
value as (
    select r.ticker,
           (select avg(d) from unnest(array[pe.pe_decile, pb.pb_decile]) as d) as value_score
    FROM fact_ratios r
    LEFT JOIN pe_deciles pe ON r.ticker = pe.ticker
    LEFT JOIN pb_deciles pb ON r.ticker = pb.ticker
)
update fact_scores s
set value_score = v.value_score
from value v
where s.ticker = v.ticker;

