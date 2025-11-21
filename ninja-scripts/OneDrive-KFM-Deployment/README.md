# OneDrive Business KFM Deployment Scripts

Automated deployment scripts for configuring OneDrive for Business with Silent Sign-In and Known Folder Move (KFM) via NinjaRMM.

## Overview

These scripts automate the complete OneDrive for Business setup:
- **Silent Account Configuration** - Users are automatically signed into OneDrive using their Windows/Azure AD credentials
- **Known Folder Move (KFM)** - Desktop, Documents, and Pictures folders are automatically redirected to OneDrive
- **KFM Lock** - Users cannot disable the folder backup

## Scripts

| Script | Run As | Purpose |
|--------|--------|---------|
| `Setup-OneDriveKFM-MachinePolicy.ps1` | SYSTEM | Sets machine-level policies (HKLM). Run once per device. |
| `Setup-OneDriveBusinessKFM.ps1` | Logged-in User | Handles user-context setup, install verification, and status reporting. Run on user login. |

## Requirements

- Windows 10/11
- Azure AD Hybrid Joined or Azure AD Joined device
- NinjaRMM agent
- User must sign in with Azure AD synced credentials

## Deployment (NinjaRMM)

### Step 1: Machine Policy Script (Run Once)

1. Create a new **Automation** in NinjaRMM
2. Upload `Setup-OneDriveKFM-MachinePolicy.ps1`
3. Configure:
   - **Run As:** System
   - **Trigger:** On device boot OR on-demand
4. Deploy to target devices/policies

### Step 2: User Context Script (Run on Login)

1. Create a new **Automation** in NinjaRMM
2. Upload `Setup-OneDriveBusinessKFM.ps1`
3. Configure:
   - **Run As:** Logged-in User
   - **Trigger:** On user login
4. Deploy to target devices/policies

### Optional: Custom Fields

Create these custom fields in NinjaRMM to capture script output:

| Field Name | Type | Purpose |
|------------|------|---------|
| `OneDrive_Status` | Text | Overall status (Configured/Pending/Failed) |
| `OneDrive_KFM` | Text | KFM folder status |
| `OneDrive_TenantID` | Text | Discovered tenant ID |

## Exit Codes

### Machine Policy Script
| Code | Meaning |
|------|---------|
| 0 | Success - All machine policies configured |
| 1 | Partial - Some policies set, check output |
| 2 | Failed - Could not configure policies |

### User Context Script
| Code | Meaning |
|------|---------|
| 0 | Success - OneDrive fully configured with KFM |
| 1 | Partial - Config applied, needs login cycle to complete |
| 2 | Failed - See output for details |

## What Gets Configured

### Machine Policies (HKLM)
```
HKLM:\SOFTWARE\Policies\Microsoft\OneDrive
├── SilentAccountConfig = 1          # Enable silent sign-in
├── KFMSilentOptIn = <TenantID>      # Enable silent KFM
├── KFMSilentOptInWithNotification = 1  # Show notification after KFM
├── KFMBlockOptOut = 1               # Prevent users disabling KFM
├── KFMOptInWithWizard = <TenantID>  # Fallback prompt if silent fails
└── FilesOnDemandEnabled = 1         # Enable Files On-Demand
```

### User Settings (HKCU)
```
HKCU:\Software\Microsoft\OneDrive
├── EnableADAL = 1                   # Modern authentication
└── (Clears SilentBusinessConfigCompleted if needed)
```

## Tenant ID Discovery

The scripts automatically discover the Azure AD Tenant ID from:
1. `HKLM:\SYSTEM\CurrentControlSet\Control\CloudDomainJoin\JoinInfo\{GUID}\TenantId`
2. `dsregcmd /status` output
3. `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CDJ\AAD\TenantId`

No manual tenant ID configuration required!

## OneDrive Installation

If OneDrive is not installed, the scripts will attempt installation via:
1. **winget** (preferred, per-machine install)
2. **Built-in setup** (`%SystemRoot%\SysWOW64\OneDriveSetup.exe`)
3. **Microsoft CDN** (https://go.microsoft.com/fwlink/?linkid=844652)

## Troubleshooting

### OneDrive not signing in automatically
- Verify device is Azure AD Joined or Hybrid Joined: `dsregcmd /status`
- Check `SilentAccountConfig` is set: `reg query "HKLM\SOFTWARE\Policies\Microsoft\OneDrive"`
- User may need to log out and back in

### KFM not enabling
- Check if user has existing folder redirection (GPO conflict)
- Verify `KFMSilentOptIn` contains correct tenant ID
- Check OneDrive sync client logs: `%LocalAppData%\Microsoft\OneDrive\logs`

### Script says "Pending" status
- This is normal on first run - user needs to log out/in or restart OneDrive
- KFM happens asynchronously after OneDrive signs in

### Tenant ID not found
- Device may not be properly Azure AD joined
- Run `dsregcmd /status` and verify `AzureAdJoined: YES` or `DomainJoined: YES`

## Registry Verification

Quick PowerShell commands to verify configuration:

```powershell
# Check machine policies
Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\OneDrive"

# Check user OneDrive status
Get-ItemProperty "HKCU:\Software\Microsoft\OneDrive\Accounts\Business1"

# Check KFM status (7 = all three folders protected)
(Get-ItemProperty "HKCU:\Software\Microsoft\OneDrive\Accounts\Business1").KfmFoldersProtectedNow
```

## Notes

- Scripts are **idempotent** - safe to run multiple times
- Machine policy script only needs to run once per device
- User script should run on every login for shared computers
- Personal OneDrive accounts are not affected (unless you enable `DisablePersonalSync`)

## References

- [Use Group Policy to control OneDrive sync settings](https://learn.microsoft.com/en-us/sharepoint/use-group-policy)
- [Redirect and move Windows known folders to OneDrive](https://learn.microsoft.com/en-us/sharepoint/redirect-known-folders)
- [Silently configure user accounts](https://learn.microsoft.com/en-us/sharepoint/use-silent-account-configuration)

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2025-11-21 | Initial release |

## License

MIT License - Use freely for your MSP/IT needs.

## Author

Bryan Faulkner, with assistance from Claude
