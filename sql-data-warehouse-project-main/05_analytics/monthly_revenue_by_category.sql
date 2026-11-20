-- Monthly sales revenue grouped by product category.
SELECT
    DATETRUNC(MONTH, f.order_date) AS month_start,
    p.category,
    SUM(f.sales_amount) AS revenue,
    SUM(f.quantity) AS quantity_sold
FROM gold.fact_sales f
JOIN gold.dim_products p
  ON p.product_key = f.product_key
WHERE f.order_date IS NOT NULL
GROUP BY DATETRUNC(MONTH, f.order_date), p.category
ORDER BY month_start, p.category;
