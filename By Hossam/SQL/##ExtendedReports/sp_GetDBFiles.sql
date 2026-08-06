CREATE OR ALTER PROCEDURE ##sp_GetDBFiles (@Disk VARCHAR(100) = NULL)

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
    CASE 
    WHEN type = 0 THEN ''USE ['' + DB_NAME() + '']; DBCC SHRINKFILE (N'''''' + name + '''''', '' + CONVERT(NVARCHAR(20), CAST(FILEPROPERTY(name, ''SpaceUsed'') * 8.0 / 1024 * 1.10 AS INT)) + ''); -- Data file''+CHAR(10)+''GO''
    WHEN type = 1 THEN ''USE ['' + DB_NAME() + '']; DBCC SHRINKFILE (N'''''' + name + ''''''); -- Log file''+CHAR(10)+''GO''
    ELSE ''''
    END AS ShrinkCommand
FROM sys.database_files
WHERE type IN (0,1)';


-- Get results
SELECT * 
FROM #DBFileSpaceInfo
WHERE PhysicalName like QUOTENAME(@Disk)+':%' OR @Disk IS NULL --DatabaseName NOT IN ('master', 'model', 'msdb', 'tempdb')
ORDER BY FreeSpaceMB DESC;

END

GO
