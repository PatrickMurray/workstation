#!/usr/bin/env bash

# VARIABLES
GITHUB_USERNAME="PatrickMurray"
GITHUB_REPOSITORY="workstation"
GITHUB_BRANCH="master"
GITHUB_ARCHIVE_URL="https://www.github.com/${GITHUB_USERNAME}/${GITHUB_REPOSITORY}/archive/${GITHUB_BRANCH}.zip"

ANSIBLE_REQUIREMENTS_FILENAME="requirements.yml"
ANSIBLE_INVENTORY_FILENAME="inventory.yml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# INITIALIZE
if [[ "${EUID}" -ne 0 ]]; then
    echo -e "${RED}Script must be run as root user${NC}"
    exit -1
fi

# Workstation type selection
WORKSTATION_TYPE="${1:-}"

if [[ -z "${WORKSTATION_TYPE}" ]]; then
    echo -e "${GREEN}Available workstation types:${NC}"
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
    exit -1
fi

# CREATE TEMP DIRECTORY
TEMP_DIRECTORY=$(mktemp --directory --suffix "_${GITHUB_USERNAME}_${GITHUB_REPOSITORY}_${GITHUB_BRANCH}")

if [[ "${?}" -ne 0 ]]; then
    echo -e "${RED}An error occurred while initializing the temporary directory${NC}"
    exit -1
fi

cd "${TEMP_DIRECTORY}"

if [[ "${?}" -ne 0 ]]; then
    echo -e "${RED}An error occurred while changing to the temporary directory${NC}"
    exit -1
fi

# INSTALL ANSIBLE
echo -e "${YELLOW}Installing Ansible...${NC}"
dnf install -y ansible-core

if [[ "${?}" -ne 0 ]]; then
    echo -e "${RED}An error occurred while attempting to install ansible${NC}"
    exit -1
fi

# DOWNLOAD ANSIBLE PLAYBOOK
echo -e "${YELLOW}Downloading workstation setup...${NC}"
wget "${GITHUB_ARCHIVE_URL}"

if [[ "${?}" -ne 0 ]]; then
    echo -e "${RED}An error occurred while attempting to download ansible playbook${NC}"
    exit -1
fi

unzip "${GITHUB_BRANCH}.zip"

if [[ "${?}" -ne 0 ]]; then
    echo -e "${RED}An error occurred while extracting the archive${NC}"
    exit -1
fi

cd "${GITHUB_REPOSITORY}-${GITHUB_BRANCH}"

if [[ "${?}" -ne 0 ]]; then
    echo -e "${RED}An error occurred while changing to the repository directory${NC}"
    exit -1
fi

# INSTALL ANSIBLE DEPENDENCIES
if [[ -f "${ANSIBLE_REQUIREMENTS_FILENAME}" ]]; then
    echo -e "${YELLOW}Installing Ansible requirements...${NC}"
    ansible-galaxy install --role-file "${ANSIBLE_REQUIREMENTS_FILENAME}"

    if [[ "${?}" -ne 0 ]]; then
        echo -e "${RED}An error occurred while installing ansible dependencies${NC}"
        exit -1
    fi
fi

# RUN ANSIBLE PLAYBOOK
echo -e "${GREEN}Running workstation setup...${NC}"
echo ""

case "${WORKSTATION_TYPE}" in
    "default")
        echo -e "${YELLOW}Running: ansible-playbook --inventory ${ANSIBLE_INVENTORY_FILENAME} --extra-vars \"workstation_type=default\" main.yml${NC}"
        ansible-playbook \
            --inventory "${ANSIBLE_INVENTORY_FILENAME}" \
            --extra-vars "workstation_type=default" \
            main.yml
        ;;
    "slim")
        echo -e "${YELLOW}Running: ansible-playbook --inventory ${ANSIBLE_INVENTORY_FILENAME} --extra-vars \"workstation_type=slim\" main.yml${NC}"
        ansible-playbook \
            --inventory "${ANSIBLE_INVENTORY_FILENAME}" \
            --extra-vars "workstation_type=slim" \
            main.yml
        ;;
esac

if [[ "${?}" -ne 0 ]]; then
    echo -e "${RED}An error occurred while running ansible playbook${NC}"
    exit -1
fi

echo ""
echo -e "${GREEN}Workstation setup complete!${NC}"
