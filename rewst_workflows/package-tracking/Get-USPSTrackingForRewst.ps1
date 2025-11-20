<#
.SYNOPSIS
    USPS Tracking Scraper for Rewst Integration
    
.DESCRIPTION
    Scrapes USPS tracking information and returns structured JSON for Rewst/HaloPSA integration.
    Includes rate limiting and error handling for production use.
    
.PARAMETER TrackingNumbers
    Array of USPS tracking numbers to look up
    
.PARAMETER DelayBetweenRequests
    Delay in seconds between requests (default: 2 seconds for rate limiting)
    
.PARAMETER OutputPath
    Optional path to save results as JSON file
    
.EXAMPLE
    .\Get-USPSTrackingForRewst.ps1 -TrackingNumbers @("9438340109490000291352")
    
.EXAMPLE
    $tracking = @("9438340109490000291352", "9400100000000000000000")
    .\Get-USPSTrackingForRewst.ps1 -TrackingNumbers $tracking -DelayBetweenRequests 3
    
.NOTES
    Author: Bryan
    Version: 1.0
    Date: 2025-11-20
    
    IMPORTANT: 
    - This scrapes the public USPS website, not their API
    - Use rate limiting (2-3 second delays) to avoid being blocked
    - For 100 checks/week, spread throughout the day
    - Consider running once daily for each active tracking number
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string[]]$TrackingNumbers,
    
    [Parameter(Mandatory=$false)]
    [int]$DelayBetweenRequests = 2,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath
)

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
                Write-Verbose "Found embedded JSON data"
            } catch {
                Write-Verbose "JSON extraction failed, falling back to HTML parsing"
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
Write-Verbose "Starting USPS tracking check for $($TrackingNumbers.Count) tracking number(s)"

$results = @()
$counter = 0

foreach ($trackingNum in $TrackingNumbers) {
    $counter++
    Write-Verbose "[$counter/$($TrackingNumbers.Count)] Checking tracking number: $trackingNum"
    
    $trackingInfo = Get-USPSTrackingInfo -TrackingNumber $trackingNum
    $results += $trackingInfo
    
    # Rate limiting: Wait between requests (except for the last one)
    if ($counter -lt $TrackingNumbers.Count) {
        Write-Verbose "Waiting $DelayBetweenRequests seconds before next request..."
        Start-Sleep -Seconds $DelayBetweenRequests
    }
}

# Convert to JSON
$jsonOutput = $results | ConvertTo-Json -Depth 10

# Output to file if specified
if ($OutputPath) {
    $jsonOutput | Out-File -FilePath $OutputPath -Encoding UTF8
    Write-Verbose "Results saved to: $OutputPath"
}

# Return JSON to console (for Rewst to capture)
Write-Output $jsonOutput
