# Permissions Management Scripts

**Category:** Network Share Permissions & Security Auditing  
**Author:** Bryan Faulkner, with assistance from Claude  
**Last Updated:** 2025-11-06

---

## 📋 Overview

This folder contains scripts for auditing, analyzing, and managing NTFS permissions across network shares and file systems.

---

## 🔧 Available Scripts

### Get-FolderPermissionsAudit.ps1
**Version:** 2.0.0  
**Purpose:** Comprehensive read-only audit of network share permissions

**Features:**
- Multi-share scanning with unlimited recursion depth
- CSV and HTML report generation
- GridView and console output options
- Account filtering with wildcard support
- Unusual permission detection
- Inheritance status tracking
- Progress indicators for large scans

**Usage:**
```powershell
# Basic audit
.\Get-FolderPermissionsAudit.ps1 -SharePaths "\\server\share1"

# Full featured audit
.\Get-FolderPermissionsAudit.ps1 `
    -SharePaths "\\server\share1","\\server\share2" `
    -OutputHTML ".\AuditReport.html" `
    -ShowGridView `
    -ShowConsole

# Filter by account
.\Get-FolderPermissionsAudit.ps1 `
    -SharePaths "\\server\share1" `
    -FilterAccount "*admin*","Everyone" `
    -ShowGridView
```

**Output Files:**
- CSV: Detailed permission entries with all metadata
- HTML: Professional formatted report with color-coding
- GridView: Interactive sortable/filterable display

**Safety:** ✅ READ-ONLY - Makes no changes to permissions or folders

---

## 🎯 Common Use Cases

### Security Audits
- Identify overly permissive access (Everyone, Authenticated Users)
- Find folders with inheritance disabled
- Track explicit vs inherited permissions
- Detect unusual permission patterns

### Compliance
- Document permission structures
- Generate audit reports for review
- Track changes over time (compare reports)
- Verify least-privilege access

### Troubleshooting
- Investigate access issues
- Verify group membership effects
- Identify permission conflicts
- Debug inheritance problems

### Migration Planning
- Document current state before changes
- Compare source and destination permissions
- Verify post-migration permissions
- Create permission baselines

---

## 📊 Output Examples

### CSV Columns:
- SharePath, FolderPath, RelativePath
- Account, Rights, RawRights
- AccessType (Allow/Deny)
- PermissionType (Inherited/Explicit)
- InheritanceDisabled, InheritanceFlags, PropagationFlags
- IsUnusual, UnusualReason
- Owner, ScanDate

### HTML Report Sections:
- Executive summary with statistics
- Scanned shares list
- Unusual permissions table (highlighted)
- Folders with disabled inheritance
- Complete permissions table

---

## ⚠️ Important Notes

### Before Running:
1. Verify you have read access to target shares
2. Consider scan scope (thousands of folders = longer runtime)
3. Choose output location with sufficient space
4. Test on small share first

### Security Considerations:
- Reports may contain sensitive information
- Secure output files appropriately
- Consider encrypting archived reports
- Limit access to audit results

### Performance Tips:
- Run during off-hours for large scans
- Use FilterAccount to reduce output size
- Break large environments into multiple runs
- Monitor network utilization

---

## 🔄 Version History

### 2.0.0 (2025-11-06)
- Added HTML report generation
- Added account filtering
- Enhanced versioning
- Improved documentation

### 1.0.0 (2025-11-06)
- Initial release
- CSV export
- GridView support
- Progress indicators

---

## 📞 Support

For issues:
1. Check console output for errors
2. Verify share accessibility
3. Confirm account permissions
4. Review documentation

---

**Scripts in this folder:** 1  
**Total Lines of Code:** ~700  
**PowerShell Version Required:** 5.1+
