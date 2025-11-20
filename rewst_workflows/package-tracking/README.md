# USPS Tracking Web Scraper for Rewst

## Overview
This PowerShell script scrapes tracking information from the public USPS tracking website and returns structured JSON data suitable for Rewst/HaloPSA integration.

## Features
- ✅ **100% Free** - No API keys or registration required
- ✅ **Structured JSON Output** - Easy integration with Rewst/HaloPSA
- ✅ **Rate Limiting** - Built-in delays to avoid being blocked
- ✅ **Batch Processing** - Handle multiple tracking numbers
- ✅ **Status Categorization** - Delivered, In Transit, Out for Delivery, etc.
- ✅ **Error Handling** - Graceful failure handling

## Files
1. **Get-USPSTrackingForRewst.ps1** - Production-ready script for Rewst
2. **Get-USPSTracking.ps1** - Standalone script with more verbose output

## Usage

### Basic Usage
```powershell
# Single tracking number
.\Get-USPSTrackingForRewst.ps1 -TrackingNumbers @("9438340109490000291352")

# Multiple tracking numbers
$trackingNums = @(
    "9438340109490000291352",
    "9400100000000000000000",
    "9205500000000000000000"
)
.\Get-USPSTrackingForRewst.ps1 -TrackingNumbers $trackingNums

# With custom delay (3 seconds between requests)
.\Get-USPSTrackingForRewst.ps1 -TrackingNumbers $trackingNums -DelayBetweenRequests 3

# Save to file
.\Get-USPSTrackingForRewst.ps1 -TrackingNumbers $trackingNums -OutputPath "C:\tracking_results.json"
```

### Output Format
```json
[
  {
    "tracking_number": "9438340109490000291352",
    "status": "Delivered, Left with Individual",
    "status_category": "Delivered",
    "delivery_date": "November 18, 2025",
    "location": "PORT HURON, MI 48060",
    "last_update": "November 18, 2025, 2:15 pm",
    "is_delivered": true,
    "is_in_transit": false,
    "is_out_for_delivery": false,
    "success": true,
    "error_message": null,
    "checked_at": "2025-11-20 14:30:00"
  }
]
```

## Rewst Integration

### Step 1: Create Custom Integration in Rewst

1. In Rewst, go to **Configuration** > **Integrations**
2. Click **Create Custom Integration**
3. Name it: "USPS Tracking Scraper"

### Step 2: Create Workflow

Create a workflow with the following structure:

#### Workflow: Daily USPS Tracking Check

**Trigger**: Time-based (runs once daily)

**Steps**:

1. **Get Active Shipments from HaloPSA**
   - Tool: HaloPSA
   - Action: Query tickets with custom field "Tracking Number"
   - Filter: Status = "Awaiting Delivery" AND Tracking Number is not empty
   - Output Variable: `active_shipments`

2. **Extract Tracking Numbers**
   - Tool: Core - Data Transformation
   - Transform: Extract array of tracking numbers from `active_shipments`
   - Output Variable: `tracking_numbers`

3. **Run PowerShell Script**
   - Tool: Custom Integration / PowerShell
   - Script:
   ```powershell
   $trackingNums = {{ CTX.tracking_numbers }}
   .\Get-USPSTrackingForRewst.ps1 -TrackingNumbers $trackingNums -DelayBetweenRequests 2
   ```
   - Output Variable: `tracking_results`

4. **Parse JSON Results**
   - Tool: Core - JSON Parse
   - Input: `{{ CTX.tracking_results }}`
   - Output Variable: `parsed_results`

5. **Loop Through Results**
   - Tool: Core - For Each
   - Array: `{{ CTX.parsed_results }}`
   - Variable Name: `result`
   
   **Inside Loop**:
   
   a. **Check if Status Changed**
      - Tool: Core - Conditional
      - Condition: `{{ CTX.result.success }} == true`
      
   b. **Update HaloPSA Ticket**
      - Tool: HaloPSA
      - Action: Update Ticket
      - Ticket ID: `{{ Match ticket by tracking_number }}`
      - Fields to Update:
        - Custom Field "Shipping Status": `{{ CTX.result.status_category }}`
        - Custom Field "Last Tracking Update": `{{ CTX.result.last_update }}`
        - Custom Field "Delivery Date": `{{ CTX.result.delivery_date }}`
      
   c. **Add Note if Delivered**
      - Tool: Core - Conditional
      - Condition: `{{ CTX.result.is_delivered }} == true`
      - If True:
        - Tool: HaloPSA - Add Note
        - Note: "📦 Package delivered on {{ CTX.result.delivery_date }} to {{ CTX.result.location }}"
        - Update Status: "Delivered"

6. **Error Handling**
   - Wrap entire workflow in try/catch
   - On error, log to Rewst and optionally send notification

### Step 3: Schedule the Workflow

- Set workflow to run once per day (e.g., 9 AM)
- This checks each active tracking number once daily
- With 100 checks/week, you'll stay well under any rate limits

## Important Notes

### Rate Limiting
- **Default**: 2 seconds between requests
- **Recommendation**: For 100 checks/week spread across daily runs, 2-3 seconds is safe
- **Never** run more frequently than once per hour for the same tracking number

### Reliability Considerations

**Pros:**
- ✅ Completely free
- ✅ No registration or API approval needed
- ✅ Works with public USPS website

**Cons:**
- ⚠️ Page structure could change (would need script updates)
- ⚠️ Not officially supported by USPS
- ⚠️ Could be blocked if rate limits exceeded
- ⚠️ No SLA or guarantee of uptime

**Mitigation Strategies:**
1. Always include error handling
2. Log failures and review periodically
3. Have a backup plan (manual checks if script fails)
4. Consider script monitoring to detect page structure changes
5. Spread requests throughout the day

### Legal/TOS Considerations
This script:
- Scrapes the **public** USPS tracking website (not their restricted Web Tools API)
- Mimics normal browser behavior
- Includes rate limiting to be respectful
- Is for low-volume personal/business use (100/week)

For official high-volume commercial use, consider applying for USPS API access.

## Testing

Test with a real tracking number:
```powershell
.\Get-USPSTrackingForRewst.ps1 -TrackingNumbers @("9438340109490000291352") -Verbose
```

Expected output should include JSON with tracking status.

## Troubleshooting

### Issue: "Could not parse tracking status"
**Solution**: The USPS page structure may have changed. Inspect the HTML:
```powershell
$response = Invoke-WebRequest -Uri "https://tools.usps.com/go/TrackConfirmAction?tLabels=YOURNUMBER"
$response.Content | Out-File debug.html
# Open debug.html and look for status text
```

### Issue: HTTP 403 or blocked requests
**Solution**: 
- Increase `DelayBetweenRequests` to 5-10 seconds
- Reduce check frequency
- Verify network/proxy settings

### Issue: Empty or null status
**Solution**:
- Verify tracking number is valid and active
- Check if package is pre-shipment (label created but not yet scanned)
- Try the tracking number manually on USPS.com

## Version History
- **v1.0** (2025-11-20): Initial release

## Author
Bryan (IT Professional)
Created with assistance from Claude (Anthropic)

## License
Use at your own risk. No warranty provided.
