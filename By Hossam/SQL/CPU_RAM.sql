SELECT CASE configuration_id WHEN 1539 THEN value_in_use END [MAXDOP],
		CASE configuration_id WHEN 1544 THEN value_in_use END [MAX Memory]
FROM  sys.configurations d
WHERE configuration_id in (1539,1544)


select
(physical_memory_in_use_kb/1024)Phy_Memory_usedby_Sqlserver_MB
from sys. dm_os_process_memory

SELECT total_physical_memory_kb/1024 AS [Physical Memory (MB)], 
       available_physical_memory_kb/1024 AS [Available Memory (MB)]
	   ,total_page_file_kb/1024 AS [Total Page File (MB)], 
       available_page_file_kb/1024 AS [Available Page File (MB)], 
       system_cache_kb/1024 AS [System Cache (MB)],
       system_memory_state_desc AS [System Memory State]
FROM sys.dm_os_sys_memory

SELECT cpu_count,
	configurations.value_in_use as [MAXDOP],
	FORMAT(physical_memory_kb/POWER(1024,1),'##,##') System_MemoryMB,
	FORMAT(committed_kb/POWER(1024,1),'##,##') SQLMemoryUsedMB,
	FORMAT(committed_target_kb/POWER(1024,1),'##,##') SQLMaxMemoryMB,dm_os_sys_info.*
FROM sys.dm_os_sys_info
,sys.configurations
WHERE configuration_id in (1539)