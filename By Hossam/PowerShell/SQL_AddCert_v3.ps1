# SQL Server Certificate Configuration Script

function Write-ColoredHost {
    param([string]$Message, [System.ConsoleColor]$ForegroundColor = [System.ConsoleColor]::White)
    Write-Host $Message -ForegroundColor $ForegroundColor
}

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-ColoredHost "This script requires administrative privileges. Please run PowerShell as an Administrator." -ForegroundColor Red
    exit
}

function Get-SQLServiceAccount {
    param([string]$InstanceId)
    $instanceName = ($InstanceId -split '\.')[1]
    $serviceName = if ($instanceName -eq "MSSQLSERVER") { "MSSQLSERVER" } else { "MSSQL`$$instanceName" }
    try {
        $serviceAccount = (Get-CimInstance -ClassName Win32_Service -Filter "Name = '$serviceName'").StartName
        return @{ ServiceName = $serviceName; Account = $serviceAccount }
    }
    catch {
        Write-ColoredHost "Could not find SQL Server service: $serviceName" -ForegroundColor Red
        return $null
    }
}

function Get-CertKeyInfo {
    param([System.Security.Cryptography.X509Certificates.X509Certificate2]$Cert)
    
    if (-not $Cert.HasPrivateKey) {
        return @{ HasKey = $false; Path = $null; Container = "No private key" }
    }
    
    try {
        $key = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($Cert)
        
        # Get container name
        if ($key -is [System.Security.Cryptography.RSACng]) {
            $container = $key.Key.UniqueName
        } else {
            $container = $Cert.PrivateKey.CspKeyContainerInfo.UniqueKeyContainerName
        }
        
        # Try both possible paths and use the one that exists
        $cngPath = "C:\ProgramData\Microsoft\Crypto\Keys\$container"
        $cspPath = "C:\ProgramData\Microsoft\Crypto\RSA\MachineKeys\$container"
        
        $keyPath = $null
        if (Test-Path $cspPath) {
            $keyPath = $cspPath
        } elseif (Test-Path $cngPath) {
            $keyPath = $cngPath
        } else {
            # Default to CSP path if neither exists (for display purposes)
            $keyPath = $cspPath
        }
        
        return @{ 
            HasKey = $true
            Path = $keyPath
            Container = $container.Substring(0, [Math]::Min(35, $container.Length))
            Exists = (Test-Path $keyPath)
        }
    }
    catch {
        return @{ HasKey = $false; Path = $null; Container = "Key access error" }
    }
}

function Get-CN {
    param([string]$DistinguishedName)
    if ($DistinguishedName -match "CN=([^,]+)") { return $matches[1] }
    return $DistinguishedName.Split('=')[-1]
}

try {
    # Get SQL instances
    Write-ColoredHost "`nChecking SQL Server instances..." -ForegroundColor Cyan
    $instances = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server" | Where-Object { $_.PSChildName -match '^MSSQL\d{2}\.' }
    if (-not $instances) { Write-ColoredHost "No SQL Server instances found." -ForegroundColor Red; exit }

    Write-ColoredHost "`nSQL Server instances:" -ForegroundColor Green
    for ($i = 0; $i -lt $instances.Count; $i++) {
        Write-ColoredHost "$($i+1). $($instances[$i].PSChildName)" -ForegroundColor Yellow
    }

    $instanceChoice = Read-Host "`nSelect instance (1-$($instances.Count))"
    if ([int]$instanceChoice -lt 1 -or [int]$instanceChoice -gt $instances.Count) {
        Write-ColoredHost "Invalid selection." -ForegroundColor Red; exit
    }
    $instanceId = $instances[$instanceChoice - 1].PSChildName

    # Get certificates
    Write-ColoredHost "`nAnalyzing certificates..." -ForegroundColor Cyan
    $certificates = Get-ChildItem Cert:\LocalMachine\My | Sort-Object NotAfter
    if (-not $certificates) { Write-ColoredHost "No certificates found." -ForegroundColor Red; exit }

    Write-ColoredHost "`nCertificates:" -ForegroundColor Green
    Write-ColoredHost ("{0,-3} {1,-12} {2,-25} {3,-20} {4}" -f "Idx", "Expiry", "Subject", "Issuer", "Key Status") -ForegroundColor Green
    
    $certInfo = @()
    for ($i = 0; $i -lt $certificates.Count; $i++) {
        $cert = $certificates[$i]
        $keyInfo = Get-CertKeyInfo -Cert $cert
        $subject = Get-CN -DistinguishedName $cert.Subject
        $issuer = Get-CN -DistinguishedName $cert.Issuer
        
        $status = if (-not $keyInfo.HasKey) { "No Key" } 
                  elseif (-not $keyInfo.Exists) { "Key Missing" } 
                  else { "OK" }
        
        $color = switch ($status) {
            "OK" { [System.ConsoleColor]::White }
            "Key Missing" { [System.ConsoleColor]::Yellow }
            default { [System.ConsoleColor]::Red }
        }
        
        Write-ColoredHost ("{0,-3} {1,-12} {2,-25} {3,-20} {4}" -f 
            ($i+1), $cert.NotAfter.ToString("yyyy-MM-dd"), 
            $subject.Substring(0, [Math]::Min(25, $subject.Length)),
            $issuer.Substring(0, [Math]::Min(20, $issuer.Length)), $status) -ForegroundColor $color
        
        $certInfo += @{ Cert = $cert; KeyInfo = $keyInfo }
    }

    $certChoice = Read-Host "`nSelect certificate (1-$($certificates.Count))"
    if ([int]$certChoice -lt 1 -or [int]$certChoice -gt $certificates.Count) {
        Write-ColoredHost "Invalid selection." -ForegroundColor Red; exit
    }
    
    $selectedCert = $certInfo[$certChoice - 1]
    if (-not $selectedCert.KeyInfo.HasKey) {
        Write-ColoredHost "`nWARNING: Certificate has no private key!" -ForegroundColor Red
        if ((Read-Host "Continue? (Y/N)") -ne "Y") { exit }
    }

    # Get service account and configure
    $sqlService = Get-SQLServiceAccount -InstanceId $instanceId
    if (-not $sqlService) { exit }

    $regPath = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$instanceId\MSSQLServer\SuperSocketNetLib"
    if (-not (Test-Path $regPath)) {
        Write-ColoredHost "Registry path not found: $regPath" -ForegroundColor Red; exit
    }

    if ((Read-Host "`nConfigure certificate? (Y/N)") -ne "Y") { exit }

    # Set registry
    Set-ItemProperty -Path $regPath -Name "Certificate" -Value $selectedCert.Cert.Thumbprint.ToLower()
    Write-ColoredHost "Certificate configured in registry:" -ForegroundColor Green
    Write-ColoredHost "  Thumbprint: $($selectedCert.Cert.Thumbprint.ToLower())" -ForegroundColor White
    Write-ColoredHost "  Key Path: $($selectedCert.KeyInfo.Path)" -ForegroundColor White

    # Set permissions if needed
    if ($selectedCert.KeyInfo.HasKey -and $selectedCert.KeyInfo.Exists -and $sqlService.Account -ne "LocalSystem") {
        try {
            $acl = Get-Acl $selectedCert.KeyInfo.Path
            $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
                $sqlService.Account, "Read", "Allow")))
            Set-Acl -Path $selectedCert.KeyInfo.Path -AclObject $acl
            Write-ColoredHost "Private key permissions updated:" -ForegroundColor Green
            Write-ColoredHost "  Service Account: $($sqlService.Account)" -ForegroundColor White
            Write-ColoredHost "  Key Path: $($selectedCert.KeyInfo.Path)" -ForegroundColor White
        }
        catch {
            Write-ColoredHost "Warning: Could not update key permissions." -ForegroundColor Yellow
        }
    }

    # Restart service
    if ((Read-Host "`nRestart SQL Server? (Y/N)") -eq "Y") {
        Restart-Service $sqlService.ServiceName -Force
        Write-ColoredHost "Service restarted:" -ForegroundColor Green
        Write-ColoredHost "  Service Name: $($sqlService.ServiceName)" -ForegroundColor White
        $serviceStatus = Get-Service $sqlService.ServiceName
        Write-ColoredHost "  Current Status: $($serviceStatus.Status)" -ForegroundColor White
    }

    Write-ColoredHost "`nCompleted successfully." -ForegroundColor Cyan
}
catch {
    Write-ColoredHost "`nError: $($_.Exception.Message)" -ForegroundColor Red
}