# IT Automation Tools

**Author:** Bryan Faulkner, with assistance from Claude  
**Organization:** Uplift Michigan Online School & Managed Services Clients  
**Last Updated:** 2025-11-06

---

## 📋 Overview

This repository contains PowerShell scripts and automation tools for IT support operations, including:
- Network share permissions auditing
- Rewst workflow integrations
- File management utilities
- Network administration tools
- Student onboarding automation

All scripts are production-ready, well-documented, and include proper versioning.

---

## 📁 Repository Structure

```
it-automation-tools/
├── permissions/          # Permission auditing and management scripts
├── rewst-workflows/      # Rewst automation workflow tools
├── file-management/      # File and folder management utilities
├── network-tools/        # Network administration scripts
└── README.md            # This file
```

---

## 🚀 Getting Started

### Prerequisites
- PowerShell 5.1 or higher
- Appropriate permissions for target systems
- Network access to target shares/systems

### Installation
1. Clone this repository:
   ```powershell
   git clone https://github.com/ShadowA2J/it-automation-tools.git
   cd it-automation-tools
   ```

2. Review script documentation before running
3. Test scripts in a non-production environment first

---

## 📚 Script Categories

### Permissions Management
Tools for auditing and managing NTFS permissions across network shares.
- Comprehensive permission audits
- Unusual permission detection
- Inheritance tracking

### Rewst Workflows
Integration tools for Rewst automation platform.
- Student onboarding workflows
- HaloPSA integrations
- Skyward API connections

### File Management
Utilities for file and folder operations.
- Bulk operations
- Directory restructuring
- Monitoring and reporting

### Network Tools
Network administration and monitoring scripts.
- Endpoint management
- Remote desktop utilities
- System configuration

---

## 🔒 Security Notes

- **Never commit credentials** - use .gitignore for sensitive files
- **Test thoroughly** - always test in non-production first
- **Review permissions** - ensure scripts run with appropriate privileges
- **Audit logs** - review script outputs for security concerns

---

## 📝 Version Control

All scripts follow semantic versioning (MAJOR.MINOR.PATCH):
- **MAJOR**: Breaking changes or significant functionality overhaul
- **MINOR**: New features added in backward-compatible manner
- **PATCH**: Backward-compatible bug fixes

Each script includes:
- Version number in header
- Author attribution
- Date created/modified
- Detailed change log
- Usage examples

---

## 🤝 Contributing

This is a personal repository for professional use. Scripts are created and maintained by Bryan Faulkner with assistance from Claude AI.

---

## 📄 License

These scripts are for internal use within Uplift Michigan Online School and managed services client environments.

---

## 📞 Support

For issues or questions:
- Review script documentation
- Check error messages in console output
- Verify prerequisites and permissions
- Test in isolated environment

---

## ⚠️ Disclaimer

All scripts are provided as-is. Always test in a non-production environment before deploying to production systems. Ensure you have proper backups before running any automation scripts.

---

**Last Repository Update:** 2025-11-06  
**Total Scripts:** Starting collection  
**PowerShell Version:** 5.1+
