# IT Automation Tools

**Author:** Bryan Faulkner  
**Repository:** https://github.com/ShadowA2J/it-automation-tools  
**Last Updated:** November 19, 2025

A comprehensive collection of IT automation scripts, templates, and tools for system administration, workflow automation, and student information management.

## 📁 Repository Structure

```
it-automation-tools/
├── AD_User_Export_Import_Tools/  # Active Directory user management
├── permissions/                   # Network share permission auditing
├── file_management/               # File, folder, and network share management
├── printer_management/            # Printer driver and deployment tools
├── terminal_services/             # Remote Desktop and terminal server utilities
├── Office_M365/                   # Office and Teams management
├── ninja-scripts/                 # NinjaRMM-specific automation scripts
├── rewst_workflows/               # Rewst workflow automation templates
├── email_templates/               # HTML email templates
└── documentation/                 # Technical documentation and guides
```

## 🚀 Quick Start

### Prerequisites
- PowerShell 5.1 or higher for Windows scripts
- Appropriate administrative permissions for target systems
- Rewst platform access for workflow templates
- NinjaRMM access for ninja-scripts deployment

### Installation
```bash
git clone https://github.com/ShadowA2J/it-automation-tools.git
cd it-automation-tools
```

## 📋 Complete Script Inventory

### Active Directory Management
**Location:** `/AD_User_Export_Import_Tools/`

| Script | Version | Description | Status |
|--------|---------|-------------|--------|
| Export-ADUsersFromOU.ps1 | - | Export AD users from specific OU to CSV | ✅ Active |
| Import-ADUsersFromCSV.ps1 | - | Bulk import AD users from CSV | ✅ Active |

### Permissions Management
**Location:** `/permissions/`

| Script | Version | Description | Status |
|--------|---------|-------------|--------|
| Get-FolderPermissionsAudit.ps1 | 2.0.0 | Comprehensive network share permissions audit with HTML/CSV reporting | ✅ Complete |

### File & Network Share Management
**Location:** `/file_management/`

| Script | Version | Description | Status |
|--------|---------|-------------|--------|
| Move-FilesWithFuzzyMatching.ps1 | - | Intelligent file reorganization with fuzzy matching | ✅ Active |
| Get-NCRFolderInventory.ps1 | - | Detailed folder inventory and analysis | ✅ Active |
| Get-TopLevelFolderReport.ps1 | 1.2.0 | Network share folder reporting with size analysis | ✅ Complete |
| Move-OldFoldersToArchive.ps1 | 1.0.0 | Archive old folders based on modification date | ✅ Complete |
| Fix-Windows11-PDFPreview.ps1 | - | Fix Windows 11 PDF preview issues | ✅ Active |

**Identified but not yet added:**
- Move-SpecificFolders.ps1 - Move folders by exact name match
- Export-DirectoryListing.ps1 - Export directory listings
- Monitor-FolderAndChangePermissions.ps1 - File change monitoring with ACL updates

### Printer Management
**Location:** `/printer_management/`

| Script | Version | Description | Status |
|--------|---------|-------------|--------|
| Remove-ZebraPrintDrivers.ps1 | - | Zebra printer driver removal utility | ✅ Active |

**Identified but not yet added:**
- Install-PrinterDriverFromSharePoint.ps1 - Download and install printer drivers from SharePoint
- Deploy-PrintersByGroup.ps1 - Printer deployment for Terminal Services

### Terminal Services
**Location:** `/terminal_services/`

| Script | Version | Description | Status |
|--------|---------|-------------|--------|
| Invoke-RDUserLogoff-Multi.ps1 | - | Remote Desktop session management across multiple servers | ✅ Active |

### Office/M365
**Location:** `/Office_M365/`

| Script | Version | Description | Status |
|--------|---------|-------------|--------|
| Reset-OfficeAndTeams.ps1 | - | Reset Office and Teams installations | ✅ Active |

### NinjaRMM Scripts
**Location:** `/ninja-scripts/`

| Script | Version | Description | Status |
|--------|---------|-------------|--------|
| DellCommandUpdate.ps1 | 1.0.0 | Dell Command Update installation and Dell driver/firmware updates | ✅ Complete |

Enhanced for NinjaRMM environments with improved error handling, logging, and reliability.

### Rewst Workflows
**Location:** `/rewst_workflows/`

#### Uplift Michigan Online School
| Template | Description | Status |
|----------|-------------|--------|
| Student-Guardian-Data-Parser.jinja | Skyward API data parsing template | ✅ Active |
| Accelerate-Account-Status-Report.html | Account creation status reporting | ✅ Active |

#### Integration Documentation
- HaloPSA Custom Field Mapping
- Skyward OneRoster API Integration
- Email-to-Workflow Trigger Configuration
- Student ID Extraction from Emails

### Email Templates
**Location:** `/email_templates/`

#### Uplift Michigan Online School
| Template | Purpose | Status |
|----------|---------|--------|
| UMOS-Welcome-Email.html | Student onboarding welcome email | ✅ Active |
| UMOS-Chromebook-Shipping.html | Chromebook shipping notification | ✅ Active |

### Documentation
**Location:** `/documentation/`

| Document | Description | Status |
|----------|-------------|--------|
| Barcode-Troubleshooting-Guide.md | Crystal Reports barcode troubleshooting | 📝 Complete |

**Identified but not yet added:**
- System Maintenance Notification Templates
- Microsoft Tenant Security Policy
- Various troubleshooting guides

## 🔧 Usage

Each script includes comprehensive inline documentation. View help for any PowerShell script:

```powershell
Get-Help .\ScriptName.ps1 -Full
```

### Example: Running Permission Audit
```powershell
.\Get-FolderPermissionsAudit.ps1 -Path "\\server\share" -OutputFormat Both
```

### Example: Dell Updates via NinjaRMM
Deploy the DellCommandUpdate.ps1 script through NinjaRMM automation policies for automated Dell driver and firmware updates across your fleet.

## 📊 Status Legend

- ✅ **Active/Complete** - Fully functional and documented
- ⚠️ **Needs Work** - Functional but needs versioning/cleanup
- 📝 **Documentation** - Guide or reference material
- 🚧 **In Progress** - Currently being developed
- ⏳ **Planned** - Identified but not yet started

## 📈 Version Control

All scripts follow semantic versioning (MAJOR.MINOR.PATCH):
- **MAJOR:** Breaking changes to parameters or functionality
- **MINOR:** New features, backward compatible
- **PATCH:** Bug fixes, documentation updates

## 🤝 Contributing

This is a personal repository for my IT automation work. Feel free to fork and adapt for your own use.

## 📋 Recent Changes

### November 19, 2025
- Added ninja-scripts folder for NinjaRMM-specific automation
- Added DellCommandUpdate.ps1 with enhanced error handling and NinjaRMM compatibility
- Merged script inventory into main README
- Removed repository goals and next steps sections

### November 18, 2025
- Merged `network_share_management` folder into `file_management`
- Renamed `powershell_utilities` to `terminal_services`
- Renamed `network_tools` to `printer_management`
- Updated all documentation to reflect new structure
- Standardized folder naming with underscores

## 📄 License

These scripts are provided as-is for personal and professional use.

---

**Repository Version:** 2.3.0  
**Last Updated:** November 19, 2025  
**Maintained By:** Bryan Faulkner  
**Status:** Active Development
