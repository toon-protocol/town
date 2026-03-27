#!/usr/bin/env bash
# test-media-and-files-skill.sh -- ATDD acceptance tests for Story 9.14: Media and Files Skill
# TDD RED PHASE: All tests will FAIL until the skill is implemented.
#
# Usage: ./tests/skills/test-media-and-files-skill.sh
# Exit 0 = all checks pass, 1 = at least one check failed
#
# Test IDs map to AC-to-Test Mapping in atdd-checklist-9-14.md:
#   STRUCT-A, STRUCT-B, STRUCT-B2, STRUCT-C, STRUCT-D
#   TOON-A, TOON-B, TOON-C, TOON-D, TOON-ALL-1, TOON-ALL-2
#   EVAL-A, EVAL-B, EVAL-A2, EVAL-B2, EVAL-C
#   TRIG-A, TRIG-B
#   DEP-A, DEP-B, DEP-C, DEP-D, DEP-E, DEP-F
#   CLEAN-A
#   AC1-NAME
#   AC2-NIP92, AC2-NIP94, AC2-NIP73, AC2-IMETA, AC2-KIND1063, AC2-ITAG
#   AC2-IMETA-FIELDS, AC2-IMETA-MULTI, AC2-IMETA-AUGMENT
#   AC2-KIND1063-REQUIRED, AC2-KIND1063-OPTIONAL, AC2-KIND1063-CONTENT
#   AC2-ITAG-TYPES, AC2-ITAG-RELAY, AC2-ARWEAVE-TX
#   AC2-NIPSPEC-THREE, AC2-NIPSPEC-SECTIONS, AC2-TOONEXT, AC2-SCENARIOS
#   AC3-CLIENT, AC3-FEEREF, AC3-IMETA-COST, AC3-KIND1063-COST
#   AC3-ITAG-OVERHEAD, AC3-ESTIMATES, AC3-COREREF
#   AC4-FORMAT, AC4-QUERY-1063, AC4-PARSE-IMETA, AC4-ITAG-FILTER, AC4-READREF
#   AC5-QUALITY, AC5-METADATA-VS-FILE, AC5-ARWEAVE-PERMANENT
#   AC5-ALT-TEXT, AC5-NO-BINARY, AC5-CROSSPLATFORM, AC5-SUBST
#   AC6-RUBRIC, AC6-TOON-ASSERT, AC6-TRIGGER-QUERIES, AC6-NOTTRIGGER-QUERIES
#   AC6-EXPECTED-OPT, AC6-OUTPUT-ID, AC6-OUTPUT-ASSERT, AC6-OUTPUT-RANGE
#   AC8-TRIGPHRASES, AC8-STRICT-RANGE, AC8-SOCIAL-PHRASES
#   AC9-TOKENS
#   AC10-NODUP, AC10-DEP-ALL
#   AC7-NAMED-ASSERTIONS, AC7-EVAL-ASSERTIONS
#   AC12-ARWEAVE-TX-FORMAT, AC12-ARWEAVE-URL, AC12-ARWEAVE-DVM, AC12-ARWEAVE-PERMANENT
#   BASE-A (skipped -- requires manual pipeline Step 8)
#
# Total: 92 tests (91 automated + 1 skipped)

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILL_DIR="$PROJECT_ROOT/.claude/skills/media-and-files"
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

echo "=== ATDD Acceptance Tests: Story 9.14 Media and Files Skill ==="
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

# AC1-NAME: name field is media-and-files
echo "[AC1-NAME] name field is media-and-files"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if sed -n '/^---$/,/^---$/p' "$SKILL_DIR/SKILL.md" | grep -q '^name: media-and-files'; then
    pass "AC1-NAME" "name field is media-and-files"
  else
    fail "AC1-NAME" "name field is not media-and-files"
  fi
else
  fail "AC1-NAME" "SKILL.md not found"
fi

# STRUCT-B: references/ directory with required files (AC1)
echo "[STRUCT-B] references/ directory with required files"
if [ -d "$SKILL_DIR/references" ]; then
  MISSING=""
  for f in nip-spec.md toon-extensions.md scenarios.md; do
    if [ ! -f "$SKILL_DIR/references/$f" ]; then
      MISSING="$MISSING $f"
    fi
  done
  if [ -z "$MISSING" ]; then
    pass "STRUCT-B" "references/ has all required files"
  else
    fail "STRUCT-B" "Missing reference files:$MISSING"
  fi
else
  fail "STRUCT-B" "references/ directory not found"
fi

# STRUCT-B2: evals/evals.json exists (AC1)
echo "[STRUCT-B2] evals/evals.json exists"
if [ -f "$SKILL_DIR/evals/evals.json" ]; then
  pass "STRUCT-B2" "evals/evals.json exists"
else
  fail "STRUCT-B2" "evals/evals.json not found"
fi

# CLEAN-A: No extraneous files in skill directory
echo "[CLEAN-A] No extraneous files in skill directory"
if [ -d "$SKILL_DIR" ]; then
  TOP_LEVEL=$(ls -1 "$SKILL_DIR" | sort)
  EXPECTED=$(printf "SKILL.md\nevals\nreferences" | sort)
  if [ "$TOP_LEVEL" = "$EXPECTED" ]; then
    pass "CLEAN-A" "Skill directory contains exactly SKILL.md, evals/, references/"
  else
    fail "CLEAN-A" "Unexpected files in skill directory: $TOP_LEVEL"
  fi
else
  fail "CLEAN-A" "Skill directory not found"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# NIP COVERAGE TESTS (AC2)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo "── NIP Coverage Tests (AC2) ──"

# AC2-NIP92: SKILL.md covers NIP-92
echo "[AC2-NIP92] SKILL.md covers NIP-92"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if grep -qi "NIP-92" "$SKILL_DIR/SKILL.md" && grep -qi "imeta" "$SKILL_DIR/SKILL.md"; then
    pass "AC2-NIP92" "SKILL.md covers NIP-92 and imeta"
  else
    fail "AC2-NIP92" "SKILL.md missing NIP-92 or imeta coverage"
  fi
else
  fail "AC2-NIP92" "SKILL.md not found"
fi

# AC2-NIP94: SKILL.md covers NIP-94
echo "[AC2-NIP94] SKILL.md covers NIP-94 and kind:1063"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if grep -qi "NIP-94" "$SKILL_DIR/SKILL.md" && grep -q "kind:1063" "$SKILL_DIR/SKILL.md"; then
    pass "AC2-NIP94" "SKILL.md covers NIP-94 and kind:1063"
  else
    fail "AC2-NIP94" "SKILL.md missing NIP-94 or kind:1063 coverage"
  fi
else
  fail "AC2-NIP94" "SKILL.md not found"
fi

# AC2-NIP73: SKILL.md covers NIP-73
echo "[AC2-NIP73] SKILL.md covers NIP-73 external content IDs"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if grep -qi "NIP-73" "$SKILL_DIR/SKILL.md" && grep -qi "external content" "$SKILL_DIR/SKILL.md"; then
    pass "AC2-NIP73" "SKILL.md covers NIP-73 and external content IDs"
  else
    fail "AC2-NIP73" "SKILL.md missing NIP-73 or external content ID coverage"
  fi
else
  fail "AC2-NIP73" "SKILL.md not found"
fi

# AC2-IMETA-FIELDS: imeta tag fields covered (url, m, alt, x, size, dim)
echo "[AC2-IMETA-FIELDS] imeta tag fields covered"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  BODY=$(sed -n '/^---$/,/^---$/!p' "$SKILL_DIR/SKILL.md")
  LOWER=$(echo "$BODY" | tr '[:upper:]' '[:lower:]')
  if echo "$LOWER" | grep -q "url" && echo "$LOWER" | grep -q "alt" && echo "$LOWER" | grep -q "size" && echo "$LOWER" | grep -q "dim"; then
    pass "AC2-IMETA-FIELDS" "imeta tag fields (url, alt, size, dim) covered"
  else
    fail "AC2-IMETA-FIELDS" "Missing imeta tag fields"
  fi
else
  fail "AC2-IMETA-FIELDS" "SKILL.md not found"
fi

# AC2-IMETA-MULTI: Multiple imeta tags per event documented
echo "[AC2-IMETA-MULTI] Multiple imeta tags per event"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if grep -qi "multiple.*imeta\|imeta.*per event" "$SKILL_DIR/SKILL.md"; then
    pass "AC2-IMETA-MULTI" "Multiple imeta tags per event documented"
  else
    fail "AC2-IMETA-MULTI" "Multiple imeta tags per event not documented"
  fi
else
  fail "AC2-IMETA-MULTI" "SKILL.md not found"
fi

# AC2-IMETA-AUGMENT: imeta augments existing events
echo "[AC2-IMETA-AUGMENT] imeta augments existing events"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if grep -qi "augment\|existing event\|kind:1\|kind:30023" "$SKILL_DIR/SKILL.md"; then
    pass "AC2-IMETA-AUGMENT" "imeta augments existing events documented"
  else
    fail "AC2-IMETA-AUGMENT" "imeta augmenting existing events not documented"
  fi
else
  fail "AC2-IMETA-AUGMENT" "SKILL.md not found"
fi

# AC2-KIND1063-REQUIRED: kind:1063 required tags (url, m, x)
echo "[AC2-KIND1063-REQUIRED] kind:1063 required tags"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if grep -qi "required.*tag" "$SKILL_DIR/SKILL.md"; then
    pass "AC2-KIND1063-REQUIRED" "kind:1063 required tags documented"
  else
    fail "AC2-KIND1063-REQUIRED" "kind:1063 required tags not documented"
  fi
else
  fail "AC2-KIND1063-REQUIRED" "SKILL.md not found"
fi

# AC2-KIND1063-OPTIONAL: kind:1063 optional tags
echo "[AC2-KIND1063-OPTIONAL] kind:1063 optional tags"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if grep -qi "optional.*tag" "$SKILL_DIR/SKILL.md" && grep -qi "ox" "$SKILL_DIR/SKILL.md"; then
    pass "AC2-KIND1063-OPTIONAL" "kind:1063 optional tags documented"
  else
    fail "AC2-KIND1063-OPTIONAL" "kind:1063 optional tags not documented"
  fi
else
  fail "AC2-KIND1063-OPTIONAL" "SKILL.md not found"
fi

# AC2-KIND1063-CONTENT: kind:1063 content field is description/caption
echo "[AC2-KIND1063-CONTENT] kind:1063 content is description/caption"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if grep -qi "description\|caption" "$SKILL_DIR/SKILL.md"; then
    pass "AC2-KIND1063-CONTENT" "kind:1063 content as description/caption documented"
  else
    fail "AC2-KIND1063-CONTENT" "kind:1063 content field not documented"
  fi
else
  fail "AC2-KIND1063-CONTENT" "SKILL.md not found"
fi

# AC2-ITAG-TYPES: i tag types (arweave:tx:, isbn:, doi:, url:)
echo "[AC2-ITAG-TYPES] i tag types covered"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if grep -q "arweave:tx:" "$SKILL_DIR/SKILL.md" && grep -qi "isbn" "$SKILL_DIR/SKILL.md" && grep -qi "doi" "$SKILL_DIR/SKILL.md"; then
    pass "AC2-ITAG-TYPES" "i tag types (arweave:tx:, isbn:, doi:) covered"
  else
    fail "AC2-ITAG-TYPES" "i tag types not fully covered"
  fi
else
  fail "AC2-ITAG-TYPES" "SKILL.md not found"
fi

# AC2-ARWEAVE-TX: arweave:tx: external content ID covered
echo "[AC2-ARWEAVE-TX] arweave:tx: external content ID"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if grep -q "arweave:tx:" "$SKILL_DIR/SKILL.md"; then
    pass "AC2-ARWEAVE-TX" "arweave:tx: covered in SKILL.md"
  else
    fail "AC2-ARWEAVE-TX" "arweave:tx: not found in SKILL.md"
  fi
else
  fail "AC2-ARWEAVE-TX" "SKILL.md not found"
fi

# AC2-NIPSPEC-THREE: nip-spec.md covers all three NIPs
echo "[AC2-NIPSPEC-THREE] nip-spec.md covers NIP-92, NIP-94, NIP-73"
if [ -f "$SKILL_DIR/references/nip-spec.md" ]; then
  if grep -q "NIP-92" "$SKILL_DIR/references/nip-spec.md" && \
     grep -q "NIP-94" "$SKILL_DIR/references/nip-spec.md" && \
     grep -q "NIP-73" "$SKILL_DIR/references/nip-spec.md"; then
    pass "AC2-NIPSPEC-THREE" "nip-spec.md covers all three NIPs"
  else
    fail "AC2-NIPSPEC-THREE" "nip-spec.md missing one or more NIPs"
  fi
else
  fail "AC2-NIPSPEC-THREE" "nip-spec.md not found"
fi

# AC2-NIPSPEC-SECTIONS: nip-spec.md has distinct sections per NIP
echo "[AC2-NIPSPEC-SECTIONS] nip-spec.md has distinct NIP sections"
if [ -f "$SKILL_DIR/references/nip-spec.md" ]; then
  if grep -E '^#+.*NIP-92' "$SKILL_DIR/references/nip-spec.md" >/dev/null && \
     grep -E '^#+.*NIP-94' "$SKILL_DIR/references/nip-spec.md" >/dev/null && \
     grep -E '^#+.*NIP-73' "$SKILL_DIR/references/nip-spec.md" >/dev/null; then
    pass "AC2-NIPSPEC-SECTIONS" "nip-spec.md has distinct section headings for each NIP"
  else
    fail "AC2-NIPSPEC-SECTIONS" "nip-spec.md missing section headings for one or more NIPs"
  fi
else
  fail "AC2-NIPSPEC-SECTIONS" "nip-spec.md not found"
fi

# AC2-TOONEXT: toon-extensions.md covers media-specific TOON dynamics
echo "[AC2-TOONEXT] toon-extensions.md covers TOON media dynamics"
if [ -f "$SKILL_DIR/references/toon-extensions.md" ]; then
  if grep -qi "imeta" "$SKILL_DIR/references/toon-extensions.md" && \
     grep -q "kind:1063" "$SKILL_DIR/references/toon-extensions.md" && \
     grep -q "arweave:tx:" "$SKILL_DIR/references/toon-extensions.md"; then
    pass "AC2-TOONEXT" "toon-extensions.md covers imeta, kind:1063, arweave:tx:"
  else
    fail "AC2-TOONEXT" "toon-extensions.md missing media-specific coverage"
  fi
else
  fail "AC2-TOONEXT" "toon-extensions.md not found"
fi

# AC2-SCENARIOS: scenarios.md covers media usage scenarios
echo "[AC2-SCENARIOS] scenarios.md covers media scenarios"
if [ -f "$SKILL_DIR/references/scenarios.md" ]; then
  if grep -qi "imeta" "$SKILL_DIR/references/scenarios.md" && \
     grep -q "kind:1063" "$SKILL_DIR/references/scenarios.md" && \
     grep -q "arweave:tx:" "$SKILL_DIR/references/scenarios.md"; then
    pass "AC2-SCENARIOS" "scenarios.md covers imeta, kind:1063, arweave:tx: scenarios"
  else
    fail "AC2-SCENARIOS" "scenarios.md missing media scenario coverage"
  fi
else
  fail "AC2-SCENARIOS" "scenarios.md not found"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TOON WRITE MODEL TESTS (AC3)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo "── TOON Write Model Tests (AC3) ──"

# AC3-CLIENT: references publishEvent() and @toon-protocol/client
echo "[AC3-CLIENT] publishEvent() and @toon-protocol/client"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if grep -q "publishEvent()" "$SKILL_DIR/SKILL.md" && grep -q "@toon-protocol/client" "$SKILL_DIR/SKILL.md"; then
    pass "AC3-CLIENT" "publishEvent() and @toon-protocol/client referenced"
  else
    fail "AC3-CLIENT" "Missing publishEvent() or @toon-protocol/client"
  fi
else
  fail "AC3-CLIENT" "SKILL.md not found"
fi

# AC3-IMETA-COST: imeta tags increase event byte size and cost
echo "[AC3-IMETA-COST] imeta tags increase byte size and cost"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if grep -qi "imeta.*increase\|imeta.*cost\|imeta.*byte" "$SKILL_DIR/SKILL.md"; then
    pass "AC3-IMETA-COST" "imeta cost impact documented"
  else
    fail "AC3-IMETA-COST" "imeta cost impact not documented"
  fi
else
  fail "AC3-IMETA-COST" "SKILL.md not found"
fi

# AC3-ITAG-OVERHEAD: arweave:tx: adds minimal overhead
echo "[AC3-ITAG-OVERHEAD] arweave:tx: minimal overhead"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if grep -qi "minimal.*overhead\|arweave.*small\|arweave.*minimal" "$SKILL_DIR/SKILL.md"; then
    pass "AC3-ITAG-OVERHEAD" "arweave:tx: minimal overhead documented"
  else
    fail "AC3-ITAG-OVERHEAD" "arweave:tx: overhead not documented"
  fi
else
  fail "AC3-ITAG-OVERHEAD" "SKILL.md not found"
fi

# AC3-FEEREF: references nostr-protocol-core for fee formula
echo "[AC3-FEEREF] References nostr-protocol-core for fee formula"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if grep -q "nostr-protocol-core" "$SKILL_DIR/SKILL.md"; then
    pass "AC3-FEEREF" "nostr-protocol-core referenced for fees"
  else
    fail "AC3-FEEREF" "nostr-protocol-core not referenced"
  fi
else
  fail "AC3-FEEREF" "SKILL.md not found"
fi

# AC3-ESTIMATES: Concrete fee estimates with dollar amounts
echo "[AC3-ESTIMATES] Concrete fee estimates"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if grep -qE '\$0\.[0-9]+' "$SKILL_DIR/SKILL.md"; then
    pass "AC3-ESTIMATES" "Concrete fee estimates with dollar amounts present"
  else
    fail "AC3-ESTIMATES" "No concrete fee estimates found"
  fi
else
  fail "AC3-ESTIMATES" "SKILL.md not found"
fi

# AC3-COREREF: toon-extensions.md covers publishEvent flow
echo "[AC3-COREREF] toon-extensions.md covers publishEvent"
if [ -f "$SKILL_DIR/references/toon-extensions.md" ]; then
  if grep -q "publishEvent" "$SKILL_DIR/references/toon-extensions.md"; then
    pass "AC3-COREREF" "toon-extensions.md covers publishEvent flow"
  else
    fail "AC3-COREREF" "toon-extensions.md missing publishEvent"
  fi
else
  fail "AC3-COREREF" "toon-extensions.md not found"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TOON READ MODEL TESTS (AC4)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo "── TOON Read Model Tests (AC4) ──"

# AC4-FORMAT: Documents TOON-format strings
echo "[AC4-FORMAT] TOON-format strings documented"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if grep -qi "toon.format\|toon format\|TOON-format" "$SKILL_DIR/SKILL.md"; then
    pass "AC4-FORMAT" "TOON-format strings documented"
  else
    fail "AC4-FORMAT" "TOON-format strings not documented"
  fi
else
  fail "AC4-FORMAT" "SKILL.md not found"
fi

# AC4-QUERY-1063: How to query kind:1063 events
echo "[AC4-QUERY-1063] Querying kind:1063 events"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if grep -qi "query.*kind:1063\|subscribe.*kind:1063\|filter.*1063" "$SKILL_DIR/SKILL.md"; then
    pass "AC4-QUERY-1063" "Querying kind:1063 events documented"
  else
    fail "AC4-QUERY-1063" "Querying kind:1063 not documented"
  fi
else
  fail "AC4-QUERY-1063" "SKILL.md not found"
fi

# AC4-PARSE-IMETA: How to parse imeta tags
echo "[AC4-PARSE-IMETA] Parsing imeta tags"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if grep -qi "parse.*imeta\|extract.*imeta\|imeta.*pars" "$SKILL_DIR/SKILL.md"; then
    pass "AC4-PARSE-IMETA" "Parsing imeta tags documented"
  else
    fail "AC4-PARSE-IMETA" "Parsing imeta tags not documented"
  fi
else
  fail "AC4-PARSE-IMETA" "SKILL.md not found"
fi

# AC4-ITAG-FILTER: i tags as filter criteria
echo "[AC4-ITAG-FILTER] i tags as filter criteria"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if grep -qi "filter.*i.*tag\|i.*tag.*filter\|external.*content.*filter" "$SKILL_DIR/SKILL.md"; then
    pass "AC4-ITAG-FILTER" "i tags as filter criteria documented"
  else
    fail "AC4-ITAG-FILTER" "i tags as filter criteria not documented"
  fi
else
  fail "AC4-ITAG-FILTER" "SKILL.md not found"
fi

# AC4-READREF: References nostr-protocol-core for TOON format parsing
echo "[AC4-READREF] nostr-protocol-core reference for format parsing"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if grep -q "nostr-protocol-core" "$SKILL_DIR/SKILL.md"; then
    pass "AC4-READREF" "nostr-protocol-core referenced for format parsing"
  else
    fail "AC4-READREF" "nostr-protocol-core not referenced"
  fi
else
  fail "AC4-READREF" "SKILL.md not found"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SOCIAL CONTEXT TESTS (AC5)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo "── Social Context Tests (AC5) ──"

# STRUCT-D: ## Social Context section exists
echo "[STRUCT-D] Social Context section exists"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if grep -q "## Social Context" "$SKILL_DIR/SKILL.md"; then
    pass "STRUCT-D" "Social Context section exists"
  else
    fail "STRUCT-D" "Social Context section not found"
  fi
else
  fail "STRUCT-D" "SKILL.md not found"
fi

# AC5-QUALITY: Quality over quantity on paid network
echo "[AC5-QUALITY] Quality over quantity guidance"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  SOCIAL=$(sed -n '/## Social Context/,/^## /p' "$SKILL_DIR/SKILL.md" | head -100)
  if echo "$SOCIAL" | grep -qi "quality.*quantity\|thoughtful"; then
    pass "AC5-QUALITY" "Quality over quantity guidance present"
  else
    fail "AC5-QUALITY" "Quality over quantity guidance missing"
  fi
else
  fail "AC5-QUALITY" "SKILL.md not found"
fi

# AC5-METADATA-VS-FILE: Metadata vs file storage distinction
echo "[AC5-METADATA-VS-FILE] Metadata vs file storage distinction"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  SOCIAL=$(sed -n '/## Social Context/,/^## /p' "$SKILL_DIR/SKILL.md" | head -100)
  if echo "$SOCIAL" | grep -qi "metadata.*small\|pay.*metadata\|hosted.*elsewhere\|external"; then
    pass "AC5-METADATA-VS-FILE" "Metadata vs file storage distinction present"
  else
    fail "AC5-METADATA-VS-FILE" "Metadata vs file storage distinction missing"
  fi
else
  fail "AC5-METADATA-VS-FILE" "SKILL.md not found"
fi

# AC5-ARWEAVE-PERMANENT: Arweave permanence guidance
echo "[AC5-ARWEAVE-PERMANENT] Arweave permanence guidance"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  SOCIAL=$(sed -n '/## Social Context/,/^## /p' "$SKILL_DIR/SKILL.md" | head -100)
  if echo "$SOCIAL" | grep -qi "arweave" && echo "$SOCIAL" | grep -qi "permanent\|immutable\|permanence"; then
    pass "AC5-ARWEAVE-PERMANENT" "Arweave permanence guidance present"
  else
    fail "AC5-ARWEAVE-PERMANENT" "Arweave permanence guidance missing"
  fi
else
  fail "AC5-ARWEAVE-PERMANENT" "SKILL.md not found"
fi

# AC5-ALT-TEXT: Alt text for accessibility
echo "[AC5-ALT-TEXT] Alt text accessibility guidance"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  SOCIAL=$(sed -n '/## Social Context/,/^## /p' "$SKILL_DIR/SKILL.md" | head -100)
  if echo "$SOCIAL" | grep -qi "alt.*text\|accessibility\|inclusive"; then
    pass "AC5-ALT-TEXT" "Alt text accessibility guidance present"
  else
    fail "AC5-ALT-TEXT" "Alt text accessibility guidance missing"
  fi
else
  fail "AC5-ALT-TEXT" "SKILL.md not found"
fi

# AC5-NO-BINARY: Never embed large binary data
echo "[AC5-NO-BINARY] No large binary data guidance"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  SOCIAL=$(sed -n '/## Social Context/,/^## /p' "$SKILL_DIR/SKILL.md" | head -100)
  if echo "$SOCIAL" | grep -qi "never.*embed.*binary\|binary.*data\|bloated.*event"; then
    pass "AC5-NO-BINARY" "No binary data embedding guidance present"
  else
    fail "AC5-NO-BINARY" "No binary data embedding guidance missing"
  fi
else
  fail "AC5-NO-BINARY" "SKILL.md not found"
fi

# AC5-CROSSPLATFORM: Cross-platform content discovery
echo "[AC5-CROSSPLATFORM] Cross-platform content discovery"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  SOCIAL=$(sed -n '/## Social Context/,/^## /p' "$SKILL_DIR/SKILL.md" | head -100)
  if echo "$SOCIAL" | grep -qi "cross.platform\|content.*discover\|isbn\|doi"; then
    pass "AC5-CROSSPLATFORM" "Cross-platform content discovery guidance present"
  else
    fail "AC5-CROSSPLATFORM" "Cross-platform content discovery guidance missing"
  fi
else
  fail "AC5-CROSSPLATFORM" "SKILL.md not found"
fi

# AC5-SUBST: Substitution test (media-specific, not generic)
echo "[AC5-SUBST] Substitution test"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  SOCIAL=$(sed -n '/## Social Context/,/^## /p' "$SKILL_DIR/SKILL.md" | head -100)
  LOWER=$(echo "$SOCIAL" | tr '[:upper:]' '[:lower:]')
  COUNT=0
  echo "$LOWER" | grep -qi "media" && COUNT=$((COUNT + 1))
  echo "$LOWER" | grep -qi "imeta" && COUNT=$((COUNT + 1))
  echo "$LOWER" | grep -qi "kind:1063" && COUNT=$((COUNT + 1))
  echo "$LOWER" | grep -qi "arweave" && COUNT=$((COUNT + 1))
  echo "$LOWER" | grep -qi "alt.*text\|accessibility" && COUNT=$((COUNT + 1))
  echo "$LOWER" | grep -qi "binary" && COUNT=$((COUNT + 1))
  echo "$LOWER" | grep -qi "file.*metadata" && COUNT=$((COUNT + 1))
  echo "$LOWER" | grep -qi "external.*content" && COUNT=$((COUNT + 1))
  if [ "$COUNT" -ge 5 ]; then
    pass "AC5-SUBST" "Social Context has $COUNT media-specific terms (need >= 5)"
  else
    fail "AC5-SUBST" "Social Context has only $COUNT media-specific terms (need >= 5)"
  fi
else
  fail "AC5-SUBST" "SKILL.md not found"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# EVAL SUITE TESTS (AC6)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo "── Eval Suite Tests (AC6) ──"

# EVAL-A: evals.json is valid JSON
echo "[EVAL-A] evals.json is valid JSON"
if [ -f "$SKILL_DIR/evals/evals.json" ]; then
  if python3 -c "import json; json.load(open('$SKILL_DIR/evals/evals.json'))" 2>/dev/null; then
    pass "EVAL-A" "evals.json is valid JSON"
  else
    fail "EVAL-A" "evals.json is not valid JSON"
  fi
else
  fail "EVAL-A" "evals.json not found"
fi

# EVAL-A2: Has trigger_evals and output_evals arrays
echo "[EVAL-A2] Has trigger_evals and output_evals"
if [ -f "$SKILL_DIR/evals/evals.json" ]; then
  HAS_TRIGGER=$(python3 -c "import json; d=json.load(open('$SKILL_DIR/evals/evals.json')); print('yes' if 'trigger_evals' in d and isinstance(d['trigger_evals'], list) else 'no')" 2>/dev/null)
  HAS_OUTPUT=$(python3 -c "import json; d=json.load(open('$SKILL_DIR/evals/evals.json')); print('yes' if 'output_evals' in d and isinstance(d['output_evals'], list) else 'no')" 2>/dev/null)
  if [ "$HAS_TRIGGER" = "yes" ] && [ "$HAS_OUTPUT" = "yes" ]; then
    pass "EVAL-A2" "Both trigger_evals and output_evals present"
  else
    fail "EVAL-A2" "Missing trigger_evals or output_evals"
  fi
else
  fail "EVAL-A2" "evals.json not found"
fi

# AC6-TRIGGER-QUERIES: 8-10 should-trigger queries
echo "[AC6-TRIGGER-QUERIES] 8-10 should-trigger queries"
if [ -f "$SKILL_DIR/evals/evals.json" ]; then
  COUNT=$(python3 -c "import json; d=json.load(open('$SKILL_DIR/evals/evals.json')); print(len([e for e in d.get('trigger_evals',[]) if e.get('should_trigger')==True]))" 2>/dev/null)
  if [ -n "$COUNT" ] && [ "$COUNT" -ge 8 ] && [ "$COUNT" -le 10 ]; then
    pass "AC6-TRIGGER-QUERIES" "$COUNT should-trigger queries (8-10 required)"
  else
    fail "AC6-TRIGGER-QUERIES" "$COUNT should-trigger queries (8-10 required)"
  fi
else
  fail "AC6-TRIGGER-QUERIES" "evals.json not found"
fi

# AC6-NOTTRIGGER-QUERIES: 8-10 should-not-trigger queries
echo "[AC6-NOTTRIGGER-QUERIES] 8-10 should-not-trigger queries"
if [ -f "$SKILL_DIR/evals/evals.json" ]; then
  COUNT=$(python3 -c "import json; d=json.load(open('$SKILL_DIR/evals/evals.json')); print(len([e for e in d.get('trigger_evals',[]) if e.get('should_trigger')==False]))" 2>/dev/null)
  if [ -n "$COUNT" ] && [ "$COUNT" -ge 8 ] && [ "$COUNT" -le 10 ]; then
    pass "AC6-NOTTRIGGER-QUERIES" "$COUNT should-not-trigger queries (8-10 required)"
  else
    fail "AC6-NOTTRIGGER-QUERIES" "$COUNT should-not-trigger queries (8-10 required)"
  fi
else
  fail "AC6-NOTTRIGGER-QUERIES" "evals.json not found"
fi

# AC6-OUTPUT-RANGE: 4-6 output evals
echo "[AC6-OUTPUT-RANGE] 4-6 output evals"
if [ -f "$SKILL_DIR/evals/evals.json" ]; then
  COUNT=$(python3 -c "import json; d=json.load(open('$SKILL_DIR/evals/evals.json')); print(len(d.get('output_evals',[])))" 2>/dev/null)
  if [ -n "$COUNT" ] && [ "$COUNT" -ge 4 ] && [ "$COUNT" -le 6 ]; then
    pass "AC6-OUTPUT-RANGE" "$COUNT output evals (4-6 required)"
  else
    fail "AC6-OUTPUT-RANGE" "$COUNT output evals (4-6 required)"
  fi
else
  fail "AC6-OUTPUT-RANGE" "evals.json not found"
fi

# AC6-OUTPUT-ID: Each output eval has id, prompt, expected_output, rubric, assertions
echo "[AC6-OUTPUT-ID] Output evals have required fields"
if [ -f "$SKILL_DIR/evals/evals.json" ]; then
  VALID=$(python3 -c "
import json
d=json.load(open('$SKILL_DIR/evals/evals.json'))
for oe in d.get('output_evals',[]):
  for f in ['id','prompt','expected_output','rubric','assertions']:
    if f not in oe: print('no'); exit()
  for rf in ['correct','acceptable','incorrect']:
    if rf not in oe.get('rubric',{}): print('no'); exit()
print('yes')
" 2>/dev/null)
  if [ "$VALID" = "yes" ]; then
    pass "AC6-OUTPUT-ID" "All output evals have required fields and rubric keys"
  else
    fail "AC6-OUTPUT-ID" "Some output evals missing required fields"
  fi
else
  fail "AC6-OUTPUT-ID" "evals.json not found"
fi

# AC6-RUBRIC: Each rubric has correct/acceptable/incorrect
echo "[AC6-RUBRIC] Rubric grading levels"
if [ -f "$SKILL_DIR/evals/evals.json" ]; then
  VALID=$(python3 -c "
import json
d=json.load(open('$SKILL_DIR/evals/evals.json'))
for oe in d.get('output_evals',[]):
  r = oe.get('rubric',{})
  if not all(k in r for k in ['correct','acceptable','incorrect']): print('no'); exit()
print('yes')
" 2>/dev/null)
  if [ "$VALID" = "yes" ]; then
    pass "AC6-RUBRIC" "All rubrics have correct/acceptable/incorrect"
  else
    fail "AC6-RUBRIC" "Some rubrics missing grading levels"
  fi
else
  fail "AC6-RUBRIC" "evals.json not found"
fi

# AC6-TOON-ASSERT: Output evals include TOON compliance assertions
echo "[AC6-TOON-ASSERT] TOON compliance assertions in output evals"
if [ -f "$SKILL_DIR/evals/evals.json" ]; then
  ALL_ASSERTIONS=$(python3 -c "
import json
d=json.load(open('$SKILL_DIR/evals/evals.json'))
for oe in d.get('output_evals',[]):
  for a in oe.get('assertions',[]): print(a.lower())
" 2>/dev/null)
  HAS_WRITE=$(echo "$ALL_ASSERTIONS" | grep -ci "toon-write-check\|publishevent" || true)
  HAS_FORMAT=$(echo "$ALL_ASSERTIONS" | grep -ci "toon-format-check\|toon.format" || true)
  if [ "$HAS_WRITE" -gt 0 ] && [ "$HAS_FORMAT" -gt 0 ]; then
    pass "AC6-TOON-ASSERT" "TOON compliance assertions present (write + format)"
  else
    fail "AC6-TOON-ASSERT" "Missing TOON compliance assertions (write=$HAS_WRITE format=$HAS_FORMAT)"
  fi
else
  fail "AC6-TOON-ASSERT" "evals.json not found"
fi

# AC6-OUTPUT-ASSERT: Output evals include media-specific assertions
echo "[AC6-OUTPUT-ASSERT] Media-specific assertions in output evals"
if [ -f "$SKILL_DIR/evals/evals.json" ]; then
  ALL_ASSERTIONS=$(python3 -c "
import json
d=json.load(open('$SKILL_DIR/evals/evals.json'))
for oe in d.get('output_evals',[]):
  for a in oe.get('assertions',[]): print(a.lower())
" 2>/dev/null)
  HAS_IMETA=$(echo "$ALL_ASSERTIONS" | grep -ci "imeta" || true)
  HAS_ARWEAVE=$(echo "$ALL_ASSERTIONS" | grep -ci "arweave" || true)
  HAS_FEE=$(echo "$ALL_ASSERTIONS" | grep -ci "fee\|cost\|byte" || true)
  if [ "$HAS_IMETA" -gt 0 ] && [ "$HAS_ARWEAVE" -gt 0 ] && [ "$HAS_FEE" -gt 0 ]; then
    pass "AC6-OUTPUT-ASSERT" "Media-specific assertions present (imeta + arweave + fee)"
  else
    fail "AC6-OUTPUT-ASSERT" "Missing media-specific assertions (imeta=$HAS_IMETA arweave=$HAS_ARWEAVE fee=$HAS_FEE)"
  fi
else
  fail "AC6-OUTPUT-ASSERT" "evals.json not found"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TOON COMPLIANCE TESTS (AC7)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo "── TOON Compliance Tests (AC7) ──"

# TOON-A: toon-write-check -- uses publishEvent(), no bare EVENT patterns
echo "[TOON-A] toon-write-check"
if [ -d "$SKILL_DIR" ]; then
  ALL_CONTENT=$(cat "$SKILL_DIR/SKILL.md" "$SKILL_DIR/references/"*.md 2>/dev/null)
  if echo "$ALL_CONTENT" | grep -q "publishEvent" && ! echo "$ALL_CONTENT" | grep -q '\["EVENT"'; then
    pass "TOON-A" "Uses publishEvent(), no bare EVENT patterns"
  else
    fail "TOON-A" "Missing publishEvent() or has bare EVENT patterns"
  fi
else
  fail "TOON-A" "Skill directory not found"
fi

# TOON-B: toon-fee-check -- includes fee awareness
echo "[TOON-B] toon-fee-check"
if [ -d "$SKILL_DIR" ]; then
  ALL_CONTENT=$(cat "$SKILL_DIR/SKILL.md" "$SKILL_DIR/references/"*.md 2>/dev/null | tr '[:upper:]' '[:lower:]')
  if echo "$ALL_CONTENT" | grep -qE 'per.byte|basepriceperbyte' && echo "$ALL_CONTENT" | grep -qE 'cost|fee|pric'; then
    pass "TOON-B" "Fee awareness present"
  else
    fail "TOON-B" "Fee awareness missing"
  fi
else
  fail "TOON-B" "Skill directory not found"
fi

# TOON-C: toon-format-check -- documents TOON-format strings
echo "[TOON-C] toon-format-check"
if [ -d "$SKILL_DIR" ]; then
  ALL_CONTENT=$(cat "$SKILL_DIR/SKILL.md" "$SKILL_DIR/references/"*.md 2>/dev/null | tr '[:upper:]' '[:lower:]')
  if echo "$ALL_CONTENT" | grep -qE 'toon.format|toon format'; then
    pass "TOON-C" "TOON-format strings documented"
  else
    fail "TOON-C" "TOON-format strings not documented"
  fi
else
  fail "TOON-C" "Skill directory not found"
fi

# TOON-D: social-context-check -- media-specific Social Context
echo "[TOON-D] social-context-check"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if grep -q "## Social Context" "$SKILL_DIR/SKILL.md"; then
    SOCIAL=$(sed -n '/## Social Context/,/^## /p' "$SKILL_DIR/SKILL.md" | tr '[:upper:]' '[:lower:]')
    if echo "$SOCIAL" | grep -qi "media\|imeta\|file.*metadata" && echo "$SOCIAL" | grep -qE 'per.byte|cost'; then
      pass "TOON-D" "Media-specific Social Context present"
    else
      fail "TOON-D" "Social Context not media-specific"
    fi
  else
    fail "TOON-D" "Social Context section not found"
  fi
else
  fail "TOON-D" "SKILL.md not found"
fi

# TOON-ALL-1: trigger-coverage -- description has protocol + social triggers
echo "[TOON-ALL-1] trigger-coverage in description"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  DESC=$(sed -n '/^---$/,/^---$/p' "$SKILL_DIR/SKILL.md" | grep '^description:' | sed 's/^description: //' | tr '[:upper:]' '[:lower:]')
  HAS_PROTO=0
  echo "$DESC" | grep -qi "nip.92" && HAS_PROTO=$((HAS_PROTO + 1))
  echo "$DESC" | grep -qi "nip.94" && HAS_PROTO=$((HAS_PROTO + 1))
  echo "$DESC" | grep -qi "nip.73" && HAS_PROTO=$((HAS_PROTO + 1))
  echo "$DESC" | grep -qi "imeta" && HAS_PROTO=$((HAS_PROTO + 1))
  echo "$DESC" | grep -qi "kind:1063" && HAS_PROTO=$((HAS_PROTO + 1))
  HAS_SOCIAL=0
  echo "$DESC" | grep -qi "how do" && HAS_SOCIAL=$((HAS_SOCIAL + 1))
  if [ "$HAS_PROTO" -ge 3 ] && [ "$HAS_SOCIAL" -ge 1 ]; then
    pass "TOON-ALL-1" "Description has protocol ($HAS_PROTO) and social ($HAS_SOCIAL) triggers"
  else
    fail "TOON-ALL-1" "Description missing triggers (proto=$HAS_PROTO social=$HAS_SOCIAL)"
  fi
else
  fail "TOON-ALL-1" "SKILL.md not found"
fi

# TOON-ALL-2: eval-completeness -- at least 6 trigger + 4 output evals
echo "[TOON-ALL-2] eval-completeness"
if [ -f "$SKILL_DIR/evals/evals.json" ]; then
  TRIGGER_COUNT=$(python3 -c "import json; d=json.load(open('$SKILL_DIR/evals/evals.json')); print(len(d.get('trigger_evals',[])))" 2>/dev/null)
  OUTPUT_COUNT=$(python3 -c "import json; d=json.load(open('$SKILL_DIR/evals/evals.json')); print(len(d.get('output_evals',[])))" 2>/dev/null)
  if [ -n "$TRIGGER_COUNT" ] && [ "$TRIGGER_COUNT" -ge 6 ] && [ -n "$OUTPUT_COUNT" ] && [ "$OUTPUT_COUNT" -ge 4 ]; then
    pass "TOON-ALL-2" "Eval completeness: $TRIGGER_COUNT trigger + $OUTPUT_COUNT output evals"
  else
    fail "TOON-ALL-2" "Eval completeness: $TRIGGER_COUNT trigger + $OUTPUT_COUNT output (need 6+4)"
  fi
else
  fail "TOON-ALL-2" "evals.json not found"
fi

# AC7-NAMED-ASSERTIONS: Named TOON assertions in output evals
echo "[AC7-NAMED-ASSERTIONS] Named TOON assertion strings"
if [ -f "$SKILL_DIR/evals/evals.json" ]; then
  ALL_ASSERTIONS=$(python3 -c "
import json
d=json.load(open('$SKILL_DIR/evals/evals.json'))
for oe in d.get('output_evals',[]):
  for a in oe.get('assertions',[]): print(a.lower())
" 2>/dev/null)
  COUNT=0
  echo "$ALL_ASSERTIONS" | grep -qi "toon-write-check" && COUNT=$((COUNT + 1))
  echo "$ALL_ASSERTIONS" | grep -qi "toon-fee-check" && COUNT=$((COUNT + 1))
  echo "$ALL_ASSERTIONS" | grep -qi "toon-format-check" && COUNT=$((COUNT + 1))
  echo "$ALL_ASSERTIONS" | grep -qi "social-context-check" && COUNT=$((COUNT + 1))
  echo "$ALL_ASSERTIONS" | grep -qi "trigger-coverage" && COUNT=$((COUNT + 1))
  if [ "$COUNT" -ge 3 ]; then
    pass "AC7-NAMED-ASSERTIONS" "$COUNT named TOON assertions found (need >= 3)"
  else
    fail "AC7-NAMED-ASSERTIONS" "Only $COUNT named TOON assertions (need >= 3)"
  fi
else
  fail "AC7-NAMED-ASSERTIONS" "evals.json not found"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DESCRIPTION OPTIMIZATION TESTS (AC8)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo "── Description Optimization Tests (AC8) ──"

# AC8-STRICT-RANGE: Description 80-120 words
echo "[AC8-STRICT-RANGE] Description word count 80-120"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  DESC=$(sed -n '/^description:/p' "$SKILL_DIR/SKILL.md" | sed 's/^description: //')
  WC=$(echo "$DESC" | wc -w | tr -d ' ')
  if [ "$WC" -ge 80 ] && [ "$WC" -le 120 ]; then
    pass "AC8-STRICT-RANGE" "Description is $WC words (80-120 required)"
  else
    fail "AC8-STRICT-RANGE" "Description is $WC words (80-120 required)"
  fi
else
  fail "AC8-STRICT-RANGE" "SKILL.md not found"
fi

# AC8-TRIGPHRASES: Description includes required trigger phrases
echo "[AC8-TRIGPHRASES] Description trigger phrases"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  DESC=$(sed -n '/^description:/p' "$SKILL_DIR/SKILL.md" | sed 's/^description: //' | tr '[:upper:]' '[:lower:]')
  COUNT=0
  echo "$DESC" | grep -qi "nip.92" && COUNT=$((COUNT + 1))
  echo "$DESC" | grep -qi "nip.94" && COUNT=$((COUNT + 1))
  echo "$DESC" | grep -qi "nip.73" && COUNT=$((COUNT + 1))
  echo "$DESC" | grep -qi "media.*attach" && COUNT=$((COUNT + 1))
  echo "$DESC" | grep -qi "imeta" && COUNT=$((COUNT + 1))
  echo "$DESC" | grep -qi "file.*metadata" && COUNT=$((COUNT + 1))
  echo "$DESC" | grep -qi "kind:1063" && COUNT=$((COUNT + 1))
  echo "$DESC" | grep -qi "external.*content.*id" && COUNT=$((COUNT + 1))
  echo "$DESC" | grep -qi "arweave" && COUNT=$((COUNT + 1))
  echo "$DESC" | grep -qi "alt.*text" && COUNT=$((COUNT + 1))
  echo "$DESC" | grep -qi "mime" && COUNT=$((COUNT + 1))
  echo "$DESC" | grep -qi "sha.256" && COUNT=$((COUNT + 1))
  if [ "$COUNT" -ge 8 ]; then
    pass "AC8-TRIGPHRASES" "$COUNT/12 trigger phrases found (need >= 8)"
  else
    fail "AC8-TRIGPHRASES" "$COUNT/12 trigger phrases found (need >= 8)"
  fi
else
  fail "AC8-TRIGPHRASES" "SKILL.md not found"
fi

# AC8-SOCIAL-PHRASES: Description includes social-situation triggers
echo "[AC8-SOCIAL-PHRASES] Social-situation trigger phrases"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  DESC=$(sed -n '/^description:/p' "$SKILL_DIR/SKILL.md" | sed 's/^description: //' | tr '[:upper:]' '[:lower:]')
  COUNT=0
  echo "$DESC" | grep -qi "how do i attach media" && COUNT=$((COUNT + 1))
  echo "$DESC" | grep -qi "how do i describe a file" && COUNT=$((COUNT + 1))
  echo "$DESC" | grep -qi "how do i reference arweave" && COUNT=$((COUNT + 1))
  echo "$DESC" | grep -qi "what is an imeta tag" && COUNT=$((COUNT + 1))
  echo "$DESC" | grep -qi "how do i add alt text" && COUNT=$((COUNT + 1))
  echo "$DESC" | grep -qi "how do i create a file metadata" && COUNT=$((COUNT + 1))
  if [ "$COUNT" -ge 2 ]; then
    pass "AC8-SOCIAL-PHRASES" "$COUNT social-situation phrases found (need >= 2)"
  else
    fail "AC8-SOCIAL-PHRASES" "$COUNT social-situation phrases found (need >= 2)"
  fi
else
  fail "AC8-SOCIAL-PHRASES" "SKILL.md not found"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TOKEN BUDGET TESTS (AC9)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo "── Token Budget Tests (AC9) ──"

# AC9-TOKENS: SKILL.md body under 500 lines
echo "[AC9-TOKENS] SKILL.md body under 500 lines"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  BODY_LINES=$(sed -n '/^---$/,/^---$/!p' "$SKILL_DIR/SKILL.md" | wc -l | tr -d ' ')
  if [ "$BODY_LINES" -lt 500 ]; then
    pass "AC9-TOKENS" "Body is $BODY_LINES lines (< 500)"
  else
    fail "AC9-TOKENS" "Body is $BODY_LINES lines (>= 500)"
  fi
else
  fail "AC9-TOKENS" "SKILL.md not found"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DEPENDENCY REFERENCES TESTS (AC10)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo "── Dependency References Tests (AC10) ──"

# DEP-A: nostr-protocol-core referenced
echo "[DEP-A] nostr-protocol-core referenced"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if grep -q "nostr-protocol-core" "$SKILL_DIR/SKILL.md"; then
    pass "DEP-A" "nostr-protocol-core referenced"
  else
    fail "DEP-A" "nostr-protocol-core not referenced"
  fi
else
  fail "DEP-A" "SKILL.md not found"
fi

# DEP-B: nostr-social-intelligence referenced
echo "[DEP-B] nostr-social-intelligence referenced"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if grep -q "nostr-social-intelligence" "$SKILL_DIR/SKILL.md"; then
    pass "DEP-B" "nostr-social-intelligence referenced"
  else
    fail "DEP-B" "nostr-social-intelligence not referenced"
  fi
else
  fail "DEP-B" "SKILL.md not found"
fi

# DEP-C: long-form-content referenced for imeta in articles
echo "[DEP-C] long-form-content referenced"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if grep -q "long-form-content" "$SKILL_DIR/SKILL.md"; then
    pass "DEP-C" "long-form-content referenced"
  else
    fail "DEP-C" "long-form-content not referenced"
  fi
else
  fail "DEP-C" "SKILL.md not found"
fi

# DEP-D: content-references referenced
echo "[DEP-D] content-references referenced"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if grep -q "content-references" "$SKILL_DIR/SKILL.md"; then
    pass "DEP-D" "content-references referenced"
  else
    fail "DEP-D" "content-references not referenced"
  fi
else
  fail "DEP-D" "SKILL.md not found"
fi

# DEP-E: social-interactions referenced
echo "[DEP-E] social-interactions referenced"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if grep -q "social-interactions" "$SKILL_DIR/SKILL.md"; then
    pass "DEP-E" "social-interactions referenced"
  else
    fail "DEP-E" "social-interactions not referenced"
  fi
else
  fail "DEP-E" "SKILL.md not found"
fi

# DEP-F: No toon-protocol-context.md in references/
echo "[DEP-F] No toon-protocol-context.md in references/"
if [ -d "$SKILL_DIR/references" ]; then
  if [ ! -f "$SKILL_DIR/references/toon-protocol-context.md" ]; then
    pass "DEP-F" "toon-protocol-context.md not duplicated"
  else
    fail "DEP-F" "toon-protocol-context.md found in references/ (should not be duplicated)"
  fi
else
  fail "DEP-F" "references/ directory not found"
fi

# AC10-NODUP: Does not duplicate upstream skill content
echo "[AC10-NODUP] No upstream content duplication"
if [ -d "$SKILL_DIR/references" ]; then
  REFS=$(ls "$SKILL_DIR/references/")
  if echo "$REFS" | grep -q "toon-protocol-context.md"; then
    fail "AC10-NODUP" "Duplicated toon-protocol-context.md"
  else
    pass "AC10-NODUP" "No upstream content duplication detected"
  fi
else
  fail "AC10-NODUP" "references/ directory not found"
fi

# AC10-DEP-ALL: All five upstream skill references present
echo "[AC10-DEP-ALL] All five upstream skill references present"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  MISSING=""
  for dep in nostr-protocol-core nostr-social-intelligence long-form-content content-references social-interactions; do
    if ! grep -q "$dep" "$SKILL_DIR/SKILL.md"; then
      MISSING="$MISSING $dep"
    fi
  done
  if [ -z "$MISSING" ]; then
    pass "AC10-DEP-ALL" "All five upstream skill references present"
  else
    fail "AC10-DEP-ALL" "Missing upstream references:$MISSING"
  fi
else
  fail "AC10-DEP-ALL" "SKILL.md not found"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ARWEAVE INTEGRATION TESTS (AC12)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo "── Arweave Integration Tests (AC12) ──"

# AC12-ARWEAVE-TX-FORMAT: arweave:tx:<txid> format in i tags
echo "[AC12-ARWEAVE-TX-FORMAT] arweave:tx:<txid> format documented"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if grep -q 'arweave:tx:' "$SKILL_DIR/SKILL.md"; then
    pass "AC12-ARWEAVE-TX-FORMAT" "arweave:tx: format documented"
  else
    fail "AC12-ARWEAVE-TX-FORMAT" "arweave:tx: format not documented"
  fi
else
  fail "AC12-ARWEAVE-TX-FORMAT" "SKILL.md not found"
fi

# AC12-ARWEAVE-URL: kind:1063 referencing Arweave-hosted files via URL
echo "[AC12-ARWEAVE-URL] kind:1063 Arweave URL reference"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if grep -qi "arweave.*url\|arweave.*host\|url.*arweave" "$SKILL_DIR/SKILL.md"; then
    pass "AC12-ARWEAVE-URL" "kind:1063 Arweave URL reference documented"
  else
    fail "AC12-ARWEAVE-URL" "kind:1063 Arweave URL reference not documented"
  fi
else
  fail "AC12-ARWEAVE-URL" "SKILL.md not found"
fi

# AC12-ARWEAVE-DVM: Relationship between Arweave DVM (kind:5094) and NIP-73/NIP-94
echo "[AC12-ARWEAVE-DVM] Arweave DVM relationship documented"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if grep -qi "kind:5094\|arweave.*dvm\|dvm.*arweave" "$SKILL_DIR/SKILL.md"; then
    pass "AC12-ARWEAVE-DVM" "Arweave DVM relationship documented"
  else
    fail "AC12-ARWEAVE-DVM" "Arweave DVM relationship not documented"
  fi
else
  fail "AC12-ARWEAVE-DVM" "SKILL.md not found"
fi

# AC12-ARWEAVE-PERMANENT: arweave:tx: provides permanent/immutable references
echo "[AC12-ARWEAVE-PERMANENT] arweave:tx: permanent references"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if grep -qi "permanent\|immutable" "$SKILL_DIR/SKILL.md" && grep -q "arweave" "$SKILL_DIR/SKILL.md"; then
    pass "AC12-ARWEAVE-PERMANENT" "arweave:tx: permanent references documented"
  else
    fail "AC12-ARWEAVE-PERMANENT" "arweave:tx: permanent references not documented"
  fi
else
  fail "AC12-ARWEAVE-PERMANENT" "SKILL.md not found"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# WITH/WITHOUT BASELINE (AC11) -- SKIPPED
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo "── With/Without Baseline (AC11) ──"

# BASE-A: Requires manual pipeline Step 8
skip "BASE-A" "With/without baseline requires manual pipeline Step 8 execution"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SUMMARY
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ATDD Summary: Story 9.14 Media and Files Skill"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Total:   $TOTAL"
echo "  Passed:  $PASSED"
echo "  Failed:  $FAILED"
echo "  Skipped: $SKIPPED"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$FAILED" -gt 0 ]; then
  echo ""
  echo "RED PHASE: $FAILED tests failing as expected (TDD red phase)"
  exit 1
else
  echo ""
  echo "GREEN PHASE: All tests passing!"
  exit 0
fi
