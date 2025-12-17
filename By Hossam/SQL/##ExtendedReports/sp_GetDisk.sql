use [master];
GO

IF OBJECT_ID('tempdb..##sp_GetDisk', 'P') IS NULL
    EXECUTE('CREATE PROCEDURE ##sp_GetDisk AS RETURN;');

GO
ALTER PROCEDURE ##sp_GetDisk

AS

SELECT 
    vs.volume_mount_point   AS Drive,
    vs.logical_volume_name  AS VolumeName,
    CASE 
        WHEN MIN(vs.available_bytes) >= 1073741824 
            THEN CONCAT(CAST(MIN(vs.available_bytes)/1073741824.0 AS DECIMAL(10,2)), ' GB')
        ELSE 
            CONCAT(CAST(MIN(vs.available_bytes)/1048576.0 AS DECIMAL(10,2)), ' MB')
    END AS FreeSpace,
    CASE 
        WHEN MAX(vs.total_bytes) >= 1073741824 
            THEN CONCAT(CAST(MAX(vs.total_bytes)/1073741824.0 AS DECIMAL(10,2)), ' GB')
        ELSE 
            CONCAT(CAST(MAX(vs.total_bytes)/1048576.0 AS DECIMAL(10,2)), ' MB')
    END AS TotalSpace,
    CAST(MIN(vs.available_bytes) * 100.0 / MAX(vs.total_bytes) AS DECIMAL(5,2)) AS FreePercent,
    CASE 
        WHEN CAST(MIN(vs.available_bytes) * 100.0 / MAX(vs.total_bytes) AS DECIMAL(5,2)) < 15.00 
            THEN N'⚠️ Below 15%' 
        ELSE 'OK' 
    END AS Status
FROM sys.master_files AS mf
CROSS APPLY sys.dm_os_volume_stats(mf.database_id, mf.file_id) AS vs
GROUP BY 
    vs.volume_mount_point,
    vs.logical_volume_name
ORDER BY FreePercent;
GO
