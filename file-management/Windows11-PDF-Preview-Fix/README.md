# Windows 11 PDF Preview Fix

Fix the "file you are attempting to preview could harm your computer" error in Windows File Explorer caused by Windows Update KB5066835 (October 2025).

![Version](https://img.shields.io/badge/version-1.0.0-blue)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue)
![Windows](https://img.shields.io/badge/Windows-11-blue)
![License](https://img.shields.io/badge/license-MIT-green)

## 🚀 Quick Start

### For Ninja RMM Deployment
```powershell
# Recommended for most deployments
.\Fix-Windows11-PDFPreview.ps1 -ScanScope UserFoldersAndShares
```

### For Manual Execution
```powershell
# Run as Administrator
.\Fix-Windows11-PDFPreview.ps1
```

## 📥 Download

**[Download Latest Release (ZIP)](../../releases/latest)**

Or download individual files:
- [Fix-Windows11-PDFPreview.ps1](Fix-Windows11-PDFPreview.ps1) - Main script
- [DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md) - Full documentation
- [QUICK-REFERENCE.md](QUICK-REFERENCE.md) - Quick reference card

## 🎯 What It Does

This script performs three actions to fix PDF preview issues:

1. **Prevents Future Blocking**
   - Modifies Windows registry to stop marking downloaded files as dangerous
   - Sets `HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Attachments\SaveZoneInformation = 1`

2. **Unblocks Existing Files**
   - Removes Zone.Identifier alternate data stream from blocked files
   - Scans user folders, network shares, or custom paths
   - Processes files recursively with progress tracking

3. **Applies Changes**
   - Restarts Windows Explorer (optional)
   - Creates detailed logs at `C:\ProgramData\NinjaRMM\Logs\PDF-Preview-Fix.log`
   - Outputs status to Ninja RMM custom fields

## 🛠️ Features

- ✅ **Ninja RMM Integration** - Custom field outputs for monitoring
- ✅ **Comprehensive Logging** - Detailed timestamped logs
- ✅ **Flexible Scan Scopes** - User folders, network shares, entire drives, or custom paths
- ✅ **Error Handling** - Graceful handling of permission issues and locked files
- ✅ **Progress Tracking** - Visual progress for large file scans
- ✅ **Exit Codes** - Proper exit codes for automation workflows
- ✅ **Windows 11 Validation** - Ensures compatibility before running

## 📋 Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `-ScanScope` | Defines scan area: `UserFolders`, `UserFoldersAndShares`, `AllDrives`, `AllDrivesAndShares`, `Custom` | `UserFolders` |
| `-CustomPaths` | Array of custom paths when using `-ScanScope Custom` | None |
| `-SkipExplorerRestart` | Skip Windows Explorer restart | False |
| `-LogPath` | Custom log file path | `C:\ProgramData\NinjaRMM\Logs\PDF-Preview-Fix.log` |

## 💡 Usage Examples

### Standard Office Deployment
```powershell
# Scans Downloads, Documents, Desktop, and all mapped network drives
.\Fix-Windows11-PDFPreview.ps1 -ScanScope UserFoldersAndShares
```

### Manufacturing/Production Environment
```powershell
# Target specific shared folders
.\Fix-Windows11-PDFPreview.ps1 -ScanScope Custom -CustomPaths "\\fileserver\production","\\fileserver\quality","D:\Specs"
```

### Silent Deployment
```powershell
# No Explorer restart - useful during business hours
.\Fix-Windows11-PDFPreview.ps1 -ScanScope UserFoldersAndShares -SkipExplorerRestart
```

### Complete System Scan
```powershell
# Scan all local drives and network shares (may take 10+ minutes)
.\Fix-Windows11-PDFPreview.ps1 -ScanScope AllDrivesAndShares
```

## 🔧 Ninja RMM Setup

### Quick Setup (5 Minutes)

1. **Create New Script**
   - Go to: Administration > Automation > Scripting
   - Click: Add > New Script
   - Name: `Fix Windows 11 PDF Preview Issue`
   - Type: PowerShell

2. **Configure Settings**
   - Runtime: **Run as Logged on User** ⚠️ (Required for HKCU registry)
   - Timeout: 30 minutes
   - Save output: Yes

3. **Add Script Content**
   - Copy and paste `Fix-Windows11-PDFPreview.ps1`
   - Add parameter: `-ScanScope UserFoldersAndShares`

4. **Deploy**
   - Select devices or groups
   - Run script
   - Monitor exit codes

### Custom Fields for Monitoring

The script outputs these values for Ninja RMM:

| Field | Type | Description |
|-------|------|-------------|
| `PDFFixApplied` | Boolean | Whether fix was applied |
| `PDFFixVersion` | Text | Script version |
| `PDFFixDate` | Date | Date of last run |
| `PDFFixFilesProcessed` | Number | Total files checked |
| `PDFFixFilesUnblocked` | Number | Files that were unblocked |
| `PDFFixErrors` | Number | Error count |
| `PDFFixExitCode` | Number | Script exit code |

## 📊 Exit Codes

| Code | Meaning | Action |
|------|---------|--------|
| 0 | ✅ Success | None required |
| 1 | ❌ Not running as Administrator | Check execution context |
| 2 | ❌ Not Windows 11 | Skip device |
| 3 | ⚠️ Multiple errors occurred | Review log file |
| 99 | ❌ Critical error | Check Ninja output |

## 📝 Requirements

- **OS:** Windows 11 (Build 22000+)
- **PowerShell:** Version 5.1 or higher
- **Privileges:** Administrator rights
- **Context:** Must run as logged-on user (for HKCU registry access)

## 🔍 Troubleshooting

### Common Issues

**"Not running as Administrator" error**
- Solution: In Ninja RMM, set Runtime to "Run as Logged on User"

**Registry changes don't apply**
- Cause: Script running as SYSTEM instead of user
- Solution: Must run in user context to modify HKCU

**Network shares not found**
- Cause: Mapped drives are user-specific
- Solution: Ensure script runs as the logged-on user

**Script times out**
- Cause: Large number of files (100,000+)
- Solution: Increase timeout to 60 minutes or use targeted scan scope

**Still seeing preview warning**
- Solutions:
  1. Restart computer (most effective)
  2. Verify registry: `Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Attachments"`
  3. Check log file for errors
  4. Consider uninstalling KB5066835

## 📖 Documentation

- **[DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md)** - Complete deployment guide with Ninja RMM instructions
- **[QUICK-REFERENCE.md](QUICK-REFERENCE.md)** - One-page quick reference card

## 🔒 Security & Compliance

### What Gets Modified
- ✅ User Registry (HKCU) - Per-user settings only
- ✅ File Alternate Data Streams - Removes Zone.Identifier
- ❌ System Files - Not modified
- ❌ System Registry (HKLM) - Not modified

### Permissions Required
- Administrator rights (to unblock files)
- User context execution (for HKCU registry)
- File system read/write access

### Compliance Notes
- Does not modify Group Policy
- Does not disable Windows security features
- Only removes "Mark of the Web" from existing files
- Uses Microsoft-documented registry setting

## 🔄 Rollback

To revert changes if needed:

```powershell
# Remove registry setting
Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Attachments" -Name "SaveZoneInformation" -Force

# Note: Unblocked files cannot be automatically re-blocked
# They would need to be re-downloaded to restore Zone.Identifier
```

## 📅 Version History

### v1.0.0 (2025-11-10)
- Initial release
- Ninja RMM integration
- Multiple scan scope options
- Comprehensive logging
- Error handling and reporting
- Network share support
- Custom path support

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Original concept based on community fixes for KB5066835
- Optimized for Ninja RMM deployment
- Built for IT Automation Tools collection

## 📧 Support

For issues, questions, or suggestions:
- Open an issue in this repository
- Check the [DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md) for detailed troubleshooting

---

**Repository:** https://github.com/ShadowA2J/it-automation-tools  
**Script Version:** 1.0.0  
**Last Updated:** November 10, 2025

---

Made with ❤️ for IT professionals managing Windows 11 environments
