# RHEL OS Patching POC - Quick Start Guide

**For:** Fast reference during testing and demo preparation

---

## Pre-Test Checklist (5 minutes)

```bash
☐ 1. Create VM snapshot
   virsh snapshot-create-as --domain <name> --name pre-upgrade-test

☐ 2. Configure RHEL 9.4 repo on target
   cat /etc/yum.repos.d/*.repo | grep 9.4

☐ 3. Verify repo accessible
   dnf repolist

☐ 4. Check current OS version
   cat /etc/redhat-release

☐ 5. Verify disk space
   df -h /

☐ 6. Update inventory file
   vi poc_os/inventory
```

---

## Run Commands

### Success Scenario (9.0 → 9.4)

```bash
cd poc_os
ansible-playbook -i inventory site.yml --tags success -v
```

**Expected:** Complete upgrade with reboot if needed

---

### Pre-Check Failure Scenario

```bash
cd poc_os
ansible-playbook -i inventory site.yml --tags precheck_fail -v
```

**Expected:** Fails at disk check (95% used)

---

### Upgrade Failure Scenario

```bash
cd poc_os
ansible-playbook -i inventory site.yml --tags upgrade_fail -v
```

**Expected:** Fails during DNF upgrade

---

## Run All Scenarios

```bash
cd poc_os
ansible-playbook -i inventory site.yml --tags all_scenarios
```

**Note:** Will fail at first scenario, run individually instead

---

## Expected Outputs

### Success Scenario Output

```
PLAY [RHEL OS Patching POC - Success Scenario]

TASK [Display current version]
ok: [host] =>
  CURRENT VERSION (BEFORE UPGRADE)
  ==========================================
  Red Hat Enterprise Linux release 9.0 (Plow)
  ==========================================

TASK [Upgrade to RHEL 9.4]
changed: [host]

TASK [Display reboot status]
ok: [host] =>
  REBOOT STATUS
  ==========================================
  Reboot Required: YES
  Reason: Core libraries or services have been updated.
  ==========================================

TASK [Reboot the server if required]
changed: [host]

TASK [Display final confirmation]
ok: [host] =>
  UPGRADE COMPLETE
  ==========================================
  Final Version: Red Hat Enterprise Linux release 9.4 (Neon)
  Kernel: 5.14.0-364.el9.x86_64
  ==========================================
```

---

### Pre-Check Failure Output

```
TASK [Validate disk space threshold]
fatal: [host]: FAILED! =>
  Insufficient disk space: 95% used. Maximum 90% allowed.

PLAY RECAP
host: ok=5    changed=0    failed=1
```

---

### Upgrade Failure Output

```
TASK [Attempt upgrade to RHEL 9.4]
fatal: [host]: FAILED! =>
  Error: Repository metadata corrupted
  RC: 1

TASK [Mark as upgrade failure]
ok: [host]

PLAY RECAP
host: ok=8    changed=0    failed=1
```

---

## Quick Troubleshooting

### Playbook won't run

```bash
# Check syntax
ansible-playbook --syntax-check site.yml

# Check inventory
ansible-inventory -i inventory --list

# Test connectivity
ansible all -i inventory -m ping
```

### Repository not accessible

```bash
# On target host
dnf clean all
dnf repolist

# Verify repo file
cat /etc/yum.repos.d/*.repo
```

### System stuck after reboot

```bash
# Check VM status
virsh list --all

# Manual reboot
virsh reboot <domain>

# Check console
virsh console <domain>
```

---

## Recovery Commands

### Revert VM Snapshot

```bash
# List snapshots
virsh snapshot-list --domain <name>

# Revert
virsh snapshot-revert --domain <name> --snapshot pre-upgrade-test

# Verify
cat /etc/redhat-release
```

### Check Upgrade History

```bash
# On target host
dnf history

# View last transaction
dnf history info <transaction-id>
```

---

## File Locations

| File | Location | Purpose |
|------|----------|---------|
| Summary | `/tmp/rhel_os_upgrade_summary_<host>.txt` | Success report |
| Pre-check fail | `/tmp/rhel_os_precheck_fail_<host>.txt` | Pre-check failure report |
| Upgrade fail | `/tmp/rhel_os_upgrade_fail_<host>.txt` | Upgrade failure report |
| Log file | `/var/log/rhel_os_upgrade.log` | Execution log |

---

## Time Estimates

| Scenario | Duration |
|----------|----------|
| Pre-check (all scenarios) | 30 seconds |
| Success scenario | 15-30 minutes (depends on updates) |
| Pre-check failure | 1 minute |
| Upgrade failure | 5-10 minutes |

---

## Demo Script

```bash
# 1. Show current version
echo "=== BEFORE ==="
cat /etc/redhat-release
uname -r

# 2. Run success scenario
echo "=== RUNNING UPGRADE ==="
ansible-playbook -i inventory site.yml --tags success

# 3. Show new version
echo "=== AFTER ==="
cat /etc/redhat-release
uname -r

# 4. Show summary
cat /tmp/rhel_os_upgrade_summary_*.txt
```

---

## Variable Overrides

### Change disk threshold

```bash
ansible-playbook -i inventory site.yml --tags success \
  -e "disk_threshold=80"
```

### Skip reboot (testing only)

```bash
ansible-playbook -i inventory site.yml --tags success \
  -e "skip_reboot=true"
```

### Change target version

```bash
ansible-playbook -i inventory site.yml --tags success \
  -e "target_version=9.5"
```

---

## Common Errors

### "Repository not accessible"
```bash
# Fix: Verify repo configuration
cat /etc/yum.repos.d/*.repo
dnf repolist
```

### "Insufficient disk space"
```bash
# Fix: Free up space or adjust threshold
df -h /
ansible-playbook site.yml --tags success -e "disk_threshold=95"
```

### "Timeout waiting for reboot"
```bash
# Fix: Increase timeout or check system
# Edit site.yml: reboot_timeout: 900
virsh reboot <domain>
```

---

**End of Quick Start Guide**

---

## Version Selection (NEW!)

### Available Target Versions

| Tag | Version | Description |
|-----|---------|-------------|
| `success` | 9.4 | Default - upgrade to 9.4 |
| `success_v9.4` | 9.4 | Explicit - upgrade to 9.4 |
| `success_v9.5` | 9.5 | Upgrade to 9.5 |
| `success_v9.6` | 9.6 | Upgrade to 9.6 |
| `success_v9.7` | 9.7 | Upgrade to 9.7 |

### Version Selection Examples

```bash
# Default (9.4)
ansible-playbook -i inventory site.yml --tags success

# Upgrade to 9.5
ansible-playbook -i inventory site.yml --tags success_v9.5

# Upgrade to 9.6
ansible-playbook -i inventory site.yml --tags success_v9.6

# Upgrade to 9.7
ansible-playbook -i inventory site.yml --tags success_v9.7
```

---

## Repository Type Selection (NEW!)

### 3 Repository Options

| Type | Variable | Description | Example |
|------|----------|-------------|---------|
| **Subscription Manager** | `subscription_manager` | Red Hat CDN (default) | Most environments |
| **Satellite** | `satellite` | Red Hat Satellite | Managed environments |
| **Jump Server** | `jump_server` | Local repository server | Air-gapped networks |

### Repository Examples

```bash
# Default - Subscription Manager (CDN)
ansible-playbook -i inventory site.yml --tags success

# Satellite
ansible-playbook -i inventory site.yml --tags success \
  -e "repo_type=satellite"

# Jump Server (local repo)
ansible-playbook -i inventory site.yml --tags success_v9.5 \
  -e "repo_type=jump_server" \
  -e "jump_server_url=http://jump-server.local/repos"
```

---

## Combined Examples

### Upgrade to 9.5 using Satellite

```bash
ansible-playbook -i inventory site.yml --tags success_v9.5 \
  -e "repo_type=satellite"
```

### Upgrade to 9.6 using Jump Server

```bash
ansible-playbook -i inventory site.yml --tags success_v9.6 \
  -e "repo_type=jump_server" \
  -e "jump_server_url=http://repo.example.com/rhel"
```

### Upgrade to 9.7 using CDN (default)

```bash
ansible-playbook -i inventory site.yml --tags success_v9.7
```

---

## Variable Reference

| Variable | Default | Description |
|----------|---------|-------------|
| `repo_type` | `subscription_manager` | Repository type |
| `jump_server_url` | `http://jump-server.example.com` | Jump server URL |
| `target_version` | `9.4` | Target OS version |
| `disk_threshold` | `90` | Fail if disk usage > 90% |


---

## Repository Selection (UPDATED!)

### 3 Repository Options (All Pre-Configured)

| Option | Variable | Description | Use When |
|--------|----------|-------------|----------|
| **cdn** | `cdn` | Red Hat CDN (default) | Most environments, internet access |
| **satellite** | `satellite` | Red Hat Satellite | Managed environments, air-gapped with Satellite |
| **jump** | `jump` | Local Jump Server | Air-gapped networks, local repos |

**Important:** All repositories must be pre-configured on target systems. The playbook only verifies accessibility.

### Repository Examples

```bash
# Default - Red Hat CDN
ansible-playbook -i inventory site.yml --tags success

# Satellite (already configured)
ansible-playbook -i inventory site.yml --tags success_v9.5 \
  -e "repo_type=satellite"

# Jump Server (already configured)
ansible-playbook -i inventory site.yml --tags success_v9.6 \
  -e "repo_type=jump"

# Version + Repository selection
ansible-playbook -i inventory site.yml --tags success_v9.7 \
  -e "repo_type=satellite"
```

### Quick Examples

```bash
# Upgrade to 9.4 using CDN
ansible-playbook -i inventory site.yml --tags success

# Upgrade to 9.5 using Satellite
ansible-playbook -i inventory site.yml --tags success_v9.5 \
  -e "repo_type=satellite"

# Upgrade to 9.6 using Jump Server
ansible-playbook -i inventory site.yml --tags success_v9.6 \
  -e "repo_type=jump"

# Upgrade to 9.7 using CDN (default)
ansible-playbook -i inventory site.yml --tags success_v9.7
```

---

## Updated Variable Reference

| Variable | Default | Description |
|----------|---------|-------------|
| `repo_type` | `cdn` | Repository type (cdn/satellite/jump) |
| `target_version` | `9.4` | Target RHEL version |
| `disk_threshold` | `90 | Fail if disk usage > 90% |
| `reboot_timeout` | `600` | Max seconds to wait for reboot |

**Note:** `jump_server_url` variable removed - repos are pre-configured on targets

