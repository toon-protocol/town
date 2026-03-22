/**
 * Example 03: Full Lifecycle — Publish Events Between Two Nodes
 *
 * Demonstrates the complete TOON SDK lifecycle:
 *   1. Create two nodes (A and B) with embedded connectors
 *   2. Peer them directly via BTP
 *   3. Node A publishes a Nostr event routed to Node B
 *   4. Node B's handler receives and processes the event
 *   5. Node B publishes a reply routed back to Node A
 *
 * Requires: Anvil running on localhost:18545 (via ./scripts/sdk-e2e-infra.sh up)
 *
 * Run: npm run publish-event
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
// Anvil constants (deterministic addresses)
// ---------------------------------------------------------------------------

const ANVIL_RPC = 'http://localhost:18545';
const TOKEN_ADDRESS = '0x5FbDB2315678afecb367f032d93F642f64180aa3' as const; // Mock USDC (Anvil)
const REGISTRY_ADDRESS = '0xe7f1725e7734ce288f8367e1bb143e90bb3f0512' as const;
const DEPLOYER_PRIVATE_KEY = '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80' as const;

// Anvil Account #5 — Node A
const NODE_A_PRIVATE_KEY = '0x8b3a350cf5c34c9194ca85829a2df0ec3153be0318b5e2d3348e872092edffba' as const;
const NODE_A_EVM_ADDRESS = '0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc' as const;
// Anvil Account #6 — Node B
const NODE_B_PRIVATE_KEY = '0x92db14e403b83dfe3df233f83dfa3a0d7096f21ca9b0d6d6b8d88b2b4ec1564e' as const;
const NODE_B_EVM_ADDRESS = '0x976EA74026E726554dB657fA54763abd0C3a0aa9' as const;

const FUNDING_AMOUNT = 10n * 10n ** 18n; // 10 tokens (mock USDC on Anvil uses 18 decimals)

const anvilChain = defineChain({
  id: 31337,
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

// Track received events for verification
const receivedEvents: { nodeId: string; content: string; amount: bigint }[] = [];

async function fundAccount(walletClient: ReturnType<typeof createWalletClient>, address: Hex, label: string) {
  const client = createPublicClient({ chain: anvilChain, transport: http(ANVIL_RPC) });
  const balance = await client.readContract({
    address: TOKEN_ADDRESS,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: [address],
  });
  if (balance >= FUNDING_AMOUNT) {
    console.log(`  ${label}: already funded (${balance} USDC)`);
    return;
  }
  await walletClient.writeContract({
    address: TOKEN_ADDRESS,
    abi: ERC20_ABI,
    functionName: 'transfer',
    args: [address, FUNDING_AMOUNT],
  });
  console.log(`  ${label}: funded with ${FUNDING_AMOUNT} USDC`);
}

async function main() {
  console.log('=== TOON SDK: Full Lifecycle (Publish Events) ===\n');

  // --- 1. Check Anvil ---
  console.log('Checking Anvil...');
  try {
    const resp = await fetch(ANVIL_RPC, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ jsonrpc: '2.0', method: 'eth_chainId', params: [], id: 1 }),
    });
    const json = await resp.json() as { result?: string };
    const chainId = parseInt(json.result || '0', 16);
    if (chainId !== 31337) throw new Error(`Expected chain 31337, got ${chainId}`);
    console.log(`  Anvil running (chain ID: ${chainId})`);
  } catch {
    console.error('  Anvil not running! Start it with: ./scripts/sdk-e2e-infra.sh up');
    process.exit(1);
  }

  // --- 2. Fund accounts ---
  console.log('Funding node accounts...');
  const deployerAccount = privateKeyToAccount(DEPLOYER_PRIVATE_KEY);
  const walletClient = createWalletClient({
    account: deployerAccount,
    chain: anvilChain,
    transport: http(ANVIL_RPC),
  });
  await fundAccount(walletClient, NODE_A_EVM_ADDRESS, 'Node A');
  await fundAccount(walletClient, NODE_B_EVM_ADDRESS, 'Node B');

  // --- 3. Identities ---
  const identityA = fromMnemonic(generateMnemonic());
  const identityB = fromMnemonic(generateMnemonic());

  console.log(`\nNode A pubkey: ${identityA.pubkey.slice(0, 24)}...`);
  console.log(`Node B pubkey: ${identityB.pubkey.slice(0, 24)}...\n`);

  // --- 4. Embedded Connectors ---
  // connector@1.7.0 requires per-packet claims for forwarded packets.
  // settlementInfra wires the claim service; settlement.connectorFeePercentage: 0
  // disables routing fees so bi-directional routing works with equal basePricePerByte.
  const logger = pino({ level: 'silent' });

  const connectorA = new ConnectorNode({
    nodeId: 'lifecycle-node-a',
    btpServerPort: 6100,
    healthCheckPort: 6180,
    environment: 'development',
    deploymentMode: 'embedded',
    explorer: { enabled: false },
    settlement: { connectorFeePercentage: 0 } as any,
    peers: [{
      id: 'lifecycle-node-b',
      url: 'ws://localhost:6110',
      authToken: '',
      evmAddress: NODE_B_EVM_ADDRESS,
    }],
    routes: [
      { prefix: 'g.toon.lifecycle.node-a', nextHop: 'local', priority: 0 },
      { prefix: 'g.toon.lifecycle.node-b', nextHop: 'lifecycle-node-b', priority: 0 },
    ],
    settlementInfra: {
      enabled: true,
      rpcUrl: ANVIL_RPC,
      registryAddress: REGISTRY_ADDRESS,
      tokenAddress: TOKEN_ADDRESS,
      privateKey: NODE_A_PRIVATE_KEY,
      threshold: '999999999',
      pollingIntervalMs: 60000,
    },
  }, logger);

  const connectorB = new ConnectorNode({
    nodeId: 'lifecycle-node-b',
    btpServerPort: 6110,
    healthCheckPort: 6190,
    environment: 'development',
    deploymentMode: 'embedded',
    explorer: { enabled: false },
    settlement: { connectorFeePercentage: 0 } as any,
    peers: [{
      id: 'lifecycle-node-a',
      url: 'ws://localhost:6100',
      authToken: '',
      evmAddress: NODE_A_EVM_ADDRESS,
    }],
    routes: [
      { prefix: 'g.toon.lifecycle.node-b', nextHop: 'local', priority: 0 },
      { prefix: 'g.toon.lifecycle.node-a', nextHop: 'lifecycle-node-a', priority: 0 },
    ],
    settlementInfra: {
      enabled: true,
      rpcUrl: ANVIL_RPC,
      registryAddress: REGISTRY_ADDRESS,
      tokenAddress: TOKEN_ADDRESS,
      privateKey: NODE_B_PRIVATE_KEY,
      threshold: '999999999',
      pollingIntervalMs: 60000,
    },
  }, logger);

  // --- 5. SDK Nodes ---
  // Both nodes use basePricePerByte: 1n. With connectorFeePercentage: 0,
  // no routing fee is deducted, so both sides validate at the same rate.
  const nodeA = createNode({
    secretKey: identityA.secretKey,
    connector: connectorA,
    ilpAddress: 'g.toon.lifecycle.node-a',
    basePricePerByte: 1n,
    toonEncoder: encodeEventToToon,
    toonDecoder: decodeEventFromToon,
  });

  const nodeB = createNode({
    secretKey: identityB.secretKey,
    connector: connectorB,
    ilpAddress: 'g.toon.lifecycle.node-b',
    basePricePerByte: 1n,
    toonEncoder: encodeEventToToon,
    toonDecoder: decodeEventFromToon,
  });

  // --- 6. Event Handlers ---
  nodeA.on(1, async (ctx: HandlerContext) => {
    const event = ctx.decode();
    console.log(`  [Node A handler] Received: "${event.content}"`);
    console.log(`  [Node A handler] Payment: ${ctx.amount} units`);
    receivedEvents.push({ nodeId: 'A', content: event.content, amount: ctx.amount });
    return ctx.accept();
  });

  nodeB.on(1, async (ctx: HandlerContext) => {
    const event = ctx.decode();
    console.log(`  [Node B handler] Received: "${event.content}"`);
    console.log(`  [Node B handler] Payment: ${ctx.amount} units`);
    receivedEvents.push({ nodeId: 'B', content: event.content, amount: ctx.amount });
    return ctx.accept();
  });

  // --- 7. Start and Peer ---
  console.log('Starting connectors...');
  await connectorA.start();
  await connectorB.start();

  console.log('Waiting for BTP peering...');
  await new Promise((r) => setTimeout(r, 5000));

  console.log('Starting SDK nodes...');
  await nodeA.start();
  await nodeB.start();

  console.log('Both nodes started and peered.\n');

  // --- 8. Publish: Node A -> Node B ---
  console.log('--- Publish #1: Node A -> Node B ---');
  console.log('  Route: ConnectorA --(BTP)--> ConnectorB --> NodeB handler\n');

  const eventAtoB = finalizeEvent({
    kind: 1,
    content: 'Hello from Node A! This event was routed via ILP.',
    tags: [['route', 'A-to-B']],
    created_at: Math.floor(Date.now() / 1000),
  }, identityA.secretKey);

  const resultAtoB = await nodeA.publishEvent(eventAtoB, {
    destination: 'g.toon.lifecycle.node-b',
  });

  if (resultAtoB.success) {
    console.log(`  Published! Event ID: ${resultAtoB.eventId.slice(0, 24)}...\n`);
  } else {
    console.log(`  Failed: [${resultAtoB.code}] ${resultAtoB.message}\n`);
  }

  await new Promise((r) => setTimeout(r, 500));

  // --- 9. Publish: Node B -> Node A (reply) ---
  console.log('--- Publish #2: Node B -> Node A (reply) ---');
  console.log('  Route: ConnectorB --(BTP)--> ConnectorA --> NodeA handler\n');

  const eventBtoA = finalizeEvent({
    kind: 1,
    content: 'Reply from Node B! Round-trip routing works.',
    tags: [['route', 'B-to-A']],
    created_at: Math.floor(Date.now() / 1000),
  }, identityB.secretKey);

  const resultBtoA = await nodeB.publishEvent(eventBtoA, {
    destination: 'g.toon.lifecycle.node-a',
  });

  if (resultBtoA.success) {
    console.log(`  Published! Event ID: ${resultBtoA.eventId.slice(0, 24)}...\n`);
  } else {
    console.log(`  Failed: [${resultBtoA.code}] ${resultBtoA.message}\n`);
  }

  await new Promise((r) => setTimeout(r, 500));

  // --- 10. Summary ---
  console.log('=== Summary ===');
  console.log(`Events received: ${receivedEvents.length}`);
  for (const ev of receivedEvents) {
    console.log(`  Node ${ev.nodeId}: "${ev.content}" (paid ${ev.amount} units)`);
  }

  if (receivedEvents.length === 2) {
    console.log('\nBi-directional routing verified:');
    console.log('  A -> B (forward)');
    console.log('  B -> A (reply)');
  }

  // --- 11. Cleanup ---
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
