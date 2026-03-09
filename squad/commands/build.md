---
name: build
description: 구현 루프 — Explore→Plan→Implement→Verify 사이클을 완료까지 반복합니다. (ralph-style)
argument-hint: "<task-description> [--max-iter N] [--worktree]"
---

# /squad:build — 구현 루프 (implement-until-done)

요청된 작업을 탐색→계획→구현→검증 사이클로 완료까지 반복합니다.

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

## Phase 0: 세션 복구 감지

**이 단계가 가장 먼저 실행됩니다.**

기존 파일 존재 여부로 이전 세션에서 어디까지 진행했는지 판단합니다:

```
1. .claude/squad-plan.json 존재 → Phase 3 (Implement)부터 시작
2. .claude/squad-explore.md 존재 + plan.json 없음 → Phase 2 (Plan)부터 시작
3. .claude/squad-findings.json 존재 + 위 없음 → Phase 2부터 시작 (분석 결과 활용)
4. 아무것도 없음 → Phase 1 (Explore)부터 시작
```

**복구 시 메시지:**
```
[Squad Build] 이전 세션 감지: {존재하는 파일 목록}
→ Phase {N}부터 재개합니다. (깨끗한 컨텍스트에서 구현 시작)
```

이전 세션의 탐색/분석/계획 결과가 파일에 저장되어 있으므로, 컨텍스트 없이도 정확한 구현이 가능합니다.

## Phase 1: Explore

Agent 도구로 code-explorer 에이전트를 호출합니다:
- 작업: {task-description}
- 파악할 것: 관련 파일, 구조, 의존성, 수정 범위
- **결과를 `.claude/squad-explore.md`에 저장** (1000자 이내 요약)
- 메인 컨텍스트에는 "탐색 완료: N개 파일, 요약은 .claude/squad-explore.md" 1줄만 유지
- 이 단계에서는 소스 코드를 수정하지 않습니다

## Phase 2: Plan

**기존 결과 확인 (컨텍스트 최적화):**
1. `.claude/squad-memory/plan.md` — 기존 계획 (`/squad-plan`에서 생성)
2. `.claude/squad-findings.json` — 기존 분석 결과 (`/squad-analyze`에서 생성)
3. `.claude/squad-explore.md` — Phase 1 탐색 결과

존재하는 파일을 읽어 컨텍스트로 활용합니다. 없으면 처음부터 계획을 수립합니다.

Agent 도구를 호출하여 실행 계획을 수립합니다:
- 작업: {task-description}
- 컨텍스트: 위 파일들의 내용 (서브에이전트가 직접 파일을 읽음)
- 소스 코드를 수정하지 말고, 계획 파일만 작성합니다
- Write 도구로 `.claude/squad-plan.json`에 저장:
  ```json
  [{"file": "경로", "changes": [{"line": N, "old_string": "현재코드", "new_string": "수정코드", "reason": "이유", "severity": "critical|major|minor"}]}]
  ```
- 완료 후 "계획 완료: N개 파일, M개 변경사항"만 반환

### Phase 2 완료 후: 세션 분리 판단

**컨텍스트 보호 원칙: 계획까지만 하고 구현은 깨끗한 세션에서.**

Phase 2 완료 시 다음 메시지를 출력하고 **구현을 시작하지 않습니다:**

```
✅ Phase 2 완료 — 계획이 저장되었습니다.

저장된 파일:
- .claude/squad-plan.json (구현 계획)
- .claude/squad-explore.md (탐색 결과)
- .claude/squad-findings.json (분석 결과, 있는 경우)

👉 다음 세션에서 `/squad-build`를 다시 실행하면 깨끗한 컨텍스트에서 Phase 3(구현)부터 시작합니다.
   지금 바로 구현하려면 `/squad-build --now`를 입력하세요.
```

**예외: `--now` 옵션이 있으면** 세션을 나누지 않고 Phase 3으로 바로 진행합니다.

## Phase 2.5: 이전 수정 실패 감지 + 필터링

구현 전 `.claude/squad-memory/` 디렉토리가 존재하면:
1. `squad-plan.json`의 변경사항과 `fix-history.jsonl`을 대조
2. 동일 file + 유사 패턴이 이전에 수정된 기록이 있으면 = **이전 수정 실패**
3. 실패 감지 시:
   - `agent-effectiveness.md`에서 이전 수정 에이전트 점수 -5
   - 해당 변경사항을 **다른 에이전트**에게 재배정하거나 다른 접근법 사용
   - 이전 수정과 동일한 `old_string`/`new_string` 반복 금지
4. 동일 패턴 **3회 이상** 실패 → `false-positives.md` 등록 + 구현 대상에서 제외

## Phase 3: Implement

**이 단계는 반드시 Agent 도구(서브에이전트)로 격리 실행합니다.**

구현 에이전트는 깨끗한 컨텍스트에서 시작하여 파일만 읽고 작업합니다:
- `.claude/squad-plan.json`을 읽어서 모든 변경사항을 실행 (Phase 2.5에서 필터링된 항목 제외)
- 수정 규칙: 심각도순, 라인역순, old_string 검증
- **각 변경사항 적용 전** `.claude/squad-state.md`에 `agent:`, `severity:`, `title:` 필드를 업데이트 (track-fix.sh 이력 추적용)
- 완료 후 적용/스킵/실패 건수만 반환

메인 컨텍스트에는 구현 결과 요약(적용/스킵/실패 건수)만 유지합니다.

## Phase 4: Verify

리드가 직접 빌드/테스트를 실행합니다.
- 실패 시 → Agent 도구로 code-fixer 에이전트를 호출하여 빌드 에러 수정
- 성공 시 → `.claude/squad-plan.json` 삭제, 상태를 complete로 업데이트

Stop hook (`build-loop.sh`)이 미완료 시 재실행을 강제합니다.

## 완료 + 임시 파일 정리

성공 시 임시 파일을 삭제합니다 (squad-memory/는 영구 데이터이므로 유지):

```bash
rm -f .claude/squad-plan.json .claude/squad-explore.md .claude/squad-state.md
# squad-findings.json은 이 build에서 소비했으면 삭제
rm -f .claude/squad-findings.json
```

```
임시 파일 정리 완료
최종 리포트 출력
```
