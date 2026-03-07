# Squad v5.0 — All-in-One Code Quality Plugin

The ultimate Claude Code plugin: 13 expert agents orchestrated in parallel, with session memory, structured planning, worktree isolation, and compound learning built in.

## Features

- **13 Expert Agents** — CleanCode, Architect, BugHunter, TypeGuard, PerfTuner, TestExpert, ReactPro, RustSage, DocWriter, CodeExplorer, CodeFixer, ClaudeMdChecker, PlanArchitect
- **12 Commands** — analyze, fix, build, review, team, plan, memory, compound, init, reject, learn, cancel
- **8 Hooks** — capture-memory, inject-memory, validate-output, track-fix, guard-plan-mode, pre-compact, session-resume, worktree-cleanup
- **Session Memory** — Every tool use recorded; previous context auto-injected on session start
- **Plan Workflow** — 7-step structured planning: Explore → Q&A → 3 approaches → select → detail plan → build
- **Worktree Isolation** — `--worktree` flag sandboxes changes in a git worktree; apply only after review
- **Compound Learning** — `/squad:compound` distills session patterns into project conventions
- **Confidence Scoring** — 0–100 confidence on every finding; sub-80 filtered automatically
- **Self-Correction Loop** — N-pass correction guarantees fix quality
- **Anti-Drift + Critical Consensus** — Goal drift detection, critical findings cross-validated
- **Self-Learning** — Tracks fix history, detects reverts, scores agent accuracy per project
- **CLAUDE.md Compliance** — Project rules auto-checked on every run

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

# 3. Initialize project learning
/squad:init

# 4. Run commands
/squad:analyze src/        # Analyze code quality
/squad:fix src/            # Auto-fix issues
/squad:plan "add login"    # Plan a feature with 3 approaches
/squad:build "add login"   # Build end-to-end
/squad:memory auth         # Search session memory
/squad:compound            # Distill session learnings
```

## Commands

| Command | Description |
|---------|-------------|
| `/squad:analyze src/` | Analyze code quality (adaptive agent selection) |
| `/squad:fix src/` | Auto-fix + self-correction loop |
| `/squad:fix src/ --thorough` | 3-pass thorough mode |
| `/squad:fix src/ --worktree` | Fix in isolated git worktree |
| `/squad:build "task"` | Implement until done (ralph-style loop) |
| `/squad:build "task" --max-iter N` | Build with max N iterations |
| `/squad:build "task" --worktree` | Build in isolated git worktree |
| `/squad:plan "feature"` | 7-step structured planning with 3 approaches |
| `/squad:review` | PR review (git diff based) |
| `/squad:review --comment` | PR review + post GitHub comment |
| `/squad:team src/` | Team mode (large-scale parallel) |
| `/squad:memory` | Show last 20 session observations |
| `/squad:memory <keyword>` | Search session memory by keyword |
| `/squad:compound` | Distill session patterns into project knowledge |
| `/squad:init` | Initialize project learning |
| `/squad:reject {finding}` | Register false positive |
| `/squad:learn` | Learning statistics dashboard |
| `/squad:cancel` | Cancel in-progress task |

## Expert Agents

### Core (always active)
| Agent | Role |
|-------|------|
| **CleanCode** | Naming, function size, SRP, DRY, complexity |
| **Architect** | Dependencies, layers, SOLID, coupling |
| **BugHunter** | Bugs, edge cases, security, error handling |

### Contextual (condition-based)
| Agent | Condition |
|-------|-----------|
| **TypeGuard** | TypeScript / Rust type issues |
| **PerfTuner** | Performance-sensitive code |
| **TestExpert** | Test files / TDD |
| **ReactPro** | React / frontend code |
| **RustSage** | Rust code |
| **DocWriter** | Public APIs / libraries |

### Project
| Agent | Condition |
|-------|-----------|
| **ClaudeMdChecker** | Always active when CLAUDE.md exists |

### Special
| Agent | Role |
|-------|------|
| **CodeExplorer** | Codebase exploration and mapping |
| **CodeFixer** | Batch auto-fixing |
| **PlanArchitect** | Implementation plan with 3-approach comparison table |

## Session Memory System

Squad records every tool use and injects recent context at session start — no continuity lost across compactions or restarts.

### How it works

1. **Capture** — `capture-memory.sh` (PostToolUse `*`) appends `{timestamp, tool, input_summary, output_summary, file, session_id}` to `observations.jsonl` after every tool call
2. **Inject** — `inject-memory.sh` (SessionStart `""`) injects the last 50 observations into the conversation at every session start
3. **Resume** — If a build/fix was in-progress at compaction, the resume message is prepended automatically
4. **Search** — `/squad:memory [keyword]` searches across observations, fix history, and session summaries

### Memory files

```
.claude/squad-memory/
├── observations.jsonl      # All tool usage (auto-recorded)
├── fix-history.jsonl       # Fix history (auto-recorded)
├── session-summary.md      # Session summaries (auto-saved at compaction)
├── learnings.md            # Compound session learnings
├── project-profile.md      # Project characteristics
├── false-positives.md      # Repeated false positive patterns
├── agent-effectiveness.md  # Per-agent accuracy scores (0–100)
└── convention-overrides.md # Project-specific rule overrides
```

## Plan Workflow

`/squad:plan` guides you through structured planning before any code is written:

```
Step 1  Explore     code-explorer maps the relevant codebase
Step 2  Q&A         2–3 clarifying questions (user answers)
Step 3  3 Approaches plan-architect generates a comparison table
Step 4  Select      user picks A / B / C (or customizes)
Step 5  Detail Plan file-level plan saved to squad-memory/plan.md
Step 6  Confirm     summary + "start /squad:build?"
```

The comparison table shows: strategy, changed files, estimated LOC, risk level (LOW/MID/HIGH), pros, cons.

## Worktree Isolation

Add `--worktree` to `fix` or `build` for sandboxed execution:

```bash
/squad:fix src/ --worktree
/squad:build "refactor auth" --worktree
```

Flow:
1. `git worktree add .squad-worktree-{timestamp} HEAD`
2. All changes run inside the worktree
3. Diff displayed on completion
4. User confirms: "Apply to main branch? (y/n)"
5. On yes: cherry-pick or file copy to apply
6. Worktree auto-removed on session Stop

## Compound Learning

`/squad:compound` analyzes the session and proposes knowledge updates:

- Repeated fix patterns → suggest additions to `convention-overrides.md`
- New frameworks/libraries detected → suggest updates to `project-profile.md`
- Session learnings always saved to `learnings.md` (no confirmation needed)

## Self-Learning System

Squad improves accuracy the more you use it:

1. **Fix Tracking** — `track-fix.sh` records every Edit in fix/build mode to `fix-history.jsonl`
2. **Revert Detection** — Next fix checks if previous fixes were reverted → auto-registers false positives
3. **Agent Scoring** — Fix retained: +1; fix reverted: −5 (range 0–100)
4. **Adaptive Threshold** — Low-scoring agents get higher confidence thresholds, reducing noise
5. **Hotspot Identification** — Files edited repeatedly flagged for focused analysis
6. **Compaction Survival** — `pre-compact.sh` saves session summary before context compression
7. **Auto-Resume** — `session-resume.sh` notifies Claude of in-progress work after compaction

## Hooks (8 total)

| Hook | Event | Purpose |
|------|-------|---------|
| `capture-memory.sh` | PostToolUse `*` | Record all tool usage to observations.jsonl |
| `validate-output.sh` | PostToolUse `Agent` | Validate agent JSON contract output |
| `track-fix.sh` | PostToolUse `Edit` | Record fix history in fix/build mode |
| `guard-plan-mode.sh` | PreToolUse `Edit\|Write` | Block edits in analyze-only mode |
| `pre-compact.sh` | PreCompact | Save session summary before compaction |
| `session-resume.sh` | SessionStart `compact` | Notify Claude of in-progress work after compaction |
| `inject-memory.sh` | SessionStart `""` | Inject last 50 observations at every session start |
| `worktree-cleanup.sh` | Stop | Auto-remove leftover `.squad-worktree-*` worktrees |

## Structure

```
squad/
├── .claude-plugin/plugin.json    # Plugin manifest (v5.0.0)
├── commands/                     # 12 slash commands
│   ├── analyze.md
│   ├── fix.md                    # + --worktree
│   ├── build.md                  # + --worktree
│   ├── review.md
│   ├── team.md
│   ├── plan.md                   # NEW
│   ├── memory.md                 # NEW
│   ├── compound.md               # NEW
│   ├── init.md
│   ├── reject.md
│   ├── learn.md
│   └── cancel.md
├── agents/                       # 13 agent definitions
│   ├── clean-code-expert.md
│   ├── architect-expert.md
│   ├── bug-hunter.md
│   ├── type-guard.md
│   ├── perf-tuner.md
│   ├── test-expert.md
│   ├── react-pro.md
│   ├── rust-sage.md
│   ├── doc-writer.md
│   ├── claude-md-checker.md
│   ├── code-explorer.md
│   ├── code-fixer.md
│   └── plan-architect.md        # NEW
├── hooks/                        # 8 hook scripts
│   ├── hooks.json
│   ├── capture-memory.sh         # NEW
│   ├── inject-memory.sh          # NEW
│   ├── validate-output.sh
│   ├── track-fix.sh
│   ├── guard-plan-mode.sh
│   ├── pre-compact.sh
│   ├── session-resume.sh
│   └── worktree-cleanup.sh       # NEW
├── skills/squad-auto/SKILL.md    # Auto-trigger skill
├── references/                   # Shared references
├── install.sh
└── uninstall.sh
```

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/cjy5507/squad/main/squad/uninstall.sh | bash
```

## License

MIT
