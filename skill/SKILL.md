---
name: squad
description: Deploys parallel specialist agents to autonomously analyze code quality, clean code, TDD, QA, and architecture in parallel. Use when user mentions squad, 스쿼드, 전문가 에이전트, 병렬 분석, code quality audit, parallel agents, 코드 품질, clean code review, or wants comprehensive multi-expert code analysis.
argument-hint: "[mode] [target-path] [--options]"
---

# Code Squad v3 — 병렬 전문가 에이전트 오케스트레이터

코드베이스를 다각도로 분석하는 전문가 에이전트 스쿼드를 상황에 맞게 자율 편성하여 병렬 실행합니다.

## 핵심 원칙

1. **Context Engineering** — 컨텍스트는 유한 자원. 최소한의 고신호 토큰으로 최대 결과 도출 (Anthropic 공식 권장)
2. **Explore → Plan → Execute** — haiku 탐색 → 편성 계획 → 전문가 병렬 실행
3. **3-Gate 병렬 판단** — 병렬/직렬을 의사결정 트리로 판단
4. **컨텍스트 격리** — 각 서브에이전트는 fresh context, 편향 없는 분석
5. **JSON 계약** — 에이전트 간 결과는 구조화된 JSON으로 전달
6. **자기 교정 루프** — N회 연속 통과 게이트로 수정 품질 보장
7. **명시적 위임 경계** — 자기 영역 외 작업은 `defer_to`로 위임
8. **정적 모델 라우팅** — agent frontmatter `model: sonnet` 기반, Explore는 빌트인(haiku)
9. **Anti-Drift 검증** — 에이전트 결과가 원래 목표에서 벗어나는지 검증
10. **Critical Consensus** — critical 발견은 교차 검증으로 확정
11. **AgentSpeak 프로토콜** — Team 모드 에이전트 간 토큰 효율 통신
12. **Persistent Learning** — `/squad reject`로 오탐 수동 등록, 세션 간 정밀도 향상

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

### Step 0: Quick Explore (haiku 사전 탐색)

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
    5. 모듈 간 의존성 관계
    6. 프레임워크 감지 (import/using 문 기반)"
)
→ 결과: 에이전트 편성 + 모델 라우팅 + 동적 체크리스트 결정에 사용
```

**동적 언어 규칙 주입:** Step 0에서 감지된 언어/프레임워크에 따라 [lang-rules.md](lang-rules.md)에서
해당 규칙만 뽑아 에이전트 프롬프트에 자동 주입합니다.
```
감지: .sql 파일 → BugHunter에 [SQL] 규칙 추가, PerfTuner에 [SQL] 규칙 추가
감지: .cs + EF Core → BugHunter에 [DOTNET]+[EFCORE] 규칙 추가
감지: .java + Spring → BugHunter에 [JAVA]+[SPRING] 규칙 추가
→ 에이전트 수는 그대로, 체크리스트만 동적으로 확장
```

### Step 1: 에이전트 편성

Step 0 결과 기반으로 투입 에이전트를 결정합니다.

**편성 규칙:**
- `.ts/.tsx` → TypeGuard | `React` 컴포넌트/훅 → ReactPro
- `.rs` → RustSage | `*.test.*`/`*.spec.*` → TestExpert
- 루프/쿼리/API 다수 → PerfTuner | 공개 API/export → DocWriter

**적응형 에이전트 수 (Quick Scan 최적화):**
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

### Step 1.6: 정적 모델 라우팅

Agent tool에 `model` 파라미터가 없으므로 **동적 모델 선택은 불가능**합니다.
모델은 agent `.md` frontmatter의 `model` 필드로 정적 지정됩니다.

| 계층 | 모델 | 설정 방법 | 용도 |
|------|------|----------|------|
| **Explore** | haiku | 빌트인 (자동) | 코드 탐색, 파일 스캔 |
| **분석 에이전트** | sonnet | frontmatter `model: sonnet` | 분석/구현 (대부분) |
| **Opus 승격** | opus | 사용자가 agent frontmatter 수정 | 고난이도 코드 |

**제약사항:**
- 호출 시점에 모델을 동적으로 변경할 수 없음 (Agent tool API 한계)
- 모든 커스텀 에이전트는 `model: sonnet`으로 설정됨 (비용 효율)
- Opus가 필요하면 해당 agent `.md` 파일의 frontmatter를 `model: opus`로 수정

### Step 2: 에이전트 병렬 실행

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
| `mode: "plan"` | 분석 모드 (⚠️ 실제 tool 차단 아님, Hook 필요) | 모드 A (분석) |
| `mode: "acceptEdits"` | 수정 허용 | 모드 B (Auto-Fix) |
| `isolation: "worktree"` | git worktree 격리 | 모드 D (리팩토링) |
| `resume` | 이전 에이전트 재개 | 자기 교정 루프 시 |

**Overlooked DB 프리로딩:**
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

## 언어별 추가 규칙 (Step 0 감지 기반, 동적 주입)
{lang-rules.md에서 감지된 언어 태그의 해당 에이전트 규칙만 발췌}

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

**3a-0. 에이전트 실패 처리:**
```
에이전트가 유효한 JSON을 반환하지 않거나 타임아웃 시:
- JSON 파싱 실패 → 해당 에이전트 결과 제외 + 경고 표시
- 타임아웃 → 해당 에이전트 결과 제외 + 경고 표시
- 전체 에이전트 실패 시 → "분석 실패" 리포트 + 재시도 제안
- 부분 실패(1명 이상 성공) → 성공한 에이전트 결과만으로 리포트 생성
⚠️ LLM은 JSON을 markdown fence(```)로 감쌀 수 있음 — 파싱 시 fence 제거 필요
⚠️ 서브에이전트는 중첩 불가 (2-tier 최대: 리드 → 서브에이전트)
```

**3a. Defer-To 재배치:** `defer_to` 항목을 해당 전문가 결과에 병합.

**3b. 충돌 해소:** 같은 file:line → severity 높은 것 우선 → 병합 시도 → 사용자 선택.

**3c. Anti-Drift 검증:**
```
각 에이전트 결과의 task_alignment 필드 확인:
- 원래 분석 목표와 무관한 발견(scope creep) 필터링
- 드리프트 비율 30% 이상 → 해당 에이전트 결과에 경고 표시
- 단, severity: "critical" 발견은 드리프트와 무관하게 항상 보존 (안전성 우선)
```

**3d. Critical Consensus:**
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
→ Phase 4: 자기 교정 루프 (standard=2-pass, thorough=3-pass, maxIterations=pass×3)
```

**안전장치:** maxIterations = requiredPasses × 3. 상한 도달 시 "자동 수정 불가, 수동 검토 필요"로 탈출.
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

### 모드 Best: Auto-Pipeline (완전 자동)

⚠️ **절대 중간에 멈추지 마라. 사용자 입력을 기다리지 마라.**
⚠️ **Phase 1~4를 한 번의 실행으로 전부 완료하라. "진행할까요?" 질문 금지.**

**실행:** `/squad best src/target/`

**서브에이전트 = 새 세션. /clear, /compact 불필요. 파일이 Phase 간 다리.**

**Phase 1: Explore** — 코드 스캔 (haiku, ~500 토큰 리드 소비)
```
Agent(subagent_type: "Explore", prompt: "대상 파일 구조, 언어, 복잡도 파악.
  결과를 1000자 이내 요약으로 반환.")
→ 리드가 받는 것: 요약 텍스트만 (~500 tokens)
```

**Phase 2: Plan** — 계획을 파일에 저장 (리드 컨텍스트 ~50 토큰만 소비)
```
Agent(prompt: "다음 코드를 분석하고 수정 계획을 작성하라.
  대상: {Phase 1 요약의 파일 목록}

  ⚠️ 소스 코드를 수정하지 마라. 계획 파일만 작성하라.

  Write tool로 .claude/squad-plan.json에 저장:
  [{\"file\": \"경로\", \"changes\": [{\"line\": N,
    \"old_string\": \"현재코드\", \"new_string\": \"수정코드\",
    \"reason\": \"이유\", \"severity\": \"critical|major|minor\"}]}]

  리드에게는 이것만 반환: '계획 완료: N개 파일, M개 변경사항 (critical X, major Y)'
  전체 계획 내용을 반환하지 마라. 파일에만 저장하라.",
  mode: "acceptEdits")  # ⚠️ "plan" 모드 금지 — Write 권한 필요
→ 리드가 받는 것: "계획 완료: 5개 파일, 12개 변경사항" (~50 tokens)
→ 디스크에 생성됨: .claude/squad-plan.json
```

**Phase 3: Execute** — 계획 파일을 읽어서 자동 실행
```
Agent(subagent_type: "code-fixer", prompt:
  "Read .claude/squad-plan.json 파일을 읽어서 모든 변경사항을 실행하라.
  수정 규칙은 너의 기본 룰(심각도순, 라인역순, old_string 검증)을 따르라.
  완료 후 적용/스킵/실패 건수만 반환하라.",
  mode: "acceptEdits")
→ 리드가 받는 것: "적용 10건, 스킵 2건, 실패 0건" (~100 tokens)
```

**Phase 4: Verify + Report** — 빌드/테스트 후 리포트
```
리드가 직접 Bash로 빌드/테스트 실행 (tsc, cargo check, npm test 등)
실패 시 → Agent(subagent_type: "code-fixer", prompt: "빌드 에러 수정", mode: "acceptEdits")
성공 시 → Bash("rm .claude/squad-plan.json")  # cleanup
최종 리포트 출력
```

**왜 이 설계가 동작하는가:**
```
리드 컨텍스트 증가량:
  Phase 1 Explore 요약:  ~500 tokens
  Phase 2 Plan 요약:      ~50 tokens  (전체 계획은 파일에만 존재)
  Phase 3 Execute 요약:  ~100 tokens  (code-fixer가 파일에서 직접 읽음)
  Phase 4 Verify:        ~200 tokens
  ─────────────────────────────────
  총계:                  ~850 tokens  (리드 컨텍스트 거의 안 씀)

각 서브에이전트 = fresh context = "새 세션"
파일 = Phase 간 데이터 전달 (컨텍스트 아닌 디스크)
/clear, /compact 불필요 = 완전 자동
```

### 모드 T: Team 모드 (대규모 병렬)

Agent Teams로 독립 Claude Code 세션 병렬 실행.
각 teammate는 **독립 컨텍스트 + 직접 소통 + 공유 태스크 리스트**.
에이전트 간 통신은 **AgentSpeak 프로토콜**로 토큰 효율 통신.

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
| "수정", "고쳐", "fix", "auto" | B (Auto-Fix, 2-pass, sonnet) |
| "best", "최고", "max", "pro" | **Auto-Pipeline** (아래 참조) — 계획→실행→검증 완전 자동 |
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

## Context Engineering + Persistent Learning

**컨텍스트 관리 (Anthropic 공식 권장):**
- 분석 시작 전 `/clear`로 무관한 컨텍스트 제거, `/compact`로 핵심만 유지
- 탐색/리서치는 서브에이전트에 위임 → 메인 컨텍스트 오염 방지
- `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=80` 설정으로 조기 컴팩션
- 에이전트 프롬프트에 파일 경로만 전달 (전체 코드 X) → just-in-time retrieval
- 참고: 실제 사용 가능 컨텍스트는 ~120K tokens (200K 중 시스템 프롬프트/도구 정의 차감)

**Persistent Learning (수동 관리 — 세션 간 학습):**
- `.claude/squad-memory/` 디렉토리에 프로젝트별 학습 데이터 축적
- `false-positives.md`: `/squad reject {finding}` 명령으로 수동 등록 → 에이전트에 "무시할 패턴" 주입
- `convention-overrides.md`: 사용자가 직접 편집하는 프로젝트 특화 룰 오버라이드
- 초기화: `/squad init`으로 학습 디렉토리 생성
- 참고: 자동 학습은 CLI 환경의 한계로 지원하지 않음. 수동 등록이 더 정확함

상세 설정: [strategy-guide.md](strategy-guide.md) § Persistent Learning

## 사용 예시

```
/squad src/hooks/                           # 분석 (자동 편성)
/squad fix src/hooks/                       # Auto-Fix (2-pass, sonnet)
/squad best src/hooks/                      # 완전 자동 파이프라인 (3-pass, opus)
/squad fix --thorough src/hooks/            # Auto-Fix (3-pass, sonnet)
/squad fix --experts CleanCode,BugHunter .  # 특정 전문가만
/squad tdd src/components/                  # TDD 생성
/squad refactor src/lib/                    # 리팩토링
/squad batch src/                           # 전체 배치
/squad team src/                            # Team 모드
/squad init                                 # 학습 디렉토리 초기화
```

## 에이전트 파일 위치

사전 정의 에이전트: `~/.claude/agents/`
```
clean-code-expert.md, architect-expert.md, bug-hunter.md,
test-expert.md, perf-tuner.md, type-guard.md,
react-pro.md, rust-sage.md, doc-writer.md, code-fixer.md
```
분석 에이전트: `tools: Read, Grep, Glob` (읽기 전용)
수정 에이전트: code-fixer.md → `tools: Read, Edit, Grep, Glob, Bash`

## 참고 문서

- [체크리스트](checklists.md) — 에이전트별 기본 분석 기준
- [언어 규칙](lang-rules.md) — 동적 주입용 언어/프레임워크별 추가 규칙 (SQL, .NET, Java, Python, Go, Spring, EF Core)
- [전략 가이드](strategy-guide.md) — 배치 전략, 롤백 트리, 자기 교정 루프, Team 모드, AgentSpeak, Persistent Learning
- [비용 가이드](cost-guide.md) — 비용 추적, 최적화, 모델 선택 전략

## 설계 원칙 출처

본 스킬은 다음 Anthropic 공식 가이드라인에 기반합니다:
- [Effective Context Engineering for AI Agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) — 컨텍스트 유한성, just-in-time retrieval, minimal viable tools
- [Skill Authoring Best Practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices) — progressive disclosure, 500줄 제한, degree of freedom
- [Claude Code Best Practices](https://code.claude.com/docs/en/best-practices) — /clear, /compact, 서브에이전트 위임, verification loops
