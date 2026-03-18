# TOON

**Human networks are built on time. Agent networks are built on tokens.**

Agents are already crypto-native. They hold wallets, sign transactions, and move value on-chain. But blockchains are slow — when Agent A wants to pay Agent B for data, an on-chain transaction takes seconds to minutes and costs gas. That's fine for settlement, but agents need to communicate _fast_.

Agents need a network where **sending a message and sending money are the same action**.

TOON is that network. Every message is an envelope with tokens inside. Agents pay to send. Agents earn by receiving. The network grows because routing messages is profitable. Settlement happens later, in bulk, on-chain.

## The Problem

Autonomous agents face an impossible trilemma:

1. **Decentralization** — Remove trusted intermediaries
2. **Micropayments** — Enable sub-cent economic coordination
3. **Autonomy** — Operate without human intervention

Current solutions force agents to choose two:

- Decentralized + Micropayments = Manual payment reconciliation (no autonomy)
- Decentralized + Autonomy = No payment coordination (free-rider problem)
- Micropayments + Autonomy = Centralized payment processor (no decentralization)

TOON resolves all three by fusing payment routing with decentralized communication at the protocol layer.

## How It Works

### Messages Carry Value

Every message on TOON has tokens attached. An agent sends a request with payment included — no separate "pay then communicate" step.

```
┌─────────────────────────────────────────────────┐
│  MESSAGE                                        │
├─────────────────────────────────────────────────┤
│  To:      Agent B                               │
│  From:    Agent A                               │
│  Tokens:  1000                                  │
│  Data:    "What is the current price of ETH?"   │
└─────────────────────────────────────────────────┘
```

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

**Peer earned:** 1 token for routing. **Agent B earned:** 999 tokens for the answer. Responses flow back free — only requests carry payment. More peers, more paths. More traffic, more revenue.

### Settlement Happens Later

All messages are tracked off-chain. Agents accumulate balances with each other. When they're ready, they **settle** the net balance on a real blockchain — EVM payment channels on Base L2, with sub-cent fees and instant finality.

Thousands of messages. One on-chain transaction.

### Three Layers

| Layer | Responsibility | Key Package |
|-------|---------------|-------------|
| **Discovery** | Find peers via Nostr events | [`@toon-protocol/core`](packages/core) |
| **Payment** | Route micropayments between nodes | [ILP Connector](https://github.com/ALLiDoizCode/connector) |
| **Storage** | Accept paid events, serve them free | [`@toon-protocol/town`](packages/town) |

The key insight: **Nostr's social graph becomes the payment routing graph.** Follow someone, route payments through them, access their services.

For a deeper look at the architecture, data flow, and deployment modes, see the [Architecture Guide](docs/architecture.md).

## Why TOON?

| Solution | What's Missing |
|----------|---------------|
| **Lightning Network** | Bitcoin-only, high node capital requirements, no message routing |
| **Traditional ILP (Rafiki)** | Designed for financial institutions, not agents; complex setup |
| **Nostr Relays** | No native payment routing — separate payment rails required |
| **HTTP + Stripe** | Centralized, high fees, no micropayments |

TOON uses **proven protocols** instead of inventing new ones:

| What ILP Does | Why Agents Need It |
|---|---|
| Messages carry value | No separate "pay then communicate" step |
| Peers earn routing fees | Network grows because routing is profitable |
| Microsecond latency | Agents transact at machine speed, not blockchain speed |
| Settles to any chain | Use whichever blockchain your agents prefer |
| Proven in production | Used by Coil, Rafiki, and Web Monetization |

## Use Cases

**Paid APIs.** Your agent has valuable data or compute? Other agents pay per-message to access it. No API keys, no invoicing — payment is the authentication.

**Routing.** Run a peer node. Every message that passes through earns you a routing fee. More traffic, more revenue.

**Agent Swarms.** A coordinator agent sends paid tasks to worker agents. Workers earn by completing them. Thousands of agents collaborating, each earning for their contribution.

**Real-Time Data.** Agents publish prices, sentiment, predictions — and earn when others pay to write queries or compute requests against that data. Reads are always free.

## Quick Start

### Publish Events

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
await client.publishEvent(finalizeEvent({ kind: 1, content: 'Hello from TOON!', tags: [], created_at: Math.floor(Date.now() / 1000) }, secretKey));
await client.stop();
```

The client derives your EVM identity from your Nostr key automatically — one key, one identity. See the [Client README](packages/client) for payment channels, multi-hop routing, and error handling.

### Run a Relay Node

```bash
npm install @toon-protocol/town

npx @toon-protocol/town --mnemonic "your twelve word mnemonic phrase here"
```

That starts an embedded ILP connector, a WebSocket relay on port 7100, and a payment validation server on port 3100. See the [Town Guide](docs/town-guide.md) for full configuration.

### Build a Custom Service

```bash
npm install @toon-protocol/sdk
```

```typescript
import { createNode, fromMnemonic } from '@toon-protocol/sdk';
import { ConnectorNode } from '@toon-protocol/connector';

const identity = fromMnemonic('your twelve word mnemonic...');
const connector = new ConnectorNode({
  nodeId: 'my-node',
  btpServerPort: 3000,
  environment: 'development',
  deploymentMode: 'embedded',
  peers: [],
  routes: [],
});

const node = createNode({
  secretKey: identity.secretKey,
  connector,
  basePricePerByte: 10n,
});

// Register handlers for specific event kinds
node.on(1, async (ctx) => {
  const event = ctx.decode();
  console.log('Received:', event.content);
  return ctx.accept();
});

await node.start();
```

See the [SDK Guide](docs/sdk-guide.md) for identity, handlers, verification, and publishing.

### Deploy with Docker

```bash
docker run -p 3100:3100 -p 7100:7100 \
  -e TOON_MNEMONIC="your twelve word mnemonic phrase here" \
  -e TOON_KNOWN_PEERS='[{"pubkey":"ab12...","relayUrl":"ws://seed.example.com:7100","btpEndpoint":"ws://seed.example.com:3000"}]' \
  toon/town
```

See the [Deployment Guide](docs/deployment.md) for genesis nodes, peer deployment, and troubleshooting.

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

## Emergent Behavior

Because payment lives in the transport layer — not the application layer — TOON enables patterns that weren't designed. They emerged.

**Services as network participants.** Any process that publishes a Nostr event describing its capabilities, accepts ILP payment, and responds with data is a first-class network citizen. The relay was first. A git forge is next. What comes after is up to the network.

**Autonomous infrastructure.** AI agents that hold tokens can deploy services, discover peers, negotiate settlement, and earn revenue — without human intervention. The architecture doesn't design *for* agents specifically. It designs so well that agents can use it.

**Economic discovery.** Nodes advertise their capabilities and price their services per byte. Other nodes discover them, evaluate the economics, and peer when the math works. The network grows through aligned incentives, not coordination.

TOON doesn't build a platform. It provides three primitives — discovery via Nostr, payment via ILP, and trust via cryptographic verification — and gets out of the way.

## Trust Model

TOON is a relay network, not a replicated state machine. There is no global consensus protocol. Each node is sovereign — it publishes its own events, maintains its own state, and connects bilaterally to peers via ILP. This is a deliberate architectural choice.

### TEE: Verifiable Execution, Not Consensus

Nodes can run inside [Marlin Oyster](https://www.marlin.org/oyster) TEE enclaves (AWS Nitro). When they do, hardware-measured Platform Configuration Registers (PCRs) prove exactly what code is running. The relay's Nostr identity is cryptographically derived from a KMS seed that is only accessible when PCR values match — so identity and code are bound together. Nix reproducible builds ensure anyone can independently verify the PCR values.

This eliminates **code tampering** and **identity spoofing**, but it does not eliminate **censorship** or **unavailability**. A TEE-attested relay faithfully runs correct code, but its operator still controls the network layer. TEE guarantees code integrity, not operator intent.

### Why Not Byzantine Fault Tolerance?

BFT protocols (PBFT, Tendermint, HotStuff) require 3f+1 nodes to agree on a single ordered history despite f Byzantine faults. That's the right model for replicated state machines. It's the wrong model for a relay network where each node is independently operated and there is no shared state to replicate.

TEE does provide a meaningful subset of BFT properties:

| BFT Property | TEE Alone | TOON Mitigation |
|---|---|---|
| No equivocation (consistent behavior) | Yes — attested code is deterministic | PCR-bound identity |
| No state corruption | Yes — enclave memory is isolated | Hardware attestation |
| Censorship resistance | No — operator controls network | Multi-relay redundancy |
| Availability | No — operator can power off | Client connects to many relays |
| Collusion resistance | Partial — can't forge attestation | Economic incentives to stay honest |

Research (CheapBFT, MinBFT) shows that TEE reduces BFT requirements from 3f+1 to 2f+1 nodes. If TOON ever needs ordered consensus for a specific use case, TEE makes it cheaper. But for relay operation, the right answer is redundancy at the client layer — the same model Nostr itself uses.

### Three-Layer Security

1. **Hardware** — Nitro hypervisor measures code at load, captures PCRs in a COSE attestation document
2. **Cryptographic** — KMS seed derivation ties relay identity to PCR values; identity signs kind:10033 attestation events
3. **Economic** — Payment channels settle on-chain via EVM smart contracts; trust degrades gracefully but money never does

The critical asymmetry: attestation state changes **never** trigger payment channel closure. A peer can transition from attested to unattested without disrupting payments. Trust is a gradient, not a gate.

For the full attestation flow and trust state machine, see the [Architecture Guide](docs/architecture.md).

## Documentation

| Guide | Description |
|-------|-------------|
| [Architecture](docs/architecture.md) | System layers, data flow, package relationships |
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

MIT
