#!/bin/bash

# Docker Updater - Master Script
# Helps you choose the right update method

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

clear

echo -e "${MAGENTA}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║          Docker Container Update Manager Suite               ║
║                                                              ║
║              Safe Updates with Backup Support                ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo ""
echo -e "${CYAN}What would you like to do?${NC}"
echo ""
echo -e "  ${GREEN}1)${NC} Check for updates (no changes made)"
echo -e "  ${GREEN}2)${NC} Update Docker Compose projects (recommended)"
echo -e "  ${GREEN}3)${NC} Update individual containers"
echo -e "  ${GREEN}4)${NC} View backup history"
echo -e "  ${GREEN}5)${NC} Read documentation"
echo -e "  ${GREEN}6)${NC} Container status overview"
echo -e "  ${GREEN}7)${NC} Exit"
echo ""
read -p "$(echo -e ${CYAN}Enter your choice [1-7]:${NC} )" choice

case $choice in
    1)
        echo ""
        echo -e "${BLUE}Running update checker...${NC}"
        echo ""
        ./docker-check-updates.sh
        ;;
    2)
        echo ""
        echo -e "${BLUE}Launching Docker Compose updater...${NC}"
        echo ""
        ./docker-compose-updater.sh
        ;;
    3)
        echo ""
        echo -e "${BLUE}Launching individual container updater...${NC}"
        echo ""
        ./docker-update-manager.sh
        ;;
    4)
        echo ""
        echo -e "${BLUE}Backup History:${NC}"
        echo ""
        if [ -d "/home/deshmukh/docker-backups" ]; then
            echo -e "${CYAN}Location: /home/deshmukh/docker-backups${NC}"
            echo ""
            ls -lth /home/deshmukh/docker-backups/ | head -20
            echo ""
            echo -e "${YELLOW}Total backup size:${NC}"
            du -sh /home/deshmukh/docker-backups/ 2>/dev/null || echo "No backups yet"
        else
            echo -e "${YELLOW}No backups found yet${NC}"
        fi
        ;;
    5)
        echo ""
        if [ -f "DOCKER-UPDATE-GUIDE.md" ]; then
            if command -v less &> /dev/null; then
                less DOCKER-UPDATE-GUIDE.md
            elif command -v more &> /dev/null; then
                more DOCKER-UPDATE-GUIDE.md
            else
                cat DOCKER-UPDATE-GUIDE.md
            fi
        else
            echo -e "${RED}Documentation not found${NC}"
        fi
        ;;
    6)
        echo ""
        echo -e "${BLUE}Container Status Overview:${NC}"
        echo ""
        echo -e "${CYAN}Running Containers:${NC}"
        docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" | head -20
        echo ""
        echo -e "${CYAN}Resource Usage:${NC}"
        docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" | head -20
        echo ""
        echo -e "${CYAN}Disk Usage:${NC}"
        docker system df
        ;;
    7)
        echo ""
        echo -e "${GREEN}Goodbye!${NC}"
        exit 0
        ;;
    *)
        echo ""
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${YELLOW}Press Enter to continue...${NC}"
read

