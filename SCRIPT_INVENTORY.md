# Script Inventory - All Scripts from Conversations

**Generated:** 2025-11-06  
**Author:** Bryan Faulkner, with assistance from Claude  
**Total Scripts Found:** 15+

---

## 📊 Summary by Category

### ✅ Permissions Management (1 script)
- Get-FolderPermissionsAudit.ps1 v2.0.0 - COMPLETE

### 📁 File Management (4 scripts)
- Move-FilesWithFuzzyMatching.ps1 - File/folder moving with fuzzy part number matching
- Get-NCRFolderInventory.ps1 - NCR folder scanner and inventory  
- Move-SpecificFolders.ps1 - Move folders by exact name match
- Export-DirectoryListing.ps1 - Export directory listings

### 🖥️ Network & System Tools (6 scripts)
- Remove-ZebraPrintDrivers.ps1 - Forcibly remove Zebra print drivers
- Move-OffScreenWindows.ps1 - Reposition off-screen windows
- Install-Font.ps1 - Install fonts system-wide
- Install-PrinterDriverFromSharePoint.ps1 - Download and install printer drivers
- Monitor-FolderAndChangePermissions.ps1 - File change monitoring with ACL updates
- Deploy-PrintersByGroup.ps1 - Printer deployment for Terminal Services

### 🔄 Rewst Workflow Integration (4+ workflows/guides)
- HaloPSA Custom Field Mapping Guide
- Skyward OneRoster API Integration Setup
- Email-to-Workflow Trigger Configuration  
- Student ID Extraction from Emails

### 📝 Documentation & Templates
- System Maintenance Notification Template
- Security Policy Documentation (Microsoft Tenant Access)
- Various troubleshooting guides

---

## 📋 Detailed Script List

### Permissions Management

#### 1. Get-FolderPermissionsAudit.ps1
**Version:** 2.0.0  
**Status:** ✅ Complete and versioned  
**Location:** Already in repository  
**Features:**
- Multi-share scanning
- CSV and HTML reports
- Account filtering
- Unusual permission detection
- Inheritance tracking

---

### File Management Scripts

#### 2. Move-FilesWithFuzzyMatching.ps1
**Status:** ⚠️ Needs versioning and cleanup  
**Purpose:** Move files between client/partnumber directory structures with fuzzy matching  
**Key Features:**
- Fuzzy part number matching (ignores suffixes after second hyphen)
- Dry-run mode for testing
- Comprehensive logging
- File size tracking
- Identical file detection

**Found In:** Chat "Molds to Prism Files Script"  
**Date:** 2025-10-22

#### 3. Get-NCRFolderInventory.ps1
**Status:** ⚠️ Needs versioning  
**Purpose:** Scan root\client\partnumber structure for NCR folders and export inventory  
**Key Features:**
- Recursive scanning
- File count and size reporting
- CSV export
- Error handling for inaccessible folders

**Found In:** Chat "Powershell script for NCR folder inventory"  
**Date:** 2025-10-20

#### 4. Move-SpecificFolders.ps1
**Status:** ⚠️ Needs completion and versioning  
**Purpose:** Move specific folders by exact name match from nested structures  
**Key Features:**
- Exact name matching
- Recursive search
- Collision detection
- Multiple folder support

**Found In:** Chat "Molds to Prism Files Script"  
**Date:** 2025-10-22

#### 5. Export-DirectoryListing.ps1
**Status:** ⚠️ Needs to be created as full script  
**Purpose:** Export directory listings to file  
**Notes:** Currently just command examples, should be made into proper script

**Found In:** Chat "Command Prompt Directory Listing Export"  
**Date:** 2025-07-16

---

### Network & System Administration Tools

#### 6. Remove-ZebraPrintDrivers.ps1
**Status:** ⚠️ Needs versioning and final testing  
**Purpose:** Forcibly remove all Zebra print drivers  
**Key Features:**
- Stops print spooler
- Clears print queues
- Removes printers, ports, and drivers
- Comprehensive cleanup
- Administrator privilege check

**Found In:** Chat "Removing zebra print drivers"  
**Date:** 2025-10-22

#### 7. Move-OffScreenWindows.ps1
**Status:** ⚠️ Needs versioning  
**Purpose:** Find and reposition windows that are off-screen  
**Key Features:**
- Win32 API integration
- Screen boundary detection
- Automatic repositioning
- Visible window filtering

**Found In:** Chat "PowerShell Window Repositioning Script"  
**Date:** 2025-08-20

#### 8. Install-Font.ps1
**Status:** ⚠️ Needs versioning  
**Purpose:** Install fonts system-wide  
**Key Features:**
- Administrator check
- Multiple font format support
- Registry registration
- COM object usage for installation

**Found In:** Chat "Command Prompt Directory Listing Export"  
**Date:** 2025-07-16

#### 9. Install-PrinterDriverFromSharePoint.ps1
**Status:** ⚠️ Needs versioning (multiple versions found)  
**Purpose:** Download and install printer drivers from SharePoint  
**Key Features:**
- SharePoint download
- ZIP extraction
- INF file detection
- pnputil integration

**Found In:** Multiple chats  
**Date:** Various (2024-11-14, 2025-03-19)

#### 10. Monitor-FolderAndChangePermissions.ps1
**Status:** ⚠️ Needs versioning  
**Purpose:** Monitor folders for changes and modify security permissions  
**Key Features:**
- FileSystemWatcher implementation
- Real-time monitoring
- ACL modification on file changes
- Logging

**Found In:** Chat "PowerShell File Change Security Monitor"  
**Date:** 2025-08-06

#### 11. Deploy-PrintersByGroup.ps1
**Status:** ⚠️ Needs to be created from code snippet  
**Purpose:** Deploy printers in Terminal Services by AD group  
**Key Features:**
- AD group membership check
- Conditional printer deployment
- No GPO required

**Found In:** Chat "Windows printer deployment methods"  
**Date:** 2025-10-23

---

### Rewst Workflow Integration

#### 12. HaloPSA Custom Field Mapping
**Status:** 📝 Documentation/Guide  
**Purpose:** Map Rewst workflow data to HaloPSA custom fields  
**Key Topics:**
- Custom field ID mapping
- JSON payload structure
- Jinja2 templating
- Troubleshooting common issues

**Found In:** Multiple chats including "Mapping Rewst workflow data to Halo custom fields"  
**Date:** 2025-11-03

#### 13. Skyward OneRoster API Integration
**Status:** 📝 Configuration Guide  
**Purpose:** Set up OAuth2 integration with Skyward OneRoster API  
**Key Topics:**
- OAuth2 configuration
- Token endpoint setup
- API action creation
- User data retrieval

**Found In:** Chat "API connection testing method"  
**Date:** 2025-10-28

#### 14. Email-to-Workflow Triggers
**Status:** 📝 Implementation Guide  
**Purpose:** Extract student IDs from HaloPSA emails and trigger Rewst workflows  
**Key Topics:**
- HaloPSA automation rules
- Regex for student ID extraction
- Webhook configuration
- Rewst workflow triggers

**Found In:** Multiple chats including "Extracting student ID from Halo PSA emails to Rewst"  
**Date:** 2025-10-29, 2025-10-30

#### 15. Rewst-to-Halo Ticket Updates
**Status:** 📝 Implementation Guide  
**Purpose:** Update HaloPSA tickets with custom field data from Rewst  
**Key Topics:**
- Custom fields array structure
- Update ticket action configuration
- Data alias usage
- Troubleshooting

**Found In:** Chat "Rewst to Halo ticket integration with custom fields"  
**Date:** 2025-10-30

---

### Additional Documentation & Templates

#### System Maintenance Notification Template
**Type:** Email Template  
**Purpose:** Professional system downtime notifications  
**Found In:** Chat "System maintenance notification improvements"  
**Date:** 2025-11-06

#### Microsoft Tenant Security Policy
**Type:** Policy Document  
**Purpose:** Guidance on third-party contractor access to Microsoft 365  
**Found In:** Chat "Restrict Third-Party Contractor Access to Microsoft Tenant"  
**Date:** 2025-03-13

---

## 🎯 Next Steps - Organizing Scripts

### Priority 1: Complete Core Scripts (Immediate)
1. ✅ Get-FolderPermissionsAudit.ps1 - Already done
2. ⚠️ Move-FilesWithFuzzyMatching.ps1 - Add versioning
3. ⚠️ Remove-ZebraPrintDrivers.ps1 - Add versioning
4. ⚠️ Get-NCRFolderInventory.ps1 - Add versioning

### Priority 2: Documentation (This Week)
1. Create README files for each category
2. Document Rewst integration workflows
3. Create setup guides

### Priority 3: Remaining Scripts (As Needed)
1. Complete and version remaining scripts
2. Test in appropriate environments
3. Add to repository

---

## 📝 Versioning Standards

All scripts will follow this format:
- **Version:** Semantic versioning (MAJOR.MINOR.PATCH)
- **Author:** Bryan Faulkner, with assistance from Claude
- **Date Created:** Original creation date
- **Date Modified:** Last modification date
- **Change Log:** Detailed version history

---

## 🔄 Status Legend

- ✅ **Complete** - Fully versioned and documented
- ⚠️ **Needs Work** - Functional but needs versioning/cleanup
- 📝 **Documentation** - Guide or reference material
- 🚧 **In Progress** - Currently being developed
- ⏳ **Planned** - Identified but not yet started

---

**Total Scripts to Process:** 11 PowerShell scripts + 4 workflow guides + 2 templates  
**Estimated Time to Complete All:** 3-4 hours of organization work  
**Current Status:** Beginning comprehensive organization
