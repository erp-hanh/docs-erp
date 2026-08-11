# Chặng A — Khung `backend-erp` và bộ CI enforce: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dựng khung chạy được của `backend-erp` và biến 19 Architecture Rule từ văn bản thành thứ máy kiểm được trên mỗi PR.

**Architecture:** Bộ checker `arch/` viết bằng Go test dùng `go/parser` + `go/ast`, không type-check — điều kiện để fixture cố ý vi phạm (có import không tồn tại) tồn tại được. Mỗi checker bắt buộc có fixture hai chiều: MUST-FAIL chứng minh nó bắt được vi phạm, MUST-PASS chứng minh nó không bắt oan code hợp lệ. Hạ tầng test do `internal/testharness` sở hữu vòng đời; package test chỉ tiêu thụ.

**Tech Stack:** Go 1.26, Gin, pgx/sqlx, golang-migrate, testcontainers-go, PostgreSQL 16, GitHub Actions.

**Nguồn:** `docs-erp/99-meta/specs/2026-08-10-chang-a-khung-va-ci-enforce-design.md` — đọc trước khi bắt đầu. Plan này trỏ tới spec thay vì chép lại, để tránh hai bản lệch nhau.

---

## Hai nguyên tắc chi phối toàn bộ plan

> **Hard-check chỉ được tuyên bố FULL khi checker chứng minh được property bằng thông tin tĩnh mà nó thật sự quan sát được.**

> **Không checker nào được coi là đã implement nếu chưa có fixture vi phạm chứng minh nó chuyển từ PASS sang FAIL đúng chỗ, và fixture hợp lệ chứng minh nó không bắt nhầm.**

Task nào vi phạm hai câu này thì chưa xong, kể cả khi `go test` xanh.

### Ba việc lặp lại ở mọi task viết checker

Từ Task 13 trở đi mỗi checker đều phải làm đủ ba việc sau. Chúng không được nhắc lại trong từng task để plan khỏi dài, nhưng thiếu bất kỳ việc nào thì task chưa xong:

1. **Thêm một entry vào biến `rules`** trong `arch/rules.go`, điền đủ `ID`, `Level`, `FixtureDir`, `Check`, cộng `DependsOn` và `Unverifiable` nếu có. Không thêm thì `TestFixtures` và `TestProductionCode` không chạy checker đó — nó tồn tại mà không ai gọi.
2. **Tạo thư mục `arch/testdata/<fixturedir>/`** với ít nhất một file `violation_*.go` và một file `valid_*.go`. `TestFixtures` fail nếu thiếu một trong hai.
3. **Chạy `go generate ./arch/...`** để `arch/README.md` cập nhật theo.

### Ghi chú về độ chi tiết của plan này

Các task nền — engine `loader`, `imports`, `fixtures_test.go`, `EffectiveLevels`, `requestid`, `DBTX`, `testutil.Connect` — có code đầy đủ, vì chúng định hình mọi thứ sau đó và sai ở đây thì hỏng dây chuyền.

Mười lăm checker ở Phase 5 được đặc tả bằng **bảng: bắt gì · mức · fixture MUST-FAIL · fixture MUST-PASS**, không chép code đầy đủ. Lý do: cả mười lăm dùng chung khuôn của `checkR01` đã viết đầy đủ ở Task 5, nên chép lại là duplicate, và bản chép sẽ lệch khi khuôn đổi. Bảng đặc tả nêu đủ để implement mà không phải đoán — thứ duy nhất phải tự viết là biểu thức AST cho từng pattern.

---

## File Structure

### `docs-erp` — sửa ở Phase 0

| File | Sửa gì |
|---|---|
| `01-rules/RULES.md` | Thêm `tenant_root` vào bảng 5 nhóm; cập nhật R-02, R-06, R-08, R-17, R-18 |
| `03-decisions/ADR-0003-multi-tenant-ready.md` | Bỏ danh sách, giữ *why*, trỏ sang `C-DB` |
| `04-conventions/C-DB-database.md` | Registry YAML canonical; `C-DB-03` thêm `tenant_root` và ghi `created_by`/`updated_by` không FK |
| `04-conventions/C-GO-backend.md` | Thêm `C-GO-07` — SQL là `BasicLit` đơn |
| `tools/check-ids.ps1` | Kiểm mọi `adr:` trong registry trỏ ADR có thật và ở trạng thái Accepted |

### `backend-erp` — dựng ở Phase 1–6

| Đường dẫn | Trách nhiệm |
|---|---|
| `go.mod` | `module erp`, `go 1.26` |
| `cmd/dev/` | Bộ chạy lệnh: `dev`, `test`, `arch`, `arch-update`, `lint`, `check`, `migrate-up`, `migrate-down`, `clean-test-db` — thay `Makefile`, xem Task 11e |
| `internal/reporoot/`, `internal/migrator/` | Tìm gốc repo; chạy migration — dùng chung giữa `cmd/dev` và `internal/testharness` |
| `arch/internal/loader/` | Nạp file `.go` thành AST, lọc theo scope |
| `arch/internal/imports/` | Dựng import graph, truy vấn "package X có import Y không" |
| `arch/internal/scan/` | Trích const string, quét call expression, đọc struct tag |
| `arch/internal/registry/` | Đọc registry YAML từ `C-DB` |
| `arch/rules.go` | Khai `[]Rule` — ID, Level, DependsOn, Unverifiable, Check |
| `arch/rules_test.go` | Chạy toàn bộ checker trên code thật |
| `arch/fixtures_test.go` | Chạy từng checker trên `testdata/`, kiểm hai chiều |
| `arch/gen_readme.go` | `go:generate` sinh `README.md` từ `rules` |
| `arch/testdata/r01/`..`r18/`, `cgo07/`, `testinfra/` | Fixture, mỗi thư mục có `*_violation.go` và `*_valid.go` |
| `shared/requestid/` | Sinh `request_id`, middleware, `FromContext` |
| `shared/log/` | Wrapper `log/slog`, `FromContext` |
| `shared/errors/` | Mã lỗi, kiểu `Error` |
| `shared/response/` | Envelope và helper |
| `shared/db/` | `DBTX`, `Open` |
| `internal/testharness/` | **Sở hữu vòng đời** container Postgres |
| `internal/testutil/` | `Connect(t)` — chỉ đọc `TEST_DATABASE_URL` |
| `migrations/000001_create_companies.{up,down}.sql` | Bảng `companies` |
| `cmd/api/main.go` | Composition root |
| `.github/workflows/ci.yml` | Ba job: `lint`, `arch`, `test` |

---

# PHASE 0 — Sửa `docs-erp` làm tiền đề

Làm trước khi viết dòng Go nào. Migration đầu tiên không viết đúng được nếu chưa chốt nhóm bảng.

## Task 1: Thêm nhóm `tenant_root`

**Files:**
- Modify: `docs-erp/01-rules/RULES.md`

- [ ] **Step 1: Sửa blockquote bốn nhóm dưới R-06 thành năm nhóm**

Thêm một dòng vào bảng, ngay sau `system_tables`:

```
> | `tenant_root` | Không | Có đủ | Có đủ | Có | Có | Có |
```

Và thêm mục mô tả, ngay sau mục `system_tables`:

```
> - **`tenant_root`** — bảng gốc của cơ chế multi-tenant. Chỉ chứa `companies`.
>   Không có `company_id` vì nó **là** tenant, không thuộc tenant nào. Ngoài điểm đó,
>   nó chịu mọi thứ như bảng nghiệp vụ: đủ ba cột thời gian, đủ cột audit, vẫn sinh
>   bản ghi audit, vẫn soft delete. Nó không nằm trong `system_tables` vì nhóm đó
>   miễn cả audit lẫn soft delete — tạo hay sửa một công ty mà không để lại dấu vết
>   là sai về nghiệp vụ.
```

- [ ] **Step 2: Cập nhật R-02 Ngoại lệ**

Thêm `tenant_root` vào danh sách nhóm được mọi module đọc, cạnh `system_tables` và `reference_tables`.

- [ ] **Step 3: Cập nhật R-06 mệnh đề và Ngoại lệ**

Mệnh đề: `system_tables`, `reference_tables` và `tenant_root` đều được miễn `company_id`.
Ngoại lệ: liệt kê đủ ba nhóm.

- [ ] **Step 4: Cập nhật R-08, R-17, R-18**

Cả ba đang viết *"bảng nghiệp vụ và bảng trong `reference_tables`"*. Thêm `tenant_root` vào cùng vị trí ở **mệnh đề bắt buộc**, **dấu hiệu vi phạm**, và **Ngoại lệ** của từng rule.

Đây là chỗ dễ sót nhất: `tenant_root` không phải bảng nghiệp vụ theo định nghĩa, nên nếu chỉ thêm vào Ngoại lệ mà không sửa mệnh đề thì ba rule sẽ **không đòi gì** ở `companies`.

- [ ] **Step 5: Chạy script và commit**

```powershell
powershell -ExecutionPolicy Bypass -File "d:\My project web\erp\docs-erp\tools\check-ids.ps1"
```
Expected: `check-ids: OK - 130 ID`

```powershell
cd "d:\My project web\erp\docs-erp"
git add 01-rules/RULES.md
git commit -m @'
feat: them nhom bang tenant_root cho companies

companies dang nam trong system_tables, ma nhom do mien ca audit lan soft delete.
Tao hay sua mot cong ty ma khong de lai dau vet la sai ve nghiep vu. tenant_root
co hanh vi giong reference_tables nhung ten noi dung no la gi.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
'@
```

---

## Task 2: Registry YAML trong `C-DB`

**Files:**
- Modify: `docs-erp/04-conventions/C-DB-database.md` (mục `C-DB-04`)
- Modify: `docs-erp/03-decisions/ADR-0003-multi-tenant-ready.md`

- [ ] **Step 1: Thay nội dung `C-DB-04` bằng registry canonical**

```markdown
### C-DB-04 — Registry nhóm bảng

**Implements:** R-06

Đây là **canonical registry** — nguồn sự thật cho việc bảng nào thuộc nhóm nào. Cả
người lẫn checker `arch/` đọc từ đây.

**Nghĩa của trường `adr`:** ADR giải thích **lý do kiến trúc khiến entry được xếp vào
nhóm hiện tại**. Nó **không** có nghĩa "ADR gần nhất từng nhắc tới bảng này".

**Invariant:** `adr` phải trỏ tới một ADR ở trạng thái `Accepted`, và ADR đó phải biện
minh tường minh cho phân loại hoặc miễn trừ này. Thêm một bảng vào bất kỳ nhóm nào
đòi một ADR mới — không sửa ADR cũ, và cũng không thêm lặng lẽ bằng một PR Convention.

```yaml
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

> **`outbox` thuộc `append_only_tables`, KHÔNG thuộc `system_tables`.** Xếp nhầm thì
> `outbox` mất `company_id` (vì `system_tables` miễn cột đó), R-06 không đòi nó nữa,
> và bug chỉ lộ ra khi có khách hàng thứ hai — relay không lọc được theo tenant.
```

- [ ] **Step 2: ADR-0003 bỏ danh sách, giữ *why***

Thay bốn mục danh sách trong ADR-0003 bằng:

```markdown
Danh sách cụ thể bảng nào thuộc nhóm nào là **current policy**, không phải quyết định
bất biến — nó dài ra theo thời gian khi hệ thống có thêm danh mục dùng chung hay bảng
chỉ ghi thêm. Vì vậy nó sống ở `04-conventions/C-DB-database.md` mục `C-DB-04` dưới
dạng registry máy đọc được, không nằm trong ADR này.

Phân vai: **ADR giữ *why*, `C-DB` giữ *current policy*.** Mỗi entry trong registry
mang một trường `adr` trỏ ngược về ADR biện minh cho phân loại của nó — nên thêm một
bảng vẫn đòi một ADR mới, chứ không phải một PR sửa Convention.
```

Giữ nguyên phần Context, Decision, Alternatives, Consequences, và trường `Constrains`.

- [ ] **Step 3: Ghi lại việc sửa ADR-0003**

ADR-0003 đã `Accepted`. Thêm khối ghi chú dưới `Status`, cùng khuôn với ghi chú đã có ở ADR-0002:

```markdown
> **Sửa đổi (2026-08-10):** danh sách bốn nhóm bảng ban đầu nằm trong chính ADR này;
> chúng được chuyển sang `04-conventions/C-DB-database.md` mục `C-DB-04` làm canonical
> registry. Lý do: ADR bất biến còn danh sách thì tiến hóa — thêm một bảng mà phải sửa
> ADR đã `Accepted` là tự mâu thuẫn với chính quy tắc ADR. Quyết định kiến trúc trong
> ADR này không đổi; chỉ chỗ giữ danh sách đổi.
```

- [ ] **Step 4: Chạy script và commit**

```powershell
powershell -ExecutionPolicy Bypass -File "d:\My project web\erp\docs-erp\tools\check-ids.ps1"
```
Expected: `check-ids: OK - 130 ID`

```powershell
cd "d:\My project web\erp\docs-erp"
git add 04-conventions/C-DB-database.md 03-decisions/ADR-0003-multi-tenant-ready.md
git commit -m @'
refactor: chuyen registry nhom bang tu ADR-0003 sang C-DB-04

ADR bat bien con danh sach thi tien hoa. Them mot bang ma phai sua ADR da Accepted
la tu mau thuan. Truong adr o moi entry giu lai phan bao ve cua quyet dinh cu:
them bang van doi mot ADR moi.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
'@
```

---

## Task 3: `C-GO-07`, ngoại lệ bootstrap của R-17, và `check-ids` kiểm `adr`

**Files:**
- Modify: `docs-erp/04-conventions/C-GO-backend.md`
- Modify: `docs-erp/04-conventions/C-DB-database.md` (mục `C-DB-03`)
- Modify: `docs-erp/01-rules/RULES.md` (R-17)
- Modify: `docs-erp/tools/check-ids.ps1`

- [ ] **Step 1: Thêm `C-GO-07`**

```markdown
### C-GO-07 — SQL phải là một hằng chuỗi đơn

**Implements:** R-02, R-06, R-09, R-18

Câu SQL trong `*_repository.go` phải là **một `BasicLit` đơn** khai bằng `const`. Cấm
nối chuỗi — kể cả nối hai hằng — cấm `fmt.Sprintf`, `strings.Builder`, và mọi cách
dựng SQL lúc chạy.

```go
// ĐÚNG: mot BasicLit don
const insertOrderSQL = `
INSERT INTO orders (id, company_id, code)
VALUES ($1, $2, $3)`

// SAI: noi hai hang. Go coi day la constant expression, nhung checker thi phai
// evaluate expression moi biet chuoi cuoi cung la gi - va the la mo lai dung canh
// cua ma quy uoc nay dong.
const badSQL = "SELECT * FROM orders" + " WHERE company_id = $1"

// SAI: dung lúc chay. Khong the phan tich tinh.
q := fmt.Sprintf("SELECT * FROM %s WHERE company_id = $1", table)
```

**Vì sao quy ước nhỏ này quan trọng hơn vẻ ngoài của nó:** bốn Rule — R-02, R-06,
R-09, R-18 — đều cần đọc được câu SQL thật để kiểm. Với SQL là hằng, checker trích ra
bằng AST và parse được. Với SQL dựng lúc chạy, cả bốn mù hoàn toàn. Nó cũng đóng luôn
lỗ SQL injection, và R-12 đã đòi điều tương tự cho `sort` — đây là mở rộng ra toàn bộ.

Lọc động (thêm điều kiện `WHERE` tùy tham số) giải bằng cách viết sẵn vài hằng cho
từng tổ hợp, hoặc dùng `WHERE ($1::text IS NULL OR status = $1)`. Không nối chuỗi.
```

- [ ] **Step 2: `C-DB-03` thêm `tenant_root` và ghi rõ hai cột audit không FK**

Thêm một khối cột cho `tenant_root` (giống bảng nghiệp vụ nhưng bỏ `company_id`), và thêm ghi chú:

```markdown
**`created_by` và `updated_by` không bao giờ mang khóa ngoại**, dù R-08 bắt mọi cột
dạng `<singular>_id` là khóa ngoại. Đây là ngoại lệ có lý do: audit phải giữ được dấu
vết kể cả khi user bị xóa, nên ràng buộc cứng tới `users` sai về nghiệp vụ chứ không
chỉ bất tiện. Khai tường minh ở đây vì nếu không, checker R-09 sẽ đi tìm index cho một
khóa ngoại không tồn tại.

Giá trị của hai cột này khi thao tác không do người dùng khởi xướng là
`system_actor_id` khai ở `C-DB-04`.
```

- [ ] **Step 3: R-17 thêm ngoại lệ bootstrap**

Thêm vào cuối trường `**Ngoại lệ:**` của R-17:

```
Dữ liệu do migration ghi trực tiếp (bootstrap) được miễn sinh bản ghi audit, vì hệ thống audit chưa tồn tại tại thời điểm đó — bảng `audit_logs` mãi chặng sau mới có. Mọi thao tác ghi từ tầng ứng dụng sau đó đều chịu R-17 đầy đủ.
```

- [ ] **Step 4: `check-ids.ps1` kiểm `adr:` trong registry**

Chèn trước khối `# ---------- 4. Kết quả ----------`:

```powershell
# ---------- 3d. Registry trong C-DB: moi adr phai tro ADR co that va da Accepted ----
$cdbFile = Join-Path $root '04-conventions\C-DB-database.md'
if (Test-Path $cdbFile) {
    $cdbText = Get-Content -Path $cdbFile -Raw -Encoding UTF8
    foreach ($m in [regex]::Matches($cdbText, '(?m)^\s*adr:\s*(ADR-\d{4})\s*$')) {
        $aid = $m.Groups[1].Value
        $adrPath = Get-ChildItem -Path (Join-Path $root '03-decisions') -Filter "$aid-*.md" -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $adrPath) {
            Add-Err "C-DB-database.md : registry tro '$aid' nhung khong co file ADR do"
            continue
        }
        $adrText = Get-Content -Path $adrPath.FullName -Raw -Encoding UTF8
        if ($adrText -notmatch '(?m)^\*\*Status:\*\*\s*Accepted') {
            Add-Err "C-DB-database.md : registry tro '$aid' nhung ADR do khong o trang thai Accepted"
        }
    }
}
```

- [ ] **Step 5: Chứng minh checker mới bắt được lỗi**

Tạm sửa một dòng trong registry thành `adr: ADR-9999`, chạy script, xác nhận nó báo:
```
C-DB-database.md : registry tro 'ADR-9999' nhung khong co file ADR do
```
Rồi hoàn nguyên. **Không bỏ qua bước này** — checker chưa được chứng minh là checker chưa tồn tại.

- [ ] **Step 6: Chạy script và commit**

Expected: `check-ids: OK - 130 ID`

```powershell
cd "d:\My project web\erp\docs-erp"
git add -A
git commit -m @'
feat: C-GO-07 SQL la hang chuoi don, R-17 mien bootstrap, check-ids kiem adr

- C-GO-07 mo khoa bon rule R-02, R-06, R-09, R-18: co SQL la hang thi checker
  trich ra bang AST va parse duoc; SQL dung luc chay thi ca bon mu.
- R-17: migration bootstrap mien sinh audit vi bang audit_logs chua ton tai luc do.
- check-ids kiem moi adr trong registry tro ADR co that va da Accepted.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
'@
```

### ⏸ CHECKPOINT PHASE 0

Báo cáo: output `check-ids.ps1`; diff của R-08/R-17/R-18 để người duyệt xác nhận `tenant_root` đã vào **mệnh đề** chứ không chỉ vào Ngoại lệ; và bằng chứng checker `adr` bắt được `ADR-9999`.

---

# PHASE 1 — Khung Go và engine `arch/`

## Task 4: `go.mod`, cấu trúc thư mục, `Makefile`

> **Task này đã chạy, và `Makefile` của nó đã bị Task 11e xóa.** Giữ nguyên phần dưới vì
> đó là việc đã xảy ra thật; đừng dựng lại `Makefile` từ nó. Lý do bỏ: `make` không có
> trên máy dev Windows, nên mọi lệnh trong file đó không chạy được ở đúng chỗ người ta gõ.
> Bộ chạy lệnh hiện tại là `cmd/dev` — xem Task 11e.

**Files:**
- Create: `backend-erp/go.mod`, `backend-erp/Makefile`, `backend-erp/compose.dev.yml`, `backend-erp/.gitignore` (bổ sung)

- [ ] **Step 1: Khởi tạo module**

```powershell
cd "d:\My project web\erp\backend-erp"
go mod init erp
```

- [ ] **Step 2: Tạo cây thư mục**

```powershell
$dirs = @(
  'cmd/api','shared/db','shared/errors','shared/log','shared/requestid','shared/response',
  'modules','migrations','internal/testharness','internal/testutil',
  'arch/internal/loader','arch/internal/imports','arch/internal/scan','arch/internal/registry',
  'arch/testdata'
)
foreach ($d in $dirs) { New-Item -ItemType Directory -Force $d | Out-Null }
```

`modules/` sẽ rỗng suốt chặng A — đó là đúng kế hoạch, chặng B mới có module đầu tiên.

- [ ] **Step 3: `compose.dev.yml`**

```yaml
services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: erp
      POSTGRES_PASSWORD: erp
      POSTGRES_DB: erp_dev
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U erp -d erp_dev"]
      interval: 5s
      timeout: 3s
      retries: 10
```

- [ ] **Step 4: `Makefile`**

```makefile
.PHONY: dev test check lint arch migrate-up migrate-down clean-test-db

dev:
	docker compose -f compose.dev.yml up -d
	go run ./cmd/api

# test la duong MAC DINH: harness tu dung container, export DSN, chay test, don dep.
# CI goi dung target nay va KHONG tu set TEST_DATABASE_URL - nho vay duong mac dinh
# duoc chay moi PR nen no khong muc.
test:
	go run ./internal/testharness -- go test ./...

# arch chay duoc khi khong co Docker. Neu bo checker phu thuoc Docker thi ngay
# Docker hong la ngay rule ngung duoc canh.
arch:
	go test ./arch/...

lint:
	gofmt -l .
	go vet ./...

check: lint arch

migrate-up:
	migrate -path migrations -database "$(DATABASE_URL)" up

migrate-down:
	migrate -path migrations -database "$(DATABASE_URL)" down 1

clean-test-db:
	go run ./internal/testharness -clean
```

- [ ] **Step 5: Bổ sung `.gitignore`**

Thêm vào file có sẵn:
```gitignore
/bin/
*.exe
coverage.out
```

- [ ] **Step 6: Commit**

```powershell
cd "d:\My project web\erp\backend-erp"
git add -A
git commit -m @'
chore: khoi tao go module erp, cay thu muc, Makefile va compose dev

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
'@
```

---

## Task 5: Engine `arch/` và ba checker import graph

Ba checker đầu tiên chọn nhóm IMPORT vì chúng đơn giản nhất và chứng minh được toàn bộ mô hình — engine, fixture hai chiều, cách báo lỗi — trước khi làm 15 checker còn lại.

**Files:**
- Create: `arch/internal/loader/loader.go`, `arch/internal/imports/graph.go`
- Create: `arch/rules.go`, `arch/checks_import.go`, `arch/fixtures_test.go`, `arch/rules_test.go`
- Create: `arch/testdata/r01/`, `arch/testdata/r03/`, `arch/testdata/r04/`

- [ ] **Step 1: Viết fixture MUST-FAIL cho R-01 trước**

`arch/testdata/r01/violation_import_internal.go`:
```go
package order

// MUST-FAIL: file thuoc modules/order nhung import internal cua module khac.
// Import nay khong resolve duoc - do la chu y, va la ly do engine phai dung
// go/parser chu khong phai go/packages.
import (
	_ "erp/modules/customer/internal/model"
)
```

`arch/testdata/r01/violation_cmd_deep_import.go`:
```go
package main

// MUST-FAIL: cmd/** chi duoc import package goc cua module.
import (
	_ "erp/modules/order/api"
)
```

- [ ] **Step 2: Viết fixture MUST-PASS cho R-01**

`arch/testdata/r01/valid_import_api.go`:
```go
package order

// MUST-PASS: import api/ cua module khac la duong hop le duy nhat.
import (
	_ "erp/modules/customer/api"
)
```

`arch/testdata/r01/valid_cmd_root_import.go`:
```go
package main

// MUST-PASS: cmd/** import dung package goc cua module.
import (
	_ "erp/modules/order"
)
```

- [ ] **Step 3: Viết loader**

`arch/internal/loader/loader.go`:
```go
// Package loader nap file .go thanh AST. No co y KHONG dung go/packages: fixture
// trong arch/testdata co import khong resolve duoc, nen bat ky checker nao can type
// info se chet tren chinh fixture cua no.
package loader

import (
	"go/ast"
	"go/parser"
	"go/token"
	"os"
	"path/filepath"
	"strings"
)

// File la mot file Go da nap, kem duong dan tuong doi so voi goc repo.
type File struct {
	Path string // duong dan tuong doi, dung dau /
	AST  *ast.File
	FSet *token.FileSet
}

// Scope gioi han pham vi quet. Rule chi ap len production code; arch/ la tooling
// nen nam ngoai dependency graph cua ung dung.
type Scope struct {
	Roots   []string // vi du: cmd, shared, modules
	Exclude []string // vi du: arch, testdata
}

// ProductionScope la pham vi mac dinh cua moi rule.
func ProductionScope() Scope {
	return Scope{
		Roots:   []string{"cmd", "shared", "modules"},
		Exclude: []string{"arch", "testdata", "internal/testharness"},
	}
}

// FixtureScope nap mot thu muc fixture cu the.
func FixtureScope(dir string) Scope {
	return Scope{Roots: []string{dir}}
}

// Load nap moi file .go trong scope. root la thu muc goc repo.
func Load(root string, s Scope) ([]File, error) {
	fset := token.NewFileSet()
	var out []File

	for _, r := range s.Roots {
		base := filepath.Join(root, filepath.FromSlash(r))
		if _, err := os.Stat(base); os.IsNotExist(err) {
			continue // thu muc rong hoac chua ton tai: khong phai loi
		}
		err := filepath.WalkDir(base, func(p string, d os.DirEntry, err error) error {
			if err != nil {
				return err
			}
			if d.IsDir() || !strings.HasSuffix(p, ".go") {
				return nil
			}
			rel, err := filepath.Rel(root, p)
			if err != nil {
				return err
			}
			rel = filepath.ToSlash(rel)
			for _, ex := range s.Exclude {
				if strings.HasPrefix(rel, ex+"/") || strings.Contains(rel, "/"+ex+"/") {
					return nil
				}
			}
			// ParseComments de checker doc duoc comment mien tru khi can.
			f, perr := parser.ParseFile(fset, p, nil, parser.ParseComments)
			if perr != nil {
				return perr
			}
			out = append(out, File{Path: rel, AST: f, FSet: fset})
			return nil
		})
		if err != nil {
			return nil, err
		}
	}
	return out, nil
}
```

- [ ] **Step 4: Viết import graph helper**

`arch/internal/imports/graph.go`:
```go
// Package imports tra loi cau hoi "file nay import nhung gi".
package imports

import (
	"strconv"

	"erp/arch/internal/loader"
)

// Of tra ve danh sach import path cua mot file, da bo dau nhay.
func Of(f loader.File) []string {
	out := make([]string, 0, len(f.AST.Imports))
	for _, im := range f.AST.Imports {
		p, err := strconv.Unquote(im.Path.Value)
		if err != nil {
			continue
		}
		out = append(out, p)
	}
	return out
}
```

- [ ] **Step 5: Khai kiểu `Rule` và ba checker**

`arch/rules.go`:
```go
package arch

import "erp/arch/internal/loader"

type Level string

const (
	FULL    Level = "FULL"
	PARTIAL Level = "PARTIAL"
	NA      Level = "N/A"
)

// Finding la mot vi pham cu the.
type Finding struct {
	File string
	Line int
	Msg  string
}

type CheckFunc func(files []loader.File) []Finding

// Rule khai bao mot rule kem MUC ENFORCE va PHU THUOC cua no.
//
// DependsOn khong phai chu thich: engine doc no de tinh lai muc thuc te. Neu mot
// prerequisite khong duoc enforce thi muc cua moi rule phu thuoc no TU DONG tut
// xuong PARTIAL. Xem TestDependencyDowngrade.
type Rule struct {
	ID           string
	Level        Level
	DependsOn    []string
	Unverifiable string // ve khong kiem duoc; rong khi Level la FULL va khong co DependsOn
	FixtureDir   string // thu muc trong testdata; rong neu Level la NA
	Check        CheckFunc
}
```

`arch/checks_import.go`:
```go
package arch

import (
	"strings"

	"erp/arch/internal/imports"
	"erp/arch/internal/loader"
)

// checkR01 kiem ba ve cua R-01:
//  1. modules/<A>/internal chi duoc import boi chinh module A
//  2. module khac chi duoc import modules/<A>/api
//  3. cmd/** chi duoc import package goc cua module
func checkR01(files []loader.File) []Finding {
	var out []Finding
	for _, f := range files {
		owner := moduleOf(f.Path) // ten module chua file nay, rong neu khong thuoc module nao
		inCmd := strings.HasPrefix(f.Path, "cmd/")

		for _, imp := range imports.Of(f) {
			target, rest, ok := splitModuleImport(imp)
			if !ok {
				continue // khong phai import vao modules/
			}

			if inCmd {
				if rest != "" {
					out = append(out, Finding{
						File: f.Path,
						Msg:  "cmd/** chi duoc import package goc cua module, thay vi " + imp,
					})
				}
				continue
			}
			if target == owner {
				continue // module tu import chinh no: hop le
			}
			if rest != "api" && !strings.HasPrefix(rest, "api/") {
				out = append(out, Finding{
					File: f.Path,
					Msg:  "module khac chi duoc import api/ cua " + target + ", thay vi " + imp,
				})
			}
		}
	}
	return out
}

// splitModuleImport tach "erp/modules/order/internal/service" thanh ("order",
// "internal/service", true). Tra ok=false neu khong phai import vao modules/.
func splitModuleImport(imp string) (module, rest string, ok bool) {
	const prefix = "erp/modules/"
	if !strings.HasPrefix(imp, prefix) {
		return "", "", false
	}
	tail := strings.TrimPrefix(imp, prefix)
	if i := strings.Index(tail, "/"); i >= 0 {
		return tail[:i], tail[i+1:], true
	}
	return tail, "", true
}

// moduleOf tra ve ten module chua file, hoac chuoi rong.
func moduleOf(path string) string {
	const prefix = "modules/"
	if !strings.HasPrefix(path, prefix) {
		return ""
	}
	tail := strings.TrimPrefix(path, prefix)
	if i := strings.Index(tail, "/"); i >= 0 {
		return tail[:i]
	}
	return ""
}
```

Viết `checkR03` và `checkR04` trong cùng file theo đúng khuôn trên:

| Checker | Bắt gì |
|---|---|
| `checkR03` | File `*_handler.go` import `github.com/jackc/pgx` hoặc `github.com/jmoiron/sqlx`; file `*_service.go` import `github.com/gin-gonic/gin` hoặc `net/http`; file `*_repository.go` import path kết thúc `/service` hoặc `/internal/service` |
| `checkR04` | File dưới `shared/` có import chứa `erp/modules/` |

- [ ] **Step 6: Viết `fixtures_test.go` — kiểm hai chiều**

```go
package arch

import (
	"strings"
	"testing"

	"erp/arch/internal/loader"
)

// TestFixtures la thu chung minh moi checker THAT SU hoat dong. Khong co no thi
// mot checker hong va mot checker dung tren repo chua co code cho ra ket qua giong
// het nhau: ca hai deu xanh.
//
// Kiem HAI CHIEU:
//   - file ten violation_*.go PHAI sinh it nhat mot Finding
//   - file ten valid_*.go     PHAI khong sinh Finding nao
//
// Chieu thu hai quan trong khong kem chieu thu nhat. Loi that da gap: mot regex bat
// oan /checklists, /documents, /lists vi bat co (?i) lam [A-Z_-] khop ca chu thuong.
// Fixture vi pham khong bao gio phat hien duoc loi do.
func TestFixtures(t *testing.T) {
	for _, r := range rules {
		if r.Level == NA {
			continue
		}
		r := r
		t.Run(r.ID, func(t *testing.T) {
			if r.FixtureDir == "" {
				t.Fatalf("%s khong co FixtureDir: checker chua co fixture thi coi nhu chua implement", r.ID)
			}
			files, err := loader.Load("testdata", loader.FixtureScope(r.FixtureDir))
			if err != nil {
				t.Fatalf("nap fixture: %v", err)
			}
			if len(files) == 0 {
				t.Fatalf("%s: thu muc fixture testdata/%s rong", r.ID, r.FixtureDir)
			}

			var sawViolation, sawValid bool
			for _, f := range files {
				name := f.Path[strings.LastIndex(f.Path, "/")+1:]
				findings := r.Check([]loader.File{f})

				switch {
				case strings.HasPrefix(name, "violation_"):
					sawViolation = true
					if len(findings) == 0 {
						t.Errorf("%s: %s la fixture MUST-FAIL nhung checker khong bat duoc gi", r.ID, name)
					}
				case strings.HasPrefix(name, "valid_"):
					sawValid = true
					if len(findings) > 0 {
						t.Errorf("%s: %s la fixture MUST-PASS nhung checker bao %d vi pham: %v",
							r.ID, name, len(findings), findings)
					}
				default:
					t.Errorf("%s: %s khong theo quy uoc ten violation_*.go hoac valid_*.go", r.ID, name)
				}
			}
			if !sawViolation {
				t.Errorf("%s: thieu fixture violation_*.go", r.ID)
			}
			if !sawValid {
				t.Errorf("%s: thieu fixture valid_*.go", r.ID)
			}
		})
	}
}
```

- [ ] **Step 7: Chạy test — phải ĐỎ vì chưa khai `rules`**

Run: `go test ./arch/... -run TestFixtures -v`
Expected: lỗi biên dịch `undefined: rules`.

- [ ] **Step 8: Khai biến `rules` với ba rule đầu**

Thêm vào cuối `arch/rules.go`:
```go
var rules = []Rule{
	{ID: "R-01", Level: FULL, FixtureDir: "r01", Check: checkR01},
	{ID: "R-03", Level: FULL, FixtureDir: "r03", Check: checkR03},
	{ID: "R-04", Level: FULL, FixtureDir: "r04", Check: checkR04},
}
```

- [ ] **Step 9: Chạy lại — phải XANH**

Run: `go test ./arch/... -run TestFixtures -v`
Expected: `--- PASS: TestFixtures/R-01`, `R-03`, `R-04`.

Nếu một fixture `violation_*` không bị bắt, checker sai — sửa checker, **đừng sửa fixture cho dễ**.

- [ ] **Step 10: Viết `rules_test.go` chạy trên code thật**

```go
package arch

import (
	"testing"

	"erp/arch/internal/loader"
)

// TestProductionCode chay moi checker tren code that cua repo.
//
// Luu y quan trong: o chang A, modules/ con rong nen nhieu checker chay tren tap
// rong va xanh. Dieu do KHONG co nghia rule da duoc kiem - TestFixtures moi la thu
// chung minh checker hoat dong.
func TestProductionCode(t *testing.T) {
	files, err := loader.Load("..", loader.ProductionScope())
	if err != nil {
		t.Fatalf("nap code that: %v", err)
	}
	for _, r := range rules {
		if r.Level == NA {
			continue
		}
		r := r
		t.Run(r.ID, func(t *testing.T) {
			for _, f := range r.Check(files) {
				t.Errorf("%s vi pham tai %s:%d — %s", r.ID, f.File, f.Line, f.Msg)
			}
		})
	}
}
```

- [ ] **Step 11: Chạy toàn bộ và commit**

Run: `go test ./arch/... -v`
Expected: cả `TestFixtures` và `TestProductionCode` xanh.

```powershell
cd "d:\My project web\erp\backend-erp"
git add arch/
git commit -m @'
feat: engine arch va ba checker import graph kem fixture hai chieu

Engine co y khong dung go/packages: fixture co import khong resolve duoc, nen
checker nao can type info se chet tren chinh fixture cua no.

TestFixtures kiem hai chieu - violation_*.go phai bi bat, valid_*.go phai khong.
Chieu thu hai bat duoc loai loi ma fixture vi pham khong bao gio thay: checker
bat oan code hop le.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
'@
```

---

## Task 6: Cơ chế hạ mức và `README.md` sinh tự động

**Files:**
- Create: `arch/downgrade.go`, `arch/downgrade_test.go`, `arch/gen_readme.go`
- Create: `arch/testdata/cgo07/`

- [ ] **Step 1: Viết `TestDependencyDowngrade` trước khi có cơ chế**

`arch/downgrade_test.go`:
```go
package arch

import "testing"

// TestDependencyDowngrade chung minh DependsOn KHONG phai chu thich.
//
// Neu prerequisite cua mot rule that bai, muc thuc te cua rule do phai tu dong tut
// xuong PARTIAL. Khong co test nay thi dong DependsOn cung chi la prose, chi khac
// cho no nam trong file .go.
func TestDependencyDowngrade(t *testing.T) {
	rs := []Rule{
		{ID: "C-GO-07", Level: FULL},
		{ID: "R-02", Level: FULL, DependsOn: []string{"C-GO-07"}},
	}

	t.Run("prerequisite xanh thi giu FULL", func(t *testing.T) {
		got := EffectiveLevels(rs, map[string]bool{"C-GO-07": true, "R-02": true})
		if got["R-02"] != FULL {
			t.Errorf("muon FULL, duoc %s", got["R-02"])
		}
	})

	t.Run("prerequisite do thi tut xuong PARTIAL", func(t *testing.T) {
		got := EffectiveLevels(rs, map[string]bool{"C-GO-07": false, "R-02": true})
		if got["R-02"] != PARTIAL {
			t.Errorf("C-GO-07 that bai thi R-02 phai tut xuong PARTIAL, duoc %s", got["R-02"])
		}
	})
}
```

- [ ] **Step 2: Chạy — phải ĐỎ**

Run: `go test ./arch/... -run TestDependencyDowngrade`
Expected: lỗi biên dịch `undefined: EffectiveLevels`.

- [ ] **Step 3: Implement `EffectiveLevels`**

`arch/downgrade.go`:
```go
package arch

// EffectiveLevels tinh muc enforce THUC TE cua tung rule.
//
// Muc khai trong Rule.Level la muc TOI DA - no chi dat duoc khi moi prerequisite
// deu dang duoc enforce. Prerequisite that bai nghia la du lieu dau vao cua checker
// khong dang tin, nen ket luan cua no khong con la FULL du code checker khong doi
// mot dong nao.
func EffectiveLevels(rs []Rule, passed map[string]bool) map[string]Level {
	out := make(map[string]Level, len(rs))
	for _, r := range rs {
		lvl := r.Level
		for _, dep := range r.DependsOn {
			if ok, seen := passed[dep]; seen && !ok {
				lvl = PARTIAL
				break
			}
		}
		out[r.ID] = lvl
	}
	return out
}
```

- [ ] **Step 4: Chạy — phải XANH**

Run: `go test ./arch/... -run TestDependencyDowngrade -v`
Expected: cả hai subtest PASS.

- [ ] **Step 5: Viết `gen_readme.go`**

```go
//go:build ignore

// Chuong trinh nay sinh arch/README.md tu bien rules.
//
// Bang viet tay se lech khoi code ngay lan sua checker thu hai. Sinh tu du lieu thi
// khong the lech.
//
// Chi thi //go:generate KHONG dat o day - xem ghi chu duoi.
package main

// Doc bien rules qua go/parser tu chinh package arch roi sinh bang Markdown gom bon
// cot: Rule, Enforce, Dependency, Ve khong kiem duoc.
// Ghi de arch/README.md, kem canh bao o dau file rang day la file sinh tu dong.
```

Thân chương trình làm đúng bốn bước, không hơn:

1. `parser.ParseFile` đọc `rules.go`, tìm `*ast.ValueSpec` tên `rules`.
2. Với mỗi phần tử `*ast.CompositeLit`, trích bốn key: `ID`, `Level`, `DependsOn`, `Unverifiable`.
3. Sinh bảng Markdown bốn cột: `Rule` · `Enforce` · `Dependency` · `Vế không kiểm được`. Cột `Dependency` nối `DependsOn` bằng dấu phẩy, rỗng thì ghi `—`.
4. Ghi đè `arch/README.md`, mở đầu bằng dòng `<!-- File nay sinh tu dong bang: go generate ./arch/... — dung sua tay -->`.

Không đọc `rules` bằng reflection lúc chạy: `gen_readme.go` có build tag `ignore` nên nó không nằm trong package `arch`, và đọc bằng AST giữ được thứ tự khai báo.

- [ ] **Step 6: Sinh README và kiểm nội dung**

Run: `cd arch && go generate ./...`
Expected: `arch/README.md` xuất hiện với bảng ba dòng (R-01, R-03, R-04), cột `Dependency` rỗng cho cả ba.

- [ ] **Step 7: Commit**

```powershell
cd "d:\My project web\erp\backend-erp"
git add arch/
git commit -m @'
feat: co che tu ha muc khi prerequisite that bai va README sinh tu dong

DependsOn la du lieu chu khong phai chu thich: EffectiveLevels doc no va tinh lai
muc thuc te. TestDependencyDowngrade chung minh co che chay that.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
'@
```

### ⏸ CHECKPOINT PHASE 1

Báo cáo: output `go test ./arch/... -v`; nội dung `arch/README.md` vừa sinh; và một lần chạy chứng minh khi cố tình làm hỏng `checkR01` thì fixture `violation_*` bắt được sự cố đó.

---

# PHASE 2 — `shared/`

Bốn task, mỗi task một hoặc hai package. Mọi package viết ở đây đều bị ba checker của Task 5 canh ngay từ lúc commit.

## Task 7: `shared/requestid` và `shared/log`

**Files:**
- Create: `shared/requestid/requestid.go`, `shared/requestid/requestid_test.go`
- Create: `shared/log/log.go`, `shared/log/log_test.go`

- [ ] **Step 1: Viết test cho `requestid` trước**

```go
package requestid_test

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"

	"erp/shared/requestid"
)

func TestMiddlewareGanIDVaoContextVaHeader(t *testing.T) {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.Use(requestid.Middleware())

	var seen string
	r.GET("/x", func(c *gin.Context) {
		seen = requestid.FromContext(c.Request.Context())
		c.Status(http.StatusOK)
	})

	w := httptest.NewRecorder()
	r.ServeHTTP(w, httptest.NewRequest(http.MethodGet, "/x", nil))

	if seen == "" {
		t.Fatal("request_id khong duoc gan vao ctx")
	}
	// R-17: request_id di qua header X-Request-Id cho MOI response, ke ca response
	// khong co envelope (vi du endpoint tra file).
	if got := w.Header().Get("X-Request-Id"); got != seen {
		t.Errorf("header X-Request-Id = %q, muon %q", got, seen)
	}
}

func TestFromContextTraChuoiRongKhiChuaGan(t *testing.T) {
	if got := requestid.FromContext(context.Background()); got != "" {
		t.Errorf("muon chuoi rong, duoc %q", got)
	}
}

func TestMiddlewareGiuIDDoClientGuiLen(t *testing.T) {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.Use(requestid.Middleware())
	var seen string
	r.GET("/x", func(c *gin.Context) {
		seen = requestid.FromContext(c.Request.Context())
		c.Status(http.StatusOK)
	})

	req := httptest.NewRequest(http.MethodGet, "/x", nil)
	req.Header.Set("X-Request-Id", "tu-client")
	r.ServeHTTP(httptest.NewRecorder(), req)

	if seen != "tu-client" {
		t.Errorf("muon giu id client gui len, duoc %q", seen)
	}
}
```

- [ ] **Step 2: Chạy — phải ĐỎ**

Run: `go test ./shared/requestid/...`
Expected: lỗi biên dịch, package chưa tồn tại.

- [ ] **Step 3: Implement `requestid`**

```go
// Package requestid so huu request_id: sinh no, gan vao context, va tra ve qua
// header X-Request-Id.
//
// R-17 so huu request_id; P-OBS chi tieu thu. Khong package nao khac duoc sinh no.
package requestid

import (
	"context"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

const HeaderName = "X-Request-Id"

type ctxKey struct{}

// Middleware gan request_id vao context cua request va vao header response.
// No giu lai id do client gui len neu co - de mot request di qua nhieu he thong
// van truy duoc bang cung mot id.
func Middleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		id := c.GetHeader(HeaderName)
		if id == "" {
			id = uuid.NewString()
		}
		ctx := context.WithValue(c.Request.Context(), ctxKey{}, id)
		c.Request = c.Request.WithContext(ctx)
		c.Header(HeaderName, id)
		c.Next()
	}
}

// FromContext lay request_id ra. Tra chuoi rong neu chua duoc gan - goi trong test
// hoac trong job nen khong con request nao.
func FromContext(ctx context.Context) string {
	if v, ok := ctx.Value(ctxKey{}).(string); ok {
		return v
	}
	return ""
}
```

- [ ] **Step 4: Chạy — phải XANH**

Run: `go test ./shared/requestid/... -v`
Expected: ba test PASS.

- [ ] **Step 5: Viết test và implement `shared/log`**

Test kiểm ba điều: `FromContext` trả logger không nil khi ctx rỗng; logger lấy từ ctx có attribute `request_id` khi ctx đã qua middleware; `Init` cấu hình được level từ chuỗi.

```go
// Package log la wrapper MONG quanh log/slog, khong phai mot abstraction.
//
// No lam dung mot viec: tra ve logger da gan request_id lay tu ctx. Khong tu dinh
// nghia level, khong tu dinh nghia field. R-17 so huu request_id, package nay chi
// tieu thu (ranh gioi voi P-OBS).
package log

import (
	"context"
	"log/slog"
	"os"

	"erp/shared/requestid"
)

var base *slog.Logger = slog.New(slog.NewJSONHandler(os.Stdout, nil))

// Init cau hinh logger goc. Goi mot lan o composition root.
func Init(level string) {
	var l slog.Level
	if err := l.UnmarshalText([]byte(level)); err != nil {
		l = slog.LevelInfo
	}
	base = slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: l}))
}

// FromContext tra logger da gan request_id. Handler va service PHAI dung ham nay
// thay vi goi logger toan cuc (R-17).
func FromContext(ctx context.Context) *slog.Logger {
	if id := requestid.FromContext(ctx); id != "" {
		return base.With("request_id", id)
	}
	return base
}
```

- [ ] **Step 6: Chạy toàn bộ và commit**

Run: `go test ./shared/... ./arch/... -v`
Expected: xanh. `arch/` xanh nghĩa là hai package mới không vi phạm R-01/R-03/R-04.

```powershell
cd "d:\My project web\erp\backend-erp"
git add shared/requestid shared/log
git commit -m @'
feat: shared/requestid va shared/log

requestid so huu request_id va tra qua header X-Request-Id cho moi response, ke ca
response khong co envelope. log la wrapper mong, chi lay logger da gan request_id
ra khoi ctx - khong tu dinh nghia level hay field.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
'@
```

---

## Task 8: `shared/errors` và `shared/response`

Nội dung lấy từ `C-API-03` và `C-API-05` — đọc hai mục đó trước, và **không** phát minh lại hình dạng envelope hay bảng mã lỗi.

**Files:**
- Create: `shared/errors/errors.go`, `shared/errors/codes.go`, `shared/errors/errors_test.go`
- Create: `shared/response/response.go`, `shared/response/fielderrors.go`, `shared/response/response_test.go`

- [ ] **Step 1: Viết test cho `errors`**

Kiểm: `NotFound` tạo `*Error` có `Code` đúng; `errors.Is` xuyên qua `Wrap`; `errors.As` lấy được `*Error` từ lỗi đã bọc nhiều lớp; `Error()` không lộ nội dung lỗi gốc ra chuỗi trả client.

- [ ] **Step 2: Implement `errors`**

`codes.go` khai hằng mã lỗi đúng bảng ở `C-API-05`, tối thiểu: `CodeValidationFailed`, `CodeUnauthenticated`, `CodeForbidden`, `CodeNotFound`, `CodeConflict`, `CodeVersionConflict`, `CodeIdempotencyKeyMissing`, `CodeInternal`.

`errors.go` khai kiểu `Error` có `Code`, `Message`, `HTTPStatus`, và `cause` **không xuất khẩu** — nguyên nhân gốc không được lọt ra client.

- [ ] **Step 3: Viết test cho `response` — ba hình dạng envelope**

Kiểm đúng ba trường hợp của `C-API-03`: thành công một bản ghi; thành công danh sách kèm `meta`; lỗi validate 422 kèm `fields`. Thêm một test kiểm `request_id` có mặt trong **mọi** envelope.

- [ ] **Step 4: Implement `response`**

Struct `Envelope`, `Meta`, `ErrorBody`, `FieldError` đúng như `C-API-03`. Helper `Success`, `Created`, `NoContent`, `List`, `ValidationFailed`, `Error`.

`fielderrors.go` implement `FieldErrors(err error) []FieldError` theo hợp đồng đã chốt: `field` là đường dẫn theo tag `json`, phần tử mảng đánh chỉ số từ 0 (`items.0.quantity`), lỗi không gắn được vào field nào trả một phần tử với `Field` rỗng.

- [ ] **Step 5: Chạy và commit**

Run: `go test ./shared/... ./arch/...`

```powershell
git add shared/errors shared/response
git commit -m @'
feat: shared/errors va shared/response theo C-API-03 va C-API-05

FieldErrors dich loi validator sang duong dan theo tag json, phan tu mang danh chi
so tu 0 - do la thu frontend can de highlight dung o thu may cua dong thu may.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
'@
```

---

## Task 9: `shared/db`

**Files:**
- Create: `shared/db/dbtx.go`, `shared/db/open.go`, `shared/db/dbtx_test.go`

- [ ] **Step 1: Viết `dbtx.go`**

```go
// Package db cung cap hop dong duy nhat giua repository va database.
package db

import (
	"context"
	"database/sql"

	"github.com/jmoiron/sqlx"
)

// DBTX la thu duy nhat repository nhan de cham toi database. No co y KHONG co
// BeginTxx, Commit hay Rollback: repository cam DBTX thi khong co cach nao mo hay
// dong mot transaction, ke ca khi nguoi viet muon (C-GO-03).
type DBTX interface {
	GetContext(ctx context.Context, dest interface{}, query string, args ...interface{}) error
	SelectContext(ctx context.Context, dest interface{}, query string, args ...interface{}) error
	QueryRowxContext(ctx context.Context, query string, args ...interface{}) *sqlx.Row
	ExecContext(ctx context.Context, query string, args ...interface{}) (sql.Result, error)
}

// Hai dong nay la hop dong do trinh bien dich giu: ca *sqlx.DB lan *sqlx.Tx deu thoa
// DBTX. Nho do cung mot method repository dung duoc o ca hai ngu canh, va repository
// khong can biet minh dang o dau.
//
// Dat chung o day thay vi de build tu do rai rac: doi chu ky mot method trong DBTX
// ma sqlx khong con thoa thi loi hien ngay tai file nay, kem dung ten method.
var (
	_ DBTX = (*sqlx.DB)(nil)
	_ DBTX = (*sqlx.Tx)(nil)
)
```

- [ ] **Step 2: Viết test khẳng định hợp đồng**

```go
package db_test

import (
	"testing"

	"github.com/jmoiron/sqlx"

	"erp/shared/db"
)

// TestSqlxThoaDBTX la test bien dich: neu sqlx doi API thi test nay khong build.
func TestSqlxThoaDBTX(t *testing.T) {
	var _ db.DBTX = (*sqlx.DB)(nil)
	var _ db.DBTX = (*sqlx.Tx)(nil)
}
```

- [ ] **Step 3: Implement `Open`**

Nhận DSN, mở `sqlx.Connect` với driver `pgx`, đặt `MaxOpenConns`, `MaxIdleConns`, `ConnMaxLifetime` từ config, `PingContext` để fail fast.

- [ ] **Step 4: Chạy và commit**

Run: `go test ./shared/... ./arch/...`

---

### ⏸ CHECKPOINT PHASE 2

Báo cáo: `go test ./shared/... ./arch/... -v`; xác nhận `arch/` vẫn xanh sau khi có 5 package thật (tức 3 checker đã chạy trên code thật chứ không còn trên tập rỗng).

---

# PHASE 3 — Migration và test harness

## Task 10: Migration `000001_create_companies` và registry loader

**Files:**
- Create: `migrations/000001_create_companies.up.sql`, `migrations/000001_create_companies.down.sql`
- Create: `arch/internal/registry/registry.go`, `arch/internal/registry/registry_test.go`

- [ ] **Step 1: Viết migration `up`**

```sql
-- companies thuoc nhom tenant_root (C-DB-04): no LA tenant nen khong co company_id,
-- nhung chiu moi thu con lai nhu bang nghiep vu - du ba cot thoi gian, du cot audit,
-- van sinh audit, van soft delete.
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

-- Partial unique index chu khong phai UNIQUE thuong (R-18, C-DB-05): xoa mem mot
-- cong ty roi tao lai dung ma do phai duoc.
CREATE UNIQUE INDEX uq_companies_code ON companies(code) WHERE deleted_at IS NULL;

-- created_by va updated_by KHONG co khoa ngoai toi users: audit phai giu duoc dau
-- vet ke ca khi user bi xoa (C-DB-03). Bang users cung mai chang B moi ton tai.

-- Seed cong ty dau tien. Day la bootstrap: duoc mien sinh ban ghi audit theo ngoai
-- le cua R-17, vi bang audit_logs mai chang C moi co.
INSERT INTO companies (code, name, created_by, updated_by)
VALUES ('DEFAULT', 'Cong ty mac dinh',
        '00000000-0000-4000-8000-000000000001',
        '00000000-0000-4000-8000-000000000001');
```

- [ ] **Step 2: Viết migration `down`**

```sql
DROP TABLE IF EXISTS companies;
```

- [ ] **Step 3: Viết test cho registry loader trước**

```go
package registry_test

import (
	"testing"

	"erp/arch/internal/registry"
)

func TestLoadDocSystemActorID(t *testing.T) {
	r, err := registry.Load("../../../../docs-erp/04-conventions/C-DB-database.md")
	if err != nil {
		t.Fatalf("nap registry: %v", err)
	}
	const want = "00000000-0000-4000-8000-000000000001"
	if r.SystemActorID != want {
		t.Errorf("system_actor_id = %q, muon %q", r.SystemActorID, want)
	}
}

func TestOutboxThuocAppendOnlyChuKhongPhaiSystem(t *testing.T) {
	r, err := registry.Load("../../../../docs-erp/04-conventions/C-DB-database.md")
	if err != nil {
		t.Fatalf("nap registry: %v", err)
	}
	// Loi nay da suyt lot hai lan. Neu outbox nam trong system_tables thi no duoc
	// mien company_id, R-06 khong doi cot do nua, va bug chi lo ra khi co khach hang
	// thu hai - relay khong loc duoc theo tenant.
	if r.GroupOf("outbox") != "append_only_tables" {
		t.Errorf("outbox phai thuoc append_only_tables, dang thuoc %q", r.GroupOf("outbox"))
	}
	if r.GroupOf("companies") != "tenant_root" {
		t.Errorf("companies phai thuoc tenant_root, dang thuoc %q", r.GroupOf("companies"))
	}
}
```

- [ ] **Step 4: Implement registry loader**

Trích khối ` ```yaml ` đầu tiên trong `C-DB-database.md` sau heading `### C-DB-04`, parse bằng `gopkg.in/yaml.v3`, trả struct có `SystemActorID` và map nhóm → danh sách bảng, kèm method `GroupOf(table string) string`.

- [ ] **Step 5: Thêm checker kiểm `SYSTEM_ACTOR_ID` khớp giữa ba nơi**

Checker đọc registry, rồi grep `migrations/*.sql` tìm mọi UUID xuất hiện ở vị trí `created_by`/`updated_by` và khẳng định chúng bằng `SystemActorID`. Fixture: `testdata/sysactor/violation_*.sql` dùng UUID khác, `valid_*.sql` dùng đúng.

- [ ] **Step 6: Chạy và commit**

Run: `go test ./arch/... -v`

---

## Task 11: `internal/testharness` và ba checker hạ tầng test

**Files:**
- Create: `internal/testharness/main.go`, `internal/testharness/container.go`
- Create: `internal/testutil/connect.go`
- Create: `arch/checks_testinfra.go`, `arch/testdata/testinfra/`

- [ ] **Step 1: Viết ba fixture MUST-FAIL trước**

`arch/testdata/testinfra/violation_package_dung_container.go`:
```go
package repository

// MUST-FAIL: package test tu dung ha tang. Test infrastructure so huu vong doi;
// test package chi tieu thu.
import (
	_ "github.com/testcontainers/testcontainers-go"
)
```

`arch/testdata/testinfra/violation_exec_docker_test.go`:
```go
package repository

// MUST-FAIL: dung ha tang bang duong vong, ne checker cam import testcontainers.
import "os/exec"

func dungContainer() {
	_ = exec.Command("docker", "run", "-d", "postgres:16")
}
```

`arch/testdata/testinfra/valid_chi_doc_bien.go`:
```go
package repository

// MUST-PASS: chi tieu thu ha tang qua bien moi truong.
import "os"

func dsn() string {
	return os.Getenv("TEST_DATABASE_URL")
}
```

- [ ] **Step 2: Chạy — phải ĐỎ vì chưa có checker**

Run: `go test ./arch/... -run TestFixtures/testinfra`
Expected: fail vì rule chưa khai.

- [ ] **Step 3: Implement ba checker**

```go
package arch

// Ba checker nay enforce nguyen tac:
//
//   Test infrastructure owns infrastructure lifecycle.
//   Test packages consume infrastructure; they do not create or destroy it.
//
// Chan tinh luc review, re hon va som hon mot assertion runtime dem so container.
// Quan trong hon: chung khoa KIEN TRUC chu khong khoa mot con so, nen van dung khi
// sau nay doi testcontainers sang thu khac.
```

| Checker | Bắt gì | Loại trừ |
|---|---|---|
| `checkTestInfraImport` | Import chứa `testcontainers` | `internal/testharness/**` |
| `checkTestInfraExec` | `exec.Command` với đối số đầu là chuỗi chứa `"docker"` trong file `*_test.go` | `internal/testharness/**` |
| `checkCINoTestDBURL` | Đọc `.github/workflows/ci.yml`, job `test` có `TEST_DATABASE_URL` trong `env` | — |

- [ ] **Step 4: Implement `internal/testharness`**

Chương trình có hai chế độ:
- Mặc định: dựng **đúng một** container Postgres, chạy migration lên database `erp_template`, export `TEST_DATABASE_URL`, `exec` lệnh truyền sau `--`, rồi dọn container.
- `-clean`: chỉ dọn container còn sót.

- [ ] **Step 5: Implement `internal/testutil`**

```go
// Package testutil cho test package TIEU THU ha tang. No khong bao gio tao hay xoa
// ha tang - do la viec cua internal/testharness.
package testutil

// Connect tra ve ket noi toi mot database rieng cua package test hien tai, tao tu
// template erp_template.
//
// Neu TEST_DATABASE_URL rong thi FAIL NGAY voi thong bao ro rang, khong im lang tu
// xoay xo bang cach dung container - do chinh la thu nguyen tac nay cam.
func Connect(t *testing.T) *sqlx.DB {
	t.Helper()

	admin := os.Getenv("TEST_DATABASE_URL")
	if admin == "" {
		t.Fatal("TEST_DATABASE_URL rong. Chay `go run ./cmd/dev test`, hoac set bien nay tro toi mot Postgres co san.")
	}

	adminDB, err := sqlx.Connect("pgx", admin)
	if err != nil {
		t.Fatalf("ket noi Postgres: %v", err)
	}
	defer adminDB.Close()

	// Ten database lay tu ten test da lam sach, cong hau to ngau nhien de hai lan
	// chay khong dam nhau.
	name := "t_" + sanitize(t.Name()) + "_" + strconv.FormatInt(time.Now().UnixNano()%1e6, 36)

	// Tao tu TEMPLATE thay vi chay lai chuoi migration: chep mot database rong
	// nhanh hon nhieu, va chi phi chay migration tang tuyen tinh theo so file.
	if _, err := adminDB.Exec(`CREATE DATABASE ` + pq(name) + ` TEMPLATE erp_template`); err != nil {
		t.Fatalf("tao database %s: %v", name, err)
	}
	t.Cleanup(func() {
		// Xoa database la don DU LIEU cua chinh test nay, khong phai don HA TANG.
		// Container van do internal/testharness so huu.
		conn, err := sqlx.Connect("pgx", admin)
		if err != nil {
			return
		}
		defer conn.Close()
		_, _ = conn.Exec(`DROP DATABASE IF EXISTS ` + pq(name) + ` WITH (FORCE)`)
	})

	db, err := sqlx.Connect("pgx", replaceDBName(admin, name))
	if err != nil {
		t.Fatalf("ket noi database %s: %v", name, err)
	}
	t.Cleanup(func() { db.Close() })
	return db
}
```

Ba helper còn lại: `sanitize` giữ lại `[a-z0-9_]` và hạ chữ thường; `pq` bọc identifier bằng dấu nháy kép và nhân đôi nháy bên trong; `replaceDBName` đổi phần path của DSN sang tên database mới.

Thông báo khi thiếu biến: ``TEST_DATABASE_URL rong. Chay `go run ./cmd/dev test`, hoac set bien nay tro toi mot Postgres co san.``

- [ ] **Step 6: Chạy và commit**

Run: `go run ./cmd/dev test`
Expected: harness dựng container, chạy toàn bộ test, dọn container. `go test ./arch/...` xanh gồm ba checker mới.

---

### ⏸ CHECKPOINT PHASE 3

Báo cáo: output `go run ./cmd/dev test`; bằng chứng chỉ **một** container Postgres tồn tại trong lúc chạy (`docker ps` giữa chừng); và output `go test ./arch/... ` khi **đã tắt Docker** — phải vẫn xanh.

---

# PHASE 4 — `cmd/api`

## Task 12: Composition root, `/health`, `/ready`

**Files:**
- Create: `cmd/api/main.go`, `cmd/api/config.go`, `cmd/api/router.go`, `cmd/api/health_test.go`

- [ ] **Step 1: Viết test cho `/health` và `/ready` trước**

```go
func TestHealthLuonTra200(t *testing.T) { /* khong cham DB */ }

func TestReadyTra200KhiDBSong(t *testing.T) { /* dung testutil.Connect */ }

// Day la test quan trong nhat cua task: /ready phai PHAN BIET duoc DB song va DB
// chet. Mot /ready luon tra 200 thi vo dung - no khong ngan duoc viec dua mot
// instance khong ket noi duoc DB vao load balancer.
func TestReadyTra503KhiDBChet(t *testing.T) {
	db := mustOpen(t, "postgres://khong-ton-tai:5432/x?sslmode=disable&connect_timeout=1")
	w := callReady(t, db)
	if w.Code != http.StatusServiceUnavailable {
		t.Errorf("/ready = %d, muon 503", w.Code)
	}
}
```

- [ ] **Step 2: Chạy — phải ĐỎ**

- [ ] **Step 3: Implement config đọc env, fail fast**

Đọc `PORT`, `DATABASE_URL`, `LOG_LEVEL`. Thiếu `DATABASE_URL` thì thoát ngay với thông báo rõ, không chạy tiếp với giá trị mặc định.

- [ ] **Step 4: Implement router và hai endpoint**

`/health` và `/ready` nằm **ngoài** `/api/v1` theo ngoại lệ của R-13. `/health` không chạm DB; `/ready` gọi `PingContext` với timeout ngắn, trả 503 khi lỗi.

- [ ] **Step 5: Implement `main.go`**

Thứ tự: đọc config → `log.Init` → `db.Open` → dựng router với `requestid.Middleware()` → `http.Server` có graceful shutdown.

- [ ] **Step 6: Chạy toàn bộ và commit**

Run: `go run ./cmd/dev check` rồi `go run ./cmd/dev test`

### Đã chạy — bốn quyết định và một lỗi môi trường thật

1. **`/health` và `/ready` đi qua envelope của `shared/response`.** R-13 miễn cho chúng *tiền tố* `/api/v1`, không miễn *hình dạng* response — hai vế độc lập nhau, và coi một ngoại lệ về đường dẫn là ngoại lệ về thân response là cách một ngoại lệ hẹp nở ra. Hệ quả: `503` cần một `code`, nên C-API-05 nhận thêm `ERR_COMMON_SERVICE_UNAVAILABLE` kèm ghi chú nói rõ nó là mã **hạ tầng** duy nhất và vì sao nó nằm trong một bảng mã nghiệp vụ.
2. **`recovery()` thay cho `gin.Recovery()`.** Bản có sẵn trả `500` với thân **rỗng** — không envelope, không `request_id`, đúng lúc người ta cần `request_id` nhất để tìm lại stack trong log.
3. **`Pinger` thay vì `*sqlx.DB`** ở `/ready`, để test dùng được một kết nối chết thật. Cả hai chiều đều có test: `Pinger` giả chứng minh handler rẽ nhánh đúng, `sqlx.Open` tới một cổng không ai nghe chứng minh `*sqlx.DB` thật sự báo lỗi.
4. **`LOG_LEVEL` gõ nhầm bị từ chối lúc khởi động.** `log.Init` cố ý dễ — nó không được phép làm sập tiến trình — nhưng người *đọc cấu hình* thì được quyền từ chối trước khi tiến trình chạy. Tập mức hợp lệ lấy từ `log.Names()`, không chép tay sang `cmd/api`.

**Lỗi môi trường thật:** `compose.dev.yml` map cổng `5432`, mà máy dev đã có một Postgres **native** chiếm cổng đó. Kiểu hỏng không phải "không kết nối được" mà là **kết nối nhầm**: `localhost:5432` nói chuyện với database của người khác, và `migrate-up` suýt chạy lên đó. Đổi sang `5433:5432`.

**Graceful shutdown không kiểm được bằng tín hiệu trên Windows** — `kill -TERM` ở đó giết cứng tiến trình (thoát 143), nên một lần chạy tay **không** đi qua đoạn `Shutdown` lần nào. Câu hỏi được đặt ở mức hàm: hủy context là đúng thứ `signal.NotifyContext` làm, và nó chạy giống nhau trên mọi hệ điều hành. Cả hai đường ra của `phucVu` — tắt theo yêu cầu → `0`, không mở được cổng → khác `0` — đều có test, và cả hai đều đỏ khi bị phá.

---

# PHASE 5 — 15 checker còn lại

Mỗi checker theo đúng vòng: fixture MUST-FAIL → chạy, đỏ → viết checker → chạy, bắt đúng → fixture MUST-PASS → chạy, xanh.

## Task 13: Checker nhóm AST — R-11, R-14, R-15, R-16, R-05

| Rule | Bắt gì | Mức | Fixture MUST-FAIL | Fixture MUST-PASS |
|---|---|---|---|---|
| R-11 | `c.JSON(`, `c.AbortWithStatusJSON(`, `c.IndentedJSON(`, `c.PureJSON(` với tham số thứ hai là `gin.H{` hoặc struct literal, trong `modules/**` và `shared/middleware/**` | FULL | handler trả `gin.H{}` | handler gọi `response.Success` |
| R-14 | `c.GetHeader("Authorization")`, `r.Header.Get("Authorization")`, `jwt.Parse(`, `jwt.ParseWithClaims(`, `ParseUnverified(` ngoài `shared/middleware/auth` | FULL | service đọc header | middleware đọc header |
| R-15 | Hàm khớp `func (s *XService) Yyy` mà tham số thứ hai không phải `actor auth.Actor`, hoặc câu lệnh đầu không phải `if err := s.authz.Can(`/`Require(`; `auth.FromContext(` trong `*_service.go` | PARTIAL — vế "handler so sánh role" là heuristic | service thiếu actor; service mở đầu bằng `BeginTxx` | service đúng khuôn; method `Internal*` |
| R-16 | Field tên khớp `(?i)(password\|passwd\|matkhau\|secret\|token\|apikey\|api_key\|privatekey\|cccd\|cmnd\|otp)` mà tag không phải `json:"-"` | PARTIAL — dữ liệu qua alias, helper, custom logger không kiểm được | struct có `PasswordHash` với tag `json:"password_hash"` | cùng struct với tag `json:"-"` |
| R-05 | Bất kỳ `.Publish(` trong `modules/**`; `outboxRepo.Append(` trong `*_handler.go` hoặc `*_repository.go`; import module ngoài `allowed_deps` | PARTIAL — vế "ghi outbox trong cùng transaction" cần data-flow | service gọi `bus.Publish` sau `tx.Commit()` | service chỉ gọi `outboxRepo.Append(ctx, tx, ...)` |

**Với R-16, không đổi mệnh đề thành "logger phải có số tham số chẵn".** `logger.Info("user", "password", password)` thỏa hình dạng đó và vẫn lộ mật khẩu — đó là kiểm hình dạng thay vì kiểm thứ cần kiểm. Rule bảo mật giữ conservative: false negative nguy hiểm hơn false positive. Ghi vế không kiểm được vào `Unverifiable`.

**Với R-05, fixture MUST-FAIL bắt buộc có ca `bus.Publish` đứng SAU `tx.Commit()`** — đó là ca mà mệnh đề cũ để lọt, và là bài toán dual write mà outbox sinh ra để giải.

### Đã chạy — năm checker, và ba lỗi mà chính cơ chế kiểm bắt được

**Không rule nào trong nhóm này lên FULL, kể cả R-11 và R-14 mà bảng trên khai FULL.** Lý do không phải thiếu công sức mà là thiếu **thông tin**: `loader` cố ý không dùng `go/packages` nên không có type info, mà checker chỉ biết một biểu thức *viết ra* thế nào chứ không biết nó *là* gì. `c.JSON(200, than)` với `than` là một biến, hay `logger.Info("x", u)` với `u` là struct, đều đi qua sạch sẽ. Nâng FULL lúc này là lặp lại đúng lỗi Task 11d đi sửa, chỉ khác chỗ nó ở một rule khác. **R-03 cũng giữ PARTIAL** dù vế thứ tư đã có: vế còn lại — không checker nào bắt buộc quy ước đặt tên — không hề biến mất khi vế thứ tư được thêm.

**Ba lỗi do cơ chế kiểm bắt, không do đọc lại code:**

1. **Mâu thuẫn bên trong R-16.** *Dấu hiệu vi phạm* bắt mọi field khớp regex mà tag khác `json:"-"`; *Cách sửa* của chính R-16 lại đề nghị "thêm một field boolean riêng ở DTO". Một field `DaDatMatKhau bool` khớp regex — rule bắt đúng thứ nó vừa khuyên. Fixture `valid_tag_an.go` đỏ ngay lần chạy đầu. Đã sửa **rule**, không phải sửa fixture: field kiểu `bool` được miễn, vì một `bool` chỉ lộ đúng một bit "có hay không".
2. **R-16 bắt oan trên code thật.** Checker chỉ so *tên method*, nên `response.Error(c, err)` — đường ra lỗi chuẩn của mọi handler — bị bắt vì nó cũng tên `Error`. Fixture không thấy; `TestProductionCode` thấy ngay. Nay checker đọc cả **người nhận**, đúng như dấu hiệu của R-16 viết (`logger.Info(`, `fmt.Printf(`, `log.Println(`).
3. **`relay/` không nằm trong scope nào.** Lộ ra khi một fixture của R-05 cần mô tả relay và không khai được đường dẫn hợp lệ nào. `relay/` là nơi **duy nhất** được publish ra bus — một thư mục mang đặc quyền mà không scope nào quét là chỗ dễ nhất để mọi rule khác cũng bị bỏ qua ở đó. Đã thêm vào `ProductionScope` và `TestInfraScope`.

**Thêm một cột vào bảng mức: `FILE`.** Từ task này trở đi có checker chỉ kết luận về `modules/**`, mà `modules/` còn rỗng — chúng chạy, không thấy gì, và bảng in `PASS`. Dòng đó không phân biệt được với một checker đã quét cả repo rồi không thấy vi phạm. Nay bảng nói thẳng: `PASS tren tap RONG: chua co file nao trong tam ket luan`. `Rule.Targets` khai *rule kết luận về đâu*, khác `Scope` khai *loader nạp ở đâu* — hai cái lệch nhau đúng ở chỗ nguy hiểm.

`targetChuaCo` tự hết hạn theo đúng cách `Scope.Optional` tự hết hạn. Bản đầu của nó hỏi `os.Stat` và **đỏ ngay**: `backend-erp/modules/` có tồn tại — nó được tạo từ Task 4 — nhưng rỗng. Cột `FILE` đo *số file*, nên một thư mục rỗng và một thư mục không tồn tại cho ra cùng con số 0; phân biệt bằng sự tồn tại của thư mục là phân biệt nhầm thứ.

Tám lần phá, tám lần đỏ. Trong đó **một xác nhận giả bị bắt lại**: fixture `valid` của R-05 ban đầu chỉ *khai báo* method `Publish` chứ không *gọi* nó, nên gỡ bỏ hoàn toàn phần miễn cho code ngoài `modules/` vẫn cho ra một lần chạy xanh — fixture không chạy qua đường nó tưởng mình đang canh.

## Task 14: Checker nhóm SQL — `C-GO-07`, R-02, R-06, R-08, R-09, R-18

- [ ] **Step 1: `C-GO-07` trước tiên** — bốn rule sau phụ thuộc nó, và `EffectiveLevels` sẽ hạ chúng xuống PARTIAL nếu nó đỏ.

Bắt: trong `*_repository.go`, khai `const` gán cho một biểu thức **không phải** `*ast.BasicLit` đơn; hoặc `fmt.Sprintf` có đối số đầu chứa `SELECT`/`INSERT`/`UPDATE`/`DELETE`.

Fixture MUST-FAIL phải có cả hai ca: nối hai hằng, và `fmt.Sprintf`.

- [ ] **Step 2: Bốn checker SQL còn lại**

| Rule | Luồng | Mức |
|---|---|---|
| R-02 | Trích const SQL → parse → lấy định danh sau `FROM`/`JOIN`/`UPDATE`/`INSERT INTO`/`DELETE FROM` → so với `module.yaml.tables` cộng các nhóm mọi module đọc được | FULL, DependsOn `C-GO-07` |
| R-06 | Migration: `CREATE TABLE` thiếu `company_id` mà bảng không thuộc `system_tables`/`reference_tables`/`tenant_root`. Repository: câu `SELECT` thiếu `company_id = $`, hoặc không có `WHERE` nào. DTO: field tag `json:"company_id"`. Handler: `c.Query("company_id")` | FULL, DependsOn `C-GO-07` |
| R-08 | Tên bảng khớp `^[a-z][a-z0-9_]*s$` hoặc có trong `naming_exempt`; PK `id UUID`; bộ cột đúng nhóm | FULL |
| R-09 | Mọi FK khác `company_id` là cột dẫn đầu một index hoặc cột thứ hai trong index bắt đầu bằng `company_id`; comment miễn đúng mẫu ASCII `-- index-exempt:` | FULL, DependsOn `C-GO-07` |
| R-18 | `DELETE FROM` bảng nghiệp vụ không kèm `-- hard-delete: ADR-00xx`; `SELECT` thiếu `deleted_at IS NULL` | FULL, DependsOn `C-GO-07` |

- [ ] **Step 3: Chạy `TestDependencyDowngrade` mở rộng**

Sau khi có `C-GO-07` thật, thêm một subtest dùng fixture SQL nối chuỗi thật và khẳng định R-02 báo "không kết luận được".

## Task 15: Checker còn lại — R-07, R-10, R-12, R-13, R-17

| Rule | Cơ chế | Mức | Ghi chú |
|---|---|---|---|
| R-07 | FS: mỗi migration có cặp `.up.sql`/`.down.sql`. SCAN: `CREATE TABLE` ngoài `migrations/`. GIT: file trong `migrations/` bị sửa so với base ref | PARTIAL | Vế GIT **chỉ chạy trong CI**; ghi rõ trong `Unverifiable` |
| R-10 | Route có segment nguyên vẹn khớp `^(get\|create\|update\|delete\|list\|fetch\|save\|send\|check\|do)([A-Z_-]\w*)?$` — **không** dùng cờ `(?i)` | PARTIAL | Fixture MUST-PASS **bắt buộc** có `/documents`, `/checklists`, `/price-lists` — đây chính là ca đã từng bị bắt oan |
| R-12 | Struct bind query thiếu tag `form:"page"`/`form:"page_size"`/`form:"sort"`; biến `sort` đi vào SQL qua nối chuỗi | PARTIAL | Vế "trả mảng trần" cần type info |
| R-13 | Route đăng ký ngoài group `/api/v1`, trừ `/health`, `/ready`, `/metrics` | PARTIAL | Vế so sánh DTO giữa hai phiên bản cần GIT |
| R-17 | Migration thiếu `created_by`/`updated_by`; method service/repository tham số đầu không phải `ctx`; handler không truyền `c.Request.Context()`; handler gọi logger toàn cục | PARTIAL | Vế *"mọi thao tác ghi sinh audit"* **không kiểm được** — audit bọc qua helper hay wrapper là mù. Ghi vào `Unverifiable` |

- [ ] **Step cuối: sinh lại README và commit**

Run: `cd arch && go generate ./... && cd .. && go test ./arch/... -v`
Expected: `arch/README.md` có đủ 19 dòng, cột `Dependency` điền cho R-02/R-06/R-09/R-18.

---

# PHASE 6 — CI

## Task 16: Workflow và kiểm định nghĩa hoàn thành

**Files:**
- Create: `.github/workflows/ci.yml`

- [ ] **Step 1: Viết workflow**

```yaml
name: CI
on:
  pull_request:
  push:
    branches: [main]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with: { go-version: '1.26' }
      # Mot lenh chu khong phai hai: gofmt -l LIET KE file sai dinh dang roi THOAT VOI
      # MA 0, nen no phai duoc doc dau ra chu khong doc ma thoat. Logic do nam trong
      # cmd/dev va co test canh; viet lai o day la co hai ban de lech nhau.
      - run: go run ./cmd/dev lint

  arch:
    runs-on: ubuntu-latest
    steps:
      # fetch-depth 0 vi ve "khong sua migration da merge" cua R-07 phai so voi
      # base ref cua PR.
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - uses: actions/setup-go@v5
        with: { go-version: '1.26' }
      # Job nay CO Y khong dung Docker: rule phai duoc canh ke ca khi Docker hong.
      # cmd/dev arch in ca arch/LEVELS.md sau khi chay - package list mode vut bo dau ra
      # cua binary khi package xanh, nen khong in tay thi bang muc khong den duoc log CI.
      - run: go run ./cmd/dev arch

  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with: { go-version: '1.26' }
      # KHONG set TEST_DATABASE_URL o day. Lenh duoi goi harness tu dung container,
      # nho vay duong MAC DINH duoc chay moi PR nen no khong muc. Co checker
      # (checkCINoTestDBURL) canh chinh dieu nay.
      - run: go run ./cmd/dev test
```

- [ ] **Step 2: Chạy checker `checkCINoTestDBURL` trên workflow vừa viết**

Run: `go test ./arch/... -run TestProductionCode/CI`
Expected: xanh — job `test` không có `TEST_DATABASE_URL` trong `env`.

- [ ] **Step 3: Kiểm định nghĩa hoàn thành**

Chạy lần lượt và dán output:

```powershell
cd "d:\My project web\erp\backend-erp"
go run ./cmd/dev lint   # xanh
go run ./cmd/dev arch   # xanh, va in bang muc thuc te
go run ./cmd/dev test   # xanh
```

Rồi tắt Docker và chạy lại `go test ./arch/...` — phải vẫn xanh.

- [ ] **Step 4: Commit**

---

### ⏸ CHECKPOINT PHASE 6 — Định nghĩa hoàn thành

Đối chiếu mục 10 của spec, từng dòng:

**`docs-erp`:** `tenant_root` vào mệnh đề của R-08/R-17/R-18 (không chỉ Ngoại lệ); registry ở `C-DB-04` với trường `adr`; `system_actor_id`; `C-GO-07`; ngoại lệ bootstrap của R-17; `created_by`/`updated_by` không FK; `check-ids.ps1` xanh và kiểm được `adr`.

**`backend-erp`:** build/vet/gofmt sạch; `/health` 200 và `/ready` **503 khi DB chết**, kiểm bằng test; `migrate up`/`down` chạy được; `go test ./...` xanh; `go test ./arch/...` xanh **khi Docker tắt**; mỗi checker có ≥1 fixture MUST-FAIL và ≥1 MUST-PASS; không rule nào FULL chỉ vì chạy trên tập rỗng; `arch/README.md` sinh bằng `go generate`; `TestDependencyDowngrade` xanh; ba checker hạ tầng test xanh; CI ba job; `go run ./cmd/dev clean-test-db` chạy được.

---

## Nợ để lại sau plan này

| Nợ | Chặng |
|---|---|
| R-05 vế "outbox trong cùng transaction" — cần data-flow analysis | Cân nhắc lại ở chặng C |
| R-13 vế so sánh DTO giữa hai phiên bản | Khi có `/api/v2` đầu tiên |
| R-12, R-16 các vế cần type info | Cân nhắc chế độ type-check chạy riêng trên code thật |
| R-19 và toàn bộ checker frontend | Chặng frontend |
| `document_counters` chưa phân nhóm | Khi module đầu tiên cần cấp số chứng từ |

---

# Phụ lục A — Bốn task sửa nền, chèn TRƯỚC Task 12

Một audit độc lập sau Phase 3 tìm ra rằng bộ máy `arch/` **chưa an toàn để thêm 15 checker**. Các lỗ hổng cùng một họ: **cơ chế bảo vệ bị vô hiệu hóa thì không có gì đỏ**. Bằng chứng thực nghiệm:

| Thí nghiệm | Kết quả |
|---|---|
| Xóa `Scope` khỏi TI-01 và TI-02 | Hai checker mù hoàn toàn — toàn suite vẫn xanh |
| Gõ sai `Roots` của `ProductionScope` | Nạp 0 file, ba rule chạy trên tập rỗng — xanh |
| Checker cross-file đúng + fixture đúng 2 file | Đỏ oan, vì `TestFixtures` gọi `Check` từng file một |
| Đặt `module.yaml` vào thư mục fixture | Bị loại im lặng |
| Quên khai R-10 vào `rules` | Không gì xảy ra |

## Nguyên tắc bổ sung

> **Mọi cơ chế bảo vệ phải có một test chứng minh rằng khi cơ chế đó bị vô hiệu hóa, có thứ gì đó đỏ.**

Nguyên tắc cũ chỉ áp cho *checker*; nó không áp cho *cơ chế đỡ checker*. Đó là chỗ trống mà cả năm thí nghiệm trên chui qua.

## Task 11b — Nền fixture

1. **Đơn vị fixture đổi từ file sang case-directory**: `testdata/<rule>/violation_<ten>/` và `valid_<ten>/`; mọi file trong một case nạp chung rồi gọi `r.Check(files)` **một lần**. File `.go` phẳng ở gốc vẫn là case một-file — giữ tương thích, không rule nào mất chiều kiểm.
2. **Siết thêm cho case cross-file**: bỏ bớt bất kỳ file nào khỏi case `violation_*` thì Finding phải biến mất. Nếu không, case đó không thật sự cross-file và checker đang kết luận từ ít thông tin hơn nó khai.
3. **Loader nhận `.yaml`/`.yml`/`.sql`** dưới dạng `RawFile{Path, Name, Bytes}`. File có đuôi mà không loader nào nhận, nằm trong thư mục case → **đỏ**. Hố im lặng hiện tại phải thành lỗi.
4. **`TestFixtures` chạy fixture qua `r.scope()`**: fixture `violation_*` bị chính scope của rule loại ra → đỏ với thông điệp *"rule khai Scope không chứa loại file mà fixture của nó mô tả"*.
5. **Mọi `Scope` có test hợp đồng với khẳng định DƯƠNG**: `len(files) > 0`, và ít nhất một file thuộc mỗi root khai báo. `TestProductionScopeExcludesArch` hiện chỉ có khẳng định phủ định nên tập rỗng cũng đậu.
6. **`loader.Load` chế độ nghiêm**: root khai trong `Roots` mà không tồn tại → lỗi, trừ khi khai `Optional` (dành cho `modules/` ở chặng A).
7. **`arch/internal/loader` phải có test riêng** — hiện 0 test, trong khi nó là nền của mọi checker: `//arch:path`, `excluded()`, và nhánh "root thiếu thì bỏ qua".
8. `TestFixtureLineFilled` kiểm thêm `fd.File` trỏ đúng file trong case và `fd.Msg` mở đầu bằng `<rule ID>:`.

## Task 11c — Nền khai báo

1. **Song ánh `rules` ↔ `RULES.md`**: test đọc `docs-erp/01-rules/RULES.md`, trích mọi `### R-NN`, và đòi mỗi ID có mặt trong `rules` — dù chỉ `Level: NA` kèm lý do. ID trong `rules` không có trong `RULES.md` và không thuộc họ `TI-` → đỏ. Dùng `registry.FindDocsRoot()`, **không `t.Skip`**.
2. **`DependsOn` phải giải được**: mỗi ID hoặc là Rule trong `rules`, hoặc có tên trong `knownPrerequisites` khai tường minh kèm nguồn. ID không giải được → **đỏ**, không phải hạ mức im lặng.
3. **`passed` phải nhận được kết quả của checker convention**. Hiện `C-GO-07` không bao giờ vào `passed`, nên mọi rule phụ thuộc nó sẽ **vĩnh viễn PARTIAL kể cả sau khi nó được enforce** — trái hẳn điều `README.md` đang hứa.
4. **Chu trình phụ thuộc → đỏ** ở `TestRuleDeclaration`. Hiện `A→B→A` và `C→C` đều tự chứng nhận FULL.
5. **Bỏ `NoGoFixture`** sau khi loader nhận file khác `.go`. Nó là cửa thoát gỡ rule khỏi toàn bộ cơ chế chứng minh mà không test nào đỏ.
6. **Bảng mức thực tế phải hiện ra**: `t.Logf` chỉ hiện khi có `-v`, mà `make arch` không có. Ghi ra `os.Stderr` hoặc thêm `-v`. Và **`t.Errorf` khi một rule khai FULL bị hạ mức** — im lặng hạ mức đúng là thứ bảng này sinh ra để chống.

## Task 11d — Sửa ba chỗ đang nói quá về mức bảo vệ

1. **TI-01/TI-02 khai FULL nhưng mù** `dockertest`, `moby/moby/client`, alias của `os/exec`, và `sh -c "docker run"`. Chính `internal/testharness` đang import moby client. Hoặc mở rộng (danh sách chuỗi cho TI-01; giải alias từ `f.AST.Imports` và quét mọi đối số literal cho TI-02), hoặc hạ PARTIAL với `Unverifiable` ghi đúng ba đường vòng.
2. **TI-03 chỉ soi job tên `test`**. `env:` ở cấp workflow — cách tự nhiên nhất để set biến toàn cục trong Actions — mù hoàn toàn. Tệ hơn: `TestCINoTestDBURL` có case *"workflow không có job test"* với `wantHit: false`, tức **lỗ hổng đang được đóng đinh vào test như hành vi đúng**. Sửa cả checker lẫn case đó, và đổi thông điệp của `TestCIWorkflowUnverifiableStaysHonest` để nó không ép over-claim.
3. **R-03 phụ thuộc hoàn toàn tên file** — đổi `order_repository.go` thành `postgres.go` là thoát cả ba vế. Khớp theo **cả** segment thư mục (`internal/repository/`, `internal/handler/`, `internal/service/`) lẫn hậu tố; bổ sung vế này vào `Unverifiable` cho tới khi có checker canh quy ước đặt tên.
4. **R-04 dùng `strings.Contains`** nên bắt oan `github.com/acme/erp/modules/util`. Dùng lại `splitModuleImport` vốn đã có `HasPrefix` đúng, và thêm fixture `valid_*` cho ca này.
5. **`checkCINoTestDBURL` nuốt mọi lỗi đọc**: `return nil` bắt cả lỗi quyền, không chỉ `NotExist`. Dùng `registry.RepoRoot()` thay đường dẫn tương đối cứng, và phân biệt hai loại lỗi.

## Task 11e — Thay `Makefile` bằng `cmd/dev`

`make` không có trên máy dev Windows, nên `make test` trong `CLAUDE.md` và `Makefile` là lệnh không chạy được — CI Ubuntu thì có. Hai đường khác nhau giữa dev và CI là chỗ lệch sẽ lớn dần.

Viết `cmd/dev` bằng Go: một nguồn duy nhất, chạy mọi nơi, không cần công cụ ngoài. Các lệnh con: `dev`, `test`, `arch`, `lint`, `check`, `migrate-up`, `migrate-down`, `clean-test-db`. Xóa `Makefile`, cập nhật `CLAUDE.md` và CI.

### Đã chạy — và bịt thêm sáu chỗ mà việc đọc kỹ `Makefile` làm lộ ra

1. **`gofmt -l .` thoát với mã 0 kể cả khi có file sai định dạng.** Kiểm chứng bằng thực nghiệm. Nghĩa là `make lint` chưa bao giờ đỏ vì định dạng — nó in tên file rồi đi tiếp. `cmd/dev lint` đọc **đầu ra** chứ không đọc mã thoát, và `TestKiemGofmt` chạy `gofmt` thật theo cả hai chiều.
2. **`migrate -path ... up` đòi một binary không repo nào khai.** Đúng căn bệnh của `make`. Thay bằng thư viện: `internal/migrator`, dùng chung giữa `cmd/dev` và `internal/testharness` — nên cái bẫy `m.Close()` chỉ còn một chỗ để nhớ.
3. **`migrator.Down` là code mới và là đường xóa dữ liệu.** `m.Down()` lùi *hết*, `m.Steps(-n)` lùi *n*. Test đầu tiên chạy trên `migrations/` thật thì **xanh nhưng vô nghĩa** — repo mới có một migration nên hai hành vi trùng nhau. Bản hiện tại dựng thư mục hai migration để phân biệt được, và đã kiểm chứng: đổi sang `m.Down()` thì đỏ.
4. **`arch/LEVELS.md` in ra bằng lệnh riêng.** `go test ./arch/...` là package list mode nên nó vứt đầu ra của binary khi package xanh.
5. **TI-02 nhận đúng một ngoại lệ: `cmd/dev`, file không phải `_test.go`** — lệnh `dev` phải dựng ngăn xếp dev bằng `docker compose`. Ngoại lệ không lan được vì `cmd/dev` là `package main` nên không package test nào import được nó; `TestCmdDevLaPackageMain` canh chính tiền đề đó. Ba fixture canh ba lớp của ngoại lệ.
6. **TI-03 mất mỏ neo `make test`, nên nó được siết thay vì chỉ đổi tên**: dấu hiệu job chạy test giờ gồm cả `go test` trần — hình dạng của việc đi vòng qua harness mà bản cũ chỉ bắt được nếu job tình cờ mang tên `test`.

Thêm một chiều kiểm mới: **`TestLenhKhopCLAUDEmd`** đối chiếu bảng lệnh trong `CLAUDE.md` với bảng lệnh thật theo cả hai chiều. Chính vì không có nó mà `make test` nằm trong `CLAUDE.md` suốt nhiều task mà không gì kêu.

## Task 16 nhận thêm

1. **Ghim phiên bản `docs-erp`**: băm nội dung từng mục `### R-NN` của `RULES.md`, so với bảng băm ghim trong `rules.go`. Mục nào đổi băm thì rule tương ứng đỏ với thông điệp *"mệnh đề nguồn đã đổi, đọc lại và cập nhật hoặc ghim lại"*. Đây là cách duy nhất biến *"docs-erp là nguồn sự thật"* thành thứ máy kiểm được thay vì một câu trong comment.
2. **`go generate && git diff --exit-code`** để `README.md` không lệch khỏi `rules.go`.
3. CI **phải checkout cả `docs-erp`** — registry loader và test song ánh đều đọc từ đó.
