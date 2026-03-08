#!/bin/bash
# guard-plan-mode.sh — 읽기 전용 모드(analyze/plan/review)에서 파일 수정 차단
# PreToolUse hook으로 사용 시: Edit/Write tool 호출 차단
# analyze/plan/review 모드에서 파일 수정 차단

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

# Edit 또는 Write가 아니면 패스
case "$TOOL_NAME" in
  Edit|Write) ;;
  *) exit 0 ;;
esac

STATE_FILE=".claude/squad-state.md"
[ ! -f "$STATE_FILE" ] && exit 0

MODE=""
while IFS= read -r line; do
  case "$line" in mode:*) MODE="${line#mode:}"; MODE="${MODE# }"; break ;; esac
done < "$STATE_FILE"
case "$MODE" in
  analyze|plan|review)
    echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"'"$MODE"' 모드에서는 소스 코드 수정이 금지됩니다. 읽기 전용 모드에서는 코드를 수정하지 마세요."}}'
    exit 0
    ;;
esac

exit 0
