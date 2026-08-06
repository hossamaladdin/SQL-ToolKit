SET NOCOUNT ON;

EXEC SP_CONFIGURE 'adv',1 reconfigure
EXEC SP_CONFIGURE 'Ad Hoc Dist',1 reconfigure
GO

declare @instance varchar(100) = @@servername
declare @SQL varchar(MAX) = 'SELECT DISTINCT local_net_address FROM OPENROWSET(''SQLNCLI'',''Server=tcp:'+@instance+';Trusted_Connection=yes;'',
	''SELECT local_net_address FROM sys.dm_exec_connections WHERE session_id = @@spid'') as a'

--PRINT @SQL
declare @tbl table (IP_ADDRESS varchar(150))
insert @tbl
EXEC(@SQL)

/*
declare @Drive table(DriveName char,	FreeSpaceInMegabytes int,FreeSpaceInGB int)
insert @Drive(DriveName,FreeSpaceInMegabytes) execute xp_fixeddrives
UPDATE @Drive SET FreeSpaceInGB = FreeSpaceInMegabytes/1024
*/

SELECT  distinct @@SERVERNAME InstanceName, 
			SERVERPROPERTY('ComputerNamePhysicalNetBIOS') Hostname,
			CONCAT(CASE 
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '8%' THEN 'SQL 2000'
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '9%' THEN 'SQL 2005'
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '10.0%' THEN 'SQL 2008'
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '10.5%' THEN 'SQL 2008 R2'
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '11%' THEN 'SQL 2012'
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '12%' THEN 'SQL 2014'
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '13%' THEN 'SQL 2016'     
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '14%' THEN 'SQL 2017' 
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '15%' THEN 'SQL 2019' 
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '16%' THEN 'SQL 2022' 
     ELSE 'unknown'
  END 
  ,' ',CONVERT(VARCHAR(128),SERVERPROPERTY('ProductLevel')) 
  ,' ',CONVERT(VARCHAR(128),SERVERPROPERTY('Edition')) 
  ,' ',CONVERT(VARCHAR(128),SERVERPROPERTY('ProductVersion')) ) SQL_Version,
			STUFF((
		SELECT 
			STUFF((SELECT ' | ' +l.[name],
			'; ' +l.[type_desc],
			'; ' +  r.[name],
			'; ' +case when l.[is_disabled]=0 
				then 'Enabled '
				else 'Disabled '
			end
			 FROM sys.server_role_members srm JOIN sys.server_principals r ON srm.role_principal_id = r.principal_id 
					WHERE l.principal_id = srm.member_principal_id
					FOR XML PATH ('')), 1, 1, '')
		FROM sys.server_principals l 
		WHERE l.[type] IN ('U','S','E','K','G','X','C') --Would probably be easier to do != 'R'...
		  AND l.[name] NOT LIKE N'##%'
		  AND l.[name] NOT LIKE N'NT SERVICE%'
		  AND l.[name] NOT LIKE N'NT AUTH%'
  FOR XML PATH ('')), 1, 1, '') Logins,
  STUFF((SELECT DISTINCT '| '+(volume_mount_point), 
			  ' Size: ',CAST(total_bytes/1048576/1024.0 AS DEC(19,2)),' GB',
			  ' Free: ',CAST(available_bytes/1048576/1024.0 AS DEC(19,2)),' GB'
			FROM sys.master_files AS f 
				CROSS APPLY sys.dm_os_volume_stats(f.database_id, f.file_id)
			group by volume_mount_point,total_bytes,available_bytes 
			order by 1 FOR XML PATH ('')), 1, 1, '') Disks,
  IP_Address
  FROM @tbl
GO

EXEC SP_CONFIGURE 'Ad Hoc Dist',0 reconfigure
EXEC SP_CONFIGURE 'adv',0 reconfigure