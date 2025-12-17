-- =============================================
-- Simplified Database Index Analysis Summary
-- Shows: Current Size, Size After Removal, % Decrease
-- =============================================

SET NOCOUNT ON;
DECLARE @Details INT = 0; -- Set to 1 if you want to view index details
DECLARE @ReadsThreshold INT = 2000; -- Change this value to desired threshold

-- Create temp table to store all index data
IF OBJECT_ID('tempdb..#AllIndexes') IS NOT NULL DROP TABLE #AllIndexes;

CREATE TABLE #AllIndexes (
    database_name     NVARCHAR(128),
    schema_name       NVARCHAR(128),
    table_name        NVARCHAR(128),
    index_name        NVARCHAR(128),
    index_size_mb     DECIMAL(18,2),
    total_reads       BIGINT,
    total_writes      BIGINT,
    is_primary_key    BIT
);

-- Loop through databases and collect index info
DECLARE @DB NVARCHAR(128);
DECLARE @SQL NVARCHAR(MAX);

DECLARE db_cursor CURSOR FOR
SELECT name FROM sys.databases
WHERE name NOT IN ('master','model','msdb','tempdb')
  AND state = 0 AND HAS_DBACCESS(name) = 1;

OPEN db_cursor;
FETCH NEXT FROM db_cursor INTO @DB;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @SQL = N'
    USE [' + @DB + N'];
    INSERT INTO #AllIndexes
    SELECT 
        DB_NAME(),
        SCHEMA_NAME(t.schema_id),
        t.name,
        i.name,
        SUM(ps.reserved_page_count) * 8.0 / 1024.0,
        ISNULL(ius.user_seeks,0) + ISNULL(ius.user_scans,0) + ISNULL(ius.user_lookups,0),
        ISNULL(ius.user_updates,0),
        i.is_primary_key
    FROM sys.tables t
    JOIN sys.indexes i ON t.object_id = i.object_id
    JOIN sys.dm_db_partition_stats ps ON i.object_id = ps.object_id AND i.index_id = ps.index_id
    LEFT JOIN sys.dm_db_index_usage_stats ius ON i.object_id = ius.object_id 
        AND i.index_id = ius.index_id AND ius.database_id = DB_ID()
    WHERE i.type > 0 AND t.is_ms_shipped = 0
    GROUP BY t.schema_id, t.name, i.name, i.is_primary_key,
        ius.user_seeks, ius.user_scans, ius.user_lookups, ius.user_updates;';
    
    BEGIN TRY
        EXEC sp_executesql @SQL;
    END TRY
    BEGIN CATCH
        PRINT 'Error in database: ' + @DB;
    END CATCH
    
    FETCH NEXT FROM db_cursor INTO @DB;
END;

CLOSE db_cursor;
DEALLOCATE db_cursor;

-- =============================================
-- MAIN RESULT: Database Summary
-- =============================================
SELECT 
    database_name AS [Database Name],
    
    -- Current total size
    FORMAT(SUM(index_size_mb), 'N2') AS [Current Size (MB)],
    
    -- Size after removing indexes with < 1000 reads (excluding PKs)
    FORMAT(
        SUM(index_size_mb) - 
        SUM(CASE WHEN total_reads < @ReadsThreshold AND is_primary_key = 0 THEN index_size_mb ELSE 0 END), 
        'N2'
    ) AS [Size After Removal (MB)],
    
    -- Space that would be freed
    FORMAT(
        SUM(CASE WHEN total_reads < @ReadsThreshold AND is_primary_key = 0 THEN index_size_mb ELSE 0 END),
        'N2'
    ) AS [Space Freed (MB)],
    
    -- Percentage decrease
    CAST(
        CASE WHEN SUM(index_size_mb) > 0 THEN
            (SUM(CASE WHEN total_reads < @ReadsThreshold AND is_primary_key = 0 THEN index_size_mb ELSE 0 END) 
             / SUM(index_size_mb) * 100)
        ELSE 0 END
    AS DECIMAL(5,2)) AS [Decrease %],
    
    -- Additional stats
    COUNT(*) AS [Total Indexes],
    SUM(CASE WHEN total_reads < @ReadsThreshold AND is_primary_key = 0 THEN 1 ELSE 0 END) AS [Low Usage Indexes]
    
FROM #AllIndexes
GROUP BY database_name
ORDER BY [Decrease %] DESC;

-- =============================================
-- DETAILED BREAKDOWN: Index Details
-- =============================================
IF @Details = 1
BEGIN
PRINT '';
PRINT 'Detailed Index Information:';
PRINT '';

SELECT 
    database_name AS [Database],
    schema_name + '.' + table_name AS [Table],
    index_name AS [Index],
    FORMAT(index_size_mb, 'N2') AS [Size (MB)],
    total_reads AS [Reads],
    total_writes AS [Writes],
    CASE WHEN is_primary_key = 1 THEN 'PK' ELSE '' END AS [PK],
    CASE 
        WHEN total_reads < @ReadsThreshold AND is_primary_key = 0 THEN 'DROP CANDIDATE'
        ELSE 'KEEP'
    END AS [Recommendation]
FROM #AllIndexes
ORDER BY 
    database_name,
    index_size_mb DESC;
END;
