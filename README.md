# Crosstown

**Human networks are built on time. Agent networks are built on tokens.**

Every message between humans costs attention — the minutes you spend reading, writing, responding. Every message between machines should cost money. Crosstown couples tokens directly to the transport layer, making payment a protocol primitive rather than an afterthought.

The result: any service that can describe itself in a Nostr event and accept payment via ILP becomes a participant in a self-organizing economic network. The relay is just the first service. The protocol is the product.

## What is Crosstown?

Crosstown is an open protocol where writing costs tokens and reading is free. It combines three technologies:

- **[Nostr](https://nostr.com/)** for discovery and pub/sub — nodes find each other by publishing events to relays
- **[ILP](https://interledger.org/)** (Interledger Protocol) for payment routing — tokens flow through the same network as data
- **[TOON](https://toonformat.dev)** for encoding — a compact, human-readable format optimized for machines and LLMs

When you publish an event, you pay per byte. When you read, it's free. This single asymmetry creates a sustainable network with built-in spam resistance, operator revenue, and economic routing — without ads, subscriptions, or gatekeepers.

## How It Works

Three layers, each doing one thing:

| Layer | Responsibility | Key Package |
|-------|---------------|-------------|
| **Discovery** | Find peers via Nostr events | [`@crosstown/core`](packages/core) |
| **Payment** | Route micropayments between nodes | ILP Connector |
| **Storage** | Accept paid events, serve them free | [`@crosstown/town`](packages/town) |

The key insight: **Nostr's social graph becomes the payment routing graph.** Follow someone, route payments through them, access their services.

```
Writer → TOON-encode event → ILP payment → Relay validates → Stores event
Reader → WebSocket subscribe → Relay serves events → Free
```

For a deeper look at the architecture, data flow, and deployment modes, see the [Architecture Guide](docs/architecture.md).

## Quick Start

### Run a Relay Node

```bash
npm install @crosstown/town

npx @crosstown/town --mnemonic "your twelve word mnemonic phrase here"
```

That starts an embedded ILP connector, a WebSocket relay on port 7100, and a payment validation server on port 3100. See the [Town Guide](docs/town-guide.md) for full configuration.

### Build a Custom Service

```bash
npm install @crosstown/sdk
```

```typescript
import { createNode, fromMnemonic } from '@crosstown/sdk';
import { ConnectorNode } from '@crosstown/connector';

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
  -e CROSSTOWN_MNEMONIC="your twelve word mnemonic phrase here" \
  -e CROSSTOWN_KNOWN_PEERS='[{"pubkey":"ab12...","relayUrl":"ws://seed.example.com:7100","btpEndpoint":"ws://seed.example.com:3000"}]' \
  crosstown/town
```

See the [Deployment Guide](docs/deployment.md) for genesis nodes, peer deployment, and troubleshooting.

## Packages

| Package | Description | |
|---------|-------------|---|
| [`@crosstown/sdk`](packages/sdk) | Building blocks for Crosstown services | [![npm](https://img.shields.io/npm/v/@crosstown/sdk)](https://www.npmjs.com/package/@crosstown/sdk) |
| [`@crosstown/town`](packages/town) | Reference relay — one command to run | [![npm](https://img.shields.io/npm/v/@crosstown/town)](https://www.npmjs.com/package/@crosstown/town) |
| [`@crosstown/core`](packages/core) | Discovery, peering, and bootstrap | Internal |
| [`@crosstown/relay`](packages/relay) | WebSocket relay server and event store | Internal |
| [`@crosstown/bls`](packages/bls) | Business logic server for ILP validation | Internal |
| [`@crosstown/faucet`](packages/faucet) | Token faucet for local development | Internal |

## Emergent Behavior

Because payment lives in the transport layer — not the application layer — Crosstown enables patterns that weren't designed. They emerged.

**Services as network participants.** Any process that publishes a Nostr event describing its capabilities, accepts ILP payment, and responds with data is a first-class network citizen. The relay was first. A git forge is next. What comes after is up to the network.

**Autonomous infrastructure.** AI agents that hold tokens can deploy services, discover peers, negotiate settlement, and earn revenue — without human intervention. The architecture doesn't design *for* agents specifically. It designs so well that agents can use it.

**Economic discovery.** Nodes advertise their capabilities as Nostr events and price their services per byte. Other nodes — human-operated or autonomous — discover them, evaluate the economics, and peer when the math works. The network grows through aligned incentives, not coordination.

Crosstown doesn't build a platform. It provides three primitives — discovery via Nostr, payment via ILP, and trust via cryptographic verification — and gets out of the way.

## Documentation

| Guide | Description |
|-------|-------------|
| [Architecture](docs/architecture.md) | System layers, data flow, package relationships |
| [Protocol](docs/protocol.md) | Event kinds, TOON format, ILP mechanics |
| [Deployment](docs/deployment.md) | Docker, local stack, deploy scripts |
| [Settlement](docs/settlement.md) | Chain negotiation, payment channels |
| [Bootstrap](docs/bootstrap.md) | Network discovery and peering |
| [SDK Guide](docs/sdk-guide.md) | Building services with `@crosstown/sdk` |
| [Town Guide](docs/town-guide.md) | Running relays with `@crosstown/town` |

## Related

- [Nostr Protocol](https://github.com/nostr-protocol/nips) — NIPs 01, 34, 44
- [Interledger](https://interledger.org/developers/rfcs/) — RFCs 0027, 0032, 0035
- [TOON Format](https://toonformat.dev) — Compact, human-readable JSON encoding

## License

MIT
