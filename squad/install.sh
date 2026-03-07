#!/bin/bash
# Squad v4 — Claude Code Plugin Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/cjy5507/squad/main/squad/install.sh | bash

set -e

REPO_URL="https://github.com/cjy5507/squad.git"
TEMP_DIR=$(mktemp -d)
CLAUDE_DIR="$HOME/.claude"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "=== Squad v4 Installer ==="
echo ""

# Clone
echo "[1/4] Downloading Squad v4..."
git clone --depth 1 "$REPO_URL" "$TEMP_DIR/squad" 2>/dev/null
echo "  Done."

# Detect install mode
echo "[2/4] Detecting install mode..."
PLUGIN_DIR=""
if [ -d "$CLAUDE_DIR/plugins" ]; then
  PLUGIN_DIR="$CLAUDE_DIR/plugins/squad"
  echo "  Plugin mode: $PLUGIN_DIR"
else
  PLUGIN_DIR="$CLAUDE_DIR/plugins/squad"
  mkdir -p "$CLAUDE_DIR/plugins"
  echo "  Plugin mode (new): $PLUGIN_DIR"
fi

# Backup existing
if [ -d "$PLUGIN_DIR" ]; then
  echo "  Backing up existing installation to squad.bak.$TIMESTAMP"
  mv "$PLUGIN_DIR" "${PLUGIN_DIR}.bak.${TIMESTAMP}"
fi

# Legacy cleanup
LEGACY_SKILL="$CLAUDE_DIR/skills/squad"
LEGACY_AGENTS=(
  clean-code-expert.md architect-expert.md bug-hunter.md
  test-expert.md perf-tuner.md type-guard.md
  react-pro.md rust-sage.md doc-writer.md code-fixer.md
)

if [ -d "$LEGACY_SKILL" ]; then
  echo "  Removing legacy v3 skill files..."
  rm -rf "$LEGACY_SKILL"
fi

for agent in "${LEGACY_AGENTS[@]}"; do
  if [ -f "$CLAUDE_DIR/agents/$agent" ]; then
    echo "  Removing legacy agent: $agent"
    rm "$CLAUDE_DIR/agents/$agent"
  fi
done

# Install
echo "[3/4] Installing Squad v4..."
cp -r "$TEMP_DIR/squad/squad" "$PLUGIN_DIR"
chmod +x "$PLUGIN_DIR/hooks/"*.sh
echo "  Done."

# Cleanup
echo "[4/4] Cleaning up..."
rm -rf "$TEMP_DIR"
echo "  Done."

echo ""
echo "=== Installation Complete ==="
echo ""
echo "Installed to: $PLUGIN_DIR"
echo ""
echo "Commands:"
echo "  /squad:analyze src/     # Code analysis"
echo "  /squad:fix src/         # Auto-fix with self-correction"
echo "  /squad:build \"task\"     # Implement until done"
echo "  /squad:review           # PR review"
echo "  /squad:team src/        # Team mode (parallel)"
echo "  /squad:init             # Initialize project learning"
echo ""
echo "Docs: https://github.com/cjy5507/squad"
