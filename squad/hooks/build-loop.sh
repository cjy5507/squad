#!/bin/bash
# build-loop.sh — build 모드 Stop hook (ralph-style 지속 실행)
# build 모드 활성 + 미완료 시 → 종료 차단, 재실행 지시

STATE_FILE=".claude/squad-state.md"

# state 파일 없으면 build 모드가 아님
[ ! -f "$STATE_FILE" ] && exit 0

# STATE_FILE 한 번 읽기로 모든 필드 파싱 (0 fork)
STATUS="" MODE="" CURRENT_ITER="" MAX_ITER="" HAS_ITER=""
while IFS= read -r line; do
  case "$line" in
    status:*)     STATUS="${line#status:}"; STATUS="${STATUS# }" ;;
    mode:*)       MODE="${line#mode:}"; MODE="${MODE# }" ;;
    iterations:*) CURRENT_ITER="${line#iterations:}"; CURRENT_ITER="${CURRENT_ITER# }"; HAS_ITER=1 ;;
    max_iter:*)   MAX_ITER="${line#max_iter:}"; MAX_ITER="${MAX_ITER# }" ;;
  esac
done < "$STATE_FILE"

case "$STATUS" in
  complete) rm -f "$STATE_FILE"; exit 0 ;;
  failed|cancelled) exit 0 ;;
esac

if [ "$MODE" = "build" ]; then
  CURRENT_ITER=${CURRENT_ITER:-0}
  [[ "$CURRENT_ITER" =~ ^[0-9]+$ ]] || CURRENT_ITER=0
  MAX_ITER=${MAX_ITER:-10}
  [[ "$MAX_ITER" =~ ^[0-9]+$ ]] || MAX_ITER=10

  # max 도달 시 자동 종료
  if [ "$CURRENT_ITER" -ge "$MAX_ITER" ] 2>/dev/null; then
    jq -cn --arg max "$MAX_ITER" \
      '{hookSpecificOutput:{hookEventName:"Stop",stopDecision:"allow",stopReason:"SQUAD BUILD 최대 반복 횟수(\($max)회)에 도달했습니다. 자동 종료합니다. 필요 시 /squad:build --max-iter N으로 횟수를 늘려 재시작하세요."}}'
    exit 0
  fi

  # iteration 카운터 증가
  NEW_ITER=$((CURRENT_ITER + 1))
  if [ -n "$HAS_ITER" ]; then
    if [[ "$OSTYPE" == darwin* ]]; then
      sed -i '' "s/^iterations:.*/iterations: $NEW_ITER/" "$STATE_FILE" 2>/dev/null
    else
      sed -i "s/^iterations:.*/iterations: $NEW_ITER/" "$STATE_FILE" 2>/dev/null
    fi
  else
    echo "iterations: $NEW_ITER" >> "$STATE_FILE"
  fi

  jq -cn --arg iter "$NEW_ITER" --arg max "$MAX_ITER" --arg sf "$STATE_FILE" \
    '{hookSpecificOutput:{hookEventName:"Stop",stopDecision:"block",stopReason:"SQUAD BUILD 미완료 (반복 \($iter)/\($max)). 현재 상태를 확인하고 다음 단계를 계속 진행하세요. 상태 파일: \($sf)"}}'
  exit 0
fi

exit 0
