<#
.SYNOPSIS
    Triggers a Rewst webhook manually.

.DESCRIPTION
    Calls the specified Rewst webhook endpoint via POST request.
    Designed to run in Terminal Services under user context.

.NOTES
    Author: Bryan Faulkner
    Company: Quality Computer Solutions
    Created: 2026-02-02
#>

# Webhook URL
$webhookUrl = "https://engine.rewst.io/webhooks/custom/trigger/019c1e7f-ac3f-75b7-9ce1-7c4975177cff/019889ac-540c-7327-9dac-2a222afec0dc"

try {
    Write-Host "Calling Rewst webhook..." -ForegroundColor Cyan
    
    # Make the POST request
    $response = Invoke-RestMethod -Uri $webhookUrl -Method Post -ErrorAction Stop
    
    Write-Host "✓ Webhook triggered successfully!" -ForegroundColor Green
    
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
