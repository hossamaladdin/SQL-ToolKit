DECLARE
@LoginName nvarchar(200)=null
,@Host nvarchar(200)=null
,@ElapsedTime int=null
,@BlockedOnly int = null
,@SessionId int = null
,@SQLText nvarchar(1000) = null
,@DatabaseName nvarchar(200) = null
,@All int = 0


SELECT --@@SERVERNAME SrvName ,@@SERVICENAME SvcName,@@VERSION Ver,
	req.session_id SPID,
	req.total_elapsed_time ElpsdTime,req.last_wait_type Wait,req.wait_time,
	x2.event_info BatchSQL, --not before sql 2014 sp1
	req.cpu_time cpu,
	req.logical_reads logclRead,req.reads,req.writes,
	ses.host_name host,DB_Name(req.database_id) DBName,
	req.blocking_session_id BlkBY,
	isnull(x.event_info,'') BlockingSQL, --not before sql 2014 sp1
	req.status,percent_complete,
	ses.login_name,
	SUBSTRING(sqltext.text, (req.statement_start_offset/2)+1,((CASE req.statement_end_offset WHEN -1 THEN DATALENGTH(sqltext.text) ELSE req.statement_end_offset END - req.statement_start_offset)/2) + 1) AS Statement,
	sqltext.text,
	'kill '+cast(req.session_id as varchar) KillCMD
FROM sys.dm_exec_requests req
	LEFT JOIN sys.dm_exec_sessions ses ON ses. session_id = req. session_id
	CROSS APPLY sys.dm_exec_sql_text(sql_handle) AS sqltext
	outer apply (select * from sys.dm_exec_input_buffer(req.session_id,null)) x2 --not before sql 2014 sp1
	outer apply (select * from sys.dm_exec_input_buffer(blocking_session_id,null)) x --not before sql 2014 sp1
where req.session_id<>@@SPID
	and (req.last_wait_type not in (N'BROKER_RECEIVE_WAITFOR',N'WAITFOR',N'TRACEWRITE','SP_SERVER_DIAGNOSTICS_SLEEP') or @All = 1)
	and (ses.login_name like '%'+@LoginName+'%' or @LoginName is null)
	and (ses.host_name like '%'+@Host+'%' or @Host is null)
	and (req.total_elapsed_time>=@ElapsedTime or @ElapsedTime is null)
	and (ses.session_id=@SessionId or @SessionId is null)
	and (req.blocking_session_id>=@BlockedOnly or @BlockedOnly is null)
	and (--x2.event_info like '%'+@SQLText+'%' or x.event_info like '%'+@SQLText+'%' or --not before sql 2014 sp1 
		SUBSTRING(sqltext.text, (req.statement_start_offset/2)+1,((CASE req.statement_end_offset WHEN -1 THEN DATALENGTH(sqltext.text) ELSE req.statement_end_offset END - req.statement_start_offset)/2) + 1) like '%'+@SQLText+'%' or @SQLText is null)
	and (DB_Name(req.database_id) like '%'+@DatabaseName+'%' or @DatabaseName is null)
order by req.total_elapsed_time desc