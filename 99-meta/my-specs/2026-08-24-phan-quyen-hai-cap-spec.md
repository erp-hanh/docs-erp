# Spec: tách màn phân quyền thành hai cấp

**Ngày:** 2026-08-24
**Trạng thái:** đã chốt hướng, **chưa thi công** — hai việc backend phải xong trước.
**Mockup:** `erp/mockup-erp/cap1-quan-tri-he-thong.html`, `erp/mockup-erp/cap2-phan-quyen-phan-he.html`
(mockup nằm ngoài git, xem `MEMORY.md` mục "Skill và mockup nằm ngoài git").

## 1. Vì sao tách

Hôm nay có đúng một màn `/quan-tri/phan-quyen`, và nó trộn hai việc thuộc hai người khác nhau:
việc của quản trị hệ thống (dựng chi nhánh, tạo tài khoản, bổ nhiệm trưởng phòng) và việc của
trưởng phòng (mở quyền Thêm/Sửa/Xoá/Duyệt cho nhân viên của mình). Hai người này không bao giờ
ngồi cùng một lúc, và trộn vào một màn nghĩa là ai mở ra cũng thấy quá nửa màn không phải việc
của mình.

## 2. Hai cấp

### Cấp 1 — Quản trị hệ thống

- **Ai:** người mang cờ `users.is_system_admin` → vai trò dẫn xuất `quan_tri_he_thong`.
- **Vào từ:** ứng dụng "Quản trị hệ thống" trong lưới ứng dụng.
- **Đứng ngoài mọi phân vùng** (ADR-0019 mục 5).
- **Ba tab:** Phân vùng (chi nhánh) · Tài khoản · Bổ nhiệm quản trị phân hệ.
- **Đơn vị một dòng:** một lượt bổ nhiệm = (người × chi nhánh × phân hệ × phạm vi dữ liệu).

### Cấp 2 — Admin phân hệ

- **Ai:** người mang `<module>.admin` của đúng phân hệ đó (`inventory.admin`, `machine.admin`,
  `auth.admin`) — ADR-0021.
- **Vào từ:** **thanh bên của chính phân hệ đó**, nhóm "Quản trị phân hệ" ở dưới cùng. Mục này
  chỉ hiện khi người đăng nhập mang vai trò tương ứng.
- **Ba tab:** Ma trận quyền `<phân hệ>` · Nhân sự phân hệ · Phạm vi kho.
- **Đơn vị một dòng:** một trang chức năng × năm hành động (Xem / Thêm / Sửa / Xoá / Duyệt).

### Ba thứ cấp 2 KHÔNG được vẽ

Vẽ ra là nói dối về quyền, và cả đội sẽ tưởng tính năng đã có:

1. **Chỉ một thẻ phân hệ.** Một `inventory.admin` không cấu hình được phân hệ khác.
2. **Vai trò ngoài phân hệ hiện mờ, không sửa được** — hiện dạng "Xem thiết bị · ngoài phân hệ".
3. **Không có nút "Tạo vai trò".** Bảng `roles` **đã có** (ADR-0023 đưa vai trò xuống
   database, thay ADR-0010), nhưng **đường ghi tập quyền chưa có** — đợt 2b. Đường ghi duy
   nhất vào `role_permissions` hôm nay là bộ nạp mặc định lúc mở phân vùng (ADR-0023 mục 11).

### Ma trận quyền chưa dựng được — đính chính

Bản đầu của spec này viết "màn cấp 2 dựng được ngay". Sai một nửa. Kiểm lại endpoint:

- `GET /roles` trả **đúng hai trường** `{ma, nhan}`. `frontend-erp/src/modules/user/api/user-api.ts:110`
  ghi rõ backend **cố ý** không trả tập permission, để câu hỏi "người xem có gán được vai trò
  này không" do một `403` thật trả lời chứ không do màn hình tự đối chiếu (C-TS-06).
- Không có endpoint nào liệt kê **trang chức năng** của một phân hệ.
- Không có đường ghi `role_permissions`.

Nên ma trận trang × hành động trong mockup cấp 2 là **thứ chờ đợt 2b**, không phải thứ dựng
được hôm nay. Nó cần hai endpoint mới ngoài đợt 2b: liệt kê trang chức năng, và đọc/ghi tập
quyền của một vai trò.

### Thứ dựng được ngay trên endpoint đang chạy

| Việc | Endpoint |
|---|---|
| Danh sách nhân sự | `GET /users` |
| Danh mục vai trò | `GET /roles` |
| Gán vai trò cho một người | `GET \| PUT /users/:id/roles` |
| Gán phạm vi kho cho một người | `GET \| PUT /users/:id/scopes` |

Bốn đường này đủ cho một màn cấp 2 **rút gọn**: băng chọn người (0.3) → thẻ ngữ cảnh (0.4) →
một thẻ "Vai trò trong phân hệ" (danh sách ô chọn) → một thẻ "Phạm vi kho". Không có ma trận.
Đó là màn nên dựng trước.

## 3. Hai quyết định cần ADR

### 3.1 Chi nhánh = phân vùng

**Đã chốt:** mỗi chi nhánh (Trụ sở, CN-HN, CN-HCM, NM-TB) là một hàng `companies`.

**Điều kiện tiên quyết — ADR-0019 giai đoạn hai, chưa thi công:**

- Bỏ `uq_users_email_active(company_id, email)`, email unique toàn hệ thống.
- Dựng `user_companies` và `user_company_roles` (schema đã chốt sẵn ở ADR-0019 mục 3).
- Đăng nhập hai bước: token danh tính 5 phút → liệt kê phân vùng → chọn → token gắn phân vùng.
- Đường đổi phân vùng, kèm thu hồi refresh token của phân vùng cũ.

**Chưa xong bước đó thì:** một người làm cả Hà Nội lẫn HCM phải có **hai tài khoản, hai mật
khẩu**. Đây là hệ quả đã được nêu và người quyết đã chấp nhận.

**Hệ quả nghiệp vụ đã chấp nhận:** dữ liệu giữa các chi nhánh không lẫn nhau, nên không có báo
cáo hợp nhất toàn công ty, và chuyển kho giữa hai chi nhánh không còn là một chuyển động kho
thường. Ngày cần hợp nhất thì đó là một ADR mới.

### 3.2 Mở quyền cho cấp 1

**Đã chốt:** `quan_tri_he_thong` sẽ tạo được tài khoản và bổ nhiệm được admin phân hệ.

Hôm nay nó giữ **đúng năm quyền** `auth.company_*` (ADR-0019 mục 5), nên chưa làm được. ADR mở
đường phải trả lời được rào của ADR-0029 mục "Nợ để lại":

> Điều kiện để ADR-0029 đứng vững: `auth.admin` không bao giờ được cấp một mã `auth.company_*`.

Tức là ADR mới đi **một chiều**: thêm `auth.user_*` cho `quan_tri_he_thong`, và giữ nguyên hàng
rào chiều ngược lại. Phải kèm một test khoá tính chất đó lại, vì hôm nay nó chỉ được giữ bởi nội
dung của bảng quyền chứ không bởi một luật (ADR-0029 mục Mất).

## 4. Thứ tự thi công

1. ADR cho 3.2 (rẻ, không chạm schema) → mở màn cấp 1 với hai tab Phân vùng + Nhật ký.
2. ADR-0019 giai đoạn hai (đắt, chạm luồng đăng nhập) → mở tab Tài khoản và Bổ nhiệm.
3. Màn cấp 2 **rút gọn** (vai trò + phạm vi kho, không ma trận) — không phụ thuộc hai việc
   trên, dựng được ngay trên bốn endpoint đang chạy.
4. Đợt 2b (CRUD `role_permissions`) + hai endpoint mới (liệt kê trang chức năng, đọc/ghi tập
   quyền của một vai trò) → khi đó mới mở được **ma trận trang × hành động**.

Nên bắt đầu bằng **bước 3**: nó là phần duy nhất chạy được hôm nay, và nó là màn mà trưởng kho
dùng hằng ngày.

## 5. Chưa quyết

- Trạng thái "Chờ nhận" của một lượt bổ nhiệm (thấy trên mockup cấp 1) — chưa có trong mô hình.
  Hoặc bỏ, hoặc cần một cột trạng thái thật.
- Phạm vi dữ liệu của một admin phân hệ ("6 kho — miền Nam") hiện chỉ có dạng danh sách kho.
  Với Kế toán và Bán hàng thì không có "kho" để bám vào — chưa có lời giải.
