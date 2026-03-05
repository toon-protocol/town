# NIP-34 Git Integration with Crosstown

## Overview

Crosstown integrates **NIP-34 (Git Stuff)** to enable Git operations via Nostr events. This provides a **decentralized, ILP-gated Git workflow** where developers submit patches, PRs, and issues as Nostr events that require payment.

## Two Complementary Approaches

Crosstown supports **two ways** to interact with Git repositories:

### 1. HTTP Git Operations (via git-proxy)

Traditional `git clone/push/pull` with ILP payment gating.

```
git clone http://localhost:3003/user/repo.git
```

**Use for:**

- Standard Git workflows
- IDE integrations
- Large file transfers
- Binary files

### 2. Nostr Event-Based Operations (NIP-34)

Submit Git operations as Nostr events that get applied to Forgejo.

```
nostr publish --kind 1617 patch.txt
```

**Use for:**

- Decentralized collaboration
- Censorship resistance
- Social Git (follows, mentions)
- Small patches (<60KB)

## NIP-34 Event Types

| Kind          | Type                    | Description                             | Payment Required |
| ------------- | ----------------------- | --------------------------------------- | ---------------- |
| **30617**     | Repository Announcement | Publish repository metadata, clone URLs | ✅ Yes           |
| **1617**      | Patch                   | Submit code changes (format-patch)      | ✅ Yes           |
| **1618**      | Pull Request            | Reference branch/commits for merge      | ✅ Yes           |
| **1621**      | Issue                   | Bug report or feature request           | ✅ Yes           |
| **1630-1633** | Status Updates          | Open/merged/closed/draft states         | ✅ Yes           |

All NIP-34 events require ILP payment to be stored by the relay.

## Architecture

```
Developer
    │
    ├─→ Git HTTP (clone/push) → Git Proxy → Forgejo
    │                                ↓
    │                              Pay via ILP
    │
    └─→ Nostr Event (patch/PR) → Crosstown Relay → BLS
                                        ↓              ↓
                                    Pay via ILP    Store Event
                                                       ↓
                                                  NIP34Handler
                                                       ↓
                                                   Forgejo
                                                  (apply patch)
```

## Flow: Submitting a Patch via NIP-34

### Step 1: Create Patch

```bash
# Make changes
git add file.txt
git commit -m "Fix typo"

# Generate patch
git format-patch HEAD~1 --stdout > my-patch.txt
```

### Step 2: Create NIP-34 Patch Event

```bash
# Patch event (kind 1617)
nostr event create \
  --kind 1617 \
  --content "$(cat my-patch.txt)" \
  --tag "a:30617:${REPO_OWNER_PUBKEY}:my-repo" \
  --tag "commit:abc123" \
  --tag "parent-commit:def456"
```

### Step 3: Pay to Publish

```bash
# Calculate price (event size × price per byte)
EVENT_SIZE=$(stat -f%z event.json)
PRICE=$((EVENT_SIZE * 10))

# Pay via ILP
ilp-pay --amount $PRICE --destination g.crosstown.my-node
```

### Step 4: Publish with Payment Proof

```bash
# Publish to Crosstown relay
nostr publish \
  --relay ws://localhost:7100 \
  --payment-proof $ILP_PROOF \
  event.json
```

### Step 5: Crosstown Processes Event

```
1. Relay receives event
2. BLS validates ILP payment
3. Event stored in database
4. NIP34Handler triggered
5. Handler applies patch to Forgejo
6. Git commit created
```

## Configuration

### Environment Variables

```bash
# Required for NIP-34 integration
FORGEJO_URL=http://forgejo:3000
FORGEJO_TOKEN=<admin-token>
FORGEJO_OWNER=crosstown  # Default owner for repos

# Optional
FORGEJO_WORK_DIR=/tmp/git-work  # Git working directory
```

### Generate Forgejo Token

```bash
# Access Forgejo admin panel
http://localhost:3003/user/settings/applications

# Or via CLI
docker exec crosstown-forgejo \
  forgejo admin user generate-access-token \
  --username crosstown \
  --scopes write:repository,write:issue,write:pull_request
```

### Docker Compose Configuration

```yaml
crosstown:
  environment:
    # Enable NIP-34
    FORGEJO_URL: http://forgejo:3000
    FORGEJO_TOKEN: ${FORGEJO_TOKEN} # Set in .env
    FORGEJO_OWNER: crosstown
```

## NIP-34 Handler Operations

### Repository Announcement (kind 30617)

Creates or updates repository metadata in Forgejo.

**Event Structure:**

```json
{
  "kind": 30617,
  "tags": [
    ["d", "my-repo"],
    ["name", "My Awesome Project"],
    ["description", "A cool project"],
    ["clone", "http://localhost:3003/crosstown/my-repo.git"],
    ["maintainers", "pubkey1", "pubkey2"]
  ]
}
```

**Handler Action:**

- Creates repository in Forgejo if doesn't exist
- Updates description and settings
- Adds maintainers as collaborators

### Patch Submission (kind 1617)

Applies a `git format-patch` patch directly to the repository.

**Event Structure:**

```json
{
  "kind": 1617,
  "content": "From abc123...\nSubject: [PATCH] Fix bug\n...",
  "tags": [
    ["a", "30617:pubkey:my-repo"],
    ["commit", "abc123"],
    ["parent-commit", "def456"]
  ]
}
```

**Handler Action:**

1. Clones repository
2. Checks out parent commit
3. Applies patch using `git am`
4. Pushes to Forgejo

### Pull Request (kind 1618)

References commits from a contributor's fork/branch.

**Event Structure:**

```json
{
  "kind": 1618,
  "tags": [
    ["a", "30617:pubkey:upstream-repo"],
    ["clone", "http://contributor-repo.git"],
    ["c", "commit-tip-sha"],
    ["merge-base", "base-commit-sha"],
    ["subject", "Add feature X"]
  ]
}
```

**Handler Action:**

1. Fetches contributor's commits
2. Creates PR in Forgejo
3. Links to Nostr event for discussion

### Issue Creation (kind 1621)

Creates an issue in Forgejo's issue tracker.

**Event Structure:**

```json
{
  "kind": 1621,
  "content": "## Bug Report\n\nSteps to reproduce...",
  "tags": [
    ["a", "30617:pubkey:repo"],
    ["subject", "Login broken on Safari"],
    ["t", "bug"],
    ["t", "ui"]
  ]
}
```

**Handler Action:**

- Creates issue in Forgejo
- Sets labels from `t` tags
- Links to Nostr event

## Pricing for NIP-34 Events

NIP-34 events are priced like any other Nostr event:

```
price = event_size_bytes × BASE_PRICE_PER_BYTE
```

**Example:**

- Small patch (5KB): 5120 × 10 = **51,200 units**
- Large patch (50KB): 51200 × 10 = **512,000 units**
- Issue (2KB): 2048 × 10 = **20,480 units**

**Note:** Events over 60KB should use pull requests (kind 1618) instead of patches.

## Benefits of NIP-34 Integration

### 1. Censorship Resistance

- Patches stored on Nostr relays
- Multiple relays = redundancy
- Can't be taken down by single entity

### 2. Social Integration

- Follow maintainers (NIP-02)
- Mention contributors in patches
- Zap developers for merged PRs

### 3. Decentralized Collaboration

- No central Git host required
- Repository announcements discoverable via Nostr
- Cross-relay collaboration

### 4. Monetization

- Developers earn from accepted patches
- ILP micropayments for contributions
- Direct peer-to-peer payments

### 5. Provenance

- All events cryptographically signed
- Immutable contribution history
- Portable across platforms

## Comparison: HTTP vs NIP-34

| Feature          | HTTP Git       | NIP-34 Events          |
| ---------------- | -------------- | ---------------------- |
| **Operation**    | `git push`     | Nostr event            |
| **Size Limit**   | Unlimited      | ~60KB per event        |
| **Payment**      | Per operation  | Per event              |
| **Censorship**   | Can be blocked | Relay redundancy       |
| **Discovery**    | URL-based      | Nostr follows          |
| **Social**       | None           | Full Nostr integration |
| **Offline**      | No             | Events can queue       |
| **Binary Files** | ✅ Yes         | ❌ No                  |
| **Large Repos**  | ✅ Yes         | ❌ Use PRs             |

## Example Workflow

### Maintainer: Publish Repository

```bash
# Create repo announcement
nostr event create --kind 30617 \
  --tag "d:my-project" \
  --tag "name:My Awesome Project" \
  --tag "description:A cool thing" \
  --tag "clone:http://localhost:3003/crosstown/my-project.git"

# Pay and publish
ilp-pay --amount 20480 --destination g.crosstown
nostr publish --relay ws://localhost:7100 event.json
```

### Contributor: Submit Patch

```bash
# Make changes
git checkout -b fix-bug
# ... edit files ...
git commit -m "Fix null pointer bug"

# Create patch
git format-patch main --stdout > fix.patch

# Create patch event
nostr event create --kind 1617 \
  --content "$(cat fix.patch)" \
  --tag "a:30617:${MAINTAINER_PUBKEY}:my-project"

# Pay and submit
ilp-pay --amount 51200
nostr publish --relay ws://localhost:7100 event.json
```

### Maintainer: Apply Patch

Crosstown **automatically** applies the patch when the event is received!

```
✅ NIP-34 patch: Applied patch 'Fix null pointer bug' to my-project
   Commit: abc123
   Author: contributor@nostr
```

The commit appears in Forgejo, ready to view/merge.

## Testing NIP-34 Integration

### 1. Start Crosstown with NIP-34 Enabled

```bash
# Set Forgejo token in .env
echo "FORGEJO_TOKEN=your-token-here" >> .env

# Start stack
docker compose -f docker-compose-with-local.yml up -d

# Check logs
docker logs crosstown-node | grep NIP-34
# Should see: ✅ NIP-34 Git integration enabled
```

### 2. Create Test Repository in Forgejo

```bash
# Access Forgejo
open http://localhost:3003

# Create repo: crosstown/test-repo
```

### 3. Submit Test Patch via Nostr

```bash
# Create patch
echo "Test change" > test.txt
git add test.txt
git commit -m "Test patch"
git format-patch HEAD~1 --stdout > test.patch

# Submit as NIP-34 event
# (requires Nostr client with ILP payment support)
```

## Troubleshooting

### NIP-34 Integration Not Enabled

```
📝 NIP-34 Git integration disabled
```

**Solution:** Set `FORGEJO_TOKEN` environment variable.

### Patch Application Failed

```
❌ NIP-34 patch: Failed to apply patch
```

**Causes:**

- Invalid patch format
- Merge conflicts
- Repository doesn't exist

**Check:** Forgejo logs and Git working directory.

### Payment Validation Failed

```
Payment required: 51200 units
```

**Solution:** Include valid ILP payment proof in event.

## Future Enhancements

- [ ] NIP-34 client library
- [ ] Automatic PR creation from patches
- [ ] Code review via Nostr replies
- [ ] Zaps for merged contributions
- [ ] Multi-sig repository ownership
- [ ] Decentralized CI/CD triggers

## Resources

- [NIP-34 Specification](https://github.com/nostr-protocol/nips/blob/master/34.md)
- [Forgejo API Docs](https://forgejo.org/docs/latest/api/)
- [Git Format-Patch](https://git-scm.com/docs/git-format-patch)

---

**NIP-34 + ILP = Sustainable, Decentralized Git Collaboration** 🚀
