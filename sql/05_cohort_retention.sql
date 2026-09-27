USE DATABASE ecommerce_intelligence;

-- cohort month per customer = month of their first order
CREATE OR REPLACE VIEW analytics.customer_cohorts AS
SELECT
    c.customer_unique_id,
    MIN(DATE_TRUNC('month', o.order_purchase_timestamp))::DATE AS cohort_month
FROM raw.customers c
JOIN raw.orders o ON c.customer_id = o.customer_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_unique_id;

-- every month each customer was active (placed at least one order)
CREATE OR REPLACE VIEW analytics.customer_monthly_activity AS
SELECT DISTINCT
    c.customer_unique_id,
    DATE_TRUNC('month', o.order_purchase_timestamp)::DATE AS activity_month
FROM raw.customers c
JOIN raw.orders o ON c.customer_id = o.customer_id
WHERE o.order_status = 'delivered';

-- join cohort + activity to get months_since_acquisition per customer
CREATE OR REPLACE VIEW analytics.cohort_retention_base AS
SELECT
    cc.cohort_month,
    cma.activity_month,
    DATEDIFF('month', cc.cohort_month, cma.activity_month) AS months_since_acquisition,
    cc.customer_unique_id
FROM analytics.customer_cohorts cc
JOIN analytics.customer_monthly_activity cma
    ON cc.customer_unique_id = cma.customer_unique_id;

-- final retention table: % of each cohort still active at each month offset
WITH cohort_size AS (
    SELECT
        cohort_month,
        COUNT(DISTINCT customer_unique_id) AS total_customers
    FROM analytics.customer_cohorts
    GROUP BY cohort_month
),
retention_counts AS (
    SELECT
        cohort_month,
        months_since_acquisition,
        COUNT(DISTINCT customer_unique_id) AS active_customers
    FROM analytics.cohort_retention_base
    GROUP BY cohort_month, months_since_acquisition
)
SELECT
    rc.cohort_month,
    cs.total_customers,
    rc.months_since_acquisition,
    rc.active_customers,
    ROUND(rc.active_customers / cs.total_customers * 100, 2) AS retention_pct
FROM retention_counts rc
JOIN cohort_size cs ON rc.cohort_month = cs.cohort_month
WHERE rc.cohort_month >= '2017-01-01'
ORDER BY rc.cohort_month, rc.months_since_acquisition;
