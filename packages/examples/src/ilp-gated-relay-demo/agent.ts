/**
 * Agent Client Demo
 *
 * Demonstrates the complete agent interaction flow with an ILP-gated relay:
 * 1. Generate or load Nostr keypair
 * 2. Create and sign a Nostr event
 * 3. Pay to store the event via mock ILP connector
 * 4. Verify the event was stored by querying the relay
 */

import WebSocket from 'ws';
import {
  generateSecretKey,
  getPublicKey,
  finalizeEvent,
} from 'nostr-tools/pure';
import { MockIlpConnector, type BlsResponse } from './mock-connector.js';

// Server ports matching relay.ts defaults
const BLS_PORT = 3100;
const WS_PORT = 7100;
const BLS_URL = `http://localhost:${BLS_PORT}`;
const WS_URL = `ws://localhost:${WS_PORT}`;

/**
 * Verify that an event was stored in the relay by querying via WebSocket.
 *
 * This connects to the relay, sends a NIP-01 REQ message filtering by event ID,
 * and waits for either an EVENT message (found) or EOSE (not found).
 *
 * @param wsUrl - WebSocket URL of the relay
 * @param eventId - The event ID to search for
 * @returns true if event was found, false otherwise
 */
async function verifyEventStored(
  wsUrl: string,
  eventId: string
): Promise<boolean> {
  return new Promise((resolve, reject) => {
    // Create WebSocket connection to relay
    const ws = new WebSocket(wsUrl);
    const subId = `verify-${Date.now()}`;
    let found = false;

    // Set a timeout in case the relay doesn't respond
    const timeout = setTimeout(() => {
      ws.close();
      reject(new Error('Timeout waiting for relay response'));
    }, 5000);

    ws.on('open', () => {
      // Send NIP-01 REQ message with filter for specific event ID
      // Format: ["REQ", <subscription_id>, <filters>...]
      const req = JSON.stringify(['REQ', subId, { ids: [eventId] }]);
      ws.send(req);
    });

    ws.on('message', (data: Buffer | string) => {
      const msg = JSON.parse(data.toString()) as [string, ...unknown[]];

      // Check for EVENT message matching our subscription and event ID
      if (msg[0] === 'EVENT' && msg[1] === subId) {
        const event = msg[2] as { id: string };
        if (event.id === eventId) {
          found = true;
        }
      }

      // EOSE (End of Stored Events) signals the query is complete
      if (msg[0] === 'EOSE' && msg[1] === subId) {
        clearTimeout(timeout);
        // Send CLOSE to clean up subscription
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
 * Run the main agent demo flow.
 *
 * This demonstrates:
 * - Keypair generation
 * - Event creation and signing
 * - Payment via mock connector
 * - Event verification via WebSocket
 */
export async function runAgentDemo(): Promise<{
  secretKey: Uint8Array;
  pubkey: string;
  eventId: string;
}> {
  console.log('\n=== Agent Demo ===\n');

  // Step 1: Generate Nostr keypair for agent identity
  // In production, you would load this from secure storage
  const secretKey = generateSecretKey();
  const pubkey = getPublicKey(secretKey);
  console.log(`[Agent] Generated keypair`);
  console.log(`[Agent] Pubkey: ${pubkey.slice(0, 16)}...`);

  // Step 2: Create a signed Nostr event (kind:1 = text note)
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

  // Step 3: Create mock connector and send payment with event
  const connector = new MockIlpConnector({ blsUrl: BLS_URL });

  // Calculate a reasonable payment amount (event size * 10 units/byte + margin)
  const eventJson = JSON.stringify(event);
  const estimatedPrice = BigInt(eventJson.length * 10 + 100);
  console.log(`[Agent] Sending payment of ${estimatedPrice} units...`);

  const response: BlsResponse = await connector.sendPayment(
    event,
    estimatedPrice
  );

  if (response.accept) {
    console.log(`[Agent] Payment accepted!`);
    console.log(
      `[Agent] Fulfillment: ${response.fulfillment?.slice(0, 20)}...`
    );
    console.log(
      `[Agent] Event ID: ${(response.metadata as { eventId: string })?.eventId}`
    );
  } else {
    console.error(`[Agent] Payment rejected!`);
    console.error(`[Agent] Error: ${response.code} - ${response.message}`);
    throw new Error(`Payment rejected: ${response.message}`);
  }

  // Step 4: Verify the event was stored by querying the relay
  console.log(`[Agent] Verifying event stored...`);

  // Small delay to ensure event is queryable
  await new Promise((r) => setTimeout(r, 100));

  const stored = await verifyEventStored(WS_URL, event.id);

  if (stored) {
    console.log(`[Agent] Event verified in relay!`);
  } else {
    console.error(`[Agent] Event NOT found in relay!`);
    throw new Error('Event verification failed');
  }

  return { secretKey, pubkey, eventId: event.id };
}

/**
 * Main entry point when running agent.ts directly.
 */
async function main(): Promise<void> {
  console.log('[Agent] Starting agent demo...');
  console.log(
    '[Agent] Note: Relay must be running on ports 3000 (BLS) and 7000 (WS)\n'
  );

  try {
    await runAgentDemo();
    console.log('\n[Agent] Demo completed successfully!');
  } catch (error) {
    console.error('\n[Agent] Demo failed:', error);
    process.exit(1);
  }
}

// Run main if this file is executed directly
const isMain =
  typeof process !== 'undefined' &&
  process.argv[1] &&
  import.meta.url.endsWith(process.argv[1].replace(/\\/g, '/'));

if (isMain) {
  main();
}
