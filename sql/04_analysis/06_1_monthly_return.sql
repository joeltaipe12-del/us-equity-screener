with returns as (
select
	ticker_id,
	date_id,
	(fp.close_price/ lag(fp.close_price) over(partition by ticker_id order by date_id)) - 1 as 
	new_returns
	from fact_prices fp
)
update fact_prices fp 
set monthly_turn = r.new_returns
from returns r
where fp.ticker_id = r.ticker_id
and fp.date_id = r.date_id; 


select * from fact_prices fp 