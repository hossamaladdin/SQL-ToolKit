-- =====================================================
-- Grafana User Creation Script - Always On AG Aware
-- =====================================================
USE [master];

-- Parameters (set these before running)
DECLARE @UserSID VARBINARY(85) = 0x87B135D2146D3840B229D12CCEB3DF10;  -- Default Grafana User SID
DECLARE @ShowSID BIT = 0;               -- Set to 1 to display SID after creation

-- =====================================================
-- AG Role Detection and Validation
-- =====================================================
DECLARE @AGRole NVARCHAR(20) = 'STANDALONE';
DECLARE @AGName NVARCHAR(128) = NULL;
DECLARE @IsAGEnabled BIT = 0;

-- Check if Always On is enabled and get role
IF EXISTS (SELECT 1 FROM sys.availability_groups)
BEGIN
    SET @IsAGEnabled = 1;
    
    -- Get AG role and name using correct column names
    SELECT TOP 1 
        @AGRole = CASE 
            WHEN ars.role = 1 THEN 'PRIMARY'
            WHEN ars.role = 2 THEN 'SECONDARY'
            ELSE 'UNKNOWN'
        END,
        @AGName = ag.name
    FROM sys.dm_hadr_availability_replica_states ars
    INNER JOIN sys.availability_replicas ar ON ars.replica_id = ar.replica_id
    INNER JOIN sys.availability_groups ag ON ar.group_id = ag.group_id
    WHERE ar.replica_server_name = @@SERVERNAME
    AND ars.is_local = 1;
END

PRINT '=====================================================';
PRINT 'Server: ' + @@SERVERNAME;
PRINT 'AG Status: ' + CASE WHEN @IsAGEnabled = 1 THEN 'ENABLED' ELSE 'DISABLED' END;
PRINT 'AG Role: ' + @AGRole;
IF @AGName IS NOT NULL PRINT 'AG Name: ' + @AGName;
PRINT '=====================================================';

-- =====================================================
-- Secondary Replica Validation
-- =====================================================
IF @AGRole = 'SECONDARY' AND @UserSID IS NULL
BEGIN
    PRINT '';
    PRINT '⚠️  WARNING: This script is running on a SECONDARY replica!';
    PRINT '';
    PRINT 'The @UserSID parameter is NULL. Please set it to the standard SID:';
    PRINT 'DECLARE @UserSID VARBINARY(85) = 0x87B135D2146D3840B229D12CCEB3DF10;';
    PRINT '';
    PRINT 'Or use the SID from your PRIMARY replica if different.';
    PRINT '';
    PRINT 'Script execution STOPPED.';
    RETURN;
END

-- Show which SID will be used
IF @UserSID IS NOT NULL
BEGIN
    PRINT 'Using SID: ' + CONVERT(NVARCHAR(MAX), @UserSID, 1);
    IF @UserSID = 0x87B135D2146D3840B229D12CCEB3DF10
        PRINT '(Standard Grafana User SID)';
    PRINT '';
END

-- =====================================================
-- Login Creation (Server Level) with SID Validation
-- =====================================================
USE [master];

PRINT 'Creating login [Grafana_User]...';

-- Check for existing login and validate SID if needed
DECLARE @ExistingLoginSID VARBINARY(85) = NULL;
DECLARE @SIDMismatch BIT = 0;

SELECT @ExistingLoginSID = sid 
FROM sys.server_principals 
WHERE name = 'Grafana_User';

-- Validate SID mismatch scenarios
IF @ExistingLoginSID IS NOT NULL AND @UserSID IS NOT NULL
BEGIN
    IF @ExistingLoginSID != @UserSID
    BEGIN
        SET @SIDMismatch = 1;
        PRINT '';
        PRINT '⚠️  WARNING: Login [Grafana_User] exists with different SID!';
        PRINT 'Existing SID: ' + CONVERT(NVARCHAR(MAX), @ExistingLoginSID, 1);
        PRINT 'Required SID:  ' + CONVERT(NVARCHAR(MAX), @UserSID, 1);
        PRINT 'This will cause orphaned users in databases.';
        PRINT 'Dropping existing login and recreating with correct SID...';
        PRINT '';
    END
    ELSE
    BEGIN
        PRINT 'Login already exists with correct SID - skipping creation.';
    END
END
ELSE IF @ExistingLoginSID IS NOT NULL AND @UserSID IS NULL
BEGIN
    PRINT 'Login already exists - will use existing SID.';
END

-- Drop existing login if it exists and we have a SID mismatch or need to recreate
IF @ExistingLoginSID IS NOT NULL AND (@SIDMismatch = 1 OR @UserSID IS NULL)
BEGIN
    PRINT 'Dropping existing login...';
    DROP LOGIN [Grafana_User];
    SET @ExistingLoginSID = NULL;
END

-- Create login if it doesn't exist or was dropped
IF @ExistingLoginSID IS NULL
BEGIN
    PRINT 'Creating login with SID: ' + CONVERT(NVARCHAR(MAX), @UserSID, 1);
    IF @UserSID = 0x87B135D2146D3840B229D12CCEB3DF10
        PRINT '(Using standard Grafana User SID)';
    
    DECLARE @CreateLoginSQL NVARCHAR(1000) = 
        'CREATE LOGIN [Grafana_User] 
         WITH PASSWORD = ''12345'', 
              SID = ' + CONVERT(NVARCHAR(MAX), @UserSID, 1) + ',
              CHECK_POLICY = OFF, 
              CHECK_EXPIRATION = OFF;';
    EXEC sp_executesql @CreateLoginSQL;
END

-- Grant server-level permissions
PRINT 'Granting server-level permissions...';
GRANT VIEW SERVER STATE TO [Grafana_User];
GRANT VIEW ANY DEFINITION TO [Grafana_User];
GRANT VIEW ANY DATABASE TO [Grafana_User];

-- =====================================================
-- Master Database User Creation with Orphan Handling
-- =====================================================
PRINT 'Creating user in master database...';

-- Check for orphaned user (user exists but login SID doesn't match)
DECLARE @MasterUserSID VARBINARY(85) = NULL;
DECLARE @CurrentLoginSID VARBINARY(85);
DECLARE @IsOrphanedUser BIT = 0;

-- Get current login SID
SELECT @CurrentLoginSID = sid FROM sys.server_principals WHERE name = 'Grafana_User';

-- Check if user exists and get its SID
SELECT @MasterUserSID = dp.sid
FROM sys.database_principals dp 
WHERE dp.name = 'Grafana_User' AND dp.type = 'S';

-- Check if user is orphaned
IF @MasterUserSID IS NOT NULL AND @MasterUserSID != @CurrentLoginSID
BEGIN
    SET @IsOrphanedUser = 1;
    PRINT '  - Found orphaned user in master database - fixing...';
    DROP USER [Grafana_User];
    SET @MasterUserSID = NULL;
END
ELSE IF @MasterUserSID IS NOT NULL
BEGIN
    PRINT '  - User already exists with correct SID in master database.';
END

-- Create user if it doesn't exist or was orphaned
IF @MasterUserSID IS NULL
BEGIN
    CREATE USER [Grafana_User] FOR LOGIN [Grafana_User];
    ALTER ROLE [db_datareader] ADD MEMBER [Grafana_User];
    PRINT '  - Created user in master database.';
END

-- =====================================================
-- MSDB Database User Creation with Orphan Handling
-- =====================================================
PRINT 'Creating user in msdb database...';

DECLARE @msdbSQL NVARCHAR(MAX) = '
DECLARE @MsdbUserSID VARBINARY(85) = NULL;
DECLARE @CurrentLoginSID VARBINARY(85);
DECLARE @IsOrphanedUser BIT = 0;

-- Get current login SID
SELECT @CurrentLoginSID = sid FROM sys.server_principals WHERE name = ''Grafana_User'';

-- Check if user exists and get its SID
SELECT @MsdbUserSID = dp.sid
FROM sys.database_principals dp 
WHERE dp.name = ''Grafana_User'' AND dp.type = ''S'';

-- Check if user is orphaned
IF @MsdbUserSID IS NOT NULL AND @MsdbUserSID != @CurrentLoginSID
BEGIN
    PRINT ''  - Found orphaned user in msdb database - fixing...'';
    DROP USER [Grafana_User];
    SET @MsdbUserSID = NULL;
END
ELSE IF @MsdbUserSID IS NOT NULL
BEGIN
    PRINT ''  - User already exists with correct SID in msdb database.'';
END

-- Create user if it doesn''t exist or was orphaned
IF @MsdbUserSID IS NULL
BEGIN
    CREATE USER [Grafana_User] FOR LOGIN [Grafana_User];
    ALTER ROLE [db_datareader] ADD MEMBER [Grafana_User];
    PRINT ''  - Created user in msdb database.'';
END
';

EXEC sp_executesql @msdbSQL;

-- =====================================================
-- User Creation in User Databases (AG-aware) using Cursor
-- =====================================================
USE [master];

IF @AGRole = 'SECONDARY'
BEGIN
    PRINT 'Secondary replica detected - only processing NON-AG databases...';
    PRINT '(AG database users will be synced from primary)';
END
ELSE
BEGIN
    PRINT 'Creating users in all user databases...';
END

DECLARE @DatabaseName NVARCHAR(128);
DECLARE @dbCount INT = 0;
DECLARE @skippedAGDbs INT = 0;
DECLARE @ProcessSQL NVARCHAR(MAX);

-- Create cursor based on AG role
DECLARE db_cursor CURSOR FOR
SELECT d.name
FROM sys.databases d
WHERE d.database_id > 4  -- Skip system databases
    AND d.state = 0      -- Only online databases  
    AND d.name NOT IN ('tempdb')
    AND (
        @AGRole != 'SECONDARY' OR  -- If not secondary, process all
        NOT EXISTS (              -- If secondary, exclude AG databases
            SELECT 1 
            FROM sys.availability_databases_cluster adc
            WHERE adc.database_name = d.name
        )
    );

OPEN db_cursor;
FETCH NEXT FROM db_cursor INTO @DatabaseName;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @ProcessSQL = '
    USE [' + @DatabaseName + '];
    
    DECLARE @UserSID VARBINARY(85) = NULL;
    DECLARE @LoginSID VARBINARY(85);
    
    -- Get current login SID
    SELECT @LoginSID = sid FROM sys.server_principals WHERE name = ''Grafana_User'';
    
    -- Check if user exists and get its SID
    SELECT @UserSID = dp.sid
    FROM sys.database_principals dp 
    WHERE dp.name = ''Grafana_User'' AND dp.type = ''S'';
    
    -- Handle orphaned user
    IF @UserSID IS NOT NULL AND @UserSID != @LoginSID
    BEGIN
        PRINT ''  - Found orphaned user in ' + @DatabaseName + ' - fixing...'';
        DROP USER [Grafana_User];
        SET @UserSID = NULL;
    END
    ELSE IF @UserSID IS NOT NULL
    BEGIN
        PRINT ''  - User already exists with correct SID in: ' + @DatabaseName + ''';
    END
    
    -- Create user if needed
    IF @UserSID IS NULL
    BEGIN
        PRINT ''  - Adding user to database: ' + @DatabaseName + ''';
        CREATE USER [Grafana_User] FOR LOGIN [Grafana_User];
        ALTER ROLE [db_datareader] ADD MEMBER [Grafana_User];
        GRANT VIEW DATABASE STATE TO [Grafana_User];
    END
    ';
    
    -- Execute the SQL for this database
    EXEC sp_executesql @ProcessSQL;
    
    SET @dbCount = @dbCount + 1;
    FETCH NEXT FROM db_cursor INTO @DatabaseName;
END

CLOSE db_cursor;
DEALLOCATE db_cursor;

-- Count skipped AG databases if on secondary
IF @AGRole = 'SECONDARY'
BEGIN
    SELECT @skippedAGDbs = COUNT(*)
    FROM sys.databases d
    WHERE d.database_id > 4 
        AND d.state = 0 
        AND d.name NOT IN ('tempdb')
        AND EXISTS (
            SELECT 1 
            FROM sys.availability_databases_cluster adc
            WHERE adc.database_name = d.name
        );
END

-- Report results
IF @AGRole = 'SECONDARY'
BEGIN
    PRINT 'Processing completed: ' + CAST(@dbCount AS VARCHAR(10)) + ' standalone databases processed.';
    IF @skippedAGDbs > 0
        PRINT 'Skipped ' + CAST(@skippedAGDbs AS VARCHAR(10)) + ' AG databases (will be synced from primary).';
END
ELSE
BEGIN
    PRINT 'Processing completed: ' + CAST(@dbCount AS VARCHAR(10)) + ' user databases processed.';
END

-- =====================================================
-- Display Results and SID Information
-- =====================================================
PRINT '';
PRINT '=====================================================';
PRINT 'SCRIPT EXECUTION COMPLETED SUCCESSFULLY';
PRINT '=====================================================';

-- Always show the SID being used
DECLARE @LoginSID VARBINARY(85);

SELECT @LoginSID = sid 
FROM sys.server_principals 
WHERE name = 'Grafana_User';

PRINT '';
PRINT '📋 GRAFANA USER SID:';
PRINT 'SID: ' + CONVERT(NVARCHAR(MAX), @LoginSID, 1);

IF @LoginSID = 0x87B135D2146D3840B229D12CCEB3DF10
BEGIN
    PRINT '✅ Using standard Grafana User SID';
END
ELSE
BEGIN
    PRINT '⚠️  Using custom SID - ensure this matches across all replicas';
    PRINT '';
    PRINT 'To use this SID on other servers:';
    PRINT 'DECLARE @UserSID VARBINARY(85) = ' + CONVERT(NVARCHAR(MAX), @LoginSID, 1) + ';';
END

PRINT '';

PRINT 'User [Grafana_User] has been successfully created with:';
PRINT '• Server-level permissions: VIEW SERVER STATE, VIEW ANY DEFINITION, VIEW ANY DATABASE';
PRINT '• Database access: db_datareader role in master, msdb, and all user databases';
PRINT '• Database permission: VIEW DATABASE STATE in all user databases';
PRINT '';

-- Final validation
DECLARE @UserDatabases INT = 0;
DECLARE @AGDatabases INT = 0;

-- Count standalone databases where user was created
IF @AGRole = 'SECONDARY'
BEGIN
    -- Count only non-AG databases
    SELECT @UserDatabases = COUNT(*)
    FROM sys.databases d
    WHERE d.database_id > 4 
      AND d.state = 0 
      AND d.name NOT IN ('tempdb')
      AND NOT EXISTS (
          SELECT 1 
          FROM sys.availability_databases_cluster adc
          WHERE adc.database_name = d.name
      );
      
    -- Count AG databases that were skipped
    SELECT @AGDatabases = COUNT(*)
    FROM sys.databases d
    WHERE d.database_id > 4 
      AND d.state = 0 
      AND d.name NOT IN ('tempdb')
      AND EXISTS (
          SELECT 1 
          FROM sys.availability_databases_cluster adc
          WHERE adc.database_name = d.name
      );
      
    PRINT 'Verification: User created in ' + CAST(@UserDatabases + 2 AS VARCHAR(10)) + ' databases (master, msdb, + ' + CAST(@UserDatabases AS VARCHAR(10)) + ' standalone).';
    IF @AGDatabases > 0
        PRINT 'Note: ' + CAST(@AGDatabases AS VARCHAR(10)) + ' AG databases were skipped (users will sync from primary).';
END
ELSE
BEGIN
    -- Count all user databases
    SELECT @UserDatabases = COUNT(*)
    FROM sys.databases d
    WHERE d.database_id > 4 
      AND d.state = 0 
      AND d.name NOT IN ('tempdb');
      
    PRINT 'Verification: User created in ' + CAST(@UserDatabases + 2 AS VARCHAR(10)) + ' databases (master, msdb, + ' + CAST(@UserDatabases AS VARCHAR(10)) + ' user databases).';
END
PRINT '=====================================================';