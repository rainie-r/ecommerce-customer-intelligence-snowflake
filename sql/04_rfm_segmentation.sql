USE DATABASE ecommerce_intelligence;

-- reference date for recency (most recent order in the dataset)
SELECT MAX(order_purchase_timestamp) AS max_order_date
FROM raw.orders
WHERE order_status = 'delivered';

-- raw R, F, M per customer
CREATE OR REPLACE VIEW analytics.customer_rfm_raw AS
SELECT
    c.customer_unique_id,
    DATEDIFF('day', MAX(o.order_purchase_timestamp), '2018-08-29 15:00:37'::TIMESTAMP) AS recency_days,
    COUNT(DISTINCT o.order_id) AS frequency,
    SUM(oi.price) AS monetary
FROM raw.customers c
JOIN raw.orders o ON c.customer_id = o.customer_id
JOIN raw.order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_unique_id;

SELECT * FROM analytics.customer_rfm_raw
ORDER BY monetary DESC
LIMIT 20;

-- score R, F, M 1-5 using NTILE
CREATE OR REPLACE VIEW analytics.customer_rfm_scored AS
SELECT
    customer_unique_id,
    recency_days,
    frequency,
    monetary,
    NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
    NTILE(5) OVER (ORDER BY frequency ASC) AS f_score,
    NTILE(5) OVER (ORDER BY monetary ASC) AS m_score
FROM analytics.customer_rfm_raw;

SELECT * FROM analytics.customer_rfm_scored
ORDER BY monetary DESC
LIMIT 20;

SELECT frequency, COUNT(*) AS customer_count
FROM analytics.customer_rfm_raw
GROUP BY frequency
ORDER BY frequency;

-- fix: manual scoring for frequency instead of NTILE
CREATE OR REPLACE VIEW analytics.customer_rfm_scored AS
SELECT
    customer_unique_id,
    recency_days,
    frequency,
    monetary,
    NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
    CASE
        WHEN frequency = 1 THEN 1
        WHEN frequency = 2 THEN 3
        WHEN frequency BETWEEN 3 AND 4 THEN 4
        WHEN frequency >= 5 THEN 5
    END AS f_score,
    NTILE(5) OVER (ORDER BY monetary ASC) AS m_score
FROM analytics.customer_rfm_raw;

SELECT frequency, f_score, COUNT(*) AS customer_count
FROM analytics.customer_rfm_scored
GROUP BY frequency, f_score
ORDER BY frequency;

-- combine R+F+M scores into named segments
CREATE OR REPLACE VIEW analytics.customer_rfm_segments AS
SELECT
    customer_unique_id,
    recency_days,
    frequency,
    monetary,
    r_score,
    f_score,
    m_score,
    (r_score + f_score + m_score) AS rfm_total_score,
    CASE
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
        WHEN r_score >= 4 AND f_score BETWEEN 1 AND 3 AND m_score >= 3 THEN 'Potential Loyalists'
        WHEN r_score >= 4 AND f_score = 1 AND m_score <= 2 THEN 'New Customers'
        WHEN r_score BETWEEN 2 AND 3 AND f_score >= 3 THEN 'Loyal Customers'
        WHEN r_score <= 2 AND f_score >= 3 AND m_score >= 3 THEN 'At Risk'
        WHEN r_score <= 2 AND f_score <= 2 AND m_score >= 4 THEN 'Cant Lose Them'
        WHEN r_score <= 2 AND f_score <= 2 AND m_score <= 2 THEN 'Lost'
        ELSE 'Needs Attention'
    END AS customer_segment
FROM analytics.customer_rfm_scored;

SELECT
    customer_segment,
    COUNT(*) AS customer_count,
    ROUND(AVG(monetary), 2) AS avg_monetary,
    SUM(monetary) AS total_segment_revenue
FROM analytics.customer_rfm_segments
GROUP BY customer_segment
ORDER BY total_segment_revenue DESC;
