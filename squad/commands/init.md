---
name: init
description: 프로젝트 학습 초기화 — squad-memory 디렉토리를 생성하고 프로젝트 프로파일을 자동 수집합니다.
argument-hint: ""
---

# /squad:init — 프로젝트 학습 초기화

프로젝트별 학습 데이터를 축적할 디렉토리를 생성합니다.

## 실행 절차

### 1. 디렉토리 생성

```
.claude/squad-memory/
├── project-profile.md        # 프로젝트 특성
├── false-positives.md        # 반복 false positive 패턴
├── agent-effectiveness.md    # 에이전트별 정확도
└── convention-overrides.md   # 프로젝트 특화 룰 오버라이드
```

### 2. 프로젝트 스캔

Explore 에이전트로 프로젝트 구조를 스캔하여 `project-profile.md` 자동 생성:

```markdown
# 프로젝트 프로파일
- 언어: {감지된 언어 비율}
- 프레임워크: {감지된 프레임워크}
- 테스트: {테스트 프레임워크}
- 빌드: {빌드 도구}
- 최종 업데이트: {날짜}
```

### 3. 빈 파일 생성

나머지 파일은 빈 템플릿으로 생성. 사용자가 직접 편집하거나 `/squad:reject`로 자동 축적.

### 4. 완료 메시지

```
Squad 학습 디렉토리 초기화 완료.
- /squad:reject {finding} 으로 false positive 등록
- .claude/squad-memory/convention-overrides.md 직접 편집으로 프로젝트 룰 설정
```
