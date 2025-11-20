#ps
# USPS Tracking Scraper for Rewst/Halo Integration
# This script runs in Rewst's PowerShell Interpreter
# CTX.body contains the Halo webhook JSON

$TrackingFieldName = "CFUMOSRewstTrackingNumber"

# Get webhook data from Rewst context
$webhookData = $CTX.body

# Extract ticket information - ticket data is nested under body.ticket
$ticketId = $webhookData.ticket.id
$ticketSummary = $webhookData.ticket.summary

# Find the tracking number in custom fields - customfields is under ticket, not root
$trackingNumber = $null
foreach ($field in $webhookData.ticket.customfields) {
    if ($field.name -eq $TrackingFieldName) {
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
    $result.error_message = "Tracking number not found or empty in custom field '$TrackingFieldName'"
    $result | ConvertTo-Json -Depth 10 -Compress
}
else {
    # Build URL and fetch tracking info
    $url = "https://tools.usps.com/go/TrackConfirmAction?tLabels=$trackingNumber"
    
    try {
        $headers = @{
            'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
            'Accept' = 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
            'Accept-Language' = 'en-US,en;q=0.5'
        }
        
        $response = Invoke-WebRequest -Uri $url -Headers $headers -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop
        $html = $response.Content
        
        # Status extraction - try multiple approaches
        $statusFound = $false
        
        # Approach 1: Look for main status text in headers
        if ($html -match '<h[12][^>]*>([^<]*(?:Delivered|In Transit|Out for Delivery|Pre-Shipment|Acceptance|Arrived|Departed)[^<]*)</h[12]>') {
            $result.status = $matches[1].Trim() -replace '\s+', ' '
            $statusFound = $true
        }
        
        # Approach 2: Look for status in common div classes
        if (-not $statusFound -and $html -match '<div[^>]*class="[^"]*(?:tracking-summary|delivery-status|status-category)[^"]*"[^>]*>\s*([^<]+)') {
            $result.status = $matches[1].Trim() -replace '\s+', ' '
            $statusFound = $true
        }
        
        # Approach 3: Search for status keywords anywhere
        if (-not $statusFound) {
            $statusKeywords = @('Delivered', 'In Transit', 'Out for Delivery', 'Accepted', 'Arrived at', 'Departed', 'Pre-Shipment')
            foreach ($keyword in $statusKeywords) {
                if ($html -match "$keyword[^<]{0,100}" -and $result.status -eq $null) {
                    $result.status = ($matches[0] -replace '<[^>]+>', '' -replace '\s+', ' ').Trim()
                    $statusFound = $true
                    break
                }
            }
        }
        
        # Categorize status
        if ($result.status) {
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
            elseif ($result.status -match 'Pre-Shipment|Accepted') {
                $result.status_category = 'Pre-Shipment'
            }
            else {
                $result.status_category = 'Unknown'
            }
            $result.success = $true
        }
        else {
            $result.error_message = "Could not parse tracking status from page"
        }
        
        # Extract delivery date
        if ($html -match '(?:Expected|Estimated)?\s*Delivery[^:]*:?\s*<?[^>]*>?\s*([A-Za-z]+\s+\d{1,2},?\s+\d{4})') {
            $result.delivery_date = $matches[1].Trim()
        }
        elseif ($html -match 'Delivered[^,]*,?\s*([A-Za-z]+\s+\d{1,2},?\s+\d{4})') {
            $result.delivery_date = $matches[1].Trim()
        }
        
        # Extract location
        if ($html -match '([A-Z][A-Z\s]+,\s*[A-Z]{2}\s+\d{5})') {
            $result.location = $matches[1].Trim()
        }
        
        # Extract timestamp
        if ($html -match '([A-Za-z]+\s+\d{1,2},?\s+\d{4}(?:,?\s+\d{1,2}:\d{2}\s*(?:am|pm|AM|PM))?)') {
            $result.last_update = $matches[1].Trim()
        }
        
    }
    catch {
        $result.error_message = $_.Exception.Message
        $result.status_category = 'Error'
    }
    
    # Return result as JSON - this is the ONLY output
    $result | ConvertTo-Json -Depth 10 -Compress
}
