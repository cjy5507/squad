#!/bin/bash
# _filelock.sh — portable mkdir 기반 파일 잠금 유틸리티 (stale lock 자동 탐지)
# capture-memory.sh, track-fix.sh에서 source로 공유

filelock_acquire() {
  local lock_dir="$1" i=0
  local max_retries=100   # 100 * 0.05s = 5초 타임아웃
  local retry_interval=0.05
  local max_lock_age=30   # stale lock 판정 기준 (초)
  while ! mkdir "$lock_dir" 2>/dev/null; do
    # stale lock 탐지: max_lock_age초 이상 오래된 lock은 강제 제거
    if [ -d "$lock_dir" ]; then
      local lock_mtime
      lock_mtime=$(stat -f%m "$lock_dir" 2>/dev/null || stat -c%Y "$lock_dir" 2>/dev/null || echo 0)
      local now
      now=$(date +%s)
      if [ $((now - lock_mtime)) -gt "$max_lock_age" ] 2>/dev/null; then
        rmdir "$lock_dir" 2>/dev/null
        continue
      fi
    fi
    i=$((i + 1))
    [ "$i" -ge "$max_retries" ] && return 1
    sleep "$retry_interval"
  done
  return 0
}

filelock_release() {
  rmdir "$1" 2>/dev/null
}
