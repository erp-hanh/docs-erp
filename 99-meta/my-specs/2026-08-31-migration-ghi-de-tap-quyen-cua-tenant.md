# Năm migration liên tiếp ghi đè tập quyền của tenant, trái ADR-0027 mục 2

Ngày: 2026-08-31. Tìm ra bằng một lượt soi code sau rc.90. **Chưa sửa** — văn bản này là kế
hoạch sửa, và lý do vì sao nó không được sửa vội.

## Sự việc

`migrations/000040` → `000044` đều mang một khối:

```sql
INSERT INTO role_permissions (company_id, role_id, permission_code, ...)
SELECT r.company_id, r.id, v.permission_code, ...
FROM roles r
JOIN (VALUES ('inventory.admin', '<mã mới>'), ...) AS v ON v.role_code = r.code
WHERE r.deleted_at IS NULL AND NOT EXISTS (...);
```

Nó ghi vào tập quyền của những hàng `roles` **đã tồn tại**.

[ADR-0027](../../03-decisions/ADR-0027-permission-module-moi-vao-cong-ty-da-co.md) mục 2, tiêu đề
nguyên văn *"KHÔNG ghi đè lựa chọn của tenant, **không có ngoại lệ nào**"*:

> tập quyền của một hàng `roles` đã tồn tại là **dữ liệu của công ty đó**, ADR-0024 đã đặt nó
> dưới thẩm quyền của quản trị công ty ấy, và không cơ chế nào của hệ được ghi vào nó.

Mục Alternatives của chính ADR đó loại thẳng phương án *"mỗi module mới kèm một migration nạp
bù"*. `NOT EXISTS` chỉ chống nhân đôi hàng — nó **không** phân biệt "chưa bao giờ có" với
"quản trị đã cố ý gỡ".

**Kịch bản hỏng:** quản trị công ty X đã thu hẹp `inventory.thu_kho` thành gần như chỉ đọc.
Một lần `migrate-up` → mọi thủ kho của X **được cấp lại** quyền ghi, và từ 000043 thì được cấp
thêm quyền lập lệnh sản xuất cùng quyền đẩy hàng ra vào kho theo lệnh. Không ai tick, không màn
hình nào báo.

## Vì sao nó lặp lại năm lần

Khối đầu tiên nằm ở `000040`, và mỗi migration sau đều ghi *"chép đúng khuôn của 000040"*. Một
lối làm sai được chép lại bốn lần vì nó **trông giống** một tiền lệ. Không phép kiểm nào canh:
`cmd/dev/vaitrodatabase_test.go` chỉ đối soát migration 000025.

## Hai ca khác nhau, và chúng cần hai cách sửa khác nhau

**Ca A — quyền mới của một module ĐÃ CÓ** (`000040` thêm `inventory.partner_*`, `000042`).
ADR-0027 không mở đường nào cho ca này, và đó là **có ý thức**: `seed-roles` nạp ở mức vai trò,
vai trò đã có thì bỏ qua trọn vẹn. Hệ quả ADR chấp nhận là *quyền mới không bao giờ tự tới tenant
cũ* — quản trị của họ phải tự tick. Vậy cách sửa đúng là **gỡ khối INSERT**, không thay bằng gì.

**Ca B — quyền của một module MỚI** (`000043`, `000044` nhét `production.*` vào vai trò
`inventory.*`). Đây là ca ADR-0027 sinh ra để giải, và nó đã chỉ đường: module mới phải mang
**vai trò của chính nó**, rồi `seed-roles` nạp vai trò đó cho mọi công ty. Sai lầm của đợt sản
xuất là **không tạo vai trò `production.*` nào**.

Ca B nặng hơn ca A: nó vượt ranh giới module, và nó dựng ra đúng thế bí mà ADR-0027 mục 2 mô tả
— không vai trò nào của công ty cũ giữ `production.role_assign` nên quản trị công ty đó không tự
tạo nổi vai trò `production` đầu tiên.

## Đường sửa

1. **`production` khai vai trò mặc định của chính nó** trong `vaitro.BoMacDinh()` và `DanhMuc()`.
   Ít nhất một vai trò quản trị mang `production.role_assign`, và một vai trò vận hành. Người vừa
   giữ kho vừa lập lệnh sẽ được gán **hai** vai trò — đó là mô hình đúng, không phải điều bất tiện.
2. **Migration mới gỡ** những dòng `role_permissions` mà `000040`-`000044` đã chèn. Phải nghĩ kỹ:
   không phân biệt được dòng nào do migration chèn với dòng nào quản trị tự tick sau đó, trừ khi
   dựa vào `created_by` bằng system actor của C-DB-04.
3. **`seed-roles` chạy lúc deploy** — `deploy-dev.sh` đã gọi nó sẵn ở bước 4b.
4. **Gán lại vai trò cho tài khoản QA** trên dev, nếu không màn Lệnh sản xuất thành 403.
5. **Một phép kiểm ở `arch/`** chặn migration thứ sáu: `INSERT INTO role_permissions` chỉ được
   phép trong một danh sách đóng (000025 tạo vai trò lần đầu, 000034 backfill một cột). Đây là
   phần **rẻ nhất và đáng làm trước nhất** — nó chặn chảy máu ngay cả khi bốn bước kia còn chờ.

## Vì sao chưa sửa trong đợt này

Nó **không mất tiền và không sai sổ** — khác hẳn lỗi phiếu chuyển rút quá tồn (đã vá ở rc.91).
Nó chạm năm migration đã chạy trên dev cộng cả mô hình vai trò, và bước 2 cần một quyết định về
cách phân biệt dòng do máy chèn với dòng do người tick. Cùng lúc đó có ba đợt vá đang chạy cho
những lỗi **ăn vào sổ**, và chúng phải xong trước.

Hệ này chưa có khách hàng thật, nên chi phí sửa còn thấp — nhưng nó tăng theo mỗi module mới.

## Việc tiếp theo, đúng một việc

Bước 5: dựng phép kiểm ở `arch/`. Nó chặn được lỗi thứ sáu ngay hôm nay, và nó biến bốn bước còn
lại từ *"nhớ mà làm"* thành *"CI đỏ cho tới khi làm"*.
