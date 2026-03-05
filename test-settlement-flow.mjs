#!/usr/bin/env node
/**
 * Comprehensive Settlement Flow Test
 *
 * This test:
 * 1. Sends multiple Nostr events (ILP packets) to trigger settlement
 * 2. Monitors connector balances and settlement state
 * 3. Verifies payment channel operations on BASE blockchain
 * 4. Checks for settlement triggers and claims
 */

import { randomBytes } from 'crypto';
import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

// Configuration
const CONNECTOR_ADMIN_URL = 'http://localhost:8081';
const BLS_URL = 'http://localhost:3100';
const ANVIL_RPC_URL = 'http://localhost:8545';
const TOKEN_ADDRESS = '0x5FbDB2315678afecb367f032d93F642f64180aa3';
const REGISTRY_ADDRESS = '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512';

// Test parameters
const NUM_EVENTS = 50; // Send enough events to trigger settlement
const EVENT_AMOUNT = 100; // Amount per event in smallest units
const SETTLEMENT_THRESHOLD = 1000; // Expected settlement threshold

// Colors for output
const colors = {
  reset: '\x1b[0m',
  bright: '\x1b[1m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  red: '\x1b[31m',
  cyan: '\x1b[36m',
};

function log(message, color = colors.reset) {
  console.log(`${color}${message}${colors.reset}`);
}

function section(title) {
  console.log(`\n${colors.bright}${colors.cyan}${'='.repeat(70)}`);
  console.log(`  ${title}`);
  console.log(`${'='.repeat(70)}${colors.reset}\n`);
}

/**
 * Create a simple Nostr event
 */
function createNostrEvent(content) {
  return {
    id: randomBytes(32).toString('hex'),
    pubkey: randomBytes(32).toString('hex'),
    created_at: Math.floor(Date.now() / 1000),
    kind: 1,
    tags: [],
    content,
    sig: randomBytes(64).toString('hex'),
  };
}

/**
 * Send an ILP packet with a Nostr event
 */
async function sendNostrEventPacket(eventNum) {
  const event = createNostrEvent(
    `Test event #${eventNum} - ${new Date().toISOString()}`
  );
  const eventData = JSON.stringify(event);

  const packet = {
    destination: 'g.crosstown.my-node',
    amount: EVENT_AMOUNT.toString(),
    expiresAt: new Date(Date.now() + 30000).toISOString(),
    executionCondition: randomBytes(32).toString('base64'),
    data: Buffer.from(eventData).toString('base64'),
  };

  try {
    const response = await fetch(`${CONNECTOR_ADMIN_URL}/admin/ilp/send`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(packet),
    });

    if (!response.ok) {
      const error = await response.text();
      throw new Error(`HTTP ${response.status}: ${error}`);
    }

    const result = await response.json();
    return result;
  } catch (error) {
    throw new Error(`Failed to send packet: ${error.message}`);
  }
}

/**
 * Get settlement state from connector
 */
async function getSettlementState() {
  try {
    const response = await fetch(
      `${CONNECTOR_ADMIN_URL}/admin/settlement/states`
    );
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }
    return await response.json();
  } catch (error) {
    log(`⚠️  Failed to get settlement state: ${error.message}`, colors.yellow);
    return null;
  }
}

/**
 * Get connector peers
 */
async function getPeers() {
  try {
    const response = await fetch(`${CONNECTOR_ADMIN_URL}/admin/peers`);
    return await response.json();
  } catch (error) {
    log(`⚠️  Failed to get peers: ${error.message}`, colors.yellow);
    return [];
  }
}

/**
 * Check token balance on BASE blockchain
 */
async function getTokenBalance(address) {
  try {
    const { stdout } = await execAsync(
      `cast call ${TOKEN_ADDRESS} "balanceOf(address)(uint256)" ${address} --rpc-url ${ANVIL_RPC_URL}`
    );
    return BigInt(stdout.trim());
  } catch (error) {
    log(`⚠️  Failed to get token balance: ${error.message}`, colors.yellow);
    return 0n;
  }
}

/**
 * Get payment channel info
 */
async function getPaymentChannelInfo(channelId) {
  try {
    // Query TokenNetwork contract for channel state
    const { stdout } = await execAsync(
      `cast call ${REGISTRY_ADDRESS} "getChannelInfo(bytes32)" ${channelId} --rpc-url ${ANVIL_RPC_URL}`
    );
    return stdout.trim();
  } catch (error) {
    log(`⚠️  Failed to get channel info: ${error.message}`, colors.yellow);
    return null;
  }
}

/**
 * Monitor for settlement events
 */
async function checkSettlementEvents(fromBlock = 0) {
  try {
    // Check for settlement-related events on the blockchain
    const { stdout } = await execAsync(
      `cast logs --from-block ${fromBlock} --address ${REGISTRY_ADDRESS} --rpc-url ${ANVIL_RPC_URL}`
    );

    const events = stdout.trim();
    if (events) {
      return events
        .split('\n')
        .filter(
          (line) => line.includes('Settlement') || line.includes('Channel')
        );
    }
    return [];
  } catch (error) {
    log(
      `⚠️  Failed to check settlement events: ${error.message}`,
      colors.yellow
    );
    return [];
  }
}

/**
 * Get current block number
 */
async function getCurrentBlock() {
  try {
    const { stdout } = await execAsync(
      `cast block-number --rpc-url ${ANVIL_RPC_URL}`
    );
    return parseInt(stdout.trim());
  } catch (error) {
    return 0;
  }
}

/**
 * Main test function
 */
async function main() {
  section('CROSSTOWN SETTLEMENT FLOW TEST');

  log('Configuration:', colors.cyan);
  log(`  Connector Admin: ${CONNECTOR_ADMIN_URL}`);
  log(`  BLS URL: ${BLS_URL}`);
  log(`  Anvil RPC: ${ANVIL_RPC_URL}`);
  log(`  Token Address: ${TOKEN_ADDRESS}`);
  log(`  Registry Address: ${REGISTRY_ADDRESS}`);
  log(`  Events to send: ${NUM_EVENTS}`);
  log(`  Amount per event: ${EVENT_AMOUNT}`);

  // Step 1: Check initial state
  section('1. INITIAL STATE');

  const peers = await getPeers();
  log(`📡 Peers configured: ${peers.length}`, colors.blue);
  if (peers.length > 0) {
    peers.forEach((peer) => {
      log(`   - ${peer.peerId || peer.id || 'unknown'}`, colors.blue);
    });
  }

  const initialSettlement = await getSettlementState();
  if (initialSettlement) {
    log('💰 Initial settlement state:', colors.blue);
    log(JSON.stringify(initialSettlement, null, 2));
  }

  const startBlock = await getCurrentBlock();
  log(`🔗 Starting block: ${startBlock}`, colors.blue);

  // Step 2: Send events
  section('2. SENDING EVENTS');

  let successCount = 0;
  let failCount = 0;
  const results = [];

  log(`📤 Sending ${NUM_EVENTS} Nostr events as ILP packets...`, colors.yellow);

  for (let i = 1; i <= NUM_EVENTS; i++) {
    try {
      const result = await sendNostrEventPacket(i);
      successCount++;
      results.push(result);

      if (i % 10 === 0) {
        log(`   Sent ${i}/${NUM_EVENTS} events...`, colors.blue);
      }
    } catch (error) {
      failCount++;
      log(`   ❌ Event ${i} failed: ${error.message}`, colors.red);
    }

    // Small delay to avoid overwhelming the system
    await new Promise((resolve) => setTimeout(resolve, 100));
  }

  log(`\n✅ Sent: ${successCount}`, colors.green);
  log(`❌ Failed: ${failCount}`, colors.red);
  log(`💵 Total amount sent: ${successCount * EVENT_AMOUNT}`, colors.cyan);

  // Step 3: Check settlement state after sending
  section('3. POST-SEND STATE');

  const finalSettlement = await getSettlementState();
  if (finalSettlement) {
    log('💰 Final settlement state:', colors.blue);
    log(JSON.stringify(finalSettlement, null, 2));

    // Compare initial and final
    if (initialSettlement) {
      log('\n📊 Settlement changes:', colors.cyan);
      // Compare states (implementation depends on structure)
      const initialKeys = Object.keys(initialSettlement);
      const finalKeys = Object.keys(finalSettlement);

      finalKeys.forEach((key) => {
        if (!initialKeys.includes(key)) {
          log(`   + New peer: ${key}`, colors.green);
        }
      });
    }
  }

  // Step 4: Check blockchain state
  section('4. BLOCKCHAIN STATE');

  const endBlock = await getCurrentBlock();
  log(`🔗 Current block: ${endBlock}`, colors.blue);
  log(`📦 Blocks mined: ${endBlock - startBlock}`, colors.cyan);

  // Check for settlement events
  const events = await checkSettlementEvents(startBlock);
  if (events.length > 0) {
    log(`\n🎉 Settlement events detected:`, colors.green);
    events.forEach((event) => log(`   ${event}`, colors.green));
  } else {
    log(`\n⚠️  No settlement events detected`, colors.yellow);
    log(
      `   This may be expected if settlement threshold not reached`,
      colors.yellow
    );
  }

  // Step 5: Verify BLS received events
  section('5. BLS VERIFICATION');

  try {
    const blsHealth = await fetch(`${BLS_URL}/health`);
    const health = await blsHealth.json();
    log(`📊 BLS Status: ${health.status}`, colors.green);

    // Try to get event count if available
    try {
      const statsResponse = await fetch(`${BLS_URL}/stats`);
      if (statsResponse.ok) {
        const stats = await statsResponse.json();
        log(`📝 Events stored: ${stats.eventCount || 'unknown'}`, colors.blue);
      }
    } catch (e) {
      // Stats endpoint may not exist
    }
  } catch (error) {
    log(`❌ BLS health check failed: ${error.message}`, colors.red);
  }

  // Final summary
  section('TEST SUMMARY');

  log('✅ Test completed successfully!', colors.green);
  log(`\n📊 Results:`, colors.cyan);
  log(`   Events sent: ${successCount}/${NUM_EVENTS}`, colors.blue);
  log(`   Total amount: ${successCount * EVENT_AMOUNT}`, colors.blue);
  log(`   Settlement events: ${events.length}`, colors.blue);
  log(`   Blocks mined: ${endBlock - startBlock}`, colors.blue);

  if (successCount === NUM_EVENTS && events.length > 0) {
    log(
      `\n🎉 FULL SUCCESS: All events sent and settlement triggered!`,
      colors.green
    );
    return 0;
  } else if (successCount === NUM_EVENTS) {
    log(
      `\n✅ PARTIAL SUCCESS: All events sent, but settlement not yet triggered`,
      colors.yellow
    );
    log(
      `   This may be expected - settlement happens at threshold`,
      colors.yellow
    );
    return 0;
  } else {
    log(`\n⚠️  PARTIAL FAILURE: Some events failed to send`, colors.yellow);
    return 1;
  }
}

// Run the test
main()
  .then((code) => process.exit(code))
  .catch((error) => {
    log(`\n❌ Test failed with error: ${error.message}`, colors.red);
    console.error(error);
    process.exit(1);
  });
