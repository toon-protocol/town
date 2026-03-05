#!/usr/bin/env node
/**
 * Quick verification that integration test services are working
 */

console.log('🔍 Verifying Integration Test Services\n');

// Check Anvil
console.log('1. Checking Anvil (EVM blockchain)...');
try {
  const anvilResponse = await fetch('http://localhost:8545', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      jsonrpc: '2.0',
      method: 'eth_blockNumber',
      params: [],
      id: 1,
    }),
  });
  const anvilData = await anvilResponse.json();
  console.log('✅ Anvil is responding:', anvilData.result);
} catch (error) {
  console.log('❌ Anvil failed:', error.message);
}

// Check Connector Admin API
console.log('\n2. Checking Connector Admin API...');
try {
  const adminResponse = await fetch('http://localhost:13001/admin/peers');
  const adminData = await adminResponse.json();
  console.log('✅ Connector Admin API is responding');
  console.log('   Peers:', adminData.peers?.length || 0);
} catch (error) {
  console.log('❌ Connector Admin API failed:', error.message);
}

// Check Connector Health
console.log('\n3. Checking Connector Health...');
try {
  const healthResponse = await fetch('http://localhost:13000/health');
  if (healthResponse.ok) {
    console.log('✅ Connector is healthy');
  } else {
    console.log('⚠️  Connector health check returned:', healthResponse.status);
  }
} catch (error) {
  console.log('❌ Connector health check failed:', error.message);
}

// Check Nostr Relay
console.log('\n4. Checking Nostr Relay...');
try {
  const { WebSocket } = await import('ws');
  const ws = new WebSocket('ws://localhost:17000');

  await new Promise((resolve, reject) => {
    const timeout = setTimeout(() => {
      ws.close();
      reject(new Error('Timeout'));
    }, 5000);

    ws.on('open', () => {
      clearTimeout(timeout);
      console.log('✅ Nostr Relay is responding');
      ws.close();
      resolve();
    });

    ws.on('error', (error) => {
      clearTimeout(timeout);
      reject(error);
    });
  });
} catch (error) {
  console.log('❌ Nostr Relay failed:', error.message);
}

console.log('\n✅ Service verification complete!');
console.log('\n📝 Summary:');
console.log('   - Anvil (EVM): http://localhost:8545');
console.log('   - Connector Admin: http://localhost:13001');
console.log('   - Connector BTP: http://localhost:13000');
console.log('   - Nostr Relay: ws://localhost:17000');
