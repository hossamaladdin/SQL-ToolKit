EXEC sp_MSforeachdb '
USE [?];
IF ''?'' NOT IN (''master'', ''model'', ''msdb'', ''tempdb'')
BEGIN
    PRINT ''Processing database: ?'';

    -- Create user if it does not exist
    IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = ''IC_Admin'')
    BEGIN
        CREATE USER [IC_Admin] FOR LOGIN [IC_Admin];
        PRINT '' - Created IC_Admin user'';
    END

    -- Create db_executor role if it does not exist
    IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = ''db_executor'')
    BEGIN
        CREATE ROLE [db_executor];
        GRANT EXECUTE TO [db_executor];
        PRINT '' - Created db_executor role'';
    END

    -- Add to roles only if not already a member
    IF NOT EXISTS (SELECT 1 FROM sys.database_role_members rm 
                   JOIN sys.database_principals r ON rm.role_principal_id = r.principal_id
                   JOIN sys.database_principals m ON rm.member_principal_id = m.principal_id
                   WHERE r.name = ''db_datareader'' AND m.name = ''IC_Admin'')
    BEGIN
        EXEC sp_addrolemember ''db_datareader'', ''IC_Admin'';
        PRINT '' - Added to db_datareader'';
    END

    IF NOT EXISTS (SELECT 1 FROM sys.database_role_members rm 
                   JOIN sys.database_principals r ON rm.role_principal_id = r.principal_id
                   JOIN sys.database_principals m ON rm.member_principal_id = m.principal_id
                   WHERE r.name = ''db_datawriter'' AND m.name = ''IC_Admin'')
    BEGIN
        EXEC sp_addrolemember ''db_datawriter'', ''IC_Admin'';
        PRINT '' - Added to db_datawriter'';
    END

    IF NOT EXISTS (SELECT 1 FROM sys.database_role_members rm 
                   JOIN sys.database_principals r ON rm.role_principal_id = r.principal_id
                   JOIN sys.database_principals m ON rm.member_principal_id = m.principal_id
                   WHERE r.name = ''db_ddladmin'' AND m.name = ''IC_Admin'')
    BEGIN
        EXEC sp_addrolemember ''db_ddladmin'', ''IC_Admin'';
        PRINT '' - Added to db_ddladmin'';
    END

    IF NOT EXISTS (SELECT 1 FROM sys.database_role_members rm 
                   JOIN sys.database_principals r ON rm.role_principal_id = r.principal_id
                   JOIN sys.database_principals m ON rm.member_principal_id = m.principal_id
                   WHERE r.name = ''db_executor'' AND m.name = ''IC_Admin'')
    BEGIN
        EXEC sp_addrolemember ''db_executor'', ''IC_Admin'';
        PRINT '' - Added to db_executor'';
    END

    PRINT ''Completed permissions for ?'';
END
ELSE
    PRINT ''Skipping system database: ?'';
';