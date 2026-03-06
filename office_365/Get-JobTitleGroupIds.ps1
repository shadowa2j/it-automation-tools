<#
.SYNOPSIS
    Retrieves Entra ID group IDs for job title groups and formats them for use in a dynamic membership rule.

.DESCRIPTION
    Pulls all Entra groups once, then filters client-side by exact display name in the format
    "All - <Job Title> - Role". Avoids OData filter issues with special characters (e.g. &).
    Outputs a ready-to-paste dynamic membership rule expression for group nesting.

.NOTES
    Requires: Microsoft.Graph PowerShell SDK
    Permissions: Group.Read.All
    Install: Install-Module Microsoft.Graph -Scope CurrentUser
#>

[CmdletBinding()]
param()

#region Job Titles
$JobTitles = @(
    'Account Manager'
    'Accounting Manager'
    'AR Billing & Revenue Manager'
    'Business Development Manager'
    'Commodity Buyer'
    'Corporate Quality Engineer'
    'Corporate Quality Manager'
    'Customer Account Support Manager'
    'Customer Service Representative'
    'Customer Support Engineer'
    'Design Engineer'
    'Development Engineer'
    'Engineering Manager'
    'ERP System Analyst'
    'General Manager'
    'HR Generalist'
    'Operations Manager'
    'Process Development Engineer'
    'Program Manager'
    'Project Engineer'
    'Project Manager'
    'Tooling Estimator and Project Scheduler'
)
#endregion

#region Connect
Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
try {
    Connect-MgGraph -Scopes "Group.Read.All" -NoWelcome -ErrorAction Stop
} catch {
    Write-Error "Failed to connect to Microsoft Graph: $($_.Exception.Message)"
    exit 1
}
#endregion

#region Pull All Groups Once
Write-Host "Retrieving all groups from Entra ID..." -ForegroundColor Cyan
try {
    $AllGroups = Get-MgGroup -All -Property "Id,DisplayName" -ErrorAction Stop
    Write-Host "  Retrieved $($AllGroups.Count) total groups." -ForegroundColor Gray
} catch {
    Write-Error "Failed to retrieve groups: $($_.Exception.Message)"
    exit 1
}

# Build a hashtable for fast exact-match lookups (case-insensitive)
$GroupLookup = @{}
foreach ($g in $AllGroups) {
    $GroupLookup[$g.DisplayName.ToLower()] = $g
}
#endregion

#region Match Job Title Groups
$FoundGroups   = [System.Collections.Generic.List[PSCustomObject]]::new()
$MissingGroups = [System.Collections.Generic.List[string]]::new()

foreach ($Title in $JobTitles) {
    $GroupName = "All - $Title - Role"
    $Match     = $GroupLookup[$GroupName.ToLower()]

    if ($Match) {
        $FoundGroups.Add([PSCustomObject]@{
            JobTitle  = $Title
            GroupName = $Match.DisplayName
            ObjectId  = $Match.Id
        })
        Write-Host "  [FOUND]   $GroupName" -ForegroundColor Green
    } else {
        $MissingGroups.Add($GroupName)
        Write-Warning "  [MISSING] $GroupName"
    }
}
#endregion

#region Output Results
Write-Host "`n--- Results ---" -ForegroundColor Cyan

if ($FoundGroups.Count -gt 0) {
    Write-Host "`nFound $($FoundGroups.Count) of $($JobTitles.Count) group(s):`n" -ForegroundColor Green
    $FoundGroups | Format-Table -AutoSize

    # Build dynamic membership rule string
    $GuidList    = $FoundGroups | ForEach-Object { "`"$($_.ObjectId)`"" }
    $GuidString  = $GuidList -join ', '
    $DynamicRule = "(user.memberOf -any (group.objectId -in [$GuidString]))"

    Write-Host "`n--- Dynamic Membership Rule ---" -ForegroundColor Cyan
    Write-Host $DynamicRule -ForegroundColor Yellow

    $DynamicRule | Set-Clipboard
    Write-Host "`n(Rule copied to clipboard)" -ForegroundColor Gray
} else {
    Write-Warning "No groups were found."
}

if ($MissingGroups.Count -gt 0) {
    Write-Host "`n--- Missing Groups ($($MissingGroups.Count)) ---" -ForegroundColor Yellow
    $MissingGroups | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
}
#endregion
