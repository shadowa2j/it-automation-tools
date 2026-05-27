Clear-Host

# Prompt a warning for the end user
Write-Host -ForegroundColor White -BackgroundColor Red "WARNING: THIS WILL FORCE LOG OUT $($env:username) FROM THE ENVIRONMENT!"
Write-Host -ForegroundColor White "`nThe purpose of this tool is to bypass any disconnect or idle timeouts set for the environment."
Write-Host -ForegroundColor White "This is useful if you are experiencing a locked/frozen session but may not fully resolve depending on the nature of the lock."
Write-Host -ForegroundColor White "`nMost often, locks or freezing can occur if a window is appearing off-screen."
Write-Host -ForegroundColor White "If so, following tools maybe a better option:"
Write-Host -ForegroundColor Cyan "`tFIX EIQ Window Position"
Write-Host -ForegroundColor Cyan "`tReset Forms to Default"
Write-Host -ForegroundColor White "`nIf you continue to have issues, please reach out to the HMS Service Desk:"
Write-Host -ForegroundColor Cyan "`thttp://support.iqms-cloud.com"

Write-Host -ForegroundColor White -BackgroundColor Red "`nAre you sure you want to continue?"
Read-Host -Prompt "`Press any key to continue or CTRL+C to quit"

# start logoff process
Write-Host -ForegroundColor Cyan "`nLogging off in 3 seconds..."
Start-Sleep 3
Start-Process -FilePath "C:\windows\system32\logoff.exe"
