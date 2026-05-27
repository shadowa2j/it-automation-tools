# This should be placed in c:\users\public\documents
# Remote app should be published as powershell.exe and require argument c:\users\public\documents\Set-IQDefaultPrinter.ps1

# this is for making a selection of collection
$printers = Get-Printer | Select-Object -ExpandProperty Name | Sort-Object
$printerNumber = 1

# list options
Write-Host -ForegroundColor Cyan "`nGathering list of network printers..."
foreach ($printer in $printers) {
    Write-Host "[$printerNumber] - $printer"
    if ($printerNumber -lt $printers.count) {
        $printerNumber++
    }
}
Write-Host -ForegroundColor Yellow "`nEnter number of printer to set as default..."
Write-Host -ForegroundColor Yellow "`tThis will close DELMIA|Works applications for $($env:username) if open. CTRL+C to cancel if needed..."

# allow choice of option in int value, check for real value
[int]$printerChoice = Read-Host "Printer Number"
if (($printerChoice -ge 1) -and ($printerChoice -le $printers.Count)) {
    $printerDefault = $($printers[$printerChoice-1])
    Write-Host -ForegroundColor Cyan "`nSetting $($printerDefault) as default printer..."
    Start-Sleep 5 # give the end user a chance to cancel the script as a backup measure
    # Set Printer
    rundll32 printui.dll,PrintUIEntry /y /n "$printerDefault"
    Write-Host "`Done!" -ForegroundColor Green
} else {
    Throw "Not a valid printer choice... script terminated"
}

# Define the remote apps to close
$remoteApps = @("AssyData.exe", "IQCRM.exe", "IQWin32.exe", "ShopData.exe", "SmartPage.exe")
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop

# Get current user's username
$currentUsername = $env:USERNAME

foreach ($app in $remoteApps) {
    $appShort = $app.Substring(0, $app.IndexOf('.'))
    Write-Host -ForegroundColor Cyan "`nAttempting to find $($app)..."
    
    # Use WMI to get processes by name and filter for the current user
    $processes = Get-CimInstance -ClassName Win32_Process | Where-Object {
        $_.Name -eq $app -and $_.GetOwner().User -eq $currentUsername
    }
    
    # Stop the processes owned by the current user
    foreach ($process in $processes) {
        try {
            Stop-Process -Id $process.ProcessId -Force -Verbose
            Write-Host "$appShort was successfully terminated!" -ForegroundColor Green
        } catch {
            Write-Host "Unable to stop process for $appShort. Please contact the IQMS Cloud Operations Service Desk." -ForegroundColor Red
            Start-Sleep 5
        }
    }
}


Write-Host -ForegroundColor Green "`nDone."
Write-Host -ForegroundColor Green "`nDefault Printer in Windows has been assigned to $($printerDefault)."
Start-Sleep 2