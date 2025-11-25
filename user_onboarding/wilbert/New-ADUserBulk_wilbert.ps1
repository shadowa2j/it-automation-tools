#Requires -Module ActiveDirectory

<#
.SYNOPSIS
    Bulk creates Active Directory users from CSV file with group membership and Exchange attributes.

.DESCRIPTION
    This script imports user data from a CSV file and creates AD user accounts with:
    - Standard AD attributes (name, email, department, etc.)
    - Automatic group membership based on description field
    - Exchange attributes (mailNickname, proxyAddresses, targetAddress)

.PARAMETER CSVPath
    Path to the CSV file containing user data

.NOTES
    File Name  : New-ADUserBulk_wilbert.ps1
    Author     : Bryan Faulkner
    Company    : Quality Computer Solutions
    Version    : 1.0.0
    Date       : 2024-11-25
    Updated    : 2024-11-25
    
.CHANGELOG
    1.0.0 - 2024-11-25
        - Initial version with improved error handling
        - Consolidated CSV import to single read operation
        - Added individual error handling for group membership operations
        - Improved Exchange attribute handling with comma-separated value support
        - Enhanced console output with color-coded status messages
#>

# Enter a path to your import CSV file
$CSVPath = "C:\Users\bfaulkner\OneDrive - Wilbert Plastic Services\Scripts\newusers.csv"

# Verify CSV exists
if (-not (Test-Path $CSVPath)) {
    Write-Error "CSV file not found at: $CSVPath"
    Read-Host -Prompt "Press Enter to exit"
    exit
}

# Import CSV once
$ADUsers = Import-Csv $CSVPath

foreach ($User in $ADUsers) {
    $Username          = $User.samaccountname
    $Password          = $User.password
    $Firstname         = $User.firstname
    $Lastname          = $User.lastname
    $Description       = $User.description
    $Title             = $User.title
    $Department        = $User.department
    $OU                = $User.ou
    $Company           = $User.company
    $EmailAddress      = $User.emailaddress
    $StreetAddress     = $User.streetaddress
    $City              = $User.city
    $State             = $User.state
    $PostalCode        = $User.postalcode
    $HomeDrive         = $User.homedrive
    $HomeDirectory     = $User.homedirectory
    $Manager           = $User.manager
    $GroupSearch       = $User.Description + " - Role"
    $MailNickname      = $User.mailNickname
    $ProxyAddresses    = $User.Proxyaddresses
    $TargetAddress     = $User.targetAddress

    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Processing user: $Username" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan

    # Check if the user account already exists in AD
    if (Get-ADUser -Filter "SamAccountName -eq '$Username'" -ErrorAction SilentlyContinue) {
        Write-Warning "A user account '$Username' already exists in Active Directory. Skipping..."
        continue
    }

    # Create the new user account
    try {
        New-ADUser `
            -SamAccountName $Username `
            -UserPrincipalName "$Username@wilbertinc.com" `
            -Name "$Firstname $Lastname" `
            -GivenName $Firstname `
            -Surname $Lastname `
            -Enabled $True `
            -ChangePasswordAtLogon $True `
            -DisplayName "$Firstname $Lastname" `
            -Description $Description `
            -EmailAddress $EmailAddress `
            -Department $Department `
            -Title $Title `
            -Company $Company `
            -Manager $Manager `
            -Path $OU `
            -StreetAddress $StreetAddress `
            -City $City `
            -State $State `
            -PostalCode $PostalCode `
            -HomeDrive $HomeDrive `
            -HomeDirectory $HomeDirectory `
            -AccountPassword (ConvertTo-SecureString $Password -AsPlainText -Force) `
            -ErrorAction Stop

        Write-Host "✓ Successfully created user account: $Username" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to create user account '$Username'. Error: $_"
        continue
    }

    # Add user to groups based on description
    try {
        $MatchedGroups = Get-ADGroup -Filter "Name -like '*$GroupSearch*'" -ErrorAction Stop

        if ($MatchedGroups) {
            Write-Host "`nFound groups matching '$GroupSearch':" -ForegroundColor Yellow
            
            foreach ($Group in $MatchedGroups) {
                try {
                    Write-Host "  - Adding to: $($Group.Name)" -ForegroundColor Gray
                    Add-ADGroupMember -Identity $Group.Name -Members $Username -ErrorAction Stop
                    Write-Host "    ✓ Added successfully" -ForegroundColor Green
                }
                catch {
                    Write-Warning "    ✗ Failed to add user to group '$($Group.Name)'. Error: $_"
                }
            }
        }
        else {
            Write-Warning "No groups found matching '$GroupSearch'."
        }
    }
    catch {
        Write-Error "Error occurred while searching for groups matching '$GroupSearch'. Error: $_"
    }

    # Update Exchange attributes
    try {
        # Update mailNickname
        if ($MailNickname) {
            Set-ADUser -Identity $Username -Add @{mailNickname = $MailNickname} -ErrorAction Stop
            Write-Host "✓ Set mailNickname: $MailNickname" -ForegroundColor Green
        }

        # Update proxyAddresses (handle comma-separated values)
        if ($ProxyAddresses) {
            $ProxyArray = if ($ProxyAddresses -like '*,*') {
                $ProxyAddresses -split ","
            } else {
                @($ProxyAddresses)
            }
            Set-ADUser -Identity $Username -Add @{Proxyaddresses = $ProxyArray} -ErrorAction Stop
            Write-Host "✓ Set proxyAddresses: $($ProxyArray -join ', ')" -ForegroundColor Green
        }

        # Update targetAddress (handle comma-separated values)
        if ($TargetAddress) {
            $TargetArray = if ($TargetAddress -like '*,*') {
                $TargetAddress -split ","
            } else {
                @($TargetAddress)
            }
            Set-ADUser -Identity $Username -Add @{targetAddress = $TargetArray} -ErrorAction Stop
            Write-Host "✓ Set targetAddress: $($TargetArray -join ', ')" -ForegroundColor Green
        }
    }
    catch {
        Write-Warning "Failed to update Exchange attributes for '$Username'. Error: $_"
    }

    Write-Host "`n✓ Completed processing for: $Username" -ForegroundColor Green
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Bulk user creation complete!" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Read-Host -Prompt "Press Enter to exit"
