# Quick Reference Card - Windows 11 PDF Preview Fix

## 🎯 Common Deployment Scenarios

### Standard Office User
```powershell
.\Fix-Windows11-PDFPreview.ps1 -ScanScope UserFoldersAndShares
```
**Time:** ~5-10 min | **Use:** 90% of deployments

---

### Manufacturing Clients (Prism/Wilbert/Marmon)
```powershell
.\Fix-Windows11-PDFPreview.ps1 -ScanScope Custom -CustomPaths "\\fileserver\production","\\fileserver\quality","D:\Specs"
```
**Time:** Varies | **Use:** Targeted shared folders

---

### Uplift Michigan Online School
```powershell
.\Fix-Windows11-PDFPreview.ps1 -ScanScope UserFolders
```
**Time:** ~2-5 min | **Use:** Student/staff workstations

---

### Silent Deployment (No Interruption)
```powershell
.\Fix-Windows11-PDFPreview.ps1 -ScanScope UserFoldersAndShares -SkipExplorerRestart
```
**Time:** ~5-10 min | **Use:** During business hours

---

## 📊 Ninja RMM Setup (5 Minutes)

1. **Administration > Scripting > Add New Script**
2. **Name:** `Fix Windows 11 PDF Preview Issue`
3. **Type:** PowerShell
4. **Runtime:** Run as Logged on User ⚠️ IMPORTANT
5. **Timeout:** 30 minutes
6. **Paste script** and save

### Quick Deploy
- Select devices/groups
- Run script with parameter: `-ScanScope UserFoldersAndShares`
- Monitor exit codes (0 = success)

---

## 🔍 Quick Checks

### Is it Working?
```powershell
# Check registry
Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Attachments" -Name SaveZoneInformation

# Should return: SaveZoneInformation : 1
```

### View Results
```
Log: C:\ProgramData\NinjaRMM\Logs\PDF-Preview-Fix.log
Exit Code 0 = Success
```

---

## ⚠️ Common Issues

| Problem | Solution |
|---------|----------|
| "Not Administrator" error | Run as Logged on User (not SYSTEM) |
| Registry not applying | Must run in user context |
| Script times out | Increase timeout or use targeted scope |
| Still seeing warning | Restart computer |

---

## 🎛️ Parameters Cheat Sheet

| Parameter | Options | Default |
|-----------|---------|---------|
| `-ScanScope` | UserFolders, UserFoldersAndShares, AllDrives, AllDrivesAndShares, Custom | UserFolders |
| `-CustomPaths` | Array of paths | None |
| `-SkipExplorerRestart` | Switch (include or not) | False |
| `-LogPath` | File path | C:\ProgramData\NinjaRMM\Logs\... |

---

## 📈 Exit Codes

| Code | Meaning |
|------|---------|
| 0 | ✅ Success |
| 1 | ❌ Not Administrator |
| 2 | ❌ Not Windows 11 |
| 3 | ⚠️ Multiple errors (check log) |
| 99 | ❌ Critical error |

---

## 🔧 Manual Test Run

```powershell
# Quick test on your machine
cd C:\Temp
.\Fix-Windows11-PDFPreview.ps1

# Check the log
notepad C:\ProgramData\NinjaRMM\Logs\PDF-Preview-Fix.log
```

---

**Version:** 1.0.0 | **Repo:** github.com/ShadowA2J/it-automation-tools
