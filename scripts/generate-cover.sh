#!/usr/bin/env bash
# Generate a blog cover image using Replicate Nano Banana Pro, then resize for Dev.to
# Usage: ./scripts/generate-cover.sh "prompt text" output-path.png
#
# Requires: REPLICATE_API_TOKEN in .env.publish, ImageMagick (magick)
# Dev.to cover spec: 1000x420 pixels
#
# Character spec (for consistent mascot across articles):
#   Prepend the CHARACTER_PREFIX to your prompt for consistent "Relay Bot" character.
#   See _bmad-output/planning-artifacts/content/character-spec.md for full details.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$PROJECT_ROOT/.env.publish"

# Load credentials
if [ -f "$ENV_FILE" ]; then
  set -a
  source "$ENV_FILE"
  set +a
fi

PROMPT="${1:?Usage: $0 \"prompt\" output.png}"
OUTPUT="${2:?Usage: $0 \"prompt\" output.png}"

# Optional: prepend character spec for consistent mascot
USE_CHARACTER="${3:-}"

if [ -z "${REPLICATE_API_TOKEN:-}" ]; then
  echo "ERROR: REPLICATE_API_TOKEN not set in .env.publish"
  echo "Sign up at https://replicate.com and add your token"
  exit 1
fi

# Character prefix for consistent "Relay Bot" mascot
CHARACTER_PREFIX="1930s rubber hose cartoon animation style, hand-painted watercolor. A cartoon robot character named Relay Bot with a round vintage television set head. The face on the TV screen has exactly two simple round black dot eyes, a small curved line smile, and two small rosy pink circle cheeks like a classic smiley face. Small single antenna on top of the TV head. Wearing a small orange bow tie on the chest. White cartoon glove hands with no fingers. Bendy rubber hose style arms and legs. The full body must be visible including torso, both arms, and both legs. Simple rounded rectangular torso. Warm sepia cream orange and red watercolor tones, bold ink outlines, vintage Fleischer Studios animation aesthetic."

if [ "$USE_CHARACTER" = "--character" ]; then
  FULL_PROMPT="$CHARACTER_PREFIX $PROMPT"
  echo "Using Relay Bot character prefix"
else
  FULL_PROMPT="$PROMPT"
fi

echo "Generating image with Nano Banana Pro..."
echo "Prompt: $FULL_PROMPT"

# Create prediction via Nano Banana Pro (Google Gemini 3 Pro image model)
PROMPT_JSON=$(python3 -c "import sys,json; print(json.dumps(sys.argv[1]))" "$FULL_PROMPT")
RESPONSE=$(curl -s -X POST "https://api.replicate.com/v1/models/google/nano-banana-pro/predictions" \
  -H "Authorization: Bearer $REPLICATE_API_TOKEN" \
  -H "Content-Type: application/json" \
  -H "Prefer: wait" \
  -d "{
    \"input\": {
      \"prompt\": $PROMPT_JSON,
      \"aspect_ratio\": \"16:9\",
      \"output_format\": \"png\",
      \"safety_filter_level\": \"block_only_high\"
    }
  }")

# Extract image URL (Nano Banana returns string, not array)
IMAGE_URL=$(echo "$RESPONSE" | python3 -c "
import sys, json
d = json.load(sys.stdin)
if d.get('status') == 'succeeded' and d.get('output'):
    out = d['output']
    print(out if isinstance(out, str) else out[0] if isinstance(out, list) else '')
elif d.get('error'):
    print('ERROR:' + str(d['error']), file=sys.stderr)
    sys.exit(1)
else:
    print('ERROR: Unexpected response: ' + json.dumps(d)[:200], file=sys.stderr)
    sys.exit(1)
")

if [ -z "$IMAGE_URL" ]; then
  echo "ERROR: Failed to generate image"
  echo "$RESPONSE" | python3 -m json.tool
  exit 1
fi

echo "Generated: $IMAGE_URL"

# Download
TEMP_FILE=$(mktemp /tmp/cover-XXXXXX.png)
curl -s -o "$TEMP_FILE" "$IMAGE_URL"
echo "Downloaded to temp file"

# Resize to Dev.to spec (1000x420)
magick "$TEMP_FILE" -resize 1000x420^ -gravity center -extent 1000x420 -quality 92 "$OUTPUT"
rm "$TEMP_FILE"

echo "Resized to 1000x420 → $OUTPUT"
echo "Done!"
