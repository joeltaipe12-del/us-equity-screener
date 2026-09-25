SELECT current_database()

SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public';


COPY stg_companies FROM '/tmp/universe.csv' DELIMITER ',' CSV HEADER;
COPY stg_prices FROM '/tmp/prices_raw.csv' DELIMITER ',' CSV HEADER;
COPY stg_fundamentals FROM '/tmp/fundamentals_raw.csv' DELIMITER ',' CSV HEADER;

select 'stg_companies' as companies, 
	COUNT(*) as row_count, 
	COUNT(distinct ticker) as unqiue_tickers
from stg_companies;


select 'stg_prices' as prices,
	COUNT(*) as row_count, 
	COUNT(distinct ticker) as unqiue_tickers,
	MIN(date) as earliest,
	MAX(date) as Latest 
from stg_prices; 

SELECT 
    'stg_fundamentals' AS fundamentals,
    COUNT(*) AS row_count, 
    COUNT(DISTINCT ticker) AS unique_tickers, 
    MIN(fiscal_year) AS earliest_fy, 
    MAX(fiscal_year) AS latest_fy
FROM stg_fundamentals;

select  * from  stg_fundamentals sf 
where ticker = 'AAPL'
limit 5;

