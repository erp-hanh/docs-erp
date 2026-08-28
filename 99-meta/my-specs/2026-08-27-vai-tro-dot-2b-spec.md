# Đợt 2b - CRUD vai trò

Ngày: 2026-08-27. Trạng thái: spec, chưa thi công.

Thay thế trạng thái "dữ liệu mẫu" của màn Vai trò bằng đường thật, và mở cho admin của
một phân vùng tự đặt ra vai trò rồi tự tích quyền cho nhân viên trong phân vùng đó.

## 1. Vì sao đợt này tồn tại

Màn `/quan-tri/phan-quyen` hôm nay chạy trên hằng `VAI_TRO_MAU` (5 dòng bịa) và đeo chip
"Xem trước". Backend chỉ có `GET /api/v1/roles` trả đúng `{ma, nhan}`, không có đường ghi
nào. Bốn cột đang hiện trên màn - Mô tả, Phân hệ, Đang giữ, Trạng thái - không có nguồn
thật, và ba trong bốn cột đó không có cột tương ứng dưới database.

## 2. Người dùng chốt những gì

Hỏi và đáp ngày 2026-08-27:

1. **Phạm vi**: mỗi phân vùng có một admin. Vai trò admin của phân vùng do hệ thống đặt
   sẵn - mã hệ thống sinh, tên người dùng đặt. Trong phân vùng của mình, admin tự đặt ra
   vai trò mới và tự tích quyền cho nhân viên.
2. **Ngừng dùng**: **tắt, không xoá**. Vai trò vẫn nằm trong danh sách, đánh dấu Tắt;
   người đang giữ mất quyền ngay; gán mới không chọn được; bật lại bất cứ lúc nào.
3. **Tập quyền admin nhìn thấy**: **đúng những quyền chính họ đang có**. Quyền ngoài tầm
   hiện mờ và khoá, kèm câu nói vì sao.
4. **Chỗ tích quyền**: **cùng một màn** với tên vai trò, một nút Lưu cho cả hai.
5. **Vai trò admin gắn với vòng đời phân vùng**: phân vùng còn sống thì vai trò admin của
   nó không tắt được; phân vùng bị ẩn thì vai trò admin của nó ẩn theo.

Giả định do người viết spec chốt, người dùng chưa phản đối: **bảy vai trò hệ thống sửa
được tên và mô tả, khoá tập quyền**. Muốn một tập quyền khác thì tạo vai trò riêng. Lý do:
admin sửa tập quyền của chính vai trò đang cho họ quyền quản trị là đường ngắn nhất để tự
khoá mình ra ngoài phân vùng, và không ai trong phân vùng sửa lại được.

## 3. Đường đã chọn, và hai đường đã loại

**Đã chọn - mở rộng bảng `roles` sẵn có.** Thêm cột cho mô tả, trạng thái bật/tắt, và cờ
do-hệ-thống-tạo. Tập quyền của vai trò vẫn ở bảng `role_permissions` đã có từ ADR-0023.

**Loại - không đụng database** (bỏ cột Mô tả và Trạng thái khỏi màn): rẻ hơn chừng một
phần ba nhưng mâu thuẫn thẳng với điểm 2 người dùng vừa chốt.

**Loại - vai trò mẫu cấp hệ thống, mỗi phân vùng một bản sao**: đá vào ADR-0027 (hệ thống
không bao giờ ghi đè `role_permissions` của một vai trò đã tồn tại), và là một cỗ máy đồng
bộ hai chiều đắt gấp nhiều lần nhu cầu hôm nay.

## 4. Ràng buộc bắt buộc tuân - không cái nào được bỏ

Khảo sát ngày 2026-08-27 rút ra mười ràng buộc. Đường ghi của đợt này phải tuân từng cái.

1. **Loại trừ tập tự tác động** (ADR-0028 mục 5): `auth.self_read` và
   `auth.change_password` bị bỏ khỏi tập quyền TRƯỚC khi gom module để tính thẩm quyền -
   và mục 5 nói rõ phép loại trừ này áp cho cả đường GHI. Dùng lại `s.quyenTuTacDong` đã
   tiêm sẵn (`user_service.go:1303-1311`).
2. **Kiểm trên hiệu đối xứng, không trên tập gửi lên** (ADR-0024 mục 2): actor phải có
   `<module>.role_assign` của mọi module xuất hiện trong hiệu giữa tập quyền cũ và tập
   quyền mới. Kiểm trên tập gửi lên là lỗ cho phép GỠ quyền của module mình không có
   thẩm quyền. Khuôn có sẵn: `hieuDoiXungVaiTro` (`user_service.go:779`).
3. **Cấm suy module từ tiền tố `roles.code`** (ADR-0024). Module của một vai trò suy từ
   `role_permissions`, luôn luôn. Ô "Phân hệ áp dụng" trên màn tạo chỉ là quy ước đặt tên
   để sinh mã, không phải nguồn sự thật về module.
4. **`quan_tri_he_thong` không bao giờ có hàng `roles`** (ADR-0023 mục 3): chặn nó trước
   mọi phép kiểm khác, đúng như `laVaiTroDanXuat` đang làm.
5. **`roles.code` bất biến sau khi tạo** (ADR-0023 mục 5): migration cố ý không cưỡng chế,
   đường ghi của đợt này phải cưỡng chế.
6. **Tra mã trùng phải hỏi bất kể `deleted_at`** (ADR-0027 mục 3): `uq_roles_company_id_code`
   là partial index, nên một mã sống nằm cạnh một mã bia mộ thì database không chặn.
7. **`permission_code` là TEXT trần**: không FK, không CHECK. Phép kiểm "mã quyền này có
   thật không" nằm ở tầng service, đối chiếu danh mục hằng tiêm từ composition root
   (ADR-0023 mục 7).
8. **Xoá là xoá mềm** (R-18) cho cả `roles` lẫn `role_permissions`.
9. **Nhớ đệm quyền 30 giây** (`shared/authz/nguon_db.go`, `nhipHetHan`): sau khi ghi tập
   quyền, thay đổi chỉ nhìn thấy sau tối đa 30 giây. Không có API vô hiệu hoá. Đợt này
   **nói câu đó trên màn**, không bổ sung cơ chế invalidate.
10. **`GET /roles` phân trang sau lọc thẩm quyền** (ADR-0032): thêm trường mới không được
    kéo `LIMIT/OFFSET` xuống SQL.

## 5. Database - migration `000033` và `000034`

Một migration làm một việc, nên tách đôi (C-DB-06).

**`000033_add_role_attributes`** - DDL trên `roles`:

| Cột | Kiểu | Mặc định | Nói gì |
|---|---|---|---|
| `description` | TEXT NOT NULL | `''` | Mô tả admin tự viết |
| `is_active` | BOOLEAN NOT NULL | `true` | Bật/tắt. `false` = không gán mới được, người đang giữ mất quyền |
| `is_system` | BOOLEAN NOT NULL | `false` | Do hệ thống tạo. Khoá tập quyền, khoá nút Tắt |

Không thêm cột `module`: module suy từ `role_permissions` (ràng buộc 3).

Không thêm index mới: mọi câu đọc vẫn lọc theo `company_id` rồi `code`, đúng
`uq_roles_company_id_code` đang có.

`down` trả lại ba cột. Ghi comment `-- destructive: rollback lam mat du lieu cot
description, is_active, is_system`.

**`000034_backfill_role_system_flag`** - backfill hai việc:

1. Bật `is_system = true` cho các hàng `roles` mang một trong bảy mã mặc định
   (`auth.admin`, `inventory.admin`, `inventory.thu_kho`, `inventory.viewer`,
   `machine.admin`, `machine.viewer`, `machine.ky_thuat`) ở mọi phân vùng.
2. **Bẫy đã bắt được trước khi nó cắn**: đợt này thêm hai mã quyền mới
   (`auth.role_create`, `auth.role_update`) vào bộ mặc định của `auth.admin`. ADR-0027
   nói hệ thống **không bao giờ** ghi đè `role_permissions` của một vai trò đã tồn tại,
   nên `seed-roles` sẽ KHÔNG nạp hai mã này cho các phân vùng đang sống. Không có
   backfill này thì admin của mọi phân vùng hiện có không mở được màn vừa làm ra.
   Backfill chèn đúng hai hàng `role_permissions` cho mỗi hàng `roles` mã `auth.admin`
   còn sống, bỏ qua hàng đã có (`ON CONFLICT DO NOTHING` theo unique index partial).

## 6. Backend - hai mã quyền mới, ba endpoint

### 6.1 Hai mã quyền mới

| Mã | Cho làm gì | Vào vai trò nào |
|---|---|---|
| `auth.role_create` | Tạo vai trò mới trong phân vùng của mình | `auth.admin`, `quan_tri_he_thong` |
| `auth.role_update` | Sửa tên/mô tả/tập quyền, bật tắt một vai trò | `auth.admin`, `quan_tri_he_thong` |

**Cấp hai mã này cho `quan_tri_he_thong` đảo một mệnh đề đã khoá bằng máy.** ADR-0031 mục 1
chốt tập quyền của vai trò dẫn xuất ở đúng mười sáu mã, và
`cmd/internal/vaitro/adr0031_test.go` là hiện thân của mệnh đề đó. Vẫn cấp, vì người dùng
nói rõ quản trị hệ thống cũng phải tự thêm được vai trò. ADR mới (mục 9) ghi phép đính
chính mười sáu -> mười tám kèm lập luận theo tiêu chí ADR-0031 mục 2, và bài test đó sửa
trong cùng lượt - không để nó đỏ qua đêm.

Không có `auth.role_delete`: người dùng chốt "tắt, không xoá", nên không có đường xoá để
gác.

Khai cạnh các hằng `auth.*` đang có; thêm vào `Bang()` của `cmd/internal/vaitro`; nhớ
`nhanMacDinh()` và map `NHAN_VAI_TRO` ở `frontend-erp/src/app/DropdownTaiKhoan.tsx` phải
khớp tay - hai bên đó lệch là hỏng lặng lẽ.

### 6.2 `GET /api/v1/permissions` - danh mục quyền kèm nhãn tiếng Việt

Mới. Trả **50** mã quyền - 48 mã đang có cộng hai mã mục 6.1 vừa thêm - mỗi mã kèm nhãn
tiếng Việt, nhóm, và module.

```
{"data":[{"ma":"inventory.item_create","nhan":"Thêm vật tư",
          "nhom":"Danh mục vật tư","phan_he":"inventory",
          "nhan_phan_he":"Kho vận","cap_duoc":true}], "meta":{...}, "request_id":"..."}
```

`cap_duoc` = actor có đang giữ mã quyền đó không. Đây là thứ làm nên điểm 3 người dùng
chốt: `false` thì màn vẽ dòng đó mờ và khoá. Backend vẫn phải từ chối nếu ai đó gửi lên
một mã `cap_duoc: false` - ẩn nút là UX, không phải bảo mật.

**Nhãn tiếng Việt sống ở Go**, cạnh danh mục hằng trong `cmd/internal/vaitro`, không ở
frontend. Lý do: thêm một mã quyền ở backend mà quên sửa bảng nhãn bên frontend thì màn
hiện ra một mã trần kiểu `inventory.movement_create` cho người không làm kỹ thuật đọc.
Một nguồn, một chỗ sửa.

50 nhãn là phần việc thầm lặng lớn nhất của đợt này. Nhóm theo đối tượng, không theo động
từ: "Kho hàng", "Danh mục vật tư", "Sổ nhập xuất", "Tồn kho", "Đơn vị tính", "Người dùng",
"Phân vùng", "Phân quyền", "Thiết bị", "Kế hoạch bảo trì", "Sự cố".

Gác bằng `auth.role_create` HOẶC `auth.role_update` - ai không đặt được vai trò thì không
cần danh mục quyền.

### 6.3 `GET /api/v1/roles` - mở rộng, không phá

Giữ nguyên đường lọc theo thẩm quyền và phân trang sau lọc của ADR-0032. Thêm trường:

| Trường | Nguồn |
|---|---|
| `id` | `roles.id` - hôm nay cố ý vắng, nay có người đọc thật |
| `mo_ta` | `roles.description` |
| `dang_dung` | `roles.is_active` |
| `he_thong_tao` | `roles.is_system` |
| `phan_he` | Mảng mã module suy từ `role_permissions` (ràng buộc 3), không từ tiền tố mã |
| `nhan_phan_he` | Mảng nhãn tiếng Việt song song `phan_he`, cùng thứ tự - nhãn sống ở Go, đúng lý do mục 6.2 |
| `so_nguoi_giu` | `COUNT` trên `user_company_roles` còn sống |

Thêm trường vào response không phải breaking (C-API-06). `VaiTroKhaDungDTO {ma, nhan}`
bên frontend vẫn đọc được như cũ.

**Một endpoint, không phải hai.** Vai trò mà admin không gán được cũng là vai trò admin
không sửa được - cùng một luật thẩm quyền - nên danh sách đã lọc của ADR-0032 chính là
danh sách đúng cho màn quản trị.

### 6.4 `POST /api/v1/roles` - tạo, trả 201

Thân: `{"name": "...", "description": "...", "module": "inventory", "permissions": [...]}`

**Mã do backend sinh**, không nhận từ client: `module` + `name` → slug không dấu →
`inventory.thu_kho_ca_dem`. Trùng thì thêm hậu tố `_2`, `_3`. Tra trùng hỏi bất kể
`deleted_at` (ràng buộc 6). Frontend vẫn hiện một mã xem trước cạnh ô Tên, kèm câu nói rõ
mã cuối cùng do hệ thống chốt - frontend không giữ quy tắc nghiệp vụ (R-19).

Kiểm ở tầng service, theo thứ tự: `authz.Can(auth.role_create)` → mã quyền gửi lên có
trong danh mục hằng không (ràng buộc 7) → loại trừ tập tự tác động (ràng buộc 1) → actor
có `<module>.role_assign` của mọi module còn lại không (ràng buộc 2) → sinh mã → mở
transaction → ghi `roles` + `role_permissions` + `audit_logs` hằng `role.created` → commit.

`is_system` luôn `false` cho đường này.

### 6.5 `PATCH /api/v1/roles/:id` - sửa, trả 200

Thân, mọi trường tuỳ chọn: `{"name", "description", "permissions", "dang_dung"}`.

Ba tên tiếng Anh cạnh một tên tiếng Việt là **chủ ý, không phải chỗ sót**: `dang_dung` khớp
đúng tên trường `GET /roles` trả về, nên client đọc một tên rồi ghi lại chính tên đó.

Bốn luật riêng của đường này:

1. **`code` không nhận, không đổi** (ràng buộc 5). Gửi lên thì 422.
2. **`is_system = true`**: chỉ `name` và `description` đi qua. Gửi `permissions` hoặc
   `dang_dung` thì 422 kèm `fields` nói rõ trường nào bị từ chối và vì sao.
3. **Vai trò admin của một phân vùng còn sống không tắt được** (điểm 5 người dùng chốt).
   Nó nằm trong nhóm `is_system` nên luật 2 đã chặn; ghi ra đây vì đó là lý do nghiệp vụ,
   không phải hệ quả kỹ thuật.
4. **Phân vùng bị ẩn thì vai trò của nó ẩn theo**, và điều đó tự đúng chứ không cần code:
   mọi câu đọc vai trò lọc theo `company_id` của actor (R-06), mà không ai đăng nhập được
   vào một phân vùng đã vô hiệu hoá. Không thêm cột, không thêm phép kiểm - ghi ra đây để
   lần sau không ai đi làm lại nó.
5. **Tắt một vai trò đang có người giữ**: cho phép, nhưng response trả `so_nguoi_giu` để
   màn hỏi lại một câu trước khi gửi. Người đang giữ mất quyền sau tối đa 30 giây
   (ràng buộc 9).

Kiểm tập quyền: hiệu đối xứng giữa tập cũ đọc từ DB và tập mới gửi lên (ràng buộc 2), sau
khi đã loại trừ tập tự tác động (ràng buộc 1). Audit hằng `role.updated`.

### 6.6 Mã lỗi mới

| Mã | Khi nào | Status |
|---|---|---|
| `ERR_AUTH_ROLE_CODE_DUPLICATED` | Unique index `uq_roles_company_id_code` nổ | 409 |
| `ERR_AUTH_ROLE_PERMISSION_UNKNOWN` | Mã quyền không có trong danh mục hằng | 422 |
| `ERR_AUTH_ROLE_PERMISSION_FORBIDDEN` | Mã quyền actor không giữ | 422 |
| `ERR_AUTH_ROLE_SYSTEM_LOCKED` | Sửa tập quyền hoặc tắt một vai trò hệ thống | 422 |

Cả bốn thêm dòng vào bảng mã lỗi và bảng ánh xạ constraint **trong chính PR đó**
(CL-API-08).

## 6bis. Hai lỗ hổng lộ ra lúc dựng kế hoạch - vá trong đợt này

Không có trong bản spec đầu, tìm thấy khi đọc code thật. Cả hai đều làm đợt này rỗng ruột
nếu bỏ qua.

**1. `is_system` phải được đặt ở đường ghi bộ mặc định, không chỉ backfill.** Mục 5 chỉ
backfill các hàng đang có. Một phân vùng mở SAU đợt này đi qua `CreateCompany` ->
`insertVaiTroMacDinhSQL`, câu chèn đó không đụng `is_system`, nên bảy vai trò mặc định của
nó ra đời với `is_system = false`: tắt được, sửa tập quyền được, và `auth.admin` của phân
vùng ấy tự khoá mình ra ngoài được. Cùng lỗ ở `cmd/dev seed-roles`.

**2. `is_active = false` phải cắt quyền ở nguồn `authz`, không chỉ đổi một chữ trên màn.**
Mục 5 hứa người đang giữ mất quyền, nhưng không đường nào ở mục 6 chạm tới
`selectQuyenTheoVaiTroSQL` - câu mà `authz` đọc. Thiếu một mệnh đề `AND r.is_active` ở đó
thì nút Tắt chỉ đổi màu một cái chip. Hai hệ quả phải nhận: thông điệp từ chối lúc gán một
vai trò đã tắt là "vai trò không tồn tại" (chưa thật đúng, chấp nhận đợt này), và
`GET /roles` vẫn liệt kê vai trò đã tắt nên **màn gán phải tự lọc theo `dang_dung`** - việc
đó thuộc kế hoạch frontend.

## 7. Frontend

### 7.1 `VaiTroListPage` - nối API thật

Bỏ `VAI_TRO_MAU`, đọc `GET /roles`. Sáu cột giữ nguyên. Thêm vào ô Thao tác nút **Tắt** /
**Bật** cạnh nút Sửa.

Tắt một vai trò đang có người giữ đi qua **xác nhận hai bước tại chỗ**, đúng lối repo đang
dùng ở `WarehouseListPage` và `CompanyFormPage` - không `window.confirm`, không modal.
Câu hỏi nói đúng con số: "Tắt vai trò này? 12 người đang giữ sẽ mất quyền trong vòng 30
giây."

Vai trò `he_thong_tao = true`: nút Tắt khoá mềm kèm lý do "Vai trò hệ thống, không tắt
được. Tạo một vai trò riêng nếu cần tập quyền khác."

Dải cảnh báo "dữ liệu mẫu" ở đầu màn: xoá. Chip "Xem trước": xoá `xemTruoc: true` ở
`src/app/mat-phan-quyen.ts:17` - một dòng, nhưng có test đang khoá chip, sửa cùng lượt.

### 7.2 `VaiTroFormPage` - thêm khối tích quyền

Trên: Tên, Phân hệ áp dụng, Mô tả, Đang dùng - giữ nguyên. Dưới: khối quyền, nhóm theo
phân hệ rồi theo đối tượng, mỗi nhóm một checkbox cha tích cả nhóm.

Dựng trên `DanhSachChon` đã có (`src/shared/components/DanhSachChon/`) - nó đã có ô lọc,
gom nhóm, số đếm. Thiếu hai thứ, phải thêm vào chính component đó vì cả hai đều là nhu cầu
chung chứ không riêng màn này:

- **Checkbox cha tích cả nhóm**, ba trạng thái: trống / đầy / một phần.
- **Khoá từng dòng kèm lý do** (hôm nay chỉ khoá được toàn bộ danh sách). Dòng
  `cap_duoc: false` hiện mờ, không tích được, lý do đọc được bằng bàn phím.

Một câu cố định dưới khối quyền: "Người đang giữ vai trò này thấy thay đổi sau tối đa 30
giây."

Nút Lưu giữ khuôn khoá mềm kèm lý do đang có. Gỡ hằng `LY_DO_CHUA_CO_DUONG_GHI` và khối
ghi chú `VaiTroFormPage.tsx:34-37` (xem mục 9).

Đặt tên biến: giữ lối `muc` thay vì `vaiTro` để không vướng luật ESLint
`erp/c-ts-06-no-role-guess`.

### 7.3 Test

Bộ test hiện có của hai màn khoá vào dữ liệu mẫu, phải viết lại. Giữ luật của repo: kiểm
bằng `data-*` và class, không bằng chữ - một dòng chữ bị CSS giấu vẫn nằm trong
`textContent`.

Ca bắt buộc có: khoá theo `cap_duoc`, checkbox cha ba trạng thái, xác nhận hai bước khi
tắt vai trò có người giữ, vai trò hệ thống khoá đúng ba thứ và mở đúng hai thứ, và lỗi 422
từ backend tố đúng vào trường.

## 8. Thứ tự thi công

Mỗi bước xanh mới sang bước sau.

1. ADR (mục 9) - vì nó đảo một quyết định đã ghi.
2. Migration `000033` + `000034`, chạy trên dev, đối soát bằng `cmd/dev seed-roles`.
3. Hai mã quyền mới + 50 nhãn tiếng Việt + `GET /permissions`.
4. `GET /roles` mở rộng - frontend chưa đổi vẫn phải chạy nguyên.
5. `POST /roles`, `PATCH /roles/:id`.
6. `DanhSachChon`: checkbox cha + khoá từng dòng, kèm test của riêng nó.
7. `VaiTroFormPage` nối API thật.
8. `VaiTroListPage` nối API thật + nút Tắt/Bật.
9. Gỡ `VAI_TRO_MAU`, gỡ chip "Xem trước", gỡ dải cảnh báo.

Bước 3-5 và bước 6 độc lập nhau, chạy song song được.

## 9. ADR phải mở trước khi gõ dòng code đầu tiên

`VaiTroFormPage.tsx:34-37` có khối ghi chú nói thẳng: **không** có ma trận quyền trên màn
này, vì tick quyền là việc của quản trị module. Đợt này đảo ngược điều đó. Theo
`CLAUDE.md` mục 2, đảo một quyết định đã ghi là ca cần ADR, không phải chỗ sửa lặng lẽ.

ADR mới cần trả lời: ai được đặt ra vai trò (admin phân vùng, không phải quản trị module),
vì sao tập quyền hiện ra bị cắt theo quyền của chính actor, và vì sao vai trò hệ thống
khoá tập quyền.

## 10. Ngoài phạm vi đợt này

- **Xoá hẳn vai trò**: người dùng chốt tắt, không xoá.
- **Vô hiệu hoá nhớ đệm quyền 30 giây**: đợt này nói ra con số trên màn, không sửa cơ chế.
- **Phạm vi dữ liệu** (`PUT /users/:id/scopes`): ADR-0026 nói rõ nới/thu phạm vi không
  dính đường ghi vai trò. Màn vai trò không đụng vào.
- **Vai trò mẫu dùng chung nhiều phân vùng**: đường C đã loại ở mục 3.
