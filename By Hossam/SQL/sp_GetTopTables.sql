USE [master];
GO

IF OBJECT_ID('dbo.sp_GetTopTables') IS NULL
    EXECUTE('CREATE PROCEDURE dbo.sp_GetTopTables AS RETURN;');
GO


ALTER PROCEDURE dbo.sp_GetTopTables
    @TopN INT = 10,  -- how many tables to return
    @DbName NVARCHAR(128) = NULL -- database name, default is current
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @TargetDb NVARCHAR(128) = ISNULL(@DbName, DB_NAME());
    DECLARE @sql NVARCHAR(MAX);

    SET @sql = N'USE [' + @TargetDb + N'];
    WITH TableSizes AS
    (
        SELECT 
            t.[name] AS TableName,
            s.[name] AS SchemaName,
            p.[rows] AS RowCounts,
            (SUM(a.total_pages) * 8) / 1024.0 AS TotalSizeMB,
            (SUM(a.used_pages) * 8) / 1024.0 AS UsedSizeMB,
            (SUM(a.data_pages) * 8) / 1024.0 AS DataSizeMB,
            ((SUM(a.total_pages) - SUM(a.used_pages)) * 8) / 1024.0 AS UnusedSizeMB,
            ''ALTER INDEX ALL ON ['' + s.[name] + ''].['' + t.[name] + ''] REBUILD;'' AS RebuildIndexCommand
        FROM sys.tables t
        INNER JOIN sys.indexes i ON t.OBJECT_ID = i.object_id
        INNER JOIN sys.partitions p ON i.object_id = p.OBJECT_ID AND i.index_id = p.index_id
        INNER JOIN sys.allocation_units a ON p.partition_id = a.container_id
        INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
        GROUP BY t.name, s.name, p.rows
    )
    SELECT TOP (' + CAST(@TopN AS NVARCHAR(10)) + N')
        SchemaName,
        TableName,
        RowCounts,
        TotalSizeMB,
        UsedSizeMB,
        DataSizeMB,
        UnusedSizeMB,
        RebuildIndexCommand
    FROM TableSizes
    ORDER BY UnusedSizeMB DESC;';

    EXEC sp_executesql @sql;
END
GO
