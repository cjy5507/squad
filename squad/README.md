# Squad v4 — Parallel Expert Agent Orchestrator

코드베이스를 다각도로 분석하는 11개 전문가 에이전트를 자율 편성하여 병렬 실행하는 Claude Code 플러그인.

## Features

- **11 Expert Agents** — CleanCode, Architect, BugHunter, TypeGuard, PerfTuner, TestExpert, ReactPro, RustSage, DocWriter, CodeExplorer, CodeFixer
- **Confidence Scoring** — 0-100 신뢰도, 80 미만 자동 필터링으로 노이즈 제거
- **7 Commands** — analyze, fix, build, review, team, init, reject
- **Build Mode** — ralph-style implement-until-done 루프
- **PR Review** — 4-에이전트 병렬 리뷰 + confidence scoring
- **Self-Correction Loop** — N-pass 자기 교정으로 수정 품질 보장
- **Anti-Drift + Critical Consensus** — 목표 이탈 방지, critical 교차 검증
- **Hooks** — JSON 검증, build 루프 지속, analyze 모드 수정 차단
- **Persistent Learning** — 프로젝트별 false positive/컨벤션 학습

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/cjy5507/squad/main/squad/install.sh | bash
```

## Commands

| Command | Description |
|---------|-------------|
| `/squad:analyze src/` | 코드 분석 (적응형 에이전트 편성) |
| `/squad:fix src/` | 자동 수정 + 자기 교정 루프 |
| `/squad:fix --thorough src/` | 3-pass 철저 모드 |
| `/squad:build "task"` | 구현 루프 (완료까지 반복) |
| `/squad:review` | PR 리뷰 (git diff 기반) |
| `/squad:review --comment` | PR 리뷰 + GitHub 코멘트 |
| `/squad:team src/` | Team 모드 (대규모 병렬) |
| `/squad:init` | 프로젝트 학습 초기화 |
| `/squad:reject {finding}` | False positive 등록 |

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

### Special
| Agent | Role |
|-------|------|
| **CodeExplorer** | 코드베이스 탐색 |
| **CodeFixer** | 배치 자동 수정 |

## Structure

```
squad/
├── .claude-plugin/plugin.json    # Plugin manifest
├── commands/                     # 7 slash commands
├── skills/squad-auto/SKILL.md    # Auto-trigger skill
├── agents/                       # 11 agent definitions
├── hooks/                        # Hook scripts
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
