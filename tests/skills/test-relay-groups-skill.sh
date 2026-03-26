#!/usr/bin/env bash
# test-relay-groups-skill.sh -- ATDD acceptance tests for Story 9.8: Relay Groups Skill
# TDD RED PHASE: All tests will FAIL until the skill is implemented.
#
# Usage: ./tests/skills/test-relay-groups-skill.sh
# Exit 0 = all checks pass, 1 = at least one check failed
#
# Test IDs map to AC-to-Test Mapping in atdd-checklist-9-8.md:
#   STRUCT-A, STRUCT-B, STRUCT-B2, STRUCT-C, STRUCT-D
#   TOON-A, TOON-B, TOON-C, TOON-D, TOON-ALL-1, TOON-ALL-2
#   EVAL-A, EVAL-B, EVAL-A2, EVAL-B2, EVAL-C
#   TRIG-A, TRIG-B
#   DEP-A, DEP-B, DEP-C, DEP-D
#   CLEAN-A
#   AC1-NAME
#   AC2-NIP29, AC2-RELAY-AUTH, AC2-KINDS-MSG, AC2-KINDS-ADMIN, AC2-KINDS-META
#   AC2-HTAG, AC2-TOONEXT, AC2-SCENARIOS, AC2-PERMS, AC2-OPEN-CLOSED
#   AC3-CLIENT, AC3-FEEREF, AC3-HTAG-REQ, AC3-ADMIN-COST, AC3-ILP-GATE
#   AC3-COREREF
#   AC4-FORMAT, AC4-HTAG-FILTER, AC4-REPLACEABLE, AC4-READREF
#   AC5-CULTURE, AC5-ECON, AC5-ADMIN-WEIGHT, AC5-REACTION-INTIMACY
#   AC5-CLOSED-TRUST, AC5-RELAY-NORMS, AC5-SUBST
#   AC6-RUBRIC, AC6-TOON-ASSERT, AC6-TRIGGER-QUERIES, AC6-NOTTRIGGER-QUERIES
#   AC6-EXPECTED-OPT, AC6-OUTPUT-ID, AC6-OUTPUT-ASSERT
#   AC8-TRIGPHRASES, AC8-STRICT-RANGE, AC8-SOCIAL-PHRASES, AC8-GROUP-PHRASES
#   AC9-TOKENS
#   AC10-NODUP, AC10-DEP-ALL
#   AC7-NAMED-ASSERTIONS
#   BASE-A (skipped -- requires manual pipeline Step 8)
#
# Total: 67 tests (66 automated + 1 skipped)

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILL_DIR="$PROJECT_ROOT/.claude/skills/relay-groups"
VALIDATE_SCRIPT="$PROJECT_ROOT/.claude/skills/nip-to-toon-skill/scripts/validate-skill.sh"
RUNEVAL_SCRIPT="$PROJECT_ROOT/.claude/skills/skill-eval-framework/scripts/run-eval.sh"

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

echo "=== ATDD Acceptance Tests: Story 9.8 Relay Groups Skill ==="
echo "Skill directory: $SKILL_DIR"
echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STRUCTURAL TESTS (P0)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "── Structural Tests (P0) ──"

# STRUCT-A: SKILL.md exists with valid YAML frontmatter (AC1)
echo "[STRUCT-A] SKILL.md exists with valid frontmatter"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  FRONTMATTER=$(sed -n '/^---$/,/^---$/p' "$SKILL_DIR/SKILL.md")
  if [ -z "$FRONTMATTER" ]; then
    fail "STRUCT-A" "SKILL.md has no YAML frontmatter"
  elif echo "$FRONTMATTER" | grep -q '^name:' && echo "$FRONTMATTER" | grep -q '^description:'; then
    EXTRA_FIELDS=$(echo "$FRONTMATTER" | grep -E '^[a-zA-Z][a-zA-Z0-9_-]*:' | grep -v '^name:' | grep -v '^description:' | grep -v '^---$' || true)
    if [ -n "$EXTRA_FIELDS" ]; then
      fail "STRUCT-A" "Frontmatter has extra fields (only name and description allowed): $EXTRA_FIELDS"
    else
      pass "STRUCT-A" "SKILL.md has valid frontmatter with only name and description"
    fi
  else
    fail "STRUCT-A" "Frontmatter missing name or description field"
  fi
else
  fail "STRUCT-A" "SKILL.md not found at $SKILL_DIR/SKILL.md"
fi

# STRUCT-B: references/ directory with required files (AC1)
echo "[STRUCT-B] references/ directory with required files"
REFS_OK=true
REFS_MISSING=""
for REF_FILE in nip-spec.md toon-extensions.md scenarios.md; do
  if [ ! -f "$SKILL_DIR/references/$REF_FILE" ]; then
    REFS_OK=false
    REFS_MISSING="$REFS_MISSING $REF_FILE"
  fi
done
if [ "$REFS_OK" = true ] && [ -d "$SKILL_DIR/references" ]; then
  pass "STRUCT-B" "All required reference files present"
else
  fail "STRUCT-B" "Missing reference file(s):$REFS_MISSING"
fi

# STRUCT-B2: evals/evals.json exists and is valid JSON (AC1)
echo "[STRUCT-B2] evals/evals.json exists and is valid JSON"
if [ -f "$SKILL_DIR/evals/evals.json" ]; then
  if node -e "JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8'))" "$SKILL_DIR/evals/evals.json" 2>/dev/null; then
    pass "STRUCT-B2" "evals/evals.json is valid JSON"
  else
    fail "STRUCT-B2" "evals/evals.json is not valid JSON"
  fi
else
  fail "STRUCT-B2" "evals/evals.json not found"
fi

# STRUCT-C: Body under 500 lines (AC9)
echo "[STRUCT-C] Body under 500 lines"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  BODY_LINES=$(awk 'BEGIN{n=0} /^---$/{n++; next} n>=2{print}' "$SKILL_DIR/SKILL.md" | wc -l | tr -d ' ')
  if [ "$BODY_LINES" -lt 500 ]; then
    pass "STRUCT-C" "Body is $BODY_LINES lines (under 500)"
  else
    fail "STRUCT-C" "Body is $BODY_LINES lines (exceeds 500 limit)"
  fi
else
  fail "STRUCT-C" "Cannot check body lines -- SKILL.md not found"
fi

# STRUCT-D: Social Context section exists (AC5, >= 30 words)
echo "[STRUCT-D] Social Context section exists with >= 30 words"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if grep -q '^## Social Context' "$SKILL_DIR/SKILL.md"; then
    SC_WORDS=$(awk '/^## Social Context/{found=1; next} found && /^## /{exit} found{print}' "$SKILL_DIR/SKILL.md" | wc -w | tr -d ' ')
    if [ "$SC_WORDS" -ge 30 ]; then
      pass "STRUCT-D" "Social Context section found ($SC_WORDS words)"
    else
      fail "STRUCT-D" "Social Context section too short ($SC_WORDS words, need >= 30)"
    fi
  else
    fail "STRUCT-D" "## Social Context section missing from SKILL.md"
  fi
else
  fail "STRUCT-D" "Cannot check Social Context -- SKILL.md not found"
fi

# AC1-NAME: Skill name in frontmatter is "relay-groups" (AC1)
echo "[AC1-NAME] Skill name is relay-groups"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if sed -n '/^---$/,/^---$/p' "$SKILL_DIR/SKILL.md" | grep -q '^name: relay-groups'; then
    pass "AC1-NAME" "Skill name is relay-groups"
  else
    fail "AC1-NAME" "Skill name is not relay-groups"
  fi
else
  fail "AC1-NAME" "Cannot check name -- SKILL.md not found"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CONTENT TESTS -- NIP COVERAGE (P0)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "── Content Tests -- NIP Coverage (P0) ──"

# EVAL-A: SKILL.md body mentions NIP-29, relay-based groups, h tag, relay-as-authority (AC2)
echo "[EVAL-A] NIP coverage in SKILL.md"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  NIP_OK=true
  NIP_MISSING=""
  for TERM in "NIP-29" "relay" "group" "h tag|\"h\""; do
    if ! grep -qE "$TERM" "$SKILL_DIR/SKILL.md"; then
      NIP_OK=false
      NIP_MISSING="$NIP_MISSING $TERM"
    fi
  done
  if [ "$NIP_OK" = true ]; then
    pass "EVAL-A" "SKILL.md covers NIP-29, relay, group, h tag"
  else
    fail "EVAL-A" "SKILL.md missing coverage for:$NIP_MISSING"
  fi
else
  fail "EVAL-A" "Cannot check NIP coverage -- SKILL.md not found"
fi

# EVAL-B: references/nip-spec.md covers NIP-29 group management model (AC2)
echo "[EVAL-B] NIP spec reference file coverage"
if [ -f "$SKILL_DIR/references/nip-spec.md" ]; then
  SPEC_OK=true
  if ! grep -qi 'NIP-29\|relay.*group\|group.*relay' "$SKILL_DIR/references/nip-spec.md"; then
    fail "EVAL-B" "nip-spec.md missing NIP-29/relay group coverage"
    SPEC_OK=false
  fi
  if ! grep -qi 'kind:39000\|kind:9000\|kind:9\b' "$SKILL_DIR/references/nip-spec.md"; then
    fail "EVAL-B" "nip-spec.md missing event kind coverage"
    SPEC_OK=false
  fi
  if [ "$SPEC_OK" = true ]; then
    pass "EVAL-B" "nip-spec.md covers NIP-29 and event kinds"
  fi
else
  fail "EVAL-B" "nip-spec.md not found"
fi

# AC2-NIP29: SKILL.md mentions NIP-29 (AC2)
echo "[AC2-NIP29] SKILL.md covers NIP-29"
if [ -f "$SKILL_DIR/SKILL.md" ] && grep -q 'NIP-29' "$SKILL_DIR/SKILL.md"; then
  pass "AC2-NIP29" "NIP-29 mentioned in SKILL.md"
else
  fail "AC2-NIP29" "NIP-29 not found in SKILL.md"
fi

# AC2-RELAY-AUTH: SKILL.md covers relay-as-authority model (AC2)
echo "[AC2-RELAY-AUTH] SKILL.md covers relay-as-authority model"
if [ -f "$SKILL_DIR/SKILL.md" ] && grep -qi 'relay.*authority\|relay.*enforc\|relay.*manage\|relay.*validate' "$SKILL_DIR/SKILL.md"; then
  pass "AC2-RELAY-AUTH" "Relay-as-authority model covered in SKILL.md"
else
  fail "AC2-RELAY-AUTH" "Relay-as-authority model not found in SKILL.md"
fi

# AC2-KINDS-MSG: Skill covers group message kinds (kind:9, kind:11) (AC2)
echo "[AC2-KINDS-MSG] Skill covers group message kinds (kind:9, kind:11)"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  KIND9=false
  KIND11=false
  if grep -qi 'kind:9\b\|kind 9\b' "$SKILL_DIR/SKILL.md"; then KIND9=true; fi
  if grep -qi 'kind:11\|kind 11' "$SKILL_DIR/SKILL.md"; then KIND11=true; fi
  if [ "$KIND9" = true ] && [ "$KIND11" = true ]; then
    pass "AC2-KINDS-MSG" "Group message kinds (kind:9, kind:11) covered"
  else
    fail "AC2-KINDS-MSG" "Missing group message kinds (kind:9=$KIND9, kind:11=$KIND11)"
  fi
else
  fail "AC2-KINDS-MSG" "Cannot check -- SKILL.md not found"
fi

# AC2-KINDS-ADMIN: Skill covers admin action kinds (kind:9000-9009) (AC2)
echo "[AC2-KINDS-ADMIN] Skill covers admin action kinds (kind:9000-9009)"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  ADMIN_FOUND=0
  for KIND in "kind:9000" "kind:9001" "kind:9002" "kind:9005" "kind:9007" "kind:9009"; do
    if grep -q "$KIND" "$SKILL_DIR/SKILL.md"; then
      ADMIN_FOUND=$((ADMIN_FOUND + 1))
    fi
  done
  if [ "$ADMIN_FOUND" -ge 4 ]; then
    pass "AC2-KINDS-ADMIN" "Admin action kinds covered ($ADMIN_FOUND/6 checked)"
  else
    fail "AC2-KINDS-ADMIN" "Only $ADMIN_FOUND/6 admin action kinds found (need >= 4)"
  fi
else
  fail "AC2-KINDS-ADMIN" "Cannot check -- SKILL.md not found"
fi

# AC2-KINDS-META: Skill covers metadata kinds (kind:39000, 39001, 39002) (AC2)
echo "[AC2-KINDS-META] Skill covers metadata kinds (kind:39000, 39001, 39002)"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  META_FOUND=0
  for KIND in "kind:39000|39000" "kind:39001|39001" "kind:39002|39002"; do
    if grep -qE "$KIND" "$SKILL_DIR/SKILL.md"; then
      META_FOUND=$((META_FOUND + 1))
    fi
  done
  if [ "$META_FOUND" -ge 3 ]; then
    pass "AC2-KINDS-META" "All 3 metadata kinds covered"
  else
    fail "AC2-KINDS-META" "Only $META_FOUND/3 metadata kinds found"
  fi
else
  fail "AC2-KINDS-META" "Cannot check -- SKILL.md not found"
fi

# AC2-HTAG: SKILL.md covers h tag for group ID (AC2)
echo "[AC2-HTAG] SKILL.md covers h tag for group ID"
if [ -f "$SKILL_DIR/SKILL.md" ] && grep -qi 'h.*tag\|"h"\|h tag' "$SKILL_DIR/SKILL.md"; then
  pass "AC2-HTAG" "h tag covered in SKILL.md"
else
  fail "AC2-HTAG" "h tag not found in SKILL.md"
fi

# AC2-TOONEXT: toon-extensions.md exists and covers ILP/per-byte costs (AC2)
echo "[AC2-TOONEXT] toon-extensions.md covers ILP/per-byte costs"
if [ -f "$SKILL_DIR/references/toon-extensions.md" ]; then
  if grep -qi 'byte.*cost\|cost.*byte\|ILP.*gat\|per.*byte\|basePricePerByte' "$SKILL_DIR/references/toon-extensions.md"; then
    pass "AC2-TOONEXT" "toon-extensions.md covers ILP/per-byte costs"
  else
    fail "AC2-TOONEXT" "toon-extensions.md does not mention ILP/per-byte costs"
  fi
else
  fail "AC2-TOONEXT" "toon-extensions.md not found"
fi

# AC2-SCENARIOS: scenarios.md exists and covers step-by-step workflows (AC2)
echo "[AC2-SCENARIOS] scenarios.md covers step-by-step workflows"
if [ -f "$SKILL_DIR/references/scenarios.md" ]; then
  if grep -qi 'scenario\|step.*by.*step\|steps\|workflow' "$SKILL_DIR/references/scenarios.md"; then
    pass "AC2-SCENARIOS" "scenarios.md covers step-by-step workflows"
  else
    fail "AC2-SCENARIOS" "scenarios.md does not contain step-by-step workflows"
  fi
else
  fail "AC2-SCENARIOS" "scenarios.md not found"
fi

# AC2-PERMS: Skill covers NIP-29 permissions model (AC2)
echo "[AC2-PERMS] Skill covers NIP-29 permissions model"
if [ -f "$SKILL_DIR/SKILL.md" ] && grep -qi 'permission\|add-user\|edit-metadata\|delete-event' "$SKILL_DIR/SKILL.md"; then
  pass "AC2-PERMS" "Permissions model covered in SKILL.md"
else
  if [ -f "$SKILL_DIR/references/nip-spec.md" ] && grep -qi 'permission\|add-user\|edit-metadata' "$SKILL_DIR/references/nip-spec.md"; then
    pass "AC2-PERMS" "Permissions model covered in nip-spec.md"
  else
    fail "AC2-PERMS" "NIP-29 permissions model not found in skill files"
  fi
fi

# AC2-OPEN-CLOSED: Skill covers open vs closed group status (AC2)
echo "[AC2-OPEN-CLOSED] Skill covers open vs closed group status"
if grep -rqi 'open.*group\|closed.*group\|open.*closed\|invite.*only' "$SKILL_DIR"/*.md "$SKILL_DIR"/references/*.md 2>/dev/null; then
  pass "AC2-OPEN-CLOSED" "Open/closed group status covered"
else
  fail "AC2-OPEN-CLOSED" "Open/closed group status not found in skill files"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TOON WRITE MODEL TESTS (P0)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "── TOON Write Model Tests (P0) ──"

# TOON-A: publishEvent referenced across skill files (AC3, AC7)
echo "[TOON-A] publishEvent referenced"
if grep -rq 'publishEvent' "$SKILL_DIR"/*.md "$SKILL_DIR"/references/*.md 2>/dev/null; then
  pass "TOON-A" "publishEvent referenced across skill files"
else
  fail "TOON-A" "publishEvent not found in any skill file"
fi

# TOON-B: Fee/cost terms referenced across skill files (AC3, AC7)
echo "[TOON-B] Fee/cost terms referenced"
if grep -rqi 'basePricePerByte\|fee calculation\|fee awareness\|cost.*per.*byte\|byte.*cost' "$SKILL_DIR"/*.md "$SKILL_DIR"/references/*.md 2>/dev/null; then
  pass "TOON-B" "Fee/cost terms referenced across skill files"
else
  fail "TOON-B" "Fee/cost terms not found in any skill file"
fi

# AC3-CLIENT: References publishEvent() from @toon-protocol/client (AC3)
echo "[AC3-CLIENT] References publishEvent() from @toon-protocol/client"
if [ -f "$SKILL_DIR/SKILL.md" ] && grep -q 'publishEvent()' "$SKILL_DIR/SKILL.md" && grep -q '@toon-protocol/client' "$SKILL_DIR/SKILL.md"; then
  pass "AC3-CLIENT" "SKILL.md references publishEvent() from @toon-protocol/client"
else
  fail "AC3-CLIENT" "SKILL.md does not reference publishEvent() from @toon-protocol/client"
fi

# AC3-FEEREF: References fee calculation or cost per byte (AC3)
echo "[AC3-FEEREF] References fee calculation"
if [ -f "$SKILL_DIR/SKILL.md" ] && grep -qi 'fee\|cost.*byte\|byte.*cost\|basePricePerByte\|per-byte' "$SKILL_DIR/SKILL.md"; then
  pass "AC3-FEEREF" "SKILL.md references fee/cost"
else
  fail "AC3-FEEREF" "SKILL.md does not reference fee/cost"
fi

# AC3-HTAG-REQ: Explains h tag requirement for group messages (AC3)
echo "[AC3-HTAG-REQ] Explains h tag requirement for group messages"
if [ -f "$SKILL_DIR/SKILL.md" ] && grep -qi 'h.*tag.*group\|group.*h.*tag\|h.*tag.*required\|must.*h.*tag' "$SKILL_DIR/SKILL.md"; then
  pass "AC3-HTAG-REQ" "SKILL.md explains h tag requirement for group messages"
else
  fail "AC3-HTAG-REQ" "SKILL.md does not explain h tag requirement for group messages"
fi

# AC3-ADMIN-COST: Explains admin actions cost per-byte (AC3)
echo "[AC3-ADMIN-COST] Explains admin actions cost per-byte"
if grep -rqi 'admin.*cost\|admin.*per.*byte\|admin.*fee\|admin action.*cost\|moderation.*cost\|administering.*cost' "$SKILL_DIR"/*.md "$SKILL_DIR"/references/*.md 2>/dev/null; then
  pass "AC3-ADMIN-COST" "Admin action per-byte cost explained"
else
  fail "AC3-ADMIN-COST" "Admin action per-byte cost not explained"
fi

# AC3-ILP-GATE: Explains ILP-gated group entry possibility (AC3)
echo "[AC3-ILP-GATE] Explains ILP-gated group entry"
if grep -rqi 'ILP.*gat.*group\|group.*ILP.*gat\|payment.*channel.*group\|group.*payment' "$SKILL_DIR"/*.md "$SKILL_DIR"/references/*.md 2>/dev/null; then
  pass "AC3-ILP-GATE" "ILP-gated group entry explained"
else
  fail "AC3-ILP-GATE" "ILP-gated group entry not explained"
fi

# AC3-COREREF: Write model references nostr-protocol-core for fee formula (AC3)
echo "[AC3-COREREF] Write model references nostr-protocol-core for fee formula"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if grep -qi 'nostr-protocol-core\|toon-protocol-context' "$SKILL_DIR/SKILL.md"; then
    pass "AC3-COREREF" "SKILL.md references nostr-protocol-core for fee details"
  else
    fail "AC3-COREREF" "SKILL.md does not reference nostr-protocol-core for fee formula"
  fi
else
  fail "AC3-COREREF" "Cannot check -- SKILL.md not found"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TOON READ MODEL TESTS (P0)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "── TOON Read Model Tests (P0) ──"

# TOON-C: TOON-format referenced across skill files (AC4, AC7)
echo "[TOON-C] TOON-format referenced"
if grep -rqi 'TOON[- ]format\|toon-format\|TOON format' "$SKILL_DIR"/*.md "$SKILL_DIR"/references/*.md 2>/dev/null; then
  pass "TOON-C" "TOON-format referenced across skill files"
else
  fail "TOON-C" "TOON-format not found in any skill file"
fi

# AC4-FORMAT: References TOON-format strings for group subscriptions (AC4)
echo "[AC4-FORMAT] References TOON-format for group subscriptions"
if [ -f "$SKILL_DIR/SKILL.md" ] && grep -qi 'TOON[- ]format\|toon-format' "$SKILL_DIR/SKILL.md"; then
  pass "AC4-FORMAT" "SKILL.md references TOON-format"
else
  fail "AC4-FORMAT" "SKILL.md does not reference TOON-format"
fi

# AC4-HTAG-FILTER: Explains h tag filtering for group subscriptions (AC4)
echo "[AC4-HTAG-FILTER] Explains h tag filtering for group subscriptions"
if [ -f "$SKILL_DIR/SKILL.md" ] && grep -qi 'h.*tag.*filter\|filter.*h.*tag\|subscribe.*h.*tag\|h.*tag.*subscri' "$SKILL_DIR/SKILL.md"; then
  pass "AC4-HTAG-FILTER" "SKILL.md explains h tag filtering for subscriptions"
else
  fail "AC4-HTAG-FILTER" "SKILL.md does not explain h tag filtering for subscriptions"
fi

# AC4-REPLACEABLE: Explains replaceable event model for group metadata (AC4)
echo "[AC4-REPLACEABLE] Explains replaceable event model for group metadata"
if grep -rqi 'replaceabl.*event\|replaceable.*kind\|maintained.*relay\|relay.*maintain' "$SKILL_DIR"/*.md "$SKILL_DIR"/references/*.md 2>/dev/null; then
  pass "AC4-REPLACEABLE" "Replaceable event model for group metadata explained"
else
  fail "AC4-REPLACEABLE" "Replaceable event model not explained"
fi

# AC4-READREF: References nostr-protocol-core for TOON format details (AC4)
echo "[AC4-READREF] References nostr-protocol-core for TOON format"
if [ -f "$SKILL_DIR/SKILL.md" ] && grep -qi 'nostr-protocol-core.*toon-protocol-context\|toon-protocol-context' "$SKILL_DIR/SKILL.md"; then
  pass "AC4-READREF" "SKILL.md references nostr-protocol-core for TOON format"
else
  fail "AC4-READREF" "SKILL.md does not reference nostr-protocol-core for TOON format"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SOCIAL CONTEXT TESTS (P1)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "── Social Context Tests (P1) ──"

# TOON-D: Social Context section has group-specific content (AC5, >= 100 words)
echo "[TOON-D] Social Context has >= 100 words of group-specific content"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  SC_WORDS=$(awk '/^## Social Context/{found=1; next} found && /^## /{exit} found{print}' "$SKILL_DIR/SKILL.md" | wc -w | tr -d ' ')
  if [ "$SC_WORDS" -ge 100 ]; then
    pass "TOON-D" "Social Context has $SC_WORDS words (>= 100)"
  else
    fail "TOON-D" "Social Context has $SC_WORDS words (need >= 100)"
  fi
else
  fail "TOON-D" "Cannot check Social Context -- SKILL.md not found"
fi

# AC5-CULTURE: Social Context covers group culture / observe before participating (AC5)
echo "[AC5-CULTURE] Social Context covers group culture"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  SC_SECTION=$(awk '/^## Social Context/{found=1; next} found && /^## /{exit} found{print}' "$SKILL_DIR/SKILL.md")
  if echo "$SC_SECTION" | grep -qi 'culture\|norm\|observe\|before.*participat'; then
    pass "AC5-CULTURE" "Social Context covers group culture"
  else
    fail "AC5-CULTURE" "Social Context does not cover group culture"
  fi
else
  fail "AC5-CULTURE" "Cannot check -- SKILL.md not found"
fi

# AC5-ECON: Social Context covers economic dynamics of paid group participation (AC5)
echo "[AC5-ECON] Social Context covers economic dynamics"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  SC_SECTION=$(awk '/^## Social Context/{found=1; next} found && /^## /{exit} found{print}' "$SKILL_DIR/SKILL.md")
  if echo "$SC_SECTION" | grep -qi 'cost.*money\|every.*message.*cost\|quality.*filter\|economic\|spam.*disincentiv'; then
    pass "AC5-ECON" "Social Context covers economic dynamics"
  else
    fail "AC5-ECON" "Social Context does not cover economic dynamics"
  fi
else
  fail "AC5-ECON" "Cannot check -- SKILL.md not found"
fi

# AC5-ADMIN-WEIGHT: Social Context covers admin action weight / deliberate (AC5)
echo "[AC5-ADMIN-WEIGHT] Social Context covers admin action weight"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  SC_SECTION=$(awk '/^## Social Context/{found=1; next} found && /^## /{exit} found{print}' "$SKILL_DIR/SKILL.md")
  if echo "$SC_SECTION" | grep -qi 'admin.*weight\|admin.*cost\|admin.*deliberat\|removing.*user\|delet.*message.*deliberat'; then
    pass "AC5-ADMIN-WEIGHT" "Social Context covers admin action weight"
  else
    fail "AC5-ADMIN-WEIGHT" "Social Context does not cover admin action weight"
  fi
else
  fail "AC5-ADMIN-WEIGHT" "Cannot check -- SKILL.md not found"
fi

# AC5-REACTION-INTIMACY: Social Context covers reaction intimacy in groups (AC5)
echo "[AC5-REACTION-INTIMACY] Social Context covers reaction intimacy"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  SC_SECTION=$(awk '/^## Social Context/{found=1; next} found && /^## /{exit} found{print}' "$SKILL_DIR/SKILL.md")
  if echo "$SC_SECTION" | grep -qi 'reaction.*group\|reaction.*personal\|reaction.*intima\|smaller.*audience\|direct.*address'; then
    pass "AC5-REACTION-INTIMACY" "Social Context covers reaction intimacy"
  else
    fail "AC5-REACTION-INTIMACY" "Social Context does not cover reaction intimacy"
  fi
else
  fail "AC5-REACTION-INTIMACY" "Cannot check -- SKILL.md not found"
fi

# AC5-CLOSED-TRUST: Social Context covers closed group high-trust (AC5)
echo "[AC5-CLOSED-TRUST] Social Context covers closed group high-trust"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  SC_SECTION=$(awk '/^## Social Context/{found=1; next} found && /^## /{exit} found{print}' "$SKILL_DIR/SKILL.md")
  if echo "$SC_SECTION" | grep -qi 'closed.*group.*trust\|high.*trust\|skin.*game\|economic.*commitment\|social.*approval.*economic'; then
    pass "AC5-CLOSED-TRUST" "Social Context covers closed group high-trust"
  else
    fail "AC5-CLOSED-TRUST" "Social Context does not cover closed group high-trust"
  fi
else
  fail "AC5-CLOSED-TRUST" "Cannot check -- SKILL.md not found"
fi

# AC5-RELAY-NORMS: Social Context covers relay-specific norms (AC5)
echo "[AC5-RELAY-NORMS] Social Context covers relay-specific norms"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  SC_SECTION=$(awk '/^## Social Context/{found=1; next} found && /^## /{exit} found{print}' "$SKILL_DIR/SKILL.md")
  if echo "$SC_SECTION" | grep -qi 'relay.*norm\|relay.*rule\|relay.*authori\|different.*relay'; then
    pass "AC5-RELAY-NORMS" "Social Context covers relay-specific norms"
  else
    fail "AC5-RELAY-NORMS" "Social Context does not cover relay-specific norms"
  fi
else
  fail "AC5-RELAY-NORMS" "Cannot check -- SKILL.md not found"
fi

# AC5-SUBST: Social Context passes NIP-name substitution test (AC5)
echo "[AC5-SUBST] Social Context is group-specific (not generic)"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  SC_SECTION=$(awk '/^## Social Context/{found=1; next} found && /^## /{exit} found{print}' "$SKILL_DIR/SKILL.md")
  SUBST_OK=true
  FOUND_SPECIFIC=0
  for TERM in "group" "member" "admin" "relay" "closed" "message.*cost" "culture" "reaction"; do
    if echo "$SC_SECTION" | grep -qi "$TERM"; then
      FOUND_SPECIFIC=$((FOUND_SPECIFIC + 1))
    fi
  done
  if [ "$FOUND_SPECIFIC" -ge 5 ]; then
    pass "AC5-SUBST" "Social Context has $FOUND_SPECIFIC group-specific terms (passes substitution test)"
  else
    fail "AC5-SUBST" "Social Context has only $FOUND_SPECIFIC group-specific terms (need >= 5, fails substitution test)"
  fi
else
  fail "AC5-SUBST" "Cannot check -- SKILL.md not found"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# EVAL SUITE TESTS (P0)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "── Eval Suite Tests (P0) ──"

EVALS_FILE="$SKILL_DIR/evals/evals.json"

# EVAL-A2: Trigger eval count >= 8 should-trigger (AC6)
echo "[EVAL-A2] >= 8 should-trigger queries"
if [ -f "$EVALS_FILE" ]; then
  TRIGGER_TRUE=$(node -e "
    const d = JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8'));
    console.log((d.trigger_evals || []).filter(e => e.should_trigger === true).length);
  " "$EVALS_FILE" 2>/dev/null || echo "0")
  if [ "$TRIGGER_TRUE" -ge 8 ]; then
    pass "EVAL-A2" "$TRIGGER_TRUE should-trigger queries (>= 8)"
  else
    fail "EVAL-A2" "Only $TRIGGER_TRUE should-trigger queries (need >= 8)"
  fi
else
  fail "EVAL-A2" "evals/evals.json not found"
fi

# EVAL-B2: Trigger eval count >= 8 should-not-trigger (AC6)
echo "[EVAL-B2] >= 8 should-not-trigger queries"
if [ -f "$EVALS_FILE" ]; then
  TRIGGER_FALSE=$(node -e "
    const d = JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8'));
    console.log((d.trigger_evals || []).filter(e => e.should_trigger === false).length);
  " "$EVALS_FILE" 2>/dev/null || echo "0")
  if [ "$TRIGGER_FALSE" -ge 8 ]; then
    pass "EVAL-B2" "$TRIGGER_FALSE should-not-trigger queries (>= 8)"
  else
    fail "EVAL-B2" "Only $TRIGGER_FALSE should-not-trigger queries (need >= 8)"
  fi
else
  fail "EVAL-B2" "evals/evals.json not found"
fi

# EVAL-C: Output eval count >= 4 (AC6)
echo "[EVAL-C] >= 4 output evals"
if [ -f "$EVALS_FILE" ]; then
  OUTPUT_COUNT=$(node -e "
    const d = JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8'));
    console.log((d.output_evals || []).length);
  " "$EVALS_FILE" 2>/dev/null || echo "0")
  if [ "$OUTPUT_COUNT" -ge 4 ]; then
    pass "EVAL-C" "$OUTPUT_COUNT output evals (>= 4)"
  else
    fail "EVAL-C" "Only $OUTPUT_COUNT output evals (need >= 4)"
  fi
else
  fail "EVAL-C" "evals/evals.json not found"
fi

# AC6-RUBRIC: Output evals have rubric with correct/acceptable/incorrect (AC6)
echo "[AC6-RUBRIC] Output evals have rubric"
if [ -f "$EVALS_FILE" ]; then
  RUBRIC_COUNT=$(node -e "
    const d = JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8'));
    const oe = d.output_evals || [];
    const withRubric = oe.filter(e => e.rubric && e.rubric.correct && e.rubric.acceptable && e.rubric.incorrect);
    console.log(withRubric.length + ' ' + oe.length);
  " "$EVALS_FILE" 2>/dev/null || echo "0 0")
  RUBRIC_WITH=$(echo "$RUBRIC_COUNT" | awk '{print $1}')
  RUBRIC_TOTAL=$(echo "$RUBRIC_COUNT" | awk '{print $2}')
  if [ "$RUBRIC_WITH" -eq "$RUBRIC_TOTAL" ] && [ "$RUBRIC_TOTAL" -gt 0 ]; then
    pass "AC6-RUBRIC" "All $RUBRIC_TOTAL output evals have complete rubric"
  else
    fail "AC6-RUBRIC" "$RUBRIC_WITH/$RUBRIC_TOTAL output evals have complete rubric"
  fi
else
  fail "AC6-RUBRIC" "evals/evals.json not found"
fi

# AC6-TOON-ASSERT: Output eval assertions include TOON compliance assertions (AC6)
echo "[AC6-TOON-ASSERT] TOON compliance assertions in output evals"
if [ -f "$EVALS_FILE" ]; then
  TOON_ASSERT=$(node -e "
    const d = JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8'));
    const oe = d.output_evals || [];
    const hasToon = oe.filter(e => Array.isArray(e.assertions) && e.assertions.some(a => /toon-(write|fee|format)-check|social-context-check|trigger-coverage/.test(a)));
    console.log(hasToon.length + ' ' + oe.length);
  " "$EVALS_FILE" 2>/dev/null || echo "0 0")
  TOON_WITH=$(echo "$TOON_ASSERT" | awk '{print $1}')
  TOON_TOTAL=$(echo "$TOON_ASSERT" | awk '{print $2}')
  if [ "$TOON_WITH" -gt 0 ]; then
    pass "AC6-TOON-ASSERT" "$TOON_WITH/$TOON_TOTAL output evals have TOON compliance assertions"
  else
    fail "AC6-TOON-ASSERT" "No output evals have TOON compliance assertions"
  fi
else
  fail "AC6-TOON-ASSERT" "evals/evals.json not found"
fi

# AC6-TRIGGER-QUERIES: Should-trigger queries cover group-relevant terms (AC6)
echo "[AC6-TRIGGER-QUERIES] Trigger queries cover group-relevant terms"
if [ -f "$EVALS_FILE" ]; then
  TRIGGER_TERMS=$(node -e "
    const d = JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8'));
    const triggers = (d.trigger_evals || []).filter(e => e.should_trigger === true).map(e => e.query.toLowerCase());
    const allText = triggers.join(' ');
    let found = 0;
    for (const t of ['nip-29', 'group', 'h tag', 'admin', 'member', 'join', 'create', 'relay', 'invite']) {
      if (allText.includes(t.toLowerCase())) found++;
    }
    console.log(found);
  " "$EVALS_FILE" 2>/dev/null || echo "0")
  if [ "$TRIGGER_TERMS" -ge 5 ]; then
    pass "AC6-TRIGGER-QUERIES" "Should-trigger queries cover $TRIGGER_TERMS/9 group-relevant terms"
  else
    fail "AC6-TRIGGER-QUERIES" "Should-trigger queries cover only $TRIGGER_TERMS/9 group-relevant terms (need >= 5)"
  fi
else
  fail "AC6-TRIGGER-QUERIES" "evals/evals.json not found"
fi

# AC6-NOTTRIGGER-QUERIES: Should-not-trigger queries exclude unrelated skills (AC6)
echo "[AC6-NOTTRIGGER-QUERIES] Not-trigger queries exclude unrelated skills"
if [ -f "$EVALS_FILE" ]; then
  NOTTRIGGER_TERMS=$(node -e "
    const d = JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8'));
    const notTriggers = (d.trigger_evals || []).filter(e => e.should_trigger === false).map(e => e.query.toLowerCase());
    const allText = notTriggers.join(' ');
    let found = 0;
    for (const t of ['profile', 'article', 'reaction', 'encrypt', 'follow', 'file', 'search', 'community']) {
      if (allText.includes(t)) found++;
    }
    console.log(found);
  " "$EVALS_FILE" 2>/dev/null || echo "0")
  if [ "$NOTTRIGGER_TERMS" -ge 4 ]; then
    pass "AC6-NOTTRIGGER-QUERIES" "Not-trigger queries exclude $NOTTRIGGER_TERMS/8 unrelated topics"
  else
    fail "AC6-NOTTRIGGER-QUERIES" "Not-trigger queries exclude only $NOTTRIGGER_TERMS/8 unrelated topics (need >= 4)"
  fi
else
  fail "AC6-NOTTRIGGER-QUERIES" "evals/evals.json not found"
fi

# AC6-EXPECTED-OPT: Output evals include expected_output field (AC6)
echo "[AC6-EXPECTED-OPT] Output evals have expected_output"
if [ -f "$EVALS_FILE" ]; then
  EXPECTED_COUNT=$(node -e "
    const d = JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8'));
    const oe = d.output_evals || [];
    const withExpected = oe.filter(e => e.expected_output && e.expected_output.length > 0);
    console.log(withExpected.length + ' ' + oe.length);
  " "$EVALS_FILE" 2>/dev/null || echo "0 0")
  EXP_WITH=$(echo "$EXPECTED_COUNT" | awk '{print $1}')
  EXP_TOTAL=$(echo "$EXPECTED_COUNT" | awk '{print $2}')
  if [ "$EXP_WITH" -eq "$EXP_TOTAL" ] && [ "$EXP_TOTAL" -gt 0 ]; then
    pass "AC6-EXPECTED-OPT" "All $EXP_TOTAL output evals have expected_output field"
  else
    fail "AC6-EXPECTED-OPT" "expected_output field absent in $((EXP_TOTAL - EXP_WITH))/$EXP_TOTAL output evals (required per AC6)"
  fi
else
  fail "AC6-EXPECTED-OPT" "evals/evals.json not found"
fi

# AC6-OUTPUT-ID: All output evals have id and prompt fields (AC6)
echo "[AC6-OUTPUT-ID] Output evals have id and prompt fields"
if [ -f "$EVALS_FILE" ]; then
  ID_PROMPT_CHECK=$(node -e "
    const d = JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8'));
    const oe = d.output_evals || [];
    const valid = oe.filter(e => e.id && typeof e.id === 'string' && e.prompt && typeof e.prompt === 'string');
    console.log(valid.length + ' ' + oe.length);
  " "$EVALS_FILE" 2>/dev/null || echo "0 0")
  ID_WITH=$(echo "$ID_PROMPT_CHECK" | awk '{print $1}')
  ID_TOTAL=$(echo "$ID_PROMPT_CHECK" | awk '{print $2}')
  if [ "$ID_WITH" -eq "$ID_TOTAL" ] && [ "$ID_TOTAL" -gt 0 ]; then
    pass "AC6-OUTPUT-ID" "All $ID_TOTAL output evals have id and prompt fields"
  else
    fail "AC6-OUTPUT-ID" "$ID_WITH/$ID_TOTAL output evals have id and prompt fields"
  fi
else
  fail "AC6-OUTPUT-ID" "evals/evals.json not found"
fi

# AC6-OUTPUT-ASSERT: All output evals have assertions array (AC6)
echo "[AC6-OUTPUT-ASSERT] Output evals have assertions array"
if [ -f "$EVALS_FILE" ]; then
  ASSERT_CHECK=$(node -e "
    const d = JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8'));
    const oe = d.output_evals || [];
    const valid = oe.filter(e => Array.isArray(e.assertions) && e.assertions.length > 0);
    console.log(valid.length + ' ' + oe.length);
  " "$EVALS_FILE" 2>/dev/null || echo "0 0")
  ASSERT_WITH=$(echo "$ASSERT_CHECK" | awk '{print $1}')
  ASSERT_TOTAL=$(echo "$ASSERT_CHECK" | awk '{print $2}')
  if [ "$ASSERT_WITH" -eq "$ASSERT_TOTAL" ] && [ "$ASSERT_TOTAL" -gt 0 ]; then
    pass "AC6-OUTPUT-ASSERT" "All $ASSERT_TOTAL output evals have assertions array"
  else
    fail "AC6-OUTPUT-ASSERT" "$ASSERT_WITH/$ASSERT_TOTAL output evals have assertions array"
  fi
else
  fail "AC6-OUTPUT-ASSERT" "evals/evals.json not found"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TOON COMPLIANCE INTEGRATION TESTS (P0)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "── TOON Compliance Integration Tests (P0) ──"

# TOON-ALL-1: validate-skill.sh passes (AC7)
echo "[TOON-ALL-1] validate-skill.sh passes"
if [ -f "$VALIDATE_SCRIPT" ]; then
  if bash "$VALIDATE_SCRIPT" "$SKILL_DIR" > /dev/null 2>&1; then
    pass "TOON-ALL-1" "validate-skill.sh passes (11/11 structural checks)"
  else
    fail "TOON-ALL-1" "validate-skill.sh failed"
  fi
else
  fail "TOON-ALL-1" "validate-skill.sh not found at $VALIDATE_SCRIPT"
fi

# TOON-ALL-2: run-eval.sh passes (AC7)
echo "[TOON-ALL-2] run-eval.sh passes"
if [ -f "$RUNEVAL_SCRIPT" ]; then
  if bash "$RUNEVAL_SCRIPT" "$SKILL_DIR" > /dev/null 2>&1; then
    pass "TOON-ALL-2" "run-eval.sh passes (all TOON compliance assertions)"
  else
    fail "TOON-ALL-2" "run-eval.sh failed"
  fi
else
  fail "TOON-ALL-2" "run-eval.sh not found at $RUNEVAL_SCRIPT"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DESCRIPTION OPTIMIZATION TESTS (P1)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "── Description Optimization Tests (P1) ──"

# Extract description
DESCRIPTION=""
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  DESCRIPTION=$(awk '/^---$/{n++; next} n==1 && /^description:/{sub(/^description: */, ""); p=1; print; next} n==1 && p && /^[a-zA-Z][a-zA-Z0-9_-]*:/{p=0} n==1 && p{print} n>=2{exit}' "$SKILL_DIR/SKILL.md")
fi

# AC8-STRICT-RANGE: Description is 80-120 words (AC8)
echo "[AC8-STRICT-RANGE] Description is 80-120 words"
if [ -n "$DESCRIPTION" ]; then
  WORD_COUNT=$(echo "$DESCRIPTION" | wc -w | tr -d ' ')
  if [ "$WORD_COUNT" -ge 80 ] && [ "$WORD_COUNT" -le 120 ]; then
    pass "AC8-STRICT-RANGE" "Description is $WORD_COUNT words (80-120 range)"
  else
    fail "AC8-STRICT-RANGE" "Description is $WORD_COUNT words (expected 80-120)"
  fi
else
  fail "AC8-STRICT-RANGE" "Cannot extract description"
fi

# AC8-TRIGPHRASES: Description includes trigger phrases (AC8)
echo "[AC8-TRIGPHRASES] Description includes trigger phrases"
if [ -n "$DESCRIPTION" ]; then
  TRIG_FOUND=0
  for TERM in "NIP-29" "relay group" "group chat" "h tag" "kind:9" "kind:11" "group admin" "group member" "create group" "join group" "group message" "group invite" "group permission" "closed group" "open group"; do
    if echo "$DESCRIPTION" | grep -qi "$TERM"; then
      TRIG_FOUND=$((TRIG_FOUND + 1))
    fi
  done
  if [ "$TRIG_FOUND" -ge 8 ]; then
    pass "AC8-TRIGPHRASES" "Description includes $TRIG_FOUND/15 trigger phrases"
  else
    fail "AC8-TRIGPHRASES" "Description includes only $TRIG_FOUND/15 trigger phrases (need >= 8)"
  fi
else
  fail "AC8-TRIGPHRASES" "Cannot extract description"
fi

# AC8-SOCIAL-PHRASES: Description includes social-situation triggers (AC8)
echo "[AC8-SOCIAL-PHRASES] Description includes social-situation triggers"
if [ -n "$DESCRIPTION" ]; then
  if echo "$DESCRIPTION" | grep -qi 'how do I\|how to\|what is\|how should'; then
    pass "AC8-SOCIAL-PHRASES" "Description includes social-situation triggers"
  else
    fail "AC8-SOCIAL-PHRASES" "Description does not include social-situation triggers"
  fi
else
  fail "AC8-SOCIAL-PHRASES" "Cannot extract description"
fi

# AC8-GROUP-PHRASES: Description includes group-specific trigger phrases (AC8)
echo "[AC8-GROUP-PHRASES] Description includes group-specific trigger phrases"
if [ -n "$DESCRIPTION" ]; then
  GROUP_FOUND=0
  for TERM in "relay-based" "group participation" "membership" "moderation" "relay-enforced"; do
    if echo "$DESCRIPTION" | grep -qi "$TERM"; then
      GROUP_FOUND=$((GROUP_FOUND + 1))
    fi
  done
  if [ "$GROUP_FOUND" -ge 2 ]; then
    pass "AC8-GROUP-PHRASES" "Description includes $GROUP_FOUND/5 group-specific trigger phrases"
  else
    fail "AC8-GROUP-PHRASES" "Description includes only $GROUP_FOUND/5 group-specific phrases (need >= 2)"
  fi
else
  fail "AC8-GROUP-PHRASES" "Cannot extract description"
fi

# TRIG-A: Description has protocol-technical triggers (AC8)
echo "[TRIG-A] Protocol-technical triggers in description"
if [ -n "$DESCRIPTION" ]; then
  if echo "$DESCRIPTION" | grep -qi 'NIP-[0-9]\|kind:[0-9]\|relay.*group\|h tag'; then
    pass "TRIG-A" "Description has protocol-technical triggers"
  else
    fail "TRIG-A" "Description missing protocol-technical triggers"
  fi
else
  fail "TRIG-A" "Cannot extract description"
fi

# TRIG-B: Description has social/user-facing triggers (AC8)
echo "[TRIG-B] Social/user-facing triggers in description"
if [ -n "$DESCRIPTION" ]; then
  if echo "$DESCRIPTION" | grep -qi 'how do I\|how to\|join.*group\|post.*group\|manage.*member'; then
    pass "TRIG-B" "Description has social/user-facing triggers"
  else
    fail "TRIG-B" "Description missing social/user-facing triggers"
  fi
else
  fail "TRIG-B" "Cannot extract description"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TOKEN BUDGET TESTS (P1)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "── Token Budget Tests (P1) ──"

# AC9-TOKENS: Body is approximately 5k tokens or fewer (~3500 words max) (AC9)
echo "[AC9-TOKENS] Body is approximately 5k tokens or fewer"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  BODY_WORDS=$(awk 'BEGIN{n=0} /^---$/{n++; next} n>=2{print}' "$SKILL_DIR/SKILL.md" | wc -w | tr -d ' ')
  # ~5000 tokens ~ ~3500 words (1.4 tokens/word average)
  if [ "$BODY_WORDS" -le 3500 ]; then
    pass "AC9-TOKENS" "Body is $BODY_WORDS words (~$((BODY_WORDS * 14 / 10)) tokens, under ~5k)"
  else
    fail "AC9-TOKENS" "Body is $BODY_WORDS words (~$((BODY_WORDS * 14 / 10)) tokens, exceeds ~5k limit)"
  fi
else
  fail "AC9-TOKENS" "Cannot check token budget -- SKILL.md not found"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DEPENDENCY REFERENCE TESTS (P1)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "── Dependency Reference Tests (P1) ──"

# DEP-A: References nostr-protocol-core (AC10)
echo "[DEP-A] References nostr-protocol-core"
if [ -f "$SKILL_DIR/SKILL.md" ] && grep -qi 'nostr-protocol-core' "$SKILL_DIR/SKILL.md"; then
  pass "DEP-A" "SKILL.md references nostr-protocol-core"
else
  fail "DEP-A" "SKILL.md does not reference nostr-protocol-core"
fi

# DEP-B: References nostr-social-intelligence (AC10)
echo "[DEP-B] References nostr-social-intelligence"
if [ -f "$SKILL_DIR/SKILL.md" ] && grep -qi 'nostr-social-intelligence' "$SKILL_DIR/SKILL.md"; then
  pass "DEP-B" "SKILL.md references nostr-social-intelligence"
else
  fail "DEP-B" "SKILL.md does not reference nostr-social-intelligence"
fi

# DEP-C: References social-interactions (AC10)
echo "[DEP-C] References social-interactions"
if [ -f "$SKILL_DIR/SKILL.md" ] && grep -qi 'social-interactions' "$SKILL_DIR/SKILL.md"; then
  pass "DEP-C" "SKILL.md references social-interactions"
else
  fail "DEP-C" "SKILL.md does not reference social-interactions"
fi

# DEP-D: References content-references (AC10)
echo "[DEP-D] References content-references"
if [ -f "$SKILL_DIR/SKILL.md" ] && grep -qi 'content-references' "$SKILL_DIR/SKILL.md"; then
  pass "DEP-D" "SKILL.md references content-references"
else
  fail "DEP-D" "SKILL.md does not reference content-references"
fi

# AC10-NODUP: Skill does NOT contain toon-protocol-context.md in references/ (AC10)
echo "[AC10-NODUP] No duplicate toon-protocol-context.md in references/"
if [ -f "$SKILL_DIR/references/toon-protocol-context.md" ]; then
  fail "AC10-NODUP" "toon-protocol-context.md found in references/ (should not be duplicated)"
else
  pass "AC10-NODUP" "No duplicate toon-protocol-context.md in references/"
fi

# AC10-DEP-ALL: Skill references all four upstream skills (AC10)
echo "[AC10-DEP-ALL] References all four upstream skills"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  HAS_CORE=false
  HAS_SOCIAL=false
  HAS_INTERACTIONS=false
  HAS_CONTENT_REF=false
  if grep -qi 'nostr-protocol-core' "$SKILL_DIR/SKILL.md"; then HAS_CORE=true; fi
  if grep -qi 'nostr-social-intelligence' "$SKILL_DIR/SKILL.md"; then HAS_SOCIAL=true; fi
  if grep -qi 'social-interactions' "$SKILL_DIR/SKILL.md"; then HAS_INTERACTIONS=true; fi
  if grep -qi 'content-references' "$SKILL_DIR/SKILL.md"; then HAS_CONTENT_REF=true; fi
  if [ "$HAS_CORE" = true ] && [ "$HAS_SOCIAL" = true ] && [ "$HAS_INTERACTIONS" = true ] && [ "$HAS_CONTENT_REF" = true ]; then
    pass "AC10-DEP-ALL" "SKILL.md references all four upstream skills"
  else
    fail "AC10-DEP-ALL" "SKILL.md missing upstream references (core=$HAS_CORE, social=$HAS_SOCIAL, interactions=$HAS_INTERACTIONS, content-ref=$HAS_CONTENT_REF)"
  fi
else
  fail "AC10-DEP-ALL" "Cannot check -- SKILL.md not found"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CLEANLINESS TEST (P0)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "── Cleanliness Test (P0) ──"

# CLEAN-A: No extraneous .md files in skill root (P0)
echo "[CLEAN-A] No extraneous files in skill root"
if [ -d "$SKILL_DIR" ]; then
  EXTRA_MD=$(find "$SKILL_DIR" -maxdepth 1 -name '*.md' ! -name 'SKILL.md' 2>/dev/null || true)
  if [ -n "$EXTRA_MD" ]; then
    fail "CLEAN-A" "Extraneous .md files in skill root: $EXTRA_MD"
  else
    pass "CLEAN-A" "No extraneous .md files in skill root"
  fi
else
  fail "CLEAN-A" "Skill directory not found"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TOON COMPLIANCE NAMED ASSERTIONS (P0)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "── TOON Compliance Named Assertions (P0) ──"

# AC7-NAMED-ASSERTIONS: run-eval.sh output includes all 6 named TOON assertions (AC7)
echo "[AC7-NAMED-ASSERTIONS] run-eval.sh covers all 6 named TOON compliance assertions"
if [ -f "$RUNEVAL_SCRIPT" ]; then
  EVAL_OUTPUT=$(bash "$RUNEVAL_SCRIPT" "$SKILL_DIR" 2>&1 || true)
  ASSERT_FOUND=0
  for ASSERTION in "toon-write-check" "toon-fee-check" "toon-format-check" "social-context-check" "trigger-coverage" "eval-completeness"; do
    if echo "$EVAL_OUTPUT" | grep -qi "$ASSERTION"; then
      ASSERT_FOUND=$((ASSERT_FOUND + 1))
    fi
  done
  if [ "$ASSERT_FOUND" -ge 5 ]; then
    pass "AC7-NAMED-ASSERTIONS" "run-eval.sh checks $ASSERT_FOUND/6 named TOON assertions"
  else
    fail "AC7-NAMED-ASSERTIONS" "run-eval.sh checks only $ASSERT_FOUND/6 named TOON assertions"
  fi
else
  fail "AC7-NAMED-ASSERTIONS" "run-eval.sh not found at $RUNEVAL_SCRIPT"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# AC11: WITH/WITHOUT BASELINE (P2 -- manual pipeline verification)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "── AC11: With/Without Baseline (P2) ──"

# BASE-A: With/without testing requires manual pipeline Step 8 (AC11)
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
