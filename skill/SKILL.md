---
name: squad
description: 병렬 전문가 에이전트 스쿼드를 자율 생성하여 코드 품질 분석, 클린코드, TDD, QA, 아키텍처 리뷰를 동시 수행. Use when user mentions squad, 스쿼드, 전문가 에이전트, 병렬 분석, code quality audit, parallel agents, 코드 품질, clean code review, or wants comprehensive multi-expert code analysis.
---

# Code Squad v3 — 병렬 전문가 에이전트 오케스트레이터

코드베이스를 다각도로 분석하는 전문가 에이전트 스쿼드를 상황에 맞게 자율 편성하여 병렬 실행합니다.

## 핵심 원칙

1. **Explore → Plan → Execute** — haiku 탐색 → 편성 계획 → 전문가 병렬 실행
2. **3-Gate 병렬 판단** — 병렬/직렬을 의사결정 트리로 판단
3. **컨텍스트 격리** — 각 서브에이전트는 fresh context, 편향 없는 분석
4. **JSON 계약** — 에이전트 간 결과는 구조화된 JSON으로 전달
5. **자기 교정 루프** — N회 연속 통과 게이트로 수정 품질 보장
6. **명시적 위임 경계** — 자기 영역 외 작업은 `defer_to`로 위임
7. **3-Tier 모델 라우팅** — haiku(탐색) / sonnet(실행) / opus(고난이도)
8. **Anti-Drift 검증** — 에이전트 결과가 원래 목표에서 벗어나는지 검증
9. **Critical Consensus** — critical 발견은 교차 검증으로 확정
10. **AgentSpeak 프로토콜** — Team 모드 에이전트 간 토큰 효율 통신 (60-70% 절감)
11. **Persistent Learning** — 세션 간 학습으로 분석 정밀도 점진 향상

## 전문가 에이전트 로스터

### Tier 1 — 항상 투입 (Core)
| 에이전트 | 역할 | Defer-To |
|----------|------|----------|
| **CleanCode** | 네이밍, 함수 크기, SRP, DRY, KISS, 복잡도 | 에러 처리→BugHunter |
| **Architect** | 의존성 방향, 레이어 분리, 결합도, SOLID | 코드 수정→CleanCode |
| **BugHunter** | 잠재 버그, 엣지케이스, 에러 핸들링, 보안 | 타입→TypeGuard |

### Tier 2 — 상황별 투입 (Contextual)
| 에이전트 | 투입 조건 | Defer-To |
|----------|-----------|----------|
| **TestExpert** | 테스트 파일 존재 또는 TDD 요청 | 프로덕션 코드→CleanCode |
| **PerfTuner** | 성능 민감 코드 (루프, DB, API) | 구조→Architect |
| **TypeGuard** | TypeScript/Rust 타입 시스템 | 런타임 버그→BugHunter |
| **ReactPro** | React/프론트엔드 코드 | Rust→RustSage |
| **RustSage** | Rust 코드 | 프론트엔드→ReactPro |
| **DocWriter** | 공개 API/라이브러리 코드 | 코드 수정→CleanCode |

에이전트별 상세 체크리스트: [checklists.md](checklists.md)
사전 정의 에이전트: `~/.claude/agents/` (subagent_type으로 호출)

## 실행 전략

### Step 0: Quick Explore (haiku 사전 탐색) — NEW

본격 분석 전, Explore 에이전트(haiku)로 코드베이스를 빠르게 스캔합니다.
sonnet 대비 비용 1/10, 탐색에 최적.

```
Agent(
  subagent_type: "Explore",  # haiku 기반 탐색 에이전트
  prompt: "다음을 파악하세요:
    1. 대상 파일 목록 + 라인 수
    2. 파일 확장자별 언어 분류
    3. 테스트 파일 존재 여부
    4. 코드 난이도 시그널 (HIGH/MID/LOW)
    5. 모듈 간 의존성 관계"
)
→ 결과: 에이전트 편성 + 모델 라우팅 결정에 사용
```

### Step 1: 에이전트 편성

Step 0 결과 기반으로 투입 에이전트를 결정합니다.

**편성 규칙:**
- `.ts/.tsx` → TypeGuard | `React` 컴포넌트/훅 → ReactPro
- `.rs` → RustSage | `*.test.*`/`*.spec.*` → TestExpert
- 루프/쿼리/API 다수 → PerfTuner | 공개 API/export → DocWriter

**적응형 에이전트 수 (Quick Scan 최적화):** — NEW
```
파일 1~2개 + 100줄 이하 → 단일 에이전트 (가장 관련 높은 1명)
파일 3~5개             → Core 2명 (CleanCode + BugHunter)
파일 6~15개            → Core 3명 + 관련 Tier 2
파일 16개+             → Full Audit (전원)
```

### Step 1.5: 3-Gate 병렬 의사결정

```
Gate 1: 독립 도메인 3개+?     → NO: 단일 에이전트
Gate 2: 상호 독립 분석 가능?   → NO: 순차 실행
Gate 3: 파일 동시 수정 없음?   → NO: 파일 분배 또는 순차
→ 모든 Gate 통과: 병렬 실행
```

### Step 1.6: 3-Tier 모델 라우팅 — UPDATED

**에이전트 역할 x 코드 난이도** 조합으로 자동 결정합니다.

| Tier | 모델 | 용도 | 비용 비율 |
|------|------|------|----------|
| **Explore** | haiku 4.5 | 코드 탐색, 파일 스캔, 구조 파악 | 1x |
| **Execute** | sonnet 4.6 | 분석/구현/테스트 (대부분의 작업) | 3x |
| **Reason** | opus 4.6 | HIGH 난이도 코드의 추론 집약 분석 | 5x |

**`opusplan` alias:** 계획은 Opus, 실행은 Sonnet으로 자동 전환. Lead 조율에 최적.

**난이도 판정 (Step 0에서 자동):**
```
LOW/MID → sonnet: CRUD, 설정, 분기 8개 이하, 300줄 이하
HIGH → opus:     동시성, 제네릭/매크로, unsafe, 순환 복잡도 높음, 300줄+
```

**에이전트별 HIGH 오버라이드:**
| sonnet 유지 | opus 승격 |
|-------------|----------|
| CleanCode, TestExpert, ReactPro | Architect, BugHunter, PerfTuner, TypeGuard, RustSage |

사용자 오버라이드: `--model sonnet|opus|haiku|opusplan`로 전원 강제 지정 가능.

### Step 2: 에이전트 병렬 실행 — UPDATED

**반드시 Agent tool을 사용하여 병렬 호출합니다.**

**Agent tool 파라미터 활용:**
```
Agent(
  description: "CleanCode 분석",
  prompt: "{에이전트 프롬프트}",
  subagent_type: "clean-code-expert",    # ~/.claude/agents/ 사전 정의 에이전트
  run_in_background: true,                # 백그라운드 비동기 실행 (진정한 병렬)
  mode: "plan",                           # 퍼미션: plan(읽기만), acceptEdits(수정 허용)
  isolation: "worktree"                   # 리팩토링/수정 시 git worktree 격리
)
```

**핵심 파라미터:**
| 파라미터 | 용도 | 사용 시점 |
|---------|------|----------|
| `subagent_type` | 사전 정의 에이전트 선택 | 항상 (agents/ 파일 활용) |
| `run_in_background` | 비동기 병렬 실행 | 3명 이상 동시 실행 시 |
| `mode: "plan"` | 읽기 전용 분석 | 모드 A (분석) |
| `mode: "acceptEdits"` | 수정 허용 | 모드 B (Auto-Fix) |
| `isolation: "worktree"` | git worktree 격리 | 모드 D (리팩토링) |
| `resume` | 이전 에이전트 재개 | 자기 교정 루프 시 |

**Overlooked DB 프리로딩:** — NEW
`.claude/squad-overlooked.md`가 존재하면 에이전트 프롬프트 상단에 주입:
```
## 이전 놓친 패턴 (이 카테고리)
{squad-overlooked.md에서 해당 에이전트 카테고리만 발췌, 최근 10건}
```

**에이전트 프롬프트 템플릿:**
```
당신은 [{에이전트명}] 전문가입니다.

## 이전 놓친 패턴 (있으면)
{.claude/squad-overlooked.md에서 해당 카테고리 발췌}

## 분석 대상
{파일 목록 — 전체 경로}

## 분석 기준
{에이전트별 체크리스트 — checklists.md 참조}

## 위임 경계 (Defer-To)
당신의 영역이 아닌 문제: `defer_to: {전문가명}` 표시, 직접 수정안 제시 금지.

## 출력 형식 (JSON 계약)
{
  "agent": "에이전트명",
  "files_analyzed": ["파일1"],
  "findings": [{
    "severity": "critical|major|minor|info",
    "title": "발견 제목",
    "file": "파일 경로",
    "line": 라인번호,
    "description": "구체적 설명",
    "old_string": "현재 코드 (Edit용 정확한 문자열)",
    "new_string": "수정된 코드",
    "auto_fixable": true|false,
    "defer_to": null | "전문가명",
    "rationale": "왜 이것이 문제인지",
    "task_alignment": "원래 분석 목표와의 관련성"
  }],
  "score": { "항목1": "X/10" },
  "passed": true|false
}
심각도: critical=데이터손실/보안/크래시, major=기능오작동, minor=개선권장, info=제안
```

### Step 3: 결과 통합 + 검증

**3a. Defer-To 재배치:** `defer_to` 항목을 해당 전문가 결과에 병합.

**3b. 충돌 해소:** 같은 file:line → severity 높은 것 우선 → 병합 시도 → 사용자 선택.

**3c. Anti-Drift 검증:** — NEW
```
각 에이전트 결과의 task_alignment 필드 확인:
- 원래 분석 목표와 무관한 발견(scope creep) 필터링
- 드리프트 비율 30% 이상 → 해당 에이전트 결과에 경고 표시
```

**3d. Critical Consensus:** — NEW
```
severity: "critical" 발견 시:
1. 원래 발견한 에이전트가 아닌 다른 전문가 1명에게 교차 검증
2. 두 전문가 모두 critical 동의 → 확정
3. 동의 안 함 → major로 다운그레이드 + 사용자에게 판단 요청
```

**3e. 통합 리포트:**
```markdown
# Code Squad 분석 리포트

## 요약
- 분석 파일: N개 | 투입 전문가: [목록] | 모델: [사용 tier]
- 발견 항목: critical X | major Y | minor Z | info W
- 자동 수정 가능: N건 | 수동 필요: M건
- 예상 비용: ~{토큰}K tokens

## Critical (교차 검증 완료)
## Major
## Minor
## 전문가별 점수
```

## 실행 모드

### 모드 A: 분석 전용 (Analyze)

리포트만 생성. 코드 수정 없음.

| 레벨 | 에이전트 | 대상 |
|------|---------|------|
| Quick Scan | 적응형 1~3명 | git diff 파일만 |
| Deep Analysis | Core + Tier 2 | 변경 파일 + 관련 모듈 |
| Full Audit | 전원 | 디렉토리 전체 |

자동 선택: 파일 1~5개→Quick, 6~15개→Deep, 16개+→Full

### 모드 B: 자동 수정 (Auto-Fix) + 자기 교정 루프

```
Phase 1: 병렬 분석 (JSON 계약)
→ Phase 2: 배치 수정 (순차, 아래→위, Critical→Major→Minor)
→ Phase 3: 검증 (tsc/cargo/test, 실패 시 개별 롤백)
→ Phase 4: 자기 교정 루프 (standard=2-pass, thorough=3-pass)
```

수정 전 검증: Read로 old_string 일치 확인 → 불일치 시 스킵.
Overlooked Issues DB: 1차 놓침→2차 발견 패턴을 `.claude/squad-overlooked.md`에 축적.
상세 알고리즘: [strategy-guide.md](strategy-guide.md) § 자기 교정 루프

### 모드 C: TDD 생성 (Test-First)

```
Phase 1: TestExpert + BugHunter + TypeGuard 병렬 분석 → 테스트 케이스 도출
Phase 2: 테스트 생성 (fresh subagent)
Phase 3: Spec 리뷰 (불신 기반: 실제 코드와 대조 검증)
Phase 4: Quality 리뷰 → Phase 5: 실행 + 자기 교정
```

### 모드 D: 리팩토링 배치 (Refactor)

Architect + CleanCode 주도. 항상 `isolation: "worktree"`에서 실행.
게이트: 원래 작업 완료 + 테스트 통과 + 사용자 명시 요청.

### 모드 T: Team 모드 (대규모 병렬)

Agent Teams로 독립 Claude Code 세션 병렬 실행.
각 teammate는 **독립 컨텍스트 + 직접 소통 + 공유 태스크 리스트**.
에이전트 간 통신은 **AgentSpeak 프로토콜**로 토큰 60-70% 절감.

**AgentSpeak 핵심 형식:**
```
STATUS: TM1 → LEAD | phase:analysis files:3/5 findings:2M,1m
FINDING: TM1 → LEAD | S:major F:src/use.ts L:45 T:"missing cleanup"
DONE: TM1 → LEAD | files:5 findings:3C,5M score:7/10
```

**자동 제안 조건** (2개 이상 만족 시):
- 대상 파일 20개+ | 독립 모듈 3개+ | 구현+테스트+문서 동시
- 사용자가 "team", "팀", "병렬 구현" 키워드 사용

상세 전략 (편성, AgentSpeak, Delegate 모드, 파일 충돌 방지, 종료 프로토콜):
[strategy-guide.md](strategy-guide.md) § Team 모드

## 모드 자동 선택

| 키워드 | 모드 |
|--------|------|
| "분석", "리뷰", "체크" | A (분석) |
| "수정", "고쳐", "fix", "auto" | B (Auto-Fix) |
| "테스트", "TDD", "커버리지" | C (TDD) |
| "리팩토링", "정리", "refactor" | D (리팩토링) |
| "team", "팀", "병렬 구현", "대규모" | T (Team) |
| 키워드 없음 | A → "자동 수정할까요?" |

## 전체 배치 (`/squad batch`)

```
A(분석) → B(수정, Critical시만) → C(TDD) → D(리팩토링, 승인 후) → 최종 리포트
각 단계 사이 검증 게이트: tsc/cargo check + 테스트 통과 필수
```

## 비용 가이드 (요약)

| 모드 | 예상 토큰 | 에이전트 |
|------|----------|---------|
| Quick (1-2 파일) | ~20K | 1명 |
| Quick (3-5 파일) | ~50K | 2명 |
| Deep | ~150K | 3-5명 |
| Full / Auto-Fix | ~300K | 전원 |
| Team | ~200K x N | 3-5 teammate |

상세 비용/최적화 전략: [cost-guide.md](cost-guide.md)

## 컨텍스트 보호 + Persistent Learning

**컨텍스트 보호:**
- 분석 시작 전 `/compact`로 컨텍스트 정리 권장
- `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=80` 설정으로 조기 컴팩션
- **`PreCompact` hook** — 컴팩션 직전에 Squad 상태를 `.claude/squad-state-snapshot.md`에 자동 저장
- 복원: compaction 후 snapshot 파일이 존재하면 중단된 phase부터 자동 재개
- 참고: 실제 사용 가능 컨텍스트는 ~120K tokens (200K 중 시스템 프롬프트/도구 정의 차감)

**Persistent Learning (세션 간 학습):**
- `.claude/squad-memory/` 디렉토리에 프로젝트별 학습 데이터 축적
- `false-positives.md`: 반복 거부된 finding → 에이전트에 "무시할 패턴" 주입
- `convention-overrides.md`: 프로젝트 특화 룰 오버라이드
- `agent-effectiveness.md`: 에이전트별 정확도 추적
- 초기화: `/squad init`으로 학습 디렉토리 생성

상세 설정: [strategy-guide.md](strategy-guide.md) § PreCompact Hook / Persistent Learning

## 사용 예시

```
/squad src/hooks/                           # 분석 (자동 편성)
/squad fix src/hooks/                       # Auto-Fix (2-pass)
/squad fix --thorough src/hooks/            # Auto-Fix (3-pass)
/squad fix --model opus src/hooks/          # 전원 opus 강제
/squad fix --experts CleanCode,BugHunter .  # 특정 전문가만
/squad tdd src/components/                  # TDD 생성
/squad refactor src/lib/                    # 리팩토링
/squad batch src/                           # 전체 배치
/squad team src/                            # Team 모드
/squad team --delegate --teammates 3 src/   # Team Delegate 모드
/squad init                                 # 학습 디렉토리 초기화
```

## 에이전트 파일 위치

사전 정의 에이전트: `~/.claude/agents/`
```
clean-code-expert.md, architect-expert.md, bug-hunter.md,
test-expert.md, perf-tuner.md, type-guard.md,
react-pro.md, rust-sage.md, code-fixer.md
```
분석 에이전트: `tools: Read, Grep, Glob` (읽기 전용)
수정 에이전트: code-fixer.md → `tools: Read, Edit, Grep, Glob, Bash`

## 참고 문서

- [체크리스트](checklists.md) — 에이전트별 상세 분석 기준
- [전략 가이드](strategy-guide.md) — 배치 전략, 롤백 트리, 자기 교정 루프, Team 모드, AgentSpeak, PreCompact, Persistent Learning
- [비용 가이드](cost-guide.md) — 비용 추적, 최적화, 모델 선택 전략
