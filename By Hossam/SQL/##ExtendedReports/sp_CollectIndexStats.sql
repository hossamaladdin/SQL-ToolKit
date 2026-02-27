DROP PROCEDURE IF EXISTS ##sp_CollectIndexStats;
GO
CREATE PROCEDURE ##sp_CollectIndexStats
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Create table in master if it doesn't exist
    IF OBJECT_ID('tempdb..##DBA_IndexStats') IS NULL
    BEGIN
        CREATE TABLE ##DBA_IndexStats (
            database_name NVARCHAR(128),
            schema_name NVARCHAR(128),
            table_name NVARCHAR(128),
            index_name NVARCHAR(128),
            index_type NVARCHAR(60),
            is_primary_key BIT,
            is_unique BIT,
            is_disabled BIT,
            row_count BIGINT,
            index_size_MB DECIMAL(18,2),
            avg_fragmentation_in_percent FLOAT,
            page_count BIGINT,
            total_user_operations BIGINT,
            user_seeks BIGINT,
            user_scans BIGINT,
            user_lookups BIGINT,
            write_operations BIGINT,
            last_user_seek DATETIME,
            last_user_update DATETIME,
            recommended_action NVARCHAR(20),
            collection_date DATETIME DEFAULT GETDATE()
        );
    END;
    
    -- Clear existing data
    TRUNCATE TABLE ##DBA_IndexStats;
    
    -- Get list of online user databases
    DECLARE @databases TABLE (dbname NVARCHAR(128));
    INSERT INTO @databases
    SELECT name FROM sys.databases 
    WHERE state_desc = 'ONLINE' 
    AND database_id > 4 
    AND is_read_only = 0;
    
    -- Loop through databases
    DECLARE @dbname NVARCHAR(128);
    DECLARE @sql NVARCHAR(MAX);
    
    DECLARE db_cursor CURSOR FOR 
    SELECT dbname FROM @databases;
    
    OPEN db_cursor;
    FETCH NEXT FROM db_cursor INTO @dbname;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Collect index stats with fragmentation
        SET @sql = N'
        USE [' + @dbname + N'];
        INSERT INTO ##DBA_IndexStats (
            database_name, schema_name, table_name, index_name, index_type,
            is_primary_key, is_unique, is_disabled, row_count, index_size_MB,
            avg_fragmentation_in_percent, page_count,
            total_user_operations, user_seeks, user_scans, user_lookups,
            write_operations, last_user_seek, last_user_update,
            recommended_action
        )
        SELECT 
            DB_NAME() AS database_name,
            SCHEMA_NAME(t.schema_id) AS schema_name,
            t.name AS table_name,
            i.name AS index_name,
            i.type_desc AS index_type,
            i.is_primary_key,
            i.is_unique,
            i.is_disabled,
            p.rows AS row_count,
            SUM(a.total_pages) * 8 / 1024 AS index_size_MB,
            ips.avg_fragmentation_in_percent,
            ips.page_count,
            ISNULL(ius.user_seeks, 0) + ISNULL(ius.user_scans, 0) + ISNULL(ius.user_lookups, 0) AS total_user_operations,
            ISNULL(ius.user_seeks, 0) AS user_seeks,
            ISNULL(ius.user_scans, 0) AS user_scans,
            ISNULL(ius.user_lookups, 0) AS user_lookups,
            ISNULL(ius.user_updates, 0) AS write_operations,
            ius.last_user_seek,
            ius.last_user_update,
            CASE
                WHEN ips.avg_fragmentation_in_percent > 30 THEN ''REBUILD''
                WHEN ips.avg_fragmentation_in_percent BETWEEN 10 AND 30 THEN ''REORGANIZE''
                ELSE ''OK''
            END AS recommended_action
        FROM sys.tables t
        JOIN sys.indexes i ON t.object_id = i.object_id
        JOIN sys.partitions p ON i.object_id = p.object_id AND i.index_id = p.index_id
        JOIN sys.allocation_units a ON p.partition_id = a.container_id
        LEFT JOIN sys.dm_db_index_usage_stats ius ON i.object_id = ius.object_id 
                                             AND i.index_id = ius.index_id
                                             AND ius.database_id = DB_ID()
        LEFT JOIN sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, ''LIMITED'') ips 
                  ON i.object_id = ips.object_id 
                  AND i.index_id = ips.index_id
        WHERE i.index_id > 0  -- Skip heaps
        GROUP BY 
            t.schema_id,
            t.name,
            i.name,
            i.type_desc,
            i.is_primary_key,
            i.is_unique,
            i.is_disabled,
            p.rows,
            ips.avg_fragmentation_in_percent,
            ips.page_count,
            ius.user_seeks,
            ius.user_scans,
            ius.user_lookups,
            ius.user_updates,
            ius.last_user_seek,
            ius.last_user_update;
        ';
        EXEC sp_executesql @sql;
        
        FETCH NEXT FROM db_cursor INTO @dbname;
    END;
    
    CLOSE db_cursor;
    DEALLOCATE db_cursor;
        
    PRINT 'Index statistics collection complete.';

	SELECT * FROM ##DBA_IndexStats ORDER BY avg_fragmentation_in_percent DESC;
END;
GO
