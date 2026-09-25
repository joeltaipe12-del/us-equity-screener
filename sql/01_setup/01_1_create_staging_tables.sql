create table stg_companies(
ticker TEXT,
company_name TEXT,
sector TEXT
);


create table stg_prices(
date DATE,
ticker TEXT,
close NUMERIC
);

create table stg_fundamentals(
revenue       NUMERIC,
net_income    NUMERIC,
total_assets  NUMERIC,
total_equity  NUMERIC,
total_debt    NUMERIC,
eps           NUMERIC,
ticker        TEXT,
fiscal_year   INTEGER
);

SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public';