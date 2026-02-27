#create CSR for LocalMachine
$CN = "$($env:COMPUTERNAME).$((Get-WmiObject Win32_ComputerSystem).Domain)"
$infContent = @"
[Version]
Signature="$Windows NT$"

[NewRequest]
Subject = "CN=$CN , O=Mobily, OU=Information Technology, L=Riyadh, S=Riyadh, C=SA"
KeyLength = 2048
Exportable = TRUE

[RequestAttributes]
CertificateTemplate = "WebServer"
"@
$infPath = [IO.Path]::Combine([Environment]::GetFolderPath("MyDocuments"), "$env:COMPUTERNAME.inf")
$ReqPath = [IO.Path]::Combine([Environment]::GetFolderPath("MyDocuments"), "$env:COMPUTERNAME.csr")
$infContent | Out-File -FilePath $infPath -Encoding ASCII
certreq -new -machine $infPath $ReqPath
Write-Output "CSR saved to: $ReqPath"

##################################################################################################
#try
certreq -accept <Certfile>

#if didn't work then need to add root and intermediate certs first
certutil -addstore Root <rootCAfile>
certutil -addstore CA <intermediateCAfile>
certreq -accept <Certfile>

#if still didnt work, export and re-import
$cert = Get-ChildItem Cert:\CurrentUser\My | Where-Object { $_.Subject -like "*O=Mobily*" }
$cert | Export-PfxCertificate -FilePath "$env:USERPROFILE\Documents\MobilyCert.pfx" -Password (ConvertTo-SecureString -String "1234" -Force -AsPlainText)

Import-PfxCertificate -FilePath "$env:USERPROFILE\Documents\MobilyCert.pfx" -CertStoreLocation Cert:\LocalMachine\My -Password (ConvertTo-SecureString -String "1234" -Force -AsPlainText)

#if didnt work, import then fix
Import-Certificate -CertStoreLocation Cert:\LocalMachine\My -FilePath <Certfile>
Get-ChildItem Cert:\LocalMachine\My | Format-List Subject, Thumbprint, HasPrivateKey
certutil -repairstore my <Thumbprint>
