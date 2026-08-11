# Design: Chặng A — Khung `backend-erp` và bộ CI enforce

- **Ngày:** 2026-08-10
- **Repo chính:** `backend-erp` (kèm một đợt sửa `docs-erp` làm tiền đề)
- **Trạng thái:** Chờ duyệt

---

## 1. Mục tiêu

Dựng bộ khung chạy được của `backend-erp`, và **quan trọng hơn**, dựng bộ checker biến 19 Architecture Rule từ văn bản thành thứ máy kiểm được trên mỗi PR.

Hiện toàn bộ 19 Rule chỉ được giữ bằng việc người và AI đọc `docs-erp`. Đó là enforcement tầng 1–2, và nó vẫn lọt. Chặng này mở tầng 3.

### Vì sao CI enforce nằm ở chặng đầu, không phải chặng cuối

Lộ trình ban đầu xếp CI vào cuối. Đổi lại vì bài học từ `check-ids.ps1`: nó được viết trước, giữ đỏ suốt sáu task với đúng lý do dự kiến, và nhờ vậy qua bốn vòng sửa lớn không lần nào để lọt một ID lạc.

Bộ checker cho Rule cũng vậy — phần lớn là import graph và AST, viết được ngay khi có cấu trúc thư mục, chưa cần code nghiệp vụ. Để nó ở cuối nghĩa là toàn bộ code chặng A–D không được máy kiểm, rồi phải sửa hồi tố.

### Trong phạm vi

- Sửa `docs-erp` làm tiền đề (mục 3) — phải xong trước khi viết code
- `cmd/api` composition root, `shared/` năm package, migration đầu tiên
- Endpoint `/health` và `/ready`
- Bộ checker `arch/` cho mọi Rule mà backend chạm tới, kèm fixture hai chiều
- Test harness trên PostgreSQL thật
- GitHub Actions với ba job

### Ngoài phạm vi

| Hạng mục | Thuộc chặng |
|---|---|
| `shared/auth`, `shared/authz`, `shared/middleware/auth`, module `auth`, bảng `users`/`roles`/`permissions` | B |
| `shared/audit`, `shared/outbox`, relay, bảng `audit_logs`/`outbox`/`idempotency_keys` | C |
| Module `user` — module mẫu đầy đủ | D |
| Mọi thứ thuộc `frontend-erp` (gồm R-19) | Chặng frontend |

`modules/` ở chặng A là thư mục rỗng. Checker cho R-02, R-05, R-15 vẫn được viết và vẫn phải chứng minh mình đúng bằng fixture — tới chặng B–D thì đã sẵn sàng canh.

---

## 2. Quyết định đã chốt

| # | Quyết định |
|---|---|
| 1 | Cắt việc thành bốn chặng A/B/C/D; đây là chặng A |
| 2 | Checker viết bằng **Go test dùng AST**, không phải script grep, không phải golangci-lint plugin |
| 3 | Engine chỉ dùng `go/parser` + `go/ast`, **không type-check** |
| 4 | Mỗi checker bắt buộc có fixture **vi phạm** (MUST FAIL) và fixture **hợp lệ** (MUST PASS) |
| 5 | Thêm nhóm bảng thứ năm `tenant_root`, chỉ chứa `companies` |
| 6 | Registry nhóm bảng sống ở `C-DB` dạng YAML, mỗi entry có trường `adr` |
| 7 | Postgres cho test: mặc định testcontainers, override bằng `TEST_DATABASE_URL` |
| 8 | Logging dùng `log/slog`; config đọc env thuần; migration bằng `golang-migrate` CLI |
| 9 | Go module tên `erp`; Postgres cho chạy tay nằm ở `backend-erp/compose.dev.yml` |
| 10 | CI trên GitHub Actions, ba job, job `arch` không cần Docker |

### Nguyên tắc nền của toàn bộ chặng này

> **Hard-check chỉ được tuyên bố FULL khi checker chứng minh được property bằng thông tin tĩnh mà nó thật sự quan sát được. Không đánh dấu FULL chỉ vì Convention đòi property đó.**

> **Không checker nào được coi là đã implement nếu chưa có fixture vi phạm chứng minh nó chuyển từ PASS sang FAIL đúng chỗ.**

Hai câu này tồn tại để chặn một tình huống cụ thể: checker hỏng và checker đúng trên repo chưa có code **cho ra kết quả giống hệt nhau** — cả hai đều xanh.

Và chiều ngược lại cũng bắt buộc: fixture hợp lệ chứng minh checker **không bắt nhầm** code đúng. Bằng chứng thực tế cho vế này là lỗi đã gặp ở R-10 — regex bật cờ `(?i)` khiến `[A-Z_-]` khớp cả chữ thường, nên `/checklists`, `/documents`, `/lists` đều bị báo oan. Fixture vi phạm không bao giờ phát hiện được lỗi đó.

---

## 3. Tiền đề — sửa `docs-erp` trước

Bảy thay đổi. Làm trước khi viết dòng code nào, vì migration đầu tiên không viết đúng được nếu chưa chốt.

### 3.1 Nhóm bảng thứ năm `tenant_root`

`companies` đang nằm trong `system_tables`, mà nhóm đó miễn **cả audit lẫn soft delete**. Áp lên `companies` nghĩa là tạo hay sửa một công ty không sinh bản ghi audit — sai về nghiệp vụ.

`tenant_root` có hành vi giống hệt `reference_tables` nhưng tên nói đúng nó là gì, tránh lẫn ngữ nghĩa khi đọc R-17.

| Nhóm | `company_id` | Cột thời gian | Cột audit | Sinh audit | Soft delete | Mọi module đọc |
|---|---|---|---|---|---|---|
| `system_tables` | Không | Không | Không | Không | Không | Có |
| `tenant_root` | Không | Có đủ | Có đủ | Có | Có | Có |
| `reference_tables` | Không | Có đủ | Có đủ | Có | Có | Có |
| `append_only_tables` | Có | Chỉ `created_at` | Chỉ `created_by` | Không | Không | Không |
| Bảng nghiệp vụ | Có | Có đủ | Có đủ | Có | Có | Không |

Cập nhật theo: R-02, R-06, R-08, R-17, R-18, blockquote dưới R-06, `C-DB-03`, `C-DB-04`, ADR-0003.

### 3.2 Registry chuyển từ ADR-0003 sang `C-DB`, mỗi entry trỏ ADR

Đây là đảo ngược một quyết định trước, và lý do phải ghi lại: ADR bất biến, nhưng danh sách bảng miễn trừ thì tiến hóa. Thêm `timezones` vào `reference_tables` mà phải sửa ADR-0003 đã `Accepted` là tự mâu thuẫn với chính quy tắc ADR.

Lo ngại cũ vẫn còn giá trị — nếu registry chỉ là Convention thì một PR sửa Convention vô hiệu hóa được bốn Rule. Trường `adr` giải quyết đúng chỗ đó.

```yaml
# 04-conventions/C-DB-database.md — canonical registry
system_actor_id: 00000000-0000-4000-8000-000000000001

tenant_root:
  - table: companies
    adr: ADR-0003

reference_tables:
  - table: currencies
    adr: ADR-0003
  - table: units
    adr: ADR-0003
  - table: provinces
    adr: ADR-0003

append_only_tables:
  - table: outbox
    adr: ADR-0006
  - table: audit_logs
    adr: ADR-0007
  - table: idempotency_keys
    adr: ADR-0003

system_tables:
  - table: schema_migrations
    adr: ADR-0003

naming_exempt:
  - table: outbox
    adr: ADR-0003
    reason: ket thuc bang x, khong khop regex cua R-08
```

**Nghĩa của trường `adr`, viết ngay trong `C-DB` cạnh registry:**

> `adr` là ADR giải thích **lý do kiến trúc khiến entry được xếp vào nhóm hiện tại**. Nó **không** có nghĩa "ADR gần nhất từng nhắc tới bảng này".
>
> **Invariant:** `adr` phải trỏ tới một ADR ở trạng thái `Accepted` và ADR đó phải **biện minh tường minh** cho phân loại hoặc miễn trừ này.

Ví dụ đúng: `outbox` trỏ ADR-0006 vì chính ADR đó quyết định nó là bảng chỉ ghi thêm. `idempotency_keys` trỏ ADR-0003 vì ADR-0003 là nơi xếp nó vào `append_only_tables` — không phải vì ADR-0003 có nhắc tới multi-tenancy.

`check-ids.ps1` kiểm được vế "ADR tồn tại và ở trạng thái Accepted". Vế "biện minh tường minh" thì không — đó là việc của reviewer, và `CL-PR` cần một dòng cho nó.

**Cảnh báo một lỗi đã suýt lọt hai lần:** `outbox` thuộc `append_only_tables`, **không** thuộc `system_tables`. Xếp nhầm thì `outbox` mất `company_id` (vì `system_tables` miễn cột đó), R-06 sẽ không đòi nó, và bug chỉ lộ ra khi có khách hàng thứ hai — relay không lọc được theo tenant.

Phân vai: **ADR giữ *why*, `C-DB` giữ *current policy*.** Thêm một bảng = viết ADR mới + thêm một dòng registry. Không ai sửa ADR cũ, và cũng không ai âm thầm mở rộng miễn trừ bằng một PR Convention.

ADR-0003 bỏ danh sách, giữ phần lý do và một câu trỏ sang `C-DB` là canonical registry.

`check-ids.ps1` bổ sung một kiểm: mọi giá trị `adr:` trong registry phải trỏ tới file ADR có thật.

### 3.3 `SYSTEM_ACTOR_ID`

Giá trị canonical: **`00000000-0000-4000-8000-000000000001`**

Đây là UUIDv4 hợp lệ về hình thức — version nibble `4`, variant bits `8`. Không dùng nil UUID (`00000000-0000-0000-0000-000000000000`) vì hai lý do: nó là zero value của `uuid.UUID` trong Go nên "system actor" không phân biệt được với "quên gán"; và nó không hợp lệ về version/variant nên thư viện validate chặt sẽ từ chối.

Giá trị này xuất hiện ở đúng bốn nơi và phải khớp nhau: registry `C-DB` (canonical), migration bootstrap, hằng `shared/auth` (chặng B), test fixture. Có checker kiểm khớp — không hard-code thêm ở bất kỳ đâu khác.

### 3.4 `C-GO-07` — SQL phải là một hằng chuỗi đơn

```
Câu SQL trong `*_repository.go` phải là một BasicLit đơn khai bằng `const`.
Cấm nối chuỗi (kể cả nối hai hằng), `fmt.Sprintf`, `strings.Builder`, hay bất kỳ
cách dựng SQL nào lúc chạy.
```

Cấm cả `const q = "SELECT ..." + " WHERE ..."` dù Go coi đó là constant expression — nếu cho phép thì checker phải evaluate expression, và thế là mở lại đúng cánh cửa vừa đóng. Điều kiện kiểm được là AST node phải là một `*ast.BasicLit`.

Quy tắc nhỏ này mở khóa bốn Rule: R-02, R-06, R-09, R-18 chuyển từ mù sang kiểm được. Nó cũng đóng luôn lỗ SQL injection, và R-12 đã đòi điều tương tự cho `sort` — đây là mở rộng ra toàn bộ.

Là Convention, không phải Rule mới — giữ đúng 19.

### 3.5 R-17 thêm ngoại lệ bootstrap

R-17 nói *mọi thao tác ghi sinh bản ghi audit*. Nhưng migration đầu tiên tạo `companies` ở thời điểm bảng `audit_logs` còn chưa tồn tại — mãi chặng C mới có. Không ghi ngoại lệ thì integration test chặng C sẽ đụng đúng mâu thuẫn này.

```
Ngoại lệ bổ sung: dữ liệu do migration ghi trực tiếp (bootstrap) được miễn sinh bản
ghi audit, vì hệ thống audit chưa tồn tại tại thời điểm đó. Mọi thao tác ghi từ tầng
ứng dụng sau đó đều chịu R-17 đầy đủ.
```

Sửa vào Ngoại lệ của R-17, **không** sửa ADR-0007 — Rule sống được, ADR thì bất biến.

### 3.6 `created_by` và `updated_by` không mang khóa ngoại

R-08 bắt mọi cột dạng `<singular>_id` là khóa ngoại. Hai cột này là ngoại lệ, và lý do không phải vì tiện: audit phải giữ được dấu vết kể cả khi user bị xóa, nên khóa ngoại cứng ở đây sai về nghiệp vụ.

Khai tường minh trong `C-DB-03`. Không khai thì checker R-09 sẽ đi tìm index cho một khóa ngoại không tồn tại.

### 3.7 R-16 giữ nguyên phát biểu conservative

Có một đề xuất đổi vế logger thành *"tham số phải là số chẵn, xen kẽ chuỗi literal và giá trị"* để kiểm được 100%. **Bác.** `logger.Info("user", "password", password)` thỏa mãn hình dạng đó và vẫn lộ mật khẩu — đó là kiểm *hình dạng* thay vì kiểm *thứ cần kiểm*.

Rule bảo mật giữ conservative: false negative nguy hiểm hơn false positive. R-16 tách ba mức:

- Phát hiện tên field và tên biến khớp danh sách nhạy cảm — kiểm được
- Struct field nhạy cảm có tag `json:"-"` — kiểm được
- Dữ liệu nhạy cảm đi qua alias, helper, hay custom logger — **không kiểm được**, ghi rõ là PARTIAL

---

## 4. Cấu trúc `backend-erp`

```
backend-erp/
├── go.mod                          # module erp
├── cmd/dev/                     # bo chay lenh, thay Makefile
├── compose.dev.yml                 # chỉ Postgres, cho chạy tay
├── cmd/api/main.go                 # composition root
├── shared/
│   ├── db/                         # DBTX, Open
│   ├── errors/                     # mã lỗi, kiểu Error
│   ├── log/                        # wrapper slog, FromContext
│   ├── requestid/                  # sinh, gắn ctx, middleware, header
│   └── response/                   # envelope, helper
├── modules/                        # rỗng ở chặng A
├── migrations/
│   ├── 000001_create_companies.up.sql
│   └── 000001_create_companies.down.sql
├── internal/testutil/              # helper Postgres cho test
├── arch/
│   ├── README.md                   # bảng mức enforce của 19 rule
│   ├── rules_test.go               # chạy trên code thật
│   ├── fixtures_test.go            # chạy trên testdata
│   ├── internal/                   # engine: loader, imports, ast, scanner
│   └── testdata/
│       ├── r01/ r02/ r03/ r04/ r05/ r06/ r07/ r08/ r09/
│       ├── r10/ r11/ r12/ r13/ r14/ r15/ r16/ r17/ r18/
│       └── mỗi thư mục: *_violation.go + *_valid.go
└── .github/workflows/ci.yml
```

### Ba quyết định trong cấu trúc

**`module erp` trong `go.mod`.** Toàn bộ `docs-erp` đã viết import path `erp/modules/order`, `erp/shared/db` — dùng tên khác thì 124 dòng ví dụ sai hết. Đổi lại repo không `go get` được từ ngoài; với monolith nội bộ thì không mất gì.

**Tên `testdata` là bắt buộc, không phải quy ước.** Go package discovery không coi thư mục tên `testdata` là package cần build hay test, nên file cố ý vi phạm — có import không tồn tại như `erp/modules/customer/internal/model` — không làm `go build ./...` đỏ. Trong khi đó `go/parser` vẫn đọc được chúng vì nó chỉ cần cú pháp đúng.

Đây **không** phải sandbox tuyệt đối cho mọi công cụ Go: `testdata` không được build, nhưng file trong đó vẫn đọc trực tiếp được. Chính vì thế engine bắt buộc dùng `go/parser`/`go/ast` chứ **không** dùng `go/packages` với type-check — checker nào cần type info sẽ chết trên chính fixture của nó.

**`arch/internal/` tách khỏi checker, nhưng giữ nhỏ.** Engine lo bốn việc: nạp file thành AST, dựng import graph, quét chuỗi theo hậu tố file, đọc YAML. Mỗi rule chỉ còn vài dòng khai báo. Mục tiêu là `Rule → gọi engine nhỏ → PASS/FAIL`, **không** phải xây một architecture compiler riêng.

### Phạm vi của checker — contract

```
Architecture rules apply to production application code under cmd/, shared/, and
modules/. Excluded: arch/ itself, *_test.go files, and arch/testdata/ — unless a
rule explicitly targets them.
```

Đây không phải "arch được miễn Rule", mà là Rule có scope xác định. `arch/` là tooling, không nằm trong dependency graph của ứng dụng:

```
shared → modules    ❌ (R-04)
modules → shared    ✅
arch → modules/shared  ✅ (tooling, ngoài graph)
```

Checker phải tự loại trừ `arch/`, nếu không nó báo chính nó vi phạm.

---

## 5. Bộ checker — Rule nào kiểm bằng gì, tới đâu

**Sáu cơ chế:** `IMPORT` (import graph) · `AST` (cây cú pháp) · `SQL` (parse migration) · `SCAN` (quét chuỗi) · `YAML` (registry, `module.yaml`) · `FS` (filesystem) · `GIT` (so base ref, chỉ trong CI)

| Rule | Cơ chế | Mức | Vế KHÔNG kiểm được |
|---|---|---|---|
| R-01 Module Boundary | IMPORT | **FULL** | — |
| R-02 No Cross-Module DB | AST + SQL + YAML | **FULL** ⁽¹⁾ | — (nhờ `C-GO-07`) |
| R-03 Layered Structure | IMPORT + AST | **FULL** | — |
| R-04 Dependency Direction | IMPORT + YAML | **FULL** | — |
| R-05 Events | AST + IMPORT + YAML | **PARTIAL** | *"ghi outbox trong cùng transaction"* — cần data-flow |
| R-06 Tenant Column | SQL + AST | **FULL** ⁽¹⁾ | — (nhờ `C-GO-07`) |
| R-07 Migration Only | FS + GIT + SCAN | **PARTIAL** | *"không sửa migration đã merge"* chỉ chạy được trong CI |
| R-08 Naming Convention | SQL + YAML | **FULL** | — |
| R-09 Index by Design | SQL + AST | **FULL** ⁽¹⁾ | — (nhờ `C-GO-07`) |
| R-10 RESTful Resource | AST | **PARTIAL** | Status code — cần biết handler nào là "tạo mới" |
| R-11 Envelope | AST | **FULL** | — |
| R-12 List Query Standard | AST | **PARTIAL** | *"trả mảng trần"* cần type info |
| R-13 API Versioning | AST + GIT | **PARTIAL** | Xóa field / đổi kiểu DTO — cần so hai phiên bản |
| R-14 Auth at Middleware | AST | **FULL** | — |
| R-15 Permission Check | AST | **PARTIAL** | Vế *"handler chứa so sánh role"* chỉ là heuristic |
| R-16 Never Expose Secrets | AST | **PARTIAL** | Dữ liệu nhạy cảm qua alias, helper, custom logger |
| R-17 Traceability | SQL + AST | **PARTIAL** | *"mọi thao tác ghi sinh audit"* — audit bọc qua helper hay wrapper là mù |
| R-18 Soft Delete | SQL + SCAN | **FULL** ⁽¹⁾ | — (nhờ `C-GO-07`) |
| R-19 Business Rules in UI | — | **N/A** | Thuộc `frontend-erp` |

⁽¹⁾ Bốn rule này FULL **chỉ khi** `C-GO-07` được enforce trước — checker `C-GO-07` phải chạy và xanh thì kết quả của chúng mới đáng tin.

### Dependency là dữ liệu, không phải prose

Ghi *"R-02 FULL có điều kiện C-GO-07"* thành câu văn thì sáu tháng nữa bảng và code sẽ lệch nhau. Dependency khai thành dữ liệu ngay trong checker:

```go
type Level int // FULL | PARTIAL | NA

type Rule struct {
    ID           string
    Level        Level
    DependsOn    []string // checker/convention phải xanh thì Level mới đáng tin
    Unverifiable string   // vế không kiểm được, rỗng nếu FULL
    Check        CheckFunc
}

var rules = []Rule{
    {ID: "R-02", Level: FULL, DependsOn: []string{"C-GO-07"}, Check: checkR02},
    {ID: "R-17", Level: PARTIAL, Unverifiable: "audit bọc qua helper hoặc transaction wrapper"},
}
```

Ba hệ quả bắt buộc:

1. **Invariant tự động hạ mức.** Nếu một prerequisite không được enforce, mức thực tế của mọi rule phụ thuộc nó **tự động** tụt xuống PARTIAL. Đây là code, không phải quy ước — engine đọc `DependsOn` và tính lại mức trước khi báo cáo.

2. **`arch/README.md` sinh bằng `go generate`** từ chính `rules`, không viết tay. Bảng viết tay lệch khỏi code ngay lần sửa checker thứ hai.

3. **Self-test chứng minh dependency, không chỉ khai báo nó.** `TestDependencyDowngrade` dựng fixture có SQL nối chuỗi (tức `C-GO-07` fail), chạy checker R-02 trên đó, rồi assert R-02 trả về **"không kết luận được"** chứ không phải PASS. Không có test này thì dòng `DependsOn` cũng chỉ là prose, chỉ khác chỗ nó nằm trong file `.go`.

### R-02 — luồng kiểm cụ thể

```
*_repository.go
   ↓ AST: trích const SQL (BasicLit đơn)
parse SQL
   ↓ lấy định danh sau FROM, JOIN, UPDATE, INSERT INTO, DELETE FROM
tập bảng được tham chiếu
   ↓ so với module.yaml.tables + registry (system/reference/tenant_root đọc được bởi mọi module)
PASS / FAIL
```

### R-17 vì sao là PARTIAL

Checker chỉ thấy pattern trong cùng thân hàm: service gọi `<repo>.Insert(ctx, tx, ...)` mà trong cùng method không có `auditRepo.Record(ctx, tx,`. Nếu audit được bọc qua helper, qua một service khác, qua transaction wrapper, qua trigger database, hay qua event — checker mù hoàn toàn.

Phần thật sự kiểm được:

| Kiểm được | Cơ chế |
|---|---|
| Cột `created_by`, `updated_by` trong migration | SQL |
| `ctx` là tham số đầu của service và repository | AST |
| Handler truyền `c.Request.Context()` | AST |
| Handler không gọi logger toàn cục | AST |
| Pattern audit trong cùng thân hàm | AST |
| **Mọi business write thực sự sinh audit** | **Review và integration test — không phải checker** |

---

## 6. `shared/` — năm package

Đồ thị phụ thuộc không có vòng. Điều này quan trọng vì R-04 chỉ cấm `shared/ → modules/`; vòng *bên trong* `shared/` không rule nào bắt, và nó là thứ làm `shared/` mục dần.

```
requestid        (không phụ thuộc gì)
    ↑     ↑
   log  response → errors
db               (không phụ thuộc gì)
```

| Package | Chịu trách nhiệm | Bề mặt công khai |
|---|---|---|
| `shared/requestid` | Sinh `request_id`, gắn `ctx`, set header `X-Request-Id` | `Middleware()`, `FromContext(ctx) string` |
| `shared/log` | Wrapper mỏng quanh `log/slog` | `FromContext(ctx) *slog.Logger`, `Init(cfg)` |
| `shared/errors` | Mã lỗi nghiệp vụ, kiểu `Error` mang mã | `Error`, hằng `Code*`, `NotFound/Conflict/Forbidden/Wrap` |
| `shared/response` | Envelope và mọi đường ra HTTP | `Success/Created/NoContent/List/ValidationFailed/Error/FieldErrors` |
| `shared/db` | `DBTX` và mở kết nối | `DBTX`, `Open(cfg) (*sqlx.DB, error)` |

`log` là wrapper mỏng, **không phải abstraction**: nó chỉ lấy logger đã gắn `request_id` ra khỏi `ctx`. Không tự định nghĩa level, không tự định nghĩa field. R-17 sở hữu `request_id`, `log` chỉ tiêu thụ — đúng ranh giới đã chốt với P-OBS.

Nội dung `shared/response` và `shared/errors` lấy từ `C-API-03` và `C-API-05`, gồm cả `FieldErrors` với hợp đồng đường dẫn theo tag `json` và phần tử mảng đánh chỉ số từ 0.

---

## 7. Migration đầu tiên

`000001_create_companies` — `companies` thuộc `tenant_root`: không có `company_id`, có đủ ba cột thời gian, hai cột audit, và soft delete.

```sql
CREATE TABLE companies (
    id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    code       TEXT        NOT NULL,
    name       TEXT        NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    created_by UUID        NOT NULL,
    updated_by UUID        NOT NULL
);

-- Partial unique index, khong dung UNIQUE thuong (R-18, C-DB-05): xoa mem mot cong ty
-- roi tao lai dung ma do phai duoc.
CREATE UNIQUE INDEX uq_companies_code ON companies(code) WHERE deleted_at IS NULL;
```

Không có khóa ngoại từ `created_by`/`updated_by` tới `users` — bảng đó mãi chặng B mới có, và ràng buộc cứng ở đây sai về nghiệp vụ (mục 3.6).

Seed công ty đầu tiên dùng `SYSTEM_ACTOR_ID`. Đây là bootstrap, được miễn sinh audit theo ngoại lệ mới của R-17 (mục 3.5).

---

## 8. Test harness

### Nguyên tắc nền

> **Test infrastructure owns infrastructure lifecycle. Test packages consume infrastructure; they do not create or destroy it.**

Câu này khóa **ai được sở hữu vòng đời**, chứ không khóa một con số như "một container mỗi test run". Nhờ vậy nó vẫn đúng khi sau này đổi testcontainers sang thứ khác, và nó chặn được cả những cách lách chưa nghĩ ra.

Hệ quả trực tiếp: không test package nào được dựng hay dọn hạ tầng. Chúng chỉ đọc DSN và tự lo cách ly ở mức database hoặc transaction.

### Hai đường, và vì sao phải tách vai

`TEST_DATABASE_URL` dễ bị gánh hai vai khác nhau — *override do người chọn* và *cơ chế harness truyền DSN xuống process con*. Nhập hai vai vào một biến sinh ra mâu thuẫn: CI không set biến để exercise đường mặc định, nhưng package cũng không được tự dựng, nên không ai dựng cả.

Tách rõ:

```
go run ./cmd/dev test           →  harness dựng đúng 1 container
                                   → harness export TEST_DATABASE_URL
                                   → go test ./...   (package chỉ ĐỌC biến)
                                   → harness dọn container

TEST_DATABASE_URL=... go test   →  dùng Postgres có sẵn, harness không chạy
```

CI gọi `go run ./cmd/dev test` và **không** tự set `TEST_DATABASE_URL`. Đường mặc định — harness tự dựng — là đường được chạy mỗi PR, nên nó không mục. Việc "mỗi package một container" không xảy ra được về mặt cấu trúc, không phải nhờ kỷ luật.

Vòng đời container nằm ở `internal/testharness`, gọi từ `cmd/dev`. Package test chỉ có `testutil.Connect(t)` đọc biến và trả `*sqlx.DB`; nếu biến rỗng thì fail ngay với thông báo *"chạy `go run ./cmd/dev test`, hoặc set `TEST_DATABASE_URL`"* — không im lặng tự xoay xở.

### Ba hard rule enforce nguyên tắc trên

| Hard rule | Cách enforce | Mức |
|---|---|---|
| Không package nào gọi `testcontainers.GenericContainer()` | Checker AST: cấm import `testcontainers` ngoài `internal/testharness` | FULL |
| Không package nào dựng hạ tầng bằng đường vòng | Checker AST: cấm `exec.Command` với đối số chứa `"docker"` trong `*_test.go` | FULL |
| CI không set `TEST_DATABASE_URL` | Checker đọc `.github/workflows/ci.yml`: job `test` không được có biến đó trong `env` | FULL |

Hai checker đầu chặn ngay lúc review, không đợi chạy — mạnh hơn và rẻ hơn một assertion runtime đếm số container. Chúng cũng nằm trong `arch/` nên chịu đúng quy tắc fixture hai chiều như mọi checker khác.

### Vì sao không dùng `Reuse: true`

`go test` chạy các package test **song song trong nhiều process riêng**. Nhiều process cùng gọi "tạo container nếu chưa có" sẽ cùng thấy nó chưa tồn tại và cùng tạo — xung đột tên. Tính năng `Reuse` của testcontainers-go vẫn được đánh dấu experimental, và lớp race này là một lý do.

### Template database

Chạy migration một lần lên `erp_template`, rồi mỗi package test `CREATE DATABASE ... TEMPLATE erp_template`. Chép một database rỗng nhanh hơn chạy lại chuỗi migration nhiều lần, và chi phí đó tăng tuyến tính theo số migration — tới chặng D sẽ là hàng chục file.

**Trong một package**, mỗi test bọc transaction rồi rollback, **không** tạo database mới. Điều này khả thi chính nhờ `DBTX` truyền qua tham số: test truyền thẳng `tx` vào repository.

Chỉ test service — vốn tự mở transaction ở bên trong — mới cần database riêng.

### `arch/` không cần Postgres

Fixture chỉ là file Go được `go/parser` đọc. Bộ checker phải chạy được cả khi máy không có Docker — nếu nó phụ thuộc Docker thì ngày Docker hỏng là ngày rule ngừng được canh.

---

## 9. CI

| Job | Chạy gì | Cần Docker | Vì sao tách |
|---|---|---|---|
| `lint` | `gofmt -l`, `go vet ./...` | Không | Rẻ nhất, fail sớm nhất |
| `arch` | `go test ./arch/...` | **Không** | Rule phải được canh kể cả khi Docker hỏng |
| `test` | `go test ./...` | Có | Testcontainers |

Job `arch` cần `fetch-depth: 0` vì vế *"không sửa migration đã merge"* của R-07 phải so với base ref của PR. Đó là vế duy nhất **chỉ chạy được trong CI**, không chạy được lúc phát triển offline — ghi rõ trong `arch/README.md`, nếu không người ta tưởng `go run ./cmd/dev check` local đã phủ hết.

**Mức enforce của từng rule ghi ở `backend-erp/arch/README.md`, không ghi vào `RULES.md`.** Rule là chuẩn mực; mức enforce là trạng thái công cụ tại một thời điểm. Trộn hai thứ thì `RULES.md` phải sửa mỗi lần checker khá lên. `CL-PR-code-review.md` thêm một dòng trỏ sang bảng đó, để reviewer biết chỗ nào máy không canh và phải soi tay.

---

## 10. Định nghĩa hoàn thành

### Phần `docs-erp` — làm trước

- [ ] Nhóm `tenant_root` thêm vào; bảng nhóm thành 5 dòng; R-02, R-06, R-08, R-17, R-18 cập nhật
- [ ] Registry YAML trong `C-DB`, mỗi entry có `adr`; ADR-0003 bỏ danh sách, giữ *why* và trỏ sang
- [ ] `system_actor_id: 00000000-0000-4000-8000-000000000001` trong registry
- [ ] `C-GO-07` SQL phải là `BasicLit` đơn
- [ ] R-17 thêm ngoại lệ bootstrap migration
- [ ] `created_by`/`updated_by` khai tường minh là không mang khóa ngoại trong `C-DB-03`
- [ ] R-16 giữ nguyên phát biểu conservative
- [ ] `check-ids.ps1` xanh, và có thêm kiểm `adr:` trong registry trỏ tới ADR có thật

### Phần `backend-erp`

- [ ] `go build ./...`, `go vet ./...`, `gofmt -l` sạch
- [ ] `go run ./cmd/api` lên được; `/health` trả 200; `/ready` trả 200 khi DB sống và **503 khi DB chết**, kiểm bằng test chứ không bằng mắt
- [ ] `migrate up` chạy được từ database trống; `migrate down` quay về được
- [ ] `go test ./...` xanh, gồm `arch/` và ít nhất một repository test chạy trên Postgres thật
- [ ] `go test ./arch/...` chạy xanh **khi Docker đã tắt**
- [ ] **Mỗi checker đã implement có ≥1 fixture MUST-FAIL và ≥1 fixture MUST-PASS.** Không có fixture thì checker coi như chưa implement. Áp cho 18 rule backend; R-19 là N/A nên không có checker và không cần fixture
- [ ] Không rule nào đánh dấu FULL chỉ vì chạy xanh trên tập rỗng
- [ ] `arch/README.md` **sinh bằng `go generate`** từ `rules`, không viết tay; có cột `Enforce` và cột `Dependency`
- [ ] `TestDependencyDowngrade` chứng minh R-02 tụt xuống "không kết luận được" khi `C-GO-07` fail
- [ ] Ba checker của test infrastructure xanh: cấm `testcontainers` ngoài `internal/testharness`, cấm `exec.Command` với `"docker"` trong `*_test.go`, và job `test` trong CI không có `TEST_DATABASE_URL` trong `env`
- [ ] Không package test nào dựng hay dọn hạ tầng — kiểm bằng chính ba checker trên
- [ ] CI ba job chạy trên PR; job `arch` không cần Docker
- [ ] `go run ./cmd/dev clean-test-db` dọn tài nguyên test

---

## 11. Rủi ro

| Rủi ro | Giảm thiểu |
|---|---|
| Checker xanh giả vì chạy trên tập rỗng | Fixture hai chiều bắt buộc; không fixture thì coi như chưa implement |
| Checker bắt oan code hợp lệ | Fixture MUST-PASS bắt buộc — chính là lỗi đã gặp ở R-10 |
| Bốn rule FULL phụ thuộc `C-GO-07` bị tắt lặng lẽ | `DependsOn` là dữ liệu; engine tự hạ mức; `TestDependencyDowngrade` chứng minh cơ chế hạ mức hoạt động |
| Đường testcontainers mục vì dev toàn dùng `TEST_DATABASE_URL` | CI gọi `go run ./cmd/dev test` và không set biến, nên đường mặc định chạy mỗi PR |
| Một package test tự dựng container, quay lại "mỗi package một container" | Nguyên tắc *test infrastructure owns lifecycle* + hai checker AST chặn tĩnh |
| `arch/README.md` lệch khỏi code | Sinh bằng `go generate`, không viết tay |
| `SYSTEM_ACTOR_ID` lệch giữa bốn nơi | Checker kiểm khớp với registry |
| Registry ở Convention bị mở rộng lặng lẽ | Trường `adr` bắt buộc; `check-ids.ps1` kiểm ADR tồn tại |
| Engine `arch/` phình thành framework | Giới hạn bốn việc: nạp AST, import graph, quét chuỗi, đọc YAML |

## 12. Nợ để lại

| Nợ | Chặng |
|---|---|
| R-05 vế *"outbox trong cùng transaction"* — cần data-flow analysis | Cân nhắc lại ở chặng C khi có outbox thật |
| R-13 vế so sánh DTO giữa hai phiên bản | Khi có `/api/v2` đầu tiên |
| R-12, R-16 các vế cần type info | Cân nhắc một chế độ type-check chạy riêng trên code thật |
| R-19 và toàn bộ checker frontend | Chặng frontend |
| `document_counters` chưa phân nhóm | Khi module đầu tiên cần cấp số chứng từ |
