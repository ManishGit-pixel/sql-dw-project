-- Return rate by product. Returns are represented by negative quantity or sales amount.
-- If return data is absent, this query reports a 0% return rate.
SELECT
    p.product_number,
    p.product_name,
    COUNT(*) AS sold_line_count,
    SUM(CASE WHEN f.quantity < 0 OR f.sales_amount < 0 THEN 1 ELSE 0 END) AS returned_line_count,
    CAST(
        100.0 * SUM(CASE WHEN f.quantity < 0 OR f.sales_amount < 0 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0)
        AS DECIMAL(5,2)
    ) AS return_rate_pct
FROM gold.fact_sales f
JOIN gold.dim_products p
  ON p.product_key = f.product_key
GROUP BY p.product_number, p.product_name
ORDER BY return_rate_pct DESC;
