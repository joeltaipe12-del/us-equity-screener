with momentum_deciles as (
	select
		fp.ticker_id, 
			ntile(10) over (order by rolling_12m_return asc) as momentum_decile  
	from fact_prices fp
	join dim_company dc
	on fp.ticker_id = dc.ticker_id 
	where fp.date_id = (select max(date_id) from fact_prices fp)
	and dc.is_benchmark = false 
	and fp.rolling_12m_return is not null 
)
update fact_scores s 
set momentum_score = m.momentum_decile 
from momentum_deciles m 
where s.ticker_id = m.ticker_id;

select * from fact_scores t 