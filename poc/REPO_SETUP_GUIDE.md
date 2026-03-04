# Repository Setup Guide - RHEL 9.4 → 9.7 Patching

**Purpose:** Configure dual repositories to demonstrate realistic RHEL minor version upgrade patching

---

## Understanding the Approach

### Why Two Repositories?

This POC simulates a **real-world scenario** where servers are patched across RHEL minor versions:

| Aspect | RHEL 9.4 (Before) | RHEL 9.7 (After) |
|--------|-------------------|------------------|
| **Repository** | rhel-9.4-appstream | rhel-9.7-appstream |
| **nginx version** | 1.20.1 | 1.26.x |
| **OS kernel** | 9.4 kernel | 9.4 kernel (unchanged) |
| **Application** | Old nginx | New nginx ✅ |

### What Happens During Patching?

1. **Pre-patch**: Server using RHEL 9.4 repos, nginx 1.20.1 installed
2. **Repo switch**: Playbook disables 9.4, enables 9.7 repos
3. **Patching**: nginx upgrades from 1.20.1 → 1.26 using 9.7 repos
4. **Post-patch**: Server now uses 9.7 repos for future updates

**Note**: OS kernel remains at 9.4 (kernel upgrade is separate from app patching)

---

## Prerequisites

### On Your Jump Server

```bash
# Verify you have both RHEL repositories
ls -la /var/www/html/repos/
# Expected output:
# drwxr-xr-x 4 root root 4096 Jan 15 10:30 rhel-9.4
# drwxr-xr-x 4 root root 4096 Jan 15 10:30 rhel-9.7

# Verify each has baseos and appstream
ls -la /var/www/html/repos/rhel-9.4/
# Expected:
# drwxr-xr-x 2 root root 4096 Jan 15 10:30 baseos
# drwxr-xr-x 2 root root 4096 Jan 15 10:30 appstream

# Check nginx versions in each
grep -R "nginx" /var/www/html/repos/rhel-9.4/appstream/ | head -3
# Should show nginx-1.20.1 packages

grep -R "nginx" /var/www/html/repos/rhel-9.7/appstream/ | head -3
# Should show nginx-1.26 packages
```

### On Your Target RHEL Host

- OS: RHEL 9.4
- SSH access configured
- Sudo/root access available
- Can reach jump server HTTP repos

---

## Step-by-Step Configuration

### Step 1: Configure RHEL 9.4 Repositories

```bash
# On target host
sudo tee /etc/yum.repos.d/rhel-9.4.repo <<'EOF'
[rhel-9.4-baseos]
name=RHEL 9.4 BaseOS
baseurl=http://<your-jump-server-ip>/repos/rhel-9.4/baseos/
enabled=1
gpgcheck=0
priority=1

[rhel-9.4-appstream]
name=RHEL 9.4 AppStream
baseurl=http://<your-jump-server-ip>/repos/rhel-9.4/appstream/
enabled=1
gpgcheck=0
priority=1
EOF
```

### Step 2: Configure RHEL 9.7 Repositories (Disabled)

```bash
sudo tee /etc/yum.repos.d/rhel-9.7.repo <<'EOF'
[rhel-9.7-baseos]
name=RHEL 9.7 BaseOS
baseurl=http://<your-jump-server-ip>/repos/rhel-9.7/baseos/
enabled=0
gpgcheck=0
priority=2

[rhel-9.7-appstream]
name=RHEL 9.7 AppStream
baseurl=http://<your-jump-server-ip>/repos/rhel-9.7/appstream/
enabled=0
gpgcheck=0
priority=2
EOF
```

### Step 3: Test Repository Configuration

```bash
# Clean cache
sudo dnf clean all

# List enabled repos (should show only 9.4)
sudo dnf repolist
# Expected output:
# repo id                    repo name
# rhel-9.4-appstream         RHEL 9.4 AppStream
# rhel-9.4-baseos            RHEL 9.4 BaseOS

# Check available nginx version from 9.4
sudo dnf info nginx
# Look for: Version : 1.20.1
```

### Step 4: Install Old nginx Version

```bash
# Install from 9.4 repo
sudo dnf install nginx -y

# Verify version
rpm -q nginx
# Expected: nginx-1.20.1-xxxx.el9_4.x86_64

# Start service
sudo systemctl start nginx
sudo systemctl enable nginx

# Verify service running
sudo systemctl is-active nginx
# Expected: active
```

### Step 5: Verify 9.7 Has Newer Version

```bash
# Temporarily enable 9.7 to check
sudo dnf --enablerepo=rhel-9.7-appstream info nginx | grep -E "Version|Release"

# Should show higher version (1.26 or similar)

# Disable 9.7 again (playbook will enable it)
sudo dnf config-manager --set-disabled rhel-9.7-*
```

---

## Verification Checklist

Before running the POC playbook:

- [ ] RHEL 9.4 repos enabled: `dnf repolist | grep 9.4`
- [ ] RHEL 9.7 repos disabled: `! dnf repolist | grep 9.7`
- [ ] nginx 1.20.1 installed: `rpm -q nginx | grep 1.20`
- [ ] nginx service running: `systemctl is-active nginx`
- [ ] 9.7 has newer nginx: `dnf --enablerepo=rhel-9.7-appstream info nginx | grep 1.26`
- [ ] Can reach repos: `curl -I http://<jump-server>/repos/rhel-9.4/`

---

## How the Playbook Handles the Switch

**All scenarios except precheck_fail** include automatic repo switching:

```yaml
# Phase 1.5: REPOSITORY SWITCH (9.4 → 9.7)
- name: Disable RHEL 9.4 repositories (if present)
  ansible.builtin.command: dnf config-manager --set-disabled rhel-9.4-*

- name: Enable RHEL 9.7 repositories
  ansible.builtin.command: dnf config-manager --set-enabled rhel-9.7-*

- name: Clean DNF cache after repo switch
  ansible.builtin.command: dnf clean all
```

**Scenarios with repo switch:**
- ✅ **Success scenario** - Switches repos, patches successfully
- ✅ **Install failure** - Switches repos, then fails during install
- ✅ **Validation failure** - Switches repos, installs, fails validation

**Scenario without repo switch:**
- ⚠️ **Pre-check failure** - Fails before repo switch (as designed)

**What you'll see during playbook run:**

```
PHASE 1.5: REPOSITORY SWITCH (9.4 → 9.7)
==========================================
Current repos:
rhel-9.4-appstream         RHEL 9.4 AppStream
rhel-9.4-baseos            RHEL 9.4 BaseOS

✓ Repository switch completed
Now using: RHEL 9.7 repositories
New repos:
rhel-9.7-appstream         RHEL 9.7 AppStream
rhel-9.7-baseos            RHEL 9.7 BaseOS
```

---

## Troubleshooting

### "Cannot find package nginx"

**Problem**: Repo not accessible

**Solution**:
```bash
# Test HTTP access
curl http://<jump-server-ip>/repos/rhel-9.4/

# Check repo file syntax
cat /etc/yum.repos.d/rhel-9.4.repo

# Check firewall on jump server
sudo firewall-cmd --list-all
```

### "9.7 repo not found during playbook"

**Problem**: 9.7 repo file not created on target

**Solution**:
```bash
# Verify repo file exists
ls -la /etc/yum.repos.d/ | grep 9.7

# Test manually enabling
sudo dnf config-manager --set-enabled rhel-9.7-*
sudo dnf repolist | grep 9.7
```

### "Wrong nginx version installed"

**Problem**: Multiple repos with different priorities

**Solution**:
```bash
# Check all repos
sudo dnf repolist all

# Ensure 9.4 is disabled when testing 9.7
sudo dnf config-manager --set-disabled rhel-9.4-*
sudo dnf config-manager --set-enabled rhel-9.7-*

# Check which repo provides nginx
sudo dnf repo-pkgs nginx
```

### "Service won't start after patch"

**Problem**: nginx configuration incompatible with new version

**Solution**:
```bash
# Check nginx error log
sudo tail -f /var/log/nginx/error.log

# Test configuration
sudo nginx -t

# If needed, restore backup
sudo rpm -ivh --force /var/lib/rpmbackup/nginx-1.20.1-*.rpm
```

---

## Manual Testing (Without Ansible)

If you want to test the repo switch manually:

```bash
# 1. Check current state (9.4)
echo "=== BEFORE: RHEL 9.4 ==="
dnf repolist | grep 9.4
rpm -q nginx
systemctl is-active nginx

# 2. Switch to 9.7
echo "=== SWITCHING TO 9.7 ==="
sudo dnf config-manager --set-disabled rhel-9.4-*
sudo dnf config-manager --set-enabled rhel-9.7-*
sudo dnf clean all

# 3. Upgrade nginx
echo "=== UPGRADING NGINX ==="
sudo dnf update nginx -y

# 4. Verify new state
echo "=== AFTER: RHEL 9.7 ==="
dnf repolist | grep 9.7
rpm -q nginx
systemctl is-active nginx

# Expected output:
# BEFORE: nginx-1.20.1-xxxx.el9_4
# AFTER:  nginx-1.26-xxxx.el9_7
```

---

## Repository Switch Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    PATCHING WORKFLOW                        │
└─────────────────────────────────────────────────────────────┘

  BEFORE PATCH                    AFTER PATCH
  ─────────────                   ────────────

  ┌──────────────────┐            ┌──────────────────┐
  │  RHEL 9.4 Repo   │            │  RHEL 9.7 Repo   │
  │  ✓ Enabled       │    ═══>    │  ✓ Enabled       │
  │  nginx 1.20.1    │   SWITCH   │  nginx 1.26      │
  └──────────────────┘            └──────────────────┘
         ↓                               ↓
  ┌──────────────────┐            ┌──────────────────┐
  │ Target Host      │            │ Target Host      │
  │ nginx 1.20.1     │   UPDATE   │ nginx 1.26       │
  │ Service Running  │    ═══>    │ Service Running  │
  └──────────────────┘            └──────────────────┘
```

---

## Quick Reference Commands

```bash
# Check current repos
dnf repolist

# Enable/disable repos manually
sudo dnf config-manager --set-enabled rhel-9.7-*
sudo dnf config-manager --set-disabled rhel-9.4-*

# Check nginx version
rpm -q nginx

# Check available nginx in specific repo
dnf --enablerepo=rhel-9.7-appstream info nginx

# Clean cache
sudo dnf clean all

# Test repo access
curl -I http://<jump-server>/repos/rhel-9.4/appstream/
```

---

## Next Steps

Once repos are configured:

1. Run the success scenario: `ansible-playbook -i inventory site.yml --tags success`
2. Verify version change in output
3. Check service still running
4. Review report: `/tmp/rhel_patching_success_*.txt`

**Full Documentation:**
- [QUICKSTART.md](QUICKSTART.md) - Quick start guide
- [README.md](README.md) - Complete documentation
- [AAP_MIGRATION_GUIDE.md](AAP_MIGRATION_GUIDE.md) - AAP setup instructions
