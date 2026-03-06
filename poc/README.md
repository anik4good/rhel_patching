# RHEL Patching POC - Playbook Demonstration

This directory contains demonstration playbooks for the RHEL patching Proof of Concept, showing actual package patching with **RHEL 9.4 → 9.7 repository switch**.

## Overview

These playbooks demonstrate the 4 test cases from the test case document:

| Test Case | Scenario | Tag | Demonstrates |
|-----------|----------|-----|-------------|
| TC-RHEL-001 | Successful patching | `--tags success` | Version upgrade workflow with repo switch |
| TC-RHEL-002 | Pre-check failure (disk space) | `--tags precheck_fail` | Stops before damage |
| TC-RHEL-003 | Installation failure (dependency) | `--tags install_fail` | Rescue block behavior |
| TC-RHEL-004 | Validation failure (service) | `--tags validate_fail` | Post-patch validation |

## What Is Patching vs Installing?

**Installing**: Package not present → Install it
**Patching**: Old version installed → Upgrade to new version

This POC demonstrates **PATCHING** - upgrading from an older version to a newer version using **RHEL 9.4 → 9.7 repository switch**.

### Flexible Repository Support

**The playbooks automatically work with your setup:**

- ✅ **With 9.4/9.7 repos:** Demonstrates repo switch + version upgrade
- ✅ **With default repos:** Demonstrates version upgrade only
- ✅ **Either way:** Full failure handling + validation

No manual configuration needed - the playbooks detect your setup and adapt automatically!

### Repository Switch Approach

The POC demonstrates a **realistic minor OS version upgrade**:

**Before Patch:**
- OS: RHEL 9.4
- Repo: `rhel-9.4-appstream` (enabled)
- nginx: 1.20.1

**During Patch:**
- ✅ Disable 9.4 repos
- ✅ Enable 9.7 repos
- ✅ Clean DNF cache

**After Patch:**
- OS: Still RHEL 9.4 (kernel unchanged)
- Repo: `rhel-9.7-appstream` ✅
- nginx: 1.26 ✅

## Prerequisites

- Ansible control node with Ansible 2.9+
- Target RHEL 8/9 host(s)
- SSH access to target host(s)
- Sudo privileges on target host(s)
- **RHEL 9.4 repository** (old nginx version)
- **RHEL 9.7 repository** (new nginx version) - optional, playbooks work without it

## Repository Setup

### Quick Start: Use Default Repositories (Simplest)

The playbooks work with your **existing RHEL repositories** - no special setup required!

```bash
# Just ensure you have:
# - RHEL 9.4 repos (with nginx 1.20.1)
# - SSH access to target
# - Sudo privileges

# Playbooks will work automatically!
ansible-playbook -i inventory site.yml --tags success
```

### Option 1: Set Up 9.4 → 9.7 Repository Switch (Recommended for Demo)

This demonstrates a realistic minor version upgrade workflow:

```bash
# On target RHEL host - Create 9.4 repo file
cat > /etc/yum.repos.d/rhel-9.4.repo <<'EOF'
[rhel-9.4-baseos]
name=RHEL 9.4 BaseOS
baseurl=http://<jump-server-ip>/repos/rhel-9.4/BaseOS/
enabled=1
gpgcheck=0
priority=1

[rhel-9.4-appstream]
name=RHEL 9.4 AppStream
baseurl=http://<jump-server-ip>/repos/rhel-9.4/AppStream/
enabled=1
gpgcheck=0
priority=1
EOF

# Create 9.7 repo file (DISABLED by default)
cat > /etc/yum.repos.d/rhel-9.7.repo <<'EOF'
[rhel-9.7-baseos]
name=RHEL 9.7 BaseOS
baseurl=http://<jump-server-ip>/repos/rhel-9.7/BaseOS/
enabled=0
gpgcheck=0
priority=2

[rhel-9.7-appstream]
name=RHEL 9.7 AppStream
baseurl=http://<jump-server-ip>/repos/rhel-9.7/AppStream/
enabled=0
gpgcheck=0
priority=2
EOF

# Verify only 9.4 is enabled
sudo dnf repolist
```

**For detailed setup instructions, see [REPO_SETUP_GUIDE.md](REPO_SETUP_GUIDE.md)**

### Option 2: Use Existing Satellite/CDN Repos

```bash
# Your existing RHEL repos work fine
# Just ensure old nginx is installed first
sudo dnf install nginx -y
sudo systemctl start nginx

# Playbooks will use whatever repos are available
```

## Initial Setup for Patching Demo

### Step 1: Install Old Nginx Version from 9.4

```bash
# On target host, ensure 9.4 repos are enabled
sudo dnf config-manager --set-enabled rhel-9.4-*
sudo dnf clean all

# Install nginx from 9.4 (will be 1.20.1)
sudo dnf remove nginx -y
sudo dnf install nginx -y
sudo systemctl start nginx
sudo systemctl enable nginx

# Verify old version

rpm -q nginx
# Expected: nginx-1.20.1-xxxx.el9_4.x86_64

#httpd
# On target host, ensure 9.4 repos are enabled
sudo dnf config-manager --set-enabled rhel-9.4-*
sudo dnf clean all
sudo dnf remove httpd -y
sudo dnf install httpd -y
sudo systemctl start httpd
sudo systemctl enable httpd

# Verify old version
rpm -q httpd

```

### Step 2: Verify New Version Available (Optional)

If using 9.4 → 9.7 repo switch:

```bash
# Temporarily enable 9.7 to check
sudo dnf --enablerepo=rhel-9.7-* info nginx | grep Version
# Should show 1.26 or higher

# Disable 9.7 again (playbook will enable it)
sudo dnf config-manager --set-disabled rhel-9.7-*
```

**Note:** If using default repos, the playbook will use whatever version is available.

## Inventory

Create an `inventory` file:

```ini
[rhel_poc]
rhel-test-01 ansible_host=192.168.1.100 ansible_user=root
```

## Usage

### Run Success Scenario (Patching)

```bash
# This upgrades nginx 1.20.1 → 1.26 with optional repo switch 9.4 → 9.7
ansible-playbook -i inventory site.yml --tags success -v
```

**What happens:**
1. ✅ Pre-checks (disk space, repos, services)
2. ✅ **If 9.4/9.7 repos configured:** Switches from 9.4 to 9.7
3. ✅ **If using default repos:** Uses available repos
4. ✅ Upgrades nginx to latest available (1.26 from 9.7)
5. ✅ Version comparison before/after
6. ✅ Post-validation of services

### Run Failure Scenarios

```bash
# Pre-check failure (disk space)
ansible-playbook -i inventory site.yml --tags precheck_fail

# Installation failure (dependency conflict)
ansible-playbook -i inventory site.yml --tags install_fail

# Validation failure (service not running after patch)
ansible-playbook -i inventory site.yml --tags validate_fail
```

### Run All Scenarios

```bash
ansible-playbook -i inventory site.yml --tags all_scenarios
```

## What Each Scenario Demonstrates

### TC-RHEL-001: Success Scenario (Patching)

**Before Patch:**
- nginx 1.20.1 installed
- Service running
- Using RHEL 9.4 repos (if configured)

**After Patch:**
- nginx 1.26 installed ✅
- Service running ✅
- Backup created ✅
- Version change confirmed ✅
- Using RHEL 9.7 repos (if configured) ✅

**Demonstrates:**
- ✅ Pre-checks pass (disk, repository, subscription)
- ✅ **Repository switch (9.4 → 9.7) if configured**
- ✅ Backup created before patching
- ✅ Package upgrades (not just installs)
- ✅ Before/after version comparison
- ✅ Post-validation confirms service running
- ✅ Summary report with version change details

**Key Learning**: Patching workflow with version upgrade validation and optional repository switching.

### TC-RHEL-002: Pre-Check Failure (Disk Space)

- ✅ Disk space check fails
- ✅ Playbook stops immediately
- ✅ No patching attempted
- ✅ No system changes made
- ✅ Clear error message displayed

**Key Learning**: Pre-flight validation prevents damage before it happens.

### TC-RHEL-003: Installation Failure (Dependency Conflict)

- ✅ All pre-checks pass
- ✅ Backup created successfully
- ✅ Installation attempt fails (dependency conflict)
- ✅ Block/rescue structure activates
- ✅ Error logged clearly
- ✅ Execution stops (no further hosts patched)
- ✅ Backup preserved for rollback

**Key Learning**: Graceful error handling with rescue blocks and blast radius control.

### TC-RHEL-004: Validation Failure (Service Won't Start)

- ✅ Package patches successfully
- ✅ Post-patch service check fails
- ✅ NOT marked as success (accurate reporting)
- ✅ Execution stops
- ✅ Backup preserved
- ✅ Rollback instructions provided

**Key Learning**: Post-validation catches issues that installation alone doesn't detect.

## Patching Workflow in Success Scenario

### 1. Pre-Patch Version Check
```
CURRENT STATE (BEFORE PATCH)
==========================================
Package: nginx
Version: nginx-1.20.1-xxxx.el9_4.x86_64
Repository: rhel-9.4-appstream (or default)
Status: Installed
==========================================
```

### 2. Backup Creation
```
✓ Backup created at /var/lib/rpmbackup/
File: nginx-1.20.1-*.rpm
```

### 3. Repository Switch (If 9.4/9.7 Repos Configured)
```
PHASE 1.5: REPOSITORY SWITCH (9.4 → 9.7)
==========================================
✓ Disabling RHEL 9.4 repositories
✓ Enabling RHEL 9.7 repositories
✓ Cleaning DNF cache
==========================================
```

### 4. Patching (Upgrade)
```
PATCHING DETAILS
==========================================
Before: nginx-1.20.1-xxxx.el9_4.x86_64
Target: nginx-1.26-xxxx.el9_7.x86_64
Action: UPGRADE
==========================================
```

### 5. Post-Patch Version Check
```
NEW STATE (AFTER PATCH)
==========================================
Package: nginx
Version: nginx-1.26-xxxx.el9_7.x86_64
Repository: rhel-9.7-appstream (or default)
Status: Installed
==========================================
```

### 6. Version Comparison
```
PATCH SUMMARY
==========================================
Before: nginx-1.20.1-xxxx.el9_4.x86_64
After:  nginx-1.26-xxxx.el9_7.x86_64
Change:  VERSION CHANGED ✓
Status:  PATCHED SUCCESSFULLY
==========================================
```

## Expected Output (Success Scenario)

```
PLAY [RHEL Patching POC - Success Scenario] **************

TASK [Display target server information]
ok: [rhel-test-01]
✓ OS: Red Hat Enterprise Linux 9.0
✓ IP: 192.168.1.100

TASK [Check sufficient disk space]
ok: [rhel-test-01]
✓ Disk space check passed: 16% used

TASK [Verify repository accessible]
ok: [rhel-test-01]
✓ Repository accessible

TASK [Get current package version]
ok: [rhel-test-01]
CURRENT STATE (BEFORE PATCH)
==========================================
Package: nginx
Version: nginx-1.20.1-xxxx.el9_4.x86_64
==========================================

TASK [Repository switch result]
ok: [rhel-test-01]
✓ Repository switch completed (9.4 → 9.7)
OR
⚠ Using default repositories (no 9.4/9.7 repos configured)

TASK [Upgrade package to target version]
changed: [rhel-test-01]
✓ Patching completed
Changes: 1 update

TASK [Get new package version]
ok: [rhel-test-01]
NEW STATE (AFTER PATCH)
==========================================
Package: nginx
Version: nginx-1.26-xxxx.el9_7.x86_64
==========================================

TASK [Display version comparison]
ok: [rhel-test-01]
PATCH SUMMARY
==========================================
Before: nginx-1.20.1-xxxx.el9_4.x86_64
After:  nginx-1.26-xxxx.el9_7.x86_64
Change:  VERSION CHANGED ✓
Status:  PATCHED SUCCESSFULLY
==========================================

PLAY RECAP
rhel-test-01: ok=20 changed=2 failed=0

Status: PATCHED SUCCESSFULLY
```

## Files Generated

Each scenario creates a report file on the target host:

- `/tmp/rhel_patching_success_<hostname>.txt` - Contains before/after versions
- `/tmp/rhel_patching_install_fail_<hostname>.txt` - Contains error details
- `/tmp/rhel_patching_validate_fail_<hostname>.txt` - Contains rollback instructions

## Logs

Logs are created in `/var/log/rhel_patching_*.log` on target hosts.

## Key Playbook Features Demonstrated

### Serial Execution
```yaml
serial: 1  # One host at a time
```
**Benefit**: Limits blast radius, allows investigation between hosts

### Stop on Failure
```yaml
max_fail_percentage: 0  # Stop on any failure
```
**Benefit**: No cascading failures, protects production

### Block/Rescue Structure
```yaml
- block:
    # Patching tasks
  rescue:
    # Error handling
  always:
    # Cleanup (always runs)
```
**Benefit**: Graceful error handling, cleanup always happens

### Pre-Flight Validation
- Disk space check (stops if > 90% used)
- Repository accessibility check
- Subscription status check
- Service baseline check

### Version Comparison
- Before patch: Check current version
- After patch: Verify new version
- Compare: Show version change ✓

## Customization

### Change Package Versions

Edit in `site.yml`:
```yaml
vars:
  package_name: nginx
  current_version: "1.20.1"      # Old version (for reference)
  target_version: "1.26"         # New version (from RHEL 9.7)
  # Repository switching settings
  old_repo_version: "9.4"
  new_repo_version: "9.7"
```

### Change Package Name

```yaml
vars:
  package_name: httpd           # or tomcat, postgresql, etc.
```

### Disable Repository Switching

If you don't want the repo switch feature, the playbooks automatically detect and skip it when custom repos aren't configured. No changes needed!

### Modify Disk Space Threshold

Edit in `site.yml` (precheck_fail scenario):
```yaml
vars:
  disk_threshold: 90  # Fail if more than 90% used
```

The validation logic: `when: disk_usage.stdout|int > disk_threshold`
- With `disk_threshold: 90`, playbook fails if disk usage exceeds 90%
- Change this value to adjust the threshold as needed

## Troubleshooting

### "Package not found in repository"

**Problem**: Target version not available in repo

**Solution**:
```bash
# Check what's available
dnf list available | grep nginx

# If using 9.4/9.7 repos, verify 9.7 has the version
dnf --enablerepo=rhel-9.7-* info nginx
```

### "Old version not installed"

**Problem**: You skipped the initial setup

**Solution**:
```bash
# Install old version first from 9.4
sudo dnf config-manager --set-enabled rhel-9.4-*
sudo dnf install nginx -y
sudo systemctl start nginx

# Verify
rpm -q nginx
```

### "Repository switch fails - No matching repo"

**Problem**: Custom 9.4/9.7 repos not configured (not an error!)

**Solution**:
```bash
# This is expected! Playbooks work fine without custom repos
# They'll use your default repositories instead

# To see what's happening, run with -v
ansible-playbook -i inventory site.yml --tags success -v

# Look for: "⚠ Using default repositories (no 9.4/9.7 repos configured)"
```

### "DNF can't find local repo"

**Problem**: Repo configuration incorrect or network issue

**Solution**:
```bash
# Test repo access
curl http://<jump-server-ip>/repos/rhel-9.4/BaseOS/

# Verify repo files
ls -la /etc/yum.repos.d/ | grep rhel

# Clean and retry
sudo dnf clean all
sudo dnf repolist
```

### "Both 9.4 and 9.7 repos showing in repolist"

**Problem**: 9.7 repos should start disabled

**Solution**:
```bash
# Disable 9.7 repos before running playbook
sudo dnf config-manager --set-disabled rhel-9.7-*
sudo dnf repolist  # Should only show 9.4 repos
```

## Setup Checklist for Client Demo

Before demonstrating to client:

### Repository Setup
- [ ] **Option A (Recommended):** RHEL 9.4 and 9.7 repos configured
  - [ ] 9.4 repos enabled on target
  - [ ] 9.7 repos disabled (will be enabled by playbook)
  - [ ] Target can access both repos
  - [ ] See [REPO_SETUP_GUIDE.md](REPO_SETUP_GUIDE.md) for details
- [ ] **OR Option B (Simple):** Use existing RHEL repos
  - [ ] Any RHEL repos available
  - [ ] Old nginx version installed

### Target Host Setup
- [ ] Old nginx version (1.20.x) installed on target
- [ ] nginx service is running
- [ ] SSH access from control node
- [ ] Sudo privileges available

### Ansible Setup
- [ ] Inventory file configured
- [ ] SSH connectivity tested: `ansible rhel_poc -i inventory -m ping`
- [ ] Run success scenario once to verify
- [ ] Check report file generates correctly

## Demo Script Suggestion

### 1. Show Initial State
```bash
# Show old version
ansible rhel_poc -i inventory -m shell -a "rpm -q nginx"
```

### 2. Run Patching
```bash
ansible-playbook -i inventory site.yml --tags success -v
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
# Show what happens when things go wrong
ansible-playbook -i inventory site.yml --tags precheck_fail
ansible-playbook -i inventory site.yml --tags install_fail
ansible-playbook -i inventory site.yml --tags validate_fail
```

### 5. Explain Safety Features
- Serial execution (one at a time)
- Pre-flight validation
- Stop on failure
- Rescue blocks
- Rollback capability

## Next Steps

After demonstrating to client:

1. **Get Feedback**: Does patching approach meet their needs?
2. **Discuss Satellite Integration**: How to integrate with their Satellite
3. **Plan Customization**: What packages, what schedule, what environments?
4. **Production Readiness**: What's needed for production deployment?

## Documentation

| File | Purpose |
|------|---------|
| [QUICKSTART.md](QUICKSTART.md) | Quick reference guide |
| [REPO_SETUP_GUIDE.md](REPO_SETUP_GUIDE.md) | Detailed 9.4/9.7 repository setup |
| [AAP_MIGRATION_GUIDE.md](AAP_MIGRATION_GUIDE.md) | Setup for Ansible Automation Platform |
| [PLAYBOOK_FIX_SUMMARY.md](PLAYBOOK_FIX_SUMMARY.md) | Recent playbook updates |
| [CHANGELOG_9.4_TO_9.7.md](CHANGELOG_9.4_TO_9.7.md) | Repository switch changes |

## Project References

- Test Cases Document: `../docs/rhel_patching_test_cases.md`
- Test Cases (DOCX): `../docs/rhel_patching_test_cases_v1.1.docx`
- Main Playbook: `../master_patch.yaml`

---

**Note**: These playbooks demonstrate actual patching (version upgrade) behavior with optional repository switching. The playbooks automatically detect your repository configuration and work with:
- ✅ Custom 9.4 → 9.7 repos (full repo switch demonstration)
- ✅ Default RHEL repos (simple patching workflow)

For production use, integrate with your Satellite server and customize based on specific requirements.
