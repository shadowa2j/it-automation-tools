# Network Share Folder Management Suite

A two-script PowerShell solution for analyzing and archiving old folders on network shares. Scan top-level folders for modification dates, then safely archive folders that haven't been modified recently.

## Overview

This suite consists of two complementary scripts:

1. **Get-TopLevelFolderReport.ps1** - Recursively scans all folders and files under each top-level folder in a network share, identifies the newest `LastWriteTime` from any file or folder within each top-level folder, and exports the results to a timestamped CSV report.

2. **Move-OldFoldersToArchive.ps1** - Reads the CSV report, identifies folders with modification dates older than 2024, and safely moves them to an archive location with WhatIf support and confirmation prompts.

## Features

### Get-TopLevelFolderReport.ps1

- ✅ **Recursive scanning** - Examines all files and folders at every level
- ✅ **Newest date detection** - Finds the most recent `LastWriteTime` from both files AND folders
- ✅ **Folder size calculation** - Calculates total size of each top-level folder in bytes, MB, and GB
- ✅ **Progress indicators** - Real-time progress display with percentage and folder count
- ✅ **Error handling** - Gracefully handles access denied errors and logs them
- ✅ **Comprehensive logging** - Creates detailed timestamped log files for troubleshooting
- ✅ **Sorted output** - Results automatically sorted by newest modified date (descending)
- ✅ **CSV export** - Professional CSV report with multiple date columns for analysis
- ✅ **Interactive completion** - Option to open report location when finished

### Move-OldFoldersToArchive.ps1

- ✅ **Interactive CSV selection** - File picker dialog to select the report
- ✅ **WhatIf mode** - Preview what would be archived without making changes
- ✅ **Confirmation prompts** - Shows detailed preview and asks for confirmation
- ✅ **Auto-create archive** - Creates archive folder if it doesn't exist
- ✅ **Date filtering** - Configurable cutoff date (default: January 1, 2024)
- ✅ **Conflict detection** - Checks for existing folders in archive location
- ✅ **Comprehensive logging** - Detailed logging matching the first script
- ✅ **Progress tracking** - Real-time progress during move operations
- ✅ **Detailed summary** - Reports success, failures, and skipped folders

## Requirements

- **PowerShell**: Version 5.1 or higher
- **Permissions**: Read access to the target network share
- **Operating System**: Windows (tested on Windows 10/11 and Windows Server 2016+)

## Installation

1. Download both scripts from this repository
2. Place `Get-TopLevelFolderReport.ps1` and `Move-OldFoldersToArchive.ps1` in your desired location
3. Configure the network share path in `Get-TopLevelFolderReport.ps1` (line 25)
4. Configure the archive path in `Move-OldFoldersToArchive.ps1` (line 28) if needed

## Configuration

### Script 1: Get-TopLevelFolderReport.ps1

#### Network Share Path

By default, the script is configured for:
```powershell
$NetworkSharePath = "\\ecpsyn\Shares\Public"
```

**To change the target share**, edit line 25 in the script:
```powershell
$NetworkSharePath = "\\your-server\your-share\your-folder"
```

#### Output Location

Reports and logs are saved to the same directory where the script is executed:
- **CSV Report**: `TopLevelFolderReport_YYYYMMDD_HHMMSS.csv`
- **Log File**: `TopLevelFolderReport_YYYYMMDD_HHMMSS.log`

### Script 2: Move-OldFoldersToArchive.ps1

#### Archive Path

By default, the archive location is:
```powershell
$ArchivePath = "\\ecpsyn\Shares\Public\Archive"
```

**To change the archive location**, edit line 28 in the script:
```powershell
$ArchivePath = "\\your-server\your-share\Archive"
```

#### Cutoff Date

By default, folders with a newest modified date older than January 1, 2024 will be archived:
```powershell
$CutoffDate = Get-Date "2024-01-01"
```

**To change the cutoff date**, edit line 29 in the script:
```powershell
$CutoffDate = Get-Date "2023-01-01"  # Archive folders older than 2023
```

#### Output Location

Logs are saved to the same directory where the script is executed:
- **Log File**: `ArchiveOperation_YYYYMMDD_HHMMSS.log`

## Usage

### Workflow

This is a two-step process:

1. **Generate Report** - Run `Get-TopLevelFolderReport.ps1` to scan the network share
2. **Archive Old Folders** - Run `Move-OldFoldersToArchive.ps1` to move old folders based on the report

### Step 1: Generate Report

```powershell
.\Get-TopLevelFolderReport.ps1
```

This will scan all top-level folders and create a CSV report with modification dates.

### Step 2: Archive Old Folders

```powershell
# Preview what would be archived (recommended first step)
.\Move-OldFoldersToArchive.ps1 -WhatIf

# Archive with confirmation prompt
.\Move-OldFoldersToArchive.ps1

# Archive without confirmation
.\Move-OldFoldersToArchive.ps1 -Force
```

### Complete Example Workflow

```powershell
# Step 1: Generate the report
PS C:\Scripts> .\Get-TopLevelFolderReport.ps1
# ... scanning completes, CSV created ...

# Step 2: Preview what would be archived
PS C:\Scripts> .\Move-OldFoldersToArchive.ps1 -WhatIf
# ... shows folders that would be moved ...

# Step 3: Actually archive the folders
PS C:\Scripts> .\Move-OldFoldersToArchive.ps1
# ... prompts for CSV selection ...
# ... shows preview and asks for confirmation ...
# ... moves folders to archive ...
```

### Example Output

#### Script 1: CSV Report Columns
| FolderName | FolderPath | NewestModifiedDate | FolderSizeBytes | FolderSizeDisplay | FolderCreatedDate | FolderLastModified |
|------------|------------|-------------------|-----------------|-------------------|-------------------|-------------------|
| Documents | \\ecpsyn\Shares\Public\Documents | 2025-11-13 14:30:22 | 15728640000 | 14.65 GB | 2020-01-15 09:00:00 | 2025-11-13 14:30:22 |
| Archives | \\ecpsyn\Shares\Public\Archives | 2025-10-05 08:15:33 | 524288000 | 500.00 MB | 2019-05-10 11:20:00 | 2024-08-22 16:45:00 |

#### Console Output
```
2025-11-13 10:30:15 [INFO] ========================================
2025-11-13 10:30:15 [INFO] Starting Top-Level Folder Report Script
2025-11-13 10:30:15 [INFO] Network Share: \\ecpsyn\Shares\Public
2025-11-13 10:30:15 [INFO] Report will be saved to: C:\Scripts\TopLevelFolderReport_20251113_103015.csv
2025-11-13 10:30:15 [INFO] ========================================
2025-11-13 10:30:15 [INFO] Network share is accessible. Beginning scan...
2025-11-13 10:30:16 [INFO] Found 5 top-level folders to process
2025-11-13 10:30:16 [INFO] [1/5] Processing folder: Documents
2025-11-13 10:30:45 [INFO]   Newest date: 11/13/2025 14:30:22 | Size: 14.65 GB
...
```

#### Script 2: Archive Operation Console Output
```
2025-11-13 11:15:30 [INFO] ========================================
2025-11-13 11:15:30 [INFO] Starting Archive Operation Script
2025-11-13 11:15:30 [INFO] Archive Location: \\ecpsyn\Shares\Public\Archive
2025-11-13 11:15:30 [INFO] Cutoff Date: 2024-01-01
2025-11-13 11:15:30 [INFO] WhatIf Mode: False
2025-11-13 11:15:30 [INFO] ========================================
2025-11-13 11:15:35 [INFO] Selected CSV: C:\Scripts\TopLevelFolderReport_20251113_103015.csv
2025-11-13 11:15:35 [INFO] Found 5 folders in report
2025-11-13 11:15:35 [INFO] Found 2 folders to archive

========================================
FOLDERS TO BE ARCHIVED:
========================================
  - OldArchives (Last Modified: 2022-03-15)
  - LegacyData (Last Modified: 2021-08-22)
========================================

Do you want to proceed with archiving these 2 folders? (Y/N): Y

2025-11-13 11:15:42 [INFO] Beginning archive operation...
2025-11-13 11:15:42 [INFO] Archive folder exists: \\ecpsyn\Shares\Public\Archive
2025-11-13 11:15:42 [INFO] [1/2] Archiving: OldArchives
2025-11-13 11:15:45 [SUCCESS]   Successfully moved: OldArchives
2025-11-13 11:15:45 [INFO] [2/2] Archiving: LegacyData
2025-11-13 11:15:48 [SUCCESS]   Successfully moved: LegacyData

========================================
Archive Operation Complete!
Total folders processed: 2
Successfully archived: 2
Failed to archive: 0
Skipped (not found): 0
Archive location: \\ecpsyn\Shares\Public\Archive
========================================
```

## How It Works

### Script 1: Get-TopLevelFolderReport.ps1

1. **Validation** - Verifies the network share path is accessible
2. **Discovery** - Identifies all top-level folders in the target share
3. **Recursive Scanning** - For each top-level folder:
   - Retrieves the folder's own `LastWriteTime`
   - Recursively scans all child files and folders
   - Compares all `LastWriteTime` values to find the newest
   - Handles access denied errors gracefully
4. **Reporting** - Sorts results and exports to CSV
5. **Logging** - Records all operations, errors, and warnings to log file

### Script 2: Move-OldFoldersToArchive.ps1

1. **CSV Selection** - Displays file picker dialog to select the report CSV
2. **Data Import** - Reads and parses the CSV report data
3. **Date Filtering** - Identifies folders with `NewestModifiedDate` older than cutoff (2024-01-01)
4. **Preview Display** - Shows which folders will be archived
5. **Confirmation** - Prompts user to proceed (unless `-Force` used)
6. **Archive Creation** - Creates archive folder if it doesn't exist
7. **Move Operations** - Moves each folder with:
   - Conflict detection (skips if destination exists)
   - Error handling for each folder
   - Progress tracking
8. **Summary Report** - Displays success/failure statistics

## Error Handling

The script includes robust error handling:

- **Access Denied**: Logged as warnings, script continues processing
- **Network Issues**: Stops execution with detailed error message
- **Missing Folders**: Exits gracefully with warning
- **Unexpected Errors**: Captured with full stack trace in log file

## Troubleshooting

### Both Scripts

#### Script Won't Run
- Ensure PowerShell execution policy allows script execution:
  ```powershell
  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
  ```

#### Access Denied Errors
- Check that your account has read permissions on the network share
- For the archive script, ensure you have write/modify permissions
- Review the log file for specific paths that were denied
- Contact your network administrator if needed

### Script 1: Get-TopLevelFolderReport.ps1

#### Network Share Not Accessible
- Verify the UNC path is correct
- Test access manually: `Test-Path "\\server\share"`
- Ensure network connectivity to the server

#### Performance on Large Shares
- The script uses `-Force` to include hidden files (can be removed if not needed)
- Large folder structures may take significant time to scan
- Progress indicator shows real-time status

### Script 2: Move-OldFoldersToArchive.ps1

#### CSV File Won't Open
- Ensure the CSV was generated by `Get-TopLevelFolderReport.ps1`
- Verify the CSV is not open in Excel or another application
- Check that the CSV has the expected columns: `FolderName`, `FolderPath`, `NewestModifiedDate`

#### Folders Not Moving
- Verify you have write permissions to both source and destination
- Check if folders already exist in the archive location (script will skip)
- Review the log file for specific error messages

#### Date Parsing Errors
- Ensure dates in CSV are in a valid format
- Check for "Unable to determine" values in the `NewestModifiedDate` column
- These folders will be skipped automatically

#### WhatIf Mode Not Working
- Ensure you're using the `-WhatIf` parameter: `.\Move-OldFoldersToArchive.ps1 -WhatIf`
- WhatIf mode will show operations but not perform them

## Output Files

### CSV Report Fields

| Field | Description |
|-------|-------------|
| **FolderName** | Name of the top-level folder |
| **FolderPath** | Full UNC path to the folder |
| **NewestModifiedDate** | Most recent LastWriteTime found in the entire folder tree |
| **FolderSizeBytes** | Total size of all files in the folder tree in bytes (for precise calculations) |
| **FolderSizeDisplay** | Human-readable folder size (automatically formatted as MB or GB) |
| **FolderCreatedDate** | When the top-level folder was created |
| **FolderLastModified** | LastWriteTime of the top-level folder itself |

### Log File Content

The log file includes:
- Script start/end timestamps
- Network share path being scanned
- Number of folders processed
- Individual folder processing status
- Any errors or warnings encountered
- Final summary statistics

## Version History

### Version 1.1.0 (2025-11-13)

#### Get-TopLevelFolderReport.ps1
- **Added**: Folder size calculation feature
  - Calculates total size of each top-level folder recursively
  - Includes both exact size in bytes and human-readable format (MB/GB)
  - Adds `FolderSizeBytes` and `FolderSizeDisplay` columns to CSV report
  - Updates log output to include size information

### Version 1.0.0 (2025-11-13)

#### Get-TopLevelFolderReport.ps1
- Initial release
- Recursive folder scanning
- CSV export functionality
- Comprehensive logging
- Progress indicators
- Error handling for access denied scenarios

#### Move-OldFoldersToArchive.ps1
- Initial release
- CSV import with file picker dialog
- Date-based filtering (pre-2024 cutoff)
- WhatIf mode for safe testing
- Confirmation prompts
- Auto-create archive folder
- Comprehensive logging
- Progress indicators
- Detailed summary statistics

## Author

**Bryan Jackson**

## License

This script is provided as-is for use in IT automation and administration tasks.

## Contributing

Suggestions and improvements are welcome! Please feel free to submit issues or pull requests.

## Use Cases

This script suite is particularly useful for:

- **Storage cleanup planning** - Identify and archive folders with stale data
- **Compliance requirements** - Archive old data while maintaining access
- **Cost reduction** - Move inactive data to cheaper storage tiers
- **Performance improvement** - Reduce clutter in active network shares
- **Capacity planning** - Understand which areas of shares are actively used vs. stagnant
- **Migration planning** - Identify active vs. stale data before migration projects
- **Audit preparation** - Document last modification dates and archive old records
- **Data lifecycle management** - Implement automated policies for data retention
- **Disaster recovery** - Prioritize backup resources on actively-used data

## Notes

### Script 1: Get-TopLevelFolderReport.ps1
- The script uses `Get-ChildItem -Recurse -Force` which includes hidden and system files
- Access denied folders are skipped and logged, but don't stop the script
- Results are sorted by newest modified date (most recent first)
- Both the CSV report and log file include timestamps in their filenames to prevent overwrites

### Script 2: Move-OldFoldersToArchive.ps1
- Folders are moved (not copied), freeing up space on the original share
- If a folder already exists in the archive location, the move is skipped to prevent data loss
- The script preserves the entire folder structure when moving
- WhatIf mode is highly recommended for first-time use to preview operations
- Log files track every operation for audit and troubleshooting purposes

## Support

For issues, questions, or feature requests, please open an issue in this repository.
