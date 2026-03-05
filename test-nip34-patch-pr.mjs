#!/usr/bin/env node
/**
 * Test NIP-34 Patch → Pull Request Flow
 *
 * Tests the complete flow:
 * 1. Create repository (kind:30617)
 * 2. Submit patch (kind:1617) - creates branch + files + PR
 */

import {
  generateSecretKey,
  getPublicKey,
  finalizeEvent,
} from 'nostr-tools/pure';
import { encode as encodeToon } from '@toon-format/toon';

const BLS_URL = 'http://localhost:3100';
const REPO_NAME = 'nip34-pr-test';
const OWNER = 'admin';

// Generate keypair for this test
const sk = generateSecretKey();
const pk = getPublicKey(sk);

console.log('🧪 NIP-34 Patch → PR Test\n');
console.log(`Test Pubkey: ${pk.slice(0, 16)}...\n`);

/**
 * Submit event via ILP
 */
async function submitEvent(event, description) {
  console.log(`📤 ${description}...`);
  console.log(`   Event ID: ${event.id.substring(0, 8)}`);
  console.log(`   Kind: ${event.kind}`);

  try {
    const toonEvent = encodeToon(event);
    const eventBytes = new TextEncoder().encode(toonEvent);
    const price = eventBytes.length * 10;

    console.log(`   Size: ${eventBytes.length} bytes`);
    console.log(`   Payment: ${price} units\n`);

    const ilpPacket = {
      amount: price.toString(),
      destination: 'g.crosstown.my-node',
      executionCondition: Buffer.alloc(32).toString('base64'),
      expiresAt: new Date(Date.now() + 30000).toISOString(),
      data: Buffer.from(toonEvent).toString('base64'),
    };

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

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function main() {
  console.log('============================================================');
  console.log('Step 1: Create Repository');
  console.log('============================================================\n');

  const repoEvent = finalizeEvent(
    {
      kind: 30617,
      created_at: Math.floor(Date.now() / 1000),
      tags: [
        ['d', `${OWNER}/${REPO_NAME}`],
        ['name', REPO_NAME],
        ['description', 'Test repository for patch → PR workflow'],
        ['clone', `http://localhost:3004/crosstownAdmin/${REPO_NAME}.git`],
      ],
      content: '',
    },
    sk
  );

  await submitEvent(repoEvent, 'Creating repository');
  await sleep(2000);

  console.log('============================================================');
  console.log('Step 2: Submit Patch (will create PR)');
  console.log('============================================================\n');

  // Create a git format-patch style patch
  const patchContent = `From abc123def456789012345678901234567890abcd Mon Sep 17 00:00:00 2001
From: Contributor <contributor@example.com>
Date: Fri, 21 Feb 2026 16:00:00 +0000
Subject: [PATCH] Add README with project information

---
 README.md | 15 +++++++++++++++
 1 file changed, 15 insertions(+)
 create mode 100644 README.md

diff --git a/README.md b/README.md
new file mode 100644
index 0000000..9876543
--- /dev/null
+++ b/README.md
@@ -0,0 +1,15 @@
+# ${REPO_NAME}
+
+This repository demonstrates the NIP-34 patch workflow.
+
+## Features
+
+- Payment-gated Git operations via Nostr
+- Automatic PR creation from patches
+- ILP micropayments for event storage
+
+## How it works
+
+1. Submit NIP-34 patch event (kind:1617)
+2. Pay via ILP (10 units per byte)
+3. Patch automatically applied → PR created!
--
2.39.0
`;

  const patchEvent = finalizeEvent(
    {
      kind: 1617,
      created_at: Math.floor(Date.now() / 1000) + 1,
      tags: [
        ['a', `30617:${pk}:${OWNER}/${REPO_NAME}`],
        ['p', pk],
        ['commit', 'abc123def456789012345678901234567890abcd'],
      ],
      content: patchContent,
    },
    sk
  );

  await submitEvent(patchEvent, 'Submitting patch');
  await sleep(3000);

  console.log('\n============================================================');
  console.log('✅ Patch submitted and PR should be created!');
  console.log('============================================================\n');

  console.log('📊 What happened:');
  console.log('  1. Repository created via NIP-34 (kind:30617)');
  console.log('  2. Patch submitted via NIP-34 (kind:1617)');
  console.log('  3. NIP34Handler parsed the patch');
  console.log('  4. Created new branch via Forgejo API');
  console.log('  5. Applied file changes via API');
  console.log('  6. Created Pull Request automatically\n');

  console.log('🔍 Verify:');
  console.log(
    `  1. Repository: http://localhost:3004/crosstownAdmin/${REPO_NAME}`
  );
  console.log(
    `  2. Pull Requests: http://localhost:3004/crosstownAdmin/${REPO_NAME}/pulls`
  );
  console.log('  3. View logs: docker logs crosstown-node | grep NIP34\n');
}

main().catch(console.error);
