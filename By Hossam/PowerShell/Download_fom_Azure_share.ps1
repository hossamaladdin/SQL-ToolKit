# Set your values
$storageAccount = "saaprfs"
$shareName = "backup"
$fileName =  "ITCMonthlyReportDetails_2026-02-02.zip"
$storageKey = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"  # Get from Portal: saaprfs → Access keys
$localPath = "C:\Downloads\ITCMonthlyReportDetails_2026-02-02.zip"

# Create the Downloads folder if it doesn't exist
New-Item -ItemType Directory -Force -Path "C:\Downloads"

# Build the request
$uri = "https://$storageAccount.file.core.windows.net/$shareName/$fileName"
$date = [DateTime]::UtcNow.ToString("R")

# Create signature
$stringToSign = "GET`n`n`n`n`n`n`n`n`n`n`n`nx-ms-date:$date`nx-ms-version:2021-06-08`n/$storageAccount/$shareName/$fileName"
$hmacsha = New-Object System.Security.Cryptography.HMACSHA256
$hmacsha.key = [Convert]::FromBase64String($storageKey)
$signature = [Convert]::ToBase64String($hmacsha.ComputeHash([Text.Encoding]::UTF8.GetBytes($stringToSign)))

# Download
$headers = @{
    "x-ms-date" = $date
    "x-ms-version" = "2021-06-08"
    "Authorization" = "SharedKey $storageAccount`:$signature"
}

Invoke-RestMethod -Uri $uri -Method Get -Headers $headers -OutFile $localPath
Write-Output "Downloaded to $localPath"