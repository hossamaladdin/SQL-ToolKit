<#
 Script: Uninstall-SQL2017-SLQ16.ps1
 Purpose:
   - Clears registry entries that make SQL Server setup think a reboot is pending.
   - Runs SQL Server 2017 setup.exe in quiet mode to uninstall instance SLQ16.
#>

Write-Host "=== Step 1: Clearing Pending Restart Flags ===" -ForegroundColor Cyan

# Function to backup and remove a registry value or key
function Remove-RegEntry {
    param (
        [string]$Path,
        [string]$ValueName = $null
    )
    try {
        if ($ValueName) {
            $val = Get-ItemProperty -Path $Path -Name $ValueName -ErrorAction SilentlyContinue
            if ($val) {
                Write-Host "Clearing $Path\$ValueName"
                Remove-ItemProperty -Path $Path -Name $ValueName -Force
            }
        } else {
            if (Test-Path $Path) {
                $backupName = ($Path.Split('\')[-1] + "_backup_" + (Get-Date -Format 'yyyyMMddHHmmss'))
                Rename-Item -Path $Path -NewName $backupName
                Write-Host "Renamed $Path -> $backupName"
            }
        }
    } catch {
        Write-Host "Failed to modify $Path - $_" -ForegroundColor Red
    }
}

# Clear common pending reboot keys
Remove-RegEntry -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -ValueName "PendingFileRenameOperations"
Remove-RegEntry -Path "HKLM:\SOFTWARE\Microsoft\Updates" -ValueName "UpdateExeVolatile"
Remove-RegEntry -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending"
Remove-RegEntry -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"

Write-Host "=== Pending restart flags cleared ===" -ForegroundColor Green

# Corrected SQL Server 2017 setup path
$SQLSetupPath = "C:\Program Files\Microsoft SQL Server\140\Setup Bootstrap\SQL2017\setup.exe"

if (Test-Path $SQLSetupPath) {
    Write-Host "=== Step 2: Starting SQL Server 2017 instance SLQ16 uninstall ===" -ForegroundColor Cyan
    
    & $SQLSetupPath /q /ACTION=Uninstall `
        /INSTANCENAME=SLQ16 `
        /FEATURES=SQL,Conn,BC,SDK `
        /IACCEPTSQLSERVERLICENSETERMS `
        /INDICATEPROGRESS
    
    Write-Host "Uninstall command executed. Check logs under C:\Program Files\Microsoft SQL Server\140\Setup Bootstrap\Log" -ForegroundColor Green
} else {
    Write-Host "SQL Server 2017 setup.exe not found at $SQLSetupPath. Please confirm the path." -ForegroundColor Red
}
