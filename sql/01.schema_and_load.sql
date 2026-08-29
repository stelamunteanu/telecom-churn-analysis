-- Staging table
CREATE TABLE staging_telecom_churn (
    customer_id                          VARCHAR(20),
    gender                                VARCHAR(10),
    age                                   INT,
    married                               VARCHAR(5),
    number_of_dependents                  INT,
    city                                  VARCHAR(100),
    zip_code                              VARCHAR(10),
    latitude                              NUMERIC(9,6),
    longitude                             NUMERIC(9,6),
    number_of_referrals                   INT,
    tenure_in_months                      INT,
    offer                                 VARCHAR(50),
    phone_service                         VARCHAR(5),
    avg_monthly_long_distance_charges     NUMERIC(10,2),
    multiple_lines                        VARCHAR(5),
    internet_service                      VARCHAR(5),
    internet_type                         VARCHAR(30),
    avg_monthly_gb_download               NUMERIC(10,2),
    online_security                       VARCHAR(5),
    online_backup                         VARCHAR(5),
    device_protection_plan                VARCHAR(5),
    premium_tech_support                  VARCHAR(5),
    streaming_tv                          VARCHAR(5),
    streaming_movies                      VARCHAR(5),
    streaming_music                       VARCHAR(5),
    unlimited_data                        VARCHAR(5),
    contract                              VARCHAR(30),
    paperless_billing                     VARCHAR(5),
    payment_method                        VARCHAR(30),
    monthly_charge                        NUMERIC(10,2),
    total_charges                         NUMERIC(12,2),
    total_refunds                         NUMERIC(12,2),
    total_extra_data_charges              NUMERIC(12,2),
    total_long_distance_charges           NUMERIC(12,2),
    total_revenue                         NUMERIC(12,2),
    customer_status                       VARCHAR(20),
    churn_category                        VARCHAR(50),
    churn_reason                          VARCHAR(200)
);

-- star schema 
CREATE TABLE dim_customer (
    customer_id             VARCHAR(20) PRIMARY KEY,
    gender                  VARCHAR(10),
    age                     INT CHECK (age >= 0),
    married                 BOOLEAN,
    number_of_dependents    INT CHECK (number_of_dependents >= 0)
);

CREATE TABLE dim_location (
    customer_id     VARCHAR(20) PRIMARY KEY REFERENCES dim_customer(customer_id),
    city            VARCHAR(100),
    zip_code        VARCHAR(10),
    latitude        NUMERIC(9,6),
    longitude       NUMERIC(9,6)
);

CREATE TABLE dim_services (
    customer_id              VARCHAR(20) PRIMARY KEY REFERENCES dim_customer(customer_id),
    offer                    VARCHAR(50),
    phone_service            BOOLEAN,
    multiple_lines           BOOLEAN,
    internet_service         BOOLEAN,
    internet_type            VARCHAR(30),
    online_security          BOOLEAN,
    online_backup            BOOLEAN,
    device_protection_plan   BOOLEAN,
    premium_tech_support     BOOLEAN,
    streaming_tv             BOOLEAN,
    streaming_movies         BOOLEAN,
    streaming_music          BOOLEAN,
    unlimited_data           BOOLEAN,
    contract                 VARCHAR(30) CHECK (contract IN ('Month-to-Month','One Year','Two Year')),
    paperless_billing        BOOLEAN,
    payment_method           VARCHAR(30)
);

CREATE TABLE fact_charges (
    customer_id                           VARCHAR(20) PRIMARY KEY REFERENCES dim_customer(customer_id),
    tenure_in_months                      INT CHECK (tenure_in_months >= 0),
    number_of_referrals                   INT CHECK (number_of_referrals >= 0),
    avg_monthly_long_distance_charges     NUMERIC(10,2),
    avg_monthly_gb_download               NUMERIC(10,2),
    monthly_charge                        NUMERIC(10,2),
    total_charges                         NUMERIC(12,2),
    total_refunds                         NUMERIC(12,2),
    total_extra_data_charges              NUMERIC(12,2),
    total_long_distance_charges           NUMERIC(12,2),
    total_revenue                         NUMERIC(12,2)
);

CREATE TABLE dim_status (
    customer_id       VARCHAR(20) PRIMARY KEY REFERENCES dim_customer(customer_id),
    customer_status   VARCHAR(20) CHECK (customer_status IN ('Churned','Stayed','Joined')),
    churn_category    VARCHAR(50),
    churn_reason      VARCHAR(200)
);

-- Population

INSERT INTO dim_customer (customer_id, gender, age, married, number_of_dependents)
SELECT
    customer_id,
    gender,
    age,
    CASE WHEN married = 'Yes' THEN TRUE
         WHEN married = 'No'  THEN FALSE
         ELSE NULL END,
    number_of_dependents
FROM staging_telecom_churn;

INSERT INTO dim_location (customer_id, city, zip_code, latitude, longitude)
SELECT customer_id, city, zip_code, latitude, longitude
FROM staging_telecom_churn;

INSERT INTO dim_services (
    customer_id, offer, phone_service, multiple_lines, internet_service, internet_type,
    online_security, online_backup, device_protection_plan, premium_tech_support,
    streaming_tv, streaming_movies, streaming_music, unlimited_data,
    contract, paperless_billing, payment_method
)
SELECT
    customer_id,
    offer,
    phone_service = 'Yes',
    multiple_lines = 'Yes',
    internet_service = 'Yes',
    internet_type,
    online_security = 'Yes',
    online_backup = 'Yes',
    device_protection_plan = 'Yes',
    premium_tech_support = 'Yes',
    streaming_tv = 'Yes',
    streaming_movies = 'Yes',
    streaming_music = 'Yes',
    unlimited_data = 'Yes',
    contract,
    paperless_billing = 'Yes',
    payment_method
FROM staging_telecom_churn;

INSERT INTO fact_charges (
    customer_id, tenure_in_months, number_of_referrals,
    avg_monthly_long_distance_charges, avg_monthly_gb_download,
    monthly_charge, total_charges, total_refunds,
    total_extra_data_charges, total_long_distance_charges, total_revenue
)
SELECT
    customer_id, tenure_in_months, number_of_referrals,
    avg_monthly_long_distance_charges, avg_monthly_gb_download,
    monthly_charge, total_charges, total_refunds,
    total_extra_data_charges, total_long_distance_charges, total_revenue
FROM staging_telecom_churn;

INSERT INTO dim_status (customer_id, customer_status, churn_category, churn_reason)
SELECT customer_id, customer_status, churn_category, churn_reason
FROM staging_telecom_churn;

-- Index
CREATE INDEX idx_services_contract ON dim_services(contract);
CREATE INDEX idx_services_internet_type ON dim_services(internet_type); 
CREATE INDEX idx_status_customer_status ON dim_status(customer_status); 
CREATE INDEX idx_location_city ON dim_location(city);