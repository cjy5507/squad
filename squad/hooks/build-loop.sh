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

# 취소 상태 확인
if grep -q "^status: cancelled" "$STATE_FILE" 2>/dev/null; then
  exit 0
fi

# build 모드 활성 + 미완료 → iteration 카운터 체크 후 계속 진행 지시
if grep -q "^mode: build" "$STATE_FILE" 2>/dev/null; then

  # 현재 iteration 읽기 (없으면 0)
  CURRENT_ITER=$(grep '^iterations:' "$STATE_FILE" 2>/dev/null | awk '{print $2}')
  CURRENT_ITER=${CURRENT_ITER:-0}

  # max_iter 읽기 (없으면 기본값 10)
  MAX_ITER=$(grep '^max_iter:' "$STATE_FILE" 2>/dev/null | awk '{print $2}')
  MAX_ITER=${MAX_ITER:-10}

  # max 도달 시 자동 종료
  if [ "$CURRENT_ITER" -ge "$MAX_ITER" ] 2>/dev/null; then
    echo '{"hookSpecificOutput":{"hookEventName":"Stop","stopDecision":"allow","stopReason":"SQUAD BUILD 최대 반복 횟수('"$MAX_ITER"'회)에 도달했습니다. 자동 종료합니다. 필요 시 /squad:build --max-iter N으로 횟수를 늘려 재시작하세요."}}'
    exit 0
  fi

  # iteration 카운터 증가
  NEW_ITER=$((CURRENT_ITER + 1))
  if grep -q '^iterations:' "$STATE_FILE" 2>/dev/null; then
    sed -i '' "s/^iterations:.*/iterations: $NEW_ITER/" "$STATE_FILE" 2>/dev/null || \
    sed -i "s/^iterations:.*/iterations: $NEW_ITER/" "$STATE_FILE" 2>/dev/null
  else
    echo "iterations: $NEW_ITER" >> "$STATE_FILE"
  fi

  echo '{"hookSpecificOutput":{"hookEventName":"Stop","stopDecision":"block","stopReason":"SQUAD BUILD 미완료 (반복 '"$NEW_ITER"'/'"$MAX_ITER"'). 현재 상태를 확인하고 다음 단계를 계속 진행하세요. 상태 파일: '"$STATE_FILE"'"}}'
  exit 0
fi

exit 0
