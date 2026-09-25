with ranked as (
	select 
		ticker_id,
		date_id,
		close_price,
		row_number() over(partition by ticker_id order by date_id desc ) as rn
from fact_prices fp 
)
SELECT
    ticker_id,
    date_id,
    close_price
FROM ranked
WHERE rn = 1;