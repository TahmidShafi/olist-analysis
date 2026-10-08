# Cleaning and Validation Log

Every data issue found, what I decided, and why. Counts are from queries run against `olist_analysis`.

| # | Issue | Finding | Decision | Impact |
|---|---|---|---|---|
| 1 | Customer identity | `customer_id` is generated per order; `customer_unique_id` identifies the person | Use `customer_unique_id` for RFM, retention, repeat purchase | 93,358 delivered customers; 2,801 repeat |
| 2 | Order statuses | delivered 96,478 (97.02%); shipped 1,107; canceled 625; unavailable 609; invoiced 314; processing 301; created 5; approved 2 | Final KPIs use `delivered` only. The 2,963 non-delivered orders are excluded | Dashboard numbers describe completed sales only |
| 3 | Multiple payments per order | 103,886 payment rows vs 99,441 orders | Aggregate to one row per order (`vw_order_payments`) before joining | Prevents inflated revenue from one-to-many joins |
| 4 | Multiple items per order | 112,650 item rows vs 99,441 orders | Aggregate to one row per order (`vw_order_revenue`) | Order-level metrics stay at order grain |
| 5 | Multiple reviews per order | 547 orders have more than one review; 99,224 review rows | Average review score per order (`vw_order_reviews`) | Scores can be fractional; "average review score" is an average of order-level averages |
| 6 | Missing delivery dates | 96,478 delivered orders, 96,470 with a calculable delay (8 missing) | Exclude the 8 from late-rate denominators only | Late rate = 6,534 / 96,470 = 6.77% |
| 7 | Products with no category | 32,951 products, 32,341 with a category (610 without). Their delivered revenue is R$170,726.63 (1.29%) | Label as "Uncategorized" instead of dropping | Category revenue + Uncategorized = R$13,221,498.11 |
| 8 | Untranslated categories | 73 category names, 71 English translations | Fall back to the Portuguese name | No revenue lost; two names appear untranslated |
| 9 | Sparse early period | Very few orders in late 2016 (`04` notes Sep 2016 = 2, Dec 2016 = 1 on its population) | Do not read early growth rates or cohorts as business trends | 2016 cohorts de-emphasized in retention views |
| 10 | Two revenue populations | `04` excludes only canceled/unavailable; `08`/`09` use delivered only | Keep `04` as exploratory; dashboard uses `09` | Totals differ by design; documented in README |
| 11 | RFM frequency | 97% of customers have exactly one delivered order | Do not score frequency; segment on recency and monetary only | Frequency is descriptive (repeat vs one-time) |
| 12 | Tied RFM values | Many customers share identical recency or spend | `NTILE` splits ties across tiers | Segment cutoffs are approximate |
| 13 | Retention averaging | Simple average of cohort percentages (Month 1 about 4.96%) vs weighted (0.48%) | Use weighted retention for the headline | Avoids over-weighting tiny cohorts |
| 14 | Order-category grain | An order with two categories appears in both | Distinct order/category pairs; counts are not additive across categories | Category order totals exceed total orders |
| 15 | Small groups | State/category rates are unstable below small n | Require 100+ delivered orders (`HAVING COUNT(*) >= 100`) | 24 states, 51 categories reported |
| 16 | Snapshot date | Latest delivered purchase is 2018-08-29 | Used as the RFM and retention reference date | Final month is partial |
| 17 | Definition of "late" | Delay computed from dates, not timestamps | Late = delivery date after estimated date | Same-day deliveries count as on time |
| 18 | `ROUND` type error | `function round(double precision, integer) does not exist` | Cast to `NUMERIC` before rounding | Fixed |
| 19 | Import failure | pgAdmin could not find DLLs for `psql` | Set the PostgreSQL 18 binary path | Import succeeded |

## Reconciliation checks that passed

- Executive vs monthly: orders (96,478), product revenue (R$13,221,498.11), total order value (R$15,419,773.75).
- Executive vs RFM: customers (93,358) and repeat customers (2,801).
- RFM segment customers sum to 93,358; segment revenue sums to R$13,221,498.11.
- Category revenue plus Uncategorized equals the executive product revenue.
