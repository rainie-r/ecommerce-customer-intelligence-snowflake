USE DATABASE ecommerce_intelligence;

-- revenue per customer
SELECT
    c.customer_unique_id,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(oi.price) AS total_revenue,
    ROUND(SUM(oi.price) / COUNT(DISTINCT o.order_id), 2) AS avg_order_value
FROM raw.customers c
JOIN raw.orders o ON c.customer_id = o.customer_id
JOIN raw.order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_unique_id
ORDER BY total_revenue DESC
LIMIT 20;

-- same thing but with RANK()
SELECT
    c.customer_unique_id,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(oi.price) AS total_revenue,
    RANK() OVER (ORDER BY SUM(oi.price) DESC) AS revenue_rank
FROM raw.customers c
JOIN raw.orders o ON c.customer_id = o.customer_id
JOIN raw.order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_unique_id
ORDER BY revenue_rank
LIMIT 20;

-- RANK() vs DENSE_RANK() comparison
SELECT
    c.customer_unique_id,
    SUM(oi.price) AS total_revenue,
    RANK() OVER (ORDER BY SUM(oi.price) DESC) AS rank_version,
    DENSE_RANK() OVER (ORDER BY SUM(oi.price) DESC) AS dense_rank_version
FROM raw.customers c
JOIN raw.orders o ON c.customer_id = o.customer_id
JOIN raw.order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_unique_id
ORDER BY total_revenue DESC
LIMIT 50;


-- revenue concentration (running total + % of total)
WITH customer_revenue AS (
    SELECT
        c.customer_unique_id,
        SUM(oi.price) AS total_revenue
    FROM raw.customers c
    JOIN raw.orders o ON c.customer_id = o.customer_id
    JOIN raw.order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)
SELECT
    customer_unique_id,
    total_revenue,
    SUM(total_revenue) OVER (ORDER BY total_revenue DESC) AS running_total_revenue,
    ROUND(
        SUM(total_revenue) OVER (ORDER BY total_revenue DESC) / SUM(total_revenue) OVER () * 100
    , 2) AS pct_of_total_revenue_cumulative
FROM customer_revenue
ORDER BY total_revenue DESC
LIMIT 20;

-- total company revenue, for context on the % above
SELECT SUM(oi.price) AS total_company_revenue
FROM raw.orders o
JOIN raw.order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered';
-- = $13,221,498.11. top 20 customers = only 0.81% of that.


-- month-over-month growth
WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', o.order_purchase_timestamp)::DATE AS revenue_month,
        SUM(oi.price) AS total_revenue
    FROM raw.orders o
    JOIN raw.order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY revenue_month
)
SELECT
    revenue_month,
    total_revenue,
    LAG(total_revenue) OVER (ORDER BY revenue_month) AS prev_month_revenue,
    ROUND(
        (total_revenue - LAG(total_revenue) OVER (ORDER BY revenue_month))
        / LAG(total_revenue) OVER (ORDER BY revenue_month) * 100
    , 2) AS mom_growth_pct
FROM monthly_revenue
ORDER BY revenue_month;

-- same query, 2016 excluded
WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', o.order_purchase_timestamp)::DATE AS revenue_month,
        SUM(oi.price) AS total_revenue
    FROM raw.orders o
    JOIN raw.order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp >= '2017-01-01'
    GROUP BY revenue_month
)
SELECT
    revenue_month,
    total_revenue,
    LAG(total_revenue) OVER (ORDER BY revenue_month) AS prev_month_revenue,
    ROUND(
        (total_revenue - LAG(total_revenue) OVER (ORDER BY revenue_month))
        / LAG(total_revenue) OVER (ORDER BY revenue_month) * 100
    , 2) AS mom_growth_pct
FROM monthly_revenue
ORDER BY revenue_month;

-- revenue by product category
SELECT
    COALESCE(pct.product_category_name_english, p.product_category_name) AS category,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    COUNT(*) AS total_items_sold,
    SUM(oi.price) AS total_revenue,
    ROUND(SUM(oi.price) / COUNT(*), 2) AS avg_item_price,
    RANK() OVER (ORDER BY SUM(oi.price) DESC) AS category_rank
FROM raw.order_items oi
JOIN raw.orders o ON oi.order_id = o.order_id
JOIN raw.products p ON oi.product_id = p.product_id
LEFT JOIN raw.product_category_translation pct
    ON p.product_category_name = pct.product_category_name
WHERE o.order_status = 'delivered'
GROUP BY COALESCE(pct.product_category_name_english, p.product_category_name)
ORDER BY total_revenue DESC
LIMIT 20;

-- above-average spenders (subquery)
SELECT
    c.customer_unique_id,
    SUM(oi.price) AS total_revenue
FROM raw.customers c
JOIN raw.orders o ON c.customer_id = o.customer_id
JOIN raw.order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_unique_id
HAVING SUM(oi.price) > (
    SELECT AVG(customer_total)
    FROM (
        SELECT SUM(oi2.price) AS customer_total
        FROM raw.orders o2
        JOIN raw.order_items oi2 ON o2.order_id = oi2.order_id
        WHERE o2.order_status = 'delivered'
        GROUP BY o2.customer_id
    )
)
ORDER BY total_revenue DESC
LIMIT 20;

-- customer lifespan / repeat order behavior
WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        o.order_purchase_timestamp,
        ROW_NUMBER() OVER (PARTITION BY c.customer_unique_id ORDER BY o.order_purchase_timestamp) AS order_sequence
    FROM raw.customers c
    JOIN raw.orders o ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
)
SELECT
    customer_unique_id,
    COUNT(*) AS total_orders,
    MIN(order_purchase_timestamp) AS first_order,
    MAX(order_purchase_timestamp) AS last_order,
    DATEDIFF('day', MIN(order_purchase_timestamp), MAX(order_purchase_timestamp)) AS customer_lifespan_days
FROM customer_orders
GROUP BY customer_unique_id
HAVING COUNT(*) > 1
ORDER BY total_orders DESC
LIMIT 20;

-- 3-month rolling average revenue
WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', o.order_purchase_timestamp)::DATE AS revenue_month,
        SUM(oi.price) AS total_revenue
    FROM raw.orders o
    JOIN raw.order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp >= '2017-01-01'
    GROUP BY revenue_month
)
SELECT
    revenue_month,
    total_revenue,
    ROUND(
        AVG(total_revenue) OVER (ORDER BY revenue_month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)
    , 2) AS moving_avg_3month
FROM monthly_revenue
ORDER BY revenue_month;
