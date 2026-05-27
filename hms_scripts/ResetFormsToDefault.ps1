Clear-Host

# Prompt a warning for the end user
Write-Host -ForegroundColor Yellow "WARNING: This will delete IQMS Current User regkeys for user $($env:username) containing:"
Write-Host -ForegroundColor Yellow "`tCustomizations"
Write-Host -ForegroundColor Yellow "`tForm Settings"
Write-Host -ForegroundColor Yellow "`tDialog Check Boxes"
Write-Host -ForegroundColor Yellow "`tCustomizations"
Write-Host -ForegroundColor Yellow "`tSave User Login"

Write-Host -ForegroundColor White "`nThis option resets the forms to their original settings"
Write-Host -ForegroundColor White "Essentially the same as Help > About > File > Reset Form to Default."
Write-Host -ForegroundColor White "This will terminate applications you have open in order for changes to take effect."

Write-Host -ForegroundColor White "`nAre you sure you want to reset the forms to its default setting?"
Read-Host -Prompt "`Press any key to continue or CTRL+C to quit"

# delete the current user regkeys
Set-Location -path "HKCU:"
if (!(Test-Path "HKCU:\Software\IQMS") -eq $false) {
    Write-Host -ForegroundColor Yellow "`nResetting Forms to Default..."
    Write-Host -ForegroundColor Cyan "Deleting Regkeys for $($env:Username) at HKCU:\Software\IQMS\*"
    Remove-Item -Path "HKCU:\Software\IQMS\*" -Recurse
    Write-Host -ForegroundColor Green "`nForms have been reset and regkeys deleted."
} else {
    Write-Host -ForegroundColor Green "`nNo forms to reset. Restarting apps..."
}

Set-Location $env:USERPROFILE
Start-Sleep 2

# close applications to go into effect
$remoteApps = ("AssyData.exe","IQCRM.exe","IQWin32.exe","ShopData.exe","SmartPage.exe")
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop

Foreach ($app in $remoteApps) {
    # Convert the full process name, to a short name without .exe
    $appShort = $app.Substring(0, $app.IndexOf('.'))

    # Find all remoteApps running for the current user
    Write-Host -ForegroundColor Cyan "`nAttempting to find $($app)..."
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

Write-Host -ForegroundColor Green "`nDone"
Start-Sleep 2
