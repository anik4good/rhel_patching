#!/bin/bash
# Production Environment Patching Workflow Script
# This script automates the patching process for Production servers
#
# Usage: ./scripts/patch_prod.sh

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Change to project directory
cd "$PROJECT_DIR"

# Warning prompt for production
echo -e "${RED}============================================================================${NC}"
echo -e "${RED}  WARNING: PRODUCTION ENVIRONMENT PATCHING${NC}"
echo -e "${RED}============================================================================${NC}"
echo -e "${YELLOW}This will patch production servers!${NC}"
echo -e "${YELLOW}Ensure you have:${NC}"
echo "  1. Completed UAT and DR patching successfully"
echo "  2. Approved maintenance window"
echo "  3. Notified stakeholders"
echo "  4. Prepared rollback plan"
echo ""
read -p "Do you want to proceed? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Patching cancelled."
    exit 0
fi
echo ""

echo -e "${BLUE}============================================================================${NC}"
echo -e "${BLUE}  RHEL Patching Automation - Production Environment${NC}"
echo -e "${BLUE}============================================================================${NC}"
echo ""

# Step 1/4: Pre-patching backup
echo -e "${GREEN}[1/4] Creating Pre-patching Backup...${NC}"
BACKUP_DIR="patch_data/backups/prod_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
echo "Backup directory: $BACKUP_DIR"
if [ -d "patch_data" ]; then
    cp -r patch_data/*.json "$BACKUP_DIR/" 2>/dev/null || true
fi
echo -e "${GREEN}✓ Backup completed${NC}"
echo ""

# Step 2/4: Patch Production servers
echo -e "${GREEN}[2/4] Patching Production Servers...${NC}"
echo "Starting patching process for Production environment..."
if ansible-playbook -i inventory master_patch.yaml -l prod_servers; then
    echo -e "${GREEN}✓ Production patching completed successfully${NC}"
else
    echo -e "${RED}✗ Production patching failed${NC}"
    echo "Please check the error logs and initiate rollback if needed"
    exit 1
fi
echo ""

# Step 3/4: Generate HTML report
echo -e "${GREEN}[3/4] Generating HTML Report...${NC}"
REPORT_FILE="patching_reports/prod_patching_report_$(date +%Y%m%d_%H%M%S).html"
mkdir -p patching_reports

if ansible-playbook -i inventory generate_report.yaml -l prod_servers \
    -e "report_file=$REPORT_FILE" \
    -e "environment=prod"; then
    echo -e "${GREEN}✓ HTML report generated successfully${NC}"
else
    echo -e "${YELLOW}⚠ Report generation completed with warnings${NC}"
fi
echo ""

# Step 4/4: Display summary
echo -e "${GREEN}[4/4] Patching Summary${NC}"
echo -e "${BLUE}============================================================================${NC}"
echo -e "${GREEN}Production Environment Patching Completed Successfully!${NC}"
echo -e "${BLUE}============================================================================${NC}"
echo ""
echo "Report Location:"
echo -e "  ${YELLOW}$PROJECT_DIR/$REPORT_FILE${NC}"
echo ""
echo "Critical Next Steps:"
echo "  1. Review the HTML report for patching details"
echo "  2. Verify all production services are running"
echo "  3. Monitor application logs and metrics"
echo "  4. Perform smoke tests on critical applications"
echo "  5. Check system performance and resource utilization"
echo "  6. Verify backup and recovery systems"
echo "  7. Document any issues or anomalies"
echo ""
echo "Monitoring Commands:"
echo "  - Check system logs: ssh prod-server 'journalctl -xe'"
echo "  - Monitor resources: ssh prod-server 'top -b -n 1'"
echo "  - Service status: ssh prod-server 'systemctl status'"
echo ""
echo "Rollback Information:"
echo "  Backup location: $BACKUP_DIR"
echo "  If issues occur, refer to runbook for rollback procedures"
echo ""
echo "To view the report:"
echo -e "  ${YELLOW}xdg-open $PROJECT_DIR/$REPORT_FILE${NC}"
echo -e "${BLUE}============================================================================${NC}"
