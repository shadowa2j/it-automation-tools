# This should be placed in c:\users\public\documents
# Remote app should be published as powershell.exe and require argument c:\users\public\documents\SmartPage.ps1

# run mapdrive vbs script and sleep to load printers
Write-Host -ForegroundColor yellow "`nInitializing Mapped Drives and Printers..."
wscript.exe "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\mapdrive.vbs"
Start-Sleep 5

# check if we are using a printer map script
Write-Host -ForegroundColor yellow "`nChecking for default printer map script..."
$printerMap = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\printermap.bat"
if (Test-Path -Path $printerMap) {
    Write-Host -ForegroundColor green "Default printer map script found!"
    Start-Process -FilePath $printerMap -Wait
}

# launch applications
Write-Host -ForegroundColor green "`nLaunching application..."
Set-Location "c:\Program Files (x86)\IQMS\IQWin32\"
Start-Process -FilePath "c:\Program Files (x86)\IQMS\IQWin32\smartpage.exe" -Verbose
