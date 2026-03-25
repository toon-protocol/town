#!/usr/bin/env bash
# test-social-identity-skill.sh — ATDD acceptance tests for Story 9.4: Social Identity Skill
# TDD RED PHASE: All tests will FAIL until the skill is implemented.
#
# Usage: ./tests/skills/test-social-identity-skill.sh
# Exit 0 = all checks pass, 1 = at least one check failed
#
# Test IDs map to AC-to-Test Mapping in atdd-checklist-9-4.md:
#   STRUCT-A, STRUCT-B, STRUCT-B2, STRUCT-C, STRUCT-D, STRUCT-E
#   TOON-A, TOON-B, TOON-C, TOON-D, TOON-ALL
#   EVAL-A, EVAL-B, EVAL-A2, EVAL-B2, EVAL-C
#   TRIG-A, TRIG-B
#   DEP-A, DEP-B
#   CLEAN-A
# Gap-fill tests (added to cover remaining AC criteria):
#   AC1-NAME, AC2-FIELDS, AC2-PTAGS, AC2-ITAGS, AC2-WELLKNOWN,
#   AC2-TOONEXT, AC2-SCENARIOS, AC2-BOTFLAG,
#   AC3-CLIENT, AC3-FEEREF, AC3-REPLACEABLE, AC3-WRITEMODEL,
#   AC4-DECODER, AC4-REFREADS,
#   AC5-NEWACCT, AC5-SELFASSERT, AC5-ANTIPATTERNS, AC5-SUBST,
#   AC6-RUBRIC, AC6-TOON-ASSERT,
#   AC8-TRIGPHRASES, AC9-TOKENS,
#   AC10-NODUP, PIPE-REGR
# Gap-fill round 2 (AC coverage tightening):
#   AC10-DEP-BOTH, AC5-NIP-SPECIFIC, AC8-STRICT-RANGE, AC9-TOKEN-WORDS

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILL_DIR="$PROJECT_ROOT/.claude/skills/social-identity"
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

echo "=== ATDD Acceptance Tests: Story 9.4 Social Identity Skill ==="
echo "Skill directory: $SKILL_DIR"
echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STRUCTURAL TESTS (P0)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "── Structural Tests (P0) ──"

# STRUCT-A: SKILL.md exists with valid YAML frontmatter
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

# STRUCT-B: references/ directory with required files
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

# STRUCT-B2: evals/evals.json exists and is valid JSON
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

# STRUCT-D: Social Context section exists (checked via content grep, >= 30 words)
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

# STRUCT-E: Description word count 80-120 (AC8)
echo "[STRUCT-E] Description word count 80-120"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  DESCRIPTION=$(awk '/^---$/{n++; next} n==1 && /^description:/{sub(/^description: */, ""); p=1; print; next} n==1 && p && /^[a-zA-Z][a-zA-Z0-9_-]*:/{p=0} n==1 && p{print} n>=2{exit}' "$SKILL_DIR/SKILL.md")
  WORD_COUNT=$(echo "$DESCRIPTION" | wc -w | tr -d ' ')
  if [ "$WORD_COUNT" -ge 80 ] && [ "$WORD_COUNT" -le 120 ]; then
    pass "STRUCT-E" "Description is $WORD_COUNT words (80-120 range)"
  else
    fail "STRUCT-E" "Description is $WORD_COUNT words (expected 80-120)"
  fi
else
  fail "STRUCT-E" "Cannot check description -- SKILL.md not found"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CONTENT TESTS (P0-P1)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "── Content Tests (P0-P1) ──"

# EVAL-A: SKILL.md body mentions kind:0, kind:3, NIP-05, NIP-24, NIP-39 (AC2)
echo "[EVAL-A] NIP coverage in SKILL.md"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  NIP_OK=true
  for TERM in "kind:0" "kind:3" "NIP-05" "NIP-24" "NIP-39"; do
    if ! grep -q "$TERM" "$SKILL_DIR/SKILL.md"; then
      fail "EVAL-A" "SKILL.md missing coverage for $TERM"
      NIP_OK=false
    fi
  done
  if [ "$NIP_OK" = true ]; then
    pass "EVAL-A" "SKILL.md covers kind:0, kind:3, NIP-05, NIP-24, NIP-39"
  fi
else
  fail "EVAL-A" "Cannot check NIP coverage -- SKILL.md not found"
fi

# EVAL-B: references/nip-spec.md covers profile fields, follow list, DNS verification, external identities (AC2)
echo "[EVAL-B] NIP spec reference file coverage"
if [ -f "$SKILL_DIR/references/nip-spec.md" ]; then
  SPEC_OK=true
  # Check for profile metadata coverage
  if ! grep -qi 'profile\|kind:0\|metadata' "$SKILL_DIR/references/nip-spec.md"; then
    fail "EVAL-B" "nip-spec.md missing profile/metadata coverage"
    SPEC_OK=false
  fi
  # Check for follow list coverage
  if ! grep -qi 'follow\|contact\|kind:3' "$SKILL_DIR/references/nip-spec.md"; then
    fail "EVAL-B" "nip-spec.md missing follow list/contacts coverage"
    SPEC_OK=false
  fi
  # Check for NIP-05 DNS verification
  if ! grep -qi 'DNS\|nostr.json\|well-known\|NIP-05' "$SKILL_DIR/references/nip-spec.md"; then
    fail "EVAL-B" "nip-spec.md missing NIP-05 DNS verification coverage"
    SPEC_OK=false
  fi
  # Check for NIP-39 external identities
  if ! grep -qi 'external\|NIP-39\|"i" tag\|i tag' "$SKILL_DIR/references/nip-spec.md"; then
    fail "EVAL-B" "nip-spec.md missing NIP-39 external identity coverage"
    SPEC_OK=false
  fi
  if [ "$SPEC_OK" = true ]; then
    pass "EVAL-B" "nip-spec.md covers profiles, follow lists, DNS verification, external identities"
  fi
else
  fail "EVAL-B" "references/nip-spec.md not found"
fi

# TOON-D: Social Context is identity-specific (AC5 -- P1)
echo "[TOON-D] Social Context is identity-specific"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  SC_CONTENT=$(awk '/^## Social Context/{found=1; next} found && /^## /{exit} found{print}' "$SKILL_DIR/SKILL.md")
  IDENTITY_OK=true
  # Must mention profile/identity investment
  if ! echo "$SC_CONTENT" | grep -qi 'profile\|identity'; then
    fail "TOON-D" "Social Context missing identity/profile references"
    IDENTITY_OK=false
  fi
  # Must mention follow lists as signals
  if ! echo "$SC_CONTENT" | grep -qi 'follow'; then
    fail "TOON-D" "Social Context missing follow list references"
    IDENTITY_OK=false
  fi
  # Must mention NIP-05 verification distinction
  if ! echo "$SC_CONTENT" | grep -qi 'NIP-05\|verification\|domain'; then
    fail "TOON-D" "Social Context missing NIP-05/verification references"
    IDENTITY_OK=false
  fi
  # Must mention cost/payment/economics
  if ! echo "$SC_CONTENT" | grep -qi 'cost\|pay\|money\|economic\|fee'; then
    fail "TOON-D" "Social Context missing economics references"
    IDENTITY_OK=false
  fi
  if [ "$IDENTITY_OK" = true ]; then
    pass "TOON-D" "Social Context is identity-specific (profiles, follows, verification, economics)"
  fi
else
  fail "TOON-D" "Cannot check Social Context specificity -- SKILL.md not found"
fi

# TRIG-A: Description contains protocol triggers (AC8 -- P1)
echo "[TRIG-A] Description contains protocol triggers"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  DESCRIPTION=$(awk '/^---$/{n++; next} n==1 && /^description:/{sub(/^description: */, ""); p=1; print; next} n==1 && p && /^[a-zA-Z][a-zA-Z0-9_-]*:/{p=0} n==1 && p{print} n>=2{exit}' "$SKILL_DIR/SKILL.md")
  PTRIG_OK=true
  # Should mention relevant NIP event kinds or NIP numbers
  if ! echo "$DESCRIPTION" | grep -qi 'kind:0\|kind:3\|NIP-05\|NIP-39\|profile\|follow\|identity'; then
    fail "TRIG-A" "Description missing protocol trigger phrases"
    PTRIG_OK=false
  fi
  if [ "$PTRIG_OK" = true ]; then
    pass "TRIG-A" "Description contains protocol trigger phrases"
  fi
else
  fail "TRIG-A" "Cannot check triggers -- SKILL.md not found"
fi

# TRIG-B: Description contains social-situation triggers (AC8 -- P1)
echo "[TRIG-B] Description contains social-situation triggers"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  DESCRIPTION=$(awk '/^---$/{n++; next} n==1 && /^description:/{sub(/^description: */, ""); p=1; print; next} n==1 && p && /^[a-zA-Z][a-zA-Z0-9_-]*:/{p=0} n==1 && p{print} n>=2{exit}' "$SKILL_DIR/SKILL.md")
  if echo "$DESCRIPTION" | grep -qi 'should I\|when to\|how do I\|how to\|how much\|what does\|what is'; then
    pass "TRIG-B" "Description contains social-situation trigger phrases"
  else
    fail "TRIG-B" "Description missing social-situation trigger phrases"
  fi
else
  fail "TRIG-B" "Cannot check triggers -- SKILL.md not found"
fi

# DEP-A: References nostr-protocol-core (AC10 -- P1)
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

# DEP-B: References nostr-social-intelligence (AC10 -- P1)
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

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# NO EXTRANEOUS FILES CHECK
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
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
# GAP-FILL TESTS: AC coverage not in original test suite
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "── Gap-Fill Tests (AC completeness) ──"

# AC1-NAME: Frontmatter name field is exactly "social-identity"
echo "[AC1-NAME] Frontmatter name field value"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  NAME_VALUE=$(awk '/^---$/{n++; next} n==1 && /^name:/{sub(/^name: */, ""); print; exit}' "$SKILL_DIR/SKILL.md")
  if [ "$NAME_VALUE" = "social-identity" ]; then
    pass "AC1-NAME" "Frontmatter name is 'social-identity'"
  else
    fail "AC1-NAME" "Frontmatter name is '$NAME_VALUE' (expected 'social-identity')"
  fi
else
  fail "AC1-NAME" "SKILL.md not found"
fi

# AC2-FIELDS: SKILL.md mentions required profile fields (name, about, picture, nip05, banner, display_name, website, lud16)
echo "[AC2-FIELDS] Profile field coverage in SKILL.md"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  FIELDS_OK=true
  for FIELD in "name" "about" "picture" "nip05" "banner" "display_name" "website" "lud16"; do
    if ! grep -q "$FIELD" "$SKILL_DIR/SKILL.md"; then
      fail "AC2-FIELDS" "SKILL.md missing profile field: $FIELD"
      FIELDS_OK=false
    fi
  done
  if [ "$FIELDS_OK" = true ]; then
    pass "AC2-FIELDS" "All 8 profile fields mentioned in SKILL.md"
  fi
else
  fail "AC2-FIELDS" "SKILL.md not found"
fi

# AC2-PTAGS: SKILL.md or nip-spec.md documents p tag format for kind:3
echo "[AC2-PTAGS] p tag format documented for kind:3 follow list"
if [ -f "$SKILL_DIR/SKILL.md" ] || [ -f "$SKILL_DIR/references/nip-spec.md" ]; then
  if grep -rq '"p"' "$SKILL_DIR/SKILL.md" "$SKILL_DIR/references/nip-spec.md" 2>/dev/null; then
    pass "AC2-PTAGS" "p tag format documented for kind:3"
  else
    fail "AC2-PTAGS" "p tag format not documented"
  fi
else
  fail "AC2-PTAGS" "Required files not found"
fi

# AC2-ITAGS: NIP-39 i tag format documented
echo "[AC2-ITAGS] NIP-39 i tag format documented"
if [ -f "$SKILL_DIR/SKILL.md" ] || [ -f "$SKILL_DIR/references/nip-spec.md" ]; then
  if grep -rq '"i"' "$SKILL_DIR/SKILL.md" "$SKILL_DIR/references/nip-spec.md" 2>/dev/null; then
    pass "AC2-ITAGS" "i tag format documented for NIP-39"
  else
    fail "AC2-ITAGS" "i tag format not documented"
  fi
else
  fail "AC2-ITAGS" "Required files not found"
fi

# AC2-WELLKNOWN: NIP-05 well-known URL documented
echo "[AC2-WELLKNOWN] NIP-05 /.well-known/nostr.json documented"
if grep -rq 'well-known/nostr.json\|nostr.json\|_nostr.json' "$SKILL_DIR/SKILL.md" "$SKILL_DIR/references/nip-spec.md" 2>/dev/null; then
  pass "AC2-WELLKNOWN" "NIP-05 well-known URL documented"
else
  fail "AC2-WELLKNOWN" "NIP-05 well-known URL not documented"
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

# AC3-REPLACEABLE: Documents that kind:0 is replaceable and each update costs money
echo "[AC3-REPLACEABLE] kind:0 replaceable semantics with cost noted"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if grep -qi 'replaceable' "$SKILL_DIR/SKILL.md" && grep -qi 'update.*cost\|cost.*money\|each update\|update.*pay' "$SKILL_DIR/SKILL.md"; then
    pass "AC3-REPLACEABLE" "kind:0 replaceable + cost documented"
  else
    fail "AC3-REPLACEABLE" "Missing replaceable semantics or cost-per-update note"
  fi
else
  fail "AC3-REPLACEABLE" "SKILL.md not found"
fi

# AC4-DECODER: TOON Read Model mentions decoder / TOON format parsing
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

# AC5-NEWACCT: Social Context mentions new accounts / benefit of the doubt
echo "[AC5-NEWACCT] Social Context covers new accounts trust signal"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  SC_CONTENT=$(awk '/^## Social Context/{found=1; next} found && /^## /{exit} found{print}' "$SKILL_DIR/SKILL.md")
  if echo "$SC_CONTENT" | grep -qi 'new account\|benefit of the doubt\|absence of history'; then
    pass "AC5-NEWACCT" "Social Context covers new account trust signal"
  else
    fail "AC5-NEWACCT" "Social Context missing new account / benefit of the doubt guidance"
  fi
else
  fail "AC5-NEWACCT" "SKILL.md not found"
fi

# AC5-SELFASSERT: Social Context mentions NIP-39 claims are self-asserted
echo "[AC5-SELFASSERT] Social Context covers self-asserted identity claims"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  SC_CONTENT=$(awk '/^## Social Context/{found=1; next} found && /^## /{exit} found{print}' "$SKILL_DIR/SKILL.md")
  if echo "$SC_CONTENT" | grep -qi 'self-asserted\|self.assert'; then
    pass "AC5-SELFASSERT" "Social Context covers self-asserted identity claims"
  else
    fail "AC5-SELFASSERT" "Social Context missing self-asserted claim guidance"
  fi
else
  fail "AC5-SELFASSERT" "SKILL.md not found"
fi

# AC5-ANTIPATTERNS: Social Context includes anti-patterns
echo "[AC5-ANTIPATTERNS] Social Context includes anti-patterns"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  SC_CONTENT=$(awk '/^## Social Context/{found=1; next} found && /^## /{exit} found{print}' "$SKILL_DIR/SKILL.md")
  if echo "$SC_CONTENT" | grep -qi 'anti-pattern\|avoid'; then
    pass "AC5-ANTIPATTERNS" "Social Context includes anti-patterns"
  else
    fail "AC5-ANTIPATTERNS" "Social Context missing anti-patterns guidance"
  fi
else
  fail "AC5-ANTIPATTERNS" "SKILL.md not found"
fi

# AC5-SUBST: Social Context substitution test (identity-specific, not generic)
# Checks that the Social Context section mentions identity-specific terms
# that would NOT make sense if a different NIP skill name were substituted
echo "[AC5-SUBST] Social Context passes substitution test (identity-specific)"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  SC_CONTENT=$(awk '/^## Social Context/{found=1; next} found && /^## /{exit} found{print}' "$SKILL_DIR/SKILL.md")
  SUBST_SCORE=0
  # These are identity-specific terms that would fail substitution test
  echo "$SC_CONTENT" | grep -qi 'profile' && SUBST_SCORE=$((SUBST_SCORE + 1))
  echo "$SC_CONTENT" | grep -qi 'follow list\|follow.*list' && SUBST_SCORE=$((SUBST_SCORE + 1))
  echo "$SC_CONTENT" | grep -qi 'NIP-05\|nip05\|domain.*verification\|domain.*control' && SUBST_SCORE=$((SUBST_SCORE + 1))
  echo "$SC_CONTENT" | grep -qi 'NIP-39\|external.*identity\|i tag' && SUBST_SCORE=$((SUBST_SCORE + 1))
  echo "$SC_CONTENT" | grep -qi 'kind:0\|profile.*update' && SUBST_SCORE=$((SUBST_SCORE + 1))
  if [ "$SUBST_SCORE" -ge 4 ]; then
    pass "AC5-SUBST" "Social Context is identity-specific ($SUBST_SCORE/5 identity terms)"
  else
    fail "AC5-SUBST" "Social Context too generic ($SUBST_SCORE/5 identity terms, need >= 4)"
  fi
else
  fail "AC5-SUBST" "SKILL.md not found"
fi

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
  if [ "$TOON_ASSERT_COUNT" -ge 4 ]; then
    pass "AC6-TOON-ASSERT" "$TOON_ASSERT_COUNT output evals include TOON compliance assertions"
  else
    fail "AC6-TOON-ASSERT" "Only $TOON_ASSERT_COUNT output evals include TOON compliance assertions (need >= 4)"
  fi
else
  fail "AC6-TOON-ASSERT" "evals/evals.json not found"
fi

# AC9-TOKENS: Token budget approximation (~5k tokens, estimate 4 chars/token)
echo "[AC9-TOKENS] Token budget approximation (~5k tokens)"
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

# AC2-TOONEXT: toon-extensions.md covers fee tables for identity events
echo "[AC2-TOONEXT] toon-extensions.md covers fee tables"
if [ -f "$SKILL_DIR/references/toon-extensions.md" ]; then
  if grep -qi 'basePricePerByte\|fee\|cost' "$SKILL_DIR/references/toon-extensions.md" && grep -qi 'kind:0\|kind:3\|profile\|follow' "$SKILL_DIR/references/toon-extensions.md"; then
    pass "AC2-TOONEXT" "toon-extensions.md covers identity event fees"
  else
    fail "AC2-TOONEXT" "toon-extensions.md missing fee tables for identity events"
  fi
else
  fail "AC2-TOONEXT" "references/toon-extensions.md not found"
fi

# AC2-SCENARIOS: scenarios.md covers step-by-step identity workflows
echo "[AC2-SCENARIOS] scenarios.md covers identity management workflows"
if [ -f "$SKILL_DIR/references/scenarios.md" ]; then
  SCENARIO_OK=true
  # Check for profile creation workflow
  if ! grep -qi 'creat.*profile\|first profile\|profile.*creation' "$SKILL_DIR/references/scenarios.md"; then
    fail "AC2-SCENARIOS" "scenarios.md missing profile creation workflow"
    SCENARIO_OK=false
  fi
  # Check for follow list management
  if ! grep -qi 'follow.*list\|manage.*follow\|adding.*follow' "$SKILL_DIR/references/scenarios.md"; then
    fail "AC2-SCENARIOS" "scenarios.md missing follow list management workflow"
    SCENARIO_OK=false
  fi
  # Check for NIP-05 setup
  if ! grep -qi 'NIP-05\|DNS.*verif\|well-known' "$SKILL_DIR/references/scenarios.md"; then
    fail "AC2-SCENARIOS" "scenarios.md missing NIP-05 verification workflow"
    SCENARIO_OK=false
  fi
  # Check for NIP-39 external identity
  if ! grep -qi 'NIP-39\|external.*identity\|linking.*identity' "$SKILL_DIR/references/scenarios.md"; then
    fail "AC2-SCENARIOS" "scenarios.md missing NIP-39 external identity workflow"
    SCENARIO_OK=false
  fi
  if [ "$SCENARIO_OK" = true ]; then
    pass "AC2-SCENARIOS" "scenarios.md covers all identity management workflows"
  fi
else
  fail "AC2-SCENARIOS" "references/scenarios.md not found"
fi

# AC8-TRIGPHRASES: Description includes specific trigger phrases from AC8
echo "[AC8-TRIGPHRASES] Description includes required trigger phrases"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  DESCRIPTION=$(awk '/^---$/{n++; next} n==1 && /^description:/{sub(/^description: */, ""); p=1; print; next} n==1 && p && /^[a-zA-Z][a-zA-Z0-9_-]*:/{p=0} n==1 && p{print} n>=2{exit}' "$SKILL_DIR/SKILL.md")
  TRIG_SCORE=0
  echo "$DESCRIPTION" | grep -qi 'identity management\|identity' && TRIG_SCORE=$((TRIG_SCORE + 1))
  echo "$DESCRIPTION" | grep -qi 'profile' && TRIG_SCORE=$((TRIG_SCORE + 1))
  echo "$DESCRIPTION" | grep -qi 'follow list\|follow' && TRIG_SCORE=$((TRIG_SCORE + 1))
  echo "$DESCRIPTION" | grep -qi 'NIP-05.*verification\|NIP-05' && TRIG_SCORE=$((TRIG_SCORE + 1))
  echo "$DESCRIPTION" | grep -qi 'external identit\|NIP-39' && TRIG_SCORE=$((TRIG_SCORE + 1))
  if [ "$TRIG_SCORE" -ge 4 ]; then
    pass "AC8-TRIGPHRASES" "Description includes $TRIG_SCORE/5 required trigger categories"
  else
    fail "AC8-TRIGPHRASES" "Description includes only $TRIG_SCORE/5 required trigger categories (need >= 4)"
  fi
else
  fail "AC8-TRIGPHRASES" "SKILL.md not found"
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

# AC2-BOTFLAG: NIP-24 bot flag documented
echo "[AC2-BOTFLAG] NIP-24 bot flag documented"
if grep -rqi 'bot.*flag\|bot.*boolean\|`bot`' "$SKILL_DIR/SKILL.md" "$SKILL_DIR/references/nip-spec.md" 2>/dev/null; then
  pass "AC2-BOTFLAG" "NIP-24 bot flag documented"
else
  fail "AC2-BOTFLAG" "NIP-24 bot flag not documented"
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

# PIPE-REGR: Pipeline regression -- references/ has no toon-protocol-context.md
# and SKILL.md points to nostr-protocol-core's copy (verifies D9-010 pointer pattern)
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

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# GAP-FILL ROUND 2: Tighter AC validation (AC10-DEP, AC5-NIP, AC8-RANGE, AC9-TOKENS)
# These tests cover gaps identified in AC coverage review:
#   AC10-DEP-BOTH: Both dependency skill paths referenced (not just name mentions)
#   AC5-NIP-SPECIFIC: Social Context NIP-specificity via compound identity terms
#   AC8-STRICT-RANGE: Tighter 80-120 word count per AC8 spec (vs validate-skill.sh 50-200)
#   AC9-TOKEN-WORDS: Word-based token estimation (~5k budget)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo "── Gap-Fill Round 2 (AC coverage tightening) ──"

# AC10-DEP-BOTH: Both upstream skills are referenced as skill paths in SKILL.md
# Existing DEP-A/DEP-B check each name independently. This test verifies BOTH are
# present and that nostr-protocol-core is referenced as an actual skill path
# (e.g., .claude/skills/nostr-protocol-core/...) rather than just a name mention.
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

# AC5-NIP-SPECIFIC: Social Context uses compound identity terms that would fail
# a substitution test (i.e., replacing "social-identity" with another NIP skill
# name like "reactions" or "encryption" would make these terms nonsensical).
# This goes beyond AC5-SUBST by checking for compound phrases, not just single terms.
echo "[AC5-NIP-SPECIFIC] Social Context has NIP-identity compound terms (substitution-proof)"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  SC_CONTENT=$(awk '/^## Social Context/{found=1; next} found && /^## /{exit} found{print}' "$SKILL_DIR/SKILL.md")
  NIP_SCORE=0
  # Compound identity terms that only make sense for identity management:
  echo "$SC_CONTENT" | grep -qi 'profile.*spam\|profile spam' && NIP_SCORE=$((NIP_SCORE + 1))
  echo "$SC_CONTENT" | grep -qi 'follow.*list\|follow list' && NIP_SCORE=$((NIP_SCORE + 1))
  echo "$SC_CONTENT" | grep -qi 'domain.*control\|domain.*ownership\|domain.*verification' && NIP_SCORE=$((NIP_SCORE + 1))
  echo "$SC_CONTENT" | grep -qi 'self-asserted\|self.assert' && NIP_SCORE=$((NIP_SCORE + 1))
  echo "$SC_CONTENT" | grep -qi 'profile.*update\|update.*profile\|updating.*profile' && NIP_SCORE=$((NIP_SCORE + 1))
  echo "$SC_CONTENT" | grep -qi 'credib\|trust.*signal\|identity.*evidence' && NIP_SCORE=$((NIP_SCORE + 1))
  if [ "$NIP_SCORE" -ge 4 ]; then
    pass "AC5-NIP-SPECIFIC" "Social Context has $NIP_SCORE/6 identity-specific compound terms"
  else
    fail "AC5-NIP-SPECIFIC" "Social Context has only $NIP_SCORE/6 identity-specific compound terms (need >= 4)"
  fi
else
  fail "AC5-NIP-SPECIFIC" "SKILL.md not found"
fi

# AC8-STRICT-RANGE: Description word count must be 80-120 per AC8 spec.
# Note: validate-skill.sh check 7 uses the looser 50-200 range. This test
# enforces the AC-specified tighter range as a separate assertion.
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

# AC9-TOKEN-WORDS: Token budget estimation using word count heuristic.
# Existing AC9-TOKENS uses chars/4. This uses word count * 1.3 tokens/word
# (standard heuristic for mixed English/technical markdown). AC9 specifies ~5k tokens.
echo "[AC9-TOKEN-WORDS] Token budget via word-count heuristic (~5k tokens)"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  BODY_WORDS=$(awk 'BEGIN{n=0} /^---$/{n++; next} n>=2{print}' "$SKILL_DIR/SKILL.md" | wc -w | tr -d ' ')
  # Heuristic: ~1.3 tokens per word for English/technical markdown
  # Using integer math: multiply by 13, divide by 10
  APPROX_TOKENS=$(( (BODY_WORDS * 13) / 10 ))
  if [ "$APPROX_TOKENS" -le 5500 ]; then
    pass "AC9-TOKEN-WORDS" "Body is ~$APPROX_TOKENS tokens ($BODY_WORDS words * 1.3; under ~5k budget)"
  else
    fail "AC9-TOKEN-WORDS" "Body is ~$APPROX_TOKENS tokens ($BODY_WORDS words * 1.3; exceeds ~5k token budget)"
  fi
else
  fail "AC9-TOKEN-WORDS" "SKILL.md not found"
fi

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
