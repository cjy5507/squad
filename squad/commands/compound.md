---
name: compound
description: 세션 학습 정리 — 이번 세션에서 배운 패턴을 분석하고 프로젝트 지식으로 통합합니다.
argument-hint: ""
---

# /squad:compound — 세션 학습 자동 정리

이번 세션의 수정 패턴과 관찰을 분석하여 프로젝트 지식으로 통합합니다.

## 동작 조건

`.claude/squad-memory/` 디렉토리가 존재해야 합니다.
없으면: "메모리가 없습니다. /squad:init을 먼저 실행하세요." 출력 후 종료.

## 실행 절차

### Step 0: 데이터 로테이션 (자동 정리)

학습 데이터가 무한히 쌓이는 것을 방지합니다. **매 compound 실행 시 자동 실행.**

**JSONL 파일 (fix-history.jsonl, observations.jsonl):**
- 최근 30일치만 유지, 이전 데이터 삭제
```bash
CUTOFF=$(date -u -v-30d +%Y-%m-%d 2>/dev/null || date -u -d '30 days ago' +%Y-%m-%d)
for f in fix-history.jsonl observations.jsonl; do
  [ -f ".claude/squad-memory/$f" ] && \
  jq -c --arg c "$CUTOFF" 'select(.timestamp >= $c)' ".claude/squad-memory/$f" > "/tmp/$f.tmp" && \
  mv "/tmp/$f.tmp" ".claude/squad-memory/$f"
done
```

**learnings.md:**
- 최근 10개 세션만 유지 (오래된 `## Session:` 섹션 삭제)
- 10개 초과 시 가장 오래된 세션부터 삭제

**false-positives.md / squad-overlooked.md:**
- 90일 이상 미참조 패턴에 `[stale]` 태그 추가
- 180일 이상이면 삭제 제안 (`compound` 리포트에 표시)

**로테이션 결과 출력:**
```
[Rotation] fix-history: 45 → 32 entries | observations: 120 → 87 entries | learnings: 12 → 10 sessions
```

### Step 1: 이번 세션 수정 패턴 분석

`fix-history.jsonl`에서 이번 세션 수정 기록 읽기:
- 오늘 날짜 기준으로 필터링 (`jq --arg today "$(date -u +%Y-%m-%d)" 'select(.timestamp | startswith($today))'`)
- 에이전트별 수정 횟수 집계
- 반복 수정된 파일 식별 (2회 이상)
- 공통 severity 패턴 파악

### Step 2: 이번 세션 관찰 분석

`observations.jsonl`에서 이번 세션 관찰 읽기:
- 오늘 날짜(UTC) 기준으로 필터링 (`jq --arg today "$(date -u +%Y-%m-%d)" 'select(.timestamp | startswith($today))'`)
- 가장 많이 사용된 tool 집계
- 반복적으로 접근한 파일 목록
- 오류 패턴 (tool_response에 "error" 포함)

### Step 3: 반복 패턴 → convention-overrides.md 제안

반복된 수정 패턴 발견 시 (동일 파일 3회 이상, 동일 패턴 2회 이상):

```
[발견] 반복 패턴 감지:
- src/api/handlers.ts에서 3회 동일 수정 (bug-hunter: error handling)

convention-overrides.md에 추가할까요?
## bug-hunter
- API 핸들러의 try-catch 패턴은 이미 프로젝트 컨벤션으로 허용됨 (compound 자동 감지, {날짜})

(y/n)
```

사용자 확인 후 `.claude/squad-memory/convention-overrides.md`에 추가.

### Step 4: 새 패턴 → project-profile.md 업데이트 제안

탐색한 파일에서 새 기술/패턴 감지 시:
- 기존 `project-profile.md`와 비교
- 신규 프레임워크, 라이브러리, 패턴 발견 시 제안:

```
[발견] project-profile.md에 없는 패턴:
- Zod 스키마 검증 패턴 감지 (src/validation/*.ts)

project-profile.md에 추가할까요?
(y/n)
```

사용자 확인 후 업데이트.

### Step 5: agent-effectiveness.md 점수 업데이트

`fix-history.jsonl`의 이번 세션 수정 기록을 기반으로 `agent-effectiveness.md` 테이블을 업데이트합니다:

```bash
# 이번 세션 수정 기록에서 에이전트별 수정 건수 집계
jq -r --arg today "$(date -u +%Y-%m-%d)" 'select(.timestamp | startswith($today)) | .agent' .claude/squad-memory/fix-history.jsonl | sort | uniq -c
```

**점수 업데이트 규칙:**
- 각 에이전트의 Total Fixes += 이번 세션 수정 건수
- fix-history.jsonl과 최근 squad-findings.json을 대조:
  - 이전에 수정한 이슈가 다시 findings에 나타남 = **수정 실패** → Failed += 1, Score -= 5
  - 다시 나타나지 않음 = 수정 성공 → Score += 1 (최대 100)
- Last Updated = 오늘 날짜

agent-effectiveness.md 테이블을 직접 Edit 도구로 업데이트합니다 (확인 불필요).

### Step 6: learnings.md에 정리 저장

`.claude/squad-memory/learnings.md`에 이번 세션 학습 내용 저장 (항상 실행, 확인 불필요):

```markdown
## Session: {timestamp}

### 수정 통계
- 총 수정: N건
- 가장 활발한 에이전트: {agent} ({N}건)
- 핫스팟 파일: {file} ({N}회)

### 발견된 패턴
- [패턴 1]
- [패턴 2]

### convention-overrides 추가: {Y/N}
### project-profile 업데이트: {Y/N}
```

## 최종 리포트

```
=== Compound 결과 ===
분석된 수정: N건 | 관찰: M건
반복 패턴: K개 발견
convention-overrides: X개 추가
project-profile: Y개 업데이트
learnings.md: 저장 완료

Squad가 이 프로젝트를 더 잘 이해하게 되었습니다.
```
