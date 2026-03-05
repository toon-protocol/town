# Crosstown Protocol

ILP-gated Nostr relay. Pay to write, free to read.

> **Detailed rules, patterns, and conventions are in `_bmad-output/project-context.md`** -- loaded automatically by BMAD workflows. This file covers setup, commands, and operational knowledge not found there.

---

## Commands

```bash
# Build & Test
pnpm install                  # Install all dependencies
pnpm build                    # Build all packages (pnpm -r run build)
pnpm test                     # Run all tests (vitest)
pnpm test:coverage            # Run tests with coverage
pnpm lint                     # Lint codebase (ESLint flat config)
pnpm format                   # Format code (Prettier, write mode)
pnpm format:check             # Check formatting without writing

# Package-level
cd packages/sdk && pnpm test:integration   # SDK integration tests
cd packages/client && pnpm test:e2e        # E2E tests (requires running genesis node)

# Deployment
./deploy-genesis-node.sh      # Deploy full genesis stack (Anvil + Faucet + Connector + Node)
./deploy-peers.sh 3           # Deploy 3 peer nodes
```

---

## Prerequisites

- Docker & Docker Compose
- Node.js >=20 (24.x recommended for local dev)
- pnpm 8.15.0 (`corepack enable && corepack prepare pnpm@8.15.0 --activate`)
- Connector contracts repo cloned to `../connector`

---

## Genesis Node Endpoints

| Service   | URL                     |
|-----------|-------------------------|
| Faucet    | http://localhost:3500    |
| Relay     | ws://localhost:7100      |
| BLS       | http://localhost:3100    |
| Connector | http://localhost:8080    |
| Anvil     | http://localhost:8545    |

Peer N offsets: BLS `3100+N*10`, Relay `7100+N*10`, Connector `8080+N*10`.

---

## Deployment Verification

```bash
# Health checks
curl http://localhost:3100/health   # BLS
curl http://localhost:8545           # Anvil

# Full E2E (bootstrap + channels + publish + on-chain validation)
cd packages/client && pnpm test:e2e genesis-bootstrap-with-channels

# Logs
docker compose -p crosstown-genesis logs -f crosstown
```

---

## Troubleshooting

**Genesis node won't start:**
1. `docker ps` -- Docker running?
2. `ls ../connector/packages/contracts` -- Contracts repo present?
3. `docker logs crosstown-node` -- Check container logs

**Tests failing:**
1. `curl http://localhost:3100/health` -- Genesis node up?
2. `curl http://localhost:8545` -- Anvil healthy?
3. `./deploy-genesis-node.sh --reset` -- Clear stale containers
