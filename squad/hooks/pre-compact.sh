#!/bin/bash
# pre-compact.sh — 컴팩션 전 학습 상태 저장
# PreCompact hook: 컨텍스트 압축 전 현재 세션 요약 저장

MEMORY_DIR=".claude/squad-memory"
SUMMARY_FILE="$MEMORY_DIR/session-summary.md"
STATE_FILE=".claude/squad-state.md"
HISTORY_FILE="$MEMORY_DIR/fix-history.jsonl"

# squad-memory 디렉토리 없으면 패스
[ ! -d "$MEMORY_DIR" ] && exit 0

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# 현재 모드/상태 추출
MODE="none"
STATUS="none"
TASK=""
if [ -f "$STATE_FILE" ]; then
  MODE=$(grep '^mode:' "$STATE_FILE" 2>/dev/null | awk '{print $2}')
  STATUS=$(grep '^status:' "$STATE_FILE" 2>/dev/null | awk '{print $2}')
  TASK=$(grep '^task:' "$STATE_FILE" 2>/dev/null | sed 's/^task: //')
fi

# fix-history에서 세션 통계 추출
TOTAL_FIXES=0
AGENTS_USED=""
if [ -f "$HISTORY_FILE" ]; then
  TOTAL_FIXES=$(wc -l < "$HISTORY_FILE" | tr -d ' ')
  AGENTS_USED=$(jq -r '.agent' "$HISTORY_FILE" 2>/dev/null | sort -u | tr '\n' ', ' | sed 's/,$//')
fi

# session-summary.md에 추가 (append)
cat >> "$SUMMARY_FILE" << EOF

---
## Session: $TIMESTAMP
- mode: $MODE
- status: $STATUS
- task: $TASK
- fixes applied: $TOTAL_FIXES
- agents used: $AGENTS_USED
EOF

exit 0
