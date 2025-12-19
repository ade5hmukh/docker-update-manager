# Feature: Disk Space Management & Backup History

## ✨ New Feature Added

**Date:** December 19, 2025  
**Requested by:** User  
**Status:** ✅ **IMPLEMENTED**

---

## 🎯 What Was Added

The interactive update script now includes comprehensive disk space management:

1. **Disk Space Checking** - Before creating backups
2. **Existing Backup Display** - Shows previous backups for each service
3. **Space Warnings** - Alerts when disk space is low
4. **Backup Cleanup** - Easy removal of old backups
5. **System Status Dashboard** - Shows space and backup info at startup

---

## 📊 Features in Detail

### 1. System Status at Startup

When you start the script, you now see:

```
╔══════════════════════════════════════════════════════════════╗
║          Interactive Docker Update Manager                   ║
╚══════════════════════════════════════════════════════════════╝

This script will guide you through updating Docker containers
one at a time, with explanations at each step.

System Status:
  Available disk space: 896G
  Total backups: 7
  Backup storage used: 2.1G
  Backup location: /home/deshmukh/docker-backups
```

**Shows:**
- ✅ How much disk space is available
- ✅ How many backups exist
- ✅ How much space backups are using
- ✅ Where backups are stored
- ⚠️ Warning if you have many backups (>10)

---

### 2. Disk Space Check Before Backup

Before creating each backup:

```
STEP 1: Creating Backup for homeassistant

What we're backing up:
  • Container configuration
  • Volume data
  • Current image

Disk Space Check:
  Available: 896GB
  Estimated backup size: ~3GB
  ✓ Sufficient space available
```

**Features:**
- Calculates estimated backup size based on container size
- Warns if space is low (< 5GB available)
- Asks for confirmation if space is tight
- Prevents running out of disk space mid-backup

**Warning Levels:**
```
Available > 5GB + needed:  ✓ Sufficient space available
Available < 5GB + needed:  ⚠ Space is tight, but should be sufficient
Available < 5GB:           ⚠ WARNING: Low disk space!
```

---

### 3. Existing Backup History

Before creating a new backup, shows previous backups:

```
Existing backups for homeassistant:
  1) interactive-20251219_184332-homeassistant
     Size: 1.2G | Age: 2 hours ago
  2) interactive-20251218_103045-homeassistant
     Size: 1.1G | Age: 1 day ago
  3) interactive-20251215_083012-homeassistant
     Size: 1.0G | Age: 4 days ago
  
  Note: New backup will be created. Old backups are kept for safety.
```

**Shows:**
- ✅ All previous backups for this service
- ✅ Size of each backup
- ✅ How old each backup is
- ✅ Numbered list for easy reference

**Benefits:**
- Know what backups already exist
- See how much space each takes
- Decide if you need to clean old ones
- Confidence that you have fallback options

---

### 4. Backup Cleanup Option

New menu option to clean old backups:

```
Available services:
  1) portainer (running) [5 minutes ago]
  2) uptime-kuma (running) [10 minutes ago]
  ...
  c) Clean old backups
  0) Exit

Select a service to update [0-18]: c
```

**Cleanup Process:**

```
Checking for old backups (older than 7 days)...

Found 5 old backup(s) using ~4.2GB
  - interactive-20251210_103045-homeassistant (1.1G)
  - interactive-20251209_083012-portainer (250M)
  - interactive-20251208_143022-mariadb (2.5G)
  - interactive-20251207_093015-influxdb (300M)
  - interactive-20251206_113045-sonarr (150M)

Delete these old backups to free space? [y/N]: y

✓ Deleted interactive-20251210_103045-homeassistant
✓ Deleted interactive-20251209_083012-portainer
✓ Deleted interactive-20251208_143022-mariadb
✓ Deleted interactive-20251207_093015-influxdb
✓ Deleted interactive-20251206_113045-sonarr
Old backups cleaned up!
```

**Features:**
- Finds backups older than 7 days (configurable)
- Shows total size that will be freed
- Lists each backup with size
- Asks for confirmation before deleting
- Safe - only deletes backups, never containers or volumes

---

### 5. Exit Cleanup Prompt

When exiting, if you have many backups:

```
═══════════════════════════════════════════════════════
Session Complete!
═══════════════════════════════════════════════════════

Clean up old backups before exiting? [y/N]: y

Checking for old backups (older than 7 days)...
...
```

**Triggers when:**
- You have more than 5 backups total
- Offers cleanup before exiting
- Optional - can skip if you want to keep them

---

## 🔧 Technical Implementation

### Disk Space Calculation

```bash
# Get available space
available_gb=$(df -BG /backup/location | awk 'NR==2 {print $4}' | sed 's/G//')

# Estimate backup size
container_size=$(docker ps -a --size --format "{{.Size}}" | ...)
estimated_size_gb=$((container_size / 1024 + 1))

# Check if sufficient
min_required=$((estimated_size_gb + 2))  # 2GB buffer
if [ "$available_gb" -lt "$min_required" ]; then
    echo "WARNING: Low disk space!"
fi
```

### Finding Existing Backups

```bash
# Find backups for specific service
find /backup/dir -maxdepth 1 -type d -name "*${service_name}" | sort -r

# Get size and age
du -sh backup_dir
find backup_dir -maxdepth 0 -printf '%Ar\n'
```

### Cleanup Logic

```bash
# Find old backups (>7 days)
find /backup/dir -maxdepth 1 -type d -mtime +7 -name "interactive-*"

# Calculate total size
du -sh $(echo $old_backups) | awk '{sum+=$1} END {print sum}'

# Delete after confirmation
rm -rf backup_dir
```

---

## 📊 Benefits

### 1. Prevents Disk Space Issues
- ✅ Check before backup, not during
- ✅ Estimate size needed
- ✅ Warn if space is low
- ✅ Prevent failed backups due to full disk

### 2. Better Backup Management
- ✅ See what backups exist
- ✅ Know how much space they use
- ✅ Easy cleanup of old backups
- ✅ Keep backups organized

### 3. Informed Decisions
- ✅ Know if you have room for backup
- ✅ See backup history before creating new one
- ✅ Choose when to clean old backups
- ✅ Understand space usage

### 4. Automatic Maintenance
- ✅ Warns when too many backups
- ✅ Offers cleanup at exit
- ✅ Prevents backup directory bloat
- ✅ Keeps system healthy

---

## 🎓 Usage Guide

### Check Space Before Starting

The script automatically shows space at startup. If you see:
```
Available disk space: 12GB
⚠ You have 15 backups. Consider cleanup after session.
```

Consider cleaning old backups first:
- Select option `c` from menu
- Or manually: `rm -rf ~/docker-backups/OLD_BACKUP_DIR`

### During Updates

If you see:
```
⚠ WARNING: Low disk space!
Continue anyway? [y/N]:
```

**Options:**
1. **Stop and clean** - Exit, clean old backups, restart
2. **Continue** - Risky, backup might fail
3. **Skip backup** - Not recommended

### Managing Backups

**View all backups:**
```bash
ls -lth ~/docker-backups/
```

**Check total size:**
```bash
du -sh ~/docker-backups/
```

**Manual cleanup:**
```bash
# Delete backups older than 7 days
find ~/docker-backups/ -type d -mtime +7 -name "interactive-*" -exec rm -rf {} \;
```

**Keep specific backup:**
```bash
# All others can be deleted, but keep this one
mv ~/docker-backups/important-backup ~/docker-backups-keep/
```

---

## ⚙️ Configuration

### Change Cleanup Age

Default is 7 days. To change:

Edit the script and modify:
```bash
cleanup_old_backups "${BACKUP_BASE_DIR}" 14  # 14 days instead of 7
```

### Change Warning Threshold

Default warns at 5GB. To change:

Edit the script:
```bash
if [ "$available_gb" -lt 10 ]; then  # Warn at 10GB instead of 5GB
    echo "WARNING: Low disk space!"
fi
```

### Change Backup Location

Edit at top of script:
```bash
BACKUP_BASE_DIR="/path/to/your/backups"
```

---

## 📋 Backup Retention Strategy

### Recommended Approach

**Keep backups for:**
- **1 day** - For immediate rollback if update fails
- **7 days** - For discovering issues that appear later
- **30 days** - For major changes (optional)

**Cleanup schedule:**
- After each update session (if >10 backups)
- Weekly (delete >7 days old)
- Monthly (delete >30 days old)

### Your Current Status

Based on your system:
```
Available: 896GB
Used by backups: 2.1G
Total backups: 7

Status: ✅ Healthy
Action: No cleanup needed yet
```

### When to Clean

**Clean when:**
- ⚠️ Available space < 50GB
- ⚠️ Backup storage > 10GB
- ⚠️ More than 20 backups
- ⚠️ Backups older than 30 days

**Keep when:**
- ✅ Recent updates (< 7 days)
- ✅ Before major changes
- ✅ Known good states
- ✅ Plenty of disk space

---

## 🔍 Troubleshooting

### "Insufficient disk space" Warning

**Check actual space:**
```bash
df -h /home/deshmukh
```

**Free up space:**
```bash
# Clean old Docker images
docker image prune -a

# Clean old backups
./docker-interactive-update.sh
# Select option 'c'

# Clean Docker system
docker system prune -a
```

### Backup Size Estimation Wrong

The script estimates based on container size. Actual backup size depends on:
- Volume data size
- Compression ratio
- Number of volumes

**Check actual container + volume size:**
```bash
docker ps -a --size
docker system df -v
```

### Can't Delete Old Backups

**Check permissions:**
```bash
ls -la ~/docker-backups/
```

**Manual deletion:**
```bash
sudo rm -rf ~/docker-backups/OLD_BACKUP_DIR
```

---

## 📊 Example Session

```
$ ./docker-interactive-update.sh

System Status:
  Available disk space: 896G
  Total backups: 7
  Backup storage used: 2.1G
  ⚠ You have 7 backups. Consider cleanup after session.

Select service: 6 (homeassistant)

STEP 1: Creating Backup

Disk Space Check:
  Available: 896GB
  Estimated backup size: ~3GB
  ✓ Sufficient space available

Existing backups for homeassistant:
  1) interactive-20251219_184332-homeassistant
     Size: 1.2G | Age: 2 hours ago
  Note: New backup will be created.

[Backup proceeds...]

[After several updates...]

Select service: c (cleanup)

Checking for old backups (older than 7 days)...
No old backups to clean

Select service: 0 (exit)

Session Complete!
```

---

## ✅ Summary

### What's New:
- ✅ Disk space checking before backups
- ✅ Existing backup history display
- ✅ Space warnings and estimates
- ✅ Easy backup cleanup option
- ✅ System status dashboard
- ✅ Exit cleanup prompt

### Benefits:
- ✅ Never run out of space mid-backup
- ✅ Know what backups exist
- ✅ Easy maintenance
- ✅ Informed decisions
- ✅ Automatic warnings

### Files Modified:
- `scripts/docker-interactive-update.sh`

---

**Status:** ✅ Live and ready to use!

Your updates are now safer with automatic space management! 🚀

