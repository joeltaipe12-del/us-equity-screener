WITH momentum_deciles AS (
    SELECT fp.ticker_id,
           ntile(10) OVER (ORDER BY fp.rolling_12m_return ASC) AS momentum_decile
    FROM fact_prices fp
    JOIN dim_company dc ON fp.ticker_id = dc.ticker_id
    WHERE fp.date_id = (SELECT MAX(date_id) FROM fact_prices)
      AND dc.is_benchmark = FALSE
      AND fp.rolling_12m_return IS NOT NULL
)
UPDATE fact_scores s
SET momentum_score = m.momentum_decile
FROM momentum_deciles m
WHERE s.ticker_id = m.ticker_id;