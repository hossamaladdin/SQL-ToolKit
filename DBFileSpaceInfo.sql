CREATE OR ALTER PROCEDURE sp_GetDBFiles (@Disk VARCHAR(100) = NULL)

AS
BEGIN
-- Drop the temporary table if it exists
IF OBJECT_ID('tempdb..#DBFileSpaceInfo') IS NOT NULL
    DROP TABLE #DBFileSpaceInfo;

-- Create temporary table to hold results
CREATE TABLE #DBFileSpaceInfo
(
    DatabaseName NVARCHAR(128),
    FileName NVARCHAR(128),
    PhysicalName NVARCHAR(260),
    FileType NVARCHAR(60),
    TotalSizeMB DECIMAL(10,2),
    UsedSpaceMB DECIMAL(10,2),
    FreeSpaceMB DECIMAL(10,2),
    FreePercentage DECIMAL(5,2),
    ShrinkCommand NVARCHAR(500)
)

-- Collect space information for all databases
EXEC sp_MSforeachdb '
USE [?];
INSERT INTO #DBFileSpaceInfo
SELECT 
    DB_NAME() AS DatabaseName,
    name AS FileName,
    physical_name AS PhysicalName,
    type_desc AS FileType,
    size/128.0 AS TotalSizeMB,
    CAST(FILEPROPERTY(name, ''SpaceUsed'') AS int)/128.0 AS UsedSpaceMB,
    size/128.0 - CAST(FILEPROPERTY(name, ''SpaceUsed'') AS int)/128.0 AS FreeSpaceMB,
    ((size/128.0 - CAST(FILEPROPERTY(name, ''SpaceUsed'') AS int)/128.0)/(size/128.0))*100 AS FreePercentage,
    ''USE ['' + DB_NAME() + '']; DBCC SHRINKDATABASE (N'''''' + DB_NAME() + ''''''); ''+CHAR(10)+''GO'' AS ShrinkCommand
FROM sys.database_files
WHERE type IN (0,1)';


-- Get results
SELECT * 
FROM #DBFileSpaceInfo
WHERE PhysicalName like QUOTENAME(@Disk)+':%' OR @Disk IS NULL --DatabaseName NOT IN ('master', 'model', 'msdb', 'tempdb')
ORDER BY FreeSpaceMB DESC;

END

GO
/**************************/

--check progress
SELECT  
    r.session_id,
    r.status,
    r.command,
    r.percent_complete,
    r.start_time,
    DATEDIFF(SECOND, r.start_time, GETDATE()) / 60.0 AS [Elapsed_Time_Minutes],
    r.estimated_completion_time / 1000 / 60 AS [Est_Min_Left],
    r.blocking_session_id,
    r.wait_type,
    r.wait_time,
    r.wait_resource,
    t.text AS [SQL Text]
FROM sys.dm_exec_requests r
    JOIN sys.dm_exec_sessions s ON r.session_id = s.session_id
    CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
WHERE r.command LIKE 'Dbcc%';

--SP_ACTIVESESSIONS