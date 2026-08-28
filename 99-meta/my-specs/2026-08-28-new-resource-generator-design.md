# Thiết kế: `go run ./cmd/dev new-resource`

Ngày: 2026-08-28. Trạng thái: đã duyệt, chờ thi công.

## 1. Vấn đề

Đo trên `warehouses` (một tài nguyên CRUD một bảng, năm endpoint):

| Hạng mục | Số liệu |
|---|---|
| File tạo mới | 8 |
| File phải sửa | 7 |
| Dòng code sản xuất | ~1.335 |
| Dòng test | ~1.630 |
| Sổ đăng ký phải vá đồng bộ | 6 |

Quên một sổ đăng ký thì CI đỏ, hoặc tệ hơn: quyền im lặng không ai cấp được. Toàn bộ phần
này đang chép tay từ tài nguyên có sẵn - `stock_item_list_page` bên frontend còn ghi thẳng
trong comment "khuôn chép từ WarehouseListPage".

## 2. Phạm vi

Sinh phần **cơ học** của một tài nguyên CRUD một bảng trong một module đã có.

**Ngoài phạm vi:** module mới (đó là `CL-NEWMOD`, một quyết định kiến trúc), nghiệp vụ
phức tạp hơn CRUD (như `stock_movements` với khóa `FOR UPDATE`), và frontend.

## 3. Điều generator KHÔNG làm

Code repo này 30-59% là comment giải trình - `permissions.go` có 135 dòng thì ~110 dòng là
lập luận vì sao tách quyền như vậy, và những dòng đó là tài sản chứ không phải nhiễu.

Generator **không sinh lập luận**. Nó sinh khung có comment mô tả cơ chế (cái gì, chiếu
theo rule nào), và để lại marker `// TODO(new-resource):` ở đúng bốn chỗ luôn cần người
quyết:

1. `module.yaml` - vì sao bảng này thuộc module này
2. `vaitro.go Bang()` - vai trò nào được cấp quyền nào
3. `scoped_tables` - bảng có chịu phạm vi không, theo cột nào
4. Migration - cột nào cố ý không index, vì sao

Marker còn sót lại làm lint đỏ. Sinh xong mà không giải trình là việc chưa xong.

## 4. Đầu vào

Một file YAML **dùng một lần, không commit**:

```yaml
module: inventory
resource: supplier          # số ít, snake_case
table: suppliers            # số nhiều, snake_case (C-DB-01)
doi_tuong: "Nha cung cap"   # dùng trong thông điệp lỗi 404
fields:
  - {name: code, type: text, unique_trong_cong_ty: true}
  - {name: name, type: text}
  - {name: phone, type: text, default: "''"}
  - {name: note, type: text, nullable: true}
sort: [created_at, code]    # whitelist ORDER BY (R-12)
filter: [code]
scope: {column: id}         # tùy chọn (C-GO-09)
```

**Vì sao không commit file này:** hai nguồn sự thật tả cùng một bảng sẽ lệch nhau mà không
báo lỗi ở đâu - đúng lập luận `cmd/dev/commands.go` đã dùng để bỏ `compose.dev.yml` khỏi
repo này. Sau khi sinh, `migration + model` là nguồn sự thật duy nhất.

Số migration tự tính = max hiện có + 1. Không khai trong file.

## 5. Đầu ra

**Sinh mới (8 file):**

```
migrations/NNNNNN_create_<table>.{up,down}.sql
modules/<m>/internal/model/<resource>.go
modules/<m>/internal/repository/<resource>_repository.go
modules/<m>/internal/repository/<resource>_scope_source.go   # chỉ khi có scope
modules/<m>/internal/service/<resource>_service.go
modules/<m>/internal/handler/<resource>_handler.go
modules/<m>/internal/handler/<resource>_routes.go
modules/<m>/internal/{repository,service,handler}/<resource>_*_test.go
```

**Vá (6 sổ đăng ký):**

| Sổ | Vá gì |
|---|---|
| `internal/service/permissions.go` | 5 hằng `Perm<X><Hành động>` |
| `internal/service/errors.go` | tên constraint + nhánh `dichTrungKhoa` |
| `module.go` | khối cửa ra `Perm*`, `MoiQuyen()`, `Deps/New/Register` |
| `module.yaml` | `tables:` + `scoped_tables:` |
| `cmd/internal/vaitro/vaitro.go` | dòng cấp quyền cho từng vai trò |
| `shared/errors/codes.go` | mã lỗi mới, nếu tài nguyên cần |

Vá bằng **neo văn bản** (anchor comment) chứ không sửa AST: mỗi sổ được thêm một dòng neo
`// new-resource: <mục>` một lần, generator chèn ngay trên neo. Thiếu neo thì dừng và nói
rõ phải thêm neo ở đâu, không đoán vị trí.

## 6. Bằng chứng nó đúng

Bộ 19 Rule sẵn có **chính là** bài kiểm cho generator. Code sinh ra qua được R-06
(company_id trong WHERE), R-09 (index-by-design), R-12 (phân trang + whitelist sort), R-15
(câu lệnh đầu là kiểm quyền), R-18 (không hard-delete) thì nó đúng hình dạng.

Ba lớp kiểm, từ rẻ tới đắt:

1. **Golden test trong `cmd/dev`** - sinh một tài nguyên mẫu vào thư mục tạm, so với
   `cmd/dev/testdata/newresource/golden/`. Bắt mọi thay đổi ngoài ý muốn của template.
2. **Parse test** - mọi file `.go` sinh ra phải qua `go/parser` và `gofmt` không đổi. Bắt
   template sinh code không biên dịch được.
3. **Một lần chạy thật** - sinh một tài nguyên vào repo, chạy `go run ./cmd/dev check`
   phải xanh, rồi `go run ./cmd/dev test`. Sau đó hoàn lại. Đây là bằng chứng duy nhất nói
   được code sinh ra hợp lệ với cả 19 Rule.

## 7. Ba việc phụ bắt buộc

- Thêm dòng vào `cmd/dev/commands.go` **và** bảng lệnh trong `backend-erp/CLAUDE.md` -
  `TestLenhKhopCLAUDEmd` đối chiếu hai chiều, thiếu một bên là đỏ.
- Thêm dòng neo `// new-resource:` vào 6 sổ đăng ký (thay đổi một lần, không lặp lại).
- `go run ./cmd/dev arch-update` sau khi thêm file mới vào `arch/`, nếu có.

## 8. Điều đã cân nhắc và bỏ

**Sinh code không cần file spec (chỉ tên tài nguyên).** Bỏ vì phần tốn dòng nhất -
repository 363 dòng, service 462 - hoàn toàn phụ thuộc danh sách cột. Không có cột thì
generator chỉ tiết kiệm được phần khung, tức khoảng một phần tư công.

**Chép thư mục `warehouse` rồi đổi tên định danh.** Bỏ vì nó chép luôn cả lập luận của
`warehouses` sang một bảng có lý do tồn tại khác - và một comment sai chỗ khó gỡ hơn một
comment thiếu.
