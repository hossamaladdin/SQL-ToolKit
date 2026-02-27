DROP PROCEDURE IF EXISTS ##sp_CollectBackupStatus;
GO
CREATE PROCEDURE ##sp_CollectBackupStatus
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Create table in master if it doesn't exist
    IF OBJECT_ID('tempdb..##DBA_BackupStatus') IS NULL
    BEGIN
        CREATE TABLE ##DBA_BackupStatus (
            database_name NVARCHAR(128),
            database_status NVARCHAR(60),
            recovery_model NVARCHAR(60),
            last_full_backup NVARCHAR(20),
            days_since_full_backup INT,
            full_backup_status NVARCHAR(20),
            last_diff_backup NVARCHAR(20),
            days_since_diff_backup INT,
            last_log_backup NVARCHAR(20),
            days_since_log_backup INT,
            log_backup_status NVARCHAR(20),
            backup_health NVARCHAR(100),
            collection_date DATETIME DEFAULT GETDATE()
        );
    END;
    
    -- Clear existing data
    TRUNCATE TABLE ##DBA_BackupStatus;
    
    -- Insert new data
    WITH LatestBackups AS (
        SELECT 
            database_name,
            type,
            backup_start_date,
            backup_finish_date,
            -- Use ROW_NUMBER to get only the latest backup of each type for each database
            ROW_NUMBER() OVER (PARTITION BY database_name, type ORDER BY backup_finish_date DESC) as backup_rank
        FROM msdb.dbo.backupset
    )
    INSERT INTO ##DBA_BackupStatus (
        database_name, database_status, recovery_model, 
        last_full_backup, days_since_full_backup, full_backup_status,
        last_diff_backup, days_since_diff_backup,
        last_log_backup, days_since_log_backup, log_backup_status,
        backup_health
    )
    SELECT 
        d.name AS database_name,
        d.state_desc AS database_status,
        d.recovery_model_desc AS recovery_model,
        -- Full backup info
        ISNULL(CONVERT(VARCHAR(20), f.backup_finish_date, 120), 'NEVER') AS last_full_backup,
        ISNULL(DATEDIFF(DAY, f.backup_finish_date, GETDATE()), 999) AS days_since_full_backup,
        CASE 
            WHEN f.backup_finish_date IS NULL THEN 'CRITICAL'
            WHEN DATEDIFF(DAY, f.backup_finish_date, GETDATE()) > 7 THEN 'WARNING'
            ELSE 'OK'
        END AS full_backup_status,
        -- Differential backup info
        ISNULL(CONVERT(VARCHAR(20), d_bak.backup_finish_date, 120), 'NEVER') AS last_diff_backup,
        ISNULL(DATEDIFF(DAY, d_bak.backup_finish_date, GETDATE()), 999) AS days_since_diff_backup,
        -- Log backup info (only for FULL or BULK_LOGGED recovery models)
        CASE 
            WHEN d.recovery_model_desc = 'SIMPLE' THEN 'N/A'
            ELSE ISNULL(CONVERT(VARCHAR(20), l.backup_finish_date, 120), 'NEVER')
        END AS last_log_backup,
        CASE
            WHEN d.recovery_model_desc = 'SIMPLE' THEN NULL
            ELSE ISNULL(DATEDIFF(DAY, l.backup_finish_date, GETDATE()), 999)
        END AS days_since_log_backup,
        CASE 
            WHEN d.recovery_model_desc = 'SIMPLE' THEN 'N/A'
            WHEN l.backup_finish_date IS NULL THEN 'CRITICAL'
            WHEN DATEDIFF(DAY, l.backup_finish_date, GETDATE()) > 1 THEN 'WARNING'
            ELSE 'OK'
        END AS log_backup_status,
        -- Overall backup health assessment
        CASE 
            WHEN f.backup_finish_date IS NULL THEN 'CRITICAL: No Full Backup'
            WHEN d.recovery_model_desc <> 'SIMPLE' AND l.backup_finish_date IS NULL THEN 'CRITICAL: No Log Backup'
            WHEN DATEDIFF(DAY, f.backup_finish_date, GETDATE()) > 7 THEN 'WARNING: Full Backup Overdue'
            WHEN d.recovery_model_desc <> 'SIMPLE' AND DATEDIFF(DAY, l.backup_finish_date, GETDATE()) > 1 THEN 'WARNING: Log Backup Overdue'
            ELSE 'OK'
        END AS backup_health
    FROM sys.databases d
    LEFT JOIN LatestBackups f
        ON d.name = f.database_name AND f.type = 'D' AND f.backup_rank = 1  -- Latest full backup
    LEFT JOIN LatestBackups d_bak
        ON d.name = d_bak.database_name AND d_bak.type = 'I' AND d_bak.backup_rank = 1  -- Latest differential backup
    LEFT JOIN LatestBackups l
        ON d.name = l.database_name AND l.type = 'L' AND l.backup_rank = 1  -- Latest log backup
    WHERE d.database_id<>2;

    PRINT 'Backup status collection complete.';

	SELECT * FROM ##DBA_BackupStatus;
END;
GO