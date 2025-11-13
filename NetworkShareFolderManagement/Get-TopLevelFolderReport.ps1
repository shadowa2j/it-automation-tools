<#
.SYNOPSIS
    Scans a network share and reports the newest modification date for each top-level folder.

.DESCRIPTION
    This script recursively scans all folders and files under each top-level folder in a network share,
    identifies the newest LastWriteTime from any file or folder within each top-level folder,
    and exports the results to a CSV report.

.NOTES
    File Name      : Get-TopLevelFolderReport.ps1
    Author         : Bryan Jackson
    Prerequisite   : PowerShell 5.1 or higher
    Version        : 1.1.0
    Date           : 2025-11-13

.EXAMPLE
    .\Get-TopLevelFolderReport.ps1
    Scans \\ecpsyn\Shares\Public and generates a CSV report in the same directory as the script.
#>

#Requires -Version 5.1

# Script configuration
$NetworkSharePath = "\\ecpsyn\Shares\Public"
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$ReportPath = Join-Path -Path $ScriptPath -ChildPath "TopLevelFolderReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
$LogPath = Join-Path -Path $ScriptPath -ChildPath "TopLevelFolderReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# Initialize logging function
function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('INFO','WARNING','ERROR')]
        [string]$Level = 'INFO'
    )
    
    $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $LogMessage = "$Timestamp [$Level] $Message"
    Add-Content -Path $LogPath -Value $LogMessage
    
    switch ($Level) {
        'INFO'    { Write-Host $LogMessage -ForegroundColor Green }
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
        
        # Get all child items (files and folders) recursively
        $ChildItems = Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
        
        # Compare each item's LastWriteTime to find the newest and calculate total size
        foreach ($Item in $ChildItems) {
            if ($Item.LastWriteTime -gt $NewestDate) {
                $NewestDate = $Item.LastWriteTime
            }
            
            # Only add size for files, not directories
            if (-not $Item.PSIsContainer) {
                $TotalSize += $Item.Length
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

# Main script execution
try {
    Write-Log -Message "========================================" -Level 'INFO'
    Write-Log -Message "Starting Top-Level Folder Report Script" -Level 'INFO'
    Write-Log -Message "Network Share: $NetworkSharePath" -Level 'INFO'
    Write-Log -Message "Report will be saved to: $ReportPath" -Level 'INFO'
    Write-Log -Message "========================================" -Level 'INFO'
    
    # Verify network share is accessible
    if (-not (Test-Path -Path $NetworkSharePath)) {
        throw "Network share path is not accessible: $NetworkSharePath"
    }
    
    Write-Log -Message "Network share is accessible. Beginning scan..." -Level 'INFO'
    
    # Get all top-level folders
    $TopLevelFolders = Get-ChildItem -Path $NetworkSharePath -Directory -ErrorAction Stop
    
    if ($TopLevelFolders.Count -eq 0) {
        Write-Log -Message "No top-level folders found in $NetworkSharePath" -Level 'WARNING'
        return
    }
    
    Write-Log -Message "Found $($TopLevelFolders.Count) top-level folders to process" -Level 'INFO'
    
    # Initialize results array
    $Results = @()
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
        
        # Create result object
        $Result = [PSCustomObject]@{
            FolderName = $Folder.Name
            FolderPath = $Folder.FullName
            NewestModifiedDate = if ($FolderStats.NewestDate) { $FolderStats.NewestDate } else { "Unable to determine" }
            FolderSizeBytes = $FolderStats.TotalSize
            FolderSizeDisplay = $SizeDisplay
            FolderCreatedDate = $Folder.CreationTime
            FolderLastModified = $Folder.LastWriteTime
        }
        
        $Results += $Result
        
        Write-Log -Message "  Newest date: $($Result.NewestModifiedDate) | Size: $($Result.FolderSizeDisplay)" -Level 'INFO'
    }
    
    Write-Progress -Activity "Scanning Top-Level Folders" -Completed
    
    # Sort results by NewestModifiedDate (descending)
    $Results = $Results | Sort-Object -Property NewestModifiedDate -Descending
    
    # Export to CSV
    Write-Log -Message "Exporting results to CSV..." -Level 'INFO'
    $Results | Export-Csv -Path $ReportPath -NoTypeInformation -Encoding UTF8
    
    Write-Log -Message "========================================" -Level 'INFO'
    Write-Log -Message "Script completed successfully!" -Level 'INFO'
    Write-Log -Message "Total folders processed: $($TopLevelFolders.Count)" -Level 'INFO'
    Write-Log -Message "Total access errors encountered: $ErrorCount" -Level 'INFO'
    Write-Log -Message "Report saved to: $ReportPath" -Level 'INFO'
    Write-Log -Message "Log saved to: $LogPath" -Level 'INFO'
    Write-Log -Message "========================================" -Level 'INFO'
    
    # Open the report location
    Write-Host "`nWould you like to open the report location? (Y/N): " -ForegroundColor Cyan -NoNewline
    $Response = Read-Host
    if ($Response -eq 'Y' -or $Response -eq 'y') {
        Start-Process explorer.exe -ArgumentList "/select,`"$ReportPath`""
    }
}
catch {
    Write-Log -Message "FATAL ERROR: $($_.Exception.Message)" -Level 'ERROR'
    Write-Log -Message "Stack Trace: $($_.ScriptStackTrace)" -Level 'ERROR'
    throw
}
finally {
    Write-Log -Message "Script execution ended" -Level 'INFO'
}
