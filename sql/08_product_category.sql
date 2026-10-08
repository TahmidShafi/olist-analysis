-- =========================================================
-- Olist E-Commerce Analysis
-- 08 - Product Category Performance
-- =========================================================

/*
Business Purpose:

Create the final product-category dataset for Power BI.

Metrics:
    - Product revenue
    - Distinct orders
    - Items sold

Population:
    Delivered orders only.

Revenue Definition:
    SUM(order_items.price)

Freight:
    Excluded from product revenue.

Category Handling:
    - English category name when available
    - Original category name when translation is unavailable
    - 'Uncategorized' when product category is NULL

This view is designed for the final Power BI
Revenue & Products page.
*/

-- =========================================================
-- 1. PRODUCT CATEGORY PERFORMANCE
-- =========================================================

DROP VIEW IF EXISTS vw_product_category_performance;

CREATE VIEW vw_product_category_performance AS

SELECT

    COALESCE(
        pct.product_category_name_english,
        p.product_category_name,
        'Uncategorized'
    ) AS product_category,

    ROUND(
        SUM(oi.price),
        2
    ) AS product_revenue,

    COUNT(DISTINCT oi.order_id)
        AS orders,

    COUNT(*)
        AS items

FROM order_items oi

JOIN products p
    ON oi.product_id = p.product_id

LEFT JOIN product_category_name_translation pct
    ON p.product_category_name =
       pct.product_category_name

JOIN orders o
    ON oi.order_id = o.order_id

WHERE o.order_status = 'delivered'

GROUP BY

    COALESCE(
        pct.product_category_name_english,
        p.product_category_name,
        'Uncategorized'
    )

ORDER BY
    product_revenue DESC;


-- =========================================================
-- 2. CATEGORY REVENUE RECONCILIATION
-- =========================================================
-- Category revenue should reconcile to the executive
-- delivered-order product revenue.
-- =========================================================

SELECT

    ROUND(
        SUM(product_revenue),
        2
    ) AS categorized_and_uncategorized_revenue

FROM vw_product_category_performance;