#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Disables AutoRun and AutoPlay for all drive types via registry policy.

.DESCRIPTION
    Sets NoDriveTypeAutoRun and NoAutorun registry values under both the
    machine-wide policy hive (HKLM) and the default user profile hive (HKU\.DEFAULT).
    Ensures registry paths exist before writing. Requires administrative privileges.

.NOTES
    Author:       Quality Computer Solutions
    Version:      1.2
    Target:       Windows endpoints (domain-joined or standalone)
    Run Context:  SYSTEM or Administrator

    Registry paths targeted:
        HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer
        HKU:\.DEFAULT\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer

    Values written:
        NoDriveTypeAutoRun  = 0xFF (255) - Disables AutoRun on all drive types
        NoAutorun           = 1          - Disables AutoRun prompt/execution
#>

[CmdletBinding()]
param ()

#region Functions

function Set-AutoRunRegistryValues {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [hashtable]$Values
    )

    if (-not (Test-Path $Path)) {
        Write-Verbose "Path not found, creating: $Path"
        New-Item -Path $Path -Force | Out-Null
    }

    foreach ($entry in $Values.GetEnumerator()) {
        Write-Verbose "Setting $($entry.Key) = $($entry.Value) at $Path"
        Set-ItemProperty -Path $Path -Name $entry.Key -Type DWord -Value $entry.Value -Force
    }
}

#endregion

#region Main

$ErrorActionPreference = 'Stop'
$hkuMounted = $false

try {
    if (-not (Get-PSDrive -Name HKU -ErrorAction SilentlyContinue)) {
        Write-Verbose "Mounting HKU PSDrive..."
        New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS | Out-Null
        $hkuMounted = $true
    }

    $regPaths = @{
        HKLM       = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'
        HKUDefault = 'HKU:\.DEFAULT\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'
    }

    $autoRunValues = @{
        NoDriveTypeAutoRun = 0xFF
        NoAutorun          = 1
    }

    Write-Verbose "Applying AutoRun policy to HKLM..."
    Set-AutoRunRegistryValues -Path $regPaths.HKLM -Values $autoRunValues

    Write-Verbose "Applying AutoRun policy to HKU\.DEFAULT..."
    Set-AutoRunRegistryValues -Path $regPaths.HKUDefault -Values $autoRunValues

    Write-Output "AutoRun registry policy applied successfully."
    exit 0
}
catch {
    Write-Error "Failed to apply AutoRun registry policy: $_"
    exit 1
}
finally {
    if ($hkuMounted) {
        Write-Verbose "Removing HKU PSDrive..."
        Remove-PSDrive -Name HKU -ErrorAction SilentlyContinue
    }
}

#endregion
