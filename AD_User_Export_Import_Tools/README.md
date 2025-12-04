# AD User Export and Import Tools

PowerShell scripts for bulk exporting and importing Active Directory user accounts with all attributes, plus specialized tools for phone number management.

## Overview

This toolkit provides complementary scripts for managing Active Directory user data:
- **Export-ADUsersFromOU.ps1** - Export all users from an OU (and sub-OUs) with all attributes to CSV
- **Import-ADUsersFromCSV.ps1** - Import and update AD users from CSV with extensive validation and safety features
- **Export-WilbertUsersPhoneNumbers.ps1** - Export phone numbers for Wilbert users from specific OU
- **Update-PhoneNumbersFromSignatures.ps1** - Match and update phone numbers from external data sources
- **Update-ADPhoneNumbers.ps1** - Bulk update Active Directory phone numbers with logging and WhatIf support

## Features

### Export Script
- ✅ Exports all users from specified OU including sub-OUs
- ✅ Captures ALL user attributes (not just common ones)
- ✅ Automatic timestamp in filename
- ✅ Comprehensive logging
- ✅ OU validation before export
- ✅ UTF-8 encoding for international characters

### Import Script
- ✅ **WhatIf mode** for safe testing
- ✅ Confirmation prompt before changes
- ✅ Automatic exclusion of read-only/system attributes
- ✅ Multi-valued attribute support (proxyAddresses, etc.)
- ✅ Flexible identity matching (SamAccountName, UPN, or DN)
- ✅ Selective attribute updates
- ✅ Detailed change logging
- ✅ Error tracking with separate error log
- ✅ Progress indicator for large batches

### Phone Number Management Tools

#### Export-WilbertUsersPhoneNumbers.ps1
- ✅ Exports enabled users from specific Wilbert OU structure
- ✅ Excludes TEST OU users automatically
- ✅ Exports all phone-related fields (Office, Mobile, Home, ipPhone, Pager, Fax)
- ✅ Provides statistics on phone number coverage
- ✅ Timestamped output files

#### Update-PhoneNumbersFromSignatures.ps1
- ✅ Matches users by first and last name
- ✅ Formats all phone numbers to standard (xxx) xxx-xxxx format
- ✅ Automatically skips invalid entries (N/A, "no phone", etc.)
- ✅ Handles both Office Phone and Mobile Phone updates
- ✅ Provides detailed matching statistics

#### Update-ADPhoneNumbers.ps1
- ✅ **WhatIf mode** for safe testing before changes
- ✅ Updates only OfficePhone and MobilePhone in Active Directory
- ✅ Detailed timestamped logging to file
- ✅ Color-coded console output
- ✅ Comprehensive error handling and statistics
- ✅ Only updates when values differ (smart change detection)

## Requirements

- Windows PowerShell 5.1 or PowerShell 7+
- Active Directory PowerShell Module
- Appropriate AD permissions (read for export, write for import)
- For import: Run as Administrator recommended

## Installation

1. Download the scripts to your preferred location
2. Unblock the files if downloaded from the internet:
   ```powershell
   Unblock-File -Path .\*.ps1
   ```

## Usage

### Exporting Users

**Basic export:**
```powershell
.\Export-ADUsersFromOU.ps1 -SearchBase "OU=Users,DC=contoso,DC=com"
```

**Export with custom output path:**
```powershell
.\Export-ADUsersFromOU.ps1 -SearchBase "OU=Users,DC=contoso,DC=com" -OutputPath "C:\Exports\ADUsers.csv"
```

**Export Wilbert users with phone numbers:**
```powershell
.\Export-WilbertUsersPhoneNumbers.ps1
# Outputs to current directory with timestamp
```

### Importing/Updating Users

**Test run (recommended first step):**
```powershell
.\Import-ADUsersFromCSV.ps1 -CsvPath "C:\Exports\ADUsers.csv" -WhatIf
```

**Full update with confirmation:**
```powershell
.\Import-ADUsersFromCSV.ps1 -CsvPath "C:\Exports\ADUsers.csv"
```

**Update specific attributes only:**
```powershell
.\Import-ADUsersFromCSV.ps1 -CsvPath "C:\Exports\ADUsers.csv" -UpdateSpecificAttributes @("Title","Department","Manager","Office")
```

### Phone Number Management Workflow

**Complete phone number update workflow:**
```powershell
# 1. Export current AD phone data
.\Export-WilbertUsersPhoneNumbers.ps1

# 2. Match with external source (e.g., email signatures)
.\Update-PhoneNumbersFromSignatures.ps1 `
    -ADExportPath ".\WilbertUsers_PhoneNumbers_20251204_084939.csv" `
    -SignaturePath ".\Email_Signatures.csv"

# 3. Test the AD update
.\Update-ADPhoneNumbers.ps1 `
    -CSVPath ".\WilbertUsers_PhoneNumbers_Updated_20251204_090000.csv" `
    -WhatIf

# 4. Apply the changes
.\Update-ADPhoneNumbers.ps1 `
    -CSVPath ".\WilbertUsers_PhoneNumbers_Updated_20251204_090000.csv"
```

## Workflow Examples

### Scenario 1: Bulk Update User Attributes
```powershell
# 1. Export current users
.\Export-ADUsersFromOU.ps1 -SearchBase "OU=Sales,OU=Users,DC=contoso,DC=com"

# 2. Edit the CSV in Excel (update Department, Title, etc.)

# 3. Test the import
.\Import-ADUsersFromCSV.ps1 -CsvPath ".\ADUsers_Export_20251111_143022.csv" -WhatIf

# 4. Apply the changes
.\Import-ADUsersFromCSV.ps1 -CsvPath ".\ADUsers_Export_20251111_143022.csv"
```

### Scenario 2: Update Phone Numbers from External Source
```powershell
# 1. Export current AD phone data
.\Export-WilbertUsersPhoneNumbers.ps1

# 2. Match and format phone numbers from external source
.\Update-PhoneNumbersFromSignatures.ps1 `
    -ADExportPath ".\WilbertUsers_PhoneNumbers_20251204_084939.csv" `
    -SignaturePath ".\External_Phone_List.csv"

# 3. Preview changes
.\Update-ADPhoneNumbers.ps1 `
    -CSVPath ".\WilbertUsers_PhoneNumbers_Updated_20251204_090000.csv" `
    -WhatIf

# 4. Apply to Active Directory
.\Update-ADPhoneNumbers.ps1 `
    -CSVPath ".\WilbertUsers_PhoneNumbers_Updated_20251204_090000.csv"
```

### Scenario 3: Update Only Contact Information
```powershell
# Export users
.\Export-ADUsersFromOU.ps1 -SearchBase "OU=Users,DC=contoso,DC=com"

# Edit phone numbers, addresses, etc. in CSV

# Update only contact fields
.\Import-ADUsersFromCSV.ps1 -CsvPath ".\ADUsers_Export_20251111_143022.csv" `
    -UpdateSpecificAttributes @("telephoneNumber","mobile","streetAddress","city","state","postalCode")
```

## Important Notes

### Read-Only Attributes
The import script automatically excludes system-managed and read-only attributes, including:
- ObjectGUID, ObjectSID, DistinguishedName
- Timestamps (whenCreated, whenChanged, lastLogon, etc.)
- Password-related attributes (pwdLastSet, badPasswordTime, etc.)
- Account control computed values

### Multi-Valued Attributes
Attributes like `proxyAddresses` are exported as semicolon-separated values and properly handled during import.

### Phone Number Formatting
The phone number tools automatically format all US phone numbers to **(xxx) xxx-xxxx** format and skip invalid entries like "N/A", "no phone", etc.

### Identity Matching
The import script attempts to match users in this order:
1. SamAccountName (preferred)
2. UserPrincipalName
3. DistinguishedName

## Logging

Scripts create detailed logs:
- **Export**: `ADExport_Log_YYYYMMDD_HHMMSS.txt`
- **Import**: `ADImport_Log_YYYYMMDD_HHMMSS.txt` and `ADImport_Errors_YYYYMMDD_HHMMSS.csv` (if errors)
- **Phone Updates**: `ADPhoneUpdate_Log_YYYYMMDD_HHMMSS.txt`

## Security Considerations

- Always test with `-WhatIf` before making changes
- Review the CSV carefully before importing
- Keep backups of exported data
- Use appropriate AD permissions (principle of least privilege)
- Logs may contain sensitive information - store securely

## Troubleshooting

### "Cannot find path" error
Ensure the SearchBase DN is correct and you have permissions to read it.

### "User not found" during import
Verify the identity column (SamAccountName, UPN, or DN) exists and is correct in the CSV.

### Attributes not updating
Check if the attribute is in the excluded list. Some attributes cannot be set via `Set-ADUser`.

### Permission denied
Run PowerShell as Administrator and ensure you have write permissions in AD.

## Version History

### Version 1.1 (2025-12-04)
- Added Export-WilbertUsersPhoneNumbers.ps1 for targeted phone number exports
- Added Update-PhoneNumbersFromSignatures.ps1 for matching external data sources
- Added Update-ADPhoneNumbers.ps1 for bulk AD phone number updates with logging
- Enhanced phone number formatting and validation

### Version 1.0 (2025-11-11)
- Initial release
- Full export functionality with all attributes
- Import with WhatIf, validation, and error handling
- Multi-valued attribute support
- Comprehensive logging

## Authors

**Bryan - Quality Computer Solutions**

## License

These scripts are provided as-is for use in your environment. Modify as needed for your specific requirements.

## Contributing

Feel free to submit issues, fork, and create pull requests for improvements.

## Disclaimer

These scripts modify Active Directory. Always test in a non-production environment first and maintain proper backups. The authors are not responsible for any data loss or issues arising from the use of these scripts.
