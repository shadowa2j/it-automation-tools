# Device Reboot via Webhook - Rewst Workflow Documentation

## Overview

This workflow provides a webhook endpoint that accepts device reboot requests and executes them via NinjaRMM. It's designed to be triggered by PowerShell scripts running in Terminal Services sessions, allowing users to initiate device reboots remotely.

---

## Workflow Details

**Workflow Name:** Device Reboot via Webhook  
**Trigger Type:** Webhook  
**Webhook URL:** `https://engine.rewst.io/webhooks/custom/trigger/019c1e7f-ac3f-75b7-9ce1-7c4975177cff/019889ac-540c-7327-9dac-2a222afec0dc`

---

## Input Variables

| Variable | Type | Required | Description |
|----------|------|----------|-------------|
| `device_id` | number | Yes | NinjaRMM device ID to reboot |

---

## Workflow Actions

### 1. start (noop)
**Purpose:** Entry point that extracts the device ID from webhook payload and initializes error tracking variables.

**Publishes:**
- `device_id` - The device ID from the webhook payload
- `error_step` - Empty string (initialized for error tracking)
- `error_message` - Empty string (initialized for error tracking)

**Transitions:**
- On success → `ninja_one_reboot_device`

---

### 2. ninja_one_reboot_device (NinjaRMM Action)
**Purpose:** Sends reboot command to the specified device via NinjaRMM API.

**Input Parameters:**
- `path_params.id` - `{{ CTX.device_id }}`
- `path_params.mode` - `NORMAL`
- `json_body.reason` - `"Reboot initiated via webhook"`

**Transition Mode:** FOLLOW_FIRST

**Transitions:**
- On success → `finish`
- On failure → `error_notification`
  - Publishes `error_step`: "reboot_device"
  - Publishes `error_message`: Error details from API response

---

### 3. error_notification (Send Email)
**Purpose:** Sends error notification email when the workflow fails.

**Join:** 1 (waits for any incoming path)

**Email Configuration:**
- **To:** qcs_rewst@qcsph.com
- **Subject:** `[Rewst Error] Device Reboot - Device ID {{ CTX.device_id | default('Unknown') }}`
- **Body:** HTML-formatted email containing:
  - Device ID
  - Failed step name
  - Error message
  
**Transitions:**
- On success → `finish`

---

### 4. finish (noop)
**Purpose:** Exit point for the workflow.

**Join:** 1 (accepts paths from success or error paths)

---

## Workflow Flow Diagram

```
start
  ↓ [Extract device_id, initialize error vars]
ninja_one_reboot_device
  ├─ SUCCESS → finish
  └─ FAILED → error_notification → finish
```

---

## PowerShell Scripts

Three PowerShell scripts are available to trigger this workflow for specific devices:

### Reboot-HNC.ps1
- **Device ID:** 3329
- **Location:** `E:\OneDrive - Quality Computer Solutions\Documents\GitHub\it-automation-tools\rewst_workflows\`

### Reboot-ESC.ps1
- **Device ID:** 3327
- **Location:** `E:\OneDrive - Quality Computer Solutions\Documents\GitHub\it-automation-tools\rewst_workflows\`

### Reboot-WMN.ps1
- **Device ID:** 3328
- **Location:** `E:\OneDrive - Quality Computer Solutions\Documents\GitHub\it-automation-tools\rewst_workflows\`

**Script Functionality:**
- Sends POST request to webhook URL
- Includes device_id in JSON payload
- Displays success/error messages in console
- Shows any response data from Rewst

**Usage Example:**
```powershell
.\Reboot-HNC.ps1
```

---

## Error Handling

The workflow implements comprehensive error handling:

1. **Failed Reboot Action:** If the NinjaRMM reboot command fails, the workflow:
   - Captures the error step (`reboot_device`)
   - Captures the error message from the API response
   - Sends email notification to qcs_rewst@qcsph.com
   - Completes the workflow (does not retry)

2. **Email Notification Format:** Error emails include an HTML-formatted table with:
   - Device ID that failed
   - Step where failure occurred
   - Detailed error message
   - Suggestion to review manually

---

## Prerequisites

1. **NinjaRMM Integration:** Workflow must have NinjaRMM pack configured with appropriate credentials
2. **Device IDs:** Valid NinjaRMM device IDs for target devices
3. **Email Configuration:** Rewst email integration configured for sending notifications
4. **Webhook Access:** Terminal Services environment must have network access to engine.rewst.io

---

## Troubleshooting

### Device ID Shows as Null
**Cause:** Workflow input variable not defined  
**Solution:** Ensure `device_id` is configured as a workflow input variable (type: number, required: true)

### "Expecting value: line 1 column 1" Error
**Cause:** NinjaRMM API returning empty response (common for reboot actions)  
**Solution:** This may be normal behavior - verify device actually reboots despite error message

### Webhook Returns Immediately with No Response
**Cause:** Default webhook configuration doesn't wait for results  
**Solution:** This is expected behavior - workflow runs asynchronously

### Script Connection Errors
**Cause:** Network restrictions blocking access to engine.rewst.io  
**Solution:** Verify firewall rules allow HTTPS to engine.rewst.io from Terminal Services environment

---

## Maintenance Notes

- Scripts are version-controlled in both personal and work GitHub repositories
- Webhook URL is hardcoded in scripts - if regenerated, all three scripts must be updated
- Device IDs are hardcoded per script - create new scripts for additional devices
- Error notification email address can be modified in the `error_notification` action

---

## Related Documentation

- NinjaRMM API Documentation: Device Management endpoints
- Rewst Webhook Triggers: Best practices and configuration
- PowerShell Invoke-RestMethod: Error handling and JSON formatting

---

**Author:** Bryan Faulkner  
**Company:** Quality Computer Solutions  
**Created:** 2026-02-02  
**Last Updated:** 2026-02-02
