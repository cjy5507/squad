#!/bin/bash
# session-resume.sh — 컴팩션 후 자동 재개 hook
# SessionStart(compact) hook: 컴팩션으로 세션이 재시작됐을 때 진행 중인 작업을 알림

STATE_FILE=".claude/squad-state.md"

# state 파일 없으면 재개할 작업 없음
[ ! -f "$STATE_FILE" ] && exit 0

# in-progress 상태인지 확인
if grep -q "^status: in-progress" "$STATE_FILE" 2>/dev/null; then
  MODE=$(grep '^mode:' "$STATE_FILE" 2>/dev/null | awk '{print $2}')
  PHASE=$(grep '^phase:' "$STATE_FILE" 2>/dev/null | awk '{print $2}')
  TASK=$(grep '^task:' "$STATE_FILE" 2>/dev/null | sed 's/^task: //')
  ITER=$(grep '^iterations:' "$STATE_FILE" 2>/dev/null | awk '{print $2}')
  MAX=$(grep '^max_iter:' "$STATE_FILE" 2>/dev/null | awk '{print $2}')

  MSG="Squad ${MODE} 모드가 컴팩션 전에 중단되었습니다. squad-state.md를 읽고 이어서 진행하세요."
  if [ -n "$PHASE" ]; then
    MSG="${MSG} (마지막 phase: ${PHASE}"
    if [ -n "$ITER" ] && [ -n "$MAX" ]; then
      MSG="${MSG}, 반복: ${ITER}/${MAX}"
    fi
    MSG="${MSG})"
  fi
  if [ -n "$TASK" ]; then
    MSG="${MSG} task: ${TASK}"
  fi

  printf '{"addToConversation":"%s"}\n' "$MSG"
fi

exit 0
