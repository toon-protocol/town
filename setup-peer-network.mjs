#!/usr/bin/env node
/**
 * Setup Peer Network with Payment Channels
 *
 * This script:
 * 1. Configures peer relationships
 * 2. Adds routes for packet forwarding
 * 3. Creates payment channels on BASE blockchain
 * 4. Verifies the setup
 */

const PEERS = [
  {
    id: 'peer1',
    ilpAddress: 'g.crosstown.peer1',
    adminUrl: 'http://localhost:8091',
    btpUrl: 'ws://connector-peer1:3000',
    evmAddress: '0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC', // Anvil account #2
  },
  {
    id: 'peer2',
    ilpAddress: 'g.crosstown.peer2',
    adminUrl: 'http://localhost:8092',
    btpUrl: 'ws://connector-peer2:3000',
    evmAddress: '0x90F79bf6EB2c4f870365E785982E1f101E93b906', // Anvil account #3
  },
  {
    id: 'peer3',
    ilpAddress: 'g.crosstown.peer3',
    adminUrl: 'http://localhost:8093',
    btpUrl: 'ws://connector-peer3:3000',
    evmAddress: '0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65', // Anvil account #4
  },
  {
    id: 'peer4',
    ilpAddress: 'g.crosstown.peer4',
    adminUrl: 'http://localhost:8094',
    btpUrl: 'ws://connector-peer4:3000',
    evmAddress: '0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc', // Anvil account #5
  },
];

const SETTLEMENT_THRESHOLD = '1000';
const MAX_PACKET_AMOUNT = '1000000';

async function addPeer(fromPeer, toPeer) {
  try {
    const response = await fetch(`${fromPeer.adminUrl}/admin/peers`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        peerId: toPeer.id,
        btpUrl: toPeer.btpUrl,
        ilpAddress: toPeer.ilpAddress,
        maxPacketAmount: MAX_PACKET_AMOUNT,
        settlementThreshold: SETTLEMENT_THRESHOLD,
      }),
    });

    const result = await response.json();

    if (response.ok) {
      console.log(`  ✓ ${fromPeer.id} → ${toPeer.id}: peer added`);
      return true;
    } else {
      console.log(
        `  ✗ ${fromPeer.id} → ${toPeer.id}: ${result.error || result.message}`
      );
      return false;
    }
  } catch (error) {
    console.log(`  ✗ ${fromPeer.id} → ${toPeer.id}: ${error.message}`);
    return false;
  }
}

async function addRoute(fromPeer, toPeer) {
  try {
    const response = await fetch(`${fromPeer.adminUrl}/admin/routes`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        prefix: toPeer.ilpAddress,
        peerId: toPeer.id,
      }),
    });

    const result = await response.json();

    if (response.ok) {
      console.log(`  ✓ ${fromPeer.id} → ${toPeer.id}: route added`);
      return true;
    } else {
      console.log(
        `  ✗ ${fromPeer.id} → ${toPeer.id}: ${result.error || result.message}`
      );
      return false;
    }
  } catch (error) {
    console.log(`  ✗ ${fromPeer.id} → ${toPeer.id}: ${error.message}`);
    return false;
  }
}

async function createPaymentChannel(fromPeer, toPeer) {
  try {
    const response = await fetch(`${fromPeer.adminUrl}/admin/channels`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        peerId: toPeer.id,
        peerAddress: toPeer.evmAddress,
        initialDeposit: '10000', // 10,000 tokens
      }),
    });

    if (!response.ok) {
      const error = await response.text();
      console.log(`  ✗ ${fromPeer.id} ↔ ${toPeer.id}: ${error}`);
      return false;
    }

    const result = await response.json();
    console.log(
      `  ✓ ${fromPeer.id} ↔ ${toPeer.id}: channel created (${result.channelId || 'id pending'})`
    );
    return true;
  } catch (error) {
    console.log(`  ✗ ${fromPeer.id} ↔ ${toPeer.id}: ${error.message}`);
    return false;
  }
}

async function getPeers(peer) {
  try {
    const response = await fetch(`${peer.adminUrl}/admin/peers`);
    const data = await response.json();
    return data.peers || [];
  } catch (error) {
    return [];
  }
}

async function getRoutes(peer) {
  try {
    const response = await fetch(`${peer.adminUrl}/admin/routes`);
    const data = await response.json();
    return data.routes || [];
  } catch (error) {
    return [];
  }
}

async function getChannels(peer) {
  try {
    const response = await fetch(`${peer.adminUrl}/admin/channels`);
    if (!response.ok) return [];
    const data = await response.json();
    return data.channels || [];
  } catch (error) {
    return [];
  }
}

async function main() {
  console.log('╔═══════════════════════════════════════════════════════════╗');
  console.log('║        Crosstown Peer Network Setup                       ║');
  console.log(
    '╚═══════════════════════════════════════════════════════════╝\n'
  );

  // Setup peer relationships: peer1 ↔ peer2 ↔ peer3 ↔ peer4
  const relationships = [
    { from: PEERS[0], to: PEERS[1] }, // peer1 ↔ peer2
    { from: PEERS[1], to: PEERS[0] },
    { from: PEERS[1], to: PEERS[2] }, // peer2 ↔ peer3
    { from: PEERS[2], to: PEERS[1] },
    { from: PEERS[2], to: PEERS[3] }, // peer3 ↔ peer4
    { from: PEERS[3], to: PEERS[2] },
  ];

  // Step 1: Add Peers
  console.log('1. Adding peers...\n');
  for (const rel of relationships) {
    await addPeer(rel.from, rel.to);
  }

  // Small delay for peer connections to establish
  console.log('\n  Waiting for BTP connections...');
  await new Promise((resolve) => setTimeout(resolve, 3000));

  // Step 2: Add Routes
  console.log('\n2. Adding routes...\n');
  for (const rel of relationships) {
    await addRoute(rel.from, rel.to);
  }

  // Step 3: Create Payment Channels (bidirectional)
  console.log('\n3. Creating payment channels...\n');
  const channelPairs = [
    { from: PEERS[0], to: PEERS[1] },
    { from: PEERS[1], to: PEERS[2] },
    { from: PEERS[2], to: PEERS[3] },
  ];

  for (const pair of channelPairs) {
    await createPaymentChannel(pair.from, pair.to);
    await new Promise((resolve) => setTimeout(resolve, 1000));
  }

  // Step 4: Verify Setup
  console.log('\n4. Verifying configuration...\n');

  for (const peer of PEERS) {
    const peers = await getPeers(peer);
    const routes = await getRoutes(peer);
    const channels = await getChannels(peer);

    console.log(`  ${peer.id}:`);
    console.log(
      `    Peers: ${peers.length}, Routes: ${routes.length}, Channels: ${channels.length}`
    );

    if (peers.length > 0) {
      peers.forEach((p) => {
        const status = p.connected ? '✓' : '✗';
        console.log(
          `      ${status} ${p.peerId} (${p.connectionState || 'unknown'})`
        );
      });
    }
  }

  console.log(
    '\n╔═══════════════════════════════════════════════════════════╗'
  );
  console.log('║  Setup Complete! Ready to test settlement.               ║');
  console.log('║                                                           ║');
  console.log('║  Run: node test-multi-peer-settlement.mjs                ║');
  console.log(
    '╚═══════════════════════════════════════════════════════════╝\n'
  );
}

main().catch((error) => {
  console.error('\n❌ Setup failed:', error.message);
  process.exit(1);
});
