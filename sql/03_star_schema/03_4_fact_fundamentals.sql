DROP TABLE IF EXISTS fact_fundamentals CASCADE;

create table fact_fundamentals(
		ticker_id 			integer not null references dim_company,
		fiscal_year			integer not null,
		revenue 			numeric,
		net_income			numeric,
		total_assets		numeric, 
		total_equity 		numeric,
		total_debt 			numeric, 
		eps					numeric(10,6)
	);

insert into fact_fundamentals (ticker_id,fiscal_year,revenue,net_income,total_assets,total_equity,total_debt,eps)
select 
	dc.ticker_id, 
	sf.fiscal_year, 
	sf.revenue, 
	sf.net_income, 
	sf.total_assets, 
	sf.total_equity,
	sf.total_debt,
	sf.eps 
from stg_fundamentals sf 
join dim_company dc 
on sf.ticker = dc.ticker;

