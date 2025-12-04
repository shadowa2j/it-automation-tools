<#
.SYNOPSIS
    Compares two monthly billing report CSVs and generates an HTML report highlighting changes.

.DESCRIPTION
    Automatically detects the two most recent billing CSVs in a folder (based on YYYY-MM filename pattern),
    compares license counts, and generates an HTML report showing all licenses with changes highlighted.

.PARAMETER FolderPath
    Path to the folder containing billing report CSVs named as Billing_Report_YYYY-MM.csv

.PARAMETER OutputPath
    Path for the output HTML comparison report.

.PARAMETER OlderFile
    (Optional) Manually specify the older CSV file instead of auto-detecting.

.PARAMETER NewerFile
    (Optional) Manually specify the newer CSV file instead of auto-detecting.

.EXAMPLE
    .\Compare-BillingReports.ps1 -FolderPath "C:\Reports\Billing" -OutputPath "C:\Reports\Comparison.html"

.EXAMPLE
    .\Compare-BillingReports.ps1 -OlderFile "C:\Reports\Billing_Report_2025-11.csv" -NewerFile "C:\Reports\Billing_Report_2025-12.csv" -OutputPath "C:\Reports\Comparison.html"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$FolderPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [string]$OlderFile,

    [Parameter(Mandatory = $false)]
    [string]$NewerFile
)

#region License Category Definitions
$LicenseCategories = @{
    SentinelOne = @(
        'Actual Sentinelone'
        'Actual Sentinelonesku'
    )
    NinjaRMM = @(
        'Actual Ninja Rmm Workstation Count'
        'Actual Ninja Rmm Server Count'
        'Actual Ninja Rmm Network Device Count'
    )
    ThirdParty = @(
        'PAX8_Foxit - PDF Editor+'
        'PAX8_Foxit - PDF Editor'
        'PAX8_Rewst Essentials Plan'
        'PAX8_ConnectSecure Security Assessment & Vulnerability Management (Formerly CyberCNS)'
        'PAX8_Clerk Chat Ultimate'
    )
}

$NonMicrosoftColumns = $LicenseCategories.SentinelOne + $LicenseCategories.NinjaRMM + $LicenseCategories.ThirdParty
#endregion

#region File Detection
function Get-TwoMostRecentFiles {
    param([string]$Folder)
    
    $pattern = 'Billing_Report_(\d{4}-\d{2})\.csv$'
    $files = Get-ChildItem -Path $Folder -Filter "Billing_Report_*.csv" | Where-Object {
        $_.Name -match $pattern
    } | ForEach-Object {
        [PSCustomObject]@{
            File = $_
            Date = $_.Name -replace 'Billing_Report_(\d{4}-\d{2})\.csv', '$1'
        }
    } | Sort-Object Date -Descending
    
    if ($files.Count -lt 2) {
        throw "Need at least 2 billing reports in folder. Found: $($files.Count)"
    }
    
    return @{
        Newer = $files[0].File.FullName
        Older = $files[1].File.FullName
        NewerDate = $files[0].Date
        OlderDate = $files[1].Date
    }
}

function Get-DateFromFilename {
    param([string]$FilePath)
    
    $filename = Split-Path -Leaf $FilePath
    if ($filename -match 'Billing_Report_(\d{4}-\d{2})\.csv$') {
        return $matches[1]
    }
    return $filename -replace '\.csv$', ''
}
#endregion

#region Data Processing
function Get-CategoryForColumn {
    param([string]$ColumnName)
    
    if ($ColumnName -in $LicenseCategories.SentinelOne) { return 'SentinelOne' }
    if ($ColumnName -in $LicenseCategories.NinjaRMM) { return 'NinjaRMM' }
    if ($ColumnName -in $LicenseCategories.ThirdParty) { return 'ThirdParty' }
    if ($ColumnName -like 'PAX8_*') { return 'Microsoft' }
    return $null
}

function Import-BillingData {
    param([string]$CsvPath)
    
    $data = @{}
    $csv = Import-Csv -Path $CsvPath
    
    foreach ($row in $csv) {
        $company = $row.Company
        if ([string]::IsNullOrWhiteSpace($company)) { continue }
        
        $data[$company] = @{}
        
        foreach ($prop in $row.PSObject.Properties) {
            if ($prop.Name -eq 'Company') { continue }
            
            $category = Get-CategoryForColumn -ColumnName $prop.Name
            if ($null -eq $category) { continue }
            
            $value = $prop.Value
            if ([string]::IsNullOrWhiteSpace($value)) { continue }
            
            $numValue = 0
            if ([int]::TryParse($value, [ref]$numValue)) {
                $data[$company][$prop.Name] = $numValue
            } else {
                # Non-numeric like SKU
                $data[$company][$prop.Name] = $value
            }
        }
    }
    
    return $data
}

function Compare-BillingData {
    param($OlderData, $NewerData)
    
    $allCompanies = @($OlderData.Keys) + @($NewerData.Keys) | Select-Object -Unique | Sort-Object
    $allLicenses = @()
    
    foreach ($company in $OlderData.Values + $NewerData.Values) {
        $allLicenses += $company.Keys
    }
    $allLicenses = $allLicenses | Select-Object -Unique | Sort-Object
    
    $comparison = @{}
    
    foreach ($company in $allCompanies) {
        $comparison[$company] = @{
            Licenses = @{}
            HasChanges = $false
            TotalOlder = 0
            TotalNewer = 0
            TotalDelta = 0
        }
        
        foreach ($license in $allLicenses) {
            $olderVal = if ($OlderData.ContainsKey($company) -and $OlderData[$company].ContainsKey($license)) { 
                $OlderData[$company][$license] 
            } else { 0 }
            
            $newerVal = if ($NewerData.ContainsKey($company) -and $NewerData[$company].ContainsKey($license)) { 
                $NewerData[$company][$license] 
            } else { 0 }
            
            # Skip if both are 0 or empty
            if (($olderVal -eq 0 -or $olderVal -eq '') -and ($newerVal -eq 0 -or $newerVal -eq '')) { continue }
            
            $isNumericOlder = $olderVal -is [int]
            $isNumericNewer = $newerVal -is [int]
            
            $delta = 0
            $changed = $false
            
            if ($isNumericOlder -and $isNumericNewer) {
                $delta = $newerVal - $olderVal
                $changed = $delta -ne 0
                $comparison[$company].TotalOlder += $olderVal
                $comparison[$company].TotalNewer += $newerVal
                $comparison[$company].TotalDelta += $delta
            } else {
                $changed = $olderVal -ne $newerVal
            }
            
            if ($changed) { $comparison[$company].HasChanges = $true }
            
            $comparison[$company].Licenses[$license] = @{
                Older = $olderVal
                Newer = $newerVal
                Delta = $delta
                Changed = $changed
                Category = Get-CategoryForColumn -ColumnName $license
            }
        }
    }
    
    return $comparison
}
#endregion

#region HTML Generation
function Get-ComparisonHtmlHeader {
    param([string]$OlderDate, [string]$NewerDate)
    
    @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Billing Comparison - $OlderDate vs $NewerDate</title>
    <style>
        * { box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            max-width: 1400px;
            margin: 0 auto;
            padding: 20px;
            background: #f5f5f5;
            color: #333;
        }
        h1 {
            color: #2c3e50;
            border-bottom: 3px solid #9b59b6;
            padding-bottom: 10px;
        }
        .summary {
            background: #fff;
            padding: 20px;
            border-radius: 8px;
            margin-bottom: 20px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .summary h2 { margin-top: 0; color: #2c3e50; }
        .summary-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
            gap: 15px;
        }
        .summary-item {
            background: #ecf0f1;
            padding: 15px;
            border-radius: 6px;
            text-align: center;
        }
        .summary-item .number {
            font-size: 1.8em;
            font-weight: bold;
            color: #3498db;
        }
        .summary-item .label { color: #7f8c8d; font-size: 0.9em; }
        .summary-item.increase .number { color: #27ae60; }
        .summary-item.decrease .number { color: #e74c3c; }
        .customer {
            background: #fff;
            margin-bottom: 10px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        .customer-header {
            background: #9b59b6;
            color: #fff;
            padding: 15px 20px;
            cursor: pointer;
            display: flex;
            justify-content: space-between;
            align-items: center;
            user-select: none;
        }
        .customer-header:hover { background: #8e44ad; }
        .customer-header.has-changes { background: #e67e22; }
        .customer-header.has-changes:hover { background: #d35400; }
        .customer-header h3 { margin: 0; }
        .customer-header .badge {
            background: rgba(255,255,255,0.2);
            padding: 4px 10px;
            border-radius: 12px;
            font-size: 0.85em;
        }
        .customer-header .toggle {
            font-size: 1.2em;
            transition: transform 0.3s;
        }
        .customer-header.active .toggle { transform: rotate(180deg); }
        .customer-content {
            display: none;
            padding: 20px;
        }
        .customer-content.show { display: block; }
        .category { margin-bottom: 20px; }
        .category:last-child { margin-bottom: 0; }
        .category h4 {
            color: #2c3e50;
            border-bottom: 2px solid #ecf0f1;
            padding-bottom: 8px;
            margin-bottom: 10px;
        }
        .license-table {
            width: 100%;
            border-collapse: collapse;
        }
        .license-table th, .license-table td {
            padding: 10px 12px;
            text-align: left;
            border-bottom: 1px solid #ecf0f1;
        }
        .license-table th {
            background: #f8f9fa;
            font-weight: 600;
            color: #2c3e50;
        }
        .license-table td:nth-child(2),
        .license-table td:nth-child(3),
        .license-table td:nth-child(4) {
            text-align: right;
            width: 100px;
        }
        .license-table th:nth-child(2),
        .license-table th:nth-child(3),
        .license-table th:nth-child(4) {
            text-align: right;
            width: 100px;
        }
        .license-table tr:hover { background: #f8f9fa; }
        .change-positive {
            color: #27ae60;
            font-weight: 600;
        }
        .change-negative {
            color: #e74c3c;
            font-weight: 600;
        }
        .change-none {
            color: #bdc3c7;
        }
        .customer-total {
            text-align: right;
            font-weight: bold;
            padding-top: 10px;
            color: #2c3e50;
            border-top: 2px solid #9b59b6;
            margin-top: 15px;
        }
        .filter-buttons {
            margin: 15px 0;
        }
        .filter-buttons button {
            padding: 8px 16px;
            cursor: pointer;
            margin-right: 10px;
            border: 1px solid #ddd;
            background: #fff;
            border-radius: 4px;
        }
        .filter-buttons button:hover { background: #ecf0f1; }
        .filter-buttons button.active { background: #9b59b6; color: #fff; border-color: #9b59b6; }
        .hidden { display: none !important; }
    </style>
</head>
<body>
    <h1>📊 Billing Comparison Report</h1>
    <p>Comparing <strong>$OlderDate</strong> → <strong>$NewerDate</strong> | Generated: $(Get-Date -Format 'MMMM dd, yyyy h:mm tt')</p>
"@
}

function Get-ComparisonSummaryHtml {
    param($Comparison, $OlderDate, $NewerDate)
    
    $totalCustomers = $Comparison.Count
    $customersWithChanges = ($Comparison.Values | Where-Object { $_.HasChanges }).Count
    $totalOlder = ($Comparison.Values | Measure-Object -Property TotalOlder -Sum).Sum
    $totalNewer = ($Comparison.Values | Measure-Object -Property TotalNewer -Sum).Sum
    $totalDelta = $totalNewer - $totalOlder
    
    $deltaClass = if ($totalDelta -gt 0) { 'increase' } elseif ($totalDelta -lt 0) { 'decrease' } else { '' }
    $deltaDisplay = if ($totalDelta -gt 0) { "+$totalDelta" } else { "$totalDelta" }
    
    @"
    <div class="summary">
        <h2>Summary</h2>
        <div class="summary-grid">
            <div class="summary-item">
                <div class="number">$totalCustomers</div>
                <div class="label">Total Customers</div>
            </div>
            <div class="summary-item has-changes">
                <div class="number">$customersWithChanges</div>
                <div class="label">With Changes</div>
            </div>
            <div class="summary-item">
                <div class="number">$totalOlder</div>
                <div class="label">$OlderDate Total</div>
            </div>
            <div class="summary-item">
                <div class="number">$totalNewer</div>
                <div class="label">$NewerDate Total</div>
            </div>
            <div class="summary-item $deltaClass">
                <div class="number">$deltaDisplay</div>
                <div class="label">Net Change</div>
            </div>
        </div>
        <div class="filter-buttons">
            <button id="showAll" class="active">Show All</button>
            <button id="showChanges">Show Only Changes</button>
            <button id="expandAll">Expand All</button>
            <button id="collapseAll">Collapse All</button>
        </div>
    </div>
"@
}

function Get-CustomerComparisonHtml {
    param($CustomerName, $CustomerData, $OlderDate, $NewerDate)
    
    $categoryOrder = @('SentinelOne', 'NinjaRMM', 'Microsoft', 'ThirdParty')
    $categoryIcons = @{
        SentinelOne = '🛡️ SentinelOne'
        NinjaRMM = '🖥️ NinjaRMM'
        Microsoft = '☁️ Microsoft'
        ThirdParty = '🔧 Third Party'
    }
    
    $categoryHtml = @()
    
    foreach ($category in $categoryOrder) {
        $licenses = $CustomerData.Licenses.GetEnumerator() | Where-Object { $_.Value.Category -eq $category } | Sort-Object Name
        
        if (-not $licenses) { continue }
        
        $rows = foreach ($lic in $licenses) {
            $older = if ($lic.Value.Older -eq 0) { '-' } else { $lic.Value.Older }
            $newer = if ($lic.Value.Newer -eq 0) { '-' } else { $lic.Value.Newer }
            
            $changeClass = 'change-none'
            $changeText = '-'
            
            if ($lic.Value.Changed) {
                if ($lic.Value.Delta -gt 0) {
                    $changeClass = 'change-positive'
                    $changeText = "+$($lic.Value.Delta)"
                } elseif ($lic.Value.Delta -lt 0) {
                    $changeClass = 'change-negative'
                    $changeText = "$($lic.Value.Delta)"
                } else {
                    # Non-numeric change
                    $changeClass = 'change-positive'
                    $changeText = '~'
                }
            }
            
            "<tr><td>$($lic.Name)</td><td>$older</td><td>$newer</td><td class='$changeClass'>$changeText</td></tr>"
        }
        
        $categoryHtml += @"
            <div class="category">
                <h4>$($categoryIcons[$category])</h4>
                <table class="license-table">
                    <thead><tr><th>License</th><th>$OlderDate</th><th>$NewerDate</th><th>Change</th></tr></thead>
                    <tbody>
                        $($rows -join "`n                        ")
                    </tbody>
                </table>
            </div>
"@
    }
    
    if ($categoryHtml.Count -eq 0) { return $null }
    
    $hasChangesClass = if ($CustomerData.HasChanges) { 'has-changes' } else { '' }
    $badge = if ($CustomerData.HasChanges) { '<span class="badge">CHANGED</span>' } else { '' }
    
    $deltaClass = 'change-none'
    $deltaText = '-'
    if ($CustomerData.TotalDelta -ne 0) {
        if ($CustomerData.TotalDelta -gt 0) {
            $deltaClass = 'change-positive'
            $deltaText = "+$($CustomerData.TotalDelta)"
        } else {
            $deltaClass = 'change-negative'
            $deltaText = "$($CustomerData.TotalDelta)"
        }
    }
    
    $dataChanged = if ($CustomerData.HasChanges) { 'true' } else { 'false' }
    
    @"
    <div class="customer" data-has-changes="$dataChanged">
        <div class="customer-header $hasChangesClass">
            <h3>$CustomerName $badge</h3>
            <span class="toggle">▼</span>
        </div>
        <div class="customer-content">
            $($categoryHtml -join "`n")
            <div class="customer-total">
                Total: $($CustomerData.TotalOlder) → $($CustomerData.TotalNewer) 
                <span class="$deltaClass">($deltaText)</span>
            </div>
        </div>
    </div>
"@
}

function Get-ComparisonHtmlFooter {
    @"
    <script>
        document.querySelectorAll('.customer-header').forEach(header => {
            header.addEventListener('click', () => {
                header.classList.toggle('active');
                header.nextElementSibling.classList.toggle('show');
            });
        });
        
        document.getElementById('expandAll').addEventListener('click', () => {
            document.querySelectorAll('.customer-header').forEach(h => h.classList.add('active'));
            document.querySelectorAll('.customer-content').forEach(c => c.classList.add('show'));
        });
        
        document.getElementById('collapseAll').addEventListener('click', () => {
            document.querySelectorAll('.customer-header').forEach(h => h.classList.remove('active'));
            document.querySelectorAll('.customer-content').forEach(c => c.classList.remove('show'));
        });
        
        document.getElementById('showAll').addEventListener('click', () => {
            document.querySelectorAll('.customer').forEach(c => c.classList.remove('hidden'));
            document.getElementById('showAll').classList.add('active');
            document.getElementById('showChanges').classList.remove('active');
        });
        
        document.getElementById('showChanges').addEventListener('click', () => {
            document.querySelectorAll('.customer').forEach(c => {
                if (c.dataset.hasChanges === 'false') {
                    c.classList.add('hidden');
                } else {
                    c.classList.remove('hidden');
                }
            });
            document.getElementById('showChanges').classList.add('active');
            document.getElementById('showAll').classList.remove('active');
        });
    </script>
</body>
</html>
"@
}
#endregion

#region Main
try {
    # Determine which files to compare
    if ($OlderFile -and $NewerFile) {
        if (-not (Test-Path $OlderFile)) { throw "Older file not found: $OlderFile" }
        if (-not (Test-Path $NewerFile)) { throw "Newer file not found: $NewerFile" }
        
        $olderPath = $OlderFile
        $newerPath = $NewerFile
        $olderDate = Get-DateFromFilename -FilePath $OlderFile
        $newerDate = Get-DateFromFilename -FilePath $NewerFile
    }
    elseif ($FolderPath) {
        if (-not (Test-Path $FolderPath)) { throw "Folder not found: $FolderPath" }
        
        Write-Host "Scanning folder: $FolderPath" -ForegroundColor Cyan
        $files = Get-TwoMostRecentFiles -Folder $FolderPath
        
        $olderPath = $files.Older
        $newerPath = $files.Newer
        $olderDate = $files.OlderDate
        $newerDate = $files.NewerDate
    }
    else {
        throw "Must specify either -FolderPath or both -OlderFile and -NewerFile"
    }
    
    Write-Host "Comparing:" -ForegroundColor Cyan
    Write-Host "  Older: $olderPath ($olderDate)" -ForegroundColor White
    Write-Host "  Newer: $newerPath ($newerDate)" -ForegroundColor White
    
    # Import and compare data
    Write-Host "Loading data..." -ForegroundColor Cyan
    $olderData = Import-BillingData -CsvPath $olderPath
    $newerData = Import-BillingData -CsvPath $newerPath
    
    Write-Host "Comparing..." -ForegroundColor Cyan
    $comparison = Compare-BillingData -OlderData $olderData -NewerData $newerData
    
    # Generate HTML
    Write-Host "Generating report..." -ForegroundColor Cyan
    $html = @()
    $html += Get-ComparisonHtmlHeader -OlderDate $olderDate -NewerDate $newerDate
    $html += Get-ComparisonSummaryHtml -Comparison $comparison -OlderDate $olderDate -NewerDate $newerDate
    
    foreach ($company in $comparison.Keys | Sort-Object) {
        $customerHtml = Get-CustomerComparisonHtml -CustomerName $company -CustomerData $comparison[$company] -OlderDate $olderDate -NewerDate $newerDate
        if ($customerHtml) {
            $html += $customerHtml
        }
    }
    
    $html += Get-ComparisonHtmlFooter
    
    # Ensure output directory exists
    $outputDir = Split-Path -Path $OutputPath -Parent
    if ($outputDir -and -not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }
    
    # Write HTML
    $html -join "`n" | Out-File -FilePath $OutputPath -Encoding UTF8
    
    $changedCount = ($comparison.Values | Where-Object { $_.HasChanges }).Count
    
    Write-Host "`n✅ Comparison report generated!" -ForegroundColor Green
    Write-Host "   Output: $OutputPath" -ForegroundColor White
    Write-Host "   Customers: $($comparison.Count)" -ForegroundColor White
    Write-Host "   With Changes: $changedCount" -ForegroundColor White
}
catch {
    Write-Error "Failed to generate comparison: $_"
    exit 1
}
#endregion
