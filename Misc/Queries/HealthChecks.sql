USE [msdb]
GO

/****** Object:  Job [Health Checks]    Script Date: 08/12/2022 10:48:44 AM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]    Script Date: 08/12/2022 10:48:44 AM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'Health Checks', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Backup Check]    Script Date: 08/12/2022 10:48:45 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Backup Check', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DECLARE @SN VARCHAR(100),@Report varchar(100)=''BackupCheck'';
DECLARE @sql NVARCHAR(max),@Query NVARCHAR(max);
DECLARE @startdate VARCHAR(100) = ''DATEADD(MONTH,DATEDIFF(MONTH,0,GETDATE()),0)'' --''CAST(GETDATE()-5 AS date)''

DELETE FROM Health_Check.dbo.BackupCheck WHERE ReportingDate >= CAST(GETDATE() AS DATE)
DELETE FROM Health_Check.dbo.ErrorSummary WHERE ErrorTime >= CAST(GETDATE() AS DATE) AND Report = @Report

DECLARE C CURSOR LOCAL FAST_FORWARD
  FOR SELECT Server_Name  FROM RAK_Servers

OPEN C;

FETCH NEXT FROM C INTO @SN;
WHILE (@@FETCH_STATUS = 0)
BEGIN 
    PRINT @SN;
    -- you could loop here for each database, if you''d define what that is
	SET @Query = ''SELECT CONVERT(CHAR(100), SERVERPROPERTY(''''''''Servername'''''''')) AS Instancename, 
							SERVERPROPERTY(''''''''ComputerNamePhysicalNetBIOS'''''''') Servername,
							d.name [database], 
							x.backup_finish_date last_backup
						FROM sys.databases d
							OUTER APPLY (SELECT TOP 1 backupset.backup_finish_date 
										FROM msdb.dbo.backupset 
										where database_name = d.name
										ORDER BY backup_finish_date desc) x
						WHERE (backup_finish_date < ''+@startdate+'' OR x.backup_finish_date IS NULL)
							AND d.database_id <> 2
						ORDER BY backup_finish_date DESC''

	SET @sql = ''SELECT * FROM OPENQUERY(''+QUOTENAME(@SN)+'',''''''+@Query+'''''')''
	BEGIN TRY
		INSERT INTO [Health_Check].[dbo].[BackupCheck]([Instancename],[Servername],[database],[last_backup])

		EXEC (@sql);
	END TRY
	BEGIN CATCH
		DECLARE @Errors table (ServerName VARCHAR(100),ErrorNumber VARCHAR(100),ErrorSeverity VARCHAR(100),ErrorState VARCHAR(100),ErrorProcedure VARCHAR(100),ErrorLine VARCHAR(100),ErrorMessage VARCHAR(MAX))
		INSERT INTO ErrorSummary(Report,TargetServer,ErrorNumber,ErrorSeverity,ErrorState,ErrorProcedure,ErrorLine,ErrorMessage)
		SELECT  @Report,
			@SN,
			ERROR_NUMBER() AS ErrorNumber  ,
			ERROR_SEVERITY() AS ErrorSeverity , 
			ERROR_STATE() AS ErrorState  ,
			ERROR_PROCEDURE() AS ErrorProcedure  ,
			ERROR_LINE() AS ErrorLine  ,
			ERROR_MESSAGE() AS ErrorMessage; 
	END CATCH
    FETCH NEXT FROM C INTO @SN;
END 
CLOSE C;
DEALLOCATE C;', 
		@database_name=N'Health_Check', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Send Report]    Script Date: 08/12/2022 10:48:45 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Send Report', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DECLARE @EmailBody NVARCHAR(MAX)
	,@EmailRecipients NVARCHAR(200)
	,@EmailSubject NVARCHAR(150)
	,@Query NVARCHAR(MAX)
	,@AttachedFile NVARCHAR(100)
	,@Report NVARCHAR(100)

SELECT @EmailRecipients = ''h.hassan@egac.rak.ae;mohamed.reda@egac.rak.ae''
	,@EmailSubject = ''Backup Check''
	,@Query = ''SET NOCOUNT ON SELECT Instancename,Servername,[database],cast(last_backup as smalldatetime) LastBackup FROM Health_Check.dbo.BackupCheck WHERE ReportingDate >= CAST(GETDATE() AS DATE)''
	,@AttachedFile = ''BackupCheck_''+CAST(CAST(GETDATE() AS date)as nvarchar)+''.csv''
	,@Report = ''BackupCheck''

SELECT @EmailBody = dbo.EmailCSS_Get();
		SET @EmailBody = @EmailBody + N''<h2>Backup Check Error Summary:</h2>'' + CHAR(10) +
				N''<table><tr>'' +
				N''<th>Servername</th>'' +
				N''<th>ErrorNumber</th>'' +
				N''<th>ErrorSeverity</th>'' +
				N''<th>ErrorState</th>'' +
				N''<th>ErrorProcedure</th>'' +
				N''<th>ErrorLine</th>'' +
				N''<th>ErrorMessage</th>'' +
				N''<th>ErrorTime</th>'' +
				N''</tr>'' +
				CAST(( SELECT
							td = TargetServer, '''',
							td = ErrorNumber, '''',   
							td = ErrorSeverity, '''',
							td = ErrorState,'''',
							td = ISNULL(ErrorProcedure,''''),'''',
							td = ErrorLine,'''',
							td = ErrorMessage,'''',
							td = ErrorTime,''''
						FROM Health_Check.dbo.ErrorSummary 
						WHERE ErrorTime >= CAST(GETDATE() AS DATE)
							AND Report = @Report
						FOR XML PATH (''tr''), ELEMENTS
						) AS nvarchar(max)) +
				N''</table>'';
    
		SELECT @EmailBody = @EmailBody + ''<hr>'' + dbo.EmailServerInfo_Get();

		SELECT @EmailBody = REPLACE(@EmailBody,''&lt;'',''<'');
		SELECT @EmailBody = REPLACE(@EmailBody,''&gt;'',''>'');

exec msdb.dbo.sp_send_dbmail  
	--@profile_name = ''DBAdmin'',
	--@from_address = @EmailFrom,
	@recipients = @EmailRecipients,
	@subject = @EmailSubject,
	@body = @EmailBody,
	@body_format = ''HTML'',
	@importance = ''High'',
	@query = @Query, 
	@query_attachment_filename = @AttachedFile, 
	@attach_query_result_as_file = 1, 
	@query_result_header = 1, 
	@query_result_width = 32767, 
	@append_query_error = 0, 
	@query_result_no_padding = 1, 
	@query_result_separator = ''	''; --specify your column delimiter here', 
		@database_name=N'Health_Check', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Performance Report]    Script Date: 08/12/2022 10:48:45 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Performance Report', 
		@step_id=3, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DECLARE @SN VARCHAR(100),@Report varchar(100)=''PerformanceCheck'';
DECLARE @sql NVARCHAR(max),@Query NVARCHAR(max);

DROP TABLE IF EXISTS ##PerformanceCheck;
SELECT TOP 0 SERVERPROPERTY(''Servername'') AS Instancename, 
			SERVERPROPERTY(''ComputerNamePhysicalNetBIOS'') Servername,
			cpu_count,
	x.value_in_use as [MAXDOP],
	FORMAT(physical_memory_kb/POWER(1024,1),''##,##'') System_MemoryMB,
	FORMAT(available_physical_memory_kb/1024,''##,##'') AvailableSystemMemory,
	FORMAT(committed_kb/POWER(1024,1),''##,##'') SQLMemoryUsedMB,
	FORMAT(CAST(y.value_in_use as dec(19,2)),''##,##'') SQLMaxMemoryMB
INTO ##PerformanceCheck
FROM sys.dm_os_sys_info,sys.dm_os_sys_memory,sys.configurations x,sys.configurations y
WHERE x.configuration_id = 1539 AND y.configuration_id = 1544

DELETE FROM Health_Check.dbo.ErrorSummary WHERE ErrorTime >= CAST(GETDATE() AS DATE) AND Report = @Report

DECLARE C CURSOR LOCAL FAST_FORWARD
  FOR SELECT Server_Name  FROM RAK_Servers

OPEN C;

FETCH NEXT FROM C INTO @SN;
WHILE (@@FETCH_STATUS = 0)
BEGIN 
    PRINT @SN;
    -- you could loop here for each database, if you''d define what that is
	SET @Query = ''SELECT SERVERPROPERTY(''''''''Servername'''''''') AS Instancename, 
							SERVERPROPERTY(''''''''ComputerNamePhysicalNetBIOS'''''''') Servername,
							cpu_count,
					x.value_in_use as [MAXDOP],
					FORMAT(physical_memory_kb/POWER(1024,1),''''''''##,##'''''''') System_MemoryMB,
					FORMAT(available_physical_memory_kb/1024,''''''''##,##'''''''') AvailableSystemMemory,
					FORMAT(committed_kb/POWER(1024,1),''''''''##,##'''''''') SQLMemoryUsedMB,
					FORMAT(CAST(y.value_in_use as dec(19,2)),''''''''##,##'''''''') SQLMaxMemoryMB
				FROM sys.dm_os_sys_info,sys.dm_os_sys_memory,sys.configurations x,sys.configurations y
				WHERE x.configuration_id = 1539 AND y.configuration_id = 1544''

	SET @sql = ''SELECT * FROM OPENQUERY(''+QUOTENAME(@SN)+'',''''''+@Query+'''''')''
	BEGIN TRY
		INSERT INTO ##PerformanceCheck

		EXEC (@sql);
	END TRY
	BEGIN CATCH
		DECLARE @Errors table (ServerName VARCHAR(100),ErrorNumber VARCHAR(100),ErrorSeverity VARCHAR(100),ErrorState VARCHAR(100),ErrorProcedure VARCHAR(100),ErrorLine VARCHAR(100),ErrorMessage VARCHAR(MAX))
		INSERT INTO ErrorSummary(Report,TargetServer,ErrorNumber,ErrorSeverity,ErrorState,ErrorProcedure,ErrorLine,ErrorMessage)
		SELECT  @Report,
			@SN,
			ERROR_NUMBER() AS ErrorNumber  ,
			ERROR_SEVERITY() AS ErrorSeverity , 
			ERROR_STATE() AS ErrorState  ,
			ERROR_PROCEDURE() AS ErrorProcedure  ,
			ERROR_LINE() AS ErrorLine  ,
			ERROR_MESSAGE() AS ErrorMessage; 
	END CATCH
    FETCH NEXT FROM C INTO @SN;
END 
CLOSE C;
DEALLOCATE C;
/*****************************************/

/*************Send Report*****************/
DECLARE @EmailBody NVARCHAR(MAX)
	,@EmailRecipients NVARCHAR(200)
	,@EmailSubject NVARCHAR(150)
	,@AttachedFile NVARCHAR(100)

SELECT @EmailRecipients = ''h.hassan@egac.rak.ae;mohamed.reda@egac.rak.ae''
	,@EmailSubject = ''Performance Check''
	,@Query = ''SET NOCOUNT ON SELECT * FROM ##PerformanceCheck''
	,@AttachedFile = ''PerformanceCheck_''+CAST(CAST(GETDATE() AS date)as nvarchar)+''.csv''
	,@Report = ''PerformanceCheck''

SELECT @EmailBody = dbo.EmailCSS_Get();
		SET @EmailBody = @EmailBody + N''<h2>Performance Check Error Summary:</h2>'' + CHAR(10) +
				N''<table><tr>'' +
				N''<th>Servername</th>'' +
				N''<th>ErrorNumber</th>'' +
				N''<th>ErrorSeverity</th>'' +
				N''<th>ErrorState</th>'' +
				N''<th>ErrorProcedure</th>'' +
				N''<th>ErrorLine</th>'' +
				N''<th>ErrorMessage</th>'' +
				N''<th>ErrorTime</th>'' +
				N''</tr>'' +
				CAST(( SELECT
							td = TargetServer, '''',
							td = ErrorNumber, '''',   
							td = ErrorSeverity, '''',
							td = ErrorState,'''',
							td = ISNULL(ErrorProcedure,''''),'''',
							td = ErrorLine,'''',
							td = ErrorMessage,'''',
							td = ErrorTime,''''
						FROM Health_Check.dbo.ErrorSummary 
						WHERE ErrorTime >= CAST(GETDATE() AS DATE)
							AND Report = @Report
						FOR XML PATH (''tr''), ELEMENTS
						) AS nvarchar(max)) +
				N''</table>'';
    
		SELECT @EmailBody = @EmailBody + ''<hr>'' + dbo.EmailServerInfo_Get();

		SELECT @EmailBody = REPLACE(@EmailBody,''&lt;'',''<'');
		SELECT @EmailBody = REPLACE(@EmailBody,''&gt;'',''>'');

exec msdb.dbo.sp_send_dbmail  
	--@profile_name = ''DBAdmin'',
	--@from_address = @EmailFrom,
	@recipients = @EmailRecipients,
	@subject = @EmailSubject,
	@body = @EmailBody,
	@body_format = ''HTML'',
	@importance = ''High'',
	@query = @Query, 
	@query_attachment_filename = @AttachedFile, 
	@attach_query_result_as_file = 1, 
	@query_result_header = 1, 
	@query_result_width = 32767, 
	@append_query_error = 0, 
	@query_result_no_padding = 1, 
	@query_result_separator = ''	''; --specify your column delimiter here', 
		@database_name=N'Health_Check', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'HealthChecks', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20221130, 
		@active_end_date=99991231, 
		@active_start_time=70000, 
		@active_end_time=235959, 
		@schedule_uid=N'7e86ae84-6a37-45f0-b85e-c8eb90b3d6c5'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO

