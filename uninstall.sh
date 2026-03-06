#!/bin/bash
# Squad v3 — Claude Code Plugin Uninstaller

set -e

CLAUDE_DIR="$HOME/.claude"
SKILL_DIR="$CLAUDE_DIR/skills/squad"
AGENT_DIR="$CLAUDE_DIR/agents"

AGENTS=(
  "clean-code-expert.md"
  "architect-expert.md"
  "bug-hunter.md"
  "test-expert.md"
  "perf-tuner.md"
  "type-guard.md"
  "react-pro.md"
  "rust-sage.md"
  "doc-writer.md"
  "code-fixer.md"
)

echo "=== Squad v3 Uninstaller ==="
echo ""

read -p "Remove Squad skill and all 10 agent files? (y/N): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
  echo "Cancelled."
  exit 0
fi

echo "[1/3] Removing skill files..."
rm -rf "$SKILL_DIR"
echo "  Done."

echo "[2/3] Removing agent files..."
for agent in "${AGENTS[@]}"; do
  if [ -f "$AGENT_DIR/$agent" ]; then
    rm "$AGENT_DIR/$agent"
    echo "  Removed $agent"
  fi
  # Restore backup if exists
  if [ -f "$AGENT_DIR/${agent}.bak" ]; then
    mv "$AGENT_DIR/${agent}.bak" "$AGENT_DIR/$agent"
    echo "  Restored ${agent} from backup"
  fi
done
echo "  Done."

echo "[3/3] Removing learning data (optional)..."
if [ -d "$CLAUDE_DIR/squad-memory" ]; then
  read -p "  Remove squad-memory/ learning data? (y/N): " confirm_mem
  if [[ "$confirm_mem" == "y" || "$confirm_mem" == "Y" ]]; then
    rm -rf "$CLAUDE_DIR/squad-memory"
    echo "  Removed."
  else
    echo "  Kept."
  fi
fi

if [ -f "$CLAUDE_DIR/squad-overlooked.md" ]; then
  rm "$CLAUDE_DIR/squad-overlooked.md"
  echo "  Removed squad-overlooked.md"
fi

echo ""
echo "=== Uninstall Complete ==="
