-- =====================================================
-- Extract ALL High CPU Events from XEL Files
-- Time Window: 2026-01-31 07:00-07:30 AM
-- =====================================================
-- IMPORTANT: All time values are in MICROSECONDS in the raw XEL
-- =====================================================

USE master;
GO

SET NOCOUNT ON;
GO

-- =====================================================
-- STEP 1: Find XEL files on server (uncomment to search)
-- =====================================================
-- EXEC xp_dirtree 'G:\log', 1, 1;
-- EXEC xp_cmdshell 'dir G:\log\HighCPUAndReads*.xel /B';

-- =====================================================
-- STEP 2: Set path and time range
-- =====================================================
DECLARE @XELPath NVARCHAR(500);
DECLARE @StartTime DATETIME2 = '2026-01-31 07:00:00';  -- 7:00 AM server time
DECLARE @EndTime DATETIME2 = '2026-01-31 07:30:00';    -- 7:30 AM server time

-- Find the LAST (most recent) XEL file
DECLARE @FileList TABLE (FileName NVARCHAR(500), Depth INT, IsFile INT);
INSERT INTO @FileList
EXEC xp_dirtree 'G:\log', 1, 1;

SELECT TOP 1 @XELPath = 'G:\log\' + FileName
FROM @FileList
WHERE FileName LIKE 'HighCPUAndReads%.xel'
ORDER BY FileName DESC;  -- Last file alphabetically (usually means most recent)

PRINT '=================================================================';
PRINT 'Extracting events from: ' + ISNULL(@XELPath, 'NO FILE FOUND');
PRINT 'Time range: ' + CAST(@StartTime AS VARCHAR(30)) + ' to ' + CAST(@EndTime AS VARCHAR(30));
PRINT '=================================================================';
PRINT '';

-- =====================================================
-- STEP 3: Parse events into temp table for reuse
-- =====================================================
IF OBJECT_ID('tempdb..#Parsed_Events') IS NOT NULL
    DROP TABLE #Parsed_Events;

;WITH XEL_Data AS (
    SELECT CAST(event_data AS XML) AS event_data
    FROM sys.fn_xe_file_target_read_file(@XELPath, null, null, null)
)
SELECT
    event_data.value('(event/@timestamp)[1]', 'datetime2') AS EventTime_UTC,
        event_data.value('(event/@name)[1]', 'varchar(100)') AS EventName,

        -- All values are in MICROSECONDS from XEL
        event_data.value('(event/data[@name="duration"]/value)[1]', 'bigint') AS Duration_Microseconds,
        event_data.value('(event/data[@name="cpu_time"]/value)[1]', 'bigint') AS CPU_Microseconds,
        event_data.value('(event/data[@name="logical_reads"]/value)[1]', 'bigint') AS LogicalReads,
        event_data.value('(event/data[@name="physical_reads"]/value)[1]', 'bigint') AS PhysicalReads,
        event_data.value('(event/data[@name="writes"]/value)[1]', 'bigint') AS Writes,
        event_data.value('(event/data[@name="row_count"]/value)[1]', 'bigint') AS [RowCount],

        -- Database and object info
        event_data.value('(event/data[@name="database_name"]/value)[1]', 'varchar(256)') AS DatabaseName,
        event_data.value('(event/data[@name="object_name"]/value)[1]', 'varchar(256)') AS ObjectName,

        -- Session and connection info
        event_data.value('(event/action[@name="session_id"]/value)[1]', 'int') AS SessionID,
        event_data.value('(event/action[@name="username"]/value)[1]', 'varchar(256)') AS Username,
        event_data.value('(event/action[@name="client_hostname"]/value)[1]', 'varchar(256)') AS ClientHostname,
        event_data.value('(event/action[@name="client_app_name"]/value)[1]', 'varchar(256)') AS ClientAppName,
        event_data.value('(event/action[@name="database_name"]/value)[1]', 'varchar(256)') AS ActionDatabaseName,

        -- Full SQL Statement
        event_data.value('(event/data[@name="statement"]/value)[1]', 'varchar(max)') AS SQL_Statement,
        event_data.value('(event/action[@name="sql_text"]/value)[1]', 'varchar(max)') AS SQL_Text_Action
INTO #Parsed_Events
FROM XEL_Data
WHERE event_data.value('(event/@timestamp)[1]', 'datetime2') >= @StartTime
  AND event_data.value('(event/@timestamp)[1]', 'datetime2') < @EndTime;

-- =====================================================
-- Query 1: Get ALL events with full details
-- =====================================================
SELECT
    ROW_NUMBER() OVER (ORDER BY CPU_Microseconds DESC) AS RowNum,
    EventTime_UTC AS EventTime_Server,  -- Already in server local time
    EventName,

    -- Convert to human-readable units
    Duration_Microseconds,
    CAST(Duration_Microseconds / 1000.0 AS DECIMAL(18,3)) AS Duration_Milliseconds,
    CAST(Duration_Microseconds / 1000000.0 AS DECIMAL(18,3)) AS Duration_Seconds,

    CPU_Microseconds,
    CAST(CPU_Microseconds / 1000.0 AS DECIMAL(18,3)) AS CPU_Milliseconds,
    CAST(CPU_Microseconds / 1000000.0 AS DECIMAL(18,3)) AS CPU_Seconds,

    LogicalReads,
    PhysicalReads,
    Writes,
    [RowCount],

    ISNULL(DatabaseName, ActionDatabaseName) AS [Database],
    ObjectName,
    SessionID,
    Username,
    ClientHostname,
    ClientAppName,

    -- Use statement if available, otherwise sql_text action
    ISNULL(SQL_Statement, SQL_Text_Action) AS SQL_Text

FROM #Parsed_Events
ORDER BY CPU_Microseconds DESC;

-- Show summary statistics
PRINT '';
PRINT 'Summary Statistics:';
SELECT
    COUNT(*) AS Total_Events,
    SUM(CPU_Microseconds) / 1000000.0 AS Total_CPU_Seconds,
    AVG(CPU_Microseconds) / 1000000.0 AS Avg_CPU_Seconds,
    MAX(CPU_Microseconds) / 1000000.0 AS Max_CPU_Seconds,
    SUM(LogicalReads) AS Total_LogicalReads,
    AVG(LogicalReads) AS Avg_LogicalReads
FROM #Parsed_Events;

-- Show by user
PRINT '';
PRINT 'By Username:';
SELECT
    Username,
    COUNT(*) AS Event_Count,
    SUM(CPU_Microseconds) / 1000000.0 AS Total_CPU_Seconds,
    AVG(CPU_Microseconds) / 1000000.0 AS Avg_CPU_Seconds
FROM #Parsed_Events
GROUP BY Username
ORDER BY COUNT(*) DESC;

-- Show by host
PRINT '';
PRINT 'By Client Host:';
SELECT
    ClientHostname,
    COUNT(*) AS Event_Count,
    SUM(CPU_Microseconds) / 1000000.0 AS Total_CPU_Seconds
FROM #Parsed_Events
GROUP BY ClientHostname
ORDER BY COUNT(*) DESC;

GO
