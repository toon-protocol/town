# Client Examples

Standalone `@toon-protocol/client` examples that connect to external TOON peer containers.

## Key Difference from SDK/Town

- **SDK/Town**: The connector creates and attaches signed claims to every packet automatically.
- **Client**: YOU create self-describing claims via `signBalanceProof()` and attach them to each `publishEvent()` call.

The client does not run its own connector. It connects to external peer containers via BTP and manages its own EIP-712 balance proofs.

## Prerequisites

Start the SDK E2E infrastructure (Anvil + 2 peer containers):

```bash
./scripts/sdk-e2e-infra.sh up
```

This starts:

| Service | Port | Purpose |
|---------|------|---------|
| Anvil | 18545 | Local Ethereum (chain 31337) |
| Peer1 BTP | 19000 | BTP WebSocket endpoint |
| Peer1 BLS | 19100 | Business Logic Server |
| Peer1 Relay | 19700 | Nostr relay (WebSocket) |
| Peer2 BTP | 19010 | BTP WebSocket endpoint |
| Peer2 BLS | 19110 | Business Logic Server |
| Peer2 Relay | 19710 | Nostr relay (WebSocket) |

## Examples

### 01 - Publish Event

Demonstrates the complete standalone client lifecycle: fund wallet, bootstrap, open payment channel, sign a self-describing claim, publish a Nostr event, and verify it on the relay.

**What you'll learn:**
- Connecting to external TOON peers via BTP
- Funding a wallet and opening a payment channel
- Signing EIP-712 balance proofs with `signBalanceProof()`
- Publishing a paid Nostr event and reading it back from the relay

```bash
npm run publish-event
```

**Expected output:** The client funds its wallet, opens a channel with Peer1, publishes a kind:1 event with payment, then queries the relay to confirm the event was stored.

### 02 - Payment Channel Lifecycle

Publishes multiple events with incrementing balance proofs, showing cumulative nonces and amounts. Queries on-chain channel state to verify participants and deposits.

**What you'll learn:**
- Cumulative balance proofs (nonce increments with each payment)
- Multi-event publishing within a single payment channel
- Querying on-chain channel state (participants, deposits, status)

```bash
npm run payment-channel
```

**Expected output:** Multiple events published with increasing nonce values, followed by on-chain channel state showing both participants and the total deposited amount.

## Notes

- Both examples use **Anvil Account #9** (`0xa0Ee7A142d267C1f36714E4a8F75612F20a79720`) as the client's EVM address. This account is unused by other examples and tests.
- The deployer (Account #0) funds the client wallet with USDC tokens before each run.
- Contract addresses are deterministic from the Anvil deployment (see source files for values).

## Teardown

```bash
./scripts/sdk-e2e-infra.sh down
```
