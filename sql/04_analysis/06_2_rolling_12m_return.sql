WITH rolling AS (
    SELECT
        ticker_id,
        date_id,
        CASE
            WHEN COUNT(monthly_turn) OVER w < 12
            THEN NULL
            ELSE EXP(SUM(LN(1 + monthly_turn)) OVER w) - 1
        END AS new_rolling
    FROM fact_prices
    WINDOW w AS (
        PARTITION BY ticker_id
        ORDER BY date_id
        ROWS BETWEEN 11 PRECEDING AND CURRENT ROW
    )
)
UPDATE fact_prices fp
SET rolling_12m_return = r.new_rolling
FROM rolling r
WHERE fp.ticker_id = r.ticker_id
  AND fp.date_id   = r.date_id;

select * from fact_prices fp 
