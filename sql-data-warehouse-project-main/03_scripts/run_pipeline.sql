/*
Execute Bronze -> Silver -> Gold and write success/error records to dbo.pipeline_log.
*/
IF OBJECT_ID('dbo.pipeline_log', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.pipeline_log (
        log_id INT IDENTITY(1,1) PRIMARY KEY,
        pipeline_name NVARCHAR(128) NOT NULL,
        step_name NVARCHAR(128) NOT NULL,
        status NVARCHAR(20) NOT NULL,
        message NVARCHAR(MAX),
        started_at DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        completed_at DATETIME2
    );
END
GO

CREATE OR ALTER PROCEDURE dbo.run_pipeline AS
BEGIN
    SET XACT_ABORT ON;
    SET NOCOUNT ON;

    DECLARE @step NVARCHAR(128),
            @started_at DATETIME2;

    BEGIN TRY
        SET @step = 'bronze.load_bronze';
        SET @started_at = SYSUTCDATETIME();
        INSERT INTO dbo.pipeline_log (pipeline_name, step_name, status, started_at)
        VALUES ('main_pipeline', @step, 'RUNNING', @started_at);

        EXEC bronze.load_bronze;

        UPDATE dbo.pipeline_log
        SET status = 'SUCCESS', completed_at = SYSUTCDATETIME(),
            message = 'Bronze load completed'
        WHERE log_id = SCOPE_IDENTITY();

        SET @step = 'silver.load_silver';
        SET @started_at = SYSUTCDATETIME();
        INSERT INTO dbo.pipeline_log (pipeline_name, step_name, status, started_at)
        VALUES ('main_pipeline', @step, 'RUNNING', @started_at);

        EXEC silver.load_silver;

        UPDATE dbo.pipeline_log
        SET status = 'SUCCESS', completed_at = SYSUTCDATETIME(),
            message = 'Silver load completed'
        WHERE log_id = SCOPE_IDENTITY();

        SET @step = 'gold.load_gold';
        SET @started_at = SYSUTCDATETIME();
        INSERT INTO dbo.pipeline_log (pipeline_name, step_name, status, started_at)
        VALUES ('main_pipeline', @step, 'RUNNING', @started_at);

        EXEC gold.load_gold;

        UPDATE dbo.pipeline_log
        SET status = 'SUCCESS', completed_at = SYSUTCDATETIME(),
            message = 'Gold load completed'
        WHERE log_id = SCOPE_IDENTITY();
    END TRY
    BEGIN CATCH
        UPDATE dbo.pipeline_log
        SET status = 'FAILED',
            completed_at = SYSUTCDATETIME(),
            message = CONCAT(
                'Error ', ERROR_NUMBER(), ' (state ', ERROR_STATE(), '): ',
                ERROR_MESSAGE()
            )
        WHERE log_id = SCOPE_IDENTITY();

        THROW;
    END CATCH
END
GO
