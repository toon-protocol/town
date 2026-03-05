# Local Development Setup (No Docker)

Run connector and crosstown nodes directly on your host machine for instant iteration.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Infrastructure (Docker - Keep Running)                     │
│  - Anvil (Ethereum local node): localhost:8545              │
│  - Token Faucet: localhost:3500                             │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  Connector Peer1 (Local Node Process)                       │
│  - BTP: localhost:3001                                      │
│  - Health: localhost:8081                                   │
│  - Admin: localhost:8091                                    │
│  - Explorer: localhost:3011                                 │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  Crosstown Peer1 (Local Node Process)                       │
│  - BLS: localhost:3101                                      │
│  - Nostr Relay: localhost:7101                              │
└─────────────────────────────────────────────────────────────┘
```

## Prerequisites

✅ Anvil + Faucet running in Docker (already done!)
✅ Node.js >= 22.11.0
✅ pnpm >= 8

## Step 1: Build Everything

```bash
# Build crosstown packages
cd /Users/jonathangreen/Documents/crosstown
pnpm build

# Build connector packages
cd /Users/jonathangreen/Documents/connector
npm run build
```

## Step 2: Start Connector Peer1 (Local)

```bash
cd /Users/jonathangreen/Documents/connector/packages/connector

# Set environment variables
export ENVIRONMENT=development
export LOCAL_DELIVERY_URL=http://localhost:3101
export SETTLEMENT_ENABLED=true
export BASE_L2_RPC_URL=http://localhost:8545
export TOKEN_NETWORK_REGISTRY=0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
export M2M_TOKEN_ADDRESS=0x5FbDB2315678afecb367f032d93F642f64180aa3
export TREASURY_EVM_PRIVATE_KEY=0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a
export EXPLORER_ENABLED=true
export BTP_PORT=3001
export HEALTH_PORT=8081
export ADMIN_PORT=8091
export EXPLORER_PORT=3011

# Run connector
node dist/main.js
```

## Step 3: Start Crosstown Peer1 (Local)

Open a new terminal:

```bash
cd /Users/jonathangreen/Documents/crosstown/packages/bls

# Set environment variables
export NODE_ID=peer1
export NOSTR_SECRET_KEY=d5c4f02f7c0f9c8e7a6b5d4e3f2a1b0c9d8e7f6a5b4c3d2e1f0a9b8c7d6e5f4a
export ILP_ADDRESS=g.crosstown.peer1
export CONNECTOR_ADMIN_URL=http://localhost:8091
export CONNECTOR_URL=http://localhost:8081
export BTP_ENDPOINT=btp+ws://localhost:3001
export BLS_PORT=3101
export WS_PORT=7101
export BASE_PRICE_PER_BYTE=10
export SPSP_MIN_PRICE=0
export PEER_EVM_ADDRESS=0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC
export M2M_TOKEN_ADDRESS=0x5FbDB2315678afecb367f032d93F642f64180aa3
export TOKEN_NETWORK_REGISTRY=0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
export INITIAL_DEPOSIT=100000
export DATA_DIR=./data-peer1
export ENTRYPOINT=entrypoint-with-bootstrap.js

# Run crosstown node
node dist/${ENTRYPOINT}
```

## Step 4: Start Connector Peer2 (Local)

Open a new terminal:

```bash
cd /Users/jonathangreen/Documents/connector/packages/connector

export ENVIRONMENT=development
export LOCAL_DELIVERY_URL=http://localhost:3102
export SETTLEMENT_ENABLED=true
export BASE_L2_RPC_URL=http://localhost:8545
export TOKEN_NETWORK_REGISTRY=0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
export M2M_TOKEN_ADDRESS=0x5FbDB2315678afecb367f032d93F642f64180aa3
export TREASURY_EVM_PRIVATE_KEY=0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6
export EXPLORER_ENABLED=true
export BTP_PORT=3002
export HEALTH_PORT=8082
export ADMIN_PORT=8092
export EXPLORER_PORT=3012

node dist/main.js
```

## Step 5: Start Crosstown Peer2 (Local)

Open a new terminal:

```bash
cd /Users/jonathangreen/Documents/crosstown/packages/bls

export NODE_ID=peer2
export NOSTR_SECRET_KEY=b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3
export ILP_ADDRESS=g.crosstown.peer2
export CONNECTOR_ADMIN_URL=http://localhost:8092
export CONNECTOR_URL=http://localhost:8082
export BTP_ENDPOINT=btp+ws://localhost:3002
export BLS_PORT=3102
export WS_PORT=7102
export BASE_PRICE_PER_BYTE=10
export PEER_EVM_ADDRESS=0x90F79bf6EB2c4f870365E785982E1f101E93b906
export M2M_TOKEN_ADDRESS=0x5FbDB2315678afecb367f032d93F642f64180aa3
export TOKEN_NETWORK_REGISTRY=0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
export INITIAL_DEPOSIT=100000
export DATA_DIR=./data-peer2
export BOOTSTRAP_RELAYS=ws://localhost:7101
export BOOTSTRAP_PEERS=719705df863f0190e0c124bbb11dd84b6374d077f66c4912a039324c98dc25e3
export ENTRYPOINT=entrypoint-with-bootstrap.js

node dist/${ENTRYPOINT}
```

## After Code Changes

**Instant iteration - no Docker rebuilds!**

### Connector changes:

```bash
cd /Users/jonathangreen/Documents/connector
npm run build
# Restart the connector process (Ctrl+C and re-run)
```

### Crosstown changes:

```bash
cd /Users/jonathangreen/Documents/crosstown
pnpm --filter @crosstown/core build  # Or whichever package changed
pnpm --filter @crosstown/bls build
# Restart the crosstown process (Ctrl+C and re-run)
```

**Rebuild time: ~3-5 seconds**
**Restart time: ~1-2 seconds**
**Total iteration: ~5 seconds** (vs. 5-10 minutes with Docker!)

## Verify Bootstrap Flow

### Check Genesis (Peer1):

```bash
# Check health
curl http://localhost:3101/health | jq .

# Check published kind:10032
curl -s http://localhost:8091/admin/peers | jq .
```

### Check Joiner (Peer2):

```bash
# Check health
curl http://localhost:3102/health | jq .

# Check discovered peers
curl -s http://localhost:8092/admin/peers | jq .

# Check BTP connection
curl -s http://localhost:8092/admin/peers | jq '.peers[] | select(.connected == true)'
```

### Test SPSP via ILP:

```bash
# Send test packet from peer2 to peer1
curl -X POST http://localhost:8092/admin/ilp/send \
  -H "Content-Type: application/json" \
  -d '{
    "destination": "g.crosstown.peer1",
    "amount": "1000",
    "data": "dGVzdA=="
  }' | jq .
```

## Benefits vs. Docker

| Aspect             | Docker              | Local Node         |
| ------------------ | ------------------- | ------------------ |
| **Startup Time**   | 10-20s              | 1-2s               |
| **Rebuild Time**   | 5-10min             | 3-5s               |
| **Iteration Time** | 5-10min             | 5s                 |
| **Debugging**      | Docker logs         | Direct console.log |
| **File Changes**   | Volume mounts       | Instant            |
| **Resource Usage** | High (4 containers) | Low (4 processes)  |

## Troubleshooting

### Port already in use:

```bash
lsof -ti:3101 | xargs kill -9  # Kill process on port 3101
```

### BTP connection failing:

- Check both connector and crosstown are running
- Check CONNECTOR_ADMIN_URL points to correct port
- Verify BTP_ENDPOINT uses correct port
- Check BTP auth uses empty string (fixed!)

### SPSP not routing:

- Verify peer registration: `curl http://localhost:8092/admin/peers`
- Check BTP connected: `curl http://localhost:8092/admin/peers | jq '.peers[] | select(.connected == true)'`
- Check routes exist: `curl http://localhost:8092/admin/routes`
