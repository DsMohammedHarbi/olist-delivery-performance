-- =====================================================================
-- Olist Delivery Performance - SQL analysis
-- Author: Mohammed Alharbi
-- Data:   Olist Brazilian E-Commerce Public Dataset (Kaggle)
-- Engine: SQLite (tables loaded from the original CSV files)
--
-- Scope: delivered orders purchased between 2017-01-01 and 2018-08-31
-- "Late" = delivered after the estimated delivery date shown to the customer
-- =====================================================================


-- ---------------------------------------------------------------------
-- Base view: one row per delivered order, with the metrics used below
-- ---------------------------------------------------------------------
DROP VIEW IF EXISTS delivered_orders;
CREATE VIEW delivered_orders AS
SELECT
    o.order_id,
    o.customer_id,
    o.order_purchase_timestamp,
    -- days the order spent with the seller (NULL if timestamps are invalid)
    CASE
        WHEN julianday(o.order_delivered_carrier_date) >= julianday(o.order_approved_at)
        THEN CAST(julianday(o.order_delivered_carrier_date) - julianday(o.order_approved_at) AS INTEGER)
    END AS prep_days,
    -- days the order spent in shipping
    CASE
        WHEN julianday(o.order_delivered_customer_date) >= julianday(o.order_delivered_carrier_date)
        THEN CAST(julianday(o.order_delivered_customer_date) - julianday(o.order_delivered_carrier_date) AS INTEGER)
    END AS shipping_days,
    CASE
        WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1 ELSE 0
    END AS is_late
FROM orders AS o
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp <  '2018-09-01';


-- ---------------------------------------------------------------------
-- Q1. How many orders arrive late?
-- ---------------------------------------------------------------------
SELECT
    COUNT(*)                          AS delivered_orders,
    SUM(is_late)                      AS late_orders,
    ROUND(100.0 * AVG(is_late), 1)    AS late_pct
FROM delivered_orders;


-- ---------------------------------------------------------------------
-- Q2. Does lateness hurt customer ratings?
--     Average the reviews per order first, so orders with several
--     reviews are not counted twice.
-- ---------------------------------------------------------------------
WITH order_rating AS (
    SELECT order_id, AVG(review_score) AS rating
    FROM reviews
    GROUP BY order_id
)
SELECT
    CASE d.is_late WHEN 1 THEN 'Late' ELSE 'On time' END AS delivery_status,
    COUNT(*)                                            AS orders,
    ROUND(AVG(r.rating), 2)                             AS avg_rating
FROM delivered_orders AS d
JOIN order_rating     AS r ON r.order_id = d.order_id
GROUP BY d.is_late;


-- ---------------------------------------------------------------------
-- Q3. Where does the delay happen: with the seller or in shipping?
-- ---------------------------------------------------------------------
SELECT
    CASE is_late WHEN 1 THEN 'Late' ELSE 'On time' END AS delivery_status,
    ROUND(AVG(prep_days), 1)                          AS avg_days_with_seller,
    ROUND(AVG(shipping_days), 1)                      AS avg_days_in_shipping
FROM delivered_orders
GROUP BY is_late;


-- ---------------------------------------------------------------------
-- Q4. Which customer states see the most delays? (1,000+ orders only)
-- ---------------------------------------------------------------------
SELECT
    c.customer_state,
    COUNT(*)                          AS orders,
    SUM(d.is_late)                    AS late_orders,
    ROUND(100.0 * AVG(d.is_late), 1)  AS late_pct
FROM delivered_orders AS d
JOIN customers        AS c ON c.customer_id = d.customer_id
GROUP BY c.customer_state
HAVING COUNT(*) >= 1000
ORDER BY late_pct DESC;


-- ---------------------------------------------------------------------
-- Q5. Are cross-state orders late more often than same-state orders?
--     (orders with a single seller only)
-- ---------------------------------------------------------------------
WITH order_seller AS (
    SELECT order_id, MIN(seller_id) AS seller_id
    FROM order_items
    GROUP BY order_id
    HAVING COUNT(DISTINCT seller_id) = 1
)
SELECT
    CASE WHEN c.customer_state = s.seller_state
         THEN 'Same state' ELSE 'Cross-state' END AS route,
    COUNT(*)                                       AS orders,
    ROUND(100.0 * AVG(d.is_late), 1)               AS late_pct
FROM delivered_orders AS d
JOIN customers        AS c  ON c.customer_id = d.customer_id
JOIN order_seller     AS os ON os.order_id   = d.order_id
JOIN sellers          AS s  ON s.seller_id   = os.seller_id
GROUP BY route;


-- ---------------------------------------------------------------------
-- Q6. How does seller prep time relate to late delivery?
-- ---------------------------------------------------------------------
SELECT
    CASE
        WHEN prep_days <= 1  THEN '1) 0-1 days'
        WHEN prep_days <= 3  THEN '2) 2-3 days'
        WHEN prep_days <= 5  THEN '3) 4-5 days'
        WHEN prep_days <= 10 THEN '4) 6-10 days'
        ELSE                      '5) 11+ days'
    END                               AS prep_bucket,
    COUNT(*)                          AS orders,
    ROUND(100.0 * AVG(is_late), 1)    AS late_pct
FROM delivered_orders
WHERE prep_days IS NOT NULL
GROUP BY prep_bucket
ORDER BY prep_bucket;


-- ---------------------------------------------------------------------
-- Q7. Seller scorecard: worst sellers by late rate (50+ orders)
--     Uses a window function to rank sellers.
-- ---------------------------------------------------------------------
WITH seller_orders AS (
    SELECT DISTINCT oi.seller_id, d.order_id, d.is_late, d.prep_days
    FROM delivered_orders AS d
    JOIN order_items      AS oi ON oi.order_id = d.order_id
),
seller_stats AS (
    SELECT
        seller_id,
        COUNT(*)                          AS orders,
        ROUND(100.0 * AVG(is_late), 1)    AS late_pct,
        ROUND(AVG(prep_days), 1)          AS avg_prep_days
    FROM seller_orders
    GROUP BY seller_id
    HAVING COUNT(*) >= 50
)
SELECT
    RANK() OVER (ORDER BY late_pct DESC) AS late_rank,
    seller_id,
    orders,
    late_pct,
    avg_prep_days
FROM seller_stats
ORDER BY late_rank
LIMIT 10;


-- ---------------------------------------------------------------------
-- Q8. Monthly trend: orders and late rate by purchase month
-- ---------------------------------------------------------------------
SELECT
    strftime('%Y-%m', order_purchase_timestamp) AS purchase_month,
    COUNT(*)                                    AS orders,
    ROUND(100.0 * AVG(is_late), 1)              AS late_pct
FROM delivered_orders
GROUP BY purchase_month
ORDER BY purchase_month;
