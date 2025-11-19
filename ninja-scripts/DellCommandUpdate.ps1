<#
  .SYNOPSIS
    Installs Dell updates via Dell Command Update
  .DESCRIPTION
    Installs the latest version of Dell Command Update and applies all Dell updates silently.
    Modified for improved reliability in NinjaRMM environments with enhanced error handling.
  .LINK
    https://www.dell.com/support/product-details/en-us/product/command-update/resources/manuals
    https://github.com/wise-io/scripts/blob/main/scripts/DellCommandUpdate.ps1
  .NOTES
    Original Author: Aaron J. Stevenson
    Modified by: Bryan (Quality Computer Solutions)
    Modifications: Enhanced error handling, NinjaRMM compatibility, improved version handling
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
  # On PS x86, PROCESSOR_ARCHITECTURE reports x86 even on x64 systems.
  # To get the correct architecture, we need to use PROCESSOR_ARCHITEW6432.
  # PS x64 doesn't define this, so we fall back to PROCESSOR_ARCHITECTURE.
  # Possible values: amd64, x64, x86, arm64, arm
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
  
  # Get applications matching criteria
  $BroadMatch = @()
  foreach ($DisplayName in $DisplayNames) {
    $AppsWithBundledVersion = Get-ChildItem -Path $RegPaths -ErrorAction SilentlyContinue | Get-ItemProperty | Where-Object { $_.DisplayName -like "*$DisplayName*" -and $null -ne $_.BundleVersion }
    if ($AppsWithBundledVersion) { $BroadMatch += $AppsWithBundledVersion }
    else { $BroadMatch += Get-ChildItem -Path $RegPaths -ErrorAction SilentlyContinue | Get-ItemProperty | Where-Object { $_.DisplayName -like "*$DisplayName*" } }
  }
  
  # Remove excluded apps
  $MatchedApps = @()
  foreach ($App in $BroadMatch) {
    if ($Exclude -notcontains $App.DisplayName) { $MatchedApps += $App }
  }

  return $MatchedApps | Sort-Object { [version]$_.BundleVersion } -Descending
}

function Remove-IncompatibleApps {
  # Check for incompatible products
  $IncompatibleApps = Get-InstalledApps -DisplayNames 'Dell Update', 'Dell Command | Update' `
    -Exclude 'Dell SupportAssist OS Recovery Plugin for Dell Update', 'Dell Command | Update for Windows Universal', 'Dell Command | Update for Windows 10'
  
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
    # Set KB URL
    $DellKBURL = 'https://www.dell.com/support/kbdoc/en-us/000177325/dell-command-update'
  
    # Set fallback URL based on architecture
    $Arch = Get-Architecture
    if ($Arch -like 'arm*') { 
      $FallbackDownloadURL = 'https://dl.dell.com/FOLDER11914141M/1/Dell-Command-Update-Windows-Universal-Application_6MK0D_WINARM64_5.4.0_A00.EXE'
      $FallbackMD5 = 'c6ed3bc35d7d6d726821a2c25fbbb44d'
      $FallbackVersion = '5.4.0'
    }
    else { 
      $FallbackDownloadURL = 'https://dl.dell.com/FOLDER12925773M/1/Dell-Command-Update-Windows-Universal-Application_P4DJW_WIN64_5.5.0_A00.EXE'
      $FallbackMD5 = 'a1eb9c7eadb6d9cbfbbe2be13049b299'
      $FallbackVersion = '5.5.0'
    }
  
    # Set headers for Dell website
    $Headers = @{
      'accept'          = 'text/html'
      'accept-encoding' = 'gzip'
      'accept-language' = '*'
    }
  
    # Attempt to parse Dell website for download page links of latest DCU
    try {
      [String]$DellKB = Invoke-WebRequest -UseBasicParsing -Uri $DellKBURL -Headers $Headers -TimeoutSec 30 -ErrorAction Stop
      $LinkMatches = @($DellKB | Select-String '(https://www\.dell\.com.+driverid=[a-z0-9]+).+>Dell Command \| Update Windows Universal Application<\/a>' -AllMatches).Matches
      $KBLinks = foreach ($Match in $LinkMatches) { $Match.Groups[1].Value }
    
      # Attempt to parse Dell website for download URLs for latest DCU
      $DownloadObjects = foreach ($Link in $KBLinks) {
        $DownloadPage = Invoke-WebRequest -UseBasicParsing -Uri $Link -Headers $Headers -TimeoutSec 30 -ErrorAction Stop
        if ($DownloadPage -match '(https://dl\.dell\.com.+Dell-Command-Update.+\.EXE)') { 
          $Url = $Matches[1]
          $MD5 = $null
          if ($DownloadPage -match 'MD5:.*?([a-fA-F0-9]{32})') { $MD5 = $Matches[1] }
          
          # Extract version from URL
          $VersionMatch = $Url | Select-String '[0-9]+\.[0-9]+\.[0-9]+' | ForEach-Object { $_.Matches.Value }
          
          [PSCustomObject]@{
            URL     = $Url
            MD5     = $MD5
            Version = $VersionMatch
          }
        }
      }
    
      # Set download URL / MD5 based on architecture
      if ($Arch -like 'arm*') { $DownloadObject = $DownloadObjects | Where-Object { $_.URL -like '*winarm*' } | Select-Object -First 1 }
      else { $DownloadObject = $DownloadObjects | Where-Object { $_.URL -notlike '*winarm*' } | Select-Object -First 1 }

      # Validate that we got all required information
      if ($null -eq $DownloadObject -or $null -eq $DownloadObject.URL -or $null -eq $DownloadObject.MD5 -or $null -eq $DownloadObject.Version) {
        throw "Failed to parse Dell website for complete download information"
      }

      Write-Log "Successfully retrieved DCU info from Dell website: Version $($DownloadObject.Version)"
      
      return @{
        MD5     = $DownloadObject.MD5.ToUpper()
        URL     = $DownloadObject.URL
        Version = $DownloadObject.Version
      }
    }
    catch {
      Write-Log "Failed to retrieve DCU info from Dell website: $($_.Exception.Message)" -Level 'WARNING'
      Write-Log "Falling back to hardcoded version $FallbackVersion" -Level 'WARNING'
      
      # Return fallback with all required fields
      return @{
        MD5     = $FallbackMD5.ToUpper()
        URL     = $FallbackDownloadURL
        Version = $FallbackVersion
      }
    }
  }
  
  $LatestDellCommandUpdate = Get-LatestDellCommandUpdate
  $Installer = Join-Path -Path $env:TEMP -ChildPath (Split-Path $LatestDellCommandUpdate.URL -Leaf)
  
  $InstalledApp = Get-InstalledApps -DisplayName 'Dell Command | Update for Windows Universal', 'Dell Command | Update for Windows 10'
  $CurrentVersion = $InstalledApp.DisplayVersion
  
  # Handle multiple versions installed
  if ($CurrentVersion -is [array]) { $CurrentVersion = $CurrentVersion[0] }
  
  Write-Log "Installed Dell Command Update: $CurrentVersion"
  Write-Log "Latest Dell Command Update: $($LatestDellCommandUpdate.Version)"

  # Compare versions properly
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
      Invoke-WebRequest -Uri $LatestDellCommandUpdate.URL -OutFile $Installer -UserAgent ([Microsoft.PowerShell.Commands.PSUserAgent]::Chrome) -TimeoutSec 300 -ErrorAction Stop

      # Verify MD5 checksum
      Write-Log 'Verifying MD5 checksum...'
      $InstallerMD5 = (Get-FileHash -Path $Installer -Algorithm MD5).Hash
      if ($InstallerMD5 -ne $LatestDellCommandUpdate.MD5) {
        throw "MD5 verification failed. Expected: $($LatestDellCommandUpdate.MD5), Got: $InstallerMD5"
      }
      Write-Log 'MD5 verification successful'

      # Install Dell Command Update
      Write-Log 'Installing Dell Command Update...'
      $InstallProcess = Start-Process -Wait -NoNewWindow -FilePath $Installer -ArgumentList '/s' -PassThru
      
      if ($InstallProcess.ExitCode -ne 0) {
        throw "Installation failed with exit code: $($InstallProcess.ExitCode)"
      }

      # Wait a moment for installation to complete
      Start-Sleep -Seconds 5

      # Confirm installation
      $InstalledApp = Get-InstalledApps -DisplayName 'Dell Command | Update for Windows Universal', 'Dell Command | Update for Windows 10'
      $NewVersion = $InstalledApp.DisplayVersion
      if ($NewVersion -is [array]) { $NewVersion = $NewVersion[0] }
      
      if ([string]::IsNullOrEmpty($NewVersion)) {
        throw "Dell Command Update not detected after installation attempt"
      }
      
      # Use version comparison instead of string matching
      if ([version]$NewVersion -ge [version]$LatestDellCommandUpdate.Version) {
        Write-Log "Successfully installed Dell Command Update [$NewVersion]"
        Remove-Item $Installer -Force -ErrorAction SilentlyContinue
      }
      else {
        throw "Version mismatch after installation. Expected: $($LatestDellCommandUpdate.Version), Got: $NewVersion"
      }
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
  function Get-LatestDotNetDesktopRuntime {
    $BaseURL = 'https://builds.dotnet.microsoft.com/dotnet/WindowsDesktop'
    
    try {
      $Version = (Invoke-WebRequest -Uri "$BaseURL/LTS/latest.version" -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop).Content.Trim()
      $Arch = Get-Architecture
      $URL = "$BaseURL/$Version/windowsdesktop-runtime-$Version-win-$Arch.exe"
    
      return @{
        URL     = $URL
        Version = $Version
      }
    }
    catch {
      Write-Log "Failed to retrieve .NET version from Microsoft: $($_.Exception.Message)" -Level 'WARNING'
      
      # Fallback to known stable version
      $Arch = Get-Architecture
      $FallbackVersion = '8.0.11'
      return @{
        URL     = "https://builds.dotnet.microsoft.com/dotnet/WindowsDesktop/8.0.11/windowsdesktop-runtime-$FallbackVersion-win-$Arch.exe"
        Version = $FallbackVersion
      }
    }
  }
  
  $LatestDotNet = Get-LatestDotNetDesktopRuntime
  $Installer = Join-Path -Path $env:TEMP -ChildPath (Split-Path $LatestDotNet.URL -Leaf)
  
  $InstalledApp = Get-InstalledApps -DisplayName 'Microsoft Windows Desktop Runtime'
  $CurrentVersion = $InstalledApp.BundleVersion
  if ($CurrentVersion -is [array]) { $CurrentVersion = $CurrentVersion[0] }
  
  Write-Log "Installed .NET Desktop Runtime: $CurrentVersion"
  Write-Log "Latest .NET Desktop Runtime: $($LatestDotNet.Version)"

  # Compare versions properly
  $NeedsInstall = $false
  if ([string]::IsNullOrEmpty($CurrentVersion)) {
    $NeedsInstall = $true
    Write-Log "No existing .NET installation detected"
  }
  elseif ([version]$CurrentVersion -lt [version]$LatestDotNet.Version) {
    $NeedsInstall = $true
    Write-Log ".NET upgrade needed"
  }

  if ($NeedsInstall) {
    try {
      # Download installer
      Write-Log ".NET Desktop Runtime installation needed"
      Write-Log "Downloading from: $($LatestDotNet.URL)"
      Invoke-WebRequest -Uri $LatestDotNet.URL -OutFile $Installer -TimeoutSec 300 -ErrorAction Stop

      # Install .NET
      Write-Log 'Installing .NET Desktop Runtime...'
      $InstallProcess = Start-Process -Wait -NoNewWindow -FilePath $Installer -ArgumentList '/install /quiet /norestart' -PassThru
      
      if ($InstallProcess.ExitCode -ne 0 -and $InstallProcess.ExitCode -ne 3010) {
        throw "Installation failed with exit code: $($InstallProcess.ExitCode)"
      }

      # Wait a moment for installation to complete
      Start-Sleep -Seconds 5

      # Confirm installation
      $InstalledApp = Get-InstalledApps -DisplayName 'Microsoft Windows Desktop Runtime'
      $NewVersion = $InstalledApp.BundleVersion
      if ($NewVersion -is [array]) { $NewVersion = $NewVersion[0] }
      
      if ([string]::IsNullOrEmpty($NewVersion)) {
        throw ".NET Desktop Runtime not detected after installation attempt"
      }
      
      if ([version]$NewVersion -ge [version]$LatestDotNet.Version) {
        Write-Log "Successfully installed .NET Desktop Runtime [$NewVersion]"
        Remove-Item $Installer -Force -ErrorAction SilentlyContinue
      }
      else {
        throw "Version mismatch after installation. Expected: $($LatestDotNet.Version), Got: $NewVersion"
      }
    }
    catch {
      Write-Log "Failed to install .NET Desktop Runtime: $($_.Exception.Message)" -Level 'ERROR'
      Remove-Item $Installer -Force -ErrorAction SilentlyContinue
      exit 1
    }
  }
  else { 
    Write-Log ".NET Desktop Runtime installation / upgrade not needed"
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
    if ($ConfigProcess.ExitCode -ne 0) {
      Write-Log "DCU configuration returned exit code: $($ConfigProcess.ExitCode)" -Level 'WARNING'
    }
    
    # Scan for updates
    Write-Log 'Scanning for Dell updates...'
    $ScanProcess = Start-Process -NoNewWindow -Wait -FilePath $DCU -ArgumentList '/scan -silent' -PassThru
    if ($ScanProcess.ExitCode -ne 0) {
      Write-Log "DCU scan returned exit code: $($ScanProcess.ExitCode)" -Level 'WARNING'
    }
    
    # Apply updates
    Write-Log 'Applying Dell updates...'
    $UpdateProcess = Start-Process -NoNewWindow -Wait -FilePath $DCU -ArgumentList '/applyUpdates -autoSuspendBitLocker=enable -reboot=disable' -PassThru
    
    Write-Log "DCU apply updates completed with exit code: $($UpdateProcess.ExitCode)"
    
    # Exit code 0 = success, 500 = no updates available, 1 = reboot required
    if ($UpdateProcess.ExitCode -eq 0 -or $UpdateProcess.ExitCode -eq 500) {
      Write-Log 'Dell updates completed successfully'
    }
    elseif ($UpdateProcess.ExitCode -eq 1) {
      Write-Log 'Dell updates applied - reboot required' -Level 'WARNING'
    }
    else {
      Write-Log "DCU returned unexpected exit code: $($UpdateProcess.ExitCode)" -Level 'WARNING'
    }
  }
  catch {
    Write-Log "Unable to apply updates using the dcu-cli: $($_.Exception.Message)" -Level 'ERROR'
    exit 1
  }
}

# Set PowerShell preferences
Set-Location -Path $env:SystemRoot
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'

# Ensure TLS 1.2 or higher
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

# Handle Prerequisites / Dependencies
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
