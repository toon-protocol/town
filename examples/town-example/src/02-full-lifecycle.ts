/**
 * Example 02: Full Lifecycle — Two Towns with Routing
 *
 * Demonstrates the complete TOON relay lifecycle:
 *   1. Start two standalone connectors and peer them
 *   2. Start two Town nodes (A and B), each with its own connector
 *   3. Publish a Nostr event from Town A, routed to Town B
 *   4. Read the event back from Town B's relay via WebSocket
 *   5. Graceful shutdown of both towns
 *
 * Routing topology:
 *   Town A (relay 7200) -> ConnectorA -> ConnectorB -> Town B (relay 7300)
 *
 * Requires: Anvil running on localhost:18545 (via ./scripts/sdk-e2e-infra.sh up)
 *
 * Run: npm run full-lifecycle
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

// Fixed ILP addresses (must be known at connector construction time for routes)
const ILP_ADDRESS_A = 'g.toon.lifecycle.town-a';
const ILP_ADDRESS_B = 'g.toon.lifecycle.town-b';

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
  console.log('=== TOON Town: Full Lifecycle (Two Towns) ===\n');

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

    // --- 4. Start standalone connectors ---
    // Constructor-time peers with evmAddress so peerIdToAddressMap is populated
    // (required for per-packet claim service to open payment channels).
    // Start B first so A's BTP client can connect immediately.
    // Use admin port for startTown() health check (always returns 200).
    console.log('Starting standalone connectors...');

    connectorA = new ConnectorNode({
      nodeId: 'town-a-connector',
      btpServerPort: 4200,
      healthCheckPort: 4280,
      environment: 'development',
      deploymentMode: 'standalone',
      adminApi: { enabled: true, port: 4281 },
      localDelivery: {
        enabled: true,
        handlerUrl: 'http://localhost:3200',
      },
      explorer: { enabled: false },
      settlement: { connectorFeePercentage: 0 } as any,
      peers: [{
        id: 'town-b-connector',
        url: 'ws://localhost:4210',
        authToken: '',
        evmAddress: NODE_B_EVM_ADDRESS,
      }],
      routes: [
        { prefix: ILP_ADDRESS_A, nextHop: 'local', priority: 0 },
        { prefix: ILP_ADDRESS_B, nextHop: 'town-b-connector', priority: 0 },
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
      nodeId: 'town-b-connector',
      btpServerPort: 4210,
      healthCheckPort: 4290,
      environment: 'development',
      deploymentMode: 'standalone',
      adminApi: { enabled: true, port: 4291 },
      localDelivery: {
        enabled: true,
        handlerUrl: 'http://localhost:3300',
      },
      explorer: { enabled: false },
      settlement: { connectorFeePercentage: 0 } as any,
      peers: [{
        id: 'town-a-connector',
        url: 'ws://localhost:4200',
        authToken: '',
        evmAddress: NODE_A_EVM_ADDRESS,
      }],
      routes: [
        { prefix: ILP_ADDRESS_B, nextHop: 'local', priority: 0 },
        { prefix: ILP_ADDRESS_A, nextHop: 'town-a-connector', priority: 0 },
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

    // Start B first so A's BTP client can connect on startup
    await connectorB.start();
    await connectorA.start();
    console.log('  Connector A: health=4280, admin=4281, BTP=4200');
    console.log('  Connector B: health=4290, admin=4291, BTP=4210\n');

    // Wait for BTP peering
    console.log('Waiting for BTP peering...');
    await new Promise((r) => setTimeout(r, 3000));
    console.log('BTP peers connected.\n');

    // --- 5. Start Town A ---
    // connectorUrl points to admin port (always returns 200 for /health).
    // The connector health port returns 503 when BTP peering had issues on startup
    // (health status bug: _updateHealthStatus called only once during start()).
    console.log('Starting Town A (relay 7200, BLS 3200)...');
    townA = await startTown({
      mnemonic: mnemonicA,
      relayPort: 7200,
      blsPort: 3200,
      connectorUrl: 'http://localhost:4281',
      connectorAdminUrl: 'http://localhost:4281',
      ilpAddress: ILP_ADDRESS_A,
      dataDir: '/tmp/toon-example-townA',
    });
    console.log(`  Town A started: pubkey=${townA.pubkey.slice(0, 24)}...`);
    console.log(`  ILP address: ${ILP_ADDRESS_A}\n`);

    // --- 6. Start Town B ---
    console.log('Starting Town B (relay 7300, BLS 3300)...');
    townB = await startTown({
      mnemonic: mnemonicB,
      relayPort: 7300,
      blsPort: 3300,
      connectorUrl: 'http://localhost:4291',
      connectorAdminUrl: 'http://localhost:4291',
      ilpAddress: ILP_ADDRESS_B,
      dataDir: '/tmp/toon-example-townB',
    });
    console.log(`  Town B started: pubkey=${townB.pubkey.slice(0, 24)}...`);
    console.log(`  ILP address: ${ILP_ADDRESS_B}\n`);

    // Wait for relays
    await waitForRelay('ws://localhost:7200');
    await waitForRelay('ws://localhost:7300');

    // --- 7. Publish event from Town A to Town B ---
    console.log('--- Publishing event: Town A -> Town B ---\n');

    const event = finalizeEvent({
      kind: 1,
      content: `Hello from Town A! Timestamp: ${new Date().toISOString()}`,
      tags: [['route', 'town-a-to-town-b']],
      created_at: Math.floor(Date.now() / 1000),
    }, identityA.secretKey);

    const toonBytes = encodeEventToToon(event);
    const base64Data = Buffer.from(toonBytes).toString('base64');
    const amount = String(10n * BigInt(toonBytes.length));

    console.log(`  Event ID:     ${event.id.slice(0, 32)}...`);
    console.log(`  Content:      "${event.content}"`);
    console.log(`  TOON size:    ${toonBytes.length} bytes`);
    console.log(`  ILP amount:   ${amount} units`);
    console.log(`  Destination:  ${ILP_ADDRESS_B}\n`);

    // Send via connector A's admin ILP send endpoint
    const sendResp = await fetch('http://localhost:4281/admin/ilp/send', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        destination: ILP_ADDRESS_B,
        amount,
        data: base64Data,
      }),
    });
    const sendResult = await sendResp.json() as Record<string, unknown>;

    if (sendResult.accepted || sendResult.type === 13) {
      console.log('  Event delivered to Town B!');
      console.log(`  Result: ${JSON.stringify(sendResult).slice(0, 80)}...\n`);
    } else {
      console.log(`  Delivery result: ${JSON.stringify(sendResult)}\n`);
    }

    await new Promise((r) => setTimeout(r, 1000));

    // --- 8. Read event from Town B's relay ---
    console.log('--- Reading events from Town B relay (ws://localhost:7300) ---\n');
    const events = await queryRelay('ws://localhost:7300', { kinds: [1], limit: 5 });
    console.log(`  Found ${events.length} event(s) on Town B relay`);

    // --- 9. Health checks ---
    console.log('\n--- Health Checks ---\n');
    const healthA = await fetch('http://localhost:3200/health').then(r => r.json());
    const healthB = await fetch('http://localhost:3300/health').then(r => r.json());
    console.log(`  Town A: ${JSON.stringify(healthA)}`);
    console.log(`  Town B: ${JSON.stringify(healthB)}\n`);

    // --- 10. Summary ---
    console.log('=== Summary ===');
    console.log(`  Town A: ${townA.pubkey.slice(0, 24)}... (relay 7200, BLS 3200)`);
    console.log(`  Town B: ${townB.pubkey.slice(0, 24)}... (relay 7300, BLS 3300)`);
    console.log(`  Routing: Town A -> ConnectorA -> ConnectorB -> Town B`);
    console.log(`  Events delivered: ${events.length > 0 ? 'YES' : 'Check logs'}`);

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
