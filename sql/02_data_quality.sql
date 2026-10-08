/*
=========================================================
Olist E-Commerce Analysis
02 - Data Quality Checks
=========================================================

Purpose:
    Validate the integrity and structure of the raw
    PostgreSQL tables before performing analysis.

Database:
    olist_analysis

Checks:
    1.  Customer ID uniqueness
    2.  Order ID uniqueness
    3.  Order status distribution
    4.  Order date range
    5.  Missing order dates
    6.  Orders without a valid customer
    7.  Payment structure
    8.  Multiple payments per order
    9.  Review structure
    10. Review score validation
    11. Multiple reviews per order
    12. Examples of orders with multiple reviews
    13. Order item structure
    14. Order item uniqueness
    15. Price and freight validation
    16. Negative price check
    17. Negative freight check

=========================================================
*/


-- =====================================================
-- 1. CUSTOMER ID UNIQUENESS
-- =====================================================
-- Check whether customer_id is unique in customers.
--
-- Also compare customer_id with customer_unique_id.
-- customer_unique_id represents the underlying customer
-- across orders and should be used for customer-level
-- analysis such as RFM and retention.

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT customer_id) AS unique_customer_ids,
    COUNT(DISTINCT customer_unique_id) AS unique_customers
FROM customers;


-- =====================================================
-- 2. ORDER ID UNIQUENESS
-- =====================================================
-- order_id should be unique in the orders table.

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_id) AS unique_order_ids
FROM orders;


-- =====================================================
-- 3. ORDER STATUS DISTRIBUTION
-- =====================================================
-- Understand the different order statuses and their
-- percentage of all orders.

SELECT
    order_status,
    COUNT(*) AS orders,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS pct
FROM orders
GROUP BY order_status
ORDER BY orders DESC;


-- =====================================================
-- 4. ORDER DATE RANGE
-- =====================================================
-- Identify the observation period of the dataset.

SELECT
    MIN(order_purchase_timestamp) AS first_order,
    MAX(order_purchase_timestamp) AS last_order
FROM orders;


-- =====================================================
-- 5. MISSING ORDER DATES
-- =====================================================
-- Check NULL values in important timestamp columns.

SELECT
    COUNT(*) AS total_orders,

    COUNT(order_purchase_timestamp) AS purchase_dates,

    COUNT(order_approved_at) AS approved_dates,

    COUNT(order_delivered_carrier_date) AS carrier_dates,

    COUNT(order_delivered_customer_date) AS delivered_dates,

    COUNT(order_estimated_delivery_date) AS estimated_dates

FROM orders;


-- =====================================================
-- 6. ORDERS WITHOUT A VALID CUSTOMER
-- =====================================================
-- Every order should have a matching customer.

SELECT
    COUNT(*) AS orders_without_customer

FROM orders o

LEFT JOIN customers c
    ON o.customer_id = c.customer_id

WHERE c.customer_id IS NULL;


-- =====================================================
-- 7. PAYMENT STRUCTURE
-- =====================================================
-- Check the number of payment records and the number
-- of orders represented in the payment table.

SELECT
    COUNT(*) AS payment_rows,
    COUNT(DISTINCT order_id) AS orders_with_payments
FROM order_payments;


-- =====================================================
-- 8. MULTIPLE PAYMENTS PER ORDER
-- =====================================================
-- Some orders can have multiple payment records.
--
-- This is important because joining payments directly
-- to order_items can multiply rows and inflate revenue.

SELECT
    payment_count,
    COUNT(*) AS number_of_orders

FROM (
    SELECT
        order_id,
        COUNT(*) AS payment_count

    FROM order_payments

    GROUP BY order_id
) x

GROUP BY payment_count

ORDER BY payment_count;


-- =====================================================
-- 9. REVIEW STRUCTURE
-- =====================================================
-- Check review rows, unique review IDs and orders
-- represented in the review table.

SELECT
    COUNT(*) AS total_review_rows,
    COUNT(DISTINCT review_id) AS unique_review_ids,
    COUNT(DISTINCT order_id) AS orders_with_reviews
FROM order_reviews;


-- =====================================================
-- 10. REVIEW SCORE VALIDATION
-- =====================================================
-- Review scores should normally range from 1 to 5.
--
-- This query allows us to verify the actual values
-- present in the dataset.

SELECT
    review_score,
    COUNT(*) AS review_count

FROM order_reviews

GROUP BY review_score

ORDER BY review_score;


-- =====================================================
-- 11. MULTIPLE REVIEWS PER ORDER
-- =====================================================
-- Check whether an order has more than one review row.

SELECT
    COUNT(*) AS orders_with_multiple_reviews

FROM (
    SELECT
        order_id

    FROM order_reviews

    GROUP BY order_id

    HAVING COUNT(*) > 1
) x;


-- =====================================================
-- 12. EXAMPLES OF ORDERS WITH MULTIPLE REVIEWS
-- =====================================================
-- Display examples of orders that have multiple
-- review rows.

SELECT
    order_id,
    COUNT(*) AS review_count

FROM order_reviews

GROUP BY order_id

HAVING COUNT(*) > 1

ORDER BY review_count DESC

LIMIT 20;


-- =====================================================
-- 13. ORDER ITEM STRUCTURE
-- =====================================================
-- Basic structure of the order_items table.

SELECT
    COUNT(*) AS total_item_rows,
    COUNT(DISTINCT order_id) AS orders_with_items,
    COUNT(DISTINCT product_id) AS unique_products,
    COUNT(DISTINCT seller_id) AS unique_sellers
FROM order_items;


-- =====================================================
-- 14. ORDER ITEM UNIQUENESS
-- =====================================================
-- order_id + order_item_id should uniquely identify
-- an order line.

SELECT
    COUNT(*) AS total_rows,

    COUNT(
        DISTINCT (order_id, order_item_id)
    ) AS unique_order_items

FROM order_items;


-- =====================================================
-- 15. PRICE AND FREIGHT VALIDATION
-- =====================================================
-- Check minimum, maximum and average values for
-- product price and freight.

SELECT
    MIN(price) AS min_price,
    MAX(price) AS max_price,
    AVG(price) AS avg_price,

    MIN(freight_value) AS min_freight,
    MAX(freight_value) AS max_freight,
    AVG(freight_value) AS avg_freight

FROM order_items;


-- =====================================================
-- 16. NEGATIVE PRICE CHECK
-- =====================================================
-- There should normally be no negative product prices.

SELECT
    COUNT(*) AS negative_price_rows

FROM order_items

WHERE price < 0;


-- =====================================================
-- 17. NEGATIVE FREIGHT CHECK
-- =====================================================
-- Check for negative freight values.

SELECT
    COUNT(*) AS negative_freight_rows

FROM order_items

WHERE freight_value < 0;