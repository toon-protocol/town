/**
 * Relay Server Setup
 *
 * Initializes and runs the ILP-gated Nostr relay with:
 * - SqliteEventStore for persistent event storage
 * - PricingService for configurable pricing
 * - BusinessLogicServer for ILP payment verification
 * - NostrRelayServer for WebSocket connections
 */

import { serve, type ServerType } from '@hono/node-server';
import {
  SqliteEventStore,
  PricingService,
  BusinessLogicServer,
  NostrRelayServer,
  type EventStore,
} from '@toon-protocol/relay';

// Default ports for the servers
const DEFAULT_BLS_PORT = 3100;
const DEFAULT_WS_PORT = 7100;

/**
 * Configuration for the relay servers
 */
export interface RelayDemoConfig {
  /** Port for the BLS HTTP server (default: 3000) */
  blsPort?: number;
  /** Port for the WebSocket relay (default: 7000) */
  wsPort?: number;
  /** Base price per byte in smallest units (default: 10) */
  basePricePerByte?: bigint;
  /** Kind-specific price overrides */
  kindOverrides?: Map<number, bigint>;
  /** Owner pubkey for self-write bypass (optional) */
  ownerPubkey?: string;
  /** Use in-memory storage instead of file-based (default: true for demo) */
  inMemory?: boolean;
  /** Path to SQLite database file (only used if inMemory is false) */
  dbPath?: string;
}

/**
 * Running relay servers container
 */
export interface RelayServers {
  /** The event store instance */
  eventStore: EventStore;
  /** The BLS HTTP server */
  blsServer: ServerType;
  /** The WebSocket relay server */
  wsRelay: NostrRelayServer;
  /** Stop all servers gracefully */
  shutdown: () => Promise<void>;
}

/**
 * Start the ILP-gated relay servers.
 *
 * This function initializes and starts both the BLS HTTP server
 * (for payment verification) and the WebSocket relay server
 * (for Nostr event queries).
 *
 * @param config - Optional configuration overrides
 * @returns Object containing server instances and shutdown function
 */
export async function startRelay(
  config: RelayDemoConfig = {}
): Promise<RelayServers> {
  const {
    blsPort = DEFAULT_BLS_PORT,
    wsPort = DEFAULT_WS_PORT,
    basePricePerByte = 10n,
    kindOverrides,
    ownerPubkey,
    inMemory = true,
    dbPath = './relay-events.db',
  } = config;

  // Step 1: Initialize the event store
  // Using in-memory SQLite for demo (no file cleanup needed)
  const dbConnection = inMemory ? ':memory:' : dbPath;
  const eventStore = new SqliteEventStore(dbConnection);
  console.log(
    `[Relay] Initialized ${inMemory ? 'in-memory' : 'file-based'} event store`
  );

  // Step 2: Initialize the pricing service with configurable rates
  const pricingService = new PricingService({
    basePricePerByte,
    kindOverrides,
  });
  console.log(`[Relay] Pricing: ${basePricePerByte} units/byte base rate`);

  // Step 3: Initialize the Business Logic Server
  // This handles ILP payment verification and event storage
  const bls = new BusinessLogicServer(
    {
      basePricePerByte,
      pricingService,
      ownerPubkey,
    },
    eventStore
  );

  if (ownerPubkey) {
    console.log(`[Relay] Owner pubkey configured for self-write bypass`);
  }

  // Step 4: Bind BLS to HTTP server using @hono/node-server
  const blsServer = serve({
    fetch: bls.getApp().fetch,
    port: blsPort,
  });
  console.log(`[Relay] BLS listening on http://localhost:${blsPort}`);

  // Step 5: Initialize and start WebSocket relay
  const wsRelay = new NostrRelayServer({ port: wsPort }, eventStore);
  await wsRelay.start();
  console.log(`[Relay] WebSocket relay listening on ws://localhost:${wsPort}`);

  // Step 6: Create shutdown function for graceful cleanup
  const shutdown = async (): Promise<void> => {
    console.log('[Relay] Shutting down...');
    await wsRelay.stop();
    blsServer.close();
    console.log('[Relay] Shutdown complete');
  };

  return {
    eventStore,
    blsServer,
    wsRelay,
    shutdown,
  };
}

/**
 * Main entry point when running relay.ts directly.
 * Sets up signal handlers for graceful shutdown.
 */
async function main(): Promise<void> {
  console.log('[Relay] Starting ILP-gated Nostr relay...\n');

  const servers = await startRelay();

  // Set up graceful shutdown handlers
  const handleShutdown = async (signal: string): Promise<void> => {
    console.log(`\n[Relay] Received ${signal}`);
    await servers.shutdown();
    process.exit(0);
  };

  process.on('SIGINT', () => handleShutdown('SIGINT'));
  process.on('SIGTERM', () => handleShutdown('SIGTERM'));

  console.log('\n[Relay] Ready to accept connections');
  console.log('[Relay] Press Ctrl+C to stop\n');
}

// Run main if this file is executed directly
// Using import.meta.url to detect direct execution
const isMain =
  typeof process !== 'undefined' &&
  process.argv[1] &&
  import.meta.url.endsWith(process.argv[1].replace(/\\/g, '/'));

if (isMain) {
  main().catch((error) => {
    console.error('[Relay] Fatal error:', error);
    process.exit(1);
  });
}
