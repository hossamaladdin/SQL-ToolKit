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
   RESULT 1: Daily summary of resource-pressure events
   ============================================================ */

SELECT
    CONVERT(date, LogDate)  AS EventDay,
    SUM(CASE WHEN LogText LIKE '%taking longer than 15 seconds%'
              OR LogText LIKE '%I/O is frozen%'
              OR LogText LIKE '%I/O was resumed%'
              OR LogText LIKE '%latch%time-out%'          THEN 1 ELSE 0 END) AS IOEvents,
    SUM(CASE WHEN LogText LIKE '%paged out%'
              OR LogText LIKE '%memory pressure%'
              OR LogText LIKE '%insufficient%memory%'
              OR LogText LIKE '%out of memory%'
              OR LogText LIKE '%Error: 701%'
              OR LogText LIKE '%Error: 802%'
              OR LogText LIKE '%FAIL_PAGE_ALLOCATION%'    THEN 1 ELSE 0 END) AS MemoryEvents,
    SUM(CASE WHEN LogText LIKE '%non-yielding%'
              OR LogText LIKE '%SchedulerMonitor%'
              OR LogText LIKE '%appear deadlocked%'
              OR LogText LIKE '%Process % Worker%appears to be non-yielding%' THEN 1 ELSE 0 END) AS CPUSchedulerEvents,
    MIN(LogDate) AS FirstEvent,
    MAX(LogDate) AS LastEvent,
    COUNT(*)     AS TotalEvents
FROM #ErrorLog
WHERE
       LogText LIKE '%taking longer than 15 seconds%'
    OR LogText LIKE '%I/O is frozen%'
    OR LogText LIKE '%I/O was resumed%'
    OR LogText LIKE '%latch%time-out%'
    OR LogText LIKE '%paged out%'
    OR LogText LIKE '%memory pressure%'
    OR LogText LIKE '%insufficient%memory%'
    OR LogText LIKE '%out of memory%'
    OR LogText LIKE '%Error: 701%'
    OR LogText LIKE '%Error: 802%'
    OR LogText LIKE '%FAIL_PAGE_ALLOCATION%'
    OR LogText LIKE '%non-yielding%'
    OR LogText LIKE '%SchedulerMonitor%'
    OR LogText LIKE '%appear deadlocked%'
GROUP BY CONVERT(date, LogDate)
ORDER BY EventDay;


/* ============================================================
   RESULT 2: Full detail - IO / Memory / CPU pressure
   ============================================================ */

SELECT
    ArchiveNo,
    LogDate,
    ProcessInfo,

    CASE
        WHEN LogText LIKE '%taking longer than 15 seconds%'
            THEN 'IO - SLOW (15s+)'

        WHEN LogText LIKE '%I/O is frozen%'
            THEN 'IO - FROZEN (VSS/BACKUP)'

        WHEN LogText LIKE '%I/O was resumed%'
            THEN 'IO - RESUMED'

        WHEN LogText LIKE '%latch%time-out%'
            THEN 'IO - LATCH TIMEOUT'

        WHEN LogText LIKE '%paged out%'
            THEN 'MEM - PAGED OUT'

        WHEN LogText LIKE '%Error: 701%'
          OR LogText LIKE '%insufficient%memory%'
          OR LogText LIKE '%out of memory%'
          OR LogText LIKE '%FAIL_PAGE_ALLOCATION%'
            THEN 'MEM - ALLOCATION FAILURE'

        WHEN LogText LIKE '%Error: 802%'
          OR LogText LIKE '%memory pressure%'
            THEN 'MEM - PRESSURE'

        WHEN LogText LIKE '%non-yielding%'
            THEN 'CPU - NON-YIELDING'

        WHEN LogText LIKE '%appear deadlocked%'
            THEN 'CPU - SCHEDULER DEADLOCK'

        WHEN LogText LIKE '%SchedulerMonitor%'
            THEN 'CPU - SCHEDULER MONITOR'

        ELSE 'OTHER'
    END AS EventType,

    LogText

FROM #ErrorLog

WHERE
       LogText LIKE '%taking longer than 15 seconds%'
    OR LogText LIKE '%I/O is frozen%'
    OR LogText LIKE '%I/O was resumed%'
    OR LogText LIKE '%latch%time-out%'
    OR LogText LIKE '%paged out%'
    OR LogText LIKE '%memory pressure%'
    OR LogText LIKE '%insufficient%memory%'
    OR LogText LIKE '%out of memory%'
    OR LogText LIKE '%Error: 701%'
    OR LogText LIKE '%Error: 802%'
    OR LogText LIKE '%FAIL_PAGE_ALLOCATION%'
    OR LogText LIKE '%non-yielding%'
    OR LogText LIKE '%SchedulerMonitor%'
    OR LogText LIKE '%appear deadlocked%'

ORDER BY
    LogDate ASC;
