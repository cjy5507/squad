# Squad v4.2 — Parallel Expert Agent Orchestrator

코드베이스를 다각도로 분석하는 12개 전문가 에이전트를 자율 편성하여 병렬 실행하는 Claude Code 플러그인.

## Features

- **12 Expert Agents** — CleanCode, Architect, BugHunter, TypeGuard, PerfTuner, TestExpert, ReactPro, RustSage, DocWriter, CodeExplorer, CodeFixer, ClaudeMdChecker
- **Confidence Scoring** — 0-100 신뢰도, 80 미만 자동 필터링으로 노이즈 제거
- **9 Commands** — analyze, fix, build, review, team, init, reject, learn, cancel
- **Build Mode** — ralph-style implement-until-done 루프 (max-iterations 지원)
- **PR Review** — 4-에이전트 병렬 리뷰 + confidence scoring
- **Self-Correction Loop** — N-pass 자기 교정으로 수정 품질 보장
- **Anti-Drift + Critical Consensus** — 목표 이탈 방지, critical 교차 검증
- **Hooks** — JSON 검증, build 루프 지속, analyze 모드 수정 차단, 수정 추적, 컴팩션 전 학습 저장, 컴팩션 후 자동 재개
- **Self-Learning System** — 수정 이력 추적, 리버트 자동 감지, 에이전트 정확도 스코어링, 핫스팟 파일 식별
- **Persistent Learning** — 프로젝트별 false positive/컨벤션 학습
- **CLAUDE.md Compliance** — 프로젝트 룰 자동 준수 검사

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/cjy5507/squad/main/squad/install.sh | bash
```

## Quick Start

```bash
# 1. Install
curl -fsSL https://raw.githubusercontent.com/cjy5507/squad/main/squad/install.sh | bash

# 2. Open Claude Code in your project
cd your-project
claude

# 3. Run a command
/squad:analyze src/       # Analyze code quality
/squad:fix src/           # Auto-fix issues
/squad:build "add login"  # Build a feature end-to-end
/squad:review             # Review PR changes
```

## Commands

| Command | Description |
|---------|-------------|
| `/squad:analyze src/` | 코드 분석 (적응형 에이전트 편성) |
| `/squad:fix src/` | 자동 수정 + 자기 교정 루프 |
| `/squad:fix --thorough src/` | 3-pass 철저 모드 |
| `/squad:build "task"` | 구현 루프 (완료까지 반복) |
| `/squad:build "task" --max-iter N` | 구현 루프 (최대 N회 반복) |
| `/squad:review` | PR 리뷰 (git diff 기반) |
| `/squad:review --comment` | PR 리뷰 + GitHub 코멘트 |
| `/squad:team src/` | Team 모드 (대규모 병렬) |
| `/squad:init` | 프로젝트 학습 초기화 |
| `/squad:reject {finding}` | False positive 등록 |
| `/squad:learn` | 학습 통계 대시보드 |
| `/squad:cancel` | 진행 중인 작업 취소 |

## Expert Agents

### Core (항상 투입)
| Agent | Role |
|-------|------|
| **CleanCode** | 네이밍, 함수 크기, SRP, DRY, 복잡도 |
| **Architect** | 의존성, 레이어, SOLID, 결합도 |
| **BugHunter** | 버그, 엣지케이스, 보안, 에러 처리 |

### Contextual (상황별 투입)
| Agent | Condition |
|-------|-----------|
| **TypeGuard** | TypeScript/Rust 타입 |
| **PerfTuner** | 성능 민감 코드 |
| **TestExpert** | 테스트 파일/TDD |
| **ReactPro** | React/프론트엔드 |
| **RustSage** | Rust 코드 |
| **DocWriter** | 공개 API/라이브러리 |

### Project (프로젝트 룰)
| Agent | Condition |
|-------|-----------|
| **ClaudeMdChecker** | CLAUDE.md 존재 시 항상 투입 |

### Special
| Agent | Role |
|-------|------|
| **CodeExplorer** | 코드베이스 탐색 |
| **CodeFixer** | 배치 자동 수정 |

## Self-Learning System

Squad는 사용할수록 정확도가 향상되는 자기 학습 시스템을 내장하고 있습니다.

### 작동 원리

1. **수정 추적** — `PostToolUse` 훅이 fix/build 모드의 모든 Edit을 `fix-history.jsonl`에 기록
2. **리버트 감지** — 다음 fix 실행 시 이전 수정이 되돌려졌는지 자동 감지, false positive로 등록
3. **에이전트 스코어링** — 수정 유지 시 +1점, 리버트 시 -5점으로 정확도 자동 조정
4. **적응형 임계값** — 점수가 낮은 에이전트는 confidence 임계값이 자동 상향되어 노이즈 감소
5. **핫스팟 식별** — 반복 수정 파일을 식별하여 집중 분석 대상으로 지정
6. **세션 생존** — `PreCompact` 훅이 컴팩션 전 세션 요약을 저장하여 컨텍스트 유실 방지
7. **컴팩션 재개** — `SessionStart` 훅이 컴팩션 후 in-progress 작업을 자동으로 Claude에 알림

### 학습 데이터

```
.claude/squad-memory/
├── project-profile.md        # 프로젝트 특성
├── false-positives.md        # 반복 false positive 패턴
├── agent-effectiveness.md    # 에이전트별 정확도 (0-100)
├── convention-overrides.md   # 프로젝트 특화 룰 오버라이드
├── fix-history.jsonl         # 수정 이력 (자동 기록)
└── session-summary.md        # 세션 요약 (자동 기록)
```

`/squad:learn`으로 학습 통계를 확인할 수 있습니다.

## Structure

```
squad/
├── .claude-plugin/plugin.json    # Plugin manifest
├── commands/                     # 9 slash commands
├── skills/squad-auto/SKILL.md    # Auto-trigger skill
├── agents/                       # 12 agent definitions
├── hooks/                        # Hook scripts (6 hooks)
├── references/                   # Shared references (DRY)
├── install.sh
└── uninstall.sh
```

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/cjy5507/squad/main/squad/uninstall.sh | bash
```

## License

MIT
