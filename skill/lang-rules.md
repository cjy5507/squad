# 동적 언어 규칙 레지스트리

Step 0(Explore)에서 감지된 언어/프레임워크에 따라, 해당 규칙만 에이전트 프롬프트에 동적 주입합니다.
기본 체크리스트(checklists.md)에 **추가**되는 규칙입니다.

## 감지 → 주입 매핑

```
파일 확장자/패턴 → 언어 태그 → 해당 에이전트에 규칙 주입

.sql, .prc, .sp, .fnc          → [SQL]
.cs, .csproj, .sln             → [DOTNET]
.java, .gradle, .pom           → [JAVA]
.py, .pyx                      → [PYTHON]
.go                            → [GO]
.ts, .tsx                      → [TS] (기존 TypeGuard 체크리스트로 충분)
.rs                            → [RUST] (기존 RustSage 체크리스트로 충분)
.jsx, .tsx + React import      → [REACT] (기존 ReactPro 체크리스트로 충분)

프레임워크 감지 (import/using 문 기반):
Spring/SpringBoot              → [SPRING]
Entity Framework / EF Core     → [EFCORE]
Django/Flask/FastAPI            → [PYTHON_WEB]
ASP.NET                        → [ASPNET]
```

---

## [SQL] 규칙

### BugHunter 추가
- [ ] SQL Injection 위험: 동적 SQL에 사용자 입력이 직접 결합되는가?
- [ ] 트랜잭션 내 에러 처리: TRY-CATCH + ROLLBACK이 있는가?
- [ ] 데드락 위험: 테이블 접근 순서가 일관적인가?
- [ ] NULL 비교에 IS NULL을 사용하는가? (= NULL 금지)
- [ ] 커서 사용 후 CLOSE + DEALLOCATE 하는가?
- [ ] NOLOCK 힌트의 dirty read 위험을 인지하는가?

### PerfTuner 추가
- [ ] SELECT *를 사용하지 않는가? (필요 컬럼만 명시)
- [ ] WHERE 절에 인덱스 컬럼을 사용하는가?
- [ ] 함수 래핑(ISNULL, CONVERT 등)으로 인덱스 무효화되지 않는가?
- [ ] 대량 데이터 INSERT 시 배치 처리하는가?
- [ ] 임시 테이블 vs 테이블 변수 선택이 적절한가?
- [ ] EXISTS vs IN vs JOIN 중 적절한 것을 사용하는가?
- [ ] SP에 SET NOCOUNT ON이 있는가?

### CleanCode 추가
- [ ] SP/함수명이 동작을 명확히 설명하는가?
- [ ] 매개변수명에 접두사(@p_ 등) 컨벤션이 있는가?
- [ ] 하드코딩된 매직 값이 없는가?
- [ ] SP가 단일 책임을 따르는가? (500줄+ SP 경고)

### Architect 추가
- [ ] 비즈니스 로직이 SP와 앱 레이어에 중복되지 않는가?
- [ ] SP 간 의존성이 명확한가? (SP가 다른 SP를 호출하는 체인)
- [ ] 스키마 변경의 영향 범위가 관리되는가?

---

## [DOTNET] 규칙

### BugHunter 추가
- [ ] async void를 사용하지 않는가? (이벤트 핸들러 제외)
- [ ] IDisposable 구현 객체에 using/await using을 사용하는가?
- [ ] ConfigureAwait(false)가 라이브러리 코드에 적용되었는가?
- [ ] HttpClient를 매번 new하지 않는가? (IHttpClientFactory 사용)
- [ ] 예외를 catch 후 throw (스택 보존) vs throw ex (스택 손실) 구분하는가?
- [ ] CancellationToken이 전파되는가?

### PerfTuner 추가
- [ ] LINQ에서 불필요한 ToList()/ToArray()가 없는가? (지연 실행 활용)
- [ ] StringBuilder를 루프 내 문자열 결합에 사용하는가?
- [ ] ValueTask vs Task 선택이 적절한가?
- [ ] Span<T>/Memory<T>로 할당을 줄일 수 있는가?

### Architect 추가
- [ ] DI 컨테이너 등록이 적절한가? (Scoped/Transient/Singleton)
- [ ] 미들웨어 파이프라인 순서가 올바른가?
- [ ] Options 패턴으로 설정이 분리되었는가?

---

## [JAVA] 규칙

### BugHunter 추가
- [ ] NullPointerException 위험: Optional을 활용하는가?
- [ ] equals/hashCode가 함께 오버라이드되었는가?
- [ ] Stream을 재사용하지 않는가? (한 번만 소비 가능)
- [ ] try-with-resources로 AutoCloseable을 처리하는가?
- [ ] 동기화: synchronized 블록의 범위가 최소한인가?
- [ ] 불변 컬렉션(Collections.unmodifiable*)을 반환하는가?

### PerfTuner 추가
- [ ] String concatenation에 StringBuilder를 사용하는가?
- [ ] 박싱/언박싱이 불필요하게 발생하지 않는가?
- [ ] 적절한 Collection 타입을 선택했는가? (ArrayList vs LinkedList, HashMap vs TreeMap)
- [ ] GC 압력: 불필요한 객체 생성이 루프 내에 없는가?

### Architect 추가
- [ ] 계층 구조가 Controller → Service → Repository를 따르는가?
- [ ] 인터페이스 기반 프로그래밍을 사용하는가?

---

## [SPRING] 규칙 (Java + Spring 감지 시 추가)

### BugHunter 추가
- [ ] @Transactional이 적절한 레벨에 적용되었는가?
- [ ] @Transactional(readOnly=true)가 조회에 사용되는가?
- [ ] 자기 호출(self-invocation) 시 프록시 우회 문제가 없는가?
- [ ] @Async 메서드가 void 또는 Future를 반환하는가?

### Architect 추가
- [ ] 필드 인젝션(@Autowired) 대신 생성자 인젝션을 사용하는가?
- [ ] 순환 의존성이 없는가?
- [ ] @ComponentScan 범위가 과도하지 않은가?

---

## [EFCORE] 규칙 (.NET + EF Core 감지 시 추가)

### BugHunter 추가
- [ ] 트래킹 vs 비트래킹 쿼리가 적절한가? (AsNoTracking)
- [ ] SaveChanges 실패 시 재시도/롤백이 있는가?
- [ ] 마이그레이션이 누락되지 않았는가?

### PerfTuner 추가
- [ ] N+1 쿼리: Include/ThenInclude로 Eager Loading 하는가?
- [ ] 대량 쿼리에 AsSplitQuery()를 고려했는가?
- [ ] 프로젝션(Select)으로 필요한 컬럼만 가져오는가?
- [ ] DbContext 수명이 적절한가? (Scoped 권장)

---

## [PYTHON] 규칙

### BugHunter 추가
- [ ] 가변 기본 인수(def f(x=[]))를 사용하지 않는가?
- [ ] except: (bare except) 대신 구체적 예외를 잡는가?
- [ ] 파일/리소스에 with 문을 사용하는가?
- [ ] type hints가 적용되었는가?

### PerfTuner 추가
- [ ] 리스트 컴프리헨션/제너레이터를 적절히 사용하는가?
- [ ] 대용량 데이터에 제너레이터(yield)를 사용하는가?
- [ ] 글로벌 변수 접근이 핫루프에 없는가?

---

## [GO] 규칙

### BugHunter 추가
- [ ] error를 무시하지 않는가? (_, err := 후 err 체크)
- [ ] goroutine 누수가 없는가? (context 기반 취소)
- [ ] defer의 실행 순서를 이해하고 사용하는가?
- [ ] 채널이 적절히 닫히는가?
- [ ] 동시 접근 시 sync.Mutex 또는 채널을 사용하는가?

### PerfTuner 추가
- [ ] 슬라이스 용량을 사전 할당하는가? (make([]T, 0, cap))
- [ ] 불필요한 메모리 할당이 핫경로에 없는가?
- [ ] sync.Pool을 적절히 활용하는가?
