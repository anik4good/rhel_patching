# RHEL Security Patching POC - Quick Start Guide

## 🎯 Overview

This POC demonstrates **security-only patching** for RHEL systems in a banking environment, with CVE tracking, controlled reboot behavior, and comprehensive failure handling.

**Key Features:**
- ✅ Security-only patching (`dnf` with `security: yes`)
- ✅ CVE exposure tracking (before/after)
- ✅ Security advisory counting (RHSAs)
- ✅ Controlled reboot (manual by default for banking)
- ✅ Serial execution (one server at a time)
- ✅ Automatic stop on failure
- ✅ HTML report generation with CVE metrics
- ✅ Pre/post validation checks
- ✅ 3 failure scenarios with recovery guidance

---

## 🏗️ Architecture

```
poc_security_patch/
├── site.yml                 # Main playbook
├── ansible.cfg              # Ansible configuration
├── inventory                # Target servers
├── QUICKSTART.md            # This file
├── scenarios/
│   ├── success.yml          # TC-SEC-001: Successful security patching
│   ├── precheck_fail.yml    # TC-SEC-002: Pre-check validation failure
│   ├── patch_fail.yml       # TC-SEC-003: Patch installation failure
│   └── postcheck_fail.yml   # TC-SEC-004: Post-patch validation failure
└── templates/
    └── report.html.j2       # HTML report template
```

---

## 🚀 Quick Start

### 1. Test Scenarios

```bash
cd poc_security_patch

# Scenario 1: Successful security patching (manual reboot)
ansible-playbook -i inventory site.yml --tags success

# Scenario 1: With automatic reboot
ansible-playbook -i inventory site.yml --tags success -e "auto_reboot=true"

# Scenario 2: Pre-check validation failure (disk space)
ansible-playbook -i inventory site.yml --tags precheck_fail

# Scenario 3: Patch installation failure
ansible-playbook -i inventory site.yml --tags patch_fail

# Scenario 4: Post-patch validation failure
ansible-playbook -i inventory site.yml --tags postcheck_fail

# Run all scenarios (for testing)
ansible-playbook -i inventory site.yml --tags all_scenarios
```

---

## 🔧 Configuration Options

### Repository Selection

**3 Repository Options (All Pre-Configured):**

| Option | Variable | Description | Use When |
|--------|----------|-------------|----------|
| **cdn** | `cdn` | Red Hat CDN (default) | Most environments, internet access |
| **satellite** | `satellite` | Red Hat Satellite | Managed environments, air-gapped with Satellite |
| **jump** | `jump` | Local Jump Server | Air-gapped networks, local repos |

**Usage:**
```bash
# Default - Red Hat CDN
ansible-playbook -i inventory site.yml --tags success

# Satellite (already configured)
ansible-playbook -i inventory site.yml --tags success -e "repo_type=satellite"

# Jump Server (already configured)
ansible-playbook -i inventory site.yml --tags success -e "repo_type=jump"
```

### Reboot Control

**For Banking Environments:**

| Setting | Variable | Behavior |
|---------|----------|----------|
| **Manual Reboot** | `auto_reboot=false` | Requires manual approval (default) |
| **Auto Reboot** | `auto_reboot=true` | Automatic reboot after patching |

**Usage:**
```bash
# Manual reboot (banking standard - default)
ansible-playbook -i inventory site.yml --tags success

# Auto reboot (for non-production testing)
ansible-playbook -i inventory site.yml --tags success -e "auto_reboot=true"
```

---

## 📊 Test Scenarios

### TC-SEC-001: Successful Security Patching

**Demonstrates:**
- Security-only patching flow
- CVE exposure tracking
- Security advisory counting
- Package version tracking
- Controlled reboot behavior
- HTML report generation

**What happens:**
1. Pre-check validation (disk space, repo access)
2. Security exposure assessment (CVE count before)
3. Apply security patches only (`dnf` with `security: yes`)
4. Post-patch security assessment (CVE count after)
5. Reboot check (manual or auto based on setting)
6. HTML report with CVE metrics

**Expected outcome:**
- Security patches applied successfully
- CVE count reduced (or unchanged if already patched)
- HTML report shows before/after CVE counts
- Manual reboot notification (if `auto_reboot=false`)

---

### TC-SEC-002: Pre-Check Validation Failure

**Demonstrates:**
- Playbook stops **before** causing damage
- Disk space validation
- Clear error messaging
- Recovery instructions

**What happens:**
1. Playbook reaches disk space check
2. Check fails (simulated: 95% disk usage)
3. Playbook stops immediately
4. No patches applied
5. Failure report generated

**Expected outcome:**
- Playbook stops at pre-check
- Error message clearly states disk space issue
- System untouched (no changes)
- Exit code: non-zero

---

### TC-SEC-003: Patch Installation Failure

**Demonstrates:**
- Block/Rescue structure catches installation errors
- Graceful failure handling
- Clear error reporting

**What happens:**
1. Pre-checks pass
2. Playbook attempts security patch installation
3. Installation fails (simulated repo failure)
4. Rescue block activates
5. Playbook stops

**Expected outcome:**
- Installation fails safely
- Rescue block handles error gracefully
- Playbook stops immediately
- Failure report generated

---

### TC-SEC-004: Post-Patch Validation Failure

**Demonstrates:**
- Post-patch service validation
- Rollback guidance
- Manual intervention procedures

**What happens:**
1. Pre-checks pass
2. Security patches install successfully
3. Post-patch validation fails (simulated service check)
4. Playbook stops with rollback guidance

**Expected outcome:**
- Patches applied successfully
- Validation fails
- Rollback instructions provided
- Manual intervention required

---

## 📈 Reports Generated

### 1. Text Summary Report
**Location:** `/tmp/rhel_security_patch_summary_<hostname>.txt`

**Contains:**
- Server information
- Security advisories count (before/after)
- CVEs patched
- Package updates (before/after versions)
- Reboot status

**Sample:**
```
RHEL Security Patching Summary
==============================
Date: 2026-03-06T12:00:00Z
Server: 192.168.8.51

OS Version: Red Hat Enterprise Linux release 9.4
Kernel Version: 5.14.0-427.18.1.el9_4.x86_64

Security Patching Results:
- Security Advisories Before: 15
- Security Advisories After: 3
- CVEs Patched: 12

Package Updates:
- Kernel: 5.14.0-284 → 5.14.0-427
- glibc: 2.34-40 → 2.34-60
- openssl: 3.0.1 → 3.0.7
- systemd: 250-12 → 250-14

Reboot Required: YES

Status: SUCCESS
```

### 2. HTML Report
**Location:** `/tmp/rhel_security_patch_report_<hostname>.html`

**Contains:**
- Visual security exposure summary
- CVE count before/after
- Package updates table (before/after versions)
- Security posture assessment
- Risk reduction metrics

**To view:**
```bash
# Copy to local machine
scp root@192.168.8.51:/tmp/rhel_security_patch_report_*.html .

# Open in browser
firefox rhel_security_patch_report_*.html
```

---

## 🔍 Playbook Phases

### Phase 1: Pre-Check & Security Exposure Analysis
- Disk space validation
- Repository accessibility check
- Current version capture

### Phase 2: Security Exposure Assessment
- Count security advisories (RHSAs) before patching
- List packages to be patched
- Display risk baseline

### Phase 3: Apply Security Patches
- Apply security updates only (`dnf` with `security: yes`)
- Track package versions (before/after)
- No version uplift (stays on same minor version)

### Phase 4: Post-Patch Security Assessment
- Count remaining security advisories
- Calculate CVEs patched
- Verify package versions

### Phase 5: Reboot Check
- Check if reboot required (`needs-restarting -r`)
- Auto-reboot if enabled
- Manual reboot instructions if disabled

### Phase 6: Final Validation
- Confirm system status
- Generate text summary
- Log results

### Phase 7: HTML Report Generation
- Generate visual HTML report
- Include CVE metrics
- Package update details

---

## 🏦 Banking Environment Features

### 1. Security-Only Patching
```yaml
- name: Apply security updates only
  ansible.builtin.dnf:
    name: '*'
    state: latest
    security: yes  # Only security errata
```

### 2. Controlled Reboot
```yaml
# Manual reboot (banking standard)
auto_reboot: false

# Playbook will:
1. Apply patches
2. Check if reboot needed
3. Display manual reboot instructions
4. Wait for manual intervention
```

### 3. Serial Execution
```yaml
serial: 1  # One server at a time (zero blast radius)
```

### 4. CVE Tracking
```yaml
# Before patching
- dnf updateinfo list security
- Count security advisories

# After patching
- dnf updateinfo list security
- Calculate CVEs patched
```

### 5. Audit Evidence
- Text summary logs
- HTML reports with timestamps
- Package version tracking
- Security advisory counts

---

## 🛠️ Troubleshooting

### Issue: No security updates available
**Symptom:** `Security Advisories Before: 0`

**Solution:**
- System already fully patched
- No security errata for current repositories
- Check with: `dnf updateinfo list security`

### Issue: Reboot required but auto_reboot=false
**Symptom:** Playbook shows manual reboot required

**Solution:**
```bash
# Coordinate with application team
# Then manually reboot:
ssh root@192.168.8.51 "reboot"
```

### Issue: Repository connection failure
**Symptom:** `Failed to synchronize repository`

**Solution:**
```bash
# Check repository connectivity
ansible rhel_security_poc_servers -i inventory -m shell -a "dnf repolist" -b

# Check network
ansible rhel_security_poc_servers -i inventory -m shell -a "ping -c 3 <repo-server>"
```

---

## 📝 Variables Reference

| Variable | Default | Description |
|----------|---------|-------------|
| `repo_type` | `cdn` | Repository type: cdn/satellite/jump |
| `auto_reboot` | `false` | Auto-reboot after patching |
| `disk_threshold` | `90` | Max disk usage % (stop if exceeded) |
| `reboot_timeout` | `600` | Reboot timeout in seconds |
| `pre_reboot_delay` | `10` | Delay before reboot (seconds) |

---

## 🎯 Key Differences from OS Upgrade POC

| Feature | Security Patching | OS Upgrade |
|---------|------------------|------------|
| **Operation** | Security patches only | Version uplift |
| **DNF Command** | `dnf` with `security: yes` | `dnf upgrade --releasever=X.Y` |
| **Reboot** | Manual by default | Automatic |
| **Scope** | Within same minor version | Across minor versions |
| **Tracking** | CVE count, security advisories | Version numbers |
| **Use Case** | Monthly patch cycle | Planned change window |
| **Risk Level** | Medium | High |

---

## ✅ Success Criteria

✅ Security patches applied successfully
✅ CVE count reduced (or already at 0)
✅ No version uplift (stays on same minor version)
✅ HTML report generated with CVE metrics
✅ Package versions tracked (before/after)
✅ Clear reboot notification (if manual)
✅ Audit trail created (logs + reports)

---

## 📞 Support

For issues or questions:
1. Check ansible logs: `cat /var/log/rhel_security_patch.log`
2. Check dnf logs: `cat /var/log/dnf.log`
3. Review generated reports in `/tmp/`
