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
- **NVIDIA GPU** with drivers installed
- **NVIDIA Container Toolkit** (for GPU monitoring inside container)
- **AxxonOne VMS** server accessible from the host
- **Artifact Portal API Token** (provided by administrator)

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

## What the Installer Does

The interactive installer will:

1. **Check prerequisites** - Verifies Docker, Docker Compose, and jq are installed
2. **Check NVIDIA support** - Tests if NVIDIA Container Toolkit is available
3. **Authenticate** - Prompts for your Artifact Portal API token
4. **Download** - Pulls the Docker image from Artifact Portal with SHA256 verification
5. **Configure** - Asks for AxxonOne server connection details
6. **Generate configs** - Creates `.env` and `docker-compose.yml` files
7. **Start service** - Launches the container and verifies it's healthy
8. **Setup auto-updates** - Configures systemd watcher for one-click updates

## Installation Directory

After installation, files are located at:

| Path | Description |
|------|-------------|
| `/opt/gpu-nt-benchmark/` | Main installation directory |
| `/opt/gpu-nt-benchmark/.env` | Configuration file |
| `/opt/gpu-nt-benchmark/docker-compose.yml` | Docker Compose configuration |
| `/opt/gpu-nt-benchmark/instance/` | SQLite database |
| `/opt/gpu-nt-benchmark/output/` | Benchmark reports |
| `/opt/AxxonSoft/TestVideos/` | Test video files (managed via web UI) |

## Usage

After installation, access the web interface at:

```
http://localhost:5000
```

### Test Videos

Test videos are **not** downloaded automatically during installation. Instead, manage them through the web UI:

1. Navigate to **Settings** in the web interface
2. Find the **Video Management** section
3. Choose from available options:
   - **Download from Artifact Portal** - Pre-packaged video packs for testing
   - **Upload custom videos** - Your own footage (up to 10GB)

Videos are stored in `/opt/AxxonSoft/TestVideos/` on the host filesystem, which AxxonOne can access for virtual camera testing.

### Common Commands

```bash
# View logs
cd /opt/gpu-nt-benchmark && docker compose logs -f

# Stop service
cd /opt/gpu-nt-benchmark && docker compose down

# Start service
cd /opt/gpu-nt-benchmark && docker compose up -d

# Check status
docker ps | grep gpu-nt-benchmark

# Manual update
sudo /opt/gpu-nt-benchmark/update.sh

# Uninstall
sudo /opt/gpu-nt-benchmark/uninstall.sh
```

## Updating

The tool supports easy updates. When a new version is available:

**Option 1: Manual update**
```bash
sudo /opt/gpu-nt-benchmark/update.sh
```

**Option 2: From the web UI**
Use the "Check for Updates" feature in Settings (if available)

Updates automatically:
- Backup the database before updating
- Download and verify the new image
- Restart the container

## Uninstalling

To completely remove the tool:

```bash
sudo /opt/gpu-nt-benchmark/uninstall.sh
```

The uninstaller will prompt before removing:
- Docker container and image
- Configuration and database files
- Test video files

## Configuration

The installer prompts for these settings:

| Setting | Description | Default |
|---------|-------------|---------|
| AxxonOne Host | Hostname/IP of AxxonOne server | localhost |
| AxxonOne Port | HTTP API port | 42000 |
| AxxonOne Username | API username | root |
| AxxonOne Password | API password | (required) |
| Site ID | Identifier for reports | default-site |

### Environment Variables

You can override settings in `/opt/gpu-nt-benchmark/.env`:

```bash
# AxxonOne Connection
AXXON_HOST=192.168.1.100
AXXON_PORT=42000
AXXON_USER=root
AXXON_PASS=your_password

# Site Configuration
SITE_ID=my-site-name

# Optional: S3 Upload for reports
S3_BUCKET=my-bucket
S3_REGION=us-east-1
S3_ACCESS_KEY=...
S3_SECRET_KEY=...
```

After changing `.env`, restart the container:
```bash
cd /opt/gpu-nt-benchmark && docker compose restart
```

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
```

## Support

For issues or questions, contact your system administrator or open an issue in this repository.

## License

Internal use only. Not for redistribution.
