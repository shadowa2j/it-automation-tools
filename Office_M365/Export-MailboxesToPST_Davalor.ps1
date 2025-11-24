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
    .\Export-MailboxesToPST_Davalor.ps1
    
    Creates compliance searches for all Davalor mailboxes specified in $UsersToExport,
    monitors completion, and provides export links.
#>

#Requires -Modules ExchangeOnlineManagement

# ============================================
# CONFIGURATION SECTION - MODIFY AS NEEDED
# ============================================

# List of user email addresses to export
$UsersToExport = @(
    "accounting@davalor.com",
    "annette.cappella@davalor.com",
    "brandon.hammack@davalor.com",
    "brian.hopp@davalor.com",
    "christopher.cotting@davalor.com",
    "craig.levy@davalor.com",
    "dan.binkley@davalor.com",
    "daryl.miller@davalor.com",
    "calendars@davalor.com",
    "donna.lutz@davalor.com",
    "edward.schoenherr@davalor.com",
    "elizabeth.giovannangeli@davalor.com",
    "elizabeth.mcwilliams@davalor.com",
    "ernest.hilton@davalor.com",
    "fakhra.zahoor@davalor.com",
    "frank.palazzolo@davalor.com",
    "holli.mcewan@davalor.com",
    "iqsrv.davalor@davalor.com",
    "itsupport@davalor.com",
    "james.lemere@davalor.com",
    "jasmina.bircevic@davalor.com",
    "jeff.nolfo@davalor.com",
    "jen.wressell@davalor.com",
    "jena.mccoll@davalor.com",
    "jeremy.koss@davalor.com",
    "john.boeschenstein@davalor.com",
    "jwilson@davalor.com",
    "joshua.wendland@davalor.com",
    "karthika.konda@davalor.com",
    "kelly.hollandsworth@davalor.com",
    "ken.carlson@davalor.com",
    "kenneth.clark@davalor.com",
    "mary.maley@davalor.com",
    "material.davalor@davalor.com",
    "material2.davalor@davalor.com",
    "michael.houston@davalor.com",
    "mgrosor@davalor.com",
    "admin@davalormoldcompany.onmicrosoft.com",
    "paul.fee@davalor.com",
    "quality.office1-1@davalor.com",
    "quality.office1-2@davalor.com",
    "quality.office1-3@davalor.com",
    "quality.office2-1@davalor.com",
    "quality.office2-2@davalor.com",
    "quality.office2-3@davalor.com",
    "quality.office3-1@davalor.com",
    "quality.office3-2@davalor.com",
    "quality.office3-3@davalor.com",
    "robert.williams@davalor.com",
    "rodolfo.sanchez@davalor.com",
    "sanjiv.sheth@davalor.com",
    "scott.osterling@davalor.com",
    "sharleene.dionne@davalor.com",
    "steve.angst@davalor.com",
    "steve.arnold@davalor.com",
    "steve.hogston@davalor.com",
    "steve.tomlinson@davalor.com",
    "terry.darling@davalor.com",
    "theresa.sprague@davalor.com",
    "tony.hall@davalor.com",
    "vincent.bobek@davalor.com"
)

# Network share path where you'll download the PST files (for reference in notes)
$DownloadPath = "C:\Temp\Scripts"

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
Write-Host "Creating single compliance search for $($UsersToExport.Count) mailbox(es)..." -ForegroundColor White
Write-Host "Timestamp: $Timestamp`n" -ForegroundColor Gray

# Create a single search name
$SearchName = "$SearchPrefix`_$Timestamp"

Write-Host "Creating search: $SearchName" -ForegroundColor Yellow
Write-Host "  Mailboxes: $($UsersToExport -join ', ')" -ForegroundColor Gray

try {
    # Create the compliance search for all users at once
    Write-Host "  Creating compliance search..." -ForegroundColor Gray
    $Search = New-ComplianceSearch -Name $SearchName `
                                   -ExchangeLocation $UsersToExport `
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
        
        # Show progress
        Write-Host "`r  Waiting... $([math]::Round($WaitedMinutes, 1)) minutes elapsed" -NoNewline -ForegroundColor Gray
        
        if ($WaitedMinutes -gt $MaxWaitMinutes) {
            Write-Host "`n  Search timed out after $MaxWaitMinutes minutes" -ForegroundColor Red
            break
        }
    } while ($SearchStatus.Status -ne "Completed")
    
    Write-Host "" # New line after progress
    
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
            Mailboxes = $UsersToExport -join ', '
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
            Mailboxes = $UsersToExport -join ', '
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
        Mailboxes = $UsersToExport -join ', '
        SearchName = $SearchName
        ItemCount = 0
        SizeMB = 0
        SizeDisplay = "N/A"
        Status = "Failed: $($_.Exception.Message)"
        ComplianceURL = "N/A"
    }
}

# Display summary
Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host "SEARCH RESULTS SUMMARY" -ForegroundColor Cyan
Write-Host "============================================`n" -ForegroundColor Cyan

$SearchJobs | Format-Table Mailboxes, ItemCount, SizeDisplay, Status -AutoSize

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

Write-Host "QUICK EXPORT LINK:" -ForegroundColor White
Write-Host "Click the link below to export all mailboxes at once:`n" -ForegroundColor Gray

foreach ($Job in $SuccessfulSearches) {
    Write-Host "Search: $($Job.SearchName)" -ForegroundColor Yellow
    Write-Host "  Mailboxes: $($Job.Mailboxes)" -ForegroundColor Gray
    Write-Host "  Items: $($Job.ItemCount) | Size: $($Job.SizeDisplay)" -ForegroundColor Gray
    Write-Host "  Direct Link: $($Job.ComplianceURL)" -ForegroundColor Cyan
    Write-Host ""
}

Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host "EXPORT STEPS" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "1. Click the direct link above" -ForegroundColor White
Write-Host "2. Click 'Actions' > 'Export results'" -ForegroundColor White
Write-Host "3. Configure export options:" -ForegroundColor White
Write-Host "   - Output options: All items, excluding ones with unrecognized format" -ForegroundColor Gray
Write-Host "   - Export Exchange content as: One PST file per mailbox" -ForegroundColor Gray
Write-Host "   - Enable deduplication: Yes (recommended)" -ForegroundColor Gray
Write-Host "4. Click 'Export'" -ForegroundColor White
Write-Host "5. Wait for export to complete (monitor in 'Exports' tab)" -ForegroundColor White
Write-Host "6. Click 'Download results' and install eDiscovery Export Tool if prompted" -ForegroundColor White
Write-Host "7. Specify download location: $DownloadPath" -ForegroundColor White
Write-Host "`nNote: Each mailbox will be in a separate PST file." -ForegroundColor Yellow
Write-Host "Note: PST files will automatically split into 10GB chunks if larger." -ForegroundColor Yellow

Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host "ALTERNATIVE: Manual Navigation" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "If the direct link doesn't work:" -ForegroundColor White
Write-Host "1. Go to: https://compliance.microsoft.com/contentsearch" -ForegroundColor Cyan
Write-Host "2. Find the search: $($SuccessfulSearches[0].SearchName)" -ForegroundColor White
Write-Host "3. Click 'Actions' > 'Export results'" -ForegroundColor White

# Save search details to file for reference
$OutputFile = "MailboxExportSearches_$Timestamp.txt"
$OutputPath = Join-Path $PSScriptRoot $OutputFile

$OutputContent = @"
Mailbox Export Searches - Created: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
============================================

"@

foreach ($Job in $SearchJobs) {
    $OutputContent += @"
Mailboxes: $($Job.Mailboxes)
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
