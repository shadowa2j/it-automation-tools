# This should be placed in c:\users\public\documents
# Remote app should be published as powershell.exe and require argument c:\users\public\documents\clear_hkcu.ps1

Write-Host 'Attempting to clear HKEY Current User Regkeys for IQMS' -ForegroundColor yellow;

If (Get-Item HKCU:\Software\IQMS -ErrorAction SilentlyContinue) {
    Remove-Item HKCU:\Software\IQMS -Recurse -Force -Verbose
} else {
    Write-Host "Regkeys do not exist or have already been cleared." -ForegroundColor Green
}

Start-Sleep 3; 