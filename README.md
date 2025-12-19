# Docker Update Manager

A comprehensive suite of tools for safely updating Docker containers with automatic backups, progress tracking, and rollback capabilities.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Shell](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)

## 🚀 Features

- **Interactive Updates** - Step-by-step guidance with explanations
- **Automatic Backups** - Config and volume backups before every update
- **Progress Tracking** - Shows container age and update progress
- **Smart Detection** - Handles service name vs container name differences
- **Rollback Support** - Easy recovery if updates fail
- **Multiple Modes** - Interactive, batch, and check-only options
- **Docker Compose** - First-class support for compose-managed containers

## 📦 What's Included

### Main Scripts

| Script | Purpose | Use Case |
|--------|---------|----------|
| `docker-interactive-update.sh` | ⭐ Interactive updater | **Recommended** - Update one service at a time with guidance |
| `docker-check-updates.sh` | Update checker | Quick status check, no changes made |
| `docker-compose-updater.sh` | Compose manager | Update multiple compose projects |
| `docker-update-manager.sh` | Container manager | Individual container updates |
| `docker-updater.sh` | Main menu | Quick access to all tools |
| `docker-image-info.sh` | Image inspector | View detailed image information |

### Documentation

- `docs/DOCKER-UPDATE-GUIDE.md` - Comprehensive reference guide
- `docs/UPDATE-ORDER-GUIDE.md` - Recommended update order and walkthrough

## 🎯 Quick Start

### Installation

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/docker-update-manager.git
cd docker-update-manager

# Make scripts executable
chmod +x scripts/*.sh

# Optional: Add to PATH
echo 'export PATH="$PATH:$HOME/docker-update-manager/scripts"' >> ~/.bashrc
source ~/.bashrc
```

### First Update

```bash
# Check what needs updating
./scripts/docker-check-updates.sh

# Start the interactive updater
./scripts/docker-interactive-update.sh

# Select a service and follow the prompts
# The script will:
#   1. Create backups
#   2. Pull latest image
#   3. Stop old container
#   4. Start new container
#   5. Verify it's working
```

## 💡 Usage Examples

### Check for Updates (No Changes)

```bash
./scripts/docker-check-updates.sh
```

Output shows which containers have updates available:
```
portainer         [UP TO DATE]
uptime-kuma       [UPDATE AVAILABLE]
homeassistant     [UP TO DATE]
```

### Interactive Update (Recommended)

```bash
./scripts/docker-interactive-update.sh
```

- Shows list of services with ages
- Guides through 5-step update process
- Explains each step
- Creates backups automatically
- Verifies success

### Batch Update All Services

```bash
./scripts/docker-compose-updater.sh
```

- Updates all services in docker-compose projects
- Backs up compose files and volumes
- Can update all at once or select specific ones

### Quick Menu

```bash
./scripts/docker-updater.sh
```

Presents a menu with all options:
1. Check for updates
2. Update compose projects
3. Update individual containers
4. View backup history
5. Read documentation
6. Container status overview

## 🛡️ Safety Features

### Automatic Backups

Before every update, the script creates:
- Container configuration (JSON format)
- Environment variables
- Volume data (compressed archives)
- Bind mount data

Backups are stored in: `~/docker-backups/`

### Rollback Instructions

If an update goes wrong:

```bash
# Find your backup
ls -lth ~/docker-backups/

# Stop the problematic service
cd /path/to/docker-compose
docker-compose stop SERVICE_NAME

# Restore volumes from backup
cd ~/docker-backups/BACKUP_DIR/volumes/
tar -xzf VOLUME_NAME.tar.gz -C /destination/path/

# Restart service
docker-compose up -d SERVICE_NAME
```

## 📋 Requirements

- Docker Engine 20.10+
- Docker Compose v2.0+ (or docker-compose 1.29+)
- Bash 4.0+
- Standard Unix tools (grep, awk, tar)
- Sufficient disk space for backups

## 🎓 How It Works

### The Update Process

```
1. BACKUP
   └─ Save config & volumes

2. PULL NEW IMAGE
   └─ Download latest version

3. STOP OLD CONTAINER
   └─ Graceful shutdown
   
4. START NEW CONTAINER
   └─ Reconnect volumes

5. VERIFY
   └─ Check logs & health
```

### Smart Container Name Handling

The script automatically handles cases where service names differ from container names:

```yaml
# docker-compose.yml
mqtt:                      # Service name
  container_name: mosquitto  # Actual container name
```

- Uses service name for docker-compose commands
- Uses container name for direct docker commands
- Works seamlessly in all scenarios

## 📊 Container Age Tracking

Shows when each container was last updated:

```
1) portainer (running) [5 minutes ago]      ← Just updated
2) uptime-kuma (running) [10 minutes ago]   ← Just updated
3) homeassistant (running) [2 months ago]   ← Needs update
```

Helps prioritize:
- 🔴 2+ months old → High priority
- 🟡 1 month old → Medium priority
- 🟢 < 1 week → Low priority

## 🐛 Troubleshooting

### Service Won't Start After Update

```bash
# Check logs
docker logs CONTAINER_NAME

# Try recreating
docker-compose stop SERVICE_NAME
docker-compose up -d SERVICE_NAME
```

### "Container name already in use"

```bash
# Remove old container
docker stop CONTAINER_NAME
docker rm CONTAINER_NAME

# Recreate
docker-compose up -d SERVICE_NAME
```

### Out of Disk Space

```bash
# Clean old images
docker image prune -a

# Clean old backups
rm -rf ~/docker-backups/OLD_BACKUP_DIR
```

## 📁 Project Structure

```
docker-update-manager/
├── scripts/
│   ├── docker-interactive-update.sh    ← Main interactive tool
│   ├── docker-check-updates.sh         ← Update checker
│   ├── docker-compose-updater.sh       ← Compose manager
│   ├── docker-update-manager.sh        ← Container manager
│   ├── docker-updater.sh               ← Menu system
│   └── docker-image-info.sh            ← Image inspector
├── docs/
│   ├── DOCKER-UPDATE-GUIDE.md          ← Complete reference
│   └── UPDATE-ORDER-GUIDE.md           ← Update walkthrough
├── README.md                            ← This file
└── CHANGELOG.md                         ← Version history
```

## 🔧 Configuration

### Custom Backup Location

Edit the script and change:

```bash
BACKUP_BASE_DIR="/home/deshmukh/docker-backups"
```

To your preferred location.

### Compose File Location

The script automatically searches for docker-compose files in your home directory. To specify a custom location, edit:

```bash
COMPOSE_DIR="/path/to/your/compose"
```

## 🤝 Contributing

Contributions are welcome! This project was developed through real-world testing and user feedback.

### Found a Bug?

Please open an issue with:
- Description of the problem
- Terminal output (if applicable)
- Docker version: `docker --version`
- Compose version: `docker-compose --version`

### Have an Idea?

Open an issue with:
- Feature description
- Use case
- Expected behavior

## 📝 License

MIT License - See LICENSE file for details

## 🙏 Acknowledgments

- Developed through extensive real-world testing
- Incorporates feedback from production use
- Handles edge cases discovered in homelab environments

## 📞 Support

- **Documentation**: See `docs/` folder
- **Issues**: GitHub Issues
- **Discussions**: GitHub Discussions

## 🚀 Roadmap

Planned features:
- [ ] Email notifications on updates
- [ ] Webhook support
- [ ] Update scheduling
- [ ] Health check integration
- [ ] Multi-host support
- [ ] Web UI

## 📈 Version History

See [CHANGELOG.md](CHANGELOG.md) for detailed version history.

## ⚡ Quick Reference

```bash
# Check updates
./scripts/docker-check-updates.sh

# Interactive update (best for first time)
./scripts/docker-interactive-update.sh

# Batch update
./scripts/docker-compose-updater.sh

# View menu
./scripts/docker-updater.sh

# Check container ages
docker ps --format "{{.Names}} {{.RunningFor}}"

# View backups
ls -lth ~/docker-backups/
```

---

**Made with ❤️ for homelabbers**

