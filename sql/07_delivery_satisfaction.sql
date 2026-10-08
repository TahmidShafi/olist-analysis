/*
=========================================================
Olist E-Commerce Analysis
07 - Delivery Performance vs Satisfaction
=========================================================

BUSINESS QUESTION

    Do late deliveries correspond to lower customer
    review scores?

SECONDARY QUESTIONS

    1. What percentage of delivered orders are late?
    2. How does average review score differ between
       late and on-time/early deliveries?
    3. Does satisfaction change as delivery delay
       increases?
    4. Does the relationship vary by customer state?
    5. Does the relationship vary by product category?

DELIVERY DELAY DEFINITION

    Actual delivery date
    -
    Estimated delivery date

    Positive delay  = delivered late
    Zero delay      = delivered on estimated date
    Negative delay  = delivered early

IMPORTANT METHODOLOGICAL NOTE

    This analysis measures association/correlation.

    It does NOT establish that late delivery causes
    lower review scores.

=========================================================
*/


-- =====================================================
-- 1. DELIVERY / REVIEW DATA COVERAGE
-- =====================================================

SELECT

    COUNT(*) AS total_delivered_orders,

    COUNT(*) FILTER (
        WHERE order_delivered_customer_date IS NOT NULL
    ) AS orders_with_actual_delivery_date,

    COUNT(*) FILTER (
        WHERE order_estimated_delivery_date IS NOT NULL
    ) AS orders_with_estimated_delivery_date,

    COUNT(*) FILTER (
        WHERE delivery_delay_days IS NOT NULL
    ) AS orders_with_delivery_delay,

    COUNT(*) FILTER (
        WHERE average_review_score IS NOT NULL
    ) AS orders_with_review,

    COUNT(*) FILTER (
        WHERE delivery_delay_days IS NOT NULL
          AND average_review_score IS NOT NULL
    ) AS orders_with_delivery_and_review

FROM vw_order_analytics

WHERE order_status = 'delivered';


-- =====================================================
-- 2. DELIVERY DATE VALIDATION
-- =====================================================

SELECT

    COUNT(*) AS delivered_orders,

    COUNT(*) FILTER (
        WHERE order_delivered_customer_date
              < order_purchase_timestamp
    ) AS delivered_before_purchase,

    COUNT(*) FILTER (
        WHERE order_delivered_customer_date
              < order_approved_at
    ) AS delivered_before_approval,

    COUNT(*) FILTER (
        WHERE order_delivered_customer_date
              > order_estimated_delivery_date
    ) AS late_orders,

    COUNT(*) FILTER (
        WHERE order_delivered_customer_date
              <= order_estimated_delivery_date
    ) AS on_time_or_early_orders

FROM vw_order_analytics

WHERE order_status = 'delivered'

  AND order_delivered_customer_date IS NOT NULL

  AND order_estimated_delivery_date IS NOT NULL;


-- =====================================================
-- 3. DELIVERY DELAY DISTRIBUTION
-- =====================================================

SELECT

    COUNT(*) AS orders,

    MIN(delivery_delay_days)
        AS minimum_delay_days,

    MAX(delivery_delay_days)
        AS maximum_delay_days,

    CAST(
        AVG(delivery_delay_days)
        AS NUMERIC(10,2)
    ) AS average_delay_days,

    CAST(
        PERCENTILE_CONT(0.50)
        WITHIN GROUP (
            ORDER BY delivery_delay_days
        )
        AS NUMERIC(10,2)
    ) AS median_delay_days

FROM vw_order_analytics

WHERE order_status = 'delivered'

  AND delivery_delay_days IS NOT NULL;


-- =====================================================
-- 4. LATE DELIVERY RATE
-- =====================================================

SELECT

    CASE

        WHEN delivery_delay_days > 0
            THEN 'Late'

        WHEN delivery_delay_days <= 0
            THEN 'On Time / Early'

    END AS delivery_status,

    COUNT(*) AS orders,

    CAST(
        COUNT(*) * 100.0
        / SUM(COUNT(*)) OVER ()
        AS NUMERIC(10,2)
    ) AS order_share_pct

FROM vw_order_analytics

WHERE order_status = 'delivered'

  AND delivery_delay_days IS NOT NULL

GROUP BY

    CASE

        WHEN delivery_delay_days > 0
            THEN 'Late'

        WHEN delivery_delay_days <= 0
            THEN 'On Time / Early'

    END

ORDER BY orders DESC;


-- =====================================================
-- 5. DELIVERY STATUS VS REVIEW SCORE
-- =====================================================

SELECT

    CASE

        WHEN delivery_delay_days > 0
            THEN 'Late'

        WHEN delivery_delay_days <= 0
            THEN 'On Time / Early'

    END AS delivery_status,

    COUNT(*) AS orders_with_review,

    CAST(
        AVG(average_review_score)
        AS NUMERIC(10,2)
    ) AS average_review_score,

    CAST(
        AVG(delivery_delay_days)
        AS NUMERIC(10,2)
    ) AS average_delay_days,

    CAST(
        PERCENTILE_CONT(0.50)
        WITHIN GROUP (
            ORDER BY delivery_delay_days
        )
        AS NUMERIC(10,2)
    ) AS median_delay_days

FROM vw_order_analytics

WHERE order_status = 'delivered'

  AND delivery_delay_days IS NOT NULL

  AND average_review_score IS NOT NULL

GROUP BY

    CASE

        WHEN delivery_delay_days > 0
            THEN 'Late'

        WHEN delivery_delay_days <= 0
            THEN 'On Time / Early'

    END

ORDER BY delivery_status;


-- =====================================================
-- 6. REVIEW SCORE BY DELIVERY DELAY SEVERITY
-- =====================================================

SELECT

    CASE

        WHEN delivery_delay_days <= 0
            THEN 'On Time / Early'

        WHEN delivery_delay_days BETWEEN 1 AND 3
            THEN '1-3 Days Late'

        WHEN delivery_delay_days BETWEEN 4 AND 7
            THEN '4-7 Days Late'

        WHEN delivery_delay_days BETWEEN 8 AND 14
            THEN '8-14 Days Late'

        WHEN delivery_delay_days >= 15
            THEN '15+ Days Late'

    END AS delay_bucket,

    COUNT(*) AS orders_with_review,

    CAST(
        AVG(average_review_score)
        AS NUMERIC(10,2)
    ) AS average_review_score,

    CAST(
        AVG(delivery_delay_days)
        AS NUMERIC(10,2)
    ) AS average_delay_days,

    CAST(
        PERCENTILE_CONT(0.50)
        WITHIN GROUP (
            ORDER BY delivery_delay_days
        )
        AS NUMERIC(10,2)
    ) AS median_delay_days

FROM vw_order_analytics

WHERE order_status = 'delivered'

  AND delivery_delay_days IS NOT NULL

  AND average_review_score IS NOT NULL

GROUP BY

    CASE

        WHEN delivery_delay_days <= 0
            THEN 'On Time / Early'

        WHEN delivery_delay_days BETWEEN 1 AND 3
            THEN '1-3 Days Late'

        WHEN delivery_delay_days BETWEEN 4 AND 7
            THEN '4-7 Days Late'

        WHEN delivery_delay_days BETWEEN 8 AND 14
            THEN '8-14 Days Late'

        WHEN delivery_delay_days >= 15
            THEN '15+ Days Late'

    END

ORDER BY
    MIN(delivery_delay_days);


-- =====================================================
-- 7. REVIEW SCORE DISTRIBUTION BY DELIVERY STATUS
-- =====================================================

SELECT

    CASE

        WHEN delivery_delay_days > 0
            THEN 'Late'

        WHEN delivery_delay_days <= 0
            THEN 'On Time / Early'

    END AS delivery_status,

    average_review_score AS review_score,

    COUNT(*) AS orders,

    CAST(
        COUNT(*) * 100.0
        / SUM(COUNT(*)) OVER (
            PARTITION BY

                CASE

                    WHEN delivery_delay_days > 0
                        THEN 'Late'

                    WHEN delivery_delay_days <= 0
                        THEN 'On Time / Early'

                END
        )
        AS NUMERIC(10,2)
    ) AS score_share_pct

FROM vw_order_analytics

WHERE order_status = 'delivered'

  AND delivery_delay_days IS NOT NULL

  AND average_review_score IS NOT NULL

GROUP BY

    CASE

        WHEN delivery_delay_days > 0
            THEN 'Late'

        WHEN delivery_delay_days <= 0
            THEN 'On Time / Early'

    END,

    average_review_score

ORDER BY

    delivery_status,

    review_score;


-- =====================================================
-- 8. DELIVERY PERFORMANCE BY CUSTOMER STATE
-- =====================================================

SELECT

    c.customer_state,

    COUNT(*) AS delivered_orders,

    COUNT(*) FILTER (
        WHERE oa.delivery_delay_days > 0
    ) AS late_orders,

    CAST(
        COUNT(*) FILTER (
            WHERE oa.delivery_delay_days > 0
        ) * 100.0
        / NULLIF(COUNT(*), 0)
        AS NUMERIC(10,2)
    ) AS late_delivery_rate_pct,

    CAST(
        AVG(oa.average_review_score)
        FILTER (
            WHERE oa.average_review_score IS NOT NULL
        )
        AS NUMERIC(10,2)
    ) AS average_review_score,

    CAST(
        AVG(oa.average_review_score)
        FILTER (
            WHERE oa.delivery_delay_days > 0
              AND oa.average_review_score IS NOT NULL
        )
        AS NUMERIC(10,2)
    ) AS late_order_review_score,

    CAST(
        AVG(oa.average_review_score)
        FILTER (
            WHERE oa.delivery_delay_days <= 0
              AND oa.average_review_score IS NOT NULL
        )
        AS NUMERIC(10,2)
    ) AS on_time_review_score

FROM vw_order_analytics oa

JOIN customers c
    ON oa.customer_id = c.customer_id

WHERE oa.order_status = 'delivered'

  AND oa.delivery_delay_days IS NOT NULL

GROUP BY
    c.customer_state

HAVING COUNT(*) >= 100

ORDER BY
    late_delivery_rate_pct DESC;


-- =====================================================
-- 9A. PRODUCT CATEGORY COVERAGE
-- =====================================================

SELECT

    COUNT(*) AS total_products,

    COUNT(*) FILTER (
        WHERE product_category_name IS NOT NULL
    ) AS products_with_category,

    COUNT(DISTINCT product_category_name)
        AS categories

FROM products;


-- =====================================================
-- 9B. CATEGORY TRANSLATION COVERAGE
-- =====================================================

SELECT

    COUNT(*) AS translated_categories,

    COUNT(DISTINCT product_category_name)
        AS original_category_names,

    COUNT(DISTINCT product_category_name_english)
        AS english_category_names

FROM product_category_name_translation;


-- =====================================================
-- 9C. ORDER-CATEGORY VALIDATION
-- =====================================================

WITH order_categories AS (

    SELECT DISTINCT

        oi.order_id,

        p.product_category_name

    FROM order_items oi

    JOIN products p
        ON oi.product_id = p.product_id

    WHERE p.product_category_name IS NOT NULL
)

SELECT

    COUNT(*) AS order_category_rows,

    COUNT(DISTINCT order_id)
        AS distinct_orders,

    COUNT(DISTINCT product_category_name)
        AS distinct_categories

FROM order_categories;


-- =====================================================
-- 9D. DELIVERY PERFORMANCE BY PRODUCT CATEGORY
-- =====================================================

WITH order_categories AS (

    SELECT DISTINCT

        oi.order_id,

        p.product_category_name

    FROM order_items oi

    JOIN products p
        ON oi.product_id = p.product_id

    WHERE p.product_category_name IS NOT NULL
),

category_data AS (

    SELECT

        oc.order_id,

        COALESCE(
            pct.product_category_name_english,
            oc.product_category_name
        ) AS product_category,

        oa.delivery_delay_days,

        oa.average_review_score

    FROM order_categories oc

    JOIN vw_order_analytics oa
        ON oc.order_id = oa.order_id

    LEFT JOIN product_category_name_translation pct
        ON oc.product_category_name =
           pct.product_category_name

    WHERE oa.order_status = 'delivered'

      AND oa.delivery_delay_days IS NOT NULL
)

SELECT

    product_category,

    COUNT(*) AS category_orders,

    COUNT(*) FILTER (
        WHERE delivery_delay_days > 0
    ) AS late_orders,

    CAST(
        COUNT(*) FILTER (
            WHERE delivery_delay_days > 0
        ) * 100.0
        / NULLIF(COUNT(*), 0)
        AS NUMERIC(10,2)
    ) AS late_delivery_rate_pct,

    CAST(
        AVG(average_review_score)
        FILTER (
            WHERE average_review_score IS NOT NULL
        )
        AS NUMERIC(10,2)
    ) AS average_review_score,

    CAST(
        AVG(average_review_score)
        FILTER (
            WHERE delivery_delay_days > 0
              AND average_review_score IS NOT NULL
        )
        AS NUMERIC(10,2)
    ) AS late_order_review_score,

    CAST(
        AVG(average_review_score)
        FILTER (
            WHERE delivery_delay_days <= 0
              AND average_review_score IS NOT NULL
        )
        AS NUMERIC(10,2)
    ) AS on_time_review_score

FROM category_data

GROUP BY
    product_category

HAVING COUNT(*) >= 100

ORDER BY
    late_delivery_rate_pct DESC;


-- =====================================================
-- 10A. FINAL VIEW:
-- OVERALL DELIVERY & SATISFACTION
-- =====================================================

DROP VIEW IF EXISTS vw_delivery_satisfaction;

CREATE VIEW vw_delivery_satisfaction AS

SELECT

    CASE

        WHEN delivery_delay_days > 0
            THEN 'Late'

        WHEN delivery_delay_days <= 0
            THEN 'On Time / Early'

    END AS delivery_status,

    COUNT(*) AS orders,

    CAST(
        AVG(average_review_score)
        FILTER (
            WHERE average_review_score IS NOT NULL
        )
        AS NUMERIC(10,2)
    ) AS average_review_score,

    CAST(
        AVG(delivery_delay_days)
        AS NUMERIC(10,2)
    ) AS average_delay_days,

    CAST(
        PERCENTILE_CONT(0.50)
        WITHIN GROUP (
            ORDER BY delivery_delay_days
        )
        AS NUMERIC(10,2)
    ) AS median_delay_days

FROM vw_order_analytics

WHERE order_status = 'delivered'

  AND delivery_delay_days IS NOT NULL

GROUP BY

    CASE

        WHEN delivery_delay_days > 0
            THEN 'Late'

        WHEN delivery_delay_days <= 0
            THEN 'On Time / Early'

    END;


-- =====================================================
-- 10B. FINAL VIEW:
-- DELIVERY DELAY BUCKETS
-- =====================================================

DROP VIEW IF EXISTS vw_delivery_delay_buckets;

CREATE VIEW vw_delivery_delay_buckets AS

SELECT

    CASE

        WHEN delivery_delay_days <= 0
            THEN 'On Time / Early'

        WHEN delivery_delay_days BETWEEN 1 AND 3
            THEN '1-3 Days Late'

        WHEN delivery_delay_days BETWEEN 4 AND 7
            THEN '4-7 Days Late'

        WHEN delivery_delay_days BETWEEN 8 AND 14
            THEN '8-14 Days Late'

        WHEN delivery_delay_days >= 15
            THEN '15+ Days Late'

    END AS delay_bucket,

    COUNT(*) AS orders,

    CAST(
        AVG(average_review_score)
        FILTER (
            WHERE average_review_score IS NOT NULL
        )
        AS NUMERIC(10,2)
    ) AS average_review_score,

    CAST(
        AVG(delivery_delay_days)
        AS NUMERIC(10,2)
    ) AS average_delay_days

FROM vw_order_analytics

WHERE order_status = 'delivered'

  AND delivery_delay_days IS NOT NULL

GROUP BY

    CASE

        WHEN delivery_delay_days <= 0
            THEN 'On Time / Early'

        WHEN delivery_delay_days BETWEEN 1 AND 3
            THEN '1-3 Days Late'

        WHEN delivery_delay_days BETWEEN 4 AND 7
            THEN '4-7 Days Late'

        WHEN delivery_delay_days BETWEEN 8 AND 14
            THEN '8-14 Days Late'

        WHEN delivery_delay_days >= 15
            THEN '15+ Days Late'

    END;


-- =====================================================
-- 10C. FINAL VIEW:
-- DELIVERY PERFORMANCE BY CUSTOMER STATE
-- =====================================================

DROP VIEW IF EXISTS vw_delivery_state;

CREATE VIEW vw_delivery_state AS

SELECT

    c.customer_state,

    COUNT(*) AS delivered_orders,

    COUNT(*) FILTER (
        WHERE oa.delivery_delay_days > 0
    ) AS late_orders,

    CAST(
        COUNT(*) FILTER (
            WHERE oa.delivery_delay_days > 0
        ) * 100.0
        / NULLIF(COUNT(*), 0)
        AS NUMERIC(10,2)
    ) AS late_delivery_rate_pct,

    CAST(
        AVG(oa.average_review_score)
        FILTER (
            WHERE oa.average_review_score IS NOT NULL
        )
        AS NUMERIC(10,2)
    ) AS average_review_score,

    CAST(
        AVG(oa.average_review_score)
        FILTER (
            WHERE oa.delivery_delay_days > 0
              AND oa.average_review_score IS NOT NULL
        )
        AS NUMERIC(10,2)
    ) AS late_order_review_score,

    CAST(
        AVG(oa.average_review_score)
        FILTER (
            WHERE oa.delivery_delay_days <= 0
              AND oa.average_review_score IS NOT NULL
        )
        AS NUMERIC(10,2)
    ) AS on_time_review_score

FROM vw_order_analytics oa

JOIN customers c
    ON oa.customer_id = c.customer_id

WHERE oa.order_status = 'delivered'

  AND oa.delivery_delay_days IS NOT NULL

GROUP BY
    c.customer_state

HAVING COUNT(*) >= 100;


-- =====================================================
-- 10D. FINAL VIEW:
-- DELIVERY PERFORMANCE BY PRODUCT CATEGORY
-- =====================================================

DROP VIEW IF EXISTS vw_delivery_category;

CREATE VIEW vw_delivery_category AS

WITH order_categories AS (

    SELECT DISTINCT

        oi.order_id,

        p.product_category_name

    FROM order_items oi

    JOIN products p
        ON oi.product_id = p.product_id

    WHERE p.product_category_name IS NOT NULL
),

category_data AS (

    SELECT

        oc.order_id,

        COALESCE(
            pct.product_category_name_english,
            oc.product_category_name
        ) AS product_category,

        oa.delivery_delay_days,

        oa.average_review_score

    FROM order_categories oc

    JOIN vw_order_analytics oa
        ON oc.order_id = oa.order_id

    LEFT JOIN product_category_name_translation pct
        ON oc.product_category_name =
           pct.product_category_name

    WHERE oa.order_status = 'delivered'

      AND oa.delivery_delay_days IS NOT NULL
)

SELECT

    product_category,

    COUNT(*) AS category_orders,

    COUNT(*) FILTER (
        WHERE delivery_delay_days > 0
    ) AS late_orders,

    CAST(
        COUNT(*) FILTER (
            WHERE delivery_delay_days > 0
        ) * 100.0
        / NULLIF(COUNT(*), 0)
        AS NUMERIC(10,2)
    ) AS late_delivery_rate_pct,

    CAST(
        AVG(average_review_score)
        FILTER (
            WHERE average_review_score IS NOT NULL
        )
        AS NUMERIC(10,2)
    ) AS average_review_score,

    CAST(
        AVG(average_review_score)
        FILTER (
            WHERE delivery_delay_days > 0
              AND average_review_score IS NOT NULL
        )
        AS NUMERIC(10,2)
    ) AS late_order_review_score,

    CAST(
        AVG(average_review_score)
        FILTER (
            WHERE delivery_delay_days <= 0
              AND average_review_score IS NOT NULL
        )
        AS NUMERIC(10,2)
    ) AS on_time_review_score

FROM category_data

GROUP BY
    product_category

HAVING COUNT(*) >= 100;


-- =====================================================
-- 11. FINAL VIEW VALIDATION
-- =====================================================

SELECT
    'vw_delivery_satisfaction' AS view_name,
    COUNT(*) AS rows
FROM vw_delivery_satisfaction

UNION ALL

SELECT
    'vw_delivery_delay_buckets',
    COUNT(*)
FROM vw_delivery_delay_buckets

UNION ALL

SELECT
    'vw_delivery_state',
    COUNT(*)
FROM vw_delivery_state

UNION ALL

SELECT
    'vw_delivery_category',
    COUNT(*)
FROM vw_delivery_category;


-- =====================================================
-- 12. FINAL SAMPLE CHECKS
-- =====================================================

SELECT *
FROM vw_delivery_satisfaction
ORDER BY delivery_status;


SELECT *
FROM vw_delivery_delay_buckets
ORDER BY
    CASE delay_bucket
        WHEN 'On Time / Early' THEN 1
        WHEN '1-3 Days Late' THEN 2
        WHEN '4-7 Days Late' THEN 3
        WHEN '8-14 Days Late' THEN 4
        WHEN '15+ Days Late' THEN 5
    END;


SELECT *
FROM vw_delivery_state
ORDER BY late_delivery_rate_pct DESC;


SELECT *
FROM vw_delivery_category
ORDER BY late_delivery_rate_pct DESC;