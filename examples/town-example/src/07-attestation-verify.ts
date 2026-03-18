/**
 * Example 07: TEE Attestation Verification
 *
 * Demonstrates Epic 4 TEE attestation features using pure library calls:
 *   - AttestationVerifier: verify PCR values against a known-good registry
 *   - AttestationState: track attestation lifecycle (valid -> stale -> unattested)
 *   - Peer ranking: prefer attested peers over non-attested ones
 *
 * No infrastructure required — this is a pure @toon-protocol/core library demo.
 * All data is mock/simulated to show the verification logic.
 *
 * Run: npm run attestation-verify
 */

import {
  AttestationVerifier,
  type TeeAttestation,
  type PeerDescriptor,
} from '@toon-protocol/core';

// ---------------------------------------------------------------------------
// Mock Data
// ---------------------------------------------------------------------------

// PCR values are SHA-384 hashes (96 hex chars = 48 bytes)
const KNOWN_GOOD_PCR0 = 'a1b2c3d4e5f6'.repeat(16); // 96 chars
const KNOWN_GOOD_PCR1 = 'f1e2d3c4b5a6'.repeat(16);
const KNOWN_GOOD_PCR2 = '112233445566'.repeat(16);

// A rogue PCR that is NOT in our trusted registry
const ROGUE_PCR = '000000000000'.repeat(16);

function createAttestation(overrides: Partial<TeeAttestation> = {}): TeeAttestation {
  return {
    enclave: 'marlin-oyster',
    pcr0: KNOWN_GOOD_PCR0,
    pcr1: KNOWN_GOOD_PCR1,
    pcr2: KNOWN_GOOD_PCR2,
    attestationDoc: Buffer.from('mock-attestation-document').toString('base64'),
    version: '1.0.0',
    ...overrides,
  };
}

async function main() {
  console.log('=== TOON: TEE Attestation Verification ===\n');

  // --- 1. Create verifier with known-good PCR registry ---
  console.log('Step 1: Creating AttestationVerifier with known-good PCRs...\n');

  const knownGoodPcrs = new Map<string, boolean>([
    [KNOWN_GOOD_PCR0, true],
    [KNOWN_GOOD_PCR1, true],
    [KNOWN_GOOD_PCR2, true],
  ]);

  const verifier = new AttestationVerifier({
    knownGoodPcrs,
    validitySeconds: 300,  // 5 minutes
    graceSeconds: 30,      // 30 second grace period
  });

  console.log(`  Registry size: ${knownGoodPcrs.size} trusted PCR values`);
  console.log(`  Validity:      300s (5 minutes)`);
  console.log(`  Grace period:  30s\n`);

  // --- 2. Verify a valid attestation ---
  console.log('Step 2: Verifying a valid attestation...\n');

  const validAttestation = createAttestation();
  const validResult = verifier.verify(validAttestation);

  console.log(`  Enclave:    ${validAttestation.enclave}`);
  console.log(`  PCR0:       ${validAttestation.pcr0.slice(0, 24)}...`);
  console.log(`  PCR1:       ${validAttestation.pcr1.slice(0, 24)}...`);
  console.log(`  PCR2:       ${validAttestation.pcr2.slice(0, 24)}...`);
  console.log(`  Result:     ${validResult.valid ? 'VALID' : 'INVALID'}`);
  console.log('');

  // --- 3. Verify an attestation with a rogue PCR ---
  console.log('Step 3: Verifying attestation with rogue PCR0...\n');

  const rogueAttestation = createAttestation({ pcr0: ROGUE_PCR });
  const rogueResult = verifier.verify(rogueAttestation);

  console.log(`  PCR0:       ${ROGUE_PCR.slice(0, 24)}... (ROGUE)`);
  console.log(`  PCR1:       ${rogueAttestation.pcr1.slice(0, 24)}... (trusted)`);
  console.log(`  PCR2:       ${rogueAttestation.pcr2.slice(0, 24)}... (trusted)`);
  console.log(`  Result:     ${rogueResult.valid ? 'VALID' : 'INVALID'}`);
  if (!rogueResult.valid) {
    console.log(`  Reason:     ${rogueResult.reason}`);
  }
  console.log('');

  // --- 4. Attestation state lifecycle ---
  console.log('Step 4: Attestation state lifecycle...\n');

  const baseTime = 1700000000; // Fixed timestamp for demo

  // Just attested (within validity period)
  const freshState = verifier.getAttestationState(
    validAttestation,
    baseTime,
    baseTime + 100  // 100s after attestation
  );
  console.log(`  T+100s (within validity):  ${freshState}`);

  // At the boundary (exactly at validity expiry)
  const boundaryState = verifier.getAttestationState(
    validAttestation,
    baseTime,
    baseTime + 300  // Exactly at validity boundary
  );
  console.log(`  T+300s (validity boundary): ${boundaryState}`);

  // In grace period (after validity, before full expiry)
  const staleState = verifier.getAttestationState(
    validAttestation,
    baseTime,
    baseTime + 310  // 10s into grace period
  );
  console.log(`  T+310s (grace period):     ${staleState}`);

  // Expired (past grace period)
  const expiredState = verifier.getAttestationState(
    validAttestation,
    baseTime,
    baseTime + 400  // Well past grace period
  );
  console.log(`  T+400s (expired):          ${expiredState}`);

  console.log('');
  console.log('  State transitions: VALID -> STALE -> UNATTESTED');
  console.log(`  VALID:      attestedAt to attestedAt + ${300}s`);
  console.log(`  STALE:      attestedAt + ${300}s to attestedAt + ${300 + 30}s`);
  console.log(`  UNATTESTED: after attestedAt + ${300 + 30}s\n`);

  // --- 5. Peer ranking by attestation status ---
  console.log('Step 5: Peer ranking (attested peers preferred)...\n');

  const peers: PeerDescriptor[] = [
    {
      pubkey: 'aa'.repeat(32),
      relayUrl: 'wss://peer-a.example.com',
      attested: false,
    },
    {
      pubkey: 'bb'.repeat(32),
      relayUrl: 'wss://peer-b.example.com',
      attested: true,
      attestationTimestamp: baseTime,
    },
    {
      pubkey: 'cc'.repeat(32),
      relayUrl: 'wss://peer-c.example.com',
      attested: false,
    },
    {
      pubkey: 'dd'.repeat(32),
      relayUrl: 'wss://peer-d.example.com',
      attested: true,
      attestationTimestamp: baseTime - 100,
    },
  ];

  console.log('  Before ranking:');
  for (const p of peers) {
    console.log(`    ${p.pubkey.slice(0, 8)}... attested=${p.attested} ${p.relayUrl}`);
  }

  const ranked = verifier.rankPeers(peers);

  console.log('\n  After ranking (attested first):');
  for (const p of ranked) {
    console.log(`    ${p.pubkey.slice(0, 8)}... attested=${p.attested} ${p.relayUrl}`);
  }

  console.log('');

  // --- 6. Summary ---
  console.log('=== TEE Attestation Summary ===');
  console.log('');
  console.log('  AttestationVerifier (Epic 4, Story 4-3):');
  console.log('    Verifies PCR values against a known-good registry.');
  console.log('    ALL three PCRs (pcr0, pcr1, pcr2) must match trusted values.');
  console.log('');
  console.log('  AttestationState lifecycle:');
  console.log('    VALID      -> Fresh attestation, full trust');
  console.log('    STALE      -> Expired but in grace period, degraded trust');
  console.log('    UNATTESTED -> Expired or never attested, no trust');
  console.log('');
  console.log('  Peer ranking:');
  console.log('    Attested peers are preferred for routing but non-attested');
  console.log('    peers remain connectable. Attestation is preference, not gate.');
  console.log('');
  console.log('  In production (Marlin Oyster CVM):');
  console.log('    Nodes publish kind:10033 attestation events with real PCR');
  console.log('    values from the TEE hardware. Peers verify these before');
  console.log('    establishing payment channels.');
}

main().catch((err) => {
  console.error('Fatal:', err);
  process.exit(1);
});
