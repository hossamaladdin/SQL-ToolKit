set nocount on
go
SELECT @@SERVERNAME db_server,
SERVERPROPERTY('ComputerNamePhysicalNetBIOS') CurrentNode,
    DB_NAME(m.database_id) AS database_name,
	suser_sname( d.owner_sid ) [Owner],
    m.type_desc,
    m.name AS FileName,
	m.physical_name,
    CAST(size/128.0AS dec(19,3)) AS CurrentSizeMB,
    CAST(size/128.0/1024.0AS dec(19,3)) AS CurrentSizeGB,
    CAST(size/128.0/1024.0/1024.0 AS dec(19,3))AS CurrentSizeTB,
    SUM(CAST(size/128.0/1024.0AS dec(19,3))) OVER (PARTITION BY type_desc) Total_Size
FROM sys.master_files m
inner join sys.databases d
on m.database_id=d.database_id
WHERE m.database_id > 4
    AND type IN (1) --0 data file, 1 log file
	--and CAST(size/128.0/1024.0AS dec(19,3))>=100
ORDER BY CurrentSizeMB DESC