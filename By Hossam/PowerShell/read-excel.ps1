$excelFile = 'C:\Users\hossam.aladdin\Documents\Database Environment Detailed Assessment.xlsx'

# Create Excel COM object
$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false
$excel.DisplayAlerts = $false

try {
    $workbook = $excel.Workbooks.Open($excelFile)

    Write-Host 'Sheet Names:'
    foreach ($sheet in $workbook.Worksheets) {
        Write-Host "  - $($sheet.Name)"
    }
    Write-Host ''
    Write-Host ('='*80)
    Write-Host ''

    # Read each sheet
    foreach ($sheet in $workbook.Worksheets) {
        Write-Host "Sheet: $($sheet.Name)"

        $usedRange = $sheet.UsedRange
        $rowCount = $usedRange.Rows.Count
        $colCount = $usedRange.Columns.Count

        Write-Host "Rows: $rowCount, Columns: $colCount"
        Write-Host ''

        # Get first 20 rows
        $maxRows = [Math]::Min(20, $rowCount)
        for ($row = 1; $row -le $maxRows; $row++) {
            $rowData = @()
            for ($col = 1; $col -le $colCount; $col++) {
                $cellValue = $sheet.Cells.Item($row, $col).Text
                $rowData += $cellValue
            }
            Write-Host ($rowData -join ' | ')
        }

        Write-Host ''
        Write-Host ('='*80)
        Write-Host ''
    }

    $workbook.Close($false)
} finally {
    $excel.Quit()
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
}
