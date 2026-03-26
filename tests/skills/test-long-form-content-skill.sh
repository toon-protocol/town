#!/usr/bin/env bash
# test-long-form-content-skill.sh — ATDD acceptance tests for Story 9.5: Long-form Content Skill
# TDD RED PHASE: All tests will FAIL until the skill is implemented.
#
# Usage: ./tests/skills/test-long-form-content-skill.sh
# Exit 0 = all checks pass, 1 = at least one check failed
#
# Test IDs map to AC-to-Test Mapping in atdd-checklist-9-5.md:
#   STRUCT-A, STRUCT-B, STRUCT-B2, STRUCT-C, STRUCT-D
#   TOON-A, TOON-B, TOON-C, TOON-D, TOON-ALL-1, TOON-ALL-2
#   EVAL-A, EVAL-B, EVAL-A2, EVAL-B2, EVAL-C
#   TRIG-A, TRIG-B
#   DEP-A, DEP-B
#   CLEAN-A
# Gap-fill tests (added to cover remaining AC criteria):
#   AC1-NAME, AC2-KIND30023, AC2-DTAG, AC2-MARKDOWN, AC2-TAGS,
#   AC2-LIFECYCLE, AC2-NIP14, AC2-SUBJECT-VS-T,
#   AC2-TOONEXT, AC2-SCENARIOS,
#   AC3-CLIENT, AC3-FEEREF, AC3-REPLACEABLE, AC3-WRITEMODEL,
#   AC4-DECODER, AC4-FILTER, AC4-REFREADS,
#   AC5-INVESTMENT, AC5-QUALITY, AC5-UPDATES, AC5-SUBJECT,
#   AC5-SUMMARY, AC5-SUBST, AC5-NIP-SPECIFIC,
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
#   AC5-STRUCTURE,
#   AC2-REPLACEABLE-SPEC
# AC11 (manual / pipeline):
#   BASE-A (skipped -- requires manual pipeline Step 8)
#
# Total: 63 tests (62 automated + 1 skipped)
# Note: STRUCT-E removed as duplicate of AC8-STRICT-RANGE

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILL_DIR="$PROJECT_ROOT/.claude/skills/long-form-content"
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

echo "=== ATDD Acceptance Tests: Story 9.5 Long-form Content Skill ==="
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

# STRUCT-E removed: was duplicate of AC8-STRICT-RANGE (both check description word count 80-120)

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CONTENT TESTS — NIP COVERAGE (P0)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "── Content Tests — NIP Coverage (P0) ──"

# EVAL-A: SKILL.md body mentions kind:30023, NIP-23, NIP-14, d tag, subject tag (AC2)
echo "[EVAL-A] NIP coverage in SKILL.md"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  NIP_OK=true
  for TERM in "kind:30023" "NIP-23" "NIP-14"; do
    if ! grep -q "$TERM" "$SKILL_DIR/SKILL.md"; then
      fail "EVAL-A" "SKILL.md missing coverage for $TERM"
      NIP_OK=false
    fi
  done
  if [ "$NIP_OK" = true ]; then
    pass "EVAL-A" "SKILL.md covers kind:30023, NIP-23, NIP-14"
  fi
else
  fail "EVAL-A" "Cannot check NIP coverage -- SKILL.md not found"
fi

# EVAL-B: references/nip-spec.md covers kind:30023 structure, d tag, tags, NIP-14 subject (AC2)
echo "[EVAL-B] NIP spec reference file coverage"
if [ -f "$SKILL_DIR/references/nip-spec.md" ]; then
  SPEC_OK=true
  # Check for kind:30023 / long-form content
  if ! grep -qi 'kind:30023\|long-form\|long.form' "$SKILL_DIR/references/nip-spec.md"; then
    fail "EVAL-B" "nip-spec.md missing kind:30023/long-form content coverage"
    SPEC_OK=false
  fi
  # Check for d tag / parameterized replaceable
  if ! grep -qi '"d"\|d tag\|parameterized replaceable' "$SKILL_DIR/references/nip-spec.md"; then
    fail "EVAL-B" "nip-spec.md missing d tag / parameterized replaceable coverage"
    SPEC_OK=false
  fi
  # Check for article tags (title, summary, published_at)
  if ! grep -qi 'title\|summary\|published_at' "$SKILL_DIR/references/nip-spec.md"; then
    fail "EVAL-B" "nip-spec.md missing article tag coverage (title/summary/published_at)"
    SPEC_OK=false
  fi
  # Check for NIP-14 subject tag
  if ! grep -qi 'subject\|NIP-14' "$SKILL_DIR/references/nip-spec.md"; then
    fail "EVAL-B" "nip-spec.md missing NIP-14 subject tag coverage"
    SPEC_OK=false
  fi
  if [ "$SPEC_OK" = true ]; then
    pass "EVAL-B" "nip-spec.md covers kind:30023, d tag, article tags, NIP-14 subject"
  fi
else
  fail "EVAL-B" "references/nip-spec.md not found"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CONTENT TESTS — SOCIAL CONTEXT (P1)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "── Content Tests — Social Context (P1) ──"

# TOON-D: Social Context is content-publishing-specific (AC5)
echo "[TOON-D] Social Context is content-publishing-specific"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  SC_CONTENT=$(awk '/^## Social Context/{found=1; next} found && /^## /{exit} found{print}' "$SKILL_DIR/SKILL.md")
  CONTENT_OK=true
  # Must mention articles/long-form content investment
  if ! echo "$SC_CONTENT" | grep -qi 'article\|long-form\|long.form'; then
    fail "TOON-D" "Social Context missing article/long-form content references"
    CONTENT_OK=false
  fi
  # Must mention quality over quantity
  if ! echo "$SC_CONTENT" | grep -qi 'quality'; then
    fail "TOON-D" "Social Context missing quality references"
    CONTENT_OK=false
  fi
  # Must mention summaries
  if ! echo "$SC_CONTENT" | grep -qi 'summary\|summaries'; then
    fail "TOON-D" "Social Context missing summary references"
    CONTENT_OK=false
  fi
  # Must mention cost/payment/economics
  if ! echo "$SC_CONTENT" | grep -qi 'cost\|pay\|money\|economic\|fee\|byte'; then
    fail "TOON-D" "Social Context missing economics references"
    CONTENT_OK=false
  fi
  if [ "$CONTENT_OK" = true ]; then
    pass "TOON-D" "Social Context is content-publishing-specific (articles, quality, summaries, economics)"
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
  if ! echo "$DESCRIPTION" | grep -qi 'kind:30023\|NIP-23\|NIP-14\|article\|long-form\|subject tag'; then
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
  if echo "$DESCRIPTION" | grep -qi 'should I\|when to\|how do I\|how to\|how much\|how long\|is this worth\|what makes'; then
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

# AC1-NAME: Frontmatter name field is exactly "long-form-content"
echo "[AC1-NAME] Frontmatter name field value"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  NAME_VALUE=$(awk '/^---$/{n++; next} n==1 && /^name:/{sub(/^name: */, ""); print; exit}' "$SKILL_DIR/SKILL.md")
  if [ "$NAME_VALUE" = "long-form-content" ]; then
    pass "AC1-NAME" "Frontmatter name is 'long-form-content'"
  else
    fail "AC1-NAME" "Frontmatter name is '$NAME_VALUE' (expected 'long-form-content')"
  fi
else
  fail "AC1-NAME" "SKILL.md not found"
fi

# AC2-KIND30023: SKILL.md documents kind:30023 as parameterized replaceable event
echo "[AC2-KIND30023] kind:30023 documented as parameterized replaceable"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if grep -q 'kind:30023' "$SKILL_DIR/SKILL.md" && grep -qi 'parameterized replaceable' "$SKILL_DIR/SKILL.md"; then
    pass "AC2-KIND30023" "kind:30023 documented as parameterized replaceable event"
  else
    fail "AC2-KIND30023" "Missing kind:30023 or parameterized replaceable semantics in SKILL.md"
  fi
else
  fail "AC2-KIND30023" "SKILL.md not found"
fi

# AC2-DTAG: d tag documented as article identifier
echo "[AC2-DTAG] d tag documented as article identifier"
if [ -f "$SKILL_DIR/SKILL.md" ] || [ -f "$SKILL_DIR/references/nip-spec.md" ]; then
  if grep -rqi '"d"\|d tag\|`d` tag' "$SKILL_DIR/SKILL.md" "$SKILL_DIR/references/nip-spec.md" 2>/dev/null; then
    pass "AC2-DTAG" "d tag documented as article identifier"
  else
    fail "AC2-DTAG" "d tag not documented"
  fi
else
  fail "AC2-DTAG" "Required files not found"
fi

# AC2-MARKDOWN: Content field uses markdown format documented
echo "[AC2-MARKDOWN] Markdown content format documented"
if [ -f "$SKILL_DIR/SKILL.md" ] || [ -f "$SKILL_DIR/references/nip-spec.md" ]; then
  if grep -rqi 'markdown' "$SKILL_DIR/SKILL.md" "$SKILL_DIR/references/nip-spec.md" 2>/dev/null; then
    pass "AC2-MARKDOWN" "Markdown content format documented"
  else
    fail "AC2-MARKDOWN" "Markdown content format not documented"
  fi
else
  fail "AC2-MARKDOWN" "Required files not found"
fi

# AC2-TAGS: Article tags documented (title, summary, image, published_at)
echo "[AC2-TAGS] Article tags documented (title, summary, image, published_at)"
if [ -f "$SKILL_DIR/SKILL.md" ] || [ -f "$SKILL_DIR/references/nip-spec.md" ]; then
  TAGS_OK=true
  for TAG in "title" "summary" "image" "published_at"; do
    if ! grep -rq "$TAG" "$SKILL_DIR/SKILL.md" "$SKILL_DIR/references/nip-spec.md" 2>/dev/null; then
      fail "AC2-TAGS" "Missing article tag documentation: $TAG"
      TAGS_OK=false
    fi
  done
  if [ "$TAGS_OK" = true ]; then
    pass "AC2-TAGS" "All article tags documented (title, summary, image, published_at)"
  fi
else
  fail "AC2-TAGS" "Required files not found"
fi

# AC2-LIFECYCLE: Article lifecycle documented (create, update, draft/published)
echo "[AC2-LIFECYCLE] Article lifecycle documented (create, update, draft)"
if [ -f "$SKILL_DIR/SKILL.md" ] || [ -f "$SKILL_DIR/references/nip-spec.md" ]; then
  LIFE_OK=true
  if ! grep -rqi 'creat.*article\|new article\|publish.*article\|article.*creation' "$SKILL_DIR/SKILL.md" "$SKILL_DIR/references/nip-spec.md" 2>/dev/null; then
    fail "AC2-LIFECYCLE" "Missing article creation documentation"
    LIFE_OK=false
  fi
  if ! grep -rqi 'updat.*article\|replac.*article\|article.*update\|same.*d.*tag' "$SKILL_DIR/SKILL.md" "$SKILL_DIR/references/nip-spec.md" 2>/dev/null; then
    fail "AC2-LIFECYCLE" "Missing article update documentation"
    LIFE_OK=false
  fi
  if ! grep -rqi 'draft\|published_at' "$SKILL_DIR/SKILL.md" "$SKILL_DIR/references/nip-spec.md" 2>/dev/null; then
    fail "AC2-LIFECYCLE" "Missing draft/published state documentation"
    LIFE_OK=false
  fi
  if [ "$LIFE_OK" = true ]; then
    pass "AC2-LIFECYCLE" "Article lifecycle documented (create, update, draft/published)"
  fi
else
  fail "AC2-LIFECYCLE" "Required files not found"
fi

# AC2-NIP14: NIP-14 subject tag format documented
echo "[AC2-NIP14] NIP-14 subject tag format documented"
if [ -f "$SKILL_DIR/SKILL.md" ] || [ -f "$SKILL_DIR/references/nip-spec.md" ]; then
  if grep -rqi 'subject.*tag\|NIP-14\|"subject"' "$SKILL_DIR/SKILL.md" "$SKILL_DIR/references/nip-spec.md" 2>/dev/null; then
    pass "AC2-NIP14" "NIP-14 subject tag documented"
  else
    fail "AC2-NIP14" "NIP-14 subject tag not documented"
  fi
else
  fail "AC2-NIP14" "Required files not found"
fi

# AC2-SUBJECT-VS-T: Distinction between subject tag and t (hashtag) tag
echo "[AC2-SUBJECT-VS-T] Distinction between subject tag and t tag"
if [ -f "$SKILL_DIR/SKILL.md" ] || [ -f "$SKILL_DIR/references/nip-spec.md" ]; then
  # Must mention both subject and t tags, with some distinguishing context
  HAS_SUBJECT=$(grep -rci 'subject' "$SKILL_DIR/SKILL.md" "$SKILL_DIR/references/nip-spec.md" 2>/dev/null | awk -F: '{s+=$NF} END {print s+0}')
  HAS_TTAG=$(grep -rc '"t"\|`t`.*tag\|hashtag' "$SKILL_DIR/SKILL.md" "$SKILL_DIR/references/nip-spec.md" 2>/dev/null | awk -F: '{s+=$NF} END {print s+0}')
  if [ "$HAS_SUBJECT" -gt 0 ] && [ "$HAS_TTAG" -gt 0 ]; then
    pass "AC2-SUBJECT-VS-T" "Both subject and t/hashtag tags documented"
  else
    fail "AC2-SUBJECT-VS-T" "Missing distinction between subject and t tags (subject refs: $HAS_SUBJECT, t-tag refs: $HAS_TTAG)"
  fi
else
  fail "AC2-SUBJECT-VS-T" "Required files not found"
fi

# AC2-TOONEXT: toon-extensions.md covers fee tables for long-form content
echo "[AC2-TOONEXT] toon-extensions.md covers long-form content fees"
if [ -f "$SKILL_DIR/references/toon-extensions.md" ]; then
  if grep -qi 'basePricePerByte\|fee\|cost' "$SKILL_DIR/references/toon-extensions.md" && grep -qi 'kind:30023\|article\|long-form\|long.form' "$SKILL_DIR/references/toon-extensions.md"; then
    pass "AC2-TOONEXT" "toon-extensions.md covers long-form content fees"
  else
    fail "AC2-TOONEXT" "toon-extensions.md missing fee tables for long-form content"
  fi
else
  fail "AC2-TOONEXT" "references/toon-extensions.md not found"
fi

# AC2-SCENARIOS: scenarios.md covers long-form content workflows
echo "[AC2-SCENARIOS] scenarios.md covers long-form content workflows"
if [ -f "$SKILL_DIR/references/scenarios.md" ]; then
  SCENARIO_OK=true
  # Check for article publishing workflow
  if ! grep -qi 'publish.*article\|first article\|article.*publish\|creating.*article' "$SKILL_DIR/references/scenarios.md"; then
    fail "AC2-SCENARIOS" "scenarios.md missing article publishing workflow"
    SCENARIO_OK=false
  fi
  # Check for article update workflow
  if ! grep -qi 'updat.*article\|existing article\|article.*updat' "$SKILL_DIR/references/scenarios.md"; then
    fail "AC2-SCENARIOS" "scenarios.md missing article update workflow"
    SCENARIO_OK=false
  fi
  # Check for draft workflow
  if ! grep -qi 'draft' "$SKILL_DIR/references/scenarios.md"; then
    fail "AC2-SCENARIOS" "scenarios.md missing draft workflow"
    SCENARIO_OK=false
  fi
  # Check for subject tag usage
  if ! grep -qi 'subject.*tag\|subject' "$SKILL_DIR/references/scenarios.md"; then
    fail "AC2-SCENARIOS" "scenarios.md missing subject tag usage workflow"
    SCENARIO_OK=false
  fi
  if [ "$SCENARIO_OK" = true ]; then
    pass "AC2-SCENARIOS" "scenarios.md covers all long-form content workflows"
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

# AC3-REPLACEABLE: Documents parameterized replaceable semantics with cost implications
echo "[AC3-REPLACEABLE] Parameterized replaceable semantics with cost noted"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if grep -qi 'parameterized replaceable\|replaceable event' "$SKILL_DIR/SKILL.md" && grep -qi 'update.*cost\|cost.*money\|each update\|update.*pay\|re-publish\|full.*article.*size\|full.*cost' "$SKILL_DIR/SKILL.md"; then
    pass "AC3-REPLACEABLE" "Parameterized replaceable + update cost documented"
  else
    fail "AC3-REPLACEABLE" "Missing parameterized replaceable semantics or update cost note"
  fi
else
  fail "AC3-REPLACEABLE" "SKILL.md not found"
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

# AC4-FILTER: Read model mentions filtering by kinds:[30023] and #d tag (AC4)
echo "[AC4-FILTER] Read model mentions kinds:[30023] filter and #d tag filter"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  FILTER_OK=true
  if ! grep -qi 'kinds.*30023\|kinds: \[30023\]\|kinds:\[30023\]' "$SKILL_DIR/SKILL.md"; then
    fail "AC4-FILTER" "Missing kinds:[30023] filter mention"
    FILTER_OK=false
  fi
  if ! grep -qi '#d.*tag\|"#d"\|d tag.*filter\|filter.*d tag' "$SKILL_DIR/SKILL.md"; then
    fail "AC4-FILTER" "Missing #d tag filter mention"
    FILTER_OK=false
  fi
  if [ "$FILTER_OK" = true ]; then
    pass "AC4-FILTER" "Read model mentions kinds:[30023] and #d tag filtering"
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

# AC5-INVESTMENT: Social Context mentions content as investment
echo "[AC5-INVESTMENT] Social Context covers content-as-investment theme"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  SC_CONTENT=$(awk '/^## Social Context/{found=1; next} found && /^## /{exit} found{print}' "$SKILL_DIR/SKILL.md")
  if echo "$SC_CONTENT" | grep -qi 'invest\|signal.*seriousness\|economic.*weight'; then
    pass "AC5-INVESTMENT" "Content-as-investment theme present"
  else
    fail "AC5-INVESTMENT" "Missing content-as-investment theme"
  fi
else
  fail "AC5-INVESTMENT" "SKILL.md not found"
fi

# AC5-QUALITY: Social Context mentions quality over quantity
echo "[AC5-QUALITY] Social Context covers quality-over-quantity theme"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  SC_CONTENT=$(awk '/^## Social Context/{found=1; next} found && /^## /{exit} found{print}' "$SKILL_DIR/SKILL.md")
  if echo "$SC_CONTENT" | grep -qi 'quality.*over.*quantity\|quality over quantity\|incentiviz.*quality\|fewer.*higher-quality'; then
    pass "AC5-QUALITY" "Quality-over-quantity theme present"
  else
    fail "AC5-QUALITY" "Missing quality-over-quantity theme"
  fi
else
  fail "AC5-QUALITY" "SKILL.md not found"
fi

# AC5-UPDATES: Social Context mentions update costs / batch edits
echo "[AC5-UPDATES] Social Context covers update cost / batch edits theme"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  SC_CONTENT=$(awk '/^## Social Context/{found=1; next} found && /^## /{exit} found{print}' "$SKILL_DIR/SKILL.md")
  if echo "$SC_CONTENT" | grep -qi 'updat.*cost\|revision.*cost\|batch.*edit\|proofread\|full article\|edit.*freely'; then
    pass "AC5-UPDATES" "Update cost / batch edits theme present"
  else
    fail "AC5-UPDATES" "Missing update cost / batch edits theme"
  fi
else
  fail "AC5-UPDATES" "SKILL.md not found"
fi

# AC5-SUBJECT: Social Context mentions subject tags as curation signals
echo "[AC5-SUBJECT] Social Context covers subject tags as curation signals"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  SC_CONTENT=$(awk '/^## Social Context/{found=1; next} found && /^## /{exit} found{print}' "$SKILL_DIR/SKILL.md")
  if echo "$SC_CONTENT" | grep -qi 'subject.*tag\|curation.*signal\|subject.*curation\|categorization'; then
    pass "AC5-SUBJECT" "Subject tags as curation signals theme present"
  else
    fail "AC5-SUBJECT" "Missing subject tags curation theme"
  fi
else
  fail "AC5-SUBJECT" "SKILL.md not found"
fi

# AC5-SUMMARY: Social Context mentions summaries as first impressions
echo "[AC5-SUMMARY] Social Context covers summaries as first impressions"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  SC_CONTENT=$(awk '/^## Social Context/{found=1; next} found && /^## /{exit} found{print}' "$SKILL_DIR/SKILL.md")
  if echo "$SC_CONTENT" | grep -qi 'summary.*first.*impression\|first impression.*summary\|summary.*determine\|compelling.*summary\|summary.*craft'; then
    pass "AC5-SUMMARY" "Summaries as first impressions theme present"
  else
    fail "AC5-SUMMARY" "Missing summaries as first impressions theme"
  fi
else
  fail "AC5-SUMMARY" "SKILL.md not found"
fi

# AC5-SUBST: Social Context substitution test (content-specific, not generic)
echo "[AC5-SUBST] Social Context passes substitution test (content-specific)"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  SC_CONTENT=$(awk '/^## Social Context/{found=1; next} found && /^## /{exit} found{print}' "$SKILL_DIR/SKILL.md")
  SUBST_SCORE=0
  # These are long-form-content-specific terms that would fail substitution test
  echo "$SC_CONTENT" | grep -qi 'article' && SUBST_SCORE=$((SUBST_SCORE + 1))
  echo "$SC_CONTENT" | grep -qi 'long-form\|long.form' && SUBST_SCORE=$((SUBST_SCORE + 1))
  echo "$SC_CONTENT" | grep -qi 'summary' && SUBST_SCORE=$((SUBST_SCORE + 1))
  echo "$SC_CONTENT" | grep -qi 'subject.*tag' && SUBST_SCORE=$((SUBST_SCORE + 1))
  echo "$SC_CONTENT" | grep -qi 'header\|structure' && SUBST_SCORE=$((SUBST_SCORE + 1))
  if [ "$SUBST_SCORE" -ge 4 ]; then
    pass "AC5-SUBST" "Social Context is content-specific ($SUBST_SCORE/5 content terms)"
  else
    fail "AC5-SUBST" "Social Context too generic ($SUBST_SCORE/5 content terms, need >= 4)"
  fi
else
  fail "AC5-SUBST" "SKILL.md not found"
fi

# AC5-NIP-SPECIFIC: Social Context has content-publishing compound terms (substitution-proof)
echo "[AC5-NIP-SPECIFIC] Social Context has content-publishing compound terms (substitution-proof)"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  SC_CONTENT=$(awk '/^## Social Context/{found=1; next} found && /^## /{exit} found{print}' "$SKILL_DIR/SKILL.md")
  NIP_SCORE=0
  # Compound content-publishing terms that only make sense for long-form content:
  echo "$SC_CONTENT" | grep -qi 'article.*cost\|cost.*article' && NIP_SCORE=$((NIP_SCORE + 1))
  echo "$SC_CONTENT" | grep -qi 'short note\|short.*note\|kind:1' && NIP_SCORE=$((NIP_SCORE + 1))
  echo "$SC_CONTENT" | grep -qi 'byte.*cost\|per.*byte\|higher.*cost' && NIP_SCORE=$((NIP_SCORE + 1))
  echo "$SC_CONTENT" | grep -qi 'batch.*edit\|proofread\|revise.*thought' && NIP_SCORE=$((NIP_SCORE + 1))
  echo "$SC_CONTENT" | grep -qi 'summary.*first\|first.*impression\|summary.*craft' && NIP_SCORE=$((NIP_SCORE + 1))
  echo "$SC_CONTENT" | grep -qi 'subject.*tag.*curation\|curation.*signal' && NIP_SCORE=$((NIP_SCORE + 1))
  if [ "$NIP_SCORE" -ge 4 ]; then
    pass "AC5-NIP-SPECIFIC" "Social Context has $NIP_SCORE/6 content-specific compound terms"
  else
    fail "AC5-NIP-SPECIFIC" "Social Context has only $NIP_SCORE/6 content-specific compound terms (need >= 4)"
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
  echo "$DESCRIPTION" | grep -qi 'long-form\|long.form\|article' && TRIG_SCORE=$((TRIG_SCORE + 1))
  echo "$DESCRIPTION" | grep -qi 'kind:30023' && TRIG_SCORE=$((TRIG_SCORE + 1))
  echo "$DESCRIPTION" | grep -qi 'NIP-23\|NIP-14' && TRIG_SCORE=$((TRIG_SCORE + 1))
  echo "$DESCRIPTION" | grep -qi 'subject.*tag\|subject tag' && TRIG_SCORE=$((TRIG_SCORE + 1))
  echo "$DESCRIPTION" | grep -qi 'publish\|summary\|summaries' && TRIG_SCORE=$((TRIG_SCORE + 1))
  if [ "$TRIG_SCORE" -ge 4 ]; then
    pass "AC8-TRIGPHRASES" "Description includes $TRIG_SCORE/5 required trigger categories"
  else
    fail "AC8-TRIGPHRASES" "Description includes only $TRIG_SCORE/5 required trigger categories (need >= 4)"
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

# AC6-TRIGGER-QUERIES: Should-trigger queries include content-relevant topics (AC6)
echo "[AC6-TRIGGER-QUERIES] Should-trigger queries cover content-relevant topics"
if [ -f "$EVALS_FILE" ]; then
  TRIG_TOPICS=$(node -e "
    const d = JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8'));
    const triggers = (d.trigger_evals || []).filter(e => e.should_trigger === true).map(e => e.query.toLowerCase());
    const all = triggers.join(' ');
    let score = 0;
    if (/article/.test(all)) score++;
    if (/kind:30023|kind 30023/.test(all)) score++;
    if (/update|updat/.test(all)) score++;
    if (/subject/.test(all)) score++;
    if (/summary/.test(all)) score++;
    if (/draft|publish/.test(all)) score++;
    console.log(score);
  " "$EVALS_FILE" 2>/dev/null || echo "0")
  if [ "$TRIG_TOPICS" -ge 5 ]; then
    pass "AC6-TRIGGER-QUERIES" "Should-trigger queries cover $TRIG_TOPICS/6 content topics"
  else
    fail "AC6-TRIGGER-QUERIES" "Should-trigger queries cover only $TRIG_TOPICS/6 content topics (need >= 5)"
  fi
else
  fail "AC6-TRIGGER-QUERIES" "evals/evals.json not found"
fi

# AC6-NOTTRIGGER-QUERIES: Should-not-trigger queries cover non-content topics (AC6)
echo "[AC6-NOTTRIGGER-QUERIES] Should-not-trigger queries cover non-content topics"
if [ -f "$EVALS_FILE" ]; then
  NONTRIG_TOPICS=$(node -e "
    const d = JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8'));
    const nontriggers = (d.trigger_evals || []).filter(e => e.should_trigger === false).map(e => e.query.toLowerCase());
    const all = nontriggers.join(' ');
    let score = 0;
    if (/profile/.test(all)) score++;
    if (/react/.test(all)) score++;
    if (/follow/.test(all)) score++;
    if (/encrypt|messaging|dm/.test(all)) score++;
    if (/group|chat/.test(all)) score++;
    console.log(score);
  " "$EVALS_FILE" 2>/dev/null || echo "0")
  if [ "$NONTRIG_TOPICS" -ge 4 ]; then
    pass "AC6-NOTTRIGGER-QUERIES" "Should-not-trigger queries cover $NONTRIG_TOPICS/5 non-content topics"
  else
    fail "AC6-NOTTRIGGER-QUERIES" "Should-not-trigger queries cover only $NONTRIG_TOPICS/5 non-content topics (need >= 4)"
  fi
else
  fail "AC6-NOTTRIGGER-QUERIES" "evals/evals.json not found"
fi

# AC3-COST-COMPARE: Write model compares long-form article cost to short note cost (AC3)
echo "[AC3-COST-COMPARE] Write model compares article cost vs short note cost"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  WRITE_SECTION=$(awk '/^## TOON Write Model/{found=1; next} found && /^## /{exit} found{print}' "$SKILL_DIR/SKILL.md")
  HAS_SHORT=$(echo "$WRITE_SECTION" | grep -ci 'short note\|kind:1\|kind 1' || true)
  HAS_LONG=$(echo "$WRITE_SECTION" | grep -ci 'kind:30023\|article\|long-form' || true)
  HAS_COMPARE=$(echo "$WRITE_SECTION" | grep -ci '10-40x\|larger\|significantly\|more.*than\|cost.*difference' || true)
  if [ "$HAS_SHORT" -gt 0 ] && [ "$HAS_LONG" -gt 0 ] && [ "$HAS_COMPARE" -gt 0 ]; then
    pass "AC3-COST-COMPARE" "Write model compares article vs short note costs"
  else
    fail "AC3-COST-COMPARE" "Write model missing explicit cost comparison (short: $HAS_SHORT, long: $HAS_LONG, compare: $HAS_COMPARE)"
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
  echo "$DESCRIPTION" | grep -qi 'should I publish' && PHRASE_SCORE=$((PHRASE_SCORE + 1))
  echo "$DESCRIPTION" | grep -qi 'how long should' && PHRASE_SCORE=$((PHRASE_SCORE + 1))
  echo "$DESCRIPTION" | grep -qi 'is this worth' && PHRASE_SCORE=$((PHRASE_SCORE + 1))
  echo "$DESCRIPTION" | grep -qi 'what makes a good' && PHRASE_SCORE=$((PHRASE_SCORE + 1))
  if [ "$PHRASE_SCORE" -ge 2 ]; then
    pass "AC8-SOCIAL-PHRASES" "Description includes $PHRASE_SCORE/4 AC8-specified social-situation phrases"
  else
    fail "AC8-SOCIAL-PHRASES" "Description includes only $PHRASE_SCORE/4 AC8-specified social-situation phrases (need >= 2)"
  fi
else
  fail "AC8-SOCIAL-PHRASES" "SKILL.md not found"
fi

# AC5-STRUCTURE: Social Context mentions structuring articles with headers/titles (AC5)
echo "[AC5-STRUCTURE] Social Context covers article structure guidance"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  SC_CONTENT=$(awk '/^## Social Context/{found=1; next} found && /^## /{exit} found{print}' "$SKILL_DIR/SKILL.md")
  if echo "$SC_CONTENT" | grep -qi 'header.*title\|title.*header\|structure.*article\|meaningful.*header\|descriptive.*title'; then
    pass "AC5-STRUCTURE" "Social Context covers article structure (headers, titles)"
  else
    fail "AC5-STRUCTURE" "Social Context missing article structure guidance (headers, titles)"
  fi
else
  fail "AC5-STRUCTURE" "SKILL.md not found"
fi

# AC2-REPLACEABLE-SPEC: nip-spec.md documents parameterized replaceable event range (AC2)
echo "[AC2-REPLACEABLE-SPEC] nip-spec.md documents parameterized replaceable event semantics"
if [ -f "$SKILL_DIR/references/nip-spec.md" ]; then
  REPL_OK=true
  if ! grep -qi 'parameterized replaceable' "$SKILL_DIR/references/nip-spec.md"; then
    fail "AC2-REPLACEABLE-SPEC" "nip-spec.md missing parameterized replaceable semantics"
    REPL_OK=false
  fi
  if ! grep -qi 'latest.*version\|replac.*previous\|newer.*version\|relay.*replac' "$SKILL_DIR/references/nip-spec.md"; then
    fail "AC2-REPLACEABLE-SPEC" "nip-spec.md missing replacement behavior (latest version wins)"
    REPL_OK=false
  fi
  if [ "$REPL_OK" = true ]; then
    pass "AC2-REPLACEABLE-SPEC" "nip-spec.md documents parameterized replaceable semantics and replacement behavior"
  fi
else
  fail "AC2-REPLACEABLE-SPEC" "references/nip-spec.md not found"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# AC11: WITH/WITHOUT BASELINE (P2 — manual pipeline verification)
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
