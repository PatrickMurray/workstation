#!/bin/bash

# Check ansible-vault encryption for role defaults files and secrets.yml

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if a file is encrypted with ansible-vault
is_encrypted() {
    local file="$1"
    if [[ -f "$file" ]]; then
        head -n 1 "$file" | grep -q '$ANSIBLE_VAULT'
        return $?
    fi
    return 1
}

# Get files to check (passed by pre-commit)
FILES_TO_CHECK=$@

EXIT_CODE=0

echo -e "${YELLOW}Checking ansible-vault encryption...${NC}"

for file in $FILES_TO_CHECK; do
    if [[ -f "$file" ]]; then
        if ! is_encrypted "$file"; then
            echo -e "${RED}✗${NC} File $file is not encrypted with ansible-vault"
            echo -e "${YELLOW}  Encrypt it with: ansible-vault encrypt $file${NC}"
            EXIT_CODE=1
        else
            echo -e "${GREEN}✓${NC} $file is properly encrypted"
        fi
    fi
done

if [ $EXIT_CODE -ne 0 ]; then
    echo -e "${RED}❌ ansible-vault encryption check failed.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ ansible-vault encryption check passed.${NC}"
exit 0
