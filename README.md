# IT Automation Tools

**Author:** Bryan Faulkner  
**Repository:** https://github.com/ShadowA2J/it-automation-tools  
**Last Updated:** November 6, 2025

A comprehensive collection of IT automation scripts, templates, and tools for system administration, workflow automation, and student information management.

## 📁 Repository Structure

```
it-automation-tools/
├── permissions/                  # Network share permission auditing
├── file-management/             # File and folder management utilities
├── network-tools/               # Network administration scripts
├── powershell-utilities/        # General PowerShell utilities
├── rewst-workflows/             # Rewst workflow automation templates
├── email-templates/             # HTML email templates
└── documentation/               # Technical documentation and guides
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

### Permissions Management
- **Get-FolderPermissionsAudit.ps1** - Comprehensive network share permissions audit with HTML/CSV reporting

### File Management
- **Move-FilesWithFuzzyMatching.ps1** - Intelligent file reorganization with fuzzy matching
- **Get-NCRFolderInventory.ps1** - Detailed folder inventory and analysis

### Network Tools
- **Remove-ZebraPrintDrivers.ps1** - Zebra printer driver removal utility

### PowerShell Utilities
- **Invoke-RDUserLogoff-Multi.ps1** - Remote Desktop session management across multiple servers

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

## 🤝 Contributing

This is a personal repository for my IT automation work. Feel free to fork and adapt for your own use.

## 📝 Versioning

All scripts follow semantic versioning (MAJOR.MINOR.PATCH):
- MAJOR: Breaking changes
- MINOR: New features, backward compatible
- PATCH: Bug fixes, backward compatible

## 📧 Contact

For questions or support regarding these scripts:
- Create an issue in this repository
- Email: support@qcsph.com (for Uplift Michigan related items)

## 📄 License

These scripts are provided as-is for personal and professional use.

## 🎯 Environments

These scripts are used across multiple client environments:
- **Uplift Michigan Online School** - Student information and onboarding automation
- **Wilbert Plastics** - Network administration and file management
- **Prism Plastics** - System maintenance and printer management
- **Marmon Plastics** - Network infrastructure support

---

**Version:** 2.0.0  
**Last Update:** November 6, 2025  
**Status:** Active Development
