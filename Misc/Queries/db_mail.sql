set nocount on
go

--update operator email
DECLARE @operator varchar(50)
SELECT TOP 1 @operator =  name FROM msdb.dbo.sysoperators

exec  msdb.dbo.sp_update_operator  @name = @operator, @email_address = 'h.hassan@egac.rak.ae;mohamed.reda@egac.rak.ae'
	

--Check last backup
SELECT 
   CONVERT(CHAR(100), SERVERPROPERTY('Servername')) AS Server, 
   d.name [database], 
   x.backup_finish_date last_backup
FROM sys.databases d
	OUTER APPLY (SELECT TOP 1 backupset.backup_finish_date 
				FROM msdb.dbo.backupset 
				where database_name = d.name
				ORDER BY backup_finish_date desc) x
WHERE backup_finish_date < '2022-11-01' OR x.backup_finish_date IS NULL
ORDER BY backup_finish_date DESC
--===================
 
--reassign job owner
USE msdb ;
GO
EXEC dbo.sp_manage_jobs_by_login
@action = N'REASSIGN',
@current_owner_login_name = N'EGA\marco.ramzy',
@new_owner_login_name = N'sa';

EXEC dbo.sp_manage_jobs_by_login
@action = N'REASSIGN',
@current_owner_login_name = N'EGA\marco.ramzy',
@new_owner_login_name = N'sa';

SELECT @@servername as Server,s.name AS JobName, l.name AS JobOwner
FROM msdb..sysjobs s
LEFT JOIN master.sys.syslogins l ON s.owner_sid = l.sid
WHERE l.name like 'EGA\marco.ramzy'
ORDER by l.name
--===================

--check mail account
select @@SERVERNAME FQDN,SERVERPROPERTY('ComputerNamePhysicalNetBIOS') CurrentMachine,@@SERVICENAME Instance,s.* from (select 1)x(x) full join msdb.dbo.sysoperators s on 1=1
exec msdb.dbo.sp_send_dbmail @recipients='h.hassan@egac.rak.ae;mohamed.reda@egac.rak.ae',@subject='testmail 321'

EXECUTE msdb.dbo.sysmail_update_account_sp    @account_name = 'noreply@ega.rak.ae' ,    @display_name = '' ,       @replyto_address =  'h.hassan@egac.rak.ae' ,      @description = ''

SELECT @@SERVERNAME Server,*  FROM msdb.dbo.sysmail_account
--===================

--enable sql agent
use master
go
exec sp_configure 'Show advanced options',1
Go
reconfigure with override
go
exec sp_configure 'Agent XPs',1
Go
reconfigure with override
go

USE [msdb]
GO

declare @name nvarchar(max) 

select @name = name from msdb.dbo.sysmail_profile

EXEC msdb.dbo.sp_set_sqlagent_properties 
		@email_save_in_sent_folder=1, 
		@databasemail_profile=@name
GO
--===================

--enable job notification
USE msdb
GO 



SELECT 'EXEC msdb.dbo.sp_update_job @job_ID = ''' + convert(varchar(50),job_id) 
        + ''' ,@notify_level_email = 2, @notify_email_operator_name = ''' + @operator + '''' 
FROM dbo.sysjobs WHERE notify_email_operator_id = 0
--===================

--find failing jobs
select j.name JobName,
	h.step_name,
	h.run_date,
	h.run_time,
	h.run_duration,
	replace(replace(replace(h.message,char(10),' '),char(9),' '),char(13),' ')message,
	h.server 
from msdb.dbo.sysjobhistory h 
	join msdb.dbo.sysjobs j on h.job_id = j.job_id 
where run_status <> 1 order by run_date desc,run_time desc
--===================
