#!/bin/bash
# inject-memory.sh — 세션 시작 시 이전 컨텍스트 주입
# SessionStart hook, matcher: "" (모든 세션 시작)
# - 기존 compact 재개 로직 수행
# - observations.jsonl에서 최근 50개 관찰 요약 주입

STATE_FILE=".claude/squad-state.md"
MEMORY_DIR=".claude/squad-memory"
OBS_FILE="$MEMORY_DIR/observations.jsonl"

PARTS=""

# Part 1: compact 재개 로직 (in-progress 작업 있으면 알림)
if [ -f "$STATE_FILE" ]; then
  STATUS="" MODE="" PHASE="" TASK="" ITER="" MAX=""
  while IFS= read -r line; do
    case "$line" in
      status:*)     STATUS="${line#status:}"; STATUS="${STATUS# }" ;;
      mode:*)       MODE="${line#mode:}"; MODE="${MODE# }" ;;
      phase:*)      PHASE="${line#phase:}"; PHASE="${PHASE# }" ;;
      task:*)       TASK="${line#task:}"; TASK="${TASK# }" ;;
      iterations:*) ITER="${line#iterations:}"; ITER="${ITER# }" ;;
      max_iter:*)   MAX="${line#max_iter:}"; MAX="${MAX# }" ;;
    esac
  done < "$STATE_FILE"

  [ "$STATUS" != "in-progress" ] && STATUS=""
fi

if [ -n "$STATUS" ]; then
  RESUME="[Squad] ${MODE} 모드가 중단되었습니다. squad-state.md를 읽고 이어서 진행하세요."
  if [ -n "$PHASE" ]; then
    RESUME="${RESUME} (마지막 phase: ${PHASE}"
    if [ -n "$ITER" ] && [ -n "$MAX" ]; then
      RESUME="${RESUME}, 반복: ${ITER}/${MAX}"
    fi
    RESUME="${RESUME})"
  fi
  [ -n "$TASK" ] && RESUME="${RESUME} task: ${TASK}"

  PARTS="$RESUME"
fi

# Part 2: 최근 관찰 50개 주입 (observations.jsonl 존재 시)
if [ -f "$OBS_FILE" ] && [ -s "$OBS_FILE" ]; then
  RECENT=$(tail -50 "$OBS_FILE" | jq -r '"[\(.timestamp)] \(.tool)\(if .file != "" then " (\(.file))" else "" end): \(.input_summary)" ' 2>/dev/null | tr -d '\000-\010\013-\037')
  if [ -n "$RECENT" ]; then
    OBS_MSG="이전 세션 컨텍스트 (최근 관찰):
$RECENT"
    if [ -n "$PARTS" ]; then
      PARTS="${PARTS}

${OBS_MSG}"
    else
      PARTS="$OBS_MSG"
    fi
  fi
fi

[ -z "$PARTS" ] && exit 0

# JSON 출력 (printf + jq -Rs로 newline 이스케이프 보장)
printf '%s' "$PARTS" | jq -Rsn '{addToConversation: input}'

exit 0
