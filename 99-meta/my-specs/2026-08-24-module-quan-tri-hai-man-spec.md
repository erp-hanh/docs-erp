# Spec: dựng lại module quản trị thành hai màn

**Ngày:** 2026-08-24
**Trạng thái:** đã chốt hướng với người quyết, chưa thi công.
**Thay thế:** bố cục ba mục của `2026-08-24-phan-quyen-hai-cap-spec.md` mục 4d và 4e.
**Chốt luôn:** hai câu bỏ ngỏ ở mục 4e và mục 5 của spec đó (xem mục 8 dưới đây).

## 1. Vì sao dựng lại

Module quản trị hôm nay có bốn mục thanh bên: Tài khoản, Phân vùng, Vùng dữ liệu, Bổ nhiệm
quản trị phân vùng. Bốn mục này không gấp lại được thành một câu nói được là quản trị hệ thống
làm gì. Hai trong bốn màn chạy dữ liệu giả, một màn thứ năm (`VungDuLieuFormPage`) viết xong
mà không có route nào trỏ tới.

Người quyết mô tả lại việc của quản trị hệ thống bằng đúng bốn động từ:

1. Tạo vai trò
2. Gán vai trò cho người dùng
3. Tạo vùng dữ liệu
4. Gán vùng dữ liệu cho quản trị module

Bốn động từ chia thành hai cặp, nên module quản trị có đúng hai màn.

## 2. Mô hình đã chốt

- **Một công ty, nhiều phân vùng.** Mỗi phân vùng là một chi nhánh. Một hàng `companies` là một
  chi nhánh. Đây là chốt lại của mục 3.1 spec cũ, nay bỏ mọi cách đọc khác.
- **Vai trò** là hàng `roles`, có phạm vi phân hệ. Ở màn quản trị hệ thống, một vai trò chỉ có
  mã, tên, phân hệ áp dụng, mô tả, trạng thái. **Không có ma trận Xem/Thêm/Sửa/Xoá/Duyệt ở
  đây** — người quyết nói thẳng điều này. Tick từng ô quyền là việc của quản trị module, làm
  trong chính phân hệ của họ.
- **Vùng dữ liệu** là một nhóm phân vùng có tên. Ví dụ "Miền Bắc" = {Trụ sở, CN-HN}. Không phải
  nhóm kho.
- **Một lượt gán quản trị module** = người × phân hệ × vùng dữ liệu. Trục chi nhánh biến mất
  khỏi một dòng bổ nhiệm, vì vùng dữ liệu đã mang trục đó.

## 3. Hai màn

```
Quan tri he thong
  |- Phan quyen        /quan-tri/phan-quyen
  |     tab Vai tro
  |     tab Gan vai tro
  |
  |- Vung du lieu      /quan-tri/vung-du-lieu
        tab Phan vung
        tab Vung du lieu
        tab Gan quan tri module
```

Dải tab dùng `shared/components/DaiTab`, tức là dải **liên kết** có địa chỉ riêng từng mặt,
không phải `role="tablist"`. Mỗi mặt là một mặt của cùng một đối tượng, đúng điều kiện của
`khuon-man-hinh.md` mục 0.2: màn Phân quyền nói về **vai trò**, màn Vùng dữ liệu nói về **phạm
vi dữ liệu**.

Mục bấm trên thanh bên và tiêu đề màn đến gọi cùng một tên. Tab nói mặt, không nhắc lại tên màn.

### 3.1 Màn Phân quyền

**Tab Vai trò** — `/quan-tri/phan-quyen`

| Cột | Nội dung |
|---|---|
| Mã | `MaBanGhi`, ví dụ `inventory.thu_kho` |
| Tên vai trò | Tên hiển thị |
| Phân hệ | Chip: Kho vận / Thiết bị / Quản trị |
| Đang giữ | Số người đang mang vai trò, class `so` |
| Trạng thái | `NhanTrangThai` tốt/tắt |
| Thao tác | Sửa |

Nút dải đầu: "Tạo vai trò". Form (`--rong-form`): Mã, Tên vai trò, Phân hệ áp dụng, Mô tả,
Trạng thái. Mã khoá cứng khi sửa.

**Tab Gán vai trò** — `/quan-tri/phan-quyen/gan`

| Cột | Nội dung |
|---|---|
| Người dùng | Tên + email |
| Phân vùng | Chi nhánh của tài khoản |
| Vai trò đang giữ | Chip nhiều vai trò, gấp `+N` |
| Trạng thái | `NhanTrangThai` |
| Thao tác | Gán vai trò → `/quan-tri/phan-quyen/gan/:id` |

Màn gán một người: thẻ ngữ cảnh (ai, phân vùng nào) + danh sách ô chọn vai trò. Giữ nguyên
cảnh báo móc vòng đời `VE_CANH_BAO_MOC_VONG_DOI` đang có ở `UserDetailPage`.

### 3.2 Màn Vùng dữ liệu

**Tab Phân vùng** — `/quan-tri/vung-du-lieu/phan-vung`

Giữ nguyên nội dung `CompanyListPage` đang chạy: Mã, Tên chi nhánh, Số người dùng, Thao tác.
Thêm cột Trạng thái. Đưa qua hệ thiết kế: thay `<table>` trần bằng `Bang`, thêm `TieuDeTrang`
và `DaiTab`. Đây là món nợ đã ghi ở mục 4c spec cũ.

**Tab Vùng dữ liệu** — `/quan-tri/vung-du-lieu`

| Cột | Nội dung |
|---|---|
| Tên vùng | Tên + mô tả |
| Phân vùng trong vùng | Chip `MaBanGhi`, gấp `+N chi nhánh` |
| Đang gán cho | Số lượt gán quản trị module, class `so` |
| Thao tác | Sửa, Xoá |

Form: Tên vùng, Mô tả, `DanhSachChon` các phân vùng. Xoá khoá mềm kèm `lyDoKhoa` khi vùng còn
lượt gán.

**Tab Gán quản trị module** — `/quan-tri/vung-du-lieu/gan`

| Cột | Nội dung |
|---|---|
| Người dùng | Tên + email |
| Phân hệ quản trị | Chip: Kho vận / Thiết bị / Kế toán |
| Vùng dữ liệu | Tên vùng + số chi nhánh |
| Trạng thái | Hiệu lực / Đã thu hồi |
| Thao tác | Sửa, Thu hồi |

Form: chọn người, chọn phân hệ, chọn vùng dữ liệu.

## 4. Màn giữ, màn xoá

**Giữ và sửa:**

| File hiện có | Thành |
|---|---|
| `modules/company/pages/CompanyListPage.tsx` | Tab Phân vùng |
| `modules/company/pages/CompanyFormPage.tsx` | Form phân vùng, giữ nguyên logic API |
| `modules/user/pages/UserListPage.tsx` | Tab Gán vai trò (bỏ dải tab hai mặt phạm vi) |
| `modules/user/pages/UserDetailPage.tsx` | Màn gán vai trò một người (bỏ khối gán phạm vi kho) |
| `modules/company/pages/VungDuLieuListPage.tsx` | Tab Vùng dữ liệu, viết lại theo mô hình mới |
| `modules/company/pages/VungDuLieuFormPage.tsx` | Form vùng dữ liệu, nối route (hết mồ côi) |

**Xoá, kèm route và test:**

- `modules/user/pages/MaTranQuyenPage.tsx` + test — ma trận không thuộc cấp quản trị hệ thống.
- `modules/user/pages/TaiKhoanListPage.tsx` + test — người quyết chốt bỏ màn quản lý tài khoản.
- `modules/user/pages/TaiKhoanFormPage.tsx` + test — cùng lý do.
- `modules/user/pages/BoNhiemListPage.tsx` + test — thay bằng tab Gán quản trị module.
- `modules/user/pages/BoNhiemFormPage.tsx` + test — cùng lý do.
- `modules/user/pages/ChuyenHuongChiTiet.tsx` + test — bốn đường `/nguoi-dung*` đã cũ.
- `modules/user/components/mat-tai-khoan.ts` — hai mặt phạm vi không còn.
- `app/tab-quan-tri.ts` — thay bằng hai danh sách mặt mới, vẫn ở `app/` vì mặt thuộc hai module.

Xoá màn Tài khoản có nghĩa: hệ thống không còn chỗ tạo tài khoản, đổi mật khẩu hộ, bật tắt tài
khoản. Đây là hệ quả người quyết đã nhận. Danh sách người dùng chỉ còn xuất hiện dưới dạng tab
Gán vai trò.

## 5. Dữ liệu thật và dữ liệu giả

Đợt này dựng giao diện trước, nối API sau. Ranh giới:

| Phần | Nguồn |
|---|---|
| Tab Phân vùng | API thật: `GET/POST/PATCH/DELETE /companies` |
| Tab Gán vai trò, danh sách người | API thật: `GET /users` |
| Tab Gán vai trò, danh mục vai trò | API thật: `GET /roles` |
| Gán vai trò cho một người | API thật: `GET | PUT /users/:id/roles` |
| Tab Vai trò, tạo/sửa vai trò | **Dữ liệu giả** |
| Tab Vùng dữ liệu | **Dữ liệu giả** |
| Tab Gán quản trị module | **Dữ liệu giả** |

Mọi mặt chạy dữ liệu giả mang một dải `BangThongBao` sắc `canh-bao` cao **tối đa hai dòng**,
nói rõ endpoint còn thiếu và trỏ về spec này. Mọi nút ghi khoá mềm kèm `lyDoKhoa` — không cú
bấm nào bị nuốt im lặng. Đây là lối đã dùng ở đợt rc.40 và đã sửa lỗi dải cảnh báo quá cao.

## 6. Backend còn nợ

Danh sách endpoint phải có trước khi ba mặt kia bỏ được dữ liệu giả:

| Việc | Endpoint cần |
|---|---|
| CRUD vai trò | `POST /roles`, `PATCH /roles/:id`, `DELETE /roles/:id`; `GET /roles` phải trả thêm `phan_he`, `so_nguoi_giu`, `is_active` |
| CRUD vùng dữ liệu | bảng mới + `GET/POST/PATCH/DELETE /data-zones` |
| Gán quản trị module | bảng mới + `GET/POST/PATCH/DELETE /module-admins` |

Hai bảng mới thay chỗ của `user_company_role_scopes` ở trục chi nhánh. Phạm vi kho hiện có
(`GET | PUT /users/:id/scopes`) **không bị xoá** — nó là phạm vi cấp 2, do quản trị module đặt
trong phân hệ của họ, không thuộc hai màn này.

`GET /roles` hôm nay cố ý chỉ trả `{ma, nhan}` để câu hỏi "gán được không" do một `403` thật
trả lời (C-TS-06). Thêm ba trường trên **không** phá luật đó: ba trường mới nói về bản thân vai
trò, không nói về quyền của người đang xem.

## 7. Test

Mỗi mặt một file `*.test.tsx` cạnh page. Ca bắt buộc mỗi bảng: đang tải, rỗng, lỗi 403, lỗi
khác có nút thử lại, có dữ liệu. Ca bắt buộc mỗi form: trường trống, lỗi 422 đúng ô, lỗi 409.

Sửa `app/routes.test.tsx` (13 ca, khoá thứ tự `/moi` trước `/:id`) và `app/ung-dung.test.ts`
(19 ca, khoá bất biến `duongThuoc` không giao nhau) theo bảng route mới.

Luật riêng của repo này: **test bằng class, không bằng chữ**, vì `textContent` không thấy chữ
bị CSS giấu.

## 8. Hai câu bỏ ngỏ nay đã chốt

- **Mục 4e spec cũ** hỏi tên màn bổ nhiệm nói theo trục chi nhánh còn cột nói theo trục phân
  hệ, chọn đường nào. Chốt: **đổi mô hình**. Một lượt gán là người × phân hệ × **vùng dữ liệu**,
  và vùng dữ liệu là nhóm chi nhánh. Hai trục không còn cãi nhau.
- **Mục 5 spec cũ** nói phạm vi dữ liệu chỉ có dạng danh sách kho nên Kế toán và Bán hàng không
  có gì để bám. Chốt: phạm vi cấp 1 bám vào **chi nhánh**, thứ mọi phân hệ đều có. Danh sách
  kho lùi xuống cấp 2, đúng chỗ của nó.

## 9. Chưa quyết

- Trạng thái "Chờ nhận" của một lượt gán quản trị module. Đợt này vẽ hai trạng thái Hiệu lực /
  Đã thu hồi. Nếu cần bước xác nhận thì đó là một cột trạng thái thật, quyết khi làm backend.
- Một người có được gán hai vùng dữ liệu cho cùng một phân hệ không. Đợt giao diện cho phép
  nhiều dòng; ràng buộc duy nhất quyết khi làm backend.
