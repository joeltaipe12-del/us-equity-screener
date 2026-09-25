drop table if exists portfolio_cumulative;
create table portfolio_cumulative as(
	select date, 
		   date_id, 
		   year_month, 
		   portfolio_returns ,
		   spy_return,
		   exp(sum(ln(1 + portfolio_returns )) over w) as portfolio_value, 
		   exp(sum(ln(1 + pmi.spy_return)) over w ) as spy_value, 
		   100 * exp(sum(ln(1+ portfolio_returns)) over w ) as portfolio_index, 
		   100 * exp(sum(ln(1 + pmi.spy_return)) over w) as spy_index
	from portfolio_monthly_returns pmi 
	window w as (order by date_id rows between unbounded preceding and current row ));

SELECT year_month,
       ROUND(portfolio_returns::numeric, 4) AS ret,
       ROUND(portfolio_index::numeric, 1)   AS port,
       ROUND(spy_index::numeric, 1)         AS spy
FROM portfolio_cumulative
ORDER BY date_id;