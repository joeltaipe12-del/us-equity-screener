/*data quality and checks

LAYER 1 - DO I HAVE ALL THE DATA   
 */

select COUNT(*) from stg_companies sc;

select COUNT(*) from stg_prices sp ;

select COUNT(*) from stg_fundamentals sf;

/*Check 1: stg_companies=102, stg_prices=7286, stg_fundamentals=406 ✅
