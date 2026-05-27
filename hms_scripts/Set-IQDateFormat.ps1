# ========================================================
# Script:: Set-IQDateFormat.ps1
#
# Copyright 2021, IQMS, Inc.
#
# All rights reserved - Do Not Redistribute
# For IQMS internal use only
# ========================================================

# clear host so we get a clean output in ISE
Clear-Host

# find the domain and then alter the regkey according to that users domain
# restart explorer so takes effect immediately

$date1 = Get-Date -UFormat %d/%m/%Y
$date2 = Get-Date -UFormat %m/%d/%Y

Get-Date

$choice = 0
while (($choice -lt 1) -or ($choice -gt 2)) {
    Write-Host -ForegroundColor Yellow "`nWhich date format do you want to use?"
    Write-Host -ForegroundColor White "[1] dd/MM/yyyy Example: $($date1)"
    Write-Host -ForegroundColor White "[2] MM/dd/yyyy Example: $($date2)"
    $choice = Read-Host "Enter Option 1, or 2?"
}
if ($choice -eq 1) {
    $shortDate = "dd/MM/yyyy"
}
if ($choice -eq 2) {
    $shortDate = "MM/dd/yyyy"
}


# Write-Host -ForegroundColor Yellow "$($env:USERDNSDOMAIN.ToLower()) domain detected..."
Write-Host -ForegroundColor Cyan "`nSetting date to $shortDate"
Start-Sleep 1
reg add "HKEY_CURRENT_USER\Control Panel\International" /v sShortDate /d "$shortDate" /f
Write-Host -ForegroundColor Cyan "`nRestarting explorer process..."
Stop-Process -Name "Explorer" -Force -ErrorAction Ignore

Write-Host -ForegroundColor White "`You may need to close and re-open any DW/IQMS application for the date format to take effect."
Start-Sleep 3

Write-Host -ForegroundColor Green "`nDone!`n"
Start-Sleep 1
