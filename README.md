# Crosstown

**An ILP-gated Nostr relay that solves relay sustainability through micropayments: pay to write, free to read.**

Crosstown bridges Nostr and Interledger Protocol (ILP) to create a self-sustaining relay network. Nodes publish their ILP connector info as Nostr events, discover peers by subscribing to relays, and negotiate payment channels through encrypted SPSP handshakes — eliminating manual peering configuration.

## Mental Model

Think of Crosstown as **three layers working together**:

1. **Discovery Layer** (`@crosstown/core`) — Find and peer with ILP nodes using Nostr events
2. **Payment Layer** (ILP Connector) — Route micropayments between peers
3. **Storage Layer** (`@crosstown/relay` + `@crosstown/bls`) — Accept paid events, store them, serve them for free

The key insight: **Nostr's social graph becomes the payment routing graph**. If you follow someone on Nostr, you can route payments through them.

## Why Use Crosstown?

**For Relay Operators:**

- Generate revenue from writes (finally a business model!)
- No need to manually configure peering relationships
- Spam protection via pay-per-byte pricing

**For AI Agents:**

- Discover and connect to ILP payment networks without hardcoded configs
- Pay for Nostr storage using existing ILP infrastructure
- Bootstrap payment channels automatically using Nostr follows

**For Protocol Developers:**

- Proof-of-concept for solving relay sustainability
- Reference implementation for ILP-gated content
- Demonstrates Nostr as a service discovery layer

## How It Works

Crosstown uses **custom Nostr event kinds** to enable ILP peering and payment-gated services:

### Core ILP Peering Events

| Kind      | Name          | Discovery                  | Purpose                                                                                                            |
| --------- | ------------- | -------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| **10032** | ILP Peer Info | Public (anyone can read)   | Advertise your node's ILP address, BTP endpoint, supported chains, and settlement addresses — like a business card |
| **23194** | SPSP Request  | Private (NIP-44 encrypted) | "I want to open a payment channel with you — here are my supported chains"                                         |
| **23195** | SPSP Response | Private (NIP-44 encrypted) | "Channel opened on chain X at address Y — here's your channel ID and payment destination"                          |

### NIP-34: Git Operations via Nostr (Payment-Gated)

| Kind      | Name                    | Purpose                                        |
| --------- | ----------------------- | ---------------------------------------------- |
| **30617** | Repository Announcement | Advertise Git repositories available via Nostr |
| **1617**  | Patch                   | Submit code changes (like `git push`)          |
| **1621**  | Issue                   | Create issues in repositories                  |
| **1622**  | Reply                   | Comment on patches or issues                   |

**NIP-34 provides payment-gated Git operations** — users pay via ILP to submit patches, create issues, and interact with repositories. Unlike traditional Git HTTP (which is free), NIP-34 submissions require micropayments and are automatically applied to the Forgejo Git server.

**Why these event kinds?**

- **10032** is a _replaceable event_ — when your connector details change (new settlement address, different chains), you publish a new event with the same `d` tag and it replaces the old one
- **23194/23195** use _NIP-44 encryption_ — negotiation happens in the open (via relays) but payment secrets stay private
- **NIP-34 kinds (30617, 1617, 1621, 1622)** provide payment-gated Git operations via Nostr events

### NIP-34 Git Integration: Payment-Gated Git via Nostr

Crosstown includes **NIP-34 (Git Stuff)** integration, allowing users to interact with Git repositories through Nostr events instead of traditional Git HTTP. This provides a **payment-gated alternative** to free HTTP Git operations.

**How it works:**

```
Developer                    Crosstown BLS                 Forgejo Git Server
    │                              │                              │
    │  1. Create patch             │                              │
    │     (kind:1617 event)        │                              │
    │                              │                              │
    │  2. ILP Prepare              │                              │
    │     (TOON-encoded event)     │                              │
    │ ──────────────────────────> │                              │
    │                              │  3. Validate payment         │
    │                              │     (price = bytes × rate)   │
    │                              │                              │
    │                              │  4. Store event              │
    │                              │                              │
    │                              │  5. Apply patch via API      │
    │                              │ ──────────────────────────> │
    │                              │                              │  Create branch
    │                              │                              │  Commit changes
    │                              │                              │  Update refs
    │                              │                              │
    │  6. ILP Fulfill              │ <─────────────────────────── │
    │ <────────────────────────── │                              │
    │     (proof of storage)       │                              │
```

**Why use NIP-34 instead of HTTP Git?**

| Feature              | HTTP Git (port 3004)           | NIP-34 (via Nostr)                        |
| -------------------- | ------------------------------ | ----------------------------------------- |
| **Payment**          | FREE                           | PAID (micropayments via ILP)              |
| **Protocol**         | Standard Git HTTP              | Nostr events                              |
| **Spam protection**  | None                           | Payment requirement                       |
| **Decentralization** | Centralized (direct to server) | Decentralized (via Nostr relays)          |
| **Monetization**     | No revenue                     | Repository owners earn from contributions |

**Setting up NIP-34:**

1. **Configure Forgejo API token** in `.env`:

   ```bash
   FORGEJO_TOKEN=your-api-token-here
   FORGEJO_OWNER=admin
   FORGEJO_URL=http://forgejo:3000
   ```

2. **Submit a patch via Nostr** (requires ILP payment):

   ```bash
   # Example: Submit a patch as a kind:1617 event
   # Payment is automatically required by BLS
   # See NIP-34-INTEGRATION.md for detailed examples
   ```

3. **Repository owner receives payment** for each contribution accepted

**Learn more:** See [NIP-34-INTEGRATION.md](NIP-34-INTEGRATION.md) for complete workflows and examples.

### Network Bootstrap: Joining the Network

When a new node starts, it goes through **three phases** to join the network:

```
New Node                               Genesis Node (already on network)
   │                                              │
   │  Phase 1: DISCOVER                          │
   │  ─────────────────────────────────────────> │
   │  Query relay: "show me all kind:10032"      │
   │  Result: found 5 peer info events           │
   │                                              │
   │  Phase 2: HANDSHAKE                         │
   │  ILP Prepare (kind:23194 encrypted request) │
   │  ─────────────────────────────────────────> │
   │                                              │  "I support chains A, B, C"
   │                                              │  "Let's use chain B"
   │                                              │  Opens payment channel on-chain
   │  ILP Fulfill (kind:23195 encrypted response)│
   │ <───────────────────────────────────────────│
   │  "Channel opened! ID=abc123"                │
   │                                              │
   │  Phase 3: ANNOUNCE                          │
   │  ILP Prepare (my kind:10032 event in TOON)  │
   │  ─────────────────────────────────────────> │
   │  Payment: 1500 units for 150 bytes          │
   │                                              │  Store event in relay
   │  ILP Fulfill                                 │
   │ <───────────────────────────────────────────│
   │                                              │
   │  Now visible to other nodes! ✓              │
```

**What happens in each phase:**

1. **DISCOVER** — Free read from relay to find existing peers (kind:10032 events)
2. **HANDSHAKE** — Negotiate settlement chain and open payment channel (kind:23194/23195 via ILP)
3. **ANNOUNCE** — Pay to publish your own kind:10032 event so others can discover you

**After bootstrap:** The `RelayMonitor` continuously watches for new kind:10032 events. When a new peer appears, it's added to the discovered peers list — but peering doesn't happen automatically. You call `node.peerWith(pubkey)` when you're ready to establish a payment channel with that peer.

## Architecture

Crosstown is a monorepo with four packages:

| Package                                        | Purpose                          | Status      | Key Exports                                                                                                             |
| ---------------------------------------------- | -------------------------------- | ----------- | ----------------------------------------------------------------------------------------------------------------------- |
| **[@crosstown/core](packages/core)**           | Discovery & peering foundation   | ✅ Active   | `createCrosstownNode()`, `BootstrapService`, `RelayMonitor`, SPSP client/server, settlement negotiation, NIP-34 handler |
| **[@crosstown/relay](packages/relay)**         | Nostr relay WebSocket server     | ✅ Active   | `NostrRelayServer`, `EventStore`, TOON encoding, upstream relay propagation via `RelaySubscriber`                       |
| **[@crosstown/bls](packages/bls)**             | Standalone Business Logic Server | ✅ Active   | `createBlsServer()` — HTTP server that validates ILP payments and stores events, NIP-34 integration                     |
| **[@crosstown/faucet](packages/faucet)**       | Token distribution service       | ✅ Active   | Web-based faucet for distributing test ETH and AGENT tokens to developers                                               |
| **[@crosstown/git-proxy](packages/git-proxy)** | HTTP Git payment gateway         | ⚠️ Disabled | ILP-gated Git HTTP operations (needs redesign per RFC-0035)                                                             |
| **[@crosstown/examples](packages/examples)**   | Working demos                    | ✅ Active   | `ilp-gated-relay-demo` showing the full stack in action                                                                 |

**Package Relationships:**

- `@crosstown/core` is the foundation (no dependencies on other packages)
- `@crosstown/relay` depends on `@crosstown/bls` (integrates BLS validation with relay serving)
- `@crosstown/bls` can run standalone (Docker) or embedded (imported by relay)
- `@crosstown/examples` shows how everything fits together

### Data Flow: How Writes and Reads Work

**Reading (Free)**

```
Client              Relay
  │                   │
  │  REQ (filter)     │
  │ ───────────────> │
  │                   │  Query EventStore
  │  EVENT (match 1)  │
  │ <─────────────── │
  │  EVENT (match 2)  │
  │ <─────────────── │
  │  EOSE             │
  │ <─────────────── │
```

**Writing (Paid via ILP)**

```
Client              Connector               Relay (BLS)           EventStore
  │                      │                        │                     │
  │  ILP Prepare         │                        │                     │
  │  (TOON event data)   │                        │                     │
  │ ──────────────────> │  Route packet          │                     │
  │                      │ ──────────────────────>│                     │
  │                      │                        │  1. Decode TOON      │
  │                      │                        │     (validates format)
  │                      │                        │  2. Verify signature │
  │                      │                        │     (validates crypto)
  │                      │                        │  3. Check payment    │
  │                      │                        │     (amount >= bytes*price)
  │                      │                        │  4. Store event ────>│
  │                      │                        │  5. Generate proof   │
  │  ILP Fulfill         │  Return fulfillment    │                     │
  │ <────────────────── │ <────────────────────── │                     │
```

**Key Points:**

- Reads use standard Nostr WebSocket protocol (NIP-01)
- Writes bypass WebSocket and use ILP packet routing
- Events are TOON-encoded (text format) and transmitted as UTF-8 bytes in ILP packet data
- **BLS validates TOON format BEFORE checking payment** — prevents paying to store garbage data
- Returns cryptographic proof of payment (fulfillment) only after all validations pass

## Deployment Modes

Crosstown can run in two modes:

### Mode 1: Embedded (Library)

**Use when:** Building an AI agent or application that needs to send/receive ILP payments via Nostr

**How it works:** Import `@crosstown/core` and `@crosstown/relay` as libraries. The ILP connector runs in-process — no HTTP overhead, just direct function calls.

**Benefits:**

- Zero network latency between relay and connector
- Single process to manage
- Easier debugging

```typescript
import { createCrosstownNode } from '@crosstown/core';
import { encodeEventToToon, decodeEventFromToon } from '@crosstown/relay';

const node = createCrosstownNode({
  connector, // EmbeddableConnectorLike instance
  handlePacket, // ILP packet handler function
  secretKey, // 32-byte Nostr secret key (Uint8Array)
  ilpInfo: {
    ilpAddress: 'g.agent.peer1',
    btpEndpoint: 'btp+ws://localhost:3000',
    assetCode: 'USD',
    assetScale: 6,
    supportedChains: ['evm:base:84532'],
    settlementAddresses: { 'evm:base:84532': '0x6AFbC4...' },
    preferredTokens: { 'evm:base:84532': '0x39eaF9...' },
    tokenNetworks: { 'evm:base:84532': '0x733b89...' },
  },
  toonEncoder: encodeEventToToon,
  toonDecoder: decodeEventFromToon,
  relayUrl: 'ws://relay.example.com',
  knownPeers: [{ pubkey, relayUrl, btpEndpoint }],
  settlementInfo,
  basePricePerByte: 10n,
});

// Subscribe to lifecycle events
node.bootstrapService.on((event) => console.log(event));
node.relayMonitor.on((event) => console.log(event));

// Bootstrap: discover peers, handshake genesis, announce self
const result = await node.start();
console.log(
  `Connected to ${result.peerCount} peers, opened ${result.channelCount} channels`
);

// Explicit peering with discovered peers
const discovered = node.relayMonitor.getDiscoveredPeers();
for (const peer of discovered) {
  await node.peerWith(peer.pubkey);
}
```

### Mode 2: Docker (Standalone)

**Use when:** Running Crosstown as a microservice alongside an external ILP connector (like Rafiki)

**How it works:** The BLS runs as an HTTP server. Your external connector sends ILP packets via `POST /handle-packet`. The Nostr relay runs on a separate WebSocket port.

**Build and run:**

```bash
docker build -f docker/Dockerfile -t crosstown .
docker run -p 3100:3100 -p 7100:7100 \
  -e NOSTR_SECRET_KEY=<64-char-hex> \
  -e ILP_ADDRESS=g.agent.peer1 \
  -e BTP_ENDPOINT=ws://connector:3000 \
  -e CONNECTOR_URL=http://connector:8081 \
  -e SUPPORTED_CHAINS=evm:base:84532 \
  -e SETTLEMENT_ADDRESS_evm_base_84532=0x6AFbC4... \
  crosstown
```

**Exposed ports:**

| Port     | Service                                                      | Protocol  |
| -------- | ------------------------------------------------------------ | --------- |
| **3100** | BLS — accepts `POST /handle-packet` with ILP PREPARE packets | HTTP      |
| **7100** | Nostr relay — standard NIP-01 WebSocket for reads            | WebSocket |

**Benefits:**

- Decouples relay from connector lifecycle
- Can scale independently
- Works with any ILP connector that speaks HTTP

## Key Design Decisions

### 1. Pay to Write, Free to Read

**Problem:** Nostr relays cost money to run but have no revenue model. This leads to relay centralization and spam.

**Solution:** Writers pay per byte via ILP. Readers access everything for free.

**How it works:**

The BLS validates in this order (fail-fast):

1. **Decode UTF-8 and parse TOON** → Reject if malformed text structure
2. **Verify signature** → Reject if cryptographic signature invalid
3. **Check payment** → Reject if `amount < (event_bytes × price_per_byte)`
4. **Store event** → Write to EventStore (SQLite as TOON text)
5. **Return proof** → Generate ILP FULFILL with cryptographic fulfillment

**Why validate TOON before payment?**

- Prevents paying to store garbage data
- Fails fast on malformed packets (saves processing)
- Ensures only valid Nostr events consume storage

**Special rules:**

- **Relay owner writes free** — You don't pay to publish on your own relay (checked after signature verification)
- **SPSP bootstrap pricing** — kind:23194 events can have lower minimums to make joining the network cheaper

### 2. TOON-Native Format

**Problem:** Nostr events in JSON are verbose. Parsing JSON repeatedly wastes CPU and network bandwidth.

**Solution:** Use [TOON](https://toonformat.dev) — a compact, human-readable encoding of the JSON data model.

**Event lifecycle (TOON all the way):**

1. Client encodes event to TOON text → converts to UTF-8 bytes → embeds in ILP packet data
2. **BLS decodes UTF-8 → parses TOON (validates format)** → verifies signature → checks payment → stores as TOON in SQLite
3. Relay reads TOON from disk → sends TOON to WebSocket subscribers
4. `RelaySubscriber` propagates TOON to upstream relays

**Why TOON?**

- **Compact:** 5-10% smaller than JSON for simple events, more efficient for uniform arrays
- **Human-readable:** Uses YAML-like `key: value` syntax — easier to debug than binary formats
- **LLM-optimized:** Designed for token efficiency and reliable parsing by language models
- **Validated early:** TOON format checked before payment, preventing garbage data storage
- **Deterministic:** Lossless round-trips preserve all data and structure

**Example:** A simple text note (actual measurements):

```yaml
# TOON format (327 bytes UTF-8)
id: aaaa...aaaa
pubkey: bbbb...bbbb
kind: 1
content: gm
tags[0]:
created_at: 1234567890
sig: cccc...cccc

# JSON format (344 bytes UTF-8)
{"id":"aaaa...aaaa","pubkey":"bbbb...bbbb","kind":1,"content":"gm","tags":[],"created_at":1234567890,"sig":"cccc...cccc"}
```

**Validation ordering matters:** The BLS decodes UTF-8 bytes and parses TOON **before** checking payment. If the TOON is malformed, the packet is rejected immediately with `BAD_REQUEST`, even if the payment amount is correct. This prevents paying for invalid data.

### 3. Passive Discovery, Explicit Peering

**Problem:** Auto-peering with every discovered node could open you to attacks or unwanted connections.

**Solution:** Separate _seeing_ peers from _connecting_ to them.

**How it works:**

| Phase         | What Happens                                                                                                                                                      | Triggered By             |
| ------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------ |
| **Discovery** | `RelayMonitor` subscribes to kind:10032 events and maintains a live list of available peers                                                                       | Automatic (continuous)   |
| **Peering**   | You explicitly call `node.peerWith(pubkey)` which triggers: connector registration → SPSP handshake (kind:23194/23195) → settlement negotiation → channel opening | Manual (when you decide) |

**Why this matters:**

- **Security** — You control who you peer with
- **Cost** — Opening payment channels costs gas; you only pay for peers you trust
- **Awareness** — You always know who's available, even if you haven't peered yet

**Example:**

```typescript
// Discovery happens automatically in the background
const discovered = node.relayMonitor.getDiscoveredPeers();
console.log(`Found ${discovered.length} peers`);

// Peering only happens when you decide
for (const peer of discovered) {
  if (await myTrustCheck(peer.pubkey)) {
    await node.peerWith(peer.pubkey); // Now we're connected
  }
}
```

### 4. Settlement Negotiation

**Problem:** Different nodes may support different blockchains for settlement. How do they agree?

**Solution:** Automated chain negotiation during the SPSP handshake.

**How it works:**

1. **Advertise** — Both nodes publish kind:10032 events listing their supported chains:

   ```json
   {
     "supportedChains": ["evm:base:84532", "evm:sepolia:11155111"],
     "settlementAddresses": {
       "evm:base:84532": "0xABC...",
       "evm:sepolia:11155111": "0xDEF..."
     }
   }
   ```

2. **Request** — Joiner sends kind:23194: "I want to peer, I support chains X, Y, Z"

3. **Negotiate** — Genesis node runs `negotiateSettlementChain()` to find common chains:
   - Finds intersection of supported chains
   - Picks optimal chain (prefer mainnet > testnet, lower fees > higher)

4. **Open Channel** — Genesis calls `connector.openChannel()` on the negotiated chain

5. **Response** — Genesis sends kind:23195: "Channel opened on chain B, address 0x123, channel ID abc"

**Chain format:** `{blockchain}:{network}:{chainId}`

Examples:

- `evm:base:84532` — Base Sepolia testnet
- `evm:base:8453` — Base mainnet
- `xrp:mainnet` — XRP Ledger mainnet

### 5. Multiple Discovery Sources

**Problem:** How does a brand new node find its first peer?

**Solution:** Four complementary discovery mechanisms:

| Source                               | When Used | Why It Exists                                                                          |
| ------------------------------------ | --------- | -------------------------------------------------------------------------------------- |
| **Config (`knownPeers`)**            | Bootstrap | Hardcoded genesis nodes — the first peers you connect to when joining the network      |
| **ArDrive Registry**                 | Bootstrap | Decentralized peer list stored on Arweave — global registry of Crosstown nodes         |
| **Environment (`ADDITIONAL_PEERS`)** | Runtime   | JSON-formatted peer injection — useful for Docker deployments or dynamic configuration |
| **RelayMonitor**                     | Ongoing   | Real-time subscription to kind:10032 events — discovers new peers as they join         |

**Bootstrap flow:**

1. Load peers from config → merge with ArDrive registry → merge with env var
2. Peer with at least one genesis node (usually the first peer in your known peers list)
3. Once connected, `RelayMonitor` subscribes to the relay and discovers new peers continuously

**Why multiple sources?**

- **Redundancy** — If ArDrive is down, you can still bootstrap from config
- **Flexibility** — Environment variables let you inject peers without rebuilding
- **Decentralization** — ArDrive provides a shared registry without requiring a central server

## Quick Start

> **⚡ Important: What's Payment-Gated?**
>
> - ✅ **Nostr event writes** (kind:1, etc.) → PAID via ILP
> - ✅ **NIP-34 Git operations** (patches, issues) → PAID via ILP
> - ❌ **HTTP Git operations** (git clone, git push) → FREE (no payment required)
> - ❌ **Forgejo Web UI** (browse, view) → FREE (no payment required)
>
> **Why HTTP Git is free:** The git-proxy (HTTP Git payment gateway) has been temporarily disabled as it needs to be redesigned to properly implement ILP over HTTP (RFC-0035). In the meantime, use **NIP-34** for payment-gated Git operations via Nostr events.

### Run the Demo (Embedded Mode)

The fastest way to see Crosstown in action:

```bash
# Prerequisites: Node.js 20+, pnpm 8+
git clone https://github.com/ALLiDoizCode/crosstown.git
cd crosstown

pnpm install          # Install dependencies
pnpm build            # Build all packages
pnpm test             # Run tests (optional)

# Run the ILP-gated relay demo
pnpm demo:ilp-gated-relay
```

**What the demo does:**

1. Creates two nodes (genesis and joiner) with mock ILP connectors
2. Genesis publishes its kind:10032 peer info event
3. Joiner discovers genesis via relay subscription
4. Joiner handshakes with genesis (kind:23194/23195)
5. Joiner announces itself by paying to write its own kind:10032 event

### Local Development Stack (Recommended)

The easiest way to develop with Crosstown — includes everything you need:

```bash
# Start full local stack: Anvil + Connector + Crosstown + Faucet + Forgejo
docker compose -f docker-compose-with-local.yml up -d

# Get test tokens instantly from the faucet
open http://localhost:3500
```

**What you get:**

| Service                 | URL                            | Purpose                                     | Payment    |
| ----------------------- | ------------------------------ | ------------------------------------------- | ---------- |
| **🚰 Token Faucet**     | http://localhost:3500          | Get 100 ETH + 10,000 AGENT tokens instantly | FREE       |
| **⚡ Anvil**            | http://localhost:8545          | Local Ethereum blockchain (chain ID 31337)  | FREE       |
| **🔗 Connector**        | http://localhost:8080          | ILP packet routing (v1.19.1)                | -          |
| **📊 Explorer UI**      | http://localhost:3001          | Monitor ILP packets and balances            | FREE       |
| **📡 Crosstown BLS**    | http://localhost:3100          | Payment validation & event storage          | -          |
| **🌐 Nostr Relay**      | ws://localhost:7100            | Read events for free                        | FREE       |
| **🦊 Forgejo Web UI**   | http://localhost:3004          | Browse repos, edit files, view commits      | FREE       |
| **📦 Forgejo Git HTTP** | http://localhost:3004/repo.git | Standard Git operations (clone, push, pull) | FREE       |
| **⚡ NIP-34 Git**       | Via Nostr events               | Submit patches/issues via Nostr             | PAID (ILP) |

**Quick workflow:**

1. **Get tokens** → Visit faucet, enter your address, receive tokens
2. **Deploy contracts** → Automatically deployed on startup
3. **Test payments** → Send ILP packets through the connector
4. **Store events** → Pay to write Nostr events to the relay
5. **Read for free** → Query events via WebSocket

**Token Faucet Features:**

- Distributes **100 ETH** and **10,000 AGENT tokens** per request
- **Rate limited** to 1 request per address per hour
- **Auto-discovery** of deployed contract addresses
- **Beautiful web UI** with real-time balance tracking
- **RESTful API** for programmatic access

**Deployed Contracts (Local Anvil):**

- **AGENT Token** (ERC20): Mock token for testing payment channels
- **TokenNetwork**: Payment channel registry for off-chain transfers

**Stop the stack:**

```bash
docker compose -f docker-compose-with-local.yml down
```

### Docker Deployment (Standalone Mode)

Run Crosstown as a microservice:

```bash
docker build -f docker/Dockerfile -t crosstown .
docker run -p 3100:3100 -p 7100:7100 \
  -e NOSTR_SECRET_KEY=$(openssl rand -hex 32) \
  -e ILP_ADDRESS=g.mynode \
  -e SUPPORTED_CHAINS=evm:base:84532 \
  -e SETTLEMENT_ADDRESS_evm_base_84532=0xYourAddress \
  crosstown
```

Visit:

- `http://localhost:3100/health` — BLS health check
- `ws://localhost:7100` — Nostr relay WebSocket

### Development Guidelines

When contributing to Crosstown:

- **Use `nostr-tools` for all Nostr operations** — Don't reinvent event signing, validation, etc.
- **Separate concerns** — ILP logic in `@crosstown/core`, storage logic in `@crosstown/relay`, payment validation in `@crosstown/bls`
- **Mock external dependencies** — Tests shouldn't require live relays or real ILP connectors
- **Passive discovery pattern** — Services observe and expose data; callers decide when to act

## Nostr Event Kinds

Crosstown implements and extends several Nostr event kinds:

### Implemented: NIP-34 (Git Stuff)

**Status:** ✅ Fully implemented with ILP payment gating

| Kind      | Name                    | Purpose                                  |
| --------- | ----------------------- | ---------------------------------------- |
| **30617** | Repository Announcement | Advertise Git repositories               |
| **1617**  | Patch                   | Submit code changes (paid via ILP)       |
| **1621**  | Issue                   | Create repository issues (paid via ILP)  |
| **1622**  | Reply                   | Comment on patches/issues (paid via ILP) |

**Integration:** Crosstown's BLS validates NIP-34 events and automatically applies them to Forgejo via API. This enables **payment-gated Git operations** — users pay micropayments to submit patches, and repository owners earn revenue from contributions.

**Learn more:** [NIP-34 Specification](https://github.com/nostr-protocol/nips/blob/master/34.md) | [Integration Guide](NIP-34-INTEGRATION.md)

### Proposed: ILP Peering via Nostr Events

**Status:** ⚠️ Implemented in Crosstown, not yet submitted as formal NIP

| Kind      | Name          | Type                         | Purpose                                                                                         |
| --------- | ------------- | ---------------------------- | ----------------------------------------------------------------------------------------------- |
| **10032** | ILP Peer Info | Parameterized replaceable    | Advertise ILP connector details (address, BTP endpoint, supported chains, settlement addresses) |
| **23194** | SPSP Request  | Ephemeral encrypted (NIP-44) | Request payment channel setup with settlement chain negotiation                                 |
| **23195** | SPSP Response | Ephemeral encrypted (NIP-44) | Respond with opened channel ID and payment destination                                          |

**Why this could be a NIP:**

- Enables **decentralized ILP connector discovery** without DNS or central registries
- Provides **encrypted payment channel negotiation** using existing Nostr infrastructure
- Makes **micropayment routing** inherit Nostr's social graph (follow someone → route payments through them)

**Future work:** Submit to `nostr-protocol/nips` repository for standardization

## Related Specifications

### Nostr Specifications

- [NIP-01: Basic Protocol](https://github.com/nostr-protocol/nips/blob/master/01.md) — Base Nostr relay protocol
- [NIP-34: Git Stuff](https://github.com/nostr-protocol/nips/blob/master/34.md) — Git operations via Nostr events (repositories, patches, issues)
- [NIP-44: Encrypted Payloads](https://github.com/nostr-protocol/nips/blob/master/44.md) — Secures SPSP handshakes

### Interledger Specifications

- [RFC 0009: SPSP](https://interledger.org/developers/rfcs/simple-payment-setup-protocol/) — Simple Payment Setup Protocol
- [RFC 0027: ILPv4](https://interledger.org/developers/rfcs/interledger-protocol-v4/) — Interledger Protocol V4
- [RFC 0032: Peering, Clearing and Settlement](https://interledger.org/developers/rfcs/peering-clearing-settling/) — ILP peering model
- [RFC 0035: ILP Over HTTP](https://interledger.org/developers/rfcs/ilp-over-http/) — Transport ILP packets over HTTP

### Other

- [TOON Format](https://toonformat.dev) — Compact, human-readable JSON encoding for LLMs

## License

MIT
