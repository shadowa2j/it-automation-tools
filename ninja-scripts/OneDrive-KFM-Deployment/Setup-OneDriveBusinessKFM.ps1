<#
.SYNOPSIS
    Configures OneDrive for Business with silent sign-in and Known Folder Move (KFM).

.DESCRIPTION
    This script checks if OneDrive is installed and signed into a business account with KFM enabled.
    If not configured properly, it will:
    1. Install OneDrive if missing (via winget, fallback to Microsoft CDN)
    2. Auto-discover the Azure AD tenant ID from the device join info
    3. Configure silent SSO sign-in via registry
    4. Enable KFM for Desktop, Documents, and Pictures folders
    5. Prevent users from disabling KFM

    Designed for NinjaRMM deployment, running as the logged-in user context.
    Safe to run multiple times (idempotent).

.NOTES
    Author: Bryan Faulkner, with assistance from Claude
    Version: 1.0.0
    Requires: Windows 10/11, Azure AD Hybrid Joined device
    Run As: Logged-in user (via NinjaRMM "Run As Logged In User")

.OUTPUTS
    Exit 0 = Success - OneDrive Business configured with KFM
    Exit 1 = Partial Success - Configuration applied, requires OneDrive restart/relaunch
    Exit 2 = Failed - See stdout for details
#>

#Requires -Version 5.1

# ============================================================================
# CONFIGURATION
# ============================================================================
$ErrorActionPreference = "Stop"
$Script:LogMessages = @()
$Script:ExitCode = 0
$Script:NeedsOneDriveRestart = $false

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS")]
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    $Script:LogMessages += $logEntry
    
    switch ($Level) {
        "ERROR"   { Write-Host $logEntry -ForegroundColor Red }
        "WARN"    { Write-Host $logEntry -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logEntry -ForegroundColor Green }
        default   { Write-Host $logEntry }
    }
}

function Get-OneDriveInstallPath {
    # Check common OneDrive installation locations
    $paths = @(
        "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe",
        "$env:ProgramFiles\Microsoft OneDrive\OneDrive.exe",
        "${env:ProgramFiles(x86)}\Microsoft OneDrive\OneDrive.exe",
        "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"
    )
    
    foreach ($path in $paths) {
        if (Test-Path $path) {
            return $path
        }
    }
    return $null
}

function Test-OneDriveInstalled {
    $oneDrivePath = Get-OneDriveInstallPath
    if ($oneDrivePath -and $oneDrivePath -notlike "*Setup*") {
        Write-Log "OneDrive found at: $oneDrivePath" -Level "INFO"
        return $true
    }
    return $false
}

function Get-AzureTenantId {
    # Method 1: Try registry CloudDomainJoin info (most reliable for hybrid joined)
    $joinInfoPath = "HKLM:\SYSTEM\CurrentControlSet\Control\CloudDomainJoin\JoinInfo"
    if (Test-Path $joinInfoPath) {
        $guids = Get-ChildItem $joinInfoPath -ErrorAction SilentlyContinue
        foreach ($guid in $guids) {
            $tenantId = Get-ItemProperty -Path $guid.PSPath -Name "TenantId" -ErrorAction SilentlyContinue
            if ($tenantId.TenantId) {
                Write-Log "Tenant ID found via CloudDomainJoin: $($tenantId.TenantId)" -Level "INFO"
                return $tenantId.TenantId
            }
        }
    }
    
    # Method 2: Parse dsregcmd output
    try {
        $dsregOutput = dsregcmd /status 2>&1 | Out-String
        if ($dsregOutput -match "TenantId\s*:\s*([a-f0-9\-]{36})") {
            $tenantId = $matches[1]
            Write-Log "Tenant ID found via dsregcmd: $tenantId" -Level "INFO"
            return $tenantId
        }
    }
    catch {
        Write-Log "Failed to parse dsregcmd output: $_" -Level "WARN"
    }
    
    # Method 3: Check AAD registry key
    $aadPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CDJ\AAD"
    if (Test-Path $aadPath) {
        $tenantId = Get-ItemProperty -Path $aadPath -Name "TenantId" -ErrorAction SilentlyContinue
        if ($tenantId.TenantId) {
            Write-Log "Tenant ID found via CDJ\AAD: $($tenantId.TenantId)" -Level "INFO"
            return $tenantId.TenantId
        }
    }
    
    return $null
}

function Test-AzureADJoined {
    try {
        $dsregOutput = dsregcmd /status 2>&1 | Out-String
        $azureJoined = $dsregOutput -match "AzureAdJoined\s*:\s*YES"
        $domainJoined = $dsregOutput -match "DomainJoined\s*:\s*YES"
        
        if ($azureJoined -or $domainJoined) {
            Write-Log "Device is Azure AD Joined: $azureJoined, Domain Joined: $domainJoined" -Level "INFO"
            return $true
        }
    }
    catch {
        Write-Log "Failed to check Azure AD join status: $_" -Level "WARN"
    }
    return $false
}

function Test-OneDriveBusinessSignedIn {
    $businessPath = "HKCU:\Software\Microsoft\OneDrive\Accounts\Business1"
    if (Test-Path $businessPath) {
        $userFolder = Get-ItemProperty -Path $businessPath -Name "UserFolder" -ErrorAction SilentlyContinue
        $userEmail = Get-ItemProperty -Path $businessPath -Name "UserEmail" -ErrorAction SilentlyContinue
        
        if ($userFolder.UserFolder -and (Test-Path $userFolder.UserFolder)) {
            Write-Log "OneDrive Business signed in as: $($userEmail.UserEmail)" -Level "INFO"
            Write-Log "OneDrive folder: $($userFolder.UserFolder)" -Level "INFO"
            return $true
        }
    }
    return $false
}

function Test-KFMEnabled {
    $businessPath = "HKCU:\Software\Microsoft\OneDrive\Accounts\Business1"
    if (-not (Test-Path $businessPath)) {
        return @{ Enabled = $false; Desktop = $false; Documents = $false; Pictures = $false }
    }
    
    # Check KfmFoldersProtectedNow - bitmask where 1=Desktop, 2=Documents, 4=Pictures
    $kfmStatus = Get-ItemProperty -Path $businessPath -Name "KfmFoldersProtectedNow" -ErrorAction SilentlyContinue
    
    $result = @{
        Enabled = $false
        Desktop = $false
        Documents = $false
        Pictures = $false
        Value = 0
    }
    
    if ($kfmStatus.KfmFoldersProtectedNow) {
        $value = [int]$kfmStatus.KfmFoldersProtectedNow
        $result.Value = $value
        $result.Desktop = ($value -band 1) -eq 1
        $result.Documents = ($value -band 2) -eq 2
        $result.Pictures = ($value -band 4) -eq 4
        $result.Enabled = $result.Desktop -and $result.Documents -and $result.Pictures
    }
    
    # Also check if folders are redirected by looking at shell folders
    $shellFolders = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"
    $desktopPath = (Get-ItemProperty -Path $shellFolders -Name "Desktop" -ErrorAction SilentlyContinue).Desktop
    $documentsPath = (Get-ItemProperty -Path $shellFolders -Name "Personal" -ErrorAction SilentlyContinue).Personal
    $picturesPath = (Get-ItemProperty -Path $shellFolders -Name "My Pictures" -ErrorAction SilentlyContinue)."My Pictures"
    
    # If paths contain OneDrive, they're redirected
    if ($desktopPath -like "*OneDrive*") { $result.Desktop = $true }
    if ($documentsPath -like "*OneDrive*") { $result.Documents = $true }
    if ($picturesPath -like "*OneDrive*") { $result.Pictures = $true }
    
    $result.Enabled = $result.Desktop -and $result.Documents -and $result.Pictures
    
    return $result
}

function Install-OneDrive {
    Write-Log "OneDrive not installed, attempting installation..." -Level "INFO"
    
    # Method 1: Try winget
    $wingetPath = Get-Command winget -ErrorAction SilentlyContinue
    if ($wingetPath) {
        Write-Log "Attempting installation via winget..." -Level "INFO"
        try {
            $result = Start-Process -FilePath "winget" -ArgumentList "install --id Microsoft.OneDrive --accept-package-agreements --accept-source-agreements --silent" -Wait -PassThru -NoNewWindow
            if ($result.ExitCode -eq 0) {
                Write-Log "OneDrive installed successfully via winget" -Level "SUCCESS"
                Start-Sleep -Seconds 5
                return $true
            }
            Write-Log "Winget install returned exit code: $($result.ExitCode)" -Level "WARN"
        }
        catch {
            Write-Log "Winget installation failed: $_" -Level "WARN"
        }
    }
    
    # Method 2: Check for built-in setup
    $builtInSetup = "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"
    if (Test-Path $builtInSetup) {
        Write-Log "Attempting installation via built-in setup..." -Level "INFO"
        try {
            $result = Start-Process -FilePath $builtInSetup -ArgumentList "/silent" -Wait -PassThru
            if ($result.ExitCode -eq 0) {
                Write-Log "OneDrive installed successfully via built-in setup" -Level "SUCCESS"
                Start-Sleep -Seconds 5
                return $true
            }
            Write-Log "Built-in setup returned exit code: $($result.ExitCode)" -Level "WARN"
        }
        catch {
            Write-Log "Built-in setup failed: $_" -Level "WARN"
        }
    }
    
    # Method 3: Download from Microsoft CDN
    Write-Log "Attempting download from Microsoft CDN..." -Level "INFO"
    $downloadUrl = "https://go.microsoft.com/fwlink/?linkid=844652"
    $installerPath = "$env:TEMP\OneDriveSetup.exe"
    
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($downloadUrl, $installerPath)
        
        if (Test-Path $installerPath) {
            $result = Start-Process -FilePath $installerPath -ArgumentList "/silent" -Wait -PassThru
            Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
            
            if ($result.ExitCode -eq 0) {
                Write-Log "OneDrive installed successfully via CDN download" -Level "SUCCESS"
                Start-Sleep -Seconds 5
                return $true
            }
            Write-Log "CDN installer returned exit code: $($result.ExitCode)" -Level "WARN"
        }
    }
    catch {
        Write-Log "CDN download/install failed: $_" -Level "ERROR"
    }
    
    return $false
}

function Set-RegistryValue {
    param(
        [string]$Path,
        [string]$Name,
        [object]$Value,
        [string]$Type = "DWord"
    )
    
    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }
    
    $existing = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
    if ($existing.$Name -eq $Value) {
        Write-Log "Registry value already set: $Path\$Name = $Value" -Level "INFO"
        return $false  # No change needed
    }
    
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type
    Write-Log "Set registry value: $Path\$Name = $Value" -Level "INFO"
    return $true  # Changed
}

function Configure-SilentSSO {
    Write-Log "Configuring Silent Account Configuration..." -Level "INFO"
    $changed = $false
    
    # HKLM policy for SilentAccountConfig (machine-level, but we'll check it)
    # Note: This typically needs admin rights, so we check if it exists
    $policyPath = "HKLM:\SOFTWARE\Policies\Microsoft\OneDrive"
    try {
        $existing = Get-ItemProperty -Path $policyPath -Name "SilentAccountConfig" -ErrorAction SilentlyContinue
        if (-not $existing -or $existing.SilentAccountConfig -ne 1) {
            Write-Log "SilentAccountConfig not set at machine level (may require GPO or admin deployment)" -Level "WARN"
        }
        else {
            Write-Log "SilentAccountConfig already enabled at machine level" -Level "INFO"
        }
    }
    catch {
        Write-Log "Cannot check machine-level SilentAccountConfig: $_" -Level "WARN"
    }
    
    # Clear any blockers for re-running silent config
    $oneDrivePath = "HKCU:\Software\Microsoft\OneDrive"
    
    # Only clear SilentBusinessConfigCompleted if business account isn't already signed in
    if (-not (Test-OneDriveBusinessSignedIn)) {
        @(
            "SilentBusinessConfigCompleted",
            "OneAuthUnrecoverableTimestamp"
        ) | ForEach-Object {
            $existing = Get-ItemProperty -Path $oneDrivePath -Name $_ -ErrorAction SilentlyContinue
            if ($existing.$_) {
                Remove-ItemProperty -Path $oneDrivePath -Name $_ -Force -ErrorAction SilentlyContinue
                Write-Log "Cleared blocker: $_" -Level "INFO"
                $changed = $true
            }
        }
    }
    
    # Enable ADAL for modern auth
    if (Set-RegistryValue -Path $oneDrivePath -Name "EnableADAL" -Value 1) {
        $changed = $true
    }
    
    return $changed
}

function Configure-KFM {
    param(
        [Parameter(Mandatory)]
        [string]$TenantId
    )
    
    Write-Log "Configuring Known Folder Move for tenant: $TenantId" -Level "INFO"
    $changed = $false
    
    # Machine-level policies (HKLM) - these are typically set by GPO or admin scripts
    # We'll document what they should be, but may not have permission to set them
    $hklmPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\OneDrive"
    
    $hklmSettings = @{
        # Silent KFM - moves folders without user interaction
        "KFMSilentOptIn" = $TenantId
        # Block users from opting out of KFM
        "KFMBlockOptOut" = 1
        # Silent account config
        "SilentAccountConfig" = 1
    }
    
    # Try to set HKLM values (will fail without admin rights in user context)
    foreach ($setting in $hklmSettings.GetEnumerator()) {
        try {
            if ($setting.Value -is [string]) {
                $existingValue = (Get-ItemProperty -Path $hklmPolicyPath -Name $setting.Key -ErrorAction SilentlyContinue).$($setting.Key)
                if ($existingValue -ne $setting.Value) {
                    Set-ItemProperty -Path $hklmPolicyPath -Name $setting.Key -Value $setting.Value -Type String -ErrorAction Stop
                    Write-Log "Set HKLM policy: $($setting.Key) = $($setting.Value)" -Level "INFO"
                    $changed = $true
                }
            }
            else {
                if (Set-RegistryValue -Path $hklmPolicyPath -Name $setting.Key -Value $setting.Value) {
                    $changed = $true
                }
            }
        }
        catch {
            Write-Log "Cannot set HKLM policy $($setting.Key) (may need admin/GPO): $($_.Exception.Message)" -Level "WARN"
        }
    }
    
    # User-level settings that can help trigger KFM
    $hkcuOneDrivePath = "HKCU:\Software\Microsoft\OneDrive"
    $hkcuPolicyPath = "HKCU:\Software\Policies\Microsoft\OneDrive"
    
    # Ensure user policy path exists
    if (-not (Test-Path $hkcuPolicyPath)) {
        New-Item -Path $hkcuPolicyPath -Force | Out-Null
    }
    
    # Check if KFM has been silently attempted before and reset if needed
    $businessPath = "HKCU:\Software\Microsoft\OneDrive\Accounts\Business1"
    if (Test-Path $businessPath) {
        $kfmDone = Get-ItemProperty -Path $businessPath -Name "KfmIsDoneSilentOptIn" -ErrorAction SilentlyContinue
        
        # Value of 2 means it was done, we might need to reset to retrigger
        $kfmStatus = Test-KFMEnabled
        if (-not $kfmStatus.Enabled -and $kfmDone.KfmIsDoneSilentOptIn -eq 2) {
            # KFM was attempted but not all folders are protected - something went wrong
            # Don't reset automatically as this could cause issues
            Write-Log "KFM was previously attempted but not all folders protected. Manual intervention may be needed." -Level "WARN"
        }
    }
    
    return $changed
}

function Restart-OneDrive {
    Write-Log "Restarting OneDrive client..." -Level "INFO"
    
    # Stop OneDrive
    Get-Process -Name "OneDrive" -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 2
    
    # Start OneDrive
    $oneDrivePath = Get-OneDriveInstallPath
    if ($oneDrivePath -and $oneDrivePath -notlike "*Setup*") {
        Start-Process -FilePath $oneDrivePath -ArgumentList "/background"
        Write-Log "OneDrive restarted" -Level "INFO"
        Start-Sleep -Seconds 5
    }
}

function Get-StatusSummary {
    $installed = Test-OneDriveInstalled
    $signedIn = Test-OneDriveBusinessSignedIn
    $kfmStatus = Test-KFMEnabled
    $tenantId = Get-AzureTenantId
    
    $summary = @{
        OneDriveInstalled = $installed
        BusinessSignedIn = $signedIn
        TenantId = $tenantId
        KFM = @{
            FullyEnabled = $kfmStatus.Enabled
            Desktop = $kfmStatus.Desktop
            Documents = $kfmStatus.Documents
            Pictures = $kfmStatus.Pictures
        }
    }
    
    return $summary
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================
Write-Log "========================================" -Level "INFO"
Write-Log "OneDrive Business KFM Configuration Script" -Level "INFO"
Write-Log "Running as: $env:USERNAME" -Level "INFO"
Write-Log "Computer: $env:COMPUTERNAME" -Level "INFO"
Write-Log "========================================" -Level "INFO"

try {
    # Step 1: Check Azure AD join status
    if (-not (Test-AzureADJoined)) {
        Write-Log "Device is not Azure AD or Hybrid joined. Cannot configure OneDrive Business." -Level "ERROR"
        $Script:ExitCode = 2
        throw "Device not Azure AD joined"
    }
    
    # Step 2: Get Tenant ID
    $tenantId = Get-AzureTenantId
    if (-not $tenantId) {
        Write-Log "Could not discover Azure AD Tenant ID. Device may not be properly joined." -Level "ERROR"
        $Script:ExitCode = 2
        throw "Tenant ID not found"
    }
    Write-Log "Using Tenant ID: $tenantId" -Level "INFO"
    
    # Step 3: Check/Install OneDrive
    if (-not (Test-OneDriveInstalled)) {
        $installResult = Install-OneDrive
        if (-not $installResult) {
            Write-Log "Failed to install OneDrive" -Level "ERROR"
            $Script:ExitCode = 2
            throw "OneDrive installation failed"
        }
        $Script:NeedsOneDriveRestart = $true
    }
    
    # Step 4: Configure Silent SSO
    $ssoChanged = Configure-SilentSSO
    if ($ssoChanged) {
        $Script:NeedsOneDriveRestart = $true
    }
    
    # Step 5: Configure KFM
    $kfmChanged = Configure-KFM -TenantId $tenantId
    if ($kfmChanged) {
        $Script:NeedsOneDriveRestart = $true
    }
    
    # Step 6: Restart OneDrive if needed
    if ($Script:NeedsOneDriveRestart) {
        Restart-OneDrive
        # Give OneDrive time to apply settings
        Start-Sleep -Seconds 10
    }
    
    # Step 7: Final status check
    Write-Log "========================================" -Level "INFO"
    Write-Log "Final Status Check" -Level "INFO"
    Write-Log "========================================" -Level "INFO"
    
    $finalStatus = Get-StatusSummary
    
    Write-Log "OneDrive Installed: $($finalStatus.OneDriveInstalled)" -Level "INFO"
    Write-Log "Business Account Signed In: $($finalStatus.BusinessSignedIn)" -Level "INFO"
    Write-Log "KFM Desktop: $($finalStatus.KFM.Desktop)" -Level "INFO"
    Write-Log "KFM Documents: $($finalStatus.KFM.Documents)" -Level "INFO"
    Write-Log "KFM Pictures: $($finalStatus.KFM.Pictures)" -Level "INFO"
    Write-Log "KFM Fully Enabled: $($finalStatus.KFM.FullyEnabled)" -Level "INFO"
    
    # Determine final exit code
    if ($finalStatus.OneDriveInstalled -and $finalStatus.BusinessSignedIn -and $finalStatus.KFM.FullyEnabled) {
        Write-Log "SUCCESS: OneDrive Business fully configured with KFM" -Level "SUCCESS"
        $Script:ExitCode = 0
    }
    elseif ($finalStatus.OneDriveInstalled) {
        if (-not $finalStatus.BusinessSignedIn) {
            Write-Log "OneDrive installed but not yet signed in. Silent sign-in will occur on next OneDrive launch or user login." -Level "WARN"
        }
        if (-not $finalStatus.KFM.FullyEnabled) {
            Write-Log "KFM not fully enabled yet. This may occur after sign-in completes." -Level "WARN"
        }
        Write-Log "PARTIAL: Configuration applied, may need user login cycle or OneDrive restart" -Level "WARN"
        $Script:ExitCode = 1
    }
    else {
        Write-Log "FAILED: Could not configure OneDrive" -Level "ERROR"
        $Script:ExitCode = 2
    }
    
    # Output summary for Ninja custom field
    Write-Host ""
    Write-Host "=== NINJA OUTPUT ===" 
    Write-Host "Status: $(if ($Script:ExitCode -eq 0) { 'Configured' } elseif ($Script:ExitCode -eq 1) { 'Pending' } else { 'Failed' })"
    Write-Host "OneDrive: $(if ($finalStatus.OneDriveInstalled) { 'Installed' } else { 'Missing' })"
    Write-Host "Business: $(if ($finalStatus.BusinessSignedIn) { 'SignedIn' } else { 'NotSignedIn' })"
    Write-Host "KFM: $(if ($finalStatus.KFM.FullyEnabled) { 'Enabled' } else { "Desktop=$($finalStatus.KFM.Desktop),Docs=$($finalStatus.KFM.Documents),Pics=$($finalStatus.KFM.Pictures)" })"
    Write-Host "TenantID: $($finalStatus.TenantId)"
}
catch {
    Write-Log "Script execution failed: $_" -Level "ERROR"
    Write-Log $_.ScriptStackTrace -Level "ERROR"
    if ($Script:ExitCode -eq 0) { $Script:ExitCode = 2 }
}

exit $Script:ExitCode
