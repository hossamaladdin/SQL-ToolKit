# Requires Run as Administrator to access private key permissions

function Show-PrivateKeyPermissions {
    param (
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$cert
    )

    try {
        $rsaCert = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($cert)
        if ($rsaCert -is [System.Security.Cryptography.RSACng]) {
            $key = $rsaCert.Key
            $keyName = $key.UniqueName
            $keyPath = "C:\ProgramData\Microsoft\Crypto\Keys\$keyName"
            
            Write-Host "`nPrivate Key Information:" -ForegroundColor Cyan
            Write-Host "Key Path: $keyPath"
            
            if (Test-Path $keyPath) {
                $acl = Get-Acl -Path $keyPath
                Write-Host "`nPermissions:" -ForegroundColor Cyan
                $acl.Access | Format-Table IdentityReference, FileSystemRights, AccessControlType -AutoSize
            } else {
                Write-Host "Private key file not found at expected location." -ForegroundColor Yellow
            }
        } else {
            Write-Host "Private key is not in CNG format (non-RSA or legacy CSP)." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "Error accessing private key: $_" -ForegroundColor Red
    }
}

# Main script
Write-Host "`nListing computer certificates with private keys..." -ForegroundColor Green

$certs = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object { $_.HasPrivateKey }

if (-not $certs) {
    Write-Host "No certificates with private keys found in LocalMachine\My store." -ForegroundColor Yellow
    exit
}

# Display certificates with numbers
Write-Host "`nAvailable Certificates:" -ForegroundColor Cyan
for ($i = 0; $i -lt $certs.Count; $i++) {
    $cert = $certs[$i]
    Write-Host "$($i+1). $($cert.Subject) (Expires: $($cert.NotAfter))"
    Write-Host "   Thumbprint: $($cert.Thumbprint)"
    Write-Host "   Issuer: $($cert.Issuer)`n"
}

# Prompt for selection
do {
    $selection = Read-Host "`nEnter the number of the certificate to inspect (1-$($certs.Count)) or 'q' to quit"
    if ($selection -eq 'q') { exit }
} until ($selection -match "^\d+$" -and [int]$selection -ge 1 -and [int]$selection -le $certs.Count)

$selectedCert = $certs[[int]$selection-1]

# Display certificate details
Write-Host "`nSelected Certificate:" -ForegroundColor Green
$selectedCert | Format-List Subject, Issuer, Thumbprint, NotBefore, NotAfter, SerialNumber, HasPrivateKey

# Show private key permissions
Show-PrivateKeyPermissions -cert $selectedCert