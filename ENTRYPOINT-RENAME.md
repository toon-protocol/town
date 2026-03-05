# Entrypoint Renaming - Making Full-Featured the Default

## Summary

Renamed BLS entrypoints to make the full-featured Crosstown node the default behavior.

## Changes Made

### 1. **Entrypoint Files Renamed**

| Old Name                       | New Name                 | Purpose                                   |
| ------------------------------ | ------------------------ | ----------------------------------------- |
| `entrypoint-with-bootstrap.ts` | `entrypoint.ts`          | **Default**: Full-featured Crosstown node |
| `entrypoint.ts`                | `entrypoint-bls-only.ts` | **Minimal**: BLS-only for testing         |

**Rationale:** The "bootstrap" version is actually the production-ready implementation with all features. Making it the default encourages proper usage.

### 2. **What's in Each Entrypoint**

#### `entrypoint.ts` (Default - Full-Featured)

- ✅ Business Logic Server (BLS)
- ✅ Nostr Relay (WebSocket on port 7100)
- ✅ Peer Discovery via Nostr
- ✅ **Automatic payment channel creation**
- ✅ **SPSP negotiation with settlement**
- ✅ Bootstrap Service (auto-peering)
- ✅ Relay Monitor (watch for new peers)
- ✅ Settlement configuration (EVM/BASE)

**Use for:** Production, multi-peer networks, any setup with payment channels

#### `entrypoint-bls-only.ts` (Minimal)

- ✅ Business Logic Server (BLS) only
- ❌ No Nostr relay
- ❌ No peer discovery
- ❌ No payment channels
- ❌ No bootstrap flow

**Use for:** Testing BLS in isolation, manual peer configuration

### 3. **Docker Configuration Updated**

#### Main Dockerfile (`packages/bls/Dockerfile`)

```dockerfile
# Now defaults to full-featured entrypoint
CMD node dist/${ENTRYPOINT:-entrypoint.js}
```

To use minimal version:

```yaml
environment:
  ENTRYPOINT: 'entrypoint-bls-only.js'
```

#### Dockerfile.bootstrap

Updated to use new default `entrypoint.js`

### 4. **Docker Compose Files Updated**

#### `docker-compose-with-local.yml` ✅ Fixed

Added required bootstrap environment variables:

- `BOOTSTRAP_RELAYS` - Comma-separated relay URLs
- `BOOTSTRAP_PEERS` - Comma-separated peer pubkeys
- `PEER_EVM_ADDRESS` - EVM address for settlement
- `M2M_TOKEN_ADDRESS` - Token contract address

**Now uses the fixed bootstrap flow with payment channels!**

#### `docker-compose-bootstrap.yml` ✅ Updated

Changed `ENTRYPOINT: "entrypoint-with-bootstrap.js"` → `ENTRYPOINT: "entrypoint.js"`

### 5. **Build Configuration Updated**

`packages/bls/tsup.config.ts`:

```typescript
entry: ['src/index.ts', 'src/entrypoint.ts', 'src/entrypoint-bls-only.ts'];
```

## Migration Guide

### If you were using `entrypoint-with-bootstrap.js`:

✅ **No action needed** - it's now just `entrypoint.js` (the default)

Remove explicit ENTRYPOINT overrides:

```diff
- ENTRYPOINT: "entrypoint-with-bootstrap.js"
+ # Remove this line - it's now the default!
```

### If you were using basic `entrypoint.js`:

⚠️ **Action required** - Explicitly set to minimal version:

```yaml
environment:
  ENTRYPOINT: 'entrypoint-bls-only.js'
```

## Why This Matters

The bootstrap flow fixes in commits `d8c1294` and `cfcb1b3` implemented:

- Payment channel integration
- Automatic channel opening during SPSP negotiation
- Settlement on-chain via TokenNetworkRegistry

**Before:** `docker-compose-with-local.yml` wasn't using these fixes (wrong entrypoint)
**After:** Now properly configured with all bootstrap features enabled

## Testing

Build and verify:

```bash
# Rebuild BLS package
pnpm --filter @crosstown/bls build

# Verify outputs exist
ls -lh packages/bls/dist/
# Should see:
# - entrypoint.js (full-featured, ~11KB)
# - entrypoint-bls-only.js (minimal, ~3.8KB)

# Test with docker-compose
docker compose -f docker-compose-with-local.yml up -d
docker compose -f docker-compose-with-local.yml logs crosstown
# Should see: "🚀 Starting Crosstown Node with Bootstrap..."
```

## Files Modified

- `packages/bls/src/entrypoint-with-bootstrap.ts` → `entrypoint.ts`
- `packages/bls/src/entrypoint.ts` → `entrypoint-bls-only.ts`
- `packages/bls/tsup.config.ts`
- `packages/bls/Dockerfile`
- `packages/bls/Dockerfile.bootstrap`
- `docker-compose-with-local.yml`
- `docker-compose-bootstrap.yml`
