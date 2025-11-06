<#
.SYNOPSIS
    Comprehensive network share permissions audit script (READ-ONLY)
    
.DESCRIPTION
    Audits all folders and subfolders in specified network shares, capturing detailed
    permission information including inheritance status, access rights, and unusual permissions.
    This script is READ-ONLY and makes NO changes to any permissions or folders.
    
.PARAMETER SharePaths
    Array of network share paths to audit (e.g., "\\server\share1", "\\server\share2")
    
.PARAMETER OutputCSV
    Path to the output CSV file (default: .\PermissionsAudit_[timestamp].csv)
    
.PARAMETER OutputHTML
    Path to the output HTML report file (default: .\PermissionsAudit_[timestamp].html)
    If not specified, no HTML report is generated.
    
.PARAMETER ShowGridView
    Switch to display results in GridView after completion
    
.PARAMETER ShowConsole
    Switch to display results in console after completion
    
.PARAMETER FilterAccount
    Optional filter to show only permissions for specific account(s).
    Supports wildcards (e.g., "*admin*", "DOMAIN\*", "Everyone")
    Can be an array of accounts to filter multiple accounts.
    
.EXAMPLE
    .\Get-FolderPermissionsAudit.ps1 -SharePaths "\\server\share1","\\server\share2" -ShowGridView -ShowConsole
    
.EXAMPLE
    .\Get-FolderPermissionsAudit.ps1 -SharePaths "\\server\share1" -FilterAccount "*admin*","Everyone" -OutputHTML ".\report.html"
    
.EXAMPLE
    .\Get-FolderPermissionsAudit.ps1 -SharePaths "\\server\share1" -FilterAccount "DOMAIN\JohnDoe" -ShowGridView
    
.NOTES
    Script Name: Get-FolderPermissionsAudit.ps1
    Author: Bryan Faulkner, with assistance from Claude
    Version: 2.0.0
    Date Created: 2025-11-06
    Date Modified: 2025-11-06
    Requires: PowerShell 5.1 or higher
    Requires: Run as account with read permissions to target shares
    
    Version History:
    2.0.0 - 2025-11-06
        - Added HTML report generation with professional formatting
        - Added account filtering capability with wildcard support
        - Enhanced error handling and progress indicators
        - Added unusual permission detection
        - Comprehensive documentation added
    
    1.0.0 - 2025-11-06
        - Initial release
        - Basic CSV export functionality
        - GridView and console output support
        - Multi-share scanning capability
    
    IMPORTANT: This script is READ-ONLY and makes NO modifications to:
    - Folder permissions
    - File permissions
    - Inheritance settings
    - ACLs or security descriptors
    - Any files or folders
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, HelpMessage="Enter network share paths (e.g., '\\server\share1','\\server\share2')")]
    [string[]]$SharePaths,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputCSV = ".\PermissionsAudit_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv",
    
    [Parameter(Mandatory=$false)]
    [string]$OutputHTML = "",
    
    [Parameter(Mandatory=$false)]
    [switch]$ShowGridView,
    
    [Parameter(Mandatory=$false)]
    [switch]$ShowConsole,
    
    [Parameter(Mandatory=$false)]
    [string[]]$FilterAccount = @()
)

#Requires -Version 5.1

# Script version
$ScriptVersion = "2.0.0"
$ScriptName = "Get-FolderPermissionsAudit.ps1"
$ScriptAuthor = "Bryan Faulkner, with assistance from Claude"

# Function to generate HTML report
function New-HTMLReport {
    param(
        [Parameter(Mandatory=$true)]
        [array]$Results,
        
        [Parameter(Mandatory=$true)]
        [string]$OutputPath,
        
        [Parameter(Mandatory=$true)]
        [int]$TotalShares,
        
        [Parameter(Mandatory=$true)]
        [array]$SharePaths
    )
    
    $unusualCount = ($Results | Where-Object { $_.IsUnusual }).Count
    $totalFolders = ($Results | Select-Object -Unique FolderPath).Count
    $disabledInheritanceCount = ($Results | Where-Object { $_.InheritanceDisabled -eq $true } | Select-Object -Unique FolderPath).Count
    $scanDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    # Build HTML
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Network Share Permissions Audit Report</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 20px;
            background-color: #f5f5f5;
        }
        .header {
            background-color: #0078d4;
            color: white;
            padding: 20px;
            border-radius: 5px;
            margin-bottom: 20px;
        }
        .header h1 {
            margin: 0;
            font-size: 28px;
        }
        .header p {
            margin: 5px 0 0 0;
            font-size: 14px;
        }
        .summary {
            background-color: white;
            padding: 20px;
            border-radius: 5px;
            margin-bottom: 20px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .summary h2 {
            margin-top: 0;
            color: #0078d4;
        }
        .stat-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin-top: 15px;
        }
        .stat-box {
            background-color: #f8f8f8;
            padding: 15px;
            border-radius: 5px;
            border-left: 4px solid #0078d4;
        }
        .stat-box.warning {
            border-left-color: #ff8c00;
        }
        .stat-box h3 {
            margin: 0 0 5px 0;
            font-size: 24px;
            color: #333;
        }
        .stat-box p {
            margin: 0;
            color: #666;
            font-size: 14px;
        }
        .section {
            background-color: white;
            padding: 20px;
            border-radius: 5px;
            margin-bottom: 20px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .section h2 {
            margin-top: 0;
            color: #0078d4;
            border-bottom: 2px solid #0078d4;
            padding-bottom: 10px;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 15px;
            font-size: 13px;
        }
        th {
            background-color: #0078d4;
            color: white;
            padding: 12px 8px;
            text-align: left;
            font-weight: 600;
            position: sticky;
            top: 0;
        }
        td {
            padding: 10px 8px;
            border-bottom: 1px solid #e0e0e0;
        }
        tr:hover {
            background-color: #f8f8f8;
        }
        .unusual {
            background-color: #fff3cd;
        }
        .unusual-badge {
            background-color: #ff8c00;
            color: white;
            padding: 3px 8px;
            border-radius: 3px;
            font-size: 11px;
            font-weight: bold;
        }
        .explicit {
            color: #d83b01;
            font-weight: bold;
        }
        .inherited {
            color: #107c10;
        }
        .deny {
            color: #d83b01;
            font-weight: bold;
        }
        .share-list {
            list-style: none;
            padding: 0;
        }
        .share-list li {
            padding: 8px;
            background-color: #f8f8f8;
            margin-bottom: 5px;
            border-radius: 3px;
            font-family: 'Courier New', monospace;
        }
        .footer {
            text-align: center;
            color: #666;
            font-size: 12px;
            margin-top: 30px;
            padding-top: 20px;
            border-top: 1px solid #ddd;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>📊 Network Share Permissions Audit Report</h1>
        <p>Generated: $scanDate | Version: $ScriptVersion | Author: $ScriptAuthor</p>
    </div>
    
    <div class="summary">
        <h2>Executive Summary</h2>
        <div class="stat-grid">
            <div class="stat-box">
                <h3>$TotalShares</h3>
                <p>Shares Scanned</p>
            </div>
            <div class="stat-box">
                <h3>$totalFolders</h3>
                <p>Unique Folders</p>
            </div>
            <div class="stat-box">
                <h3>$($Results.Count)</h3>
                <p>Total Permissions</p>
            </div>
            <div class="stat-box warning">
                <h3>$unusualCount</h3>
                <p>Unusual Permissions</p>
            </div>
            <div class="stat-box warning">
                <h3>$disabledInheritanceCount</h3>
                <p>Disabled Inheritance</p>
            </div>
        </div>
    </div>
    
    <div class="section">
        <h2>Scanned Shares</h2>
        <ul class="share-list">
"@
    
    foreach ($share in $SharePaths) {
        $html += "            <li>$share</li>`n"
    }
    
    $html += @"
        </ul>
    </div>
"@
    
    # Unusual Permissions Section
    $unusualPerms = $Results | Where-Object { $_.IsUnusual } | Sort-Object FolderPath, Account
    if ($unusualPerms.Count -gt 0) {
        $html += @"
    <div class="section">
        <h2>⚠️ Unusual Permissions ($($unusualPerms.Count) entries)</h2>
        <table>
            <thead>
                <tr>
                    <th>Folder Path</th>
                    <th>Account</th>
                    <th>Rights</th>
                    <th>Access Type</th>
                    <th>Permission Type</th>
                    <th>Reason</th>
                </tr>
            </thead>
            <tbody>
"@
        foreach ($perm in $unusualPerms) {
            $accessClass = if ($perm.AccessType -eq "Deny") { "deny" } else { "" }
            $html += @"
                <tr class="unusual">
                    <td>$($perm.FolderPath)</td>
                    <td>$($perm.Account)</td>
                    <td>$($perm.Rights)</td>
                    <td class="$accessClass">$($perm.AccessType)</td>
                    <td>$($perm.PermissionType)</td>
                    <td><span class="unusual-badge">$($perm.UnusualReason)</span></td>
                </tr>
"@
        }
        $html += @"
            </tbody>
        </table>
    </div>
"@
    }
    
    # Folders with Disabled Inheritance
    $disabledInheritance = $Results | Where-Object { $_.InheritanceDisabled -eq $true } | 
        Select-Object -Unique FolderPath, InheritanceDisabled | Sort-Object FolderPath
    if ($disabledInheritance.Count -gt 0) {
        $html += @"
    <div class="section">
        <h2>🔒 Folders with Disabled Inheritance ($($disabledInheritance.Count) folders)</h2>
        <table>
            <thead>
                <tr>
                    <th>Folder Path</th>
                </tr>
            </thead>
            <tbody>
"@
        foreach ($folder in $disabledInheritance) {
            $html += @"
                <tr>
                    <td>$($folder.FolderPath)</td>
                </tr>
"@
        }
        $html += @"
            </tbody>
        </table>
    </div>
"@
    }
    
    # All Permissions Section
    $html += @"
    <div class="section">
        <h2>📋 All Permissions ($($Results.Count) entries)</h2>
        <table>
            <thead>
                <tr>
                    <th>Share</th>
                    <th>Relative Path</th>
                    <th>Account</th>
                    <th>Rights</th>
                    <th>Access Type</th>
                    <th>Permission Type</th>
                    <th>Inheritance Disabled</th>
                    <th>Owner</th>
                </tr>
            </thead>
            <tbody>
"@
    
    foreach ($result in $Results) {
        $rowClass = if ($result.IsUnusual) { "unusual" } else { "" }
        $permTypeClass = if ($result.PermissionType -eq "Explicit") { "explicit" } else { "inherited" }
        $accessClass = if ($result.AccessType -eq "Deny") { "deny" } else { "" }
        
        $html += @"
                <tr class="$rowClass">
                    <td>$($result.SharePath)</td>
                    <td>$($result.RelativePath)</td>
                    <td>$($result.Account)</td>
                    <td>$($result.Rights)</td>
                    <td class="$accessClass">$($result.AccessType)</td>
                    <td class="$permTypeClass">$($result.PermissionType)</td>
                    <td>$($result.InheritanceDisabled)</td>
                    <td>$($result.Owner)</td>
                </tr>
"@
    }
    
    $html += @"
            </tbody>
        </table>
    </div>
    
    <div class="footer">
        <p>This is a READ-ONLY audit report. No changes were made to any permissions or folders.</p>
        <p>$ScriptName v$ScriptVersion | $ScriptAuthor</p>
    </div>
</body>
</html>
"@
    
    # Write HTML file
    $html | Out-File -FilePath $OutputPath -Encoding UTF8
}

# Function to determine if permissions are unusual
function Test-UnusualPermission {
    param(
        [string]$IdentityReference,
        [string]$FileSystemRights,
        [string]$AccessControlType
    )
    
    $unusual = $false
    $reason = @()
    
    # Check for Everyone with elevated permissions
    if ($IdentityReference -match "Everyone" -and $FileSystemRights -match "FullControl|Modify|Write") {
        $unusual = $true
        $reason += "Everyone has $FileSystemRights"
    }
    
    # Check for Users group with Full Control
    if ($IdentityReference -match "\\Users$|^Users$" -and $FileSystemRights -match "FullControl") {
        $unusual = $true
        $reason += "Users group has Full Control"
    }
    
    # Check for Authenticated Users with Full Control
    if ($IdentityReference -match "Authenticated Users" -and $FileSystemRights -match "FullControl") {
        $unusual = $true
        $reason += "Authenticated Users has Full Control"
    }
    
    # Check for Deny permissions (often unusual)
    if ($AccessControlType -eq "Deny") {
        $unusual = $true
        $reason += "Deny permission found"
    }
    
    # Check for Guest account access
    if ($IdentityReference -match "Guest") {
        $unusual = $true
        $reason += "Guest account has access"
    }
    
    return @{
        IsUnusual = $unusual
        Reason = ($reason -join "; ")
    }
}

# Function to get human-readable file system rights
function Get-ReadableRights {
    param([string]$Rights)
    
    # Common permission combinations
    $readableRights = switch -Regex ($Rights) {
        "^FullControl$" { "Full Control" }
        "^Modify, Synchronize$|^Modify$" { "Modify" }
        "^ReadAndExecute, Synchronize$|^ReadAndExecute$" { "Read & Execute" }
        "^Read, Synchronize$|^Read$" { "Read" }
        "^Write, Synchronize$|^Write$" { "Write" }
        default { $Rights }
    }
    
    return $readableRights
}

# Function to get all folders recursively with error handling
function Get-FoldersRecursive {
    param([string]$Path)
    
    $folders = @()
    
    try {
        $folders += Get-Item -Path $Path -Force -ErrorAction Stop
        $folders += Get-ChildItem -Path $Path -Directory -Recurse -Force -ErrorAction SilentlyContinue | 
            Where-Object { $_.PSIsContainer }
    }
    catch {
        Write-Warning "Unable to access path: $Path - $($_.Exception.Message)"
    }
    
    return $folders
}

# Main script execution
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Network Share Permissions Audit Tool" -ForegroundColor Cyan
Write-Host "Version $ScriptVersion" -ForegroundColor Cyan
Write-Host "Author: $ScriptAuthor" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$results = @()
$totalShares = $SharePaths.Count
$currentShare = 0

foreach ($sharePath in $SharePaths) {
    $currentShare++
    
    Write-Host "`n[$currentShare/$totalShares] Processing share: $sharePath" -ForegroundColor Yellow
    
    # Verify share is accessible
    if (-not (Test-Path -Path $sharePath)) {
        Write-Warning "Cannot access share: $sharePath - Skipping"
        continue
    }
    
    # Get all folders
    Write-Host "  → Enumerating folders..." -ForegroundColor Gray
    $folders = Get-FoldersRecursive -Path $sharePath
    $totalFolders = $folders.Count
    Write-Host "  → Found $totalFolders folders to process" -ForegroundColor Gray
    
    $currentFolder = 0
    $lastPercent = -1
    
    foreach ($folder in $folders) {
        $currentFolder++
        $percentComplete = [math]::Round(($currentFolder / $totalFolders) * 100, 1)
        
        # Update progress every 5% or every 100 folders, whichever is more frequent
        if ($percentComplete -ne $lastPercent -or $currentFolder % 100 -eq 0) {
            $lastPercent = $percentComplete
            Write-Progress -Activity "Scanning Share: $sharePath" `
                -Status "Processing folder $currentFolder of $totalFolders ($percentComplete%)" `
                -PercentComplete $percentComplete `
                -CurrentOperation $folder.FullName
        }
        
        try {
            # Get ACL for the folder
            $acl = Get-Acl -Path $folder.FullName -ErrorAction Stop
            
            # Check if inheritance is disabled
            $inheritanceDisabled = $acl.AreAccessRulesProtected
            
            # Process each access rule
            foreach ($access in $acl.Access) {
                
                # Determine if inherited or explicit
                $isInherited = $access.IsInherited
                $permissionType = if ($isInherited) { "Inherited" } else { "Explicit" }
                
                # Get readable rights
                $readableRights = Get-ReadableRights -Rights $access.FileSystemRights.ToString()
                
                # Check for unusual permissions
                $unusualCheck = Test-UnusualPermission -IdentityReference $access.IdentityReference `
                    -FileSystemRights $access.FileSystemRights `
                    -AccessControlType $access.AccessControlType
                
                # Create result object
                $result = [PSCustomObject]@{
                    SharePath = $sharePath
                    FolderPath = $folder.FullName
                    RelativePath = $folder.FullName.Replace($sharePath, "").TrimStart('\')
                    Account = $access.IdentityReference
                    Rights = $readableRights
                    RawRights = $access.FileSystemRights.ToString()
                    AccessType = $access.AccessControlType
                    PermissionType = $permissionType
                    InheritanceDisabled = $inheritanceDisabled
                    InheritanceFlags = $access.InheritanceFlags
                    PropagationFlags = $access.PropagationFlags
                    IsUnusual = $unusualCheck.IsUnusual
                    UnusualReason = $unusualCheck.Reason
                    Owner = $acl.Owner
                    ScanDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                }
                
                $results += $result
            }
        }
        catch {
            Write-Warning "Error processing folder: $($folder.FullName) - $($_.Exception.Message)"
            
            # Add error record
            $errorResult = [PSCustomObject]@{
                SharePath = $sharePath
                FolderPath = $folder.FullName
                RelativePath = $folder.FullName.Replace($sharePath, "").TrimStart('\')
                Account = "ERROR"
                Rights = "Unable to retrieve"
                RawRights = $_.Exception.Message
                AccessType = "N/A"
                PermissionType = "N/A"
                InheritanceDisabled = "N/A"
                InheritanceFlags = "N/A"
                PropagationFlags = "N/A"
                IsUnusual = $false
                UnusualReason = ""
                Owner = "N/A"
                ScanDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            
            $results += $errorResult
        }
    }
    
    Write-Progress -Activity "Scanning Share: $sharePath" -Completed
    Write-Host "  ✓ Completed processing $sharePath" -ForegroundColor Green
}

# Apply account filter if specified
$unfilteredCount = $results.Count
if ($FilterAccount.Count -gt 0) {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Applying Account Filter" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Filter criteria: $($FilterAccount -join ', ')" -ForegroundColor Yellow
    Write-Host "Entries before filtering: $unfilteredCount" -ForegroundColor Gray
    
    $filteredResults = @()
    foreach ($filter in $FilterAccount) {
        $filteredResults += $results | Where-Object { $_.Account -like $filter }
    }
    
    # Remove duplicates if any account matched multiple filters
    $results = $filteredResults | Sort-Object -Property FolderPath, Account -Unique
    
    Write-Host "Entries after filtering: $($results.Count)" -ForegroundColor Green
    
    if ($results.Count -eq 0) {
        Write-Warning "No permissions found matching the specified account filter(s). No output will be generated."
        Write-Host "`nFilter criteria used: $($FilterAccount -join ', ')" -ForegroundColor Yellow
        exit
    }
}

# Summary statistics
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Scan Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total shares scanned: $totalShares" -ForegroundColor White
if ($FilterAccount.Count -gt 0) {
    Write-Host "Total permission entries (unfiltered): $unfilteredCount" -ForegroundColor Gray
    Write-Host "Total permission entries (filtered): $($results.Count)" -ForegroundColor White
} else {
    Write-Host "Total permission entries: $($results.Count)" -ForegroundColor White
}
Write-Host "Unique folders scanned: $(($results | Select-Object -Unique FolderPath).Count)" -ForegroundColor White
Write-Host "Unusual permissions found: $(($results | Where-Object { $_.IsUnusual }).Count)" -ForegroundColor Yellow
Write-Host "Folders with disabled inheritance: $(($results | Where-Object { $_.InheritanceDisabled -eq $true } | Select-Object -Unique FolderPath).Count)" -ForegroundColor Yellow

# Export to CSV
Write-Host "`nExporting results to CSV..." -ForegroundColor Gray
try {
    $results | Export-Csv -Path $OutputCSV -NoTypeInformation -Encoding UTF8
    Write-Host "✓ CSV exported successfully: $OutputCSV" -ForegroundColor Green
}
catch {
    Write-Error "Failed to export CSV: $($_.Exception.Message)"
}

# Export to HTML if specified
if ($OutputHTML -ne "") {
    Write-Host "`nGenerating HTML report..." -ForegroundColor Gray
    try {
        New-HTMLReport -Results $results -OutputPath $OutputHTML -TotalShares $totalShares -SharePaths $SharePaths
        Write-Host "✓ HTML report generated successfully: $OutputHTML" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to generate HTML report: $($_.Exception.Message)"
    }
}

# Display in GridView if requested
if ($ShowGridView) {
    Write-Host "`nOpening results in GridView..." -ForegroundColor Gray
    $results | Out-GridView -Title "Network Share Permissions Audit v$ScriptVersion - $($results.Count) entries"
}

# Display in console if requested
if ($ShowConsole) {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Console Output (First 50 entries)" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
    
    $results | Select-Object -First 50 | Format-Table -Property SharePath, RelativePath, Account, Rights, AccessType, PermissionType, IsUnusual -AutoSize
    
    if ($results.Count -gt 50) {
        Write-Host "`n... (Showing first 50 of $($results.Count) total entries. See CSV or GridView for complete results)" -ForegroundColor Yellow
    }
}

# Highlight unusual permissions if any found
$unusualPerms = $results | Where-Object { $_.IsUnusual }
if ($unusualPerms.Count -gt 0) {
    Write-Host "`n========================================" -ForegroundColor Red
    Write-Host "UNUSUAL PERMISSIONS DETECTED" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "Found $($unusualPerms.Count) unusual permission entries" -ForegroundColor Yellow
    Write-Host "Review the following folders carefully:`n" -ForegroundColor Yellow
    
    $unusualPerms | Select-Object -First 20 | Format-Table -Property FolderPath, Account, Rights, UnusualReason -AutoSize
    
    if ($unusualPerms.Count -gt 20) {
        Write-Host "`n... (Showing first 20 unusual permissions. Filter CSV by 'IsUnusual' column for complete list)" -ForegroundColor Yellow
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Audit Complete!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Cyan
