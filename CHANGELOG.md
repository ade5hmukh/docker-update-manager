# Changelog

All notable changes to this project will be documented in this file.

## [1.0.0] - 2025-12-19

### 🎉 Initial Release

A comprehensive Docker container update manager with automatic backups and interactive guidance.

### ✨ Features

- **Interactive Update Mode** - Step-by-step guidance through the update process
- **Automatic Backups** - Config and volume backups before every update
- **Container Age Display** - Shows when each container was last updated
- **Progress Bars** - Native Docker progress bars during image pulls
- **Smart Name Handling** - Correctly handles service name vs container name differences
- **Multiple Update Modes**:
  - Interactive (one at a time with explanations)
  - Batch (update multiple services)
  - Check-only (see what needs updating)
- **Docker Compose Support** - First-class support for compose-managed containers
- **Rollback Capability** - Easy recovery if updates fail

### 🐛 Bug Fixes

During development and testing, the following bugs were identified and fixed:

#### Bug #1: Container Removal Not Verified
- **Issue**: Script didn't check if `docker-compose rm` succeeded
- **Impact**: Container name conflicts on recreation
- **Fix**: Added error checking and automatic fallback to `docker rm -f`

#### Bug #2: Volumes Shown as Services
- **Issue**: Parsed volumes section as services (showed 37 instead of 18)
- **Impact**: Confusing service list with non-service items
- **Fix**: Limited parsing to services section only using awk range

#### Bug #3: False "Not Running" Status
- **Issue**: Checked for service names instead of container names
- **Impact**: Services like 'mqtt' (container: mosquitto) shown as not running
- **Fix**: Look up actual container names from docker-compose.yml

#### Bug #4: Stop/Remove Used Wrong Names
- **Issue**: Fallback docker commands used service names not container names
- **Impact**: Updates failed for services with different container names
- **Fix**: Use actual container names for direct docker commands

### 🎨 Improvements

#### Container Age Display
- Shows when each container was last updated/restarted
- Helps prioritize which containers need updates
- Updates in real-time as you progress

#### Progress Bar Enhancement
- Removed piped output that caused verbose line-by-line progress
- Native Docker progress bars now display properly
- Clean, professional output during image pulls

#### Service List Re-display
- Service list now re-displays after each update
- No need to remember service numbers
- Always see current status

### 📚 Documentation

- Complete reference guide
- Update order recommendations
- Troubleshooting section
- Rollback instructions
- Configuration examples

### 🔧 Technical Details

- Handles TTY vs non-TTY output correctly
- Proper error checking throughout
- Image digest comparison for update detection
- Backup integrity with tar compression
- Service/container name mapping

### 🎯 Scripts Included

1. `docker-interactive-update.sh` - Main interactive updater
2. `docker-check-updates.sh` - Quick update checker
3. `docker-compose-updater.sh` - Compose project manager
4. `docker-update-manager.sh` - Individual container manager
5. `docker-updater.sh` - Menu system
6. `docker-image-info.sh` - Image information tool

### 🧪 Testing

- Tested on Ubuntu 22.04 LTS
- Docker Engine 24.0+
- Docker Compose v2.20+
- 19 production containers
- Multiple docker-compose projects
- Various container configurations

### 📦 Packaging

- Organized project structure
- Comprehensive README
- Detailed documentation
- Clear installation instructions

### 🙏 Acknowledgments

Developed through extensive real-world testing with:
- 4 major bugs discovered and fixed
- 2 significant UX improvements
- User-driven feature enhancements
- Production homelab environment

---

## Future Releases

### Planned for v1.1.0
- [ ] Email notifications
- [ ] Webhook support
- [ ] Update scheduling
- [ ] Health check integration

### Planned for v2.0.0
- [ ] Multi-host support
- [ ] Web UI
- [ ] REST API
- [ ] Update policies

---

**Format**: Based on [Keep a Changelog](https://keepachangelog.com/)  
**Versioning**: [Semantic Versioning](https://semver.org/)

