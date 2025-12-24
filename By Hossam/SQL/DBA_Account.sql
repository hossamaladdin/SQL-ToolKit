DECLARE @username SYSNAME = N'SAAPR\ADM-c.Hossam.Aladdin';
DECLARE @type NVARCHAR(50) = N'Windows';  -- 'SQL' or 'Windows'
DECLARE @password NVARCHAR(128) = N'SecureP@ssw0rd123!';

PRINT 'Setting up: ' + @username;

-- 1. CREATE LOGIN
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = @username)
BEGIN
    DECLARE @sql1 NVARCHAR(MAX) = 'CREATE LOGIN [' + @username + '] ' + CASE WHEN @type = 'SQL' THEN 'WITH PASSWORD = ''' + @password + ''', CHECK_EXPIRATION=OFF, CHECK_POLICY=ON' ELSE 'FROM WINDOWS' END;
    EXEC(@sql1);
    PRINT '✓ Login created';
END ELSE PRINT 'Login exists';

-- 2. MASTER: Server permissions
USE master;
DECLARE @sql2 NVARCHAR(MAX) = 'CREATE USER [' + @username + '] FOR LOGIN [' + @username + ']';
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = @username)
    EXEC(@sql2);

SET @sql2 = 'GRANT VIEW SERVER STATE TO [' + @username + ']';
EXEC(@sql2);
SET @sql2 = 'GRANT VIEW ANY DATABASE TO [' + @username + ']';
EXEC(@sql2);
SET @sql2 = 'GRANT VIEW ANY DEFINITION TO [' + @username + ']';
EXEC(@sql2);
PRINT '✓ Master configured';

-- 3. MSDB: Jobs
USE msdb;
DECLARE @sql4 NVARCHAR(MAX) = 'CREATE USER [' + @username + '] FOR LOGIN [' + @username + ']';
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = @username)
    EXEC(@sql4);

SET @sql4 = 'GRANT SELECT ON sysjobs TO [' + @username + ']';
EXEC(@sql4);
SET @sql4 = 'GRANT SELECT ON sysjobhistory TO [' + @username + ']';
EXEC(@sql4);
SET @sql4 = 'GRANT EXECUTE ON sp_help_job TO [' + @username + ']';
EXEC(@sql4);
PRINT '✓ msdb configured';

PRINT 'COMPLETE! Test: Connect as ' + @username + ' and run SELECT @@VERSION';

-- 4. USER DATABASES
DECLARE @dbname SYSNAME;
DECLARE db_cursor CURSOR FOR SELECT name FROM sys.databases WHERE database_id > 4 AND state = 0;

OPEN db_cursor; FETCH NEXT FROM db_cursor INTO @dbname;
WHILE @@FETCH_STATUS = 0
BEGIN
    DECLARE @sql_db NVARCHAR(MAX) = 'USE [' + @dbname + ']; 
    IF NOT EXISTS(SELECT 1 FROM sys.database_principals WHERE name = ''' + @username + ''')
        CREATE USER [' + @username + '] FOR LOGIN [' + @username + '];
    ALTER ROLE db_datareader ADD MEMBER [' + @username + '];
    GRANT VIEW DATABASE STATE TO [' + @username + '];';
    
    EXEC(@sql_db);
    PRINT '✓ ' + @dbname + ' configured';
    FETCH NEXT FROM db_cursor INTO @dbname;
END
CLOSE db_cursor; DEALLOCATE db_cursor;
