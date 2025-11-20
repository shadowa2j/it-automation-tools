# USPS Tracking Scraper - Runs on Windows endpoint via NinjaRMM
# Uses Edge WebDriver (headless) to render JavaScript and scrape tracking data
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

    # Get Edge version
    $edgeVersion = (Get-Item $edgePath).VersionInfo.ProductVersion
    $edgeMajorVersion = $edgeVersion.Split('.')[0]

    # Check for Edge WebDriver in multiple locations
    $driverPath = $null
    $driverExe = $null
    
    # Location 1: Pre-installed in C:\Tools\EdgeDriver
    if (Test-Path "C:\Tools\EdgeDriver\msedgedriver.exe") {
        $driverPath = "C:\Tools\EdgeDriver"
        $driverExe = "$driverPath\msedgedriver.exe"
    }
    # Location 2: Pre-installed in C:\EdgeDriver
    elseif (Test-Path "C:\EdgeDriver\msedgedriver.exe") {
        $driverPath = "C:\EdgeDriver"
        $driverExe = "$driverPath\msedgedriver.exe"
    }
    # Location 3: Already in TEMP
    elseif (Test-Path "$env:TEMP\edgedriver\msedgedriver.exe") {
        $driverPath = "$env:TEMP\edgedriver"
        $driverExe = "$driverPath\msedgedriver.exe"
    }
    # Location 4: Try to download
    else {
        $driverPath = "$env:TEMP\edgedriver"
        $driverExe = "$driverPath\msedgedriver.exe"
        
        # Create driver directory
        New-Item -ItemType Directory -Path $driverPath -Force | Out-Null
        
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        
        # Try multiple download sources
        $downloadSuccess = $false
        $driverUrls = @(
            "https://msedgedriver.azureedge.net/$edgeVersion/edgedriver_win64.zip",
            "https://msedgewebdriverstorage.blob.core.windows.net/edgewebdriver/$edgeVersion/edgedriver_win64.zip"
        )
        
        foreach ($driverUrl in $driverUrls) {
            try {
                $driverZip = "$env:TEMP\edgedriver.zip"
                Invoke-WebRequest -Uri $driverUrl -OutFile $driverZip -UseBasicParsing -TimeoutSec 30
                Expand-Archive -Path $driverZip -DestinationPath $driverPath -Force
                Remove-Item $driverZip -Force -ErrorAction SilentlyContinue
                $downloadSuccess = $true
                break
            }
            catch {
                continue
            }
        }
        
        if (-not $downloadSuccess) {
            throw "Could not download Edge WebDriver. Please manually install msedgedriver.exe to C:\Tools\EdgeDriver\"
        }
    }
    
    if (-not (Test-Path $driverExe)) {
        throw "Edge WebDriver not found at $driverExe. Please manually install msedgedriver.exe to C:\Tools\EdgeDriver\"
    }

    # Install Selenium PowerShell module if needed
    if (-not (Get-Module -ListAvailable -Name Selenium)) {
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser | Out-Null
        Install-Module -Name Selenium -Force -Scope CurrentUser -AllowClobber | Out-Null
    }
    Import-Module Selenium -ErrorAction Stop

    # Start Edge in headless mode
    $edgeOptions = New-Object OpenQA.Selenium.Edge.EdgeOptions
    $edgeOptions.AddArgument("--headless")
    $edgeOptions.AddArgument("--disable-gpu")
    $edgeOptions.AddArgument("--no-sandbox")
    $edgeOptions.AddArgument("--disable-dev-shm-usage")
    $edgeOptions.AddArgument("--window-size=1920,1080")
    $edgeOptions.AddArgument("--user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")

    $edgeService = [OpenQA.Selenium.Edge.EdgeDriverService]::CreateDefaultService($driverPath)
    $edgeService.HideCommandPromptWindow = $true
    
    $driver = New-Object OpenQA.Selenium.Edge.EdgeDriver($edgeService, $edgeOptions)
    $driver.Manage().Timeouts().ImplicitWait = [TimeSpan]::FromSeconds(10)
    $driver.Manage().Timeouts().PageLoad = [TimeSpan]::FromSeconds(30)

    try {
        # Navigate to USPS tracking page
        $url = "https://tools.usps.com/go/TrackConfirmAction?qtc_tLabels1=$TrackingNumber"
        $driver.Navigate().GoToUrl($url)
        
        # Wait for page to load and JavaScript to render
        Start-Sleep -Seconds 5
        
        # Wait for tracking info to appear (try multiple selectors)
        $maxWait = 20
        $waited = 0
        $pageSource = ""
        
        while ($waited -lt $maxWait) {
            $pageSource = $driver.PageSource
            
            # Check if tracking data has loaded
            if ($pageSource -match "Delivered" -or 
                $pageSource -match "In Transit" -or 
                $pageSource -match "Out for Delivery" -or
                $pageSource -match "Arrived" -or
                $pageSource -match "Departed" -or
                $pageSource -match "Accepted" -or
                $pageSource -match "Pre-Shipment" -or
                $pageSource -match "tracking-summary" -or
                $pageSource -match "tb-status") {
                break
            }
            
            Start-Sleep -Seconds 1
            $waited++
        }
        
        # Try to find status using various methods
        $statusFound = $false
        
        # Method 1: Try to find element by class
        try {
            $statusElement = $driver.FindElement([OpenQA.Selenium.By]::CssSelector(".tb-status, .tracking-summary, .delivery_status, .status-category, .banner-content"))
            if ($statusElement) {
                $PS_Results.status = $statusElement.Text.Trim()
                $statusFound = $true
            }
        } catch {}
        
        # Method 2: Try finding by XPath for common status patterns
        if (-not $statusFound) {
            try {
                $statusElement = $driver.FindElement([OpenQA.Selenium.By]::XPath("//*[contains(@class, 'status') or contains(@class, 'delivery') or contains(@class, 'tracking')]//h2 | //*[contains(@class, 'status') or contains(@class, 'delivery') or contains(@class, 'tracking')]//h3"))
                if ($statusElement) {
                    $PS_Results.status = $statusElement.Text.Trim()
                    $statusFound = $true
                }
            } catch {}
        }
        
        # Method 3: Parse page source with regex
        if (-not $statusFound) {
            if ($pageSource -match '<[^>]*class="[^"]*(?:tb-status|tracking-summary|delivery-status|banner-content)[^"]*"[^>]*>([^<]+)<') {
                $PS_Results.status = $matches[1].Trim()
                $statusFound = $true
            }
            elseif ($pageSource -match '>(Delivered[^<]{0,100})<' -or
                    $pageSource -match '>(In Transit[^<]{0,100})<' -or
                    $pageSource -match '>(Out for Delivery[^<]{0,100})<' -or
                    $pageSource -match '>(Arrived[^<]{0,100})<' -or
                    $pageSource -match '>(Departed[^<]{0,100})<' -or
                    $pageSource -match '>(Accepted[^<]{0,100})<' -or
                    $pageSource -match '>(Pre-Shipment[^<]{0,100})<') {
                $PS_Results.status = $matches[1].Trim() -replace '\s+', ' '
                $statusFound = $true
            }
        }
        
        # Try to get delivery date
        try {
            $dateElement = $driver.FindElement([OpenQA.Selenium.By]::CssSelector(".tb-date, .expected-delivery, .delivery-date"))
            if ($dateElement) {
                $PS_Results.delivery_date = $dateElement.Text.Trim()
            }
        } catch {}
        
        # Try regex for date
        if (-not $PS_Results.delivery_date) {
            if ($pageSource -match '(?:Expected|Estimated)?\s*Delivery[^:]*:?\s*([A-Za-z]+\s+\d{1,2},?\s+\d{4})') {
                $PS_Results.delivery_date = $matches[1].Trim()
            }
            elseif ($pageSource -match 'Delivered[^,]*,?\s*([A-Za-z]+\s+\d{1,2},?\s+\d{4})') {
                $PS_Results.delivery_date = $matches[1].Trim()
            }
        }
        
        # Try to get location
        try {
            $locationElement = $driver.FindElement([OpenQA.Selenium.By]::CssSelector(".tb-location, .location, .event-location"))
            if ($locationElement) {
                $PS_Results.location = $locationElement.Text.Trim()
            }
        } catch {}
        
        # Try regex for location
        if (-not $PS_Results.location) {
            if ($pageSource -match '([A-Z][a-zA-Z\s]+,\s*[A-Z]{2}\s+\d{5})') {
                $PS_Results.location = $matches[1].Trim()
            }
        }
        
        # Try to get last update time
        if ($pageSource -match '(\d{1,2}:\d{2}\s*(?:am|pm|AM|PM)[^<]{0,50}[A-Za-z]+\s+\d{1,2},?\s+\d{4})') {
            $PS_Results.last_update = $matches[1].Trim()
        }
        elseif ($pageSource -match '([A-Za-z]+\s+\d{1,2},?\s+\d{4}[^<]{0,20}\d{1,2}:\d{2}\s*(?:am|pm|AM|PM))') {
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
            elseif ($PS_Results.status -match 'In Transit|Arrived|Departed|Processed|In-Transit') {
                $PS_Results.status_category = 'In Transit'
                $PS_Results.is_in_transit = $true
            }
            elseif ($PS_Results.status -match 'Pre-Shipment|Accepted|Label Created|Shipping Label Created') {
                $PS_Results.status_category = 'Pre-Shipment'
            }
            else {
                $PS_Results.status_category = 'Unknown'
            }
        }
        else {
            # Save snippet for debugging
            $snippet = $pageSource.Substring(0, [Math]::Min(1500, $pageSource.Length))
            $PS_Results.error_message = "Could not find tracking status. Page snippet: $snippet"
        }
        
    }
    finally {
        # Clean up - close browser
        if ($driver) {
            $driver.Quit()
            $driver.Dispose()
        }
    }
    
}
catch {
    $PS_Results.error_message = "Script error: $($_.Exception.Message)"
    $PS_Results.status_category = 'Error'
}

# Output results (for Rewst callback)
$PS_Results
