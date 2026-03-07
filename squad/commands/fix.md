---
name: fix
description: 자동 수정 — 분석 결과를 기반으로 코드를 자동 수정하고 자기 교정 루프로 품질을 보장합니다.
argument-hint: "<target-path> [--thorough]"
---

# /squad:fix — 자동 수정 + 자기 교정 루프

분석 → 배치 수정 → 검증 → 자기 교정 루프를 실행합니다.

## 실행 절차

### 1. 분석 (analyze와 동일)

전문가 에이전트 병렬 실행 → JSON 계약 결과 수집.
confidence < 80인 발견은 필터링.

### 2. 배치 수정

code-fixer 에이전트에 위임. `mode: "acceptEdits"`.

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
  results = 새 에이전트로 분석 (fresh context)
  if results.hasIssues():
    consecutivePasses = 0
    fix → verify
  else:
    consecutivePasses++

maxIterations 도달 시 → "자동 수정 불가, 수동 검토 필요" 탈출
```

### 5. 리버트 감지 (자기 학습)

`.claude/squad-memory/` 디렉토리가 존재하면 자기 학습을 수행합니다:

**수정 이력 대조:**
- `fix-history.jsonl`에서 이전 수정 기록을 읽음
- `git log --oneline --diff-filter=M` 결과와 대조
- 이전에 squad가 수정한 파일이 이후 사용자에 의해 재변경된 경우 → 잠재적 리버트로 판단

**리버트 감지 시 자동 처리:**
- 해당 패턴을 `false-positives.md`에 자동 등록:
  ```markdown
  ## {에이전트명}
  - `{패턴}`: 사용자가 수정을 되돌림 (자동 감지, {날짜})
  ```
- `agent-effectiveness.md`에서 해당 에이전트 점수를 -5 차감

**에이전트 정확도 업데이트:**
- 성공적으로 유지된 수정 → 해당 에이전트 점수 +1 (최대 100)
- 리버트된 수정 → 해당 에이전트 점수 -5 (최소 0)
- 결과를 `agent-effectiveness.md`에 기록

### 6. 최종 리포트

```
적용: N건 | 스킵: M건 | 실패: K건
자기 교정: X iterations, Y consecutive passes
빌드: PASS/FAIL | 테스트: PASS/FAIL
리버트 감지: R건 (자동 false positive 등록)
```
