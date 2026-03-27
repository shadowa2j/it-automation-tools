<#
.SYNOPSIS
    Cleans up CapabilityAccessManager SQLite WAL bloat.

.DESCRIPTION
    Stops the CapabilityAccessManager service using sc.exe (compatible with SYSTEM
    context), deletes the database and associated WAL/SHM files, then restarts the
    service. Windows rebuilds the database on next start/access.
    Intended to be run as a NinjaRMM script under the SYSTEM account.

.NOTES
    Safe to run without significant user impact.
    App privacy permission toggles (camera, mic, location, etc.) may reset to defaults.
    Only the three CapabilityAccessManager db/wal/shm files are deleted -- nothing else.
#>

[CmdletBinding()]
param()

$dbPath    = "C:\ProgramData\Microsoft\Windows\CapabilityAccessManager"
$targetFiles = @(
    "CapabilityAccessManager.db",
    "CapabilityAccessManager.db-wal",
    "CapabilityAccessManager.db-shm"
)
$serviceName = "camsvc"
$exitCode    = 0

function Write-Log {
    param([string]$Message)
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
}

function Get-FolderSizeMB {
    $size = (Get-ChildItem $dbPath -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
    if ($null -eq $size) { return 0 }
    return [math]::Round($size / 1MB, 2)
}

Write-Log "=== CapabilityAccessManager Cleanup Start ==="
Write-Log "Target path: $dbPath"
Write-Log "Size before cleanup: $(Get-FolderSizeMB) MB"

# -- Check if service exists --
$svc = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
if ($null -eq $svc) {
    Write-Log "WARNING: Service '$serviceName' not found on this machine. Files will still be cleaned up if present."
} else {
    Write-Log "Service '$serviceName' found. Current status: $($svc.Status)"

    # -- Stop service via sc.exe (works reliably under SYSTEM) --
    Write-Log "Stopping service '$serviceName'..."
    $scStop = & sc.exe stop $serviceName 2>&1
    Write-Log "sc.exe stop output: $scStop"

    # -- Wait for service to reach Stopped state --
    $timeout = 30
    $elapsed = 0
    $stopped = $false
    while ($elapsed -lt $timeout) {
        $status = (Get-Service -Name $serviceName -ErrorAction SilentlyContinue).Status
        if ($status -eq "Stopped") {
            $stopped = $true
            break
        }
        Write-Log "Waiting for service to stop... ($elapsed s elapsed, current status: $status)"
        Start-Sleep -Seconds 2
        $elapsed += 2
    }

    if (-not $stopped) {
        Write-Log "ERROR: Service '$serviceName' did not stop within $timeout seconds. Aborting."
        exit 1
    }

    Write-Log "Service stopped successfully."
}

# -- Delete target files --
Write-Log "Beginning file deletion..."
foreach ($file in $targetFiles) {
    $fullPath = Join-Path $dbPath $file
    if (-not (Test-Path $fullPath)) {
        Write-Log "Not found (skipping): $file"
        continue
    }

    # Retry loop to handle brief post-stop file locks
    $deleted  = $false
    $attempts = 3
    for ($i = 1; $i -le $attempts; $i++) {
        try {
            Remove-Item $fullPath -Force -ErrorAction Stop
            Write-Log "Deleted ($i attempt(s)): $file"
            $deleted = $true
            break
        } catch {
            Write-Log "Attempt $i failed to delete $file - $_"
            if ($i -lt $attempts) { Start-Sleep -Seconds 2 }
        }
    }

    if (-not $deleted) {
        Write-Log "ERROR: Could not delete $file after $attempts attempts. Aborting."
        exit 1
    }
}

# -- Restart service if it exists --
if ($null -ne (Get-Service -Name $serviceName -ErrorAction SilentlyContinue)) {
    Write-Log "Starting service '$serviceName'..."
    $scStart = & sc.exe start $serviceName 2>&1
    Write-Log "sc.exe start output: $scStart"

    # Brief wait then confirm it came up
    Start-Sleep -Seconds 5
    $newStatus = (Get-Service -Name $serviceName -ErrorAction SilentlyContinue).Status
    Write-Log "Service status after start: $newStatus"

    if ($newStatus -notin @("Running", "StartPending")) {
        Write-Log "WARNING: Service may not have started cleanly. Status: $newStatus"
        $exitCode = 1
    }
} else {
    Write-Log "Service not present -- skipping restart."
}

# -- Verify DB rebuild --
Start-Sleep -Seconds 3
$dbFile = Join-Path $dbPath "CapabilityAccessManager.db"
if (Test-Path $dbFile) {
    Write-Log "Database file detected -- rebuilt successfully."
} else {
    Write-Log "NOTE: Database file not yet present. Windows will rebuild it on first access."
}

Write-Log "Size after cleanup: $(Get-FolderSizeMB) MB"
Write-Log "=== CapabilityAccessManager Cleanup Complete ==="

exit $exitCode
