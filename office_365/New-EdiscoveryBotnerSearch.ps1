<#
.SYNOPSIS
    Creates and runs a Standard eDiscovery compliance search for the Greg Botner mailbox at Wilbert.

.DESCRIPTION
    Creates a Microsoft Purview eDiscovery case and two searches:

      1. Botner-2021-AllTerms
         Full year 2021 search across three categories:
           - Domain contacts: brandes.com, capreturns.com, pinebridge.com
           - Specific email addresses (7 addresses)
           - Named individuals and handles (Keith Duffy, Benson/Marcia Chapman,
             Dawn Dawick, Lance/Rory Montano)

      2. Botner-2022-Q1-FullCollection
         Full mailbox collection Jan 1 - Mar 31, 2022 for data vendor delivery.

    Once searches complete, export to PST from the Purview portal:
      purview.microsoft.com > eDiscovery > Cases > [case name] > Searches > Export

.NOTES
    Requires : ExchangeOnlineManagement module v3.9.0 or higher
    Role     : eDiscovery Manager or eDiscovery Administrator in Microsoft Purview
    Mailbox  : gbotner@wilbertinc.com (shared mailbox)
    Updated  : May 2026 - PowerShell export retired May 26 2025 for Standard eDiscovery.
               Case creation, search creation, and running remain fully supported.
               -EnableSearchOnlySession is required on Connect-IPPSSession as of v3.9.0.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]$AdminUPN,

    [string]$TargetMailbox      = 'gbotner@wilbertinc.com',
    [string]$CaseName           = 'Wilbert-Botner-eDiscovery-2026',
    [string]$SearchName2021     = 'Botner-2021-AllTerms',
    [string]$SearchName2022Q1   = 'Botner-2022-Q1-FullCollection'
)

$ErrorActionPreference = 'Stop'
$terminalStates        = @('Completed', 'Failed', 'Stopped', 'PartiallySucceeded')

#region Connect
try {
    Write-Host "Connecting to Security & Compliance PowerShell as $AdminUPN..." -ForegroundColor Cyan
    Connect-IPPSSession -UserPrincipalName $AdminUPN -EnableSearchOnlySession
    Write-Host "Connected." -ForegroundColor Green
}
catch {
    Write-Error "Failed to connect: $_"
    exit 1
}
#endregion

#region Create Case
try {
    $existingCase = Get-ComplianceCase -Identity $CaseName -ErrorAction SilentlyContinue
    if ($existingCase) {
        Write-Host "Case '$CaseName' already exists. Skipping creation." -ForegroundColor Yellow
    }
    else {
        Write-Host "Creating eDiscovery case: $CaseName" -ForegroundColor Cyan
        New-ComplianceCase -Name $CaseName
        Write-Host "Case created." -ForegroundColor Green
    }
}
catch {
    Write-Error "Failed to create case: $_"
    exit 1
}
#endregion

#region Build 2021 KQL Query

# Date range - covers both received mail (Inbox) and sent mail (Sent Items)
$dateRange2021 = '(received:2021-01-01..2021-12-31 OR sent:2021-01-01..2021-12-31)'

# Domain searches
# participants: covers From, To, CC, and BCC fields
# Correct KQL syntax for domain: participants:domain.com (no wildcard prefix - not supported)
$domainQuery = @(
    'participants:brandes.com',
    'participants:capreturns.com',
    'participants:pinebridge.com'
) -join ' OR '

# Specific email addresses
$emailQuery = @(
    'participants:ron@capreturns.com',
    'participants:jsennott@capspecialty.com',
    'participants:Charles.Brandes@brandes.com',
    'participants:taxben@aol.com',
    'participants:bryan.barrett@brandes.com',
    'participants:gsmith@kytrailer.com',
    'participants:gary.smith@kytrailer.com'
) -join ' OR '

# Named individuals and handles
# No property prefix = searches all indexed content (subject, body, attachments)
# NEAR(n) = terms within n words of each other; operators must be uppercase
# Note: bare 'Montano' may return broad results - included by attorney request
$nameQuery = @(
    # Keith Duffy
    'kduffy*',
    '"Keith Duffy"',
    'Keith NEAR(2) Duffy',

    # Benson Chapman / Marcia Chapman
    '"Benson Chapman"',
    '"Marcia Chapman"',
    'bchapman*',
    'mchapman*',

    # Dawn Dawick
    'Dawick',
    'ddawick*',

    # Lance Montano / Rory Montano
    'Lance NEAR(2) Montano',
    'Rory NEAR(2) Montano',
    'Montano',
    'lmontano*',
    'rmontano*'
) -join ' OR '

$kqlQuery2021 = "$dateRange2021 AND (($domainQuery) OR ($emailQuery) OR ($nameQuery))"

Write-Verbose "2021 KQL Query:`n$kqlQuery2021"

#endregion

#region Create and Run 2021 Search
try {
    $existingSearch = Get-ComplianceSearch -Identity $SearchName2021 -ErrorAction SilentlyContinue
    if ($existingSearch) {
        Write-Host "Search '$SearchName2021' already exists. Skipping creation." -ForegroundColor Yellow
    }
    else {
        Write-Host "Creating compliance search: $SearchName2021" -ForegroundColor Cyan
        New-ComplianceSearch `
            -Name              $SearchName2021 `
            -Case              $CaseName `
            -ExchangeLocation  $TargetMailbox `
            -ContentMatchQuery $kqlQuery2021 `
            -Description       'Wilbert Botner mailbox - 2021 full year - domains, addresses, named individuals'
        Write-Host "Search created." -ForegroundColor Green
    }
}
catch {
    Write-Error "Failed to create 2021 search: $_"
    exit 1
}

try {
    Write-Host "Starting search: $SearchName2021" -ForegroundColor Cyan
    Start-ComplianceSearch -Identity $SearchName2021
}
catch {
    Write-Error "Failed to start search: $_"
    exit 1
}
#endregion

#region Poll 2021 Search
Write-Host "Polling for completion (checks every 30 seconds, max 30 minutes)..." -ForegroundColor Cyan

$maxWaitMinutes = 30
$elapsedMinutes = 0
$itemsFound2021 = 0
$sizeMB2021     = 0

do {
    Start-Sleep -Seconds 30
    $elapsedMinutes += 0.5

    $search2021     = Get-ComplianceSearch -Identity $SearchName2021
    $status2021     = $search2021.Status
    $itemsFound2021 = $search2021.Items
    $sizeMB2021     = [math]::Round($search2021.Size / 1MB, 2)

    Write-Host "  [$elapsedMinutes min] Status: $status2021 | Items: $itemsFound2021 | Size: $sizeMB2021 MB"
}
while ($status2021 -notin $terminalStates -and $elapsedMinutes -lt $maxWaitMinutes)

if ($status2021 -ne 'Completed') {
    Write-Warning "2021 search ended with status '$status2021'. Check the Purview portal before proceeding."
    exit 1
}

Write-Host "2021 search complete. Items: $itemsFound2021 | Size: $sizeMB2021 MB" -ForegroundColor Green
#endregion

#region Create and Run Q1 2022 Search
$kqlQuery2022Q1 = '(received:2022-01-01..2022-03-31 OR sent:2022-01-01..2022-03-31)'

try {
    $existingSearch2022 = Get-ComplianceSearch -Identity $SearchName2022Q1 -ErrorAction SilentlyContinue
    if ($existingSearch2022) {
        Write-Host "Search '$SearchName2022Q1' already exists. Skipping creation." -ForegroundColor Yellow
    }
    else {
        Write-Host "Creating compliance search: $SearchName2022Q1" -ForegroundColor Cyan
        New-ComplianceSearch `
            -Name              $SearchName2022Q1 `
            -Case              $CaseName `
            -ExchangeLocation  $TargetMailbox `
            -ContentMatchQuery $kqlQuery2022Q1 `
            -Description       'Wilbert Botner mailbox - Q1 2022 full collection for data vendor'
        Write-Host "Search created." -ForegroundColor Green
    }
}
catch {
    Write-Error "Failed to create Q1 2022 search: $_"
    exit 1
}

try {
    Write-Host "Starting search: $SearchName2022Q1" -ForegroundColor Cyan
    Start-ComplianceSearch -Identity $SearchName2022Q1
}
catch {
    Write-Error "Failed to start search: $_"
    exit 1
}
#endregion

#region Poll Q1 2022 Search
Write-Host "Polling for completion (checks every 30 seconds, max 30 minutes)..." -ForegroundColor Cyan

$elapsedMinutes  = 0
$itemsFound2022  = 0
$sizeMB2022      = 0

do {
    Start-Sleep -Seconds 30
    $elapsedMinutes += 0.5

    $search2022     = Get-ComplianceSearch -Identity $SearchName2022Q1
    $status2022     = $search2022.Status
    $itemsFound2022 = $search2022.Items
    $sizeMB2022     = [math]::Round($search2022.Size / 1MB, 2)

    Write-Host "  [$elapsedMinutes min] Status: $status2022 | Items: $itemsFound2022 | Size: $sizeMB2022 MB"
}
while ($status2022 -notin $terminalStates -and $elapsedMinutes -lt $maxWaitMinutes)

if ($status2022 -ne 'Completed') {
    Write-Warning "Q1 2022 search ended with status '$status2022'. Check the Purview portal before proceeding."
    exit 1
}

Write-Host "Q1 2022 search complete. Items: $itemsFound2022 | Size: $sizeMB2022 MB" -ForegroundColor Green
#endregion

#region Summary
Write-Host @"

=================================================================
  All Searches Complete
=================================================================
  Case              : $CaseName
  Mailbox           : $TargetMailbox

  $SearchName2021
    Date Range      : Jan 1, 2021 - Dec 31, 2021 (sent and received)
    Items Found     : $itemsFound2021
    Total Size      : $sizeMB2021 MB

  $SearchName2022Q1
    Date Range      : Jan 1, 2022 - Mar 31, 2022 (sent and received)
    Items Found     : $itemsFound2022
    Total Size      : $sizeMB2022 MB

  To export to PST:
  1. Go to purview.microsoft.com
  2. Navigate to eDiscovery > Cases
  3. Open case '$CaseName'
  4. Go to Searches, select the search to export
  5. Click Export and follow the prompts to download the PST
=================================================================
"@ -ForegroundColor Cyan
#endregion
