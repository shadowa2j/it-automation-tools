# This should be placed in c:\users\public\documents
# Remote app should be published as powershell.exe and require argument c:\users\public\documents\Force-Logoff.ps1

Write-Host 'Logging off the user' -ForegroundColor green;
Start-Sleep 5; 
logoff