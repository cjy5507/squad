# 동적 언어 규칙 레지스트리

Explore에서 감지된 언어/프레임워크에 따라 해당 규칙만 에이전트에 동적 주입.
기본 체크리스트에 **추가**되는 규칙입니다.

## 감지 매핑

```
.sql, .prc, .sp        → [SQL]
.cs, .csproj            → [DOTNET]
.java, .gradle          → [JAVA]
.py, .pyx               → [PYTHON]
.go                     → [GO]
Spring/SpringBoot       → [SPRING]
EF Core                 → [EFCORE]
```

## [SQL]

**BugHunter:** SQL Injection, 트랜잭션 에러 처리, 데드락, NULL 비교, 커서 정리, NOLOCK dirty read
**PerfTuner:** SELECT * 금지, 인덱스 활용, 함수 래핑 무효화, 배치 INSERT, EXISTS vs IN vs JOIN
**CleanCode:** SP 네이밍, 매직 값, 단일 책임 (500줄+ 경고)
**Architect:** 비즈니스 로직 중복, SP 체인 의존성

## [DOTNET]

**BugHunter:** async void 금지, IDisposable using, ConfigureAwait, HttpClient 재사용, CancellationToken
**PerfTuner:** LINQ ToList() 지연실행, StringBuilder, ValueTask, Span<T>
**Architect:** DI 등록 (Scoped/Transient/Singleton), 미들웨어 순서, Options 패턴

## [JAVA]

**BugHunter:** Optional 활용, equals/hashCode, Stream 재사용 금지, try-with-resources, synchronized
**PerfTuner:** StringBuilder, 박싱/언박싱, Collection 타입 선택, GC 압력
**Architect:** Controller→Service→Repository, 인터페이스 기반

## [SPRING]

**BugHunter:** @Transactional 레벨, readOnly, 자기 호출 프록시 우회, @Async 반환
**Architect:** 생성자 인젝션, 순환 의존성, @ComponentScan 범위

## [EFCORE]

**BugHunter:** 트래킹 vs AsNoTracking, SaveChanges 재시도, 마이그레이션 누락
**PerfTuner:** N+1 Include, AsSplitQuery, 프로젝션 Select, DbContext 수명

## [PYTHON]

**BugHunter:** 가변 기본 인수, bare except 금지, with 문, type hints
**PerfTuner:** 리스트 컴프리헨션, 제너레이터, 글로벌 변수 핫루프

## [GO]

**BugHunter:** error 무시 금지, goroutine 누수, defer 순서, 채널 닫기, sync.Mutex
**PerfTuner:** 슬라이스 용량 사전 할당, 핫경로 할당, sync.Pool
