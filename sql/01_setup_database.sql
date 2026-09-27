
CREATE WAREHOUSE IF NOT EXISTS ecommerce_wh
    WITH WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE;

CREATE DATABASE IF NOT EXISTS ecommerce_intelligence;

CREATE SCHEMA IF NOT EXISTS ecommerce_intelligence.raw;
CREATE SCHEMA IF NOT EXISTS ecommerce_intelligence.analytics;

-- Verify Infrastructure Setup
SHOW DATABASES LIKE 'ECOMMERCE_INTELLIGENCE';
SHOW SCHEMAS IN DATABASE ecommerce_intelligence;
SHOW WAREHOUSES LIKE 'ECOMMERCE_WH';


USE DATABASE ecommerce_intelligence;
USE SCHEMA raw;

-- Customer Master Table
CREATE OR REPLACE TABLE customers (
    customer_id VARCHAR,
    customer_unique_id VARCHAR,
    customer_zip_code_prefix VARCHAR,
    customer_city VARCHAR,
    customer_state VARCHAR
);

-- Orders Header Table
CREATE OR REPLACE TABLE orders (
    order_id VARCHAR,
    customer_id VARCHAR,
    order_status VARCHAR,
    order_purchase_timestamp TIMESTAMP_NTZ,
    order_approved_at TIMESTAMP_NTZ,
    order_delivered_carrier_date TIMESTAMP_NTZ,
    order_delivered_customer_date TIMESTAMP_NTZ,
    order_estimated_delivery_date TIMESTAMP_NTZ
);

-- Order Items Detail Table
CREATE OR REPLACE TABLE order_items (
    order_id VARCHAR,
    order_item_id NUMBER,
    product_id VARCHAR,
    seller_id VARCHAR,
    shipping_limit_date TIMESTAMP_NTZ,
    price NUMBER(10,2),
    freight_value NUMBER(10,2)
);

-- Payment Transactions Table
CREATE OR REPLACE TABLE order_payments (
    order_id VARCHAR,
    payment_sequential NUMBER,
    payment_type VARCHAR,
    payment_installments NUMBER,
    payment_value NUMBER(10,2)
);

-- Customer Reviews Table
CREATE OR REPLACE TABLE order_reviews (
    review_id VARCHAR,
    order_id VARCHAR,
    review_score NUMBER,
    review_comment_title VARCHAR,
    review_comment_message VARCHAR,
    review_creation_date TIMESTAMP_NTZ,
    review_answer_timestamp TIMESTAMP_NTZ
);

-- Product Catalog Master Table
CREATE OR REPLACE TABLE products (
    product_id VARCHAR,
    product_category_name VARCHAR,
    product_name_lenght NUMBER,
    product_description_lenght NUMBER,
    product_photos_qty NUMBER,
    product_weight_g NUMBER,
    product_length_cm NUMBER,
    product_height_cm NUMBER,
    product_width_cm NUMBER
);

-- Seller Master Table
CREATE OR REPLACE TABLE sellers (
    seller_id VARCHAR,
    seller_zip_code_prefix VARCHAR,
    seller_city VARCHAR,
    seller_state VARCHAR
);

-- Category Translation Reference Table
CREATE OR REPLACE TABLE product_category_translation (
    product_category_name VARCHAR,
    product_category_name_english VARCHAR
);

-- Verify Created Tables
SHOW TABLES IN SCHEMA ecommerce_intelligence.raw;

-- Phase 3: Data Staging & Load Preparation
USE DATABASE ecommerce_intelligence;
USE SCHEMA raw;

-- External Stage Setup Placeholder
CREATE OR REPLACE STAGE my_s3_stage; 

-- Data Ingestion Verification & Row Count Checks
SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM ecommerce_intelligence.raw.customers
UNION ALL
SELECT 'orders', COUNT(*) FROM ecommerce_intelligence.raw.orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM ecommerce_intelligence.raw.order_items
UNION ALL
SELECT 'order_payments', COUNT(*) FROM ecommerce_intelligence.raw.order_payments
UNION ALL
SELECT 'order_reviews', COUNT(*) FROM ecommerce_intelligence.raw.order_reviews
UNION ALL
SELECT 'products', COUNT(*) FROM ecommerce_intelligence.raw.products
UNION ALL
SELECT 'sellers', COUNT(*) FROM ecommerce_intelligence.raw.sellers;

-- Check Duplicate Header Row in Translation Table
SELECT * FROM ecommerce_intelligence.raw.product_category_translation
WHERE product_category_name = 'product_category_name';

-- Clean Ingested Header Row
DELETE FROM ecommerce_intelligence.raw.product_category_translation
WHERE product_category_name = 'product_category_name';

-- Final Row Count Verification
SELECT COUNT(*) FROM ecommerce_intelligence.raw.product_category_translation;