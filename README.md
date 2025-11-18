# IT Automation Tools

**Author:** Bryan Faulkner  
**Repository:** https://github.com/ShadowA2J/it-automation-tools  
**Last Updated:** November 18, 2025

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
├── rewst_workflows/               # Rewst workflow automation templates
├── email_templates/               # HTML email templates
└── documentation/                 # Technical documentation and guides
```

## 🚀 Quick Start

### Prerequisites
- PowerShell 5.1 or higher for Windows scripts
- Appropriate administrative permissions for target systems
- Rewst platform access for workflow templates

### Installation
```bash
git clone https://github.com/ShadowA2J/it-automation-tools.git
cd it-automation-tools
```

## 📋 Script Categories

### Active Directory Management
- **Export-ADUsersFromOU.ps1** - Export AD users from specific OU to CSV
- **Import-ADUsersFromCSV.ps1** - Bulk import AD users from CSV

### Permissions Management
- **Get-FolderPermissionsAudit.ps1** - Comprehensive network share permissions audit with HTML/CSV reporting

### File & Network Share Management
- **Move-FilesWithFuzzyMatching.ps1** - Intelligent file reorganization with fuzzy matching
- **Get-NCRFolderInventory.ps1** - Detailed folder inventory and analysis
- **Get-TopLevelFolderReport.ps1** - Network share folder reporting with size analysis
- **Move-OldFoldersToArchive.ps1** - Archive old folders based on modification date
- **Fix-Windows11-PDFPreview.ps1** - Fix Windows 11 PDF preview issues

### Printer Management
- **Remove-ZebraPrintDrivers.ps1** - Zebra printer driver removal utility

### Terminal Services
- **Invoke-RDUserLogoff-Multi.ps1** - Remote Desktop session management across multiple servers

### Office/M365
- **Reset-OfficeAndTeams.ps1** - Reset Office and Teams installations

### Rewst Workflows
- **Student-Guardian-Data-Parser.jinja** - Skyward API data parsing template
- **Accelerate-Account-Status-Report.html** - Account creation status reporting

### Email Templates
- **UMOS-Welcome-Email.html** - Student onboarding welcome email
- **UMOS-Chromebook-Shipping.html** - Chromebook shipping notification

### Documentation
- **Barcode-Troubleshooting-Guide.md** - Crystal Reports barcode troubleshooting

## 🔧 Usage

Each script includes comprehensive inline documentation. View help for any PowerShell script:

```powershell
Get-Help .\ScriptName.ps1 -Full
```

## 📊 Script Inventory

For a complete inventory of all scripts, including planned additions and version history, see [SCRIPT_INVENTORY.md](SCRIPT_INVENTORY.md).

## 🤝 Contributing

This is a personal repository for my IT automation work. Feel free to fork and adapt for your own use.

## 📝 Versioning

All scripts follow semantic versioning (MAJOR.MINOR.PATCH):
- MAJOR: Breaking changes
- MINOR: New features, backward compatible
- PATCH: Bug fixes, backward compatible

## 📄 License

These scripts are provided as-is for personal and professional use.

---

**Version:** 2.2.0  
**Last Update:** November 18, 2025  
**Status:** Active Development
