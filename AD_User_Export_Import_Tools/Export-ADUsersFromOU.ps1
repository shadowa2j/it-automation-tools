<#
.SYNOPSIS
    Exports all Active Directory users from a specified OU (including sub-OUs) to CSV with all attributes.

.DESCRIPTION
    This script retrieves all user accounts from a specified Organizational Unit and its sub-OUs,
    exports all populated attributes to a CSV file for backup or modification purposes.

.PARAMETER SearchBase
    The Distinguished Name of the OU to search (e.g., "OU=Users,DC=domain,DC=com")

.PARAMETER OutputPath
    The path where the CSV file will be saved (default: Desktop with timestamp)

.EXAMPLE
    .\Export-ADUsersFromOU.ps1 -SearchBase "OU=Users,DC=contoso,DC=com"

.EXAMPLE
    .\Export-ADUsersFromOU.ps1 -SearchBase "OU=Users,DC=contoso,DC=com" -OutputPath "C:\Exports\ADUsers.csv"

.NOTES
    File Name      : Export-ADUsersFromOU.ps1
    Author         : BF and Claude
    Prerequisite   : ActiveDirectory PowerShell Module
    Version        : 1.0
    Date           : 2025-11-11
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, HelpMessage = "Enter the Distinguished Name of the OU (e.g., 'OU=Users,DC=domain,DC=com')")]
    [string]$SearchBase,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "$env:USERPROFILE\Desktop\ADUsers_Export_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
)

# Initialize logging
$LogPath = "$env:USERPROFILE\Desktop\ADExport_Log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
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

Write-Log "========== AD User Export Script Started =========="
Write-Log "Search Base: $SearchBase"
Write-Log "Output Path: $OutputPath"

# Check if ActiveDirectory module is available
try {
    Import-Module ActiveDirectory -ErrorAction Stop
    Write-Log "ActiveDirectory module loaded successfully" -Level "SUCCESS"
}
catch {
    Write-Log "Failed to import ActiveDirectory module: $($_.Exception.Message)" -Level "ERROR"
    throw
}

# Verify the OU exists
try {
    $null = Get-ADOrganizationalUnit -Identity $SearchBase -ErrorAction Stop
    Write-Log "OU verified: $SearchBase" -Level "SUCCESS"
}
catch {
    Write-Log "OU not found or inaccessible: $SearchBase - $($_.Exception.Message)" -Level "ERROR"
    throw
}

# Get all users from the OU and sub-OUs
Write-Log "Retrieving users from OU and sub-OUs..."
try {
    $Users = Get-ADUser -Filter * -SearchBase $SearchBase -SearchScope Subtree -Properties *
    $UserCount = $Users.Count
    Write-Log "Found $UserCount user(s) in the specified OU and sub-OUs" -Level "SUCCESS"
    
    if ($UserCount -eq 0) {
        Write-Log "No users found to export" -Level "WARNING"
        return
    }
}
catch {
    Write-Log "Error retrieving users: $($_.Exception.Message)" -Level "ERROR"
    throw
}

# Export to CSV
Write-Log "Exporting users to CSV..."
try {
    # Export all properties
    $Users | Select-Object * | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
    Write-Log "Successfully exported $UserCount user(s) to: $OutputPath" -Level "SUCCESS"
    
    # Display sample of exported properties
    $PropertyCount = ($Users | Select-Object -First 1 | Get-Member -MemberType Properties).Count
    Write-Log "Total properties exported per user: $PropertyCount"
    
    Write-Host "`n========== Export Summary ==========" -ForegroundColor Cyan
    Write-Host "Users Exported: $UserCount" -ForegroundColor Green
    Write-Host "Output File: $OutputPath" -ForegroundColor Green
    Write-Host "Log File: $LogPath" -ForegroundColor Green
    Write-Host "Properties per User: $PropertyCount" -ForegroundColor Green
    Write-Host "===================================`n" -ForegroundColor Cyan
}
catch {
    Write-Log "Error exporting to CSV: $($_.Exception.Message)" -Level "ERROR"
    throw
}

Write-Log "========== AD User Export Script Completed =========="
