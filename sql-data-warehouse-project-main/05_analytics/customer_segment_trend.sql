-- Monthly customer segment trend based on current Silver customer segments.
SELECT
    DATETRUNC(MONTH, f.order_date) AS month_start,
    c.segment,
    COUNT(DISTINCT c.customer_id) AS active_customer_count,
    SUM(f.sales_amount) AS revenue
FROM gold.fact_sales f
JOIN gold.dim_customers c
  ON c.customer_key = f.customer_key
WHERE f.order_date IS NOT NULL
GROUP BY DATETRUNC(MONTH, f.order_date), c.segment
ORDER BY month_start, c.segment;
