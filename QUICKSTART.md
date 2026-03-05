# Crosstown Quick Start

**Get ILP-gated Git running in 5 minutes** ⚡

---

## 1️⃣ Start Everything

```bash
# Generate Nostr key
export NOSTR_SECRET_KEY=$(openssl rand -hex 32)
echo "NOSTR_SECRET_KEY=$NOSTR_SECRET_KEY" > .env

# Start services
docker compose -f docker-compose-with-local.yml up -d

# Wait 30 seconds ⏳
```

## 2️⃣ Set Up Forgejo

```bash
# Open Forgejo Web UI (FREE browsing)
open http://localhost:3004

# If first time: click through setup, create admin account
# Username: admin
# Password: admin123

# Generate API Token:
# Settings → Applications → Generate Token
# Scopes: Select "All" (or write:repository, write:issue, write:pull_request)
# Name: crosstown

# Add token to .env
echo "FORGEJO_TOKEN=<paste-token-here>" >> .env
echo "FORGEJO_OWNER=admin" >> .env
```

## 3️⃣ Enable NIP-34

```bash
# Restart to load config
docker compose -f docker-compose-with-local.yml restart crosstown-node

# Verify
docker logs crosstown-node 2>&1 | grep NIP-34
# Should say: ✅ NIP-34 Git integration enabled
```

## ✅ Done!

### Test It

```bash
# Run automated test
./test-nip34.sh

# Check all services
docker compose -f docker-compose-with-local.yml ps
```

### What You Have

| Service            | URL                   | Description                | Payment |
| ------------------ | --------------------- | -------------------------- | ------- |
| **Forgejo Web UI** | http://localhost:3004 | Browse repos, issues, docs | ✅ FREE |
| **Git Operations** | http://localhost:3003 | Clone/push via Git         | 💰 PAID |
| **Crosstown**      | http://localhost:3100 | BLS + Nostr relay          | -       |
| **Connector**      | http://localhost:3001 | ILP routing (Explorer UI)  | -       |
| **Faucet**         | http://localhost:3500 | Get test tokens            | -       |

### Use It

**Browse Web UI (free):**

```bash
open http://localhost:3004
# View code, issues, PRs - no payment required
```

**Git Operations (paid):**

```bash
# Clone requires ILP payment
git clone http://localhost:3003/admin/test-repo.git
```

**Nostr Events (NIP-34):**

```bash
# Submit patches as Nostr events
# See NIP-34-INTEGRATION.md for details
```

**Security Note:** Web editor is disabled - all commits must go through paid Git operations!

---

## Troubleshooting

**NIP-34 still disabled?**

```bash
# Check .env has FORGEJO_TOKEN
cat .env | grep FORGEJO_TOKEN

# Restart
docker compose -f docker-compose-with-local.yml restart crosstown-node
```

**Service won't start?**

```bash
# Check logs
docker logs crosstown-node

# Check all services
docker compose -f docker-compose-with-local.yml ps
```

**Port conflict?**

```bash
# Find what's using the port
lsof -i :3003

# Kill it or change the port in docker-compose-with-local.yml
```

---

## Next Steps

📖 **[SETUP-GUIDE.md](SETUP-GUIDE.md)** - Complete detailed guide
📖 **[NIP-34-INTEGRATION.md](NIP-34-INTEGRATION.md)** - Nostr event workflows
📖 **[ILP-GATED-GIT-SUMMARY.md](ILP-GATED-GIT-SUMMARY.md)** - Architecture details

---

**Need help?** Check logs: `docker compose -f docker-compose-with-local.yml logs`
