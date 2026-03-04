# RHEL Patching Automation - Test Cases & Failure Handling (POC)

**Document Version:** 1.0
**Date:** 2026-03-03
**Architecture:** Red Hat Satellite (Content Control) + Ansible Automation Platform (Orchestration)
**Environment:** RHEL 8/9
**Focus:** Playbook Failure Handling & Recovery

---

## 1. Introduction

### 1.1 Purpose

This Proof of Concept (POC) demonstrates how **Ansible Automation Platform (AAP)** can orchestrate RHEL patching on **Red Hat Satellite-managed environments** with intelligent failure handling capabilities.

The primary client concern addressed by this POC:

> **"If patching fails, what will the playbook do?"**

This document provides comprehensive test cases demonstrating the Ansible playbook's ability to:
- Detect failures at multiple stages
- Stop automatically to prevent cascading issues
- Handle errors gracefully with rescue blocks
- Provide clear error reporting
- Support rollback procedures

### 1.2 Architecture Overview

#### Separation of Concerns

| Component | Responsibility |
|-----------|---------------|
| **Red Hat Satellite** | Content governance, Content View versioning, Lifecycle promotion, Approved patch visibility |
| **Ansible/AAP** | Orchestration timing, Batch execution, Validation, Stop-on-failure, Reporting, Rollback coordination |

#### Integration Flow

```
┌─────────────────┐         ┌─────────────────┐         ┌─────────────────┐
│   Satellite     │         │     Ansible     │         │   Target Host   │
│                 │         │      AAP        │         │                 │
│  1. Publish CV  │────────▶│  2. Orchestrate │────────▶│  3. Apply Patch │
│     v1.1        │         │     Execution   │         │                 │
│                 │         │                 │         │                 │
│  4. Promote to  │         │  5. Validate    │◀────────│  6. Service OK? │
│     UAT         │         │     Services    │         │                 │
│                 │         │                 │         │                 │
│  7. Rollback CV │◀────────│  8. Coordinate │◀────────│  9. Failure?    │
│     if needed   │         │     Recovery    │         │                 │
└─────────────────┘         └─────────────────┘         └─────────────────┘
```

### 1.3 Playbook Design Philosophy

**"Fail safely, stop automatically, recover gracefully"**

The Ansible playbook implements the following failure handling mechanisms:

#### Pre-Flight Validation Gates
- Disk space verification
- Repository accessibility check
- Subscription and Content View binding validation
- Service status pre-check
- Network connectivity verification

#### Execution Safety Controls
- **Serial execution**: One server at a time (`serial: 1`)
- **Stop on failure**: No further hosts patched after failure (`max_fail_percentage: 0`)
- **Block/Rescue structure**: Graceful error handling with cleanup
- **Immediate stop**: `meta: end_play` to halt execution

#### Post-Patch Validation
- Service health checks
- Application endpoint validation
- Kernel version verification (if applicable)
- Dependency conflict detection

#### Comprehensive Reporting
- JSON output with detailed results
- Before/after package versions
- Error messages with timestamps
- Host status tracking
- Audit trail for compliance

### 1.4 Testing Approach

This POC uses a scenario-based testing approach:

1. **Success Scenario**: Normal flow with all validations passing
2. **Pre-Check Failure**: Disk space issue detected before patching
3. **Installation Failure**: Dependency conflict during package installation
4. **Post-Validation Failure**: Service failure after patch installation

Each scenario includes:
- Failure simulation method
- Expected playbook behavior
- Validation that safety mechanisms work
- Evidence collection requirements

### 1.5 Prerequisites

#### Infrastructure Requirements
- Red Hat Satellite 6.x server
- Ansible Automation Platform (or AWX) 2.x+
- Test RHEL 8/9 hosts registered to Satellite
- Network connectivity between all components

#### Satellite Setup
- Lifecycle environments: Library → UAT → PROD → DR
- Content Views with versioning
- Hosts registered to appropriate lifecycle environments
- Subscription management configured

#### Ansible Setup
- Inventory file with target hosts
- Playbook with failure handling logic
- SSH keys or credentials configured
- Service account with appropriate permissions

#### Test Data
- Sample packages for testing (e.g., nginx)
- Failure simulation scripts
- VM snapshots or backups for rollback testing

---

## 2. Playbook Failure Handling Architecture

### 2.1 Multi-Layer Validation

The playbook implements defense-in-depth with validation at three layers:

```
┌─────────────────────────────────────────────────────────────┐
│                    PRE-EXECUTION LAYER                      │
│  • Disk space check     • Repository connectivity           │
│  • Subscription status  • Content View binding              │
│  • Service pre-check    • Network reachability              │
└─────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────┐
│                      EXECUTION LAYER                         │
│  • Block/Rescue structure   • Serial execution               │
│  • Error detection          • Graceful failure handling      │
│  • Automatic stop           • Backup creation                │
└─────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────┐
│                    POST-EXECUTION LAYER                     │
│  • Service health check   • Application validation          │
│  • Package verification   • Log analysis                    │
│  • Status reporting       • Rollback triggers               │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 Stop-On-Failure Mechanism

```yaml
# Playbook configuration
- hosts: rhel_servers
  serial: 1                      # One host at a time
  max_fail_percentage: 0         # Stop on ANY failure
  any_errors_fatal: true         # Fatal errors stop everything
```

**What this achieves:**
- Limits blast radius to single server
- Prevents cascading failures
- Allows investigation before proceeding
- Protects production stability

### 2.3 Block/Rescue Structure

```yaml
- block:
    - name: Install security updates
      ansible.builtin.dnf:
        name: "{{ item }}"
        state: present
        security: yes
      register: install_result

  rescue:
    - name: Log installation failure
      ansible.builtin.debug:
        msg: "Package {{ item }} failed to install"

    - name: Mark host as failed
      ansible.builtin.set_fact:
        patch_status: "failed"

    - name: Stop further execution
      meta: end_play

  always:
    - name: Always collect logs
      ansible.builtin.fetch:
        src: /var/log/dnf.log
        dest: logs/{{ inventory_hostname }}_dnf.log
```

**Benefits:**
- Graceful error handling
- Cleanup tasks in `always` block
- Clear error messaging
- Immediate stop capability

### 2.4 Rollback Capabilities

#### Automatic Rollback Triggers
- Service validation fails
- Application health check fails
- Kernel panic after reboot
- Manual abort by operator

#### Rollback Methods
1. **Satellite Content View Reversion**
   ```bash
   # Reassign host to previous CV
   hammer host update --id <host-id> --content-view-id <cv-id>

   # Sync to previous state
   dnf distro-sync
   ```

2. **Package Downgrade**
   ```bash
   dnf history undo <transaction-id>
   ```

3. **VM Snapshot Revert**
   ```bash
   # Via hypervisor API
   virsh snapshot-revert <domain> <snapshot-name>
   ```

---

## 3. Test Cases

### Test Case Template

| Field | Description |
|-------|-------------|
| **Test Case ID** | Unique identifier (TC-RHEL-XXX) |
| **Title** | Brief description of the scenario |
| **Type** | Success / Failure |
| **Description** | Detailed scenario explanation |
| **Pre-conditions** | Required state before testing |
| **Test Steps** | Step-by-step execution guide |
| **Expected Playbook Behavior** | How playbook should handle the scenario |
| **Expected Results** | Specific outcomes to verify |
| **Actual Results** | To be filled during execution |
| **Status** | Pass / Fail / Blocked |

---

## TC-RHEL-001: Successful End-to-End Patching

**Type:** Success Scenario
**Priority:** High
**Estimated Duration:** 30 minutes

### Description

Demonstrates the complete patching workflow when all validations pass and packages install successfully. This scenario confirms the playbook functions correctly under ideal conditions.

### Pre-Conditions

- [ ] Test host registered to Satellite UAT environment
- [ ] Content View CV_RHEL9_POC v1.0 promoted to UAT
- [ ] CV v1.1 published with nginx-2.3 security update
- [ ] Sufficient disk space (>20% free)
- [ ] All services running normally
- [ ] SSH connectivity from Ansible control node
- [ ] VM snapshot created (for rollback if needed)

### Test Data

| Parameter | Value |
|-----------|-------|
| Test Host | uat-rhel9-01.example.com |
| Package | nginx |
| Current Version | 1.20.1-8.el9_2 |
| Target Version | 1.28.2-1.el9.ngx |
| Architecture | x86_64 |

### Test Steps

#### Step 1: Pre-Execution Verification

1. Log in to Ansible control node
2. Verify inventory configuration:
   ```bash
   ansible-inventory --list -i inventory
   ```
3. Check host subscription:
   ```bash
   ansible uat-rhel9-01 -m shell -a "subscription-manager status"
   ```
4. Verify Content View binding:
   ```bash
   ansible uat-rhel9-01 -m shell -a "cat /etc/yum.repos.d/redhat.repo | grep content_view"
   ```

**Expected Result:**
- Host appears in inventory
- Subscription status: "Subscribed"
- Content View displayed in repository configuration

#### Step 2: Execute Playbook

1. Navigate to playbook directory
2. Run the patching playbook:
   ```bash
   ansible-playbook -i inventory master_patch.yaml --limit uat-rhel9-01
   ```

**Expected Result:**
- Playbook starts without errors
- Pre-check tasks execute sequentially

#### Step 3: Verify Pre-Checks Pass

Watch for the following pre-check tasks:

1. **Disk Space Check**
   ```yaml
   TASK [Check sufficient disk space]
   ok: [uat-rhel9-01]
   ```

2. **Repository Connectivity**
   ```yaml
   TASK [Verify Satellite repository accessible]
   ok: [uat-rhel9-01]
   ```

3. **Service Pre-Check**
   ```yaml
   TASK [Verify service running before patching]
   ok: [uat-rhel9-01]
   ```

**Expected Result:**
- All pre-checks return "ok"
- No failures or warnings
- Playbook proceeds to installation phase

#### Step 4: Package Installation

1. Playbook displays package information:
   ```
   Current: nginx-1.20.1-8.el9_2.x86_64
   Target:  nginx-1.28.2-1.el9.ngx.x86_64
   ```

2. Backup is created:
   ```yaml
   TASK [Backup current RPM]
   changed: [uat-rhel9-01]
   ```

3. Package installation:
   ```yaml
   TASK [Install security updates]
   changed: [uat-rhel9-01]
   ```

**Expected Result:**
- Backup created in /var/lib/rpmbackup/
- Package installs successfully
- Task status: "changed"

#### Step 5: Post-Validation

1. Service health check:
   ```yaml
   TASK [Verify nginx service is running]
   ok: [uat-rhel9-01]
   ```

2. Application endpoint check (if configured):
   ```yaml
   TASK [Verify application responding]
   ok: [uat-rhel9-01]
   ```

3. Version verification:
   ```yaml
   TASK [Verify package version]
   ok: [uat-rhel9-01] => {
       "version": "1.28.2-1.el9.ngx"
   }
   ```

**Expected Result:**
- Service is active and running
- Application responds to health checks
- Correct package version confirmed

#### Step 6: Report Generation

1. JSON results saved:
   ```yaml
   TASK [Save patching results to control node]
   changed: [localhost]
   ```

2. Report location displayed:
   ```
   Results saved to: patch_data/uat_uat-rhel9-01_9_2026-03-03T10-30-45.json
   ```

**Expected Result:**
- JSON file created with complete results
- Status: "completed"
- All packages marked as "installed"

### Expected Playbook Behavior

| Phase | Behavior |
|-------|----------|
| **Pre-Check** | All validations pass without stopping |
| **Execution** | Packages install successfully |
| **Validation** | Service checks pass |
| **Reporting** | Status: "completed" |
| **Completion** | Exit code: 0 |

### Expected Results

#### Console Output
```
PLAY [Patch RHEL Servers] **************************************************

TASK [Gathering Facts] ***************************************************
ok: [uat-rhel9-01]

TASK [Check sufficient disk space] ***************************************
ok: [uat-rhel9-01] => {
    "disk_usage": "35%"
}

TASK [Verify Satellite repository accessible] ****************************
ok: [uat-rhel9-01]

TASK [Install security updates] ******************************************
changed: [uat-rhel9-01]

TASK [Verify nginx service is running] ***********************************
ok: [uat-rhel9-01]

TASK [Save patching results] *********************************************
changed: [localhost]

PLAY RECAP ****************************************************************
uat-rhel9-01              : ok=15   changed=4    unreachable=0    failed=0    skipped=0
```

#### JSON Report Structure

```json
{
  "hostname": "uat-rhel9-01.example.com",
  "ip": "192.168.1.10",
  "environment": "uat",
  "rhel_version": "9",
  "kernel": "5.14.0-427.18.1.el9_4.x86_64",
  "duration": "5m 23s",
  "status": "completed",
  "patches": [
    {
      "name": "nginx",
      "current_version": "1.20.1-8.el9_2",
      "target_version": "1.28.2-1.el9.ngx",
      "architecture": "x86_64",
      "status": "installed",
      "backup_created": true,
      "backup_path": "/var/lib/rpmbackup/nginx-1.20.1-8.el9_2.x86_64.rpm",
      "timestamp": "2026-03-03T10:30:45Z"
    }
  ]
}
```

#### Verification Commands

Run these commands after execution to verify success:

```bash
# Check installed version
ansible uat-rhel9-01 -m shell -a "rpm -q nginx"

# Verify service status
ansible uat-rhel9-01 -m shell -a "systemctl is-active nginx"

# Check service enabled
ansible uat-rhel9-01 -m shell -a "systemctl is-enabled nginx"

# Verify backup exists
ansible uat-rhel9-01 -m shell -a "ls -lh /var/lib/rpmbackup/"
```

### Actual Results

*To be filled during test execution*

| Check | Pass/Fail | Notes |
|-------|-----------|-------|
| Pre-checks passed | | |
| Package installed | | |
| Service running | | |
| Version correct | | |
| Backup created | | |
| JSON report generated | | |

### Status

[ ] Pass
[ ] Fail
[ ] Blocked

---

## TC-RHEL-002: Pre-Check Failure - Insufficient Disk Space

**Type:** Failure Scenario
**Priority:** Critical
**Estimated Duration:** 15 minutes

### Description

Demonstrates the playbook's ability to detect and stop when insufficient disk space is available during pre-flight validation. This confirms the playbook prevents damage by failing **before** any installation attempts.

### Why This Matters

In production environments, attempting to install packages with insufficient disk space can:
- Leave system in inconsistent state
- Cause partial installations
- Require manual recovery
- Potentially crash services

The playbook must detect this condition **before** any changes are made.

### Failure Simulation Method

**Option 1: Fill Disk (Requires root access)**
```bash
# Create large file to consume disk space
dd if=/dev/zero of=/var/tmp/diskfiller bs=1M count=5000
# This creates ~5GB file, adjust based on disk size
```

**Option 2: Modify Playbook Threshold**
Temporarily modify the playbook to trigger failure at lower threshold:
```yaml
- name: Check sufficient disk space
  ansible.builtin.shell: df / | tail -1 | awk '{print $5}' | sed 's/%//'
  register: disk_usage
  failed_when: disk_usage.stdout|int > 10  # Changed from 90 to 10
```

**Option 3: Simulate Check Failure**
Mock the disk check task to return failure:
```yaml
- name: Check sufficient disk space (MOCKED)
  ansible.builtin.debug:
    msg: "Simulating disk space failure"
  failed_when: true
```

### Pre-Conditions

- [ ] Test host registered to Satellite
- [ ] Disk space check threshold modified OR disk filled
- [ ] VM snapshot created (for recovery)
- [ ] SSH connectivity available
- [ ] Playbook modified for simulation (if using Option 2 or 3)

### Test Data

| Parameter | Value |
|-----------|-------|
| Test Host | uat-rhel9-01.example.com |
| Failure Point | Disk space pre-check |
| Expected Threshold | >90% usage (or simulated) |
| Current Disk Usage | ~95% (or simulated failure) |

### Test Steps

#### Step 1: Verify Initial State

1. Check current disk usage:
   ```bash
   ansible uat-rhel9-01 -m shell -a "df -h /"
   ```

**Expected Result:**
- Disk usage above threshold (if actually filled)
- OR playbook configured for simulation

#### Step 2: Execute Playbook

1. Run the patching playbook:
   ```bash
   ansible-playbook -i inventory master_patch.yaml --limit uat-rhel9-01
   ```

**Expected Result:**
- Playbook starts execution
- Reaches disk space check task

#### Step 3: Observe Failure

Watch for the disk space check task:

```yaml
TASK [Check sufficient disk space] ***************************************
fatal: [uat-rhel9-01]: FAILED! => {
    "msg": "Insufficient disk space: 95% used. Maximum 90% allowed."
}
```

**Expected Behavior:**
1. Task fails with clear error message
2. **Playbook immediately stops**
3. No subsequent tasks execute
4. No packages installed
5. No system changes made

#### Step 4: Verify No Changes Made

1. Check if any packages were installed:
   ```bash
   ansible uat-rhel9-01 -m shell -a "rpm -qa --last | head -20"
   ```

2. Check if backup directory was modified:
   ```bash
   ansible uat-rhel9-01 -m shell -a "ls -lt /var/lib/rpmbackup/ | head -5"
   ```

3. Verify no JSON report was created:
   ```bash
   ls -la patch_data/ | grep uat-rhel9-01
   ```

**Expected Result:**
- No new packages installed
- No backup modifications
- No JSON report created
- System state unchanged

#### Step 5: Verify Playbook Exit Code

```bash
echo $?
```

**Expected Result:**
- Exit code: Non-zero (typically 2 for Ansible failures)

### Expected Playbook Behavior

| Phase | Behavior |
|-------|----------|
| **Pre-Check** | Disk space check fails |
| **Stop Mechanism** | Task failure triggers immediate stop |
| **System Changes** | NONE - playbook stops before any changes |
| **Subsequent Tasks** | NOT executed |
| **Exit Code** | Non-zero (failure) |

### Expected Results

#### Console Output

```
PLAY [Patch RHEL Servers] **************************************************

TASK [Gathering Facts] ***************************************************
ok: [uat-rhel9-01]

TASK [Check sufficient disk space] ***************************************
fatal: [uat-rhel9-01]: FAILED! => {
    "changed": false,
    "cmd": "df / | tail -1 | awk '{print $5}' | sed 's/%//'",
    "delta": "0:00:00.123456",
    "end": "2026-03-03 10:25:30.123456",
    "failed": true,
    "msg": "Insufficient disk space: 95% used. Maximum 90% allowed.",
    "rc": 0,
    "start": "2026-03-03 10:25:30.000000",
    "stderr": "",
    "stderr_lines": [],
    "stdout": "95",
    "stdout_lines": ["95"]
}

PLAY RECAP ****************************************************************
uat-rhel9-01              : ok=1    changed=0    unreachable=0    failed=1    skipped=0
```

**Key Observations:**
- `failed=1` indicates task failure
- `changed=0` confirms no changes made
- Only 1 task completed (gathering facts)
- Clear error message explaining the issue

### Playbook Code Reference

This is the code that handles the failure:

```yaml
---
# Pre-check: Disk space validation
- name: Check sufficient disk space
  ansible.builtin.shell: df / | tail -1 | awk '{print $5}' | sed 's/%//'
  register: disk_usage
  changed_when: false
  failed_when:
    - disk_usage.stdout|int > 90
  notify:
    - Disk space insufficient

- name: Display disk usage warning
  ansible.builtin.debug:
    msg: "Disk space at {{ disk_usage.stdout }}% usage"
  when: disk_usage.stdout|int > 80

- name: Fail if insufficient space
  ansible.builtin.fail:
    msg: "Insufficient disk space: {{ disk_usage.stdout }}% used. Maximum 90% allowed."
  when: disk_usage.stdout|int > 90
```

### Safety Verification

After the test, verify that no damage was done:

```bash
# No packages installed in last 10 minutes
ansible uat-rhel9-01 -m shell -a "rpm -qa --last | grep '$(date +%H:%M)'"

# All services still running
ansible uat-rhel9-01 -m shell -a "systemctl list-units --state=running"

# No error messages in logs
ansible uat-rhel9-01 -m shell -a "journalctl -p err -n 10 --no-pager"
```

### Actual Results

*To be filled during test execution*

| Check | Pass/Fail | Notes |
|-------|-----------|-------|
| Playbook stopped at pre-check | | |
| Clear error message displayed | | |
| No packages installed | | |
| No system changes made | | |
| Exit code indicates failure | | |
| System still stable | | |

### Status

[ ] Pass
[ ] Fail
[ ] Blocked

### Recovery (Cleanup)

If disk was actually filled:
```bash
# Remove the filler file
ansible uat-rhel9-01 -m shell -a "rm -f /var/tmp/diskfiller"

# Verify disk space recovered
ansible uat-rhel9-01 -m shell -a "df -h /"
```

If playbook was modified:
- Revert threshold change to original value (90%)
- Commit reversion to version control

---

## TC-RHEL-003: Package Installation Failure - Dependency Conflict

**Type:** Failure Scenario
**Priority:** Critical
**Estimated Duration:** 20 minutes

### Description

Demonstrates the playbook's block/rescue structure when a package installation fails due to dependency conflicts. This confirms that installation errors are caught gracefully, reported clearly, and stop further execution to prevent cascading issues.

### Why This Matters

In real-world patching scenarios, dependency conflicts can occur due to:
- Incompatible package versions
- Missing dependencies
- Repository synchronization issues
- Content View promotion errors

The playbook must:
1. Detect the installation failure
2. Log the specific error
3. Stop immediately (no further hosts patched)
4. Preserve system state for rollback

### Failure Simulation Method

**Option 1: Use Conflicting Package**
Create a scenario with a known dependency conflict:
```bash
# Install older version that conflicts
dnf install nginx-1.18.0-1.el8.ngx --skip-broken

# Then try to upgrade to incompatible version
```

**Option 2: Simulate DNF Failure**
Mock the installation task to simulate DNF failure:
```yaml
- name: Install security updates (MOCKED FAILURE)
  ansible.builtin.shell: "dnf install nonexistent-package-1.0.0 -y"
  register: install_result
  failed_when: install_result.rc != 0
```

**Option 3: Break Repository Temporarily**
Temporarily make repository unavailable during installation:
```bash
# On target host, temporarily block repository
iptables -A OUTPUT -p tcp --dport 443 -j REJECT
```

### Pre-Conditions

- [ ] Test host registered to Satellite
- [ ] Conflicting package prepared OR simulation configured
- [ ] VM snapshot created (for recovery)
- [ ] Pre-checks expected to pass
- [ ] Installation expected to fail

### Test Data

| Parameter | Value |
|-----------|-------|
| Test Host | uat-rhel9-01.example.com |
| Failure Point | Package installation task |
| Failure Type | Dependency conflict / DNF failure |
| Expected Behavior | Rescue block activates, execution stops |

### Test Steps

#### Step 1: Verify Pre-Checks Pass

1. Run the playbook:
   ```bash
   ansible-playbook -i inventory master_patch.yaml --limit uat-rhel9-01 -vv
   ```

2. Watch pre-check tasks complete successfully:
   ```yaml
   TASK [Check sufficient disk space]
   ok: [uat-rhel9-01]

   TASK [Verify Satellite repository accessible]
   ok: [uat-rhel9-01]

   TASK [Backup current RPM]
   changed: [uat-rhel9-01]
   ```

**Expected Result:**
- All pre-checks pass
- Backup created successfully
- Playbook proceeds to installation

#### Step 2: Installation Attempt

1. Playbook attempts package installation:
   ```yaml
   TASK [Install security updates]
   ```

2. Watch for failure:
   ```
   fatal: [uat-rhel9-01]: FAILED! => {
       "msg": "Dependency resolution failed:\n  - package nginx-1.28.2 requires libssl >= 1.1.1\n  - cannot install both nginx-1.20.1 and nginx-1.28.2"
   }
   ```

**Expected Result:**
- Installation task fails
- Error message shows dependency details

#### Step 3: Rescue Block Activation

1. Watch rescue block execute:
   ```yaml
   TASK [Handle installation failure] ************************************
   ok: [uat-rhel9-01] => {
       "msg": "Installation failed on uat-rhel9-01.example.com"
   }

   TASK [Mark host as failed] ********************************************
   ok: [uat-rhel9-01]

   TASK [Stop further execution] ****************************************
   ```

**Expected Behavior:**
1. Rescue block activates automatically
2. Failure is logged with clear message
3. Host marked as failed
4. Playbook execution stops
5. No subsequent tasks run

#### Step 4: Verify Execution Stop

1. Check that post-validation tasks did NOT run:
   ```bash
   # In playbook output, verify these tasks are MISSING:
   # - Verify nginx service is running
   # - Save patching results
   ```

2. If multiple hosts in batch, verify others not patched:
   ```bash
   # Check other hosts in batch
   ansible rhel_batch1 -m shell -a "rpm -q nginx-version"
   ```

**Expected Result:**
- Post-validation tasks skipped
- Other hosts in batch NOT patched
- Playbook stopped immediately after rescue

#### Step 5: Check Failure Report

1. Look for partial results file:
   ```bash
   ls -la patch_data/ | grep uat-rhel9-01
   ```

2. If report was created, check content:
   ```bash
   cat patch_data/uat_uat-rhel9-01_9_2026-03-03T*.json | jq .
   ```

**Expected Result:**
- Report shows status: "failed" or "partial_failure"
- Error details included
- Timestamp recorded

### Expected Playbook Behavior

| Phase | Behavior |
|-------|----------|
| **Pre-Check** | All validations pass |
| **Backup** | Backup created successfully |
| **Installation** | Fails with dependency error |
| **Rescue Block** | Activates automatically |
| **Error Logging** | Clear error message recorded |
| **Stop Mechanism** | `meta: end_play` halts execution |
| **Subsequent Tasks** | NOT executed |
| **Other Hosts** | NOT patched |

### Expected Results

#### Console Output

```
PLAY [Patch RHEL Servers] **************************************************

TASK [Gathering Facts] ***************************************************
ok: [uat-rhel9-01]

TASK [Check sufficient disk space] ***************************************
ok: [uat-rhel9-01] => {
    "disk_usage": "35%"
}

TASK [Verify Satellite repository accessible] ****************************
ok: [uat-rhel9-01]

TASK [Backup current RPM] *************************************************
changed: [uat-rhel9-01] => {
    "backup_path": "/var/lib/rpmbackup/nginx-1.20.1-8.el9_2.x86_64.rpm"
}

TASK [Install security updates] ******************************************
fatal: [uat-rhel9-01]: FAILED! => {
    "changed": false,
    "cmd": "dnf install nginx-1.28.2-1.el9.ngx -y",
    "msg": "Dependency Resolution Error:\n  Problem: package nginx-1.28.2-1.el9.ngx.x86_64 requires libssl.so.1.1(OPENSSL_1_1_1)(64bit)\n  - cannot install both libssl-1.0.2 and libssl-1.1.1\n",
    "rc": 1
}

TASK [Handle installation failure] ***************************************
ok: [uat-rhel9-01] => {
    "msg": "Installation failed on uat-rhel9-01.example.com"
}

TASK [Mark host as failed] ************************************************
ok: [uat-rhel9-01] => {
    "patch_status": "failed",
    "failed_task": "Install security updates",
    "error_message": "Dependency Resolution Error"
}

TASK [Stop further execution] *********************************************
fatal: [uat-rhel9-01]: FAILED! => {
    "msg": "Stopping execution due to installation failure"
}

NO MORE HOSTS LEFT *********************************************************

PLAY RECAP ****************************************************************
uat-rhel9-01              : ok=6    changed=1    unreachable=0    failed=2    skipped=0
```

**Key Observations:**
- Pre-checks passed (ok=6)
- Installation failed (failed=2)
- Rescue block executed
- Execution stopped with clear message

### Playbook Code Reference

```yaml
---
# Main execution block with rescue
- block:
    - name: Install security updates
      ansible.builtin.dnf:
        name: "{{ item.name }}-{{ item.target_version }}.{{ item.arch }}"
        state: present
        disable_gpg_check: true
      register: install_result
      loop: "{{ packages_to_install }}"

    - name: Verify installation
      ansible.builtin.shell: rpm -q {{ item.name }}-{{ item.target_version }}
      register: verify_result
      loop: "{{ packages_to_install }}"

  rescue:
    - name: Log installation failure
      ansible.builtin.debug:
        msg: "Installation failed on {{ inventory_hostname }}"

    - name: Capture error details
      ansible.builtin.set_fact:
        patch_failure_details:
          host: "{{ inventory_hostname }}"
          failed_task: "Install security updates"
          error_message: "{{ install_result.msg | default('Unknown error') }}"
          timestamp: "{{ ansible_date_time.iso8601 }}"

    - name: Mark host as failed
      ansible.builtin.set_fact:
        patch_status: "failed"

    - name: Stop execution for all hosts
      meta: end_play

  always:
    - name: Always collect installation logs
      ansible.builtin.fetch:
        src: /var/log/dnf.log
        dest: logs/{{ inventory_hostname }}_dnf_failure.log
        flat: true

    - name: Always save failure report
      ansible.builtin.copy:
        content: "{{ patch_failure_details | to_nice_json }}"
        dest: "{{ patch_data_dir }}/{{ inventory_hostname }}_failure.json"
      delegate_to: localhost
```

### Safety Verification

Verify the system is still in a good state:

```bash
# Original package still installed
ansible uat-rhel9-01 -m shell -a "rpm -q nginx"
# Expected: nginx-1.20.1-8.el9_2

# No broken dependencies
ansible uat-rhel9-01 -m shell -a "dnf verify dependencies"

# Service still running (wasn't affected)
ansible uat-rhel9-01 -m shell -a "systemctl is-active nginx"

# Backup intact for potential rollback
ansible uat-rhel9-01 -m shell -a "ls -lh /var/lib/rpmbackup/"
```

### Actual Results

*To be filled during test execution*

| Check | Pass/Fail | Notes |
|-------|-----------|-------|
| Pre-checks passed | | |
| Backup created | | |
| Installation failed as expected | | |
| Rescue block activated | | |
| Error logged clearly | | |
| Execution stopped | | |
| Post-validation tasks skipped | | |
| System state intact | | |
| Backup preserved | | |

### Status

[ ] Pass
[ ] Fail
[ ] Blocked

### Recovery (Cleanup)

If using mock failure:
- Remove mock code from playbook
- Commit cleanup to version control

If using actual conflict:
```bash
# Resolve dependency manually
ansible uat-rhel9-01 -m shell -a "dnf resolve"

# Or rollback from backup
ansible uat-rhel9-01 -m shell -a "rpm -Uvh --force /var/lib/rpmbackup/nginx-*.rpm"
```

---

## TC-RHEL-004: Post-Patch Validation Failure - Service Not Running

**Type:** Failure Scenario
**Priority:** Critical
**Estimated Duration:** 20 minutes

### Description

Demonstrates the playbook's ability to detect when a patch installs successfully but breaks a service or application. This confirms that post-patch validation catches issues AFTER installation but BEFORE marking the system as successfully patched.

### Why This Matters

Some patches can:
- Break service configurations
- Change file permissions
- Introduce incompatible changes
- Cause services to fail to start

The playbook must detect these issues immediately and:
1. NOT mark the system as successfully patched
2. Stop further patching
3. Preserve backups for rollback
4. Alert operators to the problem

### Failure Simulation Method

**Option 1: Stop Service After Installation**
Create a task that stops the service immediately after patch installation:
```yaml
- name: Install package
  ansible.builtin.dnf:
    name: nginx
    state: latest

- name: Simulate service failure (MOCK)
  ansible.builtin.systemd:
    name: nginx
    state: stopped
  when: simulate_failure | bool
```

**Option 2: Break Configuration File**
Modify service configuration to cause failure:
```bash
# After patch, break nginx config
sed -i 's/listen 80;/listen 81;/g' /etc/nginx/nginx.conf
# This will cause nginx to fail on restart
```

**Option 3: Validate Non-Existent Service**
Configure playbook to check a service that doesn't exist:
```yaml
- name: Verify service running (MOCKED)
  ansible.builtin.systemd:
    name: nonexistent-service
    state: started
```

### Pre-Conditions

- [ ] Test host registered to Satellite
- [ ] Service to be patched is running
- [ ] Failure simulation configured
- [ ] VM snapshot created (for recovery)
- [ ] Playbook includes post-validation checks

### Test Data

| Parameter | Value |
|-----------|-------|
| Test Host | uat-rhel9-01.example.com |
| Failure Point | Post-patch service validation |
| Failure Type | Service fails to start/stops after patch |
| Expected Behavior | Validation fails, execution stops, backup preserved |

### Test Steps

#### Step 1: Verify Pre-Patch State

1. Check service is running before patch:
   ```bash
   ansible uat-rhel9-01 -m shell -a "systemctl is-active nginx"
   # Expected: active
   ```

2. Check service enabled:
   ```bash
   ansible uat-rhel9-01 -m shell -a "systemctl is-enabled nginx"
   # Expected: enabled
   ```

**Expected Result:**
- Service is running and enabled
- Application responding normally

#### Step 2: Execute Playbook

1. Run the patching playbook:
   ```bash
   ansible-playbook -i inventory master_patch.yaml --limit uat-rhel9-01 -vv
   ```

2. Watch execution proceed through pre-checks:
   ```yaml
   TASK [Check sufficient disk space]
   ok: [uat-rhel9-01]

   TASK [Verify Satellite repository accessible]
   ok: [uat-rhel9-01]
   ```

**Expected Result:**
- All pre-checks pass
- Playbook proceeds to installation

#### Step 3: Package Installation

1. Watch package install successfully:
   ```yaml
   TASK [Backup current RPM]
   changed: [uat-rhel9-01]

   TASK [Install security updates]
   changed: [uat-rhel9-01] => {
       "results": [
           {
               "package": "nginx-1.28.2-1.el9.ngx.x86_64",
               "result": "success"
           }
       ]
   }
   ```

**Expected Result:**
- Backup created
- Package installs successfully
- No errors during installation

#### Step 4: Service Validation Failure

1. Post-patch validation runs:
   ```yaml
   TASK [Verify nginx service is running]
   fatal: [uat-rhel9-01]: FAILED! => {
       "changed": false,
       "msg": "Service nginx is not running",
       "status": {
           "ActiveState": "failed",
           "LoadState": "loaded",
           "SubState": "failed"
       }
   }
   ```

**Expected Behavior:**
1. Validation task detects service failure
2. Task fails with clear message
3. Playbook marks as validation failure
4. Execution stops (no further hosts patched)

#### Step 5: Verify Playbook Response

1. Watch for failure handling:
   ```yaml
   TASK [Mark validation failure] *****************************************
   ok: [uat-rhel9-01] => {
       "patch_status": "validation_failed",
       "service": "nginx",
       "expected_state": "active",
       "actual_state": "failed"
   }

   TASK [Stop further execution] ******************************************
   fatal: [uat-rhel9-01]: FAILED! => {
       "msg": "Stopping execution: Post-patch validation failed"
   }
   ```

**Expected Result:**
- Validation failure clearly marked
- Execution stops immediately
- No other hosts patched
- Backup preserved for rollback

#### Step 6: Verify Rollback Readiness

1. Check backup is intact:
   ```bash
   ansible uat-rhel9-01 -m shell -a "ls -lh /var/lib/rpmbackup/"
   ```

2. Check rollback report generated:
   ```bash
   cat patch_data/uat_rhel9-01_validation_failure.json | jq .
   ```

**Expected Result:**
- Backup RPM present and accessible
- Failure report includes:
  - Service that failed
  - Expected vs actual state
  - Timestamp
  - Rollback instructions

### Expected Playbook Behavior

| Phase | Behavior |
|-------|----------|
| **Pre-Check** | All validations pass |
| **Installation** | Package installs successfully |
| **Post-Validation** | Service check fails |
| **Failure Marking** | Status: "validation_failed" |
| **Stop Mechanism** | Execution halts immediately |
| **Backup Status** | Preserved for rollback |
| **Other Hosts** | NOT patched |

### Expected Results

#### Console Output

```
PLAY [Patch RHEL Servers] **************************************************

TASK [Gathering Facts] ***************************************************
ok: [uat-rhel9-01]

TASK [Check sufficient disk space] ***************************************
ok: [uat-rhel9-01]

TASK [Verify Satellite repository accessible] ****************************
ok: [uat-rhel9-01]

TASK [Backup current RPM] *************************************************
changed: [uat-rhel9-01] => {
    "backup_path": "/var/lib/rpmbackup/nginx-1.20.1-8.el9_2.x86_64.rpm"
}

TASK [Install security updates] ******************************************
changed: [uat-rhel9-01] => {
    "results": ["Successfully installed nginx-1.28.2-1.el9.ngx.x86_64"]
}

TASK [Verify nginx service is running] ***********************************
fatal: [uat-rhel9-01]: FAILED! => {
    "changed": false,
    "msg": "Service validation failed",
    "service": "nginx",
    "expected": "active",
    "actual": "failed",
    "status": {
        "ActiveState": "failed",
        "SubState": "failed"
    }
}

TASK [Mark validation failure] *******************************************
ok: [uat-rhel9-01] => {
    "patch_status": "validation_failed",
    "service_name": "nginx",
    "failure_reason": "Service failed to start after patch installation",
    "backup_available": true,
    "backup_path": "/var/lib/rpmbackup/nginx-1.20.1-8.el9_2.x86_64.rpm"
}

TASK [Generate validation failure report] ********************************
changed: [localhost] => {
    "report_path": "patch_data/uat_rhel9-01_validation_failure_2026-03-03T10-45-30.json"
}

TASK [Stop further execution] *********************************************
fatal: [uat-rhel9-01]: FAILED! => {
    "msg": "Stopping execution due to post-patch validation failure"
}

PLAY RECAP ****************************************************************
uat-rhel9-01              : ok=8    changed=3    unreachable=0    failed=2    skipped=0
```

**Key Observations:**
- Installation succeeded (changed=3)
- Validation failed (failed=2)
- Backup explicitly confirmed
- Clear failure reason documented
- Execution stopped

### Playbook Code Reference

```yaml
---
# Post-patch validation section
- name: Verify service is running
  ansible.builtin.systemd:
    name: "{{ service_name }}"
    state: started
  register: service_status
  failed_when: service_status.status.ActiveState != "active"
  ignore_errors: true  # Don't fail yet, we need to mark it properly

- name: Handle validation failure
  block:
    - name: Check if service failed
      ansible.builtin.fail:
        msg: "Service validation failed"
      when: service_status.status.ActiveState != "active"

    - name: Mark as validation failure
      ansible.builtin.set_fact:
        patch_status: "validation_failed"
        service_name: "{{ service_name }}"
        failure_details:
          service: "{{ service_name }}"
          expected_state: "active"
          actual_state: "{{ service_status.status.ActiveState }}"
          backup_available: true
          backup_path: "{{ rpm_backup_dir }}/{{ backup_file }}"

    - name: Generate validation failure report
      ansible.builtin.copy:
        content: "{{ failure_details | to_nice_json }}"
        dest: "{{ patch_data_dir }}/{{ inventory_hostname }}_validation_failure.json"
      delegate_to: localhost

    - name: Display rollback instructions
      ansible.builtin.debug:
        msg: |
          VALIDATION FAILED - Service {{ service_name }} is not running
          Rollback using: rpm -Uvh --force {{ backup_path }}
          Or revert VM snapshot

    - name: Stop execution
      meta: end_play

  when: service_status.status.ActiveState != "active"
```

### Validation Failure Report Structure

```json
{
  "hostname": "uat-rhel9-01.example.com",
  "patch_status": "validation_failed",
  "timestamp": "2026-03-03T10:45:30Z",
  "service_validation": {
    "service_name": "nginx",
    "expected_state": "active",
    "actual_state": "failed",
    "failure_reason": "Service failed to start after patch installation"
  },
  "patch_info": {
    "package_installed": "nginx-1.28.2-1.el9.ngx.x86_64",
    "previous_version": "nginx-1.20.1-8.el9_2.x86_64",
    "installation_success": true
  },
  "rollback": {
    "backup_available": true,
    "backup_path": "/var/lib/rpmbackup/nginx-1.20.1-8.el9_2.x86_64.rpm",
    "rollback_command": "rpm -Uvh --force /var/lib/rpmbackup/nginx-1.20.1-8.el9_2.x86_64.rpm",
    "alternative_rollback": "VM snapshot revert"
  },
  "logs": {
    "service_status": "systemctl status nginx",
    "journal_log": "journalctl -u nginx -n 50"
  }
}
```

### Safety Verification

Verify the system is recoverable:

```bash
# Backup is intact
ansible uat-rhel9-01 -m shell -a "ls -lh /var/lib/rpmbackup/nginx-*.rpm"

# Can rollback from backup
ansible uat-rhel9-01 -m shell -a "rpm -Uvh --force /var/lib/rpmbackup/nginx-1.20.1-8.el9_2.x86_64.rpm"

# Verify service starts after rollback
ansible uat-rhel9-01 -m shell -a "systemctl start nginx && systemctl is-active nginx"
```

### Actual Results

*To be filled during test execution*

| Check | Pass/Fail | Notes |
|-------|-----------|-------|
| Pre-checks passed | | |
| Package installed | | |
| Service validation failed | | |
| Failure clearly marked | | |
| Execution stopped | | |
| Backup preserved | | |
| Failure report generated | | |
| Rollback documented | | |
| System recoverable | | |

### Status

[ ] Pass
[ ] Fail
[ ] Blocked

### Recovery (Rollback)

Demonstrate rollback capability:

```bash
# Rollback package from backup
ansible uat-rhel9-01 -m shell -a "rpm -Uvh --force /var/lib/rpmbackup/nginx-1.20.1-8.el9_2.x86_64.rpm"

# Start service
ansible uat-rhel9-01 -m shell -a "systemctl start nginx"

# Verify service running
ansible uat-rhel9-01 -m shell -a "systemctl is-active nginx"

# Verify version
ansible uat-rhel9-01 -m shell -a "rpm -q nginx"
# Expected: nginx-1.20.1-8.el9_2
```

Or revert VM snapshot if available.

---

## 4. Playbook Failure Handling Features

### 4.1 Pre-Flight Validation Gates

The playbook implements multiple pre-checks to prevent issues before they start:

| Validation | Purpose | Failure Action |
|------------|---------|----------------|
| **Disk Space** | Ensure space for downloads & installation | Stop immediately |
| **Repository Access** | Verify Satellite reachable | Stop immediately |
| **Subscription Status** | Confirm host registered | Stop immediately |
| **Content View Binding** | Verify correct CV assigned | Stop immediately |
| **Service Pre-Check** | Baseline service status | Warn but continue |
| **Network Connectivity** | Ensure host reachable | Stop immediately |

### 4.2 Serial Execution & Blast Radius Containment

```yaml
# Playbook configuration
- hosts: rhel_servers
  serial: 1                      # One host at a time
  max_fail_percentage: 0         # Stop on ANY failure
```

**Benefits:**
- Only one server patched at a time
- Failure on one host doesn't affect others
- Allows investigation before proceeding
- Limits potential outage scope

### 4.3 Block/Rescue Structure

```yaml
- block:
    # Tasks that might fail
    - name: Install package
      ansible.builtin.dnf:
        name: "{{ package }}"
        state: present

  rescue:
    # What to do if block fails
    - name: Log error
      ansible.builtin.debug:
        msg: "Installation failed"

    - name: Stop execution
      meta: end_play

  always:
    # Cleanup that always happens
    - name: Collect logs
      ansible.builtin.fetch:
        src: /var/log/dnf.log
```

**Benefits:**
- Graceful error handling
- Cleanup tasks always run
- Clear error messaging
- Immediate stop capability

### 4.4 Comprehensive Error Reporting

Every failure generates detailed report including:

- Hostname and IP
- Timestamp
- Failed task
- Error message
- Package being installed
- Service affected
- Backup location
- Rollback instructions

### 4.5 Rollback Capabilities

Three rollback methods supported:

#### Method 1: Package Downgrade
```bash
# Using DNF history
dnf history undo <transaction-id>

# Using backup RPM
rpm -Uvh --force /var/lib/rpmbackup/package-version.rpm
```

#### Method 2: Satellite CV Reversion
```bash
# Reassign host to previous CV
hammer host update --id <host-id> --content-view-id <previous-cv-id>

# Sync to previous state
dnf distro-sync
```

#### Method 3: VM Snapshot Revert
```bash
# Via hypervisor
virsh snapshot-revert <domain> <snapshot-name>

# Or via hypervisor API
```

---

## 5. Pre-Test Checklist

### 5.1 Infrastructure Preparation

- [ ] Satellite server is accessible
- [ ] Lifecycle environments configured (Library/UAT/PROD/DR)
- [ ] Content Views created and published
- [ ] Test hosts registered to Satellite
- [ ] Ansible/AAP inventory configured
- [ ] SSH connectivity verified
- [ ] Service accounts with appropriate permissions

### 5.2 Test Host Preparation

- [ ] VM snapshots created (for rollback testing)
- [ ] Baseline package versions documented
- [ ] Service status documented
- [ ] Disk space verified
- [ ] Application health confirmed

### 5.3 Playbook Preparation

- [ ] Playbook reviewed and validated
- [ ] Failure handling logic verified
- [ ] Backup directory configured
- [ ] Reporting directory configured
- [ ] Logging configured

### 5.4 Failure Scenarios Preparation

- [ ] Disk space failure simulation configured
- [ ] Dependency conflict prepared OR mock configured
- [ ] Service failure simulation configured
- [ ] Rollback procedures tested
- [ ] Recovery commands documented

### 5.5 Monitoring & Evidence Collection

- [ ] Terminal session recording configured
- [ ] Screenshot tool ready
- [ ] Log collection directory prepared
- [ ] Results spreadsheet prepared
- [ ] Communication channel for issues

---

## 6. Execution Guidelines

### 6.1 Running the Playbook

#### Basic Execution
```bash
# Run on single host
ansible-playbook -i inventory master_patch.yaml --limit uat-rhel9-01

# Run with verbose output
ansible-playbook -i inventory master_patch.yaml -v

# Run with extra verbose (for debugging)
ansible-playbook -i inventory master_patch.yaml -vvv
```

#### With Check Mode (Dry Run)
```bash
# Check mode - no changes made
ansible-playbook -i inventory master_patch.yaml --check
```

#### With Tags
```bash
# Run only pre-checks
ansible-playbook -i inventory master_patch.yaml --tags pre-check

# Run only installation
ansible-playbook -i inventory master_patch.yaml --tags install

# Run only validation
ansible-playbook -i inventory master_patch.yaml --tags validate
```

### 6.2 Monitoring During Execution

#### What to Watch For

**Console Output:**
- Task status (ok/changed/failed/skipped)
- Error messages
- Warning messages
- Progress indicators

**Log Files:**
```bash
# Ansible log
tail -f /var/log/ansible.log

# DNF log on target
tail -f /var/log/dnf.log

# System journal
journalctl -f
```

**Service Status:**
```bash
# Watch service status
watch systemctl status nginx

# Check process
watch ps aux | grep nginx
```

### 6.3 Verification Commands

During execution, verify expected behavior:

```bash
# Check if playbook is still running
ps aux | grep ansible

# Check recent package installations
ansible target -m shell -a "rpm -qa --last | head -5"

# Check disk space
ansible target -m shell -a "df -h /"

# Check service status
ansible target -m shell -a "systemctl is-active nginx"

# Check if host still reachable
ansible target -m ping
```

### 6.4 Evidence Collection

#### Screenshots Required

1. **Pre-Execution State**
   - Package versions
   - Service status
   - Disk space

2. **Execution Progress**
   - Pre-check results
   - Installation progress
   - Any warnings or errors

3. **Post-Execution State**
   - Final package versions
   - Service status
   - Playbook summary

4. **Failure Scenarios**
   - Error message
   - Stop confirmation
   - Backup preserved

#### Log Collection

```bash
# Create logs directory
mkdir -p logs/test_run_$(date +%Y%m%d_%H%M%S)

# Collect Ansible output
ansible-playbook ... 2>&1 | tee logs/test_run_$(date +%Y%m%d_%H%M%S)/ansible_output.log

# Collect DNF logs
ansible all -m fetch -a "src=/var/log/dnf.log dest=logs/test_run_$(date +%Y%m%d_%H%M%S)/"

# Collect system journal
ansible all -m shell -a "journalctl -n 1000 --no-pager" > logs/test_run_$(date +%Y%m%d_%H%M%S)/journal.log

# Collect JSON reports
cp patch_data/*.json logs/test_run_$(date +%Y%m%d_%H%M%S)/
```

### 6.5 Troubleshooting During Execution

#### Playbook Hangs
```bash
# Check if task is waiting for input
# Look for "[prompt]" in output

# Check if service is waiting
# Verify no manual intervention required

# Kill playbook if needed
# Ctrl+C to stop
```

#### Connection Lost
```bash
# Verify network connectivity
ping target_host

# Check SSH
ssh target_host

# Verify Ansible can reach
ansible target -m ping
```

#### Task Fails Unexpectedly
```bash
# Run with verbose output
ansible-playbook ... -vvv

# Check target host logs
ssh target_host "journalctl -n 50"

# Run specific task manually
ansible target -m shell -a "<command>"
```

---

## 7. Post-Test Validation

### 7.1 Success Scenario Validation

After successful test execution (TC-RHEL-001):

```bash
# Verify package version
ansible uat-rhel9-01 -m shell -a "rpm -q nginx"
# Expected: nginx-1.28.2-1.el9.ngx

# Verify service running
ansible uat-rhel9-01 -m shell -a "systemctl is-active nginx"
# Expected: active

# Verify service enabled
ansible uat-rhel9-01 -m shell -a "systemctl is-enabled nginx"
# Expected: enabled

# Verify application responding
ansible uat-rhel9-01 -m uri -a "url=http://localhost/status_code=200"
# Expected: 200

# Verify backup created
ansible uat-rhel9-01 -m shell -a "ls -lh /var/lib/rpmbackup/"
# Expected: backup RPM present

# Verify JSON report
cat patch_data/uat_uat-rhel9-01_*.json | jq .
# Expected: status: "completed"
```

### 7.2 Failure Scenario Validation

After failure test execution (TC-RHEL-002/003/004):

```bash
# Verify playbook stopped
# Check that expected number of tasks executed
# No subsequent tasks should have run

# Verify error message was clear
# Check console output for descriptive error

# Verify no partial damage
ansible uat-rhel9-01 -m shell -a "rpm -qa --last | head -10"
# Expected: No unexpected installations

# Verify system still stable
ansible uat-rhel9-01 -m shell -a "systemctl list-units --state=running"
# Expected: All expected services running

# Verify backup preserved
ansible uat-rhel9-01 -m shell -a "ls -lh /var/lib/rpmbackup/"
# Expected: Backup intact

# Verify failure report generated
ls -la patch_data/*failure*.json
# Expected: Failure report exists
```

### 7.3 Rollback Verification

After rollback procedure:

```bash
# Verify package reverted
ansible uat-rhel9-01 -m shell -a "rpm -q nginx"
# Expected: Original version (e.g., nginx-1.20.1)

# Verify service running
ansible uat-rhel9-01 -m shell -a "systemctl is-active nginx"
# Expected: active

# Verify no errors in logs
ansible uat-rhel9-01 -m shell -a "journalctl -p err -n 10 --no-pager"
# Expected: No new errors

# Verify system stable
ansible uat-rhel9-01 -m shell -a "uptime"
# Expected: Normal uptime (not recently rebooted unexpectedly)
```

### 7.4 Sign-Off Requirements

Each test case requires sign-off from:

| Role | Responsibility |
|------|---------------|
| **Test Executor** | Performed test, documented results |
| **Technical Reviewer** | Verified failure handling worked correctly |
| **Client Representative** | Confirms POC addresses requirements |

**Sign-off Template:**
```
Test Case: TC-RHEL-XXX
Execution Date: ___________
Executor: _________________

Results:
[ ] All expected behaviors observed
[ ] Failure handling demonstrated
[ ] Rollback capability verified
[ ] Documentation complete

Technical Review: _________________ Date: _________

Client Approval: _________________ Date: _________
```

---

## 8. Appendices

### Appendix A: Sample Playbook Snippets

#### Pre-Check: Disk Space Validation
```yaml
- name: Check sufficient disk space
  block:
    - name: Get disk usage
      ansible.builtin.shell: df / | tail -1 | awk '{print $5}' | sed 's/%//'
      register: disk_usage
      changed_when: false

    - name: Display disk usage
      ansible.builtin.debug:
        msg: "Disk usage: {{ disk_usage.stdout }}%"

    - name: Fail if insufficient space
      ansible.builtin.fail:
        msg: "Insufficient disk space: {{ disk_usage.stdout }}% used. Minimum 10% required."
      when: disk_usage.stdout|int > 90

  rescue:
    - name: Log disk space failure
      ansible.builtin.debug:
        msg: "Pre-check failed: Insufficient disk space"

    - name: Stop execution
      meta: end_play
```

#### Installation with Rescue
```yaml
- name: Install packages with error handling
  block:
    - name: Backup current package
      ansible.builtin.shell:
        cmd: find /var/lib/rpm -name "{{ item.name }}-*.rpm" -exec cp {} /var/lib/rpmbackup/ \;
      loop: "{{ packages_to_install }}"

    - name: Install package
      ansible.builtin.dnf:
        name: "{{ item.name }}-{{ item.version }}.{{ item.arch }}"
        state: present
        disable_gpg_check: true
      register: install_result
      loop: "{{ packages_to_install }}"

    - name: Verify installation
      ansible.builtin.shell: rpm -q {{ item.name }}-{{ item.version }}
      register: verify_result
      loop: "{{ packages_to_install }}"
      failed_when: verify_result.rc != 0

  rescue:
    - name: Log installation failure
      ansible.builtin.debug:
        msg: "Installation failed: {{ install_result.msg }}"

    - name: Mark host as failed
      ansible.builtin.set_fact:
        patch_status: "installation_failed"
        error_details: "{{ install_result.msg }}"

    - name: Stop execution
      meta: end_play
```

#### Post-Validation
```yaml
- name: Post-patch validation
  block:
    - name: Verify service running
      ansible.builtin.systemd:
        name: "{{ service_name }}"
        state: started
      register: service_status

    - name: Check service active state
      ansible.builtin.fail:
        msg: "Service {{ service_name }} is not running"
      when: service_status.status.ActiveState != "active"

    - name: Verify application endpoint
      ansible.builtin.uri:
        url: "http://localhost:8080/health"
        status_code: 200
      register: app_check

    - name: Mark validation successful
      ansible.builtin.set_fact:
        patch_status: "completed"
        validation_passed: true

  rescue:
    - name: Log validation failure
      ansible.builtin.debug:
        msg: "Post-patch validation failed"

    - name: Mark validation failed
      ansible.builtin.set_fact:
        patch_status: "validation_failed"
        service_name: "{{ service_name }}"
        service_state: "{{ service_status.status.ActiveState }}"

    - name: Display rollback instructions
      ansible.builtin.debug:
        msg: |
          VALIDATION FAILED
          Service: {{ service_name }}
          State: {{ service_status.status.ActiveState }}
          Rollback: rpm -Uvh --force /var/lib/rpmbackup/{{ item.name }}-*.rpm

    - name: Stop execution
      meta: end_play
```

### Appendix B: Expected Error Messages

| Error Type | Expected Message | Action Required |
|------------|------------------|-----------------|
| **Disk Space** | "Insufficient disk space: 95% used. Maximum 90% allowed." | Free disk space, retry |
| **Repository** | "Cannot access Satellite repository. Check network connectivity." | Verify network, check Satellite status |
| **Subscription** | "Host is not registered to Satellite." | Register host with subscription-manager |
| **Content View** | "Host not bound to correct Content View." | Assign correct Content View |
| **Dependency** | "Dependency resolution failed: package X requires libY >= version" | Resolve dependency, update Content View |
| **Service** | "Post-patch validation failed: Service nginx is not running" | Rollback package, investigate service issue |

### Appendix C: Satellite Commands for Validation

#### Check Host Registration
```bash
subscription-manager status
# Expected: "Subscribed"
```

#### Check Content View Binding
```bash
# On host
cat /etc/yum.repos.d/redhat.repo | grep content_view

# Via Satellite API/CLI
hammer host info --name uat-rhel9-01.example.com
```

#### Check Available Updates
```bash
# From host
dnf updateinfo list available

# Via Satellite
hammer host errata list --host uat-rhel9-01.example.com
```

#### View Content View History
```bash
hammer content-view version list --content-view "CV_RHEL9_POC"
```

#### Check Lifecycle Environment
```bash
hammer lifecycle-environment info --name "UAT"
```

### Appendix D: Verification Commands

#### Package Version Verification
```bash
# Check specific package
rpm -q nginx

# Check all patches applied in last hour
rpm -qa --last | head -20

# Check package details
rpm -qi nginx
```

#### Service Status Verification
```bash
# Check service status
systemctl status nginx

# Check if service is active
systemctl is-active nginx

# Check if service is enabled
systemctl is-enabled nginx

# Check service logs
journalctl -u nginx -n 50 --no-pager
```

#### System Health Verification
```bash
# Check system load
uptime

# Check disk space
df -h

# Check memory
free -h

# Check for errors
journalctl -p err -n 10 --no-pager

# Check network connectivity
ping -c 3 satellite.example.com
```

### Appendix E: Troubleshooting Guide

#### Issue: Playbook Stops at Pre-Check

**Symptom:** Playbook fails during pre-check phase

**Possible Causes:**
1. Disk space insufficient
2. Repository unreachable
3. Subscription expired
4. Wrong Content View assigned

**Resolution:**
```bash
# Check disk space
df -h /

# Check repository
dnf repolist

# Check subscription
subscription-manager status

# Check Content View
# Via Satellite web UI or hammer CLI
```

#### Issue: Package Installation Fails

**Symptom:** Installation task fails with dependency error

**Possible Causes:**
1. Dependency conflict
2. Package not in Content View
3. Network issue during download
4. Corrupted package

**Resolution:**
```bash
# Check dependency
dnf deplist package-name

# Check if package in repo
dnf info package-name

# Clear DNF cache
dnf clean all

# Sync Satellite repository
# Via Satellite web UI
```

#### Issue: Service Won't Start After Patch

**Symptom:** Package installs but service fails to start

**Possible Causes:**
1. Configuration file changed/overwritten
2. New dependencies required
3. Permission issues
4. Port conflicts

**Resolution:**
```bash
# Check service status
systemctl status nginx

# Check service logs
journalctl -u nginx -n 50

# Check configuration
nginx -t

# Rollback if needed
rpm -Uvh --force /var/lib/rpmbackup/package-old-version.rpm
```

#### Issue: Playbook Doesn't Stop on Failure

**Symptom:** Playbook continues after failure

**Possible Causes:**
1. `ignore_errors: true` set incorrectly
2. `max_fail_percentage` not set
3. `serial: 1` not set
4. `any_errors_fatal: true` missing

**Resolution:**
```yaml
# Check playbook configuration
- hosts: rhel_servers
  serial: 1
  max_fail_percentage: 0
  any_errors_fatal: true
```

---

## 9. Document Control

### Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0 | 2026-03-03 | Initial POC document | Ansible Automation Team |

### Review & Approval

| Role | Name | Signature | Date |
|------|------|-----------|------|
| **Author** | | | |
| **Technical Reviewer** | | | |
| **Security Reviewer** | | | |
| **Client Representative** | | | |

### Distribution

| Recipient | Role | Date Sent |
|-----------|------|-----------|
| | | |
| | | |

---

## 10. Next Steps

### 10.1 After POC Success

If POC demonstrates successful failure handling:

1. **Scale to Production**
   - Expand to more hosts
   - Add more validation checks
   - Integrate with monitoring systems

2. **Enhance Reporting**
   - Integrate with ServiceNow
   - Send email notifications
   - Dashboard in AAP

3. **Add Automation**
   - Automatic rollback triggers
   - Integration with load balancers
   - Automated snapshot management

### 10.2 After POC Issues

If POC reveals issues:

1. **Document Findings**
   - Record what worked
   - Document what failed
   - Identify gaps

2. **Iterate**
   - Fix identified issues
   - Add missing validations
   - Enhance error handling

3. **Re-test**
   - Run POC again
   - Verify fixes
   - Document improvements

### 10.3 Client Decision Points

After reviewing POC results, client should consider:

**Technical:**
- [ ] Does failure handling meet requirements?
- [ ] Is rollback capability sufficient?
- [ ] Are validation checks comprehensive?

**Operational:**
- [ ] Can team maintain playbooks?
- [ ] Is training required?
- [ ] Runbook procedures clear?

**Strategic:**
- [ ] Scale to all environments?
- [ ] Integrate with existing processes?
- [ ] Extend to Windows patching?

---

**End of Document**
