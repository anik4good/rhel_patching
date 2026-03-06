# RHEL Security Patching POC

## 🎯 Purpose

This POC demonstrates **enterprise-grade security patching** for RHEL systems in a banking environment, focusing on:

- **Security-only patching** (not version upgrades)
- **CVE exposure tracking** (before/after)
- **Controlled reboot behavior** (manual by default)
- **Comprehensive failure handling**
- **Audit-ready reporting**

---

## 🏦 Banking Environment Standards

This POC follows banking industry standards:

✅ **Security-first approach** - Only security errata applied
✅ **Controlled reboot** - Manual approval required by default
✅ **Zero blast radius** - Serial execution (one server at a time)
✅ **Stop-on-failure** - Automatic halt on any error
✅ **Audit evidence** - Complete logs and HTML reports
✅ **Rollback guidance** - Clear recovery instructions

---

## 🚀 Quick Start

```bash
cd poc_security_patch

# Run successful security patching scenario
ansible-playbook -i inventory site.yml --tags success

# Run with automatic reboot (for testing only)
ansible-playbook -i inventory site.yml --tags success -e "auto_reboot=true"

# Run failure scenarios
ansible-playbook -i inventory site.yml --tags precheck_fail
ansible-playbook -i inventory site.yml --tags patch_fail
ansible-playbook -i inventory site.yml --tags postcheck_fail
```

**See [QUICKSTART.md](QUICKSTART.md) for detailed documentation.**

---

## 📊 Scenarios

| Scenario | Test Case ID | Description |
|----------|--------------|-------------|
| Success | TC-SEC-001 | Successful security patching with CVE tracking |
| Pre-check Fail | TC-SEC-002 | Disk space validation failure (stops before patching) |
| Patch Fail | TC-SEC-003 | Repository/package failure during patching |
| Post-check Fail | TC-SEC-004 | Service validation failure after patching |

---

## 🏗️ Architecture

```
poc_security_patch/
├── site.yml                 # Main playbook
├── ansible.cfg              # Ansible configuration
├── inventory                # Target servers
├── README.md                # This file
├── QUICKSTART.md            # Detailed usage guide
├── scenarios/
│   ├── success.yml          # TC-SEC-001: Success scenario
│   ├── precheck_fail.yml    # TC-SEC-002: Pre-check failure
│   ├── patch_fail.yml       # TC-SEC-003: Patch failure
│   └── postcheck_fail.yml   # TC-SEC-004: Post-patch failure
└── templates/
    └── report.html.j2       # HTML report template
```

---

## 🔑 Key Features

### 1. Security-Only Patching
```yaml
- name: Apply security updates only
  ansible.builtin.dnf:
    name: '*'
    state: latest
    security: yes  # Only security errata, no minor version uplift
```

### 2. CVE Exposure Tracking
```yaml
# Before patching
- dnf updateinfo list security
- Count: 15 security advisories

# After patching
- dnf updateinfo list security
- Count: 3 security advisories
- CVEs Patched: 12
```

### 3. Controlled Reboot
```bash
# Banking standard: Manual reboot
auto_reboot: false

# Playbook displays:
# "Manual reboot required"
# "Please coordinate with application team"
```

### 4. Serial Execution
```yaml
serial: 1  # One server at a time
max_fail_percentage: 0  # Stop on first failure
```

### 5. HTML Reports
- CVE count before/after
- Package version tracking
- Security posture assessment
- Risk reduction metrics

---

## 📈 Reports Generated

### 1. Text Summary
```
/tmp/rhel_security_patch_summary_<hostname>.txt
```
- Security advisories count
- CVEs patched
- Package updates
- Reboot status

### 2. HTML Report
```
/tmp/rhel_security_patch_report_<hostname>.html
```
- Visual security summary
- CVE metrics
- Package comparison table
- Before/after analysis

---

## 🔄 Comparison: Security Patching vs OS Upgrade

| Feature | Security Patching (This POC) | OS Upgrade (poc_os/) |
|---------|------------------------------|----------------------|
| **Operation** | Security patches only | Minor version uplift |
| **Example** | 9.4 → 9.4 (with patches) | 9.0 → 9.4 |
| **DNF Command** | `dnf` with `security: yes` | `dnf upgrade --releasever=X.Y` |
| **Reboot** | Manual by default | Automatic |
| **Risk Level** | Medium | High |
| **Change Type** | Monthly patch cycle | Planned change window |
| **CAB Approval** | Monthly batch | Special approval |
| **Tracking** | CVE count, security advisories | Version numbers |

---

## 🎯 Use Cases

### When to Use This POC:
✅ Monthly security patching cycles
✅ CVE remediation requirements
✅ Banking/regulated environments
✅ Controlled patch deployments
✅ Audit trail requirements

### When to Use OS Upgrade POC (`poc_os/`):
✅ Minor version upgrades (e.g., 9.0 → 9.4)
✅ Major feature updates
✅ Planned maintenance windows
✅ Non-production testing

---

## 🛡️ Security Features

1. **Pre-flight validation**
   - Disk space checks
   - Repository accessibility
   - Service status validation

2. **Security-only patching**
   - DNF with `security: yes` flag
   - No version uplift
   - CVE reduction tracking

3. **Controlled reboot**
   - Manual by default (banking standard)
   - Clear notification
   - Coordination requirements

4. **Failure handling**
   - Block/Rescue structure
   - Automatic stop on failure
   - Rollback guidance

5. **Audit evidence**
   - Text logs with timestamps
   - HTML reports with metrics
   - Package version tracking
   - CVE count tracking

---

## 🔧 Configuration

### Repository Options
```bash
# Red Hat CDN (default)
ansible-playbook -i inventory site.yml --tags success

# Satellite
ansible-playbook -i inventory site.yml --tags success -e "repo_type=satellite"

# Jump Server
ansible-playbook -i inventory site.yml --tags success -e "repo_type=jump"
```

### Reboot Control
```bash
# Manual reboot (banking standard - default)
ansible-playbook -i inventory site.yml --tags success

# Auto reboot (for testing)
ansible-playbook -i inventory site.yml --tags success -e "auto_reboot=true"
```

---

## 📝 Test Case Documentation

### TC-SEC-001: Successful Security Patching
**Objective:** Demonstrate complete security patching flow with CVE tracking

**Steps:**
1. Pre-check validation (disk space, repo access)
2. Security exposure assessment (CVE count before)
3. Apply security patches only
4. Post-patch security assessment (CVE count after)
5. Reboot check (manual notification)
6. HTML report generation

**Expected Results:**
- Security patches applied
- CVE count reduced
- HTML report with CVE metrics
- Manual reboot notification

### TC-SEC-002: Pre-Check Validation Failure
**Objective:** Demonstrate stop before causing damage

**Failure Simulation:** Disk space 95% full

**Expected Results:**
- Playbook stops at pre-check
- No patches applied
- Clear error message
- System untouched

### TC-SEC-003: Patch Installation Failure
**Objective:** Demonstrate graceful failure handling

**Failure Simulation:** Repository connection failure

**Expected Results:**
- Installation fails safely
- Rescue block handles error
- Playbook stops immediately
- Failure report generated

### TC-SEC-004: Post-Patch Validation Failure
**Objective:** Demonstrate post-patch validation and rollback guidance

**Failure Simulation:** Service check fails after patching

**Expected Results:**
- Patches applied successfully
- Validation fails
- Rollback instructions provided
- Manual intervention required

---

## ✅ Success Criteria

✅ Security patches applied successfully
✅ CVE count reduced (or already at 0)
✅ No version uplift (stays on same minor version)
✅ HTML report generated with CVE metrics
✅ Package versions tracked (before/after)
✅ Clear reboot notification (if manual)
✅ Audit trail created (logs + reports)
✅ Failure scenarios demonstrate graceful handling

---

## 📖 Documentation

- **[QUICKSTART.md](QUICKSTART.md)** - Detailed usage guide with examples
- **[scenarios/](scenarios/)** - Individual test case implementations
- **[templates/report.html.j2](templates/report.html.j2)** - HTML report template

---

## 🎯 Next Steps

1. **Review the scenarios** - Understand each test case
2. **Run the success scenario** - Verify basic functionality
3. **Test failure scenarios** - Validate error handling
4. **Review generated reports** - Check HTML and text outputs
5. **Customize for your environment** - Adjust variables and thresholds

---

## 📞 Support

For detailed usage instructions, see [QUICKSTART.md](QUICKSTART.md)

For implementation details, review scenario files in `scenarios/`
