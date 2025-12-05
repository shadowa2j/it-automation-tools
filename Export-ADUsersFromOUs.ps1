<#
.SYNOPSIS
    Exports Active Directory users from specified OUs with their username, name, email, and enabled status.

.DESCRIPTION
    This script exports AD user information (Username, First Name, Last Name, Email, Enabled/Disabled status)
    from one or more Organizational Units. Searches recursively through sub-OUs and combines all results
    into a single CSV file.

.PARAMETER OUPaths
    Array of Distinguished Names for the OUs to export users from.
    Example: @("OU=Employees,DC=domain,DC=com", "OU=Disabled Users,DC=domain,DC=com")

.PARAMETER OutputPath
    Full path where the CSV file will be saved. Defaults to current directory with timestamp.

.EXAMPLE
    .\Export-ADUsersFromOUs.ps1 -OUPaths @("OU=Employees,DC=contoso,DC=com", "OU=Disabled,DC=contoso,DC=com")

.EXAMPLE
    .\Export-ADUsersFromOUs.ps1 -OUPaths @("OU=Employees,DC=contoso,DC=com") -OutputPath "C:\Exports\ADUsers.csv"

.NOTES
    Author: Bryan
    Requires: ActiveDirectory PowerShell Module
    Version: 2.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Array of OU Distinguished Names to search")]
    [ValidateNotNullOrEmpty()]
    [string[]]$OUPaths,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = ".\ADUsers_Export_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
)

# Import Active Directory module
try {
    Import-Module ActiveDirectory -ErrorAction Stop
    Write-Host "Active Directory module loaded successfully." -ForegroundColor Green
}
catch {
    Write-Error "Failed to import Active Directory module. Ensure RSAT tools are installed."
    exit 1
}

# Initialize results array
$allUsers = @()

# Process each OU
foreach ($ouPath in $OUPaths) {
    Write-Host "`nProcessing OU: $ouPath" -ForegroundColor Cyan
    
    try {
        # Verify OU exists
        $null = Get-ADOrganizationalUnit -Identity $ouPath -ErrorAction Stop
        
        # Get all users from OU recursively - now including EmailAddress
        $users = Get-ADUser -Filter * -SearchBase $ouPath -SearchScope Subtree -Properties GivenName, Surname, EmailAddress, Enabled, SamAccountName -ErrorAction Stop
        
        Write-Host "Found $($users.Count) user(s) in this OU" -ForegroundColor Yellow
        
        # Process each user
        foreach ($user in $users) {
            $userObject = [PSCustomObject]@{
                Username    = $user.SamAccountName
                FirstName   = $user.GivenName
                LastName    = $user.Surname
                Email       = $user.EmailAddress
                Status      = if ($user.Enabled) { "Enabled" } else { "Disabled" }
            }
            
            $allUsers += $userObject
        }
    }
    catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
        Write-Warning "OU not found: $ouPath - Skipping..."
    }
    catch {
        Write-Warning "Error processing OU '$ouPath': $($_.Exception.Message)"
    }
}

# Export results
if ($allUsers.Count -gt 0) {
    try {
        $allUsers | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
        Write-Host "`nExport completed successfully!" -ForegroundColor Green
        Write-Host "Total users exported: $($allUsers.Count)" -ForegroundColor Green
        Write-Host "File saved to: $OutputPath" -ForegroundColor Green
        
        # Display summary
        $enabledCount = ($allUsers | Where-Object { $_.Status -eq "Enabled" }).Count
        $disabledCount = ($allUsers | Where-Object { $_.Status -eq "Disabled" }).Count
        $withEmail = ($allUsers | Where-Object { -not [string]::IsNullOrWhiteSpace($_.Email) }).Count
        $withoutEmail = $allUsers.Count - $withEmail
        
        Write-Host "`nSummary:" -ForegroundColor Cyan
        Write-Host "  Enabled users:  $enabledCount" -ForegroundColor Green
        Write-Host "  Disabled users: $disabledCount" -ForegroundColor Red
        Write-Host "  Users with email: $withEmail" -ForegroundColor Green
        Write-Host "  Users without email: $withoutEmail" -ForegroundColor Yellow
    }
    catch {
        Write-Error "Failed to export CSV: $($_.Exception.Message)"
        exit 1
    }
}
else {
    Write-Warning "No users found in any of the specified OUs."
}
