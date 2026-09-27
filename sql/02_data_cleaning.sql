

USE DATABASE ecommerce_intelligence;
USE SCHEMA raw;


-- MISSING VALUES CHECK

-- 1a. Orders table: check for missing timestamps and key identifiers
SELECT
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(order_id) AS missing_order_id,
    COUNT(*) - COUNT(customer_id) AS missing_customer_id,
    COUNT(*) - COUNT(order_status) AS missing_order_status,
    COUNT(*) - COUNT(order_purchase_timestamp) AS missing_purchase_timestamp,
    COUNT(*) - COUNT(order_approved_at) AS missing_approved_at,
    COUNT(*) - COUNT(order_delivered_carrier_date) AS missing_delivered_carrier,
    COUNT(*) - COUNT(order_delivered_customer_date) AS missing_delivered_customer,
    COUNT(*) - COUNT(order_estimated_delivery_date) AS missing_estimated_delivery
FROM orders;

-- 1b. Products table: check for missing values (found 610 missing categories)
SELECT
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(product_category_name) AS missing_category,
    COUNT(*) - COUNT(product_name_lenght) AS missing_name_length,
    COUNT(*) - COUNT(product_description_lenght) AS missing_description_length,
    COUNT(*) - COUNT(product_photos_qty) AS missing_photos_qty,
    COUNT(*) - COUNT(product_weight_g) AS missing_weight
FROM products;

-- 1c. Order_reviews table: check missing review text (expected to be high since these are optional fields)
SELECT
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(review_comment_title) AS missing_title,
    COUNT(*) - COUNT(review_comment_message) AS missing_message,
    COUNT(*) - COUNT(review_score) AS missing_score
FROM order_reviews;

-- 1d. Customers table: verify data completeness
SELECT
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(customer_unique_id) AS missing_unique_id,
    COUNT(*) - COUNT(customer_city) AS missing_city,
    COUNT(*) - COUNT(customer_state) AS missing_state,
    COUNT(*) - COUNT(customer_zip_code_prefix) AS missing_zip
FROM customers;

-- 1e. Order_items table: verify item details completeness
SELECT
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(product_id) AS missing_product_id,
    COUNT(*) - COUNT(seller_id) AS missing_seller_id,
    COUNT(*) - COUNT(price) AS missing_price,
    COUNT(*) - COUNT(freight_value) AS missing_freight
FROM order_items;

-- 1f. Order_payments table: verify payment details completeness
SELECT
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(payment_type) AS missing_payment_type,
    COUNT(*) - COUNT(payment_installments) AS missing_installments,
    COUNT(*) - COUNT(payment_value) AS missing_value
FROM order_payments;

-- 1g. Sellers table: verify seller details completeness
SELECT
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(seller_city) AS missing_city,
    COUNT(*) - COUNT(seller_state) AS missing_state,
    COUNT(*) - COUNT(seller_zip_code_prefix) AS missing_zip
FROM sellers;


-- STEP 1.1: FIX MISSING PRODUCT CATEGORIES

-- Confirm these 610 rows are missing all 4 metadata columns at the same time
SELECT COUNT(*) AS rows_with_all_4_columns_null
FROM products
WHERE product_category_name IS NULL
  AND product_name_lenght IS NULL
  AND product_description_lenght IS NULL
  AND product_photos_qty IS NULL;

-- Calculate total revenue at risk before applying updates
SELECT COUNT(DISTINCT oi.product_id) AS sold_products_with_missing_category,
       COUNT(*) AS total_line_items_affected,
       SUM(oi.price) AS revenue_at_risk
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
WHERE p.product_category_name IS NULL;

-- Fill NULL categories with 'unknown' placeholder
UPDATE products
SET product_category_name = 'unknown'
WHERE product_category_name IS NULL;

-- Verify all NULLs have been updated
SELECT COUNT(*) AS remaining_nulls
FROM products
WHERE product_category_name IS NULL;


-- DUPLICATE CHECK
 
-- 2a. Orders: order_id should be unique
SELECT order_id, COUNT(*) AS duplicate_count
FROM orders
GROUP BY order_id
HAVING COUNT(*) > 1;

-- 2b. Order_items: composite key (order_id + order_item_id)
SELECT order_id, order_item_id, COUNT(*) AS duplicate_count
FROM order_items
GROUP BY order_id, order_item_id
HAVING COUNT(*) > 1;

-- 2c. Order_payments: composite key (order_id + payment_sequential)
SELECT order_id, payment_sequential, COUNT(*) AS duplicate_count
FROM order_payments
GROUP BY order_id, payment_sequential
HAVING COUNT(*) > 1;

-- 2d. Order_reviews: check review_id uniqueness
SELECT review_id, COUNT(*) AS duplicate_count
FROM order_reviews
GROUP BY review_id
HAVING COUNT(*) > 1;


-- INVESTIGATE DUPLICATE REVIEW_IDs
 
-- Inspect a sample repeated review_id
SELECT *
FROM order_reviews
WHERE review_id = '62c7722239b976d943ec0d430cfe890e'
ORDER BY review_id;

-- Quantify total rows vs unique review_ids
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT review_id) AS unique_review_ids,
    COUNT(*) - COUNT(DISTINCT review_id) AS extra_duplicate_rows
FROM order_reviews;

-- Confirm repeated review_ids belong to multiple distinct orders
SELECT review_id, COUNT(DISTINCT order_id) AS distinct_orders_per_review
FROM order_reviews
GROUP BY review_id
HAVING COUNT(*) > 1
ORDER BY distinct_orders_per_review DESC
LIMIT 10;

-- Confirm composite key (review_id, order_id) is completely unique (returns 0 rows)
SELECT review_id, order_id, COUNT(*) AS cnt
FROM order_reviews
GROUP BY review_id, order_id
HAVING COUNT(*) > 1;


-- INVALID VALUES CHECK

-- 3a. Check for non-positive prices or payment values
SELECT 'order_items.price' AS field, COUNT(*) AS invalid_count
FROM order_items WHERE price <= 0
UNION ALL
SELECT 'order_items.freight_value', COUNT(*)
FROM order_items WHERE freight_value < 0
UNION ALL
SELECT 'order_payments.payment_value', COUNT(*)
FROM order_payments WHERE payment_value <= 0;

-- 3b. Check for out-of-sequence order dates
SELECT
    SUM(CASE WHEN order_delivered_customer_date < order_purchase_timestamp THEN 1 ELSE 0 END) AS delivered_before_purchase,
    SUM(CASE WHEN order_approved_at < order_purchase_timestamp THEN 1 ELSE 0 END) AS approved_before_purchase,
    SUM(CASE WHEN order_delivered_customer_date < order_delivered_carrier_date THEN 1 ELSE 0 END) AS customer_before_carrier
FROM orders;


-- INVESTIGATE PAYMENT_VALUE = 0


SELECT *
FROM order_payments
WHERE payment_value <= 0;


-- INVESTIGATE CARRIER DATE ANOMALIES

SELECT order_id, order_status, order_purchase_timestamp,
       order_delivered_carrier_date, order_delivered_customer_date
FROM orders
WHERE order_delivered_customer_date < order_delivered_carrier_date
ORDER BY order_purchase_timestamp
LIMIT 23;

-- CREATE ENRICHED ANALYTICS VIEW


USE DATABASE ecommerce_intelligence;

CREATE OR REPLACE VIEW analytics.orders_enriched AS
SELECT
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date,

    -- Delivery duration in days
    DATEDIFF('day', order_purchase_timestamp, order_delivered_customer_date) AS delivery_time_days,

    -- Flag for late deliveries
    CASE
        WHEN order_delivered_customer_date > order_estimated_delivery_date THEN TRUE
        WHEN order_delivered_customer_date IS NULL THEN NULL
        ELSE FALSE
    END AS is_late_delivery,

    -- Purchase month for cohort modeling
    DATE_TRUNC('month', order_purchase_timestamp)::DATE AS order_year_month

FROM raw.orders;

-- Inspect output sample from the view
SELECT * FROM analytics.orders_enriched LIMIT 10;

-- Overall delivery performance summary
SELECT
    AVG(delivery_time_days) AS avg_delivery_days,
    SUM(CASE WHEN is_late_delivery = TRUE THEN 1 ELSE 0 END) AS total_late_orders,
    COUNT(*) AS total_orders
FROM analytics.orders_enriched;

SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM raw.customers
UNION ALL
SELECT 'products', COUNT(*) FROM raw.products
UNION ALL
SELECT 'product_category_translation', COUNT(*) FROM raw.product_category_translation;
SELECT COUNT(*) AS remaining_nulls FROM raw.products WHERE product_category_name IS NULL;