#!/usr/bin/env node
/**
 * Seed Rig-UI test data into a running TOON relay.
 *
 * This script:
 * 1. Creates signed NIP-34 events (kind:30617, 30618, 1621, 1617)
 * 2. Exports git objects (commits, trees, blobs) from the local repo
 * 3. Uploads them to Arweave via ArDrive free tier (TurboFactory.unauthenticated)
 * 4. Inserts events into the peer's SQLite database via docker exec
 *
 * Usage:
 *   node scripts/seed-forge-data.mjs [--container sdk-e2e-peer1] [--db-path /data/relay.db]
 */

import { execSync, execFileSync } from 'child_process';
import { getPublicKey, finalizeEvent } from 'nostr-tools/pure';
import { bytesToHex } from '@noble/hashes/utils';

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------
const CONTAINER = process.argv.includes('--container')
  ? process.argv[process.argv.indexOf('--container') + 1]
  : 'sdk-e2e-peer1';

const DB_PATH = process.argv.includes('--db-path')
  ? process.argv[process.argv.indexOf('--db-path') + 1]
  : '/data/events.db';

// Validate CLI args to prevent shell injection (dev-only, but defense in depth)
if (!/^[a-zA-Z0-9._-]+$/.test(CONTAINER)) {
  throw new Error(`Invalid container name: ${CONTAINER}`);
}
if (!/^[a-zA-Z0-9._/:-]+$/.test(DB_PATH)) {
  throw new Error(`Invalid DB path: ${DB_PATH}`);
}

// Use peer1's Nostr secret key (from docker-compose-sdk-e2e.yml)
const NOSTR_SK_HEX = 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
const sk = Uint8Array.from(Buffer.from(NOSTR_SK_HEX, 'hex'));
const pubkey = getPublicKey(sk);
const REPO_ID = 'toon-protocol';
const REPO_NAME = 'TOON Protocol';
const REPO_DESCRIPTION = 'ILP-gated Nostr relay. Pay to write, free to read.';

console.log(`\n🔑 Pubkey: ${pubkey}`);
console.log(`📦 Container: ${CONTAINER}`);
console.log(`💾 DB: ${DB_PATH}\n`);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
function gitCmd(...args) {
  // Use execFileSync with argument array to avoid shell injection
  return execFileSync('git', args, { encoding: 'utf-8' }).trim();
}

function dockerSqlite(sql) {
  try {
    // Use execFileSync with argument array to avoid shell interpolation (no shell injection)
    execFileSync('docker', ['exec', CONTAINER, 'sqlite3', DB_PATH, sql], {
      encoding: 'utf-8',
      stdio: ['pipe', 'pipe', 'pipe'],
    });
  } catch (e) {
    // If UNIQUE constraint (duplicate), that's OK
    if (e.stderr && e.stderr.includes('UNIQUE')) {
      console.log('  (already exists, skipping)');
    } else {
      throw e;
    }
  }
}

function signEvent(template) {
  const event = finalizeEvent(template, sk);
  return event;
}

/** Escape a string for safe inclusion in a SQLite single-quoted string literal. */
function sqliteEscape(str) {
  // SQLite string escaping: replace ' with '' and strip null bytes
  return str.replace(/\0/g, '').replace(/'/g, "''");
}

/** Validate that a string is a hex-only value (safe for SQL interpolation). */
function isHexString(str) {
  return /^[0-9a-f]+$/i.test(str);
}

function insertEvent(event) {
  // Validate hex fields to prevent any injection through event data
  if (!isHexString(event.id) || !isHexString(event.pubkey) || !isHexString(event.sig)) {
    throw new Error(`Event contains non-hex id/pubkey/sig: ${event.id?.slice(0, 8)}`);
  }
  if (!Number.isInteger(event.kind) || !Number.isInteger(event.created_at)) {
    throw new Error(`Event contains non-integer kind/created_at`);
  }
  const tagsJson = sqliteEscape(JSON.stringify(event.tags));
  const contentEscaped = sqliteEscape(event.content);
  const sql = `INSERT OR IGNORE INTO events (id, pubkey, kind, content, tags, created_at, sig, received_at) VALUES ('${event.id}', '${event.pubkey}', ${event.kind}, '${contentEscaped}', '${tagsJson}', ${event.created_at}, '${event.sig}', ${Math.floor(Date.now() / 1000)})`;
  dockerSqlite(sql);
}

// ---------------------------------------------------------------------------
// Step 1: Get git data from local repo
// ---------------------------------------------------------------------------
console.log('📋 Step 1: Collecting git data from local repo...\n');

const headSha = gitCmd('rev-parse', 'HEAD');
const headTreeSha = gitCmd('rev-parse', 'HEAD^{tree}');
const commits = gitCmd('log', '--format=%H %T %P %s', '-5').split('\n').map(line => {
  const [sha, treeSha, ...rest] = line.split(' ');
  // Find where parent SHAs end and subject starts
  // Parents are 40-char hex, subject is the rest
  const remaining = rest.join(' ');
  const parentMatch = remaining.match(/^([0-9a-f]{40}\s?)*/);
  const parentStr = parentMatch ? parentMatch[0].trim() : '';
  const parents = parentStr ? parentStr.split(/\s+/) : [];
  const subject = remaining.slice(parentStr.length).trim();
  return { sha, treeSha, parents, subject };
});

console.log(`  HEAD: ${headSha}`);
console.log(`  Tree: ${headTreeSha}`);
console.log(`  Commits: ${commits.length}\n`);

// Get refs
const mainRef = gitCmd('rev-parse', 'refs/heads/epic-8');
const refs = new Map();
refs.set('refs/heads/epic-8', mainRef);
try {
  const mainSha = gitCmd('rev-parse', 'refs/heads/main');
  refs.set('refs/heads/main', mainSha);
} catch { /* branch may not exist locally */ }

console.log(`  Refs: ${[...refs.entries()].map(([k,v]) => `${k}=${v.slice(0,8)}`).join(', ')}\n`);

// Get top-level tree entries
const treeEntries = gitCmd('ls-tree', 'HEAD').split('\n').map(line => {
  const match = line.match(/^(\d+)\s+(\w+)\s+([0-9a-f]+)\t(.+)$/);
  if (!match) return null;
  return { mode: match[1], type: match[2], sha: match[3], name: match[4] };
}).filter(Boolean);

console.log(`  Tree entries: ${treeEntries.length}\n`);

// ---------------------------------------------------------------------------
// Step 2: Upload git objects to Arweave via ArDrive free tier
// ---------------------------------------------------------------------------
console.log('📤 Step 2: Uploading git objects to Arweave...\n');

// Pre-import Readable for use in upload
import { Readable } from 'stream';

// Collect SHA→txId mappings for embedding in refs event
const arweaveMap = new Map();

let turbo;
try {
  const { TurboFactory } = await import('@ardrive/turbo-sdk/node');
  const Arweave = (await import('arweave')).default;
  const arweave = Arweave.init({});
  const jwk = await arweave.crypto.generateJWK();
  turbo = TurboFactory.authenticated({ privateKey: jwk });
  console.log('  ✅ ArDrive TurboFactory initialized (authenticated with ephemeral JWK, free tier <100KB)\n');
} catch (e) {
  console.log(`  ⚠️  Could not load @ardrive/turbo-sdk: ${e.message}`);
  console.log('  Skipping Arweave uploads. Tree/blob views will show "Content unavailable".\n');
  turbo = null;
}

async function uploadGitObject(sha, type) {
  if (!turbo) return null;
  if (arweaveMap.has(sha)) return arweaveMap.get(sha);
  // Validate SHA is hex-only (defense in depth against injection)
  if (!/^[0-9a-f]{40}$/.test(sha)) {
    console.log(`  ⚠️  Invalid SHA: ${sha}, skipping`);
    return null;
  }
  // Check object size BEFORE reading content to avoid ENOBUFS on large blobs
  const objectSize = parseInt(execFileSync('git', ['cat-file', '-s', sha], { encoding: 'utf-8' }).trim(), 10);
  if (objectSize > 100 * 1024) {
    console.log(`  ⚠️  ${type} ${sha.slice(0, 8)} too large (${objectSize} bytes), skipping`);
    return null;
  }
  // Use raw format for tree objects (parseGitTree expects binary), pretty-print for commits/blobs
  // Use execFileSync with argument array to avoid shell injection
  const catArgs = type === 'tree' ? ['cat-file', 'tree', sha] : ['cat-file', '-p', sha];
  const objectData = execFileSync('git', catArgs, { encoding: 'buffer', maxBuffer: 200 * 1024 });
  try {
    const contentType = type === 'blob' ? 'application/octet-stream' : `application/x-git-${type}`;
    const result = await turbo.uploadFile({
      fileStreamFactory: () => Readable.from(objectData),
      fileSizeFactory: () => objectData.length,
      dataItemOpts: {
        tags: [
          { name: 'Git-SHA', value: sha },
          { name: 'Repo', value: REPO_ID },
          { name: 'Content-Type', value: contentType },
          { name: 'Git-Type', value: type },
        ],
      },
    });
    console.log(`  ✅ ${type} ${sha.slice(0, 8)} → ${result.id} (${objectData.length} bytes)`);
    arweaveMap.set(sha, result.id);
    return result.id;
  } catch (e) {
    console.log(`  ❌ ${type} ${sha.slice(0, 8)} upload failed: ${e.message}`);
    return null;
  }
}

// Upload commits
for (const commit of commits) {
  await uploadGitObject(commit.sha, 'commit');
}

// Upload HEAD tree + key blobs
await uploadGitObject(headTreeSha, 'tree');
const keyFiles = ['README.md', 'package.json', 'CLAUDE.md', 'LICENSE'];
for (const file of keyFiles) {
  const entry = treeEntries.find(e => e.name === file);
  if (entry && entry.type === 'blob') {
    await uploadGitObject(entry.sha, 'blob');
  }
}

// Recursively upload all tree objects so every directory is browsable.
// Trees are tiny (<1KB) so this is safe for Turbo free tier.
// Blobs are only uploaded for leaf files at max depth to keep upload count reasonable.
const uploadedShas = new Set();
const MAX_BLOBS_PER_DIR = 5;

async function uploadTreeRecursive(treeSha, treePath) {
  if (uploadedShas.has(treeSha)) return;
  uploadedShas.add(treeSha);

  const children = gitCmd('ls-tree', treeSha).split('\n').map(line => {
    const match = line.match(/^(\d+)\s+(\w+)\s+([0-9a-f]+)\t(.+)$/);
    return match ? { mode: match[1], type: match[2], sha: match[3], name: match[4] } : null;
  }).filter(Boolean);

  let blobCount = 0;
  for (const child of children) {
    if (child.type === 'tree') {
      await uploadGitObject(child.sha, 'tree');
      await uploadTreeRecursive(child.sha, `${treePath}${child.name}/`);
    } else if (child.type === 'blob' && blobCount < MAX_BLOBS_PER_DIR) {
      await uploadGitObject(child.sha, 'blob');
      blobCount++;
    }
  }
}

for (const entry of treeEntries) {
  if (entry.type === 'tree') {
    await uploadGitObject(entry.sha, 'tree');
    await uploadTreeRecursive(entry.sha, `${entry.name}/`);
  }
}

console.log(`\n  📦 Arweave map: ${arweaveMap.size} SHA→txId mappings collected\n`);

// ---------------------------------------------------------------------------
// Step 3: Create and insert NIP-34 events
// ---------------------------------------------------------------------------
console.log('📝 Step 3: Creating NIP-34 events...\n');

const now = Math.floor(Date.now() / 1000);

// 3a. Repository Announcement (kind:30617)
console.log('  → kind:30617 Repository Announcement');
const repoAnnouncement = signEvent({
  kind: 30617,
  created_at: now - 3600, // 1 hour ago
  content: REPO_DESCRIPTION,
  tags: [
    ['d', REPO_ID],
    ['name', REPO_NAME],
    ['description', REPO_DESCRIPTION],
    ['web', `http://localhost:5173/${pubkey}/${REPO_ID}`],
    ['clone', `ws://localhost:19700`],
    ['r', headSha, 'euc'],
    ['r', 'HEAD', 'epic-8'],
    ['relays', 'ws://localhost:19700'],
    ['maintainers', pubkey],
  ],
});
insertEvent(repoAnnouncement);
console.log(`    id: ${repoAnnouncement.id.slice(0, 16)}...`);

// 3b. Repository Refs (kind:30618) — includes arweave SHA→txId mappings
console.log('  → kind:30618 Repository Refs');
const refTags = [...refs.entries()].map(([refName, sha]) => ['r', refName, sha]);
const arweaveTags = [...arweaveMap.entries()].map(([sha, txId]) => ['arweave', sha, txId]);
const repoRefs = signEvent({
  kind: 30618,
  created_at: now - 1800,
  content: '',
  tags: [
    ['d', REPO_ID],
    ...refTags,
    ...arweaveTags,
  ],
});
insertEvent(repoRefs);
console.log(`    id: ${repoRefs.id.slice(0, 16)}...`);
console.log(`    refs: ${refTags.map(t => `${t[1]}=${t[2].slice(0,8)}`).join(', ')}`);

// 2c. Issues (kind:1621) - Create 3 sample issues
const issues = [
  {
    title: 'WebSocket relay should support NIP-42 authentication',
    body: `## Description\n\nThe relay currently has no authentication mechanism for subscribers. We should implement NIP-42 (Authentication of clients to relays) to allow relays to restrict read access to authenticated users.\n\n## Acceptance Criteria\n- [ ] Challenge sent on connect\n- [ ] AUTH message handling\n- [ ] Restricted event filtering for unauthenticated users\n\n## References\n- [NIP-42 spec](https://github.com/nostr-protocol/nips/blob/master/42.md)`,
    labels: ['enhancement', 'relay'],
  },
  {
    title: 'Payment channel settlement fails on Arbitrum Sepolia',
    body: `## Bug Report\n\n### Steps to Reproduce\n1. Open payment channel on Arbitrum Sepolia (421614)\n2. Send ILP packets\n3. Attempt cooperative close\n\n### Expected\nChannel closes and balances settle correctly.\n\n### Actual\nTransaction reverts with "insufficient allowance".\n\n### Environment\n- Chain: Arbitrum Sepolia (421614)\n- USDC: 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d\n- Node version: v2.0.0`,
    labels: ['bug', 'settlement'],
  },
  {
    title: 'Add DVM compute marketplace pricing docs',
    body: `## Feature Request\n\nWe need documentation for the DVM compute marketplace pricing model:\n\n- Base pricing per compute unit\n- Bid/ask mechanism for kind:5090-5099\n- Settlement flow for long-running compute jobs\n- Fee structure (relay fee vs compute provider fee)\n\nThis blocks the Epic 10 compute primitives work.`,
    labels: ['docs', 'dvm'],
  },
];

const issueEvents = [];
for (const issue of issues) {
  console.log(`  → kind:1621 Issue: ${issue.title.slice(0, 50)}...`);
  const event = signEvent({
    kind: 1621,
    created_at: now - Math.floor(Math.random() * 86400),
    content: issue.body,
    tags: [
      ['a', `30617:${pubkey}:${REPO_ID}`],
      ['p', pubkey],
      ['subject', issue.title],
      ...issue.labels.map(l => ['t', l]),
    ],
  });
  insertEvent(event);
  issueEvents.push(event);
  console.log(`    id: ${event.id.slice(0, 16)}...`);
}

// 2d. Issue comments (kind:1622)
console.log('  → kind:1622 Issue Comments');
const comment1 = signEvent({
  kind: 1622,
  created_at: now - 1200,
  content: 'I can reproduce this on Arbitrum Sepolia. The issue is that the token allowance check happens before the channel close signature verification. We need to ensure `approve()` is called with sufficient amount before `cooperativeClose()`.',
  tags: [
    ['e', issueEvents[1].id],
    ['p', pubkey],
  ],
});
insertEvent(comment1);
console.log(`    comment on issue #2: ${comment1.id.slice(0, 16)}...`);

const comment2 = signEvent({
  kind: 1622,
  created_at: now - 600,
  content: 'Good catch. I\'ll add an `ensureAllowance()` helper that checks and approves in the settlement flow. PR incoming.',
  tags: [
    ['e', issueEvents[1].id],
    ['p', pubkey],
  ],
});
insertEvent(comment2);
console.log(`    comment on issue #2: ${comment2.id.slice(0, 16)}...`);

// 2e. Patches / PRs (kind:1617)
console.log('  → kind:1617 Patches');
const patchContent = `From ${headSha} Mon Sep 17 00:00:00 2001
From: Test Developer <dev@toon-protocol.org>
Date: ${new Date().toUTCString()}
Subject: [PATCH] fix: ensure token allowance before cooperative close

Check and approve token allowance in the settlement flow
before attempting cooperative channel close.

---
 packages/sdk/src/settlement/close.ts | 12 ++++++++++--
 1 file changed, 10 insertions(+), 2 deletions(-)

diff --git a/packages/sdk/src/settlement/close.ts b/packages/sdk/src/settlement/close.ts
index abc1234..def5678 100644
--- a/packages/sdk/src/settlement/close.ts
+++ b/packages/sdk/src/settlement/close.ts
@@ -42,6 +42,14 @@ export async function cooperativeClose(
   channel: PaymentChannel,
   finalBalance: bigint,
 ): Promise<void> {
+  // Ensure sufficient token allowance before close
+  const currentAllowance = await channel.token.allowance(
+    channel.address,
+    channel.tokenNetwork,
+  );
+  if (currentAllowance < finalBalance) {
+    await channel.token.approve(channel.tokenNetwork, finalBalance);
+  }
+
   const closeSignature = await signCooperativeClose(
     channel,
     finalBalance,
--
2.43.0`;

const patchEvent = signEvent({
  kind: 1617,
  created_at: now - 900,
  content: patchContent,
  tags: [
    ['a', `30617:${pubkey}:${REPO_ID}`],
    ['r', headSha],
    ['p', pubkey],
    ['commit', headSha],
    ['parent-commit', commits[1]?.sha || headSha],
    ['subject', 'fix: ensure token allowance before cooperative close'],
    ['branch', 'epic-8'],
    ['t', 'root'],
  ],
});
insertEvent(patchEvent);
console.log(`    patch: ${patchEvent.id.slice(0, 16)}...`);

// 2f. Status events (kind:1630 = open, kind:1631 = merged)
console.log('  → kind:1630/1631 Status Events');
const openStatus = signEvent({
  kind: 1630,
  created_at: now - 800,
  content: '',
  tags: [
    ['e', patchEvent.id],
    ['p', pubkey],
    ['a', `30617:${pubkey}:${REPO_ID}`],
  ],
});
insertEvent(openStatus);
console.log(`    open status for patch: ${openStatus.id.slice(0, 16)}...`);

// Also add a merged status for the patch
const mergedStatus = signEvent({
  kind: 1631,
  created_at: now - 300,
  content: 'LGTM! Merging.',
  tags: [
    ['e', patchEvent.id],
    ['p', pubkey],
    ['a', `30617:${pubkey}:${REPO_ID}`],
  ],
});
insertEvent(mergedStatus);
console.log(`    merged status for patch: ${mergedStatus.id.slice(0, 16)}...`);

// Open status for all issues
for (const issueEvent of issueEvents) {
  const status = signEvent({
    kind: 1630,
    created_at: issueEvent.created_at + 1,
    content: '',
    tags: [
      ['e', issueEvent.id],
      ['p', pubkey],
      ['a', `30617:${pubkey}:${REPO_ID}`],
    ],
  });
  insertEvent(status);
}
console.log(`    open status for ${issueEvents.length} issues`);

// Close issue #2 (the bug)
const closedStatus = signEvent({
  kind: 1632,
  created_at: now - 200,
  content: 'Fixed in patch above.',
  tags: [
    ['e', issueEvents[1].id],
    ['p', pubkey],
    ['a', `30617:${pubkey}:${REPO_ID}`],
  ],
});
insertEvent(closedStatus);
console.log(`    closed status for issue #2: ${closedStatus.id.slice(0, 16)}...`);

// ---------------------------------------------------------------------------
// Step 4: Verify
// ---------------------------------------------------------------------------
console.log('\n✅ Step 4: Verifying seeded data...\n');

try {
  const countResult = execSync(
    `docker exec ${CONTAINER} sqlite3 ${DB_PATH} "SELECT kind, COUNT(*) FROM events GROUP BY kind ORDER BY kind"`,
    { encoding: 'utf-8' }
  ).trim();
  console.log('  Events by kind:');
  for (const line of countResult.split('\n')) {
    const [kind, count] = line.split('|');
    const kindName = {
      '1617': 'Patch',
      '1621': 'Issue',
      '1622': 'Comment',
      '1630': 'Status:Open',
      '1631': 'Status:Merged',
      '1632': 'Status:Closed',
      '30617': 'Repo Announcement',
      '30618': 'Repo Refs',
    }[kind] || `kind:${kind}`;
    console.log(`    ${kindName}: ${count}`);
  }
} catch (e) {
  console.log(`  ⚠️  Could not verify: ${e.message}`);
}

console.log(`\n🎉 Rig-UI test data seeded successfully!`);
console.log(`\n📱 Open Rig-UI at: http://localhost:5173/?relay=ws://localhost:19700`);
console.log(`   Routes to test:`);
console.log(`   - /                                    → Repository list`);
console.log(`   - /${pubkey}/${REPO_ID}/               → Tree view`);
console.log(`   - /${pubkey}/${REPO_ID}/issues         → Issues`);
console.log(`   - /${pubkey}/${REPO_ID}/pulls          → PRs`);
console.log(`   - /${pubkey}/${REPO_ID}/commits/refs/heads/epic-8 → Commit log\n`);
