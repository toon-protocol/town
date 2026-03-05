# Crosstown Documentation Index

**Complete guide to all documentation - start here!**

---

## 🚀 Getting Started (Start Here!)

### [QUICKSTART.md](QUICKSTART.md)

**5-minute setup guide**

- Fastest way to get running
- Step-by-step commands
- Troubleshooting tips
- Perfect for: First-time users

### [SETUP-GUIDE.md](SETUP-GUIDE.md)

**Complete setup guide**

- Detailed explanations
- Environment variables
- Common tasks
- Troubleshooting
- Perfect for: Production setup

---

## 📖 Architecture & Design

### [ARCHITECTURE.md](ARCHITECTURE.md)

**Visual system architecture**

- Complete system diagrams
- Data flow visualization
- Component responsibilities
- Network topology
- Port reference
- Perfect for: Understanding the system

### [SECURITY.md](SECURITY.md) 🔒

**Security model & access control**

- Port separation (3003 vs 3004)
- Payment enforcement
- Attack vectors & mitigations
- Configuration security
- Perfect for: Security review

### [CLAUDE.md](CLAUDE.md)

**Project overview**

- High-level design
- Event kinds (NIP-02, NIP-34, SPSP)
- Key design decisions
- Perfect for: Contributors

---

## 🔧 Feature Documentation

### [NIP-34-INTEGRATION.md](NIP-34-INTEGRATION.md)

**Git operations via Nostr events**

- How NIP-34 works
- Event types and structures
- Patch submission workflow
- Pricing model
- Examples
- Perfect for: Nostr developers

### [ILP-GATED-GIT-SUMMARY.md](ILP-GATED-GIT-SUMMARY.md)

**HTTP Git payment gateway**

- Git proxy architecture
- Payment flow
- Pricing model
- API reference
- Perfect for: Git integration

---

## 📝 Implementation Summaries

### [ENTRYPOINT-RENAME.md](ENTRYPOINT-RENAME.md)

**Entrypoint refactoring**

- Why we renamed entrypoints
- Migration guide
- Before/after comparison
- Perfect for: Understanding code structure

### [BOOTSTRAP-TEST-RESULTS.md](BOOTSTRAP-TEST-RESULTS.md)

**Bootstrap flow validation**

- Test results
- Payment channel testing
- System validation
- Perfect for: Verifying setup

### [SECURITY-FIX-SUMMARY.md](SECURITY-FIX-SUMMARY.md) 🔒

**Critical security fix**

- Port separation implementation
- Web UI bypass eliminated
- Before/after comparison
- Migration guide
- Perfect for: Understanding the security fix

---

## 🧪 Testing

### [test-nip34.sh](test-nip34.sh)

**NIP-34 integration test**

```bash
./test-nip34.sh
```

- Validates NIP-34 configuration
- Creates test repository
- Checks Forgejo connectivity
- Perfect for: Verification

### [test-local-bootstrap.sh](test-local-bootstrap.sh)

**Bootstrap flow test**

```bash
./test-local-bootstrap.sh
```

- Tests full-featured entrypoint
- Validates all services
- Checks endpoints
- Perfect for: System validation

---

## 📦 Package Documentation

### [packages/git-proxy/README.md](packages/git-proxy/README.md)

**Git proxy package**

- API reference
- Configuration
- Docker usage
- Development guide

### [packages/core/](packages/core/)

**Core library**

- NIP-34 handler
- Bootstrap service
- SPSP implementation
- Event parsing

### [packages/bls/](packages/bls/)

**Business Logic Server**

- Packet validation
- Event storage
- Pricing service

---

## 🗺️ Quick Reference

### What Should I Read?

**I want to get started fast:**
→ [QUICKSTART.md](QUICKSTART.md)

**I want to understand the system:**
→ [ARCHITECTURE.md](ARCHITECTURE.md)

**I want to use NIP-34 (Nostr events):**
→ [NIP-34-INTEGRATION.md](NIP-34-INTEGRATION.md)

**I want to use Git HTTP (traditional):**
→ [ILP-GATED-GIT-SUMMARY.md](ILP-GATED-GIT-SUMMARY.md)

**I want to contribute code:**
→ [CLAUDE.md](CLAUDE.md) + [ARCHITECTURE.md](ARCHITECTURE.md)

**I need to troubleshoot:**
→ [SETUP-GUIDE.md](SETUP-GUIDE.md) (Troubleshooting section)

**I want to test everything:**
→ Run `./test-nip34.sh` and `./test-local-bootstrap.sh`

---

## 📚 Documentation by Use Case

### For Developers

| Task                         | Document                                             |
| ---------------------------- | ---------------------------------------------------- |
| Set up local environment     | [QUICKSTART.md](QUICKSTART.md)                       |
| Submit Git patches via Nostr | [NIP-34-INTEGRATION.md](NIP-34-INTEGRATION.md)       |
| Use traditional Git          | [ILP-GATED-GIT-SUMMARY.md](ILP-GATED-GIT-SUMMARY.md) |
| Understand payment flow      | [ARCHITECTURE.md](ARCHITECTURE.md)                   |

### For System Administrators

| Task                  | Document                                           |
| --------------------- | -------------------------------------------------- |
| Deploy in production  | [SETUP-GUIDE.md](SETUP-GUIDE.md)                   |
| Configure environment | [SETUP-GUIDE.md](SETUP-GUIDE.md) (Env vars)        |
| Monitor services      | [SETUP-GUIDE.md](SETUP-GUIDE.md) (Common tasks)    |
| Troubleshoot issues   | [SETUP-GUIDE.md](SETUP-GUIDE.md) (Troubleshooting) |

### For Contributors

| Task                    | Document                                     |
| ----------------------- | -------------------------------------------- |
| Understand architecture | [ARCHITECTURE.md](ARCHITECTURE.md)           |
| Learn project design    | [CLAUDE.md](CLAUDE.md)                       |
| Review recent changes   | [ENTRYPOINT-RENAME.md](ENTRYPOINT-RENAME.md) |
| Run tests               | `./test-nip34.sh`                            |

---

## 🔄 Documentation Updates

This documentation was created on **2026-02-21** and covers:

✅ NIP-34 integration with Forgejo
✅ ILP-gated Git HTTP proxy
✅ Bootstrap flow with payment channels
✅ Full-featured entrypoint (default)
✅ Multi-service Docker Compose setup

---

## 📋 Checklist for New Users

- [ ] Read [QUICKSTART.md](QUICKSTART.md)
- [ ] Start services: `docker compose -f docker-compose-with-local.yml up -d`
- [ ] Set up Forgejo API token
- [ ] Run test: `./test-nip34.sh`
- [ ] Read [ARCHITECTURE.md](ARCHITECTURE.md) to understand the system
- [ ] Explore [NIP-34-INTEGRATION.md](NIP-34-INTEGRATION.md) for Nostr workflows
- [ ] Check services: `docker compose -f docker-compose-with-local.yml ps`

---

## 🤝 Contributing

Found a mistake? Want to improve docs?

1. Read [CLAUDE.md](CLAUDE.md) for project guidelines
2. Make changes
3. Submit PR
4. Update this index if adding new docs

---

**All documentation is in the repository root and `packages/*/README.md`**
