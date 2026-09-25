drop table if exists portfolio_monthly_returns;
create table portfolio_monthly_returns as 
	with portfolio as (
		select fp.date_id,
			    avg(fp.monthly_turn) as portfolio_returns, 
			    count(fp.monthly_turn) as n_holdings 
	from fact_prices fp 
	join portfolio_holdings ph
	on fp.ticker_id = ph.ticker_id 
	where fp.monthly_turn is not null 
	group by fp.date_id
), 
benchmark as (
	select fp.date_id, 
		   fp.monthly_turn as spy_return
	from fact_prices fp 
	join dim_company dc 
	on fp.ticker_id = dc.ticker_id
	where fp.monthly_turn is not null
	AND dc.is_benchmark = TRUE
)
select d.date_id, d.date, d.year_month,
       p.portfolio_returns, b.spy_return, p.n_holdings
from portfolio p
join benchmark b on p.date_id = b.date_id
join dim_date  d on p.date_id = d.date_id;


