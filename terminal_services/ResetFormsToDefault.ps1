# ========================================================
# Script:: ResetFormsToDefault.ps1
#
# Resets IQMS form settings to default for the current user by
# removing HKCU registry keys and terminating IQMS applications.
# Equivalent to Help > About > File > Reset Form to Default.
#
# Deploy as a published RemoteApp:
#   powershell.exe -File "C:\Users\Public\Documents\ResetFormsToDefault.ps1"
# ========================================================

Clear-Host

# Prompt a warning for the end user
Write-Host -ForegroundColor Yellow "WARNING: This will delete IQMS Current User regkeys for user $($env:USERNAME) containing:"
Write-Host -ForegroundColor Yellow "`tForm Settings"
Write-Host -ForegroundColor Yellow "`tDialog Check Boxes"
Write-Host -ForegroundColor Yellow "`tCustomizations"
Write-Host -ForegroundColor Yellow "`tSaved Login"

Write-Host -ForegroundColor White "`nThis option resets the forms to their original settings."
Write-Host -ForegroundColor White "Equivalent to: Help > About > File > Reset Form to Default."
Write-Host -ForegroundColor White "All open IQMS applications will be closed for the changes to take effect."

Write-Host -ForegroundColor White "`nAre you sure you want to reset forms to default?"
Read-Host -Prompt "Press ENTER to continue or CTRL+C to cancel"

# Delete the current user IQMS regkeys
if (Test-Path "HKCU:\Software\IQMS") {
    Write-Host -ForegroundColor Yellow "`nResetting Forms to Default..."
    Write-Host -ForegroundColor Cyan "Deleting regkeys for $($env:USERNAME) at HKCU:\Software\IQMS\*"
    try {
        Remove-Item -Path "HKCU:\Software\IQMS\*" -Recurse -ErrorAction Stop
        Write-Host -ForegroundColor Green "`nForms have been reset and regkeys deleted."
    }
    catch {
        Write-Host -ForegroundColor Red "`nFailed to delete regkeys: $($_.Exception.Message)"
        Write-Host -ForegroundColor Red "Please contact the QCS Service Desk for assistance."
        Start-Sleep 5
        exit 1
    }
} else {
    Write-Host -ForegroundColor Green "`nNo IQMS regkeys found for $($env:USERNAME). Nothing to reset."
}

Start-Sleep 2

# Close IQMS applications for the current user so changes take effect
$remoteApps = @("AssyData.exe", "IQCRM.exe", "IQWin32.exe", "ShopData.exe", "SmartPage.exe")
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop

foreach ($app in $remoteApps) {
    $appShort = $app.Substring(0, $app.IndexOf('.'))

    Write-Host -ForegroundColor Cyan "`nLooking for $app..."
    
    try {
        $processes = Get-CimInstance -ClassName Win32_Process -Filter "Name = '$app'" -ErrorAction Stop |
            Where-Object { (Invoke-CimMethod -InputObject $_ -MethodName GetOwner).User -eq $env:USERNAME }
    }
    catch {
        Write-Host -ForegroundColor Yellow "Could not query processes for $app`: $($_.Exception.Message)"
        continue
    }

    if (-not $processes) {
        Write-Host -ForegroundColor Gray "$app is not running."
        continue
    }

    foreach ($process in $processes) {
        try {
            Stop-Process -Id $process.ProcessId -Force -ErrorAction Stop
            Write-Host -ForegroundColor Green "$appShort terminated successfully."
        }
        catch {
            Write-Host -ForegroundColor Red "Unable to stop $appShort`: $($_.Exception.Message)"
            Write-Host -ForegroundColor Red "Please close $appShort manually and relaunch it."
        }
    }
}

Write-Host -ForegroundColor Green "`nDone. Please relaunch your IQMS applications."
