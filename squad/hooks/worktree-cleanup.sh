#!/bin/bash
# worktree-cleanup.sh — 세션 종료 시 남은 squad worktree 자동 정리
# SessionEnd hook, matcher: ""

GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
[ -z "$GIT_ROOT" ] && exit 0

# squad worktree 경로 추출
WORKTREES=$(git worktree list --porcelain 2>/dev/null | awk '/^worktree .*\.squad-worktree-/{sub(/^worktree /,""); print}')

[ -z "$WORKTREES" ] && exit 0

while IFS= read -r WT_PATH; do
  [ -z "$WT_PATH" ] && continue

  # uncommitted 변경사항 확인
  if [ -d "$WT_PATH" ]; then
    DIRTY=$(cd "$WT_PATH" && git status --porcelain 2>/dev/null)
    if [ -n "$DIRTY" ]; then
      mkdir -p "$GIT_ROOT/.claude/squad-memory" 2>/dev/null
      BACKUP="$GIT_ROOT/.claude/squad-memory/worktree-stash-$(date +%Y%m%d%H%M%S).diff"
      # diff 캡처 후 staging 오염 방지 (reset stdout은 diff에 혼입 방지)
      (cd "$WT_PATH" && git add -A 2>/dev/null && git diff --cached HEAD 2>/dev/null) > "$BACKUP" 2>/dev/null
      (cd "$WT_PATH" && git reset HEAD >/dev/null 2>&1)
      # 빈 백업 파일 제거
      [ ! -s "$BACKUP" ] && rm -f "$BACKUP"
      if [ -s "$BACKUP" ]; then
        echo "WARNING: dirty worktree 발견. diff 백업: $BACKUP" >&2
      elif [ -n "$DIRTY" ]; then
        echo "ERROR: dirty worktree 백업 실패. worktree 보존: $WT_PATH" >&2
        continue
      fi
    fi
  fi

  git worktree remove --force "$WT_PATH" 2>/dev/null
done <<< "$WORKTREES"

# prune으로 참조 정리
git worktree prune 2>/dev/null

exit 0
