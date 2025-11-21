# Complete Script Inventory

**Repository:** https://github.com/ShadowA2J/it-automation-tools  
**Last Updated:** November 21, 2025  
**Maintained By:** Bryan Faulkner

---

## 📊 Status Overview

| Category | Scripts | Status |
|----------|---------|--------|
| PowerShell Scripts | 13+ | Mixed |
| Rewst Templates | 4+ | Active |
| Email Templates | 2 | Active |
| Documentation | 2+ | Active |

---

## ✅ Scripts Currently in Repository

### Active Directory Management
**Location:** `/AD_User_Export_Import_Tools/`
- **Export-ADUsersFromOU.ps1** - Export AD users from specific OU to CSV
- **Import-ADUsersFromCSV.ps1** - Bulk import AD users from CSV

### File & Network Share Management
**Location:** `/file_management/`
- **Get-NCRFolderInventory.ps1** - Scan and inventory NCR folders
- **Move-FilesWithFuzzyMatching.ps1** - Intelligent file reorganization with fuzzy matching
- **Get-TopLevelFolderReport.ps1** v1.2.0 - Network share folder reporting with size analysis
- **Move-OldFoldersToArchive.ps1** v1.0.0 - Archive old folders based on modification date
- **Fix-Windows11-PDFPreview.ps1** - Fix Windows 11 PDF preview issues (in subfolder)

### Printer Management
**Location:** `/printer_management/`
- **Remove-ZebraPrintDrivers.ps1** - Comprehensive Zebra driver cleanup

### Permissions Management
**Location:** `/permissions/`
- **Get-FolderPermissionsAudit.ps1** v2.0.0 - Network share permissions audit with CSV/HTML output

### Terminal Services
**Location:** `/terminal_services/`
- **Invoke-RDUserLogoff-Multi.ps1** - Remote Desktop session management

### Office/M365
**Location:** `/Office_M365/`
- **Reset-OfficeAndTeams.ps1** - Reset Office and Teams installations

### NinjaRMM Scripts
**Location:** `/ninja-scripts/`
- **DellCommandUpdate.ps1** v1.0.0 - Automated Dell firmware and driver updates via Dell Command Update
- **Uninstall-OldPolyWorksReviewer.ps1** v1.0 - Remove older PolyWorks Reviewer versions
- **OneDrive-KFM-Deployment/** v1.0.0 - Complete OneDrive Business KFM deployment package:
  - **Setup-OneDriveKFM-MachinePolicy.ps1** - Machine-level policies (run as SYSTEM)
  - **Setup-OneDriveBusinessKFM.ps1** - User-context setup (run as logged-in user)

### Rewst Workflow Templates
**Location:** `/rewst_workflows/`

#### Uplift Michigan Online School
- **Student-Guardian-Data-Parser.jinja** - Skyward API data parsing
- **Accelerate-Account-Status-Report.html** - Account creation status reporting

#### Integration Guides
- HaloPSA Custom Field Mapping
- Skyward OneRoster API Integration
- Email-to-Workflow Trigger Configuration
- Student ID Extraction from Emails

### Email Templates
**Location:** `/email_templates/`

#### Uplift Michigan Online School
- **UMOS-Welcome-Email.html** - Student onboarding welcome
- **UMOS-Chromebook-Shipping.html** - Chromebook shipping notification

### Documentation
**Location:** `/documentation/`
- **Barcode-Troubleshooting-Guide.md** - Crystal Reports barcode issue resolution
- Various README files per category

---

## 🔍 Scripts Identified But Not Yet Added

### From Conversation History

#### File Management
- **Move-SpecificFolders.ps1** - Move folders by exact name match
- **Export-DirectoryListing.ps1** - Export directory listings

#### Printer Management
- **Install-PrinterDriverFromSharePoint.ps1** - Download and install printer drivers from SharePoint
- **Deploy-PrintersByGroup.ps1** - Printer deployment for Terminal Services

#### System Administration
- **Move-OffScreenWindows.ps1** - Reposition off-screen windows
- **Install-Font.ps1** - Install fonts system-wide
- **Monitor-FolderAndChangePermissions.ps1** - File change monitoring with ACL updates

#### Documentation
- System Maintenance Notification Template
- Microsoft Tenant Security Policy
- Various troubleshooting guides

---

## 📂 Folder Structure

```
it-automation-tools/
├── AD_User_Export_Import_Tools/  # Active Directory user management
├── permissions/                   # Network share permission auditing
├── file_management/               # File, folder, and network share management
├── printer_management/            # Printer driver and deployment tools
├── terminal_services/             # Remote Desktop and terminal server utilities
├── Office_M365/                   # Office and Teams management
├── rewst_workflows/               # Rewst workflow automation templates
├── email_templates/               # HTML email templates
└── documentation/                 # Technical documentation and guides
```

---

## 📈 Version Control Strategy

### Semantic Versioning
- **MAJOR.MINOR.PATCH** format
- MAJOR: Breaking changes to parameters or functionality
- MINOR: New features, backward compatible
- PATCH: Bug fixes, documentation updates

### Status Legend
- ✅ **Complete** - Fully versioned and documented
- ⚠️ **Needs Work** - Functional but needs versioning/cleanup
- 📝 **Documentation** - Guide or reference material
- 🚧 **In Progress** - Currently being developed
- ⏳ **Planned** - Identified but not yet started

---

## 🎯 Repository Goals

### Short Term (1-2 weeks)
- [x] Complete folder reorganization with underscores
- [x] Merge network share management into file management
- [x] Rename folders for clarity (terminal_services, printer_management)
- [ ] Add all identified scripts from conversation history
- [ ] Update all README documentation
- [ ] Create usage examples for each script

### Medium Term (1-3 months)
- [ ] Create automated testing framework
- [ ] Add script templates for new development
- [ ] Build script dependency documentation
- [ ] Create video tutorials

### Long Term (3+ months)
- [ ] PowerShell module packaging
- [ ] CI/CD pipeline for testing
- [ ] Community contributions welcome
- [ ] Integration with other automation platforms

---

## 📋 Recent Changes

### November 21, 2025
- Added OneDrive-KFM-Deployment package to ninja-scripts
  - Machine policy script for SYSTEM context
  - User context script for login triggers
  - Auto tenant ID discovery, silent SSO, KFM enforcement
- Updated ninja-scripts README

### November 18, 2025
- Merged `network_share_management` folder into `file_management`
- Renamed `powershell_utilities` to `terminal_services`
- Renamed `network_tools` to `printer_management`
- Updated all documentation to reflect new structure
- Consolidated duplicate inventory files
- Standardized folder naming with underscores

---

## 📋 Next Steps

### Immediate
- [x] Consolidate inventory files
- [x] Rename all folders to use underscores
- [x] Merge network share management scripts
- [ ] Add remaining scripts from conversation history
- [ ] Update individual folder README files

### Future
- [ ] Extract and version all unversioned scripts
- [ ] Create API specification files (Skyward, USPS, etc.)
- [ ] Document common HaloPSA automation rules
- [ ] Add PowerShell module requirements documentation

---

**Inventory Version:** 3.2  
**Last Updated:** November 21, 2025  
**Maintained By:** Bryan Faulkner
