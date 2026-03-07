#!/bin/bash
# track-fix.sh — Edit 사용 시 수정 이력 추적
# PostToolUse hook: fix/build 모드에서 Edit tool 호출 후 실행

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

# Edit tool이 아니면 패스
[ "$TOOL_NAME" != "Edit" ] && exit 0

STATE_FILE=".claude/squad-state.md"
MEMORY_DIR=".claude/squad-memory"
HISTORY_FILE="$MEMORY_DIR/fix-history.jsonl"

# squad-memory 디렉토리 없으면 패스
[ ! -d "$MEMORY_DIR" ] && exit 0

# fix 또는 build 모드가 아니면 패스
if [ -f "$STATE_FILE" ]; then
  MODE=$(grep '^mode:' "$STATE_FILE" 2>/dev/null | awk '{print $2}')
  case "$MODE" in
    fix|build) ;;
    *) exit 0 ;;
  esac
else
  exit 0
fi

# Edit 대상 파일 경로 추출
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
[ -z "$FILE_PATH" ] && exit 0

# 현재 state에서 에이전트/severity 정보 추출
AGENT=$(grep '^agent:' "$STATE_FILE" 2>/dev/null | awk '{print $2}')
[ -z "$AGENT" ] && AGENT="unknown"
SEVERITY=$(grep '^severity:' "$STATE_FILE" 2>/dev/null | awk '{print $2}')
[ -z "$SEVERITY" ] && SEVERITY="unknown"
TITLE=$(grep '^title:' "$STATE_FILE" 2>/dev/null | sed 's/^title: //')
[ -z "$TITLE" ] && TITLE=""

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# JSONL에 한 줄 추가 (jq로 안전하게 이스케이프)
jq -cn \
  --arg ts "$TIMESTAMP" \
  --arg file "$FILE_PATH" \
  --arg agent "$AGENT" \
  --arg sev "$SEVERITY" \
  --arg title "$TITLE" \
  --arg mode "$MODE" \
  '{timestamp:$ts,file:$file,agent:$agent,severity:$sev,title:$title,mode:$mode}' \
  >> "$HISTORY_FILE" 2>/dev/null

exit 0
