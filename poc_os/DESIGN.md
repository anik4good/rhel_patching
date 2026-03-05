# RHEL OS Version Patching POC - Design Document

**Date:** March 5, 2026
**Version:** 1.0
**Status:** Design Approved

---

## Overview

Create a separate proof of concept demonstrating RHEL OS minor version upgrade (9.0 → 9.4) with failure handling scenarios. This complements the existing package-level patching POC by showing OS-level upgrade capabilities.

### Purpose

Demonstrate to the client that the Ansible patching automation can handle:
- Full OS version upgrades (not just individual packages)
- Pre-upgrade validation and safety checks
- Upgrade failure detection and handling
- Reboot management and post-reboot validation
- Clear rollback procedures

### Client Concern Addressed

**"If patching fails, what will the playbook do?"**

This POC shows failure handling specifically for OS upgrades, which are more complex and risky than package updates.

---

## Architecture

### Folder Structure

```
poc_os/
├── DESIGN.md                    (This document)
├── README.md                    (User guide for OS patching)
├── QUICKSTART.md                (Quick reference)
├── site.yml                     (Main playbook with 3 scenarios)
├── ansible.cfg                  (Ansible configuration)
├── inventory                    (Sample inventory file)
└── scenarios/
    ├── success.yml              (TC-OS-001: Successful 9.0 → 9.4 upgrade)
    ├── precheck_fail.yml        (TC-OS-002: Pre-check validation failure)
    └── upgrade_fail.yml         (TC-OS-003: DNF upgrade fails mid-process)
```

### Design Principles

1. **Consistent with Package POC** - Same structure, messaging, error handling style
2. **Based on Proven Playbook** - Derived from existing [patching_old_v1.yaml](../patching_old_v1.yaml)
3. **Assumes Pre-Configured Repos** - User manually sets up 9.4 repositories
4. **Real Upgrades Only** - No simulations, actual `dnf upgrade --releasever=9.4`
5. **Reboot-Aware** - Detects and handles reboots properly

---

## Scenarios

### TC-OS-001: Successful OS Upgrade (9.0 → 9.4)

**Purpose:** Demonstrate complete OS upgrade workflow

**Phases:**
1. **Pre-Check Validation**
   - Check current OS version (`cat /etc/redhat-release`)
   - Verify disk space (>10% free required)
   - Verify repository accessibility
   - Check for available updates

2. **Upgrade Execution**
   - Run `dnf upgrade --releasever=9.4 -y`
   - Use async/poll for long-running operation
   - Log upgrade attempt

3. **Post-Upgrade Validation**
   - Verify new OS version
   - Check kernel version (`uname -r`)
   - Detect if reboot required (`needs-restarting -r`)

4. **Reboot (if needed)**
   - Reboot system using `ansible.builtin.reboot`
   - Wait for system to come back online
   - Verify connectivity restored

5. **Final Validation**
   - Confirm OS version after reboot
   - Verify critical services running
   - Generate summary report

**Expected Outcome:**
- System upgraded from 9.0 to 9.4
- Reboot executed if required
- All services running after upgrade
- Clear before/after version comparison

---

### TC-OS-002: Pre-Check Validation Failure

**Purpose:** Demonstrate stopping before upgrade when validation fails

**Failure Triggers (choose one):**
- Disk space > 90% used
- Repository not accessible
- System already at target version
- Subscription not active

**Phases:**
1. **Pre-Check Validation**
   - All checks from success scenario
   - One check intentionally fails

2. **Immediate Stop**
   - Playbook halts at pre-check
   - Clear error message displayed
   - No upgrade attempted

3. **System State**
   - No changes made to system
   - Original OS version intact
   - Clear guidance on what needs fixing

**Expected Outcome:**
- Upgrade NOT attempted
- System unchanged
- Clear error message explaining the issue
- No risk to system

---

### TC-OS-003: Upgrade Failure Mid-Process

**Purpose:** Demonstrate handling when DNF upgrade fails

**Failure Triggers:**
- Repository metadata corrupted
- Network interruption during download
- Package dependency conflict
- Insufficient disk space during unpacking

**Phases:**
1. **Pre-Check** (all pass)
   - Validation succeeds
   - Upgrade begins

2. **Upgrade Execution** (fails)
   - `dnf upgrade` command starts
   - Fails partway through
   - Rescue block activated

3. **Failure Handling**
   - Error logged with details
   - System state documented
   - Rollback guidance provided
   - Execution stops

4. **System State**
   - May be in partial upgrade state
   - Backup/repository still available
   - Clear recovery instructions

**Expected Outcome:**
- Upgrade failure detected and logged
- Rescue block handles error gracefully
- System remains functional (no complete failure)
- Clear rollback/recovery steps provided

---

## Key Variables

### Common Variables (site.yml)

```yaml
vars:
  # OS Upgrade Settings
  current_version: "9.0"           # Starting version
  target_version: "9.4"            # Target version

  # Validation Settings
  disk_threshold: 90               # Fail if > 90% used
  min_memory_mb: 2048              # Minimum memory required

  # Reboot Settings
  reboot_timeout: 600              # Max seconds to wait for reboot
  pre_reboot_delay: 10             # Seconds before reboot
  max_reboot_retries: 3            # Retry attempts

  # Logging
  log_file: "/var/log/rhel_os_upgrade.log"
  summary_file: "/tmp/rhel_os_upgrade_summary_{{ inventory_hostname }}.txt"
```

### Scenario-Specific Variables

**Success Scenario:**
```yaml
perform_upgrade: true
skip_reboot: false
```

**Pre-Check Fail:**
```yaml
simulate_disk_full: true          # OR
simulate_repo_unavailable: true   # Choose one
```

**Upgrade Fail:**
```yaml
corrupt_repo: true                 # Simulate corruption
break_network: false               # Alternative: network failure
```

---

## Commands and Validations

### Version Detection

**Before:**
```bash
cat /etc/redhat-release
# Output: Red Hat Enterprise Linux release 9.0 (Plow)
```

**After:**
```bash
cat /etc/redhat-release
# Output: Red Hat Enterprise Linux release 9.4 (Neon)
```

### Kernel Version Check

```bash
uname -r
# Example: 5.14.0-284.11.1.el9_2.x86_64
```

### Reboot Detection

```bash
/usr/bin/needs-restarting -r
# Returns 0 if no reboot needed
# Returns non-zero if reboot required
```

### Update Availability Check

```bash
dnf check-update --releasever=9.4
# Lists available packages for upgrade
```

---

## Comparison: Package POC vs OS POC

| Aspect | Package POC (`poc/`) | OS POC (`poc_os/`) |
|--------|----------------------|-------------------|
| **Target** | Individual packages (nginx) | Entire OS |
| **Version Check** | `rpm -q nginx` | `cat /etc/redhat-release` |
| **Upgrade Command** | `dnf install nginx` | `dnf upgrade --releasever=9.4` |
| **Reboot Required** | No | Yes (usually) |
| **Validation** | Service status | Kernel + OS version |
| **Duration** | Seconds to minutes | 10-30 minutes |
| **Risk Level** | Low | Medium |
| **Rollback** | Package downgrade | VM snapshot revert |

---

## Safety Features

### Pre-Flight Checks

| Check | Threshold | Action on Failure |
|-------|-----------|-------------------|
| Disk space | ≤90% used | Stop |
| Repository access | Reachable | Stop |
| Subscription status | Active | Stop |
| Current version | < target version | Stop if already at target |
| Memory | ≥2048 MB | Warn |

### Execution Controls

| Feature | Configuration | Benefit |
|---------|---------------|---------|
| Serial execution | `serial: 1` | One server at a time |
| Stop on failure | `max_fail_percentage: 0` | No cascade |
| Async upgrade | `async: 3600, poll: 10` | Handle long operations |
| Reboot management | `ansible.builtin.reboot` | Controlled reboot |
| Block/rescue | Error handling | Graceful failures |

### Error Detection Points

| Phase | Validation | Failure Action |
|-------|------------|----------------|
| Pre-check | Disk, repo, subscription | Stop immediately |
| Upgrade | DNF exit code | Activate rescue, stop |
| Post-upgrade | Version check | Log warning, continue |
| Reboot check | `needs-restarting -r` | Reboot if needed |
| Post-reboot | Connectivity, services | Fail if issues |

---

## Documentation Files

### README.md

**Contents:**
- Overview of OS patching POC
- Architecture diagram
- Prerequisites (repo setup, VM snapshots)
- Detailed explanation of each scenario
- Safety features explanation
- Troubleshooting guide

### QUICKSTART.md

**Contents:**
- Pre-test checklist (VM snapshot, repo verification)
- Quick run commands for each scenario
- Expected outputs
- Common issues and fixes
- Recovery procedures

---

## Rollback Procedures

### Option 1: VM Snapshot (Recommended)

```bash
# Revert to pre-upgrade state
virsh snapshot-revert <domain> <snapshot-name>

# Verify version
cat /etc/redhat-release
```

### Option 2: Manual Rollback (Not Recommended)

```bash
# This is complex and error-prone
# Use VM snapshot instead
```

### Option 3: Re-upgrade to Previous Version

```bash
# If 9.0 repo still available
dnf upgrade --releasever=9.0 --allowerasing
```

---

## Success Criteria

The POC is successful when:

1. ✅ All 3 scenarios execute as designed
2. ✅ Success scenario shows complete 9.0 → 9.4 upgrade
3. ✅ Pre-check fail scenario stops before upgrade
4. ✅ Upgrade fail scenario handles errors gracefully
5. ✅ Reboot detection and management works correctly
6. ✅ Documentation is clear and comprehensive
7. ✅ Client can demonstrate failure handling
8. ✅ Test cases document updated with OS scenarios

---

## Implementation Notes

### Repository Assumptions

- User manually configures RHEL 9.4 repository before running
- Repository contains complete 9.4 packages
- Repository is accessible from target systems
- No repo setup automation in playbooks

### VM Snapshot Requirement

**Critical:** All scenarios require VM snapshots before execution
- Allows safe testing of failure scenarios
- Enables quick rollback
- Protects test systems

### Reboot Behavior

- Reboot only happens in success scenario
- Uses `ansible.builtin.reboot` module
- Waits up to 600 seconds for system to return
- Retries up to 3 times if needed

---

## Next Steps

1. ✅ Design approved
2. ⏭️ Create implementation plan
3. ⏭️ Implement playbooks
4. ⏭️ Test all scenarios
5. ⏭️ Write documentation
6. ⏭️ Update test cases docx

---

**Document Control**

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0 | Mar 5, 2026 | Initial design | Automation Team |

---

**End of Design Document**
