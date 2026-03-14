# Crosstown Protocol

ILP-gated Nostr relay. Pay to write, free to read.

> **All coding rules, patterns, conventions, and architecture details are in `_bmad-output/project-context.md`** -- loaded automatically by BMAD workflows. This file covers only setup, deployment, and troubleshooting.

---

## Quick Reference

```bash
pnpm install && pnpm build && pnpm test   # Build & test all packages
pnpm lint && pnpm format                   # Lint & format

./deploy-genesis-node.sh          # Deploy genesis stack (Anvil + Faucet + Connector + Node)
./deploy-genesis-node.sh --reset  # Reset and redeploy from scratch
./deploy-peers.sh 3               # Deploy N peer nodes

# SDK E2E infrastructure (multi-hop routing, payment channels)
./scripts/sdk-e2e-infra.sh up     # Build, start Anvil + 2 Docker peers, wait for health
./scripts/sdk-e2e-infra.sh down   # Stop containers
cd packages/sdk && pnpm test:e2e:docker   # Run SDK E2E tests against infra
```

---

## Prerequisites

- Docker & Docker Compose
- Node.js >=20, pnpm 8.15.0 (`corepack enable && corepack prepare pnpm@8.15.0 --activate`)
- Connector contracts repo cloned at `../connector` (required for genesis deployment)

---

## Deployment Verification

```bash
# Health checks (genesis node)
curl http://localhost:3100/health   # BLS (enriched: pricing, capabilities, chain, x402 status)
curl http://localhost:8545           # Anvil (JSON-RPC, returns error object = healthy)
curl http://localhost:3500/health   # Faucet
# Relay (port 7100) is WebSocket-only -- no HTTP health endpoint

# x402 endpoint (when enabled)
curl http://localhost:3100/publish  # Returns 402 with pricing info (no X-PAYMENT header)

# E2E validation (requires running genesis node)
cd packages/client && pnpm test:e2e    # Client E2E (payment channels, bootstrap)
cd packages/town && pnpm test:e2e      # Town E2E (lifecycle, requires genesis infra)

# View logs
docker compose -p crosstown-genesis -f docker-compose-genesis.yml logs -f
docker compose -p crosstown-genesis -f docker-compose-genesis.yml logs -f crosstown  # Node only
```

---

## Key Environment Variables

These configure deployment beyond defaults. Full config docs are in project-context.md.

| Variable                  | Purpose                                                    | Default       |
| ------------------------- | ---------------------------------------------------------- | ------------- |
| `CROSSTOWN_CHAIN`         | Chain preset (`anvil`, `arbitrum-sepolia`, `arbitrum-one`) | `anvil`       |
| `CROSSTOWN_RPC_URL`       | Override chain preset RPC URL                              | (from preset) |
| `CROSSTOWN_TOKEN_NETWORK` | Override TokenNetwork address                              | (from preset) |
| `CROSSTOWN_X402_ENABLED`  | Enable x402 `/publish` HTTP endpoint                       | `false`       |
| `CROSSTOWN_MNEMONIC`      | Node identity mnemonic (prefer over CLI flag)              | --            |
| `CROSSTOWN_CONNECTOR_URL` | Standalone connector HTTP URL                              | --            |

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

**Port conflicts:**

- Genesis ports: BLS 3100, Relay 7100, Connector 8080/8081/3000, Faucet 3500, Anvil 8545
- Peer N ports: BLS 3100+N*10, Relay 7100+N*10, Connector 8080+N\*10
- SDK E2E ports: Anvil 18545, Peer1 (BTP 19000, BLS 19100, Relay 19700), Peer2 (BTP 19010, BLS 19110, Relay 19710)
