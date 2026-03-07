# JSON 출력 계약 (공유 레퍼런스)

모든 분석 에이전트는 이 형식으로 결과를 반환합니다.

```json
{
  "agent": "에이전트명",
  "files_analyzed": ["파일1", "파일2"],
  "findings": [
    {
      "severity": "critical|major|minor|info",
      "confidence": 85,
      "title": "발견 제목",
      "file": "파일 경로",
      "line": 0,
      "description": "구체적 설명",
      "evidence": "이 발견을 뒷받침하는 구체적 증거",
      "old_string": "현재 코드 (Edit용 정확한 문자열)",
      "new_string": "수정된 코드",
      "auto_fixable": true,
      "defer_to": null,
      "rationale": "왜 이것이 문제인지",
      "task_alignment": "원래 분석 목표와의 관련성"
    }
  ],
  "score": { "항목": "X/10" },
  "passed": true
}
```

## 필드 규칙

- `severity`: critical=데이터손실/보안/크래시, major=기능오작동, minor=개선권장, info=제안
- `confidence`: 0-100 정수. **80 미만은 리포트에서 필터링됨**
- `evidence`: 발견을 뒷받침하는 구체적 코드/상황 (필수)
- `old_string`: 파일에서 **정확히 복사** (공백, 줄바꿈 포함)
- `auto_fixable`: false → 구조 변경, 설계 판단 등 자동 수정 불가
- `defer_to`: 자기 영역 외 → 해당 전문가명 설정, 수정안 제시 금지
- `task_alignment`: Anti-drift 검증용, 원래 목표와의 관련성 1줄 설명
