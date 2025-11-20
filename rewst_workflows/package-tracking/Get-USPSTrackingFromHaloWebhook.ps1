#ps
# USPS Tracking Scraper for Rewst/Halo Integration
# This script runs in Rewst's PowerShell Interpreter
# Uses USPS internal tracking API endpoint

# Get webhook data from Rewst context
$webhookData = $CTX.body

# Extract ticket information - ticket data is nested under body.ticket
$ticketId = $webhookData.ticket.id
$ticketSummary = $webhookData.ticket.summary

# Find the tracking number in custom fields by ID (398 = CFUMOSRewstTrackingNumber)
$trackingNumber = $null
foreach ($field in $webhookData.ticket.customfields) {
    if ($field.id -eq 398) {
        $trackingNumber = $field.value
        break
    }
}

# Initialize result object
$result = @{
    ticket_id = $ticketId
    tracking_number = $trackingNumber
    status = $null
    status_category = $null
    delivery_date = $null
    location = $null
    last_update = $null
    is_delivered = $false
    is_in_transit = $false
    is_out_for_delivery = $false
    success = $false
    error_message = $null
    checked_at = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
}

# Check if tracking number was found
if (-not $trackingNumber -or [string]::IsNullOrWhiteSpace($trackingNumber)) {
    $result.error_message = "Tracking number not found or empty"
    $result | ConvertTo-Json -Depth 10 -Compress
}
else {
    # Try USPS REST tracking endpoint
    $url = "https://tools.usps.com/go/TrackConfirmAction!execute.action?tLabels=$trackingNumber"
    
    try {
        $headers = @{
            'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
            'Accept' = 'application/json, text/javascript, */*; q=0.01'
            'Accept-Language' = 'en-US,en;q=0.5'
            'X-Requested-With' = 'XMLHttpRequest'
            'Referer' = 'https://tools.usps.com/go/TrackConfirmAction'
        }
        
        $response = Invoke-WebRequest -Uri $url -Headers $headers -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop
        $content = $response.Content
        
        # Try to parse as JSON first
        try {
            $jsonData = $content | ConvertFrom-Json
            
            # Check if we got tracking data
            if ($jsonData.resultsList -and $jsonData.resultsList.Count -gt 0) {
                $trackingData = $jsonData.resultsList[0]
                
                $result.status = $trackingData.statusSummary
                $result.location = $trackingData.eventCity + ", " + $trackingData.eventState + " " + $trackingData.eventZip
                $result.last_update = $trackingData.eventDate + " " + $trackingData.eventTime
                
                # Categorize status
                if ($result.status -match 'Delivered') {
                    $result.status_category = 'Delivered'
                    $result.is_delivered = $true
                }
                elseif ($result.status -match 'Out for Delivery') {
                    $result.status_category = 'Out for Delivery'
                    $result.is_out_for_delivery = $true
                }
                elseif ($result.status -match 'In Transit|Arrived|Departed|Processed|Accepted') {
                    $result.status_category = 'In Transit'
                    $result.is_in_transit = $true
                }
                elseif ($result.status -match 'Pre-Shipment|Label Created') {
                    $result.status_category = 'Pre-Shipment'
                }
                else {
                    $result.status_category = 'Unknown'
                }
                
                $result.success = $true
            }
            else {
                $result.error_message = "No tracking results found in JSON response"
            }
        }
        catch {
            # Not JSON, check if it's HTML with embedded data
            if ($content -match '"statusSummary"\s*:\s*"([^"]+)"') {
                $result.status = $matches[1]
                $result.success = $true
                
                # Try to get more fields
                if ($content -match '"eventCity"\s*:\s*"([^"]+)"') {
                    $city = $matches[1]
                    if ($content -match '"eventState"\s*:\s*"([^"]+)"') {
                        $state = $matches[1]
                        $result.location = "$city, $state"
                    }
                }
                
                if ($content -match '"eventDate"\s*:\s*"([^"]+)"') {
                    $result.last_update = $matches[1]
                }
                
                # Categorize
                if ($result.status -match 'Delivered') {
                    $result.status_category = 'Delivered'
                    $result.is_delivered = $true
                }
                elseif ($result.status -match 'Out for Delivery') {
                    $result.status_category = 'Out for Delivery'
                    $result.is_out_for_delivery = $true
                }
                elseif ($result.status -match 'In Transit|Arrived|Departed') {
                    $result.status_category = 'In Transit'
                    $result.is_in_transit = $true
                }
                else {
                    $result.status_category = 'Unknown'
                }
            }
            else {
                # Return snippet for debugging
                $snippet = $content.Substring(0, [Math]::Min(1000, $content.Length))
                $result.error_message = "Could not parse response. Preview: $snippet"
            }
        }
    }
    catch {
        $result.error_message = $_.Exception.Message
        $result.status_category = 'Error'
    }
    
    # Return result as JSON
    $result | ConvertTo-Json -Depth 10 -Compress
}
