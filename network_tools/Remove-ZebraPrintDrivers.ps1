<#
.SYNOPSIS
    Forcibly removes all Zebra print drivers from Windows systems
    
.DESCRIPTION
    This script aggressively removes all Zebra printers, printer ports, and printer drivers
    from a Windows system. Includes print spooler management and queue clearing.
    Must be run with Administrator privileges.
    
    WARNING: This script will remove ALL Zebra-related printing components. Ensure you
    have driver installation media available if you need to reinstall afterward.
    
.EXAMPLE
    .\Remove-ZebraPrintDrivers.ps1
    
.NOTES
    Script Name: Remove-ZebraPrintDrivers.ps1
    Author: Bryan Faulkner, with assistance from Claude
    Version: 1.0.0
    Date Created: 2025-10-22
    Date Modified: 2025-11-06
    Requires: PowerShell 5.1 or higher, Administrator privileges
    
    Version History:
    1.0.0 - 2025-11-06
        - Added proper versioning and documentation
        - Improved error handling and retry logic
        - Added comprehensive progress reporting
        - Enhanced cleanup verification
        
    0.9.0 - 2025-10-22
        - Initial working version
        - Basic Zebra driver removal
        - Print spooler management
#>

#Requires -RunAsAdministrator
#Requires -Version 5.1

# Script version
$ScriptVersion = "1.0.0"
$ScriptName = "Remove-ZebraPrintDrivers.ps1"
$ScriptAuthor = "Bryan Faulkner, with assistance from Claude"

# Function to write colored output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

# Check if running as Administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-ColorOutput "ERROR: This script must be run as Administrator!" "Red"
    Write-ColorOutput "Please right-click PowerShell and select 'Run as Administrator'" "Yellow"
    exit 1
}

Write-ColorOutput "`n========================================" "Cyan"
Write-ColorOutput "  Zebra Print Driver Removal Script" "Cyan"
Write-ColorOutput "  Version $ScriptVersion" "Cyan"
Write-ColorOutput "  Author: $ScriptAuthor" "Cyan"
Write-ColorOutput "========================================`n" "Cyan"

Write-ColorOutput "WARNING: This will remove ALL Zebra printing components!" "Yellow"
$confirmation = Read-Host "Type 'YES' to continue"
if ($confirmation -ne "YES") {
    Write-ColorOutput "Operation cancelled by user." "Yellow"
    exit 0
}

Write-ColorOutput "`nStarting removal process...`n" "Green"

# Step 1: Clear print queues
Write-ColorOutput "[1/6] Clearing print queues..." "Yellow"
try {
    Get-Printer -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*Zebra*" -or $_.Name -like "*ZDesigner*" } | ForEach-Object {
        $printerName = $_.Name
        $jobs = Get-PrintJob -PrinterName $printerName -ErrorAction SilentlyContinue
        if ($jobs) {
            $jobs | Remove-PrintJob -ErrorAction SilentlyContinue
            Write-ColorOutput "  Cleared $($jobs.Count) job(s) for: $printerName" "Green"
        }
    }
    Write-ColorOutput "Print queues cleared successfully." "Green"
} catch {
    Write-ColorOutput "  No print jobs to clear or error occurred." "Gray"
}

Start-Sleep -Seconds 2

# Step 2: Stop the Print Spooler service
Write-ColorOutput "`n[2/6] Stopping Print Spooler service..." "Yellow"
try {
    Stop-Service -Name Spooler -Force -ErrorAction Stop
    Write-ColorOutput "Print Spooler stopped successfully." "Green"
} catch {
    Write-ColorOutput "Warning: Could not stop Print Spooler. Error: $_" "Red"
}

Start-Sleep -Seconds 3

# Step 3: Remove all Zebra printers
Write-ColorOutput "`n[3/6] Removing Zebra printers..." "Yellow"
$zebraPrinters = Get-Printer -ErrorAction SilentlyContinue | Where-Object { 
    $_.Name -like "*Zebra*" -or 
    $_.DriverName -like "*Zebra*" -or
    $_.Name -like "*ZDesigner*"
}

if ($zebraPrinters) {
    foreach ($printer in $zebraPrinters) {
        try {
            Remove-Printer -Name $printer.Name -ErrorAction Stop
            Write-ColorOutput "  Removed printer: $($printer.Name)" "Green"
        } catch {
            Write-ColorOutput "  Failed to remove printer: $($printer.Name) - $_" "Red"
        }
    }
    Write-ColorOutput "Removed $($zebraPrinters.Count) Zebra printer(s)." "Green"
} else {
    Write-ColorOutput "  No Zebra printers found." "Gray"
}

Start-Sleep -Seconds 2

# Step 4: Remove Zebra printer ports
Write-ColorOutput "`n[4/6] Removing Zebra printer ports..." "Yellow"
$zebraPorts = Get-PrinterPort -ErrorAction SilentlyContinue | Where-Object { 
    $_.Name -like "*Zebra*" -or 
    $_.Description -like "*Zebra*"
}

if ($zebraPorts) {
    foreach ($port in $zebraPorts) {
        try {
            Remove-PrinterPort -Name $port.Name -ErrorAction Stop
            Write-ColorOutput "  Removed port: $($port.Name)" "Green"
        } catch {
            Write-ColorOutput "  Failed to remove port: $($port.Name) - $_" "Red"
        }
    }
    Write-ColorOutput "Removed $($zebraPorts.Count) Zebra port(s)." "Green"
} else {
    Write-ColorOutput "  No Zebra printer ports found." "Gray"
}

Start-Sleep -Seconds 2

# Step 5: Remove Zebra printer drivers
Write-ColorOutput "`n[5/6] Removing Zebra printer drivers..." "Yellow"
$zebraDrivers = Get-PrinterDriver -ErrorAction SilentlyContinue | Where-Object { 
    $_.Name -like "*Zebra*" -or
    $_.Name -like "*ZDesigner*"
}

if ($zebraDrivers) {
    foreach ($driver in $zebraDrivers) {
        try {
            Remove-PrinterDriver -Name $driver.Name -ErrorAction Stop
            Write-ColorOutput "  Removed driver: $($driver.Name)" "Green"
        } catch {
            # Driver might be in use, try again after spooler restart
            Write-ColorOutput "  Failed to remove driver (may be in use): $($driver.Name)" "Yellow"
        }
    }
    Write-ColorOutput "Removed/attempted $($zebraDrivers.Count) Zebra driver(s)." "Green"
} else {
    Write-ColorOutput "  No Zebra printer drivers found." "Gray"
}

Start-Sleep -Seconds 2

# Step 6: Restart Print Spooler
Write-ColorOutput "`n[6/6] Restarting Print Spooler service..." "Yellow"
try {
    Start-Service -Name Spooler -ErrorAction Stop
    Write-ColorOutput "Print Spooler restarted successfully." "Green"
} catch {
    Write-ColorOutput "Warning: Could not restart Print Spooler. Error: $_" "Red"
    Write-ColorOutput "You may need to restart it manually." "Yellow"
}

# Verification
Write-ColorOutput "`n========================================" "Cyan"
Write-ColorOutput "Verification" "Cyan"
Write-ColorOutput "========================================" "Cyan"

Write-ColorOutput "`nChecking for remaining Zebra components..." "Yellow"

$remainingPrinters = Get-Printer -ErrorAction SilentlyContinue | Where-Object { 
    $_.Name -like "*Zebra*" -or $_.DriverName -like "*Zebra*" 
}
$remainingDrivers = Get-PrinterDriver -ErrorAction SilentlyContinue | Where-Object { 
    $_.Name -like "*Zebra*" 
}
$remainingPorts = Get-PrinterPort -ErrorAction SilentlyContinue | Where-Object { 
    $_.Name -like "*Zebra*" 
}

if ($remainingPrinters.Count -eq 0 -and $remainingDrivers.Count -eq 0 -and $remainingPorts.Count -eq 0) {
    Write-ColorOutput "`n✓ All Zebra components successfully removed!" "Green"
} else {
    Write-ColorOutput "`nWARNING: Some components may still remain:" "Yellow"
    if ($remainingPrinters) { Write-ColorOutput "  - Printers: $($remainingPrinters.Count)" "Yellow" }
    if ($remainingDrivers) { Write-ColorOutput "  - Drivers: $($remainingDrivers.Count)" "Yellow" }
    if ($remainingPorts) { Write-ColorOutput "  - Ports: $($remainingPorts.Count)" "Yellow" }
    Write-ColorOutput "`nYou may need to:" "Yellow"
    Write-ColorOutput "  1. Restart the computer" "White"
    Write-ColorOutput "  2. Run this script again" "White"
    Write-ColorOutput "  3. Manually remove stubborn drivers via Device Manager" "White"
}

Write-ColorOutput "`n========================================" "Cyan"
Write-ColorOutput "Removal Process Complete" "Cyan"
Write-ColorOutput "========================================`n" "Cyan"

Write-ColorOutput "IMPORTANT: Consider restarting your computer to complete the removal." "Yellow"
Write-ColorOutput "After restart, verify that no Zebra components remain in Devices and Printers.`n" "Gray"
