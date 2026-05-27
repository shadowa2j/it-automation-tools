# This should be placed in c:\users\public\documents

Write-Host 'Initializing Mapped Drives and Printers' -ForegroundColor green;
wscript.exe 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\mapdrive.vbs';
Start-Sleep 5;

Set-Location $($env:userprofile);
Start-Process -FilePath "$($env:userprofile)\AppData\Local\Microsoft\OneDrive\OneDrive.exe";
