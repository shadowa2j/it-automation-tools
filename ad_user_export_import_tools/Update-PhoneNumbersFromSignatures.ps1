<#
.SYNOPSIS
    Updates phone numbers in AD export CSV by matching with signature sheet data
    
.DESCRIPTION
    Matches users from the signature sheet to the AD export by first and last name,
    updates phone numbers, and formats all numbers as (xxx) xxx-xxxx. Skips invalid
    entries like "N/A", "no phone", etc.
    
.PARAMETER ADExportPath
    Path to the AD export CSV file
    
.PARAMETER SignaturePath
    Path to the signature phone numbers CSV file
    
.PARAMETER OutputPath
    Path where the updated CSV will be saved
    
.EXAMPLE
    .\Update-PhoneNumbersFromSignatures.ps1 -ADExportPath ".\WilbertUsers_PhoneNumbers.csv" -SignaturePath ".\Wilbert_Email_Signature_Phone_Numbers.csv"

.NOTES
    Author: Bryan
    Company: Quality Computer Solutions
    Version: 1.0.0
    Last Modified: 2025-12-04
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ADExportPath,
    
    [Parameter(Mandatory)]
    [string]$SignaturePath,
    
    [Parameter()]
    [string]$OutputPath = ".\WilbertUsers_PhoneNumbers_Updated_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
)

function Format-PhoneNumber {
    param([string]$PhoneNumber)
    
    # Return empty if null or whitespace
    if ([string]::IsNullOrWhiteSpace($PhoneNumber)) {
        return ""
    }
    
    # Convert to lowercase for case-insensitive matching
    $lower = $PhoneNumber.ToLower().Trim()
    
    # Skip non-phone entries
    if ($lower -match '^(n/a|na|no phone|none)$') {
        return ""
    }
    
    # Extract only digits
    $digits = $PhoneNumber -replace '\D', ''
    
    # Check if we have 10 digits (US phone number)
    if ($digits.Length -eq 10) {
        return "($($digits.Substring(0,3))) $($digits.Substring(3,3))-$($digits.Substring(6,4))"
    }
    # Check if we have 11 digits starting with 1 (US number with country code)
    elseif ($digits.Length -eq 11 -and $digits.StartsWith('1')) {
        $trimmed = $digits.Substring(1)
        return "($($trimmed.Substring(0,3))) $($trimmed.Substring(3,3))-$($trimmed.Substring(6,4))"
    }
    # If it's not a standard format, return empty (skip it)
    else {
        return ""
    }
}

function Get-NameFromDisplayName {
    param([string]$DisplayName)
    
    # Most DisplayNames are in "FirstName LastName" format
    # Handle edge cases like "FirstName Middle LastName"
    $parts = $DisplayName -split '\s+'
    
    if ($parts.Count -ge 2) {
        return @{
            FirstName = $parts[0]
            LastName = $parts[-1]  # Get last element as last name
        }
    }
    
    return $null
}

Write-Host "Loading CSV files..." -ForegroundColor Cyan

# Load both CSV files
try {
    $adUsers = Import-Csv -Path $ADExportPath
    $signatureUsers = Import-Csv -Path $SignaturePath
}
catch {
    Write-Error "Failed to load CSV files: $_"
    exit 1
}

Write-Host "Loaded $($adUsers.Count) AD users" -ForegroundColor Green
Write-Host "Loaded $($signatureUsers.Count) signature records" -ForegroundColor Green
Write-Host "`nMatching users and updating phone numbers..." -ForegroundColor Cyan

# Create a hashtable for quick lookups (key = "firstname lastname")
$signatureLookup = @{}
foreach ($sigUser in $signatureUsers) {
    $key = "$($sigUser.'First Name'.Trim().ToLower()) $($sigUser.'Last Name'.Trim().ToLower())"
    $signatureLookup[$key] = $sigUser
}

$matchCount = 0
$updateCount = 0
$skippedCount = 0

# Process each AD user
foreach ($adUser in $adUsers) {
    $nameInfo = Get-NameFromDisplayName -DisplayName $adUser.DisplayName
    
    if ($null -eq $nameInfo) {
        Write-Warning "Could not parse name from DisplayName: $($adUser.DisplayName)"
        continue
    }
    
    $lookupKey = "$($nameInfo.FirstName.ToLower()) $($nameInfo.LastName.ToLower())"
    
    if ($signatureLookup.ContainsKey($lookupKey)) {
        $matchCount++
        $sigData = $signatureLookup[$lookupKey]
        $updated = $false
        
        # Update Office Phone
        if (![string]::IsNullOrWhiteSpace($sigData.'Office Phone Number')) {
            $formatted = Format-PhoneNumber -PhoneNumber $sigData.'Office Phone Number'
            if (![string]::IsNullOrWhiteSpace($formatted)) {
                $adUser.OfficePhone = $formatted
                $updated = $true
            }
        }
        
        # Update Mobile Phone
        if (![string]::IsNullOrWhiteSpace($sigData.'Mobile Phone Number')) {
            $formatted = Format-PhoneNumber -PhoneNumber $sigData.'Mobile Phone Number'
            if (![string]::IsNullOrWhiteSpace($formatted)) {
                $adUser.MobilePhone = $formatted
                $updated = $true
            }
        }
        
        if ($updated) {
            $updateCount++
            Write-Host "  ✓ Updated: $($adUser.DisplayName)" -ForegroundColor Green
        }
        else {
            $skippedCount++
        }
    }
}

Write-Host "`n--- Summary ---" -ForegroundColor Cyan
Write-Host "Total AD Users: $($adUsers.Count)"
Write-Host "Matched Users: $matchCount"
Write-Host "Updated Users: $updateCount"
Write-Host "Matched but Skipped (no valid phone): $skippedCount"
Write-Host "Not Matched: $($adUsers.Count - $matchCount)"

# Export updated CSV
$adUsers | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8

Write-Host "`nUpdated CSV saved to: $OutputPath" -ForegroundColor Green
