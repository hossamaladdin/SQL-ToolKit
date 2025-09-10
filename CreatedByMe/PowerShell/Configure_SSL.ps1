#create CSR
$CN = "$($env:COMPUTERNAME).$((Get-WmiObject Win32_ComputerSystem).Domain)"
$infContent = @"
[NewRequest]
Subject = "CN=$CN"
KeyLength = 2048
Exportable = TRUE
"@
$infPath = [IO.Path]::Combine([Environment]::GetFolderPath("MyDocuments"), "$env:COMPUTERNAME.inf")
$ReqPath = [IO.Path]::Combine([Environment]::GetFolderPath("MyDocuments"), "$env:COMPUTERNAME.csr")
$infContent | Out-File -FilePath $infPath -Encoding ASCII
certreq -new $infPath $ReqPath
Write-Output "CSR saved to: $ReqPath"

##################################################################################################
#try
certreq -accept <Certfile>

#if didnt work, import then fix
Import-Certificate -CertStoreLocation Cert:\LocalMachine\My -FilePath <Certfile>
Get-ChildItem Cert:\LocalMachine\My | Format-List Subject, Thumbprint, HasPrivateKey
certutil -repairstore my <Thumbprint>