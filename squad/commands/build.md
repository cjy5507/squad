---
name: build
description: 구현 루프 — Explore→Plan→Implement→Verify 사이클을 완료까지 반복합니다. (ralph-style)
argument-hint: "<task-description> [--max-iter N] [--worktree]"
---

# /squad:build — 구현 루프 (implement-until-done)

요청된 작업을 탐색→계획→구현→검증 사이클로 완료까지 반복합니다.

**절대 중간에 멈추지 마라. 사용자 입력을 기다리지 마라.**
**Phase 1~4를 한 번의 실행으로 전부 완료하라.**

## 옵션

- `--max-iter N` — 최대 반복 횟수 지정 (기본값: 10). 이 횟수에 도달하면 build-loop이 자동 종료됩니다.
- `--worktree` — Git worktree 격리 실행. 완료 후 diff 표시 + 메인 브랜치 적용 확인.

## Worktree 격리 (--worktree 옵션 시)

1. `git worktree add .squad-worktree-{timestamp} HEAD` 로 격리 환경 생성
2. worktree 경로에서 Phase 1~4 실행
3. 완료 후 `git diff HEAD` 로 변경사항 표시
4. 사용자에게 확인: "변경사항을 메인 브랜치에 적용할까요? (y/n)"
5. 확인 시: 파일 복사 또는 `git cherry-pick` 으로 적용
6. `git worktree remove .squad-worktree-{timestamp}` 로 자동 정리

**--worktree 없으면** 현재 경로에서 바로 실행.

## 상태 관리

시작 시 `.claude/squad-state.md` 생성:
```
mode: build
status: in-progress
phase: explore
task: {task-description}
started: {timestamp}
iterations: 0
max_iter: {N | 10}
```

`--max-iter N` 옵션이 있으면 `max_iter: N`으로 설정, 없으면 `max_iter: 10`.
각 Phase 완료 시 상태 업데이트. 컴팩션 복구에 사용.

## Phase 1: Explore

Agent 도구로 code-explorer 에이전트를 호출합니다:
- 작업: {task-description}
- 파악할 것: 관련 파일, 구조, 의존성, 수정 범위
- 결과를 1000자 이내 요약으로 반환
- 이 단계에서는 소스 코드를 수정하지 않습니다

## Phase 2: Plan

Agent 도구를 호출하여 실행 계획을 수립합니다:
- 작업: {task-description}
- 컨텍스트: Phase 1 요약의 파일 목록
- 소스 코드를 수정하지 말고, 계획 파일만 작성합니다
- Write 도구로 `.claude/squad-plan.json`에 저장:
  ```json
  [{"file": "경로", "changes": [{"line": N, "old_string": "현재코드", "new_string": "수정코드", "reason": "이유", "severity": "critical|major|minor"}]}]
  ```
- 완료 후 "계획 완료: N개 파일, M개 변경사항"만 반환

## Phase 3: Implement

Agent 도구로 code-fixer 에이전트를 호출합니다:
- `.claude/squad-plan.json`을 읽어서 모든 변경사항을 실행
- 수정 규칙: 심각도순, 라인역순, old_string 검증
- 완료 후 적용/스킵/실패 건수만 반환

## Phase 4: Verify

리드가 직접 빌드/테스트를 실행합니다.
- 실패 시 → Agent 도구로 code-fixer 에이전트를 호출하여 빌드 에러 수정
- 성공 시 → `.claude/squad-plan.json` 삭제, 상태를 complete로 업데이트

Stop hook (`build-loop.sh`)이 미완료 시 재실행을 강제합니다.

## 완료

```
.claude/squad-state.md → status: complete
최종 리포트 출력
```
