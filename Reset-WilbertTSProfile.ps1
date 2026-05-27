<#
.SYNOPSIS
    Full RDS profile reset for a single user in the Wilbert TS farm.
    Kills active/disconnected sessions, dismounts the UPD VHDX, renames it,
    cleans the ProfileList registry, and removes C:\Users\<username> on all hosts.

.DESCRIPTION
    Targets the Wilbert TS farm (wps-inap-ts02w, wps-inap-ts03w) and UPD share
    (\\WPS-inap-fs01w\TS_User_Profiles\Profiles). Run from an admin workstation
    with WinRM access to both TS hosts and read/write access to the UPD share.

    All destructive operations are scoped exclusively to the specified user's
    SID, VHDX, registry key, and profile folder. Nothing else is modified.

    The VHDX is renamed (UVHD-<SID>-old.vhdx) rather than deleted, giving you
    a recovery path if something goes wrong.

.PARAMETER Username
    The SAMAccountName of the user whose profile should be reset.

.PARAMETER Force
    Skips the confirmation prompt.

.EXAMPLE
    .\Reset-WilbertTSProfile.ps1 -Username jsmith

.EXAMPLE
    .\Reset-WilbertTSProfile.ps1 -Username jsmith -Force
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]$Username,

    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$TSHosts  = @('wps-inap-ts02w', 'wps-inap-ts03w')
$UPDShare = '\\WPS-inap-fs01w\TS_User_Profiles\Profiles'

# How long to wait (seconds) after killing sessions before checking VHDX state
$SessionKillWaitSeconds = 15

# How long to poll (seconds) for the VHDX file lock to clear before trying force dismount
$VHDXLockTimeoutSeconds = 60

#region Output helpers
function Write-Step    { param([string]$m) Write-Host "`n[*] $m" -ForegroundColor Cyan }
function Write-Success { param([string]$m) Write-Host "    [+] $m" -ForegroundColor Green }
function Write-Warn    { param([string]$m) Write-Host "    [!] $m" -ForegroundColor Yellow }
function Write-Fail    { param([string]$m) Write-Host "    [-] $m" -ForegroundColor Red }
#endregion

# ---------------------------------------------------------------------------
# Step 1: Resolve the user's SID from AD
# ---------------------------------------------------------------------------
Write-Step "Resolving AD account for '$Username'..."
try {
    $ADUser  = Get-ADUser -Identity $Username -Properties SID -ErrorAction Stop
    $UserSID = $ADUser.SID.Value
    Write-Success "Found:  $($ADUser.DistinguishedName)"
    Write-Success "SID:    $UserSID"
} catch {
    Write-Fail "AD lookup failed for '$Username': $_"
    exit 1
}

# ---------------------------------------------------------------------------
# Step 2: Check for active/disconnected sessions and kill them
#
# Using quser /server: and logoff /server: directly from the admin workstation
# rather than Invoke-Command. Terminal Services session enumeration via WinRM
# is unreliable - quser /server: uses RPC and correctly sees all sessions.
# ---------------------------------------------------------------------------
Write-Step "Checking for sessions on TS hosts..."

# Parse session IDs from quser output for a specific user.
# Anchors on the state word (Active/Disc) so it works whether SESSIONNAME
# is populated (active) or blank (disconnected), both of which shift columns.
function Get-TSSessionIDs {
    param([string]$Username, [string]$Server)
    # quser exits 1 and writes to stderr when the user has no session.
    # With $ErrorActionPreference = 'Stop', that triggers a NativeCommandError
    # before $LASTEXITCODE can be checked, so we catch it here instead.
    try {
        $output = & quser $Username /server:$Server 2>&1
    } catch {
        return @()  # "No User exists" - not an error, just no session
    }
    if ($LASTEXITCODE -ne 0) { return @() }
    $ids = @()
    $output | Select-Object -Skip 1 | ForEach-Object {
        if ($_ -match '\s+(\d+)\s+(Active|Disc)\b') {
            $ids += $Matches[1]
        }
    }
    return $ids
}

$SessionsKilled = $false

foreach ($TSHost in $TSHosts) {
    try {
        $SessionIDs = Get-TSSessionIDs -Username $Username -Server $TSHost

        if ($SessionIDs.Count -eq 0) {
            Write-Success "No sessions on $TSHost"
        } else {
            foreach ($ID in $SessionIDs) {
                Write-Warn "Killing session ID $ID on $TSHost..."
                & logoff $ID /server:$TSHost
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "Session $ID logged off on $TSHost"
                    $SessionsKilled = $true
                } else {
                    Write-Warn "logoff returned non-zero for session $ID on $TSHost"
                }
            }
        }
    } catch {
        Write-Warn "Could not check/kill sessions on ${TSHost}: $_"
    }
}

# Give the OS time to write the profile and release the VHDX after logoff
if ($SessionsKilled) {
    Write-Step "Waiting ${SessionKillWaitSeconds}s for sessions to fully close..."
    Start-Sleep -Seconds $SessionKillWaitSeconds
}

# Verify sessions are actually gone before continuing
Write-Step "Verifying sessions are closed..."
$StillActive = @()
foreach ($TSHost in $TSHosts) {
    $Remaining = Get-TSSessionIDs -Username $Username -Server $TSHost
    if ($Remaining.Count -gt 0) {
        $StillActive += $TSHost
        Write-Warn "Sessions still present on $TSHost after logoff attempt"
    } else {
        Write-Success "Confirmed no sessions on $TSHost"
    }
}

if ($StillActive.Count -gt 0) {
    Write-Fail "Sessions could not be terminated on: $($StillActive -join ', ')"
    Write-Fail "Cannot safely proceed while sessions are active. Aborting."
    exit 1
}

# ---------------------------------------------------------------------------
# Step 3: Confirm before doing anything destructive
# ---------------------------------------------------------------------------
$VHDXPath    = "$UPDShare\UVHD-$UserSID.vhdx"
$VHDXOldPath = "$UPDShare\UVHD-$UserSID-old.vhdx"

if (-not $Force) {
    Write-Host "`n    The following actions will be taken for user '$Username':" -ForegroundColor Yellow
    Write-Host "      VHDX rename:      $VHDXPath" -ForegroundColor Yellow
    Write-Host "                    --> $VHDXOldPath" -ForegroundColor Yellow
    Write-Host "      Registry cleanup: ProfileList\$UserSID (+ .bak) on each TS host" -ForegroundColor Yellow
    Write-Host "      Profile folder:   C:\Users\$Username on each TS host" -ForegroundColor Yellow
    Write-Host ""
    $Confirm = Read-Host "    Type YES to proceed"
    if ($Confirm -ne 'YES') {
        Write-Host "    Aborted.`n" -ForegroundColor Gray
        exit 0
    }
}

# ---------------------------------------------------------------------------
# Step 4: Handle the VHDX
#
# Critical: renaming a VHDX file does NOT dismount it. Windows allows renaming
# open files, which means the rename can succeed while the VHDX is still
# mounted on a TS host. The renamed file stays mounted, blocks the new VHDX
# from mounting at C:\Users\<username>, and causes ntuser.dat access errors.
#
# Fix: test the file lock directly on the file server before renaming. An
# exclusive open attempt is the only definitive check - if it succeeds, the
# file is not held by any host and is safe to rename. We poll up to
# $VHDXLockTimeoutSeconds seconds, then attempt a force dismount on each TS
# host if the lock has not cleared on its own.
# ---------------------------------------------------------------------------
Write-Step "Locating UPD VHDX..."

if (-not (Test-Path $VHDXPath)) {
    Write-Warn "VHDX not found at expected path. It may not exist yet or was already renamed."
    Write-Warn "  Expected: $VHDXPath"
} else {
    Write-Success "VHDX found."

    # Parse file server and share name out of the UPD share path
    $UPDParts   = $UPDShare.TrimStart('\') -split '\\'
    $FileServer = $UPDParts[0]
    $ShareName  = $UPDParts[1]
    $SubFolder  = $UPDParts[2]

    # Tests whether the VHDX file is currently held open by any process.
    # Runs on the file server where the file is local - no double-hop issue.
    $IsLockedBlock = {
        param($ShareName, $SubFolder, $UserSID)
        $ShareRoot = (Get-SmbShare -Name $ShareName -ErrorAction Stop).Path
        $VHDXLocal = [System.IO.Path]::Combine($ShareRoot, $SubFolder, "UVHD-$UserSID.vhdx")
        if (-not (Test-Path $VHDXLocal)) { return $false }
        try {
            $stream = [System.IO.File]::Open(
                $VHDXLocal,
                [System.IO.FileMode]::Open,
                [System.IO.FileAccess]::ReadWrite,
                [System.IO.FileShare]::None
            )
            $stream.Close()
            $stream.Dispose()
            return $false
        } catch {
            return $true
        }
    }

    # Tries to find and dismount the user's UPD on a TS host.
    # Uses mountvol (native) with CIM as fallback.
    # Works via the volume mount point - no UNC access needed, no double-hop.
    $DismountBlock = {
        param($Username)
        $result = [PSCustomObject]@{
            WasMounted = $false
            Dismounted = $false
            Method     = $null
            Error      = $null
        }
        $MountPoint = "C:\Users\$Username\"
        try {
            $mvOutput = (& mountvol $MountPoint /L 2>&1) -join ''
            if ($LASTEXITCODE -eq 0 -and $mvOutput.Trim() -match '\\\\') {
                $result.WasMounted = $true
                $DevicePath = $mvOutput.Trim().TrimEnd('\')
                Get-DiskImage -DevicePath $DevicePath -ErrorAction Stop | Dismount-DiskImage -ErrorAction Stop
                $result.Dismounted = $true
                $result.Method = 'mountvol'
                return $result
            }
            $vol = Get-CimInstance -ClassName Win32_Volume -ErrorAction SilentlyContinue |
                   Where-Object { $_.Name -eq $MountPoint }
            if ($vol) {
                $result.WasMounted = $true
                $DevicePath = $vol.DeviceID.TrimEnd('\')
                Get-DiskImage -DevicePath $DevicePath -ErrorAction Stop | Dismount-DiskImage -ErrorAction Stop
                $result.Dismounted = $true
                $result.Method = 'CIM'
                return $result
            }
        } catch {
            $result.Error = $_.Exception.Message
        }
        return $result
    }

    # Renames the VHDX on the file server using its local path, then takes
    # ownership and grants Administrators FullControl on the renamed file.
    # UPD VHDXs are created and owned by the TS host machine account, which
    # blocks deletion from admin workstations even with FullControl in the ACL.
    # Fixing ownership after rename ensures -old files can be cleaned up normally.
    $RenameBlock = {
        param($ShareName, $SubFolder, $UserSID)
        $ShareRoot = (Get-SmbShare -Name $ShareName -ErrorAction Stop).Path
        $VHDXLocal = [System.IO.Path]::Combine($ShareRoot, $SubFolder, "UVHD-$UserSID.vhdx")
        $NewLeaf   = "UVHD-$UserSID-old.vhdx"
        $OldLocal  = [System.IO.Path]::Combine($ShareRoot, $SubFolder, $NewLeaf)
        if (Test-Path $OldLocal) {
            $Stamp   = Get-Date -Format 'yyyyMMdd-HHmmss'
            $NewLeaf = "UVHD-$UserSID-old-$Stamp.vhdx"
            Write-Warning "Previous -old VHDX exists. Using timestamped name: $NewLeaf"
        }
        $NewPath = [System.IO.Path]::Combine($ShareRoot, $SubFolder, $NewLeaf)
        Rename-Item -Path $VHDXLocal -NewName $NewLeaf -ErrorAction Stop

        # Take ownership and grant Administrators FullControl so the file
        # can be deleted by any admin without hitting the machine account
        # ownership restriction.
        $acl = Get-Acl -Path $NewPath -ErrorAction Stop
        $adminAccount = New-Object System.Security.Principal.NTAccount('BUILTIN\Administrators')
        $acl.SetOwner($adminAccount)
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            $adminAccount,
            [System.Security.AccessControl.FileSystemRights]::FullControl,
            [System.Security.AccessControl.AccessControlType]::Allow
        )
        $acl.SetAccessRule($rule)
        Set-Acl -Path $NewPath -AclObject $acl -ErrorAction Stop

        return $NewLeaf
    }

    # --- Phase 1: proactive dismount pass on all TS hosts ---
    Write-Step "Checking for mounted UPD on TS hosts..."
    foreach ($TSHost in $TSHosts) {
        try {
            $R = Invoke-Command -ComputerName $TSHost -ScriptBlock $DismountBlock `
                    -ArgumentList $Username -ErrorAction Stop
            if ($R.WasMounted -and $R.Dismounted) {
                Write-Success "Dismounted on $TSHost (via $($R.Method))"
            } elseif ($R.WasMounted -and -not $R.Dismounted) {
                Write-Warn "Found mount on $TSHost but dismount failed: $($R.Error)"
            } else {
                Write-Success "Not mounted on $TSHost"
            }
        } catch {
            Write-Warn "Could not check ${TSHost}: $_"
        }
    }

    # --- Phase 2: poll file lock on the file server ---
    # The RDS stack can take time to release the file handle after logoff.
    # Polling is more reliable than a fixed wait.
    Write-Step "Waiting for VHDX file lock to clear (up to ${VHDXLockTimeoutSeconds}s)..."
    $PollInterval = 3
    $Elapsed      = 0
    $IsLocked     = $true

    while ($IsLocked -and $Elapsed -lt $VHDXLockTimeoutSeconds) {
        try {
            $IsLocked = Invoke-Command -ComputerName $FileServer -ErrorAction Stop `
                -ScriptBlock $IsLockedBlock -ArgumentList $ShareName, $SubFolder, $UserSID
        } catch {
            Write-Warn "Lock check failed: $_"
            break
        }
        if ($IsLocked) {
            Write-Host "    [~] Still locked (${Elapsed}s elapsed). Waiting..." -ForegroundColor DarkYellow
            Start-Sleep -Seconds $PollInterval
            $Elapsed += $PollInterval
        }
    }

    if (-not $IsLocked) {
        Write-Success "VHDX lock cleared after ${Elapsed}s."
    }

    # --- Phase 3: force dismount if still locked after polling ---
    if ($IsLocked) {
        Write-Warn "VHDX still locked after ${Elapsed}s. Attempting force dismount on TS hosts..."
        foreach ($TSHost in $TSHosts) {
            try {
                $R = Invoke-Command -ComputerName $TSHost -ScriptBlock $DismountBlock `
                        -ArgumentList $Username -ErrorAction Stop
                if ($R.Dismounted) {
                    Write-Success "Force dismounted on $TSHost (via $($R.Method))"
                    Start-Sleep -Seconds 5
                    try {
                        $IsLocked = Invoke-Command -ComputerName $FileServer -ErrorAction Stop `
                            -ScriptBlock $IsLockedBlock -ArgumentList $ShareName, $SubFolder, $UserSID
                    } catch { }
                }
            } catch {
                Write-Warn "Could not check ${TSHost}: $_"
            }
        }
    }

    if ($IsLocked) {
        Write-Fail "VHDX is still locked. A TS host has an orphaned mount that could not"
        Write-Fail "be dismounted via WinRM. Check Explorer for the owner, then run this"
        Write-Fail "on that host via Ninja as SYSTEM:"
        Write-Fail ""
        Write-Fail "  `$vol = Get-CimInstance Win32_Volume | Where-Object { `$_.Name -eq 'C:\Users\$Username\' }"
        Write-Fail "  if (`$vol) { Get-DiskImage -DevicePath `$vol.DeviceID.TrimEnd('\') | Dismount-DiskImage }"
        Write-Fail ""
        Write-Fail "Then re-run this script."
        exit 1
    }

    # --- Phase 4: rename ---
    Write-Step "Renaming VHDX (via file server)..."
    try {
        $NewLeafName = Invoke-Command -ComputerName $FileServer -ErrorAction Stop `
            -ScriptBlock $RenameBlock -ArgumentList $ShareName, $SubFolder, $UserSID
        $VHDXOldPath = "$UPDShare\$NewLeafName"
        Write-Success "VHDX renamed to: $NewLeafName"
    } catch {
        Write-Fail "Rename failed: $_"
        exit 1
    }
}


# ---------------------------------------------------------------------------
# Step 5: Remote cleanup on each TS host
#         Scoped exclusively to $UserSID and $Username - nothing else is touched.
# ---------------------------------------------------------------------------
Write-Step "Running remote cleanup on TS hosts..."

$CleanupBlock = {
    param($SID, $Username)

    $Result = [PSCustomObject]@{
        Host          = $env:COMPUTERNAME
        RegistryMain  = 'Not found'
        RegistryBAK   = 'Not found'
        ProfileFolder = 'Not found'
        Errors        = [System.Collections.Generic.List[string]]::new()
    }

    $ProfileListRoot = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'

    # Remove only the registry key that matches this user's exact SID
    $MainKey = Join-Path $ProfileListRoot $SID
    if (Test-Path $MainKey) {
        try {
            Remove-Item -Path $MainKey -Recurse -Force -ErrorAction Stop
            $Result.RegistryMain = 'Deleted'
        } catch {
            $Result.RegistryMain = "Error: $_"
            $Result.Errors.Add("Registry [SID]: $_")
        }
    }

    # Remove the .bak variant for this SID only
    $BAKKey = Join-Path $ProfileListRoot "$SID.bak"
    if (Test-Path $BAKKey) {
        try {
            Remove-Item -Path $BAKKey -Recurse -Force -ErrorAction Stop
            $Result.RegistryBAK = 'Deleted'
        } catch {
            $Result.RegistryBAK = "Error: $_"
            $Result.Errors.Add("Registry [SID.bak]: $_")
        }
    }

    # Remove this user's profile folder and any .NNN variants left behind
    # by failed login attempts (e.g. bfaulkner.000, bfaulkner.001).
    # These block the UPD from mounting at C:\Users\<username> on next login.
    $FoldersRemoved = [System.Collections.Generic.List[string]]::new()
    $FolderErrors   = [System.Collections.Generic.List[string]]::new()

    $ProfileFolders = Get-ChildItem 'C:\Users' -ErrorAction SilentlyContinue |
                      Where-Object { $_.Name -eq $Username -or $_.Name -match ("^" + [regex]::Escape($Username) + "\." + "\d+$") }

    foreach ($Folder in $ProfileFolders) {
        try {
            Remove-Item -Path $Folder.FullName -Recurse -Force -ErrorAction Stop
            $FoldersRemoved.Add($Folder.Name)
        } catch {
            try {
                & cmd.exe /c "rd /s /q `"$($Folder.FullName)`"" 2>&1 | Out-Null
                if (Test-Path $Folder.FullName) { throw "Still present after rd /s /q." }
                $FoldersRemoved.Add("$($Folder.Name) (rd fallback)")
            } catch {
                $FolderErrors.Add("$($Folder.Name): $_")
                $Result.Errors.Add("Profile folder $($Folder.Name): $_")
            }
        }
    }

    if ($FoldersRemoved.Count -gt 0) {
        $Result.ProfileFolder = "Deleted: $($FoldersRemoved -join ', ')"
    } elseif ($FolderErrors.Count -gt 0) {
        $Result.ProfileFolder = "Errors: $($FolderErrors -join ', ')"
    }

    return $Result
}

foreach ($TSHost in $TSHosts) {
    Write-Host "`n    [$TSHost]" -ForegroundColor Cyan
    try {
        $R = Invoke-Command -ComputerName $TSHost -ScriptBlock $CleanupBlock `
                -ArgumentList $UserSID, $Username -ErrorAction Stop

        Write-Host "      Registry (SID):       $($R.RegistryMain)"
        Write-Host "      Registry (SID.bak):   $($R.RegistryBAK)"
        Write-Host "      C:\Users\${Username}: $($R.ProfileFolder)"

        foreach ($Err in $R.Errors) {
            Write-Warn "      $Err"
        }
    } catch {
        Write-Fail "Remote cleanup failed on ${TSHost}: $_"
    }
}

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "[+] Profile reset complete for '$Username'." -ForegroundColor Green
Write-Host "    A fresh profile and UPD will be created on next login." -ForegroundColor Green
if (Test-Path $VHDXOldPath) {
    Write-Host "    Old VHDX retained at: $VHDXOldPath" -ForegroundColor Green
}
Write-Host ""
exit 0

<#
## Assumptions Made
- WinRM is enabled and accessible on both TS hosts from the admin workstation
- Admin workstation has the ActiveDirectory RSAT module installed
- The account running the script has admin rights on both TS hosts and
  read/write access to \\WPS-inap-fs01w\TS_User_Profiles\Profiles
- UPD file naming follows the standard UVHD-<SID>.vhdx convention
- The share name parsed from $UPDShare matches the actual SMB share name on the
  file server exactly (case-sensitive for Get-SmbShare -Name)

## Known Risks / Edge Cases Not Handled
- If logoff triggers profile save activity that takes longer than
  $SessionKillWaitSeconds, the VHDX may still be mounted when the script
  reaches Step 4. Both mountvol and CIM detection will catch this and abort
  safely. Increase $SessionKillWaitSeconds if users have large or slow profiles.
- Remove-Item / rd on C:\Users\<username> can still fail if the OS (antivirus,
  Windows Search, etc.) holds a handle on a file. A TS host reboot clears this.
- Rename-Item will fail if the UPD share is on a DFS path with certain
  configurations. In that case, use Copy-Item + Remove-Item manually.
- If both mountvol and CIM detection return false but the file is still locked,
  check for orphaned RDS session handles using Process Explorer on the TS host.
  A reboot of the affected TS host will clear any remaining locks.

## Suggested Follow-up
- After first use, confirm the user receives a fresh profile on next login
- Clean up any accumulated -old VHDX files periodically from the UPD share
- Consider bumping $SessionKillWaitSeconds to 30 if you see dismount issues
#>
