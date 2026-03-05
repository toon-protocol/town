# Crosstown Architecture

**Visual guide to how everything fits together**

---

## Complete System Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         USER / DEVELOPER                            │
│                                                                     │
│  Uses:                                                              │
│  • Standard Git (clone/push)                                        │
│  • Nostr client (submit patches)                                    │
│  • Browser (Forgejo UI)                                             │
└───────────┬────────────────────────┬────────────────────────────────┘
            │                        │
            │ git clone              │ nostr publish
            │ git push               │ (NIP-34 event)
            ▼                        ▼
┌────────────────────┐    ┌──────────────────────────────┐
│   Git Proxy        │    │    Crosstown Node            │
│   Port: 3003       │    │    Ports: 3100, 7100         │
├────────────────────┤    ├──────────────────────────────┤
│ • Intercept Git    │    │ • BLS (packet validation)    │
│ • Calculate price  │    │ • Nostr relay                │
│ • Require payment  │◄───┤ • Bootstrap service          │
│ • Proxy to Forgejo │    │ • NIP-34 handler             │
└─────────┬──────────┘    └────────┬─────────────────────┘
          │                        │
          │ validate               │ validate
          │ payment                │ payment
          └───────►┌───────────────┴──┐
                   │  BLS Validation  │
                   └───────────────────┘
                           │
                           │ forward on success
                           ▼
                   ┌──────────────────┐
                   │     Forgejo      │
                   │  (Git Server)    │
                   ├──────────────────┤
                   │ • Store repos    │
                   │ • Track issues   │
                   │ • Manage PRs     │
                   │ • Web UI         │
                   └──────────────────┘
                           ▲
                           │
           ┌───────────────┴───────────────┐
           │                               │
    NIP-34 handler              Git Proxy forward
    (apply patches)             (HTTP requests)


┌─────────────────────────────────────────────────────────────────────┐
│                    PAYMENT INFRASTRUCTURE                           │
├──────────────────┬──────────────────┬───────────────────────────────┤
│  ILP Connector   │  Anvil (ETH)     │  Token Faucet                 │
│  Port: 8080/8081 │  Port: 8545      │  Port: 3500                   │
│                  │                  │                               │
│ • Route packets  │ • Local chain    │ • Dispense test tokens        │
│ • Peer management│ • Payment channels│ • Fund test wallets           │
│ • Settlement     │ • Smart contracts│                               │
└──────────────────┴──────────────────┴───────────────────────────────┘
```

---

## Flow 1: Standard Git Operation (HTTP)

```
1. Developer runs:
   git clone http://localhost:3003/admin/my-repo.git

2. Git Proxy:
   • Detects operation: clone (read)
   • Calculates price: base (100) + size (10/KB)
   • Returns: 402 Payment Required

3. Git client includes payment proof (future: automatic via helper)

4. Git Proxy:
   • Validates payment with BLS
   • Forwards request to Forgejo
   • Streams repository data back

5. Developer has local clone ✅
```

---

## Flow 2: NIP-34 Patch Submission

```
1. Developer creates patch:
   git format-patch HEAD~1 --stdout > fix.patch

2. Encode as Nostr event (kind 1617):
   {
     "kind": 1617,
     "content": "<patch content>",
     "tags": [["a", "30617:owner-pubkey:repo-id"]]
   }

3. Calculate ILP payment:
   price = event_size × 10 units

4. Publish to Crosstown relay:
   ws://localhost:7100

5. Crosstown receives event:
   • BLS validates payment
   • Stores event in database
   • Triggers NIP34Handler

6. NIP34Handler:
   • Extracts patch from event
   • Clones repository
   • Applies patch (git am)
   • Pushes to Forgejo

7. Patch appears in Git repository ✅
```

---

## Flow 3: Bootstrap & Peer Discovery

```
1. Genesis peer starts:
   • Publishes ILP info (kind 10032) to local relay
   • Announces availability

2. Joining peer:
   • Queries relay for peers
   • Finds genesis peer info
   • Initiates SPSP handshake

3. SPSP Negotiation:
   • Exchange settlement parameters
   • Negotiate payment channel details
   • Open channel (if settlement enabled)

4. BTP Connection:
   • Register peer with connector
   • Exchange shared secret
   • Enable packet routing

5. Peers connected ✅
   • Can route ILP packets
   • Payment channel active
   • Settlement on-chain
```

---

## Data Flow Diagram

```
┌──────────────┐
│ Git Client   │
└──────┬───────┘
       │ HTTP request
       ▼
┌──────────────────┐
│ Git Proxy        │
│                  │
│ 1. Parse operation
│ 2. Calculate price
│ 3. Check payment ──────┐
│ 4. Proxy request       │
└──────┬─────────────────┘
       │                  │
       │                  ▼
       │           ┌────────────┐
       │           │    BLS     │
       │           │            │
       │           │ Validate   │
       │           │ payment    │
       │           │ proof      │
       │           └────────────┘
       │
       ▼
┌────────────────────┐
│ Forgejo            │
│                    │
│ • Serve repo data  │
│ • Apply patches    │
│ • Store commits    │
└────────────────────┘
```

---

## Payment Channel Architecture

```
Peer 1                                    Peer 2
   │                                         │
   │ 1. SPSP request (kind 23194)            │
   ├─────────────────────────────────────────►
   │                                         │
   │ 2. SPSP response (kind 23195)           │
   │    • settlement address                 │
   │    • token contract                     │
   │    • registry address                   │
   ◄─────────────────────────────────────────┤
   │                                         │
   │ 3. Open payment channel                 │
   ├──────────┐                   ┌──────────┤
   │          │                   │          │
   ▼          ▼                   ▼          ▼
┌─────────────────────┐   ┌─────────────────────┐
│ TokenNetworkRegistry│   │ TokenNetworkRegistry│
│ (on Anvil)          │   │ (on Anvil)          │
│                     │   │                     │
│ • Create channel    │   │ • Create channel    │
│ • Initial deposit   │   │ • Initial deposit   │
│ • Track balances    │   │ • Track balances    │
└─────────────────────┘   └─────────────────────┘
         │                           │
         │ 4. Channel created        │
         │    channelId = abc123     │
         │                           │
         │ 5. ILP packets flow ◄────►│
         │    (off-chain)            │
         │                           │
         │ 6. Settle on-chain        │
         │    (when needed)          │
         └───────────────────────────┘
```

---

## Component Responsibilities

### Crosstown Node

**Role:** Core ILP + Nostr integration

- Validate ILP payments
- Store Nostr events
- Handle NIP-34 Git operations
- Relay management
- Bootstrap coordination

### Git Proxy

**Role:** Payment gateway for Git HTTP

- Intercept git operations
- Calculate operation cost
- Enforce payment requirement
- Proxy to Forgejo

### Forgejo

**Role:** Git repository storage

- Store Git objects
- Manage users/permissions
- Provide web UI
- Track issues/PRs

### ILP Connector

**Role:** Payment packet routing

- Route ILP packets between peers
- Manage peer balances
- Settlement execution
- Admin API

### Anvil

**Role:** Local blockchain

- Deploy payment channel contracts
- Execute settlements
- Provide test ETH/tokens

### Token Faucet

**Role:** Test token distribution

- Dispense ETH for gas
- Dispense AGENT tokens
- Rate limiting

---

## Network Topology

### Single Node (Development)

```
┌──────────────────────────────────┐
│         Local Machine            │
│                                  │
│  ┌────────────────────────────┐  │
│  │   Docker Network           │  │
│  │                            │  │
│  │  • crosstown-node          │  │
│  │  • git-proxy               │  │
│  │  • forgejo                 │  │
│  │  • connector               │  │
│  │  • anvil                   │  │
│  │  • faucet                  │  │
│  │                            │  │
│  └────────────────────────────┘  │
└──────────────────────────────────┘
```

### Multi-Peer Network (Production)

```
Peer 1                  Peer 2                  Peer 3
┌─────────────┐        ┌─────────────┐        ┌─────────────┐
│ Crosstown   │        │ Crosstown   │        │ Crosstown   │
│   Node      │        │   Node      │        │   Node      │
└──────┬──────┘        └──────┬──────┘        └──────┬──────┘
       │                      │                      │
       │ Nostr relay          │ Nostr relay          │ Nostr relay
       │ ws://peer1:7100      │ ws://peer2:7100      │ ws://peer3:7100
       │                      │                      │
       └──────────┬───────────┴───────────┬──────────┘
                  │                       │
                  │   Peer Discovery      │
                  │   (NIP-02 follows)    │
                  │                       │
         ┌────────┴────────┐    ┌────────┴────────┐
         │ ILP Connection  │    │ ILP Connection  │
         │ (BTP/WS)        │    │ (BTP/WS)        │
         └─────────────────┘    └─────────────────┘
```

---

## Port Reference

| Port     | Service   | Protocol  | Purpose                     |
| -------- | --------- | --------- | --------------------------- |
| **3003** | git-proxy | HTTP      | Git operations (clone/push) |
| **3100** | crosstown | HTTP      | BLS packet delivery         |
| **7100** | crosstown | WebSocket | Nostr relay                 |
| **8080** | connector | HTTP      | Health check                |
| **8081** | connector | HTTP      | Admin API                   |
| **3001** | connector | HTTP      | Explorer UI                 |
| **8545** | anvil     | HTTP      | Ethereum JSON-RPC           |
| **3500** | faucet    | HTTP      | Token dispenser             |
| **3000** | forgejo   | HTTP      | Git web UI (internal)       |

---

## Storage Locations

```
Docker Volumes:
• crosstown-data:/data          → Event store, SQLite DB
• connector-data:/data          → Connector state, routes
• forgejo-data:/data            → Git repositories, SQLite

Local Build:
• packages/bls/dist/            → Compiled BLS
• packages/core/dist/           → Compiled core lib
• packages/git-proxy/dist/      → Compiled proxy
```

---

## Security Model

### Payment Validation

- All operations require valid ILP payment
- Payment proofs validated by BLS
- No operations without payment

### Access Control

- Forgejo: username/password
- Git Proxy: ILP payment = access
- Connector Admin API: no auth (local only)

### Network Isolation

- Forgejo not exposed externally
- All Git access via payment proxy
- Internal Docker network

---

**See [SETUP-GUIDE.md](SETUP-GUIDE.md) for setup instructions**
