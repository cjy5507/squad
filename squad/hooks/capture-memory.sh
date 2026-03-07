#!/bin/bash
# capture-memory.sh — 모든 tool 사용을 observations.jsonl에 기록
# PostToolUse hook, matcher: "*"

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
[ -z "$TOOL_NAME" ] && exit 0

MEMORY_DIR=".claude/squad-memory"
[ ! -d "$MEMORY_DIR" ] && exit 0

OBS_FILE="$MEMORY_DIR/observations.jsonl"
SESSION_ID="${CLAUDE_SESSION_ID:-$(date +%Y%m%d)-$$}"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# input/output 첫 200자만 추출 (토큰 절약)
INPUT_SUMMARY=$(echo "$INPUT" | jq -r '(.tool_input // {}) | tostring' 2>/dev/null | cut -c1-200)
OUTPUT_SUMMARY=$(echo "$INPUT" | jq -r '(.tool_response // "") | tostring' 2>/dev/null | cut -c1-200)

# 파일 경로 추출 (있으면)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // ""' 2>/dev/null)

# JSONL에 안전하게 한 줄 추가 (jq로 이스케이프 처리)
jq -cn \
  --arg ts "$TIMESTAMP" \
  --arg tool "$TOOL_NAME" \
  --arg input "$INPUT_SUMMARY" \
  --arg output "$OUTPUT_SUMMARY" \
  --arg file "$FILE" \
  --arg sid "$SESSION_ID" \
  '{timestamp:$ts,tool:$tool,input_summary:$input,output_summary:$output,file:$file,session_id:$sid}' \
  >> "$OBS_FILE" 2>/dev/null

exit 0
