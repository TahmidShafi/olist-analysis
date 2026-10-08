/*
=========================================================
Olist E-Commerce Analysis
06 - Cohort Retention Analysis
=========================================================

Business Question:

    After customers make their first delivered purchase,
    how often do they return and purchase again?

Customer Definition:

    customer_unique_id

Purchase Population:

    Delivered orders only.

Cohort Definition:

    The month of the customer's first delivered purchase.

Retention Definition:

    Percentage of customers from a cohort who make at
    least one delivered purchase in a given month after
    their first purchase.

Month Number:

    0 = first purchase month
    1 = one month after first purchase
    2 = two months after first purchase
    etc.

Important Findings:

    Total customers analyzed: 93,358
    Number of cohorts: 23
    Overall repeat-purchase rate: 3.00%
    Month-1 retention: 0.48%

Important Interpretation:

    Repeat-purchase rate and monthly retention are
    different metrics.

    A customer can make a second purchase several months
    after their first purchase and therefore count as a
    repeat customer without being retained in Month 1.

=========================================================
*/


-- =====================================================
-- 1. FIRST PURCHASE PER CUSTOMER
-- =====================================================
-- Identify the first delivered purchase for each
-- customer_unique_id.
--
-- This determines the customer's cohort.
-- =====================================================

SELECT

    customer_unique_id,

    MIN(purchase_date) AS first_purchase_date,

    DATE_TRUNC(
        'month',
        MIN(purchase_date)
    ) AS cohort_month

FROM vw_order_analytics

WHERE order_status = 'delivered'

  AND customer_unique_id IS NOT NULL

GROUP BY customer_unique_id

ORDER BY first_purchase_date;


-- =====================================================
-- 2. COHORT SIZE
-- =====================================================
-- Count customers belonging to each cohort.
-- =====================================================

WITH customer_first_purchase AS (

    SELECT

        customer_unique_id,

        DATE_TRUNC(
            'month',
            MIN(purchase_date)
        ) AS cohort_month

    FROM vw_order_analytics

    WHERE order_status = 'delivered'

      AND customer_unique_id IS NOT NULL

    GROUP BY customer_unique_id
)

SELECT

    cohort_month,

    COUNT(*) AS cohort_customers

FROM customer_first_purchase

GROUP BY cohort_month

ORDER BY cohort_month;


-- =====================================================
-- 2B. COHORT SIZE VALIDATION
-- =====================================================
-- The total number of customers across all cohorts
-- should equal the Phase 6 customer population:
--
--     93,358 customers
-- =====================================================

WITH customer_first_purchase AS (

    SELECT

        customer_unique_id,

        DATE_TRUNC(
            'month',
            MIN(purchase_date)
        ) AS cohort_month

    FROM vw_order_analytics

    WHERE order_status = 'delivered'

      AND customer_unique_id IS NOT NULL

    GROUP BY customer_unique_id
),

cohort_sizes AS (

    SELECT

        cohort_month,

        COUNT(*) AS cohort_customers

    FROM customer_first_purchase

    GROUP BY cohort_month
)

SELECT

    SUM(cohort_customers)
        AS total_cohort_customers,

    COUNT(*)
        AS number_of_cohorts

FROM cohort_sizes;


-- =====================================================
-- 3. CUSTOMER COHORT + PURCHASE MONTH
-- =====================================================
-- Connect each customer to:
--
--     cohort_month
--     purchase_month
--
-- DISTINCT is important because a customer may place
-- multiple orders in the same month.
--
-- For retention, we only need to know whether the
-- customer was active during that month.
-- =====================================================

WITH customer_first_purchase AS (

    SELECT

        customer_unique_id,

        DATE_TRUNC(
            'month',
            MIN(purchase_date)
        ) AS cohort_month

    FROM vw_order_analytics

    WHERE order_status = 'delivered'

      AND customer_unique_id IS NOT NULL

    GROUP BY customer_unique_id
),

customer_activity AS (

    SELECT DISTINCT

        o.customer_unique_id,

        c.cohort_month,

        o.purchase_month

    FROM vw_order_analytics o

    JOIN customer_first_purchase c

        ON o.customer_unique_id
        = c.customer_unique_id

    WHERE o.order_status = 'delivered'

      AND o.customer_unique_id IS NOT NULL
)

SELECT

    cohort_month,

    purchase_month,

    COUNT(DISTINCT customer_unique_id)
        AS active_customers

FROM customer_activity

GROUP BY

    cohort_month,

    purchase_month

ORDER BY

    cohort_month,

    purchase_month;


-- =====================================================
-- 4. COHORT MONTH NUMBER
-- =====================================================
-- Convert calendar months into relative months:
--
--     Month 0 = first purchase month
--     Month 1 = one month later
--     Month 2 = two months later
--     ...
-- =====================================================

WITH customer_first_purchase AS (

    SELECT

        customer_unique_id,

        DATE_TRUNC(
            'month',
            MIN(purchase_date)
        ) AS cohort_month

    FROM vw_order_analytics

    WHERE order_status = 'delivered'

      AND customer_unique_id IS NOT NULL

    GROUP BY customer_unique_id
),

customer_activity AS (

    SELECT DISTINCT

        o.customer_unique_id,

        c.cohort_month,

        o.purchase_month

    FROM vw_order_analytics o

    JOIN customer_first_purchase c

        ON o.customer_unique_id
        = c.customer_unique_id

    WHERE o.order_status = 'delivered'

      AND o.customer_unique_id IS NOT NULL
),

cohort_activity AS (

    SELECT

        cohort_month,

        purchase_month,

        (
            EXTRACT(YEAR FROM purchase_month)
            - EXTRACT(YEAR FROM cohort_month)
        ) * 12

        +

        (
            EXTRACT(MONTH FROM purchase_month)
            - EXTRACT(MONTH FROM cohort_month)
        ) AS month_number,

        COUNT(DISTINCT customer_unique_id)
            AS active_customers

    FROM customer_activity

    GROUP BY

        cohort_month,

        purchase_month

)

SELECT

    cohort_month,

    purchase_month,

    month_number,

    active_customers

FROM cohort_activity

ORDER BY

    cohort_month,

    month_number;


-- =====================================================
-- 5. COHORT RETENTION %
-- =====================================================
-- Calculate:
--
--     active customers
--     -----------------
--     cohort customers
--            × 100
--
-- Month 0 should equal 100% for every cohort.
-- =====================================================

WITH customer_first_purchase AS (

    SELECT

        customer_unique_id,

        DATE_TRUNC(
            'month',
            MIN(purchase_date)
        ) AS cohort_month

    FROM vw_order_analytics

    WHERE order_status = 'delivered'

      AND customer_unique_id IS NOT NULL

    GROUP BY customer_unique_id
),

customer_activity AS (

    SELECT DISTINCT

        o.customer_unique_id,

        c.cohort_month,

        o.purchase_month

    FROM vw_order_analytics o

    JOIN customer_first_purchase c

        ON o.customer_unique_id
        = c.customer_unique_id

    WHERE o.order_status = 'delivered'

      AND o.customer_unique_id IS NOT NULL
),

cohort_activity AS (

    SELECT

        cohort_month,

        purchase_month,

        (
            EXTRACT(YEAR FROM purchase_month)
            - EXTRACT(YEAR FROM cohort_month)
        ) * 12

        +

        (
            EXTRACT(MONTH FROM purchase_month)
            - EXTRACT(MONTH FROM cohort_month)
        ) AS month_number,

        COUNT(DISTINCT customer_unique_id)
            AS active_customers

    FROM customer_activity

    GROUP BY

        cohort_month,

        purchase_month
),

cohort_sizes AS (

    SELECT

        cohort_month,

        COUNT(*) AS cohort_customers

    FROM customer_first_purchase

    GROUP BY cohort_month
)

SELECT

    a.cohort_month,

    a.purchase_month,

    a.month_number,

    a.active_customers,

    s.cohort_customers,

    ROUND(

        a.active_customers * 100.0
        / NULLIF(
            s.cohort_customers,
            0
        ),

        2

    ) AS retention_pct

FROM cohort_activity a

JOIN cohort_sizes s

    ON a.cohort_month = s.cohort_month

ORDER BY

    a.cohort_month,

    a.month_number;


-- =====================================================
-- 6. COMPLETE COHORT RETENTION MATRIX
-- =====================================================
-- Creates missing cohort/month combinations.
--
-- If no customer returned during a month:
--
--     active_customers = 0
--     retention_pct = 0
--
-- This creates the proper dataset for a Power BI
-- cohort heatmap.
-- =====================================================

WITH customer_first_purchase AS (

    SELECT

        customer_unique_id,

        DATE_TRUNC(
            'month',
            MIN(purchase_date)
        ) AS cohort_month

    FROM vw_order_analytics

    WHERE order_status = 'delivered'

      AND customer_unique_id IS NOT NULL

    GROUP BY customer_unique_id
),

customer_activity AS (

    SELECT DISTINCT

        o.customer_unique_id,

        c.cohort_month,

        o.purchase_month

    FROM vw_order_analytics o

    JOIN customer_first_purchase c

        ON o.customer_unique_id
        = c.customer_unique_id

    WHERE o.order_status = 'delivered'

      AND o.customer_unique_id IS NOT NULL
),

cohort_activity AS (

    SELECT

        cohort_month,

        purchase_month,

        (
            EXTRACT(YEAR FROM purchase_month)
            - EXTRACT(YEAR FROM cohort_month)
        ) * 12

        +

        (
            EXTRACT(MONTH FROM purchase_month)
            - EXTRACT(MONTH FROM cohort_month)
        ) AS month_number,

        COUNT(DISTINCT customer_unique_id)
            AS active_customers

    FROM customer_activity

    GROUP BY

        cohort_month,

        purchase_month
),

cohort_sizes AS (

    SELECT

        cohort_month,

        COUNT(*) AS cohort_customers

    FROM customer_first_purchase

    GROUP BY cohort_month
),

max_months AS (

    SELECT

        cohort_month,

        cohort_customers,

        (
            EXTRACT(
                YEAR FROM DATE '2018-08-29'
            )
            - EXTRACT(
                YEAR FROM cohort_month
            )
        ) * 12

        +

        (
            EXTRACT(
                MONTH FROM DATE '2018-08-29'
            )
            - EXTRACT(
                MONTH FROM cohort_month
            )
        ) AS max_month_number

    FROM cohort_sizes
),

month_grid AS (

    SELECT

        m.cohort_month,

        m.cohort_customers,

        gs.month_number

    FROM max_months m

    CROSS JOIN LATERAL generate_series(
        0,
        m.max_month_number
    ) AS gs(month_number)
),

retention_matrix AS (

    SELECT

        g.cohort_month,

        g.month_number,

        g.cohort_customers,

        COALESCE(
            a.active_customers,
            0
        ) AS active_customers

    FROM month_grid g

    LEFT JOIN cohort_activity a

        ON g.cohort_month = a.cohort_month

       AND g.month_number = a.month_number
)

SELECT

    cohort_month,

    month_number,

    active_customers,

    cohort_customers,

    ROUND(

        active_customers * 100.0
        / NULLIF(
            cohort_customers,
            0
        ),

        2

    ) AS retention_pct

FROM retention_matrix

ORDER BY

    cohort_month,

    month_number;


-- =====================================================
-- 7. CREATE REUSABLE COHORT RETENTION VIEW
-- =====================================================
-- This is the main analytical view that will later be
-- connected to Power BI.
--
-- Grain:
--
--     One row = one cohort + one month number
--
-- Columns:
--
--     cohort_month
--     month_number
--     active_customers
--     cohort_customers
--     retention_pct
-- =====================================================

DROP VIEW IF EXISTS vw_cohort_retention;

CREATE VIEW vw_cohort_retention AS

WITH customer_first_purchase AS (

    SELECT

        customer_unique_id,

        DATE_TRUNC(
            'month',
            MIN(purchase_date)
        ) AS cohort_month

    FROM vw_order_analytics

    WHERE order_status = 'delivered'

      AND customer_unique_id IS NOT NULL

    GROUP BY customer_unique_id
),

customer_activity AS (

    SELECT DISTINCT

        o.customer_unique_id,

        c.cohort_month,

        o.purchase_month

    FROM vw_order_analytics o

    JOIN customer_first_purchase c

        ON o.customer_unique_id
        = c.customer_unique_id

    WHERE o.order_status = 'delivered'

      AND o.customer_unique_id IS NOT NULL
),

cohort_activity AS (

    SELECT

        cohort_month,

        purchase_month,

        (
            EXTRACT(YEAR FROM purchase_month)
            - EXTRACT(YEAR FROM cohort_month)
        ) * 12

        +

        (
            EXTRACT(MONTH FROM purchase_month)
            - EXTRACT(MONTH FROM cohort_month)
        ) AS month_number,

        COUNT(DISTINCT customer_unique_id)
            AS active_customers

    FROM customer_activity

    GROUP BY

        cohort_month,

        purchase_month
),

cohort_sizes AS (

    SELECT

        cohort_month,

        COUNT(*) AS cohort_customers

    FROM customer_first_purchase

    GROUP BY cohort_month
),

max_months AS (

    SELECT

        cohort_month,

        cohort_customers,

        (
            EXTRACT(
                YEAR FROM DATE '2018-08-29'
            )
            - EXTRACT(
                YEAR FROM cohort_month
            )
        ) * 12

        +

        (
            EXTRACT(
                MONTH FROM DATE '2018-08-29'
            )
            - EXTRACT(
                MONTH FROM cohort_month
            )
        ) AS max_month_number

    FROM cohort_sizes
),

month_grid AS (

    SELECT

        m.cohort_month,

        m.cohort_customers,

        gs.month_number

    FROM max_months m

    CROSS JOIN LATERAL generate_series(
        0,
        m.max_month_number
    ) AS gs(month_number)
),

retention_matrix AS (

    SELECT

        g.cohort_month,

        g.month_number,

        g.cohort_customers,

        COALESCE(
            a.active_customers,
            0
        ) AS active_customers

    FROM month_grid g

    LEFT JOIN cohort_activity a

        ON g.cohort_month = a.cohort_month

       AND g.month_number = a.month_number
)

SELECT

    cohort_month,

    month_number,

    active_customers,

    cohort_customers,

    ROUND(

        active_customers * 100.0
        / NULLIF(
            cohort_customers,
            0
        ),

        2

    ) AS retention_pct

FROM retention_matrix;


-- =====================================================
-- 8. VIEW VALIDATION
-- =====================================================
-- Confirm the view returns the expected cohort data.
-- =====================================================

SELECT *

FROM vw_cohort_retention

ORDER BY

    cohort_month,

    month_number;


-- =====================================================
-- 9. MONTH 0 VALIDATION
-- =====================================================
-- Every cohort should have 100% retention in Month 0.
--
-- Verified result:
--
--     cohorts = 23
--     full_retention_month_0 = 23
-- =====================================================

SELECT

    COUNT(*) AS cohorts,

    COUNT(*) FILTER (
        WHERE retention_pct = 100.00
    ) AS full_retention_month_0

FROM vw_cohort_retention

WHERE month_number = 0;


-- =====================================================
-- 10. OVERALL RETENTION BY MONTH
-- =====================================================
-- Descriptive retention curve across all cohorts.
--
-- IMPORTANT:
--
-- The eligible customer population decreases at higher
-- month numbers because newer cohorts have not existed
-- long enough to reach those months.
-- =====================================================

SELECT

    month_number,

    SUM(active_customers)
        AS active_customers,

    SUM(cohort_customers)
        AS eligible_cohort_customers,

    ROUND(

        SUM(active_customers) * 100.0
        / NULLIF(
            SUM(cohort_customers),
            0
        ),

        2

    ) AS retention_pct

FROM vw_cohort_retention

GROUP BY month_number

ORDER BY month_number;


-- =====================================================
-- 11. COHORT MATURITY CHECK
-- =====================================================
-- Shows how many months of observation are available
-- for each cohort.
--
-- Recent cohorts naturally have fewer observable months.
-- =====================================================

SELECT

    cohort_month,

    MAX(month_number)
        AS available_months,

    MAX(cohort_customers)
        AS cohort_customers

FROM vw_cohort_retention

GROUP BY cohort_month

ORDER BY cohort_month DESC;


-- =====================================================
-- 12. RETENTION SUMMARY
-- =====================================================
-- Quick summary of the overall cohort analysis.
-- =====================================================

SELECT

    COUNT(DISTINCT cohort_month)
        AS total_cohorts,

    SUM(
        CASE
            WHEN month_number = 0
            THEN cohort_customers
            ELSE 0
        END
    ) AS total_customers,

    ROUND(
        MAX(
            CASE
                WHEN month_number = 1
                THEN retention_pct
            END
        ),
        2
    ) AS month_1_retention_pct,

    ROUND(
        MAX(
            CASE
                WHEN month_number = 2
                THEN retention_pct
            END
        ),
        2
    ) AS month_2_retention_pct,

    ROUND(
        MAX(
            CASE
                WHEN month_number = 3
                THEN retention_pct
            END
        ),
        2
    ) AS month_3_retention_pct

FROM vw_cohort_retention;


-- =====================================================
-- END OF 06_COHORT_RETENTION.SQL
-- =====================================================