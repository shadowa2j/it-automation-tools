# PowerShell Utilities

General-purpose PowerShell scripts for system administration tasks.

## Scripts

### Invoke-RDUserLogoff-Multi.ps1
**Purpose:** Log off multiple Remote Desktop sessions across multiple terminal servers

**Version:** 1.0.0

#### Parameters
- `Servers` (optional) - Array of terminal server FQDNs
  - Default: wps-inap-ts02w, wps-inap-ts03w, wps-inap-tes05w (all in wilbertinc.prv domain)
- `SessionIDs` (required) - Array of session IDs to log off

#### Features
- ✅ Multi-server support
- ✅ Force logoff capability
- ✅ Error handling with try/catch
- ✅ Colored console output (Green = success, Red = error)
- ✅ Progress indicators for each server
- ✅ Handles non-existent session IDs gracefully

#### Usage Examples

**Basic usage with default servers:**
```powershell
.\Invoke-RDUserLogoff-Multi.ps1 -SessionIDs 1715,1716,1717
```

**Custom servers:**
```powershell
$MyServers = @("server1.domain.com", "server2.domain.com")
.\Invoke-RDUserLogoff-Multi.ps1 -Servers $MyServers -SessionIDs 1715,1716
```

**Single server:**
```powershell
.\Invoke-RDUserLogoff-Multi.ps1 -Servers @("wps-inap-ts02w.wilbertinc.prv") -SessionIDs 1715
```

#### Prerequisites
- Remote Desktop Services PowerShell module
- Administrative access to terminal servers
- Network connectivity to target servers

#### Output Example
```
=== Remote Desktop Session Logoff Tool ===
Starting logoff process for 3 session(s) across 3 server(s)

Processing server: wps-inap-ts02w.wilbertinc.prv
  ✓ Successfully logged off session 1715
  ✗ Failed to log off session 1716 - Session not found
  ✓ Successfully logged off session 1717

Processing server: wps-inap-ts03w.wilbertinc.prv
  ✓ Successfully logged off session 1715
  ✓ Successfully logged off session 1716
  ✓ Successfully logged off session 1717

Logoff process complete!
===========================================
```

#### Error Handling
The script gracefully handles:
- Non-existent session IDs
- Unreachable servers
- Permission issues
- Network timeouts

Each error is displayed in red with the specific error message.

#### Safety Notes
- Uses `-Force` parameter to immediately log off sessions
- Users will lose unsaved work
- No confirmation prompts
- Recommended for administrative cleanup, not routine operations

#### Common Use Cases
- Cleaning up stuck RDP sessions
- Administrative maintenance windows
- Troubleshooting terminal server issues
- Bulk session termination during upgrades

---

## Environment

These scripts are used primarily in:
- **Wilbert Plastics** - Terminal server management
- Multiple Windows Server environments with RDS deployments

---

## Contributing

To add new utility scripts:
1. Follow the same documentation format
2. Include version history
3. Add comprehensive examples
4. Document all parameters
5. Include error handling

---

**Folder Version:** 1.0.0  
**Last Updated:** November 6, 2025  
**Maintainer:** Bryan Faulkner
