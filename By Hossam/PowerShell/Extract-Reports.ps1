$SqlFolder = "C:\Users\hossam"
$ServerInstance = "localhost"
$Database = "SafeYard"

chcp 65001 | Out-Null

$SqlFiles = Get-ChildItem $SqlFolder -Filter "*.sql"

foreach ($File in $SqlFiles) {

    Write-Host "Processing $($File.Name)..."

    $CsvPath  = [System.IO.Path]::ChangeExtension($File.FullName, ".csv")
    $TempSql  = Join-Path $env:TEMP $File.Name
    $TempCsv  = Join-Path $env:TEMP ([System.IO.Path]::GetRandomFileName())

@"
SET NOCOUNT ON;
$(Get-Content $File.FullName -Raw)
"@ | Set-Content $TempSql -Encoding UTF8

    # 1️⃣ sqlcmd writes UTF-8 directly (NO PowerShell capture)
    sqlcmd `
        -S $ServerInstance `
        -d $Database `
        -E `
        -W `
        -s "," `
        -h 1 `
        -f 65001 `
        -i $TempSql `
        -o $TempCsv

    # 2️⃣ Clean headers + dashed lines (safe UTF-8 read)
    $Lines  = Get-Content $TempCsv -Encoding UTF8
    $Header = $null

    $Clean = foreach ($Line in $Lines) {

        if ($Line -match '^-{3,}') { continue }

        if (-not $Header) {
            $Header = $Line
            $Line
            continue
        }

        if ($Line -eq $Header) { continue }

        $Line
    }

    $Clean | Out-File $CsvPath -Encoding utf8

    Remove-Item $TempSql, $TempCsv -ErrorAction SilentlyContinue
}
