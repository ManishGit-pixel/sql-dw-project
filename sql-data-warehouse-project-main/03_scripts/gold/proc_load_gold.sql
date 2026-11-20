/*
Stored Procedure: Truncate and repopulate physical Gold tables.
*/
CREATE OR ALTER PROCEDURE gold.load_gold AS
BEGIN
    SET XACT_ABORT ON;
    SET NOCOUNT ON;

    DECLARE @start_time DATETIME2,
            @end_time DATETIME2,
            @batch_start_time DATETIME2 = SYSUTCDATETIME();

    BEGIN TRY
        -- Fact table first to avoid orphaned facts during a full refresh.
        TRUNCATE TABLE gold.fact_sales;

        SET @start_time = SYSUTCDATETIME();
        TRUNCATE TABLE gold.dim_customers;
        INSERT INTO gold.dim_customers (
            customer_id, customer_number, first_name, last_name, country,
            marital_status, segment, gender, birthdate, create_date,
            effective_from, effective_to, is_current
        )
        SELECT
            ci.cst_id,
            ci.cst_key,
            ci.cst_firstname,
            ci.cst_lastname,
            la.cntry,
            ci.cst_marital_status,
            ci.cst_segment,
            CASE WHEN ci.cst_gndr <> 'n/a' THEN ci.cst_gndr ELSE COALESCE(ca.gen, 'n/a') END,
            ca.bdate,
            ci.cst_create_date,
            ci.effective_from,
            ci.effective_to,
            ci.is_current
        FROM silver.crm_cust_info ci
        LEFT JOIN silver.erp_cust_az12 ca ON ci.cst_key = ca.cid
        LEFT JOIN silver.erp_loc_a101 la ON ci.cst_key = la.cid
        WHERE ci.is_current = 1;
        SET @end_time = SYSUTCDATETIME();
        PRINT 'gold.dim_customers duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR(20)) + ' seconds';

        SET @start_time = SYSUTCDATETIME();
        TRUNCATE TABLE gold.dim_products;
        INSERT INTO gold.dim_products (
            product_id, product_number, product_name, category_id, category,
            subcategory, maintenance, cost, product_line, start_date
        )
        SELECT
            pn.prd_id,
            pn.prd_key,
            pn.prd_nm,
            pn.cat_id,
            pc.cat,
            pc.subcat,
            pc.maintenance,
            pn.prd_cost,
            pn.prd_line,
            pn.prd_start_dt
        FROM silver.crm_prd_info pn
        LEFT JOIN silver.erp_px_cat_g1v2 pc ON pn.cat_id = pc.id
        WHERE pn.prd_end_dt IS NULL;
        SET @end_time = SYSUTCDATETIME();
        PRINT 'gold.dim_products duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR(20)) + ' seconds';

        SET @start_time = SYSUTCDATETIME();
        INSERT INTO gold.fact_sales (
            order_number, product_key, customer_key, order_date,
            shipping_date, due_date, sales_amount, quantity, price
        )
        SELECT
            sd.sls_ord_num,
            pr.product_key,
            cu.customer_key,
            sd.sls_order_dt,
            sd.sls_ship_dt,
            sd.sls_due_dt,
            sd.sls_sales,
            sd.sls_quantity,
            sd.sls_price
        FROM silver.crm_sales_details sd
        LEFT JOIN gold.dim_products pr ON sd.sls_prd_key = pr.product_number
        LEFT JOIN gold.dim_customers cu ON sd.sls_cust_id = cu.customer_id;
        SET @end_time = SYSUTCDATETIME();
        PRINT 'gold.fact_sales duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR(20)) + ' seconds';

        PRINT 'Loading Gold Layer is Completed';
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
