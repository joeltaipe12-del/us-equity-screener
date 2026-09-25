drop table if exists fact_ratios cascade;
CREATE TABLE fact_ratios as
with fund_ranked as (
	select 
		ticker_id,
		fiscal_year,
		revenue,
		net_income,
		total_assets,
		total_equity,
		total_debt,
		eps,
		row_number() over (partition by ticker_id order by fiscal_year DESC) as rn 
	from fact_fundamentals ff 
),
fund_latest as (
	select 
		ticker_id,
		fiscal_year,
		revenue,
		net_income,
		total_assets,
		total_equity,
		total_debt,
		eps 
	from fund_ranked 
	where rn = 1
),
price_ranked as( 
	select 
		ticker_id,
		date_id,
		close_price,
		row_number() over(partition by ticker_id order by date_id DESC) as rn 
	from fact_prices fp
),
price_latest as ( 
	select
		ticker_id,
		date_id,
		close_price
	from  price_ranked pr
	where rn = 1
)
select
    dc.ticker,
    dc.company_name,
    dc.sector,
    fl.fiscal_year,
    pl.close_price,
    fl.eps,
case when 
	fl.eps > 0 then pl.close_price / fl.eps 
	else null end as pe_ratio,
case when 
	fl.total_equity > 0 then (fl.net_income / fl.total_equity)
	else null
	end as roe,
case when 
	fl.total_assets > 0 then (fl.net_income / fl.total_assets)
	else null 
	end as roa,
case when 
	fl.total_equity > 0 then (fl.total_debt / fl.total_equity)
	else null 	
	end as de_ratio,
case when  
	fl.total_equity > 0 and fl.eps > 0 and fl.net_income > 0
    then (pl.close_price * fl.net_income) / (fl.total_equity * fl.eps)
    else null  
	end as pb_ratio
from fund_latest fl
join price_latest pl on fl.ticker_id = pl.ticker_id
join dim_company dc  on fl.ticker_id = dc.ticker_id;


