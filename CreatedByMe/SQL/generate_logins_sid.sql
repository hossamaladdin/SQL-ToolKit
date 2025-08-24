SET NOCOUNT ON;
DECLARE @SQL NVARCHAR(MAX) = '';
DECLARE @name sysname, @password_hash varbinary(256), @sid varbinary(85), 
        @default_database_name sysname, @is_policy_checked bit, @is_expiration_checked bit;

DECLARE login_cursor CURSOR FOR
SELECT name, password_hash, sid, default_database_name, is_policy_checked, is_expiration_checked
FROM sys.sql_logins WHERE name not like '##%' and name not like 'sa%'
ORDER BY name;

OPEN login_cursor;
FETCH NEXT FROM login_cursor INTO @name, @password_hash, @sid, @default_database_name, @is_policy_checked, @is_expiration_checked;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @SQL = @SQL + '
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = ''' + @name + ''')
    DROP LOGIN [' + @name + '];

CREATE LOGIN [' + @name + '] 
WITH PASSWORD = 0x' + CONVERT(NVARCHAR(MAX), @password_hash, 2) + ' HASHED, 
SID = ' + CASE WHEN DATALENGTH(@sid) = 16 THEN '0x' + CONVERT(NVARCHAR(MAX), @sid, 2) ELSE 'NULL' END + ',
DEFAULT_DATABASE = [' + @default_database_name + '], 
CHECK_POLICY = ' + CASE @is_policy_checked WHEN 1 THEN 'ON' ELSE 'OFF' END + ',
CHECK_EXPIRATION = ' + CASE @is_expiration_checked WHEN 1 THEN 'ON' ELSE 'OFF' END + ';
';

    FETCH NEXT FROM login_cursor INTO @name, @password_hash, @sid, @default_database_name, @is_policy_checked, @is_expiration_checked;
END

CLOSE login_cursor;
DEALLOCATE login_cursor;

SELECT @SQL;
-- EXEC sp_executesql @SQL;  -- Uncomment to execute
/*************/

SELECT 
    name AS LoginName,
    sid AS SID
FROM sys.sql_logins
ORDER BY name;
