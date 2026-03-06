# RHEL OS Version Patching POC

**Version:** 1.0
**Date:** March 5, 2026
**Purpose:** Proof of concept for RHEL OS minor version upgrade automation

---

## Overview

This POC demonstrates automated RHEL OS version upgrades (9.0 → 9.4) with comprehensive failure handling. It addresses the client's primary concern: **"If patching fails, what will the playbook do?"**

### What This Demonstrates

| Capability | How It's Shown |
|------------|----------------|
| **Successful OS upgrade** | TC-OS-001: Complete 9.0 → 9.4 upgrade with reboot |
| **Pre-flight validation** | TC-OS-002: Stops before upgrade when issues detected |
| **Failure handling** | TC-OS-003: Handles DNF upgrade failures gracefully |
| **Reboot management** | Automatic reboot detection and controlled execution |
| **Post-upgrade validation** | Version and service verification after upgrade |
| **Clear reporting** | Summary files with before/after information |

---

## Prerequisites

### Test Systems

- RHEL 9.0 system (for testing)
- RHEL 9.4 repository configured and accessible
- Root or sudo access
- SSH connectivity
- VM snapshot created before testing

### Repository Setup

**IMPORTANT:** You must manually configure the RHEL 9.4 repository before running these playbooks. The playbooks assume the repository is already configured.

```bash
# Example: Configure local 9.4 repo
cat > /etc/yum.repos.d/rhel-9.4.repo << EOF
[rhel-9.4-baseos]
name=RHEL 9.4 BaseOS
baseurl=http://your-repo-server/rhel/9.4/BaseOS
enabled=1
gpgcheck=0

[rhel-9.4-appstream]
name=RHEL 9.4 AppStream
baseurl=http://your-repo-server/rhel/9.4/AppStream
enabled=1
gpgcheck=0
