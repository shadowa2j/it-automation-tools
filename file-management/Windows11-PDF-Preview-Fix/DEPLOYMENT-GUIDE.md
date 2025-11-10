# Windows 11 PDF Preview Fix - Deployment Guide

## Overview
This script fixes the "file you are attempting to preview could harm your computer" error in Windows File Explorer caused by Windows Update KB5066835 (October 2025).

**Version:** 1.0.0  
**Last Updated:** 2025-11-10  
**Author:** IT Automation Tools

---

## What the Script Does

### 1. Registry Modification
- Creates/modifies: `HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Attachments`
- Sets `SaveZoneInformation = 1` to prevent future downloads from being blocked
- This is a **per-user** setting and must run in user context

### 2. File Unblocking
- Recursively scans specified folders for blocked files
- Removes the "Zone.Identifier" alternate data stream from files
- Supports multiple scan scopes (see Parameters section)

### 3. Windows Explorer Restart
- Restarts Windows Explorer to apply registry changes immediately
- Can be skipped if desired

---

## Deployment Methods

### Method 1: Ninja RMM Scripted Automation (Recommended)

**Setup in Ninja RMM:**

1. **Create New Automation Script**
   - Go to Administration > Automation > Scripting
   - Click "Add" > "New Script"
   - Name: `Fix Windows 11 PDF Preview Issue`
   - Type: PowerShell
   - Category: Remediation

2. **Script Settings**
   - Runtime: **Run as Logged on User** (for HKCU registry access)
   - Timeout: 30 minutes (for large file scans)
   - Save output: Yes

3. **Paste Script Content**
   - Copy entire `Fix-Windows11-PDFPreview.ps1` content
   - Paste into Ninja script editor

4. **Configure Parameters** (Optional)
   ```
   -ScanScope "UserFoldersAndShares"
   ```

5. **Deployment Options**
   - **Option A:** Deploy to specific devices/groups
   - **Option B:** Create scheduled automation
   - **Option C:** Add to onboarding/maintenance policies

---

### Method 2: Ninja RMM Custom Field Monitoring

Create custom fields to track deployment status:

| Field Name | Type | Value Source |
|------------|------|--------------|
| PDFFixApplied | Checkbox | Script Output |
| PDFFixVersion | Text | Script Output |
| PDFFixDate | Date | Script Output |
| PDFFixFilesProcessed | Number | Script Output |
| PDFFixFilesUnblocked | Number | Script Output |
| PDFFixErrors | Number | Script Output |

The script automatically outputs these values for Ninja to capture.

---

### Method 3: Manual Execution

For IT staff running manually:

```powershell
# Download script
cd C:\Temp

# Run with default settings (user folders only)
.\Fix-Windows11-PDFPreview.ps1

# Run with network shares included
.\Fix-Windows11-PDFPreview.ps1 -ScanScope UserFoldersAndShares

# Run on all drives and network shares
.\Fix-Windows11-PDFPreview.ps1 -ScanScope AllDrivesAndShares

# Run with custom paths
.\Fix-Windows11-PDFPreview.ps1 -ScanScope Custom -CustomPaths "D:\SharedFiles","\\server\documents"

# Skip Explorer restart (useful for remote sessions)
.\Fix-Windows11-PDFPreview.ps1 -SkipExplorerRestart
```

---

## Parameters Reference

### -ScanScope
Defines which areas to scan for blocked files:

| Value | Description | Use Case |
|-------|-------------|----------|
| `UserFolders` | Downloads, Documents, Desktop only | Default, fastest option |
| `UserFoldersAndShares` | User folders + mapped network drives | **Recommended for most deployments** |
| `AllDrives` | All local drives (C:, D:, etc.) | Deep clean of local system |
| `AllDrivesAndShares` | Everything including network shares | Comprehensive fix |
| `Custom` | Specific paths you define | Targeted deployment |

### -CustomPaths
Array of custom folder paths to scan (used with `-ScanScope Custom`)

**Example:**
```powershell
-CustomPaths "D:\CompanyFiles","\\fileserver\public","\\fileserver\HR"
```

### -SkipExplorerRestart
Switch parameter to skip Windows Explorer restart

**Use when:**
- Remote session where Explorer restart might disconnect you
- User is actively working and you want to minimize disruption
- Running during non-business hours where reboot is scheduled

### -LogPath
Custom log file location

**Default:** `C:\ProgramData\NinjaRMM\Logs\PDF-Preview-Fix.log`

**Example:**
```powershell
-LogPath "C:\Logs\CustomLocation\PDFFix.log"
```

---

## Ninja RMM Deployment Examples

### Example 1: Quick Fix for End Users
**Goal:** Fix user folders only, minimal disruption

```powershell
.\Fix-Windows11-PDFPreview.ps1
```

**Runtime:** 2-5 minutes  
**Runtime Context:** Logged on User  
**Best For:** Individual user remediation

---

### Example 2: Comprehensive Fix with Network Shares
**Goal:** Fix user folders and all mapped network drives

```powershell
.\Fix-Windows11-PDFPreview.ps1 -ScanScope UserFoldersAndShares
```

**Runtime:** 5-15 minutes  
**Runtime Context:** Logged on User  
**Best For:** Standard enterprise deployment

---

### Example 3: Manufacturing Environment
**Goal:** Fix specific shared production folders

```powershell
.\Fix-Windows11-PDFPreview.ps1 -ScanScope Custom -CustomPaths "\\prismserver\production","\\prismserver\quality","D:\LocalSpecs"
```

**Runtime:** Varies by folder size  
**Runtime Context:** Logged on User  
**Best For:** Prism Plastics, Wilbert Plastics, Marmon Plastics

---

### Example 4: Silent Deployment (No Explorer Restart)
**Goal:** Apply fix without interrupting user

```powershell
.\Fix-Windows11-PDFPreview.ps1 -ScanScope UserFoldersAndShares -SkipExplorerRestart
```

**Runtime:** 5-15 minutes  
**Runtime Context:** Logged on User  
**Best For:** During business hours, will take effect on next login

---

## Exit Codes

| Code | Meaning | Action Required |
|------|---------|-----------------|
| 0 | Success | None |
| 1 | Not running as Administrator | Check Ninja execution context |
| 2 | Not Windows 11 | Skip deployment for this device |
| 3 | Multiple errors occurred | Review log file |
| 99 | Critical error | Check Ninja output and logs |

---

## Log Files

**Default Location:** `C:\ProgramData\NinjaRMM\Logs\PDF-Preview-Fix.log`

**Log Contents:**
- Timestamp for each operation
- Registry modification results
- Files scanned and unblocked counts
- Error details with file paths
- Summary statistics

**Sample Log Entry:**
```
================================================================================
[2025-11-10 14:23:15] [INFO] Windows 11 PDF Preview Fix - v1.0.0
================================================================================
Computer: DESKTOP-ABC123
User: jsmith
Scan Scope: UserFoldersAndShares
================================================================================
[2025-11-10 14:23:15] [SUCCESS] OS Validation: Windows 11 (Build 22631) - OK
[2025-11-10 14:23:15] [SUCCESS] Administrator Check: Running as Administrator - OK
[2025-11-10 14:23:15] [INFO] === STEP 1: Configuring Registry ===
[2025-11-10 14:23:15] [SUCCESS] Set registry value: SaveZoneInformation = 1
[2025-11-10 14:23:16] [INFO] === STEP 2: Unblocking Existing Files ===
[2025-11-10 14:23:16] [INFO] Will scan 4 path(s)
[2025-11-10 14:23:16] [INFO]   - C:\Users\jsmith\Downloads
[2025-11-10 14:23:16] [INFO]   - C:\Users\jsmith\Documents
[2025-11-10 14:23:16] [INFO]   - C:\Users\jsmith\Desktop
[2025-11-10 14:23:16] [INFO]   - Z:\
[2025-11-10 14:23:16] [INFO] Scanning path: C:\Users\jsmith\Downloads
[2025-11-10 14:23:18] [INFO] Found 342 files to check in C:\Users\jsmith\Downloads
[2025-11-10 14:23:25] [SUCCESS] Path: C:\Users\jsmith\Downloads - Processed: 342 | Unblocked: 18 | Skipped: 324 | Errors: 0
[2025-11-10 14:23:25] [SUCCESS] Total files unblocked: 18
[2025-11-10 14:23:25] [INFO] === STEP 3: Restart Windows Explorer ===
[2025-11-10 14:23:28] [SUCCESS] Windows Explorer restarted successfully
================================================================================
[2025-11-10 14:23:28] [SUCCESS] SCRIPT EXECUTION COMPLETED
================================================================================
```

---

## Monitoring & Reporting

### Create Ninja RMM Alert Conditions

**Condition 1: Deployment Success**
- Trigger: `PDFFixApplied = True`
- Action: Tag device as "PDF Fix Applied"
- Notification: None

**Condition 2: Errors Detected**
- Trigger: `PDFFixErrors > 5`
- Action: Create ticket
- Notification: Email IT team

**Condition 3: Files Unblocked**
- Trigger: `PDFFixFilesUnblocked > 0`
- Action: Update dashboard
- Notification: None (informational)

### Dashboard Widgets

Create custom dashboard to track deployment:
- Total devices fixed
- Devices with errors
- Total files unblocked across organization
- Last run date per device

---

## Troubleshooting

### Issue: Script fails with "Not running as Administrator"
**Solution:** Change Ninja script to run as "Logged on User" (not SYSTEM)

### Issue: Registry change doesn't apply
**Cause:** HKCU registry requires user context
**Solution:** Ensure script runs as logged on user, not SYSTEM account

### Issue: Network shares not found
**Cause:** Mapped drives are user-specific
**Solution:** Script must run in user context; verify user has mapped drives

### Issue: Script times out
**Cause:** Large file scans (hundreds of thousands of files)
**Solution:** 
- Increase Ninja timeout to 60 minutes
- Use more targeted ScanScope
- Use Custom scope with specific paths

### Issue: Explorer restart disconnects remote session
**Solution:** Use `-SkipExplorerRestart` parameter

### Issue: Files still show preview warning after running
**Solutions:**
1. Restart computer (most effective)
2. Log off and log back on
3. Verify registry change applied: Check `HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Attachments\SaveZoneInformation` = 1
4. Consider uninstalling KB5066835 if issue persists

---

## Security Considerations

### What Gets Modified
✅ **User Registry (HKCU)** - Per-user settings only  
✅ **File Alternate Data Streams** - Removes Zone.Identifier  
❌ **System Files** - Not modified  
❌ **System Registry (HKLM)** - Not modified  

### Permissions Required
- **Administrator rights** - Required to unblock files in system folders
- **User context** - Required for HKCU registry access
- **File system access** - Standard read/write to user folders

### Compliance
- Does not modify Group Policy
- Does not disable Windows security features
- Only removes "Mark of the Web" from existing files
- Registry change is Microsoft-documented setting

---

## Rollback Procedure

To revert changes if needed:

```powershell
# Remove registry setting
Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Attachments" -Name "SaveZoneInformation" -Force

# Note: Files that were unblocked cannot be automatically re-blocked
# They would need to be re-downloaded to restore Zone.Identifier
```

---

## Related KB Articles & Resources

- **KB5066835** - Windows Update causing PDF preview issue (October 2025)
- **Microsoft Docs** - SaveZoneInformation registry setting
- **NTFS Alternate Data Streams** - Zone.Identifier documentation

---

## Support & Maintenance

**Repository:** https://github.com/ShadowA2J/it-automation-tools  
**Script Version:** 1.0.0  
**Compatibility:** Windows 11 only (Build 22000+)  
**PowerShell Version:** 5.1 or higher

**Change Log:**
- v1.0.0 (2025-11-10) - Initial release with Ninja RMM support

---

## Recommended Deployment Strategy

### Phase 1: Pilot Group (Week 1)
- Deploy to IT team first (5-10 devices)
- Use `-ScanScope UserFoldersAndShares`
- Monitor logs and exit codes
- Verify fix effectiveness

### Phase 2: Department Rollout (Week 2-3)
- Deploy to one department at a time
- Use `-ScanScope UserFoldersAndShares`
- Create Ninja automation policy
- Monitor for issues

### Phase 3: Organization-Wide (Week 4+)
- Add to maintenance/onboarding policies
- Schedule for new Windows 11 deployments
- Include in quarterly maintenance scripts

---

## Questions or Issues?

If you encounter issues with this script:

1. Check the log file at `C:\ProgramData\NinjaRMM\Logs\PDF-Preview-Fix.log`
2. Review Ninja RMM script output for error messages
3. Verify script parameters are correct for your environment
4. Check exit code for specific failure reasons

---

**Document Version:** 1.0  
**Last Updated:** November 10, 2025
