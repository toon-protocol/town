/**
 * Example 04: Embedded Town — Two Towns with Zero-Latency Connectors
 *
 * Demonstrates running Town nodes in embedded mode: ConnectorNode instances
 * are passed directly to startTown() instead of connecting via HTTP. This
 * eliminates all HTTP overhead for ILP packet delivery.
 *
 * Key differences from Example 02 (standalone mode):
 *   - ConnectorNode uses deploymentMode: 'embedded' (no HTTP admin/health ports)
 *   - startTown() receives { connector: connectorNode } instead of { connectorUrl }
 *   - No localDelivery, adminApi, or healthCheckPort configuration needed
 *   - No startup order issues — connector.setPacketHandler() wires directly
 *
 * Routing topology:
 *   Town A (relay 7400) -> ConnectorA -> ConnectorB -> Town B (relay 7500)
 *
 * Requires: Anvil running on localhost:18545 (via ./scripts/sdk-e2e-infra.sh up)
 *
 * Run: npm run embedded-town
 */

import { startTown, type TownInstance } from '@toon-protocol/town';
import { generateMnemonic, fromMnemonic } from '@toon-protocol/sdk';
import { encodeEventToToon } from '@toon-protocol/core/toon';
import { finalizeEvent } from 'nostr-tools/pure';
import { ConnectorNode } from '@toon-protocol/connector';
import WebSocket from 'ws';
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

/**
 * Wait for a WebSocket endpoint to accept connections.
 */
async function waitForRelay(url: string, timeoutMs = 15000): Promise<void> {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    try {
      await new Promise<void>((resolve, reject) => {
        const ws = new WebSocket(url);
        const timer = setTimeout(() => { ws.close(); reject(new Error('timeout')); }, 2000);
        ws.on('open', () => { clearTimeout(timer); ws.close(); resolve(); });
        ws.on('error', () => { clearTimeout(timer); reject(new Error('failed')); });
      });
      return;
    } catch {
      await new Promise((r) => setTimeout(r, 500));
    }
  }
  throw new Error(`Relay ${url} not ready after ${timeoutMs}ms`);
}

/**
 * Query a relay for events via WebSocket.
 */
async function queryRelay(
  url: string,
  filter: Record<string, unknown>,
  timeoutMs = 10000
): Promise<unknown[]> {
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
            events.push(msg[2]);
          } else if (msg[0] === 'EOSE' && msg[1] === subId) {
            clearTimeout(timer);
            ws.close();
            resolve(events);
          }
        }
      } catch { /* ignore parse errors */ }
    });

    ws.on('error', () => { clearTimeout(timer); resolve(events); });
  });
}

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
  console.log('=== TOON Town: Embedded Mode (Two Towns) ===\n');

  const logger = pino({ level: 'silent' });
  let townA: TownInstance | null = null;
  let townB: TownInstance | null = null;
  let connectorA: ConnectorNode | null = null;
  let connectorB: ConnectorNode | null = null;

  try {
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

    // --- 3. Generate identities ---
    const mnemonicA = generateMnemonic();
    const mnemonicB = generateMnemonic();
    const identityA = fromMnemonic(mnemonicA);

    console.log(`\nTown A mnemonic: ${mnemonicA.split(' ').slice(0, 3).join(' ')}...`);
    console.log(`Town B mnemonic: ${mnemonicB.split(' ').slice(0, 3).join(' ')}...\n`);

    // --- 4. Create embedded connectors ---
    console.log('Creating embedded connectors...');

    const ilpAddressA = `g.toon.embedded.town-a`;
    const ilpAddressB = `g.toon.embedded.town-b`;

    connectorA = new ConnectorNode({
      nodeId: 'embedded-town-a',
      btpServerPort: 4400,
      healthCheckPort: 4480,
      environment: 'development',
      deploymentMode: 'embedded',
      explorer: { enabled: false },
      settlement: { connectorFeePercentage: 0 } as any,
      peers: [{
        id: 'embedded-town-b',
        url: 'ws://localhost:4410',
        authToken: '',
        evmAddress: NODE_B_EVM_ADDRESS,
      }],
      routes: [
        { prefix: ilpAddressA, nextHop: 'local', priority: 0 },
        { prefix: ilpAddressB, nextHop: 'embedded-town-b', priority: 0 },
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

    connectorB = new ConnectorNode({
      nodeId: 'embedded-town-b',
      btpServerPort: 4410,
      healthCheckPort: 4490,
      environment: 'development',
      deploymentMode: 'embedded',
      explorer: { enabled: false },
      settlement: { connectorFeePercentage: 0 } as any,
      peers: [{
        id: 'embedded-town-a',
        url: 'ws://localhost:4400',
        authToken: '',
        evmAddress: NODE_A_EVM_ADDRESS,
      }],
      routes: [
        { prefix: ilpAddressB, nextHop: 'local', priority: 0 },
        { prefix: ilpAddressA, nextHop: 'embedded-town-a', priority: 0 },
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

    await connectorA.start();
    await connectorB.start();
    console.log('  Connector A: embedded, BTP=4400');
    console.log('  Connector B: embedded, BTP=4410\n');

    // Wait for BTP peering
    console.log('Waiting for BTP peering...');
    await new Promise((r) => setTimeout(r, 5000));

    // --- 5. Start Town A in embedded mode ---
    console.log('Starting Town A (embedded, relay 7400, BLS 3400)...');
    townA = await startTown({
      mnemonic: mnemonicA,
      connector: connectorA,     // <-- Embedded mode!
      relayPort: 7400,
      blsPort: 3400,
      ilpAddress: ilpAddressA,
      dataDir: '/tmp/toon-example-embedded-townA',
    });
    console.log(`  Town A started: pubkey=${townA.pubkey.slice(0, 24)}...`);
    console.log(`  ILP address: ${townA.config.ilpAddress}\n`);

    // --- 6. Start Town B in embedded mode ---
    console.log('Starting Town B (embedded, relay 7500, BLS 3500)...');
    townB = await startTown({
      mnemonic: mnemonicB,
      connector: connectorB,     // <-- Embedded mode!
      relayPort: 7500,
      blsPort: 3500,
      ilpAddress: ilpAddressB,
      dataDir: '/tmp/toon-example-embedded-townB',
    });
    console.log(`  Town B started: pubkey=${townB.pubkey.slice(0, 24)}...`);
    console.log(`  ILP address: ${townB.config.ilpAddress}\n`);

    // Wait for relays
    await waitForRelay('ws://localhost:7400');
    await waitForRelay('ws://localhost:7500');

    // --- 7. Publish event from Town A to Town B ---
    console.log('--- Publishing event: Town A -> Town B (zero-latency) ---\n');

    const event = finalizeEvent({
      kind: 1,
      content: `Hello from embedded Town A! Timestamp: ${new Date().toISOString()}`,
      tags: [['mode', 'embedded']],
      created_at: Math.floor(Date.now() / 1000),
    }, identityA.secretKey);

    const toonBytes = encodeEventToToon(event);
    const base64Data = Buffer.from(toonBytes).toString('base64');
    const amount = String(10n * BigInt(toonBytes.length));

    console.log(`  Event ID:     ${event.id.slice(0, 32)}...`);
    console.log(`  Content:      "${event.content}"`);
    console.log(`  TOON size:    ${toonBytes.length} bytes`);
    console.log(`  ILP amount:   ${amount} units`);
    console.log(`  Destination:  ${ilpAddressB}\n`);

    // Send via connector A's sendPacket (direct, no HTTP)
    const result = await connectorA.sendPacket({
      destination: ilpAddressB,
      amount: BigInt(amount),
      data: Buffer.from(base64Data, 'base64'),
      expiresAt: new Date(Date.now() + 30000),
    });

    if (result.type === 'fulfill' || result.type === 13) {
      console.log('  Event delivered to Town B (embedded, zero-latency)!');
      console.log(`  Result type: ${result.type}\n`);
    } else {
      console.log(`  Delivery result: type=${result.type}, code=${(result as { code?: string }).code}\n`);
    }

    await new Promise((r) => setTimeout(r, 1000));

    // --- 8. Read event from Town B's relay ---
    console.log('--- Reading events from Town B relay (ws://localhost:7500) ---\n');
    const events = await queryRelay('ws://localhost:7500', { kinds: [1], limit: 5 });
    console.log(`  Found ${events.length} event(s) on Town B relay`);

    // --- 9. Health checks (BLS server still runs for /health) ---
    console.log('\n--- Health Checks ---\n');
    const healthA = await fetch('http://localhost:3400/health').then(r => r.json());
    const healthB = await fetch('http://localhost:3500/health').then(r => r.json());
    console.log(`  Town A: ${JSON.stringify(healthA)}`);
    console.log(`  Town B: ${JSON.stringify(healthB)}\n`);

    // --- 10. Summary ---
    console.log('=== Summary ===');
    console.log(`  Mode:     EMBEDDED (zero-latency)`);
    console.log(`  Town A:   ${townA.pubkey.slice(0, 24)}... (relay 7400, BLS 3400)`);
    console.log(`  Town B:   ${townB.pubkey.slice(0, 24)}... (relay 7500, BLS 3500)`);
    console.log(`  Routing:  Town A -> ConnectorA --(BTP)--> ConnectorB -> Town B`);
    console.log(`  Events:   ${events.length > 0 ? 'Delivered' : 'Check logs'}`);
    console.log(`\n  No HTTP in the ILP path — packets routed via direct function calls.`);

  } catch (error) {
    console.error('Error:', error);
  } finally {
    console.log('\nStopping towns and connectors...');
    if (townA) await townA.stop();
    if (townB) await townB.stop();
    if (connectorA) await connectorA.stop();
    if (connectorB) await connectorB.stop();
    console.log('Done.');
    process.exit(0);
  }
}

main().catch((err) => {
  console.error('Fatal:', err);
  process.exit(1);
});
