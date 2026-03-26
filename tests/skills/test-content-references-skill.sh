#!/usr/bin/env bash
# test-content-references-skill.sh -- ATDD acceptance tests for Story 9.7: Content References Skill
# TDD RED PHASE: All tests will FAIL until the skill is implemented.
#
# Usage: ./tests/skills/test-content-references-skill.sh
# Exit 0 = all checks pass, 1 = at least one check failed
#
# Test IDs map to AC-to-Test Mapping in atdd-checklist-9-7.md:
#   STRUCT-A, STRUCT-B, STRUCT-B2, STRUCT-C, STRUCT-D
#   TOON-A, TOON-B, TOON-C, TOON-D, TOON-ALL-1, TOON-ALL-2
#   EVAL-A, EVAL-B, EVAL-A2, EVAL-B2, EVAL-C
#   TRIG-A, TRIG-B
#   DEP-A, DEP-B
#   CLEAN-A
#   AC1-NAME
#   AC2-NIP21, AC2-NIP27, AC2-NPUB1, AC2-NOTE1, AC2-NPROFILE1, AC2-NEVENT1, AC2-NADDR1
#   AC2-BECH32, AC2-TLV, AC2-TAG-URI, AC2-TOONEXT, AC2-SCENARIOS
#   AC3-CLIENT, AC3-FEEREF, AC3-EMBED-URI, AC3-TAG-REQ, AC3-BYTE-COST
#   AC4-DECODER, AC4-PARSING, AC4-RELAY-HINTS, AC4-READREF, AC4-READING-FREE
#   AC5-LINK-QUALITY, AC5-SELF-REF, AC5-ATTRIBUTION, AC5-DEAD-REF
#   AC5-NADDR-VALUE, AC5-TLV-PREFER, AC5-SUBST
#   AC6-RUBRIC, AC6-TOON-ASSERT, AC6-TRIGGER-QUERIES, AC6-NOTTRIGGER-QUERIES, AC6-EXPECTED-OPT
#   AC8-TRIGPHRASES, AC8-STRICT-RANGE, AC8-SOCIAL-PHRASES
#   AC9-TOKENS
#   AC10-NODUP, AC10-DEP-BOTH
#   BASE-A (skipped -- requires manual pipeline Step 8)
# Gap-fill tests (AC coverage tightening):
#   AC3-NADDR-ATAG, AC3-COREREF, AC4-NIP19, AC4-REGEX
#   AC2-RENDER, AC6-OUTPUT-ID, AC6-OUTPUT-ASSERT
#   AC8-CONTENT-PHRASES, AC7-NAMED-ASSERTIONS
#
# Total: 72 tests (71 automated + 1 skipped)
# Note: In RED phase (missing files), STRUCT-B and EVAL-A may count extra fails per missing file/term

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILL_DIR="$PROJECT_ROOT/.claude/skills/content-references"
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

echo "=== ATDD Acceptance Tests: Story 9.7 Content References Skill ==="
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

# AC1-NAME: Skill name in frontmatter is "content-references" (AC1)
echo "[AC1-NAME] Skill name is content-references"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if sed -n '/^---$/,/^---$/p' "$SKILL_DIR/SKILL.md" | grep -q '^name: content-references'; then
    pass "AC1-NAME" "Skill name is content-references"
  else
    fail "AC1-NAME" "Skill name is not content-references"
  fi
else
  fail "AC1-NAME" "Cannot check name -- SKILL.md not found"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CONTENT TESTS -- NIP COVERAGE (P0)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "── Content Tests -- NIP Coverage (P0) ──"

# EVAL-A: SKILL.md body mentions NIP-21, NIP-27, nostr: URI, bech32 (AC2)
echo "[EVAL-A] NIP coverage in SKILL.md"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  NIP_OK=true
  NIP_MISSING=""
  for TERM in "NIP-21" "NIP-27" "nostr:" "bech32"; do
    if ! grep -q "$TERM" "$SKILL_DIR/SKILL.md"; then
      NIP_OK=false
      NIP_MISSING="$NIP_MISSING $TERM"
    fi
  done
  if [ "$NIP_OK" = true ]; then
    pass "EVAL-A" "SKILL.md covers NIP-21, NIP-27, nostr: URI, bech32"
  else
    fail "EVAL-A" "SKILL.md missing coverage for:$NIP_MISSING"
  fi
else
  fail "EVAL-A" "Cannot check NIP coverage -- SKILL.md not found"
fi

# EVAL-B: references/nip-spec.md covers NIP-21 URI scheme and NIP-27 text note references (AC2)
echo "[EVAL-B] NIP spec reference file coverage"
if [ -f "$SKILL_DIR/references/nip-spec.md" ]; then
  SPEC_OK=true
  if ! grep -qi 'NIP-21\|nostr:.*URI' "$SKILL_DIR/references/nip-spec.md"; then
    fail "EVAL-B" "nip-spec.md missing NIP-21/nostr: URI coverage"
    SPEC_OK=false
  fi
  if ! grep -qi 'NIP-27\|text note reference\|inline.*mention' "$SKILL_DIR/references/nip-spec.md"; then
    fail "EVAL-B" "nip-spec.md missing NIP-27/text note reference coverage"
    SPEC_OK=false
  fi
  if [ "$SPEC_OK" = true ]; then
    pass "EVAL-B" "nip-spec.md covers NIP-21 and NIP-27"
  fi
else
  fail "EVAL-B" "nip-spec.md not found"
fi

# AC2-NIP21: SKILL.md mentions NIP-21 (AC2)
echo "[AC2-NIP21] SKILL.md covers NIP-21"
if [ -f "$SKILL_DIR/SKILL.md" ] && grep -q 'NIP-21' "$SKILL_DIR/SKILL.md"; then
  pass "AC2-NIP21" "NIP-21 mentioned in SKILL.md"
else
  fail "AC2-NIP21" "NIP-21 not found in SKILL.md"
fi

# AC2-NIP27: SKILL.md mentions NIP-27 (AC2)
echo "[AC2-NIP27] SKILL.md covers NIP-27"
if [ -f "$SKILL_DIR/SKILL.md" ] && grep -q 'NIP-27' "$SKILL_DIR/SKILL.md"; then
  pass "AC2-NIP27" "NIP-27 mentioned in SKILL.md"
else
  fail "AC2-NIP27" "NIP-27 not found in SKILL.md"
fi

# AC2-NPUB1: Skill covers npub1 entity type (AC2)
echo "[AC2-NPUB1] Skill covers npub1"
if [ -f "$SKILL_DIR/SKILL.md" ] && grep -qi 'npub1' "$SKILL_DIR/SKILL.md"; then
  pass "AC2-NPUB1" "npub1 covered in SKILL.md"
else
  fail "AC2-NPUB1" "npub1 not found in SKILL.md"
fi

# AC2-NOTE1: Skill covers note1 entity type (AC2)
echo "[AC2-NOTE1] Skill covers note1"
if [ -f "$SKILL_DIR/SKILL.md" ] && grep -qi 'note1' "$SKILL_DIR/SKILL.md"; then
  pass "AC2-NOTE1" "note1 covered in SKILL.md"
else
  fail "AC2-NOTE1" "note1 not found in SKILL.md"
fi

# AC2-NPROFILE1: Skill covers nprofile1 entity type (AC2)
echo "[AC2-NPROFILE1] Skill covers nprofile1"
if [ -f "$SKILL_DIR/SKILL.md" ] && grep -qi 'nprofile1' "$SKILL_DIR/SKILL.md"; then
  pass "AC2-NPROFILE1" "nprofile1 covered in SKILL.md"
else
  fail "AC2-NPROFILE1" "nprofile1 not found in SKILL.md"
fi

# AC2-NEVENT1: Skill covers nevent1 entity type (AC2)
echo "[AC2-NEVENT1] Skill covers nevent1"
if [ -f "$SKILL_DIR/SKILL.md" ] && grep -qi 'nevent1' "$SKILL_DIR/SKILL.md"; then
  pass "AC2-NEVENT1" "nevent1 covered in SKILL.md"
else
  fail "AC2-NEVENT1" "nevent1 not found in SKILL.md"
fi

# AC2-NADDR1: Skill covers naddr1 entity type (AC2)
echo "[AC2-NADDR1] Skill covers naddr1"
if [ -f "$SKILL_DIR/SKILL.md" ] && grep -qi 'naddr1' "$SKILL_DIR/SKILL.md"; then
  pass "AC2-NADDR1" "naddr1 covered in SKILL.md"
else
  fail "AC2-NADDR1" "naddr1 not found in SKILL.md"
fi

# AC2-BECH32: Skill covers bech32 encoding (AC2)
echo "[AC2-BECH32] Skill covers bech32 encoding"
if [ -f "$SKILL_DIR/SKILL.md" ] && grep -qi 'bech32' "$SKILL_DIR/SKILL.md"; then
  pass "AC2-BECH32" "bech32 encoding covered in SKILL.md"
else
  fail "AC2-BECH32" "bech32 encoding not found in SKILL.md"
fi

# AC2-TLV: nip-spec.md covers TLV encoding (AC2)
echo "[AC2-TLV] nip-spec.md covers TLV encoding"
if [ -f "$SKILL_DIR/references/nip-spec.md" ] && grep -qi 'TLV\|type-length-value' "$SKILL_DIR/references/nip-spec.md"; then
  pass "AC2-TLV" "TLV encoding covered in nip-spec.md"
else
  fail "AC2-TLV" "TLV encoding not found in nip-spec.md"
fi

# AC2-TAG-URI: Skill covers tag-URI correspondence (AC2)
echo "[AC2-TAG-URI] Skill covers tag-URI correspondence"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  TAG_OK=true
  # Check for p tag correspondence
  if ! grep -qi 'p.*tag\|"p"' "$SKILL_DIR/SKILL.md"; then
    TAG_OK=false
  fi
  # Check for e tag correspondence
  if ! grep -qi 'e.*tag\|"e"' "$SKILL_DIR/SKILL.md"; then
    TAG_OK=false
  fi
  # Check for a tag correspondence
  if ! grep -qi 'a.*tag\|"a"' "$SKILL_DIR/SKILL.md"; then
    TAG_OK=false
  fi
  if [ "$TAG_OK" = true ]; then
    pass "AC2-TAG-URI" "Tag-URI correspondence (p, e, a tags) covered in SKILL.md"
  else
    fail "AC2-TAG-URI" "Tag-URI correspondence incomplete in SKILL.md"
  fi
else
  fail "AC2-TAG-URI" "Cannot check tag-URI correspondence -- SKILL.md not found"
fi

# AC2-TOONEXT: toon-extensions.md exists and covers byte costs (AC2)
echo "[AC2-TOONEXT] toon-extensions.md covers byte costs"
if [ -f "$SKILL_DIR/references/toon-extensions.md" ]; then
  if grep -qi 'byte.*cost\|cost.*byte\|fee.*impact\|basePricePerByte' "$SKILL_DIR/references/toon-extensions.md"; then
    pass "AC2-TOONEXT" "toon-extensions.md covers byte costs"
  else
    fail "AC2-TOONEXT" "toon-extensions.md does not mention byte costs"
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
if [ -f "$SKILL_DIR/SKILL.md" ] && grep -qi 'fee\|cost.*byte\|byte.*cost\|basePricePerByte' "$SKILL_DIR/SKILL.md"; then
  pass "AC3-FEEREF" "SKILL.md references fee/cost"
else
  fail "AC3-FEEREF" "SKILL.md does not reference fee/cost"
fi

# AC3-EMBED-URI: Explains URI embedding in content field (AC3)
echo "[AC3-EMBED-URI] Explains URI embedding in content field"
if [ -f "$SKILL_DIR/SKILL.md" ] && grep -qi 'content field\|embedded.*content\|embed.*URI\|URI.*content' "$SKILL_DIR/SKILL.md"; then
  pass "AC3-EMBED-URI" "SKILL.md explains URI embedding in content field"
else
  fail "AC3-EMBED-URI" "SKILL.md does not explain URI embedding in content field"
fi

# AC3-TAG-REQ: Explains corresponding tag requirements (AC3)
echo "[AC3-TAG-REQ] Explains corresponding tag requirements"
if [ -f "$SKILL_DIR/SKILL.md" ] && grep -qi 'corresponding.*tag\|tag.*correspond\|tag-URI\|p.*tag.*e.*tag\|must.*tag' "$SKILL_DIR/SKILL.md"; then
  pass "AC3-TAG-REQ" "SKILL.md explains corresponding tag requirements"
else
  fail "AC3-TAG-REQ" "SKILL.md does not explain corresponding tag requirements"
fi

# AC3-BYTE-COST: Includes byte cost estimates for URI types (AC3)
echo "[AC3-BYTE-COST] Includes byte cost estimates"
if [ -f "$SKILL_DIR/SKILL.md" ] && grep -qi '~6[0-9]\|~7[0-9]\|~8[0-9]\|~1[0-4][0-9]\|60.*byte\|67.*byte\|80.*byte' "$SKILL_DIR/SKILL.md"; then
  pass "AC3-BYTE-COST" "SKILL.md includes byte cost estimates for URI types"
else
  fail "AC3-BYTE-COST" "SKILL.md does not include byte cost estimates"
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

# AC4-DECODER: References TOON decoder or TOON-format (AC4)
echo "[AC4-DECODER] References TOON decoder"
if [ -f "$SKILL_DIR/SKILL.md" ] && grep -qi 'TOON decoder\|TOON[- ]format' "$SKILL_DIR/SKILL.md"; then
  pass "AC4-DECODER" "SKILL.md references TOON decoder/format"
else
  fail "AC4-DECODER" "SKILL.md does not reference TOON decoder/format"
fi

# AC4-PARSING: Explains URI parsing/extraction from content (AC4)
echo "[AC4-PARSING] Explains URI parsing from content"
if [ -f "$SKILL_DIR/SKILL.md" ] && grep -qi 'pars\|extract.*URI\|scan.*nostr:\|URI.*extract' "$SKILL_DIR/SKILL.md"; then
  pass "AC4-PARSING" "SKILL.md explains URI parsing from content"
else
  fail "AC4-PARSING" "SKILL.md does not explain URI parsing from content"
fi

# AC4-RELAY-HINTS: Covers relay hints in nprofile1/nevent1/naddr1 (AC4)
echo "[AC4-RELAY-HINTS] Covers relay hints"
if [ -f "$SKILL_DIR/SKILL.md" ] && grep -qi 'relay hint' "$SKILL_DIR/SKILL.md"; then
  pass "AC4-RELAY-HINTS" "SKILL.md covers relay hints"
else
  fail "AC4-RELAY-HINTS" "SKILL.md does not cover relay hints"
fi

# AC4-READREF: References nostr-protocol-core for TOON format details (AC4)
echo "[AC4-READREF] References nostr-protocol-core for read model"
if [ -f "$SKILL_DIR/SKILL.md" ] && grep -qi 'nostr-protocol-core.*toon-protocol-context\|toon-protocol-context' "$SKILL_DIR/SKILL.md"; then
  pass "AC4-READREF" "SKILL.md references nostr-protocol-core for TOON format"
else
  fail "AC4-READREF" "SKILL.md does not reference nostr-protocol-core for TOON format"
fi

# AC4-READING-FREE: States reading is free (AC4)
echo "[AC4-READING-FREE] States reading is free"
if grep -rqi 'free\|no.*ILP.*payment\|no.*payment.*required' "$SKILL_DIR/SKILL.md" "$SKILL_DIR"/references/*.md 2>/dev/null; then
  pass "AC4-READING-FREE" "Skill states reading is free"
else
  fail "AC4-READING-FREE" "Skill does not state reading is free"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SOCIAL CONTEXT TESTS (P1)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "── Social Context Tests (P1) ──"

# TOON-D: Social Context section has reference-specific content (AC5, >= 100 words)
echo "[TOON-D] Social Context has >= 100 words of reference-specific content"
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

# AC5-LINK-QUALITY: Social Context covers link quality / cost of references (AC5)
echo "[AC5-LINK-QUALITY] Social Context covers link quality"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  SC_SECTION=$(awk '/^## Social Context/{found=1; next} found && /^## /{exit} found{print}' "$SKILL_DIR/SKILL.md")
  if echo "$SC_SECTION" | grep -qi 'link quality\|quality.*matter\|cost.*money\|micro-investment'; then
    pass "AC5-LINK-QUALITY" "Social Context covers link quality and cost"
  else
    fail "AC5-LINK-QUALITY" "Social Context does not cover link quality/cost"
  fi
else
  fail "AC5-LINK-QUALITY" "Cannot check -- SKILL.md not found"
fi

# AC5-SELF-REF: Social Context covers self-referencing (AC5)
echo "[AC5-SELF-REF] Social Context covers self-referencing"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  SC_SECTION=$(awk '/^## Social Context/{found=1; next} found && /^## /{exit} found{print}' "$SKILL_DIR/SKILL.md")
  if echo "$SC_SECTION" | grep -qi 'self-referenc\|self.*promot'; then
    pass "AC5-SELF-REF" "Social Context covers self-referencing"
  else
    fail "AC5-SELF-REF" "Social Context does not cover self-referencing"
  fi
else
  fail "AC5-SELF-REF" "Cannot check -- SKILL.md not found"
fi

# AC5-ATTRIBUTION: Social Context covers cross-referencing as attribution (AC5)
echo "[AC5-ATTRIBUTION] Social Context covers attribution"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  SC_SECTION=$(awk '/^## Social Context/{found=1; next} found && /^## /{exit} found{print}' "$SKILL_DIR/SKILL.md")
  if echo "$SC_SECTION" | grep -qi 'attribut\|cross-referenc\|amplif'; then
    pass "AC5-ATTRIBUTION" "Social Context covers attribution/cross-referencing"
  else
    fail "AC5-ATTRIBUTION" "Social Context does not cover attribution"
  fi
else
  fail "AC5-ATTRIBUTION" "Cannot check -- SKILL.md not found"
fi

# AC5-DEAD-REF: Social Context covers dead/broken references (AC5)
echo "[AC5-DEAD-REF] Social Context covers dead references"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  SC_SECTION=$(awk '/^## Social Context/{found=1; next} found && /^## /{exit} found{print}' "$SKILL_DIR/SKILL.md")
  if echo "$SC_SECTION" | grep -qi 'dead.*reference\|broken.*link\|unavailable.*event\|deleted'; then
    pass "AC5-DEAD-REF" "Social Context covers dead references"
  else
    fail "AC5-DEAD-REF" "Social Context does not cover dead references"
  fi
else
  fail "AC5-DEAD-REF" "Cannot check -- SKILL.md not found"
fi

# AC5-NADDR-VALUE: Social Context covers naddr1 value for versioned content (AC5)
echo "[AC5-NADDR-VALUE] Social Context covers naddr1 value"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  SC_SECTION=$(awk '/^## Social Context/{found=1; next} found && /^## /{exit} found{print}' "$SKILL_DIR/SKILL.md")
  if echo "$SC_SECTION" | grep -qi 'naddr1\|replaceable\|versioned'; then
    pass "AC5-NADDR-VALUE" "Social Context covers naddr1 value for versioned content"
  else
    fail "AC5-NADDR-VALUE" "Social Context does not cover naddr1 value"
  fi
else
  fail "AC5-NADDR-VALUE" "Cannot check -- SKILL.md not found"
fi

# AC5-TLV-PREFER: Social Context covers TLV preference over simple types (AC5)
echo "[AC5-TLV-PREFER] Social Context covers TLV preference"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  SC_SECTION=$(awk '/^## Social Context/{found=1; next} found && /^## /{exit} found{print}' "$SKILL_DIR/SKILL.md")
  if echo "$SC_SECTION" | grep -qi 'prefer.*TLV\|TLV.*prefer\|nprofile1.*npub1\|prefer.*nprofile\|relay hint'; then
    pass "AC5-TLV-PREFER" "Social Context covers TLV preference"
  else
    fail "AC5-TLV-PREFER" "Social Context does not cover TLV preference"
  fi
else
  fail "AC5-TLV-PREFER" "Cannot check -- SKILL.md not found"
fi

# AC5-SUBST: Social Context passes NIP-name substitution test (AC5)
echo "[AC5-SUBST] Social Context is NIP-specific (not generic)"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  SC_SECTION=$(awk '/^## Social Context/{found=1; next} found && /^## /{exit} found{print}' "$SKILL_DIR/SKILL.md")
  # Must contain reference-specific terms that would NOT make sense if NIP name were swapped
  SUBST_OK=true
  FOUND_SPECIFIC=0
  for TERM in "reference" "link" "nostr:" "URI" "naddr1" "cross-referenc" "byte" "dead reference"; do
    if echo "$SC_SECTION" | grep -qi "$TERM"; then
      FOUND_SPECIFIC=$((FOUND_SPECIFIC + 1))
    fi
  done
  if [ "$FOUND_SPECIFIC" -ge 4 ]; then
    pass "AC5-SUBST" "Social Context has $FOUND_SPECIFIC reference-specific terms (passes substitution test)"
  else
    fail "AC5-SUBST" "Social Context has only $FOUND_SPECIFIC reference-specific terms (need >= 4, fails substitution test)"
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

# AC6-TRIGGER-QUERIES: Should-trigger queries cover protocol terms (AC6)
echo "[AC6-TRIGGER-QUERIES] Trigger queries cover protocol terms"
if [ -f "$EVALS_FILE" ]; then
  TRIGGER_TERMS=$(node -e "
    const d = JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8'));
    const triggers = (d.trigger_evals || []).filter(e => e.should_trigger === true).map(e => e.query.toLowerCase());
    const allText = triggers.join(' ');
    let found = 0;
    for (const t of ['nostr:', 'nip-21', 'nip-27', 'bech32', 'mention', 'link', 'reference', 'embed', 'naddr']) {
      if (allText.includes(t.toLowerCase())) found++;
    }
    console.log(found);
  " "$EVALS_FILE" 2>/dev/null || echo "0")
  if [ "$TRIGGER_TERMS" -ge 5 ]; then
    pass "AC6-TRIGGER-QUERIES" "Should-trigger queries cover $TRIGGER_TERMS/9 protocol terms"
  else
    fail "AC6-TRIGGER-QUERIES" "Should-trigger queries cover only $TRIGGER_TERMS/9 protocol terms (need >= 5)"
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
    for (const t of ['profile', 'article', 'reaction', 'repost', 'group', 'encrypt', 'follow', 'file']) {
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
  TRIG_OK=true
  TRIG_FOUND=0
  for TERM in "nostr:" "NIP-21" "NIP-27" "npub1" "note1" "nprofile1" "nevent1" "naddr1" "bech32"; do
    if echo "$DESCRIPTION" | grep -qi "$TERM"; then
      TRIG_FOUND=$((TRIG_FOUND + 1))
    fi
  done
  if [ "$TRIG_FOUND" -ge 7 ]; then
    pass "AC8-TRIGPHRASES" "Description includes $TRIG_FOUND/9 trigger phrases"
  else
    fail "AC8-TRIGPHRASES" "Description includes only $TRIG_FOUND/9 trigger phrases (need >= 7)"
  fi
else
  fail "AC8-TRIGPHRASES" "Cannot extract description"
fi

# AC8-SOCIAL-PHRASES: Description includes social-situation triggers (AC8)
echo "[AC8-SOCIAL-PHRASES] Description includes social-situation triggers"
if [ -n "$DESCRIPTION" ]; then
  if echo "$DESCRIPTION" | grep -qi 'how do I\|how to\|what is\|best way'; then
    pass "AC8-SOCIAL-PHRASES" "Description includes social-situation triggers"
  else
    fail "AC8-SOCIAL-PHRASES" "Description does not include social-situation triggers"
  fi
else
  fail "AC8-SOCIAL-PHRASES" "Cannot extract description"
fi

# TRIG-A: Description has protocol-technical triggers (AC8)
echo "[TRIG-A] Protocol-technical triggers in description"
if [ -n "$DESCRIPTION" ]; then
  if echo "$DESCRIPTION" | grep -qi 'NIP-[0-9]\|bech32\|nostr:\|URI'; then
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
  if echo "$DESCRIPTION" | grep -qi 'how do I\|how to\|mention\|link\|reference\|embed'; then
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
  # ~5000 tokens ≈ ~3500 words (1.4 tokens/word average)
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

# AC10-NODUP: Skill does NOT contain toon-protocol-context.md in references/ (AC10)
echo "[AC10-NODUP] No duplicate toon-protocol-context.md in references/"
if [ -f "$SKILL_DIR/references/toon-protocol-context.md" ]; then
  fail "AC10-NODUP" "toon-protocol-context.md found in references/ (should not be duplicated)"
else
  pass "AC10-NODUP" "No duplicate toon-protocol-context.md in references/"
fi

# AC10-DEP-BOTH: Skill references both nostr-protocol-core and nostr-social-intelligence (AC10)
echo "[AC10-DEP-BOTH] References both upstream skills"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  HAS_CORE=false
  HAS_SOCIAL=false
  if grep -qi 'nostr-protocol-core' "$SKILL_DIR/SKILL.md"; then HAS_CORE=true; fi
  if grep -qi 'nostr-social-intelligence' "$SKILL_DIR/SKILL.md"; then HAS_SOCIAL=true; fi
  if [ "$HAS_CORE" = true ] && [ "$HAS_SOCIAL" = true ]; then
    pass "AC10-DEP-BOTH" "SKILL.md references both nostr-protocol-core and nostr-social-intelligence"
  else
    fail "AC10-DEP-BOTH" "SKILL.md missing upstream references (core=$HAS_CORE, social=$HAS_SOCIAL)"
  fi
else
  fail "AC10-DEP-BOTH" "Cannot check -- SKILL.md not found"
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
# GAP-FILL TESTS (AC coverage tightening)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "── Gap-Fill Tests (AC coverage tightening) ──"

# AC3-NADDR-ATAG: naddr1 references use a tag format (AC3)
echo "[AC3-NADDR-ATAG] naddr1 references use a tag format"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if grep -q 'naddr1' "$SKILL_DIR/SKILL.md" && grep -q '"a"' "$SKILL_DIR/SKILL.md"; then
    # Verify they appear in proximity (both in the tag correspondence section)
    if grep -qi 'naddr1.*tag\|naddr1.*"a"\|"a".*naddr1' "$SKILL_DIR/SKILL.md"; then
      pass "AC3-NADDR-ATAG" "SKILL.md links naddr1 to a tag format"
    else
      fail "AC3-NADDR-ATAG" "SKILL.md mentions naddr1 and a tag separately but not in correspondence"
    fi
  else
    fail "AC3-NADDR-ATAG" "SKILL.md missing naddr1 or a tag reference"
  fi
else
  fail "AC3-NADDR-ATAG" "Cannot check -- SKILL.md not found"
fi

# AC3-COREREF: Write model references nostr-protocol-core for fee formula (AC3)
echo "[AC3-COREREF] Write model references nostr-protocol-core for fee formula"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  # Check that the TOON Write Model section references nostr-protocol-core
  WRITE_SECTION=$(awk '/^## TOON Write Model/{found=1; next} found && /^## /{exit} found{print}' "$SKILL_DIR/SKILL.md")
  if echo "$WRITE_SECTION" | grep -qi 'nostr-protocol-core\|toon-protocol-context'; then
    pass "AC3-COREREF" "TOON Write Model section references nostr-protocol-core"
  else
    fail "AC3-COREREF" "TOON Write Model section does not reference nostr-protocol-core for fee formula"
  fi
else
  fail "AC3-COREREF" "Cannot check -- SKILL.md not found"
fi

# AC4-NIP19: Read model mentions NIP-19 bech32 decoding (AC4)
echo "[AC4-NIP19] Read model mentions NIP-19 bech32 decoding"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  READ_SECTION=$(awk '/^## TOON Read Model/{found=1; next} found && /^## /{exit} found{print}' "$SKILL_DIR/SKILL.md")
  if echo "$READ_SECTION" | grep -qi 'NIP-19\|bech32.*decod\|decod.*bech32'; then
    pass "AC4-NIP19" "TOON Read Model explains NIP-19 bech32 decoding"
  else
    fail "AC4-NIP19" "TOON Read Model does not mention NIP-19 bech32 decoding"
  fi
else
  fail "AC4-NIP19" "Cannot check -- SKILL.md not found"
fi

# AC4-REGEX: Read model mentions regex or string matching for URI parsing (AC4)
echo "[AC4-REGEX] Read model mentions parsing approach (regex or string matching)"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  READ_SECTION=$(awk '/^## TOON Read Model/{found=1; next} found && /^## /{exit} found{print}' "$SKILL_DIR/SKILL.md")
  if echo "$READ_SECTION" | grep -qi 'regex\|string match\|scan.*content\|prefix.*bech32'; then
    pass "AC4-REGEX" "TOON Read Model describes URI parsing approach"
  else
    fail "AC4-REGEX" "TOON Read Model does not describe parsing approach (regex/string matching)"
  fi
else
  fail "AC4-REGEX" "Cannot check -- SKILL.md not found"
fi

# AC2-RENDER: NIP-27 coverage includes client rendering behavior (AC2)
echo "[AC2-RENDER] Skill covers client rendering of inline references"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if grep -qi 'render\|clickable\|linked.*profile\|embedded.*note\|note.*preview' "$SKILL_DIR/SKILL.md"; then
    pass "AC2-RENDER" "SKILL.md covers client rendering of inline references"
  else
    fail "AC2-RENDER" "SKILL.md does not cover client rendering behavior"
  fi
else
  fail "AC2-RENDER" "Cannot check -- SKILL.md not found"
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

# AC8-CONTENT-PHRASES: Description includes content-linking trigger phrases (AC8)
echo "[AC8-CONTENT-PHRASES] Description includes content-linking trigger phrases"
if [ -n "$DESCRIPTION" ]; then
  CONTENT_FOUND=0
  for TERM in "content linking" "cross-referenc" "mention" "embed" "link to article\|link.*article"; do
    if echo "$DESCRIPTION" | grep -qi "$TERM"; then
      CONTENT_FOUND=$((CONTENT_FOUND + 1))
    fi
  done
  if [ "$CONTENT_FOUND" -ge 3 ]; then
    pass "AC8-CONTENT-PHRASES" "Description includes $CONTENT_FOUND/5 content-linking trigger phrases"
  else
    fail "AC8-CONTENT-PHRASES" "Description includes only $CONTENT_FOUND/5 content-linking phrases (need >= 3)"
  fi
else
  fail "AC8-CONTENT-PHRASES" "Cannot extract description"
fi

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
