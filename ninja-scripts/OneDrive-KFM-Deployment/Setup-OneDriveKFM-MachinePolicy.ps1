<#
.SYNOPSIS
    Configures machine-level OneDrive policies for silent sign-in and Known Folder Move (KFM).

.DESCRIPTION
    This script sets HKLM registry policies that enable:
    1. Silent account configuration (auto sign-in with Windows credentials)
    2. Silent Known Folder Move for Desktop, Documents, and Pictures
    3. Blocking users from disabling KFM
    4. Files On-Demand enabled by default

    Must be run as SYSTEM or Administrator BEFORE the user-context script.
    Designed for NinjaRMM deployment.

.PARAMETER TenantId
    Optional. Azure AD Tenant ID (GUID format). If not provided, the script will
    attempt to auto-discover from device join info, dsregcmd, or registry.
    Use this for:
    - Pre-staging machines before any user has signed in
    - Devices that aren't hybrid Azure AD joined
    - When auto-discovery fails

.EXAMPLE
    .\Setup-OneDriveKFM-MachinePolicy.ps1
    Auto-discovers tenant ID from device.

.EXAMPLE
    .\Setup-OneDriveKFM-MachinePolicy.ps1 -TenantId "b71226e9-ed4b-4f10-88f9-44382dff3cbc"
    Uses the manually specified tenant ID.

.NOTES
    Author: Bryan Faulkner, with assistance from Claude
    Version: 1.3.0
    Requires: Windows 10/11, Run as SYSTEM or Administrator
    Run As: SYSTEM (via NinjaRMM default context)

.OUTPUTS
    Exit 0 = Success - Machine policies configured
    Exit 1 = Partial Success - Some policies set, check output
    Exit 2 = Failed - Could not configure policies
#>

#Requires -Version 5.1
#Requires -RunAsAdministrator

param(
    [Parameter(Mandatory = $false)]
    [ValidatePattern('^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$')]
    [string]$TenantId
)

# Also check for NinjaRMM environment variable (script variables in Ninja)
if ([string]::IsNullOrWhiteSpace($TenantId) -and $env:TenantId) {
    $TenantId = $env:TenantId
}

# ============================================================================
# CONFIGURATION
# ============================================================================
$ErrorActionPreference = "Stop"
$Script:ExitCode = 0
$Script:ChangesMade = $false

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
    
    switch ($Level) {
        "ERROR"   { Write-Host $logEntry -ForegroundColor Red }
        "WARN"    { Write-Host $logEntry -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logEntry -ForegroundColor Green }
        default   { Write-Host $logEntry }
    }
}

function Get-AzureTenantId {
    # Method 1: Try registry CloudDomainJoin info (most reliable for hybrid joined)
    $joinInfoPath = "HKLM:\SYSTEM\CurrentControlSet\Control\CloudDomainJoin\JoinInfo"
    if (Test-Path $joinInfoPath) {
        $guids = Get-ChildItem $joinInfoPath -ErrorAction SilentlyContinue
        foreach ($guid in $guids) {
            $tenantIdValue = Get-ItemProperty -Path $guid.PSPath -Name "TenantId" -ErrorAction SilentlyContinue
            if ($tenantIdValue.TenantId) {
                Write-Log "Tenant ID found via CloudDomainJoin: $($tenantIdValue.TenantId)" -Level "INFO"
                return $tenantIdValue.TenantId
            }
        }
    }
    
    # Method 2: Parse dsregcmd output for TenantId (Hybrid/Azure AD Joined)
    try {
        $dsregOutput = dsregcmd /status 2>&1 | Out-String
        if ($dsregOutput -match "TenantId\s*:\s*([a-f0-9\-]{36})") {
            $tenantIdValue = $matches[1]
            Write-Log "Tenant ID found via dsregcmd (TenantId): $tenantIdValue" -Level "INFO"
            return $tenantIdValue
        }
    }
    catch {
        Write-Log "Failed to parse dsregcmd output: $_" -Level "WARN"
    }
    
    # Method 3: Parse dsregcmd output for WorkplaceTenantId (Workplace Joined / Azure AD Registered)
    try {
        $dsregOutput = dsregcmd /status 2>&1 | Out-String
        if ($dsregOutput -match "WorkplaceTenantId\s*:\s*([a-f0-9\-]{36})") {
            $tenantIdValue = $matches[1]
            Write-Log "Tenant ID found via dsregcmd (WorkplaceTenantId): $tenantIdValue" -Level "INFO"
            return $tenantIdValue
        }
    }
    catch {
        Write-Log "Failed to parse WorkplaceTenantId from dsregcmd: $_" -Level "WARN"
    }
    
    # Method 4: Check AAD registry key
    $aadPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CDJ\AAD"
    if (Test-Path $aadPath) {
        $tenantIdValue = Get-ItemProperty -Path $aadPath -Name "TenantId" -ErrorAction SilentlyContinue
        if ($tenantIdValue.TenantId) {
            Write-Log "Tenant ID found via CDJ\AAD: $($tenantIdValue.TenantId)" -Level "INFO"
            return $tenantIdValue.TenantId
        }
    }
    
    # Method 5: Check all user profiles for Workplace Join info (SYSTEM context can't see HKCU)
    $aadAccountsPath = "HKLM:\SOFTWARE\Microsoft\IdentityStore\Cache"
    if (Test-Path $aadAccountsPath) {
        $cacheKeys = Get-ChildItem $aadAccountsPath -Recurse -ErrorAction SilentlyContinue
        foreach ($key in $cacheKeys) {
            $tenantIdValue = Get-ItemProperty -Path $key.PSPath -Name "TenantId" -ErrorAction SilentlyContinue
            if ($tenantIdValue.TenantId -and $tenantIdValue.TenantId -match "^[a-f0-9\-]{36}$") {
                Write-Log "Tenant ID found via IdentityStore Cache: $($tenantIdValue.TenantId)" -Level "INFO"
                return $tenantIdValue.TenantId
            }
        }
    }
    
    return $null
}

function Test-AzureADJoined {
    try {
        $dsregOutput = dsregcmd /status 2>&1 | Out-String
        $azureJoined = $dsregOutput -match "AzureAdJoined\s*:\s*YES"
        $domainJoined = $dsregOutput -match "DomainJoined\s*:\s*YES"
        $workplaceJoined = $dsregOutput -match "WorkplaceJoined\s*:\s*YES"
        
        Write-Log "Device is Azure AD Joined: $azureJoined, Domain Joined: $domainJoined, Workplace Joined: $workplaceJoined" -Level "INFO"
        
        # Accept any of these join types - we just need a way to get tenant ID
        if ($azureJoined -or $domainJoined -or $workplaceJoined) {
            return $true
        }
    }
    catch {
        Write-Log "Failed to check Azure AD join status: $_" -Level "WARN"
    }
    return $false
}

function Set-RegistryValue {
    param(
        [string]$Path,
        [string]$Name,
        [object]$Value,
        [ValidateSet("DWord", "String", "ExpandString", "MultiString", "QWord", "Binary")]
        [string]$Type = "DWord"
    )
    
    try {
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
            Write-Log "Created registry path: $Path" -Level "INFO"
        }
        
        $existing = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
        if ($existing.$Name -eq $Value) {
            Write-Log "Registry value already set: $Name = $Value" -Level "INFO"
            return $false
        }
        
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type
        Write-Log "Set registry value: $Name = $Value" -Level "SUCCESS"
        $Script:ChangesMade = $true
        return $true
    }
    catch {
        Write-Log "Failed to set registry value $Name : $_" -Level "ERROR"
        return $false
    }
}

function Install-OneDrive {
    Write-Log "Checking OneDrive installation..." -Level "INFO"
    
    # Check if OneDrive is already installed (per-machine or per-user locations)
    $installPaths = @(
        "$env:ProgramFiles\Microsoft OneDrive\OneDrive.exe",
        "${env:ProgramFiles(x86)}\Microsoft OneDrive\OneDrive.exe"
    )
    
    foreach ($path in $installPaths) {
        if (Test-Path $path) {
            Write-Log "OneDrive already installed at: $path" -Level "INFO"
            return $true
        }
    }
    
    # Check for built-in setup (always available on Windows 10/11)
    $builtInSetup = "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"
    if (-not (Test-Path $builtInSetup)) {
        $builtInSetup = "$env:SystemRoot\System32\OneDriveSetup.exe"
    }
    
    # Method 1: Try winget (per-machine install)
    $wingetPath = Get-Command winget -ErrorAction SilentlyContinue
    if ($wingetPath) {
        Write-Log "Attempting per-machine installation via winget..." -Level "INFO"
        try {
            $process = Start-Process -FilePath "winget" -ArgumentList "install --id Microsoft.OneDrive --accept-package-agreements --accept-source-agreements --silent --scope machine" -Wait -PassThru -NoNewWindow -RedirectStandardOutput "$env:TEMP\winget_out.txt" -RedirectStandardError "$env:TEMP\winget_err.txt"
            
            if ($process.ExitCode -eq 0) {
                Write-Log "OneDrive installed successfully via winget (per-machine)" -Level "SUCCESS"
                return $true
            }
            else {
                $wingetErr = Get-Content "$env:TEMP\winget_err.txt" -ErrorAction SilentlyContinue
                Write-Log "Winget install returned exit code: $($process.ExitCode). Error: $wingetErr" -Level "WARN"
            }
        }
        catch {
            Write-Log "Winget installation failed: $_" -Level "WARN"
        }
    }
    
    # Method 2: Download and install per-machine from Microsoft
    Write-Log "Attempting download from Microsoft CDN for per-machine install..." -Level "INFO"
    $downloadUrl = "https://go.microsoft.com/fwlink/?linkid=844652"
    $installerPath = "$env:TEMP\OneDriveSetup.exe"
    
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($downloadUrl, $installerPath)
        
        if (Test-Path $installerPath) {
            $result = Start-Process -FilePath $installerPath -ArgumentList "/allusers /silent" -Wait -PassThru
            Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
            
            if ($result.ExitCode -eq 0) {
                Write-Log "OneDrive installed successfully via CDN (per-machine)" -Level "SUCCESS"
                return $true
            }
            Write-Log "CDN installer returned exit code: $($result.ExitCode)" -Level "WARN"
        }
    }
    catch {
        Write-Log "CDN download/install failed: $_" -Level "WARN"
    }
    
    # Method 3: Use built-in setup (will install per-user on next login)
    if (Test-Path $builtInSetup) {
        Write-Log "OneDrive will be installed per-user via built-in setup on user login" -Level "INFO"
        return $true
    }
    
    Write-Log "Could not install OneDrive" -Level "ERROR"
    return $false
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================
Write-Log "========================================" -Level "INFO"
Write-Log "OneDrive Machine Policy Configuration" -Level "INFO"
Write-Log "Running as: $env:USERNAME" -Level "INFO"
Write-Log "Computer: $env:COMPUTERNAME" -Level "INFO"
Write-Log "========================================" -Level "INFO"

try {
    # Verify running with admin rights
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Log "This script must run as Administrator or SYSTEM" -Level "ERROR"
        exit 2
    }
    
    # Step 1: Determine Tenant ID (manual parameter takes priority)
    $effectiveTenantId = $null
    
    if (-not [string]::IsNullOrWhiteSpace($TenantId)) {
        Write-Log "Using manually provided Tenant ID: $TenantId" -Level "INFO"
        $effectiveTenantId = $TenantId
    }
    else {
        Write-Log "No Tenant ID provided, attempting auto-discovery..." -Level "INFO"
        
        # Check Azure AD join status for logging
        $isJoined = Test-AzureADJoined
        
        # Auto-discover Tenant ID
        $effectiveTenantId = Get-AzureTenantId
        
        if (-not $effectiveTenantId) {
            if (-not $isJoined) {
                Write-Log "Device is not Azure AD, Hybrid, or Workplace joined." -Level "WARN"
            }
            Write-Log "Could not auto-discover Azure AD Tenant ID." -Level "ERROR"
            Write-Log "Use -TenantId parameter to specify manually, e.g.: -TenantId 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'" -Level "ERROR"
            Write-Log "Or set TenantId as an environment variable in NinjaRMM script settings." -Level "ERROR"
            exit 2
        }
    }
    
    Write-Log "Using Tenant ID: $effectiveTenantId" -Level "INFO"
    
    # Step 2: Install OneDrive if needed
    if (-not (Install-OneDrive)) {
        Write-Log "OneDrive installation check failed" -Level "WARN"
        # Don't exit - policies can still be set
    }
    
    # Step 3: Configure HKLM Policies
    Write-Log "----------------------------------------" -Level "INFO"
    Write-Log "Configuring Machine Policies..." -Level "INFO"
    Write-Log "----------------------------------------" -Level "INFO"
    
    $policyPath = "HKLM:\SOFTWARE\Policies\Microsoft\OneDrive"
    
    # Create policy path if it doesn't exist
    if (-not (Test-Path $policyPath)) {
        New-Item -Path $policyPath -Force | Out-Null
        Write-Log "Created OneDrive policy path" -Level "INFO"
    }
    
    # Silent Account Configuration - enables auto sign-in with Windows credentials
    Set-RegistryValue -Path $policyPath -Name "SilentAccountConfig" -Value 1 -Type "DWord"
    
    # Silent KFM - automatically moves known folders to OneDrive
    Set-RegistryValue -Path $policyPath -Name "KFMSilentOptIn" -Value $effectiveTenantId -Type "String"
    
    # Show notification after KFM completes
    Set-RegistryValue -Path $policyPath -Name "KFMSilentOptInWithNotification" -Value 1 -Type "DWord"
    
    # Block users from opting out of KFM
    Set-RegistryValue -Path $policyPath -Name "KFMBlockOptOut" -Value 1 -Type "DWord"
    
    # Prompt users if silent KFM fails (fallback)
    Set-RegistryValue -Path $policyPath -Name "KFMOptInWithWizard" -Value $effectiveTenantId -Type "String"
    
    # Enable Files On-Demand by default
    Set-RegistryValue -Path $policyPath -Name "FilesOnDemandEnabled" -Value 1 -Type "DWord"
    
    # Step 4: Verify policies
    Write-Log "----------------------------------------" -Level "INFO"
    Write-Log "Verifying Configured Policies..." -Level "INFO"
    Write-Log "----------------------------------------" -Level "INFO"
    
    $policies = Get-ItemProperty -Path $policyPath -ErrorAction SilentlyContinue
    
    $verification = @{
        SilentAccountConfig = $policies.SilentAccountConfig -eq 1
        KFMSilentOptIn = $policies.KFMSilentOptIn -eq $effectiveTenantId
        KFMBlockOptOut = $policies.KFMBlockOptOut -eq 1
        FilesOnDemandEnabled = $policies.FilesOnDemandEnabled -eq 1
    }
    
    $allPassed = $true
    foreach ($check in $verification.GetEnumerator()) {
        if ($check.Value) {
            Write-Log "$($check.Key): CONFIGURED" -Level "SUCCESS"
        }
        else {
            Write-Log "$($check.Key): NOT CONFIGURED" -Level "ERROR"
            $allPassed = $false
        }
    }
    
    # Output summary
    Write-Host ""
    Write-Host "=== NINJA OUTPUT ==="
    Write-Host "TenantID: $effectiveTenantId"
    Write-Host "SilentAccountConfig: $(if ($verification.SilentAccountConfig) { 'Enabled' } else { 'Failed' })"
    Write-Host "KFMSilentOptIn: $(if ($verification.KFMSilentOptIn) { 'Enabled' } else { 'Failed' })"
    Write-Host "KFMBlockOptOut: $(if ($verification.KFMBlockOptOut) { 'Enabled' } else { 'Failed' })"
    Write-Host "FilesOnDemand: $(if ($verification.FilesOnDemandEnabled) { 'Enabled' } else { 'Failed' })"
    Write-Host "Status: $(if ($allPassed) { 'AllPoliciesConfigured' } else { 'SomePoliciesFailed' })"
    
    if ($allPassed) {
        Write-Log "All machine policies configured successfully" -Level "SUCCESS"
        Write-Log "User-context script can now be run on user login" -Level "INFO"
        exit 0
    }
    else {
        Write-Log "Some policies failed to configure" -Level "ERROR"
        exit 1
    }
}
catch {
    Write-Log "Script execution failed: $_" -Level "ERROR"
    Write-Log $_.ScriptStackTrace -Level "ERROR"
    exit 2
}
