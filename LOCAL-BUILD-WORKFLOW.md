# Local Build Workflow for Bootstrap Testing

## Overview

This workflow uses **local builds** mounted as volumes instead of rebuilding Docker images.
This dramatically speeds up the development iteration cycle.

## Prerequisites

✅ **Already Running:**

- Anvil (Ethereum local node): `http://localhost:8545` (Chain ID: 31337)
- Token Faucet: `http://localhost:3500`
- Token Contract: `0x5FbDB2315678afecb367f032d93F642f64180aa3`
- Token Network Registry: `0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512`

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Crosstown Packages (Local Builds)                          │
│  - @crosstown/core      → packages/core/dist/               │
│  - @crosstown/bls       → packages/bls/dist/                │
│  - @crosstown/relay     → packages/relay/dist/              │
│  - @crosstown/client    → packages/client/dist/             │
└─────────────────────────────────────────────────────────────┘
                              │ mounted as volumes
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  Docker Containers (Base Images Only)                       │
│  - crosstown-peer1      → crosstown:bootstrap image         │
│  - crosstown-peer2      → crosstown:bootstrap image         │
│  - connector-peer1      → crosstown/connector:1.20.0-dev    │
│  - connector-peer2      → crosstown/connector:1.20.0-dev    │
└─────────────────────────────────────────────────────────────┘
```

## Quick Start

### 1. Build All Packages Locally

```bash
# From crosstown root
pnpm build

# Verify builds
ls -la packages/bls/dist/entrypoint-with-bootstrap.js
ls -la packages/core/dist/index.js
ls -la packages/client/dist/index.js
ls -la packages/relay/dist/index.js
```

### 2. Start Bootstrap Network (Using Local Builds)

```bash
# Stop any existing containers
docker-compose -f docker-compose-bootstrap.yml -f docker-compose-bootstrap-dev.yml down -v

# Start with local builds mounted
docker-compose -f docker-compose-bootstrap.yml -f docker-compose-bootstrap-dev.yml up -d

# Watch logs
docker-compose -f docker-compose-bootstrap.yml -f docker-compose-bootstrap-dev.yml logs -f crosstown-peer1 crosstown-peer2
```

### 3. After Code Changes

```bash
# Rebuild only changed packages
pnpm --filter @crosstown/bls build      # If you changed BLS
pnpm --filter @crosstown/core build     # If you changed core
pnpm --filter @crosstown/client build   # If you changed client

# Restart containers (NO IMAGE REBUILD NEEDED!)
docker-compose -f docker-compose-bootstrap.yml -f docker-compose-bootstrap-dev.yml restart crosstown-peer1 crosstown-peer2
```

## Bootstrap Flow Test

### Phase 1: Genesis Startup

**Expected Genesis (Peer1) Logs:**

```
✅ Nostr relay started on port 7100
✅ SPSP server started
✅ Genesis peer: Published ILP info (kind:10032) to local relay
✅ Running as bootstrap node
```

**Verify:**

```bash
# Check genesis published kind:10032
docker logs crosstown-peer1 2>&1 | grep -E "kind:10032|Genesis"

# Check relay is listening
curl http://localhost:7101/health || echo "Relay not responding"
```

### Phase 2: Joiner Discovery

**Expected Joiner (Peer2) Logs:**

```
✅ Querying ws://crosstown-peer1:7100 for peer info
✅ Peer discovered: 719705df...
✅ Bootstrap event: bootstrap:peer-registered
```

**Verify:**

```bash
# Check joiner discovered genesis
docker logs crosstown-peer2 2>&1 | grep -E "discovered|peer-registered"

# Check connector peer added
curl http://localhost:8092/admin/peers | jq '.[] | select(.id | startswith("nostr-"))'
```

### Phase 3: SPSP Handshake

**Expected Logs:**

```
Genesis (Peer1):
  📨 SPSP request from b2c3d4e5f6a7b8c9...
  ✅ Payment channel opened: ch-...
  ✅ SPSP response sent to b2c3d4e5...

Joiner (Peer2):
  ✅ SPSP response received
  ✅ Payment channel opened: ch-...
  ✅ Bootstrap event: bootstrap:channel-opened
```

**Verify:**

```bash
# Check SPSP handshake
docker logs crosstown-peer1 2>&1 | grep SPSP
docker logs crosstown-peer2 2>&1 | grep SPSP

# Check payment channels
curl http://localhost:8091/admin/channels | jq '.'
curl http://localhost:8092/admin/channels | jq '.'
```

### Phase 4: Packet Routing

```bash
# Send test packet from peer2 → peer1
curl -X POST http://localhost:3102/send \
  -H "Content-Type: application/json" \
  -d '{
    "destination": "g.crosstown.peer1",
    "amount": "1000",
    "data": "test"
  }'
```

## Debugging

### Check Genesis Peer State

```bash
# Full logs
docker logs crosstown-peer1

# Bootstrap events only
docker logs crosstown-peer1 2>&1 | grep "🔔"

# SPSP events only
docker logs crosstown-peer1 2>&1 | grep "📨"

# Connector state
curl http://localhost:8091/admin/peers | jq .
curl http://localhost:8091/admin/channels | jq .
```

### Check Joiner Peer State

```bash
# Full logs
docker logs crosstown-peer2

# Discovery phase
docker logs crosstown-peer2 2>&1 | grep "Bootstrap"

# Connector state
curl http://localhost:8092/admin/peers | jq .
curl http://localhost:8092/admin/channels | jq .
```

### Common Issues

**Issue: "No kind:10032 event found"**

- Genesis hasn't published yet, wait 5-10 seconds
- Check genesis logs: `docker logs crosstown-peer1 | grep kind:10032`

**Issue: "SPSP handshake rejected"**

- Check payment channel opening failed
- Check channel client logs in connector

**Issue: "Connection closed before receiving events"**

- Relay WebSocket timeout
- Check relay is running: `curl http://localhost:7101/health`

## Performance Comparison

| Method                         | Time to Iterate |
| ------------------------------ | --------------- |
| **Docker Image Rebuild**       | 5-10 minutes    |
| **Local Build + Volume Mount** | 5-10 seconds    |

## File Structure

```
crosstown/
├── packages/
│   ├── bls/dist/              # Built BLS (mounted to containers)
│   ├── core/dist/             # Built core (mounted to containers)
│   ├── client/dist/           # Built client (mounted to containers)
│   └── relay/dist/            # Built relay (mounted to containers)
├── docker-compose-bootstrap.yml        # Base config
├── docker-compose-bootstrap-dev.yml    # Local build overrides
└── LOCAL-BUILD-WORKFLOW.md            # This file
```

## Volume Mounts (from docker-compose-bootstrap-dev.yml)

```yaml
crosstown-peer1:
  volumes:
    - ./packages/bls/dist:/app/dist:ro
    - ./packages/core:/app/node_modules/@crosstown/core:ro
    - ./packages/client:/app/node_modules/@crosstown/client:ro
    - ./packages/relay:/app/node_modules/@crosstown/relay:ro
```

This mounts the **entire package directories** (not just dist) so Node.js module resolution finds:

- `package.json` (for exports/main)
- `dist/` (for compiled code)
- `*.d.ts` (for TypeScript types)

## Next Steps

1. ✅ Local builds working
2. ⬜ Test full bootstrap flow (Phase 1-4)
3. ⬜ Test settlement triggering
4. ⬜ Test multi-peer network (peer3, peer4)
5. ⬜ Document connector HTTP mode integration
