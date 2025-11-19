<#
  .SYNOPSIS
    Installs Dell updates via Dell Command Update
  .DESCRIPTION
    Installs the latest version of Dell Command Update and applies all Dell updates silently.
  .LINK
    https://www.dell.com/support/product-details/en-us/product/command-update/resources/manuals
    https://github.com/wise-io/scripts/blob/main/scripts/DellCommandUpdate.ps1
  .NOTES
    Author: Aaron J. Stevenson
    Modified: Bryan [Bug fixes and improved error handling]
#>

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
    $AppsWithBundledVersion = Get-ChildItem -Path $RegPaths | Get-ItemProperty | Where-Object { $_.DisplayName -like "*$DisplayName*" -and $null -ne $_.BundleVersion }
    if ($AppsWithBundledVersion) { $BroadMatch += $AppsWithBundledVersion }
    else { $BroadMatch += Get-ChildItem -Path $RegPaths | Get-ItemProperty | Where-Object { $_.DisplayName -like "*$DisplayName*" } }
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
  
  if ($IncompatibleApps) { Write-Output 'Incompatible applications detected' }
  foreach ($App in $IncompatibleApps) {
    Write-Output "Attempting to remove [$($App.DisplayName)]"
    try {
      if ($App.UninstallString -match 'msiexec') {
        $Guid = [regex]::Match($App.UninstallString, '\{[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}\}').Value
        Start-Process -NoNewWindow -Wait -FilePath 'msiexec.exe' -ArgumentList "/x $Guid /quiet /qn"
      }
      else { Start-Process -NoNewWindow -Wait -FilePath $App.UninstallString -ArgumentList '/quiet' }
      Write-Output "Successfully removed $($App.DisplayName)"
    }
    catch { 
      Write-Warning "Failed to remove $($App.DisplayName)"
      Write-Warning $_
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
    }
    else { 
      $FallbackDownloadURL = 'https://dl.dell.com/FOLDER12925773M/1/Dell-Command-Update-Windows-Universal-Application_P4DJW_WIN64_5.5.0_A00.EXE'
      $FallbackMD5 = 'a1eb9c7eadb6d9cbfbbe2be13049b299'
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
    }
    catch {
      Write-Warning "Unable to retrieve Dell KB page, using fallback URL"
      $KBLinks = @()
    }
  
    # Attempt to parse Dell website for download URLs for latest DCU
    $DownloadObjects = foreach ($Link in $KBLinks) {
      try {
        $DownloadPage = Invoke-WebRequest -UseBasicParsing -Uri $Link -Headers $Headers -TimeoutSec 30 -ErrorAction Stop
        if ($DownloadPage -match '(https://dl\.dell\.com.+Dell-Command-Update.+\.EXE)') { 
          $Url = $Matches[1]
          $MD5 = $null
          if ($DownloadPage -match 'MD5:.*?([a-fA-F0-9]{32})') { $MD5 = $Matches[1] }
          [PSCustomObject]@{
            URL = $Url
            MD5 = $MD5
          }
        }
      }
      catch {
        Write-Warning "Unable to retrieve download page: $Link"
      }
    }
  
    # Set download URL / MD5 based on architecture
    if ($Arch -like 'arm*') { $DownloadObject = $DownloadObjects | Where-Object { $_.URL -like '*winarm*' } | Select-Object -First 1 }
    else { $DownloadObject = $DownloadObjects | Where-Object { $_.URL -notlike '*winarm*' } | Select-Object -First 1 }
    
    $DownloadURL = $DownloadObject.URL
    $MD5 = $DownloadObject.MD5
    $Version = $null

    # Get version from DownloadURL if available
    if ($DownloadURL) {
      $Version = $DownloadURL | Select-String '[0-9]+\.[0-9]+\.[0-9]+' | ForEach-Object { $_.Matches.Value }
    }

    # Revert to fallback URL / MD5 / Version if unable to retrieve from Dell
    if ($null -eq $DownloadURL -or $null -eq $MD5 -or $null -eq $Version) { 
      Write-Output "Using fallback download information"
      $DownloadURL = $FallbackDownloadURL
      $MD5 = $FallbackMD5
      $Version = $FallbackDownloadURL | Select-String '[0-9]+\.[0-9]+\.[0-9]+' | ForEach-Object { $_.Matches.Value }
    }
  
    return @{
      MD5     = $MD5.ToUpper()
      URL     = $DownloadURL
      Version = $Version
    }
  }
  
  try {
    $LatestDellCommandUpdate = Get-LatestDellCommandUpdate
    $Installer = Join-Path -Path $env:TEMP -ChildPath (Split-Path $LatestDellCommandUpdate.URL -Leaf)
    $CurrentVersion = (Get-InstalledApps -DisplayName 'Dell Command | Update for Windows Universal', 'Dell Command | Update for Windows 10').DisplayVersion
    Write-Output "`nInstalled Dell Command Update: $CurrentVersion"
    Write-Output "Latest Dell Command Update: $($LatestDellCommandUpdate.Version)"

    # Compare versions properly
    $NeedsInstall = $false
    if ($null -eq $CurrentVersion) {
      $NeedsInstall = $true
      Write-Output "Dell Command Update not currently installed"
    }
    elseif ([version]$CurrentVersion -lt [version]$LatestDellCommandUpdate.Version) {
      $NeedsInstall = $true
      Write-Output "Upgrade available"
    }

    if ($NeedsInstall) {

      # Download installer
      Write-Output "`nDell Command Update installation needed"
      Write-Output 'Downloading...'
      Invoke-WebRequest -Uri $LatestDellCommandUpdate.URL -OutFile $Installer -UserAgent ([Microsoft.PowerShell.Commands.PSUserAgent]::Chrome) -TimeoutSec 300 -ErrorAction Stop

      # Verify MD5 checksum
      Write-Output 'Verifying MD5 checksum...'
      $InstallerMD5 = (Get-FileHash -Path $Installer -Algorithm MD5).Hash
      if ($InstallerMD5 -ne $LatestDellCommandUpdate.MD5) {
        Write-Warning "MD5 verification failed"
        Write-Warning "Expected: $($LatestDellCommandUpdate.MD5)"
        Write-Warning "Got: $InstallerMD5"
        Remove-Item $Installer -Force -ErrorAction Ignore
        exit 1
      }

      # Install Dell Command Update
      Write-Output 'Installing...'
      $InstallProcess = Start-Process -Wait -NoNewWindow -FilePath $Installer -ArgumentList '/s' -PassThru
      
      if ($InstallProcess.ExitCode -ne 0) {
        Write-Warning "Installation returned exit code: $($InstallProcess.ExitCode)"
      }

      # Wait a moment for registry to update
      Start-Sleep -Seconds 5

      # Confirm installation by comparing versions
      $CurrentVersion = (Get-InstalledApps -DisplayName 'Dell Command | Update for Windows Universal', 'Dell Command | Update for Windows 10').DisplayVersion
      if ($null -ne $CurrentVersion -and [version]$CurrentVersion -ge [version]$LatestDellCommandUpdate.Version) {
        Write-Output "Successfully installed Dell Command Update [$CurrentVersion]`n"
        Remove-Item $Installer -Force -ErrorAction Ignore 
      }
      else {
        Write-Warning "Dell Command Update [$($LatestDellCommandUpdate.Version)] not detected after installation attempt"
        Write-Warning "Current version detected: $CurrentVersion"
        Remove-Item $Installer -Force -ErrorAction Ignore 
        exit 1
      }
    }
    else { Write-Output "`nDell Command Update installation / upgrade not needed`n" }
  }
  catch {
    Write-Warning "Error during Dell Command Update installation: $_"
    if (Test-Path $Installer) { Remove-Item $Installer -Force -ErrorAction Ignore }
    exit 1
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
      Write-Warning "Unable to retrieve latest .NET version information: $_"
      throw
    }
  }
  
  try {
    $LatestDotNet = Get-LatestDotNetDesktopRuntime
    $Installer = Join-Path -Path $env:TEMP -ChildPath (Split-Path $LatestDotNet.URL -Leaf)
    $CurrentVersion = (Get-InstalledApps -DisplayName 'Microsoft Windows Desktop Runtime').BundleVersion
    if ($CurrentVersion -is [system.array]) { $CurrentVersion = $CurrentVersion[0] }
    Write-Output "`nInstalled .NET Desktop Runtime: $CurrentVersion"
    Write-Output "Latest .NET Desktop Runtime: $($LatestDotNet.Version)"

    # Compare versions properly
    $NeedsInstall = $false
    if ($null -eq $CurrentVersion) {
      $NeedsInstall = $true
      Write-Output ".NET Desktop Runtime not currently installed"
    }
    elseif ([version]$CurrentVersion -lt [version]$LatestDotNet.Version) {
      $NeedsInstall = $true
      Write-Output "Upgrade available"
    }

    if ($NeedsInstall) {
      
      # Download installer
      Write-Output "`n.NET Desktop Runtime installation needed"
      Write-Output 'Downloading...'
      Invoke-WebRequest -Uri $LatestDotNet.URL -OutFile $Installer -TimeoutSec 300 -ErrorAction Stop

      # Install .NET
      Write-Output 'Installing...'
      $InstallProcess = Start-Process -Wait -NoNewWindow -FilePath $Installer -ArgumentList '/install /quiet /norestart' -PassThru

      if ($InstallProcess.ExitCode -ne 0 -and $InstallProcess.ExitCode -ne 3010) {
        Write-Warning "Installation returned exit code: $($InstallProcess.ExitCode)"
      }

      # Wait a moment for registry to update
      Start-Sleep -Seconds 5

      # Confirm installation
      $CurrentVersion = (Get-InstalledApps -DisplayName 'Microsoft Windows Desktop Runtime').BundleVersion
      if ($CurrentVersion -is [system.array]) { $CurrentVersion = $CurrentVersion[0] }
      if ($null -ne $CurrentVersion -and [version]$CurrentVersion -ge [version]$LatestDotNet.Version) {
        Write-Output "Successfully installed .NET Desktop Runtime [$CurrentVersion]"
        Remove-Item $Installer -Force -ErrorAction Ignore 
      }
      else {
        Write-Warning ".NET Desktop Runtime [$($LatestDotNet.Version)] not detected after installation attempt"
        Write-Warning "Current version detected: $CurrentVersion"
        Remove-Item $Installer -Force -ErrorAction Ignore 
        exit 1
      }
    }
    else { Write-Output "`n.NET Desktop Runtime installation / upgrade not needed" }
  }
  catch {
    Write-Warning "Error during .NET Desktop Runtime installation: $_"
    if (Test-Path $Installer) { Remove-Item $Installer -Force -ErrorAction Ignore }
    exit 1
  }
}

function Invoke-DellCommandUpdate {
  # Check for DCU CLI
  $DCU = (Resolve-Path "$env:SystemDrive\Program Files*\Dell\CommandUpdate\dcu-cli.exe" -ErrorAction SilentlyContinue).Path
  if ($null -eq $DCU) {
    Write-Warning 'Dell Command Update CLI was not detected.'
    exit 1
  }
  
  try {
    Write-Output "`nConfiguring Dell Command Update..."
    # Configure DCU automatic updates
    $ConfigureProcess = Start-Process -NoNewWindow -Wait -FilePath $DCU -ArgumentList '/configure -scheduleAction=DownloadInstallAndNotify -updatesNotification=disable -forceRestart=disable -scheduleAuto -silent' -PassThru
    if ($ConfigureProcess.ExitCode -ne 0) {
      Write-Warning "DCU configure returned exit code: $($ConfigureProcess.ExitCode)"
    }
    
    Write-Output "Scanning for updates..."
    # Scan for / apply updates
    $ScanProcess = Start-Process -NoNewWindow -Wait -FilePath $DCU -ArgumentList '/scan -silent' -PassThru
    if ($ScanProcess.ExitCode -ne 0) {
      Write-Warning "DCU scan returned exit code: $($ScanProcess.ExitCode)"
    }
    
    Write-Output "Applying updates..."
    $ApplyProcess = Start-Process -NoNewWindow -Wait -FilePath $DCU -ArgumentList '/applyUpdates -autoSuspendBitLocker=enable -reboot=disable' -PassThru
    if ($ApplyProcess.ExitCode -ne 0) {
      Write-Warning "DCU applyUpdates returned exit code: $($ApplyProcess.ExitCode)"
    }
    
    Write-Output "Dell Command Update process completed"
  }
  catch {
    Write-Warning 'Unable to apply updates using the dcu-cli.'
    Write-Warning $_
    exit 1
  }
}

# Set PowerShell preferences
Set-Location -Path $env:SystemRoot
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'
if ([Net.ServicePointManager]::SecurityProtocol -notcontains 'Tls12' -and [Net.ServicePointManager]::SecurityProtocol -notcontains 'Tls13') {
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}

# Log start time
Write-Output "=== Dell Command Update Script Started ==="
Write-Output "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Output "Computer: $env:COMPUTERNAME"
Write-Output "User Context: $env:USERNAME"

# Check device manufacturer
if ((Get-CimInstance -ClassName Win32_BIOS).Manufacturer -notlike '*Dell*') {
  Write-Output "`nNot a Dell system. Aborting..."
  exit 0
}

Write-Output "Dell system detected - proceeding with updates"

# Handle Prerequisites / Dependencies
Remove-IncompatibleApps
Install-DotNetDesktopRuntime

# Install DCU and available updates
Install-DellCommandUpdate
Invoke-DellCommandUpdate

Write-Output "`n=== Dell Command Update Script Completed ==="
Write-Output "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
