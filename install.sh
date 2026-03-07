#!/bin/bash
# Squad v3 — Claude Code Plugin Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/cjy5507/squad/main/install.sh | bash

set -e

CLAUDE_DIR="$HOME/.claude"
SKILL_DIR="$CLAUDE_DIR/skills/squad"
AGENT_DIR="$CLAUDE_DIR/agents"
REPO_URL="https://github.com/cjy5507/squad.git"
TEMP_DIR=$(mktemp -d)

echo "=== Squad v3 Installer ==="
echo ""

# Clone repo
echo "[1/4] Downloading Squad..."
git clone --depth 1 "$REPO_URL" "$TEMP_DIR/squad" 2>/dev/null
echo "  Done."

# Install skill files
echo "[2/4] Installing skill files to $SKILL_DIR..."
mkdir -p "$SKILL_DIR"
cp "$TEMP_DIR/squad/skill/SKILL.md" "$SKILL_DIR/"
cp "$TEMP_DIR/squad/skill/checklists.md" "$SKILL_DIR/"
cp "$TEMP_DIR/squad/skill/cost-guide.md" "$SKILL_DIR/"
cp "$TEMP_DIR/squad/skill/strategy-guide.md" "$SKILL_DIR/"
cp "$TEMP_DIR/squad/skill/lang-rules.md" "$SKILL_DIR/"
echo "  Done."

# Install agent files
echo "[3/4] Installing agent files to $AGENT_DIR..."
mkdir -p "$AGENT_DIR"
for f in "$TEMP_DIR/squad/agents/"*.md; do
  filename=$(basename "$f")
  if [ -f "$AGENT_DIR/$filename" ]; then
    echo "  WARNING: $filename already exists, backing up to ${filename}.bak"
    cp "$AGENT_DIR/$filename" "$AGENT_DIR/${filename}.bak"
  fi
  cp "$f" "$AGENT_DIR/"
done
echo "  Done."

# Cleanup
echo "[4/4] Cleaning up..."
rm -rf "$TEMP_DIR"
echo "  Done."

echo ""
echo "=== Installation Complete ==="
echo ""
echo "Installed:"
echo "  Skill:  $SKILL_DIR/SKILL.md (+ 4 reference docs)"
echo "  Agents: $AGENT_DIR/ (10 expert agents)"
echo ""
echo "Usage:"
echo "  /squad src/hooks/          # Analyze"
echo "  /squad fix src/hooks/      # Auto-Fix"
echo "  /squad tdd src/components/ # TDD generation"
echo "  /squad team src/           # Team mode"
echo "  /squad init                # Initialize learning directory"
echo ""
echo "Docs: https://github.com/cjy5507/squad"
