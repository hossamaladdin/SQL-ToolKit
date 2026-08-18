SET NOCOUNT ON;

DECLARE @To   datetime = GETDATE();
DECLARE @From datetime = DATEADD(DAY, -7, @To);

IF OBJECT_ID('tempdb..#ErrorLog') IS NOT NULL DROP TABLE #ErrorLog;
IF OBJECT_ID('tempdb..#Stage')    IS NOT NULL DROP TABLE #Stage;
IF OBJECT_ID('tempdb..#Logs')     IS NOT NULL DROP TABLE #Logs;

CREATE TABLE #Logs
(
    ArchiveNo   int,
    LogDate     varchar(30),
    LogSizeByte bigint
);

INSERT INTO #Logs
EXEC master.dbo.xp_enumerrorlogs;

CREATE TABLE #ErrorLog
(
    ArchiveNo   int,
    LogDate     datetime,
    ProcessInfo nvarchar(128),
    LogText     nvarchar(max)
);

CREATE TABLE #Stage
(
    LogDate     datetime,
    ProcessInfo nvarchar(128),
    LogText     nvarchar(max)
);

DECLARE @Archive int;

DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT ArchiveNo
    FROM #Logs
    WHERE TRY_CONVERT(datetime, LogDate) >= @From
       OR ArchiveNo = 0
    ORDER BY ArchiveNo;

OPEN cur;
FETCH NEXT FROM cur INTO @Archive;

WHILE @@FETCH_STATUS = 0
BEGIN
    TRUNCATE TABLE #Stage;

    INSERT INTO #Stage
    EXEC master.dbo.xp_readerrorlog @Archive, 1;

    INSERT INTO #ErrorLog (ArchiveNo, LogDate, ProcessInfo, LogText)
    SELECT @Archive, LogDate, ProcessInfo, LogText
    FROM #Stage
    WHERE LogDate BETWEEN @From AND @To;

    FETCH NEXT FROM cur INTO @Archive;
END;

CLOSE cur;
DEALLOCATE cur;


/* ============================================================
   RESULT 1: One row per day - lease/WSFC incidents only
   ============================================================ */

SELECT
    CONVERT(date, LogDate)  AS EventDay,
    MIN(LogDate)            AS FirstEvent,
    MAX(LogDate)            AS LastEvent,
    COUNT(*)                AS TotalEvents
FROM #ErrorLog
WHERE
    (
        LogText LIKE '%lease%'
     OR LogText LIKE '%Windows Server Failover Cluster%'
     OR LogText LIKE '%Error: 19407%'
     OR LogText LIKE '%Error: 19419%'
     OR LogText LIKE '%Error: 1146%'
     OR LogText LIKE '%Error: 35201%'
     OR LogText LIKE '%Error: 41089%'
     OR LogText LIKE '%Error: 41091%'
     OR LogText LIKE '%Error: 41144%'
    )
    AND LogText NOT LIKE '%changing roles from%'
    AND LogText NOT LIKE 'State information for database%'
    AND LogText NOT LIKE '%DbMgrPartnerCommitPolicy%'
GROUP BY CONVERT(date, LogDate)
ORDER BY EventDay;


/* ============================================================
   RESULT 2: Full detail - server/AG level only
   ============================================================ */

SELECT
    ArchiveNo,
    LogDate,
    ProcessInfo,

    CASE
        WHEN LogText LIKE '%lease%expired%'
          OR LogText LIKE '%Error: 19407%'
          OR LogText LIKE '%Error: 19419%'
          OR LogText LIKE '%lease worker%'
          OR LogText LIKE '%lease renewal%'
            THEN 'LEASE'

        WHEN LogText LIKE '%Error: 1146%'
          OR LogText LIKE '%Windows Server Failover Cluster%'
            THEN 'WSFC'

        WHEN LogText LIKE '%Error: 35201%'
          OR LogText LIKE '%connection timeout%availability replica%'
            THEN 'REPLICA CONN TIMEOUT'

        WHEN LogText LIKE '%Error: 41089%'
          OR LogText LIKE '%Error: 41091%'
          OR LogText LIKE '%Error: 41144%'
            THEN 'AG ONLINE FAILURE'

        ELSE 'OTHER'
    END AS EventType,

    LogText

FROM #ErrorLog

WHERE
    (
        LogText LIKE '%lease%'
     OR LogText LIKE '%Windows Server Failover Cluster%'
     OR LogText LIKE '%Error: 19407%'
     OR LogText LIKE '%Error: 19419%'
     OR LogText LIKE '%Error: 1146%'
     OR LogText LIKE '%Error: 35201%'
     OR LogText LIKE '%Error: 41089%'
     OR LogText LIKE '%Error: 41091%'
     OR LogText LIKE '%Error: 41144%'
    )
    AND LogText NOT LIKE '%changing roles from%'
    AND LogText NOT LIKE 'State information for database%'
    AND LogText NOT LIKE '%DbMgrPartnerCommitPolicy%'

ORDER BY
    LogDate ASC;
