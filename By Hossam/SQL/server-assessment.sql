-- SQL Server Comprehensive Assessment Script
-- Author: Hossam
-- Description: Single result set for easy Excel copy-paste across multiple servers
-- Output: Two result sets - Summary (1 row) and Detailed (multiple rows)

SET NOCOUNT ON;

-- Drop temp tables if they exist
DROP TABLE IF EXISTS #ServerMetrics, #DatabaseBackups, #FailedJobs, #AllJobs,
                     #DiskSpace, #SysAdminLogins, #FileGrowth, #TempDBFiles,
                     #LargestDBs, #SQLLogins, #Final;

-- ============================================================================
-- COLLECT SERVER METRICS INTO TEMP TABLE
-- ============================================================================

-- Create main metrics table using PIVOT for configurations
SELECT
    CAST([max degree of parallelism] AS INT) AS MAXDOP_Value,
    CAST([cost threshold for parallelism] AS INT) AS CTFP_Value,
    CAST([max server memory (MB)] AS BIGINT) AS MaxMem_Value,
    CAST([min server memory (MB)] AS BIGINT) AS MinMem_Value,
    CAST([xp_cmdshell] AS INT) AS xp_cmdshell_Value,
    CAST([Ad Hoc Distributed Queries] AS INT) AS AdHocDist_Value,
    CAST([Ole Automation Procedures] AS INT) AS OleAuto_Value,
    CAST([remote access] AS INT) AS RemoteAccess_Value,
    CAST([clr enabled] AS INT) AS CLR_Value,
    CAST([remote admin connections] AS INT) AS DAC_Value,
    CAST([optimize for ad hoc workloads] AS INT) AS OptAdHoc_Value,
    CAST([backup compression default] AS INT) AS BackupComp_Value,
    CAST(NULL AS BIGINT) AS PhysicalMem_MB,
    CAST(NULL AS BIGINT) AS AvailablePhysicalMem_MB,
    CAST(NULL AS BIGINT) AS TargetServerMem_MB,
    CAST(NULL AS BIGINT) AS TotalServerMem_MB,
    CAST(NULL AS VARCHAR(1)) AS IFI_Value,
    CAST(NULL AS NVARCHAR(256)) AS ServiceAcct,
    CAST(NULL AS NVARCHAR(50)) AS ServiceStartMode,
    CAST(NULL AS INT) AS IndexJobCount,
    CAST(NULL AS INT) AS BackupJobCount,
    CAST(NULL AS INT) AS TempDBFiles,
    CAST(NULL AS INT) AS CPUCount,
    CAST(NULL AS INT) AS PhysicalCPUCount,
    CAST(NULL AS INT) AS HyperThreadRatio,
    CAST(NULL AS DATETIME) AS StartTime,
    CAST(NULL AS DECIMAL(5,2)) AS MinDiskPct,
    CAST(NULL AS BIGINT) AS PageLifeExpectancy,
    CAST(NULL AS DECIMAL(5,2)) AS BufferCacheHitRatio,
    CAST(NULL AS INT) AS UserConnections,
    CAST(NULL AS INT) AS IsAGEnabled,
    CAST(NULL AS INT) AS IsClustered,
    CAST(NULL AS INT) AS BlockedSessionCount,
    CAST(NULL AS VARCHAR(50)) AS Collation,
    CAST(NULL AS INT) AS ActiveSysAdmins,
    CAST(NULL AS INT) AS ActiveSQLLogins,
    CAST(NULL AS INT) AS OfflineDatabases,
    CAST(NULL AS INT) AS OnlineUserDatabases,
    CAST(NULL AS INT) AS FailedJobsLast24h,
    CAST(NULL AS INT) AS DaysSinceRestart,
    CAST(NULL AS INT) AS DatabasesNeedingBackup,
    CAST(NULL AS DATETIME) AS LastFullBackup,
    CAST(NULL AS VARCHAR(50)) AS AuthMode,
    CAST(NULL AS VARCHAR(50)) AS MAXDOP_Status,
    CAST(NULL AS VARCHAR(50)) AS CTFP_Status,
    CAST(NULL AS VARCHAR(50)) AS MaxMemory_Status,
    CAST(NULL AS VARCHAR(50)) AS IFI_Status,
    CAST(NULL AS VARCHAR(50)) AS ServiceAccount_Type,
    CAST(NULL AS VARCHAR(50)) AS IndexMaint_Status,
    CAST(NULL AS VARCHAR(50)) AS xp_cmdshell_Status,
    CAST(NULL AS VARCHAR(50)) AS AdHocDist_Status,
    CAST(NULL AS VARCHAR(50)) AS OleAuto_Status,
    CAST(NULL AS VARCHAR(50)) AS RemoteAccess_Status,
    CAST(NULL AS VARCHAR(50)) AS CLR_Status,
    CAST(NULL AS VARCHAR(50)) AS DAC_Status,
    CAST(NULL AS VARCHAR(50)) AS TempDB_Status,
    CAST(NULL AS VARCHAR(50)) AS DiskSpace_Status,
    CAST(NULL AS VARCHAR(50)) AS PLE_Status,
    CAST(NULL AS VARCHAR(50)) AS MemoryPressure_Status,
    CAST(NULL AS INT) AS TotalWarnings,
    CAST(NULL AS INT) AS TotalCritical
INTO #ServerMetrics
FROM (
    SELECT name, CAST(value AS VARCHAR(100)) AS value
    FROM sys.configurations
    WHERE name IN ('max degree of parallelism', 'cost threshold for parallelism', 'max server memory (MB)',
                   'min server memory (MB)', 'xp_cmdshell', 'Ad Hoc Distributed Queries',
                   'Ole Automation Procedures', 'remote access', 'clr enabled',
                   'remote admin connections', 'optimize for ad hoc workloads', 'backup compression default')
) AS SourceTable
PIVOT (
    MAX(value)
    FOR name IN ([max degree of parallelism], [cost threshold for parallelism], [max server memory (MB)],
                 [min server memory (MB)], [xp_cmdshell], [Ad Hoc Distributed Queries],
                 [Ole Automation Procedures], [remote access], [clr enabled],
                 [remote admin connections], [optimize for ad hoc workloads], [backup compression default])
) AS PivotTable;

-- Update from sys.dm_os_sys_memory (memory info)
UPDATE #ServerMetrics
SET PhysicalMem_MB = (SELECT total_physical_memory_kb/1024 FROM sys.dm_os_sys_memory),
    AvailablePhysicalMem_MB = (SELECT available_physical_memory_kb/1024 FROM sys.dm_os_sys_memory);

-- Update from sys.dm_os_sys_info (CPU and start time)
UPDATE #ServerMetrics
SET CPUCount = (SELECT cpu_count FROM sys.dm_os_sys_info),
    PhysicalCPUCount = (SELECT cpu_count / hyperthread_ratio FROM sys.dm_os_sys_info),
    HyperThreadRatio = (SELECT hyperthread_ratio FROM sys.dm_os_sys_info),
    StartTime = (SELECT sqlserver_start_time FROM sys.dm_os_sys_info);

-- Update from sys.dm_os_performance_counters (memory performance)
UPDATE #ServerMetrics
SET TargetServerMem_MB = (SELECT TOP 1 CAST(cntr_value AS BIGINT)/1024 FROM sys.dm_os_performance_counters
                          WHERE counter_name = 'Target Server Memory (KB)' AND object_name LIKE '%Memory Manager%'),
    TotalServerMem_MB = (SELECT TOP 1 CAST(cntr_value AS BIGINT)/1024 FROM sys.dm_os_performance_counters
                         WHERE counter_name = 'Total Server Memory (KB)' AND object_name LIKE '%Memory Manager%'),
    PageLifeExpectancy = (SELECT TOP 1 CAST(cntr_value AS BIGINT) FROM sys.dm_os_performance_counters
                          WHERE counter_name = 'Page life expectancy' AND object_name LIKE '%Buffer Manager%'),
    BufferCacheHitRatio = (SELECT TOP 1
                           CAST((CAST(a.cntr_value AS BIGINT) * 100.0) / NULLIF(CAST(b.cntr_value AS BIGINT), 0) AS DECIMAL(5,2))
                           FROM sys.dm_os_performance_counters a
                           INNER JOIN sys.dm_os_performance_counters b
                               ON a.object_name = b.object_name
                           WHERE a.counter_name = 'Buffer cache hit ratio'
                               AND b.counter_name = 'Buffer cache hit ratio base'
                               AND a.object_name LIKE '%Buffer Manager%'),
    UserConnections = (SELECT TOP 1 CAST(cntr_value AS INT) FROM sys.dm_os_performance_counters
                       WHERE counter_name = 'User Connections' AND object_name LIKE '%General Statistics%');

-- Update from sys.dm_server_services (service account and IFI)
UPDATE #ServerMetrics
SET IFI_Value = (SELECT TOP 1 instant_file_initialization_enabled FROM sys.dm_server_services WHERE servicename LIKE 'SQL Server%'),
    ServiceAcct = (SELECT TOP 1 service_account FROM sys.dm_server_services WHERE servicename LIKE 'SQL Server%'),
    ServiceStartMode = (SELECT TOP 1 startup_type_desc FROM sys.dm_server_services WHERE servicename LIKE 'SQL Server%');

-- Update from msdb.dbo.sysjobs (job counts)
UPDATE #ServerMetrics
SET IndexJobCount = (SELECT COUNT(*) FROM msdb.dbo.sysjobs
                     WHERE (name LIKE '%index%' OR name LIKE '%reindex%' OR name LIKE '%defrag%' OR name LIKE '%IndexOptimize%')
                     AND enabled = 1),
    BackupJobCount = (SELECT COUNT(*) FROM msdb.dbo.sysjobs
                      WHERE (name LIKE '%backup%' OR name LIKE '%DatabaseBackup%')
                      AND enabled = 1);

-- Update from sys.master_files (TempDB file count)
UPDATE #ServerMetrics
SET TempDBFiles = (SELECT COUNT(*) FROM sys.master_files WHERE database_id = 2 AND type = 0);

-- Update from sys.dm_os_volume_stats (disk space)
UPDATE #ServerMetrics
SET MinDiskPct = (SELECT MIN(CAST((CAST(vs.available_bytes AS BIGINT) * 100) / CAST(vs.total_bytes AS FLOAT) AS DECIMAL(5,2)))
                  FROM sys.master_files AS mf
                  CROSS APPLY sys.dm_os_volume_stats(mf.database_id, mf.file_id) AS vs);

-- Update AG and clustering info
UPDATE #ServerMetrics
SET IsAGEnabled = (SELECT CASE WHEN SERVERPROPERTY('IsHadrEnabled') = 1 THEN 1 ELSE 0 END),
    IsClustered = (SELECT CASE WHEN SERVERPROPERTY('IsClustered') = 1 THEN 1 ELSE 0 END),
    Collation = (SELECT CAST(SERVERPROPERTY('Collation') AS VARCHAR(50)));

-- Update blocked sessions count
UPDATE #ServerMetrics
SET BlockedSessionCount = (SELECT COUNT(*) FROM sys.dm_exec_requests WHERE blocking_session_id <> 0);

-- Update login counts
UPDATE #ServerMetrics
SET ActiveSysAdmins = (SELECT COUNT(*) FROM sys.server_principals p
                       WHERE p.type IN ('S', 'U', 'G') AND p.is_disabled = 0
                       AND IS_SRVROLEMEMBER('sysadmin', p.name) = 1),
    ActiveSQLLogins = (SELECT COUNT(*) FROM sys.sql_logins WHERE is_disabled = 0);

-- Update database counts
UPDATE #ServerMetrics
SET OfflineDatabases = (SELECT COUNT(*) FROM sys.databases WHERE state_desc <> 'ONLINE'),
    OnlineUserDatabases = (SELECT COUNT(*) FROM sys.databases WHERE database_id > 4 AND state_desc = 'ONLINE');

-- Update failed jobs count
UPDATE #ServerMetrics
SET FailedJobsLast24h = (SELECT COUNT(DISTINCT j.job_id)
                         FROM msdb.dbo.sysjobs j
                         INNER JOIN msdb.dbo.sysjobhistory h ON j.job_id = h.job_id
                         WHERE h.run_status IN (0, 2, 3)
                         AND h.step_id = 0
                         AND h.run_date >= CONVERT(INT, CONVERT(VARCHAR(8), DATEADD(DAY, -1, GETDATE()), 112))
                         AND j.enabled = 1);

-- Update days since restart
UPDATE #ServerMetrics
SET DaysSinceRestart = DATEDIFF(DAY, StartTime, GETDATE());

-- Update backup metrics (exclude AG secondary replicas)
UPDATE #ServerMetrics
SET DatabasesNeedingBackup = (SELECT COUNT(DISTINCT d.name)
                              FROM sys.databases d
                              LEFT JOIN sys.dm_hadr_database_replica_states hdrs ON d.database_id = hdrs.database_id AND hdrs.is_local = 1
                              WHERE d.database_id > 4
                              AND d.state_desc = 'ONLINE'
                              AND (hdrs.database_id IS NULL OR hdrs.is_primary_replica = 1)  -- Exclude AG secondaries
                              AND (
                                  -- No full backup in last 7 days
                                  NOT EXISTS (
                                      SELECT 1 FROM msdb.dbo.backupset b
                                      WHERE b.database_name COLLATE DATABASE_DEFAULT = d.name COLLATE DATABASE_DEFAULT
                                      AND b.type = 'D'
                                      AND DATEDIFF(DAY, b.backup_finish_date, GETDATE()) <= 7
                                  )
                                  OR
                                  -- For FULL/BULK_LOGGED: no log backup in last 24 hours
                                  (d.recovery_model IN (1, 2) AND NOT EXISTS (
                                      SELECT 1 FROM msdb.dbo.backupset b
                                      WHERE b.database_name COLLATE DATABASE_DEFAULT = d.name COLLATE DATABASE_DEFAULT
                                      AND b.type = 'L'
                                      AND DATEDIFF(HOUR, b.backup_finish_date, GETDATE()) <= 24
                                  ))
                              )),
    LastFullBackup = (SELECT MAX(b.backup_finish_date)
                      FROM msdb.dbo.backupset b
                      INNER JOIN sys.databases d ON b.database_name COLLATE DATABASE_DEFAULT = d.name COLLATE DATABASE_DEFAULT
                      WHERE b.type = 'D' AND d.database_id > 4);

-- Calculate status columns
UPDATE #ServerMetrics
SET AuthMode = CASE WHEN SERVERPROPERTY('IsIntegratedSecurityOnly') = 1 THEN 'Windows Only' ELSE 'Mixed Mode' END;

UPDATE #ServerMetrics
SET MAXDOP_Status = CASE
                        WHEN MAXDOP_Value = 0 THEN 'WARNING: Unlimited'
                        WHEN MAXDOP_Value = 1 THEN 'No Parallelism'
                        WHEN MAXDOP_Value > 8 THEN 'High Value'
                        ELSE 'OK'
                    END;

UPDATE #ServerMetrics
SET CTFP_Status = CASE
                      WHEN CTFP_Value = 5 THEN 'WARNING: Default'
                      WHEN CTFP_Value < 25 THEN 'Low'
                      ELSE 'OK'
                  END;

UPDATE #ServerMetrics
SET MaxMemory_Status = CASE
                           WHEN MaxMem_Value = 2147483647 THEN 'WARNING: Unlimited'
                           WHEN MaxMem_Value > (PhysicalMem_MB * 0.9) THEN 'WARNING: >90% Physical'
                           ELSE 'OK'
                       END;

UPDATE #ServerMetrics
SET IFI_Status = CASE WHEN IFI_Value = 'Y' THEN 'OK' ELSE 'WARNING: Disabled' END;

UPDATE #ServerMetrics
SET ServiceAccount_Type = CASE
                              WHEN ServiceAcct LIKE 'NT AUTHORITY%' THEN 'WARNING: Built-in Account'
                              WHEN ServiceAcct LIKE 'NT SERVICE%' THEN 'Virtual Account'
                              ELSE 'Domain/Managed Account'
                          END;

UPDATE #ServerMetrics
SET IndexMaint_Status = CASE WHEN IndexJobCount = 0 THEN 'WARNING: None Found' ELSE 'OK' END;

UPDATE #ServerMetrics
SET xp_cmdshell_Status = CASE WHEN xp_cmdshell_Value = 1 THEN 'CRITICAL' ELSE 'OK' END,
    AdHocDist_Status = CASE WHEN AdHocDist_Value = 1 THEN 'WARNING' ELSE 'OK' END,
    OleAuto_Status = CASE WHEN OleAuto_Value = 1 THEN 'WARNING' ELSE 'OK' END,
    RemoteAccess_Status = CASE WHEN RemoteAccess_Value = 1 THEN 'WARNING' ELSE 'OK' END,
    CLR_Status = CASE WHEN CLR_Value = 1 THEN 'INFO' ELSE 'OK' END,
    DAC_Status = CASE WHEN DAC_Value = 1 THEN 'OK' ELSE 'INFO: DAC Disabled' END;

UPDATE #ServerMetrics
SET TempDB_Status = CASE WHEN TempDBFiles < CPUCount / 2 THEN 'WARNING: Add more files' ELSE 'OK' END;

UPDATE #ServerMetrics
SET DiskSpace_Status = CASE
                           WHEN MinDiskPct < 10 THEN 'CRITICAL'
                           WHEN MinDiskPct < 20 THEN 'WARNING'
                           ELSE 'OK'
                       END;

UPDATE #ServerMetrics
SET PLE_Status = CASE
                     WHEN PageLifeExpectancy < 300 THEN 'CRITICAL: <300 sec'
                     WHEN PageLifeExpectancy < 600 THEN 'WARNING: <10 min'
                     ELSE 'OK'
                 END;

UPDATE #ServerMetrics
SET MemoryPressure_Status = CASE
                                WHEN TotalServerMem_MB < TargetServerMem_MB * 0.9 THEN 'WARNING: Memory pressure'
                                ELSE 'OK'
                            END;

-- Calculate warning and critical counts
UPDATE #ServerMetrics
SET TotalWarnings = (CASE WHEN MAXDOP_Value = 0 OR MAXDOP_Value > 8 THEN 1 ELSE 0 END +
                     CASE WHEN CTFP_Value = 5 OR CTFP_Value < 25 THEN 1 ELSE 0 END +
                     CASE WHEN MaxMem_Value = 2147483647 OR MaxMem_Value > (PhysicalMem_MB * 0.9) THEN 1 ELSE 0 END +
                     CASE WHEN IFI_Value <> 'Y' THEN 1 ELSE 0 END +
                     CASE WHEN ServiceAcct LIKE 'NT AUTHORITY%' THEN 1 ELSE 0 END +
                     CASE WHEN IndexJobCount = 0 THEN 1 ELSE 0 END +
                     CASE WHEN RemoteAccess_Value = 1 THEN 1 ELSE 0 END +
                     CASE WHEN AdHocDist_Value = 1 THEN 1 ELSE 0 END +
                     CASE WHEN OleAuto_Value = 1 THEN 1 ELSE 0 END +
                     CASE WHEN TempDBFiles < CPUCount / 2 THEN 1 ELSE 0 END +
                     CASE WHEN MinDiskPct < 20 THEN 1 ELSE 0 END +
                     CASE WHEN PageLifeExpectancy < 600 THEN 1 ELSE 0 END +
                     CASE WHEN TotalServerMem_MB < TargetServerMem_MB * 0.9 THEN 1 ELSE 0 END),
    TotalCritical = (CASE WHEN xp_cmdshell_Value = 1 THEN 1 ELSE 0 END +
                     CASE WHEN MinDiskPct < 10 THEN 1 ELSE 0 END +
                     CASE WHEN PageLifeExpectancy < 300 THEN 1 ELSE 0 END +
                     ISNULL(DatabasesNeedingBackup, 0));

-- ============================================================================
-- RESULT SET 1: SUMMARY REPORT (Single Row)
-- ============================================================================
SELECT
    @@SERVERNAME AS ServerName,
    GETDATE() AS AssessmentDate,
    CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)) AS SQLVersion,
    CAST(SERVERPROPERTY('Edition') AS VARCHAR(100)) AS Edition,
    CAST(SERVERPROPERTY('ProductLevel') AS VARCHAR(50)) AS ServicePack,
    m.ActiveSysAdmins,
    m.ActiveSQLLogins,
    m.AuthMode,
    m.MAXDOP_Value AS MAXDOP,
    m.MAXDOP_Status,
    m.CTFP_Value AS CTFP,
    m.CTFP_Status,
    m.MaxMem_Value AS MaxMemory_MB,
    m.MinMem_Value AS MinMemory_MB,
    m.PhysicalMem_MB AS TotalPhysicalMemory_MB,
    m.TargetServerMem_MB,
    m.TotalServerMem_MB,
    m.MaxMemory_Status,
    m.PageLifeExpectancy,
    m.PLE_Status,
    m.MemoryPressure_Status,
    m.BufferCacheHitRatio,
    m.OfflineDatabases,
    m.OnlineUserDatabases,
    m.IFI_Value AS IFI_Enabled,
    m.IFI_Status,
    m.ServiceAcct AS SQLServiceAccount,
    m.ServiceStartMode,
    m.ServiceAccount_Type,
    m.FailedJobsLast24h,
    m.IndexJobCount AS IndexMaintenanceJobs,
    m.BackupJobCount,
    m.IndexMaint_Status,
    m.StartTime AS LastRestart,
    m.DaysSinceRestart,
    m.DatabasesNeedingBackup,
    m.LastFullBackup,
    m.xp_cmdshell_Status AS xp_cmdshell,
    m.AdHocDist_Status AS AdHocDistributedQueries,
    m.OleAuto_Status AS OleAutomation,
    m.RemoteAccess_Status AS RemoteAccess,
    m.CLR_Status AS CLR_Enabled,
    m.DAC_Status AS DAC,
    m.OptAdHoc_Value AS OptimizeAdHocWorkloads,
    m.BackupComp_Value AS BackupCompression,
    m.TempDBFiles AS TempDB_DataFiles,
    m.CPUCount AS LogicalCPUs,
    m.PhysicalCPUCount,
    m.HyperThreadRatio,
    m.TempDB_Status,
    m.MinDiskPct AS MinDiskFreePercent,
    m.DiskSpace_Status,
    m.UserConnections,
    m.BlockedSessionCount,
    m.IsAGEnabled,
    m.IsClustered,
    m.Collation,
    m.TotalWarnings,
    m.TotalCritical
FROM #ServerMetrics m;

-- ============================================================================
-- RESULT SET 2: DETAILED MULTI-ROW REPORT
-- ============================================================================

-- Database Backups Detail (exclude AG secondaries)
SELECT
    @@SERVERNAME AS ServerName,
    'Database Backups' AS ReportSection,
    d.name COLLATE DATABASE_DEFAULT AS ItemName,
    d.state_desc COLLATE DATABASE_DEFAULT AS Status,
    d.recovery_model_desc COLLATE DATABASE_DEFAULT AS RecoveryModel,
    CAST(mf.SizeMB / 1024.0 AS DECIMAL(18,2)) AS SizeGB,
    b.LastFullBackup_DT,
    b.LastDiffBackup_DT,
    b.LastLogBackup_DT,
    CAST(NULL AS VARCHAR(50)) AS LastFullBackup,
    CAST(NULL AS VARCHAR(50)) AS LastDiffBackup,
    CAST(NULL AS VARCHAR(50)) AS LastLogBackup,
    CAST(NULL AS VARCHAR(100)) AS Assessment
INTO #DatabaseBackups
FROM sys.databases d
LEFT JOIN (
    SELECT
        database_id,
        SUM(size) / 128.0 AS SizeMB   -- EXACT same unit SSMS uses
    FROM sys.master_files
    GROUP BY database_id
) mf ON d.database_id = mf.database_id
LEFT JOIN (
    SELECT
        database_name,
        MAX(CASE WHEN type = 'D' THEN backup_finish_date END) AS LastFullBackup_DT,
        MAX(CASE WHEN type = 'I' THEN backup_finish_date END) AS LastDiffBackup_DT,
        MAX(CASE WHEN type = 'L' THEN backup_finish_date END) AS LastLogBackup_DT
    FROM msdb.dbo.backupset
    GROUP BY database_name
) b ON d.name COLLATE DATABASE_DEFAULT = b.database_name COLLATE DATABASE_DEFAULT
LEFT JOIN sys.dm_hadr_database_replica_states hdrs
    ON d.database_id = hdrs.database_id
    AND hdrs.is_local = 1
WHERE d.database_id > 4
  AND (hdrs.database_id IS NULL OR hdrs.is_primary_replica = 1);

-- Format dates
UPDATE #DatabaseBackups
SET LastFullBackup = CONVERT(VARCHAR(50), LastFullBackup_DT, 120),
    LastDiffBackup = CONVERT(VARCHAR(50), LastDiffBackup_DT, 120),
    LastLogBackup = CONVERT(VARCHAR(50), LastLogBackup_DT, 120);

-- Calculate backup status
UPDATE #DatabaseBackups
SET Assessment = CASE
                       WHEN Status <> 'ONLINE' THEN 'Offline'
                       WHEN LastFullBackup_DT IS NULL THEN 'CRITICAL: Never Backed Up'
                       WHEN DATEDIFF(DAY, LastFullBackup_DT, GETDATE()) > 7 THEN 'WARNING: >7 days'
                       WHEN RecoveryModel IN ('FULL', 'BULK_LOGGED') AND LastLogBackup_DT IS NULL THEN 'WARNING: No Log Backups'
                       WHEN RecoveryModel IN ('FULL', 'BULK_LOGGED') AND DATEDIFF(HOUR, LastLogBackup_DT, GETDATE()) > 24 THEN 'WARNING: Log >24h'
                       ELSE 'OK'
                   END;

-- Failed Jobs Detail
SELECT
    @@SERVERNAME AS ServerName,
    'Failed Jobs' AS ReportSection,
    j.name COLLATE DATABASE_DEFAULT AS ItemName,
    h.run_status,
    h.run_date,
    h.run_time,
    c.name COLLATE DATABASE_DEFAULT AS JobCategory,
    CAST(NULL AS DECIMAL(10,2)) AS SizeGB,
    CAST(NULL AS VARCHAR(50)) AS LastFullBackup,
    CAST(NULL AS VARCHAR(50)) AS LastDiffBackup,
    CAST(NULL AS VARCHAR(50)) AS LastLogBackup,
    LEFT(h.message, 500) AS Assessment,
    CAST(NULL AS VARCHAR(50)) AS Status,
    CAST(NULL AS VARCHAR(50)) AS RecoveryModel
INTO #FailedJobs
FROM msdb.dbo.sysjobs j
INNER JOIN msdb.dbo.sysjobhistory h ON j.job_id = h.job_id
LEFT JOIN msdb.dbo.syscategories c ON j.category_id = c.category_id
WHERE h.run_status IN (0, 2, 3)
    AND h.step_id = 0
    AND h.run_date >= CONVERT(INT, CONVERT(VARCHAR(8), DATEADD(DAY, -7, GETDATE()), 112))
    AND j.enabled = 1;

-- Format failed jobs status and recovery model (category)
UPDATE #FailedJobs
SET Status = CASE run_status WHEN 0 THEN 'Failed' WHEN 2 THEN 'Retry' WHEN 3 THEN 'Canceled' END,
    RecoveryModel = JobCategory;

-- Format failed jobs run time
UPDATE #FailedJobs
SET LastFullBackup = CASE WHEN run_date > 0 THEN
                        STUFF(STUFF(CAST(run_date AS VARCHAR(8)), 7, 0, '-'), 5, 0, '-') + ' ' +
                        STUFF(STUFF(RIGHT('000000' + CAST(run_time AS VARCHAR(6)), 6), 5, 0, ':'), 3, 0, ':')
                    ELSE 'Unknown' END;

-- All Enabled Jobs
SELECT
    @@SERVERNAME AS ServerName,
    'All Enabled Jobs' AS ReportSection,
    j.name COLLATE DATABASE_DEFAULT AS ItemName,
    c.name COLLATE DATABASE_DEFAULT AS JobCategory,
    j.enabled,
    h.run_status,
    h.run_date,
    h.run_time,
    CAST(NULL AS DECIMAL(10,2)) AS SizeGB,
    CONVERT(VARCHAR(50), j.date_created, 120) AS LastFullBackup,
    CONVERT(VARCHAR(50), j.date_modified, 120) AS LastDiffBackup,
    CAST(NULL AS VARCHAR(50)) AS LastLogBackup,
    CAST(NULL AS VARCHAR(100)) AS Assessment,
    CAST(NULL AS VARCHAR(50)) AS Status,
    CAST(NULL AS VARCHAR(50)) AS RecoveryModel
INTO #AllJobs
FROM msdb.dbo.sysjobs j
LEFT JOIN msdb.dbo.syscategories c ON j.category_id = c.category_id
OUTER APPLY (
    SELECT TOP 1 run_status, run_date, run_time
    FROM msdb.dbo.sysjobhistory
    WHERE job_id = j.job_id AND step_id = 0
    ORDER BY run_date DESC, run_time DESC
) h
WHERE j.enabled = 1 AND c.name <> 'Report Server';

-- Format all jobs status and recovery model (category)
UPDATE #AllJobs
SET Status = CASE
                 WHEN run_status = 1 THEN 'Success'
                 WHEN run_status = 0 THEN 'Failed'
                 WHEN run_status = 2 THEN 'Retry'
                 WHEN run_status = 3 THEN 'Canceled'
                 WHEN run_date IS NULL THEN 'Never Run'
                 ELSE 'Unknown'
             END,
    RecoveryModel = JobCategory;

-- Format all jobs last run
UPDATE #AllJobs
SET LastLogBackup = CASE
                        WHEN run_date IS NULL THEN 'Never Run'
                        ELSE STUFF(STUFF(CAST(run_date AS VARCHAR(8)), 7, 0, '-'), 5, 0, '-') + ' ' +
                             STUFF(STUFF(RIGHT('000000' + CAST(run_time AS VARCHAR(6)), 6), 5, 0, ':'), 3, 0, ':')
                    END;

-- Format all jobs backup status
UPDATE #AllJobs
SET Assessment = CASE
                       WHEN run_status = 1 THEN 'OK: Last run succeeded'
                       WHEN run_status = 0 THEN 'CRITICAL: Last run failed'
                       WHEN run_status = 3 THEN 'WARNING: Last run canceled'
                       WHEN run_date IS NULL THEN 'INFO: Never executed'
                       ELSE 'WARNING: Check job history'
                   END;

-- Disk Space per Drive
SELECT
    @@SERVERNAME AS ServerName,
    'Disk Space' AS ReportSection,
    vs.volume_mount_point COLLATE DATABASE_DEFAULT AS ItemName,
    vs.logical_volume_name COLLATE DATABASE_DEFAULT AS Status,
    vs.total_bytes,
    vs.available_bytes,
    CAST(NULL AS VARCHAR(50)) AS RecoveryModel,
    CAST(vs.total_bytes/1073741824.0 AS DECIMAL(10,2)) AS SizeGB,
    CAST(NULL AS VARCHAR(50)) AS LastFullBackup,
    CAST(NULL AS VARCHAR(50)) AS LastDiffBackup,
    CAST(NULL AS VARCHAR(50)) AS LastLogBackup,
    CAST(NULL AS VARCHAR(200)) AS Assessment
INTO #DiskSpace
FROM (
    SELECT DISTINCT volume_mount_point, logical_volume_name, total_bytes, available_bytes
    FROM sys.master_files mf
    CROSS APPLY sys.dm_os_volume_stats(mf.database_id, mf.file_id) vs
) vs;

-- Format disk space available
UPDATE #DiskSpace
SET LastLogBackup = CAST(CAST(available_bytes/1073741824.0 AS DECIMAL(10,2)) AS VARCHAR(20)) + ' GB';

-- Format disk space status
UPDATE #DiskSpace
SET Assessment = CASE
                       WHEN CAST((CAST(available_bytes AS BIGINT) * 100) / CAST(total_bytes AS FLOAT) AS DECIMAL(5,2)) < 10 THEN 'CRITICAL: <10%'
                       WHEN CAST((CAST(available_bytes AS BIGINT) * 100) / CAST(total_bytes AS FLOAT) AS DECIMAL(5,2)) < 20 THEN 'WARNING: <20%'
                       ELSE 'OK'
                   END + ' (' + CAST(CAST((CAST(available_bytes AS BIGINT) * 100) / CAST(total_bytes AS FLOAT) AS DECIMAL(5,2)) AS VARCHAR(10)) + '% free)';

-- SysAdmin Logins
SELECT
    @@SERVERNAME AS ServerName,
    'SysAdmin Logins' AS ReportSection,
    p.name COLLATE DATABASE_DEFAULT AS ItemName,
    p.type_desc COLLATE DATABASE_DEFAULT AS Status,
    p.is_disabled,
    CAST(NULL AS DECIMAL(10,2)) AS SizeGB,
    CONVERT(VARCHAR(50), p.create_date, 120) AS LastFullBackup,
    CONVERT(VARCHAR(50), p.modify_date, 120) AS LastDiffBackup,
    CAST(NULL AS VARCHAR(50)) AS LastLogBackup,
    CAST(NULL AS VARCHAR(100)) AS Assessment,
    CAST(NULL AS VARCHAR(50)) AS RecoveryModel
INTO #SysAdminLogins
FROM sys.server_principals p
WHERE p.type IN ('S', 'U', 'G') AND p.is_disabled = 0
    AND IS_SRVROLEMEMBER('sysadmin', p.name) = 1;

-- Format sysadmin logins recovery model
UPDATE #SysAdminLogins
SET RecoveryModel = CASE WHEN is_disabled = 0 THEN 'Active' ELSE 'Disabled' END;

-- Format sysadmin logins backup status
UPDATE #SysAdminLogins
SET Assessment = CASE
                       WHEN ItemName = 'sa' AND is_disabled = 0 THEN 'WARNING: sa account enabled'
                       WHEN Status = 'SQL_LOGIN' THEN 'INFO: SQL Authentication'
                       ELSE 'OK'
                   END;

-- Database File Growth Issues
SELECT
    @@SERVERNAME AS ServerName,
    'File Growth Issues' AS ReportSection,
    DB_NAME(mf.database_id) COLLATE DATABASE_DEFAULT AS ItemName,
    mf.name COLLATE DATABASE_DEFAULT AS Status,
    mf.type_desc COLLATE DATABASE_DEFAULT AS RecoveryModel,
    CAST(CAST(mf.size AS BIGINT) * 8 / 1024.0 / 1024 AS DECIMAL(10,2)) AS SizeGB,
    mf.is_percent_growth,
    mf.growth,
    CAST(NULL AS VARCHAR(50)) AS LastFullBackup,
    CAST(NULL AS VARCHAR(50)) AS LastDiffBackup,
    CAST(NULL AS VARCHAR(50)) AS LastLogBackup,
    CAST(NULL AS VARCHAR(100)) AS Assessment
INTO #FileGrowth
FROM sys.master_files mf
WHERE mf.database_id > 4
    AND (
        (mf.is_percent_growth = 1 AND mf.size > 128000)
        OR (mf.is_percent_growth = 0 AND mf.growth * 8 < 64)
        OR (mf.is_percent_growth = 0 AND mf.growth = 1)
    );

-- Format file growth display
UPDATE #FileGrowth
SET LastLogBackup = CASE WHEN is_percent_growth = 1 THEN CAST(growth AS VARCHAR(10)) + '%'
                         ELSE CAST(growth * 8 / 1024 AS VARCHAR(10)) + ' MB' END;

-- Format file growth backup status
UPDATE #FileGrowth
SET Assessment = CASE
                       WHEN is_percent_growth = 1 AND SizeGB > 1000 THEN 'WARNING: Large file with % growth'
                       WHEN is_percent_growth = 0 AND growth = 1 THEN 'CRITICAL: 8KB growth'
                       WHEN is_percent_growth = 0 AND growth * 8 < 64 THEN 'WARNING: Growth <64MB'
                       ELSE 'INFO: Review growth setting'
                   END;

-- TempDB Files
SELECT
    @@SERVERNAME AS ServerName,
    'TempDB Files' AS ReportSection,
    mf.name COLLATE DATABASE_DEFAULT AS ItemName,
    mf.type_desc COLLATE DATABASE_DEFAULT AS Status,
    mf.physical_name COLLATE DATABASE_DEFAULT AS RecoveryModel,
    CAST(CAST(mf.size AS BIGINT) * 8 / 1024.0 / 1024 AS DECIMAL(10,2)) AS SizeGB,
    mf.is_percent_growth,
    mf.growth,
    mf.file_id,
    CAST(mf.size AS BIGINT) AS size_pages,
    CAST(NULL AS VARCHAR(50)) AS LastFullBackup,
    CAST(NULL AS VARCHAR(50)) AS LastDiffBackup,
    CAST(NULL AS VARCHAR(50)) AS LastLogBackup,
    CAST(NULL AS VARCHAR(100)) AS Assessment
INTO #TempDBFiles
FROM sys.master_files mf
WHERE mf.database_id = 2;

-- Format TempDB files growth
UPDATE #TempDBFiles
SET LastLogBackup = CASE WHEN is_percent_growth = 1 THEN CAST(growth AS VARCHAR(10)) + '%'
                         ELSE CAST(growth * 8 / 1024 AS VARCHAR(10)) + ' MB' END;

-- Format TempDB files backup status
UPDATE #TempDBFiles
SET Assessment = CASE
                       WHEN Status = 'ROWS' AND EXISTS (
                           SELECT 1 FROM sys.master_files mf2
                           WHERE mf2.database_id = 2 AND mf2.type = 0 AND mf2.file_id <> file_id
                           AND mf2.size <> size_pages
                       ) THEN 'WARNING: Unequal file sizes'
                       ELSE 'OK'
                   END;

-- Top 10 Largest Databases
SELECT
    @@SERVERNAME AS ServerName,
    'Largest Databases' AS ReportSection,
    db.name COLLATE DATABASE_DEFAULT AS ItemName,
    db.state_desc COLLATE DATABASE_DEFAULT AS Status,
    db.recovery_model_desc COLLATE DATABASE_DEFAULT AS RecoveryModel,
    db.SizeGB,
    db.compatibility_level,
    CONVERT(VARCHAR(50), db.create_date, 120) AS LastFullBackup,
    CAST(NULL AS VARCHAR(50)) AS LastDiffBackup,
    CAST(NULL AS VARCHAR(100)) AS LastLogBackup,
    CAST(NULL AS VARCHAR(100)) AS Assessment
INTO #LargestDBs
FROM (
    SELECT TOP 10
        d.name, d.state_desc, d.recovery_model_desc,
        CAST(SUM(CAST(mf.size AS BIGINT)) * 8 / 1024.0 / 1024 AS DECIMAL(10,2)) AS SizeGB,
        d.create_date, d.compatibility_level
    FROM sys.databases d
    LEFT JOIN sys.master_files mf ON d.database_id = mf.database_id
    WHERE d.database_id > 4
    GROUP BY d.name, d.state_desc, d.recovery_model_desc, d.create_date, d.compatibility_level
    ORDER BY SUM(CAST(mf.size AS BIGINT)) DESC
) db;

-- Format largest databases compat level
UPDATE #LargestDBs
SET LastLogBackup = 'Compatibility: ' + CAST(compatibility_level AS VARCHAR(10));

-- Format largest databases backup status
UPDATE #LargestDBs
SET Assessment = CASE
                       WHEN compatibility_level < 150 THEN 'INFO: Consider upgrading compatibility level'
                       ELSE 'OK'
                   END;

-- Active SQL Logins with Password Policy
SELECT
    @@SERVERNAME AS ServerName,
    'SQL Logins' AS ReportSection,
    sl.name COLLATE DATABASE_DEFAULT AS ItemName,
    'SQL_LOGIN' AS Status,
    sl.is_disabled,
    sl.is_policy_checked,
    sl.is_expiration_checked,
    CAST(NULL AS DECIMAL(10,2)) AS SizeGB,
    CONVERT(VARCHAR(50), sl.create_date, 120) AS LastFullBackup,
    CONVERT(VARCHAR(50), sl.modify_date, 120) AS LastDiffBackup,
    CAST(NULL AS VARCHAR(100)) AS LastLogBackup,
    CAST(NULL AS VARCHAR(100)) AS Assessment,
    CAST(NULL AS VARCHAR(50)) AS RecoveryModel
INTO #SQLLogins
FROM sys.sql_logins sl
WHERE sl.is_disabled = 0
    AND sl.name NOT IN ('##MS_PolicyEventProcessingLogin##', '##MS_PolicyTsqlExecutionLogin##');

-- Format SQL logins recovery model
UPDATE #SQLLogins
SET RecoveryModel = CASE WHEN is_disabled = 0 THEN 'Active' ELSE 'Disabled' END;

-- Format SQL logins policy info
UPDATE #SQLLogins
SET LastLogBackup = 'Policy: ' + CASE WHEN is_policy_checked = 1 THEN 'Yes' ELSE 'No' END +
                    ', Expiration: ' + CASE WHEN is_expiration_checked = 1 THEN 'Yes' ELSE 'No' END;

-- Format SQL logins backup status
UPDATE #SQLLogins
SET Assessment = CASE
                       WHEN is_policy_checked = 0 THEN 'WARNING: Password policy not enforced'
                       WHEN is_expiration_checked = 0 THEN 'INFO: Password expiration disabled'
                       ELSE 'OK'
                   END;

-- Combine all detail reports
SELECT ServerName, ReportSection, ItemName, Status, RecoveryModel, SizeGB,
       LastFullBackup AS Detail1,
       LastDiffBackup AS Detail2,
       LastLogBackup AS Detail3,
       Assessment
INTO #FINAL
FROM #DatabaseBackups
UNION ALL
SELECT ServerName, ReportSection, ItemName, Status, RecoveryModel, SizeGB,
       LastFullBackup AS Detail1,
       LastDiffBackup AS Detail2,
       LastLogBackup AS Detail3,
       Assessment
FROM #FailedJobs
UNION ALL
SELECT ServerName, ReportSection, ItemName, Status, RecoveryModel, SizeGB,
       LastFullBackup AS Detail1,
       LastDiffBackup AS Detail2,
       LastLogBackup AS Detail3,
       Assessment
FROM #AllJobs
UNION ALL
SELECT ServerName, ReportSection, ItemName, Status, RecoveryModel, SizeGB,
       LastFullBackup AS Detail1,
       LastDiffBackup AS Detail2,
       LastLogBackup AS Detail3,
       Assessment
FROM #DiskSpace
UNION ALL
SELECT ServerName, ReportSection, ItemName, Status, RecoveryModel, SizeGB,
       LastFullBackup AS Detail1,
       LastDiffBackup AS Detail2,
       LastLogBackup AS Detail3,
       Assessment
FROM #SysAdminLogins
UNION ALL
SELECT ServerName, ReportSection, ItemName, Status, RecoveryModel, SizeGB,
       LastFullBackup AS Detail1,
       LastDiffBackup AS Detail2,
       LastLogBackup AS Detail3,
       Assessment
FROM #FileGrowth
UNION ALL
SELECT ServerName, ReportSection, ItemName, Status, RecoveryModel, SizeGB,
       LastFullBackup AS Detail1,
       LastDiffBackup AS Detail2,
       LastLogBackup AS Detail3,
       Assessment
FROM #TempDBFiles
UNION ALL
SELECT ServerName, ReportSection, ItemName, Status, RecoveryModel, SizeGB,
       LastFullBackup AS Detail1,
       LastDiffBackup AS Detail2,
       LastLogBackup AS Detail3,
       Assessment
FROM #LargestDBs
UNION ALL
SELECT ServerName, ReportSection, ItemName, Status, RecoveryModel, SizeGB,
       LastFullBackup AS Detail1,
       LastDiffBackup AS Detail2,
       LastLogBackup AS Detail3,
       Assessment
FROM #SQLLogins
ORDER BY ReportSection, ItemName;

--Display results
SELECT * FROM #FINAL WHERE Assessment NOT LIKE 'OK%' 

-- Clean up
DROP TABLE IF EXISTS #ServerMetrics, #DatabaseBackups, #FailedJobs, #AllJobs,
                     #DiskSpace, #SysAdminLogins, #FileGrowth, #TempDBFiles,
                     #LargestDBs, #SQLLogins, #FINAL;

SET NOCOUNT OFF;
