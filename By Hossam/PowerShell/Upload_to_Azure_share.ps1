# Set your values
$storageAccount = "your-storage-account"
$shareName = "backup"  # or diagnose, shares, etc.
$storageKey = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"  # Get from Portal: your-storage-account → Access keys
$sourceFile = "C:\YourPath\your-report-file.zip"
$destFileName = "your-report-file.zip"

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
