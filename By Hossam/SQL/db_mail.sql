-- Enable advanced options to allow changing the 'Database Mail XPs' setting
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;

-- Enable Database Mail extended stored procedures
EXEC sp_configure 'Database Mail XPs', 1;
RECONFIGURE;

---------------------------------------------------------------
-- Create a Database Mail account
---------------------------------------------------------------
EXEC msdb.dbo.sysmail_add_account_sp
    @account_name = 'MIT',
    @description = 'Mail account for sending emails',
    @email_address = 'sqladmin@example.com',
    @display_name = 'SQL Server Mail',
    @mailserver_name = '192.0.2.10';

---------------------------------------------------------------
-- Create a Database Mail profile
---------------------------------------------------------------
EXEC msdb.dbo.sysmail_add_profile_sp
    @profile_name = 'MIT',
    @description = 'Mail profile for sending emails';

---------------------------------------------------------------
-- Add the account to the profile and set it as default
---------------------------------------------------------------
EXEC msdb.dbo.sysmail_add_profileaccount_sp
    @profile_name = 'MIT', -- Same as above
    @account_name = 'MIT', -- Same as above
    @sequence_number = 1;

EXECUTE msdb.dbo.sysmail_add_principalprofile_sp
@profile_name = 'MIT'
, @principal_name = 'dbo'  
, @is_default = 1;


-- Enable advanced options to allow changing the 'Database Mail XPs' setting
EXEC sp_configure 'show advanced options', 0;
RECONFIGURE;