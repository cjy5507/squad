---
name: squad
description: 병렬 전문가 에이전트 코드 분석. squad, 스쿼드, 코드 품질, code quality, parallel agents 키워드로 자동 트리거.
argument-hint: "[command] [target-path] [--options]"
---

# Squad v5 — 올인원 코드 품질 플러그인

코드베이스를 다각도로 분석하는 전문가 에이전트 스쿼드를 자율 편성하여 병렬 실행합니다.
세션 메모리, 계획 수립, Worktree 격리, 복합 학습을 내장한 올인원 플러그인입니다.

## 사용 가능한 명령어

사용자의 요청에서 아래 키워드를 감지하면, 해당 명령 파일(`commands/*.md`)의 절차를 따르세요.

| 키워드 | 명령 | 설명 |
|--------|------|------|
| (없음), 분석, analyze | `/squad:analyze` | 분석 리포트 생성 |
| fix, 수정, 고쳐 | `/squad:fix` | 자동 수정 + 자기 교정 |
| build, 구현, 만들어 | `/squad:build` | 구현 루프 (완료까지) |
| review, 리뷰, PR | `/squad:review` | PR 리뷰 |
| team, 팀, 병렬 구현 | `/squad:team` | Team 모드 |
| plan, 계획, 설계 | `/squad:plan` | 상세 구현 계획 수립 |
| memory, 메모리, 기억, 검색 | `/squad:memory` | 이전 세션 메모리 검색 |
| compound, 학습 정리, 패턴 정리 | `/squad:compound` | 세션 학습 자동 정리 |
| init | `/squad:init` | 학습 초기화 |
| reject | `/squad:reject` | False positive 등록 |
| learn, 학습, 통계, stats | `/squad:learn` | 학습 통계 대시보드 |
| cancel, 취소, 중단, 멈춰 | `/squad:cancel` | 진행 중인 작업 취소 |

## 핵심 원칙

1. **Confidence Scoring** — 모든 발견에 0-100 신뢰도. 80 미만 필터링
2. **Context Engineering** — 최소 토큰으로 최대 결과. 에이전트 프롬프트에 파일 경로만 전달
3. **JSON 계약** — `references/json-contract.md` 공유 형식
4. **Anti-Drift** — 목표 이탈 자동 감지/필터링
5. **Critical Consensus** — Critical 발견은 교차 검증
6. **Session Memory** — 모든 tool 사용을 observations.jsonl에 기록, 세션 시작 시 컨텍스트 주입
7. **Worktree Isolation** — --worktree 옵션으로 격리된 환경에서 안전하게 실행

## 전문가 에이전트

Core: CleanCode, Architect, BugHunter
Contextual: TestExpert, PerfTuner, TypeGuard, ReactPro, RustSage, DocWriter
Special: CodeExplorer (탐색), CodeFixer (수정), PlanArchitect (계획)
Project: ClaudeMdChecker (CLAUDE.md 존재 시)
