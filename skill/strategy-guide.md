# Code Squad 전략 가이드 v3

통합 출처: agent_farm(락/하트비트), dev-workflows(자기교정/JSON계약), claude-pipeline(3-gate/defer-to/2단계리뷰)
리서치 출처: ruflo(anti-drift/consensus), kieranklaassen gist(swarm patterns), Reddit/커뮤니티 베스트프랙티스

## 병렬 에이전트 실행 방식 비교

### 방식 1: Agent Tool 서브에이전트 (권장 — 분석/리뷰)

```
장점: 즉시 병렬, 결과 자동 수집, 모델별 지정, 설정 불필요
단점: 메인 컨텍스트 내 처리, 에이전트 간 직접 소통 불가
적합: 코드 리뷰/분석, 리서치, 파일별 독립 분석
부적합: 여러 파일 동시 수정, 장시간 실행
```

### 방식 2: Agent Teams (실험적 — 대규모 구현)

```
장점: 독립 컨텍스트, 태스크 리스트 공유, tmux 모니터링, 에이전트 간 메시지
단점: 실험적 기능, 토큰 비용 높음, 세션 복원 불가
적합: 대규모 리팩토링, 다중 모듈 구현, 탐색적 디버깅
부적합: 빠른 분석, 소규모 리뷰
```

### 방식 3: 사전 정의 에이전트 (`~/.claude/agents/`)

```
장점: 재사용, 도구 권한 세밀 제어, 팀 공유 가능
단점: 사전 정의 필요, 프롬프트 변경 시 파일 수정
적합: 반복 워크플로우, 도구 제한 필요 시, 팀 표준
```

## 3-Gate 병렬 의사결정 트리 (from claude-pipeline)

```
                    ┌──────────────────────────┐
                    │ Gate 1: 독립 도메인 3개+? │
                    └─────────┬────────────────┘
                         YES  │  NO → 단일 에이전트
                    ┌─────────▼────────────────┐
                    │ Gate 2: 상호 독립 분석?   │
                    └─────────┬────────────────┘
                         YES  │  NO → 순차 실행
                    ┌─────────▼────────────────┐
                    │ Gate 3: 파일 충돌 없음?   │
                    └─────────┬────────────────┘
                         YES  │  NO → 파일 분배 또는 순차
                              ▼
                        ✅ 병렬 실행
```

**모드별 Gate 통과 패턴:**
| 모드 | Phase 1 (분석) | Phase 2 (수정) | Phase 3 (검증) |
|------|---------------|---------------|---------------|
| A (분석) | ✅ 병렬 (읽기만) | N/A | N/A |
| B (Auto-Fix) | ✅ 병렬 | ❌ 순차 (파일 수정) | ✅ 병렬 (독립 검증) |
| C (TDD) | ✅ 병렬 | ✅ 병렬 (다른 테스트 파일) | ✅ 병렬 |
| D (리팩토링) | ✅ 병렬 | ⚠️ worktree 격리 | ✅ 병렬 |

## JSON 계약 기반 결과 구조 (from dev-workflows)

모든 에이전트는 아래 JSON 구조로 결과를 반환합니다:

```json
{
  "agent": "에이전트명",
  "files_analyzed": ["파일1.ts", "파일2.rs"],
  "findings": [
    {
      "severity": "critical|major|minor|info",
      "title": "발견 제목",
      "file": "src/hooks/usePtyStream.ts",
      "line": 45,
      "description": "구체적 설명",
      "old_string": "현재 코드 (Edit 가능한 정확한 문자열)",
      "new_string": "수정된 코드",
      "auto_fixable": true,
      "defer_to": null,
      "rationale": "왜 이것이 문제인지",
      "task_alignment": "원래 분석 목표와의 관련성"
    }
  ],
  "score": {
    "naming": "8/10",
    "structure": "7/10"
  },
  "passed": true
}
```

**JSON 계약의 핵심 규칙:**
1. `old_string`은 파일에서 **정확히 복사**해야 함 (공백, 줄바꿈 포함)
2. `auto_fixable: false`인 항목은 구조 변경, 설계 판단 등 자동 수정 불가
3. `defer_to`가 설정되면 해당 전문가 결과에 병합
4. `severity` 기준: critical=크래시/보안, major=기능오작동, minor=개선권장, info=제안

## 자기 교정 루프 알고리즘 (from dev-workflows)

```
function selfCorrectionLoop(target, requiredPasses):
  consecutivePasses = 0
  iteration = 0
  overlookedIssues = []

  while consecutivePasses < requiredPasses:
    iteration++

    # Phase 1: Fresh subagent로 분석 (컨텍스트 격리)
    results = parallelAnalyze(target, freshContext=true)

    if results.hasIssues():
      # 이전에 놓쳤던 이슈 기록
      if iteration > 1:
        for issue in results.newIssues:
          overlookedIssues.push({
            pattern: issue.title,
            category: issue.agent,
            missedIn: iteration - 1,
            foundIn: iteration
          })

      consecutivePasses = 0  # 카운터 리셋
      fixAll(results.findings)  # errors 먼저, 그 다음 warnings
      verify()  # tsc/cargo/test

    else:
      consecutivePasses++

  # 놓친 패턴을 DB에 기록
  if overlookedIssues.length > 0:
    appendToOverlookedDB(overlookedIssues)

  return "APPROVED after {iteration} iterations, {requiredPasses} consecutive passes"
```

**모드별 requiredPasses:**
| 모드 | Passes | 사용 시점 |
|------|--------|----------|
| quick | 1 | 빠른 확인 |
| standard (기본) | 2 | 일반적 수정 |
| thorough | 3 | 중요한 릴리스 전 |

## 파일 락 조정 프로토콜 (from agent_farm)

Team 모드에서 여러 에이전트가 동시에 파일을 수정할 때 사용합니다.

### 조정 디렉토리 구조

```
.claude/coordination/
├── active_work_registry.json
├── completed_work_log.json
└── agent_locks/
    ├── agent_cleancode_1709000000.lock
    └── agent_rustexpert_1709000001.lock
```

### active_work_registry.json

```json
{
  "agent_cleancode_abc1": {
    "start_time": "2026-03-03T12:00:00Z",
    "files_locked": ["src/hooks/usePtyStream.ts", "src/lib/types.ts"],
    "features_working_on": "클린코드 리팩토링",
    "expected_completion": "2026-03-03T12:30:00Z"
  }
}
```

### 락 프로토콜

```
1. 작업 시작 전:
   - active_work_registry.json 읽기
   - 작업 대상 파일이 다른 에이전트에 의해 락 되어 있는지 확인
   - 충돌 시 → 다른 파일/모듈 선택
   - 충돌 없으면 → 레지스트리에 자신 등록 + 락 파일 생성

2. 작업 중:
   - 다른 에이전트의 파일에 접근하지 않음
   - 새 파일을 수정해야 하면 레지스트리 업데이트

3. 작업 완료:
   - 락 파일 삭제
   - active_work_registry에서 자신 제거
   - completed_work_log에 결과 기록

4. Stale 락 처리:
   - 2시간 이상 된 락은 stale로 간주
   - Stale 락은 무시하고 작업 진행 가능
```

## 2단계 리뷰 패턴 (from claude-pipeline)

Auto-Fix 후 수정 품질을 보장하기 위해 2단계로 리뷰합니다:

### Stage 1: Spec 리뷰 (목표 정합성)

```
Fresh subagent로 실행. 프롬프트:
"수정된 코드가 원래 발견 항목의 문제를 실제로 해결하는지 검증하세요.
 주의: 수정 에이전트의 보고서를 신뢰하지 마세요. 실제 코드를 읽고 확인하세요."

체크:
- 원래 이슈가 실제로 해결되었는가?
- 새로운 문제가 도입되지 않았는가?
- 과도한 수정 (scope creep)이 없는가?
```

### Stage 2: Quality 리뷰 (코드 품질)

```
Spec 리뷰 통과 후에만 실행. 프롬프트:
"수정된 코드의 품질을 평가하세요. git diff 범위: {base_sha}..{head_sha}"

체크:
- 수정 코드가 프로젝트 컨벤션을 따르는가?
- 가독성이 개선되었는가 (최소한 악화되지 않았는가)?
- 테스트가 수정과 함께 업데이트되었는가?
```

**각 단계에 재수정 루프:**
```
Stage 리뷰 → Pass? → 다음 단계
              ↓ Fail
        수정 → Stage 리뷰 반복 (최대 3회)
              ↓ 3회 실패
        수동 목록에 추가
```

## Defer-To 위임 매트릭스

에이전트 간 역할 충돌을 방지하는 명시적 위임 경계:

```
                     발견 영역
에이전트      에러처리  타입   성능   구조   테스트  React  Rust
─────────────────────────────────────────────────────────────
CleanCode      →BH     →TG    →PT    →AR     →TE    →RP   →RS
Architect      →BH     →TG    →PT    자기    →TE    →RP   →RS
BugHunter      자기    →TG    →PT    →AR     →TE    →RP   →RS
TypeGuard      →BH     자기   →PT    →AR     →TE    →RP   →RS
PerfTuner      →BH     →TG    자기   →AR     →TE    →RP   →RS
TestExpert     →BH     →TG    →PT    →AR     자기   →RP   →RS
ReactPro       →BH     →TG    →PT    →AR     →TE    자기  →RS
RustSage       →BH     →TG    →PT    →AR     →TE    →RP   자기

BH=BugHunter, TG=TypeGuard, PT=PerfTuner, AR=Architect
TE=TestExpert, RP=ReactPro, RS=RustSage
```

**규칙: 자기 영역이 아닌 이슈는 반드시 `defer_to` 필드에 표시하고 수정안을 제시하지 않는다.**

## 3-Tier 모델 라우팅 (Step 1.6) — v3 UPDATED

모델은 **haiku / sonnet / opus** 3-tier로 운용합니다.

| Tier | 모델 | 용도 | 입력 단가 | 출력 단가 |
|------|------|------|----------|----------|
| **Explore** | haiku 4.5 | 코드 탐색, 파일 스캔, 구조 파악 | $1/1M | $5/1M |
| **Execute** | sonnet 4.6 | 분석/구현/테스트 (대부분의 작업) | $3/1M | $15/1M |
| **Reason** | opus 4.6 | HIGH 난이도 코드의 추론 집약 분석 | $5/1M | $25/1M |

**참고:** Opus 4.6 (2026.02 출시)으로 Reason tier 비용이 1/3 수준으로 인하됨.
에이전트 frontmatter에서 `model` 필드를 제거하여 리드가 난이도에 따라 동적으로 모델을 결정합니다.

**코드 난이도 판정:**
| 난이도 | 모델 | 시그널 |
|--------|------|--------|
| LOW/MID | sonnet | CRUD, 설정, 분기 8개 이하, 300줄 이하 |
| HIGH | opus | 동시성, 제네릭/매크로, unsafe, 순환 복잡도 높음, 300줄+ |

**에이전트별 HIGH 난이도 오버라이드:**
| sonnet 유지 | opus 승격 | 이유 |
|-------------|----------|------|
| CleanCode | Architect | 패턴 매칭 vs 의존성 체인 추론 |
| TestExpert | BugHunter | 테스트 구조 vs 경쟁 조건/보안 |
| ReactPro | PerfTuner | React 패턴 vs 복잡도 분석 |
| — | TypeGuard | 제네릭/라이프타임 추론 |
| — | RustSage | 소유권/unsafe 추론 |

**Haiku 활용 시점:**
- Step 0 (Quick Explore): 파일 스캔, 구조 파악, 난이도 사전 판정
- 대규모 코드베이스(100+ 파일) 탐색
- 사용자가 `--model haiku`로 강제 지정 시

```
자기 교정 루프: 모든 pass에서 동일 모델 유지 (난이도 판정은 첫 pass에서 1회만)
사용자 오버라이드: --model sonnet|opus|haiku 로 전원 강제 지정 가능
```

## Haiku Explore 전략 (Step 0) — v3 NEW

본격 분석 전 haiku 기반 Explore 에이전트로 코드베이스를 사전 탐색합니다.

**왜 필요한가:**
- sonnet으로 모든 파일을 스캔하면 비용 낭비 (탐색은 추론이 아닌 패턴 매칭)
- haiku는 sonnet 대비 비용 1/10, 탐색/분류에 충분한 성능
- 사전 탐색 결과로 에이전트 편성과 모델 라우팅을 최적화

**실행 방법:**
```
Agent(
  subagent_type: "Explore",     # haiku 기반 탐색 에이전트 (built-in)
  prompt: "다음을 파악하세요:
    1. 대상 파일 목록 + 라인 수
    2. 파일 확장자별 언어 분류
    3. 테스트 파일 존재 여부
    4. 코드 난이도 시그널 (async/await, unsafe, 제네릭 등)
    5. 모듈 간 의존성 관계 (import/use 분석)"
)
```

**Step 0 결과 활용:**
```
Explore 결과 → 에이전트 편성 결정:
  files: [{path, lang, lines, difficulty}]
  tests_exist: true/false
  modules: [{name, files, dependencies}]

→ 편성:
  - difficulty=HIGH 파일 존재 → 해당 에이전트 opus 승격
  - lang=rust → RustSage 투입
  - tests_exist=false + TDD 모드 → TestExpert 투입
  - 파일 1~2개 → 단일 에이전트 (비용 최적화)
```

**스킵 조건:**
- `--skip-explore` 플래그 사용 시
- 이전 세션에서 같은 디렉토리를 이미 탐색한 경우
- 사용자가 `--experts` 플래그로 직접 에이전트를 지정한 경우

## Anti-Drift Detection (Step 3c) — v3 NEW

에이전트가 원래 분석 목표에서 벗어나는 "목표 드리프트"를 감지합니다.
(출처: Ruflo의 hierarchical coordinator validation pattern)

**왜 필요한가:**
- 에이전트가 분석 중 관련 없는 코드 스타일/패턴을 지적하는 경우
- Scope creep으로 리포트가 불필요한 noise로 채워지는 경우
- 자기 교정 루프에서 매 반복마다 새로운 unrelated 이슈를 생성하는 경우

**구현:**
```
JSON 계약에 task_alignment 필드 추가:
{
  "findings": [{
    ...
    "task_alignment": "이 발견이 원래 분석 목표와 어떻게 관련되는지 1줄 설명"
  }]
}

리드가 결과 수집 시:
1. 각 finding의 task_alignment 읽기
2. 원래 분석 목표(사용자 요청)와 비교
3. 관련성 판정:
   - 직접 관련: 리포트에 포함
   - 간접 관련: info 레벨로 다운그레이드
   - 무관: 필터링 (리포트에서 제외, 별도 "참고사항"으로 분리)
4. 드리프트 비율 = 무관 항목 수 / 전체 항목 수
   - 30% 이상: 해당 에이전트 결과에 경고 표시
   - 50% 이상: 해당 에이전트 결과 폐기 + 재실행 고려
```

**자기 교정 루프에서의 활용:**
```
1차 분석: 원래 목표 기준으로 이슈 발견
2차 분석: 1차 수정 검증 + 새 이슈 탐색
  → 2차에서 발견된 이슈가 원래 목표와 무관한 경우:
     "이것은 수정으로 인한 회귀가 아닌 기존 이슈입니다"
     → info로 다운그레이드, 별도 목록
  → 2차에서 발견된 이슈가 1차 수정과 관련된 경우:
     "1차 수정이 새로운 문제를 도입했습니다"
     → severity 유지, 즉시 수정
```

## Critical Consensus (Step 3d) — v3 NEW

severity: "critical" 발견은 교차 검증으로 확정합니다.
(출처: Ruflo의 Byzantine consensus pattern 경량 버전)

**왜 필요한가:**
- 단일 에이전트의 판단에 의존하면 false positive critical이 발생
- Critical은 즉시 수정 대상이므로 확실해야 함
- 불필요한 critical 수정은 코드 안정성을 해침

**프로토콜:**
```
1. 에이전트 A가 critical 발견을 보고
2. 리드가 다른 전문가 1명(B)에게 교차 검증 요청:
   "에이전트 A가 {파일:라인}에서 다음 critical 이슈를 발견했습니다:
    {description}
    이 파일을 읽고 이것이 정말 critical(데이터손실/보안/크래시)인지 판단하세요.
    critical/major/minor 중 선택하고 근거를 설명하세요."

3. 결과:
   - A와 B 모두 critical → 확정 (리포트에 "교차 검증 완료" 표시)
   - A는 critical, B는 major → major로 다운그레이드
   - A는 critical, B는 minor/info → 사용자에게 판단 요청

4. 검증자 선택 우선순위:
   - BugHunter의 발견 → Architect 또는 TypeGuard가 검증
   - Architect의 발견 → BugHunter 또는 CleanCode가 검증
   - TypeGuard의 발견 → BugHunter가 검증
   - 기타 → BugHunter가 기본 검증자
```

**비용 영향:**
- Critical이 발견되지 않으면 추가 비용 없음
- Critical 1건당 sonnet 1회 추가 호출 (~10K tokens)
- 통상 세션당 0~3건 수준

## 롤백 의사결정 트리

```
검증 실패 발생
├── 타입 에러?
│   ├── 수정된 파일에서 발생? → 해당 수정만 롤백
│   └── 다른 파일에서 발생? → 의존성 분석 후 관련 수정 모두 롤백
├── 테스트 실패?
│   ├── 수정과 직접 관련? → 해당 수정 롤백
│   └── 기존 실패 테스트? → 무시 (이전부터 실패)
├── 린트 에러?
│   ├── 자동 수정 가능? → eslint --fix 실행
│   └── 수동 필요? → 경고만 (롤백 안함)
└── 컴파일 에러?
    └── 항상 해당 수정 롤백 + 수동 목록에 추가
```

## 배치 패턴 선택

| 수정 규모 | 패턴 | 설명 |
|-----------|------|------|
| 10건 이하 | 리드 직접 수정 | 충돌 없음, 순서 제어 용이 |
| 10~50건 | code-fixer 위임 | 파일별 fixer 에이전트 순차 실행 |
| 50건 이상 | Worktree 격리 | 도메인별 병렬 수정, 병합 조율 |

## 검증 명령 자동 감지

```
package.json 존재?
  ├── scripts.test → npm test
  ├── scripts.lint → npm run lint
  └── tsconfig.json → npx tsc --noEmit

Cargo.toml 존재?
  ├── cargo check
  ├── cargo clippy -- -D warnings
  └── cargo test
```

## 모드 간 파이프라인 연결 (전체 배치)

```
모드 A 결과 ──→ 모드 B 입력 (수정 대상 목록)
                    ↓ 검증 게이트: tsc/cargo 통과?
              모드 B 결과 ──→ 모드 C 입력 (수정된 파일의 테스트 필요 목록)
                                  ↓ 검증 게이트: 테스트 통과?
                            모드 C 결과 ──→ 모드 D 입력 (구조적 문제 목록)
                                                ↓ 게이트: 사용자 승인?
                                          최종 통합 리포트
```

---

## Team 모드 (모드 T) 상세 전략

### Subagent 병렬 vs Team 모드 판단 트리

```
작업 수신
├── 읽기 전용 분석? → Subagent 병렬 (모드 A)
├── 소규모 수정 (파일 10개 이하)? → Subagent 병렬 (모드 B)
├── 대규모 수정 or 구현?
│   ├── 독립 모듈 3개 이상? → ✅ Team 모드
│   ├── 구현 + 테스트 + 리뷰 동시? → ✅ Team 모드
│   ├── 20개+ 파일에 걸친 수정? → ✅ Team 모드
│   └── 모듈 간 의존성 높음? → ⚠️ Team 모드 (계획 승인 필수)
└── 탐색적 디버깅? → ✅ Team 모드 (다각도 조사)
```

### Team 편성 패턴

#### 패턴 1: 모듈 분배형 (대규모 구현)

```
가장 일반적. 각 teammate에게 독립 모듈을 할당합니다.

Lead (Delegate 모드):
  └── 조율, 태스크 관리, 통합 검증

Teammate 1 (백엔드):
  └── src-tauri/src/ 전담
  └── Rust 구현, API 추가, 타입 정의

Teammate 2 (프론트엔드):
  └── src/components/ + src/hooks/ 전담
  └── React 구현, 상태 관리, UI

Teammate 3 (테스트):
  └── **/*.test.* + src-tauri/**/tests/ 전담
  └── Teammate 1,2 완료 후 즉시 테스트 작성

적합: 새 기능 구현, 전체 모듈 리팩토링
비용: 약 3배 (Lead + 3 teammates)
```

#### 패턴 2: 역할 분담형 (구현 + 즉시 리뷰)

```
구현과 리뷰를 동시에 진행합니다.

Lead (Delegate 모드):
  └── 조율, 최종 리포트

Teammate 1~2 (구현):
  └── 각자 담당 모듈 구현
  └── 완료 후 Teammate 3에 리뷰 요청 메시지

Teammate 3 (리뷰어):
  └── 구현 완료된 코드를 즉시 리뷰
  └── BugHunter + CleanCode + TypeGuard 역할 겸임
  └── 이슈 발견 시 구현 teammate에게 직접 메시지

적합: 품질이 중요한 릴리스, 보안 민감 코드
비용: 약 3~4배
```

#### 패턴 3: 탐색형 (디버깅/조사)

```
여러 가설을 동시에 검증합니다.

Lead:
  └── 가설 수립, 결과 종합

Teammate 1: 가설 A 검증 (예: 상태 관리 문제?)
Teammate 2: 가설 B 검증 (예: 비동기 타이밍 문제?)
Teammate 3: 가설 C 검증 (예: 데이터 흐름 문제?)

적합: 재현 어려운 버그, 성능 병목 탐색
비용: 약 3배, 단 디버깅 시간 대폭 단축
```

#### 패턴 4: 대규모 분석형

```
대규모 코드베이스를 모듈별로 나눠 분석합니다.

Lead:
  └── 결과 통합 + 리포트 생성

Teammate 1: src/hooks/ + src/lib/ (TypeGuard + BugHunter)
Teammate 2: src/components/ (ReactPro + CleanCode)
Teammate 3: src-tauri/src/ (RustSage + Architect)

적합: 전체 코드 오딧, 기술 부채 평가
비용: 약 3배, 단 분석 속도 3배 향상
```

### Team 태스크 분배 전략

```
function distributeTasksForTeam(target, mode):
  # 1. 대상 파일을 모듈별로 그룹핑
  modules = groupByModule(target)

  # 2. 모듈 간 의존성 분석
  deps = analyzeDependencies(modules)

  # 3. 독립 모듈끼리 묶어서 teammate에게 할당
  assignments = []
  for cluster in independentClusters(modules, deps):
    assignment = {
      teammate: selectExpert(cluster),  # 모듈 언어/도메인에 맞는 전문가
      modules: cluster.modules,
      tasks: generateTasks(cluster, mode)
    }
    assignments.push(assignment)

  # 4. 의존적 모듈은 순서 지정
  for dep in deps.sequential:
    tasks[dep.downstream].blockedBy = [tasks[dep.upstream].id]

  return assignments
```

### Team 모드 파일 충돌 방지 프로토콜

```
┌─────────────────────────────────────────┐
│        파일 충돌 방지 3단계              │
├─────────────────────────────────────────┤
│                                         │
│  1단계: 모듈 분배 (사전 방지)            │
│  ─────────────────────────              │
│  각 teammate에게 독립 디렉토리 할당      │
│  → "src-tauri/는 네 영역"               │
│  → 가장 효과적, 조율 비용 0             │
│                                         │
│  2단계: 파일 락 (실행 중 방지)           │
│  ─────────────────────────              │
│  .claude/coordination/ 파일 락 사용     │
│  → teammate가 파일 수정 전 락 확인      │
│  → 충돌 시 대체 파일 선택 또는 대기     │
│                                         │
│  3단계: 계획 승인 (최종 안전장치)        │
│  ─────────────────────────              │
│  teammate가 수정 전 계획서 제출          │
│  → Lead가 다른 teammate와 충돌 확인      │
│  → 승인 후에만 수정 실행                │
│                                         │
└─────────────────────────────────────────┘
```

### Team 모드 종료 프로토콜

```
1. Lead가 모든 태스크 완료 확인 (TaskList)
2. 통합 검증 실행:
   - npx tsc --noEmit
   - cargo check
   - npm test / cargo test
3. 검증 실패 시:
   - 해당 teammate 재활성화
   - 실패 원인 수정 요청
   - 재검증
4. 검증 통과 시:
   - 각 teammate에게 shutdown 요청 (순차)
   - teammate가 현재 작업 완료 후 승인
5. 모든 teammate 종료 확인
6. TeamDelete로 팀 인프라 정리
7. 최종 통합 리포트 생성

주의사항:
- 항상 Lead를 통해 정리 (teammate가 직접 정리 금지)
- 활성 teammate가 있으면 TeamDelete 실패
- 비정상 종료 시 ~/.claude/teams/ 수동 정리 필요
```

### Team 모드 비용 최적화

```
전략 1: Lead는 Opus, Teammate는 Sonnet
  → Lead의 조율 판단은 높은 추론 필요
  → Teammate의 구현/분석은 Sonnet으로 충분
  → 비용 약 40% 절감

전략 2: Teammate 수 최소화
  → 3명이면 충분한 곳에 5명 투입 금지
  → 조율 오버헤드로 오히려 느려질 수 있음

전략 3: 분석은 Subagent, 구현만 Team
  → 모드 A (분석)는 Agent tool 병렬로 충분
  → 모드 T는 파일 수정이 필요한 구현에만 사용

전략 4: teammate당 태스크 밀도
  → 5~6개 태스크/teammate 유지
  → 너무 적으면 idle 시간 낭비
  → 너무 많으면 컨텍스트 윈도우 소진
```

### AgentSpeak 프로토콜 (Team 모드 토큰 최적화) — v3 NEW

Team 모드에서 에이전트 간 메시지를 토큰 효율적 구조화 프로토콜로 전달합니다.
자연어 대비 **60-70% 토큰 절감**. (출처: yuvalsuede/claude-teams-language-protocol)

**왜 필요한가:**
- Team 모드에서 teammate 간 SendMessage로 자연어 소통 시 토큰 낭비
- "안녕하세요, 저는 Teammate 1입니다. src/hooks/ 분석을 완료했고..." → 불필요한 서사
- 구조화된 프로토콜로 정보 밀도를 극대화

**AgentSpeak 메시지 형식:**
```
[PREFIX] [AGENT_ID] → [TARGET] | [PAYLOAD]

접두사:
  STATUS:  진행 상태 보고 (Lead에게)
  FINDING: 발견 항목 전달 (Lead 또는 다른 에이전트에게)
  REQUEST: 파일 락/정보 요청
  BLOCKED: 차단 상태 + 사유
  DONE:    작업 완료 + 요약
  HANDOFF: 다른 에이전트에게 작업 위임

예시:
  STATUS: TM1 → LEAD | phase:analysis files:3/5 findings:2M,1m eta:2min
  FINDING: TM1 → LEAD | S:major F:src/hooks/use.ts L:45 T:"missing cleanup" fix:true
  REQUEST: TM2 → LEAD | lock:src/lib/types.ts reason:type-refactor
  BLOCKED: TM3 → LEAD | waiting:TM1 file:src/hooks/use.ts reason:dep-analysis
  DONE: TM1 → LEAD | files:5 findings:3C,5M,2m score:7/10 duration:4min
  HANDOFF: TM1 → TM3 | task:test-generation files:[src/hooks/use.ts] context:refactored-error-handling
```

**FINDING 축약 필드:**
```
S: severity (critical/major/minor/info → C/M/m/i)
F: file path
L: line number
T: title (짧게)
fix: auto_fixable (true/false → t/f)
defer: defer_to agent (없으면 생략)
```

**Team 프롬프트에 주입:**
```
에이전트 프롬프트 하단에 추가:

## 통신 프로토콜: AgentSpeak
다른 에이전트/Lead와 소통 시 자연어 대신 AgentSpeak 형식을 사용하세요:
- 상태 보고: STATUS: {ID} → LEAD | phase:{} files:{done}/{total} findings:{counts}
- 발견 보고: FINDING: {ID} → LEAD | S:{severity} F:{file} L:{line} T:"{title}"
- 완료 보고: DONE: {ID} → LEAD | files:{n} findings:{counts} score:{n}/10
자연어 설명이 필요한 경우에만 FINDING의 T: 필드를 확장하세요.
```

**Lead의 AgentSpeak 파싱:**
```
Lead는 AgentSpeak 메시지를 수신하면:
1. PREFIX로 메시지 유형 분류
2. 구조화된 필드 추출
3. FINDING은 JSON 계약 형식으로 변환하여 통합 리포트에 병합
4. BLOCKED는 즉시 해소 조치 (파일 락 해제, 태스크 재배분)
5. DONE은 teammate 종료 후보에 등록
```

### Team 모드 CLAUDE.md 권장 내용

Team 모드에서 teammate가 프로젝트 맥락을 이해하도록 CLAUDE.md에 다음을 포함하세요:

```markdown
## 모듈 경계
- src-tauri/: Rust 백엔드 (Tauri 커맨드, 터미널 관리)
- src/components/: React UI 컴포넌트
- src/hooks/: React 커스텀 훅
- src/lib/: 공유 유틸리티, 타입 정의

## 검증 방법
- TypeScript: npx tsc --noEmit
- Rust: cd src-tauri && cargo check
- 테스트: npm test / cargo test

## 코딩 컨벤션
- [프로젝트별 규칙 기재]
```

---

## PreCompact Hook 설정 — v3 NEW

장시간 Squad 세션에서 auto-compaction으로 분석 상태가 소실되는 것을 방지합니다.

**왜 필요한가:**
- Squad는 다단계 프로세스 (Explore → 편성 → 분석 → 수정 → 검증)
- Auto-compaction(95% 시 자동)이 발생하면 현재 진행 상태, 에이전트 결과, 수정 계획이 소실
- PreCompact hook으로 compaction 직전에 상태를 파일로 저장 → 복원 가능

**Hook 설정 (`.claude/settings.json`):**
```json
{
  "hooks": {
    "PreCompact": [
      {
        "matcher": "",
        "command": "cat > .claude/squad-state-snapshot.md << 'SNAPSHOT'\n# Squad State Snapshot (auto-saved before compaction)\n# Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)\n# Resume: 이 파일이 존재하면 Squad가 자동으로 상태를 복원합니다.\nSNAPSHOT"
      }
    ]
  }
}
```

**Squad 리드의 PreCompact 대응:**
```
PreCompact hook 발동 시, Squad 리드는 compaction 전에:

1. 현재 상태를 .claude/squad-state-snapshot.md에 기록:
   - current_phase: "analysis" | "fix" | "verify" | "self-correction"
   - agents_deployed: ["CleanCode", "BugHunter", ...]
   - findings_so_far: [JSON 계약 결과 요약]
   - files_modified: ["경로 목록"]
   - pending_fixes: [아직 적용 안 된 수정 목록]
   - self_correction_pass: 현재 pass 번호
   - model_routing: {agent: tier} 매핑

2. Compaction 후 복원:
   - squad-state-snapshot.md 존재 확인
   - 존재하면 상태 로드 → 중단된 phase부터 재개
   - "Compaction 후 복원됨. Phase: {phase}부터 계속합니다." 메시지 출력
   - 파일은 복원 후 삭제 (1회성)
```

**조기 컴팩션 설정 (권장):**
```bash
# 환경변수로 80%에서 미리 컴팩션 실행
export CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=80

# Squad 세션 시작 전 수동 컴팩션
# /compact 명령으로 컨텍스트 정리 후 시작
```

**PreToolUse hook으로 지침 재주입 (대안):**
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Agent",
        "command": "echo '## Squad 핵심 지침 재주입\n에이전트 실행 시 JSON 계약 준수, defer_to 위임, task_alignment 포함 필수.'"
      }
    ]
  }
}
```

---

## Persistent Learning (세션 간 학습) — v3 NEW

Overlooked DB를 확장하여 에이전트별 학습 패턴을 세션 간 축적합니다.

**왜 필요한가:**
- Overlooked DB(`.claude/squad-overlooked.md`)는 놓친 패턴만 기록
- 반복적으로 발생하는 false positive, 프로젝트 특화 컨벤션, 에이전트별 강약점은 미기록
- 세션 간 학습으로 분석 정밀도가 점진적으로 향상

**학습 디렉토리 구조:**
```
.claude/squad-memory/
├── project-profile.md        # 프로젝트 특성 (언어, 프레임워크, 컨벤션)
├── false-positives.md        # 반복 false positive 패턴
├── agent-effectiveness.md    # 에이전트별 정확도/강약점
└── convention-overrides.md   # 프로젝트 특화 룰 오버라이드
```

**project-profile.md (자동 생성):**
```markdown
# 프로젝트 프로파일
- 언어: TypeScript (80%), Rust (20%)
- 프레임워크: React 18, Tauri 2
- 테스트: vitest, cargo test
- 린트: eslint, clippy
- 빌드: vite, cargo
- 스타일: tailwindcss
- 최종 업데이트: 2026-03-06
```

**false-positives.md (자동 축적):**
```markdown
# False Positive 패턴

## CleanCode
- `any` 타입 사용 경고: FFI 바운더리에서는 허용 (3회 무시됨)
- 함수 크기 경고: SQL 빌더 함수는 50줄+ 허용 (프로젝트 컨벤션)

## BugHunter
- `unwrap()` 경고: CLI 초기화 코드에서는 허용 (fail-fast 의도)

## TypeGuard
- 제네릭 제약 부족 경고: internal API는 relaxed typing 허용
```

**agent-effectiveness.md (자동 축적):**
```markdown
# 에이전트 효과 추적

| 에이전트 | 세션 수 | 평균 findings | critical 정확도 | 주요 강점 |
|----------|--------|--------------|----------------|----------|
| CleanCode | 12 | 8.3 | N/A | 네이밍, DRY |
| BugHunter | 12 | 5.1 | 85% | 에러 핸들링 |
| TypeGuard | 8 | 3.2 | 90% | 제네릭 추론 |
```

**convention-overrides.md (사용자 설정):**
```markdown
# 프로젝트 컨벤션 오버라이드

## 무시할 룰
- CleanCode: 함수명에 한글 허용 (i18n 프로젝트)
- CleanCode: 파일당 export 10개+ 허용 (barrel files)
- BugHunter: console.log 경고 무시 (dev 환경)

## 강화할 룰
- BugHunter: SQL injection 체크 항상 critical
- TypeGuard: `as any` 사용 시 항상 major
```

**학습 사이클:**
```
세션 시작:
  1. .claude/squad-memory/ 존재 확인
  2. 존재하면 project-profile.md 로드 → Step 0 스킵 가능 (이미 파악)
  3. false-positives.md 로드 → 에이전트 프롬프트에 "무시할 패턴" 주입
  4. convention-overrides.md 로드 → 체크리스트 오버라이드

세션 중:
  5. 사용자가 finding을 거부/무시하면 → false positive 후보로 기록
  6. 같은 패턴이 3회 이상 거부되면 → false-positives.md에 자동 추가
  7. Critical Consensus에서 다운그레이드된 항목 추적

세션 종료:
  8. agent-effectiveness.md 업데이트 (findings 수, 정확도)
  9. project-profile.md 업데이트 (새 파일/언어 발견 시)
  10. Overlooked DB와 병합 (중복 제거)
```

**에이전트 프롬프트에 주입 (확장):**
```
기존 Overlooked DB 프리로딩에 추가:

## 프로젝트 특화 규칙
{convention-overrides.md에서 해당 에이전트 섹션}

## 무시할 패턴 (False Positive)
{false-positives.md에서 해당 에이전트 섹션}

→ 에이전트가 이미 알려진 false positive를 반복 보고하지 않음
→ 프로젝트 컨벤션에 맞는 분석 수행
```

**초기화 (`/squad init`):**
```
/squad init 실행 시:
1. .claude/squad-memory/ 디렉토리 생성
2. Explore 에이전트로 프로젝트 스캔 → project-profile.md 자동 생성
3. 빈 false-positives.md, agent-effectiveness.md, convention-overrides.md 생성
4. "Squad 학습 디렉토리 초기화 완료" 메시지
```
