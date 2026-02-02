#!/bin/bash
#
# GPU NeuralTracker Benchmark - Installation Script
# Downloads and installs the benchmark tool via Artifact Portal
#
# Usage: curl -fsSL https://raw.githubusercontent.com/csardoss/AxxonOne-NT-Testing-Docker/main/install.sh | sudo bash
#

set -e

# Open /dev/tty for interactive input (needed when script is piped)
exec 3</dev/tty || exec 3<&0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Configuration
INSTALL_DIR="/opt/gpu-nt-benchmark"
VIDEO_DIR="/opt/AxxonSoft/TestVideos"
ARTIFACT_PORTAL_URL="${ARTIFACT_PORTAL_URL:-https://artifacts.digitalsecurityguard.com}"
ARTIFACT_PROJECT="axxon-nt-test-tool"
ARTIFACT_TOOL="docker-container"
ARTIFACT_PLATFORM="linux-amd64"
ARTIFACT_FILENAME="gpu-nt-benchmark.tar.gz"
IMAGE_NAME="gpu-nt-benchmark:latest"
DEFAULT_API_TOKEN="apt_vuqFUcCxCk2TmJaT6741cRVBFBNXAvrdsVfuLbdYKxI"

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "\n${CYAN}${BOLD}>>> $1${NC}"; }

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (sudo)"
        exit 1
    fi
}

# Print banner
print_banner() {
    echo -e "${CYAN}"
    cat << 'EOF'
  ╔═══════════════════════════════════════════════════════════════╗
  ║                                                               ║
  ║   GPU NeuralTracker Benchmark Tool                            ║
  ║   Installation Script                                         ║
  ║                                                               ║
  ║   Automated GPU performance testing for AxxonOne VMS          ║
  ║                                                               ║
  ╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Print prerequisites
print_prerequisites() {
    log_step "Prerequisites"
    echo ""
    echo -e "${BOLD}Before proceeding, ensure you have:${NC}"
    echo ""
    echo "  1. Docker Engine installed (version 20.10+)"
    echo "  2. Docker Compose installed (version 2.0+)"
    echo "  3. NVIDIA GPU with drivers installed (optional but recommended)"
    echo "  4. NVIDIA Container Toolkit installed (for GPU support)"
    echo "  5. Access to Artifact Portal with valid API token"
    echo "  6. Network access to AxxonOne server"
    echo ""
    echo -e "${YELLOW}Note: Without NVIDIA Container Toolkit, GPU monitoring will be limited${NC}"
    echo ""
    read -p "Do you want to continue? [y/N] " -n 1 -r REPLY <&3
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Installation cancelled"
        exit 0
    fi
}

# Check Docker installation
check_docker() {
    log_step "Checking Docker Installation"

    if ! command -v docker &> /dev/null; then
        log_warn "Docker is not installed"
        echo ""
        read -p "Would you like to install Docker automatically? [Y/n] " -n 1 -r REPLY <&3
        echo
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            log_error "Docker is required. Install manually with:"
            echo "  curl -fsSL https://get.docker.com | sh"
            exit 1
        fi

        log_info "Installing Docker..."
        curl -fsSL https://get.docker.com | sh

        # Start Docker service
        log_info "Starting Docker service..."
        systemctl start docker
        systemctl enable docker

        log_success "Docker installed successfully"
    fi

    DOCKER_VERSION=$(docker --version | grep -oP '\d+\.\d+' | head -1)
    log_success "Docker found: version $DOCKER_VERSION"

    # Check Docker daemon is running
    if ! docker info &> /dev/null; then
        log_warn "Docker daemon is not running"
        log_info "Starting Docker service..."
        systemctl start docker
        sleep 2
        if ! docker info &> /dev/null; then
            log_error "Failed to start Docker daemon"
            exit 1
        fi
    fi
    log_success "Docker daemon is running"
}

# Check Docker Compose
check_docker_compose() {
    log_step "Checking Docker Compose"

    if docker compose version &> /dev/null; then
        COMPOSE_VERSION=$(docker compose version --short 2>/dev/null || echo "unknown")
        log_success "Docker Compose found: version $COMPOSE_VERSION"
        COMPOSE_CMD="docker compose"
    elif command -v docker-compose &> /dev/null; then
        COMPOSE_VERSION=$(docker-compose --version | grep -oP '\d+\.\d+' | head -1)
        log_success "Docker Compose (standalone) found: version $COMPOSE_VERSION"
        COMPOSE_CMD="docker-compose"
    else
        log_warn "Docker Compose is not installed"
        log_info "Installing Docker Compose plugin..."

        if command -v apt-get &> /dev/null; then
            apt-get update && apt-get install -y docker-compose-plugin
        elif command -v yum &> /dev/null; then
            yum install -y docker-compose-plugin
        elif command -v dnf &> /dev/null; then
            dnf install -y docker-compose-plugin
        else
            log_error "Could not auto-install Docker Compose. Please install manually."
            exit 1
        fi

        if docker compose version &> /dev/null; then
            COMPOSE_VERSION=$(docker compose version --short 2>/dev/null || echo "unknown")
            log_success "Docker Compose installed: version $COMPOSE_VERSION"
            COMPOSE_CMD="docker compose"
        else
            log_error "Docker Compose installation failed"
            exit 1
        fi
    fi
}

# Check for jq (JSON parser)
check_jq() {
    log_step "Checking Required Tools"

    if ! command -v jq &> /dev/null; then
        log_info "Installing jq..."
        if command -v apt-get &> /dev/null; then
            apt-get update && apt-get install -y jq
        elif command -v yum &> /dev/null; then
            yum install -y jq
        else
            log_error "jq is not installed and could not be auto-installed"
            echo "Please install jq manually: https://stedolan.github.io/jq/download/"
            exit 1
        fi
    fi
    log_success "jq found"
}

# Install NVIDIA Container Toolkit
install_nvidia_toolkit() {
    log_info "Installing NVIDIA Container Toolkit..."

    if command -v apt-get &> /dev/null; then
        # Debian/Ubuntu
        log_info "Adding NVIDIA container toolkit repository..."
        curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg 2>/dev/null

        curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
            sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
            tee /etc/apt/sources.list.d/nvidia-container-toolkit.list > /dev/null

        apt-get update
        apt-get install -y nvidia-container-toolkit

    elif command -v yum &> /dev/null; then
        # RHEL/CentOS
        curl -s -L https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo | \
            tee /etc/yum.repos.d/nvidia-container-toolkit.repo > /dev/null
        yum install -y nvidia-container-toolkit

    elif command -v dnf &> /dev/null; then
        # Fedora
        curl -s -L https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo | \
            tee /etc/yum.repos.d/nvidia-container-toolkit.repo > /dev/null
        dnf install -y nvidia-container-toolkit

    else
        log_error "Could not determine package manager. Please install manually."
        return 1
    fi

    # Configure Docker to use NVIDIA runtime
    log_info "Configuring Docker for NVIDIA runtime..."
    nvidia-ctk runtime configure --runtime=docker

    # Restart Docker to apply changes
    log_info "Restarting Docker..."
    systemctl restart docker
    sleep 3

    log_success "NVIDIA Container Toolkit installed"
    return 0
}

# Check NVIDIA Container Toolkit
check_nvidia() {
    log_step "Checking NVIDIA Container Toolkit"

    NVIDIA_AVAILABLE=false

    # Check for NVIDIA GPU
    if command -v nvidia-smi &> /dev/null; then
        GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
        if [[ -n "$GPU_NAME" ]]; then
            log_success "NVIDIA GPU detected: $GPU_NAME"
        else
            log_warn "nvidia-smi found but no GPU detected"
            return
        fi
    else
        log_warn "No NVIDIA GPU detected (nvidia-smi not found)"
        log_info "Continuing without GPU support"
        return
    fi

    # Check for NVIDIA Container Toolkit
    if docker run --rm --gpus all ubuntu nvidia-smi &> /dev/null; then
        log_success "NVIDIA Container Toolkit is working"
        NVIDIA_AVAILABLE=true
    else
        log_warn "NVIDIA Container Toolkit not available"
        echo ""
        read -p "Would you like to install NVIDIA Container Toolkit? [Y/n] " -n 1 -r REPLY <&3
        echo

        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            if install_nvidia_toolkit; then
                # Verify it works now
                if docker run --rm --gpus all ubuntu nvidia-smi &> /dev/null; then
                    log_success "NVIDIA Container Toolkit is now working"
                    NVIDIA_AVAILABLE=true
                else
                    log_warn "Installation completed but GPU access still not working"
                    log_info "Continuing without GPU support"
                fi
            else
                log_warn "NVIDIA Container Toolkit installation failed"
                log_info "Continuing without GPU support"
            fi
        else
            log_info "Continuing without GPU support"
        fi
    fi
}

# Validate Artifact Portal token
validate_token() {
    local token="$1"

    log_info "Validating API token..."

    # Try to get presigned URL (validates token and artifact existence)
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${ARTIFACT_PORTAL_URL}/api/v2/presign-latest" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -d "{
            \"project\": \"${ARTIFACT_PROJECT}\",
            \"tool\": \"${ARTIFACT_TOOL}\",
            \"platform_arch\": \"${ARTIFACT_PLATFORM}\",
            \"latest_filename\": \"${ARTIFACT_FILENAME}\"
        }" 2>/dev/null || echo -e "\n000")

    HTTP_CODE=$(echo "$RESPONSE" | tail -1)
    BODY=$(echo "$RESPONSE" | sed '$d')

    if [[ "$HTTP_CODE" == "200" ]]; then
        # Check if we got a valid URL back
        if echo "$BODY" | jq -e '.url' > /dev/null 2>&1; then
            log_success "API token validated"
            return 0
        else
            log_error "Artifact not found in portal"
            return 1
        fi
    elif [[ "$HTTP_CODE" == "401" ]] || [[ "$HTTP_CODE" == "403" ]]; then
        log_error "Invalid or expired API token"
        return 1
    elif [[ "$HTTP_CODE" == "000" ]]; then
        log_error "Cannot connect to Artifact Portal at $ARTIFACT_PORTAL_URL"
        return 1
    else
        log_error "Unexpected response from Artifact Portal (HTTP $HTTP_CODE)"
        echo "Response: $BODY"
        return 1
    fi
}

# Get Artifact Portal token
get_artifact_token() {
    log_step "Artifact Portal Authentication"

    # Use embedded token by default
    ARTIFACT_TOKEN="$DEFAULT_API_TOKEN"

    if [[ -n "$ARTIFACT_TOKEN" ]]; then
        log_info "Using embedded API token..."
        if validate_token "$ARTIFACT_TOKEN"; then
            return 0
        else
            log_warn "Embedded token failed, prompting for manual entry"
            ARTIFACT_TOKEN=""
        fi
    fi

    # Fall back to manual entry if no embedded token or it failed
    echo ""
    echo "Enter your Artifact Portal API token."
    echo "This token will be securely stored for future updates."
    echo ""

    while true; do
        read -sp "API Token: " ARTIFACT_TOKEN <&3
        echo

        if [[ -z "$ARTIFACT_TOKEN" ]]; then
            log_error "Token cannot be empty"
            continue
        fi

        if validate_token "$ARTIFACT_TOKEN"; then
            break
        else
            read -p "Try again? [y/N] " -n 1 -r REPLY <&3
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "Installation cancelled"
                exit 0
            fi
        fi
    done
}

# Create installation directories
create_directories() {
    log_step "Creating Installation Directories"

    mkdir -p "$INSTALL_DIR"
    mkdir -p "$INSTALL_DIR/instance"
    mkdir -p "$INSTALL_DIR/output"
    mkdir -p "$INSTALL_DIR/update-signal"
    mkdir -p "$VIDEO_DIR"

    log_success "Created $INSTALL_DIR"
    log_success "Created $VIDEO_DIR"
}

# Download Docker image from Artifact Portal
download_image() {
    log_step "Downloading Docker Image"

    log_info "Requesting presigned URL from Artifact Portal..."

    # Get presigned URL for latest version
    PRESIGN_RESPONSE=$(curl -s -X POST "${ARTIFACT_PORTAL_URL}/api/v2/presign-latest" \
        -H "Authorization: Bearer $ARTIFACT_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"project\": \"${ARTIFACT_PROJECT}\",
            \"tool\": \"${ARTIFACT_TOOL}\",
            \"platform_arch\": \"${ARTIFACT_PLATFORM}\",
            \"latest_filename\": \"${ARTIFACT_FILENAME}\"
        }")

    DOWNLOAD_URL=$(echo "$PRESIGN_RESPONSE" | jq -r '.url // empty')
    EXPECTED_SHA256=$(echo "$PRESIGN_RESPONSE" | jq -r '.sha256 // empty')
    FILENAME=$(echo "$PRESIGN_RESPONSE" | jq -r '.filename // empty')

    if [[ -z "$DOWNLOAD_URL" ]]; then
        log_error "Failed to get download URL from Artifact Portal"
        echo "Response: $PRESIGN_RESPONSE"
        exit 1
    fi

    # Extract version from filename if possible (e.g., gpu-nt-benchmark-1.0.0.tar.gz)
    VERSION=$(echo "$FILENAME" | grep -oP '\d+\.\d+\.\d+' || echo "latest")

    log_info "Downloading $FILENAME..."

    IMAGE_FILE="$INSTALL_DIR/$FILENAME"

    # Download with progress (presigned URL doesn't need auth)
    curl -L --progress-bar -o "$IMAGE_FILE" "$DOWNLOAD_URL"

    if [[ ! -f "$IMAGE_FILE" ]] || [[ ! -s "$IMAGE_FILE" ]]; then
        log_error "Download failed"
        exit 1
    fi

    log_success "Downloaded $(du -h "$IMAGE_FILE" | cut -f1)"

    # Verify checksum
    if [[ -n "$EXPECTED_SHA256" ]]; then
        log_info "Verifying SHA256 checksum..."
        ACTUAL_SHA256=$(sha256sum "$IMAGE_FILE" | cut -d' ' -f1)

        if [[ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]]; then
            log_error "Checksum verification failed!"
            echo "Expected: $EXPECTED_SHA256"
            echo "Actual:   $ACTUAL_SHA256"
            rm -f "$IMAGE_FILE"
            exit 1
        fi
        log_success "Checksum verified"
    else
        log_warn "No checksum provided - skipping verification"
    fi

    # Load Docker image
    log_info "Loading Docker image..."
    LOADED_IMAGE=$(docker load -i "$IMAGE_FILE" | grep "Loaded image:" | sed 's/Loaded image: //')

    log_success "Docker image loaded: $LOADED_IMAGE"

    # Tag as latest if loaded with version tag
    if [[ "$LOADED_IMAGE" != "$IMAGE_NAME" ]] && [[ -n "$LOADED_IMAGE" ]]; then
        log_info "Tagging $LOADED_IMAGE as $IMAGE_NAME..."
        docker tag "$LOADED_IMAGE" "$IMAGE_NAME"
        log_success "Image tagged as $IMAGE_NAME"
    fi

    # Cleanup downloaded file
    rm -f "$IMAGE_FILE"

    # Store version
    echo "$VERSION" > "$INSTALL_DIR/.installed-version"
}

# Setup video storage directory (no auto-download per Phase 3)
setup_video_storage() {
    log_step "Video Storage Setup"

    echo ""
    log_info "Creating video storage directory..."

    mkdir -p "$VIDEO_DIR"
    chmod 755 "$VIDEO_DIR"

    # Ensure container user can write (uid 1000 typically)
    chown -R 1000:1000 "$VIDEO_DIR" 2>/dev/null || true

    echo ""
    echo -e "${BOLD}Video storage configured:${NC} $VIDEO_DIR"
    echo ""
    echo "  After installation, manage test videos through the web UI:"
    echo "    * Download video packs from Artifact Portal"
    echo "    * Upload your own video files (up to 10GB)"
    echo ""
    echo "  Videos are stored on the HOST filesystem so AxxonOne can access them."
    echo ""

    log_success "Video storage ready"
}

# Prompt for configuration
configure_application() {
    log_step "Application Configuration"

    echo ""
    echo "Configure connection to AxxonOne server:"
    echo ""

    # AxxonOne Host
    read -p "AxxonOne Server Host [localhost]: " AXXON_HOST <&3
    AXXON_HOST=${AXXON_HOST:-localhost}

    # AxxonOne Port
    read -p "AxxonOne Server Port [42000]: " AXXON_PORT <&3
    AXXON_PORT=${AXXON_PORT:-42000}

    # AxxonOne Credentials
    read -p "AxxonOne Username [root]: " AXXON_USER <&3
    AXXON_USER=${AXXON_USER:-root}

    read -sp "AxxonOne Password: " AXXON_PASS <&3
    echo

    # Site ID
    echo ""
    read -p "Site ID (for report organization) [default-site]: " SITE_ID <&3
    SITE_ID=${SITE_ID:-default-site}

    # Generate secret key
    SECRET_KEY=$(openssl rand -hex 32)

    # S3 Configuration (optional)
    echo ""
    echo "S3 Upload Configuration (optional - for cloud backup of reports):"
    read -p "Configure S3 upload? [y/N] " -n 1 -r REPLY <&3
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "S3 Bucket Name: " S3_BUCKET <&3
        read -p "S3 Region [us-east-1]: " S3_REGION <&3
        S3_REGION=${S3_REGION:-us-east-1}
        read -p "S3 Access Key ID: " S3_ACCESS_KEY <&3
        read -sp "S3 Secret Access Key: " S3_SECRET_KEY <&3
        echo
        read -p "S3 Endpoint URL (leave empty for AWS): " S3_ENDPOINT <&3
    fi
}

# Generate .env file
generate_env_file() {
    log_step "Generating Configuration Files"

    cat > "$INSTALL_DIR/.env" << EOF
# GPU NeuralTracker Benchmark Configuration
# Generated by install.sh on $(date)

# Flask Configuration
FLASK_ENV=production
SECRET_KEY=$SECRET_KEY

# AxxonOne Server
AXXON_HOST=$AXXON_HOST
AXXON_PORT=$AXXON_PORT
AXXON_USER=$AXXON_USER
AXXON_PASS=$AXXON_PASS

# Site Configuration
SITE_ID=$SITE_ID

# Paths - VIDEO_HOST_PATH is what gets sent to AxxonOne
VIDEO_HOST_PATH=$VIDEO_DIR
OUTPUT_DIR=/app/output

# Database
DATABASE_PATH=/app/instance/benchmark.db
EOF

    # Add S3 config if provided
    if [[ -n "$S3_BUCKET" ]]; then
        cat >> "$INSTALL_DIR/.env" << EOF

# S3 Upload Configuration
S3_BUCKET=$S3_BUCKET
S3_REGION=$S3_REGION
S3_ACCESS_KEY=$S3_ACCESS_KEY
S3_SECRET_KEY=$S3_SECRET_KEY
EOF
        if [[ -n "$S3_ENDPOINT" ]]; then
            echo "S3_ENDPOINT=$S3_ENDPOINT" >> "$INSTALL_DIR/.env"
        fi
    fi

    chmod 600 "$INSTALL_DIR/.env"
    log_success "Created .env file"
}

# Generate docker-compose.yml
generate_docker_compose() {
    local GPU_CONFIG=""

    if [[ "$NVIDIA_AVAILABLE" == "true" ]]; then
        GPU_CONFIG="
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]"
    fi

    cat > "$INSTALL_DIR/docker-compose.yml" << EOF
# GPU NeuralTracker Benchmark
# Generated by install.sh on $(date)

services:
  gpu-nt-benchmark:
    image: ${IMAGE_NAME}
    pull_policy: never
    container_name: gpu-nt-benchmark
    restart: unless-stopped
    ports:
      - "5000:5000"
    env_file:
      - .env
    environment:
      # Video paths - critical for AxxonOne integration
      - VIDEO_CONTAINER_PATH=/app/videos
      - VIDEO_HOST_PATH=${VIDEO_DIR}
      # Artifact Portal token for video downloads
      - ARTIFACT_API_TOKEN_FILE=/app/.artifact-token
    volumes:
      - ./instance:/app/instance
      - ./output:/app/output
      # Video storage - container writes, host (AxxonOne) reads
      - ${VIDEO_DIR}:/app/videos
      - ./update-signal:/app/update-signal
      # API token for Artifact Portal
      - ./.artifact-token:/app/.artifact-token:ro
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"${GPU_CONFIG}

networks:
  default:
    name: gpu-benchmark-net
EOF

    log_success "Created docker-compose.yml"
}

# Save API token for updates
save_api_token() {
    echo "$ARTIFACT_TOKEN" > "$INSTALL_DIR/.artifact-token"
    chmod 600 "$INSTALL_DIR/.artifact-token"
    log_success "API token saved for updates"
}

# Create update script
create_update_script() {
    cat > "$INSTALL_DIR/update.sh" << 'UPDATESCRIPT'
#!/bin/bash
#
# GPU NeuralTracker Benchmark - Update Script
#

set -e

INSTALL_DIR="/opt/gpu-nt-benchmark"
ARTIFACT_PORTAL_URL="${ARTIFACT_PORTAL_URL:-https://artifacts.digitalsecurityguard.com}"
ARTIFACT_PROJECT="axxon-nt-test-tool"
ARTIFACT_TOOL="docker-container"
ARTIFACT_PLATFORM="linux-amd64"
ARTIFACT_FILENAME="gpu-nt-benchmark.tar.gz"
IMAGE_NAME="gpu-nt-benchmark:latest"
SIGNAL_DIR="$INSTALL_DIR/update-signal"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

write_result() {
    local status="$1"
    local message="$2"
    local version="$3"

    mkdir -p "$SIGNAL_DIR"
    cat > "$SIGNAL_DIR/last-update-result" << EOF
{
    "status": "$status",
    "message": "$message",
    "version": "$version",
    "timestamp": "$(date -Iseconds)"
}
EOF
}

# Check for jq
if ! command -v jq &> /dev/null; then
    log_error "jq is required but not installed"
    write_result "error" "jq not installed" ""
    exit 1
fi

# Check for token
if [[ ! -f "$INSTALL_DIR/.artifact-token" ]]; then
    log_error "API token not found. Please reinstall."
    write_result "error" "API token not found" ""
    exit 1
fi

ARTIFACT_TOKEN=$(cat "$INSTALL_DIR/.artifact-token")

log_info "Checking for updates..."

# Get current version
CURRENT_VERSION=""
if [[ -f "$INSTALL_DIR/.installed-version" ]]; then
    CURRENT_VERSION=$(cat "$INSTALL_DIR/.installed-version")
fi

# Get latest version info
PRESIGN_RESPONSE=$(curl -s -X POST "${ARTIFACT_PORTAL_URL}/api/v2/presign-latest" \
    -H "Authorization: Bearer $ARTIFACT_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"project\": \"${ARTIFACT_PROJECT}\",
        \"tool\": \"${ARTIFACT_TOOL}\",
        \"platform_arch\": \"${ARTIFACT_PLATFORM}\",
        \"latest_filename\": \"${ARTIFACT_FILENAME}\"
    }")

DOWNLOAD_URL=$(echo "$PRESIGN_RESPONSE" | jq -r '.url // empty')
EXPECTED_SHA256=$(echo "$PRESIGN_RESPONSE" | jq -r '.sha256 // empty')
FILENAME=$(echo "$PRESIGN_RESPONSE" | jq -r '.filename // empty')

if [[ -z "$DOWNLOAD_URL" ]]; then
    log_error "Failed to get download URL"
    write_result "error" "Failed to get download URL from Artifact Portal" "$CURRENT_VERSION"
    exit 1
fi

# Extract version from filename
NEW_VERSION=$(echo "$FILENAME" | grep -oP '\d+\.\d+\.\d+' || echo "latest")

if [[ "$NEW_VERSION" == "$CURRENT_VERSION" ]] && [[ "$NEW_VERSION" != "latest" ]]; then
    log_info "Already running latest version ($CURRENT_VERSION)"
    write_result "current" "Already running latest version" "$CURRENT_VERSION"
    exit 0
fi

log_info "Update available: $CURRENT_VERSION -> $NEW_VERSION"

# Backup database
if [[ -f "$INSTALL_DIR/instance/benchmark.db" ]]; then
    BACKUP_FILE="$INSTALL_DIR/instance/benchmark.db.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$INSTALL_DIR/instance/benchmark.db" "$BACKUP_FILE"
    log_info "Database backed up to $BACKUP_FILE"
fi

# Download new image
IMAGE_FILE="$INSTALL_DIR/$FILENAME"
log_info "Downloading $FILENAME..."

curl -L --progress-bar -o "$IMAGE_FILE" "$DOWNLOAD_URL"

if [[ ! -f "$IMAGE_FILE" ]] || [[ ! -s "$IMAGE_FILE" ]]; then
    log_error "Download failed"
    write_result "error" "Download failed" "$CURRENT_VERSION"
    exit 1
fi

# Verify checksum
if [[ -n "$EXPECTED_SHA256" ]]; then
    log_info "Verifying checksum..."
    ACTUAL_SHA256=$(sha256sum "$IMAGE_FILE" | cut -d' ' -f1)

    if [[ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]]; then
        log_error "Checksum verification failed!"
        rm -f "$IMAGE_FILE"
        write_result "error" "Checksum verification failed" "$CURRENT_VERSION"
        exit 1
    fi
    log_success "Checksum verified"
fi

# Stop container
log_info "Stopping service..."
cd "$INSTALL_DIR"
docker compose down 2>/dev/null || docker-compose down 2>/dev/null || true

# Load new image
log_info "Loading new Docker image..."
docker load -i "$IMAGE_FILE"
rm -f "$IMAGE_FILE"

# Start container
log_info "Starting service..."
docker compose up -d 2>/dev/null || docker-compose up -d

# Update version file
echo "$NEW_VERSION" > "$INSTALL_DIR/.installed-version"

log_success "Update complete: $NEW_VERSION"
write_result "success" "Updated to version $NEW_VERSION" "$NEW_VERSION"
UPDATESCRIPT

    chmod +x "$INSTALL_DIR/update.sh"
    log_success "Created update.sh"
}

# Create uninstall script
create_uninstall_script() {
    cat > "$INSTALL_DIR/uninstall.sh" << 'UNINSTALLSCRIPT'
#!/bin/bash
#
# GPU NeuralTracker Benchmark - Uninstall Script
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

INSTALL_DIR="/opt/gpu-nt-benchmark"
VIDEO_DIR="/opt/AxxonSoft/TestVideos"

echo -e "${YELLOW}GPU NeuralTracker Benchmark - Uninstaller${NC}"
echo ""

# Confirm uninstall
read -p "Are you sure you want to uninstall? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Uninstall cancelled"
    exit 0
fi

# Stop and remove container
echo "Stopping container..."
cd "$INSTALL_DIR" 2>/dev/null || true
docker compose down 2>/dev/null || docker-compose down 2>/dev/null || true

# Remove Docker image
echo "Removing Docker image..."
docker rmi gpu-nt-benchmark:latest 2>/dev/null || true

# Remove systemd watcher
echo "Removing systemd services..."
systemctl stop gpu-benchmark-update.path 2>/dev/null || true
systemctl disable gpu-benchmark-update.path 2>/dev/null || true
rm -f /etc/systemd/system/gpu-benchmark-update.path
rm -f /etc/systemd/system/gpu-benchmark-update.service
systemctl daemon-reload 2>/dev/null || true

# Remove config/data
read -p "Remove configuration and data ($INSTALL_DIR)? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf "$INSTALL_DIR"
    echo -e "${GREEN}Removed $INSTALL_DIR${NC}"
fi

# Remove test videos
if [[ -d "$VIDEO_DIR" ]]; then
    read -p "Remove test videos ($VIDEO_DIR)? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$VIDEO_DIR"
        echo -e "${GREEN}Removed $VIDEO_DIR${NC}"
    fi
fi

echo ""
echo -e "${GREEN}Uninstall complete${NC}"
UNINSTALLSCRIPT

    chmod +x "$INSTALL_DIR/uninstall.sh"
    log_success "Created uninstall.sh"
}

# Setup systemd path watcher for one-click updates
setup_systemd_watcher() {
    log_step "Setting Up Auto-Update Service"

    # Create path unit
    cat > /etc/systemd/system/gpu-benchmark-update.path << EOF
[Unit]
Description=Watch for GPU Benchmark update requests

[Path]
PathModified=$INSTALL_DIR/update-signal/request-update
Unit=gpu-benchmark-update.service

[Install]
WantedBy=multi-user.target
EOF

    # Create service unit
    cat > /etc/systemd/system/gpu-benchmark-update.service << EOF
[Unit]
Description=GPU Benchmark Update Service
After=docker.service

[Service]
Type=oneshot
ExecStart=$INSTALL_DIR/update.sh
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    # Enable and start path watcher
    systemctl daemon-reload
    systemctl enable gpu-benchmark-update.path
    systemctl start gpu-benchmark-update.path

    log_success "Auto-update service configured"
}

# Start the service
start_service() {
    log_step "Starting Service"

    cd "$INSTALL_DIR"

    if command -v docker &> /dev/null && docker compose version &> /dev/null; then
        docker compose up -d
    else
        docker-compose up -d
    fi

    log_info "Waiting for service to start..."
    sleep 5

    # Check health
    for i in {1..30}; do
        if curl -sf http://localhost:5000/api/health > /dev/null 2>&1; then
            log_success "Service is running and healthy"
            return 0
        fi
        sleep 1
    done

    log_warn "Service may still be starting. Check status with: docker compose logs"
}

# Print completion message
print_completion() {
    echo ""
    echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}${BOLD}  Installation Complete!${NC}"
    echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "  Access the application at:"
    echo -e "    ${CYAN}http://localhost:5000${NC}"
    echo ""
    echo "  Useful commands:"
    echo "    View logs:      cd $INSTALL_DIR && docker compose logs -f"
    echo "    Stop service:   cd $INSTALL_DIR && docker compose down"
    echo "    Start service:  cd $INSTALL_DIR && docker compose up -d"
    echo "    Update:         $INSTALL_DIR/update.sh"
    echo "    Uninstall:      $INSTALL_DIR/uninstall.sh"
    echo ""
    echo "  Files:"
    echo "    Configuration:  $INSTALL_DIR/.env"
    echo "    Database:       $INSTALL_DIR/instance/benchmark.db"
    echo "    Reports:        $INSTALL_DIR/output/"
    echo "    Test videos:    $VIDEO_DIR/"
    echo ""
}

# Main installation flow
main() {
    check_root
    print_banner
    print_prerequisites
    check_docker
    check_docker_compose
    check_jq
    check_nvidia
    get_artifact_token
    create_directories
    download_image
    setup_video_storage
    configure_application
    generate_env_file
    generate_docker_compose
    save_api_token
    create_update_script
    create_uninstall_script
    setup_systemd_watcher
    start_service
    print_completion
}

# Run main
main "$@"
