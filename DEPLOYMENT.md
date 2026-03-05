# Crosstown Deployment Guide

Complete guide for deploying Crosstown in **External Mode** with the Agent-Runtime connector.

---

## 🏗️ **Architecture**

```
┌─────────────────────────────────────────────────────────────────┐
│                    TigerBeetle Database                         │
│                 (Settlement Accounting)                         │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│               Agent-Runtime Connector                           │
│                                                                 │
│  • ILP packet routing                                           │
│  • Peer management (BTP)                                        │
│  • Balance tracking                                             │
│  • Admin API (port 8081)                                        │
│  • Explorer UI (port 3001)                                      │
└────────────────────┬───────────────┬────────────────────────────┘
                     │               │
        ┌────────────┘               └────────────┐
        │                                         │
        ▼ POST /handle-packet                    ▼ Admin API calls
┌─────────────────────────────────────────────────────────────────┐
│              Crosstown Full Node                                │
│                                                                 │
│  ✓ BLS (Business Logic Server)     - Port 3100                 │
│  ✓ Nostr Relay (WebSocket)         - Port 7100                 │
│  ✓ Bootstrap Service                                            │
│  ✓ Peer Discovery                                               │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📦 **Prerequisites**

### 1. **Docker & Docker Compose**

```bash
docker --version  # Should be ≥ 20.10
docker compose version  # Should be ≥ 2.0
```

### 2. **Agent-Runtime Repository**

The agent-runtime must be in a sibling directory:

```bash
# Your directory structure should look like:
~/projects/
├── crosstown/           # This repository
└── agent-runtime/       # Agent-Runtime repository
```

**Clone agent-runtime if you don't have it:**

```bash
cd ~/projects
git clone https://github.com/anthropics/agent-runtime.git  # Update with actual URL
```

### 3. **Nostr Secret Key**

Generate a secret key for your node:

```bash
openssl rand -hex 32
```

Save this - you'll need it for the `.env` file.

---

## 🚀 **Quick Start (Development)**

### **Step 1: Configure Environment**

```bash
# Copy environment template
cp .env.example .env

# Edit .env and set required values:
nano .env
```

**Minimum required configuration:**

```bash
NODE_ID=my-node
NOSTR_SECRET_KEY=<your-64-char-hex-key>
ILP_ADDRESS=g.crosstown.my-node
```

### **Step 2: Build Images**

```bash
# Build Crosstown optimized image
docker build -f docker/Dockerfile -t crosstown:optimized .

# Build agent-runtime image
cd ../agent-runtime
docker build -t agent-runtime:latest .
cd ../crosstown
```

### **Step 3: Start the Stack**

```bash
docker compose -f docker-compose-full-stack.yml up -d
```

### **Step 4: Verify Deployment**

```bash
# Check all services are healthy
docker compose -f docker-compose-full-stack.yml ps

# Should show:
# ✓ crosstown-tigerbeetle    (healthy)
# ✓ crosstown-agent-runtime  (healthy)
# ✓ crosstown-node           (healthy)
```

**Test endpoints:**

```bash
# Crosstown BLS health
curl http://localhost:3100/health

# Agent-Runtime health
curl http://localhost:8080/health

# Explorer UI (in browser)
open http://localhost:3001
```

---

## 📊 **Monitoring**

### **View Logs**

```bash
# All services
docker compose -f docker-compose-full-stack.yml logs -f

# Specific service
docker compose -f docker-compose-full-stack.yml logs -f crosstown
docker compose -f docker-compose-full-stack.yml logs -f agent-runtime
docker compose -f docker-compose-full-stack.yml logs -f tigerbeetle
```

### **Explorer UI Dashboard**

Open http://localhost:3001 in your browser to view:

- Active peer connections
- ILP packet flow
- Balance tracking
- Settlement status
- Payment channels

### **Health Check Endpoints**

| Service       | Endpoint                     | Expected Response                     |
| ------------- | ---------------------------- | ------------------------------------- |
| Crosstown BLS | http://localhost:3100/health | `{"status":"healthy","nodeId":"..."}` |
| Agent-Runtime | http://localhost:8080/health | `200 OK`                              |
| Nostr Relay   | ws://localhost:7100          | WebSocket upgrade required            |

---

## 🔧 **Configuration**

### **Pricing Configuration**

Control event storage costs:

```bash
# .env
BASE_PRICE_PER_BYTE=10    # Base price (10 units per byte)
SPSP_MIN_PRICE=5          # Lower price for SPSP handshakes
ASSET_CODE=USD
ASSET_SCALE=6             # 6 = micro-USD (1 unit = 0.000001 USD)
```

**Example:**

- 1 KB Nostr event = 1024 bytes × 10 = 10,240 units = $0.01024
- SPSP request = ~200 bytes × 5 = 1,000 units = $0.001

### **Peer Discovery**

```bash
# Enable ArDrive peer lookup (default: true)
ARDRIVE_ENABLED=true

# Add known bootstrap peers
ADDITIONAL_PEERS='[
  {
    "pubkey": "abc123...",
    "ilpAddress": "g.bootstrap.peer1",
    "btpEndpoint": "ws://peer1.example.com:3000",
    "relay": "wss://relay.example.com"
  }
]'
```

### **Settlement (Payment Channels)**

For multi-hop payments with settlement:

```bash
# Enable EVM-based settlement on Base and Polygon
SUPPORTED_CHAINS=evm:base:8453,evm:polygon:137

# Your wallet addresses (one per chain)
SETTLEMENT_ADDRESS_EVM_BASE_8453=0x1234...
SETTLEMENT_ADDRESS_EVM_POLYGON_137=0x5678...

# Preferred stablecoin
PREFERRED_TOKEN_EVM_BASE_8453=USDC
PREFERRED_TOKEN_EVM_POLYGON_137=USDC

# Token network contract (if using custom token contracts)
TOKEN_NETWORK_EVM_BASE_8453=0xabcd...

# Settlement parameters
SETTLEMENT_TIMEOUT=86400      # 24 hours
INITIAL_DEPOSIT=1000000       # Initial channel deposit
```

---

## 🧪 **Testing the Deployment**

### **Test 1: Send a Test Event via ILP**

```bash
# From another Crosstown node or ILP client, send a packet:
curl -X POST http://localhost:3000/ilp/send \
  -H "Content-Type: application/json" \
  -d '{
    "destinationAccount": "g.crosstown.my-node.spsp.abc123",
    "sourceAmount": "10000",
    "data": "<base64-toon-event>"
  }'
```

Expected flow:

1. Connector routes packet to Crosstown BLS
2. BLS validates payment amount
3. BLS decodes TOON event
4. BLS stores event in relay
5. Connector returns ILP Fulfill

### **Test 2: Query Nostr Relay**

```bash
# Using websocat (install: brew install websocat)
echo '["REQ","test",{"kinds":[10032],"limit":10}]' | \
  websocat ws://localhost:7100
```

Should return stored events.

### **Test 3: Check Bootstrap Status**

```bash
curl http://localhost:3100/health | jq .

# Should show:
{
  "status": "healthy",
  "nodeId": "my-node",
  "bootstrapPhase": "ready",
  "peerCount": 0,
  "channelCount": 0
}
```

---

## 🌐 **Production Deployment**

### **Recommended Changes for Production:**

#### **1. Use Environment-Specific Images**

```bash
# Tag images with version
docker build -f docker/Dockerfile -t crosstown:1.0.0 .
docker tag crosstown:1.0.0 crosstown:latest

# Push to registry
docker tag crosstown:1.0.0 di3twater/crosstown:1.0.0
docker push di3twater/crosstown:1.0.0
docker push di3twater/crosstown:latest
```

#### **2. Enable TLS/SSL**

Add nginx reverse proxy for HTTPS:

```yaml
# docker-compose-full-stack.yml
services:
  nginx:
    image: nginx:alpine
    ports:
      - '443:443'
      - '80:80'
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./certs:/etc/nginx/certs:ro
```

#### **3. Configure Resource Limits**

```yaml
services:
  crosstown:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
        reservations:
          cpus: '1'
          memory: 1G
```

#### **4. Set Up Persistent Volumes**

```yaml
volumes:
  crosstown-data:
    driver: local
    driver_opts:
      type: none
      device: /mnt/data/crosstown
      o: bind
```

#### **5. Enable Log Rotation**

```yaml
services:
  crosstown:
    logging:
      driver: 'json-file'
      options:
        max-size: '10m'
        max-file: '3'
```

---

## 🐛 **Troubleshooting**

### **Issue: Container Won't Start**

**Check logs:**

```bash
docker compose -f docker-compose-full-stack.yml logs crosstown
```

**Common causes:**

- Missing `NOSTR_SECRET_KEY` in `.env`
- Invalid ILP address format (must start with `g.`)
- Agent-runtime not healthy (check dependency order)

**Fix:**

```bash
# Restart in correct order
docker compose -f docker-compose-full-stack.yml down
docker compose -f docker-compose-full-stack.yml up -d tigerbeetle
# Wait for healthy
docker compose -f docker-compose-full-stack.yml up -d agent-runtime
# Wait for healthy
docker compose -f docker-compose-full-stack.yml up -d crosstown
```

### **Issue: "Cannot connect to agent-runtime"**

**Check connectivity:**

```bash
docker compose -f docker-compose-full-stack.yml exec crosstown \
  wget -O- http://agent-runtime:8080/health
```

**If fails:**

- Verify both containers are on same network
- Check agent-runtime health status
- Review agent-runtime logs for errors

### **Issue: Peer Discovery Not Working**

**Check bootstrap logs:**

```bash
docker compose -f docker-compose-full-stack.yml logs crosstown | grep Bootstrap
```

**Verify ArDrive is enabled:**

```bash
# In .env
ARDRIVE_ENABLED=true
```

**Check relay connectivity:**

```bash
docker compose -f docker-compose-full-stack.yml exec crosstown \
  nc -zv localhost 7100
```

### **Issue: Payment Channels Not Opening**

**Verify settlement configuration:**

```bash
docker compose -f docker-compose-full-stack.yml exec crosstown \
  printenv | grep SETTLEMENT
```

**Check agent-runtime admin API:**

```bash
curl http://localhost:8081/admin/channels
```

**Common causes:**

- Missing `SUPPORTED_CHAINS` configuration
- No settlement address for negotiated chain
- Insufficient initial deposit
- Token network contract not deployed

---

## 📖 **Additional Resources**

- [Agent-Runtime Documentation](https://github.com/anthropics/agent-runtime)
- [Interledger Protocol](https://interledger.org)
- [Nostr Protocol](https://nostr.com)
- [TigerBeetle](https://tigerbeetle.com)

---

## 🆘 **Getting Help**

- **Issues:** https://github.com/ALLiDoizCode/crosstown/issues
- **Discussions:** https://github.com/ALLiDoizCode/crosstown/discussions
- **Discord:** [Join our community]

---

**Happy deploying! 🚀**
