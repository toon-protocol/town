/**
 * Example 01: Start a Town Node with Embedded Connector
 *
 * Demonstrates starting a complete TOON relay node using startTown()
 * with an embedded ILP connector. A single setup spins up:
 *   - An embedded ILP connector (packet routing + admin API)
 *   - A WebSocket Nostr relay (NIP-01 compatible)
 *   - A BLS HTTP server (health check + ILP packet handler)
 *   - SQLite event storage
 *
 * No external infrastructure required — everything runs in-process.
 *
 * Run: npm run start-town
 */

import { startTown } from '@toon-protocol/town';
import { ConnectorNode } from '@toon-protocol/connector';
import pino from 'pino';

async function main() {
  console.log('=== TOON Town: Start a Relay Node ===\n');

  const logger = pino({ level: 'silent' });

  // --- Step 1: Start an embedded connector ---
  // The Town connects to a connector via HTTP. We run one in-process.
  // handlerUrl tells the connector where to POST incoming ILP packets.
  console.log('Starting embedded connector...');
  const connector = new ConnectorNode({
    nodeId: 'town-connector',
    btpServerPort: 4000,
    healthCheckPort: 4080,
    environment: 'development',
    deploymentMode: 'standalone',
    adminApi: { enabled: true, port: 4081 },
    localDelivery: {
      enabled: true,
      handlerUrl: 'http://localhost:3200',
    },
    peers: [],
    routes: [],
  }, logger);

  await connector.start();
  console.log('  Connector running (health: 4080, admin: 4081, BTP: 4000)\n');

  // --- Step 2: Start the Town ---
  console.log('Starting town node...');

  const town = await startTown({
    mnemonic: 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
    relayPort: 7200,
    blsPort: 3200,
    connectorUrl: 'http://localhost:4080',
    dataDir: '/tmp/toon-example-town-01',
  });

  console.log('\nTown node started!');
  console.log(`  Nostr pubkey:  ${town.pubkey}`);
  console.log(`  EVM address:   ${town.evmAddress}`);
  console.log(`  Relay:         ws://localhost:${town.config.relayPort}`);
  console.log(`  BLS health:    http://localhost:${town.config.blsPort}/health`);
  console.log(`  ILP address:   ${town.config.ilpAddress}`);
  console.log(`  Peers found:   ${town.bootstrapResult.peerCount}`);
  console.log(`  Channels:      ${town.bootstrapResult.channelCount}`);

  // --- Step 3: Verify health ---
  const healthResp = await fetch(`http://localhost:${town.config.blsPort}/health`);
  const health = await healthResp.json();
  console.log(`\nHealth check: ${JSON.stringify(health, null, 2)}`);

  // --- Step 4: Run briefly, then stop ---
  console.log('\nRelay is running. Shutting down in 3 seconds...');
  await new Promise((r) => setTimeout(r, 3000));

  // --- Step 5: Graceful shutdown ---
  console.log('\nStopping town...');
  await town.stop();
  console.log(`Running after stop: ${town.isRunning()}`);

  await connector.stop();
  console.log('Connector stopped.');
  console.log('Done.');
  process.exit(0);
}

main().catch((err) => {
  console.error('Fatal:', err);
  process.exit(1);
});
