# NinjaRMM RunAs Credential Reference

When using the API Endpoint `/api/v2/device/{id}/script/run`, the `runAs` parameter is case-sensitive.

## Available RunAs Values

| Value | Description |
|-------|-------------|
| `system` | `general.system` - Runs as SYSTEM account |
| `SR_MAC_SCRIPT` | `general.system` - For Mac scripts |
| `SR_LINUX_SCRIPT` | `general.system` - For Linux scripts |
| `loggedonuser` | `editor.credentials.currentLoggedOnUser` - Runs as current logged-on user |
| `SR_LOCAL_ADMINISTRATOR` | `editor.credentials.preferredWindowsLocalAdmin` - Local admin credentials |
| `SR_DOMAIN_ADMINISTRATOR` | `editor.credentials.preferredWindowsDomainAdmin` - Domain admin credentials |
| `"string"` (e.g., `"26"`) | `editor.credentials.preferredCredential` - Custom credential ID |

## Custom Credential IDs

To find a custom credential ID:
1. Go to NinjaRMM UI
2. Drill down on the user account
3. Look at the account page URL (e.g., `https://app.ninjarmm.com/#/editor/user/15/general`)
4. The number in the URL is the credential ID
5. Use that number as the `runAs` value (e.g., `"26"`)

## Example Usage in Rewst

For running a PowerShell script as SYSTEM:
```
Run As: system
```

For running as a specific credential:
```
Run As: 26
```

## Source
From Rewst/NinjaRMM community (Mikey/homotechsual) - May 2023
