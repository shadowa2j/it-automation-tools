# Network Share Permissions Audit Script - Documentation

**Script Name:** Get-FolderPermissionsAudit.ps1  
**Version:** 2.0.0  
**Author:** Bryan Faulkner, with assistance from Claude  
**Last Updated:** 2025-11-06  
**PowerShell Version Required:** 5.1 or higher

---

## Overview
This PowerShell script performs a **READ-ONLY** comprehensive audit of network share permissions. It makes **NO CHANGES** to any files, folders, or permissions.

## Safety Verification ✓

### Read-Only Operations Confirmed:
- ✅ Uses only `Get-Acl` to READ permissions (never `Set-Acl`)
- ✅ Uses only `Get-Item` and `Get-ChildItem` to enumerate folders
- ✅ Uses only `Test-Path` to verify accessibility
- ✅ Only writes to OUTPUT files (CSV/HTML reports)
- ✅ NO modification cmdlets used (Set-Acl, Remove-Item, etc.)
- ✅ NO changes to inheritance settings
- ✅ NO changes to folder structure
- ✅ NO file modifications

### Cmdlets Used (All Read-Only):
- `Get-Acl` - Reads ACL information
- `Get-Item` - Gets folder objects
- `Get-ChildItem` - Enumerates subfolders
- `Test-Path` - Checks if path exists
- `Export-Csv` - Writes to report CSV file
- `Out-GridView` - Displays results in GUI
- `Out-File` - Writes to HTML report file only

## Features

### ✨ New Features in Version 2.0:
1. **HTML Report Generation** - Professional, formatted HTML reports with color-coding and statistics
2. **Account Filtering** - Filter results by specific account(s) with wildcard support

### Core Features:
- ✅ Multiple share scanning
- ✅ Unlimited recursion depth
- ✅ Progress indicators for large scans
- ✅ CSV export with all details
- ✅ GridView display
- ✅ Console output
- ✅ Unusual permission detection
- ✅ Inheritance status tracking
- ✅ Comprehensive error handling

## Usage Examples

### Basic Usage - Scan and Export to CSV:
```powershell
.\Get-FolderPermissionsAudit.ps1 -SharePaths "\\server\share1","\\server\share2"
```

### With GridView and Console Output:
```powershell
.\Get-FolderPermissionsAudit.ps1 -SharePaths "\\server\share1" -ShowGridView -ShowConsole
```

### With HTML Report:
```powershell
.\Get-FolderPermissionsAudit.ps1 -SharePaths "\\server\share1" -OutputHTML ".\AuditReport.html"
```

### Filter by Specific Account:
```powershell
# Single account with wildcard
.\Get-FolderPermissionsAudit.ps1 -SharePaths "\\server\share1" -FilterAccount "*admin*" -ShowGridView

# Multiple specific accounts
.\Get-FolderPermissionsAudit.ps1 -SharePaths "\\server\share1" -FilterAccount "DOMAIN\JohnDoe","Everyone" -ShowGridView

# Filter by domain
.\Get-FolderPermissionsAudit.ps1 -SharePaths "\\server\share1" -FilterAccount "DOMAIN\*" -OutputHTML ".\DomainPerms.html"
```

### Comprehensive Audit with All Outputs:
```powershell
.\Get-FolderPermissionsAudit.ps1 `
    -SharePaths "\\server\share1","\\server\share2","\\server\share3" `
    -OutputHTML ".\FullAudit.html" `
    -ShowGridView `
    -ShowConsole
```

### Custom Output Locations:
```powershell
.\Get-FolderPermissionsAudit.ps1 `
    -SharePaths "\\server\share1" `
    -OutputCSV "C:\Audits\Permissions_$(Get-Date -Format 'yyyy-MM-dd').csv" `
    -OutputHTML "C:\Audits\Permissions_$(Get-Date -Format 'yyyy-MM-dd').html"
```

## Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| SharePaths | string[] | Yes | - | Array of network share UNC paths |
| OutputCSV | string | No | .\PermissionsAudit_[timestamp].csv | CSV output file path |
| OutputHTML | string | No | "" (disabled) | HTML report file path |
| ShowGridView | switch | No | False | Display results in GridView |
| ShowConsole | switch | No | False | Display results in console |
| FilterAccount | string[] | No | @() (no filter) | Filter by account name(s), supports wildcards |

## Output Files

### CSV File Contents:
- SharePath
- FolderPath
- RelativePath
- Account
- Rights (readable format)
- RawRights (detailed format)
- AccessType (Allow/Deny)
- PermissionType (Inherited/Explicit)
- InheritanceDisabled (True/False)
- InheritanceFlags
- PropagationFlags
- IsUnusual (True/False)
- UnusualReason
- Owner
- ScanDate

### HTML Report Contents:
- Executive summary with statistics
- List of scanned shares
- Unusual permissions table (color-coded)
- Folders with disabled inheritance
- Complete permissions table with filtering and sorting
- Color-coded entries (unusual permissions highlighted)

## Unusual Permission Detection

The script flags the following as unusual:
- ✓ Everyone with FullControl, Modify, or Write permissions
- ✓ Users group with Full Control
- ✓ Authenticated Users with Full Control
- ✓ Any Deny permissions
- ✓ Guest account with any access

## Performance

- Handles thousands of folders efficiently
- Progress indicators show current status
- Error handling prevents script termination
- Inaccessible folders are logged but don't stop the scan

## Requirements

- PowerShell 5.1 or higher
- Account with read permissions to target shares
- No administrative privileges required (unless auditing protected folders)

## Error Handling

- Continues scanning even if some folders are inaccessible
- Logs errors for individual folder access failures
- Creates error entries in output for troubleshooting
- Does not terminate on errors

## Best Practices

1. **Test on a small share first** before scanning large environments
2. **Run during off-hours** for large scans to minimize network impact
3. **Use FilterAccount** when investigating specific security principals
4. **Review HTML reports** for easy identification of security issues
5. **Keep CSV files** for historical comparison and detailed analysis
6. **Schedule regular audits** to track permission changes over time

## Troubleshooting

### Access Denied Errors:
- Ensure your account has at least Read permissions to the share and folders
- Some system folders may require elevated privileges

### Slow Performance:
- Normal for shares with thousands of folders
- Progress indicators show current status
- Consider filtering or breaking into smaller share groups

### Empty Results:
- Verify share paths are correct (UNC format)
- Check that shares are accessible from your computer
- Ensure network connectivity

### FilterAccount Returns No Results:
- Verify the account name format matches what's in the ACLs
- Use wildcards for partial matches: "*admin*", "DOMAIN\*"
- Check the console output for the exact account names being scanned

## Security Notes

- This script is **READ-ONLY** and makes no modifications
- All operations are auditing/reporting only
- Script output may contain sensitive information - secure the reports appropriately
- Consider encrypting or restricting access to output files

## Version History

### Version 2.0.0 (2025-11-06):
- Added HTML report generation with professional formatting and color-coding
- Added account filtering capability with wildcard support
- Added comprehensive versioning throughout script and outputs
- Enhanced error handling and progress indicators
- Added unusual permission detection with multiple criteria
- Improved documentation with detailed examples

### Version 1.0.0 (2025-11-06):
- Initial release
- CSV export with comprehensive permission details
- GridView and console output support
- Multi-share scanning capability with progress indicators
- Inheritance status tracking

---

## Change Log Format

All notable changes to this script will be documented using semantic versioning (MAJOR.MINOR.PATCH):
- **MAJOR**: Breaking changes or significant functionality overhaul
- **MINOR**: New features added in a backward-compatible manner
- **PATCH**: Backward-compatible bug fixes

## Support

For issues or questions, review the console output for error messages and verify:
1. Share paths are accessible
2. Account has sufficient permissions
3. Network connectivity is stable
4. Output directory is writable

---

**Remember: This script is completely safe - it only READS permissions and creates reports. It makes NO changes to your files, folders, or security settings.**
