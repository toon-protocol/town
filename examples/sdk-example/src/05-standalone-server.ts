/**
 * Example 05: Standalone SDK Server
 *
 * Demonstrates running an SDK service node in standalone mode: the node
 * connects to an external connector via HTTP instead of embedding one.
 * The SDK starts its own HTTP server to receive ILP packets from the
 * connector's local delivery mechanism.
 *
 * Key differences from embedded mode (Examples 02-04):
 *   - createNode() receives { connectorUrl, handlerPort } instead of { connector }
 *   - The SDK starts an HTTP server on handlerPort with /handle-packet and /health
 *   - ConnectorNode uses deploymentMode: 'standalone' with localDelivery pointing
 *     to the SDK's HTTP server
 *   - No direct reference to the connector object in the SDK code
 *
 * Topology:
 *   ConnectorA (standalone, admin:5081) <--(BTP)--> ConnectorB (standalone, admin:5091)
 *   SDK Node A (handler:3600) <--(HTTP)--> ConnectorA
 *   SDK Node B (handler:3700) <--(HTTP)--> ConnectorB
 *
 * Requires: Anvil running on localhost:18545 (via ./scripts/sdk-e2e-infra.sh up)
 *
 * Run: npm run standalone-server
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
  console.log('=== TOON SDK: Standalone Server Mode ===\n');

  // --- 1. Check Anvil ---
  console.log('Checking Anvil...');
  try {
    const resp = await fetch(ANVIL_RPC, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ jsonrpc: '2.0', method: 'eth_chainId', params: [], id: 1 }),
    });
    const json = await resp.json() as { result?: string };
    if (parseInt(json.result || '0', 16) !== 31337) throw new Error('Wrong chain');
    console.log('  Anvil running.\n');
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

  const logger = pino({ level: 'silent' });

  // --- 4. External connectors (standalone mode) ---
  // connector@1.7.0 requires per-packet claims for forwarded packets.
  // settlementInfra wires the claim service; settlement.connectorFeePercentage: 0
  // disables routing fees so bi-directional routing works with equal basePricePerByte.
  console.log('Starting standalone connectors...');

  const connectorA = new ConnectorNode({
    nodeId: 'standalone-node-a',
    btpServerPort: 5100,
    healthCheckPort: 5180,
    environment: 'development',
    deploymentMode: 'standalone',
    adminApi: { enabled: true, port: 5181 },
    localDelivery: {
      enabled: true,
      handlerUrl: 'http://localhost:3600',
    },
    explorer: { enabled: false },
    settlement: { connectorFeePercentage: 0 } as any,
    peers: [{
      id: 'standalone-node-b',
      url: 'ws://localhost:5110',
      authToken: '',
      evmAddress: NODE_B_EVM_ADDRESS,
    }],
    routes: [
      { prefix: 'g.toon.standalone.node-a', nextHop: 'local', priority: 0 },
      { prefix: 'g.toon.standalone.node-b', nextHop: 'standalone-node-b', priority: 0 },
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
    nodeId: 'standalone-node-b',
    btpServerPort: 5110,
    healthCheckPort: 5190,
    environment: 'development',
    deploymentMode: 'standalone',
    adminApi: { enabled: true, port: 5191 },
    localDelivery: {
      enabled: true,
      handlerUrl: 'http://localhost:3700',
    },
    explorer: { enabled: false },
    settlement: { connectorFeePercentage: 0 } as any,
    peers: [{
      id: 'standalone-node-a',
      url: 'ws://localhost:5100',
      authToken: '',
      evmAddress: NODE_A_EVM_ADDRESS,
    }],
    routes: [
      { prefix: 'g.toon.standalone.node-b', nextHop: 'local', priority: 0 },
      { prefix: 'g.toon.standalone.node-a', nextHop: 'standalone-node-a', priority: 0 },
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

  // Start B first so A's BTP client can connect immediately
  await connectorB.start();
  await connectorA.start();
  console.log('  Connector A: health=5180, admin=5181, BTP=5100');
  console.log('  Connector B: health=5190, admin=5191, BTP=5110\n');

  // --- 5. SDK Nodes in standalone mode ---
  console.log('Creating SDK nodes (standalone mode)...');

  const nodeA = createNode({
    secretKey: identityA.secretKey,
    connectorUrl: 'http://localhost:5181',
    handlerPort: 3600,
    ilpAddress: 'g.toon.standalone.node-a',
    basePricePerByte: 1n,
    toonEncoder: encodeEventToToon,
    toonDecoder: decodeEventFromToon,
  });

  const nodeB = createNode({
    secretKey: identityB.secretKey,
    connectorUrl: 'http://localhost:5191',
    handlerPort: 3700,
    ilpAddress: 'g.toon.standalone.node-b',
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

  // --- 7. Start nodes (starts HTTP servers) ---
  console.log('Starting SDK nodes (starts HTTP servers)...');
  await nodeA.start();
  await nodeB.start();
  console.log('  Node A listening on http://localhost:3600 (/handle-packet, /health)');
  console.log('  Node B listening on http://localhost:3700 (/handle-packet, /health)\n');

  // Verify SDK health endpoints
  const healthA = await fetch('http://localhost:3600/health').then(r => r.json());
  const healthB = await fetch('http://localhost:3700/health').then(r => r.json());
  console.log(`  Node A health: ${JSON.stringify(healthA)}`);
  console.log(`  Node B health: ${JSON.stringify(healthB)}\n`);

  // --- 8. Wait for BTP peering ---
  // Peers and routes were configured at constructor time.
  // ConnectorB started first so ConnectorA's BTP client connects on startup.
  console.log('Waiting for BTP peering...');
  await new Promise((r) => setTimeout(r, 3000));
  console.log('BTP peers connected.\n');

  // --- 9. Publish: Node A -> Node B ---
  console.log('--- Publish #1: Node A -> Node B (via standalone connectors) ---');
  console.log('  Route: SDK-A --(HTTP)--> ConnectorA --(BTP)--> ConnectorB --(HTTP)--> SDK-B\n');

  const eventAtoB = finalizeEvent({
    kind: 1,
    content: 'Hello from standalone Node A! Packets route via HTTP + BTP.',
    tags: [['mode', 'standalone']],
    created_at: Math.floor(Date.now() / 1000),
  }, identityA.secretKey);

  const resultAtoB = await nodeA.publishEvent(eventAtoB, {
    destination: 'g.toon.standalone.node-b',
  });

  if (resultAtoB.success) {
    console.log(`  Published! Event ID: ${resultAtoB.eventId.slice(0, 24)}...`);
    console.log(`  Fulfillment: ${resultAtoB.fulfillment?.slice(0, 24)}...\n`);
  } else {
    console.log(`  Failed: [${resultAtoB.code}] ${resultAtoB.message}\n`);
  }

  await new Promise((r) => setTimeout(r, 500));

  // --- 10. Publish: Node B -> Node A (reply) ---
  console.log('--- Publish #2: Node B -> Node A (reply) ---\n');

  const eventBtoA = finalizeEvent({
    kind: 1,
    content: 'Reply from standalone Node B! Round-trip via HTTP.',
    tags: [['mode', 'standalone']],
    created_at: Math.floor(Date.now() / 1000),
  }, identityB.secretKey);

  const resultBtoA = await nodeB.publishEvent(eventBtoA, {
    destination: 'g.toon.standalone.node-a',
  });

  if (resultBtoA.success) {
    console.log(`  Published! Event ID: ${resultBtoA.eventId.slice(0, 24)}...`);
    console.log(`  Fulfillment: ${resultBtoA.fulfillment?.slice(0, 24)}...\n`);
  } else {
    console.log(`  Failed: [${resultBtoA.code}] ${resultBtoA.message}\n`);
  }

  await new Promise((r) => setTimeout(r, 500));

  // --- 11. Summary ---
  console.log('=== Summary ===');
  console.log(`  Mode: STANDALONE (HTTP + BTP)`);
  console.log(`  Events received: ${receivedEvents.length}`);
  for (const ev of receivedEvents) {
    console.log(`    Node ${ev.nodeId}: "${ev.content}" (paid ${ev.amount} units)`);
  }
  console.log(`  connector property: ${nodeA.connector}`);  // null in standalone mode

  if (receivedEvents.length === 2) {
    console.log('\n  Bi-directional routing verified via standalone connectors.');
  }

  // --- 12. Cleanup ---
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
