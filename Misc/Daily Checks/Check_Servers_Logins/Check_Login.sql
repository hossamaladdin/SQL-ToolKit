set nocount on
go
SELECT distinct @@SERVERNAME db_server, 
	SERVERPROPERTY('ComputerNamePhysicalNetBIOS') Servername,
	l.[name] AS LoginName,
	l.[type_desc] AS [Login_Type],
	case when l.[is_disabled]=0 
		then 'Enabled'
		else 'Disabled'
	end AS [Status],
	STUFF((SELECT ', ' +  r.[name] FROM sys.server_role_members srm JOIN sys.server_principals r ON srm.role_principal_id = r.principal_id 
			WHERE l.principal_id = srm.member_principal_id
			FOR XML PATH ('')), 1, 1, '') AS [Roles]
FROM sys.server_principals l 
WHERE l.[type] IN ('U','S','E','K','G','X','C') --Would probably be easier to do != 'R'...
  AND l.[name] NOT LIKE N'##%'
  AND l.[name] NOT LIKE N'NT SERVICE%'
  AND l.[name] NOT LIKE N'NT AUTH%'