select ticker ,count(*) as years
from stg_fundamentals sf 
	group by ticker 
	order by years ASC;
