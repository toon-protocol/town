# @toon-protocol/sdk Examples

Learn the TOON SDK by running these self-contained examples. No external infrastructure required — everything runs in-process using embedded connectors.

## Prerequisites

**Install dependencies:**
```bash
cd examples/sdk-example
npm install
```

## Deployment Modes

`createNode()` supports two deployment modes:

- **Embedded** (`connector`): Pass a `ConnectorNode` directly for zero-latency packet delivery. Examples 02-04 use this mode.
- **Standalone** (`connectorUrl` + `handlerPort`): Connect to an external connector via HTTP. The SDK starts an HTTP server on `handlerPort` to receive packets. Example 05 demonstrates this mode.

## Examples

### 01 — Identity Generation

Generate a BIP-39 mnemonic and derive a unified Nostr + EVM identity. No infrastructure required.

```bash
npm run identity
```

**What you'll learn:**
- How a single secp256k1 key produces both a Nostr pubkey (Schnorr) and an EVM address (Keccak-256)
- BIP-39 mnemonic generation and account derivation (NIP-06 path)
- Creating an identity from a raw secret key

### 02 — Create Two Nodes (Embedded)

Create two SDK nodes with embedded ILP connectors peered directly via BTP and register custom event handlers.

```bash
npm run create-node
```

**What you'll learn:**
- Creating `ConnectorNode` instances for embedded ILP routing
- Using `createNode()` to wire the full pipeline (TOON parse → verification → pricing → handler dispatch)
- Registering kind-specific handlers with `node.on(kind, handler)`
- Direct BTP peering between two embedded connectors (no genesis infrastructure needed)
- Local and remote route configuration

### 03 — Publish Events (Full Lifecycle, Embedded)

Complete lifecycle: two nodes publish events to each other through direct BTP peering, demonstrating bi-directional routing.

```bash
npm run publish-event
```

**What you'll learn:**
- Publishing Nostr events via `node.publishEvent(event, { destination })`
- How TOON encoding and per-byte pricing work
- Direct ILP packet routing via embedded connectors
- Handler context: `ctx.decode()`, `ctx.accept()`, `ctx.reject()`
- Bi-directional routing (A→B and B→A)

### 04 — On-Chain Payment Channels (Embedded)

Real EVM settlement: publish events until the settlement threshold is exceeded, then watch the connector automatically open a payment channel and deposit tokens on-chain.

**Prerequisite:** Anvil running via `./scripts/sdk-e2e-infra.sh up` (deploys USDC token + TokenNetwork contracts).

```bash
npm run payment-channel
```

**What you'll learn:**
- Enabling `settlementInfra` on `ConnectorNode` for on-chain settlement
- Funding EVM wallets with ERC-20 tokens (viem)
- Connector routing fee: sender sets ~10% higher `basePricePerByte` to cover the connector's 0.1% fee
- Configuring settlement thresholds for automatic on-chain settlement
- How the connector handles channel open, deposit, per-packet EIP-712 signed claims, and settlement automatically
- Querying on-chain channel state via `paymentChannelSDK` (channel ID, participants, deposits, status)
- Verifying settlement with assertions: wallet diffs, channel existence, ILP balance cleared

### 05 — Standalone Server

SDK service nodes connecting to external connectors via HTTP instead of embedding them.

```bash
npm run standalone-server
```

**What you'll learn:**
- Using `connectorUrl` + `handlerPort` instead of `connector` in `createNode()`
- How the SDK starts an HTTP server with `/handle-packet` and `/health` endpoints
- Standalone connector configuration (`deploymentMode: 'standalone'`, `localDelivery`, `adminApi`)
- The `node.connector` property returns `null` in standalone mode
- Bi-directional routing through standalone connectors (HTTP + BTP)

## Embedded Connector Configuration

Each example uses `ConnectorNode` from `@toon-protocol/connector` in embedded mode. Key configuration patterns:

### BTP Authentication

Use `authToken: ''` (empty string) for development. This enables no-auth mode:

```typescript
const connector = new ConnectorNode({
  nodeId: 'my-node',
  btpServerPort: 6000,
  deploymentMode: 'embedded',
  peers: [{
    id: 'remote-node',        // Must match the remote connector's nodeId
    url: 'ws://localhost:6010',
    authToken: '',             // No-auth mode for development
  }],
  routes: [...],
}, logger);
```

### Route Configuration

Every connector needs TWO types of routes:

```typescript
routes: [
  // LOCAL route: deliver packets addressed to THIS node to the SDK handler
  { prefix: 'g.toon.my-node', nextHop: 'local', priority: 0 },
  // REMOTE route: forward packets for the other node via BTP
  { prefix: 'g.toon.other-node', nextHop: 'other-node', priority: 0 },
]
```

Without the local route, packets addressed to this node will get F02 "no route found".

### Peer ID Convention

The peer `id` in the config must match the **remote** connector's `nodeId`. The BTP client sends its `nodeId` during authentication, so the peer ID must match for the connection to be recognized.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Your Application                         │
├─────────────────────────────────────────────────────────────┤
│  createNode()     Handler Registry      publishEvent()      │
│  ┌──────────┐    ┌──────────────────┐   ┌──────────────┐   │
│  │ Identity  │    │ .on(1, handler)  │   │ TOON encode  │   │
│  │ Pipeline  │    │ .onDefault(...)  │   │ Compute amt  │   │
│  │ Verify    │    │                  │   │ ILP PREPARE  │   │
│  │ Pricing   │    │                  │   │              │   │
│  └──────────┘    └──────────────────┘   └──────────────┘   │
├─────────────────────────────────────────────────────────────┤
│  ConnectorNode (embedded ILP connector)                     │
│  ┌──────────┐    ┌──────────────────┐                      │
│  │ BTP Peer │◄──►│ Remote Connector │                      │
│  └──────────┘    └──────────────────┘                      │
└─────────────────────────────────────────────────────────────┘
```

## Key Concepts

- **Pay to write, free to read**: Publishing events requires ILP payment (amount = `basePricePerByte * toonBytes`). Reading is free.
- **TOON format**: TOON uses a compact binary encoding (not JSON) for Nostr events.
- **Handler pipeline**: Incoming packets pass through signature verification → pricing validation → handler dispatch.
- **Embedded connector**: Each node runs its own ILP connector in-process for direct packet routing.
- **Standalone connector**: The connector runs externally. The SDK connects via HTTP and starts its own HTTP server for incoming packets.
