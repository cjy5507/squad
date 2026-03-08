---
name: plan
description: 상세 구현 계획 — 코드 탐색 후 3가지 접근법을 제시하고 사용자 선택으로 구체적인 계획을 수립합니다.
argument-hint: "<기능 설명>"
---

# /squad:plan — 상세 구현 계획 수립

요청 기능을 분석하고 3가지 접근법을 비교한 후 선택된 안으로 구체적인 구현 계획을 수립합니다.

## 상태 관리

시작 시 `.claude/squad-state.md` 생성:
```
mode: plan
status: in-progress
phase: explore
task: {기능 설명}
started: {timestamp}
```

## 7단계 실행 절차

### Step 1: Explore

Agent 도구로 code-explorer 에이전트 호출:
- 목표: 요청 기능과 관련된 코드 파악
- 탐색: 관련 파일, 모듈 구조, 의존성, 기존 패턴
- 결과: 1000자 이내 구조화된 요약 반환

상태 업데이트: `phase: qa`

### Step 2: Q&A

탐색 결과를 바탕으로 구현에 필요한 핵심 질문 2-3개를 사용자에게 제시:

```
구현 계획을 위해 몇 가지 확인이 필요합니다:

1. [질문 1 — 예: 기존 인증 미들웨어를 재사용할까요, 새로 만들까요?]
2. [질문 2 — 예: 테스트 커버리지 범위는 어디까지 필요한가요?]
3. [질문 3 — 예: API 버저닝이 필요한가요?]
```

**사용자 답변 대기** — 답변을 받은 후 Step 3으로 진행.

상태 업데이트: `phase: approaches`

### Step 3: 접근법 3가지 제시

Agent 도구로 plan-architect 에이전트 호출:
- 입력: 기능 설명 + 탐색 요약 + Q&A 답변
- 출력: 3가지 접근법 비교표

출력 형식:
```
## 접근법 비교

| 항목 | 안 A | 안 B | 안 C |
|------|------|------|------|
| 전략 | ... | ... | ... |
| 변경 파일 | N개 | M개 | K개 |
| 예상 LOC | ~N | ~M | ~K |
| 리스크 | LOW | MID | HIGH |
| 장점 | ... | ... | ... |
| 단점 | ... | ... | ... |

### 안 A — [전략명]
변경 파일:
- src/auth/middleware.ts (신규)
- src/routes/api.ts (수정)
리스크: LOW — 기존 코드와 분리됨

### 안 B — [전략명]
...

### 안 C — [전략명]
...
```

### Step 4: 사용자 선택 대기

```
어떤 접근법으로 진행할까요? (A/B/C 또는 직접 수정사항 입력)
```

**사용자 선택 대기** — 선택을 받은 후 Step 5로 진행.

상태 업데이트: `phase: detail-plan`

### Step 5: 상세 구현 계획 수립

선택된 안을 기반으로 Agent 도구로 plan-architect 에이전트 재호출:
- 파일별 변경 목록 (라인 수준)
- 구현 순서 및 의존성
- 테스트 계획

계획을 **2가지 형식**으로 저장 (컨텍스트 최적화):

1. `.claude/squad-memory/plan.md` — 사람이 읽을 수 있는 마크다운
2. `.claude/squad-plan.json` — `/squad-build` Phase 3에서 바로 실행 가능한 JSON

**squad-plan.json 스키마** (build.md Phase 2와 동일한 공유 스키마):
```json
[{"file": "경로", "changes": [{"line": N, "old_string": "현재코드", "new_string": "수정코드", "reason": "이유", "severity": "critical|major|minor"}]}]
```

`.claude/squad-memory/plan.md`에 저장:

```markdown
# 구현 계획: {기능 설명}
생성: {timestamp}
접근법: {선택된 안}

## 변경 파일
1. `path/to/file.ts` — [변경 내용 요약]
2. `path/to/other.ts` — [변경 내용 요약]

## 구현 순서
1. [Step 1]
2. [Step 2]
...

## 테스트 계획
- [ ] [테스트 항목 1]
- [ ] [테스트 항목 2]

## 예상 리스크
- [리스크 항목]
```

상태 업데이트: `phase: confirm`

### Step 6: 계획 확인

계획을 요약 출력 후:

```
계획이 .claude/squad-memory/plan.md에 저장되었습니다.

변경 파일: N개 | 예상 LOC: ~M | 리스크: LOW/MID/HIGH

바로 구현을 시작할까요? (/squad:build로 이어서 진행)
```

**사용자 확인 대기** — 확인 시 상태를 `complete`로 업데이트.

상태 업데이트: `status: complete`

## 완료

```
.claude/squad-state.md → status: complete
/squad:build를 실행하면 계획에 따라 구현을 시작합니다.
```
