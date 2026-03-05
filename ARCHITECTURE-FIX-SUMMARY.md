# Architecture Fix Summary

## What Was Wrong

### ❌ Direct BLS Client (Hack)

I created a client that sent HTTP requests directly to peer's BLS endpoint, **bypassing the entire ILP/connector architecture**:

```
Peer2 → HTTP → Peer1's BLS (WRONG!)
```

This broke:

- ILP packet routing
- Connector settlement tracking
- The fundamental purpose of having connectors

## What's Correct Now

### ✅ SPSP via ILP (Always)

SPSP packets flow through proper ILP routing:

```
Peer2 BLS → Connector2 → BTP → Connector1 → Peer1 BLS (CORRECT!)
```

### ✅ BTP Auth with Empty String

The chicken-and-egg problem is solved by:

- **BTP doesn't require authentication**
- Use empty string `''` for `authToken`
- Peers can connect immediately without secret exchange

## Bootstrap Flow (Correct Architecture)

```
1. Discovery (Nostr)
   ├─ Peer1 publishes kind:10032 to local relay
   └─ Peer2 queries relay and discovers Peer1

2. Peer Registration (Admin API)
   ├─ Peer2 calls Connector2 Admin API
   ├─ Registers Peer1: { id, url, authToken: '', routes }
   └─ Connector2 initiates BTP connection to Connector1

3. BTP Connection (WebSocket)
   ├─ Connector2 connects to Connector1 BTP endpoint
   ├─ Auth with empty string (no secret needed!)
   └─ BTP connection established

4. SPSP Handshake (via ILP!)
   ├─ Peer2 sends kind:23194 SPSP request as ILP packet
   ├─ Packet routes: BLS2 → Connector2 → BTP → Connector1 → BLS1
   ├─ Peer1 BLS responds with kind:23195 SPSP response
   └─ Settlement info exchanged (chains, addresses, channels)

5. Payment Channels (Settlement Layer)
   ├─ Based on SPSP negotiation, connectors open payment channels
   ├─ On-chain: TokenNetwork contracts, deposits, signatures
   └─ Channels ready for settlement

6. Announce (via ILP!)
   ├─ Peer2 sends kind:10032 announce as PAID ILP packet
   ├─ Peer1 receives and stores in local relay
   └─ Network mesh forms
```

## Key Principles

### 1. SPSP is ALWAYS ILP

SPSP is not a separate protocol - it's **Nostr events sent as ILP packet data**.

```typescript
// SPSP request is a Nostr event (kind:23194)
const spspRequestEvent = buildSpspRequestEvent(/*...*/);

// TOON-encode it
const toonBytes = encodeEventToToon(spspRequestEvent);
const data = Buffer.from(toonBytes).toString('base64');

// Send via ILP (NOT direct HTTP!)
await runtimeClient.sendIlpPacket({
  destination: 'g.crosstown.peer1',
  amount: '0', // Free bootstrap handshake
  data, // TOON-encoded Nostr event
});
```

### 2. BTP Doesn't Need Auth

For Crosstown's use case:

- Peers discover each other via Nostr (public info)
- No need for pre-shared secrets
- BTP auth can be empty string

```typescript
await connectorAdmin.addPeer({
  id: 'nostr-719705df...',
  url: 'btp+ws://connector-peer1:3001',
  authToken: '', // No auth needed!
  routes: [{ prefix: 'g.crosstown.peer1' }],
});
```

### 3. Connector is Always in the Middle

The connector handles:

- **Routing**: Find path to destination ILP address
- **BTP**: WebSocket connection to peer connectors
- **Settlement**: Track balances, trigger on-chain settlement
- **Local Delivery**: Route to local BLS for own ILP address

```
Outbound: BLS → Connector → BTP → Peer Connector → Peer BLS
Inbound:  Peer BLS → Peer Connector → BTP → Connector → BLS
```

## Local Development Benefits

### Before (Docker)

```
Code change → Build → Docker build image → Restart container → Test
Time: 5-10 minutes
```

### After (Local Node)

```
Code change → Build → Restart process → Test
Time: 5 seconds
```

### Why Local is Better

1. **Instant restarts** - `Ctrl+C` and re-run (1-2s)
2. **Direct console logs** - No `docker logs` needed
3. **Fast builds** - No Docker layer caching
4. **Easy debugging** - Attach debugger directly
5. **Low resource** - 4 Node processes vs 4 Docker containers

## Next Steps

1. **Test BTP Connection** - Verify empty auth works
2. **Test SPSP via ILP** - Packets route through connectors
3. **Test Payment Channels** - Verify on-chain channel opening
4. **Add Peer3, Peer4** - Test mesh topology

## Files Changed

### Fixed

- `packages/core/src/bootstrap/BootstrapService.ts`
  - ✅ Removed direct BLS client hack
  - ✅ BTP auth uses empty string
  - ✅ SPSP flows through ILP

### Deprecated (Can Delete)

- `packages/core/src/bootstrap/direct-bls-client.ts`
- `packages/core/src/types.ts` - Remove `blsHttpEndpoint?` field
- `packages/bls/src/entrypoint-with-bootstrap.ts` - Remove blsHttpEndpoint construction
- `packages/core/src/events/parsers.ts` - Remove blsHttpEndpoint parsing

### New

- `LOCAL-DEV-SETUP.md` - Local development guide
- `dev-peer1.sh` - Start genesis peer locally
- `dev-peer2.sh` - Start joiner peer locally
- `ARCHITECTURE-FIX-SUMMARY.md` - This file

## Clean Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    NOSTR LAYER (Discovery)                   │
│  ┌─────────────┐                          ┌─────────────┐  │
│  │   Peer1     │──────kind:10032────────▶ │   Relay     │  │
│  │   Genesis   │                          │   (Nostr)   │  │
│  └─────────────┘                          └─────────────┘  │
│                                                  │           │
│                                            Query │           │
│                                                  ▼           │
│  ┌─────────────┐                          ┌─────────────┐  │
│  │   Peer2     │◀────────────────────────│   Joiner    │  │
│  │   Joiner    │      Discover Peer1      │             │  │
│  └─────────────┘                          └─────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ Register peer
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      ILP LAYER (Routing)                     │
│                                                              │
│  ┌─────────────┐         BTP          ┌─────────────┐      │
│  │ Connector1  │◀══════════════════▶  │ Connector2  │      │
│  │ (Peer1)     │    WebSocket Auth:''  │ (Peer2)     │      │
│  └─────────────┘                       └─────────────┘      │
│        │                                       │             │
│        │ Local Delivery                       │ Local Delivery
│        ▼                                       ▼             │
│  ┌─────────────┐                       ┌─────────────┐      │
│  │   BLS1      │                       │   BLS2      │      │
│  │ (Peer1)     │                       │ (Peer2)     │      │
│  └─────────────┘                       └─────────────┘      │
│        │                                       │             │
│        │ SPSP Request (kind:23194)            │             │
│        │◀──────────ILP PREPARE────────────────│             │
│        │                                       │             │
│        │ SPSP Response (kind:23195)           │             │
│        │───────────ILP FULFILL────────────────▶             │
│                                                              │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ Settlement
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  SETTLEMENT LAYER (Blockchain)               │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │           Ethereum (Anvil - Local)                   │   │
│  │  - TokenNetwork Contract                             │   │
│  │  - Payment Channels                                  │   │
│  │  - Signed Claims                                     │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

**All layers work together - no bypassing allowed!** ✅
