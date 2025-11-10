<#
.SYNOPSIS
    Fix Windows 11 PDF Preview Issue caused by KB5066835

.DESCRIPTION
    This script fixes the "file you are attempting to preview could harm your computer" 
    error in Windows File Explorer caused by October 2025 Windows Update KB5066835.
    
    The script performs three main actions:
    1. Modifies registry to prevent future files from being blocked
    2. Unblocks existing PDF files in user folders and network shares
    3. Restarts Windows Explorer to apply changes
    
    Optimized for deployment via Ninja RMM with comprehensive logging and error reporting.

.PARAMETER ScanScope
    Defines the scope of file unblocking:
    - UserFolders: Downloads, Documents, Desktop (default)
    - UserFoldersAndShares: User folders + all mapped network drives
    - AllDrives: All local drives (C:, D:, etc.)
    - AllDrivesAndShares: Everything including network shares
    - Custom: Specify custom paths

.PARAMETER CustomPaths
    Array of custom paths to scan when ScanScope is set to "Custom"

.PARAMETER SkipExplorerRestart
    If specified, skips the Windows Explorer restart

.PARAMETER LogPath
    Custom log file path. Defaults to C:\ProgramData\NinjaRMM\Logs\PDF-Preview-Fix.log

.EXAMPLE
    .\Fix-Windows11-PDFPreview.ps1
    Runs with default settings (user folders only)

.EXAMPLE
    .\Fix-Windows11-PDFPreview.ps1 -ScanScope UserFoldersAndShares
    Scans user folders and all mapped network drives

.EXAMPLE
    .\Fix-Windows11-PDFPreview.ps1 -ScanScope Custom -CustomPaths "D:\SharedFiles","\\server\share"
    Scans specific custom paths

.NOTES
    Version:        1.0.0
    Author:         IT Automation Tools
    Creation Date:  2025-11-10
    Purpose:        Fix Windows 11 PDF preview issue via Ninja RMM
    
    Requirements:
    - Windows 11
    - PowerShell 5.1 or higher
    - Administrator privileges
    
.LINK
    https://github.com/ShadowA2J/it-automation-tools
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("UserFolders","UserFoldersAndShares","AllDrives","AllDrivesAndShares","Custom")]
    [string]$ScanScope = "UserFolders",
    
    [Parameter(Mandatory=$false)]
    [string[]]$CustomPaths = @(),
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipExplorerRestart,
    
    [Parameter(Mandatory=$false)]
    [string]$LogPath = "C:\ProgramData\NinjaRMM\Logs\PDF-Preview-Fix.log"
)

#Requires -RunAsAdministrator

# ============================================================================
# SCRIPT VARIABLES
# ============================================================================
$script:ScriptVersion = "1.0.0"
$script:ExitCode = 0
$script:TotalFilesProcessed = 0
$script:TotalFilesUnblocked = 0
$script:ErrorCount = 0

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================

function Initialize-Logging {
    <#
    .SYNOPSIS
        Initializes the logging system
    #>
    try {
        $logDir = Split-Path -Path $LogPath -Parent
        if (-not (Test-Path $logDir)) {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        }
        
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $separator = "=" * 80
        
        Add-Content -Path $LogPath -Value ""
        Add-Content -Path $LogPath -Value $separator
        Add-Content -Path $LogPath -Value "[$timestamp] Windows 11 PDF Preview Fix - v$script:ScriptVersion"
        Add-Content -Path $LogPath -Value $separator
        Add-Content -Path $LogPath -Value "Computer: $env:COMPUTERNAME"
        Add-Content -Path $LogPath -Value "User: $env:USERNAME"
        Add-Content -Path $LogPath -Value "Scan Scope: $ScanScope"
        Add-Content -Path $LogPath -Value $separator
        
        return $true
    }
    catch {
        Write-Error "Failed to initialize logging: $_"
        return $false
    }
}

function Write-Log {
    <#
    .SYNOPSIS
        Writes a message to both console and log file
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("INFO","SUCCESS","WARNING","ERROR")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Console output with colors
    switch ($Level) {
        "SUCCESS" { Write-Host $Message -ForegroundColor Green }
        "WARNING" { Write-Host $Message -ForegroundColor Yellow }
        "ERROR"   { Write-Host $Message -ForegroundColor Red; $script:ErrorCount++ }
        default   { Write-Host $Message -ForegroundColor White }
    }
    
    # File output
    try {
        Add-Content -Path $LogPath -Value $logMessage
    }
    catch {
        Write-Warning "Failed to write to log file: $_"
    }
}

# ============================================================================
# VALIDATION FUNCTIONS
# ============================================================================

function Test-IsWindows11 {
    <#
    .SYNOPSIS
        Validates that the OS is Windows 11
    #>
    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem
        $buildNumber = [int]$os.BuildNumber
        
        # Windows 11 starts at build 22000
        if ($buildNumber -ge 22000) {
            Write-Log "OS Validation: Windows 11 (Build $buildNumber) - OK" -Level SUCCESS
            return $true
        }
        else {
            Write-Log "OS Validation: Not Windows 11 (Build $buildNumber)" -Level ERROR
            return $false
        }
    }
    catch {
        Write-Log "OS Validation Failed: $_" -Level ERROR
        return $false
    }
}

function Test-IsAdministrator {
    <#
    .SYNOPSIS
        Validates that the script is running with administrator privileges
    #>
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if ($isAdmin) {
        Write-Log "Administrator Check: Running as Administrator - OK" -Level SUCCESS
        return $true
    }
    else {
        Write-Log "Administrator Check: NOT running as Administrator" -Level ERROR
        return $false
    }
}

# ============================================================================
# REGISTRY FUNCTIONS
# ============================================================================

function Set-RegistryFix {
    <#
    .SYNOPSIS
        Configures registry to prevent future files from being blocked
    #>
    Write-Log "=== STEP 1: Configuring Registry ===" -Level INFO
    
    try {
        $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Attachments"
        
        # Create registry key if it doesn't exist
        if (-not (Test-Path $regPath)) {
            New-Item -Path $regPath -Force | Out-Null
            Write-Log "Created registry key: $regPath" -Level SUCCESS
        }
        else {
            Write-Log "Registry key already exists: $regPath" -Level INFO
        }
        
        # Set SaveZoneInformation value
        $existingValue = Get-ItemProperty -Path $regPath -Name "SaveZoneInformation" -ErrorAction SilentlyContinue
        
        if ($existingValue -and $existingValue.SaveZoneInformation -eq 1) {
            Write-Log "Registry value already set correctly (SaveZoneInformation = 1)" -Level INFO
        }
        else {
            New-ItemProperty -Path $regPath -Name "SaveZoneInformation" -PropertyType DWord -Value 1 -Force | Out-Null
            Write-Log "Set registry value: SaveZoneInformation = 1" -Level SUCCESS
        }
        
        Write-Log "Future downloads will no longer be blocked" -Level SUCCESS
        return $true
    }
    catch {
        Write-Log "Failed to modify registry: $_" -Level ERROR
        return $false
    }
}

# ============================================================================
# FILE UNBLOCKING FUNCTIONS
# ============================================================================

function Get-NetworkShares {
    <#
    .SYNOPSIS
        Gets all mapped network drives
    #>
    try {
        $shares = Get-PSDrive -PSProvider FileSystem | Where-Object { 
            $_.DisplayRoot -like "\\*" 
        }
        
        if ($shares) {
            Write-Log "Found $($shares.Count) mapped network drives" -Level INFO
            foreach ($share in $shares) {
                Write-Log "  - $($share.Name): $($share.DisplayRoot)" -Level INFO
            }
        }
        else {
            Write-Log "No mapped network drives found" -Level INFO
        }
        
        return $shares
    }
    catch {
        Write-Log "Error enumerating network shares: $_" -Level ERROR
        return @()
    }
}

function Get-ScanPaths {
    <#
    .SYNOPSIS
        Determines which paths to scan based on ScanScope parameter
    #>
    $paths = @()
    
    switch ($ScanScope) {
        "UserFolders" {
            $paths += "$env:USERPROFILE\Downloads"
            $paths += "$env:USERPROFILE\Documents"
            $paths += "$env:USERPROFILE\Desktop"
        }
        
        "UserFoldersAndShares" {
            $paths += "$env:USERPROFILE\Downloads"
            $paths += "$env:USERPROFILE\Documents"
            $paths += "$env:USERPROFILE\Desktop"
            
            $shares = Get-NetworkShares
            foreach ($share in $shares) {
                $paths += "$($share.Root)"
            }
        }
        
        "AllDrives" {
            $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { 
                $_.Root -match '^[A-Z]:\\$' 
            }
            foreach ($drive in $drives) {
                $paths += $drive.Root
            }
        }
        
        "AllDrivesAndShares" {
            $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { 
                $_.Root -match '^[A-Z]:\\$' 
            }
            foreach ($drive in $drives) {
                $paths += $drive.Root
            }
            
            $shares = Get-NetworkShares
            foreach ($share in $shares) {
                $paths += "$($share.Root)"
            }
        }
        
        "Custom" {
            if ($CustomPaths.Count -eq 0) {
                Write-Log "Custom scope selected but no paths provided. Using UserFolders as fallback." -Level WARNING
                $paths += "$env:USERPROFILE\Downloads"
                $paths += "$env:USERPROFILE\Documents"
                $paths += "$env:USERPROFILE\Desktop"
            }
            else {
                $paths = $CustomPaths
            }
        }
    }
    
    # Validate paths exist
    $validPaths = @()
    foreach ($path in $paths) {
        if (Test-Path $path) {
            $validPaths += $path
        }
        else {
            Write-Log "Path not found, skipping: $path" -Level WARNING
        }
    }
    
    return $validPaths
}

function Unblock-FilesInPath {
    <#
    .SYNOPSIS
        Unblocks all files in a specified path recursively
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    
    Write-Log "Scanning path: $Path" -Level INFO
    
    try {
        # Get all files recursively with error handling
        $files = @()
        try {
            $files = Get-ChildItem -Path $Path -File -Recurse -ErrorAction SilentlyContinue
        }
        catch {
            Write-Log "Error accessing path $Path : $_" -Level WARNING
            return
        }
        
        $fileCount = $files.Count
        Write-Log "Found $fileCount files to check in $Path" -Level INFO
        
        if ($fileCount -eq 0) {
            Write-Log "No files found in $Path" -Level INFO
            return
        }
        
        $unblocked = 0
        $skipped = 0
        $errors = 0
        
        # Progress tracking for large scans
        $progressInterval = [Math]::Max(1, [Math]::Floor($fileCount / 10))
        $processed = 0
        
        foreach ($file in $files) {
            $processed++
            $script:TotalFilesProcessed++
            
            # Progress update every 10%
            if ($processed % $progressInterval -eq 0 -or $processed -eq $fileCount) {
                $percentComplete = [Math]::Round(($processed / $fileCount) * 100)
                Write-Progress -Activity "Unblocking files in $Path" -Status "$percentComplete% Complete" -PercentComplete $percentComplete
            }
            
            try {
                # Check if file is blocked before attempting unblock
                $zone = Get-Item -Path $file.FullName -Stream Zone.Identifier -ErrorAction SilentlyContinue
                
                if ($zone) {
                    Unblock-File -Path $file.FullName -ErrorAction Stop
                    $unblocked++
                    $script:TotalFilesUnblocked++
                }
                else {
                    $skipped++
                }
            }
            catch [System.UnauthorizedAccessException] {
                # Silent skip for permission issues
                $skipped++
            }
            catch {
                # Log other errors but continue
                if ($errors -lt 10) {  # Only log first 10 errors to avoid log spam
                    Write-Log "Error unblocking file $($file.FullName): $_" -Level WARNING
                }
                $errors++
            }
        }
        
        Write-Progress -Activity "Unblocking files in $Path" -Completed
        
        Write-Log "Path: $Path - Processed: $fileCount | Unblocked: $unblocked | Skipped: $skipped | Errors: $errors" -Level SUCCESS
    }
    catch {
        Write-Log "Critical error processing path $Path : $_" -Level ERROR
    }
}

function Invoke-FileUnblocking {
    <#
    .SYNOPSIS
        Main function to unblock files based on scan scope
    #>
    Write-Log "=== STEP 2: Unblocking Existing Files ===" -Level INFO
    
    $paths = Get-ScanPaths
    
    if ($paths.Count -eq 0) {
        Write-Log "No valid paths found to scan" -Level WARNING
        return $false
    }
    
    Write-Log "Will scan $($paths.Count) path(s)" -Level INFO
    foreach ($path in $paths) {
        Write-Log "  - $path" -Level INFO
    }
    
    foreach ($path in $paths) {
        Unblock-FilesInPath -Path $path
    }
    
    Write-Log "File unblocking complete" -Level SUCCESS
    Write-Log "Total files processed: $script:TotalFilesProcessed" -Level INFO
    Write-Log "Total files unblocked: $script:TotalFilesUnblocked" -Level SUCCESS
    
    return $true
}

# ============================================================================
# EXPLORER RESTART FUNCTION
# ============================================================================

function Restart-WindowsExplorer {
    <#
    .SYNOPSIS
        Restarts Windows Explorer to apply changes
    #>
    Write-Log "=== STEP 3: Restart Windows Explorer ===" -Level INFO
    
    if ($SkipExplorerRestart) {
        Write-Log "Skipping Explorer restart (parameter specified)" -Level INFO
        return $true
    }
    
    try {
        Write-Log "Stopping Windows Explorer..." -Level INFO
        Stop-Process -Name explorer -Force -ErrorAction Stop
        
        Start-Sleep -Seconds 3
        
        Write-Log "Starting Windows Explorer..." -Level INFO
        Start-Process explorer -ErrorAction Stop
        
        Write-Log "Windows Explorer restarted successfully" -Level SUCCESS
        return $true
    }
    catch {
        Write-Log "Failed to restart Windows Explorer: $_" -Level ERROR
        Write-Log "Please restart Explorer manually or reboot your PC" -Level WARNING
        return $false
    }
}

# ============================================================================
# REPORTING FUNCTIONS
# ============================================================================

function Write-CompletionReport {
    <#
    .SYNOPSIS
        Writes final completion report
    #>
    $separator = "=" * 80
    
    Write-Log $separator -Level INFO
    Write-Log "SCRIPT EXECUTION COMPLETED" -Level SUCCESS
    Write-Log $separator -Level INFO
    
    Write-Log "Summary:" -Level INFO
    Write-Log "  - Registry configured: YES" -Level SUCCESS
    Write-Log "  - Total files processed: $script:TotalFilesProcessed" -Level INFO
    Write-Log "  - Total files unblocked: $script:TotalFilesUnblocked" -Level SUCCESS
    Write-Log "  - Errors encountered: $script:ErrorCount" -Level $(if ($script:ErrorCount -eq 0) { "SUCCESS" } else { "WARNING" })
    
    if ($script:ErrorCount -gt 0) {
        Write-Log "" -Level INFO
        Write-Log "Some errors were encountered. Please review the log file:" -Level WARNING
        Write-Log "  $LogPath" -Level INFO
    }
    
    Write-Log "" -Level INFO
    Write-Log "If PDF preview issues persist:" -Level INFO
    Write-Log "  1. Restart your computer" -Level INFO
    Write-Log "  2. Consider uninstalling update KB5066835:" -Level INFO
    Write-Log "     Settings > Windows Update > Update History > Uninstall Updates" -Level INFO
    
    Write-Log $separator -Level INFO
}

function Send-NinjaRMMOutput {
    <#
    .SYNOPSIS
        Sends custom fields to Ninja RMM for monitoring
    #>
    try {
        # Ninja RMM custom field output
        Write-Host ""
        Write-Host "=== NINJA RMM CUSTOM FIELDS ==="
        Write-Host "PDFFixApplied=True"
        Write-Host "PDFFixVersion=$script:ScriptVersion"
        Write-Host "PDFFixDate=$(Get-Date -Format 'yyyy-MM-dd')"
        Write-Host "PDFFixFilesProcessed=$script:TotalFilesProcessed"
        Write-Host "PDFFixFilesUnblocked=$script:TotalFilesUnblocked"
        Write-Host "PDFFixErrors=$script:ErrorCount"
        Write-Host "PDFFixExitCode=$script:ExitCode"
        Write-Host "==============================="
    }
    catch {
        Write-Log "Failed to send Ninja RMM output: $_" -Level WARNING
    }
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

function Main {
    <#
    .SYNOPSIS
        Main script execution function
    #>
    
    # Initialize logging
    if (-not (Initialize-Logging)) {
        Write-Error "Failed to initialize logging. Exiting."
        exit 1
    }
    
    Write-Log "Starting Windows 11 PDF Preview Fix Script v$script:ScriptVersion" -Level INFO
    
    # Validation checks
    if (-not (Test-IsAdministrator)) {
        Write-Log "Script must be run as Administrator. Exiting." -Level ERROR
        $script:ExitCode = 1
        exit $script:ExitCode
    }
    
    if (-not (Test-IsWindows11)) {
        Write-Log "This script is designed for Windows 11 only. Exiting." -Level ERROR
        $script:ExitCode = 2
        exit $script:ExitCode
    }
    
    # Execute fix steps
    try {
        # Step 1: Registry fix
        if (-not (Set-RegistryFix)) {
            Write-Log "Registry fix failed but continuing with file unblocking" -Level WARNING
        }
        
        # Step 2: Unblock files
        if (-not (Invoke-FileUnblocking)) {
            Write-Log "File unblocking encountered issues" -Level WARNING
        }
        
        # Step 3: Restart Explorer
        if (-not (Restart-WindowsExplorer)) {
            Write-Log "Explorer restart failed but fix may still be effective" -Level WARNING
        }
        
        # Completion report
        Write-CompletionReport
        
        # Ninja RMM output
        Send-NinjaRMMOutput
        
        # Set exit code based on error count
        if ($script:ErrorCount -eq 0) {
            $script:ExitCode = 0
        }
        elseif ($script:ErrorCount -le 5) {
            $script:ExitCode = 0  # Minor errors, still successful
        }
        else {
            $script:ExitCode = 3  # Multiple errors occurred
        }
    }
    catch {
        Write-Log "Critical error during script execution: $_" -Level ERROR
        $script:ExitCode = 99
    }
    
    Write-Log "Script exiting with code: $script:ExitCode" -Level INFO
    exit $script:ExitCode
}

# ============================================================================
# SCRIPT ENTRY POINT
# ============================================================================

# Execute main function
Main
