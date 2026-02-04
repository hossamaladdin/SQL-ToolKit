# Set your values
$storageAccount = "saaprfs"
$shareName = "backup"  # or diagnose, shares, etc.
$storageKey = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"  # Get from Portal: saaprfs → Access keys
$sourceFile = "E:\QueryLogs\Results\ITCMonthlyReportDetails_2026-02-02.zip"
$destFileName = "ITCMonthlyReportDetails_2026-02-02.zip"

# Mount the share
$connectTestResult = Test-NetConnection -ComputerName "$storageAccount.file.core.windows.net" -Port 445
if ($connectTestResult.TcpTestSucceeded) {
    cmd.exe /C "cmdkey /add:`"$storageAccount.file.core.windows.net`" /user:`"Azure\$storageAccount`" /pass:`"$storageKey`""
    New-PSDrive -Name Z -PSProvider FileSystem -Root "\\$storageAccount.file.core.windows.net\$shareName" -Persist
    
    # Copy file
    Copy-Item -Path $sourceFile -Destination "Z:\$destFileName"
    
    Write-Output "File uploaded successfully to $shareName"
} else {
    Write-Output "Cannot reach storage account on port 445"
}
