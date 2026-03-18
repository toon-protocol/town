/**
 * Example 01: Identity Generation
 *
 * Demonstrates how TOON derives a unified identity from a single
 * secp256k1 key — producing both a Nostr public key (Schnorr/BIP-340)
 * and an EVM address (Keccak-256) from the same secret.
 *
 * No infrastructure required — this runs entirely offline.
 *
 * Run: npm run identity
 */

import { generateMnemonic, fromMnemonic, fromSecretKey } from '@toon-protocol/sdk';
import { generateSecretKey } from 'nostr-tools/pure';

async function main() {
  console.log('=== TOON SDK: Identity Generation ===\n');

  // --- Option A: Generate from a BIP-39 mnemonic ---
  // Mnemonics are human-readable and can derive multiple accounts
  const mnemonic = generateMnemonic();
  console.log('Generated mnemonic:');
  console.log(`  ${mnemonic}\n`);

  const identity = fromMnemonic(mnemonic);
  console.log('Derived identity (account 0):');
  console.log(`  Nostr pubkey:  ${identity.pubkey}`);
  console.log(`  EVM address:   ${identity.evmAddress}`);
  console.log(`  Secret key:    ${Buffer.from(identity.secretKey).toString('hex').slice(0, 16)}...\n`);

  // Derive a second account from the same mnemonic (NIP-06 path)
  const identity2 = fromMnemonic(mnemonic, { accountIndex: 1 });
  console.log('Derived identity (account 1):');
  console.log(`  Nostr pubkey:  ${identity2.pubkey}`);
  console.log(`  EVM address:   ${identity2.evmAddress}\n`);

  // --- Option B: From a raw secret key ---
  // Useful when you already have a nostr-tools keypair
  const rawKey = generateSecretKey();
  const identityFromKey = fromSecretKey(rawKey);
  console.log('Identity from raw secret key:');
  console.log(`  Nostr pubkey:  ${identityFromKey.pubkey}`);
  console.log(`  EVM address:   ${identityFromKey.evmAddress}\n`);

  // --- Key concept ---
  // Both the Nostr pubkey and EVM address come from the SAME secp256k1 key.
  // This means a single wallet controls both your Nostr identity and your
  // on-chain payment channel. No separate key management needed.
  console.log('Key insight: One key, two identities.');
  console.log('  - Nostr uses Schnorr signatures (BIP-340, x-only pubkey)');
  console.log('  - EVM uses ECDSA signatures (Keccak-256 of uncompressed pubkey)');
  console.log('  - Both derived from the same secp256k1 secret key');
}

main().catch(console.error);
