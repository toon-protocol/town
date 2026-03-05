#!/usr/bin/env node
/**
 * Verify NIP-34 events are stored in the Nostr relay
 */

import WebSocket from 'ws';

const RELAY_URL = 'ws://localhost:7100';

console.log('🔍 Verifying NIP-34 events in Nostr relay...\n');

const ws = new WebSocket(RELAY_URL);

ws.on('open', () => {
  console.log('✅ Connected to relay:', RELAY_URL);

  // Subscribe to NIP-34 events
  const subscriptionId = 'nip34-check';
  const filter = {
    kinds: [30617, 1617, 1621], // NIP-34 event kinds
    limit: 10,
  };

  const subscription = JSON.stringify(['REQ', subscriptionId, filter]);
  console.log('📡 Subscribing to NIP-34 events (kinds 30617, 1617, 1621)...\n');

  ws.send(subscription);

  // Timeout after 5 seconds
  setTimeout(() => {
    ws.send(JSON.stringify(['CLOSE', subscriptionId]));
    ws.close();
  }, 5000);
});

let eventCount = 0;

ws.on('message', (data) => {
  const message = JSON.parse(data.toString());
  const [type, ...rest] = message;

  if (type === 'EVENT') {
    const [subscriptionId, event] = rest;
    eventCount++;

    console.log(`📄 Event ${eventCount}:`);
    console.log(`   ID: ${event.id}`);
    console.log(`   Kind: ${event.kind} (${getEventTypeName(event.kind)})`);
    console.log(
      `   Created: ${new Date(event.created_at * 1000).toISOString()}`
    );
    console.log(`   Content length: ${event.content.length} chars`);
    console.log(`   Tags: ${event.tags.length}`);

    if (event.kind === 30617) {
      const repoTag = event.tags.find((t) => t[0] === 'd');
      if (repoTag) {
        console.log(`   Repository: ${repoTag[1]}`);
      }
    } else if (event.kind === 1617) {
      console.log(`   Patch preview: ${event.content.slice(0, 60)}...`);
    } else if (event.kind === 1621) {
      const subjectTag = event.tags.find((t) => t[0] === 'subject');
      if (subjectTag) {
        console.log(`   Subject: ${subjectTag[1]}`);
      }
    }

    console.log('');
  } else if (type === 'EOSE') {
    console.log(
      `✅ End of stored events (found ${eventCount} NIP-34 events)\n`
    );
  }
});

ws.on('close', () => {
  console.log('🔌 Disconnected from relay');

  if (eventCount === 0) {
    console.log(
      '\n⚠️  No NIP-34 events found - they may not be persisted to relay'
    );
    console.log(
      '   Events were stored in BLS but relay integration may be disabled'
    );
  } else {
    console.log(
      `\n✅ Successfully verified ${eventCount} NIP-34 events in relay!`
    );
  }
});

ws.on('error', (error) => {
  console.error('❌ WebSocket error:', error.message);
});

function getEventTypeName(kind) {
  const names = {
    30617: 'Repository Announcement',
    1617: 'Patch',
    1621: 'Issue',
    1622: 'Reply',
  };
  return names[kind] || 'Unknown';
}
