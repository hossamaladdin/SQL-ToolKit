SELECT
    ag.name AS [AG Name],
    ar.replica_server_name AS [Replica],
    drs.database_id,
    db_name(drs.database_id) AS [Database],
    drs.is_primary_replica,
    drs.synchronization_state_desc,
    drs.synchronization_health_desc,
    drs.redo_queue_size / 1024.0 AS [Redo Queue (MB)],
    drs.redo_rate / 1024.0 AS [Redo Rate (MB/sec)],
    drs.log_send_queue_size / 1024.0 AS [Log Send Queue (MB)],
    drs.log_send_rate / 1024.0 AS [Log Send Rate (MB/sec)],
    drs.last_commit_time
FROM sys.dm_hadr_database_replica_states AS drs
JOIN sys.availability_groups AS ag ON drs.group_id = ag.group_id
JOIN sys.availability_replicas AS ar ON drs.replica_id = ar.replica_id
where synchronization_state_desc not in ('SYNCHRONIZED','SYNCHRONIZING')
	--db_name(drs.database_id) = 'EVVSJournalVaultStore2_9'
ORDER BY [Redo Queue (MB)] DESC;

--ALTER DATABASE EVVSJournalVaultStore2_9 SET HADR RESUME;

--SELECT name, state_desc FROM sys.databases WHERE name = 'EVVSJournalVaultStore2_9';

SELECT session_id,start_time,status,percent_complete, estimated_completion_time, command 
FROM sys.dm_exec_requests 
WHERE command = 'DB STARTUP'
and wait_type is null;

SELECT * FROM sys.dm_io_virtual_file_stats(
   DB_ID('EVVSJournalVaultStore2_9'), NULL);