# RHEL Patching Automation
## Test Cases & Failure Handling POC

**Version:** 1.1
**Date:** March 3, 2026
**Prepared for:** Client Proof of Concept

---

## 1. Document Overview

### 1.1 Purpose

This document validates how the Ansible patching playbook handles failures when patching RHEL servers managed by Red Hat Satellite.

### 1.2 Architecture

| Component | Responsibility |
|-----------|---------------|
| Red Hat Satellite | Controls which patches are available and approved |
| Ansible Automation Platform | Orchestrates when and how patches are applied |

### 1.3 Test Environment

| Item | Details |
|------|---------|
| Operating System | RHEL 8 and 9 |
| Patch Management | Red Hat Satellite 6.x |
| Automation Tool | Ansible Automation Platform |
| Test Servers | UAT → DR → PROD lifecycle |

---

## 2. Test Case Summary

| Test Case ID | Scenario | Type | Expected Behavior |
|--------------|----------|------|-------------------|
| TC-001 | Normal patching flow | Success | All checks pass, package installs, service runs |
| TC-002 | Low disk space | Failure | Stops before installation, no changes made |
| TC-003 | Package dependency error | Failure | Catches error, logs details, stops execution |
| TC-004 | Service fails after patch | Failure | Detects service failure, preserves backup |

---

## 3. Test Cases

### TC-001: Successful Patching

| Field | Details |
|-------|---------|
| **Test Case ID** | TC-001 |
| **Title** | Successful End-to-End Patching |
| **Type** | Success Scenario |
| **Priority** | High |

#### Test Objective

Verify that patching completes successfully when all pre-conditions are met.

#### Pre-Conditions

| Requirement | Status |
|-------------|--------|
| Host registered to Satellite UAT environment | ☐ Verified |
| Sufficient disk space (≤90% used) | ☐ Verified |
| Satellite repository accessible | ☐ Verified |
| Service currently running | ☐ Verified |
| VM snapshot created | ☐ Verified |

#### Test Steps

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Run playbook on test host | Playbook starts successfully |
| 2 | Pre-check: Disk space | Passes with ≤90% used |
| 3 | Pre-check: Repository access | Satellite responds OK |
| 4 | Pre-check: Subscription status | Shows "Subscribed" |
| 5 | Create backup of current package | Backup saved to /var/lib/rpmbackup |
| 6 | Install package nginx-1.28.2 | Installation completes |
| 7 | Verify package version | Shows nginx-1.28.2 |
| 8 | Check service status | nginx is active |
| 9 | Generate report | JSON report created |

#### Expected Results

| Metric | Expected Value |
|--------|----------------|
| Playbook exit code | 0 |
| Packages installed | 1 |
| Packages failed | 0 |
| Service status | active |
| Backup created | Yes |
| Report status | completed |

#### Pass/Fail Criteria

| Criteria | Pass | Fail |
|----------|------|------|
| All pre-checks pass | ☐ | ☐ |
| Package installs correctly | ☐ | ☐ |
| Service is running after patch | ☐ | ☐ |
| Backup file created | ☐ | ☐ |
| Report generated | ☐ | ☐ |
| **Test Result** | **☐ PASS** | **☐ FAIL** |

#### Actual Results

| Field | Value |
|-------|-------|
| Packages installed | |
| Packages failed | |
| Service status | |
| Error messages | |
| Notes | |

#### Execution Log

```
[To be completed during test execution]

PLAY RECAP:
ok=____    changed=____    failed=____

Console output:
[Attach output log]
```

---

### TC-002: Disk Space Failure

| Field | Details |
|-------|---------|
| **Test Case ID** | TC-002 |
| **Title** | Pre-Check Failure - Insufficient Disk Space |
| **Type** | Failure Scenario |
| **Priority** | Critical |

#### Test Objective

Verify the playbook stops before installing packages when disk space is insufficient.

#### Pre-Conditions

| Requirement | Status |
|-------------|--------|
| Host registered to Satellite | ☐ Verified |
| Disk space filled to 95% OR threshold modified | ☐ Prepared |
| VM snapshot created | ☐ Verified |
| No other processes consuming space | ☐ Verified |

#### Test Steps

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Simulate low disk space | Disk at 95% capacity |
| 2 | Run playbook | Reaches disk space check |
| 3 | Disk space validation | Task fails with error |
| 4 | Playbook execution | Stops immediately |
| 5 | Verify system state | No packages installed |

#### Expected Results

| Metric | Expected Value |
|--------|----------------|
| Playbook stops at | Pre-check phase |
| Installation attempted | No |
| System changes | None |
| Exit code | Non-zero (failure) |
| Error message | Clear and specific |

#### Expected Error Message

```
TASK [Check sufficient disk space]
fatal: [host]: FAILED!
msg: "Insufficient disk space: 95% used. Maximum 90% allowed."
```

#### Pass/Fail Criteria

| Criteria | Pass | Fail |
|----------|------|------|
| Detected during pre-check | ☐ | ☐ |
| Installation NOT attempted | ☐ | ☐ |
| Clear error message | ☐ | ☐ |
| System unchanged | ☐ | ☐ |
| No partial installations | ☐ | ☐ |
| **Test Result** | **☐ PASS** | **☐ FAIL** |

#### What This Proves

| Capability | Demonstrated |
|------------|--------------|
| Pre-flight validation | ☐ Detects issues before execution |
| Automatic stop | ☐ Prevents damage |
| Clear messaging | ☐ Error explains problem |
| System protection | ☐ No partial state |

#### Actual Results

| Field | Value |
|-------|-------|
| Detected at phase | |
| Installation attempted | ☐ Yes ☐ No |
| Error message received | |
| System changed | ☐ Yes ☐ No |
| Notes | |

---

### TC-003: Package Installation Failure

| Field | Details |
|-------|---------|
| **Test Case ID** | TC-003 |
| **Title** | Installation Failure - Dependency Conflict |
| **Type** | Failure Scenario |
| **Priority** | Critical |

#### Test Objective

Validate that the block/rescue structure catches installation errors gracefully.

#### Pre-Conditions

| Requirement | Status |
|-------------|--------|
| Host registered to Satellite | ☐ Verified |
| Pre-checks will pass | ☐ Verified |
| Dependency conflict prepared | ☐ Prepared |
| Backup directory exists | ☐ Verified |
| VM snapshot created | ☐ Verified |

#### Test Steps

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Run playbook | Pre-checks begin |
| 2 | Complete pre-checks | All pass |
| 3 | Create backup | Backup saved successfully |
| 4 | Attempt package install | DNF fails with dependency error |
| 5 | Rescue block activates | Error handler executes |
| 6 | Log failure details | Error captured in log |
| 7 | Stop execution | Playbook halts |
| 8 | Verify other hosts | No other hosts patched |

#### Expected Results

| Metric | Expected Value |
|--------|----------------|
| Pre-checks | Pass |
| Installation | Fails |
| Rescue block | Activates |
| Other hosts patched | No |
| Backup preserved | Yes |
| Error logged | Yes |

#### Expected Error Message

```
TASK [Install security updates]
fatal: [host]: FAILED!
msg: "Dependency resolution failed:
      package nginx-1.28.2 requires libssl >= 1.1.1"

TASK [Handle installation failure]
ok: [host]
msg: "Installation failed"
```

#### Pass/Fail Criteria

| Criteria | Pass | Fail |
|----------|------|------|
| Pre-checks passed | ☐ | ☐ |
| Installation failed as expected | ☐ | ☐ |
| Rescue block activated | ☐ | ☐ |
| Error logged clearly | ☐ | ☐ |
| Execution stopped | ☐ | ☐ |
| Other hosts NOT patched | ☐ | ☐ |
| Backup preserved | ☐ | ☐ |
| **Test Result** | **☐ PASS** | **☐ FAIL** |

#### What This Proves

| Capability | Demonstrated |
|------------|--------------|
| Error detection | ☐ Catches installation failures |
| Graceful handling | ☐ Rescue block works |
| Clear logging | ☐ Error details captured |
| Blast radius control | ☐ Other hosts protected |
| Recovery path | ☐ Backup available |

#### Actual Results

| Field | Value |
|-------|-------|
| Pre-checks passed | ☐ Yes ☐ No |
| Installation failed | ☐ Yes ☐ No |
| Rescue activated | ☐ Yes ☐ No |
| Error logged | ☐ Yes ☐ No |
| Other hosts patched | ☐ Yes ☐ No |
| Backup intact | ☐ Yes ☐ No |
| Notes | |

---

### TC-004: Service Validation Failure

| Field | Details |
|-------|---------|
| **Test Case ID** | TC-004 |
| **Title** | Post-Patch Validation Failure - Service Not Running |
| **Type** | Failure Scenario |
| **Priority** | Critical |

#### Test Objective

Confirm post-patch validation detects when services fail after installation.

#### Pre-Conditions

| Requirement | Status |
|-------------|--------|
| Host registered to Satellite | ☐ Verified |
| Service running before patch | ☐ Verified |
| Service failure simulation ready | ☐ Prepared |
| VM snapshot created | ☐ Verified |

#### Test Steps

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Run playbook | Pre-checks begin |
| 2 | Complete pre-checks | All pass |
| 3 | Create backup | Backup saved |
| 4 | Install package | Installation succeeds |
| 5 | Verify package version | Shows new version |
| 6 | Check service status | Service is NOT running |
| 7 | Service validation fails | Task marked as failed |
| 8 | Execution stops | No other hosts patched |
| 9 | Verify backup preserved | Backup file exists |

#### Expected Results

| Metric | Expected Value |
|--------|----------------|
| Package installation | Succeeds |
| Service status after patch | Failed |
| Validation | Detects failure |
| Report status | validation_failed |
| Execution | Stops |
| Backup available | Yes |

#### Expected Error Message

```
TASK [Install security updates]
changed: [host]
results: "Successfully installed nginx-1.28.2"

TASK [Verify nginx service is running]
fatal: [host]: FAILED!
msg: "Service validation failed: nginx is not running"
status: "failed"

TASK [Mark validation failure]
ok: [host]
patch_status: "validation_failed"
```

#### Pass/Fail Criteria

| Criteria | Pass | Fail |
|----------|------|------|
| Package installed | ☐ | ☐ |
| Service failure detected | ☐ | ☐ |
| NOT marked as success | ☐ | ☐ |
| Execution stopped | ☐ | ☐ |
| Backup preserved | ☐ | ☐ |
| Rollback possible | ☐ | ☐ |
| **Test Result** | **☐ PASS** | **☐ FAIL** |

#### What This Proves

| Capability | Demonstrated |
|------------|--------------|
| Post-patch validation | ☐ Detects service failures |
| Accurate reporting | ☐ No false success |
| Recovery ready | ☐ Backup preserved |
| Clear instructions | ☐ Rollback documented |
| System protection | ☐ Issues caught |

#### Actual Results

| Field | Value |
|-------|-------|
| Package installed | ☐ Yes ☐ No |
| Service failed | ☐ Yes ☐ No |
| Validation caught failure | ☐ Yes ☐ No |
| Marked as failed (not success) | ☐ Yes ☐ No |
| Backup available | ☐ Yes ☐ No |
| Rollback tested | ☐ Yes ☐ No |
| Notes | |

---

## 4. Rollback Procedures

### 4.1 Rollback Methods Comparison

| Method | When to Use | Steps | Time to Recover |
|--------|-------------|-------|-----------------|
| Package Downgrade | Single package issue | Reinstall from backup | 2-5 minutes |
| Satellite CV Revert | Content View issue | Reassign + sync | 5-10 minutes |
| VM Snapshot | Complete system failure | Revert snapshot | 10-15 minutes |

### 4.2 Package Downgrade Procedure

| Step | Command | Expected Result |
|------|---------|-----------------|
| 1 | Connect to host | SSH session established |
| 2 | `rpm -Uvh --force /var/lib/rpmbackup/nginx-1.20.1-*.rpm` | Package downgraded |
| 3 | `systemctl start nginx` | Service started |
| 4 | `systemctl is-active nginx` | Returns "active" |
| 5 | `rpm -q nginx` | Shows old version |

### 4.3 Satellite Content View Revert

| Step | Command | Expected Result |
|------|---------|-----------------|
| 1 | `hammer host update --id <host-id> --content-view-id <old-cv-id>` | Host reassigned |
| 2 | `dnf distro-sync` | Packages sync to CV |
| 3 | `systemctl restart nginx` | Service restarted |
| 4 | Verify version | Matches CV version |

### 4.4 VM Snapshot Revert

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Login to hypervisor | Admin access |
| 2 | `virsh snapshot-revert <domain> <snapshot>` | Snapshot restored |
| 3 | Verify host boots | System online |
| 4 | Verify service running | Service active |

---

## 5. Playbook Safety Features

### 5.1 Pre-Flight Validations

| Check | Threshold | Action on Failure |
|-------|-----------|-------------------|
| Disk space | ≤90% used | Stop |
| Repository access | Reachable | Stop |
| Subscription status | Subscribed | Stop |
| Content View bound | Yes | Stop |
| Service baseline | Running | Warn, continue |

### 5.2 Execution Controls

| Feature | Configuration | Benefit |
|---------|---------------|---------|
| Serial execution | `serial: 1` | One server at a time |
| Stop on failure | `max_fail_percentage: 0` | No cascade |
| Fatal errors | `any_errors_fatal: true` | Immediate stop |
| Error handling | `block/rescue` | Graceful failure |

### 5.3 Error Detection Points

| Phase | Validation | Failure Action |
|-------|------------|----------------|
| Pre-check | Disk, network, subscription | Stop immediately |
| Installation | DNF exit code | Activate rescue |
| Post-validation | Service status | Stop and report |

---

## 6. Test Execution Checklist

### 6.1 Pre-Test Setup

| Item | Action | Completed |
|------|--------|-----------|
| Satellite setup | Publish Content Views | ☐ |
| | Verify lifecycle environments | ☐ |
| | Register test hosts | ☐ |
| Ansible setup | Configure inventory | ☐ |
| | Verify connectivity | ☐ |
| | Validate playbook syntax | ☐ |
| Test preparation | Create VM snapshots | ☐ |
| | Prepare failure scenarios | ☐ |
| | Set up logging | ☐ |

### 6.2 During Test

| Item | Action | Completed |
|------|--------|-----------|
| Monitoring | Record console output | ☐ |
| | Document error messages | ☐ |
| | Verify stop-on-failure | ☐ |
| Evidence | Collect screenshots | ☐ |
| | Save log files | ☐ |
| | Record timestamps | ☐ |

### 6.3 Post-Test

| Item | Action | Completed |
|------|--------|-----------|
| Validation | Verify expected behavior | ☐ |
| | Document actual results | ☐ |
| | Perform rollback if needed | ☐ |
| Reporting | Update test results | ☐ |
| | Sign off test case | ☐ |

---

## 7. Verification Commands Reference

| Purpose | Command | Example Output |
|---------|---------|----------------|
| Check package version | `rpm -q nginx` | nginx-1.28.2-1.el9.ngx |
| Check service status | `systemctl is-active nginx` | active |
| Check all services | `systemctl list-units --state=running` | [list] |
| Check disk space | `df -h /` | /dev/sda1 35% mounted |
| Recent installations | `rpm -qa --last \| head -20` | [list with timestamps] |
| Check subscription | `subscription-manager status` | Subscribed |
| View DNF log | `tail -n 50 /var/log/dnf.log` | [log entries] |
| Verify backup | `ls -lh /var/lib/rpmbackup/` | [backup files] |

---

## 8. Approval & Sign-Off

### 8.1 Test Execution Summary

| Test Case | Executor | Date | Result | Reviewed By |
|-----------|----------|------|--------|-------------|
| TC-001 | | | ☐ Pass ☐ Fail | |
| TC-002 | | | ☐ Pass ☐ Fail | |
| TC-003 | | | ☐ Pass ☐ Fail | |
| TC-004 | | | ☐ Pass ☐ Fail | |

### 8.2 Overall Assessment

| Criteria | Rating | Comments |
|----------|--------|----------|
| Failure handling demonstrated | ☐ Excellent ☐ Good ☐ Fair ☐ Poor | |
| Rollback capability verified | ☐ Yes ☐ No | |
| Documentation quality | ☐ Excellent ☐ Good ☐ Fair ☐ Poor | |
| Ready for production | ☐ Yes ☐ No | |

### 8.3 Approvals

| Role | Name | Signature | Date |
|------|------|-----------|------|
| Test Executor | | | |
| Technical Lead | | | |
| Client Representative | | | |

---

## 9. Appendix

### 9.1 Playbook Configuration

```yaml
# Safety settings
- hosts: rhel_servers
  serial: 1
  max_fail_percentage: 0
  any_errors_fatal: true
```

### 9.2 Disk Space Check Code

```yaml
- name: Check sufficient disk space
  shell: df / | tail -1 | awk '{print $5}' | sed 's/%//'
  register: disk_usage
  failed_when: disk_usage.stdout|int > 90
```

### 9.3 Installation with Rescue

```yaml
- block:
    - name: Install package
      dnf:
        name: "{{ package }}"
        state: present
  rescue:
    - name: Log failure
      debug:
        msg: "Installation failed"
    - name: Stop execution
      meta: end_play
```

### 9.4 Service Validation

```yaml
- name: Verify service is running
  systemd:
    name: nginx
    state: started
  register: service_status

- name: Fail if not active
  fail:
    msg: "Service validation failed"
  when: service_status.status.ActiveState != "active"
```

---

**Document Control**

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0 | Mar 3, 2026 | Initial version | Automation Team |
| 1.1 | Mar 3, 2026 | Reformatted with proper tables | Automation Team |

---

**End of Document**

---

## 10. OS Version Patching Test Cases

### TC-OS-001: Successful OS Upgrade (9.0 → 9.4)

| Field | Details |
|-------|---------|
| **Test Case ID** | TC-OS-001 |
| **Title** | Successful OS Minor Version Upgrade |
| **Type** | Success Scenario |
| **Priority** | Critical |

#### Test Objective

Verify complete OS upgrade from RHEL 9.0 to 9.4 with reboot management.

#### Pre-Conditions

| Requirement | Status |
|-------------|--------|
| RHEL 9.0 system ready | ☐ Verified |
| RHEL 9.4 repo configured | ☐ Verified |
| Disk space ≤90% used | ☐ Verified |
| VM snapshot created | ☐ Verified |
| SSH connectivity | ☐ Verified |

#### Test Steps

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Run success scenario | Playbook starts |
| 2 | Pre-check: Disk space | Passes |
| 3 | Pre-check: Repo access | Passes |
| 4 | DNF upgrade starts | Begins upgrade |
| 5 | Upgrade completes | No errors |
| 6 | Reboot check | Detects if needed |
| 7 | Reboot (if needed) | System reboots |
| 8 | Post-reboot validation | System online |
| 9 | Version verification | Shows 9.4 |

#### Expected Results

- System upgraded to RHEL 9.4
- Reboot executed if required
- All services running
- Summary report created

---

### TC-OS-002: Pre-Check Validation Failure

| Field | Details |
|-------|---------|
| **Test Case ID** | TC-OS-002 |
| **Title** | Pre-Check Failure - Disk Space |
| **Type** | Failure Scenario |
| **Priority** | Critical |

#### Test Objective

Verify playbook stops before upgrade when validation fails.

#### Expected Result

```
TASK [Validate disk space threshold]
fatal: [host]: FAILED!
msg: "Insufficient disk space: 95% used. Maximum 90% allowed."
```

---

### TC-OS-003: Upgrade Failure Mid-Process

| Field | Details |
|-------|---------|
| **Test Case ID** | TC-OS-003 |
| **Title** | Upgrade Failure - DNF Error |
| **Type** | Failure Scenario |
| **Priority** | Critical |

#### Test Objective

Verify graceful handling when DNF upgrade fails.

#### Expected Result

- Upgrade failure detected
- Rescue block activated
- Failure report generated
- Rollback instructions provided

---

## Document Control Update

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0 | Mar 3, 2026 | Initial version | Automation Team |
| 1.1 | Mar 3, 2026 | Reformatted with proper tables | Automation Team |
| 1.2 | Mar 6, 2026 | Added OS patching scenarios (TC-OS-001 to TC-OS-003) | Automation Team |

---

**End of Document**
