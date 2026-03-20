# TOON Examples

Self-contained examples for building ILP-gated Nostr services with TOON.

## Deployment Modes

Both `@toon-protocol/sdk` and `@toon-protocol/town` support two deployment modes:

### Embedded Mode

Pass a `ConnectorNode` directly to the SDK or Town. Packets are delivered via direct function calls — zero HTTP overhead.

```typescript
// SDK
const node = createNode({
  secretKey,
  connector: connectorNode,          // Direct reference
  ilpAddress: 'g.toon.my-node',
});

// Town
const town = await startTown({
  mnemonic: '...',
  connector: connectorNode,          // Direct reference
});
```

**When to use:** Development, testing, single-process deployments, low-latency requirements.

### Standalone Mode

Connect to an external connector via HTTP. The connector runs as a separate process (or container). The SDK starts an HTTP server to receive incoming packets.

```typescript
// SDK
const node = createNode({
  secretKey,
  connectorUrl: 'http://localhost:8081',  // Connector admin URL
  handlerPort: 3600,                       // SDK's HTTP server port
  ilpAddress: 'g.toon.my-node',
});

// Town
const town = await startTown({
  mnemonic: '...',
  connectorUrl: 'http://localhost:8080',  // Connector health URL
});
```

**When to use:** Production, Docker/container deployments, scaling connector and service independently.

## Connector Routing Fee

The connector charges a 0.1% routing fee (hardcoded in `@toon-protocol/connector@1.7.x`). This fee is only active when settlement is enabled (`SETTLEMENT_ENABLED=true`).

- **Without settlement:** Both sender and receiver use the same `basePricePerByte`. No fee is deducted.
- **With settlement:** The sender sets a ~10% higher `basePricePerByte` (e.g., 11 vs 10) so the forwarded amount still meets the receiver's minimum after the connector deducts its fee.

## Examples

### SDK Examples (`examples/sdk-example/`)

| # | Example | Mode | Infra Required |
|---|---------|------|----------------|
| 01 | Identity Generation | N/A | None |
| 02 | Create Two Nodes | Embedded | None |
| 03 | Publish Events | Embedded | None |
| 04 | Payment Channels | Embedded | Anvil |
| 05 | Standalone Server | Standalone | None |

```bash
cd examples/sdk-example && npm install
npm run identity          # 01
npm run create-node       # 02
npm run publish-event     # 03
npm run standalone-server # 05
# For 04: ./scripts/sdk-e2e-infra.sh up && npm run payment-channel
```

### Town Examples (`examples/town-example/`)

| # | Example | Mode | Infra Required |
|---|---------|------|----------------|
| 01 | Start a Town Node | Standalone | None |
| 02 | Full Lifecycle (Two Towns) | Standalone | None |
| 03 | Subscribe to Remote Relay | Standalone | None |
| 04 | Embedded Town | Embedded | None |

```bash
cd examples/town-example && npm install
npm run start-town     # 01
npm run full-lifecycle # 02
npm run subscribe      # 03
npm run embedded-town  # 04
```

### Client Examples (`examples/client-example/`)

| # | Example | Infra Required |
|---|---------|----------------|
| 01 | Publish Event | SDK E2E (Anvil + peers) |
| 02 | Payment Channel Lifecycle | SDK E2E (Anvil + peers) |

```bash
cd examples/client-example && npm install
# Start infrastructure first: ./scripts/sdk-e2e-infra.sh up
npm run publish-event     # 01
npm run payment-channel   # 02
```

See [examples/client-example/README.md](client-example/README.md) for details on self-describing claims and how the client differs from SDK/Town.
