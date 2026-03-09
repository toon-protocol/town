#!/usr/bin/env bash
# Deploy Genesis Crosstown Node
#
# This script deploys a complete Crosstown genesis node with:
# - Anvil (local Ethereum blockchain with payment channel contracts)
# - Token Faucet (ETH + AGENT token distribution)
# - ILP Connector (packet routing + settlement)
# - Crosstown Node (Nostr relay + BLS + bootstrap service)
#
# Usage:
#   ./deploy-genesis-node.sh [--reset]
#
# Options:
#   --reset    Completely reset the deployment (removes all data)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration
COMPOSE_FILE="docker-compose-genesis.yml"
ENV_FILE=".env"
GENESIS_ENV="genesis.env"

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

log_header() {
    echo -e "\n${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}${BOLD}  $1${NC}"
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

# Check for reset flag
RESET_MODE=false
if [[ "${1:-}" == "--reset" ]]; then
    RESET_MODE=true
    log_warning "Reset mode enabled - will remove all existing data"
    read -p "Are you sure you want to reset everything? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Cancelled"
        exit 0
    fi
fi

# Banner
clear
echo -e "${CYAN}${BOLD}"
cat << "EOF"
  ╔═══════════════════════════════════════════════════════════╗
  ║                                                           ║
  ║   ██████╗██████╗  ██████╗ ███████╗███████╗████████╗      ║
  ║  ██╔════╝██╔══██╗██╔═══██╗██╔════╝██╔════╝╚══██╔══╝      ║
  ║  ██║     ██████╔╝██║   ██║███████╗███████╗   ██║         ║
  ║  ██║     ██╔══██╗██║   ██║╚════██║╚════██║   ██║         ║
  ║  ╚██████╗██║  ██║╚██████╔╝███████║███████║   ██║         ║
  ║   ╚═════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚══════╝   ╚═╝         ║
  ║                                                           ║
  ║              Genesis Node Deployment                     ║
  ║                                                           ║
  ╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}\n"

# Step 1: Prerequisites
log_header "Step 1: Checking Prerequisites"

# Check Docker
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed"
    exit 1
fi
log_success "Docker found: $(docker --version | cut -d' ' -f3)"

# Check Docker Compose
if ! docker compose version &> /dev/null; then
    log_error "Docker Compose is not installed"
    exit 1
fi
log_success "Docker Compose found: $(docker compose version | cut -d' ' -f4)"

# Check for connector contracts
if [ ! -d "/Users/jonathangreen/Documents/connector/packages/contracts" ]; then
    log_error "Connector contracts not found at /Users/jonathangreen/Documents/connector"
    log_info "Please clone the connector repository:"
    log_info "  cd /Users/jonathangreen/Documents"
    log_info "  git clone <connector-repo-url> connector"
    exit 1
fi
log_success "Connector contracts found"

# Step 2: Clean up (if reset mode)
if [ "$RESET_MODE" = true ]; then
    log_header "Step 2: Cleaning Up Existing Deployment"

    docker compose -p crosstown-genesis -f "$COMPOSE_FILE" down -v 2>/dev/null || true
    rm -f "$ENV_FILE" "$GENESIS_ENV" 2>/dev/null || true

    log_success "Cleanup complete"
else
    log_header "Step 2: Checking Existing Deployment"

    if [ -f "$ENV_FILE" ]; then
        log_warning "$ENV_FILE already exists"
        read -p "Use existing configuration? (Y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            log_info "Backing up existing $ENV_FILE to ${ENV_FILE}.backup"
            cp "$ENV_FILE" "${ENV_FILE}.backup"
            rm "$ENV_FILE"
        else
            log_info "Using existing configuration"
        fi
    fi
fi

# Step 3: Generate Genesis Node Configuration
if [ ! -f "$ENV_FILE" ]; then
    log_header "Step 3: Generating Genesis Node Configuration"

    # Generate Nostr keypair
    NOSTR_SECRET=$(openssl rand -hex 32)
    log_info "Generated Nostr secret key"

    # Create .env file
    cat > "$ENV_FILE" << EOF
# Crosstown Genesis Node Configuration
# Generated: $(date)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Genesis Node Identity
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

NODE_ID=genesis-node
NOSTR_SECRET_KEY=$NOSTR_SECRET
ILP_ADDRESS=g.crosstown.genesis

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Network Configuration
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# BTP endpoint for peer connections
BTP_ENDPOINT=ws://connector:3000

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Pricing Configuration
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

BASE_PRICE_PER_BYTE=10
ASSET_CODE=USD
ASSET_SCALE=6

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Bootstrap & Discovery
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ARDRIVE_ENABLED=true

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Payment Channel Configuration (Anvil Local)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Token contract (deployed by Anvil on startup)
BASE_TOKEN_ADDRESS=0x5FbDB2315678afecb367f032d93F642f64180aa3
M2M_TOKEN_ADDRESS=0x5FbDB2315678afecb367f032d93F642f64180aa3

# Token network registry (deployed by Anvil on startup)
BASE_REGISTRY_ADDRESS=0xe7f1725e7734ce288f8367e1bb143e90bb3f0512

# Genesis node wallet (Anvil account #0 - has 10k ETH + 1M AGENT)
PEER_EVM_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Faucet Configuration
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

FAUCET_ETH_AMOUNT=100
FAUCET_TOKEN_AMOUNT=10000
FAUCET_RATE_LIMIT_HOURS=1

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Explorer UI
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EXPLORER_ENABLED=true
EOF

    log_success "Configuration saved to $ENV_FILE"

    # Also save to genesis.env for other peers to reference
    cat > "$GENESIS_ENV" << EOF
# Genesis Node Information
# Other peers can use this to bootstrap into the network

GENESIS_NODE_ID=genesis-node
GENESIS_ILP_ADDRESS=g.crosstown.genesis
GENESIS_NOSTR_PUBKEY=$(node -e "const { getPublicKey } = require('nostr-tools/pure'); console.log(getPublicKey('$NOSTR_SECRET'))" 2>/dev/null || echo "<run after npm install>")
GENESIS_BTP_ENDPOINT=ws://localhost:3000
GENESIS_RELAY=ws://localhost:7100
GENESIS_BLS_URL=http://localhost:3100
GENESIS_EVM_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
EOF

    log_success "Genesis info saved to $GENESIS_ENV"
else
    log_header "Step 3: Using Existing Configuration"
    log_info "Using configuration from $ENV_FILE"
fi

# Step 4: Create Docker Network
log_header "Step 4: Creating Docker Network"

log_info "Creating crosstown-network..."
if docker network inspect crosstown-network &>/dev/null; then
    log_success "Network already exists"
else
    docker network create crosstown-network
    log_success "Network created"
fi

# Step 5: Start the Stack
log_header "Step 5: Starting Genesis Node"

log_info "Starting Docker Compose stack..."
docker compose -p crosstown-genesis -f "$COMPOSE_FILE" up -d

log_success "Services started"

# Step 6: Wait for Health Checks
log_header "Step 6: Waiting for Services to be Healthy"

log_info "Waiting for Anvil..."
timeout=60
elapsed=0
while [ $elapsed -lt $timeout ]; do
    if curl -sf http://localhost:8545 -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' &>/dev/null; then
        log_success "Anvil is ready"
        break
    fi
    sleep 2
    elapsed=$((elapsed + 2))
    if [ $elapsed -ge $timeout ]; then
        log_error "Anvil failed to start within ${timeout}s"
        exit 1
    fi
done

log_info "Waiting for contracts to deploy..."
sleep 5

log_info "Waiting for Faucet..."
elapsed=0
while [ $elapsed -lt $timeout ]; do
    if curl -sf http://localhost:3500/health &>/dev/null; then
        log_success "Faucet is ready"
        break
    fi
    sleep 2
    elapsed=$((elapsed + 2))
    if [ $elapsed -ge $timeout ]; then
        log_warning "Faucet not ready yet (may need more time)"
        break
    fi
done

log_info "Waiting for Connector..."
elapsed=0
while [ $elapsed -lt $timeout ]; do
    if curl -sf http://localhost:8080/health &>/dev/null; then
        log_success "Connector is ready"
        break
    fi
    sleep 2
    elapsed=$((elapsed + 2))
    if [ $elapsed -ge $timeout ]; then
        log_error "Connector failed to start within ${timeout}s"
        exit 1
    fi
done

log_info "Waiting for Crosstown Node..."
elapsed=0
while [ $elapsed -lt $timeout ]; do
    if curl -sf http://localhost:3100/health &>/dev/null; then
        log_success "Crosstown Node is ready"
        break
    fi
    sleep 2
    elapsed=$((elapsed + 2))
    if [ $elapsed -ge $timeout ]; then
        log_error "Crosstown Node failed to start within ${timeout}s"
        exit 1
    fi
done

# Step 7: Verify Deployment
log_header "Step 7: Verifying Deployment"

# Check Anvil contracts
log_info "Verifying deployed contracts..."
TOKEN_CODE=$(curl -s http://localhost:8545 -X POST -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"eth_getCode","params":["0x5FbDB2315678afecb367f032d93F642f64180aa3","latest"],"id":1}' \
    | jq -r '.result')

if [ "$TOKEN_CODE" != "0x" ] && [ ${#TOKEN_CODE} -gt 10 ]; then
    log_success "AGENT token contract deployed"
else
    log_warning "AGENT token contract not found (may deploy on first use)"
fi

# Check faucet info
log_info "Checking faucet status..."
FAUCET_INFO=$(curl -s http://localhost:3500/api/info 2>/dev/null || echo '{}')
FAUCET_READY=$(echo "$FAUCET_INFO" | jq -r '.ready // false')

if [ "$FAUCET_READY" = "true" ]; then
    ETH_BALANCE=$(echo "$FAUCET_INFO" | jq -r '.faucetBalances.eth // "unknown"')
    TOKEN_BALANCE=$(echo "$FAUCET_INFO" | jq -r '.faucetBalances.token // "unknown"')
    log_success "Faucet ready (ETH: $ETH_BALANCE, AGENT: $TOKEN_BALANCE)"
else
    log_warning "Faucet not fully initialized yet"
fi

# Check Crosstown health
log_info "Checking Crosstown node status..."
CROSSTOWN_HEALTH=$(curl -s http://localhost:3100/health 2>/dev/null || echo '{}')
BOOTSTRAP_PHASE=$(echo "$CROSSTOWN_HEALTH" | jq -r '.bootstrapPhase // "unknown"')
PEER_COUNT=$(echo "$CROSSTOWN_HEALTH" | jq -r '.peerCount // 0')

log_success "Crosstown Node status: $BOOTSTRAP_PHASE | Peers: $PEER_COUNT"

# Step 8: Display Access Information
log_header "Genesis Node Deployed Successfully! 🎉"

cat << EOF

${BOLD}Service Endpoints:${NC}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ${GREEN}🚰 Token Faucet${NC}
     Web UI:           ${CYAN}http://localhost:3500${NC}
     Get test tokens:  Enter any Ethereum address

  ${GREEN}⛓️  Anvil (Local Blockchain)${NC}
     RPC URL:          ${CYAN}http://localhost:8545${NC}
     Chain ID:         31337
     AGENT Token:      0x5FbDB2315678afecb367f032d93F642f64180aa3
     Token Registry:   0xe7f1725e7734ce288f8367e1bb143e90bb3f0512

  ${GREEN}🔌 ILP Connector${NC}
     Health:           ${CYAN}http://localhost:8080/health${NC}
     Admin API:        ${CYAN}http://localhost:8081${NC}
     Explorer UI:      ${CYAN}http://localhost:3001${NC}
     BTP Server:       ws://localhost:3000

  ${GREEN}📡 Crosstown Node${NC}
     BLS API:          ${CYAN}http://localhost:3100${NC}
     Health:           ${CYAN}http://localhost:3100/health${NC}
     Nostr Relay:      ${CYAN}ws://localhost:7100${NC}

  ${GREEN}🦊 Forgejo (Read-Only Public Git)${NC}
     Web UI:           ${CYAN}http://localhost:3004${NC}
     Git Clone:        git clone http://localhost:3004/user/repo.git

     ${YELLOW}Access Model:${NC}
       ✅ FREE: Browse, clone, download (public read access)
       💰 PAID: Push, create repo, PRs (via NIP-34 events only)


${BOLD}Genesis Node Information (for peers):${NC}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Node ID:            ${CYAN}genesis-node${NC}
  ILP Address:        ${CYAN}g.crosstown.genesis${NC}
  BTP Endpoint:       ${CYAN}ws://localhost:3000${NC}
  Nostr Relay:        ${CYAN}ws://localhost:7100${NC}
  BLS URL:            ${CYAN}http://localhost:3100${NC}
  EVM Address:        ${CYAN}0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266${NC}

  ${YELLOW}ℹ${NC} Detailed bootstrap info saved to: ${BOLD}genesis.env${NC}


${BOLD}Pre-funded Test Accounts:${NC}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ${BOLD}Account 0${NC} (Genesis Node - Deployer)
    Address:  0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
    Balance:  10,000 ETH + 1,000,000 AGENT
    Private:  0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

  ${BOLD}Account 1${NC} (Faucet Source)
    Address:  0x70997970C51812dc3A010C7d01b50e0d17dc79C8
    Balance:  10,000 ETH
    Private:  0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d

  ${BOLD}Account 2${NC} (Available for Testing)
    Address:  0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC
    Balance:  10,000 ETH
    Private:  0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a


${BOLD}Quick Start Guide:${NC}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ${BOLD}1. Get tokens for a new wallet:${NC}
     → Open ${CYAN}http://localhost:3500${NC}
     → Enter your wallet address
     → Receive 100 ETH + 10,000 AGENT tokens

  ${BOLD}2. Monitor the genesis node:${NC}
     → docker compose -p crosstown-genesis -f $COMPOSE_FILE logs -f crosstown

  ${BOLD}3. Check health status:${NC}
     → curl http://localhost:3100/health | jq

  ${BOLD}4. View ILP peers:${NC}
     → curl http://localhost:8081/admin/peers | jq

  ${BOLD}5. Bootstrap a new peer:${NC}
     → Use the genesis node information above
     → Set BOOTSTRAP_PEERS environment variable
     → Point to ws://localhost:7100 for Nostr relay


${BOLD}Next Steps:${NC}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  • The genesis node is now ready to accept peer connections
  • Other Crosstown nodes can bootstrap by following your genesis node
  • Use the faucet to distribute tokens to peer wallets
  • Monitor logs to see peers joining the network


${BOLD}Useful Commands:${NC}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  View logs:          docker compose -p crosstown-genesis -f $COMPOSE_FILE logs -f
  Stop services:      docker compose -p crosstown-genesis -f $COMPOSE_FILE down
  Restart services:   docker compose -p crosstown-genesis -f $COMPOSE_FILE restart
  Reset everything:   ./deploy-genesis-node.sh --reset

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EOF

log_success "Genesis node deployment complete!"
