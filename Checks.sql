drop VIEW if exists jobs_report;
go
create view jobs_report as
SELECT 
    j.name AS JobName,
	c.name AS Category,
    CASE 
        WHEN h.run_date IS NULL OR h.run_date = 0 THEN 'Unknown'
        WHEN h.run_status = 1 THEN 'Success'
        WHEN h.run_status = 2 THEN 'Retry'
        WHEN h.run_status = 3 THEN 'Canceled'
        ELSE 'Failed'
    END AS LastStatus,
    CASE 
        WHEN h.run_date IS NULL OR h.run_date = 0 THEN 'never'
        ELSE 
            STUFF(
                STUFF(
                    CONVERT(varchar(8), h.run_date),
                    5, 0, '-'
                ),
                8, 0, '-'
            ) + ' ' +
            STUFF(
                STUFF(
                    RIGHT('000000' + CONVERT(varchar(6), h.run_time), 6),
                    3, 0, ':' 
                ),
                6, 0, ':'
            )
    END AS LastRun,
    CASE 
        WHEN h.run_date IS NULL OR h.run_date = 0 THEN NULL
        ELSE
            STUFF(
                STUFF(
                    RIGHT('000000' + CONVERT(varchar(6), h.run_duration), 6),
                    3, 0, ':' 
                ),
                6, 0, ':'
            )
    END AS Duration
--into ##jobs
FROM msdb.dbo.sysjobs AS j
	LEFT JOIN msdb.dbo.syscategories c ON j.category_id = c.category_id
OUTER APPLY (
    SELECT TOP 1 
        run_status,
        run_date,
        run_time,
        run_duration
    FROM msdb.dbo.sysjobhistory
    WHERE job_id = j.job_id
      AND step_id = 0
    ORDER BY run_date DESC, run_time DESC
) AS h
WHERE j.enabled = 1
	AND c.name <> 'Report Server'
--ORDER BY LastRun, 2, 1;

go

drop VIEW if exists database_report;
GO

CREATE VIEW database_report as
SELECT
    d.name AS DatabaseName,
    d.state_desc AS Status
FROM sys.databases d
LEFT JOIN sys.dm_hadr_database_replica_states hars
    ON d.database_id = hars.database_id
WHERE hars.database_id IS NULL  -- Only databases not in AG
go

drop VIEW if exists  disk_report;
go

create view disk_report as
SELECT 
    vs.volume_mount_point   AS Drive,
    vs.logical_volume_name  AS VolumeName,
    CASE 
        WHEN vs.available_bytes >= 1073741824 
            THEN CONCAT(CAST(vs.available_bytes/1073741824.0 AS DECIMAL(10,2)), ' GB')
        ELSE 
            CONCAT(CAST(vs.available_bytes/1048576.0 AS DECIMAL(10,2)), ' MB')
    END AS FreeSpace,
    CASE 
        WHEN vs.total_bytes >= 1073741824 
            THEN CONCAT(CAST(vs.total_bytes/1073741824.0 AS DECIMAL(10,2)), ' GB')
        ELSE 
            CONCAT(CAST(vs.total_bytes/1048576.0 AS DECIMAL(10,2)), ' MB')
    END AS TotalSpace,
    CAST(vs.available_bytes * 100.0 / vs.total_bytes AS DECIMAL(5,2)) AS FreePercent,
    CASE 
        WHEN CAST(vs.available_bytes * 100.0 / vs.total_bytes AS DECIMAL(5,2)) < 15.00 
            THEN N'⚠️ Below 15%' 
        ELSE 'OK' 
    END AS Status
--INTO ##DISKS
FROM sys.master_files AS mf
CROSS APPLY sys.dm_os_volume_stats(mf.database_id, mf.file_id) AS vs
GROUP BY 
    vs.volume_mount_point,
    vs.logical_volume_name,
    vs.available_bytes,
    vs.total_bytes
--ORDER BY FreePercent;
go

DROP VIEW IF EXISTS locking_report;
go

create view locking_report as 
SELECT
    r.session_id          AS BlockedSessionID,
    r.blocking_session_id AS BlockingSessionID,
    r.wait_type,
    r.wait_time,
    r.last_wait_type,
    DB_NAME(r.database_id) AS DatabaseName,
    bs.login_name        AS BlockedLogin,
    bs.host_name         AS BlockedHost,
    bs.program_name      AS BlockedProgram,
    st_blocked.text      AS BlockedSQL,
    blocking_s.login_name   AS BlockingLogin,
    blocking_s.host_name    AS BlockingHost,
    blocking_s.program_name AS BlockingProgram,
    st_blocking.text     AS BlockingSQL,
    l.request_mode       AS LockMode,
    l.resource_type      AS ResourceType,
    l.resource_associated_entity_id AS ResourceID
FROM sys.dm_exec_requests r
	JOIN sys.dm_exec_sessions bs ON r.session_id = bs.session_id
	LEFT JOIN sys.dm_exec_sessions blocking_s ON r.blocking_session_id = blocking_s.session_id
	CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) st_blocked
	OUTER APPLY (
		SELECT TOP 1 st.text
		FROM sys.dm_exec_requests r2
		CROSS APPLY sys.dm_exec_sql_text(r2.sql_handle) st
		WHERE r2.session_id = r.blocking_session_id
	) st_blocking
	LEFT JOIN sys.dm_tran_locks l ON l.request_session_id = r.session_id
WHERE r.blocking_session_id <> 0  -- only sessions that are blocked by another session
/*
exec sp_send_report @mailto= 'someone'--'h.abudayefhassan@mobily.com.sa;e.mekala@mobily.com.sa'
,@subject='SQL Databases Status '
,@table = '##DISKS'
,@report = 'SQL Databases Status'
*/
go

DROP VIEW IF EXISTS ag_replicas_report;
go

CREATE VIEW ag_replicas_report AS
SELECT 
    ag.name AS AGGroupName,
    l.dns_name AS Listener,
    ar.replica_server_name AS ReplicaServer,
    ar.availability_mode_desc AS CommitMode,  -- Synchronous or Asynchronous commit
    ars.role_desc AS Role,                    -- Primary or Secondary
    ars.connected_state_desc AS ReplicaStatus -- Replica connection status (e.g., CONNECTED)
FROM sys.dm_hadr_availability_replica_states AS ars
	INNER JOIN sys.availability_replicas AS ar     ON ars.replica_id = ar.replica_id
	INNER JOIN sys.availability_groups AS ag    ON ar.group_id = ag.group_id
	LEFT JOIN sys.availability_group_listeners AS l    ON ag.group_id = l.group_id
--ORDER BY ag.name, ar.replica_server_name;
GO

DROP VIEW IF EXISTS ag_dbs_report
go
CREATE VIEW ag_dbs_report AS
SELECT DISTINCT
    d.name AS DatabaseName,
    --ar.replica_server_name AS CurrentNode,
    CASE WHEN dbs.synchronization_state_desc <> 'SYNCHRONIZED' 
		THEN dbs.synchronization_state_desc +' at '+ar.replica_server_name 
		ELSE dbs.synchronization_state_desc END AS SyncState,
    dbs.synchronization_health_desc AS SyncHealth
FROM sys.dm_hadr_database_replica_states AS dbs
	INNER JOIN sys.databases AS d ON dbs.database_id = d.database_id
	INNER JOIN sys.availability_replicas AS ar ON dbs.replica_id = ar.replica_id
--ORDER BY d.name;
go

exec sp_send_reports
@mailto= 'h.abudayefhassan@mobily.com.sa'--;e.mekala@mobily.com.sa'
,@subject = 'SQL Checks'
,@titles = 'SQL Jobs,Locks and Blocks,Standalone Database Status,AG Replica Status,AG Database Status,Disk Space'
,@objects = 'jobs_report,locking_report,database_report,ag_replicas_report,ag_dbs_report,disk_report'