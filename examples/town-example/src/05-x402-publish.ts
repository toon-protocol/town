/**
 * Example 05: x402 HTTP Publish — Payment-Gated Event Publishing
 *
 * Demonstrates the full x402 protocol flow for publishing Nostr events
 * via HTTP with USDC payment, including on-chain EIP-3009 settlement.
 *
 * Flow:
 *   1. POST /publish (no X-PAYMENT header) -> 402 with pricing info
 *   2. Client constructs EIP-3009 signed authorization for the required amount
 *   3. POST /publish (with X-PAYMENT header) -> settlement + ILP delivery
 *
 * Anvil setup (automated):
 *   - Upgrades the mock ERC-20 at the USDC address with EIP-3009 support
 *     (transferWithAuthorization, authorizationState) via anvil_setCode
 *   - Mints USDC to the client account
 *   - Funds the facilitator (town node) with ETH for gas
 *
 * Requires: Anvil + SDK E2E infra running on localhost:18545
 *   Start with: ./scripts/sdk-e2e-infra.sh up
 *   Compile contract: cd examples/town-example && forge build --root . --contracts contracts --out contracts/out
 *
 * Run: npm run x402-publish
 */

import { startTown, type TownInstance } from '@crosstown/town';
import { ConnectorNode } from '@crosstown/connector';
import { generateMnemonic, fromMnemonic } from '@crosstown/sdk';
import { finalizeEvent } from 'nostr-tools/pure';
import {
  createPublicClient,
  createWalletClient,
  http,
  defineChain,
  parseEther,
} from 'viem';
import { privateKeyToAccount, signTypedData } from 'viem/accounts';
import pino from 'pino';
import { readFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

// ---------------------------------------------------------------------------
// Anvil constants
// ---------------------------------------------------------------------------

const ANVIL_RPC = 'http://localhost:18545';
const TOKEN_ADDRESS = '0x5FbDB2315678afecb367f032d93F642f64180aa3' as const;

// Anvil Account #0 — deployer (has ETH, can call mint)
const DEPLOYER_PRIVATE_KEY = '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80' as const;

// Anvil Account #7 — x402 client (the payer)
const CLIENT_PRIVATE_KEY = '0x4bbbf85ce3377467afe5d46f804f221813b2bb87f24d81f60f1fcdbf7cbf4356' as const;

const anvilChain = defineChain({
  id: 31337,
  name: 'anvil',
  nativeCurrency: { name: 'ETH', symbol: 'ETH', decimals: 18 },
  rpcUrls: { default: { http: [ANVIL_RPC] } },
});

// Minimal ABI for mint + balanceOf on the upgraded contract
const MOCK_USDC_ABI = [
  {
    name: 'mint',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'to', type: 'address' },
      { name: 'amount', type: 'uint256' },
    ],
    outputs: [],
  },
  {
    name: 'balanceOf',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [{ name: '', type: 'uint256' }],
  },
] as const;

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

// ---------------------------------------------------------------------------
// Anvil RPC helpers
// ---------------------------------------------------------------------------

async function anvilRpc(method: string, params: unknown[]): Promise<unknown> {
  const resp = await fetch(ANVIL_RPC, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ jsonrpc: '2.0', method, params, id: 1 }),
  });
  const json = await resp.json() as { result?: unknown; error?: { message: string } };
  if (json.error) throw new Error(`RPC ${method}: ${json.error.message}`);
  return json.result;
}

/**
 * Upgrade the USDC contract at TOKEN_ADDRESS with EIP-3009 support.
 * Uses anvil_setCode to replace the runtime bytecode in-place.
 */
async function upgradeUsdcContract(): Promise<void> {
  const __dirname = dirname(fileURLToPath(import.meta.url));
  const artifactPath = resolve(__dirname, '../contracts/out/MockUSDC_EIP3009.sol/MockUSDC_EIP3009.json');

  let bytecode: string;
  try {
    const artifact = JSON.parse(readFileSync(artifactPath, 'utf-8'));
    bytecode = artifact.deployedBytecode.object;
  } catch {
    throw new Error(
      'Compiled contract not found. Run:\n' +
      '  cd examples/town-example && forge build --root . --contracts contracts --out contracts/out'
    );
  }

  await anvilRpc('anvil_setCode', [TOKEN_ADDRESS, bytecode]);
}

/**
 * Fund an address with ETH using anvil_setBalance.
 */
async function fundEth(address: string, ethAmount: string): Promise<void> {
  const wei = `0x${parseEther(ethAmount).toString(16)}`;
  await anvilRpc('anvil_setBalance', [address, wei]);
}

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

    // --- 2. Upgrade USDC contract with EIP-3009 support ---
    console.log('Step 2: Upgrading USDC contract with EIP-3009 support...');
    await upgradeUsdcContract();
    console.log('  anvil_setCode: replaced mock ERC-20 with EIP-3009 version');

    // Mint USDC to the client (Account #7)
    const clientAccount = privateKeyToAccount(CLIENT_PRIVATE_KEY);
    const deployerAccount = privateKeyToAccount(DEPLOYER_PRIVATE_KEY);
    const deployerWallet = createWalletClient({
      account: deployerAccount,
      chain: anvilChain,
      transport: http(ANVIL_RPC),
    });

    const mintAmount = 1_000_000n * 10n ** 18n; // 1M USDC (18 decimals on Anvil)
    await deployerWallet.writeContract({
      address: TOKEN_ADDRESS,
      abi: MOCK_USDC_ABI,
      functionName: 'mint',
      args: [clientAccount.address, mintAmount],
    });

    // Verify balance
    const publicClient = createPublicClient({ chain: anvilChain, transport: http(ANVIL_RPC) });
    const balance = await publicClient.readContract({
      address: TOKEN_ADDRESS,
      abi: MOCK_USDC_ABI,
      functionName: 'balanceOf',
      args: [clientAccount.address],
    });
    console.log(`  Minted ${(balance / 10n ** 18n).toLocaleString()} USDC to client ${clientAccount.address}`);
    console.log('');

    // --- 3. Start Town with x402 enabled ---
    // Override RPC URL to point at SDK E2E Anvil (port 18545)
    process.env['CROSSTOWN_RPC_URL'] = ANVIL_RPC;

    console.log('Step 3: Starting town node with x402 enabled...');
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
    console.log(`  Facilitator:  ${town.evmAddress}`);

    // Fund the facilitator with ETH for gas (needed for on-chain settlement tx)
    await fundEth(town.evmAddress, '10');
    console.log(`  Funded facilitator with 10 ETH for gas\n`);

    // --- 4. Pricing negotiation (402 response) ---
    console.log('Step 4: x402 pricing negotiation...');
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

    // --- 5. Construct EIP-3009 authorization ---
    console.log('Step 5: Constructing EIP-3009 signed authorization...');

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

    // --- 6. Submit with X-PAYMENT header ---
    console.log('Step 6: Submitting with X-PAYMENT header...');
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
      console.log(`  Settlement returned HTTP ${publishResp.status}.`);
      console.log(`  Check the error above for details.`);
    }

    // Verify on-chain: check client balance decreased
    const balanceAfter = await publicClient.readContract({
      address: TOKEN_ADDRESS,
      abi: MOCK_USDC_ABI,
      functionName: 'balanceOf',
      args: [clientAccount.address],
    });
    const spent = balance - balanceAfter;
    if (spent > 0n) {
      console.log(`\n  On-chain verification:`);
      console.log(`    Client spent:    ${spent.toString()} micro-units`);
      console.log(`    Client balance:  ${(balanceAfter / 10n ** 18n).toLocaleString()} USDC`);
    }

    // --- 7. Summary ---
    console.log('\n=== x402 Protocol Summary ===');
    console.log('');
    console.log('  The x402 flow allows any HTTP client to publish events:');
    console.log('');
    console.log('  1. POST /publish (no payment)    -> 402 with pricing');
    console.log('  2. Sign EIP-3009 authorization    -> off-chain ECDSA signature');
    console.log('  3. POST /publish (with X-PAYMENT) -> on-chain settlement + ILP delivery');
    console.log('');
    console.log('  The facilitator (node operator) submits the signed authorization');
    console.log('  on-chain via transferWithAuthorization and pays gas.');
    console.log('  The client only pays the USDC amount.');

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
