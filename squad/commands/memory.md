---
name: memory
description: 메모리 검색 — 이전 세션 관찰, 수정 이력, 세션 요약을 통합 검색합니다.
argument-hint: "[검색어]"
---

# /squad:memory — 메모리 검색

세션 간 기억된 관찰, 수정 이력, 세션 요약을 검색합니다.

## 동작

### 검색어가 없는 경우

`observations.jsonl`의 최근 20개 관찰을 시간순으로 표시:

```
[timestamp] tool (file): input_summary
```

### 검색어가 있는 경우

아래 파일 전체를 grep으로 키워드 검색:

1. `.claude/squad-memory/observations.jsonl` — tool 사용 관찰
2. `.claude/squad-memory/fix-history.jsonl` — 수정 이력
3. `.claude/squad-memory/session-summary.md` — 세션 요약
4. `.claude/squad-memory/learnings.md` — compound 학습 내용 (존재 시)

결과를 타입별로 구분하여 시간순 정렬 후 출력:

```
=== 관찰 (observations) ===
[2024-01-15T10:23:11Z] Edit (src/auth.ts): {"file_path":"src/auth.ts"...

=== 수정 이력 (fix-history) ===
{"timestamp":"2024-01-15T10:25:00Z","file":"src/auth.ts","agent":"bug-hunter"...

=== 세션 요약 (session-summary) ===
## Session: 2024-01-15T10:00:00Z
- mode: fix
...
```

## 실행 절차

1. `.claude/squad-memory/` 디렉토리 존재 확인
   - 없으면: "메모리가 없습니다. /squad:init을 먼저 실행하세요." 출력 후 종료

2. 검색어 유무 확인:
   - **없음**: `observations.jsonl` tail -20 읽어서 포맷팅 출력
   - **있음**: 각 파일에 grep -i {검색어}로 키워드 검색

3. 결과 없으면: "'{검색어}'에 대한 결과가 없습니다." 출력

4. 전체 결과 수: "총 N건 검색됨 (observations: A, fix-history: B, session: C)" 요약

## 예시

```
/squad:memory              # 최근 20개 관찰
/squad:memory auth         # "auth" 키워드 검색
/squad:memory TypeError    # 오류 메시지 검색
/squad:memory src/api.ts   # 특정 파일 관련 기록 검색
```
