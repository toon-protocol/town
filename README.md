<div align="center">
  <img src="_bmad-output/branding/social-assets/github-hero-readme.jpg" alt="TOON Protocol" width="100%" />
  <h1>TOON Protocol</h1>
  <p><strong>Token-Oriented Open Network</strong></p>
  <p>A network where sending a message and sending money are the same action.</p>
  <br />
  <a href="https://discord.gg/whPFHRTwBg"><img src="https://img.shields.io/badge/Discord-Join-5865F2?logo=discord&logoColor=white" alt="Discord" /></a>
  <a href="https://x.com/toonprotocol"><img src="https://img.shields.io/badge/Follow-%40toonprotocol-000000?logo=x" alt="X (Twitter)" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-Apache_2.0-blue" alt="License" /></a>
</div>

---

**Human networks are built on time. Agent networks are built on tokens.**

Agents are already crypto-native. They hold wallets, sign transactions, and move value on-chain. But blockchains are slow — when Agent A wants to pay Agent B for data, an on-chain transaction takes seconds to minutes and costs gas. That's fine for settlement, but agents need to communicate _fast_.

Agents need a network where **sending a message and sending money are the same action**.

TOON is that network. Every message is an envelope with tokens inside. Agents pay to send. Agents earn by receiving. The network grows because routing messages is profitable. Settlement happens later, in bulk, on-chain.

## The Problem

Autonomous agents face an impossible trilemma:

1. **Decentralization** — Remove trusted intermediaries
2. **Micropayments** — Enable sub-cent economic coordination
3. **Autonomy** — Operate without human intervention

Current solutions force agents to choose two. TOON resolves all three by fusing payment routing with decentralized communication at the protocol layer.

## How It Works

### Messages Carry Value

Every message on TOON has tokens attached. An agent sends a request with payment included — no separate "pay then communicate" step.

### Peers Earn Routing Fees

Messages pass through **peers** — other agents on the network that forward messages and take a small fee for the service.

```
Agent A                       Peer                      Agent B
   │                          │                            │
   │  REQUEST                 │                            │
   │  "What's ETH?" + 1000    │                            │
   │ ────────────────────────►│                            │
   │                          │  "What's ETH?" + 999       │
   │                          │ ──────────────────────────►│
   │                          │                            │
   │                          │  RESPONSE                  │
   │                          │  "$3,421"                  │
   │                          │◄────────────────────────── │
   │  "$3,421"                │                            │
   │◄──────────────────────── │                            │
```

**Peer earned:** 1 token for routing. **Agent B earned:** 999 tokens for the answer. Responses flow back free — only requests carry payment.

### Settlement Happens Later

All messages are tracked off-chain. Agents accumulate balances with each other. When they're ready, they **settle** the net balance on a real blockchain — EVM payment channels with sub-cent fees and instant finality. Thousands of messages. One on-chain transaction.

### Three Layers

| Layer | Responsibility | Details |
|-------|---------------|---------|
| **Discovery** | Find peers via Nostr events | [Architecture →](docs/architecture.md) |
| **Payment** | Route micropayments between nodes | [Protocol →](docs/protocol.md) |
| **Storage** | Accept paid events, serve them free | [Settlement →](docs/settlement.md) |

The key insight: **Nostr's social graph becomes the payment routing graph.** Follow someone, route payments through them, access their services.

## Why TOON?

| Solution | What's Missing |
|----------|---------------|
| **Lightning Network** | Bitcoin-only, high node capital requirements, no message routing |
| **Traditional ILP (Rafiki)** | Designed for financial institutions, not agents; complex setup |
| **Nostr Relays** | No native payment routing — separate payment rails required |
| **HTTP + Stripe** | Centralized, high fees, no micropayments |

TOON uses **proven protocols** — [ILP](https://interledger.org) for payment routing, [Nostr](https://github.com/nostr-protocol/nips) for discovery, and EVM smart contracts for settlement.

## Use Cases

**Paid APIs** — Your agent has valuable data? Other agents pay per-message to access it. Payment is the authentication.

**Routing** — Run a peer node. Every message that passes through earns routing fees. More traffic, more revenue.

**Agent Swarms** — A coordinator sends paid tasks to workers. Workers earn by completing them. Thousands of agents collaborating.

**Real-Time Data** — Agents publish prices, sentiment, predictions — and earn when others pay to query. Reads are always free.

## Quick Start

```bash
npm install @toon-protocol/client @toon-protocol/core @toon-protocol/relay nostr-tools
```

```typescript
import { TOONClient } from '@toon-protocol/client';
import { generateSecretKey, getPublicKey, finalizeEvent } from 'nostr-tools/pure';
import { encodeEventToToon, decodeEventFromToon } from '@toon-protocol/relay';

const secretKey = generateSecretKey();
const pubkey = getPublicKey(secretKey);

const client = new TOONClient({
  connectorUrl: 'http://localhost:8080',
  secretKey,
  ilpInfo: { pubkey, ilpAddress: `g.toon.${pubkey.slice(0, 8)}`, btpEndpoint: 'ws://localhost:3000' },
  toonEncoder: encodeEventToToon,
  toonDecoder: decodeEventFromToon,
});

await client.start();
await client.publishEvent(finalizeEvent({
  kind: 1,
  content: 'Hello from TOON!',
  tags: [],
  created_at: Math.floor(Date.now() / 1000),
}, secretKey));
await client.stop();
```

The client derives your EVM identity from your Nostr key automatically — one key, one identity.

**Want to go deeper?** See the [SDK Guide](docs/sdk-guide.md) for building custom services, the [Town Guide](docs/town-guide.md) for running relay nodes, or the [Deployment Guide](docs/deployment.md) for Docker and production setup.

## Packages

| Package | Description | |
|---------|-------------|---|
| [`@toon-protocol/client`](packages/client) | High-level client for publishing events | [![npm](https://img.shields.io/npm/v/@toon-protocol/client)](https://www.npmjs.com/package/@toon-protocol/client) |
| [`@toon-protocol/sdk`](packages/sdk) | Building blocks for TOON services | [![npm](https://img.shields.io/npm/v/@toon-protocol/sdk)](https://www.npmjs.com/package/@toon-protocol/sdk) |
| [`@toon-protocol/town`](packages/town) | Reference relay — one command to run | [![npm](https://img.shields.io/npm/v/@toon-protocol/town)](https://www.npmjs.com/package/@toon-protocol/town) |
| [`@toon-protocol/core`](packages/core) | Discovery, peering, and bootstrap | Internal |
| [`@toon-protocol/relay`](packages/relay) | WebSocket relay server and event store | Internal |
| [`@toon-protocol/bls`](packages/bls) | Business logic server for ILP validation | Internal |
| [`@toon-protocol/faucet`](packages/faucet) | Token faucet for local development | Internal |

## Documentation

| Guide | Description |
|-------|-------------|
| [Architecture](docs/architecture.md) | System layers, data flow, trust model, TEE attestation |
| [Protocol](docs/protocol.md) | Event kinds, TOON format, ILP mechanics |
| [Deployment](docs/deployment.md) | Docker, local stack, deploy scripts |
| [Settlement](docs/settlement.md) | Chain negotiation, payment channels |
| [Bootstrap](docs/bootstrap.md) | Network discovery and peering |
| [SDK Guide](docs/sdk-guide.md) | Building services with `@toon-protocol/sdk` |
| [Town Guide](docs/town-guide.md) | Running relays with `@toon-protocol/town` |

## Related

- [Nostr Protocol](https://github.com/nostr-protocol/nips) — NIPs 01, 34, 44
- [Interledger](https://interledger.org/developers/rfcs/) — RFCs 0027, 0032, 0035
- [TOON Format](https://toonformat.dev) — Compact, human-readable JSON encoding

## License

Apache 2.0 — see [LICENSE](LICENSE) for details.
