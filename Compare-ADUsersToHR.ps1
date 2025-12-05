<#
.SYNOPSIS
    Compares Active Directory enabled users export against HR roster to identify discrepancies.

.DESCRIPTION
    This script compares two user lists (AD export and HR roster) and generates a detailed report
    showing which users exist in one system but not the other. Only includes enabled AD users.
    Outputs results in both CSV and HTML formats with edge case reporting.

.PARAMETER ADExportPath
    Path to the CSV file exported from the Export-ADUsersFromOUs.ps1 script.

.PARAMETER HRRosterPath
    Path to the Excel file from HR containing employee roster.

.PARAMETER OutputDirectory
    Directory where report files will be saved. Defaults to current directory.

.EXAMPLE
    .\Compare-ADUsersToHR.ps1 -ADExportPath ".\ADUsers_Export.csv" -HRRosterPath ".\HR_Roster.xlsx"

.EXAMPLE
    .\Compare-ADUsersToHR.ps1 -ADExportPath "C:\Exports\ADUsers.csv" -HRRosterPath "C:\HR\Roster.xlsx" -OutputDirectory "C:\Reports"

.NOTES
    Author: Bryan
    Requires: ImportExcel PowerShell Module (Install-Module ImportExcel)
    Version: 1.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({Test-Path $_ -PathType Leaf})]
    [string]$ADExportPath,
    
    [Parameter(Mandatory = $true)]
    [ValidateScript({Test-Path $_ -PathType Leaf})]
    [string]$HRRosterPath,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputDirectory = "."
)

#region Module Check and Import
Write-Host "Checking required modules..." -ForegroundColor Cyan

# Check for ImportExcel module
if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
    Write-Host "ImportExcel module not found. Installing..." -ForegroundColor Yellow
    try {
        Install-Module -Name ImportExcel -Scope CurrentUser -Force -AllowClobber
        Write-Host "ImportExcel module installed successfully." -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to install ImportExcel module: $($_.Exception.Message)"
        Write-Host "Please install manually with: Install-Module ImportExcel" -ForegroundColor Red
        exit 1
    }
}

Import-Module ImportExcel
#endregion

#region Data Import
Write-Host "`nImporting data files..." -ForegroundColor Cyan

# Import AD Export
try {
    $adUsers = Import-Csv -Path $ADExportPath
    Write-Host "Loaded $($adUsers.Count) users from AD export" -ForegroundColor Green
}
catch {
    Write-Error "Failed to import AD export: $($_.Exception.Message)"
    exit 1
}

# Import HR Roster
try {
    $hrUsers = Import-Excel -Path $HRRosterPath
    Write-Host "Loaded $($hrUsers.Count) users from HR roster" -ForegroundColor Green
}
catch {
    Write-Error "Failed to import HR roster: $($_.Exception.Message)"
    exit 1
}
#endregion

#region Data Processing
Write-Host "`nProcessing and normalizing data..." -ForegroundColor Cyan

# Filter to only enabled AD users
$adUsersEnabled = $adUsers | Where-Object { $_.Status -eq "Enabled" }
Write-Host "Filtered to $($adUsersEnabled.Count) enabled AD users" -ForegroundColor Yellow

# Process AD users - normalize names and track edge cases
$adProcessed = @()
$adEdgeCases = @()

foreach ($user in $adUsersEnabled) {
    # Check for missing data
    if ([string]::IsNullOrWhiteSpace($user.FirstName) -or [string]::IsNullOrWhiteSpace($user.LastName)) {
        $adEdgeCases += [PSCustomObject]@{
            Source = "Active Directory"
            Issue = "Missing Name Data"
            Username = $user.Username
            FirstName = $user.FirstName
            LastName = $user.LastName
            FullName = "$($user.FirstName) $($user.LastName)".Trim()
        }
        continue
    }
    
    $normalizedFirst = $user.FirstName.Trim().ToLower()
    $normalizedLast = $user.LastName.Trim().ToLower()
    $fullName = "$normalizedFirst $normalizedLast"
    
    $adProcessed += [PSCustomObject]@{
        Username = $user.Username
        FirstName = $user.FirstName
        LastName = $user.LastName
        NormalizedFirst = $normalizedFirst
        NormalizedLast = $normalizedLast
        FullName = $fullName
    }
}

# Process HR users - extract last name and normalize
$hrProcessed = @()
$hrEdgeCases = @()

foreach ($user in $hrUsers) {
    $legalName = $user.'Legal Name'
    $firstName = $user.'Legal Name - First Name'
    
    # Check for missing data
    if ([string]::IsNullOrWhiteSpace($legalName) -or [string]::IsNullOrWhiteSpace($firstName)) {
        $hrEdgeCases += [PSCustomObject]@{
            Source = "HR Roster"
            Issue = "Missing Name Data"
            Username = $user.'Email - Primary Work'
            FirstName = $firstName
            LastName = ""
            FullName = $legalName
        }
        continue
    }
    
    # Extract last name (everything after first name in Legal Name)
    $lastName = $legalName.Replace($firstName, "").Trim()
    
    if ([string]::IsNullOrWhiteSpace($lastName)) {
        $hrEdgeCases += [PSCustomObject]@{
            Source = "HR Roster"
            Issue = "Cannot Extract Last Name"
            Username = $user.'Email - Primary Work'
            FirstName = $firstName
            LastName = ""
            FullName = $legalName
        }
        continue
    }
    
    $normalizedFirst = $firstName.Trim().ToLower()
    $normalizedLast = $lastName.Trim().ToLower()
    $fullName = "$normalizedFirst $normalizedLast"
    
    $hrProcessed += [PSCustomObject]@{
        Email = $user.'Email - Primary Work'
        FirstName = $firstName
        LastName = $lastName
        NormalizedFirst = $normalizedFirst
        NormalizedLast = $normalizedLast
        FullName = $fullName
        Manager = $user.Manager
        BusinessTitle = $user.'Business Title'
        Location = "$($user.'Location Address - City'), $($user.'Location Address - State (United States)')"
    }
}

Write-Host "Processed $($adProcessed.Count) valid AD users" -ForegroundColor Yellow
Write-Host "Processed $($hrProcessed.Count) valid HR users" -ForegroundColor Yellow
Write-Host "Found $($adEdgeCases.Count) AD edge cases" -ForegroundColor Yellow
Write-Host "Found $($hrEdgeCases.Count) HR edge cases" -ForegroundColor Yellow
#endregion

#region Comparison Logic
Write-Host "`nPerforming comparison..." -ForegroundColor Cyan

# Create hash tables for quick lookup
$adHash = @{}
$hrHash = @{}

# Track duplicates
$adDuplicates = @()
$hrDuplicates = @()

foreach ($user in $adProcessed) {
    if ($adHash.ContainsKey($user.FullName)) {
        $adDuplicates += [PSCustomObject]@{
            Source = "Active Directory"
            Issue = "Duplicate Name"
            FirstName = $user.FirstName
            LastName = $user.LastName
            FullName = "$($user.FirstName) $($user.LastName)"
            Username1 = $adHash[$user.FullName].Username
            Username2 = $user.Username
        }
    }
    else {
        $adHash[$user.FullName] = $user
    }
}

foreach ($user in $hrProcessed) {
    if ($hrHash.ContainsKey($user.FullName)) {
        $hrDuplicates += [PSCustomObject]@{
            Source = "HR Roster"
            Issue = "Duplicate Name"
            FirstName = $user.FirstName
            LastName = $user.LastName
            FullName = "$($user.FirstName) $($user.LastName)"
            Email1 = $hrHash[$user.FullName].Email
            Email2 = $user.Email
        }
    }
    else {
        $hrHash[$user.FullName] = $user
    }
}

# Find users in AD but not in HR
$inADNotHR = @()
foreach ($adUser in $adProcessed) {
    if (-not $hrHash.ContainsKey($adUser.FullName)) {
        $inADNotHR += [PSCustomObject]@{
            FirstName = $adUser.FirstName
            LastName = $adUser.LastName
            Username = $adUser.Username
            MissingFrom = "HR Roster"
        }
    }
}

# Find users in HR but not in AD
$inHRNotAD = @()
foreach ($hrUser in $hrProcessed) {
    if (-not $adHash.ContainsKey($hrUser.FullName)) {
        $inHRNotAD += [PSCustomObject]@{
            FirstName = $hrUser.FirstName
            LastName = $hrUser.LastName
            Email = $hrUser.Email
            BusinessTitle = $hrUser.BusinessTitle
            Manager = $hrUser.Manager
            Location = $hrUser.Location
            MissingFrom = "Active Directory"
        }
    }
}

Write-Host "Found $($inADNotHR.Count) users in AD but not in HR" -ForegroundColor Yellow
Write-Host "Found $($inHRNotAD.Count) users in HR but not in AD" -ForegroundColor Yellow
Write-Host "Found $($adDuplicates.Count) duplicate names in AD" -ForegroundColor Yellow
Write-Host "Found $($hrDuplicates.Count) duplicate names in HR" -ForegroundColor Yellow
#endregion

#region Report Generation
Write-Host "`nGenerating reports..." -ForegroundColor Cyan

$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$csvPath = Join-Path $OutputDirectory "UserComparison_Report_$timestamp.csv"
$htmlPath = Join-Path $OutputDirectory "UserComparison_Report_$timestamp.html"

# Prepare combined report data
$reportData = @()

# Add users in AD but not HR
foreach ($user in $inADNotHR) {
    $reportData += [PSCustomObject]@{
        Category = "In AD, Not in HR"
        FirstName = $user.FirstName
        LastName = $user.LastName
        Username = $user.Username
        Email = ""
        BusinessTitle = ""
        Manager = ""
        Location = ""
        Notes = ""
    }
}

# Add users in HR but not AD
foreach ($user in $inHRNotAD) {
    $reportData += [PSCustomObject]@{
        Category = "In HR, Not in AD"
        FirstName = $user.FirstName
        LastName = $user.LastName
        Username = ""
        Email = $user.Email
        BusinessTitle = $user.BusinessTitle
        Manager = $user.Manager
        Location = $user.Location
        Notes = ""
    }
}

# Add edge cases
foreach ($edge in ($adEdgeCases + $hrEdgeCases)) {
    $reportData += [PSCustomObject]@{
        Category = "Edge Case"
        FirstName = $edge.FirstName
        LastName = $edge.LastName
        Username = $edge.Username
        Email = ""
        BusinessTitle = ""
        Manager = ""
        Location = ""
        Notes = "$($edge.Source): $($edge.Issue)"
    }
}

# Add duplicates
foreach ($dup in $adDuplicates) {
    $reportData += [PSCustomObject]@{
        Category = "Duplicate Name"
        FirstName = $dup.FirstName
        LastName = $dup.LastName
        Username = "$($dup.Username1), $($dup.Username2)"
        Email = ""
        BusinessTitle = ""
        Manager = ""
        Location = ""
        Notes = "AD: Multiple users with same name"
    }
}

foreach ($dup in $hrDuplicates) {
    $reportData += [PSCustomObject]@{
        Category = "Duplicate Name"
        FirstName = $dup.FirstName
        LastName = $dup.LastName
        Username = ""
        Email = "$($dup.Email1), $($dup.Email2)"
        BusinessTitle = ""
        Manager = ""
        Location = ""
        Notes = "HR: Multiple users with same name"
    }
}

# Export CSV
$reportData | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
Write-Host "CSV report saved to: $csvPath" -ForegroundColor Green

# Generate HTML Report
$htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>AD vs HR User Comparison Report</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 20px;
            background-color: #f5f5f5;
        }
        .header {
            background-color: #2c3e50;
            color: white;
            padding: 20px;
            border-radius: 5px;
            margin-bottom: 20px;
        }
        .summary {
            background-color: white;
            padding: 15px;
            border-radius: 5px;
            margin-bottom: 20px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .summary-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin-top: 15px;
        }
        .summary-box {
            background-color: #ecf0f1;
            padding: 15px;
            border-radius: 5px;
            text-align: center;
        }
        .summary-box h3 {
            margin: 0 0 10px 0;
            color: #2c3e50;
        }
        .summary-box .number {
            font-size: 32px;
            font-weight: bold;
            color: #e74c3c;
        }
        .summary-box.match .number {
            color: #27ae60;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            background-color: white;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            margin-bottom: 20px;
        }
        th {
            background-color: #34495e;
            color: white;
            padding: 12px;
            text-align: left;
            font-weight: 600;
        }
        td {
            padding: 10px;
            border-bottom: 1px solid #ddd;
        }
        tr:hover {
            background-color: #f5f5f5;
        }
        .category-ad-not-hr {
            background-color: #ffe6e6;
        }
        .category-hr-not-ad {
            background-color: #e6f3ff;
        }
        .category-edge {
            background-color: #fff3cd;
        }
        .category-duplicate {
            background-color: #f8d7da;
        }
        .section-title {
            background-color: #34495e;
            color: white;
            padding: 10px;
            border-radius: 5px;
            margin-top: 20px;
            margin-bottom: 10px;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>AD vs HR User Comparison Report</h1>
        <p>Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
        <p>AD Export: $ADExportPath</p>
        <p>HR Roster: $HRRosterPath</p>
    </div>
    
    <div class="summary">
        <h2>Executive Summary</h2>
        <div class="summary-grid">
            <div class="summary-box">
                <h3>Total AD Users (Enabled)</h3>
                <div class="number">$($adProcessed.Count)</div>
            </div>
            <div class="summary-box">
                <h3>Total HR Users</h3>
                <div class="number">$($hrProcessed.Count)</div>
            </div>
            <div class="summary-box match">
                <h3>Matched Users</h3>
                <div class="number">$($adProcessed.Count - $inADNotHR.Count)</div>
            </div>
            <div class="summary-box">
                <h3>In AD, Not in HR</h3>
                <div class="number">$($inADNotHR.Count)</div>
            </div>
            <div class="summary-box">
                <h3>In HR, Not in AD</h3>
                <div class="number">$($inHRNotAD.Count)</div>
            </div>
            <div class="summary-box">
                <h3>Edge Cases</h3>
                <div class="number">$($adEdgeCases.Count + $hrEdgeCases.Count)</div>
            </div>
            <div class="summary-box">
                <h3>Duplicates</h3>
                <div class="number">$($adDuplicates.Count + $hrDuplicates.Count)</div>
            </div>
        </div>
    </div>
"@

# Add section for users in AD but not HR
if ($inADNotHR.Count -gt 0) {
    $htmlContent += @"
    <div class="section-title">
        <h2>Users in Active Directory but NOT in HR Roster ($($inADNotHR.Count))</h2>
    </div>
    <table>
        <thead>
            <tr>
                <th>First Name</th>
                <th>Last Name</th>
                <th>Username</th>
            </tr>
        </thead>
        <tbody>
"@
    foreach ($user in ($inADNotHR | Sort-Object LastName, FirstName)) {
        $htmlContent += @"
            <tr class="category-ad-not-hr">
                <td>$($user.FirstName)</td>
                <td>$($user.LastName)</td>
                <td>$($user.Username)</td>
            </tr>
"@
    }
    $htmlContent += @"
        </tbody>
    </table>
"@
}

# Add section for users in HR but not AD
if ($inHRNotAD.Count -gt 0) {
    $htmlContent += @"
    <div class="section-title">
        <h2>Users in HR Roster but NOT in Active Directory ($($inHRNotAD.Count))</h2>
    </div>
    <table>
        <thead>
            <tr>
                <th>First Name</th>
                <th>Last Name</th>
                <th>Email</th>
                <th>Business Title</th>
                <th>Manager</th>
                <th>Location</th>
            </tr>
        </thead>
        <tbody>
"@
    foreach ($user in ($inHRNotAD | Sort-Object LastName, FirstName)) {
        $htmlContent += @"
            <tr class="category-hr-not-ad">
                <td>$($user.FirstName)</td>
                <td>$($user.LastName)</td>
                <td>$($user.Email)</td>
                <td>$($user.BusinessTitle)</td>
                <td>$($user.Manager)</td>
                <td>$($user.Location)</td>
            </tr>
"@
    }
    $htmlContent += @"
        </tbody>
    </table>
"@
}

# Add edge cases section
if (($adEdgeCases.Count + $hrEdgeCases.Count) -gt 0) {
    $htmlContent += @"
    <div class="section-title">
        <h2>Edge Cases - Data Quality Issues ($($adEdgeCases.Count + $hrEdgeCases.Count))</h2>
    </div>
    <table>
        <thead>
            <tr>
                <th>Source</th>
                <th>Issue</th>
                <th>First Name</th>
                <th>Last Name</th>
                <th>Username/Email</th>
                <th>Full Name</th>
            </tr>
        </thead>
        <tbody>
"@
    foreach ($edge in ($adEdgeCases + $hrEdgeCases)) {
        $htmlContent += @"
            <tr class="category-edge">
                <td>$($edge.Source)</td>
                <td>$($edge.Issue)</td>
                <td>$($edge.FirstName)</td>
                <td>$($edge.LastName)</td>
                <td>$($edge.Username)</td>
                <td>$($edge.FullName)</td>
            </tr>
"@
    }
    $htmlContent += @"
        </tbody>
    </table>
"@
}

# Add duplicates section
if (($adDuplicates.Count + $hrDuplicates.Count) -gt 0) {
    $htmlContent += @"
    <div class="section-title">
        <h2>Duplicate Names ($($adDuplicates.Count + $hrDuplicates.Count))</h2>
    </div>
    <table>
        <thead>
            <tr>
                <th>Source</th>
                <th>First Name</th>
                <th>Last Name</th>
                <th>Details</th>
            </tr>
        </thead>
        <tbody>
"@
    foreach ($dup in $adDuplicates) {
        $htmlContent += @"
            <tr class="category-duplicate">
                <td>$($dup.Source)</td>
                <td>$($dup.FirstName)</td>
                <td>$($dup.LastName)</td>
                <td>Usernames: $($dup.Username1), $($dup.Username2)</td>
            </tr>
"@
    }
    foreach ($dup in $hrDuplicates) {
        $htmlContent += @"
            <tr class="category-duplicate">
                <td>$($dup.Source)</td>
                <td>$($dup.FirstName)</td>
                <td>$($dup.LastName)</td>
                <td>Emails: $($dup.Email1), $($dup.Email2)</td>
            </tr>
"@
    }
    $htmlContent += @"
        </tbody>
    </table>
"@
}

$htmlContent += @"
</body>
</html>
"@

# Save HTML report
$htmlContent | Out-File -FilePath $htmlPath -Encoding UTF8
Write-Host "HTML report saved to: $htmlPath" -ForegroundColor Green
#endregion

#region Summary Output
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "           COMPARISON COMPLETE          " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "`nSummary Statistics:" -ForegroundColor White
Write-Host "  Total AD Users (Enabled): $($adProcessed.Count)" -ForegroundColor Yellow
Write-Host "  Total HR Users: $($hrProcessed.Count)" -ForegroundColor Yellow
Write-Host "  Matched Users: $($adProcessed.Count - $inADNotHR.Count)" -ForegroundColor Green
Write-Host "  In AD but NOT in HR: $($inADNotHR.Count)" -ForegroundColor Red
Write-Host "  In HR but NOT in AD: $($inHRNotAD.Count)" -ForegroundColor Red
Write-Host "  Edge Cases: $($adEdgeCases.Count + $hrEdgeCases.Count)" -ForegroundColor Magenta
Write-Host "  Duplicate Names: $($adDuplicates.Count + $hrDuplicates.Count)" -ForegroundColor Magenta
Write-Host "`nReports generated:" -ForegroundColor White
Write-Host "  CSV: $csvPath" -ForegroundColor Cyan
Write-Host "  HTML: $htmlPath" -ForegroundColor Cyan
Write-Host "`n========================================`n" -ForegroundColor Cyan
#endregion
