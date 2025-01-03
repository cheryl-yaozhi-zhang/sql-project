-- PROJECT: Telco Churn Analysis
-- DATE: 2025-01-02
-- AUTHOR: Cheryl (Yaozhi) Zhang
-- DATA SOURCE: Kaggle

-- Extract IDs of churned customers
CREATE TABLE churn_schurn_status AS
	SELECT customer_id, churn_value
    FROM status_analysis;

-- PART 1: CUSTOMER FEEDBACK ANALYSIS

-- 1a) Churns by category: "Competitors" is the top and dominant reason for churn (account for ~45%)
SELECT churn_category, 
SUM(churn_value) / (SELECT SUM(churn_value) FROM status_analysis) AS percent_total
FROM status_analysis
WHERE churn_value != 0
GROUP BY churn_category;

-- 1b) Taking a deeper look, the primary reasons under "Competition" category are
-- "Competitor had better devices" and "Competitor made better offer" (~37% each within the category)
SELECT churn_reason, 
SUM(churn_value) / (SELECT SUM(churn_value) FROM status_analysis WHERE TRIM(churn_category) = 'Competitor') AS competitor_count
FROM status_analysis
WHERE TRIM(churn_category) = 'Competitor'
GROUP BY churn_reason;

-- PART 2: LOCATION ANALYSIS
-- 2a) By location, San Diego has the highest number of churns (185 customers), followed by Los Angeles (78) and San Francisco (31).
-- Despite San Diego having one of the company's biggest customer bases, its % churn is alarmingly high at 65%.
WITH churn_loc_cte AS
(
	SELECT loc.customer_id, loc.city, stat.churn_value
    FROM location_data AS loc
    LEFT JOIN status_analysis AS stat
    ON loc.customer_id = stat.customer_id
)
SELECT city,
COUNT(customer_id) AS Total_Customers,
SUM(churn_value) AS Churns,
SUM(churn_value)/COUNT(customer_id)*100 AS `% Churn`
FROM churn_loc_cte
GROUP BY city
ORDER BY Churns DESC;

-- 2b) And the reason is predominantly intense competition ("Competitor made better offer").
WITH churn_loc_reason_cte AS
(
	SELECT loc.customer_id, loc.city, stat.churn_value, stat.churn_reason
    FROM location_data AS loc
    LEFT JOIN status_analysis AS stat
    ON loc.customer_id = stat.customer_id
)
SELECT churn_reason,
SUM(churn_value) AS Churns
FROM churn_loc_reason_cte
WHERE city = 'San Diego'
GROUP BY churn_reason
ORDER BY Churns DESC;

-- PART 3: SERVICES ANALYSIS
-- 3a) The average number of services subscribed is similar between customers who have left (4.0) vs stayed (4.1).
-- This suggests that a greater number of services (cross-selling) doesn't make the customer base stickier.

WITH services_count AS
(
    SELECT customer_id,
        SUM(CASE WHEN phone_service = 'Yes' THEN 1 ELSE 0 END) +
        SUM(CASE WHEN internet_service = 'Yes' THEN 1 ELSE 0 END) +
        SUM(CASE WHEN online_security = 'Yes' THEN 1 ELSE 0 END) +
        SUM(CASE WHEN online_backup = 'Yes' THEN 1 ELSE 0 END) +
        SUM(CASE WHEN device_protection = 'Yes' THEN 1 ELSE 0 END) +
        SUM(CASE WHEN premium_tech_support = 'Yes' THEN 1 ELSE 0 END) +
        SUM(CASE WHEN streaming_tv = 'Yes' THEN 1 ELSE 0 END) +
        SUM(CASE WHEN streaming_movies = 'Yes' THEN 1 ELSE 0 END) +
        SUM(CASE WHEN streaming_music = 'Yes' THEN 1 ELSE 0 END) AS count
    FROM online_services
    GROUP BY customer_id
), service_churn AS
(
	SELECT serv.customer_id,
    count,
    churn_value
    FROM services_count AS serv
    LEFT JOIN status_analysis AS stat
    ON serv.customer_id = stat.customer_id
)
SELECT churn_value,
AVG(count) AS avg_serv_count
FROM service_churn
GROUP BY churn_value;

-- PART 4: PAYMENT TERMS ANALYSIS
-- 4a) Looking at churn rate by contract type, "Month-to-Month" has the highest churn rate (46% or almost half). In other words,
-- the monthly payment option offers little barriers for customers to switch and likely presents the less loyal customers.
-- "Two Year" contract type has the lowest churn rate (3%) as it provides a longer lock-in period.
SELECT contract,
SUM(churn_value)/COUNT(churn_value)*100 as `% Churn`
FROM payment_info AS pay
LEFT JOIN status_analysis AS stat
ON pay.customer_id = stat.customer_id
GROUP BY contract;

-- 4b) By payment method, "electronic check" has the highest churn rate (45% or almost half),
-- while "credit card (automatic)" (15%) and "bank transfer (automatic)" (17%) have the lowest churn rates.
-- It appears that automatic payment deductions result in better loyalty and payment adherence.
SELECT payment_method,
SUM(churn_value)/COUNT(churn_value)*100 as `% Churn`
FROM payment_info AS pay
LEFT JOIN status_analysis AS stat
ON pay.customer_id = stat.customer_id
GROUP BY payment_method;

-- 4c) By tenure, churn is highest for customers that have subscribed for less than two years (50% for 0-9 months, and 33% for 10-19 months)
-- which makes sense given that the low-loyalty customers have yet departed, although the 33-50% churn rate is still very high.
-- There is an inverse correlation between churn rates and tenure. The longer the customers stay with the company, the less likely that they will leave.
CREATE TEMPORARY TABLE rev_tenure AS
	SELECT tenure,
    (`monthly_ charges` + avg_monthly_long_distance_charges) AS monthly,
    total_revenue,
    churn_value
    FROM service_options AS serv
    LEFT JOIN payment_info AS pay
    ON serv.customer_id = pay.customer_id
    LEFT JOIN status_analysis AS stat
    ON serv.customer_id = stat.customer_id;

SELECT tenure_range,
SUM(churn_value)/COUNT(churn_value)*100 AS `% Churn`
FROM (SELECT churn_value,
	CASE WHEN tenure BETWEEN 0 AND 9 THEN '0-9'
    WHEN tenure BETWEEN 10 AND 19 THEN '10-19'
    WHEN tenure BETWEEN 20 and 29 THEN '20-29'
    WHEN tenure BETWEEN 30 and 39 THEN '30-39'
    WHEN tenure BETWEEN 40 and 49 THEN '40-49'
    WHEN tenure BETWEEN 50 and 59 THEN '50-59'
    WHEN tenure BETWEEN 60 and 69 THEN '60-69'
    WHEN tenure BETWEEN 70 and 79 THEN '70-79' END AS tenure_range
    FROM rev_tenure) AS t
GROUP BY t.tenure_range
ORDER BY t.tenure_range;

-- 4d) On average, customers who left have a ~14% lower monthly chargest ($84.15) than those who stayed ($97.61).
SELECT churn_value,
AVG(monthly)
FROM rev_tenure
GROUP BY churn_value;


-- PART 5: CHURN IMPACT
-- 5a) On a consolidated basis, 26% of the company's customer base has churned in the past month.
SELECT SUM(churn_value)/COUNT(churn_value)*100 AS `% of Customer Base Churned`
FROM status_analysis;

-- 5b) In dollar terms, the company is losing ~30% of its revenue from this month's customer churns.
WITH churn_rev_table AS
(
	SELECT (`monthly_ charges` + avg_monthly_long_distance_charges) AS monthly,
    churn_value
    FROM payment_info AS pay
    LEFT JOIN status_analysis AS stat
    ON pay.customer_id = stat.customer_id
)
SELECT churn.rev / total.rev * 100 AS `% Revenue Churned`
FROM (
	SELECT SUM(monthly) AS rev
    FROM churn_rev_table
    WHERE churn_value = 1
    ) AS churn
JOIN (
	SELECT SUM(monthly) AS rev
    FROM churn_rev_table
    ) AS total
ON 1 = 1;


-- PART 6: IDENTIFY AT-RISK CUSTOMERS
-- 6a) The churn score for actual churns ranges 65-96, while the churn score for customers that stayed range 5-80
SELECT MIN(churn_score) AS Low,
MAX(churn_score) AS High
FROM status_analysis
WHERE churn_value = 1;

SELECT MIN(churn_score) AS Low,
MAX(churn_score) AS High
FROM status_analysis
WHERE churn_value = 0;

-- 6b) ~27% of the remaining customer have a churn score at or above the lower bound of churn score
-- range for those that have churned in the past month. These customers are at risk of churning in
-- the future.
SELECT at_risk.count / remaining.count * 100 AS `% of Customers At Risk`
FROM (
	SELECT COUNT(customer_id) AS count
	FROM status_analysis
	WHERE churn_score >= (SELECT MIN(churn_score) FROM status_analysis WHERE churn_value = 1)
    AND churn_value = 0
    ) AS at_risk
JOIN (
	SELECT COUNT(customer_id) AS count
    FROM status_analysis
    WHERE churn_value = 0
    ) AS remaining
ON 1 = 1;

-- 6c) These at-risk customers also represent 27% of the company's monthly revenue (in the remaining customer base).
WITH churn_rev_table_2 AS
(
	SELECT (`monthly_ charges` + avg_monthly_long_distance_charges) AS monthly,
    churn_value,
    churn_score
    FROM payment_info AS pay
    LEFT JOIN status_analysis AS stat
    ON pay.customer_id = stat.customer_id
)
SELECT at_risk.rev / remaining.rev * 100 AS `% of Revenue At Risk`
FROM (
	SELECT SUM(monthly) AS rev
	FROM churn_rev_table_2
	WHERE churn_score >= (SELECT MIN(churn_score) FROM status_analysis WHERE churn_value = 1)
    AND churn_value = 0
    ) AS at_risk
JOIN (
	SELECT SUM(monthly) AS rev
    FROM churn_rev_table_2
    WHERE churn_value = 0
    ) AS remaining
ON 1 = 1;