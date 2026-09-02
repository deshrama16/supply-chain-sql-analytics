/*
===============================================================================
Enterprise Supply Chain & Logistics Intelligence Suite
Database: MySQL 8.0+
Description: End-to-End Analytics solving SLA Breaches, Inventory Stockouts, 
             Logistics Cost Leakage, and Revenue Risk.
===============================================================================
*/
-- 1. Database Creation
CREATE DATABASE IF NOT EXISTS faang_supply_chain;
USE faang_supply_chain;

-- 2. Drop existing tables if re-running
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS inventory;
DROP TABLE IF EXISTS warehouses;

-- 3. Schema Definition (Normalized 3NF)
CREATE TABLE warehouses (
    warehouse_id VARCHAR(10) PRIMARY KEY,
    warehouse_name VARCHAR(50),
    region VARCHAR(20),
    max_capacity_units INT
);

CREATE TABLE inventory (
    product_id VARCHAR(10) PRIMARY KEY,
    product_name VARCHAR(50),
    category VARCHAR(30),
    warehouse_id VARCHAR(10),
    current_stock INT,
    reorder_level INT,
    unit_cost DECIMAL(10,2),
    FOREIGN KEY (warehouse_id) REFERENCES warehouses(warehouse_id)
);

CREATE TABLE orders (
    order_id INT PRIMARY KEY AUTO_INCREMENT,
    product_id VARCHAR(10),
    order_date DATE,
    promised_delivery_date DATE,
    actual_delivery_date DATE,
    quantity_ordered INT,
    fulfillment_status VARCHAR(20),
    shipping_cost DECIMAL(8,2),
    FOREIGN KEY (product_id) REFERENCES inventory(product_id)
);

-- 4. Seed Data Insertion (Lightweight & Instant Load)
INSERT INTO warehouses VALUES 
('WH-US-EAST', 'New York Hub', 'North America', 50000),
('WH-US-WEST', 'Seattle Hub', 'North America', 45000),
('WH-EU-CENT', 'Frankfurt Hub', 'Europe', 60000),
('WH-APAC-IN', 'Mumbai Hub', 'APAC', 40000);

INSERT INTO inventory VALUES 
('PRD-101', 'High-End GPU Unit', 'Electronics', 'WH-US-WEST', 15, 50, 750.00),
('PRD-102', 'Cloud Server Blade', 'Hardware', 'WH-US-EAST', 120, 100, 1200.00),
('PRD-103', 'Enterprise Router', 'Networking', 'WH-EU-CENT', 8, 30, 450.00),
('PRD-104', 'Fiber Optic Cable 100m', 'Networking', 'WH-APAC-IN', 450, 200, 85.00),
('PRD-105', 'Smart Sensor Array', 'IoT', 'WH-US-EAST', 25, 80, 210.00);

INSERT INTO orders (product_id, order_date, promised_delivery_date, actual_delivery_date, quantity_ordered, fulfillment_status, shipping_cost) VALUES 
('PRD-101', '2026-07-01', '2026-07-05', '2026-07-07', 5, 'DELIVERED', 45.00),  -- Delayed
('PRD-101', '2026-07-03', '2026-07-07', '2026-07-06', 10, 'DELIVERED', 50.00), -- On-Time
('PRD-102', '2026-07-10', '2026-07-14', '2026-07-14', 20, 'DELIVERED', 120.00),-- On-Time
('PRD-103', '2026-07-12', '2026-07-15', '2026-07-19', 3, 'DELIVERED', 35.00),  -- Severely Delayed
('PRD-103', '2026-07-15', '2026-07-18', NULL, 4, 'CANCELLED', 0.00),           -- Cancelled
('PRD-104', '2026-07-18', '2026-07-22', '2026-07-21', 100, 'DELIVERED', 210.00),-- On-Time
('PRD-105', '2026-07-20', '2026-07-25', '2026-07-28', 15, 'DELIVERED', 65.00), -- Delayed
('PRD-101', '2026-07-22', '2026-07-26', '2026-07-29', 2, 'DELIVERED', 30.00);  -- Delayed

-- ===============================================================================
-- PROBLEM 1: Supply Chain SLA Breach & Penalty Risk Assessment
-- Business Impact: Identify vendors/hubs breaching the 40% threshold for late 
--                  deliveries to prevent SLA financial penalties.
-- Tech Stack: CTE, Conditional Aggregation, DATEDIFF
-- ===============================================================================

WITH SLA_Analysis AS (
    SELECT 
        i.product_name,
        w.warehouse_name,
        o.order_id,
        CASE WHEN DATEDIFF(o.actual_delivery_date, o.promised_delivery_date) > 0 THEN 1 ELSE 0 END AS is_delayed
    FROM orders o
    JOIN inventory i ON o.product_id = i.product_id
    JOIN warehouses w ON i.warehouse_id = w.warehouse_id
    WHERE o.fulfillment_status = 'DELIVERED'
)
SELECT 
    product_name,
    warehouse_name,
    COUNT(order_id) AS total_orders,
    SUM(is_delayed) AS delayed_orders,
    ROUND((SUM(is_delayed) * 100.0 / COUNT(order_id)), 2) AS sla_breach_pct
FROM SLA_Analysis
GROUP BY product_name, warehouse_name
HAVING sla_breach_pct >= 40.0;

-- ===============================================================================
-- PROBLEM 2: Critical Stockout & Emergency Reorder Priority Engine
-- Business Impact: Detect stock levels falling below buffer levels and prioritize 
--                  procurement action items via Window Functions.
-- Tech Stack: Window Functions (DENSE_RANK), Conditional CASE
-- ===============================================================================

SELECT 
    i.product_id,
    i.product_name,
    w.warehouse_name,
    i.current_stock,
    i.reorder_level,
    (i.reorder_level - i.current_stock) AS stock_deficit,
    DENSE_RANK() OVER (ORDER BY (i.reorder_level - i.current_stock) DESC) AS reorder_priority_rank
FROM inventory i
JOIN warehouses w ON i.warehouse_id = w.warehouse_id
WHERE i.current_stock < i.reorder_level;

-- ===============================================================================
-- PROBLEM 3: Financial Opportunity Loss via Order Cancellations
-- Business Impact: Quantify lost gross revenue driven by fulfillment failures.
-- Tech Stack: Multi-table JOINs, Financial Aggregations
-- ===============================================================================

SELECT 
    w.warehouse_name,
    i.product_name,
    COUNT(o.order_id) AS cancelled_orders,
    SUM(o.quantity_ordered * i.unit_cost) AS total_revenue_lost
FROM orders o
JOIN inventory i ON o.product_id = i.product_id
JOIN warehouses w ON i.warehouse_id = w.warehouse_id
WHERE o.fulfillment_status = 'CANCELLED'
GROUP BY w.warehouse_name, i.product_name;

-- ===============================================================================
-- PROBLEM 4: Logistics Freight Cost Efficiency Ratio Analysis
-- Business Impact: Isolate high freight cost percentages relative to order value 
--                  to optimize carrier contracts.
-- Tech Stack: Ratio Analytics, Derived Metrics
-- ===============================================================================

SELECT 
    o.order_id,
    i.product_name,
    (o.quantity_ordered * i.unit_cost) AS order_gross_value,
    o.shipping_cost,
    ROUND((o.shipping_cost * 100.0 / (o.quantity_ordered * i.unit_cost)), 2) AS freight_cost_pct
FROM orders o
JOIN inventory i ON o.product_id = i.product_id
ORDER BY freight_cost_pct DESC;

-- ===============================================================================
-- PROBLEM 5: Route Delay Outlier & Bottleneck Audit
-- Business Impact: Benchmark average vs worst-case delay days across regions.
-- Tech Stack: Grouped Metrics (AVG, MAX), Date Math
-- ===============================================================================

SELECT 
    w.warehouse_name,
    w.region,
    COUNT(o.order_id) AS total_shipped,
    ROUND(AVG(DATEDIFF(o.actual_delivery_date, o.promised_delivery_date)), 1) AS avg_delay_days,
    MAX(DATEDIFF(o.actual_delivery_date, o.promised_delivery_date)) AS worst_case_delay_days
FROM orders o
JOIN inventory i ON o.product_id = i.product_id
JOIN warehouses w ON i.warehouse_id = w.warehouse_id
WHERE o.fulfillment_status = 'DELIVERED'
GROUP BY w.warehouse_name, w.region;

-- ===============================================================================
-- PROBLEM 6: Product Pareto Principle Analysis (80/20 Revenue Contribution)
-- Business Impact: Segment core revenue-generating inventory items using Window Aggregates.
-- Tech Stack: Analytical Window Functions (SUM OVER)
-- ===============================================================================

WITH ProductRevenue AS (
    SELECT 
        i.product_name,
        SUM(o.quantity_ordered * i.unit_cost) AS total_revenue
    FROM orders o
    JOIN inventory i ON o.product_id = i.product_id
    WHERE o.fulfillment_status = 'DELIVERED'
    GROUP BY i.product_name
)
SELECT 
    product_name,
    total_revenue,
    SUM(total_revenue) OVER (ORDER BY total_revenue DESC) AS cumulative_revenue,
    ROUND((total_revenue * 100.0 / SUM(total_revenue) OVER()), 2) AS revenue_contribution_pct
FROM ProductRevenue;

-- ===============================================================================
-- PROBLEM 7: Warehouse Storage Utilization & Overcrowding Risk
-- Business Impact: Track active stock volume against max physical threshold capacity.
-- Tech Stack: LEFT JOIN, Aggregations
-- ===============================================================================

SELECT 
    w.warehouse_id,
    w.warehouse_name,
    w.max_capacity_units,
    SUM(i.current_stock) AS total_units_stored,
    ROUND((SUM(i.current_stock) * 100.0 / w.max_capacity_units), 2) AS capacity_utilization_pct
FROM warehouses w
LEFT JOIN inventory i ON w.warehouse_id = i.warehouse_id
GROUP BY w.warehouse_id, w.warehouse_name, w.max_capacity_units;

-- ===============================================================================
-- PROBLEM 8: Inventory Velocity & Demand-to-Stock Ratio
-- Business Impact: Pinpoint high-velocity SKUs at risk of fast depletion.
-- Tech Stack: Ratio Analysis, NULL Safeguards
-- ===============================================================================

SELECT 
    i.product_id,
    i.product_name,
    i.current_stock,
    SUM(o.quantity_ordered) AS total_units_demanded,
    ROUND((SUM(o.quantity_ordered) * 1.0 / NULLIF(i.current_stock, 0)), 2) AS velocity_demand_ratio
FROM inventory i
LEFT JOIN orders o ON i.product_id = o.product_id
GROUP BY i.product_id, i.product_name, i.current_stock
ORDER BY velocity_demand_ratio DESC;

-- ===============================================================================
-- PROBLEM 9: Perfect Order Rate (POR) KPI Dashboard
-- Business Impact: Measure global supply chain performance (% of orders on-time & error-free).
-- Tech Stack: Complex Conditional Aggregation
-- ===============================================================================

SELECT 
    w.warehouse_name,
    COUNT(o.order_id) AS total_incoming_orders,
    SUM(CASE WHEN o.fulfillment_status = 'DELIVERED' AND DATEDIFF(o.actual_delivery_date, o.promised_delivery_date) <= 0 THEN 1 ELSE 0 END) AS perfect_orders,
    ROUND((SUM(CASE WHEN o.fulfillment_status = 'DELIVERED' AND DATEDIFF(o.actual_delivery_date, o.promised_delivery_date) <= 0 THEN 1 ELSE 0 END) * 100.0 / COUNT(o.order_id)), 2) AS perfect_order_rate_pct
FROM warehouses w
JOIN inventory i ON w.warehouse_id = i.warehouse_id
JOIN orders o ON i.product_id = o.product_id
GROUP BY w.warehouse_name;

-- ===============================================================================
-- PROBLEM 10: Capital Lock-up & Inventory Rationalization Matrix
-- Business Impact: Flag high-cost products (> $500) with low market velocity for decommission.
-- Tech Stack: Subqueries/CTEs, Filtering Conditions
-- ===============================================================================

WITH ProductPerformance AS (
    SELECT 
        i.product_id,
        i.product_name,
        i.unit_cost,
        COUNT(o.order_id) AS total_orders,
        COALESCE(SUM(o.quantity_ordered), 0) AS total_units_sold
    FROM inventory i
    LEFT JOIN orders o ON i.product_id = o.product_id
    GROUP BY i.product_id, i.product_name, i.unit_cost
)
SELECT 
    product_name,
    unit_cost,
    total_orders,
    total_units_sold
FROM ProductPerformance
WHERE unit_cost > 500.00 AND total_orders <= 2;