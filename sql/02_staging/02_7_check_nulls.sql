select 
	count(*) filter(where close is null) as close_null,
	count(*) filter(where date is null) as date_null,
	count(*) filter(where ticker is null) as ticker_null
from stg_prices sp 

select 
	count(*) filter(where company_name is null) as name_null,
	count(*) filter(where 'date' is null) as date_null,
	count(*) filter(where ticker is null) as ticker_null
from stg_companies sc 


select 
	count(*) filter(where revenue is null) as revenue_null,
	count(*) filter(where net_income is null) as net_null,
	count(*) filter(where total_assets is null) as assets_null,
	count(*) filter(where total_equity is null) as equity_null,
	count(*) filter(where total_debt is null) as debt_null,
	count(*) filter(where eps is null) as eps_null,
	count(*) filter(where fiscal_year is null) as Fyear_null,
	count(*) filter(where ticker is null) as ticker_null
from stg_fundamentals sf 

/* Layer 2 Check 1 — Nulls:
  - stg_companies: 0 nulls across all fields ✅
  - stg_prices: 0 nulls in date/ticker/close ✅
  - stg_fundamentals: <2% null rate across financial fields
    - revenue: 2 nulls (0.5%)
    - net_income: 6 nulls (1.5%)
    - total_assets: 2 nulls (0.5%)
    - total_equity: 2 nulls (0.5%)
    - total_debt: 5 nulls (1.2%) — some companies legitimately carry no debt
    - eps: 2 nulls (0.5%)
  - Verdict: Data quality is high. No remediation required.