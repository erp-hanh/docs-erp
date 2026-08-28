# Kế hoạch thi công: `go run ./cmd/dev new-resource`

> **Cho agent thi công:** dùng `superpowers:subagent-driven-development`. Mỗi task một
> subagent mới. Bước đánh dấu bằng `- [ ]`.

**Mục tiêu:** sinh phần cơ học của một tài nguyên CRUD một bảng trong module đã có - 8 file
mới, 6 sổ đăng ký được vá - từ một file khai báo YAML dùng một lần.

**Kiến trúc:** một lệnh con của `cmd/dev` (package `main`, cùng lối với `seed_roles.go`).
Khai báo YAML đọc bằng `gopkg.in/yaml.v3` (đã là dependency trực tiếp). Template là file
`.tmpl` nhúng bằng `//go:embed`. Vá sổ đăng ký bằng **neo văn bản**, không sửa AST.

**Ngăn xếp:** Go 1.26, `text/template`, `embed`, `gopkg.in/yaml.v3`, `go/parser`, `go/format`.

**Thiết kế:** `docs-erp/99-meta/my-specs/2026-08-28-new-resource-generator-design.md`

**Nguồn khuôn mẫu** - mọi template lấy hình dạng từ vertical slice `warehouses`:

| Tầng | File nguồn |
|---|---|
| migration | `migrations/000015_create_warehouses.{up,down}.sql` |
| model | `modules/inventory/internal/model/warehouse.go` |
| repository | `modules/inventory/internal/repository/warehouse_repository.go` |
| scope source | `modules/inventory/internal/repository/warehouse_scope_source.go` |
| service | `modules/inventory/internal/service/warehouse_service.go` |
| handler | `modules/inventory/internal/handler/warehouse_handler.go` |
| routes | `modules/inventory/internal/handler/warehouse_routes.go` |
| test | `modules/inventory/internal/{repository,service,handler}/warehouse_*_test.go` |

---

## Bố cục file

**Tạo mới trong `cmd/dev/`:**

| File | Trách nhiệm |
|---|---|
| `newresource_khai.go` | đọc + kiểm + suy tên từ YAML. Không biết gì về template. |
| `newresource_sinh.go` | chạy template ra `map[đường dẫn]nội dung`. Không ghi đĩa. |
| `newresource_va.go` | vá 6 sổ đăng ký theo neo. Không biết gì về template. |
| `newresource.go` | lệnh con: đọc khai -> sinh -> vá -> ghi đĩa. |
| `templates/*.tmpl` | 11 template, nhúng bằng `//go:embed`. |

Ba file đầu **thuần hàm** (vào chuỗi, ra chuỗi, không chạm đĩa) nên test được không cần
thư mục tạm. Chỉ `newresource.go` chạm filesystem.

**Sửa:** `cmd/dev/commands.go`, `backend-erp/CLAUDE.md`, và 6 sổ đăng ký (thêm dòng neo).

---

## Task 1: Khai báo và suy tên

**Files:**
- Create: `cmd/dev/newresource_khai.go`
- Test: `cmd/dev/newresource_khai_test.go`

Kiểu dữ liệu - **mọi task sau dùng đúng tên trường này**:

```go
type khaiTaiNguyen struct {
	Module   string     `yaml:"module"`
	Resource string     `yaml:"resource"` // so it, snake_case: supplier
	Table    string     `yaml:"table"`    // so nhieu, snake_case: suppliers
	DoiTuong string     `yaml:"doi_tuong"`
	Fields   []khaiCot  `yaml:"fields"`
	Sort     []string   `yaml:"sort"`
	Filter   []string   `yaml:"filter"`
	Scope    *khaiScope `yaml:"scope"`
}

type khaiCot struct {
	Name              string `yaml:"name"`
	Type              string `yaml:"type"` // text, int, numeric, bool, uuid
	Nullable          bool   `yaml:"nullable"`
	Default           string `yaml:"default"`
	UniqueTrongCongTy bool   `yaml:"unique_trong_cong_ty"`
}

type khaiScope struct {
	Column string `yaml:"column"`
}

// taiNguyen la khai bao DA suy ra du ten. Template chi doc kieu nay.
type taiNguyen struct {
	khaiTaiNguyen
	Go          string // Supplier
	PermTienTo  string // Supplier  -> PermSupplierList
	PermChuoi   string // inventory.supplier -> "inventory.supplier_list"
	SoMigration string // 000033
	TenRangBuoc string // uq_suppliers_company_id_code (rong neu khong co cot unique)
	TenIndex    string // idx_suppliers_company_id_created_at
	Cot         []cot
}

type cot struct {
	khaiCot
	GoTen  string // Code
	GoKieu string // string, *string, int64, decimal.Decimal, bool
	SQLKieu string // TEXT, BIGINT, NUMERIC(18,4), BOOLEAN, UUID
}
```

- [ ] **Bước 1: viết test đỏ** cho `docKhai([]byte, soMigrationKeTiep string) (taiNguyen, error)`:

```go
func TestDocKhaiSuyDungTen(t *testing.T) {
	y := []byte("module: inventory\nresource: supplier\ntable: suppliers\ndoi_tuong: Nha cung cap\n" +
		"fields:\n  - {name: code, type: text, unique_trong_cong_ty: true}\n  - {name: note, type: text, nullable: true}\n" +
		"sort: [created_at, code]\nfilter: [code]\n")
	tn, err := docKhai(y, "000033")
	if err != nil {
		t.Fatalf("docKhai: %v", err)
	}
	if tn.Go != "Supplier" || tn.PermChuoi != "inventory.supplier" {
		t.Fatalf("suy ten sai: %+v", tn)
	}
	if tn.TenRangBuoc != "uq_suppliers_company_id_code" {
		t.Fatalf("ten rang buoc sai: %q", tn.TenRangBuoc)
	}
	if tn.TenIndex != "idx_suppliers_company_id_created_at" {
		t.Fatalf("ten index sai: %q", tn.TenIndex)
	}
	if tn.Cot[1].GoKieu != "*string" {
		t.Fatalf("cot nullable phai ra con tro, duoc %q", tn.Cot[1].GoKieu)
	}
}
```

Thêm test bảng cho `kiemKhai`, mỗi ca một dòng, mỗi ca phải ĐỎ với một thông điệp nói
đúng việc phải sửa:

| Ca | Thông điệp mong đợi chứa |
|---|---|
| `resource` rỗng | `thieu resource` |
| `table` không kết thúc bằng `s` | `R-08` |
| `table` không snake_case | `C-DB-01` |
| `fields` rỗng | `khong co cot nghiep vu nao` |
| cột tên `id`/`company_id`/`created_at`/`deleted_at`/`created_by` | `cot chuan, khong khai lai` |
| `type` ngoài 5 kiểu | `kieu khong ho tro` |
| `sort` chứa tên không có trong `fields` và không phải `created_at` | `khong co cot` |
| `filter` chứa tên không có trong `fields` | `khong co cot` |
| >1 cột `unique_trong_cong_ty` | `chi mot cot` |
| `scope.column` không có trong `fields` và khác `id` | `khong co cot` |

- [ ] **Bước 2:** `go test ./cmd/dev -run TestDocKhai -v` -> ĐỎ, `undefined: docKhai`.
- [ ] **Bước 3: viết `newresource_khai.go`.** Bảng ánh xạ kiểu:

| YAML | SQL | Go (not null) | Go (nullable) |
|---|---|---|---|
| `text` | `TEXT` | `string` | `*string` |
| `int` | `BIGINT` | `int64` | `*int64` |
| `numeric` | `NUMERIC(18,4)` | `decimal.Decimal` | `*decimal.Decimal` |
| `bool` | `BOOLEAN` | `bool` | `*bool` |
| `uuid` | `UUID` | `string` | `*string` |

`Go` = PascalCase của `Resource`. `PermTienTo` = `Go`. `PermChuoi` = `Module + "." + Resource`.
`TenRangBuoc` = `uq_<table>_company_id_<cot unique>`, rỗng nếu không có cột unique.
`TenIndex` = `idx_<table>_company_id_created_at`.

- [ ] **Bước 4:** `go test ./cmd/dev -run TestDocKhai -v` -> XANH.
- [ ] **Bước 5:** commit `feat(dev): doc va kiem khai bao new-resource`.

---

## Task 2: Lệnh con và bảng lệnh

**Files:**
- Create: `cmd/dev/newresource.go`
- Modify: `cmd/dev/commands.go` (bảng `lenhs`), `backend-erp/CLAUDE.md` (bảng "Lệnh hay dùng")

- [ ] **Bước 1: chạy test bảng lệnh trước khi sửa** để thấy nó thật sự canh hai chiều:
  `go test ./cmd/dev -run TestLenhKhopCLAUDEmd -v` -> XANH.
- [ ] **Bước 2:** thêm vào `lenhs` trong `cmd/dev/commands.go`, ngay sau dòng `seed-roles`:

```go
{"new-resource", "Sinh khung mot tai nguyen CRUD tu file khai bao", chayNewResource},
```

- [ ] **Bước 3:** `go test ./cmd/dev -run TestLenhKhopCLAUDEmd -v` -> ĐỎ, vì `CLAUDE.md`
  chưa có dòng đó. Đây là bằng chứng test canh thật.
- [ ] **Bước 4:** thêm dòng cuối bảng "Lệnh hay dùng" của `backend-erp/CLAUDE.md`:

```
| Sinh khung một tài nguyên CRUD từ file khai báo | `go run ./cmd/dev new-resource -spec <file>.yaml` |
```

Chuỗi trong cột đầu của bảng CLAUDE.md phải khớp **từng ký tự** với trường `Tom` ở bước 2
nếu test so cả mô tả; nếu test chỉ so tên lệnh thì mô tả tự do. Đọc
`cmd/dev/main_test.go` trước khi viết để biết nó so cái gì.

- [ ] **Bước 5:** viết `chayNewResource(root string, args []string) int` trong
  `newresource.go`: đọc cờ `-spec` (bắt buộc) và `-dry-run`, đọc file, tính số migration kế
  tiếp bằng cách quét `migrations/*.up.sql` lấy tiền tố số lớn nhất + 1 (định dạng `%06d`),
  gọi `docKhai`, rồi tạm thời in danh sách file sẽ sinh. Thiếu `-spec` thì trả 2 và in
  cách dùng.
- [ ] **Bước 6:** `go test ./cmd/dev -v` -> XANH toàn bộ.
- [ ] **Bước 7:** commit `feat(dev): them lenh new-resource vao bang lenh`.

---

## Task 3: Template migration + model

**Files:**
- Create: `cmd/dev/templates/migration_up.sql.tmpl`, `migration_down.sql.tmpl`, `model.go.tmpl`
- Modify: `cmd/dev/newresource_sinh.go` (tạo mới ở task này)
- Test: `cmd/dev/newresource_sinh_test.go`

**Đọc trước khi viết:** `migrations/000015_create_warehouses.up.sql` và
`modules/inventory/internal/model/warehouse.go`. Giữ nguyên thứ tự cột của C-DB-03:
`id -> company_id -> khóa ngoại -> cột nghiệp vụ -> cột thời gian -> cột audit`.

Comment sinh ra chỉ mô tả **cơ chế** kèm ID rule, không viết lập luận. Migration mang đúng
một marker:

```sql
-- TODO(new-resource): ghi ra cot nao CO Y khong index va vi sao (R-09).
```

- [ ] **Bước 1: viết test đỏ** - `sinh(tn taiNguyen) (map[string]string, error)` với khai báo
  `supplier` ở Task 1 phải cho ra khóa
  `migrations/000033_create_suppliers.up.sql` chứa `CREATE TABLE suppliers`,
  `company_id UUID        NOT NULL REFERENCES companies(id)`,
  `CREATE UNIQUE INDEX uq_suppliers_company_id_code`, `WHERE deleted_at IS NULL`, và
  `CREATE INDEX idx_suppliers_company_id_created_at`; file `.down.sql` chứa
  `DROP TABLE IF EXISTS suppliers`.
- [ ] **Bước 2:** `go test ./cmd/dev -run TestSinhMigration -v` -> ĐỎ.
- [ ] **Bước 3:** viết `newresource_sinh.go` (embed + chạy template) và ba template.
- [ ] **Bước 4:** `go test ./cmd/dev -run TestSinh -v` -> XANH.
- [ ] **Bước 5:** commit `feat(dev): template migration va model`.

---

## Task 4: Template repository

**Files:**
- Create: `cmd/dev/templates/repository.go.tmpl`, `scope_source.go.tmpl`
- Test: thêm vào `cmd/dev/newresource_sinh_test.go`

**Đọc trước khi viết:** `modules/inventory/internal/repository/warehouse_repository.go` và
`warehouse_scope_source.go`.

Năm câu SQL đều là **hằng chuỗi đơn** (C-GO-07), mỗi câu mang `company_id = $n`
(R-06) và `deleted_at IS NULL` (R-18). `List` có `LIMIT/OFFSET` và `ORDER BY` chỉ nhận cột
trong whitelist sinh từ `tn.Sort`, luôn kèm tie-breaker `, id` (R-12). `scope_source.go.tmpl`
chỉ sinh khi `tn.Scope != nil`.

- [ ] **Bước 1:** viết test đỏ - file repository sinh ra phải chứa `WHERE company_id = $1 AND deleted_at IS NULL`,
  whitelist sort là một `map[string]string` chứa đúng các khóa trong `tn.Sort`, và
  `ORDER BY` kết thúc bằng `, id`. Thêm ca: khai báo không có `scope` thì **không** có
  khóa `..._scope_source.go` trong map trả về.
- [ ] **Bước 2:** chạy -> ĐỎ.
- [ ] **Bước 3:** viết hai template.
- [ ] **Bước 4:** chạy -> XANH.
- [ ] **Bước 5:** commit `feat(dev): template repository`.

---

## Task 5: Template service

**Files:**
- Create: `cmd/dev/templates/service.go.tmpl`
- Test: thêm vào `cmd/dev/newresource_sinh_test.go`

**Đọc trước khi viết:** `modules/inventory/internal/service/warehouse_service.go`.

Mỗi method public mở đầu bằng **đúng một** lời gọi `s.Authz.Can(...)` là câu lệnh đầu tiên
của thân hàm (R-15) - không dòng nào đứng trước, kể cả kiểm định dạng UUID. Ghi audit trong
cùng transaction (R-17). Dịch lỗi qua `dichLoiGhi` (P-ERR). Không method nào hard-delete.

- [ ] **Bước 1:** viết test đỏ - dùng `go/parser` phân tích file service sinh ra, khẳng định
  với **mọi** method public, `Body.List[0]` là một `IfStmt` có điều kiện gọi `.Can(`. Test
  này bắt đúng cái R-15 bắt, nên nó không đỏ oan khi template đổi cách viết.
- [ ] **Bước 2:** chạy -> ĐỎ.
- [ ] **Bước 3:** viết template.
- [ ] **Bước 4:** chạy -> XANH.
- [ ] **Bước 5:** commit `feat(dev): template service`.

---

## Task 6: Template handler + routes

**Files:**
- Create: `cmd/dev/templates/handler.go.tmpl`, `routes.go.tmpl`
- Test: thêm vào `cmd/dev/newresource_sinh_test.go`

**Đọc trước khi viết:** `warehouse_handler.go` và `warehouse_routes.go`.

DTO ở lại package `handler` (C-GO-02). Năm route theo dạng tài nguyên của C-API-01: danh từ
số nhiều, không động từ trong path, param luôn tên `:id`. **Không** tự thêm group
`/api/v1` (R-13). Cả năm route mang `xacThuc`.

- [ ] **Bước 1:** viết test đỏ - file routes sinh ra chứa đúng năm dòng
  `v1.GET("/suppliers", xacThuc, h.List)` ... `v1.DELETE("/suppliers/:id", xacThuc, h.Delete)`,
  và **không** chứa chuỗi `/api/v1`.
- [ ] **Bước 2:** chạy -> ĐỎ.
- [ ] **Bước 3:** viết hai template.
- [ ] **Bước 4:** chạy -> XANH.
- [ ] **Bước 5:** commit `feat(dev): template handler va routes`.

---

## Task 7: Template test

**Files:**
- Create: `cmd/dev/templates/repository_test.go.tmpl`, `service_test.go.tmpl`, `handler_test.go.tmpl`
- Test: thêm vào `cmd/dev/newresource_sinh_test.go`

**Đọc trước khi viết:** ba file `warehouse_*_test.go`.

Bộ ca cố định cho mọi tài nguyên CRUD, sinh đủ, không để trống thân hàm:

| Tầng | Ca |
|---|---|
| handler | 401 không token, 403 thiếu quyền, 404 id sai định dạng, 422 body sai hình dạng, 200 đường thuận |
| service | 403 `Authz.Can` từ chối, 404 bản ghi công ty khác, 409 trùng mã (nếu có cột unique), audit được ghi trong cùng tx |
| repository | List phân trang, List sort ngoài whitelist bị từ chối, Get bản ghi đã xóa mềm trả không thấy, Update chạm đúng một hàng |

- [ ] **Bước 1:** viết test đỏ - ba file test sinh ra phải qua `go/parser`, và số hàm
  `func Test` trong mỗi file phải khớp bảng trên.
- [ ] **Bước 2:** chạy -> ĐỎ.
- [ ] **Bước 3:** viết ba template.
- [ ] **Bước 4:** chạy -> XANH.
- [ ] **Bước 5:** commit `feat(dev): template test`.

---

## Task 8: Vá sổ đăng ký

**Files:**
- Create: `cmd/dev/newresource_va.go`, `cmd/dev/newresource_va_test.go`
- Modify: 6 sổ đăng ký, mỗi file thêm **một** dòng neo

Neo là một comment đặt ở **cuối** khối cần chèn thêm:

| Sổ | Neo | Chèn gì |
|---|---|---|
| `modules/<m>/internal/service/permissions.go` | `// new-resource: hang permission` | 5 hằng `Perm<X>*` |
| `modules/<m>/internal/service/errors.go` | `// new-resource: ten rang buoc` | hằng tên constraint + nhánh `case` trong `dichTrungKhoa` (neo thứ hai `// new-resource: nhanh dich trung khoa`) |
| `modules/<m>/module.go` | `// new-resource: cua ra permission` | khối `const Perm* = service.Perm*` |
| `modules/<m>/module.go` | `// new-resource: moi quyen` | các dòng trong `MoiQuyen()` |
| `modules/<m>/module.yaml` | `# new-resource: bang` | tên bảng dưới `tables:` |
| `cmd/internal/vaitro/vaitro.go` | `// new-resource: cap quyen` | dòng cấp quyền + marker TODO |

Hàm thuần: `va(noiDung string, neo string, themVao string) (string, error)`. Không thấy neo
thì trả lỗi nói **đúng file và đúng chuỗi neo phải thêm** - không đoán vị trí, không chèn
vào cuối file.

- [ ] **Bước 1:** viết test đỏ cho `va`: chèn đúng ngay trên dòng neo giữ nguyên thụt lề của
  neo; gọi hai lần với cùng nội dung thì lần hai trả lỗi `da co` (chống chèn trùng); neo
  không tồn tại trả lỗi chứa cả tên file lẫn chuỗi neo.
- [ ] **Bước 2:** chạy -> ĐỎ.
- [ ] **Bước 3:** viết `newresource_va.go`.
- [ ] **Bước 4:** chạy -> XANH.
- [ ] **Bước 5:** thêm 7 dòng neo vào 6 file sổ đăng ký. Đây là thay đổi **một lần**.
- [ ] **Bước 6:** `go run ./cmd/dev check` -> XANH (neo chỉ là comment, không đổi hành vi).
- [ ] **Bước 7:** commit `feat(dev): va so dang ky theo neo van ban`.

---

## Task 9: Nối dây và ba lớp bằng chứng

**Files:**
- Modify: `cmd/dev/newresource.go`
- Create: `cmd/dev/testdata/newresource/supplier.yaml`, `cmd/dev/testdata/newresource/golden/**`
- Test: `cmd/dev/newresource_test.go`

- [ ] **Bước 1:** nối `chayNewResource`: đọc khai -> `sinh` -> `va` -> ghi đĩa. Ghi đĩa là
  **hành vi tất-cả-hoặc-không-gì**: sinh hết vào bộ nhớ, kiểm không file nào đã tồn tại,
  rồi mới ghi. File đã tồn tại thì dừng và liệt kê, không đè.
- [ ] **Bước 2: lớp 1 - golden test.** `go test ./cmd/dev -run TestNewResourceGolden` sinh
  `supplier.yaml` vào `t.TempDir()` và so từng file với `testdata/newresource/golden/`.
  Thêm cờ `-update` để sinh lại golden, cùng lối với `arch`.
- [ ] **Bước 3: lớp 2 - parse test.** Mọi file `.go` sinh ra phải qua `go/parser` không lỗi,
  và `format.Source` trả về đúng nội dung đã sinh (tức template đã gofmt sẵn).
- [ ] **Bước 4:** `go test ./cmd/dev -v` -> XANH. Commit.
- [ ] **Bước 5: lớp 3 - một lần chạy thật.** Sinh thật vào repo:

```bash
go run ./cmd/dev new-resource -spec cmd/dev/testdata/newresource/supplier.yaml
go run ./cmd/dev check
```

Phải XANH. Đây là bằng chứng duy nhất nói được code sinh ra hợp lệ với cả 19 Rule. Rồi
`go run ./cmd/dev test`.

- [ ] **Bước 6:** hoàn lại thay đổi của bước 5 (`git checkout` + xóa file mới). Ghi kết quả
  hai lệnh vào file bàn giao làm bằng chứng.
- [ ] **Bước 7:** commit `feat(dev): new-resource sinh du mot tai nguyen CRUD`.

---

## Xong khi nào

- `go run ./cmd/dev check` xanh.
- `go run ./cmd/dev test` xanh (lấy bằng chứng từ CI nếu máy không chạy được Docker).
- Sinh thử một tài nguyên vào repo rồi `check` xanh, có log dán vào file bàn giao.
- `TestLenhKhopCLAUDEmd` xanh với dòng mới trong `backend-erp/CLAUDE.md`.
