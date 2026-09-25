WITH dd AS (
    SELECT portfolio_value / MAX(portfolio_value) OVER w - 1 AS port_dd,
           spy_value       / MAX(spy_value)       OVER w - 1 AS spy_dd
    FROM portfolio_cumulative
    WINDOW w AS (ORDER BY date_id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
),
spread AS (
    SELECT COUNT(*)                        AS n_months,
           STDDEV_SAMP(portfolio_returns)  AS port_sd,
           STDDEV_SAMP(spy_return)         AS spy_sd
    FROM portfolio_monthly_returns
),
final AS (
    SELECT portfolio_value, spy_value
    FROM portfolio_cumulative
    ORDER BY date_id DESC
    LIMIT 1
)
SELECT
    ROUND((POWER(f.portfolio_value, 12.0 / s.n_months) - 1)::numeric, 4) AS port_ann_return,
    ROUND((POWER(f.spy_value,       12.0 / s.n_months) - 1)::numeric, 4) AS spy_ann_return,
    ROUND((s.port_sd * SQRT(12))::numeric, 4)                            AS port_ann_vol,
    ROUND((s.spy_sd  * SQRT(12))::numeric, 4)                            AS spy_ann_vol,
    ROUND(((POWER(f.portfolio_value, 12.0/s.n_months) - 1)
           / (s.port_sd * SQRT(12)))::numeric, 2)                        AS port_sharpe,
    ROUND(((POWER(f.spy_value, 12.0/s.n_months) - 1)
           / (s.spy_sd * SQRT(12)))::numeric, 2)                         AS spy_sharpe,
    ROUND((SELECT MIN(port_dd) FROM dd)::numeric, 4)                     AS port_max_dd,
    ROUND((SELECT MIN(spy_dd)  FROM dd)::numeric, 4)                     AS spy_max_dd
FROM spread s, final f;