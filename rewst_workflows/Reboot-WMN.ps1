<#
.SYNOPSIS
    Triggers a Rewst webhook to reboot WMN device.

.DESCRIPTION
    Calls the specified Rewst webhook endpoint to reboot WMN (Device ID: 3328).
    Designed to run in Terminal Services under user context.

.NOTES
    Author: Bryan Faulkner
    Company: Quality Computer Solutions
    Device: WMN (3328)
    Created: 2026-02-02
#>

# Webhook URL
$webhookUrl = "https://engine.rewst.io/webhooks/custom/trigger/019c1e7f-ac3f-75b7-9ce1-7c4975177cff/019889ac-540c-7327-9dac-2a222afec0dc"

# WMN Device ID
$deviceId = 3328

# Prepare the payload
$payload = @{
    device_id = $deviceId
} | ConvertTo-Json

try {
    Write-Host "Calling Rewst webhook to reboot WMN (Device ID: $deviceId)..." -ForegroundColor Cyan
    
    # Make the POST request with JSON payload
    $response = Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $payload -ContentType "application/json" -ErrorAction Stop
    
    Write-Host "✓ Webhook triggered successfully!" -ForegroundColor Green
    Write-Host "  WMN reboot initiated." -ForegroundColor Green
    
    # Display response if there is one
    if ($response) {
        Write-Host "`nResponse:" -ForegroundColor Yellow
        $response | ConvertTo-Json -Depth 5
    }
    
} catch {
    Write-Host "✗ Error calling webhook:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    
    if ($_.Exception.Response) {
        Write-Host "`nStatus Code:" $_.Exception.Response.StatusCode.value__ -ForegroundColor Red
    }
}
