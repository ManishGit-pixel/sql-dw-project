-- Highest-spending customers based on total sales amount.
SELECT TOP (10)
    c.customer_id,
    c.first_name,
    c.last_name,
    SUM(f.sales_amount) AS total_spend,
    COUNT(*) AS order_line_count
FROM gold.fact_sales f
JOIN gold.dim_customers c
  ON c.customer_key = f.customer_key
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY total_spend DESC;
