/*
=========================================================
Olist E-Commerce Analysis
04 - Revenue & Growth
=========================================================

Purpose:
    Analyze product sales performance over time and
    identify the product categories contributing the
    most to product sales value.

Business Questions:
    1. How does monthly product sales value change?
    2. How many orders are placed each month?
    3. What is the monthly Average Order Value (AOV)?
    4. How does revenue change month-over-month?
    5. Which product categories generate the most sales?
    6. What percentage of product sales does each category
       contribute?

Revenue Definition:
    Product revenue = SUM(order_items.price)

    Freight is excluded from the primary revenue metric.

Order Inclusion Rule:
    Exclude:
        - canceled
        - unavailable

    All other order statuses remain in the analysis.

Important Data Limitation:
    The beginning of the Olist observation period is sparse.
    September 2016 has only 2 qualifying orders and
    December 2016 has only 1 qualifying order.

    Therefore, early-period MoM growth percentages should
    not be interpreted as normal business growth.

Currency:
    Brazilian Real (R$)

=========================================================
*/


-- =====================================================
-- 1. MONTHLY REVENUE
-- =====================================================
-- Business question:
-- How much product sales value was generated each month?
--
-- Grain:
-- One row = one calendar month.
-- =====================================================

SELECT
    purchase_month AS month,

    ROUND(
        SUM(product_revenue),
        2
    ) AS revenue

FROM vw_order_analytics

WHERE order_status NOT IN ('canceled', 'unavailable')

GROUP BY purchase_month

ORDER BY purchase_month;


-- =====================================================
-- 2. MONTHLY REVENUE + ORDERS
-- =====================================================
-- Adds order volume so revenue growth can be separated
-- into volume effects and order-value effects.
-- =====================================================

SELECT
    purchase_month AS month,

    ROUND(
        SUM(product_revenue),
        2
    ) AS revenue,

    COUNT(DISTINCT order_id) AS orders

FROM vw_order_analytics

WHERE order_status NOT IN ('canceled', 'unavailable')

GROUP BY purchase_month

ORDER BY purchase_month;


-- =====================================================
-- 3. MONTHLY REVENUE + ORDERS + AOV
-- =====================================================
-- AOV = product revenue / number of orders
-- =====================================================

SELECT
    purchase_month AS month,

    ROUND(
        SUM(product_revenue),
        2
    ) AS revenue,

    COUNT(DISTINCT order_id) AS orders,

    ROUND(
        SUM(product_revenue)
        / NULLIF(COUNT(DISTINCT order_id), 0),
        2
    ) AS aov

FROM vw_order_analytics

WHERE order_status NOT IN ('canceled', 'unavailable')

GROUP BY purchase_month

ORDER BY purchase_month;


-- =====================================================
-- 4. BASIC MONTH-OVER-MONTH REVENUE GROWTH
-- =====================================================
-- Uses LAG() to retrieve the previous observed month.
--
-- NOTE:
-- This is intentionally kept as a learning/reference
-- query. Because some calendar months have no qualifying
-- orders, the previous row is not always the previous
-- calendar month.
-- =====================================================

WITH monthly_sales AS (

    SELECT
        purchase_month AS month,

        SUM(product_revenue) AS revenue,

        COUNT(DISTINCT order_id) AS orders

    FROM vw_order_analytics

    WHERE order_status NOT IN ('canceled', 'unavailable')

    GROUP BY purchase_month
),

monthly_with_previous AS (

    SELECT
        month,
        revenue,
        orders,

        LAG(revenue) OVER (
            ORDER BY month
        ) AS previous_month_revenue

    FROM monthly_sales
)

SELECT
    month,

    ROUND(revenue, 2) AS revenue,

    orders,

    ROUND(
        revenue / NULLIF(orders, 0),
        2
    ) AS aov,

    ROUND(
        previous_month_revenue,
        2
    ) AS previous_month_revenue,

    ROUND(
        (
            revenue - previous_month_revenue
        )
        / NULLIF(previous_month_revenue, 0)
        * 100,
        2
    ) AS revenue_growth_pct

FROM monthly_with_previous

ORDER BY month;


-- =====================================================
-- 5. CALENDAR-AWARE MONTHLY SALES
-- =====================================================
-- Creates a complete calendar-month series so missing
-- months are represented explicitly as zero.
--
-- This prevents LAG() from treating:
--
--     October -> December
--
-- as if they were consecutive calendar months.
-- =====================================================

WITH calendar_months AS (

    SELECT
        GENERATE_SERIES(
            DATE '2016-09-01',
            DATE '2018-10-01',
            INTERVAL '1 month'
        )::timestamp AS month
),

monthly_sales AS (

    SELECT
        purchase_month AS month,

        SUM(product_revenue) AS revenue,

        COUNT(DISTINCT order_id) AS orders

    FROM vw_order_analytics

    WHERE order_status NOT IN ('canceled', 'unavailable')

    GROUP BY purchase_month
)

SELECT
    c.month,

    ROUND(
        COALESCE(m.revenue, 0),
        2
    ) AS revenue,

    COALESCE(
        m.orders,
        0
    ) AS orders,

    ROUND(
        COALESCE(m.revenue, 0)
        / NULLIF(COALESCE(m.orders, 0), 0),
        2
    ) AS aov

FROM calendar_months c

LEFT JOIN monthly_sales m
    ON c.month = m.month

ORDER BY c.month;


-- =====================================================
-- 6. COMPARABLE MONTH-OVER-MONTH REVENUE GROWTH
-- =====================================================
-- Uses a complete calendar series.
--
-- The first part of the dataset is extremely sparse:
--
-- September 2016 = 2 orders
-- October 2016   = 293 orders
-- December 2016  = 1 order
--
-- Therefore, growth percentages before February 2017
-- are not treated as comparable business growth.
--
-- Starting February 2017:
--
--     current month revenue
--     vs.
--     immediately preceding calendar month revenue
--
-- =====================================================

WITH calendar_months AS (

    SELECT
        GENERATE_SERIES(
            DATE '2016-09-01',
            DATE '2018-10-01',
            INTERVAL '1 month'
        )::timestamp AS month
),

monthly_sales AS (

    SELECT
        purchase_month AS month,

        SUM(product_revenue) AS revenue,

        COUNT(DISTINCT order_id) AS orders

    FROM vw_order_analytics

    WHERE order_status NOT IN ('canceled', 'unavailable')

    GROUP BY purchase_month
),

complete_monthly_sales AS (

    SELECT
        c.month,

        COALESCE(
            m.revenue,
            0
        ) AS revenue,

        COALESCE(
            m.orders,
            0
        ) AS orders

    FROM calendar_months c

    LEFT JOIN monthly_sales m
        ON c.month = m.month
),

monthly_with_previous AS (

    SELECT
        month,

        revenue,

        orders,

        LAG(revenue) OVER (
            ORDER BY month
        ) AS previous_month_revenue,

        LAG(orders) OVER (
            ORDER BY month
        ) AS previous_month_orders

    FROM complete_monthly_sales
)

SELECT
    month,

    ROUND(
        revenue,
        2
    ) AS revenue,

    orders,

    ROUND(
        revenue / NULLIF(orders, 0),
        2
    ) AS aov,

    ROUND(
        previous_month_revenue,
        2
    ) AS previous_month_revenue,

    previous_month_orders,

    CASE
        WHEN month >= DATE '2017-02-01'
         AND previous_month_revenue > 0
        THEN ROUND(
            (
                revenue - previous_month_revenue
            )
            / previous_month_revenue
            * 100,
            2
        )
        ELSE NULL
    END AS revenue_growth_pct

FROM monthly_with_previous

ORDER BY month;


-- =====================================================
-- 7. REVENUE BY PRODUCT CATEGORY
-- =====================================================
-- Grain:
-- One row = one product category.
--
-- Revenue:
-- SUM(order_items.price)
--
-- Orders:
-- DISTINCT orders containing products from the category.
--
-- Items:
-- Number of product-line records.
-- =====================================================

SELECT

    COALESCE(
        pct.product_category_name_english,
        p.product_category_name,
        'Unknown'
    ) AS category,

    ROUND(
        SUM(oi.price),
        2
    ) AS revenue,

    COUNT(DISTINCT oi.order_id) AS orders,

    COUNT(*) AS items_sold

FROM order_items oi

JOIN products p
    ON oi.product_id = p.product_id

LEFT JOIN product_category_name_translation pct
    ON p.product_category_name =
       pct.product_category_name

JOIN orders o
    ON oi.order_id = o.order_id

WHERE o.order_status NOT IN ('canceled', 'unavailable')

GROUP BY 1

ORDER BY revenue DESC;


-- =====================================================
-- 8. CATEGORY REVENUE SHARE
-- =====================================================
-- Calculates each category's percentage contribution
-- to total product sales value.
-- =====================================================

WITH category_sales AS (

    SELECT

        COALESCE(
            pct.product_category_name_english,
            p.product_category_name,
            'Unknown'
        ) AS category,

        SUM(oi.price) AS revenue

    FROM order_items oi

    JOIN products p
        ON oi.product_id = p.product_id

    LEFT JOIN product_category_name_translation pct
        ON p.product_category_name =
           pct.product_category_name

    JOIN orders o
        ON oi.order_id = o.order_id

    WHERE o.order_status NOT IN ('canceled', 'unavailable')

    GROUP BY 1
)

SELECT

    category,

    ROUND(
        revenue,
        2
    ) AS revenue,

    ROUND(
        revenue
        / NULLIF(
            SUM(revenue) OVER (),
            0
        )
        * 100,
        2
    ) AS revenue_share_pct

FROM category_sales

ORDER BY revenue DESC;


-- =====================================================
-- 9. TOP 10 PRODUCT CATEGORIES
-- =====================================================
-- Ranks categories by product sales value.
-- =====================================================

WITH category_sales AS (

    SELECT

        COALESCE(
            pct.product_category_name_english,
            p.product_category_name,
            'Unknown'
        ) AS category,

        SUM(oi.price) AS revenue

    FROM order_items oi

    JOIN products p
        ON oi.product_id = p.product_id

    LEFT JOIN product_category_name_translation pct
        ON p.product_category_name =
           pct.product_category_name

    JOIN orders o
        ON oi.order_id = o.order_id

    WHERE o.order_status NOT IN ('canceled', 'unavailable')

    GROUP BY 1
),

ranked_categories AS (

    SELECT
        category,

        revenue,

        RANK() OVER (
            ORDER BY revenue DESC
        ) AS revenue_rank

    FROM category_sales
)

SELECT
    revenue_rank,

    category,

    ROUND(
        revenue,
        2
    ) AS revenue

FROM ranked_categories

WHERE revenue_rank <= 10

ORDER BY revenue_rank;


-- =====================================================
-- 10. REVENUE VALIDATION
-- =====================================================
-- Validate that the cleaned analytical view produces
-- the same product revenue as the raw order_items table.
--
-- These two values should match.
-- =====================================================

SELECT
    ROUND(
        SUM(product_revenue),
        2
    ) AS order_view_revenue

FROM vw_order_analytics

WHERE order_status NOT IN ('canceled', 'unavailable');


SELECT
    ROUND(
        SUM(oi.price),
        2
    ) AS raw_item_revenue

FROM order_items oi

JOIN orders o
    ON oi.order_id = o.order_id

WHERE o.order_status NOT IN ('canceled', 'unavailable');


-- =====================================================
-- 11. CATEGORY SHARE VALIDATION
-- =====================================================
-- The category revenue shares should sum to 100%.
-- =====================================================

WITH category_sales AS (

    SELECT

        COALESCE(
            pct.product_category_name_english,
            p.product_category_name,
            'Unknown'
        ) AS category,

        SUM(oi.price) AS revenue

    FROM order_items oi

    JOIN products p
        ON oi.product_id = p.product_id

    LEFT JOIN product_category_name_translation pct
        ON p.product_category_name =
           pct.product_category_name

    JOIN orders o
        ON oi.order_id = o.order_id

    WHERE o.order_status NOT IN ('canceled', 'unavailable')

    GROUP BY 1
),

category_share AS (

    SELECT
        category,

        revenue,

        revenue
        / NULLIF(
            SUM(revenue) OVER (),
            0
        )
        * 100 AS revenue_share_pct

    FROM category_sales
)

SELECT
    ROUND(
        SUM(revenue_share_pct),
        2
    ) AS total_revenue_share_pct

FROM category_share;


-- =====================================================
-- 12. MONTHLY SALES RANGE
-- =====================================================
-- Confirms the observation period used in the analysis.
-- =====================================================

SELECT
    MIN(purchase_month) AS first_month,
    MAX(purchase_month) AS last_month

FROM vw_order_analytics;


-- =====================================================
-- END OF 04_REVENUE_GROWTH.SQL
-- =====================================================