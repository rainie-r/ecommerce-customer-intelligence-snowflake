# E-Commerce Customer Intelligence & Sales Analytics

SQL-based analytics project on the Olist Brazilian E-Commerce dataset, built in Snowflake. Covers data modeling, data cleaning, RFM segmentation, and cohort retention analysis for a fictional retailer, NorthStar Market.

## Business Problem

NorthStar Market's leadership noticed revenue growth slowing and had no clear answer on who their best customers were, which ones were at risk of leaving, or why growth had stalled. This project builds a customer intelligence layer in Snowflake to answer those questions with data instead of guesswork.

## Dataset

[Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) — ~100k orders from 2016-2018, split across 8 relational CSV files (customers, orders, order items, payments, reviews, products, sellers, category translations).

Known limitations, documented rather than hidden:
- 2016 data is too sparse to be meaningful (excluded from trend analysis)
- Review text is anonymized to fictional names, not usable for real sentiment analysis
- No marketing/acquisition channel data, so cohorts are based on first purchase month, not true acquisition source
- No customer demographic data, so segmentation is purely behavioral (RFM), not demographic

## Tech Stack

Snowflake (data warehouse, SQL), Kaggle (data source). No BI tool layer — all analysis done directly in SQL, results interpreted below.

## Project Structure

```
sql/
  01_setup_database.sql       - warehouse, database, schema, table creation
  02_data_cleaning.sql        - missing values, duplicates, invalid values, derived fields
  03_analytics_queries.sql    - revenue analysis, ranking, growth, category breakdown
  04_rfm_segmentation.sql     - RFM scoring and customer segmentation
  05_cohort_retention.sql     - cohort definition and monthly retention
```

## Data Model

8 tables in a `raw` schema, one enriched view and several analytics views in an `analytics` schema layered on top. Core relationships:

```
customers (1) --< orders (1) --< order_items (M) >-- products
                     |                  |
                     |                  >-- sellers
                     |
                     >-- payments (M)
                     |
                     >-- reviews (M, keyed on review_id + order_id)

products >-- product_category_name_translation
```

Note: `customers.customer_id` is order-specific and changes per order. `customers.customer_unique_id` is the actual persistent customer identifier and is what all customer-level analysis (RFM, cohorts) is grouped on.

## Data Quality Findings

- 610 products (1,603 order line items, $179,535 in revenue) were missing category data. Filled with `'unknown'` instead of deleted, to avoid silently understating revenue.
- Zero true duplicate records found across all 8 tables.
- 814 `review_id` values appeared to repeat, but investigation showed they map to different `order_id`s — one review can legitimately cover multiple orders placed in the same checkout session. True key is `(review_id, order_id)`, not `review_id` alone.
- 9 payments recorded as $0, all tied to `voucher` or `not_defined` payment types — valid, not errors.
- 23 orders (0.02%) show a carrier delivery date later than the customer delivery date, likely reflecting how the carrier confirmation timestamp is recorded upstream. Excluded from delivery-time calculations, not deleted from the base table.

## Key Findings

1. **Revenue is not concentrated.** The top 20 customers by revenue account for only 0.81% of total revenue ($13.2M). This is a low-risk revenue profile, but it also means VIP-style programs for top spenders won't move the needle much.
2. **97% of customers order exactly once.** Month-1 retention sits below 1% across every acquisition cohort from Jan 2017 through Aug 2018. This is a structural feature of a general-marketplace business, not a data error.
3. **Revenue growth has slowed sharply.** Monthly growth averaged roughly +23% through 2017, dropping to roughly +3% in 2018, with several negative months. Because retention has been low from the very first cohort, the slowdown points to a deceleration in new customer acquisition, not a drop in repeat behavior.
4. **RFM segmentation surfaces $3.82M in revenue at risk.** The "Cant Lose Them" segment (13,776 customers, historically high value, now inactive) represents real revenue that may already be churned.
5. **Delivery delays affect roughly 1 in 13 orders.** Worth testing as a contributing factor to low repeat purchase rates.

## Recommendations

- Shift retention strategy from "keep top customers happy" to "convert first-time buyers into second-time buyers" — the volume math favors small improvements at scale over VIP treatment for a handful of accounts.
- Launch a win-back campaign targeted specifically at the "Cant Lose Them" segment before that revenue is fully lost.
- Investigate delivery delay as a churn driver by cross-referencing late orders against review scores and repeat purchase rates.
- Track new customer acquisition rate as a leading indicator going forward, since the business's growth is acquisition-driven rather than retention-driven.

## Limitations of This Analysis

- No marketing spend or channel data means acquisition-driver claims are inferential, not proven — a natural next step if this project continues.
- Delivery delay as a churn driver is a hypothesis based on pattern, not yet statistically tested against actual repeat-purchase outcomes.
- 2018 data ends in August, which is a dataset boundary, not a business event, and is called out explicitly to avoid misreading it as a business collapse.
