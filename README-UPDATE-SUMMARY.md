# README Update Summary

**Date:** 2026-02-21
**Reason:** Align README with current project state (git-proxy disabled)

## What Changed

### 1. Added Clear Payment Status Indicators

**Before:** Confusing whether Git operations required payment
**After:** Clear table showing what's FREE vs PAID

| Feature               | Status        |
| --------------------- | ------------- |
| Nostr event writes    | ✅ PAID (ILP) |
| NIP-34 Git operations | ✅ PAID (ILP) |
| HTTP Git (clone/push) | ❌ FREE       |
| Forgejo Web UI        | ❌ FREE       |

### 2. Fixed Service URLs and Ports

**Before:**

- Forgejo listed at port 3003 as "ILP-gated Git hosting"
- No distinction between web UI and Git HTTP

**After:**

- Forgejo Web UI: http://localhost:3004 (FREE)
- Forgejo Git HTTP: http://localhost:3004/repo.git (FREE)
- NIP-34 Git: Via Nostr events (PAID)

### 3. Added NIP-34 Documentation

**New sections:**

- NIP-34 event kinds table (30617, 1617, 1621, 1622)
- Detailed explanation of NIP-34 Git integration
- Flow diagram showing payment-gated patch submission
- Comparison table: HTTP Git vs NIP-34

### 4. Updated Package Table

**Changes:**

- Added Status column
- Marked `@crosstown/git-proxy` as "⚠️ Disabled"
- Added note: "needs redesign per RFC-0035"
- Added NIP-34 handler to core package description

### 5. Added Important Notice at Quick Start

**New callout box:**

> ⚡ Important: What's Payment-Gated?
>
> Clear explanation of what requires payment and what doesn't
> Note about git-proxy being disabled

### 6. Reorganized "Nostr Event Kinds" Section

**Before:** "Proposed NIPs (Future Work)"
**After:** "Nostr Event Kinds" with two subsections:

- ✅ Implemented: NIP-34 (Git Stuff)
- ⚠️ Proposed: ILP Peering via Nostr Events

### 7. Enhanced Related Specifications

**Added:**

- Organized into categories (Nostr, Interledger, Other)
- Added NIP-34 link
- Added RFC-0035 (ILP Over HTTP) link

## Key Messaging

### What Works ✅

1. **Nostr relay** - Pay to write events, free to read
2. **NIP-34 Git operations** - Payment-gated patches/issues via Nostr
3. **Bootstrap flow** - Automatic peer discovery and payment channels
4. **Token faucet** - Get test tokens for development

### What's Free ❌ (No Payment Required)

1. **HTTP Git operations** - Standard `git clone`, `git push` work without payment
2. **Forgejo Web UI** - Browse repos, view code, read issues
3. **Nostr relay reads** - Subscribe to events for free

### What's Disabled ⚠️

1. **git-proxy** - HTTP Git payment gateway needs RFC-0035 compliance redesign

## Anti-Confusion Measures

1. **Explicit payment status in every table** - No ambiguity about what costs money
2. **Port numbers in service table** - Clear which port to use for what
3. **NIP-34 vs HTTP Git comparison** - Side-by-side feature comparison
4. **Important callout at Quick Start** - Users see payment status immediately
5. **Status indicators** - ✅ Active, ⚠️ Disabled, ❌ Free

## Documentation Files Referenced

The README now links to:

- `NIP-34-INTEGRATION.md` - Complete NIP-34 workflows
- `QUICKSTART.md` - 5-minute setup guide
- `SETUP-GUIDE.md` - Detailed setup instructions
- `ARCHITECTURE.md` - System architecture diagrams

## Why This Matters

**User Confusion Before:**

- "Do I need to pay for Git?"
- "Why is port 3003 not working?"
- "What's the difference between Forgejo and git-proxy?"

**Clear Answers Now:**

- HTTP Git is FREE (git-proxy disabled)
- NIP-34 is PAID (via Nostr events)
- Forgejo is at port 3004 (web UI + Git HTTP)
- Payment is required for: Nostr event writes + NIP-34 Git operations

## Next Steps

When git-proxy is re-enabled with RFC-0035 compliance:

1. Update status from "⚠️ Disabled" to "✅ Active"
2. Change HTTP Git status from "FREE" to "PAID"
3. Update port 3003 references
4. Add git-proxy to service table
5. Document ILP over HTTP implementation

---

**Review:** This README update makes it impossible to confuse what requires payment. Every service has a clear status, every port is documented, and NIP-34 (the actual payment-gated Git option) is prominently explained.
