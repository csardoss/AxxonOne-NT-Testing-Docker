# AxxonOne NeuralTracker GPU Benchmark Tool

A web-based GPU benchmark application for testing NeuralTracker performance on AxxonOne VMS servers.

## What This Tool Does

The GPU NeuralTracker Benchmark Tool automates GPU performance testing by:

1. **Adding virtual cameras** with NeuralTracker AI detectors to your AxxonOne server
2. **Scaling camera count** until GPU efficiency drops below threshold (default: 95%)
3. **Fine-tuning** to find the optimal number of cameras your GPU can handle
4. **Running stability tests** to verify performance over time
5. **Generating benchmark reports** in JSON format

This helps you determine the maximum number of NeuralTracker-enabled cameras your GPU can process efficiently.

## Requirements

- **Docker Engine** (version 20.10+)
- **Docker Compose** (version 2.0+)
- **NVIDIA GPU** with drivers installed (optional but recommended)
- **NVIDIA Container Toolkit** (for GPU monitoring inside container)
- **AxxonOne VMS** server accessible from the host
- **Web browser** to approve device pairing on the Artifact Portal

## Quick Install

Run this single command to download and start the installer:

```bash
curl -fsSL https://raw.githubusercontent.com/csardoss/AxxonOne-NT-Testing-Docker/main/install.sh | sudo bash
```

Or if you prefer to review the script first:

```bash
# Download the script
curl -fsSL https://raw.githubusercontent.com/csardoss/AxxonOne-NT-Testing-Docker/main/install.sh -o install.sh

# Review it
less install.sh

# Run it
sudo bash install.sh
```

### Automated Install (Skip Pairing)

For unattended or scripted installs, set the `ARTIFACT_PORTAL_TOKEN` environment variable to skip the interactive device pairing:

```bash
ARTIFACT_PORTAL_TOKEN=apt_xxxxx curl -fsSL https://raw.githubusercontent.com/csardoss/AxxonOne-NT-Testing-Docker/main/install.sh | sudo bash
```

## What the Installer Does

The interactive installer will:

1. **Check prerequisites** - Verifies Docker, Docker Compose, and jq are installed
2. **Check NVIDIA support** - Tests if NVIDIA Container Toolkit is available
3. **Authenticate** - Device pairing with Artifact Portal (display code, approve in browser)
4. **Download** - Pulls the Docker image from Artifact Portal with SHA256 verification
5. **Configure** - Asks for AxxonOne server connection details
6. **Generate configs** - Creates `.env` and `docker-compose.yml` files
7. **Start service** - Launches the container and verifies it's healthy
8. **Setup auto-updates** - Configures systemd watcher for one-click updates from web UI

## Installation Directory

After installation, files are located at:

| Path | Description |
|------|-------------|
| `/opt/gpu-nt-benchmark/` | Main installation directory |
| `/opt/gpu-nt-benchmark/.env` | Configuration file (contains version tracking) |
| `/opt/gpu-nt-benchmark/.artifact-token` | Session token from device pairing (chmod 600) |
| `/opt/gpu-nt-benchmark/.artifact-token-expires` | Token expiry timestamp (chmod 600) |
| `/opt/gpu-nt-benchmark/.installed-version` | Currently installed version |
| `/opt/gpu-nt-benchmark/docker-compose.yml` | Docker Compose configuration |
| `/opt/gpu-nt-benchmark/update.sh` | Update script (self-updating) |
| `/opt/gpu-nt-benchmark/uninstall.sh` | Uninstall script |
| `/opt/gpu-nt-benchmark/instance/` | SQLite database |
| `/opt/gpu-nt-benchmark/output/` | Benchmark reports |
| `/opt/gpu-nt-benchmark/update-signal/` | Signal files for web UI updates |
| `/opt/AxxonSoft/TestVideos/` | Test video files (managed via web UI) |

## Usage

After installation, access the web interface at:

```
http://YOUR_HOST:5000
```

### Test Videos

Test videos are **not** downloaded automatically during installation. Manage them through the web UI:

1. Navigate to **Settings** in the web interface
2. Find the **Video Management** section
3. Choose from available options:
   - **Download from Artifact Portal** - Pre-packaged video packs for testing
   - **Upload custom videos** - Your own footage

Videos are stored in `/opt/AxxonSoft/TestVideos/` on the host filesystem, which AxxonOne can access for virtual camera testing.

### Common Commands

```bash
# View logs
cd /opt/gpu-nt-benchmark && docker compose logs -f

# Stop service
cd /opt/gpu-nt-benchmark && docker compose down

# Start service
cd /opt/gpu-nt-benchmark && docker compose up -d

# Restart service
cd /opt/gpu-nt-benchmark && docker compose restart

# Check status
docker ps | grep gpu-nt-benchmark

# Check health
curl -s http://localhost:5000/api/health | jq

# Manual update
sudo /opt/gpu-nt-benchmark/update.sh

# Uninstall
sudo /opt/gpu-nt-benchmark/uninstall.sh
```

## Device Pairing & Token Management

The tool uses **device pairing** to authenticate with the Artifact Portal. Instead of embedding a static API token, the installer displays a short pairing code that you approve on the portal website. This issues a **30-day session token**.

### How Pairing Works

1. **During install**: A pairing code is displayed (e.g., `ABCD-1234`)
2. **Approve**: Open the approval URL in your browser and approve the code
3. **Token issued**: A 30-day session token is saved to `.artifact-token`
4. **Re-pairing**: When the token expires, re-pair from **Settings** in the web UI

### Token Expiry

When the session token expires:
- The **Settings** page shows "Token expired" with a "Re-pair Device" button
- Update checks and video pack downloads will show a re-pair prompt
- Click "Re-pair Device" to get a new pairing code and approve it

### Token Files

| File | Purpose |
|------|---------|
| `.artifact-token` | Current session token (bind-mounted into container) |
| `.artifact-token-expires` | ISO 8601 expiry timestamp |

Both files are bind-mounted between the host and container so re-pairing from the web UI persists across container restarts.

## Updating

The tool supports multiple update methods with automatic self-updating capabilities.

### Update Methods

**Option 1: From the Web UI (Recommended)**
1. Go to **Dashboard** or **Settings**
2. If an update is available, click **Update Now**
3. The update runs automatically in the background

**Option 2: Manual Command**
```bash
sudo /opt/gpu-nt-benchmark/update.sh
```

### What Happens During an Update

1. **Database backup** - Automatically backs up SQLite database
2. **Download** - Pulls new Docker image from Artifact Portal
3. **Verify** - SHA256 checksum verification
4. **Self-update scripts** - If newer versions of `update.sh` or `docker-compose.yml` are available, they are automatically extracted and applied
5. **Restart** - Container is recreated with the new image

### Version Tracking

The system tracks multiple version numbers in `.env`:

| Variable | Description |
|----------|-------------|
| `APP_SHA256` | SHA256 of current Docker image (for update detection) |
| `COMPOSE_VERSION` | Version of docker-compose.yml template |
| `UPDATE_SCRIPT_VERSION` | Version of update.sh script |

When a new Docker image contains newer versions of these components, they are automatically updated during the update process.

### Systemd Update Service

The installer configures a systemd path watcher that monitors for update requests from the web UI:

```bash
# Check status
sudo systemctl status gpu-nt-benchmark-update.path

# View update logs
sudo journalctl -u gpu-nt-benchmark-update.service -f
```

## Uninstalling

To completely remove the tool:

```bash
sudo /opt/gpu-nt-benchmark/uninstall.sh
```

The uninstaller will prompt before removing:
- Docker container and image
- Configuration and database files
- Test video files
- Systemd services

## Configuration

### Initial Configuration

The installer prompts for these settings:

| Setting | Description | Default |
|---------|-------------|---------|
| AxxonOne Host | Hostname/IP of AxxonOne server | localhost |
| AxxonOne Port | HTTP API port | 42000 |
| AxxonOne Username | API username | root |
| AxxonOne Password | API password | (required) |
| Site ID | Identifier for reports | (hostname) |

### Environment Variables

Configuration is stored in `/opt/gpu-nt-benchmark/.env`:

```bash
# AxxonOne Connection
AXXON_HOST=192.168.1.100
AXXON_PORT=42000
AXXON_USER=root
AXXON_PASS=your_password

# Site Configuration
SITE_ID=my-site-name
HOST_ID=my-hostname

# Artifact Portal (for updates)
ARTIFACT_PORTAL_URL=https://artifacts.digitalsecurityguard.com
# Token is managed via device pairing (.artifact-token file)
# For automated installs, set ARTIFACT_PORTAL_TOKEN env var to skip pairing

# Version Tracking (managed automatically)
APP_SHA256=abc123...
COMPOSE_VERSION=5
UPDATE_SCRIPT_VERSION=2

# Optional: S3 Upload for reports
S3_BUCKET=my-bucket
S3_REGION=us-east-1
S3_ACCESS_KEY=...
S3_SECRET_KEY=...
```

After changing `.env`, restart the container:
```bash
cd /opt/gpu-nt-benchmark && docker compose down && docker compose up -d
```

### Updating AxxonOne Credentials

You can update AxxonOne server credentials through the web UI:

1. Go to **Settings**
2. Find **AxxonOne Server Credentials**
3. Enter new credentials and click **Save**

Credentials are stored in the SQLite database and take effect immediately.

## Architecture

### Docker Container

The benchmark tool runs as a Docker container with:
- Flask web application on port 5000
- SQLite database for configuration and test history
- Access to host's NVIDIA GPU (if available)
- Read-only access to AxxonOne's NeuroSDK filters and GPU cache

### Host Integration

The container communicates with the host through:
- **Signal files** (`/opt/gpu-nt-benchmark/update-signal/`) - For triggering updates from web UI
- **Mounted volumes** - For database persistence, video files, and GPU cache access
- **host.docker.internal** - For connecting to AxxonOne on the host

### Systemd Services

| Service | Purpose |
|---------|---------|
| `gpu-nt-benchmark-update.path` | Watches for update signal files |
| `gpu-nt-benchmark-update.service` | Runs update.sh when triggered |

## Troubleshooting

### Docker not found
```bash
# Install Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
```

### NVIDIA Container Toolkit not working
```bash
# Install NVIDIA Container Toolkit
# See: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html

# Test it
docker run --rm --gpus all nvidia/cuda:11.0-base nvidia-smi
```

### Cannot connect to AxxonOne
- Verify the AxxonOne server is running
- Check firewall allows port 42000
- Verify credentials are correct
- Test with: `curl -u user:pass http://AXXON_HOST:42000/camera/list`

### Container won't start
```bash
# Check logs
cd /opt/gpu-nt-benchmark && docker compose logs

# Check container status
docker ps -a | grep gpu-nt-benchmark

# Verify image exists
docker images | grep gpu-nt-benchmark
```

### Update stuck "in progress"
If the web UI shows "Update in Progress" but it's not running:
```bash
# Remove the stale signal file
sudo rm -f /opt/gpu-nt-benchmark/update-signal/update-requested

# Refresh the web page
```

### CPU/RAM metrics not showing (Docker)
Ensure the AxxonOne server credentials are saved in the web UI Settings. The container needs to connect to AxxonOne's Prometheus endpoint on the host.

### AxxonOne version not detected (Docker)
The tool fetches version info from AxxonOne's API. Ensure:
1. Credentials are saved in Settings
2. AxxonOne server is accessible from the container
3. The API user has sufficient permissions

## Logs

### Container logs
```bash
cd /opt/gpu-nt-benchmark && docker compose logs -f
```

### Update service logs
```bash
sudo journalctl -u gpu-nt-benchmark-update.service -f
```

### Application logs (inside container)
```bash
docker exec -it gpu-nt-benchmark cat /app/logs/app.log
```

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review container logs for error messages
3. Contact your system administrator
4. Open an issue in this repository

## Version History

See [CHANGELOG.md](https://github.com/csardoss/Axxon-NT-Testing-App/blob/main/CHANGELOG.md) in the main application repository for detailed release notes.

## License

Internal use only. Not for redistribution.
