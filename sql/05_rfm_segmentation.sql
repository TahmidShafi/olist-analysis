/*
=========================================================
Olist E-Commerce Analysis
05 - RFM Customer Segmentation
=========================================================

Purpose:
    Segment Olist customers based on purchasing behavior.

Primary Business Questions:
    1. How recently did customers purchase?
    2. How much value did customers generate?
    3. How many customers are repeat purchasers?
    4. Which customer segments are most valuable?
    5. Which high-value customers may be at risk?

=========================================================
METHODOLOGY
=========================================================

Customer Definition:
    customer_unique_id

Why customer_unique_id?
    customer_id represents an order-level customer record.
    customer_unique_id is used to identify the underlying
    customer across purchases.

Purchase Population:
    Delivered orders only.

Excluded:
    canceled
    unavailable
    other non-delivered statuses

Recency:
    Number of days since the customer's latest delivered
    purchase.

Frequency:
    Number of distinct delivered orders.

Monetary:
    SUM(product_revenue)

    product_revenue comes from vw_order_analytics and
    represents product price, excluding freight.

Snapshot Date:
    Latest delivered purchase date in the dataset.

Important Dataset Finding:
    97% of customers have exactly one delivered order.

    Therefore Frequency has very limited discriminatory
    power and is NOT used as a primary NTILE score.

Primary segmentation dimensions:
    Recency
    Monetary

Frequency is retained as:
    - descriptive metric
    - repeat-customer indicator

=========================================================
*/


-- =====================================================
-- 1. RFM SNAPSHOT DATE
-- =====================================================
-- The snapshot date is the latest delivered purchase
-- date in the dataset.
-- =====================================================

SELECT

    MAX(purchase_date) AS snapshot_date

FROM vw_order_analytics

WHERE order_status = 'delivered'

  AND customer_unique_id IS NOT NULL;


-- =====================================================
-- 2. CUSTOMER FREQUENCY DISTRIBUTION
-- =====================================================
-- Understand how many purchases customers make.
--
-- This is important before applying traditional RFM
-- frequency scoring.
-- =====================================================

WITH customer_frequency AS (

    SELECT

        customer_unique_id,

        COUNT(DISTINCT order_id) AS frequency

    FROM vw_order_analytics

    WHERE order_status = 'delivered'

      AND customer_unique_id IS NOT NULL

    GROUP BY customer_unique_id
)

SELECT

    frequency,

    COUNT(*) AS customer_count,

    ROUND(
        COUNT(*) * 100.0
        / SUM(COUNT(*)) OVER (),
        2
    ) AS customer_share_pct

FROM customer_frequency

GROUP BY frequency

ORDER BY frequency;


-- =====================================================
-- 3. RAW CUSTOMER RFM METRICS
-- =====================================================
-- Creates one row per customer.
--
-- Grain:
--     One row = one customer_unique_id
-- =====================================================

WITH snapshot AS (

    SELECT

        MAX(purchase_date) AS snapshot_date

    FROM vw_order_analytics

    WHERE order_status = 'delivered'

      AND customer_unique_id IS NOT NULL
),

customer_rfm AS (

    SELECT

        o.customer_unique_id,

        MAX(o.purchase_date)
            AS last_purchase_date,

        COUNT(DISTINCT o.order_id)
            AS frequency,

        SUM(o.product_revenue)
            AS monetary

    FROM vw_order_analytics o

    WHERE o.order_status = 'delivered'

      AND o.customer_unique_id IS NOT NULL

    GROUP BY o.customer_unique_id
)

SELECT

    c.customer_unique_id,

    s.snapshot_date,

    c.last_purchase_date,

    (
        s.snapshot_date
        - c.last_purchase_date
    ) AS recency,

    c.frequency,

    ROUND(
        c.monetary,
        2
    ) AS monetary

FROM customer_rfm c

CROSS JOIN snapshot s

ORDER BY monetary DESC;


-- =====================================================
-- 4. RECENCY + MONETARY SCORES
-- =====================================================
-- Frequency is deliberately NOT scored.
--
-- Recency:
--     Lower number of days = better.
--
-- Monetary:
--     Higher value = better.
--
-- NTILE(5):
--     1 = lowest fifth
--     5 = highest fifth
-- =====================================================

WITH snapshot AS (

    SELECT

        MAX(purchase_date) AS snapshot_date

    FROM vw_order_analytics

    WHERE order_status = 'delivered'

      AND customer_unique_id IS NOT NULL
),

customer_rfm AS (

    SELECT

        o.customer_unique_id,

        MAX(o.purchase_date)
            AS last_purchase_date,

        COUNT(DISTINCT o.order_id)
            AS frequency,

        SUM(o.product_revenue)
            AS monetary

    FROM vw_order_analytics o

    WHERE o.order_status = 'delivered'

      AND o.customer_unique_id IS NOT NULL

    GROUP BY o.customer_unique_id
),

rfm_metrics AS (

    SELECT

        c.customer_unique_id,

        s.snapshot_date,

        c.last_purchase_date,

        (
            s.snapshot_date
            - c.last_purchase_date
        ) AS recency,

        c.frequency,

        c.monetary

    FROM customer_rfm c

    CROSS JOIN snapshot s
),

rm_scores AS (

    SELECT

        *,

        /*
        Lower recency is better.

        DESC causes the most recent customers
        to receive the highest score.
        */

        NTILE(5) OVER (
            ORDER BY recency DESC
        ) AS recency_score,

        /*
        Higher monetary value is better.
        */

        NTILE(5) OVER (
            ORDER BY monetary ASC
        ) AS monetary_score

    FROM rfm_metrics
)

SELECT

    customer_unique_id,

    snapshot_date,

    last_purchase_date,

    recency,

    frequency,

    ROUND(
        monetary,
        2
    ) AS monetary,

    recency_score,

    monetary_score,

    CONCAT(
        recency_score,
        monetary_score
    ) AS rm_score

FROM rm_scores

ORDER BY

    recency_score DESC,

    monetary_score DESC,

    monetary DESC;


-- =====================================================
-- 5. EXACT REPEAT-PURCHASE RATE
-- =====================================================
-- Repeat customer:
--     frequency >= 2
--
-- One-time customer:
--     frequency = 1
-- =====================================================

WITH customer_frequency AS (

    SELECT

        customer_unique_id,

        COUNT(DISTINCT order_id)
            AS frequency

    FROM vw_order_analytics

    WHERE order_status = 'delivered'

      AND customer_unique_id IS NOT NULL

    GROUP BY customer_unique_id
)

SELECT

    COUNT(*) AS total_customers,

    COUNT(*) FILTER (
        WHERE frequency >= 2
    ) AS repeat_customers,

    COUNT(*) FILTER (
        WHERE frequency = 1
    ) AS one_time_customers,

    ROUND(
        COUNT(*) FILTER (
            WHERE frequency >= 2
        ) * 100.0
        / NULLIF(COUNT(*), 0),
        2
    ) AS repeat_purchase_rate_pct,

    ROUND(
        COUNT(*) FILTER (
            WHERE frequency = 1
        ) * 100.0
        / NULLIF(COUNT(*), 0),
        2
    ) AS one_time_customer_rate_pct

FROM customer_frequency;


-- =====================================================
-- 6. RECENCY + MONETARY CUSTOMER SEGMENTS
-- =====================================================
-- Primary segmentation logic.
--
-- Recent High Value:
--     High recency score
--     High monetary score
--
-- Recent Low/Medium Value:
--     High recency score
--     Lower monetary score
--
-- High Value At Risk:
--     Low recency score
--     High monetary score
--
-- Inactive / Low Value:
--     Low recency score
--     Low monetary score
--
-- Middle Value:
--     Everything else.
-- =====================================================

WITH snapshot AS (

    SELECT

        MAX(purchase_date) AS snapshot_date

    FROM vw_order_analytics

    WHERE order_status = 'delivered'

      AND customer_unique_id IS NOT NULL
),

customer_rfm AS (

    SELECT

        o.customer_unique_id,

        MAX(o.purchase_date)
            AS last_purchase_date,

        COUNT(DISTINCT o.order_id)
            AS frequency,

        SUM(o.product_revenue)
            AS monetary

    FROM vw_order_analytics o

    WHERE o.order_status = 'delivered'

      AND o.customer_unique_id IS NOT NULL

    GROUP BY o.customer_unique_id
),

rfm_metrics AS (

    SELECT

        c.customer_unique_id,

        s.snapshot_date,

        c.last_purchase_date,

        (
            s.snapshot_date
            - c.last_purchase_date
        ) AS recency,

        c.frequency,

        c.monetary

    FROM customer_rfm c

    CROSS JOIN snapshot s
),

rm_scores AS (

    SELECT

        *,

        NTILE(5) OVER (
            ORDER BY recency DESC
        ) AS recency_score,

        NTILE(5) OVER (
            ORDER BY monetary ASC
        ) AS monetary_score

    FROM rfm_metrics
)

SELECT

    customer_unique_id,

    snapshot_date,

    last_purchase_date,

    recency,

    frequency,

    ROUND(
        monetary,
        2
    ) AS monetary,

    recency_score,

    monetary_score,

    CASE

        WHEN recency_score >= 4
         AND monetary_score >= 4
            THEN 'Recent High Value'

        WHEN recency_score >= 4
         AND monetary_score < 4
            THEN 'Recent Low/Medium Value'

        WHEN recency_score <= 2
         AND monetary_score >= 4
            THEN 'High Value At Risk'

        WHEN recency_score <= 2
         AND monetary_score < 4
            THEN 'Inactive / Low Value'

        ELSE 'Middle Value'

    END AS customer_segment,

    CASE

        WHEN frequency >= 2
            THEN 'Repeat Customer'

        ELSE 'One-Time Customer'

    END AS purchase_type

FROM rm_scores

ORDER BY

    recency_score DESC,

    monetary_score DESC,

    monetary DESC;


-- =====================================================
-- 7. CUSTOMER SEGMENT SUMMARY
-- =====================================================
-- Main business summary for the RFM analysis.
-- =====================================================

WITH snapshot AS (

    SELECT

        MAX(purchase_date) AS snapshot_date

    FROM vw_order_analytics

    WHERE order_status = 'delivered'

      AND customer_unique_id IS NOT NULL
),

customer_rfm AS (

    SELECT

        o.customer_unique_id,

        MAX(o.purchase_date)
            AS last_purchase_date,

        COUNT(DISTINCT o.order_id)
            AS frequency,

        SUM(o.product_revenue)
            AS monetary

    FROM vw_order_analytics o

    WHERE o.order_status = 'delivered'

      AND o.customer_unique_id IS NOT NULL

    GROUP BY o.customer_unique_id
),

rfm_metrics AS (

    SELECT

        c.customer_unique_id,

        s.snapshot_date,

        (
            s.snapshot_date
            - c.last_purchase_date
        ) AS recency,

        c.frequency,

        c.monetary

    FROM customer_rfm c

    CROSS JOIN snapshot s
),

rm_scores AS (

    SELECT

        *,

        NTILE(5) OVER (
            ORDER BY recency DESC
        ) AS recency_score,

        NTILE(5) OVER (
            ORDER BY monetary ASC
        ) AS monetary_score

    FROM rfm_metrics
),

segmented_customers AS (

    SELECT

        *,

        CASE

            WHEN recency_score >= 4
             AND monetary_score >= 4
                THEN 'Recent High Value'

            WHEN recency_score >= 4
             AND monetary_score < 4
                THEN 'Recent Low/Medium Value'

            WHEN recency_score <= 2
             AND monetary_score >= 4
                THEN 'High Value At Risk'

            WHEN recency_score <= 2
             AND monetary_score < 4
                THEN 'Inactive / Low Value'

            ELSE 'Middle Value'

        END AS customer_segment

    FROM rm_scores
)

SELECT

    customer_segment,

    COUNT(*) AS customers,

    ROUND(
        COUNT(*) * 100.0
        / SUM(COUNT(*)) OVER (),
        2
    ) AS customer_share_pct,

    COUNT(*) FILTER (
        WHERE frequency >= 2
    ) AS repeat_customers,

    ROUND(
        SUM(monetary),
        2
    ) AS total_monetary,

    ROUND(
        AVG(monetary),
        2
    ) AS avg_customer_value

FROM segmented_customers

GROUP BY customer_segment

ORDER BY total_monetary DESC;


-- =====================================================
-- 8. SEGMENT x PURCHASE TYPE
-- =====================================================
-- Shows where repeat customers are concentrated.
-- =====================================================

WITH snapshot AS (

    SELECT

        MAX(purchase_date) AS snapshot_date

    FROM vw_order_analytics

    WHERE order_status = 'delivered'

      AND customer_unique_id IS NOT NULL
),

customer_rfm AS (

    SELECT

        o.customer_unique_id,

        MAX(o.purchase_date)
            AS last_purchase_date,

        COUNT(DISTINCT o.order_id)
            AS frequency,

        SUM(o.product_revenue)
            AS monetary

    FROM vw_order_analytics o

    WHERE o.order_status = 'delivered'

      AND o.customer_unique_id IS NOT NULL

    GROUP BY o.customer_unique_id
),

rfm_metrics AS (

    SELECT

        c.customer_unique_id,

        s.snapshot_date,

        (
            s.snapshot_date
            - c.last_purchase_date
        ) AS recency,

        c.frequency,

        c.monetary

    FROM customer_rfm c

    CROSS JOIN snapshot s
),

rm_scores AS (

    SELECT

        *,

        NTILE(5) OVER (
            ORDER BY recency DESC
        ) AS recency_score,

        NTILE(5) OVER (
            ORDER BY monetary ASC
        ) AS monetary_score

    FROM rfm_metrics
),

segmented_customers AS (

    SELECT

        *,

        CASE

            WHEN recency_score >= 4
             AND monetary_score >= 4
                THEN 'Recent High Value'

            WHEN recency_score >= 4
             AND monetary_score < 4
                THEN 'Recent Low/Medium Value'

            WHEN recency_score <= 2
             AND monetary_score >= 4
                THEN 'High Value At Risk'

            WHEN recency_score <= 2
             AND monetary_score < 4
                THEN 'Inactive / Low Value'

            ELSE 'Middle Value'

        END AS customer_segment,

        CASE

            WHEN frequency >= 2
                THEN 'Repeat Customer'

            ELSE 'One-Time Customer'

        END AS purchase_type

    FROM rm_scores
)

SELECT

    customer_segment,

    purchase_type,

    COUNT(*) AS customers,

    ROUND(
        COUNT(*) * 100.0
        / SUM(COUNT(*)) OVER (
            PARTITION BY customer_segment
        ),
        2
    ) AS segment_purchase_type_pct

FROM segmented_customers

GROUP BY

    customer_segment,

    purchase_type

ORDER BY

    customer_segment,

    purchase_type;


-- =====================================================
-- 9. HIGH VALUE AT RISK ANALYSIS
-- =====================================================
-- Specifically quantifies the customers who have:
--
--     Low recency score
--     High monetary score
--
-- These customers are potentially useful targets for
-- reactivation efforts.
-- =====================================================

WITH snapshot AS (

    SELECT

        MAX(purchase_date) AS snapshot_date

    FROM vw_order_analytics

    WHERE order_status = 'delivered'

      AND customer_unique_id IS NOT NULL
),

customer_rfm AS (

    SELECT

        o.customer_unique_id,

        MAX(o.purchase_date)
            AS last_purchase_date,

        COUNT(DISTINCT o.order_id)
            AS frequency,

        SUM(o.product_revenue)
            AS monetary

    FROM vw_order_analytics o

    WHERE o.order_status = 'delivered'

      AND o.customer_unique_id IS NOT NULL

    GROUP BY o.customer_unique_id
),

rfm_metrics AS (

    SELECT

        c.customer_unique_id,

        s.snapshot_date,

        (
            s.snapshot_date
            - c.last_purchase_date
        ) AS recency,

        c.frequency,

        c.monetary

    FROM customer_rfm c

    CROSS JOIN snapshot s
),

rm_scores AS (

    SELECT

        *,

        NTILE(5) OVER (
            ORDER BY recency DESC
        ) AS recency_score,

        NTILE(5) OVER (
            ORDER BY monetary ASC
        ) AS monetary_score

    FROM rfm_metrics
)

SELECT

    COUNT(*) AS high_value_at_risk_customers,

    COUNT(*) FILTER (
        WHERE frequency >= 2
    ) AS repeat_customers,

    ROUND(
        SUM(monetary),
        2
    ) AS total_monetary,

    ROUND(
        AVG(monetary),
        2
    ) AS avg_customer_value,

    ROUND(
        COUNT(*) * 100.0
        / SUM(COUNT(*)) OVER (),
        2
    ) AS segment_share_pct

FROM rm_scores

WHERE recency_score <= 2

  AND monetary_score >= 4;


-- =====================================================
-- 10. RECENT HIGH VALUE ANALYSIS
-- =====================================================
-- Customers who are both recently active and
-- financially valuable.
-- =====================================================

WITH snapshot AS (

    SELECT

        MAX(purchase_date) AS snapshot_date

    FROM vw_order_analytics

    WHERE order_status = 'delivered'

      AND customer_unique_id IS NOT NULL
),

customer_rfm AS (

    SELECT

        o.customer_unique_id,

        MAX(o.purchase_date)
            AS last_purchase_date,

        COUNT(DISTINCT o.order_id)
            AS frequency,

        SUM(o.product_revenue)
            AS monetary

    FROM vw_order_analytics o

    WHERE o.order_status = 'delivered'

      AND o.customer_unique_id IS NOT NULL

    GROUP BY o.customer_unique_id
),

rfm_metrics AS (

    SELECT

        c.customer_unique_id,

        s.snapshot_date,

        (
            s.snapshot_date
            - c.last_purchase_date
        ) AS recency,

        c.frequency,

        c.monetary

    FROM customer_rfm c

    CROSS JOIN snapshot s
),

rm_scores AS (

    SELECT

        *,

        NTILE(5) OVER (
            ORDER BY recency DESC
        ) AS recency_score,

        NTILE(5) OVER (
            ORDER BY monetary ASC
        ) AS monetary_score

    FROM rfm_metrics
)

SELECT

    COUNT(*) AS recent_high_value_customers,

    COUNT(*) FILTER (
        WHERE frequency >= 2
    ) AS repeat_customers,

    ROUND(
        SUM(monetary),
        2
    ) AS total_monetary,

    ROUND(
        AVG(monetary),
        2
    ) AS avg_customer_value

FROM rm_scores

WHERE recency_score >= 4

  AND monetary_score >= 4;


-- =====================================================
-- 11. TOP 20 CUSTOMERS BY MONETARY VALUE
-- =====================================================
-- Useful for validating the monetary calculations and
-- identifying the highest-value customers.
-- =====================================================

SELECT

    customer_unique_id,

    MAX(purchase_date)
        AS last_purchase_date,

    COUNT(DISTINCT order_id)
        AS frequency,

    ROUND(
        SUM(product_revenue),
        2
    ) AS monetary

FROM vw_order_analytics

WHERE order_status = 'delivered'

  AND customer_unique_id IS NOT NULL

GROUP BY customer_unique_id

ORDER BY monetary DESC

LIMIT 20;


-- =====================================================
-- 12. RFM DATASET VALIDATION
-- =====================================================
-- Confirms:
--     1. Customer count
--     2. Unique customer count
--     3. Repeat customer count
--     4. Snapshot date
-- =====================================================

WITH snapshot AS (

    SELECT

        MAX(purchase_date) AS snapshot_date

    FROM vw_order_analytics

    WHERE order_status = 'delivered'

      AND customer_unique_id IS NOT NULL
),

customer_rfm AS (

    SELECT

        o.customer_unique_id,

        MAX(o.purchase_date)
            AS last_purchase_date,

        COUNT(DISTINCT o.order_id)
            AS frequency,

        SUM(o.product_revenue)
            AS monetary

    FROM vw_order_analytics o

    WHERE o.order_status = 'delivered'

      AND o.customer_unique_id IS NOT NULL

    GROUP BY o.customer_unique_id
)

SELECT

    COUNT(*) AS total_customers,

    COUNT(DISTINCT customer_unique_id)
        AS unique_customer_ids,

    COUNT(*) FILTER (
        WHERE frequency >= 2
    ) AS repeat_customers,

    COUNT(*) FILTER (
        WHERE frequency = 1
    ) AS one_time_customers,

    MAX(snapshot_date)
        AS snapshot_date

FROM customer_rfm

CROSS JOIN snapshot;


-- =====================================================
-- END OF 05_RFM_SEGMENTATION.SQL
-- =====================================================