# RHEL Patching Automation with HTML Report Generation

**Date:** 2026-02-16
**Status:** Approved
**Author:** Design Discussion with User

## Context

Monthly RHEL patching for banking environment requires automation to:
- Patch specific CVE-affected packages (not full system updates)
- Support phased rollout: UAT → DR → PROD (not simultaneous)
- Generate comprehensive HTML reports with before/after package versions
- Provide rollback capability via local RPM backups
- Work with offline environment using jump server (192.168.20.46) as central repository

## Problem

Current process is manual and error-prone:
1. Security team identifies CVE (e.g., NGINX vulnerability)
2. Manual version verification across servers
3. Manual package installation on each server
4. Manual report generation
5. Risk of inconsistencies between environments

## Solution

Automated Ansible playbooks with:
- Master playbook delegating to OS-specific playbooks (RHEL 8 & 9)
- Package list file specifying exact versions to install
- Interactive confirmation before installation
- Automatic backup of old RPMs for rollback
- HTML report generation with full package details

## Architecture

### File Structure

```
rhel_patching/
├── inventory
│   ├── [uat_servers]           # UAT environment
│   ├── [dr_servers]            # DR environment
│   └── [prod_servers]          # Production environment
│
├── master_patch.yaml           # Main entry point (OS detection)
├── rhel8_patch.yaml            # RHEL 8 specific patching (yum)
├── rhel9_patch.yaml            # RHEL 9 specific patching (dnf)
│
├── generate_report.yaml         # HTML report generator
│
├── packages_to_patch.txt       # CVE package list with exact versions
│   # Example:
│   nginx-1.28.2-1.el9.ngx.x86_64.rpm
│   openssl-3.0.7-27.el9_4.x86_64.rpm
│
├── templates/
│   └── html_report_template_v2.j2   # Existing template (reuse)
│
├── patch_data/                 # JSON results per environment/date
│   ├── uat_2026-02-16/
│   ├── dr_2026-02-23/
│   └── prod_2026-03-02/
│
└── reports/                    # Final HTML reports
```

### Jump Server Repository

**Server:** 192.168.20.46

**Structure:**
```
http://192.168.20.46/
├── rhel-8.8/
│   ├── BaseOS/Packages/
│   └── AppStream/Packages/
├── rhel-9.4/
│   ├── BaseOS/Packages/
│   └── AppStream/Packages/
└── rhel-9.7/
    ├── BaseOS/Packages/
    └── AppStream/Packages/
```

**Target Server Repo Configuration:**
```ini
# /etc/yum.repos.d/local_rhel9.7.repo
[BaseOS]
name=Red Hat Enterprise Linux 9.7 - BaseOS
baseurl=http://192.168.20.46/rhel-9.7/BaseOS/
enabled=1
gpgcheck=0

[AppStream]
name=Red Hat Enterprise Linux 9.7 - AppStream
baseurl=http://192.168.20.46/rhel-9.7/AppStream/
enabled=1
gpgcheck=0
```

## Data Flow

### Execution Flow

```
1. User runs: ansible-playbook -i inventory master_patch.yaml -l uat_servers

2. For EACH SERVER:

   a) READ packages_to_patch.txt
      Parse: nginx-1.28.2-1.el9.ngx.x86_64.rpm
      → name: nginx
      → version: 1.28.2-1.el9.ngx

   b) CHECK current versions
      rpm -q nginx openssl bash

   c) BACKUP old RPMs
      cp /var/lib/rpm/{package} /var/lib/rpmbackup/

   d) DISPLAY comparison table
      ┌─────────────────────────────────────────┐
      │ nginx:   1.20.1 → 1.28.2               │
      │ openssl: 3.0.1 → 3.0.7                 │
      │ bash:    5.1.8 → 5.1.8 (same)          │
      │                                         │
      │ Install from: jump-server repo         │
      │ Proceed? (yes/no):                      │
      └─────────────────────────────────────────┘

   e) IF YES: yum/dnf install -y {package-version}
   f) VERIFY and save to JSON

3. REBOOT PROMPT (after all servers)
   "Patching complete. Reboot servers now? (yes/no)"

4. SAVE RESULTS
   patch_data/uat_2026-02-16/{hostname}.json

5. GENERATE REPORT
   ansible-playbook generate_report.yaml -e environment=uat
   → reports/uat_patching_2026-02-16.html
```

### JSON Result Format

```json
{
  "hostname": "uat-web-01.example.com",
  "ip": "10.10.10.101",
  "environment": "uat",
  "rhel_version": "9.4",
  "kernel": "5.14.0-427.31.1.el9_4.x86_64",
  "duration": "8m 32s",
  "status": "success",
  "patches": [
    {
      "name": "nginx",
      "before": "1.20.1-8.el9_2",
      "after": "1.28.2-1.el9.ngx",
      "type": "security",
      "repo": "rhel-9.7-local"
    },
    {
      "name": "openssl",
      "before": "3.0.1-47.el9_2",
      "after": "3.0.7-27.el9_4",
      "type": "security",
      "repo": "rhel-9.7-local"
    }
  ],
  "timestamp": "2026-02-16T14:32:15Z"
}
```

## Components

### 1. master_patch.yaml

**Purpose:** Entry point, OS detection, delegation

**Tasks:**
- Detect RHEL version via `ansible_distribution_major_version`
- Include rhel8_patch.yaml or rhel9_patch.yaml
- Read packages_to_patch.txt
- Pass package list to OS-specific playbook

### 2. rhel8_patch.yaml / rhel9_patch.yaml

**Purpose:** OS-specific patching logic

**Tasks:**
1. Verify jump server repo accessible
2. Parse packages_to_patch.txt
3. Query current versions: `rpm -q {package}`
4. Backup current RPMs to `/var/lib/rpmbackup/`
5. Display before/after comparison
6. Pause for user confirmation
7. Install packages: `yum install -y {package-version}` (RHEL 8)
   or `dnf install -y {package-version}` (RHEL 9)
8. Verify installation
9. Record start/end time for duration
10. Save results to JSON on Ansible control node

### 3. generate_report.yaml

**Purpose:** Generate HTML report from JSON data

**Tasks:**
1. Read all JSON files from `patch_data/{environment}_{date}/`
2. Calculate summary statistics:
   - Total servers, success, failed
   - Total patches applied
   - Kernel updates count
   - Security updates count
3. Render HTML using existing template
4. Save to `reports/{environment}_patching_{date}.html`

### 4. packages_to_patch.txt

**Format:**
```txt
# February 2026 Security Patching
# CVE-2024-XXXXX: nginx
# CVE-2024-YYYYY: openssl
nginx-1.28.2-1.el9.ngx.x86_64.rpm
openssl-3.0.7-27.el9_4.x86_64.rpm
bash-5.1.8-9.el9_4.x86_64.rpm
```

**Parsing Rules:**
- One package per line
- Format: `{name}-{version}-{release}.{arch}.rpm`
- Lines starting with `#` are comments
- Empty lines ignored

## Rollback Strategy

**Backup Location:** `/var/lib/rpmbackup/` on each target server

**Rollback Process:**
```bash
# On affected server
ssh uat-web-01.example.com
cd /var/lib/rpmbackup/
sudo rpm -Uvh --oldpackage nginx-1.20.1-8.el9_2.x86_64.rpm
sudo rpm -Uvh --oldpackage openssl-3.0.1-47.el9_2.x86_64.rpm
```

**Rollback Scenarios:**
- Application incompatibility after patch
- Service failures post-reboot
- Performance issues
- Test failures in UAT

## Workflow

### Monthly Patching Cycle

```
Week 1: UAT
---------
1. Update packages_to_patch.txt with CVE packages
2. ansible-playbook -i inventory master_patch.yaml -l uat_servers
3. Review UAT report: reports/uat_patching_2026-02-16.html
4. Test applications
5. If issues: rollback from /var/lib/rpmbackup/

Week 2: DR (after UAT approved)
-----------
1. ansible-playbook -i inventory master_patch.yaml -l dr_servers
2. Review DR report
3. Test DR environment

Week 3: PROD (after DR approved)
-------------
1. ansible-playbook -i inventory master_patch.yaml -l prod_servers
2. Review PROD report
3. Monitor production
```

### Report Regeneration

If needed, regenerate report from historical JSON data:
```bash
ansible-playbook generate_report.yaml \
  -e environment=uat \
  -e patch_date=2026-02-16
```

## Key Features

1. **OS-Aware:** Automatically detects RHEL 8 vs 9
2. **Safety-First:**
   - Display before/before comparison
   - Interactive confirmation prompt
   - Automatic backup of old RPMs
3. **Audit Trail:**
   - JSON files with full details
   - HTML reports for management
   - packages_to_patch.txt as approval record
4. **Phased Rollout:** Run per environment with -l flag
5. **Rollback Ready:** Local backups for quick recovery
6. **Offline-Friendly:** Uses jump server repos, no internet needed

## Error Handling

- **Repo not accessible:** Fail with clear error message
- **Package not found:** Display missing packages, continue with others
- **Installation failure:** Log error, mark server as failed, continue with next server
- **Reboot timeout:** Retry up to 30 times with 10s delay
- **JSON write failure:** Log to local file on server as fallback

## Success Criteria

✅ All servers in environment patched successfully
✅ Only specified packages updated (no full system upgrade)
✅ HTML report generated with accurate data
✅ Old RPMs backed up on all servers
✅ No unexpected package changes
✅ Rollback tested and documented

## Next Steps

1. Implement playbooks (master, rhel8, rhel9, report)
2. Create example packages_to_patch.txt
3. Update inventory with environment groups
4. Test in UAT environment
5. Document rollback procedures
6. Train operations team
