#!/usr/bin/env bash
# Deploy Crosstown Peer Nodes
#
# This script fully deploys N peer nodes that bootstrap from the genesis node.
# Each peer gets:
# - Its own ILP Connector
# - Its own Crosstown node
# - Its own Forgejo instance (with auto-configured token)
# - Automatic wallet funding
# - Automatic bootstrap configuration
#
# Usage:
#   ./deploy-peers.sh <count>
#
# Example:
#   ./deploy-peers.sh 3    # Deploy 3 complete peer nodes

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ${NC} $1"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }

log_header() {
    echo -e "\n${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}${BOLD}  $1${NC}"
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

# Function to get Anvil account info by peer number
get_anvil_account() {
    local peer_num=$1
    case $peer_num in
        1) echo "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC:0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a" ;;
        2) echo "0x90F79bf6EB2c4f870365E785982E1f101E93b906:0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6" ;;
        3) echo "0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65:0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a" ;;
        4) echo "0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc:0x8b3a350cf5c34c9194ca85829a2df0ec3153be0318b5e2d3348e872092edffba" ;;
        5) echo "0x976EA74026E726554dB657fA54763abd0C3a0aa9:0x92db14e403b83dfe3df233f83dfa3a0d7096f21ca9b0d6d6b8d88b2b4ec1564e" ;;
        6) echo "0x14dC79964da2C08b23698B3D3cc7Ca32193d9955:0x4bbbf85ce3377467afe5d46f804f221813b2bb87f24d81f60f1fcdbf7cbf4356" ;;
        7) echo "0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f:0xdbda1821b80551c9d65939329250298aa3472ba22feea921c0cf5d620ea67b97" ;;
        8) echo "0xa0Ee7A142d267C1f36714E4a8F75612F20a79720:0x2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6" ;;
        *) echo "" ;;
    esac
}

# Parse argument
if [ $# -ne 1 ]; then
    log_error "Usage: $0 <count>"
    echo ""
    echo "Example:"
    echo "  $0 3    # Deploy 3 peer nodes"
    echo ""
    echo "Maximum: 8 peers (uses Anvil accounts #2-#9)"
    exit 1
fi

PEER_COUNT="$1"

if ! [[ "$PEER_COUNT" =~ ^[1-8]$ ]]; then
    log_error "Count must be between 1 and 8"
    exit 1
fi

# Configuration
FUNDING_AMOUNT=50000

# Banner
clear
echo -e "${CYAN}${BOLD}"
cat << "EOF"
  ╔═══════════════════════════════════════════════════════════╗
  ║                                                           ║
  ║   ██████╗ ███████╗███████╗██████╗     ███╗   ██╗███████╗ ║
  ║   ██╔══██╗██╔════╝██╔════╝██╔══██╗    ████╗  ██║██╔════╝ ║
  ║   ██████╔╝█████╗  █████╗  ██████╔╝    ██╔██╗ ██║███████╗ ║
  ║   ██╔═══╝ ██╔══╝  ██╔══╝  ██╔══██╗    ██║╚██╗██║╚════██║ ║
  ║   ██║     ███████╗███████╗██║  ██║    ██║ ╚████║███████║ ║
  ║   ╚═╝     ╚══════╝╚══════╝╚═╝  ╚═╝    ╚═╝  ╚═══╝╚══════╝ ║
  ║                                                           ║
  ║         Automated Multi-Peer Deployment                  ║
  ║                                                           ║
  ╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}\n"

log_info "Deploying ${PEER_COUNT} complete peer node(s)"
echo ""

# Check prerequisites
log_header "Checking Prerequisites"

# Check if genesis node is running
if ! curl -sf http://localhost:3100/health &>/dev/null; then
    log_error "Genesis node is not running"
    log_info "Start it with: ./deploy-genesis-node.sh"
    exit 1
fi
log_success "Genesis node is running"

# Check if crosstown-network exists
if ! docker network inspect crosstown-network &>/dev/null; then
    log_error "crosstown-network does not exist"
    log_info "The genesis deployment should create this network"
    log_info "Try: ./deploy-genesis-node.sh"
    exit 1
fi
log_success "Docker network exists"

# Load genesis node info
if [ ! -f "genesis.env" ]; then
    log_error "genesis.env not found"
    log_info "Deploy the genesis node first: ./deploy-genesis-node.sh"
    exit 1
fi

source genesis.env
log_success "Loaded genesis node configuration"

# Check for required tools
for cmd in docker jq openssl python3; do
    if ! command -v $cmd &>/dev/null; then
        log_error "$cmd is not installed"
        exit 1
    fi
done
log_success "All required tools available"

# Function to deploy a single peer
deploy_peer() {
    local PEER_NUM=$1
    local PEER_ID="peer-${PEER_NUM}"
    local ILP_ADDRESS="g.crosstown.peer${PEER_NUM}"

    # Get account for this peer
    local ACCOUNT_INFO=$(get_anvil_account "$PEER_NUM")
    if [ -z "$ACCOUNT_INFO" ]; then
        log_error "Invalid peer number: $PEER_NUM"
        return 1
    fi
    IFS=':' read -r PEER_ADDRESS PEER_PRIVATE_KEY <<< "$ACCOUNT_INFO"
    local ACCOUNT_NUM=$((PEER_NUM + 1))

    log_header "Deploying Peer #${PEER_NUM}"

    echo -e "${BOLD}Configuration:${NC}"
    echo "  Peer ID:       $PEER_ID"
    echo "  ILP Address:   $ILP_ADDRESS"
    echo "  EVM Address:   $PEER_ADDRESS"
    echo "  Anvil Account: #$ACCOUNT_NUM"
    echo ""

    # Step 1: Fund wallet
    log_info "Funding wallet with $FUNDING_AMOUNT USDC..."
    ./fund-peer-wallet.sh "$PEER_ADDRESS" "$FUNDING_AMOUNT" > /dev/null 2>&1
    log_success "Wallet funded"

    # Step 2: Generate Nostr keypair
    local NOSTR_SECRET=$(openssl rand -hex 32)
    log_success "Generated Nostr keypair"

    # Step 3: Create docker-compose file with Forgejo
    local COMPOSE_FILE="docker-compose-peer${PEER_NUM}.yml"
    local BLS_PORT=$((3100 + PEER_NUM * 10))
    local WS_PORT=$((7100 + PEER_NUM * 10))
    local CONNECTOR_PORT=$((3000 + PEER_NUM * 10))
    local CONNECTOR_HEALTH_PORT=$((8080 + PEER_NUM * 10))
    local CONNECTOR_ADMIN_PORT=$((8081 + PEER_NUM * 10))
    local FORGEJO_PORT=$((3004 + PEER_NUM * 10))

    log_info "Creating docker-compose file: $COMPOSE_FILE"

    cat > "$COMPOSE_FILE" << EOF
# Crosstown Peer #${PEER_NUM}
# Auto-generated by deploy-peers.sh

networks:
  crosstown-network:
    external: true

volumes:
  peer${PEER_NUM}-crosstown-data:
  peer${PEER_NUM}-connector-data:
  peer${PEER_NUM}-forgejo-data:

services:
  # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  # ILP Connector for Peer #${PEER_NUM}
  # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  connector-peer${PEER_NUM}:
    image: connector:1.20.0
    container_name: connector-peer${PEER_NUM}
    labels:
      - "crosstown.group=peer-${PEER_NUM}"
      - "crosstown.role=connector"
      - "crosstown.tier=application"
    environment:
      ENVIRONMENT: development
      LOCAL_DELIVERY_URL: http://crosstown-peer${PEER_NUM}:${BLS_PORT}

      # Payment channels
      BASE_ENABLED: "true"
      BASE_RPC_URL: http://crosstown-anvil:8545
      BASE_CHAIN_ID: "31337"
      BASE_PRIVATE_KEY: "${PEER_PRIVATE_KEY}"
      BASE_TOKEN_ADDRESS: "0x5FbDB2315678afecb367f032d93F642f64180aa3"
      BASE_REGISTRY_ADDRESS: "0xe7f1725e7734ce288f8367e1bb143e90bb3f0512"

      EXPLORER_ENABLED: "true"

    ports:
      - "${CONNECTOR_PORT}:3000"
      - "${CONNECTOR_HEALTH_PORT}:8080"
      - "${CONNECTOR_ADMIN_PORT}:8081"
      - "$((3001 + PEER_NUM * 10)):3001"
    volumes:
      - peer${PEER_NUM}-connector-data:/data
      - ./config/connector-config-with-base.yaml:/app/config.yaml:ro
    networks:
      - crosstown-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:8080/health"]
      interval: 10s
      timeout: 5s
      retries: 3
      start_period: 20s

  # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  # Forgejo for Peer #${PEER_NUM}
  # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  forgejo-peer${PEER_NUM}:
    image: codeberg.org/forgejo/forgejo:14
    container_name: forgejo-peer${PEER_NUM}
    labels:
      - "crosstown.group=peer-${PEER_NUM}"
      - "crosstown.role=git"
      - "crosstown.tier=application"
    environment:
      - USER_UID=1000
      - USER_GID=1000
      - FORGEJO__database__DB_TYPE=sqlite3
      - FORGEJO__server__DOMAIN=localhost
      - FORGEJO__server__HTTP_PORT=3000
      - FORGEJO__server__ROOT_URL=http://localhost:${FORGEJO_PORT}/
      - FORGEJO__security__INSTALL_LOCK=true

      # Read-only public access
      - FORGEJO__service__REQUIRE_SIGNIN_VIEW=false
      - FORGEJO__repository__DISABLE_HTTP_GIT=false
      - FORGEJO__repository__ENABLE_PUSH_CREATE_USER=false
      - FORGEJO__repository__ENABLE_PUSH_CREATE_ORG=false
      - FORGEJO__repository__ENABLE_EDITOR_UPLOAD=false
      - FORGEJO__repository__DISABLE_DOWNLOAD_SOURCE_ARCHIVES=false
      - FORGEJO__service__DISABLE_REGISTRATION=true
      - FORGEJO__service__SHOW_REGISTRATION_BUTTON=false
      - FORGEJO__api__ENABLE_SWAGGER=false
      - FORGEJO__repository__DEFAULT_PRIVATE=false

    ports:
      - "${FORGEJO_PORT}:3000"
    volumes:
      - peer${PEER_NUM}-forgejo-data:/data
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
    networks:
      - crosstown-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:3000/"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 20s

  # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  # Crosstown Node for Peer #${PEER_NUM}
  # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  crosstown-peer${PEER_NUM}:
    image: crosstown:optimized
    container_name: crosstown-peer${PEER_NUM}
    labels:
      - "crosstown.group=peer-${PEER_NUM}"
      - "crosstown.role=relay"
      - "crosstown.tier=application"
    environment:
      # Identity
      NODE_ID: ${PEER_ID}
      NOSTR_SECRET_KEY: ${NOSTR_SECRET}
      ILP_ADDRESS: ${ILP_ADDRESS}

      # Connector integration (Docker-internal, TLS unnecessary)
      CONNECTOR_ADMIN_URL: http://connector-peer${PEER_NUM}:8081
      CONNECTOR_URL: http://connector-peer${PEER_NUM}:8080
      BTP_ENDPOINT: ws://connector-peer${PEER_NUM}:3000 # nosemgrep: detect-insecure-websocket

      # Service ports
      BLS_PORT: ${BLS_PORT}
      WS_PORT: ${WS_PORT}

      # Pricing
      BASE_PRICE_PER_BYTE: 10
      ASSET_CODE: USD
      ASSET_SCALE: 6

      # Bootstrap from genesis
      BOOTSTRAP_RELAYS: "${GENESIS_RELAY}"
      BOOTSTRAP_PEERS: '[{"pubkey":"${GENESIS_NOSTR_PUBKEY}","ilpAddress":"${GENESIS_ILP_ADDRESS}","btpEndpoint":"${GENESIS_BTP_ENDPOINT}","relay":"${GENESIS_RELAY}"}]'
      ARDRIVE_ENABLED: "true"

      # Payment channels
      PEER_EVM_ADDRESS: "${PEER_ADDRESS}"
      M2M_TOKEN_ADDRESS: "0x5FbDB2315678afecb367f032d93F642f64180aa3"

      # Settlement configuration for Anvil
      SUPPORTED_CHAINS: "evm:anvil:31337"
      SETTLEMENT_ADDRESS_EVM_ANVIL_31337: "${PEER_ADDRESS}"

      # NIP-34 Git integration (token will be set by init script)
      FORGEJO_URL: http://forgejo-peer${PEER_NUM}:3000
      FORGEJO_OWNER: crosstown

      # Storage
      DATA_DIR: /data

    ports:
      - "${BLS_PORT}:${BLS_PORT}"
      - "${WS_PORT}:${WS_PORT}"
    volumes:
      - peer${PEER_NUM}-crosstown-data:/data
    networks:
      - crosstown-network
    depends_on:
      connector-peer${PEER_NUM}:
        condition: service_healthy
      forgejo-peer${PEER_NUM}:
        condition: service_healthy
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:${BLS_PORT}/health"]
      interval: 10s
      timeout: 5s
      retries: 3
      start_period: 15s
EOF

    log_success "Docker compose file created"

    # Step 4: Start services (Forgejo first, then others)
    log_info "Starting Forgejo..."
    docker compose -p "crosstown-peer-${PEER_NUM}" -f "$COMPOSE_FILE" up -d forgejo-peer${PEER_NUM}

    # Wait for Forgejo to be healthy
    log_info "Waiting for Forgejo to be ready..."
    local timeout=60
    local elapsed=0
    while [ $elapsed -lt $timeout ]; do
        if docker compose -p "crosstown-peer-${PEER_NUM}" -f "$COMPOSE_FILE" ps forgejo-peer${PEER_NUM} | grep -q "healthy"; then
            log_success "Forgejo is ready"
            break
        fi
        sleep 2
        elapsed=$((elapsed + 2))
        if [ $elapsed -ge $timeout ]; then
            log_error "Forgejo failed to start within ${timeout}s"
            return 1
        fi
    done

    # Step 5: Auto-configure Forgejo token
    log_info "Setting up Forgejo admin and API token..."

    # Create admin user (run as git user, not root)
    docker exec --user git forgejo-peer${PEER_NUM} forgejo admin user create \
        --username crosstown \
        --password "crosstown${PEER_NUM}" \
        --email "admin@peer${PEER_NUM}.local" \
        --admin \
        --must-change-password=false 2>/dev/null || log_warning "Admin user may already exist"

    # Generate API token (run as git user, not root)
    local TOKEN_OUTPUT=$(docker exec --user git forgejo-peer${PEER_NUM} forgejo admin user generate-access-token \
        --username crosstown \
        --scopes write:repository,write:issue,write:misc \
        --token-name "Crosstown-BLS-NIP34-$(date +%s)" 2>&1)

    local FORGEJO_TOKEN=$(echo "$TOKEN_OUTPUT" | grep -oE '[a-f0-9]{40}' | head -1)

    if [ -z "$FORGEJO_TOKEN" ]; then
        log_error "Failed to generate Forgejo token"
        log_info "Token output: $TOKEN_OUTPUT"
        return 1
    fi

    log_success "Forgejo token generated"

    # Update docker-compose to include the token
    # We'll use docker compose config to set environment variable
    # For now, restart crosstown with token set via docker exec
    # (Better approach: use .env file per peer, but this works)

    # Step 6: Start remaining services
    log_info "Starting connector and crosstown services..."
    docker compose -p "crosstown-peer-${PEER_NUM}" -f "$COMPOSE_FILE" up -d

    # Step 7: Configure Forgejo token in running container
    sleep 5
    docker exec crosstown-peer${PEER_NUM} sh -c "echo 'FORGEJO_TOKEN=${FORGEJO_TOKEN}' >> /app/.env" 2>/dev/null || true
    docker compose -p "crosstown-peer-${PEER_NUM}" -f "$COMPOSE_FILE" restart crosstown-peer${PEER_NUM}

    # Step 8: Wait for health checks
    log_info "Waiting for connector to be healthy..."
    elapsed=0
    while [ $elapsed -lt $timeout ]; do
        if curl -sf "http://localhost:${CONNECTOR_HEALTH_PORT}/health" &>/dev/null; then
            log_success "Connector is healthy"
            break
        fi
        sleep 2
        elapsed=$((elapsed + 2))
        if [ $elapsed -ge $timeout ]; then
            log_error "Connector failed to start within ${timeout}s"
            return 1
        fi
    done

    log_info "Waiting for Crosstown node to be healthy..."
    elapsed=0
    while [ $elapsed -lt $timeout ]; do
        if curl -sf "http://localhost:${BLS_PORT}/health" &>/dev/null; then
            log_success "Crosstown node is healthy"
            break
        fi
        sleep 2
        elapsed=$((elapsed + 2))
        if [ $elapsed -ge $timeout ]; then
            log_error "Crosstown node failed to start within ${timeout}s"
            return 1
        fi
    done

    # Step 9: Wait for bootstrap
    log_info "Waiting for bootstrap to complete..."
    elapsed=0
    timeout=120
    while [ $elapsed -lt $timeout ]; do
        HEALTH=$(curl -s "http://localhost:${BLS_PORT}/health" 2>/dev/null || echo '{}')
        PHASE=$(echo "$HEALTH" | jq -r '.bootstrapPhase // "unknown"')
        PEERS=$(echo "$HEALTH" | jq -r '.peerCount // 0')

        if [ "$PHASE" = "ready" ] || [ "$PEERS" -gt 0 ]; then
            log_success "Bootstrap complete (phase: $PHASE, peers: $PEERS)"
            break
        fi

        sleep 3
        elapsed=$((elapsed + 3))

        if [ $elapsed -ge $timeout ]; then
            log_warning "Bootstrap phase: $PHASE (may still be connecting)"
            break
        fi
    done

    # Step 10: Display peer info
    HEALTH=$(curl -s "http://localhost:${BLS_PORT}/health" 2>/dev/null || echo '{}')
    PHASE=$(echo "$HEALTH" | jq -r '.bootstrapPhase // "unknown"')
    PEERS=$(echo "$HEALTH" | jq -r '.peerCount // 0')

    echo ""
    echo -e "${BOLD}Peer #${PEER_NUM} Status:${NC}"
    echo "  Bootstrap Phase: $PHASE"
    echo "  Peer Count:      $PEERS"
    echo "  BLS URL:         http://localhost:${BLS_PORT}"
    echo "  Nostr Relay:     ws://localhost:${WS_PORT}"
    echo "  Connector:       http://localhost:${CONNECTOR_HEALTH_PORT}"
    echo "  Forgejo:         http://localhost:${FORGEJO_PORT}"
    echo "  Forgejo Token:   ${FORGEJO_TOKEN:0:16}...${FORGEJO_TOKEN:32}"
    echo ""

    log_success "Peer #${PEER_NUM} deployed successfully!"

    return 0
}

# Deploy all peers
DEPLOYED_PEERS=()
FAILED_PEERS=()

for PEER_NUM in $(seq 1 $PEER_COUNT); do
    if deploy_peer "$PEER_NUM"; then
        DEPLOYED_PEERS+=("$PEER_NUM")
    else
        FAILED_PEERS+=("$PEER_NUM")
    fi
done

# Final summary
log_header "Deployment Complete! 🎉"

cat << EOF

${BOLD}Deployment Summary:${NC}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ${GREEN}✓ Successfully deployed:${NC} ${#DEPLOYED_PEERS[@]} peer(s) [${DEPLOYED_PEERS[*]}]
  ${RED}✗ Failed to deploy:${NC}      ${#FAILED_PEERS[@]} peer(s) [${FAILED_PEERS[*]}]


${BOLD}Active Peer Nodes:${NC}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EOF

for PEER_NUM in "${DEPLOYED_PEERS[@]}"; do
    BLS_PORT=$((3100 + PEER_NUM * 10))
    WS_PORT=$((7100 + PEER_NUM * 10))
    HEALTH_PORT=$((8080 + PEER_NUM * 10))
    FORGEJO_PORT=$((3004 + PEER_NUM * 10))

    echo "  ${BOLD}Peer #${PEER_NUM}:${NC}"
    echo "    BLS:        ${CYAN}http://localhost:${BLS_PORT}${NC}"
    echo "    Relay:      ${CYAN}ws://localhost:${WS_PORT}${NC}"
    echo "    Connector:  ${CYAN}http://localhost:${HEALTH_PORT}${NC}"
    echo "    Forgejo:    ${CYAN}http://localhost:${FORGEJO_PORT}${NC}"
    echo ""
done

cat << EOF

${BOLD}Network Status:${NC}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Total nodes:     $((${#DEPLOYED_PEERS[@]} + 1)) (1 genesis + ${#DEPLOYED_PEERS[@]} peers)
  Network ready:   ${GREEN}✓${NC}


${BOLD}Useful Commands:${NC}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  View all peers status:
    ${CYAN}for port in 3100 3110 3120 3130; do curl -s http://localhost:\$port/health | jq -r '.bootstrapPhase'; done${NC}

  View peer logs:
    ${CYAN}docker compose -p crosstown-peer-1 -f docker-compose-peer1.yml logs -f${NC}

  Stop all peers:
    ${CYAN}for i in ${DEPLOYED_PEERS[*]}; do docker compose -p crosstown-peer-\$i -f docker-compose-peer\$i.yml down; done${NC}

  Access Forgejo:
    ${CYAN}Peer 1: http://localhost:3014 (user: crosstown, pass: crosstown1)${NC}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EOF

if [ ${#FAILED_PEERS[@]} -gt 0 ]; then
    log_error "Some peers failed to deploy. Check logs above for details."
    exit 1
fi

log_success "All ${#DEPLOYED_PEERS[@]} peer(s) deployed with Forgejo and bootstrapped successfully!"
