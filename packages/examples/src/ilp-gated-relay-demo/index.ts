/**
 * ILP-Gated Relay Demo
 *
 * This is the main entry point for the demo. It runs:
 * 1. Basic agent demo - payment flow with event verification
 * 2. Self-write bypass demo - owner events skip payment
 *
 * The demo starts its own relay servers, runs the demonstrations,
 * and shuts down cleanly.
 */

import WebSocket from 'ws';
import {
  generateSecretKey,
  getPublicKey,
  finalizeEvent,
} from 'nostr-tools/pure';
import { MockIlpConnector } from './mock-connector.js';
import { startRelay } from './relay.js';

// Server ports
const BLS_PORT = 3100;
const WS_PORT = 7100;
const BLS_URL = `http://localhost:${BLS_PORT}`;
const WS_URL = `ws://localhost:${WS_PORT}`;

/**
 * Verify that an event was stored in the relay.
 */
async function verifyEventStored(
  wsUrl: string,
  eventId: string
): Promise<boolean> {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(wsUrl);
    const subId = `verify-${Date.now()}`;
    let found = false;

    const timeout = setTimeout(() => {
      ws.close();
      reject(new Error('Timeout waiting for relay response'));
    }, 5000);

    ws.on('open', () => {
      ws.send(JSON.stringify(['REQ', subId, { ids: [eventId] }]));
    });

    ws.on('message', (data: Buffer | string) => {
      const msg = JSON.parse(data.toString()) as [string, ...unknown[]];
      if (msg[0] === 'EVENT' && msg[1] === subId) {
        const event = msg[2] as { id: string };
        if (event.id === eventId) {
          found = true;
        }
      }
      if (msg[0] === 'EOSE' && msg[1] === subId) {
        clearTimeout(timeout);
        ws.send(JSON.stringify(['CLOSE', subId]));
        ws.close();
        resolve(found);
      }
    });

    ws.on('error', (error) => {
      clearTimeout(timeout);
      reject(error);
    });
  });
}

/**
 * Run the basic agent demo with payment flow.
 */
async function runBasicDemo(): Promise<void> {
  console.log('\n' + '='.repeat(50));
  console.log('DEMO 1: Basic Payment Flow');
  console.log('='.repeat(50) + '\n');

  // Generate agent keypair
  const secretKey = generateSecretKey();
  const pubkey = getPublicKey(secretKey);
  console.log(`[Agent] Generated keypair`);
  console.log(`[Agent] Pubkey: ${pubkey.slice(0, 16)}...`);

  // Create a signed event
  const event = finalizeEvent(
    {
      kind: 1,
      content: 'Hello from ILP-gated relay demo!',
      tags: [],
      created_at: Math.floor(Date.now() / 1000),
    },
    secretKey
  );
  console.log(`[Agent] Created event: ${event.id.slice(0, 16)}...`);

  // Send payment via mock connector
  const connector = new MockIlpConnector({ blsUrl: BLS_URL });
  const eventJson = JSON.stringify(event);
  const paymentAmount = BigInt(eventJson.length * 10 + 100);
  console.log(`[Agent] Sending payment of ${paymentAmount} units...`);

  const response = await connector.sendPayment(event, paymentAmount);

  if (response.accept) {
    console.log(`[Agent] PAID: Event accepted!`);
    console.log(
      `[Agent] Fulfillment: ${response.fulfillment?.slice(0, 20)}...`
    );
  } else {
    throw new Error(`Payment rejected: ${response.message}`);
  }

  // Verify event stored
  await new Promise((r) => setTimeout(r, 100));
  const stored = await verifyEventStored(WS_URL, event.id);
  if (stored) {
    console.log(`[Agent] Event verified in relay!`);
  } else {
    throw new Error('Event verification failed');
  }
}

/**
 * Demonstrate self-write bypass functionality.
 *
 * This shows that:
 * 1. Owner events are accepted with zero payment
 * 2. Non-owner events are rejected without payment
 * 3. Non-owner events are accepted with sufficient payment
 */
export async function demonstrateSelfWriteBypass(
  ownerSecretKey: Uint8Array,
  _ownerPubkey: string
): Promise<void> {
  console.log('\n' + '='.repeat(50));
  console.log('DEMO 2: Self-Write Bypass');
  console.log('='.repeat(50) + '\n');

  const connector = new MockIlpConnector({ blsUrl: BLS_URL });

  // --- Part A: Owner event with zero payment ---
  console.log('[Demo] Testing owner event with zero payment...');

  const ownerEvent = finalizeEvent(
    {
      kind: 1,
      content: 'Owner event - should bypass payment!',
      tags: [],
      created_at: Math.floor(Date.now() / 1000),
    },
    ownerSecretKey
  );

  // Send with amount = 0 (zero payment)
  const ownerResponse = await connector.sendPayment(ownerEvent, 0n);

  if (ownerResponse.accept) {
    console.log(`[Demo] BYPASS: Owner event accepted with 0 payment`);
    console.log(`[Demo] Event ID: ${ownerEvent.id.slice(0, 16)}...`);
  } else {
    throw new Error(`Owner bypass failed: ${ownerResponse.message}`);
  }

  // Verify owner event stored
  await new Promise((r) => setTimeout(r, 100));
  const ownerStored = await verifyEventStored(WS_URL, ownerEvent.id);
  if (ownerStored) {
    console.log(`[Demo] Owner event verified in relay!`);
  }

  // --- Part B: Non-owner event rejected without payment ---
  console.log('\n[Demo] Testing non-owner event with insufficient payment...');

  // Generate a different keypair (non-owner)
  const nonOwnerSecretKey = generateSecretKey();
  const nonOwnerPubkey = getPublicKey(nonOwnerSecretKey);
  console.log(`[Demo] Non-owner pubkey: ${nonOwnerPubkey.slice(0, 16)}...`);

  const nonOwnerEvent = finalizeEvent(
    {
      kind: 1,
      content: 'Non-owner event - requires payment!',
      tags: [],
      created_at: Math.floor(Date.now() / 1000),
    },
    nonOwnerSecretKey
  );

  // Send with insufficient payment
  const rejectResponse = await connector.sendPayment(nonOwnerEvent, 1n);

  if (!rejectResponse.accept) {
    console.log(
      `[Demo] Non-owner event rejected (insufficient): ${rejectResponse.code}`
    );
    console.log(
      `[Demo] Required: ${(rejectResponse.metadata as { required?: string })?.required}, ` +
        `Received: ${(rejectResponse.metadata as { received?: string })?.received}`
    );
  } else {
    throw new Error('Non-owner event should have been rejected');
  }

  // --- Part C: Non-owner event accepted with payment ---
  console.log('\n[Demo] Testing non-owner event with sufficient payment...');

  const nonOwnerEvent2 = finalizeEvent(
    {
      kind: 1,
      content: 'Non-owner event with proper payment!',
      tags: [],
      created_at: Math.floor(Date.now() / 1000),
    },
    nonOwnerSecretKey
  );

  const eventJson = JSON.stringify(nonOwnerEvent2);
  const paymentAmount = BigInt(eventJson.length * 10 + 100);

  const acceptResponse = await connector.sendPayment(
    nonOwnerEvent2,
    paymentAmount
  );

  if (acceptResponse.accept) {
    console.log(
      `[Demo] PAID: Non-owner event accepted with ${paymentAmount} payment`
    );
    console.log(`[Demo] Event ID: ${nonOwnerEvent2.id.slice(0, 16)}...`);
  } else {
    throw new Error(`Non-owner payment failed: ${acceptResponse.message}`);
  }

  // Verify non-owner event stored
  await new Promise((r) => setTimeout(r, 100));
  const nonOwnerStored = await verifyEventStored(WS_URL, nonOwnerEvent2.id);
  if (nonOwnerStored) {
    console.log(`[Demo] Non-owner event verified in relay!`);
  }
}

/**
 * Main entry point - runs the complete demo.
 */
async function main(): Promise<void> {
  console.log('\n' + '='.repeat(50));
  console.log('ILP-Gated Nostr Relay Demo');
  console.log('='.repeat(50));

  // Generate owner keypair first (needed for relay config)
  const ownerSecretKey = generateSecretKey();
  const ownerPubkey = getPublicKey(ownerSecretKey);
  console.log(`\n[Setup] Owner pubkey: ${ownerPubkey.slice(0, 16)}...`);

  // Start relay with owner pubkey for self-write bypass
  console.log('[Setup] Starting relay servers...\n');
  const servers = await startRelay({
    ownerPubkey,
    basePricePerByte: 10n,
  });

  try {
    // Run basic demo (payment flow)
    await runBasicDemo();

    // Run self-write bypass demo
    await demonstrateSelfWriteBypass(ownerSecretKey, ownerPubkey);

    console.log('\n' + '='.repeat(50));
    console.log('Demo Complete!');
    console.log('='.repeat(50) + '\n');
  } finally {
    // Always shut down servers
    await servers.shutdown();
  }
}

// Run main
main().catch((error) => {
  console.error('\n[Demo] Fatal error:', error);
  process.exit(1);
});
