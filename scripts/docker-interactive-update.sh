#!/bin/bash

# Interactive Docker Update Script
# Updates containers one at a time with detailed explanations and prompts

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Configuration
BACKUP_BASE_DIR="/home/deshmukh/docker-backups"
COMPOSE_DIR="/home/deshmukh/homelab-docker"

# Detect compose command
if command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
else
    COMPOSE_CMD="docker compose"
fi

# Function to print section headers
print_header() {
    echo ""
    echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║$(printf '%64s' | tr ' ' ' ')║${NC}"
    echo -e "${MAGENTA}║  $(printf '%-60s' "$1")║${NC}"
    echo -e "${MAGENTA}║$(printf '%64s' | tr ' ' ' ')║${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Function to pause and wait for user
pause() {
    echo ""
    read -p "$(echo -e ${CYAN}Press ENTER to continue, or Ctrl+C to abort...${NC})"
    echo ""
}

# Function to get service info from compose
get_service_info() {
    local service_name=$1
    cd "${COMPOSE_DIR}"
    
    # Get the image from compose file
    local image=$(grep -A 1 "^  ${service_name}:" docker-compose.yml | grep "image:" | awk '{print $2}')
    echo "$image"
}

# Function to check disk space
check_disk_space() {
    local backup_base_dir=$1
    local service_name=$2
    
    # Get available space in GB
    local available_gb=$(df -BG "${backup_base_dir}" 2>/dev/null | awk 'NR==2 {print $4}' | sed 's/G//')
    
    if [ -z "$available_gb" ]; then
        # Fallback if backup dir doesn't exist yet
        available_gb=$(df -BG /home 2>/dev/null | awk 'NR==2 {print $4}' | sed 's/G//')
    fi
    
    # Estimate backup size needed (rough estimate)
    local container_name=$(grep -A 5 "^  ${service_name}:" "${COMPOSE_DIR}/docker-compose.yml" | grep "container_name:" | head -1 | awk '{print $2}' | tr -d '"')
    if [ -z "$container_name" ]; then
        container_name="${service_name}"
    fi
    
    # Get container size if it exists
    local estimated_size_mb=100  # Default 100MB minimum
    if docker ps -a --format "{{.Names}}" | grep -q "^${container_name}$"; then
        local container_size=$(docker ps -a --size --format "{{.Names}} {{.Size}}" | grep "^${container_name} " | awk '{print $(NF-1)}' | sed 's/MB//;s/GB/*1024/;s/KB/\/1024/' | bc 2>/dev/null || echo "100")
        estimated_size_mb=$((${container_size%.*} + 100))  # Add 100MB buffer
    fi
    
    local estimated_size_gb=$((estimated_size_mb / 1024 + 1))
    
    echo -e "${CYAN}Disk Space Check:${NC}"
    echo -e "  Available: ${GREEN}${available_gb}GB${NC}"
    echo -e "  Estimated backup size: ${BLUE}~${estimated_size_gb}GB${NC}"
    
    # Warn if low on space (less than 5GB or less than needed + 2GB buffer)
    local min_required=$((estimated_size_gb + 2))
    if [ "$available_gb" -lt 5 ]; then
        echo -e "  ${RED}⚠ WARNING: Low disk space!${NC}"
        return 1
    elif [ "$available_gb" -lt "$min_required" ]; then
        echo -e "  ${YELLOW}⚠ Space is tight, but should be sufficient${NC}"
    else
        echo -e "  ${GREEN}✓ Sufficient space available${NC}"
    fi
    
    echo ""
    return 0
}

# Function to show existing backups
show_existing_backups() {
    local service_name=$1
    local backup_base_dir=$2
    
    # Find existing backups for this service
    local existing_backups=$(find "${backup_base_dir}" -maxdepth 1 -type d -name "*${service_name}" 2>/dev/null | sort -r)
    
    if [ -n "$existing_backups" ]; then
        echo -e "${CYAN}Existing backups for ${service_name}:${NC}"
        local count=0
        while IFS= read -r backup; do
            if [ -n "$backup" ]; then
                local backup_name=$(basename "$backup")
                local backup_date=$(echo "$backup_name" | grep -oP '\d{8}_\d{6}' || echo "unknown")
                local backup_size=$(du -sh "$backup" 2>/dev/null | awk '{print $1}')
                local backup_age=$(find "$backup" -maxdepth 0 -printf '%Ar\n' 2>/dev/null || echo "unknown")
                
                ((count++))
                echo -e "  ${count}) ${backup_name}"
                echo -e "     Size: ${backup_size} | Age: ${backup_age}"
            fi
        done <<< "$existing_backups"
        
        echo -e "${YELLOW}  Note: New backup will be created. Old backups are kept for safety.${NC}"
        echo ""
    else
        echo -e "${BLUE}No existing backups found for ${service_name}${NC}"
        echo ""
    fi
}

# Function to backup service
backup_service() {
    local service_name=$1
    local backup_dir=$2
    
    print_header "STEP 1: Creating Backup for ${service_name}"
    
    echo -e "${BLUE}What we're backing up:${NC}"
    echo -e "  • Container configuration (how it's set up)"
    echo -e "  • Volume data (your actual data)"
    echo -e "  • Current image (so we can rollback if needed)"
    echo ""
    
    # Check disk space
    if ! check_disk_space "${BACKUP_BASE_DIR}" "${service_name}"; then
        echo -e "${RED}Insufficient disk space for backup!${NC}"
        read -p "$(echo -e ${YELLOW}Continue anyway? [y/N]:${NC} )" -r proceed
        if [[ ! $proceed =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi
    
    # Show existing backups
    show_existing_backups "${service_name}" "${BACKUP_BASE_DIR}"
    
    mkdir -p "${backup_dir}/config"
    mkdir -p "${backup_dir}/volumes"
    
    # Get the actual container name from compose file
    cd "${COMPOSE_DIR}"
    local container_name=$(grep -A 5 "^  ${service_name}:" docker-compose.yml | grep "container_name:" | head -1 | awk '{print $2}' | tr -d '"')
    
    # If no container_name defined, docker-compose uses service name
    if [ -z "$container_name" ]; then
        container_name="${service_name}"
    fi
    
    # Check if container exists
    if ! docker ps -a --format "{{.Names}}" | grep -q "^${container_name}$"; then
        echo -e "${YELLOW}⚠ Container ${container_name} (service: ${service_name}) not found, skipping backup${NC}"
        return 1
    fi
    
    echo -e "${CYAN}Backing up configuration...${NC}"
    docker inspect "${container_name}" > "${backup_dir}/config/${service_name}.json"
    docker inspect --format='{{range .Config.Env}}{{println .}}{{end}}' "${container_name}" > "${backup_dir}/config/${service_name}.env"
    echo -e "${GREEN}✓${NC} Configuration saved"
    
    echo -e "${CYAN}Backing up volume data...${NC}"
    # Get volumes
    local volumes=$(docker inspect --format='{{range .Mounts}}{{if eq .Type "volume"}}{{.Name}} {{end}}{{end}}' "${container_name}")
    
    if [ -n "$volumes" ]; then
        for vol in $volumes; do
            echo -e "  • Volume: ${vol}"
            docker run --rm \
                -v "${vol}:/source:ro" \
                -v "${backup_dir}/volumes:/backup" \
                alpine \
                tar czf "/backup/${vol}.tar.gz" -C /source . 2>/dev/null || {
                echo -e "${YELLOW}  ⚠ Could not backup volume ${vol}${NC}"
            }
        done
    fi
    
    # Backup bind mounts
    local bind_mounts=$(docker inspect --format='{{range .Mounts}}{{if eq .Type "bind"}}{{.Source}} {{end}}{{end}}' "${container_name}")
    
    if [ -n "$bind_mounts" ]; then
        for mount in $bind_mounts; do
            # Skip system mounts
            if [[ "$mount" == "/etc/localtime" ]] || [[ "$mount" == "/var/run/docker.sock" ]] || [[ "$mount" == "/run/udev" ]]; then
                continue
            fi
            
            if [ -d "$mount" ] && [ -r "$mount" ]; then
                local mount_name=$(basename "$mount")
                echo -e "  • Bind mount: ${mount}"
                tar -czf "${backup_dir}/volumes/${service_name}_${mount_name}.tar.gz" -C "$(dirname "$mount")" "$(basename "$mount")" 2>/dev/null || {
                    echo -e "${YELLOW}  ⚠ Could not backup ${mount}${NC}"
                }
            fi
        done
    fi
    
    echo -e "${GREEN}✓${NC} Backup complete: ${backup_dir}"
    
    pause
}

# Function to pull new image
pull_image() {
    local service_name=$1
    
    print_header "STEP 2: Pulling Latest Image for ${service_name}"
    
    echo -e "${BLUE}What this does:${NC}"
    echo -e "  • Downloads the latest version of the image from the internet"
    echo -e "  • Does NOT affect the running container yet"
    echo -e "  • Allows us to compare versions"
    echo ""
    
    cd "${COMPOSE_DIR}"
    
    echo -e "${CYAN}Pulling image...${NC}"
    echo ""
    
    # Get current image digest before pulling
    local current_digest=""
    local container_name=$(grep -A 5 "^  ${service_name}:" docker-compose.yml | grep "container_name:" | head -1 | awk '{print $2}' | tr -d '"')
    if [ -z "$container_name" ]; then
        container_name="${service_name}"
    fi
    
    if docker ps -a --format "{{.Names}}" | grep -q "^${container_name}$"; then
        current_digest=$(docker inspect --format='{{.Image}}' "${container_name}" 2>/dev/null)
    fi
    
    # Pull with native progress bars (no piping/tee)
    ${COMPOSE_CMD} pull ${service_name}
    local pull_result=$?
    
    echo ""
    
    if [ $pull_result -eq 0 ]; then
        # Check if image actually changed
        local new_digest=""
        local image=$(grep -A 10 "^  ${service_name}:" docker-compose.yml | grep "image:" | head -1 | awk '{print $2}')
        if [ -n "$image" ]; then
            new_digest=$(docker inspect --format='{{.Id}}' "${image}" 2>/dev/null)
        fi
        
        if [ -n "$current_digest" ] && [ -n "$new_digest" ] && [ "$current_digest" != "$new_digest" ]; then
            echo -e "${GREEN}✓${NC} New version available and downloaded!"
        else
            echo -e "${BLUE}ℹ${NC} Image pulled (may already be latest version)"
        fi
    else
        echo -e "${YELLOW}⚠${NC} Pull completed with warnings"
    fi
    
    pause
}

# Function to stop and remove old container
stop_container() {
    local service_name=$1
    
    # Get the actual container name (may differ from service name)
    cd "${COMPOSE_DIR}"
    local container_name=$(grep -A 5 "^  ${service_name}:" docker-compose.yml | grep "container_name:" | head -1 | awk '{print $2}' | tr -d '"')
    
    # If no container_name defined, docker-compose uses service name
    if [ -z "$container_name" ]; then
        container_name="${service_name}"
    fi
    
    print_header "STEP 3: Stopping Old Container for ${service_name}"
    
    echo -e "${BLUE}What this does:${NC}"
    echo -e "  • Gracefully stops the running container"
    echo -e "  • Removes the old container (data is safe in volumes)"
    echo -e "  • Prepares for creating the new container"
    echo ""
    
    echo -e "${YELLOW}⚠ The service will be temporarily unavailable${NC}"
    
    read -p "$(echo -e ${CYAN}Ready to stop ${service_name}? [y/N]:${NC} )" -r confirm
    
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Skipped${NC}"
        return 1
    fi
    
    echo -e "${CYAN}Stopping ${service_name}...${NC}"
    if ${COMPOSE_CMD} stop ${service_name} 2>&1; then
        echo -e "${GREEN}✓${NC} Container stopped"
    else
        echo -e "${YELLOW}⚠${NC} Stop command completed (may have already been stopped)"
    fi
    
    echo -e "${CYAN}Removing old container...${NC}"
    
    # Try docker-compose rm first
    if ${COMPOSE_CMD} rm -f ${service_name} 2>&1 | grep -q "No stopped containers"; then
        echo -e "${YELLOW}⚠${NC} Container still running, forcing removal with docker command..."
        # Fall back to direct docker command using ACTUAL container name
        if docker stop ${container_name} 2>/dev/null && docker rm -f ${container_name} 2>/dev/null; then
            echo -e "${GREEN}✓${NC} Old container removed (forced)"
        else
            echo -e "${RED}✗${NC} Failed to remove container ${container_name}"
            return 1
        fi
    else
        echo -e "${GREEN}✓${NC} Old container removed"
    fi
    
    pause
}

# Function to start new container
start_container() {
    local service_name=$1
    
    print_header "STEP 4: Starting New Container for ${service_name}"
    
    echo -e "${BLUE}What this does:${NC}"
    echo -e "  • Creates a new container with the updated image"
    echo -e "  • Reconnects to your existing data volumes"
    echo -e "  • Starts the service with new version"
    echo ""
    
    cd "${COMPOSE_DIR}"
    
    echo -e "${CYAN}Creating and starting ${service_name}...${NC}"
    
    # Get the actual container name
    cd "${COMPOSE_DIR}"
    local container_name=$(grep -A 5 "^  ${service_name}:" docker-compose.yml | grep "container_name:" | head -1 | awk '{print $2}' | tr -d '"')
    if [ -z "$container_name" ]; then
        container_name="${service_name}"
    fi
    
    # Use --no-deps to avoid restarting dependencies that are already running
    if ${COMPOSE_CMD} up -d --no-deps ${service_name} 2>&1; then
        echo -e "${GREEN}✓${NC} New container started"
    else
        echo -e "${RED}✗${NC} Failed to start container"
        echo ""
        echo -e "${YELLOW}Checking if old container is still present...${NC}"
        if docker ps -a --format "{{.Names}}" | grep -q "^${container_name}$"; then
            echo -e "${YELLOW}Found old container (${container_name}), removing it...${NC}"
            docker stop ${container_name} 2>/dev/null || true
            docker rm -f ${container_name} 2>/dev/null || true
            echo -e "${CYAN}Retrying container creation...${NC}"
            if ${COMPOSE_CMD} up -d --no-deps ${service_name}; then
                echo -e "${GREEN}✓${NC} Container started successfully on retry"
            else
                echo -e "${RED}✗${NC} Failed again, please check manually"
                return 1
            fi
        else
            return 1
        fi
    fi
    
    echo ""
    echo -e "${CYAN}Waiting 5 seconds for service to initialize...${NC}"
    sleep 5
    
    pause
}

# Function to verify container
verify_container() {
    local service_name=$1
    
    print_header "STEP 5: Verifying ${service_name}"
    
    echo -e "${BLUE}What we're checking:${NC}"
    echo -e "  • Is the container running?"
    echo -e "  • Are there any errors in logs?"
    echo -e "  • Is the service healthy?"
    echo ""
    
    cd "${COMPOSE_DIR}"
    
    # Check if running
    local status=$(${COMPOSE_CMD} ps ${service_name} 2>/dev/null | tail -n +2)
    
    if [ -z "$status" ]; then
        echo -e "${RED}✗${NC} Container is not running!"
        echo ""
        echo -e "${CYAN}Recent logs:${NC}"
        ${COMPOSE_CMD} logs --tail=30 ${service_name}
        return 1
    fi
    
    echo -e "${GREEN}✓${NC} Container is running"
    echo ""
    echo -e "${CYAN}Container status:${NC}"
    ${COMPOSE_CMD} ps ${service_name}
    
    echo ""
    echo -e "${CYAN}Recent logs (last 15 lines):${NC}"
    ${COMPOSE_CMD} logs --tail=15 ${service_name}
    
    echo ""
    echo -e "${BLUE}Does everything look good?${NC}"
    read -p "$(echo -e ${CYAN}Is ${service_name} working correctly? [Y/n]:${NC} )" -r confirm
    
    if [[ $confirm =~ ^[Nn]$ ]]; then
        echo ""
        echo -e "${RED}Update may have failed!${NC}"
        echo -e "${YELLOW}You can rollback by restoring from backup${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓${NC} Update verified successfully!"
    
    pause
}

# Function to update a service
update_service() {
    local service_name=$1
    local backup_dir="${BACKUP_BASE_DIR}/interactive-$(date +%Y%m%d_%H%M%S)-${service_name}"
    
    clear
    print_header "Updating Service: ${service_name}"
    
    # Get image info
    local image=$(get_service_info "${service_name}")
    
    echo -e "${CYAN}Service:${NC} ${service_name}"
    echo -e "${CYAN}Image:${NC} ${image}"
    echo -e "${CYAN}Backup Location:${NC} ${backup_dir}"
    echo ""
    echo -e "${BLUE}This process has 5 steps:${NC}"
    echo -e "  1. Backup current state"
    echo -e "  2. Pull new image"
    echo -e "  3. Stop old container"
    echo -e "  4. Start new container"
    echo -e "  5. Verify it's working"
    echo ""
    
    read -p "$(echo -e ${CYAN}Proceed with updating ${service_name}? [y/N]:${NC} )" -r proceed
    
    if [[ ! $proceed =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Skipped ${service_name}${NC}"
        return 0
    fi
    
    # Step 1: Backup
    if ! backup_service "${service_name}" "${backup_dir}"; then
        echo -e "${RED}Backup failed, skipping update${NC}"
        return 1
    fi
    
    # Step 2: Pull
    pull_result=0
    if ! pull_image "${service_name}"; then
        pull_result=$?
        if [ $pull_result -eq 2 ]; then
            echo -e "${BLUE}No update needed for ${service_name}${NC}"
            read -p "$(echo -e ${CYAN}Continue anyway to recreate container? [y/N]:${NC} )" -r force
            if [[ ! $force =~ ^[Yy]$ ]]; then
                return 0
            fi
        fi
    fi
    
    # Step 3: Stop
    if ! stop_container "${service_name}"; then
        echo -e "${YELLOW}Update cancelled${NC}"
        return 1
    fi
    
    # Step 4: Start
    start_container "${service_name}"
    
    # Step 5: Verify
    if ! verify_container "${service_name}"; then
        echo ""
        echo -e "${RED}════════════════════════════════════════${NC}"
        echo -e "${RED}Update may have issues!${NC}"
        echo -e "${RED}════════════════════════════════════════${NC}"
        echo -e "${YELLOW}Backup location: ${backup_dir}${NC}"
        return 1
    fi
    
    clear
    print_header "✓ ${service_name} Updated Successfully!"
    
    echo -e "${GREEN}The service has been updated and verified${NC}"
    echo -e "${CYAN}Backup saved to:${NC} ${backup_dir}"
    echo ""
    
    pause
}

# Function to clean old backups
cleanup_old_backups() {
    local backup_base_dir=$1
    local days_to_keep=${2:-7}  # Default 7 days
    
    echo ""
    echo -e "${CYAN}Checking for old backups (older than ${days_to_keep} days)...${NC}"
    
    local old_backups=$(find "${backup_base_dir}" -maxdepth 1 -type d -mtime +${days_to_keep} -name "interactive-*" 2>/dev/null)
    
    if [ -n "$old_backups" ]; then
        local count=$(echo "$old_backups" | wc -l)
        local total_size=$(du -sh $(echo "$old_backups") 2>/dev/null | awk '{sum+=$1} END {print sum}')
        
        echo -e "${YELLOW}Found ${count} old backup(s) using ~${total_size}${NC}"
        echo ""
        echo "$old_backups" | while read -r backup; do
            if [ -n "$backup" ]; then
                local backup_name=$(basename "$backup")
                local backup_size=$(du -sh "$backup" 2>/dev/null | awk '{print $1}')
                echo -e "  - ${backup_name} (${backup_size})"
            fi
        done
        
        echo ""
        read -p "$(echo -e ${YELLOW}Delete these old backups to free space? [y/N]:${NC} )" -r cleanup
        
        if [[ $cleanup =~ ^[Yy]$ ]]; then
            echo "$old_backups" | while read -r backup; do
                if [ -n "$backup" ]; then
                    rm -rf "$backup"
                    echo -e "${GREEN}✓${NC} Deleted $(basename "$backup")"
                fi
            done
            echo -e "${GREEN}Old backups cleaned up!${NC}"
        else
            echo -e "${BLUE}Keeping old backups${NC}"
        fi
    else
        echo -e "${GREEN}No old backups to clean${NC}"
    fi
    
    echo ""
}

# Main function
main() {
    clear
    
    echo -e "${MAGENTA}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║          Interactive Docker Update Manager                   ║
║                                                              ║
║            Update One Container at a Time                    ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    echo ""
    echo -e "${BLUE}This script will guide you through updating Docker containers${NC}"
    echo -e "${BLUE}one at a time, with explanations at each step.${NC}"
    echo ""
    
    # Show disk space and backup info
    echo -e "${CYAN}System Status:${NC}"
    local available_space=$(df -h "${BACKUP_BASE_DIR}" 2>/dev/null | awk 'NR==2 {print $4}' || df -h /home | awk 'NR==2 {print $4}')
    echo -e "  Available disk space: ${GREEN}${available_space}${NC}"
    
    if [ -d "${BACKUP_BASE_DIR}" ]; then
        local total_backups=$(find "${BACKUP_BASE_DIR}" -maxdepth 1 -type d -name "interactive-*" 2>/dev/null | wc -l)
        local backup_size=$(du -sh "${BACKUP_BASE_DIR}" 2>/dev/null | awk '{print $1}' || echo "0")
        echo -e "  Total backups: ${BLUE}${total_backups}${NC}"
        echo -e "  Backup storage used: ${BLUE}${backup_size}${NC}"
        echo -e "  Backup location: ${CYAN}${BACKUP_BASE_DIR}${NC}"
        
        # Offer cleanup if many backups exist
        if [ "$total_backups" -gt 10 ]; then
            echo -e "  ${YELLOW}⚠ You have ${total_backups} backups. Consider cleanup after session.${NC}"
        fi
    else
        echo -e "  ${BLUE}No backups yet${NC}"
    fi
    echo ""
    
    pause
    
    # Get list of services from compose file
    cd "${COMPOSE_DIR}"
    
    echo -e "${CYAN}Available services in docker-compose:${NC}"
    echo ""
    
    # Parse service names from compose file (stop at volumes: section)
    local services=$(awk '/^services:/,/^volumes:/ {if (/^  [a-z]/ && !/^  #/ && !/services:/ && !/volumes:/) print}' docker-compose.yml | sed 's/://g' | awk '{print $1}')
    
    local service_array=()
    local index=1
    
    while IFS= read -r service; do
        if [ -n "$service" ]; then
            service_array+=("$service")
            
            # Get the actual container name (may differ from service name)
            local container_name=$(grep -A 5 "^  ${service}:" docker-compose.yml | grep "container_name:" | head -1 | awk '{print $2}' | tr -d '"')
            
            # If no container_name defined, docker-compose uses service name
            if [ -z "$container_name" ]; then
                container_name="${service}"
            fi
            
            # Check if running and get age
            if docker ps --format "{{.Names}}" | grep -q "^${container_name}$"; then
                local age=$(docker ps --format "{{.Names}} {{.RunningFor}}" | grep "^${container_name} " | cut -d' ' -f2-)
                echo -e "  ${GREEN}${index})${NC} ${service} ${BLUE}(running)${NC} ${CYAN}[${age}]${NC}"
            else
                echo -e "  ${YELLOW}${index})${NC} ${service} ${YELLOW}(not running)${NC}"
            fi
            ((index++))
        fi
    done <<< "$services"
    
    echo -e "  ${RED}0)${NC} Exit"
    echo ""
    
    # Interactive loop
    while true; do
        echo ""
        read -p "$(echo -e ${CYAN}Select a service to update [0-$((${#service_array[@]}))]:${NC} )" -r choice
        
        if [[ "$choice" == "0" ]]; then
            echo ""
            echo -e "${GREEN}All done! Goodbye!${NC}"
            echo ""
            exit 0
        elif [[ "$choice" == "c" ]] || [[ "$choice" == "C" ]]; then
            cleanup_old_backups "${BACKUP_BASE_DIR}" 7
            continue
        fi
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#service_array[@]}" ]; then
            local selected_service="${service_array[$((choice-1))]}"
            update_service "$selected_service"
            
            echo ""
            echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
            echo -e "${CYAN}What would you like to do next?${NC}"
            echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
            echo ""
            
            # Re-display the service list
            echo -e "${CYAN}Available services:${NC}"
            echo ""
            for i in "${!service_array[@]}"; do
                local svc="${service_array[$i]}"
                
                # Get the actual container name
                local container_name=$(grep -A 5 "^  ${svc}:" docker-compose.yml | grep "container_name:" | head -1 | awk '{print $2}' | tr -d '"')
                if [ -z "$container_name" ]; then
                    container_name="${svc}"
                fi
                
                if docker ps --format "{{.Names}}" | grep -q "^${container_name}$"; then
                    local age=$(docker ps --format "{{.Names}} {{.RunningFor}}" | grep "^${container_name} " | cut -d' ' -f2-)
                    echo -e "  ${GREEN}$((i+1)))${NC} ${svc} ${BLUE}(running)${NC} ${CYAN}[${age}]${NC}"
                else
                    echo -e "  ${YELLOW}$((i+1)))${NC} ${svc} ${YELLOW}(not running)${NC}"
                fi
            done
            echo -e "  ${YELLOW}c)${NC} Clean old backups"
            echo -e "  ${RED}0)${NC} Exit"
            
        else
            echo -e "${RED}Invalid selection${NC}"
        fi
    done
    
    # Offer final cleanup
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}Session Complete!${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    
    if [ -d "${BACKUP_BASE_DIR}" ]; then
        local total_backups=$(find "${BACKUP_BASE_DIR}" -maxdepth 1 -type d -name "interactive-*" 2>/dev/null | wc -l)
        if [ "$total_backups" -gt 5 ]; then
            echo ""
            read -p "$(echo -e ${YELLOW}Clean up old backups before exiting? [y/N]:${NC} )" -r final_cleanup
            if [[ $final_cleanup =~ ^[Yy]$ ]]; then
                cleanup_old_backups "${BACKUP_BASE_DIR}" 7
            fi
        fi
    fi
}

# Run main
main

