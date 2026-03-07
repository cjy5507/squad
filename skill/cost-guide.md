# Squad 비용 가이드

## 모드별 예상 토큰 사용량

| 모드 | 에이전트 수 | 예상 토큰 | 비고 |
|------|-----------|----------|------|
| Quick Scan (1-2 파일) | 1명 | ~20K | 단일 전문가 |
| Quick Scan (3-5 파일) | 2명 | ~50K | Core 2명 |
| Deep Analysis (6-15 파일) | 3-5명 | ~150K | Core + Tier 2 |
| Full Audit (16+ 파일) | 전원 | ~300K+ | 모든 관련 전문가 |
| Auto-Fix 2-pass | 분석+수정 | ~200K | 자기 교정 포함 |
| Auto-Fix 3-pass (thorough) | 분석+수정 | ~300K | 철저 모드 |
| TDD 생성 | 3-4명 | ~150K | 분석+생성+리뷰 |
| 리팩토링 | 2-3명 | ~120K | worktree 격리 |
| Team 모드 | 3-5 teammate | ~200K × N | teammate당 독립 컨텍스트 |

## 3-Tier 모델 비용 비교

| Tier | 모델 | 입력 단가 | 출력 단가 | 용도 |
|------|------|----------|----------|------|
| Explore | haiku 4.5 | $1/1M | $5/1M | 코드 탐색, 파일 스캔 |
| Execute | sonnet 4.6 | $3/1M | $15/1M | 분석/구현 (대부분) |
| Reason | opus 4.6 | $5/1M | $25/1M | HIGH 난이도 추론 |

**참고:** Opus 4.6 출시(2026.02)로 가격이 대폭 인하되어 Reason tier 비용 부담이 크게 감소.

## 비용 절감 전략

### 전략 1: Haiku로 사전 탐색 (Step 0)
```
기존: sonnet으로 모든 파일 스캔 → 편성 → 분석
개선: haiku로 빠른 탐색 → 편성 → sonnet으로 분석
절감: Step 0에서 ~67% 절감 (haiku = sonnet의 1/3 비용)
```

### 전략 2: 적응형 에이전트 수
```
기존: Quick Scan = 항상 Core 3명
개선: 파일 1-2개면 1명, 3-5개면 2명
절감: 소규모 분석에서 ~60% 절감
```

### 전략 3: 분석은 Subagent, 구현만 Team
```
모드 A (분석): Agent tool 서브에이전트 (비용 낮음)
모드 T (Team): 파일 수정 필요한 대규모 구현만 (비용 높음)
→ 분석에 Team 모드를 사용하지 않음으로써 3-4배 절감
```

### 전략 4: 정적 모델 라우팅 (frontmatter 기반)
```
⚠️ Agent tool에 model 파라미터 없음 → 동적 모델 선택 불가
Workers: model: sonnet (agent frontmatter에 고정 — 비용 효율)
Explore: haiku (빌트인 자동)
Opus 필요 시: 해당 agent .md의 frontmatter를 model: opus로 수정
→ sonnet 기본값으로 불필요한 opus 비용 방지
```

### 전략 5: 컨텍스트 효율화
```
- 에이전트 프롬프트에 전체 코드가 아닌 파일 경로만 전달
- 체크리스트는 해당 에이전트 것만 포함 (전체 X)
- Overlooked DB는 최근 10건만 주입
- 불필요한 MCP 서버 비활성화 (시스템 프롬프트 토큰 절감)
```

### 전략 6: 스킬 vs CLAUDE.md
```
CLAUDE.md: 매 턴마다 로드 → 토큰 누적
스킬: 호출 시에만 로드 → ~82% 토큰 절감
→ 반복 사용하는 지침은 스킬로 관리
```

## /squad cost 예상 출력 예시

```
Squad 비용 예상:
  대상: src/hooks/ (파일 8개, ~1,200줄)
  모드: Deep Analysis
  편성: CleanCode + BugHunter + TypeGuard + ReactPro (4명)
  모델: haiku(탐색) + sonnet(분석) × 4
  예상: ~120K tokens (~$0.50)

  Auto-Fix 추가 시: +80K tokens (~$0.35)
  총 예상: ~200K tokens (~$0.85)
```
