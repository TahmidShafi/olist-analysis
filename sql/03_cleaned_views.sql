DROP VIEW IF EXISTS vw_orders_clean;

CREATE VIEW vw_orders_clean AS

SELECT
    o.order_id,
    o.customer_id,
    c.customer_unique_id,

    o.order_status,

    o.order_purchase_timestamp,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,

    DATE_TRUNC(
        'month',
        o.order_purchase_timestamp
    ) AS purchase_month,

    o.order_purchase_timestamp::date
        AS purchase_date,

    CASE
        WHEN o.order_delivered_customer_date IS NOT NULL
         AND o.order_estimated_delivery_date IS NOT NULL
        THEN
            o.order_delivered_customer_date::date
            - o.order_estimated_delivery_date::date
        ELSE NULL
    END AS delivery_delay_days

FROM orders o

LEFT JOIN customers c
    ON o.customer_id = c.customer_id;

    DROP VIEW IF EXISTS vw_order_payments;

CREATE VIEW vw_order_payments AS

SELECT
    order_id,

    SUM(payment_value) AS total_payment_value,

    COUNT(*) AS payment_row_count,

    MAX(payment_installments) AS max_installments

FROM order_payments

GROUP BY order_id;


DROP VIEW IF EXISTS vw_order_revenue;

CREATE VIEW vw_order_revenue AS

SELECT
    order_id,

    SUM(price) AS product_revenue,

    SUM(freight_value) AS freight_revenue,

    SUM(price + freight_value) AS total_order_value,

    COUNT(*) AS item_count

FROM order_items

GROUP BY order_id;

DROP VIEW IF EXISTS vw_order_reviews;

CREATE VIEW vw_order_reviews AS

SELECT
    order_id,

    AVG(review_score)::NUMERIC(10,2)
        AS average_review_score,

    COUNT(*) AS review_count

FROM order_reviews

GROUP BY order_id;

DROP VIEW IF EXISTS vw_order_analytics;

CREATE VIEW vw_order_analytics AS

SELECT
    o.order_id,
    o.customer_id,
    o.customer_unique_id,

    o.order_status,

    o.order_purchase_timestamp,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,

    o.purchase_month,
    o.purchase_date,
    o.delivery_delay_days,

    r.product_revenue,
    r.freight_revenue,
    r.total_order_value,
    r.item_count,

    p.total_payment_value,
    p.payment_row_count,
    p.max_installments,

    rv.average_review_score,
    rv.review_count

FROM vw_orders_clean o

LEFT JOIN vw_order_revenue r
    ON o.order_id = r.order_id

LEFT JOIN vw_order_payments p
    ON o.order_id = p.order_id

LEFT JOIN vw_order_reviews rv
    ON o.order_id = rv.order_id;