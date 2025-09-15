set nocount on
go

--Check last backup
SELECT 
	CONVERT(CHAR(100), SERVERPROPERTY('Servername')) AS Instancename, 
	SERVERPROPERTY('ComputerNamePhysicalNetBIOS') Servername,
	d.name [database], 
	x.backup_finish_date last_backup
FROM sys.databases d
	OUTER APPLY (SELECT TOP 1 backupset.backup_finish_date 
				FROM msdb.dbo.backupset 
				where database_name = d.name
				ORDER BY backup_finish_date desc) x
WHERE (backup_finish_date < DATEADD(MONTH,DATEDIFF(MONTH,0,GETDATE()),0) OR x.backup_finish_date IS NULL)
	AND d.database_id <> 2
ORDER BY backup_finish_date DESC
--===================