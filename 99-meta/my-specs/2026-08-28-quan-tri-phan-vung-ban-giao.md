# Bàn giao: màn Quản trị phân vùng

Ngày 2026-08-28. Backend và frontend đều đã lên `main`, CI xanh cả ba repo.

Nền: [ADR-0039](../../03-decisions/ADR-0039-mot-nguoi-quan-tri-moi-phan-vung.md),
[ADR-0040](../../03-decisions/ADR-0040-doc-cheo-phan-vung-neo-vao-companies.md),
[ADR-0041](../../03-decisions/ADR-0041-duong-ghi-neo-vao-companies-chi-cho-co-quan-tri.md).
Thiết kế: [design](2026-08-28-quan-tri-phan-vung-design.md), kế hoạch:
[plan-backend](2026-08-28-quan-tri-phan-vung-plan-backend.md).

## Đã có gì

| Đường | Việc |
|---|---|
| `GET /companies/:id/admin` | người quản trị của một phân vùng, hoặc rỗng |
| `PUT /companies/:id/admin` | đặt người quản trị. Body `{"user_id": "..."}` |
| `GET /companies/:id/users` | người đang làm việc trong một phân vùng, có phân trang + sort |
| `POST /companies` | **đổi hợp đồng** — xem mục Breaking dưới đây |
| `GET /companies` | cột `so_nguoi` nay đếm đúng |

Migration `000035`: cột `user_companies.is_admin` + partial unique index
`uq_user_companies_admin ON user_companies(company_id) WHERE is_admin AND deleted_at IS NULL`.
Backfill **không đoán**: chỉ đánh dấu phân vùng có đúng một người giữ `auth.role_assign`; ca 0
người hoặc 2+ người để trống và in ra số lượng khi chạy.

Mã lỗi mới: `ERR_AUTH_ADMIN_NOT_ELIGIBLE` (422). Cùng đợt bổ sung bốn dòng C-API-05 cho bốn mã
đã có trong code từ đợt kiêm nhiệm nhưng chưa bao giờ có dòng nào trong bảng hợp đồng.

## BREAKING — đọc trước khi mở dev

`POST /companies` nay **bắt buộc** ba trường `admin_email`, `admin_full_name`,
`admin_password`. Form tạo phân vùng của frontend còn gửi `{code, name}` nên nút **Tạo phân
vùng sẽ ăn 422** cho tới khi làm frontend.

Để ba trường đó tùy chọn là vứt đúng cửa chặn mà ADR-0039 mục 3 vừa dựng — một phân vùng ra
đời không có ai quản trị thì vế "ít nhất một" không còn ai giữ.

Email đã tồn tại ở phân vùng khác thì **không** trả 409: hệ dùng lại tài khoản đó và gắn vào
phân vùng mới, `admin_password` bị bỏ qua. Response mang cờ `dung_lai_tai_khoan_cu` để màn
hình nói được điều đó với người vừa gõ mật khẩu.

## Bằng chứng

Toàn bộ `./modules/auth/...` chạy trên **PostgreSQL thật** ở VPS dev, không phải chỉ `go build`:

```
ok  	erp/modules/auth	1.142s
ok  	erp/modules/auth/internal/handler	24.210s
ok  	erp/modules/auth/internal/repository	1.811s
ok  	erp/modules/auth/internal/service	47.240s
```

Ba bài đáng kể nhất:

- `TestRangBuoc000035_HaiNguoiQuanTri_DatabaseTuChoi` — chèn thẳng hai hàng `is_admin = true`
  cùng một `company_id`, đòi lệnh thứ hai trả **cả** `23505` **lẫn** tên constraint
  `uq_user_companies_admin`. Chỉ đo mã thôi thì index của `000021` cũng trả đúng mã ấy, nên
  bài sẽ xanh giả sau ngày index `000035` bị gỡ. Đây là thứ chứng minh ADR-0039 không phải
  một lời hứa.
- `TestCompanyService_NguoiCuaPhanVung_ThuTuHaiCuaQuyen` — actor thiếu `auth.company_read`
  hỏi một `id` **không tồn tại** phải nhận **403 chứ không 404**. Đó là bài duy nhất đo được
  rằng cửa quyền chạy trước phép kiểm tồn tại.
- `TestCompanyHandler_KhongNhanCompanyIDTuRequest` — đọc AST, bắt `c.Query("company_id")` và
  tag `form:"company_id"`. Hai vế mà ADR-0040 cố ý **không** nới, và dễ bị nới lại vô tình.

Phép đếm người và phép chặn gỡ người quản trị đều đã qua **phép thử đột biến**: trả câu SQL /
gỡ cửa chặn thì test đỏ đúng chỗ.

## Frontend

`frontend-erp` `09ffa2a`, CI xanh (test 155s, lint 41s, arch 32s), 1276 test.

- **Form tạo phân vùng** gửi đủ năm field. Trước đó nó gửi `{code, name}` trong khi backend
  đã đổi hợp đồng — nút Tạo **hỏng thật** trên dev, không phải thiếu tính năng. Ca "email đã
  có chủ ở phân vùng khác" được nói ra bằng chữ: hệ dùng lại tài khoản cũ và **mật khẩu vừa
  gõ đã bị bỏ qua**. Im lặng ở đây nghĩa là người vừa đặt một mật khẩu sẽ đọc nó cho đồng
  nghiệp dùng.
- **Mặt Quản trị** bỏ hết dữ liệu giả: xoá `quan-tri-phan-vung-mau.ts`, gỡ hai dải cảnh báo
  và cờ `xemTruoc`. Cột người quản trị có bốn nhánh phân biệt được trên màn — có người / chưa
  có ai / chưa hỏi xong / hỏi hỏng. Ba nhánh sau đều là "không có tên người" nhưng dẫn tới ba
  việc khác hẳn: chờ, đi giao việc, báo sự cố.
- **Màn người dùng của một phân vùng** đặt làm **màn con** `/quan-tri/phan-vung/:id/nguoi`,
  không phải mặt thứ ba của dải tab: hai mặt kia nói về *tập* phân vùng, màn này nói về *đúng
  một* phân vùng và không có id thì nó không tồn tại.

Tên ô trong `error.fields` đã **đối chiếu với backend chứ không đoán**:
`PUT /companies/:id/admin` trả `user_id`, `POST /companies` trả `admin_email`.

## Tra MISA AMIS — ba dữ kiện, ghi lại để đọc lại

Tra ngày 2026-08-28 theo nếp đã dùng ở `mockup-erp/kho-van-v3.html`:

1. **Đơn vị của MISA không có trường "người phụ trách".** Quản trị là một **vai trò**
   (`Quản trị hệ thống`, `Quản trị bảo mật`), còn quyền xem dữ liệu thì gán **theo từng
   người** vào từng cấp tổ chức. Tức MISA **không** có khái niệm "mỗi chi nhánh một người
   quản trị" mà ADR-0039 vừa dựng. Dữ kiện này **không** làm đảo quyết định — người quyết đã
   chọn ép cứng và backend đã chạy — nhưng nó là bằng chứng cần có nếu ngày nào đó đọc lại.
2. **MISA có "Ngừng sử dụng" tách hẳn khỏi xoá.** Đúng món nợ ADR-0019 đã ghi: hệ này đang
   dùng chung `deleted_at` nên không có cách nào tạm dừng một phân vùng đang có người.
3. Form khai đơn vị của MISA: **Mã đơn vị\*, Tên đơn vị\*, Cấp tổ chức** (Chi nhánh / Văn
   phòng / Phòng ban / Phân xưởng / Nhóm), **Loại chi nhánh** (độc lập / phụ thuộc), **Kê
   khai thuế riêng**. Ba ô sau là thứ hệ này chưa có và sẽ cần khi làm ADR-0033 (phân vùng
   nhiều cấp).

## Ba việc còn nợ

1. **Chưa bấm thử trên dev.** 1276 test xanh không nói được ca `dung_lai_tai_khoan_cu` và ca
   `422 ERR_AUTH_ADMIN_NOT_ELIGIBLE` có đọc được trên màn thật hay không. Deploy một bản rc
   rồi đi thử bằng `qa-admin`.
2. **Chưa có checker cho ba ngoại lệ R-06.** ADR-0040 và ADR-0041 đều tự ghi nợ này. Nay có
   một câu ghi hợp lệ nên checker tương lai không thể là "cấm mọi `UPDATE` nhận `company_id`
   từ path" mà phải là danh sách trắng theo tên hàm, giống map `hamMienCompanyID` của
   ADR-0034.
3. **Phân vùng cũ có thể đang không có người quản trị.** Backfill cố ý không đoán. Chạy
   migration trên dev rồi đọc dòng `NOTICE` để biết có bao nhiêu đơn vị như vậy.

## Va phải khi merge: hai ADR trùng số

Phiên khác đang viết `ADR-0039-tinh-chat-vat-tu-hang-hoa-ba-gia-tri.md` và
`ADR-0040-phieu-nhap-xuat-thuoc-inventory.md` — chưa commit, nhưng trùng số với hai ADR của
đợt này. `check-ids` đỏ ngay vì hai file cùng một ID.

Đã đổi số **bản của họ** thành `ADR-0042` và `ADR-0043`, giữ nguyên toàn bộ nội dung, và sửa
một dòng liên kết trong `CONTEXT.md` cho khớp. Hai file đó vẫn ở trạng thái chưa commit — việc
commit vẫn là của phiên kia.

Lý do chọn đổi bên đó: bản của đợt này đã commit và bị trỏ tới từ **110 chỗ** trong
`backend-erp` cộng `RULES.md`, bảng C-API-05 và hai file kế hoạch; bản của họ là hai file chưa
commit với bốn tham chiếu. Đổi số bên đắt hơn là làm lại cả vòng kiểm chứng.

## Việc tiếp theo

Làm frontend, bắt đầu từ form tạo phân vùng — nó đang hỏng thật trên dev chứ không chỉ thiếu
tính năng. Rồi tới cột người quản trị, rồi màn xem người trong một phân vùng.
