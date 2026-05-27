# ========================================================
# Script:: Set-IQShortTimeFormat.ps1
#
# Copyright 2020, IQMS, Inc.
#
# All rights reserved - Do Not Redistribute
# For IQMS internal use only
# ========================================================

# clear host so we get a clean output in ISE
Clear-Host

$shortTime = "h:mm tt"
$timeFormat = "h:mm:ss tt"
$shortDate = "M/d/yyyy"

# Write-Host -ForegroundColor Yellow "$($env:USERDNSDOMAIN.ToLower()) domain detected..."
Write-Host -ForegroundColor Cyan "`nSetting short time to $shortTime"
Write-Host -ForegroundColor Cyan "`nSetting long time to $timeFormat"
Write-Host -ForegroundColor Cyan "`nSetting date to $shortDate"
Start-Sleep 1
reg add "HKEY_CURRENT_USER\Control Panel\International" /v sShortTime /d "$shortTime" /f
reg add "HKEY_CURRENT_USER\Control Panel\International" /v sTimeFormat /d "$timeFormat" /f
reg add "HKEY_CURRENT_USER\Control Panel\International" /v sShortDate /d "$shortDate" /f
Write-Host -ForegroundColor Cyan "`nRestarting explorer process..."
Stop-Process -Name "Explorer" -Force -ErrorAction Ignore

Write-Host -ForegroundColor Green "`nDone!`n"
Start-Sleep 1