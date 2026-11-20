/*
Stored Procedure: Load Bronze Layer (Source -> Bronze)
Uses temporary tables because BULK INSERT cannot apply a WHERE clause.
*/
CREATE OR ALTER PROCEDURE bronze.load_bronze AS
BEGIN
    SET XACT_ABORT ON;
    SET NOCOUNT ON;

    DECLARE @batch_load_date DATETIME2 = SYSUTCDATETIME(),
            @start_time DATETIME2,
            @end_time DATETIME2,
            @batch_start_time DATETIME2 = SYSUTCDATETIME();

    BEGIN TRY
        IF OBJECT_ID('bronze.bronze_load_metadata', 'U') IS NULL
            THROW 50001, 'bronze.bronze_load_metadata is missing. Run ddl_bronze.sql first.', 1;

        PRINT '================================================';
        PRINT 'Loading Bronze Layer';
        PRINT '================================================';

        -- CRM customer: bulk into a temp table, stamp the batch, then join metadata.
        SET @start_time = SYSUTCDATETIME();
        CREATE TABLE #crm_cust_info (
            cst_id INT, cst_key NVARCHAR(50), cst_firstname NVARCHAR(50),
            cst_lastname NVARCHAR(50), cst_marital_status NVARCHAR(50),
            cst_gndr NVARCHAR(50), cst_create_date DATE, load_date DATETIME2
        );
        BULK INSERT #crm_cust_info
        FROM 'C:\sql\dwh_project\01_datasets\source_crm\cust_info.csv'
        WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', TABLOCK);
        UPDATE #crm_cust_info SET load_date = @batch_load_date;
        TRUNCATE TABLE bronze.crm_cust_info;
        INSERT INTO bronze.crm_cust_info
        SELECT t.cst_id, t.cst_key, t.cst_firstname, t.cst_lastname,
               t.cst_marital_status, t.cst_gndr, t.cst_create_date
        FROM #crm_cust_info t
        LEFT JOIN bronze.bronze_load_metadata m
            ON m.table_name = 'bronze.crm_cust_info'
        WHERE t.load_date > COALESCE(m.last_load_date, '1900-01-01');
        MERGE bronze.bronze_load_metadata AS m
        USING (SELECT 'bronze.crm_cust_info' table_name,
                      @batch_load_date last_load_date,
                      COUNT(*) row_count
               FROM bronze.crm_cust_info) s
        ON m.table_name = s.table_name
        WHEN MATCHED THEN UPDATE SET m.last_load_date = s.last_load_date, m.row_count = s.row_count
        WHEN NOT MATCHED THEN INSERT (table_name, last_load_date, row_count)
                              VALUES (s.table_name, s.last_load_date, s.row_count);
        DROP TABLE #crm_cust_info;
        SET @end_time = SYSUTCDATETIME();
        PRINT '>> bronze.crm_cust_info duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR(20)) + ' seconds';

        -- CRM product
        SET @start_time = SYSUTCDATETIME();
        CREATE TABLE #crm_prd_info (
            prd_id INT, prd_key NVARCHAR(50), prd_nm NVARCHAR(50),
            prd_cost INT, prd_line NVARCHAR(50), prd_start_dt DATETIME,
            prd_end_dt DATETIME, load_date DATETIME2
        );
        BULK INSERT #crm_prd_info
        FROM 'C:\sql\dwh_project\01_datasets\source_crm\prd_info.csv'
        WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', TABLOCK);
        UPDATE #crm_prd_info SET load_date = @batch_load_date;
        TRUNCATE TABLE bronze.crm_prd_info;
        INSERT INTO bronze.crm_prd_info
        SELECT t.prd_id, t.prd_key, t.prd_nm, t.prd_cost, t.prd_line,
               t.prd_start_dt, t.prd_end_dt
        FROM #crm_prd_info t
        LEFT JOIN bronze.bronze_load_metadata m ON m.table_name = 'bronze.crm_prd_info'
        WHERE t.load_date > COALESCE(m.last_load_date, '1900-01-01');
        MERGE bronze.bronze_load_metadata AS m
        USING (SELECT 'bronze.crm_prd_info' table_name, @batch_load_date last_load_date, COUNT(*) row_count
               FROM bronze.crm_prd_info) s
        ON m.table_name = s.table_name
        WHEN MATCHED THEN UPDATE SET m.last_load_date = s.last_load_date, m.row_count = s.row_count
        WHEN NOT MATCHED THEN INSERT (table_name, last_load_date, row_count)
                              VALUES (s.table_name, s.last_load_date, s.row_count);
        DROP TABLE #crm_prd_info;
        SET @end_time = SYSUTCDATETIME();
        PRINT '>> bronze.crm_prd_info duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR(20)) + ' seconds';

        -- CRM sales
        SET @start_time = SYSUTCDATETIME();
        CREATE TABLE #crm_sales_details (
            sls_ord_num NVARCHAR(50), sls_prd_key NVARCHAR(50), sls_cust_id INT,
            sls_order_dt INT, sls_ship_dt INT, sls_due_dt INT,
            sls_sales INT, sls_quantity INT, sls_price INT, load_date DATETIME2
        );
        BULK INSERT #crm_sales_details
        FROM 'C:\sql\dwh_project\01_datasets\source_crm\sales_details.csv'
        WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', TABLOCK);
        UPDATE #crm_sales_details SET load_date = @batch_load_date;
        TRUNCATE TABLE bronze.crm_sales_details;
        INSERT INTO bronze.crm_sales_details
        SELECT t.sls_ord_num, t.sls_prd_key, t.sls_cust_id, t.sls_order_dt,
               t.sls_ship_dt, t.sls_due_dt, t.sls_sales, t.sls_quantity, t.sls_price
        FROM #crm_sales_details t
        LEFT JOIN bronze.bronze_load_metadata m ON m.table_name = 'bronze.crm_sales_details'
        WHERE t.load_date > COALESCE(m.last_load_date, '1900-01-01');
        MERGE bronze.bronze_load_metadata AS m
        USING (SELECT 'bronze.crm_sales_details' table_name, @batch_load_date last_load_date, COUNT(*) row_count
               FROM bronze.crm_sales_details) s
        ON m.table_name = s.table_name
        WHEN MATCHED THEN UPDATE SET m.last_load_date = s.last_load_date, m.row_count = s.row_count
        WHEN NOT MATCHED THEN INSERT (table_name, last_load_date, row_count)
                              VALUES (s.table_name, s.last_load_date, s.row_count);
        DROP TABLE #crm_sales_details;
        SET @end_time = SYSUTCDATETIME();
        PRINT '>> bronze.crm_sales_details duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR(20)) + ' seconds';

        -- ERP location
        SET @start_time = SYSUTCDATETIME();
        CREATE TABLE #erp_loc_a101 (cid NVARCHAR(50), cntry NVARCHAR(50), load_date DATETIME2);
        BULK INSERT #erp_loc_a101
        FROM 'C:\sql\dwh_project\01_datasets\source_erp\LOC_A101.csv'
        WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', TABLOCK);
        UPDATE #erp_loc_a101 SET load_date = @batch_load_date;
        TRUNCATE TABLE bronze.erp_loc_a101;
        INSERT INTO bronze.erp_loc_a101
        SELECT t.cid, t.cntry
        FROM #erp_loc_a101 t
        LEFT JOIN bronze.bronze_load_metadata m ON m.table_name = 'bronze.erp_loc_a101'
        WHERE t.load_date > COALESCE(m.last_load_date, '1900-01-01');
        MERGE bronze.bronze_load_metadata AS m
        USING (SELECT 'bronze.erp_loc_a101' table_name, @batch_load_date last_load_date, COUNT(*) row_count
               FROM bronze.erp_loc_a101) s
        ON m.table_name = s.table_name
        WHEN MATCHED THEN UPDATE SET m.last_load_date = s.last_load_date, m.row_count = s.row_count
        WHEN NOT MATCHED THEN INSERT (table_name, last_load_date, row_count)
                              VALUES (s.table_name, s.last_load_date, s.row_count);
        DROP TABLE #erp_loc_a101;
        SET @end_time = SYSUTCDATETIME();
        PRINT '>> bronze.erp_loc_a101 duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR(20)) + ' seconds';

        -- ERP customer
        SET @start_time = SYSUTCDATETIME();
        CREATE TABLE #erp_cust_az12 (cid NVARCHAR(50), bdate DATE, gen NVARCHAR(50), load_date DATETIME2);
        BULK INSERT #erp_cust_az12
        FROM 'C:\sql\dwh_project\01_datasets\source_erp\CUST_AZ12.csv'
        WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', TABLOCK);
        UPDATE #erp_cust_az12 SET load_date = @batch_load_date;
        TRUNCATE TABLE bronze.erp_cust_az12;
        INSERT INTO bronze.erp_cust_az12
        SELECT t.cid, t.bdate, t.gen
        FROM #erp_cust_az12 t
        LEFT JOIN bronze.bronze_load_metadata m ON m.table_name = 'bronze.erp_cust_az12'
        WHERE t.load_date > COALESCE(m.last_load_date, '1900-01-01');
        MERGE bronze.bronze_load_metadata AS m
        USING (SELECT 'bronze.erp_cust_az12' table_name, @batch_load_date last_load_date, COUNT(*) row_count
               FROM bronze.erp_cust_az12) s
        ON m.table_name = s.table_name
        WHEN MATCHED THEN UPDATE SET m.last_load_date = s.last_load_date, m.row_count = s.row_count
        WHEN NOT MATCHED THEN INSERT (table_name, last_load_date, row_count)
                              VALUES (s.table_name, s.last_load_date, s.row_count);
        DROP TABLE #erp_cust_az12;
        SET @end_time = SYSUTCDATETIME();
        PRINT '>> bronze.erp_cust_az12 duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR(20)) + ' seconds';

        -- ERP category
        SET @start_time = SYSUTCDATETIME();
        CREATE TABLE #erp_px_cat_g1v2 (
            id NVARCHAR(50), cat NVARCHAR(50), subcat NVARCHAR(50),
            maintenance NVARCHAR(50), load_date DATETIME2
        );
        BULK INSERT #erp_px_cat_g1v2
        FROM 'C:\sql\dwh_project\01_datasets\source_erp\PX_CAT_G1V2.csv'
        WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', TABLOCK);
        UPDATE #erp_px_cat_g1v2 SET load_date = @batch_load_date;
        TRUNCATE TABLE bronze.erp_px_cat_g1v2;
        INSERT INTO bronze.erp_px_cat_g1v2
        SELECT t.id, t.cat, t.subcat, t.maintenance
        FROM #erp_px_cat_g1v2 t
        LEFT JOIN bronze.bronze_load_metadata m ON m.table_name = 'bronze.erp_px_cat_g1v2'
        WHERE t.load_date > COALESCE(m.last_load_date, '1900-01-01');
        MERGE bronze.bronze_load_metadata AS m
        USING (SELECT 'bronze.erp_px_cat_g1v2' table_name, @batch_load_date last_load_date, COUNT(*) row_count
               FROM bronze.erp_px_cat_g1v2) s
        ON m.table_name = s.table_name
        WHEN MATCHED THEN UPDATE SET m.last_load_date = s.last_load_date, m.row_count = s.row_count
        WHEN NOT MATCHED THEN INSERT (table_name, last_load_date, row_count)
                              VALUES (s.table_name, s.last_load_date, s.row_count);
        DROP TABLE #erp_px_cat_g1v2;
        SET @end_time = SYSUTCDATETIME();
        PRINT '>> bronze.erp_px_cat_g1v2 duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR(20)) + ' seconds';

        PRINT '==========================================';
        PRINT 'Loading Bronze Layer is Completed';
        PRINT '==========================================';
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
