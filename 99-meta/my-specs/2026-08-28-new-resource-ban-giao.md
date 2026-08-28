# Bàn giao - 2026-08-28, `dev new-resource` chạy được đầu-cuối

Kế hoạch: `2026-08-28-new-resource-generator-plan.md`. Chín task xong, nhánh
`feat/new-resource-generator` trên cả `backend-erp` lẫn `docs-erp`.

## Dùng thế nào
`go run ./cmd/dev new-resource -spec <file>.yaml [-dry-run]`. Khai báo mẫu dưới đây rút gọn từ
`cmd/dev/testdata/newresource/supplier.yaml` - file đó cũng là đầu vào của test golden:

```yaml
module: inventory
resource: supplier          # số ít, snake_case
table: suppliers            # số nhiều (R-08)
doi_tuong: "Nhà cung cấp"
fields:
  - {name: code, type: text, unique_trong_cong_ty: true}
  - {name: ghi_chu, type: text, nullable: true}
  - {name: han_muc_no, type: numeric, default: "0"}
sort: [code, created_at]
filter: [code]
scope: {column: id}         # tùy chọn
```

Kiểu nhận: `text`, `int`, `numeric`, `bool`, `uuid`; quá một cột `unique_trong_cong_ty` thì lệnh từ chối.

## Sinh ra gì, vá vào đâu
11 file mới - danh sách nằm trong output ở mục dưới; file thứ 11 (`*_scope_source.go`) chỉ
sinh khi có khai `scope`. **5 sổ đăng ký, 8 vị trí neo** - kế hoạch viết "6 sổ", số thật là 5:

| sổ | neo (tiền tố `new-resource:`) |
| --- | --- |
| `modules/<m>/internal/service/permissions.go` | `hang permission` |
| `modules/<m>/internal/service/errors.go` | `ten rang buoc`, `nhanh dich trung khoa` |
| `modules/<m>/module.go` | `cua ra permission`, `moi quyen` |
| `modules/<m>/module.yaml` | `bang`, `bang chiu pham vi` |
| `cmd/internal/vaitro/vaitro.go` | `cap quyen` |

Vá bằng NEO VĂN BẢN chứ không sửa AST: mất neo thì lệnh dừng và nói ra chuỗi neo còn
thiếu, thay vì đoán vị trí rồi ghi ra file vẫn biên dịch được ở chỗ không ai nhìn. Ghi đĩa
là tất-cả-hoặc-không-gì: mọi đường dẫn đích được kiểm là chưa tồn tại TRƯỚC khi byte đầu
tiên chạm đĩa, nên chạy lại trên cây đã sinh thì thoát 1 và không đè gì cả.

## Bằng chứng: ba lệnh chạy thật
```
$ go run ./cmd/dev new-resource -spec cmd/dev/testdata/newresource/supplier.yaml
bang=suppliers go=Supplier migration=000035 so_cot=6
  + migrations/000035_create_suppliers.down.sql
  + migrations/000035_create_suppliers.up.sql
  + modules/inventory/internal/handler/supplier_handler.go
  + modules/inventory/internal/handler/supplier_handler_test.go
  + modules/inventory/internal/handler/supplier_routes.go
  + modules/inventory/internal/model/supplier.go
  + modules/inventory/internal/repository/supplier_repository.go
  + modules/inventory/internal/repository/supplier_repository_test.go
  + modules/inventory/internal/repository/supplier_scope_source.go
  + modules/inventory/internal/service/supplier_service.go
  + modules/inventory/internal/service/supplier_service_test.go
  ~ cmd/internal/vaitro/vaitro.go
  ~ modules/inventory/internal/service/errors.go
  ~ modules/inventory/internal/service/permissions.go
  ~ modules/inventory/module.go
  ~ modules/inventory/module.yaml

da sinh 11 file moi va va 5 so dang ky.
con 10 marker TODO(new-resource) phai xu ly - do la so viec ban con phai lam tay.
tim chung bang: grep -rn "TODO(new-resource)" .

ba viec khong co marker, va bo kiem khong bat duoc:
  1. modules/inventory/module.go: dung repo/service/handler cua supplier trong New va goi RegisterSupplierRoutes trong Routes
  2. cmd/internal/phamvi/phamvi.go: them nguon repository.NewSupplierScopeSource(db) vao Bang
  3. arch/LEVELS.md lech vi so file trong bang doi - doc bang moi bang `go run ./cmd/dev arch` roi sua cho khop

roi chay: go run ./cmd/dev check
```

`go build ./...` - không một dòng ra, mã thoát 0. `go run ./cmd/dev check` - mã thoát 0,
cả 19 rule PASS (`R-19 chua chay` là trạng thái sẵn có).

Lần chạy này bắt một lỗi thật: `importService` thiếu `shopspring/decimal` khi có cột
`numeric`, `go build` đỏ hai dòng `undefined: decimal`. Nó lọt qua cả tám task trước lẫn
hai lớp kiểm rẻ - selector trên tên chưa khai là cú pháp hợp lệ, nên `go/parser` và
`format.Source` đều sạch. Đã sửa ở generator, khóa bằng test hai chiều. Thay đổi của lần
chạy đã hoàn lại, `git status` sạch.

## 10 marker `TODO(new-resource)` sau mỗi lần sinh

| chỗ | việc | vì sao không tự sinh được |
| --- | --- | --- |
| migration up | ghi cột nào CỐ Ý không index và vì sao (R-09) | là lời giải thích về hình dạng truy vấn sẽ có, không suy được từ khai báo cột |
| `*_handler.go` | siết tag `binding` | generator chỉ biết kiểu SQL; `max`, dải số, định dạng là hợp đồng API |
| `*_service.go` (Create, Update) | thêm phép kiểm nghiệp vụ và chuẩn hóa | chính là phần nghiệp vụ - thứ duy nhất khung không thể có |
| `service/errors.go` | thay `CodeInventoryCodeDuplicated` bằng mã riêng (C-API-05) | mã mới phải do người thêm vào `shared/errors/codes.go`; generator mượn mã cũ làm chỗ đậu để file biên dịch được |
| ba file test | thay giá trị mẫu bằng dữ liệu thật | cột `uuid` mang một hằng; có khóa ngoại là fixture vi phạm ràng buộc |
| `*_service_test.go` | siết assert theo mã lỗi nghiệp vụ thật | phụ thuộc mã lỗi ở dòng trên |
| `vaitro.go` | quyết định vai trò nào được cấp năm quyền mới | `Bang()` có bảy khối vai trò, một dòng neo không chọn được khối nào - chèn nhầm là âm thầm MỞ quyền |

## Ba việc nối dây KHÔNG có marker

Chúng nằm trong file mà lệnh không vá nên không có chỗ đặt marker, và **bộ kiểm kiến trúc
vẫn XANH khi thiếu cả ba**. Lệnh in chúng ra sau khi sinh xong:

1. `modules/<m>/module.go`: dựng repo/service/handler trong `New`, gọi `Register<G>Routes` trong `Routes`. Thiếu thì năm route không tồn tại.
2. `cmd/internal/phamvi/phamvi.go`: thêm `repository.New<G>ScopeSource(db)` vào `Bang`. Thiếu thì `Resolve` không tìm được nguồn của loại phạm vi mới.
3. `arch/LEVELS.md` lệch vì số file đổi. Trên Windows: đọc bảng thật bằng `go run ./cmd/dev arch` rồi sửa tay - **đừng** chạy `arch-update`.

## Bằng chứng còn thiếu

Chưa có lần chạy `go run ./cmd/dev test` với database thật trên code sinh ra: lệnh đó cần
Docker, máy dev này không chạy được Docker. Không nói được gì về việc ba file test sinh ra
xanh hay đỏ. Cách lấy: đẩy nhánh có một tài nguyên đã sinh lên rồi đọc job test của CI.
Chỗ dễ đỏ nhất đã biết trước: giá trị mẫu `uuid` là hằng
`00000000-0000-4000-8000-000000000001`, vi phạm khóa ngoại ngay nếu cột đó tham chiếu
bảng khác.

## Việc tiếp theo

Sinh một tài nguyên THẬT đang cần (không phải `supplier` mẫu), xử lý hết 10 marker và ba
việc nối dây, rồi đẩy lên CI. Vừa ra một tài nguyên có ích, vừa là lần đầu bộ test sinh ra
được chạy với database thật - bằng chứng thiếu ở mục trên chỉ đến bằng đường đó.
