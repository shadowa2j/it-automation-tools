<#
.SYNOPSIS
    USPS Tracking Web Scraper
    
.DESCRIPTION
    Scrapes tracking information from USPS public tracking website.
    Returns structured data including status, delivery date, and tracking details.
    
.PARAMETER TrackingNumber
    The USPS tracking number to look up
    
.PARAMETER ReturnJSON
    If specified, returns JSON formatted output
    
.EXAMPLE
    .\Get-USPSTracking.ps1 -TrackingNumber "9438340109490000291352"
    
.EXAMPLE
    .\Get-USPSTracking.ps1 -TrackingNumber "9438340109490000291352" -ReturnJSON
    
.NOTES
    Author: Bryan (with Claude assistance)
    Version: 1.0
    Date: 2025-11-20
    
    This script scrapes the public USPS tracking website. For production use,
    consider rate limiting (1-2 second delays between requests) to avoid
    being blocked.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$TrackingNumber,
    
    [Parameter(Mandatory=$false)]
    [switch]$ReturnJSON
)

function Get-USPSTracking {
    param(
        [string]$TrackingNumber
    )
    
    # Build the tracking URL
    $url = "https://tools.usps.com/go/TrackConfirmAction?tLabels=$TrackingNumber"
    
    try {
        # Set up web request with headers to mimic a real browser
        $headers = @{
            'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
            'Accept' = 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8'
            'Accept-Language' = 'en-US,en;q=0.5'
            'Accept-Encoding' = 'gzip, deflate, br'
            'Connection' = 'keep-alive'
            'Upgrade-Insecure-Requests' = '1'
            'Sec-Fetch-Dest' = 'document'
            'Sec-Fetch-Mode' = 'navigate'
            'Sec-Fetch-Site' = 'none'
        }
        
        # Make the web request
        $response = Invoke-WebRequest -Uri $url -Headers $headers -UseBasicParsing -ErrorAction Stop
        
        $htmlContent = $response.Content
        
        # Initialize result object
        $result = [PSCustomObject]@{
            TrackingNumber = $TrackingNumber
            Status = $null
            StatusDetails = $null
            DeliveryDate = $null
            Location = $null
            LastUpdate = $null
            IsDelivered = $false
            Success = $false
            ErrorMessage = $null
            RawHTML = $htmlContent  # Include for debugging, remove in production
        }
        
        # First, try to find JSON data embedded in the page (most reliable)
        if ($htmlContent -match 'var\s+trackingData\s*=\s*({[^;]+});' -or 
            $htmlContent -match 'trackingInfo["\']?\s*[:=]\s*({[^;]+});') {
            try {
                $jsonData = $matches[1]
                $trackingData = $jsonData | ConvertFrom-Json
                
                # Extract from JSON if available
                if ($trackingData.status) { $result.Status = $trackingData.status }
                if ($trackingData.deliveryDate) { $result.DeliveryDate = $trackingData.deliveryDate }
                if ($trackingData.location) { $result.Location = $trackingData.location }
                if ($trackingData.statusDetails) { $result.StatusDetails = $trackingData.statusDetails }
            }
            catch {
                # JSON parsing failed, continue to HTML parsing
            }
        }
        
        # Fallback: Parse HTML if JSON not found or failed
        # Pattern 1: Look for primary status in various possible formats
        if (-not $result.Status) {
            if ($htmlContent -match '<div[^>]*class="[^"]*tracking-summary[^"]*"[^>]*>([^<]+)</div>') {
                $result.Status = $matches[1].Trim()
            }
            elseif ($htmlContent -match '<h2[^>]*class="[^"]*delivery[_-]?status[^"]*"[^>]*>([^<]+)</h2>') {
                $result.Status = $matches[1].Trim()
            }
            elseif ($htmlContent -match '<div[^>]*class="[^"]*status-category[^"]*"[^>]*>([^<]+)</div>') {
                $result.Status = $matches[1].Trim()
            }
            # Try to find any status text
            elseif ($htmlContent -match '(Delivered|In Transit|Out for Delivery|Accepted|Arrived|Departed|Pre-Shipment)[^<]{0,200}') {
                $result.Status = $matches[0].Trim() -replace '\s+', ' '
                $result.Status = ($result.Status -split '\n')[0].Trim()
            }
        }
        
        # Pattern 2: Look for delivery date
        if (-not $result.DeliveryDate) {
            if ($htmlContent -match 'Expected Delivery[^<]*:\s*([A-Za-z]+\s+\d{1,2},?\s+\d{4})') {
                $result.DeliveryDate = $matches[1].Trim()
            }
            elseif ($htmlContent -match 'Delivered[^<]*,?\s*([A-Za-z]+\s+\d{1,2},?\s+\d{4})') {
                $result.DeliveryDate = $matches[1].Trim()
                $result.IsDelivered = $true
            }
            elseif ($htmlContent -match '(?:Expected|Estimated)\s+Delivery[^:]*:\s*<[^>]+>([^<]+)</') {
                $result.DeliveryDate = $matches[1].Trim()
            }
        }
        
        # Pattern 3: Look for location
        if (-not $result.Location) {
            if ($htmlContent -match '<span[^>]*class="[^"]*location[^"]*"[^>]*>([^<]+)</span>') {
                $result.Location = $matches[1].Trim()
            }
            elseif ($htmlContent -match '([A-Z]{2,}\s+\d{5})') {
                # Try to capture city, state, zip
                $result.Location = $matches[1].Trim()
            }
        }
        
        # Pattern 4: Check if delivered
        if ($result.Status -match 'Delivered') {
            $result.IsDelivered = $true
        }
        
        # Pattern 5: Get last update timestamp  
        if (-not $result.LastUpdate) {
            if ($htmlContent -match '([A-Za-z]+\s+\d{1,2},?\s+\d{4}(?:,?\s+\d{1,2}:\d{2}\s*(?:am|pm))?)') {
                $result.LastUpdate = $matches[1].Trim()
            }
        }
        
        # Pattern 6: Try to extract additional details/events
        $detailsPattern = '<div[^>]*class="[^"]*(?:tracking-event|scan-event)[^"]*"[^>]*>([^<]+)</div>'
        $allMatches = [regex]::Matches($htmlContent, $detailsPattern)
        if ($allMatches.Count -gt 0) {
            $details = @()
            foreach ($match in $allMatches[0..4]) {  # Get first 5 events
                $details += $match.Groups[1].Value.Trim()
            }
            if ($details.Count -gt 0) {
                $result.StatusDetails = $details -join ' | '
            }
        }
        
        # Set success if we got at least a status
        if ($result.Status) {
            $result.Success = $true
        }
        else {
            $result.ErrorMessage = "Could not parse tracking status from HTML"
        }
        
        return $result
        
    }
    catch {
        $result = [PSCustomObject]@{
            TrackingNumber = $TrackingNumber
            Status = $null
            StatusDetails = $null
            DeliveryDate = $null
            Location = $null
            LastUpdate = $null
            IsDelivered = $false
            Success = $false
            ErrorMessage = $_.Exception.Message
        }
        return $result
    }
}

# Main execution
$trackingInfo = Get-USPSTracking -TrackingNumber $TrackingNumber

if ($ReturnJSON) {
    # Remove RawHTML from JSON output
    $trackingInfo.PSObject.Properties.Remove('RawHTML')
    $trackingInfo | ConvertTo-Json -Depth 10
}
else {
    $trackingInfo
}
