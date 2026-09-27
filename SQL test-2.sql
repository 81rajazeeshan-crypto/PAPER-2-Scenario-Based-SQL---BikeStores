
  --- BikeStores Sample Database - Scenario-Based SQL Assignment ---
  --- Database Engine: Microsoft SQL Server (T-SQL) ---


-- TASK 1: Build the Sales Detail Dataset (6 Marks)

SELECT 
    o.order_id,
    o.order_date,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    st.store_name,
    CONCAT(sf.first_name, ' ', sf.last_name) AS staff_name,
    p.product_name,
    cat.category_name,
    b.brand_name,
    oi.quantity,
    oi.list_price,
    oi.discount,
    CAST(oi.quantity * oi.list_price * (1 - oi.discount) AS DECIMAL(12,2)) AS net_line_revenue
FROM sales.orders o
INNER JOIN sales.customers c ON o.customer_id = c.customer_id
INNER JOIN sales.stores st ON o.store_id = st.store_id
INNER JOIN sales.staffs sf ON o.staff_id = sf.staff_id
INNER JOIN sales.order_items oi ON o.order_id = oi.order_id
INNER JOIN production.products p ON oi.product_id = p.product_id
INNER JOIN production.categories cat ON p.category_id = cat.category_id
INNER JOIN production.brands b ON p.brand_id = b.brand_id
WHERE o.order_status = 4 -- Completed orders
ORDER BY o.order_date DESC, o.order_id DESC;



-- TASK 2: Store Performance Summary (5 Marks)

SELECT 
    st.store_name,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(oi.quantity) AS total_units_sold,
    CAST(SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS DECIMAL(12,2)) AS total_net_revenue,
    CAST(
    SUM(oi.quantity * oi.list_price * (1 - oi.discount)) / NULLIF(COUNT(DISTINCT o.order_id), 0) 
     AS DECIMAL(12,2)
    ) AS avg_order_value
FROM sales.stores st
INNER JOIN sales.orders o ON st.store_id = o.store_id
INNER JOIN sales.order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 4
GROUP BY st.store_id, st.store_name
ORDER BY total_net_revenue DESC;

-- TASK 3: High-Value Customers (5 Marks)

WITH CustomerSpending AS (
    SELECT 
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    COUNT(DISTINCT o.order_id) AS completed_order_count,
    SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_spending
    FROM sales.customers c
    INNER JOIN sales.orders o ON c.customer_id = o.customer_id
    INNER JOIN sales.order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 4
    GROUP BY c.customer_id, c.first_name, c.last_name
)
SELECT 
customer_id,
customer_name,
completed_order_count,
CAST(total_spending AS DECIMAL(12,2)) AS total_spending
FROM CustomerSpending
WHERE total_spending > (SELECT AVG(total_spending) FROM CustomerSpending)
ORDER BY total_spending DESC;


-- TASK 4: Inventory Risk Report (5 Marks)

SELECT 
    p.product_name,
    st.store_name,
    s.quantity AS current_quantity,
    cat.category_name,
    b.brand_name
FROM production.stocks s
INNER JOIN production.products p ON s.product_id = p.product_id
INNER JOIN sales.stores st ON s.store_id = st.store_id
INNER JOIN production.categories cat ON p.category_id = cat.category_id
INNER JOIN production.brands b ON p.brand_id = b.brand_id
WHERE s.quantity < 5
ORDER BY s.quantity ASC, p.product_name ASC;

-- TASK 5: Top Products Within Each Category (6 Marks)

WITH RankedProducts AS (
    SELECT 
    cat.category_name,
    p.product_name,
    SUM(oi.quantity) AS total_units_sold,
    SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_net_revenue,
    DENSE_RANK() OVER (
     PARTITION BY cat.category_id 
     ORDER BY SUM(oi.quantity * oi.list_price * (1 - oi.discount)) DESC
     ) AS category_position
    FROM production.categories cat
    INNER JOIN production.products p ON cat.category_id = p.category_id
    INNER JOIN sales.order_items oi ON p.product_id = oi.product_id
    INNER JOIN sales.orders o ON oi.order_id = o.order_id
    WHERE o.order_status = 4
    GROUP BY cat.category_id, cat.category_name, p.product_id, p.product_name
)
SELECT 
    category_name,
    product_name,
    total_units_sold,
    CAST(total_net_revenue AS DECIMAL(12,2)) AS total_net_revenue,
    category_position
FROM RankedProducts
WHERE category_position <= 3
ORDER BY category_name ASC, category_position ASC;

-- TASK 6: Monthly Sales Trend (6 Marks)

WITH MonthlySales AS (
    SELECT 
    YEAR(o.order_date) AS sales_year,
    MONTH(o.order_date) AS sales_month,
    SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_net_revenue
    FROM sales.orders o
    INNER JOIN sales.order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 4
    GROUP BY YEAR(o.order_date), MONTH(o.order_date)
)
SELECT 
    sales_year AS [year],
    sales_month AS [month],
    CAST(total_net_revenue AS DECIMAL(12,2)) AS total_net_revenue,
    CAST(
        LAG(total_net_revenue, 1) OVER (ORDER BY sales_year, sales_month) 
        AS DECIMAL(12,2)
    ) AS prev_month_net_revenue,
    CAST(
        total_net_revenue - LAG(total_net_revenue, 1) OVER (ORDER BY sales_year, sales_month) 
        AS DECIMAL(12,2)
    ) AS revenue_change
FROM MonthlySales
ORDER BY sales_year ASC, sales_month ASC;

-- TASK 7: Reusable Reporting View (4 Marks)

GO
CREATE OR ALTER VIEW sales.vw_customer_sales_summary AS
SELECT 
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    COUNT(DISTINCT o.order_id) AS total_completed_orders,
    ISNULL(SUM(oi.quantity), 0) AS total_units_purchased,
    CAST(ISNULL(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 0) AS DECIMAL(12,2)) AS total_net_revenue,
    MAX(o.order_date) AS most_recent_completed_order_date
FROM sales.customers c
LEFT JOIN sales.orders o 
ON c.customer_id = o.customer_id AND o.order_status = 4
LEFT JOIN sales.order_items oi 
ON o.order_id = oi.order_id
GROUP BY c.customer_id, c.first_name, c.last_name;
GO

-- TASK 8: Safe Data Modification (4 Marks)

 BEGIN TRANSACTION;
-- 1. Update phone number for customer_id = 1
UPDATE sales.customers
SET phone = '(999) 555-0101'
WHERE customer_id = 1;

-- 2. Validation query to check updated data
SELECT customer_id, first_name, last_name, phone
FROM sales.customers
WHERE customer_id = 1;

-- 3. Rollback changes for testing/assessment safety
ROLLBACK TRANSACTION;


 -- Task 9 — Store Sales Procedure (6 marks)

GO
CREATE OR ALTER PROCEDURE sales.usp_store_sales_report
    @store_id INT,
    @start_date DATE,
    @end_date DATE
AS
BEGIN
  SET NOCOUNT ON;

    -- Date Range Validation
    IF @start_date > @end_date
    BEGIN
    RAISERROR('Invalid Date Range: @start_date cannot be later than @end_date.', 16, 1);
    RETURN;
    END

    -- Report Query
    SELECT 
    p.product_name,
    SUM(oi.quantity) AS total_units_sold,
    CAST(SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS DECIMAL(12,2)) AS total_net_revenue
    FROM sales.orders o
    INNER JOIN sales.order_items oi ON o.order_id = oi.order_id
    INNER JOIN production.products p ON oi.product_id = p.product_id
    WHERE o.store_id = @store_id
      AND o.order_status = 4
      AND o.order_date BETWEEN @start_date AND @end_date
    GROUP BY p.product_id, p.product_name
    ORDER BY total_net_revenue DESC;
END;
GO

-- TASK 10: Management Insight Query (3 Marks)

 SELECT
    st.store_name,
    CONCAT(sf.first_name, ' ', sf.last_name) AS staff_name,
    COUNT(DISTINCT o.order_id) AS orders_handled,
    CAST(SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS DECIMAL(12,2)) AS total_staff_revenue
FROM sales.staffs sf
INNER JOIN sales.stores st ON sf.store_id = st.store_id
INNER JOIN sales.orders o ON sf.staff_id = o.staff_id
INNER JOIN sales.order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 4
GROUP BY st.store_name, sf.staff_id, sf.first_name, sf.last_name
ORDER BY st.store_name ASC, total_staff_revenue DESC;


-- Business Insight Explanation:
-- 1. Question: Which staff members are driving the highest completed revenue across each store location?
-- 2. Measurement: Total net sales revenue generated and distinct orders processed per sales employee.
-- 3. Impact: Helps management identify top performers for incentives and address skill gaps across stores.
