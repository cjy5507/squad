---
name: analyze
description: 코드 품질 분석 — 전문가 에이전트 병렬 실행으로 코드를 다각도로 분석합니다.
argument-hint: "<target-path> [--experts Agent1,Agent2]"
---

# /squad:analyze — 코드 분석

대상 코드에 전문가 에이전트를 병렬 투입하여 분석 리포트를 생성합니다. 코드 수정 없음.

## 실행 절차

### 0. 학습 데이터 로드

분석 시작 전 `.claude/squad-memory/` 디렉토리를 확인합니다.

존재하면 다음 학습 데이터를 로드하여 에이전트 프롬프트에 주입합니다:

**false-positives.md**: 각 에이전트 프롬프트에 "무시할 패턴" 섹션으로 주입:
```
## 무시할 패턴 (이 프로젝트의 허용된 패턴)
{해당 에이전트의 false-positive 목록}
이 패턴에 해당하는 발견은 보고하지 마세요.
```

**agent-effectiveness.md**: 에이전트별 정확도 점수를 읽어 confidence 임계값을 조정:
```
점수 90+ → confidence 임계값 유지 (80)
점수 70~89 → confidence 임계값 상향 (85)
점수 70 미만 → confidence 임계값 상향 (90) + 경고 표시
```

**fix-history.jsonl**: 수정 빈도 Top 10 파일(핫스팟)을 식별하여 에이전트에게 전달:
```
## 핫스팟 파일 (반복 수정 영역)
{파일별 수정 횟수 상위 10개}
이 파일들은 구조적 문제가 있을 수 있으니 더 꼼꼼히 분석하세요.
```

**convention-overrides.md**: 프로젝트 특화 룰 오버라이드를 에이전트 프롬프트에 주입:
```
## 프로젝트 컨벤션 (이 규칙을 위반으로 보고하지 마세요)
{convention-overrides.md 내용}
```

**learnings.md**: 이전 세션에서 발견된 패턴을 에이전트에게 전달:
```
## 이전 세션 학습 내용
{learnings.md에서 최근 3개 세션의 "발견된 패턴" 섹션}
```

디렉토리가 없으면 이 단계를 건너뛰고 기본 설정으로 진행합니다.

### 1. Explore (사전 탐색)

Explore 에이전트를 사용하여 대상 경로를 탐색합니다:
- 대상: {target-path}
- 파악할 것: 1) 파일 목록+라인수 2) 언어 분류 3) 테스트 존재 여부 4) 난이도 시그널 5) 모듈 의존성 6) 프레임워크 감지
- 결과를 1000자 이내 요약으로 반환

### 2. 적응형 에이전트 편성

```
파일 1~2개 + 100줄 이하 → 단일 에이전트 (가장 관련 높은 1명)
파일 3~5개             → Core 2명 (CleanCode + BugHunter)
파일 6~15개            → Core 3명 + 관련 Tier 2
파일 16개+             → Full Audit (전원)
```

Tier 1 (Core): CleanCode, Architect, BugHunter
Tier 2 (Contextual): TestExpert, PerfTuner, TypeGuard, ReactPro, RustSage, DocWriter
Tier 3 (Project): ClaudeMdChecker

편성 규칙: `.ts/.tsx` → TypeGuard | React → ReactPro | `.rs` → RustSage | 테스트 파일 → TestExpert | 루프/쿼리 → PerfTuner | 공개 API → DocWriter | CLAUDE.md 존재 시 → ClaudeMdChecker 항상 추가

### 3. 병렬 실행

편성된 각 전문가 에이전트를 Agent 도구로 병렬 호출합니다. 3명 이상이면 `run_in_background: true`로 실행합니다.

각 에이전트에게 전달할 프롬프트:
- 대상 파일 경로
- `references/json-contract.md`의 출력 형식
- "분석만 수행하고 코드를 수정하지 마세요" 지시

guard-plan-mode.sh 훅이 analyze 모드에서 Edit/Write를 차단합니다.

### 4. 결과 통합

**Confidence 필터링:** confidence < 80인 발견은 제외.

**Defer-To 재배치:** `defer_to` 항목을 해당 전문가 결과에 병합.

**충돌 해소:** 같은 file:line → severity 높은 것 우선.

**Anti-Drift 검증:**
- 각 finding의 `task_alignment` 확인
- 원래 목표와 무관한 발견(scope creep) 필터링
- 드리프트 비율 30%+ → 해당 에이전트 결과에 경고

**Critical Consensus:**
- severity: critical 발견 시 → 다른 전문가 1명에게 교차 검증
- 양쪽 critical 동의 → 확정 | 불일치 → major 다운그레이드

### 5. 결과 저장 (컨텍스트 최적화)

통합된 결과를 **파일에 저장**하여 메인 컨텍스트를 보호합니다:

```
Write 도구로 .claude/squad-findings.json에 저장:
{
  "timestamp": "ISO8601",
  "target": "분석 대상 경로",
  "agents": ["투입된 에이전트 목록"],
  "summary": { "critical": N, "major": N, "minor": N, "info": N, "auto_fixable": N },
  "findings": [통합된 finding 배열]
}
```

이 파일은 `/squad-fix`, `/squad-build` 등 후속 명령에서 재사용됩니다.
메인 컨텍스트에 findings 배열 전체를 출력하지 마세요.

### 6. 리포트 출력

**컨텍스트에는 요약만 출력합니다** (findings 상세는 파일 참조):

```markdown
# Code Squad 분석 리포트

## 요약
- 분석 파일: N개 | 투입 전문가: [목록]
- 발견 항목: critical X | major Y | minor Z | info W
- 자동 수정 가능: N건 | 수동 필요: M건
- 결과 저장: .claude/squad-findings.json

## Critical (교차 검증 완료)
{critical 항목만 title + file:line 1줄씩}
## Major
{major 항목만 title + file:line 1줄씩}
## Minor
{minor 항목 수만 표시, 상세는 파일 참조}
## 전문가별 점수
```
