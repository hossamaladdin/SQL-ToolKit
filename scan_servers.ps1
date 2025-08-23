#Requires -Version 5.1

<#
.SYNOPSIS
    Runs all SQL queries from a file against multiple servers and outputs results to CSV.
.DESCRIPTION
    This script reads a list of SQL Server instances from servers.txt and executes all queries in query.sql
    against each server. All result sets are captured and exported to a CSV file.
.PARAMETER QueryPath
    Path to the SQL query file. Default is "./query.sql".
.PARAMETER ServerListPath
    Path to the text file containing server names, one per line. Default is "./servers.txt".
.PARAMETER OutputCSV
    Path to save the CSV output file. Default is "./SqlQueryResults.csv".
.PARAMETER Timeout
    Timeout in seconds for SQL query execution. Default is 120 seconds.
.PARAMETER Credential
    Optional credential object for SQL Server authentication.
.EXAMPLE
    .\Check-SqlCertificates.ps1
.EXAMPLE
    .\Check-SqlCertificates.ps1 -QueryPath "C:\Scripts\query.sql" -ServerListPath "C:\Scripts\servers.txt" -OutputCSV "C:\Reports\Results.csv"
.EXAMPLE
    $cred = Get-Credential
    .\Check-SqlCertificates.ps1 -Credential $cred
#>

[CmdletBinding()]
param (
    [Parameter()]
    [string]$QueryPath = "./query.sql",
    
    [Parameter()]
    [string]$ServerListPath = "./servers.txt",
    
    [Parameter()]
    [string]$OutputCSV = "./SqlQueryResults.csv",
    
    [Parameter()]
    [int]$Timeout = 120,
    
    [Parameter()]
    [System.Management.Automation.PSCredential]$Credential = $null
)

# Function to write colored output
function Write-ColorOutput {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter()]
        [ConsoleColor]$ForegroundColor = [ConsoleColor]::White
    )
    
    $originalColor = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    Write-Output $Message
    $host.UI.RawUI.ForegroundColor = $originalColor
}

# Function to execute SQL commands and capture all result sets
function Execute-SqlQuery {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ServerName,
        
        [Parameter(Mandatory = $true)]
        [string]$QueryText,
        
        [Parameter()]
        [int]$CommandTimeout = 120,
        
        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential = $null
    )
    
    # Build connection string
    $connString = "Server=$ServerName;Database=master;Application Name=SqlCertificateCheck;Connection Timeout=30;ConnectRetryCount=3;ConnectRetryInterval=10;"
    
    if ($null -ne $Credential) {
        $connString += "User ID=$($Credential.UserName);Password=$($Credential.GetNetworkCredential().Password);"
    }
    else {
        $connString += "Integrated Security=True;"
    }
    
    # Create connection object
    $connection = New-Object System.Data.SqlClient.SqlConnection($connString)
    $results = @()
    
    try {
        $connection.Open()
        
        # Split queries by GO separator
        $queryBatches = $QueryText -split "(?im)^\s*GO\s*$"
        $batchCount = 0
        
        foreach ($batch in $queryBatches) {
            $batch = $batch.Trim()
            if (-not $batch) { continue }
            
            $batchCount++
            Write-Verbose "Executing batch $batchCount of $($queryBatches.Count) on $ServerName"
            
            $command = New-Object System.Data.SqlClient.SqlCommand($batch, $connection)
            $command.CommandTimeout = $CommandTimeout
            
            try {
                $reader = $command.ExecuteReader()
                $resultSetCounter = 0
                
                # Process all result sets
                do {
                    $resultSetCounter++
                    $tableResults = @()
                    $fieldNames = @()
                    
                    # Get field names
                    for ($i = 0; $i -lt $reader.FieldCount; $i++) {
                        $fieldNames += $reader.GetName($i)
                    }
                    
                    # Read all rows
                    while ($reader.Read()) {
                        $row = [ordered]@{
                            'ServerName' = $ServerName
                            'BatchNumber' = $batchCount
                            'ResultSetNumber' = $resultSetCounter
                        }
                        
                        for ($i = 0; $i -lt $reader.FieldCount; $i++) {
                            $fieldName = $fieldNames[$i]
                            $value = if ($reader.IsDBNull($i)) { $null } else { $reader.GetValue($i) }
                            $row[$fieldName] = $value
                        }
                        
                        $tableResults += [PSCustomObject]$row
                    }
                    
                    # Add this result set to overall results
                    $results += $tableResults
                    
                } while ($reader.NextResult())
                
                $reader.Close()
            }
            catch {
                Write-Verbose "Error executing batch $batchCount on $ServerName`: $_"
                
                # Add error record to results
                $errorRecord = [PSCustomObject]@{
                    'ServerName' = $ServerName
                    'BatchNumber' = $batchCount
                    'ResultSetNumber' = 0
                    'ErrorMessage' = $_.Exception.Message
                    'ErrorBatch' = $batch
                }
                
                $results += $errorRecord
            }
            finally {
                $command.Dispose()
            }
        }
    }
    catch {
        Write-ColorOutput ("Error connecting to " + $ServerName + ": " + $_.Exception.Message) -ForegroundColor Red
        
        # Add connection error record to results
        $errorRecord = [PSCustomObject]@{
            'ServerName' = $ServerName
            'BatchNumber' = 0
            'ResultSetNumber' = 0
            'ErrorMessage' = "Connection Error: $($_.Exception.Message)"
        }
        
        $results += $errorRecord
    }
    finally {
        if ($connection.State -eq 'Open') {
            $connection.Close()
        }
        $connection.Dispose()
    }
    
    return $results
}

# Verify required files exist
if (-not (Test-Path $QueryPath)) {
    Write-ColorOutput "Error: Query file not found at '$QueryPath'" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $ServerListPath)) {
    Write-ColorOutput "Error: Server list file not found at '$ServerListPath'" -ForegroundColor Red
    exit 1
}

try {
    # Load required assemblies
    Add-Type -AssemblyName System.Data

    # Read query content
    $query = Get-Content -Path $QueryPath -Raw
    
    # Read server list
    $servers = Get-Content -Path $ServerListPath | Where-Object { $_ -match '\S' } | ForEach-Object { $_.Trim() }
    
    if ($servers.Count -eq 0) {
        Write-ColorOutput "Error: No servers found in '$ServerListPath'" -ForegroundColor Red
        exit 1
    }
    
    Write-ColorOutput "Found $($servers.Count) servers to process..." -ForegroundColor Cyan
    
    # Create array to store all results
    $allResults = @()
    $serverCount = 0
    $totalServers = $servers.Count
    
    # Process each server
    foreach ($server in $servers) {
        $serverCount++
        Write-ColorOutput "[$serverCount/$totalServers] Processing server: $server" -ForegroundColor Cyan
        
        try {
            # Execute query against the server
            $results = Execute-SqlQuery -ServerName $server -QueryText $query -CommandTimeout $Timeout -Credential $Credential
            
            if ($results.Count -eq 0) {
                Write-ColorOutput "  Warning: No results returned from $server" -ForegroundColor Yellow
            }
            else {
                # Add ExecutedOn timestamp to results
                $executedOn = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                $results | ForEach-Object { 
                    $_ | Add-Member -MemberType NoteProperty -Name "ExecutedOn" -Value $executedOn -Force
                }
                
                # Add to collection
                $allResults += $results
                
                # Show summary
                $resultSetCount = ($results | Select-Object -Property ResultSetNumber -Unique).Count
                $hasErrors = ($results | Where-Object { $_.ErrorMessage }).Count -gt 0
                
                if ($hasErrors) {
                    Write-ColorOutput "  Warning: Query executed with some errors, check results" -ForegroundColor Yellow
                }
                else {
                    Write-ColorOutput "  Success: Query executed with $resultSetCount result sets" -ForegroundColor Green
                }
            }
        }
        catch {
            Write-ColorOutput "  Error processing $server : $($_.Exception.Message)" -ForegroundColor Red
            
            # Add error record
            $errorRecord = [PSCustomObject]@{
                'ServerName' = $server
                'BatchNumber' = 0
                'ResultSetNumber' = 0
                'ErrorMessage' = $_.Exception.Message
                'ExecutedOn' = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            
            $allResults += $errorRecord
        }
    }
    
    # Export results to CSV
    if ($allResults.Count -gt 0) {
        $allResults | Export-Csv -Path $OutputCSV -NoTypeInformation
        Write-ColorOutput "Results exported to $OutputCSV" -ForegroundColor Green
        Write-ColorOutput "Total rows in CSV: $($allResults.Count)" -ForegroundColor Cyan
        Write-ColorOutput "Total servers processed: $totalServers" -ForegroundColor Cyan
    }
    else {
        Write-ColorOutput "No results to export" -ForegroundColor Yellow
    }
}
catch {
    Write-ColorOutput "Unhandled error occurred: $($_.Exception.Message)" -ForegroundColor Red
    Write-ColorOutput "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}