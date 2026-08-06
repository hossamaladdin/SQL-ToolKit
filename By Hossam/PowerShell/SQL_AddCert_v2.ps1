# SQL Server Certificate Configuration Script

# Function to write colored output
function Write-ColoredHost {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [Parameter(Mandatory=$false)]
        [System.ConsoleColor]$ForegroundColor = [System.ConsoleColor]::White
    )
    Write-Host $Message -ForegroundColor $ForegroundColor
}

# Check for administrative privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-ColoredHost "This script requires administrative privileges. Please run PowerShell as an Administrator." -ForegroundColor Red
    exit
}

# Function to get SQL Server service account
function Get-SQLServiceAccount {
    param (
        [Parameter(Mandatory = $true)]
        [string]$InstanceId
    )

    $instanceName = ($InstanceId -split '\.')[1]
    $serviceName = if ($instanceName -eq "MSSQLSERVER") { "MSSQLSERVER" } else { "MSSQL`$$instanceName" }

    try {
        $service = Get-Service -Name $serviceName -ErrorAction Stop
        $serviceAccount = (Get-CimInstance -ClassName Win32_Service -Filter "Name = '$serviceName'").StartName
        return @{
            ServiceName = $serviceName
            Account     = $serviceAccount
        }
    }
    catch {
        Write-ColoredHost "Could not find SQL Server service: $serviceName" -ForegroundColor Red
        return $null
    }
}

# Main script execution
try {
    # Step 1: List available SQL Server instances
    Write-ColoredHost "`nChecking available SQL Server instances..." -ForegroundColor Cyan
    $instances = Get-ChildItem -Path "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server" | 
        Where-Object { $_.PSChildName -match '^MSSQL\d{2}\.' }

    if (-not $instances) {
        Write-ColoredHost "No SQL Server instances found." -ForegroundColor Red
        exit
    }

    # Display instances
    Write-ColoredHost "`nAvailable SQL Server instances:" -ForegroundColor Green
    $instances | ForEach-Object -Begin { $i = 1 } -Process {
        Write-ColoredHost "$i. $($_.PSChildName)" -ForegroundColor Yellow
        $i++
    }

    # Step 2: Instance selection
    $instanceChoice = Read-Host "`nEnter the number of the SQL Server instance you want to use (1-$($instances.Count))"
    if (($instanceChoice -as [int]) -lt 1 -or ($instanceChoice -as [int]) -gt $instances.Count) {
        Write-ColoredHost "Invalid selection. Exiting." -ForegroundColor Red
        exit
    }
    $instanceId = $instances[$instanceChoice - 1].PSChildName
    Write-ColoredHost "Selected instance: $instanceId`n" -ForegroundColor Green

    # Step 3: Certificate selection
    Write-ColoredHost "`nAvailable certificates:" -ForegroundColor Cyan
    $certificates = @(Get-ChildItem -Path Cert:\LocalMachine\My | Sort-Object NotAfter)
    
    if (-not $certificates) {
        Write-ColoredHost "No certificates found in LocalMachine\My store." -ForegroundColor Red
        exit
    }

    # Display certificates
    Write-ColoredHost ("{0,-5} {1,-25} {2,-40} {3}" -f "Index", "Expiry Date", "Subject", "Issuer") -ForegroundColor Green
    $certificates | ForEach-Object -Begin { $i = 1 } -Process {
        Write-ColoredHost ("{0,-5} {1,-25} {2,-40} {3}" -f $i++, $_.NotAfter.ToString("yyyy-MM-dd"), $_.Subject.Split('=')[-1], $_.Issuer.Split('=')[-1]) -ForegroundColor Yellow
    }

    # Certificate selection
    $certChoice = Read-Host "`nEnter the number of the certificate to use (1-$($certificates.Count))"
    if (($certChoice -as [int]) -lt 1 -or ($certChoice -as [int]) -gt $certificates.Count) {
        Write-ColoredHost "Invalid certificate selection. Exiting." -ForegroundColor Red
        exit
    }
    $selectedCert = $certificates[$certChoice - 1]
    Write-ColoredHost ("`nSelected certificate:`nThumbprint: {0}`nSubject: {1}`nExpiry: {2}`n" -f 
        $selectedCert.Thumbprint, $selectedCert.Subject, $selectedCert.NotAfter) -ForegroundColor Green

    # Step 4: Get SQL service account
    $sqlService = Get-SQLServiceAccount -InstanceId $instanceId
    if (-not $sqlService) { exit }

    # Step 5: Validate registry path
    $regPath = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$instanceId\MSSQLServer\SuperSocketNetLib"
    if (-not (Test-Path $regPath)) {
        Write-ColoredHost "Registry path not found: $regPath" -ForegroundColor Red
        exit
    }

    # Confirmation
    $confirm = Read-Host "`nReady to configure certificate for SQL Server. Continue? (Y/N)"
    if ($confirm -ne "Y") {
        Write-ColoredHost "Operation cancelled." -ForegroundColor Yellow
        exit
    }

    # Step 6: Configure registry
	Set-ItemProperty -Path $regPath -Name "Certificate" -Value $selectedCert.Thumbprint.ToLower() -ErrorAction Stop
    Write-ColoredHost "`nCertificate thumbprint added to registry." -ForegroundColor Green

    # Step 7: Configure private key permissions
    $key = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($selectedCert)
	$keyPath = if ($key -is [System.Security.Cryptography.RSACng]) {
		"C:\ProgramData\Microsoft\Crypto\Keys\$($key.Key.UniqueName)"
	} else {
		"$env:ProgramData\Microsoft\Crypto\RSA\MachineKeys\$($selectedCert.PrivateKey.CspKeyContainerInfo.UniqueKeyContainerName)"
	}

	if (-not (Test-Path $keyPath)) {
		Write-ColoredHost "Private key path not found: $keyPath" -ForegroundColor Red
		exit
	}

	# Skip permission update if account is LocalSystem
	if ($sqlService.Account -eq "LocalSystem") {
		Write-ColoredHost "`nService account is LocalSystem - no permission update needed" -ForegroundColor Yellow
	} else {
		$acl = Get-Acl $keyPath
		$acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
			$sqlService.Account,
			[System.Security.AccessControl.FileSystemRights]::Read,
			[System.Security.AccessControl.AccessControlType]::Allow
		)))
		Set-Acl -Path $keyPath -AclObject $acl
		Write-ColoredHost "`nPrivate key permissions updated for service account: $($sqlService.Account)" -ForegroundColor Green
	}

    # Step 8: Service restart
    $service = Get-Service -Name $sqlService.ServiceName -ErrorAction SilentlyContinue
    if (-not $service) {
        Write-ColoredHost "SQL Server service not found: $($sqlService.ServiceName)" -ForegroundColor Red
        exit
    }

    $restart = Read-Host "`nRestart SQL Server service? (Y/N)"
    if ($restart -eq "Y") {
        $service | Restart-Service -Force
        Write-ColoredHost "`nService restart initiated. Verify service status." -ForegroundColor Green
    }
}
catch {
    Write-ColoredHost "`nError occurred: $($_.Exception.Message)" -ForegroundColor Red
    exit
}

Write-ColoredHost "`nOperation completed successfully." -ForegroundColor Cyan