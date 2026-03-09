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
curl http://localhost:3100/health   # BLS
curl http://localhost:8545           # Anvil (JSON-RPC, returns error object = healthy)
curl http://localhost:3500/health   # Faucet
# Relay (port 7100) is WebSocket-only -- no HTTP health endpoint

# E2E validation (requires running genesis node)
cd packages/client && pnpm test:e2e    # Client E2E (payment channels, bootstrap)
cd packages/town && pnpm test:e2e      # Town E2E (lifecycle, requires genesis infra)

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

**Port conflicts:**
- Genesis ports: BLS 3100, Relay 7100, Connector 8080/8081/3000, Faucet 3500, Anvil 8545
- Peer N ports: BLS 3100+N*10, Relay 7100+N*10, Connector 8080+N*10
