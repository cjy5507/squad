# Squad v3 — Parallel Expert Agent Orchestrator for Claude Code

코드베이스를 다각도로 분석하는 전문가 에이전트 스쿼드를 자율 편성하여 병렬 실행하는 Claude Code 플러그인입니다.

## Features

- **10 Expert Agents** — CleanCode, Architect, BugHunter, TypeGuard, PerfTuner, TestExpert, ReactPro, RustSage, DocWriter, CodeFixer
- **3-Tier Model Routing** — Haiku(탐색) / Sonnet(실행) / Opus(고난이도) 자동 선택
- **5 Execution Modes** — Analyze, Auto-Fix, TDD, Refactor, Team
- **AgentSpeak Protocol** — Team 모드 에이전트 간 토큰 60-70% 절감 통신
- **Self-Correction Loop** — N-pass 자기 교정으로 수정 품질 보장
- **Anti-Drift Detection** — Scope creep 자동 필터링
- **Critical Consensus** — Critical 발견 교차 검증
- **Persistent Learning** — 세션 간 학습 데이터 축적
- **PreCompact Hook** — 컨텍스트 컴팩션 시 상태 자동 보존

## Installation

### One-liner (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/cjy5507/squad/main/install.sh | bash
```

### Manual

```bash
git clone https://github.com/cjy5507/squad.git
cd squad

# Copy skill files
mkdir -p ~/.claude/skills/squad
cp skill/*.md ~/.claude/skills/squad/

# Copy agent files
mkdir -p ~/.claude/agents
cp agents/*.md ~/.claude/agents/
```

## Usage

```bash
/squad src/hooks/                           # Analyze (auto squad formation)
/squad fix src/hooks/                       # Auto-Fix (2-pass)
/squad fix --thorough src/hooks/            # Auto-Fix (3-pass)
/squad fix --model opus src/hooks/          # Force opus for all agents
/squad fix --experts CleanCode,BugHunter .  # Specific experts only
/squad tdd src/components/                  # TDD generation
/squad refactor src/lib/                    # Refactoring
/squad batch src/                           # Full pipeline
/squad team src/                            # Team mode (parallel sessions)
/squad team --delegate --teammates 3 src/   # Team Delegate mode
/squad init                                 # Initialize learning directory
```

## Expert Agents

### Tier 1 — Core (always deployed)

| Agent | Role |
|-------|------|
| **CleanCode** | Naming, function size, SRP, DRY, KISS, complexity |
| **Architect** | Dependencies, layer separation, coupling, SOLID |
| **BugHunter** | Potential bugs, edge cases, error handling, security |

### Tier 2 — Contextual (deployed based on code)

| Agent | Condition |
|-------|-----------|
| **TestExpert** | Test files exist or TDD requested |
| **PerfTuner** | Performance-sensitive code (loops, DB, API) |
| **TypeGuard** | TypeScript/Rust type system |
| **ReactPro** | React/frontend code |
| **RustSage** | Rust code |
| **DocWriter** | Public API/library code |

### Special

| Agent | Role |
|-------|------|
| **CodeFixer** | Applies fixes from analysis (Edit permissions) |

## Execution Flow

```
Step 0: Quick Explore (Haiku) → file scan, difficulty assessment
Step 1: Squad Formation → select agents based on code
Step 1.5: 3-Gate Decision → parallel vs sequential
Step 1.6: Model Routing → haiku/sonnet/opus per agent
Step 2: Parallel Execution → Agent tool with subagent_type
Step 3: Integration → defer-to merge, anti-drift, critical consensus
```

## 3-Tier Model Routing

| Tier | Model | Use | Cost |
|------|-------|-----|------|
| Explore | Haiku 4.5 | File scanning, structure | $1/$5 per 1M tokens |
| Execute | Sonnet 4.6 | Analysis/implementation | $3/$15 per 1M tokens |
| Reason | Opus 4.6 | HIGH difficulty reasoning | $5/$25 per 1M tokens |

## File Structure

```
~/.claude/
├── skills/squad/
│   ├── SKILL.md              # Main orchestrator (loaded on /squad)
│   ├── checklists.md         # Per-agent analysis criteria
│   ├── cost-guide.md         # Token/cost estimates
│   └── strategy-guide.md     # Detailed strategies & protocols
├── agents/
│   ├── clean-code-expert.md  # CleanCode agent definition
│   ├── architect-expert.md   # Architect agent definition
│   ├── bug-hunter.md         # BugHunter agent definition
│   ├── test-expert.md        # TestExpert agent definition
│   ├── perf-tuner.md         # PerfTuner agent definition
│   ├── type-guard.md         # TypeGuard agent definition
│   ├── react-pro.md          # ReactPro agent definition
│   ├── rust-sage.md          # RustSage agent definition
│   ├── doc-writer.md         # DocWriter agent definition
│   └── code-fixer.md         # CodeFixer agent definition (write access)
├── squad-memory/             # Persistent learning (created by /squad init)
└── squad-overlooked.md       # Overlooked patterns DB (auto-generated)
```

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/cjy5507/squad/main/uninstall.sh | bash
```

## License

MIT
