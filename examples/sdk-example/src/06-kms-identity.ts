/**
 * Example 06: KMS Identity (Nautilus KMS Pipeline)
 *
 * Demonstrates TEE enclave-bound identity derivation using deriveFromKmsSeed()
 * from @toon-protocol/core (Epic 4, Story 4.4).
 *
 * In production Marlin Oyster CVM:
 *   - A 32-byte seed comes from Nautilus KMS (encrypted via Threshold Network DKG)
 *   - The seed is only decryptable when the enclave's PCR values match KmsRoot contract
 *   - If the code changes -> PCR changes -> KMS seed inaccessible -> identity lost
 *
 * This example shows the same derivation pipeline using a BIP-39 mnemonic,
 * which uses the identical NIP-06 path (m/44'/1237'/0'/0/0). When real KMS
 * is available, swap the mnemonic for a raw 32-byte seed.
 *
 * No infrastructure required — runs entirely offline.
 *
 * Run: npm run kms-identity
 */

import { deriveFromKmsSeed, KmsIdentityError } from '@toon-protocol/core';
import { generateMnemonic, fromMnemonic } from '@toon-protocol/sdk';
import { finalizeEvent, verifyEvent } from 'nostr-tools/pure';

async function main() {
  console.log('=== TOON: KMS Identity (Nautilus Pipeline) ===\n');

  // --- 1. Derive from mnemonic (same NIP-06 path as KMS) ---
  console.log('Step 1: Derive identity from BIP-39 mnemonic...\n');

  const mnemonic = generateMnemonic();
  console.log(`  Mnemonic:    ${mnemonic}`);

  const kmsKeypair = deriveFromKmsSeed(new Uint8Array(32), { mnemonic });
  console.log(`  Pubkey:      ${kmsKeypair.pubkey}`);
  console.log(
    `  Secret key:  ${Buffer.from(kmsKeypair.secretKey).toString('hex').slice(0, 16)}...`
  );
  console.log(`  Path:        m/44'/1237'/0'/0/0 (NIP-06)\n`);

  // --- 2. Verify determinism (same seed = same key) ---
  console.log('Step 2: Verify deterministic derivation...\n');

  const keypair2 = deriveFromKmsSeed(new Uint8Array(32), { mnemonic });
  const match = kmsKeypair.pubkey === keypair2.pubkey;
  console.log(`  Derivation 1: ${kmsKeypair.pubkey.slice(0, 24)}...`);
  console.log(`  Derivation 2: ${keypair2.pubkey.slice(0, 24)}...`);
  console.log(
    `  Match:        ${match ? 'YES (deterministic)' : 'NO (ERROR!)'}\n`
  );

  // --- 3. Cross-verify with SDK fromMnemonic (same path) ---
  console.log('Step 3: Cross-verify with SDK fromMnemonic()...\n');

  const sdkIdentity = fromMnemonic(mnemonic);
  const crossMatch = kmsKeypair.pubkey === sdkIdentity.pubkey;
  console.log(`  Core KMS:     ${kmsKeypair.pubkey.slice(0, 24)}...`);
  console.log(`  SDK:          ${sdkIdentity.pubkey.slice(0, 24)}...`);
  console.log(
    `  Match:        ${crossMatch ? 'YES (same NIP-06 path)' : 'NO (path mismatch!)'}`
  );
  console.log(`  SDK also has: evmAddress = ${sdkIdentity.evmAddress}\n`);

  // --- 4. Sign and verify a Nostr event ---
  console.log('Step 4: Sign a Nostr event with KMS-derived key...\n');

  const event = finalizeEvent(
    {
      kind: 1,
      content: 'Hello from a KMS-derived identity!',
      tags: [],
      created_at: Math.floor(Date.now() / 1000),
    },
    kmsKeypair.secretKey
  );

  const valid = verifyEvent(event);
  console.log(`  Event ID:    ${event.id.slice(0, 24)}...`);
  console.log(`  Pubkey:      ${event.pubkey.slice(0, 24)}...`);
  console.log(`  Signature:   ${event.sig.slice(0, 24)}...`);
  console.log(`  Verified:    ${valid}\n`);

  // --- 5. Raw 32-byte seed (simulating real KMS output) ---
  console.log('Step 5: Derive from raw 32-byte seed (real KMS path)...\n');

  const rawSeed = new Uint8Array(32);
  crypto.getRandomValues(rawSeed);
  const rawKeypair = deriveFromKmsSeed(rawSeed);
  console.log(
    `  Seed:        ${Buffer.from(rawSeed).toString('hex').slice(0, 24)}...`
  );
  console.log(`  Pubkey:      ${rawKeypair.pubkey}`);
  console.log(`  Path:        m/44'/1237'/0'/0/0 (same NIP-06 path)\n`);

  // --- 6. Error handling (KMS unavailable) ---
  console.log('Step 6: KMS unavailable error handling...\n');

  try {
    deriveFromKmsSeed(null as unknown as Uint8Array);
    console.log('  ERROR: Should have thrown!');
  } catch (err) {
    if (err instanceof KmsIdentityError) {
      console.log(`  Caught KmsIdentityError: ${err.message}`);
      console.log(`  Error code:              ${err.code}`);
      console.log('  No random key fallback — clear error for operators.\n');
    }
  }

  // --- Summary ---
  console.log('=== KMS Identity Summary ===\n');
  console.log('  deriveFromKmsSeed() (Story 4.4):');
  console.log(
    '    Derives Nostr keypair from raw 32-byte seed or BIP-39 mnemonic.'
  );
  console.log("    Uses NIP-06 path: m/44'/1237'/0'/0/0 (same as SDK).\n");
  console.log('  In production (Marlin Oyster CVM):');
  console.log('    1. Enclave boots with valid PCR values');
  console.log(
    '    2. KMS root servers verify attestation via KmsRoot contract'
  );
  console.log('    3. DKG-encrypted seed decrypted and injected into enclave');
  console.log('    4. deriveFromKmsSeed(rawSeed) produces the node identity');
  console.log(
    '    5. If code changes -> PCR changes -> seed inaccessible -> identity lost'
  );
  console.log('    => Identity proves code integrity.\n');
}

main().catch((err) => {
  console.error('Fatal:', err);
  process.exit(1);
});
