<#
.SYNOPSIS
    Downloads all OneDrive and SharePoint document library data from an Office 365 tenant.

.DESCRIPTION
    This script connects to Microsoft Graph, enumerates all users' OneDrive sites and SharePoint sites,
    generates a pre-download report with size estimates, and downloads all content with preserved folder structure.

.PARAMETER OutputPath
    Local path where data will be downloaded. Default: C:\M365TenantBackup

.EXAMPLE
    .\Download-M365TenantData.ps1 -OutputPath "E:\Backups\M365Data"

.NOTES
    Requirements:
    - Microsoft.Graph PowerShell module
    - Global Admin or SharePoint Admin permissions
    - Sufficient local storage space
    
    Version: 1.0.0
    Author: Generated for Quality Computer Solutions
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$OutputPath = "C:\M365TenantBackup"
)

#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Sites, Microsoft.Graph.Users

# Script variables
$ErrorActionPreference = "Continue"
$ProgressPreference = "Continue"
$script:DownloadReport = @()
$script:TotalSize = 0
$script:TotalFiles = 0
$script:ErrorLog = @()
$LogFile = Join-Path $OutputPath "Download-Log-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"

#region Helper Functions

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('Info','Warning','Error','Success')]
        [string]$Level = 'Info'
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    $color = switch($Level) {
        'Info' { 'Cyan' }
        'Warning' { 'Yellow' }
        'Error' { 'Red' }
        'Success' { 'Green' }
    }
    
    Write-Host $logMessage -ForegroundColor $color
    Add-Content -Path $LogFile -Value $logMessage
}

function Format-FileSize {
    param([long]$Bytes)
    
    if ($Bytes -ge 1TB) { return "{0:N2} TB" -f ($Bytes / 1TB) }
    elseif ($Bytes -ge 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    elseif ($Bytes -ge 1MB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
    elseif ($Bytes -ge 1KB) { return "{0:N2} KB" -f ($Bytes / 1KB) }
    else { return "$Bytes Bytes" }
}

function Get-SafeFileName {
    param([string]$FileName)
    
    $invalidChars = [System.IO.Path]::GetInvalidFileNameChars()
    $safeName = $FileName
    foreach ($char in $invalidChars) {
        $safeName = $safeName.Replace($char, '_')
    }
    return $safeName
}

function Get-DriveItems {
    param(
        [string]$SiteId,
        [string]$DriveId,
        [string]$FolderPath = "",
        [string]$ItemId = "root"
    )
    
    $items = @()
    $uri = "https://graph.microsoft.com/v1.0/sites/$SiteId/drives/$DriveId/items/$ItemId/children"
    
    try {
        do {
            $response = Invoke-MgGraphRequest -Uri $uri -Method GET
            
            foreach ($item in $response.value) {
                $itemInfo = [PSCustomObject]@{
                    Name = $item.name
                    Path = if ($FolderPath) { "$FolderPath/$($item.name)" } else { $item.name }
                    Size = if ($item.size) { $item.size } else { 0 }
                    IsFolder = $null -ne $item.folder
                    Id = $item.id
                    DownloadUrl = $item.'@microsoft.graph.downloadUrl'
                    WebUrl = $item.webUrl
                }
                
                $items += $itemInfo
                
                # Recursively get child items if it's a folder
                if ($itemInfo.IsFolder) {
                    $childItems = Get-DriveItems -SiteId $SiteId -DriveId $DriveId -FolderPath $itemInfo.Path -ItemId $item.id
                    $items += $childItems
                }
            }
            
            $uri = $response.'@odata.nextLink'
        } while ($uri)
        
    } catch {
        Write-Log "Error retrieving items: $($_.Exception.Message)" -Level Error
        $script:ErrorLog += "Error retrieving items from DriveId $DriveId, ItemId $ItemId : $($_.Exception.Message)"
    }
    
    return $items
}

function Download-DriveItem {
    param(
        [PSCustomObject]$Item,
        [string]$DestinationPath
    )
    
    try {
        $fullPath = Join-Path $DestinationPath $Item.Path
        $directory = Split-Path $fullPath -Parent
        
        if (-not (Test-Path $directory)) {
            New-Item -Path $directory -ItemType Directory -Force | Out-Null
        }
        
        if (-not $Item.IsFolder -and $Item.DownloadUrl) {
            $safeFileName = Get-SafeFileName (Split-Path $Item.Path -Leaf)
            $fullPath = Join-Path (Split-Path $fullPath -Parent) $safeFileName
            
            Invoke-WebRequest -Uri $Item.DownloadUrl -OutFile $fullPath -UseBasicParsing
            Write-Log "Downloaded: $($Item.Path)" -Level Info
            return $true
        }
    } catch {
        Write-Log "Error downloading $($Item.Path): $($_.Exception.Message)" -Level Error
        $script:ErrorLog += "Failed to download: $($Item.Path) - $($_.Exception.Message)"
        return $false
    }
}

#endregion

#region Main Script

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Microsoft 365 Tenant Data Download" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Create output directory
if (-not (Test-Path $OutputPath)) {
    New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    Write-Log "Created output directory: $OutputPath" -Level Info
}

# Connect to Microsoft Graph
Write-Log "Connecting to Microsoft Graph..." -Level Info
try {
    Connect-MgGraph -Scopes "Sites.Read.All", "Files.Read.All", "User.Read.All" -NoWelcome
    Write-Log "Successfully connected to Microsoft Graph" -Level Success
} catch {
    Write-Log "Failed to connect to Microsoft Graph: $($_.Exception.Message)" -Level Error
    exit 1
}

# Get tenant info
$context = Get-MgContext
Write-Log "Connected to tenant: $($context.TenantId)" -Level Info

Write-Host "`n--- Phase 1: Discovery and Report Generation ---`n" -ForegroundColor Yellow

#region OneDrive Discovery

Write-Log "Discovering OneDrive sites..." -Level Info
$oneDriveData = @()

try {
    $users = Get-MgUser -All -Property Id, DisplayName, UserPrincipalName, Mail
    Write-Log "Found $($users.Count) users" -Level Info
    
    $userCount = 0
    foreach ($user in $users) {
        $userCount++
        Write-Progress -Activity "Scanning OneDrive Sites" -Status "Processing $($user.UserPrincipalName)" -PercentComplete (($userCount / $users.Count) * 100)
        
        try {
            # Get user's OneDrive
            $drive = Get-MgUserDrive -UserId $user.Id -ErrorAction SilentlyContinue
            
            if ($drive) {
                Write-Log "Scanning OneDrive for: $($user.UserPrincipalName)" -Level Info
                
                # Get all items in the drive
                $items = Get-DriveItems -SiteId $user.Id -DriveId $drive.Id
                
                $totalSize = ($items | Where-Object { -not $_.IsFolder } | Measure-Object -Property Size -Sum).Sum
                $fileCount = ($items | Where-Object { -not $_.IsFolder }).Count
                
                $oneDriveData += [PSCustomObject]@{
                    Type = "OneDrive"
                    Owner = $user.UserPrincipalName
                    DisplayName = $user.DisplayName
                    SiteId = $user.Id
                    DriveId = $drive.Id
                    DriveName = $drive.Name
                    Items = $items
                    TotalSize = $totalSize
                    FileCount = $fileCount
                }
                
                $script:TotalSize += $totalSize
                $script:TotalFiles += $fileCount
                
                Write-Log "  Files: $fileCount | Size: $(Format-FileSize $totalSize)" -Level Info
            }
        } catch {
            Write-Log "Error accessing OneDrive for $($user.UserPrincipalName): $($_.Exception.Message)" -Level Warning
            $script:ErrorLog += "OneDrive access error for $($user.UserPrincipalName): $($_.Exception.Message)"
        }
    }
} catch {
    Write-Log "Error during OneDrive discovery: $($_.Exception.Message)" -Level Error
    $script:ErrorLog += "OneDrive discovery error: $($_.Exception.Message)"
}

Write-Progress -Activity "Scanning OneDrive Sites" -Completed

#endregion

#region SharePoint Discovery

Write-Log "`nDiscovering SharePoint sites..." -Level Info
$sharePointData = @()

try {
    # Get all SharePoint sites
    $sites = Get-MgSite -All -Property Id, DisplayName, WebUrl, SiteCollection
    Write-Log "Found $($sites.Count) SharePoint sites" -Level Info
    
    $siteCount = 0
    foreach ($site in $sites) {
        $siteCount++
        Write-Progress -Activity "Scanning SharePoint Sites" -Status "Processing $($site.DisplayName)" -PercentComplete (($siteCount / $sites.Count) * 100)
        
        try {
            Write-Log "Scanning SharePoint site: $($site.DisplayName)" -Level Info
            
            # Get all document libraries (drives) in the site
            $drives = Get-MgSiteDrive -SiteId $site.Id -All
            
            foreach ($drive in $drives) {
                # Only process document libraries (skip other list types)
                if ($drive.DriveType -eq "documentLibrary") {
                    Write-Log "  Scanning library: $($drive.Name)" -Level Info
                    
                    $items = Get-DriveItems -SiteId $site.Id -DriveId $drive.Id
                    
                    $totalSize = ($items | Where-Object { -not $_.IsFolder } | Measure-Object -Property Size -Sum).Sum
                    $fileCount = ($items | Where-Object { -not $_.IsFolder }).Count
                    
                    $sharePointData += [PSCustomObject]@{
                        Type = "SharePoint"
                        SiteName = $site.DisplayName
                        SiteUrl = $site.WebUrl
                        SiteId = $site.Id
                        DriveId = $drive.Id
                        DriveName = $drive.Name
                        Items = $items
                        TotalSize = $totalSize
                        FileCount = $fileCount
                    }
                    
                    $script:TotalSize += $totalSize
                    $script:TotalFiles += $fileCount
                    
                    Write-Log "    Files: $fileCount | Size: $(Format-FileSize $totalSize)" -Level Info
                }
            }
        } catch {
            Write-Log "Error accessing SharePoint site $($site.DisplayName): $($_.Exception.Message)" -Level Warning
            $script:ErrorLog += "SharePoint site access error for $($site.DisplayName): $($_.Exception.Message)"
        }
    }
} catch {
    Write-Log "Error during SharePoint discovery: $($_.Exception.Message)" -Level Error
    $script:ErrorLog += "SharePoint discovery error: $($_.Exception.Message)"
}

Write-Progress -Activity "Scanning SharePoint Sites" -Completed

#endregion

#region Generate Report

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  DOWNLOAD REPORT" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "OneDrive Sites:" -ForegroundColor Yellow
Write-Host "  Total Users: $($oneDriveData.Count)"
Write-Host "  Total Files: $(($oneDriveData | Measure-Object -Property FileCount -Sum).Sum)"
Write-Host "  Total Size: $(Format-FileSize (($oneDriveData | Measure-Object -Property TotalSize -Sum).Sum))"

Write-Host "`nSharePoint Sites:" -ForegroundColor Yellow
Write-Host "  Total Sites: $(($sharePointData | Select-Object -Property SiteName -Unique).Count)"
Write-Host "  Total Libraries: $($sharePointData.Count)"
Write-Host "  Total Files: $(($sharePointData | Measure-Object -Property FileCount -Sum).Sum)"
Write-Host "  Total Size: $(Format-FileSize (($sharePointData | Measure-Object -Property TotalSize -Sum).Sum))"

Write-Host "`nGRAND TOTAL:" -ForegroundColor Green
Write-Host "  Files: $script:TotalFiles"
Write-Host "  Size: $(Format-FileSize $script:TotalSize)"
Write-Host "  Destination: $OutputPath"

# Export detailed report
$reportPath = Join-Path $OutputPath "Download-Report-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"
$allData = $oneDriveData + $sharePointData

$allData | Select-Object Type, 
    @{N='Location';E={if($_.Type -eq 'OneDrive'){$_.Owner}else{$_.SiteName}}},
    DriveName,
    FileCount,
    @{N='TotalSize';E={Format-FileSize $_.TotalSize}} | 
    Export-Csv -Path $reportPath -NoTypeInformation

Write-Log "`nDetailed report saved to: $reportPath" -Level Success

#endregion

#region Confirm Download

Write-Host "`n========================================" -ForegroundColor Cyan
$confirmation = Read-Host "`nProceed with download? (Y/N)"

if ($confirmation -ne 'Y') {
    Write-Log "Download cancelled by user" -Level Warning
    Disconnect-MgGraph | Out-Null
    exit 0
}

#endregion

#region Download Phase

Write-Host "`n--- Phase 2: Downloading Files ---`n" -ForegroundColor Yellow

$downloadedCount = 0
$failedCount = 0

# Download OneDrive files
foreach ($oneDrive in $oneDriveData) {
    Write-Log "`nDownloading OneDrive for: $($oneDrive.Owner)" -Level Info
    $userPath = Join-Path $OutputPath "OneDrive\$($oneDrive.Owner)"
    
    $fileItems = $oneDrive.Items | Where-Object { -not $_.IsFolder }
    $fileNum = 0
    
    foreach ($item in $fileItems) {
        $fileNum++
        Write-Progress -Activity "Downloading OneDrive: $($oneDrive.Owner)" `
                       -Status "File $fileNum of $($fileItems.Count): $($item.Name)" `
                       -PercentComplete (($fileNum / $fileItems.Count) * 100)
        
        if (Download-DriveItem -Item $item -DestinationPath $userPath) {
            $downloadedCount++
        } else {
            $failedCount++
        }
    }
}

Write-Progress -Activity "Downloading OneDrive" -Completed

# Download SharePoint files
foreach ($spSite in $sharePointData) {
    Write-Log "`nDownloading SharePoint: $($spSite.SiteName) - $($spSite.DriveName)" -Level Info
    $safeSiteName = Get-SafeFileName $spSite.SiteName
    $safeDriveName = Get-SafeFileName $spSite.DriveName
    $sitePath = Join-Path $OutputPath "SharePoint\$safeSiteName\$safeDriveName"
    
    $fileItems = $spSite.Items | Where-Object { -not $_.IsFolder }
    $fileNum = 0
    
    foreach ($item in $fileItems) {
        $fileNum++
        Write-Progress -Activity "Downloading SharePoint: $($spSite.SiteName)" `
                       -Status "File $fileNum of $($fileItems.Count): $($item.Name)" `
                       -PercentComplete (($fileNum / $fileItems.Count) * 100)
        
        if (Download-DriveItem -Item $item -DestinationPath $sitePath) {
            $downloadedCount++
        } else {
            $failedCount++
        }
    }
}

Write-Progress -Activity "Downloading SharePoint" -Completed

#endregion

#region Summary

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  DOWNLOAD COMPLETE" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Successfully downloaded: $downloadedCount files" -ForegroundColor Green
if ($failedCount -gt 0) {
    Write-Host "Failed downloads: $failedCount files" -ForegroundColor Red
}
Write-Host "Total errors logged: $($script:ErrorLog.Count)" -ForegroundColor $(if($script:ErrorLog.Count -gt 0){'Yellow'}else{'Green'})

if ($script:ErrorLog.Count -gt 0) {
    $errorLogPath = Join-Path $OutputPath "Error-Log-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
    $script:ErrorLog | Out-File -FilePath $errorLogPath
    Write-Log "Error log saved to: $errorLogPath" -Level Warning
}

Write-Log "`nAll operations complete. Check log file: $LogFile" -Level Success

# Disconnect from Graph
Disconnect-MgGraph | Out-Null

#endregion

#endregion
