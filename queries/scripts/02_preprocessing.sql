-- 2- Data Cleaning 

-- 2.1 Understanding the dataset

-- 2.2 Remove duplicates:
-- lets check the columns from the 
SELECT COUNT(campaign_id), campaign_id FROM campaigns GROUP BY campaign_id;
-- result
--  count | campaign_id 
-- -------+-------------
--     28 |      348934
--     28 |      349043
--     28 |    89459845
--     28 |       10934
--     28 |      983498
--     28 |      374754
--     28 |      544756
--     28 |       39889
--     28 |     4387490
--     28 |      127823
--     28 |     9034945

-- -> there are 11 campaigns that were measured 28 times each


-- Let's check that the campaign names doesn't have spelling/case issues
-- We check if each campaign has a unique name
SELECT COUNT(campaign_id) AS count_campaign_id, campaign_id
    FROM (
        SELECT  
            COUNT(campaign_id) as num_campaign_measures, 
            campaign_id,
            campaign_name 
        FROM campaigns 
        GROUP BY campaign_id, campaign_name
    ) AS num_campaign_per_id_and_name 
    GROUP BY campaign_id
    HAVING COUNT(campaign_id) > 1
;

-- result
--  count_campaign_id | campaign_id 
-- -------------------+-------------
-- (0 rows)
-- -> we can see that there is a single campaign_name for each campaign_id




-- There is no value feared to be duplicate because:
-- - [mark_spent, revenue] are amount of money
-- - [clicks, leads, orders] are quantities
-- - [campaign_id, campaign_name] there can be multiple metrics on the same campaign
-- - [c_date] can be duplicated because multiple campaign metrics could have been done the same date
-- - [category] can be duplicated among the dataset as multiple campaigns can share the same categories 
-- - [id] should be the only value without duplicate as it is the primary key 







-- 2.3 Handle Missing Data: counting the NULL values on each columns
CREATE VIEW null_count AS
    SELECT
        SUM( CASE WHEN campaign_id IS NULL THEN 1 ELSE 0 END ) AS campaign_id,
        SUM( CASE WHEN c_date IS NULL THEN 1 ELSE 0 END ) AS c_date,
        SUM( CASE WHEN campaign_name IS NULL THEN 1 ELSE 0 END ) AS campaign_name,
        SUM( CASE WHEN category IS NULL THEN 1 ELSE 0 END ) AS category,
        SUM( CASE WHEN impressions IS NULL THEN 1 ELSE 0 END ) AS impressions,
        SUM( CASE WHEN mark_spent IS NULL THEN 1 ELSE 0 END ) AS mark_spent,
        SUM( CASE WHEN clicks IS NULL THEN 1 ELSE 0 END ) AS clicks,
        SUM( CASE WHEN leads IS NULL THEN 1 ELSE 0 END ) AS leads,
        SUM( CASE WHEN orders IS NULL THEN 1 ELSE 0 END ) AS orders,
        SUM( CASE WHEN revenue IS NULL THEN 1 ELSE 0 END ) AS revenue
    FROM campaigns
;

-- Result
--  campaign_id | c_date | campaign_name | category | impressions | mark_spent | clicks | leads | orders | revenue 
-- -------------+--------+---------------+----------+-------------+------------+--------+-------+--------+---------
--            0 |      0 |             0 |        0 |           0 |          0 |      0 |     0 |      0 |       0

--  There is no NULL values in the dataset, so we don't need to fill any missing values




-- 2.4-Correct Inaccuracies:
-- we already have set constraints on each columns before inserting the data so we are sure that there is no inaccuraties in the data
-- Asumptions for each column:
--  - clicks <= impressions: because you can't have clicked without an impression
--  - leads <= clicks: because you can't have a lead without a click
--  - orders <= leads: because you can't order if you haven't created a lead 



-- 2.5-Standardize Formats:
-- we can see that there are still 11 campaigns after lowercase comparison. We can also see that there is no naming errors in the database
-- BUT, for ... purposes we will replace all campaign_names with their equivalent in lowercase
UPDATE campaigns SET campaign_name = LOWER(campaign_name);

-- 2.6-Filter Irrelevant Data:
-- there are no irrelevant columns in the "campaigns" table so we will skip this part


-- 3.1-Summary statistics + 2.7-Handle Outliers
-- search for the mean, median compare them
DROP FUNCTION IF EXISTS median;
CREATE OR REPLACE FUNCTION median(column_name varchar)
RETURNS BIGINT
LANGUAGE PLPGSQL
AS $$
    DECLARE median_value INT;
    BEGIN
        EXECUTE FORMAT('SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY %I) FROM campaigns', column_name) INTO median_value;
        RETURN median_value;
    END
$$;
SELECT median('impressions');

DROP FUNCTION IF EXISTS median_position;
CREATE OR REPLACE FUNCTION median_position(column_name varchar)
RETURNS REAL
LANGUAGE PLPGSQL
AS $$
    DECLARE position_value REAL;
    BEGIN
        EXECUTE FORMAT('SELECT 100.0*PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY %I) /(MAX(%I)-MIN(%I)) FROM campaigns', column_name,column_name,column_name) INTO position_value;
        RETURN position_value;
    END
$$;

CREATE OR REPLACE VIEW median_campaigns AS
SELECT
    median('impressions') AS impressions,
    median('mark_spent') AS mark_spent,
    median('clicks') AS clicks,
    median('leads') AS leads,
    median('orders') AS orders,
    median('revenue') AS revenue
;

CREATE OR REPLACE VIEW min_campaigns AS 
SELECT
    MIN(impressions) AS impressions,
    MIN(mark_spent) AS mark_spent,
    MIN(clicks) AS clicks,
    MIN(leads) AS leads,
    MIN(orders) AS orders,
    MIN(revenue) AS revenue
FROM campaigns;

CREATE OR REPLACE VIEW max_campaigns AS 
SELECT
    MAX(impressions) AS impressions,
    MAX(mark_spent) AS mark_spent,
    MAX(clicks) AS clicks,
    MAX(leads) AS leads,
    MAX(orders) AS orders,
    MAX(revenue) AS revenue
FROM campaigns;

CREATE OR REPLACE VIEW mean_campaigns AS 
SELECT
    AVG(impressions) AS impressions,
    AVG(mark_spent) AS mark_spent,
    AVG(clicks) AS clicks,
    AVG(leads) AS leads,
    AVG(orders) AS orders,
    AVG(revenue) AS revenue
FROM campaigns;

-- SELECT * FROM Min_campaigns;
--  impressions | mark_spent | clicks | leads | orders | revenue 
-- -------------+------------+--------+-------+--------+---------
--          667 |     169.75 |     20 |     0 |      0 |     0.0
-- (1 row)

-- campaign_db=# SELECT * FROM Median_campaigns;
--  impressions | mark_spent | clicks | leads | orders | revenue 
-- -------------+------------+--------+-------+--------+---------
--       602810 |      36765 |   4350 |    84 |      9 |   38917
-- (1 row)

-- campaign_db=# SELECT * FROM Max_campaigns;
--  impressions | mark_spent | clicks | leads | orders |  revenue  
-- -------------+------------+--------+-------+--------+-----------
--    419970000 |   880357.0 |  61195 |  1678 |    369 | 2812520.0
-- (1 row)

-- select* from mean_campaigns;
--      impressions      |     mark_spent     |        clicks         |        leads         |       orders        |       revenue       
-- ----------------------+--------------------+-----------------------+----------------------+---------------------+---------------------
--  5122475.321428571429 | 99321.038376623377 | 9739.9967532467532468 | 212.9188311688311688 | 26.1136363636363636 | 139251.188311688312
-- (1 row)

CREATE OR REPLACE VIEW median_position_campaigns AS
SELECT
    median_position('impressions') AS impressions,
    median_position('mark_spent') AS mark_spent,
    median_position('clicks') AS clicks,
    median_position('leads') AS leads,
    median_position('orders') AS orders,
    median_position('revenue') AS revenue
    FROM min_campaigns, median_campaigns
;





-- As we can see for all of the columns mentionned above(impressions, mark_spent, clicks, leads, orders, revenue) the data is asymetrical and is more skewed to the left with a longer tail on the right side. This skewnesss suggest the presence of outliers, which are values significantly higher than the majority of the data points.

-- Put simply, there are huge abnormal values on each of the columns (impressions, mark_spent, clicks, leads, orders, revenue).

-- We only have one table, it makes no sense to calculate the variance of the dataset bacause
CREATE OR REPLACE VIEW deviation_campaigns AS 
SELECT
    STDDEV(impressions) AS impressions,
    STDDEV(mark_spent) AS mark_spent,
    STDDEV(clicks) AS clicks,
    STDDEV(leads) AS leads,
    STDDEV(orders) AS orders,
    STDDEV(revenue) AS revenue
FROM campaigns;

-- select * from deviation_campaigns;
--   impressions  |   mark_spent    |     clicks     |      leads       |       orders        |     revenue     
-- ---------------+-----------------+----------------+------------------+---------------------+-----------------
--  26311343.5219 | 144008.01118132 | 12157.47624395 | 300.459978369644 | 42.7412875754433906 | 276303.11169181
-- (1 row)
