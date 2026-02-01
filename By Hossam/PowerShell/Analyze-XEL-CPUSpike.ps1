#Requires -Version 5.1
<#
.SYNOPSIS
    Extracts ALL High CPU Events from XEL Files
.PARAMETER ServerInstance
    SQL Server instance (default: 127.0.0.1)
.PARAMETER XELPath
    Path to XEL files on the SQL Server (supports wildcards)
.PARAMETER StartTime
    Start time in server local time (default: 2026-01-31 07:00:00)
.PARAMETER EndTime
    End time in server local time (default: 2026-01-31 07:30:00)
.PARAMETER OutputPath
    Where to save the CSV output
#>

param(
    [string]$ServerInstance = "127.0.0.1",
    [string]$XELPath = "C:\Temp\XEL_Analysis\HighCPUAndReads*.xel",
    [datetime]$StartTime = "2026-01-31 07:00:00",
    [datetime]$EndTime = "2026-01-31 07:30:00",
    [string]$OutputPath = "C:\Temp\XEL_Analysis\Reports"
)

$ErrorActionPreference = "Stop"

Write-Host "==================================================================" -ForegroundColor Green
Write-Host "XEL CPU Spike Analysis" -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Green
Write-Host "Server:     $ServerInstance" -ForegroundColor Cyan
Write-Host "XEL Path:   $XELPath" -ForegroundColor Cyan
Write-Host "Time Range: $($StartTime.ToString('yyyy-MM-dd HH:mm:ss')) to $($EndTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Cyan
Write-Host "Output:     $OutputPath" -ForegroundColor Cyan
Write-Host ""

# Create output directory
if (!(Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}

# Build SQL query
$query = @"
SET NOCOUNT ON;

;WITH XEL_Data AS (
    SELECT CAST(event_data AS XML) AS event_data
    FROM sys.fn_xe_file_target_read_file('$XELPath', null, null, null)
),
Parsed_Events AS (
    SELECT
        event_data.value('(event/@timestamp)[1]', 'datetime2') AS EventTime,
        event_data.value('(event/@name)[1]', 'varchar(100)') AS EventName,
        event_data.value('(event/data[@name="duration"]/value)[1]', 'bigint') AS Duration_Microseconds,
        event_data.value('(event/data[@name="cpu_time"]/value)[1]', 'bigint') AS CPU_Microseconds,
        event_data.value('(event/data[@name="logical_reads"]/value)[1]', 'bigint') AS LogicalReads,
        event_data.value('(event/data[@name="physical_reads"]/value)[1]', 'bigint') AS PhysicalReads,
        event_data.value('(event/data[@name="writes"]/value)[1]', 'bigint') AS Writes,
        event_data.value('(event/data[@name="row_count"]/value)[1]', 'bigint') AS [RowCount],
        event_data.value('(event/data[@name="database_name"]/value)[1]', 'varchar(256)') AS DatabaseName,
        event_data.value('(event/data[@name="object_name"]/value)[1]', 'varchar(256)') AS ObjectName,
        event_data.value('(event/action[@name="session_id"]/value)[1]', 'int') AS SessionID,
        event_data.value('(event/action[@name="username"]/value)[1]', 'varchar(256)') AS Username,
        event_data.value('(event/action[@name="client_hostname"]/value)[1]', 'varchar(256)') AS ClientHostname,
        event_data.value('(event/action[@name="client_app_name"]/value)[1]', 'varchar(256)') AS ClientAppName,
        event_data.value('(event/action[@name="database_name"]/value)[1]', 'varchar(256)') AS ActionDatabaseName,
        event_data.value('(event/data[@name="statement"]/value)[1]', 'varchar(max)') AS SQL_Statement,
        event_data.value('(event/action[@name="sql_text"]/value)[1]', 'varchar(max)') AS SQL_Text_Action
    FROM XEL_Data
    WHERE event_data.value('(event/@timestamp)[1]', 'datetime2') >= '$($StartTime.ToString('yyyy-MM-dd HH:mm:ss'))'
      AND event_data.value('(event/@timestamp)[1]', 'datetime2') < '$($EndTime.ToString('yyyy-MM-dd HH:mm:ss'))'
)
SELECT
    ROW_NUMBER() OVER (ORDER BY CPU_Microseconds DESC) AS RowNum,
    EventTime,
    EventName,
    Duration_Microseconds,
    CAST(Duration_Microseconds / 1000.0 AS DECIMAL(18,3)) AS Duration_ms,
    CAST(Duration_Microseconds / 1000000.0 AS DECIMAL(18,3)) AS Duration_sec,
    CPU_Microseconds,
    CAST(CPU_Microseconds / 1000.0 AS DECIMAL(18,3)) AS CPU_ms,
    CAST(CPU_Microseconds / 1000000.0 AS DECIMAL(18,3)) AS CPU_sec,
    LogicalReads,
    PhysicalReads,
    Writes,
    [RowCount],
    ISNULL(DatabaseName, ActionDatabaseName) AS [Database],
    ObjectName,
    SessionID,
    Username,
    ClientHostname,
    ClientAppName,
    ISNULL(SQL_Statement, SQL_Text_Action) AS SQL_Text
FROM Parsed_Events
ORDER BY CPU_Microseconds DESC;
"@

Write-Host "[INFO] Connecting to SQL Server and extracting events..." -ForegroundColor Yellow

try {
    # Execute query
    $connectionString = "Server=$ServerInstance;Database=master;Integrated Security=True;TrustServerCertificate=True"
    $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
    $connection.Open()

    $command = $connection.CreateCommand()
    $command.CommandText = $query
    $command.CommandTimeout = 600

    $adapter = New-Object System.Data.SqlClient.SqlDataAdapter($command)
    $dataset = New-Object System.Data.DataSet
    $rowCount = $adapter.Fill($dataset)

    $connection.Close()

    Write-Host "[SUCCESS] Extracted $rowCount events" -ForegroundColor Green

    if ($rowCount -gt 0) {
        $results = $dataset.Tables[0]

        # Display top 20
        Write-Host "`n=== TOP 20 CPU EVENTS ===" -ForegroundColor Yellow
        $results | Select-Object -First 20 | Format-Table RowNum, EventTime, CPU_sec, Duration_sec, LogicalReads, Username, ClientHostname -AutoSize

        # Export to CSV
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $csvFile = Join-Path $OutputPath "CPUSpike_${timestamp}.csv"
        $results | Export-Csv -Path $csvFile -NoTypeInformation -Encoding UTF8

        Write-Host "`n[EXPORT] Saved $rowCount events to:" -ForegroundColor Green
        Write-Host "  $csvFile" -ForegroundColor Cyan

        # Summary statistics
        Write-Host "`n=== SUMMARY ===" -ForegroundColor Yellow
        $totalCPU = ($results | Measure-Object -Property CPU_sec -Sum).Sum
        $avgCPU = ($results | Measure-Object -Property CPU_sec -Average).Average
        $maxCPU = ($results | Measure-Object -Property CPU_sec -Maximum).Maximum

        Write-Host "Total Events:    $rowCount" -ForegroundColor White
        Write-Host "Total CPU Time:  $([math]::Round($totalCPU, 2)) seconds ($([math]::Round($totalCPU/60, 2)) minutes)" -ForegroundColor White
        Write-Host "Avg CPU/Event:   $([math]::Round($avgCPU, 3)) seconds" -ForegroundColor White
        Write-Host "Max CPU:         $([math]::Round($maxCPU, 3)) seconds" -ForegroundColor White

        # By User
        Write-Host "`n=== BY USER ===" -ForegroundColor Yellow
        $results | Group-Object Username | Sort-Object Count -Descending | Select-Object -First 10 | ForEach-Object {
            Write-Host "  $($_.Name): $($_.Count) events" -ForegroundColor Gray
        }

        # By Host
        Write-Host "`n=== BY HOST ===" -ForegroundColor Yellow
        $results | Group-Object ClientHostname | Sort-Object Count -Descending | Select-Object -First 10 | ForEach-Object {
            Write-Host "  $($_.Name): $($_.Count) events" -ForegroundColor Gray
        }
    }
    else {
        Write-Host "[WARNING] No events found in the specified time range" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "[ERROR] Failed to extract events: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n==================================================================" -ForegroundColor Green
Write-Host "Analysis Complete" -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Green
