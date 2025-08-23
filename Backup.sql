
-- T-SQL Script to Backup All User Databases with Date Suffix
-- This script excludes system databases and creates backups with timestamp

DECLARE @DatabaseName NVARCHAR(128)
DECLARE @BackupPath NVARCHAR(500)
DECLARE @BackupFileName NVARCHAR(500)
DECLARE @BackupCommand NVARCHAR(1000)
DECLARE @DateString NVARCHAR(20)

-- Set the backup directory path (modify as needed)
SET @BackupPath = 'E:\Backup\'

-- Generate date string in YYYYMMDD format
SET @DateString = CONVERT(VARCHAR(8), GETDATE(), 112)

-- Cursor to iterate through all user databases
DECLARE db_cursor CURSOR FOR
SELECT name
FROM sys.databases
WHERE database_id > 4  -- Excludes system databases (master, model, msdb, tempdb)
AND state = 0          -- Only online databases
--AND name NOT IN ('ReportServer', 'ReportServerTempDB')  -- Exclude SSRS databases if present

OPEN db_cursor
FETCH NEXT FROM db_cursor INTO @DatabaseName

WHILE @@FETCH_STATUS = 0
BEGIN
    -- Construct backup file name with date
    SET @BackupFileName = @BackupPath + @DatabaseName + '_' + @DateString + '.bak'
    
    -- Construct backup command
    SET @BackupCommand = 'BACKUP DATABASE [' + @DatabaseName + '] TO DISK = ''' + @BackupFileName + ''' 
    WITH FORMAT, COPY_ONLY, COMPRESSION, CHECKSUM, STATS = 10'
    
    -- Print the command for verification
    PRINT 'Backing up database: ' + @DatabaseName
    PRINT 'Command: ' + @BackupCommand
    
    -- Execute the backup
    BEGIN TRY
        EXEC sp_executesql @BackupCommand
        PRINT 'SUCCESS: Backup completed for ' + @DatabaseName
        PRINT '----------------------------------------'
    END TRY
    BEGIN CATCH
        PRINT 'ERROR: Backup failed for ' + @DatabaseName
        PRINT 'Error Message: ' + ERROR_MESSAGE()
        PRINT '----------------------------------------'
    END CATCH
    
    FETCH NEXT FROM db_cursor INTO @DatabaseName
END

CLOSE db_cursor
DEALLOCATE db_cursor

PRINT 'Backup process completed for all user databases.'