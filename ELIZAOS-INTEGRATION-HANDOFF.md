# ElizaOS Integration Handoff: crosstown

## Goal

Publish `@crosstown/core`, `@crosstown/bls`, and `@crosstown/relay` as npm packages, then create a new `@crosstown/elizaos-plugin` package that wraps everything — including the refactored `@agent-runtime/connector` — as ElizaOS Services, Actions, and Providers.

---

## Current State

The three packages **build successfully** and have clean public APIs. They're ~95% ready to publish. The remaining work falls into three categories:

1. **Publish blockers** — metadata, workspace references
2. **Integration refactoring** — replace HTTP client with direct connector imports
3. **New package** — the ElizaOS plugin

---

## Part 1: Publish as npm Packages

### 1.1 Package Readiness

| Package               | Builds | Types (.d.ts) | `files` field | README       | Blockers                             |
| --------------------- | ------ | ------------- | ------------- | ------------ | ------------------------------------ |
| `@crosstown/core`     | Yes    | Yes (49 KB)   | `["dist"]`    | Missing      | Missing metadata fields              |
| `@crosstown/bls`      | Yes    | Yes (12 KB)   | `["dist"]`    | Yes (6.5 KB) | Missing metadata fields              |
| `@crosstown/relay`    | Yes    | Yes (13 KB)   | `["dist"]`    | Missing      | Missing metadata, `workspace:*` deps |
| `@crosstown/examples` | N/A    | N/A           | N/A           | N/A          | `private: true` — do not publish     |

### 1.2 Metadata to Add (All Packages)

Each package.json needs:

```jsonc
{
  "repository": {
    "type": "git",
    "url": "https://github.com/ALLiDoizCode/crosstown.git",
    "directory": "packages/<package-name>",
  },
  "author": "...",
  "publishConfig": {
    "access": "public",
  },
  "license": "MIT", // already present
}
```

### 1.3 Fix workspace:\* References

`@crosstown/relay` depends on core and bls using `workspace:*`. Before publishing, these must become real version ranges:

```jsonc
// packages/relay/package.json — BEFORE
{
  "dependencies": {
    "@crosstown/bls": "workspace:*",
    "@crosstown/core": "workspace:*"
  }
}

// packages/relay/package.json — AFTER
{
  "dependencies": {
    "@crosstown/bls": "^1.0.0",
    "@crosstown/core": "^1.0.0"
  }
}
```

### 1.4 Publish Order

Dependencies flow: `bls` (no internal deps) → `core` (no internal runtime deps) → `relay` (depends on both).

```bash
# 1. Publish bls first (zero internal dependencies)
cd packages/bls
npm run build && npm publish --access public

# 2. Publish core (zero internal runtime dependencies)
cd ../core
npm run build && npm publish --access public

# 3. Update relay's workspace refs to published versions
# Change workspace:* → ^1.0.0 in relay/package.json

# 4. Publish relay
cd ../relay
npm run build && npm publish --access public
```

### 1.5 Add READMEs

`core` and `relay` need README.md files. Keep them minimal — package description, install command, basic usage example.

### 1.6 Version Bump

All packages are at `0.1.0`. Bump to `1.0.0` for the publish since this marks the first public release with a stable API.

---

## Part 2: Integration Refactoring

Once `@agent-runtime/connector` is published as an npm package (see `ELIZAOS-INTEGRATION-HANDOFF.md` in the agent-runtime repo), crosstown needs to consume it directly instead of via HTTP.

### 2.1 Replace HTTP Client with Direct Import

**Current** (`packages/core/src/bootstrap/agent-runtime-client.ts`):

```typescript
// Creates an HTTP client that calls POST /ilp/send
export function createAgentRuntimeClient(baseUrl: string): AgentRuntimeClient {
  return {
    async sendIlpPacket(params) {
      const response = await fetch(`${normalizedUrl}/ilp/send`, { ... });
      // ...
    }
  };
}
```

**Target**: The `AgentRuntimeClient` interface stays the same, but gains a second factory that wraps a `ConnectorNode` directly:

```typescript
import { ConnectorNode } from '@agent-runtime/connector';

// New — direct in-process client (no HTTP)
export function createDirectRuntimeClient(
  connector: ConnectorNode
): AgentRuntimeClient {
  return {
    async sendIlpPacket(params) {
      const result = await connector.sendPacket({
        destination: params.destination,
        amount: BigInt(params.amount),
        data: Buffer.from(params.data, 'base64'),
        // ...
      });
      return {
        accepted: result.type === 'fulfill',
        fulfillment: result.fulfillment?.toString('base64'),
        // ...
      };
    },
  };
}

// Keep the HTTP client as a fallback
export function createHttpRuntimeClient(baseUrl: string): AgentRuntimeClient {
  // ... existing implementation
}
```

### 2.2 Make BLS handlePacket Callable Directly

The `BusinessLogicServer.handlePacket()` is currently a **private** method wrapped by an HTTP route. It needs to be public so the connector can call it directly:

```typescript
// packages/bls/src/bls/BusinessLogicServer.ts
export class BusinessLogicServer {
  // Change from private to public
  public handlePacket(
    request: HandlePacketRequest
  ): HandlePacketAcceptResponse | HandlePacketRejectResponse {
    // ... existing logic unchanged
  }
}
```

This is the method that the connector's `setLocalDeliveryHandler()` will call instead of HTTP POST `/handle-packet`.

### 2.3 Wire Connector ↔ BLS in Core

Add a composition function in core that wires everything together:

```typescript
// packages/core/src/compose.ts (new file)
import { ConnectorNode } from '@agent-runtime/connector';
import { BusinessLogicServer } from '@crosstown/bls';

export interface CrosstownNode {
  connector: ConnectorNode;
  bls: BusinessLogicServer;
  bootstrap: BootstrapService;
  trustManager: SocialTrustManager;
  spspClient: NostrSpspClient;
  spspServer: NostrSpspServer;
  relayServer?: NostrRelayServer;

  start(): Promise<void>;
  stop(): Promise<void>;
}

export function createCrosstownNode(config: CrosstownConfig): CrosstownNode {
  // 1. Create connector
  const connector = new ConnectorNode({
    nodeId: config.nodeId,
    btpServerPort: config.btpPort,
  });

  // 2. Create BLS
  const bls = new BusinessLogicServer(blsConfig, eventStore);

  // 3. Wire BLS ← connector (incoming packets)
  connector.setLocalDeliveryHandler(async (packet, sourcePeer) => {
    return bls.handlePacket({
      amount: packet.amount.toString(),
      destination: packet.destination,
      data: Buffer.from(packet.data).toString('base64'),
    });
  });

  // 4. Create bootstrap with direct connector access (outgoing packets)
  const runtimeClient = createDirectRuntimeClient(connector);
  const bootstrap = new BootstrapService({ ...config, runtimeClient });

  // 5. Trust, SPSP, relay
  const trustManager = new SocialTrustManager(config.relays);
  const spspClient = new NostrSpspClient(config.relays, config.secretKey);
  const spspServer = new NostrSpspServer(config.relays, config.secretKey, {
    ilpAddress: config.ilpAddress,
  });

  return {
    connector,
    bls,
    bootstrap,
    trustManager,
    spspClient,
    spspServer,
    async start() {
      await connector.start();
      await bootstrap.bootstrap();
    },
    async stop() {
      await connector.stop();
      spspServer.stop();
    },
  };
}
```

### 2.4 Add @agent-runtime/connector as a Dependency

```jsonc
// packages/core/package.json
{
  "dependencies": {
    "@agent-runtime/connector": "^1.0.0",
    "@agent-runtime/shared": "^1.0.0",
    // ... existing deps
  },
}
```

### 2.5 Update Exports

```typescript
// packages/core/src/index.ts — add new exports
export {
  createCrosstownNode,
  type CrosstownNode,
  type CrosstownConfig,
} from './compose.js';
export {
  createDirectRuntimeClient,
  createHttpRuntimeClient,
} from './bootstrap/agent-runtime-client.js';

// Re-export connector types for convenience
export type { ConnectorNode, ConnectorConfig } from '@agent-runtime/connector';
```

---

## Part 3: Create ElizaOS Plugin

New package: `@crosstown/elizaos-plugin`

### 3.1 Package Structure

```
packages/elizaos-plugin/
├── package.json
├── tsconfig.json
├── tsup.config.ts
├── README.md
├── src/
│   ├── index.ts                    ← plugin entry point
│   ├── services/
│   │   └── CrosstownService.ts  ← wraps createCrosstownNode()
│   ├── actions/
│   │   ├── pay.ts                  ← "Pay Alice 5 USD"
│   │   ├── discoverPeers.ts        ← "Find new payment peers"
│   │   ├── checkTrust.ts           ← "How much do I trust Bob?"
│   │   ├── publishPeerInfo.ts      ← "Update my ILP peer info"
│   │   ├── requestPayment.ts       ← "Request 10 USD from Carol"
│   │   └── bootstrapNetwork.ts     ← "Bootstrap my ILP network"
│   ├── providers/
│   │   ├── trustScore.ts           ← trust scores for mentioned peers
│   │   ├── peerStatus.ts           ← connected peer status
│   │   ├── ilpBalance.ts           ← connector balances
│   │   ├── networkStatus.ts        ← bootstrap phase, relay health
│   │   └── paymentHistory.ts       ← recent payments
│   ├── evaluators/
│   │   ├── paymentOutcome.ts       ← assess payment success/failure
│   │   └── trustEvolution.ts       ← track trust changes
│   └── events.ts                   ← custom ElizaOS event types
```

### 3.2 Package.json

```jsonc
{
  "name": "@crosstown/elizaos-plugin",
  "version": "1.0.0",
  "description": "ElizaOS plugin for Crosstown — ILP payments via Nostr social graph",
  "main": "dist/index.js",
  "types": "dist/index.d.ts",
  "exports": {
    ".": {
      "import": "./dist/index.js",
      "types": "./dist/index.d.ts",
    },
  },
  "files": ["dist", "README.md", "LICENSE"],
  "publishConfig": {
    "access": "public",
  },
  "dependencies": {
    "@crosstown/core": "^1.0.0",
    "@crosstown/bls": "^1.0.0",
  },
  "peerDependencies": {
    "@elizaos/core": "^1.0.0",
  },
  "license": "MIT",
}
```

### 3.3 Plugin Entry Point

```typescript
// src/index.ts
import type { Plugin } from '@elizaos/core';
import { CrosstownService } from './services/CrosstownService.js';
import { payAction } from './actions/pay.js';
import { discoverPeersAction } from './actions/discoverPeers.js';
import { checkTrustAction } from './actions/checkTrust.js';
import { bootstrapNetworkAction } from './actions/bootstrapNetwork.js';
import { publishPeerInfoAction } from './actions/publishPeerInfo.js';
import { requestPaymentAction } from './actions/requestPayment.js';
import { trustScoreProvider } from './providers/trustScore.js';
import { peerStatusProvider } from './providers/peerStatus.js';
import { ilpBalanceProvider } from './providers/ilpBalance.js';
import { networkStatusProvider } from './providers/networkStatus.js';
import { paymentHistoryProvider } from './providers/paymentHistory.js';
import { paymentOutcomeEvaluator } from './evaluators/paymentOutcome.js';
import { trustEvolutionEvaluator } from './evaluators/trustEvolution.js';

export const crosstownPlugin: Plugin = {
  name: '@crosstown/elizaos-plugin',
  description: 'ILP payments via Nostr social graph',

  services: [CrosstownService],

  actions: [
    payAction,
    discoverPeersAction,
    checkTrustAction,
    bootstrapNetworkAction,
    publishPeerInfoAction,
    requestPaymentAction,
  ],

  providers: [
    trustScoreProvider,
    peerStatusProvider,
    ilpBalanceProvider,
    networkStatusProvider,
    paymentHistoryProvider,
  ],

  evaluators: [paymentOutcomeEvaluator, trustEvolutionEvaluator],

  routes: [
    { type: 'GET', path: '/status', handler: getNetworkStatus },
    { type: 'GET', path: '/peers', handler: getPeerList },
    { type: 'GET', path: '/trust/:pubkey', handler: getTrustScore },
    { type: 'GET', path: '/payments', handler: getPaymentHistory },
  ],
};

export default crosstownPlugin;
```

### 3.4 Service Implementation

```typescript
// src/services/CrosstownService.ts
import { Service, type IAgentRuntime } from '@elizaos/core';
import { createCrosstownNode, type CrosstownNode } from '@crosstown/core';

export class CrosstownService extends Service {
  static serviceType = 'crosstown' as const;
  capabilityDescription =
    'Manages ILP connector, Nostr identity, peer discovery, and trust';

  private node!: CrosstownNode;

  static async start(runtime: IAgentRuntime): Promise<CrosstownService> {
    const service = new CrosstownService(runtime);

    const nostrKey = runtime.getSetting('CROSSTOWN_NOSTR_PRIVATE_KEY');
    if (!nostrKey)
      throw new Error(
        'CROSSTOWN_NOSTR_PRIVATE_KEY required in character secrets'
      );

    service.node = createCrosstownNode({
      nodeId: runtime.character.name,
      btpPort: Number(runtime.getSetting('BTP_PORT') || 7768),
      relayPort: Number(runtime.getSetting('RELAY_PORT') || 7100),
      ilpAddress: runtime.getSetting('CROSSTOWN_ILP_ADDRESS') as string,
      secretKey: nostrKey as string,
      relays:
        (runtime.getSetting('CROSSTOWN_RELAYS') as string)?.split(',') || [],
      autoBootstrap: runtime.getSetting('CROSSTOWN_AUTO_BOOTSTRAP') !== 'false',
    });

    await service.node.start();
    return service;
  }

  async stop(): Promise<void> {
    await this.node.stop();
  }

  // Accessors for Actions and Providers
  getNode(): CrosstownNode {
    return this.node;
  }
  getConnector() {
    return this.node.connector;
  }
  getTrustManager() {
    return this.node.trustManager;
  }
  getSpspClient() {
    return this.node.spspClient;
  }
  getBootstrapPhase() {
    return this.node.bootstrap.getPhase?.() || 'unknown';
  }
}
```

---

## Part 4: ElizaOS Character Configuration

With the plugin published, an agent operator's entire config is one character file:

```jsonc
{
  "name": "PaymentAgent",
  "plugins": ["@crosstown/elizaos-plugin"],
  "settings": {
    "CROSSTOWN_ILP_ADDRESS": "g.agent.payment-agent",
    "BTP_PORT": "7768",
    "RELAY_PORT": "7100",
    "CROSSTOWN_RELAYS": "wss://relay.damus.io,wss://relay.nostr.band",
    "CROSSTOWN_AUTO_BOOTSTRAP": "true",
    "CROSSTOWN_TRUST_THRESHOLD": "0.5",
    "CROSSTOWN_MAX_PAYMENT": "100",
  },
  "secrets": {
    "CROSSTOWN_NOSTR_PRIVATE_KEY": "<hex-encoded-nostr-private-key>",
  },
}
```

No YAML config. No Docker compose. No multiple processes. One file, one process.

---

## Summary: All Work Items

### crosstown — Publish Existing Packages

| #   | Task                                                    | Package          | Effort |
| --- | ------------------------------------------------------- | ---------------- | ------ |
| 1   | Add repository, author, publishConfig to package.json   | core, bls, relay | S      |
| 2   | Add README.md                                           | core, relay      | S      |
| 3   | Replace `workspace:*` with real versions before publish | relay            | S      |
| 4   | Version bump to 1.0.0                                   | core, bls, relay | S      |
| 5   | `npm pack` each package and verify contents             | core, bls, relay | S      |
| 6   | Publish to npm in order: bls → core → relay             | core, bls, relay | S      |

### crosstown — Integration Refactoring

| #   | Task                                                                  | Package | Effort |
| --- | --------------------------------------------------------------------- | ------- | ------ |
| 7   | Add `@agent-runtime/connector` as dependency                          | core    | S      |
| 8   | Create `createDirectRuntimeClient()` (in-process alternative to HTTP) | core    | M      |
| 9   | Make `BusinessLogicServer.handlePacket()` public                      | bls     | S      |
| 10  | Create `createCrosstownNode()` composition function                   | core    | M      |
| 11  | Update core exports                                                   | core    | S      |

### crosstown — New ElizaOS Plugin

| #   | Task                                                             | Package        | Effort |
| --- | ---------------------------------------------------------------- | -------------- | ------ |
| 12  | Create package scaffolding                                       | elizaos-plugin | S      |
| 13  | Implement CrosstownService                                       | elizaos-plugin | M      |
| 14  | Implement PAY action                                             | elizaos-plugin | L      |
| 15  | Implement DISCOVER_PEERS, CHECK_TRUST, BOOTSTRAP_NETWORK actions | elizaos-plugin | M      |
| 16  | Implement trustScore, peerStatus, ilpBalance providers           | elizaos-plugin | M      |
| 17  | Implement networkStatus, paymentHistory providers                | elizaos-plugin | M      |
| 18  | Implement paymentOutcome, trustEvolution evaluators              | elizaos-plugin | M      |
| 19  | Add REST routes                                                  | elizaos-plugin | S      |
| 20  | Publish to npm                                                   | elizaos-plugin | S      |

### Dependencies (Order of Work)

```
agent-runtime refactoring (separate handoff)
        │
        ▼
Publish @agent-runtime/shared + @agent-runtime/connector to npm
        │
        ▼
Tasks 1-6: Publish @crosstown/bls, core, relay to npm
        │
        ▼
Tasks 7-11: Integration refactoring (core imports connector directly)
        │
        ▼
Tasks 12-20: Build and publish @crosstown/elizaos-plugin
```

---

## Reference: Existing Public APIs

### @crosstown/core exports

```
BootstrapService, createAgentRuntimeClient, RelayMonitor
NostrPeerDiscovery, SocialPeerDiscovery, GenesisPeerLoader, ArDrivePeerRegistry
NostrSpspClient, NostrSpspServer, IlpSpspClient
SocialTrustManager, calculateCreditLimit
buildIlpPeerInfoEvent, parseIlpPeerInfo, buildSpspRequestEvent, parseSpspResponse
ILP_PEER_INFO_KIND, SPSP_REQUEST_KIND, SPSP_RESPONSE_KIND
CrosstownError, PeerDiscoveryError, SpspError, TrustError, BootstrapError
+ all types (IlpPeerInfo, SpspInfo, TrustScore, TrustConfig, etc.)
```

### @crosstown/bls exports

```
createBlsServer, BusinessLogicServer
InMemoryEventStore, SqliteEventStore, createEventStore
PricingService, loadPricingConfigFromEnv
encodeEventToToon, decodeEventFromToon
BlsBaseError, BlsError, ToonEncodeError
+ all types (BlsConfig, HandlePacketRequest/Response, EventStore, etc.)
```

### @crosstown/relay exports

```
NostrRelayServer, ConnectionHandler
createBlsServer (re-export from bls)
+ types
```

---

## Reference: Companion Handoff

The agent-runtime side of this work is documented in:
`/agent-runtime/ELIZAOS-INTEGRATION-HANDOFF.md`

That handoff covers refactoring `@agent-runtime/connector` into an importable library and publishing it to npm. This handoff assumes that work is done first.
