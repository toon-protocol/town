#!/usr/bin/env node
/**
 * Deploy a Rig-UI pointer to Arweave.
 *
 * Generates a thin HTML shell that embeds relay config and loads
 * the canonical Rig-UI from a known Arweave manifest TX. The resulting
 * pointer URL is a single click-to-view link for any TOON repo.
 *
 * Usage:
 *   node scripts/deploy-rig-pointer.mjs --relay wss://relay.example --rig-tx <manifest-tx> --dev
 *   node scripts/deploy-rig-pointer.mjs --relay wss://relay.example --repo my-project --rig-tx <tx> --dev
 *   node scripts/deploy-rig-pointer.mjs --relay wss://relay.example --rig-tx <tx> --wallet key.json --confirm
 *   node scripts/deploy-rig-pointer.mjs --dry-run --relay wss://relay.example --rig-tx <tx>
 *   node scripts/deploy-rig-pointer.mjs --help
 *
 * Pointers reference a specific Rig-UI version. Regenerate pointers after
 * redeploying the canonical Rig-UI to use the latest version.
 */

import { Readable } from 'node:stream';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

// ---------------------------------------------------------------------------
// CLI argument parsing
// ---------------------------------------------------------------------------

function printHelp() {
  console.log(`
Rig-UI Pointer Deployment Script

Generates a thin HTML shell pointer that embeds relay config and loads
the canonical Rig-UI from Arweave. The result is a single shareable URL.

Usage:
  node scripts/deploy-rig-pointer.mjs [options]

Required:
  --relay <url>     WebSocket relay URL (wss:// or ws://)
  --rig-tx <txid>   Arweave manifest TX ID of the canonical Rig-UI deploy

Optional:
  --repo <name>     Repository name for deep-linking (single-repo pointer)
  --owner <npub>    Owner npub or hex pubkey for deep-linking

Upload Mode (one required unless --dry-run):
  --dev             Use Turbo free tier (unauthenticated, <=100KB)
  --wallet <path>   Use authenticated Turbo with Arweave JWK wallet
  --confirm         Required with --wallet to proceed with paid upload

Other:
  --dry-run         Generate the pointer HTML and print to stdout (no upload)
  --help            Show this help message

Examples:
  # Single-repo pointer (free tier)
  node scripts/deploy-rig-pointer.mjs --relay wss://relay.example --repo my-project --rig-tx abc123 --dev

  # Relay-wide pointer (shows repo list)
  node scripts/deploy-rig-pointer.mjs --relay wss://relay.example --rig-tx abc123 --dev

  # Preview pointer HTML without uploading
  node scripts/deploy-rig-pointer.mjs --relay wss://relay.example --rig-tx abc123 --dry-run

Notes:
  - Pointers require path-based Arweave gateways (ar-io.dev, arweave.net, permagate.io)
  - Pointers reference a specific Rig-UI version; regenerate after redeploying canonical Rig-UI
  - ws:// relay URLs will trigger a warning (insecure for permanent Arweave pointers)
`);
}

/**
 * Parse pointer-specific CLI arguments.
 *
 * @param {string[]} argv
 */
function parsePointerArgs(argv) {
  const showHelp = argv.includes('--help');
  const isDev = argv.includes('--dev');
  const isDryRun = argv.includes('--dry-run');
  const isConfirm = argv.includes('--confirm');

  const walletIdx = argv.indexOf('--wallet');
  const rawWallet = walletIdx !== -1 ? (argv[walletIdx + 1] || null) : null;
  const walletPath = rawWallet && rawWallet.startsWith('--') ? null : rawWallet;

  const relayIdx = argv.indexOf('--relay');
  const relay = relayIdx !== -1 ? (argv[relayIdx + 1] || null) : null;

  const rigTxIdx = argv.indexOf('--rig-tx');
  const rigTx = rigTxIdx !== -1 ? (argv[rigTxIdx + 1] || null) : null;

  const repoIdx = argv.indexOf('--repo');
  const repo = repoIdx !== -1 ? (argv[repoIdx + 1] || null) : null;

  const ownerIdx = argv.indexOf('--owner');
  const owner = ownerIdx !== -1 ? (argv[ownerIdx + 1] || null) : null;

  let error = null;

  if (!showHelp) {
    if (!relay) {
      error = '--relay <url> is required.';
    } else if (!/^wss?:\/\//i.test(relay)) {
      error = '--relay must be a WebSocket URL (ws:// or wss://).';
    } else if (!rigTx) {
      error = '--rig-tx <manifest-tx-id> is required.';
    } else if (walletIdx !== -1 && !walletPath) {
      error = '--wallet requires a path argument.';
    } else if (walletPath && isDev) {
      error = '--dev and --wallet are mutually exclusive.';
    } else if (!isDev && !isDryRun && !walletPath) {
      error = 'Specify --dev, --wallet <path>, or --dry-run.';
    } else if (owner && !isValidOwner(owner)) {
      error = '--owner must be an npub1-encoded key or 64-char hex pubkey.';
    }
  }

  return { showHelp, isDev, isDryRun, isConfirm, walletPath, relay, rigTx, repo, owner, error };
}

/**
 * Validate owner is npub1-prefixed or 64-char hex.
 * @param {string} owner
 * @returns {boolean}
 */
function isValidOwner(owner) {
  return owner.startsWith('npub1') || /^[0-9a-f]{64}$/i.test(owner);
}

// ---------------------------------------------------------------------------
// Manifest resolution
// ---------------------------------------------------------------------------

/** Arweave gateways for pointer URLs. */
const GATEWAYS = [
  'https://ar-io.dev',
  'https://arweave.net',
  'https://permagate.io',
];

/**
 * Fetch the raw Arweave manifest and extract JS/CSS asset paths.
 *
 * @param {string} rigTx - Manifest transaction ID
 * @returns {Promise<{ jsPath: string, cssPath: string }>}
 */
async function resolveAssetPaths(rigTx) {
  const url = `${GATEWAYS[0]}/raw/${rigTx}`;
  console.log(`Fetching manifest: ${url}`);

  const res = await fetch(url);
  if (!res.ok) {
    throw new Error(`Failed to fetch manifest from ${url}: ${res.status} ${res.statusText}`);
  }

  const manifest = await res.json();
  const paths = Object.keys(manifest.paths || {});

  const jsPath = paths.find((p) => p.match(/^assets\/.*\.js$/));
  const cssPath = paths.find((p) => p.match(/^assets\/.*\.css$/));

  if (!jsPath) {
    throw new Error('Could not find JS asset in manifest. Expected assets/*.js');
  }
  if (!cssPath) {
    throw new Error('Could not find CSS asset in manifest. Expected assets/*.css');
  }

  return { jsPath, cssPath };
}

// ---------------------------------------------------------------------------
// Pointer HTML generation — delegated to shared module for testability
// ---------------------------------------------------------------------------

// Note: generatePointerHtml lives in packages/rig/src/web/rig-pointer-html.ts
// for vitest testability. We inline an equivalent here to avoid build dependency.
// Keep in sync with the TS source.

/**
 * Generate the pointer HTML shell.
 *
 * @param {object} opts
 * @param {string} opts.relay - WebSocket relay URL
 * @param {string} [opts.repo] - Optional repo name for deep-linking
 * @param {string} [opts.owner] - Optional owner npub/hex for deep-linking
 * @param {string} opts.rigTx - Canonical Rig-UI manifest TX ID
 * @param {string} opts.jsPath - JS asset path within the manifest
 * @param {string} opts.cssPath - CSS asset path within the manifest
 * @returns {string} Complete HTML document
 */
function generatePointerHtml({ relay, repo, owner, rigTx, jsPath, cssPath }) {
  const config = { relay };
  if (repo) config.repo = repo;
  if (owner) config.owner = owner;

  // Escape < as \u003c to prevent </script> breakout XSS
  const safeConfig = JSON.stringify(config).replace(/</g, '\\u003c');

  const title = repo ? `${repo} — Rig` : 'Rig';
  const gw = GATEWAYS[0];
  const baseUrl = `${gw}/${rigTx}`;

  return `<!DOCTYPE html>
<html lang="en"><head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <meta name="description" content="Decentralized Git on Nostr &amp; TOON Protocol">
  <meta http-equiv="Content-Security-Policy" content="default-src 'self' ${gw}; script-src 'self' 'unsafe-inline' ${gw}; style-src 'self' 'unsafe-inline' ${gw}; connect-src 'self' ws: wss: ${gw} *.ar-io.dev https://arweave.net *.arweave.net https://permagate.io *.permagate.io; img-src 'self' data: https:">
  <title>${title}</title>
  <link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='.9em' font-size='90'>&#x2692;</text></svg>">
  <script>window.__RIG_CONFIG__=${safeConfig}</script>
  <link rel="stylesheet" href="${baseUrl}/${cssPath}">
</head><body>
  <div id="app"></div>
  <script type="module" src="${baseUrl}/${jsPath}"></script>
</body></html>
`;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

const args = process.argv.slice(2);
const cli = parsePointerArgs(args);

if (cli.showHelp) {
  printHelp();
  process.exit(0);
}

if (cli.error) {
  console.error(`Error: ${cli.error} Use --help for details.`);
  process.exit(1);
}

const { relay, rigTx, repo, owner, isDev, isDryRun, isConfirm, walletPath } = cli;

// Warn about insecure relay for permanent Arweave pointer
// nosemgrep: javascript.lang.security.detect-insecure-websocket.detect-insecure-websocket
if (relay.startsWith('ws://')) {
  console.warn('\n⚠️  Warning: Using insecure ws:// relay URL for a permanent Arweave pointer.');
  console.warn('   Consider using wss:// for production pointers.\n');
}

// ---------------------------------------------------------------------------
// Step 1: Resolve asset paths from canonical manifest
// ---------------------------------------------------------------------------

console.log('\n--- Step 1: Resolving canonical Rig-UI assets ---\n');

const { jsPath, cssPath } = await resolveAssetPaths(rigTx);
console.log(`  JS:  ${jsPath}`);
console.log(`  CSS: ${cssPath}\n`);

// ---------------------------------------------------------------------------
// Step 2: Generate pointer HTML
// ---------------------------------------------------------------------------

console.log('--- Step 2: Generating pointer HTML ---\n');

const html = generatePointerHtml({ relay, repo, owner, rigTx, jsPath, cssPath });
const htmlBuffer = Buffer.from(html, 'utf-8');

console.log(`  Size: ${htmlBuffer.length} bytes`);
console.log(`  Mode: ${repo ? `single-repo (${repo})` : 'relay-wide (repo list)'}`);
console.log(`  Relay: ${relay}\n`);

if (isDryRun) {
  console.log('--- Dry run: pointer HTML ---\n');
  console.log(html);
  console.log('--- Dry run complete (no upload) ---');
  process.exit(0);
}

// ---------------------------------------------------------------------------
// Step 3: Upload pointer to Arweave
// ---------------------------------------------------------------------------

console.log('--- Step 3: Uploading pointer to Arweave ---\n');

/** @type {import('@ardrive/turbo-sdk/node')} */
let TurboFactory;
try {
  ({ TurboFactory } = await import('@ardrive/turbo-sdk/node'));
} catch {
  console.error('Error: @ardrive/turbo-sdk is not installed.');
  console.error('Run `pnpm install` from the workspace root and try again.');
  process.exit(1);
}

let turbo;
if (isDev) {
  console.log('Using Turbo free tier (ephemeral JWK, <=100KB).\n');
  const Arweave = (await import('arweave')).default;
  const jwk = await Arweave.init({}).crypto.generateJWK();
  turbo = TurboFactory.authenticated({ privateKey: jwk });
} else {
  const resolvedWalletPath = resolve(walletPath);
  let jwk;
  try {
    jwk = JSON.parse(readFileSync(resolvedWalletPath, 'utf-8'));
  } catch (err) {
    console.error(`Error: Cannot read wallet at ${resolvedWalletPath}: ${err instanceof Error ? err.message : String(err)}`);
    process.exit(1);
  }

  if (!isConfirm) {
    console.log('--- Cost Estimate ---\n');
    console.log(`  Size: ${htmlBuffer.length} bytes (1 data item)`);
    console.log('\nTo proceed with the upload, add the --confirm flag.');
    process.exit(0);
  }

  console.log(`Using authenticated Turbo with wallet: ${walletPath}\n`);
  turbo = TurboFactory.authenticated({ privateKey: jwk });
}

let result;
try {
  result = await turbo.uploadFile({
    fileStreamFactory: () => Readable.from(htmlBuffer),
    fileSizeFactory: () => htmlBuffer.length,
    dataItemOpts: {
      tags: [
        { name: 'Content-Type', value: 'text/html' },
        { name: 'App-Name', value: 'Rig-UI-Pointer' },
        { name: 'Rig-Relay', value: relay },
        ...(repo ? [{ name: 'Rig-Repo', value: repo }] : []),
        ...(owner ? [{ name: 'Rig-Owner', value: owner }] : []),
        { name: 'Rig-Canonical-TX', value: rigTx },
      ],
    },
  });
} catch (err) {
  console.error(`\nError uploading pointer: ${err instanceof Error ? err.message : String(err)}`);
  process.exit(1);
}

const pointerTxId = result.id;

// ---------------------------------------------------------------------------
// Step 4: Print deployment summary
// ---------------------------------------------------------------------------

console.log(`\n=== Rig-UI Pointer Deployed ===\n`);
console.log(`Pointer TX: ${pointerTxId}`);
console.log(`Relay:      ${relay}`);
if (repo) console.log(`Repo:       ${repo}`);
if (owner) console.log(`Owner:      ${owner}`);
console.log(`Canonical:  ${rigTx}\n`);
console.log('Pointer URLs:');
for (const gw of GATEWAYS) {
  console.log(`  ${gw}/${pointerTxId}/`);
}
console.log('');
