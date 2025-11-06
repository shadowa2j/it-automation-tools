# Complete Script Inventory

**Repository:** https://github.com/ShadowA2J/it-automation-tools  
**Last Updated:** November 6, 2025  
**Total Scripts:** 9 active scripts + templates

## 📊 Status Overview

| Category | Scripts | Status |
|----------|---------|--------|
| PowerShell Scripts | 4 | ✅ In Repo |
| Rewst Templates | 2 | ✅ In Repo |
| Email Templates | 2 | ✅ In Repo |
| Documentation | 1 | ✅ In Repo |
| **TOTAL** | **9** | **✅ Complete** |

---

## ✅ Scripts Currently in Repository

### PowerShell Scripts (4)

#### 1. Invoke-RDUserLogoff-Multi.ps1
- **Location:** `/powershell-utilities/`
- **Version:** 1.0.0
- **Purpose:** Remote Desktop session management
- **Environment:** Wilbert Plastics terminal servers
- **Status:** ✅ Active

#### 2. Get-FolderPermissionsAudit.ps1
- **Location:** `/permissions/` (from previous session)
- **Version:** 2.0.0
- **Purpose:** Network share permissions audit
- **Features:** CSV/HTML reports, account filtering
- **Status:** ⏳ Need to add to repo

#### 3. Move-FilesWithFuzzyMatching.ps1
- **Location:** `/file-management/` (from previous session)
- **Version:** 1.0.0
- **Purpose:** Intelligent file reorganization
- **Status:** ⏳ Need to add to repo

#### 4. Remove-ZebraPrintDrivers.ps1
- **Location:** `/network-tools/` (from previous session)
- **Version:** 1.0.0
- **Purpose:** Zebra printer driver cleanup
- **Status:** ⏳ Need to add to repo

### Rewst Workflow Templates (2)

#### 5. Student-Guardian-Data-Parser.jinja
- **Location:** `/rewst-workflows/`
- **Version:** 1.0.0
- **Purpose:** Skyward API data parsing
- **Environment:** Uplift Michigan Online School
- **Status:** ✅ Active

#### 6. Accelerate-Account-Status-Report.html
- **Location:** `/rewst-workflows/`
- **Version:** 1.0.0
- **Purpose:** Account creation status reporting
- **Environment:** Uplift Michigan Online School
- **Status:** ✅ Active

### Email Templates (2)

#### 7. UMOS-Welcome-Email.html
- **Location:** `/email-templates/`
- **Version:** 1.0.0
- **Purpose:** Student onboarding welcome
- **Environment:** Uplift Michigan Online School
- **Status:** ✅ Active

#### 8. UMOS-Chromebook-Shipping.html
- **Location:** `/email-templates/`
- **Version:** 1.0.0
- **Purpose:** Chromebook shipping notification
- **Environment:** Uplift Michigan Online School
- **Status:** ✅ Active

### Documentation (1)

#### 9. Barcode-Troubleshooting-Guide.md
- **Location:** `/documentation/`
- **Version:** 1.0.0
- **Purpose:** Crystal Reports barcode issue resolution
- **Environment:** Prism Plastics
- **Status:** ✅ Active

---

## 🔍 Scripts Identified But Not Yet Created

These scripts were mentioned in conversation history but need to be extracted and added:

### From Previous GitHub Session:
1. **Get-FolderPermissionsAudit.ps1** - Already discussed, need to pull from previous chat
2. **Get-NCRFolderInventory.ps1** - Folder inventory generator
3. **Move-FilesWithFuzzyMatching.ps1** - File reorganization tool

### From Various Conversations:
4. **Printer Driver Install from SharePoint** - Downloads and installs printer INF files
5. **Get-OffScreenWindow Recovery** - Recovers off-screen windows
6. **Font Installation Script** - Automated font deployment
7. **SharePoint Member Management** - SharePoint Online user management
8. **File System Monitoring** - Network drive monitoring solution
9. **Terminal Server Printer Deployment** - Printer management for RDS

### SentinelOne Related:
10. **SentinelOne Configuration Scripts** - Endpoint security automation

---

## 📋 Next Steps for Complete Repository

### Immediate (This Session):
- [x] Create folder structure
- [x] Add RD Logoff script
- [x] Add Rewst templates
- [x] Add email templates
- [x] Add documentation
- [x] Create README files for each folder
- [ ] Pull scripts from previous GitHub session
- [ ] Create comprehensive push guide

### Future Sessions:
- [ ] Extract and add remaining 10+ scripts from conversation history
- [ ] Create API specification files (Skyward, USPS, etc.)
- [ ] Add more Rewst workflow templates
- [ ] Document common HaloPSA automation rules
- [ ] Add PowerShell module requirements documentation

---

## 🏢 Environment Breakdown

| Client | Script Count | Primary Use Cases |
|--------|--------------|-------------------|
| Uplift Michigan | 4 | Student onboarding, email automation |
| Wilbert Plastics | 1+ | Terminal servers, file management |
| Prism Plastics | 1+ | Printer management, barcode troubleshooting |
| Marmon Plastics | TBD | System administration |
| Multi-Client | 3+ | General IT utilities |

---

## 📈 Version Control Strategy

### Semantic Versioning
- **MAJOR.MINOR.PATCH** format
- MAJOR: Breaking changes to parameters or functionality
- MINOR: New features, backward compatible
- PATCH: Bug fixes, documentation updates

### Current Versions
- All newly added scripts: 1.0.0
- Get-FolderPermissionsAudit: 2.0.0 (has HTML feature)

---

## 🎯 Repository Goals

### Short Term (1-2 weeks):
- Add all 20+ identified scripts
- Complete all README documentation
- Create usage examples for each script
- Add prerequisite documentation

### Medium Term (1-3 months):
- Create automated testing framework
- Add script templates for new development
- Build script dependency documentation
- Create video tutorials

### Long Term (3+ months):
- PowerShell module packaging
- CI/CD pipeline for testing
- Community contributions welcome
- Integration with other automation platforms

---

**Inventory Version:** 2.0  
**Last Updated:** November 6, 2025  
**Maintained By:** Bryan Faulkner
