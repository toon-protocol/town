#!/usr/bin/env bash
# test-relay-discovery-skill.sh -- ATDD acceptance tests for Story 9.33: Relay Discovery Skill
# TDD RED PHASE: All tests will FAIL until the skill is implemented.
#
# Usage: ./tests/skills/test-relay-discovery-skill.sh
# Exit 0 = all checks pass, 1 = at least one check failed
#
# Covers: NIP-11 (Relay Information Document), NIP-65 (Relay List Metadata),
#         NIP-66 (Relay Discovery and Liveness Monitoring)
#
# Classification: "read-focused" -- NIP-11 HTTP read, NIP-66 monitoring read,
#                 only NIP-65 kind:10002 is agent-writable
#
# Test IDs map to AC-to-Test Mapping:
#   STRUCT-A, STRUCT-B, STRUCT-B2, STRUCT-C, STRUCT-D
#   TOON-A, TOON-B, TOON-C, TOON-D, TOON-ALL-1, TOON-ALL-2
#   EVAL-A, EVAL-B, EVAL-A2, EVAL-B2, EVAL-C
#   TRIG-A, TRIG-B
#   DEP-A, DEP-B, DEP-C, DEP-D
#   CLEAN-A
#   AC1-NAME
#   AC2-NIP11, AC2-NIP11-HTTP, AC2-NIP11-FIELDS, AC2-NIP11-LIMITATION, AC2-NIP11-PAYMENT-REQUIRED
#   AC2-NIP11-TOON-PRICING, AC2-NIP11-TOON-ILP, AC2-NIP11-TOON-CHAIN, AC2-NIP11-TOON-X402
#   AC2-NIP11-TOON-TEE, AC2-NIP11-RETENTION
#   AC3-NIP65, AC3-NIP65-KIND, AC3-NIP65-RTAG, AC3-NIP65-READWRITE, AC3-NIP65-NOCONTENT
#   AC4-NIP66, AC4-NIP66-10166, AC4-NIP66-30166, AC4-NIP66-10066
#   AC4-NIP66-DTAG, AC4-NIP66-RTT, AC4-NIP66-TTAG, AC4-NIP66-PARAMREPLACEABLE
#   AC5-NIPSPEC-ALL3, AC5-NIPSPEC-HTTP, AC5-NIPSPEC-FILTERS
#   AC6-TOONEXT-HEALTH, AC6-TOONEXT-PRICING, AC6-TOONEXT-ILP, AC6-TOONEXT-CHAIN
#   AC6-TOONEXT-X402, AC6-TOONEXT-TEE, AC6-TOONEXT-SEED, AC6-TOONEXT-PEERINFO
#   AC6-TOONEXT-READFOCUS, AC6-TOONEXT-FEE, AC6-TOONEXT-EVAL
#   AC7-SCENARIOS-PAID, AC7-SCENARIOS-RELAYLIST, AC7-SCENARIOS-TEE, AC7-SCENARIOS-TRUST
#   AC7-SCENARIOS-PRICING, AC7-SCENARIOS-GEO, AC7-SCENARIOS-STEPS
#   AC8-EVAL-JSON, AC8-TRIGGER-TRUE, AC8-TRIGGER-FALSE, AC8-TRIGGER-FIELDS
#   AC8-OUTPUT-COUNT, AC8-OUTPUT-FIELDS, AC8-OUTPUT-RUBRIC
#   AC9-IMPERATIVE, AC9-REFS-IMPERATIVE, AC9-WHY
#   AC10-WORDCOUNT, AC10-NIP11-TRIGGER, AC10-NIP65-TRIGGER, AC10-NIP66-TRIGGER
#   AC10-DISCOVERY-TRIGGER, AC10-HEALTH-TRIGGER, AC10-SOCIAL-TRIGGER
#   AC11-WHENTOREAD, AC11-NIPSPEC-REF, AC11-TOONEXT-REF, AC11-SCENARIOS-REF
#   AC12-SOCIAL-SECTION, AC12-ILP-GATED, AC12-COST, AC12-VISIBILITY, AC12-DIVERSITY
#   AC13-NIP11-JSON, AC13-NIP65-RTAG, AC13-NIP66-TAGS, AC13-TOON-FIELDS
#   AC14-ONLY-10002, AC14-PUBLISHEVENT, AC14-NIP11-READONLY, AC14-NIP66-MONITORS
#   AC14-FEE-10002, AC14-DOLLAR, AC14-NIP11-FREE, AC14-READ-FREE
#   AC15-NODUP-CORE, AC15-NODUP-DVM, AC15-NODUP-SOCIAL, AC15-NODUP-CONTEXT
#   TOKEN-LINES, TOKEN-WORDS
#   CROSS-RTAG-SKILL, CROSS-RTAG-SCENARIOS, CROSS-RTAG-TOONEXT
#   CROSS-HEALTH-SKILL, CROSS-HEALTH-TOONEXT, CROSS-HEALTH-SCENARIOS
#   CROSS-SEED-SKILL, CROSS-SEED-TOONEXT, CROSS-PEERINFO-TOONEXT
#   BASE-A (skipped -- requires manual pipeline Step 8)
#
# Total: 95 tests (94 automated + 1 skipped)

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILL_DIR="$PROJECT_ROOT/.claude/skills/relay-discovery"
SKILL_MD="$SKILL_DIR/SKILL.md"
REFS_DIR="$SKILL_DIR/references"
EVALS_DIR="$SKILL_DIR/evals"
EVALS_JSON="$EVALS_DIR/evals.json"

TOTAL=0
PASSED=0
FAILED=0
SKIPPED=0

pass() {
  TOTAL=$((TOTAL + 1))
  PASSED=$((PASSED + 1))
  echo "  PASS [$1]: $2"
}

fail() {
  TOTAL=$((TOTAL + 1))
  FAILED=$((FAILED + 1))
  echo "  FAIL [$1]: $2"
}

skip() {
  TOTAL=$((TOTAL + 1))
  SKIPPED=$((SKIPPED + 1))
  echo "  SKIP [$1]: $2"
}

echo "=== ATDD Acceptance Tests: Story 9.33 Relay Discovery Skill ==="
echo "Skill directory: $SKILL_DIR"
echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STRUCTURAL TESTS (P0)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "-- Structural Tests (P0) --"

# STRUCT-A: SKILL.md exists with valid YAML frontmatter (AC1)
echo "[STRUCT-A] SKILL.md exists with valid frontmatter"
if [ -f "$SKILL_MD" ]; then
  if head -1 "$SKILL_MD" | grep -q '^---$'; then
    pass "STRUCT-A" "SKILL.md exists with YAML frontmatter"
  else
    fail "STRUCT-A" "SKILL.md exists but missing YAML frontmatter"
  fi
else
  fail "STRUCT-A" "SKILL.md does not exist at $SKILL_MD"
fi

# STRUCT-B: references/ directory exists with expected files (AC1)
echo "[STRUCT-B] references/ directory and expected files"
if [ -d "$REFS_DIR" ]; then
  pass "STRUCT-B" "references/ directory exists"
else
  fail "STRUCT-B" "references/ directory does not exist"
fi

for ref_file in nip-spec.md toon-extensions.md scenarios.md; do
  if [ -f "$REFS_DIR/$ref_file" ]; then
    pass "STRUCT-B-$ref_file" "references/$ref_file exists"
  else
    fail "STRUCT-B-$ref_file" "references/$ref_file does not exist"
  fi
done

# STRUCT-B2: evals/ directory and evals.json exist (AC8)
echo "[STRUCT-B2] evals/ directory and evals.json"
if [ -d "$EVALS_DIR" ] && [ -f "$EVALS_JSON" ]; then
  pass "STRUCT-B2" "evals/evals.json exists"
else
  fail "STRUCT-B2" "evals/evals.json does not exist"
fi

# AC1-NAME: frontmatter name = "relay-discovery" (AC1)
echo "[AC1-NAME] Frontmatter name is relay-discovery"
if [ -f "$SKILL_MD" ] && grep -q 'name:.*relay-discovery' "$SKILL_MD" 2>/dev/null; then
  pass "AC1-NAME" "Frontmatter name is relay-discovery"
else
  fail "AC1-NAME" "Frontmatter name is not relay-discovery"
fi

# CLEAN-A: No extraneous files in skill directory (AC1)
echo "[CLEAN-A] No extraneous files"
if [ -d "$SKILL_DIR" ]; then
  top_level=$(ls "$SKILL_DIR" 2>/dev/null | sort | tr '\n' ',')
  if [ "$top_level" = "SKILL.md,evals,references," ]; then
    pass "CLEAN-A" "Skill directory contains only SKILL.md, evals/, references/"
  else
    fail "CLEAN-A" "Unexpected files in skill directory: $top_level"
  fi
else
  fail "CLEAN-A" "Skill directory does not exist"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# AC2: NIP-11 COVERAGE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "-- AC2: NIP-11 Coverage --"

# AC2-NIP11: SKILL.md covers NIP-11
echo "[AC2-NIP11] SKILL.md covers NIP-11 relay information document"
if [ -f "$SKILL_MD" ] && grep -qi 'nip-11' "$SKILL_MD" && grep -qi 'relay information' "$SKILL_MD"; then
  pass "AC2-NIP11" "SKILL.md covers NIP-11 relay information document"
else
  fail "AC2-NIP11" "SKILL.md does not cover NIP-11"
fi

# AC2-NIP11-TOON-PRICING: pricing (basePricePerByte)
echo "[AC2-NIP11-TOON-PRICING] TOON-enriched pricing"
if grep -qi 'basePricePerByte' "$SKILL_MD" 2>/dev/null; then
  pass "AC2-NIP11-TOON-PRICING" "SKILL.md covers basePricePerByte"
else
  fail "AC2-NIP11-TOON-PRICING" "SKILL.md missing basePricePerByte"
fi

# AC2-NIP11-TOON-ILP: ILP capabilities
echo "[AC2-NIP11-TOON-ILP] TOON-enriched ILP capabilities"
if grep -qi 'ilp' "$SKILL_MD" 2>/dev/null && grep -qi 'ilpAddress\|ilp.*address' "$SKILL_MD" 2>/dev/null; then
  pass "AC2-NIP11-TOON-ILP" "SKILL.md covers ILP capabilities"
else
  fail "AC2-NIP11-TOON-ILP" "SKILL.md missing ILP capabilities"
fi

# AC2-NIP11-TOON-CHAIN: chain config
echo "[AC2-NIP11-TOON-CHAIN] TOON-enriched chain config"
if grep -qi 'chainId\|chain.*config' "$SKILL_MD" 2>/dev/null; then
  pass "AC2-NIP11-TOON-CHAIN" "SKILL.md covers chain config"
else
  fail "AC2-NIP11-TOON-CHAIN" "SKILL.md missing chain config"
fi

# AC2-NIP11-TOON-X402: x402 status
echo "[AC2-NIP11-TOON-X402] TOON-enriched x402 status"
if grep -qi 'x402' "$SKILL_MD" 2>/dev/null; then
  pass "AC2-NIP11-TOON-X402" "SKILL.md covers x402 status"
else
  fail "AC2-NIP11-TOON-X402" "SKILL.md missing x402 status"
fi

# AC2-NIP11-TOON-TEE: TEE attestation
echo "[AC2-NIP11-TOON-TEE] TOON-enriched TEE attestation"
if grep -qi 'tee.*attestation\|nitroAttested\|attestation.*status' "$SKILL_MD" 2>/dev/null; then
  pass "AC2-NIP11-TOON-TEE" "SKILL.md covers TEE attestation"
else
  fail "AC2-NIP11-TOON-TEE" "SKILL.md missing TEE attestation"
fi

# AC2-NIP11-PAYMENT-REQUIRED: payment_required field
echo "[AC2-NIP11-PAYMENT-REQUIRED] payment_required in NIP-11"
if grep -qi 'payment_required' "$SKILL_MD" 2>/dev/null; then
  pass "AC2-NIP11-PAYMENT-REQUIRED" "SKILL.md covers payment_required"
else
  fail "AC2-NIP11-PAYMENT-REQUIRED" "SKILL.md missing payment_required"
fi

# AC2-NIP11-HTTP: nip-spec.md covers HTTP GET with Accept header
echo "[AC2-NIP11-HTTP] nip-spec.md covers NIP-11 HTTP GET"
if [ -f "$REFS_DIR/nip-spec.md" ] && grep -qi 'http get\|GET' "$REFS_DIR/nip-spec.md" && grep -q 'application/nostr+json' "$REFS_DIR/nip-spec.md"; then
  pass "AC2-NIP11-HTTP" "nip-spec.md covers HTTP GET with Accept header"
else
  fail "AC2-NIP11-HTTP" "nip-spec.md missing HTTP GET or Accept header"
fi

# AC2-NIP11-FIELDS: nip-spec.md covers standard fields
echo "[AC2-NIP11-FIELDS] nip-spec.md covers NIP-11 standard fields"
if [ -f "$REFS_DIR/nip-spec.md" ] && grep -qi 'supported_nips' "$REFS_DIR/nip-spec.md" && grep -qi 'pubkey' "$REFS_DIR/nip-spec.md"; then
  pass "AC2-NIP11-FIELDS" "nip-spec.md covers standard NIP-11 fields"
else
  fail "AC2-NIP11-FIELDS" "nip-spec.md missing standard NIP-11 fields"
fi

# AC2-NIP11-LIMITATION: nip-spec.md covers limitation object
echo "[AC2-NIP11-LIMITATION] nip-spec.md covers limitation object"
if [ -f "$REFS_DIR/nip-spec.md" ] && grep -qi 'limitation' "$REFS_DIR/nip-spec.md" && grep -qi 'payment_required' "$REFS_DIR/nip-spec.md"; then
  pass "AC2-NIP11-LIMITATION" "nip-spec.md covers limitation object"
else
  fail "AC2-NIP11-LIMITATION" "nip-spec.md missing limitation object"
fi

# AC2-NIP11-RETENTION: nip-spec.md covers retention and relay_countries
echo "[AC2-NIP11-RETENTION] nip-spec.md covers retention and relay_countries"
if [ -f "$REFS_DIR/nip-spec.md" ] && grep -qi 'retention' "$REFS_DIR/nip-spec.md" && grep -qi 'relay_countries' "$REFS_DIR/nip-spec.md"; then
  pass "AC2-NIP11-RETENTION" "nip-spec.md covers retention and relay_countries"
else
  fail "AC2-NIP11-RETENTION" "nip-spec.md missing retention or relay_countries"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# AC3: NIP-65 COVERAGE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "-- AC3: NIP-65 Coverage --"

# AC3-NIP65: SKILL.md covers NIP-65
echo "[AC3-NIP65] SKILL.md covers NIP-65 relay list metadata"
if [ -f "$SKILL_MD" ] && grep -qi 'nip-65' "$SKILL_MD" && grep -q 'kind:10002' "$SKILL_MD"; then
  pass "AC3-NIP65" "SKILL.md covers NIP-65 kind:10002"
else
  fail "AC3-NIP65" "SKILL.md missing NIP-65 or kind:10002"
fi

# AC3-NIP65-RTAG: nip-spec.md covers r tags
echo "[AC3-NIP65-RTAG] nip-spec.md covers r tags with relay URLs"
if [ -f "$REFS_DIR/nip-spec.md" ] && grep -q '\["r"' "$REFS_DIR/nip-spec.md"; then
  pass "AC3-NIP65-RTAG" "nip-spec.md covers r tags"
else
  fail "AC3-NIP65-RTAG" "nip-spec.md missing r tag documentation"
fi

# AC3-NIP65-READWRITE: read/write markers
echo "[AC3-NIP65-READWRITE] nip-spec.md covers read/write markers"
if [ -f "$REFS_DIR/nip-spec.md" ] && grep -qi 'read' "$REFS_DIR/nip-spec.md" && grep -qi 'write' "$REFS_DIR/nip-spec.md"; then
  pass "AC3-NIP65-READWRITE" "nip-spec.md covers read/write markers"
else
  fail "AC3-NIP65-READWRITE" "nip-spec.md missing read/write markers"
fi

# AC3-NIP65-NOCONTENT: no content field
echo "[AC3-NIP65-NOCONTENT] nip-spec.md documents no content field"
if [ -f "$REFS_DIR/nip-spec.md" ] && grep -qi 'no content\|empty content\|content.*empty' "$REFS_DIR/nip-spec.md"; then
  pass "AC3-NIP65-NOCONTENT" "nip-spec.md documents no content field"
else
  fail "AC3-NIP65-NOCONTENT" "nip-spec.md missing no-content documentation"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# AC4: NIP-66 COVERAGE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "-- AC4: NIP-66 Coverage --"

# AC4-NIP66: SKILL.md covers NIP-66
echo "[AC4-NIP66] SKILL.md covers NIP-66"
if [ -f "$SKILL_MD" ] && grep -qi 'nip-66' "$SKILL_MD" && grep -qi 'relay discovery\|relay.*liveness\|relay monitor' "$SKILL_MD"; then
  pass "AC4-NIP66" "SKILL.md covers NIP-66"
else
  fail "AC4-NIP66" "SKILL.md missing NIP-66 coverage"
fi

# AC4-NIP66-10166: kind:10166 relay monitor announcements
echo "[AC4-NIP66-10166] kind:10166 relay monitor announcements"
if [ -f "$SKILL_MD" ] && grep -q 'kind:10166' "$SKILL_MD"; then
  pass "AC4-NIP66-10166" "SKILL.md covers kind:10166"
else
  fail "AC4-NIP66-10166" "SKILL.md missing kind:10166"
fi

# AC4-NIP66-30166: kind:30166 relay meta
echo "[AC4-NIP66-30166] kind:30166 relay meta"
if [ -f "$SKILL_MD" ] && grep -q 'kind:30166' "$SKILL_MD"; then
  pass "AC4-NIP66-30166" "SKILL.md covers kind:30166"
else
  fail "AC4-NIP66-30166" "SKILL.md missing kind:30166"
fi

# AC4-NIP66-10066: kind:10066 relay list to monitor
echo "[AC4-NIP66-10066] kind:10066 relay list to monitor"
if [ -f "$SKILL_MD" ] && grep -q 'kind:10066' "$SKILL_MD"; then
  pass "AC4-NIP66-10066" "SKILL.md covers kind:10066"
else
  fail "AC4-NIP66-10066" "SKILL.md missing kind:10066"
fi

# AC4-NIP66-DTAG: nip-spec.md covers d tag = relay URL for kind:30166
echo "[AC4-NIP66-DTAG] nip-spec.md covers d tag for kind:30166"
if [ -f "$REFS_DIR/nip-spec.md" ] && grep -q '\["d"' "$REFS_DIR/nip-spec.md" && grep -qi 'relay url' "$REFS_DIR/nip-spec.md"; then
  pass "AC4-NIP66-DTAG" "nip-spec.md covers d tag = relay URL"
else
  fail "AC4-NIP66-DTAG" "nip-spec.md missing d tag documentation"
fi

# AC4-NIP66-RTT: nip-spec.md covers rtt (round-trip time)
echo "[AC4-NIP66-RTT] nip-spec.md covers rtt tags"
if [ -f "$REFS_DIR/nip-spec.md" ] && grep -qi 'rtt' "$REFS_DIR/nip-spec.md" && grep -qi 'round.trip' "$REFS_DIR/nip-spec.md"; then
  pass "AC4-NIP66-RTT" "nip-spec.md covers rtt tags"
else
  fail "AC4-NIP66-RTT" "nip-spec.md missing rtt documentation"
fi

# AC4-NIP66-TTAG: nip-spec.md covers t tags for kind:10166
echo "[AC4-NIP66-TTAG] nip-spec.md covers t tags for monitors"
if [ -f "$REFS_DIR/nip-spec.md" ] && grep -q '\["t"' "$REFS_DIR/nip-spec.md"; then
  pass "AC4-NIP66-TTAG" "nip-spec.md covers t tags"
else
  fail "AC4-NIP66-TTAG" "nip-spec.md missing t tag documentation"
fi

# AC4-NIP66-PARAMREPLACEABLE: kind:30166 is parameterized replaceable
echo "[AC4-NIP66-PARAMREPLACEABLE] kind:30166 parameterized replaceable"
if [ -f "$REFS_DIR/nip-spec.md" ] && grep -qi 'parameterized.*replaceable' "$REFS_DIR/nip-spec.md"; then
  pass "AC4-NIP66-PARAMREPLACEABLE" "kind:30166 documented as parameterized replaceable"
else
  fail "AC4-NIP66-PARAMREPLACEABLE" "kind:30166 missing parameterized replaceable documentation"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# AC5: NIP-SPEC.MD CONSOLIDATED
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "-- AC5: nip-spec.md Consolidated Coverage --"

# AC5-NIPSPEC-ALL3: covers all three NIPs
echo "[AC5-NIPSPEC-ALL3] nip-spec.md covers NIP-11, NIP-65, NIP-66"
if [ -f "$REFS_DIR/nip-spec.md" ] && grep -qi 'nip-11' "$REFS_DIR/nip-spec.md" && grep -qi 'nip-65' "$REFS_DIR/nip-spec.md" && grep -qi 'nip-66' "$REFS_DIR/nip-spec.md"; then
  pass "AC5-NIPSPEC-ALL3" "nip-spec.md covers all three NIPs"
else
  fail "AC5-NIPSPEC-ALL3" "nip-spec.md missing one or more NIPs"
fi

# AC5-NIPSPEC-FILTERS: covers filter patterns
echo "[AC5-NIPSPEC-FILTERS] nip-spec.md covers filter patterns"
if [ -f "$REFS_DIR/nip-spec.md" ] && grep -qi 'filter' "$REFS_DIR/nip-spec.md" && grep -qi 'kinds' "$REFS_DIR/nip-spec.md"; then
  pass "AC5-NIPSPEC-FILTERS" "nip-spec.md covers filter patterns"
else
  fail "AC5-NIPSPEC-FILTERS" "nip-spec.md missing filter patterns"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# AC6: TOON-EXTENSIONS.MD
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "-- AC6: toon-extensions.md Coverage --"

# AC6-TOONEXT-HEALTH: enriched /health endpoint
echo "[AC6-TOONEXT-HEALTH] enriched /health endpoint"
if [ -f "$REFS_DIR/toon-extensions.md" ] && grep -q '/health' "$REFS_DIR/toon-extensions.md"; then
  pass "AC6-TOONEXT-HEALTH" "toon-extensions.md covers /health endpoint"
else
  fail "AC6-TOONEXT-HEALTH" "toon-extensions.md missing /health endpoint"
fi

# AC6-TOONEXT-PRICING: basePricePerByte
echo "[AC6-TOONEXT-PRICING] basePricePerByte pricing"
if [ -f "$REFS_DIR/toon-extensions.md" ] && grep -qi 'basePricePerByte' "$REFS_DIR/toon-extensions.md"; then
  pass "AC6-TOONEXT-PRICING" "toon-extensions.md covers basePricePerByte"
else
  fail "AC6-TOONEXT-PRICING" "toon-extensions.md missing basePricePerByte"
fi

# AC6-TOONEXT-ILP: ILP capabilities (ilpAddress, btpUrl)
echo "[AC6-TOONEXT-ILP] ILP capabilities"
if [ -f "$REFS_DIR/toon-extensions.md" ] && grep -qi 'ilpAddress\|ilp.*address' "$REFS_DIR/toon-extensions.md" && grep -qi 'btpUrl\|btp.*url' "$REFS_DIR/toon-extensions.md"; then
  pass "AC6-TOONEXT-ILP" "toon-extensions.md covers ILP capabilities"
else
  fail "AC6-TOONEXT-ILP" "toon-extensions.md missing ILP capabilities"
fi

# AC6-TOONEXT-CHAIN: chain config (chainId, tokenNetworkAddress, usdcAddress)
echo "[AC6-TOONEXT-CHAIN] chain config"
if [ -f "$REFS_DIR/toon-extensions.md" ] && grep -qi 'chainId' "$REFS_DIR/toon-extensions.md" && grep -qi 'tokenNetworkAddress' "$REFS_DIR/toon-extensions.md"; then
  pass "AC6-TOONEXT-CHAIN" "toon-extensions.md covers chain config"
else
  fail "AC6-TOONEXT-CHAIN" "toon-extensions.md missing chain config"
fi

# AC6-TOONEXT-X402: x402 status
echo "[AC6-TOONEXT-X402] x402 status"
if [ -f "$REFS_DIR/toon-extensions.md" ] && grep -qi 'x402' "$REFS_DIR/toon-extensions.md"; then
  pass "AC6-TOONEXT-X402" "toon-extensions.md covers x402"
else
  fail "AC6-TOONEXT-X402" "toon-extensions.md missing x402"
fi

# AC6-TOONEXT-TEE: TEE attestation fields
echo "[AC6-TOONEXT-TEE] TEE attestation fields"
if [ -f "$REFS_DIR/toon-extensions.md" ] && grep -qi 'nitroAttested' "$REFS_DIR/toon-extensions.md" && grep -qi 'enclaveId' "$REFS_DIR/toon-extensions.md" && grep -qi 'pcrs' "$REFS_DIR/toon-extensions.md"; then
  pass "AC6-TOONEXT-TEE" "toon-extensions.md covers TEE attestation fields"
else
  fail "AC6-TOONEXT-TEE" "toon-extensions.md missing TEE attestation fields"
fi

# AC6-TOONEXT-SEED: kind:10036 seed relay discovery
echo "[AC6-TOONEXT-SEED] kind:10036 seed relay discovery"
if [ -f "$REFS_DIR/toon-extensions.md" ] && grep -q 'kind:10036' "$REFS_DIR/toon-extensions.md" && grep -qi 'seed relay' "$REFS_DIR/toon-extensions.md"; then
  pass "AC6-TOONEXT-SEED" "toon-extensions.md covers seed relay discovery"
else
  fail "AC6-TOONEXT-SEED" "toon-extensions.md missing seed relay discovery"
fi

# AC6-TOONEXT-PEERINFO: kind:10032 ILP peer info
echo "[AC6-TOONEXT-PEERINFO] kind:10032 ILP peer info"
if [ -f "$REFS_DIR/toon-extensions.md" ] && grep -q 'kind:10032' "$REFS_DIR/toon-extensions.md"; then
  pass "AC6-TOONEXT-PEERINFO" "toon-extensions.md covers kind:10032"
else
  fail "AC6-TOONEXT-PEERINFO" "toon-extensions.md missing kind:10032"
fi

# AC6-TOONEXT-READFOCUS: read-focused nature documented
echo "[AC6-TOONEXT-READFOCUS] read-focused nature documented"
if [ -f "$REFS_DIR/toon-extensions.md" ] && grep -qi 'read.*focus\|minimal.*write\|only.*kind:10002' "$REFS_DIR/toon-extensions.md"; then
  pass "AC6-TOONEXT-READFOCUS" "toon-extensions.md documents read-focused nature"
else
  fail "AC6-TOONEXT-READFOCUS" "toon-extensions.md missing read-focused documentation"
fi

# AC6-TOONEXT-FEE: fee estimate for kind:10002
echo "[AC6-TOONEXT-FEE] fee estimate for kind:10002"
if [ -f "$REFS_DIR/toon-extensions.md" ] && grep -q 'kind:10002' "$REFS_DIR/toon-extensions.md" && grep -qi 'fee\|cost\|\$' "$REFS_DIR/toon-extensions.md"; then
  pass "AC6-TOONEXT-FEE" "toon-extensions.md has fee estimate for kind:10002"
else
  fail "AC6-TOONEXT-FEE" "toon-extensions.md missing fee estimate for kind:10002"
fi

# AC6-TOONEXT-EVAL: relay evaluation criteria
echo "[AC6-TOONEXT-EVAL] relay evaluation criteria"
if [ -f "$REFS_DIR/toon-extensions.md" ] && grep -qi 'evaluation\|evaluat\|criteria' "$REFS_DIR/toon-extensions.md"; then
  pass "AC6-TOONEXT-EVAL" "toon-extensions.md covers relay evaluation criteria"
else
  fail "AC6-TOONEXT-EVAL" "toon-extensions.md missing relay evaluation criteria"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# AC7: SCENARIOS.MD
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "-- AC7: scenarios.md Coverage --"

# AC7-SCENARIOS-PAID: relay discovery on paid networks
echo "[AC7-SCENARIOS-PAID] relay discovery on paid networks"
if [ -f "$REFS_DIR/scenarios.md" ] && grep -qi 'discover' "$REFS_DIR/scenarios.md" && grep -qi 'paid\|ilp.gated\|cost\|pricing' "$REFS_DIR/scenarios.md"; then
  pass "AC7-SCENARIOS-PAID" "scenarios.md covers paid network discovery"
else
  fail "AC7-SCENARIOS-PAID" "scenarios.md missing paid network discovery"
fi

# AC7-SCENARIOS-RELAYLIST: relay list management
echo "[AC7-SCENARIOS-RELAYLIST] relay list management"
if [ -f "$REFS_DIR/scenarios.md" ] && grep -qi 'relay list' "$REFS_DIR/scenarios.md" && grep -q 'kind:10002' "$REFS_DIR/scenarios.md"; then
  pass "AC7-SCENARIOS-RELAYLIST" "scenarios.md covers relay list management"
else
  fail "AC7-SCENARIOS-RELAYLIST" "scenarios.md missing relay list management"
fi

# AC7-SCENARIOS-TEE: TEE-attested relay evaluation
echo "[AC7-SCENARIOS-TEE] TEE-attested relay evaluation"
if [ -f "$REFS_DIR/scenarios.md" ] && grep -qi 'tee\|attestation\|attested' "$REFS_DIR/scenarios.md"; then
  pass "AC7-SCENARIOS-TEE" "scenarios.md covers TEE relay evaluation"
else
  fail "AC7-SCENARIOS-TEE" "scenarios.md missing TEE relay evaluation"
fi

# AC7-SCENARIOS-TRUST: relay trust and quality signals
echo "[AC7-SCENARIOS-TRUST] relay trust and quality signals"
if [ -f "$REFS_DIR/scenarios.md" ] && grep -qi 'trust\|quality\|signal' "$REFS_DIR/scenarios.md"; then
  pass "AC7-SCENARIOS-TRUST" "scenarios.md covers trust and quality signals"
else
  fail "AC7-SCENARIOS-TRUST" "scenarios.md missing trust and quality signals"
fi

# AC7-SCENARIOS-PRICING: pricing comparison
echo "[AC7-SCENARIOS-PRICING] pricing comparison between relays"
if [ -f "$REFS_DIR/scenarios.md" ] && grep -qi 'pricing\|price.*compar\|compar.*price' "$REFS_DIR/scenarios.md"; then
  pass "AC7-SCENARIOS-PRICING" "scenarios.md covers pricing comparison"
else
  fail "AC7-SCENARIOS-PRICING" "scenarios.md missing pricing comparison"
fi

# AC7-SCENARIOS-GEO: geographic considerations
echo "[AC7-SCENARIOS-GEO] geographic relay considerations"
if [ -f "$REFS_DIR/scenarios.md" ] && grep -qi 'geographic\|region\|latency\|relay_countries' "$REFS_DIR/scenarios.md"; then
  pass "AC7-SCENARIOS-GEO" "scenarios.md covers geographic considerations"
else
  fail "AC7-SCENARIOS-GEO" "scenarios.md missing geographic considerations"
fi

# AC7-SCENARIOS-STEPS: step-by-step TOON flows
echo "[AC7-SCENARIOS-STEPS] step-by-step TOON flows"
if [ -f "$REFS_DIR/scenarios.md" ] && grep -qi 'step' "$REFS_DIR/scenarios.md" && grep -q '/health' "$REFS_DIR/scenarios.md"; then
  pass "AC7-SCENARIOS-STEPS" "scenarios.md provides step-by-step flows"
else
  fail "AC7-SCENARIOS-STEPS" "scenarios.md missing step-by-step flows"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# AC8: EVAL SUITE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "-- AC8: Eval Suite --"

# AC8-EVAL-JSON: valid JSON
echo "[AC8-EVAL-JSON] evals.json is valid JSON"
if [ -f "$EVALS_JSON" ] && python3 -c "import json; json.load(open('$EVALS_JSON'))" 2>/dev/null; then
  pass "AC8-EVAL-JSON" "evals.json is valid JSON"
else
  fail "AC8-EVAL-JSON" "evals.json is not valid JSON or does not exist"
fi

# AC8-TRIGGER-TRUE: 8-10 should_trigger:true
echo "[AC8-TRIGGER-TRUE] 8-10 should_trigger:true"
if [ -f "$EVALS_JSON" ]; then
  count=$(python3 -c "import json; d=json.load(open('$EVALS_JSON')); print(len([e for e in d.get('trigger_evals',[]) if e.get('should_trigger')==True]))" 2>/dev/null || echo 0)
  if [ "$count" -ge 8 ] && [ "$count" -le 10 ]; then
    pass "AC8-TRIGGER-TRUE" "$count should_trigger:true evals (8-10 range)"
  else
    fail "AC8-TRIGGER-TRUE" "$count should_trigger:true evals (expected 8-10)"
  fi
else
  fail "AC8-TRIGGER-TRUE" "evals.json does not exist"
fi

# AC8-TRIGGER-FALSE: 8-10 should_trigger:false
echo "[AC8-TRIGGER-FALSE] 8-10 should_trigger:false"
if [ -f "$EVALS_JSON" ]; then
  count=$(python3 -c "import json; d=json.load(open('$EVALS_JSON')); print(len([e for e in d.get('trigger_evals',[]) if e.get('should_trigger')==False]))" 2>/dev/null || echo 0)
  if [ "$count" -ge 8 ] && [ "$count" -le 10 ]; then
    pass "AC8-TRIGGER-FALSE" "$count should_trigger:false evals (8-10 range)"
  else
    fail "AC8-TRIGGER-FALSE" "$count should_trigger:false evals (expected 8-10)"
  fi
else
  fail "AC8-TRIGGER-FALSE" "evals.json does not exist"
fi

# AC8-TRIGGER-FIELDS: each trigger eval has query and should_trigger
echo "[AC8-TRIGGER-FIELDS] trigger evals have required fields"
if [ -f "$EVALS_JSON" ]; then
  valid=$(python3 -c "
import json
d=json.load(open('$EVALS_JSON'))
ok=all('query' in e and 'should_trigger' in e for e in d.get('trigger_evals',[]))
print('true' if ok else 'false')
" 2>/dev/null || echo "false")
  if [ "$valid" = "true" ]; then
    pass "AC8-TRIGGER-FIELDS" "All trigger evals have query and should_trigger"
  else
    fail "AC8-TRIGGER-FIELDS" "Some trigger evals missing required fields"
  fi
else
  fail "AC8-TRIGGER-FIELDS" "evals.json does not exist"
fi

# AC8-OUTPUT-COUNT: 4-6 output evals
echo "[AC8-OUTPUT-COUNT] 4-6 output evals"
if [ -f "$EVALS_JSON" ]; then
  count=$(python3 -c "import json; d=json.load(open('$EVALS_JSON')); print(len(d.get('output_evals',[])))" 2>/dev/null || echo 0)
  if [ "$count" -ge 4 ] && [ "$count" -le 6 ]; then
    pass "AC8-OUTPUT-COUNT" "$count output evals (4-6 range)"
  else
    fail "AC8-OUTPUT-COUNT" "$count output evals (expected 4-6)"
  fi
else
  fail "AC8-OUTPUT-COUNT" "evals.json does not exist"
fi

# AC8-OUTPUT-FIELDS: output evals have required fields
echo "[AC8-OUTPUT-FIELDS] output evals have required fields"
if [ -f "$EVALS_JSON" ]; then
  valid=$(python3 -c "
import json
d=json.load(open('$EVALS_JSON'))
fields=['id','prompt','expected_output','rubric','assertions']
ok=all(all(f in e for f in fields) for e in d.get('output_evals',[]))
print('true' if ok else 'false')
" 2>/dev/null || echo "false")
  if [ "$valid" = "true" ]; then
    pass "AC8-OUTPUT-FIELDS" "All output evals have required fields"
  else
    fail "AC8-OUTPUT-FIELDS" "Some output evals missing required fields"
  fi
else
  fail "AC8-OUTPUT-FIELDS" "evals.json does not exist"
fi

# AC8-OUTPUT-RUBRIC: rubric has correct/acceptable/incorrect
echo "[AC8-OUTPUT-RUBRIC] output evals rubric structure"
if [ -f "$EVALS_JSON" ]; then
  valid=$(python3 -c "
import json
d=json.load(open('$EVALS_JSON'))
ok=all(all(k in e.get('rubric',{}) for k in ['correct','acceptable','incorrect']) for e in d.get('output_evals',[]))
print('true' if ok else 'false')
" 2>/dev/null || echo "false")
  if [ "$valid" = "true" ]; then
    pass "AC8-OUTPUT-RUBRIC" "All output evals have correct/acceptable/incorrect rubric"
  else
    fail "AC8-OUTPUT-RUBRIC" "Some output evals missing rubric fields"
  fi
else
  fail "AC8-OUTPUT-RUBRIC" "evals.json does not exist"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# AC9: IMPERATIVE FORM AND SKILL PATTERN
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "-- AC9: Writing Style --"

# AC9-IMPERATIVE: SKILL.md uses imperative form
echo "[AC9-IMPERATIVE] SKILL.md uses imperative form"
if [ -f "$SKILL_MD" ] && ! grep -qi 'you should' "$SKILL_MD"; then
  pass "AC9-IMPERATIVE" "SKILL.md uses imperative form (no 'you should')"
else
  fail "AC9-IMPERATIVE" "SKILL.md contains 'you should' (not imperative form)"
fi

# AC9-REFS-IMPERATIVE: reference files use imperative form
echo "[AC9-REFS-IMPERATIVE] references use imperative form"
refs_ok=true
for ref_file in nip-spec.md toon-extensions.md scenarios.md; do
  if [ -f "$REFS_DIR/$ref_file" ] && grep -qi 'you should' "$REFS_DIR/$ref_file"; then
    refs_ok=false
  fi
done
if [ "$refs_ok" = true ] && [ -d "$REFS_DIR" ]; then
  pass "AC9-REFS-IMPERATIVE" "Reference files use imperative form"
else
  fail "AC9-REFS-IMPERATIVE" "Reference files contain 'you should'"
fi

# AC9-WHY: reference files explain WHY
echo "[AC9-WHY] reference files explain WHY"
why_ok=true
for ref_file in nip-spec.md toon-extensions.md scenarios.md; do
  if [ -f "$REFS_DIR/$ref_file" ] && ! grep -qi 'why\|because\|reason\|this means\|this matter' "$REFS_DIR/$ref_file"; then
    why_ok=false
  fi
done
if [ "$why_ok" = true ] && [ -d "$REFS_DIR" ]; then
  pass "AC9-WHY" "Reference files explain WHY"
else
  fail "AC9-WHY" "Reference files missing WHY explanations"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# AC10: DESCRIPTION OPTIMIZATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "-- AC10: Description Optimization --"

# AC10-WORDCOUNT: 80-120 words
echo "[AC10-WORDCOUNT] description is 80-120 words"
if [ -f "$SKILL_MD" ]; then
  desc=$(sed -n '/^---$/,/^---$/p' "$SKILL_MD" | grep -i 'description:' | sed 's/^[^:]*: *//' | sed "s/^['\"]//;s/['\"]$//" 2>/dev/null)
  if [ -n "$desc" ]; then
    wc_count=$(echo "$desc" | wc -w | tr -d ' ')
    if [ "$wc_count" -ge 80 ] && [ "$wc_count" -le 120 ]; then
      pass "AC10-WORDCOUNT" "Description is $wc_count words (80-120 range)"
    else
      fail "AC10-WORDCOUNT" "Description is $wc_count words (expected 80-120)"
    fi
  else
    fail "AC10-WORDCOUNT" "Could not extract description from frontmatter"
  fi
else
  fail "AC10-WORDCOUNT" "SKILL.md does not exist"
fi

# AC10-NIP11-TRIGGER: description includes NIP-11
echo "[AC10-NIP11-TRIGGER] description includes NIP-11"
if [ -f "$SKILL_MD" ]; then
  desc=$(sed -n '/^---$/,/^---$/p' "$SKILL_MD" | grep -i 'description:')
  if echo "$desc" | grep -qi 'nip.11'; then
    pass "AC10-NIP11-TRIGGER" "Description includes NIP-11 trigger"
  else
    fail "AC10-NIP11-TRIGGER" "Description missing NIP-11 trigger"
  fi
else
  fail "AC10-NIP11-TRIGGER" "SKILL.md does not exist"
fi

# AC10-NIP65-TRIGGER: description includes NIP-65
echo "[AC10-NIP65-TRIGGER] description includes NIP-65"
if [ -f "$SKILL_MD" ]; then
  desc=$(sed -n '/^---$/,/^---$/p' "$SKILL_MD" | grep -i 'description:')
  if echo "$desc" | grep -qi 'nip.65'; then
    pass "AC10-NIP65-TRIGGER" "Description includes NIP-65 trigger"
  else
    fail "AC10-NIP65-TRIGGER" "Description missing NIP-65 trigger"
  fi
else
  fail "AC10-NIP65-TRIGGER" "SKILL.md does not exist"
fi

# AC10-NIP66-TRIGGER: description includes NIP-66
echo "[AC10-NIP66-TRIGGER] description includes NIP-66"
if [ -f "$SKILL_MD" ]; then
  desc=$(sed -n '/^---$/,/^---$/p' "$SKILL_MD" | grep -i 'description:')
  if echo "$desc" | grep -qi 'nip.66'; then
    pass "AC10-NIP66-TRIGGER" "Description includes NIP-66 trigger"
  else
    fail "AC10-NIP66-TRIGGER" "Description missing NIP-66 trigger"
  fi
else
  fail "AC10-NIP66-TRIGGER" "SKILL.md does not exist"
fi

# AC10-DISCOVERY-TRIGGER: description includes relay discovery
echo "[AC10-DISCOVERY-TRIGGER] description includes relay discovery"
if [ -f "$SKILL_MD" ]; then
  desc=$(sed -n '/^---$/,/^---$/p' "$SKILL_MD" | grep -i 'description:')
  if echo "$desc" | grep -qi 'relay.*discover\|discover.*relay'; then
    pass "AC10-DISCOVERY-TRIGGER" "Description includes relay discovery trigger"
  else
    fail "AC10-DISCOVERY-TRIGGER" "Description missing relay discovery trigger"
  fi
else
  fail "AC10-DISCOVERY-TRIGGER" "SKILL.md does not exist"
fi

# AC10-HEALTH-TRIGGER: description includes relay health
echo "[AC10-HEALTH-TRIGGER] description includes relay health"
if [ -f "$SKILL_MD" ]; then
  desc=$(sed -n '/^---$/,/^---$/p' "$SKILL_MD" | grep -i 'description:')
  if echo "$desc" | grep -qi 'relay.*health\|health.*check\|check.*relay'; then
    pass "AC10-HEALTH-TRIGGER" "Description includes relay health trigger"
  else
    fail "AC10-HEALTH-TRIGGER" "Description missing relay health trigger"
  fi
else
  fail "AC10-HEALTH-TRIGGER" "SKILL.md does not exist"
fi

# AC10-SOCIAL-TRIGGER: description includes social-situation triggers
echo "[AC10-SOCIAL-TRIGGER] description includes social-situation triggers"
if [ -f "$SKILL_MD" ]; then
  desc=$(sed -n '/^---$/,/^---$/p' "$SKILL_MD" | grep -i 'description:')
  if echo "$desc" | grep -qi 'how do i\|how do.*relay\|which relay'; then
    pass "AC10-SOCIAL-TRIGGER" "Description includes social-situation triggers"
  else
    fail "AC10-SOCIAL-TRIGGER" "Description missing social-situation triggers"
  fi
else
  fail "AC10-SOCIAL-TRIGGER" "SKILL.md does not exist"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# AC11: WHEN TO READ EACH REFERENCE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "-- AC11: When to Read Each Reference --"

# AC11-WHENTOREAD: section exists
echo "[AC11-WHENTOREAD] 'When to Read Each Reference' section"
if [ -f "$SKILL_MD" ] && grep -qi 'when to.*read.*each reference\|when to.*load.*each reference\|when to.*consult.*each reference' "$SKILL_MD"; then
  pass "AC11-WHENTOREAD" "SKILL.md has 'When to Read Each Reference' section"
else
  fail "AC11-WHENTOREAD" "SKILL.md missing 'When to Read Each Reference' section"
fi

# AC11-NIPSPEC-REF: mentions nip-spec.md
echo "[AC11-NIPSPEC-REF] mentions nip-spec.md"
if [ -f "$SKILL_MD" ] && grep -q 'nip-spec\.md' "$SKILL_MD"; then
  pass "AC11-NIPSPEC-REF" "SKILL.md mentions nip-spec.md"
else
  fail "AC11-NIPSPEC-REF" "SKILL.md does not mention nip-spec.md"
fi

# AC11-TOONEXT-REF: mentions toon-extensions.md
echo "[AC11-TOONEXT-REF] mentions toon-extensions.md"
if [ -f "$SKILL_MD" ] && grep -q 'toon-extensions\.md' "$SKILL_MD"; then
  pass "AC11-TOONEXT-REF" "SKILL.md mentions toon-extensions.md"
else
  fail "AC11-TOONEXT-REF" "SKILL.md does not mention toon-extensions.md"
fi

# AC11-SCENARIOS-REF: mentions scenarios.md
echo "[AC11-SCENARIOS-REF] mentions scenarios.md"
if [ -f "$SKILL_MD" ] && grep -q 'scenarios\.md' "$SKILL_MD"; then
  pass "AC11-SCENARIOS-REF" "SKILL.md mentions scenarios.md"
else
  fail "AC11-SCENARIOS-REF" "SKILL.md does not mention scenarios.md"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# AC12: SOCIAL CONTEXT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "-- AC12: Social Context --"

# AC12-SOCIAL-SECTION: Social Context section exists
echo "[AC12-SOCIAL-SECTION] Social Context section exists"
if [ -f "$SKILL_MD" ] && grep -q '## Social Context' "$SKILL_MD"; then
  pass "AC12-SOCIAL-SECTION" "SKILL.md has Social Context section"
else
  fail "AC12-SOCIAL-SECTION" "SKILL.md missing Social Context section"
fi

# AC12-ILP-GATED: ILP-gated relays signal quality
echo "[AC12-ILP-GATED] ILP-gated relays signal quality"
if [ -f "$SKILL_MD" ] && grep -qi 'ilp.gated\|paid.*relay' "$SKILL_MD" && grep -qi 'quality\|signal\|filter.*spam' "$SKILL_MD"; then
  pass "AC12-ILP-GATED" "Social Context covers ILP-gated quality signal"
else
  fail "AC12-ILP-GATED" "Social Context missing ILP-gated quality signal"
fi

# AC12-COST: relay selection impacts payment costs
echo "[AC12-COST] relay selection impacts costs"
if [ -f "$SKILL_MD" ] && grep -qi 'relay.*selection\|select.*relay\|choos' "$SKILL_MD" && grep -qi 'cost\|payment\|pricing' "$SKILL_MD"; then
  pass "AC12-COST" "Social Context covers cost impact"
else
  fail "AC12-COST" "Social Context missing cost impact"
fi

# AC12-VISIBILITY: relay selection impacts content visibility
echo "[AC12-VISIBILITY] relay selection impacts visibility"
if [ -f "$SKILL_MD" ] && grep -qi 'visibility\|reach\|audience' "$SKILL_MD"; then
  pass "AC12-VISIBILITY" "Social Context covers visibility impact"
else
  fail "AC12-VISIBILITY" "Social Context missing visibility impact"
fi

# AC12-DIVERSITY: relay diversity for resilience
echo "[AC12-DIVERSITY] relay diversity for resilience"
if [ -f "$SKILL_MD" ] && grep -qi 'diversity\|resilience\|redundanc\|multiple' "$SKILL_MD"; then
  pass "AC12-DIVERSITY" "Social Context covers relay diversity"
else
  fail "AC12-DIVERSITY" "Social Context missing relay diversity"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# AC14: READ-FOCUSED SKILL
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "-- AC14: Read-Focused Skill --"

# AC14-ONLY-10002: only kind:10002 is writable
echo "[AC14-ONLY-10002] only kind:10002 writable"
if grep -rqi 'kind:10002.*only.*writ\|only.*writ.*kind:10002\|only.*kind:10002' "$SKILL_DIR"/*.md "$SKILL_DIR"/references/*.md 2>/dev/null; then
  pass "AC14-ONLY-10002" "Documents kind:10002 as only writable event"
else
  fail "AC14-ONLY-10002" "Missing documentation that kind:10002 is only writable event"
fi

# AC14-PUBLISHEVENT: uses publishEvent
echo "[AC14-PUBLISHEVENT] uses publishEvent"
if grep -rq 'publishEvent' "$SKILL_DIR"/*.md "$SKILL_DIR"/references/*.md 2>/dev/null; then
  pass "AC14-PUBLISHEVENT" "Skill uses publishEvent"
else
  fail "AC14-PUBLISHEVENT" "Skill missing publishEvent reference"
fi

# AC14-NIP11-READONLY: NIP-11 is read-only
echo "[AC14-NIP11-READONLY] NIP-11 is read-only"
if grep -rqi 'read.only\|http get\|no.*write' "$SKILL_DIR"/*.md "$SKILL_DIR"/references/*.md 2>/dev/null; then
  pass "AC14-NIP11-READONLY" "NIP-11 documented as read-only"
else
  fail "AC14-NIP11-READONLY" "NIP-11 missing read-only documentation"
fi

# AC14-NIP66-MONITORS: NIP-66 published by monitors
echo "[AC14-NIP66-MONITORS] NIP-66 published by monitors"
if grep -rqi 'monitor.*operator\|relay.*monitor.*publish\|not.*end.user' "$SKILL_DIR"/*.md "$SKILL_DIR"/references/*.md 2>/dev/null; then
  pass "AC14-NIP66-MONITORS" "NIP-66 documented as monitor-published"
else
  fail "AC14-NIP66-MONITORS" "NIP-66 missing monitor-published documentation"
fi

# AC14-FEE-10002: fee for kind:10002
echo "[AC14-FEE-10002] fee awareness for kind:10002"
if grep -rqi 'per.byte\|basePricePerByte' "$SKILL_DIR"/*.md "$SKILL_DIR"/references/*.md 2>/dev/null; then
  pass "AC14-FEE-10002" "Fee awareness for kind:10002"
else
  fail "AC14-FEE-10002" "Missing fee awareness for kind:10002"
fi

# AC14-DOLLAR: concrete dollar estimates
echo "[AC14-DOLLAR] concrete dollar estimates"
if grep -rq '\$0\.' "$SKILL_DIR"/*.md "$SKILL_DIR"/references/*.md 2>/dev/null; then
  pass "AC14-DOLLAR" "Concrete dollar estimates present"
else
  fail "AC14-DOLLAR" "Missing concrete dollar estimates"
fi

# AC14-NIP11-FREE: NIP-11 fetch is free
echo "[AC14-NIP11-FREE] NIP-11 fetch is free"
if grep -rqi 'free\|no.*cost\|no.*fee' "$SKILL_DIR"/*.md "$SKILL_DIR"/references/*.md 2>/dev/null; then
  pass "AC14-NIP11-FREE" "NIP-11 fetch documented as free"
else
  fail "AC14-NIP11-FREE" "Missing NIP-11 free documentation"
fi

# AC14-READ-FREE: reading is free on TOON
echo "[AC14-READ-FREE] reading is free"
if grep -rqi 'read.*free\|free.*read' "$SKILL_DIR"/*.md "$SKILL_DIR"/references/*.md 2>/dev/null; then
  pass "AC14-READ-FREE" "Reading documented as free"
else
  fail "AC14-READ-FREE" "Missing read-free documentation"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# AC15: NO DUPLICATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "-- AC15: No Duplication --"

# AC15-NODUP-CORE: references nostr-protocol-core
echo "[AC15-NODUP-CORE] references nostr-protocol-core"
if [ -f "$SKILL_MD" ] && grep -q 'nostr-protocol-core' "$SKILL_MD"; then
  pass "AC15-NODUP-CORE" "References nostr-protocol-core"
else
  fail "AC15-NODUP-CORE" "Missing nostr-protocol-core reference"
fi

# AC15-NODUP-DVM: no DVM relay routing duplication
echo "[AC15-NODUP-DVM] no DVM relay routing duplication"
if [ -f "$SKILL_MD" ] && ! grep -qi 'kind:5[0-9]\{3\}.*route\|dvm.*job.*route' "$SKILL_MD"; then
  pass "AC15-NODUP-DVM" "No DVM relay routing duplication"
else
  fail "AC15-NODUP-DVM" "Contains DVM relay routing details (duplication)"
fi

# AC15-NODUP-SOCIAL: no kind:3 follow list duplication
echo "[AC15-NODUP-SOCIAL] no kind:3 follow list duplication"
if [ -f "$SKILL_MD" ] && ! grep -qi 'kind:3.*follow\|follow.*list.*kind:3' "$SKILL_MD"; then
  pass "AC15-NODUP-SOCIAL" "No kind:3 follow list duplication"
else
  fail "AC15-NODUP-SOCIAL" "Contains kind:3 follow list details (duplication)"
fi

# AC15-NODUP-CONTEXT: no toon-protocol-context.md in references
echo "[AC15-NODUP-CONTEXT] no toon-protocol-context.md in references"
if [ -d "$REFS_DIR" ] && ! [ -f "$REFS_DIR/toon-protocol-context.md" ]; then
  pass "AC15-NODUP-CONTEXT" "No toon-protocol-context.md in references"
else
  fail "AC15-NODUP-CONTEXT" "toon-protocol-context.md found in references"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TOKEN BUDGET
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "-- Token Budget --"

# TOKEN-LINES: SKILL.md under 500 lines
echo "[TOKEN-LINES] SKILL.md under 500 lines"
if [ -f "$SKILL_MD" ]; then
  lines=$(wc -l < "$SKILL_MD" | tr -d ' ')
  if [ "$lines" -lt 500 ]; then
    pass "TOKEN-LINES" "SKILL.md is $lines lines (under 500)"
  else
    fail "TOKEN-LINES" "SKILL.md is $lines lines (expected under 500)"
  fi
else
  fail "TOKEN-LINES" "SKILL.md does not exist"
fi

# TOKEN-WORDS: SKILL.md body under 3500 words
echo "[TOKEN-WORDS] SKILL.md body under 3500 words"
if [ -f "$SKILL_MD" ]; then
  words=$(sed '1,/^---$/d' "$SKILL_MD" | sed '/^---$/,$!d; /^---$/d' | wc -w | tr -d ' ')
  if [ "$words" -le 3500 ]; then
    pass "TOKEN-WORDS" "SKILL.md body is $words words (under 3500)"
  else
    fail "TOKEN-WORDS" "SKILL.md body is $words words (expected under 3500)"
  fi
else
  fail "TOKEN-WORDS" "SKILL.md does not exist"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CROSS-CUTTING CONSISTENCY
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "-- Cross-Cutting Consistency --"

# CROSS-RTAG-SKILL: r tag documented in SKILL.md
echo "[CROSS-RTAG-SKILL] r tag in SKILL.md"
if [ -f "$SKILL_MD" ] && grep -q '\["r"' "$SKILL_MD"; then
  pass "CROSS-RTAG-SKILL" "r tag documented in SKILL.md"
else
  fail "CROSS-RTAG-SKILL" "r tag missing from SKILL.md"
fi

# CROSS-RTAG-TOONEXT: r tag in toon-extensions.md
echo "[CROSS-RTAG-TOONEXT] r tag in toon-extensions.md"
if [ -f "$REFS_DIR/toon-extensions.md" ] && grep -qi 'r.*tag\|\["r"' "$REFS_DIR/toon-extensions.md"; then
  pass "CROSS-RTAG-TOONEXT" "r tag mentioned in toon-extensions.md"
else
  fail "CROSS-RTAG-TOONEXT" "r tag missing from toon-extensions.md"
fi

# CROSS-HEALTH-SKILL: /health in SKILL.md
echo "[CROSS-HEALTH-SKILL] /health in SKILL.md"
if [ -f "$SKILL_MD" ] && grep -q '/health' "$SKILL_MD"; then
  pass "CROSS-HEALTH-SKILL" "/health endpoint in SKILL.md"
else
  fail "CROSS-HEALTH-SKILL" "/health endpoint missing from SKILL.md"
fi

# CROSS-HEALTH-TOONEXT: /health in toon-extensions.md with enriched fields
echo "[CROSS-HEALTH-TOONEXT] /health in toon-extensions.md with enriched fields"
if [ -f "$REFS_DIR/toon-extensions.md" ] && grep -q '/health' "$REFS_DIR/toon-extensions.md" && grep -qi 'basePricePerByte' "$REFS_DIR/toon-extensions.md"; then
  pass "CROSS-HEALTH-TOONEXT" "/health with enriched fields in toon-extensions.md"
else
  fail "CROSS-HEALTH-TOONEXT" "/health missing enriched fields in toon-extensions.md"
fi

# CROSS-HEALTH-SCENARIOS: /health in scenarios.md
echo "[CROSS-HEALTH-SCENARIOS] /health in scenarios.md"
if [ -f "$REFS_DIR/scenarios.md" ] && grep -q '/health' "$REFS_DIR/scenarios.md"; then
  pass "CROSS-HEALTH-SCENARIOS" "/health endpoint in scenarios.md"
else
  fail "CROSS-HEALTH-SCENARIOS" "/health endpoint missing from scenarios.md"
fi

# CROSS-SEED-SKILL: kind:10036 in SKILL.md
echo "[CROSS-SEED-SKILL] kind:10036 in SKILL.md"
if [ -f "$SKILL_MD" ] && grep -q 'kind:10036' "$SKILL_MD"; then
  pass "CROSS-SEED-SKILL" "kind:10036 in SKILL.md"
else
  fail "CROSS-SEED-SKILL" "kind:10036 missing from SKILL.md"
fi

# CROSS-SEED-TOONEXT: kind:10036 in toon-extensions.md with bootstrap
echo "[CROSS-SEED-TOONEXT] kind:10036 in toon-extensions.md"
if [ -f "$REFS_DIR/toon-extensions.md" ] && grep -q 'kind:10036' "$REFS_DIR/toon-extensions.md" && grep -qi 'bootstrap' "$REFS_DIR/toon-extensions.md"; then
  pass "CROSS-SEED-TOONEXT" "kind:10036 with bootstrap in toon-extensions.md"
else
  fail "CROSS-SEED-TOONEXT" "kind:10036 or bootstrap missing from toon-extensions.md"
fi

# CROSS-PEERINFO-TOONEXT: kind:10032 in toon-extensions.md
echo "[CROSS-PEERINFO-TOONEXT] kind:10032 in toon-extensions.md"
if [ -f "$REFS_DIR/toon-extensions.md" ] && grep -q 'kind:10032' "$REFS_DIR/toon-extensions.md"; then
  pass "CROSS-PEERINFO-TOONEXT" "kind:10032 in toon-extensions.md"
else
  fail "CROSS-PEERINFO-TOONEXT" "kind:10032 missing from toon-extensions.md"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# WITH/WITHOUT BASELINE (P2 -- manual pipeline verification)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "-- With/Without Baseline (P2) --"

skip "BASE-A" "With/without baseline requires manual pipeline execution (Step 8 of nip-to-toon-skill)"

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SUMMARY
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo "=== ATDD Test Results ==="
echo "Total: $TOTAL | Passed: $PASSED | Failed: $FAILED | Skipped: $SKIPPED"

if [ "$FAILED" -gt 0 ]; then
  echo "Status: RED (TDD red phase -- $FAILED failing tests)"
  exit 1
else
  echo "Status: GREEN (all tests pass)"
  exit 0
fi
