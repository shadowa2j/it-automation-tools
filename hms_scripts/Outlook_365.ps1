# This should be placed in c:\users\public\documents
# Remote app should be published as powershell.exe and require argument c:\users\public\documents\Excel.ps1

Write-Host 'Initializing Mapped Drives and Printers' -ForegroundColor green;
wscript.exe 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\mapdrive.vbs';
Start-Sleep 5;

# Import HMSPublic module for functions
Import-Module HMSPublic

# Add Outlook Trusted Sites
Add-HMSTrustedSite -zone 2 -siteName "login.microsoftonline.com"
Add-HMSTrustedSite -zone 2 -siteName "aadcdn.msftauth.net"
Add-HMSTrustedSite -zone 2 -siteName "aadcdn.msauth.net"

# Set protected mode to disabled for local intranet and trusted sites
Set-HMSIEProtectedMode -zone 1 -value 3
Set-HMSIEProtectedMode -zone 2 -value 3

cd 'C:\Program Files (x86)\Microsoft Office\root\Office16'; 
Start-Process -FilePath 'C:\Program Files (x86)\Microsoft Office\root\Office16\outlook.exe';