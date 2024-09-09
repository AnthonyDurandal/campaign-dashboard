
-- 1-Overall RMOI

-- We will consider those values as our reference to tell "how good a marketing campaign is":
-- Negative RMOI: Campaign is losing money.
-- 0% to 100% = [0;1]: Break-even to low profit.
-- 100% to 400% = [1;4]: Moderate profit.
-- 400% to 900% = [4;9]: Good profit.
-- Above 900% = [9;+inf]: Exceptional profit.

CREATE OR REPLACE FUNCTION rmoi()
RETURNS REAL 
LANGUAGE PLPGSQL
AS
$$
    DECLARE rmoi_value REAL;
    BEGIN
        SELECT
            (SUM(revenue) - SUM(mark_spent))/ SUM(mark_spent)
            INTO rmoi_value
        FROM campaigns;
        RETURN rmoi_value;
    END
$$;
;

-- SELECT * FROM rmoi();
--     rmoi    
-- ------------
--  0.40203112

-- ROMI by campaigns

-- -> As a whole, the campaigns can be considered as a break-even to low profit.


-- 2-Let's see more in details which are perfoming well and which makes loosing money.

DROP VIEW IF EXISTS rmoi_by_campaign;
CREATE OR REPLACE VIEW rmoi_by_campaign AS
WITH r AS (
    SELECT
        campaign_name,
        (SUM(revenue) - SUM(mark_spent))/ SUM(mark_spent) AS rmoi
    FROM campaigns
    GROUP BY campaign_name
    ORDER BY rmoi DESC
) 
SELECT r.*,
    CASE
        WHEN r.rmoi < 0 THEN 'losing money'
        WHEN r.rmoi >= 0 AND r.rmoi < 1 THEN 'break-even to low profit'
        WHEN r.rmoi >= 1 AND r.rmoi < 4 THEN 'moderate profit'
        WHEN r.rmoi >= 4 AND r.rmoi < 9 THEN 'good profit'
        WHEN r.rmoi >= 9 THEN 'exceptional profit'
    END AS efficiency
    FROM r
;


-- select * from rmoi_by_campaign 
-- campaign_db-# ;
--     campaign_name     |          rmoi           |        efficiency        
-- ----------------------+-------------------------+--------------------------
--  youtube_blogger      |      2.7732066438861065 | moderate profit
--  facebook_retargeting |      1.0149608456936868 | moderate profit
--  google_hot           |  0.83812439939521270839 | break-even to low profit
--  instagram_tier1      |  0.77139683439674990296 | break-even to low profit
--  instagram_blogger    |  0.36754210796971357956 | break-even to low profit
--  banner_partner       |  0.22406168964072781984 | break-even to low profit
--  facebook_tier1       | -0.06565108704190873099 | losing money
--  facebook_tier2       | -0.26216420900040207113 | losing money
--  google_wide          | -0.33670273797531996652 | losing money
--  instagram_tier2      | -0.37114135742616859904 | losing money
--  facebook_lal         | -0.88635885509615277905 | losing money
-- (11 rows)


-- As we can see, only two campaigns make moderate profit, four makes low profit and five are not even profitable. This explains a bit why the global RMOI is so low.

-- 3-Performance of the campaign depending on the date - on which date did we spend the most money on advertising, when we got the biggest revenue when conversion rates were high and low? What were the average order values?
-- 
SELECT
    c_date,
    mark_spent
FROM campaigns
ORDER BY mark_spent
LIMIT 1;

-- when we got the biggest revenue when conversion rates were high and low
-- We will use those numbers as reference to tell how good is the convertion rate:
-- - Less than 1%: Very low conversion rate.
-- - 1% to 3%:Below average conversion rate.
-- - 3% to 5%: Average conversion rate.
-- - 5% to 10%: Good conversion rate.
-- - Above 10%: Excellent conversion rate.

-- conversions/total visitors
DROP VIEW IF EXISTS conversion_rate;
CREATE OR REPLACE VIEW conversion_rate AS
WITH c AS (
    SELECT
        100.0::REAL*leads::REAL/clicks::REAL AS rate,
        revenue
    FROM campaigns
    ORDER BY 100.0::REAL*leads::REAL/clicks::REAL DESC
) 
SELECT c.*,
    CASE
        WHEN c.rate < 1 THEN 'very low'
        WHEN c.rate >= 1 AND c.rate < 3 THEN 'below average'
        WHEN c.rate >= 3 AND c.rate < 5 THEN 'average'
        WHEN c.rate >= 5 AND c.rate < 10 THEN 'good conversion'
        WHEN c.rate >= 10 THEN 'excellent'
    END AS efficiency
    FROM c
;

-- result
-- SELECT * FROM conversion_rate LIMIT 5;
--    rate    | revenue  | efficiency 
-- -----------+----------+------------
--  4.5454545 |   4461.0 | average
--  3.9784262 | 237711.0 | average
--  3.9682539 | 262184.0 | average
--   3.935301 | 158340.0 | average
--  3.9156628 |      0.0 | average

SELECT 
    COUNT(*), 
    efficiency
FROM conversion_rate
GROUP BY efficiency;

-- result
--  count |  efficiency   
-- -------+---------------
--     67 | average
--    196 | below average
--     45 | very low

-- -> Most of the conversion are below average and the best conversion rate is average

-- Let's consider that a high conversion rate is a rate above 5% and a low conversion rate is a rate below 3%

-- biggest revenue from low conversion rate
SELECT
    rate,
    revenue
FROM conversion_rate
WHERE rate < 3
ORDER BY revenue DESC
LIMIT 1
;
-- result
--    rate    |  revenue  
-- -----------+-----------
--  2.0261886 | 1452540.0
-- (1 row)


-- biggest revenue from high conversion rate
SELECT
    rate,
    revenue
FROM conversion_rate
WHERE rate >= 5
ORDER BY revenue DESC
LIMIT 1
;

-- result (None)
--  rate | revenue 
-- ------+---------
-- (0 rows)
-- There is no conversion rate above agerage so there won't be high conversion rates

-- average order values
SELECT
    AVG(orders)
FROM campaigns;

--          avg         
-- ---------------------
--  26.1136363636363636
-- (1 row)



-- 4- When buyers are more active? What is the average revenue on weekdays and weekends?
-- We will calculate the average revenue per week days
CREATE OR REPLACE VIEW revenue_by_day_of_week AS
SELECT
    EXTRACT(dow FROM DATE_TRUNC('day', c_date)) AS day_of_week,
    revenue
FROM campaigns;

DROP VIEW IF EXISTS avg_revenue_per_day_of_week;
CREATE OR REPLACE VIEW avg_revenue_per_day_of_week AS
SELECT
    day_of_week,
    AVG(revenue) as avg_revenue
FROM revenue_by_day_of_week
GROUP BY day_of_week
ORDER BY avg_revenue DESC
;

-- SELECT * FROM avg_revenue_per_day_of_week;
-- result
--      avg_revenue     | day_of_week 
-- ---------------------+-------------
--  217594.886363636364 |           5
--  193713.681818181818 |           6
--  158495.340909090909 |           3
--  135362.977272727273 |           4
--  103125.795454545455 |           2
--   94992.204545454545 |           1
--   71473.431818181818 |           0

-- average revenue per weekdays

WITH revenue_by_week_period AS(
    SELECT 
        revenue,
        CASE WHEN day_of_week < 5 THEN 'weekday' ELSE 'weekend' END AS week_period
    FROM revenue_by_day_of_week
)
SELECT
    week_period,
    AVG(revenue) as avg_revenue
FROM revenue_by_week_period
GROUP BY week_period
ORDER BY avg_revenue DESC
;

-- result
--  week_period |     avg_revenue     
-- -------------+---------------------
--  weekend     | 205654.284090909091
--  weekday     | 112689.950000000000
-- (2 rows)

-- -> We can deduce that people spend almost as twice as much as on week period