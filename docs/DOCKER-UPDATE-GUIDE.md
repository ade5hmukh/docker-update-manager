# Docker Container Update Manager

This suite of scripts helps you safely check for and apply updates to your Docker containers with comprehensive backup capabilities.

## 📋 Available Scripts

### 1. `docker-check-updates.sh` - Quick Update Checker
**Purpose**: Quickly check which containers have available updates without making any changes.

**Usage**:
```bash
./docker-check-updates.sh
```

**Features**:
- Non-destructive - doesn't modify anything
- Fast overview of all containers
- Color-coded status for easy reading
- Automatically skips local/custom images

**When to use**: Run this first to see what needs updating before taking any action.

---

### 2. `docker-compose-updater.sh` - Compose Project Manager
**Purpose**: Update Docker Compose managed containers with full backup support.

**Usage**:
```bash
./docker-compose-updater.sh
```

**Features**:
- Automatically finds all docker-compose files in your home directory
- Backs up compose files, .env files, and related configs
- Backs up all volumes (both named volumes and bind mounts)
- Interactive selection - update all or choose specific projects
- Graceful shutdown and restart of services
- Shows logs after update to verify success

**What it backs up**:
- Docker compose files (docker-compose.yml, etc.)
- Environment files (.env)
- Docker volumes (as .tar.gz archives)
- Bind mount directories (as .tar.gz archives)

**When to use**: Best for containers managed with docker-compose (like your homeassistant, zigbee2mqtt, etc.)

---

### 3. `docker-update-manager.sh` - Individual Container Manager
**Purpose**: Update individual containers (non-compose) with detailed backup options.

**Usage**:
```bash
./docker-update-manager.sh
```

**Features**:
- Checks each container for updates
- Backs up container configurations (inspect data, env vars, commands)
- Backs up volumes and bind mounts
- Optional: Create full container snapshot (committed image)
- Interactive confirmation before each update
- Provides recovery instructions

**What it backs up**:
- Container configuration (JSON format)
- Environment variables
- Startup commands
- All volumes and bind mounts
- Optional: Full container snapshot as image

**When to use**: For standalone containers not managed by compose, or when you need more granular control.

---

## 🗂️ Backup Structure

All backups are stored in `/home/deshmukh/docker-backups/` with the following structure:

```
docker-backups/
├── YYYYMMDD_HHMMSS/              # Individual container backups
│   ├── update.log                 # Detailed log of operations
│   ├── container-configs/         # Container configurations
│   │   ├── container_name.json    # Full container inspect data
│   │   ├── container_name.env     # Environment variables
│   │   └── container_name.cmd     # Startup command
│   └── volumes/                   # Volume backups
│       └── container_name/
│           └── *.tar.gz           # Compressed volume data
│
└── compose-YYYYMMDD_HHMMSS/      # Compose project backups
    ├── update.log
    ├── compose-files/
    │   └── project_name/
    │       ├── docker-compose.yml
    │       └── .env
    └── volumes/
        └── project_name/
            └── *.tar.gz
```

---

## 🚀 Recommended Workflow

### First Time Use

1. **Check what needs updating**:
   ```bash
   ./docker-check-updates.sh
   ```

2. **Review the output** - note which containers have updates

3. **Decide your approach**:
   - If most containers are from docker-compose → use `docker-compose-updater.sh`
   - If you want granular control → use `docker-update-manager.sh`

### For Compose-Managed Containers (Recommended)

```bash
# Check updates first
./docker-check-updates.sh

# Update compose projects
./docker-compose-updater.sh

# Choose option 1 to update all, or option 2 to select specific projects
```

### For Individual Containers

```bash
# Check updates
./docker-check-updates.sh

# Update with backups
./docker-update-manager.sh

# Follow prompts for each container
```

---

## 🔧 Your Current Setup

Based on the scan, you have:

- **19 running containers**
- **Docker Compose files found**:
  - `/home/deshmukh/docker-compose.yml`
  - `/home/deshmukh/homelab-docker/docker-compose.yml`
  - `/home/deshmukh/SkyLite-UX/docker-compose.yml`
  - `/home/deshmukh/SkyLite-UX/.devcontainer/docker-compose.yml`
  - `/home/deshmukh/h1b-visa-monitor/docker-compose.yml`

### Container Categories:

**Home Automation** (Best updated via compose):
- homeassistant
- esphome
- zigbee2mqtt
- zwavejs2mqtt
- mosquitto

**Media Management** (Best updated via compose):
- jellyfin
- sonarr
- radarr
- lidarr
- transmission

**System Tools**:
- portainer (can update through its UI)
- uptime-kuma
- influxdb
- mariadb

**Custom/Dev Containers**:
- skylite-ux (local image, won't auto-update)
- grampsweb

---

## ⚠️ Important Notes

### Containers That Will Be Skipped

The scripts automatically skip:
1. **Local/custom images** (like `skylite-ux:pwa`)
2. **Hash-based images** (images without tags, just digests)
3. **System mounts** (`/etc/localtime`, `/var/run/docker.sock`, etc.)

### Before Updating

✅ **DO**:
- Run `docker-check-updates.sh` first to see what needs updating
- Ensure you have enough disk space for backups
- Consider doing updates during low-usage times
- Check that containers are healthy before updating

❌ **DON'T**:
- Update all containers at once without testing
- Delete backups immediately after updating
- Update containers with active critical processes

### After Updating

1. **Verify services are running**:
   ```bash
   docker ps
   ```

2. **Check logs for errors**:
   ```bash
   docker logs container_name
   ```

3. **Test functionality** of updated services

4. **Keep backups** for at least a few days until you're sure everything works

---

## 🔄 Rollback/Recovery

If something goes wrong after an update:

### For Compose Projects

```bash
# Go to the project directory
cd /path/to/compose/project

# Stop the updated containers
docker-compose down

# Restore the compose file from backup
cp /home/deshmukh/docker-backups/compose-YYYYMMDD_HHMMSS/compose-files/PROJECT_NAME/docker-compose.yml .

# Restore .env if needed
cp /home/deshmukh/docker-backups/compose-YYYYMMDD_HHMMSS/compose-files/PROJECT_NAME/.env .

# Restore volumes (if needed)
cd /home/deshmukh/docker-backups/compose-YYYYMMDD_HHMMSS/volumes/PROJECT_NAME/
# Extract the needed .tar.gz files to their original locations

# Start with old version
docker-compose up -d
```

### For Individual Containers

```bash
# Check the backup location (shown in the script output)
cd /home/deshmukh/docker-backups/YYYYMMDD_HHMMSS/

# View the original container configuration
cat container-configs/CONTAINER_NAME.json

# Restore volume from backup
cd volumes/CONTAINER_NAME/
tar -xzf VOLUME_NAME.tar.gz -C /original/volume/path/

# Recreate container using the backed-up configuration
# (You'll need to reconstruct the docker run command from the JSON)
```

### Restoring from Snapshot

If you created a full snapshot:

```bash
# Stop and remove the current container
docker stop container_name
docker rm container_name

# Load the snapshot
docker load < /home/deshmukh/docker-backups/YYYYMMDD_HHMMSS/container_name-snapshot.tar.gz

# Run container from snapshot
docker run -d --name container_name backup-container_name:YYYYMMDD_HHMMSS
```

---

## 📊 Monitoring Updates

### Set Up a Cron Job

To check for updates daily:

```bash
# Edit crontab
crontab -e

# Add this line to check daily at 6 AM
0 6 * * * /home/deshmukh/docker-check-updates.sh > /home/deshmukh/docker-update-check.log 2>&1
```

### Check Backup Disk Usage

```bash
du -sh /home/deshmukh/docker-backups/*
```

### Clean Old Backups

After confirming updates are successful:

```bash
# List backups older than 7 days
find /home/deshmukh/docker-backups/ -type d -mtime +7 -maxdepth 1

# Delete backups older than 7 days (be careful!)
find /home/deshmukh/docker-backups/ -type d -mtime +7 -maxdepth 1 -exec rm -rf {} \;
```

---

## 🆘 Troubleshooting

### Script shows "command not found"

```bash
chmod +x docker-*.sh
```

### Permission denied errors

```bash
# Run with sudo if needed
sudo ./docker-compose-updater.sh
```

### Not enough disk space for backups

```bash
# Check available space
df -h /home/deshmukh

# Clean old backups
rm -rf /home/deshmukh/docker-backups/OLD_BACKUP_DIR
```

### Container won't start after update

1. Check logs: `docker logs container_name`
2. Check if port is already in use: `netstat -tlnp | grep PORT`
3. Restore from backup (see Rollback section)

### Volume restore fails

```bash
# Check volume exists
docker volume ls

# Manually restore volume
docker run --rm -v VOLUME_NAME:/target -v /backup/location:/source alpine sh -c "cd /target && tar xzf /source/backup.tar.gz"
```

---

## 📝 Best Practices

1. **Regular Checks**: Run `docker-check-updates.sh` weekly
2. **Backup Retention**: Keep backups for at least 7 days
3. **Test Updates**: Update one service at a time for critical systems
4. **Monitor Logs**: Check logs after every update
5. **Document Changes**: Keep notes of what was updated and when
6. **Staged Updates**: Update test environments before production

---

## 🔐 Security Considerations

- Backups contain sensitive data (environment variables, configs)
- Secure the backup directory:
  ```bash
  chmod 700 /home/deshmukh/docker-backups
  ```
- Consider encrypting sensitive backups
- Don't share backup files without sanitizing

---

## 📞 Quick Reference Commands

```bash
# Quick check
./docker-check-updates.sh

# Update compose projects
./docker-compose-updater.sh

# Update individual containers
./docker-update-manager.sh

# View all containers
docker ps -a

# View all images
docker images

# Check disk usage
docker system df

# Clean up unused images
docker image prune -a

# View backup size
du -sh /home/deshmukh/docker-backups/
```

---

## 📅 Maintenance Schedule Suggestion

| Frequency | Task |
|-----------|------|
| Daily | Check container health |
| Weekly | Run update checker |
| Bi-weekly | Apply non-critical updates |
| Monthly | Apply all updates + cleanup old backups |
| Quarterly | Review and test disaster recovery |

---

Good luck with your updates! 🚀

