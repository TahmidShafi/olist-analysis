-- =========================================================
-- Olist E-Commerce Analysis
-- 09 - Executive Dashboard Data Layer
-- =========================================================

/*
Purpose:

Create the final analytical views used by Power BI.

Dashboard Pages:

    1. Executive Overview
    2. Revenue & Products
    3. Customers & Retention
    4. Delivery & Satisfaction

Population:
    Delivered orders only unless otherwise stated.

All headline KPIs are designed to reconcile
across the dashboard.
*/


-- =========================================================
-- 1. EXECUTIVE KPIs
-- =========================================================

DROP VIEW IF EXISTS vw_executive_kpis;

CREATE VIEW vw_executive_kpis AS

WITH delivered_orders AS (

    SELECT *

    FROM vw_order_analytics

    WHERE order_status = 'delivered'
),

customer_frequency AS (

    SELECT

        customer_unique_id,

        COUNT(*) AS order_count

    FROM delivered_orders

    GROUP BY customer_unique_id
),

customer_summary AS (

    SELECT

        COUNT(*) AS delivered_customers,

        COUNT(*) FILTER (
            WHERE order_count >= 2
        ) AS repeat_customers

    FROM customer_frequency
),

order_summary AS (

    SELECT

        COUNT(*) AS delivered_orders,

        SUM(product_revenue)
            AS product_revenue,

        SUM(total_order_value)
            AS total_order_value,

        AVG(total_order_value)
            AS average_order_value,

        AVG(average_review_score)
            FILTER (
                WHERE average_review_score IS NOT NULL
            ) AS average_review_score,

        COUNT(*) FILTER (
            WHERE delivery_delay_days > 0
        ) AS late_orders,

        COUNT(*) FILTER (
            WHERE delivery_delay_days IS NOT NULL
        ) AS orders_with_delivery_data

    FROM delivered_orders
)

SELECT

    os.delivered_orders,

    cs.delivered_customers,

    os.product_revenue,

    os.total_order_value,

    CAST(
        os.average_order_value
        AS NUMERIC(12,2)
    ) AS average_order_value,

    cs.repeat_customers,

    CAST(
        cs.repeat_customers * 100.0
        / NULLIF(cs.delivered_customers, 0)
        AS NUMERIC(10,2)
    ) AS repeat_purchase_rate_pct,

    CAST(
        os.late_orders * 100.0
        / NULLIF(os.orders_with_delivery_data, 0)
        AS NUMERIC(10,2)
    ) AS late_delivery_rate_pct,

    CAST(
        os.average_review_score
        AS NUMERIC(10,2)
    ) AS average_review_score

FROM order_summary os

CROSS JOIN customer_summary cs;


-- =========================================================
-- 2. MONTHLY BUSINESS PERFORMANCE
-- =========================================================

DROP VIEW IF EXISTS vw_monthly_business_performance;

CREATE VIEW vw_monthly_business_performance AS

SELECT

    purchase_month,

    COUNT(*) AS orders,

    COUNT(
        DISTINCT customer_unique_id
    ) AS customers,

    SUM(product_revenue)
        AS product_revenue,

    SUM(total_order_value)
        AS total_order_value,

    CAST(
        AVG(total_order_value)
        AS NUMERIC(12,2)
    ) AS average_order_value,

    CAST(
        AVG(average_review_score)
        FILTER (
            WHERE average_review_score IS NOT NULL
        )
        AS NUMERIC(10,2)
    ) AS average_review_score,

    COUNT(*) FILTER (
        WHERE delivery_delay_days > 0
    ) AS late_orders,

    COUNT(*) FILTER (
        WHERE delivery_delay_days IS NOT NULL
    ) AS orders_with_delivery_data,

    CAST(

        COUNT(*) FILTER (
            WHERE delivery_delay_days > 0
        ) * 100.0

        /

        NULLIF(
            COUNT(*) FILTER (
                WHERE delivery_delay_days IS NOT NULL
            ),
            0
        )

        AS NUMERIC(10,2)

    ) AS late_delivery_rate_pct

FROM vw_order_analytics

WHERE order_status = 'delivered'

GROUP BY purchase_month

ORDER BY purchase_month;


-- =========================================================
-- 3. CUSTOMER RFM VIEW FOR POWER BI
-- =========================================================

DROP VIEW IF EXISTS vw_customer_rfm;

CREATE VIEW vw_customer_rfm AS

WITH customer_summary AS (

    SELECT

        customer_unique_id,

        COUNT(*) AS frequency,

        SUM(product_revenue)
            AS monetary_value,

        SUM(total_order_value)
            AS total_order_value,

        MAX(purchase_date)
            AS last_purchase_date

    FROM vw_order_analytics

    WHERE order_status = 'delivered'

    GROUP BY customer_unique_id
)

SELECT

    customer_unique_id,

    frequency,

    CAST(
        monetary_value
        AS NUMERIC(12,2)
    ) AS monetary_value,

    CAST(
        total_order_value
        AS NUMERIC(12,2)
    ) AS total_order_value,

    last_purchase_date,

    (
        DATE '2018-08-29'
        - last_purchase_date
    ) AS recency_days,

    CASE

        WHEN frequency >= 2
            THEN 'Repeat Customer'

        ELSE 'One-Time Customer'

    END AS customer_type

FROM customer_summary;


-- =========================================================
-- 4. COHORT RETENTION VIEW FOR POWER BI
-- =========================================================

DROP VIEW IF EXISTS vw_cohort_retention_powerbi;

CREATE VIEW vw_cohort_retention_powerbi AS

SELECT

    cohort_month,

    month_number,

    active_customers,

    cohort_customers,

    retention_pct

FROM vw_cohort_retention

ORDER BY

    cohort_month,

    month_number;


-- =========================================================
-- 5. FINAL VALIDATION
-- =========================================================

SELECT *

FROM vw_executive_kpis;


SELECT

    COUNT(*) AS monthly_rows,

    SUM(orders) AS total_orders,

    ROUND(
        SUM(product_revenue),
        2
    ) AS total_product_revenue,

    ROUND(
        SUM(total_order_value),
        2
    ) AS total_order_value

FROM vw_monthly_business_performance;


SELECT

    COUNT(*) AS customers,

    COUNT(*) FILTER (
        WHERE customer_type = 'Repeat Customer'
    ) AS repeat_customers,

    COUNT(*) FILTER (
        WHERE customer_type = 'One-Time Customer'
    ) AS one_time_customers

FROM vw_customer_rfm;


SELECT

    COUNT(DISTINCT cohort_month)
        AS number_of_cohorts,

    MIN(month_number)
        AS minimum_month_number,

    MAX(month_number)
        AS maximum_month_number

FROM vw_cohort_retention_powerbi;