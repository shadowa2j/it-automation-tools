# Complete Script Inventory

**Repository:** https://github.com/ShadowA2J/it-automation-tools  
**Last Updated:** November 18, 2025  
**Maintained By:** Bryan Faulkner

---

## 📊 Status Overview

| Category | Scripts | Status |
|----------|---------|--------|
| PowerShell Scripts | 11+ | Mixed |
| Rewst Templates | 4+ | Active |
| Email Templates | 2 | Active |
| Documentation | 2+ | Active |

---

## ✅ Scripts Currently in Repository

### PowerShell Scripts

#### Active Directory Management
- **Export-ADUsersFromOU.ps1** - Export AD users from specific OU to CSV
- **Import-ADUsersFromCSV.ps1** - Bulk import AD users from CSV

#### File Management
- **Get-NCRFolderInventory.ps1** - Scan and inventory NCR folders
- **Move-FilesWithFuzzyMatching.ps1** - Intelligent file reorganization with fuzzy matching
- **Get-TopLevelFolderReport.ps1** - Network share folder reporting
- **Move-OldFoldersToArchive.ps1** - Archive old folders based on age

#### Network Tools
- **Remove-ZebraPrintDrivers.ps1** - Comprehensive Zebra driver cleanup

#### Permissions
- **Get-FolderPermissionsAudit.ps1** - Network share permissions audit with CSV/HTML output

#### PowerShell Utilities
- **Invoke-RDUserLogoff-Multi.ps1** - Remote Desktop session management

#### Office/M365
- **Reset-OfficeAndTeams.ps1** - Reset Office and Teams installations

#### Windows Management
- **Fix-Windows11-PDFPreview.ps1** - Fix Windows 11 PDF preview issues

### Rewst Workflow Templates

#### Uplift Michigan Online School
- **Student-Guardian-Data-Parser.jinja** - Skyward API data parsing
- **Accelerate-Account-Status-Report.html** - Account creation status reporting

#### Integration Guides
- HaloPSA Custom Field Mapping
- Skyward OneRoster API Integration
- Email-to-Workflow Trigger Configuration
- Student ID Extraction from Emails

### Email Templates

#### Uplift Michigan Online School
- **UMOS-Welcome-Email.html** - Student onboarding welcome
- **UMOS-Chromebook-Shipping.html** - Chromebook shipping notification

### Documentation
- **Barcode-Troubleshooting-Guide.md** - Crystal Reports barcode issue resolution
- Various README files per category

---

## 🔍 Scripts Identified But Not Yet Added

### From Conversation History

#### File Management
- **Move-SpecificFolders.ps1** - Move folders by exact name match
- **Export-DirectoryListing.ps1** - Export directory listings

#### Network & System Tools
- **Move-OffScreenWindows.ps1** - Reposition off-screen windows
- **Install-Font.ps1** - Install fonts system-wide
- **Install-PrinterDriverFromSharePoint.ps1** - Download and install printer drivers from SharePoint
- **Monitor-FolderAndChangePermissions.ps1** - File change monitoring with ACL updates
- **Deploy-PrintersByGroup.ps1** - Printer deployment for Terminal Services

#### Documentation
- System Maintenance Notification Template
- Microsoft Tenant Security Policy
- Various troubleshooting guides

---

## 🏢 Environment Breakdown

| Client | Script Count | Primary Use Cases |
|--------|--------------|-------------------|
| Uplift Michigan | 4+ | Student onboarding, email automation |
| Wilbert Plastics | 3+ | Terminal servers, file management |
| Prism Plastics | 2+ | Printer management, barcode troubleshooting |
| Marmon Plastics | 2+ | Network share management |
| Multi-Client | 5+ | General IT utilities |

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
- Complete folder reorganization with underscores
- Add all identified scripts from conversation history
- Update all README documentation
- Create usage examples for each script

### Medium Term (1-3 months)
- Create automated testing framework
- Add script templates for new development
- Build script dependency documentation
- Create video tutorials

### Long Term (3+ months)
- PowerShell module packaging
- CI/CD pipeline for testing
- Community contributions welcome
- Integration with other automation platforms

---

## 📋 Next Steps

### Immediate
- [x] Consolidate inventory files
- [ ] Rename all folders to use underscores
- [ ] Add remaining scripts from conversation history
- [ ] Update all README files

### Future
- [ ] Extract and version all unversioned scripts
- [ ] Create API specification files (Skyward, USPS, etc.)
- [ ] Document common HaloPSA automation rules
- [ ] Add PowerShell module requirements documentation

---

**Inventory Version:** 3.0  
**Last Updated:** November 18, 2025  
**Maintained By:** Bryan Faulkner
