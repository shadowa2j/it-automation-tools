<#
.SYNOPSIS
    USPS Tracking Scraper for Halo Webhook Integration
    
.DESCRIPTION
    Extracts tracking number from Halo webhook JSON (from Rewst CTX.body) and scrapes USPS tracking information.
    Returns structured JSON for Rewst to process and update back to Halo.
    
.PARAMETER TrackingFieldName
    Name of the custom field containing the tracking number (default: CFUMOSRewstTrackingNumber)
    
.EXAMPLE
    # In Rewst workflow - script automatically uses {{ CTX.body }}
    .\Get-USPSTrackingFromHaloWebhook.ps1
    
.NOTES
    Author: Bryan
    Version: 1.3
    Date: 2025-11-20
    
    IMPORTANT: 
    - This script is designed to run in Rewst workflows
    - It automatically reads the Halo webhook from {{ CTX.body }}
    - Scrapes public USPS website (not their API)
    - Returns JSON that Rewst can use to update Halo ticket
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$TrackingFieldName = "CFUMOSRewstTrackingNumber"
)

# Get webhook JSON from Rewst context - this will be replaced by Rewst at runtime
$WebhookJSON = '{{ CTX.body }}'

function Get-USPSTrackingInfo {
    <#
    .SYNOPSIS
        Gets tracking information for a single USPS tracking number
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$TrackingNumber
    )
    
    $url = "https://tools.usps.com/go/TrackConfirmAction?tLabels=$TrackingNumber"
    
    try {
        # Headers to mimic a real browser
        $headers = @{
            'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
            'Accept' = 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
            'Accept-Language' = 'en-US,en;q=0.5'
            'Connection' = 'keep-alive'
            'Upgrade-Insecure-Requests' = '1'
        }
        
        # Make request
        $response = Invoke-WebRequest -Uri $url -Headers $headers -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop
        $html = $response.Content
        
        # Initialize result
        $result = @{
            tracking_number = $TrackingNumber
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
        
        # Try to extract JSON data first (most reliable if present)
        if ($html -match 'window\.__INITIAL_STATE__\s*=\s*({.+?});' -or 
            $html -match 'var\s+trackingInfo\s*=\s*({.+?});' -or
            $html -match '"trackingEvents"\s*:\s*\[(.+?)\]') {
            try {
                $jsonMatch = $matches[1]
            } catch {
                # JSON extraction failed, continue to HTML parsing
            }
        }
        
        # HTML parsing patterns
        # Status extraction - try multiple approaches
        $statusFound = $false
        
        # Approach 1: Look for main status text
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
        
        # Mark as successful if we got a status
        if ($result.status) {
            $result.success = $true
        } else {
            $result.error_message = "Could not parse tracking status from page"
        }
        
        return $result
        
    } catch {
        return @{
            tracking_number = $TrackingNumber
            status = $null
            status_category = 'Error'
            delivery_date = $null
            location = $null
            last_update = $null
            is_delivered = $false
            is_in_transit = $false
            is_out_for_delivery = $false
            success = $false
            error_message = $_.Exception.Message
            checked_at = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        }
    }
}

# Main execution
try {
    # Parse the webhook JSON
    $webhookData = $WebhookJSON | ConvertFrom-Json
    
    # Extract ticket information
    $ticketId = $webhookData.id
    $ticketSummary = $webhookData.summary
    
    # Find the tracking number in custom fields
    $trackingNumber = $null
    foreach ($field in $webhookData.customfields) {
        if ($field.name -eq $TrackingFieldName) {
            $trackingNumber = $field.value
            break
        }
    }
    
    # Check if tracking number was found
    if (-not $trackingNumber) {
        $errorResult = @{
            ticket_id = $ticketId
            tracking_number = $null
            success = $false
            error_message = "Tracking number not found in custom field '$TrackingFieldName'"
            checked_at = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        }
        
        # Output ONLY JSON - no other text
        $errorResult | ConvertTo-Json -Depth 10 -Compress
        exit 1
    }
    
    # Check if tracking number is empty
    if ([string]::IsNullOrWhiteSpace($trackingNumber)) {
        $errorResult = @{
            ticket_id = $ticketId
            tracking_number = $null
            success = $false
            error_message = "Tracking number field '$TrackingFieldName' is empty"
            checked_at = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        }
        
        # Output ONLY JSON - no other text
        $errorResult | ConvertTo-Json -Depth 10 -Compress
        exit 1
    }
    
    # Get tracking information
    $trackingInfo = Get-USPSTrackingInfo -TrackingNumber $trackingNumber
    
    # Add ticket ID to the result for Rewst to use when updating Halo
    $trackingInfo.ticket_id = $ticketId
    
    # Output ONLY JSON - no other text
    $trackingInfo | ConvertTo-Json -Depth 10 -Compress
    
    # Exit with appropriate code
    if ($trackingInfo.success) {
        exit 0
    } else {
        exit 1
    }
    
} catch {
    # Handle any unexpected errors
    $errorResult = @{
        ticket_id = if ($ticketId) { $ticketId } else { $null }
        tracking_number = if ($trackingNumber) { $trackingNumber } else { $null }
        success = $false
        error_message = "Script error: $($_.Exception.Message)"
        checked_at = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    }
    
    # Output ONLY JSON - no other text
    $errorResult | ConvertTo-Json -Depth 10 -Compress
    exit 1
}
