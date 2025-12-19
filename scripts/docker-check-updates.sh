#!/bin/bash

# Docker Update Checker
# Checks for available updates without making any changes

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}=========================================="
echo -e "Docker Container Update Checker"
echo -e "==========================================${NC}"
echo ""

# Counter for updates
updates_available=0
total_checked=0

# Get all running containers
containers=$(docker ps --format '{{.ID}}|{{.Names}}|{{.Image}}')

if [ -z "$containers" ]; then
    echo -e "${RED}No running containers found${NC}"
    exit 1
fi

echo -e "${CYAN}Checking for updates...${NC}"
echo ""

# Check each container
while IFS='|' read -r container_id container_name image; do
    ((total_checked++))
    
    # Skip hash-only images
    if [[ "${image}" =~ ^[a-f0-9]{12}$ ]]; then
        printf "%-30s %-50s ${YELLOW}[SKIP]${NC} Hash-based image\n" "$container_name" "$image"
        continue
    fi
    
    # Skip local custom images
    if [[ "${image}" == *":"* ]] && [[ ! "${image}" =~ \. ]] && [[ ! "${image}" =~ ^(ghcr|lscr|docker\.io|quay\.io|gcr\.io) ]]; then
        if [[ "${image}" != *"/"* ]] || [[ "${image}" == "skylite-ux:"* ]]; then
            printf "%-30s %-50s ${YELLOW}[SKIP]${NC} Local image\n" "$container_name" "$image"
            continue
        fi
    fi
    
    # Get current digest
    current_digest=$(docker inspect --format='{{.Image}}' "${container_name}" 2>/dev/null)
    
    if [ -z "$current_digest" ]; then
        printf "%-30s %-50s ${RED}[ERROR]${NC} Failed to get digest\n" "$container_name" "$image"
        continue
    fi
    
    # Pull latest (quiet mode)
    printf "%-30s %-50s Checking..." "$container_name" "$image"
    
    if docker pull "${image}" --quiet >/dev/null 2>&1; then
        latest_digest=$(docker inspect --format='{{.Id}}' "${image}" 2>/dev/null)
        
        if [ "$current_digest" != "$latest_digest" ]; then
            printf "\r%-30s %-50s ${GREEN}[UPDATE AVAILABLE]${NC}\n" "$container_name" "$image"
            ((updates_available++))
        else
            printf "\r%-30s %-50s ${BLUE}[UP TO DATE]${NC}\n" "$container_name" "$image"
        fi
    else
        printf "\r%-30s %-50s ${RED}[ERROR]${NC} Failed to check\n" "$container_name" "$image"
    fi
    
done <<< "$containers"

echo ""
echo -e "${BLUE}=========================================="
echo -e "Summary"
echo -e "==========================================${NC}"
echo -e "Total containers checked: ${CYAN}${total_checked}${NC}"

if [ $updates_available -gt 0 ]; then
    echo -e "Updates available: ${GREEN}${updates_available}${NC}"
    echo ""
    echo -e "${YELLOW}To update containers, run:${NC}"
    echo -e "  ${CYAN}./docker-compose-updater.sh${NC}  (for docker-compose managed containers)"
    echo -e "  ${CYAN}./docker-update-manager.sh${NC}   (for standalone containers)"
else
    echo -e "Updates available: ${GREEN}0${NC}"
    echo -e "${GREEN}All containers are up to date!${NC}"
fi

echo ""

