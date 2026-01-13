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
DECLARE @RunBackup BIT = 1;                                  -- 1 = Create backup, 0 = Skip backup
DECLARE @RunRestore BIT = 1;                                 -- 1 = Restore database, 0 = Skip restore

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
PRINT 'Run Backup: ' + CASE WHEN @RunBackup = 1 THEN 'Yes' ELSE 'No' END;
PRINT 'Run Restore: ' + CASE WHEN @RunRestore = 1 THEN 'Yes' ELSE 'No' END;
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

-- Step 1: Create COPY_ONLY backup
IF @RunBackup = 1
BEGIN
    BEGIN TRY
        PRINT '1. Creating COPY_ONLY backup...';

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
ELSE
BEGIN
    PRINT '1. Skipping backup (RunBackup = 0).';
    PRINT '   Note: Using existing backup file if available.';
    PRINT '';
END

-- Step 2-5: Restore database (if enabled)
IF @RunRestore = 1
BEGIN
    -- Step 2: Drop existing testing database if it exists
    IF EXISTS (SELECT 1 FROM sys.databases WHERE name = @TestingDatabase)
    BEGIN
        PRINT '2. Dropping existing testing database...';

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
        PRINT '2. Testing database does not exist, skipping drop.';
        PRINT '';
    END

    -- Step 3: Get logical file names from backup file (not sys.master_files)
    PRINT '3. Reading database file information from backup...';

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

    -- Create temp table to hold file list from backup
    DECLARE @FileList TABLE (
        LogicalName NVARCHAR(128),
        PhysicalName NVARCHAR(260),
        Type CHAR(1),
        FileGroupName NVARCHAR(128),
        Size NUMERIC(20,0),
        MaxSize NUMERIC(20,0),
        FileID BIGINT,
        CreateLSN NUMERIC(25,0),
        DropLSN NUMERIC(25,0),
        UniqueID UNIQUEIDENTIFIER,
        ReadOnlyLSN NUMERIC(25,0),
        ReadWriteLSN NUMERIC(25,0),
        BackupSizeInBytes BIGINT,
        SourceBlockSize INT,
        FileGroupID INT,
        LogGroupGUID UNIQUEIDENTIFIER,
        DifferentialBaseLSN NUMERIC(25,0),
        DifferentialBaseGUID UNIQUEIDENTIFIER,
        IsReadOnly BIT,
        IsPresent BIT,
        TDEThumbprint VARBINARY(32),
        SnapshotUrl NVARCHAR(360)
    );

    -- Get file list from backup
    INSERT INTO @FileList
    EXEC('RESTORE FILELISTONLY FROM DISK = ''' + @BackupFile + '''');

    -- Build RESTORE command with all MOVE clauses
    DECLARE @MoveClause NVARCHAR(MAX) = '';
    DECLARE @FileCounter INT = 0;
    DECLARE @NewPhysicalPath NVARCHAR(500);
    DECLARE @FileType CHAR(1);
    DECLARE @FileExtension NVARCHAR(10);
    DECLARE @HasFileStream BIT = 0;
    DECLARE @FileStreamDir NVARCHAR(500);

    PRINT '   Files to restore:';

    DECLARE file_cursor CURSOR FOR
    SELECT LogicalName, Type FROM @FileList ORDER BY FileID;

    OPEN file_cursor;
    FETCH NEXT FROM file_cursor INTO @LogicalDataName, @FileType;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Determine file path based on type
        IF @FileType = 'D' -- Data file
        BEGIN
            SET @FileCounter = @FileCounter + 1;
            IF @FileCounter = 1
                SET @FileExtension = '.mdf';
            ELSE
                SET @FileExtension = '_' + CAST(@FileCounter AS NVARCHAR(10)) + '.ndf';

            SET @NewPhysicalPath = @DefaultDataPath + @TestingDatabase + @FileExtension;
        END
        ELSE IF @FileType = 'L' -- Log file
        BEGIN
            SET @NewPhysicalPath = @DefaultLogPath + @TestingDatabase + '_log.ldf';
        END
        ELSE IF @FileType = 'S' -- FILESTREAM
        BEGIN
            -- FILESTREAM path is just the directory, not including the logical file name
            SET @HasFileStream = 1;
            SET @FileStreamDir = @DefaultFileStreamPath;
            SET @NewPhysicalPath = @FileStreamDir;
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
                WHEN 'D' THEN 'Data'
                WHEN 'L' THEN 'Log'
                WHEN 'S' THEN 'FileStream'
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
END
ELSE
BEGIN
    PRINT '2-5. Skipping restore (RunRestore = 0).';
    PRINT '';
END

PRINT '';
PRINT '========================================';
PRINT 'Process completed!';
PRINT '========================================';
