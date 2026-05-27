# This should be placed in c:\users\public\documents
# Remote app should be published as powershell.exe and require argument c:\users\public\documents\FileExplorer_UserTemp.ps1

Write-Host -ForegroundColor Cyan "Initializing Mapped Drives`n"

# Enter the Drives that we will loop over. For example: "M:"
$drives = @("M:")
$maxAttempts = 5
Foreach ($drive in $drives) {
    $timer = 6
    $incrementTimer = 1
    # Sets up a loop to continue attempting to map the drives
    For ($attempt = 1; $attempt -le 5; $attempt++) {
        If ((Test-Path $drive) -eq $false) {
            Write-Host -ForegroundColor Yellow "[$attempt/$maxAttempts] Attempting to map $drive Drive over $timer seconds..."
            wscript.exe 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\mapdrive.vbs';
            # To give drive mapping more time
            Start-Sleep $timer
            $timer = $timer + $incrementTimer
        } else {
            Write-Host -ForegroundColor Green "$drive Drive Mapped Successfully!`n"
            $attempt = $maxAttempts
        }
        # We tried, let's move on...
        If ((Test-Path $drive) -eq $false -and $attempt -eq $maxAttempts) {
            Write-Host -ForegroundColor Red "Mapping of $drive Drive failed!`n"
            Start-Sleep 2
        }
    }
}

$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
Set-ItemProperty -Path $key -Name NavPaneShowAllFolders 1
Set-ItemProperty $key HideFileExt 1
# Set-ItemProperty $key Hidden 1
Stop-Process -processname explorer -ErrorAction ignore -Force
Start-Sleep 1

if ($false -eq (Test-Path -Path "$env:USERPROFILE\Temp")) {
    Write-Host -ForegroundColor Yellow "Temp doesn't exist, creating it..."
    New-Item -ItemType Directory -Path "$env:USERPROFILE\Temp" 
}

Start-Process -FilePath 'c:\windows\sysWow64\explorer.exe' -ArgumentList "$env:USERPROFILE\Temp";
