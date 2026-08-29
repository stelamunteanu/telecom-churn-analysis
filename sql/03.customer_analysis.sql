-- BQ01. Total customer base
SELECT
    COUNT(*) AS total_customers
FROM vw_customer_analysis;

-- BQ2. Customer status distribution
SELECT
    customer_status,
    COUNT(*) AS customers,
    ROUND(COUNT(*) * 100.0 /SUM(COUNT(*)) OVER (), 2)
    AS customer_pct
FROM vw_customer_analysis
GROUP BY customer_status
ORDER BY customers DESC;

-- BQ3. Overall churn rate
-- For this dataset the formula used to define churn rate is:
-- Churn Rate = Churned / (Churned + Stayed)
SELECT 
    COUNT(*) FILTER (WHERE customer_status='Churned') AS churned_customers,
	COUNT (*) FILTER (WHERE customer_status='Stayed') AS stayed_customers,
	ROUND(COUNT(*) FILTER (WHERE customer_status='Churned') * 100
	    /
		NULLIF(COUNT(*) FILTER (WHERE customer_status IN ('Churned', 'Stayed')),
		0),
		2) AS churn_rate_pct
FROM vw_customer_analysis;
-- churn_rate_pct=28.00

-- BQ4. Why are customers leaving?
SELECT
    churn_category,
	COUNT (*) AS churned_customers,
	ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_of_churn
FROM vw_customer_analysis
WHERE customer_status = 'Churned'
GROUP BY churn_category
ORDER BY churned_customers DESC;

--BQ5. Top churn reasons
SELECT
    churn_reason,
    COUNT(*) AS churned_customers,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS pct_of_churn
FROM vw_customer_analysis
WHERE customer_status='Churned'
    AND churn_reason IS NOT NULL
GROUP BY churn_reason
ORDER BY churned_customers DESC
Limit 15;

-- BQ6. Does churn vary by contract?
SELECT
    contract,
	COUNT(*) FILTER (WHERE customer_status IN ('Churned', 'Stayed')) AS customers,
	COUNT(*) FILTER (WHERE customer_status='Churned') AS churned_customers,
	ROUND(COUNT(*) FILTER (WHERE customer_status='Churned') * 100.0 
	    /
		NULLIF(COUNT(*) FILTER (WHERE customer_status IN ('Churned', 'Stayed')),
		0), 2) AS churn_rate_pct,
	ROUND(AVG(total_revenue), 2) AS avg_total_revenue,
	ROUND(AVG(monthly_charge), 2) AS avg_monthly_charge
FROM vw_customer_analysis
GROUP BY contract
ORDER BY churn_rate_pct;

-- BQ7. Does churn vary by tenure?
WITH tenure_segments AS (
    SELECT *,
	    CASE 
		    WHEN tenure_in_months BETWEEN 0 AND 6 THEN '0-6 months'
			WHEN tenure_in_months BETWEEN 7 AND 12 THEN '7-12 months'
			WHEN tenure_in_months BETWEEN 13 AND 24 THEN '13-24 months'
			WHEN tenure_in_months BETWEEN 25 AND 48 THEN '25-48 months'
			ELSE '49+ months'
		END AS tenure_segment
	FROM vw_customer_analysis
)

Select
    tenure_segment,
	COUNT(*) FILTER(WHERE customer_status IN ('Churned', 'Stayed')) as customers,
	COUNT(*) FILTER(WHERE customer_status='Churned') AS churned_customers,
	ROUND(COUNT(*) FILTER(WHERE customer_status='Churned')
	* 100.0
	    /
		NULLIF (COUNT(*) FILTER(WHERE customer_status IN ('Churned', 'Stayed')), 0), 2)
		as churn_rate_pct,
	ROUND(AVG(monthly_charge), 2) AS avg_monthly_charge
FROM tenure_segments
GROUP BY tenure_segment
ORDER BY MIN(tenure_in_months);

-- BQ8. Which age groups have the highest churn?
WITH age_segments AS (
    SELECT *,
	    CASE
		    WHEN age BETWEEN 18 AND 25 THEN '18-25'
			WHEN age BETWEEN 26 AND 35 THEN '26-35'
			WHEN age BETWEEN 36 AND 45 THEN '36-45'
			WHEN age BETWEEN 46 AND 55 THEN '46-55'
			WHEN age BETWEEN 56 AND 65 THEN '56-65'
			ELSE '65+'
		END AS age_segment
	from vw_customer_analysis
)
SELECT 
    age_segment,
	COUNT(*) AS customers,
	COUNT(*) FILTER(WHERE customer_status='Churned') AS churned_customers,
	ROUND(COUNT(*) FILTER(WHERE customer_status='Churned') * 100.0
	    /
		NULLIF (COUNT(*) FILTER(WHERE customer_status IN ('Churned', 'Stayed')), 0), 2)
		as churn_rate_pct
FROM age_segments
GROUP BY age_segment
ORDER BY min(age);
-- BQ9. Does internet type affect churn?
SELECT 
    internet_type,
	COUNT(*) FILTER(WHERE customer_status IN ('Churned', 'Stayed')) as customers,
	COUNT(*) FILTER(WHERE customer_status='Churned') AS churned_customers,
	ROUND(COUNT(*) FILTER(WHERE customer_status='Churned')
	* 100.0
	    /
		NULLIF (COUNT(*) FILTER(WHERE customer_status IN ('Churned', 'Stayed')), 0), 2)
		as churn_rate_pct,
		ROUND(AVG(monthly_charge), 2) AS avg_monthly_charge
FROM vw_customer_analysis
WHERE internet_service = TRUE
GROUP BY internet_type
ORDER BY churn_rate_pct DESC;

-- BQ10. Does payment method matter?
SELECT
    payment_method,
	COUNT(*) FILTER(WHERE customer_status IN ('Churned', 'Stayed')) as customers,
	COUNT(*) FILTER(WHERE customer_status='Churned') AS churned_customers,
	ROUND(COUNT(*) FILTER(WHERE customer_status='Churned')
	* 100.0
	    /
		NULLIF (COUNT(*) FILTER(WHERE customer_status IN ('Churned', 'Stayed')), 0), 2)
		as churn_rate_pct
from vw_customer_analysis
GROUP BY payment_method
ORDER BY churn_rate_pct DESC;

-- BQ11. Are services associated with lower/higher churn?
WITH service_data AS (
    SELECT
        customer_id,
        customer_status,
        online_security,
        online_backup,
        device_protection_plan,
        premium_tech_support,
        streaming_tv,
        streaming_movies,
        streaming_music

    FROM vw_customer_analysis
)

SELECT
    service_name,
    service_value,
    COUNT(*) AS customers,
	COUNT(*) FILTER(WHERE customer_status='Churned') AS churned_customers,
	ROUND(COUNT(*) FILTER(WHERE customer_status='Churned')
	* 100.0
	    /
		NULLIF (COUNT(*) FILTER(WHERE customer_status IN ('Churned', 'Stayed')), 0), 2)
		as churn_rate_pct
FROM service_data

CROSS JOIN LATERAL (
    VALUES
        ('Online Security',
         CASE WHEN online_security THEN 'Yes' ELSE 'No' END),
        ('Online Backup',
         CASE WHEN online_backup THEN 'Yes' ELSE 'No' END),
        ('Device Protection',
         CASE WHEN device_protection_plan THEN 'Yes' ELSE 'No' END),
        ('Premium Tech Support',
         CASE WHEN premium_tech_support THEN 'Yes' ELSE 'No' END),
        ('Streaming TV',
         CASE WHEN streaming_tv THEN 'Yes' ELSE 'No' END),
        ('Streaming Movies',
         CASE WHEN streaming_movies THEN 'Yes' ELSE 'No' END),
        ('Streaming Music',
         CASE WHEN streaming_music THEN 'Yes' ELSE 'No' END)
) AS services(service_name, service_value)
GROUP BY
    service_name,
    service_value
ORDER BY
    service_name,
    churn_rate_pct DESC;

-- BQ12. Revenue
SELECT
    ROUND(SUM(total_revenue), 2) AS total_revenue,
	ROUND(AVG(total_revenue), 2) AS avg_customer_revenue,
	ROUND(AVG(monthly_charge), 2) AS avg_monthly_charge,
	ROUND(AVG(tenure_in_months), 2) AS avg_tenure
FROM vw_customer_analysis;

-- BQ13. Revenue by customer status
Select 
    customer_status,
	ROUND(SUM(total_revenue), 2) AS total_revenue,
	ROUND(AVG(total_revenue), 2) AS avg_customer_revenue
FROM vw_customer_analysis
GROUP BY customer_status
ORDER BY total_revenue DESC;

-- BQ14. ARPU
-- ARPU = Total Revenue / Total Tenure Months
SELECT 
    ROUND (SUM(total_revenue)
	    /
		NULLIF(SUM(tenure_in_months), 0), 2) AS arpu
FROM vw_customer_analysis;

-- BQ15. ARPY by contract
SELECT
    contract,
	ROUND (SUM(total_revenue)
	    /
		NULLIF(SUM(tenure_in_months), 0), 2) AS arpu,
	ROUND(AVG(monthly_charge), 2) AS avg_monthly_charge
FROM vw_customer_analysis
GROUP BY contract
ORDER BY arpu DESC;

-- BQ16. How much revenue is associated with churned customers?
SELECT 
    COUNT(*) AS churned_customers,
	ROUND(SUM(total_revenue), 2) AS historical_revenue_from_churned_customers,
	ROUND(SUM(monthly_charge * 12), 2) AS annualized_revenue_at_risk
FROM vw_customer_analysis
WHERE customer_status='Churned';

-- BQ17. Highest-value customers
WITH customer_value AS (
    SELECT
        customer_id,
        total_revenue,
        customer_status,
        NTILE(4) OVER (ORDER BY total_revenue DESC) AS revenue_quartile
    FROM vw_customer_analysis
)
SELECT
    revenue_quartile,
    COUNT(*) AS customers,
    ROUND(AVG(total_revenue),2) AS avg_revenue,
    ROUND(SUM(total_revenue),2) AS total_revenue
FROM customer_value
GROUP BY revenue_quartile
ORDER BY revenue_quartile;

--BQ18 — Which high-value customers have churned?
WITH customer_value AS (
    SELECT
        customer_id,
        total_revenue,
        monthly_charge,
        tenure_in_months,
        customer_status,
        NTILE(4) OVER (ORDER BY total_revenue DESC) AS revenue_quartile
    FROM vw_customer_analysis
)
SELECT
    customer_id,
    total_revenue,
    monthly_charge,
    tenure_in_months,
    customer_status
FROM customer_value
WHERE revenue_quartile = 1
  AND customer_status = 'Churned'
ORDER BY total_revenue DESC;

-- BQ19 — Which customers should be prioritized?
WITH customer_scoring AS (
    SELECT
        customer_id,
        contract,
        tenure_in_months,
        monthly_charge,
        total_revenue,
        customer_status,
        NTILE(4) OVER (ORDER BY total_revenue DESC) AS revenue_quartile,
        NTILE(4) OVER (ORDER BY monthly_charge DESC) AS charge_quartile
    FROM vw_customer_analysis
	WHERE customer_status IN ('Stayed', 'Churned'))
SELECT
	customer_id,
    contract,
    tenure_in_months,
    monthly_charge,
    total_revenue,
    customer_status,
	CASE
	    WHEN revenue_quartile=1 and customer_status = 'Churned'
	        THEN 'Critical - High Value Churned'
	    WHEN revenue_quartile=1 and tenure_in_months <= 12
	        THEN 'High Priority - High Value New Customer'
		WHEN revenue_quartile IN (1,2) and charge_quartile = 1
		    THEN 'High Priority - High Charge'
		WHEN tenure_in_months <= 12
		    THEN 'Medium Priority - Early Lifecycle'
		ELSE 'Low priority'
	END AS retention_priority
FROM customer_scoring
ORDER BY
    CASE
	    WHEN revenue_quartile = 1 AND customer_status = 'Churned' THEN 1
		WHEN revenue_quartile = 1 AND tenure_in_months <= 12 THEN 2
		WHEN revenue_quartile IN (1,2) AND charge_quartile = 1 THEN 3
		WHEN tenure_in_months <= 12 THEN 4
		ELSE 5
	END,
	total_revenue DESC;

-- BQ20. Which cities have unusually high churn?
WITH city_churn AS (
    SELECT
	    city,
		Count(*) FILTER (WHERE customer_status IN ('Churned', 'Stayed')) AS customers,
		Count (*) FILTER (WHERE customer_status='Churned') AS churned_customers
	from vw_customer_analysis
		GROUP BY city
),
overall_churn AS (
    SELECT 
	    COUNT (*) FILTER (WHERE customer_status='Churned') *100.0
		    /
			NULLIF(COUNT(*) FILTER(WHERE customer_status IN ('Churned', 'Stayed')), 0) 
			AS overall_churn_rate
	from vw_customer_analysis 
),
Select
    c.city,
	c.customers,
	c.churned_customers,
	ROUND (c.churned_customers * 100.0 / NULLIF(c.customers, 0), 2) 
	    AS churn_rate_pct,
	ROUND (o.overall_churn_rate, 2) AS overall_churn_rate_pct
from city_churn c
CROSS JOIN overall_churn o
WHERE c.customers >= 20
    AND c.churned_customers * 100.0 / NULLIF(c.customers, 0) > o.overall_churn_rate
ORDER BY churn_rate_pct DESC;

-- BQ.21 Usage vs Churn
WITH usage_segments AS (
    SELECT
	    *,
		CASE
		    WHEN avg_monthly_gb_download < 50 THEN 'Low Usage'
			WHEN avg_monthly_gb_download < 150 THEN 'Medium Usage'
			ELSE 'High Usage'
		END AS usage_segment
	from vw_customer_analysis 
)
SELECT
    usage_segment,
	Count(*) FILTER (WHERE customer_status IN ('Churned', 'Stayed')) AS customers,
	Count (*) FILTER (WHERE customer_status='Churned') AS churned_customers,
	ROUND(COUNT(*) FILTER(WHERE customer_status='Churned')
	* 100.0
	    /
		NULLIF (COUNT(*) FILTER(WHERE customer_status IN ('Churned', 'Stayed')), 0), 2)
		as churn_rate_pct,
	ROUND(AVG(monthly_charge), 2) AS avg_monthly_charge
from usage_segments
GROUP BY usage_segment
ORDER BY MIN(avg_monthly_gb_download);

-- BQ22. Number of services vs churn
WITH service_count AS (
    SELECT
        customer_id,
        customer_status,
        (
            CASE WHEN online_security THEN 1 ELSE 0 END +
            CASE WHEN online_backup THEN 1 ELSE 0 END +
            CASE WHEN device_protection_plan THEN 1 ELSE 0 END +
            CASE WHEN premium_tech_support THEN 1 ELSE 0 END +
            CASE WHEN streaming_tv THEN 1 ELSE 0 END +
            CASE WHEN streaming_movies THEN 1 ELSE 0 END +
            CASE WHEN streaming_music THEN 1 ELSE 0 END
        ) AS additional_services
    FROM vw_customer_analysis
)
SELECT 
    additional_services,
	COUNT(*) AS customers,
	COUNT(*) FILTER (WHERE customer_status = 'Churned')
	    AS churned_customers,
	ROUND(COUNT(*) FILTER (WHERE customer_status = 'Churned'
	    ) * 100.0
		/
		NULLIF(COUNT(*) FILTER (WHERE customer_status IN ('Churned', 'Stayed')),
		0), 2) AS churn_rate_pct
FROM service_count
GROUP BY additional_services
ORDER BY additional_services;