---
name: squad
description: 병렬 전문가 에이전트 코드 분석. squad, 스쿼드, 코드 품질, code quality, parallel agents 키워드로 자동 트리거.
argument-hint: "[command] [target-path] [--options]"
---

# Squad v4 — 병렬 전문가 에이전트 오케스트레이터

코드베이스를 다각도로 분석하는 전문가 에이전트 스쿼드를 자율 편성하여 병렬 실행합니다.

## 사용 가능한 명령어

사용자의 요청에서 아래 키워드를 감지하면, 해당 명령 파일(`commands/*.md`)의 절차를 따르세요.

| 키워드 | 명령 | 설명 |
|--------|------|------|
| (없음), 분석, analyze | `/squad:analyze` | 분석 리포트 생성 |
| fix, 수정, 고쳐 | `/squad:fix` | 자동 수정 + 자기 교정 |
| build, 구현, 만들어 | `/squad:build` | 구현 루프 (완료까지) |
| review, 리뷰, PR | `/squad:review` | PR 리뷰 |
| team, 팀, 병렬 구현 | `/squad:team` | Team 모드 |
| init | `/squad:init` | 학습 초기화 |
| reject | `/squad:reject` | False positive 등록 |

## 핵심 원칙

1. **Confidence Scoring** — 모든 발견에 0-100 신뢰도. 80 미만 필터링
2. **Context Engineering** — 최소 토큰으로 최대 결과. 에이전트 프롬프트에 파일 경로만 전달
3. **JSON 계약** — `references/json-contract.md` 공유 형식
4. **Anti-Drift** — 목표 이탈 자동 감지/필터링
5. **Critical Consensus** — Critical 발견은 교차 검증

## 전문가 에이전트

Core: CleanCode, Architect, BugHunter
Contextual: TestExpert, PerfTuner, TypeGuard, ReactPro, RustSage, DocWriter
Special: CodeExplorer (탐색), CodeFixer (수정)
