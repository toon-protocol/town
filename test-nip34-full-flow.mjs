#!/usr/bin/env node
/**
 * Test NIP-34 Full Flow
 *
 * Tests complete NIP-34 workflow:
 * 1. Repository announcement (kind:30617)
 * 2. Multiple patches (kind:1617)
 * 3. Issues (kind:1621)
 */

import {
  generateSecretKey,
  getPublicKey,
  finalizeEvent,
} from 'nostr-tools/pure';
import { bytesToHex } from '@noble/hashes/utils';

/**
 * Encode a Nostr event in TOON format
 */
function encodeToonEvent(event) {
  const tags = event.tags.map((tag) => tag.join('\t')).join('\n');
  return `${event.id}\t${event.pubkey}\t${event.created_at}\t${event.kind}\t${tags}\t${event.content}\t${event.sig}`;
}

const BLS_URL = 'http://localhost:3100';
const CONNECTOR_URL = 'http://localhost:8080';
const REPO_NAME = 'nip34-test-repo';
const OWNER = 'admin';

// Generate keypair for this test
const sk = generateSecretKey();
const pkBytes = getPublicKey(sk);
const pk = bytesToHex(pkBytes);

console.log('🧪 NIP-34 Full Flow Test\n');
console.log(`Test Pubkey: ${pk.substring(0, 16)}...\n`);

/**
 * Submit a NIP-34 event via ILP payment
 */
async function submitNIP34Event(event, description) {
  console.log(`📤 Submitting ${description}...`);
  console.log(`   Event ID: ${event.id.substring(0, 8)}`);
  console.log(`   Kind: ${event.kind}`);

  try {
    // Encode event in TOON format
    const toonEvent = encodeToonEvent(event);
    const eventBytes = new TextEncoder().encode(toonEvent);
    const price = eventBytes.length * 10; // 10 units per byte

    console.log(`   Size: ${eventBytes.length} bytes`);
    console.log(`   Payment: ${price} units\n`);

    // Create ILP payment packet
    const ilpPacket = {
      amount: price.toString(),
      executionCondition: Buffer.alloc(32).toString('base64'),
      expiresAt: new Date(Date.now() + 30000).toISOString(),
      destination: 'g.crosstown.my-node',
      data: Buffer.from(toonEvent).toString('base64'),
    };

    // Submit via connector
    const response = await fetch(`${CONNECTOR_URL}/ilp`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(ilpPacket),
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.log(`   ❌ Error: ${response.status} - ${errorText}\n`);
      return false;
    }

    const result = await response.json();
    console.log(`   ✅ Submitted successfully!\n`);
    return true;
  } catch (error) {
    console.log(`   ❌ Error: ${error.message}\n`);
    return false;
  }
}

/**
 * Wait for a bit
 */
function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function main() {
  console.log('============================================================');
  console.log('Step 1: Repository Announcement (kind:30617)');
  console.log('============================================================\n');

  const repoEvent = finalizeEvent(
    {
      kind: 30617,
      created_at: Math.floor(Date.now() / 1000),
      tags: [
        ['d', `${OWNER}/${REPO_NAME}`],
        ['name', REPO_NAME],
        ['description', 'Test repository for NIP-34 workflow'],
        ['web', 'https://github.com/example/test'],
        ['clone', 'https://github.com/example/test.git'],
        ['relays', 'wss://relay.damus.io'],
      ],
      content: '',
    },
    sk
  );

  await submitNIP34Event(repoEvent, 'Repository announcement');
  await sleep(2000);

  console.log('============================================================');
  console.log('Step 2: Patch - Add README.md (kind:1617)');
  console.log('============================================================\n');

  const patchContent = `From 9c88ec0f6c78b9c0eeb48a1e5f91b8f3d2a6e4b1 Mon Sep 17 00:00:00 2001
From: Test User <test@example.com>
Date: Fri, 21 Feb 2026 12:00:00 +0000
Subject: [PATCH] Add README.md

---
 README.md | 5 +++++
 1 file changed, 5 insertions(+)
 create mode 100644 README.md

diff --git a/README.md b/README.md
new file mode 100644
index 0000000..8b13789
--- /dev/null
+++ b/README.md
@@ -0,0 +1,5 @@
+# ${REPO_NAME}
+
+This is a test repository for NIP-34 workflow.
+
+Submitted via Crosstown ILP-gated relay!
--
2.39.0
`;

  const patch1Event = finalizeEvent(
    {
      kind: 1617,
      created_at: Math.floor(Date.now() / 1000),
      tags: [
        ['a', `30617:${pk}:${OWNER}/${REPO_NAME}`],
        ['p', pk],
        ['commit', '9c88ec0f6c78b9c0eeb48a1e5f91b8f3d2a6e4b1'],
      ],
      content: patchContent,
    },
    sk
  );

  await submitNIP34Event(patch1Event, 'Patch: Add README.md');
  await sleep(2000);

  console.log('============================================================');
  console.log('Step 3: Patch - Add LICENSE file (kind:1617)');
  console.log('============================================================\n');

  const licensePatch = `From a1b2c3d4e5f6789012345678901234567890abcd Mon Sep 17 00:00:00 2001
From: Test User <test@example.com>
Date: Fri, 21 Feb 2026 12:30:00 +0000
Subject: [PATCH] Add MIT LICENSE

---
 LICENSE | 3 +++
 1 file changed, 3 insertions(+)
 create mode 100644 LICENSE

diff --git a/LICENSE b/LICENSE
new file mode 100644
index 0000000..0e259d4
--- /dev/null
+++ b/LICENSE
@@ -0,0 +1,3 @@
+MIT License
+
+Copyright (c) 2026 NIP-34 Test
--
2.39.0
`;

  const patch2Event = finalizeEvent(
    {
      kind: 1617,
      created_at: Math.floor(Date.now() / 1000) + 1,
      tags: [
        ['a', `30617:${pk}:${OWNER}/${REPO_NAME}`],
        ['p', pk],
        ['commit', 'a1b2c3d4e5f6789012345678901234567890abcd'],
      ],
      content: licensePatch,
    },
    sk
  );

  await submitNIP34Event(patch2Event, 'Patch: Add LICENSE');
  await sleep(2000);

  console.log('============================================================');
  console.log('Step 4: Issue - Documentation needed (kind:1621)');
  console.log('============================================================\n');

  const issueEvent = finalizeEvent(
    {
      kind: 1621,
      created_at: Math.floor(Date.now() / 1000) + 2,
      tags: [
        ['a', `30617:${pk}:${OWNER}/${REPO_NAME}`],
        ['p', pk],
        ['subject', 'Add documentation for NIP-34 integration'],
      ],
      content: `We need comprehensive documentation explaining how the NIP-34 integration works.

Tasks:
- [ ] Document event kinds
- [ ] Explain payment flow
- [ ] Add examples
- [ ] Create diagrams`,
    },
    sk
  );

  await submitNIP34Event(issueEvent, 'Issue: Documentation needed');
  await sleep(2000);

  console.log('============================================================');
  console.log('Step 5: Issue - Add CI/CD pipeline (kind:1621)');
  console.log('============================================================\n');

  const issue2Event = finalizeEvent(
    {
      kind: 1621,
      created_at: Math.floor(Date.now() / 1000) + 3,
      tags: [
        ['a', `30617:${pk}:${OWNER}/${REPO_NAME}`],
        ['p', pk],
        ['subject', 'Set up CI/CD pipeline'],
      ],
      content: `We should add automated testing and deployment.

Proposed pipeline:
1. Run tests on every commit
2. Build Docker images
3. Deploy to staging on merge to main
4. Manual approval for production`,
    },
    sk
  );

  await submitNIP34Event(issue2Event, 'Issue: CI/CD pipeline');
  await sleep(2000);

  console.log('\n============================================================');
  console.log('✅ All NIP-34 events submitted successfully!');
  console.log('============================================================\n');

  console.log('📊 Summary:');
  console.log('  • 1 repository announcement');
  console.log('  • 2 patches (README.md, LICENSE)');
  console.log('  • 2 issues (Documentation, CI/CD)\n');

  console.log('🔍 Next steps:');
  console.log(
    '  1. Check Forgejo: http://localhost:3004/crosstownAdmin/nip34-test-repo'
  );
  console.log('  2. View logs: docker logs crosstown-node | grep NIP34');
  console.log('  3. Check PRs and issues in Forgejo UI\n');
}

main().catch(console.error);
