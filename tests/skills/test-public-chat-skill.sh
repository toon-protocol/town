#!/usr/bin/env bash
# test-public-chat-skill.sh -- ATDD acceptance tests for Story 9.10: Public Chat Skill
# TDD RED PHASE: All tests will FAIL until the skill is implemented.
#
# Usage: ./tests/skills/test-public-chat-skill.sh
# Exit 0 = all checks pass, 1 = at least one check failed
#
# Test IDs map to AC-to-Test Mapping in atdd-checklist-9-10.md:
#   STRUCT-A, STRUCT-B, STRUCT-B2, STRUCT-C, STRUCT-D
#   TOON-A, TOON-B, TOON-C, TOON-D, TOON-ALL-1, TOON-ALL-2
#   EVAL-A, EVAL-B, EVAL-A2, EVAL-B2, EVAL-C
#   TRIG-A, TRIG-B
#   DEP-A, DEP-B, DEP-C, DEP-D, DEP-E, DEP-F
#   CLEAN-A
#   AC1-NAME
#   AC2-NIP28, AC2-CHANNEL-CREATE, AC2-KINDS-40, AC2-KINDS-41, AC2-KINDS-42
#   AC2-KINDS-43, AC2-KINDS-44, AC2-ETAG, AC2-JSON-CONTENT, AC2-TOONEXT, AC2-SCENARIOS
#   AC2-CHANNEL-DISCOVER, AC2-REPLY-THREADING
#   AC3-CLIENT, AC3-FEEREF, AC3-MSG-COST, AC3-CHANNEL-COST, AC3-MODERATION-COST
#   AC3-CONCISENESS, AC3-COREREF
#   AC4-FORMAT, AC4-CHANNEL-SUBSCRIBE, AC4-MSG-SUBSCRIBE, AC4-METADATA-VALIDATE, AC4-READREF
#   AC5-CONCISENESS, AC5-REALTIME, AC5-CHANNEL-PURPOSE, AC5-MODERATION-TOOLS
#   AC5-DISTINGUISH-GROUPS, AC5-DISTINGUISH-COMMUNITIES, AC5-SUBST
#   AC6-RUBRIC, AC6-TOON-ASSERT, AC6-TRIGGER-QUERIES, AC6-NOTTRIGGER-QUERIES
#   AC6-EXPECTED-OPT, AC6-OUTPUT-ID, AC6-OUTPUT-ASSERT, AC6-OUTPUT-RANGE
#   AC8-TRIGPHRASES, AC8-STRICT-RANGE, AC8-SOCIAL-PHRASES, AC8-CHAT-PHRASES
#   AC9-TOKENS
#   AC10-NODUP, AC10-DEP-ALL
#   AC7-NAMED-ASSERTIONS, AC7-EVAL-ASSERTIONS
#   BASE-A (skipped -- requires manual pipeline Step 8)
#
# Gap-fill tests (NIP-28-specific detail coverage):
#   AC2-ROOT-MARKER, AC2-REPLY-MARKER, AC2-PTAG-REPLY, AC2-HIDE-REASON
#   AC2-MUTE-REASON, AC2-METADATA-AUTHOR-CHECK
#   AC3-SPAM-RESISTANCE
#   AC4-METADATA-OVERRIDE
#
# Total: 84 tests (83 automated + 1 skipped)

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILL_DIR="$PROJECT_ROOT/.claude/skills/public-chat"
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

echo "=== ATDD Acceptance Tests: Story 9.10 Public Chat Skill ==="
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

# AC1-NAME: Skill name in frontmatter is "public-chat" (AC1)
echo "[AC1-NAME] Skill name is public-chat"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if sed -n '/^---$/,/^---$/p' "$SKILL_DIR/SKILL.md" | grep -q '^name: public-chat'; then
    pass "AC1-NAME" "Skill name is public-chat"
  else
    fail "AC1-NAME" "Skill name is not public-chat"
  fi
else
  fail "AC1-NAME" "Cannot check name -- SKILL.md not found"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CONTENT TESTS -- NIP COVERAGE (P0)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "── Content Tests -- NIP Coverage (P0) ──"

# EVAL-A: SKILL.md body mentions NIP-28, public chat, channel, e tag (AC2)
echo "[EVAL-A] NIP coverage in SKILL.md"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  NIP_OK=true
  NIP_MISSING=""
  for TERM in "NIP-28" "channel" "chat" 'e tag|"e"'; do
    if ! grep -qE "$TERM" "$SKILL_DIR/SKILL.md"; then
      NIP_OK=false
      NIP_MISSING="$NIP_MISSING $TERM"
    fi
  done
  if [ "$NIP_OK" = true ]; then
    pass "EVAL-A" "SKILL.md covers NIP-28, channel, chat, e tag"
  else
    fail "EVAL-A" "SKILL.md missing coverage for:$NIP_MISSING"
  fi
else
  fail "EVAL-A" "Cannot check NIP coverage -- SKILL.md not found"
fi

# EVAL-B: references/nip-spec.md covers NIP-28 public chat model (AC2)
echo "[EVAL-B] NIP spec reference file coverage"
if [ -f "$SKILL_DIR/references/nip-spec.md" ]; then
  SPEC_OK=true
  if ! grep -qi 'NIP-28\|public.*chat' "$SKILL_DIR/references/nip-spec.md"; then
    fail "EVAL-B" "nip-spec.md missing NIP-28/public chat coverage"
    SPEC_OK=false
  fi
  if ! grep -qi 'kind:40\|kind:41\|kind:42\|kind:43\|kind:44' "$SKILL_DIR/references/nip-spec.md"; then
    fail "EVAL-B" "nip-spec.md missing event kind coverage"
    SPEC_OK=false
  fi
  if [ "$SPEC_OK" = true ]; then
    pass "EVAL-B" "nip-spec.md covers NIP-28 and event kinds"
  fi
else
  fail "EVAL-B" "nip-spec.md not found"
fi

# AC2-NIP28: SKILL.md mentions NIP-28 (AC2)
echo "[AC2-NIP28] SKILL.md covers NIP-28"
if [ -f "$SKILL_DIR/SKILL.md" ] && grep -q 'NIP-28' "$SKILL_DIR/SKILL.md"; then
  pass "AC2-NIP28" "NIP-28 mentioned in SKILL.md"
else
  fail "AC2-NIP28" "NIP-28 not found in SKILL.md"
fi

# AC2-CHANNEL-CREATE: SKILL.md covers channel creation (AC2)
echo "[AC2-CHANNEL-CREATE] SKILL.md covers channel creation"
if [ -f "$SKILL_DIR/SKILL.md" ] && grep -qi 'channel.*creat\|creat.*channel\|kind:40' "$SKILL_DIR/SKILL.md"; then
  pass "AC2-CHANNEL-CREATE" "Channel creation covered in SKILL.md"
else
  fail "AC2-CHANNEL-CREATE" "Channel creation not found in SKILL.md"
fi

# AC2-KINDS-40: Skill covers channel creation kind (kind:40) (AC2)
echo "[AC2-KINDS-40] Skill covers channel creation kind (kind:40)"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if grep -qi 'kind:40\|kind 40' "$SKILL_DIR/SKILL.md"; then
    pass "AC2-KINDS-40" "Channel creation kind (kind:40) covered"
  else
    fail "AC2-KINDS-40" "Channel creation kind (kind:40) not found"
  fi
else
  fail "AC2-KINDS-40" "Cannot check -- SKILL.md not found"
fi

# AC2-KINDS-41: Skill covers channel metadata kind (kind:41) (AC2)
echo "[AC2-KINDS-41] Skill covers channel metadata kind (kind:41)"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if grep -qi 'kind:41\|kind 41' "$SKILL_DIR/SKILL.md"; then
    pass "AC2-KINDS-41" "Channel metadata kind (kind:41) covered"
  else
    fail "AC2-KINDS-41" "Channel metadata kind (kind:41) not found"
  fi
else
  fail "AC2-KINDS-41" "Cannot check -- SKILL.md not found"
fi

# AC2-KINDS-42: Skill covers channel message kind (kind:42) (AC2)
echo "[AC2-KINDS-42] Skill covers channel message kind (kind:42)"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if grep -qi 'kind:42\|kind 42' "$SKILL_DIR/SKILL.md"; then
    pass "AC2-KINDS-42" "Channel message kind (kind:42) covered"
  else
    fail "AC2-KINDS-42" "Channel message kind (kind:42) not found"
  fi
else
  fail "AC2-KINDS-42" "Cannot check -- SKILL.md not found"
fi

# AC2-KINDS-43: Skill covers hide message kind (kind:43) (AC2)
echo "[AC2-KINDS-43] Skill covers hide message kind (kind:43)"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if grep -qi 'kind:43\|kind 43' "$SKILL_DIR/SKILL.md"; then
    pass "AC2-KINDS-43" "Hide message kind (kind:43) covered"
  else
    fail "AC2-KINDS-43" "Hide message kind (kind:43) not found"
  fi
else
  fail "AC2-KINDS-43" "Cannot check -- SKILL.md not found"
fi

# AC2-KINDS-44: Skill covers mute user kind (kind:44) (AC2)
echo "[AC2-KINDS-44] Skill covers mute user kind (kind:44)"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if grep -qi 'kind:44\|kind 44' "$SKILL_DIR/SKILL.md"; then
    pass "AC2-KINDS-44" "Mute user kind (kind:44) covered"
  else
    fail "AC2-KINDS-44" "Mute user kind (kind:44) not found"
  fi
else
  fail "AC2-KINDS-44" "Cannot check -- SKILL.md not found"
fi

# AC2-ETAG: SKILL.md covers e tag for channel reference (AC2)
echo "[AC2-ETAG] SKILL.md covers e tag for channel reference"
if [ -f "$SKILL_DIR/SKILL.md" ] && grep -qi 'e.*tag\|"e"\|e tag' "$SKILL_DIR/SKILL.md"; then
  pass "AC2-ETAG" "e tag covered in SKILL.md"
else
  fail "AC2-ETAG" "e tag not found in SKILL.md"
fi

# AC2-JSON-CONTENT: Skill covers JSON content in channel creation events (AC2)
echo "[AC2-JSON-CONTENT] Skill covers JSON content in channel creation"
if grep -rqi 'JSON.*content\|content.*JSON\|name.*about.*picture\|channel.*metadata.*JSON' "$SKILL_DIR"/*.md "$SKILL_DIR"/references/*.md 2>/dev/null; then
  pass "AC2-JSON-CONTENT" "JSON content in channel creation covered"
else
  fail "AC2-JSON-CONTENT" "JSON content in channel creation not found"
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

# AC2-CHANNEL-DISCOVER: Skill covers channel discovery via kind:40 subscriptions (AC2)
echo "[AC2-CHANNEL-DISCOVER] Skill covers channel discovery via kind:40"
if grep -rqi 'discover.*channel\|channel.*discover\|subscribe.*kind:40\|kind:40.*discover\|kind:40.*subscri' "$SKILL_DIR"/*.md "$SKILL_DIR"/references/*.md 2>/dev/null; then
  pass "AC2-CHANNEL-DISCOVER" "Channel discovery via kind:40 covered"
else
  fail "AC2-CHANNEL-DISCOVER" "Channel discovery via kind:40 not found"
fi

# AC2-REPLY-THREADING: Skill covers reply threading in channel messages (AC2)
echo "[AC2-REPLY-THREADING] Skill covers reply threading in channel messages"
if grep -rqi 'reply.*thread\|thread.*reply\|reply.*marker\|optional.*e.*tag.*reply\|reply.*e.*tag' "$SKILL_DIR"/*.md "$SKILL_DIR"/references/*.md 2>/dev/null; then
  pass "AC2-REPLY-THREADING" "Reply threading in channel messages covered"
else
  fail "AC2-REPLY-THREADING" "Reply threading in channel messages not found"
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

# AC3-MSG-COST: Explains channel messages (kind:42) cost per-byte (AC3)
echo "[AC3-MSG-COST] Explains channel messages cost per-byte"
if grep -rqi 'message.*cost\|message.*per.*byte\|kind:42.*cost\|chat.*cost\|every.*message.*cost\|message.*money' "$SKILL_DIR"/*.md "$SKILL_DIR"/references/*.md 2>/dev/null; then
  pass "AC3-MSG-COST" "Channel message per-byte cost explained"
else
  fail "AC3-MSG-COST" "Channel message per-byte cost not explained"
fi

# AC3-CHANNEL-COST: Explains channel creation (kind:40) costs per-byte (AC3)
echo "[AC3-CHANNEL-COST] Explains channel creation cost per-byte"
if grep -rqi 'channel.*creat.*cost\|creat.*channel.*cost\|kind:40.*cost\|channel.*per.*byte\|creat.*cost.*per.*byte' "$SKILL_DIR"/*.md "$SKILL_DIR"/references/*.md 2>/dev/null; then
  pass "AC3-CHANNEL-COST" "Channel creation per-byte cost explained"
else
  # Broader check: channel creation mentioned near cost language
  if grep -rqi 'kind:40' "$SKILL_DIR"/*.md "$SKILL_DIR"/references/*.md 2>/dev/null && \
     grep -rqi 'cost.*per.*byte\|per-byte' "$SKILL_DIR"/references/toon-extensions.md 2>/dev/null; then
    pass "AC3-CHANNEL-COST" "Channel creation cost covered (kind:40 + per-byte in toon-extensions)"
  else
    fail "AC3-CHANNEL-COST" "Channel creation per-byte cost not explained"
  fi
fi

# AC3-MODERATION-COST: Explains hide/mute events cost per-byte (AC3)
echo "[AC3-MODERATION-COST] Explains hide/mute moderation cost per-byte"
if grep -rqi 'hide.*cost\|mute.*cost\|moderation.*cost\|kind:43.*cost\|kind:44.*cost\|moderat.*per.*byte\|hide.*per.*byte\|mute.*per.*byte' "$SKILL_DIR"/*.md "$SKILL_DIR"/references/*.md 2>/dev/null; then
  pass "AC3-MODERATION-COST" "Hide/mute moderation per-byte cost explained"
else
  fail "AC3-MODERATION-COST" "Hide/mute moderation per-byte cost not explained"
fi

# AC3-CONCISENESS: Explains conciseness incentive from per-byte pricing (AC3)
echo "[AC3-CONCISENESS] Explains conciseness incentive"
if grep -rqi 'conciseness.*incentive\|concise.*incent\|say more.*fewer\|economic.*concis\|cost.*concis\|natural.*concis' "$SKILL_DIR"/*.md "$SKILL_DIR"/references/*.md 2>/dev/null; then
  pass "AC3-CONCISENESS" "Conciseness incentive from per-byte pricing explained"
else
  fail "AC3-CONCISENESS" "Conciseness incentive not explained"
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

# AC4-FORMAT: References TOON-format strings for channel/message reading (AC4)
echo "[AC4-FORMAT] References TOON-format for channel/message reading"
if [ -f "$SKILL_DIR/SKILL.md" ] && grep -qi 'TOON[- ]format\|toon-format' "$SKILL_DIR/SKILL.md"; then
  pass "AC4-FORMAT" "SKILL.md references TOON-format"
else
  fail "AC4-FORMAT" "SKILL.md does not reference TOON-format"
fi

# AC4-CHANNEL-SUBSCRIBE: Explains subscribing to channel creation events (kind:40) (AC4)
echo "[AC4-CHANNEL-SUBSCRIBE] Explains subscribing to kind:40 for channel discovery"
if [ -f "$SKILL_DIR/SKILL.md" ] && grep -qi 'subscribe.*kind:40\|kind:40.*subscribe\|channel.*discover\|discover.*channel' "$SKILL_DIR/SKILL.md"; then
  pass "AC4-CHANNEL-SUBSCRIBE" "SKILL.md explains channel discovery via kind:40 subscription"
else
  fail "AC4-CHANNEL-SUBSCRIBE" "SKILL.md does not explain channel discovery via kind:40 subscription"
fi

# AC4-MSG-SUBSCRIBE: Explains subscribing to channel messages via #e tag filter (AC4)
echo "[AC4-MSG-SUBSCRIBE] Explains subscribing to messages via #e tag filter"
if grep -rqi '#e.*tag.*filter\|e.*tag.*filter.*message\|subscribe.*message.*e.*tag\|#e.*filter\|filter.*channel.*event' "$SKILL_DIR"/*.md "$SKILL_DIR"/references/*.md 2>/dev/null; then
  pass "AC4-MSG-SUBSCRIBE" "Subscribing to messages via #e tag filter explained"
else
  fail "AC4-MSG-SUBSCRIBE" "Subscribing to messages via #e tag filter not explained"
fi

# AC4-METADATA-VALIDATE: Explains validating kind:41 metadata updates against channel creator (AC4)
echo "[AC4-METADATA-VALIDATE] Explains validating kind:41 against channel creator"
if grep -rqi 'kind:41.*author.*kind:40\|metadata.*creator\|metadata.*valid.*creator\|author.*match\|channel.*creator.*metadata\|only.*valid.*creator' "$SKILL_DIR"/*.md "$SKILL_DIR"/references/*.md 2>/dev/null; then
  pass "AC4-METADATA-VALIDATE" "Metadata update validation against channel creator explained"
else
  fail "AC4-METADATA-VALIDATE" "Metadata update validation against channel creator not explained"
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

# TOON-D: Social Context section has chat-specific content (AC5, >= 100 words)
echo "[TOON-D] Social Context has >= 100 words of chat-specific content"
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

# AC5-CONCISENESS: Social Context covers conciseness incentive from per-byte pricing (AC5)
echo "[AC5-CONCISENESS] Social Context covers conciseness incentive"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  SC_SECTION=$(awk '/^## Social Context/{found=1; next} found && /^## /{exit} found{print}' "$SKILL_DIR/SKILL.md")
  if echo "$SC_SECTION" | grep -qi 'concis\|say more.*fewer\|verbose.*waste\|fewer words\|economic.*friction.*concis\|cost.*encourage.*concis'; then
    pass "AC5-CONCISENESS" "Social Context covers conciseness incentive"
  else
    fail "AC5-CONCISENESS" "Social Context does not cover conciseness incentive"
  fi
else
  fail "AC5-CONCISENESS" "Cannot check -- SKILL.md not found"
fi

# AC5-REALTIME: Social Context covers real-time conversational norms (AC5)
echo "[AC5-REALTIME] Social Context covers real-time conversational norms"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  SC_SECTION=$(awk '/^## Social Context/{found=1; next} found && /^## /{exit} found{print}' "$SKILL_DIR/SKILL.md")
  if echo "$SC_SECTION" | grep -qi 'real.*time\|conversational\|on.*topic\|rapid.*fire\|flooding\|concise.*on.*topic'; then
    pass "AC5-REALTIME" "Social Context covers real-time conversational norms"
  else
    fail "AC5-REALTIME" "Social Context does not cover real-time conversational norms"
  fi
else
  fail "AC5-REALTIME" "Cannot check -- SKILL.md not found"
fi

# AC5-CHANNEL-PURPOSE: Social Context covers reading channel description before participating (AC5)
echo "[AC5-CHANNEL-PURPOSE] Social Context covers channel purpose/description"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  SC_SECTION=$(awk '/^## Social Context/{found=1; next} found && /^## /{exit} found{print}' "$SKILL_DIR/SKILL.md")
  if echo "$SC_SECTION" | grep -qi 'description.*before\|about.*field\|channel.*purpose\|read.*channel\|channel.*norms\|stated.*purpose'; then
    pass "AC5-CHANNEL-PURPOSE" "Social Context covers channel purpose/description"
  else
    fail "AC5-CHANNEL-PURPOSE" "Social Context does not cover channel purpose/description"
  fi
else
  fail "AC5-CHANNEL-PURPOSE" "Cannot check -- SKILL.md not found"
fi

# AC5-MODERATION-TOOLS: Social Context covers hide/mute as personal moderation tools (AC5)
echo "[AC5-MODERATION-TOOLS] Social Context covers hide/mute as personal moderation"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  SC_SECTION=$(awk '/^## Social Context/{found=1; next} found && /^## /{exit} found{print}' "$SKILL_DIR/SKILL.md")
  if echo "$SC_SECTION" | grep -qi 'personal.*moderat\|hide.*mute\|not.*global.*censor\|user.*specific\|judicious\|personal.*tool\|disruptive.*content'; then
    pass "AC5-MODERATION-TOOLS" "Social Context covers hide/mute as personal moderation tools"
  else
    fail "AC5-MODERATION-TOOLS" "Social Context does not cover hide/mute as personal moderation tools"
  fi
else
  fail "AC5-MODERATION-TOOLS" "Cannot check -- SKILL.md not found"
fi

# AC5-DISTINGUISH-GROUPS: Social Context distinguishes public chat from relay groups (NIP-29) (AC5)
echo "[AC5-DISTINGUISH-GROUPS] Social Context distinguishes from NIP-29 relay groups"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  SC_SECTION=$(awk '/^## Social Context/{found=1; next} found && /^## /{exit} found{print}' "$SKILL_DIR/SKILL.md")
  if echo "$SC_SECTION" | grep -qi 'NIP-29\|relay.*group\|relay.*enforc\|membership.*enforc\|distinguish\|different.*model'; then
    pass "AC5-DISTINGUISH-GROUPS" "Social Context distinguishes from NIP-29 relay groups"
  else
    fail "AC5-DISTINGUISH-GROUPS" "Social Context does not distinguish from NIP-29 relay groups"
  fi
else
  fail "AC5-DISTINGUISH-GROUPS" "Cannot check -- SKILL.md not found"
fi

# AC5-DISTINGUISH-COMMUNITIES: Social Context distinguishes public chat from moderated communities (NIP-72) (AC5)
echo "[AC5-DISTINGUISH-COMMUNITIES] Social Context distinguishes from NIP-72 communities"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  SC_SECTION=$(awk '/^## Social Context/{found=1; next} found && /^## /{exit} found{print}' "$SKILL_DIR/SKILL.md")
  if echo "$SC_SECTION" | grep -qi 'NIP-72\|moderated.*communit\|approval.*based\|communit.*curated'; then
    pass "AC5-DISTINGUISH-COMMUNITIES" "Social Context distinguishes from NIP-72 communities"
  else
    fail "AC5-DISTINGUISH-COMMUNITIES" "Social Context does not distinguish from NIP-72 communities"
  fi
else
  fail "AC5-DISTINGUISH-COMMUNITIES" "Cannot check -- SKILL.md not found"
fi

# AC5-SUBST: Social Context passes NIP-name substitution test (AC5)
echo "[AC5-SUBST] Social Context is chat-specific (not generic)"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  SC_SECTION=$(awk '/^## Social Context/{found=1; next} found && /^## /{exit} found{print}' "$SKILL_DIR/SKILL.md")
  FOUND_SPECIFIC=0
  for TERM in "chat" "channel" "concis" "real.*time" "message" "hide\|mute" "NIP-29\|relay.*group" "NIP-72\|communit"; do
    if echo "$SC_SECTION" | grep -qi "$TERM"; then
      FOUND_SPECIFIC=$((FOUND_SPECIFIC + 1))
    fi
  done
  if [ "$FOUND_SPECIFIC" -ge 5 ]; then
    pass "AC5-SUBST" "Social Context has $FOUND_SPECIFIC chat-specific terms (passes substitution test)"
  else
    fail "AC5-SUBST" "Social Context has only $FOUND_SPECIFIC chat-specific terms (need >= 5, fails substitution test)"
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

# AC6-TRIGGER-QUERIES: Should-trigger queries cover chat-relevant terms (AC6)
echo "[AC6-TRIGGER-QUERIES] Trigger queries cover chat-relevant terms"
if [ -f "$EVALS_FILE" ]; then
  TRIGGER_TERMS=$(node -e "
    const d = JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8'));
    const triggers = (d.trigger_evals || []).filter(e => e.should_trigger === true).map(e => e.query.toLowerCase());
    const allText = triggers.join(' ');
    let found = 0;
    for (const t of ['nip-28', 'chat', 'channel', 'kind:40', 'kind:42', 'message', 'hide', 'mute', 'create']) {
      if (allText.includes(t.toLowerCase())) found++;
    }
    console.log(found);
  " "$EVALS_FILE" 2>/dev/null || echo "0")
  if [ "$TRIGGER_TERMS" -ge 5 ]; then
    pass "AC6-TRIGGER-QUERIES" "Should-trigger queries cover $TRIGGER_TERMS/9 chat-relevant terms"
  else
    fail "AC6-TRIGGER-QUERIES" "Should-trigger queries cover only $TRIGGER_TERMS/9 chat-relevant terms (need >= 5)"
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
    for (const t of ['profile', 'group', 'community', 'article', 'encrypt', 'follow', 'file', 'search']) {
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

# AC6-OUTPUT-RANGE: Output eval count is 4-6 (AC6)
echo "[AC6-OUTPUT-RANGE] Output eval count is 4-6"
if [ -f "$EVALS_FILE" ]; then
  OUTPUT_RANGE=$(node -e "
    const d = JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8'));
    console.log((d.output_evals || []).length);
  " "$EVALS_FILE" 2>/dev/null || echo "0")
  if [ "$OUTPUT_RANGE" -ge 4 ] && [ "$OUTPUT_RANGE" -le 6 ]; then
    pass "AC6-OUTPUT-RANGE" "$OUTPUT_RANGE output evals (within 4-6 range)"
  else
    fail "AC6-OUTPUT-RANGE" "$OUTPUT_RANGE output evals (expected 4-6)"
  fi
else
  fail "AC6-OUTPUT-RANGE" "evals/evals.json not found"
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
  for TERM in "NIP-28" "public chat" "channel creation" "kind:40" "channel metadata" "kind:41" "channel message" "kind:42" "hide message" "kind:43" "mute user" "kind:44" "chat channel" "real-time chat" "send message" "create channel" "channel moderation"; do
    if echo "$DESCRIPTION" | grep -qi "$TERM"; then
      TRIG_FOUND=$((TRIG_FOUND + 1))
    fi
  done
  if [ "$TRIG_FOUND" -ge 8 ]; then
    pass "AC8-TRIGPHRASES" "Description includes $TRIG_FOUND/17 trigger phrases"
  else
    fail "AC8-TRIGPHRASES" "Description includes only $TRIG_FOUND/17 trigger phrases (need >= 8)"
  fi
else
  fail "AC8-TRIGPHRASES" "Cannot extract description"
fi

# AC8-SOCIAL-PHRASES: Description includes social-situation triggers (AC8)
echo "[AC8-SOCIAL-PHRASES] Description includes social-situation triggers"
if [ -n "$DESCRIPTION" ]; then
  if echo "$DESCRIPTION" | grep -qi 'how do I\|how to\|how does\|how should\|what is'; then
    pass "AC8-SOCIAL-PHRASES" "Description includes social-situation triggers"
  else
    fail "AC8-SOCIAL-PHRASES" "Description does not include social-situation triggers"
  fi
else
  fail "AC8-SOCIAL-PHRASES" "Cannot extract description"
fi

# AC8-CHAT-PHRASES: Description includes chat-specific trigger phrases (AC8)
echo "[AC8-CHAT-PHRASES] Description includes chat-specific trigger phrases"
if [ -n "$DESCRIPTION" ]; then
  CHAT_FOUND=0
  for TERM in "chat channel" "send message" "create channel" "channel moderation" "real-time"; do
    if echo "$DESCRIPTION" | grep -qi "$TERM"; then
      CHAT_FOUND=$((CHAT_FOUND + 1))
    fi
  done
  if [ "$CHAT_FOUND" -ge 2 ]; then
    pass "AC8-CHAT-PHRASES" "Description includes $CHAT_FOUND/5 chat-specific trigger phrases"
  else
    fail "AC8-CHAT-PHRASES" "Description includes only $CHAT_FOUND/5 chat-specific phrases (need >= 2)"
  fi
else
  fail "AC8-CHAT-PHRASES" "Cannot extract description"
fi

# TRIG-A: Description has protocol-technical triggers (AC8)
echo "[TRIG-A] Protocol-technical triggers in description"
if [ -n "$DESCRIPTION" ]; then
  if echo "$DESCRIPTION" | grep -qi 'NIP-[0-9]\|kind:[0-9]\|channel.*creat\|e tag'; then
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
  if echo "$DESCRIPTION" | grep -qi 'how do I\|how to\|send.*message\|create.*channel\|chat.*channel'; then
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

# DEP-E: References relay-groups (AC10)
echo "[DEP-E] References relay-groups"
if [ -f "$SKILL_DIR/SKILL.md" ] && grep -qi 'relay-groups' "$SKILL_DIR/SKILL.md"; then
  pass "DEP-E" "SKILL.md references relay-groups"
else
  fail "DEP-E" "SKILL.md does not reference relay-groups"
fi

# DEP-F: References moderated-communities (AC10)
echo "[DEP-F] References moderated-communities"
if [ -f "$SKILL_DIR/SKILL.md" ] && grep -qi 'moderated-communities' "$SKILL_DIR/SKILL.md"; then
  pass "DEP-F" "SKILL.md references moderated-communities"
else
  fail "DEP-F" "SKILL.md does not reference moderated-communities"
fi

# AC10-NODUP: Skill does NOT contain toon-protocol-context.md in references/ (AC10)
echo "[AC10-NODUP] No duplicate toon-protocol-context.md in references/"
if [ -f "$SKILL_DIR/references/toon-protocol-context.md" ]; then
  fail "AC10-NODUP" "toon-protocol-context.md found in references/ (should not be duplicated)"
else
  pass "AC10-NODUP" "No duplicate toon-protocol-context.md in references/"
fi

# AC10-DEP-ALL: Skill references all six upstream skills (AC10)
echo "[AC10-DEP-ALL] References all six upstream skills"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  HAS_CORE=false
  HAS_SOCIAL=false
  HAS_INTERACTIONS=false
  HAS_CONTENT_REF=false
  HAS_RELAY_GROUPS=false
  HAS_MOD_COMMUNITIES=false
  if grep -qi 'nostr-protocol-core' "$SKILL_DIR/SKILL.md"; then HAS_CORE=true; fi
  if grep -qi 'nostr-social-intelligence' "$SKILL_DIR/SKILL.md"; then HAS_SOCIAL=true; fi
  if grep -qi 'social-interactions' "$SKILL_DIR/SKILL.md"; then HAS_INTERACTIONS=true; fi
  if grep -qi 'content-references' "$SKILL_DIR/SKILL.md"; then HAS_CONTENT_REF=true; fi
  if grep -qi 'relay-groups' "$SKILL_DIR/SKILL.md"; then HAS_RELAY_GROUPS=true; fi
  if grep -qi 'moderated-communities' "$SKILL_DIR/SKILL.md"; then HAS_MOD_COMMUNITIES=true; fi
  if [ "$HAS_CORE" = true ] && [ "$HAS_SOCIAL" = true ] && [ "$HAS_INTERACTIONS" = true ] && [ "$HAS_CONTENT_REF" = true ] && [ "$HAS_RELAY_GROUPS" = true ] && [ "$HAS_MOD_COMMUNITIES" = true ]; then
    pass "AC10-DEP-ALL" "SKILL.md references all six upstream skills"
  else
    fail "AC10-DEP-ALL" "SKILL.md missing upstream references (core=$HAS_CORE, social=$HAS_SOCIAL, interactions=$HAS_INTERACTIONS, content-ref=$HAS_CONTENT_REF, relay-groups=$HAS_RELAY_GROUPS, mod-communities=$HAS_MOD_COMMUNITIES)"
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

# AC7-EVAL-ASSERTIONS: Write evals have all 5 TOON assertions; read-only evals have format/social/trigger (AC7)
echo "[AC7-EVAL-ASSERTIONS] Write evals have all 5 TOON assertions, read evals have 3"
if [ -f "$SKILL_DIR/evals/evals.json" ]; then
  EVAL_ASSERT_OK=true
  WRITE_KEYS="toon-write-check toon-fee-check toon-format-check social-context-check trigger-coverage"
  READ_KEYS="toon-format-check social-context-check trigger-coverage"
  OUTPUT_COUNT=$(python3 -c "import json; d=json.load(open('$SKILL_DIR/evals/evals.json')); print(len(d.get('output_evals',[])))" 2>/dev/null || echo "0")
  MISSING_EVALS=""
  WRITE_COUNT=0
  READ_COUNT=0
  for i in $(seq 0 $((OUTPUT_COUNT - 1))); do
    EVAL_ID=$(python3 -c "import json; d=json.load(open('$SKILL_DIR/evals/evals.json')); print(d['output_evals'][$i]['id'])" 2>/dev/null)
    ASSERTIONS=$(python3 -c "import json; d=json.load(open('$SKILL_DIR/evals/evals.json')); print(' '.join(d['output_evals'][$i].get('assertions',[])))" 2>/dev/null)
    # Determine if this eval has write assertions (write eval) or not (read eval)
    if echo "$ASSERTIONS" | grep -q "toon-write-check"; then
      WRITE_COUNT=$((WRITE_COUNT + 1))
      for KEY in $WRITE_KEYS; do
        if ! echo "$ASSERTIONS" | grep -q "$KEY"; then
          EVAL_ASSERT_OK=false
          MISSING_EVALS="$MISSING_EVALS $EVAL_ID:$KEY"
        fi
      done
    else
      READ_COUNT=$((READ_COUNT + 1))
      for KEY in $READ_KEYS; do
        if ! echo "$ASSERTIONS" | grep -q "$KEY"; then
          EVAL_ASSERT_OK=false
          MISSING_EVALS="$MISSING_EVALS $EVAL_ID:$KEY"
        fi
      done
    fi
  done
  if [ "$EVAL_ASSERT_OK" = true ] && [ "$WRITE_COUNT" -ge 1 ] && [ "$OUTPUT_COUNT" -gt 0 ]; then
    pass "AC7-EVAL-ASSERTIONS" "$WRITE_COUNT write evals (5 assertions) + $READ_COUNT read evals (3 assertions)"
  else
    fail "AC7-EVAL-ASSERTIONS" "Missing assertions in output evals:$MISSING_EVALS (write=$WRITE_COUNT, read=$READ_COUNT)"
  fi
else
  fail "AC7-EVAL-ASSERTIONS" "evals.json not found"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# GAP-FILL TESTS (NIP-28-specific detail coverage)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "── Gap-Fill Tests (NIP-28 detail coverage) ──"

# AC2-ROOT-MARKER: nip-spec.md covers root marker for channel reference in kind:42 (AC2)
echo "[AC2-ROOT-MARKER] nip-spec.md covers root marker for channel reference"
if [ -f "$SKILL_DIR/references/nip-spec.md" ]; then
  if grep -qi 'root.*marker\|"root"\|root.*e.*tag\|e.*tag.*root' "$SKILL_DIR/references/nip-spec.md"; then
    pass "AC2-ROOT-MARKER" "nip-spec.md covers root marker for channel reference"
  else
    fail "AC2-ROOT-MARKER" "nip-spec.md does not cover root marker for channel reference"
  fi
else
  fail "AC2-ROOT-MARKER" "nip-spec.md not found"
fi

# AC2-REPLY-MARKER: nip-spec.md covers reply marker for message threading in kind:42 (AC2)
echo "[AC2-REPLY-MARKER] nip-spec.md covers reply marker for message threading"
if [ -f "$SKILL_DIR/references/nip-spec.md" ]; then
  if grep -qi 'reply.*marker\|"reply"\|reply.*e.*tag\|e.*tag.*reply' "$SKILL_DIR/references/nip-spec.md"; then
    pass "AC2-REPLY-MARKER" "nip-spec.md covers reply marker for message threading"
  else
    fail "AC2-REPLY-MARKER" "nip-spec.md does not cover reply marker for message threading"
  fi
else
  fail "AC2-REPLY-MARKER" "nip-spec.md not found"
fi

# AC2-PTAG-REPLY: nip-spec.md covers p tag for replied-to user in kind:42 (AC2)
echo "[AC2-PTAG-REPLY] nip-spec.md covers p tag for replied-to user"
if [ -f "$SKILL_DIR/references/nip-spec.md" ]; then
  if grep -qi 'p.*tag.*repl\|repl.*p.*tag\|p.*tag.*user\|replied.*to.*user\|replied.*to.*pubkey\|"p".*replied' "$SKILL_DIR/references/nip-spec.md"; then
    pass "AC2-PTAG-REPLY" "nip-spec.md covers p tag for replied-to user"
  else
    fail "AC2-PTAG-REPLY" "nip-spec.md does not cover p tag for replied-to user"
  fi
else
  fail "AC2-PTAG-REPLY" "nip-spec.md not found"
fi

# AC2-HIDE-REASON: nip-spec.md covers optional reason field in hide message (kind:43) (AC2)
echo "[AC2-HIDE-REASON] nip-spec.md covers optional reason in hide message"
if [ -f "$SKILL_DIR/references/nip-spec.md" ]; then
  if grep -qi 'reason.*hide\|hide.*reason\|kind:43.*reason\|reason.*kind:43\|optional.*reason' "$SKILL_DIR/references/nip-spec.md"; then
    pass "AC2-HIDE-REASON" "nip-spec.md covers optional reason in hide message"
  else
    fail "AC2-HIDE-REASON" "nip-spec.md does not cover optional reason in hide message"
  fi
else
  fail "AC2-HIDE-REASON" "nip-spec.md not found"
fi

# AC2-MUTE-REASON: nip-spec.md covers optional reason field in mute user (kind:44) (AC2)
echo "[AC2-MUTE-REASON] nip-spec.md covers optional reason in mute user"
if [ -f "$SKILL_DIR/references/nip-spec.md" ]; then
  if grep -qi 'reason.*mute\|mute.*reason\|kind:44.*reason\|reason.*kind:44' "$SKILL_DIR/references/nip-spec.md"; then
    pass "AC2-MUTE-REASON" "nip-spec.md covers optional reason in mute user"
  else
    fail "AC2-MUTE-REASON" "nip-spec.md does not cover optional reason in mute user"
  fi
else
  fail "AC2-MUTE-REASON" "nip-spec.md not found"
fi

# AC2-METADATA-AUTHOR-CHECK: Skill covers kind:41 author must match kind:40 creator (AC2)
echo "[AC2-METADATA-AUTHOR-CHECK] Skill covers kind:41 author must match kind:40 creator"
if grep -rqi 'author.*match\|creator.*only\|only.*creator\|only.*channel.*creator\|kind:41.*author.*kind:40\|metadata.*author.*creat' "$SKILL_DIR"/*.md "$SKILL_DIR"/references/*.md 2>/dev/null; then
  pass "AC2-METADATA-AUTHOR-CHECK" "kind:41 author validation against kind:40 creator covered"
else
  fail "AC2-METADATA-AUTHOR-CHECK" "kind:41 author validation against kind:40 creator not covered"
fi

# AC3-SPAM-RESISTANCE: Skill covers spam resistance from per-byte pricing (AC3)
echo "[AC3-SPAM-RESISTANCE] Skill covers spam resistance from per-byte pricing"
if grep -rqi 'spam.*resist\|spam.*unfeasible\|spam.*expensive\|spam.*economic\|prevent.*spam\|anti.*spam\|automated.*spam' "$SKILL_DIR"/*.md "$SKILL_DIR"/references/*.md 2>/dev/null; then
  pass "AC3-SPAM-RESISTANCE" "Spam resistance from per-byte pricing covered"
else
  fail "AC3-SPAM-RESISTANCE" "Spam resistance from per-byte pricing not covered"
fi

# AC4-METADATA-OVERRIDE: Read model covers kind:41 metadata overriding kind:40 metadata (AC4)
echo "[AC4-METADATA-OVERRIDE] Read model covers kind:41 metadata overriding kind:40"
if grep -rqi 'override.*metadata\|metadata.*override\|kind:41.*override\|kind:41.*updat.*metadata\|replace.*metadata\|metadata.*updat' "$SKILL_DIR"/*.md "$SKILL_DIR"/references/*.md 2>/dev/null; then
  pass "AC4-METADATA-OVERRIDE" "kind:41 metadata override covered"
else
  fail "AC4-METADATA-OVERRIDE" "kind:41 metadata override not covered"
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
