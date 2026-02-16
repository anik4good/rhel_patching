# RHEL Patching Automation System

## Overview

The RHEL Patching Automation System is a comprehensive Ansible-based solution for automated patching of Red Hat Enterprise Linux 8 and 9 servers. This system provides OS-aware patching, CVE-specific updates, phased rollout capabilities, interactive prompts, automatic backups, and detailed HTML reporting.

**Key Features:**

- OS-Aware Patching: Automatically detects RHEL 8 or 9 and applies appropriate patches
- Phased Rollout: Three-phase deployment strategy (UAT → DR → Production)
- CVE-Specific Patching: Target security vulnerabilities with precision
- Interactive Prompts: Safety confirmations before critical operations
- Automatic Backups: All RPMs backed up before installation to `/var/lib/rpmbackup/`
- HTML Reports: Comprehensive patching reports with statistics and details
- Jump Server Integration: Patch packages hosted on centralized repository
- JSON Results: Structured output for integration with monitoring systems
- Rollback Support: Quick recovery procedures documented in `docs/ROLLBACK.md`

---

## Prerequisites

### Control Node Requirements

- **Ansible**: Version 2.15 or higher
  ```bash
  ansible --version
  ```
- **Python**: Python 3.9 or higher
- **SSH Access**: Key-based authentication to target hosts
- **Network Connectivity**: Access to jump server repository and target hosts

### Target Host Requirements

- **Operating System**: RHEL 8 or RHEL 9
- **SSH Access**: Configured for Ansible control node
- **Sudo Access**: Root or sudo privileges for package installation
- **Subscription**: Valid Red Hat subscription enabled
  ```bash
  sudo subscription-manager status
  ```
- **Disk Space**: Minimum 2 GB free in `/var` for backups
- **Jump Server Access**: Connectivity to jump server repository (if using remote repos)

### Repository Setup

Jump server should host RPM packages in the following structure:

```
/var/www/html/repos/
  rhel8/
    x86_64/
      Packages/
        nginx-1.26.3-1.el8.ngx.x86_64.rpm
        curl-8.2.1-3.el8_10.x86_64.rpm
        ...
  rhel9/
    x86_64/
      Packages/
        nginx-1.28.2-1.el9.ngx.x86_64.rpm
        curl-8.7.1-1.el9_5.x86_64.rpm
        ...
```

Repository should be accessible via HTTP/HTTPS from target hosts.

---

## Quick Start Guide

Get started with RHEL patching in 5 simple steps:

### Step 1: Update Inventory

Edit the `inventory` file to add your RHEL servers:

```bash
vi /home/anik/ansible/wikilabs/aeon/rhel_patching/inventory
```

Add your servers to the appropriate environment groups:

```ini
[uat_servers]
uat-rhel8-01.example.com ansible_host=192.168.1.10
uat-rhel9-01.example.com ansible_host=192.168.1.11

[dr_servers]
dr-rhel8-01.example.com ansible_host=192.168.2.10
dr-rhel9-01.example.com ansible_host=192.168.2.11

[prod_servers]
prod-rhel8-01.example.com ansible_host=192.168.3.10
prod-rhel9-01.example.com ansible_host=192.168.3.11
```

### Step 2: Test Connectivity

Verify Ansible can reach your target hosts:

```bash
# Test UAT environment
ansible -i inventory uat_servers -m ping

# Test DR environment
ansible -i inventory dr_servers -m ping

# Test Production environment
ansible -i inventory prod_servers -m ping
```

### Step 3: Update Package List

Edit `packages_to_patch.txt` to specify which RPMs to patch:

```bash
vi /home/anik/ansible/wikilabs/aeon/rhel_patching/packages_to_patch.txt
```

Format: `package-name-version-release.architecture.rpm`

```txt
# RHEL 9 packages
nginx-1.28.2-1.el9.ngx.x86_64.rpm
curl-8.7.1-1.el9_5.x86_64.rpm
openssl-libs-3.2.2-1.el9.x86_64.rpm

# RHEL 8 packages
nginx-1.26.3-1.el8.ngx.x86_64.rpm
curl-8.2.1-3.el8_10.x86_64.rpm
openssl-libs-1.1.1k-12.el8_10.x86_64.rpm
```

### Step 4: Run Patching (UAT First)

Execute the master patching playbook:

```bash
# Patch UAT environment
cd /home/anik/ansible/wikilabs/aeon/rhel_patching
ansible-playbook -i inventory master_patch.yaml -l uat_servers
```

The playbook will:
1. Display patching information banner
2. Parse package list
3. Prompt for confirmation
4. Back up current RPMs
5. Install updates from jump server
6. Save results to `patch_data/` directory

### Step 5: Review Report

Generate and review the HTML report:

```bash
# Generate UAT report
ansible-playbook generate_report.yaml -e environment=uat

# Open report in browser
firefox reports/uat_patching_$(date +%Y-%m-%d).html
# or
xdg-open reports/uat_patching_$(date +%Y-%m-%d).html
```

### Step 6: Repeat for DR and Production

After verifying UAT results:

```bash
# Week 2: Patch DR environment
ansible-playbook -i inventory master_patch.yaml -l dr_servers
ansible-playbook generate_report.yaml -e environment=dr

# Week 3: Patch Production environment
ansible-playbook -i inventory master_patch.yaml -l prod_servers
ansible-playbook generate_report.yaml -e environment=prod
```

---

## Usage Examples

### Environment-Specific Patching

```bash
# Patch UAT environment
ansible-playbook -i inventory master_patch.yaml -l uat_servers

# Patch DR environment
ansible-playbook -i inventory master_patch.yaml -l dr_servers

# Patch Production environment
ansible-playbook -i inventory master_patch.yaml -l prod_servers
```

### Single Host Testing

Test patching on a single host before full deployment:

```bash
# Patch specific UAT server
ansible-playbook -i inventory master_patch.yaml \
  -l uat_servers \
  --limit uat-rhel9-01.example.com
```

### Report Generation

```bash
# Generate UAT report
ansible-playbook generate_report.yaml -e environment=uat

# Generate DR report
ansible-playbook generate_report.yaml -e environment=dr

# Generate Production report
ansible-playbook generate_report.yaml -e environment=prod
```

### Quick Rollback

If patching causes issues, quickly rollback to previous version:

```bash
# SSH to affected host
ssh uat-rhel9-01.example.com

# Navigate to backup directory
cd /var/lib/rpmbackup/

# List backed up packages
ls -lh

# Rollback specific package
sudo rpm -Uvh --oldpackage nginx-1.20.1-8.el9_2.x86_64.rpm

# Restart affected service
sudo systemctl restart nginx

# Verify rollback
rpm -qa | grep nginx
```

For comprehensive rollback procedures, see `docs/ROLLBACK.md`.

### Dry Run Mode

Preview what would be patched without making changes:

```bash
# Check connectivity and OS detection
ansible -i inventory uat_servers -m setup \
  -a "filter=ansible_distribution*"

# Verify package file parsing
python3 library/package_parser.py packages_to_patch.txt
```

---

## Directory Structure

```
rhel_patching/
├── README.md                          # This file
├── ansible.cfg                        # Ansible configuration
├── inventory                          # Target host inventory
├── master_patch.yaml                  # Main patching playbook
├── generate_report.yaml               # HTML report generator
├── packages_to_patch.txt              # List of RPMs to patch
│
├── docs/                              # Documentation
│   ├── ROLLBACK.md                    # Rollback procedures
│   └── plans/                         # Implementation plans
│
├── library/                           # Custom Ansible modules
│   └── package_parser.py              # Package list parser
│
├── roles/                             # Ansible roles
│   └── rhel_patching/                 # Main patching role
│       ├── defaults/
│       │   └── main.yml               # Role variables
│       └── tasks/
│           ├── main.yml               # Role entry point
│           ├── rhel8.yml              # RHEL 8 tasks
│           ├── rhel9.yml              # RHEL 9 tasks
│           └── process_package.yml    # Package installation logic
│
├── templates/                         # Jinja2 templates
│   ├── html_report_template.j2        # HTML report v1
│   └── html_report_template_v2.j2     # HTML report v2 (current)
│
├── patch_data/                        # JSON results (created at runtime)
│   ├── uat_hostname_9_2025-02-16.json
│   ├── dr_hostname_8_2025-02-16.json
│   └── prod_hostname_9_2025-02-16.json
│
└── reports/                           # HTML reports (created at runtime)
    ├── uat_patching_2025-02-16.html
    ├── dr_patching_2025-02-16.html
    └── prod_patching_2025-02-16.html
```

---

## Rollback Procedures

Comprehensive rollback procedures are documented in `docs/ROLLBACK.md`.

### Quick Rollback Steps

1. **Identify Problem Package**
   ```bash
   rpm -qa | grep nginx
   ```

2. **Check Available Backups**
   ```bash
   ls -lh /var/lib/rpmbackup/
   ```

3. **Perform Rollback**
   ```bash
   cd /var/lib/rpmbackup/
   sudo rpm -Uvh --oldpackage nginx-1.20.1-8.el9_2.x86_64.rpm
   ```

4. **Restart Service**
   ```bash
   sudo systemctl restart nginx
   sudo systemctl status nginx
   ```

5. **Verify Rollback**
   ```bash
   rpm -qa | grep nginx
   ```

For detailed rollback scenarios, troubleshooting, and automated rollback scripts, see:
```bash
cat docs/ROLLBACK.md
```

---

## Troubleshooting

### Issue: Repository Not Accessible

**Symptom**: Playbook fails with "Cannot download package" error

**Solution**:
```bash
# Test repository access from target host
ssh uat-rhel9-01.example.com
curl -I http://jump-server.example.com/repos/rhel9/x86_64/

# Check DNS resolution
nslookup jump-server.example.com

# Verify repository exists
ls -lh /var/www/html/repos/rhel9/x86_64/Packages/

# Test with curl
curl http://jump-server.example.com/repos/rhel9/x86_64/Packages/nginx-1.28.2-1.el9.ngx.x86_64.rpm
```

### Issue: Package Not Found

**Symptom**: Playbook fails with "Package not found in repository" error

**Solution**:
```bash
# Verify package exists in repository
ssh jump-server
find /var/www/html/repos -name "nginx-*.rpm"

# Check package name in packages_to_patch.txt
cat packages_to_patch.txt | grep nginx

# Verify architecture matches
uname -m  # Should show x86_64

# List available packages in repo
ls /var/www/html/repos/rhel9/x86_64/Packages/ | grep nginx
```

### Issue: Permission Denied

**Symptom**: Playbook fails with "Permission denied" error

**Solution**:
```bash
# Test sudo access on target host
ssh uat-rhel9-01.example.com
sudo -v
sudo ls /root

# Check sudoers configuration
sudo visudo

# Ensure ansible user has sudo privileges
ansible ALL=(ALL) NOPASSWD: ALL

# Test with Ansible
ansible -i inventory uat_servers -m shell -a "whoami" -b
```

### Issue: SSH Connection Failed

**Symptom**: "SSH connection not reachable" error

**Solution**:
```bash
# Test SSH connectivity
ssh ansible@uat-rhel9-01.example.com

# Check SSH key permissions
ls -lh ~/.ssh/id_rsa*

# Test with Ansible ping
ansible -i inventory uat_servers -m ping -vvv

# Check firewall rules
sudo firewall-cmd --list-all

# Verify SELinux context
ls -Z ~/.ssh/
```

### Issue: JSON Parsing Error

**Symptom**: Report generation fails with JSON parsing error

**Solution**:
```bash
# Validate JSON files in patch_data/
python3 -m json.tool patch_data/uat_*.json

# Check for empty JSON files
find patch_data/ -name "*.json" -empty

# Verify JSON structure
cat patch_data/uat_hostname_9_2025-02-16.json | jq .

# Re-run patching if JSON is corrupted
ansible-playbook -i inventory master_patch.yaml -l uat_servers
```

### Issue: Backup Directory Not Created

**Symptom**: Warning message about backup directory

**Solution**:
```bash
# Manually create backup directory on target
ssh uat-rhel9-01.example.com
sudo mkdir -p /var/lib/rpmbackup
sudo chmod 755 /var/lib/rpmbackup

# Verify disk space
df -h /var

# Check if backups exist
ls -lh /var/lib/rpmbackup/
```

---

## Advanced Usage

### CVE-Specific Patching

Patch specific CVE vulnerabilities by creating targeted package lists:

```bash
# Create CVE-specific package list
cat > packages_cve_2025_21378.txt << EOF
# CVE-2025-21378: nginx vulnerability
nginx-1.28.2-1.el9.ngx.x86_64.rpm
nginx-1.26.3-1.el8.ngx.x86_64.rpm
EOF

# Run patching with custom package list
ansible-playbook -i inventory master_patch.yaml \
  -e package_file=packages_cve_2025_21378.txt \
  -l uat_servers
```

### Patching with Maintenance Windows

Schedule patching during specific maintenance windows:

```bash
# Run at specific time (using at or cron)
echo "ansible-playbook -i inventory master_patch.yaml -l uat_servers" | at 02:00

# Or use cron for recurring patching
crontab -e
# 0 2 * * 6 cd /home/anik/ansible/wikilabs/aeon/rhel_patching && ansible-playbook -i inventory master_patch.yaml -l uat_servers >> /var/log/patching.log 2>&1
```

### Integration with Monitoring

Integrate patching results with monitoring systems:

```bash
# Parse JSON results for monitoring
cat patch_data/uat_*.json | jq -r '.hostname + "," + .status + "," + .package_count'

# Send metrics to monitoring system
curl -X POST http://monitoring-server/api/metrics \
  -H "Content-Type: application/json" \
  -d @patch_data/uat_*.json

# Generate Nagios/Icinga plugin output
cat > check_patching.sh << 'EOF'
#!/bin/bash
# Check patching status from JSON
jq -r 'if .status == "completed" then "OK: \(.hostname) patched" else "CRITICAL: \(.hostname) failed" end' patch_data/*.json
EOF
chmod +x check_patching.sh
```

---

## Best Practices

### Pre-Patching Checklist

- [ ] Test patching in UAT environment first
- [ ] Verify all prerequisites are met
- [ ] Ensure backups are current
- [ ] Notify stakeholders of maintenance window
- [ ] Document current system state
- [ ] Have rollback plan ready
- [ ] Verify repository accessibility
- [ ] Check disk space on target hosts

### During Patching

- [ ] Monitor patching progress in real-time
- [ ] Keep logs for audit trail
- [ ] Document any warnings or errors
- [ ] Don't patch all environments simultaneously
- [ ] Have team available for support
- [ ] Test applications after patching

### Post-Patching

- [ ] Verify package versions
- [ ] Test application functionality
- [ ] Check service health
- [ ] Review HTML reports
- [ ] Archive patching results
- [ ] Document lessons learned
- [ ] Update documentation if needed

---

## Support and Contacts

### Documentation

- **Main README**: `/home/anik/ansible/wikilabs/aeon/rhel_patching/README.md`
- **Rollback Guide**: `/home/anik/ansible/wikilabs/aeon/rhel_patching/docs/ROLLBACK.md`
- **Implementation Plan**: `/home/anik/ansible/wikilabs/aeon/rhel_patching/docs/plans/`

### Getting Help

For questions, issues, or assistance:

1. **Check Documentation**: Review this README and ROLLBACK.md
2. **Review Logs**: Check Ansible output and JSON results in `patch_data/`
3. **Contact Team**: Reach out to your system administration team
4. **Open Issue**: Submit issue in project repository with:
   - Environment (UAT/DR/PROD)
   - Error message
   - Relevant logs
   - Steps to reproduce

### Emergency Contacts

Fill in your organization's contacts:

| Role | Name | Email/Phone | Hours |
|------|------|-------------|-------|
| On-Call Engineer | [Name] | [email/phone] | 24/7 |
| System Admin Lead | [Name] | [email/phone] | Business Hours |
| Application Owner | [Name] | [email/phone] | Business Hours |
| Red Hat Support | 1-800-RED-HAT1 | portal.redhat.com | 24/7 |

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 2.0 | 2025-02-16 | Comprehensive rewrite with usage instructions | Automation Team |
| 1.0 | 2025-02-05 | Initial basic documentation | Automation Team |

---

## License and Attribution

This RHEL Patching Automation System is developed and maintained by the Systems Automation Team.

**Technologies Used:**
- Ansible 2.15+
- Python 3.9+
- Jinja2 Templates
- RHEL 8/9

**Related Resources:**
- [Ansible Documentation](https://docs.ansible.com/)
- [Red Hat Documentation](https://access.redhat.com/documentation/)
- [RPM Package Manager](https://rpm.org/)

---

**Last Updated**: 2025-02-16
**Maintained By**: System Administration Team
**Project Location**: `/home/anik/ansible/wikilabs/aeon/rhel_patching/`
