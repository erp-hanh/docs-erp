# Đợt 2b — CRUD vai trò — Backend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Spec:** `docs-erp/99-meta/my-specs/2026-08-27-vai-tro-dot-2b-spec.md` — mục 5, 6, 9. Mục 7 (frontend) là một kế hoạch riêng, không nằm ở đây.

**Goal:** Mở đường ghi vai trò cho admin của một phân vùng: ba cột mới trên `roles`, hai mã quyền mới, một danh mục 50 mã quyền kèm nhãn tiếng Việt, `GET /api/v1/permissions`, `GET /api/v1/roles` mở rộng sáu trường, `POST /api/v1/roles`, `PATCH /api/v1/roles/:id`, bốn mã lỗi mới — tất cả tuân đủ mười ràng buộc ở mục 4 của spec.

**Architecture:** Toàn bộ trong `backend-erp` cộng bốn dòng tài liệu ở `docs-erp`. Ba cột mới nằm trên bảng `roles` đã có (ADR-0023), tập quyền vẫn ở `role_permissions`. Đường ghi mới sống ở một `RoleService` riêng trong `modules/auth/internal/service/`, cạnh `UserService` — cùng package nên nó dùng lại được `moduleCuaQuyen`, `permRoleAssignHauTo`, `hieuDoiXungVaiTro`, `loiThieuQuyenGanModule`, `laUUID`, `maTrungKhoa` mà không đẻ ra bản sao thứ hai của phép gom module. Danh mục 50 nhãn sống ở `cmd/internal/vaitro/` — chỗ duy nhất được biết cả ba module (ADR-0010, ADR-0023 mục 9) — và đi vào module auth qua `Deps`, đúng lối `BoVaiTroMacDinh` và `QuyenTuTacDong` đang đi.

**Tech Stack:** Go 1.26, Gin, sqlx + pgx/v5, golang-migrate, PostgreSQL 16. Không thêm dependency nào — phép bỏ dấu tiếng Việt viết tay bằng bảng rune, KHÔNG kéo `golang.org/x/text` từ indirect lên direct.

**Chạy ở đâu:** mọi lệnh chạy tại `d:/My project web/erp/backend-erp` trừ khi ghi rõ khác.

- `go build ./...`, `go vet ./...`, `go run ./cmd/dev lint`, `go run ./cmd/dev arch` **chạy được dưới Windows** (`arch` cố ý không cần Docker — CLAUDE.md mục 4).
- `go run ./cmd/dev test` **KHÔNG chạy được dưới máy Windows này**: nó gọi `internal/testharness` dựng một container Postgres qua testcontainers. Bằng chứng test xanh lấy từ **CI** (job `test` của `.github/workflows/ci.yml`, bước `go run ./cmd/dev test`) hoặc từ **VPS dev qua ssh bọc `bash -lc`** (Go trên VPS nằm ngoài `PATH` của shell không đăng nhập — đã ghi ở `docs-erp/99-meta/my-specs/2026-08-22-ban-giao-module-kho.md`).
- Test **không chạm database** chạy được dưới Windows bằng bộ lọc `-run`, và mọi Step dưới đây nói rõ bài nào thuộc loại nào.

Hai lệnh bằng chứng, dùng nguyên văn:

```bash
# A. CI - đường chính. Đẩy nhánh rồi đọc job `test`.
git push -u origin feat/vai-tro-dot-2b-backend
gh pr create --draft --title "feat(auth): CRUD vai tro dot 2b" --body "WIP"
gh run watch --exit-status
gh run view --log --job test | tail -60
```

```bash
# B. VPS dev - đường dự phòng khi CI hỏng. Clone RA MỘT THƯ MỤC RIÊNG,
#    tuyệt đối không checkout nhánh lên /opt/erp/backend-erp (đó là cây deploy đang chạy).
ssh dev-erp 'bash -lc "rm -rf /tmp/erp-2b && \
  git clone -q -b feat/vai-tro-dot-2b-backend https://github.com/<chu-repo>/backend-erp.git /tmp/erp-2b && \
  git clone -q https://github.com/<chu-repo>/docs-erp.git /tmp/erp-2b-docs && \
  cd /tmp/erp-2b && ERP_DOCS_PATH=/tmp/erp-2b-docs go run ./cmd/dev test 2>&1 | tail -60"'
```

**Vệ sinh git:** ba repo dùng chung máy. **Cấm `git add -A`.** Mỗi commit liệt kê từng đường dẫn. `backend-erp` làm trên nhánh `feat/vai-tro-dot-2b-backend`; `docs-erp` đang ở `docs/vai-tro-dot-2b-spec` và ở nguyên đó.

---

## File Structure

### `backend-erp` — tạo mới

| File | Trách nhiệm |
|---|---|
| `migrations/000033_add_role_attributes.up.sql` / `.down.sql` | Ba cột `description`, `is_active`, `is_system` trên `roles` |
| `migrations/000034_backfill_role_system_flag.up.sql` / `.down.sql` | Bật `is_system` cho bảy mã mặc định; chèn hai mã quyền mới cho mọi `auth.admin` còn sống |
| `cmd/internal/vaitro/nhan_quyen.go` | Bảng 50 nhãn tiếng Việt + nhóm + phân hệ; hàm `DanhMucQuyenCoNhan()` |
| `cmd/internal/vaitro/nhan_quyen_test.go` | Đối soát hai chiều bảng nhãn ↔ `DanhMucQuyen()`; nhóm và nhãn không rỗng, không trùng |
| `modules/auth/internal/service/role_service.go` | `RoleService`: `DanhMucQuyen`, `TaoVaiTro`, `SuaVaiTro`, `kiemGhiTapQuyen`, sinh mã, dịch lỗi ghi |
| `modules/auth/internal/service/role_service_test.go` | Test không chạm DB của `RoleService` (bảng quyền giả + repo giả) |
| `modules/auth/internal/service/role_service_db_test.go` | Test có ghi của `TaoVaiTro`/`SuaVaiTro` trên PostgreSQL thật (P-TEST) |
| `modules/auth/internal/service/role_ma_test.go` | Test thuần hàm của `boDauTiengViet` và `sinhMaVaiTro` — chạy được dưới Windows |
| `modules/auth/internal/handler/role_handler.go` | `RoleHandler`: `DanhMucQuyen`, `Create`, `Patch`, DTO của cả ba |
| `modules/auth/internal/handler/role_handler_test.go` | Test tầng HTTP: hình dạng JSON, 201/200/422, tên field trong `error.fields` |
| `modules/auth/internal/handler/role_routes.go` | `RegisterRoleRoutes` — ba route mới |
| `modules/auth/internal/repository/role_repository_db_test.go` | Test DB của đường ghi vai trò + hậu điều kiện của 000033/000034 |
| `cmd/api/e2e_vaitro_2b_test.go` | e2e qua ngăn xếp đầy đủ cho ba endpoint mới |

### `backend-erp` — sửa

| File | Việc |
|---|---|
| `modules/auth/internal/service/permissions.go:74` (sau `PermRoleAssign`) | Thêm `PermRoleCreate`, `PermRoleUpdate` |
| `modules/auth/module.go:65-85`, `:99-117`, `:190-199`, `:205-277`, `:303-341`, `:402-410`, `:434-439` | Cửa ra hai hằng mới; thêm vào `MoiQuyen()`; kiểu `QuyenCoNhan`; `Deps.DanhMucQuyen`; dựng `RoleService` + `RoleHandler`; `Register` gọi `RegisterRoleRoutes` |
| `cmd/internal/vaitro/vaitro.go:263-274` (`AuthAdmin`), `:379-396` (`QuanTriHeThong`) | Hai mã quyền mới vào hai vai trò |
| `cmd/internal/vaitro/adr0031_test.go:20-41` | Danh sách `tapQuyenQuanTriHeThong` 16 → 18 mã |
| `cmd/api/main.go:232-250` | Tiêm `DanhMucQuyen: vaitro.DanhMucQuyenCoNhan()` |
| `cmd/dev/bootstrap.go:132-145` | Ghi chú vì sao root này KHÔNG tiêm danh mục (fail-close) |
| `modules/auth/internal/repository/role_repository.go:69-73` | `selectQuyenTheoVaiTroSQL` thêm `AND r.is_active` |
| `modules/auth/internal/repository/role_repository.go:227-232`, `:352-359` | Hai câu chèn bộ mặc định đặt `is_system = true` |
| `modules/auth/internal/repository/role_repository.go:140-191` | Bảy method mới trên `RoleRepository` |
| `modules/auth/internal/repository/role_repository.go:466-550` | `DongDanhMucVaiTro` + sáu trường; hai hằng SQL danh mục |
| `modules/auth/internal/service/user_service.go:152-164` | `VaiTroKhaDung` + sáu trường |
| `modules/auth/internal/service/user_service.go:636-669` | `DanhMucVaiTro` mang sáu trường mới ra |
| `modules/auth/internal/service/user_service.go:1343-1375` | Tách vòng gom module thành `moduleCuaTapQuyen` |
| `modules/auth/internal/handler/user_role_handler.go:59-68`, `:111-120` | `VaiTroKhaDungDTO` + sáu trường |
| `modules/auth/internal/service/user_service_danhmuc_test.go:44-75` | `roleRepoGia` cài bảy method mới |
| `shared/errors/codes.go:66` (sau `CodeAuthCompanyInUse`) | Bốn hằng mã lỗi mới |

### `docs-erp` — sửa (nhánh `docs/vai-tro-dot-2b-spec`, **không commit, không đổi nhánh**)

| File | Việc |
|---|---|
| `03-decisions/ADR-0038-admin-phan-vung-dat-ra-vai-tro.md` | ADR mới (mục 9 của spec) |
| `04-conventions/C-API-http.md:581` | Bốn dòng vào bảng mã lỗi C-API-05 |
| `04-conventions/C-API-http.md:700` | Một dòng vào bảng ánh xạ constraint |

---

## Task 1: Nhánh và vạch xuất phát

**Files:** không sửa file nào.

- [ ] **Step 1: Dựng nhánh**

```bash
cd "d:/My project web/erp/backend-erp"
git status --short
git checkout -b feat/vai-tro-dot-2b-backend
```

`git status --short` có file lạ của phiên khác thì **dừng lại và báo** — cây làm việc dùng chung, không cuốn thay đổi của người khác vào nhánh này.

- [ ] **Step 2: Chốt vạch xuất phát dưới máy**

```bash
go build ./...
go vet ./...
go run ./cmd/dev lint
go run ./cmd/dev arch
```

Bốn lệnh này phải sạch trước khi gõ dòng code đầu tiên, và phải sạch lại sau mỗi task. Đỏ ngay ở đây thì báo, đừng sửa — đó là việc của phiên khác.

- [ ] **Step 3: Chốt vạch xuất phát của bộ test**

Đẩy nhánh rỗng lên rồi đọc job `test` của CI (lệnh A ở phần "Chạy ở đâu"), hoặc chạy lệnh B trên VPS dev. Ghi lại **số test xanh** và dán vào ghi chú bàn giao. Mọi task sau so với con số này.

---

## Task 2: ADR-0038 — admin phân vùng đặt ra vai trò

**Files:**
- Create: `docs-erp/03-decisions/ADR-0038-admin-phan-vung-dat-ra-vai-tro.md`
- Modify: `backend-erp/cmd/internal/vaitro/adr0031_test.go:20-41`

ADR đi **trước** mọi dòng code, vì nó đảo hai quyết định đã ghi: khối ghi chú `VaiTroFormPage.tsx:34-37` nói thẳng "không có ma trận quyền trên màn này, vì tick quyền là việc của quản trị module"; và ADR-0031 mục 1 khoá tập quyền của `quan_tri_he_thong` ở đúng mười sáu mã, `TestQuanTriHeThongDungMuoiSauQuyen` là hiện thân bằng máy của mệnh đề đó.

- [ ] **Step 1: Viết ADR-0038 theo mẫu `05-templates/ADR-template.md`**

Bốn câu hỏi bắt buộc trả lời, không được để trống câu nào:

1. **Ai được đặt ra vai trò.** Admin của phân vùng (`auth.role_create`/`auth.role_update`), không phải quản trị module. Lý do: `<module>.admin` không có `auth.role_assign`, nên theo ADR-0024 mục 2 họ không ghi nổi một tập quyền chạm module `auth` — mà mọi vai trò đều mang sàn chung. Đặt cửa ở `auth.*` là đặt nó đúng chỗ nó đã nằm sẵn.
2. **Vì sao tập quyền hiện ra bị cắt theo quyền của chính actor.** `cap_duoc: false` là *hệ quả đọc được* của ADR-0024 mục 2 chứ không phải một luật mới: actor không có `<module>.role_assign` thì không ghi nổi mã của module đó, nên bày một ô tick bấm được rồi trả 403 là một vòng mạng để nhận một câu trả lời đã biết trước. Nói thẳng: **ẩn nút là UX, không phải bảo mật** — backend vẫn từ chối một mã `cap_duoc: false` gửi lên.
3. **Vì sao vai trò hệ thống khoá tập quyền.** Admin sửa tập quyền của chính vai trò đang cho họ quyền quản trị là đường ngắn nhất để tự khoá mình ra ngoài phân vùng, và không ai trong phân vùng sửa lại được. Tên và mô tả vẫn sửa được vì chúng không cấp quyền cho ai.
4. **Đính chính ADR-0031 mục 1: mười sáu → mười tám mã.** ADR là bất biến nên câu chữ của ADR-0031 không sửa tại chỗ; ADR-0038 ghi rõ hai mã được thêm (`auth.role_create`, `auth.role_update`), vì sao chúng không phải "một cửa sau vào dữ liệu vận hành" theo tiêu chí ADR-0031 mục 2 (chúng chỉ chạm hai bảng `roles`/`role_permissions` **của phân vùng actor đang đứng**, không mở thêm đường đọc nghiệp vụ nào), và trỏ đích danh `cmd/internal/vaitro/adr0031_test.go` là chỗ phải sửa cùng đợt. Lý do bằng lời của người dùng: *"quản trị hệ thống cũng phải tự thêm được vai trò"*.

Thêm một mục **Consequences** nói ra ba cái giá, không giấu:

- Nhớ đệm quyền 30 giây (`shared/authz/nguon_db.go`, `nhipHetHan`) làm mọi thay đổi tập quyền chỉ nhìn thấy sau tối đa 30 giây. Đợt này **nói câu đó trên màn**, không bổ sung invalidate.
- `is_active = false` cắt vai trò khỏi nguồn đọc của `authz`, nên người đang giữ mất quyền — và cùng một dòng đó làm vai trò tắt không gán mới được. Thông điệp từ chối lúc gán khi đó là `vai tro khong ton tai`, một câu chưa thật đúng; đổi nó đòi thêm một lần đọc `is_active` mỗi vai trò và không được làm ở đợt này.
- `GET /roles` là **một** endpoint phục vụ cả màn quản trị lẫn màn gán, nên nó trả cả vai trò đã tắt. Màn gán phải tự lọc theo `dang_dung` — đó là lọc theo **dữ liệu backend trả về**, không phải suy diễn quyền, nên nó không vướng `erp/c-ts-06-no-role-guess`.

- [ ] **Step 2: Nối ADR vào sổ**

Thêm một dòng cho ADR-0038 vào `docs-erp/03-decisions/README.md`, đúng khuôn các dòng đang có.

- [ ] **Step 3: KHÔNG commit `docs-erp`**

Repo `docs-erp` đang ở nhánh `docs/vai-tro-dot-2b-spec`. Để nguyên trong cây làm việc, không `git commit`, không `git checkout`. Chạy `git -C "d:/My project web/erp/docs-erp" status --short` và xác nhận đúng ba file đang đổi (ADR mới, README, và về sau là `C-API-http.md`).

- [ ] **Step 4: Sửa danh sách khoá của ADR-0031**

Trong `cmd/internal/vaitro/adr0031_test.go`, thêm hai chuỗi vào `tapQuyenQuanTriHeThong` (khối dòng 20-41) và cập nhật khối ghi chú của `TestQuanTriHeThongDungMuoiSauQuyen`:

```go
	"auth.role_create",
	"auth.role_update",
```

Đổi câu "lai dung bang muoi sau ma" thành "lai dung bang muoi tam ma", và thêm một câu: *"Muoi sau -> muoi tam ngay 2026-08-27 theo ADR-0038; ADR-0031 la bat bien nen phep dinh chinh nam o ADR-0038 chu khong o cau chu cua no."* Tên hàm giữ nguyên — đổi tên một bài test đang được ADR gọi đích danh là làm mất sợi dây nối.

---

## Task 3: Migration 000033 — ba cột trên `roles`

**Files:**
- Create: `backend-erp/migrations/000033_add_role_attributes.up.sql`
- Create: `backend-erp/migrations/000033_add_role_attributes.down.sql`

- [ ] **Step 1: Viết file `up`**

```sql
-- 000033: ba cot thuoc tinh cua mot vai tro (dot 2b muc 5).
--
-- Bang roles cua 000025 co dung hai cot nghiep vu: code va name. Man quan tri vai tro dang
-- hien bon cot ma ba trong so do khong co nguon that duoi database - Mo ta, Dang giu, Trang
-- thai - va dot nay bo hai trong ba xuong day. Cot thu ba (Dang giu) KHONG thanh mot cot: no
-- la mot phep dem tren user_company_roles, va mot cot dem la mot ban sao se lech.
--
-- KHONG them cot `module`. Module cua mot vai tro suy tu role_permissions, luon luon
-- (ADR-0024 muc 1 va muc 3). Mot cot module o day se la mot nguon thu hai tra loi cung cau
-- hoi, va nguon do do quan tri go tay - dung thu ADR-0024 cam moi phep kiem quyen doc toi.
--
-- KHONG them index moi tren bang nay: moi cau doc van loc theo company_id roi sap theo code,
-- va uq_roles_company_id_code phuc vu ca hai (R-09). is_active KHONG duoc index: cot hai gia
-- tri, va C-DB-05 noi thang mot index nhu vay khong loc duoc gi.
--
-- # Thu tu cot khong theo C-DB-03, va do la gioi han cua ALTER chu khong phai mot lua chon
--
-- C-DB-03 xep cot theo id -> company_id -> nghiep vu -> thoi gian -> audit. ALTER TABLE ADD
-- COLUMN cua PostgreSQL luon noi vao CUOI, nen ba cot nghiep vu nay nam sau created_by/
-- updated_by. Dua chung ve dung cho doi dung lai ca bang - mot thao tac khoa bang khong doi
-- lay gi ngoai thu tu hien ra trong `\d roles`. 000019 da chap nhan dung dieu nay khi them
-- users.phone.
--
-- Khong cau BEGIN/COMMIT nao: golang-migrate chay ca file bang MOT ExecContext khong tham so
-- va PostgreSQL boc chuoi nhieu cau lenh cua simple query vao MOT transaction ngam.

ALTER TABLE roles ADD COLUMN description TEXT    NOT NULL DEFAULT '';

-- DEFAULT true chu khong false: moi hang dang co la mot vai tro DANG DUNG. Mot lan migrate
-- lam tat sach vai tro cua moi phan vung la mot he khong ai lam duoc gi, va khong dong log
-- nao noi ra dieu do.
ALTER TABLE roles ADD COLUMN is_active BOOLEAN NOT NULL DEFAULT true;

-- DEFAULT false chu khong true: gia tri mac dinh phai dung cho hang duoc tao SAU migration
-- nay - tuc vai tro do quan tri tu dat ra. Bay vai tro mac dinh cua cac phan vung DANG CO
-- duoc bat rieng o 000034; duong ghi bo mac dinh dat true tuong minh trong cau chen cua no.
ALTER TABLE roles ADD COLUMN is_system BOOLEAN NOT NULL DEFAULT false;
```

- [ ] **Step 2: Viết file `down`**

```sql
-- Lui 000033: tra lai ba cot.
--
-- destructive: rollback lam mat du lieu cot description, is_active, is_system. Khong nguon
-- nao khac trong he dung lai duoc chung - mo ta la chu nguoi quan tri go, va co bat/tat la
-- mot quyet dinh van hanh. Muon du lieu ve thi phuc hoi tu backup, khong phai tu file nay.
--
-- # Thu tu deploy khi lui
--
-- Lui BACKEND truoc, lui migration sau. Nguoc lai thi co mot khoang backend moi - ban doc
-- roles.is_active trong selectQuyenTheoVaiTroSQL - dang chay tren mot schema khong con cot
-- do, va MOI lan nap bang phan quyen vo voi 42703, tuc moi request co kiem quyen deu 500.
--
-- Thu tu ba dong nguoc voi chieu len, thuan mat doc chu khong vi mot rang buoc nao: khong
-- cot nao trong ba phu thuoc cot nao.
--
-- Khong IF EXISTS, cung ly do 000029 va 000032 da ghi: cot khong con o do nghia la schema da
-- lech khoi lich su migration, va do la thu phai no ra chu khong phai thu bo qua im lang.

ALTER TABLE roles DROP COLUMN is_system;
ALTER TABLE roles DROP COLUMN is_active;
ALTER TABLE roles DROP COLUMN description;
```

- [ ] **Step 3: Chạy bộ kiểm kiến trúc — nó đọc migration**

```bash
go run ./cmd/dev arch
```

Expected: xanh. `checks_migration.go` đọc `migrations/` để dựng kho index và kho cột; một file `.up.sql` không có `.down.sql` đi kèm làm R-07 đỏ ngay tại đây (`arch/checks_migration.go:750`).

- [ ] **Step 4: Commit**

```bash
git add migrations/000033_add_role_attributes.up.sql migrations/000033_add_role_attributes.down.sql
git commit -m "feat(db): them description, is_active, is_system vao bang roles

Ba cột thuộc tính của một vai trò, theo mục 5 của spec đợt 2b. Không thêm cột
module: module của một vai trò suy từ role_permissions (ADR-0024 mục 1).

Refs: docs-erp/99-meta/my-specs/2026-08-27-vai-tro-dot-2b-spec.md"
```

---

## Task 4: Migration 000034 — backfill cờ hệ thống và hai mã quyền mới

**Files:**
- Create: `backend-erp/migrations/000034_backfill_role_system_flag.up.sql`
- Create: `backend-erp/migrations/000034_backfill_role_system_flag.down.sql`

Một migration làm một việc (C-DB-06), nên DDL ở 000033 và dữ liệu ở đây. Hai việc trong file này đi chung vì chúng cùng một mệnh đề: *đưa các phân vùng đang chạy về đúng trạng thái mà một phân vùng mở sau đợt này sẽ có ngay từ đầu.*

- [ ] **Step 1: Viết file `up`**

```sql
-- 000034: dua cac phan vung DANG CHAY ve dung trang thai ma mot phan vung mo sau dot 2b se
-- co ngay tu dau (dot 2b muc 5).
--
-- Hai viec, mot menh de. Viec thu hai la mot BAY DA BAT DUOC TRUOC KHI NO CAN, va no dang
-- doc ky: dot nay them hai ma quyen moi vao bo mac dinh cua auth.admin, nhung ADR-0027 muc 2
-- chot rang he thong KHONG BAO GIO ghi de role_permissions cua mot vai tro DA TON TAI - tap
-- quyen do la du lieu cua cong ty. Nen `cmd/dev seed-roles` se KHONG nap hai ma nay cho phan
-- vung nao dang song: no bo qua tron ven moi hang roles da co. Khong co backfill nay thi
-- admin cua MOI phan vung hien huu khong mo duoc chinh man vua lam ra, va trieu chung la mot
-- 403 tren mot man vua deploy xong.
--
-- Khong BEGIN/COMMIT: xem ghi chu cung ten o 000033.

-- ============ PHAN 1: bat is_system cho bay ma mac dinh ============
--
-- deleted_at IS NULL la R-18: hang BIA MO mang mot trong bay ma - vi du mot phan vung da xoa
-- vai tro ho khong dung - khong phai mot vai tro he thong dang song, va bat co tren no chi
-- lam mot hang khong ai doc mang mot gia tri khong ai doc.
--
-- `AND is_system = false` khong thua: no lam cau nay khong cham hang nao da dung, nen so hang
-- UPDATE tra ve dem duoc, va chay lai migration tren mot database da chay roi khong doi
-- updated_at cua ai. Tinh idempotent do la thu ADR-0027 muc 8 doi o moi duong nap bu.
--
-- updated_by la SYSTEM ACTOR - hang cua registry C-DB-04, giong 000022, 000024 va 000025:
-- khong co nguoi that nao dung sau thao tac nay, va cot do NOT NULL (R-17).
UPDATE roles
   SET is_system  = true,
       updated_at = now(),
       updated_by = '00000000-0000-4000-8000-000000000001'::uuid
 WHERE code IN ('auth.admin', 'inventory.admin', 'inventory.thu_kho', 'inventory.viewer',
                'machine.admin', 'machine.viewer', 'machine.ky_thuat')
   AND deleted_at IS NULL
   AND is_system = false;

-- ============ PHAN 2: hai ma quyen moi cho moi auth.admin con song ============
--
-- ON CONFLICT chu khong NOT EXISTS, va menh de WHERE trong ON CONFLICT la BAT BUOC:
-- uq_role_permissions_company_id_role_id_permission_code la PARTIAL index
-- (WHERE deleted_at IS NULL), nen PostgreSQL chi suy ra duoc no khi cau lenh nhac lai dung
-- vi tu ay. Thieu menh de do thi cau bao "there is no unique or exclusion constraint matching
-- the ON CONFLICT specification" - mot loi lo ra ngay luc chay, khong am tham.
--
-- CHI auth.admin, khong phai quan_tri_he_thong: vai tro dan xuat KHONG BAO GIO co hang trong
-- bang roles (ADR-0023 muc 3), tap quyen cua no o lai trong code va di ra qua
-- vaitro.KemVaiTroDanXuat. Mot hang cho no o day la pha dung bat bien do.
--
-- r.deleted_at IS NULL: mot hang bia mo mang ma auth.admin khong cap quyen cho ai, nen cap
-- them hai ma cho no la ghi vao cho khong ai doc.
INSERT INTO role_permissions (company_id, role_id, permission_code, created_by, updated_by)
SELECT r.company_id, r.id, p.permission_code,
       '00000000-0000-4000-8000-000000000001'::uuid,
       '00000000-0000-4000-8000-000000000001'::uuid
FROM roles r
CROSS JOIN (VALUES
    ('auth.role_create'),
    ('auth.role_update')
) AS p(permission_code)
WHERE r.code = 'auth.admin' AND r.deleted_at IS NULL
ON CONFLICT (company_id, role_id, permission_code) WHERE deleted_at IS NULL DO NOTHING;

-- ============ PHAN 3: hau dieu kien ============
--
-- Thieu cai nao thi dung va khong commit mot nua. Mot migration phan quyen hong nua chung la
-- mot he ma khong ai biet no dang o trang thai nao.

DO $$
DECLARE thieu BIGINT;
BEGIN
    SELECT count(*) INTO thieu
      FROM roles
     WHERE deleted_at IS NULL
       AND is_system = false
       AND code IN ('auth.admin', 'inventory.admin', 'inventory.thu_kho', 'inventory.viewer',
                    'machine.admin', 'machine.viewer', 'machine.ky_thuat');
    IF thieu > 0 THEN
        RAISE EXCEPTION 'migration 000034: con % hang roles con song mang ma mac dinh ma is_system van false.', thieu;
    END IF;
END $$;

-- Hau dieu kien thu HAI: moi auth.admin con song phai co DU hai ma quyen moi.
--
-- Khoi tren khong bat duoc ca nay - no chi hoi ve co is_system - va do la ve DE HONG hon
-- trong hai ve: mot phan vung thieu hai ma quyen la mot phan vung co man phan quyen tra 403,
-- trong khi mot phan vung thieu co is_system chi la mot nut Tat bam duoc nham.
DO $$
DECLARE thieu TEXT;
BEGIN
    SELECT string_agg(format('phan vung %s thieu %s', r.company_id, p.ma), E'\n  ' ORDER BY r.company_id, p.ma)
      INTO thieu
    FROM roles r
    CROSS JOIN (VALUES ('auth.role_create'), ('auth.role_update')) AS p(ma)
    WHERE r.code = 'auth.admin' AND r.deleted_at IS NULL
      AND NOT EXISTS (
          SELECT 1 FROM role_permissions rp
           WHERE rp.company_id = r.company_id AND rp.role_id = r.id
             AND rp.permission_code = p.ma AND rp.deleted_at IS NULL);

    IF thieu IS NOT NULL THEN
        RAISE EXCEPTION 'migration 000034: hai ma quyen moi chua toi duoc moi auth.admin con song:%', E'\n  ' || thieu;
    END IF;
END $$;
```

- [ ] **Step 2: Viết file `down`**

```sql
-- Lui 000034: tat co is_system cua bay ma, va xoa MEM hai ma quyen do chinh migration nay chen.
--
-- # Vi sao xoa MEM chu khong DELETE
--
-- R-18 liet DELETE FROM tren mot bang co deleted_at la dau hieu vi pham, va ngoai le doi mot
-- ADR tro toi dung ten bang - khong ADR nao cho phep hard delete role_permissions. Xoa mem
-- de lai hai hang bia mo cho moi phan vung; chay lai chieu len sau do chen HAI HANG MOI chu
-- khong hoi sinh hang cu, vi partial unique index chi phu deleted_at IS NULL nen khong co
-- dung do. Do la ket qua dung: mot lan lui roi len lai khong duoc phep phu thuoc vao viec ai
-- do dung day hang bia mo.
--
-- # Vi sao dieu kien created_by = system actor
--
-- Sau khi dot 2b chay, mot quan tri CO THE da tu tick hai ma nay vao mot vai tro do ho tao,
-- va nhung hang do KHONG phai thu migration nay sinh ra. Buoc lui chi duoc go lai dung thu no
-- da ghi; go rong hon la xoa du lieu cua khach hang trong mot thao tac ho khong yeu cau.
-- Dieu kien `r.code = 'auth.admin'` cong `created_by = system actor` khoanh dung tap do.

UPDATE role_permissions rp
   SET deleted_at = now(),
       updated_at = now(),
       updated_by = '00000000-0000-4000-8000-000000000001'::uuid
  FROM roles r
 WHERE r.id = rp.role_id
   AND r.code = 'auth.admin'
   AND rp.permission_code IN ('auth.role_create', 'auth.role_update')
   AND rp.created_by = '00000000-0000-4000-8000-000000000001'::uuid
   AND rp.deleted_at IS NULL;

-- Tat co cho dung bay ma, khong dung mot cau UPDATE vo dieu kien: mot vai tro do quan tri
-- tao ra khong bao gio co is_system = true (duong ghi cua dot 2b luon dat false), nhung mot
-- cau vo dieu kien o day se la mot cau dung cho hom nay va sai vao ngay co loai vai tro he
-- thong thu hai.
UPDATE roles
   SET is_system  = false,
       updated_at = now(),
       updated_by = '00000000-0000-4000-8000-000000000001'::uuid
 WHERE code IN ('auth.admin', 'inventory.admin', 'inventory.thu_kho', 'inventory.viewer',
                'machine.admin', 'machine.viewer', 'machine.ky_thuat')
   AND is_system = true;
```

- [ ] **Step 3: Viết test đỏ cho hậu điều kiện của cả hai migration**

Tạo `modules/auth/internal/repository/role_repository_db_test.go`. Database của test chép từ `erp_template`, mà template đã chạy hết migration — nên hai bài dưới đây đo đúng thứ 000033 và 000034 để lại trên phân vùng seed của 000001.

```go
package repository_test

import (
	"testing"

	"erp/internal/testutil"
)

// TestMigration000034_BayVaiTroMacDinhLaVaiTroHeThong do dung phan 1 cua 000034 tren du lieu
// that ma template de lai.
//
// Bai nay o tang repository chu khong o internal/migrator: migrator_test.go do CO CHE lui/len
// cua golang-migrate, con day do KET QUA cua mot migration cu the tren schema that. Hai cau
// hoi khac nhau, va gop lai thi mot bai do co che se do vi mot du lieu doi.
func TestMigration000034_BayVaiTroMacDinhLaVaiTroHeThong(t *testing.T) {
	db := testutil.Connect(t)

	bayMa := []string{
		"auth.admin", "inventory.admin", "inventory.thu_kho", "inventory.viewer",
		"machine.admin", "machine.viewer", "machine.ky_thuat",
	}

	var thieu int
	const q = `
SELECT count(*) FROM roles
 WHERE deleted_at IS NULL AND is_system = false AND code = ANY($1)`
	if err := db.Get(&thieu, q, bayMa); err != nil {
		t.Fatalf("dem vai tro mac dinh chua bat is_system: %v", err)
	}
	if thieu != 0 {
		t.Errorf("con %d hang roles mac dinh con song mang is_system = false - migration 000034 phan 1 chua toi", thieu)
	}
}

// TestMigration000034_AuthAdminCoHaiMaQuyenMoi do phan 2 - ve de hong hon trong hai ve.
//
// Thieu no thi admin cua moi phan vung hien huu nhan 403 tren chinh man vua deploy, va
// ADR-0027 muc 2 bao dam rang `seed-roles` se KHONG chua ho.
func TestMigration000034_AuthAdminCoHaiMaQuyenMoi(t *testing.T) {
	db := testutil.Connect(t)

	for _, ma := range []string{"auth.role_create", "auth.role_update"} {
		var thieu int
		const q = `
SELECT count(*) FROM roles r
 WHERE r.code = 'auth.admin' AND r.deleted_at IS NULL
   AND NOT EXISTS (SELECT 1 FROM role_permissions rp
                    WHERE rp.company_id = r.company_id AND rp.role_id = r.id
                      AND rp.permission_code = $1 AND rp.deleted_at IS NULL)`
		if err := db.Get(&thieu, q, ma); err != nil {
			t.Fatalf("dem auth.admin thieu %s: %v", ma, err)
		}
		if thieu != 0 {
			t.Errorf("%d hang auth.admin con song thieu ma quyen %q - migration 000034 phan 2 chua toi", thieu, ma)
		}
	}
}

// TestMigration000033_BaCotCoMatVaCoMacDinhDung do DDL cua 000033.
//
// Doc information_schema chu khong doc mot hang du lieu: gia tri mac dinh la thu quyet dinh
// hang duoc chen SAU nay ra sao, va khong hang nao dang co noi ho dieu do.
func TestMigration000033_BaCotCoMatVaCoMacDinhDung(t *testing.T) {
	db := testutil.Connect(t)

	muon := map[string]string{
		"description": "''::text",
		"is_active":   "true",
		"is_system":   "false",
	}
	for cot, macDinh := range muon {
		var thuc string
		const q = `
SELECT coalesce(column_default, '') FROM information_schema.columns
 WHERE table_name = 'roles' AND column_name = $1`
		if err := db.Get(&thuc, q, cot); err != nil {
			t.Fatalf("doc mac dinh cua roles.%s: %v", cot, err)
		}
		if thuc != macDinh {
			t.Errorf("roles.%s mac dinh = %q, muon %q", cot, thuc, macDinh)
		}
	}
}
```

- [ ] **Step 4: Chạy để thấy nó xanh trên CI**

Đẩy nhánh và đọc job `test` (lệnh A). Ba bài trên phải xanh. Đỏ ở `TestMigration000034_AuthAdminCoHaiMaQuyenMoi` nghĩa là mệnh đề `ON CONFLICT ... WHERE deleted_at IS NULL` chưa suy ra đúng partial index — đọc lại thông điệp của PostgreSQL trước khi sửa gì.

- [ ] **Step 5: Commit**

```bash
git add migrations/000034_backfill_role_system_flag.up.sql \
        migrations/000034_backfill_role_system_flag.down.sql \
        modules/auth/internal/repository/role_repository_db_test.go
git commit -m "feat(db): backfill is_system va hai ma quyen moi cho phan vung dang chay

ADR-0027 mục 2 cấm hệ thống ghi đè role_permissions của một vai trò đã tồn tại,
nên seed-roles sẽ không nạp hai mã mới cho phân vùng nào đang sống. Không có
backfill này thì admin của mọi phân vùng hiện có nhận 403 trên màn vừa làm ra."
```

---

## Task 5: Hai mã quyền mới `auth.role_create` và `auth.role_update`

**Files:**
- Modify: `backend-erp/modules/auth/internal/service/permissions.go` (sau dòng 74)
- Modify: `backend-erp/modules/auth/module.go:65-85` và `:99-117`
- Modify: `backend-erp/cmd/internal/vaitro/vaitro.go:263-274` và `:379-396`
- Test: `backend-erp/cmd/internal/vaitro/vaitro_test.go` (bài mới)

- [ ] **Step 1: Viết test đỏ trước**

Thêm vào cuối `cmd/internal/vaitro/vaitro_test.go`:

```go
// TestHaiMaQuyenVaiTroChiCapChoHaiVaiTroQuanTri khoa muc 6.1 cua spec dot 2b: hai ma moi vao
// dung auth.admin va quan_tri_he_thong, khong vao vai tro nao khac.
//
// Do CA HAI chieu, va chieu thu hai la chieu dat: mot bai chi kiem "auth.admin co hai ma nay"
// van xanh khi ai do cap chung cho ca inventory.thu_kho - va luc do mot thu kho dat ra duoc
// vai tro moi cho ca phan vung.
func TestHaiMaQuyenVaiTroChiCapChoHaiVaiTroQuanTri(t *testing.T) {
	haiMa := []string{auth.PermRoleCreate, auth.PermRoleUpdate}
	duocCap := map[string]bool{vaitro.AuthAdmin: true, vaitro.QuanTriHeThong: true}

	for maVaiTro, quyen := range vaitro.Bang() {
		co := map[string]bool{}
		for _, p := range quyen {
			co[p] = true
		}
		for _, ma := range haiMa {
			if duocCap[maVaiTro] && !co[ma] {
				t.Errorf("vai tro %q THIEU %q - spec dot 2b muc 6.1 doi no", maVaiTro, ma)
			}
			if !duocCap[maVaiTro] && co[ma] {
				t.Errorf("vai tro %q CAM %q. Chi auth.admin va quan_tri_he_thong duoc dat ra vai tro moi; "+
					"cap ma nay cho mot vai tro khac la mo duong tu nang quyen trong phan vung.", maVaiTro, ma)
			}
		}
	}
}
```

- [ ] **Step 2: Chạy cho thấy đỏ**

```bash
go test ./cmd/internal/vaitro/ -run 'TestHaiMaQuyenVaiTro' -v
```

Expected: **lỗi biên dịch** `undefined: auth.PermRoleCreate`. Đó là đỏ đúng loại — đúng cơ chế mà khối ghi chú đầu `cmd/internal/vaitro/vaitro.go` mô tả: đổi một permission ở đây là một lỗi biên dịch.

- [ ] **Step 3: Khai hai hằng ở module sở hữu**

Vào `modules/auth/internal/service/permissions.go`, ngay sau hằng `PermRoleAssign` (dòng 74):

```go
// PermRoleCreate va PermRoleUpdate gac DUONG GHI vai tro cua dot 2b.
//
// Chung KHONG gop voi PermRoleAssign, va viec tach la toan bo gia tri cua chung:
// PermRoleAssign tra loi "duoc PHAT vai tro cua module auth cho nguoi khac", con hai ma nay
// tra loi "duoc DAT RA mot vai tro moi trong phan vung nay". Gop lai nghia la moi
// <module>.admin - nhung nguoi giu <module>.role_assign - deu che duoc mot vai tro moi, va
// tap quyen cua vai tro do la thu ho tu tick.
//
// KHONG co PermRoleDelete: nguoi dung chot "tat, khong xoa" (spec dot 2b muc 2), nen khong co
// duong xoa nao de gac. Them mot hang o day cho mot duong khong ton tai la mo san mot quyen
// nam im cho toi khi co nguoi tuong no co nghia.
const (
	PermRoleCreate = "auth.role_create"
	PermRoleUpdate = "auth.role_update"
)
```

- [ ] **Step 4: Mở cửa ra ở package gốc**

Trong `modules/auth/module.go`, thêm vào khối hằng (sau `PermRoleAssign`, dòng 84):

```go
	// PermRoleCreate / PermRoleUpdate gac duong ghi vai tro cua dot 2b (ADR-0038). Ly do day
	// du o modules/auth/internal/service/permissions.go.
	PermRoleCreate = service.PermRoleCreate
	PermRoleUpdate = service.PermRoleUpdate
```

và vào `MoiQuyen()` (sau `PermRoleAssign`, dòng 115):

```go
		PermRoleCreate,
		PermRoleUpdate,
```

- [ ] **Step 5: Cấp cho hai vai trò trong bảng phân quyền**

Trong `cmd/internal/vaitro/vaitro.go`, khối `AuthAdmin` (dòng 263-274) thêm sau `auth.PermRoleAssign`:

```go
			// Hai ma cua dot 2b: admin cua phan vung tu dat ra vai tro roi tu tich quyen cho
			// nhan vien trong phan vung do (ADR-0038). Chung nam o auth.admin chu khong o
			// <module>.admin vi moi vai tro deu mang san chung cua module auth, nen ADR-0024
			// muc 2 doi auth.role_assign cho gan nhu moi lan ghi mot tap quyen - va chi
			// auth.admin voi quan_tri_he_thong co ma do.
			auth.PermRoleCreate,
			auth.PermRoleUpdate,
```

và khối `QuanTriHeThong` (dòng 379-396) thêm sau `machine.PermRoleAssign`:

```go
			// Hai ma cua dot 2b. Chung KHONG pha lap luan cua ADR-0031 muc 2 - "khong permission
			// van hanh nao cua module duoc them vao day": hai ma nay cham dung hai bang roles va
			// role_permissions CUA PHAN VUNG ACTOR DANG DUNG, va chung khong mo them mot duong
			// doc du lieu van hanh nao. ADR-0038 ghi ro phep dinh chinh muoi sau -> muoi tam.
			auth.PermRoleCreate,
			auth.PermRoleUpdate,
```

- [ ] **Step 6: Chạy cho thấy xanh**

```bash
go build ./...
go test ./cmd/internal/vaitro/ ./modules/auth/ -v
go run ./cmd/dev arch
```

Cả `TestHaiMaQuyenVaiTroChiCapChoHaiVaiTroQuanTri`, `TestQuanTriHeThongDungMuoiSauQuyen`, `TestDanhMucQuyen_PhuHetBang` và `TestMoiQuyen*` phải xanh. Ba package này **không chạm database**, nên bước này chạy được dưới Windows.

- [ ] **Step 7: Commit**

```bash
git add modules/auth/internal/service/permissions.go modules/auth/module.go \
        cmd/internal/vaitro/vaitro.go cmd/internal/vaitro/vaitro_test.go
git commit -m "feat(auth): them hai ma quyen auth.role_create va auth.role_update

Cấp cho auth.admin và quan_tri_he_thong. Tập quyền của vai trò dẫn xuất đi từ
mười sáu lên mười tám mã — phép đính chính ADR-0031 mục 1 ghi ở ADR-0038."
```

---

## Task 6: Đường ghi bộ mặc định đặt `is_system = true`

**Files:**
- Modify: `backend-erp/modules/auth/internal/repository/role_repository.go:227-232` (`insertVaiTroMacDinhSQL`) và `:352-359` (`insertVaiTroConThieuSQL`)
- Test: `backend-erp/modules/auth/internal/repository/role_repository_db_test.go`

**Lỗ hổng này KHÔNG có trong spec, và nó nuốt mất một nửa của migration 000034.** 000034 bật `is_system` cho các hàng *đang có*. Một phân vùng mở **sau** đợt này đi qua `CreateCompany` → `NapBoMacDinh` → `insertVaiTroMacDinhSQL`, và câu chèn đó không đụng tới cột `is_system`, nên bảy vai trò mặc định của nó ra đời với `is_system = false`: nút Tắt mở, tập quyền sửa được, và `auth.admin` của phân vùng ấy tự khoá mình ra ngoài được. Cùng lỗ ở `NapBuVaiTroConThieu` — tức `cmd/dev seed-roles`.

- [ ] **Step 1: Viết test đỏ trước**

Thêm vào `modules/auth/internal/repository/role_repository_db_test.go`:

```go
// TestNapBoMacDinh_DatCoHeThong chot rang mot phan vung MO SAU dot 2b co bay vai tro he thong
// ngay tu luc mo, khong cho mot lan backfill nao.
//
// Khong co bai nay thi migration 000034 chi dung cho nhung phan vung ton tai vao dung ngay no
// chay, va moi phan vung sinh ra sau do mang bay vai tro tat duoc - trong khi diem 5 nguoi dung
// chot noi thang: phan vung con song thi vai tro admin cua no khong tat duoc.
func TestNapBoMacDinh_DatCoHeThong(t *testing.T) {
	db := testutil.Connect(t)
	ctx := context.Background()

	congTyID := themCongTyTest(t, db)
	repo := repository.NewRoleRepository()

	bo := []repository.VaiTroMacDinh{
		{Ma: "auth.admin", Nhan: "Quản trị người dùng", Quyen: []string{"auth.user_list"}},
		{Ma: "inventory.viewer", Nhan: "Xem kho vận", Quyen: []string{"inventory.item_list"}},
	}
	if err := repo.NapBoMacDinh(ctx, db, congTyID, auth.SystemActorID, bo); err != nil {
		t.Fatalf("NapBoMacDinh: %v", err)
	}

	var chuaBat int
	const q = `SELECT count(*) FROM roles WHERE company_id = $1 AND deleted_at IS NULL AND is_system = false`
	if err := db.Get(&chuaBat, q, congTyID); err != nil {
		t.Fatalf("dem vai tro chua bat is_system: %v", err)
	}
	if chuaBat != 0 {
		t.Errorf("%d/%d vai tro mac dinh vua nap mang is_system = false - mot phan vung moi mo se tat duoc chinh vai tro admin cua no", chuaBat, len(bo))
	}
}

// TestNapBuVaiTroConThieu_DatCoHeThong la ban doi xung cho duong `cmd/dev seed-roles`.
//
// Hai duong ghi, hai cau SQL, nen mot bai cho duong nay khong noi gi ve duong kia - va duong
// nap bu la duong chay tren database cua khach hang sau MOI lan trien khai (ADR-0027 muc 6).
func TestNapBuVaiTroConThieu_DatCoHeThong(t *testing.T) {
	db := testutil.Connect(t)
	ctx := context.Background()

	congTyID := themCongTyTest(t, db)
	repo := repository.NewRoleRepository()

	bo := []repository.VaiTroMacDinh{
		{Ma: "machine.viewer", Nhan: "Xem thiết bị", Quyen: []string{"machine.list"}},
	}
	daNap, err := repo.NapBuVaiTroConThieu(ctx, db, congTyID, auth.SystemActorID, bo)
	if err != nil {
		t.Fatalf("NapBuVaiTroConThieu: %v", err)
	}
	if len(daNap) != 1 {
		t.Fatalf("nap bu %d vai tro, muon 1", len(daNap))
	}

	var heThong bool
	const q = `SELECT is_system FROM roles WHERE company_id = $1 AND code = 'machine.viewer' AND deleted_at IS NULL`
	if err := db.Get(&heThong, q, congTyID); err != nil {
		t.Fatalf("doc is_system cua vai tro vua nap bu: %v", err)
	}
	if !heThong {
		t.Error("vai tro vua nap bu mang is_system = false - seed-roles dang de lai vai tro mac dinh tat duoc")
	}
}

// themCongTyTest chen mot phan vung RIENG cho bai test dang chay va tra ve id cua no.
//
// Phan vung rieng chu khong dung phan vung seed cua 000001: hai bai o file nay ghi vao bang
// roles, va ghi vao phan vung seed se lam chung phu thuoc thu tu chay lan nhau.
func themCongTyTest(t *testing.T, db *sqlx.DB) string {
	t.Helper()
	const q = `
INSERT INTO companies (code, name, created_by, updated_by)
VALUES ($1, $1, '00000000-0000-4000-8000-000000000001'::uuid,
                '00000000-0000-4000-8000-000000000001'::uuid)
RETURNING id`
	var id string
	ma := "TEST-" + uuid.NewString()[:8]
	if err := db.Get(&id, q, ma); err != nil {
		t.Fatalf("tao phan vung test %s: %v", ma, err)
	}
	return id
}
```

- [ ] **Step 2: Chạy cho thấy đỏ (CI hoặc VPS)**

Expected: hai bài đỏ với `2/2 vai tro mac dinh vua nap mang is_system = false` và `vai tro vua nap bu mang is_system = false`.

- [ ] **Step 3: Sửa hai câu chèn**

`insertVaiTroMacDinhSQL` (dòng 227-232) — thêm cột và giá trị, giữ nguyên mọi thứ khác:

```go
// is_system = true la mot HANG trong cau chen chu khong phai gia tri mac dinh cua cot: cot do
// mac dinh false, va false la gia tri dung cho vai tro do QUAN TRI tu dat ra (dot 2b). Bo mac
// dinh thi nguoc lai - no do he thong nap, va diem 5 nguoi dung chot rang vai tro admin cua
// mot phan vung con song thi khong tat duoc. Migration 000034 chi bat co cho cac phan vung DA
// TON TAI; dong nay la thu lo cho moi phan vung mo SAU do.
const insertVaiTroMacDinhSQL = `
INSERT INTO roles (company_id, code, name, is_system, created_by, updated_by)
SELECT c.id, moi.code, moi.name, true, $2::uuid, $2::uuid
FROM companies c
CROSS JOIN (SELECT unnest($3::text[]) AS code, unnest($4::text[]) AS name) AS moi
WHERE c.id = $1 AND c.deleted_at IS NULL`
```

`insertVaiTroConThieuSQL` (dòng 352-359) — cùng một sửa, giữ nguyên `NOT EXISTS` và `RETURNING code`:

```go
const insertVaiTroConThieuSQL = `
INSERT INTO roles (company_id, code, name, is_system, created_by, updated_by)
SELECT c.id, moi.code, moi.name, true, $2::uuid, $2::uuid
FROM companies c
CROSS JOIN (SELECT unnest($3::text[]) AS code, unnest($4::text[]) AS name) AS moi
WHERE c.id = $1 AND c.deleted_at IS NULL
  AND NOT EXISTS (SELECT 1 FROM roles r WHERE r.company_id = c.id AND r.code = moi.code)
RETURNING code`
```

- [ ] **Step 4: Chạy cho thấy xanh, rồi commit**

```bash
go run ./cmd/dev arch    # dưới Windows
# rồi CI hoặc VPS cho bộ test
git add modules/auth/internal/repository/role_repository.go \
        modules/auth/internal/repository/role_repository_db_test.go
git commit -m "fix(auth): duong ghi bo vai tro mac dinh dat is_system = true

Migration 000034 chỉ bật cờ cho phân vùng đã tồn tại. Không có hai dòng này thì
mọi phân vùng mở sau đợt 2b nhận bảy vai trò mặc định tắt được — trái điểm 5 mà
người dùng đã chốt."
```

---

## Task 7: `is_active = false` cắt vai trò khỏi nguồn đọc của `authz`

**Files:**
- Modify: `backend-erp/modules/auth/internal/repository/role_repository.go:69-73` (`selectQuyenTheoVaiTroSQL`)
- Test: `backend-erp/modules/auth/internal/repository/role_repository_db_test.go`

**Cũng không có trong spec mục 6, nhưng mục 5 hứa nó:** bảng cột nói `is_active = false` nghĩa là *"không gán mới được, người đang giữ mất quyền"*. Cả hai vế đó nằm ở đúng một dòng SQL — nguồn mà `authz` đọc để dựng bảng phân quyền của phân vùng. Không có dòng đó, nút Tắt đổi đúng một chữ trên màn hình và không đổi gì trong hệ.

- [ ] **Step 1: Viết test đỏ trước**

```go
// TestQuyenTheoVaiTro_BoVaiTroDaTat chot ca hai ve ma cot is_active hua.
//
// Nguon nay la thu authz.NewTuNguon nap vao nho dem, va CA BA cau tra loi cua Checker deu doc
// tu no: Can, VaiTroTonTai, QuyenCuaVaiTro. Nen mot dong `AND r.is_active` o day lam ba viec
// cung luc - nguoi dang giu mat quyen, vai tro tat khong gan moi duoc, va no bien khoi tam
// tham quyen - thay vi ba phep kiem rai o ba tang.
//
// Cai gia, do luon o bai duoi: vai tro tat bien mat khoi map nen VaiTroTonTai noi KHONG, va
// duong gan tra ve thong diep "vai tro khong ton tai" thay vi mot cau ve trang thai tat.
// Doi cau do doi mot lan doc is_active cho TUNG vai tro trong vong loc cua GET /roles - mot
// vong toi database cho moi dong - nen no o ngoai pham vi dot nay va duoc ghi o ADR-0038.
func TestQuyenTheoVaiTro_BoVaiTroDaTat(t *testing.T) {
	db := testutil.Connect(t)
	ctx := context.Background()

	congTyID := themCongTyTest(t, db)
	testutil.TaoVaiTroKemQuyen(t, db, congTyID, "kho.thu_kho_ca_dem", "inventory.movement_create")

	nguon := repository.NewNguonQuyen(db)

	bang, err := nguon.QuyenTheoVaiTro(ctx, congTyID)
	if err != nil {
		t.Fatalf("QuyenTheoVaiTro truoc khi tat: %v", err)
	}
	if len(bang["kho.thu_kho_ca_dem"]) != 1 {
		t.Fatalf("truoc khi tat, vai tro co %d quyen, muon 1 - tien de cua bai nay sai", len(bang["kho.thu_kho_ca_dem"]))
	}

	const tat = `UPDATE roles SET is_active = false WHERE company_id = $1 AND code = $2`
	if _, err := db.Exec(tat, congTyID, "kho.thu_kho_ca_dem"); err != nil {
		t.Fatalf("tat vai tro: %v", err)
	}

	bang, err = nguon.QuyenTheoVaiTro(ctx, congTyID)
	if err != nil {
		t.Fatalf("QuyenTheoVaiTro sau khi tat: %v", err)
	}
	if _, con := bang["kho.thu_kho_ca_dem"]; con {
		t.Error("vai tro da tat van con trong bang phan quyen - nguoi dang giu no khong mat quyen nao, va nut Tat chi doi mot chu tren man hinh")
	}
}
```

- [ ] **Step 2: Chạy cho thấy đỏ (CI hoặc VPS)**

- [ ] **Step 3: Thêm đúng một mệnh đề**

`selectQuyenTheoVaiTroSQL` (dòng 69-73) — thêm `AND r.is_active` vào mệnh đề `WHERE`, và một đoạn vào khối ghi chú ngay trên nó:

```go
// `r.is_active` la ve THU BA cua bo loc, ngang hang voi company_id va deleted_at, va no den tu
// dot 2b: mot vai tro bi TAT phai bien mat khoi day. Ca ba cau tra loi cua authz.Checker deu
// nap tu ham nay, nen mot dong duy nhat lam ca ba viec ma cot is_active hua: nguoi dang giu
// mat quyen (sau toi da 30 giay, dung nhip nhoDem), vai tro tat khong gan moi duoc
// (VaiTroTonTai noi KHONG), va no khong con keo theo cua module nao.
//
// KHONG loc is_active o duong doc DANH MUC (selectDanhMucVaiTro*SQL ben duoi): man quan tri
// phai thay ca vai tro da tat de bat lai duoc. Hai cau doc cung mot bang tra loi hai cau hoi
// khac nhau, va do la ly do chung khong dung chung mot bo loc.
const selectQuyenTheoVaiTroSQL = `
SELECT r.code, p.permission_code
FROM roles r
JOIN role_permissions p ON p.role_id = r.id AND p.company_id = $1 AND p.deleted_at IS NULL
WHERE r.company_id = $1 AND r.deleted_at IS NULL AND r.is_active`
```

- [ ] **Step 4: Chạy cho thấy xanh, rồi commit**

```bash
git add modules/auth/internal/repository/role_repository.go \
        modules/auth/internal/repository/role_repository_db_test.go
git commit -m "feat(auth): vai tro tat bien khoi nguon doc cua authz

Một mệnh đề `AND r.is_active` làm cả hai vế mà cột hứa: người đang giữ mất quyền
sau tối đa 30 giây, và vai trò tắt không gán mới được."
```

---

## Task 8: Bảng 50 nhãn tiếng Việt

**Files:**
- Create: `backend-erp/cmd/internal/vaitro/nhan_quyen.go`
- Create: `backend-erp/cmd/internal/vaitro/nhan_quyen_test.go`
- Modify: `backend-erp/modules/auth/module.go:190-199` (thêm kiểu `QuyenCoNhan` cạnh `VaiTroMacDinh`)

**Spec mục 6.2 nói "48 mã". Con số thật sau Task 5 là 50** — `auth.MoiQuyen()` 15 + 2 mới = 17, `inventory.MoiQuyen()` 20, `machine.MoiQuyen()` 13. Bốn mươi tám là số mã *trước* đợt này. Bảng dưới đây phủ đủ 50; bài test ở Step 3 đối soát hai chiều nên con số không cần chép tay ở đâu cả.

- [ ] **Step 1: Khai kiểu ở package gốc của module auth**

`modules/auth/module.go`, ngay sau kiểu `VaiTroMacDinh` (dòng 199):

```go
// QuyenCoNhan mo ta MOT ma quyen kem thu con nguoi doc duoc ve no: nhan tieng Viet, nhom doi
// tuong, va phan he so huu.
//
// # Vi sao no phai di ra qua day
//
// Cung ly do voi VaiTroMacDinh va PhamViKhaDung ngay tren: bang nhan goi ten hang permission
// cua CA BA module, ma R-05 cam module auth phu thuoc inventory hay machine.
// cmd/internal/vaitro la noi duy nhat biet du ba phia, va quy tac internal/ cua Go chan
// modules/ import no - nen chieu di chi co the la vaitro -> auth, va kieu phai khai o day.
//
// # Vi sao nhan song o Go chu khong o frontend
//
// Them mot ma quyen o backend ma quen sua bang nhan ben frontend thi man hinh hien mot ma tran
// kieu `inventory.movement_create` cho nguoi khong lam ky thuat doc. Mot nguon, mot cho sua
// (spec dot 2b muc 6.2).
type QuyenCoNhan struct {
	// Ma la gia tri that cua cot role_permissions.permission_code, vi du "inventory.item_create".
	Ma string

	// Nhan la chu hien tren o tick, vi du "Thêm vật tư".
	Nhan string

	// Nhom gom cac ma theo DOI TUONG chu khong theo dong tu: "Danh mục vật tư", khong phai
	// "Thêm". Nhom theo dong tu cho ra mot man hinh ma moi nhom deu co mot dong cua moi doi
	// tuong, tuc khong gom duoc gi.
	Nhom string

	// PhanHe la ten module so huu ma quyen, suy tu chinh tien to cua Ma.
	PhanHe string

	// NhanPhanHe la chu hien cho phan he, lay tu ten UNG DUNG that trong he
	// (frontend-erp/src/app/ung-dung.ts): "Kho vận", "Thiết bị", "Quản trị hệ thống".
	NhanPhanHe string
}
```

- [ ] **Step 2: Viết test đỏ trước**

`cmd/internal/vaitro/nhan_quyen_test.go`:

```go
package vaitro_test

import (
	"strings"
	"testing"

	"erp/cmd/internal/vaitro"
)

// TestDanhMucQuyenCoNhan_DoiSoatHaiChieuVoiDanhMucQuyen la bai dat nhat cua file nay.
//
// Hai chieu, va chieu thu hai la chieu that su giu: mot ma co trong DanhMucQuyen() ma thieu
// nhan se hien ra man hinh duoi dang mot chuoi tran; mot nhan cho mot ma khong con ton tai la
// mot o tick khong bao giờ luu duoc. Ca hai deu im lang neu chi do mot chieu.
func TestDanhMucQuyenCoNhan_DoiSoatHaiChieuVoiDanhMucQuyen(t *testing.T) {
	coNhan := map[string]bool{}
	for _, q := range vaitro.DanhMucQuyenCoNhan() {
		if coNhan[q.Ma] {
			t.Errorf("ma quyen %q co HAI dong nhan - mot ma se hien hai lan tren man tich quyen", q.Ma)
		}
		coNhan[q.Ma] = true
	}

	coThat := map[string]bool{}
	for _, ma := range vaitro.DanhMucQuyen() {
		coThat[ma] = true
		if !coNhan[ma] {
			t.Errorf("ma quyen %q khong co nhan tieng Viet - no se hien ra man hinh duoi dang mot chuoi tran", ma)
		}
	}
	for ma := range coNhan {
		if !coThat[ma] {
			t.Errorf("nhan cho ma %q ma ma do khong co trong DanhMucQuyen() - mot o tich khong bao gio luu duoc", ma)
		}
	}
}

// TestDanhMucQuyenCoNhan_BonTruongDeuCoGiaTri chan mot dong chep thieu.
//
// Nhan rong cho ra mot o tich khong chu; nhom rong cho ra mot nhom khong ten om moi ma bi bo
// sot. Ca hai deu la loi khong lam vo build va chi lo ra tren man hinh.
func TestDanhMucQuyenCoNhan_BonTruongDeuCoGiaTri(t *testing.T) {
	for _, q := range vaitro.DanhMucQuyenCoNhan() {
		if q.Nhan == "" || q.Nhom == "" || q.PhanHe == "" || q.NhanPhanHe == "" {
			t.Errorf("ma %q: nhan=%q nhom=%q phan_he=%q nhan_phan_he=%q - khong truong nao duoc rong",
				q.Ma, q.Nhan, q.Nhom, q.PhanHe, q.NhanPhanHe)
		}
	}
}

// TestDanhMucQuyenCoNhan_PhanHeLaTienToCuaMa chot rang PhanHe khong go tay lech khoi Ma.
//
// Cat tien to cua mot MA QUYEN la an toan (ADR-0024 muc 1) - ma quyen chi nhan gia tri trong
// danh muc hang - nen bai nay do duoc dieu ma khong bai nao khac do: mot dong chep tu dong
// tren xuong roi quen doi truong PhanHe.
func TestDanhMucQuyenCoNhan_PhanHeLaTienToCuaMa(t *testing.T) {
	for _, q := range vaitro.DanhMucQuyenCoNhan() {
		i := strings.IndexByte(q.Ma, '.')
		if i <= 0 {
			t.Errorf("ma %q khong co tien to module", q.Ma)
			continue
		}
		if q.Ma[:i] != q.PhanHe {
			t.Errorf("ma %q khai phan he %q, tien to cua no la %q", q.Ma, q.PhanHe, q.Ma[:i])
		}
	}
}

// TestDanhMucQuyenCoNhan_TraSliceMoi chot cung bat bien ma Bang() va QuyenTuTacDong() giu: mot
// slice dung chung van la thu ai cung sua duoc.
func TestDanhMucQuyenCoNhan_TraSliceMoi(t *testing.T) {
	a := vaitro.DanhMucQuyenCoNhan()
	if len(a) == 0 {
		t.Fatal("danh muc rong")
	}
	a[0].Nhan = "da bi sua"
	if vaitro.DanhMucQuyenCoNhan()[0].Nhan == "da bi sua" {
		t.Error("DanhMucQuyenCoNhan tra ve chung mot slice giua hai lan goi")
	}
}
```

- [ ] **Step 3: Chạy cho thấy đỏ**

```bash
go test ./cmd/internal/vaitro/ -run 'TestDanhMucQuyenCoNhan'
```

Expected: lỗi biên dịch `undefined: vaitro.DanhMucQuyenCoNhan`.

- [ ] **Step 4: Viết bảng nhãn**

`cmd/internal/vaitro/nhan_quyen.go`:

```go
package vaitro

import "erp/modules/auth"

// Nhan cua ba PHAN HE, lay tu ten UNG DUNG that trong he: frontend-erp/src/app/ung-dung.ts.
//
// Khong dat mot ten thu ba o day - "Quan tri kho" chang han - vi mot cai ten khong co trong
// giao dien nao la mot cai ten nguoi dung khong doi chieu duoc voi thu ho dang nhin. Do la
// dung lo hong ma khoi ghi chu cua nhanMacDinh() da ke: hai bang nhan, mot lan lech, va cung
// mot vai tro mang hai ten o hai man hinh.
const (
	nhanPhanHeAuth      = "Quản trị hệ thống"
	nhanPhanHeInventory = "Kho vận"
	nhanPhanHeMachine   = "Thiết bị"
)

// Muoi mot NHOM, gom theo DOI TUONG chu khong theo dong tu (spec dot 2b muc 6.2).
//
// Gom theo dong tu - "Xem", "Thêm", "Xoá" - cho ra mot man hinh ma moi nhom deu chua mot dong
// cua moi doi tuong, tuc khong gom duoc gi va nguoi tich phai doc het 50 dong. Gom theo doi
// tuong thi mot nguoi muon mo quyen kho cho nhan vien chi doc mot nhom.
const (
	nhomKho        = "Kho hàng"
	nhomVatTu      = "Danh mục vật tư"
	nhomSoNhapXuat = "Sổ nhập xuất"
	nhomTonKho     = "Tồn kho"
	nhomDonViTinh  = "Đơn vị tính"
	nhomNguoiDung  = "Người dùng"
	nhomPhanVung   = "Phân vùng"
	nhomPhanQuyen  = "Phân quyền"
	nhomThietBi    = "Thiết bị"
	nhomBaoTri     = "Kế hoạch bảo trì"
	nhomSuCo       = "Sự cố"
)

// DanhMucQuyenCoNhan tra ve MOI ma quyen cua he, moi ma kem nhan tieng Viet, nhom doi tuong va
// phan he so huu.
//
// # Vi sao no o day chu khong o mot bang o frontend
//
// Cung ly do voi Bang() va DanhMucQuyen() ngay ben canh: day la cho duy nhat biet ca ba module
// (ADR-0023 muc 9). Va vi mot ly do rieng cua chinh no - spec dot 2b muc 6.2: them mot ma quyen
// o backend ma quen sua bang nhan ben frontend thi man hinh hien ra mot ma tran kieu
// `inventory.movement_create` cho nguoi khong lam ky thuat doc, va khong gi bao ra.
//
// # Ma lay tu HANG, khong go tay
//
// Moi truong Ma duoi day la mot hang cua module so huu, dung ky luat ma khoi ghi chu dau file
// vaitro.go dat ra: xoa hay doi ten mot hang permission lam VO BUILD o day. Go tay chuoi thi
// mot lan doi ten lam mot dong nhan tro ve hu vo, va TestDanhMucQuyenCoNhan_DoiSoatHaiChieu...
// se do - nhung do la mot lan do sau, con loi bien dich thi do ngay.
//
// Tra ve mot slice MOI moi lan goi, cung ly do Bang() lam vay.
func DanhMucQuyenCoNhan() []auth.QuyenCoNhan {
	return []auth.QuyenCoNhan{
		// --- auth: Người dùng ---
		{Ma: auth.PermUserList, Nhan: "Xem danh sách người dùng", Nhom: nhomNguoiDung, PhanHe: "auth", NhanPhanHe: nhanPhanHeAuth},
		{Ma: auth.PermUserRead, Nhan: "Xem chi tiết một người dùng", Nhom: nhomNguoiDung, PhanHe: "auth", NhanPhanHe: nhanPhanHeAuth},
		{Ma: auth.PermUserCreate, Nhan: "Thêm người dùng", Nhom: nhomNguoiDung, PhanHe: "auth", NhanPhanHe: nhanPhanHeAuth},
		{Ma: auth.PermUserUpdate, Nhan: "Sửa hồ sơ người dùng", Nhom: nhomNguoiDung, PhanHe: "auth", NhanPhanHe: nhanPhanHeAuth},
		{Ma: auth.PermUserDelete, Nhan: "Xoá người dùng", Nhom: nhomNguoiDung, PhanHe: "auth", NhanPhanHe: nhanPhanHeAuth},
		{Ma: auth.PermAuthSelfRead, Nhan: "Xem hồ sơ của chính mình", Nhom: nhomNguoiDung, PhanHe: "auth", NhanPhanHe: nhanPhanHeAuth},
		{Ma: auth.PermAuthChangePassword, Nhan: "Đổi mật khẩu của chính mình", Nhom: nhomNguoiDung, PhanHe: "auth", NhanPhanHe: nhanPhanHeAuth},

		// --- auth: Phân vùng ---
		{Ma: auth.PermCompanyList, Nhan: "Xem danh sách phân vùng", Nhom: nhomPhanVung, PhanHe: "auth", NhanPhanHe: nhanPhanHeAuth},
		{Ma: auth.PermCompanyRead, Nhan: "Xem chi tiết một phân vùng", Nhom: nhomPhanVung, PhanHe: "auth", NhanPhanHe: nhanPhanHeAuth},
		{Ma: auth.PermCompanyCreate, Nhan: "Mở phân vùng mới", Nhom: nhomPhanVung, PhanHe: "auth", NhanPhanHe: nhanPhanHeAuth},
		{Ma: auth.PermCompanyUpdate, Nhan: "Sửa tên phân vùng", Nhom: nhomPhanVung, PhanHe: "auth", NhanPhanHe: nhanPhanHeAuth},
		{Ma: auth.PermCompanyDelete, Nhan: "Vô hiệu hoá phân vùng", Nhom: nhomPhanVung, PhanHe: "auth", NhanPhanHe: nhanPhanHeAuth},

		// --- auth: Phân quyền ---
		{Ma: auth.PermUserAssignRoles, Nhan: "Gán vai trò cho người dùng", Nhom: nhomPhanQuyen, PhanHe: "auth", NhanPhanHe: nhanPhanHeAuth},
		{Ma: auth.PermUserAssignScopes, Nhan: "Gán phạm vi dữ liệu cho người dùng", Nhom: nhomPhanQuyen, PhanHe: "auth", NhanPhanHe: nhanPhanHeAuth},
		{Ma: auth.PermRoleAssign, Nhan: "Phát vai trò mang quyền của phân hệ Quản trị hệ thống", Nhom: nhomPhanQuyen, PhanHe: "auth", NhanPhanHe: nhanPhanHeAuth},
		{Ma: auth.PermRoleCreate, Nhan: "Đặt ra vai trò mới", Nhom: nhomPhanQuyen, PhanHe: "auth", NhanPhanHe: nhanPhanHeAuth},
		{Ma: auth.PermRoleUpdate, Nhan: "Sửa vai trò và bật tắt vai trò", Nhom: nhomPhanQuyen, PhanHe: "auth", NhanPhanHe: nhanPhanHeAuth},

		// --- inventory: Kho hàng ---
		{Ma: inventory.PermWarehouseList, Nhan: "Xem danh sách kho", Nhom: nhomKho, PhanHe: "inventory", NhanPhanHe: nhanPhanHeInventory},
		{Ma: inventory.PermWarehouseRead, Nhan: "Xem chi tiết một kho", Nhom: nhomKho, PhanHe: "inventory", NhanPhanHe: nhanPhanHeInventory},
		{Ma: inventory.PermWarehouseCreate, Nhan: "Mở kho mới", Nhom: nhomKho, PhanHe: "inventory", NhanPhanHe: nhanPhanHeInventory},
		{Ma: inventory.PermWarehouseUpdate, Nhan: "Sửa thông tin kho", Nhom: nhomKho, PhanHe: "inventory", NhanPhanHe: nhanPhanHeInventory},
		{Ma: inventory.PermWarehouseDelete, Nhan: "Đóng kho", Nhom: nhomKho, PhanHe: "inventory", NhanPhanHe: nhanPhanHeInventory},
		{Ma: inventory.PermWarehouseScopeAll, Nhan: "Thấy mọi kho, không giới hạn theo phạm vi được cấp", Nhom: nhomKho, PhanHe: "inventory", NhanPhanHe: nhanPhanHeInventory},

		// --- inventory: Danh mục vật tư ---
		{Ma: inventory.PermItemList, Nhan: "Xem danh sách vật tư", Nhom: nhomVatTu, PhanHe: "inventory", NhanPhanHe: nhanPhanHeInventory},
		{Ma: inventory.PermItemRead, Nhan: "Xem chi tiết một vật tư", Nhom: nhomVatTu, PhanHe: "inventory", NhanPhanHe: nhanPhanHeInventory},
		{Ma: inventory.PermItemCreate, Nhan: "Thêm vật tư", Nhom: nhomVatTu, PhanHe: "inventory", NhanPhanHe: nhanPhanHeInventory},
		{Ma: inventory.PermItemUpdate, Nhan: "Sửa vật tư", Nhom: nhomVatTu, PhanHe: "inventory", NhanPhanHe: nhanPhanHeInventory},
		{Ma: inventory.PermItemDelete, Nhan: "Xoá vật tư", Nhom: nhomVatTu, PhanHe: "inventory", NhanPhanHe: nhanPhanHeInventory},

		// --- inventory: Sổ nhập xuất ---
		{Ma: inventory.PermMovementList, Nhan: "Xem sổ nhập xuất", Nhom: nhomSoNhapXuat, PhanHe: "inventory", NhanPhanHe: nhanPhanHeInventory},
		{Ma: inventory.PermMovementRead, Nhan: "Xem chi tiết một dòng nhập xuất", Nhom: nhomSoNhapXuat, PhanHe: "inventory", NhanPhanHe: nhanPhanHeInventory},
		{Ma: inventory.PermMovementCreate, Nhan: "Ghi một dòng nhập xuất", Nhom: nhomSoNhapXuat, PhanHe: "inventory", NhanPhanHe: nhanPhanHeInventory},
		{Ma: inventory.PermMovementDelete, Nhan: "Xoá một dòng nhập xuất", Nhom: nhomSoNhapXuat, PhanHe: "inventory", NhanPhanHe: nhanPhanHeInventory},

		// --- inventory: Tồn kho ---
		{Ma: inventory.PermBalanceRead, Nhan: "Xem tồn kho", Nhom: nhomTonKho, PhanHe: "inventory", NhanPhanHe: nhanPhanHeInventory},

		// --- inventory: Đơn vị tính ---
		{Ma: inventory.PermUnitList, Nhan: "Xem danh mục đơn vị tính", Nhom: nhomDonViTinh, PhanHe: "inventory", NhanPhanHe: nhanPhanHeInventory},
		{Ma: inventory.PermUnitCreate, Nhan: "Thêm đơn vị tính dùng chung toàn hệ", Nhom: nhomDonViTinh, PhanHe: "inventory", NhanPhanHe: nhanPhanHeInventory},

		// --- inventory: Phân quyền ---
		{Ma: inventory.PermRoleAssign, Nhan: "Phát vai trò mang quyền của phân hệ Kho vận", Nhom: nhomPhanQuyen, PhanHe: "inventory", NhanPhanHe: nhanPhanHeInventory},
		{Ma: inventory.PermScopeAssign, Nhan: "Cấp phạm vi kho cho người dùng", Nhom: nhomPhanQuyen, PhanHe: "inventory", NhanPhanHe: nhanPhanHeInventory},

		// --- machine: Thiết bị ---
		{Ma: machine.PermMachineList, Nhan: "Xem danh sách thiết bị", Nhom: nhomThietBi, PhanHe: "machine", NhanPhanHe: nhanPhanHeMachine},
		{Ma: machine.PermMachineRead, Nhan: "Xem lý lịch một thiết bị", Nhom: nhomThietBi, PhanHe: "machine", NhanPhanHe: nhanPhanHeMachine},
		{Ma: machine.PermMachineCreate, Nhan: "Thêm thiết bị", Nhom: nhomThietBi, PhanHe: "machine", NhanPhanHe: nhanPhanHeMachine},
		{Ma: machine.PermMachineUpdate, Nhan: "Sửa lý lịch thiết bị", Nhom: nhomThietBi, PhanHe: "machine", NhanPhanHe: nhanPhanHeMachine},
		{Ma: machine.PermMachineDelete, Nhan: "Thanh lý thiết bị", Nhom: nhomThietBi, PhanHe: "machine", NhanPhanHe: nhanPhanHeMachine},

		// --- machine: Kế hoạch bảo trì ---
		{Ma: machine.PermPlanList, Nhan: "Xem danh sách kế hoạch bảo trì", Nhom: nhomBaoTri, PhanHe: "machine", NhanPhanHe: nhanPhanHeMachine},
		{Ma: machine.PermPlanRead, Nhan: "Xem chi tiết một kế hoạch bảo trì", Nhom: nhomBaoTri, PhanHe: "machine", NhanPhanHe: nhanPhanHeMachine},
		{Ma: machine.PermPlanCreate, Nhan: "Lập kế hoạch bảo trì", Nhom: nhomBaoTri, PhanHe: "machine", NhanPhanHe: nhanPhanHeMachine},
		{Ma: machine.PermPlanUpdate, Nhan: "Sửa kế hoạch bảo trì", Nhom: nhomBaoTri, PhanHe: "machine", NhanPhanHe: nhanPhanHeMachine},
		{Ma: machine.PermPlanExecute, Nhan: "Bắt đầu, hoàn thành hoặc huỷ một ca bảo trì", Nhom: nhomBaoTri, PhanHe: "machine", NhanPhanHe: nhanPhanHeMachine},

		// --- machine: Sự cố ---
		{Ma: machine.PermBreakdownRead, Nhan: "Xem nhật ký sự cố", Nhom: nhomSuCo, PhanHe: "machine", NhanPhanHe: nhanPhanHeMachine},
		{Ma: machine.PermBreakdownCreate, Nhan: "Ghi một sự cố", Nhom: nhomSuCo, PhanHe: "machine", NhanPhanHe: nhanPhanHeMachine},

		// --- machine: Phân quyền ---
		{Ma: machine.PermRoleAssign, Nhan: "Phát vai trò mang quyền của phân hệ Thiết bị", Nhom: nhomPhanQuyen, PhanHe: "machine", NhanPhanHe: nhanPhanHeMachine},
	}
}
```

- [ ] **Step 5: Chạy cho thấy xanh**

```bash
go test ./cmd/internal/vaitro/ -v
go run ./cmd/dev arch
```

Cả bốn bài mới phải xanh. Package này không chạm database — chạy được dưới Windows.

- [ ] **Step 6: Commit**

```bash
git add cmd/internal/vaitro/nhan_quyen.go cmd/internal/vaitro/nhan_quyen_test.go modules/auth/module.go
git commit -m "feat(auth): bang nhan tieng Viet cho 50 ma quyen

Nhãn sống ở Go cạnh danh mục hằng, không ở frontend: thêm một mã ở backend mà
quên bảng nhãn bên kia thì màn hiện ra một mã trần. Một nguồn, một chỗ sửa.
Đối soát hai chiều với DanhMucQuyen() nên con số không chép tay ở đâu."
```

---

## Task 9: Bốn mã lỗi mới

**Files:**
- Modify: `backend-erp/shared/errors/codes.go` (sau `CodeAuthCompanyInUse`, dòng 66)
- Modify: `docs-erp/04-conventions/C-API-http.md:581` và `:700`

CL-API-08 đòi mã mới có dòng trong bảng mã lỗi **trong chính PR đó**. Làm trước khi có chỗ gọi để mọi task sau chỉ việc dùng hằng.

- [ ] **Step 1: Khai bốn hằng**

```go
	// CodeAuthRoleCodeDuplicated - 409. Ma vai tro trung trong CUNG mot phan vung, tuc vi pham
	// uq_roles_company_id_code.
	//
	// Duong ghi SINH ma chu khong nhan tu client (spec dot 2b muc 6.4), va no da tra ma trung
	// truoc khi chen - ke ca hang bia mo (ADR-0027 muc 3), thu ma partial index KHONG chan.
	// Nen ma nay la hang rao CUOI cho mot lan chay song song lot vao khe giua lan tra va lan
	// chen, khong phai duong chay thuong.
	//
	// 409 chu khong 422 theo ranh gioi C-API-02: phai doc database moi biet trung.
	CodeAuthRoleCodeDuplicated = "ERR_AUTH_ROLE_CODE_DUPLICATED"

	// CodeAuthRolePermissionUnknown - 422. Mot ma quyen gui len khong co trong danh muc hang
	// tiem tu composition root.
	//
	// permission_code la TEXT tran duoi database: khong khoa ngoai, khong CHECK (ADR-0023 muc
	// 2). Phep kiem "ma quyen nay co that khong" vi vay nam o tang service, va ma nay la cau
	// tra loi cua no.
	//
	// 422 chu khong 409: nhin request la biet sai - danh muc hang nam trong tien trinh, khong
	// phai trong database.
	CodeAuthRolePermissionUnknown = "ERR_AUTH_ROLE_PERMISSION_UNKNOWN"

	// CodeAuthRolePermissionForbidden - 422. Mot ma quyen CO THAT nhung actor khong du tham
	// quyen de phat no ra: ho thieu <module>.role_assign cua module so huu ma do (ADR-0024
	// muc 2).
	//
	// 422 chu khong 403, va day la cho de chon nham nhat trong bon ma: actor CO quyen goi
	// endpoint nay - ho da qua auth.role_create hoac auth.role_update o cau lenh dau tien - va
	// thu bi tu choi la mot GIA TRI trong than request. Do dung la dinh nghia mot loi validate
	// (C-API-02), va no di kem error.fields tro vao o `permissions`. Tra 403 o day se lam man
	// hinh bao "ban khong co quyen sua vai tro" trong khi su that la mot o tick sai.
	CodeAuthRolePermissionForbidden = "ERR_AUTH_ROLE_PERMISSION_FORBIDDEN"

	// CodeAuthRoleSystemLocked - 422. Sua tap quyen hoac bat tat mot vai tro HE THONG.
	//
	// Vai tro he thong sua duoc TEN va MO TA; tap quyen va co bat tat thi khoa (ADR-0038).
	// Ly do nghiep vu: admin sua tap quyen cua chinh vai tro dang cho ho quyen quan tri la
	// duong ngan nhat de tu khoa minh ra ngoai phan vung, va khong ai trong phan vung sua lai
	// duoc.
	//
	// 422 chu khong 403, cung lap luan voi ma ngay tren: thu bi tu choi la mot truong trong
	// than request, khong phai quyen cua nguoi goi. error.fields tro dung vao truong bi tu
	// choi - `permissions` hay `dang_dung` - de man hinh to dung o.
	CodeAuthRoleSystemLocked = "ERR_AUTH_ROLE_SYSTEM_LOCKED"
```

- [ ] **Step 2: Thêm bốn dòng vào bảng mã lỗi C-API-05**

`docs-erp/04-conventions/C-API-http.md`, ngay sau dòng `ERR_AUTH_COMPANY_IN_USE` (dòng 581):

```markdown
| `ERR_AUTH_ROLE_CODE_DUPLICATED` | `409` | Mã vai trò đã được dùng trong phân vùng này | Tạo vai trò mà mã sinh ra đã có trong **cùng** phân vùng — vi phạm `uq_roles_company_id_code`. Đường ghi tự sinh mã và tự tra trùng kể cả hàng đã xoá mềm ([ADR-0027](../03-decisions/ADR-0027-permission-module-moi-vao-cong-ty-da-co.md) mục 3), nên mã này là hàng rào cuối cho một lần chạy song song |
| `ERR_AUTH_ROLE_PERMISSION_UNKNOWN` | `422` | Mã quyền không tồn tại | Một phần tử của `permissions` không có trong danh mục hằng tiêm từ composition root. `permission_code` là TEXT trần dưới database ([ADR-0023](../03-decisions/ADR-0023-vai-tro-xuong-database.md) mục 2), nên phép kiểm này sống ở tầng service. Kèm `error.fields` trỏ vào `permissions` |
| `ERR_AUTH_ROLE_PERMISSION_FORBIDDEN` | `422` | Bạn không cấp được quyền này cho vai trò | Mã quyền có thật nhưng actor thiếu `<module>.role_assign` của module sở hữu nó ([ADR-0024](../03-decisions/ADR-0024-tham-quyen-tren-vai-tro-tinh-tu-tap-quyen.md) mục 2). `422` chứ không `403`: actor **có** quyền gọi endpoint, thứ bị từ chối là một giá trị trong body |
| `ERR_AUTH_ROLE_SYSTEM_LOCKED` | `422` | Vai trò hệ thống: chỉ sửa được tên và mô tả | `PATCH /roles/:id` gửi `permissions` hoặc `dang_dung` cho một vai trò `is_system = true` ([ADR-0038](../03-decisions/ADR-0038-admin-phan-vung-dat-ra-vai-tro.md)). Kèm `error.fields` trỏ đúng trường bị từ chối |
```

- [ ] **Step 3: Thêm một dòng vào bảng ánh xạ constraint**

Sau dòng `uq_units_code` (dòng 700):

```markdown
| `uq_roles_company_id_code` | `ERR_AUTH_ROLE_CODE_DUPLICATED` | `409` | — |
```

- [ ] **Step 4: Chạy cho thấy xanh, rồi commit `backend-erp`**

```bash
go build ./...
go test ./shared/errors/
go run ./cmd/dev arch
git add shared/errors/codes.go
git commit -m "feat(auth): bon ma loi cua duong ghi vai tro

Bốn dòng tương ứng trong bảng mã lỗi C-API-05 và một dòng trong bảng ánh xạ
constraint đã thêm cùng đợt ở docs-erp (CL-API-08)."
```

`docs-erp` **không commit** — để nguyên trong cây làm việc trên nhánh `docs/vai-tro-dot-2b-spec`.

---

## Task 10: `RoleService` và `GET /permissions` ở tầng service

**Files:**
- Create: `backend-erp/modules/auth/internal/service/role_service.go`
- Create: `backend-erp/modules/auth/internal/service/role_service_test.go`
- Modify: `backend-erp/modules/auth/module.go:205-277` (`Deps`), `:303-341` (`New`), `:402-410`

**Quyết định về phân trang, ghi ra để không ai đi làm lại nó:** `GET /permissions` nhận **đủ ba tham số** `page`, `page_size`, `sort` và trả `meta`, tức nó **không** đăng ký ngoại lệ R-12 ở bảng 3 của C-API-07. Bảng đó miễn cho endpoint trả "hằng số biên dịch được, **không truy vấn DB**", và cờ `cap_duoc` của endpoint này đi qua `authz.Can` — thứ đọc bảng `roles`/`role_permissions` qua nhớ đệm. Đăng ký một ngoại lệ mà vế "không truy vấn DB" đọc thế nào cũng được là đúng cách dòng ngoại lệ cũ của `GET /roles` đã phải bị gỡ. Phép cắt trang chạy **ở Go trên danh mục hằng** — không câu SQL nào, nên vế "sort không đi vào SQL" của R-12 và điều kiện index của CL-API-07 không áp. Hệ quả đã biết: màn tích quyền phải gọi với `page_size=100` (max của C-API-04) và danh mục hôm nay có 50 dòng; ngày nó vượt 100, hoặc frontend phải cuộn trang, hoặc `max` phải được nới bằng một đợt riêng.

- [ ] **Step 1: Viết test đỏ trước**

`modules/auth/internal/service/role_service_test.go`:

```go
package service_test

import (
	"context"
	"testing"

	"erp/modules/auth/internal/service"
	"erp/shared/auth"
	"erp/shared/authz"
)

// danhMucQuyenTest la danh muc hang NHO XIU dung cho ca file, dung khuon ma bangQuyenUser()
// dat ra o user_service_test.go: bon ma tren hai module gia cong hai ma san chung that.
//
// Hai module GIA chu khong ba module that: thu duoc do la LUAT, va mot bang nho thi mot lan
// do sai chi ra dung mot dong. Bo that duoc do o cmd/internal/vaitro va o e2e.
func danhMucQuyenTest() []service.QuyenCoNhan {
	return []service.QuyenCoNhan{
		{Ma: permVanHanhKho, Nhan: "Hang nhap", Nhom: "Kho", PhanHe: "kho", NhanPhanHe: "Kho"},
		{Ma: permGanKho, Nhan: "Phat vai tro kho", Nhom: "Phan quyen", PhanHe: "kho", NhanPhanHe: "Kho"},
		{Ma: permVanHanhBanHang, Nhan: "Don ban", Nhom: "Ban hang", PhanHe: "banhang", NhanPhanHe: "Ban hang"},
		{Ma: service.PermAuthSelfRead, Nhan: "Xem ho so cua chinh minh", Nhom: "Nguoi dung", PhanHe: "auth", NhanPhanHe: "Quan tri"},
	}
}

// dungRoleService dung RoleService voi bang quyen that cua file nay va mot repo gia.
//
// DB de nil CO Y, cung ly do dungServiceDanhMuc da ghi: DanhMucQuyen khong cham database dong
// nao, nen mot nil o day la mot phep kiem - ngay ai do chen mot cau truy van vao chinh method
// nay, no panic ngay thay vi im lang di qua.
func dungRoleService(repo repository.RoleRepository) *service.RoleService {
	return service.NewRoleService(service.RoleDeps{
		Authz:          bangQuyenUser(),
		RoleRepo:       repo,
		QuyenTuTacDong: quyenTuTacDongTest(),
		DanhMucQuyen:   danhMucQuyenTest(),
	})
}

// TestDanhMucQuyen_TraDuTapVaDanhCoCapDuocTheoActor chot menh de trung tam cua muc 6.2.
//
// `cap_duoc` KHONG phai mot phep loc: moi ma van di ra, chi khac o co. Loc bot se lam man
// hinh khong noi duoc "co quyen nay nhung ban khong cap duoc", va do dung la cau ma diem 3
// nguoi dung chot doi phai noi ra.
func TestDanhMucQuyen_TraDuTapVaDanhCoCapDuocTheoActor(t *testing.T) {
	svc := dungRoleService(&roleRepoGia{})

	ra, tong, err := svc.DanhMucQuyen(context.Background(), actorChiGanKho("cong-ty-nao-cung-duoc"),
		service.DanhMucQuyenInput{Page: 1, PageSize: 100})
	if err != nil {
		t.Fatalf("DanhMucQuyen loi: %v", err)
	}
	if tong != 4 {
		t.Fatalf("tong = %d, muon 4 - `cap_duoc` khong duoc lam mot phep loc", tong)
	}

	co := map[string]bool{}
	for _, q := range ra {
		co[q.Ma] = q.CapDuoc
	}
	if !co[permVanHanhKho] {
		t.Errorf("%q co cap_duoc = false; actor nay dang GIU chinh ma do", permVanHanhKho)
	}
	if co[permVanHanhBanHang] {
		t.Errorf("%q co cap_duoc = true; actor nay khong giu ma do", permVanHanhBanHang)
	}
}

// TestDanhMucQuyen_ThieuCaHaiQuyenTra403 chot cua chan cua R-15.
//
// Hai ma, mot cua: ai khong dat duoc vai tro thi khong can danh muc quyen (spec muc 6.2). Bai
// nay do dung chieu TU CHOI; chieu cho qua cua tung ma do o hai bai duoi.
func TestDanhMucQuyen_ThieuCaHaiQuyenTra403(t *testing.T) {
	svc := dungRoleService(&roleRepoGia{})

	_, _, err := svc.DanhMucQuyen(context.Background(), actorThieuQuyen(),
		service.DanhMucQuyenInput{Page: 1, PageSize: 100})
	if err == nil {
		t.Fatal("muon loi, nhan nil: mot actor khong dat duoc vai tro van doc duoc danh muc quyen")
	}
	kiemTuChoiQuyen(t, err)
}

// TestDanhMucQuyen_MotTrongHaiQuyenLaDu chot ve "HOAC" cua cua chan.
//
// Khong co bai nay thi mot cai dat doi CA HAI ma van xanh o bai tren, va trieu chung la mot
// actor chi sua duoc vai tro (auth.role_update, khong co auth.role_create) mo man Sua ra va
// thay mot khoi quyen trong.
func TestDanhMucQuyen_MotTrongHaiQuyenLaDu(t *testing.T) {
	bang := authz.New(authz.Bang{
		"chi_sua_vai_tro": {service.PermRoleUpdate},
	})
	svc := service.NewRoleService(service.RoleDeps{
		Authz:          bang,
		RoleRepo:       &roleRepoGia{},
		QuyenTuTacDong: quyenTuTacDongTest(),
		DanhMucQuyen:   danhMucQuyenTest(),
	})
	actor := auth.Actor{UserID: "u", CompanyID: "c", Roles: []string{"chi_sua_vai_tro"}}

	if _, _, err := svc.DanhMucQuyen(context.Background(), actor,
		service.DanhMucQuyenInput{Page: 1, PageSize: 100}); err != nil {
		t.Fatalf("actor chi co %s bi tu choi: %v - cua chan la HOAC, khong phai VA", service.PermRoleUpdate, err)
	}
}

// TestDanhMucQuyen_PhanTrangCatOGoVaGiuThuTuBang chot rang phep cat trang chay tren Go va
// khong xao thu tu cua bang hang.
//
// Thu tu cua bang hang la thu tu NHOM da xep tay - Nguoi dung, Phan vung, Phan quyen, Kho... -
// va no la thu tu man hinh ve. Sap lai o day la lam man hinh nhay cho moi lan tai.
func TestDanhMucQuyen_PhanTrangCatOGoVaGiuThuTuBang(t *testing.T) {
	svc := dungRoleService(&roleRepoGia{})
	actor := actorQuanTri("cong-ty-nao-cung-duoc")

	trang1, tong, err := svc.DanhMucQuyen(context.Background(), actor,
		service.DanhMucQuyenInput{Page: 1, PageSize: 2})
	if err != nil {
		t.Fatalf("trang 1: %v", err)
	}
	if tong != 4 {
		t.Errorf("meta.total = %d, muon 4", tong)
	}
	if len(trang1) != 2 || trang1[0].Ma != permVanHanhKho || trang1[1].Ma != permGanKho {
		t.Fatalf("trang 1 = %+v, muon hai dong dau cua bang theo dung thu tu khai", trang1)
	}

	trang9, tong9, err := svc.DanhMucQuyen(context.Background(), actor,
		service.DanhMucQuyenInput{Page: 9, PageSize: 2})
	if err != nil {
		t.Fatalf("trang 9: %v", err)
	}
	if trang9 == nil {
		t.Error("trang ngoai tap tra ve nil - no se tuan tu hoa thanh \"data\": null thay vi []")
	}
	if len(trang9) != 0 || tong9 != 4 {
		t.Errorf("trang 9: len=%d total=%d, muon 0 va 4", len(trang9), tong9)
	}
}
```

- [ ] **Step 2: Chạy cho thấy đỏ**

```bash
go test ./modules/auth/internal/service/ -run 'TestDanhMucQuyen'
```

Expected: lỗi biên dịch `undefined: service.RoleService`.

- [ ] **Step 3: Viết `RoleService` với đúng `DanhMucQuyen`**

`modules/auth/internal/service/role_service.go`:

```go
package service

import (
	"context"

	"github.com/jmoiron/sqlx"

	"erp/modules/auth/internal/repository"
	"erp/shared/audit"
	"erp/shared/auth"
	"erp/shared/authz"
	apperr "erp/shared/errors"
)

// QuyenCoNhan la MOT dong cua danh muc quyen: ma, nhan tieng Viet, nhom doi tuong, phan he.
//
// Ban cua tang service, khac ban o package goc (auth.QuyenCoNhan): module.go doi tung dong
// sang kieu nay, y het cach LoaiPhamVi da di. Khong dung thang kieu cua package goc vi package
// goc import package nay, khong nguoc lai.
type QuyenCoNhan struct {
	Ma         string
	Nhan       string
	Nhom       string
	PhanHe     string
	NhanPhanHe string
}

// QuyenKhaDung la MOT dong cua `GET /permissions`: QuyenCoNhan cong mot co CapDuoc.
//
// CapDuoc tra loi "actor co dang giu chinh ma quyen nay khong", va no la thu lam nen diem 3
// nguoi dung chot: false thi man ve dong do mo va khoa. No la mot CO chu khong mot phep loc -
// loc bot se lam man hinh khong noi duoc "co quyen nay nhung ban khong cap duoc".
type QuyenKhaDung struct {
	QuyenCoNhan
	CapDuoc bool
}

// DanhMucQuyenInput la ba tham so phan trang cua `GET /permissions` (C-API-04).
//
// Sort co mat de hop dong endpoint dong khuon voi moi endpoint list khac, nhung danh muc nay
// la mot BANG HANG da xep tay theo nhom, va thu tu do chinh la thu tu man hinh ve - nen gia tri
// duy nhat co nghia hom nay la chuoi rong. Xem catTrangQuyen.
type DanhMucQuyenInput struct {
	Page     int
	PageSize int
	Sort     string
}

// RoleService so huu duong GHI vai tro: tao mot vai tro, sua mot vai tro, va doc danh muc
// quyen de man tich quyen ve duoc.
//
// # Vi sao mot service RIENG, khong them ba method vao UserService
//
// UserService tra loi "nguoi nay la ai va duoc gi"; service nay tra loi "phan vung nay co
// nhung vai tro nao". Hai cau hoi, hai cua quyen (PermUserAssignRoles so voi
// PermRoleCreate/PermRoleUpdate), va gop chung la mo duong cho ai do goi nham method trong mot
// endpoint moi - dung ly do ma UserRoleHandler da tach khoi UserHandler.
//
// Chung o CUNG package service, va do la co y: phep gom module cua ADR-0024 phai co DUNG MOT
// ban cai dat. moduleCuaTapQuyen, moduleCuaQuyen, permRoleAssignHauTo, loiThieuQuyenGanModule,
// hieuDoiXungVaiTro, laUUID va maTrungKhoa deu la cua package, nen ca hai service dung chung
// chung ma khong ai chep tay lan hai.
//
// GET /roles thi O LAI UserService.DanhMucVaiTro, va do khong phai mot cho quen: phep loc cua
// no dung lai kiemGanMotVaiTro - mot method cua UserService - va ADR-0032 muc Alternatives loai
// thang phuong an viet mot ban thu hai cua phep kiem do.
type RoleService struct {
	db        *sqlx.DB
	authz     authz.Checker
	roleRepo  repository.RoleRepository
	auditRepo audit.Repository

	// quyenTuTacDong la tap permission chi tac dong len CHINH NGUOI GIU no (ADR-0028), dang
	// TAP de kiemGhiTapQuyen tra mot lan cho moi ma no duyet. ADR-0028 muc 5 noi ro phep loai
	// tru nay ap cho ca duong GHI tap quyen, khong chi duong gan.
	quyenTuTacDong map[string]struct{}

	// danhMucQuyen la bang hang tiem tu composition root, giu nguyen THU TU khai - do la thu
	// tu man hinh ve.
	danhMucQuyen []QuyenCoNhan

	// coMaQuyen la chinh danhMucQuyen dang TAP, dung cho phep kiem "ma quyen nay co that
	// khong" (ADR-0023 muc 7). Dung mot map thay vi quet slice: mot lan ghi tich 50 o se quet
	// 50 lan tren mot slice 50 phan tu.
	coMaQuyen map[string]struct{}
}

// RoleDeps gom phu thuoc de chu ky NewRoleService khong dai ra theo thoi gian.
type RoleDeps struct {
	DB        *sqlx.DB
	Authz     authz.Checker
	RoleRepo  repository.RoleRepository
	AuditRepo audit.Repository

	// QuyenTuTacDong den tu composition root vi tieu chi cua ADR-0028 muc 1 khong noi gi ve
	// module (R-05). Rong la hop le va fail-CLOSE: khong loai tru gi thi moi tap quyen deu keo
	// theo module auth qua san chung, tuc luat CHAT hon chu khong long hon.
	QuyenTuTacDong []string

	// DanhMucQuyen den tu composition root vi cung mot ly do: no goi ten hang permission cua ca
	// ba module.
	//
	// Rong cung la fail-CLOSE, va o day chieu do manh hon: danh muc rong nghia la MOI ma quyen
	// gui len deu bi tu choi 422, tuc khong vai tro nao tao duoc voi mot o tick nao. Do la
	// trang thai dung cho mot composition root khong phuc vu HTTP - cmd/dev bootstrap-user
	// chang han - va la mot loi lo ra ngay o request dau tien neu cmd/api quen tiem.
	DanhMucQuyen []QuyenCoNhan
}

// NewRoleService dung RoleService tu cac phu thuoc da tiem.
func NewRoleService(d RoleDeps) *RoleService {
	tuTacDong := make(map[string]struct{}, len(d.QuyenTuTacDong))
	for _, p := range d.QuyenTuTacDong {
		tuTacDong[p] = struct{}{}
	}
	coMa := make(map[string]struct{}, len(d.DanhMucQuyen))
	for _, q := range d.DanhMucQuyen {
		coMa[q.Ma] = struct{}{}
	}
	return &RoleService{
		db:             d.DB,
		authz:          d.Authz,
		roleRepo:       d.RoleRepo,
		auditRepo:      d.AuditRepo,
		quyenTuTacDong: tuTacDong,
		danhMucQuyen:   d.DanhMucQuyen,
		coMaQuyen:      coMa,
	}
}

// DanhMucQuyen tra ve MOI ma quyen cua he, moi ma kem nhan tieng Viet va mot co `cap_duoc`.
//
// # Cua quyen la HOAC, khong phai VA
//
// Ai khong dat duoc vai tro thi khong can danh muc quyen (spec muc 6.2), va "dat duoc" nghia
// la co mot trong hai ma. Mot actor chi co auth.role_update - nguoi sua duoc vai tro nhung
// khong tao duoc - phai mo duoc man Sua va thay du khoi quyen.
//
// Loi goi Can thu nhat la CAU LENH DAU TIEN cua than ham, dung nhu R-15 doi; loi goi thu hai
// nam trong nhanh that bai cua no.
//
// # `cap_duoc` doc tu authz.Can, khong tu mot phep so sanh tay
//
// Cung mot nguon ma phep kiem ghi se doc, nen co bay ra man hinh khong lech duoc voi cau tra
// loi 200/422 cua duong ghi. Mot ban so sanh rieng o day se lech vao dung ngay ai do doi luat.
func (s *RoleService) DanhMucQuyen(ctx context.Context, actor auth.Actor, in DanhMucQuyenInput) ([]QuyenKhaDung, int64, error) {
	if err := s.authz.Can(ctx, actor, PermRoleCreate); err != nil {
		if err2 := s.authz.Can(ctx, actor, PermRoleUpdate); err2 != nil {
			return nil, 0, err
		}
	}

	// Slice khoi tao san chu khong de nil: mot trang khong co ban ghi nao phai ra JSON `[]`
	// (C-API-03).
	ra := make([]QuyenKhaDung, 0, len(s.danhMucQuyen))
	for _, q := range s.danhMucQuyen {
		ra = append(ra, QuyenKhaDung{QuyenCoNhan: q, CapDuoc: s.authz.Can(ctx, actor, q.Ma) == nil})
	}
	return catTrangQuyen(ra, in), int64(len(ra)), nil
}

// catTrangQuyen cat mot trang ra khoi danh muc.
//
// Phep cat chay o Go vi danh muc nay khong den tu database - no la mot bang hang trong tien
// trinh - nen khong co LIMIT/OFFSET nao de dat, va mot bo loc `sort` di vao SQL cung khong ton
// tai. Ba con so phan trang van di qua repository.PhanTrang chu khong qua mot cap hang khai o
// day, cung ly do catTrangVaiTro da ghi: gia tri mac dinh cua C-API-04 co dung mot nguon.
//
// KHONG doc in.Sort. Thu tu cua danh muc la thu tu KHAI trong bang hang, gom theo nhom doi
// tuong, va do chinh la thu tu man hinh ve. Sap lai theo ma se pha cac nhom ra. Truong Sort
// van co mat trong Input de hop dong endpoint dong khuon voi moi endpoint list khac, va ngay
// no co nghia thi cho them mot whitelist la o day.
func catTrangQuyen(ds []QuyenKhaDung, in DanhMucQuyenInput) []QuyenKhaDung {
	soDong, boQua := repository.PhanTrang(repository.ListQuery{Page: in.Page, PageSize: in.PageSize})
	if boQua >= len(ds) {
		return []QuyenKhaDung{}
	}
	het := boQua + soDong
	if het > len(ds) {
		het = len(ds)
	}
	return ds[boQua:het]
}

// ghiAudit ghi mot dong audit_logs qua CHINH tx cua thao tac nghiep vu (R-17).
//
// Ban rieng cua RoleService chu khong dung method cung ten cua UserService: hai method gan
// giong nhau nhung chung treo tren hai struct khac nhau, va mot ham dung chung se doi mot trong
// hai service phai giu mot tham chieu toi cai kia.
func (s *RoleService) ghiAudit(ctx context.Context, tx *sqlx.Tx, actor auth.Actor, hanhDong, entityID string) error {
	return s.auditRepo.Record(ctx, tx, audit.Entry{
		CompanyID: actor.CompanyID,
		ActorID:   actor.UserID,
		RequestID: requestid.FromContext(ctx),
		Action:    hanhDong,
		EntityID:  entityID,
	})
}

// Ten hanh dong ghi vao audit_logs.action, dang `<thuc the>.<hanh dong o the qua khu>` giong
// bon hang cua UserService. Cot action la TEXT khong CHECK (migration 000004) nen tap gia tri
// mo, va do la ly do chung phai la hang: mot lan go nham "role.create" thi man tra cuu lich su
// mat dung nhung dong do ma khong ai bao.
const (
	actionRoleCreated = "role.created"
	actionRoleUpdated = "role.updated"
)

// loiVaiTroKhongTonTai la cau tra loi DUY NHAT cho ca "khong co vai tro do" lan "vai tro cua
// phan vung khac".
//
// Rieng voi loiKhongTonTai() cua UserService chi o mot cho: thong diep. Hai duong tra hai cau
// khac nhau vi hai tai nguyen khac nhau, va mot cau "nguoi dung khong ton tai" tren mot
// PATCH /roles/:id se day nguoi doc di sai huong han.
func loiVaiTroKhongTonTai() error {
	return apperr.NotFound(apperr.CodeNotFound, "vai tro khong ton tai")
}
```

(Import `requestid` cùng khối import ở đầu file: `"erp/shared/requestid"`.)

- [ ] **Step 4: Bổ sung `RoleRepository` giả cho test biên dịch được**

Chưa có method mới nào trên interface ở task này, nên `&roleRepoGia{}` từ `user_service_danhmuc_test.go` dùng được ngay. Chạy:

```bash
go test ./modules/auth/internal/service/ -run 'TestDanhMucQuyen'
```

Expected: bốn bài mới xanh. Bộ lọc `-run` giữ cho các bài chạm database không chạy — nên bước này chạy được dưới Windows.

- [ ] **Step 5: Nối vào composition root**

`modules/auth/module.go`:

Trong `Deps` (sau `BoVaiTroMacDinh`, dòng 276):

```go
	// DanhMucQuyen la bang 50 ma quyen kem nhan tieng Viet, nguon cua `GET /permissions` va la
	// danh muc hang ma duong ghi tap quyen doi chieu (ADR-0023 muc 7).
	//
	// No den tu composition root vi cung ly do voi BoVaiTroMacDinh: bang goi ten hang
	// permission cua ca ba module, ma R-05 cam module auth phu thuoc inventory hay machine.
	//
	// Rong la fail-CLOSE va no LON hon mot lan tu choi: danh muc rong nghia la MOI ma quyen gui
	// len deu 422, tuc khong vai tro nao tao duoc voi mot o tick nao. Do la trang thai dung cho
	// mot root khong phuc vu HTTP; o cmd/api thi thieu dong nay la mot loi lo ra ngay o request
	// dau tien.
	DanhMucQuyen []QuyenCoNhan
```

Trong `Module` (dòng 281-292): thêm `roles *handler.RoleHandler` (handler dựng ở Task 11 — ở task này chỉ dựng service, để `roleSvc` làm biến cục bộ trong `New` và gán vào struct ở Task 11).

Trong `New` (sau `companySvc`, dòng 380):

```go
	// Doi tung dong sang kieu cua tang service, y het loaiPhamVi ben duoi: package goc va
	// package service co hai ban cua cung mot kieu, vi package goc import service chu khong
	// nguoc lai.
	danhMucQuyen := make([]service.QuyenCoNhan, 0, len(d.DanhMucQuyen))
	for _, q := range d.DanhMucQuyen {
		danhMucQuyen = append(danhMucQuyen, service.QuyenCoNhan{
			Ma: q.Ma, Nhan: q.Nhan, Nhom: q.Nhom, PhanHe: q.PhanHe, NhanPhanHe: q.NhanPhanHe,
		})
	}

	roleSvc := service.NewRoleService(service.RoleDeps{
		DB:        d.DB,
		Authz:     d.Authz,
		RoleRepo:  roleRepo,
		AuditRepo: d.Audit,

		// Cung tap quyen tu tac dong voi UserService, va do la bat buoc chu khong tien tay:
		// ADR-0028 muc 5 chot rang phep loai tru ap cho ca duong ghi tap quyen. Hai tap khac
		// nhau o hai duong se lam mot inventory.admin tick duoc inventory.item_create nhung
		// khong tick duoc auth.self_read - mot su bat doi xung khong ai giai thich duoc.
		QuyenTuTacDong: d.QuyenTuTacDong,
		DanhMucQuyen:   danhMucQuyen,
	})
```

`cmd/api/main.go` (khối `auth.Deps`, sau `BoVaiTroMacDinh`, dòng 249):

```go
		// Bang 50 ma quyen kem nhan tieng Viet. No phai den tu day vi cung mot ly do voi hai
		// dong tren: bang goi ten hang permission cua ca ba module (R-05).
		DanhMucQuyen: vaitro.DanhMucQuyenCoNhan(),
```

`cmd/dev/bootstrap.go` (khối `auth.Deps`, sau `QuyenTuTacDong`, dòng 144) — chỉ thêm ghi chú, **không** thêm field:

```go
		// KHONG tiem DanhMucQuyen, va do la mot quyet dinh: lenh nay khong di qua duong ghi
		// vai tro nao. Danh muc rong lam moi ma quyen gui len bi tu choi 422 - fail-CLOSE - va
		// khong duong nao trong lenh nay cham toi nhanh do.
```

- [ ] **Step 6: Chạy cho thấy xanh, rồi commit**

```bash
go build ./...
go test ./modules/auth/internal/service/ -run 'TestDanhMucQuyen'
go run ./cmd/dev arch
git add modules/auth/internal/service/role_service.go \
        modules/auth/internal/service/role_service_test.go \
        modules/auth/module.go cmd/api/main.go cmd/dev/bootstrap.go
git commit -m "feat(auth): RoleService va danh muc quyen kem co cap_duoc

Cửa quyền là auth.role_create HOẶC auth.role_update. cap_duoc là một cờ chứ không
phải một phép lọc: ẩn nút là UX, backend vẫn từ chối một mã cap_duoc false."
```

---

## Task 11: Handler và route `GET /api/v1/permissions`

**Files:**
- Create: `backend-erp/modules/auth/internal/handler/role_handler.go`
- Create: `backend-erp/modules/auth/internal/handler/role_routes.go`
- Create: `backend-erp/modules/auth/internal/handler/role_handler_test.go`
- Modify: `backend-erp/modules/auth/module.go:281-292`, `:402-410`, `:434-439`

- [ ] **Step 1: Viết test đỏ trước**

`modules/auth/internal/handler/role_handler_test.go` — đọc `user_handler_test.go` để bắt chước cách dựng gin engine và bơm actor vào context của repo này, rồi thêm:

```go
// TestDanhMucQuyen_HinhDangJSON chot HOP DONG cua `GET /permissions`: sau khoa, dung ten, dung
// kieu.
//
// Do bang cach doc lai JSON THAT chu khong so sanh struct: ten khoa la thu client re nhanh
// theo, va mot tag json go nham khong lam vo build o phia nao ca.
func TestDanhMucQuyen_HinhDangJSON(t *testing.T) {
	w := goiDanhMucQuyen(t)
	if w.Code != http.StatusOK {
		t.Fatalf("GET /permissions = %d, muon 200 (than: %s)", w.Code, w.Body.String())
	}

	var than struct {
		Data []map[string]any `json:"data"`
		Meta struct {
			Total    int64 `json:"total"`
			Page     int   `json:"page"`
			PageSize int   `json:"page_size"`
		} `json:"meta"`
	}
	if err := json.Unmarshal(w.Body.Bytes(), &than); err != nil {
		t.Fatalf("doc than: %v", err)
	}
	if len(than.Data) == 0 {
		t.Fatal("data rong")
	}
	for _, khoa := range []string{"ma", "nhan", "nhom", "phan_he", "nhan_phan_he", "cap_duoc"} {
		if _, co := than.Data[0][khoa]; !co {
			t.Errorf("dong dau thieu khoa %q - client re nhanh theo ten khoa", khoa)
		}
	}
	if than.Meta.PageSize == 0 {
		t.Error("meta.page_size = 0 - endpoint list phai tra ba con so DA CHUAN HOA (C-API-04)")
	}
}
```

- [ ] **Step 2: Chạy cho thấy đỏ**

```bash
go test ./modules/auth/internal/handler/ -run 'TestDanhMucQuyen'
```

Expected: lỗi biên dịch `undefined: handler.NewRoleHandler`.

- [ ] **Step 3: Viết handler**

`modules/auth/internal/handler/role_handler.go` (phần của `GET /permissions`; hai method ghi thêm ở Task 18):

```go
package handler

import (
	"github.com/gin-gonic/gin"

	"erp/modules/auth/internal/service"
	"erp/shared/auth"
	"erp/shared/response"
)

// RoleHandler phuc vu TAI NGUYEN VAI TRO: duong ghi `/roles` va danh muc `/permissions`.
//
// Tach khoi UserRoleHandler chu khong them method vao do, va tach vi dung ly do UserRoleHandler
// da tach khoi UserHandler: ba endpoint o day di qua HAI permission khac han
// (auth.role_create, auth.role_update), trong khi ca hai method cua UserRoleHandler di qua
// auth.user_assign_roles. Gop chung mot handler la mo duong cho ai do goi nham method trong mot
// endpoint moi.
//
// `GET /roles` O LAI UserRoleHandler du no cung la danh muc vai tro: no goi
// UserService.DanhMucVaiTro, va phep loc cua method do dung lai kiemGanMotVaiTro. Chuyen no
// sang day se doi mot ban thu hai cua phep kiem ay - dung phuong an ADR-0032 muc Alternatives
// da loai.
type RoleHandler struct {
	svc *service.RoleService
}

// NewRoleHandler dung handler tu service da khoi tao o module.go.
func NewRoleHandler(svc *service.RoleService) *RoleHandler {
	return &RoleHandler{svc: svc}
}

// QuyenDTO la MOT dong cua `GET /permissions`.
//
// `cap_duoc` CO mat trong hop dong, va no la ngoai le co y thuc cua tinh than "khong bay ra
// manh du lieu de frontend tu suy quyen" ma VaiTroKhaDungDTO dang giu. Khac biet: o day cau
// hoi khong phai "actor co lam duoc thao tac nay khong" ma "actor co dang giu chinh ma quyen
// nay khong", va man hinh CAN cau tra loi do de ve mot dong mo kem ly do thay vi mot o tick
// bam duoc roi 422. ADR-0038 ghi ro ranh gioi giua hai ca nay.
type QuyenDTO struct {
	Ma         string `json:"ma"`
	Nhan       string `json:"nhan"`
	Nhom       string `json:"nhom"`
	PhanHe     string `json:"phan_he"`
	NhanPhanHe string `json:"nhan_phan_he"`
	CapDuoc    bool   `json:"cap_duoc"`
}

// ListQuyenQuery la struct bind query cua `GET /permissions` (R-12, C-API-04).
//
// Du CA BA tag form, cung khuon voi ListVaiTroQuery, va checker cua R-12 nhan ra mot endpoint
// list bang chinh su co mat cua ba tag do.
//
// Endpoint nay KHONG dang ky ngoai le mien phan trang o bang 3 cua C-API-07, du danh muc cua no
// la mot bang hang: bang do mien cho endpoint "khong truy van DB", ma co `cap_duoc` di qua
// authz.Can - thu doc bang roles qua nho dem. Dang ky mot ngoai le ma dieu kien cua no doc the
// nao cung duoc la dung cach dong ngoai le cu cua `GET /roles` da phai bi go.
type ListQuyenQuery struct {
	Page     int    `form:"page" binding:"omitempty,min=1"`
	PageSize int    `form:"page_size" binding:"omitempty,min=1,max=100"`
	Sort     string `form:"sort"`
}

// DanhMucQuyen xu ly GET /api/v1/permissions.
func (h *RoleHandler) DanhMucQuyen(c *gin.Context) {
	var q ListQuyenQuery
	if err := c.ShouldBindQuery(&q); err != nil {
		response.BindFailed(c, err)
		return
	}
	if q.Page < 1 {
		q.Page = pageMacDinh
	}
	if q.PageSize < 1 {
		q.PageSize = pageSizeMacDinh
	}

	ctx := c.Request.Context()
	actor := auth.FromContext(ctx)

	ds, tong, err := h.svc.DanhMucQuyen(ctx, actor, service.DanhMucQuyenInput{
		Page:     q.Page,
		PageSize: q.PageSize,
		Sort:     q.Sort,
	})
	if err != nil {
		response.Error(c, err)
		return
	}

	// Slice khoi tao san chu khong de nil: mot trang khong co ban ghi nao phai ra JSON `[]`
	// chu khong `null` (C-API-03).
	ra := make([]QuyenDTO, 0, len(ds))
	for _, q := range ds {
		ra = append(ra, QuyenDTO{
			Ma: q.Ma, Nhan: q.Nhan, Nhom: q.Nhom,
			PhanHe: q.PhanHe, NhanPhanHe: q.NhanPhanHe, CapDuoc: q.CapDuoc,
		})
	}

	// Ba con so trong Meta la ba con so DA CHUAN HOA o tren, tuc dung bo tham so ma service
	// vua chay - khong phai gia tri tho client gui len.
	response.List(c, ra, response.Meta{Total: tong, Page: q.Page, PageSize: q.PageSize})
}
```

- [ ] **Step 4: Viết bảng route**

`modules/auth/internal/handler/role_routes.go`:

```go
package handler

import "github.com/gin-gonic/gin"

// RegisterRoleRoutes dang ky ba route cua dot 2b: hai route ghi tren tai nguyen roles, va mot
// danh muc quyen cua he thong.
//
// Tham so v1 DA la group /api/v1 do COMPOSITION ROOT dung (cmd/api/router.go). Ham nay chi khai
// phan duoi, va do la dieu R-13 doi: tien to /api/v1 xuat hien dung MOT lan trong toan he
// (C-API-06).
//
// Ca ba route dung dang tai nguyen cua C-API-01: danh tu SO NHIEU, chu thuong, khong dong tu
// nao trong path. `:id` luon la UUID.
//
// # Mot ham dang ky RIENG, khac loi RegisterUserRoutes da chon
//
// user_routes.go co y GOM `GET /roles` vao chung vi no do cung mot handler phuc vu. O day thi
// nguoc lai: ba route nay do RoleHandler phuc vu, con `GET /roles` do UserRoleHandler. Nhet
// chung vao mot ham se bat ham do nhan ca hai handler roi khong ai doc ra duoc route nao thuoc
// ai - va do la thu de dan toi mot lan goi nham method trong mot endpoint moi.
//
// `POST /roles` va `GET /roles` nam o hai ham khac nhau du chung chung mot duong dan, va do la
// dieu duy nhat dang chu y o day: gin khop theo (method, path) nen hai lan dang ky khong dam
// nhau, va khong thu tu nao giua hai ham la bat buoc.
//
// # xacThuc la tham so BAT BUOC, khong duoc nil
//
// Ca ba endpoint doi mot actor da xac thuc. Chung KHONG dua duoc vao mot lan `v1.Use(...)` o
// composition root: group /api/v1 con mang /auth/login, /auth/refresh va /auth/logout - ba
// endpoint chay khi CHUA CO actor. Thieu middleware o day khong lam ro du lieu - actor rong co
// CompanyID rong nen moi cau truy van deu khong khop gi - nhung no tra 403 cho mot request
// khong co token, trong khi cau tra loi dung la 401 (C-API-02).
func RegisterRoleRoutes(v1 *gin.RouterGroup, h *RoleHandler, xacThuc gin.HandlerFunc) {
	// Danh muc quyen cua HE THONG, khong phai quyen cua mot nguoi - nen no la /permissions tran
	// chu khong nam duoi /users/:id. No dung o day chu khong o mot ham thu ba: no do CUNG mot
	// handler phuc vu va chia CUNG mot cua quyen voi hai route ghi ben duoi.
	v1.GET("/permissions", xacThuc, h.DanhMucQuyen)

	v1.POST("/roles", xacThuc, h.Create)
	v1.PATCH("/roles/:id", xacThuc, h.Patch)
}
```

Ba dòng `Create`/`Patch` chưa có method — task này **chỉ** đăng ký `GET /permissions`; hai dòng `POST`/`PATCH` được thêm ở Task 18. Ở task này để lại đúng dòng `GET` và khối ghi chú tương ứng.

- [ ] **Step 5: Nối vào `Module`**

`modules/auth/module.go`:
- `Module` (dòng 281-292): thêm field `roles *handler.RoleHandler`.
- `New` (dòng 402-410): thêm `roles: handler.NewRoleHandler(roleSvc),`.
- `Register` (dòng 434-439): thêm `handler.RegisterRoleRoutes(v1, m.roles, xacThuc)`.

- [ ] **Step 6: Chạy cho thấy xanh, rồi commit**

```bash
go build ./...
go test ./modules/auth/internal/handler/ -run 'TestDanhMucQuyen'
go run ./cmd/dev arch
git add modules/auth/internal/handler/role_handler.go \
        modules/auth/internal/handler/role_routes.go \
        modules/auth/internal/handler/role_handler_test.go \
        modules/auth/module.go
git commit -m "feat(auth): GET /api/v1/permissions

Danh mục 50 mã quyền kèm nhãn tiếng Việt, nhóm, phân hệ và cờ cap_duoc. Nhận đủ
ba tham số phân trang nên không đăng ký ngoại lệ R-12 nào."
```

---

## Task 12: `GET /roles` mở rộng sáu trường

**Files:**
- Modify: `backend-erp/modules/auth/internal/repository/role_repository.go:466-550`
- Modify: `backend-erp/modules/auth/internal/service/user_service.go:152-164`, `:636-669`, `:1343-1375`
- Modify: `backend-erp/modules/auth/internal/handler/user_role_handler.go:59-68`, `:111-120`
- Modify: `backend-erp/modules/auth/module.go` (dựng bảng nhãn phân hệ và tiêm vào `UserDeps`)
- Modify: `backend-erp/modules/auth/internal/service/user_service_danhmuc_test.go`
- Test: `user_service_danhmuc_test.go` (bài mới), `role_repository_db_test.go` (bài mới)

- [ ] **Step 1: Viết test đỏ trước — tầng service**

Thêm vào `modules/auth/internal/service/user_service_danhmuc_test.go`:

```go
// TestDanhMucVaiTro_MangSauTruongMoi chot muc 6.3: sau truong moi di ra, va `phan_he` suy tu
// TAP QUYEN chu khong tu tien to cua ma vai tro.
//
// Bai nay do dung cho ma rang buoc 3 canh: vai tro `banhang_nhan_vien` mang mot ma quyen cua
// module `kho`, nen `phan_he` cua no phai la ["kho"] chu khong ["banhang"]. Mot cai dat cat
// tien to cua roles.code van xanh o moi bai khac va do o day.
func TestDanhMucVaiTro_MangSauTruongMoi(t *testing.T) {
	repo := &roleRepoGia{dong: []repository.DongDanhMucVaiTro{{
		ID: "11111111-1111-4111-8111-111111111111", Ma: vaiTroKho, Nhan: "Kho",
		MoTa: "Thu kho ca dem", DangDung: true, HeThongTao: true, SoNguoiGiu: 12,
	}}}
	svc := dungServiceDanhMuc(repo)

	ra, _, err := svc.DanhMucVaiTro(context.Background(), actorQuanTri("cong-ty-nao-cung-duoc"),
		service.DanhMucVaiTroInput{Page: 1, PageSize: 20})
	if err != nil {
		t.Fatalf("DanhMucVaiTro loi: %v", err)
	}
	if len(ra) != 1 {
		t.Fatalf("nhan %d dong, muon 1", len(ra))
	}
	d := ra[0]
	if d.ID != "11111111-1111-4111-8111-111111111111" {
		t.Errorf("ID = %q, muon id cua hang roles", d.ID)
	}
	if d.MoTa != "Thu kho ca dem" || !d.DangDung || !d.HeThongTao || d.SoNguoiGiu != 12 {
		t.Errorf("bon truong tu database di ra sai: %+v", d)
	}
	if len(d.PhanHe) != 1 || d.PhanHe[0] != "kho" {
		t.Errorf("PhanHe = %v, muon [kho] - module suy tu role_permissions, khong tu tien to cua %q", d.PhanHe, vaiTroKho)
	}
	if len(d.NhanPhanHe) != 1 || d.NhanPhanHe[0] != "Kho vận" {
		t.Errorf("NhanPhanHe = %v, muon [Kho vận] - nhan song o Go chu khong o frontend (spec muc 6.2)", d.NhanPhanHe)
	}
}

// TestDanhMucVaiTro_PhanHeBoTapTuTacDong chot rang cot Phan he tren man hinh khong hien "Quan
// tri he thong" cho MOI dong.
//
// Bay vai tro mac dinh deu mang san chung `auth.self_read` va `auth.change_password`
// (ADR-0021 muc 2). Khong bo chung thi moi dong deu co module `auth` trong `phan_he`, va mot
// cot ma moi hang mang cung mot gia tri la mot cot khong noi len gi. Phep bo dung DUNG tap ma
// ADR-0028 dat ra va dung DUNG mot ham voi phep gom tham quyen - moduleCuaTapQuyen.
func TestDanhMucVaiTro_PhanHeBoTapTuTacDong(t *testing.T) {
	repo := &roleRepoGia{dong: []repository.DongDanhMucVaiTro{
		{ID: "22222222-2222-4222-8222-222222222222", Ma: vaiTroKhoKemSanChung, Nhan: "Kho kem san chung"},
	}}
	svc := dungServiceDanhMuc(repo)

	ra, _, err := svc.DanhMucVaiTro(context.Background(), actorQuanTri("cong-ty-nao-cung-duoc"),
		service.DanhMucVaiTroInput{Page: 1, PageSize: 20})
	if err != nil {
		t.Fatalf("DanhMucVaiTro loi: %v", err)
	}
	if len(ra) != 1 {
		t.Fatalf("nhan %d dong, muon 1", len(ra))
	}
	if len(ra[0].PhanHe) != 1 || ra[0].PhanHe[0] != "kho" {
		t.Errorf("PhanHe = %v, muon [kho]: san chung cua module auth phai bi bo truoc khi gom (ADR-0028)", ra[0].PhanHe)
	}
}

// TestDanhMucVaiTro_HaiMangPhanHeLuonCungDoDai la bai khoa BAT BIEN cua cap phan_he/nhan_phan_he.
//
// Hai mang di ra SONG SONG tung phan tu, va man hinh ghep chung theo CHI SO. Lech mot phan tu la
// dan nhan cua module nay cho module kia - mot man hinh sai ma van day du, tuc thu khong ai nhin
// ra bang mat va khong loi nao bao. Bai nay do tren MOI dong cua danh muc chu khong mot dong mau.
func TestDanhMucVaiTro_HaiMangPhanHeLuonCungDoDai(t *testing.T) {
	repo := &roleRepoGia{dong: dongDanhMucDayDu()}
	svc := dungServiceDanhMuc(repo)

	ra, _, err := svc.DanhMucVaiTro(context.Background(), actorQuanTri("cong-ty-nao-cung-duoc"),
		service.DanhMucVaiTroInput{Page: 1, PageSize: 100})
	if err != nil {
		t.Fatalf("DanhMucVaiTro loi: %v", err)
	}
	if len(ra) == 0 {
		t.Fatal("danh muc rong - bai nay khong do duoc gi")
	}
	for _, d := range ra {
		if len(d.NhanPhanHe) != len(d.PhanHe) {
			t.Errorf("vai tro %q: PhanHe %v (%d phan tu) va NhanPhanHe %v (%d phan tu) LECH do dai - "+
				"man hinh ghep hai mang theo chi so, nen mot lan lech la mot lan dan nhan sai module",
				d.Ma, d.PhanHe, len(d.PhanHe), d.NhanPhanHe, len(d.NhanPhanHe))
		}
	}
}
```

- [ ] **Step 2: Chạy cho thấy đỏ**

```bash
go test ./modules/auth/internal/service/ -run 'TestDanhMucVaiTro_'
```

Expected: lỗi biên dịch — `DongDanhMucVaiTro` chưa có `ID`, `MoTa`, `DangDung`, `HeThongTao`, `SoNguoiGiu`.

- [ ] **Step 3: Mở rộng kiểu và hai câu SQL của repository**

`role_repository.go`, thay khối `DongDanhMucVaiTro` (dòng 466-475) và hai hằng SQL (dòng 500-510):

```go
// DongDanhMucVaiTro la MOT dong cua danh muc vai tro.
//
// Cot `id` tung CO Y vang mat: hop dong cu cua `GET /roles` la `{ma, nhan}` va khong nguoi doc
// nao can dinh danh hang. Khoi ghi chu do viet san ngay het han cua chinh no - *"Ngay duong
// CRUD vai tro cua dot 2b can id, no duoc them cung nguoi doc cua no"* - va ngay do la
// 2026-08-27: `PATCH /roles/:id` doi mot id that.
//
// Nam truong con lai den tu 000033 va tu mot phep dem. `SoNguoiGiu` KHONG phai mot cot: no la
// count tren user_company_roles con song, va mot cot dem se la mot ban sao se lech.
type DongDanhMucVaiTro struct {
	ID         string `db:"id"`
	Ma         string `db:"code"`
	Nhan       string `db:"name"`
	MoTa       string `db:"description"`
	DangDung   bool   `db:"is_active"`
	HeThongTao bool   `db:"is_system"`
	SoNguoiGiu int64  `db:"so_nguoi_giu"`
}
```

```go
// --- Hai cau list, mot cau cho moi chieu sap xep ---
//
// (Khoi ghi chu cu giu nguyen tu day toi het doan noi ve tie-breaker va ve LIMIT/OFFSET.)
//
// # Phep dem so nguoi giu, va vi sao no la mot SUBQUERY DUOC JOIN chu khong mot correlated
//   subquery trong danh sach SELECT
//
// Ca hai hinh dang cho ra cung con so. Khac biet nam o cot xuat hien trong menh de WHERE:
// mot correlated subquery phai viet `WHERE ucr.role_id = r.id`, va `role_id` la cot THU BA cua
// uq_user_company_roles_company_id_user_company_id_role_id - khong index nao dat no o vi tri
// mot hay hai, nen R-09 doi mot index moi cho mot phep dem hien tren mot man hinh quan tri.
// Hinh dang duoi day loc theo `company_id` - cot DAN DAU cua chinh index ay - roi GROUP BY
// trong bo nho, tuc no doc dung phan cua phan vung nay va khong doi index nao.
//
// `deleted_at IS NULL` o CA HAI ve va khong ve nao thay duoc ve nao (R-18): mot phep gan da thu
// hoi khong duoc dem, con mot vai tro da xoa mem thi khong duoc hien.
//
// KHONG loc `is_active` o day, khac selectQuyenTheoVaiTroSQL: man quan tri phai thay ca vai
// tro da tat de bat lai duoc. Hai cau doc cung mot bang tra loi hai cau hoi khac nhau.
const selectDanhMucVaiTroTangSQL = `
SELECT r.id, r.code, r.name, r.description, r.is_active, r.is_system,
       coalesce(g.so, 0) AS so_nguoi_giu
FROM roles r
LEFT JOIN (SELECT role_id, count(*) AS so
             FROM user_company_roles
            WHERE company_id = $1 AND deleted_at IS NULL
            GROUP BY role_id) AS g ON g.role_id = r.id
WHERE r.company_id = $1 AND r.deleted_at IS NULL
ORDER BY r.code ASC`

const selectDanhMucVaiTroGiamSQL = `
SELECT r.id, r.code, r.name, r.description, r.is_active, r.is_system,
       coalesce(g.so, 0) AS so_nguoi_giu
FROM roles r
LEFT JOIN (SELECT role_id, count(*) AS so
             FROM user_company_roles
            WHERE company_id = $1 AND deleted_at IS NULL
            GROUP BY role_id) AS g ON g.role_id = r.id
WHERE r.company_id = $1 AND r.deleted_at IS NULL
ORDER BY r.code DESC`
```

- [ ] **Step 4: Tách vòng gom module thành `moduleCuaTapQuyen`**

`user_service.go`, thay khối dòng 1343-1375 trong `kiemGanMotVaiTro` bằng:

```go
	for _, m := range moduleCuaTapQuyen(quyen, s.quyenTuTacDong) {
		if err := s.authz.Can(ctx, actor, m+"."+permRoleAssignHauTo); err != nil {
			return loiThieuQuyenGanModule(err, m)
		}
	}
	return nil
}

// moduleCuaTapQuyen gom ten MODULE xuat hien trong mot tap quyen, sau khi da bo tap tu tac
// dong (ADR-0028), va tra ve chung DA SAP XEP.
//
// # Vi sao no la mot ham rieng
//
// Ba nguoi doc, mot phep tinh. kiemGanMotVaiTro hoi "gan vai tro nay doi cua cua module nao";
// RoleService.kiemGhiTapQuyen hoi cung cau do tren HIEU DOI XUNG cua hai tap quyen (ADR-0024
// muc 2); va DanhMucVaiTro hoi de dien cot `phan_he` cua man hinh. Ba ban cai dat la ba ban se
// lech, va hinh dang cua lo hong la: man hinh noi vai tro nay thuoc phan he A, con duong ghi
// doi cua cua phan he B.
//
// # Vi sao phep bo tap tu tac dong ap ca cho cot HIEN THI
//
// Bay vai tro mac dinh deu mang san chung `auth.self_read` va `auth.change_password`. Khong bo
// chung thi MOI dong tren man hinh deu mang phan he "Quan tri he thong", va mot cot ma moi hang
// deu giong nhau la mot cot khong noi len gi. Tieu chi cua ADR-0028 muc 1 - "chi tac dong len
// chinh nguoi giu" - dung cho ca cau hoi hien thi: hai ma do khong lam vai tro nay thuoc ve
// phan he Quan tri he thong theo bat cu nghia nao nguoi doc man hinh hieu.
//
// Sap xep de ket qua TAT DINH: thu tu duyet map cua Go ngau nhien theo tung lan chay, va ca mot
// cau loi goi ten module lan mot cot hien thi doi thu tu moi lan tai deu la thu khong test duoc.
//
// Chuoi khong co dau cham, hoac mo dau bang dau cham, cho ra chuoi rong va bi bo qua - xem
// moduleCuaQuyen. Cat tien to o day AN TOAN vi thu bi cat la MA QUYEN, khong phai ma vai tro
// (ADR-0024 muc 1).
func moduleCuaTapQuyen(quyen []string, tuTacDong map[string]struct{}) []string {
	mods := map[string]struct{}{}
	for _, p := range quyen {
		// Bo TRUOC khi gom, khong loc sau: mot module lot vao tap roi thi khong con biet no
		// vao nho ma nao.
		if _, tu := tuTacDong[p]; tu {
			continue
		}
		if m := moduleCuaQuyen(p); m != "" {
			mods[m] = struct{}{}
		}
	}
	// Slice RONG chu khong nil: no di thang vao mot truong JSON mang, va nil se tuan tu hoa
	// thanh `null` thay vi `[]` (C-API-03).
	ten := make([]string, 0, len(mods))
	for m := range mods {
		ten = append(ten, m)
	}
	sort.Strings(ten)
	return ten
}

// nhanCuaModule doi mot mang ma module thanh mang nhan tieng Viet SONG SONG tung phan tu.
//
// Module khong co trong bang nhan tra ve chinh ma cua no chu khong chuoi rong: mot o trong
// tren man hinh khong noi len gi, con mot ma tran thi it nhat noi rang bang nhan dang thieu
// mot dong - va do la thu nguoi doc bao lai duoc.
func nhanCuaModule(mods []string, bang map[string]string) []string {
	ra := make([]string, 0, len(mods))
	for _, m := range mods {
		if n, co := bang[m]; co {
			ra = append(ra, n)
			continue
		}
		ra = append(ra, m)
	}
	return ra
}
```

- [ ] **Step 5: Mở rộng `VaiTroKhaDung` và `DanhMucVaiTro`**

`user_service.go` dòng 152-164:

```go
// VaiTroKhaDung la MOT dong danh muc vai tro ma DanhMucVaiTro tra ra cho `GET /roles`.
//
// Tu dot 2b no mang chin truong chu khong hai, va endpoint van la MOT: vai tro ma admin khong
// gan duoc cung la vai tro admin khong sua duoc - cung mot luat tham quyen - nen danh sach da
// loc cua ADR-0032 chinh la danh sach dung cho man quan tri (spec muc 6.3). Them truong vao
// response khong phai breaking change (C-API-06).
type VaiTroKhaDung struct {
	Ma   string
	Nhan string

	ID         string
	MoTa       string
	DangDung   bool
	HeThongTao bool

	// PhanHe la tap module suy tu TAP QUYEN cua vai tro, khong tu tien to cua Ma (ADR-0024).
	PhanHe []string

	// Song song tung phan tu voi PhanHe, cung thu tu. Nhan song o Go (spec muc 6.2): frontend
	// khong tu map, va them mot module moi khong doi mot bang nhan thu hai.
	NhanPhanHe []string

	SoNguoiGiu int64
}
```

`DanhMucVaiTro`, thân vòng lặp (dòng 650-666):

```go
	ganDuoc := make([]VaiTroKhaDung, 0, len(rows))
	for _, r := range rows {
		err := s.kiemGanMotVaiTro(ctx, actor, r.Ma, chieuCapThem)
		if err == nil {
			// Doc lai tap quyen de dien `phan_he`. Loi goi nay KHONG them mot vong toi
			// database: authz.Checker cache theo phan vung (shared/authz/nguon_db.go), va
			// kiemGanMotVaiTro vua hoi dung cau nay cho dung vai tro nay.
			quyen, err := s.authz.QuyenCuaVaiTro(ctx, actor.CompanyID, r.Ma)
			if err != nil {
				return nil, 0, err
			}
			// Goi moduleCuaTapQuyen DUNG MOT LAN roi dan nhan tu chinh ket qua do: hai lan goi
			// la hai co hoi cho hai mang lech nhau, va hai mang lech nhau la mot man hinh dan
			// nhan cua module nay cho module kia.
			mods := moduleCuaTapQuyen(quyen, s.quyenTuTacDong)
			ganDuoc = append(ganDuoc, VaiTroKhaDung{
				Ma: r.Ma, Nhan: r.Nhan,
				ID: r.ID, MoTa: r.MoTa, DangDung: r.DangDung, HeThongTao: r.HeThongTao,
				PhanHe:     mods,
				NhanPhanHe: nhanCuaModule(mods, s.nhanPhanHe),
				SoNguoiGiu: r.SoNguoiGiu,
			})
			continue
		}
		if !laTuChoiGan(err) {
			return nil, 0, err
		}
	}
```

Bảng nhãn phải đi vào `UserService` qua `UserDeps`, đúng lối `QuyenTuTacDong` đang đi. `user_service.go`, thêm vào `UserDeps` (dòng 118-168):

```go
	// NhanPhanHe tra nhan tieng Viet cua mot ma module: "inventory" -> "Kho van".
	//
	// No den tu composition root vi cung ly do voi QuyenTuTacDong: nguon that la bang 50 dong o
	// cmd/internal/vaitro, cho duy nhat duoc biet ten cua ca ba module (R-05).
	//
	// Rong la HOP LE chu khong mot loi: nhanCuaModule tra ve chinh ma module khi khong tra duoc
	// nhan, nen mot root khong tiem bang van cho ra mot man hinh doc duoc - chi la doc bang ma.
	NhanPhanHe map[string]string
```

`NewUserService` gán thẳng `nhanPhanHe: d.NhanPhanHe` vào struct `UserService`.

`modules/auth/module.go`, trong `New` — dựng bảng ngay cạnh `danhMucQuyen` đã đổi kiểu ở Task 10 Step 5:

```go
	// Bang nhan phan he dung TU DanhMucQuyen chu khong tu mot hang thu hai: mot bang thu hai la
	// mot ban sao se lech, va cho lech se hien ra tren man hinh chu khong o mot bai test.
	nhanPhanHe := make(map[string]string, len(d.DanhMucQuyen))
	for _, q := range d.DanhMucQuyen {
		nhanPhanHe[q.PhanHe] = q.NhanPhanHe
	}
```

rồi thêm `NhanPhanHe: nhanPhanHe,` vào khối `service.UserDeps{...}` (dòng 322). `RoleDeps` nhận đúng bảng đó ở Task 16.

- [ ] **Step 6: Mở rộng DTO của handler**

`user_role_handler.go` dòng 59-68 và 111-120:

```go
// VaiTroKhaDungDTO la mot dong cua danh muc vai tro.
//
// Hai truong dau la hop dong CU va chung khong doi - `VaiTroKhaDungDTO {ma, nhan}` ben frontend
// van doc duoc y nhu truoc (C-API-06, CL-API-16). Bay truong sau la phan them cua dot 2b.
//
// No van KHONG mang mot ten permission nao. `phan_he` la ten MODULE, thu da nam san trong tien
// to cua moi ma vai tro hien tren chinh man hinh do - khong phai mot manh du lieu de frontend
// tu doi chieu roi an bot lua chon.
type VaiTroKhaDungDTO struct {
	Ma   string `json:"ma"`
	Nhan string `json:"nhan"`

	ID         string   `json:"id"`
	MoTa       string   `json:"mo_ta"`
	DangDung   bool     `json:"dang_dung"`
	HeThongTao bool     `json:"he_thong_tao"`
	PhanHe     []string `json:"phan_he"`
	NhanPhanHe []string `json:"nhan_phan_he"`
	SoNguoiGiu int64    `json:"so_nguoi_giu"`
}
```

```go
	ra := make([]VaiTroKhaDungDTO, 0, len(ds))
	for _, v := range ds {
		ra = append(ra, VaiTroKhaDungDTO{
			Ma: v.Ma, Nhan: v.Nhan,
			ID: v.ID, MoTa: v.MoTa, DangDung: v.DangDung, HeThongTao: v.HeThongTao,
			PhanHe: v.PhanHe, NhanPhanHe: v.NhanPhanHe, SoNguoiGiu: v.SoNguoiGiu,
		})
	}
```

- [ ] **Step 7: Bài DB đo `so_nguoi_giu` và `is_active` không lọc ở danh mục**

Thêm vào `role_repository_db_test.go`:

```go
// TestDanhMuc_DemNguoiGiuVaGiuCaVaiTroDaTat chot hai menh de cua muc 6.3 tren SQL that.
//
// Phep dem chi do duoc o day: no la mot LEFT JOIN tren mot subquery gom nhom, va khong mot bai
// o tang service nao nhin thay hinh dang do.
func TestDanhMuc_DemNguoiGiuVaGiuCaVaiTroDaTat(t *testing.T) {
	db := testutil.Connect(t)
	ctx := context.Background()

	congTyID := themCongTyTest(t, db)
	testutil.TaoVaiTroKemQuyen(t, db, congTyID, "kho.co_nguoi_giu", "inventory.item_list")
	testutil.TaoVaiTroKemQuyen(t, db, congTyID, "kho.da_tat", "inventory.item_list")

	const tat = `UPDATE roles SET is_active = false WHERE company_id = $1 AND code = 'kho.da_tat'`
	if _, err := db.Exec(tat, congTyID); err != nil {
		t.Fatalf("tat vai tro: %v", err)
	}
	ganChoHaiNguoi(t, db, congTyID, "kho.co_nguoi_giu")

	ds, err := repository.NewRoleRepository().DanhMuc(ctx, db, congTyID, "code")
	if err != nil {
		t.Fatalf("DanhMuc: %v", err)
	}

	theoMa := map[string]repository.DongDanhMucVaiTro{}
	for _, d := range ds {
		theoMa[d.Ma] = d
	}
	if got := theoMa["kho.co_nguoi_giu"].SoNguoiGiu; got != 2 {
		t.Errorf("so_nguoi_giu = %d, muon 2", got)
	}
	daTat, co := theoMa["kho.da_tat"]
	if !co {
		t.Fatal("vai tro da tat bien khoi danh muc - man quan tri se khong bat lai duoc no")
	}
	if daTat.DangDung {
		t.Error("vai tro da tat mang dang_dung = true")
	}
	if daTat.SoNguoiGiu != 0 {
		t.Errorf("vai tro khong ai giu co so_nguoi_giu = %d, muon 0 - coalesce cua LEFT JOIN chua chay", daTat.SoNguoiGiu)
	}
}
```

`ganChoHaiNguoi` chèn hai hàng `user_companies` + `user_company_roles` cho phân vùng đó — viết ngay trong file test, dùng khuôn của `testutil.TaoVaiTroKemQuyen` (actor hệ thống, đếm `RowsAffected`).

- [ ] **Step 8: Vá `roleRepoGia`**

`user_service_danhmuc_test.go` — chưa cần method mới ở task này (đó là Task 13), nhưng `dongDanhMucTest()` và `dongDanhMucDayDu()` phải gán `ID` cho từng dòng, nếu không mọi `VaiTroKhaDungDTO.id` ra chuỗi rỗng và không bài nào bắt được. Gán `ID: uuid.NewString()` cho mọi dòng. `dungServiceDanhMuc` cũng phải tiêm `NhanPhanHe: map[string]string{"kho": "Kho vận", ...}` vào `service.UserDeps`, nếu không mọi `nhan_phan_he` ra đúng bằng mã module và bài nhãn ở Step 1 đỏ.

- [ ] **Step 9: Chạy cho thấy xanh, rồi commit**

```bash
go build ./... && go run ./cmd/dev arch
go test ./modules/auth/internal/service/ -run 'TestDanhMucVaiTro_|TestDanhMucQuyen'
# rồi CI hoặc VPS cho bộ đầy đủ
git add modules/auth/internal/repository/role_repository.go \
        modules/auth/internal/repository/role_repository_db_test.go \
        modules/auth/internal/service/user_service.go \
        modules/auth/internal/service/user_service_danhmuc_test.go \
        modules/auth/module.go \
        modules/auth/internal/handler/user_role_handler.go
git commit -m "feat(auth): GET /roles mang them bay truong

id, mo_ta, dang_dung, he_thong_tao, phan_he, nhan_phan_he, so_nguoi_giu. phan_he suy từ
role_permissions chứ không từ tiền tố roles.code (ADR-0024), và bỏ tập tự tác
động trước khi gom — không thì mọi dòng đều mang cùng một phân hệ.
Phân trang vẫn chạy sau phép lọc thẩm quyền (ADR-0032)."
```

---

## Task 13: Đường ghi ở tầng repository

**Files:**
- Modify: `backend-erp/modules/auth/internal/repository/role_repository.go:140-191` (interface) + phần cài đặt
- Modify: `backend-erp/modules/auth/internal/service/user_service_danhmuc_test.go:44-75` (`roleRepoGia`)
- Test: `backend-erp/modules/auth/internal/repository/role_repository_db_test.go`

- [ ] **Step 1: Viết test đỏ trước — ba bài nặng nhất**

```go
// TestMaDaDung_DemCaHANG_BIA_MO la hien than bang may cua rang buoc 6.
//
// uq_roles_company_id_code la PARTIAL index (WHERE deleted_at IS NULL), nen mot ma song nam
// canh mot ma bia mo la HOAN TOAN HOP LE voi database. Neu duong sinh ma chi hoi hang con
// song, no se sinh ra mot ma trung voi mot vai tro da bi xoa - va hai hang do khong phan biet
// duoc trong audit_logs, thu chi ghi ma chu khong ghi id.
func TestMaDaDung_DemCaHangBiaMo(t *testing.T) {
	db := testutil.Connect(t)
	ctx := context.Background()

	congTyID := themCongTyTest(t, db)
	testutil.TaoVaiTro(t, db, congTyID, "kho.da_xoa")
	const xoa = `UPDATE roles SET deleted_at = now() WHERE company_id = $1 AND code = 'kho.da_xoa'`
	if _, err := db.Exec(xoa, congTyID); err != nil {
		t.Fatalf("xoa mem vai tro: %v", err)
	}

	repo := repository.NewRoleRepository()
	daDung, err := repo.MaDaDung(ctx, db, congTyID, "kho.da_xoa")
	if err != nil {
		t.Fatalf("MaDaDung: %v", err)
	}
	if !daDung {
		t.Error("MaDaDung noi KHONG cho mot ma da co hang bia mo - duong sinh ma se de ra mot ma trung voi mot vai tro da xoa (ADR-0027 muc 3)")
	}
}

// TestTao_RoiDoc_RoiSua di het mot vong doi cua mot vai tro do quan tri dat ra.
//
// Mot bai chu khong ba, va do la co y: ba bai rieng se phai dung lai cung mot fixture ba lan,
// con mot bai di het vong thi no do luon rang buoc giua ba buoc - id tra ve tu Tao phai la id
// ma TheoID va Sua doc duoc.
func TestTao_RoiDoc_RoiSua(t *testing.T) {
	db := testutil.Connect(t)
	ctx := context.Background()

	congTyID := themCongTyTest(t, db)
	repo := repository.NewRoleRepository()
	const actorID = "00000000-0000-4000-8000-000000000001"

	id, err := repo.Tao(ctx, db, congTyID, actorID, repository.TaoVaiTroRow{
		Ma: "kho.thu_kho_ca_dem", Nhan: "Thủ kho ca đêm", MoTa: "Ca 22h-6h",
	})
	if err != nil {
		t.Fatalf("Tao: %v", err)
	}

	d, err := repo.TheoID(ctx, db, congTyID, id)
	if err != nil {
		t.Fatalf("TheoID: %v", err)
	}
	if d.Ma != "kho.thu_kho_ca_dem" || d.MoTa != "Ca 22h-6h" {
		t.Errorf("doc lai = %+v, khong khop thu vua ghi", d)
	}
	if !d.DangDung {
		t.Error("vai tro vua tao mang dang_dung = false - mac dinh cua cot is_active phai la true")
	}
	if d.HeThongTao {
		t.Error("vai tro do quan tri tao mang he_thong_tao = true - duong nay luon dat false (spec muc 6.4)")
	}

	tenMoi, dungMoi := "Thủ kho đêm", false
	if err := repo.Sua(ctx, db, congTyID, actorID, id, repository.SuaVaiTroRow{Nhan: &tenMoi, DangDung: &dungMoi}); err != nil {
		t.Fatalf("Sua: %v", err)
	}
	d, err = repo.TheoID(ctx, db, congTyID, id)
	if err != nil {
		t.Fatalf("TheoID sau Sua: %v", err)
	}
	if d.Nhan != tenMoi || d.DangDung {
		t.Errorf("sau Sua = %+v, muon nhan %q va dang_dung false", d, tenMoi)
	}
	if d.MoTa != "Ca 22h-6h" {
		t.Errorf("Sua da ghi de mo ta thanh %q - truong nil phai KHONG duoc cham", d.MoTa)
	}
}

// TestThemQuyen_GoQuyen_DocLai chot rang duong ghi tap quyen xoa MEM va khong bao gio DELETE.
//
// R-18 khong co ngoai le cho bang nay, va he qua thuc te la mot cai bay: sau khi go mot ma roi
// tick lai chinh no, cau chen phai sinh mot hang MOI - partial unique index chi phu hang con
// song nen khong co dung do - chu khong duoc hoi sinh hang cu bang cach xoa deleted_at.
func TestThemQuyen_GoQuyen_DocLai(t *testing.T) {
	db := testutil.Connect(t)
	ctx := context.Background()

	congTyID := themCongTyTest(t, db)
	repo := repository.NewRoleRepository()
	const actorID = "00000000-0000-4000-8000-000000000001"

	id, err := repo.Tao(ctx, db, congTyID, actorID, repository.TaoVaiTroRow{Ma: "kho.a", Nhan: "A"})
	if err != nil {
		t.Fatalf("Tao: %v", err)
	}
	if err := repo.ThemQuyen(ctx, db, congTyID, actorID, id, []string{"inventory.item_list", "inventory.item_read"}); err != nil {
		t.Fatalf("ThemQuyen: %v", err)
	}
	if err := repo.GoQuyen(ctx, db, congTyID, actorID, id, []string{"inventory.item_read"}); err != nil {
		t.Fatalf("GoQuyen: %v", err)
	}

	con, err := repo.QuyenTheoVaiTroID(ctx, db, congTyID, id)
	if err != nil {
		t.Fatalf("QuyenTheoVaiTroID: %v", err)
	}
	if len(con) != 1 || con[0] != "inventory.item_list" {
		t.Fatalf("con lai %v, muon [inventory.item_list]", con)
	}

	var biaMo int
	const dem = `SELECT count(*) FROM role_permissions WHERE role_id = $1 AND deleted_at IS NOT NULL`
	if err := db.Get(&biaMo, dem, id); err != nil {
		t.Fatalf("dem hang bia mo: %v", err)
	}
	if biaMo != 1 {
		t.Errorf("%d hang bia mo, muon 1 - GoQuyen phai xoa MEM chu khong DELETE (R-18)", biaMo)
	}

	// Tick lai chinh ma vua go: phai ra MOT hang moi, khong duoc hoi sinh hang bia mo.
	if err := repo.ThemQuyen(ctx, db, congTyID, actorID, id, []string{"inventory.item_read"}); err != nil {
		t.Fatalf("ThemQuyen lan hai: %v", err)
	}
	con, err = repo.QuyenTheoVaiTroID(ctx, db, congTyID, id)
	if err != nil {
		t.Fatalf("QuyenTheoVaiTroID lan hai: %v", err)
	}
	if len(con) != 2 {
		t.Errorf("con lai %v, muon hai ma - tick lai mot ma vua go phai chay duoc", con)
	}
}
```

- [ ] **Step 2: Chạy cho thấy đỏ (CI hoặc VPS)**

Expected: lỗi biên dịch — bảy method chưa tồn tại.

- [ ] **Step 3: Mở rộng interface `RoleRepository`**

Thêm vào `RoleRepository` (sau `DanhMuc`, dòng 190):

```go
	// MaDaDung hoi mot ma vai tro DA TUNG duoc dung trong phan vung nay chua - KE CA boi mot
	// hang da xoa mem (ADR-0027 muc 3).
	//
	// Vi sao "ke ca": uq_roles_company_id_code la partial index `WHERE deleted_at IS NULL`, nen
	// mot ma song nam canh mot ma bia mo la hop le voi database. Neu duong sinh ma chi hoi hang
	// con song, no se de ra mot vai tro moi trung ma voi mot vai tro da xoa - va audit_logs ghi
	// MA chu khong ghi id, nen lich su cua hai vai tro do tron lam mot vinh vien.
	MaDaDung(ctx context.Context, db sharedDB.DBTX, companyID, code string) (bool, error)

	// Tao chen MOT hang roles va tra ve id cua no.
	//
	// Nguoi goi truyen tx: hang roles va cac hang role_permissions cua no phai cung song cung
	// chet - mot vai tro tao ra ma tap quyen chen hut la mot vai tro gan duoc ma khong lam duoc
	// gi (C-GO-03).
	Tao(ctx context.Context, db sharedDB.DBTX, companyID, actorID string, r TaoVaiTroRow) (string, error)

	// TheoID doc MOT hang roles con song cua phan vung, du sau truong nhu DanhMuc.
	//
	// sql.ErrNoRows di ra NGUYEN TRANG (R-03): tang service moi la cho biet mot vai tro khong
	// tim thay nghia la 404.
	TheoID(ctx context.Context, db sharedDB.DBTX, companyID, id string) (DongDanhMucVaiTro, error)

	// Sua cap nhat nhung truong KHAC nil cua r; truong nil khong duoc cham.
	//
	// KHONG co truong Ma trong SuaVaiTroRow, va do la cach cuong che rang buoc 5 o dung tang
	// re nhat: roles.code bat bien sau khi tao (ADR-0023 muc 5), va migration co y khong cuong
	// che dieu do vi mot CHECK khong dien ta duoc "khong doi sau khi tao". Khong co truong thi
	// khong co cau lenh nao ghi duoc cot do, va do la mot loi bien dich chu khong mot phep kiem
	// ai do quen goi.
	Sua(ctx context.Context, db sharedDB.DBTX, companyID, actorID, id string, r SuaVaiTroRow) error

	// QuyenTheoVaiTroID doc tap ma quyen CON SONG cua MOT vai tro, DA SAP XEP.
	//
	// Doc tu DATABASE chu khong tu authz.QuyenCuaVaiTro, va do la mot rang buoc chu khong mot
	// lua chon: authz cache 30 giay (shared/authz/nguon_db.go), nen mot lan ghi doc tap cu tu
	// cache se tinh hieu doi xung tren mot buc anh cu toi 30 giay - va ket qua la go nham hoac
	// chen trung. Duong DOC dung cache duoc; duong GHI thi khong.
	QuyenTheoVaiTroID(ctx context.Context, db sharedDB.DBTX, companyID, roleID string) ([]string, error)

	// ThemQuyen chen cac hang role_permissions con thieu cho mot vai tro.
	ThemQuyen(ctx context.Context, db sharedDB.DBTX, companyID, actorID, roleID string, quyen []string) error

	// GoQuyen xoa MEM cac hang role_permissions cua mot vai tro (R-18).
	GoQuyen(ctx context.Context, db sharedDB.DBTX, companyID, actorID, roleID string, quyen []string) error
```

Và hai kiểu tham số, khai ngay dưới `VaiTroMacDinh`:

```go
// TaoVaiTroRow la mot hang roles sap duoc chen, o dang tang service noi ra no.
//
// KHONG co truong DangDung: cot is_active mac dinh true (000033), va mot vai tro vua tao ra
// da tat san la mot man hinh khong ai giai thich duoc. KHONG co truong HeThongTao: duong nay
// luon dat false (spec muc 6.4), va mot truong o day se la mot cho de ai do dat true.
type TaoVaiTroRow struct {
	Ma   string
	Nhan string
	MoTa string
}

// SuaVaiTroRow la ba truong TUY CHON cua mot lan sua. nil nghia la "khong gui", va truong do
// khong duoc cham - khac chuoi rong, thu co nghia "xoa trang mo ta".
//
// KHONG co truong Ma. Xem ghi chu cua RoleRepository.Sua.
type SuaVaiTroRow struct {
	Nhan     *string
	MoTa     *string
	DangDung *bool
}
```

- [ ] **Step 4: Viết bảy hằng SQL và bảy method**

Thêm ở cuối `role_repository.go`:

```go
// --- Duong GHI vai tro: dot 2b ---

// maDaDungSQL hoi mot ma da tung ton tai trong phan vung chua, KHONG loc deleted_at.
//
// Thieu bo loc do o day KHONG phai cho quen - do la ca noi dung cua ADR-0027 muc 3, y het
// menh de NOT EXISTS cua insertVaiTroConThieuSQL. `EXISTS` chu khong `count(*)`: cau tra loi
// la mot bit, va Postgres dung ngay khi thay hang dau.
//
// uq_roles_company_id_code phuc vu ca hai cot cua menh de WHERE (R-09), du no la partial: mot
// partial index khong dung duoc cho cau nay o phan bia mo, nen phep hoi rot ve mot lan quet
// phan roles cua phan vung. Chap nhan duoc: tap do la so vai tro mot quan tri go tay.
const maDaDungSQL = `
SELECT EXISTS (SELECT 1 FROM roles WHERE company_id = $1 AND code = $2)`

func (r *roleWriteRepo) MaDaDung(ctx context.Context, db sharedDB.DBTX, companyID, code string) (bool, error) {
	var co bool
	if err := db.GetContext(ctx, &co, maDaDungSQL, companyID, code); err != nil {
		return false, fmt.Errorf("tra ma vai tro %s cua phan vung %s: %w", code, companyID, err)
	}
	return co, nil
}

// insertVaiTroSQL chen MOT hang roles do quan tri dat ra.
//
// is_system KHONG co trong danh sach cot: cot do mac dinh false (000033), va false la gia tri
// DUNG cho duong nay - `is_system` luon false cho vai tro do nguoi dung tao (spec muc 6.4).
// Khai `false` tuong minh o day se la mot cho de ai do doi thanh mot bieu thuc.
//
// Hang companies KHONG xuat hien trong cau nay, khac insertVaiTroMacDinhSQL: companyID den tu
// actor.CompanyID cua mot phien dang nhap that, tuc mot phan vung con song theo dinh nghia -
// khong ai dang nhap duoc vao mot phan vung da vo hieu hoa.
const insertVaiTroSQL = `
INSERT INTO roles (company_id, code, name, description, created_by, updated_by)
VALUES ($1, $2, $3, $4, $5::uuid, $5::uuid)
RETURNING id`

func (r *roleWriteRepo) Tao(ctx context.Context, db sharedDB.DBTX, companyID, actorID string, row TaoVaiTroRow) (string, error) {
	var id string
	if err := db.GetContext(ctx, &id, insertVaiTroSQL, companyID, row.Ma, row.Nhan, row.MoTa, actorID); err != nil {
		// Loi di ra NGUYEN TRANG, khong dich: 23505 tren uq_roles_company_id_code la mot loi
		// NGHIEP VU, va R-03 chot rang chi service dich duoc - chi no biet ten constraint ay
		// ung voi quy tac nao. Boc bang %w de errors.As o tang tren con thay *pgconn.PgError.
		return "", fmt.Errorf("chen vai tro %s cho phan vung %s: %w", row.Ma, companyID, err)
	}
	return id, nil
}

// selectVaiTroTheoIDSQL doc MOT hang, du sau truong nhu danh muc.
//
// Phep dem so nguoi giu lap lai hinh dang cua selectDanhMucVaiTro*SQL - LEFT JOIN mot subquery
// gom nhom - chu khong doi sang correlated subquery, va vi dung ly do da ghi o do: mot menh de
// `WHERE ucr.role_id = $2` dat `role_id` vao vi tri ma khong index nao phuc vu (R-09).
//
// `id = $2` la khoa chinh nen no da co index; `company_id = $1` dung canh no la R-06, va no
// khong thua: thieu no thi mot id doan dung se doc duoc vai tro cua phan vung khac.
const selectVaiTroTheoIDSQL = `
SELECT r.id, r.code, r.name, r.description, r.is_active, r.is_system,
       coalesce(g.so, 0) AS so_nguoi_giu
FROM roles r
LEFT JOIN (SELECT role_id, count(*) AS so
             FROM user_company_roles
            WHERE company_id = $1 AND deleted_at IS NULL
            GROUP BY role_id) AS g ON g.role_id = r.id
WHERE r.company_id = $1 AND r.id = $2 AND r.deleted_at IS NULL`

func (r *roleWriteRepo) TheoID(ctx context.Context, db sharedDB.DBTX, companyID, id string) (DongDanhMucVaiTro, error) {
	var d DongDanhMucVaiTro
	if err := db.GetContext(ctx, &d, selectVaiTroTheoIDSQL, companyID, id); err != nil {
		// sql.ErrNoRows di ra NGUYEN TRANG (R-03, P-ERR): chi tang service biet "khong tim
		// thay" o day nghia la mot 404.
		return d, err
	}
	return d, nil
}

// updateVaiTroSQL sua ba truong TUY CHON trong DUNG mot cau lenh.
//
// `coalesce($3, name)` la cach dien "nil thi khong cham" ma khong phai ghep chuoi SQL theo tap
// truong duoc gui - thu C-GO-07 cam trong file repository. Ba tham so deu la con tro o Go, nen
// nil di xuong thanh NULL va coalesce tra ve gia tri dang co.
//
// Chuoi RONG khac nil, va khac biet do co nghia: `""` la "xoa trang o mo ta", con nil la
// "khong gui". coalesce phan biet dung hai ca do vi `''` khong phai NULL.
//
// KHONG co cot `code` trong cau nay (rang buoc 5). Khong co cot thi khong co duong ghi, va do
// la hinh dang re nhat de cuong che mot bat bien.
//
// updated_by la ACTOR, khong phai system actor: co nguoi that vua bam nut (R-17).
const updateVaiTroSQL = `
UPDATE roles
   SET name        = coalesce($3, name),
       description = coalesce($4, description),
       is_active   = coalesce($5, is_active),
       updated_at  = now(),
       updated_by  = $6::uuid
 WHERE company_id = $1 AND id = $2 AND deleted_at IS NULL`

func (r *roleWriteRepo) Sua(ctx context.Context, db sharedDB.DBTX, companyID, actorID, id string, row SuaVaiTroRow) error {
	ra, err := db.ExecContext(ctx, updateVaiTroSQL, companyID, id, row.Nhan, row.MoTa, row.DangDung, actorID)
	if err != nil {
		return fmt.Errorf("sua vai tro %s cua phan vung %s: %w", id, companyID, err)
	}
	n, err := ra.RowsAffected()
	if err != nil {
		return fmt.Errorf("dem hang da sua cho vai tro %s: %w", id, err)
	}
	if n == 0 {
		// Boc sql.ErrNoRows chu khong dung mot loi moi: R-03 cam repository sinh loi nghiep vu,
		// va cau chuyen ky thuat o day dung la "khong hang nao khop". Cung sentinel ma
		// companyRepo.UpdateName tra, nen hai duong doc giong nhau o tang tren.
		return fmt.Errorf("sua vai tro %s cua phan vung %s: khong hang nao khop: %w", id, companyID, sql.ErrNoRows)
	}
	return nil
}

// selectQuyenTheoVaiTroIDSQL doc tap ma quyen CON SONG cua MOT vai tro.
//
// `company_id = $1` loc thang tren bang LA (R-06), va no khong thua du `role_id` da hep: khong
// khoa ngoai nao ep role_permissions.company_id khop roles.company_id (migration 000025), nen
// mot hang mang phan vung khac van treo hop le tren mot vai tro cua phan vung nay.
//
// ORDER BY co mat o day, khac selectQuyenTheoVaiTroSQL: nguoi goi tinh HIEU DOI XUNG roi dung
// thong diep tu choi tu ket qua, va mot thong diep goi ten ma theo thu tu ngau nhien la mot
// thong diep khong test duoc. `permission_code` khong co index rieng - no la cot thu ba cua
// uq_role_permissions_* - nhung day khong phai mot `sort` do client gui (R-12) ma la mot thu tu
// co dinh tren mot tap vai chuc dong da loc theo role_id.
const selectQuyenTheoVaiTroIDSQL = `
SELECT permission_code
FROM role_permissions
WHERE company_id = $1 AND role_id = $2 AND deleted_at IS NULL
ORDER BY permission_code ASC`

func (r *roleWriteRepo) QuyenTheoVaiTroID(ctx context.Context, db sharedDB.DBTX, companyID, roleID string) ([]string, error) {
	// Slice RONG chu khong nil: tap quyen rong la hop le - quan tri tao vai tro roi chua tick
	// gi - va nguoi goi lap tren ket qua nay.
	ra := []string{}
	if err := db.SelectContext(ctx, &ra, selectQuyenTheoVaiTroIDSQL, companyID, roleID); err != nil {
		return nil, fmt.Errorf("doc tap quyen cua vai tro %s: %w", roleID, err)
	}
	return ra, nil
}

// insertQuyenVaiTroSQL chen ca tap ma quyen trong DUNG mot cau lenh.
//
// unnest nam trong mot subquery co alias chu khong dung thang sau FROM: bo kiem doc ten bang
// ngay sau FROM/JOIN nen `FROM unnest(...)` bi doc thanh mot bang ten "unnest" - cung ly do da
// ghi o insertVaiTroMacDinhSQL.
//
// KHONG co ON CONFLICT, va do la co y: tang service da tinh HIEU DOI XUNG nen tap di xuong day
// chi chua ma CHUA CO. Mot ON CONFLICT o day se nuot mat truong hop tang tren tinh sai, va cai
// sai do se lo ra o mot man hinh phan quyen vai tuan sau.
const insertQuyenVaiTroSQL = `
INSERT INTO role_permissions (company_id, role_id, permission_code, created_by, updated_by)
SELECT $1, $2, moi.ma, $4::uuid, $4::uuid
FROM (SELECT unnest($3::text[]) AS ma) AS moi`

func (r *roleWriteRepo) ThemQuyen(ctx context.Context, db sharedDB.DBTX, companyID, actorID, roleID string, quyen []string) error {
	if len(quyen) == 0 {
		return nil
	}
	ra, err := db.ExecContext(ctx, insertQuyenVaiTroSQL, companyID, roleID, quyen, actorID)
	if err != nil {
		return fmt.Errorf("chen tap quyen cho vai tro %s: %w", roleID, err)
	}
	n, err := ra.RowsAffected()
	if err != nil {
		return fmt.Errorf("dem hang quyen da chen cho vai tro %s: %w", roleID, err)
	}
	if int(n) != len(quyen) {
		return fmt.Errorf("chen tap quyen cho vai tro %s: chen %d/%d hang: %w", roleID, n, len(quyen), sql.ErrNoRows)
	}
	return nil
}

// softDeleteQuyenVaiTroSQL xoa MEM cac hang role_permissions cua mot vai tro (R-18).
//
// UPDATE chu khong DELETE, va khong can comment `-- hard-delete: ADR-00xx` nao vi khong co cau
// DELETE nao: bang nay co cot deleted_at, nen xoa vat ly la thu R-18 chan.
//
// `= ANY($3)` chu khong `IN (...)`: danh sach do dai bien thien theo so o tick bi go, va mot
// menh de IN sinh theo so phan tu doi ghep chuoi - dung thu C-GO-07 cam.
//
// `deleted_at IS NULL` trong WHERE giu cho mot lan chay lai khong doi deleted_at cua hang da
// xoa: dau vet thoi diem xoa la thu duy nhat noi lai duoc mot o tick bi go luc nao.
const softDeleteQuyenVaiTroSQL = `
UPDATE role_permissions
   SET deleted_at = now(),
       updated_at = now(),
       updated_by = $4::uuid
 WHERE company_id = $1 AND role_id = $2 AND permission_code = ANY($3) AND deleted_at IS NULL`

func (r *roleWriteRepo) GoQuyen(ctx context.Context, db sharedDB.DBTX, companyID, actorID, roleID string, quyen []string) error {
	if len(quyen) == 0 {
		return nil
	}
	ra, err := db.ExecContext(ctx, softDeleteQuyenVaiTroSQL, companyID, roleID, quyen, actorID)
	if err != nil {
		return fmt.Errorf("go tap quyen cua vai tro %s: %w", roleID, err)
	}
	n, err := ra.RowsAffected()
	if err != nil {
		return fmt.Errorf("dem hang quyen da go cua vai tro %s: %w", roleID, err)
	}
	if int(n) != len(quyen) {
		return fmt.Errorf("go tap quyen cua vai tro %s: go %d/%d hang: %w", roleID, n, len(quyen), sql.ErrNoRows)
	}
	return nil
}
```

- [ ] **Step 5: Vá `roleRepoGia` cho biên dịch lại được**

`user_service_danhmuc_test.go`, thêm bảy method rỗng ngay dưới `MaQuyenDangCap` (dòng 66-70), theo đúng khuôn ba method đang có:

```go
// Bay method duoi day chi co mat de thoa interface, cung ly do voi NapBoMacDinh ngay tren:
// chung la duong GHI cua RoleService, khong phai duong doc cua UserService. Mot ban gia CO
// hanh vi cho chung se la mot ban gia hai service dung chung, va thu do khong noi len gi.
func (r *roleRepoGia) MaDaDung(context.Context, sharedDB.DBTX, string, string) (bool, error) {
	return false, nil
}

func (r *roleRepoGia) Tao(context.Context, sharedDB.DBTX, string, string, repository.TaoVaiTroRow) (string, error) {
	return "", nil
}

func (r *roleRepoGia) TheoID(context.Context, sharedDB.DBTX, string, string) (repository.DongDanhMucVaiTro, error) {
	return repository.DongDanhMucVaiTro{}, nil
}

func (r *roleRepoGia) Sua(context.Context, sharedDB.DBTX, string, string, string, repository.SuaVaiTroRow) error {
	return nil
}

func (r *roleRepoGia) QuyenTheoVaiTroID(context.Context, sharedDB.DBTX, string, string) ([]string, error) {
	return nil, nil
}

func (r *roleRepoGia) ThemQuyen(context.Context, sharedDB.DBTX, string, string, string, []string) error {
	return nil
}

func (r *roleRepoGia) GoQuyen(context.Context, sharedDB.DBTX, string, string, string, []string) error {
	return nil
}
```

- [ ] **Step 6: Chạy cho thấy xanh, rồi commit**

```bash
go build ./... && go vet ./... && go run ./cmd/dev arch
# rồi CI hoặc VPS cho ba bài DB mới
git add modules/auth/internal/repository/role_repository.go \
        modules/auth/internal/repository/role_repository_db_test.go \
        modules/auth/internal/service/user_service_danhmuc_test.go
git commit -m "feat(auth): bay method ghi vai tro o tang repository

MaDaDung hỏi bất kể deleted_at (ADR-0027 mục 3). SuaVaiTroRow cố ý không có
trường Ma: không có cột thì không có đường ghi, và roles.code bất biến trở thành
một lỗi biên dịch chứ không một phép kiểm ai đó quên gọi."
```

---

## Task 14: Sinh mã vai trò từ phân hệ và tên

**Files:**
- Create: `backend-erp/modules/auth/internal/service/role_ma_test.go`
- Modify: `backend-erp/modules/auth/internal/service/role_service.go` (thêm `boDauTiengViet`, `slugKhongDau`, `sinhMaVaiTro`)

Toàn bộ task này là hàm thuần — **chạy được dưới Windows**, không cần CI.

- [ ] **Step 1: Viết test đỏ trước**

`modules/auth/internal/service/role_ma_test.go`:

```go
package service

import "testing"

// File nay o package `service` chu khong `service_test`: ba ham duoi day khong xuat khau, va
// chung khong duoc xuat khau - chung la chi tiet cua mot method public da co test rieng. Cung
// khuon voi user_service_internal_test.go.
//
// Ca file KHONG cham database, nen no chay duoc duoi may Windows bang `go test -run`.

// TestBoDauTiengViet_HaiBangCungSoRune la bai RE nhat va DAT nhat trong file.
//
// Hai hang song song la mot khuon de sai theo kieu im lang: them mot ky tu vao bang co dau ma
// quen bang khong dau se lam moi rune SAU vi tri do dich di mot cho, tuc "ơ" thanh "u". Bai nay
// bat dieu do ngay o dong dau tien cua bo test thay vi o mot ma vai tro sai tren production.
func TestBoDauTiengViet_HaiBangCungSoRune(t *testing.T) {
	co := []rune(nguyenAmCoDau)
	khong := []rune(nguyenAmKhongDau)
	if len(co) != len(khong) {
		t.Fatalf("nguyenAmCoDau co %d rune, nguyenAmKhongDau co %d - hai bang phai song song tung rune", len(co), len(khong))
	}
}

// TestBoDauTiengViet_MoiNguyenAmDeuVeDungChuCai duyet TOAN BO bang, khong lay mau.
//
// Lay mau vai chu se bo lot dung mot dong chep sai o giua bang - thu duy nhat co the sai o day.
func TestBoDauTiengViet_MoiNguyenAmDeuVeDungChuCai(t *testing.T) {
	co := []rune(nguyenAmCoDau)
	khong := []rune(nguyenAmKhongDau)
	for i, r := range co {
		if got := boDauTiengViet(string(r)); got != string(khong[i]) {
			t.Errorf("boDauTiengViet(%q) = %q, muon %q", string(r), got, string(khong[i]))
		}
	}
}

// TestSinhMaVaiTro chot dung khuon ma spec muc 6.4 dat ra: <phan_he>.<slug khong dau>.
func TestSinhMaVaiTro(t *testing.T) {
	ca := []struct {
		ten    string
		phanHe string
		nhan   string
		muon   string
	}{
		{"vi du cua spec", "inventory", "Thủ kho ca đêm", "inventory.thu_kho_ca_dem"},
		{"chu D gach ngang", "auth", "Điều độ viên", "auth.dieu_do_vien"},
		{"chu hoa va khoang trang thua", "machine", "  KỸ  THUẬT viên  ", "machine.ky_thuat_vien"},
		{"ky tu la bi bo", "inventory", "Kế toán (kho) #2", "inventory.ke_toan_kho_2"},
		{"gach ngang thanh gach duoi", "inventory", "Thủ kho - ca 2", "inventory.thu_kho_ca_2"},
		{"ten khong con ky tu nao dung duoc", "inventory", "!!!", "inventory.vai_tro"},
	}
	for _, c := range ca {
		t.Run(c.ten, func(t *testing.T) {
			if got := sinhMaVaiTro(c.phanHe, c.nhan); got != c.muon {
				t.Errorf("sinhMaVaiTro(%q, %q) = %q, muon %q", c.phanHe, c.nhan, got, c.muon)
			}
		})
	}
}

// TestSinhMaVaiTro_CatDoDaiOMucAnToan chot rang mot cai ten dai khong lam vo cau chen.
//
// roles.code la TEXT nen database khong chan gi, nhung mot ma dai vai tram ky tu di vao claim
// `roles` cua token se lam token phinh ra - va no la thu khong ai do cho toi luc mot header
// vuot han muc cua reverse proxy.
func TestSinhMaVaiTro_CatDoDaiOMucAnToan(t *testing.T) {
	ten := ""
	for i := 0; i < 200; i++ {
		ten += "a"
	}
	ma := sinhMaVaiTro("inventory", ten)
	if len(ma) > len("inventory.")+doDaiToiDaSlug {
		t.Errorf("ma dai %d ky tu, tran la %d", len(ma), len("inventory.")+doDaiToiDaSlug)
	}
}
```

- [ ] **Step 2: Chạy cho thấy đỏ**

```bash
go test ./modules/auth/internal/service/ -run 'TestBoDauTiengViet|TestSinhMaVaiTro'
```

Expected: lỗi biên dịch — bốn định danh chưa tồn tại.

- [ ] **Step 3: Viết ba hàm**

Thêm vào `role_service.go`:

```go
// --- Sinh ma vai tro (spec muc 6.4) ---

// nguyenAmCoDau va nguyenAmKhongDau la HAI BANG SONG SONG tung rune: rune thu i cua bang tren
// doi thanh rune thu i cua bang duoi.
//
// # Vi sao viet tay chu khong dung golang.org/x/text
//
// `golang.org/x/text` dang la mot phu thuoc GIAN TIEP cua repo (go.mod). Import no truc tiep se
// keo no len khoi require truc tiep - mot phu thuoc moi cua ca he thong - de doi lay mot phep
// chuan hoa NFD cong mot bo loc dau thanh. Bang duoi day dai hon nhung no khong them mot dong
// nao vao go.mod, va no la TAT DINH: khong phu thuoc phien ban bang Unicode cua thu vien.
//
// Bang chi chua CHU THUONG. Nguoi goi ha chu ve thuong TRUOC khi tra, nen "Ế" di qua strings.
// ToLower thanh "ế" roi moi toi day. Chep ca hai bang hoa vao day se lam moi lan them mot rune
// phai sua bon cho thay vi hai.
//
// `đ` nam o cuoi bang, sau nam rune cua `y`: no khong phai mot nguyen am, nhung no la ky tu
// tieng Viet duy nhat con lai can doi - va gop no vao day re hon mot nhanh `if` rieng.
//
// TestBoDauTiengViet_HaiBangCungSoRune canh bat bien "cung so rune". Mot rune them vao bang tren
// ma quen bang duoi lam MOI rune sau vi tri do dich di mot cho - mot loi khong lam vo build va
// chi lo ra o mot ma vai tro sai.
const (
	nguyenAmCoDau    = "àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ"
	nguyenAmKhongDau = "aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooooouuuuuuuuuuuyyyyyd"
)

// bangBoDau la hai hang tren o dang map, dung mot lan cho ca tien trinh.
//
// Bien cap package chu khong dung mot ham dung lai map moi lan goi: sinh ma chay mot lan cho
// moi POST /roles, nhung mot map 67 phan tu dung lai cho tung lan goi la mot phep phi pham
// khong doi lai duoc gi. Map nay CHI DOC sau khi init, nen no dung duoc dong thoi tu moi
// goroutine phuc vu request ma khong can khoa - cung bat bien ma rbacChecker.quyen giu.
var bangBoDau = func() map[rune]rune {
	co := []rune(nguyenAmCoDau)
	khong := []rune(nguyenAmKhongDau)
	m := make(map[rune]rune, len(co))
	for i, r := range co {
		// Khong panic khi hai bang lech: mot ham dung bo gia tri khoi tao khong phai cho de lam
		// ca tien trinh khong len duoc. TestBoDauTiengViet_HaiBangCungSoRune bat cho lech do.
		if i >= len(khong) {
			break
		}
		m[r] = khong[i]
	}
	return m
}()

// boDauTiengViet doi moi ky tu tieng Viet co dau thanh chu cai ASCII tuong ung.
//
// Ky tu khong co trong bang di qua NGUYEN TRANG - ke ca chu hoa, ke ca ky tu la. Viec loai bo
// chung la cua slugKhongDau, khong phai cua ham nay: mot ham lam hai viec thi khong test rieng
// duoc viec nao.
func boDauTiengViet(s string) string {
	return strings.Map(func(r rune) rune {
		if thay, co := bangBoDau[r]; co {
			return thay
		}
		return r
	}, s)
}

// doDaiToiDaSlug la tran do dai cua phan sau dau cham trong mot ma vai tro.
//
// 48 chu khong phai mot con so tron: `roles.code` la TEXT nen database khong chan gi, nhung ma
// vai tro di vao claim `roles` cua token, va mot nguoi mang nam vai tro voi ten dai vai tram ky
// tu se lam header Authorization phinh vuot han muc cua reverse proxy - mot loi khong ai do cho
// toi luc no xay ra. 48 du cho moi ten vai tro co that va giu tong do dai mot ma duoi 60 ky tu.
const doDaiToiDaSlug = 48

// slugKhongDau doi mot cai ten nguoi go thanh phan sau dau cham cua mot ma vai tro.
//
// Bon buoc, dung thu tu nay: ha chu thuong -> bo dau -> doi moi ky tu khong phai [a-z0-9] thanh
// gach duoi -> gop gach duoi lien tiep va cat hai dau.
//
// Ha chu thuong TRUOC khi bo dau la bat buoc: bangBoDau chi chua chu thuong, nen "Ế" phai thanh
// "ế" truoc khi no tim thay duong ve "e".
//
// Chuoi khong con ky tu nao dung duoc - vi du "!!!" - cho ra chuoi rong, va nguoi goi thay no
// bang mot hang. Tra ve chuoi rong o day chu khong tu vá: mot ham sinh slug tu dat ra mot cai
// ten thay the la mot ham hai viec.
func slugKhongDau(ten string) string {
	tho := boDauTiengViet(strings.ToLower(strings.TrimSpace(ten)))

	var b strings.Builder
	b.Grow(len(tho))
	for _, r := range tho {
		switch {
		case r >= 'a' && r <= 'z', r >= '0' && r <= '9':
			b.WriteRune(r)
		default:
			b.WriteByte('_')
		}
	}

	// Gop gach duoi lien tiep roi cat hai dau: "ke_toan__kho_" khong phai mot ma ai doc ra duoc,
	// va no khac "ke_toan_kho" o mot cho khong ai nhin thay.
	ra := b.String()
	for strings.Contains(ra, "__") {
		ra = strings.ReplaceAll(ra, "__", "_")
	}
	ra = strings.Trim(ra, "_")

	if len(ra) > doDaiToiDaSlug {
		// Cat theo BYTE an toan o day vi chuoi da chi con [a-z0-9_] - moi ky tu mot byte - nen
		// khong co rune nao bi cat doi. Cat truoc khi Trim lan hai: lat cat co the roi dung vao
		// mot gach duoi.
		ra = strings.Trim(ra[:doDaiToiDaSlug], "_")
	}
	return ra
}

// maVaiTroMacDinh la phan slug dung khi cai ten nguoi go khong con ky tu nao dung duoc.
//
// Mot hang chu khong mot loi 422: cai ten "!!!" la mot cai ten HOP LE - `name` khong co rang
// buoc ky tu nao - va tu choi no se la mot luat nghiep vu khong ai khai o dau. Ma sinh ra khi do
// la `inventory.vai_tro`, va lan thu hai se la `inventory.vai_tro_2` nho phep them hau to.
const maVaiTroMacDinh = "vai_tro"

// sinhMaVaiTro ghep phan he va ten thanh mot ma vai tro.
//
// # Ma do BACKEND sinh, khong nhan tu client (spec muc 6.4)
//
// Frontend van hien mot ma XEM TRUOC canh o Ten, kem cau noi ro ma cuoi cung do he thong chot -
// nhung no khong gui ma len, va backend khong doc mot truong `code` nao. R-19: frontend khong
// giu quy tac nghiep vu.
//
// # `phanHe` o day KHONG phai nguon su that ve module cua vai tro
//
// No la mot quy uoc DAT TEN, khong hon (rang buoc 3). Module cua mot vai tro suy tu
// role_permissions, va khong phep kiem quyen nao doc tien to nay - ADR-0024 cam tuyet doi dieu
// do. Mot admin dat phan he "inventory" roi tick toan quyen `auth.*` van bi kiemGhiTapQuyen tu
// choi, va cai ma `inventory.xxx` khong giup gi cho ho.
//
// Phep them hau to `_2`, `_3` KHONG o day: no doi mot lan hoi database, va ham nay la ham thuan
// de test duoc mot minh. Xem RoleService.sinhMaChuaDung.
func sinhMaVaiTro(phanHe, ten string) string {
	slug := slugKhongDau(ten)
	if slug == "" {
		slug = maVaiTroMacDinh
	}
	return phanHe + "." + slug
}
```

- [ ] **Step 4: Chạy cho thấy xanh, rồi commit**

```bash
go test ./modules/auth/internal/service/ -run 'TestBoDauTiengViet|TestSinhMaVaiTro' -v
go run ./cmd/dev lint
```

```bash
git add modules/auth/internal/service/role_ma_test.go modules/auth/internal/service/role_service.go
git commit -m "feat(auth): sinh ma vai tro tu phan he va ten

Bảng bỏ dấu viết tay thay vì kéo golang.org/x/text từ indirect lên direct — nó
tất định và không thêm một dòng nào vào go.mod. `phanHe` ở đây chỉ là quy ước
đặt tên, không phải nguồn sự thật về module (ADR-0024)."
```

---

## Task 15: `kiemGhiTapQuyen` — ba ràng buộc trong một hàm

**Files:**
- Modify: `backend-erp/modules/auth/internal/service/role_service.go`
- Test: `backend-erp/modules/auth/internal/service/role_service_test.go`

Đây là hàm gác của cả hai đường ghi. Nó áp **ràng buộc 7** (mã quyền có thật không), **ràng buộc 1** (loại trừ tập tự tác động trước khi gom), và **ràng buộc 2** (kiểm trên hiệu đối xứng, không trên tập gửi lên).

- [ ] **Step 1: Viết test đỏ trước**

```go
// TestKiemGhiTapQuyen_MaKhongCoThatTra422 chot rang buoc 7: permission_code la TEXT tran duoi
// database - khong khoa ngoai, khong CHECK (ADR-0023 muc 2) - nen phep kiem "ma nay co that
// khong" nam o tang service, doi chieu voi danh muc hang tiem tu composition root.
//
// Do qua TaoVaiTro chu khong goi thang ham noi bo: thu can chot la HANH VI cua endpoint, va
// mot bai goi thang ham se van xanh vao ngay ai do quen goi no o mot trong hai duong ghi.
func TestKiemGhiTapQuyen_MaKhongCoThatTra422(t *testing.T) {
	svc := dungRoleService(&roleRepoGia{})

	_, err := svc.TaoVaiTro(context.Background(), actorQuanTri("cong-ty"), service.TaoVaiTroInput{
		Ten: "Ke toan kho", PhanHe: "kho", Quyen: []string{"kho.khong_co_ma_nay"},
	})
	kiemMaLoi(t, err, apperr.CodeAuthRolePermissionUnknown, "permissions")
}

// TestKiemGhiTapQuyen_MaNgoaiTamActorTra422 chot rang buoc 2 o chieu CAP THEM.
//
// actorChiGanKho giu `kho.role_assign` va KHONG giu `banhang.role_assign`. Tick mot ma cua
// module banhang phai bi tu choi - do la dung ca ma ADR-0024 muc 2 dung ra de chan: mot quan tri
// module nay che ra mot vai tro mang quyen cua module kia.
//
// 422 chu khong 403: actor CO quyen goi endpoint - ho da qua auth.role_create o cau lenh dau -
// va thu bi tu choi la mot gia tri trong than request.
func TestKiemGhiTapQuyen_MaNgoaiTamActorTra422(t *testing.T) {
	svc := dungRoleService(&roleRepoGia{})

	_, err := svc.TaoVaiTro(context.Background(), actorChiGanKhoDatDuocVaiTro("cong-ty"), service.TaoVaiTroInput{
		Ten: "Ke toan", PhanHe: "kho", Quyen: []string{permVanHanhBanHang},
	})
	kiemMaLoi(t, err, apperr.CodeAuthRolePermissionForbidden, "permissions")
}

// TestKiemGhiTapQuyen_SanChungKhongKeoTheoCuaModuleAuth chot rang buoc 1 tren duong GHI.
//
// ADR-0028 muc 5 noi thang: phep loai tru ap cho ca duong ghi tap quyen - neu khong, mot
// `inventory.admin` se tick duoc `inventory.item_create` nhung KHONG tick duoc `auth.self_read`,
// mot su bat doi xung khong ai giai thich duoc.
//
// Doi chung HEP nam o bai ngay duoi: mot ma auth THAT SU tac dong len nguoi khac van bi chan.
// Thieu doi chung do, mot cai dat loc theo tien to "bo moi ma auth.* khoi phep gom" van xanh -
// dung phuong an ADR-0028 muc Alternatives da loai.
func TestKiemGhiTapQuyen_SanChungKhongKeoTheoCuaModuleAuth(t *testing.T) {
	svc := dungRoleService(&roleRepoGia{})

	_, err := svc.TaoVaiTro(context.Background(), actorChiGanKhoDatDuocVaiTro("cong-ty"), service.TaoVaiTroInput{
		Ten: "Thu kho ca dem", PhanHe: "kho",
		Quyen: []string{permVanHanhKho, service.PermAuthSelfRead},
	})
	if err != nil {
		t.Fatalf("tick san chung bi tu choi: %v - ADR-0028 muc 5 chot rang phep loai tru ap cho ca duong ghi", err)
	}
}

// TestKiemGhiTapQuyen_TinhTrenHIEU_DOI_XUNG la bai dat nhat cua ca dot.
//
// Kiem tren TAP GUI LEN la mot lo hong cho phep GO quyen cua module minh khong co tham quyen:
// mot vai tro dang mang `banhang.don_ban`, actor chi giu cua module kho gui len mot tap KHONG
// con ma do - thi `banhang.don_ban` bi GO ma khong xuat hien o bat cu dau trong than request.
//
// Bai nay dung chinh hinh dang do: tap moi chi chua ma cua module kho, tuc mot cai dat kiem
// tren tap gui len se CHO QUA. Duong dung tinh hieu doi xung giua tap cu doc tu DATABASE va tap
// moi, nen no thay `banhang.don_ban` o phia GO BO va tu choi.
func TestKiemGhiTapQuyen_TinhTrenHieuDoiXung(t *testing.T) {
	repo := &roleRepoGia{
		dongTheoID: repository.DongDanhMucVaiTro{
			ID: idVaiTroTest, Ma: "kho.ke_toan", Nhan: "Ke toan",
		},
		quyenTheoID: []string{permVanHanhKho, permVanHanhBanHang},
	}
	svc := dungRoleService(repo)

	moi := []string{permVanHanhKho}
	_, err := svc.SuaVaiTro(context.Background(), actorChiGanKhoDatDuocVaiTro("cong-ty"), idVaiTroTest,
		service.SuaVaiTroInput{Quyen: &moi})

	kiemMaLoi(t, err, apperr.CodeAuthRolePermissionForbidden, "permissions")
	if repo.soLanThemQuyen != 0 || repo.soLanGoQuyen != 0 {
		t.Error("da cham duong ghi truoc khi phep kiem xong - mot lan GO quyen cua module khong phai cua minh vua di qua")
	}
}
```

Kèm hai helper trong cùng file:

```go
// kiemMaLoi khang dinh mot loi mang dung MA va tro dung O.
//
// Kiem ca hai chu khong chi ma: mot 422 mang ten o SAI con te hon mot 422 khong mang o nao - form
// se to mot o khong lien quan va nguoi dung sua nham cho.
func kiemMaLoi(t *testing.T, err error, ma, o string) {
	t.Helper()
	if err == nil {
		t.Fatalf("muon loi %s, nhan nil", ma)
	}
	var ae *apperr.Error
	if !errors.As(err, &ae) {
		t.Fatalf("loi khong phai *apperr.Error: %v", err)
	}
	if ae.Code != ma {
		t.Fatalf("Code = %q, muon %q (thong diep: %s)", ae.Code, ma, ae.Message)
	}
	coO := false
	for _, f := range ae.Fields {
		if f.Name == o {
			coO = true
		}
	}
	if !coO {
		t.Errorf("loi khong tro vao o %q; fields = %+v", o, ae.Fields)
	}
}

// actorChiGanKhoDatDuocVaiTro la actorChiGanKho CONG hai ma cua dot 2b.
//
// Mot actor role rieng chu khong sua vaiTroChiGanKho san co: bai o
// user_service_danhmuc_test.go dua vao viec vai tro do KHONG dat ra duoc vai tro, va them hai
// ma vao no se lam nhung bai kia do vi mot ly do khong lien quan.
func actorChiGanKhoDatDuocVaiTro(congTyID string) auth.Actor {
	return auth.Actor{UserID: uuid.NewString(), CompanyID: congTyID, Roles: []string{vaiTroDatVaiTroKho}}
}
```

và ba hằng mới trong `role_service_test.go`:

```go
const (
	// vaiTroDatVaiTroKho giu cua vao cua dot 2b CONG cua cua module kho, KHONG giu cua cua
	// module banhang. Do la hinh dang cua mot admin phan vung co that trong bai toan nay.
	vaiTroDatVaiTroKho = "dat_vai_tro_kho"

	idVaiTroTest = "33333333-3333-4333-8333-333333333333"
)
```

Bảng `bangQuyenUser()` ở `user_service_test.go` thêm một hàng:

```go
		vaiTroDatVaiTroKho: {
			service.PermRoleCreate,
			service.PermRoleUpdate,
			permGanKho,
			permVanHanhKho,
			service.PermAuthSelfRead,
			service.PermAuthChangePassword,
		},
```

và `roleRepoGia` thêm bốn field ghi lại: `dongTheoID repository.DongDanhMucVaiTro`, `quyenTheoID []string`, `soLanThemQuyen int`, `soLanGoQuyen int`, với `TheoID`/`QuyenTheoVaiTroID`/`ThemQuyen`/`GoQuyen` trả và đếm theo chúng thay vì trả rỗng như ở Task 13 Step 5.

- [ ] **Step 2: Chạy cho thấy đỏ**

```bash
go test ./modules/auth/internal/service/ -run 'TestKiemGhiTapQuyen'
```

Expected: lỗi biên dịch — `TaoVaiTro`, `SuaVaiTro`, `TaoVaiTroInput`, `SuaVaiTroInput` chưa tồn tại.

- [ ] **Step 3: Viết `kiemGhiTapQuyen` và hai hàm phụ**

Thêm vào `role_service.go`:

```go
// kiemGhiTapQuyen gac MOT lan ghi tap quyen cua mot vai tro, va no gac ba ve theo dung thu tu
// nay: ma co that khong -> bo tap tu tac dong -> actor co cua cua moi module con lai khong.
//
// # Ve MOT: ma co that khong (rang buoc 7, ADR-0023 muc 7)
//
// permission_code la TEXT tran duoi database: khong khoa ngoai, khong CHECK liet ke. Tap ma
// quyen song trong code va dai ra theo tung module moi, nen mot bang dich hay mot CHECK o
// database se bat moi module sau phai kem mot migration - dung dieu C-DB-02 loai bo ENUM de
// tranh. Phep kiem vi vay nam O DAY, doi chieu voi danh muc hang tiem tu composition root.
//
// Chay ve nay TRUOC hai ve kia la bat buoc, khong phai thu tu tuy y: ve ba cat tien to cua tung
// ma de lay ten module, va ADR-0024 muc 1 chi cho phep cat tien to cua mot chuoi DA DUOC DOI
// CHIEU voi danh muc. Dao thu tu la mo lai dung lo hong ma ADR-0024 dung ra de bit.
//
// # Ve HAI: bo tap tu tac dong (rang buoc 1, ADR-0028 muc 5)
//
// Bo TRUOC khi gom module, khong loc sau - mot module lot vao tap roi thi khong con biet no vao
// nho ma nao. Khong co ve nay thi mot `inventory.admin` tick duoc `inventory.item_create` nhung
// khong tick duoc `auth.self_read`, mot su bat doi xung khong ai giai thich duoc.
//
// Phep bo di qua moduleCuaTapQuyen - DUNG mot ham voi phep gom cua kiemGanMotVaiTro va cua cot
// `phan_he` tren `GET /roles`. Ba nguoi doc, mot phep tinh.
//
// # Ve BA: cua cua tung module (rang buoc 2, ADR-0024 muc 2)
//
// Nguoi goi truyen vao HIEU DOI XUNG giua tap cu doc tu database va tap moi gui len, khong
// truyen tap gui len. Xem ghi chu cua TaoVaiTro va SuaVaiTro ve ly do.
//
// Thong diep tu choi goi ten MODULE dang thieu, khong goi ten permission: tap ten module la
// thong tin cong khai cua he - no nam ngay trong tien to cua moi ma vai tro hien tren chinh man
// hinh do - con ten mot permission la thong tin ve hinh dang he thong.
func (s *RoleService) kiemGhiTapQuyen(ctx context.Context, actor auth.Actor, doiXung []string) error {
	if err := s.kiemMaQuyenCoThat(doiXung); err != nil {
		return err
	}
	for _, m := range moduleCuaTapQuyen(doiXung, s.quyenTuTacDong) {
		if err := s.authz.Can(ctx, actor, m+"."+permRoleAssignHauTo); err != nil {
			return apperr.ValidationFailedFields(apperr.CodeAuthRolePermissionForbidden,
				msgMaQuyenNgoaiTamActor+m,
				apperr.Field{Name: fieldQuyen, Message: msgMaQuyenNgoaiTamActor + m})
		}
	}
	return nil
}

// kiemMaQuyenCoThat doi chieu tung ma voi danh muc hang.
//
// Dung o ma SAI DAU TIEN va noi ten no ra. Ten ma o day KHONG phai du lieu client tu bia: no
// vua bi doi chieu voi danh muc va bi tu choi vi khong co trong do, nen nhac lai no la nhac lai
// mot chuoi client da biet - khac han cac thong diep HANG cua kiemGanMotVaiTro, noi ten vai tro
// la mot chuoi tu do do quan tri go.
//
// Danh muc RONG cho ra "moi ma deu sai", va do la chieu fail-CLOSE dung: mot composition root
// quen tiem danh muc thi khong vai tro nao tao duoc voi mot o tick nao, va trieu chung lo ra o
// request dau tien.
func (s *RoleService) kiemMaQuyenCoThat(quyen []string) error {
	for _, p := range quyen {
		if _, co := s.coMaQuyen[p]; !co {
			return apperr.ValidationFailedFields(apperr.CodeAuthRolePermissionUnknown,
				msgMaQuyenKhongCoThat+p,
				apperr.Field{Name: fieldQuyen, Message: msgMaQuyenKhongCoThat + p})
		}
	}
	return nil
}

// Ba nua dau HANG cua thong diep tu choi. Nua sau - ten ma quyen hoac ten module - la thu duy
// nhat doi theo tung lan.
const (
	msgMaQuyenKhongCoThat   = "ma quyen khong ton tai: "
	msgMaQuyenNgoaiTamActor = "khong du quyen cap ma quyen cua module "
)

// Ten cac o cua than request, viet theo ten CLIENT gui len chu khong theo ten field Go.
//
// Khai thanh hang thay vi go chuoi thang vao tung loi goi vi mot 422 mang ten o SAI con te hon
// mot 422 khong mang ten o nao: form se to mot o khong lien quan va nguoi dung sua nham cho.
// Nguon cua bon chuoi la tag json cua TaoVaiTroRequest/SuaVaiTroRequest o
// modules/auth/internal/handler/role_handler.go.
const (
	fieldTenVaiTro = "name"
	fieldQuyen     = "permissions"
	fieldDangDung  = "dang_dung"
	fieldMaVaiTro  = "code"
)
```

- [ ] **Step 4: Chạy — vẫn đỏ, và đỏ đúng chỗ**

`TaoVaiTro`/`SuaVaiTro` chưa có, nên bốn bài vẫn không biên dịch được. Đó là đỏ **mong đợi**: hai task sau chữa. Không viết vội hai method ở đây.

- [ ] **Step 5: Commit phần đã xong**

```bash
go build ./modules/auth/internal/service/
git add modules/auth/internal/service/role_service.go
git commit -m "feat(auth): kiemGhiTapQuyen gac ba rang buoc cua duong ghi tap quyen

Mã có thật (ràng buộc 7) chạy TRƯỚC phép cắt tiền tố, vì ADR-0024 mục 1 chỉ cho
cắt tiền tố của một chuỗi đã đối chiếu với danh mục. Phép gom module dùng chung
moduleCuaTapQuyen với đường gán — ba người đọc, một phép tính."
```

---

## Task 16: `POST /roles` ở tầng service

**Files:**
- Modify: `backend-erp/modules/auth/internal/service/role_service.go`
- Test: `backend-erp/modules/auth/internal/service/role_service_test.go`, `role_service_db_test.go`

- [ ] **Step 1: Viết test đỏ trước — bốn bài không chạm database**

```go
// TestTaoVaiTro_ThieuQuyenTra403 chot cua chan cua R-15 tren duong TAO.
//
// Cua nay la auth.role_create MOT MINH, khac DanhMucQuyen (HOAC): mot actor chi sua duoc vai tro
// khong duoc dat ra vai tro moi.
//
// Khang dinh thu hai - repository khong duoc goi lan nao - la phan R-15 that su doi: mot lan
// ghi chay truoc phep kiem quyen van cho ra 403 o response, nhung no da cham database nhan danh
// mot nguoi khong duoc phep.
func TestTaoVaiTro_ThieuQuyenTra403(t *testing.T) {
	repo := &roleRepoGia{}
	svc := dungRoleService(repo)

	_, err := svc.TaoVaiTro(context.Background(), actorChiGanKho("cong-ty"), service.TaoVaiTroInput{
		Ten: "Ke toan", PhanHe: "kho",
	})
	kiemTuChoiQuyen(t, err)
	if repo.soLanMaDaDung != 0 || repo.soLanTao != 0 {
		t.Error("da cham database truoc phep kiem quyen")
	}
}

// TestTaoVaiTro_TapQuyenRongLaHopLe chot mot ca de tuong la loi.
//
// Quan tri tao mot vai tro roi chua tick gi la thao tac binh thuong. Vai tro do khong cap quyen
// nao nen phep gom module cho ra tap rong, va vong kiem cua ve ba chay khong lan nao - do la ket
// qua DUNG chu khong mot cho lot.
func TestTaoVaiTro_TapQuyenRongLaHopLe(t *testing.T) {
	svc := dungRoleService(&roleRepoGia{})

	ra, err := svc.TaoVaiTro(context.Background(), actorChiGanKhoDatDuocVaiTro("cong-ty"), service.TaoVaiTroInput{
		Ten: "Chua tick gi", PhanHe: "kho",
	})
	if err != nil {
		t.Fatalf("tao vai tro voi tap quyen rong bi tu choi: %v", err)
	}
	if ra.HeThongTao {
		t.Error("vai tro do quan tri tao mang he_thong_tao = true - duong nay luon dat false (spec muc 6.4)")
	}
	if ra.PhanHe == nil {
		t.Error("PhanHe = nil - no se tuan tu hoa thanh \"phan_he\": null thay vi []")
	}
}

// TestTaoVaiTro_SinhMaVaThemHauToKhiTrung chot ca hai nua cua muc 6.4.
//
// repo gia noi CO cho hai ma dau roi noi KHONG cho ma thu ba, tuc dung hinh dang ma mot phan
// vung da co `inventory.thu_kho` va `inventory.thu_kho_2` se cho ra.
func TestTaoVaiTro_SinhMaVaThemHauToKhiTrung(t *testing.T) {
	repo := &roleRepoGia{maDaDung: map[string]bool{
		"inventory.thu_kho":   true,
		"inventory.thu_kho_2": true,
	}}
	svc := dungRoleService(repo)

	ra, err := svc.TaoVaiTro(context.Background(), actorQuanTri("cong-ty"), service.TaoVaiTroInput{
		Ten: "Thủ kho", PhanHe: "inventory",
	})
	if err != nil {
		t.Fatalf("TaoVaiTro: %v", err)
	}
	if ra.Ma != "inventory.thu_kho_3" {
		t.Errorf("ma = %q, muon inventory.thu_kho_3", ra.Ma)
	}
}

// TestTaoVaiTro_TraTrangThaiSauKhiGhi chot rang response mang du thu man hinh can ve lai ngay.
func TestTaoVaiTro_TraTrangThaiSauKhiGhi(t *testing.T) {
	svc := dungRoleService(&roleRepoGia{})

	ra, err := svc.TaoVaiTro(context.Background(), actorChiGanKhoDatDuocVaiTro("cong-ty"), service.TaoVaiTroInput{
		Ten: "Thủ kho ca đêm", MoTa: "Ca 22h-6h", PhanHe: "kho", Quyen: []string{permVanHanhKho},
	})
	if err != nil {
		t.Fatalf("TaoVaiTro: %v", err)
	}
	if ra.Nhan != "Thủ kho ca đêm" || ra.MoTa != "Ca 22h-6h" || !ra.DangDung {
		t.Errorf("trang thai tra ve sai: %+v", ra)
	}
	if len(ra.PhanHe) != 1 || ra.PhanHe[0] != "kho" {
		t.Errorf("PhanHe = %v, muon [kho]", ra.PhanHe)
	}
	if ra.SoNguoiGiu != 0 {
		t.Errorf("so_nguoi_giu = %d, muon 0 - vai tro vua tao chua ai giu", ra.SoNguoiGiu)
	}
}
```

- [ ] **Step 2: Chạy cho thấy đỏ**

```bash
go test ./modules/auth/internal/service/ -run 'TestTaoVaiTro|TestKiemGhiTapQuyen'
```

- [ ] **Step 3: Viết `TaoVaiTro`**

```go
// TaoVaiTroInput la dau vao cua TaoVaiTro.
//
// KHONG co truong Ma. Ma do backend sinh, khong nhan tu client (spec muc 6.4) - va khong co
// truong thi khong co duong nhan, tuc bat bien do la mot loi bien dich chu khong mot phep kiem
// ai do quen goi.
//
// PhanHe la quy uoc DAT TEN de sinh ma, KHONG phai nguon su that ve module cua vai tro (rang
// buoc 3). Xem ghi chu cua sinhMaVaiTro.
type TaoVaiTroInput struct {
	Ten    string
	MoTa   string
	PhanHe string
	Quyen  []string
}

// VaiTroChiTiet la trang thai cua MOT vai tro sau mot lan ghi, du de man hinh ve lai ngay ma
// khong phai goi them mot `GET /roles`.
//
// Cung chin truong voi mot dong cua `GET /roles`, cong tap quyen: man Sua mo ra tu response nay
// phai tick lai duoc dung nhung o vua luu.
type VaiTroChiTiet struct {
	ID         string
	Ma         string
	Nhan       string
	MoTa       string
	DangDung   bool
	HeThongTao bool
	PhanHe     []string
	NhanPhanHe []string
	SoNguoiGiu int64
	Quyen      []string
}

// TaoVaiTro dat ra MOT vai tro moi trong phan vung cua actor (spec muc 6.4).
//
// # Thu tu SAU BUOC, va thu tu do la hop dong
//
// authz.Can -> ma quyen co that -> bo tap tu tac dong -> cua cua tung module -> sinh ma ->
// transaction (roles + role_permissions + audit_logs) -> commit. Bon buoc dau chay NGOAI
// transaction, dung khuon C-GO-06 va P-TXN: chuan bi va kiem truoc BEGIN, transaction chi con
// lai phan ghi that su.
//
// # Hieu doi xung o day la CHINH tap gui len, va do khong phai mot ngoai le
//
// Tap cu cua mot vai tro CHUA TON TAI la tap rong, nen hieu doi xung giua rong va tap moi dung
// bang tap moi. Goi hieuDoiXungVaiTro voi mot tap rong chu khong truyen thang `in.Quyen`: hai
// duong ghi khi do chay CUNG mot phep tinh, va ngay ai do doi luat thi khong con mot duong nao
// bo lo. Ten ham noi "vai tro" vi nguoi doc dau tien cua no la duong gan, nhung than no la mot
// phep hieu tap thuan tren chuoi - xem ghi chu cua no.
//
// # is_system luon false
//
// Duong nay khong co truong nao nhan gia tri do, va TaoVaiTroRow cung khong (spec muc 6.4).
// Vai tro he thong chi sinh ra tu bo mac dinh, tuc tu CreateCompany va tu `cmd/dev seed-roles`.
func (s *RoleService) TaoVaiTro(ctx context.Context, actor auth.Actor, in TaoVaiTroInput) (*VaiTroChiTiet, error) {
	if err := s.authz.Can(ctx, actor, PermRoleCreate); err != nil {
		return nil, err
	}

	them, goBo := hieuDoiXungVaiTro(nil, in.Quyen)
	if err := s.kiemGhiTapQuyen(ctx, actor, append(them, goBo...)); err != nil {
		return nil, err
	}

	ma, err := s.sinhMaChuaDung(ctx, actor.CompanyID, in.PhanHe, in.Ten)
	if err != nil {
		return nil, err
	}

	tx, err := s.db.BeginTxx(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("begin tx tao vai tro %s: %w", ma, err)
	}
	defer tx.Rollback()

	id, err := s.roleRepo.Tao(ctx, tx, actor.CompanyID, actor.UserID, repository.TaoVaiTroRow{
		Ma: ma, Nhan: in.Ten, MoTa: in.MoTa,
	})
	if err != nil {
		return nil, dichLoiGhiVaiTro(err)
	}
	if err := s.roleRepo.ThemQuyen(ctx, tx, actor.CompanyID, actor.UserID, id, in.Quyen); err != nil {
		return nil, dichLoiGhiVaiTro(err)
	}
	if err := s.ghiAudit(ctx, tx, actor, actionRoleCreated, id); err != nil {
		return nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("commit tx tao vai tro %s: %w", ma, err)
	}

	// Dung trang thai tra ve tu thu VUA GHI chu khong doc lai mot lan nua: mot cau SELECT o day
	// chay NGOAI transaction vua commit va co the ta mot trang thai khac voi trang thai chinh
	// method nay vua tao ra. so_nguoi_giu la 0 theo dinh nghia - vai tro vua sinh chua ai giu.
	mods := moduleCuaTapQuyen(in.Quyen, s.quyenTuTacDong)
	return &VaiTroChiTiet{
		ID: id, Ma: ma, Nhan: in.Ten, MoTa: in.MoTa,
		DangDung: true, HeThongTao: false,
		PhanHe:     mods,
		NhanPhanHe: nhanCuaModule(mods, s.nhanPhanHe),
		SoNguoiGiu: 0,
		Quyen:      in.Quyen,
	}, nil
}

// soLanThuHauTo la so lan toi da thu them hau to `_2`, `_3`, ... truoc khi bo cuoc.
//
// 50 chu khong phai mot vong lap vo han: neu mot phan vung that su co 50 vai tro cung slug thi
// thu dang xay ra khong phai mot cai ten trung ma la mot vong lap goi API, va mot vong lap
// khong tran o day se giu ket noi database mo cho toi khi ai do nhan ra.
const soLanThuHauTo = 50

// sinhMaChuaDung sinh ma tu phan he va ten, roi them hau to `_2`, `_3`, ... cho toi khi gap mot
// ma chua ai dung (spec muc 6.4).
//
// Phep tra hoi BAT KE deleted_at (rang buoc 6, ADR-0027 muc 3): uq_roles_company_id_code la
// partial index nen mot ma song nam canh mot ma bia mo la hop le voi database, va mot ma trung
// voi mot vai tro DA XOA lam lich su audit_logs cua hai vai tro tron lam mot - cot do ghi MA
// chu khong ghi id.
//
// Phep tra nay chay NGOAI transaction va vi vay co mot KHE giua lan tra va lan chen: hai request
// song song co the cung thay mot ma con trong. Khe do duoc bit o tang duoi bang chinh unique
// index, va dichLoiGhiVaiTro doi 23505 thanh ERR_AUTH_ROLE_CODE_DUPLICATED - mot 409 that thay
// vi mot 500. Dua phep tra vao trong transaction khong dong khe nay lai: hai transaction READ
// COMMITTED van khong nhin thay hang chua commit cua nhau.
func (s *RoleService) sinhMaChuaDung(ctx context.Context, companyID, phanHe, ten string) (string, error) {
	goc := sinhMaVaiTro(phanHe, ten)
	for i := 0; i < soLanThuHauTo; i++ {
		ma := goc
		if i > 0 {
			ma = fmt.Sprintf("%s_%d", goc, i+1)
		}
		daDung, err := s.roleRepo.MaDaDung(ctx, s.db, companyID, ma)
		if err != nil {
			return "", err
		}
		if !daDung {
			return ma, nil
		}
	}
	return "", apperr.ValidationFailedFields(apperr.CodeValidationFailed, msgKhongSinhNoiMa,
		apperr.Field{Name: fieldTenVaiTro, Message: msgKhongSinhNoiMa})
}

// msgKhongSinhNoiMa la thong diep khi 50 lan thu deu trung.
//
// No noi ra viec phai lam - doi ten - chu khong de lai mot loi ky thuat: nguoi dung khong biet
// va khong can biet rang he thong vua thu 50 hau to.
const msgKhongSinhNoiMa = "ten nay da duoc dung qua nhieu lan, hay dat mot ten khac"

// dichLoiGhiVaiTro la ca giao thoa: driver tra loi KY THUAT nhung ngu nghia la NGHIEP VU.
//
// Chi service dich duoc, vi chi no biet uq_roles_company_id_code ung voi quy tac "ma vai tro
// khong trung trong mot phan vung" (R-03, P-ERR). Ma 23505 tren mot constraint KHAC di tiep
// NGUYEN TRANG: doan bua cho ra thong diep sai, va thong diep sai con kho go hon thong diep
// chung chung.
//
// Doc TEN CONSTRAINT chu khong doc ma loi: bang role_permissions cung co mot unique index, va
// 23505 mot minh khong noi cai nao vua bi vi pham.
func dichLoiGhiVaiTro(err error) error {
	var pgErr *pgconn.PgError
	if !errors.As(err, &pgErr) {
		return err
	}
	if pgErr.Code == maTrungKhoa && pgErr.ConstraintName == tenRangBuocMaVaiTro {
		// Ma lay tu shared/errors chu khong khai tai cho: bang ma loi la HOP DONG o C-API-05.
		return apperr.Conflict(apperr.CodeAuthRoleCodeDuplicated,
			"ma vai tro nay vua duoc dung, hay thu lai")
	}
	return err
}

// tenRangBuocMaVaiTro la ten partial unique index cua migration 000025.
//
// Chuoi nay la mot KHOA ma code dang so. Doi ten index trong mot migration ma quen sua day thi
// loi trung ma tut xuong thanh 500. Ten do CO trong bang anh xa constraint o C-API-http.md, nen
// doi no la mot thay doi tai lieu chu khong phai mot thay doi lang le trong migration.
const tenRangBuocMaVaiTro = "uq_roles_company_id_code"
```

`VaiTroChiTiet` mang `NhanPhanHe`, nên `RoleDeps` (Task 10 Step 3) phải nhận **đúng bảng nhãn mà `UserDeps` nhận** — cùng một `map[string]string` dựng từ `DanhMucQuyen` ở `module.go` (Task 12 Step 5). Thêm vào `RoleDeps`:

```go
	// NhanPhanHe tra nhan tieng Viet cua mot ma module. CUNG bang voi UserDeps.NhanPhanHe, va
	// "cung" o day la bat buoc: `GET /roles` va `POST /roles` tra ve cung mot hinh dang, nen hai
	// bang nhan khac nhau se lam mot vai tro doi nhan ngay sau khi luu.
	NhanPhanHe map[string]string
```

`NewRoleService` gán `nhanPhanHe: d.NhanPhanHe` vào struct `RoleService`, và `module.go` truyền `NhanPhanHe: nhanPhanHe,` vào cả hai khối `service.UserDeps{...}` lẫn `service.RoleDeps{...}`.

- [ ] **Step 4: Viết bài DB đo transaction có thật lăn lại**

`role_service_db_test.go`:

```go
// TestTaoVaiTro_GhiThatVaAuditTrongCungTransaction chay tren PostgreSQL that theo P-TEST:
// method service co ghi thi phai test tren PostgreSQL that.
//
// Bai nay do thu ma khong mot fake nao do duoc: hang roles, cac hang role_permissions va dong
// audit_logs cung sinh ra trong MOT transaction (R-17).
func TestTaoVaiTro_GhiThatVaAuditTrongCungTransaction(t *testing.T) { /* ... */ }

// TestTaoVaiTro_ChenTrungMaTra409 do hang rao CUOI, tuc khe giua lan tra va lan chen.
//
// Dung fixture: chen truoc mot hang roles mang dung ma se sinh ra, roi goi TaoVaiTro. Khong mot
// phep tra nao o tang service thay hang do vi repo gia khong duoc dung o day - day la database
// that, va cai chan lai la chinh uq_roles_company_id_code.
func TestTaoVaiTro_ChenTrungMaTra409(t *testing.T) { /* ... */ }
```

Hai bài này dựng service thật với `repository.NewRoleRepository()`, `audit.NewPostgres()` và một `authz.New` nhỏ; khẳng định `apperr.CodeAuthRoleCodeDuplicated` cho bài thứ hai và một dòng `audit_logs` mang `action = 'role.created'` cho bài thứ nhất.

- [ ] **Step 5: Chạy cho thấy xanh, rồi commit**

```bash
go build ./... && go run ./cmd/dev arch
go test ./modules/auth/internal/service/ -run 'TestTaoVaiTro_ThieuQuyen|TestTaoVaiTro_TapQuyenRong|TestTaoVaiTro_SinhMa|TestTaoVaiTro_TraTrangThai|TestKiemGhiTapQuyen'
# rồi CI hoặc VPS cho hai bài DB
git add modules/auth/internal/service/role_service.go \
        modules/auth/internal/service/role_service_test.go \
        modules/auth/internal/service/role_service_db_test.go
git commit -m "feat(auth): RoleService.TaoVaiTro

Mã do backend sinh, tra trùng bất kể deleted_at (ADR-0027 mục 3). Hiệu đối xứng
tính qua hieuDoiXungVaiTro với tập cũ rỗng chứ không truyền thẳng tập gửi lên —
hai đường ghi chạy cùng một phép tính."
```

---

## Task 17: `PATCH /roles/:id` ở tầng service

**Files:**
- Modify: `backend-erp/modules/auth/internal/service/role_service.go`
- Test: `backend-erp/modules/auth/internal/service/role_service_test.go`, `role_service_db_test.go`

Bốn luật riêng của đường này (spec mục 6.5): `code` không nhận; `is_system` chỉ cho `name`/`description` đi qua; vai trò admin của phân vùng còn sống không tắt được (hệ quả của luật 2); tắt một vai trò đang có người giữ thì cho phép nhưng response trả `so_nguoi_giu`.

- [ ] **Step 1: Viết test đỏ trước**

```go
// TestSuaVaiTro_VaiTroHeThongKhoaTapQuyenVaCoBatTat chot luat 2 va luat 3 cua muc 6.5.
//
// Bon nhanh, va ca bon deu can: hai thu bi KHOA va hai thu van MO. Mot bai chi do chieu khoa se
// van xanh khi mot cai dat khoa TAT CA - va luc do khong ai sua noi ten mot vai tro he thong.
func TestSuaVaiTro_VaiTroHeThongKhoaTapQuyenVaCoBatTat(t *testing.T) {
	dungRepo := func() *roleRepoGia {
		return &roleRepoGia{
			dongTheoID:  repository.DongDanhMucVaiTro{ID: idVaiTroTest, Ma: "auth.admin", Nhan: "Quan tri", HeThongTao: true, DangDung: true},
			quyenTheoID: []string{permVanHanhKho},
		}
	}
	actor := actorQuanTri("cong-ty")
	ten, moTa := "Ten moi", "Mo ta moi"
	tat := false
	quyen := []string{permVanHanhKho, permVanHanhBanHang}

	t.Run("gui permissions thi 422", func(t *testing.T) {
		svc := dungRoleService(dungRepo())
		_, err := svc.SuaVaiTro(context.Background(), actor, idVaiTroTest, service.SuaVaiTroInput{Quyen: &quyen})
		kiemMaLoi(t, err, apperr.CodeAuthRoleSystemLocked, "permissions")
	})
	t.Run("gui dang_dung thi 422", func(t *testing.T) {
		svc := dungRoleService(dungRepo())
		_, err := svc.SuaVaiTro(context.Background(), actor, idVaiTroTest, service.SuaVaiTroInput{DangDung: &tat})
		kiemMaLoi(t, err, apperr.CodeAuthRoleSystemLocked, "dang_dung")
	})
	t.Run("gui name thi di qua", func(t *testing.T) {
		svc := dungRoleService(dungRepo())
		if _, err := svc.SuaVaiTro(context.Background(), actor, idVaiTroTest, service.SuaVaiTroInput{Ten: &ten}); err != nil {
			t.Fatalf("sua TEN cua mot vai tro he thong bi tu choi: %v - luat 2 chi khoa tap quyen va co bat tat", err)
		}
	})
	t.Run("gui description thi di qua", func(t *testing.T) {
		svc := dungRoleService(dungRepo())
		if _, err := svc.SuaVaiTro(context.Background(), actor, idVaiTroTest, service.SuaVaiTroInput{MoTa: &moTa}); err != nil {
			t.Fatalf("sua MO TA cua mot vai tro he thong bi tu choi: %v", err)
		}
	})
}

// TestSuaVaiTro_TatVaiTroCoNguoiGiuThiChoQua_VaTraSoNguoiGiu chot luat 5.
//
// Cho qua chu khong chan: nguoi dung chot "tat, khong xoa", va mot vai tro khong ai giu thi
// chang can tat. Con so di ra response de man hinh hoi lai mot cau TRUOC khi gui - "Tắt vai trò
// này? 12 người đang giữ sẽ mất quyền trong vòng 30 giây."
func TestSuaVaiTro_TatVaiTroCoNguoiGiuThiChoQua_VaTraSoNguoiGiu(t *testing.T) {
	repo := &roleRepoGia{
		dongTheoID:  repository.DongDanhMucVaiTro{ID: idVaiTroTest, Ma: "kho.ke_toan", Nhan: "Ke toan", DangDung: true, SoNguoiGiu: 12},
		quyenTheoID: []string{permVanHanhKho},
	}
	svc := dungRoleService(repo)
	tat := false

	ra, err := svc.SuaVaiTro(context.Background(), actorChiGanKhoDatDuocVaiTro("cong-ty"), idVaiTroTest,
		service.SuaVaiTroInput{DangDung: &tat})
	if err != nil {
		t.Fatalf("tat mot vai tro dang co nguoi giu bi tu choi: %v", err)
	}
	if ra.SoNguoiGiu != 12 {
		t.Errorf("so_nguoi_giu = %d, muon 12 - man hinh doc con so nay de hoi lai truoc khi gui", ra.SoNguoiGiu)
	}
	if ra.DangDung {
		t.Error("dang_dung van true sau khi tat")
	}
}

// TestSuaVaiTro_IDSaiDinhDangTra404 chot rang mot id khong phai UUID khong tut xuong 500.
//
// Cot id la UUID, nen mot chuoi khong dung dinh dang di thang vao `WHERE id = $2` lam PostgreSQL
// tra 22P02 - mot loi KY THUAT ra client duoi dang ERR_INTERNAL, trong khi su that la khong co
// ban ghi nao mang dinh danh do.
func TestSuaVaiTro_IDSaiDinhDangTra404(t *testing.T) {
	repo := &roleRepoGia{}
	svc := dungRoleService(repo)
	ten := "Ten moi"

	_, err := svc.SuaVaiTro(context.Background(), actorQuanTri("cong-ty"), "khong-phai-uuid",
		service.SuaVaiTroInput{Ten: &ten})
	var ae *apperr.Error
	if !errors.As(err, &ae) || ae.Code != apperr.CodeNotFound {
		t.Fatalf("loi = %v, muon %s", err, apperr.CodeNotFound)
	}
	if repo.soLanTheoID != 0 {
		t.Error("da cham database voi mot id sai dinh dang")
	}
}
```

- [ ] **Step 2: Chạy cho thấy đỏ**

```bash
go test ./modules/auth/internal/service/ -run 'TestSuaVaiTro'
```

- [ ] **Step 3: Viết `SuaVaiTro`**

```go
// SuaVaiTroInput la bon truong TUY CHON cua mot lan sua (spec muc 6.5).
//
// Moi truong la con tro: nil nghia la "khong gui", va truong do khong duoc cham. Chuoi rong
// khac nil, va khac biet do co nghia - `""` o MoTa la "xoa trang mo ta".
//
// Quyen la *[]string chu khong []string, va do khong phai mot chi tiet: mot mang RONG gui len
// la mot lenh hop le va ro rang - "go sach moi quyen cua vai tro nay" - trong khi khong gui
// truong nay nghia la "khong dung toi tap quyen". Mot []string tran khong phan biet duoc hai ca
// do, va lan nhap nham se go sach quyen cua mot vai tro dang chay.
//
// KHONG co truong Ma (rang buoc 5). Truong `code` neu client gui len bi tu choi 422 o TANG
// HANDLER, khong o day: xem SuaVaiTroRequest.
type SuaVaiTroInput struct {
	Ten      *string
	MoTa     *string
	Quyen    *[]string
	DangDung *bool
}

// SuaVaiTro sua MOT vai tro cua phan vung actor (spec muc 6.5).
//
// # Bon luat rieng cua duong nay
//
//  1. `code` khong nhan, khong doi (rang buoc 5, ADR-0023 muc 5). Cuong che o HAI cho va ca hai
//     deu la loi bien dich chu khong mot phep kiem: SuaVaiTroInput khong co truong do, va
//     repository.SuaVaiTroRow cung khong. Truong `code` client gui len bi handler tu choi 422.
//  2. `is_system = true`: chi Ten va MoTa di qua. Gui Quyen hoac DangDung thi 422 kem `fields`
//     noi ro truong nao bi tu choi.
//  3. Vai tro admin cua mot phan vung con song khong tat duoc. No nam trong nhom is_system nen
//     luat 2 da chan; ghi ra day vi do la LY DO NGHIEP VU, khong phai mot he qua ky thuat.
//  4. Phan vung bi an thi vai tro cua no an theo, va dieu do TU DUNG chu khong can code: moi
//     cau doc vai tro loc theo company_id cua actor (R-06), ma khong ai dang nhap duoc vao mot
//     phan vung da vo hieu hoa. Khong them cot, khong them phep kiem - ghi ra day de lan sau
//     khong ai di lam lai no.
//
// # Tap quyen cu doc tu DATABASE, khong tu authz
//
// authz cache 30 giay (shared/authz/nguon_db.go, nhipHetHan). Tinh hieu doi xung tren mot buc
// anh cu toi 30 giay se cho ra mot tap `them` va mot tap `goBo` sai - chen trung hoac go nham -
// va cai sai do di thang xuong database. Duong DOC dung cache duoc; duong GHI thi khong.
//
// # Doc dangCo NGOAI transaction
//
// Cung khuon voi ThayVaiTro va voi C-GO-06: chuan bi va kiem truoc BEGIN, transaction chi con
// lai phan ghi that su (P-TXN).
func (s *RoleService) SuaVaiTro(ctx context.Context, actor auth.Actor, id string, in SuaVaiTroInput) (*VaiTroChiTiet, error) {
	if err := s.authz.Can(ctx, actor, PermRoleUpdate); err != nil {
		return nil, err
	}
	if !laUUID(id) {
		return nil, loiVaiTroKhongTonTai()
	}

	dong, err := s.roleRepo.TheoID(ctx, s.db, actor.CompanyID, id)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, loiVaiTroKhongTonTai()
		}
		return nil, fmt.Errorf("doc vai tro %s: %w", id, err)
	}

	if err := kiemVaiTroHeThong(dong.HeThongTao, in); err != nil {
		return nil, err
	}

	quyenCu, err := s.roleRepo.QuyenTheoVaiTroID(ctx, s.db, actor.CompanyID, id)
	if err != nil {
		return nil, err
	}
	var them, goBo []string
	if in.Quyen != nil {
		them, goBo = hieuDoiXungVaiTro(quyenCu, *in.Quyen)
		if err := s.kiemGhiTapQuyen(ctx, actor, append(append([]string{}, them...), goBo...)); err != nil {
			return nil, err
		}
	}

	tx, err := s.db.BeginTxx(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("begin tx sua vai tro %s: %w", id, err)
	}
	defer tx.Rollback()

	if err := s.roleRepo.Sua(ctx, tx, actor.CompanyID, actor.UserID, id, repository.SuaVaiTroRow{
		Nhan: in.Ten, MoTa: in.MoTa, DangDung: in.DangDung,
	}); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, loiVaiTroKhongTonTai()
		}
		return nil, dichLoiGhiVaiTro(err)
	}
	// GO truoc roi THEM, cung thu tu ma kiemGanVaiTro chay: no quyet dinh thong diep nao ra
	// client khi mot request sai o ca hai chieu, va doi no la doi mot hop dong khong ai khai bao.
	if err := s.roleRepo.GoQuyen(ctx, tx, actor.CompanyID, actor.UserID, id, goBo); err != nil {
		return nil, dichLoiGhiVaiTro(err)
	}
	if err := s.roleRepo.ThemQuyen(ctx, tx, actor.CompanyID, actor.UserID, id, them); err != nil {
		return nil, dichLoiGhiVaiTro(err)
	}
	if err := s.ghiAudit(ctx, tx, actor, actionRoleUpdated, id); err != nil {
		return nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("commit tx sua vai tro %s: %w", id, err)
	}

	// Dung trang thai tra ve tu hang DA DOC cong nhung truong vua ghi de, khong doc lai: mot cau
	// SELECT o day chay ngoai transaction vua commit. so_nguoi_giu lay tu hang da doc - con so
	// do la thu man hinh dung de hoi lai mot cau truoc khi gui (luat 5), va no khong doi vi mot
	// lan tat.
	quyenMoi := quyenCu
	if in.Quyen != nil {
		quyenMoi = *in.Quyen
	}
	mods := moduleCuaTapQuyen(quyenMoi, s.quyenTuTacDong)
	return &VaiTroChiTiet{
		ID: id, Ma: dong.Ma,
		Nhan:       chonChuoi(in.Ten, dong.Nhan),
		MoTa:       chonChuoi(in.MoTa, dong.MoTa),
		DangDung:   chonBool(in.DangDung, dong.DangDung),
		HeThongTao: dong.HeThongTao,
		PhanHe:     mods,
		NhanPhanHe: nhanCuaModule(mods, s.nhanPhanHe),
		SoNguoiGiu: dong.SoNguoiGiu,
		Quyen:      quyenMoi,
	}, nil
}

// kiemVaiTroHeThong ap luat 2 cua muc 6.5: vai tro he thong chi cho Ten va MoTa di qua.
//
// Ham cap PACKAGE chu khong method: no khong doc mot field nao cua RoleService, va mot ham thuan
// thi test duoc mot minh.
//
// Bao ca HAI truong bi tu choi khi ca hai cung duoc gui? Khong - dung o truong DAU TIEN, va do
// la co y: hai muc trong `fields` cho mot lan tu choi mang cung mot ly do se lam form to hai o
// cung luc trong khi nguoi dung chi can biet mot dieu - vai tro nay khoa.
//
// Thu tu Quyen truoc DangDung khong tuy y: tick quyen la thao tac nguy hiem hon, nen no dang
// duoc goi ten truoc khi ca hai cung sai.
func kiemVaiTroHeThong(heThongTao bool, in SuaVaiTroInput) error {
	if !heThongTao {
		return nil
	}
	if in.Quyen != nil {
		return apperr.ValidationFailedFields(apperr.CodeAuthRoleSystemLocked, msgVaiTroHeThongKhoa,
			apperr.Field{Name: fieldQuyen, Message: msgVaiTroHeThongKhoa})
	}
	if in.DangDung != nil {
		return apperr.ValidationFailedFields(apperr.CodeAuthRoleSystemLocked, msgVaiTroHeThongKhoa,
			apperr.Field{Name: fieldDangDung, Message: msgVaiTroHeThongKhoa})
	}
	return nil
}

// msgVaiTroHeThongKhoa noi ra LY DO va viec phai lam, khong de lai mot cau tu choi tran.
//
// HANG, khong ghep gia tri client gui len vao: chuoi loi dung tu du lieu request la mot cho de
// gia tri cua client lot ra response.
const msgVaiTroHeThongKhoa = "vai tro he thong: chi sua duoc ten va mo ta. Tao mot vai tro rieng neu can tap quyen khac"

// chonChuoi va chonBool tra ve gia tri MOI neu nguoi goi co gui, khong thi giu gia tri cu.
//
// Hai ham hai dong chu khong hai lan viet `if x != nil` tai cho: khoi dung trang thai tra ve co
// bon truong theo cung mot khuon, va bon lan viet lai khuon do la bon co hoi go nham mot bien.
func chonChuoi(moi *string, cu string) string {
	if moi != nil {
		return *moi
	}
	return cu
}

func chonBool(moi *bool, cu bool) bool {
	if moi != nil {
		return *moi
	}
	return cu
}
```

- [ ] **Step 4: Thêm hai bài DB**

`role_service_db_test.go`:

```go
// TestSuaVaiTro_GoRoiThemTapQuyenTrenDatabaseThat do thu khong fake nao do duoc: sau mot lan
// sua, tap quyen doc len phai dung bang tap gui len - khong thua mot hang bia mo nao duoc dem,
// khong thieu mot ma nao vua tick.
func TestSuaVaiTro_GoRoiThemTapQuyenTrenDatabaseThat(t *testing.T) { /* ... */ }

// TestSuaVaiTro_TatRoiThiNguoiGiuMatQuyen noi hai task lai voi nhau: PATCH dat is_active = false,
// va authz.NguonQuyen doc lai khong con thay vai tro do.
//
// Bai nay la ban do TU DAU DEN CUOI cua diem 2 nguoi dung chot, va no phai o tang nay: mot bai o
// Task 7 do cau SQL, con bai nay do rang thao tac NGUOI DUNG BAM that su dan toi cau SQL do.
func TestSuaVaiTro_TatRoiThiNguoiGiuMatQuyen(t *testing.T) { /* ... */ }
```

- [ ] **Step 5: Chạy cho thấy xanh, rồi commit**

```bash
go build ./... && go run ./cmd/dev arch
go test ./modules/auth/internal/service/ -run 'TestSuaVaiTro_VaiTroHeThong|TestSuaVaiTro_TatVaiTro|TestSuaVaiTro_IDSai'
# rồi CI hoặc VPS cho hai bài DB
git add modules/auth/internal/service/role_service.go \
        modules/auth/internal/service/role_service_test.go \
        modules/auth/internal/service/role_service_db_test.go
git commit -m "feat(auth): RoleService.SuaVaiTro

Tập quyền cũ đọc từ database chứ không từ authz: nhớ đệm 30 giây làm hiệu đối
xứng tính trên một bức ảnh cũ, và cái sai đó đi thẳng xuống database. Vai trò hệ
thống khoá đúng hai thứ và mở đúng hai thứ."
```

---

## Task 18: Handler và route `POST /roles`, `PATCH /roles/:id`

**Files:**
- Modify: `backend-erp/modules/auth/internal/handler/role_handler.go`
- Modify: `backend-erp/modules/auth/internal/handler/role_routes.go`
- Test: `backend-erp/modules/auth/internal/handler/role_handler_test.go`

- [ ] **Step 1: Viết test đỏ trước**

```go
// TestCreate_Tra201VaHinhDangDTO chot status va hinh dang than.
//
// 201 chu khong 200 (CL-API-03): POST tao mot tai nguyen moi.
func TestCreate_Tra201VaHinhDangDTO(t *testing.T) { /* dựng engine, POST, đọc lại JSON, kiểm tám khoá */ }

// TestCreate_GuiTruongCodeTra422TroVaoDungO chot rang buoc 5 o tang HTTP.
//
// Tu choi chu khong LANG LE BO QUA, va do la ca quyet dinh: mot client gui `code` len dang tin
// rang no quyet dinh ma vai tro. Bo qua im lang se lam ho tao ra mot vai tro mang mot ma khac
// han thu ho vua thay, va khong gi noi ra dieu do. Mot 422 tro dung vao o `code` noi thang.
func TestCreate_GuiTruongCodeTra422TroVaoDungO(t *testing.T) { /* ... */ }

// TestPatch_GuiTruongCodeTra422 la ban doi xung tren duong sua, va o day no con dat hon:
// roles.code BAT BIEN sau khi tao (ADR-0023 muc 5), va migration co y khong cuong che dieu do.
func TestPatch_GuiTruongCodeTra422(t *testing.T) { /* ... */ }

// TestPatch_ThanRongLaHopLe chot rang mot PATCH khong gui truong nao KHONG phai loi.
//
// No la mot thao tac khong doi gi, va no tra ve trang thai hien tai - dung nghia cua PATCH. Bat
// no 422 se lam man hinh phai tu doi chieu xem co gi doi khong truoc khi gui, tuc mot quy tac
// nghiep vu bi day sang frontend (R-19).
func TestPatch_ThanRongLaHopLe(t *testing.T) { /* ... */ }
```

- [ ] **Step 2: Chạy cho thấy đỏ**

```bash
go test ./modules/auth/internal/handler/ -run 'TestCreate_|TestPatch_'
```

- [ ] **Step 3: Viết hai DTO request và hai method**

```go
// TaoVaiTroRequest la DTO cua lop HTTP cho `POST /roles`.
//
// # Vi sao co truong Code du backend khong doc no
//
// De TU CHOI no (rang buoc 5). Ma do backend sinh, khong nhan tu client (spec muc 6.4), va mot
// client gui `code` len dang tin rang no quyet dinh ma vai tro. Bo qua im lang se cho ra mot vai
// tro mang mot ma khac han thu ho vua thay tren o xem truoc, va khong gi noi ra dieu do. Mot
// truong khai o day rieng de tra 422 tro dung vao o `code` la cach re nhat de noi thang.
//
// # Vi sao Permissions KHONG co rang buoc binding nao
//
// Rang buoc 7 chot rang phep kiem `permission_code` nam o TANG SERVICE, doi chieu voi danh muc
// hang. Mot `dive,max=64` o day se la mot phep kiem THU HAI tren cung mot gia tri, va no yeu
// hon: no cho qua moi chuoi duoi 64 ky tu. Hai phep kiem tren cung mot thu la hai phep kiem se
// lech, va ban yeu hon khong bao gio bao gi.
//
// Module co `alphanum` vi no di vao chuoi ma vai tro: mot dau cham trong do se cho ra
// `kho.van.thu_kho` - hai dau cham, va moi phep cat tien to sau nay se doc sai. `max=32` la tran
// an toan de tong do dai mot ma nam duoi 60 ky tu cung doDaiToiDaSlug.
type TaoVaiTroRequest struct {
	Name        string   `json:"name" binding:"required,max=255"`
	Description string   `json:"description" binding:"max=1000"`
	Module      string   `json:"module" binding:"required,alphanum,max=32"`
	Permissions []string `json:"permissions"`

	Code *string `json:"code"`
}

// Create xu ly POST /api/v1/roles.
func (h *RoleHandler) Create(c *gin.Context) {
	var req TaoVaiTroRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BindFailed(c, err)
		return
	}
	if req.Code != nil {
		response.ValidationFailed(c, []response.FieldError{{Field: fieldMaVaiTroHTTP, Message: msgMaDoHeThongSinh}})
		return
	}

	ctx := c.Request.Context()
	actor := auth.FromContext(ctx)

	v, err := h.svc.TaoVaiTro(ctx, actor, service.TaoVaiTroInput{
		Ten: req.Name, MoTa: req.Description, PhanHe: req.Module, Quyen: req.Permissions,
	})
	if err != nil {
		response.Error(c, err)
		return
	}
	response.Created(c, toVaiTroDTO(v))
}

// `dang_dung` tieng Viet nam canh ba ten tieng Anh la QUYET DINH CO CHU Y, khong phai cho sot:
// no khop dung ten truong ma `GET /roles` tra ve, nen client doc mot ten va ghi lai chinh ten do.
//
// SuaVaiTroRequest la DTO cua lop HTTP cho `PATCH /roles/:id`. Moi truong TUY CHON.
//
// Permissions la *[]string: mot mang RONG gui len la mot lenh hop le va ro rang - "go sach moi
// quyen" - trong khi khong gui truong nay nghia la "khong dung toi tap quyen". Mot []string
// tran khong phan biet duoc hai ca do.
//
// `dang_dung` la ten tieng Viet nam canh ba ten tieng Anh, va do la cho lech DUY NHAT trong
// hop dong nay. No theo dung spec muc 6.5 va theo dung ten truong tra ve o `GET /roles`, nen
// client doc mot ten va ghi lai chinh ten do. Dat `is_active` o day se lam mot truong doc mot
// ten va ghi mot ten khac.
//
// Truong Code o day cung de TU CHOI, va o duong nay no con dat hon: roles.code BAT BIEN sau khi
// tao (ADR-0023 muc 5), migration co y khong cuong che, va duong ghi nay la cho cuong che.
type SuaVaiTroRequest struct {
	Name        *string   `json:"name" binding:"omitempty,max=255"`
	Description *string   `json:"description" binding:"omitempty,max=1000"`
	Permissions *[]string `json:"permissions"`
	DangDung    *bool     `json:"dang_dung"`

	Code *string `json:"code"`
}

// Patch xu ly PATCH /api/v1/roles/:id.
func (h *RoleHandler) Patch(c *gin.Context) {
	var req SuaVaiTroRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BindFailed(c, err)
		return
	}
	if req.Code != nil {
		response.ValidationFailed(c, []response.FieldError{{Field: fieldMaVaiTroHTTP, Message: msgMaVaiTroBatBien}})
		return
	}

	ctx := c.Request.Context()
	actor := auth.FromContext(ctx)

	v, err := h.svc.SuaVaiTro(ctx, actor, c.Param("id"), service.SuaVaiTroInput{
		Ten: req.Name, MoTa: req.Description, Quyen: req.Permissions, DangDung: req.DangDung,
	})
	if err != nil {
		response.Error(c, err)
		return
	}
	response.Success(c, toVaiTroDTO(v))
}

// VaiTroDTO la than tra ve cua CA HAI duong ghi.
//
// Mot DTO cho ca hai chu khong hai: hai endpoint tra ve cung mot thu - trang thai cua mot vai
// tro sau khi ghi - va hai struct gan giong nhau se lech vao dung ngay mot ben them mot truong.
//
// Chin truong dau khop tung ten voi VaiTroKhaDungDTO cua `GET /roles`, va do la co y: man hinh
// nhan mot dong tu day roi ghep thang vao danh sach da tai, khong phai doi hinh dang. `quyen`
// la truong thu muoi, chi co o day - danh sach khong can no, con man Sua thi can de tick lai
// dung nhung o vua luu.
type VaiTroDTO struct {
	ID         string   `json:"id"`
	Ma         string   `json:"ma"`
	Nhan       string   `json:"nhan"`
	MoTa       string   `json:"mo_ta"`
	DangDung   bool     `json:"dang_dung"`
	HeThongTao bool     `json:"he_thong_tao"`
	PhanHe     []string `json:"phan_he"`
	NhanPhanHe []string `json:"nhan_phan_he"`
	SoNguoiGiu int64    `json:"so_nguoi_giu"`
	Quyen      []string `json:"quyen"`
}

// toVaiTroDTO doi trang thai cua tang service thanh hinh dang cong khai.
//
// MOT ham cho ca hai duong ra chu khong hai khoi gan giong nhau: hai ban chep tay se lech nhau
// dung vao ngay VaiTroDTO them mot field, va ban bi quen khong lam vo build - no lang le tra ve
// gia tri zero cho field do.
//
// Ba slice khoi tao san chu khong de nil: `null` trong mot truong mang lam frontend phai kiem
// them mot nhanh khong noi len dieu gi khac `[]` (C-API-03).
func toVaiTroDTO(v *service.VaiTroChiTiet) VaiTroDTO {
	phanHe := v.PhanHe
	if phanHe == nil {
		phanHe = []string{}
	}
	nhanPhanHe := v.NhanPhanHe
	if nhanPhanHe == nil {
		nhanPhanHe = []string{}
	}
	quyen := v.Quyen
	if quyen == nil {
		quyen = []string{}
	}
	return VaiTroDTO{
		ID: v.ID, Ma: v.Ma, Nhan: v.Nhan, MoTa: v.MoTa,
		DangDung: v.DangDung, HeThongTao: v.HeThongTao,
		PhanHe: phanHe, NhanPhanHe: nhanPhanHe,
		SoNguoiGiu: v.SoNguoiGiu, Quyen: quyen,
	}
}

// fieldMaVaiTroHTTP la ten o `code` trong than request, va hai thong diep tu choi cua no.
//
// Hai thong diep khac nhau cho hai duong vi hai LY DO khac nhau: o duong tao, ma chua ton tai
// va he thong dang sinh no; o duong sua, ma da ton tai va no bat bien. Mot cau chung cho ca hai
// se dung mot nua va lam nguoi doc di sai huong o nua kia.
const (
	fieldMaVaiTroHTTP  = "code"
	msgMaDoHeThongSinh = "ma vai tro do he thong sinh tu phan he va ten, khong nhan tu client"
	msgMaVaiTroBatBien = "ma vai tro khong doi duoc sau khi tao"
)
```

- [ ] **Step 4: Mở hai dòng route**

`role_routes.go` — bỏ chú thích tạm và bật hai dòng `v1.POST("/roles", ...)`, `v1.PATCH("/roles/:id", ...)` đã viết sẵn ở Task 11 Step 4.

- [ ] **Step 5: Chạy cho thấy xanh, rồi commit**

```bash
go build ./... && go run ./cmd/dev arch && go run ./cmd/dev lint
go test ./modules/auth/internal/handler/
git add modules/auth/internal/handler/role_handler.go \
        modules/auth/internal/handler/role_routes.go \
        modules/auth/internal/handler/role_handler_test.go
git commit -m "feat(auth): POST /api/v1/roles va PATCH /api/v1/roles/:id

Trường `code` được khai ở cả hai DTO để TỪ CHỐI 422 chứ không bỏ qua im lặng:
một client gửi code lên đang tin rằng nó quyết định mã vai trò."
```

---

## Task 19: e2e qua ngăn xếp đầy đủ

**Files:**
- Create: `backend-erp/cmd/api/e2e_vaitro_2b_test.go`

Tầng này là tầng duy nhất chứng minh được rằng **không có đường tắt giữa router và phép chặn** — đúng lập luận mà `e2e_adr0037_test.go` đã viết: một bài ở tầng service chứng minh được *hàm* từ chối; chỉ một request HTTP thật mới chứng minh được cái `curl` kia không qua.

- [ ] **Step 1: Bốn bài, mỗi bài một mệnh đề**

```go
// TestE2ETaoVaiTroRoiGanChoNguoiThat di het duong ma dot 2b mo ra, bang token that va bang bay
// ma vai tro that cua he.
//
// Do bang mot vong khep kin: auth.admin cua mot phan vung tao mot vai tro moi voi mot tap quyen,
// roi PUT /users/:id/roles gan chinh vai tro do cho mot nhan vien. Neu bat cu khau nao lech -
// ma sinh sai, tap quyen chen hut, vai tro khong xuat hien trong GET /roles - vong nay dut.
func TestE2ETaoVaiTroRoiGanChoNguoiThat(t *testing.T) { /* ... */ }

// TestE2EQuanTriKhoKhongTickDuocQuyenAuth do rang buoc 2 tren ngan xep that.
//
// `inventory.admin` KHONG co auth.role_assign, nen mot POST /roles mang `auth.user_delete` phai
// tra 422 ERR_AUTH_ROLE_PERMISSION_FORBIDDEN. Do la dung ca ADR-0024 muc 3 goi ten: mot quan tri
// module nay che ra mot vai tro mang quyen cua module kia roi gan no.
//
// Bai nay cung do luon rang 403 KHONG phai cau tra loi: actor co quyen goi endpoint, va mot 403
// se lam man hinh bao "ban khong sua duoc vai tro" trong khi su that la mot o tick sai.
func TestE2EQuanTriKhoKhongTickDuocQuyenAuth(t *testing.T) { /* ... */ }

// TestE2ESuaVaiTroHeThongChiDoiDuocTenVaMoTa do luat 2 cua muc 6.5 tren mot vai tro THAT -
// `auth.admin` cua phan vung seed, hang ma migration 000034 vua bat is_system.
//
// Bon lan PATCH: name qua, description qua, permissions 422, dang_dung 422. Bon lan rieng chu
// khong mot lan gop: mot lan gop ma do thi khong noi duoc truong nao hong.
func TestE2ESuaVaiTroHeThongChiDoiDuocTenVaMoTa(t *testing.T) { /* ... */ }

// TestE2EGetPermissionsDanhCoCapDuocTheoActor do muc 6.2 tren bang 50 ma that.
//
// Hai actor nguoc chieu - mot auth.admin va mot inventory.viewer - va so dong `cap_duoc: true`
// cua ho phai KHAC nhau. Mot minh mot chieu thi mot cai dat luon tra `true` van xanh, va trieu
// chung o production la mot man tich quyen mo het moi o roi 422 o nut Luu.
func TestE2EGetPermissionsDanhCoCapDuocTheoActor(t *testing.T) { /* ... */ }
```

Bốn bài dùng lại `moiTruongE2E`, `idCongTy`, `maCongTySeed`, `themUser`, `goiJSON`, `dangNhapVaoPhanVung`, `docData` sẵn có ở `cmd/api/e2e_test.go` — không viết thêm helper nào trừ khi cần một fixture mới.

- [ ] **Step 2: Chạy trên CI hoặc VPS**

`cmd/api` là package cần database, nên bốn bài này **không chạy được dưới Windows**. Đọc job `test` (lệnh A) hoặc chạy lệnh B.

- [ ] **Step 3: Commit**

```bash
git add cmd/api/e2e_vaitro_2b_test.go
git commit -m "test(auth): bon bai e2e cho ba endpoint cua dot 2b

Tầng duy nhất chứng minh được rằng không có đường tắt giữa router và phép chặn.
Hai actor ngược chiều ở bài cap_duoc: một mình một chiều thì một cài đặt luôn
trả true vẫn xanh."
```

---

## Task 20: Chốt cuối

**Files:** không sửa code; chỉ đánh dấu checklist và ghi bằng chứng.

- [ ] **Step 1: Chạy đủ bốn lệnh dưới máy**

```bash
cd "d:/My project web/erp/backend-erp"
go build ./...
go vet ./...
go run ./cmd/dev lint
go run ./cmd/dev arch
```

Bốn lệnh phải sạch. `arch` là lệnh quan trọng nhất trong bốn: nó đọc `migrations/`, `module.yaml` và AST của mọi tầng, nên nó là thứ bắt R-06, R-09, R-12, R-15, R-17, R-18 và C-GO-07 trên toàn bộ diff của đợt này.

- [ ] **Step 2: Chạy bộ test đầy đủ và **giữ lại output làm bằng chứng****

Đường chính là CI:

```bash
gh run watch --exit-status
gh run view --log --job test | tail -60
```

Đường dự phòng là VPS dev (lệnh B ở phần "Chạy ở đâu"). Dán 20 dòng cuối vào ghi chú bàn giao, kèm số test xanh và so với con số đã chốt ở Task 1 Step 3. **Không tuyên bố "xong" trước khi có output này** — `superpowers:verification-before-completion`.

- [ ] **Step 3: Đi qua `CL-API-new-endpoint.md`, đánh dấu thật**

Ba endpoint mới, mười bảy dòng. Bốn dòng đáng dừng lại lâu nhất:

- **CL-API-08** — bốn mã lỗi mới đã có dòng trong bảng mã lỗi và `uq_roles_company_id_code` đã có dòng trong bảng ánh xạ constraint, **trong chính đợt này**. Kiểm bằng mắt ở `docs-erp/04-conventions/C-API-http.md`.
- **CL-API-12** — ba endpoint mới **không** dùng ngoại lệ nào, nên **không** thêm dòng nào vào sổ đăng ký C-API-07. Ghi rõ lập luận cho `GET /permissions` (nó nhận đủ ba tham số, xem Task 10) để reviewer không đi tìm một dòng không tồn tại.
- **CL-API-09** — không DTO nào có `json:"company_id"` hay `form:"company_id"`, và không handler nào đọc `c.Param("company_id")`. Mọi `companyID` đi từ `actor.CompanyID`.
- **CL-API-16** — `VaiTroKhaDungDTO` chỉ **thêm** trường, không xoá, không đổi kiểu, không đổi tag `json` của hai trường cũ, và không thêm `binding:"required"` vào DTO request nào đã tồn tại.

Chạy thêm `CL-SCHEMA-schema-change.md` (hai migration) và `CL-PR-code-review.md` (bộ kiểm tổng hợp cho mọi PR).

- [ ] **Step 4: Đối soát bằng `cmd/dev seed-roles` trên dev**

Thứ tự thi công ở mục 8 của spec đòi bước này ngay sau migration, và nó đo được thứ không bài test nào đo: phép đối soát của ADR-0027 mục 7 so `DanhMucQuyen()` với tập `permission_code` đang có trong database.

```bash
ssh dev-erp 'bash -lc "cd /opt/erp/backend-erp && \
  DATABASE_URL=postgres://erp:erp@127.0.0.1:5433/erp_dev?sslmode=disable go run ./cmd/dev seed-roles"'
```

Lệnh thoát 0 và **không** báo mã lạ nào. Hai mã mới phải xuất hiện trong tập đang cấp — nếu chúng bị báo là "chưa vai trò nào cấp", tức migration 000034 chưa chạy trên dev.

- [ ] **Step 5: Chốt trạng thái `docs-erp`**

```bash
git -C "d:/My project web/erp/docs-erp" status --short
git -C "d:/My project web/erp/docs-erp" branch --show-current
```

Phải ra đúng ba file đang đổi (ADR-0038 mới, `03-decisions/README.md`, `04-conventions/C-API-http.md`) và nhánh `docs/vai-tro-dot-2b-spec`. **Không commit, không đổi nhánh.**

- [ ] **Step 6: Mở PR thật**

Chuyển draft PR thành PR thật. Thân PR nêu: ba endpoint mới, hai migration, hai mã quyền, bốn mã lỗi, hai lỗ hổng ngoài spec đã vá (Task 6 và Task 7), và một ghi chú phát hành — *sau đợt này, tập quyền của `quan_tri_he_thong` đi từ mười sáu lên mười tám mã*, theo đúng cách ADR-0024 đã đòi một thay đổi thẩm quyền phải nằm trong ghi chú phát hành chứ không để người dùng tự phát hiện.

---

## Kiểm lại sau khi viết — ba chỗ đã tự sửa

1. `moduleCuaTapQuyen` ban đầu chỉ định nghĩa ở Task 15 nhưng đã được Task 12 gọi. Đã chuyển phần định nghĩa lên Task 12 Step 4 và Task 15 chỉ gọi.
2. `hieuDoiXungVaiTro` được dùng cho **tập quyền** ở Task 16 và 17. Không nhân bản một hàm thứ hai — thân nó là phép hiệu tập thuần trên chuỗi — và mỗi chỗ gọi đều mang một câu giải thích tên hàm nói về người đọc đầu tiên của nó.
3. `roleRepoGia` phải cài bảy method mới ngay khi interface mở rộng (Task 13 Step 5), nếu không mọi bài ở `user_service_danhmuc_test.go` mất biên dịch — đã đặt bước vá vào đúng task mở rộng interface, không để sang task sau.

---

## Bốn chỗ trong spec cần người quyết, đã nêu chứ không tự bịa

**1. "48 mã" trong mục 6.2 — ĐÃ QUYẾT ngày 2026-08-27: con số là 50.** Đếm từ code hôm nay: `auth.MoiQuyen()` 15 + `inventory.MoiQuyen()` 20 + `machine.MoiQuyen()` 13 = **48**; mục 6.1 thêm hai mã, nên `GET /permissions` trả **50** dòng. Kế hoạch làm 50 và đối soát hai chiều bằng test nên con số không chép tay ở đâu, và câu "48 nhãn là phần việc thầm lặng lớn nhất của đợt này" trong spec đọc là 50.

**2. Hai mã mới cho `quan_tri_he_thong` đảo ADR-0031 mục 1 — ĐÃ QUYẾT ngày 2026-08-27: VẪN cấp hai mã cho `quan_tri_he_thong`, và ADR-0038 ghi phép đính chính mười sáu → mười tám.** Lý do bằng lời của người dùng: *"quản trị hệ thống cũng phải tự thêm được vai trò"*. ADR-0031 khoá tập quyền của vai trò dẫn xuất ở **đúng mười sáu mã**, và `cmd/internal/vaitro/adr0031_test.go` là hiện thân bằng máy của mệnh đề đó (`TestQuanTriHeThongDungMuoiSauQuyen`) — nên bài test đó sửa **cùng một commit với ADR**, ở Task 2 Step 4, chứ không trôi sang task code.

**3. Mục 5 hứa `is_active = false` làm "người đang giữ mất quyền", nhưng mục 6 không có việc nào thực hiện lời hứa đó.** Không đường nào trong mục 6 chạm tới `selectQuyenTheoVaiTroSQL` — nguồn mà `authz` đọc. Không sửa nó thì nút Tắt đổi đúng một chữ trên màn hình. Đã đưa vào Task 7 kèm hai hệ quả phải chấp nhận: thông điệp từ chối lúc gán là `vai tro khong ton tai` (chưa thật đúng), và `GET /roles` vẫn liệt kê vai trò đã tắt nên **màn gán phải tự lọc theo `dang_dung`** — một việc thuộc kế hoạch frontend mà spec mục 7 không nhắc.

**4. Spec không nói `is_system` phải được đặt ở đường ghi bộ mặc định.** Mục 5 chỉ backfill các hàng *đang có*. Một phân vùng mở **sau** đợt này đi qua `CreateCompany` → `insertVaiTroMacDinhSQL`, câu chèn không đụng `is_system`, nên bảy vai trò mặc định của nó ra đời với `is_system = false` — tắt được, sửa tập quyền được, và `auth.admin` của phân vùng ấy tự khoá mình ra ngoài được. Cùng lỗ ở `cmd/dev seed-roles`. Đã vá ở Task 6.

**Hai chỗ nhỏ hơn, nêu để người quyết chứ không chặn:**

- **Mục 6.5 trộn văn phạm trong một thân request**: `{"name", "description", "permissions", "dang_dung"}` — ba khoá tiếng Anh và một khoá tiếng Việt. Kế hoạch theo **đúng spec** (`dang_dung`), vì nó khớp tên trường mà `GET /roles` trả về nên client đọc một tên và ghi lại chính tên đó. Nếu muốn nhất quán thì phải đổi cả sáu trường mới của `GET /roles` sang tiếng Anh, và đó là một quyết định về hợp đồng API chứ không phải một dòng sửa.
- **Mục 6.3 định nghĩa `phan_he` là "mảng module" mã trần — ĐÃ QUYẾT ngày 2026-08-27: `GET /roles` trả kèm `nhan_phan_he`**, một mảng nhãn tiếng Việt song song từng phần tử với `phan_he` và cùng thứ tự. `phan_he` giữ nguyên mã trần theo đúng chữ của mục 6.3, nhãn dựng ở Go theo đúng lập luận của mục 6.2 — frontend không tự map, và thêm một module mới không đẻ ra một bảng nhãn thứ hai. Đã đưa vào Task 12 (`GET /roles`) và Task 16/17/18 (đường ghi), kèm một bài khoá bất biến "hai mảng luôn cùng độ dài".

---

**Tổng: 20 task.**

| # | Task | Một câu |
|---|---|---|
| 1 | Nhánh và vạch xuất phát | Dựng `feat/vai-tro-dot-2b-backend`, chốt bốn lệnh sạch dưới máy và số test xanh từ CI. |
| 2 | ADR-0038 | ADR mới trả lời ai đặt ra vai trò, vì sao tập quyền bị cắt theo actor, vì sao vai trò hệ thống khoá tập quyền, và đính chính ADR-0031 mười sáu → mười tám mã. |
| 3 | Migration 000033 | Ba cột `description`, `is_active`, `is_system` trên `roles`, không thêm cột `module` và không thêm index. |
| 4 | Migration 000034 | Bật `is_system` cho bảy mã mặc định và chèn hai mã quyền mới cho mọi `auth.admin` còn sống, kèm hai khối hậu điều kiện. |
| 5 | Hai mã quyền mới | `auth.role_create` và `auth.role_update` khai ở module sở hữu, mở cửa ra ở package gốc, cấp cho đúng hai vai trò quản trị. |
| 6 | `is_system` ở đường ghi bộ mặc định | Vá lỗ ngoài spec: hai câu chèn bộ mặc định đặt `is_system = true` để phân vùng mở sau đợt này không nhận bảy vai trò tắt được. |
| 7 | `is_active` cắt quyền ở nguồn authz | Vá lỗ ngoài spec: một mệnh đề `AND r.is_active` làm cả hai vế mà cột hứa — người đang giữ mất quyền, và vai trò tắt không gán mới được. |
| 8 | Bảng 50 nhãn tiếng Việt | `DanhMucQuyenCoNhan()` ở `cmd/internal/vaitro`, đối soát hai chiều với `DanhMucQuyen()` nên không con số nào chép tay. |
| 9 | Bốn mã lỗi mới | Bốn hằng ở `shared/errors` cộng bốn dòng bảng mã lỗi và một dòng bảng ánh xạ constraint ở `docs-erp`, đúng CL-API-08. |
| 10 | `RoleService` và `GET /permissions` ở service | Dựng service ghi vai trò và method danh mục quyền gác bằng `role_create` HOẶC `role_update`, phân trang chạy ở Go. |
| 11 | Handler và route `GET /permissions` | `RoleHandler.DanhMucQuyen` với DTO sáu khoá, nhận đủ ba tham số nên không đăng ký ngoại lệ R-12 nào. |
| 12 | `GET /roles` mở rộng | Sáu trường mới vào SQL, service, DTO; `phan_he` suy từ `role_permissions` qua `moduleCuaTapQuyen` dùng chung với đường gán. |
| 13 | Đường ghi ở repository | Bảy method mới, trong đó `MaDaDung` hỏi bất kể `deleted_at` và `SuaVaiTroRow` cố ý không có trường `Ma`. |
| 14 | Sinh mã vai trò | `boDauTiengViet` + `slugKhongDau` + `sinhMaVaiTro` viết tay bằng bảng rune, không thêm dependency nào. |
| 15 | `kiemGhiTapQuyen` | Một hàm gác ba ràng buộc theo đúng thứ tự: mã có thật → bỏ tập tự tác động → cửa của từng module. |
| 16 | `POST /roles` ở service | `TaoVaiTro` với hiệu đối xứng tính từ tập cũ rỗng, sinh mã kèm hậu tố, ghi ba bảng trong một transaction, audit `role.created`. |
| 17 | `PATCH /roles/:id` ở service | `SuaVaiTro` với tập quyền cũ đọc từ database chứ không từ nhớ đệm, vai trò hệ thống khoá đúng hai thứ, audit `role.updated`. |
| 18 | Handler và route `POST`/`PATCH` | Hai DTO request khai trường `code` để **từ chối 422** chứ không bỏ qua im lặng, và một `VaiTroDTO` chung cho cả hai đường ra. |
| 19 | e2e | Bốn bài qua ngăn xếp đầy đủ, trong đó bài `cap_duoc` dùng hai actor ngược chiều nhau. |
| 20 | Chốt cuối | Bốn lệnh dưới máy, bộ test đầy đủ trên CI kèm output làm bằng chứng, ba checklist, `seed-roles` trên dev, và PR thật. |
