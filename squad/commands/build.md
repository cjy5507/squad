---
name: build
description: 구현 루프 — Explore→Plan→Implement→Verify 사이클을 완료까지 반복합니다. (ralph-style)
argument-hint: "<task-description>"
---

# /squad:build — 구현 루프 (implement-until-done)

요청된 작업을 탐색→계획→구현→검증 사이클로 완료까지 반복합니다.

**절대 중간에 멈추지 마라. 사용자 입력을 기다리지 마라.**
**Phase 1~4를 한 번의 실행으로 전부 완료하라.**

## 상태 관리

시작 시 `.claude/squad-state.md` 생성:
```
mode: build
status: in-progress
phase: explore
task: {task-description}
started: {timestamp}
```

각 Phase 완료 시 상태 업데이트. 컴팩션 복구에 사용.

## Phase 1: Explore

```
Agent(subagent_type: "code-explorer", prompt:
  "작업: {task-description}
   파악: 관련 파일, 구조, 의존성, 수정 범위.
   결과를 1000자 이내 요약으로 반환.",
  mode: "plan")
```

## Phase 2: Plan

```
Agent(prompt:
  "작업: {task-description}
   컨텍스트: {Phase 1 요약의 파일 목록}

   소스 코드를 수정하지 마라. 계획 파일만 작성하라.

   Write tool로 .claude/squad-plan.json에 저장:
   [{\"file\": \"경로\", \"changes\": [{\"line\": N,
     \"old_string\": \"현재코드\", \"new_string\": \"수정코드\",
     \"reason\": \"이유\", \"severity\": \"critical|major|minor\"}]}]

   리드에게는 이것만 반환: '계획 완료: N개 파일, M개 변경사항'",
  mode: "acceptEdits")
```

## Phase 3: Implement

```
Agent(subagent_type: "code-fixer", prompt:
  "Read .claude/squad-plan.json을 읽어서 모든 변경사항을 실행하라.
   수정 규칙: 심각도순, 라인역순, old_string 검증.
   완료 후 적용/스킵/실패 건수만 반환하라.",
  mode: "acceptEdits")
```

## Phase 4: Verify

리드가 직접 빌드/테스트 실행.
```
실패 시 → Agent(subagent_type: "code-fixer", prompt: "빌드 에러 수정", mode: "acceptEdits")
성공 시 → .claude/squad-plan.json 삭제, 상태를 complete로 업데이트
```

Stop hook (`build-loop.sh`)이 미완료 시 재실행을 강제합니다.

## 완료

```
.claude/squad-state.md → status: complete
최종 리포트 출력
```
