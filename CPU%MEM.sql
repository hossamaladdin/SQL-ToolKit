CREATE PROCEDURE sp_GetCPU
AS
BEGIN
    SET NOCOUNT ON;

    -- Get CPU snapshot from ring buffer
    WITH RingBufferCPU AS (
        SELECT TOP 1
            CAST(record AS XML) AS record_data
        FROM sys.dm_os_ring_buffers
        WHERE ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR'
        ORDER BY timestamp DESC
    )
    SELECT
        -- CPU Metrics
        CPU.value('(./SystemIdle)[1]', 'int') AS SystemIdle_Perc,
        100 - CPU.value('(./SystemIdle)[1]', 'int') AS TotalCPU_Used_Perc,
        CPU.value('(./ProcessUtilization)[1]', 'int') AS SQL_CPU_Used_Perc,

        -- SQL Server Memory Metrics
        CAST(mem.physical_memory_in_use_kb / 1048576.0 AS DECIMAL(13,2)) AS SQL_Memory_Used_GB,
        CAST(mem.physical_memory_in_use_kb * 1.0 / sys.physical_memory_kb * 100 AS DECIMAL(13,2)) AS SQL_Memory_Used_Perc,
        CAST(mem.virtual_address_space_committed_kb / 1048576.0 AS DECIMAL(13,2)) AS SQL_Memory_Configured_GB,

        -- Total System Memory Metrics (OS-level from sys.dm_os_sys_memory)
        CAST(osmem.total_physical_memory_kb / 1048576.0 AS DECIMAL(13,2)) AS Server_Total_Memory_GB,
        CAST(osmem.available_physical_memory_kb / 1048576.0 AS DECIMAL(13,2)) AS Available_Memory_GB,
        CAST((osmem.total_physical_memory_kb - osmem.available_physical_memory_kb) / 1048576.0 AS DECIMAL(13,2)) AS System_Memory_Used_GB,
        CAST(((osmem.total_physical_memory_kb - osmem.available_physical_memory_kb) * 100.0 / osmem.total_physical_memory_kb) AS DECIMAL(13,2)) AS System_Memory_Used_Perc

    FROM RingBufferCPU cpu
    CROSS APPLY cpu.record_data.nodes('/Record/SchedulerMonitorEvent/SystemHealth') AS T(CPU)
    CROSS JOIN sys.dm_os_process_memory mem
    CROSS JOIN sys.dm_os_sys_info sys
    CROSS JOIN sys.dm_os_sys_memory osmem;
END
