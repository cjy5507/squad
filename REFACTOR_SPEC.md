# Squad v4 Refactor Specification

## Goal
Completely rewrite Squad from v3 (legacy skill-based) to v4 (official Claude Code plugin format).
This is a FULL rewrite — delete old structure, create new.

## Current Structure (DELETE THIS)
```
skill/SKILL.md (461 lines, monolithic)
skill/strategy-guide.md (914 lines)
skill/checklists.md
skill/cost-guide.md
skill/lang-rules.md
agents/*.md (10 agents)
install.sh / uninstall.sh
```

## Target Structure (CREATE THIS)
```
squad/
├── .claude-plugin/
│   └── plugin.json                ← Plugin manifest
├── commands/
│   ├── analyze.md                 ← /squad:analyze — code analysis
│   ├── fix.md                     ← /squad:fix — auto-fix with self-correction
│   ├── build.md                   ← /squad:build — OMC-style implement-until-done loop ⭐ NEW
│   ├── review.md                  ← /squad:review — PR review with confidence scoring ⭐ NEW
│   ├── team.md                    ← /squad:team — parallel team mode
│   ├── init.md                    ← /squad:init — initialize project learning
│   └── reject.md                  ← /squad:reject — register false positive
├── skills/
│   └── squad-auto/
│       └── SKILL.md               ← Auto-trigger skill (~50 lines, minimal)
├── agents/
│   ├── code-explorer.md           ← Codebase exploration (from feature-dev) ⭐ NEW
│   ├── clean-code-expert.md
│   ├── architect-expert.md
│   ├── bug-hunter.md
│   ├── type-guard.md
│   ├── perf-tuner.md
│   ├── test-expert.md
│   ├── react-pro.md
│   ├── rust-sage.md
│   ├── doc-writer.md
│   └── code-fixer.md
├── hooks/
│   ├── hooks.json                 ← Hook definitions
│   ├── validate-output.sh         ← Validate agent JSON output
│   ├── build-loop.sh              ← Stop hook for build mode (ralph-style)
│   └── guard-plan-mode.sh         ← Block edits in analyze mode
├── references/
│   ├── checklists.md
│   ├── lang-rules.md
│   ├── json-contract.md           ← Shared JSON output format (DRY)
│   └── cost-guide.md
├── install.sh                     ← Updated installer
├── uninstall.sh                   ← Updated uninstaller
└── README.md                      ← Updated with new structure
```

## Key Design Decisions

### 1. Commands (each is a focused markdown file)
Each command loads ONLY what it needs. No more 461-line monolith.

**analyze.md** (~80 lines):
- Squad formation based on file count (adaptive)
- Parallel agent execution via Agent tool
- Confidence scoring on findings (0-100, filter below 80)
- Anti-drift detection
- Critical consensus (cross-verify critical findings)
- Reference: checklists.md, json-contract.md

**fix.md** (~60 lines):
- Load analyze results → batch fix
- Self-correction loop (2-pass default, 3-pass with --thorough)
- Line-reverse ordering, old_string verification
- Build/test verification after each fix

**build.md** (~80 lines) ⭐ NEW:
- OMC/ralph-style implementation loop
- Phase 1: Explore (code-explorer agent)
- Phase 2: Plan → .claude/squad-plan.json
- Phase 3: Implement (code-fixer agent reads plan)
- Phase 4: Verify (build/test)
- Uses Stop hook (build-loop.sh) to keep iterating until done
- Saves state to .claude/squad-state.md for compaction recovery
- completion-promise pattern from ralph-wiggum

**review.md** (~60 lines) ⭐ NEW:
- PR-focused review (git diff based)
- 4 parallel agents: CLAUDE.md compliance + bug detection + history context + code quality
- Confidence scoring (0-100), threshold 80
- Optional --comment flag to post to GitHub PR

**team.md** (~60 lines):
- Agent Teams for large-scale parallel work
- Module distribution + file lock coordination
- AgentSpeak protocol for efficient communication

### 2. Confidence Scoring (CRITICAL IMPROVEMENT)
Every finding gets 0-100 confidence score:
```json
{
  "severity": "major",
  "confidence": 85,
  "evidence": "line 45: response.data accessed without null check, but fetchUser() returns nullable"
}
```
- Below 80 = filtered from report
- Agents must provide evidence for each finding
- This is the #1 SE improvement — reduces noise dramatically

### 3. Hooks (real code, not prompts)

**hooks.json:**
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Agent",
        "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/validate-output.sh"
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/build-loop.sh"
      }
    ]
  }
}
```

**validate-output.sh**: Checks agent output is valid JSON, has required fields
**build-loop.sh**: If build mode active + not complete → block exit, re-inject prompt
**guard-plan-mode.sh**: In analyze mode, warn if agent tries to edit files

### 4. JSON Contract (shared reference, DRY)
All agents reference `references/json-contract.md` instead of repeating JSON format in every agent file.

### 5. Agent Changes
- Keep all 10 existing agents but SLIM them down
- Remove duplicate JSON contract (moved to references/)
- Add confidence field to output
- Add code-explorer.md (new, from feature-dev benchmark)
- Each agent ~30-40 lines (currently 60-85)

### 6. install.sh / uninstall.sh
- Support both legacy install (~/.claude/skills) and plugin install (--plugin-dir)
- Backup with timestamp
- Version check

### 7. What to DELETE
- skill/SKILL.md (replaced by commands/ + skills/squad-auto/)
- skill/strategy-guide.md (914 lines — relevant parts absorbed into commands/)
- Old install/uninstall that copies to ~/.claude/

## Style Guide
- Korean comments/docs where original was Korean
- Concise, no fluff
- SE-style: if it can be code, make it code (not prompt)
- Follow Anthropic's official plugin patterns exactly
