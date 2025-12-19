#!/bin/bash

# Docker Compose Update Manager with Backup
# Handles docker-compose based containers gracefully

set -e

# Configuration
BACKUP_BASE_DIR="/home/deshmukh/docker-backups"
BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="${BACKUP_BASE_DIR}/compose-${BACKUP_DATE}"
LOG_FILE="${BACKUP_DIR}/update.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Create backup directory
mkdir -p "${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}/compose-files"
mkdir -p "${BACKUP_DIR}/volumes"

# Logging functions
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

# Function to find docker-compose files
find_compose_files() {
    log_info "Searching for docker-compose files..."
    
    # Search in common locations
    find /home/deshmukh -name "docker-compose.yml" -o -name "docker-compose.yaml" -o -name "compose.yml" -o -name "compose.yaml" 2>/dev/null | \
        grep -v "node_modules" | grep -v ".git"
}

# Function to backup docker-compose file and related files
backup_compose_project() {
    local compose_file=$1
    local compose_dir=$(dirname "${compose_file}")
    local project_name=$(basename "${compose_dir}")
    
    log_info "Backing up compose project: ${project_name}"
    
    # Create project backup directory
    local project_backup_dir="${BACKUP_DIR}/compose-files/${project_name}"
    mkdir -p "${project_backup_dir}"
    
    # Backup docker-compose file
    cp "${compose_file}" "${project_backup_dir}/"
    
    # Backup .env file if exists
    if [ -f "${compose_dir}/.env" ]; then
        cp "${compose_dir}/.env" "${project_backup_dir}/"
        log_info "  Backed up .env file"
    fi
    
    # Backup other related files
    for file in "${compose_dir}"/*.{yml,yaml,env,conf,config} 2>/dev/null; do
        if [ -f "$file" ]; then
            cp "$file" "${project_backup_dir}/" 2>/dev/null || true
        fi
    done
    
    log_success "Compose project backed up: ${project_name}"
}

# Function to backup volumes for compose project
backup_compose_volumes() {
    local compose_file=$1
    local compose_dir=$(dirname "${compose_file}")
    local project_name=$(basename "${compose_dir}")
    
    log_info "Backing up volumes for: ${project_name}"
    
    # Get project containers
    cd "${compose_dir}"
    local containers=$(docker-compose ps -q 2>/dev/null || docker compose ps -q 2>/dev/null)
    
    if [ -z "$containers" ]; then
        log_warning "No running containers for ${project_name}"
        return 0
    fi
    
    # Create volumes backup directory
    local volumes_backup_dir="${BACKUP_DIR}/volumes/${project_name}"
    mkdir -p "${volumes_backup_dir}"
    
    # Backup each container's volumes
    for container_id in $containers; do
        local container_name=$(docker inspect --format='{{.Name}}' "${container_id}" | sed 's/^\///')
        log_info "  Backing up volumes for: ${container_name}"
        
        # Get volume information
        local volumes=$(docker inspect --format='{{range .Mounts}}{{if eq .Type "volume"}}{{.Name}}:{{.Destination}};{{end}}{{end}}' "${container_id}")
        
        if [ -n "$volumes" ]; then
            IFS=';' read -ra VOLUME_ARRAY <<< "$volumes"
            for vol in "${VOLUME_ARRAY[@]}"; do
                if [ -z "$vol" ]; then
                    continue
                fi
                
                IFS=':' read -ra VOL_PARTS <<< "$vol"
                local vol_name="${VOL_PARTS[0]}"
                local vol_dest="${VOL_PARTS[1]}"
                
                log_info "    Volume: ${vol_name}"
                
                # Backup volume using docker run
                docker run --rm \
                    -v "${vol_name}:/source:ro" \
                    -v "${volumes_backup_dir}:/backup" \
                    alpine \
                    tar czf "/backup/${vol_name}.tar.gz" -C /source . 2>/dev/null || {
                    log_warning "    Failed to backup volume ${vol_name}"
                }
            done
        fi
        
        # Backup bind mounts
        local binds=$(docker inspect --format='{{range .Mounts}}{{if eq .Type "bind"}}{{.Source}}:{{.Destination}};{{end}}{{end}}' "${container_id}")
        
        if [ -n "$binds" ]; then
            IFS=';' read -ra BIND_ARRAY <<< "$binds"
            for bind in "${BIND_ARRAY[@]}"; do
                if [ -z "$bind" ]; then
                    continue
                fi
                
                IFS=':' read -ra BIND_PARTS <<< "$bind"
                local source="${BIND_PARTS[0]}"
                local destination="${BIND_PARTS[1]}"
                
                # Skip system mounts
                if [[ "$source" == "/etc/localtime" ]] || [[ "$source" == "/var/run/docker.sock" ]] || [[ "$source" == "/run/udev" ]]; then
                    continue
                fi
                
                if [ -d "$source" ]; then
                    local backup_name=$(echo "$destination" | sed 's/\//_/g' | sed 's/^_//')
                    log_info "    Bind mount: ${source}"
                    
                    tar -czf "${volumes_backup_dir}/${container_name}_${backup_name}.tar.gz" -C "$(dirname "$source")" "$(basename "$source")" 2>/dev/null || {
                        log_warning "    Failed to backup ${source}"
                    }
                fi
            done
        fi
    done
    
    log_success "Volumes backed up for: ${project_name}"
}

# Function to check and update compose project
update_compose_project() {
    local compose_file=$1
    local compose_dir=$(dirname "${compose_file}")
    local project_name=$(basename "${compose_dir}")
    
    log_info "=========================================="
    log_info "Processing: ${project_name}"
    log_info "Location: ${compose_dir}"
    log_info "=========================================="
    
    cd "${compose_dir}"
    
    # Check if docker-compose or docker compose
    local compose_cmd="docker-compose"
    if ! command -v docker-compose &> /dev/null; then
        compose_cmd="docker compose"
    fi
    
    # Check for updates by pulling images
    log_info "Checking for image updates..."
    ${compose_cmd} pull 2>&1 | tee -a "${LOG_FILE}"
    
    # Check if any images were updated
    if grep -q "Downloaded newer image\|Status: Downloaded newer image" "${LOG_FILE}"; then
        log_success "Updates found for ${project_name}"
        
        # Backup
        log_info "Creating backups..."
        backup_compose_project "${compose_file}"
        backup_compose_volumes "${compose_file}"
        
        # Ask for confirmation
        log_warning "Ready to update ${project_name}. Continue? (y/N)"
        read -t 15 -r proceed || proceed="n"
        
        if [[ $proceed =~ ^[Yy]$ ]]; then
            log_info "Stopping services..."
            ${compose_cmd} down
            
            log_info "Starting services with new images..."
            ${compose_cmd} up -d
            
            log_success "Updated ${project_name} successfully!"
            
            # Show logs
            log_info "Checking if services started correctly..."
            sleep 3
            ${compose_cmd} ps
            
            log_info "Recent logs:"
            ${compose_cmd} logs --tail=20
        else
            log_warning "Update skipped for ${project_name}"
        fi
    else
        log_info "No updates available for ${project_name}"
    fi
    
    echo ""
}

# Main function
main() {
    log_info "=========================================="
    log_info "Docker Compose Update Manager"
    log_info "=========================================="
    log_info "Backup Directory: ${BACKUP_DIR}"
    log_info ""
    
    # Find all compose files
    compose_files=$(find_compose_files)
    
    if [ -z "$compose_files" ]; then
        log_error "No docker-compose files found"
        exit 1
    fi
    
    log_info "Found compose files:"
    echo "$compose_files" | while read -r file; do
        echo "  - $file"
    done
    echo ""
    
    # Ask which to update
    log_info "Update options:"
    echo "  1) Update all projects"
    echo "  2) Select specific projects"
    echo "  3) Cancel"
    read -p "Choose option (1-3): " option
    
    case $option in
        1)
            # Update all
            while IFS= read -r compose_file; do
                update_compose_project "${compose_file}"
            done <<< "$compose_files"
            ;;
        2)
            # Select specific
            log_info "Enter the number of the project to update (or 'done' when finished):"
            mapfile -t files_array <<< "$compose_files"
            
            for i in "${!files_array[@]}"; do
                echo "  $((i+1))) ${files_array[$i]}"
            done
            
            while true; do
                read -p "Project number (or 'done'): " selection
                
                if [[ "$selection" == "done" ]]; then
                    break
                fi
                
                if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#files_array[@]}" ]; then
                    update_compose_project "${files_array[$((selection-1))]}"
                else
                    log_error "Invalid selection"
                fi
            done
            ;;
        3)
            log_info "Update cancelled"
            exit 0
            ;;
        *)
            log_error "Invalid option"
            exit 1
            ;;
    esac
    
    log_success "=========================================="
    log_success "Update process completed!"
    log_success "=========================================="
    log_info "Backup location: ${BACKUP_DIR}"
    log_info "Log file: ${LOG_FILE}"
}

# Run main function
main

