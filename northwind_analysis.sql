-- ============================================================
-- NORTHWIND SALES ANALYSIS – SQL PROJECT
-- Dataset: Orders, Products, Employees (830 orders, 89 customers)
-- ============================================================

-- ---------------------------------------------------------------
-- 1. TOTAL REVENUE & VOLUME OVERVIEW
-- ---------------------------------------------------------------
SELECT
    COUNT(DISTINCT o.orderid)                          AS total_orders,
    COUNT(DISTINCT o.customerid)                       AS unique_customers,
    COUNT(DISTINCT o.shipcountry)                      AS markets_served,
    ROUND(SUM(od.unitprice * od.quantity * (1 - od.discount)), 2) AS total_revenue,
    ROUND(AVG(od.unitprice * od.quantity * (1 - od.discount)), 2) AS avg_order_line_value
FROM orders o
JOIN order_details od ON o.orderid = od.orderid;
-- Result: 830 orders | 89 customers | 21 countries | $1,265,793 revenue


-- ---------------------------------------------------------------
-- 2. YEAR-OVER-YEAR REVENUE GROWTH
--    Key Insight: 197% YoY growth from 1996 → 1997
-- ---------------------------------------------------------------
SELECT
    EXTRACT(YEAR FROM o.orderdate)                              AS order_year,
    COUNT(DISTINCT o.orderid)                                   AS total_orders,
    ROUND(SUM(od.unitprice * od.quantity * (1 - od.discount)), 2) AS annual_revenue,
    ROUND(
        100.0 * (SUM(od.unitprice * od.quantity * (1 - od.discount))
            - LAG(SUM(od.unitprice * od.quantity * (1 - od.discount)))
              OVER (ORDER BY EXTRACT(YEAR FROM o.orderdate)))
        / NULLIF(LAG(SUM(od.unitprice * od.quantity * (1 - od.discount)))
              OVER (ORDER BY EXTRACT(YEAR FROM o.orderdate)), 0)
    , 1)                                                        AS yoy_growth_pct
FROM orders o
JOIN order_details od ON o.orderid = od.orderid
GROUP BY EXTRACT(YEAR FROM o.orderdate)
ORDER BY order_year;
-- 1996: $208,084 | 1997: $617,085 (+197%) | 1998: $440,624 (partial year)


-- ---------------------------------------------------------------
-- 3. TOP 5 REVENUE-GENERATING COUNTRIES
--    Key Insight: USA + Germany = 38% of total revenue
-- ---------------------------------------------------------------
SELECT
    o.shipcountry                                              AS country,
    COUNT(DISTINCT o.orderid)                                  AS orders,
    ROUND(SUM(od.unitprice * od.quantity * (1 - od.discount)), 2) AS revenue,
    ROUND(
        100.0 * SUM(od.unitprice * od.quantity * (1 - od.discount))
        / SUM(SUM(od.unitprice * od.quantity * (1 - od.discount))) OVER ()
    , 1)                                                       AS revenue_share_pct
FROM orders o
JOIN order_details od ON o.orderid = od.orderid
GROUP BY o.shipcountry
ORDER BY revenue DESC
LIMIT 5;
-- USA $245,585 | Germany $230,285 | Austria $128,004 | Brazil $106,926 | France $81,358


-- ---------------------------------------------------------------
-- 4. EMPLOYEE SALES PERFORMANCE RANKING
--    Key Insight: Top employee drove 18.4% of total revenue ($232,891)
-- ---------------------------------------------------------------
SELECT
    e.employeeid,
    e.firstname || ' ' || e.lastname                          AS employee_name,
    e.title,
    COUNT(DISTINCT o.orderid)                                  AS orders_closed,
    ROUND(SUM(od.unitprice * od.quantity * (1 - od.discount)), 2) AS total_revenue,
    ROUND(
        100.0 * SUM(od.unitprice * od.quantity * (1 - od.discount))
        / SUM(SUM(od.unitprice * od.quantity * (1 - od.discount))) OVER ()
    , 1)                                                       AS revenue_share_pct,
    RANK() OVER (
        ORDER BY SUM(od.unitprice * od.quantity * (1 - od.discount)) DESC
    )                                                          AS performance_rank
FROM employees e
JOIN orders o     ON e.employeeid = o.employeeid
JOIN order_details od ON o.orderid = od.orderid
GROUP BY e.employeeid, e.firstname, e.lastname, e.title
ORDER BY total_revenue DESC;


-- ---------------------------------------------------------------
-- 5. TOP 10 PRODUCTS BY REVENUE
--    Key Insight: Top 5 products = 30.6% of total revenue
-- ---------------------------------------------------------------
SELECT
    p.productid,
    p.productname,
    SUM(od.quantity)                                           AS units_sold,
    ROUND(SUM(od.unitprice * od.quantity * (1 - od.discount)), 2) AS total_revenue,
    ROUND(
        100.0 * SUM(od.unitprice * od.quantity * (1 - od.discount))
        / SUM(SUM(od.unitprice * od.quantity * (1 - od.discount))) OVER ()
    , 1)                                                       AS revenue_share_pct,
    ROUND(AVG(od.discount) * 100, 1)                          AS avg_discount_pct
FROM products p
JOIN order_details od ON p.productid = od.productid
GROUP BY p.productid, p.productname
ORDER BY total_revenue DESC
LIMIT 10;
-- Côte de Blaye $141,397 | Thüringer Rostbratwurst $80,369 | Raclette Courdavault $71,156


-- ---------------------------------------------------------------
-- 6. SHIPPING EFFICIENCY ANALYSIS
--    Key Insight: Average fulfillment time = 8.5 days
-- ---------------------------------------------------------------
SELECT
    s.companyname                                             AS shipper,
    COUNT(o.orderid)                                          AS shipments,
    ROUND(AVG(o.shippeddate - o.orderdate), 1)               AS avg_days_to_ship,
    MIN(o.shippeddate - o.orderdate)                         AS fastest_days,
    MAX(o.shippeddate - o.orderdate)                         AS slowest_days,
    COUNT(CASE WHEN o.shippeddate > o.requireddate THEN 1 END) AS late_shipments,
    ROUND(
        100.0 * COUNT(CASE WHEN o.shippeddate > o.requireddate THEN 1 END)
        / COUNT(o.orderid)
    , 1)                                                      AS late_rate_pct
FROM orders o
JOIN shippers s ON o.shipvia = s.shipperid
WHERE o.shippeddate IS NOT NULL
GROUP BY s.companyname
ORDER BY avg_days_to_ship;


-- ---------------------------------------------------------------
-- 7. MONTHLY REVENUE TREND (1997 – peak year)
-- ---------------------------------------------------------------
SELECT
    TO_CHAR(o.orderdate, 'YYYY-MM')                          AS month,
    COUNT(DISTINCT o.orderid)                                 AS orders,
    ROUND(SUM(od.unitprice * od.quantity * (1 - od.discount)), 2) AS monthly_revenue,
    ROUND(AVG(od.unitprice * od.quantity * (1 - od.discount)), 2) AS avg_order_revenue
FROM orders o
JOIN order_details od ON o.orderid = od.orderid
WHERE EXTRACT(YEAR FROM o.orderdate) = 1997
GROUP BY TO_CHAR(o.orderdate, 'YYYY-MM')
ORDER BY month;


-- ---------------------------------------------------------------
-- 8. CUSTOMER AVERAGE ORDER VALUE (AOV) RANKING
-- ---------------------------------------------------------------
WITH order_values AS (
    SELECT
        o.customerid,
        o.orderid,
        SUM(od.unitprice * od.quantity * (1 - od.discount)) AS order_value
    FROM orders o
    JOIN order_details od ON o.orderid = od.orderid
    GROUP BY o.customerid, o.orderid
)
SELECT
    customerid,
    COUNT(orderid)                   AS total_orders,
    ROUND(SUM(order_value), 2)       AS lifetime_value,
    ROUND(AVG(order_value), 2)       AS avg_order_value,
    ROUND(MAX(order_value), 2)       AS max_order_value
FROM order_values
GROUP BY customerid
ORDER BY lifetime_value DESC
LIMIT 10;
-- Overall avg order value: $1,525


-- ---------------------------------------------------------------
-- 9. DISCOUNT IMPACT ON REVENUE
-- ---------------------------------------------------------------
SELECT
    CASE
        WHEN od.discount = 0            THEN 'No Discount'
        WHEN od.discount BETWEEN 0.01 AND 0.10 THEN '1–10%'
        WHEN od.discount BETWEEN 0.11 AND 0.20 THEN '11–20%'
        ELSE '20%+'
    END                                                    AS discount_band,
    COUNT(*)                                               AS order_lines,
    ROUND(SUM(od.unitprice * od.quantity), 2)              AS gross_revenue,
    ROUND(SUM(od.unitprice * od.quantity * od.discount), 2) AS discount_given,
    ROUND(SUM(od.unitprice * od.quantity * (1 - od.discount)), 2) AS net_revenue
FROM order_details od
GROUP BY discount_band
ORDER BY net_revenue DESC;


-- ---------------------------------------------------------------
-- 10. SUPPLIER PRODUCT PORTFOLIO & STOCK HEALTH
-- ---------------------------------------------------------------
SELECT
    s.companyname                          AS supplier,
    COUNT(p.productid)                     AS products_supplied,
    SUM(p.unitsinstock)                    AS total_units_in_stock,
    SUM(p.unitsonorder)                    AS total_units_on_order,
    COUNT(CASE WHEN p.discontinued = 1 THEN 1 END) AS discontinued_products,
    ROUND(AVG(p.unitprice), 2)             AS avg_product_price
FROM suppliers s
JOIN products p ON s.supplierid = p.supplierid
GROUP BY s.companyname
ORDER BY products_supplied DESC, avg_product_price DESC;
