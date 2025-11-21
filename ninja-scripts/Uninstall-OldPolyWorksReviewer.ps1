<#
.SYNOPSIS
    Uninstalls all versions of PolyWorks Reviewer except the newest installed version.

.DESCRIPTION
    Queries the registry for all installed PolyWorks Reviewer versions, determines the newest
    by version number comparison, and uninstalls all older versions silently.

.NOTES
    Author: Quality Computer Solutions
    Version: 1.0
    Designed for deployment via NinjaRMM
#>

#Requires -RunAsAdministrator

# Define the product name pattern to match
$ProductNamePattern = "PolyWorks*Reviewer*"

# Registry paths to check (both 32-bit and 64-bit)
$RegistryPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

# Get all installed PolyWorks Reviewer versions
Write-Host "Searching for installed PolyWorks Reviewer versions..." -ForegroundColor Cyan

$InstalledVersions = @()

foreach ($Path in $RegistryPaths) {
    $Products = Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue | 
        Where-Object { $_.DisplayName -like $ProductNamePattern -and $_.Publisher -like "*InnovMetric*" }
    
    foreach ($Product in $Products) {
        # Parse version string into comparable version object
        $VersionString = $Product.DisplayVersion
        
        try {
            $VersionObj = [System.Version]$VersionString
        }
        catch {
            # If version string doesn't parse cleanly, try to extract numeric portions
            $VersionString -match '(\d+\.?\d*\.?\d*\.?\d*)' | Out-Null
            $VersionObj = [System.Version]$Matches[1]
        }
        
        $InstalledVersions += [PSCustomObject]@{
            DisplayName     = $Product.DisplayName
            DisplayVersion  = $Product.DisplayVersion
            VersionObj      = $VersionObj
            UninstallString = $Product.UninstallString
            QuietUninstall  = $Product.QuietUninstallString
            PSChildName     = $Product.PSChildName
            RegistryPath    = $Product.PSPath
        }
    }
}

# Remove duplicates (same product might appear in both registry paths)
$InstalledVersions = $InstalledVersions | Sort-Object DisplayName, DisplayVersion -Unique

if ($InstalledVersions.Count -eq 0) {
    Write-Host "No PolyWorks Reviewer installations found." -ForegroundColor Yellow
    exit 0
}

Write-Host "`nFound $($InstalledVersions.Count) PolyWorks Reviewer installation(s):" -ForegroundColor Green
$InstalledVersions | ForEach-Object {
    Write-Host "  - $($_.DisplayName) (v$($_.DisplayVersion))" -ForegroundColor White
}

if ($InstalledVersions.Count -eq 1) {
    Write-Host "`nOnly one version installed. Nothing to uninstall." -ForegroundColor Yellow
    exit 0
}

# Determine the newest version
$NewestVersion = $InstalledVersions | Sort-Object VersionObj -Descending | Select-Object -First 1

Write-Host "`nNewest version detected: $($NewestVersion.DisplayName) (v$($NewestVersion.DisplayVersion))" -ForegroundColor Green
Write-Host "This version will be KEPT.`n" -ForegroundColor Green

# Get versions to uninstall
$VersionsToRemove = $InstalledVersions | Where-Object { $_.DisplayVersion -ne $NewestVersion.DisplayVersion }

if ($VersionsToRemove.Count -eq 0) {
    Write-Host "No older versions to remove." -ForegroundColor Yellow
    exit 0
}

Write-Host "Versions to UNINSTALL:" -ForegroundColor Red
$VersionsToRemove | ForEach-Object {
    Write-Host "  - $($_.DisplayName) (v$($_.DisplayVersion))" -ForegroundColor Red
}

# Uninstall older versions
foreach ($Version in $VersionsToRemove) {
    Write-Host "`nUninstalling: $($Version.DisplayName)..." -ForegroundColor Yellow
    
    $UninstallCommand = $null
    $Arguments = $null
    
    # Determine uninstall method
    if ($Version.QuietUninstall) {
        # Use quiet uninstall string if available
        Write-Host "  Using QuietUninstallString" -ForegroundColor Gray
        $UninstallCommand = $Version.QuietUninstall
    }
    elseif ($Version.UninstallString) {
        $UninstallStr = $Version.UninstallString
        
        if ($UninstallStr -match 'msiexec') {
            # MSI-based uninstall
            if ($UninstallStr -match '\{[A-F0-9-]+\}') {
                $ProductGuid = $Matches[0]
                Write-Host "  Using MSI uninstall with GUID: $ProductGuid" -ForegroundColor Gray
                $UninstallCommand = "msiexec.exe"
                $Arguments = "/x $ProductGuid /qn /norestart"
            }
            else {
                # MsiExec without GUID in string, use PSChildName as GUID
                Write-Host "  Using MSI uninstall with registry key GUID" -ForegroundColor Gray
                $UninstallCommand = "msiexec.exe"
                $Arguments = "/x $($Version.PSChildName) /qn /norestart"
            }
        }
        else {
            # EXE-based uninstall - try common silent switches
            Write-Host "  Using EXE uninstall with silent switches" -ForegroundColor Gray
            
            # Extract the executable path (handle quoted paths)
            if ($UninstallStr -match '^"([^"]+)"(.*)$') {
                $UninstallCommand = $Matches[1]
                $ExistingArgs = $Matches[2].Trim()
            }
            elseif ($UninstallStr -match '^(\S+)(.*)$') {
                $UninstallCommand = $Matches[1]
                $ExistingArgs = $Matches[2].Trim()
            }
            
            # Add silent switches
            $Arguments = "$ExistingArgs /S /silent /verysilent /qn /norestart".Trim()
        }
    }
    else {
        Write-Host "  ERROR: No uninstall string found for this product!" -ForegroundColor Red
        continue
    }
    
    # Execute uninstall
    try {
        if ($Arguments) {
            Write-Host "  Executing: $UninstallCommand $Arguments" -ForegroundColor Gray
            $Process = Start-Process -FilePath $UninstallCommand -ArgumentList $Arguments -Wait -PassThru -NoNewWindow -ErrorAction Stop
        }
        else {
            Write-Host "  Executing: $UninstallCommand" -ForegroundColor Gray
            $Process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$UninstallCommand`"" -Wait -PassThru -NoNewWindow -ErrorAction Stop
        }
        
        if ($Process.ExitCode -eq 0 -or $Process.ExitCode -eq 3010) {
            Write-Host "  SUCCESS: Uninstall completed (Exit Code: $($Process.ExitCode))" -ForegroundColor Green
            if ($Process.ExitCode -eq 3010) {
                Write-Host "  NOTE: A reboot is required to complete the uninstall." -ForegroundColor Yellow
            }
        }
        else {
            Write-Host "  WARNING: Uninstall returned exit code $($Process.ExitCode)" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "  ERROR: Failed to execute uninstall - $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Script completed." -ForegroundColor Cyan
Write-Host "Kept: $($NewestVersion.DisplayName) (v$($NewestVersion.DisplayVersion))" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

exit 0
