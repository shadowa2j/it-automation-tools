# This should be placed in c:\users\public\documents
# Remote app should be published as powershell.exe and require argument c:\users\public\documents\IQAlert-Auto.ps1
Write-Host 'Initializing Mapped Drives and Printers' -ForegroundColor green;
wscript.exe 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\mapdrive.vbs';
Start-Sleep 5; 
cd 'c:\Program Files (x86)\IQMS\IQWin32\';

# get rt_wd process
$watchdog = Get-Process "rt_wd" -ErrorAction SilentlyContinue
if ($watchdog) {
    Write-Host "WatchDog is already running."
} else {
    Write-Host "Starting WatchDog..."
    Start-Process -FilePath 'c:\Program Files (x86)\IQMS\IQWin32\rt_wd.exe';
}

# get eserver process
$iqalert = Get-Process "iqalert" -ErrorAction SilentlyContinue
if ($iqalert) {
    Write-Host "IQAlert is already running."
} else {
    Write-Host "Starting IQAlert..."
    Start-Process -FilePath 'c:\Program Files (x86)\IQMS\IQWin32\iqalert.exe' -ArgumentList "auto";
}

