#!/bin/bash
# Squad v4 — Claude Code Plugin Uninstaller

set -e

CLAUDE_DIR="$HOME/.claude"
PLUGIN_DIR="$CLAUDE_DIR/plugins/squad"

echo "=== Squad v4 Uninstaller ==="
echo ""

read -p "Remove Squad v4 plugin? (y/N): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
  echo "Cancelled."
  exit 0
fi

echo "[1/2] Removing plugin..."
if [ -d "$PLUGIN_DIR" ]; then
  rm -rf "$PLUGIN_DIR"
  echo "  Removed: $PLUGIN_DIR"
else
  echo "  Not found: $PLUGIN_DIR"
fi

# Remove backups
for bak in "${PLUGIN_DIR}".bak.*; do
  [ -d "$bak" ] && rm -rf "$bak" && echo "  Removed backup: $bak"
done

echo "[2/2] Removing project data (optional)..."
if [ -d ".claude/squad-memory" ]; then
  read -p "  Remove squad-memory/ learning data? (y/N): " confirm_mem
  if [[ "$confirm_mem" == "y" || "$confirm_mem" == "Y" ]]; then
    rm -rf ".claude/squad-memory"
    echo "  Removed."
  else
    echo "  Kept."
  fi
fi

for f in .claude/squad-state.md .claude/squad-plan.json .claude/squad-overlooked.md; do
  [ -f "$f" ] && rm "$f" && echo "  Removed: $f"
done

if [ -d ".claude/coordination" ]; then
  rm -rf ".claude/coordination"
  echo "  Removed: .claude/coordination/"
fi

echo ""
echo "=== Uninstall Complete ==="
