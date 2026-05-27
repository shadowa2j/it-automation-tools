# This should be placed in c:\users\public\documents
# Remote app should be published as powershell.exe and require argument c:\users\public\documents\IQDBX.ps1

Write-Host 'Initializing Mapped Drives and Printers' -ForegroundColor green;
wscript.exe 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\mapdrive.vbs';
Start-Sleep 5; 
cd 'c:\Program Files (x86)\IQMS\IQWin32\'; 
Start-Process -FilePath 'c:\Program Files (x86)\IQMS\IQWin32\IQDBX.exe';
Start-Process -FilePath 'C:\Windows\System32\explorer.exe' -ArgumentList 'C:\dataload'
exit
