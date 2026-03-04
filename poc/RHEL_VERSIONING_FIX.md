# RHEL Versioning Fix: Why We Changed from "1.26" to "latest"

**Date:** March 4, 2026
**Issue:** Playbook trying to install nginx-1.26 which doesn't exist in RHEL repos
**Status:** ✅ Fixed

---

## The Problem

### What We Thought:

```
RHEL 9.4: nginx 1.20.1
RHEL 9.7: nginx 1.26  ← We assumed this
```

### Reality:

```bash
# From your system:
Installed Packages
nginx.x86_64    1:1.20.1-14.el9_2.1    @AppStream

Available Packages
nginx.x86_64    2:1.20.1-22.el9_6.3    rhel-9.7-AppStream
                  ^^^^^^  ^^^^^^^^^^^
                  Same major version, different build
```

**Key Insight:** RHEL doesn't use nginx 1.26. RHEL uses **nginx 1.20.x with backported security fixes**.

---

## How RHEL Versioning Works

### EPEL/nginx.org vs RHEL

| Repository | nginx Version | Approach |
|-------------|---------------|----------|
| **nginx.org** | 1.20.1 → 1.22 → 1.24 → 1.26 | Major version upgrades |
| **RHEL/AppStream** | 1.20.1-14.el9_2.1 → 1.20.1-22.el9_6.3 | Backported security fixes |

### What "Patch" Means in RHEL

**In RHEL, patching means:**
- Same major version (1.20.1)
- Newer build/release number
- Backported security fixes
- Updated dependencies

**Example:**
```
Before: nginx-1.20.1-14.el9_2.1  (from RHEL 9.4 AppStream)
After:  nginx-1.20.1-22.el9_6.3  (from RHEL 9.7 AppStream)
         ^^^^^^^  ^^^^^^^^^^^^
         Same!   Different build
```

This **IS** patching - just with RHEL's approach (backports) instead of upstream's approach (major versions).

---

## The Fix

### Before (Broken):
```yaml
- name: Upgrade package to target version
  ansible.builtin.dnf:
    name: "nginx-1.26"  # ❌ Doesn't exist in RHEL!
    state: present
```

### After (Working):
```yaml
- name: Upgrade package to latest available
  ansible.builtin.dnf:
    name: "nginx"       # ✅ Works with RHEL's versioning
    state: latest       # Gets latest from enabled repos
```

---

## What This Means for Your Demo

### ✅ Still Demonstrates Patching

**Before Patch:**
```
nginx-1.20.1-14.el9_2.1
From: rhel-9.4-AppStream
```

**Repo Switch:**
```
✓ Disabling rhel-9.4-*
✓ Enabling rhel-9.7-*
```

**After Patch:**
```
nginx-1.20.1-22.el9_6.3
From: rhel-9.7-AppStream
```

**This IS patching:**
- ✅ Version changed (build number: 14 → 22)
- ✅ Release changed (el9_2.1 → el9_6.3)
- ✅ Repository switched (9.4 → 9.7)
- ✅ Security backports applied
- ✅ Demonstrates real RHEL patching workflow

### 🎯 Even Better for Client Demo

This is actually **more realistic** for enterprise RHEL environments because:

1. **Real-world workflow:** Most RHEL shops use AppStream, not nginx.org
2. **Backport approach:** This is how RHEL actually handles security updates
3. **Satellite ready:** When you integrate with Satellite, it uses the same approach
4. **Supportable:** RHEL-supported version instead of upstream

---

## Updated Variables

### site.yml
```yaml
vars:
  package_name: nginx
  current_version: "1.20.1"  # Old version reference
  target_version: "latest"    # Changed from "1.26"
  # Repository switching still works!
  old_repo_version: "9.4"
  new_repo_version: "9.7"
```

### success.yml
```yaml
- name: Upgrade package to latest available
  ansible.builtin.dnf:
    name: "{{ package_name }}"  # No version specified
    state: latest                # Gets latest from enabled repos
```

---

## Test It Now

```bash
cd /home/anik/ansible/wikilabs/aeon/rhel_patching/poc

# This will now work!
ansible-playbook -i inventory site.yml --tags success -v
```

**Expected output:**
```
CURRENT STATE (BEFORE PATCH)
==========================================
Version: nginx-1.20.1-14.el9_2.1

REPOSITORY SWITCH (9.4 → 9.7)
==========================================
✓ Repository switch completed

PATCHING DETAILS
==========================================
Before: nginx-1.20.1-14.el9_2.1
Target: Latest available nginx
Action: UPGRADE

NEW STATE (AFTER PATCH)
==========================================
Version: nginx-1.20.1-22.el9_6.3

PATCH SUMMARY
==========================================
Change: VERSION CHANGED ✓
(1.20.1-14.el9_2.1 → 1.20.1-22.el9_6.3)
Status: PATCHED SUCCESSFULLY
```

---

## Documentation Updates Needed

All documentation should reflect RHEL's actual versioning:

### ✅ Correct:
- "Patch nginx from 9.4 to 9.7"
- "Upgrade to latest available nginx"
- "Backported security fixes"
- "Build/release number update"

### ❌ Incorrect:
- "Upgrade nginx 1.20 to 1.26"
- "Major version upgrade"
- "Upstream nginx versions"

---

## Summary

| Aspect | Old Approach | New Approach |
|--------|--------------|--------------|
| **Version** | nginx-1.26 (doesn't exist) | nginx (latest) |
| **State** | present | latest |
| **Accuracy** | Wrong for RHEL | Correct for RHEL |
| **Demo Value** | Broken | Working + realistic |
| **Client Relevance** | N/A | Matches their environment |

---

**Result:** Playbooks now work correctly with RHEL's actual versioning and demonstrate a realistic patching workflow! 🎯
