WITH vol AS (
    SELECT
        ticker_id,
        date_id,
        CASE
            WHEN COUNT(monthly_turn) OVER w < 12
            THEN NULL
            ELSE STDDEV(monthly_turn) OVER w * SQRT(12)
        END AS new_vol
    FROM fact_prices
    WINDOW w AS (
        PARTITION BY ticker_id
        ORDER BY date_id
        ROWS BETWEEN 11 PRECEDING AND CURRENT ROW
    )
)
UPDATE fact_prices fp
SET volatility_12m = v.new_vol
FROM vol v
WHERE fp.ticker_id = v.ticker_id
  AND fp.date_id = v.date_id;