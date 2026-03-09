---
name: plan
description: 상세 구현 계획 — 코드 탐색, 3가지 접근법 비교, 독립 Critic 검증으로 고품질 계획을 수립합니다.
argument-hint: "<기능 설명> [--quick] [--consensus]"
---

# /squad:plan — 상세 구현 계획 수립

요청 기능을 분석하고 3가지 접근법을 비교한 후, 독립 Critic 검증을 거쳐 고품질 구현 계획을 수립합니다.

## 옵션

- `--quick` — Critic 검증(Step 5.5)을 건너뛰고 빠르게 진행
- `--consensus` — Critic 검증을 최대 3회 반복 (Architect↔Critic 루프)

## 상태 관리

시작 시 `.claude/squad-state.md` 생성:
```
mode: plan
status: in-progress
phase: explore
task: {기능 설명}
started: {timestamp}
```

## 실행 절차

### Step 1: Explore

Agent 도구로 code-explorer 에이전트 호출 (`mode: "plan"` — 읽기 전용):
- 목표: 요청 기능과 관련된 코드 파악
- 탐색: 관련 파일, 모듈 구조, 의존성, 기존 패턴
- 코드베이스 사실을 먼저 파악한 후 사용자에게 질문 (OMC 원칙: 찾을 수 있는 건 묻지 않는다)
- 결과: 1000자 이내 구조화된 요약 반환

상태 업데이트: `phase: qa`

### Step 2: Q&A (1회 1질문)

탐색 결과를 바탕으로 **한 번에 1개씩** 질문합니다. 이전 답변을 기반으로 다음 질문을 구성합니다:

```
[탐색 결과 요약 1줄]

Q1: [질문 — 예: 기존 인증 미들웨어를 재사용할까요, 새로 만들까요?]
```

사용자 답변 후:
```
Q2: [이전 답변 기반 후속 질문]
```

2-3개 질문이면 충분합니다. 사용자가 "됐어", "진행해" 등으로 신호를 보내면 즉시 Step 3으로.

상태 업데이트: `phase: approaches`

### Step 3: 접근법 3가지 제시

Agent 도구로 plan-architect 에이전트 호출 (`mode: "plan"` — 읽기 전용):
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

추천: 안 {X} — [이유 1줄]
```

### Step 4: 사용자 선택 대기

```
어떤 접근법으로 진행할까요? (A/B/C 또는 직접 수정사항 입력)
```

**사용자 선택 대기** — 선택을 받은 후 Step 5로 진행.

상태 업데이트: `phase: detail-plan`

### Step 5: 상세 구현 계획 수립

선택된 안을 기반으로 Agent 도구로 plan-architect 에이전트 호출 (`mode: "plan"` — 읽기 전용):
- 파일별 변경 목록 (라인 수준)
- 구현 순서 및 의존성
- 독립 실행 가능 그룹 분류 (Phase 3 병렬 구현용)
- 테스트 계획

계획을 **2가지 형식**으로 저장 (컨텍스트 최적화):

1. `.claude/squad-memory/plan.md` — 사람이 읽을 수 있는 마크다운
2. `.claude/squad-plan.json` — `/squad-build` Phase 3에서 실행 가능한 JSON

**squad-plan.json 스키마** (병렬 그룹 지원):
```json
{
  "files": [
    {
      "file": "경로",
      "group": 1,
      "changes": [
        {"line": N, "old_string": "현재코드", "new_string": "수정코드", "reason": "이유", "severity": "critical|major|minor"}
      ]
    }
  ],
  "groups": {
    "1": {"name": "DB 스키마 변경", "depends_on": []},
    "2": {"name": "API 엔드포인트", "depends_on": [1]},
    "3": {"name": "프론트엔드 UI", "depends_on": [1]}
  }
}
```

`group` 필드는 의존성 그래프를 표현합니다. `depends_on: []`인 그룹들은 **동시 병렬 실행** 가능.
`depends_on: [1]`이면 그룹 1 완료 후 실행.

`.claude/squad-memory/plan.md`에 저장:

```markdown
# 구현 계획: {기능 설명}
생성: {timestamp}
접근법: {선택된 안}

## 변경 파일
1. `path/to/file.ts` — [변경 내용 요약] (그룹 1)
2. `path/to/other.ts` — [변경 내용 요약] (그룹 2)

## 병렬 실행 그래프
그룹 1 (DB) ──┬── 그룹 2 (API)
              └── 그룹 3 (UI)
독립 그룹은 병렬 구현됩니다.

## 구현 순서
1. [Step 1]
2. [Step 2]

## 테스트 계획
- [ ] [테스트 항목 1]
- [ ] [테스트 항목 2]

## 예상 리스크
- [리스크 항목]
```

### Step 5.5: Critic 독립 검증 (--quick 시 생략)

**Architect와 Critic은 반드시 다른 에이전트입니다.** 계획을 작성한 에이전트가 검증하면 안 됩니다.

Agent 도구로 critic 에이전트 호출 (`mode: "plan"`):
- 입력: `.claude/squad-plan.json` + `.claude/squad-memory/plan.md`
- 검증 기준:

| 기준 | 표준 |
|------|------|
| 파일 참조 정확도 | 80%+ 변경이 실제 파일:라인 참조 |
| 테스트 가능성 | 90%+ 수용 기준이 구체적 |
| 리스크 커버리지 | 모든 리스크에 완화 방안 존재 |
| 구체성 | "빠르게" 같은 모호한 표현 없음 → "p99 < 200ms" |

Critic 출력:
```json
{
  "verdict": "APPROVED|REVISE|REJECT",
  "score": {"file_refs": 85, "testability": 92, "risk_coverage": 78, "specificity": 88},
  "issues": ["이슈 1", "이슈 2"],
  "suggestions": ["개선 1", "개선 2"]
}
```

**verdict 처리:**
- `APPROVED` → Step 6으로
- `REVISE` → issues를 plan-architect에게 전달하여 계획 수정 후 Critic 재검증 (--consensus 시 최대 3회)
- `REJECT` → 사용자에게 알림: "Critic이 계획을 거부했습니다: {이유}. 접근법을 재선택하시겠습니까?"

상태 업데이트: `phase: confirm`

### Step 6: 계획 확인

계획 요약 + Critic 점수를 출력 후:

```
계획이 .claude/squad-memory/plan.md에 저장되었습니다.

변경 파일: N개 | 예상 LOC: ~M | 리스크: LOW/MID/HIGH
Critic 검증: APPROVED (파일참조 85% | 테스트가능 92% | 리스크커버 78% | 구체성 88%)
병렬 그룹: X개 (독립 Y개, 의존 Z개)

다음 단계를 선택하세요:
1. /squad-build — 다음 세션에서 깨끗한 컨텍스트로 구현
2. /squad-build --now — 지금 바로 구현 시작
```

**사용자 확인 대기** — 확인 시 상태를 `plan-ready`로 업데이트.

상태 업데이트: `status: plan-ready`

## 완료

```
.claude/squad-state.md → status: plan-ready
/squad:build를 실행하면 Phase 0에서 plan-ready를 감지하여 Phase 3(구현)부터 시작합니다.
```

## 읽기 전용 보호

Plan 단계에서는 Claude Code 내장 `plan` mode를 활용합니다.
Agent 도구 호출 시 `mode: "plan"`을 지정하면 서브에이전트도 읽기 전용으로 동작합니다.
