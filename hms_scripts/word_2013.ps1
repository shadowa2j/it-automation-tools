# This should be placed in c:\users\public\documents
# Remote app should be published as powershell.exe and require argument c:\users\public\documents\Excel.ps1

Write-Host 'Initializing Mapped Drives and Printers' -ForegroundColor green;
wscript.exe 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\mapdrive.vbs';
Start-Sleep 10; 
cd 'c:\Program Files (x86)\Microsoft Office\Office15\'; 
Start-Process -FilePath 'c:\Program Files (x86)\Microsoft Office\Office15\winword.exe';