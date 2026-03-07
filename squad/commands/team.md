---
name: team
description: Team 모드 — Agent Teams로 독립 세션 병렬 실행, 대규모 구현/리팩토링용.
argument-hint: "<target-path> [--teammates N]"
---

# /squad:team — Team 모드

Agent Teams로 독립 Claude Code 세션을 병렬 실행합니다. 대규모 구현에 적합.

## 투입 조건 (2개 이상 만족)

- 대상 파일 20개+ | 독립 모듈 3개+ | 구현+테스트+문서 동시
- 사용자가 "team", "팀", "병렬 구현" 키워드 사용

## 실행 절차

### 1. 모듈 분석 + 태스크 분배

```
Explore로 모듈 구조 파악 → 독립 모듈별 teammate 할당.
파일 충돌 방지: 1) 모듈 분배 2) 파일 락 3) 계획 승인
```

### 2. Team 생성 + 태스크 할당

```
TeamCreate → TaskCreate × N → Task(team_name, name) × N
각 teammate에게 독립 모듈 할당 + AgentSpeak 프로토콜 주입
```

### 3. AgentSpeak 프로토콜

에이전트 간 토큰 효율 통신:
```
STATUS: TM1 → LEAD | phase:analysis files:3/5 findings:2M,1m
FINDING: TM1 → LEAD | S:major F:src/use.ts L:45 T:"missing cleanup"
DONE: TM1 → LEAD | files:5 findings:3C,5M score:7/10
```

### 4. 통합 검증

모든 teammate 완료 후:
```
빌드: tsc --noEmit / cargo check
테스트: npm test / cargo test
실패 시 → 해당 teammate 재활성화 → 수정 → 재검증
```

### 5. 종료

```
각 teammate에 shutdown 요청 (순차)
→ teammate 현재 작업 완료 후 승인
→ TeamDelete로 정리
→ 최종 통합 리포트
```

## 파일 락

```
.claude/coordination/
├── active_work_registry.json
├── completed_work_log.json
└── agent_locks/
```

Best-effort 방식. 모듈 분배로 충돌 사전 방지, 락은 보조 수단.
