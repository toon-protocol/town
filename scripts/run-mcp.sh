#!/usr/bin/env bash
# Wrapper script to load .env.publish credentials before launching MCP servers
# Usage: ./scripts/run-mcp.sh <mcp-package-name>

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$PROJECT_ROOT/.env.publish"

# Load credentials if the file exists
if [ -f "$ENV_FILE" ]; then
  set -a
  source "$ENV_FILE"
  set +a
fi

# Run the MCP server
exec npx "$@"
