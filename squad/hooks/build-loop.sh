#!/bin/bash
# build-loop.sh — build 모드 Stop hook (ralph-style 지속 실행)
# build 모드 활성 + 미완료 시 → 종료 차단, 재실행 지시

STATE_FILE=".claude/squad-state.md"

# state 파일 없으면 build 모드가 아님
[ ! -f "$STATE_FILE" ] && exit 0

# 완료 표시 확인
if grep -q "^status: complete" "$STATE_FILE" 2>/dev/null; then
  rm -f "$STATE_FILE"
  exit 0
fi

if grep -q "^status: failed" "$STATE_FILE" 2>/dev/null; then
  exit 0
fi

# build 모드 활성 + 미완료 → 계속 진행 지시
if grep -q "^mode: build" "$STATE_FILE" 2>/dev/null; then
  echo '{"hookSpecificOutput":{"hookEventName":"Stop","stopDecision":"block","stopReason":"SQUAD BUILD 미완료. 현재 상태를 확인하고 다음 단계를 계속 진행하세요. 상태 파일: '"$STATE_FILE"'"}}'
  exit 0
fi

exit 0
