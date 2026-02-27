SELECT 
    SCHEMA_NAME(obj.schema_id) AS SchemaName,
    OBJECT_NAME(ind.OBJECT_ID) AS TableName,
    ind.name AS IndexName,
    indexstats.avg_fragmentation_in_percent AS FragmentationPercentage,
    indexstats.page_count AS PageCount,
    CASE 
        WHEN indexstats.avg_fragmentation_in_percent > 30 THEN 
            'ALTER INDEX [' + ind.name + '] ON [' + SCHEMA_NAME(obj.schema_id) + '].[' + OBJECT_NAME(ind.OBJECT_ID) + '] REBUILD WITH (ONLINE = OFF);'
        WHEN indexstats.avg_fragmentation_in_percent BETWEEN 5 AND 30 THEN 
            'ALTER INDEX [' + ind.name + '] ON [' + SCHEMA_NAME(obj.schema_id) + '].[' + OBJECT_NAME(ind.OBJECT_ID) + '] REORGANIZE;'
        ELSE 'Fragmentation under 5% - no action needed'
    END AS RecommendedAction,
    CASE 
        WHEN indexstats.avg_fragmentation_in_percent > 30 THEN 'REBUILD'
        WHEN indexstats.avg_fragmentation_in_percent BETWEEN 5 AND 30 THEN 'REORGANIZE'
        ELSE 'NONE'
    END AS ActionType
FROM 
    sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') indexstats
INNER JOIN 
    sys.indexes ind ON ind.object_id = indexstats.object_id AND ind.index_id = indexstats.index_id
INNER JOIN
    sys.objects obj ON ind.object_id = obj.object_id
WHERE 
    indexstats.avg_fragmentation_in_percent > 5  -- Only show indexes with more than 5% fragmentation
    AND ind.name IS NOT NULL  -- Ignore heaps
    --AND indexstats.page_count > 100  -- Only consider indexes with more than 100 pages
    AND obj.is_ms_shipped = 0  -- Exclude system objects
ORDER BY 
    indexstats.avg_fragmentation_in_percent DESC;