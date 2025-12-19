#!/bin/bash

# Docker Image Information Tool
# Shows detailed image information including actual tags for hash-based images

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo -e "Docker Container Image Information"
echo -e "==========================================${NC}"
echo ""

# Get all running containers
containers=$(docker ps --format '{{.ID}}|{{.Names}}|{{.Image}}')

echo -e "${CYAN}Container → Actual Image Details${NC}"
echo ""

while IFS='|' read -r container_id container_name displayed_image; do
    # Get the actual image repo tags
    actual_images=$(docker inspect --format='{{range .RepoTags}}{{.}} {{end}}{{range .RepoDigests}}{{.}} {{end}}' "${container_name}" 2>/dev/null)
    
    # Get image ID
    image_id=$(docker inspect --format='{{.Image}}' "${container_name}" 2>/dev/null | cut -d':' -f2 | cut -c1-12)
    
    # Get image creation date
    image_date=$(docker inspect --format='{{.Created}}' "${container_name}" 2>/dev/null | cut -d'T' -f1)
    
    printf "${GREEN}%-30s${NC}\n" "$container_name"
    printf "  Displayed: ${YELLOW}%-50s${NC}\n" "$displayed_image"
    
    if [ -n "$actual_images" ]; then
        # Parse and display each repo tag/digest
        for img in $actual_images; do
            if [[ $img == *"@sha256"* ]]; then
                printf "  Digest:    ${CYAN}%-50s${NC}\n" "$img"
            else
                printf "  Tag:       ${CYAN}%-50s${NC}\n" "$img"
            fi
        done
    fi
    
    printf "  Image ID:  ${BLUE}%-50s${NC}\n" "$image_id"
    printf "  Created:   ${BLUE}%-50s${NC}\n" "$image_date"
    echo ""
    
done <<< "$containers"

echo ""
echo -e "${YELLOW}Note: Containers showing hash-based images might have been created without${NC}"
echo -e "${YELLOW}      specifying a tag. Check the compose files or run commands to add tags.${NC}"
echo ""

