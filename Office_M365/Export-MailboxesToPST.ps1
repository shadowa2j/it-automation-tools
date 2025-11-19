<#
.SYNOPSIS
    Automates the creation of eDiscovery Content Searches for Exchange Online mailboxes.

.DESCRIPTION
    This script creates individual compliance searches for specified users and monitors their completion.
    After searches complete, provides direct links to manually export via the Purview compliance portal.
    
    NOTE: As of May 26, 2025, Microsoft removed PowerShell-based export functionality.
    Exports must now be initiated manually through the compliance portal UI.

.NOTES
    Requirements:
    - ExchangeOnlineManagement module
    - eDiscovery Manager role or Compliance Administrator role
    - Security & Compliance PowerShell connection
    
    Author: Bryan
    Created: 2025-11-19
    Version: 1.0.0
    
    Version History:
    1.0.0 - 2025-11-19
        - Initial release
        - Creates compliance searches for specified mailboxes
        - Monitors search completion
        - Provides direct links to Purview compliance portal for manual export
        - Handles authentication for regular PowerShell and PowerShell ISE
        - Saves search results to text file for reference
        - Adapted for post-May 2025 Microsoft eDiscovery changes

.EXAMPLE
    .\Export-MailboxesToPST.ps1
    
    Creates compliance searches for all users specified in $UsersToExport,
    monitors completion, and provides export links.
#>

#Requires -Modules ExchangeOnlineManagement

# ============================================
# CONFIGURATION SECTION - MODIFY AS NEEDED
# ============================================

# List of user email addresses to export
$UsersToExport = @(
    "shernandez@prismplastics.com"
)

# Network share path where you'll download the PST files (for reference in notes)
$DownloadPath = "E:\OneDrive - PRISM Plastics\Scripts"

# Prefix for search names (helps identify these searches later)
$SearchPrefix = "MailboxExport"

# ============================================
# SCRIPT LOGIC - DO NOT MODIFY BELOW
# ============================================

# Connect to Security & Compliance PowerShell
Write-Host "Connecting to Security & Compliance Center..." -ForegroundColor Cyan

# Detect if running in ISE
if ($psISE) {
    Write-Host "PowerShell ISE detected - using compatible authentication method..." -ForegroundColor Yellow
    Write-Host "Note: You'll authenticate via device code. Follow the instructions." -ForegroundColor Gray
    try {
        Connect-IPPSSession -Device -ErrorAction Stop
        Write-Host "Successfully connected to Security & Compliance Center" -ForegroundColor Green
    } catch {
        Write-Host "Failed to connect: $_" -ForegroundColor Red
        Write-Host "PowerShell ISE has limited authentication support." -ForegroundColor Yellow
        Write-Host "Please run this script from regular PowerShell (not ISE) for best results." -ForegroundColor Yellow
        exit 1
    }
} else {
    Write-Host "Note: You may need to authenticate in your browser." -ForegroundColor Gray
    try {
        # Try direct connection first (modern auth)
        Connect-IPPSSession -ErrorAction Stop
        Write-Host "Successfully connected to Security & Compliance Center" -ForegroundColor Green
    } catch {
        Write-Host "Failed to connect to Security & Compliance Center: $_" -ForegroundColor Red
        Write-Host "Please ensure you have the ExchangeOnlineManagement module installed and proper permissions." -ForegroundColor Yellow
        Write-Host "If authentication keeps failing, try:" -ForegroundColor Yellow
        Write-Host "  1. Update the module: Update-Module ExchangeOnlineManagement -Force" -ForegroundColor Gray
        Write-Host "  2. Run from a non-elevated PowerShell window" -ForegroundColor Gray
        Write-Host "  3. Check if you have eDiscovery Manager permissions" -ForegroundColor Gray
        exit 1
    }
}

# Results tracking
$SearchJobs = @()
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host "MAILBOX SEARCH AUTOMATION" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Creating compliance searches for $($UsersToExport.Count) user(s)..." -ForegroundColor White
Write-Host "Timestamp: $Timestamp`n" -ForegroundColor Gray

foreach ($User in $UsersToExport) {
    Write-Host "Processing: $User" -ForegroundColor Yellow
    
    # Create unique search name
    $SearchName = "$SearchPrefix`_$($User.Replace('@','_').Replace('.','_'))_$Timestamp"
    
    try {
        # Create the compliance search
        Write-Host "  Creating compliance search..." -ForegroundColor Gray
        $Search = New-ComplianceSearch -Name $SearchName `
                                       -ExchangeLocation $User `
                                       -AllowNotFoundExchangeLocationsEnabled $false `
                                       -ErrorAction Stop
        
        # Start the search
        Write-Host "  Starting search..." -ForegroundColor Gray
        Start-ComplianceSearch -Identity $SearchName -ErrorAction Stop
        
        # Wait for search to complete
        Write-Host "  Waiting for search to complete..." -ForegroundColor Gray
        $SearchStatus = $null
        $MaxWaitMinutes = 30
        $WaitedMinutes = 0
        
        do {
            Start-Sleep -Seconds 10
            $SearchStatus = Get-ComplianceSearch -Identity $SearchName
            $WaitedMinutes += 0.17
            
            if ($WaitedMinutes -gt $MaxWaitMinutes) {
                Write-Host "  Search timed out after $MaxWaitMinutes minutes" -ForegroundColor Red
                break
            }
        } while ($SearchStatus.Status -ne "Completed")
        
        if ($SearchStatus.Status -eq "Completed") {
            Write-Host "  Search completed successfully" -ForegroundColor Green
            Write-Host "    Items found: $($SearchStatus.Items)" -ForegroundColor Gray
            
            # Parse size - it comes as a string like "1.234 GB (1234567 bytes)"
            $SizeString = $SearchStatus.Size
            $SizeMB = 0
            $SizeDisplay = "Unknown"
            if ($SizeString -match '\((\d+) bytes\)') {
                $SizeBytes = [int64]$matches[1]
                $SizeMB = [math]::Round($SizeBytes / 1MB, 2)
                $SizeGB = [math]::Round($SizeBytes / 1GB, 2)
                if ($SizeGB -gt 1) {
                    $SizeDisplay = "$SizeGB GB"
                } else {
                    $SizeDisplay = "$SizeMB MB"
                }
            }
            Write-Host "    Size: $SizeDisplay" -ForegroundColor Gray
            
            # Track this search job
            $SearchJobs += [PSCustomObject]@{
                User = $User
                SearchName = $SearchName
                ItemCount = $SearchStatus.Items
                SizeMB = $SizeMB
                SizeDisplay = $SizeDisplay
                Status = "Completed - Ready for Export"
                ComplianceURL = "https://compliance.microsoft.com/contentsearch?viewid=search&search=$([System.Web.HttpUtility]::UrlEncode($SearchName))"
            }
        } else {
            Write-Host "  Search did not complete successfully. Status: $($SearchStatus.Status)" -ForegroundColor Red
            $SearchJobs += [PSCustomObject]@{
                User = $User
                SearchName = $SearchName
                ItemCount = 0
                SizeMB = 0
                SizeDisplay = "N/A"
                Status = "Failed: Search status was $($SearchStatus.Status)"
                ComplianceURL = "N/A"
            }
        }
        
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        $SearchJobs += [PSCustomObject]@{
            User = $User
            SearchName = $SearchName
            ItemCount = 0
            SizeMB = 0
            SizeDisplay = "N/A"
            Status = "Failed: $($_.Exception.Message)"
            ComplianceURL = "N/A"
        }
    }
    
    Write-Host ""
}

# Display summary
Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host "SEARCH RESULTS SUMMARY" -ForegroundColor Cyan
Write-Host "============================================`n" -ForegroundColor Cyan

$SearchJobs | Format-Table User, ItemCount, SizeDisplay, Status -AutoSize

# Count successful searches
$SuccessfulSearches = $SearchJobs | Where-Object { $_.Status -like "*Ready for Export*" }

if ($SuccessfulSearches.Count -eq 0) {
    Write-Host "No searches completed successfully. Please check the errors above." -ForegroundColor Red
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
    exit 1
}

# Provide export instructions with direct links
Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host "EXPORT INSTRUCTIONS" -ForegroundColor Cyan
Write-Host "============================================`n" -ForegroundColor Cyan

Write-Host "All searches have completed successfully!" -ForegroundColor Green
Write-Host "Microsoft requires exports to be initiated manually through the compliance portal.`n" -ForegroundColor Yellow

Write-Host "QUICK EXPORT LINKS:" -ForegroundColor White
Write-Host "Click each link below to export the corresponding mailbox:`n" -ForegroundColor Gray

foreach ($Job in $SuccessfulSearches) {
    Write-Host "User: $($Job.User)" -ForegroundColor Yellow
    Write-Host "  Items: $($Job.ItemCount) | Size: $($Job.SizeDisplay)" -ForegroundColor Gray
    Write-Host "  Direct Link: $($Job.ComplianceURL)" -ForegroundColor Cyan
    Write-Host ""
}

Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host "EXPORT STEPS (for each link above)" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "1. Click the direct link for the user" -ForegroundColor White
Write-Host "2. Click 'Actions' > 'Export results'" -ForegroundColor White
Write-Host "3. Configure export options:" -ForegroundColor White
Write-Host "   - Output options: All items, excluding ones with unrecognized format" -ForegroundColor Gray
Write-Host "   - Export Exchange content as: One PST file per mailbox" -ForegroundColor Gray
Write-Host "   - Enable deduplication: Yes (recommended)" -ForegroundColor Gray
Write-Host "4. Click 'Export'" -ForegroundColor White
Write-Host "5. Wait for export to complete (monitor in 'Exports' tab)" -ForegroundColor White
Write-Host "6. Click 'Download results' and install eDiscovery Export Tool if prompted" -ForegroundColor White
Write-Host "7. Specify download location: $DownloadPath" -ForegroundColor White
Write-Host "`nNote: PST files will automatically split into 10GB chunks if larger." -ForegroundColor Yellow

Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host "ALTERNATIVE: Batch Export" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "To export all searches at once:" -ForegroundColor White
Write-Host "1. Go to: https://compliance.microsoft.com/contentsearch" -ForegroundColor Cyan
Write-Host "2. Select multiple searches using the checkboxes" -ForegroundColor White
Write-Host "3. Click 'Actions' > 'Export results' to batch export" -ForegroundColor White

# Save search details to file for reference
$OutputFile = "MailboxExportSearches_$Timestamp.txt"
$OutputPath = Join-Path $PSScriptRoot $OutputFile

$OutputContent = @"
Mailbox Export Searches - Created: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
============================================

"@

foreach ($Job in $SearchJobs) {
    $OutputContent += @"
User: $($Job.User)
Search Name: $($Job.SearchName)
Items: $($Job.ItemCount)
Size: $($Job.SizeDisplay)
Status: $($Job.Status)
Direct Link: $($Job.ComplianceURL)

"@
}

$OutputContent += @"

Download Location: $DownloadPath

Export Instructions:
1. Click each direct link above
2. Click Actions > Export results
3. Follow the export wizard
4. Download using eDiscovery Export Tool

"@

$OutputContent | Out-File -FilePath $OutputPath -Encoding UTF8
Write-Host "`nSearch details saved to: $OutputPath" -ForegroundColor Green

# Disconnect
Write-Host "`nDisconnecting from Security & Compliance Center..." -ForegroundColor Cyan
Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
Write-Host "Script completed!" -ForegroundColor Green
Write-Host "`nYou can now proceed with manual exports using the links above.`n" -ForegroundColor White
