#!/usr/bin/env bash
# Quick publish helper — sources .env.publish credentials before running CLI tools
# Usage:
#   ./scripts/publish.sh nostr <article.md> <slug> <title> [summary]
#   ./scripts/publish.sh tweet <thread-file.md>
#   ./scripts/publish.sh hashnode <article.md> <slug> <title>
#   ./scripts/publish.sh devto <article.md> <title> <canonical-url>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$PROJECT_ROOT/.env.publish"

# Load credentials
if [ -f "$ENV_FILE" ]; then
  set -a
  source "$ENV_FILE"
  set +a
else
  echo "ERROR: $ENV_FILE not found. Create it from the template."
  exit 1
fi

case "${1:-help}" in
  nostr)
    FILE="$2"
    SLUG="$3"
    TITLE="$4"
    SUMMARY="${5:-}"

    if [ -z "$NOSTR_PRIVKEY" ]; then
      echo "ERROR: NOSTR_PRIVKEY not set in .env.publish"
      exit 1
    fi

    TAGS=(--tag "d=$SLUG" --tag "title=$TITLE" --tag "published_at=$(date +%s)")
    [ -n "$SUMMARY" ] && TAGS+=(--tag "summary=$SUMMARY")
    TAGS+=(--tag "t=nostr" --tag "t=relay")

    echo "Publishing NIP-23 article: $TITLE"
    echo "Slug: $SLUG"
    echo "Relays: ${NOSTR_RELAYS:-wss://relay.damus.io wss://nos.lol wss://relay.nostr.band}"
    echo ""

    # shellcheck disable=SC2086
    nak event --sec "$NOSTR_PRIVKEY" -k 30023 \
      -c "$(cat "$FILE")" \
      "${TAGS[@]}" \
      ${NOSTR_RELAYS:-wss://relay.damus.io wss://nos.lol wss://relay.nostr.band}

    echo ""
    echo "Published to Nostr!"
    ;;

  hashnode)
    FILE="$2"
    SLUG="$3"
    TITLE="$4"

    if [ -z "$HASHNODE_PAT" ] || [ -z "$HASHNODE_PUBLICATION_ID" ]; then
      echo "ERROR: HASHNODE_PAT and HASHNODE_PUBLICATION_ID must be set in .env.publish"
      exit 1
    fi

    CONTENT="$(cat "$FILE" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')"
    TITLE_ESC="$(echo "$TITLE" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read().strip()))')"

    echo "Publishing to Hashnode: $TITLE"

    curl -s -X POST https://gql.hashnode.com \
      -H "Authorization: $HASHNODE_PAT" \
      -H "Content-Type: application/json" \
      -d "{\"query\":\"mutation { publishPost(input: { publicationId: \\\"$HASHNODE_PUBLICATION_ID\\\", title: $TITLE_ESC, contentMarkdown: $CONTENT, slug: \\\"$SLUG\\\" }) { post { id url } } }\"}" | python3 -m json.tool
    ;;

  devto)
    FILE="$2"
    TITLE="$3"
    CANONICAL="${4:-}"

    if [ -z "$DEVTO_API_KEY" ]; then
      echo "ERROR: DEVTO_API_KEY not set in .env.publish"
      exit 1
    fi

    CONTENT="$(cat "$FILE" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')"
    TITLE_ESC="$(echo "$TITLE" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read().strip()))')"

    CANONICAL_FIELD=""
    [ -n "$CANONICAL" ] && CANONICAL_FIELD=",\"canonical_url\":\"$CANONICAL\""

    echo "Publishing to Dev.to: $TITLE"

    curl -s -X POST https://dev.to/api/articles \
      -H "api-key: $DEVTO_API_KEY" \
      -H "Content-Type: application/json" \
      -d "{\"article\":{\"title\":$TITLE_ESC,\"body_markdown\":$CONTENT,\"published\":false,\"tags\":[\"nostr\",\"relay\",\"web3\",\"ai\"]$CANONICAL_FIELD}}" | python3 -m json.tool

    echo ""
    echo "Published as DRAFT on Dev.to (set published:true to go live)"
    ;;

  help|*)
    echo "Usage:"
    echo "  $0 nostr <article.md> <slug> <title> [summary]"
    echo "  $0 hashnode <article.md> <slug> <title>"
    echo "  $0 devto <article.md> <title> [canonical-url]"
    echo ""
    echo "Credentials loaded from: $ENV_FILE"
    ;;
esac
