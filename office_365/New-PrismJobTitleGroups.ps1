<#
.SYNOPSIS
    Creates or audits Entra ID Microsoft 365 groups for job title dynamic membership.

.DESCRIPTION
    For each group in the list:
      - If the group does NOT exist: creates it with rule paused, disables welcome message, then enables rule
      - If the group DOES exist: checks welcome message, membership rule, and processing state -- fixes anything wrong

    Order of operations for new groups:
      1. Create group with rule processing paused (no members added yet)
      2. Disable welcome message via Exchange Online
      3. Enable dynamic membership rule so users are added silently

.NOTES
    Requires: Microsoft.Graph PowerShell SDK, ExchangeOnlineManagement module
    Permissions: Group.ReadWrite.All
    Tenant: prismplastics.com
#>

[CmdletBinding()]
param()

#region Groups to Create
$GroupsToCreate = @(
    @{ DisplayName = 'All - Customer Account Support Manager - Role'; JobTitle = 'Customer Account Support Manager'           }
    @{ DisplayName = 'All - ERP System Analyst - Role';               JobTitle = 'ERP System Analyst'                        }
    @{ DisplayName = 'All - Program Manager - Role';                  JobTitle = 'Program Manager'                           }
    @{ DisplayName = 'All - Tooling Estimator and Project Scheduler - Role'; JobTitle = 'Tooling Estimator and Project Scheduler' }
)
#endregion

#region Connect - Microsoft Graph
Write-Host "Connecting to Microsoft Graph (Prism Plastics)..." -ForegroundColor Cyan
try {
    Connect-MgGraph -Scopes "Group.ReadWrite.All" -TenantId "prismplastics.com" -NoWelcome -ErrorAction Stop
} catch {
    Write-Error "Failed to connect to Microsoft Graph: $($_.Exception.Message)"
    exit 1
}
#endregion

#region Connect - Exchange Online
Write-Host "Connecting to Exchange Online (Prism Plastics)..." -ForegroundColor Cyan
try {
    Connect-ExchangeOnline -UserPrincipalName "bfaulkner@prismplastics.com" -ShowBanner:$false -ErrorAction Stop
} catch {
    Write-Error "Failed to connect to Exchange Online: $($_.Exception.Message)"
    exit 1
}
#endregion

#region Process Groups
foreach ($Group in $GroupsToCreate) {

    Write-Host "`nProcessing: $($Group.DisplayName)" -ForegroundColor Cyan

    $MembershipRule = "(user.accountEnabled -eq True) and (user.jobTitle -eq `"$($Group.JobTitle)`")"
    $MailNickname   = ($Group.DisplayName -replace '[^a-zA-Z0-9]', '')

    # Check if group already exists
    $Existing = Get-MgGroup -Filter "displayName eq '$($Group.DisplayName)'" -ConsistencyLevel eventual `
        -Property "Id,DisplayName,MembershipRule,MembershipRuleProcessingState" -ErrorAction SilentlyContinue

    if ($Existing) {
        # -----------------------------------------------------------------------
        # EXISTING GROUP - audit and fix
        # -----------------------------------------------------------------------
        Write-Host "  Group already exists (ID: $($Existing.Id)) -- auditing settings..." -ForegroundColor Yellow
        $GroupId    = $Existing.Id
        $IsNewGroup = $false

    } else {
        # -----------------------------------------------------------------------
        # NEW GROUP - create with rule paused
        # -----------------------------------------------------------------------
        $Params = @{
            DisplayName                   = $Group.DisplayName
            GroupTypes                    = @("Unified", "DynamicMembership")
            MailEnabled                   = $true
            MailNickname                  = $MailNickname
            SecurityEnabled               = $false
            MembershipRule                = $MembershipRule
            MembershipRuleProcessingState = "Paused"
            Visibility                    = "Private"
        }

        try {
            $NewGroup   = New-MgGroup @Params -ErrorAction Stop
            $GroupId    = $NewGroup.Id
            $IsNewGroup = $true
            Write-Host "  [1/3] Created (rule paused, no members yet)" -ForegroundColor Green
            Write-Host "        ID: $GroupId" -ForegroundColor Gray
        } catch {
            Write-Warning "  [1/3] FAILED to create group: $($_.Exception.Message)"
            continue
        }

        # Wait for EXO to provision the group before touching it
        Write-Host "  [2/3] Waiting for Exchange Online provisioning..." -ForegroundColor Gray
        Start-Sleep -Seconds 15
    }

    # -----------------------------------------------------------------------
    # CHECK/FIX - Welcome message (both new and existing groups)
    # -----------------------------------------------------------------------
    $StepLabel = if ($IsNewGroup) { "[2/3]" } else { "[CHECK]" }

    try {
        $EXOGroup = Get-UnifiedGroup -Identity $Group.DisplayName -ErrorAction Stop

        if ($EXOGroup.WelcomeMessageEnabled -ne $false) {
            Set-UnifiedGroup -Identity $Group.DisplayName -UnifiedGroupWelcomeMessageEnabled:$false -ErrorAction Stop
            Write-Host "  $StepLabel Welcome message disabled." -ForegroundColor $(if ($IsNewGroup) { "Green" } else { "Yellow" })
        } else {
            Write-Host "  $StepLabel Welcome message: already disabled. OK" -ForegroundColor Green
        }
    } catch {
        Write-Warning "  $StepLabel Failed to check/set welcome message: $($_.Exception.Message)"
        Write-Warning "             Manually run: Set-UnifiedGroup -Identity '$($Group.DisplayName)' -UnifiedGroupWelcomeMessageEnabled:`$false"
    }

    # -----------------------------------------------------------------------
    # CHECK/FIX - Membership rule and processing state (both new and existing)
    # -----------------------------------------------------------------------
    $StepLabel    = if ($IsNewGroup) { "[3/3]" } else { "[CHECK]" }
    $UpdateParams = @{ GroupId = $GroupId }
    $NeedsUpdate  = $false

    if (-not $IsNewGroup) {
        # Check rule content
        if ($Existing.MembershipRule -ne $MembershipRule) {
            Write-Host "  $StepLabel Membership rule mismatch -- will update." -ForegroundColor Yellow
            Write-Host "             Expected: $MembershipRule" -ForegroundColor Gray
            Write-Host "             Current:  $($Existing.MembershipRule)" -ForegroundColor Gray
            $UpdateParams['MembershipRule'] = $MembershipRule
            $NeedsUpdate = $true
        } else {
            Write-Host "  $StepLabel Membership rule: correct. OK" -ForegroundColor Green
        }

        # Check processing state
        if ($Existing.MembershipRuleProcessingState -ne "On") {
            Write-Host "  $StepLabel Rule processing is '$($Existing.MembershipRuleProcessingState)' -- will enable." -ForegroundColor Yellow
            $UpdateParams['MembershipRuleProcessingState'] = "On"
            $NeedsUpdate = $true
        } else {
            Write-Host "  $StepLabel Rule processing state: On. OK" -ForegroundColor Green
        }

        if ($NeedsUpdate) {
            try {
                Update-MgGroup @UpdateParams -ErrorAction Stop
                Write-Host "  [CHECK] Group settings updated successfully." -ForegroundColor Green
            } catch {
                Write-Warning "  [CHECK] Failed to update group: $($_.Exception.Message)"
            }
        }

    } else {
        # New group -- just enable the rule now that welcome message is disabled
        try {
            Update-MgGroup -GroupId $GroupId -MembershipRuleProcessingState "On" -ErrorAction Stop
            Write-Host "  $StepLabel Dynamic membership rule enabled. Users will be added silently." -ForegroundColor Green
            Write-Host "             Rule: $MembershipRule" -ForegroundColor Gray
        } catch {
            Write-Warning "  $StepLabel Failed to enable dynamic membership rule: $($_.Exception.Message)"
            Write-Warning "             Manually enable the rule in Entra ID for: $($Group.DisplayName)"
        }
    }
}
#endregion

#region Disconnect
Disconnect-ExchangeOnline -Confirm:$false
Write-Host "`nDisconnected from Exchange Online." -ForegroundColor Gray
#endregion

Write-Host "`nDone." -ForegroundColor Cyan
