-- ============================================================
-- Olist Brazilian E-Commerce Analytics
-- 00_create_tables.sql
-- ============================================================
-- Purpose:
--   Create the raw Olist PostgreSQL tables before CSV loading.
--
-- Database:
--   olist_analysis
--
-- Load order after running this script:
--   01_load_checks.sql
--
-- Notes:
--   - Raw CSV data should be loaded into these tables afterward.
--   - This script drops existing tables so it is intended for a
--     fresh/reproducible database setup.
--   - Foreign keys are added only where the source relationships
--     are well-defined.
-- ============================================================


-- ============================================================
-- 1. DROP EXISTING TABLES
-- ============================================================

DROP TABLE IF EXISTS order_reviews CASCADE;
DROP TABLE IF EXISTS order_payments CASCADE;
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS product_category_name_translation CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS sellers CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS geolocation CASCADE;


-- ============================================================
-- 2. CUSTOMERS
-- ============================================================

CREATE TABLE customers (
    customer_id              TEXT PRIMARY KEY,
    customer_unique_id       TEXT NOT NULL,
    customer_zip_code_prefix INTEGER,
    customer_city            TEXT,
    customer_state           TEXT
);


-- ============================================================
-- 3. SELLERS
-- ============================================================

CREATE TABLE sellers (
    seller_id              TEXT PRIMARY KEY,
    seller_zip_code_prefix INTEGER,
    seller_city            TEXT,
    seller_state           TEXT
);


-- ============================================================
-- 4. PRODUCTS
-- ============================================================

CREATE TABLE products (
    product_id                  TEXT PRIMARY KEY,
    product_category_name      TEXT,
    product_name_lenght        INTEGER,
    product_description_lenght INTEGER,
    product_photos_qty         INTEGER,
    product_weight_g            NUMERIC,
    product_length_cm           NUMERIC,
    product_height_cm           NUMERIC,
    product_width_cm            NUMERIC
);


-- ============================================================
-- 5. PRODUCT CATEGORY TRANSLATION
-- ============================================================

CREATE TABLE product_category_name_translation (
    product_category_name         TEXT PRIMARY KEY,
    product_category_name_english  TEXT
);


-- ============================================================
-- 6. ORDERS
-- ============================================================

CREATE TABLE orders (
    order_id                        TEXT PRIMARY KEY,
    customer_id                     TEXT NOT NULL,
    order_status                    TEXT,
    order_purchase_timestamp        TIMESTAMP,
    order_approved_at               TIMESTAMP,
    order_delivered_carrier_date    TIMESTAMP,
    order_delivered_customer_date   TIMESTAMP,
    order_estimated_delivery_date   TIMESTAMP,

    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id)
        REFERENCES customers(customer_id)
);


-- ============================================================
-- 7. ORDER ITEMS
-- ============================================================

CREATE TABLE order_items (
    order_id             TEXT NOT NULL,
    order_item_id        INTEGER NOT NULL,
    product_id           TEXT NOT NULL,
    seller_id            TEXT NOT NULL,
    shipping_limit_date  TIMESTAMP,
    price                NUMERIC(12, 2),
    freight_value        NUMERIC(12, 2),

    PRIMARY KEY (order_id, order_item_id),

    CONSTRAINT fk_order_items_order
        FOREIGN KEY (order_id)
        REFERENCES orders(order_id),

    CONSTRAINT fk_order_items_product
        FOREIGN KEY (product_id)
        REFERENCES products(product_id),

    CONSTRAINT fk_order_items_seller
        FOREIGN KEY (seller_id)
        REFERENCES sellers(seller_id)
);


-- ============================================================
-- 8. ORDER PAYMENTS
-- ============================================================

CREATE TABLE order_payments (
    order_id             TEXT NOT NULL,
    payment_sequential   INTEGER NOT NULL,
    payment_type         TEXT,
    payment_installments INTEGER,
    payment_value        NUMERIC(12, 2),

    PRIMARY KEY (order_id, payment_sequential),

    CONSTRAINT fk_order_payments_order
        FOREIGN KEY (order_id)
        REFERENCES orders(order_id)
);


-- ============================================================
-- 9. ORDER REVIEWS
-- ============================================================
-- No primary key is imposed on review_id because the raw Olist
-- review data can contain multiple review rows associated with
-- an order and the analysis intentionally aggregates reviews
-- to order level in vw_order_reviews.
--
-- order_id is indexed for joins and aggregation.
-- ============================================================

CREATE TABLE order_reviews (
    review_id              TEXT,
    order_id               TEXT NOT NULL,
    review_score            INTEGER,
    review_comment_title   TEXT,
    review_comment_message TEXT,
    review_creation_date   TIMESTAMP,
    review_answer_timestamp TIMESTAMP,

    CONSTRAINT fk_order_reviews_order
        FOREIGN KEY (order_id)
        REFERENCES orders(order_id),

    CONSTRAINT chk_review_score
        CHECK (
            review_score IS NULL
            OR review_score BETWEEN 1 AND 5
        )
);


-- ============================================================
-- 10. GEOLOCATION
-- ============================================================
-- Multiple rows can exist for the same ZIP-code prefix, so no
-- primary key is imposed.
-- ============================================================

CREATE TABLE geolocation (
    geolocation_zip_code_prefix INTEGER,
    geolocation_lat              DOUBLE PRECISION,
    geolocation_lng              DOUBLE PRECISION,
    geolocation_city             TEXT,
    geolocation_state            TEXT
);


-- ============================================================
-- 11. INDEXES
-- ============================================================
-- Foreign-key and commonly joined columns are indexed to make
-- later analytical queries more efficient.
-- ============================================================

CREATE INDEX idx_customers_unique_id
    ON customers(customer_unique_id);

CREATE INDEX idx_orders_customer_id
    ON orders(customer_id);

CREATE INDEX idx_orders_purchase_timestamp
    ON orders(order_purchase_timestamp);

CREATE INDEX idx_orders_status
    ON orders(order_status);

CREATE INDEX idx_order_items_product_id
    ON order_items(product_id);

CREATE INDEX idx_order_items_seller_id
    ON order_items(seller_id);

CREATE INDEX idx_order_payments_order_id
    ON order_payments(order_id);

CREATE INDEX idx_order_reviews_order_id
    ON order_reviews(order_id);

CREATE INDEX idx_products_category_name
    ON products(product_category_name);

CREATE INDEX idx_geolocation_zip
    ON geolocation(geolocation_zip_code_prefix);


-- ============================================================
-- 12. VERIFICATION
-- ============================================================
-- These should return the expected table names after execution.
-- ============================================================

SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN (
      'customers',
      'orders',
      'order_items',
      'order_payments',
      'order_reviews',
      'products',
      'sellers',
      'product_category_name_translation',
      'geolocation'
  )
ORDER BY table_name;