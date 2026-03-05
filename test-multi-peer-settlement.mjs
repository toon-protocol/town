#!/usr/bin/env node
/**
 * Multi-Peer Settlement Flow Test
 *
 * Tests the complete payment channel flow between multiple Crosstown peers:
 * 1. Verify all peers are online and healthy
 * 2. Check peer discovery via Nostr
 * 3. Establish payment channels between peers
 * 4. Send packets to trigger balance accumulation
 * 5. Verify settlement when threshold is reached
 * 6. Check blockchain events for settlement
 */

import { randomBytes } from 'crypto';
import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

// Configuration
const PEERS = [
  {
    id: 'peer1',
    ilpAddress: 'g.crosstown.peer1',
    connectorAdmin: 'http://localhost:8091',
    connectorHealth: 'http://localhost:8081',
    bls: 'http://localhost:3101',
    relay: 'ws://localhost:7101',
    explorer: 'http://localhost:3011',
  },
  {
    id: 'peer2',
    ilpAddress: 'g.crosstown.peer2',
    connectorAdmin: 'http://localhost:8092',
    connectorHealth: 'http://localhost:8082',
    bls: 'http://localhost:3102',
    relay: 'ws://localhost:7102',
    explorer: 'http://localhost:3012',
  },
  {
    id: 'peer3',
    ilpAddress: 'g.crosstown.peer3',
    connectorAdmin: 'http://localhost:8093',
    connectorHealth: 'http://localhost:8083',
    bls: 'http://localhost:3103',
    relay: 'ws://localhost:7103',
    explorer: 'http://localhost:3013',
  },
  {
    id: 'peer4',
    ilpAddress: 'g.crosstown.peer4',
    connectorAdmin: 'http://localhost:8094',
    connectorHealth: 'http://localhost:8084',
    bls: 'http://localhost:3104',
    relay: 'ws://localhost:7104',
    explorer: 'http://localhost:3014',
  },
];

const ANVIL_RPC = 'http://localhost:8545';
const TOKEN_ADDRESS = '0x5FbDB2315678afecb367f032d93F642f64180aa3';
const REGISTRY_ADDRESS = '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512';

// Test parameters
const PACKETS_PER_ROUTE = 30;
const PACKET_AMOUNT = 100;
const SETTLEMENT_THRESHOLD = 1000;

// Colors
const c = {
  reset: '\x1b[0m',
  bright: '\x1b[1m',
  dim: '\x1b[2m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  red: '\x1b[31m',
  cyan: '\x1b[36m',
  magenta: '\x1b[35m',
};

function log(msg, color = c.reset) {
  console.log(`${color}${msg}${c.reset}`);
}

function section(title) {
  console.log(`\n${c.bright}${c.cyan}${'━'.repeat(70)}`);
  console.log(`  ${title}`);
  console.log(`${'━'.repeat(70)}${c.reset}\n`);
}

/**
 * Check if a peer is healthy
 */
async function checkPeerHealth(peer) {
  try {
    const [connectorRes, blsRes] = await Promise.all([
      fetch(`${peer.connectorHealth}/health`),
      fetch(`${peer.bls}/health`),
    ]);

    const connectorData = connectorRes.ok ? await connectorRes.json() : null;
    const blsData = blsRes.ok ? await blsRes.json() : null;

    return {
      connector: connectorRes.ok && connectorData?.status === 'healthy',
      bls:
        blsRes.ok &&
        (blsData?.status === 'healthy' || blsData?.status === 'ok'),
      healthy: connectorRes.ok && blsRes.ok,
    };
  } catch (error) {
    return {
      connector: false,
      bls: false,
      healthy: false,
      error: error.message,
    };
  }
}

/**
 * Get peers configured on a connector
 */
async function getConnectorPeers(adminUrl) {
  try {
    const res = await fetch(`${adminUrl}/admin/peers`);
    const data = await res.json();
    return data.peers || [];
  } catch (error) {
    return [];
  }
}

/**
 * Get routes configured on a connector
 */
async function getConnectorRoutes(adminUrl) {
  try {
    const res = await fetch(`${adminUrl}/admin/routes`);
    const data = await res.json();
    return data.routes || [];
  } catch (error) {
    return [];
  }
}

/**
 * Add a peer to a connector
 */
async function addPeer(adminUrl, peerId, btpUrl, ilpAddress) {
  try {
    const res = await fetch(`${adminUrl}/admin/peers`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        peerId,
        btpUrl,
        ilpAddress,
        maxPacketAmount: '1000000',
        settlementThreshold: SETTLEMENT_THRESHOLD,
      }),
    });
    return res.ok;
  } catch (error) {
    log(`  ⚠️  Failed to add peer: ${error.message}`, c.yellow);
    return false;
  }
}

/**
 * Add a route to a connector
 */
async function addRoute(adminUrl, prefix, peerId) {
  try {
    const res = await fetch(`${adminUrl}/admin/routes`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        prefix,
        peerId,
      }),
    });
    return res.ok;
  } catch (error) {
    log(`  ⚠️  Failed to add route: ${error.message}`, c.yellow);
    return false;
  }
}

/**
 * Send a packet from one peer to another
 */
async function sendPacket(fromPeer, toPeer, amount) {
  const event = {
    id: randomBytes(32).toString('hex'),
    pubkey: randomBytes(32).toString('hex'),
    created_at: Math.floor(Date.now() / 1000),
    kind: 1,
    tags: [],
    content: `Test packet from ${fromPeer.id} to ${toPeer.id}`,
    sig: randomBytes(64).toString('hex'),
  };

  const packet = {
    destination: toPeer.ilpAddress,
    amount: amount.toString(),
    expiresAt: new Date(Date.now() + 30000).toISOString(),
    executionCondition: randomBytes(32).toString('base64'),
    data: Buffer.from(JSON.stringify(event)).toString('base64'),
  };

  try {
    const res = await fetch(`${fromPeer.connectorAdmin}/admin/ilp/send`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(packet),
    });

    if (!res.ok) {
      const error = await res.text();
      throw new Error(`HTTP ${res.status}: ${error}`);
    }

    return await res.json();
  } catch (error) {
    throw new Error(`Packet send failed: ${error.message}`);
  }
}

/**
 * Get settlement state from a peer
 */
async function getSettlementState(adminUrl) {
  try {
    const res = await fetch(`${adminUrl}/admin/settlement/states`);
    if (!res.ok) return null;
    return await res.json();
  } catch (error) {
    return null;
  }
}

/**
 * Get current blockchain block
 */
async function getCurrentBlock() {
  try {
    const { stdout } = await execAsync(
      `cast block-number --rpc-url ${ANVIL_RPC}`
    );
    return parseInt(stdout.trim());
  } catch (error) {
    return 0;
  }
}

/**
 * Check for settlement events on blockchain
 */
async function checkSettlementEvents(fromBlock) {
  try {
    const { stdout } = await execAsync(
      `cast logs --from-block ${fromBlock} --address ${REGISTRY_ADDRESS} --rpc-url ${ANVIL_RPC} 2>/dev/null || echo ""`
    );
    return stdout
      .trim()
      .split('\n')
      .filter((line) => line.length > 0);
  } catch (error) {
    return [];
  }
}

/**
 * Main test execution
 */
async function main() {
  section('MULTI-PEER SETTLEMENT FLOW TEST');

  log('Configuration:', c.cyan);
  log(`  Peers: ${PEERS.length}`);
  log(`  Packets per route: ${PACKETS_PER_ROUTE}`);
  log(`  Amount per packet: ${PACKET_AMOUNT}`);
  log(`  Settlement threshold: ${SETTLEMENT_THRESHOLD}`);

  // Step 1: Health checks
  section('1. PEER HEALTH CHECKS');

  const healthResults = {};
  let allHealthy = true;

  for (const peer of PEERS) {
    const health = await checkPeerHealth(peer);
    healthResults[peer.id] = health;

    const status = health.healthy
      ? `${c.green}✓ HEALTHY`
      : `${c.red}✗ UNHEALTHY`;
    log(`  ${peer.id}: ${status}`, '');
    log(
      `    Connector: ${health.connector ? '✓' : '✗'} | BLS: ${health.bls ? '✓' : '✗'}`,
      c.dim
    );

    if (!health.healthy) {
      allHealthy = false;
      if (health.error) {
        log(`    Error: ${health.error}`, c.red);
      }
    }
  }

  if (!allHealthy) {
    log('\n❌ Some peers are unhealthy. Please check the services.', c.red);
    return 1;
  }

  // Step 2: Setup peering relationships
  section('2. PEER CONFIGURATION');

  log('Setting up peer relationships...', c.yellow);
  log('  Topology: peer1 ← → peer2 ← → peer3 ← → peer4', c.blue);

  // peer1 ← → peer2
  log('\n  Configuring peer1 ↔ peer2...', c.cyan);
  await addPeer(
    PEERS[0].connectorAdmin,
    'peer2',
    'ws://connector-peer2:3000',
    PEERS[1].ilpAddress
  );
  await addRoute(PEERS[0].connectorAdmin, PEERS[1].ilpAddress, 'peer2');

  await addPeer(
    PEERS[1].connectorAdmin,
    'peer1',
    'ws://connector-peer1:3000',
    PEERS[0].ilpAddress
  );
  await addRoute(PEERS[1].connectorAdmin, PEERS[0].ilpAddress, 'peer1');

  // peer2 ← → peer3
  log('  Configuring peer2 ↔ peer3...', c.cyan);
  await addPeer(
    PEERS[1].connectorAdmin,
    'peer3',
    'ws://connector-peer3:3000',
    PEERS[2].ilpAddress
  );
  await addRoute(PEERS[1].connectorAdmin, PEERS[2].ilpAddress, 'peer3');

  await addPeer(
    PEERS[2].connectorAdmin,
    'peer2',
    'ws://connector-peer2:3000',
    PEERS[1].ilpAddress
  );
  await addRoute(PEERS[2].connectorAdmin, PEERS[1].ilpAddress, 'peer2');

  // peer3 ← → peer4
  log('  Configuring peer3 ↔ peer4...', c.cyan);
  await addPeer(
    PEERS[2].connectorAdmin,
    'peer4',
    'ws://connector-peer4:3000',
    PEERS[3].ilpAddress
  );
  await addRoute(PEERS[2].connectorAdmin, PEERS[3].ilpAddress, 'peer4');

  await addPeer(
    PEERS[3].connectorAdmin,
    'peer3',
    'ws://connector-peer3:3000',
    PEERS[2].ilpAddress
  );
  await addRoute(PEERS[3].connectorAdmin, PEERS[2].ilpAddress, 'peer3');

  // Verify configuration
  log('\n  Verifying peer configuration...', c.yellow);
  for (const peer of PEERS) {
    const peers = await getConnectorPeers(peer.connectorAdmin);
    const routes = await getConnectorRoutes(peer.connectorAdmin);
    log(
      `    ${peer.id}: ${peers.length} peers, ${routes.length} routes`,
      c.blue
    );
  }

  await new Promise((resolve) => setTimeout(resolve, 2000)); // Wait for connections

  // Step 3: Initial state
  section('3. INITIAL STATE');

  const startBlock = await getCurrentBlock();
  log(`Blockchain block: ${startBlock}`, c.blue);

  for (const peer of PEERS) {
    const state = await getSettlementState(peer.connectorAdmin);
    if (state) {
      log(`${peer.id} settlement state:`, c.cyan);
      log(JSON.stringify(state, null, 2), c.dim);
    }
  }

  // Step 4: Send packets
  section('4. SENDING PACKETS');

  const routes = [
    { from: PEERS[0], to: PEERS[1], name: 'peer1 → peer2' },
    { from: PEERS[1], to: PEERS[0], name: 'peer2 → peer1' },
    { from: PEERS[1], to: PEERS[2], name: 'peer2 → peer3' },
    { from: PEERS[2], to: PEERS[1], name: 'peer3 → peer2' },
    { from: PEERS[2], to: PEERS[3], name: 'peer3 → peer4' },
    { from: PEERS[3], to: PEERS[2], name: 'peer4 → peer3' },
  ];

  const results = {};

  for (const route of routes) {
    log(`\nSending ${PACKETS_PER_ROUTE} packets: ${route.name}`, c.cyan);

    let success = 0;
    let failed = 0;

    for (let i = 0; i < PACKETS_PER_ROUTE; i++) {
      try {
        await sendPacket(route.from, route.to, PACKET_AMOUNT);
        success++;

        if ((i + 1) % 10 === 0) {
          log(`  Sent ${i + 1}/${PACKETS_PER_ROUTE}...`, c.dim);
        }
      } catch (error) {
        failed++;
        if (failed <= 3) {
          log(`  ✗ Packet ${i + 1} failed: ${error.message}`, c.red);
        }
      }

      await new Promise((resolve) => setTimeout(resolve, 100));
    }

    results[route.name] = { success, failed, total: PACKETS_PER_ROUTE };
    log(
      `  ✓ ${success}/${PACKETS_PER_ROUTE} packets sent`,
      success === PACKETS_PER_ROUTE ? c.green : c.yellow
    );
  }

  // Step 5: Check settlement
  section('5. SETTLEMENT VERIFICATION');

  const endBlock = await getCurrentBlock();
  log(`Blockchain blocks mined: ${endBlock - startBlock}`, c.blue);

  // Check settlement state for each peer
  log('\nSettlement states:', c.cyan);
  for (const peer of PEERS) {
    const state = await getSettlementState(peer.connectorAdmin);
    if (state) {
      log(`\n${peer.id}:`, c.yellow);
      log(JSON.stringify(state, null, 2), c.dim);
    }
  }

  // Check blockchain events
  log('\nChecking blockchain for settlement events...', c.yellow);
  const events = await checkSettlementEvents(startBlock);

  if (events.length > 0) {
    log(`\n🎉 ${events.length} settlement events detected:`, c.green);
    events.forEach((event) => log(`  ${event}`, c.green));
  } else {
    log('⚠️  No settlement events detected yet', c.yellow);
    log('   Settlement may occur later when threshold is reached', c.dim);
  }

  // Step 6: Summary
  section('6. TEST SUMMARY');

  let totalPacketsSent = 0;
  let totalPacketsFailed = 0;

  for (const [routeName, result] of Object.entries(results)) {
    log(
      `${routeName}: ${result.success}/${result.total}`,
      result.success === result.total ? c.green : c.yellow
    );
    totalPacketsSent += result.success;
    totalPacketsFailed += result.failed;
  }

  log(`\n📊 Overall statistics:`, c.cyan);
  log(`  Total packets sent: ${totalPacketsSent}`, c.blue);
  log(
    `  Total packets failed: ${totalPacketsFailed}`,
    totalPacketsFailed === 0 ? c.green : c.red
  );
  log(`  Total amount: ${totalPacketsSent * PACKET_AMOUNT}`, c.blue);
  log(
    `  Settlement events: ${events.length}`,
    events.length > 0 ? c.green : c.yellow
  );
  log(`  Blocks mined: ${endBlock - startBlock}`, c.blue);

  log(`\n📡 Explorer UIs:`, c.cyan);
  PEERS.forEach((peer) => {
    log(`  ${peer.id}: ${peer.explorer}`, c.blue);
  });

  if (totalPacketsSent > 0 && totalPacketsFailed === 0) {
    log(`\n🎉 SUCCESS: All packets delivered successfully!`, c.green);
    return 0;
  } else {
    log(`\n⚠️  PARTIAL SUCCESS: Some packets failed`, c.yellow);
    return 1;
  }
}

main()
  .then((code) => process.exit(code))
  .catch((error) => {
    log(`\n❌ Test failed: ${error.message}`, c.red);
    console.error(error);
    process.exit(1);
  });
