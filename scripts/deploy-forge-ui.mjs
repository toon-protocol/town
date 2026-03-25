#!/usr/bin/env node
/**
 * Deploy Rig-UI to Arweave.
 * Historically named 'Forge-UI', now deploys Rig-UI. Filename kept for backwards compat.
 *
 * Builds the Rig-UI static web app and uploads it to Arweave via
 * @ardrive/turbo-sdk, creating an Arweave path manifest that serves
 * the entire SPA from a single transaction ID.
 *
 * Usage:
 *   node scripts/deploy-forge-ui.mjs --dev              # Free tier (<=100KB per file)
 *   node scripts/deploy-forge-ui.mjs --wallet key.json  # Authenticated (paid, no size limit)
 *   node scripts/deploy-forge-ui.mjs --dry-run          # Build only, no upload
 *   node scripts/deploy-forge-ui.mjs --help             # Show help
 *
 * Prerequisites:
 *   - Node.js >= 20
 *   - pnpm installed
 *   - For --wallet mode: Arweave JWK wallet file with Turbo credits
 *
 * Environment Variables:
 *   VITE_DEFAULT_RELAY  - Default relay URL baked into the build
 *                         (e.g., wss://relay.toon-protocol.org)
 */

import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { Readable } from 'node:stream';
import {
  getMimeType,
  generateManifest,
  validateDevModeFileSizes,
  generateDeploymentSummary,
  collectFiles,
  parseCliArgs,
} from './deploy-helpers.mjs';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const ROOT_DIR = resolve(__dirname, '..');
const RIG_DIR = resolve(ROOT_DIR, 'packages/rig');
const DIST_DIR = resolve(RIG_DIR, 'dist');

// ---------------------------------------------------------------------------
// CLI argument parsing
// ---------------------------------------------------------------------------

function printHelp() {
  console.log(`
Rig-UI Arweave Deployment Script

Usage:
  node scripts/deploy-forge-ui.mjs [options]

Options:
  --dev           Use Turbo free tier (unauthenticated, <=100KB per file).
                  Good for testing the deployment pipeline without AR tokens.

  --wallet <path> Use authenticated Turbo upload with an Arweave JWK wallet.
                  No file size limit. Requires Turbo credits (purchased with
                  fiat or crypto at https://turbo.ardrive.io).

  --confirm       Required with --wallet to proceed with paid upload.
                  Without this flag, only a cost estimate is printed.

  --dry-run       Build the Rig-UI but do not upload to Arweave.
                  Useful for verifying the build output.

  --help          Show this help message.

Environment Variables:
  VITE_DEFAULT_RELAY   Default WebSocket relay URL baked into the build.
                       Example: VITE_DEFAULT_RELAY=wss://relay.example

Examples:
  # Dev mode (free tier, testing only)
  node scripts/deploy-forge-ui.mjs --dev

  # Production deployment
  node scripts/deploy-forge-ui.mjs --wallet ~/.arweave/wallet.json --confirm

  # Build verification only
  node scripts/deploy-forge-ui.mjs --dry-run

  # With custom relay default
  VITE_DEFAULT_RELAY=wss://relay.toon-protocol.org node scripts/deploy-forge-ui.mjs --wallet wallet.json --confirm

Relay Configuration:
  After deployment, users configure the relay via URL hash fragment:
    https://ar-io.dev/<manifest-tx-id>/#relay=wss://relay.example

  The hash fragment is preferred because it works across Arweave gateways,
  is shareable/bookmarkable, and is not sent to the server.

Dogfooding:
  1. Seed data into a relay:
     node scripts/seed-forge-data.mjs --container <container-name>

  2. Access the deployed Rig-UI with your relay:
     https://ar-io.dev/<manifest-tx-id>/#relay=wss://your-relay
`);
}

const args = process.argv.slice(2);
const cli = parseCliArgs(args);

if (cli.showHelp) {
  printHelp();
  process.exit(0);
}

if (cli.error) {
  console.error(`Error: ${cli.error} Use --help for details.`);
  process.exit(1);
}

const { isDev, isDryRun, isConfirm, walletPath } = cli;

// ---------------------------------------------------------------------------
// Step 1: Build Rig-UI
// ---------------------------------------------------------------------------

console.log('\n--- Step 1: Building Rig-UI ---\n');
execFileSync('pnpm', ['build'], { cwd: RIG_DIR, stdio: 'inherit' });
console.log('\nBuild complete.\n');

// ---------------------------------------------------------------------------
// Step 2: Collect dist files
// ---------------------------------------------------------------------------

console.log('--- Step 2: Collecting dist files ---\n');
const files = collectFiles(DIST_DIR, DIST_DIR);
console.log(`Found ${files.length} files in dist/:`);

let totalSize = 0;
for (const f of files) {
  const sizeKB = (f.size / 1024).toFixed(1);
  console.log(`  ${f.relativePath} (${sizeKB} KB) [${getMimeType(f.relativePath)}]`);
  totalSize += f.size;
}
console.log(`\nTotal size: ${(totalSize / 1024).toFixed(1)} KB\n`);

// ---------------------------------------------------------------------------
// Step 3: Validate (dev mode) or estimate cost (wallet mode)
// ---------------------------------------------------------------------------

if (isDev) {
  console.log('--- Step 3: Validating file sizes for free tier ---\n');
  const validation = validateDevModeFileSizes(files);
  if (!validation.valid) {
    console.error('Error: The following files exceed the 100KB free tier limit:');
    for (const f of validation.oversizedFiles) {
      console.error(`  ${f}`);
    }
    console.error('\nUse --wallet <path> for authenticated uploads with no size limit.');
    process.exit(1);
  }
  console.log('All files within 100KB free tier limit.\n');
}

if (walletPath && !isConfirm) {
  console.log('--- Cost Estimate ---\n');
  console.log(`Files: ${files.length}`);
  console.log(`Total size: ${(totalSize / 1024).toFixed(1)} KB`);
  console.log(`Uploads: ${files.length} data items + 1 manifest = ${files.length + 1} total`);
  console.log('\nTo proceed with the upload, add the --confirm flag.');
  process.exit(0);
}

if (isDryRun) {
  console.log('--- Dry run complete (no upload) ---\n');
  console.log('Build output verified. To deploy, use --dev or --wallet <path>.');
  process.exit(0);
}

// ---------------------------------------------------------------------------
// Step 4: Upload files to Arweave
// ---------------------------------------------------------------------------

console.log('--- Step 4: Uploading to Arweave ---\n');

/** @type {import('@ardrive/turbo-sdk/node')} */
let TurboFactory;
try {
  ({ TurboFactory } = await import('@ardrive/turbo-sdk/node'));
} catch (err) {
  console.error('Error: @ardrive/turbo-sdk is not installed.');
  console.error('Run `pnpm install` from the workspace root and try again.');
  process.exit(1);
}

let turbo;
if (isDev) {
  console.log('Using Turbo free tier (ephemeral JWK, <=100KB per file).\n');
  const Arweave = (await import('arweave')).default;
  const jwk = await Arweave.init({}).crypto.generateJWK();
  turbo = TurboFactory.authenticated({ privateKey: jwk });
} else {
  const resolvedWalletPath = resolve(walletPath);
  let jwkContent;
  try {
    jwkContent = readFileSync(resolvedWalletPath, 'utf-8');
  } catch (err) {
    console.error(`Error: Cannot read wallet file at ${resolvedWalletPath}`);
    console.error(err instanceof Error ? err.message : String(err));
    process.exit(1);
  }
  console.log(`Using authenticated Turbo with wallet: ${walletPath}\n`);
  let jwk;
  try {
    jwk = JSON.parse(jwkContent);
  } catch (err) {
    console.error(`Error: Wallet file at ${resolvedWalletPath} contains invalid JSON.`);
    console.error(err instanceof Error ? err.message : String(err));
    process.exit(1);
  }
  turbo = TurboFactory.authenticated({ privateKey: jwk });
}

/** @type {{ path: string, txId: string }[]} */
const uploadedEntries = [];

for (const file of files) {
  const mime = getMimeType(file.relativePath);
  const data = readFileSync(file.absolutePath);

  let result;
  try {
    result = await turbo.uploadFile({
      fileStreamFactory: () => Readable.from(data),
      fileSizeFactory: () => data.length,
      dataItemOpts: {
        tags: [
          { name: 'Content-Type', value: mime },
          { name: 'App-Name', value: 'Rig-UI' },
        ],
      },
    });
  } catch (err) {
    console.error(`\nError uploading ${file.relativePath}:`);
    console.error(err instanceof Error ? err.message : String(err));
    console.error('\nUpload failed. Previously uploaded files are still on Arweave.');
    console.error('Re-run the script to retry (already-uploaded files will be re-uploaded as new data items).');
    process.exit(1);
  }

  uploadedEntries.push({ path: file.relativePath, txId: result.id });
  console.log(`  Uploaded: ${file.relativePath} -> ${result.id}`);
}

console.log(`\nAll ${files.length} files uploaded.\n`);

// ---------------------------------------------------------------------------
// Step 5: Create and upload manifest
// ---------------------------------------------------------------------------

console.log('--- Step 5: Creating and uploading path manifest ---\n');

const manifest = generateManifest(uploadedEntries);
const manifestJson = JSON.stringify(manifest, null, 2);
const manifestBuffer = Buffer.from(manifestJson, 'utf-8');

let manifestResult;
try {
  manifestResult = await turbo.uploadFile({
    fileStreamFactory: () => Readable.from(manifestBuffer),
    fileSizeFactory: () => manifestBuffer.length,
    dataItemOpts: {
      tags: [
        { name: 'Content-Type', value: 'application/x.arweave-manifest+json' },
        { name: 'Type', value: 'manifest' },
        { name: 'App-Name', value: 'Rig-UI' },
      ],
    },
  });
} catch (err) {
  console.error('\nError uploading manifest:');
  console.error(err instanceof Error ? err.message : String(err));
  console.error('\nAll data files were uploaded successfully but the manifest failed.');
  console.error('Re-run the script to retry.');
  process.exit(1);
}

const manifestTxId = manifestResult.id;
console.log(`Manifest uploaded: ${manifestTxId}`);

// ---------------------------------------------------------------------------
// Step 6: Print deployment summary
// ---------------------------------------------------------------------------

console.log(generateDeploymentSummary(manifestTxId));
