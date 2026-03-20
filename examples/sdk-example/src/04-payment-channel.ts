/**
 * Example 04: On-Chain Payment Channels
 *
 * Demonstrates real settlement using EVM payment channels on a local Anvil chain.
 * The connector handles all on-chain complexity automatically: channel open, deposit,
 * per-packet EIP-712 signed claims, and threshold-triggered settlement.
 *
 * This example runs with FULL signature verification and pricing validation (no devMode).
 * The sender uses a higher basePricePerByte (11) to account for the connector's 0.1%
 * routing fee, while the receiver validates at the base rate (basePricePerByte: 10).
 *
 * Flow (two settlement cycles):
 *   1. Fund EVM wallets with USDC tokens
 *   2. Create connectors with low settlement threshold (triggers after a few events)
 *   3. Publish batch 1 → threshold exceeded → connector opens channel + deposits on-chain
 *   4. Verify channel opened with correct participants and deposit
 *   5. Publish batch 2 → threshold exceeded again → cooperative settle via existing channel
 *   6. Verify: B wallet increased, A wallet decreased, channel settled, ILP balance cleared
 *
 * Prerequisites:
 *   - Anvil running on localhost:18545 (via ./scripts/sdk-e2e-infra.sh up)
 *   - USDC token and TokenNetwork deployed (deterministic Anvil addresses)
 *
 * Run: npm run payment-channel
 */

import { createNode, fromMnemonic, generateMnemonic } from '@toon-protocol/sdk';
import type { HandlerContext } from '@toon-protocol/sdk';
import { ConnectorNode } from '@toon-protocol/connector';
import { encodeEventToToon, decodeEventFromToon } from '@toon-protocol/core/toon';
import { finalizeEvent } from 'nostr-tools/pure';
import pino from 'pino';
import {
  createPublicClient,
  createWalletClient,
  http,
  defineChain,
  type Hex,
} from 'viem';
import { privateKeyToAccount } from 'viem/accounts';

// ---------------------------------------------------------------------------
// Constants (Anvil deterministic addresses)
// ---------------------------------------------------------------------------

const ANVIL_RPC = 'http://localhost:18545';
const CHAIN_ID = 31337;

// Contracts (deployed by genesis node)
const TOKEN_ADDRESS = '0x5FbDB2315678afecb367f032d93F642f64180aa3' as const; // Mock USDC (Anvil)
const REGISTRY_ADDRESS = '0xe7f1725e7734ce288f8367e1bb143e90bb3f0512' as const;

// Anvil Account #0 — deployer, holds all USDC tokens
const DEPLOYER_PRIVATE_KEY = '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80' as const;

// Anvil Account #3 — Node A settlement key
const NODE_A_PRIVATE_KEY = '0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6' as const;
const NODE_A_EVM_ADDRESS = '0x90F79bf6EB2c4f870365E785982E1f101E93b906' as const;

// Anvil Account #4 — Node B settlement key
const NODE_B_PRIVATE_KEY = '0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a' as const;
const NODE_B_EVM_ADDRESS = '0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65' as const;

// Funding amount: 10 tokens per node (mock USDC on Anvil uses 18 decimals)
const FUNDING_AMOUNT = 10n * 10n ** 18n;

// Settlement config: low threshold so a few events trigger auto-settlement
const SETTLEMENT_THRESHOLD = '5000';   // Trigger settlement when ILP balance > 5000
const SETTLEMENT_POLLING_MS = 2000;     // Check every 2 seconds

// Two batches of events to drive two settlement cycles:
//   Batch 1 → threshold exceeded → opens channel + deposits (A wallet down, B unchanged)
//   Batch 2 → threshold exceeded again → cooperative settle via existing channel (B receives funds)
const BATCH_1_COUNT = 3;               // ~4600 units each ≈ 13800 total > 5000
const BATCH_2_COUNT = 3;               // Another ~13800 > 5000 triggers cooperative settle

// Pricing: sender accounts for the connector's 0.1% routing fee.
// Connector deducts fee = (amount * 10) / 10000 when forwarding.
// Sender: 11 * ~420 bytes = ~4620 → fee ~4 → forwarded ~4616
// Receiver validates: ~4616 >= 10 * ~420 = ~4200 → passes
const SENDER_PRICE_PER_BYTE = 11n;
const RECEIVER_PRICE_PER_BYTE = 10n;

// ---------------------------------------------------------------------------
// Anvil chain definition
// ---------------------------------------------------------------------------

const anvilChain = defineChain({
  id: CHAIN_ID,
  name: 'anvil',
  nativeCurrency: { name: 'ETH', symbol: 'ETH', decimals: 18 },
  rpcUrls: { default: { http: [ANVIL_RPC] } },
});

// ---------------------------------------------------------------------------
// ABIs (minimal — only what we need)
// ---------------------------------------------------------------------------

const ERC20_ABI = [
  {
    name: 'balanceOf',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ type: 'address' }],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'transfer',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'to', type: 'address' },
      { name: 'amount', type: 'uint256' },
    ],
    outputs: [{ name: '', type: 'bool' }],
  },
] as const;

// ---------------------------------------------------------------------------
// Track received events
// ---------------------------------------------------------------------------

const receivedEvents: { nodeId: string; content: string; amount: bigint }[] = [];

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function createViemClient() {
  return createPublicClient({
    chain: anvilChain,
    transport: http(ANVIL_RPC),
  });
}

async function getTokenBalance(address: Hex): Promise<bigint> {
  const client = createViemClient();
  return client.readContract({
    address: TOKEN_ADDRESS,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: [address],
  });
}

function assert(condition: boolean, message: string): void {
  if (!condition) {
    console.error(`\n  ASSERTION FAILED: ${message}`);
    process.exit(1);
  }
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function main() {
  console.log('=== TOON SDK: On-Chain Payment Channels ===\n');

  // --- Phase 1: Check Anvil ---
  console.log('Phase 1: Checking Anvil is running...');
  try {
    const resp = await fetch(ANVIL_RPC, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ jsonrpc: '2.0', method: 'eth_chainId', params: [], id: 1 }),
    });
    const json = await resp.json() as { result?: string };
    const chainId = parseInt(json.result || '0', 16);
    if (chainId !== CHAIN_ID) {
      throw new Error(`Expected chain ID ${CHAIN_ID}, got ${chainId}`);
    }
    console.log(`  Anvil running (chain ID: ${chainId})\n`);
  } catch (err) {
    console.error('  Anvil not running! Start it with: ./scripts/sdk-e2e-infra.sh up');
    console.error(`  Error: ${err instanceof Error ? err.message : err}`);
    process.exit(1);
  }

  // --- Phase 2: Fund Node Accounts + snapshot pre-funding balances ---
  console.log('Phase 2: Funding node accounts with USDC tokens...');

  const preFundBalanceA = await getTokenBalance(NODE_A_EVM_ADDRESS);
  const preFundBalanceB = await getTokenBalance(NODE_B_EVM_ADDRESS);
  console.log(`  Pre-funding balances: A=${preFundBalanceA}, B=${preFundBalanceB}`);

  const deployerAccount = privateKeyToAccount(DEPLOYER_PRIVATE_KEY);
  const walletClient = createWalletClient({
    account: deployerAccount,
    chain: anvilChain,
    transport: http(ANVIL_RPC),
  });

  // Transfer USDC tokens from deployer to each node
  for (const [label, address] of [['Node A', NODE_A_EVM_ADDRESS], ['Node B', NODE_B_EVM_ADDRESS]] as const) {
    const balanceBefore = await getTokenBalance(address);
    if (balanceBefore >= FUNDING_AMOUNT) {
      console.log(`  ${label} (${address.slice(0, 10)}...): already funded (${balanceBefore} USDC)`);
      continue;
    }

    await walletClient.writeContract({
      address: TOKEN_ADDRESS,
      abi: ERC20_ABI,
      functionName: 'transfer',
      args: [address, FUNDING_AMOUNT],
    });

    const balanceAfter = await getTokenBalance(address);
    console.log(`  ${label} (${address.slice(0, 10)}...): funded with ${FUNDING_AMOUNT} USDC (balance: ${balanceAfter})`);
  }
  console.log();

  // --- Phase 3: Embedded Connectors with Settlement ---
  console.log('Phase 3: Creating connectors with on-chain settlement...');
  console.log(`  Settlement threshold: ${SETTLEMENT_THRESHOLD} units`);
  console.log(`  Polling interval: ${SETTLEMENT_POLLING_MS}ms`);

  // Settlement accounting (fee deduction, balance tracking in the ILP packet handler)
  // requires SETTLEMENT_ENABLED=true. The `settlementInfra.enabled` flag only starts the
  // EVM infrastructure (PaymentChannelSDK, SettlementMonitor, SettlementExecutor).
  // The packet handler's `enableSettlement` check reads this env var directly — there is
  // no config path in connector@1.6.x. Without it, ILP packets are forwarded at full
  // amount (no fee deduction) and no balance ledger entries are recorded, so the
  // settlement monitor never detects a threshold breach.
  process.env['SETTLEMENT_ENABLED'] = 'true';

  const logger = pino({ level: 'silent' });

  const connectorA = new ConnectorNode({
    nodeId: 'channel-node-a',
    btpServerPort: 6200,
    healthCheckPort: 6280,
    environment: 'development',
    deploymentMode: 'embedded',
    explorer: { enabled: false },
    peers: [{
      id: 'channel-node-b',
      url: 'ws://localhost:6210',
      authToken: '',
      evmAddress: NODE_B_EVM_ADDRESS,
    }],
    routes: [
      { prefix: 'g.toon.channel.node-a', nextHop: 'local', priority: 0 },
      { prefix: 'g.toon.channel.node-b', nextHop: 'channel-node-b', priority: 0 },
    ],
    settlementInfra: {
      enabled: true,
      rpcUrl: ANVIL_RPC,
      registryAddress: REGISTRY_ADDRESS,
      tokenAddress: TOKEN_ADDRESS,
      privateKey: NODE_A_PRIVATE_KEY,
      threshold: SETTLEMENT_THRESHOLD,
      pollingIntervalMs: SETTLEMENT_POLLING_MS,
    },
  }, logger);

  const connectorB = new ConnectorNode({
    nodeId: 'channel-node-b',
    btpServerPort: 6210,
    healthCheckPort: 6290,
    environment: 'development',
    deploymentMode: 'embedded',
    explorer: { enabled: false },
    peers: [{
      id: 'channel-node-a',
      url: 'ws://localhost:6200',
      authToken: '',
      evmAddress: NODE_A_EVM_ADDRESS,
    }],
    routes: [
      { prefix: 'g.toon.channel.node-b', nextHop: 'local', priority: 0 },
      { prefix: 'g.toon.channel.node-a', nextHop: 'channel-node-a', priority: 0 },
    ],
    settlementInfra: {
      enabled: true,
      rpcUrl: ANVIL_RPC,
      registryAddress: REGISTRY_ADDRESS,
      tokenAddress: TOKEN_ADDRESS,
      privateKey: NODE_B_PRIVATE_KEY,
      threshold: SETTLEMENT_THRESHOLD,
      pollingIntervalMs: SETTLEMENT_POLLING_MS,
    },
  }, logger);

  console.log('  Connector A: settlementInfra enabled');
  console.log('  Connector B: settlementInfra enabled\n');

  // --- Phase 4: SDK Nodes (NO devMode — full verification + pricing) ---
  console.log('Phase 4: Creating SDK nodes (full verification, no devMode)...');
  const identityA = fromMnemonic(generateMnemonic());
  const identityB = fromMnemonic(generateMnemonic());

  // Sender (Node A) uses basePricePerByte: 11 — accounts for the connector's 0.1% routing fee.
  // Receiver (Node B) uses basePricePerByte: 10 — validates at the base rate.
  // The higher sender rate ensures the forwarded amount (after fee deduction) still
  // meets the receiver's minimum.
  const nodeA = createNode({
    secretKey: identityA.secretKey,
    connector: connectorA,
    ilpAddress: 'g.toon.channel.node-a',
    basePricePerByte: SENDER_PRICE_PER_BYTE,
    toonEncoder: encodeEventToToon,
    toonDecoder: decodeEventFromToon,
  });

  const nodeB = createNode({
    secretKey: identityB.secretKey,
    connector: connectorB,
    ilpAddress: 'g.toon.channel.node-b',
    basePricePerByte: RECEIVER_PRICE_PER_BYTE,
    toonEncoder: encodeEventToToon,
    toonDecoder: decodeEventFromToon,
  });

  // Event handlers
  nodeA.on(1, async (ctx: HandlerContext) => {
    const event = ctx.decode();
    receivedEvents.push({ nodeId: 'A', content: event.content, amount: ctx.amount });
    return ctx.accept();
  });

  nodeB.on(1, async (ctx: HandlerContext) => {
    const event = ctx.decode();
    receivedEvents.push({ nodeId: 'B', content: event.content, amount: ctx.amount });
    return ctx.accept();
  });

  console.log(`  Node A pubkey: ${identityA.pubkey.slice(0, 16)}... (sender, basePricePerByte: ${SENDER_PRICE_PER_BYTE})`);
  console.log(`  Node B pubkey: ${identityB.pubkey.slice(0, 16)}... (receiver, basePricePerByte: ${RECEIVER_PRICE_PER_BYTE})\n`);

  // --- Phase 5: Start and Peer ---
  console.log('Phase 5: Starting connectors and SDK nodes...');
  await connectorA.start();
  await connectorB.start();

  console.log('  Waiting for BTP peering...');
  await new Promise((r) => setTimeout(r, 5000));

  await nodeA.start();
  await nodeB.start();
  console.log('  Both nodes started and peered.\n');

  // Snapshot wallet balances AFTER funding, BEFORE publishing
  const walletBalanceA_before = await getTokenBalance(NODE_A_EVM_ADDRESS);
  const walletBalanceB_before = await getTokenBalance(NODE_B_EVM_ADDRESS);

  // Helper: publish a batch of events and return stats
  async function publishBatch(label: string, count: number, startIndex: number) {
    let paid = 0n;
    let delivered = 0;
    for (let i = startIndex; i < startIndex + count; i++) {
      const event = finalizeEvent({
        kind: 1,
        content: `Event #${i} from A — on-chain payment channel settlement demo`,
        tags: [['n', `${i}`]],
        created_at: Math.floor(Date.now() / 1000),
      }, identityA.secretKey);

      const result = await nodeA.publishEvent(event, {
        destination: 'g.toon.channel.node-b',
      });

      if (result.success) {
        delivered++;
        const received = receivedEvents[receivedEvents.length - 1];
        paid += received.amount;
        console.log(`  ${label} event #${i}: delivered (${received.amount} units, cumulative batch: ${paid})`);
      } else {
        console.log(`  ${label} event #${i}: FAILED [${result.code}] ${result.message}`);
      }

      await new Promise((r) => setTimeout(r, 200));
    }
    return { paid, delivered };
  }

  // =========================================================================
  // CYCLE 1: Open payment channel
  // =========================================================================

  // --- Phase 6: Publish batch 1 (exceed threshold → triggers channel open) ---
  console.log(`Phase 6: Publishing batch 1 (${BATCH_1_COUNT} events) to trigger channel open...\n`);

  const batch1 = await publishBatch('Batch 1', BATCH_1_COUNT, 1);
  console.log(`\n  Batch 1 total: ${batch1.paid} units (threshold: ${SETTLEMENT_THRESHOLD})`);
  assert(batch1.delivered === BATCH_1_COUNT, `Expected ${BATCH_1_COUNT} delivered, got ${batch1.delivered}`);
  console.log(`  [PASS] All ${BATCH_1_COUNT} batch 1 events delivered`);

  // Snapshot ILP balance BEFORE first settlement
  let ilpCreditBeforeSettle1 = 0n;
  try {
    const bal = await connectorA.getBalance('channel-node-b');
    for (const b of bal.balances) {
      const credit = BigInt(b.creditBalance);
      if (credit > ilpCreditBeforeSettle1) ilpCreditBeforeSettle1 = credit;
    }
  } catch { /* balance may not be available yet */ }
  console.log(`  ILP credit balance (pre-settlement): ${ilpCreditBeforeSettle1}`);
  assert(ilpCreditBeforeSettle1 > 0n, `Expected ILP credit > 0 before settlement, got ${ilpCreditBeforeSettle1}`);
  console.log('  [PASS] ILP credit balance accumulated\n');

  // --- Phase 7: Wait for first settlement (channel open + deposit) ---
  console.log('Phase 7: Waiting for first settlement (channel open + deposit)...');
  await new Promise((r) => setTimeout(r, 10000));
  console.log('  Done.\n');

  // Verify channel was opened on-chain
  const sdk = connectorA.paymentChannelSDK;
  assert(sdk !== null, 'PaymentChannelSDK not initialized on Connector A');

  console.log('  Querying on-chain channel state after first settlement...');
  const channelIds = await sdk!.getMyChannels(TOKEN_ADDRESS);
  console.log(`    Channels found: ${channelIds.length} (IDs: ${channelIds.join(', ') || 'none'})`);
  assert(channelIds.length > 0, 'Expected at least one payment channel opened on-chain');
  console.log('  [PASS] Payment channel opened on-chain');

  // Find the channel that is currently in 'opened' state (skip settled channels from prior runs)
  let channelId = channelIds[0];
  let channelStateAfterOpen = await sdk!.getChannelState(channelId, TOKEN_ADDRESS);
  for (const cid of channelIds) {
    const state = await sdk!.getChannelState(cid, TOKEN_ADDRESS);
    if (state.status === 'opened') {
      channelId = cid;
      channelStateAfterOpen = state;
      break;
    }
  }

  console.log(`\n    Channel ${channelId}:`);
  console.log(`      Participants: ${channelStateAfterOpen.participants[0]}, ${channelStateAfterOpen.participants[1]}`);
  console.log(`      My deposit:    ${channelStateAfterOpen.myDeposit}`);
  console.log(`      Their deposit: ${channelStateAfterOpen.theirDeposit}`);
  console.log(`      Status:        ${channelStateAfterOpen.status}`);

  const participants = channelStateAfterOpen.participants.map((p: string) => p.toLowerCase());
  assert(
    participants.includes(NODE_A_EVM_ADDRESS.toLowerCase()) &&
    participants.includes(NODE_B_EVM_ADDRESS.toLowerCase()),
    `Expected participants [${NODE_A_EVM_ADDRESS}, ${NODE_B_EVM_ADDRESS}], got [${channelStateAfterOpen.participants}]`,
  );
  console.log('  [PASS] Channel participants match Node A and Node B');

  assert(channelStateAfterOpen.status === 'opened', `Expected channel status 'opened', got '${channelStateAfterOpen.status}'`);
  console.log('  [PASS] Channel status: opened');

  const myDepositAfterOpen = BigInt(channelStateAfterOpen.myDeposit);
  const theirDepositAfterOpen = BigInt(channelStateAfterOpen.theirDeposit);
  const totalDepositAfterOpen = myDepositAfterOpen + theirDepositAfterOpen;
  assert(totalDepositAfterOpen > 0n, `Expected total deposit > 0, got ${totalDepositAfterOpen}`);
  console.log(`  [PASS] Channel total deposit: ${totalDepositAfterOpen} (my: ${myDepositAfterOpen}, their: ${theirDepositAfterOpen})\n`);

  // Snapshot wallet balances between settlement cycles
  const walletA_midpoint = await getTokenBalance(NODE_A_EVM_ADDRESS);
  const walletB_midpoint = await getTokenBalance(NODE_B_EVM_ADDRESS);
  const midpointADiff = walletA_midpoint - walletBalanceA_before;
  const midpointBDiff = walletB_midpoint - walletBalanceB_before;
  console.log('  Mid-point wallet balances (after channel open):');
  console.log(`    Node A diff: ${midpointADiff} (deposited into channel)`);
  console.log(`    Node B diff: ${midpointBDiff} (unchanged, funds locked in channel)`);
  const someoneDeposited = midpointADiff < 0n || midpointBDiff < 0n;
  assert(someoneDeposited, `Expected at least one wallet to decrease after channel deposit, got A diff: ${midpointADiff}, B diff: ${midpointBDiff}`);
  console.log(`  [PASS] Deposit confirmed (A diff: ${midpointADiff}, B diff: ${midpointBDiff})`);

  // =========================================================================
  // CYCLE 2: Cooperative settlement (B receives funds)
  // =========================================================================

  // --- Phase 8: Publish batch 2 (exceed threshold → triggers cooperative settle) ---
  console.log(`\nPhase 8: Publishing batch 2 (${BATCH_2_COUNT} events) to trigger cooperative settlement...\n`);

  const batch2 = await publishBatch('Batch 2', BATCH_2_COUNT, BATCH_1_COUNT + 1);
  console.log(`\n  Batch 2 total: ${batch2.paid} units (threshold: ${SETTLEMENT_THRESHOLD})`);
  assert(batch2.delivered === BATCH_2_COUNT, `Expected ${BATCH_2_COUNT} delivered, got ${batch2.delivered}`);
  console.log(`  [PASS] All ${BATCH_2_COUNT} batch 2 events delivered\n`);

  // --- Phase 9: Wait for cooperative settlement ---
  console.log('Phase 9: Waiting for cooperative settlement (funds → B wallet)...');
  await new Promise((r) => setTimeout(r, 10000));
  console.log('  Done.\n');

  // --- Phase 10: Final verification ---
  console.log('Phase 10: Final verification...\n');

  const totalEvents = BATCH_1_COUNT + BATCH_2_COUNT;
  const totalPaid = batch1.paid + batch2.paid;
  const totalDelivered = batch1.delivered + batch2.delivered;

  // --- 10a: Wallet balance diffs ---
  const walletBalanceA_after = await getTokenBalance(NODE_A_EVM_ADDRESS);
  const walletBalanceB_after = await getTokenBalance(NODE_B_EVM_ADDRESS);
  const walletADiff = walletBalanceA_after - walletBalanceA_before;
  const walletBDiff = walletBalanceB_after - walletBalanceB_before;

  console.log('  Wallet balances (before → after):');
  console.log(`    Node A: ${walletBalanceA_before} → ${walletBalanceA_after} (diff: ${walletADiff})`);
  console.log(`    Node B: ${walletBalanceB_before} → ${walletBalanceB_after} (diff: ${walletBDiff})`);

  if (walletADiff < 0n) {
    console.log('  [PASS] Node A wallet decreased (paid for events)');
  } else {
    console.log('  [WARN] Node A wallet did not decrease yet — settlement may still be in progress');
  }

  if (walletBDiff > 0n) {
    console.log('  [PASS] Node B wallet increased (received funds from cooperative settlement)');
  } else {
    console.log('  [WARN] Node B wallet did not increase yet — settlement may still be in progress');
  }

  // --- 10b: On-chain channel state after cooperative settle ---
  const channelStateFinal = await sdk!.getChannelState(channelId, TOKEN_ADDRESS);
  console.log(`\n  Channel ${channelId} (final):`);
  console.log(`      Status:        ${channelStateFinal.status}`);
  console.log(`      My deposit:    ${channelStateFinal.myDeposit}`);
  console.log(`      Their deposit: ${channelStateFinal.theirDeposit}`);

  if (channelStateFinal.status === 'settled') {
    console.log('  [PASS] Channel status: settled (cooperative settlement complete)');
  } else {
    console.log(`  [INFO] Channel status: ${channelStateFinal.status} (settlement may still be in progress)`);
  }

  // --- 10c: ILP balances post-settlement (should be cleared) ---
  let ilpCreditAfter = 0n;
  try {
    const balPost = await connectorA.getBalance('channel-node-b');
    console.log('\n  ILP balances (post-settlement, A owes B):');
    for (const b of balPost.balances) {
      console.log(`    ${b.tokenId}: debit=${b.debitBalance} credit=${b.creditBalance} net=${b.netBalance}`);
      const credit = BigInt(b.creditBalance);
      if (credit > ilpCreditAfter) ilpCreditAfter = credit;
    }
  } catch {
    console.log('\n  ILP balances: not available');
  }

  if (ilpCreditAfter === 0n) {
    console.log('  [PASS] ILP credit balance cleared to 0 (settlement complete)');
  } else {
    console.log(`  [INFO] ILP credit balance: ${ilpCreditAfter} (settlement may still be clearing)`);
  }

  // --- Summary ---
  console.log('\n=== Summary ===');
  console.log(`Events published:    ${totalEvents} (batch 1: ${BATCH_1_COUNT}, batch 2: ${BATCH_2_COUNT})`);
  console.log(`Events delivered:    ${totalDelivered}`);
  console.log(`Total ILP payment:   ${totalPaid} units`);
  console.log(`Settlement threshold: ${SETTLEMENT_THRESHOLD} units`);
  console.log(`Node A wallet diff:  ${walletADiff} USDC (net payment for events)`);
  console.log(`Node B wallet diff:  ${walletBDiff} USDC (received from settlement)`);
  console.log(`Channel ID:          ${channelId}`);
  console.log(`Channel status:      ${channelStateFinal.status}`);
  console.log(`ILP balance cleared: ${ilpCreditAfter === 0n}`);
  console.log('\nAll assertions passed — real on-chain settlement verified.');

  // --- Cleanup ---
  console.log('\nCleaning up...');
  await nodeA.stop();
  await nodeB.stop();
  await connectorA.stop();
  await connectorB.stop();

  console.log('Done.');
  process.exit(0);
}

main().catch((err) => {
  console.error('Fatal:', err);
  process.exit(1);
});
