# RHEL Patching Automation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Automate RHEL 8/9 patching with HTML report generation for banking environment with phased rollout (UAT → DR → PROD)

**Architecture:**
- Master playbook delegates to OS-specific playbooks (rhel8_patch.yaml, rhel9_patch.yaml)
- Package list file specifies exact CVE package versions
- Playbacks back up old RPMs, prompts for confirmation, installs from jump server repo (192.168.20.46)
- JSON results saved per server, consolidated into HTML report via Jinja2 template

**Tech Stack:**
- Ansible 2.15+
- RHEL 8 (yum) and RHEL 9 (dnf)
- Jinja2 templating
- Jump server: 192.168.20.46 with BaseOS/AppStream repos

**Existing Files to Reuse:**
- [templates/html_report_template_v2.j2](../templates/html_report_template_v2.j2) - HTML template (reuse as-is)
- [patching.yaml](../patching.yaml) - Reference for RHEL 9 patching logic
- [generate_report_example.yaml](../generate_report_example.yaml) - Reference for report generation

---

## Task 1: Create Inventory Structure with Environment Groups

**Files:**
- Modify: [inventory](../inventory)

**Step 1: Update inventory file with environment groups**

```bash
cat > inventory << 'EOF'
# RHEL Patching Inventory - Phased Rollout

# UAT Environment - Patch Week 1
[uat_servers]
uat-web-01 ansible_host=10.10.10.101
uat-db-01 ansible_host=10.10.10.102
uat-app-01 ansible_host=10.10.10.103

# DR Environment - Patch Week 2
[dr_servers]
dr-web-01 ansible_host=10.30.30.101
dr-db-01 ansible_host=10.30.30.102
dr-app-01 ansible_host=10.30.30.103

# Production Environment - Patch Week 3
[prod_servers]
prod-web-01 ansible_host=10.20.20.101
prod-db-01 ansible_host=10.20.20.102
prod-app-01 ansible_host=10.20.20.103

# Common variables for all servers
[rhel_servers:vars]
ansible_user=root
ansible_become=true
ansible_become_method=sudo
EOF
```

**Step 2: Verify inventory syntax**

Run: `ansible-inventory -i inventory --list`
Expected: JSON output showing uat_servers, dr_servers, prod_servers groups

**Step 3: Test connectivity to one server**

Run: `ansible -i inventory uat_servers -m ping --limit uat-web-01`
Expected: `uat-web-01 | SUCCESS => { ... "ping": "pong" }`

**Step 4: Commit inventory**

```bash
git add inventory
git commit -m "feat: add environment-specific inventory groups for phased patching"
```

---

## Task 2: Create Package List Parser and Example File

**Files:**
- Create: [packages_to_patch.txt](../packages_to_patch.txt)
- Create: [library/package_parser.py](../library/package_parser.py)

**Step 1: Create example package list file**

```bash
cat > packages_to_patch.txt << 'EOF'
# February 2026 Security Patching
# CVE-2024-XXXXX: nginx
# CVE-2024-YYYYY: openssl
# Tested in: UAT, Approved by: Security Team
nginx-1.28.2-1.el9.ngx.x86_64.rpm
openssl-3.0.7-27.el9_4.x86_64.rpm
bash-5.1.8-9.el9_4.x86_64.rpm
EOF
```

**Step 2: Create Python package parser module**

Create directory:
```bash
mkdir -p library
```

Create file:
```bash
cat > library/package_parser.py << 'EOF'
#!/usr/bin/env python3
"""Parse RPM package names from packages_to_patch.txt file."""

import re
from ansible.module_utils.basic import AnsibleModule

def parse_package_string(package_string):
    """
    Parse package string into components.
    Input:  nginx-1.28.2-1.el9.ngx.x86_64.rpm
    Output: {
        'name': 'nginx',
        'version': '1.28.2',
        'release': '1.el9.ngx',
        'arch': 'x86_64',
        'full_version': '1.28.2-1.el9.ngx',
        'filename': 'nginx-1.28.2-1.el9.ngx.x86_64.rpm'
    }
    """
    # Remove .rpm suffix
    clean_name = package_string.replace('.rpm', '')

    # Pattern: name-version-release.arch
    # Example: nginx-1.28.2-1.el9.ngx.x86_64
    pattern = r'^(.+)-([0-9]+[^-]+)-([^-]+)\.([^.]+)$'
    match = re.match(pattern, clean_name)

    if not match:
        return None

    name, version, release, arch = match.groups()

    return {
        'name': name,
        'version': version,
        'release': release,
        'arch': arch,
        'full_version': f"{version}-{release}",
        'filename': package_string
    }

def read_package_file(filepath):
    """Read and parse packages_to_patch.txt file."""
    packages = []

    try:
        with open(filepath, 'r') as f:
            for line in f:
                line = line.strip()

                # Skip comments and empty lines
                if not line or line.startswith('#'):
                    continue

                parsed = parse_package_string(line)
                if parsed:
                    packages.append(parsed)
    except FileNotFoundError:
        return []

    return packages

def main():
    module = AnsibleModule(
        argument_spec={
            'package_file': {'type': 'str', 'required': True}
        },
        supports_check_mode=True
    )

    package_file = module.params['package_file']
    packages = read_package_file(package_file)

    module.exit_json(
        changed=False,
        packages=packages,
        count=len(packages)
    )

if __name__ == '__main__':
    main()
EOF
```

**Step 3: Test package parser module**

Run:
```bash
ansible localhost -m package_parser -a "package_file=packages_to_patch.txt" -M library/
```

Expected output:
```json
{
  "count": 3,
  "packages": [
    {
      "name": "nginx",
      "version": "1.28.2",
      "release": "1.el9.ngx",
      "arch": "x86_64",
      "full_version": "1.28.2-1.el9.ngx",
      "filename": "nginx-1.28.2-1.el9.ngx.x86_64.rpm"
    },
    ...
  ]
}
```

**Step 4: Commit parser and example file**

```bash
git add library/ packages_to_patch.txt
git commit -m "feat: add RPM package parser module and example package list"
```

---

## Task 3: Create Master Patch Playbook with OS Detection

**Files:**
- Create: [master_patch.yaml](../master_patch.yaml)

**Step 1: Write master_patch.yaml**

```bash
cat > master_patch.yaml << 'EOF'
---
# Master RHEL Patching Playbook
# Description: Detects RHEL version and delegates to OS-specific playbook
# Usage: ansible-playbook -i inventory master_patch.yaml -l uat_servers

- name: RHEL Patching Automation
  hosts: all
  gather_facts: true
  become: true

  vars:
    package_file: "{{ playbook_dir }}/packages_to_patch.txt"
    patch_data_dir: "{{ playbook_dir }}/patch_data"
    environment_name: "{{ groups | select('in', inventory_hostname) | first | default('unknown') }}"
    timestamp: "{{ ansible_date_time.iso8601 | default('1970-01-01T00:00:00Z') }}"

  pre_tasks:

    - name: Display patching information
      ansible.builtin.debug:
        msg:
          - "=========================================="
          - "  RHEL PATCHING AUTOMATION"
          - "=========================================="
          - "Server: {{ inventory_hostname }}"
          - "IP: {{ ansible_default_ipv4.address | default(ansible_hostname) }}"
          - "OS: {{ ansible_distribution }} {{ ansible_distribution_version }}"
          - "Environment: {{ environment_name }}"
          - "=========================================="

    - name: Read package list file
      ansible.builtin.set_fact:
        packages_to_patch: "{{ lookup('file', package_file).splitlines() | select('match', '^(?!#|#.*$)') | list }}"
      failed_when: false

    - name: Check if package file exists
      ansible.builtin.stat:
        path: "{{ package_file }}"
      register: package_file_stat

    - name: Fail if package file missing
      ansible.builtin.fail:
        msg: "Package file not found: {{ package_file }}"
      when: not package_file_stat.stat.exists

    - name: Parse packages using Python module
      package_parser:
        package_file: "{{ package_file }}"
      register: parsed_packages
      delegate_to: localhost
      become: false

    - name: Display packages to be patched
      ansible.builtin.debug:
        msg: "{{ parsed_packages.packages | map(attribute='name') | join(', ') }}"

    - name: Create patch data directory
      ansible.builtin.file:
        path: "{{ patch_data_dir }}/{{ environment_name }}_{{ ansible_date_time.date }}"
        state: directory
        mode: '0755'
      delegate_to: localhost
      become: false

    - name: Set patch data file path
      ansible.builtin.set_fact:
        patch_data_file: "{{ patch_data_dir }}/{{ environment_name }}_{{ ansible_date_time.date }}/{{ inventory_hostname }}.json"

  tasks:
    - name: Include OS-specific playbook
      ansible.builtin.include_role:
        name: rhel_patching
      vars:
        rhel_version: "{{ ansible_distribution_major_version }}"
        packages: "{{ parsed_packages.packages }}"
        output_file: "{{ patch_data_file }}"

  post_tasks:
    - name: Display completion message
      ansible.builtin.debug:
        msg:
          - "=========================================="
          - "  PATCHING COMPLETE"
          - "=========================================="
          - "Server: {{ inventory_hostname }}"
          - "Data saved to: {{ patch_data_file }}"
          - "=========================================="
EOF
```

**Step 2: Verify playbook syntax**

Run: `ansible-playbook --syntax-check master_patch.yaml`
Expected: No syntax errors

**Step 3: Test with dry-run (check mode)**

Run: `ansible-playbook -i inventory master_patch.yaml -l uat_servers --check --limit uat-web-01`
Expected: Plays through with "CHECK MODE" warnings

**Step 4: Commit master playbook**

```bash
git add master_patch.yaml
git commit -m "feat: add master patch playbook with OS detection and package parsing"
```

---

## Task 4: Create RHEL 9 Patching Role

**Files:**
- Create: [roles/rhel_patching/tasks/main.yml](../roles/rhel_patching/tasks/main.yml)
- Create: [roles/rhel_patching/tasks/rhel9.yml](../roles/rhel_patching/tasks/rhel9.yml)
- Create: [roles/rhel_patching/defaults/main.yml](../roles/rhel_patching/defaults/main.yml)

**Step 1: Create role directory structure**

```bash
mkdir -p roles/rhel_patching/{tasks,handlers,defaults,templates}
```

**Step 2: Create role defaults**

```bash
cat > roles/rhel_patching/defaults/main.yml << 'EOF'
---
# Default variables for RHEL patching role
rpm_backup_dir: /var/lib/rpmbackup
repo_check_enabled: true
reboot_prompt_enabled: true
EOF
```

**Step 3: Create main task file with OS detection**

```bash
cat > roles/rhel_patching/tasks/main.yml << 'EOF'
---
# Main task file - delegates to OS-specific tasks

- name: Include RHEL 9 specific tasks
  ansible.builtin.include_tasks: rhel9.yml
  when: rhel_version == '9'

- name: Include RHEL 8 specific tasks
  ansible.builtin.include_tasks: rhel8.yml
  when: rhel_version == '8'

- name: Fail on unsupported RHEL version
  ansible.builtin.fail:
    msg: "Unsupported RHEL version: {{ rhel_version }}. Only 8 and 9 are supported."
  when: rhel_version not in ['8', '9']
EOF
```

**Step 4: Create RHEL 9 specific tasks**

```bash
cat > roles/rhel_patching/tasks/rhel9.yml << 'EOF'
---
# RHEL 9 specific patching tasks using dnf

- name: Start timer for duration tracking
  ansible.builtin.set_fact:
    patch_start_time: "{{ ansible_date_time.epoch }}"

- name: Verify jump server repo is accessible
  ansible.builtin.command: dnf repolist
  register: repo_check
  changed_when: false
  failed_when: repo_check.rc != 0

- name: Create RPM backup directory
  ansible.builtin.file:
    path: "{{ rpm_backup_dir }}"
    state: directory
    mode: '0755'

- name: Initialize results structure
  ansible.builtin.set_fact:
    patch_results:
      hostname: "{{ inventory_hostname }}"
      ip: "{{ ansible_default_ipv4.address | default(ansible_hostname) }}"
      environment: "{{ inventory_hostname | regex_search('(uat|dr|prod)') | first | default('unknown') }}"
      rhel_version: "{{ ansible_distribution_version }}"
      kernel: "{{ ansible_kernel }}"
      duration: "0s"
      status: "pending"
      patches: []

- name: Process each package
  ansible.builtin.include_tasks: process_package.yml
  loop: "{{ packages }}"
  loop_control:
    loop_var: package_item
    label: "{{ package_item.name }}"

- name: Calculate duration
  ansible.builtin.set_fact:
    patch_duration_seconds: "{{ ansible_date_time.epoch | int - patch_start_time | int }}"

- name: Format duration
  ansible.builtin.set_fact:
    patch_results: "{{ patch_results | combine({'duration': duration_format}) }}"
  vars:
    minutes: "{{ patch_duration_seconds | int // 60 }}"
    seconds: "{{ patch_duration_seconds | int % 60 }}"
    duration_format: "{{ minutes }}m {{ seconds }}s"

- name: Set final status
  ansible.builtin.set_fact:
    patch_results: "{{ patch_results | combine({'status': 'success', 'timestamp': ansible_date_time.iso8601}) }}"

- name: Save results to JSON file on control node
  ansible.builtin.copy:
    content: "{{ patch_results | to_nice_json }}"
    dest: "{{ output_file }}"
    mode: '0644'
  delegate_to: localhost
  become: false
EOF
```

**Step 5: Create package processing task**

```bash
cat > roles/rhel_patching/tasks/process_package.yml << 'EOF'
---
# Process individual package installation

- name: Query current package version
  ansible.builtin.command: rpm -q {{ package_item.name }}
  register: current_version
  changed_when: false
  failed_when: false

- name: Set current version or 'not installed'
  ansible.builtin.set_fact:
    package_current_version: "{{ current_version.stdout if current_version.rc == 0 else 'NOT_INSTALLED' }}"

- name: Get current version string
  ansible.builtin.set_fact:
    package_current_version_only: "{{ package_current_version | regex_replace(package_item.name + '-(' + package_item.version + '.*|' + '[0-9].*', '\\1') }}"

- name: Backup current RPM if installed
  ansible.builtin.shell: |
    find /var/lib/rpm -name "{{ package_item.name }}-*.rpm" -exec cp {} {{ rpm_backup_dir }}/ \;
  register: rpm_backup
  changed_when: rpm_backup.rc == 0
  failed_when: false
  when: current_version.rc == 0

- name: Display package comparison
  ansible.builtin.debug:
    msg:
      - "Package: {{ package_item.name }}"
      - "Current: {{ package_current_version }}"
      - "Target:  {{ package_item.filename }}"
      - "Backup:  {{ 'Saved to ' + rpm_backup_dir if current_version.rc == 0 else 'N/A (not installed)' }}"

- name: Add package to results list
  ansible.builtin.set_fact:
    patch_results: "{{ patch_results | combine({'patches': patch_results.patches + [{'name': package_item.name, 'before': package_current_version_only, 'after': package_item.full_version, 'type': 'security', 'repo': 'jump-server'}]}) }}"

- name: Prompt for installation confirmation
  ansible.builtin.pause:
    prompt: "Install {{ package_item.name }} {{ package_item.full_version }} on {{ inventory_hostname }}? (yes/no)"
  register: install_confirm

- name: Install package from jump server repo
  ansible.builtin.dnf:
    name: "{{ package_item.name }}-{{ package_item.full_version }}"
    state: present
    disable_gpg_check: true
  register: install_result
  when: install_confirm.user_input | bool

- name: Verify installation
  ansible.builtin.command: rpm -q {{ package_item.name }}-{{ package_item.full_version }}
  register: verify_install
  changed_when: false
  when: install_confirm.user_input | bool

- name: Update result status to success
  ansible.builtin.set_fact:
    patch_results: "{{ patch_results | combine({'patches': patch_results.patches | map('combine', {'status': 'success'}) | list}) }}"
  when: verify_install.rc == 0
EOF
```

**Step 6: Verify role syntax**

Run: `ansible-playbook master_patch.yaml --syntax-check`
Expected: No errors

**Step 7: Commit RHEL 9 role**

```bash
git add roles/rhel_patching/
git commit -m "feat: add RHEL 9 patching role with package processing"
```

---

## Task 5: Create RHEL 8 Patching Tasks

**Files:**
- Create: [roles/rhel_patching/tasks/rhel8.yml](../roles/rhel_patching/tasks/rhel8.yml)

**Step 1: Create RHEL 8 specific tasks (copy of RHEL 9 with yum instead of dnf)**

```bash
cat > roles/rhel_patching/tasks/rhel8.yml << 'EOF'
---
# RHEL 8 specific patching tasks using yum

- name: Start timer for duration tracking
  ansible.builtin.set_fact:
    patch_start_time: "{{ ansible_date_time.epoch }}"

- name: Verify jump server repo is accessible
  ansible.builtin.command: yum repolist
  register: repo_check
  changed_when: false
  failed_when: repo_check.rc != 0

- name: Create RPM backup directory
  ansible.builtin.file:
    path: "{{ rpm_backup_dir }}"
    state: directory
    mode: '0755'

- name: Initialize results structure
  ansible.builtin.set_fact:
    patch_results:
      hostname: "{{ inventory_hostname }}"
      ip: "{{ ansible_default_ipv4.address | default(ansible_hostname) }}"
      environment: "{{ inventory_hostname | regex_search('(uat|dr|prod)') | first | default('unknown') }}"
      rhel_version: "{{ ansible_distribution_version }}"
      kernel: "{{ ansible_kernel }}"
      duration: "0s"
      status: "pending"
      patches: []

- name: Process each package
  ansible.builtin.include_tasks: process_package.yml
  loop: "{{ packages }}"
  loop_control:
    loop_var: package_item
    label: "{{ package_item.name }}"

- name: Calculate duration
  ansible.builtin.set_fact:
    patch_duration_seconds: "{{ ansible_date_time.epoch | int - patch_start_time | int }}"

- name: Format duration
  ansible.builtin.set_fact:
    patch_results: "{{ patch_results | combine({'duration': duration_format}) }}"
  vars:
    minutes: "{{ patch_duration_seconds | int // 60 }}"
    seconds: "{{ patch_duration_seconds | int % 60 }}"
    duration_format: "{{ minutes }}m {{ seconds }}s"

- name: Set final status
  ansible.builtin.set_fact:
    patch_results: "{{ patch_results | combine({'status': 'success', 'timestamp': ansible_date_time.iso8601}) }}"

- name: Save results to JSON file on control node
  ansible.builtin.copy:
    content: "{{ patch_results | to_nice_json }}"
    dest: "{{ output_file }}"
    mode: '0644'
  delegate_to: localhost
  become: false
EOF
```

**Step 2: Verify no syntax errors**

Run: `ansible-playbook master_patch.yaml --syntax-check`
Expected: No errors

**Step 3: Commit RHEL 8 tasks**

```bash
git add roles/rhel_patching/tasks/rhel8.yml
git commit -m "feat: add RHEL 8 patching tasks using yum"
```

---

## Task 6: Add Reboot Handler and Prompt

**Files:**
- Modify: [roles/rhel_patching/tasks/main.yml](../roles/rhel_patching/tasks/main.yml)
- Create: [roles/rhel_patching/handlers/main.yml](../roles/rhel_patching/handlers/main.yml)

**Step 1: Create reboot handler**

```bash
cat > roles/rhel_patching/handlers/main.yml << 'EOF'
---
- name: Reboot server
  ansible.builtin.reboot:
    msg: "Rebooting after patching"
    pre_reboot_delay: 10
    reboot_timeout: 600
  listen: reboot_servers

- name: Wait for server to come back online
  ansible.builtin.wait_for_connection:
    delay: 10
    timeout: 300
  listen: reboot_servers
EOF
```

**Step 2: Add reboot prompt to main.yml**

Append to roles/rhel_patching/tasks/main.yml:
```yaml
- name: Prompt for reboot after patching
  ansible.builtin.pause:
    prompt: "Patching complete for {{ inventory_hostname }}. Reboot now? (yes/no)"
  register: reboot_confirm
  when: reboot_prompt_enabled | bool

- name: Trigger reboot
  ansible.builtin.command: /bin/true
  changed_when: true
  notify: reboot_servers
  when: reboot_confirm.user_input | bool
```

**Step 3: Commit reboot handler**

```bash
git add roles/rhel_patching/
git commit -m "feat: add reboot prompt and handler"
```

---

## Task 7: Create Report Generation Playbook

**Files:**
- Create: [generate_report.yaml](../generate_report.yaml)

**Step 1: Write report generation playbook**

```bash
cat > generate_report.yaml << 'EOF'
---
# Generate HTML Report from Patch JSON Data
# Usage: ansible-playbook generate_report.yaml -e environment=uat

- name: Generate RHEL Patching HTML Report
  hosts: localhost
  gather_facts: false

  vars:
    environment: "{{ env | default('uat') }}"
    patch_date: "{{ ansible_date_time.date | default('2026-02-16') }}"
    patch_data_dir: "{{ playbook_dir }}/patch_data"
    report_dir: "{{ playbook_dir }}/reports"
    admin_email: "admin@example.com"

  tasks:
    - name: Get current date
      ansible.builtin.set_fact:
        current_date: "{{ lookup('pipe', 'date +%Y-%m-%d') }}"

    - name: Find JSON files for environment
      ansible.builtin.find:
        paths: "{{ patch_data_dir }}"
        patterns: "{{ environment }}_*.json"
        recursive: true
      register: json_files
      failed_when: json_files.matched == 0

    - name: Read all JSON result files
      ansible.builtin.set_fact:
        server_results: "{{ lookup('file', item.path) | from_json }}"
      loop: "{{ json_files.files }}"
      register: server_data
      loop_control:
        label: "{{ item.path | basename }}"

    - name: Compile results list
      ansible.builtin.set_fact:
        all_results: "{{ server_data.results | map(attribute='ansible_facts.server_results') | list }}"

    - name: Calculate environment statistics
      ansible.builtin.set_fact:
        env_stats:
          name: "{{ environment }}"
          total: "{{ all_results | length }}"
          success: "{{ all_results | selectattr('status', 'equalto', 'success') | list | length }}"
          failed: "{{ all_results | selectattr('status', 'equalto', 'failed') | list | length }}"
          patches_applied: "{{ all_results | map(attribute='patches') | sum('length') }}"
          kernel_updates: "{{ all_results | map(attribute='patches') | sum('length') }}"  # TODO: filter kernel packages
          security_updates: "{{ all_results | map(attribute='patches') | sum('length') }}"  # TODO: filter security packages

    - name: Group results by server
      ansible.builtin.set_fact:
        environments:
          - "{{ env_stats | combine({'servers': all_results}) }}"

    - name: Calculate totals
      ansible.builtin.set_fact:
        total_servers: "{{ env_stats.total }}"
        total_success: "{{ env_stats.success }}"
        total_failed: "{{ env_stats.failed }}"
        total_patches: "{{ env_stats.patches_applied }}"
        completion_percent: "{{ ((env_stats.success | float) / (env_stats.total | float) * 100) | round(2) }}"

    - name: Create reports directory
      ansible.builtin.file:
        path: "{{ report_dir }}"
        state: directory
        mode: '0755'

    - name: Generate execution ID
      ansible.builtin.set_fact:
        execution_id: "{{ lookup('pipe', 'uuidgen | tr -d \\'-\\' | cut -c1-8') }}"

    - name: Generate HTML report
      ansible.builtin.template:
        src: templates/html_report_template_v2.j2
        dest: "{{ report_dir }}/{{ environment }}_patching_{{ current_date }}.html"
        mode: '0644'
      vars:
        timestamp: "{{ lookup('pipe', 'date \\'+%Y-%m-%d %H:%M:%S UTC\\'') }}"
        total_duration: "TBD"  # Calculate from JSON timestamps
        environments: "{{ environments }}"

    - name: Display report location
      ansible.builtin.debug:
        msg:
          - "=========================================="
          - "  HTML REPORT GENERATED"
          - "=========================================="
          - "Location: {{ report_dir }}/{{ environment }}_patching_{{ current_date }}.html"
          - "Open in browser to view"
          - "=========================================="
EOF
```

**Step 2: Verify playbook syntax**

Run: `ansible-playbook generate_report.yaml --syntax-check`
Expected: No errors

**Step 3: Commit report playbook**

```bash
git add generate_report.yaml
git commit -m "feat: add HTML report generation playbook"
```

---

## Task 8: Create Rollback Documentation

**Files:**
- Create: [docs/ROLLBACK.md](../docs/ROLLBACK.md)

**Step 1: Write rollback documentation**

```bash
cat > docs/ROLLBACK.md << 'EOF'
# Rollback Procedures

## Overview

Each patching session automatically backs up old RPMs to `/var/lib/rpmbackup/` on target servers before installing new versions.

## Automatic Backup Location

```
/var/lib/rpmbackup/
├── nginx-1.20.1-8.el9_2.x86_64.rpm
├── openssl-3.0.1-47.el9_2.x86_64.rpm
└── bash-5.1.8-6.el9_2.x86_64.rpm
```

## Manual Rollback Process

### Step 1: Identify problematic package

```bash
# Check current version
rpm -qa | grep nginx
# Output: nginx-1.28.2-1.el9.ngx.x86_64
```

### Step 2: Check available backup

```bash
ls -lh /var/lib/rpmbackup/
# Should show: nginx-1.20.1-8.el9_2.x86_64.rpm
```

### Step 3: Downgrade to backup version

```bash
# Single package rollback
cd /var/lib/rpmbackup/
sudo rpm -Uvh --oldpackage nginx-1.20.1-8.el9_2.x86_64.rpm

# Multiple packages
sudo rpm -Uvh --oldpackage \
  nginx-1.20.1-8.el9_2.x86_64.rpm \
  openssl-3.0.1-47.el9_2.x86_64.rpm
```

### Step 4: Verify rollback

```bash
rpm -qa | grep nginx
# Output: nginx-1.20.1-8.el9_2.x86_64
```

### Step 5: Restart affected services

```bash
sudo systemctl restart nginx
sudo systemctl status nginx
```

## Complete Rollout Rollback

If entire patching batch needs rollback:

```bash
#!/bin/bash
# Rollback all packages from backup

for rpm in /var/lib/rpmbackup/*.rpm; do
  sudo rpm -Uvh --oldpackage "$rpm"
done

# Reboot to ensure clean state
sudo reboot
```

## Automated Rollback Script

Generate rollback script from patch data:

```bash
# Generate rollback script
cat > /tmp/rollback_{{ inventory_hostname }}.sh << 'ROLLBACK_EOF'
#!/bin/bash
# Auto-generated rollback script
# Date: {{ ansible_date_time.iso8601 }}

cd /var/lib/rpmbackup/

{% for patch in patch_results.patches %}
echo "Rolling back {{ patch.name }}..."
sudo rpm -Uvh --oldpackage {{ patch.name }}-{{ patch.before }}.rpm
{% endfor %}

echo "Rollback complete. Rebooting..."
sudo reboot
ROLLBACK_EOF

chmod +x /tmp/rollback_{{ inventory_hostname }}.sh
```

## Verification After Rollback

1. Check package versions: `rpm -qa | grep {package}`
2. Verify service status: `systemctl status {service}`
3. Check application logs
4. Run application health checks
5. Monitor for 24 hours

## Escalation

If rollback fails:
1. Contact systems team
2. Consider server rebuild from backup
3. Engage vendor support if needed
EOF
```

**Step 2: Commit rollback docs**

```bash
git add docs/ROLLBACK.md
git commit -m "docs: add rollback procedures"
```

---

## Task 9: Update README with Usage Instructions

**Files:**
- Modify: [README.md](../README.md)

**Step 1: Create comprehensive README**

```bash
cat > README.md << 'EOF'
# RHEL Patching Automation

Automated RHEL 8/9 patching with HTML report generation for banking environments.

## Features

- ✅ OS-aware (RHEL 8 & 9)
- ✅ Phased rollout (UAT → DR → PROD)
- ✅ CVE-specific patching (not full system updates)
- ✅ Interactive confirmation before installation
- ✅ Automatic RPM backup for rollback
- ✅ HTML reports with before/after versions
- ✅ Jump server integration (192.168.20.46)

## Prerequisites

- Ansible 2.15+ on control node
- SSH access to target servers
- Sudo/root access on targets
- Jump server repos accessible from targets
- Local repo configured on each target

## Quick Start

### 1. Update Inventory

Edit `inventory` file with your servers:

```ini
[uat_servers]
uat-web-01 ansible_host=10.10.10.101
uat-db-01 ansible_host=10.10.10.102

[dr_servers]
dr-web-01 ansible_host=10.30.30.101

[prod_servers]
prod-web-01 ansible_host=10.20.20.101
```

### 2. Create Package List

Edit `packages_to_patch.txt` with CVE packages:

```txt
# February 2026 Security Patching
nginx-1.28.2-1.el9.ngx.x86_64.rpm
openssl-3.0.7-27.el9_4.x86_64.rpm
bash-5.1.8-9.el9_4.x86_64.rpm
```

### 3. Run Patching (UAT)

```bash
# Patch UAT servers
ansible-playbook -i inventory master_patch.yaml -l uat_servers

# Generate report
ansible-playbook generate_report.yaml -e environment=uat
```

### 4. Review Report

Open in browser: `reports/uat_patching_2026-02-16.html`

### 5. Repeat for DR and PROD

```bash
# Week 2: DR
ansible-playbook -i inventory master_patch.yaml -l dr_servers
ansible-playbook generate_report.yaml -e environment=dr

# Week 3: PROD
ansible-playbook -i inventory master_patch.yaml -l prod_servers
ansible-playbook generate_report.yaml -e environment=prod
```

## Rollback

See [docs/ROLLBACK.md](docs/ROLLBACK.md) for detailed procedures.

Quick rollback:
```bash
ssh uat-web-01
cd /var/lib/rpmbackup/
sudo rpm -Uvh --oldpackage nginx-1.20.1-8.el9_2.x86_64.rpm
```

## Directory Structure

```
rhel_patching/
├── inventory                    # Server inventory
├── master_patch.yaml            # Main playbook
├── packages_to_patch.txt        # CVE package list
├── roles/rhel_patching/         # Patching role
├── generate_report.yaml         # Report generator
├── patch_data/                  # JSON results
├── reports/                     # HTML reports
└── docs/                        # Documentation
```

## Troubleshooting

### Repo not accessible
```bash
# On target server
yum repolist  # RHEL 8
dnf repolist  # RHEL 9
```

### Package not found
Check jump server (192.168.20.46) has the RPM:
```bash
curl http://192.168.20.46/rhel-9.7/BaseOS/Packages/ | grep nginx
```

### Permission denied
Ensure ansible user has sudo access:
```bash
ansible -i inventory uat_servers -m shell -a "whoami" -b
```

## Support

Contact: admin@example.com
EOF
```

**Step 2: Commit README**

```bash
git add README.md
git commit -m "docs: add comprehensive usage instructions"
```

---

## Task 10: Integration Testing

**Files:**
- Create: [tests/integration_test.yaml](../tests/integration_test.yaml)

**Step 1: Create integration test playbook**

```bash
mkdir -p tests
cat > tests/integration_test.yaml << 'EOF'
---
# Integration test for RHEL patching automation
# Run: ansible-playbook tests/integration_test.yaml -i inventory

- name: Test RHEL Patching Automation
  hosts: localhost
  gather_facts: false

  tasks:
    - name: Check inventory file exists
      ansible.builtin.stat:
        path: "{{ playbook_dir }}/../inventory"
      register: inventory_file

    - name: Check packages_to_patch.txt exists
      ansible.builtin.stat:
        path: "{{ playbook_dir }}/../packages_to_patch.txt"
      register: package_file

    - name: Check master_patch.yaml syntax
      ansible.builtin.command: ansible-playbook --syntax-check {{ playbook_dir }}/../master_patch.yaml
      register: master_syntax

    - name: Check generate_report.yaml syntax
      ansible.builtin.command: ansible-playbook --syntax-check {{ playbook_dir }}/../generate_report.yaml
      register: report_syntax

    - name: Test package parser module
      package_parser:
        package_file: "{{ playbook_dir }}/../packages_to_patch.txt"
      register: parser_result

    - name: Display test results
      ansible.builtin.debug:
        msg:
          - "=========================================="
          - "  INTEGRATION TEST RESULTS"
          - "=========================================="
          - "Inventory file: {{ 'PASS' if inventory_file.stat.exists else 'FAIL' }}"
          - "Package file: {{ 'PASS' if package_file.stat.exists else 'FAIL' }}"
          - "Master playbook syntax: {{ 'PASS' if master_syntax.rc == 0 else 'FAIL' }}"
          - "Report playbook syntax: {{ 'PASS' if report_syntax.rc == 0 else 'FAIL' }}"
          - "Packages parsed: {{ parser_result.count }}"
          - "=========================================="

    - name: Fail if any test failed
      ansible.builtin.fail:
        msg: "Integration tests failed"
      when: >
        not inventory_file.stat.exists or
        not package_file.stat.exists or
        master_syntax.rc != 0 or
        report_syntax.rc != 0
EOF
```

**Step 2: Run integration tests**

Run: `ansible-playbook tests/integration_test.yaml`
Expected: All tests PASS

**Step 3: Commit test suite**

```bash
git add tests/
git commit -m "test: add integration test suite"
```

---

## Task 11: Create Example Workflow Script

**Files:**
- Create: [scripts/patch_uat.sh](../scripts/patch_uat.sh)

**Step 1: Create UAT patching script**

```bash
mkdir -p scripts
cat > scripts/patch_uat.sh << 'EOF'
#!/bin/bash
# UAT Patching Workflow Script
# Usage: ./scripts/patch_uat.sh

set -e

echo "=========================================="
echo "  UAT PATCHING WORKFLOW"
echo "=========================================="
echo ""

# Step 1: Verify environment
echo "[1/5] Verifying environment..."
ansible-playbook tests/integration_test.yaml

# Step 2: Patch UAT servers
echo ""
echo "[2/5] Patching UAT servers..."
ansible-playbook -i inventory master_patch.yaml -l uat_servers

# Step 3: Generate report
echo ""
echo "[3/5] Generating HTML report..."
ansible-playbook generate_report.yaml -e environment=uat

# Step 4: Display report location
echo ""
echo "[4/5] Report generated:"
ls -lh reports/uat_patching_*.html | tail -1

# Step 5: Next steps
echo ""
echo "[5/5] Next steps:"
echo "  1. Review report in browser"
echo "  2. Test applications on UAT"
echo "  3. If issues: rollback using docs/ROLLBACK.md"
echo "  4. If successful: proceed to DR next week"
echo ""
echo "=========================================="
echo "  UAT PATCHING COMPLETE"
echo "=========================================="
EOF

chmod +x scripts/patch_uat.sh
```

**Step 2: Create DR and PROD scripts**

```bash
cat > scripts/patch_dr.sh << 'EOF'
#!/bin/bash
# DR Patching Workflow Script
set -e
echo "=========================================="
echo "  DR PATCHING WORKFLOW"
echo "=========================================="
ansible-playbook -i inventory master_patch.yaml -l dr_servers
ansible-playbook generate_report.yaml -e environment=dr
echo "Report: reports/dr_patching_*.html"
EOF

chmod +x scripts/patch_dr.sh

cat > scripts/patch_prod.sh << 'EOF'
#!/bin/bash
# PROD Patching Workflow Script
set -e
echo "=========================================="
echo "  PROD PATCHING WORKFLOW"
echo "=========================================="
ansible-playbook -i inventory master_patch.yaml -l prod_servers
ansible-playbook generate_report.yaml -e environment=prod
echo "Report: reports/prod_patching_*.html"
EOF

chmod +x scripts/patch_prod.sh
```

**Step 3: Commit workflow scripts**

```bash
git add scripts/
git commit -m "feat: add workflow scripts for UAT/DR/PROD patching"
```

---

## Task 12: Final Verification and Documentation

**Step 1: Run full integration test**

Run: `ansible-playbook tests/integration_test.yaml`
Expected: All tests PASS

**Step 2: Verify all playbooks have syntax check**

```bash
for playbook in master_patch.yaml generate_report.yaml; do
  echo "Checking $playbook..."
  ansible-playbook --syntax-check $playbook
done
```

Expected: No errors

**Step 3: Create CHANGELOG entry**

```bash
cat > CHANGELOG.md << 'EOF'
# Changelog

## [Unreleased]

### Added
- Automated RHEL 8/9 patching with OS detection
- CVE-specific package patching (not full system updates)
- Interactive confirmation before installation
- Automatic RPM backup to /var/lib/rpmbackup/
- HTML report generation with before/after versions
- Phased rollout support (UAT → DR → PROD)
- Rollback documentation and procedures
- Integration test suite
- Workflow scripts for each environment

### Changed
- Updated inventory to use environment-specific groups
- Restructured playbooks into role-based architecture

### Fixed
- N/A (initial release)

## [1.0.0] - 2026-02-16

### Added
- Initial release of RHEL patching automation
EOF
```

**Step 4: Commit final documentation**

```bash
git add CHANGELOG.md
git commit -m "docs: add changelog for v1.0.0"
```

**Step 5: Tag release**

```bash
git tag -a v1.0.0 -m "Release v1.0.0: RHEL Patching Automation"
git push origin main --tags
```

---

## Summary

This implementation plan creates a complete RHEL patching automation system with:

1. **Master playbook** with OS detection (RHEL 8/9)
2. **Role-based architecture** for maintainability
3. **Package parser** for reading CVE package lists
4. **Interactive prompts** for safety
5. **Automatic backups** for rollback
6. **HTML reports** for audit trails
7. **Phased rollout** support (UAT → DR → PROD)
8. **Comprehensive documentation** and tests

Total estimated implementation time: 2-3 hours
