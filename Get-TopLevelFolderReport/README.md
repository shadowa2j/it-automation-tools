# Get-TopLevelFolderReport

A PowerShell script that scans network share top-level folders and reports the newest modification date found within each folder's entire file tree.

## Overview

This script recursively scans all folders and files under each top-level folder in a specified network share, identifies the newest `LastWriteTime` from any file or folder within each top-level folder, and exports the results to a timestamped CSV report with comprehensive logging.

## Features

- ✅ **Recursive scanning** - Examines all files and folders at every level
- ✅ **Newest date detection** - Finds the most recent `LastWriteTime` from both files AND folders
- ✅ **Progress indicators** - Real-time progress display with percentage and folder count
- ✅ **Error handling** - Gracefully handles access denied errors and logs them
- ✅ **Comprehensive logging** - Creates detailed timestamped log files for troubleshooting
- ✅ **Sorted output** - Results automatically sorted by newest modified date (descending)
- ✅ **CSV export** - Professional CSV report with multiple date columns for analysis
- ✅ **Interactive completion** - Option to open report location when finished

## Requirements

- **PowerShell**: Version 5.1 or higher
- **Permissions**: Read access to the target network share
- **Operating System**: Windows (tested on Windows 10/11 and Windows Server 2016+)

## Installation

1. Download the script from this repository
2. Place `Get-TopLevelFolderReport.ps1` in your desired location
3. Modify the `$NetworkSharePath` variable (line 25) to point to your target network share

## Configuration

### Network Share Path

By default, the script is configured for:
```powershell
$NetworkSharePath = "\\ecpsyn\Shares\Public"
```

**To change the target share**, edit line 25 in the script:
```powershell
$NetworkSharePath = "\\your-server\your-share\your-folder"
```

### Output Location

Reports and logs are saved to the same directory where the script is executed:
- **CSV Report**: `TopLevelFolderReport_YYYYMMDD_HHMMSS.csv`
- **Log File**: `TopLevelFolderReport_YYYYMMDD_HHMMSS.log`

## Usage

### Basic Execution

```powershell
.\Get-TopLevelFolderReport.ps1
```

### Example Output

#### CSV Report Columns
| FolderName | FolderPath | NewestModifiedDate | FolderCreatedDate | FolderLastModified |
|------------|------------|-------------------|-------------------|-------------------|
| Documents | \\ecpsyn\Shares\Public\Documents | 2025-11-13 14:30:22 | 2020-01-15 09:00:00 | 2025-11-13 14:30:22 |
| Archives | \\ecpsyn\Shares\Public\Archives | 2025-10-05 08:15:33 | 2019-05-10 11:20:00 | 2024-08-22 16:45:00 |

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
2025-11-13 10:30:45 [INFO]   Newest date found: 11/13/2025 14:30:22
...
```

## How It Works

1. **Validation** - Verifies the network share path is accessible
2. **Discovery** - Identifies all top-level folders in the target share
3. **Recursive Scanning** - For each top-level folder:
   - Retrieves the folder's own `LastWriteTime`
   - Recursively scans all child files and folders
   - Compares all `LastWriteTime` values to find the newest
   - Handles access denied errors gracefully
4. **Reporting** - Sorts results and exports to CSV
5. **Logging** - Records all operations, errors, and warnings to log file

## Error Handling

The script includes robust error handling:

- **Access Denied**: Logged as warnings, script continues processing
- **Network Issues**: Stops execution with detailed error message
- **Missing Folders**: Exits gracefully with warning
- **Unexpected Errors**: Captured with full stack trace in log file

## Troubleshooting

### Script Won't Run
- Ensure PowerShell execution policy allows script execution:
  ```powershell
  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
  ```

### Access Denied Errors
- Check that your account has read permissions on the network share
- Review the log file for specific paths that were denied
- Contact your network administrator if needed

### Network Share Not Accessible
- Verify the UNC path is correct
- Test access manually: `Test-Path "\\server\share"`
- Ensure network connectivity to the server

### Performance on Large Shares
- The script uses `-Force` to include hidden files (can be removed if not needed)
- Large folder structures may take significant time to scan
- Progress indicator shows real-time status

## Output Files

### CSV Report Fields

| Field | Description |
|-------|-------------|
| **FolderName** | Name of the top-level folder |
| **FolderPath** | Full UNC path to the folder |
| **NewestModifiedDate** | Most recent LastWriteTime found in the entire folder tree |
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

### Version 1.0.0 (2025-11-13)
- Initial release
- Recursive folder scanning
- CSV export functionality
- Comprehensive logging
- Progress indicators
- Error handling for access denied scenarios

## Author

**Bryan Jackson**

## License

This script is provided as-is for use in IT automation and administration tasks.

## Contributing

Suggestions and improvements are welcome! Please feel free to submit issues or pull requests.

## Use Cases

This script is particularly useful for:
- **Storage cleanup planning** - Identify folders with recent activity
- **Archive management** - Find folders that haven't been modified recently
- **Compliance reporting** - Document last modification dates for audit purposes
- **Capacity planning** - Understand which areas of the share are actively used
- **Migration planning** - Identify active vs. stale data before migration projects

## Notes

- The script uses `Get-ChildItem -Recurse -Force` which includes hidden and system files
- Access denied folders are skipped and logged, but don't stop the script
- Results are sorted by newest modified date (most recent first)
- Both the CSV report and log file include timestamps in their filenames to prevent overwrites

## Support

For issues, questions, or feature requests, please open an issue in this repository.
