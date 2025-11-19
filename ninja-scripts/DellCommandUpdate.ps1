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
    Modifications: Enhanced error handling, NinjaRMM compatibility, proper .NET 8 detection
    Version: 1.3.0
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
  catch {
  }
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
  
  # Method 1: Check for WindowsDesktop.App folder
  $DesktopAppPath = "${env:ProgramFiles}\dotnet\shared\Microsoft.WindowsDesktop.App"
  if (Test-Path $DesktopAppPath) {
    $DotNet8Folders = Get-ChildItem -Path $DesktopAppPath -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '8.*' }
    if ($DotNet8Folders) {
      Write-Log "Found .NET Desktop Runtime 8.x folder: $($DotNet8Folders[0].Name)"
      $HasDotNet8 = $true
      return $HasDotNet8
    }
  }
  
  # Method 2: Try dotnet --list-runtimes command
  try {
    $DotNetPath = "${env:ProgramFiles}\dotnet\dotnet.exe"
    if (Test-Path $DotNetPath) {
      $Runtimes = & $DotNetPath --list-runtimes 2>&1 | Out-String
      if ($Runtimes -match 'Microsoft\.WindowsDesktop\.App 8\.') {
        Write-Log "Found .NET Desktop Runtime 8.x via dotnet CLI"
        $HasDotNet8 = $true
        return $HasDotNet8
      }
    }
  }
  catch {
    Write-Log "Could not check dotnet CLI: $($_.Exception.Message)" -Level 'WARNING'
  }
  
  # Method 3: Check registry
  $DotNetKeys = @(
    'HKLM:\SOFTWARE\dotnet\Setup\InstalledVersions\x64\sharedhost',
    'HKLM:\SOFTWARE\WOW6432Node\dotnet\Setup\InstalledVersions\x64\sharedhost'
  )
  
  foreach ($Key in $DotNetKeys) {
    if (Test-Path $Key) {
      $Version = (Get-ItemProperty -Path $Key -Name 'Version' -ErrorAction SilentlyContinue).Version
      if ($Version -and $Version -like '8.*') {
        Write-Log "Found .NET shared host version: $Version"
        $HasDotNet8 = $true
        return $HasDotNet8
      }
    }
  }
  
  return $HasDotNet8
}

function Remove-IncompatibleApps {
  $IncompatibleApps = Get-InstalledApps -DisplayNames 'Dell Update', 'Dell Command | Update' `
    -Exclude 'Dell SupportAssist OS Recovery Plugin for Dell Update', 'Dell Command | Update for Windows Universal', 'Dell Command | Update for Windows 10', 'Dell Command | Update'
  
  if ($IncompatibleApps) { Write-Log 'Incompatible applications detected' }
  foreach ($App in $IncompatibleApps) {
    Write-Log "Attempting to remove [$($App.DisplayName)]"
    try {
      if ($App.UninstallString -match 'msiexec') {
        $Guid = [regex]::Match($App.UninstallString, '\{[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}\}').Value
        Start-Process -NoNewWindow -Wait -FilePath 'msiexec.exe' -ArgumentList "/x $Guid /quiet /qn"
      }
      else { Start-Process -NoNewWindow -Wait -FilePath $App.UninstallString -ArgumentList '/quiet' }
      Write-Log "Successfully removed $($App.DisplayName)"
    }
    catch { 
      Write-Log "Failed to remove $($App.DisplayName)" -Level 'ERROR'
      Write-Log $_.Exception.Message -Level 'ERROR'
      exit 1
    }
  }
}

function Install-DotNetDesktopRuntime {
  Write-Log "Checking for .NET 8 Desktop Runtime..."
  
  $HasDotNet8 = Test-DotNetVersion
  
  if ($HasDotNet8) {
    Write-Log ".NET 8 Desktop Runtime is already installed"
    return
  }
  
  Write-Log ".NET 8 Desktop Runtime not found - installing..." -Level 'WARNING'
  
  try {
    $Arch = Get-Architecture
    $DotNetUrl = "https://download.visualstudio.microsoft.com/download/pr/d6cd4de9-bb6f-4056-bc6c-4ba4c4c11c85/bd2db1af3db61b0e6a0302db21ff3a44/windowsdesktop-runtime-8.0.11-win-$Arch.exe"
    $DotNetInstaller = Join-Path -Path $env:TEMP -ChildPath "windowsdesktop-runtime-8.0.11-win-$Arch.exe"
    
    Write-Log "Downloading .NET 8 Desktop Runtime..."
    Invoke-WebRequest -Uri $DotNetUrl -OutFile $DotNetInstaller -TimeoutSec 300 -ErrorAction Stop
    
    if (-not (Test-Path $DotNetInstaller)) {
      throw ".NET installer download failed"
    }
    
    Write-Log "Installing .NET 8 Desktop Runtime (this may take a minute)..."
    $InstallProcess = Start-Process -Wait -NoNewWindow -FilePath $DotNetInstaller -ArgumentList '/install /quiet /norestart' -PassThru
    
    Write-Log ".NET installer exit code: $($InstallProcess.ExitCode)"
    
    if ($InstallProcess.ExitCode -eq 0) {
      Write-Log ".NET 8 Desktop Runtime installed successfully"
    }
    elseif ($InstallProcess.ExitCode -eq 3010) {
      Write-Log ".NET 8 Desktop Runtime installed (reboot recommended)"
    }
    elseif ($InstallProcess.ExitCode -eq 1638) {
      Write-Log ".NET 8 Desktop Runtime already installed (exit code 1638)"
    }
    else {
      throw ".NET installation failed with exit code: $($InstallProcess.ExitCode)"
    }
    
    Remove-Item $DotNetInstaller -Force -ErrorAction SilentlyContinue
    
    # Wait for installation to finalize
    Start-Sleep -Seconds 5
    
    # Verify installation
    if (Test-DotNetVersion) {
      Write-Log ".NET 8 Desktop Runtime verified after installation"
    }
    else {
      Write-Log ".NET 8 Desktop Runtime verification failed after installation" -Level 'WARNING'
    }
  }
  catch {
    Write-Log "Failed to install .NET 8 Desktop Runtime: $($_.Exception.Message)" -Level 'ERROR'
    throw "DCU installation will fail without .NET 8 Desktop Runtime"
  }
}

function Install-DellCommandUpdate {
  $OSInfo = Get-CimInstance -ClassName Win32_OperatingSystem
  $OSVersion = [System.Environment]::OSVersion.Version
  $OSBuild = $OSVersion.Build
  
  Write-Log "OS: $($OSInfo.Caption) (Build $OSBuild)"
  Write-Log "Architecture: $(Get-Architecture)"
  
  $DownloadURL = 'https://dl.dell.com/FOLDER13309509M/1/Dell-Command-Update-Application_PPWHH_WIN64_5.5.0_A00.EXE'
  $Version = '5.5.0'
  
  $Installer = Join-Path -Path $env:TEMP -ChildPath 'Dell-Command-Update-Application_PPWHH_WIN64_5.5.0_A00.EXE'
  
  $InstalledApp = Get-InstalledApps -DisplayName 'Dell Command | Update'
  $CurrentVersion = $InstalledApp.DisplayVersion
  if ($CurrentVersion -is [array]) { $CurrentVersion = $CurrentVersion[0] }
  
  Write-Log "Installed Dell Command Update: $CurrentVersion"
  Write-Log "Target Dell Command Update: $Version"

  $NeedsInstall = $false
  if ([string]::IsNullOrEmpty($CurrentVersion)) {
    $NeedsInstall = $true
    Write-Log "No existing installation detected"
  }
  elseif ([version]$CurrentVersion -lt [version]$Version) {
    $NeedsInstall = $true
    Write-Log "Upgrade needed"
  }

  if ($NeedsInstall) {
    try {
      Write-Log "Downloading Dell Command Update..."
      $UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
      Invoke-WebRequest -Uri $DownloadURL -OutFile $Installer -UserAgent $UserAgent -TimeoutSec 300 -ErrorAction Stop

      if (-not (Test-Path $Installer)) {
        throw "Installer download failed"
      }
      
      $FileSize = (Get-Item $Installer).Length / 1MB
      Write-Log "Downloaded: $([math]::Round($FileSize, 2)) MB"

      Write-Log 'Installing Dell Command Update...'
      $LogFile = Join-Path -Path $env:TEMP -ChildPath "DCU_Install_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
      $InstallArgs = "/s /l=`"$LogFile`""
      
      $InstallProcess = Start-Process -Wait -NoNewWindow -FilePath $Installer -ArgumentList $InstallArgs -PassThru
      Write-Log "Installer exit code: $($InstallProcess.ExitCode)"
      
      if (Test-Path $LogFile) {
        $LogTail = Get-Content $LogFile -Tail 10 -ErrorAction SilentlyContinue
        if ($LogTail) {
          Write-Log "Installer log (last 10 lines):"
          $LogTail | ForEach-Object { Write-Log $_ }
        }
      }
      
      switch ($InstallProcess.ExitCode) {
        0 { Write-Log "Installation completed successfully" }
        1 { Write-Log "Installation completed (reboot required)" -Level 'WARNING' }
        4 { 
          Write-Log "Installation failed - exit code 4 (prerequisites not met)" -Level 'ERROR'
          if (-not (Test-DotNetVersion)) {
            throw ".NET 8 Desktop Runtime is required but not detected"
          }
          throw "Installation prerequisites check failed"
        }
        default { 
          if ($InstallProcess.ExitCode -ne 0) {
            throw "Installation failed with exit code: $($InstallProcess.ExitCode)"
          }
        }
      }

      Start-Sleep -Seconds 10

      $InstalledApp = Get-InstalledApps -DisplayName 'Dell Command | Update'
      $NewVersion = $InstalledApp.DisplayVersion
      if ($NewVersion -is [array]) { $NewVersion = $NewVersion[0] }
      
      if ([string]::IsNullOrEmpty($NewVersion)) {
        throw "Dell Command Update not detected after installation"
      }
      
      Write-Log "Successfully installed Dell Command Update [$NewVersion]"
      Remove-Item $Installer -Force -ErrorAction SilentlyContinue
    }
    catch {
      Write-Log "Failed to install Dell Command Update: $($_.Exception.Message)" -Level 'ERROR'
      Remove-Item $Installer -Force -ErrorAction SilentlyContinue
      exit 1
    }
  }
  else { 
    Write-Log "Dell Command Update installation not needed"
  }
}

function Invoke-DellCommandUpdate {
  $DCUPaths = @(
    "$env:SystemDrive\Program Files\Dell\CommandUpdate\dcu-cli.exe",
    "$env:SystemDrive\Program Files (x86)\Dell\CommandUpdate\dcu-cli.exe"
  )
  
  $DCU = $null
  foreach ($Path in $DCUPaths) {
    if (Test-Path $Path) {
      $DCU = $Path
      break
    }
  }
  
  if ($null -eq $DCU) {
    Write-Log 'Dell Command Update CLI not found' -Level 'ERROR'
    exit 1
  }
  
  Write-Log "Found DCU CLI at: $DCU"
  
  try {
    Write-Log 'Configuring DCU...'
    $ConfigProcess = Start-Process -NoNewWindow -Wait -FilePath $DCU -ArgumentList '/configure -scheduleAction=DownloadInstallAndNotify -updatesNotification=disable -forceRestart=disable -scheduleAuto -silent' -PassThru
    Write-Log "Configuration exit code: $($ConfigProcess.ExitCode)"
    
    Write-Log 'Scanning for updates...'
    $ScanProcess = Start-Process -NoNewWindow -Wait -FilePath $DCU -ArgumentList '/scan -silent' -PassThru
    Write-Log "Scan exit code: $($ScanProcess.ExitCode)"
    
    Write-Log 'Applying updates...'
    $UpdateProcess = Start-Process -NoNewWindow -Wait -FilePath $DCU -ArgumentList '/applyUpdates -autoSuspendBitLocker=enable -reboot=disable' -PassThru
    Write-Log "Apply updates exit code: $($UpdateProcess.ExitCode)"
    
    if ($UpdateProcess.ExitCode -eq 0 -or $UpdateProcess.ExitCode -eq 500) {
      Write-Log 'Dell updates completed successfully'
    }
    elseif ($UpdateProcess.ExitCode -eq 1) {
      Write-Log 'Dell updates applied - reboot required' -Level 'WARNING'
    }
    else {
      Write-Log "DCU exit code: $($UpdateProcess.ExitCode)" -Level 'WARNING'
    }
  }
  catch {
    Write-Log "Update error: $($_.Exception.Message)" -Level 'ERROR'
    exit 1
  }
}

Set-Location -Path $env:SystemRoot
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'

if ([Net.ServicePointManager]::SecurityProtocol -notcontains 'Tls12' -and [Net.ServicePointManager]::SecurityProtocol -notcontains 'Tls13') {
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}

Write-Log "===== Dell Command Update Script Started ====="
Write-Log "Running as: $env:USERNAME"
Write-Log "Computer: $env:COMPUTERNAME"

$Manufacturer = (Get-CimInstance -ClassName Win32_BIOS).Manufacturer
Write-Log "Manufacturer: $Manufacturer"

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
