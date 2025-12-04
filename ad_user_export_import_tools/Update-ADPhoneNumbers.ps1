<#
.SYNOPSIS
    Updates AD user phone numbers (Office and Mobile) from CSV export
    
.DESCRIPTION
    Reads the updated phone numbers CSV and updates Active Directory users'
    OfficePhone and MobilePhone attributes. Includes WhatIf support, detailed
    logging, and comprehensive error handling.
    
.PARAMETER CSVPath
    Path to the CSV file containing updated phone numbers
    
.PARAMETER LogPath
    Path where the log file will be saved. Defaults to script directory with timestamp.
    
.PARAMETER WhatIf
    Preview changes without actually updating AD
    
.EXAMPLE
    .\Update-ADPhoneNumbers.ps1 -CSVPath "C:\scripts\WilbertUsers_PhoneNumbers_Updated.csv" -WhatIf
    
.EXAMPLE
    .\Update-ADPhoneNumbers.ps1 -CSVPath "C:\scripts\WilbertUsers_PhoneNumbers_Updated.csv"

.NOTES
    Author: Bryan
    Company: Quality Computer Solutions
    Version: 1.0.0
    Last Modified: 2025-12-04
    
    Version History:
    1.0.0 - Initial release
        - Support for OfficePhone and MobilePhone updates
        - WhatIf support for testing
        - Detailed logging with timestamps
        - Error handling and summary statistics
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$CSVPath,
    
    [Parameter()]
    [string]$LogPath = ".\ADPhoneUpdate_Log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
)

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('Info','Success','Warning','Error')]
        [string]$Level = 'Info'
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Write to log file
    Add-Content -Path $LogPath -Value $logMessage
    
    # Write to console with color
    switch ($Level) {
        'Success' { Write-Host $Message -ForegroundColor Green }
        'Warning' { Write-Host $Message -ForegroundColor Yellow }
        'Error'   { Write-Host $Message -ForegroundColor Red }
        default   { Write-Host $Message -ForegroundColor White }
    }
}

# Import Active Directory module
try {
    Import-Module ActiveDirectory -ErrorAction Stop
    Write-Log "Active Directory module loaded successfully" -Level Info
}
catch {
    Write-Log "Failed to import Active Directory module: $_" -Level Error
    exit 1
}

# Verify CSV file exists
if (-not (Test-Path $CSVPath)) {
    Write-Log "CSV file not found: $CSVPath" -Level Error
    exit 1
}

Write-Log "Starting AD phone number update process" -Level Info
Write-Log "CSV Source: $CSVPath" -Level Info
Write-Log "Log File: $LogPath" -Level Info

if ($WhatIfPreference) {
    Write-Log "*** WHATIF MODE - No changes will be made ***" -Level Warning
}

# Load CSV
try {
    $users = Import-Csv -Path $CSVPath
    Write-Log "Loaded $($users.Count) users from CSV" -Level Success
}
catch {
    Write-Log "Failed to load CSV file: $_" -Level Error
    exit 1
}

# Counters for summary
$stats = @{
    Total = $users.Count
    Updated = 0
    Skipped = 0
    NotFound = 0
    Errors = 0
}

Write-Log "" -Level Info
Write-Log "--- Processing Users ---" -Level Info

foreach ($user in $users) {
    $samAccountName = $user.SamAccountName
    
    # Skip if no phone numbers to update
    $hasOfficePhone = ![string]::IsNullOrWhiteSpace($user.OfficePhone)
    $hasMobilePhone = ![string]::IsNullOrWhiteSpace($user.MobilePhone)
    
    if (-not $hasOfficePhone -and -not $hasMobilePhone) {
        Write-Log "Skipping $samAccountName - No phone numbers to update" -Level Info
        $stats.Skipped++
        continue
    }
    
    try {
        # Get AD user
        $adUser = Get-ADUser -Identity $samAccountName -Properties OfficePhone, MobilePhone -ErrorAction Stop
        
        $changes = @()
        $updateParams = @{
            Identity = $samAccountName
        }
        
        # Check and update Office Phone
        if ($hasOfficePhone) {
            if ($adUser.OfficePhone -ne $user.OfficePhone) {
                $updateParams['OfficePhone'] = $user.OfficePhone
                $oldOffice = $adUser.OfficePhone
                $newOffice = $user.OfficePhone
                $changes += "OfficePhone: '$oldOffice' -> '$newOffice'"
            }
        }
        
        # Check and update Mobile Phone
        if ($hasMobilePhone) {
            if ($adUser.MobilePhone -ne $user.MobilePhone) {
                $updateParams['MobilePhone'] = $user.MobilePhone
                $oldMobile = $adUser.MobilePhone
                $newMobile = $user.MobilePhone
                $changes += "MobilePhone: '$oldMobile' -> '$newMobile'"
            }
        }
        
        # Only update if there are actual changes
        if ($changes.Count -gt 0) {
            if ($PSCmdlet.ShouldProcess($samAccountName, "Update phone numbers")) {
                Set-ADUser @updateParams -ErrorAction Stop
                $changeList = $changes -join ', '
                $displayName = $user.DisplayName
                Write-Log "Updated $samAccountName ($displayName): $changeList" -Level Success
                $stats.Updated++
            }
            else {
                $changeList = $changes -join ', '
                $displayName = $user.DisplayName
                Write-Log "[WHATIF] Would update $samAccountName ($displayName): $changeList" -Level Info
                $stats.Updated++
            }
        }
        else {
            Write-Log "Skipping $samAccountName - Phone numbers already match AD" -Level Info
            $stats.Skipped++
        }
    }
    catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
        Write-Log "User not found in AD: $samAccountName" -Level Error
        $stats.NotFound++
    }
    catch {
        Write-Log "Error updating $samAccountName : $_" -Level Error
        $stats.Errors++
    }
}

# Summary
Write-Log "" -Level Info
Write-Log "========================================" -Level Info
Write-Log "UPDATE SUMMARY" -Level Info
Write-Log "========================================" -Level Info
$totalMsg = "Total Users Processed: " + $stats.Total
Write-Log $totalMsg -Level Info
$updatedMsg = "Successfully Updated: " + $stats.Updated
Write-Log $updatedMsg -Level Success
$skippedMsg = "Skipped (No Changes): " + $stats.Skipped
Write-Log $skippedMsg -Level Info
$notFoundMsg = "Not Found in AD: " + $stats.NotFound
Write-Log $notFoundMsg -Level Warning
$errLevel = if ($stats.Errors -gt 0) { 'Error' } else { 'Info' }
$errorMsg = "Errors: " + $stats.Errors
Write-Log $errorMsg -Level $errLevel
Write-Log "========================================" -Level Info

if ($WhatIfPreference) {
    Write-Log "" -Level Info
    Write-Log "*** This was a WHATIF run - No actual changes were made ***" -Level Warning
}

Write-Log "" -Level Info
$logMsg = "Log file saved to: " + $LogPath
Write-Log $logMsg -Level Info
