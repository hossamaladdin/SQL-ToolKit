USE [master]
GO

/****** Object:  StoredProcedure [dbo].[sp_activesessions] ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

/*
    sp_activesessions - point-in-time view of what sessions are doing, what they wait on,
    and who blocks whom. Returns three result sets: sessions, wait summary, blockers.

    Requires VIEW SERVER STATE. Requires SQL Server 2016+ (STRING_SPLIT, CREATE OR ALTER).

    Drives from sys.dm_exec_sessions, not sys.dm_exec_requests, so a sleeping session
    holding an open transaction still shows up. That is the most common blocking root
    cause and it has no row in dm_exec_requests.

    By default returns sessions with an active request, sessions holding an open
    transaction, and sessions blocking someone. @All = 1 adds plain idle sessions and the
    background wait types. A session that blocks a filtered session is always included and
    flagged IsMatch = 0, even when it does not match the filters itself.

    EXEC sp_activesessions;                       -- active work plus anything blocking it
    EXEC sp_activesessions @BlockedOnly = 1;      -- blocked sessions plus their blockers
    EXEC sp_activesessions @ElapsedTime = 60000;  -- running over 60s, plus their blockers
    EXEC sp_activesessions @Host = 'app01,app02';
    EXEC sp_activesessions @All = 1;              -- everything
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_activesessions]
    @LoginName    NVARCHAR(200)  = NULL,
    @Host         NVARCHAR(200)  = NULL,
    @ElapsedTime  INT            = NULL,
    @BlockedOnly  INT            = NULL,
    @SessionId    INT            = NULL,
    @SQLText      NVARCHAR(1000) = NULL,
    @DatabaseName NVARCHAR(200)  = NULL,
    @All          INT            = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Sessions TABLE
    (
        SPID             INT            NOT NULL PRIMARY KEY,
        IsMatch          BIT            NOT NULL,
        IsHeadBlocker    BIT            NOT NULL,
        BlockedBy        INT            NULL,
        BlockedSessions  INT            NOT NULL,
        Status           NVARCHAR(30)   NULL,
        OpenTrans        INT            NULL,
        ElapsedTimeMs    INT            NULL,
        SecondsIdle      INT            NULL,
        Wait             NVARCHAR(60)   NULL,
        WaitTimeMs       BIGINT         NULL,
        WaitResource     NVARCHAR(2048) NULL,
        CPU              INT            NULL,
        LogicalReads     BIGINT         NULL,
        Reads            BIGINT         NULL,
        Writes           BIGINT         NULL,
        MemoryKB         BIGINT         NULL,
        DBName           NVARCHAR(128)  NULL,
        Login            NVARCHAR(128)  NULL,
        Host             NVARCHAR(128)  NULL,
        ProgramName      NVARCHAR(128)  NULL,
        ClientNetAddress VARCHAR(48)    NULL,
        Command          NVARCHAR(32)   NULL,
        PercentComplete  REAL           NULL,
        LoginTime        DATETIME       NULL,
        LastRequestEnd   DATETIME       NULL,
        ExecutedObject   NVARCHAR(128)  NULL,
        StatementSQL     NVARCHAR(MAX)  NULL,
        FullSQL          NVARCHAR(MAX)  NULL,
        BatchSQL         NVARCHAR(MAX)  NULL,
        KillCMD          VARCHAR(20)    NULL
    );

    -- Pass 0 captures sessions matching the filters. Later passes walk up the blocking
    -- chain so a blocker excluded by the filters is still reported.
    DECLARE @Pass INT = 0, @Added INT = 1;

    WHILE @Added > 0 AND @Pass < 10
    BEGIN
        INSERT INTO @Sessions
        (
            SPID, IsMatch, IsHeadBlocker, BlockedBy, BlockedSessions, Status, OpenTrans,
            ElapsedTimeMs, SecondsIdle, Wait, WaitTimeMs, WaitResource, CPU, LogicalReads,
            Reads, Writes, MemoryKB, DBName, Login, Host, ProgramName, ClientNetAddress,
            Command, PercentComplete, LoginTime, LastRequestEnd, ExecutedObject,
            StatementSQL, FullSQL, BatchSQL, KillCMD
        )
        SELECT
            s.session_id,
            CONVERT(BIT, CASE WHEN @Pass = 0 THEN 1 ELSE 0 END),
            bb.is_head_blocker,
            bb.blocked_by,
            blk.victim_count,
            ISNULL(r.status, s.status),
            ISNULL(r.open_transaction_count, s.open_transaction_count),
            r.total_elapsed_time,
            -- only meaningful with no active request; clamped so a session that has never
            -- run a batch cannot overflow the DATEDIFF
            CASE WHEN r.session_id IS NULL
                 THEN DATEDIFF(SECOND,
                               CASE WHEN s.last_request_end_time < s.login_time
                                    THEN s.login_time ELSE s.last_request_end_time END,
                               GETDATE())
            END,
            COALESCE(w.wait_type, r.last_wait_type),
            COALESCE(w.wait_duration_ms, r.wait_time),
            w.resource_description,
            ISNULL(r.cpu_time, s.cpu_time),
            ISNULL(r.logical_reads, s.logical_reads),
            ISNULL(r.reads, s.reads),
            ISNULL(r.writes, s.writes),
            CONVERT(BIGINT, s.memory_usage) * 8,                  -- 8-KB pages to KB
            DB_NAME(COALESCE(r.database_id, s.database_id)),
            s.login_name,
            s.host_name,
            s.program_name,
            conn.client_net_address,
            r.command,
            r.percent_complete,
            s.login_time,
            s.last_request_end_time,
            OBJECT_NAME(st.objectid, st.dbid),                    -- st.dbid, not r.database_id
            SUBSTRING(st.text,
                      (r.statement_start_offset / 2) + 1,
                      ((CASE r.statement_end_offset
                             WHEN -1 THEN DATALENGTH(st.text)
                             ELSE r.statement_end_offset
                        END - r.statement_start_offset) / 2) + 1),
            st.text,
            ib.event_info,
            'KILL ' + CONVERT(VARCHAR(11), s.session_id)
        FROM sys.dm_exec_sessions AS s
        LEFT JOIN sys.dm_exec_requests AS r
               ON r.session_id = s.session_id
        -- longest current wait only; TOP 1 stops parallel tasks fanning the session out
        OUTER APPLY
        (
            SELECT TOP (1) wt.wait_type, wt.wait_duration_ms,
                           wt.resource_description, wt.blocking_session_id
            FROM sys.dm_os_waiting_tasks AS wt
            WHERE wt.session_id = s.session_id
            ORDER BY wt.wait_duration_ms DESC
        ) AS w
        -- one row per session even when the client uses MARS
        OUTER APPLY
        (
            SELECT TOP (1) c.client_net_address
            FROM sys.dm_exec_connections AS c
            WHERE c.session_id = s.session_id
            ORDER BY CASE WHEN c.parent_connection_id IS NULL THEN 0 ELSE 1 END, c.connect_time
        ) AS conn
        CROSS APPLY
        (
            SELECT COUNT(*) AS victim_count
            FROM sys.dm_exec_requests AS br
            WHERE br.blocking_session_id = s.session_id
              AND br.session_id <> s.session_id
        ) AS blk
        CROSS APPLY
        (
            SELECT
                NULLIF(COALESCE(NULLIF(r.blocking_session_id, 0), w.blocking_session_id, 0), 0)
                    AS blocked_by,
                -- head blocker = blocks someone and is not itself blocked; a self-block from
                -- intra-query parallelism does not count as being blocked
                CONVERT(BIT, CASE WHEN blk.victim_count > 0
                                   AND ISNULL(NULLIF(r.blocking_session_id, s.session_id), 0) = 0
                                  THEN 1 ELSE 0 END) AS is_head_blocker
        ) AS bb
        -- OUTER, not CROSS: CROSS APPLY silently drops requests whose sql_handle is NULL
        OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) AS st
        OUTER APPLY sys.dm_exec_input_buffer(s.session_id, NULL) AS ib
        WHERE s.is_user_process = 1
          AND s.session_id <> @@SPID
          AND NOT EXISTS (SELECT 1 FROM @Sessions AS seen WHERE seen.SPID = s.session_id)
          AND
          (
                (@Pass > 0 AND EXISTS (SELECT 1 FROM @Sessions AS v WHERE v.BlockedBy = s.session_id))
             OR (@Pass = 0
                 -- an idle session is noise unless it holds a transaction or blocks someone
                 AND (@All = 1 OR r.session_id IS NOT NULL
                      OR s.open_transaction_count > 0 OR blk.victim_count > 0)
                 AND (@All = 1 OR ISNULL(r.last_wait_type, N'') NOT IN
                        (N'BROKER_RECEIVE_WAITFOR', N'WAITFOR', N'TRACEWRITE',
                         N'SP_SERVER_DIAGNOSTICS_SLEEP'))
                 AND (@LoginName IS NULL OR s.login_name LIKE '%' + @LoginName + '%')
                 AND (@Host IS NULL OR s.host_name IN
                        (SELECT LTRIM(RTRIM(value)) FROM STRING_SPLIT(@Host, ',')))
                 AND (@SessionId IS NULL OR s.session_id = @SessionId)
                 AND (@DatabaseName IS NULL
                      OR DB_NAME(COALESCE(r.database_id, s.database_id)) LIKE '%' + @DatabaseName + '%')
                 AND (@SQLText IS NULL OR st.text LIKE '%' + @SQLText + '%'
                      OR ib.event_info LIKE '%' + @SQLText + '%')
                 AND (ISNULL(@BlockedOnly, 0) = 0 OR bb.blocked_by IS NOT NULL)
                 -- never let an elapsed-time filter hide the session causing the wait
                 AND (@ElapsedTime IS NULL OR r.total_elapsed_time >= @ElapsedTime
                      OR bb.is_head_blocker = 1)
                )
          )
        OPTION (RECOMPILE);

        SET @Added = @@ROWCOUNT;
        SET @Pass += 1;
    END

    -- 1) Sessions. Head blockers first, then victims, then longest running.
    SELECT
        SPID, IsMatch, IsHeadBlocker, BlockedBy, BlockedSessions, Status, OpenTrans,
        ElapsedTimeMs, ElapsedTimeSec = ElapsedTimeMs / 1000.0, SecondsIdle,
        Wait, WaitTimeMs, WaitResource, CPU, LogicalReads, Reads, Writes,
        PhysicalIO_MB = (Reads + Writes) * 8.0 / 1024, MemoryKB,
        DBName, Login, Host, ProgramName, ClientNetAddress, Command, PercentComplete,
        LoginTime, LastRequestEnd, ExecutedObject, StatementSQL, FullSQL, BatchSQL, KillCMD
    FROM @Sessions
    ORDER BY IsHeadBlocker DESC,
             CASE WHEN BlockedBy IS NOT NULL THEN 0 ELSE 1 END,
             ElapsedTimeMs DESC;

    -- 2) Wait summary over the same set.
    SELECT
        Wait,
        Sessions    = COUNT(*),
        TotalWaitMs = SUM(WaitTimeMs),
        MaxWaitMs   = MAX(WaitTimeMs)
    FROM @Sessions
    WHERE Wait IS NOT NULL
    GROUP BY Wait
    ORDER BY SUM(WaitTimeMs) DESC;

    -- 3) Blockers, only when the captured set actually involves blocking.
    IF EXISTS (SELECT 1 FROM @Sessions WHERE BlockedSessions > 0)
    BEGIN
        SELECT
            Blocker = SPID,
            IsHeadBlocker, BlockedSessions, BlockedBy, Status, OpenTrans,
            ElapsedTimeMs, SecondsIdle, Wait, WaitResource,
            DBName, Login, Host, ProgramName, Command, LoginTime, LastRequestEnd,
            ExecutedObject, StatementSQL, FullSQL, BatchSQL, KillCMD
        FROM @Sessions
        WHERE BlockedSessions > 0
        ORDER BY IsHeadBlocker DESC, BlockedSessions DESC;
    END
END
GO
