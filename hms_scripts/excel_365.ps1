# This should be placed in c:\users\public\documents
# Remote app should be published as powershell.exe and require argument c:\users\public\documents\Excel.ps1

Write-Host 'Initializing Mapped Drives and Printers' -ForegroundColor green;
reg add "HKCU\Software\Microsoft\Office\16.0\Excel\Security" /v AccessVBOM /t reg_dword /d 1 /f;
wscript.exe 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\mapdrive.vbs';
Start-Sleep 10; 
cd 'C:\Program Files (x86)\Microsoft Office\root\Office16'; 
Start-Process -FilePath 'C:\Program Files (x86)\Microsoft Office\root\Office16\excel.exe';