# RHEL OS Version Upgrade POC

**Version:** 2.0
**Date:** March 6, 2026
**Purpose:** Proof of concept for RHEL OS minor version upgrade automation (9.0 → 9.x)

---

## Overview

This POC demonstrates automated RHEL OS version upgrades with comprehensive failure handling. It addresses the client's primary concern: **"If patching fails, what will the playbook do?"**

### What This Demonstrates

| Capability | Test Case | Scenario |
|------------|-----------|----------|
| **Successful OS upgrade** | TC-OS-001 | Complete 9.0 → 9.x upgrade with reboot |
| **Pre-flight validation** | TC-OS-002 | Stops before upgrade when disk space insufficient |
| **Upgrade failure handling** | TC-OS-003 | Handles DNF upgrade failures mid-process |
| **Post-upgrade validation** | TC-OS-004 | Detects stopped services after upgrade |

### Key Features

- ✅ **Flexible version targeting** - Upgrade to any RHEL 9.x version (9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 9.7)
- ✅ **Multiple repository support** - CDN, Satellite, or Jump Server (all pre-configured)
- ✅ **Pre-flight validation** - Disk space checks before upgrade
- ✅ **Failure simulation** - Realistic failure scenarios with rescue blocks
- ✅ **Service validation** - Detects ALL stopped services after upgrade
- ✅ **Comprehensive reporting** - Summary files with before/after information
- ✅ **HTML report generation** - Professional HTML reports for each run

---

## Architecture

### Repository Options

The playbook supports 3 repository types (all assumed pre-configured):

| Type | Description | Usage |
|------|-------------|-------|
| **cdn** | Red Hat CDN (default) | `-e "repo_type_input=cdn"` |
| **satellite** | Red Hat Satellite (already configured) | `-e "repo_type_input=satellite"` |
| **jump** | Jump Server (already configured) | `-e "repo_type_input=jump"` |

### Version Support

The playbook supports upgrading to any RHEL 9.x version:

```bash
-e "target_version=9.1"  # Upgrade to 9.1
-e "target_version=9.2"  # Upgrade to 9.2
-e "target_version=9.3"  # Upgrade to 9.3
-e "target_version=9.4"  # Upgrade to 9.4 (default)
-e "target_version=9.5"  # Upgrade to 9.5
-e "target_version=9.6"  # Upgrade to 9.6
-e "target_version=9.7"  # Upgrade to 9.7
```

---

## Prerequisites

### Test Systems

- RHEL 9.0 system (for testing)
- Target version repository configured (e.g., 9.1, 9.4, 9.7)
- Root or sudo access
- SSH connectivity
- **VM snapshot created before testing** (critical for failure scenarios)

### Repository Setup

**IMPORTANT:** You must manually configure the target RHEL repository before running these playbooks. The playbooks assume the repository is already configured.

#### Option 1: Red Hat CDN (Default)

```bash
# Register to Red Hat CDN
subscription-manager register
subscription-manager attach --auto

# Enable required repositories
subscription-manager repos --enable=rhel-9-for-x86_64-baseos-rpms
subscription-manager repos --enable=rhel-9-for-x86_64-appstream-rpms
```

#### Option 2: Satellite (Already Configured)

```bash
# Verify Satellite repositories are configured
dnf repolist

# Should show your Satellite repositories
```

#### Option 3: Jump Server (Already Configured)

```bash
# Verify jump server repositories are configured
dnf repolist

# Should show your jump server repositories
```

---

## Quick Start

### Success Scenario - OS Upgrade

```bash
# Upgrade to RHEL 9.1 using jump server repos
ansible-playbook -i inventory site.yml --tags success \
  -e "target_version=9.1 repo_type_input=jump"

# Upgrade to RHEL 9.4 using satellite repos
ansible-playbook -i inventory site.yml --tags success \
  -e "target_version=9.4 repo_type_input=satellite"

# Upgrade to RHEL 9.7 using CDN (default)
ansible-playbook -i inventory site.yml --tags success \
  -e "target_version=9.7"
```

**What happens:**
1. ✅ Pre-checks (disk space, repository accessibility)
2. ✅ Clean DNF cache
3. ✅ Execute `dnf upgrade --releasever=<target_version>`
4. ✅ Reboot (if auto_reboot_extra=true)
5. ✅ Post-validation (version check, service health)
6. ✅ Generate summary report
7. ✅ Generate HTML report

### Pre-Check Failure Scenario

```bash
# Simulate disk space failure
ansible-playbook -i inventory site.yml --tags precheck_fail \
  -e "repo_type_input=jump"
```

**What happens:**
1. ✅ Disk space check fails (simulated 95% usage)
2. ✅ Playbook stops immediately
3. ✅ No upgrade attempted
4. ✅ Clear error message displayed
5. ✅ Failure report generated

### Upgrade Failure Scenario

```bash
# Simulate DNF upgrade failure
ansible-playbook -i inventory site.yml --tags upgrade_fail \
  -e "repo_type_input=jump"
```

**What happens:**
1. ✅ Pre-checks pass
2. ✅ Upgrade starts
3. ✅ Progress messages displayed
4. ✅ Simulated failure at 40% progress
5. ✅ Rescue block activates
6. ✅ Error logged clearly
7. ✅ Execution stops

### Post-Check Failure Scenario

```bash
# Simulate service validation failure
ansible-playbook -i inventory site.yml --tags postcheck_fail \
  -e "repo_type_input=jump"
```

**What happens:**
1. ✅ Pre-checks pass
2. ✅ Upgrade completes successfully
3. ✅ Service validation checks ALL enabled services
4. ✅ Detects stopped services (rsyslog, chronyd, etc.)
5. ✅ Reports all stopped services
6. ✅ Rollback instructions provided
7. ✅ Execution stops

---

## Variable Reference

| Variable | Default | Description |
|----------|---------|-------------|
| `target_version` | `9.4` | Target RHEL version to upgrade to |
| `repo_type_input` | `cdn` | Repository type: cdn, satellite, jump |
| `disk_threshold` | `90` | Maximum disk usage % allowed |
| `auto_reboot_extra` | `false` | Auto-reboot after upgrade |
| `reboot_timeout` | `600` | Reboot timeout in seconds |
| `pre_reboot_delay` | `10` | Delay before reboot in seconds |
| `simulate_disk_full` | `false` | Simulate disk space failure |
| `simulated_disk_usage` | `95` | Simulated disk usage % |

---

## Scenario Details

### TC-OS-001: Successful OS Upgrade

**Purpose:** Demonstrate complete OS upgrade workflow

**Steps:**
1. Pre-check validation (disk space, repository)
2. Get current OS version
3. Clean DNF cache
4. Execute `dnf upgrade --releasever=<target_version>`
5. Reboot (if enabled)
6. Post-validation (version, services)
7. Generate reports

**Expected Result:**
- Exit code: 0
- OS version changed from 9.0 to target_version
- Summary report generated
- HTML report generated

**Key Features Demonstrated:**
- ✅ Pre-flight validation
- ✅ Graceful OS upgrade
- ✅ Version verification
- ✅ Service health checks
- ✅ Comprehensive reporting

### TC-OS-002: Pre-Check Failure

**Purpose:** Demonstrate stop-before-damage behavior

**Failure Simulation:**
- Disk space check fails (95% usage simulated)

**Steps:**
1. Pre-check validation starts
2. Disk space check fails
3. Playbook stops immediately

**Expected Result:**
- Playbook stops at pre-check
- No upgrade attempted
- No system changes
- Clear error message

**Key Features Demonstrated:**
- ✅ Pre-flight validation gates
- ✅ Immediate stop on failure
- ✅ No damage to system
- ✅ Clear error reporting

### TC-OS-003: Upgrade Failure

**Purpose:** Demonstrate mid-upgrade failure handling

**Failure Simulation:**
- DNF upgrade fails at 40% with dependency conflict

**Steps:**
1. Pre-checks pass
2. Upgrade starts
3. Progress messages displayed
4. Simulated failure (dependency conflict)
5. Rescue block activates

**Expected Result:**
- Upgrade fails safely
- Rescue block handles error
- Playbook stops immediately
- Error details logged

**Key Features Demonstrated:**
- ✅ Block/rescue structure
- ✅ Graceful error handling
- ✅ Detailed error reporting
- ✅ Blast radius containment

### TC-OS-004: Post-Check Validation Failure

**Purpose:** Demonstrate post-upgrade service validation

**Failure Simulation:**
- Upgrade succeeds but services are stopped

**Steps:**
1. Pre-checks pass
2. Upgrade completes successfully
3. Service validation checks ALL enabled services
4. Detects stopped services

**Expected Result:**
- Installation succeeded but validation failed
- All stopped services reported
- Rollback instructions provided
- Execution stops

**Key Features Demonstrated:**
- ✅ Comprehensive service checking
- ✅ Post-validation layer
- ✅ Accurate failure detection
- ✅ Recovery guidance

**Services Checked:**
The playbook checks ALL enabled services on your system:
- rsyslog
- chronyd
- sshd
- systemd-journald
- dbus
- And all other enabled services

---

## Expected Outputs

### Success Scenario

```
PLAY [RHEL OS PATCHING POC - SUCCESS SCENARIO (TC-OS-001)]

TASK [Display target server information]
ok: [rhel-test-01]
==========================================
  OS UPGRADE: rhel-test-01
==========================================
OS: Red Hat Enterprise Linux 9.0
Kernel: 5.14.0-284.el9_0.x86_64
Repository: JUMP

TASK [PHASE 1: PRE-CHECK VALIDATION]
ok: [rhel-test-01]

TASK [Display current version]
ok: [rhel-test-01]
==========================================
  CURRENT VERSION
==========================================
Red Hat Enterprise Linux release 9.0 (Plow)
==========================================

TASK [Display disk usage status]
ok: [rhel-test-01]
✓ Disk space check passed: 16% used

TASK [PHASE 2: OS UPGRADE]
changed: [rhel-test-01]

TASK [Display upgrade result]
ok: [rhel-test-01]
==========================================
  UPGRADE COMPLETED SUCCESSFULLY
==========================================
Changes: 45 packages upgraded
==========================================

TASK [PHASE 3: POST-UPGRADE VALIDATION]
ok: [rhel-test-01]

TASK [Display final confirmation]
ok: [rhel-test-01]
==========================================
  OS UPGRADE COMPLETE
==========================================
System: rhel-test-01
Before: Red Hat Enterprise Linux release 9.0 (Plow)
After:  Red Hat Enterprise Linux release 9.4 (Plow)
==========================================

PLAY RECAP
rhel-test-01: ok=25 changed=3 failed=0
```

### Pre-Check Failure Scenario

```
PLAY [RHEL OS PATCHING POC - PRE-CHECK FAILURE SCENARIO (TC-OS-002)]

TASK [Display target server information]
ok: [rhel-test-01]

TASK [PHASE 1: PRE-CHECK VALIDATION]
ok: [rhel-test-01]

TASK [Check sufficient disk space (will fail)]
fatal: [rhel-test-01]: FAILED! => {
    "msg": "Insufficient disk space: 95% used. Maximum 90% allowed."
}

TASK [Display pre-check failure]
ok: [rhel-test-01]
==========================================
  PRE-CHECK VALIDATION FAILED
==========================================
Check: Disk Space
Current: 95% used
Maximum: 90% allowed

ACTION: Playbook stopped immediately
No upgrade attempted
No system changes made
==========================================

PLAY RECAP
rhel-test-01: ok=8 changed=0 failed=1
```

### Upgrade Failure Scenario

```
PLAY [RHEL OS PATCHING POC - UPGRADE FAILURE SCENARIO (TC-OS-003)]

TASK [PHASE 2: OS UPGRADE (will fail)]
ok: [rhel-test-01]

TASK [Display upgrade start]
ok: [rhel-test-01]
==========================================
  STARTING UPGRADE
==========================================
Target: RHEL 9.4
Command: dnf upgrade --releasever=9.4
Status: In progress...
==========================================

TASK [Simulate upgrade progress]
ok: [rhel-test-01]

TASK [Display progress message]
ok: [rhel-test-01]
✓ Downloading package metadata...

TASK [Force upgrade failure (simulated)]
fatal: [rhel-test-01]: FAILED! => {
    "msg": "Error: Package dependency conflict detected - glibc-2.34 requires glibc-common-2.34 but glibc-common-2.35 is available"
}

TASK [⚠ UPGRADE FAILURE DETECTED]
ok: [rhel-test-01]

TASK [Display upgrade failure]
ok: [rhel-test-01]
==========================================
  UPGRADE FAILED
==========================================
Phase: Package Installation
Progress: 40% complete
Error: Package dependency conflict detected

WHAT HAPPENED:
- Upgrade started successfully
- Metadata downloaded ✓
- Dependencies resolved ✓
- Installation began
- FAILURE: Dependency conflict detected

ACTION: Rescue block activated
- Playbook caught the error
- System state preserved
- No partial changes committed
- Safe to recover/retry
==========================================
```

### Post-Check Failure Scenario

```
PLAY [RHEL OS PATCHING POC - POST-CHECK FAILURE SCENARIO (TC-OS-004)]

TASK [PHASE 3: POST-UPGRADE VALIDATION]
ok: [rhel-test-01]

TASK [Check status of all enabled services]
ok: [rhel-test-01]

TASK [Display stopped services found]
ok: [rhel-test-01]
==========================================
  ⚠ STOPPED SERVICES DETECTED
==========================================
The following services are NOT running:

1. rsyslog.service - System Logging Daemon
   Status: inactive (dead)
   Impact: High - No system logging

2. chronyd.service - NTP Daemon
   Status: inactive (dead)
   Impact: Medium - Time synchronization affected

3. getty@tty1.service - Getty on tty1
   Status: inactive (dead)
   Impact: Low - Console login may be affected

==========================================
Total: 3 of 46 services are STOPPED
==========================================

TASK [Display service validation failure]
ok: [rhel-test-01]
==========================================
  POST-UPGRADE VALIDATION FAILED
==========================================
Status: VALIDATION_FAILED
Stopped Services: 3
Upgrade: COMPLETED
Services: NOT ALL RUNNING

ACTION REQUIRED:
- Review stopped services above
- Start critical services manually
- Investigate why services stopped
- Re-run validation after fixes
==========================================

PLAY RECAP
rhel-test-01: ok=20 changed=2 failed=0
```

---

## Reports Generated

### Summary Reports

Each scenario generates a summary report on the target host:

| Scenario | Report Location |
|----------|----------------|
| Success | `/tmp/rhel_os_upgrade_summary_<hostname>_<version>.txt` |
| Pre-check fail | `/tmp/rhel_os_precheck_fail_<hostname>.txt` |
| Upgrade fail | `/tmp/rhel_os_upgrade_fail_<hostname>.txt` |
| Post-check fail | `/tmp/rhel_os_postcheck_fail_<hostname>.txt` |

### HTML Reports

The success scenario generates a professional HTML report:

- **Target:** `/tmp/rhel_os_upgrade_report_<hostname>_<timestamp>.html`
- **Downloaded to:** `/tmp/rhel_os_upgrade_report_<hostname>_<timestamp>.html`

**Report Contents:**
- Scenario details
- Version comparison (before/after)
- Package updates
- Service status
- Timestamp

### Log Files

All scenarios log to `/var/log/rhel_os_upgrade_*.log` on target hosts.

---

## Troubleshooting

### "Repository not accessible"

**Problem:** Cannot connect to repository

**Solution:**
```bash
# Verify repository configuration
dnf repolist

# Test repository access
dnf clean all
dnf makecache

# Check subscription status (if using CDN)
subscription-manager status
```

### "Insufficient disk space"

**Problem:** Disk usage exceeds threshold

**Solution:**
```bash
# Check disk usage
df -h /

# Free up space
sudo dnf clean all
sudo journalctl --vacuum-time=7d

# Re-run playbook
```

### "Upgrade failed - dependency conflict"

**Problem:** Package dependency issues

**Solution:**
```bash
# Check for dependency issues
dnf upgrade --releasever=<target_version> --assumeno

# Resolve dependencies manually
sudo dnf repoquery --requires --resolve <package>

# Use VM snapshot to revert and retry
```

### "Services not running after upgrade"

**Problem:** Services failed to start after upgrade

**Solution:**
```bash
# Check service status
sudo systemctl status <service>

# Start service manually
sudo systemctl start <service>

# Enable service
sudo systemctl enable <service>

# Check logs
sudo journalctl -u <service> -n 50
```

### "Reboot timeout"

**Problem:** System didn't come back online after reboot

**Solution:**
```bash
# Check system connectivity
ping <hostname>

# Check SSH
ssh <hostname>

# If still down, check VM console
# May need manual intervention
```

---

## Recovery Procedures

### VM Snapshot Revert (Recommended)

For all failure scenarios, the safest recovery is VM snapshot revert:

```bash
# Before testing, create snapshot
virsh snapshot-create-as <domain> <snapshot-name>

# After failure, revert to snapshot
virsh snapshot-revert <domain> <snapshot-name>

# Verify system state
cat /etc/redhat-release
```

### Manual Service Recovery

For post-check failures with stopped services:

```bash
# Start all failed services
sudo systemctl start rsyslog
sudo systemctl start chronyd
sudo systemctl start sshd

# Verify services running
sudo systemctl status rsyslog
sudo systemctl status chronyd
sudo systemctl status sshd
```

### Manual Upgrade Completion

For upgrade failures:

```bash
# Check what failed
sudo journalctl -n 100

# Attempt manual upgrade
sudo dnf upgrade --releasever=<target_version>

# If successful, verify version
cat /etc/redhat-release
```

---

## Testing Checklist

### Before Testing

- [ ] VM snapshot created
- [ ] Repository configured and accessible
- [ ] SSH connectivity verified
- [ ] Sudo privileges confirmed
- [ ] Disk space sufficient (>20% free)
- [ ] Test baseline services running

### Test Each Scenario

- [ ] **Success scenario** completes without errors
- [ ] **Pre-check fail** stops at disk space check
- [ ] **Upgrade fail** activates rescue block
- [ ] **Post-check fail** detects stopped services
- [ ] All reports generated correctly
- [ ] HTML reports downloaded

### After Testing

- [ ] Verify OS version changed (success scenario)
- [ ] Verify services running (success scenario)
- [ ] Review all log files
- [ ] Revert VM snapshot for next test
- [ ] Document any issues found

---

## File Structure

```
poc_os/
├── site.yml                 # Main playbook (all scenarios)
├── inventory               # Ansible inventory file
├── scenarios/
│   ├── success.yml         # TC-OS-001: Successful upgrade
│   ├── precheck_fail.yml   # TC-OS-002: Pre-check failure
│   ├── upgrade_fail.yml    # TC-OS-003: Upgrade failure
│   └── postcheck_fail.yml  # TC-OS-004: Post-validation failure
├── templates/
│   └── report.html.j2      # HTML report template
└── README.md               # This file
```

---

## Key Playbook Features

### Serial Execution

```yaml
serial: 1  # One host at a time
```
**Benefit:** Limits blast radius, allows investigation between hosts

### Stop on Failure

```yaml
max_fail_percentage: 0  # Stop on any failure
```
**Benefit:** No cascading failures, protects production

### Block/Rescue Structure

```yaml
- block:
    # Upgrade tasks
  rescue:
    # Error handling
```
**Benefit:** Graceful error handling, clear error reporting

### Pre-Flight Validation

- Disk space check (stops if > threshold% used)
- Repository accessibility check
- Subscription status check (if using CDN)

### Post-Upgrade Validation

- Version verification
- Service health checks (ALL enabled services)
- Comprehensive reporting

---

## Demo Script Suggestion

### 1. Show Initial State
```bash
# Show current OS version
ansible rhel_poc -i inventory -m shell -a "cat /etc/redhat-release"

# Show disk space
ansible rhel_poc -i inventory -m shell -a "df -h /"

# Show enabled services
ansible rhel_poc -i inventory -m shell -a "systemctl list-unit-files --type=service --state=enabled"
```

### 2. Run Success Scenario
```bash
ansible-playbook -i inventory site.yml --tags success \
  -e "target_version=9.1 repo_type_input=jump" -v
```

### 3. Show Result
```bash
# Show new version
ansible rhel_poc -i inventory -m shell -a "cat /etc/redhat-release"

# Show summary report
ansible rhel_poc -i inventory -m shell -a "cat /tmp/rhel_os_upgrade_summary_*.txt"

# Open HTML report (if downloaded)
# xdg-open /tmp/rhel_os_upgrade_report_*.html
```

### 4. Show Failure Scenarios
```bash
# Pre-check failure
echo "Demonstrating pre-check failure..."
ansible-playbook -i inventory site.yml --tags precheck_fail \
  -e "repo_type_input=jump" -v

# Upgrade failure
echo "Demonstrating upgrade failure..."
ansible-playbook -i inventory site.yml --tags upgrade_fail \
  -e "repo_type_input=jump" -v

# Post-check failure
echo "Demonstrating post-check failure..."
ansible-playbook -i inventory site.yml --tags postcheck_fail \
  -e "repo_type_input=jump" -v
```

### 5. Explain Safety Features
- Serial execution (one at a time)
- Pre-flight validation
- Stop on failure
- Rescue blocks
- VM snapshot rollback

---

## Next Steps

After demonstrating to client:

1. **Get Feedback:** Does OS upgrade approach meet their needs?
2. **Discuss Integration:** How to integrate with their Satellite/AAP
3. **Plan Customization:** What versions, what schedule, what environments?
4. **Production Readiness:** What's needed for production deployment?

---

## Related Documentation

| File | Purpose |
|------|---------|
| [../README.md](../README.md) | Main project documentation |
| [poc_security_patch/README.md](../poc_security_patch/README.md) | Security patching POC |
| [poc/README.md](../poc/README.md) | Package patching POC |

---

**Note:** These playbooks demonstrate OS version upgrade behavior with comprehensive failure handling. For production use, integrate with your Satellite/AAP server and customize based on specific requirements.
