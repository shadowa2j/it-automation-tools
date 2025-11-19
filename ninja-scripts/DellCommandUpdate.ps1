<#
  .SYNOPSIS
    Installs Dell updates via Dell Command Update
  .DESCRIPTION
    Installs the latest version of Dell Command Update and applies all Dell updates silently.
    Modified for improved reliability in NinjaRMM environments with enhanced error handling.
  .LINK
    https://www.dell.com/support/product-details/en-us/product/command-update/resources/manuals
    https://github.com/ShadowA2J/it-automation-tools
  .NOTES
    Original Author: Aaron J. Stevenson
    Modified by: Bryan (Quality Computer Solutions)
    Modifications: Enhanced error handling, NinjaRMM compatibility, handles file locking issues
    Version: 1.4.0
#>

function Write-Log {
  param([string]$Message, [string]$Level = 'INFO')
  $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
  $LogMessage = "[$Timestamp] [$Level] $Message"
  Write-Output $LogMessage
  
  try {
    if (-not [System.Diagnostics.EventLog]::SourceExists('DellCommandUpdate')) {
      New-EventLog -LogName Application -Source 'DellCommandUpdate' -ErrorAction SilentlyContinue
    }
    $EventType = switch ($Level) {
      'ERROR' { 'Error' }
      'WARNING' { 'Warning' }
      default { 'Information' }
    }
    Write-EventLog -LogName Application -Source 'DellCommandUpdate' -EntryType $EventType -EventId 1000 -Message $Message -ErrorAction SilentlyContinue
  }
  catch { }
}

function Get-Architecture {
  if ($null -ne $ENV:PROCESSOR_ARCHITEW6432) { $Architecture = $ENV:PROCESSOR_ARCHITEW6432 }
  else {     
    if ((Get-CimInstance -ClassName CIM_OperatingSystem -ErrorAction Ignore).OSArchitecture -like 'ARM*') {
      if ( [Environment]::Is64BitOperatingSystem ) { $Architecture = 'arm64' }  
      else { $Architecture = 'arm' }
    }
    if ($null -eq $Architecture) { $Architecture = $ENV:PROCESSOR_ARCHITECTURE }
  }
  switch ($Architecture.ToLowerInvariant()) {
    { ($_ -eq 'amd64') -or ($_ -eq 'x64') } { return 'x64' }
    { $_ -eq 'x86' } { return 'x86' }
    { $_ -eq 'arm' } { return 'arm' }
    { $_ -eq 'arm64' } { return 'arm64' }
    default { throw "Architecture '$Architecture' not supported." }
  }
}

function Get-InstalledApps {
  param(
    [Parameter(Mandatory)][String[]]$DisplayNames,
    [String[]]$Exclude
  )
  
  $RegPaths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
  )
  
  $BroadMatch = @()
  foreach ($DisplayName in $DisplayNames) {
    $AppsWithBundledVersion = Get-ChildItem -Path $RegPaths -ErrorAction SilentlyContinue | Get-ItemProperty | Where-Object { $_.DisplayName -like "*$DisplayName*" -and $null -ne $_.BundleVersion }
    if ($AppsWithBundledVersion) { $BroadMatch += $AppsWithBundledVersion }
    else { $BroadMatch += Get-ChildItem -Path $RegPaths -ErrorAction SilentlyContinue | Get-ItemProperty | Where-Object { $_.DisplayName -like "*$DisplayName*" } }
  }
  
  $MatchedApps = @()
  foreach ($App in $BroadMatch) {
    if ($Exclude -notcontains $App.DisplayName) { $MatchedApps += $App }
  }
  return $MatchedApps | Sort-Object { [version]$_.BundleVersion } -Descending
}

function Test-DotNetVersion {
  $HasDotNet8 = $false
  $DesktopAppPath = "${env:ProgramFiles}\dotnet\shared\Microsoft.WindowsDesktop.App"
  if (Test-Path $DesktopAppPath) {
    $DotNet8Folders = Get-ChildItem -Path $DesktopAppPath -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '8.*' }
    if ($DotNet8Folders) {
      Write-Log "Found .NET Desktop Runtime 8.x: $($DotNet8Folders[0].Name)"
      return $true
    }
  }
  return $false
}

function Stop-DellServices {
  Write-Log "Stopping Dell services that may interfere..."
  $DellServices = @(
    'DellClientManagementService',
    'Dell SupportAssist Agent',
    'DellUpdate',
    'Dell Hardware Support'
  )
  
  foreach ($ServiceName in $DellServices) {
    $Service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($Service -and $Service.Status -eq 'Running') {
      try {
        Write-Log "Stopping service: $ServiceName"
        Stop-Service -Name $ServiceName -Force -ErrorAction Stop
        Start-Sleep -Seconds 2
        Write-Log "Stopped: $ServiceName"
      }
      catch {
        Write-Log "Could not stop $ServiceName : $($_.Exception.Message)" -Level 'WARNING'
      }
    }
  }
}

function Clear-DellTempFiles {
  Write-Log "Clearing Dell temporary installation files..."
  $TempPaths = @(
    "$env:TEMP\Dell*",
    "$env:SystemRoot\TEMP\Dell*",
    "$env:ProgramData\Dell\UpdateService\*"
  )
  
  foreach ($Path in $TempPaths) {
    if (Test-Path $Path) {
      try {
        Remove-Item -Path $Path -Recurse -Force -ErrorAction Stop
        Write-Log "Cleaned: $Path"
      }
      catch {
        Write-Log "Could not clean $Path : $($_.Exception.Message)" -Level 'WARNING'
      }
    }
  }
}

function Remove-IncompatibleApps {
  $IncompatibleApps = Get-InstalledApps -DisplayNames 'Dell Update', 'Dell Command | Update' `
    -Exclude 'Dell SupportAssist OS Recovery Plugin for Dell Update', 'Dell Command | Update for Windows Universal', 'Dell Command | Update for Windows 10', 'Dell Command | Update'
  
  if ($IncompatibleApps) { Write-Log 'Incompatible applications detected' }
  foreach ($App in $IncompatibleApps) {
    Write-Log "Removing: $($App.DisplayName)"
    try {
      if ($App.UninstallString -match 'msiexec') {
        $Guid = [regex]::Match($App.UninstallString, '\{[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}\}').Value
        Start-Process -NoNewWindow -Wait -FilePath 'msiexec.exe' -ArgumentList "/x $Guid /quiet /qn"
      }
      else { Start-Process -NoNewWindow -Wait -FilePath $App.UninstallString -ArgumentList '/quiet' }
      Write-Log "Removed: $($App.DisplayName)"
    }
    catch { 
      Write-Log "Failed to remove $($App.DisplayName): $($_.Exception.Message)" -Level 'ERROR'
      exit 1
    }
  }
}

function Install-DotNetDesktopRuntime {
  Write-Log "Checking for .NET 8 Desktop Runtime..."
  
  if (Test-DotNetVersion) {
    Write-Log ".NET 8 Desktop Runtime is installed"
    return
  }
  
  Write-Log ".NET 8 Desktop Runtime not found - installing..."
  
  try {
    $Arch = Get-Architecture
    $DotNetUrl = "https://download.visualstudio.microsoft.com/download/pr/d6cd4de9-bb6f-4056-bc6c-4ba4c4c11c85/bd2db1af3db61b0e6a0302db21ff3a44/windowsdesktop-runtime-8.0.11-win-$Arch.exe"
    $DotNetInstaller = Join-Path -Path $env:TEMP -ChildPath "windowsdesktop-runtime-8.0.11-win-$Arch.exe"
    
    Write-Log "Downloading .NET 8..."
    Invoke-WebRequest -Uri $DotNetUrl -OutFile $DotNetInstaller -TimeoutSec 300 -ErrorAction Stop
    
    Write-Log "Installing .NET 8..."
    $InstallProcess = Start-Process -Wait -NoNewWindow -FilePath $DotNetInstaller -ArgumentList '/install /quiet /norestart' -PassThru
    
    if ($InstallProcess.ExitCode -eq 0 -or $InstallProcess.ExitCode -eq 3010 -or $InstallProcess.ExitCode -eq 1638) {
      Write-Log ".NET 8 installed (exit code: $($InstallProcess.ExitCode))"
      Start-Sleep -Seconds 5
    }
    else {
      throw ".NET installation failed with exit code: $($InstallProcess.ExitCode)"
    }
    
    Remove-Item $DotNetInstaller -Force -ErrorAction SilentlyContinue
  }
  catch {
    Write-Log "Failed to install .NET 8: $($_.Exception.Message)" -Level 'ERROR'
    throw
  }
}

function Install-DellCommandUpdate {
  $OSInfo = Get-CimInstance -ClassName Win32_OperatingSystem
  $OSBuild = [System.Environment]::OSVersion.Version.Build
  
  Write-Log "OS: $($OSInfo.Caption) (Build $OSBuild)"
  Write-Log "Architecture: $(Get-Architecture)"
  
  $DownloadURL = 'https://dl.dell.com/FOLDER13309509M/1/Dell-Command-Update-Application_PPWHH_WIN64_5.5.0_A00.EXE'
  $Version = '5.5.0'
  
  # Use unique filename to avoid conflicts
  $UniqueID = (Get-Date -Format 'yyyyMMddHHmmss')
  $Installer = Join-Path -Path $env:TEMP -ChildPath "DCU_${UniqueID}.exe"
  
  $InstalledApp = Get-InstalledApps -DisplayName 'Dell Command | Update'
  $CurrentVersion = $InstalledApp.DisplayVersion
  if ($CurrentVersion -is [array]) { $CurrentVersion = $CurrentVersion[0] }
  
  Write-Log "Installed: $CurrentVersion | Target: $Version"

  $NeedsInstall = [string]::IsNullOrEmpty($CurrentVersion) -or ([version]$CurrentVersion -lt [version]$Version)

  if ($NeedsInstall) {
    try {
      # Stop Dell services that might interfere
      Stop-DellServices
      
      # Clean temporary files
      Clear-DellTempFiles
      
      Write-Log "Downloading Dell Command Update..."
      $UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
      Invoke-WebRequest -Uri $DownloadURL -OutFile $Installer -UserAgent $UserAgent -TimeoutSec 300 -ErrorAction Stop

      if (-not (Test-Path $Installer)) {
        throw "Download failed"
      }
      
      $FileSize = (Get-Item $Installer).Length / 1MB
      Write-Log "Downloaded: $([math]::Round($FileSize, 2)) MB"

      Write-Log "Installing Dell Command Update..."
      $LogFile = Join-Path -Path $env:TEMP -ChildPath "DCU_Install_${UniqueID}.log"
      $InstallArgs = "/s /l=`"$LogFile`""
      
      # Extract to specific directory to avoid file locking issues
      $ExtractPath = Join-Path -Path $env:TEMP -ChildPath "DCU_Extract_${UniqueID}"
      New-Item -Path $ExtractPath -ItemType Directory -Force | Out-Null
      
      Write-Log "Installing from: $Installer"
      $InstallProcess = Start-Process -Wait -NoNewWindow -FilePath $Installer -ArgumentList $InstallArgs -PassThru
      
      Write-Log "Installer exit code: $($InstallProcess.ExitCode)"
      
      if (Test-Path $LogFile) {
        $LogContent = Get-Content $LogFile -ErrorAction SilentlyContinue
        $ErrorLines = $LogContent | Select-String -Pattern 'error|failure|1602' -Context 0,2
        if ($ErrorLines) {
          Write-Log "Installer errors found:"
          $ErrorLines | ForEach-Object { Write-Log $_.Line }
        }
      }
      
      if ($InstallProcess.ExitCode -eq 0 -or $InstallProcess.ExitCode -eq 1) {
        Write-Log "Installation completed (exit code: $($InstallProcess.ExitCode))"
      }
      elseif ($InstallProcess.ExitCode -eq 4) {
        # Check the actual error in the log
        if (Test-Path $LogFile) {
          $LogContent = Get-Content $LogFile -Raw
          if ($LogContent -match '1602') {
            throw "Installation cancelled or blocked by another process. Please close Dell applications and retry."
          }
          if ($LogContent -match 'being used by another process') {
            throw "File locking issue detected. Please reboot the system and retry."
          }
        }
        throw "Installation prerequisites not met (exit code 4)"
      }
      else {
        throw "Installation failed with exit code: $($InstallProcess.ExitCode)"
      }

      Start-Sleep -Seconds 15

      $InstalledApp = Get-InstalledApps -DisplayName 'Dell Command | Update'
      $NewVersion = $InstalledApp.DisplayVersion
      if ($NewVersion -is [array]) { $NewVersion = $NewVersion[0] }
      
      if ([string]::IsNullOrEmpty($NewVersion)) {
        throw "DCU not detected after installation"
      }
      
      Write-Log "Successfully installed DCU v$NewVersion"
      
      # Cleanup
      Remove-Item $Installer -Force -ErrorAction SilentlyContinue
      Remove-Item $ExtractPath -Recurse -Force -ErrorAction SilentlyContinue
    }
    catch {
      Write-Log "Installation failed: $($_.Exception.Message)" -Level 'ERROR'
      Remove-Item $Installer -Force -ErrorAction SilentlyContinue
      exit 1
    }
  }
  else { 
    Write-Log "DCU installation not needed"
  }
}

function Invoke-DellCommandUpdate {
  $DCUPaths = @(
    "$env:ProgramFiles\Dell\CommandUpdate\dcu-cli.exe",
    "${env:ProgramFiles(x86)}\Dell\CommandUpdate\dcu-cli.exe"
  )
  
  $DCU = $DCUPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
  
  if (-not $DCU) {
    Write-Log 'DCU CLI not found' -Level 'ERROR'
    exit 1
  }
  
  Write-Log "DCU CLI: $DCU"
  
  try {
    Write-Log 'Configuring DCU...'
    $ConfigProcess = Start-Process -NoNewWindow -Wait -FilePath $DCU -ArgumentList '/configure -scheduleAction=DownloadInstallAndNotify -updatesNotification=disable -forceRestart=disable -scheduleAuto -silent' -PassThru
    Write-Log "Config: $($ConfigProcess.ExitCode)"
    
    Write-Log 'Scanning for updates...'
    $ScanProcess = Start-Process -NoNewWindow -Wait -FilePath $DCU -ArgumentList '/scan -silent' -PassThru
    Write-Log "Scan: $($ScanProcess.ExitCode)"
    
    Write-Log 'Applying updates...'
    $UpdateProcess = Start-Process -NoNewWindow -Wait -FilePath $DCU -ArgumentList '/applyUpdates -autoSuspendBitLocker=enable -reboot=disable' -PassThru
    Write-Log "Apply: $($UpdateProcess.ExitCode)"
    
    if ($UpdateProcess.ExitCode -eq 0 -or $UpdateProcess.ExitCode -eq 500) {
      Write-Log 'Updates completed successfully'
    }
    elseif ($UpdateProcess.ExitCode -eq 1) {
      Write-Log 'Updates applied - reboot required' -Level 'WARNING'
    }
  }
  catch {
    Write-Log "Update error: $($_.Exception.Message)" -Level 'ERROR'
    exit 1
  }
}

# Main execution
Set-Location -Path $env:SystemRoot
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'

if ([Net.ServicePointManager]::SecurityProtocol -notcontains 'Tls12' -and [Net.ServicePointManager]::SecurityProtocol -notcontains 'Tls13') {
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}

Write-Log "===== Dell Command Update Script v1.4.0 ====="
Write-Log "User: $env:USERNAME | Computer: $env:COMPUTERNAME"

$Manufacturer = (Get-CimInstance -ClassName Win32_BIOS).Manufacturer
if ($Manufacturer -notlike '*Dell*') {
  Write-Log "Not a Dell system - exiting"
  exit 0
}

try {
  Remove-IncompatibleApps
  Install-DotNetDesktopRuntime
  Install-DellCommandUpdate
  Invoke-DellCommandUpdate
  Write-Log "===== Script Completed Successfully ====="
}
catch {
  Write-Log "===== Script Failed =====" -Level 'ERROR'
  Write-Log $_.Exception.Message -Level 'ERROR'
  exit 1
}
