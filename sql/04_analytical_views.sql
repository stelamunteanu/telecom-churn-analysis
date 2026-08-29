-- VIEW 01: CUSTOMER 360
-- Granularity: 1 row per customer

CREATE OR REPLACE VIEW vw_customer_360 AS
SELECT
    c.customer_id,
	
	-- Demographics
	c.gender,
    c.age,
    c.married,
    c.number_of_dependents,
    CASE
        WHEN c.age BETWEEN 18 AND 25 THEN '18-25'
        WHEN c.age BETWEEN 26 AND 35 THEN '26-35'
        WHEN c.age BETWEEN 36 AND 45 THEN '36-45'
        WHEN c.age BETWEEN 46 AND 55 THEN '46-55'
        WHEN c.age BETWEEN 56 AND 65 THEN '56-65'
        ELSE '65+'
    END AS age_segment,

	-- Location
	l.city,
    l.zip_code,
    l.latitude,
    l.longitude,

	-- Services
	s.offer,
    s.phone_service,
    s.multiple_lines,
    s.internet_service,
    s.internet_type,
    s.online_security,
    s.online_backup,
    s.device_protection_plan,
    s.premium_tech_support,
    s.streaming_tv,
    s.streaming_movies,
    s.streaming_music,
    s.unlimited_data,
    s.contract,
    s.paperless_billing,
    s.payment_method,

	--Customer Lifecycle
	f.tenure_in_months,
    CASE
        WHEN f.tenure_in_months BETWEEN 0 AND 6
            THEN '0-6 months'
        WHEN f.tenure_in_months BETWEEN 7 AND 12
            THEN '7-12 months'
        WHEN f.tenure_in_months BETWEEN 13 AND 24
            THEN '13-24 months'
        WHEN f.tenure_in_months BETWEEN 25 AND 48
            THEN '25-48 months'
        ELSE '49+ months'
    END AS tenure_segment,

	-- Customer engagement
	 f.number_of_referrals,
    f.avg_monthly_gb_download,
    f.avg_monthly_long_distance_charges,
    CASE
        WHEN f.avg_monthly_gb_download < 50
            THEN 'Low Usage'
        WHEN f.avg_monthly_gb_download < 150
            THEN 'Medium Usage'
        ELSE 'High Usage'
    END AS usage_segment,

	--Financial metrics
	f.monthly_charge,
    f.total_charges,
    f.total_refunds,
    f.total_extra_data_charges,
    f.total_long_distance_charges,
    f.total_revenue,
	CASE
        WHEN f.monthly_charge < 40
            THEN 'Low'
        WHEN f.monthly_charge < 80
            THEN 'Medium'
        ELSE 'High'
    END AS monthly_charge_segment,

	--Customer ARPU/Value
	    ROUND(f.total_revenue /
            NULLIF(f.tenure_in_months, 0),
            2) AS customer_arpu,
	CASE
        WHEN f.total_revenue < 1000
            THEN 'Low Value'
        WHEN f.total_revenue < 3000
            THEN 'Medium Value'
        ELSE 'High Value'
    END AS customer_value_segment,

	-- Status
	st.customer_status,
    st.churn_category,
    st.churn_reason,

	-- Churn flag
	CASE
	    WHEN st.customer_status = 'Churned'
            THEN 1
        ELSE 0
    END AS churn_flag,

	-- Revenue at risk
	 CASE
        WHEN st.customer_status = 'Churned'
            THEN f.monthly_charge * 12
        ELSE 0
    END AS annualized_revenue_lost,

	-- Retention priority
	   CASE
        WHEN st.customer_status = 'Churned'
             AND f.total_revenue >= 3000
            THEN 'Critical - High Value Churned'
        WHEN st.customer_status = 'Stayed'
             AND f.tenure_in_months <= 12
             AND f.monthly_charge >= 80
            THEN 'High Priority - New High Charge'
        WHEN st.customer_status = 'Stayed'
             AND f.tenure_in_months <= 12
            THEN 'Medium Priority - Early Lifecycle'
        ELSE 'Standard'
    END AS retention_priority
FROM dim_customer c
LEFT JOIN dim_location l
    ON c.customer_id = l.customer_id
LEFT JOIN dim_services s
    ON c.customer_id = s.customer_id
LEFT JOIN fact_charges f
    ON c.customer_id = f.customer_id
LEFT JOIN dim_status st
    ON c.customer_id = st.customer_id;

SELECT COUNT(*) AS customers
FROM vw_customer_360;

SELECT
    customer_id,
    COUNT(*) AS rows_per_customer
FROM vw_customer_360
GROUP BY customer_id
HAVING COUNT(*) > 1;

-- VIEW 02: CHURN SUMMARY
-- Granularity: customer status

CREATE OR REPLACE VIEW vw_churn_summary AS
SELECT
    customer_status,
    COUNT(*) AS customers,
	COUNT(*) FILTER ( WHERE customer_status = 'Churned')
	    AS churned_customers,
	ROUND(COUNT(*) FILTER(WHERE customer_status='Churned')
	    * 100.0
	    /
		NULLIF (COUNT(*) FILTER(WHERE customer_status IN ('Churned', 'Stayed')), 0), 2)
		as churn_rate_pct,
	ROUND(AVG(tenure_in_months), 2) AS avg_tenure_months,
	ROUND(AVG(monthly_charge), 2) AS avg_monthly_charge,
	ROUND(SUM(total_revenue), 2) AS total_revenue,
	ROUND(AVG(total_revenue), 2) AS avg_revenue_per_customer
FROM vw_customer_360
GROUP BY customer_status;

SELECT * FROM vw_churn_summary;

-- VIEW 03: REVENUE BY CUSTOMER SEGMENT
-- Granularity: contract + value segment

CREATE OR REPLACE VIEW vw_revenue_by_segment AS
SELECT
    contract,
    customer_value_segment,
    COUNT(*) AS customers,
	ROUND(SUM(total_revenue), 2) AS total_revenue,
	ROUND(AVG(total_revenue), 2) avg_customer_revenue,
	ROUND(AVG(monthly_charge), 2) avg_monthly_charge,
	ROUND (SUM(total_revenue)
	    /
		NULLIF(SUM(tenure_in_months), 0), 2) AS arpu,
	ROUND(AVG(tenure_in_months), 2) AS avg_tenure_months,
	ROUND(COUNT(*) FILTER(WHERE customer_status='Churned')
	    * 100.0
	    /
		NULLIF (COUNT(*) FILTER(WHERE customer_status IN ('Churned', 'Stayed')), 0), 2)
		as churn_rate_pct
FROM vw_customer_360
GROUP BY contract, customer_value_segment
ORDER BY total_revenue DESC;

SELECT * FROM vw_revenue_by_segment;

-- VIEW 04: CHURN REASONS
-- Granularity: churn category + churn reason

CREATE OR REPLACE VIEW vw_churn_reasons AS
SELECT
    churn_category,
    churn_reason,
    COUNT(*) AS churned_customers,
	ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_of_all_churn,
	ROUND(SUM(total_revenue), 2) AS historical_revenue_from_churned_customers,
	ROUND(SUM(monthly_charge * 12), 2) AS annualized_revenue_lost,
	ROUND(AVG(monthly_charge), 2) avg_monthly_charge,
	ROUND(AVG(tenure_in_months), 2) AS avg_tenure_months
FROM vw_customer_360
WHERE customer_status = 'Churned'
GROUP BY churn_category, churn_reason
ORDER BY churned_customers DESC;

SELECT * FROM vw_churn_reasons;

-- VIEW 05: GEOGRAPHIC SUMMARY
-- Granularity: city

CREATE OR REPLACE VIEW vw_geo_summary AS
SELECT
    city,
    zip_code,
    ROUND(AVG(latitude), 6) AS latitude,
    ROUND(AVG(longitude), 6) AS longitude,
    COUNT(*) AS customers,
	COUNT(*) FILTER (WHERE customer_status = 'Churned'
	    ) AS churned_customers,
	ROUND(COUNT(*) FILTER(WHERE customer_status='Churned')
	    * 100.0
	    /
		NULLIF (COUNT(*) FILTER(WHERE customer_status IN ('Churned', 'Stayed')), 0), 2)
		as churn_rate_pct,
	ROUND(AVG(tenure_in_months), 2) AS avg_tenure_months,
	ROUND(AVG(monthly_charge), 2) AS avg_monthly_charge,
	ROUND(SUM(total_revenue), 2) AS total_revenue
FROM vw_customer_360
GROUP BY city, zip_code;

SELECT * FROM vw_geo_summary;

-- VIEW 06: SERVICE CHURN ANALYSIS
-- Granularity: service + service value
CREATE OR REPLACE VIEW vw_service_churn AS
SELECT
    service_name,
    service_value,
    COUNT(*) AS customers,
	COUNT(*) FILTER ( WHERE customer_status = 'Churned')
	    AS churned_customers,
	ROUND(COUNT(*) FILTER(WHERE customer_status='Churned')
	    * 100.0
	    /
		NULLIF (COUNT(*) FILTER(WHERE customer_status IN ('Churned', 'Stayed')), 0), 2)
		as churn_rate_pct,
	ROUND(AVG(monthly_charge), 2) AS avg_monthly_charge,
	ROUND(SUM(total_revenue), 2) AS total_revenue
FROM vw_customer_360
CROSS JOIN LATERAL (
    VALUES
    ('Online Security', CASE WHEN online_security THEN 'Yes' ELSE 'No'
	    END),
	('Online Backup', CASE WHEN online_backup THEN 'Yes' ELSE 'No'
	    END),
	('Device Protection', CASE  WHEN device_protection_plan THEN 'Yes' ELSE 'No'
	    END),
	('Premium Tech Support', CASE WHEN premium_tech_support THEN 'Yes' ELSE 'No'
	    END),
	('Streaming TV', CASE WHEN streaming_tv THEN 'Yes' ELSE 'No'
	    END),
	('Streaming Movies', CASE WHEN streaming_movies THEN 'Yes' ELSE 'No'
	    END),
	('Streaming Music', CASE WHEN streaming_music THEN 'Yes' ELSE 'No'
	    END)
) AS service_data (
    service_name,
    service_value)
GROUP BY service_name, service_value
ORDER BY service_name, churn_rate_pct DESC;

SELECT * FROM vw_service_churn;

-- VIEW 07: CONTRACT ANALYSIS
-- Granularity: contract

CREATE OR REPLACE VIEW vw_contract_analysis AS
SELECT
    contract,
    COUNT(*) AS customers,
    COUNT(*) FILTER (WHERE customer_status = 'Churned'
        ) AS churned_customers,
    COUNT(*) FILTER (WHERE customer_status = 'Stayed'
        ) AS stayed_customers,
		ROUND(COUNT(*) FILTER(WHERE customer_status='Churned')
	    * 100.0
	    /
		NULLIF (COUNT(*) FILTER(WHERE customer_status IN ('Churned', 'Stayed')), 0), 2)
		as churn_rate_pct,
	ROUND(AVG(monthly_charge), 2) avg_monthly_charge,
	ROUND(AVG(total_revenue), 2) AS avg_total_revenue,
	ROUND(AVG(tenure_in_months), 2) AS avg_tenure_months,
	ROUND(SUM(total_revenue), 2) AS total_revenue
FROM vw_customer_360
GROUP BY contract
ORDER BY churn_rate_pct DESC;

SELECT * FROM vw_contract_analysis;

-- VIEW 08: TENURE ANALYSIS
-- Granularity: tenure segment

CREATE OR REPLACE VIEW vw_tenure_analysis AS
SELECT
    tenure_segment,
	COUNT(*) AS customers,
	COUNT(*) FILTER (WHERE customer_status = 'Churned'
        ) AS churned_customers,
    COUNT(*) FILTER (WHERE customer_status = 'Stayed'
        ) AS stayed_customers,
	ROUND(COUNT(*) FILTER(WHERE customer_status='Churned')
	    * 100.0
	    /
		NULLIF (COUNT(*) FILTER(WHERE customer_status IN ('Churned', 'Stayed')), 0), 2)
		as churn_rate_pct,
	ROUND(AVG(total_revenue), 2) AS avg_total_revenue,
	ROUND(AVG(monthly_charge), 2) avg_monthly_charge
FROM vw_customer_360
GROUP BY tenure_segment
ORDER BY MIN(tenure_in_months);

SELECT * FROM vw_tenure_analysis;

-- VIEW 09: RETENTION PRIORITY
-- Granularity: customer

CREATE OR REPLACE VIEW vw_retention_priority AS
WITH customer_ranking AS (
    SELECT
	    customer_id,
        contract,
        tenure_in_months,
        monthly_charge,
        total_revenue,
        customer_status,
        churn_reason,
		NTILE(4) OVER (ORDER BY total_revenue DESC) AS revenue_quartile,
		NTILE(4) OVER (ORDER BY monthly_charge DESC) AS charge_quartile
	FROM vw_customer_360
)
SELECT
    customer_id,
    contract,
    tenure_in_months,
    monthly_charge,
    total_revenue,
    customer_status,
    churn_reason,
    revenue_quartile,
    charge_quartile,
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
FROM customer_ranking;

SELECT * FROM vw_retention_priority;

-- VIEW 10: EXECUTIVE KPI
-- One row containing dashboard-level KPIs

CREATE OR REPLACE VIEW vw_executive_kpi AS
SELECT
    COUNT(*) AS total_customers,
	COUNT(*) FILTER (WHERE customer_status = 'Churned'
        ) AS churned_customers,
    COUNT(*) FILTER (WHERE customer_status = 'Stayed'
        ) AS stayed_customers,
	COUNT(*) FILTER (WHERE customer_status = 'Joined'
	    ) AS joined_customers,
	ROUND(COUNT(*) FILTER(WHERE customer_status='Churned')
	    * 100.0
	    /
		NULLIF (COUNT(*) FILTER(WHERE customer_status IN ('Churned', 'Stayed')), 0), 2)
		as churn_rate_pct,
	ROUND (SUM(total_revenue)
	    /
		NULLIF(SUM(tenure_in_months), 0), 2) AS arpu,
	ROUND(AVG(tenure_in_months), 2) AS avg_tenure_months,
	ROUND(SUM(
	    CASE
	        WHEN customer_status='Churned'
		    THEN monthly_charge*12
		    ELSE 0
		END), 2) AS annualized_revenue_lost
FROM vw_customer_360;
	
SELECT * FROM vw_executive_kpi;