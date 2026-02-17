#!/bin/bash

# Clean installation script
# Simple workstation selection without complex logic

set -e

# Configuration
ANSIBLE_REQUIREMENTS_FILENAME="requirements.yml"
ANSIBLE_INVENTORY_FILENAME="inventory.yml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Workstation Setup Script${NC}"
echo "========================"
echo ""

# Function to display usage
usage() {
    echo "Usage: $0 [workstation_type]"
    echo ""
    echo "Available workstation types:"
    echo "  default - Full workstation with all roles"
    echo "  slim    - Minimal workstation with essential roles"
    echo ""
    echo "Examples:"
    echo "  $0          # Interactive selection"
    echo "  $0 default   # Install default workstation"
    echo "  $0 slim      # Install slim workstation"
    exit 1
}

# Check for help flag
if [[ "${1}" == "-h" || "${1}" == "--help" ]]; then
    usage
fi

# Workstation type selection
WORKSTATION_TYPE="${1:-}"

if [[ -z "${WORKSTATION_TYPE}" ]]; then
    echo "Available workstation types:"
    echo "1) default - Full workstation with all roles"
    echo "2) slim    - Minimal workstation with essential roles"
    echo ""
    read -p "Select workstation type (1-2) or press Enter for default: " choice
    case "${choice}" in
        1)
            WORKSTATION_TYPE="default"
            ;;
        2)
            WORKSTATION_TYPE="slim"
            ;;
        "")
            WORKSTATION_TYPE="default"
            ;;
        *)
            echo -e "${YELLOW}Invalid choice. Using default.${NC}"
            WORKSTATION_TYPE="default"
            ;;
    esac
fi

echo -e "${GREEN}Selected workstation type: ${WORKSTATION_TYPE}${NC}"
echo ""

# Validate workstation type
if [[ "${WORKSTATION_TYPE}" != "default" && "${WORKSTATION_TYPE}" != "slim" ]]; then
    echo -e "${RED}Error: Invalid workstation type '${WORKSTATION_TYPE}'${NC}"
    echo "Valid types: default, slim"
    exit 1
fi

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Error: This script must be run as root${NC}"
    echo "Please run: sudo $0 $*"
    exit 1
fi

# Install Ansible if not present
if ! command -v ansible &> /dev/null; then
    echo -e "${YELLOW}Installing Ansible...${NC}"
    dnf install -y ansible
else
    echo -e "${GREEN}Ansible is already installed${NC}"
fi

# Install Ansible requirements
if [[ -f "${ANSIBLE_REQUIREMENTS_FILENAME}" ]]; then
    echo -e "${YELLOW}Installing Ansible requirements...${NC}"
    ansible-galaxy install -r "${ANSIBLE_REQUIREMENTS_FILENAME}"
fi

# Run the appropriate playbook
echo -e "${GREEN}Running workstation setup...${NC}"
echo ""

case "${WORKSTATION_TYPE}" in
    "default")
        ansible-playbook \
            --inventory "${ANSIBLE_INVENTORY_FILENAME}" \
            --extra-vars "workstation_type=default" \
            playbooks/default.yml
        ;;
    "slim")
        ansible-playbook \
            --inventory "${ANSIBLE_INVENTORY_FILENAME}" \
            --extra-vars "workstation_type=slim" \
            playbooks/slim.yml
        ;;
esac

echo ""
echo -e "${GREEN}Workstation setup complete!${NC}"
