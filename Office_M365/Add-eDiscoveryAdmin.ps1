<#
.SYNOPSIS
    Adds eDiscovery Administrator permissions to a user account
.DESCRIPTION
    This script connects to Security & Compliance PowerShell and adds the specified user
    to the eDiscovery Manager role group, then promotes them to eDiscovery Administrator.
    
    Based on Microsoft documentation:
    https://learn.microsoft.com/en-us/powershell/module/exchange/add-ediscoverycaseadmin
.NOTES
    Author: Bryan
    Date: 2025-11-24
    Requires: ExchangeOnlineManagement module
#>

# User to be granted eDiscovery Administrator permissions
$UserPrincipalName = "admin@davalormoldcompany.onmicrosoft.com"

# Install/Import Exchange Online Management module if needed
if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
    Write-Host "Installing ExchangeOnlineManagement module..." -ForegroundColor Yellow
    Install-Module -Name ExchangeOnlineManagement -Force -AllowClobber
}

Import-Module ExchangeOnlineManagement

# Connect to Security and Compliance PowerShell
Write-Host "Connecting to Security and Compliance PowerShell..." -ForegroundColor Cyan
Connect-IPPSSession

try {
    # Step 1: Add user to eDiscovery Manager role group
    Write-Host "Adding $UserPrincipalName to eDiscovery Manager role group..." -ForegroundColor Cyan
    Add-RoleGroupMember -Identity "eDiscoveryManager" -Member $UserPrincipalName -ErrorAction Stop
    Write-Host "Successfully added to eDiscovery Manager role group" -ForegroundColor Green
    
    # Step 2: Promote user to eDiscovery Administrator (can access ALL cases)
    Write-Host "Promoting $UserPrincipalName to eDiscovery Administrator..." -ForegroundColor Cyan
    Add-eDiscoveryCaseAdmin -User $UserPrincipalName -ErrorAction Stop
    Write-Host "Successfully promoted to eDiscovery Administrator" -ForegroundColor Green
    
    # Verify the changes
    Write-Host "`nVerifying role assignments..." -ForegroundColor Cyan
    
    Write-Host "`neDiscovery Manager Role Group Members:" -ForegroundColor Yellow
    Get-RoleGroupMember -Identity "eDiscoveryManager" | Where-Object {$_.Name -like "*$UserPrincipalName*"} | Format-Table Name, PrimarySmtpAddress
    
    Write-Host "eDiscovery Administrators:" -ForegroundColor Yellow
    Get-eDiscoveryCaseAdmin | Format-Table Name, Email
    
    Write-Host "`nAll permissions have been successfully assigned!" -ForegroundColor Green
    Write-Host "Note: It may take up to 60 minutes for permissions to fully propagate." -ForegroundColor Yellow
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}
finally {
    # Disconnect session
    Write-Host "`nDisconnecting from Security and Compliance PowerShell..." -ForegroundColor Cyan
    Disconnect-ExchangeOnline -Confirm:$false
}
