#!/usr/bin/env node
/**
 * Test NIP-34 Pull Request Submission
 *
 * Simulates a second user submitting a PR to an existing repository
 */

import {
  generateSecretKey,
  getPublicKey,
  finalizeEvent,
} from 'nostr-tools/pure';
import { encode as encodeToon } from '@toon-format/toon';

const BLS_URL = 'http://localhost:3100';
const CONNECTOR_URL = 'http://localhost:8080';
const REPO_NAME = 'nip34-test-repo';
const OWNER = 'admin';

// Generate a different keypair for the PR submitter
const contributorSk = generateSecretKey();
const contributorPk = getPublicKey(contributorSk);

console.log('🧪 NIP-34 Pull Request Test\n');
console.log(`Contributor Pubkey: ${contributorPk.slice(0, 16)}...\n`);

/**
 * Submit event via ILP
 */
async function submitEvent(event, description) {
  console.log(`📤 Submitting ${description}...`);
  console.log(`   Event ID: ${event.id.substring(0, 8)}`);
  console.log(`   Kind: ${event.kind}`);

  try {
    const toonEvent = encodeToon(event);
    const eventBytes = new TextEncoder().encode(toonEvent);
    const price = eventBytes.length * 10;

    console.log(`   Size: ${eventBytes.length} bytes`);
    console.log(`   Payment: ${price} units\n`);

    // Create ILP PREPARE packet
    const ilpPacket = {
      amount: price.toString(),
      destination: 'g.crosstown.my-node',
      executionCondition: Buffer.alloc(32).toString('base64'),
      expiresAt: new Date(Date.now() + 30000).toISOString(),
      data: Buffer.from(toonEvent).toString('base64'),
    };

    // Submit directly to BLS
    const response = await fetch(`${BLS_URL}/handle-packet`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(ilpPacket),
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.log(`   ❌ Error: ${response.status} - ${errorText}\n`);
      return false;
    }

    console.log(`   ✅ Submitted successfully!\n`);
    return true;
  } catch (error) {
    console.log(`   ❌ Error: ${error.message}\n`);
    return false;
  }
}

async function main() {
  console.log('============================================================');
  console.log('Pull Request: Add feature branch');
  console.log('============================================================\n');

  // Create a PR event (kind:1618)
  const prEvent = finalizeEvent(
    {
      kind: 1618,
      created_at: Math.floor(Date.now() / 1000),
      tags: [
        ['a', `30617:${contributorPk}:${OWNER}/${REPO_NAME}`],
        ['p', contributorPk],
        ['clone', 'https://github.com/contributor/nip34-test-repo.git'],
        ['c', 'abc123def456'], // commit hash
        ['subject', 'Add new feature: User authentication'],
      ],
      content: `This PR adds user authentication to the application.

## Changes
- Added JWT-based authentication
- Created login/logout endpoints
- Added middleware for protected routes
- Updated documentation

## Testing
- Unit tests for auth middleware
- Integration tests for login flow
- Manual testing completed

Please review and merge!`,
    },
    contributorSk
  );

  await submitEvent(prEvent, 'Pull Request: Add authentication');

  console.log('\n============================================================');
  console.log('✅ Pull Request submitted!');
  console.log('============================================================\n');

  console.log('📊 What happened:');
  console.log('  • PR event (kind:1618) paid for via ILP');
  console.log('  • Event stored in BLS');
  console.log('  • NIP34Handler creates documentation issue in Forgejo\n');

  console.log('🔍 Next steps:');
  console.log(
    '  1. Check Forgejo issues: http://localhost:3004/crosstownAdmin/nip34-test-repo/issues'
  );
  console.log('  2. View logs: docker logs crosstown-node | grep NIP34');
  console.log('  3. See PR documentation issue with clone instructions\n');
}

main().catch(console.error);
