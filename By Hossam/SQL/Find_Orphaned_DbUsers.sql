/*
    Find Orphaned Database Users and Their Roles

    Orphaned users are database users that don't have a corresponding SQL Server login.
    This typically happens after restoring a database from another server.
*/

SET NOCOUNT ON;

-- Create temp table to store results
IF OBJECT_ID('tempdb..#OrphanedUsers') IS NOT NULL
    DROP TABLE #OrphanedUsers;

CREATE TABLE #OrphanedUsers (
    DatabaseName NVARCHAR(128),
    UserName NVARCHAR(128),
    UserSID VARBINARY(85),
    UserType NVARCHAR(60),
    RoleName NVARCHAR(128),
    DefaultSchema NVARCHAR(128)
);

-- Declare variables
DECLARE @DatabaseName NVARCHAR(128);
DECLARE @SQL NVARCHAR(MAX);

-- Cursor to loop through all user databases
DECLARE db_cursor CURSOR FOR
SELECT name
FROM sys.databases
WHERE state_desc = 'ONLINE'
    AND name NOT IN ('master', 'tempdb', 'model', 'msdb')
    AND HAS_DBACCESS(name) = 1;

OPEN db_cursor;
FETCH NEXT FROM db_cursor INTO @DatabaseName;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @SQL = '
    USE [' + @DatabaseName + '];

    INSERT INTO #OrphanedUsers (DatabaseName, UserName, UserSID, UserType, RoleName, DefaultSchema)
    SELECT
        ''' + @DatabaseName + ''' AS DatabaseName,
        dp.name AS UserName,
        dp.sid AS UserSID,
        dp.type_desc AS UserType,
        ISNULL(roles.RoleName, ''No role membership'') AS RoleName,
        dp.default_schema_name AS DefaultSchema
    FROM sys.database_principals dp
    LEFT JOIN sys.server_principals sp ON dp.sid = sp.sid
    LEFT JOIN (
        SELECT
            drm.member_principal_id,
            STRING_AGG(dpr.name, '', '') AS RoleName
        FROM sys.database_role_members drm
        INNER JOIN sys.database_principals dpr ON drm.role_principal_id = dpr.principal_id
        GROUP BY drm.member_principal_id
    ) roles ON dp.principal_id = roles.member_principal_id
    WHERE dp.type IN (''S'', ''U'', ''G'')  -- SQL user, Windows user, Windows group
        AND dp.sid IS NOT NULL
        AND dp.sid NOT IN (0x00, 0x01)
        AND dp.name NOT IN (''guest'', ''INFORMATION_SCHEMA'', ''sys'', ''dbo'')
        AND sp.sid IS NULL  -- No matching server login = orphaned
    ORDER BY dp.name;
    ';

    BEGIN TRY
        EXEC sp_executesql @SQL;
    END TRY
    BEGIN CATCH
        PRINT 'Error processing database: ' + @DatabaseName;
        PRINT ERROR_MESSAGE();
    END CATCH

    FETCH NEXT FROM db_cursor INTO @DatabaseName;
END

CLOSE db_cursor;
DEALLOCATE db_cursor;

-- Display results
IF EXISTS (SELECT 1 FROM #OrphanedUsers)
BEGIN
    PRINT '========================================';
    PRINT 'ORPHANED USERS FOUND';
    PRINT '========================================';
    PRINT '';

    SELECT
        DatabaseName,
        UserName,
        UserType,
        RoleName,
        DefaultSchema,
        CONVERT(VARCHAR(MAX), UserSID, 1) AS UserSID_Hex
    FROM #OrphanedUsers
    ORDER BY DatabaseName, UserName, RoleName;

    PRINT '';
    PRINT '========================================';
    PRINT 'SUMMARY';
    PRINT '========================================';

    SELECT
        DatabaseName,
        COUNT(DISTINCT UserName) AS OrphanedUserCount
    FROM #OrphanedUsers
    GROUP BY DatabaseName
    ORDER BY OrphanedUserCount DESC, DatabaseName;
END
ELSE
BEGIN
    PRINT 'No orphaned users found.';
END

-- Cleanup
DROP TABLE #OrphanedUsers;
