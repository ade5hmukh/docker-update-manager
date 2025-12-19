# Interactive Update Guide - Recommended Order

## 🎯 Your 18 Services

Here's what each service does and the recommended update order:

### ✅ Safe to Update First (Low Risk)

These have minimal dependencies and short downtime is okay:

1. **uptime-kuma** - Monitoring dashboard (has update available!)
2. **portainer** - Docker management UI
3. **jellyfin** - Media server
4. **transmission-openvpn** - Torrent client with VPN

### ⚠️ Update Second (Medium Priority)

These are important but can tolerate brief downtime:

5. **sonarr** - TV show management
6. **radarr** - Movie management  
7. **lidarr** - Music management
8. **jackett** - Torrent indexer
9. **grampsweb** - Genealogy web interface
10. **esphome** - ESP device management

### 🔴 Update Carefully (High Priority/Dependencies)

These have dependencies or are critical - update during low usage:

11. **influxdb** - Time-series database (used by Home Assistant)
12. **mariadb** - SQL database (used by Home Assistant)
13. **mqtt** (mosquitto) - Message broker (used by zigbee/zwave)
14. **zigbee2mqtt** - Zigbee device controller
15. **zwavejs2mqtt** - Z-Wave device controller
16. **homeassistant** - Home automation hub (update LAST in this group)

### 🚫 Skip These

17. **skylite-ux** - Custom local image (can't auto-update)
18. **skylite-ux-db** - Postgres for skylite (managed separately)

---

## 🚀 How to Start

### Method 1: Interactive Script (Recommended)

```bash
cd /home/deshmukh
./docker-interactive-update.sh
```

**What happens:**
- You'll see a menu of all services
- Pick a service by number
- Script walks you through 5 steps with explanations
- You confirm each step
- Move to next service when ready

### Method 2: Manual Process (If you want more control)

For each service you want to update:

```bash
cd /home/deshmukh/homelab-docker

# 1. Pull latest image
docker-compose pull SERVICE_NAME

# 2. Recreate the container
docker-compose up -d SERVICE_NAME

# 3. Check logs
docker-compose logs -f SERVICE_NAME

# 4. Verify it's working
docker-compose ps SERVICE_NAME
```

---

## 📋 Example Update Session

Here's a sample session updating uptime-kuma:

```
$ ./docker-interactive-update.sh

[Menu shows]
1) uptime-kuma (running)
...

Select service: 1

[STEP 1: BACKUP]
- Backs up config and volumes
- Press ENTER to continue

[STEP 2: PULL IMAGE]  
- Downloads latest image
- Shows if update available
- Press ENTER to continue

[STEP 3: STOP CONTAINER]
- Confirms: "Ready to stop? [y/N]:" → type y
- Stops and removes old container
- Press ENTER to continue

[STEP 4: START NEW CONTAINER]
- Creates new container
- Starts service
- Waits 5 seconds
- Press ENTER to continue

[STEP 5: VERIFY]
- Shows status and logs
- Asks: "Is it working? [Y/n]:" → type y
- Update complete!

[Back to menu - pick next service or exit]
```

---

## 🎓 Understanding the Process

### What's Actually Happening?

```
Before:                          After:
┌──────────────┐                ┌──────────────┐
│ Container    │                │ Container    │
│ uptime-kuma  │   Updated      │ uptime-kuma  │  
│              │   ──────→      │              │
│ Image: old   │                │ Image: NEW   │
└──────┬───────┘                └──────┬───────┘
       │                                │
       │ Volume stays connected!        │
       ↓                                ↓
┌──────────────┐                ┌──────────────┐
│   Data/      │   No changes   │   Data/      │
│   Config     │   ──────→      │   Config     │
└──────────────┘                └──────────────┘
```

### Why Your Data is Safe

1. **Volumes are separate** from containers
2. **Containers are temporary**, volumes are permanent
3. **Docker-compose remembers** which volumes to reconnect
4. **Even if container fails**, volumes remain intact
5. **Backups are created** before any changes

### What Each Step Does

| Step | Action | Downtime? | Reversible? |
|------|--------|-----------|-------------|
| 1. Backup | Save config & data | ❌ No | N/A |
| 2. Pull | Download new image | ❌ No | ✅ Yes |
| 3. Stop | Stop old container | ✅ **YES** | ✅ Yes |
| 4. Start | Start new container | ✅ **YES** | ✅ Yes |
| 5. Verify | Check it works | ❌ No | ✅ Yes |

**Total downtime per service: ~10-30 seconds**

---

## 💡 Pro Tips

### Before You Start

✅ **Do this during low usage** (early morning/late night)  
✅ **Start with non-critical services** to get comfortable  
✅ **Have another terminal open** to check web interfaces  
✅ **Keep backups for at least a week**  

### During Updates

✅ **Read each step explanation** - understand what's happening  
✅ **Check logs carefully** in step 5  
✅ **Test the service** in your browser before moving on  
✅ **Take breaks** - no need to rush  

### After Updates

✅ **Monitor for 24 hours** - watch for issues  
✅ **Check automations** work in Home Assistant  
✅ **Verify media plays** in Jellyfin  
✅ **Test downloads** in transmission/sonarr/radarr  

---

## 🆘 If Something Goes Wrong

### Service Won't Start

```bash
# Check the logs
cd /home/deshmukh/homelab-docker
docker-compose logs SERVICE_NAME

# Try stopping and starting again
docker-compose stop SERVICE_NAME
docker-compose start SERVICE_NAME
```

### Logs Show Errors

```bash
# Check the exact error message
docker-compose logs --tail=50 SERVICE_NAME

# Sometimes just needs more time
sleep 10
docker-compose logs SERVICE_NAME
```

### Need to Rollback

```bash
# Find your backup
ls -lth /home/deshmukh/docker-backups/

# Stop the service
cd /home/deshmukh/homelab-docker
docker-compose stop SERVICE_NAME

# Restore the volume backup
cd /home/deshmukh/docker-backups/YOUR_BACKUP_DIR/volumes/
tar -xzf VOLUME_NAME.tar.gz -C /original/path/

# Start service
cd /home/deshmukh/homelab-docker
docker-compose start SERVICE_NAME
```

### Complete Recovery

If everything goes wrong:

```bash
# Stop all services
cd /home/deshmukh/homelab-docker
docker-compose down

# Restore all volumes from backup
# (locate your backup directory first)

# Restart all services
docker-compose up -d
```

---

## 📞 Quick Commands

```bash
# View all running containers
docker ps

# Check specific service logs
docker-compose -f /home/deshmukh/homelab-docker/docker-compose.yml logs SERVICE_NAME

# Restart a service
docker restart CONTAINER_NAME

# Check service health
docker-compose -f /home/deshmukh/homelab-docker/docker-compose.yml ps

# View recent backups
ls -lth /home/deshmukh/docker-backups/

# Check disk space
df -h
docker system df
```

---

## 🎯 Ready to Start?

### Recommended First Update: uptime-kuma

This is perfect to start with because:
- ✅ Has an update available (we detected it earlier)
- ✅ Not critical if it's down briefly  
- ✅ Simple service with no dependencies
- ✅ Good test to understand the process

### Start the Interactive Updater:

```bash
cd /home/deshmukh
./docker-interactive-update.sh
```

Then select: **2** (uptime-kuma)

### Or Update Manually:

```bash
cd /home/deshmukh/homelab-docker
docker-compose pull uptime-kuma
docker-compose up -d uptime-kuma
docker-compose logs -f uptime-kuma
```

---

**Good luck! Take your time and read each step carefully.** 🚀

