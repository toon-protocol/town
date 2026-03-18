# @toon-protocol/town Examples

Learn how to run a full TOON relay node using the `startTown()` API. All examples are self-contained — they use embedded connectors and require no external infrastructure.

## Prerequisites

**Install dependencies:**
```bash
cd examples/town-example
npm install
```

## Deployment Modes

`startTown()` supports two deployment modes:

- **Standalone** (`connectorUrl`): Connect to an external connector via HTTP. The connector handles BTP peering and ILP routing. Examples 01-03 use this mode.
- **Embedded** (`connector`): Pass a `ConnectorNode` directly for zero-latency packet delivery. No HTTP overhead. Example 04 demonstrates this mode.

## Examples

### 01 — Start a Town Node (Standalone)

Start a single relay node with `startTown()`, verify it's healthy, then shut it down.

```bash
npm run start-town
```

**What you'll learn:**
- How `startTown()` wraps the entire SDK pipeline into a single call
- Configuration: identity, ports, connector URL
- Health endpoint and bootstrap results
- Graceful shutdown via `town.stop()`

### 02 — Full Lifecycle (Two Towns, Standalone)

Start two Town nodes with standalone connectors peered via BTP. Publish a Nostr event from Town A to Town B, then read it back from Town B's WebSocket relay.

```bash
npm run full-lifecycle
```

**What you'll learn:**
- Running multiple Town nodes simultaneously on different ports
- Direct ILP routing: Town A → ConnectorA → ConnectorB → Town B
- Publishing events via the connector admin ILP endpoint
- Querying a Town's relay via WebSocket (NIP-01 REQ/EVENT/EOSE)

### 03 — Subscribe to a Remote Relay

Publish an event to Town A, then subscribe to Town A's relay from Town B via raw WebSocket. Demonstrates the "free to read" model.

```bash
npm run subscribe
```

**What you'll learn:**
- Raw WebSocket subscription to a remote relay
- "Free to read" — no ILP payment required for subscriptions
- Subscription lifecycle: connect → subscribe → receive → close

### 04 — Embedded Town (Two Towns, Embedded)

Two Town nodes with `ConnectorNode` instances passed directly — no HTTP in the ILP path.

```bash
npm run embedded-town
```

**What you'll learn:**
- Passing `connector` instead of `connectorUrl` to `startTown()`
- `deploymentMode: 'embedded'` connector configuration (no admin API or local delivery ports)
- Zero-latency packet delivery via `connector.setPacketHandler()`
- BLS HTTP server still runs for `/health` (unchanged)

### 05 — x402 HTTP Publish (Epic 3)

Full end-to-end x402 payment flow: pricing negotiation, EIP-3009 authorization signing, and on-chain USDC settlement via `transferWithAuthorization`. Automatically upgrades the Anvil mock ERC-20 with EIP-3009 support and funds the client.

```bash
# One-time: compile the EIP-3009 USDC contract
forge build --root . --contracts contracts --out contracts/out

npm run x402-publish
```

**Requires:** Anvil + SDK E2E infra running (`./scripts/sdk-e2e-infra.sh up`), Foundry installed

**What you'll learn:**
- x402 protocol flow: POST without payment → 402 pricing → sign EIP-3009 → POST with X-PAYMENT
- How to construct and sign an EIP-3009 `transferWithAuthorization` using viem
- On-chain settlement: facilitator submits signed authorization, client USDC balance decreases
- Anvil cheat codes: `anvil_setCode` to upgrade contracts, `anvil_setBalance` for ETH funding
- The facilitator model: node operator receives USDC and pays gas

### 06 — Service Discovery + Enriched Health (Epic 3)

Demonstrates the enriched `/health` endpoint and kind:10035 service discovery events. Shows how clients and peers discover node capabilities.

```bash
npm run service-discovery
```

**What you'll learn:**
- Enriched health response: chain, pricing, capabilities, x402 status, TEE info
- kind:10035 service discovery events published at startup
- Two discovery paths: HTTP `/health` (direct) and Nostr REQ (decentralized)

### 07 — TEE Attestation Verification (Epic 4)

Pure library demo of TEE attestation verification. No infrastructure required.

```bash
npm run attestation-verify
```

**What you'll learn:**
- `AttestationVerifier`: verify PCR values against a known-good registry
- `AttestationState` lifecycle: VALID → STALE → UNATTESTED
- Peer ranking: attested peers preferred but non-attested remain connectable
- How Marlin Oyster CVM attestations work in the TOON network

## Embedded Connector Configuration

Each example uses `ConnectorNode` from `@toon-protocol/connector` in standalone mode with the Town's BLS HTTP server handling local ILP delivery.

### Startup Order

Start connectors with **no peers** initially, then add peers after both towns are running:

```typescript
// 1. Start connectors with empty peers (health = healthy with 0/0 peers)
const connector = new ConnectorNode({
  nodeId: 'my-connector',
  deploymentMode: 'standalone',
  adminApi: { enabled: true, port: 4081 },
  localDelivery: { enabled: true, handlerUrl: 'http://localhost:3200' },
  peers: [],      // Start empty — add peers later
  routes: [],
}, logger);
await connector.start();

// 2. Start towns (startTown waits for connector health check)
const town = await startTown({ connectorUrl: 'http://localhost:4080', ... });

// 3. Add local route + remote peers AFTER both connectors are running
connector.addRoute({ prefix: town.config.ilpAddress, nextHop: 'local', priority: 0 });
await connector.registerPeer({
  id: 'remote-connector',
  url: 'ws://localhost:4210',
  authToken: '',
  routes: [{ prefix: remoteTown.config.ilpAddress, priority: 0 }],
});
```

This avoids a connector health issue: health status is only computed once at startup, so if the initial BTP connection fails (because the other connector isn't running yet), the health stays "unhealthy" and `startTown()`'s health check will time out.

### BTP Authentication

Use `authToken: ''` (empty string) for development. This enables BTP no-auth mode by default.

### Route Configuration

Every connector needs TWO types of routes:
- **LOCAL route** (`nextHop: 'local'`): Deliver packets addressed to THIS town to the BLS HTTP handler
- **REMOTE route** (`nextHop: '<peer-id>'`): Forward packets for the other town via BTP

## Architecture

```
┌───────────────────────────────────────────────────────┐
│                    startTown()                         │
│                                                       │
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────┐ │
│  │ WebSocket    │  │ BLS HTTP     │  │ Bootstrap   │ │
│  │ Relay        │  │ Server       │  │ Service     │ │
│  │ (NIP-01)     │  │ /health      │  │ Peer        │ │
│  │              │  │ /handle-pkt  │  │ Discovery   │ │
│  └──────┬───────┘  └──────┬───────┘  └─────────────┘ │
│         │                 │                           │
│  ┌──────┴─────────────────┴───────┐                  │
│  │     SQLite EventStore          │                  │
│  └────────────────────────────────┘                  │
│                                                       │
│  ┌────────────────────────────────┐                  │
│  │ ConnectorNode (standalone)     │                  │
│  │ BTP ◄──► Remote Connector      │                  │
│  └────────────────────────────────┘                  │
└───────────────────────────────────────────────────────┘
```

## Key Concepts

- **Batteries included**: `startTown()` creates everything — relay, BLS server, event store, bootstrap — in one call.
- **Standalone connector**: The Town connects to a `ConnectorNode` via HTTP. The connector handles BTP peering and ILP routing.
- **Settlement optional**: Omit `chainRpcUrls`/`tokenNetworks` to run without payment channels.
- **TOON-native**: The relay returns events in TOON format, not standard JSON Nostr events.
- **Raw WebSocket**: Use raw WebSocket for relay subscriptions in Node.js (`nostr-tools` SimplePool references `window` and crashes outside browsers).
