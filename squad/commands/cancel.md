---
name: cancel
description: 진행 중인 Squad 작업을 취소합니다.
argument-hint: ""
---

# /squad:cancel — 작업 취소

진행 중인 Squad build/fix 루프를 즉시 취소합니다.

## 실행 절차

### 1. 상태 파일 확인

`.claude/squad-state.md`가 존재하는지 확인합니다.

파일이 없으면: "진행 중인 Squad 작업이 없습니다." 출력 후 종료.

### 2. 상태 업데이트

상태 파일의 내용을 읽고 다음 필드를 업데이트합니다:

```
mode: {현재 mode 유지}
status: cancelled
phase: {현재 phase 유지}
task: {현재 task 유지}
cancelled: {timestamp}
```

Write 도구로 `.claude/squad-state.md`를 덮어씁니다.

### 3. 완료 메시지 출력

```
Squad 작업이 취소되었습니다.
- mode: {mode}
- 마지막 phase: {phase}
- task: {task}

build-loop이 다음 Stop 이벤트에서 종료됩니다.
```
