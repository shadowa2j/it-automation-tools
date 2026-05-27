# This should be placed in c:\users\public\documents
# Remote app should be published as powershell.exe and require argument c:\users\public\documents\enterpriseiq.ps1

Write-Host 'Initializing Mapped Drives and Printers' -ForegroundColor green;
wscript.exe 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\mapdrive.vbs';
Start-Sleep 5; 
cd "C:\Program Files (x86)\Adobe\Acrobat Reader DC\Reader\"; 
Start-Process -FilePath "C:\Program Files (x86)\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe";