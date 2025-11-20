# USPS Tracking Scraper - Runs on Windows endpoint via NinjaRMM
# Uses Edge WebDriver directly (no Selenium module required)
# Returns results via $PS_Results for Rewst callback

param(
    [Parameter(Mandatory=$true)]
    [string]$TrackingNumber,
    
    [Parameter(Mandatory=$false)]
    [int]$TicketId = 0
)

# Initialize results object
$PS_Results = @{
    ticket_id = $TicketId
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

try {
    # Check if Edge is installed
    $edgePath = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
    if (-not (Test-Path $edgePath)) {
        $edgePath = "C:\Program Files\Microsoft\Edge\Application\msedge.exe"
    }
    if (-not (Test-Path $edgePath)) {
        throw "Microsoft Edge not found on this system"
    }

    # Find Edge WebDriver
    $driverExe = $null
    $driverLocations = @(
        "C:\Tools\EdgeDriver\msedgedriver.exe",
        "C:\EdgeDriver\msedgedriver.exe",
        "$env:TEMP\edgedriver\msedgedriver.exe"
    )
    
    foreach ($loc in $driverLocations) {
        if (Test-Path $loc) {
            $driverExe = $loc
            break
        }
    }
    
    if (-not $driverExe) {
        throw "Edge WebDriver not found. Please install msedgedriver.exe to C:\Tools\EdgeDriver\"
    }

    # Start Edge WebDriver process
    $driverPort = 9515
    $driverProcess = Start-Process -FilePath $driverExe -ArgumentList "--port=$driverPort", "--silent" -PassThru -WindowStyle Hidden
    
    Start-Sleep -Seconds 2
    
    try {
        $baseUrl = "http://localhost:$driverPort"
        
        # Create a new session with headless options
        $capabilities = @{
            capabilities = @{
                alwaysMatch = @{
                    "ms:edgeOptions" = @{
                        args = @(
                            "--headless",
                            "--disable-gpu",
                            "--no-sandbox",
                            "--disable-dev-shm-usage",
                            "--window-size=1920,1080",
                            "--user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
                        )
                    }
                }
            }
        }
        
        $sessionResponse = Invoke-RestMethod -Uri "$baseUrl/session" -Method Post -Body ($capabilities | ConvertTo-Json -Depth 10) -ContentType "application/json"
        $sessionId = $sessionResponse.value.sessionId
        
        try {
            # Navigate to USPS tracking page
            $url = "https://tools.usps.com/go/TrackConfirmAction?qtc_tLabels1=$TrackingNumber"
            $navBody = @{ url = $url } | ConvertTo-Json
            Invoke-RestMethod -Uri "$baseUrl/session/$sessionId/url" -Method Post -Body $navBody -ContentType "application/json" | Out-Null
            
            # Wait for page to load
            Start-Sleep -Seconds 8
            
            # Get page source
            $sourceResponse = Invoke-RestMethod -Uri "$baseUrl/session/$sessionId/source" -Method Get
            $pageSource = $sourceResponse.value
            
            # Try to extract tracking status
            $statusFound = $false
            
            # Method 1: Look for status banner
            if ($pageSource -match 'class="[^"]*tb-status[^"]*"[^>]*>([^<]+)<') {
                $PS_Results.status = $matches[1].Trim()
                $statusFound = $true
            }
            # Method 2: Look for delivery status
            elseif ($pageSource -match 'class="[^"]*delivery-status[^"]*"[^>]*>([^<]+)<') {
                $PS_Results.status = $matches[1].Trim()
                $statusFound = $true
            }
            # Method 3: Look for banner content
            elseif ($pageSource -match 'class="[^"]*banner-content[^"]*"[^>]*>\s*<[^>]+>([^<]+)<') {
                $PS_Results.status = $matches[1].Trim()
                $statusFound = $true
            }
            # Method 4: Search for status keywords
            elseif ($pageSource -match '>\s*(Delivered[^<]{0,100})<' -or
                    $pageSource -match '>\s*(In Transit[^<]{0,100})<' -or
                    $pageSource -match '>\s*(Out for Delivery[^<]{0,100})<' -or
                    $pageSource -match '>\s*(Arrived[^<]{0,80})<' -or
                    $pageSource -match '>\s*(Departed[^<]{0,80})<' -or
                    $pageSource -match '>\s*(USPS in possession of item[^<]{0,50})<' -or
                    $pageSource -match '>\s*(Accepted[^<]{0,80})<' -or
                    $pageSource -match '>\s*(Pre-Shipment[^<]{0,80})<') {
                $PS_Results.status = $matches[1].Trim() -replace '\s+', ' '
                $statusFound = $true
            }
            
            # Extract delivery date
            if ($pageSource -match 'Delivered[^,]*,?\s*([A-Za-z]+\s+\d{1,2},?\s+\d{4})') {
                $PS_Results.delivery_date = $matches[1].Trim()
            }
            elseif ($pageSource -match '(?:Expected|Estimated)\s+Delivery[^:]*:?\s*[^A-Za-z]*([A-Za-z]+\s+\d{1,2},?\s+\d{4})') {
                $PS_Results.delivery_date = $matches[1].Trim()
            }
            
            # Extract location
            if ($pageSource -match '([A-Z][a-zA-Z\s]+,\s*[A-Z]{2}\s+\d{5})') {
                $PS_Results.location = $matches[1].Trim()
            }
            
            # Extract timestamp
            if ($pageSource -match '(\d{1,2}:\d{2}\s*(?:am|pm)[^,]*,\s*[A-Za-z]+\s+\d{1,2},?\s+\d{4})') {
                $PS_Results.last_update = $matches[1].Trim()
            }
            elseif ($pageSource -match '([A-Za-z]+\s+\d{1,2},?\s+\d{4},?\s+\d{1,2}:\d{2}\s*(?:am|pm))') {
                $PS_Results.last_update = $matches[1].Trim()
            }
            
            # Categorize status
            if ($PS_Results.status) {
                $PS_Results.success = $true
                
                if ($PS_Results.status -match 'Delivered') {
                    $PS_Results.status_category = 'Delivered'
                    $PS_Results.is_delivered = $true
                }
                elseif ($PS_Results.status -match 'Out for Delivery') {
                    $PS_Results.status_category = 'Out for Delivery'
                    $PS_Results.is_out_for_delivery = $true
                }
                elseif ($PS_Results.status -match 'In Transit|Arrived|Departed|Processed|In-Transit|USPS in possession') {
                    $PS_Results.status_category = 'In Transit'
                    $PS_Results.is_in_transit = $true
                }
                elseif ($PS_Results.status -match 'Pre-Shipment|Accepted|Label Created|Shipping Label') {
                    $PS_Results.status_category = 'Pre-Shipment'
                }
                else {
                    $PS_Results.status_category = 'Unknown'
                }
            }
            else {
                # Debug: save page snippet
                $snippet = ""
                if ($pageSource.Length -gt 2000) {
                    $snippet = $pageSource.Substring(0, 2000)
                } else {
                    $snippet = $pageSource
                }
                $PS_Results.error_message = "Could not find tracking status. Page length: $($pageSource.Length). Snippet: $snippet"
            }
        }
        finally {
            # Close session
            try {
                Invoke-RestMethod -Uri "$baseUrl/session/$sessionId" -Method Delete | Out-Null
            } catch {}
        }
    }
    finally {
        # Stop driver process
        if ($driverProcess -and -not $driverProcess.HasExited) {
            $driverProcess.Kill()
            $driverProcess.Dispose()
        }
    }
}
catch {
    $PS_Results.error_message = "Script error: $($_.Exception.Message)"
    $PS_Results.status_category = 'Error'
}

# Output results (for Rewst callback)
$PS_Results
