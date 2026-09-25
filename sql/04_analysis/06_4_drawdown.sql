with cumulative as (
		select
			ticker_id,
			date_id ,
			exp(sum(ln(monthly_turn + 1)) over (
				partition by ticker_id
				order by date_id
			 	ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT row
		)) as cum_return
	from fact_prices fp 
	where monthly_turn is not null
),
peak as (
	select
			ticker_id,
			date_id,
			cum_return,
			max(cum_return) over (
				partition by ticker_id
				order by date_id
			 	ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT row
			 ) as running_peak 
			from cumulative
),
dd as (
	select 
        ticker_id,
        date_id,
        (cum_return / running_peak) - 1 AS new_drawdown
    FROM peak
)
UPDATE fact_prices fp
SET drawdown = dd.new_drawdown
FROM dd
WHERE fp.ticker_id = dd.ticker_id
  AND fp.date_id = dd.date_id;

