/**
 * Example 05: x402 HTTP Publish — Payment-Gated Event Publishing
 *
 * Demonstrates the x402 protocol flow for publishing Nostr events via HTTP
 * with USDC payment. This is the HTTP on-ramp that lets any HTTP client
 * (AI agents, browsers, CLI tools) publish to the network without
 * understanding ILP.
 *
 * Flow:
 *   1. POST /publish (no X-PAYMENT header) -> 402 with pricing info
 *   2. Client constructs EIP-3009 signed authorization for the required amount
 *   3. POST /publish (with X-PAYMENT header) -> settlement + ILP delivery
 *
 * This example demonstrates steps 1 and 2 (pricing negotiation + EIP-3009
 * authorization signing). Full on-chain settlement requires the client to
 * hold USDC and the contract to support EIP-3009 (transferWithAuthorization).
 * The Anvil mock USDC does not yet implement this (retro A3: FiatTokenV2_2).
 *
 * Requires: Anvil running on localhost:18545 (for chain config resolution)
 *   Start with: ./scripts/sdk-e2e-infra.sh up
 *
 * Run: npm run x402-publish
 */

import { startTown, type TownInstance } from '@crosstown/town';
import { ConnectorNode } from '@crosstown/connector';
import { generateMnemonic, fromMnemonic } from '@crosstown/sdk';
import { finalizeEvent } from 'nostr-tools/pure';
import {
  createWalletClient,
  http,
  defineChain,
  encodePacked,
  keccak256,
} from 'viem';
import { privateKeyToAccount, signTypedData } from 'viem/accounts';
import pino from 'pino';

// ---------------------------------------------------------------------------
// Anvil constants
// ---------------------------------------------------------------------------

const ANVIL_RPC = 'http://localhost:18545';
const TOKEN_ADDRESS = '0x5FbDB2315678afecb367f032d93F642f64180aa3' as const;

// Anvil Account #7 — x402 client (the payer)
const CLIENT_PRIVATE_KEY = '0x4bbbf85ce3377467afe5d46f804f221813b2bb87f24d81f60f1fcdbf7cbf4356' as const;

const anvilChain = defineChain({
  id: 31337,
  name: 'anvil',
  nativeCurrency: { name: 'ETH', symbol: 'ETH', decimals: 18 },
  rpcUrls: { default: { http: [ANVIL_RPC] } },
});

// EIP-3009 typed data types (must match USDC contract)
const EIP_3009_TYPES = {
  TransferWithAuthorization: [
    { name: 'from', type: 'address' },
    { name: 'to', type: 'address' },
    { name: 'value', type: 'uint256' },
    { name: 'validAfter', type: 'uint256' },
    { name: 'validBefore', type: 'uint256' },
    { name: 'nonce', type: 'bytes32' },
  ],
} as const;

async function main() {
  console.log('=== Crosstown Town: x402 HTTP Publish ===\n');

  const logger = pino({ level: 'silent' });
  let town: TownInstance | null = null;
  let connector: ConnectorNode | null = null;

  try {
    // --- 1. Check Anvil ---
    console.log('Step 1: Checking Anvil...');
    try {
      const resp = await fetch(ANVIL_RPC, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ jsonrpc: '2.0', method: 'eth_chainId', params: [], id: 1 }),
      });
      const json = await resp.json() as { result?: string };
      if (parseInt(json.result || '0', 16) !== 31337) throw new Error('Wrong chain');
      console.log('  Anvil running on :18545\n');
    } catch {
      console.error('  Anvil not running! Start it with: ./scripts/sdk-e2e-infra.sh up');
      process.exit(1);
    }

    // --- 2. Start Town with x402 enabled ---
    console.log('Step 2: Starting town node with x402 enabled...');
    const mnemonic = generateMnemonic();

    connector = new ConnectorNode({
      nodeId: 'x402-demo',
      btpServerPort: 4600,
      healthCheckPort: 4680,
      environment: 'development',
      deploymentMode: 'standalone',
      adminApi: { enabled: true, port: 4681 },
      localDelivery: {
        enabled: true,
        handlerUrl: 'http://localhost:3600',
      },
      peers: [],
      routes: [],
    }, logger);
    await connector.start();

    town = await startTown({
      mnemonic,
      relayPort: 7600,
      blsPort: 3600,
      connectorUrl: 'http://localhost:4680',
      connectorAdminUrl: 'http://localhost:4681',
      dataDir: '/tmp/crosstown-example-x402',
      x402Enabled: true,
      chain: 'anvil',
      devMode: true,
    });

    console.log(`  Town started (BLS: 3600, Relay: 7600)`);
    console.log(`  x402 enabled: ${town.config.x402Enabled}`);
    console.log(`  Facilitator:  ${town.evmAddress}\n`);

    // --- 3. Pricing negotiation (402 response) ---
    console.log('Step 3: x402 pricing negotiation...');
    console.log('  POST /publish without X-PAYMENT header\n');

    // Create a signed Nostr event to publish
    const identity = fromMnemonic(mnemonic);
    const event = finalizeEvent({
      kind: 1,
      content: `Hello via x402! Published at ${new Date().toISOString()}`,
      tags: [['protocol', 'x402']],
      created_at: Math.floor(Date.now() / 1000),
    }, identity.secretKey);

    const publishBody = {
      event,
      destination: town.config.ilpAddress,
    };

    // First request: no X-PAYMENT -> get 402 pricing
    const pricingResp = await fetch('http://localhost:3600/publish', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(publishBody),
    });

    console.log(`  Response: HTTP ${pricingResp.status}`);

    if (pricingResp.status !== 402) {
      console.error(`  Expected 402, got ${pricingResp.status}`);
      const body = await pricingResp.text();
      console.error(`  Body: ${body}`);
      return;
    }

    const pricing = await pricingResp.json() as {
      amount: string;
      facilitatorAddress: string;
      paymentNetwork: string;
      chainId: number;
      usdcAddress: string;
    };

    console.log('\n  --- 402 Pricing Response ---');
    console.log(`  Amount:       ${pricing.amount} micro-units`);
    console.log(`  Facilitator:  ${pricing.facilitatorAddress}`);
    console.log(`  Network:      ${pricing.paymentNetwork}`);
    console.log(`  Chain ID:     ${pricing.chainId}`);
    console.log(`  USDC address: ${pricing.usdcAddress}\n`);

    // --- 4. Construct EIP-3009 authorization ---
    console.log('Step 4: Constructing EIP-3009 signed authorization...');

    const clientAccount = privateKeyToAccount(CLIENT_PRIVATE_KEY);
    console.log(`  Payer address: ${clientAccount.address}`);
    console.log(`  Recipient:     ${pricing.facilitatorAddress}`);
    console.log(`  Amount:        ${pricing.amount}\n`);

    // Generate a random nonce (32 bytes)
    const { randomBytes } = await import('node:crypto');
    const nonce = `0x${randomBytes(32).toString('hex')}` as `0x${string}`;

    const now = Math.floor(Date.now() / 1000);
    const validAfter = now - 60;     // Valid from 1 minute ago
    const validBefore = now + 3600;  // Expires in 1 hour

    // EIP-712 domain for USDC (must match the contract's domain separator)
    const usdcDomain = {
      name: 'USD Coin',
      version: '2',
      chainId: pricing.chainId,
      verifyingContract: pricing.usdcAddress as `0x${string}`,
    };

    // Sign the EIP-3009 authorization using viem
    const signature = await signTypedData({
      privateKey: CLIENT_PRIVATE_KEY,
      domain: usdcDomain,
      types: EIP_3009_TYPES,
      primaryType: 'TransferWithAuthorization',
      message: {
        from: clientAccount.address,
        to: pricing.facilitatorAddress as `0x${string}`,
        value: BigInt(pricing.amount),
        validAfter: BigInt(validAfter),
        validBefore: BigInt(validBefore),
        nonce,
      },
    });

    // Decompose signature into v, r, s
    const r = `0x${signature.slice(2, 66)}`;
    const s = `0x${signature.slice(66, 130)}`;
    const v = parseInt(signature.slice(130, 132), 16);

    const authorization = {
      from: clientAccount.address,
      to: pricing.facilitatorAddress,
      value: pricing.amount,
      validAfter,
      validBefore,
      nonce,
      v,
      r,
      s,
    };

    console.log('  --- EIP-3009 Authorization ---');
    console.log(`  From:        ${authorization.from}`);
    console.log(`  To:          ${authorization.to}`);
    console.log(`  Value:       ${authorization.value}`);
    console.log(`  Valid after: ${new Date(validAfter * 1000).toISOString()}`);
    console.log(`  Valid before:${new Date(validBefore * 1000).toISOString()}`);
    console.log(`  Nonce:       ${nonce.slice(0, 18)}...`);
    console.log(`  Signature:   v=${v}, r=${r.slice(0, 18)}..., s=${s.slice(0, 18)}...\n`);

    // --- 5. Submit with X-PAYMENT header ---
    console.log('Step 5: Submitting with X-PAYMENT header...');
    console.log('  POST /publish with X-PAYMENT: <signed EIP-3009 authorization>\n');

    const publishResp = await fetch('http://localhost:3600/publish', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-PAYMENT': JSON.stringify(authorization),
      },
      body: JSON.stringify(publishBody),
    });

    const publishResult = await publishResp.json();
    console.log(`  Response: HTTP ${publishResp.status}`);
    console.log(`  Body: ${JSON.stringify(publishResult, null, 2)}\n`);

    if (publishResp.status === 200) {
      console.log('  Event published successfully via x402!');
      console.log(`  Event ID: ${(publishResult as { eventId?: string }).eventId}`);
      console.log(`  Tx hash:  ${(publishResult as { settlementTxHash?: string }).settlementTxHash}`);
    } else {
      // Expected: pre-flight USDC balance check fails because the client
      // account has no USDC on Anvil. Full settlement also requires
      // FiatTokenV2_2 (transferWithAuthorization / EIP-3009) — retro A3.
      console.log('  Note: Settlement failed as expected on Anvil.');
      console.log('  The client account has no USDC balance (pre-flight check).');
      console.log('  Full settlement also requires FiatTokenV2_2 deployment (retro A3).');
      console.log('  The pricing negotiation and authorization signing are fully functional.');
    }

    // --- 6. Summary ---
    console.log('\n=== x402 Protocol Summary ===');
    console.log('');
    console.log('  The x402 flow allows any HTTP client to publish events:');
    console.log('');
    console.log('  1. POST /publish (no payment)    -> 402 with pricing');
    console.log('  2. Sign EIP-3009 authorization    -> off-chain ECDSA signature');
    console.log('  3. POST /publish (with X-PAYMENT) -> settlement + ILP delivery');
    console.log('');
    console.log('  The facilitator (node operator) submits the signed authorization');
    console.log('  on-chain and pays gas. The client only pays the USDC amount.');
    console.log('');
    console.log('  This example demonstrated steps 1-2 with actual signing.');
    console.log('  Full settlement requires FiatTokenV2_2 on Anvil (retro A3).');

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
