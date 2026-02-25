# Test Environment Setup Guide

## Overview

This guide explains how to prepare test virtual machines for testing the RHEL Patching Automation System. You'll need:
- 1 Jump Server (hosts repositories)
- 1-3 RHEL test VMs (can be RHEL 8 or 9)

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   Your Workstation/Laptop                  │
│                  Running Ansible Control Node              │
│  Location: /home/anik/ansible/wikilabs/aeon/rhel_patching/ │
└────────────────────┬────────────────────────────────────────┘
                     │ SSH/Ansible
                     ▼
         ┌───────────────────────────┐
         │   JUMP SERVER (VM 1)      │
         │   IP: 192.168.20.46      │
         │   - HTTP Server (nginx)  │
         │   - RHEL 8.8 RPMs         │
         │   - RHEL 9.4 RPMs         │
         │   - RHEL 9.7 RPMs         │
         └───────────────────────────┘
                     │ HTTP (RPM repos)
                     ▼
         ┌───────────────────────────┐
         │   TEST VMs               │
         │   - UAT-TEST-01          │
         │   - RHEL 8 or 9          │
         │   - Will be patched      │
         └───────────────────────────┘
```

---

## Phase 1: Create Jump Server (VM 1)

### VM Specifications

**Minimum Requirements:**
- CPU: 2 cores
- RAM: 2 GB
- Disk: 50 GB
- OS: RHEL 9 (minimal install)

### Step 1: Install RHEL 9 on Jump Server

1. **Create VM:**
   - Hypervisor: VMware VirtualBox, KVM, Hyper-V (your choice)
   - OS: RHEL 9.x (minimal ISO)
   - Network: NAT or Bridged (note the IP address)
   - Disk: 50 GB thin provisioned

2. **Install RHEL:**
   - Boot from ISO
   - Select "Minimal Install"
   - Set root password
   - Create user: `ansible` with sudo privileges
   - Enable network connection

3. **Post-Installation Setup:**

```bash
# SSH into the jump server
ssh root@<jump-server-ip>

# Update system
dnf update -y

# Install HTTP server (nginx) for hosting repos
dnf install -y nginx

# Enable and start nginx
systemctl enable nginx
systemctl start nginx

# Create repository directory structure
mkdir -p /var/www/html/repos/rhel8.8/x86_64/Packages
mkdir -p /var/www/html/repos/rhel9.4/x86_64/Packages
mkdir -p /var/www/html/repos/rhel9.7/x86_64/Packages

# Set permissions
chown -R nginx:nginx /var/www/html/repos
chmod -R 755 /var/www/html/repos
```

4. **Configure Firewall:**

```bash
# Allow HTTP traffic
firewall-cmd --permanent --add-service=http
firewall-cmd --reload
```

5. **Download RHEL RPMs to Jump Server:**

You have two options:

**Option A: Download from Red Hat Network (if you have subscription)**

```bash
# Register system (if needed)
subscription-manager register

# Enable repositories
subscription-manager repos --enable=rhel-8-for-x86_64-baseos-rpms
subscription-manager repos --enable=rhel-8-for-x86_64-appstream-rpms
subscription-manager repos --enable=rhel-9-for-x86_64-baseos-rpms
subscription-manager repos --enable=rhel-9-for-x86_64-appstream-rpms

# Create reposync config file
cat > /etc/reposync.conf << 'EOF'
[rhel-8.8]
name = RHEL 8.8
baseurl = http://mirror.centos.org/altarch/8/x86_64/
enabled = 1

[rhel-9.4]
name = RHEL 9.4
baseurl = http://mirror.centos.org/altarch/9/x86_64/
enabled = 1

[rhel-9.7]
name = RHEL 9.7
baseurl = http://mirror.centos.org/altarch/9/x86_64/
enabled = 1
EOF

# Download packages (this will take time and disk space)
dnf install -y reposync
mkdir -p /var/www/html/repos/rhel8.8/x86_64/Packages
reposync --repoid=rhel-8-for-x86_64-baseos-rpms --downloadcomps --download-metadata /var/www/html/repos/rhel8.8/x86_64/Packages
```

**Option B: Manual Download (Recommended for Testing)**

```bash
# For testing, create dummy packages first
# You'll replace these with real RPMs later

# Create placeholder files
cd /var/www/html/repos/rhel9.7/x86_64/Packages

# Download test RPMs (these are examples)
# Replace with actual RPMs you need for testing
curl -o nginx-1.20.1-8.el9_2.x86_64.rpm http://mirror.centos.org/altarch/9/x86_64/Packages/nginx-1.20.1-8.el9_2.x86_64.rpm
curl -o openssl-libs-3.0.1-47.el9_2.x86_64.rpm http://mirror.centos.org/altarch/9/x86_64/Packages/openssl-libs-3.0.1-47.el9_2.x86_64.rpm
curl -o bash-5.1.8-6.el9_2.x86_64.rpm http://mirror.centos.org/altarch/9/x86_64/Packages/bash-5.1.8-6.el9_2.x86_64.rpm

# Or copy from local ISO if you mounted it
# mount /dev/sr0 /mnt
# cp /mnt/BaseOS/Packages/nginx-*.rpm /var/www/html/repos/rhel9.7/x86_64/Packages/
```

**Option C: Using Your Existing Setup**

You mentioned your jump server is already at `192.168.20.46` with repos at:
- `http://192.168.20.46/rhel-8.8/BaseOS/`
- `http://192.168.20.46/rhel-9.4/BaseOS/`
- `http://192.168.20.46/rhel-9.7/AppStream/`

Just ensure nginx is serving these directories:

```bash
# On jump server (192.168.20.46)
# Create symlinks to your existing repos
ln -s /path/to/rhel-8.8 /var/www/html/repos/rhel-8.8
ln -s /path/to/rhel-9.4 /var/www/html/repos/rhel-9.4
ln -s /path/to/rhel-9.7 /var/www/html/repos/rhel-9.7

# Test access
curl -I http://192.168.20.46/rhel-9.7/BaseOS/
```

6. **Create Repository Metadata:**

```bash
# Install createrepo
dnf install -y createrepo

# Create repo metadata for each directory
createrepo /var/www/html/repos/rhel8.8/x86_64/Packages/
createrepo /var/www/html/repos/rhel9.4/x86_64/Packages/
createrepo /var/www/html/repos/rhel9.7/x86_64/Packages/
```

7. **Verify Jump Server:**

```bash
# Test HTTP server
curl http://192.168.20.46/rhel-9.7/BaseOS/

# Should return directory listing or 403 (forbidden but working)
```

---

## Phase 2: Create Test VMs (VMs 2, 3, etc.)

### VM Specifications

**For Each Test VM:**
- CPU: 1-2 cores
- RAM: 1-2 GB
- Disk: 20 GB
- OS: RHEL 8 or RHEL 9 (minimal install)

### Step 1: Install RHEL on Test VM

1. **Create VM:**
   - Name: `uat-test-01`
   - OS: RHEL 9.x (minimal ISO)
   - Network: Bridged or NAT (must be accessible from your workstation)
   - Note the IP address (e.g., 192.168.8.61)

2. **Install RHEL:**
   - Minimal install
   - Set root password
   - Create user: `ansible` with sudo privileges

3. **Post-Installation Setup:**

```bash
# SSH into test VM
ssh root@<test-vm-ip>

# Update system
dnf update -y

# Install required packages
dnf install -y python3 libselinux-python3

# Enable SSH password authentication (optional, for testing)
sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart sshd
```

### Step 2: Configure Repository on Test VM

**Important Repository Selection Guide:**

| Test VM OS Version | Repository to Use | Result |
|-------------------|-------------------|---------|
| RHEL 9.4 | RHEL 9.7 (BaseOS + AppStream) | Upgrade to 9.7 |
| RHEL 9.7 | RHEL 9.7 (BaseOS + AppStream) | Stay on 9.7 |
| RHEL 8.8 | RHEL 8.8 (BaseOS + AppStream) | Stay on 8.8 |

**Recommended:** Use RHEL 9.4 VM with RHEL 9.7 repository to test the upgrade scenario (minor version upgrade).

#### Option A: Single Repository (Simple - Recommended for First Test)

Use only RHEL 9.7 repo to test upgrade scenario:

```bash
# On test VM, create repo file for RHEL 9.7 only
cat > /etc/yum.repos.d/rhel-9.7-local.repo << 'EOF'
[BaseOS-9.7]
name=Red Hat Enterprise Linux 9.7 - BaseOS
baseurl=http://192.168.20.46/rhel-9.7/BaseOS/
enabled=1
gpgcheck=0
priority=1

[AppStream-9.7]
name=Red Hat Enterprise Linux 9.7 - AppStream
baseurl=http://192.168.20.46/rhel-9.7/AppStream/
enabled=1
gpgcheck=0
priority=1
EOF

# Clean cache
dnf clean all

# Test repository access
dnf repolist
```

Expected output should show:
```
repo id                                repo name
BaseOS-9.7                             Red Hat Enterprise Linux 9.7 - BaseOS
AppStream-9.7                          Red Hat Enterprise Linux 9.7 - AppStream
```

#### Option B: Multiple Repositories (Advanced - Both 9.4 and 9.7)

If you want to test with both RHEL 9.4 and 9.7 repos configured (like in production), you must use **unique repository IDs** to avoid conflicts:

```bash
# On test VM, create BOTH repo files with unique IDs
cat > /etc/yum.repos.d/local_rhel9.4.repo << 'EOF'
[BaseOS-9.4]
name=Red Hat Enterprise Linux 9.4 - BaseOS
metadata_expire=-1
gpgcheck=0
enabled=1
baseurl=http://192.168.20.46/rhel-9.4/BaseOS/
priority=99

[AppStream-9.4]
name=Red Hat Enterprise Linux 9.4 - AppStream
metadata_expire=-1
gpgcheck=0
enabled=1
baseurl=http://192.168.20.46/rhel-9.4/AppStream/
priority=99
EOF

cat > /etc/yum.repos.d/local_rhel9.7.repo << 'EOF'
[BaseOS-9.7]
name=Red Hat Enterprise Linux 9.7 - BaseOS
metadata_expire=-1
gpgcheck=0
enabled=1
baseurl=http://192.168.20.46/rhel-9.7/BaseOS/
priority=1

[AppStream-9.7]
name=Red Hat Enterprise Linux 9.7 - AppStream
metadata_expire=-1
gpgcheck=0
enabled=1
baseurl=http://192.168.20.46/rhel-9.7/AppStream/
priority=1
EOF

# Clean cache
dnf clean all

# Test repository access
dnf repolist
```

**Critical: Use UNIQUE repository IDs:**
- ✅ **Correct:** `[BaseOS-9.4]` and `[BaseOS-9.7]` (unique)
- ❌ **Wrong:** Both files using `[BaseOS]` (causes "Repository BaseOS is listed more than once" warning)

**Priority Settings:**
- `priority=1` = Higher priority (RHEL 9.7 preferred)
- `priority=99` = Lower priority (RHEL 9.4 fallback)

Expected output should show:
```
repo id                                repo name
BaseOS-9.4                             Red Hat Enterprise Linux 9.4 - BaseOS
AppStream-9.4                          Red Hat Enterprise Linux 9.4 - AppStream
BaseOS-9.7                             Red Hat Enterprise Linux 9.7 - BaseOS
AppStream-9.7                          Red Hat Enterprise Linux 9.7 - AppStream
```

**No warnings about duplicate repositories!**

**Verify package availability in repo:**

```bash
# Check available package versions
dnf list available --showduplicates --repo=BaseOS-9.7 | grep -E "^nginx|^bash|^openssl-libs|^curl"
dnf list available --showduplicates --repo=AppStream-9.7 | grep -E "^nginx|^bash|^openssl-libs|^curl"
```

**Note the package versions available** - you'll need these for `packages_to_patch.txt`

**Common Repository Setup Mistakes:**

❌ **Wrong:** Using RHEL 9.4 repo with packages_to_patch.txt listing 9.7 versions
✅ **Correct:** Match repo version with package versions in packages_to_patch.txt

❌ **Wrong:** Using generic package names (e.g., "nginx" instead of "nginx-1.28.2-1.el9.ngx.x86_64.rpm")
✅ **Correct:** Always use full package name with version, release, and architecture

❌ **Wrong:** Not verifying package exists in repo before adding to packages_to_patch.txt
✅ **Correct:** Always check availability first: `dnf info <package-version>`

### Step 3: Install Some Test Packages

```bash
# Install packages that you'll later patch
dnf install -y nginx bash openssl curl

# Verify installation
rpm -qa | grep -E "nginx|bash|openssl|curl"
```

### Step 4: Note Current Package Versions

```bash
# Save current versions for comparison
rpm -qa | grep -E "nginx|bash|openssl|curl" > /root/pre-patch-versions.txt
cat /root/pre-patch-versions.txt
```

---

## Phase 3: Configure Ansible Control Node

Your workstation is the Ansible control node. Let's verify it's ready.

### Step 1: Install Ansible

```bash
# On your workstation
cd /home/anik/ansible/wikilabs/aeon/rhel_patching

# Check Ansible version
ansible --version
# Should be 2.15 or higher
```

### Step 2: Update Inventory File

Edit `inventory` to add your test VMs:

```bash
vi inventory
```

Update the `[uat_servers]` section with your test VM:

```ini
[uat_servers]
192.168.8.61  # Your test VM IP address
```

### Step 3: Update packages_to_patch.txt

**First, check what versions are available in your RHEL 9.7 repo:**

```bash
# From test VM, find available package versions
ssh root@<test-vm-ip>

# Check RHEL 9.7 package versions
dnf list available --showduplicates --repo=BaseOS-9.7 --repo=AppStream-9.7 | grep -E "^nginx|^bash|^openssl-libs|^curl" | tail -20

# Example output:
# nginx.x86_64                    1:1.20.1-8.el9_2              BaseOS-9.7
# nginx.x86_64                    1:1.28.2-1.el9.ngx           BaseOS-9.7
# bash.x86_64                     5.1.8-6.el9_2                BaseOS-9.7
# bash.x86_64                     5.1.8-9.el9_4                BaseOS-9.7
```

**Update packages_to_patch.txt with available versions:**

Edit `packages_to_patch.txt`:

```bash
cd /home/anik/ansible/wikilabs/aeon/rhel_patching
vi packages_to_patch.txt
```

Use the exact versions from your repository check:

```txt
# Test patching - February 2026
# Testing with basic packages from RHEL 9.7 repo

# Web Server
nginx-1.28.2-1.el9.ngx.x86_64.rpm

# Security updates (use versions from your repo!)
bash-5.1.8-9.el9_4.x86_64.rpm
openssl-libs-3.0.7-27.el9_4.x86_64.rpm
curl-7.76.1-29.el9_4.x86_64.rpm
```

**Critical:** The package versions in `packages_to_patch.txt` **must exist** in your jump server repository!

**To verify package availability:**

```bash
# On test VM, check if specific package version exists
dnf info nginx-1.28.2-1.el9.ngx
```

### Step 4: Test Connectivity

```bash
# Test SSH access to test VM
ansible -i inventory uat_servers -m ping

# Expected output:
# 192.168.8.61 | SUCCESS => {
#     "changed": false,
#     "ping": "pong"
# }
```

---

## Phase 4: Run Integration Tests

### Step 1: Run Test Suite

```bash
cd /home/anik/ansible/wikilabs/aeon/rhel_patching

# Run integration tests
ansible-playbook tests/integration_test.yaml
```

Expected: All 8 tests should PASS

### Step 2: Dry Run Patching

```bash
# Check mode (dry-run)
ansible-playbook -i inventory master_patch.yaml -l uat_servers --check
```

This will:
- Detect OS
- Parse package list
- Show what would happen
- NOT make any changes

---

## Phase 5: First Patching Test

### Step 1: Run Patching on Test VM

```bash
cd /home/anik/ansible/wikilabs/aeon/rhel_patching

# Start patching
ansible-playbook -i inventory master_patch.yaml -l uat_servers
```

**What to Expect:**

1. **Display banner:**
```
==========================================
  RHEL PATCHING AUTOMATION
==========================================
Server: 192.168.8.61
IP: 192.168.8.61
OS: Red Hat Enterprise Linux 9.x
Kernel: 5.14.0-...
==========================================
```

2. **Show packages to patch:**
```
Packages to be patched: bash, openssl-libs, curl, nginx
```

3. **For each package:**
   - Show current version
   - Show target version
   - Prompt: `Install bash-5.1.8-9.el9_4.x86_64.rpm on 192.168.8.61? (yes/no)`
   - Type: `yes`

4. **Backup RPMs:**
   - Backs up old RPMs to `/var/lib/rpmbackup/`

5. **Install packages:**
   - Downloads from jump server
   - Installs updates

6. **Prompt for reboot:**
   - `Patching complete for 192.168.8.61. Reboot now? (yes/no)`
   - Type: `yes` (recommended for kernel updates)

7. **Save results:**
   - Creates JSON file in `patch_data/uat_2026-02-16/192.168.8.61.json`

### Step 2: Verify Patching

```bash
# SSH to test VM
ssh root@192.168.8.61

# Check package versions
rpm -qa | grep -E "nginx|bash|openssl|curl"

# Compare with pre-patch versions
cat /root/pre-patch-versions.txt

# Verify services are running
systemctl status nginx
```

---

## Phase 6: Generate Report

### Step 1: Generate HTML Report

```bash
cd /home/anik/ansible/wikilabs/aeon/rhel_patching

# Generate UAT report
ansible-playbook generate_report.yaml -e environment=uat
```

### Step 2: View Report

```bash
# Open report in browser
firefox reports/uat_patching_*.html
# or
xdg-open reports/uat_patching_*.html
```

**Report Should Show:**
- Hostname: 192.168.8.61
- Status: SUCCESS
- Packages patched: X
- Before/After versions for each package

---

## Troubleshooting Test Environment

### Issue: Duplicate Repository Warning

**Symptom:** `Repository BaseOS is listed more than once in the configuration`

**Cause:** Both repo files use identical repository IDs like `[BaseOS]` and `[AppStream]`

**Example Wrong Configuration:**
```ini
# local_rhel9.4.repo
[BaseOS]           # ❌ Duplicate ID!
baseurl=http://192.168.20.46/rhel-9.4/BaseOS/

# local_rhel9.7.repo
[BaseOS]           # ❌ Duplicate ID!
baseurl=http://192.168.20.46/rhel-9.7/BaseOS/
```

**Solution:** Use unique repository IDs with version suffix:

```bash
# Fix the repo files to use unique IDs
cat > /etc/yum.repos.d/local_rhel9.4.repo << 'EOF'
[BaseOS-9.4]       # ✅ Unique ID
name=Red Hat Enterprise Linux 9.4 - BaseOS
baseurl=http://192.168.20.46/rhel-9.4/BaseOS/
enabled=1
gpgcheck=0
priority=99

[AppStream-9.4]   # ✅ Unique ID
name=Red Hat Enterprise Linux 9.4 - AppStream
baseurl=http://192.168.20.46/rhel-9.4/AppStream/
enabled=1
gpgcheck=0
priority=99
EOF

cat > /etc/yum.repos.d/local_rhel9.7.repo << 'EOF'
[BaseOS-9.7]       # ✅ Unique ID
name=Red Hat Enterprise Linux 9.7 - BaseOS
baseurl=http://192.168.20.46/rhel-9.7/BaseOS/
enabled=1
gpgcheck=0
priority=1

[AppStream-9.7]   # ✅ Unique ID
name=Red Hat Enterprise Linux 9.7 - AppStream
baseurl=http://192.168.20.46/rhel-9.7/AppStream/
enabled=1
gpgcheck=0
priority=1
EOF

# Clean and verify
dnf clean all
dnf repolist

# Should show no warnings!
```

**Verification:**
```bash
# Should show 4 unique repos with NO warnings
dnf repolist
```

### Issue: Wrong Repository Being Used

**Symptom:** Packages installing from RHEL 9.4 instead of 9.7

**Solution:** Check which repo provides the package:

```bash
# Check which repository will provide a specific package
dnf repo-pkgs --repo BaseOS-9.7 --repo AppStream-9.7
dnf repo-pkgs --repo BaseOS-9.4 --repo AppStream-9.4

# Or check specific package info
dnf info nginx
# Look for "Repository" field in output

# Verify package from specific repo
dnf info --repo BaseOS-9.7 nginx
```

**Fix:** Adjust priority values if wrong repo is being used:
- Lower number = higher priority (e.g., `priority=1`)
- Higher number = lower priority (e.g., `priority=99`)

### Issue: Repository Not Accessible

**Symptom:** `Cannot download package`

**Solution:**
```bash
# From test VM, test HTTP access
curl http://192.168.20.46/rhel-9.7/BaseOS/

# Check DNS
nslookup 192.168.20.46

# Check firewall
firewall-cmd --list-all
```

### Issue: Package Not Found

**Symptom:** `Package not found in repository`

**Solution:**
```bash
# List what's in the repo
curl http://192.168.20.46/rhel-9.7/BaseOS/ | grep -i package

# Verify package name in packages_to_patch.txt matches exactly
```

### Issue: Permission Denied

**Symptom:** `Permission denied`

**Solution:**
```bash
# On test VM, ensure ansible user has sudo
echo "ansible ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Test from control node
ansible -i inventory uat_servers -m shell -a "whoami" -b
```

### Issue: SSH Connection Failed

**Symptom:** `SSH connection not reachable`

**Solution:**
```bash
# Test SSH manually
ssh root@192.168.8.61

# Check network
ping 192.168.8.61

# Check firewall on control node
sudo firewall-cmd --list-all
```

---

## Test Scenarios

### Scenario 1: Single Package Patch

```bash
# packages_to_patch.txt
bash-5.1.8-9.el9_4.x86_64.rpm

# Run patching
ansible-playbook -i inventory master_patch.yaml -l uat_servers
```

### Scenario 2: Multiple Packages

```bash
# packages_to_patch.txt
bash-5.1.8-9.el9_4.x86_64.rpm
openssl-libs-3.0.7-27.el9_4.x86_64.rpm
curl-7.76.1-29.el9_4.x86_64.rpm

# Run patching
ansible-playbook -i inventory master_patch.yaml -l uat_servers
```

### Scenario 3: Patch and Reboot

```bash
# Run patching (will prompt for reboot)
ansible-playbook -i inventory master_patch.yaml -l uat_servers

# When prompted, say YES to reboot
```

### Scenario 4: Rollback Test

```bash
# After patching, test rollback
ssh root@192.168.8.61

# Check backups
ls -lh /var/lib/rpmbackup/

# Rollback one package
cd /var/lib/rpmbackup/
rpm -Uvh --oldpackage bash-5.1.8-6.el9_2.x86_64.rpm

# Verify rollback
rpm -qa | grep bash

# Restart services if needed
systemctl restart nginx
```

---

## VM Network Configuration

### Option A: Bridged Network (Recommended)

**Jump Server:** 192.168.20.46
**Test VM:** 192.168.8.61

Both on same network as your workstation.

### Option B: NAT Network

**Jump Server:** 10.0.2.46
**Test VM:** 10.0.2.61

Configure port forwarding on hypervisor to forward SSH (port 22) to your workstation.

### Option C: Host-Only Network

**Jump Server:** 192.168.56.46
**Test VM:** 192.168.56.61

Isolated network - good for testing but requires Ansible on jump server or control node VM.

---

## Cleanup Test Environment

### After Testing:

```bash
# Delete test VM snapshots
# Shutdown test VMs when not in use

# Clean up patch data (optional)
rm -rf patch_data/uat_*/

# Clean up reports (optional)
rm -f reports/uat_patching_*.html
```

---

## Complete Working Example

**Scenario:** RHEL 9.4 test VM at 192.168.8.61, jump server at 192.168.20.46

### Step 1: Verify Jump Server Repositories

```bash
# From your workstation, test jump server HTTP
curl -I http://192.168.20.46/rhel-9.7/BaseOS/
curl -I http://192.168.20.46/rhel-9.7/AppStream/
# Should return: HTTP/1.1 200 OK or 403 Forbidden (both work)
```

### Step 2: Configure Test VM Repositories

```bash
# SSH to test VM
ssh root@192.168.8.61

# Backup existing repos (if any)
mkdir -p /root/yum.repos.d.backup
cp /etc/yum.repos.d/*.repo /root/yum.repos.d.backup/ 2>/dev/null

# Create RHEL 9.7 repository
cat > /etc/yum.repos.d/rhel-9.7-local.repo << 'EOF'
[BaseOS-9.7]
name=Red Hat Enterprise Linux 9.7 - BaseOS
baseurl=http://192.168.20.46/rhel-9.7/BaseOS/
enabled=1
gpgcheck=0
priority=1

[AppStream-9.7]
name=Red Hat Enterprise Linux 9.7 - AppStream
baseurl=http://192.168.20.46/rhel-9.7/AppStream/
enabled=1
gpgcheck=0
priority=1
EOF

# Clean and verify
dnf clean all
dnf repolist

# Expected output:
# repo id              repo name
# BaseOS-9.7           Red Hat Enterprise Linux 9.7 - BaseOS
# AppStream-9.7        Red Hat Enterprise Linux 9.7 - AppStream
```

### Step 3: Verify Package Availability

```bash
# Check what packages are available
dnf list available | grep -E "^nginx.x86_64|^bash.x86_64|^curl.x86_64" | tail -10

# Verify specific package versions exist
dnf info nginx-1.28.2-1.el9.ngx
dnf info bash-5.1.8-9.el9_5
dnf info curl-8.7.1-1.el9_5

# All should return "Available Packages" with version info
```

### Step 4: Update Control Node

```bash
# Exit test VM
exit

# On your workstation
cd /home/anik/ansible/wikilabs/aeon/rhel_patching

# Update inventory
cat > inventory << 'EOF'
[uat_servers]
192.168.8.61

[rhel_servers:vars]
ansible_user=root
ansible_become=true
ansible_become_method=sudo
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOF

# Test connectivity
ansible -i inventory uat_servers -m ping

# Expected: SUCCESS => "pong"
```

### Step 5: Run Patching Test

```bash
# Run integration tests (optional)
ansible-playbook tests/integration_test.yaml

# Dry-run patching
ansible-playbook -i inventory master_patch.yaml -l uat_servers --check

# Live patching
ansible-playbook -i inventory master_patch.yaml -l uat_servers

# Generate report
ansible-playbook generate_report.yaml -e environment=uat
```

---

## Pre-Test Checklist

- [ ] Jump server VM created and accessible
- [ ] Jump server has HTTP server running (nginx)
- [ ] Jump server has RHEL 8.8/9.4/9.7 repos
- [ ] Test VM created with RHEL 8 or 9
- [ ] Test VM has SSH access enabled
- [ ] Test VM can access jump server HTTP
- [ ] Repository configured on test VM
- [ ] Test packages installed on test VM
- [ ] Ansible can ping test VM
- [ ] Integration tests passing (8/8)
- [ ] packages_to_patch.txt updated with available packages

---

## RHEL 9.4 → 9.7 Upgrade Quick Reference

**Scenario:** You have RHEL 9.4 VM and want to test upgrading to RHEL 9.7 packages.

### Prerequisites

- Jump server at 192.168.20.46 with RHEL 9.7 repos configured
- Test VM (RHEL 9.4) at 192.168.8.61
- Network connectivity between all systems

### Step-by-Step

```bash
# 1. SSH to test VM
ssh root@192.168.8.61

# 2. Create RHEL 9.7 repository configuration
cat > /etc/yum.repos.d/rhel-9.7-local.repo << 'EOF'
[BaseOS-9.7]
name=Red Hat Enterprise Linux 9.7 - BaseOS
baseurl=http://192.168.20.46/rhel-9.7/BaseOS/
enabled=1
gpgcheck=0
priority=1

[AppStream-9.7]
name=Red Hat Enterprise Linux 9.7 - AppStream
baseurl=http://192.168.20.46/rhel-9.7/AppStream/
enabled=1
gpgcheck=0
priority=1
EOF

# OR, if you have both 9.4 and 9.7 repos, use unique IDs:
cat > /etc/yum.repos.d/local_rhel9.4.repo << 'EOF'
[BaseOS-9.4]
name=Red Hat Enterprise Linux 9.4 - BaseOS
baseurl=http://192.168.20.46/rhel-9.4/BaseOS/
enabled=1
gpgcheck=0
priority=99

[AppStream-9.4]
name=Red Hat Enterprise Linux 9.4 - AppStream
baseurl=http://192.168.20.46/rhel-9.4/AppStream/
enabled=1
gpgcheck=0
priority=99
EOF

cat > /etc/yum.repos.d/local_rhel9.7.repo << 'EOF'
[BaseOS-9.7]
name=Red Hat Enterprise Linux 9.7 - BaseOS
baseurl=http://192.168.20.46/rhel-9.7/BaseOS/
enabled=1
gpgcheck=0
priority=1

[AppStream-9.7]
name=Red Hat Enterprise Linux 9.7 - AppStream
baseurl=http://192.168.20.46/rhel-9.7/AppStream/
enabled=1
gpgcheck=0
priority=1
EOF

# 3. Clean DNF cache and verify
dnf clean all
dnf repolist

# Expected: Should show 4 repos with unique IDs (no duplicate warnings!)
# BaseOS-9.4, AppStream-9.4, BaseOS-9.7, AppStream-9.7

# 4. Check available package versions (note these!)
dnf list available --showduplicates --repo=BaseOS-9.7 --repo=AppStream-9.7 | grep -E "^nginx|^bash|^openssl-libs|^curl"

# 5. Install older versions first (for testing upgrade scenario)
dnf install -y nginx bash curl openssl-libs

# 6. Save current versions
rpm -qa | grep -E "nginx|bash|openssl|curl" > /root/pre-patch-versions.txt
cat /root/pre-patch-versions.txt

# 7. Exit test VM
exit
```

### Update Control Node

```bash
# On your workstation
cd /home/anik/ansible/wikilabs/aeon/rhel_patching

# 8. Update packages_to_patch.txt with RHEL 9.7 versions from step 4
vi packages_to_patch.txt

# 9. Run integration tests
ansible-playbook tests/integration_test.yaml

# 10. Test connectivity
ansible -i inventory uat_servers -m ping

# 11. Dry-run patching
ansible-playbook -i inventory master_patch.yaml -l uat_servers --check

# 12. Live patching
ansible-playbook -i inventory master_patch.yaml -l uat_servers

# 13. Generate report
ansible-playbook generate_report.yaml -e environment=uat
```

### What to Expect

- Packages will upgrade from RHEL 9.4 versions to RHEL 9.7 versions
- System will upgrade from RHEL 9.4 to RHEL 9.7
- Old RPMs backed up to `/var/lib/rpmbackup/` on test VM
- JSON results saved to `patch_data/uat_2026-02-16/192.168.8.61.json`
- HTML report generated at `reports/uat_patching_*.html`

---

## Quick Start Commands

```bash
# 1. Test connectivity
ansible -i inventory uat_servers -m ping

# 2. Verify repo access from test VM
ssh root@192.168.8.61 "dnf repolist"

# 3. Run integration tests
ansible-playbook tests/integration_test.yaml

# 4. Dry-run patching
ansible-playbook -i inventory master_patch.yaml -l uat_servers --check

# 5. Live patching
ansible-playbook -i inventory master_patch.yaml -l uat_servers

# 6. Generate report
ansible-playbook generate_report.yaml -e environment=uat
```

---

## Next Steps After Successful Test

1. **Document Results:** Note any issues encountered
2. **Refine Playbooks:** Adjust based on test results
3. **Prepare DR Environment:** Repeat for DR test VMs
4. **Prepare Production:** Document production deployment process
5. **Train Team:** Share workflow scripts with team members

---

## Support

**Documentation:**
- [README.md](README.md) - Main usage guide
- [ROLLBACK.md](ROLLBACK.md) - Rollback procedures

**Test Commands:**
```bash
# Quick connectivity test
ansible -i inventory uat_servers -m ping

# Full patching test
./scripts/patch_uat.sh
```
