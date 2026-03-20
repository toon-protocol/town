/**
 * Example 02: Create Two SDK Nodes with Embedded Connectors
 *
 * Demonstrates how to create two TOON SDK nodes, each with its own
 * embedded ILP connector. The nodes peer directly with each other via BTP
 * (no external infrastructure needed) and register custom event handlers.
 *
 * Prerequisites: None (fully self-contained)
 *
 * Run: npm run create-node
 */

import { createNode, fromMnemonic, generateMnemonic } from '@toon-protocol/sdk';
import type { ServiceNode } from '@toon-protocol/sdk';
import { ConnectorNode } from '@toon-protocol/connector';
import pino from 'pino';

async function main() {
  console.log('=== TOON SDK: Create Two Nodes ===\n');

  // --- Step 1: Generate identities for both nodes ---
  const mnemonicA = generateMnemonic();
  const mnemonicB = generateMnemonic();
  const identityA = fromMnemonic(mnemonicA);
  const identityB = fromMnemonic(mnemonicB);

  console.log('Node A:');
  console.log(`  Pubkey: ${identityA.pubkey.slice(0, 32)}...`);
  console.log(`  EVM:    ${identityA.evmAddress}\n`);
  console.log('Node B:');
  console.log(`  Pubkey: ${identityB.pubkey.slice(0, 32)}...`);
  console.log(`  EVM:    ${identityB.evmAddress}\n`);

  // --- Step 2: Create embedded connectors ---
  // BTP supports no-auth mode (authToken: '') for development.
  // In production, use a shared secret and set BTP_PEER_{ID}_SECRET env vars.
  const logger = pino({ level: 'warn' });

  const connectorA = new ConnectorNode({
    nodeId: 'example-node-a',
    btpServerPort: 6000,
    healthCheckPort: 6080,
    environment: 'development',
    deploymentMode: 'embedded',
    peers: [{
      id: 'example-node-b',
      url: 'ws://localhost:6010',
      authToken: '',
    }],
    routes: [
      // Local route: deliver packets addressed to THIS node to the SDK handler
      { prefix: 'g.toon.example.node-a', nextHop: 'local', priority: 0 },
      // Remote route: forward packets addressed to node-b via BTP
      { prefix: 'g.toon.example.node-b', nextHop: 'example-node-b', priority: 0 },
    ],
  }, logger);

  const connectorB = new ConnectorNode({
    nodeId: 'example-node-b',
    btpServerPort: 6010,
    healthCheckPort: 6090,
    environment: 'development',
    deploymentMode: 'embedded',
    peers: [{
      id: 'example-node-a',
      url: 'ws://localhost:6000',
      authToken: '',
    }],
    routes: [
      // Local route: deliver packets addressed to THIS node to the SDK handler
      { prefix: 'g.toon.example.node-b', nextHop: 'local', priority: 0 },
      // Remote route: forward packets addressed to node-a via BTP
      { prefix: 'g.toon.example.node-a', nextHop: 'example-node-a', priority: 0 },
    ],
  }, logger);

  // --- Step 3: Create SDK nodes ---
  // createNode() wires the full pipeline:
  //   TOON parse -> Schnorr verification -> pricing -> handler dispatch
  //
  // Both nodes use the same basePricePerByte (10n). Without settlement enabled,
  // the connector does not deduct a routing fee, so both sides use the same rate.
  const nodeA: ServiceNode = createNode({
    secretKey: identityA.secretKey,
    connector: connectorA,
    ilpAddress: 'g.toon.example.node-a',
    basePricePerByte: 10n,
  });

  const nodeB: ServiceNode = createNode({
    secretKey: identityB.secretKey,
    connector: connectorB,
    ilpAddress: 'g.toon.example.node-b',
    basePricePerByte: 10n,
  });

  // --- Step 4: Register event handlers ---
  nodeA.on(1, async (ctx) => {
    const event = ctx.decode();
    console.log(`[Node A] Received kind:1 from ${ctx.pubkey.slice(0, 16)}...`);
    console.log(`[Node A]   Content: "${event.content}"`);
    console.log(`[Node A]   Paid: ${ctx.amount} units`);
    return ctx.accept({ stored: true });
  });

  nodeB.on(1, async (ctx) => {
    const event = ctx.decode();
    console.log(`[Node B] Received kind:1 from ${ctx.pubkey.slice(0, 16)}...`);
    console.log(`[Node B]   Content: "${event.content}"`);
    console.log(`[Node B]   Paid: ${ctx.amount} units`);
    return ctx.accept({ stored: true });
  });

  nodeA.onDefault(async (ctx) => {
    return ctx.reject('F00', `Unsupported event kind: ${ctx.kind}`);
  });

  nodeB.onDefault(async (ctx) => {
    return ctx.reject('F00', `Unsupported event kind: ${ctx.kind}`);
  });

  // --- Step 5: Start connectors and nodes ---
  console.log('Starting connectors...');
  await connectorA.start();
  await connectorB.start();

  // Wait for BTP connections to establish.
  // Connector A starts first and its outbound to B may fail initially.
  // Once B starts, B's outbound to A should connect.
  console.log('Waiting for BTP peering to establish...');
  await new Promise((r) => setTimeout(r, 5000));

  console.log('Starting SDK nodes...');
  const resultA = await nodeA.start();
  const resultB = await nodeB.start();

  console.log(`\nNode A started: ${resultA.peerCount} peers, ${resultA.channelCount} channels`);
  console.log(`Node B started: ${resultB.peerCount} peers, ${resultB.channelCount} channels`);

  // --- Step 6: Show the topology ---
  console.log('\nTopology (direct peering, no external infra):');
  console.log('  Node A (g.toon.example.node-a)');
  console.log('    |-- BTP (ws://localhost:6010) --> Node B');
  console.log('  Node B (g.toon.example.node-b)');
  console.log('    |-- BTP (ws://localhost:6000) --> Node A');
  console.log('\n  Events route directly: A <-> B');

  // --- Cleanup ---
  console.log('\nStopping nodes...');
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
