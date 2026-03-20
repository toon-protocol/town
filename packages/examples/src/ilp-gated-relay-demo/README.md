# ILP-Gated Relay Demo

This demo shows the end-to-end flow of an agent using the ILP-gated Nostr relay.

## Overview

The ILP-gated relay requires payment (via the Interledger Protocol) to store Nostr events. This creates an economic spam barrier while maintaining the open nature of Nostr.

**How it works:**

1. An agent creates and signs a Nostr event
2. The event is TOON-encoded (Typed Object Oriented Notation) for transport
3. The agent sends an ILP payment with the encoded event as data
4. The Business Logic Server (BLS) verifies the payment amount
5. If sufficient, the event is stored and a fulfillment is returned
6. The agent can query the event via WebSocket using standard NIP-01 filters

## Prerequisites

- Node.js 20.x or later
- pnpm 8.x or later
- The `@toon-protocol/relay` package built

## Quick Start

From the repository root:

```bash
# Install dependencies
pnpm install

# Build all packages
pnpm build

# Run the demo
pnpm demo:ilp-gated-relay
```

## Step-by-Step Instructions

### 1. Install Dependencies

```bash
pnpm install
```

### 2. Build the Packages

```bash
pnpm build
```

### 3. Run the Demo

```bash
pnpm demo:ilp-gated-relay
```

### Expected Output

```
==================================================
ILP-Gated Nostr Relay Demo
==================================================

[Setup] Owner pubkey: a1b2c3d4e5f6...
[Setup] Starting relay servers...

[Relay] Initialized in-memory event store
[Relay] Pricing: 10 units/byte base rate
[Relay] Owner pubkey configured for self-write bypass
[Relay] BLS listening on http://localhost:3100
[NostrRelayServer] Listening on port 7100
[Relay] WebSocket relay listening on ws://localhost:7100

==================================================
DEMO 1: Basic Payment Flow
==================================================

[Agent] Generated keypair
[Agent] Pubkey: f1e2d3c4b5a6...
[Agent] Created event: abc123def456...
[Agent] Sending payment of 1234 units...
[Agent] PAID: Event accepted!
[Agent] Fulfillment: YWJjMTIzZGVm...
[Agent] Event verified in relay!

==================================================
DEMO 2: Self-Write Bypass
==================================================

[Demo] Testing owner event with zero payment...
[Demo] BYPASS: Owner event accepted with 0 payment
[Demo] Event ID: 789xyz456abc...
[Demo] Owner event verified in relay!

[Demo] Testing non-owner event with insufficient payment...
[Demo] Non-owner pubkey: 9f8e7d6c5b4a...
[Demo] Non-owner event rejected (insufficient): F06
[Demo] Required: 1230, Received: 1

[Demo] Testing non-owner event with sufficient payment...
[Demo] PAID: Non-owner event accepted with 1340 payment
[Demo] Event ID: def789ghi012...
[Demo] Non-owner event verified in relay!

==================================================
Demo Complete!
==================================================

[Relay] Shutting down...
[Relay] Shutdown complete
```

## Components

### Relay (`relay.ts`)

Starts the ILP-gated relay with two servers:

- **BLS (Business Logic Server)**: HTTP server on port 3100
  - Endpoint: `POST /handle-packet`
  - Verifies payment amount, validates event signature, stores event
  - Returns fulfillment on success or ILP error code on failure

- **WebSocket Relay**: NIP-01 compliant relay on port 7100
  - Accepts REQ/CLOSE messages
  - Returns EVENT/EOSE messages
  - Read-only (writes go through BLS)

### Agent (`agent.ts`)

Demonstrates the agent-side workflow:

1. Generate Nostr keypair
2. Create and sign a Nostr event
3. Calculate payment amount based on event size
4. Send payment via mock connector
5. Verify event storage via WebSocket query

### Mock Connector (`mock-connector.ts`)

Simulates an ILP connector for local testing:

- Takes a Nostr event and payment amount
- TOON-encodes the event
- POSTs to BLS `/handle-packet` endpoint
- Returns accept/reject response

In production, the ILP connector would handle STREAM packet routing, but the mock allows testing without a real ILP network.

### Demo Entry Point (`index.ts`)

Runs the complete demo:

1. Starts relay with owner pubkey configured
2. Runs basic payment flow demo
3. Runs self-write bypass demo
4. Shuts down cleanly

## Configuration

### Modifying Pricing

In `relay.ts`, you can configure pricing:

```typescript
const servers = await startRelay({
  // Base price: 10 units per byte
  basePricePerByte: 10n,

  // Kind-specific overrides
  kindOverrides: new Map([
    [0, 50n], // Profile metadata: 50 units/byte
    [1, 10n], // Text notes: 10 units/byte (default)
    [3, 5n], // Follows: 5 units/byte (cheaper)
  ]),
});
```

### Modifying Ports

```typescript
const servers = await startRelay({
  blsPort: 3001, // Custom BLS port
  wsPort: 7001, // Custom WebSocket port
});
```

### Using Persistent Storage

```typescript
const servers = await startRelay({
  inMemory: false,
  dbPath: './my-relay.db', // SQLite file path
});
```

## Self-Write Bypass

The relay supports an "owner pubkey" that bypasses payment:

```typescript
const servers = await startRelay({
  ownerPubkey: 'a1b2c3d4...64-char-hex...',
});
```

Events from the owner pubkey:

- Are accepted with `amount=0`
- Still require valid signatures
- Are stored just like paid events

This allows relay operators to write their own events without paying.

## Troubleshooting

### "Connection refused" errors

Make sure the relay is running before starting the agent:

```bash
# In one terminal
pnpm tsx packages/examples/src/ilp-gated-relay-demo/relay.ts

# In another terminal
pnpm tsx packages/examples/src/ilp-gated-relay-demo/agent.ts
```

Or use the combined demo which handles this automatically:

```bash
pnpm demo:ilp-gated-relay
```

### "Insufficient payment" errors

The payment amount must cover `event_size_in_bytes * price_per_byte`. The demo calculates this automatically, but if you're testing manually, ensure your payment is large enough.

### Port already in use

If ports 3100 or 7100 are in use:

1. Stop any running instances
2. Or configure different ports in the demo

### Event not found after payment

- Check that the payment was actually accepted (look for fulfillment)
- Ensure you're querying the correct event ID
- Add a small delay between storage and query (events are stored synchronously but WebSocket might need time)

## Default Ports

| Service                     | Port | Protocol  |
| --------------------------- | ---- | --------- |
| BLS (Business Logic Server) | 3100 | HTTP      |
| WebSocket Relay             | 7100 | WebSocket |

## API Reference

### BLS Request Format

```typescript
POST /handle-packet
Content-Type: application/json

{
  "amount": "1000",           // Payment amount as string
  "destination": "g.demo",    // ILP destination
  "data": "base64-toon-data"  // TOON-encoded Nostr event
}
```

### BLS Response (Accept)

```typescript
{
  "accept": true,
  "fulfillment": "base64-sha256-of-event-id",
  "metadata": {
    "eventId": "abc123...",
    "storedAt": 1699999999999
  }
}
```

### BLS Response (Reject)

```typescript
{
  "accept": false,
  "code": "F06",              // ILP error code
  "message": "Insufficient payment amount",
  "metadata": {
    "required": "1000",
    "received": "500"
  }
}
```

### ILP Error Codes

| Code | Meaning                    |
| ---- | -------------------------- |
| F00  | Bad request (invalid data) |
| F06  | Insufficient amount        |
| T00  | Internal server error      |
