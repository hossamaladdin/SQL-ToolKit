#Run on secondary node of the cluster, not particularly the secondary AG replica!
#you can determine which node is secondary by trying to open failover cluster manager on it and it would probably fail
#Remove Cloud Witness
Set-ClusterQuorum -NodeMajority

# Replace YOUR-KEY-HERE with your actual storage account key
$key = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -WindowStyle Hidden -Command `"Set-ClusterQuorum -CloudWitness -AccountName saaprfs -AccessKey '$key' | Out-File C:\temp\cluster-result.txt`""
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

# Create temp directory
New-Item -Path C:\temp -ItemType Directory -Force -ErrorAction SilentlyContinue

# Register and run
Register-ScheduledTask -TaskName "FixCloudWitness" -Action $action -Principal $principal -Force
Start-ScheduledTask -TaskName "FixCloudWitness"
Start-Sleep -Seconds 15

# Check results
Get-Content C:\temp\cluster-result.txt -ErrorAction SilentlyContinue
Get-ClusterQuorum
Get-ClusterResource "Cloud Witness" -ErrorAction SilentlyContinue

# Cleanup
Unregister-ScheduledTask -TaskName "FixCloudWitness" -Confirm:$false
