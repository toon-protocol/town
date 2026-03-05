# Crosstown Setup Guide

**Complete guide to get ILP-gated Git with NIP-34 running in 10 minutes.**

---

## Prerequisites

- Docker and Docker Compose installed
- Node.js 20+ (for local development/testing)
- Git

---

## Quick Start (3 Steps)

### Step 1: Start the Infrastructure

```bash
# Clone repository
git clone https://github.com/your-org/crosstown.git
cd crosstown

# Generate Nostr key (one-time)
export NOSTR_SECRET_KEY=$(openssl rand -hex 32)
echo "NOSTR_SECRET_KEY=$NOSTR_SECRET_KEY" > .env

# Start all services
docker compose -f docker-compose-with-local.yml up -d
```

**Wait 30 seconds** for all services to start.

### Step 2: Configure Forgejo (Git Server)

```bash
# 2a. Open Forgejo in your browser
open http://localhost:3003

# 2b. Complete initial setup (if first time):
#     - Leave all defaults
#     - Create admin account: username=admin, password=admin123
#     - Click "Install Forgejo"

# 2c. Generate API token
# Go to: Settings → Applications → Generate New Token
# Scopes: Select "All" or at minimum:
#   - write:repository
#   - write:issue
#   - write:pull_request
# Name: crosstown
# Click Generate

# 2d. Copy the token and add to .env
echo "FORGEJO_TOKEN=your-token-here" >> .env
echo "FORGEJO_OWNER=admin" >> .env
```

### Step 3: Enable NIP-34 Integration

```bash
# Restart Crosstown node to load Forgejo config
docker compose -f docker-compose-with-local.yml restart crosstown-node

# Verify NIP-34 is enabled
docker logs crosstown-node 2>&1 | grep NIP-34

# Should see:
# ✅ NIP-34 Git integration enabled (Forgejo: http://forgejo:3000)
```

**Done! Your ILP-gated Git server is ready.**

---

## What Just Happened?

You now have a complete stack running:

| Service                | Port             | Purpose                               |
| ---------------------- | ---------------- | ------------------------------------- |
| **Crosstown Node**     | 3100, 7100       | BLS + Nostr relay + NIP-34 handler    |
| **ILP Connector**      | 8080, 8081, 3001 | Payment routing + admin API           |
| **Git Proxy**          | 3003             | ILP-gated Git operations (clone/push) |
| **Forgejo Web UI**     | 3004             | Browse repos (FREE, read-only)        |
| **Forgejo (internal)** | -                | Git repository storage                |
| **Anvil**              | 8545             | Local Ethereum (for payment channels) |
| **Token Faucet**       | 3500             | Get test tokens                       |

---

## Testing the Setup

### Test 1: Health Checks

```bash
# Check all services are healthy
docker compose -f docker-compose-with-local.yml ps

# All should show "healthy" status
```

### Test 2: Create a Git Repository

```bash
# 1. Go to Forgejo Web UI (free browsing)
open http://localhost:3004

# 2. Login as admin (if not already)

# 3. Click "+" → "New Repository"
#    - Owner: admin
#    - Name: test-repo
#    - Description: Testing ILP-gated Git
#    - Visibility: Public
#    - Click "Create Repository"

# Note: Repository is created through web UI (free)
# But git clone/push will require payment (port 3003)
```

### Test 3: NIP-34 Integration (Submit Patch via Nostr)

```bash
# We'll create a simple test script
./test-nip34.sh
```

I'll create this test script next.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    Your Git Workflow                     │
├──────────────────┬──────────────────────────────────────┤
│  Traditional Git │  Nostr Events (NIP-34)               │
│  (HTTP)          │                                       │
└────────┬─────────┴────────────┬────────────────────────┘
         │                      │
         ▼                      ▼
    ┌─────────┐          ┌──────────────┐
    │Git Proxy│          │Crosstown Node│
    │(pay/op) │          │(Nostr relay) │
    └────┬────┘          └──────┬───────┘
         │                      │
         │ ┌────────────────────┘
         ▼ ▼
    ┌─────────────┐
    │   Forgejo   │ ← Your actual Git repositories
    │ (Git Server)│
    └─────────────┘
```

**Two ways to interact with Git:**

1. **Standard Git Commands** - via Git Proxy (port 3003)
   - `git clone http://localhost:3003/admin/test-repo.git`
   - Requires ILP payment per operation
   - Works with any Git client

2. **Nostr Events** - via NIP-34
   - Submit patches as Nostr events
   - Automatically applied to Forgejo
   - Decentralized, censorship-resistant

---

## Common Tasks

### Get Tokens for Testing

```bash
# Open faucet
open http://localhost:3500

# Enter your Ethereum address
# Get 100 ETH + 10,000 AGENT tokens
```

### View Connector Explorer

```bash
# See ILP packet routing and payments
open http://localhost:3001
```

### Check Logs

```bash
# Crosstown node (BLS + Nostr + NIP-34)
docker logs -f crosstown-node

# Git proxy (payment gateway)
docker logs -f crosstown-git-proxy

# Forgejo (Git server)
docker logs -f crosstown-forgejo

# ILP Connector
docker logs -f crosstown-connector
```

### Restart a Service

```bash
# Restart just one service
docker compose -f docker-compose-with-local.yml restart crosstown-node

# Restart everything
docker compose -f docker-compose-with-local.yml restart
```

### Stop Everything

```bash
# Stop but keep data
docker compose -f docker-compose-with-local.yml stop

# Stop and remove (fresh start)
docker compose -f docker-compose-with-local.yml down -v
```

---

## Environment Variables Reference

Create a `.env` file in the project root:

```bash
# Required
NOSTR_SECRET_KEY=<hex-key>         # Your Nostr identity
FORGEJO_TOKEN=<api-token>          # From Forgejo settings
FORGEJO_OWNER=admin                # Forgejo username

# Optional - Pricing
GIT_READ_PRICE=100                 # ILP units to clone/fetch
GIT_WRITE_PRICE=1000               # ILP units to push
GIT_PRICE_PER_KB=10                # Additional per KB

BASE_PRICE_PER_BYTE=10             # Nostr event pricing
SPSP_MIN_PRICE=5                   # SPSP minimum

# Optional - Settlement
PEER_EVM_ADDRESS=0x...             # Your Ethereum address
M2M_TOKEN_ADDRESS=0x5FbDB...       # Token contract (auto-set)

# Optional - Debugging
GIT_PROXY_VERBOSE=true             # Detailed Git proxy logs
VERBOSE=true                       # Detailed Crosstown logs
```

---

## Troubleshooting

### NIP-34 Not Enabled

**Symptom:**

```
📝 NIP-34 Git integration disabled
```

**Solution:**

1. Check `.env` has `FORGEJO_TOKEN` and `FORGEJO_OWNER`
2. Restart: `docker compose -f docker-compose-with-local.yml restart crosstown-node`

### Forgejo Token Invalid

**Symptom:**

```
⚠️  Failed to initialize NIP-34 handler: 401 Unauthorized
```

**Solution:**

1. Regenerate token in Forgejo settings
2. Update `.env` file
3. Restart crosstown-node

### Git Proxy Returns 502

**Symptom:**

```
git clone http://localhost:3003/admin/test-repo.git
fatal: unable to access: 502 Bad Gateway
```

**Solution:**

1. Check Forgejo is running: `docker ps | grep forgejo`
2. Check git-proxy logs: `docker logs crosstown-git-proxy`
3. Verify internal network: `docker exec crosstown-git-proxy ping forgejo`

### Connector Not Healthy

**Symptom:**

```
crosstown-connector unhealthy
```

**Solution:**

1. Check config: `docker logs crosstown-connector | grep error`
2. Verify config file: `config/connector-config-with-base.yaml`
3. Restart: `docker compose -f docker-compose-with-local.yml restart connector`

### Port Already in Use

**Symptom:**

```
Error: bind: address already in use
```

**Solution:**

1. Find conflicting process: `lsof -i :3003` (or whichever port)
2. Stop it or change port in docker-compose.yml
3. Restart: `docker compose -f docker-compose-with-local.yml up -d`

---

## Next Steps

### 1. Test Standard Git Operations

```bash
# Clone a repo (will require payment setup)
git clone http://localhost:3003/admin/test-repo.git
```

### 2. Test NIP-34 Patch Submission

```bash
# Use the test script (coming next)
./test-nip34.sh
```

### 3. Set Up Multi-Peer Network

```bash
# For testing peer discovery and payment channels
docker compose -f docker-compose-bootstrap.yml up -d
```

### 4. Integrate with Your Application

- Read `packages/core/README.md` for API documentation
- Check `packages/git-proxy/README.md` for proxy integration
- See `NIP-34-INTEGRATION.md` for Nostr event workflows

---

## Getting Help

- **Logs:** `docker compose -f docker-compose-with-local.yml logs`
- **Health:** `curl http://localhost:3100/health`
- **Issues:** https://github.com/your-org/crosstown/issues

---

## Summary

✅ **What you have:**

- ILP-gated Git server (pay to push/pull)
- Nostr relay with NIP-34 support
- Local Ethereum network (Anvil)
- Payment channels infrastructure
- Token faucet for testing

✅ **What you can do:**

- Clone/push Git repos with ILP payments
- Submit patches via Nostr events
- Test peer discovery and bootstrap
- Build on the Crosstown protocol

🚀 **You're ready to build decentralized, monetized Git infrastructure!**
