# RHEL Patching Rollback Procedures

## Overview

This document provides comprehensive rollback procedures for the RHEL Patching Automation system. The patching role automatically creates backups of all RPM packages before installing updates, ensuring that you can quickly recover from patching issues.

### Automatic Backup Location

All RPM packages are automatically backed up to **`/var/lib/rpmbackup/`** on each target host during the patching process. The backup occurs **before** any package updates are installed.

**Backup Process:**
1. The patching role queries the currently installed version of each package
2. RPM files are copied from `/var/lib/rpm` to `/var/lib/rpmbackup/`
3. New package versions are then installed from the jump server repository
4. Backup status is recorded in the patching results JSON

**Important Notes:**
- Backups are stored locally on each patched host
- Backup directory: `/var/lib/rpmbackup/`
- Backups include the complete RPM filename with version and architecture
- Multiple patching sessions will overwrite previous backups (plan accordingly)

---

## Manual Rollback Process

### Prerequisites

Before performing a rollback, ensure you have:
- Root or sudo access to the target host
- Access to the backup directory `/var/lib/rpmbackup/`
- List of packages that need to be rolled back
- Understanding of service dependencies

### Step-by-Step Rollback Procedure

#### Step 1: Identify Current Package Version

Determine the currently installed version of the package you need to rollback:

```bash
# Query current package version
rpm -qa | grep nginx

# Example output:
# nginx-1.22.1-1.el9_2.3.x86_64
```

#### Step 2: Check Available Backups

Verify that the backup RPM exists in the backup directory:

```bash
# List all backed up RPMs
ls -lh /var/lib/rpmbackup/

# Check for specific package
ls -lh /var/lib/rpmbackup/ | grep nginx

# Example output:
# -rw-r--r--. 1 root root 1.2M Feb 16 10:30 nginx-1.20.1-8.el9_2.x86_64.rpm
```

#### Step 3: Review Package Dependencies

Check if other packages depend on the package you're rolling back:

```bash
# Check what requires this package
rpm -qR nginx-1.22.1-1.el9_2.3.x86_64 | grep requires

# Check what this package requires
rpm -qR nginx-1.22.1-1.el9_2.3.x86_64 | grep rpmlib
```

#### Step 4: Perform the Rollback

Use the `--oldpackage` flag to downgrade to the backed-up version:

```bash
# Navigate to backup directory
cd /var/lib/rpmbackup/

# Rollback to old version
sudo rpm -Uvh --oldpackage nginx-1.20.1-8.el9_2.x86_64.rpm

# Example output:
# Preparing...                          ################# [100%]
# Updating / installing...
#    1:nginx-1.20.1-8.el9_2.x86_64     ################# [100%]
```

**Important Parameters:**
- `-Uvh`: Upgrade (or downgrade with --oldpackage) in verbose mode with hash marks
- `--oldpackage`: Allows downgrading to an older package version
- Use full RPM filename with version and architecture

#### Step 5: Verify the Rollback

Confirm that the rollback was successful:

```bash
# Verify the package version
rpm -qa | grep nginx

# Expected output (example):
# nginx-1.20.1-8.el9_2.x86_64
```

#### Step 6: Restart Affected Services

Restart any services that were using the rolled-back package:

```bash
# Check if service is running
sudo systemctl status nginx

# Restart the service
sudo systemctl restart nginx

# Verify service is healthy
sudo systemctl status nginx

# Check service logs if needed
sudo journalctl -u nginx -n 50 --no-pager
```

---

## Complete Rollout Rollback

### Scenario: Rollback Multiple Packages

When you need to rollback an entire patching session (multiple packages), follow this systematic approach:

#### Option 1: Manual Sequential Rollback

```bash
# 1. Get list of all currently installed packages
rpm -qa | sort > /tmp/current_packages.txt

# 2. Check available backups
ls -lh /var/lib/rpmbackup/

# 3. Rollback each package in dependency order
# Example: Rollback nginx and its dependencies
cd /var/lib/rpmbackup/

sudo rpm -Uvh --oldpackage nginx-1.20.1-8.el9_2.x86_64.rpm
sudo rpm -Uvh --oldpackage openssl-1.1.1k-6.el9_2.x86_64.rpm
sudo rpm -Uvh --oldpackage pcre2-10.40-3.el9.x86_64.rpm

# 4. Verify all rollbacks
rpm -qa | grep -E 'nginx|openssl|pcre2'
```

#### Option 2: Automated Rollback Script

Create a script to rollback all packages from the backup directory:

```bash
#!/bin/bash
# Complete rollback script - rollback_all.sh
# Usage: sudo ./rollback_all.sh

set -e

BACKUP_DIR="/var/lib/rpmbackup"
LOG_FILE="/tmp/rollback_$(date +%Y%m%d_%H%M%S).log"

echo "Starting rollback at $(date)" | tee -a "$LOG_FILE"
echo "Backup directory: $BACKUP_DIR" | tee -a "$LOG_FILE"
echo "==========================================" | tee -a "$LOG_FILE"

# Check if backup directory exists
if [ ! -d "$BACKUP_DIR" ]; then
    echo "ERROR: Backup directory $BACKUP_DIR does not exist!" | tee -a "$LOG_FILE"
    exit 1
fi

# Check if there are any RPMs to rollback
if [ -z "$(ls -A $BACKUP_DIR/*.rpm 2>/dev/null)" ]; then
    echo "ERROR: No RPM files found in $BACKUP_DIR" | tee -a "$LOG_FILE"
    exit 1
fi

# Record current state
echo "Recording current package state..." | tee -a "$LOG_FILE"
rpm -qa | sort > /tmp/before_rollback.txt

# Rollback each package
for rpm_file in "$BACKUP_DIR"/*.rpm; do
    if [ -f "$rpm_file" ]; then
        package_name=$(basename "$rpm_file" | sed 's/-[0-9].*//')
        echo "Rolling back: $package_name" | tee -a "$LOG_FILE"

        # Perform rollback
        if sudo rpm -Uvh --oldpackage "$rpm_file" >> "$LOG_FILE" 2>&1; then
            echo "SUCCESS: $package_name rolled back" | tee -a "$LOG_FILE"
        else
            echo "WARNING: Failed to rollback $package_name (check $LOG_FILE)" | tee -a "$LOG_FILE"
        fi
    fi
done

echo "==========================================" | tee -a "$LOG_FILE"
echo "Rollback completed at $(date)" | tee -a "$LOG_FILE"

# Show final state
echo "Final package state:" | tee -a "$LOG_FILE"
rpm -qa | sort > /tmp/after_rollback.txt
diff /tmp/before_rollback.txt /tmp/after_rollback.txt || true

echo "Rollback log saved to: $LOG_FILE"
```

**Usage:**

```bash
# Save the script
cat > /tmp/rollback_all.sh << 'EOF'
# [Paste the script content from above]
EOF

# Make it executable
chmod +x /tmp/rollback_all.sh

# Run the rollback
sudo /tmp/rollback_all.sh
```

---

## Automated Rollback Script Generation

### Generate Rollback Script from Patching Results

The patching system creates a JSON results file. You can use this to generate an automated rollback script:

```bash
#!/bin/bash
# generate_rollback.sh - Generate rollback script from patching results
# Usage: ./generate_rollback.sh <results_json_file>

RESULTS_FILE="$1"

if [ -z "$RESULTS_FILE" ]; then
    echo "Usage: $0 <patching_results.json>"
    exit 1
fi

if [ ! -f "$RESULTS_FILE" ]; then
    echo "ERROR: Results file not found: $RESULTS_FILE"
    exit 1
fi

# Parse JSON and generate rollback script
OUTPUT_SCRIPT="rollback_$(date +%Y%m%d_%H%M%S).sh"

echo "#!/bin/bash" > "$OUTPUT_SCRIPT"
echo "# Auto-generated rollback script" >> "$OUTPUT_SCRIPT"
echo "# Generated from: $RESULTS_FILE" >> "$OUTPUT_SCRIPT"
echo "# Date: $(date)" >> "$OUTPUT_SCRIPT"
echo "" >> "$OUTPUT_SCRIPT"
echo "set -e" >> "$OUTPUT_SCRIPT"
echo "" >> "$OUTPUT_SCRIPT"
echo "BACKUP_DIR=\"/var/lib/rpmbackup\"" >> "$OUTPUT_SCRIPT"
echo "" >> "$OUTPUT_SCRIPT"
echo "echo 'Starting rollback of packages...'" >> "$OUTPUT_SCRIPT"
echo "" >> "$OUTPUT_SCRIPT"

# Extract package information using jq (if available)
if command -v jq &> /dev/null; then
    jq -r '.patches[] | select(.status == "installed") |
        "sudo rpm -Uvh --oldpackage \${BACKUP_DIR}/\(.name)-\(.current_version).\(.architecture).rpm"' \
        "$RESULTS_FILE" >> "$OUTPUT_SCRIPT"
else
    echo "WARNING: jq not found. Please install jq to parse JSON properly."
    echo "Falling back to manual extraction..."
    grep -oP '"name":"\K[^"]+' "$RESULTS_FILE" | while read pkg; do
        echo "echo 'Rolling back: $pkg'" >> "$OUTPUT_SCRIPT"
        echo "sudo rpm -Uvh --oldpackage \${BACKUP_DIR}/${pkg}-*.rpm || true" >> "$OUTPUT_SCRIPT"
    done
fi

echo "" >> "$OUTPUT_SCRIPT"
echo "echo 'Rollback complete. Verifying...'" >> "$OUTPUT_SCRIPT"
echo "rpm -qa | sort" >> "$OUTPUT_SCRIPT"

chmod +x "$OUTPUT_SCRIPT"

echo "Rollback script generated: $OUTPUT_SCRIPT"
echo "Copy this script to the target host and run with sudo"
```

---

## Verification After Rollback

### Comprehensive Verification Checklist

After performing a rollback, verify the following:

#### 1. Package Version Verification

```bash
# Verify rolled back packages
for pkg in nginx openssl pcre2; do
    echo "=== $pkg ==="
    rpm -qa | grep $pkg
done

# Detailed package information
rpm -qi nginx
```

#### 2. Service Health Check

```bash
# Check all services status
sudo systemctl status nginx
sudo systemctl status httpd
sudo systemctl status mysql

# Check if services are listening
sudo netstat -tlnp | grep -E ':(80|443|3306)'
# or
sudo ss -tlnp | grep -E ':(80|443|3306)'

# Check service logs
sudo journalctl -xe -n 100 --no-pager
```

#### 3. Application Functionality Test

```bash
# Test web server (example)
curl -I http://localhost
curl -I https://localhost

# Check application logs
tail -f /var/log/nginx/error.log
tail -f /var/log/httpd/error_log

# Test database connectivity
mysql -u root -p -e "SELECT VERSION();"
```

#### 4. System Integrity Check

```bash
# Verify RPM database consistency
sudo rpm --rebuilddb

# Check for broken dependencies
sudo rpm -Va

# Check if all required packages are installed
rpm -qa | sort > /tmp/current_after_rollback.txt
diff /tmp/before_rollback.txt /tmp/current_after_rollback.txt
```

#### 5. Performance and Resource Check

```bash
# Check system resources
top -bn1 | head -20
free -h
df -h

# Check for unusual processes
ps auxf | grep -E 'nginx|httpd|mysql'
```

---

## Escalation Procedures

### When Rollback Fails or Issues Persist

If the rollback procedure fails or issues persist after rollback, follow this escalation path:

#### Level 1: Immediate Actions (0-15 minutes)

1. **Stop Affected Services**
   ```bash
   sudo systemctl stop nginx
   sudo systemctl stop httpd
   ```

2. **Document Current State**
   ```bash
   # Save system state
   rpm -qa | sort > /tmp/emergency_packages.txt
   sudo journalctl -xe > /tmp/emergency_logs.txt
   df -h > /tmp/emergency_disk.txt
   ```

3. **Notify Team**
   - Send alert to on-call team
   - Post in designated communication channel
   - Include: host, packages attempted, error messages

#### Level 2: Advanced Recovery (15-60 minutes)

1. **Alternative Rollback Methods**
   ```bash
   # Try using dnf history
   sudo dnf history list
   sudo dnf history undo <transaction_id>

   # If backup RPMs are corrupted, try retrieving from repository
   sudo dnf --showduplicates list nginx
   sudo dnf install nginx-1.20.1-8.el9_2
   ```

2. **Boot into Rescue Mode**
   - Boot from RHEL installation media
   - Select "Rescue installed system"
   - Mount filesystems
   - Manually install backup RPMs

3. **Restore from Snapshot (if available)**
   ```bash
   # LVM snapshots
   sudo lvconvert --merge /dev/vg00/lv_snapshot

   # Btrfs snapshots
   sudo btrfs subvolume snapshot rollback /
   ```

#### Level 3: Escalation (60+ minutes)

1. **Engage Senior Engineering**
   - Database administrator (if database issues)
   - Senior system administrator
   - Application owner

2. **Consider Fresh Installation**
   - Spin up new instance
   - Restore application data from backup
   - Cutover traffic

3. **Vendor Support**
   - Red Hat support: 1-800-RED-HAT1
   - Have case reference number ready
   - Include sosreport output

### Creating an sosreport for Vendor Support

```bash
# Generate sosreport for Red Hat support
sudo sosreport --batch --tmp-dir /tmp

# The report will be created in /tmp/sosreport-*.tar.xz
# Upload this to Red Hat support portal
```

### Emergency Contact Information

Fill in your organization's contacts:

| Role | Name | Contact | Hours |
|------|------|---------|-------|
| On-Call System Admin | [Name] | [Phone/Email] | 24/7 |
| Senior Engineer | [Name] | [Phone/Email] | Business Hours |
| Application Owner | [Name] | [Phone/Email] | Business Hours |
| Red Hat Support | 1-800-RED-HAT1 | portal.redhat.com | 24/7 |

---

## Best Practices

### Before Patching

1. **Always verify backup directory exists**: `ls -ld /var/lib/rpmbackup`
2. **Test patching in non-production first**
3. **Schedule patching during maintenance windows**
4. **Have rollback plan documented and approved**
5. **Ensure backups of application data are current**

### During Patching

1. **Monitor patching in real-time**: Watch the Ansible output
2. **Keep logs for reference**: Save patching results JSON
3. **Document any issues**: Note any warnings or errors
4. **Don't patch everything at once**: Stagger patching if possible

### After Patching

1. **Verify immediately**: Don't wait to test applications
2. **Monitor for 24-48 hours**: Some issues may not appear immediately
3. **Document lessons learned**: Update procedures based on experience
4. **Archive patching results**: Keep for audit trail

---

## Troubleshooting

### Common Issues and Solutions

#### Issue 1: Dependency Errors During Rollback

**Error Message:**
```
error: Failed dependencies:
    libxxx.so.1()(64bit) is needed by package-2.0.0-1.el9.x86_64
```

**Solution:**
```bash
# Rollback in dependency order (dependencies first)
# Identify dependencies
rpm -qR package-name | grep requires

# Rollback dependencies first, then the main package
sudo rpm -Uvh --oldpackage dependency-package-1.0-1.el9.x86_64.rpm
sudo rpm -Uvh --oldpackage main-package-1.0-1.el9.x86_64.rpm
```

#### Issue 2: Backup RPM Not Found

**Error Message:**
```
error: open of /var/lib/rpmbackup/package-1.0-1.el9.x86_64.rpm failed: No such file or directory
```

**Solution:**
```bash
# Check if backup exists
ls -lh /var/lib/rpmbackup/

# If backup is missing, try dnf history
sudo dnf history list
sudo dnf history undo <transaction_id>

# Or reinstall specific version from repository
sudo dnf --showduplicates list package-name
sudo dnf install package-name-version-release
```

#### Issue 3: Service Won't Start After Rollback

**Solution:**
```bash
# Check service status for errors
sudo systemctl status service-name
sudo journalctl -xe -u service-name -n 100

# Check configuration files (rollback doesn't revert config changes)
sudo diff /etc/service/service.conf.rpmsave /etc/service/service.conf

# Restore old configuration if needed
sudo mv /etc/service/service.conf.rpmsave /etc/service/service.conf
sudo systemctl restart service-name
```

#### Issue 4: RPM Database Corruption

**Error Message:**
```
error: rpmdb: BDB0113 Thread/process 123456 failed: Berkeley DB library version mismatch
```

**Solution:**
```bash
# Rebuild RPM database
sudo cd /var/lib
sudo mkdir rpmbackup_db
sudo cp -r rpm rpmbackup_db/
sudo rm rpm/__db*
sudo rpm --rebuilddb

# Verify
sudo rpm -qa | head
```

---

## Appendix

### Quick Reference Card

```bash
# Check current version
rpm -qa | grep package-name

# List backups
ls -lh /var/lib/rpmbackup/

# Rollback single package
sudo rpm -Uvh --oldpackage /var/lib/rpmbackup/package-version-arch.rpm

# Verify rollback
rpm -qa | grep package-name

# Restart service
sudo systemctl restart service-name

# Check service status
sudo systemctl status service-name
```

### Useful RPM Commands

```bash
# Query package information
rpm -qi package-name

# List package files
rpm -ql package-name

# Check package dependencies
rpm -qR package-name

# Verify package installation
rpm -V package-name

# Find what package provides a file
rpm -qf /path/to/file

# List all installed packages
rpm -qa | sort
```

### File Locations

- **Backup directory**: `/var/lib/rpmbackup/`
- **RPM database**: `/var/lib/rpm/`
- **Package configurations**: `/etc/package-name/`
- **Service logs**: `/var/log/package-name/`
- **System logs**: `/var/log/messages`, `/var/log/dmesg`

---

## Document Information

- **Version**: 1.0
- **Last Updated**: 2025-02-16
- **Maintained By**: System Administration Team
- **Related Documents**:
  - [README.md](../README.md) - Main project documentation
  - [Implementation Plan](../plans/implementation_plan.md) - Complete implementation details
  - [Patching Procedures](./PATCHING.md) - How to perform patching (if exists)

### Change Log

| Date | Version | Changes | Author |
|------|---------|---------|--------|
| 2025-02-16 | 1.0 | Initial document creation | Automation Team |

---

## Support and Feedback

For questions, issues, or suggestions regarding these rollback procedures:

1. Check the troubleshooting section above
2. Contact your system administration team
3. Review patching logs in the output files
4. Open an issue in the project repository

**Remember**: The best rollback is the one you never need. Always test in non-production environments first!
