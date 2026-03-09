#!/bin/bash
# validate-output.sh — 에이전트 JSON 출력 검증 (단일 jq 통합)
# PostToolUse hook: Agent tool 응답 후 실행

INPUT=$(cat)

# 단일 jq 호출: tool_name 체크 + response 추출 + fence 제거 + 검증 통합
RESULT=$(echo "$INPUT" | jq -r '
  (.tool_name // "") as $tool |
  if $tool != "Agent" then "SKIP" else
    ((.tool_response.response // .tool_response // "") | tostring) as $resp |
    if $resp == "" then "SKIP" else
      # fence 제거: 첫 번째 ```json...``` 블록 추출 (대소문자 무시)
      ($resp | split("\n") | . as $lines |
        (reduce range(length) as $i (
          {state: "before", start: -1, end: -1};
          if .state == "before" and ($lines[$i] | test("^\\s*```json\\s*$"; "i")) then
            .state = "inside" | .start = ($i + 1)
          elif .state == "inside" and ($lines[$i] | test("^\\s*```\\s*$")) then
            .state = "done" | .end = $i
          else . end
        )) as $range |
        if $range.start >= 0 and $range.end > $range.start then
          $lines[$range.start:$range.end] | join("\n")
        else $resp end
      ) as $cleaned |
      ($cleaned | try fromjson catch null) as $parsed |
      if $parsed == null then "INVALID_JSON"
      elif ($parsed | .agent // "" | length) > 0 and ($parsed | .findings | type) == "array" then "OK"
      else "MISSING_FIELDS"
      end
    end
  end
' 2>/dev/null)

case "$RESULT" in
  INVALID_JSON)
    echo "WARNING: 에이전트가 유효한 JSON을 반환하지 않았습니다." >&2
    jq -cn '{addToConversation:"[Squad BLOCKED] 에이전트가 유효한 JSON을 반환하지 않았습니다. findings.json에 저장하지 않습니다. 에이전트 출력을 확인하고 JSON 형식으로 재요청하세요."}'
    exit 0
    ;;
  MISSING_FIELDS)
    echo "WARNING: JSON에 agent 또는 findings 필드가 누락되었습니다." >&2
    jq -cn '{addToConversation:"[Squad WARNING] 에이전트 JSON에 agent 또는 findings 필드가 누락되었습니다. json-contract.md 형식을 확인하세요."}'
    exit 0
    ;;
esac

exit 0
