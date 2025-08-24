@echo off
del /q "D:\SQLGrafana\healthcheck_*"

powershell.exe -ExecutionPolicy Bypass -File "D:\SQLGrafana\SQLHealthcheck.ps1"

(
	echo cd /userdata/SQLHealthCheck/input/
	echo lcd D:\SQLGrafana
	echo mput healthcheck_*
	echo quit
)|D:\SQLGrafana\psftp.exe -i D:\SQLGrafana\PRIV.ppk grapsftp@10.64.75.94
