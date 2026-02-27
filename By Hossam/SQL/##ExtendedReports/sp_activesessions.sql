USE [master]
GO
IF OBJECT_ID('tempdb..##sp_activesessions') IS NULL EXEC ('CREATE PROCEDURE [##sp_activesessions] AS RETURN')
GO

ALTER PROCEDURE [##sp_activesessions] 
    @LoginName NVARCHAR(200) = NULL,
    @Host NVARCHAR(200) = NULL,
    @ElapsedTime INT = NULL,
    @BlockedOnly INT = NULL,
    @SessionId INT = NULL,
    @SQLText NVARCHAR(1000) = NULL,
    @DatabaseName NVARCHAR(200) = NULL,
    @All INT = 0
AS
BEGIN
    SET NOCOUNT ON;

    -- Active sessions query
    SELECT 
        req.session_id AS SPID,
        req.total_elapsed_time AS ElapsedTime,
        req.last_wait_type AS Wait,
        req.wait_time,
        x2.event_info AS BatchSQL,
        req.cpu_time AS CPU,
        req.logical_reads AS LogicalReads,
        req.reads,
        req.writes,
        ses.host_name AS Host,
        DB_NAME(req.database_id) AS DBName,
        req.blocking_session_id AS BlockedBy,
        ISNULL(x.event_info, '') AS BlockingSQL,
        req.status,
        req.percent_complete,
        ses.login_name,
        SUBSTRING(sqltext.text, 
                  (req.statement_start_offset / 2) + 1, 
                  ((CASE req.statement_end_offset WHEN -1 THEN DATALENGTH(sqltext.text) ELSE req.statement_end_offset END - req.statement_start_offset) / 2) + 1) AS Statement,
        sqltext.text AS FullSQL,
        OBJECT_NAME(sqltext.objectid, req.database_id) AS ExecutedObject,
        'KILL ' + CAST(req.session_id AS VARCHAR) AS KillCMD
    FROM sys.dm_exec_requests req
    LEFT JOIN sys.dm_exec_sessions ses ON ses.session_id = req.session_id
    CROSS APPLY sys.dm_exec_sql_text(req.sql_handle) AS sqltext
    OUTER APPLY sys.dm_exec_input_buffer(req.session_id, NULL) x2
    OUTER APPLY sys.dm_exec_input_buffer(req.blocking_session_id, NULL) x
    WHERE req.session_id <> @@SPID
        AND (req.last_wait_type NOT IN (N'BROKER_RECEIVE_WAITFOR', N'WAITFOR', N'TRACEWRITE', N'SP_SERVER_DIAGNOSTICS_SLEEP') OR @All = 1)
        AND (ses.login_name LIKE '%' + @LoginName + '%' OR @LoginName IS NULL)
        AND (@Host IS NULL OR ses.host_name IN (SELECT LTRIM(RTRIM(value)) FROM STRING_SPLIT(@Host, ',')))
        AND (req.total_elapsed_time >= @ElapsedTime OR @ElapsedTime IS NULL)
        AND (ses.session_id = @SessionId OR @SessionId IS NULL)
        AND (req.blocking_session_id >= @BlockedOnly OR @BlockedOnly IS NULL)
        AND (x2.event_info LIKE '%' + @SQLText + '%' OR x.event_info LIKE '%' + @SQLText + '%' OR sqltext.text LIKE '%' + @SQLText + '%' OR @SQLText IS NULL)
        AND (DB_NAME(req.database_id) LIKE '%' + @DatabaseName + '%' OR @DatabaseName IS NULL)
    ORDER BY req.total_elapsed_time DESC;

    -- Wait types summary
    SELECT 
        req.last_wait_type, 
        SUM(req.wait_time) AS TotalWait
    FROM sys.dm_exec_requests req
    LEFT JOIN sys.dm_exec_sessions ses ON ses.session_id = req.session_id
    CROSS APPLY sys.dm_exec_sql_text(req.sql_handle) AS sqltext
    OUTER APPLY sys.dm_exec_input_buffer(req.session_id, NULL) x2
    OUTER APPLY sys.dm_exec_input_buffer(req.blocking_session_id, NULL) x
    WHERE req.session_id <> @@SPID 
        AND (req.last_wait_type NOT IN (N'BROKER_RECEIVE_WAITFOR', N'WAITFOR', N'TRACEWRITE') OR @All = 1)
        AND (ses.login_name LIKE '%' + @LoginName + '%' OR @LoginName IS NULL)
        AND (@Host IS NULL OR ses.host_name IN (SELECT LTRIM(RTRIM(value)) FROM STRING_SPLIT(@Host, ',')))
        AND (req.total_elapsed_time >= @ElapsedTime OR @ElapsedTime IS NULL)
        AND (ses.session_id = @SessionId OR @SessionId IS NULL)
        AND (req.blocking_session_id >= @BlockedOnly OR @BlockedOnly IS NULL)
        AND (x2.event_info LIKE '%' + @SQLText + '%' OR x.event_info LIKE '%' + @SQLText + '%' OR sqltext.text LIKE '%' + @SQLText + '%' OR @SQLText IS NULL)
        AND (DB_NAME(req.database_id) LIKE '%' + @DatabaseName + '%' OR @DatabaseName IS NULL)
    GROUP BY req.last_wait_type
    ORDER BY SUM(req.wait_time) DESC;

    -- Blocking sessions
    IF EXISTS (SELECT 1 FROM sys.dm_exec_requests WHERE blocking_session_id > 0)
    BEGIN
        SELECT DISTINCT
            a.session_id AS Blockers,
            a.total_elapsed_time AS ElapsedTime,
            c.host_name AS Host,
            c.login_name AS Login,
            c.program_name,
            d.cmd,
            c.login_time,
            c.last_request_end_time,
            SUBSTRING(sqltext.text, 
                      (req.statement_start_offset / 2) + 1, 
                      ((CASE req.statement_end_offset WHEN -1 THEN DATALENGTH(sqltext.text) ELSE req.statement_end_offset END - req.statement_start_offset) / 2) + 1) AS Statement,
            sqltext.text AS FullSQL,
            OBJECT_NAME(sqltext.objectid, req.database_id) AS ExecutedObject
        FROM sys.dm_exec_requests a
        LEFT JOIN sys.sysprocesses d ON a.session_id = d.spid
        LEFT JOIN sys.dm_exec_sessions c ON a.session_id = c.session_id
        LEFT JOIN sys.dm_exec_requests req ON a.session_id = req.blocking_session_id
        OUTER APPLY sys.dm_exec_sql_text(a.sql_handle) AS sqltext
        OUTER APPLY sys.dm_exec_input_buffer(req.session_id, NULL) b
        WHERE req.blocking_session_id IS NOT NULL;
    END;
END;
GO

