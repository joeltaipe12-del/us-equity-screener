DROP TABLE IF EXISTS portfolio_holdings;

create table portfolio_holdings as 
with history as (
	select ticker_id, 
	count(monthly_turn) as month_of_return 
from fact_prices
group by ticker_id
), 
eligible as (
	select s.ticker_id ,
	s.ticker, 
	s.composite_score, 
	s.rank_overall,
	s.sector
from fact_scores s 
	join history h 
	on s.ticker_id = h.ticker_id 
	where h.month_of_return >= 71 
	and s.ticker <> 'GOOG'
	and s.composite_score is not null 
)
select ticker_id, 
	   rank_overall, 
	   composite_score, 
	   ticker, 
	   sector, 
	   rank() over (order by composite_score desc ) as portfolio_rank
	from eligible 
	order by composite_score desc
	limit 10; 

SELECT * FROM portfolio_holdings ORDER BY portfolio_rank;

