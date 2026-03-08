#!/bin/bash
# capture-memory.sh — 모든 tool 사용을 observations.jsonl에 기록
# PostToolUse hook, matcher: "Read|Edit|Write|Bash|Agent"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/_filelock.sh"

INPUT=$(cat)
MEMORY_DIR=".claude/squad-memory"
[ ! -d "$MEMORY_DIR" ] && exit 0

OBS_FILE="$MEMORY_DIR/observations.jsonl"
SESSION_ID="${CLAUDE_SESSION_ID:-$(date +%Y%m%d)-$$}"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# 단일 jq 호출: tool_name 검증 + JSONL 레코드 생성 (5→1 프로세스)
RECORD=$(echo "$INPUT" | jq -c --arg ts "$TIMESTAMP" --arg sid "$SESSION_ID" '
  (.tool_name // "") as $tool |
  if $tool == "" then empty else
  {
    timestamp: $ts,
    tool: $tool,
    input_summary: ((.tool_input // {}) | tostring | .[0:200]),
    output_summary: ((.tool_response // "") | tostring | .[0:200]),
    file: (.tool_input.file_path // .tool_input.path // ""),
    session_id: $sid
  } end
' 2>/dev/null)

[ -z "$RECORD" ] && exit 0

# acquire 성공 후에만 trap 설정
LOCK_DIR="$OBS_FILE.lck"
if filelock_acquire "$LOCK_DIR"; then
  trap 'filelock_release "$LOCK_DIR"' EXIT
else
  exit 0
fi

# 파일 크기 기반 로테이션 체크
MAX_OBS_BYTES=150000  # ~150KB ≈ 1000줄
if [ -f "$OBS_FILE" ]; then
  FILE_SIZE=$(stat -f%z "$OBS_FILE" 2>/dev/null || stat -c%s "$OBS_FILE" 2>/dev/null || echo 0)
  if [ "$FILE_SIZE" -gt "$MAX_OBS_BYTES" ] 2>/dev/null; then
    # mv 실패 시 .tmp 잔류 방지
    tail -250 "$OBS_FILE" > "$OBS_FILE.tmp" && mv -f "$OBS_FILE.tmp" "$OBS_FILE" || rm -f "$OBS_FILE.tmp"
  fi
fi

echo "$RECORD" >> "$OBS_FILE"

exit 0
