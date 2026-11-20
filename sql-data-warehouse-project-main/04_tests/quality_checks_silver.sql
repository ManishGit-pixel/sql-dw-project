/*
===============================================================================
Quality Checks
===============================================================================
Script Purpose:
    This script performs various quality checks for data consistency, accuracy,
    and standardization across the 'silver' layer. It includes checks for:
    - Null or duplicate primary keys.
    - Unwanted spaces in string fields.
    - Data standardization and consistency.
    - Invalid date ranges and orders.
    - Data consistency between related fields.

Usage Notes:
    - Run these checks after data loading Silver Layer.
    - Investigate and resolve any discrepancies found during the checks.
===============================================================================
*/

-- ====================================================================
-- Checking 'silver.crm_cust_info'
-- ====================================================================
-- Check for NULLs or Duplicates in Primary Key
-- Expectation: No Results
SELECT
    cst_id,
    COUNT(*)
FROM silver.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1 OR cst_id IS NULL;

-- Check for Unwanted Spaces
-- Expectation: No Results
SELECT
    cst_key
FROM silver.crm_cust_info
WHERE cst_key != TRIM(cst_key);

-- Data Standardization & Consistency
SELECT DISTINCT
    cst_marital_status
FROM silver.crm_cust_info;

-- ====================================================================
-- Checking 'silver.crm_prd_info'
-- ====================================================================
-- Check for NULLs or Duplicates in Primary Key
-- Expectation: No Results
SELECT
    prd_id,
    COUNT(*)
FROM silver.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) > 1 OR prd_id IS NULL;

-- Check for Unwanted Spaces
-- Expectation: No Results
SELECT
    prd_nm
FROM silver.crm_prd_info
WHERE prd_nm != TRIM(prd_nm);

-- Check for NULLs or Negative Values in Cost
-- Expectation: No Results
SELECT
    prd_cost
FROM silver.crm_prd_info
WHERE prd_cost < 0 OR prd_cost IS NULL;

-- Data Standardization & Consistency
SELECT DISTINCT
    prd_line
FROM silver.crm_prd_info;

-- Check for Invalid Date Orders (Start Date > End Date)
-- Expectation: No Results
SELECT
    *
FROM silver.crm_prd_info
WHERE prd_end_dt < prd_start_dt;

-- ====================================================================
-- Checking 'silver.crm_sales_details'
-- ====================================================================
-- Check for Invalid Dates
-- Note: this check reads bronze, because silver already stores these columns as real dates
-- Expectation: No Invalid Dates
SELECT
    NULLIF(sls_due_dt, 0) AS sls_due_dt
FROM bronze.crm_sales_details
WHERE sls_due_dt <= 0
    OR LEN(sls_due_dt) != 8
    OR sls_due_dt > 20500101
    OR sls_due_dt < 19000101;

-- Check for Invalid Date Orders (Order Date > Shipping/Due Dates)
-- Expectation: No Results
SELECT
    *
FROM silver.crm_sales_details
WHERE sls_order_dt > sls_ship_dt
   OR sls_order_dt > sls_due_dt;

-- Check Data Consistency: Sales = Quantity * Price
-- Expectation: No Results
SELECT DISTINCT
    sls_sales,
    sls_quantity,
    sls_price
FROM silver.crm_sales_details
WHERE sls_sales != sls_quantity * sls_price
   OR sls_sales IS NULL
   OR sls_quantity IS NULL
   OR sls_price IS NULL
   OR sls_sales <= 0
   OR sls_quantity <= 0
   OR sls_price <= 0
ORDER BY sls_sales, sls_quantity, sls_price;

-- ====================================================================
-- Checking 'silver.erp_cust_az12'
-- ====================================================================
-- Identify Out-of-Range Dates
-- Expectation: Birthdates between 1924-01-01 and Today
SELECT DISTINCT
    bdate
FROM silver.erp_cust_az12
WHERE bdate < '1924-01-01'
   OR bdate > GETDATE();

-- Data Standardization & Consistency
SELECT DISTINCT
    gen
FROM silver.erp_cust_az12;

-- ====================================================================
-- Checking 'silver.erp_loc_a101'
-- ====================================================================
-- Data Standardization & Consistency
SELECT DISTINCT
    cntry
FROM silver.erp_loc_a101
ORDER BY cntry;

-- ====================================================================
-- Checking 'silver.erp_px_cat_g1v2'
-- ====================================================================
-- Check for Unwanted Spaces
-- Expectation: No Results
SELECT
    *
FROM silver.erp_px_cat_g1v2
WHERE cat != TRIM(cat)
   OR subcat != TRIM(subcat)
   OR maintenance != TRIM(maintenance);

-- Data Standardization & Consistency
SELECT DISTINCT
    maintenance
FROM silver.erp_px_cat_g1v2;

-- ============================================================================
-- Required reconciliation and null percentage checks
-- ============================================================================

-- Row count reconciliation for customer source and Silver current records
SELECT
    (SELECT COUNT(DISTINCT cst_id) FROM bronze.crm_cust_info) AS bronze_distinct_customer_rows,
    (SELECT COUNT(*) FROM silver.crm_cust_info WHERE is_current = 1) AS current_silver_customer_rows,
    CASE
        WHEN (SELECT COUNT(DISTINCT cst_id) FROM bronze.crm_cust_info) =
             (SELECT COUNT(*) FROM silver.crm_cust_info WHERE is_current = 1)
        THEN 'PASS' ELSE 'FAIL'
    END AS reconciliation_status;

-- Check duplicate business keys, including duplicate current customer versions
SELECT cst_id, COUNT(*) AS duplicate_count
FROM silver.crm_cust_info
WHERE is_current = 1
GROUP BY cst_id
HAVING COUNT(*) > 1;

-- Null percentage for every column in the customer Silver table
CREATE TABLE #null_percentage (
    table_name NVARCHAR(128),
    column_name NVARCHAR(128),
    null_percentage DECIMAL(5,2)
);

DECLARE @null_sql NVARCHAR(MAX), @column_name NVARCHAR(128);
DECLARE column_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT c.name
    FROM sys.columns c
    WHERE c.object_id = OBJECT_ID('silver.crm_cust_info')
    ORDER BY c.column_id;

OPEN column_cursor;
FETCH NEXT FROM column_cursor INTO @column_name;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @null_sql =
        N'INSERT INTO #null_percentage
          SELECT ''silver.crm_cust_info'', ' +
          QUOTENAME(@column_name, '''') + ',
                 COALESCE(CAST(100.0 * SUM(CASE WHEN ' + QUOTENAME(@column_name) +
          ' IS NULL THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0) AS DECIMAL(5,2)), 0)
          FROM silver.crm_cust_info;';
    EXEC sys.sp_executesql @null_sql;
    FETCH NEXT FROM column_cursor INTO @column_name;
END
CLOSE column_cursor;
DEALLOCATE column_cursor;

SELECT * FROM #null_percentage;
