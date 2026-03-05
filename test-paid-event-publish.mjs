#!/usr/bin/env node
/**
 * Test publishing a paid event via ILP
 *
 * Flow:
 * 1. Create a signed Nostr event
 * 2. Encode it in TOON format (base64)
 * 3. Use peer1's connector to send an ILP packet to genesis
 * 4. Genesis BLS validates payment and stores the event
 * 5. Query the event back from genesis relay
 */

import { getPublicKey, finalizeEvent } from 'nostr-tools/pure';
import { hexToBytes } from 'nostr-tools/utils';
import WebSocket from 'ws';
import { encode as toonEncode, decode as toonDecode } from '@toon-format/toon';

// Peer1's secret key (from deploy script)
const PEER1_SECRET =
  '97540d8331784dbe8e452d569f6423a2898ed2c90e6da32d809162180ea16c0e';
const GENESIS_RELAY_WS = 'ws://localhost:7100';
const GENESIS_ILP_ADDRESS = 'g.crosstown.genesis';

console.log('🧪 Testing Paid Event Publishing via ILP\n');

// Step 1: Create a signed Nostr event
console.log('1️⃣  Creating signed Nostr event...');
const secretBytes = hexToBytes(PEER1_SECRET);
const pubkey = getPublicKey(secretBytes);

const event = finalizeEvent(
  {
    kind: 1,
    created_at: Math.floor(Date.now() / 1000),
    tags: [],
    content: `Test paid event published via ILP at ${new Date().toISOString()}`,
  },
  secretBytes
);

console.log(`   Event ID: ${event.id.slice(0, 16)}...`);
console.log(`   Pubkey: ${event.pubkey.slice(0, 16)}...`);
console.log(`   Content: "${event.content}"\n`);

// Step 2: Encode in TOON format
console.log('2️⃣  Encoding event in TOON format...');
const toonString = toonEncode(event);
const toonBytes = new TextEncoder().encode(toonString);
const eventBase64 = Buffer.from(toonBytes).toString('base64');
console.log(`   TOON string length: ${toonString.length} chars`);
console.log(`   TOON bytes: ${toonBytes.length} bytes`);
console.log(`   Base64 length: ${eventBase64.length} bytes\n`);

// Step 3: Send ILP packet to genesis BLS
// Note: In production, the connector routes packets and calls /handle-packet
// For testing, we'll send directly to the BLS /handle-packet endpoint

console.log('3️⃣  Sending ILP packet to genesis BLS...');
console.log(`   From: g.crosstown.peer1`);
console.log(`   To: ${GENESIS_ILP_ADDRESS}`);
console.log(`   Amount: 5000 units (minimum SPSP price)\n`);

// Construct HandlePacketRequest
const packetRequest = {
  amount: '5000',
  destination: GENESIS_ILP_ADDRESS,
  data: eventBase64,
  sourceAccount: 'g.crosstown.peer1',
};

try {
  const response = await fetch('http://localhost:3100/handle-packet', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(packetRequest),
  });

  const result = await response.json();

  if (!response.ok || !result.accept) {
    console.error(`❌ Packet rejected by BLS`);
    console.error(`   Code: ${result.code}`);
    console.error(`   Message: ${result.message}`);
    process.exit(1);
  }

  console.log('✅ ILP packet accepted by BLS');
  console.log(`   Fulfill code: ${result.code}`);
  console.log(`   Message: ${result.message || 'Event stored'}`);
} catch (error) {
  console.error(`❌ Error sending ILP packet:`, error.message);
  process.exit(1);
}

// Step 4: Wait a moment for the event to be stored
console.log('\n4️⃣  Waiting for event to be stored...');
await new Promise((resolve) => setTimeout(resolve, 2000));

// Step 5: Query the event from genesis relay
console.log('\n5️⃣  Querying event from genesis relay...');

const ws = new WebSocket(GENESIS_RELAY_WS);

ws.on('open', () => {
  console.log('   Connected to relay');

  // Subscribe to the event we just published
  const subscription = JSON.stringify(['REQ', 'test-sub', { ids: [event.id] }]);

  console.log(`   Requesting event: ${event.id.slice(0, 16)}...`);
  ws.send(subscription);
});

let eventReceived = false;

ws.on('message', (data) => {
  const msg = JSON.parse(data.toString());

  if (msg[0] === 'EVENT') {
    // The relay returns events in TOON format (as a string)
    const toonString = msg[2];

    try {
      // Decode TOON string to event object
      const receivedEvent = toonDecode(toonString);

      console.log('\n✅ Event retrieved from relay!');
      console.log(`   ID: ${receivedEvent.id}`);
      console.log(`   Content: "${receivedEvent.content}"`);
      console.log(`   Pubkey: ${receivedEvent.pubkey.slice(0, 16)}...`);
      console.log(`   Signature: ${receivedEvent.sig.slice(0, 16)}...`);
      console.log(
        `   Matches sent event: ${receivedEvent.id === event.id ? 'YES' : 'NO'}`
      );
      eventReceived = true;
    } catch (error) {
      console.error('   ERROR decoding TOON:', error.message);
    }
  } else if (msg[0] === 'EOSE') {
    if (eventReceived) {
      console.log(
        '\n🎉 SUCCESS! Paid event was published and stored via ILP payment'
      );
    } else {
      console.log(
        '\n❌ Event not found in relay (payment may have been rejected)'
      );
    }
    ws.close();
  } else if (msg[0] === 'NOTICE') {
    console.log(`   Notice: ${msg[1]}`);
  }
});

ws.on('error', (error) => {
  console.error(`❌ WebSocket error:`, error.message);
  process.exit(1);
});

ws.on('close', () => {
  console.log('\n✨ Test complete');
  process.exit(eventReceived ? 0 : 1);
});

// Timeout after 10 seconds
setTimeout(() => {
  console.log('\n❌ Test timeout');
  ws.close();
  process.exit(1);
}, 10000);
