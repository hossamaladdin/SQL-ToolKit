$SqlFolder = "C:\Users\hossam"
$ServerInstance = "localhost"
$Database = "MyDatabase"

# Import SqlServer module (install if needed: Install-Module -Name SqlServer)
Import-Module SqlServer -ErrorAction SilentlyContinue

$SqlFiles = Get-ChildItem $SqlFolder -Filter "*.sql"

foreach ($File in $SqlFiles) {

    Write-Host "Processing $($File.Name)..."

    $CsvPath = [System.IO.Path]::ChangeExtension($File.FullName, ".csv")

    try {
        # Read the SQL query
        $Query = Get-Content $File.FullName -Raw -Encoding UTF8

        # Execute query and get results as objects
        $Results = Invoke-Sqlcmd `
            -ServerInstance $ServerInstance `
            -Database $Database `
            -Query $Query `
            -ErrorAction Stop

        if ($Results) {
            # Export to CSV with proper quoting and UTF-8 encoding
            $Results | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8
            Write-Host "✓ Exported $($Results.Count) rows to $($File.Name -replace '\.sql$','.csv')" -ForegroundColor Green
        }
        else {
            Write-Host "⚠ No results returned from $($File.Name)" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "✗ Error processing $($File.Name): $_" -ForegroundColor Red
    }
}
