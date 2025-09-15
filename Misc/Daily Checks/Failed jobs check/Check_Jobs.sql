set nocount on
go


--find failing jobs
select replace(j.name,',',' ') JobName,
	h.step_name,
	h.run_date,
	h.run_time,
	h.run_duration,
	replace(replace(replace(h.message,char(10),' '),char(9),' '),char(13),' ')message,
	h.server 
from msdb.dbo.sysjobhistory h 
	join msdb.dbo.sysjobs j on h.job_id = j.job_id 
where run_status <> 1 --failed
	AND run_date >= CONVERT(varchar,GETDATE()-7,112)
	AND step_name <> '(Job outcome)'
order by run_date desc,run_time desc
--===================