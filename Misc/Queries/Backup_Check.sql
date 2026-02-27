DECLARE @SN VARCHAR(100);
DECLARE @sql NVARCHAR(max),@Query NVARCHAR(max);

DECLARE C CURSOR LOCAL FAST_FORWARD
  FOR SELECT DISTINCT(name) FROM sys.servers 
  where is_linked=1

OPEN C;

FETCH NEXT FROM C INTO @SN;
WHILE (@@FETCH_STATUS = 0)
BEGIN 
    PRINT @SN;
    -- you could loop here for each database, if you'd define what that is
	SET @Query = 'SELECT CONVERT(CHAR(100), SERVERPROPERTY(''''Servername'''')) AS Instancename, 
							SERVERPROPERTY(''''ComputerNamePhysicalNetBIOS'''') Servername,
							d.name [database], 
							x.backup_finish_date last_backup
						FROM sys.databases d
							OUTER APPLY (SELECT TOP 1 backupset.backup_finish_date 
										FROM msdb.dbo.backupset 
										where database_name = d.name
										ORDER BY backup_finish_date desc) x
						WHERE (backup_finish_date < DATEADD(MONTH,DATEDIFF(MONTH,0,GETDATE()),0) OR x.backup_finish_date IS NULL)
							AND d.database_id <> 2
						ORDER BY backup_finish_date DESC'

	SET @sql = 'SELECT * FROM OPENQUERY('+QUOTENAME(@SN)+','''+@Query+''')'
	BEGIN TRY
		INSERT INTO [Health_Check].[dbo].[Check_Backup]([Instancename],[Servername],[database],[last_backup])

		EXEC (@sql);
	END TRY
	BEGIN CATCH
		DECLARE @Errors table (ServerName VARCHAR(100),ErrorNumber VARCHAR(100),ErrorSeverity VARCHAR(100),ErrorState VARCHAR(100),ErrorProcedure VARCHAR(100),ErrorLine VARCHAR(100),ErrorMessage VARCHAR(MAX))
		INSERT INTO @Errors
		SELECT  @SN,
			ERROR_NUMBER() AS ErrorNumber  ,
			ERROR_SEVERITY() AS ErrorSeverity , 
			ERROR_STATE() AS ErrorState  ,
			ERROR_PROCEDURE() AS ErrorProcedure  ,
			ERROR_LINE() AS ErrorLine  ,
			ERROR_MESSAGE() AS ErrorMessage; 
	END CATCH
    FETCH NEXT FROM C INTO @SN;
END 
SELECT * FROM @Errors
CLOSE C;
DEALLOCATE C;

--SELECT * FROM [Health_Check].[dbo].[Check_Backup]
--TRUNCATE TABLE [Health_Check].[dbo].[Check_Backup]