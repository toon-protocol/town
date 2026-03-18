/**
 * Example 06: Service Discovery + Enriched Health
 *
 * Demonstrates Epic 3 service discovery features:
 *   - Enriched /health endpoint (Story 3.6): returns chain config, pricing,
 *     capabilities, x402 status, TEE attestation, and runtime state
 *   - kind:10035 service discovery events (Story 3.5): published to the relay
 *     at startup with node capabilities and chain information
 *
 * These features allow clients and peers to discover what a node offers
 * before attempting to interact with it.
 *
 * No external infrastructure required — runs with an embedded connector.
 *
 * Run: npm run service-discovery
 */

import { startTown, type TownInstance } from '@toon-protocol/town';
import { ConnectorNode } from '@toon-protocol/connector';
import { SERVICE_DISCOVERY_KIND } from '@toon-protocol/core';
import { shallowParseToon } from '@toon-protocol/core';
import WebSocket from 'ws';
import pino from 'pino';

/**
 * Query a relay for events via WebSocket.
 */
async function queryRelay(
  url: string,
  filter: Record<string, unknown>,
  timeoutMs = 5000
): Promise<unknown[]> {
  return new Promise((resolve) => {
    const events: unknown[] = [];
    const ws = new WebSocket(url);
    const subId = `query-${Date.now()}`;

    const timer = setTimeout(() => { ws.close(); resolve(events); }, timeoutMs);

    ws.on('open', () => {
      ws.send(JSON.stringify(['REQ', subId, filter]));
    });

    ws.on('message', (data: Buffer) => {
      try {
        const msg = JSON.parse(data.toString());
        if (Array.isArray(msg)) {
          if (msg[0] === 'EVENT' && msg[1] === subId) {
            // Relay returns TOON strings in EVENT messages.
            // Use shallowParseToon for routing metadata, then decode
            // the content field from the raw TOON text.
            const raw = msg[2];
            if (typeof raw === 'object' && raw !== null) {
              // Already a parsed object (shouldn't happen but handle it)
              events.push(raw);
            } else if (typeof raw === 'string') {
              // TOON string — extract fields via regex for display
              events.push(raw);
            } else {
              events.push(raw);
            }
          } else if (msg[0] === 'EOSE' && msg[1] === subId) {
            clearTimeout(timer);
            ws.close();
            resolve(events);
          }
        }
      } catch { /* ignore parse errors */ }
    });

    ws.on('error', () => { clearTimeout(timer); resolve(events); });
  });
}

async function main() {
  console.log('=== TOON Town: Service Discovery + Enriched Health ===\n');

  const logger = pino({ level: 'silent' });
  let town: TownInstance | null = null;
  let connector: ConnectorNode | null = null;

  try {
    // --- 1. Start Town ---
    console.log('Step 1: Starting town node...');

    connector = new ConnectorNode({
      nodeId: 'discovery-demo',
      btpServerPort: 4700,
      healthCheckPort: 4780,
      environment: 'development',
      deploymentMode: 'standalone',
      adminApi: { enabled: true, port: 4781 },
      localDelivery: {
        enabled: true,
        handlerUrl: 'http://localhost:3700',
      },
      peers: [],
      routes: [],
    }, logger);
    await connector.start();

    town = await startTown({
      mnemonic: 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
      relayPort: 7700,
      blsPort: 3700,
      connectorUrl: 'http://localhost:4780',
      connectorAdminUrl: 'http://localhost:4781',
      dataDir: '/tmp/toon-example-discovery',
      x402Enabled: true,
      chain: 'anvil',
    });

    console.log(`  Town started (BLS: 3700, Relay: 7700)\n`);

    // --- 2. Enriched Health Endpoint ---
    console.log('Step 2: Fetching enriched /health endpoint...');
    console.log('  GET http://localhost:3700/health\n');

    const healthResp = await fetch('http://localhost:3700/health');
    const health = await healthResp.json() as Record<string, unknown>;

    console.log('  --- Enriched Health Response ---');
    console.log(`  Status:       ${health.status}`);
    console.log(`  Phase:        ${health.phase}`);
    console.log(`  Pubkey:       ${(health.pubkey as string).slice(0, 24)}...`);
    console.log(`  ILP address:  ${health.ilpAddress}`);
    console.log(`  Peers:        ${health.peerCount}`);
    console.log(`  Channels:     ${health.channelCount}`);
    console.log(`  Chain:        ${health.chain}`);
    console.log(`  Version:      ${health.version}`);
    console.log(`  Capabilities: ${JSON.stringify(health.capabilities)}`);

    const pricing = health.pricing as { basePricePerByte: number; currency: string } | undefined;
    if (pricing) {
      console.log(`  Pricing:      ${pricing.basePricePerByte} ${pricing.currency}/byte`);
    }

    const x402 = health.x402 as { enabled: boolean; endpoint: string } | undefined;
    if (x402) {
      console.log(`  x402:         enabled=${x402.enabled}, endpoint=${x402.endpoint}`);
    }

    const tee = health.tee as Record<string, unknown> | undefined;
    if (tee) {
      console.log(`  TEE:          ${tee.enclaveType}, state=${tee.state}`);
    } else {
      console.log(`  TEE:          not running in TEE (field omitted)`);
    }
    console.log('');

    // --- 3. kind:10035 Service Discovery Events ---
    console.log('Step 3: Querying relay for kind:10035 service discovery events...');
    console.log(`  REQ [{ kinds: [${SERVICE_DISCOVERY_KIND}] }] -> ws://localhost:7700\n`);

    // Wait a moment for event storage to complete
    await new Promise((r) => setTimeout(r, 1000));

    const events = await queryRelay('ws://localhost:7700', {
      kinds: [SERVICE_DISCOVERY_KIND],
      limit: 5,
    });

    if (events.length === 0) {
      console.log('  No kind:10035 events found (relay may still be initializing).');
    } else {
      console.log(`  Found ${events.length} service discovery event(s):\n`);

      for (const raw of events) {
        if (typeof raw === 'string') {
          // TOON string from relay — display raw and extract content via shallowParseToon
          console.log('  --- TOON-encoded Service Discovery Event ---');
          console.log(`  Format:     TOON (relay-native format)`);
          console.log(`  Length:     ${raw.length} chars`);

          // shallowParseToon extracts routing metadata without full decode
          try {
            const meta = shallowParseToon(new TextEncoder().encode(raw));
            console.log(`  Event ID:   ${meta.id.slice(0, 16)}...`);
            console.log(`  Author:     ${meta.pubkey.slice(0, 24)}...`);
            console.log(`  Kind:       ${meta.kind}`);
          } catch {
            console.log(`  (shallow parse unavailable for this TOON variant)`);
          }

          // Extract JSON content from TOON text (content appears between delimiters)
          // The TOON format embeds the content field as a JSON string
          const contentMatch = raw.match(/"content"\s*:\s*"((?:[^"\\]|\\.)*)"/);
          if (contentMatch) {
            try {
              const contentStr = JSON.parse(`"${contentMatch[1]}"`);
              const content = JSON.parse(contentStr) as Record<string, unknown>;
              console.log(`  Version:    ${content.version}`);
              console.log(`  Chain:      ${content.chain}`);
              console.log(`  Pricing:    ${JSON.stringify(content.pricing)}`);
              console.log(`  Caps:       ${JSON.stringify(content.capabilities)}`);
              if (content.x402) {
                console.log(`  x402:       ${JSON.stringify(content.x402)}`);
              }
            } catch {
              console.log(`  Content:    (embedded JSON could not be parsed)`);
            }
          }
          console.log('');
        } else {
          // Parsed JSON event (non-TOON relay or decoded)
          const evt = raw as {
            id: string;
            pubkey: string;
            kind: number;
            content: string;
            tags: string[][];
            created_at: number;
          };

          console.log(`  --- Event ${evt.id.slice(0, 16)}... ---`);
          console.log(`  Kind:       ${evt.kind}`);
          console.log(`  Author:     ${evt.pubkey.slice(0, 24)}...`);
          console.log(`  Created:    ${new Date(evt.created_at * 1000).toISOString()}`);

          try {
            const content = JSON.parse(evt.content) as Record<string, unknown>;
            console.log(`  Version:    ${content.version}`);
            console.log(`  Chain:      ${content.chain}`);
            console.log(`  Pricing:    ${JSON.stringify(content.pricing)}`);
            console.log(`  Caps:       ${JSON.stringify(content.capabilities)}`);
            if (content.x402) {
              console.log(`  x402:       ${JSON.stringify(content.x402)}`);
            }
          } catch {
            console.log(`  Content:    (could not parse)`);
          }

          const tagSummary = evt.tags.map(t => `${t[0]}=${t.slice(1).join(',')}`).join(', ');
          console.log(`  Tags:       ${tagSummary}`);
          console.log('');
        }
      }
    }

    // --- 4. Summary ---
    console.log('=== Service Discovery Summary ===');
    console.log('');
    console.log('  Enriched /health (Story 3.6):');
    console.log('    Single HTTP GET returns chain, pricing, capabilities, TEE status.');
    console.log('    Clients can discover node features before interacting.');
    console.log('');
    console.log('  kind:10035 events (Story 3.5):');
    console.log('    Published to relay at startup. Discoverable via standard Nostr');
    console.log('    subscriptions. Mirrors /health fields for relay-based discovery.');
    console.log('');
    console.log('  Together, these provide two discovery paths:');
    console.log('    HTTP:      GET /health (direct, for clients that know the URL)');
    console.log('    Nostr:     REQ { kinds: [10035] } (decentralized, via any relay)');

  } catch (error) {
    console.error('Error:', error);
  } finally {
    console.log('\nStopping...');
    if (town) await town.stop();
    if (connector) await connector.stop();
    console.log('Done.');
    process.exit(0);
  }
}

main().catch((err) => {
  console.error('Fatal:', err);
  process.exit(1);
});
