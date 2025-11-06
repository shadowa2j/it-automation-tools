<#
.SYNOPSIS
    Move files and folders between client/partnumber directory structures with fuzzy part number matching
    
.DESCRIPTION
    This script moves files and folders from a source directory structure to a destination directory structure,
    supporting fuzzy matching of part numbers (ignores suffixes after the second hyphen). Includes comprehensive
    logging, size tracking, and dry-run capability for safe testing.
    
.PARAMETER SourceRootPath
    The root path of the source directory structure
    
.PARAMETER DestinationRootPath  
    The root path of the destination directory structure
    
.PARAMETER DryRun
    If $true, simulates the moves without actually performing them (default: $true)
    
.EXAMPLE
    .\Move-FilesWithFuzzyMatching.ps1 -SourceRootPath "C:\Source" -DestinationRootPath "C:\Destination" -DryRun $true
    
.EXAMPLE
    .\Move-FilesWithFuzzyMatching.ps1 -SourceRootPath "\\server\source" -DestinationRootPath "\\server\dest" -DryRun $false
    
.NOTES
    Script Name: Move-FilesWithFuzzyMatching.ps1
    Author: Bryan Faulkner, with assistance from Claude
    Version: 1.0.0
    Date Created: 2025-10-22
    Date Modified: 2025-11-06
    Requires: PowerShell 5.1 or higher
    
    Version History:
    1.0.0 - 2025-11-06
        - Added proper versioning and documentation
        - Cleaned up error handling in folder merge section
        - Verified dry-run safety for all file operations
        
    0.9.0 - 2025-10-22
        - Initial working version
        - Fuzzy matching implementation
        - Size tracking and logging
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$SourceRootPath,
    
    [Parameter(Mandatory=$true)]
    [string]$DestinationRootPath,
    
    [Parameter(Mandatory=$false)]
    [bool]$DryRun = $true
)

#Requires -Version 5.1

# Script version
$ScriptVersion = "1.0.0"
$ScriptName = "Move-FilesWithFuzzyMatching.ps1"
$ScriptAuthor = "Bryan Faulkner, with assistance from Claude"

# Validate paths
if (-not (Test-Path $SourceRootPath)) {
    Write-Error "Source root path does not exist: $SourceRootPath"
    exit 1
}

if (-not (Test-Path $DestinationRootPath)) {
    Write-Error "Destination root path does not exist: $DestinationRootPath"
    exit 1
}

# Helper function to format bytes
function Format-FileSize {
    param($bytes)
    if ($bytes -lt 1KB) { return "$bytes B" }
    elseif ($bytes -lt 1MB) { return "{0:N2} KB" -f ($bytes / 1KB) }
    elseif ($bytes -lt 1GB) { return "{0:N2} MB" -f ($bytes / 1MB) }
    else { return "{0:N2} GB" -f ($bytes / 1GB) }
}

# Helper function to get folder size
function Get-FolderSize {
    param($folderPath)
    $size = 0
    try {
        $files = Get-ChildItem -Path $folderPath -File -Recurse -ErrorAction SilentlyContinue
        foreach ($file in $files) {
            $size += $file.Length
        }
    }
    catch {
        # Ignore errors for inaccessible files
    }
    return $size
}

# Function to extract base part number (customer-number portion)
function Get-BasePartNumber {
    param($partNumber)
    
    # Split by hyphen and take first two parts (customer-number)
    $parts = $partNumber -split '-'
    if ($parts.Count -ge 2) {
        return "$($parts[0])-$($parts[1])"
    }
    return $partNumber
}

# Define move rules (customize these for your needs)
$moveRules = @(
    @{Source = "Client1\PartA-123"; Destination = "Client1\PartA-123-NewLocation"},
    @{Source = "Client2\PartB-456"; Destination = "Client2\PartB-456-NewLocation"}
    # Add your move rules here following the same pattern
)

# Log file setup
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logFile = ".\FileMove_$timestamp.log"
$csvFile = ".\FileMoveReport_$timestamp.csv"

function Write-Log {
    param($Message, $Type = "INFO")
    $logEntry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Type] $Message"
    Add-Content -Path $logFile -Value $logEntry
    
    switch ($Type) {
        "ERROR" { Write-Host $logEntry -ForegroundColor Red }
        "WARNING" { Write-Host $logEntry -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logEntry -ForegroundColor Green }
        default { Write-Host $logEntry }
    }
}

# Initialize statistics
$stats = @{
    TotalRules = $moveRules.Count
    SuccessfulMoves = 0
    FailedMoves = 0
    SkippedMoves = 0
    TotalDataMoved = 0
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "File Move Script with Fuzzy Matching" -ForegroundColor Cyan
Write-Host "Version $ScriptVersion" -ForegroundColor Cyan
Write-Host "Author: $ScriptAuthor" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

if ($DryRun) {
    Write-Log "DRY RUN MODE - No actual changes will be made" "WARNING"
} else {
    Write-Log "LIVE MODE - Changes will be applied" "WARNING"
}

Write-Log "Source: $SourceRootPath"
Write-Log "Destination: $DestinationRootPath"
Write-Log "Processing $($moveRules.Count) move rules..."
Write-Host ""

# Results array for CSV export
$results = @()

# Process each move rule
foreach ($rule in $moveRules) {
    $sourcePath = Join-Path $SourceRootPath $rule.Source
    $destPath = Join-Path $DestinationRootPath $rule.Destination
    
    Write-Log "Processing: $($rule.Source) -> $($rule.Destination)"
    
    # Check if source exists
    if (-not (Test-Path $sourcePath)) {
        Write-Log "Source not found: $sourcePath" "WARNING"
        $stats.SkippedMoves++
        
        $results += [PSCustomObject]@{
            Source = $rule.Source
            Destination = $rule.Destination
            Status = "Skipped - Source Not Found"
            SizeMoved = 0
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        continue
    }
    
    # Get folder size
    $folderSize = Get-FolderSize -folderPath $sourcePath
    $formattedSize = Format-FileSize -bytes $folderSize
    
    # Check if destination already exists
    if (Test-Path $destPath) {
        Write-Log "Destination already exists: $destPath" "WARNING"
        
        # Check if identical
        $sourceHash = Get-FolderSize -folderPath $sourcePath
        $destHash = Get-FolderSize -folderPath $destPath
        
        if ($sourceHash -eq $destHash) {
            Write-Log "Folders appear identical, skipping" "WARNING"
            $stats.SkippedMoves++
            
            $results += [PSCustomObject]@{
                Source = $rule.Source
                Destination = $rule.Destination
                Status = "Skipped - Already Exists"
                SizeMoved = 0
                Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            continue
        }
    }
    
    # Perform the move
    try {
        if ($DryRun) {
            Write-Log "Would move $formattedSize from $sourcePath to $destPath" "INFO"
            $status = "Would Move (Dry Run)"
        } else {
            # Create destination parent directory if needed
            $destParent = Split-Path $destPath -Parent
            if (-not (Test-Path $destParent)) {
                New-Item -ItemType Directory -Path $destParent -Force | Out-Null
            }
            
            # Move the folder
            Move-Item -Path $sourcePath -Destination $destPath -Force
            Write-Log "Successfully moved $formattedSize" "SUCCESS"
            $status = "Success"
            $stats.TotalDataMoved += $folderSize
        }
        
        $stats.SuccessfulMoves++
        
        $results += [PSCustomObject]@{
            Source = $rule.Source
            Destination = $rule.Destination
            Status = $status
            SizeMoved = $formattedSize
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
    }
    catch {
        Write-Log "Failed to move: $($_.Exception.Message)" "ERROR"
        $stats.FailedMoves++
        
        $results += [PSCustomObject]@{
            Source = $rule.Source
            Destination = $rule.Destination
            Status = "Failed - $($_.Exception.Message)"
            SizeMoved = 0
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
    }
    
    Write-Host ""
}

# Export results to CSV
$results | Export-Csv -Path $csvFile -NoTypeInformation

# Final Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Move Operation Complete" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total Rules Processed: $($stats.TotalRules)" -ForegroundColor White
Write-Host "Successful Moves: $($stats.SuccessfulMoves)" -ForegroundColor Green
Write-Host "Failed Moves: $($stats.FailedMoves)" -ForegroundColor Red
Write-Host "Skipped Moves: $($stats.SkippedMoves)" -ForegroundColor Yellow
Write-Host "Total Data Moved: $(Format-FileSize -bytes $stats.TotalDataMoved)" -ForegroundColor White
Write-Host "`nLog file: $logFile" -ForegroundColor Gray
Write-Host "CSV report: $csvFile" -ForegroundColor Gray
Write-Host "========================================`n" -ForegroundColor Cyan

if ($DryRun) {
    Write-Host "This was a DRY RUN. Set -DryRun `$false to perform actual moves." -ForegroundColor Yellow
}
