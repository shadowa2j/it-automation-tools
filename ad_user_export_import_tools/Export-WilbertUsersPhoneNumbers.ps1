<#
.SYNOPSIS
    Exports enabled users from Wilbert Employees OU with all phone number fields
    
.DESCRIPTION
    Retrieves all enabled users from OU=Employees,OU=Wilbert Users,DC=wilbertinc,DC=prv
    and child OUs, excluding users in the TEST OU. Exports SamAccountName and all
    phone number related fields to CSV.
    
.PARAMETER OutputPath
    Path where the CSV file will be saved. Defaults to current directory with timestamp.
    
.EXAMPLE
    .\Export-WilbertUsersPhoneNumbers.ps1
    
.EXAMPLE
    .\Export-WilbertUsersPhoneNumbers.ps1 -OutputPath "C:\Exports\WilbertPhones.csv"

.NOTES
    Author: Bryan
    Company: Quality Computer Solutions
    Version: 1.0.0
    Last Modified: 2025-12-04
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$OutputPath = ".\WilbertUsers_PhoneNumbers_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
)

# Import Active Directory module
try {
    Import-Module ActiveDirectory -ErrorAction Stop
}
catch {
    Write-Error "Failed to import Active Directory module. Ensure RSAT tools are installed."
    exit 1
}

# Define the base OU and exclusion OU
$baseOU = "OU=Employees,OU=Wilbert Users,DC=wilbertinc,DC=prv"
$excludeOU = "OU=TEST,OU=Employees,OU=Wilbert Users,DC=wilbertinc,DC=prv"

Write-Host "Retrieving enabled users from: $baseOU" -ForegroundColor Cyan
Write-Host "Excluding users from: $excludeOU" -ForegroundColor Yellow

# Properties to retrieve - all phone-related fields
$properties = @(
    'SamAccountName',
    'DisplayName',
    'DistinguishedName',
    'OfficePhone',
    'HomePhone',
    'MobilePhone',
    'ipPhone',
    'Pager',
    'Fax'
)

try {
    # Get all enabled users from the base OU and sub-OUs
    $users = Get-ADUser -Filter 'Enabled -eq $true' -SearchBase $baseOU -SearchScope Subtree -Properties $properties |
        Where-Object { $_.DistinguishedName -notlike "*$excludeOU*" }
    
    Write-Host "Found $($users.Count) enabled users (excluding TEST OU)" -ForegroundColor Green
    
    if ($users.Count -eq 0) {
        Write-Warning "No users found matching the criteria."
        exit 0
    }
    
    # Export to CSV
    $users | Select-Object -Property $properties | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
    
    Write-Host "`nExport completed successfully!" -ForegroundColor Green
    Write-Host "Output file: $OutputPath" -ForegroundColor Cyan
    
    # Display summary statistics
    $phoneStats = @{
        OfficePhone = ($users | Where-Object { $_.OfficePhone }).Count
        HomePhone = ($users | Where-Object { $_.HomePhone }).Count
        MobilePhone = ($users | Where-Object { $_.MobilePhone }).Count
        Fax = ($users | Where-Object { $_.Fax }).Count
    }
    
    Write-Host "`n--- Phone Number Statistics ---" -ForegroundColor Cyan
    Write-Host "Users with Office Phone: $($phoneStats.OfficePhone)"
    Write-Host "Users with Home Phone: $($phoneStats.HomePhone)"
    Write-Host "Users with Mobile Phone: $($phoneStats.MobilePhone)"
    Write-Host "Users with Fax: $($phoneStats.Fax)"
}
catch {
    Write-Error "An error occurred: $_"
    exit 1
}
