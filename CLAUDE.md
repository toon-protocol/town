# Crosstown Protocol

ILP-gated Nostr relay. Pay to write, free to read.

> **All coding rules, patterns, conventions, and architecture details are in `_bmad-output/project-context.md`** -- loaded automatically by BMAD workflows. This file covers only setup, deployment, and troubleshooting. Do NOT duplicate rules or patterns here.

---

## Quick Reference

```bash
# Build & test
pnpm install && pnpm build && pnpm test   # Build & test all packages (~2,095 tests)
pnpm lint && pnpm format                   # Lint & format

# Genesis stack (Anvil + Faucet + Connector + Node)
./deploy-genesis-node.sh
./deploy-genesis-node.sh --reset           # Reset and redeploy from scratch

# Peer nodes
./deploy-peers.sh 3                        # Deploy N peer nodes

# SDK E2E infrastructure (multi-hop routing, payment channels, DVM lifecycle)
./scripts/sdk-e2e-infra.sh up              # Build, start Anvil + 2 Docker peers, wait for health
./scripts/sdk-e2e-infra.sh down            # Stop containers
cd packages/sdk && pnpm test:e2e:docker    # Run SDK E2E tests against infra
cd packages/sdk && pnpm test:integration   # Run SDK integration tests against infra

# Oyster CVM (TEE) build
docker build -f docker/Dockerfile.oyster -t crosstown:oyster .

# Nix reproducible Docker image (requires Nix)
nix build .#docker-image && docker load < result
```

---

## Prerequisites

- Docker & Docker Compose
- Node.js >=20, pnpm 8.15.0 (`corepack enable && corepack prepare pnpm@8.15.0 --activate`)
- Connector contracts repo cloned at `../connector` (required for genesis deployment)
- (Optional) Nix package manager for reproducible builds

See `_bmad-output/project-context.md` section "Technology Stack & Versions" for exact version constraints and compiler options.

---

## Deployment Verification

```bash
# Health checks (genesis node)
curl http://localhost:3100/health   # BLS (enriched: pricing, capabilities, chain, x402, TEE status)
curl http://localhost:8545           # Anvil (JSON-RPC, returns error object = healthy)
curl http://localhost:3500/health   # Faucet
# Relay (port 7100) is WebSocket-only -- no HTTP health endpoint

# x402 endpoint (when enabled)
curl http://localhost:3100/publish  # Returns 402 with pricing info (no X-PAYMENT header)

# E2E validation (requires running genesis node)
cd packages/client && pnpm test:e2e    # Client E2E (payment channels, bootstrap)
cd packages/town && pnpm test:e2e      # Town E2E (lifecycle, requires genesis infra)

# E2E validation (requires SDK E2E infra: ./scripts/sdk-e2e-infra.sh up)
cd packages/sdk && pnpm test:e2e:docker    # SDK Docker E2E (DVM lifecycle, publish, settlement)

# View logs
docker compose -p crosstown-genesis -f docker-compose-genesis.yml logs -f
docker compose -p crosstown-genesis -f docker-compose-genesis.yml logs -f crosstown  # Node only
```

---

## Troubleshooting

**Genesis node won't start:**

1. `docker ps` -- Docker daemon running?
2. `ls ../connector/packages/contracts` -- Contracts repo cloned at correct path?
3. `docker compose -p crosstown-genesis -f docker-compose-genesis.yml logs crosstown` -- Check container logs

**Tests failing:**

1. `curl http://localhost:3100/health` -- Genesis node up?
2. `curl http://localhost:8545` -- Anvil healthy?
3. `./deploy-genesis-node.sh --reset` -- Clear stale containers and rebuild

**SDK E2E tests failing:**

1. `./scripts/sdk-e2e-infra.sh up` -- Infrastructure running?
2. `curl http://localhost:19100/health` -- Peer1 healthy?
3. `curl http://localhost:19110/health` -- Peer2 healthy?
4. `./scripts/sdk-e2e-infra.sh down && ./scripts/sdk-e2e-infra.sh up` -- Restart infra

**Port conflicts:** See `_bmad-output/project-context.md` section "Deployment" for full port allocation table. Key ranges:

- Genesis: BLS 3100, Relay 7100, Anvil 8545, Faucet 3500
- SDK E2E: Anvil 18545, Peer1 19000/19100/19700, Peer2 19010/19110/19710
- Oyster CVM attestation server: 1300

---

## Where to Find Things

| Topic | Location |
| --- | --- |
| **All coding rules, patterns, conventions** | `_bmad-output/project-context.md` |
| Epic roadmap & status (Epics 1-5 complete) | `_bmad-output/project-context.md` section "Epic Roadmap" |
| Known action items (Epic 5 retro) | `_bmad-output/project-context.md` section "Known Action Items" |
| DVM compute marketplace architecture | `_bmad-output/project-context.md` section "DVM Compute Marketplace" |
| TEE architecture & attestation flow | `_bmad-output/project-context.md` section "TEE Integration" |
| Chain config & env vars | `_bmad-output/project-context.md` section "Chain Configuration Rules" |
| Oyster CVM Dockerfile & compose | `docker/Dockerfile.oyster`, `docker/docker-compose-oyster.yml` |
| SDK E2E Docker compose | `docker-compose-sdk-e2e.yml` |
| Nix reproducible build flake | `flake.nix` (root) |
| Attestation server source | `docker/src/attestation-server.ts` |
| Docker entrypoints (SDK & Town) | `docker/src/entrypoint-sdk.ts`, `docker/src/entrypoint-town.ts` |
| Content publishing pipeline | `_bmad-output/planning-artifacts/content-strategy-2026-q1.md` |
| Content publishing workflow | `_bmad-output/planning-artifacts/content/publish-workflow.md` |
| Character spec (brand voice) | `_bmad-output/planning-artifacts/content/character-spec.md` |
| Article drafts | `_bmad-output/planning-artifacts/content/article-N/` |
| Mock USDC deployment script | `scripts/deploy-mock-usdc.sh` |
