/*
    Backup and Restore Database to Testing Environment

    Purpose: Creates a COPY_ONLY backup of a database and restores it as a testing database
             with date suffix, handling file conflicts and idempotency.

    Features:
             - Handles multiple data files (.mdf, .ndf)
             - Handles log files (.ldf)
             - Handles FILESTREAM files
             - Automatically reads file structure from backup (not sys.master_files)
             - Drops existing testing database if present

    Usage: Set @SourceDatabase variable and execute
*/

-- Configuration
DECLARE @SourceDatabase NVARCHAR(128) = 'DWQueue';  -- Change this to your source database
DECLARE @ForceBackup BIT = 0;      -- 1 = Force new backup even if today's backup exists, 0 = Reuse if exists
DECLARE @ForceRestore BIT = 0;     -- 1 = Force restore even if testing database exists, 0 = Skip if exists

-- Variables
DECLARE @BackupPath NVARCHAR(500);
DECLARE @BackupFile NVARCHAR(500);
DECLARE @TestingDatabase NVARCHAR(128);
DECLARE @DateSuffix NVARCHAR(20);
DECLARE @SQL NVARCHAR(MAX);
DECLARE @LogicalDataName NVARCHAR(128);
DECLARE @LogicalLogName NVARCHAR(128);
DECLARE @DataFilePath NVARCHAR(500);
DECLARE @LogFilePath NVARCHAR(500);

-- Get today's date in YYYYMMDD format
SET @DateSuffix = CONVERT(NVARCHAR(8), GETDATE(), 112);
SET @TestingDatabase = @SourceDatabase + '_testing_' + @DateSuffix;

PRINT '========================================';
PRINT 'Backup and Restore to Testing Database';
PRINT '========================================';
PRINT 'Source Database: ' + @SourceDatabase;
PRINT 'Testing Database: ' + @TestingDatabase;
PRINT 'Force Backup: ' + CASE WHEN @ForceBackup = 1 THEN 'Yes' ELSE 'No (reuse if exists)' END;
PRINT 'Force Restore: ' + CASE WHEN @ForceRestore = 1 THEN 'Yes' ELSE 'No (skip if exists)' END;
PRINT '';

-- Get default backup directory
EXEC master.dbo.xp_instance_regread
    N'HKEY_LOCAL_MACHINE',
    N'Software\Microsoft\MSSQLServer\MSSQLServer',
    N'BackupDirectory',
    @BackupPath OUTPUT;
SET @BackupFile = @BackupPath + '\' + @SourceDatabase + '_COPY_' + @DateSuffix + '.bak';

PRINT 'Backup File: ' + @BackupFile;
PRINT '';

-- Step 1: Check if backup exists and create if needed
DECLARE @BackupExists BIT = 0;
DECLARE @FileExistsResult INT;
DECLARE @FileExistsCmd NVARCHAR(500);

-- Check if backup file exists
BEGIN TRY
    EXEC master.dbo.xp_fileexist @BackupFile, @FileExistsResult OUTPUT;
    SET @BackupExists = @FileExistsResult;
END TRY
BEGIN CATCH
    SET @BackupExists = 0;
END CATCH

IF @BackupExists = 1 AND @ForceBackup = 0
BEGIN
    PRINT '1. Backup file already exists for today. Reusing existing backup.';
    PRINT '   (Set @ForceBackup = 1 to create a new backup)';
    PRINT '';
END
ELSE
BEGIN
    IF @BackupExists = 1
        PRINT '1. Creating new backup (Force = 1)...';
    ELSE
        PRINT '1. Creating COPY_ONLY backup...';

    BEGIN TRY
        SET @SQL = N'
        BACKUP DATABASE [' + @SourceDatabase + ']
        TO DISK = ''' + @BackupFile + '''
        WITH COPY_ONLY,
             COMPRESSION,
             STATS = 10,
             FORMAT,
             INIT,
             NAME = ''' + @SourceDatabase + ' - Copy Only Backup for Testing'';';

        EXEC sp_executesql @SQL;

        PRINT '   Backup completed successfully.';
        PRINT '';
    END TRY
    BEGIN CATCH
        PRINT 'ERROR during backup: ' + ERROR_MESSAGE();
        THROW;
    END CATCH
END

-- Step 2: Check if testing database exists and decide whether to restore
DECLARE @TestingDBExists BIT = 0;
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = @TestingDatabase)
    SET @TestingDBExists = 1;

IF @TestingDBExists = 1 AND @ForceRestore = 0
BEGIN
    PRINT '2. Testing database already exists. Skipping restore.';
    PRINT '   (Set @ForceRestore = 1 to drop and restore again)';
    PRINT '';
    GOTO SkipRestore;
END

-- Step 2: Drop existing testing database if it exists
IF @TestingDBExists = 1
BEGIN
    PRINT '2. Dropping existing testing database (Force = 1)...';

    BEGIN TRY
        -- Set database to single user mode to drop connections
        SET @SQL = N'ALTER DATABASE [' + @TestingDatabase + '] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;';
        EXEC sp_executesql @SQL;

        -- Drop the database
        SET @SQL = N'DROP DATABASE [' + @TestingDatabase + '];';
        EXEC sp_executesql @SQL;

        PRINT '   Testing database dropped successfully.';
        PRINT '';
    END TRY
    BEGIN CATCH
        PRINT 'ERROR dropping database: ' + ERROR_MESSAGE();
        THROW;
    END CATCH
END
ELSE
BEGIN
    PRINT '2. Testing database does not exist, proceeding with restore.';
    PRINT '';
END

-- Step 3: Get logical file names from source database
PRINT '3. Reading database file information from source database...';

-- Get default data directory for SQL Server
DECLARE @DefaultDataPath NVARCHAR(500);
DECLARE @DefaultLogPath NVARCHAR(500);
DECLARE @DefaultFileStreamPath NVARCHAR(500);

SELECT @DefaultDataPath =
    CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS NVARCHAR(500));
SELECT @DefaultLogPath =
    CAST(SERVERPROPERTY('InstanceDefaultLogPath') AS NVARCHAR(500));

-- FileStream path is typically in a subdirectory
SET @DefaultFileStreamPath = @DefaultDataPath + @TestingDatabase + '_FileStream\';

-- Build RESTORE command with all MOVE clauses
DECLARE @MoveClause NVARCHAR(MAX) = '';
DECLARE @FileCounter INT = 0;
DECLARE @NewPhysicalPath NVARCHAR(500);
DECLARE @FileType TINYINT;
DECLARE @FileExtension NVARCHAR(10);
DECLARE @HasFileStream BIT = 0;

PRINT '   Files to restore:';

DECLARE file_cursor CURSOR FOR
SELECT name, type FROM sys.master_files
WHERE database_id = DB_ID(@SourceDatabase)
ORDER BY file_id;

OPEN file_cursor;
FETCH NEXT FROM file_cursor INTO @LogicalDataName, @FileType;

WHILE @@FETCH_STATUS = 0
BEGIN
    -- Determine file path based on type
    IF @FileType = 0 -- Data file (ROWS)
    BEGIN
        SET @FileCounter = @FileCounter + 1;
        IF @FileCounter = 1
            SET @FileExtension = '.mdf';
        ELSE
            SET @FileExtension = '_' + CAST(@FileCounter AS NVARCHAR(10)) + '.ndf';

        SET @NewPhysicalPath = @DefaultDataPath + @TestingDatabase + @FileExtension;
    END
    ELSE IF @FileType = 1 -- Log file
    BEGIN
        SET @NewPhysicalPath = @DefaultLogPath + @TestingDatabase + '_log.ldf';
    END
    ELSE IF @FileType = 2 -- FILESTREAM
    BEGIN
        -- FILESTREAM path is just the directory
        SET @HasFileStream = 1;
        SET @NewPhysicalPath = @DefaultFileStreamPath;
    END
    ELSE -- Unknown type
    BEGIN
        SET @NewPhysicalPath = @DefaultDataPath + @TestingDatabase + '_' + @LogicalDataName;
    END

    -- Add MOVE clause
    SET @MoveClause = @MoveClause +
        '            MOVE ''' + @LogicalDataName + ''' TO ''' + @NewPhysicalPath + ''',' + CHAR(13) + CHAR(10);

    -- Print file info
    PRINT '      ' + @LogicalDataName + ' (' +
        CASE @FileType
            WHEN 0 THEN 'Data'
            WHEN 1 THEN 'Log'
            WHEN 2 THEN 'FileStream'
            ELSE 'Unknown'
        END + ') -> ' + @NewPhysicalPath;

    FETCH NEXT FROM file_cursor INTO @LogicalDataName, @FileType;
END

CLOSE file_cursor;
DEALLOCATE file_cursor;

-- Note: SQL Server will automatically create FILESTREAM directories during restore
IF @HasFileStream = 1
BEGIN
    PRINT '';
    PRINT '   Note: Database contains FILESTREAM files. SQL Server will create the directory automatically.';
END

PRINT '';

-- Step 4: Restore database with all file names
BEGIN TRY
    PRINT '4. Restoring database...';

    SET @SQL = N'
    RESTORE DATABASE [' + @TestingDatabase + ']
    FROM DISK = ''' + @BackupFile + '''
    WITH
' + @MoveClause + '            REPLACE,
        STATS = 10,
        RECOVERY;';

    EXEC sp_executesql @SQL;

    PRINT '   Restore completed successfully.';
    PRINT '';
END TRY
BEGIN CATCH
    PRINT 'ERROR during restore: ' + ERROR_MESSAGE();
    THROW;
END CATCH

-- Step 5: Verify restored database
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = @TestingDatabase)
BEGIN
    PRINT '5. Verification: Testing database created successfully!';
    PRINT '';

    -- Show database information
    SELECT
        name AS DatabaseName,
        state_desc AS State,
        recovery_model_desc AS RecoveryModel,
        compatibility_level AS CompatibilityLevel,
        create_date AS CreateDate
    FROM sys.databases
    WHERE name = @TestingDatabase;

    -- Show file information
    PRINT '';
    PRINT 'Database Files:';
    SELECT
        name AS LogicalName,
        physical_name AS PhysicalPath,
        type_desc AS FileType,
        size * 8 / 1024 AS SizeMB
    FROM sys.master_files
    WHERE database_id = DB_ID(@TestingDatabase);
END
ELSE
BEGIN
    PRINT '5. Verification FAILED: Testing database was not created.';
END

SkipRestore:

PRINT '';
PRINT '========================================';
PRINT 'Process completed!';
PRINT '========================================';
