#!/bin/bash

# Docker Container Update Manager with Backup
# This script checks for updates, creates backups, and updates containers gracefully

set -e

# Configuration
BACKUP_BASE_DIR="/home/deshmukh/docker-backups"
BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="${BACKUP_BASE_DIR}/${BACKUP_DATE}"
LOG_FILE="${BACKUP_DIR}/update.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Create backup directory
mkdir -p "${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}/container-configs"
mkdir -p "${BACKUP_DIR}/volumes"

# Logging function
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "${LOG_FILE}"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1" | tee -a "${LOG_FILE}"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1" | tee -a "${LOG_FILE}"
}

log_info() {
    echo -e "${BLUE}[ℹ]${NC} $1" | tee -a "${LOG_FILE}"
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1" | tee -a "${LOG_FILE}"
}

# Function to check if an image update is available
check_update_available() {
    local image=$1
    local container_name=$2
    
    log_info "Checking for updates: ${container_name} (${image})"
    
    # Skip checking for images with hash IDs
    if [[ "${image}" =~ ^[a-f0-9]{12}$ ]]; then
        log_warning "Skipping ${container_name} - image is using hash ID"
        return 1
    fi
    
    # Skip local/custom images
    if [[ "${image}" == *":"* ]] && [[ ! "${image}" =~ \. ]] && [[ ! "${image}" =~ ^(ghcr|lscr|docker\.io|quay\.io|gcr\.io) ]]; then
        if [[ "${image}" != *"/"* ]] || [[ "${image}" == "skylite-ux:"* ]]; then
            log_warning "Skipping ${container_name} - appears to be local/custom image"
            return 1
        fi
    fi
    
    # Get current image digest
    local current_digest=$(docker inspect --format='{{.Image}}' "${container_name}" 2>/dev/null)
    
    if [ -z "$current_digest" ]; then
        log_error "Failed to get current digest for ${container_name}"
        return 1
    fi
    
    # Pull latest image info (not the image itself yet)
    log_info "Pulling latest image metadata for ${image}..."
    if ! docker pull "${image}" --quiet 2>&1 | tee -a "${LOG_FILE}"; then
        log_error "Failed to pull ${image}"
        return 1
    fi
    
    # Get latest image digest
    local latest_digest=$(docker inspect --format='{{.Id}}' "${image}" 2>/dev/null)
    
    if [ "$current_digest" != "$latest_digest" ]; then
        log_success "Update available for ${container_name}"
        echo "${current_digest}|${latest_digest}"
        return 0
    else
        log_info "No update available for ${container_name}"
        return 1
    fi
}

# Function to backup container configuration
backup_container_config() {
    local container_id=$1
    local container_name=$2
    
    log_info "Backing up configuration for ${container_name}..."
    
    # Export container config
    docker inspect "${container_id}" > "${BACKUP_DIR}/container-configs/${container_name}.json"
    
    # Export environment variables
    docker inspect --format='{{range .Config.Env}}{{println .}}{{end}}' "${container_id}" > "${BACKUP_DIR}/container-configs/${container_name}.env"
    
    # Export running command
    docker inspect --format='{{.Config.Cmd}}' "${container_id}" > "${BACKUP_DIR}/container-configs/${container_name}.cmd"
    
    log_success "Configuration backed up for ${container_name}"
}

# Function to backup container volumes
backup_container_volumes() {
    local container_name=$1
    
    log_info "Backing up volumes for ${container_name}..."
    
    # Get all mounts
    local mounts=$(docker inspect --format='{{range .Mounts}}{{.Type}}:{{.Source}}:{{.Destination}};{{end}}' "${container_name}")
    
    if [ -z "$mounts" ]; then
        log_warning "No volumes found for ${container_name}"
        return 0
    fi
    
    # Create container-specific backup directory
    local container_backup_dir="${BACKUP_DIR}/volumes/${container_name}"
    mkdir -p "${container_backup_dir}"
    
    # Parse and backup each mount
    IFS=';' read -ra MOUNT_ARRAY <<< "$mounts"
    for mount in "${MOUNT_ARRAY[@]}"; do
        if [ -z "$mount" ]; then
            continue
        fi
        
        IFS=':' read -ra MOUNT_PARTS <<< "$mount"
        local mount_type="${MOUNT_PARTS[0]}"
        local source="${MOUNT_PARTS[1]}"
        local destination="${MOUNT_PARTS[2]}"
        
        # Skip certain system mounts
        if [[ "$source" == "/etc/localtime" ]] || [[ "$source" == "/var/run/docker.sock" ]] || [[ "$source" == "/run/udev" ]]; then
            continue
        fi
        
        # Backup bind mounts and volumes
        if [ -d "$source" ] || [ -f "$source" ]; then
            local backup_name=$(echo "$destination" | sed 's/\//_/g' | sed 's/^_//')
            log_info "  Backing up: ${source} -> ${backup_name}"
            
            if [ -d "$source" ]; then
                tar -czf "${container_backup_dir}/${backup_name}.tar.gz" -C "$(dirname "$source")" "$(basename "$source")" 2>/dev/null || {
                    log_warning "  Failed to backup ${source} (may be empty or inaccessible)"
                }
            elif [ -f "$source" ]; then
                cp "$source" "${container_backup_dir}/${backup_name}" || {
                    log_warning "  Failed to backup file ${source}"
                }
            fi
        fi
    done
    
    log_success "Volumes backed up for ${container_name}"
}

# Function to export container as image (snapshot)
backup_container_snapshot() {
    local container_name=$1
    
    log_info "Creating snapshot of ${container_name}..."
    
    # Commit container to a backup image
    docker commit "${container_name}" "backup-${container_name}:${BACKUP_DATE}" > /dev/null
    
    # Export the image
    docker save "backup-${container_name}:${BACKUP_DATE}" | gzip > "${BACKUP_DIR}/${container_name}-snapshot.tar.gz"
    
    log_success "Snapshot created for ${container_name}"
}

# Function to update a container
update_container() {
    local container_id=$1
    local container_name=$2
    local image=$3
    
    log_info "=========================================="
    log_info "Updating ${container_name}..."
    log_info "=========================================="
    
    # Backup configuration
    backup_container_config "${container_id}" "${container_name}"
    
    # Backup volumes
    backup_container_volumes "${container_name}"
    
    # Create snapshot (optional but recommended)
    log_info "Do you want to create a full snapshot of ${container_name}? (y/N)"
    read -t 10 -r create_snapshot || create_snapshot="n"
    if [[ $create_snapshot =~ ^[Yy]$ ]]; then
        backup_container_snapshot "${container_name}"
    fi
    
    # Get container details for recreation
    local container_json="${BACKUP_DIR}/container-configs/${container_name}.json"
    
    log_info "Stopping container ${container_name}..."
    docker stop "${container_name}" || {
        log_error "Failed to stop ${container_name}"
        return 1
    }
    
    log_info "Removing old container ${container_name}..."
    docker rm "${container_name}" || {
        log_error "Failed to remove ${container_name}"
        return 1
    }
    
    log_info "Pulling latest image ${image}..."
    docker pull "${image}" || {
        log_error "Failed to pull ${image}"
        return 1
    }
    
    log_success "Container ${container_name} updated successfully!"
    log_warning "NOTE: You need to recreate the container using docker-compose or your original run command"
    log_info "Backup location: ${container_backup_dir}"
}

# Main function
main() {
    log_info "=========================================="
    log_info "Docker Container Update Manager"
    log_info "=========================================="
    log_info "Backup Directory: ${BACKUP_DIR}"
    log_info ""
    
    # Get all running containers
    containers=$(docker ps --format '{{.ID}}|{{.Names}}|{{.Image}}')
    
    if [ -z "$containers" ]; then
        log_error "No running containers found"
        exit 1
    fi
    
    # Arrays to store containers with updates
    declare -a containers_with_updates
    
    log_info "Checking for updates..."
    echo ""
    
    # Check each container for updates
    while IFS='|' read -r container_id container_name image; do
        if check_update_available "${image}" "${container_name}"; then
            containers_with_updates+=("${container_id}|${container_name}|${image}")
        fi
        echo ""
    done <<< "$containers"
    
    # Summary
    log_info "=========================================="
    log_info "Update Summary"
    log_info "=========================================="
    
    if [ ${#containers_with_updates[@]} -eq 0 ]; then
        log_success "All containers are up to date!"
        exit 0
    fi
    
    log_warning "Found ${#containers_with_updates[@]} container(s) with available updates:"
    for container_info in "${containers_with_updates[@]}"; do
        IFS='|' read -r cid cname cimage <<< "$container_info"
        echo "  - ${cname} (${cimage})"
    done
    echo ""
    
    # Ask for confirmation
    log_info "Do you want to proceed with updates? (y/N)"
    read -r proceed
    
    if [[ ! $proceed =~ ^[Yy]$ ]]; then
        log_info "Update cancelled by user"
        exit 0
    fi
    
    # Update each container
    for container_info in "${containers_with_updates[@]}"; do
        IFS='|' read -r container_id container_name image <<< "$container_info"
        update_container "${container_id}" "${container_name}" "${image}"
        echo ""
    done
    
    log_success "=========================================="
    log_success "Update process completed!"
    log_success "=========================================="
    log_info "Backup location: ${BACKUP_DIR}"
    log_info "Log file: ${LOG_FILE}"
    
    # Show how to recreate containers
    echo ""
    log_info "To recreate the containers, use:"
    log_info "  - If using docker-compose: cd to the compose directory and run 'docker-compose up -d'"
    log_info "  - If using docker run: refer to the backed-up configs in ${BACKUP_DIR}/container-configs/"
}

# Run main function
main

