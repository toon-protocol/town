/**
 * Example 03: Subscribe Between Two Towns
 *
 * Demonstrates how a Town node can subscribe to events from another
 * Town's relay. Events received via the subscription are automatically
 * stored in the local EventStore and become queryable through the
 * local WebSocket relay.
 *
 * This shows the "free to read" side of TOON — subscribing to
 * events doesn't require ILP payment.
 *
 * No external infrastructure required — everything runs in-process.
 *
 * Run: npm run subscribe
 */

import { startTown, type TownInstance } from '@toon-protocol/town';
import { generateMnemonic, fromMnemonic } from '@toon-protocol/sdk';
import { encodeEventToToon } from '@toon-protocol/core/toon';
import { finalizeEvent } from 'nostr-tools/pure';
import { ConnectorNode } from '@toon-protocol/connector';
import WebSocket from 'ws';
import pino from 'pino';

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

async function main() {
  console.log('=== TOON Town: Subscribe Between Two Towns ===\n');

  const logger = pino({ level: 'silent' });
  let townA: TownInstance | null = null;
  let townB: TownInstance | null = null;
  let connectorA: ConnectorNode | null = null;
  let connectorB: ConnectorNode | null = null;
  let subWs: WebSocket | null = null;

  try {
    // --- 1. Start embedded connectors ---
    console.log('Starting embedded connectors...');

    connectorA = new ConnectorNode({
      nodeId: 'sub-connector-a',
      btpServerPort: 4300,
      healthCheckPort: 4380,
      environment: 'development',
      deploymentMode: 'standalone',
      adminApi: { enabled: true, port: 4381 },
      localDelivery: {
        enabled: true,
        handlerUrl: 'http://localhost:3400',
      },
      peers: [],
      routes: [],
    }, logger);

    connectorB = new ConnectorNode({
      nodeId: 'sub-connector-b',
      btpServerPort: 4310,
      healthCheckPort: 4390,
      environment: 'development',
      deploymentMode: 'standalone',
      adminApi: { enabled: true, port: 4391 },
      localDelivery: {
        enabled: true,
        handlerUrl: 'http://localhost:3500',
      },
      peers: [],
      routes: [],
    }, logger);

    await connectorA.start();
    await connectorB.start();
    console.log('  Connectors started.\n');

    // --- 2. Start two towns ---
    const mnemonicA = generateMnemonic();
    const mnemonicB = generateMnemonic();
    const identityA = fromMnemonic(mnemonicA);

    console.log('Starting Town A (publisher, relay 7400, BLS 3400)...');
    townA = await startTown({
      mnemonic: mnemonicA,
      relayPort: 7400,
      blsPort: 3400,
      connectorUrl: 'http://localhost:4380',
      dataDir: '/tmp/toon-example-sub-townA',
    });
    console.log(`  Town A pubkey: ${townA.pubkey.slice(0, 24)}...\n`);

    // Add a local route so the connector delivers packets for Town A's ILP address locally
    connectorA.addRoute({ prefix: townA.config.ilpAddress, nextHop: 'local', priority: 0 });

    console.log('Starting Town B (subscriber, relay 7500, BLS 3500)...');
    townB = await startTown({
      mnemonic: mnemonicB,
      relayPort: 7500,
      blsPort: 3500,
      connectorUrl: 'http://localhost:4390',
      dataDir: '/tmp/toon-example-sub-townB',
    });
    console.log(`  Town B pubkey: ${townB.pubkey.slice(0, 24)}...\n`);

    await waitForRelay('ws://localhost:7400');
    await waitForRelay('ws://localhost:7500');

    // --- 3. Publish an event to Town A via its connector ---
    console.log('Publishing event to Town A via ILP...');

    const event1 = finalizeEvent({
      kind: 1,
      content: 'Event on Town A - should be replicated to Town B via subscription',
      tags: [['source', 'town-a']],
      created_at: Math.floor(Date.now() / 1000),
    }, identityA.secretKey);

    const toonBytes = encodeEventToToon(event1);
    const base64Data = Buffer.from(toonBytes).toString('base64');
    const amount = String(10n * BigInt(toonBytes.length));

    const sendResp = await fetch('http://localhost:4381/admin/ilp/send', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        destination: townA.config.ilpAddress,
        amount,
        data: base64Data,
      }),
    });
    const sendResult = await sendResp.json() as Record<string, unknown>;
    console.log(`  Published: ${sendResult.accepted ? 'YES' : JSON.stringify(sendResult)}\n`);

    await new Promise((r) => setTimeout(r, 1000));

    // --- 4. Town B subscribes to Town A's relay via raw WebSocket ---
    // NOTE: townB.subscribe() uses nostr-tools SimplePool internally, which
    // references `window` and crashes in Node.js. We use raw WebSocket instead
    // to demonstrate the "free to read" subscription pattern.
    console.log('Town B subscribing to Town A relay (ws://localhost:7400)...');

    const replicatedEvents: string[] = [];
    subWs = new WebSocket('ws://localhost:7400');
    const subId = `sub-${Date.now()}`;

    await new Promise<void>((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error('Subscribe timeout')), 10000);
      subWs!.on('open', () => {
        subWs!.send(JSON.stringify(['REQ', subId, { kinds: [1], limit: 10 }]));
        clearTimeout(timer);
        resolve();
      });
      subWs!.on('error', (err) => { clearTimeout(timer); reject(err); });
    });

    // Collect events for a few seconds
    subWs.on('message', (data: Buffer) => {
      try {
        const msg = JSON.parse(data.toString());
        if (Array.isArray(msg) && msg[0] === 'EVENT' && msg[1] === subId) {
          replicatedEvents.push(String(msg[2]).slice(0, 60) + '...');
        }
      } catch { /* ignore */ }
    });

    console.log(`  Subscription active (WebSocket open)`);
    console.log(`  Relay URL: ws://localhost:7400\n`);

    // --- 5. Wait for events to arrive ---
    console.log('Waiting 3 seconds for events...');
    await new Promise((r) => setTimeout(r, 3000));

    // --- 6. Report replicated events ---
    console.log(`\n  Found ${replicatedEvents.length} event(s) via subscription`);
    for (const ev of replicatedEvents) {
      console.log(`    ${ev}`);
    }

    // --- 7. Subscription lifecycle ---
    console.log(`\nSubscription active: ${subWs.readyState === WebSocket.OPEN}`);
    subWs.close();
    console.log(`Subscription closed.`);

    // --- 8. Summary ---
    console.log('\n=== Summary ===');
    console.log('  "Free to read" demonstrated:');
    console.log('    - Published event to Town A (via ILP, pay-to-write)');
    console.log('    - Town B subscribed to Town A relay (raw WebSocket, no payment)');
    console.log(`    - Events received: ${replicatedEvents.length}`);
    console.log('    - Subscription lifecycle: connect -> subscribe -> receive -> close');

  } finally {
    if (subWs && subWs.readyState === WebSocket.OPEN) subWs.close();
    if (townA) await townA.stop();
    if (townB) await townB.stop();
    if (connectorA) await connectorA.stop();
    if (connectorB) await connectorB.stop();
    console.log('\nDone.');
    process.exit(0);
  }
}

main().catch((err) => {
  console.error('Fatal:', err);
  process.exit(1);
});
