---
name: fix
description: 자동 수정 — 분석 결과를 기반으로 코드를 자동 수정하고 자기 교정 루프로 품질을 보장합니다.
argument-hint: "<target-path> [--thorough] [--worktree]"
---

# /squad:fix — 자동 수정 + 자기 교정 루프

분석 → 배치 수정 → 검증 → 자기 교정 루프를 실행합니다.

## 옵션

- `--thorough` — 3-pass 철저 모드 (기본 2-pass)
- `--worktree` — Git worktree 격리 실행 (안전 모드)

## 실행 절차

### 0. Worktree 격리 (--worktree 옵션 시)

`--worktree` 옵션이 있으면:

1. `git worktree add .squad-worktree-{timestamp} HEAD` 로 격리 환경 생성
2. worktree 경로에서 Step 1~4 실행
3. 완료 후 `git diff HEAD` 로 변경사항 표시
4. 사용자에게 확인: "변경사항을 메인 브랜치에 적용할까요? (y/n)"
5. 확인 시: `git cherry-pick` 또는 파일 직접 복사로 적용
6. `git worktree remove .squad-worktree-{timestamp}` 로 자동 정리

**--worktree 없으면** Step 1부터 바로 시작.

### 1. 분석

**기존 분석 결과 확인:** `.claude/squad-findings.json`이 존재하면 이를 읽어 사용합니다 (`/squad-analyze`에서 생성). 없으면 analyze와 동일하게 에이전트 병렬 실행.

분석 결과는 `.claude/squad-findings.json`에 저장합니다 (컨텍스트 최적화).
메인 컨텍스트에는 요약(항목 수 + critical/major title만)만 유지합니다.
confidence < 80인 발견은 필터링.

### 1.5. 이전 수정 실패 감지 + 필터링

**재요청 = 이전 수정 실패 (필수 체크):**
수정 시작 전 현재 findings와 `fix-history.jsonl`을 대조합니다:
1. 현재 findings의 각 항목(file + 유사 패턴)이 fix-history에 이미 수정 기록이 있는지 확인
2. 매칭 = 이전에 수정했는데 같은 이슈가 다시 발견됨 = **이전 수정 실패**
3. 실패 감지 시:
   - `agent-effectiveness.md`에서 이전 수정 에이전트 점수 -5
   - 해당 finding을 **다른 에이전트**에게 재배정하거나, 이전과 **다른 접근법**으로 수정
   - 이전 수정의 `old_string`/`new_string`을 참고하여 같은 수정을 반복하지 않음
4. 동일 파일+동일 패턴 **3회 이상** 실패:
   - `false-positives.md`에 자동 등록 (자동 수정 불가 판정)
   - 수정 대상에서 제외, `[SKIPPED: 3회 실패 — 수동 검토 필요]`로 보고

**false-positives.md 필터링:**
`false-positives.md`에 등록된 패턴과 매칭되는 findings을 수정 대상에서 제외합니다.

### 2. 배치 수정

code-fixer 에이전트에 위임. `mode: "acceptEdits"`.

**수정 전 상태 업데이트 (필수):**
각 finding 수정 전에 `.claude/squad-state.md`에 현재 수정 대상 정보를 기록:
```
agent: {finding을 보고한 에이전트명}
severity: {finding의 severity}
title: {finding의 title/message}
```
이 정보는 `track-fix.sh` 훅이 수정 이력을 기록할 때 사용됩니다.

수정 규칙:
- `auto_fixable: false` → 스킵
- `severity: info` → 스킵
- 심각도순 정렬: critical → major → minor
- 같은 파일은 아래 라인부터 적용 (라인 밀림 방지)
- 수정 전 Read로 `old_string` 일치 확인 → 불일치 시 스킵

### 3. 빌드/테스트 검증

```
감지 순서:
  package.json → npx tsc --noEmit, npm test
  Cargo.toml → cargo check, cargo test
```

실패 시 → code-fixer로 에러 수정 재시도 (최대 3회).

### 4. 자기 교정 루프

```
requiredPasses = 2 (기본) | 3 (--thorough)
maxIterations = requiredPasses × 3

while consecutivePasses < requiredPasses && iteration < maxIterations:
  iteration++
  results = 새 에이전트로 분석 (fresh context, 서브에이전트 격리)
  → 결과를 .claude/squad-findings.json에 덮어쓰기 (이전 반복 결과 교체)
  → 메인 컨텍스트에는 "iteration N: X건 발견" 1줄만 유지
  if results.hasIssues():
    consecutivePasses = 0
    fix(findings.json에서 읽기) → verify
  else:
    consecutivePasses++

maxIterations 도달 시 → "자동 수정 불가, 수동 검토 필요" 탈출
```

**컨텍스트 규칙:** 각 반복에서 에이전트 분석은 서브에이전트로 격리 실행.
findings 전체를 메인 컨텍스트에 출력하지 않습니다. 파일로만 전달합니다.

### 5. 수정 결과 학습 (자기 학습)

`.claude/squad-memory/` 디렉토리가 존재하면 이번 수정 결과를 학습합니다:

**이번 수정 기록 저장:**
- 이번에 적용된 모든 수정이 `fix-history.jsonl`에 기록됨 (track-fix.sh 자동)
- 다음 실행 시 Step 1.5에서 이 기록과 새 findings를 대조하여 실패를 감지

**에이전트 정확도 업데이트:**
- 자기 교정 루프(Step 4)를 통과한 수정 → 해당 에이전트 점수 +1 (최대 100)
- Step 1.5에서 감지된 이전 실패 수정 → 이미 점수 -5 처리됨
- 결과를 `agent-effectiveness.md`에 기록

### 6. 최종 리포트

```
적용: N건 | 스킵: M건 | 실패: K건
자기 교정: X iterations, Y consecutive passes
빌드: PASS/FAIL | 테스트: PASS/FAIL
리버트 감지: R건 (자동 false positive 등록)
```
