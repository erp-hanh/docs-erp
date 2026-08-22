# Bàn giao - 2026-08-22, đợt 2a của ADR-0023

Đọc file này trước khi làm gì tiếp trên cụm phân quyền. Hai file bàn giao trước còn
nguyên giá trị và nói về đợt khác: `2026-08-21-ban-giao.md` (vai trò theo module) và
`2026-08-21-ban-giao-phan-quyen.md` (đợt giao diện).

## Đã xong và đã vào `main` cả ba repo

`backend-erp` PR #26, `docs-erp` PR #14, `frontend-erp` PR #21 - merge cùng một lượt, vì
job `arch` của backend đọc `C-API-http.md` của docs-erp và lệch lượt là đỏ một bên.

**Thẩm quyền gán vai trò nay tính từ TẬP QUYỀN, không từ tên vai trò** (ADR-0024 mục 3).
Actor phải có `<module>.role_assign` của mọi module xuất hiện trong tập quyền của vai trò
đó. Bất đối xứng trung tâm: `roles.code` do quản trị gõ tự do nên **không bao giờ** được
cắt tiền tố của nó; `permission_code` chỉ nhận giá trị trong danh mục hằng nên cắt tiền tố
của nó thì an toàn.

**ADR-0028 thu hẹp tập đầu vào của phép tính đó.** Đọc theo đúng câu chữ ADR-0024, luật
rộng hơn ý định của nó: `auth.self_read` và `auth.change_password` có trong cả tám vai trò
(ADR-0021 mục 2 gọi là sàn chung), còn `auth.role_assign` chỉ có ở hai - nên gán bất cứ
vai trò nào cũng đòi `auth.role_assign`, và một `inventory.admin` không gán được vai trò
**nào**. ADR-0028 bỏ khỏi tập quyền những mã chỉ tác động lên chính người giữ, trước khi
gom module. Tập ấy khai ở `cmd/internal/vaitro/vaitro.go`, hàm `QuyenTuTacDong()`.

**`GET /roles` đọc bảng `roles`** và nhận đủ `page`/`page_size`/`sort`. Ngoại lệ R-12 của
nó mang sẵn điều khoản tự huỷ, và đợt này thi hành nó - dòng trong `C-API-http.md` đã gỡ.

**Danh mục bảy dòng cứng đã xoá**: `vaitro.DanhMuc()`, `PermGan`, `auth.VaiTroKhaDung`,
`Deps.DanhMucVaiTro`, `quyenGanVaiTro`. Còn lại `nhanMacDinh()` - **không xuất khẩu**, chỉ
còn mã + nhãn, người đọc duy nhất là `BoMacDinh()`.

## Một lỗi có thật đã sửa, và bài học của nó

Migration 000025 gõ tay bảng nhãn ngay trong thân nó - **bản sao thứ ba** của cùng tập
nhãn, cạnh `cmd/internal/vaitro` và `NHAN_VAI_TRO` bên frontend. Nó lệch thật: sáu nhãn
mất dấu tiếng Việt, và `machine.ky_thuat` mang `"Ky thuat vien thiet bi"` trong khi hai
bản kia ghi `"Kỹ thuật"`.

Hậu quả trên dữ liệu đang chạy: **một phân vùng mở trước 000025 nhận nhãn của migration,
mở sau thì nhận nhãn của `CreateCompany`**. Cùng một hệ, cùng một vai trò, hai tên khác
nhau tuỳ ngày phân vùng được mở. Máy dev ở đúng trạng thái đó từ rc.27.

Migration 000026 chữa, với `WHERE name = <giá trị cũ>` để không đè lên tên một phân vùng
tự đặt (tinh thần ADR-0027), và hậu điều kiện đo bằng tập nhãn **cũ** chứ không tập mới vì
đúng lý do đó.

Bài học đáng giữ: **`TestE2EDanhMucVaiTroKhopBangThat` là thứ duy nhất bắt được nó**, và
nó chỉ bắt được vì đợt này đã đổi bài đó sang đối chiếu với `BoMacDinh()`. Đừng hạ bài đó
xuống.

## Việc còn mở, xếp theo thứ tự nên làm

### 1. `auth.admin` vẫn tự nhân bản được, và ADR-0024 nói lỗ đó đã đóng

ADR-0024 mục Consequences viết rằng lỗ `<module>.admin tự nhân bản được` đã đóng. Câu đó
đúng cho `inventory.admin` và `machine.admin` - tập quyền của chúng chạm module `auth` nên
gán chúng đòi `auth.role_assign`, thứ chúng không có.

Nó **không đúng** cho `auth.admin`: tập quyền của vai trò ấy nằm trọn trong module `auth`,
nên phép gom chỉ ra đúng `auth`, và nó có sẵn `auth.role_assign`. Nó gán được chính nó.

`modules/auth/docs/Permission.md` nay ghi đúng điều này. Phần đính chính ở `docs-erp` thì
**chưa làm**, và vì ADR bất biến nên nó phải là một ADR mới. Đóng nốt ô này đòi một luật
mà chính ADR-0024 mục Alternatives đã cân nhắc và loại - nên đây là một quyết định, không
phải một lần sửa lỗi.

### 2. Ba file `modules/*/docs/Permission.md` còn một tiền đề sai, cũ hơn đợt này

Cả ba đều viết "bảng vai trò thật sống ở `cmd/internal/vaitro` dưới dạng `authz.Bang`, một
bản duy nhất cho mọi composition root" (`auth` mục 3 và hai chỗ nữa, `inventory:230`,
`machine:199`).

Sau ADR-0023 **đợt 1**, nguồn sự thật *lúc chạy* là bảng `roles`/`role_permissions` của
từng phân vùng; `authz.Checker` đọc từ database có cache. `vaitro.Bang()` nay chỉ còn là
bộ nạp mặc định cho phân vùng mới, cộng tập quyền của vai trò dẫn xuất.

Sửa cho đúng nghĩa là viết lại phần mở đầu mục 3 của cả ba file, và **phải làm cùng một
đợt cho cả ba** để chúng không lệch nhau.

### 3. Đợt 2b - CRUD vai trò

Khi vế ghi tập quyền của một vai trò ra đời, **ADR-0028 mục 5 phải được áp ngay tại đó**:
phép loại trừ tập tự tác động áp cho cả đường ghi. Hôm nay chưa có code cho vế này vì
đường ghi duy nhất vào `role_permissions` là `NapBoMacDinh` - hệ thống nạp bộ mặc định cho
phân vùng mới, không phải quản trị sửa vai trò.

Kèm theo: lệnh `cmd/dev seed-roles` của ADR-0027 **chưa tồn tại**, mới chỉ được nhắc trong
comment. Không có nó thì permission của một module mới không tới được công ty đã có.

### 4. Ba spec còn mở của cùng cụm màn

- `2026-08-21-tim-kiem-nguoi-dung-spec.md` - `GET /users` chưa có tham số `q`.
- `2026-08-21-nhan-vai-tro-kem-auth-me-spec.md` - đã có ADR-0025 mở đường, chưa thi công.
- `2026-08-21-gan-duoc-tren-danh-muc-vai-tro-spec.md`.
- ADR-0026 (toàn phạm vi không còn là permission) chưa thi công.

## Thứ cần đi thử bằng tay trên dev, không test nào thay được

1. Đăng nhập `qa-admin`, mở `/phan-quyen`, kiểm **nhãn vai trò có dấu tiếng Việt** - đó là
   bằng chứng migration 000026 chạy trên dữ liệu thật, không phải trên database test.
2. Đường gán vai trò bằng một tài khoản chỉ có quyền quản trị một ứng dụng, nếu dựng được:
   phải gán được `inventory.thu_kho`, phải bị từ chối với `inventory.admin`, và **câu từ
   chối phải gọi tên module đang thiếu**.
3. Cảnh báo "danh mục vai trò đang bị cắt" ở màn gán **chưa có dữ liệu thật nào chứng
   minh** - nó chỉ nổ khi bảng `roles` vượt 100 dòng, và test đang mô phỏng con số đó.

## Ghi chú phát hành - phải nói ra, người dùng không tự đoán được

**Phạm vi gán vai trò của quản trị từng ứng dụng đã đổi.** Một `inventory.admin` vẫn gán
được `inventory.thu_kho` và `inventory.viewer`, nhưng **không còn gán được chính
`inventory.admin`** - vai trò ấy mang `auth.user_delete`, `auth.user_assign_roles` và hai
mã `auth.*` khác, tức quyền tác động lên người khác. Đó là lỗ ADR-0021 ghi ở mục Nợ để
lại, nay đóng cho hai trong ba vai trò quản trị ứng dụng.
