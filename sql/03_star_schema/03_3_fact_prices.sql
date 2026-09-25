DROP TABLE IF EXISTS fact_prices CASCADE;

create table fact_prices ( 
		ticker_id   		integer not null references dim_company(ticker_id), 
		date_id 			integer not null references dim_date(date_id),
		close_price 		numeric (12 ,4), 
		volume 				numeric , 
		monthly_turn 		numeric (10,6), 
		rolling_12m_return  numeric(10,6), 
		volatility_12m      numeric(10,6), 
		drawdown			numeric(10,6),
  PRIMARY KEY (ticker_id, date_id)
  
  );

insert into fact_prices (ticker_id, date_id, close_price)
select
	dc.ticker_id, 
	dd.date_id,
	sp.close 
from stg_prices sp
JOIN dim_company dc ON sp.ticker = dc.ticker
JOIN dim_date    dd ON sp.date   = dd.date;

SELECT COUNT(*) FROM fact_prices;

