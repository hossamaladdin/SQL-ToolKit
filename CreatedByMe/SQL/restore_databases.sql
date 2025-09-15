-- Enable xp_cmdshell if not already enabled (requires sysadmin)
-- EXEC sp_configure 'xp_cmdshell', 1;
-- RECONFIGURE;

-- Create a temporary table to hold file names
CREATE TABLE #BackupFiles (FileName NVARCHAR(255), Depth INT, IsFile INT);

-- Get list of files from the backup directory using xp_dirtree
INSERT INTO #BackupFiles (FileName, Depth, IsFile)
EXEC xp_dirtree 'L:\MSSQL\BACKUP', 1, 1;

-- Filter to only .bak files
DELETE FROM #BackupFiles WHERE IsFile = 0 OR FileName NOT LIKE '%.bak';

-- Declare variables
DECLARE @FileName NVARCHAR(255);
DECLARE @DatabaseName NVARCHAR(255);
DECLARE @RestoreCommand NVARCHAR(MAX);

-- Cursor to loop through each backup file
DECLARE file_cursor CURSOR FOR
SELECT FileName FROM #BackupFiles;

OPEN file_cursor;
FETCH NEXT FROM file_cursor INTO @FileName;

WHILE @@FETCH_STATUS = 0
BEGIN
    -- Extract the database name (remove the _YYYYMMDD.bak suffix, which is 13 characters)
    SET @DatabaseName = LEFT(@FileName, LEN(@FileName) - 13);

    -- Build the RESTORE command
    SET @RestoreCommand = 'RESTORE DATABASE [' + @DatabaseName + '] FROM DISK = ''L:\MSSQL\BACKUP\' + @FileName + ''';';

    -- Execute the RESTORE command
    EXEC sp_executesql @RestoreCommand;

    -- Fetch next file
    FETCH NEXT FROM file_cursor INTO @FileName;
END

CLOSE file_cursor;
DEALLOCATE file_cursor;

-- Clean up
DROP TABLE #BackupFiles;
