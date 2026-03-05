#!/usr/bin/env node
/**
 * Test publishing a real Nostr event through HTTP mode
 */

import { randomBytes } from 'crypto';

// Minimal Nostr event creation (no dependencies)
function createNostrEvent(kind, content, secretKey) {
  const pubkey = '0'.repeat(64); // Placeholder
  const created_at = Math.floor(Date.now() / 1000);

  const event = {
    id: randomBytes(32).toString('hex'),
    pubkey,
    created_at,
    kind,
    tags: [],
    content,
    sig: randomBytes(64).toString('hex'), // Placeholder signature
  };

  return event;
}

async function publishNostrEvent() {
  console.log('📝 Publishing Nostr Event via HTTP Connector\n');

  const event = createNostrEvent(
    1,
    'Test event from HTTP mode - ' + Date.now(),
    null
  );
  console.log('Event:', JSON.stringify(event, null, 2));

  // Encode event as TOON (simplified - just JSON for now)
  const eventData = JSON.stringify(event);

  const packet = {
    destination: 'g.crosstown.my-node',
    amount: '100',
    expiresAt: new Date(Date.now() + 30000).toISOString(),
    executionCondition: randomBytes(32).toString('base64'),
    data: Buffer.from(eventData).toString('base64'),
  };

  try {
    console.log('\n📤 Sending ILP packet with Nostr event...');
    const response = await fetch('http://localhost:8081/admin/ilp/send', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(packet),
    });

    const result = await response.json();
    console.log(`📊 Status: ${response.status}`);
    console.log(`📨 Result:`, JSON.stringify(result, null, 2));

    if (result.fulfilled) {
      console.log('\n✅ Event published successfully!');
      return true;
    } else {
      console.log(
        `\n⚠️  Event not fulfilled: ${result.code} - ${result.message}`
      );
      return false;
    }
  } catch (error) {
    console.error('❌ Error:', error.message);
    return false;
  }
}

publishNostrEvent();
