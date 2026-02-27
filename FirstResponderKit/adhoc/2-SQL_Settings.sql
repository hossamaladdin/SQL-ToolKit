USE SafeWatchDB --change context database
SELECT DB_NAME(DB_ID()),
	SERVERPROPERTY('Servername') AS Instancename, 
							SERVERPROPERTY('ComputerNamePhysicalNetBIOS') Servername,
							cpu_count,
					x.value_in_use as [MAXDOP],
					z.value AS ParameterSniffingEnabled,
					FORMAT(physical_memory_kb/POWER(1024,1),'##,##') System_MemoryMB,
					FORMAT(available_physical_memory_kb/1024,'##,##') AvailableSystemMemory,
					FORMAT(committed_kb/POWER(1024,1),'##,##') SQLMemoryUsedMB,
					FORMAT(CAST(y.value_in_use as dec(19,2)),'##,##') SQLMaxMemoryMB
				FROM sys.dm_os_sys_info,sys.dm_os_sys_memory,sys.configurations x,sys.configurations y,sys.database_scoped_configurations z
				WHERE x.configuration_id = 1539 AND y.configuration_id = 1544 AND z.configuration_id = 3