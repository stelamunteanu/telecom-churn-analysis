-- Data quality
-- 1.1 Basic row and customer count
SELECT
    COUNT(*) AS staging_rows,
    COUNT(DISTINCT customer_id) AS unique_customers
FROM staging_telecom_churn;

-- 1.2 Missing values on critical columns
SELECT
    COUNT(*) AS total_rows,
 
    COUNT(*) FILTER (WHERE customer_id IS NULL) AS missing_customer_id,
    COUNT(*) FILTER (WHERE gender IS NULL) AS missing_gender,
    COUNT(*) FILTER (WHERE age IS NULL) AS missing_age,
    COUNT(*) FILTER (WHERE city IS NULL) AS missing_city,
    COUNT(*) FILTER (WHERE tenure_in_months IS NULL) AS missing_tenure,
    COUNT(*) FILTER (WHERE contract IS NULL) AS missing_contract,
    COUNT(*) FILTER (WHERE monthly_charge IS NULL) AS missing_monthly_charge,
    COUNT(*) FILTER (WHERE total_charges IS NULL) AS missing_total_charges,
    COUNT(*) FILTER (WHERE total_revenue IS NULL) AS missing_total_revenue,
    COUNT(*) FILTER (WHERE customer_status IS NULL) AS missing_customer_status,
 
    COUNT(*) FILTER (
        WHERE customer_status = 'Churned' AND churn_category IS NULL
    ) AS churned_missing_category,
 
    COUNT(*) FILTER (
        WHERE customer_status = 'Churned' AND churn_reason IS NULL
    ) AS churned_missing_reason
 
FROM staging_telecom_churn;

-- SECTION 2: CATEGORICAL VALUE DISTRIBUTIONS

-- 2.1 customer status
SELECT
    customer_status,
    COUNT(*) AS customers
FROM staging_telecom_churn
GROUP BY customer_status
ORDER BY customers DESC;
--Values found: Stayed, Churned, Joined

-- 2.2 constract type
SELECT
    contract,
    COUNT(*) AS customers
FROM staging_telecom_churn
GROUP BY contract
ORDER BY customers DESC;
--Values found: Month-to-Month, Two Year, One Year

--2.3 payment method
SELECT
    payment_method,
    COUNT(*) AS customers
FROM staging_telecom_churn
GROUP BY payment_method
ORDER BY customers DESC;
--Values found: Bank Withdrawal, Credit Card, Mailed Check

-- 2.4 internet type
SELECT
    internet_type,
    COUNT(*) AS customers
FROM staging_telecom_churn
GROUP BY internet_type
ORDER BY customers DESC;
--Values found: Fiber Optic, DSL, Cable, and 1,526 NULLs
-- (expected: customers without an internet subscription)

-- SECTION 3: REFERENTIAL INTEGRITY ACROSS NORMALIZED TABLES
-- 3.1 Orphans: present in dim_customer but missing from the
--     other normalized tables
SELECT c.customer_id
FROM dim_customer c
LEFT JOIN fact_charges f ON f.customer_id = c.customer_id
LEFT JOIN dim_status st  ON st.customer_id = c.customer_id
LEFT JOIN dim_services s ON s.customer_id = c.customer_id
LEFT JOIN dim_location l ON l.customer_id = c.customer_id
WHERE f.customer_id IS NULL
   OR st.customer_id IS NULL
   OR s.customer_id IS NULL
   OR l.customer_id IS NULL;

-- SECTION 4: BUSINESS-LOGIC CONSISTENCY CHECKS
-- 4.1 Logical inconsistency: tenure = 0 but charges exist
SELECT customer_id, tenure_in_months, total_charges
FROM fact_charges
WHERE tenure_in_months = 0 AND total_charges > 0;
-- none found

-- 4.2 "Churned" customers missing Churn Category / Churn Reason
SELECT customer_id, customer_status, churn_category, churn_reason
FROM dim_status
WHERE customer_status = 'Churned'
  AND (churn_category IS NULL OR churn_reason IS NULL);
-- none found

-- 4.3 Reverse check: non-churned customers that DO have
--     Churn Category / Churn Reason filled in (should not happen)
SELECT customer_id, customer_status, churn_category, churn_reason
FROM dim_status
WHERE customer_status <> 'Churned'
  AND (churn_category IS NOT NULL OR churn_reason IS NOT NULL);
-- none found

-- 4.4 Internet Type filled in for customers without Internet Service
SELECT s.customer_id, s.internet_service, s.internet_type
FROM dim_services s
WHERE s.internet_service = FALSE AND s.internet_type IS NOT NULL;
-- none found

-- 4.5 Negative values where they don't make logical sense
-- ------------------------------------------------------------
SELECT customer_id, total_refunds, total_extra_data_charges,
       total_long_distance_charges, monthly_charge
FROM fact_charges
WHERE total_refunds < 0
   OR total_extra_data_charges < 0
   OR total_long_distance_charges < 0
   OR monthly_charge < 0;
-- Result: several negative values found, mostly on total_refunds
-- (see Section 6.2 for a dedicated investigation). Negative refunds
-- are consistent with the revenue formula validated in 4.6, so they
-- look like a sign convention rather than a data error - but
-- monthly_charge < 0 would be a genuine issue and is worth a
-- separate look if it ever appears.

-- 4.6 Formula consistency: Total Revenue should be (approximately)
--     Total Charges - Total Refunds + Total Extra Data Charges
--     + Total Long Distance Charges
SELECT
    f.customer_id,
    f.total_charges,
    f.total_refunds,
    f.total_extra_data_charges,
    f.total_long_distance_charges,
    f.total_revenue,
    ROUND(
        f.total_charges - f.total_refunds
        + f.total_extra_data_charges + f.total_long_distance_charges, 2
    ) AS total_revenue_calculat,
    ROUND(
        f.total_revenue - (f.total_charges - f.total_refunds
        + f.total_extra_data_charges + f.total_long_distance_charges), 2
    ) AS diferenta
FROM fact_charges f
WHERE ABS(
        f.total_revenue - (f.total_charges - f.total_refunds
        + f.total_extra_data_charges + f.total_long_distance_charges)
      ) > 1.00   -- toleranta de 1 unitate monetara pentru rotunjiri
-- Result: no rows returned - the formula holds for every customer

-- 4.7 Consistency: Total Charges should be close to
--     Monthly Charge * Tenure in Months
SELECT
    f.customer_id,
    f.monthly_charge,
    f.tenure_in_months,
    f.total_charges,
    ROUND(f.monthly_charge * f.tenure_in_months, 2) AS total_charges_estimat,
    ROUND(f.total_charges - (f.monthly_charge * f.tenure_in_months), 2) AS diferenta
FROM fact_charges f
WHERE f.tenure_in_months > 0
  AND ABS(f.total_charges - (f.monthly_charge * f.tenure_in_months)) >
      GREATEST(f.monthly_charge, 10)  -- toleranta relativa la o luna de abonament
ORDER BY diferenta DESC
LIMIT 50;
-- Result: major differences found, ranging from ~1,800 to ~8,000.
-- Why it matters: large deviations may indicate rate changes over
-- time (plan upgrade/downgrade) - useful to know before feature
-- engineering.

-- SECTION 5: OUTLIER CHECKS
-- 5.1 Age outliers
SELECT customer_id, age
FROM dim_customer
WHERE age < 18 OR age > 100;
-- no issues found 

-- 5.2 Zip code format (valid = 5 digits)
SELECT customer_id, zip_code
FROM dim_location
WHERE zip_code !~ '^\d{5}$';
-- no issues found 

--Phone Service / Multiple Lines consistency
SELECT *
FROM staging_telecom_churn
WHERE phone_service = 'No'
  AND multiple_lines = 'Yes';
-- no issues found

-- SECTION 6: DEEP-DIVE INVESTIGATIONS
-- 6.1 Billing differences: top 20 customers by absolute
--     difference between Total Charges and Monthly Charge x Tenure,
--     without a materiality threshold (complements check 4.7)

SELECT
    customer_id,
    monthly_charge,
    tenure_in_months,
    total_charges,

    ROUND(
        monthly_charge * tenure_in_months,
        2
    ) AS estimated_total_charges,

    ROUND(
        total_charges -
        (monthly_charge * tenure_in_months),
        2
    ) AS difference

FROM fact_charges

WHERE tenure_in_months > 0

ORDER BY ABS(
    total_charges -
    (monthly_charge * tenure_in_months)
) DESC

LIMIT 20;
-- Total Charges differs from Monthly Charge x Tenure for a
-- substantial number of customers, which may reflect changes in
-- plans, pricing, or services during the customer lifecycle.

-- 6.2 Negative refunds investigation
SELECT
    COUNT(*) AS negative_refund_rows,
    MIN(total_refunds) AS minimum_refund,
    MAX(total_refunds) AS maximum_refund
FROM fact_charges
WHERE total_refunds < 0;

SELECT
    customer_id,
    total_charges,
    total_refunds,
    total_extra_data_charges,
    total_long_distance_charges,
    total_revenue
FROM fact_charges
WHERE total_refunds < 0
ORDER BY total_refunds
LIMIT 20;

-- SECTION 7: SUMMARY VALIDATIONS
-- 7.1 Revenue formula validation summary
WITH revenue_check AS (
    SELECT
        customer_id,
        total_revenue,
        (
            total_charges
            - total_refunds
            + total_extra_data_charges
            + total_long_distance_charges
        ) AS calculated_revenue
    FROM fact_charges
)
SELECT
    COUNT(*) AS total_customers,
    COUNT(*) FILTER (
        WHERE ABS(total_revenue - calculated_revenue) <= 1
    ) AS matching_customers,
    COUNT(*) FILTER (
        WHERE ABS(total_revenue - calculated_revenue) > 1
    ) AS inconsistent_customers,
    ROUND(MAX(ABS(total_revenue - calculated_revenue)), 2) AS max_difference
FROM revenue_check;
-- Revenue consistency was validated across the full customer population.

-- 7.2 Customer status distribution
SELECT
    customer_status,
    COUNT(*) AS customers,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS customer_pct
FROM dim_status
GROUP BY customer_status
ORDER BY customers DESC;

-- SECTION 8: ANALYTICAL VIEW
-- One row per customer, combining all normalized tables
CREATE OR REPLACE VIEW vw_customer_analysis AS

SELECT
    c.customer_id,

    -- Demographics
    c.gender,
    c.age,
    c.married,
    c.number_of_dependents,

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

    -- Charges and usage
    f.tenure_in_months,
    f.number_of_referrals,
    f.avg_monthly_long_distance_charges,
    f.avg_monthly_gb_download,
    f.monthly_charge,
    f.total_charges,
    f.total_refunds,
    f.total_extra_data_charges,
    f.total_long_distance_charges,
    f.total_revenue,

    -- Status
    st.customer_status,
    st.churn_category,
    st.churn_reason

FROM dim_customer c
LEFT JOIN dim_location l ON c.customer_id = l.customer_id
LEFT JOIN dim_services s ON c.customer_id = s.customer_id
LEFT JOIN fact_charges f ON c.customer_id = f.customer_id
LEFT JOIN dim_status st  ON c.customer_id = st.customer_id;

-- 8.1 Sanity check
SELECT *
FROM vw_customer_analysis
LIMIT 10;

SELECT COUNT(*)
FROM vw_customer_analysis;
