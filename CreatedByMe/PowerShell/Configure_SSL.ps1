#create CSR
$CN = "$($env:COMPUTERNAME).$((Get-WmiObject Win32_ComputerSystem).Domain)"
$Cert = New-SelfSignedCertificate -DnsName $CN -CertStoreLocation Cert:\LocalMachine\My -KeyLength 2048 -KeyExportPolicy Exportable -KeySpec KeyExchange
$ReqPath = [IO.Path]::Combine([Environment]::GetFolderPath("MyDocuments"), "$env:COMPUTERNAME.csr")
Export-CertificateRequest -Cert $Cert -FilePath $ReqPath
Write-Output "CSR saved to: $ReqPath"


#try
certreq -accept <Certfile>

#if didnt work, import then fix
Import-Certificate -CertStoreLocation Cert:\LocalMachine\My -FilePath <Certfile>
Get-ChildItem Cert:\LocalMachine\My | Format-List Subject, Thumbprint, HasPrivateKey
certutil -repairstore my <Thumbprint>