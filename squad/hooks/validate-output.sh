#!/bin/bash
# validate-output.sh — 에이전트 JSON 출력 검증
# PreToolUse hook: Agent tool 호출 시 실행

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

# Agent tool 호출이 아니면 패스
[ "$TOOL_NAME" != "Agent" ] && exit 0

RESPONSE=$(echo "$INPUT" | jq -r '.tool_response // empty')
[ -z "$RESPONSE" ] && exit 0

# markdown fence 제거 후 JSON 파싱
CLEANED=$(echo "$RESPONSE" | sed 's/^```json//;s/^```//;s/```$//')
if ! echo "$CLEANED" | jq empty 2>/dev/null; then
  echo "WARNING: 에이전트가 유효한 JSON을 반환하지 않았습니다."
  exit 0
fi

# 필수 필드 체크
AGENT=$(echo "$CLEANED" | jq -r '.agent // empty')
FINDINGS=$(echo "$CLEANED" | jq -r '.findings // empty')
if [ -z "$AGENT" ] || [ "$FINDINGS" = "null" ]; then
  echo "WARNING: JSON에 agent 또는 findings 필드가 누락되었습니다."
fi

exit 0
