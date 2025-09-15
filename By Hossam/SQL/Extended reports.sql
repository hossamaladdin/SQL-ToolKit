-- 1. Single User Login Report (combine both user views)
DROP VIEW IF EXISTS vw_UserActivityReport;
GO
CREATE VIEW vw_UserActivityReport
AS
SELECT 
    sp.name AS login_name,
    MAX(ls.login_time) AS last_login_time,
    COUNT(ls.session_id) AS login_count_current,
    DATEDIFF(DAY, MAX(ls.login_time), GETDATE()) AS days_since_last_login,
    CASE 
        WHEN sp.is_disabled = 1 THEN 'Disabled'
        WHEN COUNT(ls.session_id) > 0 THEN 'Currently Logged In'
        WHEN DATEDIFF(DAY, MAX(ls.login_time), GETDATE()) <= 30 THEN 'Active'
        ELSE 'Inactive'
    END AS activity_status,
    CASE 
        WHEN sp.type_desc = 'WINDOWS_LOGIN' THEN 'Windows Authentication'
        ELSE 'SQL Authentication'
    END AS login_type,
    sp.create_date AS account_created_date,
    CASE
        WHEN sp.type_desc = 'WINDOWS_LOGIN' THEN 'Windows Authentication (Managed by Windows)'
        WHEN sl.is_expiration_checked = 0 THEN 'Never Expires'
        ELSE 'SQL Login - Check Password Policy'
    END AS password_policy,
    CASE
        WHEN sp.type_desc = 'WINDOWS_LOGIN' THEN NULL
        WHEN sl.is_expiration_checked = 0 THEN NULL
        ELSE DATEADD(DAY, (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'default password expiration policy'), sl.modify_date)
    END AS estimated_expiration_date,
    CASE
        WHEN sp.type_desc = 'WINDOWS_LOGIN' THEN NULL
        WHEN sl.is_expiration_checked = 0 THEN NULL
        ELSE DATEDIFF(DAY, GETDATE(), 
             DATEADD(DAY, (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'default password expiration policy'), sl.modify_date))
    END AS days_until_expiration
FROM sys.server_principals sp
LEFT JOIN sys.dm_exec_sessions ls
    ON sp.name = ls.login_name
LEFT JOIN sys.sql_logins sl
    ON sp.principal_id = sl.principal_id
WHERE sp.type IN ('S', 'U', 'G')  -- SQL login, Windows login, Windows group
    AND sp.name NOT LIKE '##%'    -- Exclude system logins
GROUP BY 
    sp.name, 
    sp.is_disabled,
    sp.type_desc,
    sp.create_date,
    sp.principal_id,
    sl.is_expiration_checked,
    sl.modify_date
GO

-- 2. Backup Status Report Procedure
DROP PROCEDURE IF EXISTS sp_CollectBackupStatus;
GO
CREATE PROCEDURE sp_CollectBackupStatus
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Create table in master if it doesn't exist
    IF NOT EXISTS (SELECT * FROM master.sys.tables WHERE name = 'DBA_BackupStatus')
    BEGIN
        CREATE TABLE master.dbo.DBA_BackupStatus (
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
    TRUNCATE TABLE master.dbo.DBA_BackupStatus;
    
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
    INSERT INTO master.dbo.DBA_BackupStatus (
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
        ON d.name = l.database_name AND l.type = 'L' AND l.backup_rank = 1;  -- Latest log backup
   
    PRINT 'Backup status collection complete.';
END;
GO

-- 3. Full Table Scan Query Procedure
DROP PROCEDURE IF EXISTS sp_CollectFullTableScanQueries;
GO
CREATE PROCEDURE sp_CollectFullTableScanQueries
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Create table in master if it doesn't exist
    IF NOT EXISTS (SELECT * FROM master.sys.tables WHERE name = 'DBA_FullTableScanQueries')
    BEGIN
        CREATE TABLE master.dbo.DBA_FullTableScanQueries (
            database_name NVARCHAR(128),
            object_name NVARCHAR(128),
            execution_count INT,
            avg_logical_reads BIGINT,
            avg_elapsed_time_ms BIGINT,
            last_execution_time DATETIME,
            query_text NVARCHAR(MAX),
            scan_type NVARCHAR(30),
            collection_date DATETIME DEFAULT GETDATE()
        );
    END;
    
    -- Clear existing data
    TRUNCATE TABLE master.dbo.DBA_FullTableScanQueries;
    
    -- Insert new data
    INSERT INTO master.dbo.DBA_FullTableScanQueries (
        database_name, object_name, execution_count, avg_logical_reads, 
        avg_elapsed_time_ms, last_execution_time, query_text, scan_type
    )
    SELECT 
        DB_NAME(st.dbid) AS database_name,
        OBJECT_NAME(st.objectid, st.dbid) AS object_name,
        qs.execution_count,
        qs.total_logical_reads / qs.execution_count AS avg_logical_reads,
        qs.total_elapsed_time / qs.execution_count / 1000 AS avg_elapsed_time_ms,
        qs.last_execution_time,
        SUBSTRING(st.text, 1, 4000) AS query_text, -- Limit to 4000 chars to avoid overflow
        CASE
            WHEN qp.query_plan.exist('//RelOp[@PhysicalOp="Table Scan"]') = 1 THEN 'Table Scan'
            WHEN qp.query_plan.exist('//RelOp[@PhysicalOp="Clustered Index Scan"]') = 1 THEN 'Clustered Index Scan'
            ELSE 'Other Scan'
        END AS scan_type
    FROM sys.dm_exec_query_stats qs
    CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
    CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) qp
    WHERE qp.query_plan.exist('//RelOp[@PhysicalOp="Table Scan" or @PhysicalOp="Clustered Index Scan"]') = 1
        AND st.dbid IS NOT NULL
        AND st.objectid IS NOT NULL;
    
    PRINT 'Full table scan queries collection complete.';
END;
GO

-- 4. Combined Index Report Procedure
DROP PROCEDURE IF EXISTS sp_CollectIndexStats;
GO
CREATE PROCEDURE sp_CollectIndexStats
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Create table in master if it doesn't exist
    IF NOT EXISTS (SELECT * FROM master.sys.tables WHERE name = 'DBA_IndexStats')
    BEGIN
        CREATE TABLE master.dbo.DBA_IndexStats (
            database_name NVARCHAR(128),
            schema_name NVARCHAR(128),
            table_name NVARCHAR(128),
            index_name NVARCHAR(128),
            index_type NVARCHAR(60),
            is_primary_key BIT,
            is_unique BIT,
            is_disabled BIT,
            row_count BIGINT,
            index_size_MB DECIMAL(18,2),
            avg_fragmentation_in_percent FLOAT,
            page_count BIGINT,
            total_user_operations BIGINT,
            user_seeks BIGINT,
            user_scans BIGINT,
            user_lookups BIGINT,
            write_operations BIGINT,
            last_user_seek DATETIME,
            last_user_update DATETIME,
            recommended_action NVARCHAR(20),
            collection_date DATETIME DEFAULT GETDATE()
        );
    END;
    
    -- Clear existing data
    TRUNCATE TABLE master.dbo.DBA_IndexStats;
    
    -- Get list of online user databases
    DECLARE @databases TABLE (dbname NVARCHAR(128));
    INSERT INTO @databases
    SELECT name FROM sys.databases 
    WHERE state_desc = 'ONLINE' 
    AND database_id > 4 
    AND is_read_only = 0;
    
    -- Loop through databases
    DECLARE @dbname NVARCHAR(128);
    DECLARE @sql NVARCHAR(MAX);
    
    DECLARE db_cursor CURSOR FOR 
    SELECT dbname FROM @databases;
    
    OPEN db_cursor;
    FETCH NEXT FROM db_cursor INTO @dbname;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Collect index stats with fragmentation
        SET @sql = N'
        USE [' + @dbname + N'];
        INSERT INTO master.dbo.DBA_IndexStats (
            database_name, schema_name, table_name, index_name, index_type,
            is_primary_key, is_unique, is_disabled, row_count, index_size_MB,
            avg_fragmentation_in_percent, page_count,
            total_user_operations, user_seeks, user_scans, user_lookups,
            write_operations, last_user_seek, last_user_update,
            recommended_action
        )
        SELECT 
            DB_NAME() AS database_name,
            SCHEMA_NAME(t.schema_id) AS schema_name,
            t.name AS table_name,
            i.name AS index_name,
            i.type_desc AS index_type,
            i.is_primary_key,
            i.is_unique,
            i.is_disabled,
            p.rows AS row_count,
            SUM(a.total_pages) * 8 / 1024 AS index_size_MB,
            ips.avg_fragmentation_in_percent,
            ips.page_count,
            ISNULL(ius.user_seeks, 0) + ISNULL(ius.user_scans, 0) + ISNULL(ius.user_lookups, 0) AS total_user_operations,
            ISNULL(ius.user_seeks, 0) AS user_seeks,
            ISNULL(ius.user_scans, 0) AS user_scans,
            ISNULL(ius.user_lookups, 0) AS user_lookups,
            ISNULL(ius.user_updates, 0) AS write_operations,
            ius.last_user_seek,
            ius.last_user_update,
            CASE
                WHEN ips.avg_fragmentation_in_percent > 30 THEN ''REBUILD''
                WHEN ips.avg_fragmentation_in_percent BETWEEN 10 AND 30 THEN ''REORGANIZE''
                ELSE ''OK''
            END AS recommended_action
        FROM sys.tables t
        JOIN sys.indexes i ON t.object_id = i.object_id
        JOIN sys.partitions p ON i.object_id = p.object_id AND i.index_id = p.index_id
        JOIN sys.allocation_units a ON p.partition_id = a.container_id
        LEFT JOIN sys.dm_db_index_usage_stats ius ON i.object_id = ius.object_id 
                                             AND i.index_id = ius.index_id
                                             AND ius.database_id = DB_ID()
        LEFT JOIN sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, ''LIMITED'') ips 
                  ON i.object_id = ips.object_id 
                  AND i.index_id = ips.index_id
        WHERE i.index_id > 0  -- Skip heaps
        GROUP BY 
            t.schema_id,
            t.name,
            i.name,
            i.type_desc,
            i.is_primary_key,
            i.is_unique,
            i.is_disabled,
            p.rows,
            ips.avg_fragmentation_in_percent,
            ips.page_count,
            ius.user_seeks,
            ius.user_scans,
            ius.user_lookups,
            ius.user_updates,
            ius.last_user_seek,
            ius.last_user_update;
        ';
        EXEC sp_executesql @sql;
        
        FETCH NEXT FROM db_cursor INTO @dbname;
    END;
    
    CLOSE db_cursor;
    DEALLOCATE db_cursor;
        
    PRINT 'Index statistics collection complete.';
END;
GO

-- 5. Table Size Report Procedure
DROP PROCEDURE IF EXISTS sp_CollectTableSizes;
GO
CREATE PROCEDURE sp_CollectTableSizes
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Create table in master if it doesn't exist
    IF NOT EXISTS (SELECT * FROM master.sys.tables WHERE name = 'DBA_TableSizes')
    BEGIN
        CREATE TABLE master.dbo.DBA_TableSizes (
            database_name NVARCHAR(128),
            schema_name NVARCHAR(128),
            table_name NVARCHAR(128),
            row_count BIGINT,
            total_space_MB DECIMAL(18,2),
            used_space_MB DECIMAL(18,2),
            unused_space_MB DECIMAL(18,2),
            storage_type NVARCHAR(20),
            collection_date DATETIME DEFAULT GETDATE()
        );
    END;
    
    -- Clear existing data
    TRUNCATE TABLE master.dbo.DBA_TableSizes;
    
    -- Get list of online user databases
    DECLARE @databases TABLE (dbname NVARCHAR(128));
    INSERT INTO @databases
    SELECT name FROM sys.databases 
    WHERE state_desc = 'ONLINE' 
    AND database_id > 4 
    AND is_read_only = 0;
    
    -- Loop through databases
    DECLARE @dbname NVARCHAR(128);
    DECLARE @sql NVARCHAR(MAX);
    
    DECLARE db_cursor CURSOR FOR 
    SELECT dbname FROM @databases;
    
    OPEN db_cursor;
    FETCH NEXT FROM db_cursor INTO @dbname;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Collect table sizes
        SET @sql = N'
        USE [' + @dbname + N'];
        INSERT INTO master.dbo.DBA_TableSizes (
            database_name, schema_name, table_name, row_count, 
            total_space_MB, used_space_MB, unused_space_MB, storage_type
        )
        SELECT 
            DB_NAME() AS database_name,
            SCHEMA_NAME(t.schema_id) AS schema_name,
            t.name AS table_name,
            p.rows AS row_count,
            SUM(a.total_pages) * 8 / 1024 AS total_space_MB,
            SUM(a.used_pages) * 8 / 1024 AS used_space_MB,
            (SUM(a.total_pages) - SUM(a.used_pages)) * 8 / 1024 AS unused_space_MB,
            CASE 
                WHEN i.type_desc = ''HEAP'' THEN ''HEAP''
                ELSE ''CLUSTERED''
            END AS storage_type
        FROM sys.tables t
        JOIN sys.indexes i ON t.object_id = i.object_id AND i.index_id <= 1
        JOIN sys.partitions p ON i.object_id = p.object_id AND i.index_id = p.index_id
        JOIN sys.allocation_units a ON p.partition_id = a.container_id
        GROUP BY 
            t.schema_id,
            t.name,
            p.rows,
            i.type_desc;
        ';
        EXEC sp_executesql @sql;
        
        FETCH NEXT FROM db_cursor INTO @dbname;
    END;
    
    CLOSE db_cursor;
    DEALLOCATE db_cursor;    

    PRINT 'Table size collection complete.';
END;
GO


-- Run data collection procedures
EXEC sp_CollectBackupStatus;
EXEC sp_CollectFullTableScanQueries;
--EXEC sp_CollectIndexStats;
EXEC sp_CollectTableSizes;

-- Send reports
EXEC sp_send_reports
@mailto = 'h.abudayefhassan@mobily.com.sa;e.mekala@mobily.com.sa',
@subject = 'SQL DBA User Account Report',
@titles = 'User Activity and Password Report',
@objects = 'vw_UserActivityReport';

EXEC sp_send_reports
@mailto = 'h.abudayefhassan@mobily.com.sa;e.mekala@mobily.com.sa',
@subject = 'SQL DBA Backup Status Report',
@titles = 'Database Backup Status',
@objects = 'master.dbo.DBA_BackupStatus';

EXEC sp_send_reports
@mailto = 'h.abudayefhassan@mobily.com.sa;e.mekala@mobily.com.sa',
@subject = 'SQL DBA Performance Report',
@titles = 'Full Table Scan Queries',
@objects = 'master.dbo.DBA_FullTableScanQueries';

/*
EXEC sp_send_reports
@mailto = 'h.abudayefhassan@mobily.com.sa;e.mekala@mobily.com.sa',
@subject = 'SQL DBA Index Status Report',
@titles = 'Index Fragmentation and Usage',
@objects = 'master.dbo.DBA_IndexStats';
*/

EXEC sp_send_reports
@mailto = 'h.abudayefhassan@mobily.com.sa;e.mekala@mobily.com.sa',
@subject = 'SQL DBA Table Size Report',
@titles = 'Table Size Information',
@objects = 'master.dbo.DBA_TableSizes';