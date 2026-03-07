#!/bin/bash
# guard-plan-mode.sh — analyze 모드에서 파일 수정 차단
# PreToolUse hook으로 사용 시: Edit/Write tool 호출 차단

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

# Edit 또는 Write가 아니면 패스
case "$TOOL_NAME" in
  Edit|Write) ;;
  *) exit 0 ;;
esac

STATE_FILE=".claude/squad-state.md"
[ ! -f "$STATE_FILE" ] && exit 0

if grep -q "^mode: analyze" "$STATE_FILE" 2>/dev/null; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"analyze 모드에서는 파일 수정이 금지됩니다. 분석 전용 모드에서는 코드 수정을 하지 마세요."}}'
  exit 0
fi

exit 0
