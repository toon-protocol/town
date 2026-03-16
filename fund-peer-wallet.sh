#!/usr/bin/env bash
# Fund Peer Wallet with USDC
#
# This script transfers USDC from the deployer account (Account #0)
# to a peer node's wallet address for payment channel creation.
#
# Usage:
#   ./fund-peer-wallet.sh <peer-address> [amount]
#
# Example:
#   ./fund-peer-wallet.sh 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC 50000

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ${NC} $1"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }

# Parse arguments
PEER_ADDRESS="${1:-}"
AMOUNT="${2:-50000}"  # Default 50,000 USDC

# Validate AMOUNT is a valid number (prevent command injection in python3 -c below)
if ! [[ "$AMOUNT" =~ ^[0-9]+$ ]]; then
    log_error "Invalid amount: '$AMOUNT' (must be a positive integer)"
    exit 1
fi

if [ -z "$PEER_ADDRESS" ]; then
    log_error "Usage: $0 <peer-address> [amount]"
    echo ""
    echo "Example:"
    echo "  $0 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC 50000"
    echo ""
    echo "Available Anvil accounts:"
    echo "  Account 2: 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"
    echo "  Account 3: 0x90F79bf6EB2c4f870365E785982E1f101E93b906"
    echo "  Account 4: 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65"
    echo "  Account 5: 0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc"
    exit 1
fi

# Validate PEER_ADDRESS is a valid Ethereum address (prevent injection in curl/cast calls)
if ! [[ "$PEER_ADDRESS" =~ ^0x[0-9a-fA-F]{40}$ ]]; then
    log_error "Invalid Ethereum address: '$PEER_ADDRESS' (must be 0x followed by 40 hex characters)"
    exit 1
fi

# Configuration
TOKEN_ADDRESS="${BASE_TOKEN_ADDRESS:-0x5FbDB2315678afecb367f032d93F642f64180aa3}"
DEPLOYER_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"  # Account #0
ANVIL_RPC="${ANVIL_RPC:-http://localhost:8545}"

# Convert amount to smallest unit
# NOTE: The on-chain mock contract uses 18 decimals (inherited from the original
# ERC-20 deploy script). Production USDC uses 6 decimals. This script targets Anvil
# where the mock contract has 18 decimals, so we use 10**18 here.
AMOUNT_WEI=$(python3 -c "print(int($AMOUNT * 10**18))")

log_info "Funding peer wallet with USDC..."
echo ""
echo "  Peer Address:  $PEER_ADDRESS"
echo "  Amount:        $AMOUNT USDC"
echo "  Token:         $TOKEN_ADDRESS"
echo "  RPC:           $ANVIL_RPC"
echo ""

# Check if Anvil is running
if ! curl -sf "$ANVIL_RPC" -X POST -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' &>/dev/null; then
    log_error "Anvil is not running at $ANVIL_RPC"
    exit 1
fi

# Check if token contract exists
TOKEN_CODE=$(curl -s "$ANVIL_RPC" -X POST -H "Content-Type: application/json" \
    --data "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getCode\",\"params\":[\"$TOKEN_ADDRESS\",\"latest\"],\"id\":1}" \
    | jq -r '.result')

if [ "$TOKEN_CODE" = "0x" ]; then
    log_error "Token contract not deployed at $TOKEN_ADDRESS"
    log_info "Start the genesis node first: ./deploy-genesis-node.sh"
    exit 1
fi

# Transfer tokens using cast
log_info "Transferring $AMOUNT USDC..."

TX_HASH=$(cast send "$TOKEN_ADDRESS" \
    "transfer(address,uint256)" \
    "$PEER_ADDRESS" \
    "$AMOUNT_WEI" \
    --rpc-url "$ANVIL_RPC" \
    --private-key "$DEPLOYER_KEY" \
    --json 2>/dev/null | jq -r '.transactionHash')

if [ -z "$TX_HASH" ] || [ "$TX_HASH" = "null" ]; then
    log_error "Transfer failed"
    exit 1
fi

log_success "Transfer complete!"
echo ""
echo "  Transaction: $TX_HASH"
echo ""

# Verify balance
log_info "Verifying balance..."

BALANCE_HEX=$(curl -s "$ANVIL_RPC" -X POST -H "Content-Type: application/json" \
    --data "{\"jsonrpc\":\"2.0\",\"method\":\"eth_call\",\"params\":[{\"to\":\"$TOKEN_ADDRESS\",\"data\":\"0x70a08231000000000000000000000000${PEER_ADDRESS:2}\"},\"latest\"],\"id\":1}" \
    | jq -r '.result')

# Validate BALANCE_HEX is a valid hex string (prevent injection in python3 -c below)
if [[ "$BALANCE_HEX" =~ ^0x[0-9a-fA-F]+$ ]]; then
    BALANCE=$(python3 -c "print(int('$BALANCE_HEX', 16) // 10**18)" 2>/dev/null || echo "0")
else
    BALANCE="0"
fi

log_success "Peer wallet balance: $BALANCE USDC"
echo ""
echo "✅ Peer wallet is funded and ready for payment channels!"
