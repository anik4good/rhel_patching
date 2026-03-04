# Updates: RHEL 9.4 → 9.7 Repository Switch

**Date:** March 4, 2026
**Purpose:** Update all POC scenarios to demonstrate realistic RHEL minor version upgrade patching

---

## Summary

All scenarios now demonstrate the **RHEL 9.4 → 9.7 repository switch** workflow, simulating real-world patching across minor OS versions.

---

## Files Updated

### 1. Playbooks

#### [scenarios/success.yml](scenarios/success.yml)
- ✅ Added: Repository switch phase (1.5)
- ✅ Disables 9.4 repos
- ✅ Enables 9.7 repos
- ✅ Cleans DNF cache
- ✅ Displays before/after repo state

#### [scenarios/install_fail.yml](scenarios/install_fail.yml)
- ✅ Added: Repository switch phase (1.5)
- ✅ Switches repos before installation failure
- ✅ Demonstrates failure after repo switch

#### [scenarios/validate_fail.yml](scenarios/validate_fail.yml)
- ✅ Added: Repository switch phase (1.5)
- ✅ Switches repos before patching
- ✅ Demonstrates validation failure after successful install

#### [scenarios/precheck_fail.yml](scenarios/precheck_fail.yml)
- ⚠️ No changes needed (fails before repo switch by design)

### 2. Main Configuration

#### [site.yml](site.yml)
- ✅ Updated `target_version: "1.26"` (9.7 version)
- ✅ Added repo variables:
  ```yaml
  old_repo_version: "9.4"
  new_repo_version: "9.7"
  repo_switch_enabled: true
  ```

### 3. Documentation

#### [QUICKSTART.md](QUICKSTART.md)
- ✅ Updated: Repository setup instructions
- ✅ Added: 9.4 → 9.7 workflow explanation
- ✅ Updated: Expected output with version 1.26
- ✅ Updated: Demo checklist

#### [REPO_SETUP_GUIDE.md](REPO_SETUP_GUIDE.md)
- ✅ Created: Complete repository setup guide
- ✅ Added: Dual-repo configuration instructions
- ✅ Added: Troubleshooting section
- ✅ Added: Manual testing procedures

---

## Scenario Behavior

### Success Scenario
```
PHASE 1.5: REPOSITORY SWITCH (9.4 → 9.7)
==========================================
✓ Disabling RHEL 9.4 repositories
✓ Enabling RHEL 9.7 repositories
✓ Repository switch completed

PATCH SUMMARY
==========================================
Before: nginx-1.20.1-xxxx.el9_4.x86_64
After:  nginx-1.26-xxxx.el9_7.x86_64
Change:  VERSION CHANGED ✓
==========================================
```

### Install Failure Scenario
```
PHASE 1.5: REPOSITORY SWITCH (9.4 → 9.7)
==========================================
✓ Repository switch completed

PHASE 3: PACKAGE INSTALLATION (with block/rescue)
==========================================
⚠ Attempting install from 9.7 repo...
✗ Installation failed (dependency conflict)
✗ Rescue block activated
✗ Execution stopped
```

### Validation Failure Scenario
```
PHASE 1.5: REPOSITORY SWITCH (9.4 → 9.7)
==========================================
✓ Repository switch completed

PHASE 3: PACKAGE INSTALLATION
==========================================
✓ Installation from 9.7 repo succeeded

PHASE 4: POST-VALIDATION
==========================================
✗ Service validation failed
✗ Execution stopped
```

### Pre-Check Failure Scenario
```
PHASE 1: PRE-CHECK VALIDATION
==========================================
✗ Disk space check failed
✗ Stopped before repo switch
✗ No changes made
```

---

## Repository Setup Required

### Before Running Playbooks

```bash
# 1. Configure 9.4 repos (enabled)
cat > /etc/yum.repos.d/rhel-9.4.repo <<'EOF'
[rhel-9.4-baseos]
name=RHEL 9.4 BaseOS
baseurl=http://<jump-server>/repos/rhel-9.4/baseos/
enabled=1
gpgcheck=0
priority=1

[rhel-9.4-appstream]
name=RHEL 9.4 AppStream
baseurl=http://<jump-server>/repos/rhel-9.4/appstream/
enabled=1
gpgcheck=0
priority=1
EOF

# 2. Configure 9.7 repos (disabled)
cat > /etc/yum.repos.d/rhel-9.7.repo <<'EOF'
[rhel-9.7-baseos]
name=RHEL 9.7 BaseOS
baseurl=http://<jump-server>/repos/rhel-9.7/baseos/
enabled=0
gpgcheck=0
priority=2

[rhel-9.7-appstream]
name=RHEL 9.7 AppStream
baseurl=http://<jump-server>/repos/rhel-9.7/appstream/
enabled=0
gpgcheck=0
priority=2
EOF

# 3. Install nginx from 9.4
sudo dnf install nginx -y
sudo systemctl start nginx
```

### After Running Success Scenario

```bash
# Verify state
rpm -q nginx
# Expected: nginx-1.26-xxxx.el9_7.x86_64

dnf repolist | grep 9.7
# Expected: rhel-9.7-appstream and rhel-9.7-baseos enabled
```

---

## Testing All Scenarios

```bash
cd /home/anik/ansible/wikilabs/aeon/rhel_patching/poc

# 1. Success (with repo switch)
ansible-playbook -i inventory site.yml --tags success -v

# 2. Pre-check failure (no repo switch)
ansible-playbook -i inventory site.yml --tags precheck_fail -v

# 3. Install failure (with repo switch)
ansible-playbook -i inventory site.yml --tags install_fail -v

# 4. Validation failure (with repo switch)
ansible-playbook -i inventory site.yml --tags validate_fail -v
```

---

## Key Benefits of This Approach

1. **Realistic** - Demonstrates actual minor version upgrade scenario
2. **Consistent** - All scenarios (except precheck) use same repo switch logic
3. **Clear** - Playbook output shows repo state changes
4. **Safe** - Pre-check failures happen before repo switch
5. **Production-like** - Mirrors real RHEL patching workflows

---

## Migration Notes

### From Previous Version

If you were using the single-repo approach:

**Before:**
- Both nginx versions in same repo
- Target version: 1.28.2
- No repo switching

**After:**
- Separate 9.4 and 9.7 repos
- Target version: 1.26 (from 9.7)
- Automatic repo switching

### Playbook Compatibility

All existing playbooks work with new approach:
- ✅ Tags remain the same
- ✅ Inventory unchanged
- ✅ Variables updated automatically
- ✅ New repo phase added seamlessly

---

## Troubleshooting

### "9.7 repo not found during playbook"

**Cause:** Repo file not created on target

**Fix:**
```bash
# Verify repo file exists
ls -la /etc/yum.repos.d/ | grep 9.7

# Re-create if missing (see Repository Setup above)
```

### "Wrong version installed"

**Cause:** Repo priorities incorrect

**Fix:**
```bash
# Check repo priorities
sudo dnf repolist all

# Ensure 9.4 is disabled when testing
sudo dnf config-manager --set-disabled rhel-9.4-*
```

### "Repo switch fails"

**Cause:** Network connectivity or incorrect baseurl

**Fix:**
```bash
# Test HTTP access
curl -I http://<jump-server>/repos/rhel-9.7/

# Check firewall on jump server
sudo firewall-cmd --list-all
```

---

## Next Steps

1. **Set up repositories** - Follow [REPO_SETUP_GUIDE.md](REPO_SETUP_GUIDE.md)
2. **Test manually** - Verify repo switch works
3. **Run playbooks** - Test all 4 scenarios
4. **Verify outputs** - Check version changes in reports
5. **Client demo** - Demonstrate failure handling with repo switch

---

## Documentation References

- [REPO_SETUP_GUIDE.md](REPO_SETUP_GUIDE.md) - Complete repository setup
- [QUICKSTART.md](QUICKSTART.md) - Quick start instructions
- [README.md](README.md) - Full documentation
- [AAP_MIGRATION_GUIDE.md](AAP_MIGRATION_GUIDE.md) - AAP setup instructions
