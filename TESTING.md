# Crosstown Testing Guide

This document describes how to test the Crosstown bootstrap flow with payment channels.

## Prerequisites

### Required Services

- **Anvil** (local Ethereum blockchain): Running via Docker
- **Connector** (ILP routing): From the connector repository
- **Crosstown nodes**: Two peers for testing

### Contract Deployment

Contracts must be deployed to Anvil before testing:

- **AGENT Token** (ERC20): Test token for payments
- **TokenNetworkRegistry**: Manages payment channel networks per token
- **TokenNetwork**: Individual channel network for AGENT token

## Quick Start

### Complete Bootstrap Test with Payment Channels

Run the full test suite with automatic setup:

```bash
bash test-payment-channels.sh
```

This script:

1. ✅ Restarts Anvil for fresh blockchain state
2. ✅ Deploys TokenNetworkRegistry and contracts
3. ✅ Verifies peer wallets have AGENT tokens
4. ✅ Cleans up any stale processes
5. ✅ Updates test configuration with contract addresses
6. ✅ Runs bootstrap test with 2 peers
7. ✅ Reports results

**Expected Output:**

```
channelCount: 1
[Bootstrap] Opened channel 0x...
✅ Bootstrap completed
```

### Verify On-Chain State

After successful test, verify the payment channel on blockchain:

```bash
bash verify-channel-state.sh
```

This checks:

- Token allowances (should be max uint256)
- Token balances (peer2 should have 9,999 AGENT after 100 deposited)
- Recent blockchain transactions
- Channel creation transactions

## Manual Testing

### Step 1: Ensure Anvil is Running

```bash
docker ps | grep anvil
```

If not running:

```bash
docker restart crosstown-anvil
```

### Step 2: Deploy Contracts

```bash
cd /Users/jonathangreen/Documents/connector/packages/contracts
/Users/jonathangreen/.foundry/bin/forge script \
  script/DeployLocal.s.sol:DeployLocalScript \
  --rpc-url http://localhost:8545 \
  --broadcast
```

Contract addresses (deterministic on Anvil):

- AGENT Token: `0x5FC8d32690cc91D4c39d9d3abcBD16989F875707`
- TokenNetworkRegistry: `0x0165878A594ca255338adfa4d48449f69242Eb8F`
- TokenNetwork: `0x3B02fF1e626Ed7a8fd6eC5299e2C54e1421B626B`

### Step 3: Run Bootstrap Test

```bash
bash run-local-bootstrap-test.sh
```

Watch for:

```
🔔 Bootstrap event: bootstrap:ready {
  type: 'bootstrap:ready',
  peerCount: 1,
  channelCount: 1   # ← Success!
}
```

## Test Architecture

### Peer Configuration

**Peer 1 (Genesis):**

- Node ID: `peer1`
- ILP Address: `g.crosstown.peer1`
- BLS Port: `3101`
- Nostr Relay Port: `7101`
- Connector Admin: `http://localhost:8091`
- EVM Address: `0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC`
- SPSP Min Price: `0` (genesis peer)

**Peer 2 (Joiner):**

- Node ID: `peer2`
- ILP Address: `g.crosstown.peer2`
- BLS Port: `3102`
- Nostr Relay Port: `7102`
- Connector Admin: `http://localhost:8092`
- EVM Address: `0x90F79bf6EB2c4f870365E785982E1f101E93b906`
- SPSP Min Price: `100` (requires payment for SPSP)

### Bootstrap Flow

1. **Discovery Phase**
   - Peer2 queries Peer1's Nostr relay for kind:10032 event
   - Receives ILP address, BTP endpoint, settlement info

2. **Registration Phase**
   - Peer2 adds Peer1 to connector routing table
   - BTP connection established

3. **Handshaking Phase**
   - SPSP request sent via ILP packet
   - Settlement parameters negotiated (chain, token, addresses)
   - **Payment channel opened** with TokenNetwork contract
   - ERC20 approve transaction (with nonce retry)
   - Deposit transaction (with nonce retry)

4. **Announcing Phase**
   - Peer2 sends announcement packet to Peer1
   - May fail if channel not fully set up (expected in test)

5. **Ready**
   - Bootstrap complete
   - `channelCount: 1` if successful

## Troubleshooting

### channelCount: 0

**Symptoms:** Bootstrap completes but `channelCount: 0`

**Common Causes:**

1. Settlement disabled in config
2. Nonce conflicts from previous test runs
3. Insufficient token balance
4. Contract not deployed

**Solutions:**

```bash
# Restart Anvil and redeploy
docker restart crosstown-anvil
sleep 5

# Redeploy contracts
cd /Users/jonathangreen/Documents/connector/packages/contracts
forge script script/DeployLocal.s.sol:DeployLocalScript \
  --rpc-url http://localhost:8545 --broadcast

# Run clean test
bash test-payment-channels.sh
```

### Nonce Errors

**Symptoms:** Logs show `nonce too low` or `NONCE_EXPIRED`

**Cause:** Connector has cached nonce from previous blockchain state

**Solution:** The connector now has automatic nonce retry logic that handles this. If you still see persistent errors:

```bash
# Kill all connector processes
lsof -ti :8091,:8092 | xargs kill -9

# Restart Anvil
docker restart crosstown-anvil

# Run clean test
bash test-payment-channels.sh
```

### Port Already in Use

**Symptoms:** `EADDRINUSE` errors when starting nodes

**Solution:**

```bash
# Find and kill processes on test ports
for port in 3051 3052 8091 8092 7101 7102 3101 3102; do
  lsof -ti :$port | xargs kill -9 2>/dev/null
done
```

### Contract Not Found

**Symptoms:** `No TokenNetwork found for token` or `execution reverted`

**Cause:** Contracts not deployed or Anvil was restarted

**Solution:** Redeploy contracts (see Step 2 above)

## Log Files

Test output is written to `/tmp/`:

- `/tmp/connector-peer1.log` - Peer1 connector logs (JSON)
- `/tmp/crosstown-peer1.log` - Peer1 crosstown node logs
- `/tmp/connector-peer2.log` - Peer2 connector logs (JSON)
- `/tmp/crosstown-peer2.log` - Peer2 crosstown node logs
- `/tmp/bootstrap-test-output.log` - Full test output

### Useful Log Queries

**Check for channel opening:**

```bash
grep "Opened channel" /tmp/crosstown-peer2.log
```

**Check for nonce retries:**

```bash
strings /tmp/connector-peer2.log | grep "Nonce error"
```

**Check final bootstrap status:**

```bash
grep "channelCount" /tmp/crosstown-peer2.log
```

**Check blockchain transactions:**

```bash
strings /tmp/connector-peer2.log | grep "approve\|setTotalDeposit"
```

## Test Scripts Reference

### test-payment-channels.sh

Complete end-to-end test with automatic setup and teardown.

- Manages Anvil lifecycle
- Deploys contracts
- Verifies balances
- Runs bootstrap test
- Reports results

### run-local-bootstrap-test.sh

Core bootstrap test that starts two peers and tests the flow.

- Starts 2 connector + 2 crosstown processes
- Waits for bootstrap to complete
- Verifies peer discovery, BTP connection, SPSP exchange
- Reports channelCount

### verify-channel-state.sh

On-chain verification of payment channel state.

- Checks token allowances
- Verifies token balances
- Lists recent transactions
- Confirms channel exists

## Success Criteria

A successful test shows:

```
✅ Anvil healthy
✅ Contracts deployed
✅ Peers have tokens (10,000 AGENT each)
✅ BTP connected
✅ channelCount: 1
✅ Channel opened with ID: 0x...
```

Blockchain state:

```
✅ Peer2 has max uint256 token allowance for TokenNetwork
✅ Peer2 balance reduced from 10,000 to 9,999 AGENT (100 deposited)
✅ Approve transaction on-chain (nonce 1)
✅ SetTotalDeposit transaction on-chain (nonce 2)
```

## Documentation

For complete technical details:

- **PAYMENT-CHANNELS-SUCCESS.md** - Complete success documentation with transaction details
- **PAYMENT-CHANNELS-PROGRESS.md** - Development journey and all fixes applied
- **CLAUDE.md** - Project overview and architecture
- **README.md** - General project information

## Notes

- Tests use deterministic contract addresses (Anvil always deploys to same addresses)
- Peer addresses are Anvil's default test accounts (accounts 2 and 3)
- Settlement is enabled by default in test scripts
- Nonce retry logic automatically handles transaction conflicts
- Clean test harness ensures no state leakage between runs
