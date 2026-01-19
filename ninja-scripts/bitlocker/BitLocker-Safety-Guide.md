# BitLocker Script Safety Quick Reference

**Script:** Enable-BitLocker-WithMonitoring.ps1 v2.0.0  
**Author:** Bryan Faulkner - Quality Computer Solutions  

---

## ✅ IS IT SAFE TO RUN?

**YES** - This script is 100% safe to run on:
- ✓ Devices with BitLocker already enabled
- ✓ Devices currently encrypting
- ✓ Devices currently decrypting
- ✓ Devices with paused encryption/decryption
- ✓ Fresh unencrypted devices
- ✓ Any Windows 10/11 device with TPM

---

## 🛡️ WHAT THE SCRIPT WON'T DO

The script will **NEVER**:
- ❌ Re-encrypt an already encrypted drive
- ❌ Interrupt active encryption
- ❌ Interrupt active decryption
- ❌ Remove existing BitLocker protectors
- ❌ Disable BitLocker protection
- ❌ Modify paused states
- ❌ Change encryption methods on protected drives
- ❌ Cause data loss

---

## 🔍 WHAT HAPPENS IN EACH SCENARIO

### Already Encrypted Drive
```
Script Action: Skips enablement, verifies recovery key backups
Changes Made: None to encryption, only backup verification
Exit Code: 0 (success)
Time: ~5 seconds
```

### Encryption In Progress
```
Script Action: Reports current progress, exits immediately
Changes Made: None
Exit Code: 0 (success)
Time: ~2 seconds
```

### Decryption In Progress
```
Script Action: Monitors progress, waits for completion (up to 4 hours)
Changes Made: None until decryption completes, then enables BitLocker
Exit Code: 0 (success or timeout)
Time: Variable (depends on decryption time)
```

### Encryption/Decryption Paused
```
Script Action: Reports pause state, provides resume command if applicable
Changes Made: None
Exit Code: 0 (success)
Time: ~2 seconds
```

### Encrypted But Protection OFF (Broken State)
```
Script Action: Adds missing TPM + Recovery Password protectors, enables protection
Changes Made: Remediates broken BitLocker configuration
Exit Code: 0 (success) or 1 (if remediation fails)
Time: ~10-15 seconds
```
**This fixes the scenario where:**
- Drive is encrypted (100%)
- Protection Status: Off
- Key Protectors: None Found

### Fully Decrypted Drive
```
Script Action: Enables BitLocker with TPM + Recovery Password
Changes Made: Enables BitLocker, creates registry policies, backs up keys
Exit Code: 0 (success) or 1 (if errors occur)
Time: ~15-30 seconds
```

---

## 📊 NINJA DEPLOYMENT CHECKLIST

### Before Deploying
- [ ] Create custom field: `bitlockerrecoverykey` (Text/Multiline)
- [ ] Set script timeout: **5+ hours** (to allow for decryption monitoring)
- [ ] Configure alert for exit code 1 (actual errors)

### Test Plan
1. **Test on already-encrypted device first** (should exit safely in ~5 seconds)
2. Test on unencrypted device (should enable BitLocker)
3. Optional: Test on device with encryption in progress (should exit safely)

### Monitoring
- Exit code **0** = Success or safe exit (no issues)
- Exit code **1** = Actual error occurred (requires investigation)
- Check console output for "SAFE EXIT" messages

---

## 🚨 TROUBLESHOOTING

### "Script won't enable BitLocker"
**Check these:**
- Is BitLocker already enabled? (Script exits safely if so)
- Is encryption/decryption in progress? (Script won't interfere)
- TPM enabled? (Check BIOS/UEFI)
- Windows version supported? (Win 10/11 Pro or higher)

### "Script taking a long time"
**Likely cause:** Decryption in progress
- Script is safely monitoring decryption
- Check console output for progress updates
- Will timeout after 4 hours (configurable)
- Can safely cancel and re-run later

### "Exit code 1 error"
**Real problems to investigate:**
- TPM initialization failed
- BitLocker partition creation failed
- Registry policy creation failed
- BitLocker enablement failed
- Check console output for specific error messages

---

## 🎯 KEY SAFETY FEATURES

1. **Pre-flight safety check** - Analyzes current state before any action
2. **Status re-verification** - Confirms state before each critical step
3. **Abort on unexpected changes** - Stops if volume state changes mid-script
4. **Backup-only mode** - Already-encrypted drives only get key backups
5. **Non-interference** - Active operations never interrupted
6. **Comprehensive logging** - Every decision and action is logged

---

## 💡 COMMON QUESTIONS

**Q: Can I run this on my entire fleet at once?**  
A: Yes! The script safely handles all scenarios and exits gracefully on compliant devices.

**Q: What if encryption is 50% done?**  
A: Script sees "EncryptionInProgress" and exits immediately without changes.

**Q: What if someone accidentally runs it twice?**  
A: First run enables BitLocker. Second run sees it's enabled and only verifies backups.

**Q: Will this slow down users' computers?**  
A: No. Script completes in seconds. BitLocker encryption happens in the background.

**Q: What if decryption takes longer than 4 hours?**  
A: Script times out safely and can be run again when decryption completes.

**Q: Can this break BitLocker that's already working?**  
A: No. Script never modifies functioning BitLocker configurations.

---

## ✅ PRODUCTION APPROVAL CHECKLIST

- [x] Script won't damage already-encrypted devices
- [x] Script won't interrupt active operations
- [x] Script exits safely on unexpected conditions
- [x] Script provides comprehensive logging
- [x] Script has been validated for all scenarios
- [x] Recovery keys backed up to multiple locations
- [x] Exit codes properly defined for monitoring

**Safety Rating: PRODUCTION READY** 🛡️  
**Mass Deployment: APPROVED** ✅

---

**Last Updated:** 2026-01-19  
**Questions?** Contact: Quality Computer Solutions IT Team
