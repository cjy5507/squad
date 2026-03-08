---
name: review
description: PR 리뷰 — git diff 기반 4-에이전트 병렬 리뷰 + confidence scoring.
argument-hint: "[--comment] [base-branch]"
---

# /squad:review — PR 리뷰

git diff 기반으로 4개 에이전트를 병렬 실행하여 PR을 리뷰합니다.

## 실행 절차

### 1. Diff 수집

```bash
git diff {base-branch}...HEAD  # base-branch 기본값: main
```

변경 파일 목록 + diff 내용 추출.

### 2. 4-에이전트 병렬 리뷰

모든 에이전트는 `run_in_background: true`, `mode: "plan"`.
출력 형식은 `references/json-contract.md` 준수.

**Agent 1: CLAUDE.md 준수 검사**
```
프로젝트 CLAUDE.md의 규칙과 변경 코드를 대조 검증.
위반 항목을 severity + confidence로 보고.
```

**Agent 2: 버그 탐지 (BugHunter)**
```
diff에서 잠재 버그, 엣지케이스, 보안 취약점 탐지.
변경으로 도입된 새로운 문제에 집중.
```

**Agent 3: 히스토리 컨텍스트**
```
git log로 관련 커밋 히스토리 확인.
이전에 수정→되돌림된 패턴, 반복적 변경 영역 탐지.
```

**Agent 4: 코드 품질 (CleanCode)**
```
변경 코드의 네이밍, 구조, DRY, 복잡도 분석.
기존 코드 스타일과의 일관성 확인.
```

### 3. 결과 통합

- **Confidence 필터링:** confidence < 80 제외
- **Severity 정렬:** critical → major → minor → info
- **중복 제거:** 같은 file:line에 여러 에이전트 발견 → 병합
- **결과 저장:** 통합 결과를 `.claude/squad-findings.json`에 저장 (후속 `/squad-fix`에서 재사용 가능)

### 4. 리포트

**컨텍스트에는 요약만 출력합니다** (findings 상세는 파일 참조):

```markdown
# PR Review — Squad

## 요약
- 변경 파일: N개 | 추가: +X줄 | 삭제: -Y줄
- 발견: critical A | major B | minor C
- 결과 저장: .claude/squad-findings.json

## Critical
{title + file:line 1줄씩}
## Major
{title + file:line 1줄씩}
## Minor
{건수만 표시}
## 개선 제안
```

### 5. --comment 옵션

`--comment` 플래그 시 `gh pr comment`로 GitHub PR에 리뷰 코멘트 게시.
