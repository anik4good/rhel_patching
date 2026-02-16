#!/bin/bash
# DR Environment Patching Workflow Script
# This script automates the patching process for DR servers
#
# Usage: ./scripts/patch_dr.sh

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
echo -e "${BLUE}  RHEL Patching Automation - DR Environment${NC}"
echo -e "${BLUE}============================================================================${NC}"
echo ""

# Step 1/4: Pre-patching backup
echo -e "${GREEN}[1/4] Creating Pre-patching Backup...${NC}"
BACKUP_DIR="patch_data/backups/dr_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
echo "Backup directory: $BACKUP_DIR"
if [ -d "patch_data" ]; then
    cp -r patch_data/*.json "$BACKUP_DIR/" 2>/dev/null || true
fi
echo -e "${GREEN}✓ Backup completed${NC}"
echo ""

# Step 2/4: Patch DR servers
echo -e "${GREEN}[2/4] Patching DR Servers...${NC}"
echo "Starting patching process for DR environment..."
if ansible-playbook -i inventory master_patch.yaml -l dr_servers; then
    echo -e "${GREEN}✓ DR patching completed successfully${NC}"
else
    echo -e "${RED}✗ DR patching failed${NC}"
    echo "Please check the error logs and fix any issues"
    exit 1
fi
echo ""

# Step 3/4: Generate HTML report
echo -e "${GREEN}[3/4] Generating HTML Report...${NC}"
REPORT_FILE="patching_reports/dr_patching_report_$(date +%Y%m%d_%H%M%S).html"
mkdir -p patching_reports

if ansible-playbook -i inventory generate_report.yaml -l dr_servers \
    -e "report_file=$REPORT_FILE" \
    -e "environment=dr"; then
    echo -e "${GREEN}✓ HTML report generated successfully${NC}"
else
    echo -e "${YELLOW}⚠ Report generation completed with warnings${NC}"
fi
echo ""

# Step 4/4: Display summary
echo -e "${GREEN}[4/4] Patching Summary${NC}"
echo -e "${BLUE}============================================================================${NC}"
echo -e "${GREEN}DR Environment Patching Completed Successfully!${NC}"
echo -e "${BLUE}============================================================================${NC}"
echo ""
echo "Report Location:"
echo -e "  ${YELLOW}$PROJECT_DIR/$REPORT_FILE${NC}"
echo ""
echo "Next Steps:"
echo "  1. Review the HTML report for patching details"
echo "  2. Verify DR environment is ready for failover"
echo "  3. Test DR failover procedures"
echo "  4. Verify DR applications are functioning correctly"
echo "  5. If DR validation passes, schedule production patching"
echo ""
echo "To view the report:"
echo -e "  ${YELLOW}xdg-open $PROJECT_DIR/$REPORT_FILE${NC}"
echo -e "${BLUE}============================================================================${NC}"
