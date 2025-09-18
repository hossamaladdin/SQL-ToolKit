@echo off
cd /d "%~dp0"

echo Upgrade started at %date% %time% > "start.txt"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "SQL_Upgrade.ps1"
echo Upgrade finished at %date% %time% > "end.txt"

exit /b %ERRORLEVEL%
