<#
.SYNOPSIS
    Converts a monthly billing report CSV to an HTML report with collapsible customer sections.

.DESCRIPTION
    Reads a billing CSV with customers as rows and license types as columns.
    Generates an HTML report showing only non-zero license counts, grouped by category:
    - SentinelOne
    - NinjaRMM
    - Microsoft (all M365, Office, Teams, etc.)
    - Third Party (Foxit, Rewst, ConnectSecure, Clerk Chat)

.PARAMETER CsvPath
    Path to the billing report CSV file.

.PARAMETER OutputPath
    Path for the output HTML file.

.EXAMPLE
    .\Convert-BillingReportToHtml.ps1 -CsvPath "C:\Reports\Billing_Report.csv" -OutputPath "C:\Reports\Output\BillingReport.html"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$CsvPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath
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
    # Microsoft = everything else (handled dynamically)
}
#endregion

#region HTML Template Functions
function Get-HtmlHeader {
    @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Billing Report - $(Get-Date -Format 'MMMM yyyy')</title>
    <style>
        * { box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
            background: #f5f5f5;
            color: #333;
        }
        h1 {
            color: #2c3e50;
            border-bottom: 3px solid #3498db;
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
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
        }
        .summary-item {
            background: #ecf0f1;
            padding: 15px;
            border-radius: 6px;
            text-align: center;
        }
        .summary-item .number {
            font-size: 2em;
            font-weight: bold;
            color: #3498db;
        }
        .summary-item .label { color: #7f8c8d; }
        .customer {
            background: #fff;
            margin-bottom: 10px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        .customer-header {
            background: #3498db;
            color: #fff;
            padding: 15px 20px;
            cursor: pointer;
            display: flex;
            justify-content: space-between;
            align-items: center;
            user-select: none;
        }
        .customer-header:hover { background: #2980b9; }
        .customer-header h3 { margin: 0; }
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
        .category {
            margin-bottom: 20px;
        }
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
        .license-table tr:hover { background: #f8f9fa; }
        .license-table td:last-child {
            text-align: right;
            font-weight: 600;
            color: #27ae60;
        }
        .category-total {
            text-align: right;
            font-weight: bold;
            padding-top: 10px;
            color: #2c3e50;
        }
        .no-licenses {
            color: #95a5a6;
            font-style: italic;
        }
        @media (max-width: 600px) {
            .customer-header { flex-direction: column; gap: 10px; }
        }
    </style>
</head>
<body>
    <h1>Monthly Billing Report</h1>
    <p>Generated: $(Get-Date -Format 'MMMM dd, yyyy h:mm tt')</p>
"@
}

function Get-HtmlFooter {
    @"
    <script>
        document.querySelectorAll('.customer-header').forEach(header => {
            header.addEventListener('click', () => {
                header.classList.toggle('active');
                const content = header.nextElementSibling;
                content.classList.toggle('show');
            });
        });
        
        // Expand all / Collapse all functionality
        document.getElementById('expandAll')?.addEventListener('click', () => {
            document.querySelectorAll('.customer-header').forEach(h => h.classList.add('active'));
            document.querySelectorAll('.customer-content').forEach(c => c.classList.add('show'));
        });
        document.getElementById('collapseAll')?.addEventListener('click', () => {
            document.querySelectorAll('.customer-header').forEach(h => h.classList.remove('active'));
            document.querySelectorAll('.customer-content').forEach(c => c.classList.remove('show'));
        });
    </script>
</body>
</html>
"@
}

function Get-SummaryHtml {
    param($CustomerCount, $TotalLicenses, $CategoryTotals)
    
    $categoryItems = $CategoryTotals.GetEnumerator() | Where-Object { $_.Value -gt 0 } | ForEach-Object {
        "<div class='summary-item'><div class='number'>$($_.Value)</div><div class='label'>$($_.Key)</div></div>"
    }
    
    @"
    <div class="summary">
        <h2>Summary</h2>
        <div class="summary-grid">
            <div class="summary-item">
                <div class="number">$CustomerCount</div>
                <div class="label">Customers</div>
            </div>
            <div class="summary-item">
                <div class="number">$TotalLicenses</div>
                <div class="label">Total Licenses</div>
            </div>
            $($categoryItems -join "`n            ")
        </div>
        <p style="margin-top:15px;">
            <button id="expandAll" style="padding:8px 16px;cursor:pointer;">Expand All</button>
            <button id="collapseAll" style="padding:8px 16px;cursor:pointer;">Collapse All</button>
        </p>
    </div>
"@
}

function Get-CustomerHtml {
    param($CustomerName, $LicensesByCategory)
    
    $categoryHtml = @()
    $customerTotal = 0
    
    foreach ($category in @('SentinelOne', 'NinjaRMM', 'Microsoft', 'ThirdParty')) {
        $licenses = $LicensesByCategory[$category]
        if ($licenses -and $licenses.Count -gt 0) {
            $categoryTotal = ($licenses.Values | Where-Object { $_ -is [int] } | Measure-Object -Sum).Sum
            $customerTotal += $categoryTotal
            
            $rows = $licenses.GetEnumerator() | Sort-Object Name | ForEach-Object {
                "<tr><td>$($_.Key)</td><td>$($_.Value)</td></tr>"
            }
            
            $displayName = switch ($category) {
                'SentinelOne' { 'SentinelOne' }
                'NinjaRMM' { 'NinjaRMM' }
                'Microsoft' { 'Microsoft' }
                'ThirdParty' { 'Third Party' }
            }
            
            $categoryHtml += @"
            <div class="category">
                <h4>$displayName</h4>
                <table class="license-table">
                    <thead><tr><th>License</th><th>Count</th></tr></thead>
                    <tbody>
                        $($rows -join "`n                        ")
                    </tbody>
                </table>
                <div class="category-total">Subtotal: $categoryTotal</div>
            </div>
"@
        }
    }
    
    if ($categoryHtml.Count -eq 0) {
        return $null  # Skip customers with no licenses
    }
    
    @"
    <div class="customer">
        <div class="customer-header">
            <h3>$CustomerName</h3>
            <span class="toggle">▼</span>
        </div>
        <div class="customer-content">
            $($categoryHtml -join "`n")
            <div class="category-total" style="font-size:1.1em;border-top:2px solid #3498db;margin-top:15px;padding-top:15px;">
                Customer Total: $customerTotal
            </div>
        </div>
    </div>
"@
}
#endregion

#region Main Processing
try {
    Write-Host "Reading CSV from: $CsvPath" -ForegroundColor Cyan
    $billingData = Import-Csv -Path $CsvPath
    
    # Get all column names (license types)
    $allColumns = $billingData[0].PSObject.Properties.Name | Where-Object { $_ -ne 'Company' }
    
    # Build a list of all known non-Microsoft columns
    $nonMicrosoftColumns = $LicenseCategories.SentinelOne + $LicenseCategories.NinjaRMM + $LicenseCategories.ThirdParty
    
    # Microsoft columns = everything else
    $microsoftColumns = $allColumns | Where-Object { $_ -notin $nonMicrosoftColumns }
    
    # Initialize summary counters
    $totalLicenses = 0
    $categoryTotals = @{
        SentinelOne = 0
        NinjaRMM = 0
        Microsoft = 0
        ThirdParty = 0
    }
    
    $customerHtmlBlocks = @()
    $customersWithLicenses = 0
    
    foreach ($row in $billingData) {
        $customerName = $row.Company
        if ([string]::IsNullOrWhiteSpace($customerName)) { continue }
        
        $licensesByCategory = @{
            SentinelOne = @{}
            NinjaRMM = @{}
            Microsoft = @{}
            ThirdParty = @{}
        }
        
        # Process each license column
        foreach ($col in $allColumns) {
            $value = $row.$col
            
            # Skip empty, null, zero, or non-numeric values
            if ([string]::IsNullOrWhiteSpace($value)) { continue }
            
            # Handle SKU fields (like "Control") - keep as text
            $numericValue = 0
            $isNumeric = [int]::TryParse($value, [ref]$numericValue)
            
            if ($isNumeric -and $numericValue -eq 0) { continue }
            if (-not $isNumeric -and $value -eq '0') { continue }
            
            # Determine category
            $category = if ($col -in $LicenseCategories.SentinelOne) { 'SentinelOne' }
                        elseif ($col -in $LicenseCategories.NinjaRMM) { 'NinjaRMM' }
                        elseif ($col -in $LicenseCategories.ThirdParty) { 'ThirdParty' }
                        elseif ($col -like 'PAX8_*') { 'Microsoft' }
                        else { $null }  # Skip non-PAX8 Microsoft licenses (duplicates)
            
            # Skip if no category matched (non-PAX8 Microsoft)
            if ($null -eq $category) { continue }
            
            # Store the value (numeric or text like SKU)
            $displayValue = if ($isNumeric) { $numericValue } else { $value }
            $licensesByCategory[$category][$col] = $displayValue
            
            # Add to totals (only numeric)
            if ($isNumeric) {
                $totalLicenses += $numericValue
                $categoryTotals[$category] += $numericValue
            }
        }
        
        # Generate HTML for this customer
        $customerHtml = Get-CustomerHtml -CustomerName $customerName -LicensesByCategory $licensesByCategory
        if ($customerHtml) {
            $customerHtmlBlocks += $customerHtml
            $customersWithLicenses++
        }
    }
    
    # Build final HTML
    $html = @()
    $html += Get-HtmlHeader
    $html += Get-SummaryHtml -CustomerCount $customersWithLicenses -TotalLicenses $totalLicenses -CategoryTotals $categoryTotals
    $html += $customerHtmlBlocks
    $html += Get-HtmlFooter
    
    # Ensure output directory exists
    $outputDir = Split-Path -Path $OutputPath -Parent
    if ($outputDir -and -not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }
    
    # Write HTML file (UTF8 with BOM for proper emoji display)
    $Utf8BomEncoding = New-Object System.Text.UTF8Encoding $true
    [System.IO.File]::WriteAllText($OutputPath, ($html -join "`n"), $Utf8BomEncoding)
    
    Write-Host "`n✅ Report generated successfully!" -ForegroundColor Green
    Write-Host "   Output: $OutputPath" -ForegroundColor White
    Write-Host "   Customers: $customersWithLicenses" -ForegroundColor White
    Write-Host "   Total Licenses: $totalLicenses" -ForegroundColor White
}
catch {
    Write-Error "Failed to generate report: $_"
    exit 1
}
#endregion
