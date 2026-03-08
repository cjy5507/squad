---
name: learn
description: 학습 통계 — 분석/수정 이력, 에이전트 정확도, false positive, 핫스팟 파일을 시각화합니다.
argument-hint: ""
---

# /squad:learn — 학습 통계 대시보드

Squad의 자기 학습 데이터를 분석하여 통계와 개선 권장사항을 표시합니다.

## 실행 절차

### 1. 학습 디렉토리 확인

`.claude/squad-memory/` 디렉토리 존재 확인. 없으면 `/squad:init` 실행 안내 후 종료.

### 2. 통계 수집

다음 파일들을 읽어 통계를 산출합니다:

**fix-history.jsonl** → 수정 이력 분석:
- 총 수정 횟수 (전체 라인 수)
- 에이전트별 수정 횟수
- 파일별 수정 횟수 → 핫스팟 파일 Top 10
- severity별 분포

**agent-effectiveness.md** → 에이전트 정확도:
- 각 에이전트의 현재 점수 표시
- 점수 80 미만 에이전트에 경고

**false-positives.md** → 오탐 패턴:
- 에이전트별 등록된 false positive 수
- 가장 많은 오탐을 생성한 에이전트

**session-summary.md** → 세션 히스토리:
- 총 세션 수
- 마지막 세션 날짜

### 3. 수정 실패 감지

squad가 수정한 이슈 중 다시 보고된 것을 감지합니다:
- `fix-history.jsonl`의 수정 기록과 가장 최근 `squad-findings.json`의 findings를 대조
- 동일 file + 유사 패턴이 수정 후에도 다시 발견됨 = **수정 실패**
- 실패 횟수별 집계: 1회 실패, 2회 실패, 3회+ 실패 (자동 수정 포기)
- 실패율이 높은 에이전트를 경고 표시

### 4. 리포트 출력

```markdown
# Squad 학습 통계

## 개요
- 총 분석 세션: N회
- 총 수정 적용: M건
- 잠재적 리버트: K건

## 에이전트 정확도
| Agent | Score | Fixes | Reverts | Accuracy |
|-------|-------|-------|---------|----------|
| CleanCode | 95 | 42 | 2 | 95.2% |
| BugHunter | 88 | 31 | 5 | 83.9% |
| ...   | ...   | ...   | ...     | ...      |

## 핫스팟 파일 (Top 10)
| File | Fix Count | Last Fixed |
|------|-----------|------------|
| src/auth.ts | 8 | 2024-01-15 |
| ...  | ...       | ...        |

## False Positives
- 총 등록: N건
- 최다 오탐 에이전트: {agent} (K건)

## 권장사항
- {점수 낮은 에이전트}: confidence 임계값 상향 검토
- {핫스팟 파일}: 구조적 리팩토링 검토
- convention-overrides.md에 추가 권장 패턴: {패턴 목록}
```
