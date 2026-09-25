CREATE TABLE dim_date (
    date_id     INTEGER PRIMARY KEY,
    date        DATE NOT NULL UNIQUE,
    year        INTEGER NOT NULL,
    quarter     INTEGER NOT NULL,
    month       INTEGER NOT NULL,
    month_name  VARCHAR(10) NOT NULL,
    year_month  VARCHAR(7) NOT NULL
);

WITH date_series AS (
    SELECT generate_series(
        '2020-01-01'::date,
        '2025-12-01'::date,
        '1 month'::interval
    )::date AS series_date
)
INSERT INTO dim_date (date_id, date, year, quarter, month, month_name, year_month)
SELECT
    ROW_NUMBER() OVER (ORDER BY series_date)::INTEGER AS date_id,
    series_date AS date,
    EXTRACT(YEAR FROM series_date)::INTEGER AS year,
    EXTRACT(QUARTER FROM series_date)::INTEGER AS quarter,
    EXTRACT(MONTH FROM series_date)::INTEGER AS month,
    TRIM(TO_CHAR(series_date, 'Month')) AS month_name,
    TO_CHAR(series_date, 'YYYY-MM') AS year_month
FROM date_series
ORDER BY series_date;

