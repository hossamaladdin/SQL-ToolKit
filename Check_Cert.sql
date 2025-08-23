-- Check SQL Error Log for certificate entries
EXEC sp_readerrorlog 0, 1, 'certificate';
GO

-- Enable xp_cmdshell
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
EXEC sp_configure 'xp_cmdshell', 1; RECONFIGURE;

-- Get instance info
DECLARE @InstanceName NVARCHAR(128) = CAST(SERVERPROPERTY('InstanceName') AS NVARCHAR(128)),
        @MajorVersion INT = CAST(SERVERPROPERTY('ProductMajorVersion') AS INT),
        @InstanceId NVARCHAR(128),
        @Thumbprint NVARCHAR(1000),
        @FinalPath NVARCHAR(512),
        @Found BIT = 0,
        @cmd BIT = 0; -- Default to 0 (disabled)

-- Determine instance ID
IF @InstanceName IS NULL
    SET @InstanceId = CASE WHEN @MajorVersion >= 11 THEN 'MSSQL' + CAST(@MajorVersion AS NVARCHAR(2)) + '.MSSQLSERVER' ELSE 'MSSQLSERVER' END;
ELSE BEGIN
    CREATE TABLE #InstanceId (InstanceId NVARCHAR(128));
    INSERT INTO #InstanceId EXEC master..xp_regread 'HKEY_LOCAL_MACHINE', 'SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL', @InstanceName;
    SELECT @InstanceId = InstanceId FROM #InstanceId;
    DROP TABLE #InstanceId;
END

-- Define registry paths to check
DECLARE @RegPaths TABLE (RegPath NVARCHAR(512), Priority INT);
INSERT INTO @RegPaths VALUES 
    ('SOFTWARE\Microsoft\Microsoft SQL Server\' + @InstanceId + '\MSSQLServer\SuperSocketNetLib', 1),
    ('SOFTWARE\Microsoft\Microsoft SQL Server\' + @InstanceId + '\MSSQLServer\SuperSocketNetLib\Tcp', 2);

IF @MajorVersion >= 13
    INSERT INTO @RegPaths VALUES ('SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL' + CAST(@MajorVersion AS NVARCHAR(2)) + '.' + ISNULL(@InstanceName, 'MSSQLSERVER') + '\MSSQLServer\SuperSocketNetLib', 0);

IF @InstanceName IS NULL
    INSERT INTO @RegPaths VALUES
        ('SOFTWARE\Microsoft\MSSQLServer\MSSQLServer\SuperSocketNetLib', 3),
        ('SOFTWARE\Microsoft\MSSQLServer\MSSQLServer\SuperSocketNetLib\Tcp', 4);

-- Search for certificate thumbprint
CREATE TABLE #ThumbprintResult (Value NVARCHAR(1000), Data NVARCHAR(1000));
DECLARE @CurrentPath NVARCHAR(512);

DECLARE path_cursor CURSOR FOR SELECT RegPath FROM @RegPaths ORDER BY Priority;
OPEN path_cursor;
FETCH NEXT FROM path_cursor INTO @CurrentPath;

WHILE @@FETCH_STATUS = 0 AND @Found = 0 BEGIN
    TRUNCATE TABLE #ThumbprintResult;
    INSERT INTO #ThumbprintResult EXEC master..xp_regread 'HKEY_LOCAL_MACHINE', @CurrentPath, 'Certificate';
    IF EXISTS (SELECT 1 FROM #ThumbprintResult WHERE Data IS NOT NULL) BEGIN
        SET @FinalPath = @CurrentPath;
        SELECT @Thumbprint = Data FROM #ThumbprintResult;
        SET @Found = 1;
    END
    FETCH NEXT FROM path_cursor INTO @CurrentPath;
END

CLOSE path_cursor; DEALLOCATE path_cursor; DROP TABLE #ThumbprintResult;

-- Return results
IF @Found = 0 OR @Thumbprint IS NULL BEGIN
    SELECT @@SERVERNAME AS [Server], 
           ISNULL(@InstanceName, 'DEFAULT') AS [Instance], 
           'Not found' AS [Certificate Thumbprint],
           'Not found' AS [Certificate Subject],
           'Not found' AS [Issuer],
           NULL AS [Expiration Date],
           'Not found' AS [Registry Path];
END
ELSE IF @cmd = 0 BEGIN
    -- Return basic info without certutil details when @cmd = 0
    SELECT @@SERVERNAME AS [Server], 
           ISNULL(@InstanceName, 'DEFAULT') AS [Instance], 
           @Thumbprint AS [Certificate Thumbprint],
           'Enable @cmd=1 for details' AS [Certificate Subject],
           'Enable @cmd=1 for details' AS [Issuer],
           'Enable @cmd=1 for details' AS [Expiration Date],
           @FinalPath AS [Registry Path];
END
ELSE BEGIN
    -- Only run certutil when @cmd = 1
    CREATE TABLE #CertUtilOutput (Line NVARCHAR(4000));
    INSERT INTO #CertUtilOutput EXEC xp_cmdshell 'certutil -store My';
    
    -- Extract certificate details with improved parsing
    DECLARE @Issuer NVARCHAR(4000), @Subject NVARCHAR(4000), @ExpiryDate NVARCHAR(100);
    
    WITH CertBlocks AS (
        SELECT 
            Line,
            SUM(CASE WHEN Line LIKE '================ Certificate % ================' THEN 1 ELSE 0 END) 
                OVER (ORDER BY (SELECT NULL) ROWS UNBOUNDED PRECEDING) AS BlockNum
        FROM #CertUtilOutput 
        WHERE Line IS NOT NULL
    ),
    CertDetails AS (
        SELECT 
            BlockNum,
            MAX(CASE WHEN LTRIM(Line) LIKE 'Issuer:%' THEN 
                LTRIM(SUBSTRING(Line, CHARINDEX(':', Line) + 1, LEN(Line))) END) AS Issuer,
            MAX(CASE WHEN LTRIM(Line) LIKE 'Subject:%' THEN 
                LTRIM(SUBSTRING(Line, CHARINDEX(':', Line) + 1, LEN(Line))) END) AS Subject,
            MAX(CASE WHEN LTRIM(Line) LIKE 'NotAfter:%' THEN 
                LTRIM(SUBSTRING(Line, CHARINDEX(':', Line) + 1, LEN(Line))) END) AS ExpiryDate,
            MAX(CASE WHEN Line LIKE '%Cert Hash(sha1):%' + @Thumbprint THEN 1 ELSE 0 END) AS IsMatch
        FROM CertBlocks
        GROUP BY BlockNum
        HAVING MAX(CASE WHEN Line LIKE '%Cert Hash(sha1):%' + @Thumbprint THEN 1 ELSE 0 END) = 1
    )
    SELECT TOP 1
        @Issuer = Issuer,
        @Subject = Subject,
        @ExpiryDate = ExpiryDate
    FROM CertDetails
    WHERE IsMatch = 1;
    
    -- Clean up the CN extraction with more robust handling
    DECLARE @IssuerCN NVARCHAR(255) = COALESCE(@Issuer, 'Not found');
    DECLARE @SubjectCN NVARCHAR(255) = COALESCE(@Subject, 'Not found');
    
    -- Extract CN if present (works with both simple CN= and complex DN formats)
    IF @Issuer LIKE '%CN=%' 
        SET @IssuerCN = SUBSTRING(@Issuer, 
                          CHARINDEX('CN=', @Issuer) + 3,
                          CASE 
                              WHEN CHARINDEX(',', @Issuer, CHARINDEX('CN=', @Issuer) + 3) > 0 
                              THEN CHARINDEX(',', @Issuer, CHARINDEX('CN=', @Issuer) + 3) - (CHARINDEX('CN=', @Issuer) + 3)
                              WHEN CHARINDEX('\', @Issuer, CHARINDEX('CN=', @Issuer) + 3) > 0
                              THEN CHARINDEX('\', @Issuer, CHARINDEX('CN=', @Issuer) + 3) - (CHARINDEX('CN=', @Issuer) + 3)
                              ELSE LEN(@Issuer)
                          END);
    
    IF @Subject LIKE '%CN=%' 
        SET @SubjectCN = SUBSTRING(@Subject, 
                           CHARINDEX('CN=', @Subject) + 3,
                           CASE 
                               WHEN CHARINDEX(',', @Subject, CHARINDEX('CN=', @Subject) + 3) > 0 
                               THEN CHARINDEX(',', @Subject, CHARINDEX('CN=', @Subject) + 3) - (CHARINDEX('CN=', @Subject) + 3)
                               WHEN CHARINDEX('\', @Subject, CHARINDEX('CN=', @Subject) + 3) > 0
                               THEN CHARINDEX('\', @Subject, CHARINDEX('CN=', @Subject) + 3) - (CHARINDEX('CN=', @Subject) + 3)
                               ELSE LEN(@Subject)
                           END);
    
    -- Format the expiration date if found
    IF @ExpiryDate IS NOT NULL AND @ExpiryDate <> 'Not found'
    BEGIN
        -- Try to convert to a standard datetime format (handles both US and international formats)
        BEGIN TRY
            IF ISDATE(@ExpiryDate) = 1
                SET @ExpiryDate = CONVERT(NVARCHAR(30), CONVERT(DATETIME, @ExpiryDate), 120);
            ELSE
                SET @ExpiryDate = LTRIM(RTRIM(@ExpiryDate));
        END TRY
        BEGIN CATCH
            SET @ExpiryDate = LTRIM(RTRIM(@ExpiryDate));
        END CATCH
    END
    
    -- Return the final results with cleaner formatting
    SELECT @@SERVERNAME AS [Server], 
           ISNULL(@InstanceName, 'DEFAULT') AS [Instance], 
           @Thumbprint AS [Certificate Thumbprint],
           CASE 
               WHEN @SubjectCN = 'Not found' THEN @Subject 
               ELSE @SubjectCN 
           END AS [Certificate Subject],
           CASE 
               WHEN @IssuerCN = 'Not found' THEN @Issuer 
               ELSE @IssuerCN 
           END AS [Issuer],
           @ExpiryDate AS [Expiration Date],
           @FinalPath AS [Registry Path];
    
    DROP TABLE #CertUtilOutput;
END

-- Disable xp_cmdshell
EXEC sp_configure 'xp_cmdshell', 0; RECONFIGURE;
EXEC sp_configure 'show advanced options', 0; RECONFIGURE;