$CPU_Usage    = "$((GWMI -ComputerName $env:computername win32_processor | Measure-Object -property LoadPercentage -Average).Average)"
$Mem = GWMI -Class win32_operatingsystem -computername $env:computername
$Memory_Usage = "$("{0:N0}" -f ((($Mem.TotalVisibleMemorySize - $Mem.FreePhysicalMemory)*100)/ $Mem.TotalVisibleMemorySize))"
$Total_Memory=[math]::Round($Mem.TotalVisibleMemorySize/(1024*1024),2)
$Free_Memory=[math]::Round($Mem.FreePhysicalMemory/(1024*1024),2)
$processcount=@(Get-Process).count
$timer = (Get-Date -uFormat %s)
$connectioncount=@(netstat -an |findstr "EST").count
$servicecount=@(get-service|findstr "Running").count
Write-Output "Windows_HealthCheck,Hostname,Measurement_Type,Usage_NUM`n
Windows_HealthCheck,$env:computername,Memory_Usage,$Memory_Usage`n
Windows_HealthCheck,$env:computername,CPU_Usage,$CPU_Usage`n
Windows_HealthCheck,$env:computername,Process_Count,$processcount`n
Windows_HealthCheck,$env:computername,Connection_Count,$connectioncount`n
Windows_HealthCheck,$env:computername,Service_Count,$servicecount`n
Windows_HealthCheck,$env:computername,TotalMemory,$Total_Memory`n
Windows_HealthCheck,$env:computername,FreeMemory,$Free_Memory" >>C:\temp\wgrafana2\healthcheck_h_$env:computername"_"$timer
Write-Output "Windows_DiskUsage,Hostname,DiskName,Disk_Usage_NUM,Free_NUM,Total_NUM" >>C:\temp\wgrafana2\healthcheck_disk_$env:computername"_"$timer
$drives=Get-WmiObject Win32_LogicalDisk -ComputerName $env:computername -filter DriveType=3
foreach ($drive in $drives){
            $drivename=$drive.DeviceID
            $freespace=[math]::Round($drive.FreeSpace/1GB,2)
            $totalspace=[math]::Round($drive.Size/1GB,2)
            $percentage=[math]::round(100*($totalspace - $freespace)/$totalspace)
			Write-Output "Windows_DiskUsage,$env:computername,$drivename,$percentage,$freespace,$totalspace">>C:\temp\wgrafana2\healthcheck_disk_$env:computername"_"$timer
}

$data1 = netstat -e
$data1 = $data1 | ForEach-Object {"Windows_NetStat_E,$env:computername,$_"}
echo "Windows_NetStat_E,HostName,Received_NUM,Sent_NUM" >C:\temp\wgrafana2\healthcheck_netstat_e_$env:computername"_"$timer
$data1= $data1 -replace '\s\s+',","
$data1= $data1 -replace 'bytes,',""
$data1[4] >>C:\temp\wgrafana2\healthcheck_netstat_e_$env:computername"_"$timer
