 
use master 
go 
sp_configure 'show advanced options',1 
go 
reconfigure with override 
go 
sp_configure 'Database Mail XPs',1 
--go 
--sp_configure 'SQL Mail XPs',0 
go 
reconfigure 
go 
 
-------------------------------------------------------------------------------------------------- 
-- BEGIN Mail Settings Alert And Notification 
-------------------------------------------------------------------------------------------------- 
IF NOT EXISTS(SELECT * FROM msdb.dbo.sysmail_profile WHERE  name = 'Alert And Notification')  
  BEGIN 
    --CREATE Profile [Alert And Notification] 
    EXECUTE msdb.dbo.sysmail_add_profile_sp 
      @profile_name = 'Alert And Notification', 
      @description  = ''; 
  END --IF EXISTS profile 
   
  IF NOT EXISTS(SELECT * FROM msdb.dbo.sysmail_account WHERE  name = 'noreply@ega.rak.ae') 
  BEGIN 
    --CREATE Account [noreply@ega.rak.ae] 
    EXECUTE msdb.dbo.sysmail_add_account_sp 
    @account_name            = 'noreply@ega.rak.ae', 
    @email_address           = 'noreply@ega.rak.ae', 
    @display_name            = 'SQLalert@DEDLICPRD3', 
    @replyto_address         = '', 
    @description             = 'SQLalert@DEDLICPRD3', 
    @mailserver_name         = '10.3.3.95', 
    @mailserver_type         = 'SMTP', 
    @port                    = '25', 
    @username                = 'noreply@ega.rak.ae', 
    @password                = 'NotTheRealPassword',  
    @use_default_credentials =  0 , 
    @enable_ssl              =  0 ; 
  END --IF EXISTS  account 
   
IF NOT EXISTS(SELECT * 
              FROM msdb.dbo.sysmail_profileaccount pa 
                INNER JOIN msdb.dbo.sysmail_profile p ON pa.profile_id = p.profile_id 
                INNER JOIN msdb.dbo.sysmail_account a ON pa.account_id = a.account_id   
              WHERE p.name = 'Alert And Notification' 
                AND a.name = 'noreply@ega.rak.ae')  
  BEGIN 
    -- Associate Account [noreply@ega.rak.ae] to Profile [Alert And Notification] 
    EXECUTE msdb.dbo.sysmail_add_profileaccount_sp 
      @profile_name = 'Alert And Notification', 
      @account_name = 'noreply@ega.rak.ae', 
      @sequence_number = 1 ; 
  END  

EXECUTE msdb.dbo.sysmail_add_principalprofile_sp
    @profile_name = 'Alert And Notification',
    @principal_name = 'public',
    @is_default = 1;
GO

USE [msdb]
GO

/****** Object:  Operator [SQL Jobs DEDLICPRD3]    Script Date: 10/12/2022 1:36:35 PM ******/
EXEC msdb.dbo.sp_add_operator @name=N'DatabaseTeam', 
		@enabled=1, 
		@weekday_pager_start_time=90000, 
		@weekday_pager_end_time=180000, 
		@saturday_pager_start_time=90000, 
		@saturday_pager_end_time=180000, 
		@sunday_pager_start_time=90000, 
		@sunday_pager_end_time=180000, 
		@pager_days=0, 
		@email_address=N'marco.ramzy@egac.rak.ae;h.hassan@egac.rak.ae', 
		@category_name=N'[Uncategorized]'
GO