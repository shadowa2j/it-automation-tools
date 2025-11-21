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

.NOTES
    Author: Bryan Faulkner, with assistance from Claude
    Version: 1.0.0
    Requires: Windows 10/11, Run as SYSTEM or Administrator
    Run As: SYSTEM (via NinjaRMM default context)

.OUTPUTS
    Exit 0 = Success - Machine policies configured
    Exit 1 = Partial Success - Some policies set, check output
    Exit 2 = Failed - Could not configure policies
#>

#Requires -Version 5.1
#Requires -RunAsAdministrator

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
            # Use --scope machine for per-machine install
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
            # /allusers flag installs per-machine
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
    
    # Step 1: Check Azure AD join status
    if (-not (Test-AzureADJoined)) {
        Write-Log "Device is not Azure AD or Hybrid joined. Cannot configure OneDrive Business policies." -Level "ERROR"
        exit 2
    }
    
    # Step 2: Get Tenant ID
    $tenantId = Get-AzureTenantId
    if (-not $tenantId) {
        Write-Log "Could not discover Azure AD Tenant ID. Device may not be properly joined." -Level "ERROR"
        exit 2
    }
    Write-Log "Using Tenant ID: $tenantId" -Level "INFO"
    
    # Step 3: Install OneDrive if needed
    if (-not (Install-OneDrive)) {
        Write-Log "OneDrive installation check failed" -Level "WARN"
        # Don't exit - policies can still be set
    }
    
    # Step 4: Configure HKLM Policies
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
    # This is a STRING value containing the tenant ID
    Set-RegistryValue -Path $policyPath -Name "KFMSilentOptIn" -Value $tenantId -Type "String"
    
    # Show notification after KFM completes (optional, set to 0 to hide)
    Set-RegistryValue -Path $policyPath -Name "KFMSilentOptInWithNotification" -Value 1 -Type "DWord"
    
    # Block users from opting out of KFM
    Set-RegistryValue -Path $policyPath -Name "KFMBlockOptOut" -Value 1 -Type "DWord"
    
    # Prompt users if silent KFM fails (fallback)
    Set-RegistryValue -Path $policyPath -Name "KFMOptInWithWizard" -Value $tenantId -Type "String"
    
    # Enable Files On-Demand by default
    Set-RegistryValue -Path $policyPath -Name "FilesOnDemandEnabled" -Value 1 -Type "DWord"
    
    # Optional: Prevent personal OneDrive accounts (uncomment if desired)
    # Set-RegistryValue -Path $policyPath -Name "DisablePersonalSync" -Value 1 -Type "DWord"
    
    # Optional: Set default OneDrive folder location (uncomment and modify if desired)
    # Set-RegistryValue -Path $policyPath -Name "DefaultRootDir" -Value "%UserProfile%\OneDrive - CompanyName" -Type "String"
    
    # Step 5: Verify policies
    Write-Log "----------------------------------------" -Level "INFO"
    Write-Log "Verifying Configured Policies..." -Level "INFO"
    Write-Log "----------------------------------------" -Level "INFO"
    
    $policies = Get-ItemProperty -Path $policyPath -ErrorAction SilentlyContinue
    
    $verification = @{
        SilentAccountConfig = $policies.SilentAccountConfig -eq 1
        KFMSilentOptIn = $policies.KFMSilentOptIn -eq $tenantId
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
    Write-Host "TenantID: $tenantId"
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
