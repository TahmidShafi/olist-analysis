# Data Dictionary

All analytical objects are PostgreSQL views in the `olist_analysis` database. Currency is Brazilian Real (R$).

## Metric definitions

| Metric | Definition |
|---|---|
| Product revenue | `SUM(order_items.price)`, delivered orders, excluding freight |
| Freight | `SUM(order_items.freight_value)` |
| Total order value | Product revenue + freight |
| AOV | Average of order-level total order value (includes freight) |
| Late delivery rate | Late orders / orders with a calculable delay (delay > 0 days) |
| Delivery delay (days) | Delivered date minus estimated date (calendar dates); positive = late |
| Repeat customer | `customer_unique_id` with 2+ delivered orders |
| Recency (days) | Snapshot date (2018-08-29) minus last delivered purchase date |
| Monetary | Sum of product revenue per customer |
| Retention % | Active customers / cohort customers x 100 |
| Weighted retention | Sum of active customers / sum of eligible cohort customers |

## Base views (`03_cleaned_views.sql`)

| View | Grain | Key columns |
|---|---|---|
| `vw_orders_clean` | 1 row per order | `order_id`, `customer_unique_id`, `order_status`, `purchase_month`, `purchase_date`, `delivery_delay_days` |
| `vw_order_payments` | 1 row per order | `total_payment_value`, `payment_row_count`, `max_installments` |
| `vw_order_revenue` | 1 row per order | `product_revenue`, `freight_revenue`, `total_order_value`, `item_count` |
| `vw_order_reviews` | 1 row per order | `average_review_score`, `review_count` |
| `vw_order_analytics` | 1 row per order | Joins all of the above; base for every later view |

## Analysis views

| View | Grain | Key columns |
|---|---|---|
| `vw_executive_kpis` | 1 row | `delivered_orders`, `delivered_customers`, `product_revenue`, `total_order_value`, `average_order_value`, `repeat_customers`, `repeat_purchase_rate_pct`, `late_delivery_rate_pct`, `average_review_score` |
| `vw_monthly_business_performance` | 1 row per purchase month (delivered orders) | `orders`, `customers`, `product_revenue`, `total_order_value`, `average_order_value`, `late_orders`, `orders_with_delivery_data`, `late_delivery_rate_pct` |
| `vw_customer_rfm` | 1 row per `customer_unique_id` | `frequency`, `monetary_value`, `total_order_value`, `last_purchase_date`, `recency_days`, `customer_type` |
| `vw_cohort_retention` / `vw_cohort_retention_powerbi` | 1 row per cohort and month number | `cohort_month`, `month_number`, `active_customers`, `cohort_customers`, `retention_pct` |
| `vw_delivery_satisfaction` | 2 rows (late, on time/early) | `orders`, `average_review_score`, `average_delay_days`, `median_delay_days` |
| `vw_delivery_delay_buckets` | 5 rows | `delay_bucket`, `orders`, `average_review_score`, `average_delay_days` |
| `vw_delivery_state` | 1 row per state (100+ orders) | `delivered_orders`, `late_orders`, `late_delivery_rate_pct`, review scores overall/late/on time |
| `vw_delivery_category` | 1 row per category (100+ order-category rows) | `category_orders`, `late_orders`, `late_delivery_rate_pct`, review scores. Order-category grain: not additive |
| `vw_product_category_performance` | 1 row per category, incl. "Uncategorized" | `product_revenue`, `orders`, `items` |

## Notes

- `vw_customer_rfm` has no RFM segment column. The five segments are defined in `sql/05_rfm_segmentation.sql`.
- `vw_executive_kpis` and `vw_monthly_business_performance` share the delivered-order population and reconcile exactly.
- Ratio columns (AOV, late rate, average review) in the monthly view are month-level values. Recompute overall ratios from counts and sums (e.g. `SUM(late_orders) / SUM(orders_with_delivery_data)`), not by averaging months.
