<#
.SYNOPSIS
    Imports AD user data from CSV and updates user attributes in Active Directory.

.DESCRIPTION
    This script reads a CSV file containing AD user information and updates the corresponding
    user accounts in Active Directory with the values from the CSV. It includes extensive
    error handling, validation, and supports both direct attribute updates and multi-valued
    attributes (like proxyAddresses).

.PARAMETER CsvPath
    The path to the CSV file containing user data to import

.PARAMETER WhatIf
    Performs a dry-run without making actual changes (shows what would be updated)

.PARAMETER UpdateSpecificAttributes
    Array of specific attribute names to update. If not specified, updates all changed attributes.

.PARAMETER SkipConfirmation
    Skip the confirmation prompt before making changes

.EXAMPLE
    .\Import-ADUsersFromCSV.ps1 -CsvPath "C:\Exports\ADUsers.csv" -WhatIf

.EXAMPLE
    .\Import-ADUsersFromCSV.ps1 -CsvPath "C:\Exports\ADUsers.csv"

.EXAMPLE
    .\Import-ADUsersFromCSV.ps1 -CsvPath "C:\Exports\ADUsers.csv" -UpdateSpecificAttributes @("Title","Department","Manager")

.NOTES
    File Name      : Import-ADUsersFromCSV.ps1
    Author         : BF and Claude
    Prerequisite   : ActiveDirectory PowerShell Module, Run as Administrator
    Version        : 1.3
    Date           : 2025-11-12
    
.NOTES
    IMPORTANT: Some attributes are read-only or system-managed and cannot be updated.
    This script automatically excludes common read-only attributes.
#>

[CmdletBinding(SupportsShouldProcess)]
param (
    [Parameter(Mandatory = $true, HelpMessage = "Enter the path to the CSV file")]
    [ValidateScript({Test-Path $_ -PathType Leaf})]
    [string]$CsvPath,
    
    [Parameter(Mandatory = $false)]
    [string[]]$UpdateSpecificAttributes,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipConfirmation
)

# Initialize logging
$LogPath = "C:\temp\scripts\ADImport_Log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
$ErrorLogPath = "C:\temp\scripts\ADImport_Errors_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"

# Ensure log directory exists
$LogDir = Split-Path -Path $LogPath -Parent
if (-not (Test-Path $LogDir)) {
    New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] [$Level] $Message"
    Add-Content -Path $LogPath -Value $LogMessage
    
    switch ($Level) {
        "ERROR" { Write-Host $LogMessage -ForegroundColor Red }
        "WARNING" { Write-Host $LogMessage -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $LogMessage -ForegroundColor Green }
        default { Write-Host $LogMessage }
    }
}

Write-Log "========== AD User Import Script Started =========="
Write-Log "CSV Path: $CsvPath"
Write-Log "WhatIf Mode: $($WhatIfPreference)"

# Check if ActiveDirectory module is available
try {
    Import-Module ActiveDirectory -ErrorAction Stop
    Write-Log "ActiveDirectory module loaded successfully" -Level "SUCCESS"
}
catch {
    Write-Log "Failed to import ActiveDirectory module: $($_.Exception.Message)" -Level "ERROR"
    throw
}

# Define attributes that should NOT be updated (read-only, system-managed, or dangerous to change)
$ExcludedAttributes = @(
    'ObjectGUID', 'ObjectSID', 'SID', 'Deleted', 'DistinguishedName', 'CN', 'Name',
    'whenCreated', 'whenChanged', 'uSNCreated', 'uSNChanged', 'Created', 'Modified',
    'ObjectClass', 'ObjectCategory', 'PropertyNames', 'PropertyCount', 'Item', 'sDRightsEffective',
    'LastLogonDate', 'lastLogon', 'lastLogonTimestamp', 'badPasswordTime', 'pwdLastSet',
    'AccountExpirationDate', 'accountExpires', 'BadLogonCount', 'badPwdCount', 'lockoutTime',
    'msDS-UserPasswordExpiryTimeComputed', 'ProtectedFromAccidentalDeletion', 'isDeletionPermitted',
    'CanonicalName', 'lockOutObservationWindow', 'lockoutDuration', 'maxPwdAge', 'minPwdAge',
    'minPwdLength', 'modifyTimeStamp', 'createTimeStamp', 'msDS-User-Account-Control-Computed',
    'instanceType', 'nTSecurityDescriptor', 'showInAdvancedViewOnly', 'systemFlags',
    'PrimaryGroup', 'PrimaryGroupID', 'RIDSetReferences', 'masteredBy', 'ManagedObjects'
)

# Import CSV
Write-Log "Importing CSV file..."
try {
    $CsvData = Import-Csv -Path $CsvPath -Encoding UTF8
    $CsvUserCount = $CsvData.Count
    Write-Log "Successfully imported $CsvUserCount user record(s) from CSV" -Level "SUCCESS"
    
    if ($CsvUserCount -eq 0) {
        Write-Log "CSV file is empty or has no data rows" -Level "WARNING"
        return
    }
}
catch {
    Write-Log "Error importing CSV: $($_.Exception.Message)" -Level "ERROR"
    throw
}

# Initialize counters
$UpdatedCount = 0
$ErrorCount = 0
$SkippedCount = 0
$ErrorRecords = @()

# Confirm before proceeding (unless skipped or WhatIf)
if (-not $SkipConfirmation -and -not $WhatIfPreference) {
    Write-Host "`n========== CONFIRMATION REQUIRED ==========" -ForegroundColor Yellow
    Write-Host "You are about to update $CsvUserCount user account(s) in Active Directory" -ForegroundColor Yellow
    Write-Host "CSV File: $CsvPath" -ForegroundColor Cyan
    Write-Host "Log File: $LogPath" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Yellow
    
    $Confirmation = Read-Host "`nType 'YES' to proceed with updates (or anything else to cancel)"
    if ($Confirmation -ne 'YES') {
        Write-Log "Operation cancelled by user" -Level "WARNING"
        return
    }
}

Write-Log "Processing user updates..."
$Progress = 0

foreach ($CsvUser in $CsvData) {
    $Progress++
    $PercentComplete = [math]::Round(($Progress / $CsvUserCount) * 100, 2)
    Write-Progress -Activity "Updating AD Users" -Status "Processing $Progress of $CsvUserCount - $PercentComplete%" -PercentComplete $PercentComplete
    
    # Get the user identity (try multiple methods)
    $UserIdentity = $null
    if (-not [string]::IsNullOrWhiteSpace($CsvUser.SamAccountName)) {
        $UserIdentity = $CsvUser.SamAccountName
        $IdentityType = "SamAccountName"
    }
    elseif (-not [string]::IsNullOrWhiteSpace($CsvUser.UserPrincipalName)) {
        $UserIdentity = $CsvUser.UserPrincipalName
        $IdentityType = "UserPrincipalName"
    }
    elseif (-not [string]::IsNullOrWhiteSpace($CsvUser.DistinguishedName)) {
        $UserIdentity = $CsvUser.DistinguishedName
        $IdentityType = "DistinguishedName"
    }
    
    if ($null -eq $UserIdentity) {
        Write-Log "Row $Progress : No valid identity found (SamAccountName, UPN, or DN)" -Level "ERROR"
        $ErrorCount++
        $ErrorRecords += [PSCustomObject]@{
            Row = $Progress
            Identity = "Unknown"
            Error = "No valid identity column found"
        }
        continue
    }
    
    Write-Log "Processing user: $UserIdentity (using $IdentityType)"
    
    # Get current AD user
    try {
        $AdUser = Get-ADUser -Identity $UserIdentity -Properties * -ErrorAction Stop
        Write-Log "  Found AD user: $($AdUser.SamAccountName)"
    }
    catch {
        Write-Log "  User not found in AD: $UserIdentity - $($_.Exception.Message)" -Level "ERROR"
        $ErrorCount++
        $ErrorRecords += [PSCustomObject]@{
            Row = $Progress
            Identity = $UserIdentity
            Error = "User not found in AD: $($_.Exception.Message)"
        }
        continue
    }
    
    # Get all property names from CSV row
    $CsvProperties = $CsvUser.PSObject.Properties.Name
    
    # Filter properties to update
    $PropertiesToUpdate = $CsvProperties | Where-Object {
        $_ -notin $ExcludedAttributes -and
        (-not $UpdateSpecificAttributes -or $_ -in $UpdateSpecificAttributes)
    }
    
    # Build hashtable of changes
    $Changes = @{}
    $ChangeCount = 0
    
    foreach ($Property in $PropertiesToUpdate) {
        $CsvValue = $CsvUser.$Property
        $AdValue = $AdUser.$Property
        
        # Map display names to LDAP attribute names
        $MappedProperty = switch ($Property) {
            'Office' { 'physicalDeliveryOfficeName' }
            'City' { 'l' }
            'State' { 'st' }
            'EmailAddress' { 'mail' }
            default { $Property }
        }
        
        # Skip attributes that aren't valid for Set-ADUser -Replace
        if ($MappedProperty -in @('Country', 'countryCode')) {
            continue
        }
        
        # Get the AD value using the mapped property name
        if ($MappedProperty -ne $Property) {
            $AdValue = $AdUser.$MappedProperty
        }
        
        # Skip if CSV value is null or empty string
        if ([string]::IsNullOrWhiteSpace($CsvValue)) {
            continue
        }
        
        # Handle multi-valued attributes (comes as semicolon-separated in CSV)
        if ($AdValue -is [array]) {
            $CsvValueArray = $CsvValue -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
            $AdValueSorted = ($AdValue | Sort-Object) -join ';'
            $CsvValueSorted = ($CsvValueArray | Sort-Object) -join ';'
            
            if ($AdValueSorted -ne $CsvValueSorted) {
                $Changes[$MappedProperty] = $CsvValueArray
                $ChangeCount++
            }
        }
        else {
            # Convert AD value to string for comparison
            $AdValueString = if ($null -eq $AdValue) { "" } else { $AdValue.ToString() }
            $CsvValueString = $CsvValue.ToString()
            
            if ($AdValueString -ne $CsvValueString) {
                # Handle special types
                if (($MappedProperty -like "*Date*" -and $MappedProperty -notin $ExcludedAttributes) -or $MappedProperty -eq "accountExpires") {
                    try {
                        $Changes[$MappedProperty] = [DateTime]::Parse($CsvValueString)
                        $ChangeCount++
                    }
                    catch {
                        Write-Log "  Unable to parse date for property '$MappedProperty': $CsvValueString" -Level "WARNING"
                    }
                }
                elseif ($MappedProperty -eq "Enabled" -or $MappedProperty -like "*Flag*") {
                    $Changes[$MappedProperty] = [bool]::Parse($CsvValueString)
                    $ChangeCount++
                }
                else {
                    $Changes[$MappedProperty] = $CsvValueString
                    $ChangeCount++
                }
            }
        }
    }
    
    # Update the user if there are changes
    if ($ChangeCount -gt 0) {
        Write-Log "  Found $ChangeCount attribute(s) to update" -Level "SUCCESS"
        
        foreach ($Change in $Changes.GetEnumerator()) {
            Write-Log "    - $($Change.Key): Updating to '$($Change.Value)'"
        }
        
        if ($PSCmdlet.ShouldProcess($UserIdentity, "Update AD user attributes")) {
            try {
                Set-ADUser -Identity $AdUser.DistinguishedName -Replace $Changes -ErrorAction Stop
                Write-Log "  Successfully updated user: $UserIdentity" -Level "SUCCESS"
                $UpdatedCount++
            }
            catch {
                Write-Log "  Error updating user: $UserIdentity - $($_.Exception.Message)" -Level "ERROR"
                $ErrorCount++
                $ErrorRecords += [PSCustomObject]@{
                    Row = $Progress
                    Identity = $UserIdentity
                    Error = $_.Exception.Message
                }
            }
        }
        else {
            Write-Log "  [WHATIF] Would update user: $UserIdentity" -Level "WARNING"
            $UpdatedCount++
        }
    }
    else {
        Write-Log "  No changes detected for user: $UserIdentity"
        $SkippedCount++
    }
}

Write-Progress -Activity "Updating AD Users" -Completed

# Export error records if any
if ($ErrorRecords.Count -gt 0) {
    $ErrorRecords | Export-Csv -Path $ErrorLogPath -NoTypeInformation
    Write-Log "Error details exported to: $ErrorLogPath" -Level "WARNING"
}

# Display summary
Write-Host "`n========== Update Summary ==========" -ForegroundColor Cyan
Write-Host "Total Records Processed: $CsvUserCount" -ForegroundColor White
if ($WhatIfPreference) {
    Write-Host "Would Update: $UpdatedCount" -ForegroundColor Yellow
} else {
    Write-Host "Successfully Updated: $UpdatedCount" -ForegroundColor Green
}
Write-Host "Skipped (No Changes): $SkippedCount" -ForegroundColor Gray
Write-Host "Errors: $ErrorCount" -ForegroundColor $(if ($ErrorCount -gt 0) { "Red" } else { "Green" })
Write-Host "Log File: $LogPath" -ForegroundColor Cyan
if ($ErrorCount -gt 0) {
    Write-Host "Error Log: $ErrorLogPath" -ForegroundColor Yellow
}
Write-Host "====================================`n" -ForegroundColor Cyan

Write-Log "========== AD User Import Script Completed =========="
Write-Log "Summary - Processed: $CsvUserCount | Updated: $UpdatedCount | Skipped: $SkippedCount | Errors: $ErrorCount"
