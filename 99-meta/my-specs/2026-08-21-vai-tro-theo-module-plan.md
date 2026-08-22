# Kế hoạch thi công: vai trò theo module (ADR-0021)

> **Cho người thi công:** dùng `superpowers:subagent-driven-development` để thi công từng task.
> Các bước dùng checkbox `- [ ]`.

**Mục tiêu:** Đổi tập vai trò từ ba tên bó ngang sang tám tên mang tiền tố module, thêm quyền
về quyền (`<module>.role_assign`, `<module>.scope_assign`), tách đường gán vai trò thành một
endpoint riêng, và chuyển dữ liệu đang sống — tất cả trong **một bản**.

**Nguồn:** [ADR-0021](../../03-decisions/ADR-0021-vai-tro-theo-module.md) đã `Accepted`.

---

## Điều kiện khung, không được phá

- **Một PR duy nhất cho backend.** Bảng vai trò sống trong code còn `role_code` sống trong dữ
  liệu; tách ra thì có một khoảnh khắc hai bên lệch nhau và mọi thứ đỏ. Frontend đi PR riêng
  được vì nó chỉ đổi nhãn hiển thị.
- **Không đụng** `shared/authz`, `shared/auth`, `arch/checks_ast.go`, `arch/checks_migration.go`,
  `RULES.md`.
- R-15: câu lệnh đầu tiên của mọi method public service là `s.authz.Can`.
- Comment Go viết tiếng Việt không dấu, theo lối đang có của `backend-erp`.
- `cmd/dev test` không chạy được dưới máy (không có Docker). Dưới máy chỉ `go build`, `go vet`,
  `go run ./cmd/dev check`, `arch`. Bằng chứng test lấy từ CI.

## Thứ tự, và vì sao là thứ tự này

Task 1-3 dựng **cơ chế** trên bảng vai trò cũ, và mỗi task xanh độc lập. Task 4 mới đổi tập
tên, và nó phải đi cùng migration cùng test trong một commit vì đó là chỗ dữ liệu và code phải
khớp nhau. Task 5-6 dọn phần còn lại.

Làm ngược lại — đổi tên trước rồi mới dựng cơ chế — thì có một khoảng cả cây test đỏ và không
ai biết đỏ vì lý do gì.

---

## Task 1: Bốn permission mới và danh mục quyền gán

**Files:**
- Modify: `modules/auth/internal/service/permissions.go` — thêm `PermRoleAssign = "auth.role_assign"`
- Modify: `modules/inventory/internal/service/permissions.go` — `PermRoleAssign = "inventory.role_assign"`, `PermScopeAssign = "inventory.scope_assign"`
- Modify: `modules/machine/internal/service/permissions.go` — `PermRoleAssign = "machine.role_assign"`
- Modify: `modules/{auth,inventory,machine}/module.go` — tái xuất (C-GO-08)

- [ ] **Bước 1:** Thêm bốn hằng, mỗi hằng kèm một khối comment nói nó trả lời câu hỏi gì:
  `<module>.role_assign` = "được gán các vai trò THUỘC module này cho người khác";
  `inventory.scope_assign` = "được gán phạm vi trên tài nguyên của module này".

  Nói rõ trong comment vì sao `machine` **không** có `scope_assign`: module đó chưa có bảng chịu
  phạm vi nào, và khai một permission chưa ai dùng tới là khai một chuỗi không request nào đi
  qua (lập luận có sẵn ở đầu `permissions.go` của auth).

- [ ] **Bước 2:** Tái xuất cả bốn ở `module.go` của module tương ứng.

- [ ] **Bước 3:** Kiểm: `go build ./...`, `go run ./cmd/dev check`.

- [ ] **Bước 4:** Commit `feat(authz): bon permission ve quyen gan`.

---

## Task 2: Danh mục quyền gán, tiêm từ composition root

Đây là mục 4 của ADR: module `auth` **tra danh mục**, không ghép chuỗi và không cắt tiền tố.

**Files:**
- Modify: `cmd/internal/vaitro/vaitro.go` — thêm `QuyenGan() map[string]string`
- Modify: `cmd/internal/phamvi/phamvi.go` — `PhamViKhaDung` thêm `PermGan`
- Modify: `modules/auth/module.go` — `Deps` thêm `QuyenGanVaiTro map[string]string`; `PhamViKhaDung` thêm `PermGan`
- Modify: `modules/auth/internal/service/scope_service.go` — `LoaiPhamVi` thêm `PermGan`
- Modify: `cmd/api/main.go`, `cmd/api/e2e_test.go`, `cmd/dev/*` — nối dây

- [ ] **Bước 1:** `vaitro.QuyenGan()` trả về map `role_code` → permission cần có để gán vai trò
  đó. Dựng từ chính hằng permission của module (`inventory.PermRoleAssign`, ...), **không** viết
  chuỗi tay. Trả bản mới mỗi lần gọi, cùng lý do `Bang()` làm thế.

  Ở task này map còn khai theo ba tên cũ (`admin`/`member`/`ky_thuat`) — Task 4 mới đổi tên. Ba
  tên cũ đều là vai trò bó ngang nên tạm ánh xạ về `auth.PermRoleAssign`; kèm một comment nói
  đây là trạng thái tạm và Task 4 thay nó.

- [ ] **Bước 2:** `PhamViKhaDung`/`LoaiPhamVi` thêm trường `PermGan string`, và
  `phamvi.Bang(db)` điền `inventory.PermScopeAssign`.

- [ ] **Bước 3:** Nối dây ở `cmd/api/main.go` và `cmd/api/e2e_test.go`. Chưa ai đọc hai thứ này
  ở task này — đúng, Task 3 mới đọc.

- [ ] **Bước 4:** Kiểm `go build ./...`, `go vet ./...`, `cmd/dev check`. Commit.

---

## Task 3: Endpoint gán vai trò, và phép kiểm module ở hai đường

**Files:**
- Create: `modules/auth/internal/handler/user_role_handler.go`
- Modify: `modules/auth/internal/handler/user_routes.go`, `user_handler.go` (bỏ `roles` khỏi `UpdateUserRequest`)
- Modify: `modules/auth/internal/service/user_service.go` — method mới + `kiemGanVaiTro` nhận danh mục
- Modify: `modules/auth/internal/service/scope_service.go` — kiểm `PermGan` theo từng loại
- Modify: `modules/auth/module.go` — nối handler
- Modify: `modules/auth/internal/service/user_service_test.go`, `scope_service_test.go`

- [ ] **Bước 1: Viết test trước.** Các ca bắt buộc:
  - `PUT /users/:id/roles` với actor thiếu `PermUserAssignRoles` → 403.
  - Actor có cửa nhưng thiếu `<module>.role_assign` của vai trò gửi lên → 403.
  - **Hiệu đối xứng:** người đang có `["auth.admin","inventory.viewer"]`, actor chỉ có
    `inventory.role_assign` gửi `["inventory.viewer"]` → **403**, vì `auth.admin` bị gỡ. Đây là
    test quan trọng nhất của task.
  - Gửi đúng tập đang có (không thêm không bớt) → không đòi permission nào ngoài cửa.
  - `CreateUser` với vai trò của module khác → 403.
  - `ThayPhamVi` với actor thiếu `inventory.scope_assign` → 403.

- [ ] **Bước 2:** Chạy `go vet ./modules/auth/...` để thấy đỏ vì thiếu ký hiệu.

- [ ] **Bước 3: Cài đặt.** `ThayVaiTro` ở service tính hiệu đối xứng:

  ```
  dangCo  := tập role_code còn sống của người đó
  guiLen  := tập trong request
  phaiKiem := (guiLen \ dangCo) ∪ (dangCo \ guiLen)
  với mỗi r trong phaiKiem: Can(actor, quyenGan[r])
  ```

  Vai trò không có trong danh mục → 422 (`VaiTroTonTai` đã lo phần tên không tồn tại; danh mục
  thiếu khoá là lỗi nối dây, trả lỗi nội bộ chứ đừng cho qua).

  `ScopeService.kiemVaChuanHoa` thêm `Can(actor, l.PermGan)` cho mỗi loại có trong thân.

- [ ] **Bước 4:** Kiểm dưới máy, đẩy, **đọc CI thật**. Commit.

---

## Task 4: Đổi tập tên, migration, và toàn bộ test theo sau

Đây là task nặng nhất. **Một commit** mang cả bốn phần dưới đây.

**Files:**
- Modify: `cmd/internal/vaitro/vaitro.go` — tám vai trò, `QuyenGan()` theo tên mới
- Create: `migrations/000024_vai_tro_theo_module.up.sql` + `.down.sql`
- Modify: `cmd/api/e2e_test.go`, `cmd/dev/bootstrap.go`, `cmd/dev/bootstrap_test.go`, `modules/auth/internal/service/*_test.go`
- Modify: `infra-erp/scripts/bootstrap.sh`

- [ ] **Bước 1: Viết test cho migration TRƯỚC khi viết migration.**

  Test dựng dữ liệu đúng hai ca sẽ gãy, rồi chạy migration lên:
  - Một người mang **`member` + `ky_thuat`** trong cùng một phân vùng. Nở từng hàng sẽ sinh
    `machine.viewer` hai lần và đâm vào `uq_user_company_roles_company_id_user_company_id_role_code`.
    Sau migration người đó phải có đúng `{machine.viewer, inventory.viewer, machine.ky_thuat}`.
  - Một hàng `admin` **đã xoá mềm** cạnh một hàng `member` còn sống. Sau migration, hàng đã xoá
    mềm phải giữ nguyên `deleted_at`, và người đó **không** được có hàng admin nào đang sống.
  - Một hàng phạm vi `warehouse` treo trên hàng `member` còn sống. Sau migration nó phải treo
    trên một hàng `inventory.*` **còn sống**, và số phạm vi **có hiệu lực** không đổi.

- [ ] **Bước 2: Bảng vai trò mới** theo đúng mục 2 của ADR — tám khoá. Mỗi nhóm module một khối,
  có comment nói vai trò đó dành cho ai. Nhớ sàn chung ở mục 6: mọi vai trò có `auth.self_read`
  **và** `auth.change_password`.

- [ ] **Bước 3: Migration.** Bốn phần, trong một transaction:

  1. Bảng ánh xạ tạm `(cu, moi)`: `admin`→3, `member`→2, `ky_thuat`→2.
  2. Chèn hàng mới, **`SELECT DISTINCT`** trên tập ảnh của từng cặp (người, phân vùng) — đây là
     chỗ chống hàng trùng, xem ADR mục 9. Chỉ tính từ các hàng **còn sống**.
  3. Chuyển hàng phạm vi: mỗi hàng `user_company_role_scopes` còn sống trỏ về hàng kế thừa của
     module sở hữu `scope_type`, chọn **xác định** bằng `ORDER BY role_code LIMIT 1`. Việc chọn
     hàng nào là tuỳ ý nhưng phải tất định: câu đọc lúc chạy hợp nhất theo người, nên hàng vai
     trò chỉ còn vai trò mốc vòng đời (ADR mục 9).
  4. Xoá mềm các hàng vai trò tên cũ **còn sống**. Hàng tên cũ đã xoá mềm thì để nguyên.

  Rồi ba hậu điều kiện của ADR mục 9, mỗi cái một câu `DO $$ ... RAISE EXCEPTION ... $$`.

- [ ] **Bước 4: `.down.sql`.** Nếu không lùi được thì nói thẳng bằng một `RAISE EXCEPTION` có
  thông điệp giải thích, đừng để một file rỗng giả vờ lùi được.

- [ ] **Bước 5: Sửa mọi chỗ dùng tên cũ.** `vaitro.QuanTri`/`ThanhVien`/`KyThuat` ở e2e;
  chuỗi trần `"member"` ở `cmd/dev/bootstrap_test.go`; cờ `-roles` mặc định ở
  `cmd/dev/bootstrap.go` (đổi sang ba admin của ba module); `ROLES=` ở
  `infra-erp/scripts/bootstrap.sh`.

- [ ] **Bước 6:** `go build`, `go vet`, `cmd/dev check`, `cmd/dev arch`. Đẩy và **đọc CI thật**.

---

## Task 5: Frontend — nhãn vai trò

**Files:** `frontend-erp/src/app/DropdownTaiKhoan.tsx`

- [ ] `NHAN_VAI_TRO` lên tám dòng theo tên mới, và thêm `quan_tri_he_thong` — dòng hôm nay đang
  thiếu, nên một quản trị hệ thống đang thấy chip chữ trần. PR riêng, sau khi backend lên.

---

## Task 6: Tài liệu

**Files:** `docs-erp/04-conventions/C-GO-backend.md`, `docs-erp/03-decisions/ADR-0020-*.md`

- [ ] Thêm một dòng vào C-GO-02 chốt khuôn `<module>.<vai_trò>`; sửa ví dụ `Bang()` trong
  C-GO-08 (`"admin"`/`"sale"`/`"viewer"`) cho khớp khuôn.
- [ ] ADR-0020 mục 1: sửa câu "một người hai vai trò có hai bộ phạm vi tách biệt" — đúng ở
  đường ghi, sai ở đường đọc. Ghi rõ hàng vai trò là **mốc vòng đời**, không phải ngăn chứa.

---

## Ngoài phạm vi

- Màn gán vai trò (endpoint có rồi, màn hình là chặng sau).
- Vẽ lại màn gán phạm vi theo loại thay vì theo hàng vai trò — việc đi kèm sửa ADR-0020, làm
  sau khi tài liệu chốt.
- Chặn `<module>.admin` tự nhân bản quyền quản trị của chính module đó (ADR để ngỏ).
- Loại phạm vi thứ hai và việc chẻ `PUT /users/:id/scopes` theo loại.
