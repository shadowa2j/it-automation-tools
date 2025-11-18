# Network & System Administration Tools

**Category:** Network Administration & Endpoint Management  
**Author:** Bryan Faulkner, with assistance from Claude  
**Last Updated:** 2025-11-06

---

## 📋 Overview

This folder contains scripts for network administration, endpoint management, and system configuration across Windows environments.

---

## 🎯 Focus Areas

### Endpoint Security
- SentinelOne configuration management
- Security policy deployment
- Threat detection reporting
- Agent status monitoring

### Remote Desktop Services
- Terminal server session management
- RDP connection monitoring
- Printer deployment automation
- User session reporting

### System Configuration
- Group policy automation
- Registry modifications
- Service management
- Scheduled task creation

### Network Monitoring
- Connectivity testing
- Bandwidth monitoring
- DNS troubleshooting
- Network path analysis

---

## 🔧 Planned Script Categories

### Session Management
Tools for managing Remote Desktop sessions:
- Active session enumeration
- Forced logoff utilities
- Session state reporting
- User activity monitoring

### Printer Management
Scripts for print infrastructure:
- Zebra driver removal
- Printer deployment
- Driver cleanup automation
- Print queue monitoring

### Window Recovery
Utilities for window management:
- Off-screen window detection
- Window position recovery
- Multi-monitor fixes
- Display configuration

### Security Management
Endpoint security tools:
- SentinelOne configuration
- Policy enforcement
- Agent deployment
- Status reporting

---

## 🖥️ Target Environments

### Terminal Servers
- Windows Server 2016/2019/2022
- Remote Desktop Services
- Multi-session environments

### Workstations
- Windows 10/11
- Domain-joined systems
- Remote workforce endpoints

### Managed Services Clients
- Prism Plastics
- Wilbert Plastics
- Marmon Plastics
- Multi-tenant environments

---

## 🔒 Security Considerations

### Privileged Operations
Many scripts require elevated privileges:
- Run as Administrator when needed
- Use least-privilege accounts when possible
- Document required permissions
- Audit script execution

### Network Security
- Validate endpoints before connection
- Use secure protocols (WinRM, HTTPS)
- Encrypt sensitive data in transit
- Log all administrative actions

---

## 🚧 Status

**In Development:** Scripts will be added as network administration needs arise

**Planned Scripts:**
- RDP session management
- Zebra driver removal utility
- Off-screen window recovery
- SentinelOne configuration tools
- Terminal server monitoring

---

## 📞 Support

For network/system issues:
- Verify administrative privileges
- Check network connectivity
- Review event logs
- Test on single endpoint first
- Document any errors

---

**Scripts in this folder:** Coming soon  
**PowerShell Version Required:** 5.1+  
**Common Modules Used:** ActiveDirectory, GroupPolicy, RemoteDesktop
