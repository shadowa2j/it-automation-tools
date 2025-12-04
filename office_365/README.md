# Office/Teams Reset and SARA Toolkit

A PowerShell utility for troubleshooting and resetting Microsoft 365 (Office) and Teams applications, with integrated Microsoft Support and Recovery Assistant (SARA) Enterprise scenarios.

## Version
1.1.1

## Features

### Mode 1: Scripted Reset (Default)
- **Clear Office and Teams Caches**: Removes temporary files and cached data that may cause performance issues
- **Reset Microsoft 365 Apps**: Resets Office 365 and Teams to default settings using AppxPackage cmdlets
- **Remove Cached Credentials**: Clears stored account information and identity caches

### Mode 2: Microsoft SARA Enterprise Scenarios
- **Outlook Scan**: Expert experience admin task with offline scan
- **Office Uninstall**: Complete removal of all Office versions
- **Office Activation**: Activate Office installation
- **Reset Office Activation**: Clear and reset activation state
- **Shared Computer Activation**: Configure for shared computer environments

## Requirements

- Windows 10 or Windows 11
- PowerShell 5.1 or higher
- Administrative privileges (required for app reset operations)
- Microsoft 365 (Office) and/or Teams installed
- For SARA mode: SARA Enterprise files extracted to network location

## Installation

1. Download `Reset-OfficeAndTeams.ps1`
2. For SARA functionality: Extract SARA Enterprise files to a network location
3. Update the `$saraSourcePath` variable in the script with your network path

## Usage

### Interactive Mode (Recommended)

Right-click PowerShell and select "Run as Administrator", then:

```powershell
.\Reset-OfficeAndTeams.ps1
```

You'll be prompted to:
1. Select operation mode (Scripted Reset or SARA Scenarios)
2. Confirm each step before execution
3. Choose whether to reboot after completion

### Unattended Mode

For automated deployment or scripting:

```powershell
.\Reset-OfficeAndTeams.ps1 -Unattended
```

**Note**: Unattended mode automatically selects Scripted Reset (Mode 1) and will NOT reboot automatically.

## Configuration

### SARA Network Path

Edit this line in the script to point to your SARA Enterprise files:

```powershell
$saraSourcePath = "\\YOUR-SERVER\SHARE\SARA"  # Update with your path
```

### Log Files

All operations are logged to: `C:\LOGS\SARA_TOOLKIT.log`

## Operation Modes Explained

### Mode 1: Scripted Reset

**Step 1 - Clear Caches**: Removes cache files from:
- Office 16.0 and 15.0 cache directories
- Office Recent files
- Teams cache, blob storage, databases, GPU cache, IndexedDB, and temp files

**Step 2 - Reset Apps**: Uses `Reset-AppxPackage` to reset:
- All Microsoft Office apps
- Microsoft Teams app

**Step 3 - Clear Credentials**: Removes:
- Cached credential files matching Microsoft/Teams/365
- Office identity registry keys (versions 14.0-17.0)
- Teams registry identity cache

### Mode 2: SARA Scenarios

Each SARA scenario can be run individually based on your needs:

- **Outlook Scan**: Diagnostic scan for Outlook issues
- **Office Uninstall**: Clean removal of Office installations
- **Office Activation**: Standard activation process
- **Reset Office Activation**: Clears activation state for re-activation
- **Shared Computer Activation**: Enables Office on shared/RDS environments

## Important Notes

- **Backup First**: Ensure critical data is backed up before running
- **Close Applications**: Close Office and Teams before running the script
- **Administrator Required**: App reset functionality requires admin rights
- **Reboot Recommended**: A system reboot is recommended after completion
- **SARA Files**: SARA mode requires pre-downloaded SARA Enterprise files

## Troubleshooting

### "Neither Microsoft 365 nor Teams is installed"
- Verify Office is installed at standard locations
- Check both Program Files and Program Files (x86)

### "Administrator privileges required"
- Right-click PowerShell and select "Run as Administrator"
- Re-run the script

### SARA scenarios fail
- Verify `$saraSourcePath` points to correct network location
- Ensure SARA files are extracted properly
- Check network connectivity to share
- Review logs at `C:\LOGS\SARA_TOOLKIT.log`

### Script execution is disabled
Run this command in an elevated PowerShell window:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## Log Files

The script creates detailed logs at: `C:\LOGS\SARA_TOOLKIT.log`

SARA tools also create additional logs at: `C:\TEMP` (configurable in SARA arguments)

## Changelog

### 1.1.1 (2025-02-12)
- Fixed logic flow to prevent SARA mode from executing scripted reset
- Improved mode separation and exit handling

### 1.1.0
- Added support for Microsoft SARA Enterprise scenarios
- Interactive scenario selection in SARA mode

### 1.0.0
- Initial release
- Office/Teams cache clearing
- App reset functionality
- Credential removal

## Support

For issues or questions:
- Check log files at `C:\LOGS\SARA_TOOLKIT.log`
- Review Microsoft 365 admin center for account issues
- Consult Microsoft SARA documentation for SARA-specific issues

## License

This script is provided as-is for internal IT support use.

## Author

JS - IT Support Specialist
