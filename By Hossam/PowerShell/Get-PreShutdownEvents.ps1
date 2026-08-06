# Get events from 1 hour before last sudden shutdown/restart
# Author: SQL-ToolKit
# Date: 2026-01-31

param(
    [int]$HoursBefore = 1,
    [string]$ComputerName = $env:COMPUTERNAME,
    [string]$ExportPath = "$([Environment]::GetFolderPath('Desktop'))\PreShutdown-Events.csv"
)

Write-Host "Searching for last shutdown/restart event..." -ForegroundColor Cyan

# Event IDs for shutdown/restart detection
# Priority: Kernel-Power Event 41 (unexpected shutdown) first
$kernelShutdownID = 41
$otherShutdownIDs = @(
    1074,  # System shutdown by process/user
    6006,  # Event Log service stopped (clean shutdown)
    6008,  # Unexpected shutdown (dirty)
    1076   # Reason for shutdown
)

try {
    # Find the last KERNEL shutdown event (Event ID 41 - unexpected shutdown)
    $lastShutdown = Get-WinEvent -FilterHashtable @{
        LogName = 'System'
        ProviderName = 'Microsoft-Windows-Kernel-Power'
        ID = $kernelShutdownID
    } -MaxEvents 10 -ComputerName $ComputerName -ErrorAction SilentlyContinue |
    Select-Object -First 1

    # If no kernel shutdown found, fall back to other shutdown events
    if ($null -eq $lastShutdown) {
        Write-Host "No Kernel-Power shutdown event found, checking other shutdown events..." -ForegroundColor Yellow
        $lastShutdown = Get-WinEvent -FilterHashtable @{
            LogName = 'System'
            ID = $otherShutdownIDs
        } -MaxEvents 50 -ComputerName $ComputerName -ErrorAction Stop |
        Select-Object -First 1
    }

    if ($null -eq $lastShutdown) {
        Write-Host "No shutdown/restart events found in System log" -ForegroundColor Yellow
        exit
    }

    $shutdownTime = $lastShutdown.TimeCreated
    $startTime = $shutdownTime.AddHours(-$HoursBefore)

    Write-Host "`nLast Shutdown/Restart Details:" -ForegroundColor Green
    Write-Host "  Time: $shutdownTime" -ForegroundColor White
    Write-Host "  Event ID: $($lastShutdown.Id)" -ForegroundColor White
    Write-Host "  Source: $($lastShutdown.ProviderName)" -ForegroundColor White
    Write-Host "  Message: $($lastShutdown.Message.Substring(0, [Math]::Min(200, $lastShutdown.Message.Length)))..." -ForegroundColor Gray

    Write-Host "`nQuerying ALL events from $startTime to $shutdownTime..." -ForegroundColor Cyan

    # Get ALL events from 1 hour before shutdown (not just errors)
    $events = @()

    # ALL events from System log
    Write-Host "  - Collecting System log (ALL levels)..." -ForegroundColor Gray
    $systemEvents = Get-WinEvent -FilterHashtable @{
        LogName = 'System'
        StartTime = $startTime
        EndTime = $shutdownTime
    } -ComputerName $ComputerName -ErrorAction SilentlyContinue

    if ($systemEvents) {
        $events += $systemEvents
        Write-Host "    Found: $($systemEvents.Count) events" -ForegroundColor DarkGray
    }

    # ALL events from Application log
    Write-Host "  - Collecting Application log (ALL levels)..." -ForegroundColor Gray
    $appEvents = Get-WinEvent -FilterHashtable @{
        LogName = 'Application'
        StartTime = $startTime
        EndTime = $shutdownTime
    } -ComputerName $ComputerName -ErrorAction SilentlyContinue

    if ($appEvents) {
        $events += $appEvents
        Write-Host "    Found: $($appEvents.Count) events" -ForegroundColor DarkGray
    }

    # SQL Server specific events if available
    Write-Host "  - Checking for SQL Server logs..." -ForegroundColor Gray
    $sqlLogs = Get-WinEvent -ListLog "Application" -ComputerName $ComputerName -ErrorAction SilentlyContinue |
               Where-Object { $_.LogName -like "*SQL*" }

    foreach ($log in $sqlLogs) {
        try {
            $sqlEvents = Get-WinEvent -FilterHashtable @{
                LogName = $log.LogName
                Level = 1,2,3
                StartTime = $startTime
                EndTime = $shutdownTime
            } -ComputerName $ComputerName -ErrorAction SilentlyContinue

            if ($sqlEvents) {
                $events += $sqlEvents
                Write-Host "    Found: $($sqlEvents.Count) events in $($log.LogName)" -ForegroundColor DarkGray
            }
        } catch {
            # Skip logs that can't be read
        }
    }

    if ($events.Count -eq 0) {
        Write-Host "`nNo significant events found in the hour before shutdown" -ForegroundColor Yellow
        exit
    }

    # Sort events by time
    $events = $events | Sort-Object TimeCreated

    Write-Host "`nTotal events collected: $($events.Count)" -ForegroundColor Green

    # Export to CSV
    $exportData = $events | Select-Object @{
        Name = 'TimeCreated'
        Expression = { $_.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss.fff") }
    },
    @{
        Name = 'Level'
        Expression = {
            switch ($_.Level) {
                1 { 'Critical' }
                2 { 'Error' }
                3 { 'Warning' }
                4 { 'Information' }
                default { 'Unknown' }
            }
        }
    },
    Id,
    LogName,
    ProviderName,
    Message,
    @{
        Name = 'MinutesBeforeShutdown'
        Expression = { [Math]::Round(($shutdownTime - $_.TimeCreated).TotalMinutes, 2) }
    }

    $exportData | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8

    Write-Host "`nEvents exported to: $ExportPath" -ForegroundColor Green

    # Display summary of critical/error events
    Write-Host "`nTop Critical/Error Events:" -ForegroundColor Yellow
    Write-Host ("=" * 100) -ForegroundColor DarkGray

    $criticalErrors = $events | Where-Object { $_.Level -in 1,2 } |
                      Group-Object Id, ProviderName |
                      Sort-Object Count -Descending |
                      Select-Object -First 10

    foreach ($group in $criticalErrors) {
        $sample = $group.Group[0]
        $levelName = if ($sample.Level -eq 1) { 'Critical' } else { 'Error' }
        $minutesBefore = [Math]::Round(($shutdownTime - $sample.TimeCreated).TotalMinutes, 1)

        Write-Host "`n[$levelName] Event ID $($sample.Id) - $($sample.ProviderName)" -ForegroundColor $(if($sample.Level -eq 1){'Red'}else{'Yellow'})
        Write-Host "  Count: $($group.Count) | First occurrence: $minutesBefore min before shutdown" -ForegroundColor Gray
        Write-Host "  Message: $($sample.Message.Substring(0, [Math]::Min(150, $sample.Message.Length)))..." -ForegroundColor White
    }

    Write-Host "`n" -NoNewline
    Write-Host ("=" * 100) -ForegroundColor DarkGray

    # Show timeline of events in last 10 minutes before shutdown
    Write-Host "`nTimeline (Last 10 minutes before shutdown):" -ForegroundColor Cyan
    $recentEvents = $events | Where-Object { ($shutdownTime - $_.TimeCreated).TotalMinutes -le 10 } |
                    Where-Object { $_.Level -in 1,2,3 } |
                    Sort-Object TimeCreated -Descending |
                    Select-Object -First 20

    foreach ($evt in $recentEvents) {
        $minBefore = [Math]::Round(($shutdownTime - $evt.TimeCreated).TotalMinutes, 1)
        $levelColor = switch ($evt.Level) {
            1 { 'Red' }
            2 { 'Yellow' }
            3 { 'Cyan' }
            default { 'White' }
        }
        $levelName = switch ($evt.Level) {
            1 { 'CRIT' }
            2 { 'ERR ' }
            3 { 'WARN' }
            default { 'INFO' }
        }

        Write-Host "T-$($minBefore.ToString('00.0'))m " -NoNewline -ForegroundColor Gray
        Write-Host "[$levelName] " -NoNewline -ForegroundColor $levelColor
        Write-Host "ID:$($evt.Id) " -NoNewline -ForegroundColor White
        Write-Host "$($evt.ProviderName): " -NoNewline -ForegroundColor Gray
        $msg = $evt.Message -replace "`r`n", " " -replace "`n", " "
        Write-Host "$($msg.Substring(0, [Math]::Min(80, $msg.Length)))" -ForegroundColor White
    }

} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}

Write-Host "`nDone!" -ForegroundColor Green
