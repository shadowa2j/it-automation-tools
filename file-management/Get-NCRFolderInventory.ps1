<#
.SYNOPSIS
    Scan directory structure for NCR folders and export detailed inventory
    
.DESCRIPTION
    Scans a root\client\partnumber directory structure for NCR folders and exports
    a comprehensive inventory including file counts, names, sizes, and folder locations.
    Designed for compliance tracking and file management in manufacturing environments.
    
.PARAMETER RootPath
    The root path to scan (should contain client folders)
    
.PARAMETER OutputCSV
    Path to the output CSV file (default: NCR_Folders_Report_[timestamp].csv)
    
.EXAMPLE
    .\Get-NCRFolderInventory.ps1 -RootPath "\\server\share\root"
    
.EXAMPLE
    .\Get-NCRFolderInventory.ps1 -RootPath "C:\ClientData" -OutputCSV "C:\Reports\NCR_Inventory.csv"
    
.NOTES
    Script Name: Get-NCRFolderInventory.ps1
    Author: Bryan Faulkner, with assistance from Claude
    Version: 1.0.0
    Date Created: 2025-10-20
    Date Modified: 2025-11-06
    Requires: PowerShell 5.1 or higher
    
    Version History:
    1.0.0 - 2025-11-06
        - Added proper versioning and documentation
        - Improved error handling for inaccessible folders
        - Added progress indicators
        - Enhanced CSV output formatting
        
    0.9.0 - 2025-10-20
        - Initial working version
        - Basic NCR folder scanning
        - CSV export capability
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputCSV = ".\NCR_Folders_Report_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
)

#Requires -Version 5.1

# Script version
$ScriptVersion = "1.0.0"
$ScriptName = "Get-NCRFolderInventory.ps1"
$ScriptAuthor = "Bryan Faulkner, with assistance from Claude"

# Validate root path
if (-not (Test-Path $RootPath)) {
    Write-Error "Root path does not exist: $RootPath"
    exit 1
}

# Helper function to format file size
function Format-FileSize {
    param($bytes)
    if ($bytes -lt 1KB) { return "$bytes B" }
    elseif ($bytes -lt 1MB) { return "{0:N2} KB" -f ($bytes / 1KB) }
    elseif ($bytes -lt 1GB) { return "{0:N2} MB" -f ($bytes / 1MB) }
    else { return "{0:N2} GB" -f ($bytes / 1GB) }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "NCR Folder Inventory Scanner" -ForegroundColor Cyan
Write-Host "Version $ScriptVersion" -ForegroundColor Cyan
Write-Host "Author: $ScriptAuthor" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Scanning for NCR folders in: $RootPath" -ForegroundColor Yellow
Write-Host "This may take a while depending on the number of folders...`n" -ForegroundColor Gray

# Initialize results array
$results = @()
$stats = @{
    ClientsScanned = 0
    PartNumbersScanned = 0
    NCRFoldersFound = 0
    TotalFiles = 0
    TotalSize = 0
    EmptyFolders = 0
    InaccessibleFolders = 0
}

# Get all client folders
$clientFolders = Get-ChildItem -Path $RootPath -Directory -ErrorAction SilentlyContinue
$totalClients = $clientFolders.Count

Write-Host "Found $totalClients client folders to scan`n" -ForegroundColor White

foreach ($client in $clientFolders) {
    $stats.ClientsScanned++
    $percentComplete = [math]::Round(($stats.ClientsScanned / $totalClients) * 100, 1)
    
    Write-Progress -Activity "Scanning Clients" `
        -Status "Processing $($client.Name) ($($stats.ClientsScanned) of $totalClients - $percentComplete%)" `
        -PercentComplete $percentComplete
    
    Write-Host "Scanning client: $($client.Name)" -ForegroundColor Gray
    
    # Get all partnumber folders within this client
    $partNumberFolders = Get-ChildItem -Path $client.FullName -Directory -ErrorAction SilentlyContinue
    $stats.PartNumbersScanned += $partNumberFolders.Count
    
    foreach ($partNumber in $partNumberFolders) {
        # Check if NCR folder exists
        $ncrPath = Join-Path -Path $partNumber.FullName -ChildPath "NCR"
        
        if (Test-Path -Path $ncrPath -PathType Container) {
            $stats.NCRFoldersFound++
            Write-Host "  Found NCR folder: $($client.Name)\$($partNumber.Name)\NCR" -ForegroundColor Green
            
            try {
                # Get all files in the NCR folder (including subfolders)
                $files = Get-ChildItem -Path $ncrPath -File -Recurse -ErrorAction Stop
                
                if ($files.Count -eq 0) {
                    # NCR folder exists but is empty
                    $stats.EmptyFolders++
                    $results += [PSCustomObject]@{
                        Client = $client.Name
                        PartNumber = $partNumber.Name
                        NCRPath = $ncrPath
                        FileCount = 0
                        FileName = "(Empty folder)"
                        FilePath = ""
                        FileSize = 0
                        FileSizeFormatted = "0 B"
                        LastModified = ""
                        ScanDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    }
                } else {
                    # Process each file
                    foreach ($file in $files) {
                        $stats.TotalFiles++
                        $stats.TotalSize += $file.Length
                        
                        $results += [PSCustomObject]@{
                            Client = $client.Name
                            PartNumber = $partNumber.Name
                            NCRPath = $ncrPath
                            FileCount = $files.Count
                            FileName = $file.Name
                            FilePath = $file.FullName.Replace($ncrPath, "").TrimStart('\')
                            FileSize = $file.Length
                            FileSizeFormatted = Format-FileSize -bytes $file.Length
                            LastModified = $file.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
                            ScanDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                        }
                    }
                }
            }
            catch {
                $stats.InaccessibleFolders++
                Write-Host "    ERROR: Unable to access NCR folder: $($_.Exception.Message)" -ForegroundColor Red
                
                $results += [PSCustomObject]@{
                    Client = $client.Name
                    PartNumber = $partNumber.Name
                    NCRPath = $ncrPath
                    FileCount = -1
                    FileName = "(Access Denied)"
                    FilePath = $_.Exception.Message
                    FileSize = 0
                    FileSizeFormatted = "N/A"
                    LastModified = ""
                    ScanDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                }
            }
        }
    }
}

Write-Progress -Activity "Scanning Clients" -Completed

# Export results to CSV
Write-Host "`nExporting results to CSV..." -ForegroundColor Yellow
try {
    $results | Export-Csv -Path $OutputCSV -NoTypeInformation -Encoding UTF8
    Write-Host "CSV exported successfully: $OutputCSV" -ForegroundColor Green
}
catch {
    Write-Error "Failed to export CSV: $($_.Exception.Message)"
}

# Display summary statistics
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Scan Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Clients scanned: $($stats.ClientsScanned)" -ForegroundColor White
Write-Host "Part numbers scanned: $($stats.PartNumbersScanned)" -ForegroundColor White
Write-Host "NCR folders found: $($stats.NCRFoldersFound)" -ForegroundColor Green
Write-Host "  - Empty folders: $($stats.EmptyFolders)" -ForegroundColor Yellow
Write-Host "  - Inaccessible folders: $($stats.InaccessibleFolders)" -ForegroundColor Red
Write-Host "Total files found: $($stats.TotalFiles)" -ForegroundColor White
Write-Host "Total size: $(Format-FileSize -bytes $stats.TotalSize)" -ForegroundColor White
Write-Host "`nResults exported to: $OutputCSV" -ForegroundColor Gray
Write-Host "========================================`n" -ForegroundColor Cyan

# Display sample of results
if ($results.Count -gt 0) {
    Write-Host "Sample Results (first 10 entries):" -ForegroundColor Yellow
    $results | Select-Object -First 10 | Format-Table -Property Client, PartNumber, FileName, FileSizeFormatted, LastModified -AutoSize
    
    if ($results.Count -gt 10) {
        Write-Host "... (Showing first 10 of $($results.Count) total entries. See CSV for complete results)" -ForegroundColor Gray
    }
}
