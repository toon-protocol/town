/**
 * Example 02: Payment Channel Lifecycle
 *
 * Demonstrates the full payment channel lifecycle from the standalone client perspective:
 *   1. Fund wallet and create CrosstownClient
 *   2. Bootstrap — payment channel opened on-chain automatically
 *   3. Publish multiple events, each with a self-describing signed claim
 *   4. Show cumulative balance proofs (nonce increments, amount accumulates)
 *   5. Query on-chain channel state to verify participants and deposits
 *   6. Verify all events are stored on peer1's relay
 *
 * This example highlights the key difference between client and SDK/Town:
 *   - SDK/Town: connector creates claims automatically per-packet
 *   - Client: YOU create self-describing claims via signBalanceProof()
 *
 * Prerequisites:
 *   - SDK E2E infrastructure running:
 *     ./scripts/sdk-e2e-infra.sh up
 *
 * Run: npm run payment-channel
 */

import { CrosstownClient } from '@crosstown/client';
import { encodeEventToToon, decodeEventFromToon } from '@crosstown/relay';
import { generateSecretKey, getPublicKey, finalizeEvent } from 'nostr-tools/pure';
import WebSocket from 'ws';
import {
  createPublicClient,
  createWalletClient,
  http,
  defineChain,
  type Hex,
} from 'viem';
import { privateKeyToAccount } from 'viem/accounts';

// ---------------------------------------------------------------------------
// Infrastructure — SDK E2E peer containers
// ---------------------------------------------------------------------------

const ANVIL_RPC = 'http://localhost:18545';
const PEER1_BTP = 'ws://localhost:19000';
const PEER1_BLS = 'http://localhost:19100';
const PEER1_RELAY = 'ws://localhost:19700';
const PEER1_PUBKEY = 'd6bfe100d1600c0d8f769501676fc74c3809500bd131c8a549f88cf616c21f35';
const PEER1_ILP_ADDRESS = 'g.crosstown.peer1';

// ---------------------------------------------------------------------------
// Contracts (deterministic Anvil addresses)
// ---------------------------------------------------------------------------

const TOKEN_ADDRESS = '0x5FbDB2315678afecb367f032d93F642f64180aa3' as const; // Mock USDC (Anvil)
const TOKEN_NETWORK_ADDRESS = '0xCafac3dD18aC6c6e92c921884f9E4176737C052c' as const;

const DEPLOYER_PRIVATE_KEY = '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80' as const;

// Anvil Account #9 — unused by other examples/tests
const CLIENT_PRIVATE_KEY = '0x2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6' as const;
const CLIENT_EVM_ADDRESS = '0xa0Ee7A142d267C1f36714E4a8F75612F20a79720' as const;

const FUNDING_AMOUNT = 10n * 10n ** 18n;
const EVENT_COUNT = 5;

// ---------------------------------------------------------------------------
// Chain config
// ---------------------------------------------------------------------------

const CHAIN_ID = 31337;
const CHAIN_IDENTIFIER = 'evm:base:31337';

const anvilChain = defineChain({
  id: CHAIN_ID,
  name: 'anvil',
  nativeCurrency: { name: 'ETH', symbol: 'ETH', decimals: 18 },
  rpcUrls: { default: { http: [ANVIL_RPC] } },
});

const ERC20_ABI = [
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
  {
    name: 'balanceOf',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ type: 'address' }],
    outputs: [{ type: 'uint256' }],
  },
] as const;

const TOKEN_NETWORK_ABI = [
  {
    name: 'channels',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ type: 'bytes32' }],
    outputs: [
      { name: 'settlementTimeout', type: 'uint256' },
      { name: 'state', type: 'uint8' },
      { name: 'closedAt', type: 'uint256' },
      { name: 'openedAt', type: 'uint256' },
      { name: 'participant1', type: 'address' },
      { name: 'participant2', type: 'address' },
    ],
  },
] as const;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

async function checkInfra(): Promise<void> {
  // Anvil
  const anvilResp = await fetch(ANVIL_RPC, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ jsonrpc: '2.0', method: 'eth_chainId', params: [], id: 1 }),
  });
  const anvilJson = await anvilResp.json() as { result?: string };
  if (parseInt(anvilJson.result || '0', 16) !== CHAIN_ID) {
    throw new Error('Anvil not running or wrong chain ID');
  }
  console.log(`  Anvil: chain ID ${CHAIN_ID}`);

  // Peer1
  const peerResp = await fetch(`${PEER1_BLS}/health`, { signal: AbortSignal.timeout(3000) });
  const health = await peerResp.json() as { status: string; bootstrapPhase: string };
  if (health.status !== 'healthy') throw new Error(`Peer1 unhealthy: ${health.status}`);
  console.log(`  Peer1: ${health.status} (phase: ${health.bootstrapPhase})`);
}

async function fundWallet(): Promise<void> {
  const client = createPublicClient({ chain: anvilChain, transport: http(ANVIL_RPC) });
  const balance = await client.readContract({
    address: TOKEN_ADDRESS,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: [CLIENT_EVM_ADDRESS],
  });

  if (balance >= FUNDING_AMOUNT) {
    console.log(`  Already funded (${balance} USDC)`);
    return;
  }

  const deployerAccount = privateKeyToAccount(DEPLOYER_PRIVATE_KEY);
  const walletClient = createWalletClient({
    account: deployerAccount,
    chain: anvilChain,
    transport: http(ANVIL_RPC),
  });

  await walletClient.writeContract({
    address: TOKEN_ADDRESS,
    abi: ERC20_ABI,
    functionName: 'transfer',
    args: [CLIENT_EVM_ADDRESS, FUNDING_AMOUNT],
  });
  console.log(`  Funded with ${FUNDING_AMOUNT} USDC`);
}

async function getChannelState(channelId: string) {
  const client = createPublicClient({ chain: anvilChain, transport: http(ANVIL_RPC) });
  const result = await client.readContract({
    address: TOKEN_NETWORK_ADDRESS,
    abi: TOKEN_NETWORK_ABI,
    functionName: 'channels',
    args: [channelId as Hex],
  });

  const [settlementTimeout, state, closedAt, openedAt, participant1, participant2] = result;
  const stateNames = ['settled', 'open', 'closed', 'settled'];
  return {
    channelId,
    state: stateNames[state] || 'unknown',
    settlementTimeout: Number(settlementTimeout),
    openedAt: Number(openedAt),
    closedAt: Number(closedAt),
    participant1,
    participant2,
  };
}

function queryRelay(url: string, filter: Record<string, unknown>, timeoutMs = 10000): Promise<unknown[]> {
  return new Promise((resolve) => {
    const events: unknown[] = [];
    const ws = new WebSocket(url);
    const subId = `query-${Date.now()}`;

    const timer = setTimeout(() => { ws.close(); resolve(events); }, timeoutMs);

    ws.on('open', () => {
      ws.send(JSON.stringify(['REQ', subId, filter]));
    });

    ws.on('message', (data: Buffer) => {
      try {
        const msg = JSON.parse(data.toString());
        if (Array.isArray(msg)) {
          if (msg[0] === 'EVENT' && msg[1] === subId) {
            // Relay returns TOON strings — decode to get event object
            const toonBytes = new TextEncoder().encode(msg[2]);
            const event = decodeEventFromToon(toonBytes);
            events.push(event);
          } else if (msg[0] === 'EOSE' && msg[1] === subId) {
            clearTimeout(timer);
            ws.close();
            resolve(events);
          }
        }
      } catch { /* ignore */ }
    });

    ws.on('error', () => { clearTimeout(timer); resolve(events); });
  });
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function main() {
  console.log('=== Crosstown Client: Payment Channel Lifecycle ===\n');

  // --- Phase 1: Preflight ---
  console.log('Phase 1: Checking infrastructure...');
  try {
    await checkInfra();
  } catch (err) {
    console.error(`  Not ready: ${err instanceof Error ? err.message : err}`);
    console.error('  Start it with: ./scripts/sdk-e2e-infra.sh up');
    process.exit(1);
  }
  console.log();

  // --- Phase 2: Fund wallet ---
  console.log('Phase 2: Funding client wallet (Anvil Account #9)...');
  await fundWallet();
  console.log();

  // --- Phase 3: Create client ---
  console.log('Phase 3: Creating CrosstownClient...');

  const secretKey = generateSecretKey();
  const pubkey = getPublicKey(secretKey);
  console.log(`  Nostr pubkey: ${pubkey.slice(0, 24)}...`);
  console.log(`  EVM address:  ${CLIENT_EVM_ADDRESS}`);

  const client = new CrosstownClient({
    connectorUrl: PEER1_BLS,
    btpUrl: PEER1_BTP,
    btpAuthToken: '',
    btpPeerId: `client-${pubkey.slice(0, 8)}`,
    secretKey,
    ilpInfo: {
      pubkey,
      ilpAddress: `g.crosstown.client.${pubkey.slice(0, 8)}`,
      btpEndpoint: PEER1_BTP,
      assetCode: 'USD',
      assetScale: 6,
    },
    toonEncoder: encodeEventToToon,
    toonDecoder: decodeEventFromToon,
    relayUrl: PEER1_RELAY,
    destinationAddress: PEER1_ILP_ADDRESS,
    knownPeers: [{
      pubkey: PEER1_PUBKEY,
      relayUrl: PEER1_RELAY,
      btpEndpoint: PEER1_BTP,
    }],
    evmPrivateKey: CLIENT_PRIVATE_KEY,
    supportedChains: [CHAIN_IDENTIFIER],
    chainRpcUrls: { [CHAIN_IDENTIFIER]: ANVIL_RPC },
    settlementAddresses: { [CHAIN_IDENTIFIER]: CLIENT_EVM_ADDRESS },
    preferredTokens: { [CHAIN_IDENTIFIER]: TOKEN_ADDRESS },
    tokenNetworks: { [CHAIN_IDENTIFIER]: TOKEN_NETWORK_ADDRESS },
  });
  console.log();

  // --- Phase 4: Bootstrap (opens payment channel) ---
  console.log('Phase 4: Starting client (bootstrap + payment channel)...');
  const startResult = await client.start();
  console.log(`  Peers discovered: ${startResult.peersDiscovered}`);

  const channels = client.getTrackedChannels();
  console.log(`  Payment channels: ${channels.length}`);

  if (channels.length === 0) {
    console.error('  No payment channel opened — cannot proceed.');
    await client.stop();
    process.exit(1);
  }

  const channelId = channels[0]!;
  console.log(`  Channel ID: ${channelId.slice(0, 32)}...`);
  console.log();

  // --- Phase 5: Query on-chain channel state ---
  console.log('Phase 5: Querying on-chain channel state...');
  const channelState = await getChannelState(channelId);
  console.log(`  State:              ${channelState.state}`);
  console.log(`  Participant 1:      ${channelState.participant1}`);
  console.log(`  Participant 2:      ${channelState.participant2}`);
  console.log(`  Settlement timeout: ${channelState.settlementTimeout}s`);

  // Verify our address is a participant
  const participants = [
    channelState.participant1.toLowerCase(),
    channelState.participant2.toLowerCase(),
  ];
  const isParticipant = participants.includes(CLIENT_EVM_ADDRESS.toLowerCase());
  console.log(`  Client is participant: ${isParticipant ? 'YES' : 'NO'}`);
  console.log();

  // --- Phase 6: Publish multiple events with incrementing claims ---
  console.log(`Phase 6: Publishing ${EVENT_COUNT} events with self-describing claims...\n`);

  const publishedIds: string[] = [];
  let totalPaid = 0n;

  for (let i = 1; i <= EVENT_COUNT; i++) {
    const event = finalizeEvent({
      kind: 1,
      content: `Payment channel demo event #${i} — ${new Date().toISOString()}`,
      tags: [['client', 'example-02'], ['n', `${i}`]],
      created_at: Math.floor(Date.now() / 1000),
    }, secretKey);

    // Sign balance proof — each call increments the nonce and accumulates amount.
    // These are SELF-DESCRIBING claims: they include channelId, signerAddress,
    // nonce, transferredAmount, and EIP-712 signature. The receiving connector
    // can verify them on-chain without any prior negotiation.
    const claimAmount = 1000n;
    const claim = await client.signBalanceProof(channelId, claimAmount);
    totalPaid += claimAmount;

    const result = await client.publishEvent(event, { claim });

    const status = result.success ? 'OK' : 'FAIL';
    console.log(
      `  Event #${i}: [${status}] nonce=${claim.nonce} ` +
      `cumulative=${claim.transferredAmount} ` +
      `id=${event.id.slice(0, 16)}...`
    );

    if (result.success) {
      publishedIds.push(event.id);
    } else {
      console.log(`    Error: ${result.error}`);
    }

    // Small delay between publishes
    await new Promise((r) => setTimeout(r, 200));
  }
  console.log(`\n  Total claimed: ${totalPaid} units across ${publishedIds.length} events\n`);

  // --- Phase 7: Verify events on relay ---
  console.log('Phase 7: Verifying events on relay...');
  await new Promise((r) => setTimeout(r, 1000));

  const storedEvents = await queryRelay(PEER1_RELAY, {
    authors: [pubkey],
    kinds: [1],
    limit: EVENT_COUNT + 5,
  });

  console.log(`  Found ${storedEvents.length} event(s) from our pubkey on relay`);

  // Check which published events are on the relay
  let verified = 0;
  for (const id of publishedIds) {
    const found = storedEvents.some((e: any) => e.id === id);
    if (found) verified++;
  }
  console.log(`  Verified: ${verified}/${publishedIds.length} published events found on relay`);
  console.log();

  // --- Phase 8: Cleanup ---
  console.log('Phase 8: Stopping client...');
  await client.stop();
  console.log('  Client stopped.');

  // --- Summary ---
  console.log('\n=== Summary ===');
  console.log(`  Nostr pubkey:      ${pubkey.slice(0, 24)}...`);
  console.log(`  EVM address:       ${CLIENT_EVM_ADDRESS}`);
  console.log(`  Channel ID:        ${channelId.slice(0, 24)}...`);
  console.log(`  Channel state:     ${channelState.state}`);
  console.log(`  Events published:  ${publishedIds.length}/${EVENT_COUNT}`);
  console.log(`  Events verified:   ${verified}/${publishedIds.length}`);
  console.log(`  Total claimed:     ${totalPaid} units`);
  console.log(`  Final nonce:       ${EVENT_COUNT}`);
  console.log('\nAll self-describing claims signed by the client — no connector involvement.');
  console.log('Done.');
  process.exit(0);
}

main().catch((err) => {
  console.error('Fatal:', err);
  process.exit(1);
});
