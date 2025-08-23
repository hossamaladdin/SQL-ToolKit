# ==============================
# SQL Server 2016 → SQL Server 2019 Upgrade Script
# ==============================

# Instance name (default instance = MSSQLSERVER)
$InstanceName = "MSSQL"

# SQL Server 2019 setup.exe path
$SetupPath = ".\SW_DVD9_NTRL_SQL_Svr_Ent_Core_2019Dec2019_64Bit_English_OEM_VL_X22-22120\setup.exe"

# Product key mapping for 2016 → 2019
$ProductKeys = @{
    "Developer Edition"                       = "22222-00000-00000-00000-00000"
    "Enterprise Edition"                       = "HMWJ3-KY3J2-NMVD7-KG4JR-X2G8G"
    "Enterprise Edition: Core-based Licensing" = "2C9JR-K3RNG-QD4M4-JQ2HR-8468J"
    "Standard Edition"                         = "PMBDC-FXVM3-T777P-N4FY8-PKFF4"
}

# Registry: Find Instance ID
$InstanceRegBase = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL"
$InstanceId = (Get-ItemProperty $InstanceRegBase).$InstanceName
if (-not $InstanceId) {
    Write-Error "Instance '$InstanceName' not found in registry."
    exit 1
}

# Registry: Setup root
$InstanceRoot = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$InstanceId\Setup"

# Detect edition + version
$Edition = (Get-ItemProperty $InstanceRoot).Edition
$Version = (Get-ItemProperty $InstanceRoot).Version

Write-Host "Detected Instance ID: $InstanceId"
Write-Host "Detected Edition: $Edition"
Write-Host "Detected Version: $Version"

# Get product key
if ($ProductKeys.ContainsKey($Edition)) {
    $ProductKey = $ProductKeys[$Edition]
} else {
    Write-Error "No product key mapping for edition: $Edition"
    exit 1
}

# Get installed features
# $InstalledFeaturesList = ((Get-ItemProperty $InstanceRoot).FEATURES -split ',')

# Remove all Reporting Services features (RS, RS_SHP, RS_Native, etc.)
# $FilteredFeatures = $InstalledFeaturesList | Where-Object { $_ -notmatch '^RS' }
# if ($InstalledFeaturesList.Count -ne $FilteredFeatures.Count) {
#    Write-Warning "SSRS detected — excluded from upgrade (SQL 2019 requires separate install)."
# }
# $InstalledFeatures = $FilteredFeatures -join ','

Write-Host "Upgrading with features: $InstalledFeatures"

# Build parameters
$Params = @(
    "/ACTION=Upgrade",
	"/IAcceptRSUninstall=TRUE",
    "/INSTANCENAME=$InstanceName",
    "/PID=$ProductKey",
    "/IAcceptSQLServerLicenseTerms",
    "/IACCEPTROPENLICENSETERMS",
    "/QUIET",
    "/SUPPRESSPRIVACYSTATEMENTNOTICE=TRUE",
	"/UPDATEENABLED=FALSE"
)

# Execute upgrade
Write-Host "Launching SQL Server 2019 upgrade..."
Start-Process -FilePath $SetupPath -ArgumentList $Params -Wait

Write-Host "Upgrade completed."

# Start-Process -FilePath "./SQLServer2019-KB5058722-x64.exe" -ArgumentList `
#    "/quiet", `
#    "/IAcceptSQLServerLicenseTerms", `
#    "/INSTANCENAME=$InstanceName" `
#    -Wait
