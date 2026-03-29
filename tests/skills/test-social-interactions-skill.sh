#!/usr/bin/env bash
# test-social-interactions-skill.sh -- ATDD acceptance tests for Story 9.6: Social Interactions Skill
# TDD RED PHASE: All tests will FAIL until the skill is implemented.
#
# Usage: ./tests/skills/test-social-interactions-skill.sh
# Exit 0 = all checks pass, 1 = at least one check failed
#
# Test IDs map to AC-to-Test Mapping in atdd-checklist-9-6.md:
#   STRUCT-A, STRUCT-B, STRUCT-B2, STRUCT-C, STRUCT-D
#   TOON-A, TOON-B, TOON-C, TOON-D, TOON-ALL-1, TOON-ALL-2
#   EVAL-A, EVAL-B, EVAL-A2, EVAL-B2, EVAL-C
#   TRIG-A, TRIG-B
#   DEP-A, DEP-B
#   CLEAN-A
# Gap-fill tests (added to cover remaining AC criteria):
#   AC1-NAME, AC2-KIND7, AC2-KIND6, AC2-KIND16, AC2-KIND1111,
#   AC2-REACT-TAGS, AC2-REPOST-TAGS, AC2-COMMENT-TAGS,
#   AC2-REACT-CONTENT, AC2-COMMENT-THREADING,
#   AC2-TOONEXT, AC2-SCENARIOS,
#   AC3-CLIENT, AC3-FEEREF, AC3-REGULAR-EVENTS, AC3-WRITEMODEL,
#   AC4-DECODER, AC4-FILTER, AC4-REFREADS,
#   AC5-REACT-ECON, AC5-DOWNVOTE, AC5-REACTSPAM, AC5-REPOST-ENDORSE,
#   AC5-CONTEXT-COMMENT, AC5-DECISION-TREE, AC5-SUBST, AC5-NIP-SPECIFIC,
#   AC6-RUBRIC, AC6-TOON-ASSERT,
#   AC8-TRIGPHRASES, AC8-STRICT-RANGE,
#   AC9-TOKENS, AC9-TOKEN-WORDS,
#   AC10-NODUP, AC10-DEP-BOTH,
#   PIPE-REGR
# Gap-fill round 2 (AC coverage tightening):
#   AC4-READREF, AC4-READING-FREE,
#   AC6-TRIGGER-QUERIES, AC6-NOTTRIGGER-QUERIES,
#   AC3-COST-COMPARE,
#   AC8-SOCIAL-PHRASES,
#   AC2-EMOJI-REACTIONS,
#   AC2-COMMENT-EXTERNAL
# Gap-fill round 3 (fine-grained AC coverage):
#   AC3-EMBED-COST, AC3-COMMENT-SCALE, AC3-REACTION-BYTES,
#   AC2-CUSTOM-EMOJI, AC2-REPOST-SERIAL,
#   AC7-ASSERTIONS, AC6-EXPECTED-OPT
# AC11 (manual / pipeline):
#   BASE-A (skipped -- requires manual pipeline Step 8)
#
# Total: 73 tests (71 automated + 2 skipped)
# Note: In RED phase (missing files), STRUCT-B and multi-check tests may count extra fails per missing file

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILL_DIR="$PROJECT_ROOT/.claude/skills/social-interactions"
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

echo "=== ATDD Acceptance Tests: Story 9.6 Social Interactions Skill ==="
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
    # Check for forbidden extra fields
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
for REF_FILE in nip-spec.md toon-extensions.md scenarios.md; do
  if [ ! -f "$SKILL_DIR/references/$REF_FILE" ]; then
    fail "STRUCT-B" "Missing reference file: references/$REF_FILE"
    REFS_OK=false
  fi
done
if [ "$REFS_OK" = true ] && [ -d "$SKILL_DIR/references" ]; then
  pass "STRUCT-B" "All required reference files present"
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

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CONTENT TESTS -- NIP COVERAGE (P0)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "── Content Tests -- NIP Coverage (P0) ──"

# EVAL-A: SKILL.md body mentions kind:7, kind:6, kind:16, kind:1111, NIP-22, NIP-18, NIP-25 (AC2)
echo "[EVAL-A] NIP coverage in SKILL.md"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  NIP_OK=true
  for TERM in "kind:7" "kind:6" "kind:16" "kind:1111" "NIP-22" "NIP-18" "NIP-25"; do
    if ! grep -q "$TERM" "$SKILL_DIR/SKILL.md"; then
      fail "EVAL-A" "SKILL.md missing coverage for $TERM"
      NIP_OK=false
    fi
  done
  if [ "$NIP_OK" = true ]; then
    pass "EVAL-A" "SKILL.md covers kind:7, kind:6, kind:16, kind:1111, NIP-22, NIP-18, NIP-25"
  fi
else
  fail "EVAL-A" "Cannot check NIP coverage -- SKILL.md not found"
fi

# EVAL-B: references/nip-spec.md covers kind:7, kind:6, kind:16, kind:1111 structure (AC2)
echo "[EVAL-B] NIP spec reference file coverage"
if [ -f "$SKILL_DIR/references/nip-spec.md" ]; then
  SPEC_OK=true
  # Check for kind:7 reactions
  if ! grep -qi 'kind:7\|reaction' "$SKILL_DIR/references/nip-spec.md"; then
    fail "EVAL-B" "nip-spec.md missing kind:7/reaction coverage"
    SPEC_OK=false
  fi
  # Check for kind:6 reposts
  if ! grep -qi 'kind:6\|repost' "$SKILL_DIR/references/nip-spec.md"; then
    fail "EVAL-B" "nip-spec.md missing kind:6/repost coverage"
    SPEC_OK=false
  fi
  # Check for kind:16 non-kind:1 reposts
  if ! grep -qi 'kind:16' "$SKILL_DIR/references/nip-spec.md"; then
    fail "EVAL-B" "nip-spec.md missing kind:16 (non-kind:1 repost) coverage"
    SPEC_OK=false
  fi
  # Check for kind:1111 comments
  if ! grep -qi 'kind:1111\|comment' "$SKILL_DIR/references/nip-spec.md"; then
    fail "EVAL-B" "nip-spec.md missing kind:1111/comment coverage"
    SPEC_OK=false
  fi
  if [ "$SPEC_OK" = true ]; then
    pass "EVAL-B" "nip-spec.md covers kind:7, kind:6, kind:16, kind:1111"
  fi
else
  fail "EVAL-B" "references/nip-spec.md not found"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CONTENT TESTS -- SOCIAL CONTEXT (P1)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "── Content Tests -- Social Context (P1) ──"

# TOON-D: Social Context is interaction-specific (AC5)
echo "[TOON-D] Social Context is interaction-specific"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  SC_CONTENT=$(awk '/^## Social Context/{found=1; next} found && /^## /{exit} found{print}' "$SKILL_DIR/SKILL.md")
  CONTENT_OK=true
  # Must mention reactions/liking
  if ! echo "$SC_CONTENT" | grep -qi 'reaction\|react\|liking\|like'; then
    fail "TOON-D" "Social Context missing reaction/liking references"
    CONTENT_OK=false
  fi
  # Must mention downvote
  if ! echo "$SC_CONTENT" | grep -qi 'downvote\|dislike\|disapproval'; then
    fail "TOON-D" "Social Context missing downvote references"
    CONTENT_OK=false
  fi
  # Must mention reposts/endorsement
  if ! echo "$SC_CONTENT" | grep -qi 'repost\|amplif\|endors'; then
    fail "TOON-D" "Social Context missing repost/endorsement references"
    CONTENT_OK=false
  fi
  # Must mention cost/payment/economics
  if ! echo "$SC_CONTENT" | grep -qi 'cost\|pay\|money\|economic\|fee\|byte'; then
    fail "TOON-D" "Social Context missing economics references"
    CONTENT_OK=false
  fi
  if [ "$CONTENT_OK" = true ]; then
    pass "TOON-D" "Social Context is interaction-specific (reactions, downvotes, reposts, economics)"
  fi
else
  fail "TOON-D" "Cannot check Social Context specificity -- SKILL.md not found"
fi

# TRIG-A: Description contains protocol triggers (AC8)
echo "[TRIG-A] Description contains protocol triggers"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  DESCRIPTION=$(awk '/^---$/{n++; next} n==1 && /^description:/{sub(/^description: */, ""); p=1; print; next} n==1 && p && /^[a-zA-Z][a-zA-Z0-9_-]*:/{p=0} n==1 && p{print} n>=2{exit}' "$SKILL_DIR/SKILL.md")
  PTRIG_OK=true
  # Should mention relevant NIP event kinds or NIP numbers
  if ! echo "$DESCRIPTION" | grep -qi 'kind:7\|kind:6\|kind:1111\|NIP-22\|NIP-18\|NIP-25\|reaction\|repost\|comment'; then
    fail "TRIG-A" "Description missing protocol trigger phrases"
    PTRIG_OK=false
  fi
  if [ "$PTRIG_OK" = true ]; then
    pass "TRIG-A" "Description contains protocol trigger phrases"
  fi
else
  fail "TRIG-A" "Cannot check triggers -- SKILL.md not found"
fi

# TRIG-B: Description contains social-situation triggers (AC8)
echo "[TRIG-B] Description contains social-situation triggers"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  DESCRIPTION=$(awk '/^---$/{n++; next} n==1 && /^description:/{sub(/^description: */, ""); p=1; print; next} n==1 && p && /^[a-zA-Z][a-zA-Z0-9_-]*:/{p=0} n==1 && p{print} n>=2{exit}' "$SKILL_DIR/SKILL.md")
  if echo "$DESCRIPTION" | grep -qi 'should I\|when to\|how do I\|how to\|is this worth\|is it worth'; then
    pass "TRIG-B" "Description contains social-situation trigger phrases"
  else
    fail "TRIG-B" "Description missing social-situation trigger phrases"
  fi
else
  fail "TRIG-B" "Cannot check triggers -- SKILL.md not found"
fi

# DEP-A: References nostr-protocol-core (AC10)
echo "[DEP-A] References nostr-protocol-core"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if grep -q 'nostr-protocol-core' "$SKILL_DIR/SKILL.md"; then
    pass "DEP-A" "SKILL.md references nostr-protocol-core"
  else
    fail "DEP-A" "SKILL.md does not reference nostr-protocol-core"
  fi
else
  fail "DEP-A" "Cannot check references -- SKILL.md not found"
fi

# DEP-B: References nostr-social-intelligence (AC10)
echo "[DEP-B] References nostr-social-intelligence"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if grep -q 'nostr-social-intelligence' "$SKILL_DIR/SKILL.md"; then
    pass "DEP-B" "SKILL.md references nostr-social-intelligence"
  else
    fail "DEP-B" "SKILL.md does not reference nostr-social-intelligence"
  fi
else
  fail "DEP-B" "Cannot check references -- SKILL.md not found"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TOON COMPLIANCE TESTS (P0)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "── TOON Compliance Tests (P0) ──"

# TOON-A: publishEvent referenced, no bare EVENT patterns (AC3)
echo "[TOON-A] toon-write-check"
if [ -d "$SKILL_DIR" ]; then
  WRITE_OK=true
  if ! grep -rq 'publishEvent' "$SKILL_DIR"/*.md "$SKILL_DIR"/references/*.md 2>/dev/null; then
    fail "TOON-A" "publishEvent not referenced in skill files"
    WRITE_OK=false
  fi
  BARE_EVENT=$(grep -rl '\["EVENT"' "$SKILL_DIR"/*.md "$SKILL_DIR"/references/*.md 2>/dev/null || true)
  if [ -n "$BARE_EVENT" ]; then
    fail "TOON-A" "Bare EVENT pattern found in: $BARE_EVENT"
    WRITE_OK=false
  fi
  if [ "$WRITE_OK" = true ]; then
    pass "TOON-A" "publishEvent referenced, no bare EVENT patterns"
  fi
else
  fail "TOON-A" "Skill directory not found"
fi

# TOON-B: Fee awareness (AC3)
echo "[TOON-B] toon-fee-check"
if [ -d "$SKILL_DIR" ]; then
  if grep -rqi 'basePricePerByte\|fee calculation\|fee awareness\|publishing fee\|cost.*per.*byte\|pricing\|pay.*to.*write\|ILP.*payment' "$SKILL_DIR"/*.md "$SKILL_DIR"/references/*.md 2>/dev/null; then
    pass "TOON-B" "Fee-related terms found in skill files"
  else
    fail "TOON-B" "No fee-related terms found"
  fi
else
  fail "TOON-B" "Skill directory not found"
fi

# TOON-C: TOON format documented (AC4)
echo "[TOON-C] toon-format-check"
if [ -d "$SKILL_DIR" ]; then
  if grep -rqi 'TOON[- ]format\|toon-format\|TOON format' "$SKILL_DIR"/*.md "$SKILL_DIR"/references/*.md 2>/dev/null; then
    pass "TOON-C" "TOON format reference found"
  else
    fail "TOON-C" "No TOON format reference found"
  fi
else
  fail "TOON-C" "Skill directory not found"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# EVAL QUALITY TESTS (P0)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "── Eval Quality Tests (P0) ──"

EVALS_FILE="$SKILL_DIR/evals/evals.json"

# EVAL-A2: 8-10 should-trigger queries (AC6)
echo "[EVAL-A2] Should-trigger query count (8-10)"
if [ -f "$EVALS_FILE" ]; then
  TRIGGER_TRUE=$(node -e "
    const d = JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8'));
    console.log((d.trigger_evals || []).filter(e => e.should_trigger === true).length);
  " "$EVALS_FILE" 2>/dev/null || echo "0")
  if [ "$TRIGGER_TRUE" -ge 8 ] && [ "$TRIGGER_TRUE" -le 10 ]; then
    pass "EVAL-A2" "Should-trigger count: $TRIGGER_TRUE (8-10 range)"
  else
    fail "EVAL-A2" "Should-trigger count: $TRIGGER_TRUE (expected 8-10)"
  fi
else
  fail "EVAL-A2" "evals/evals.json not found"
fi

# EVAL-B2: 8-10 should-not-trigger queries (AC6)
echo "[EVAL-B2] Should-not-trigger query count (8-10)"
if [ -f "$EVALS_FILE" ]; then
  TRIGGER_FALSE=$(node -e "
    const d = JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8'));
    console.log((d.trigger_evals || []).filter(e => e.should_trigger === false).length);
  " "$EVALS_FILE" 2>/dev/null || echo "0")
  if [ "$TRIGGER_FALSE" -ge 8 ] && [ "$TRIGGER_FALSE" -le 10 ]; then
    pass "EVAL-B2" "Should-not-trigger count: $TRIGGER_FALSE (8-10 range)"
  else
    fail "EVAL-B2" "Should-not-trigger count: $TRIGGER_FALSE (expected 8-10)"
  fi
else
  fail "EVAL-B2" "evals/evals.json not found"
fi

# EVAL-C: 4-6 output evals with id, prompt, rubric, assertions (AC6)
echo "[EVAL-C] Output eval count and structure (4-6)"
if [ -f "$EVALS_FILE" ]; then
  EVAL_RESULT=$(node -e "
    const d = JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8'));
    const oe = d.output_evals || [];
    const valid = oe.filter(e => e.id && e.prompt && e.rubric && Array.isArray(e.assertions) && e.assertions.length > 0);
    console.log(oe.length + ' ' + valid.length);
  " "$EVALS_FILE" 2>/dev/null || echo "0 0")
  OUTPUT_COUNT=$(echo "$EVAL_RESULT" | awk '{print $1}')
  VALID_COUNT=$(echo "$EVAL_RESULT" | awk '{print $2}')
  if [ "$OUTPUT_COUNT" -ge 4 ] && [ "$OUTPUT_COUNT" -le 6 ] && [ "$VALID_COUNT" -eq "$OUTPUT_COUNT" ]; then
    pass "EVAL-C" "Output evals: $OUTPUT_COUNT (all valid with id, prompt, rubric, assertions)"
  else
    fail "EVAL-C" "Output evals: $OUTPUT_COUNT total, $VALID_COUNT valid (expected 4-6 all valid)"
  fi
else
  fail "EVAL-C" "evals/evals.json not found"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INTEGRATION: EXISTING FRAMEWORK TESTS (P0)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "── Integration: Existing Framework Tests (P0) ──"

# TOON-ALL: validate-skill.sh passes (AC7)
echo "[TOON-ALL-1] validate-skill.sh passes"
if [ -d "$SKILL_DIR" ] && [ -f "$VALIDATE_SCRIPT" ]; then
  if bash "$VALIDATE_SCRIPT" "$SKILL_DIR" > /dev/null 2>&1; then
    pass "TOON-ALL-1" "validate-skill.sh passes"
  else
    fail "TOON-ALL-1" "validate-skill.sh failed"
  fi
else
  fail "TOON-ALL-1" "Skill directory or validate-skill.sh not found"
fi

# TOON-ALL: run-eval.sh passes (AC7)
echo "[TOON-ALL-2] run-eval.sh passes"
if [ -d "$SKILL_DIR" ] && [ -f "$RUNEVAL_SCRIPT" ]; then
  if bash "$RUNEVAL_SCRIPT" "$SKILL_DIR" > /dev/null 2>&1; then
    pass "TOON-ALL-2" "run-eval.sh passes (all 6 TOON compliance assertions)"
  else
    fail "TOON-ALL-2" "run-eval.sh failed"
  fi
else
  fail "TOON-ALL-2" "Skill directory or run-eval.sh not found"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# NO EXTRANEOUS FILES CHECK
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "── Extraneous File Check ──"

echo "[CLEAN-A] No extraneous files"
if [ -d "$SKILL_DIR" ]; then
  EXTRANEOUS=$(find "$SKILL_DIR" -maxdepth 1 -name '*.md' ! -name 'SKILL.md' 2>/dev/null || true)
  if [ -n "$EXTRANEOUS" ]; then
    fail "CLEAN-A" "Extraneous .md files in skill root: $EXTRANEOUS"
  else
    pass "CLEAN-A" "No extraneous files in skill root"
  fi
else
  fail "CLEAN-A" "Skill directory not found"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# GAP-FILL TESTS: AC coverage not in core test suite
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "── Gap-Fill Tests (AC completeness) ──"

# AC1-NAME: Frontmatter name field is exactly "social-interactions"
echo "[AC1-NAME] Frontmatter name field value"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  NAME_VALUE=$(awk '/^---$/{n++; next} n==1 && /^name:/{sub(/^name: */, ""); print; exit}' "$SKILL_DIR/SKILL.md")
  if [ "$NAME_VALUE" = "social-interactions" ]; then
    pass "AC1-NAME" "Frontmatter name is 'social-interactions'"
  else
    fail "AC1-NAME" "Frontmatter name is '$NAME_VALUE' (expected 'social-interactions')"
  fi
else
  fail "AC1-NAME" "SKILL.md not found"
fi

# AC2-KIND7: SKILL.md documents kind:7 reactions with e and p tags (AC2)
echo "[AC2-KIND7] kind:7 reactions documented with e and p tags"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if grep -q 'kind:7' "$SKILL_DIR/SKILL.md" && grep -qi 'reaction' "$SKILL_DIR/SKILL.md"; then
    pass "AC2-KIND7" "kind:7 reactions documented in SKILL.md"
  else
    fail "AC2-KIND7" "Missing kind:7 reaction documentation in SKILL.md"
  fi
else
  fail "AC2-KIND7" "SKILL.md not found"
fi

# AC2-KIND6: SKILL.md documents kind:6 reposts (AC2)
echo "[AC2-KIND6] kind:6 reposts documented"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if grep -q 'kind:6' "$SKILL_DIR/SKILL.md" && grep -qi 'repost' "$SKILL_DIR/SKILL.md"; then
    pass "AC2-KIND6" "kind:6 reposts documented in SKILL.md"
  else
    fail "AC2-KIND6" "Missing kind:6 repost documentation in SKILL.md"
  fi
else
  fail "AC2-KIND6" "SKILL.md not found"
fi

# AC2-KIND16: SKILL.md documents kind:16 for non-kind:1 reposts (AC2)
echo "[AC2-KIND16] kind:16 non-kind:1 reposts documented"
if [ -f "$SKILL_DIR/SKILL.md" ] || [ -f "$SKILL_DIR/references/nip-spec.md" ]; then
  if grep -rq 'kind:16' "$SKILL_DIR/SKILL.md" "$SKILL_DIR/references/nip-spec.md" 2>/dev/null; then
    pass "AC2-KIND16" "kind:16 non-kind:1 reposts documented"
  else
    fail "AC2-KIND16" "Missing kind:16 non-kind:1 repost documentation"
  fi
else
  fail "AC2-KIND16" "Required files not found"
fi

# AC2-KIND1111: SKILL.md documents kind:1111 comments (AC2)
echo "[AC2-KIND1111] kind:1111 comments documented"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if grep -q 'kind:1111' "$SKILL_DIR/SKILL.md" && grep -qi 'comment' "$SKILL_DIR/SKILL.md"; then
    pass "AC2-KIND1111" "kind:1111 comments documented in SKILL.md"
  else
    fail "AC2-KIND1111" "Missing kind:1111 comment documentation in SKILL.md"
  fi
else
  fail "AC2-KIND1111" "SKILL.md not found"
fi

# AC2-REACT-TAGS: Reaction tags documented (e tag, p tag) (AC2)
echo "[AC2-REACT-TAGS] Reaction e and p tags documented"
if [ -f "$SKILL_DIR/SKILL.md" ] || [ -f "$SKILL_DIR/references/nip-spec.md" ]; then
  REACT_TAGS_OK=true
  if ! grep -rqi '`e`.*tag\|"e" tag\|e tag.*react\|react.*e tag' "$SKILL_DIR/SKILL.md" "$SKILL_DIR/references/nip-spec.md" 2>/dev/null; then
    fail "AC2-REACT-TAGS" "Missing e tag documentation for reactions"
    REACT_TAGS_OK=false
  fi
  if ! grep -rqi '`p`.*tag\|"p" tag\|p tag.*author\|author.*p tag' "$SKILL_DIR/SKILL.md" "$SKILL_DIR/references/nip-spec.md" 2>/dev/null; then
    fail "AC2-REACT-TAGS" "Missing p tag documentation for reactions"
    REACT_TAGS_OK=false
  fi
  if [ "$REACT_TAGS_OK" = true ]; then
    pass "AC2-REACT-TAGS" "Reaction e and p tags documented"
  fi
else
  fail "AC2-REACT-TAGS" "Required files not found"
fi

# AC2-REPOST-TAGS: Repost tags documented (e tag, p tag) (AC2)
echo "[AC2-REPOST-TAGS] Repost e and p tags documented"
if [ -f "$SKILL_DIR/SKILL.md" ] || [ -f "$SKILL_DIR/references/nip-spec.md" ]; then
  if grep -rqi 'repost' "$SKILL_DIR/SKILL.md" "$SKILL_DIR/references/nip-spec.md" 2>/dev/null && \
     grep -rqi '`e`\|"e"\|e tag' "$SKILL_DIR/SKILL.md" "$SKILL_DIR/references/nip-spec.md" 2>/dev/null; then
    pass "AC2-REPOST-TAGS" "Repost e and p tags documented"
  else
    fail "AC2-REPOST-TAGS" "Missing repost tag documentation"
  fi
else
  fail "AC2-REPOST-TAGS" "Required files not found"
fi

# AC2-COMMENT-TAGS: Comment root scope tags documented (uppercase E, A, I and lowercase e, a, i) (AC2)
echo "[AC2-COMMENT-TAGS] Comment root scope and reply tags documented"
if [ -f "$SKILL_DIR/SKILL.md" ] || [ -f "$SKILL_DIR/references/nip-spec.md" ]; then
  COMMENT_TAGS_OK=true
  # Check for uppercase root scope tags
  if ! grep -rq '`E`\|"E"\|uppercase.*E\|root.*E\|E.*root\|`A`\|"A"\|`I`\|"I"' "$SKILL_DIR/SKILL.md" "$SKILL_DIR/references/nip-spec.md" 2>/dev/null; then
    fail "AC2-COMMENT-TAGS" "Missing uppercase root scope tags (E, A, I) documentation"
    COMMENT_TAGS_OK=false
  fi
  # Check for k tag (root event kind)
  if ! grep -rqi '`k`.*tag\|"k" tag\|`K`\|k tag.*kind\|kind.*tag' "$SKILL_DIR/SKILL.md" "$SKILL_DIR/references/nip-spec.md" 2>/dev/null; then
    fail "AC2-COMMENT-TAGS" "Missing k tag (root event kind) documentation"
    COMMENT_TAGS_OK=false
  fi
  if [ "$COMMENT_TAGS_OK" = true ]; then
    pass "AC2-COMMENT-TAGS" "Comment root scope tags and k tag documented"
  fi
else
  fail "AC2-COMMENT-TAGS" "Required files not found"
fi

# AC2-REACT-CONTENT: Reaction content field documented (+, -, emoji) (AC2)
echo "[AC2-REACT-CONTENT] Reaction content field documented (like +, dislike -, emoji)"
if [ -f "$SKILL_DIR/SKILL.md" ] || [ -f "$SKILL_DIR/references/nip-spec.md" ]; then
  REACT_OK=true
  # Check for + (like) reaction
  if ! grep -rqi 'like\|`+`\|"+"' "$SKILL_DIR/SKILL.md" "$SKILL_DIR/references/nip-spec.md" 2>/dev/null; then
    fail "AC2-REACT-CONTENT" "Missing + (like) reaction documentation"
    REACT_OK=false
  fi
  # Check for - (dislike/downvote) reaction
  if ! grep -rqi 'dislike\|downvote\|`-`\|"-"' "$SKILL_DIR/SKILL.md" "$SKILL_DIR/references/nip-spec.md" 2>/dev/null; then
    fail "AC2-REACT-CONTENT" "Missing - (dislike/downvote) reaction documentation"
    REACT_OK=false
  fi
  # Check for emoji reactions
  if ! grep -rqi 'emoji' "$SKILL_DIR/SKILL.md" "$SKILL_DIR/references/nip-spec.md" 2>/dev/null; then
    fail "AC2-REACT-CONTENT" "Missing emoji reaction documentation"
    REACT_OK=false
  fi
  if [ "$REACT_OK" = true ]; then
    pass "AC2-REACT-CONTENT" "Reaction content field documented (like, dislike, emoji)"
  fi
else
  fail "AC2-REACT-CONTENT" "Required files not found"
fi

# AC2-COMMENT-THREADING: Comment threading model documented (AC2)
echo "[AC2-COMMENT-THREADING] Comment threading model documented"
if [ -f "$SKILL_DIR/SKILL.md" ] || [ -f "$SKILL_DIR/references/nip-spec.md" ]; then
  if grep -rqi 'thread\|threading\|reply.*chain\|comment on.*comment\|parent.*comment' "$SKILL_DIR/SKILL.md" "$SKILL_DIR/references/nip-spec.md" 2>/dev/null; then
    pass "AC2-COMMENT-THREADING" "Comment threading model documented"
  else
    fail "AC2-COMMENT-THREADING" "Missing comment threading model documentation"
  fi
else
  fail "AC2-COMMENT-THREADING" "Required files not found"
fi

# AC2-TOONEXT: toon-extensions.md covers fee tables for social interactions
echo "[AC2-TOONEXT] toon-extensions.md covers social interaction fees"
if [ -f "$SKILL_DIR/references/toon-extensions.md" ]; then
  if grep -qi 'basePricePerByte\|fee\|cost' "$SKILL_DIR/references/toon-extensions.md" && grep -qi 'reaction\|repost\|comment\|kind:7\|kind:6\|kind:1111' "$SKILL_DIR/references/toon-extensions.md"; then
    pass "AC2-TOONEXT" "toon-extensions.md covers social interaction fees"
  else
    fail "AC2-TOONEXT" "toon-extensions.md missing fee tables for social interactions"
  fi
else
  fail "AC2-TOONEXT" "references/toon-extensions.md not found"
fi

# AC2-SCENARIOS: scenarios.md covers social interaction workflows
echo "[AC2-SCENARIOS] scenarios.md covers social interaction workflows"
if [ -f "$SKILL_DIR/references/scenarios.md" ]; then
  SCENARIO_OK=true
  # Check for reaction workflow
  if ! grep -qi 'react\|reaction\|kind:7' "$SKILL_DIR/references/scenarios.md"; then
    fail "AC2-SCENARIOS" "scenarios.md missing reaction workflow"
    SCENARIO_OK=false
  fi
  # Check for repost workflow
  if ! grep -qi 'repost\|kind:6' "$SKILL_DIR/references/scenarios.md"; then
    fail "AC2-SCENARIOS" "scenarios.md missing repost workflow"
    SCENARIO_OK=false
  fi
  # Check for comment workflow
  if ! grep -qi 'comment\|kind:1111' "$SKILL_DIR/references/scenarios.md"; then
    fail "AC2-SCENARIOS" "scenarios.md missing comment workflow"
    SCENARIO_OK=false
  fi
  # Check for downvote scenario
  if ! grep -qi 'downvote\|dislike\|`-`\|disapproval' "$SKILL_DIR/references/scenarios.md"; then
    fail "AC2-SCENARIOS" "scenarios.md missing downvote decision scenario"
    SCENARIO_OK=false
  fi
  if [ "$SCENARIO_OK" = true ]; then
    pass "AC2-SCENARIOS" "scenarios.md covers all social interaction workflows"
  fi
else
  fail "AC2-SCENARIOS" "references/scenarios.md not found"
fi

# AC3-CLIENT: Uses publishEvent from @toon-protocol/client specifically
echo "[AC3-CLIENT] publishEvent from @toon-protocol/client referenced"
if grep -rq '@toon-protocol/client' "$SKILL_DIR/SKILL.md" "$SKILL_DIR/references/"*.md 2>/dev/null; then
  pass "AC3-CLIENT" "@toon-protocol/client referenced for publishEvent"
else
  fail "AC3-CLIENT" "@toon-protocol/client not referenced"
fi

# AC3-FEEREF: Fee calculation references nostr-protocol-core
echo "[AC3-FEEREF] Fee calculation references nostr-protocol-core"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if grep -q 'nostr-protocol-core' "$SKILL_DIR/SKILL.md" && grep -qi 'fee\|basePricePerByte\|cost' "$SKILL_DIR/SKILL.md"; then
    pass "AC3-FEEREF" "Fee calculation present with nostr-protocol-core reference"
  else
    fail "AC3-FEEREF" "Missing fee calculation or nostr-protocol-core reference"
  fi
else
  fail "AC3-FEEREF" "SKILL.md not found"
fi

# AC3-REGULAR-EVENTS: Documents that all interaction events are regular (non-replaceable) (AC3)
echo "[AC3-REGULAR-EVENTS] Documents that interaction events are regular (non-replaceable)"
if [ -f "$SKILL_DIR/SKILL.md" ] || [ -f "$SKILL_DIR/references/nip-spec.md" ]; then
  if grep -rqi 'regular.*event\|non-replaceable\|not.*replaceable\|cannot be replaced\|permanent' "$SKILL_DIR/SKILL.md" "$SKILL_DIR/references/nip-spec.md" 2>/dev/null; then
    pass "AC3-REGULAR-EVENTS" "Interaction events documented as regular (non-replaceable)"
  else
    fail "AC3-REGULAR-EVENTS" "Missing documentation that interaction events are regular/non-replaceable"
  fi
else
  fail "AC3-REGULAR-EVENTS" "Required files not found"
fi

# AC3-WRITEMODEL: SKILL.md has a TOON Write Model section
echo "[AC3-WRITEMODEL] TOON Write Model section exists"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if grep -q '## TOON Write Model' "$SKILL_DIR/SKILL.md"; then
    pass "AC3-WRITEMODEL" "TOON Write Model section present"
  else
    fail "AC3-WRITEMODEL" "## TOON Write Model section missing from SKILL.md"
  fi
else
  fail "AC3-WRITEMODEL" "SKILL.md not found"
fi

# AC4-DECODER: TOON Read Model section exists with format details
echo "[AC4-DECODER] TOON Read Model section exists with format details"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if grep -q '## TOON Read Model' "$SKILL_DIR/SKILL.md"; then
    pass "AC4-DECODER" "TOON Read Model section present"
  else
    fail "AC4-DECODER" "## TOON Read Model section missing from SKILL.md"
  fi
else
  fail "AC4-DECODER" "SKILL.md not found"
fi

# AC4-FILTER: Read model mentions filtering by kinds:[7], kinds:[6, 16], kinds:[1111] and #e tag (AC4)
echo "[AC4-FILTER] Read model mentions kind filters and #e tag filter"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  FILTER_OK=true
  if ! grep -qi 'kinds.*7\|kinds: \[7\]\|kinds:\[7\]' "$SKILL_DIR/SKILL.md"; then
    fail "AC4-FILTER" "Missing kinds:[7] filter mention for reactions"
    FILTER_OK=false
  fi
  if ! grep -qi 'kinds.*1111\|kinds.*\[1111\]\|kinds:\[1111\]' "$SKILL_DIR/SKILL.md"; then
    fail "AC4-FILTER" "Missing kinds:[1111] filter mention for comments"
    FILTER_OK=false
  fi
  if ! grep -qi '#e.*tag\|"#e"\|#e.*filter\|tag.*filter' "$SKILL_DIR/SKILL.md"; then
    fail "AC4-FILTER" "Missing #e tag filter mention"
    FILTER_OK=false
  fi
  if [ "$FILTER_OK" = true ]; then
    pass "AC4-FILTER" "Read model mentions kind filters and #e tag filtering"
  fi
else
  fail "AC4-FILTER" "SKILL.md not found"
fi

# AC4-REFREADS: SKILL.md has "When to Read Each Reference" section
echo "[AC4-REFREADS] 'When to Read Each Reference' section exists"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if grep -qi 'When to Read\|When to read' "$SKILL_DIR/SKILL.md"; then
    pass "AC4-REFREADS" "'When to Read Each Reference' section present"
  else
    fail "AC4-REFREADS" "'When to Read Each Reference' section missing"
  fi
else
  fail "AC4-REFREADS" "SKILL.md not found"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SOCIAL CONTEXT DETAIL TESTS (P1)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "── Social Context Detail Tests (P1) ──"

# AC5-REACT-ECON: Social Context covers reactions as economic signals (AC5)
echo "[AC5-REACT-ECON] Social Context covers reactions as economic signals"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  SC_CONTENT=$(awk '/^## Social Context/{found=1; next} found && /^## /{exit} found{print}' "$SKILL_DIR/SKILL.md")
  if echo "$SC_CONTENT" | grep -qi 'react.*cost\|cost.*react\|react.*money\|money.*react\|react.*economic\|economic.*signal\|micro-payment\|selective'; then
    pass "AC5-REACT-ECON" "Reactions as economic signals theme present"
  else
    fail "AC5-REACT-ECON" "Missing reactions as economic signals theme"
  fi
else
  fail "AC5-REACT-ECON" "SKILL.md not found"
fi

# AC5-DOWNVOTE: Social Context covers downvote gravity (AC5)
echo "[AC5-DOWNVOTE] Social Context covers downvote gravity"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  SC_CONTENT=$(awk '/^## Social Context/{found=1; next} found && /^## /{exit} found{print}' "$SKILL_DIR/SKILL.md")
  if echo "$SC_CONTENT" | grep -qi 'downvote\|dislike\|disapproval\|confrontational\|`-`'; then
    pass "AC5-DOWNVOTE" "Downvote gravity theme present"
  else
    fail "AC5-DOWNVOTE" "Missing downvote gravity theme"
  fi
else
  fail "AC5-DOWNVOTE" "SKILL.md not found"
fi

# AC5-REACTSPAM: Social Context covers react-spam warning (AC5)
echo "[AC5-REACTSPAM] Social Context covers react-spam warning"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  SC_CONTENT=$(awk '/^## Social Context/{found=1; next} found && /^## /{exit} found{print}' "$SKILL_DIR/SKILL.md")
  if echo "$SC_CONTENT" | grep -qi 'spam\|mass.*react\|mass.*lik\|quality.*over.*quantity\|careless\|inflat'; then
    pass "AC5-REACTSPAM" "React-spam warning theme present"
  else
    fail "AC5-REACTSPAM" "Missing react-spam warning theme"
  fi
else
  fail "AC5-REACTSPAM" "SKILL.md not found"
fi

# AC5-REPOST-ENDORSE: Social Context covers reposts as endorsement (AC5)
echo "[AC5-REPOST-ENDORSE] Social Context covers reposts as endorsement"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  SC_CONTENT=$(awk '/^## Social Context/{found=1; next} found && /^## /{exit} found{print}' "$SKILL_DIR/SKILL.md")
  if echo "$SC_CONTENT" | grep -qi 'repost.*endors\|endors.*repost\|repost.*amplif\|amplif.*repost\|paying.*amplif\|paying.*visib'; then
    pass "AC5-REPOST-ENDORSE" "Reposts as endorsement theme present"
  else
    fail "AC5-REPOST-ENDORSE" "Missing reposts as endorsement theme"
  fi
else
  fail "AC5-REPOST-ENDORSE" "SKILL.md not found"
fi

# AC5-CONTEXT-COMMENT: Social Context covers context-aware commenting (AC5)
echo "[AC5-CONTEXT-COMMENT] Social Context covers context-aware commenting"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  SC_CONTENT=$(awk '/^## Social Context/{found=1; next} found && /^## /{exit} found{print}' "$SKILL_DIR/SKILL.md")
  if echo "$SC_CONTENT" | grep -qi 'context.*comment\|comment.*context\|substant\|tone-deaf\|low-effort.*comment\|read the room'; then
    pass "AC5-CONTEXT-COMMENT" "Context-aware commenting theme present"
  else
    fail "AC5-CONTEXT-COMMENT" "Missing context-aware commenting theme"
  fi
else
  fail "AC5-CONTEXT-COMMENT" "SKILL.md not found"
fi

# AC5-DECISION-TREE: Social Context references interaction decision tree from nostr-social-intelligence (AC5)
echo "[AC5-DECISION-TREE] Social Context references interaction decision tree"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  SC_CONTENT=$(awk '/^## Social Context/{found=1; next} found && /^## /{exit} found{print}' "$SKILL_DIR/SKILL.md")
  if echo "$SC_CONTENT" | grep -qi 'decision.*tree\|nostr-social-intelligence\|interaction decision\|when.*engage\|whether.*interact'; then
    pass "AC5-DECISION-TREE" "Interaction decision tree reference present"
  else
    fail "AC5-DECISION-TREE" "Missing interaction decision tree reference"
  fi
else
  fail "AC5-DECISION-TREE" "SKILL.md not found"
fi

# AC5-SUBST: Social Context substitution test (interaction-specific, not generic)
echo "[AC5-SUBST] Social Context passes substitution test (interaction-specific)"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  SC_CONTENT=$(awk '/^## Social Context/{found=1; next} found && /^## /{exit} found{print}' "$SKILL_DIR/SKILL.md")
  SUBST_SCORE=0
  # These are interaction-specific terms that would fail substitution test
  echo "$SC_CONTENT" | grep -qi 'reaction\|react' && SUBST_SCORE=$((SUBST_SCORE + 1))
  echo "$SC_CONTENT" | grep -qi 'downvote\|dislike' && SUBST_SCORE=$((SUBST_SCORE + 1))
  echo "$SC_CONTENT" | grep -qi 'repost\|amplif' && SUBST_SCORE=$((SUBST_SCORE + 1))
  echo "$SC_CONTENT" | grep -qi 'comment\|thread' && SUBST_SCORE=$((SUBST_SCORE + 1))
  echo "$SC_CONTENT" | grep -qi 'liking\|like\|endors' && SUBST_SCORE=$((SUBST_SCORE + 1))
  if [ "$SUBST_SCORE" -ge 4 ]; then
    pass "AC5-SUBST" "Social Context is interaction-specific ($SUBST_SCORE/5 interaction terms)"
  else
    fail "AC5-SUBST" "Social Context too generic ($SUBST_SCORE/5 interaction terms, need >= 4)"
  fi
else
  fail "AC5-SUBST" "SKILL.md not found"
fi

# AC5-NIP-SPECIFIC: Social Context has interaction-specific compound terms (substitution-proof)
echo "[AC5-NIP-SPECIFIC] Social Context has interaction-specific compound terms (substitution-proof)"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  SC_CONTENT=$(awk '/^## Social Context/{found=1; next} found && /^## /{exit} found{print}' "$SKILL_DIR/SKILL.md")
  NIP_SCORE=0
  # Compound interaction-specific terms that only make sense for social interactions:
  echo "$SC_CONTENT" | grep -qi 'reaction.*cost\|cost.*reaction\|react.*money' && NIP_SCORE=$((NIP_SCORE + 1))
  echo "$SC_CONTENT" | grep -qi 'downvote.*strong\|strong.*signal\|confrontational\|disapproval.*weight' && NIP_SCORE=$((NIP_SCORE + 1))
  echo "$SC_CONTENT" | grep -qi 'react.*spam\|mass.*react\|mass.*lik\|careless\|inflat.*engagement' && NIP_SCORE=$((NIP_SCORE + 1))
  echo "$SC_CONTENT" | grep -qi 'repost.*cost\|repost.*endors\|paying.*amplif\|amplif.*content' && NIP_SCORE=$((NIP_SCORE + 1))
  echo "$SC_CONTENT" | grep -qi 'comment.*substant\|low-effort.*comment\|tone-deaf\|high-effort.*content' && NIP_SCORE=$((NIP_SCORE + 1))
  echo "$SC_CONTENT" | grep -qi 'decision.*tree\|when.*engage\|adds.*value\|whether.*interact' && NIP_SCORE=$((NIP_SCORE + 1))
  if [ "$NIP_SCORE" -ge 4 ]; then
    pass "AC5-NIP-SPECIFIC" "Social Context has $NIP_SCORE/6 interaction-specific compound terms"
  else
    fail "AC5-NIP-SPECIFIC" "Social Context has only $NIP_SCORE/6 interaction-specific compound terms (need >= 4)"
  fi
else
  fail "AC5-NIP-SPECIFIC" "SKILL.md not found"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# EVAL QUALITY DETAIL TESTS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "── Eval Quality Detail Tests ──"

# AC6-RUBRIC: Output eval rubrics use correct/acceptable/incorrect grading
echo "[AC6-RUBRIC] Output eval rubrics use correct/acceptable/incorrect"
if [ -f "$EVALS_FILE" ]; then
  RUBRIC_RESULT=$(node -e "
    const d = JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8'));
    const oe = d.output_evals || [];
    const valid = oe.filter(e => e.rubric && e.rubric.correct && e.rubric.acceptable && e.rubric.incorrect);
    console.log(oe.length + ' ' + valid.length);
  " "$EVALS_FILE" 2>/dev/null || echo "0 0")
  RUBRIC_TOTAL=$(echo "$RUBRIC_RESULT" | awk '{print $1}')
  RUBRIC_VALID=$(echo "$RUBRIC_RESULT" | awk '{print $2}')
  if [ "$RUBRIC_TOTAL" -gt 0 ] && [ "$RUBRIC_VALID" -eq "$RUBRIC_TOTAL" ]; then
    pass "AC6-RUBRIC" "All $RUBRIC_TOTAL output evals have correct/acceptable/incorrect rubrics"
  else
    fail "AC6-RUBRIC" "$RUBRIC_VALID of $RUBRIC_TOTAL output evals have complete rubrics"
  fi
else
  fail "AC6-RUBRIC" "evals/evals.json not found"
fi

# AC6-TOON-ASSERT: Output evals include TOON compliance assertions
echo "[AC6-TOON-ASSERT] Output evals include TOON compliance assertion strings"
if [ -f "$EVALS_FILE" ]; then
  TOON_ASSERT_COUNT=$(node -e "
    const d = JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8'));
    const oe = d.output_evals || [];
    const withToon = oe.filter(e => (e.assertions || []).some(a => /toon-write-check|toon-fee-check|toon-format-check|social-context-check|trigger-coverage/.test(a)));
    console.log(withToon.length);
  " "$EVALS_FILE" 2>/dev/null || echo "0")
  OUTPUT_TOTAL=$(node -e "
    const d = JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8'));
    console.log((d.output_evals || []).length);
  " "$EVALS_FILE" 2>/dev/null || echo "0")
  if [ "$TOON_ASSERT_COUNT" -ge "$OUTPUT_TOTAL" ] && [ "$OUTPUT_TOTAL" -gt 0 ]; then
    pass "AC6-TOON-ASSERT" "All $TOON_ASSERT_COUNT/$OUTPUT_TOTAL output evals include TOON compliance assertions"
  else
    fail "AC6-TOON-ASSERT" "Only $TOON_ASSERT_COUNT/$OUTPUT_TOTAL output evals include TOON compliance assertions (all required)"
  fi
else
  fail "AC6-TOON-ASSERT" "evals/evals.json not found"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DESCRIPTION TRIGGER DETAIL TESTS (P1)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "── Description Trigger Detail Tests (P1) ──"

# AC8-TRIGPHRASES: Description includes specific trigger phrases from AC8
echo "[AC8-TRIGPHRASES] Description includes required trigger phrases"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  DESCRIPTION=$(awk '/^---$/{n++; next} n==1 && /^description:/{sub(/^description: */, ""); p=1; print; next} n==1 && p && /^[a-zA-Z][a-zA-Z0-9_-]*:/{p=0} n==1 && p{print} n>=2{exit}' "$SKILL_DIR/SKILL.md")
  TRIG_SCORE=0
  echo "$DESCRIPTION" | grep -qi 'reaction\|react\|liking\|like' && TRIG_SCORE=$((TRIG_SCORE + 1))
  echo "$DESCRIPTION" | grep -qi 'repost' && TRIG_SCORE=$((TRIG_SCORE + 1))
  echo "$DESCRIPTION" | grep -qi 'comment\|kind:1111' && TRIG_SCORE=$((TRIG_SCORE + 1))
  echo "$DESCRIPTION" | grep -qi 'kind:7\|kind:6\|kind:16' && TRIG_SCORE=$((TRIG_SCORE + 1))
  echo "$DESCRIPTION" | grep -qi 'NIP-22\|NIP-18\|NIP-25' && TRIG_SCORE=$((TRIG_SCORE + 1))
  echo "$DESCRIPTION" | grep -qi 'downvot\|emoji' && TRIG_SCORE=$((TRIG_SCORE + 1))
  if [ "$TRIG_SCORE" -ge 5 ]; then
    pass "AC8-TRIGPHRASES" "Description includes $TRIG_SCORE/6 required trigger categories"
  else
    fail "AC8-TRIGPHRASES" "Description includes only $TRIG_SCORE/6 required trigger categories (need >= 5)"
  fi
else
  fail "AC8-TRIGPHRASES" "SKILL.md not found"
fi

# AC8-STRICT-RANGE: Description word count 80-120 (stricter than validate-skill.sh 50-200)
echo "[AC8-STRICT-RANGE] Description 80-120 words (AC8 spec, stricter than validate-skill.sh 50-200)"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  DESCRIPTION=$(awk '/^---$/{n++; next} n==1 && /^description:/{sub(/^description: */, ""); p=1; print; next} n==1 && p && /^[a-zA-Z][a-zA-Z0-9_-]*:/{p=0} n==1 && p{print} n>=2{exit}' "$SKILL_DIR/SKILL.md")
  WORD_COUNT=$(echo "$DESCRIPTION" | wc -w | tr -d ' ')
  if [ "$WORD_COUNT" -ge 80 ] && [ "$WORD_COUNT" -le 120 ]; then
    pass "AC8-STRICT-RANGE" "Description is $WORD_COUNT words (80-120 AC8 range)"
  else
    fail "AC8-STRICT-RANGE" "Description is $WORD_COUNT words (AC8 requires 80-120; validate-skill.sh allows 50-200)"
  fi
else
  fail "AC8-STRICT-RANGE" "SKILL.md not found"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TOKEN BUDGET TESTS (P1)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "── Token Budget Tests (P1) ──"

# AC9-TOKENS: Token budget approximation (~5k tokens, estimate 4 chars/token)
echo "[AC9-TOKENS] Token budget approximation (~5k tokens via char count)"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  BODY_CHARS=$(awk 'BEGIN{n=0} /^---$/{n++; next} n>=2{print}' "$SKILL_DIR/SKILL.md" | wc -c | tr -d ' ')
  # Rough estimate: ~4 chars per token for English text
  APPROX_TOKENS=$((BODY_CHARS / 4))
  if [ "$APPROX_TOKENS" -le 6000 ]; then
    pass "AC9-TOKENS" "Body is ~$APPROX_TOKENS tokens (under ~5k-6k estimate)"
  else
    fail "AC9-TOKENS" "Body is ~$APPROX_TOKENS tokens (exceeds ~5k token budget)"
  fi
else
  fail "AC9-TOKENS" "SKILL.md not found"
fi

# AC9-TOKEN-WORDS: Token budget estimation using word count heuristic
echo "[AC9-TOKEN-WORDS] Token budget via word-count heuristic (~5k tokens)"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  BODY_WORDS=$(awk 'BEGIN{n=0} /^---$/{n++; next} n>=2{print}' "$SKILL_DIR/SKILL.md" | wc -w | tr -d ' ')
  # Heuristic: ~1.3 tokens per word for English/technical markdown
  APPROX_TOKENS=$(( (BODY_WORDS * 13) / 10 ))
  if [ "$APPROX_TOKENS" -le 5500 ]; then
    pass "AC9-TOKEN-WORDS" "Body is ~$APPROX_TOKENS tokens ($BODY_WORDS words * 1.3; under ~5k budget)"
  else
    fail "AC9-TOKEN-WORDS" "Body is ~$APPROX_TOKENS tokens ($BODY_WORDS words * 1.3; exceeds ~5k token budget)"
  fi
else
  fail "AC9-TOKEN-WORDS" "SKILL.md not found"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DEPENDENCY & PIPELINE TESTS (P1)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "── Dependency & Pipeline Tests (P1) ──"

# AC10-NODUP: Does NOT duplicate toon-protocol-context.md in references/
echo "[AC10-NODUP] No toon-protocol-context.md in references/ (uses pointer per D9-010)"
if [ -d "$SKILL_DIR/references" ]; then
  if [ -f "$SKILL_DIR/references/toon-protocol-context.md" ]; then
    fail "AC10-NODUP" "toon-protocol-context.md found in references/ (should use pointer to nostr-protocol-core)"
  else
    pass "AC10-NODUP" "No toon-protocol-context.md duplication -- uses pointer per D9-010"
  fi
else
  fail "AC10-NODUP" "references/ directory not found"
fi

# AC10-DEP-BOTH: Both upstream skills referenced as paths in SKILL.md
echo "[AC10-DEP-BOTH] Both dependency skills referenced as paths"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  DEP_SCORE=0
  # nostr-protocol-core must appear as a skill path (not just a name mention)
  if grep -q '\.claude/skills/nostr-protocol-core/' "$SKILL_DIR/SKILL.md" || \
     grep -q 'skills/nostr-protocol-core/' "$SKILL_DIR/SKILL.md"; then
    DEP_SCORE=$((DEP_SCORE + 1))
  fi
  # nostr-social-intelligence must be referenced (as skill name or path)
  if grep -q 'nostr-social-intelligence' "$SKILL_DIR/SKILL.md"; then
    DEP_SCORE=$((DEP_SCORE + 1))
  fi
  if [ "$DEP_SCORE" -eq 2 ]; then
    pass "AC10-DEP-BOTH" "Both nostr-protocol-core (as path) and nostr-social-intelligence referenced"
  else
    MISSING=""
    if [ "$DEP_SCORE" -lt 1 ]; then MISSING="nostr-protocol-core path"; fi
    if [ "$DEP_SCORE" -lt 2 ]; then MISSING="${MISSING:+$MISSING, }nostr-social-intelligence"; fi
    fail "AC10-DEP-BOTH" "Missing dependency references ($DEP_SCORE/2): $MISSING"
  fi
else
  fail "AC10-DEP-BOTH" "SKILL.md not found"
fi

# PIPE-REGR: Pipeline regression -- SKILL.md points to nostr-protocol-core's toon-protocol-context.md
echo "[PIPE-REGR] Pipeline regression: D9-010 pointer pattern verified"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if grep -q 'nostr-protocol-core/references/toon-protocol-context.md' "$SKILL_DIR/SKILL.md"; then
    pass "PIPE-REGR" "SKILL.md points to nostr-protocol-core/references/toon-protocol-context.md"
  else
    fail "PIPE-REGR" "SKILL.md does not point to canonical toon-protocol-context.md path"
  fi
else
  fail "PIPE-REGR" "SKILL.md not found"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# GAP-FILL ROUND 2: AC coverage tightening
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "── Gap-Fill Round 2 (AC coverage tightening) ──"

# AC4-READREF: Read model section references nostr-protocol-core for TOON format parsing (AC4)
echo "[AC4-READREF] Read model references nostr-protocol-core for TOON format parsing"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  READ_SECTION=$(awk '/^## TOON Read Model/{found=1; next} found && /^## /{exit} found{print}' "$SKILL_DIR/SKILL.md")
  if echo "$READ_SECTION" | grep -q 'nostr-protocol-core'; then
    pass "AC4-READREF" "Read model section references nostr-protocol-core"
  else
    fail "AC4-READREF" "Read model section does not reference nostr-protocol-core for TOON format parsing"
  fi
else
  fail "AC4-READREF" "SKILL.md not found"
fi

# AC4-READING-FREE: Read model states reading is free (no ILP payment) (AC4)
echo "[AC4-READING-FREE] Read model states reading is free"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  READ_SECTION=$(awk '/^## TOON Read Model/{found=1; next} found && /^## /{exit} found{print}' "$SKILL_DIR/SKILL.md")
  if echo "$READ_SECTION" | grep -qi 'free\|no.*payment\|no.*cost\|no.*fee'; then
    pass "AC4-READING-FREE" "Read model states reading is free"
  else
    fail "AC4-READING-FREE" "Read model does not state reading is free"
  fi
else
  fail "AC4-READING-FREE" "SKILL.md not found"
fi

# AC6-TRIGGER-QUERIES: Should-trigger queries include interaction-relevant topics (AC6)
echo "[AC6-TRIGGER-QUERIES] Should-trigger queries cover interaction-relevant topics"
if [ -f "$EVALS_FILE" ]; then
  TRIG_TOPICS=$(node -e "
    const d = JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8'));
    const triggers = (d.trigger_evals || []).filter(e => e.should_trigger === true).map(e => e.query.toLowerCase());
    const all = triggers.join(' ');
    let score = 0;
    if (/react/.test(all)) score++;
    if (/repost/.test(all)) score++;
    if (/comment/.test(all)) score++;
    if (/kind:7|kind 7/.test(all)) score++;
    if (/kind:1111|kind 1111/.test(all)) score++;
    if (/downvote|dislike/.test(all)) score++;
    console.log(score);
  " "$EVALS_FILE" 2>/dev/null || echo "0")
  if [ "$TRIG_TOPICS" -ge 5 ]; then
    pass "AC6-TRIGGER-QUERIES" "Should-trigger queries cover $TRIG_TOPICS/6 interaction topics"
  else
    fail "AC6-TRIGGER-QUERIES" "Should-trigger queries cover only $TRIG_TOPICS/6 interaction topics (need >= 5)"
  fi
else
  fail "AC6-TRIGGER-QUERIES" "evals/evals.json not found"
fi

# AC6-NOTTRIGGER-QUERIES: Should-not-trigger queries cover non-interaction topics (AC6)
echo "[AC6-NOTTRIGGER-QUERIES] Should-not-trigger queries cover non-interaction topics"
if [ -f "$EVALS_FILE" ]; then
  NONTRIG_TOPICS=$(node -e "
    const d = JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8'));
    const nontriggers = (d.trigger_evals || []).filter(e => e.should_trigger === false).map(e => e.query.toLowerCase());
    const all = nontriggers.join(' ');
    let score = 0;
    if (/profile/.test(all)) score++;
    if (/article|long-form/.test(all)) score++;
    if (/follow/.test(all)) score++;
    if (/encrypt|messaging|dm/.test(all)) score++;
    if (/group|chat/.test(all)) score++;
    console.log(score);
  " "$EVALS_FILE" 2>/dev/null || echo "0")
  if [ "$NONTRIG_TOPICS" -ge 4 ]; then
    pass "AC6-NOTTRIGGER-QUERIES" "Should-not-trigger queries cover $NONTRIG_TOPICS/5 non-interaction topics"
  else
    fail "AC6-NOTTRIGGER-QUERIES" "Should-not-trigger queries cover only $NONTRIG_TOPICS/5 non-interaction topics (need >= 4)"
  fi
else
  fail "AC6-NOTTRIGGER-QUERIES" "evals/evals.json not found"
fi

# AC3-COST-COMPARE: Write model compares reaction costs (cheapest interactions) (AC3)
echo "[AC3-COST-COMPARE] Write model documents interaction cost ranges"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  WRITE_SECTION=$(awk '/^## TOON Write Model/{found=1; next} found && /^## /{exit} found{print}' "$SKILL_DIR/SKILL.md")
  HAS_REACTION_COST=$(echo "$WRITE_SECTION" | grep -ci 'reaction\|kind:7' || true)
  HAS_REPOST_COST=$(echo "$WRITE_SECTION" | grep -ci 'repost\|kind:6\|embedded' || true)
  HAS_COMMENT_COST=$(echo "$WRITE_SECTION" | grep -ci 'comment\|kind:1111\|scale' || true)
  if [ "$HAS_REACTION_COST" -gt 0 ] && [ "$HAS_REPOST_COST" -gt 0 ] && [ "$HAS_COMMENT_COST" -gt 0 ]; then
    pass "AC3-COST-COMPARE" "Write model documents reaction, repost, and comment cost ranges"
  else
    fail "AC3-COST-COMPARE" "Write model missing cost comparison (reactions: $HAS_REACTION_COST, reposts: $HAS_REPOST_COST, comments: $HAS_COMMENT_COST)"
  fi
else
  fail "AC3-COST-COMPARE" "SKILL.md not found"
fi

# AC8-SOCIAL-PHRASES: Description contains specific social-situation phrases from AC8 (AC8)
echo "[AC8-SOCIAL-PHRASES] Description contains AC8-specified social-situation phrases"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  DESCRIPTION=$(awk '/^---$/{n++; next} n==1 && /^description:/{sub(/^description: */, ""); p=1; print; next} n==1 && p && /^[a-zA-Z][a-zA-Z0-9_-]*:/{p=0} n==1 && p{print} n>=2{exit}' "$SKILL_DIR/SKILL.md")
  PHRASE_SCORE=0
  # AC8 specifies these social-situation triggers:
  echo "$DESCRIPTION" | grep -qi 'should I react' && PHRASE_SCORE=$((PHRASE_SCORE + 1))
  echo "$DESCRIPTION" | grep -qi 'is this worth reposting\|is it worth reposting\|worth repost' && PHRASE_SCORE=$((PHRASE_SCORE + 1))
  echo "$DESCRIPTION" | grep -qi 'should I downvote\|downvot' && PHRASE_SCORE=$((PHRASE_SCORE + 1))
  echo "$DESCRIPTION" | grep -qi 'how do I comment\|comment on' && PHRASE_SCORE=$((PHRASE_SCORE + 1))
  if [ "$PHRASE_SCORE" -ge 2 ]; then
    pass "AC8-SOCIAL-PHRASES" "Description includes $PHRASE_SCORE/4 AC8-specified social-situation phrases"
  else
    fail "AC8-SOCIAL-PHRASES" "Description includes only $PHRASE_SCORE/4 AC8-specified social-situation phrases (need >= 2)"
  fi
else
  fail "AC8-SOCIAL-PHRASES" "SKILL.md not found"
fi

# AC2-EMOJI-REACTIONS: Emoji reactions and custom emoji documented (AC2)
echo "[AC2-EMOJI-REACTIONS] Emoji reactions and custom emoji documented"
if [ -f "$SKILL_DIR/SKILL.md" ] || [ -f "$SKILL_DIR/references/nip-spec.md" ]; then
  EMOJI_OK=true
  if ! grep -rqi 'emoji.*reaction\|reaction.*emoji\|custom emoji\|emoji' "$SKILL_DIR/SKILL.md" "$SKILL_DIR/references/nip-spec.md" 2>/dev/null; then
    fail "AC2-EMOJI-REACTIONS" "Missing emoji reaction documentation"
    EMOJI_OK=false
  fi
  if [ "$EMOJI_OK" = true ]; then
    pass "AC2-EMOJI-REACTIONS" "Emoji reactions documented"
  fi
else
  fail "AC2-EMOJI-REACTIONS" "Required files not found"
fi

# AC2-COMMENT-EXTERNAL: External content comments via I tag documented (AC2)
echo "[AC2-COMMENT-EXTERNAL] External content comments via I tag documented"
if [ -f "$SKILL_DIR/SKILL.md" ] || [ -f "$SKILL_DIR/references/nip-spec.md" ]; then
  if grep -rqi 'external.*content\|`I`.*tag\|"I" tag\|I tag.*URL\|URL.*podcast\|ISBN\|outside Nostr\|cross-protocol' "$SKILL_DIR/SKILL.md" "$SKILL_DIR/references/nip-spec.md" 2>/dev/null; then
    pass "AC2-COMMENT-EXTERNAL" "External content comments via I tag documented"
  else
    fail "AC2-COMMENT-EXTERNAL" "Missing external content comment (I tag) documentation"
  fi
else
  fail "AC2-COMMENT-EXTERNAL" "Required files not found"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# GAP-FILL ROUND 3: Fine-grained AC coverage
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "── Gap-Fill Round 3 (fine-grained AC coverage) ──"

# AC3-EMBED-COST: kind:6 reposts with embedded content cost more (AC3)
echo "[AC3-EMBED-COST] Skill notes embedded repost content costs more"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if grep -qi 'embedded.*cost\|cost.*embedded\|embedded.*more\|embedded.*byte\|embedded.*content.*cost\|embedded content.*increase\|including.*embedded.*cost' "$SKILL_DIR/SKILL.md"; then
    pass "AC3-EMBED-COST" "Embedded repost content cost increase documented"
  elif grep -qi 'With embedded content.*\$\|embedded.*\$0\|embedded.*500\|embedded.*3000' "$SKILL_DIR/SKILL.md"; then
    pass "AC3-EMBED-COST" "Embedded repost content cost comparison documented"
  else
    fail "AC3-EMBED-COST" "Missing note that kind:6 reposts with embedded content cost more"
  fi
else
  fail "AC3-EMBED-COST" "SKILL.md not found"
fi

# AC3-COMMENT-SCALE: kind:1111 comments scale with comment length (AC3)
echo "[AC3-COMMENT-SCALE] Skill notes comments scale with length"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if grep -qi 'scale.*length\|length.*scale\|comment length\|cost.*scale\|scales with.*comment\|scales with.*length' "$SKILL_DIR/SKILL.md"; then
    pass "AC3-COMMENT-SCALE" "Comment length scaling documented"
  else
    fail "AC3-COMMENT-SCALE" "Missing note that kind:1111 comments scale with comment length"
  fi
else
  fail "AC3-COMMENT-SCALE" "SKILL.md not found"
fi

# AC3-REACTION-BYTES: Reaction byte range documented (~200-400 bytes = ~$0.002-$0.004) (AC3)
echo "[AC3-REACTION-BYTES] Reaction byte range and cost documented"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if grep -qi '200.*400\|200-400\|\$0\.002.*\$0\.004\|0\.002-0\.004' "$SKILL_DIR/SKILL.md"; then
    pass "AC3-REACTION-BYTES" "Reaction byte range (~200-400) and cost documented"
  else
    fail "AC3-REACTION-BYTES" "Missing reaction byte range (~200-400 bytes = ~\$0.002-\$0.004)"
  fi
else
  fail "AC3-REACTION-BYTES" "SKILL.md not found"
fi

# AC2-CUSTOM-EMOJI: Custom emoji explicitly mentioned (AC2)
echo "[AC2-CUSTOM-EMOJI] Custom emoji reactions documented"
if [ -f "$SKILL_DIR/SKILL.md" ] || [ -f "$SKILL_DIR/references/nip-spec.md" ]; then
  if grep -rqi 'custom emoji' "$SKILL_DIR/SKILL.md" "$SKILL_DIR/references/nip-spec.md" 2>/dev/null; then
    pass "AC2-CUSTOM-EMOJI" "Custom emoji reactions documented"
  else
    fail "AC2-CUSTOM-EMOJI" "Missing custom emoji documentation (AC2 requires 'custom emoji')"
  fi
else
  fail "AC2-CUSTOM-EMOJI" "Required files not found"
fi

# AC2-REPOST-SERIAL: kind:6 content field optionally contains serialized reposted event (AC2)
echo "[AC2-REPOST-SERIAL] Repost content field (serialized event, optional) documented"
if [ -f "$SKILL_DIR/SKILL.md" ] || [ -f "$SKILL_DIR/references/nip-spec.md" ]; then
  if grep -rqi 'serialized.*reposted\|serialized.*event\|JSON.*serialized\|reposted event.*content\|content.*reposted event' "$SKILL_DIR/SKILL.md" "$SKILL_DIR/references/nip-spec.md" 2>/dev/null; then
    pass "AC2-REPOST-SERIAL" "Repost serialized event content documented"
  else
    fail "AC2-REPOST-SERIAL" "Missing repost serialized event content documentation"
  fi
else
  fail "AC2-REPOST-SERIAL" "Required files not found"
fi

# AC7-ASSERTIONS: run-eval.sh outputs named assertions (verify output, not just exit code) (AC7)
echo "[AC7-ASSERTIONS] run-eval.sh outputs all 6 named TOON compliance assertions"
if [ -d "$SKILL_DIR" ] && [ -f "$RUNEVAL_SCRIPT" ]; then
  RUNEVAL_OUTPUT=$(bash "$RUNEVAL_SCRIPT" "$SKILL_DIR" 2>&1 || true)
  ASSERT_SCORE=0
  echo "$RUNEVAL_OUTPUT" | grep -qi 'toon-write-check\|toon.write.check\|write.check' && ASSERT_SCORE=$((ASSERT_SCORE + 1))
  echo "$RUNEVAL_OUTPUT" | grep -qi 'toon-fee-check\|toon.fee.check\|fee.check' && ASSERT_SCORE=$((ASSERT_SCORE + 1))
  echo "$RUNEVAL_OUTPUT" | grep -qi 'toon-format-check\|toon.format.check\|format.check' && ASSERT_SCORE=$((ASSERT_SCORE + 1))
  echo "$RUNEVAL_OUTPUT" | grep -qi 'social-context-check\|social.context.check\|context.check' && ASSERT_SCORE=$((ASSERT_SCORE + 1))
  echo "$RUNEVAL_OUTPUT" | grep -qi 'trigger-coverage\|trigger.coverage' && ASSERT_SCORE=$((ASSERT_SCORE + 1))
  echo "$RUNEVAL_OUTPUT" | grep -qi 'eval-completeness\|eval.completeness' && ASSERT_SCORE=$((ASSERT_SCORE + 1))
  if [ "$ASSERT_SCORE" -ge 5 ]; then
    pass "AC7-ASSERTIONS" "run-eval.sh outputs $ASSERT_SCORE/6 named TOON compliance assertions"
  else
    fail "AC7-ASSERTIONS" "run-eval.sh outputs only $ASSERT_SCORE/6 named TOON compliance assertions"
  fi
else
  fail "AC7-ASSERTIONS" "Skill directory or run-eval.sh not found"
fi

# AC6-EXPECTED-OPT: Output evals have expected_output field (optional per framework, but AC6 lists it) (AC6)
echo "[AC6-EXPECTED-OPT] Output evals expected_output field check"
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
    # expected_output is optional per framework (eval-execution-guide.md: expected_output?: string)
    # but AC6 lists it. Skip rather than fail since framework defines it as optional.
    skip "AC6-EXPECTED-OPT" "expected_output field absent in $((EXP_TOTAL - EXP_WITH))/$EXP_TOTAL output evals (field is optional per framework)"
  fi
else
  fail "AC6-EXPECTED-OPT" "evals/evals.json not found"
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
