 DROP TABLE IF EXISTS dim_company CASCADE;
 
 create table dim_company (
		ticker_id 		SERIAL primary key, 
		ticker 	   		VARCHAR(10) unique not null,
		company_name    VARCHAR(100) not null, 
		sector  	    VARCHAR(50) not null,
		market_cap_tier VARCHAR(20) not null,
		is_benchmark    BOOLEAN not null default false 
);

INSERT INTO dim_company (ticker, company_name, sector, market_cap_tier, is_benchmark)
SELECT
    ticker,
    company_name,
    sector,
    CASE
        WHEN ticker = 'SPY' THEN 'Benchmark'
        WHEN ticker IN ('NVDA', 'AAPL', 'MSFT', 'AMZN', 'GOOGL', 'AVGO', 'GOOG', 'META', 'TSLA', 'BRK-B') THEN 'Mega Cap'
        ELSE 'Large Cap'
    END AS market_cap_tier,
    (ticker = 'SPY') AS is_benchmark
FROM stg_companies;
		
