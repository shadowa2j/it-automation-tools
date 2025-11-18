# File & Network Share Management

**Category:** File System Operations & Network Share Administration  
**Author:** Bryan Faulkner, with assistance from Claude  
**Last Updated:** 2025-11-18

---

## 📋 Overview

This folder contains PowerShell scripts for file and folder management operations across local systems, network shares, and SharePoint Online. Includes tools for network share analysis, archiving, and folder restructuring.

---

## 📜 Scripts in This Folder

### Network Share Management

#### Get-TopLevelFolderReport.ps1
**Version:** 1.2.0  
**Purpose:** Recursively scans all folders and files under each top-level folder in a network share, identifies the newest `LastWriteTime`, and exports results to a timestamped CSV report.

**Features:**
- ✅ Recursive scanning of all files and folders
- ✅ Newest date detection from both files AND folders
- ✅ Folder size calculation (bytes, MB, GB)
- ✅ Progress indicators with real-time updates
- ✅ Comprehensive logging with error handling
- ✅ Sorted output by modification date
- ✅ CSV export for analysis

#### Move-OldFoldersToArchive.ps1
**Version:** 1.0.0  
**Purpose:** Reads the CSV report from Get-TopLevelFolderReport.ps1, identifies folders with modification dates older than 2024, and safely moves them to an archive location.

**Features:**
- ✅ Interactive CSV selection with file picker
- ✅ WhatIf mode for safe testing
- ✅ Confirmation prompts before moving
- ✅ Auto-create archive folder
- ✅ Date filtering (configurable cutoff)
- ✅ Conflict detection
- ✅ Detailed logging and progress tracking

### File Organization

#### Move-FilesWithFuzzyMatching.ps1
**Purpose:** Intelligent file reorganization with fuzzy part number matching for manufacturing environments.

**Features:**
- Fuzzy part number matching (ignores suffixes after second hyphen)
- Dry-run mode for testing
- Comprehensive logging
- File size tracking
- Identical file detection

#### Get-NCRFolderInventory.ps1
**Purpose:** Scan root\client\partnumber structure for NCR folders and export inventory.

**Features:**
- Recursive scanning
- File count and size reporting
- CSV export
- Error handling for inaccessible folders

### Windows Management

#### Windows11-PDF-Preview-Fix/
Complete solution for fixing Windows 11 PDF preview issues with deployment guides.

---

## 🎯 Common Use Cases

### Network Share Administration
- Storage cleanup planning and archiving
- Identify stale data for compliance
- Capacity planning and usage analysis
- Data lifecycle management

### Directory Operations
- Bulk folder creation and restructuring
- Directory tree comparison
- Folder permission management
- Path length validation

### File Operations
- Bulk file renaming with fuzzy matching
- File type conversions
- Metadata management
- Duplicate detection

### Monitoring & Reporting
- File system change monitoring
- Disk usage reports
- File age analysis
- Access tracking

---

## 🔒 Safety Features

All scripts include:
- ✅ Dry-run mode for testing
- ✅ Backup/rollback capabilities
- ✅ Comprehensive logging
- ✅ Error handling
- ✅ Confirmation prompts for destructive operations

---

## ⚠️ Best Practices

### Before Running:
1. **Backup:** Always backup before bulk operations
2. **Test:** Run in test environment first with WhatIf/DryRun modes
3. **Verify:** Check paths and parameters
4. **Log:** Enable detailed logging
5. **Monitor:** Watch initial execution closely

### During Execution:
- Monitor progress indicators
- Check logs for errors
- Verify results incrementally
- Be ready to stop if needed

### After Completion:
- Verify all changes
- Review logs for errors
- Document any issues
- Archive logs for reference

---

## 📞 Support

For file management issues:
- Review script logs
- Verify file/folder permissions
- Check available disk space
- Confirm network connectivity
- Test with small sample first

---

**PowerShell Version Required:** 5.1+  
**Common Modules Used:** SharePointPnPPowerShellOnline (when applicable)
