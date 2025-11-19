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
    Modifications: Enhanced error handling, NinjaRMM compatibility, OS-specific installer selection
    Version: 1.2.0
#>

function Write-Log {
  param([string]$Message, [string]$Level = 'INFO')
  $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
  $LogMessage = "[$Timestamp] [$Level] $Message"
  Write-Output $LogMessage
  
  # Also write to event log for NinjaRMM capture
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
    # Silently continue if event log fails
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

function Install-DellCommandUpdate {
  function Get-LatestDellCommandUpdate {
    # Detect OS version
    $OSInfo = Get-CimInstance -ClassName Win32_OperatingSystem
    $OSVersion = [System.Environment]::OSVersion.Version
    $OSBuild = $OSVersion.Build
    
    # Determine if Windows 10 or Windows 11
    # Windows 11 starts at build 22000
    $IsWindows11 = $OSBuild -ge 22000
    $IsWindows10 = $OSVersion.Major -eq 10 -and $OSBuild -lt 22000
    
    Write-Log "OS: $($OSInfo.Caption) (Build $OSBuild)"
    Write-Log "Architecture: $(Get-Architecture)"
    
    $Arch = Get-Architecture
    
    # Use current working URLs from Chocolatey package
    # Source: https://community.chocolatey.org/packages/dellcommandupdate
    if ($Arch -like 'arm*') { 
      # ARM64 - Universal Application
      $DownloadURL = 'https://dl.dell.com/FOLDER13309588M/3/Dell-Command-Update-Windows-Universal-Application_C8JXV_WIN64_5.5.0_A00_02.EXE'
      $MD5 = 'skip'
      $Version = '5.5.0'
      Write-Log "Selected ARM64 Universal Application installer"
    }
    elseif ($IsWindows10) {
      # Windows 10 - Standard Application (not Universal)
      $DownloadURL = 'https://dl.dell.com/FOLDER13309509M/1/Dell-Command-Update-Application_PPWHH_WIN64_5.5.0_A00.EXE'
      $MD5 = 'skip'
      $Version = '5.5.0'
      Write-Log "Selected Windows 10 Application installer (non-Universal)"
    }
    else { 
      # Windows 11 - Standard Application works better than Universal
      $DownloadURL = 'https://dl.dell.com/FOLDER13309509M/1/Dell-Command-Update-Application_PPWHH_WIN64_5.5.0_A00.EXE'
      $MD5 = 'skip'
      $Version = '5.5.0'
      Write-Log "Selected Windows 11 Application installer"
    }
  
    return @{
      MD5     = $MD5.ToUpper()
      URL     = $DownloadURL
      Version = $Version
    }
  }
  
  $LatestDellCommandUpdate = Get-LatestDellCommandUpdate
  $Installer = Join-Path -Path $env:TEMP -ChildPath (Split-Path $LatestDellCommandUpdate.URL -Leaf)
  
  # Check for existing installation
  $InstalledApp = Get-InstalledApps -DisplayName 'Dell Command | Update'
  $CurrentVersion = $InstalledApp.DisplayVersion
  
  if ($CurrentVersion -is [array]) { $CurrentVersion = $CurrentVersion[0] }
  
  Write-Log "Installed Dell Command Update: $CurrentVersion"
  Write-Log "Target Dell Command Update: $($LatestDellCommandUpdate.Version)"

  # Compare versions
  $NeedsInstall = $false
  if ([string]::IsNullOrEmpty($CurrentVersion)) {
    $NeedsInstall = $true
    Write-Log "No existing installation detected"
  }
  elseif ([version]$CurrentVersion -lt [version]$LatestDellCommandUpdate.Version) {
    $NeedsInstall = $true
    Write-Log "Upgrade needed"
  }

  if ($NeedsInstall) {
    try {
      # Download installer
      Write-Log "Dell Command Update installation needed"
      Write-Log "Downloading from: $($LatestDellCommandUpdate.URL)"
      
      # Use custom user agent like Chocolatey does (Dell checks user agents)
      $UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3'
      Invoke-WebRequest -Uri $LatestDellCommandUpdate.URL -OutFile $Installer -UserAgent $UserAgent -TimeoutSec 300 -ErrorAction Stop

      # Verify file was downloaded
      if (-not (Test-Path $Installer)) {
        throw "Installer file was not downloaded successfully"
      }
      
      $FileSize = (Get-Item $Installer).Length / 1MB
      Write-Log "Downloaded installer: $([math]::Round($FileSize, 2)) MB"

      # Verify MD5 checksum (skip if marked to skip)
      if ($LatestDellCommandUpdate.MD5 -ne 'SKIP') {
        Write-Log 'Verifying MD5 checksum...'
        $InstallerMD5 = (Get-FileHash -Path $Installer -Algorithm MD5).Hash
        if ($InstallerMD5 -ne $LatestDellCommandUpdate.MD5) {
          throw "MD5 verification failed. Expected: $($LatestDellCommandUpdate.MD5), Got: $InstallerMD5"
        }
        Write-Log 'MD5 verification successful'
      }
      else {
        Write-Log 'Skipping MD5 verification for this installer'
      }

      # Install Dell Command Update
      Write-Log 'Installing Dell Command Update...'
      Write-Log "Installer path: $Installer"
      
      # Try silent install
      $InstallProcess = Start-Process -Wait -NoNewWindow -FilePath $Installer -ArgumentList '/s' -PassThru
      
      Write-Log "Installer exit code: $($InstallProcess.ExitCode)"
      
      # Handle exit codes
      switch ($InstallProcess.ExitCode) {
        0 { Write-Log "Installation completed successfully" }
        1 { Write-Log "Installation completed with reboot required" -Level 'WARNING' }
        2 { Write-Log "Installation failed - invalid command line parameters" -Level 'ERROR'; throw "Invalid installer parameters" }
        3 { Write-Log "Installation failed - insufficient privileges" -Level 'ERROR'; throw "Insufficient privileges" }
        4 { 
          Write-Log "Installation failed - unsupported OS or missing prerequisites (exit code 4)" -Level 'ERROR'
          Write-Log "OS Build: $([System.Environment]::OSVersion.Version.Build)" -Level 'ERROR'
          Write-Log "This may require .NET 8 Desktop Runtime" -Level 'ERROR'
          throw "Unsupported OS or missing prerequisites"
        }
        default { 
          if ($InstallProcess.ExitCode -ne 0) {
            throw "Installation failed with exit code: $($InstallProcess.ExitCode)"
          }
        }
      }

      # Wait for installation to complete
      Start-Sleep -Seconds 10

      # Confirm installation
      $InstalledApp = Get-InstalledApps -DisplayName 'Dell Command | Update'
      $NewVersion = $InstalledApp.DisplayVersion
      if ($NewVersion -is [array]) { $NewVersion = $NewVersion[0] }
      
      if ([string]::IsNullOrEmpty($NewVersion)) {
        throw "Dell Command Update not detected after installation attempt"
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
    Write-Log "Dell Command Update installation / upgrade not needed"
  }
}

function Install-DotNetDesktopRuntime {
  # Check if .NET 8 Desktop Runtime is installed (required for DCU 5.5+)
  $InstalledApp = Get-InstalledApps -DisplayName 'Microsoft Windows Desktop Runtime'
  $CurrentVersion = $InstalledApp.BundleVersion
  if ($CurrentVersion -is [array]) { $CurrentVersion = $CurrentVersion[0] }
  
  Write-Log "Installed .NET Desktop Runtime: $CurrentVersion"
  
  # Check if we have .NET 8 or higher
  $HasDotNet8 = $false
  if (-not [string]::IsNullOrEmpty($CurrentVersion)) {
    try {
      $VersionObj = [version]$CurrentVersion
      if ($VersionObj.Major -ge 8) {
        $HasDotNet8 = $true
        Write-Log ".NET 8+ Desktop Runtime is installed"
      }
    }
    catch {
      Write-Log "Could not parse .NET version" -Level 'WARNING'
    }
  }
  
  if (-not $HasDotNet8) {
    Write-Log ".NET 8 Desktop Runtime not found - DCU 5.5 requires this" -Level 'WARNING'
    Write-Log "Attempting to install .NET 8 Desktop Runtime..." -Level 'WARNING'
    
    try {
      $Arch = Get-Architecture
      $DotNetUrl = "https://download.visualstudio.microsoft.com/download/pr/d6cd4de9-bb6f-4056-bc6c-4ba4c4c11c85/bd2db1af3db61b0e6a0302db21ff3a44/windowsdesktop-runtime-8.0.11-win-$Arch.exe"
      $DotNetInstaller = Join-Path -Path $env:TEMP -ChildPath "windowsdesktop-runtime-8.0.11-win-$Arch.exe"
      
      Write-Log "Downloading .NET 8 Desktop Runtime..."
      Invoke-WebRequest -Uri $DotNetUrl -OutFile $DotNetInstaller -TimeoutSec 300 -ErrorAction Stop
      
      Write-Log "Installing .NET 8 Desktop Runtime..."
      $InstallProcess = Start-Process -Wait -NoNewWindow -FilePath $DotNetInstaller -ArgumentList '/install /quiet /norestart' -PassThru
      
      if ($InstallProcess.ExitCode -eq 0 -or $InstallProcess.ExitCode -eq 3010) {
        Write-Log ".NET 8 Desktop Runtime installed successfully"
        Remove-Item $DotNetInstaller -Force -ErrorAction SilentlyContinue
      }
      else {
        throw ".NET installation failed with exit code: $($InstallProcess.ExitCode)"
      }
    }
    catch {
      Write-Log "Failed to install .NET 8 Desktop Runtime: $($_.Exception.Message)" -Level 'WARNING'
      Write-Log "DCU installation may fail without .NET 8" -Level 'WARNING'
    }
  }
}

function Invoke-DellCommandUpdate {
  # Check for DCU CLI
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
    Write-Log 'Dell Command Update CLI was not detected.' -Level 'ERROR'
    exit 1
  }
  
  Write-Log "Found DCU CLI at: $DCU"
  
  try {
    # Configure DCU automatic updates
    Write-Log 'Configuring DCU settings...'
    $ConfigProcess = Start-Process -NoNewWindow -Wait -FilePath $DCU -ArgumentList '/configure -scheduleAction=DownloadInstallAndNotify -updatesNotification=disable -forceRestart=disable -scheduleAuto -silent' -PassThru
    Write-Log "Configuration exit code: $($ConfigProcess.ExitCode)"
    
    # Scan for updates
    Write-Log 'Scanning for Dell updates...'
    $ScanProcess = Start-Process -NoNewWindow -Wait -FilePath $DCU -ArgumentList '/scan -silent' -PassThru
    Write-Log "Scan exit code: $($ScanProcess.ExitCode)"
    
    # Apply updates
    Write-Log 'Applying Dell updates...'
    $UpdateProcess = Start-Process -NoNewWindow -Wait -FilePath $DCU -ArgumentList '/applyUpdates -autoSuspendBitLocker=enable -reboot=disable' -PassThru
    
    Write-Log "Apply updates exit code: $($UpdateProcess.ExitCode)"
    
    # Exit codes: 0 = success, 500 = no updates, 1 = reboot required
    if ($UpdateProcess.ExitCode -eq 0 -or $UpdateProcess.ExitCode -eq 500) {
      Write-Log 'Dell updates completed successfully'
    }
    elseif ($UpdateProcess.ExitCode -eq 1) {
      Write-Log 'Dell updates applied - reboot required' -Level 'WARNING'
    }
    else {
      Write-Log "DCU returned exit code: $($UpdateProcess.ExitCode)" -Level 'WARNING'
    }
  }
  catch {
    Write-Log "Unable to apply updates using dcu-cli: $($_.Exception.Message)" -Level 'ERROR'
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

Write-Log "===== Dell Command Update Script Started ====="
Write-Log "Running as: $env:USERNAME"
Write-Log "Computer: $env:COMPUTERNAME"

# Check device manufacturer
$Manufacturer = (Get-CimInstance -ClassName Win32_BIOS).Manufacturer
Write-Log "Detected manufacturer: $Manufacturer"

if ($Manufacturer -notlike '*Dell*') {
  Write-Log "Not a Dell system. Aborting..."
  exit 0
}

try {
  Remove-IncompatibleApps
  Install-DotNetDesktopRuntime
  Install-DellCommandUpdate
  Invoke-DellCommandUpdate
  
  Write-Log "===== Dell Command Update Script Completed Successfully ====="
}
catch {
  Write-Log "===== Dell Command Update Script Failed =====" -Level 'ERROR'
  Write-Log $_.Exception.Message -Level 'ERROR'
  exit 1
}
