<#
.SYNOPSIS
    Scans a folder for top-level directories older than 5 years and optionally archives them.

.DESCRIPTION
    This script scans D:\Active_Files, identifies top-level folders where the newest file/folder
    modification date is older than 5 years, generates a report, and optionally moves them to
    an archive location. By default, the script only generates a report - you must use the
    -Execute flag to actually move folders.

.NOTES
    File Name      : Archive-OldFolders.ps1
    Author         : Bryan Faulkner
    Prerequisite   : PowerShell 5.1 or higher
    Version        : 2.0.0
    Date           : 2025-02-03

.PARAMETER Execute
    Actually perform the archive operation. Without this flag, only a report is generated.

.PARAMETER Force
    Skip confirmation prompt when using -Execute (still shows preview).

.EXAMPLE
    .\Archive-OldFolders.ps1
    Scans D:\Active_Files and generates a report of folders older than 5 years.
    Does NOT move anything.

.EXAMPLE
    .\Archive-OldFolders.ps1 -Execute
    Scans, shows preview, asks for confirmation, then archives folders older than 5 years.

.EXAMPLE
    .\Archive-OldFolders.ps1 -Execute -Force
    Archives folders without confirmation prompt (still shows preview).
#>

#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory=$false)]
    [switch]$Execute,
    
    [Parameter(Mandatory=$false)]
    [switch]$Force
)

# Script configuration
$SourcePath = "D:\Active_Files"
$ArchivePath = "\\BKPSERVER\Active_Files_Archive"
$YearsOld = 5
$CutoffDate = (Get-Date).AddYears(-$YearsOld)
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$ReportPath = Join-Path -Path $ScriptPath -ChildPath "FolderAgeReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
$LogPath = Join-Path -Path $ScriptPath -ChildPath "ArchiveOperation_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# Initialize logging function
function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('INFO','WARNING','ERROR','SUCCESS')]
        [string]$Level = 'INFO'
    )
    
    $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $LogMessage = "$Timestamp [$Level] $Message"
    Add-Content -Path $LogPath -Value $LogMessage
    
    switch ($Level) {
        'INFO'    { Write-Host $LogMessage -ForegroundColor Cyan }
        'SUCCESS' { Write-Host $LogMessage -ForegroundColor Green }
        'WARNING' { Write-Host $LogMessage -ForegroundColor Yellow }
        'ERROR'   { Write-Host $LogMessage -ForegroundColor Red }
    }
}

# Function to get the newest date and total size recursively
function Get-FolderStatistics {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,
        
        [Parameter(Mandatory=$false)]
        [ref]$ErrorCount
    )
    
    $NewestDate = $null
    $TotalSize = 0
    
    try {
        # Get the folder's own LastWriteTime
        $FolderInfo = Get-Item -Path $Path -ErrorAction Stop
        $NewestDate = $FolderInfo.LastWriteTime
        
        # Manually recurse to handle errors better
        $ItemsToProcess = New-Object System.Collections.Queue
        $ItemsToProcess.Enqueue($Path)
        
        while ($ItemsToProcess.Count -gt 0) {
            $CurrentPath = $ItemsToProcess.Dequeue()
            
            try {
                # Get items in current directory
                $Items = Get-ChildItem -Path $CurrentPath -Force -ErrorAction Stop
                
                foreach ($Item in $Items) {
                    # Update newest date
                    if ($Item.LastWriteTime -gt $NewestDate) {
                        $NewestDate = $Item.LastWriteTime
                    }
                    
                    if ($Item.PSIsContainer) {
                        # Add directory to queue for processing
                        $ItemsToProcess.Enqueue($Item.FullName)
                    }
                    else {
                        # Add file size
                        if ($null -ne $Item.Length) {
                            $TotalSize += $Item.Length
                        }
                    }
                }
            }
            catch [System.UnauthorizedAccessException] {
                Write-Log -Message "  Access denied to subfolder: $CurrentPath" -Level 'WARNING'
                if ($ErrorCount) {
                    $ErrorCount.Value++
                }
            }
            catch {
                Write-Log -Message "  Error accessing subfolder $CurrentPath : $($_.Exception.Message)" -Level 'WARNING'
                if ($ErrorCount) {
                    $ErrorCount.Value++
                }
            }
        }
    }
    catch [System.UnauthorizedAccessException] {
        Write-Log -Message "Access denied to: $Path" -Level 'WARNING'
        if ($ErrorCount) {
            $ErrorCount.Value++
        }
    }
    catch {
        Write-Log -Message "Error accessing $Path : $($_.Exception.Message)" -Level 'ERROR'
        if ($ErrorCount) {
            $ErrorCount.Value++
        }
    }
    
    return @{
        NewestDate = $NewestDate
        TotalSize = $TotalSize
    }
}

# Function to move folder with error handling
function Move-FolderToArchive {
    param(
        [Parameter(Mandatory=$true)]
        [string]$SourcePath,
        
        [Parameter(Mandatory=$true)]
        [string]$DestinationPath,
        
        [Parameter(Mandatory=$true)]
        [string]$FolderName
    )
    
    try {
        $DestinationFullPath = Join-Path -Path $DestinationPath -ChildPath $FolderName
        
        # Check if destination already exists
        if (Test-Path -Path $DestinationFullPath) {
            Write-Log -Message "  WARNING: Destination already exists: $DestinationFullPath" -Level 'WARNING'
            Write-Log -Message "  Skipping to prevent overwrite..." -Level 'WARNING'
            return $false
        }
        
        # Perform the move
        Move-Item -Path $SourcePath -Destination $DestinationFullPath -Force -ErrorAction Stop
        Write-Log -Message "  Successfully moved: $FolderName" -Level 'SUCCESS'
        return $true
    }
    catch {
        Write-Log -Message "  ERROR moving $FolderName : $($_.Exception.Message)" -Level 'ERROR'
        return $false
    }
}

# Main script execution
try {
    Write-Log -Message "========================================" -Level 'INFO'
    Write-Log -Message "Starting Folder Age Analysis & Archive Script" -Level 'INFO'
    Write-Log -Message "Source Location: $SourcePath" -Level 'INFO'
    Write-Log -Message "Archive Location: $ArchivePath" -Level 'INFO'
    Write-Log -Message "Cutoff Date: $($CutoffDate.ToString('yyyy-MM-dd')) (older than $YearsOld years)" -Level 'INFO'
    Write-Log -Message "Execution Mode: $(if ($Execute) { 'ARCHIVE MODE' } else { 'REPORT ONLY' })" -Level 'INFO'
    Write-Log -Message "========================================" -Level 'INFO'
    
    # Verify source path is accessible
    if (-not (Test-Path -Path $SourcePath)) {
        throw "Source path is not accessible: $SourcePath"
    }
    
    Write-Log -Message "Source path is accessible. Beginning scan..." -Level 'INFO'
    
    # Get all top-level folders
    $TopLevelFolders = Get-ChildItem -Path $SourcePath -Directory -ErrorAction Stop
    
    if ($TopLevelFolders.Count -eq 0) {
        Write-Log -Message "No top-level folders found in $SourcePath" -Level 'WARNING'
        return
    }
    
    Write-Log -Message "Found $($TopLevelFolders.Count) top-level folders to process" -Level 'INFO'
    
    # Initialize results array
    $AllResults = @()
    $ErrorCount = 0
    $CurrentFolder = 0
    
    # Process each top-level folder
    foreach ($Folder in $TopLevelFolders) {
        $CurrentFolder++
        $PercentComplete = [math]::Round(($CurrentFolder / $TopLevelFolders.Count) * 100, 2)
        
        Write-Progress -Activity "Scanning Top-Level Folders" `
                       -Status "Processing: $($Folder.Name) ($CurrentFolder of $($TopLevelFolders.Count))" `
                       -PercentComplete $PercentComplete
        
        Write-Log -Message "[$CurrentFolder/$($TopLevelFolders.Count)] Processing folder: $($Folder.Name)" -Level 'INFO'
        
        # Get folder statistics (newest date and total size)
        $ErrorCountRef = [ref]$ErrorCount
        $FolderStats = Get-FolderStatistics -Path $Folder.FullName -ErrorCount $ErrorCountRef
        
        # Convert size to human-readable format
        $SizeInGB = [math]::Round($FolderStats.TotalSize / 1GB, 2)
        $SizeInMB = [math]::Round($FolderStats.TotalSize / 1MB, 2)
        $SizeDisplay = if ($SizeInGB -ge 1) { "$SizeInGB GB" } else { "$SizeInMB MB" }
        
        # Calculate age in years
        if ($FolderStats.NewestDate) {
            $AgeInDays = (Get-Date) - $FolderStats.NewestDate
            $AgeInYears = [math]::Round($AgeInDays.TotalDays / 365.25, 2)
        }
        else {
            $AgeInYears = "Unknown"
        }
        
        # Create result object
        $Result = [PSCustomObject]@{
            FolderName = $Folder.Name
            FolderPath = $Folder.FullName
            NewestModifiedDate = if ($FolderStats.NewestDate) { $FolderStats.NewestDate } else { "Unable to determine" }
            AgeInYears = $AgeInYears
            OlderThanCutoff = if ($FolderStats.NewestDate) { $FolderStats.NewestDate -lt $CutoffDate } else { $false }
            FolderSizeBytes = $FolderStats.TotalSize
            FolderSizeDisplay = $SizeDisplay
            FolderCreatedDate = $Folder.CreationTime
            FolderLastModified = $Folder.LastWriteTime
        }
        
        $AllResults += $Result
        
        Write-Log -Message "  Newest date: $($Result.NewestModifiedDate) | Age: $AgeInYears years | Size: $($Result.FolderSizeDisplay)" -Level 'INFO'
    }
    
    Write-Progress -Activity "Scanning Top-Level Folders" -Completed
    
    # Filter folders older than cutoff
    $FoldersToArchive = $AllResults | Where-Object { $_.OlderThanCutoff -eq $true }
    
    # Sort all results by age (descending)
    $AllResults = $AllResults | Sort-Object -Property NewestModifiedDate
    
    # Export full report to CSV
    Write-Log -Message "Exporting full report to CSV..." -Level 'INFO'
    $AllResults | Export-Csv -Path $ReportPath -NoTypeInformation -Encoding UTF8
    Write-Log -Message "Report saved to: $ReportPath" -Level 'SUCCESS'
    
    # Display summary
    Write-Log -Message "" -Level 'INFO'
    Write-Log -Message "========================================" -Level 'INFO'
    Write-Log -Message "SCAN SUMMARY" -Level 'INFO'
    Write-Log -Message "========================================" -Level 'INFO'
    Write-Log -Message "Total folders scanned: $($AllResults.Count)" -Level 'INFO'
    Write-Log -Message "Folders older than $YearsOld years: $($FoldersToArchive.Count)" -Level 'INFO'
    Write-Log -Message "Access errors encountered: $ErrorCount" -Level 'INFO'
    Write-Log -Message "========================================" -Level 'INFO'
    
    if ($FoldersToArchive.Count -eq 0) {
        Write-Log -Message "No folders found that meet the archive criteria (older than $YearsOld years)" -Level 'INFO'
        Write-Log -Message "All folders have been modified since $($CutoffDate.ToString('yyyy-MM-dd'))" -Level 'INFO'
        return
    }
    
    # Display folders that would be/will be archived
    Write-Host "`n========================================" -ForegroundColor Yellow
    Write-Host "FOLDERS OLDER THAN $YearsOld YEARS:" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    
    foreach ($Folder in $FoldersToArchive) {
        $ModDate = if ($Folder.NewestModifiedDate -is [DateTime]) { 
            $Folder.NewestModifiedDate.ToString('yyyy-MM-dd') 
        } else { 
            $Folder.NewestModifiedDate 
        }
        Write-Host "  - $($Folder.FolderName)" -ForegroundColor White
        Write-Host "    Last Modified: $ModDate | Age: $($Folder.AgeInYears) years | Size: $($Folder.FolderSizeDisplay)" -ForegroundColor Gray
    }
    
    Write-Host "========================================`n" -ForegroundColor Yellow
    
    # If not in Execute mode, stop here
    if (-not $Execute) {
        Write-Host "REPORT-ONLY MODE" -ForegroundColor Cyan
        Write-Host "No folders have been moved. To archive these folders, run the script with the -Execute flag:" -ForegroundColor Cyan
        Write-Host "  .\Archive-OldFolders.ps1 -Execute" -ForegroundColor White
        Write-Host "" -ForegroundColor Cyan
        Write-Log -Message "Script completed in REPORT-ONLY mode. No folders were moved." -Level 'INFO'
        Write-Log -Message "To execute the archive operation, run with -Execute flag" -Level 'INFO'
        return
    }
    
    # EXECUTE MODE - Actually move folders
    Write-Log -Message "" -Level 'INFO'
    Write-Log -Message "========================================" -Level 'WARNING'
    Write-Log -Message "EXECUTE MODE ENABLED" -Level 'WARNING'
    Write-Log -Message "Folders will be MOVED to archive location" -Level 'WARNING'
    Write-Log -Message "========================================" -Level 'WARNING'
    
    # Confirmation prompt (unless Force is specified)
    if (-not $Force) {
        Write-Host "Do you want to proceed with archiving these $($FoldersToArchive.Count) folders? (Y/N): " -ForegroundColor Cyan -NoNewline
        $Response = Read-Host
        
        if ($Response -ne 'Y' -and $Response -ne 'y') {
            Write-Log -Message "Operation cancelled by user" -Level 'WARNING'
            return
        }
    }
    
    Write-Log -Message "" -Level 'INFO'
    Write-Log -Message "Beginning archive operation..." -Level 'INFO'
    
    # Create archive folder if it doesn't exist
    if (-not (Test-Path -Path $ArchivePath)) {
        Write-Log -Message "Archive folder does not exist. Creating: $ArchivePath" -Level 'INFO'
        try {
            New-Item -Path $ArchivePath -ItemType Directory -Force -ErrorAction Stop | Out-Null
            Write-Log -Message "Archive folder created successfully" -Level 'SUCCESS'
        }
        catch {
            throw "Failed to create archive folder: $($_.Exception.Message)"
        }
    }
    else {
        Write-Log -Message "Archive folder exists: $ArchivePath" -Level 'INFO'
    }
    
    # Archive each folder
    $SuccessCount = 0
    $FailureCount = 0
    $SkipCount = 0
    $CurrentArchiveFolder = 0
    
    foreach ($Folder in $FoldersToArchive) {
        $CurrentArchiveFolder++
        $PercentComplete = [math]::Round(($CurrentArchiveFolder / $FoldersToArchive.Count) * 100, 2)
        
        Write-Progress -Activity "Archiving Folders" `
                       -Status "Processing: $($Folder.FolderName) ($CurrentArchiveFolder of $($FoldersToArchive.Count))" `
                       -PercentComplete $PercentComplete
        
        Write-Log -Message "[$CurrentArchiveFolder/$($FoldersToArchive.Count)] Archiving: $($Folder.FolderName)" -Level 'INFO'
        
        # Verify source folder still exists
        if (-not (Test-Path -Path $Folder.FolderPath)) {
            Write-Log -Message "  Source folder no longer exists: $($Folder.FolderPath)" -Level 'WARNING'
            $SkipCount++
            continue
        }
        
        # Move the folder
        $MoveResult = Move-FolderToArchive -SourcePath $Folder.FolderPath `
                                           -DestinationPath $ArchivePath `
                                           -FolderName $Folder.FolderName
        
        if ($MoveResult) {
            $SuccessCount++
        }
        else {
            $FailureCount++
        }
    }
    
    Write-Progress -Activity "Archiving Folders" -Completed
    
    # Final summary
    Write-Log -Message "" -Level 'INFO'
    Write-Log -Message "========================================" -Level 'INFO'
    Write-Log -Message "Archive Operation Complete!" -Level 'SUCCESS'
    Write-Log -Message "Total folders processed: $($FoldersToArchive.Count)" -Level 'INFO'
    Write-Log -Message "Successfully archived: $SuccessCount" -Level 'SUCCESS'
    Write-Log -Message "Failed to archive: $FailureCount" -Level $(if ($FailureCount -gt 0) { 'WARNING' } else { 'INFO' })
    Write-Log -Message "Skipped (not found): $SkipCount" -Level $(if ($SkipCount -gt 0) { 'WARNING' } else { 'INFO' })
    Write-Log -Message "Archive location: $ArchivePath" -Level 'INFO'
    Write-Log -Message "Report file: $ReportPath" -Level 'INFO'
    Write-Log -Message "Log file: $LogPath" -Level 'INFO'
    Write-Log -Message "========================================" -Level 'INFO'
    
    # Offer to open archive location
    if ($SuccessCount -gt 0) {
        Write-Host "`nWould you like to open the archive location? (Y/N): " -ForegroundColor Cyan -NoNewline
        $Response = Read-Host
        if ($Response -eq 'Y' -or $Response -eq 'y') {
            Start-Process explorer.exe -ArgumentList $ArchivePath
        }
    }
}
catch {
    Write-Log -Message "FATAL ERROR: $($_.Exception.Message)" -Level 'ERROR'
    Write-Log -Message "Stack Trace: $($_.ScriptStackTrace)" -Level 'ERROR'
    throw
}
finally {
    Write-Log -Message "Script execution ended" -Level 'INFO'
    
    # Always offer to open report
    if (Test-Path -Path $ReportPath) {
        Write-Host "`nWould you like to open the report file? (Y/N): " -ForegroundColor Cyan -NoNewline
        $Response = Read-Host
        if ($Response -eq 'Y' -or $Response -eq 'y') {
            Start-Process explorer.exe -ArgumentList "/select,`"$ReportPath`""
        }
    }
}
