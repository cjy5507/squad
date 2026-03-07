#!/bin/bash
# worktree-cleanup.sh — 세션 종료 시 남은 squad worktree 자동 정리
# Stop hook, matcher: ""

# .squad-worktree-* 패턴의 worktree 목록 확인
WORKTREES=$(git worktree list --porcelain 2>/dev/null | grep 'worktree' | awk '{print $2}' | grep '\.squad-worktree-' 2>/dev/null)

[ -z "$WORKTREES" ] && exit 0

while IFS= read -r WT_PATH; do
  [ -z "$WT_PATH" ] && continue
  # worktree 제거 (강제: uncommitted 변경사항도 제거)
  git worktree remove --force "$WT_PATH" 2>/dev/null
done <<< "$WORKTREES"

# prune으로 참조 정리
git worktree prune 2>/dev/null

exit 0
