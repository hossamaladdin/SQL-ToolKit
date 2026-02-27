# Set your values
$storageAccount = "your-storage-account"
$shareName = "backup"
$fileName =  "your-report-file.zip"
$storageKey = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"  # Get from Portal: your-storage-account → Access keys
$localPath = "C:\Downloads\your-report-file.zip"

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