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
    debug_info = $null
    checked_at = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
}

try {
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
    
    $PS_Results.debug_info = "Found driver at: $driverExe"

    # Start Edge WebDriver process
    $driverPort = 9515
    
    # Kill any existing driver process
    Get-Process -Name "msedgedriver" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
    
    $driverProcess = Start-Process -FilePath $driverExe -ArgumentList "--port=$driverPort" -PassThru -WindowStyle Hidden
    
    Start-Sleep -Seconds 3
    
    try {
        $baseUrl = "http://localhost:$driverPort"
        
        # Check if driver is running
        try {
            $statusCheck = Invoke-RestMethod -Uri "$baseUrl/status" -Method Get -TimeoutSec 5
            $PS_Results.debug_info += " | Driver status: Ready"
        }
        catch {
            throw "WebDriver not responding on port $driverPort. Error: $($_.Exception.Message)"
        }
        
        # Create a new session - try W3C format
        $capJson = '{"capabilities":{"alwaysMatch":{"browserName":"MicrosoftEdge","ms:edgeOptions":{"args":["--headless","--disable-gpu"]}}}}'
        
        $PS_Results.debug_info += " | Sending capabilities"
        
        $sessionResponse = $null
        $lastError = $null
        
        # Try different capability formats
        $capFormats = @(
            '{"capabilities":{"alwaysMatch":{"browserName":"MicrosoftEdge","ms:edgeOptions":{"args":["--headless","--disable-gpu"]}}}}',
            '{"capabilities":{"alwaysMatch":{"ms:edgeOptions":{"args":["--headless"]}}}}',
            '{"desiredCapabilities":{"browserName":"MicrosoftEdge","ms:edgeOptions":{"args":["--headless"]}}}',
            '{"capabilities":{}}'
        )
        
        foreach ($capFormat in $capFormats) {
            try {
                $sessionResponse = Invoke-RestMethod -Uri "$baseUrl/session" -Method Post -Body $capFormat -ContentType "application/json" -TimeoutSec 30
                if ($sessionResponse.value.sessionId) {
                    $PS_Results.debug_info += " | Session created with format"
                    break
                }
            }
            catch {
                $lastError = $_.Exception.Message
                $errBody = $_.ErrorDetails.Message
                continue
            }
        }
        
        if (-not $sessionResponse -or -not $sessionResponse.value.sessionId) {
            throw "Failed to create session after trying all formats. Last error: $lastError. Details: $errBody"
        }
        
        $sessionId = $sessionResponse.value.sessionId
        $PS_Results.debug_info += " | Session: $sessionId"
        
        try {
            # Navigate to USPS tracking page
            $url = "https://tools.usps.com/go/TrackConfirmAction?qtc_tLabels1=$TrackingNumber"
            $navBody = @{ url = $url } | ConvertTo-Json
            Invoke-RestMethod -Uri "$baseUrl/session/$sessionId/url" -Method Post -Body $navBody -ContentType "application/json" -TimeoutSec 60 | Out-Null
            
            $PS_Results.debug_info += " | Navigated to USPS"
            
            # Wait for page to load
            Start-Sleep -Seconds 10
            
            # Get page source
            $sourceResponse = Invoke-RestMethod -Uri "$baseUrl/session/$sessionId/source" -Method Get -TimeoutSec 30
            $pageSource = $sourceResponse.value
            
            $PS_Results.debug_info += " | Page length: $($pageSource.Length)"
            
            # Try to extract tracking status
            $statusFound = $false
            
            # Method 1: Look for common status patterns
            if ($pageSource -match '>\s*(Delivered[^<]{0,100})<') {
                $PS_Results.status = ($matches[1].Trim() -replace '\s+', ' ')
                $statusFound = $true
            }
            elseif ($pageSource -match '>\s*(In Transit[^<]{0,100})<') {
                $PS_Results.status = ($matches[1].Trim() -replace '\s+', ' ')
                $statusFound = $true
            }
            elseif ($pageSource -match '>\s*(Out for Delivery[^<]{0,100})<') {
                $PS_Results.status = ($matches[1].Trim() -replace '\s+', ' ')
                $statusFound = $true
            }
            elseif ($pageSource -match '>\s*(Arrived[^<]{0,80})<') {
                $PS_Results.status = ($matches[1].Trim() -replace '\s+', ' ')
                $statusFound = $true
            }
            elseif ($pageSource -match '>\s*(Departed[^<]{0,80})<') {
                $PS_Results.status = ($matches[1].Trim() -replace '\s+', ' ')
                $statusFound = $true
            }
            elseif ($pageSource -match '>\s*(Accepted[^<]{0,80})<') {
                $PS_Results.status = ($matches[1].Trim() -replace '\s+', ' ')
                $statusFound = $true
            }
            elseif ($pageSource -match '>\s*(Pre-Shipment[^<]{0,80})<') {
                $PS_Results.status = ($matches[1].Trim() -replace '\s+', ' ')
                $statusFound = $true
            }
            elseif ($pageSource -match '>\s*(USPS[^<]{0,100})<') {
                $PS_Results.status = ($matches[1].Trim() -replace '\s+', ' ')
                $statusFound = $true
            }
            
            # Extract delivery date
            if ($pageSource -match 'Delivered[^,]*,?\s*([A-Za-z]+\s+\d{1,2},?\s+\d{4})') {
                $PS_Results.delivery_date = $matches[1].Trim()
            }
            
            # Extract location
            if ($pageSource -match '([A-Z][a-zA-Z\s]+,\s*[A-Z]{2}\s+\d{5})') {
                $PS_Results.location = $matches[1].Trim()
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
                elseif ($PS_Results.status -match 'In Transit|Arrived|Departed|Processed') {
                    $PS_Results.status_category = 'In Transit'
                    $PS_Results.is_in_transit = $true
                }
                elseif ($PS_Results.status -match 'Pre-Shipment|Accepted|Label') {
                    $PS_Results.status_category = 'Pre-Shipment'
                }
                else {
                    $PS_Results.status_category = 'Unknown'
                }
            }
            else {
                # Save snippet for debugging
                $snippet = $pageSource.Substring(0, [Math]::Min(1500, $pageSource.Length))
                $PS_Results.error_message = "Could not find status. Snippet: $snippet"
            }
        }
        finally {
            # Close session
            try {
                Invoke-RestMethod -Uri "$baseUrl/session/$sessionId" -Method Delete -TimeoutSec 10 | Out-Null
            } catch {}
        }
    }
    finally {
        # Stop driver process
        Start-Sleep -Seconds 1
        Get-Process -Name "msedgedriver" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }
}
catch {
    $PS_Results.error_message = "Script error: $($_.Exception.Message)"
    $PS_Results.status_category = 'Error'
}

# Output results (for Rewst callback)
$PS_Results
