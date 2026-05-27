# This should be placed in c:\users\public\documents
# Remote app should be published as powershell.exe and require argument c:\users\public\documents\IQ_Clock.ps1

# close possible duplicate isntances of IQ_Clock
$remoteApps = ("IQ_Clock.exe")
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop

Foreach ($app in $remoteApps) {
    # Convert the full process name, to a short name without .exe
    $appShort = $app.Substring(0, $app.IndexOf('.'))

    # Find all remoteApps running for the current user
    Write-Host -ForegroundColor Cyan "`nSetting up session for $($app)..."
    $processes = Get-WmiObject -Class win32_process | Where-Object {$_.name -eq $app} | Where-Object {$_.GetOwner().user -eq "$env:USERNAME"}
    
    # Find the specific process IDs associated to the remoteApp
    foreach ($process in $processes) {
        try {
            Stop-Process -Id $process.processId -Force -verbose
            Write-Host "$appShort was successfull terminated!" -ForegroundColor green
        }
        catch {
            Write-Host "Unable to stop process for $appShort. Please contact the IQMS Cloud Operations Service Desk." -ForegroundColor red
            Start-Sleep 5;
        }
    }
}

Write-Host "Initializing Mapped Drives and Printers" -ForegroundColor green;
wscript.exe "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\mapdrive.vbs";
Start-Sleep 3;

Set-Location -Path "c:\Program Files (x86)\IQMS\IQWin32\";
Start-Process -FilePath "c:\Program Files (x86)\IQMS\IQWin32\IQ_Clock.exe";
