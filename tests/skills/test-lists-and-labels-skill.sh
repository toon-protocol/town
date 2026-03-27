#!/usr/bin/env bash
# test-lists-and-labels-skill.sh -- ATDD acceptance tests for Story 9.11: Lists and Labels Skill
# TDD RED PHASE: All tests will FAIL until the skill is implemented.
#
# Usage: ./tests/skills/test-lists-and-labels-skill.sh
# Exit 0 = all checks pass, 1 = at least one check failed
#
# Test IDs map to AC-to-Test Mapping in atdd-checklist-9-11.md:
#   STRUCT-A, STRUCT-B, STRUCT-B2, STRUCT-C, STRUCT-D
#   TOON-A, TOON-B, TOON-C, TOON-D, TOON-ALL-1, TOON-ALL-2
#   EVAL-A, EVAL-B, EVAL-A2, EVAL-B2, EVAL-C
#   TRIG-A, TRIG-B
#   DEP-A, DEP-B, DEP-C, DEP-D, DEP-E
#   CLEAN-A
#   AC1-NAME
#   AC2-NIP51, AC2-NIP32, AC2-KINDS-MUTE, AC2-KINDS-PIN, AC2-KINDS-PEOPLE, AC2-KINDS-BOOKMARKS
#   AC2-KINDS-LABEL, AC2-SECONDARY, AC2-FOLLOW-REF, AC2-PTAGS, AC2-ETAGS
#   AC2-DTAG, AC2-PRIVATE, AC2-NAMESPACE, AC2-LTAG, AC2-TARGET-TAGS
#   AC2-TOONEXT, AC2-SCENARIOS, AC2-DELETION, AC2-REPLSEM
#   AC3-CLIENT, AC3-FEEREF, AC3-COST-TRAP, AC3-BATCH
#   AC3-COREREF
#   AC4-FORMAT, AC4-FILTER-MUTE, AC4-FILTER-LABEL, AC4-READREF
#   AC5-MUTE-CONFLICT, AC5-LABEL-HONEST, AC5-COST-AWARE, AC5-PUBPRIV
#   AC5-SUBST
#   AC6-RUBRIC, AC6-TOON-ASSERT, AC6-TRIGGER-QUERIES, AC6-NOTTRIGGER-QUERIES
#   AC6-EXPECTED-OPT, AC6-OUTPUT-ID, AC6-OUTPUT-ASSERT, AC6-OUTPUT-RANGE
#   AC7-NAMED-ASSERTIONS, AC7-EVAL-ASSERTIONS
#   AC8-TRIGPHRASES, AC8-STRICT-RANGE, AC8-SOCIAL-PHRASES, AC8-LIST-PHRASES
#   AC9-TOKENS
#   AC10-NODUP, AC10-DEP-ALL
#   BASE-A (skipped -- requires manual pipeline Step 8)
#
# Total: 82 tests (81 automated + 1 skipped)

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILL_DIR="$PROJECT_ROOT/.claude/skills/lists-and-labels"
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

echo "=== ATDD Acceptance Tests: Story 9.11 Lists and Labels Skill ==="
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

# STRUCT-C: Body under 500 lines (AC1)
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

# STRUCT-D: Social Context section exists (AC11, >= 30 words)
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

# AC1-NAME: Skill name in frontmatter is "lists-and-labels" (AC1)
echo "[AC1-NAME] Skill name is lists-and-labels"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if sed -n '/^---$/,/^---$/p' "$SKILL_DIR/SKILL.md" | grep -q '^name: lists-and-labels'; then
    pass "AC1-NAME" "Skill name is lists-and-labels"
  else
    fail "AC1-NAME" "Skill name is not lists-and-labels"
  fi
else
  fail "AC1-NAME" "Cannot check name -- SKILL.md not found"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CONTENT TESTS -- NIP-51 COVERAGE (P0)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "── Content Tests -- NIP-51 Coverage (P0) ──"

# AC2-NIP51: SKILL.md mentions NIP-51 (AC2)
echo "[AC2-NIP51] SKILL.md mentions NIP-51"
if [ -f "$SKILL_DIR/SKILL.md" ] && grep -qi 'NIP-51' "$SKILL_DIR/SKILL.md"; then
  pass "AC2-NIP51" "SKILL.md mentions NIP-51"
else
  fail "AC2-NIP51" "SKILL.md does not mention NIP-51"
fi

# AC2-NIP32: SKILL.md mentions NIP-32 (AC3)
echo "[AC2-NIP32] SKILL.md mentions NIP-32"
if [ -f "$SKILL_DIR/SKILL.md" ] && grep -qi 'NIP-32' "$SKILL_DIR/SKILL.md"; then
  pass "AC2-NIP32" "SKILL.md mentions NIP-32"
else
  fail "AC2-NIP32" "SKILL.md does not mention NIP-32"
fi

# AC2-KINDS-MUTE: kind:10000 mute list covered (AC2)
echo "[AC2-KINDS-MUTE] kind:10000 mute list covered"
if [ -f "$SKILL_DIR/SKILL.md" ] && grep -qi 'kind:10000\|10000.*mute\|mute.*10000' "$SKILL_DIR/SKILL.md"; then
  pass "AC2-KINDS-MUTE" "kind:10000 mute list covered"
else
  fail "AC2-KINDS-MUTE" "kind:10000 mute list not covered in SKILL.md"
fi

# AC2-KINDS-PIN: kind:10001 pin list covered (AC2)
echo "[AC2-KINDS-PIN] kind:10001 pin list covered"
if [ -f "$SKILL_DIR/SKILL.md" ] && grep -qi 'kind:10001\|10001.*pin\|pin.*10001' "$SKILL_DIR/SKILL.md"; then
  pass "AC2-KINDS-PIN" "kind:10001 pin list covered"
else
  fail "AC2-KINDS-PIN" "kind:10001 pin list not covered in SKILL.md"
fi

# AC2-KINDS-PEOPLE: kind:30000 categorized people / follow sets covered (AC2)
echo "[AC2-KINDS-PEOPLE] kind:30000 categorized people covered"
if [ -f "$SKILL_DIR/SKILL.md" ] && grep -qi 'kind:30000\|30000.*people\|30000.*follow set\|follow set.*30000\|categorized people' "$SKILL_DIR/SKILL.md"; then
  pass "AC2-KINDS-PEOPLE" "kind:30000 categorized people covered"
else
  fail "AC2-KINDS-PEOPLE" "kind:30000 categorized people not covered in SKILL.md"
fi

# AC2-KINDS-BOOKMARKS: kind:30001 categorized bookmarks covered (AC2)
echo "[AC2-KINDS-BOOKMARKS] kind:30001 categorized bookmarks covered"
if [ -f "$SKILL_DIR/SKILL.md" ] && grep -qi 'kind:30001\|30001.*bookmark\|bookmark.*30001\|categorized bookmark' "$SKILL_DIR/SKILL.md"; then
  pass "AC2-KINDS-BOOKMARKS" "kind:30001 categorized bookmarks covered"
else
  fail "AC2-KINDS-BOOKMARKS" "kind:30001 categorized bookmarks not covered in SKILL.md"
fi

# AC2-KINDS-LABEL: kind:1985 label event covered (AC3)
echo "[AC2-KINDS-LABEL] kind:1985 label event covered"
if [ -f "$SKILL_DIR/SKILL.md" ] && grep -qi 'kind:1985\|1985.*label\|label.*1985' "$SKILL_DIR/SKILL.md"; then
  pass "AC2-KINDS-LABEL" "kind:1985 label event covered"
else
  fail "AC2-KINDS-LABEL" "kind:1985 label event not covered in SKILL.md"
fi

# AC2-SECONDARY: Secondary NIP-51 kinds acknowledged (AC2)
echo "[AC2-SECONDARY] Secondary NIP-51 kinds acknowledged"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  SECONDARY_FOUND=0
  for KIND in "10003" "10004" "10005" "10006" "10007" "10009" "10015" "10030" "30003"; do
    if grep -qi "kind:$KIND\|$KIND" "$SKILL_DIR/SKILL.md"; then
      SECONDARY_FOUND=$((SECONDARY_FOUND + 1))
    fi
  done
  if [ "$SECONDARY_FOUND" -ge 5 ]; then
    pass "AC2-SECONDARY" "SKILL.md acknowledges $SECONDARY_FOUND/9 secondary NIP-51 kinds"
  else
    fail "AC2-SECONDARY" "SKILL.md only acknowledges $SECONDARY_FOUND/9 secondary NIP-51 kinds (need >= 5)"
  fi
else
  fail "AC2-SECONDARY" "Cannot check -- SKILL.md not found"
fi

# AC2-FOLLOW-REF: References social-identity for kind:3 follow list (AC2)
echo "[AC2-FOLLOW-REF] References social-identity for kind:3 follow list"
if [ -f "$SKILL_DIR/SKILL.md" ] && grep -qi 'social-identity.*follow\|follow.*social-identity\|kind:3.*social-identity\|social-identity.*kind:3' "$SKILL_DIR/SKILL.md"; then
  pass "AC2-FOLLOW-REF" "References social-identity for kind:3 follow list"
else
  fail "AC2-FOLLOW-REF" "Does not cross-reference social-identity for kind:3 follow list"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CONTENT TESTS -- NIP-51 TAG STRUCTURE (P0)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "── Content Tests -- NIP-51 Tag Structure (P0) ──"

# AC2-PTAGS: p tags for people lists documented (AC2)
echo "[AC2-PTAGS] p tags for people lists documented"
if grep -rqi 'p.*tag.*pubkey\|p.*tag.*people\|p.*tag.*mute' "$SKILL_DIR"/*.md "$SKILL_DIR"/references/*.md 2>/dev/null; then
  pass "AC2-PTAGS" "p tags for people lists documented"
else
  fail "AC2-PTAGS" "p tags for people lists not documented"
fi

# AC2-ETAGS: e tags for event references documented (AC2)
echo "[AC2-ETAGS] e tags for event references documented"
if grep -rqi 'e.*tag.*event\|e.*tag.*pin\|e.*tag.*bookmark' "$SKILL_DIR"/*.md "$SKILL_DIR"/references/*.md 2>/dev/null; then
  pass "AC2-ETAGS" "e tags for event references documented"
else
  fail "AC2-ETAGS" "e tags for event references not documented"
fi

# AC2-DTAG: d tag for parameterized replaceable lists (AC2)
echo "[AC2-DTAG] d tag for parameterized replaceable lists"
if grep -rqi 'd.*tag.*categor\|d.*tag.*identif\|d.*tag.*name\|d.*tag.*set' "$SKILL_DIR"/*.md "$SKILL_DIR"/references/*.md 2>/dev/null; then
  pass "AC2-DTAG" "d tag for parameterized replaceable lists documented"
else
  fail "AC2-DTAG" "d tag for parameterized replaceable lists not documented"
fi

# AC2-PRIVATE: Encrypted/private list entries documented (AC2)
echo "[AC2-PRIVATE] Encrypted/private list entries documented"
if grep -rqi 'encrypt.*content\|private.*entry\|NIP-44.*encrypt\|encrypted.*tag\|\.content.*encrypt' "$SKILL_DIR"/*.md "$SKILL_DIR"/references/*.md 2>/dev/null; then
  pass "AC2-PRIVATE" "Encrypted/private list entries documented"
else
  fail "AC2-PRIVATE" "Encrypted/private list entries not documented"
fi

# AC2-REPLSEM: Replaceable vs parameterized replaceable semantics documented (AC2)
echo "[AC2-REPLSEM] Replaceable vs parameterized replaceable semantics"
if grep -rqi 'replaceable.*kind:10000\|replaceable.*kind:10001\|parameterized.*replaceable.*kind:30000\|parameterized.*replaceable.*kind:30001\|replaceable.*parameterized' "$SKILL_DIR"/*.md "$SKILL_DIR"/references/*.md 2>/dev/null; then
  pass "AC2-REPLSEM" "Replaceable vs parameterized replaceable semantics documented"
else
  # Broader check
  if grep -rqi 'replaceable' "$SKILL_DIR"/*.md "$SKILL_DIR"/references/*.md 2>/dev/null && \
     grep -rqi 'parameterized.*replaceable' "$SKILL_DIR"/*.md "$SKILL_DIR"/references/*.md 2>/dev/null; then
    pass "AC2-REPLSEM" "Both replaceable and parameterized replaceable concepts found"
  else
    fail "AC2-REPLSEM" "Replaceable vs parameterized replaceable semantics not documented"
  fi
fi

# AC2-DELETION: List deletion via NIP-09 and empty republish documented (AC2)
echo "[AC2-DELETION] List deletion documented"
if grep -rqi 'NIP-09\|NIP.09\|kind:5.*delet\|delet.*kind:5\|empty.*republish\|clear.*list' "$SKILL_DIR"/*.md "$SKILL_DIR"/references/*.md 2>/dev/null; then
  pass "AC2-DELETION" "List deletion documented (NIP-09 or empty republish)"
else
  fail "AC2-DELETION" "List deletion via NIP-09 or empty republish not documented"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CONTENT TESTS -- NIP-32 LABELING (P0)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "── Content Tests -- NIP-32 Labeling (P0) ──"

# AC2-NAMESPACE: L (namespace) tag documented (AC3)
echo "[AC2-NAMESPACE] L (namespace) tag documented"
if grep -rqi '"L".*namespace\|L.*tag.*namespace\|namespace.*L.*tag\|namespace.*tag' "$SKILL_DIR"/*.md "$SKILL_DIR"/references/*.md 2>/dev/null; then
  pass "AC2-NAMESPACE" "L namespace tag documented"
else
  fail "AC2-NAMESPACE" "L namespace tag not documented"
fi

# AC2-LTAG: l (label value) tag documented (AC3)
echo "[AC2-LTAG] l (label value) tag documented"
if grep -rqi '"l".*value\|l.*tag.*label\|label.*value.*tag\|l.*tag.*value' "$SKILL_DIR"/*.md "$SKILL_DIR"/references/*.md 2>/dev/null; then
  pass "AC2-LTAG" "l label value tag documented"
else
  fail "AC2-LTAG" "l label value tag not documented"
fi

# AC2-TARGET-TAGS: Target reference tags (e, p, a, r) for labels documented (AC3)
echo "[AC2-TARGET-TAGS] Target reference tags for labels documented"
if grep -rqi 'target.*tag\|label.*target\|e.*p.*a.*r.*tag\|what.*being.*label' "$SKILL_DIR"/*.md "$SKILL_DIR"/references/*.md 2>/dev/null; then
  pass "AC2-TARGET-TAGS" "Target reference tags for labels documented"
else
  fail "AC2-TARGET-TAGS" "Target reference tags (e, p, a, r) for labels not documented"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CONTENT TESTS -- REFERENCE FILES (P0)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "── Content Tests -- Reference Files (P0) ──"

# EVAL-A: SKILL.md body covers NIP-51, NIP-32, lists, labels (AC2/AC3)
echo "[EVAL-A] NIP coverage in SKILL.md"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  NIP_OK=true
  NIP_MISSING=""
  for TERM in "NIP-51" "NIP-32" "list" "label"; do
    if ! grep -qi "$TERM" "$SKILL_DIR/SKILL.md"; then
      NIP_OK=false
      NIP_MISSING="$NIP_MISSING $TERM"
    fi
  done
  if [ "$NIP_OK" = true ]; then
    pass "EVAL-A" "SKILL.md covers NIP-51, NIP-32, lists, labels"
  else
    fail "EVAL-A" "SKILL.md missing coverage for:$NIP_MISSING"
  fi
else
  fail "EVAL-A" "Cannot check NIP coverage -- SKILL.md not found"
fi

# EVAL-B: references/nip-spec.md covers NIP-51 + NIP-32 (AC4)
echo "[EVAL-B] NIP spec reference file coverage"
if [ -f "$SKILL_DIR/references/nip-spec.md" ]; then
  SPEC_OK=true
  SPEC_MISSING=""
  for TERM in "NIP-51" "NIP-32" "kind:10000" "kind:1985"; do
    if ! grep -qi "$TERM" "$SKILL_DIR/references/nip-spec.md"; then
      SPEC_OK=false
      SPEC_MISSING="$SPEC_MISSING $TERM"
    fi
  done
  if [ "$SPEC_OK" = true ]; then
    pass "EVAL-B" "nip-spec.md covers NIP-51 + NIP-32"
  else
    fail "EVAL-B" "nip-spec.md missing:$SPEC_MISSING"
  fi
else
  fail "EVAL-B" "nip-spec.md not found"
fi

# AC2-TOONEXT: toon-extensions.md covers ILP/per-byte costs (AC5)
echo "[AC2-TOONEXT] toon-extensions.md covers ILP/per-byte costs"
if [ -f "$SKILL_DIR/references/toon-extensions.md" ]; then
  if grep -qi 'per-byte\|per byte\|ILP\|basePricePerByte\|fee.*calc' "$SKILL_DIR/references/toon-extensions.md"; then
    pass "AC2-TOONEXT" "toon-extensions.md covers ILP/per-byte costs"
  else
    fail "AC2-TOONEXT" "toon-extensions.md does not cover ILP/per-byte costs"
  fi
else
  fail "AC2-TOONEXT" "toon-extensions.md not found"
fi

# AC2-SCENARIOS: scenarios.md covers social context scenarios (AC6)
echo "[AC2-SCENARIOS] scenarios.md covers social context scenarios"
if [ -f "$SKILL_DIR/references/scenarios.md" ]; then
  SCENARIO_WORDS=$(wc -w < "$SKILL_DIR/references/scenarios.md" | tr -d ' ')
  if [ "$SCENARIO_WORDS" -ge 100 ]; then
    pass "AC2-SCENARIOS" "scenarios.md has $SCENARIO_WORDS words (>= 100)"
  else
    fail "AC2-SCENARIOS" "scenarios.md has only $SCENARIO_WORDS words (need >= 100)"
  fi
else
  fail "AC2-SCENARIOS" "scenarios.md not found"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TOON WRITE MODEL TESTS (P0)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "── TOON Write Model Tests (P0) ──"

# TOON-A: publishEvent referenced across skill files (AC5, AC7)
echo "[TOON-A] publishEvent referenced"
if grep -rqi 'publishEvent' "$SKILL_DIR"/*.md "$SKILL_DIR"/references/*.md 2>/dev/null; then
  pass "TOON-A" "publishEvent referenced across skill files"
else
  fail "TOON-A" "publishEvent not found in any skill file"
fi

# TOON-B: Fee/cost terms referenced across skill files (AC5, AC7)
echo "[TOON-B] Fee/cost terms referenced"
if grep -rqi 'fee\|cost\|per-byte\|basePricePerByte' "$SKILL_DIR"/*.md "$SKILL_DIR"/references/*.md 2>/dev/null; then
  pass "TOON-B" "Fee/cost terms referenced across skill files"
else
  fail "TOON-B" "Fee/cost terms not found in any skill file"
fi

# AC3-CLIENT: References publishEvent() from @toon-protocol/client (AC5)
echo "[AC3-CLIENT] References publishEvent() from @toon-protocol/client"
if [ -f "$SKILL_DIR/SKILL.md" ] && grep -qi 'publishEvent.*toon-protocol.*client\|toon-protocol.*client.*publishEvent\|@toon-protocol/client' "$SKILL_DIR/SKILL.md"; then
  pass "AC3-CLIENT" "SKILL.md references publishEvent from @toon-protocol/client"
else
  fail "AC3-CLIENT" "SKILL.md does not reference publishEvent from @toon-protocol/client"
fi

# AC3-FEEREF: References fee/cost in SKILL.md (AC5)
echo "[AC3-FEEREF] References fee/cost in SKILL.md"
if [ -f "$SKILL_DIR/SKILL.md" ] && grep -qi 'fee\|cost\|per-byte\|basePricePerByte' "$SKILL_DIR/SKILL.md"; then
  pass "AC3-FEEREF" "SKILL.md references fee/cost"
else
  fail "AC3-FEEREF" "SKILL.md does not reference fee/cost"
fi

# AC3-COST-TRAP: Replaceable list cost trap documented (AC12)
echo "[AC3-COST-TRAP] Replaceable list cost trap documented"
if grep -rqi 'cost.*trap\|entire.*list.*every\|republish.*entire\|full.*list.*cost\|grow.*cost\|cost.*scal\|cost.*grow' "$SKILL_DIR"/*.md "$SKILL_DIR"/references/*.md 2>/dev/null; then
  pass "AC3-COST-TRAP" "Replaceable list cost trap documented"
else
  fail "AC3-COST-TRAP" "Replaceable list cost trap not documented"
fi

# AC3-BATCH: Batching recommendation for list updates (AC12)
echo "[AC3-BATCH] Batching recommendation for list updates"
if grep -rqi 'batch.*change\|batch.*update\|minimize.*update\|batch.*add\|combine.*change' "$SKILL_DIR"/*.md "$SKILL_DIR"/references/*.md 2>/dev/null; then
  pass "AC3-BATCH" "Batching recommendation documented"
else
  fail "AC3-BATCH" "Batching recommendation not documented"
fi

# AC3-COREREF: Write model references nostr-protocol-core for fee formula (AC5)
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

# AC4-FORMAT: References TOON-format strings in SKILL.md (AC4)
echo "[AC4-FORMAT] References TOON-format in SKILL.md"
if [ -f "$SKILL_DIR/SKILL.md" ] && grep -qi 'TOON[- ]format\|toon-format' "$SKILL_DIR/SKILL.md"; then
  pass "AC4-FORMAT" "SKILL.md references TOON-format"
else
  fail "AC4-FORMAT" "SKILL.md does not reference TOON-format"
fi

# AC4-FILTER-MUTE: Filter pattern for mute list documented (AC12)
echo "[AC4-FILTER-MUTE] Filter pattern for mute list documented"
if grep -rqi 'kind.*10000.*author\|filter.*mute\|mute.*filter\|kinds.*10000' "$SKILL_DIR"/*.md "$SKILL_DIR"/references/*.md 2>/dev/null; then
  pass "AC4-FILTER-MUTE" "Mute list filter pattern documented"
else
  fail "AC4-FILTER-MUTE" "Mute list filter pattern not documented"
fi

# AC4-FILTER-LABEL: Filter pattern for labels documented (AC12)
echo "[AC4-FILTER-LABEL] Filter pattern for labels documented"
if grep -rqi 'kind.*1985.*#e\|kind.*1985.*#L\|filter.*label\|label.*filter\|kinds.*1985' "$SKILL_DIR"/*.md "$SKILL_DIR"/references/*.md 2>/dev/null; then
  pass "AC4-FILTER-LABEL" "Label filter pattern documented"
else
  fail "AC4-FILTER-LABEL" "Label filter pattern not documented"
fi

# AC4-READREF: References nostr-protocol-core for TOON format details (AC4)
echo "[AC4-READREF] References nostr-protocol-core for TOON format"
if [ -f "$SKILL_DIR/SKILL.md" ] && grep -qi 'nostr-protocol-core.*toon-protocol-context\|toon-protocol-context\|nostr-protocol-core.*format' "$SKILL_DIR/SKILL.md"; then
  pass "AC4-READREF" "SKILL.md references nostr-protocol-core for TOON format"
else
  fail "AC4-READREF" "SKILL.md does not reference nostr-protocol-core for TOON format"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SOCIAL CONTEXT TESTS (P1)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "── Social Context Tests (P1) ──"

# TOON-D: Social Context section has list/label-specific content (AC11, >= 100 words)
echo "[TOON-D] Social Context has >= 100 words of list/label-specific content"
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

# AC5-MUTE-CONFLICT: Social Context covers mute lists as private conflict resolution (AC11)
echo "[AC5-MUTE-CONFLICT] Social Context covers mute lists as conflict resolution"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  SC_SECTION=$(awk '/^## Social Context/{found=1; next} found && /^## /{exit} found{print}' "$SKILL_DIR/SKILL.md")
  if echo "$SC_SECTION" | grep -qi 'mute.*conflict\|mute.*resolution\|mute.*private\|private.*moderat\|silent.*moderat\|mute.*personal'; then
    pass "AC5-MUTE-CONFLICT" "Social Context covers mute as private conflict resolution"
  else
    fail "AC5-MUTE-CONFLICT" "Social Context does not cover mute as private conflict resolution"
  fi
else
  fail "AC5-MUTE-CONFLICT" "Cannot check -- SKILL.md not found"
fi

# AC5-LABEL-HONEST: Social Context covers label honesty (AC11)
echo "[AC5-LABEL-HONEST] Social Context covers label honesty"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  SC_SECTION=$(awk '/^## Social Context/{found=1; next} found && /^## /{exit} found{print}' "$SKILL_DIR/SKILL.md")
  if echo "$SC_SECTION" | grep -qi 'label.*honest\|honest.*label\|label.*accurat\|label.*integrit\|responsible.*label\|label.*reputation'; then
    pass "AC5-LABEL-HONEST" "Social Context covers label honesty"
  else
    fail "AC5-LABEL-HONEST" "Social Context does not cover label honesty"
  fi
else
  fail "AC5-LABEL-HONEST" "Cannot check -- SKILL.md not found"
fi

# AC5-COST-AWARE: Social Context covers curation cost consciousness (AC11)
echo "[AC5-COST-AWARE] Social Context covers curation cost consciousness"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  SC_SECTION=$(awk '/^## Social Context/{found=1; next} found && /^## /{exit} found{print}' "$SKILL_DIR/SKILL.md")
  if echo "$SC_SECTION" | grep -qi 'cost.*curat\|cost.*conscious\|cost.*grow\|list.*grow.*cost\|econom.*curat\|curat.*cost\|every.*update.*cost\|update.*cost'; then
    pass "AC5-COST-AWARE" "Social Context covers curation cost consciousness"
  else
    fail "AC5-COST-AWARE" "Social Context does not cover curation cost consciousness"
  fi
else
  fail "AC5-COST-AWARE" "Cannot check -- SKILL.md not found"
fi

# AC5-PUBPRIV: Social Context covers public vs private list considerations (AC11)
echo "[AC5-PUBPRIV] Social Context covers public vs private list considerations"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  SC_SECTION=$(awk '/^## Social Context/{found=1; next} found && /^## /{exit} found{print}' "$SKILL_DIR/SKILL.md")
  if echo "$SC_SECTION" | grep -qi 'public.*private\|private.*public\|encrypt.*list\|private.*list\|public.*tag.*private'; then
    pass "AC5-PUBPRIV" "Social Context covers public vs private list considerations"
  else
    fail "AC5-PUBPRIV" "Social Context does not cover public vs private list considerations"
  fi
else
  fail "AC5-PUBPRIV" "Cannot check -- SKILL.md not found"
fi

# AC5-SUBST: Social Context passes NIP-name substitution test (AC11)
echo "[AC5-SUBST] Social Context is list/label-specific (not generic)"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  SC_SECTION=$(awk '/^## Social Context/{found=1; next} found && /^## /{exit} found{print}' "$SKILL_DIR/SKILL.md")
  FOUND_SPECIFIC=0
  for TERM in "mute" "bookmark" "label" "curat" "list.*grow\|grow.*list" "per-byte\|cost.*update" "NIP-51\|NIP-32" "kind:10000\|kind:1985" "private.*encrypt\|encrypt.*private"; do
    if echo "$SC_SECTION" | grep -qi "$TERM"; then
      FOUND_SPECIFIC=$((FOUND_SPECIFIC + 1))
    fi
  done
  if [ "$FOUND_SPECIFIC" -ge 5 ]; then
    pass "AC5-SUBST" "Social Context has $FOUND_SPECIFIC list/label-specific terms (passes substitution test)"
  else
    fail "AC5-SUBST" "Social Context has only $FOUND_SPECIFIC list/label-specific terms (need >= 5, fails substitution test)"
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

# EVAL-A2: Trigger eval count >= 8 should-trigger (AC7)
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

# EVAL-B2: Trigger eval count >= 8 should-not-trigger (AC7)
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

# EVAL-C: Output eval count >= 4 (AC7)
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

# AC6-RUBRIC: All output evals have rubric (correct/acceptable/incorrect) (AC7)
echo "[AC6-RUBRIC] All output evals have rubric"
if [ -f "$EVALS_FILE" ]; then
  RUBRIC_CHECK=$(node -e "
    const d = JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8'));
    const oe = d.output_evals || [];
    const valid = oe.filter(e => e.rubric && e.rubric.correct && e.rubric.acceptable && e.rubric.incorrect);
    console.log(valid.length + ' ' + oe.length);
  " "$EVALS_FILE" 2>/dev/null || echo "0 0")
  RUBRIC_WITH=$(echo "$RUBRIC_CHECK" | awk '{print $1}')
  RUBRIC_TOTAL=$(echo "$RUBRIC_CHECK" | awk '{print $2}')
  if [ "$RUBRIC_WITH" -eq "$RUBRIC_TOTAL" ] && [ "$RUBRIC_TOTAL" -gt 0 ]; then
    pass "AC6-RUBRIC" "All $RUBRIC_TOTAL output evals have correct/acceptable/incorrect rubric"
  else
    fail "AC6-RUBRIC" "$RUBRIC_WITH/$RUBRIC_TOTAL output evals have complete rubric"
  fi
else
  fail "AC6-RUBRIC" "evals/evals.json not found"
fi

# AC6-TOON-ASSERT: TOON compliance assertions in output evals (AC7)
echo "[AC6-TOON-ASSERT] TOON compliance assertions in output evals"
if [ -f "$EVALS_FILE" ]; then
  TOON_ASSERT=$(node -e "
    const d = JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8'));
    const oe = d.output_evals || [];
    const toon = oe.filter(e => (e.assertions || []).some(a => /toon/.test(a)));
    console.log(toon.length + ' ' + oe.length);
  " "$EVALS_FILE" 2>/dev/null || echo "0 0")
  TOON_WITH=$(echo "$TOON_ASSERT" | awk '{print $1}')
  TOON_TOTAL=$(echo "$TOON_ASSERT" | awk '{print $2}')
  if [ "$TOON_WITH" -gt 0 ]; then
    pass "AC6-TOON-ASSERT" "$TOON_WITH/$TOON_TOTAL output evals have TOON assertions"
  else
    fail "AC6-TOON-ASSERT" "No output evals have TOON assertions"
  fi
else
  fail "AC6-TOON-ASSERT" "evals/evals.json not found"
fi

# AC6-TRIGGER-QUERIES: Should-trigger queries cover list/label-relevant terms (AC7)
echo "[AC6-TRIGGER-QUERIES] Should-trigger queries cover list/label terms"
if [ -f "$EVALS_FILE" ]; then
  TRIG_TERMS=$(node -e "
    const d = JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8'));
    const queries = (d.trigger_evals || []).filter(e => e.should_trigger === true).map(e => e.query || e.prompt || '').join(' ').toLowerCase();
    let found = 0;
    for (const term of ['mute', 'bookmark', 'label', 'list', 'organize', 'categorize', 'pin', 'block', 'curate']) {
      if (queries.includes(term)) found++;
    }
    console.log(found);
  " "$EVALS_FILE" 2>/dev/null || echo "0")
  if [ "$TRIG_TERMS" -ge 5 ]; then
    pass "AC6-TRIGGER-QUERIES" "Should-trigger queries cover $TRIG_TERMS/9 list/label terms"
  else
    fail "AC6-TRIGGER-QUERIES" "Should-trigger queries cover only $TRIG_TERMS/9 list/label terms (need >= 5)"
  fi
else
  fail "AC6-TRIGGER-QUERIES" "evals/evals.json not found"
fi

# AC6-NOTTRIGGER-QUERIES: Should-not-trigger queries exclude unrelated topics (AC7)
echo "[AC6-NOTTRIGGER-QUERIES] Should-not-trigger queries exclude unrelated topics"
if [ -f "$EVALS_FILE" ]; then
  NOTTRIG_TERMS=$(node -e "
    const d = JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8'));
    const queries = (d.trigger_evals || []).filter(e => e.should_trigger === false).map(e => e.query || e.prompt || '').join(' ').toLowerCase();
    let found = 0;
    for (const term of ['dm', 'direct message', 'relay group', 'article', 'publish', 'channel', 'profile', 'payment']) {
      if (queries.includes(term)) found++;
    }
    console.log(found);
  " "$EVALS_FILE" 2>/dev/null || echo "0")
  if [ "$NOTTRIG_TERMS" -ge 4 ]; then
    pass "AC6-NOTTRIGGER-QUERIES" "Should-not-trigger queries cover $NOTTRIG_TERMS/8 unrelated topics"
  else
    fail "AC6-NOTTRIGGER-QUERIES" "Should-not-trigger queries cover only $NOTTRIG_TERMS/8 unrelated topics (need >= 4)"
  fi
else
  fail "AC6-NOTTRIGGER-QUERIES" "evals/evals.json not found"
fi

# AC6-EXPECTED-OPT: All output evals have expected_output field (AC7)
echo "[AC6-EXPECTED-OPT] Output evals have expected_output field"
if [ -f "$EVALS_FILE" ]; then
  EXPECTED_CHECK=$(node -e "
    const d = JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8'));
    const oe = d.output_evals || [];
    const valid = oe.filter(e => e.expected_output && e.expected_output.length > 0);
    console.log(valid.length + ' ' + oe.length);
  " "$EVALS_FILE" 2>/dev/null || echo "0 0")
  EXPECTED_WITH=$(echo "$EXPECTED_CHECK" | awk '{print $1}')
  EXPECTED_TOTAL=$(echo "$EXPECTED_CHECK" | awk '{print $2}')
  if [ "$EXPECTED_WITH" -eq "$EXPECTED_TOTAL" ] && [ "$EXPECTED_TOTAL" -gt 0 ]; then
    pass "AC6-EXPECTED-OPT" "All $EXPECTED_TOTAL output evals have expected_output"
  else
    fail "AC6-EXPECTED-OPT" "$EXPECTED_WITH/$EXPECTED_TOTAL output evals have expected_output"
  fi
else
  fail "AC6-EXPECTED-OPT" "evals/evals.json not found"
fi

# AC6-OUTPUT-ID: All output evals have id and prompt fields (AC7)
echo "[AC6-OUTPUT-ID] Output evals have id and prompt fields"
if [ -f "$EVALS_FILE" ]; then
  ID_PROMPT_CHECK=$(node -e "
    const d = JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8'));
    const oe = d.output_evals || [];
    const valid = oe.filter(e => e.id && e.prompt);
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

# AC6-OUTPUT-ASSERT: All output evals have assertions array (AC7)
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

# AC6-OUTPUT-RANGE: Output eval count is 4-6 (AC7)
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

# TOON-ALL-1: validate-skill.sh passes (AC8)
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

# TOON-ALL-2: run-eval.sh passes (AC8)
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

# AC8-STRICT-RANGE: Description is 80-120 words (AC9)
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

# AC8-TRIGPHRASES: Description includes trigger phrases (AC9)
echo "[AC8-TRIGPHRASES] Description includes trigger phrases"
if [ -n "$DESCRIPTION" ]; then
  TRIG_FOUND=0
  for TERM in "NIP-51" "NIP-32" "mute" "bookmark" "label" "kind:10000" "kind:30000" "kind:1985" "follow set" "pin" "categorize" "organize" "curate" "namespace" "list" "block"; do
    if echo "$DESCRIPTION" | grep -qi "$TERM"; then
      TRIG_FOUND=$((TRIG_FOUND + 1))
    fi
  done
  if [ "$TRIG_FOUND" -ge 8 ]; then
    pass "AC8-TRIGPHRASES" "Description includes $TRIG_FOUND/16 trigger phrases"
  else
    fail "AC8-TRIGPHRASES" "Description includes only $TRIG_FOUND/16 trigger phrases (need >= 8)"
  fi
else
  fail "AC8-TRIGPHRASES" "Cannot extract description"
fi

# AC8-SOCIAL-PHRASES: Description includes social-situation triggers (AC9)
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

# AC8-LIST-PHRASES: Description includes list/label-specific trigger phrases (AC9)
echo "[AC8-LIST-PHRASES] Description includes list/label-specific trigger phrases"
if [ -n "$DESCRIPTION" ]; then
  LIST_FOUND=0
  for TERM in "organize" "mute" "bookmark" "label" "curate"; do
    if echo "$DESCRIPTION" | grep -qi "$TERM"; then
      LIST_FOUND=$((LIST_FOUND + 1))
    fi
  done
  if [ "$LIST_FOUND" -ge 2 ]; then
    pass "AC8-LIST-PHRASES" "Description includes $LIST_FOUND/5 list/label-specific phrases"
  else
    fail "AC8-LIST-PHRASES" "Description includes only $LIST_FOUND/5 list/label phrases (need >= 2)"
  fi
else
  fail "AC8-LIST-PHRASES" "Cannot extract description"
fi

# TRIG-A: Description has protocol-technical triggers (AC9)
echo "[TRIG-A] Protocol-technical triggers in description"
if [ -n "$DESCRIPTION" ]; then
  if echo "$DESCRIPTION" | grep -qi 'NIP-[0-9]\|kind:[0-9]\|list.*kind\|label.*kind'; then
    pass "TRIG-A" "Description has protocol-technical triggers"
  else
    fail "TRIG-A" "Description missing protocol-technical triggers"
  fi
else
  fail "TRIG-A" "Cannot extract description"
fi

# TRIG-B: Description has social/user-facing triggers (AC9)
echo "[TRIG-B] Social/user-facing triggers in description"
if [ -n "$DESCRIPTION" ]; then
  if echo "$DESCRIPTION" | grep -qi 'how do I\|how to\|organize.*bookmark\|mute.*someone\|label.*content'; then
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

# AC9-TOKENS: Body is approximately 5k tokens or fewer (~3500 words max) (AC1)
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

# DEP-A: References nostr-protocol-core (AC8)
echo "[DEP-A] References nostr-protocol-core"
if [ -f "$SKILL_DIR/SKILL.md" ] && grep -qi 'nostr-protocol-core' "$SKILL_DIR/SKILL.md"; then
  pass "DEP-A" "SKILL.md references nostr-protocol-core"
else
  fail "DEP-A" "SKILL.md does not reference nostr-protocol-core"
fi

# DEP-B: References nostr-social-intelligence (AC8)
echo "[DEP-B] References nostr-social-intelligence"
if [ -f "$SKILL_DIR/SKILL.md" ] && grep -qi 'nostr-social-intelligence' "$SKILL_DIR/SKILL.md"; then
  pass "DEP-B" "SKILL.md references nostr-social-intelligence"
else
  fail "DEP-B" "SKILL.md does not reference nostr-social-intelligence"
fi

# DEP-C: References social-identity (AC8)
echo "[DEP-C] References social-identity"
if [ -f "$SKILL_DIR/SKILL.md" ] && grep -qi 'social-identity' "$SKILL_DIR/SKILL.md"; then
  pass "DEP-C" "SKILL.md references social-identity"
else
  fail "DEP-C" "SKILL.md does not reference social-identity"
fi

# DEP-D: References public-chat (AC8)
echo "[DEP-D] References public-chat"
if [ -f "$SKILL_DIR/SKILL.md" ] && grep -qi 'public-chat' "$SKILL_DIR/SKILL.md"; then
  pass "DEP-D" "SKILL.md references public-chat"
else
  fail "DEP-D" "SKILL.md does not reference public-chat"
fi

# DEP-E: References moderated-communities (AC8)
echo "[DEP-E] References moderated-communities"
if [ -f "$SKILL_DIR/SKILL.md" ] && grep -qi 'moderated-communities' "$SKILL_DIR/SKILL.md"; then
  pass "DEP-E" "SKILL.md references moderated-communities"
else
  fail "DEP-E" "SKILL.md does not reference moderated-communities"
fi

# AC10-NODUP: Skill does NOT contain toon-protocol-context.md in references/ (AC8)
echo "[AC10-NODUP] No duplicate toon-protocol-context.md in references/"
if [ -f "$SKILL_DIR/references/toon-protocol-context.md" ]; then
  fail "AC10-NODUP" "toon-protocol-context.md found in references/ (should not be duplicated)"
else
  pass "AC10-NODUP" "No duplicate toon-protocol-context.md in references/"
fi

# AC10-DEP-ALL: Skill references all five upstream skills (AC8)
echo "[AC10-DEP-ALL] References all five upstream skills"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  HAS_CORE=false
  HAS_SOCIAL_INTEL=false
  HAS_SOCIAL_ID=false
  HAS_PUBLIC_CHAT=false
  HAS_MOD_COMMUNITY=false
  if grep -qi 'nostr-protocol-core' "$SKILL_DIR/SKILL.md"; then HAS_CORE=true; fi
  if grep -qi 'nostr-social-intelligence' "$SKILL_DIR/SKILL.md"; then HAS_SOCIAL_INTEL=true; fi
  if grep -qi 'social-identity' "$SKILL_DIR/SKILL.md"; then HAS_SOCIAL_ID=true; fi
  if grep -qi 'public-chat' "$SKILL_DIR/SKILL.md"; then HAS_PUBLIC_CHAT=true; fi
  if grep -qi 'moderated-communities' "$SKILL_DIR/SKILL.md"; then HAS_MOD_COMMUNITY=true; fi
  if [ "$HAS_CORE" = true ] && [ "$HAS_SOCIAL_INTEL" = true ] && [ "$HAS_SOCIAL_ID" = true ] && [ "$HAS_PUBLIC_CHAT" = true ] && [ "$HAS_MOD_COMMUNITY" = true ]; then
    pass "AC10-DEP-ALL" "SKILL.md references all five upstream skills"
  else
    fail "AC10-DEP-ALL" "SKILL.md missing upstream references (core=$HAS_CORE, social-intel=$HAS_SOCIAL_INTEL, social-id=$HAS_SOCIAL_ID, public-chat=$HAS_PUBLIC_CHAT, mod-communities=$HAS_MOD_COMMUNITY)"
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

# AC7-NAMED-ASSERTIONS: run-eval.sh output includes all 6 named TOON assertions (AC8)
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

# AC7-EVAL-ASSERTIONS: Write evals have all 5 TOON assertions; read-only evals have format/social/trigger (AC8)
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
# GAP-FILL TESTS (NIP-51/NIP-32 detail coverage)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "── Gap-Fill Tests (detail coverage) ──"

# AC12-JSON-STRUCT: nip-spec.md has JSON event structure examples (AC12)
echo "[AC12-JSON-STRUCT] nip-spec.md has JSON event structure examples"
if [ -f "$SKILL_DIR/references/nip-spec.md" ]; then
  if grep -qi '"kind".*10000\|"kind".*10001\|"kind".*30000\|"kind".*30001\|"kind".*1985' "$SKILL_DIR/references/nip-spec.md"; then
    pass "AC12-JSON-STRUCT" "nip-spec.md has JSON event structure examples"
  else
    fail "AC12-JSON-STRUCT" "nip-spec.md missing JSON event structure examples for primary kinds"
  fi
else
  fail "AC12-JSON-STRUCT" "nip-spec.md not found"
fi

# AC12-BYTE-SIZE: Fee estimates with dollar amounts documented (AC12)
echo "[AC12-BYTE-SIZE] Fee estimates with dollar amounts documented"
if grep -rqi '\$0\.\|dollar\|byte.*cost\|cost.*byte\|fee.*estimate' "$SKILL_DIR"/*.md "$SKILL_DIR"/references/*.md 2>/dev/null; then
  pass "AC12-BYTE-SIZE" "Fee estimates with dollar amounts documented"
else
  fail "AC12-BYTE-SIZE" "Fee estimates with dollar amounts not documented"
fi

# AC12-WORD-TAG: word tag for mute list keyword matching documented (AC12)
echo "[AC12-WORD-TAG] word tag for mute list keyword matching documented"
if grep -rqi 'word.*tag\|"word".*tag\|word.*keyword\|keyword.*tag' "$SKILL_DIR"/*.md "$SKILL_DIR"/references/*.md 2>/dev/null; then
  pass "AC12-WORD-TAG" "word tag for mute list documented"
else
  fail "AC12-WORD-TAG" "word tag for mute list not documented"
fi

# AC12-SELF-LABEL: Self-labeling pattern documented (AC12)
echo "[AC12-SELF-LABEL] Self-labeling pattern documented"
if grep -rqi 'self.*label\|label.*themselves\|label.*own.*event\|own.*event.*label' "$SKILL_DIR"/*.md "$SKILL_DIR"/references/*.md 2>/dev/null; then
  pass "AC12-SELF-LABEL" "Self-labeling pattern documented"
else
  fail "AC12-SELF-LABEL" "Self-labeling pattern not documented"
fi

# AC10-REF-SECTION: SKILL.md has "When to read each reference" section (AC10)
echo "[AC10-REF-SECTION] SKILL.md has 'When to read each reference' section"
if [ -f "$SKILL_DIR/SKILL.md" ] && grep -qi 'When to read\|when to read each reference\|reference.*guide\|reading each reference' "$SKILL_DIR/SKILL.md"; then
  pass "AC10-REF-SECTION" "SKILL.md has reference reading guide section"
else
  fail "AC10-REF-SECTION" "SKILL.md missing 'When to read each reference' section"
fi

# AC12-CROSS-SKILL: Cross-skill references for secondary kinds (AC2)
echo "[AC12-CROSS-SKILL] Cross-skill references for secondary NIP-51 kinds"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  CROSS_FOUND=0
  # kind:10004 -> moderated-communities, kind:10005 -> public-chat, kind:10009 -> relay-groups
  if grep -qi 'moderated-communities\|communities.*skill' "$SKILL_DIR/SKILL.md"; then CROSS_FOUND=$((CROSS_FOUND + 1)); fi
  if grep -qi 'public-chat\|public chat.*skill' "$SKILL_DIR/SKILL.md"; then CROSS_FOUND=$((CROSS_FOUND + 1)); fi
  if grep -qi 'relay-groups\|relay group.*skill' "$SKILL_DIR/SKILL.md"; then CROSS_FOUND=$((CROSS_FOUND + 1)); fi
  if [ "$CROSS_FOUND" -ge 2 ]; then
    pass "AC12-CROSS-SKILL" "$CROSS_FOUND/3 cross-skill references for secondary kinds"
  else
    fail "AC12-CROSS-SKILL" "Only $CROSS_FOUND/3 cross-skill references for secondary kinds (need >= 2)"
  fi
else
  fail "AC12-CROSS-SKILL" "Cannot check -- SKILL.md not found"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# WITH/WITHOUT BASELINE (P2 -- manual pipeline verification)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "── With/Without Baseline (P2) ──"

# BASE-A: With/without testing requires manual pipeline Step 8
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
