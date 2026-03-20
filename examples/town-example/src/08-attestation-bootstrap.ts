/**
 * Example 08: Attestation-First Seed Relay Bootstrap
 *
 * Demonstrates the attestation-first bootstrap flow (Epic 4, Story 4.6):
 *   1. Read seed relay list (kind:10036)
 *   2. Connect to seed relay
 *   3. Query kind:10033 TEE attestation
 *   4. Verify PCR values against known-good registry
 *   5. If valid -> subscribe to kind:10032 peer info -> discover network
 *   6. If invalid -> try next seed relay
 *   7. If all fail -> degraded mode (node starts without attestation trust)
 *
 * This prevents seed relay list poisoning (R-E4-004): a malicious kind:10036
 * pointing to a non-attested node is rejected before any peers are added.
 *
 * No infrastructure required — uses mock DI callbacks to simulate the flow.
 *
 * Run: npm run attestation-bootstrap
 */

import {
  AttestationBootstrap,
  AttestationVerifier,
  buildAttestationEvent,
  parseAttestation,
  type AttestationBootstrapEvent,
  type TeeAttestation,
} from '@toon-protocol/core';
import { generateSecretKey, getPublicKey } from 'nostr-tools/pure';
import type { NostrEvent } from 'nostr-tools/pure';

// ---------------------------------------------------------------------------
// Mock infrastructure — simulates what real relay WebSocket calls would do
// ---------------------------------------------------------------------------

// Simulate a TEE-attested seed relay
const SEED_RELAY_KEY = generateSecretKey();
const SEED_RELAY_PUBKEY = getPublicKey(SEED_RELAY_KEY);

const KNOWN_GOOD_PCR0 = 'a1b2c3d4e5f6'.repeat(16);
const KNOWN_GOOD_PCR1 = 'f1e2d3c4b5a6'.repeat(16);
const KNOWN_GOOD_PCR2 = '112233445566'.repeat(16);

const MOCK_ATTESTATION: TeeAttestation = {
  enclave: 'marlin-oyster',
  pcr0: KNOWN_GOOD_PCR0,
  pcr1: KNOWN_GOOD_PCR1,
  pcr2: KNOWN_GOOD_PCR2,
  attestationDoc: Buffer.from('mock-attestation-doc').toString('base64'),
  version: '1.0.0',
};

// Build a signed kind:10033 event from the "seed relay"
const MOCK_ATTESTATION_EVENT = buildAttestationEvent(
  MOCK_ATTESTATION,
  SEED_RELAY_KEY,
  {
    relay: 'wss://seed1.example.com:7100',
    chain: '421614',
    expiry: Math.floor(Date.now() / 1000) + 600,
  }
);

// Mock kind:10032 peer info events that the seed relay would return
const MOCK_PEER_EVENTS: NostrEvent[] = [
  {
    id: 'a'.repeat(64),
    pubkey: 'bb'.repeat(32),
    created_at: Math.floor(Date.now() / 1000),
    kind: 10032,
    content: JSON.stringify({
      ilpAddress: 'g.toon.peer-b',
      btpEndpoint: 'wss://peer-b.example.com:3000',
      assetCode: 'USD',
      assetScale: 6,
    }),
    tags: [],
    sig: 'c'.repeat(128),
  },
];

async function main() {
  console.log('=== TOON: Attestation-First Seed Relay Bootstrap ===\n');

  // --- 1. Setup verifier with known-good PCRs ---
  console.log(
    'Step 1: Create AttestationVerifier with known-good PCR registry...\n'
  );

  const knownGoodPcrs = new Map<string, boolean>([
    [KNOWN_GOOD_PCR0, true],
    [KNOWN_GOOD_PCR1, true],
    [KNOWN_GOOD_PCR2, true],
  ]);

  const verifier = new AttestationVerifier({
    knownGoodPcrs,
    validitySeconds: 300,
    graceSeconds: 30,
  });

  console.log(`  Registry: ${knownGoodPcrs.size} trusted PCR values`);
  console.log(`  Seed relay pubkey: ${SEED_RELAY_PUBKEY.slice(0, 24)}...\n`);

  // --- 2. Happy path: attested seed relay ---
  console.log('Step 2: Bootstrap with an attested seed relay...\n');

  const events: AttestationBootstrapEvent[] = [];
  const bootstrap = new AttestationBootstrap({
    seedRelays: ['wss://seed1.example.com:7100'],
    secretKey: generateSecretKey(),
    verifier: {
      verify: (event: NostrEvent) => {
        const parsed = parseAttestation(event);
        if (!parsed) return { valid: false, reason: 'Failed to parse' };
        return verifier.verify(parsed.attestation);
      },
    },
    queryAttestation: async (relayUrl) => {
      console.log(`    [mock] Querying ${relayUrl} for kind:10033...`);
      // Simulate WebSocket REQ/EVENT for kind:10033
      return MOCK_ATTESTATION_EVENT;
    },
    subscribePeers: async (relayUrl) => {
      console.log(`    [mock] Subscribing to ${relayUrl} for kind:10032...`);
      // Simulate WebSocket REQ/EVENT for kind:10032
      return MOCK_PEER_EVENTS;
    },
  });

  bootstrap.on((event) => {
    events.push(event);
    console.log(`    [event] ${event.type}`);
  });

  const result = await bootstrap.bootstrap();

  console.log(`\n  Result:`);
  console.log(`    Mode:              ${result.mode}`);
  console.log(`    Attested relay:    ${result.attestedSeedRelay}`);
  console.log(`    Discovered peers:  ${result.discoveredPeers.length}`);
  console.log(`    Events emitted:    ${events.length}\n`);

  console.log('  Lifecycle event order:');
  for (const evt of events) {
    console.log(`    ${evt.type}`);
  }
  console.log('');

  // --- 3. Failure path: unattested seed relay ---
  console.log(
    'Step 3: Bootstrap with an unattested seed relay (PCR mismatch)...\n'
  );

  const failEvents: AttestationBootstrapEvent[] = [];
  const failBootstrap = new AttestationBootstrap({
    seedRelays: ['wss://rogue.example.com:7100'],
    secretKey: generateSecretKey(),
    verifier: {
      verify: () => ({ valid: false, reason: 'PCR mismatch' }),
    },
    queryAttestation: async (relayUrl) => {
      console.log(`    [mock] Querying ${relayUrl} for kind:10033...`);
      return MOCK_ATTESTATION_EVENT; // returns event, but verification fails
    },
    subscribePeers: async () => [],
  });

  failBootstrap.on((event) => {
    failEvents.push(event);
    console.log(`    [event] ${event.type}`);
  });

  const failResult = await failBootstrap.bootstrap();

  console.log(`\n  Result:`);
  console.log(`    Mode:              ${failResult.mode}`);
  console.log(
    `    Attested relay:    ${failResult.attestedSeedRelay ?? '(none)'}`
  );
  console.log(`    Discovered peers:  ${failResult.discoveredPeers.length}\n`);

  // --- 4. Fallback path: first relay fails, second succeeds ---
  console.log('Step 4: Fallback — first relay fails, second succeeds...\n');

  const fallbackEvents: AttestationBootstrapEvent[] = [];
  let callCount = 0;

  const fallbackBootstrap = new AttestationBootstrap({
    seedRelays: [
      'wss://rogue.example.com:7100', // will fail
      'wss://trusted.example.com:7100', // will succeed
    ],
    secretKey: generateSecretKey(),
    verifier: {
      verify: (event: NostrEvent) => {
        const parsed = parseAttestation(event);
        if (!parsed) return { valid: false, reason: 'Parse failed' };
        return verifier.verify(parsed.attestation);
      },
    },
    queryAttestation: async (relayUrl) => {
      callCount++;
      console.log(`    [mock] Querying ${relayUrl} (#${callCount})...`);
      if (callCount === 1) return null; // first relay: no attestation
      return MOCK_ATTESTATION_EVENT; // second relay: valid
    },
    subscribePeers: async () => MOCK_PEER_EVENTS,
  });

  fallbackBootstrap.on((event) => {
    fallbackEvents.push(event);
    console.log(`    [event] ${event.type}`);
  });

  const fallbackResult = await fallbackBootstrap.bootstrap();

  console.log(`\n  Result:`);
  console.log(`    Mode:              ${fallbackResult.mode}`);
  console.log(`    Attested relay:    ${fallbackResult.attestedSeedRelay}`);
  console.log(
    `    Discovered peers:  ${fallbackResult.discoveredPeers.length}\n`
  );

  // --- Summary ---
  console.log('=== Attestation-First Bootstrap Summary ===\n');
  console.log('  Trust flow (Story 4.6):');
  console.log('    1. Read kind:10036 seed relay list');
  console.log('    2. Connect to seed relay');
  console.log('    3. Query kind:10033 TEE attestation');
  console.log('    4. Verify PCRs against known-good registry');
  console.log('    5. If valid -> subscribe kind:10032 -> discover peers');
  console.log('    6. If invalid -> try next seed relay');
  console.log('    7. If all fail -> degraded mode (no crash)\n');
  console.log('  Security property:');
  console.log('    Attestation verified BEFORE trusting any peer info.');
  console.log('    Prevents seed relay list poisoning (R-E4-004).\n');
  console.log('  Graceful degradation:');
  console.log('    Node starts even without attested seed relays.');
  console.log('    "Trust degrades; money doesn\'t." (Decision 12)');
}

main().catch((err) => {
  console.error('Fatal:', err);
  process.exit(1);
});
