---
name: reject
description: False positive 등록 — 오탐 발견을 학습 데이터에 기록하여 향후 분석 정밀도를 향상시킵니다.
argument-hint: "<finding-description>"
---

# /squad:reject — False Positive 등록

에이전트의 발견이 오탐(false positive)일 때 학습 데이터에 등록합니다.
등록된 패턴은 향후 분석 시 에이전트 프롬프트에 "무시할 패턴"으로 주입됩니다.

## 실행 절차

### 1. 학습 디렉토리 확인

`.claude/squad-memory/false-positives.md`가 없으면 먼저 `/squad:init` 실행을 안내합니다.

### 2. 오탐 기록

사용자가 제공한 발견 설명을 파싱하여 `false-positives.md`에 추가:

```markdown
## {에이전트명}
- `{패턴/규칙}`: {왜 이 프로젝트에서 허용되는지} ({날짜} 등록)
```

### 3. 에이전트 프롬프트 주입

다음 분석 시 해당 에이전트 프롬프트 상단에 자동 주입:
```
## 무시할 패턴 (False Positive)
{false-positives.md에서 해당 에이전트 섹션}
```

### 4. 확인 메시지

```
False positive 등록 완료:
- 에이전트: {에이전트명}
- 패턴: {패턴}
- 향후 이 패턴은 분석에서 제외됩니다.
```
