#!/bin/bash
# track-fix.sh — Edit 사용 시 수정 이력 추적 (fix-history.jsonl)
# PostToolUse hook: fix/build 모드에서 Edit tool 호출 후 실행

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/_filelock.sh"

INPUT=$(cat)
read -r TOOL_NAME FILE_PATH <<< "$(echo "$INPUT" | jq -r '[.tool_name // "", .tool_input.file_path // ""] | @tsv')"

# Edit tool이 아니면 패스
[ "$TOOL_NAME" != "Edit" ] && exit 0

STATE_FILE=".claude/squad-state.md"
MEMORY_DIR=".claude/squad-memory"
HISTORY_FILE="$MEMORY_DIR/fix-history.jsonl"

# squad-memory 디렉토리 없으면 패스
[ ! -d "$MEMORY_DIR" ] && exit 0

# STATE_FILE 파싱: while-read+case (순수 bash, 0 fork)
if [ -f "$STATE_FILE" ]; then
  while IFS= read -r line; do
    case "$line" in
      mode:*)     MODE="${line#mode:}"; MODE="${MODE# }" ;;
      agent:*)    AGENT="${line#agent:}"; AGENT="${AGENT# }" ;;
      severity:*) SEVERITY="${line#severity:}"; SEVERITY="${SEVERITY# }" ;;
      title:*)    TITLE="${line#title:}"; TITLE="${TITLE# }" ;;
    esac
  done < "$STATE_FILE"
  case "$MODE" in
    fix|build) ;;
    *) exit 0 ;;
  esac
else
  exit 0
fi

[ -z "$FILE_PATH" ] && exit 0
: "${AGENT:=unknown}" "${SEVERITY:=unknown}" "${TITLE:=}"

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# acquire 성공 후에만 trap 설정
LOCK_DIR="$HISTORY_FILE.lck"
if filelock_acquire "$LOCK_DIR"; then
  trap 'filelock_release "$LOCK_DIR"' EXIT
else
  exit 0
fi

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
