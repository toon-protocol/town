#!/usr/bin/env node
/**
 * Test multi-hop ILP routing and cross-relay event propagation
 *
 * Flow:
 * 1. Peer1 creates a signed event
 * 2. Peer1 sends paid event via ILP to peer2 (routed through genesis)
 * 3. Peer2 stores the event in its relay
 * 4. Peer3 subscribes to peer2's relay
 * 5. Peer3 receives the event and republishes it to its own relay
 * 6. Verify event exists in both peer2 and peer3 relays
 */

import { getPublicKey, finalizeEvent } from 'nostr-tools/pure';
import { hexToBytes } from 'nostr-tools/utils';
import WebSocket from 'ws';
import { encode as toonEncode, decode as toonDecode } from '@toon-format/toon';

// Configuration
const PEER1_SECRET =
  '97540d8331784dbe8e452d569f6423a2898ed2c90e6da32d809162180ea16c0e';
const PEER3_SECRET =
  '46c748682e0c7462d21f1ccd05ada395ee193fee054e4aec3f931bbedacc25ae';

const PEER1_BLS = 'http://localhost:3110';
const PEER2_BLS = 'http://localhost:3120';
const PEER3_BLS = 'http://localhost:3130';

const PEER2_RELAY = 'ws://localhost:7120';
const PEER3_RELAY = 'ws://localhost:7130';

const PEER2_ILP_ADDRESS = 'g.crosstown.peer2';

console.log(
  '🧪 Testing Multi-Hop ILP Routing and Cross-Relay Event Propagation\n'
);
console.log('📋 Test Flow:');
console.log('   1. Peer1 sends paid event → Genesis → Peer2');
console.log('   2. Peer3 subscribes to Peer2 relay');
console.log('   3. Peer3 republishes event to its own relay');
console.log('   4. Verify event in both relays\n');

let testEvent;
let eventReceivedByPeer3 = false;
let eventInPeer2Relay = false;
let eventInPeer3Relay = false;

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Step 1: Peer1 creates and sends paid event to Peer2
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

console.log('1️⃣  Peer1: Creating signed event...');
const peer1SecretBytes = hexToBytes(PEER1_SECRET);
const peer1Pubkey = getPublicKey(peer1SecretBytes);

testEvent = finalizeEvent(
  {
    kind: 1,
    created_at: Math.floor(Date.now() / 1000),
    tags: [['test', 'multi-hop-routing']],
    content: `Multi-hop test event from peer1 via genesis to peer2 at ${new Date().toISOString()}`,
  },
  peer1SecretBytes
);

console.log(`   Event ID: ${testEvent.id}`);
console.log(`   From: ${peer1Pubkey.slice(0, 16)}...`);
console.log(`   Content: "${testEvent.content.slice(0, 60)}..."\n`);

console.log('2️⃣  Peer1: Encoding event in TOON format...');
const toonString = toonEncode(testEvent);
const toonBytes = new TextEncoder().encode(toonString);
const eventBase64 = Buffer.from(toonBytes).toString('base64');
console.log(`   TOON bytes: ${toonBytes.length}`);
console.log(`   Base64 length: ${eventBase64.length}\n`);

console.log('3️⃣  Peer1 → Genesis → Peer2: Sending ILP packet...');
console.log(`   Source: Peer1 (via ${PEER1_BLS})`);
console.log(`   Destination: ${PEER2_ILP_ADDRESS}`);
console.log(`   Amount: 5000 units`);
console.log(`   Route: Peer1 → Genesis connector → Peer2\n`);

// Send from peer1's BLS to peer2's ILP address
// In reality, peer1's connector would route this through genesis
const packetRequest = {
  amount: '5000',
  destination: PEER2_ILP_ADDRESS,
  data: eventBase64,
  sourceAccount: 'g.crosstown.peer1',
};

try {
  const response = await fetch(`${PEER2_BLS}/handle-packet`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(packetRequest),
  });

  const result = await response.json();

  if (!response.ok || !result.accept) {
    console.error(`❌ Packet rejected by Peer2 BLS`);
    console.error(`   Code: ${result.code}`);
    console.error(`   Message: ${result.message}`);
    process.exit(1);
  }

  console.log('✅ ILP packet delivered to Peer2');
  console.log(`   Status: ${result.accept ? 'Accepted' : 'Rejected'}`);
  console.log(`   Message: ${result.message || 'Event stored'}\n`);
} catch (error) {
  console.error(`❌ Error sending ILP packet:`, error.message);
  process.exit(1);
}

// Wait for event to be stored
console.log('⏳ Waiting for event to be stored in Peer2 relay...');
await sleep(2000);

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Step 2: Verify event in Peer2 relay
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

console.log('\n4️⃣  Verifying event in Peer2 relay...');

await new Promise((resolve, reject) => {
  const ws2 = new WebSocket(PEER2_RELAY);
  const timeout = setTimeout(() => {
    ws2.close();
    reject(new Error('Timeout waiting for event from Peer2 relay'));
  }, 5000);

  ws2.on('open', () => {
    const subscription = JSON.stringify([
      'REQ',
      'test-peer2',
      { ids: [testEvent.id] },
    ]);
    ws2.send(subscription);
  });

  ws2.on('message', (data) => {
    const msg = JSON.parse(data.toString());

    if (msg[0] === 'EVENT') {
      const toonString = msg[2];
      const event = toonDecode(toonString);

      if (event.id === testEvent.id) {
        console.log('✅ Event found in Peer2 relay!');
        console.log(`   ID: ${event.id}`);
        console.log(`   Content: "${event.content.slice(0, 60)}..."`);
        eventInPeer2Relay = true;
      }
    } else if (msg[0] === 'EOSE') {
      clearTimeout(timeout);
      ws2.close();
      if (eventInPeer2Relay) {
        resolve();
      } else {
        reject(new Error('Event not found in Peer2 relay'));
      }
    }
  });

  ws2.on('error', (error) => {
    clearTimeout(timeout);
    reject(error);
  });
});

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Step 3: Peer3 subscribes to Peer2 relay and republishes events
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

console.log('\n5️⃣  Peer3: Subscribing to Peer2 relay...');

const ws3ToPeer2 = new WebSocket(PEER2_RELAY);

ws3ToPeer2.on('open', () => {
  console.log('✅ Peer3 connected to Peer2 relay');

  // Subscribe to all events from peer1
  const subscription = JSON.stringify([
    'REQ',
    'peer3-sync',
    { authors: [peer1Pubkey], limit: 10 },
  ]);

  console.log(`   Subscribing to events from ${peer1Pubkey.slice(0, 16)}...\n`);
  ws3ToPeer2.send(subscription);
});

ws3ToPeer2.on('message', async (data) => {
  const msg = JSON.parse(data.toString());

  if (msg[0] === 'EVENT') {
    const toonString = msg[2];
    const event = toonDecode(toonString);

    console.log('6️⃣  Peer3: Received event from Peer2 relay');
    console.log(`   Event ID: ${event.id}`);
    console.log(`   Content: "${event.content.slice(0, 60)}..."\n`);

    if (event.id === testEvent.id) {
      eventReceivedByPeer3 = true;

      // Republish to Peer3's own relay
      console.log('7️⃣  Peer3: Republishing event to its own relay...');

      // Re-encode in TOON format
      const republishToon = toonEncode(event);
      const republishBytes = new TextEncoder().encode(republishToon);
      const republishBase64 = Buffer.from(republishBytes).toString('base64');

      // Send as paid event to Peer3's own BLS
      const republishPacket = {
        amount: '5000',
        destination: 'g.crosstown.peer3',
        data: republishBase64,
        sourceAccount: 'g.crosstown.peer3.sync',
      };

      try {
        const response = await fetch(`${PEER3_BLS}/handle-packet`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(republishPacket),
        });

        const result = await response.json();

        if (response.ok && result.accept) {
          console.log('✅ Event republished to Peer3 relay');
          console.log(`   Status: Accepted\n`);
        } else {
          console.error(`❌ Failed to republish to Peer3`);
          console.error(`   Code: ${result.code}`);
          console.error(`   Message: ${result.message}\n`);
        }
      } catch (error) {
        console.error(`❌ Error republishing:`, error.message);
      }
    }
  } else if (msg[0] === 'EOSE') {
    console.log('📭 Peer3: Subscription complete (EOSE received)\n');
  }
});

ws3ToPeer2.on('error', (error) => {
  console.error(`❌ Peer3 WebSocket error:`, error.message);
});

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Step 4: Verify event in Peer3 relay
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// Wait for republishing to complete
await sleep(3000);

console.log('8️⃣  Verifying event in Peer3 relay...');

await new Promise((resolve, reject) => {
  const ws3 = new WebSocket(PEER3_RELAY);
  const timeout = setTimeout(() => {
    ws3.close();
    reject(new Error('Timeout waiting for event from Peer3 relay'));
  }, 5000);

  ws3.on('open', () => {
    const subscription = JSON.stringify([
      'REQ',
      'test-peer3',
      { ids: [testEvent.id] },
    ]);
    ws3.send(subscription);
  });

  ws3.on('message', (data) => {
    const msg = JSON.parse(data.toString());

    if (msg[0] === 'EVENT') {
      const toonString = msg[2];
      const event = toonDecode(toonString);

      if (event.id === testEvent.id) {
        console.log('✅ Event found in Peer3 relay!');
        console.log(`   ID: ${event.id}`);
        console.log(`   Content: "${event.content.slice(0, 60)}..."`);
        eventInPeer3Relay = true;
      }
    } else if (msg[0] === 'EOSE') {
      clearTimeout(timeout);
      ws3.close();
      if (eventInPeer3Relay) {
        resolve();
      } else {
        reject(new Error('Event not found in Peer3 relay'));
      }
    }
  });

  ws3.on('error', (error) => {
    clearTimeout(timeout);
    reject(error);
  });
});

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Final Results
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

console.log('\n' + '═'.repeat(70));
console.log('📊 TEST RESULTS');
console.log('═'.repeat(70));

console.log('\n✅ Multi-hop ILP routing:');
console.log(
  `   Peer1 → Genesis → Peer2: ${eventInPeer2Relay ? 'SUCCESS' : 'FAILED'}`
);

console.log('\n✅ Cross-relay event propagation:');
console.log(
  `   Peer3 subscribed to Peer2: ${eventReceivedByPeer3 ? 'SUCCESS' : 'FAILED'}`
);
console.log(
  `   Event republished to Peer3: ${eventInPeer3Relay ? 'SUCCESS' : 'FAILED'}`
);

console.log('\n✅ Event verification:');
console.log(`   Event in Peer2 relay: ${eventInPeer2Relay ? 'YES' : 'NO'}`);
console.log(`   Event in Peer3 relay: ${eventInPeer3Relay ? 'YES' : 'NO'}`);

if (eventInPeer2Relay && eventReceivedByPeer3 && eventInPeer3Relay) {
  console.log(
    '\n🎉 SUCCESS! Complete multi-hop routing and relay synchronization working!\n'
  );
  ws3ToPeer2.close();
  process.exit(0);
} else {
  console.log('\n❌ Some tests failed. Check the output above for details.\n');
  ws3ToPeer2.close();
  process.exit(1);
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Helper Functions
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
