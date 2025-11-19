<#
.SYNOPSIS
    Automates the creation of eDiscovery Content Searches and Export actions for Exchange Online mailboxes.

.DESCRIPTION
    This script creates individual compliance searches for specified users and initiates PST exports.
    Exports are split into 10GB files automatically. The script monitors export status and provides
    download instructions when ready.

.NOTES
    Requirements:
    - ExchangeOnlineManagement module
    - eDiscovery Manager role or Compliance Administrator role
    - Security & Compliance PowerShell connection
    
    Confidence Level: 85%
    Note: Export size limits and some parameters may need adjustment based on your tenant configuration.

.EXAMPLE
    .\Export-MailboxesToPST.ps1
#>

#Requires -Modules ExchangeOnlineManagement

# ============================================
# CONFIGURATION SECTION - MODIFY AS NEEDED
# ============================================

# List of user email addresses to export
$UsersToExport = @(
    "[email protected]",
    "[email protected]",
    "[email protected]"
)

# Network share path where you'll download the PST files (for reference only)
$DownloadPath = "\\server\share\MailboxExports"

# Prefix for search names (helps identify these searches later)
$SearchPrefix = "MailboxExport"

# ============================================
# SCRIPT LOGIC - DO NOT MODIFY BELOW
# ============================================

# Connect to Security & Compliance PowerShell
Write-Host "Connecting to Security & Compliance Center..." -ForegroundColor Cyan
try {
    Connect-IPPSSession -ErrorAction Stop
    Write-Host "Successfully connected to Security & Compliance Center" -ForegroundColor Green
} catch {
    Write-Host "Failed to connect to Security & Compliance Center: $_" -ForegroundColor Red
    Write-Host "Please ensure you have the ExchangeOnlineManagement module installed and proper permissions." -ForegroundColor Yellow
    exit 1
}

# Results tracking
$ExportJobs = @()
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

Write-Host "`nStarting mailbox export process for $($UsersToExport.Count) user(s)..." -ForegroundColor Cyan
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
            Write-Host "    Size: $([math]::Round($SearchStatus.Size / 1MB, 2)) MB" -ForegroundColor Gray
            
            # Create the export action
            Write-Host "  Creating export action..." -ForegroundColor Gray
            $ExportName = "$SearchName`_Export"
            
            $Export = New-ComplianceSearchAction -SearchName $SearchName `
                                                 -Export `
                                                 -Format FxStream `
                                                 -ExchangeArchiveFormat PerUserPst `
                                                 -Scope IndexedItemsOnly `
                                                 -EnableDedupe $true `
                                                 -SharePointArchiveFormat IndividualMessage `
                                                 -ErrorAction Stop
            
            Write-Host "  Export created: $ExportName" -ForegroundColor Green
            
            # Track this export job
            $ExportJobs += [PSCustomObject]@{
                User = $User
                SearchName = $SearchName
                ExportName = $ExportName
                ItemCount = $SearchStatus.Items
                SizeMB = [math]::Round($SearchStatus.Size / 1MB, 2)
                Status = "Export Initiated"
            }
        }
        
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        $ExportJobs += [PSCustomObject]@{
            User = $User
            SearchName = $SearchName
            ExportName = "N/A"
            ItemCount = 0
            SizeMB = 0
            Status = "Failed: $($_.Exception.Message)"
        }
    }
    
    Write-Host ""
}

# Display summary
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "EXPORT JOBS SUMMARY" -ForegroundColor Cyan
Write-Host "============================================`n" -ForegroundColor Cyan

$ExportJobs | Format-Table -AutoSize

# Monitor export status
Write-Host "`nMonitoring export status (this may take several minutes)..." -ForegroundColor Cyan
Write-Host "Press Ctrl+C to stop monitoring (exports will continue in background)`n" -ForegroundColor Gray

$AllCompleted = $false
$MonitoringRounds = 0
$MaxMonitoringRounds = 60  # 10 minutes with 10-second intervals

while (-not $AllCompleted -and $MonitoringRounds -lt $MaxMonitoringRounds) {
    Start-Sleep -Seconds 10
    $MonitoringRounds++
    
    $StatusUpdate = @()
    $CompletedCount = 0
    
    foreach ($Job in $ExportJobs) {
        if ($Job.ExportName -ne "N/A") {
            try {
                $ExportStatus = Get-ComplianceSearchAction -Identity $Job.ExportName -ErrorAction SilentlyContinue
                
                if ($ExportStatus) {
                    $CurrentStatus = $ExportStatus.Status
                    
                    if ($CurrentStatus -eq "Completed") {
                        $CompletedCount++
                    }
                    
                    $StatusUpdate += [PSCustomObject]@{
                        User = $Job.User
                        Status = $CurrentStatus
                        Progress = if ($ExportStatus.Results) { "Ready" } else { "Processing" }
                    }
                }
            } catch {
                $StatusUpdate += [PSCustomObject]@{
                    User = $Job.User
                    Status = "Unknown"
                    Progress = "Error checking status"
                }
            }
        }
    }
    
    Write-Host "`r[Round $MonitoringRounds/$MaxMonitoringRounds] Completed: $CompletedCount/$($ExportJobs.Count)" -NoNewline
    
    if ($CompletedCount -eq $ExportJobs.Count) {
        $AllCompleted = $true
    }
}

Write-Host "`n"

# Final status check and download instructions
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "FINAL EXPORT STATUS" -ForegroundColor Cyan
Write-Host "============================================`n" -ForegroundColor Cyan

foreach ($Job in $ExportJobs) {
    if ($Job.ExportName -ne "N/A") {
        Write-Host "User: $($Job.User)" -ForegroundColor Yellow
        Write-Host "  Search Name: $($Job.SearchName)" -ForegroundColor Gray
        Write-Host "  Export Name: $($Job.ExportName)" -ForegroundColor Gray
        
        try {
            $ExportStatus = Get-ComplianceSearchAction -Identity $Job.ExportName -ErrorAction Stop
            Write-Host "  Status: $($ExportStatus.Status)" -ForegroundColor $(if ($ExportStatus.Status -eq "Completed") { "Green" } else { "Yellow" })
            
            if ($ExportStatus.Status -eq "Completed") {
                Write-Host "  Download: Ready - Use eDiscovery Export Tool" -ForegroundColor Green
                Write-Host "  Target Path: $DownloadPath\$($Job.User.Replace('@','_'))" -ForegroundColor Gray
            }
        } catch {
            Write-Host "  Status: Error checking status" -ForegroundColor Red
        }
        Write-Host ""
    }
}

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "NEXT STEPS" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "1. Go to: https://compliance.microsoft.com/contentsearch" -ForegroundColor White
Write-Host "2. Click on each completed export" -ForegroundColor White
Write-Host "3. Click 'Download results'" -ForegroundColor White
Write-Host "4. Install the eDiscovery Export Tool if prompted" -ForegroundColor White
Write-Host "5. Specify your download path: $DownloadPath" -ForegroundColor White
Write-Host "6. PST files will be split into 10GB chunks automatically" -ForegroundColor White
Write-Host "`nNote: The eDiscovery Export Tool is required by Microsoft for downloading." -ForegroundColor Yellow
Write-Host "Direct download via PowerShell is not supported for compliance reasons.`n" -ForegroundColor Yellow

# Disconnect
Write-Host "Disconnecting from Security & Compliance Center..." -ForegroundColor Cyan
Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
Write-Host "Script completed!" -ForegroundColor Green
