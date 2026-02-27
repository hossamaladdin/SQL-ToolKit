-- Drop everything first
IF OBJECT_ID('tempdb..##DBA_FullTableScanQueries') IS NOT NULL
    DROP TABLE ##DBA_FullTableScanQueries;

IF OBJECT_ID('tempdb..##sp_CollectFullTableScanQueries') IS NOT NULL
    DROP PROCEDURE ##sp_CollectFullTableScanQueries;
GO

-- Create fresh
CREATE PROCEDURE ##sp_CollectFullTableScanQueries
AS
BEGIN
    SET NOCOUNT ON;

    IF OBJECT_ID('tempdb..##DBA_FullTableScanQueries') IS NULL
    BEGIN
        CREATE TABLE ##DBA_FullTableScanQueries (
            database_name       NVARCHAR(128),
            object_name         NVARCHAR(128),
            execution_count     INT,
            avg_logical_reads   BIGINT,
            avg_elapsed_time_ms BIGINT,
            last_execution_time DATETIME,
            query_text          NVARCHAR(MAX),
            query_type          NVARCHAR(50),
            scan_type           NVARCHAR(30),
            collection_date     DATETIME DEFAULT GETDATE()
        );
    END;

    TRUNCATE TABLE ##DBA_FullTableScanQueries;

    INSERT INTO ##DBA_FullTableScanQueries (
        database_name,
        object_name,
        execution_count,
        avg_logical_reads,
        avg_elapsed_time_ms,
        last_execution_time,
        query_text,
        query_type,
        scan_type
    )
    SELECT 
        d.name AS database_name,
        COALESCE(
            OBJECT_NAME(st.objectid, st.dbid),
            'Ad-hoc Query'
        ) AS object_name,
        qs.execution_count,
        qs.total_logical_reads / NULLIF(qs.execution_count,0) AS avg_logical_reads,
        qs.total_elapsed_time / NULLIF(qs.execution_count,0) / 1000 AS avg_elapsed_time_ms,
        qs.last_execution_time,
        SUBSTRING(st.text, 1, 4000) AS query_text,
        CASE 
            WHEN st.objectid IS NOT NULL THEN 'Stored Object'
            ELSE 'Ad-hoc Query'
        END AS query_type,
        'High Logical Reads' AS scan_type
    FROM sys.dm_exec_query_stats qs
    CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st
    INNER JOIN sys.databases d ON st.dbid = d.database_id
    WHERE st.dbid IS NOT NULL
      AND d.name NOT IN ('master','model','msdb','tempdb')
      AND d.state = 0
      -- Filter out DDL statements that pollute results
      --AND st.text NOT LIKE '%CREATE PROCEDURE%'
      --AND st.text NOT LIKE '%ALTER PROCEDURE%'
      --AND st.text NOT LIKE '%CREATE FUNCTION%'
      --AND st.text NOT LIKE '%CREATE TRIGGER%'
      -- Optional: Add threshold back
      AND qs.total_logical_reads / NULLIF(qs.execution_count,0) > 1000;

    -- Summary by database
    SELECT 
        database_name,
        COUNT(*) AS query_count,
        SUM(execution_count) AS total_executions,
        AVG(avg_logical_reads) AS avg_logical_reads,
        MAX(last_execution_time) AS most_recent_execution
    FROM ##DBA_FullTableScanQueries
    GROUP BY database_name
    ORDER BY avg_logical_reads DESC;

    -- Full details
    SELECT *
    FROM ##DBA_FullTableScanQueries
    ORDER BY avg_logical_reads DESC, last_execution_time DESC;
END;
GO

-- Execute it
EXEC ##sp_CollectFullTableScanQueries;