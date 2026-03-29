/**
 * Shared helper functions for the Rig-UI Arweave deployment script.
 *
 * Extracted into a separate module so they can be imported by both
 * the deploy script (scripts/deploy-forge-ui.mjs) and the unit tests
 * (packages/rig/src/web/deploy-manifest.test.ts).
 */

import { extname, relative, join } from 'node:path';
import { readdirSync, statSync } from 'node:fs';

// ---------------------------------------------------------------------------
// MIME type detection
// ---------------------------------------------------------------------------

/** Map of file extensions to MIME types for Arweave Content-Type tags. */
const MIME_TYPES = {
  '.html': 'text/html',
  '.js': 'application/javascript',
  '.css': 'text/css',
  '.json': 'application/json',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.ico': 'image/x-icon',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.map': 'application/json',
};

/**
 * Determine the MIME type for a file based on its extension.
 *
 * @param {string} filename - File path or name
 * @returns {string} MIME type string
 */
export function getMimeType(filename) {
  const ext = extname(filename).toLowerCase();
  return MIME_TYPES[ext] || 'application/octet-stream';
}

// ---------------------------------------------------------------------------
// Arweave path manifest generation
// ---------------------------------------------------------------------------

/**
 * @typedef {Object} ManifestEntry
 * @property {string} path - Relative file path (e.g., 'assets/main-abc123.js')
 * @property {string} txId - Arweave transaction ID for the uploaded file
 */

/**
 * @typedef {Object} ArweaveManifest
 * @property {string} manifest - Always 'arweave/paths'
 * @property {string} version - Always '0.2.0'
 * @property {{ path: string }} index - Index file path
 * @property {{ id: string }} [fallback] - Fallback tx ID for SPA routing
 * @property {Record<string, { id: string }>} paths - Path-to-txId mapping
 */

/**
 * Generate an Arweave path manifest from uploaded file entries.
 *
 * The manifest enables gateway URL routing: `arweave.net/<manifest-tx>/path/to/file`
 * resolves to the correct data item. The `fallback` field enables SPA routing
 * by serving index.html for any unmatched path.
 *
 * @param {ManifestEntry[]} entries - List of uploaded files with their tx IDs
 * @returns {ArweaveManifest} Arweave path manifest JSON object
 */
export function generateManifest(entries) {
  /** @type {Record<string, { id: string }>} */
  const paths = Object.create(null);
  let indexTxId = undefined;

  for (const entry of entries) {
    paths[entry.path] = { id: entry.txId };
    if (entry.path === 'index.html') {
      indexTxId = entry.txId;
    }
  }

  /** @type {ArweaveManifest} */
  const manifest = {
    manifest: 'arweave/paths',
    version: '0.2.0',
    index: { path: 'index.html' },
    paths,
  };

  // Add fallback for SPA routing (all unmatched paths serve index.html)
  if (indexTxId) {
    manifest.fallback = { id: indexTxId };
  }

  return manifest;
}

// ---------------------------------------------------------------------------
// Dev mode file size validation
// ---------------------------------------------------------------------------

/** Free tier upload limit: 100KB per data item. */
const DEV_MODE_SIZE_LIMIT = 102_400;

/**
 * Validate that all files are within the Turbo free tier size limit (100KB).
 *
 * Accepts file objects with either `path` or `relativePath` fields (the latter
 * is produced by `collectFiles()`).
 *
 * @param {{ path?: string, relativePath?: string, size: number }[]} files - Files with their sizes in bytes
 * @returns {{ valid: boolean, oversizedFiles: string[] }} Validation result
 */
export function validateDevModeFileSizes(files) {
  const oversizedFiles = files
    .filter((f) => f.size > DEV_MODE_SIZE_LIMIT)
    .map((f) => f.relativePath || f.path || '<unknown>');

  return {
    valid: oversizedFiles.length === 0,
    oversizedFiles,
  };
}

// ---------------------------------------------------------------------------
// Deployment summary generation
// ---------------------------------------------------------------------------

/** Arweave gateways for deployment summary output. */
const GATEWAYS = [
  'https://ar-io.dev',
  'https://arweave.net',
  'https://permagate.io',
];

// ---------------------------------------------------------------------------
// File collection
// ---------------------------------------------------------------------------

/**
 * Recursively collect all files from a directory.
 *
 * @param {string} dir - Directory to scan
 * @param {string} baseDir - Base directory for computing relative paths
 * @returns {{ absolutePath: string, relativePath: string, size: number }[]}
 */
export function collectFiles(dir, baseDir) {
  const results = [];
  const entries = readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    const fullPath = join(dir, entry.name);
    if (entry.isDirectory()) {
      results.push(...collectFiles(fullPath, baseDir));
    } else if (entry.isFile()) {
      const stat = statSync(fullPath);
      // Use forward slashes for Arweave manifest paths (Windows compat)
      results.push({
        absolutePath: fullPath,
        relativePath: relative(baseDir, fullPath).split('\\').join('/'),
        size: stat.size,
      });
    }
  }
  return results;
}

// ---------------------------------------------------------------------------
// CLI argument parsing
// ---------------------------------------------------------------------------

/**
 * Parse deploy script CLI arguments.
 *
 * @param {string[]} argv - CLI arguments (process.argv.slice(2))
 * @returns {{ isDev: boolean, isDryRun: boolean, isConfirm: boolean, walletPath: string|null, showHelp: boolean, error: string|null }}
 */
export function parseCliArgs(argv) {
  const isDev = argv.includes('--dev');
  const isDryRun = argv.includes('--dry-run');
  const isConfirm = argv.includes('--confirm');
  const showHelp = argv.includes('--help');
  const walletIdx = argv.indexOf('--wallet');
  const rawWalletArg = walletIdx !== -1 ? (argv[walletIdx + 1] || null) : null;
  // Treat a following flag (--something) as a missing path, not a wallet file
  const walletPath = rawWalletArg && rawWalletArg.startsWith('--') ? null : rawWalletArg;

  let error = null;

  if (!showHelp) {
    if (walletIdx !== -1 && !walletPath) {
      error = '--wallet requires a path argument.';
    } else if (walletPath && isDev) {
      error = '--dev and --wallet are mutually exclusive.';
    } else if (!isDev && !isDryRun && !walletPath) {
      error = 'Specify --dev, --wallet <path>, or --dry-run.';
    }
  }

  return { isDev, isDryRun, isConfirm, walletPath, showHelp, error };
}

/**
 * Generate a human-readable deployment summary with gateway URLs and instructions.
 *
 * @param {string} manifestTxId - The manifest transaction ID
 * @returns {string} Formatted deployment summary
 */
export function generateDeploymentSummary(manifestTxId) {
  const lines = [
    '',
    '=== Rig-UI Deployment Summary ===',
    '',
    `Manifest Transaction ID: ${manifestTxId}`,
    '',
    'Gateway URLs:',
  ];

  for (const gw of GATEWAYS) {
    lines.push(`  ${gw}/${manifestTxId}/`);
  }

  lines.push(
    '',
    'Relay Configuration:',
    '  Add #relay=wss://your-relay.example to the URL to connect to a specific relay.',
    `  Example: ${GATEWAYS[0]}/${manifestTxId}/#relay=wss://relay.toon-protocol.org`,
    '',
    'Dogfooding:',
    '  1. Seed data:  node scripts/seed-forge-data.mjs --container <container>',  // filename kept for backwards compat
    `  2. Browse:     ${GATEWAYS[0]}/${manifestTxId}/#relay=wss://your-relay.example`,
    '',
  );

  return lines.join('\n');
}
