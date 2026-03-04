# Quick Start Guide - RHEL Patching POC

## Understanding the POC

This demonstrates **actual patching** - upgrading from an old version to a new version using **RHEL 9.4 → 9.7 repository switch**.

**What is Patching?**
- Installing: Package not installed → Install it
- **Patching**: Old version → New version ✅ (This POC)

**Example (RHEL 9.4 → 9.7):**
- Before: nginx 1.20.1 (from RHEL 9.4 repo)
- Repo Switch: 9.4 → 9.7
- After: nginx 1.26.x (from RHEL 9.7 repo) ✅

---

## Repository Setup

### Understanding the Approach: RHEL 9.4 → 9.7

This POC demonstrates a **minor OS version upgrade** scenario:

**Before Patch:**
- OS: RHEL 9.4
- Repo: `rhel-9.4-appstream`
- nginx: 1.20.x

**After Patch:**
- OS: Still RHEL 9.4 (kernel unchanged)
- Repo: Switches to `rhel-9.7-appstream` ✅
- nginx: 1.26.x ✅

### Option 1: Use Your RHEL 9.4 and 9.7 Repositories

You likely have both repos on your jump server:
```
/var/www/html/repos/
├── rhel-9.4/
│   ├── baseos/
│   └── appstream/  # nginx 1.20.x
└── rhel-9.7/
    ├── baseos/
    └── appstream/  # nginx 1.26.x
```

### Option 2: Configure Both Repositories on Target Host

```bash
# On RHEL target host - Create 9.4 repo files
cat > /etc/yum.repos.d/rhel-9.4.repo <<'EOF'
[rhel-9.4-baseos]
name=RHEL 9.4 BaseOS
baseurl=http://<jump-server-ip>/repos/rhel-9.4/baseos/
enabled=1
gpgcheck=0
priority=1

[rhel-9.4-appstream]
name=RHEL 9.4 AppStream
baseurl=http://<jump-server-ip>/repos/rhel-9.4/appstream/
enabled=1
gpgcheck=0
priority=1
EOF

# Create 9.7 repo files (DISABLED by default)
cat > /etc/yum.repos.d/rhel-9.7.repo <<'EOF'
[rhel-9.7-baseos]
name=RHEL 9.7 BaseOS
baseurl=http://<jump-server-ip>/repos/rhel-9.7/baseos/
enabled=0
gpgcheck=0
priority=2

[rhel-9.7-appstream]
name=RHEL 9.7 AppStream
baseurl=http://<jump-server-ip>/repos/rhel-9.7/appstream/
enabled=0
gpgcheck=0
priority=2
EOF

# Test 9.4 repos
dnf repolist
dnf info nginx
# Should show nginx 1.20.x
```

---

## Initial Setup (Do This First)

### 1. Install OLD Version from RHEL 9.4

```bash
# On target host - ensure 9.4 repos are enabled
sudo dnf config-manager --set-enabled rhel-9.4-*
sudo dnf clean all

# Install nginx from 9.4 (will be 1.20.x)
sudo dnf install nginx -y
sudo systemctl start nginx
sudo systemctl enable nginx

# Verify old version
rpm -q nginx
# Expected: nginx-1.20.1-xxxx.el9_4.x86_64
```

### 2. Verify 9.7 Version Available

```bash
# Temporarily enable 9.7 to check
sudo dnf --enablerepo=rhel-9.7-* info nginx | grep Version
# Should show 1.26 or higher

# Note: Don't keep 9.7 enabled yet - playbook will handle the switch
```

### 3. Configure Ansible Inventory

```bash
cd /home/anik/ansible/wikilabs/aeon/rhel_patching/poc

cp inventory.example inventory
nano inventory  # Add your target host
```

### 4. Test Connectivity

```bash
ansible rhel_poc -i inventory -m ping
```

---

## Run the POC

### Success Scenario (Patching)

```bash
cd /home/anik/ansible/wikilabs/aeon/rhel_patching/poc

# This upgrades nginx 1.20.1 → 1.26 with repo switch 9.4 → 9.7
ansible-playbook -i inventory site.yml --tags success -v
```

**What You'll See:**
```
CURRENT STATE (BEFORE PATCH)
==========================================
Version: nginx-1.20.1-xxxx.el9_4.x86_64
Repo: rhel-9.4-appstream

PHASE 1.5: REPOSITORY SWITCH (9.4 → 9.7)
==========================================
✓ Disabling RHEL 9.4 repositories
✓ Enabling RHEL 9.7 repositories
✓ Now using: RHEL 9.7 repositories

PATCHING...
Upgrading to nginx-1.26-xxxx.el9_7.x86_64

NEW STATE (AFTER PATCH)
==========================================
Version: nginx-1.26-xxxx.el9_7.x86_64
Repo: rhel-9.7-appstream

PATCH SUMMARY
==========================================
Change: VERSION CHANGED ✓ (1.20.1 → 1.26)
Status: PATCHED SUCCESSFULLY
==========================================
```

### Failure Scenarios

```bash
# Disk space failure
ansible-playbook -i inventory site.yml --tags precheck_fail

# Dependency conflict
ansible-playbook -i inventory site.yml --tags install_fail

# Service failure after patch
ansible-playbook -i inventory site.yml --tags validate_fail
```

---

## What to Expect

### Success Scenario
- ✅ Shows current version (before)
- ✅ Shows patching process
- ✅ Shows new version (after)
- ✅ Shows version comparison
- ✅ Service verified running
- ✅ Report with version details

### Failure Scenarios
- ⚠️ Failure detected at specific point
- 🛑 Execution stops immediately
- 📋 Clear error message
- 📦 Backup preserved
- 📄 Report generated

---

## Demo Checklist

Before client demo:

### Repository Setup
- [ ] RHEL 9.4 repos configured and enabled on target
- [ ] RHEL 9.7 repos configured (disabled initially)
- [ ] Target host can access both repos
- [ ] Old nginx version (1.20.x) installed from 9.4
- [ ] Service running on target

### Ansible Setup
- [ ] Inventory file configured
- [ ] SSH connectivity tested
- [ ] Sudo access verified
- [ ] Playbook syntax checked

### Dry Run
- [ ] Run success scenario once
- [ ] Verify version changed
- [ ] Check report file generated
- [ ] Test one failure scenario

---

## Quick Demo Script

### 1. Show Initial State
```bash
# Show old version
ansible rhel_poc -i inventory -m shell -a "rpm -q nginx && systemctl is-active nginx"
```

### 2. Run Patching
```bash
ansible-playbook -i inventory site.yml --tags success
```

### 3. Show Result
```bash
# Show new version
ansible rhel_poc -i inventory -m shell -a "rpm -q nginx"

# Show report
ansible rhel_poc -i inventory -m shell -a "cat /tmp/rhel_patching_success_*.txt"
```

### 4. Show Failure Scenarios
```bash
# Show what happens when things fail
ansible-playbook -i inventory site.yml --tags precheck_fail
ansible-playbook -i inventory site.yml --tags install_fail
ansible-playbook -i inventory site.yml --tags validate_fail
```

---

## Key Files

| File | Purpose |
|------|---------|
| `site.yml` | Main playbook with tags |
| `scenarios/success.yml` | Patching workflow |
| `scenarios/precheck_fail.yml` | Pre-check failure demo |
| `scenarios/install_fail.yml` | Installation failure demo |
| `scenarios/validate_fail.yml` | Validation failure demo |
| `inventory.example` | Inventory template |
| `README.md` | Full documentation |

---

## Common Issues

### "Package not found"
```bash
# Check what's available
dnf list available | grep nginx

# Verify repo configured
cat /etc/yum.repos.d/local-nginx.repo

# Check both versions exist
ls /var/www/html/repos/rhel9/x86_64/Packages/
```

### "Old version not installed"
```bash
# You skipped the setup! Install old version first
sudo dnf install nginx-1.20.1 -y
sudo systemctl start nginx
```

### "Can't reach repository"
```bash
# Test HTTP access
curl http://<jump-server>/repos/

# Check firewall
sudo firewall-cmd --list-all
```

---

## Tips for Client Demo

### Before Demo
- ✅ Prepare environment with both versions
- ✅ Test the workflow end-to-end
- ✅ Have screenshots ready as backup

### During Demo
1. **Show the architecture diagram**
2. **Explain**: "We're demonstrating patching, not just installing"
3. **Show before/after version comparison**
4. **Run each scenario with --tags**
5. **Highlight safety features after each failure**

### Key Talking Points

**What we're showing:**
- Not just installing, but **upgrading** versions
- Pre-flight validation stops problems before damage
- Serial execution limits risk
- Rescue blocks handle errors gracefully
- Post-validation catches issues installation misses

**What the client cares about:**
- "What happens if it fails?" → We show all 3 failure scenarios
- "Can we rollback?" → We show backup preservation
- "Will it break everything?" → We show serial execution

---

## One-Liner Commands

```bash
# Success scenario (patching)
ansible-playbook -i inventory site.yml --tags success

# Pre-check failure
ansible-playbook -i inventory site.yml --tags precheck_fail

# Installation failure
ansible-playbook -i inventory site.yml --tags install_fail

# Validation failure
ansible-playbook -i inventory site.yml --tags validate_fail

# All scenarios
ansible-playbook -i inventory site.yml --tags all_scenarios

# Verbose mode
ansible-playbook -i inventory site.yml --tags success -vvv
```

---

## Contact

- Full documentation: `README.md`
- Test cases: `../docs/rhel_patching_test_cases.md`
- Test cases (DOCX): `../docs/rhel_patching_test_cases_v1.1.docx`
- Main project: `../README.md`

