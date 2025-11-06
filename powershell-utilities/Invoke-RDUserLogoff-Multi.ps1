<#
.SYNOPSIS
    Logs off multiple Remote Desktop sessions across multiple terminal servers
    
.DESCRIPTION
    This script logs off specified Remote Desktop session IDs across multiple terminal servers
    in the Wilbert Inc. environment. It includes error handling and colored console feedback
    to track success and failures.
    
.PARAMETER Servers
    Array of terminal server hostnames to process
    Default: wps-inap-ts02w, wps-inap-ts03w, wps-inap-tes05w
    
.PARAMETER SessionIDs
    Array of session IDs to log off from each server
    
.EXAMPLE
    .\Invoke-RDUserLogoff-Multi.ps1
    Logs off sessions 1715-1718 from all three default terminal servers
    
.EXAMPLE
    $Servers = @("wps-inap-ts02w.wilbertinc.prv")
    $SessionIDs = @(1715, 1716)
    .\Invoke-RDUserLogoff-Multi.ps1 -Servers $Servers -SessionIDs $SessionIDs
    Logs off only sessions 1715 and 1716 from ts02w server
    
.NOTES
    File Name      : Invoke-RDUserLogoff-Multi.ps1
    Author         : Bryan Faulkner, with assistance from Claude
    Prerequisite   : Remote Desktop Services PowerShell module
    Version        : 1.0.0
    
    Version History:
    1.0.0 - 2025-11-03 - Initial creation
        - Multiple server support
        - Error handling with try/catch
        - Colored console output
        - Force logoff capability
        
.LINK
    https://github.com/ShadowA2J/it-automation-tools
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string[]]$Servers = @(
        "wps-inap-ts02w.wilbertinc.prv",
        "wps-inap-ts03w.wilbertinc.prv",
        "wps-inap-tes05w.wilbertinc.prv"
    ),
    
    [Parameter(Mandatory=$true)]
    [int[]]$SessionIDs
)

Write-Host "`n=== Remote Desktop Session Logoff Tool ===" -ForegroundColor Cyan
Write-Host "Starting logoff process for $($SessionIDs.Count) session(s) across $($Servers.Count) server(s)`n" -ForegroundColor Cyan

foreach ($Server in $Servers) {
    Write-Host "Processing server: $Server" -ForegroundColor Cyan
    
    foreach ($SessionID in $SessionIDs) {
        try {
            Invoke-RDUserLogoff -HostServer $Server -UnifiedSessionID $SessionID -Force
            Write-Host "  ✓ Successfully logged off session $SessionID" -ForegroundColor Green
        }
        catch {
            Write-Host "  ✗ Failed to log off session $SessionID - $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    Write-Host ""
}

Write-Host "Logoff process complete!" -ForegroundColor Cyan
Write-Host "===========================================`n" -ForegroundColor Cyan
