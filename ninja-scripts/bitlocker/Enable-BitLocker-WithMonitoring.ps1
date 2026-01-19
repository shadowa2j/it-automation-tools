<#
.SYNOPSIS
    Enable BitLocker with decryption monitoring and automatic backup to AD/Azure/Ninja

.DESCRIPTION
    This script enables BitLocker encryption on Windows devices with the following features:
    - Monitors and waits for in-progress decryption to complete
    - Configures TPM and BitLocker partitioning as needed
    - Sets registry policies for AD backup requirements
    - Backs up recovery keys to Active Directory, Azure AD, and Ninja RMM
    - Provides detailed logging for monitoring and troubleshooting

.NOTES
    File Name      : Enable-BitLocker-WithMonitoring.ps1
    Author         : Bryan Faulkner - Quality Computer Solutions
    Version        : 2.0.0
    Created        : 2026-01-19
    Last Modified  : 2026-01-19
    
    Requirements:
    - Windows 10/11 or Server 2012 R2+
    - TPM 1.2 or higher
    - Administrator privileges
    - Domain-joined or Azure AD-joined (for backups)
    - NinjaRMM agent installed

.PARAMETER CheckIntervalSeconds
    How often to check decryption progress (default: 60 seconds)

.PARAMETER MaxWaitHours
    Maximum time to wait for decryption to complete (default: 4 hours)

.EXAMPLE
    .\Enable-BitLocker-WithMonitoring.ps1
    Runs with default settings (60s interval, 4hr timeout)

.EXAMPLE
    .\Enable-BitLocker-WithMonitoring.ps1 -CheckIntervalSeconds 30 -MaxWaitHours 8
    Checks every 30 seconds with 8 hour timeout

#>

#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [int]$CheckIntervalSeconds = 60,
    
    [Parameter(Mandatory=$false)]
    [int]$MaxWaitHours = 4
)

#region Configuration
$Script:ScriptVersion = "2.0.0"
$Script:MaxWaitSeconds = $MaxWaitHours * 3600
$Script:StartTime = Get-Date
#endregion

#region Function: Write-NinjaLog
function Write-NinjaLog {
    <#
    .SYNOPSIS
        Writes formatted output that Ninja RMM can parse and display properly
    #>
    param(
        [Parameter(Mandatory=$true)]
        [AllowEmptyString()]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('Info','Success','Warning','Error')]
        [string]$Level = 'Info'
    )
    
    # Handle empty strings by outputting a blank line
    if ([string]::IsNullOrWhiteSpace($Message)) {
        Write-Output ""
        return
    }
    
    $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    
    switch ($Level) {
        'Success' { 
            Write-Output "[$Timestamp] SUCCESS: $Message"
        }
        'Warning' { 
            Write-Warning "[$Timestamp] WARNING: $Message"
        }
        'Error' { 
            Write-Error "[$Timestamp] ERROR: $Message"
        }
        default { 
            Write-Output "[$Timestamp] $Message"
        }
    }
}
#endregion

#region Function: Wait-BitLockerDecryption
function Wait-BitLockerDecryption {
    <#
    .SYNOPSIS
        Monitors BitLocker decryption progress and waits for completion
    #>
    param(
        [string]$MountPoint = $env:SystemDrive,
        [int]$CheckInterval = 60,
        [int]$MaxWait = 14400
    )
    
    $FunctionStart = Get-Date
    
    try {
        $Volume = Get-BitLockerVolume -MountPoint $MountPoint -ErrorAction Stop
    }
    catch {
        Write-NinjaLog -Message "Unable to retrieve BitLocker volume information for $MountPoint" -Level Error
        Write-NinjaLog -Message "Error details: $_" -Level Error
        return $false
    }
    
    $Status = $Volume.VolumeStatus
    Write-NinjaLog -Message "Current volume status: $Status"
    
    # If already decrypted, we're good to proceed
    if ($Status -eq "FullyDecrypted") {
        Write-NinjaLog -Message "Volume is fully decrypted - ready to enable BitLocker" -Level Success
        return $true
    }
    
    # If decryption in progress, monitor it
    if ($Status -eq "DecryptionInProgress") {
        Write-NinjaLog -Message "Decryption in progress - beginning monitoring loop" -Level Info
        Write-NinjaLog -Message "Check interval: $CheckInterval seconds | Timeout: $([Math]::Round($MaxWait/3600, 1)) hours"
        
        $IterationCount = 0
        
        while ($true) {
            $IterationCount++
            
            try {
                $Volume = Get-BitLockerVolume -MountPoint $MountPoint -ErrorAction Stop
                $Status = $Volume.VolumeStatus
                $EncryptionPercentage = $Volume.EncryptionPercentage
                $ElapsedMinutes = [Math]::Round(((Get-Date) - $FunctionStart).TotalMinutes, 1)
                
                Write-NinjaLog -Message "Check #$IterationCount | Status: $Status | Encrypted: $EncryptionPercentage% | Elapsed: $ElapsedMinutes min"
                
                # Check if decryption complete
                if ($Status -eq "FullyDecrypted") {
                    Write-NinjaLog -Message "Decryption completed successfully after $ElapsedMinutes minutes" -Level Success
                    return $true
                }
                
                # Check timeout
                $ElapsedSeconds = ((Get-Date) - $FunctionStart).TotalSeconds
                if ($ElapsedSeconds -ge $MaxWait) {
                    $ElapsedHours = [Math]::Round($ElapsedSeconds / 3600, 1)
                    Write-NinjaLog -Message "Timeout reached after $ElapsedHours hours - decryption still in progress at $EncryptionPercentage%" -Level Warning
                    Write-NinjaLog -Message "Script will need to be run again once decryption completes" -Level Warning
                    return $false
                }
                
                # Wait before next check
                Start-Sleep -Seconds $CheckInterval
            }
            catch {
                Write-NinjaLog -Message "Error during decryption monitoring: $_" -Level Error
                return $false
            }
        }
    }
    
    # If encryption in progress, we shouldn't proceed
    if ($Status -eq "EncryptionInProgress") {
        Write-NinjaLog -Message "Volume is currently encrypting - script should not run" -Level Warning
        return $false
    }
    
    # If encryption paused, we shouldn't proceed
    if ($Status -eq "EncryptionPaused") {
        Write-NinjaLog -Message "Volume encryption is paused - resume or disable BitLocker first" -Level Warning
        return $false
    }
    
    # If decryption paused, we shouldn't proceed
    if ($Status -eq "DecryptionPaused") {
        Write-NinjaLog -Message "Volume decryption is paused - resume decryption first" -Level Warning
        return $false
    }
    
    # Unknown status
    Write-NinjaLog -Message "Unknown volume status encountered: $Status" -Level Warning
    return $false
}
#endregion

#region Script Start
Write-NinjaLog -Message "========================================" 
Write-NinjaLog -Message "BitLocker Enable Script v$Script:ScriptVersion"
Write-NinjaLog -Message "Author: Bryan Faulkner - Quality Computer Solutions"
Write-NinjaLog -Message "Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-NinjaLog -Message "========================================"
#endregion

#region Prerequisites Check
Write-NinjaLog -Message "STEP 1: Checking prerequisites..."

try {
    $TPMNotEnabled = Get-WmiObject win32_tpm -Namespace root\cimv2\security\microsofttpm -ErrorAction Stop | 
        Where-Object {$_.IsEnabled_InitialValue -eq $false}
    $TPMEnabled = Get-WmiObject win32_tpm -Namespace root\cimv2\security\microsofttpm -ErrorAction Stop | 
        Where-Object {$_.IsEnabled_InitialValue -eq $true}
}
catch {
    Write-NinjaLog -Message "Unable to query TPM status - TPM may not be present" -Level Warning
    Write-NinjaLog -Message "Error: $_" -Level Error
    $TPMEnabled = $null
}

try {
    $WindowsVer = Get-WmiObject -Query 'select * from Win32_OperatingSystem where (Version like "6.2%" or Version like "6.3%" or Version like "10.0%") and ProductType = "1"' -ErrorAction Stop
    if ($WindowsVer) {
        $OSVersion = $WindowsVer.Caption
        Write-NinjaLog -Message "Operating System: $OSVersion" -Level Success
    }
    else {
        Write-NinjaLog -Message "Unsupported Windows version detected" -Level Error
        exit 1
    }
}
catch {
    Write-NinjaLog -Message "Unable to determine Windows version: $_" -Level Error
    exit 1
}

try {
    $BitLockerReadyDrive = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction Stop
    if ($BitLockerReadyDrive) {
        Write-NinjaLog -Message "BitLocker volume found for $env:SystemDrive" -Level Success
    }
}
catch {
    Write-NinjaLog -Message "Unable to query BitLocker volume: $_" -Level Error
    $BitLockerReadyDrive = $null
}
#endregion

#region SAFETY CHECK - Detect Already-Enabled or In-Progress BitLocker
Write-NinjaLog -Message "STEP 2: SAFETY CHECK - Verifying it's safe to enable BitLocker..."

try {
    $CurrentVolume = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction Stop
    $CurrentStatus = $CurrentVolume.VolumeStatus
    $ProtectionStatus = $CurrentVolume.ProtectionStatus
    $EncryptionPercentage = $CurrentVolume.EncryptionPercentage
    
    Write-NinjaLog -Message "Current Status: $CurrentStatus | Protection: $ProtectionStatus | Encrypted: $EncryptionPercentage%"
}
catch {
    Write-NinjaLog -Message "Unable to query BitLocker volume status: $_" -Level Error
    Write-NinjaLog -Message "Script cannot safely proceed without volume information" -Level Error
    exit 1
}

# SAFETY CHECK 1: BitLocker already fully enabled and protecting
if ($CurrentStatus -eq "FullyEncrypted") {
    # Check if protection is actually ON and key protectors exist
    $HasTPMProtector = $CurrentVolume.KeyProtector | Where-Object {$_.KeyProtectorType -eq 'Tpm'}
    $HasRecoveryPassword = $CurrentVolume.KeyProtector | Where-Object {$_.KeyProtectorType -eq 'RecoveryPassword'}
    
    if ($ProtectionStatus -eq "On" -and ($HasTPMProtector -or $HasRecoveryPassword)) {
        Write-NinjaLog -Message "SAFE EXIT: BitLocker is already fully enabled and protecting this drive" -Level Success
        Write-NinjaLog -Message "No action needed - device is already compliant"
        
        # Still backup keys if they exist
        Write-NinjaLog -Message "Verifying recovery key backups are current..."
        
        if ($HasRecoveryPassword) {
            Write-NinjaLog -Message "Recovery password exists - performing backup verification only"
            # Jump to backup steps at end
            $Script:SkipToBackup = $true
        }
        else {
            Write-NinjaLog -Message "No recovery password found (TPM-only protection) - this is acceptable" -Level Info
            exit 0
        }
    }
    # SPECIAL CASE: Encrypted but Protection OFF or No Key Protectors (common after fresh Windows install)
    elseif ($ProtectionStatus -eq "Off" -or (-not $HasTPMProtector -and -not $HasRecoveryPassword)) {
        Write-NinjaLog -Message "Drive is pre-encrypted but key protectors not yet configured" -Level Info
        Write-NinjaLog -Message "This is normal for fresh Windows installations with device encryption" -Level Info
        Write-NinjaLog -Message "Current State:" -Level Info
        Write-NinjaLog -Message "  Protection Status: $ProtectionStatus" -Level Info
        Write-NinjaLog -Message "  TPM Protector: $(if($HasTPMProtector){'Present'}else{'Not configured'})" -Level Info
        Write-NinjaLog -Message "  Recovery Password: $(if($HasRecoveryPassword){'Present'}else{'Not configured'})" -Level Info
        Write-NinjaLog -Message "Proceeding to add key protectors and enable protection..." -Level Info
        
        # Set flag to add key protectors to already-encrypted volume
        $Script:ConfigurePreEncryptedDrive = $true
    }
    # Edge case: Protection On but no key protectors (shouldn't be possible, but check anyway)
    else {
        Write-NinjaLog -Message "UNUSUAL STATE: Protection is On but key protectors are missing" -Level Warning
        Write-NinjaLog -Message "This should not normally occur - will attempt to add key protectors" -Level Warning
        $Script:ConfigurePreEncryptedDrive = $true
    }
}
# SAFETY CHECK 2: BitLocker encryption currently in progress
elseif ($CurrentStatus -eq "EncryptionInProgress") {
    Write-NinjaLog -Message "SAFE EXIT: BitLocker encryption is currently in progress ($EncryptionPercentage% complete)" -Level Info
    Write-NinjaLog -Message "Script will not interfere with active encryption process" -Level Info
    Write-NinjaLog -Message "No action taken - encryption will complete in background"
    exit 0
}
# SAFETY CHECK 3: BitLocker encryption paused
elseif ($CurrentStatus -eq "EncryptionPaused") {
    Write-NinjaLog -Message "SAFE EXIT: BitLocker encryption is paused at $EncryptionPercentage%" -Level Info
    Write-NinjaLog -Message "Encryption can be resumed with: Resume-BitLocker -MountPoint $env:SystemDrive" -Level Info
    Write-NinjaLog -Message "Script will not modify paused encryption state"
    exit 0
}
# SAFETY CHECK 4: BitLocker decryption paused
elseif ($CurrentStatus -eq "DecryptionPaused") {
    Write-NinjaLog -Message "SAFE EXIT: BitLocker decryption is paused at $EncryptionPercentage% encrypted" -Level Info
    Write-NinjaLog -Message "Decryption can be resumed or encryption re-enabled manually" -Level Info
    Write-NinjaLog -Message "Script will not modify paused decryption state"
    exit 0
}
# SAFETY CHECK 5: BitLocker decryption in progress - MONITOR IT
elseif ($CurrentStatus -eq "DecryptionInProgress") {
    Write-NinjaLog -Message "Decryption in progress detected - entering monitoring mode" -Level Info
    
    $ReadyToProceed = Wait-BitLockerDecryption -MountPoint $env:SystemDrive -CheckInterval $CheckIntervalSeconds -MaxWait $Script:MaxWaitSeconds
    
    if (-not $ReadyToProceed) {
        Write-NinjaLog -Message "Cannot proceed with BitLocker enablement - see previous messages for details" -Level Warning
        Write-NinjaLog -Message "Script completed with exit code 0 (no error, but no action taken)"
        exit 0
    }
}
# SAFETY CHECK 6: Volume is fully decrypted - SAFE TO ENABLE
elseif ($CurrentStatus -eq "FullyDecrypted") {
    Write-NinjaLog -Message "Volume is fully decrypted - safe to enable BitLocker" -Level Success
}
# SAFETY CHECK 7: Unknown status
else {
    Write-NinjaLog -Message "Unexpected volume status detected: $CurrentStatus" -Level Warning
    Write-NinjaLog -Message "Script will not proceed with unknown volume state" -Level Warning
    exit 0
}

# If we have SkipToBackup flag, jump to backup region
if ($Script:SkipToBackup) {
    Write-NinjaLog -Message "Skipping enablement steps - proceeding to key backup verification..."
}
#endregion

#region Step 3 - Initialize TPM if needed
if ($Script:SkipToBackup) {
    Write-NinjaLog -Message "STEP 3: Skipping (BitLocker already enabled)"
}
else {
    Write-NinjaLog -Message "STEP 3: TPM initialization check..."

    if ($WindowsVer -and $TPMNotEnabled) 
    {
        Write-NinjaLog -Message "TPM is present but not enabled - attempting to initialize..."
        try {
            Initialize-Tpm -AllowClear -AllowPhysicalPresence -ErrorAction Stop
            Write-NinjaLog -Message "TPM initialized successfully" -Level Success
        }
        catch {
            Write-NinjaLog -Message "TPM initialization failed: $_" -Level Error
            Write-NinjaLog -Message "Manual intervention may be required in BIOS/UEFI" -Level Warning
        }
    }
    elseif ($TPMEnabled) {
        Write-NinjaLog -Message "TPM is already enabled and ready" -Level Success
    }
    else {
        Write-NinjaLog -Message "TPM status could not be determined or TPM is not present" -Level Warning
    }
}
#endregion

#region Step 4 - Provision BitLocker partition
if ($Script:SkipToBackup) {
    Write-NinjaLog -Message "STEP 4: Skipping (BitLocker already enabled)"
}
else {
    Write-NinjaLog -Message "STEP 4: BitLocker partition provisioning check..."

    if ($WindowsVer -and $TPMEnabled -and -not $BitLockerReadyDrive) 
    {
        Write-NinjaLog -Message "BitLocker partition not found - provisioning system drive..."
        try {
            # Ensure defrag service is running
            $DefragService = Get-Service -Name defragsvc -ErrorAction SilentlyContinue
            if ($DefragService -and $DefragService.Status -ne 'Running') {
                Write-NinjaLog -Message "Starting Defragmentation service..."
                Set-Service -Name defragsvc -Status Running -ErrorAction Stop
            }
            
            Write-NinjaLog -Message "Running BdeHdCfg to create BitLocker partition..."
            $BdeResult = BdeHdCfg -target $env:SystemDrive shrink -quiet 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-NinjaLog -Message "BitLocker partition created successfully" -Level Success
            }
            else {
                Write-NinjaLog -Message "BdeHdCfg returned exit code: $LASTEXITCODE" -Level Warning
                Write-NinjaLog -Message "Output: $BdeResult" -Level Warning
            }
        }
        catch {
            Write-NinjaLog -Message "Partition provisioning failed: $_" -Level Error
            exit 1
        }
    }
    else {
        Write-NinjaLog -Message "BitLocker partition already exists or was created during OS install" -Level Success
    }
}
#endregion

#region Step 5 - Configure BitLocker registry settings
Write-NinjaLog -Message "STEP 5: Configuring BitLocker registry policies..."

$BitLockerRegLoc = 'HKLM:\SOFTWARE\Policies\Microsoft'

if (Test-Path "$BitLockerRegLoc\FVE") {
    Write-NinjaLog -Message "BitLocker registry policies already configured" -Level Success
}
else {
    Write-NinjaLog -Message "Creating BitLocker registry configuration for AD backup and encryption settings..."
    
    try {
        New-Item -Path "$BitLockerRegLoc" -Name 'FVE' -Force -ErrorAction Stop | Out-Null
        Write-NinjaLog -Message "Created FVE registry key"
        
        # Create registry values with error handling
        $RegValues = @{
            'ActiveDirectoryBackup' = '00000001'
            'RequireActiveDirectoryBackup' = '00000001'
            'ActiveDirectoryInfoToStore' = '00000001'
            'EncryptionMethodNoDiffuser' = '00000003'
            'EncryptionMethodWithXtsOs' = '00000006'
            'EncryptionMethodWithXtsFdv' = '00000006'
            'EncryptionMethodWithXtsRdv' = '00000003'
            'EncryptionMethod' = '00000003'
            'OSRecovery' = '00000001'
            'OSManageDRA' = '00000000'
            'OSRecoveryPassword' = '00000002'
            'OSRecoveryKey' = '00000002'
            'OSHideRecoveryPage' = '00000001'
            'OSActiveDirectoryBackup' = '00000001'
            'OSActiveDirectoryInfoToStore' = '00000001'
            'OSRequireActiveDirectoryBackup' = '00000001'
            'OSAllowSecureBootForIntegrity' = '00000001'
            'OSEncryptionType' = '00000001'
            'FDVRecovery' = '00000001'
            'FDVManageDRA' = '00000000'
            'FDVRecoveryPassword' = '00000002'
            'FDVRecoveryKey' = '00000002'
            'FDVHideRecoveryPage' = '00000001'
            'FDVActiveDirectoryBackup' = '00000001'
            'FDVActiveDirectoryInfoToStore' = '00000001'
            'FDVRequireActiveDirectoryBackup' = '00000001'
            'FDVEncryptionType' = '00000001'
        }
        
        $ValueCount = 0
        foreach ($Name in $RegValues.Keys) {
            New-ItemProperty -Path "$BitLockerRegLoc\FVE" -Name $Name -Value $RegValues[$Name] -PropertyType DWORD -Force -ErrorAction Stop | Out-Null
            $ValueCount++
        }
        
        Write-NinjaLog -Message "Created $ValueCount registry values successfully" -Level Success
    }
    catch {
        Write-NinjaLog -Message "Registry configuration failed: $_" -Level Error
        exit 1
    }
}
#endregion

#region Step 6 - Enable BitLocker or Configure Pre-Encrypted Drive
if ($Script:SkipToBackup) {
    Write-NinjaLog -Message "STEP 6: Skipping (BitLocker already properly configured) - proceeding to backup verification"
}
elseif ($Script:ConfigurePreEncryptedDrive) {
    Write-NinjaLog -Message "STEP 6: Configuring key protectors on pre-encrypted volume..."
    
    # Volume is already encrypted, need to add key protectors and enable protection
    try {
        # SAFETY: Re-verify the volume is actually encrypted before proceeding
        $CurrentVolume = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction Stop
        
        if ($CurrentVolume.VolumeStatus -ne "FullyEncrypted") {
            Write-NinjaLog -Message "SAFETY ABORT: Volume status changed to $($CurrentVolume.VolumeStatus)" -Level Error
            Write-NinjaLog -Message "Expected FullyEncrypted - will not proceed for safety" -Level Error
            exit 1
        }
        
        $HasTPMProtector = $CurrentVolume.KeyProtector | Where-Object {$_.KeyProtectorType -eq 'Tpm'}
        $HasRecoveryPassword = $CurrentVolume.KeyProtector | Where-Object {$_.KeyProtectorType -eq 'RecoveryPassword'}
        
        # Add TPM protector if missing and TPM is available
        if (-not $HasTPMProtector -and $TPMEnabled) {
            Write-NinjaLog -Message "Adding TPM key protector..."
            try {
                Add-BitLockerKeyProtector -MountPoint $env:SystemDrive -TpmProtector -ErrorAction Stop
                Write-NinjaLog -Message "TPM protector added successfully" -Level Success
                
                # Verify it was actually added
                $VerifyVolume = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction Stop
                $VerifyTPM = $VerifyVolume.KeyProtector | Where-Object {$_.KeyProtectorType -eq 'Tpm'}
                if (-not $VerifyTPM) {
                    Write-NinjaLog -Message "WARNING: TPM protector add reported success but not found on volume" -Level Warning
                }
            }
            catch {
                Write-NinjaLog -Message "Failed to add TPM protector: $_" -Level Error
                Write-NinjaLog -Message "This may prevent BitLocker from working properly" -Level Error
                exit 1
            }
        }
        elseif (-not $TPMEnabled) {
            Write-NinjaLog -Message "TPM not available - skipping TPM protector (will use recovery password only)" -Level Warning
        }
        else {
            Write-NinjaLog -Message "TPM protector already present" -Level Info
        }
        
        # Add recovery password if missing (CRITICAL - always need this)
        if (-not $HasRecoveryPassword) {
            Write-NinjaLog -Message "Adding recovery password protector..."
            try {
                Add-BitLockerKeyProtector -MountPoint $env:SystemDrive -RecoveryPasswordProtector -ErrorAction Stop
                Write-NinjaLog -Message "Recovery password protector added successfully" -Level Success
                
                # Verify it was actually added
                $VerifyVolume = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction Stop
                $VerifyRecovery = $VerifyVolume.KeyProtector | Where-Object {$_.KeyProtectorType -eq 'RecoveryPassword'}
                if (-not $VerifyRecovery) {
                    Write-NinjaLog -Message "CRITICAL ERROR: Recovery password add reported success but not found on volume" -Level Error
                    exit 1
                }
            }
            catch {
                Write-NinjaLog -Message "CRITICAL: Failed to add recovery password protector: $_" -Level Error
                Write-NinjaLog -Message "Cannot proceed without recovery password" -Level Error
                exit 1
            }
        }
        else {
            Write-NinjaLog -Message "Recovery password protector already present" -Level Info
        }
        
        # Enable protection if it's off
        $UpdatedVolume = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction Stop
        if ($UpdatedVolume.ProtectionStatus -eq "Off") {
            Write-NinjaLog -Message "Enabling BitLocker protection..."
            try {
                # Use Resume-BitLocker first (proper method for already-encrypted drives)
                Resume-BitLocker -MountPoint $env:SystemDrive -ErrorAction Stop
                Write-NinjaLog -Message "BitLocker protection enabled via Resume-BitLocker" -Level Success
            }
            catch {
                Write-NinjaLog -Message "Resume-BitLocker failed: $_" -Level Warning
                Write-NinjaLog -Message "Attempting alternative method with Enable-BitLocker..." -Level Info
                try {
                    # Skip hardware test since drive is already encrypted
                    Enable-BitLocker -MountPoint $env:SystemDrive -SkipHardwareTest -ErrorAction Stop
                    Write-NinjaLog -Message "Protection enabled via Enable-BitLocker" -Level Success
                }
                catch {
                    Write-NinjaLog -Message "CRITICAL: Both methods to enable protection failed: $_" -Level Error
                    Write-NinjaLog -Message "Key protectors are added but protection is not enabled" -Level Error
                    exit 1
                }
            }
        }
        else {
            Write-NinjaLog -Message "Protection is already enabled" -Level Info
        }
        
        # Wait for changes to fully apply
        Start-Sleep -Seconds 5
        
        # CRITICAL: Verify the final state
        $FinalCheck = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction Stop
        Write-NinjaLog -Message "Final Configuration Verification:" -Level Info
        Write-NinjaLog -Message "  Volume Status: $($FinalCheck.VolumeStatus)" -Level Info
        Write-NinjaLog -Message "  Protection Status: $($FinalCheck.ProtectionStatus)" -Level Info
        Write-NinjaLog -Message "  Encryption Percentage: $($FinalCheck.EncryptionPercentage)%" -Level Info
        
        $FinalTPM = $FinalCheck.KeyProtector | Where-Object {$_.KeyProtectorType -eq 'Tpm'}
        $FinalRecovery = $FinalCheck.KeyProtector | Where-Object {$_.KeyProtectorType -eq 'RecoveryPassword'}
        Write-NinjaLog -Message "  TPM Protector: $(if($FinalTPM){'Present'}else{'Not Present'})" -Level Info
        Write-NinjaLog -Message "  Recovery Password: $(if($FinalRecovery){'Present'}else{'NOT PRESENT - ERROR'})" -Level Info
        
        # Validate success criteria
        if ($FinalCheck.ProtectionStatus -ne "On") {
            Write-NinjaLog -Message "ERROR: Protection status is $($FinalCheck.ProtectionStatus) instead of On" -Level Error
            exit 1
        }
        
        if (-not $FinalRecovery) {
            Write-NinjaLog -Message "CRITICAL ERROR: No recovery password found after configuration" -Level Error
            exit 1
        }
        
        Write-NinjaLog -Message "Pre-encrypted drive configuration completed successfully" -Level Success
    }
    catch {
        Write-NinjaLog -Message "ERROR during pre-encrypted drive configuration: $_" -Level Error
        Write-NinjaLog -Message "Stack trace: $($_.ScriptStackTrace)" -Level Error
        exit 1
    }
}
else {
    Write-NinjaLog -Message "STEP 6: Enabling BitLocker encryption on decrypted drive..."

    # SAFETY: Re-check volume status to ensure it's still safe to encrypt
    try {
        $BitLockerVolume = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction Stop
        $CurrentStatus = $BitLockerVolume.VolumeStatus
        
        # SAFETY: Don't proceed if status changed since our initial check
        if ($CurrentStatus -ne "FullyDecrypted") {
            Write-NinjaLog -Message "SAFETY ABORT: Volume status changed to $CurrentStatus" -Level Error
            Write-NinjaLog -Message "Expected FullyDecrypted - aborting for safety" -Level Error
            exit 0
        }
        
        $BitLockerDecrypted = $BitLockerVolume | Where-Object {$_.VolumeStatus -eq "FullyDecrypted"}
    }
    catch {
        Write-NinjaLog -Message "Failed to query BitLocker volume status: $_" -Level Error
        exit 1
    }

    if ($WindowsVer -and $TPMEnabled -and $BitLockerReadyDrive -and $BitLockerDecrypted) 
    {
        Write-NinjaLog -Message "All prerequisites met - enabling BitLocker on $env:SystemDrive..."
        
        try {
            # Add TPM protector first
            Write-NinjaLog -Message "Adding TPM key protector..."
            Add-BitLockerKeyProtector -MountPoint $env:SystemDrive -TpmProtector -ErrorAction Stop
            Write-NinjaLog -Message "TPM protector added successfully" -Level Success
            
            # Verify TPM protector
            $VerifyVolume = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction Stop
            $VerifyTPM = $VerifyVolume.KeyProtector | Where-Object {$_.KeyProtectorType -eq 'Tpm'}
            if (-not $VerifyTPM) {
                Write-NinjaLog -Message "ERROR: TPM protector not found after adding" -Level Error
                exit 1
            }
            
            # Enable BitLocker with recovery password
            Write-NinjaLog -Message "Enabling BitLocker with recovery password protector..."
            Enable-BitLocker -MountPoint $env:SystemDrive -RecoveryPasswordProtector -ErrorAction Stop
            Write-NinjaLog -Message "BitLocker enabled successfully - encryption will begin in background" -Level Success
            
            # Give BitLocker time to generate recovery password
            Start-Sleep -Seconds 5
            
            # Verify recovery password was created
            $VerifyVolume = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction Stop
            $VerifyRecovery = $VerifyVolume.KeyProtector | Where-Object {$_.KeyProtectorType -eq 'RecoveryPassword'}
            if (-not $VerifyRecovery) {
                Write-NinjaLog -Message "CRITICAL ERROR: Recovery password not found after enabling BitLocker" -Level Error
                exit 1
            }
            
            Write-NinjaLog -Message "Recovery password generated successfully" -Level Success
        }
        catch {
            Write-NinjaLog -Message "Failed to enable BitLocker: $_" -Level Error
            Write-NinjaLog -Message "Stack trace: $($_.ScriptStackTrace)" -Level Error
            exit 1
        }
    }
    else {
        Write-NinjaLog -Message "Prerequisites not met for BitLocker enablement:" -Level Error
        if (-not $WindowsVer) { Write-NinjaLog -Message "  - Windows version not supported" -Level Error }
        if (-not $TPMEnabled) { Write-NinjaLog -Message "  - TPM not enabled" -Level Error }
        if (-not $BitLockerReadyDrive) { Write-NinjaLog -Message "  - Drive not ready for BitLocker" -Level Error }
        if (-not $BitLockerDecrypted) { Write-NinjaLog -Message "  - Drive not in FullyDecrypted state (current: $CurrentStatus)" -Level Error }
        exit 1
    }
}
#endregion

#region Step 7 - Backup recovery passwords to Active Directory
Write-NinjaLog -Message "STEP 7: Backing up recovery keys to Active Directory..."

# Wait for key protectors to be fully generated
Start-Sleep -Seconds 5

try {
    $BLVS = Get-BitLockerVolume -ErrorAction Stop | 
        Where-Object {$_.KeyProtector | Where-Object {$_.KeyProtectorType -eq 'RecoveryPassword'}}
}
catch {
    Write-NinjaLog -Message "Failed to query BitLocker volumes: $_" -Level Error
    $BLVS = $null
}

if ($BLVS) 
{
    $BackupCount = 0
    $FailCount = 0
    
    foreach ($BLV in $BLVS) 
    {
        $Keys = $BLV | Select-Object -ExpandProperty KeyProtector | 
            Where-Object {$_.KeyProtectorType -eq 'RecoveryPassword'}
        
        foreach ($Key in $Keys)
        { 
            try {
                Backup-BitLockerKeyProtector -MountPoint $BLV.MountPoint -KeyProtectorID $Key.KeyProtectorId -ErrorAction Stop
                Write-NinjaLog -Message "Backed up recovery key for $($BLV.MountPoint) (ID: $($Key.KeyProtectorId))" -Level Success
                $BackupCount++
            }
            catch {
                Write-NinjaLog -Message "Failed to backup key for $($BLV.MountPoint): $_" -Level Warning
                $FailCount++
            }
        }
    }
    
    Write-NinjaLog -Message "AD Backup Summary: $BackupCount succeeded, $FailCount failed" -Level Info
}
else {
    Write-NinjaLog -Message "No recovery passwords found to backup to AD" -Level Warning
}
#endregion

#region Step 8 - Backup to Ninja Custom Field
Write-NinjaLog -Message "STEP 8: Backing up recovery key to Ninja RMM custom field..."

try {
    $RecoveryPasswords = (Get-BitLockerVolume -MountPoint C: -ErrorAction Stop).KeyProtector | 
        Where-Object {$_.KeyProtectorType -eq 'RecoveryPassword'} | 
        Select-Object -ExpandProperty RecoveryPassword
    
    if ($RecoveryPasswords) {
        # Join multiple passwords with semicolon if multiple exist
        $RecoveryKey = $RecoveryPasswords -join '; '
        
        # Ninja RMM custom field update
        Ninja-Property-Set "bitlockerrecoverykey" "$RecoveryKey"
        
        Write-NinjaLog -Message "Recovery key saved to Ninja custom field 'bitlockerrecoverykey'" -Level Success
        Write-NinjaLog -Message "Key count: $($RecoveryPasswords.Count)" -Level Info
    }
    else {
        Write-NinjaLog -Message "No recovery passwords found for C: drive" -Level Warning
    }
}
catch {
    Write-NinjaLog -Message "Failed to save BitLocker key to Ninja: $_" -Level Warning
}
#endregion

#region Step 9 - Backup to Azure AD
Write-NinjaLog -Message "STEP 9: Backing up recovery key to Azure AD..."

try {
    $KeyProtectorId = ((Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction Stop).KeyProtector | 
        Where-Object {$_.KeyProtectorType -eq "RecoveryPassword"} | 
        Select-Object -First 1).KeyProtectorId
    
    if ($KeyProtectorId) {
        BackupToAAD-BitLockerKeyProtector -MountPoint $env:SystemDrive -KeyProtectorId $KeyProtectorId -ErrorAction Stop
        Write-NinjaLog -Message "Recovery key backed up to Azure AD successfully" -Level Success
    }
    else {
        Write-NinjaLog -Message "No recovery password key protector found for Azure AD backup" -Level Warning
    }
}
catch {
    Write-NinjaLog -Message "Failed to backup BitLocker key to Azure AD: $_" -Level Warning
    Write-NinjaLog -Message "This is expected if device is not Azure AD joined" -Level Info
}
#endregion

#region Script Complete
$TotalRuntime = [Math]::Round(((Get-Date) - $Script:StartTime).TotalMinutes, 2)

Write-NinjaLog -Message "========================================"
Write-NinjaLog -Message "BitLocker Enable Script Complete"
Write-NinjaLog -Message "Total runtime: $TotalRuntime minutes"
Write-NinjaLog -Message "Finished: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-NinjaLog -Message "========================================"

# Verify final encryption status
try {
    $FinalStatus = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction Stop
    Write-NinjaLog -Message "Final volume status: $($FinalStatus.VolumeStatus)" -Level Info
    Write-NinjaLog -Message "Encryption percentage: $($FinalStatus.EncryptionPercentage)%" -Level Info
    Write-NinjaLog -Message "Protection status: $($FinalStatus.ProtectionStatus)" -Level Info
}
catch {
    Write-NinjaLog -Message "Could not retrieve final status: $_" -Level Warning
}

exit 0
#endregion
