DROP TABLE IF EXISTS fact_scores;

CREATE TABLE fact_scores (
    ticker_id       INTEGER PRIMARY KEY REFERENCES dim_company(ticker_id),
    ticker          VARCHAR(10) NOT NULL,
    sector          VARCHAR(50),
    value_score     NUMERIC(4,2),
    quality_score   NUMERIC(4,2),
    momentum_score  NUMERIC(4,2),
    risk_score      NUMERIC(4,2),
    composite_score NUMERIC(4,2),
    rank_overall    INTEGER
);

INSERT INTO fact_scores (ticker_id, ticker, sector)
SELECT ticker_id, ticker, sector
FROM dim_company
WHERE is_benchmark = FALSE;   
SELECT COUNT(*) AS n_rows, COUNT(value_score) AS n_scored FROM fact_scores;