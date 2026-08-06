DECLARE @ERRORLOG TABLE (LogDate date,ProcessInfo varchar(100),LogText NVARCHAR(MAX))
DECLARE @Text NVARCHAR(100) = N'recovery'
DECLARE @Text1 NVARCHAR(100) = N''

/*
xp_readerrorlog 0 --error log file number
			, 1 -- error log type (1 SQL, 2 Agent)
			, 'text1' --search text 1
			, 'text2' --search text 2
			, NULL --search time start
			, NULL --search time end
			, 'asc' --order of results
*/

INSERT @ERRORLOG
exec master.dbo.xp_readerrorlog 0, 1, @Text, @Text1, NULL,NULL

INSERT @ERRORLOG
exec master.dbo.xp_readerrorlog 1, 1, @Text, @Text1, NULL,NULL

INSERT @ERRORLOG
exec master.dbo.xp_readerrorlog 2, 1, @Text, @Text1, NULL,NULL

INSERT @ERRORLOG
exec master.dbo.xp_readerrorlog 3, 1, @Text, @Text1, NULL,NULL

INSERT @ERRORLOG
exec master.dbo.xp_readerrorlog 4, 1, @Text, @Text1, NULL,NULL

INSERT @ERRORLOG
exec master.dbo.xp_readerrorlog 5, 1, @Text, @Text1, NULL,NULL

INSERT @ERRORLOG
exec master.dbo.xp_readerrorlog 6, 1, @Text, @Text1, NULL,NULL

SELECT * FROM @ERRORLOG ORDER BY LogDate DESC