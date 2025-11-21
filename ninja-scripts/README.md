# NinjaRMM Scripts

Scripts specifically optimized for deployment through NinjaRMM automation platform.

## Overview

This folder contains PowerShell scripts that have been enhanced for reliability in NinjaRMM environments, including:
- Improved error handling and logging
- Event log integration for better monitoring
- Timeout handling for network operations
- Exit code management for NinjaRMM status tracking
- SYSTEM account compatibility

## Scripts

### DellCommandUpdate.ps1
**Version:** 1.0.0  
**Purpose:** Automate Dell firmware and driver updates via Dell Command Update  
**Modified:** November 19, 2025

#### What it does:
1. Verifies the system is a Dell device
2. Removes incompatible Dell Update applications
3. Installs/upgrades .NET Desktop Runtime (dependency)
4. Installs/upgrades Dell Command Update to latest version
5. Configures DCU for automatic updates
6. Scans for and applies all available Dell updates

#### Key Features:
- **Enhanced Logging:** Writes to both stdout and Windows Event Log
- **Error Resilience:** Comprehensive error handling with graceful fallbacks
- **Network Reliability:** 30-300 second timeouts on all web requests
- **Version Intelligence:** Proper version comparison logic with fallback versions
- **NinjaRMM Compatible:** Works reliably under SYSTEM account context
- **Exit Codes:** Proper exit codes for NinjaRMM monitoring

#### Usage in NinjaRMM:

**As a Scheduled Script:**
```
Schedule Type: Daily/Weekly
Run As: SYSTEM
Timeout: 60 minutes (Dell updates can take time)
```

**As an Automation Policy:**
```
Trigger: Device Check-in
Condition: Manufacturer = Dell
Run As: SYSTEM
```

#### Exit Codes:
- `0` - Success (updates completed or not needed)
- `1` - Error occurred (check logs for details)
- `500` - DCU reports no updates available (success)

#### Logging:
- Console output captured by NinjaRMM
- Windows Event Log: Application → Source: "DellCommandUpdate"
- Event IDs: 1000 (all events)

#### Requirements:
- PowerShell 5.1 or higher
- Internet connectivity to Dell and Microsoft servers
- Administrative privileges (SYSTEM account)
- Sufficient disk space in %TEMP% for installers

#### Troubleshooting:

**Script fails to download:**
- Check internet connectivity
- Verify Dell/Microsoft URLs are not blocked by firewall
- Check proxy settings if applicable

**Version not detected after install:**
- Wait 1-2 minutes and re-run (registry may need time to update)
- Check Windows Event Log for detailed error messages

**DCU fails to apply updates:**
- Some updates may require reboot before applying others
- Check BitLocker status (script auto-suspends BitLocker)
- Review DCU logs at: `C:\ProgramData\Dell\CommandUpdate\log`

## Development Notes

### Modifications from Original:
- Added `Write-Log` function with dual output (console + event log)
- Enhanced error handling with try/catch blocks
- Added timeout parameters to all `Invoke-WebRequest` calls
- Improved version comparison using `[version]` casting
- Added fallback versions for offline scenarios
- Better null/empty validation throughout
- PassThru on Start-Process for exit code capture
- Enhanced path resolution for DCU CLI detection

### Testing Recommendations:
1. Test on a Dell device first
2. Monitor first run closely via NinjaRMM
3. Check Windows Event Log after completion
4. Verify DCU installation in Programs and Features
5. Confirm updates applied via Dell Command Update UI

### Uninstall-OldPolyWorksReviewer.ps1
**Version:** 1.0  
**Purpose:** Remove older versions of PolyWorks Reviewer, keeping only the newest  
**Modified:** November 21, 2025

#### What it does:
1. Scans both 32-bit and 64-bit registry uninstall keys
2. Finds all installed PolyWorks Reviewer versions (InnovMetric)
3. Compares version numbers (e.g., 25.3.2628 > 24.3.3048)
4. Keeps the highest version, silently uninstalls all others
5. Handles both MSI and EXE-based uninstallers

#### Key Features:
- **Dynamic Detection:** Automatically finds newest version - no hardcoding needed
- **Version Comparison:** Uses actual version numbers, not product year names
- **Multiple Uninstall Methods:** Supports MSI, QuietUninstallString, and EXE with silent switches
- **Safe:** Only removes older versions, never the newest
- **NinjaRMM Compatible:** Works under SYSTEM account context

#### Usage in NinjaRMM:

**As a Scheduled Script:**
```
Schedule Type: After software deployment or Weekly cleanup
Run As: SYSTEM
Timeout: 15 minutes
```

#### Exit Codes:
- `0` - Success (older versions removed or nothing to remove)

#### Requirements:
- PowerShell 5.1 or higher
- Administrative privileges (SYSTEM account)
- At least one version of PolyWorks Reviewer installed

---

## Contributing

When adding scripts to this folder:
1. Ensure compatibility with SYSTEM account context
2. Add comprehensive error handling
3. Include event log integration
4. Use appropriate timeouts for network operations
5. Document exit codes clearly
6. Test thoroughly in NinjaRMM before deployment

## Support

For issues specific to NinjaRMM deployment:
- Check NinjaRMM activity log for script output
- Review Windows Event Log for detailed errors
- Verify script permissions and timeout settings
- Test manually under SYSTEM account using PSExec

---

**Folder Version:** 1.0.0  
**Last Updated:** November 19, 2025  
**Maintained By:** Bryan Faulkner
