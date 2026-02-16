#!/bin/bash
# UAT Environment Patching Workflow Script
# This script automates the patching process for UAT servers
#
# Usage: ./scripts/patch_uat.sh

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

echo -e "${BLUE}============================================================================${NC}"
echo -e "${BLUE}  RHEL Patching Automation - UAT Environment${NC}"
echo -e "${BLUE}============================================================================${NC}"
echo ""

# Step 1/5: Verify environment
echo -e "${GREEN}[1/5] Verifying UAT Environment...${NC}"
echo "Running integration tests..."
if ansible-playbook -i inventory tests/integration_test.yaml -l uat_servers --check; then
    echo -e "${GREEN}✓ UAT environment verification passed${NC}"
else
    echo -e "${RED}✗ UAT environment verification failed${NC}"
    echo "Please resolve the issues before proceeding with patching"
    exit 1
fi
echo ""

# Step 2/5: Pre-patching backup
echo -e "${GREEN}[2/5] Creating Pre-patching Backup...${NC}"
BACKUP_DIR="patch_data/backups/uat_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
echo "Backup directory: $BACKUP_DIR"
if [ -d "patch_data" ]; then
    cp -r patch_data/*.json "$BACKUP_DIR/" 2>/dev/null || true
fi
echo -e "${GREEN}✓ Backup completed${NC}"
echo ""

# Step 3/5: Patch UAT servers
echo -e "${GREEN}[3/5] Patching UAT Servers...${NC}"
echo "Starting patching process for UAT environment..."
if ansible-playbook -i inventory master_patch.yaml -l uat_servers; then
    echo -e "${GREEN}✓ UAT patching completed successfully${NC}"
else
    echo -e "${RED}✗ UAT patching failed${NC}"
    echo "Please check the error logs and fix any issues"
    exit 1
fi
echo ""

# Step 4/5: Generate HTML report
echo -e "${GREEN}[4/5] Generating HTML Report...${NC}"
REPORT_FILE="patching_reports/uat_patching_report_$(date +%Y%m%d_%H%M%S).html"
mkdir -p patching_reports

if ansible-playbook -i inventory generate_report.yaml -l uat_servers \
    -e "report_file=$REPORT_FILE" \
    -e "environment=uat"; then
    echo -e "${GREEN}✓ HTML report generated successfully${NC}"
else
    echo -e "${YELLOW}⚠ Report generation completed with warnings${NC}"
fi
echo ""

# Step 5/5: Display summary
echo -e "${GREEN}[5/5] Patching Summary${NC}"
echo -e "${BLUE}============================================================================${NC}"
echo -e "${GREEN}UAT Environment Patching Completed Successfully!${NC}"
echo -e "${BLUE}============================================================================${NC}"
echo ""
echo "Report Location:"
echo -e "  ${YELLOW}$PROJECT_DIR/$REPORT_FILE${NC}"
echo ""
echo "Next Steps:"
echo "  1. Review the HTML report for patching details"
echo "  2. Verify UAT applications are functioning correctly"
echo "  3. Monitor system logs for any issues:"
echo "     ssh uat-server 'journalctl -xe'"
echo "  4. Run application-specific smoke tests"
echo "  5. If UAT validation passes, proceed to DR patching"
echo ""
echo "To view the report:"
echo -e "  ${YELLOW}xdg-open $PROJECT_DIR/$REPORT_FILE${NC}"
echo -e "${BLUE}============================================================================${NC}"
