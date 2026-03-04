# Migrating RHEL Patching POC to Ansible Automation Platform (AAP)

**Version:** 1.0
**Date:** March 4, 2026
**Purpose:** Complete guide to set up and run RHEL Patching POC playbooks in AAP

---

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [AAP Project Setup](#aap-project-setup)
4. [Inventory Configuration](#inventory-configuration)
5. [Credential Setup](#credential-setup)
6. [Playbook Upload](#playbook-upload)
7. [Template Creation](#template-creation)
8. [Job Execution](#job-execution)
9. [Advanced Features](#advanced-features)
10. [Troubleshooting](#troubleshooting)

---

## Overview

### What is AAP?

Ansible Automation Platform (AAP) provides:
- **Web-based UI** for running Ansible playbooks
- **Centralized inventory** management
- **Role-based access control** (RBAC)
- **Job scheduling** for automation
- **Audit logging** for compliance
- **Notifications** (Slack, email, webhooks)

### Why Use AAP for This POC?

| Feature | Command Line | AAP |
|---------|---------------|-----|
| **User Interface** | Terminal only | Web UI ✓ |
| **Audit Trail** | Manual logs | Automatic ✓ |
| **Access Control** | SSH keys | RBAC ✓ |
| **Scheduling** | Cron jobs | Built-in scheduler ✓ |
| **Notifications** | Manual scripts | Webhooks ✓ |
| **Inventory** | Text files | Database ✓ |
| **Team Sharing** | File sharing | Permissions ✓ |

### What You're Setting Up

You'll create a project in AAP that can run all 4 POC scenarios:

| Scenario | Template Name | Tag |
|----------|--------------|-----|
| Success (patching) | Patching - Success Scenario | `success` |
| Pre-check failure | Patching - Pre-Check Failure | `precheck_fail` |
| Installation failure | Patching - Installation Failure | `install_fail` |
| Validation failure | Patching - Validation Failure | `validate_fail` |

---

## Prerequisites

### Before You Start

#### On AAP Controller
- [ ] AAP 2.x or later installed
- [ ] Admin access to create projects
- [ ] AAP web UI accessible
- [ ] Target SSH connectivity from AAP controller to RHEL hosts

#### On Target RHEL Hosts
- [ ] Old nginx version installed: `nginx-1.20.1`
- [ ] Repository configured with new version: `nginx-1.28.2`
- [ ] SSH service running and accessible
- [ ] Sudo/root access configured
- [ ] Firewall allows AAP controller SSH access

#### Files Needed
- [ ] `site.yml` - Main playbook file
- [ ] `scenarios/success.yml` - Success scenario
- [ ] `scenarios/precheck_fail.yml` - Pre-check failure
- [ ] `scenarios/install_fail.yml` - Installation failure
- [ ] `scenarios/validate_fail.yml` - Validation failure

#### Repository Setup
- [ ] Local repo configured: `/var/www/html/repos/rhel9/x86_64/`
- [ ] Both nginx versions available (1.20.1 and 1.28.2)
- [ ] HTTP server serving repo (Apache/nginx)
- [ ] Target hosts can access repo

### Initial Target Host Setup

If not done already:

```bash
# 1. Install old nginx version
sudo dnf install nginx-1.20.1-1.el9.ngx -y
sudo systemctl start nginx
sudo systemctl enable nginx

# 2. Verify old version
rpm -q nginx
# Expected: nginx-1.20.1-1.el9.ngx.x86_64

# 3. Configure local repo
cat > /etc/yum.repos.d/local-nginx.repo <<EOF
[local-nginx]
name=Local Nginx Repository
baseurl=http://<jump-server-ip>/repos/rhel9/x86_64/
enabled=1
gpgcheck=0
EOF

# 4. Verify repo
dnf repolist
dnf list available | grep nginx
```

---

## AAP Project Setup

### Step 1: Create New Organization (If Needed)

```
1. Login to AAP web UI
2. Click your username (top right) → Organizations
3. If no org exists, click + Create Organization
```

**Organization Details:**
- Name: `Your Company Name` or `POC Demo`
- Default execution environment: (keep default)

### Step 2: Create New Project

```
1. Navigate to: Organizations → Your Org → Projects
2. Click: + Create Project
```

**Project Details:**

| Field | Value |
|-------|-------|
| **Name** | `RHEL Patching POC` |
| **Description** | `POC demonstration for client - RHEL patching with failure handling` |
| **Organization** | Your organization (from Step 1) |
| **Default Execution Environment** | Control Node (or use custom) |

**Additional Settings:**
```
☐ Enable synchronizing project with source control
☐ Allow branch override
☐ Signature verification: (optional)
```

**Click Save**

### Step 3: Verify Project Created

You should see:
```
Projects → RHEL Patching POC
├── Jobs (0)
├── Inventories (0)
├── Credentials (0)
├── Templates (0)
└── Survey Questions (0)
```

---

## Inventory Configuration

### Step 1: Create Inventory

```
Projects → RHEL Patching POC → Inventories → + Add
```

**Choose Inventory Type:**
- **Static Inventory** - For this POC (simpler)
- **Smart Inventory** - For production (auto-discovery)

Select: **Static Inventory**

**Inventory Details:**

| Field | Value |
|-------|-------|
| **Name** | `rhel_poc_inventory` |
| **Organization** | Your organization |
| **Description** | `RHEL servers for POC demonstration` |

**Click Next**

### Step 2: Add Hosts

**Inventory File Content:**

```ini
[rhel_poc_servers]
rhel-test-01 ansible_host=192.168.1.100 ansible_user=root ansible_ssh_common_args='-o StrictHostKeyChecking=no'

# Add more hosts as needed
# rhel-test-02 ansible_host=192.168.1.101 ansible_user=root

[rhel_poc_servers:vars]
ansible_become=true
ansible_become_method=sudo
ansible_python_interpreter=/usr/bin/python3
```

**Tips:**
- Replace `192.168.1.100` with your target host IP
- `ansible_user=root` or your sudo user
- `ansible_ssh_common_args='-o StrictHostKeyChecking=no'` (for POC only, not for production!)

**Click Next**

### Step 3: Review and Save

- Review inventory details
- Click **Save**

### Step 4: Verify Inventory

```
Inventories → rhel_poc_inventory → Hosts
```

You should see your hosts listed with green checkmarks if connectivity is working.

---

## Credential Setup

### Option A: SSH Key Authentication (Recommended)

#### Step 1: Generate SSH Key (If Needed)

On your Ansible control node:

```bash
# Generate key (if you don't have one)
ssh-keygen -t rsa -b 4096 -f ~/.ssh/aap_rsa
```

#### Step 2: Copy Public Key to Target Host

```bash
# Copy public key to target host
ssh-copy-id -i ~/.ssh/aap_rsa.pub root@<target-host>

# Or manually
cat ~/.ssh/aap_rsa.pub | ssh root@<target-host> 'cat >> ~/.ssh/authorized_keys'
```

#### Step 3: Create Credential in AAP

```
Projects → RHEL Patching POC → Credentials → + Add
```

**Credential Details:**

| Field | Value |
|-------|-------|
| **Name** | `SSH Key for RHEL POC` |
| **Organization** | Your organization |
| **Credential Type** | Machine |
| **SSH Key** | Paste your PRIVATE key (`~/.ssh/aap_rsa`) |
| **SSH Key Unlock** | (leave blank if key has no passphrase) |
| **Username** | `root` or your sudo user |

**Click Next → Save**

### Option B: Password Authentication

**Note:** Less secure, use only for testing

```
Projects → RHEL Patching POC → Credentials → + Add
```

**Credential Details:**

| Field | Value |
|-------|-------|
| **Name** | `Password for RHEL POC` |
| **Organization** | Your organization |
| **Credential Type** | Machine |
| **Username** | `root` or your sudo user |
| **Password** | Your SSH password |
| **Ask for password on run** | ☑ (optional) |

**Click Next → Save**

---

## Playbook Upload

### Option 1: Upload Playbook File

```
Projects → RHEL Patching POC → Project → Sync from Filesystem
```

**Steps:**
1. Select directory containing POC playbooks
2. Select `site.yml`
3. Click **Sync**

**Or:**

```
Projects → RHEL Patching POC → Project → Files
```

1. Click **Upload**
2. Select `site.yml`
3. Upload scenario files to subdirectory:
   - Create folder: `scenarios/`
   - Upload: `success.yml`, `precheck_fail.yml`, `install_fail.yml`, `validate_fail.yml`

### Option 2: Upload from Git Repository

```
Projects → RHEL Patching POC → Project → Source Control Management
```

1. Select: **Git**
2. Git Repository URL: `https://github.com/your-repo/rhel-patching-poc.git`
3. Branch: `main` (or your branch)
4. Credential: (if private repo)
5. Click **Sync**

### Option 3: Direct Paste (For Quick Testing)

```
Projects → RHEL Patching POC → Templates → + Add Template
```

Then paste playbook content directly (not recommended for production).

---

## Template Creation

### Overview

Each scenario needs its own template to easily run with tags.

### Template 1: Success Scenario

```
Projects → RHEL Patching POC → Templates → + Add
```

**Template Details:**

| Field | Value |
|-------|-------|
| **Name** | `Patching - Success Scenario (TC-001)` |
| **Description** | `Successful patching - upgrades nginx 1.20.1 → 1.28.2` |
| **Job Type** | `Run Playbook` |
| **Inventory** | `rhel_poc_inventory` |
| **Project** | `RHEL Patching POC` |
| **Execution Environment** | Control Node (or your custom env) |
| **Playbook** | `site.yml` |
| **Credentials** | Select your RHEL credential |
| **Options → Limit** | (optional) `rhel-test-01` |
| **Options → Verbosity** | `1` (equivalent to `-v`) |
| **Tags** | `success` |
| **Job Slices** | Leave as default (for serial execution, use `serial: 1` in playbook) |

**Save Template**

### Template 2: Pre-Check Failure

```
Templates → + Add Template
```

| Field | Value |
|-------|-------|
| **Name** | `Patching - Pre-Check Failure (TC-002)` |
| **Description** | `Demonstrates stop when disk space insufficient` |
| **Job Type** | `Run Playbook` |
| **Inventory** | `rhel_poc_inventory` |
| **Playbook** | `site.yml` |
| **Credentials** | Select your RHEL credential |
| **Tags** | `precheck_fail` |
| **Verbosity** | `1` |

**Save Template**

### Template 3: Installation Failure

```
Templates → + Add Template
```

| Field | Value |
|-------|-------|
| **Name** | `Patching - Installation Failure (TC-003)` |
| **Description** | `Demonstrates rescue block when dependency conflict occurs` |
| **Job Type** | `Run Playbook` |
| **Inventory** | `rhel_poc_inventory` |
| **Playbook** | `site.yml` |
| **Credentials** | Select your RHEL credential |
| **Tags** | `install_fail` |
| **Verbosity** | `2` (more verbose for debugging) |

**Save Template**

### Template 4: Validation Failure

```
Templates → + Add Template
```

| Field | Value |
|-------|-------|
| **Name** | `Patching - Validation Failure (TC-004)` |
| **Description** | `Demonstrates post-patch validation when service fails` |
| **Job Type** | `Run Playbook` |
| **Inventory** | `rhel_poc_inventory` |
| **Playbook** | `site.yml` |
| **Credentials** | Select your RHEL credential |
| **Tags** | `validate_fail` |
| **Verbosity** | `1` |

**Save Template**

### Verify Templates Created

```
Templates → All Templates
```

You should see:
- ✅ Patching - Success Scenario (TC-001)
- ✅ Patching - Pre-Check Failure (TC-002)
- ✅ Patching - Installation Failure (TC-003)
- ✅ Patching - Validation Failure (TC-004)

---

## Job Execution

### Running Jobs from Templates

### Success Scenario

```
Templates → Patching - Success Scenario (TC-001) → Launch
```

**Execution Options:**
- **Limit:** `rhel-test-01` (or leave blank for all)
- **Verbosity:** `0` (default) or `1` for detailed output
- **Job Slices:** Leave as default (playbook handles serial execution)

**Click Launch**

### Other Scenarios

```
Templates → Patching - Pre-Check Failure (TC-002) → Launch
Templates → Patching - Installation Failure (TC-003) → Launch
Templates → Patching - Validation Failure (TC-004) → Launch
```

### Monitoring Job Execution

**During Execution:**
```
Jobs → Job History → [Click running job]
```

**What You'll See:**
- Real-time console output
- Task progress indicators
- ✅ Green checks for successful tasks
- ❌ Red X for failed tasks
- ⚠️ Yellow warnings

**Output Sections:**
```
PLAY [RHEL Patching POC - Success Scenario]

TASK [Gathering Facts]
ok: [rhel-test-01]

TASK [Display target server information]
ok: [rhel-test-01]
==========================================
  PATCHING: rhel-test-01
==========================================
  OS: Red Hat Enterprise Linux 9
  IP: 192.168.1.100
...

TASK [Get current package version]
ok: [rhel-test-01]
CURRENT STATE (BEFORE PATCH)
==========================================
Package: nginx
Version: nginx-1.20.1-1.el9.ngx.x86_64
...
```

### Viewing Job Results

**After Completion:**
```
Jobs → Job History → [Click completed job] → Output
```

**Job Summary:**
```
PLAY RECAP
rhel-test-01: ok=18 changed=2 failed=0
```

**Download Output:**
- Click **Download Output** button
- Downloads as text file
- Contains full console output

---

## Advanced Features

### 1. Survey Variables (User Input at Runtime)

**Use Case:** Ask which scenario to run

**Setup:**
```
Projects → RHEL Patching POC → Survey Questions → + Add
```

**Survey Question:**

| Field | Value |
|-------|-------|
| **Question** | `Which patching scenario do you want to run?` |
| **Description** | `Select the test scenario to execute` |
| **Question Type** | `Multiple Choice` |
| **Choices** |
| - Display Name: `Success (Patching)`<br>Value: `success` |
| - Display Name: `Pre-Check Failure`<br>Value: `precheck_fail` |
| - Display Name: `Installation Failure`<br>Value: `install_fail` |
| - Display Name: `Validation Failure`<br>Value: `validate_fail` |
| **Default** | `success` |

**Add to Template:**
```
Templates → [Select Template] → Survey
```

Check: `Require user input for this survey`

### 2. Extra Variables (Override Playbook Vars)

**Use Case:** Change package versions without editing playbook

**In Template:**
```
Templates → [Select Template] → Extra Variables
```

**Add Variables:**

| Key | Value | Description |
|-----|-------|-------------|
| `package_name` | `httpd` | Change to Apache |
| `current_version` | `2.4.37` | Old version |
| `target_version` | `2.4.58` | New version |
| `disk_threshold` | `90` | Fail if more than 90% used |

**This overrides vars in `site.yml`**

### 3. Job Scheduling

**Use Case:** Run patches during maintenance window

**Setup:**
```
Templates → [Select Template] → Schedules → + Create Schedule
```

**Schedule Details:**

| Field | Value |
|-------|-------|
| **Name** | `Daily Patching - Success Scenario` |
| **Start Date** | Select date/time |
| **Frequency** | `Cron` |
| **Cron Expression** | `0 2 * * *` (2:00 AM daily) |
| **Time Zone** | Your timezone |

**Advanced Options:**
```
☐ Limit to: rhel-test-01
☐ Skip if offline hosts: ☐
☐ State: Enabled
```

### 4. Notifications

**Setup:**
```
Organizations → Your Org → Settings → Notifications → + Create Notification

OR

Templates → [Template] → Notifications
```

**Webhook to Slack:**
```
Notification Type: Webhook
Name: Slack - Patching Alerts
Webhook URL: https://hooks.slack.com/services/YOUR/WEBHOOK/URL
```

**Notification Triggers:**
- ☑ Job succeeded
- ☑ Job failed
- ☑ Job timed out

**Webhook Payload:**
```json
{
  "text": "Patching {{ job_name }} {{ status }} on {{ inventory_hostname }}",
  "blocks": [
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "*Host:* {{ inventory_hostname }}\n*Job:* {{ job_name }}\n*Status:* {{ status }}\n*Duration:* {{ duration }}"
      }
    }
  ]
}
```

### 5. Workflow Job Approval

**Use Case:** Require manager approval before production patching

**Setup:**
```
Resources → Workflows → + Create Workflow
```

**Definition (Example):**
```yaml
name: Patching with Approval

schema: "1.0"
description: Workflow for RHEL patching with manager approval

execution:
  hosts: rhel_poc_servers

execution_environment: "Control Node"

states:
  - name: Pre-Patch Validation
    transition: approval_needed
    actions:
      - validate_environment
      - check_disk_space
      - check_repository_access

  - name: Approval Needed
    transition: patch_approved
    transition: pre_patch_failed
    actions:
      - ask_for_approval
      - notify_manager

  - name: Patch Approved
    transition: success
    transition: patching_failed
    actions:
      - apply_patches
      - validate_services
      - generate_report
      - notify_success

  - name: Pre-Patch Failed
    transition: workflow_failed
    actions:
      - log_failure
      - notify_failure

  - name: Patching Failed
    transition: workflow_failed
    actions:
      - preserve_backup
      - notify_failure

  - name: Success
    actions:
      - log_completion
      - generate_final_report

  - name: Workflow Failed
    actions:
      - log_error
      - notify_error
```

---

## Troubleshooting

### Issue 1: Job Stays in "Pending" State

**Symptom:** Job shows "Pending" and never starts

**Possible Causes:**
1. Target host unreachable
2. SSH authentication failed
3. Ansible Tower/AAP service issues

**Resolution:**
```bash
# On AAP controller, test connectivity
ping <target-host>

# Test SSH from AAP controller
ssh root@<target-host> "echo 'SSH works'"

# Check AAP service
systemctl status awx / ansible-tower
```

### Issue 2: "Permission Denied" Error

**Symptom:** Job fails with authentication error

**Resolution:**
```
1. Verify credential:
   - Username correct
   - SSH key or password correct
   - Key matches public key on target

2. Check sudo permissions:
   # On target host
   visudo
   # Add: username ALL=(ALL) NOPASSWD: ALL

3. Test manually:
   ansible rhel_poc_servers -i inventory -m ping
   ansible rhel_poc_servers -i inventory -m shell "whoami"
```

### Issue 3: Tags Not Working

**Symptom:** Job runs all scenarios instead of specific tag

**Resolution:**

**Check Template:**
```
Templates → [Select Template] → Details
```

**Verify tag is set:**
- Tags section should show: `success` (or other tag)
- Should NOT be blank

**Check Playbook:**
```yaml
# In site.yml, verify tags are defined
tags:
  - success
  - all_scenarios
```

**If still not working:**
```
# Run from AAP CLI to debug
awx-cli job launch --tag success <template-id>
```

### Issue 4: Repository Not Accessible

**Symptom:** Pre-check fails with "Repository unreachable"

**Resolution:**

**On target host:**
```bash
# Test repository access
curl http://<jump-server>/repos/rhel9/x86_64/

# Check repo file
cat /etc/yum.repos.d/local-nginx.repo

# Test dnf
dnf repolist
```

**Check firewall:**
```bash
# On AAP controller
firewall-cmd --list-all

# On target host
sudo firewall-cmd --list-all
```

### Issue 5: "Package Not Found" Error

**Symptom:** Job fails with package not found

**Resolution:**

```bash
# Check available packages
dnf list available | grep nginx

# Verify both versions exist
ls /var/www/html/repos/rhel9/x86_64/Packages/ | grep nginx

# Update repo metadata (if needed)
# On jump server
createrepo --update /var/www/html/repos/rhel9/x86_64/

# Clean cache on target
sudo dnf clean all
```

### Issue 6: "Old Version Not Installed" Error

**Symptom:** Job fails because old version not present

**Resolution:**

```bash
# Install old version first
sudo dnf install nginx-1.20.1 -y
sudo systemctl start nginx

# Verify
rpm -q nginx
# Expected: nginx-1.20.1-1.el9.ngx.x86_64

# Then run job again
```

### Issue 7: Tags Execute in Wrong Order

**Symptom:** Jobs run in unexpected sequence

**Resolution:**

AAP executes templates in alphabetical order by default. To control order:

1. **Use naming convention:**
   - `01-success`
   - `02-precheck_fail`
   - `03-install_fail`
   - `04-validate_fail`

2. **Use Job Workflow** (see Advanced Features)

3. **Run manually in correct order**

---

## Best Practices for Client Demo

### Before Demo

1. **Test All Scenarios First**
   ```bash
   # Test from command line first
   ansible-playbook -i inventory site.yml --tags success -v
   ansible-playbook -i inventory site.yml --tags precheck_fail -v
   ansible-playbook -i inventory site.yml --tags install_fail -v
   ansible-playbook -i inventory site.yml --tags validate_fail -v
   ```

2. **Set Up AAP Environment**
   - Project created and configured
   - Inventory with test hosts
   - Credentials verified
   - Playbooks uploaded
   - Templates created and tested
   - Jobs executed once to verify

3. **Prepare Evidence**
   - Take screenshots of AAP web UI
   - Download job outputs
   - Prepare comparison table (before/after versions)

### During Demo

1. **Start with Dashboard Overview**
   - Show project structure
   - Show templates created
   - Show inventory

2. **Explain Architecture**
   - "This is AAP controlling the patching"
   - "Satellite manages content, AAP controls execution"

3. **Run Success Scenario**
   - Launch job from template
   - Show live execution
   - Highlight version comparison in output
   - Show report generation

4. **Demonstrate Failure Scenarios**
   - Each failure shows specific safety feature
   - Emphasize execution stops
   - Point out clear error messages

5. **Show AAP Features**
   - Job history (audit trail)
   - Notifications (if configured)
   - Scheduling capability

### After Demo

1. **Provide Access**
   - Create limited AAP user for client
   - Share project or create demo org

2. **Documentation**
   - Share this guide
   - Provide screenshots
   - Share job output files

3. **Next Steps Discussion**
   - Ask about Satellite integration
   - Discuss production requirements
   - Timeline and approval process

---

## AAP vs Command Line Reference

| Task | Command Line | AAP |
|------|---------------|-----|
| **Run success scenario** | `ansible-playbook -i inventory site.yml --tags success` | Templates → Launch |
| **Run specific tags** | `--tags success` | Template Tags field |
| **Verbose output** | `-v`, `-vv`, `-vvv` | Verbosity: 1, 2, 3, 4 |
| **Limit hosts** | `--limit rhel-test-01` | Limit field |
| **Check mode** | `--check` | Preview mode (checkmark) |
| **Extra variables** | `-e "var=value"` | Extra Variables section |
| | | |
| **View results** | Check console output | Jobs → Job History → Output |
| **Download output** | Redirect to file | Download Output button |
| **Schedule job** | Set up cron | Schedules → Create Schedule |
| | | |
| **View history** | Check logs | Jobs → Job History |

---

## Quick Reference Card

### AAP URLs

| Purpose | Path |
|---------|------|
| **Dashboard** | `/` |
| **Organizations** | `/#/organizations/` |
| **Projects** | `/#/organizations/<org>/projects/` |
| **Templates** | `/#/organizations/<org>/job_templates/` |
| **Jobs** | `/#/jobs/` |
| **Job History** | `/#/jobs/` |
| **Inventories** | `/#/inventories/` |
| **Credentials** | `/#/credentials/` |
| **Schedules** | `/#/schedules/` |

### CLI Commands (awx-cli)

```bash
# List projects
awx-cli project list

# List templates
awx-cli job_template list

# Launch job template
awx-cli job_template launch <template-name>

# List jobs
awx-cli job list

# Get job output
awx-cli job get <job-id> --output
```

---

## Production Considerations

### When Moving from POC to Production

### Security

| Consideration | Action |
|---------------|--------|
| **Credentials** | Use AAP RBAC, store encrypted |
| | Use SSH keys, not passwords |
| **API Access** | HTTPS only, certificate validation |
| **Audit** | Enable AAP audit logging |

### Scalability

| Consideration | Action |
|---------------|--------|
| **Execution** | Use `serial: 1` for safety |
| **Batches** | Use job slices for parallel execution |
| **Capacity** | Add more AAP instances as needed |

### Monitoring

| Consideration | Action |
|---------------|--------|
| **Alerts** | Configure AAP notifications |
| **Logs** | Centralize AAP logs with SIEM |
| **Dashboards** | Create AAP dashboards for visibility |

### Integration

| Consideration | Action |
|---------------|--------|
| **Satellite** | Use Satellite API for content management |
| **ServiceNow** | Create ticket for patching request |
| **CMDB** | Update after patching |
| | |

---

## Appendix: AAP Template Configuration Files

### Success Template Configuration

**As JSON (for advanced import):**
```json
{
  "name": "Patching - Success Scenario (TC-001)",
  "description": "Successful patching - upgrades nginx 1.20.1 → 1.28.2",
  "organization": "Your Organization",
  "inventory": "rhel_poc_inventory",
  "project": "RHEL Patching POC",
  "playbook": "site.yml",
  "credential": "SSH Key for RHEL POC",
  "tags": ["success"],
  "execution_environment": "Control Node",
  "verbosity": 1,
  "job_type": "run"
}
```

### Job Launch API Call

**Using awx-cli:**
```bash
awx-cli job_template launch "Patching - Success Scenario (TC-001)" \
  --limit "rhel-test-01" \
  --tags "success" \
  --extra_vars '{"package_name": "nginx"}'
```

---

**Document Control**

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0 | Mar 4, 2026 | Initial AAP setup guide | Automation Team |

---

**End of Document**
