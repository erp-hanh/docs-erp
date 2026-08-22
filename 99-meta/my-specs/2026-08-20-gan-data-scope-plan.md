# Kế hoạch thi công: đường gán Data Scope

> **Cho người thi công (kể cả subagent):** BẮT BUỘC dùng `superpowers:subagent-driven-development`
> (khuyến nghị) hoặc `superpowers:executing-plans` để thi công từng task. Các bước dùng cú
> pháp checkbox (`- [ ]`) để theo dõi.

**Mục tiêu:** Dựng đường GHI phạm vi dữ liệu (backend) và hai màn hình để admin phân vùng gán
kho cho từng hàng vai trò của một người.

**Kiến trúc:** Permission mới `auth.user_assign_scopes` cấp cho vai trò `admin`. Danh mục loại
phạm vi (nhãn + permission toàn phạm vi + `scope.Nguon`) tiêm từ `cmd/api` vào module `auth`.
`ScopeService` mới trong module `auth` đọc/ghi bảng `user_company_role_scopes` qua một
repository mới; hai endpoint `GET|PUT /api/v1/users/:id/scopes` thay TOÀN BỘ phạm vi của mọi
hàng vai trò trong một transaction. Frontend dựng module `user` mới với hai màn.

**Ngăn xếp:** Go 1.x + gin + sqlx + pgx stdlib + PostgreSQL (backend); React 19 + TanStack
Query v5 + Vite + Vitest, không thư viện UI, không router ngoài (frontend).

**Thiết kế gốc:** [2026-08-20-gan-data-scope-design.md](2026-08-20-gan-data-scope-design.md)

---

## Điều kiện trước khi bắt đầu

- **Không có migration mới.** Ba bảng đã chạy từ `000021`-`000023`. Ai thấy mình đang viết
  file migration là đã đi sai.
- **Không sửa** `shared/authz`, `shared/auth`, `shared/scope`, `arch/checks_ast.go`,
  `arch/checks_migration.go`, `RULES.md`, và không sửa chữ nào trong ADR-0019 / ADR-0020 /
  ADR-0010.
- **Nhánh riêng cho mỗi repo** (main không được bảo vệ nhưng vẫn không commit thẳng):
  - `backend-erp`: `git switch -c feat/gan-data-scope`
  - `frontend-erp`: `git switch -c feat/man-gan-pham-vi`
- **Test Go chạm database KHÔNG chạy được dưới máy** (không có Docker Desktop). Dưới máy chỉ
  chạy `go build ./...`, `go vet ./...`, `go run ./cmd/dev check`, `go run ./cmd/dev arch`.
  Bằng chứng test lấy từ CI sau khi push. Mỗi task có test đều ghi rõ hai mức: kiểm dưới máy
  và kiểm trên CI.

## Bản đồ file

**backend-erp — tạo mới:**

| File | Trách nhiệm |
|---|---|
| `modules/auth/internal/repository/user_company_role_scope_repository.go` | đọc và thay phạm vi của một cặp (hàng vai trò, loại) |
| `modules/auth/internal/service/scope_service.go` | nghiệp vụ: kiểm quyền, kiểm dữ liệu, ranh giới transaction, audit |
| `modules/auth/internal/handler/user_scope_handler.go` | DTO HTTP + hai handler |
| `modules/auth/internal/service/scope_service_test.go` | test service trên PostgreSQL thật |

**backend-erp — sửa:**

| File | Sửa gì |
|---|---|
| `modules/auth/internal/service/permissions.go` | thêm hằng `PermUserAssignScopes` |
| `modules/auth/module.go` | tái xuất hằng, thêm kiểu `PhamViKhaDung`, thêm `Deps.LoaiPhamVi`, dựng `ScopeService` + handler trong `New`, đăng ký route |
| `modules/auth/internal/repository/user_company_repository.go` | thêm `VaiTroTheoUser` |
| `modules/auth/internal/handler/user_routes.go` | thêm hai dòng route |
| `cmd/internal/vaitro/vaitro.go` | cấp `auth.PermUserAssignScopes` cho `admin` |
| `cmd/api/main.go` | dựng danh sách `LoaiPhamVi` một lần, dùng cho cả `scope.New` và `auth.New` |
| `cmd/api/e2e_test.go` | dựng cùng danh sách + test đầu-cuối |

**frontend-erp — tạo mới:** `src/modules/user/{types.ts, api/user-api.ts, hooks/user-keys.ts,
hooks/use-user-list.ts, hooks/use-user-scopes.ts, hooks/use-update-user-scopes.ts,
components/user-list-params.ts, pages/UserListPage.tsx, pages/UserScopePage.tsx}` + test.

**frontend-erp — sửa:** `src/app/routes.tsx`, `src/app/ung-dung.ts`.

---

## Task 1: Permission `auth.user_assign_scopes`

**Files:**
- Modify: `modules/auth/internal/service/permissions.go`
- Modify: `modules/auth/module.go` (khối hằng tái xuất, khoảng dòng 64-69)
- Modify: `cmd/internal/vaitro/vaitro.go` (khối `QuanTri`, khoảng dòng 227-234)

- [ ] **Bước 1: Thêm hằng trong `permissions.go`**

Thêm ngay dưới `PermUserAssignRoles`, **bên trong cùng khối `const`**:

```go
	// PermUserAssignScopes tach RIENG khoi PermUserAssignRoles vi hai thao tac tra loi hai
	// cau hoi khac nhau: gan vai tro noi "nguoi nay lam duoc loai viec gi", gan pham vi noi
	// "tren nhung ban ghi nao" (ADR-0020). Mot vai tro cap phat kho cho thu kho khong nhat
	// thiet duoc phep tu nang quyen cua chinh minh bang cach gan them vai tro.
	//
	// Khong dung lai PermUserUpdate: PATCH /users/:id doi ten va so dien thoai, va gop hai
	// thu vao mot quyen nghia la moi vai tro sua duoc ho so deu mo rong duoc pham vi nhin
	// thay cua nguoi khac - dung lap luan da tach PermUserAssignRoles.
	PermUserAssignScopes = "auth.user_assign_scopes"
```

- [ ] **Bước 2: Tái xuất trong `module.go`**

Trong khối `const` tái xuất, thêm ngay dưới `PermUserAssignRoles = service.PermUserAssignRoles`:

```go
	PermUserAssignScopes   = service.PermUserAssignScopes
```

- [ ] **Bước 3: Cấp cho `admin` trong bảng vai trò**

Trong `cmd/internal/vaitro/vaitro.go`, khối `QuanTri`, thêm ngay dưới
`auth.PermUserAssignRoles`:

```go
			// Quyen CAP PHAM VI du lieu cho nguoi khac (ADR-0020). Chi admin cua phan vung
			// co no o chang nay: quan_tri_he_thong giu dung nam quyen PermCompany* theo
			// ADR-0019 muc 5, va viec mo them cho no la viec cua mot ADR rieng.
			auth.PermUserAssignScopes,
```

- [ ] **Bước 4: Kiểm dưới máy**

```powershell
go build ./... ; if ($?) { go run ./cmd/dev check }
```
Mong đợi: build không lỗi, `check` xanh.

- [ ] **Bước 5: Commit**

```bash
git add modules/auth/internal/service/permissions.go modules/auth/module.go cmd/internal/vaitro/vaitro.go
git commit -m "feat(auth): them permission auth.user_assign_scopes cho admin phan vung

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Danh mục loại phạm vi tiêm từ composition root

**Files:**
- Modify: `modules/auth/module.go` (kiểu mới + field `Deps`)
- Modify: `cmd/api/main.go` (khoảng dòng 184)
- Modify: `cmd/api/e2e_test.go` (khoảng dòng 118)

- [ ] **Bước 1: Khai kiểu `PhamViKhaDung` trong `module.go`**

Đặt ngay TRƯỚC `type Deps struct`. Import `"erp/shared/scope"` đã có sẵn trong file (dùng bởi
`ScopeDoc`).

```go
// PhamViKhaDung mo ta MOT loai pham vi ma he thong dang phuc vu, du de man hinh gan pham
// vi lam viec cua no ma module auth khong phai biet ten mot bang nghiep vu nao.
//
// Ba manh thong tin trong day den tu BA cho khac nhau va khong cho nao trong module auth
// biet du ca ba: nhan hien thi la chuyen cua giao dien, PermToanPham la hang cua module so
// huu tai nguyen (R-05 cam auth phu thuoc inventory), con Nguon la cai dat cua chinh module
// do. cmd/api la noi duy nhat biet ca ba - cung lap luan ADR-0010 dung cho vaitro.Bang().
type PhamViKhaDung struct {
	// Loai la nhan phia du lieu, dung gia tri luu o cot scope_type (vi du scope.Kho).
	Loai scope.Loai

	// Nhan la chu hien tren man hinh gan pham vi, vi du "Kho".
	Nhan string

	// PermToanPham tra loi "vai tro nay co bi gioi han theo tung ban ghi khong"
	// (ADR-0020 muc 4), vi du inventory.PermWarehouseScopeAll.
	PermToanPham string

	// Nguon liet ke moi id cua loai nay trong mot phan vung. Man hinh gan dung no de tu
	// choi mot id khong co that - lop bu duy nhat cho viec scope_id KHONG mang khoa ngoai
	// (ADR-0020 muc 2).
	Nguon scope.Nguon
}
```

- [ ] **Bước 2: Thêm field vào `Deps`**

Thêm vào cuối `type Deps struct`, trước dấu đóng ngoặc:

```go
	// LoaiPhamVi la danh muc loai pham vi dang phuc vu. Rong la hop le: he thong khi do
	// khong co loai nao gan duoc, va man hinh gan tra ve mot danh sach rong thay vi doan.
	//
	// Composition root phai dung danh sach nay DUNG MOT LAN roi dung cho ca scope.New lan
	// auth.New: hai ban sao la cho de chung lech nhau, va lech thi man hinh gan mot loai ma
	// Resolver khong biet loai do.
	LoaiPhamVi []PhamViKhaDung
```

- [ ] **Bước 3: Dựng danh sách một lần ở `cmd/api/main.go`**

Thay khối dựng `phamVi` hiện tại (`phamVi := scope.New(...)`) bằng:

```go
	// loaiPhamVi la danh muc loai pham vi dung DUNG MOT LAN cho ca hai phia: Resolver doc
	// nó để giải phạm vi lúc chạy, module auth đọc nó để dựng màn hình gán. Hai bản sao là
	// chỗ để chúng lệch nhau.
	loaiPhamVi := []auth.PhamViKhaDung{
		{
			Loai:         scope.Kho,
			Nhan:         "Kho",
			PermToanPham: inventory.PermWarehouseScopeAll,
			Nguon:        inventory.NguonKho(database),
		},
	}

	nguonTheoLoai := make(map[scope.Loai]scope.Nguon, len(loaiPhamVi))
	for _, l := range loaiPhamVi {
		nguonTheoLoai[l.Loai] = l.Nguon
	}

	phamVi := scope.New(kiemQuyen, auth.ScopeDoc(database), nguonTheoLoai)
```

Giữ nguyên khối comment dài đang đứng trên `phamVi` — nó vẫn đúng từng chữ.

- [ ] **Bước 4: Truyền vào `auth.New`**

Trong cùng file, thêm field vào lời gọi `auth.New(auth.Deps{...})`:

```go
		LoaiPhamVi: loaiPhamVi,
```

- [ ] **Bước 5: Làm y hệt trong `cmd/api/e2e_test.go`**

File đó dựng lại toàn bộ cây phụ thuộc cho test đầu-cuối. Thay khối `Scope: scope.New(...)`
của `inventory.New` và khối `auth.New` để cả hai dùng chung một danh sách, giống hệt
`main.go`. Không được để hai nơi lệch nhau — chính test đầu-cuối là thứ chứng minh chúng khớp.

- [ ] **Bước 6: Kiểm dưới máy**

```powershell
go build ./... ; if ($?) { go vet ./... }
```
Mong đợi: không lỗi. (`LoaiPhamVi` chưa ai đọc — đúng, Task 4 sẽ đọc.)

- [ ] **Bước 7: Commit**

```bash
git add modules/auth/module.go cmd/api/main.go cmd/api/e2e_test.go
git commit -m "feat(auth): tiem danh muc loai pham vi tu composition root

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Repository đọc/ghi phạm vi

**Files:**
- Create: `modules/auth/internal/repository/user_company_role_scope_repository.go`
- Modify: `modules/auth/internal/repository/user_company_repository.go`

- [ ] **Bước 1: Thêm `VaiTroTheoUser` vào interface `UserCompanyRepository`**

Trong `user_company_repository.go`, thêm vào interface, ngay dưới `RoleCodesTheoUser`:

```go
	// VaiTroTheoUser tra ve cac HANG vai tro con hieu luc cua mot nguoi trong mot phan
	// vung, kem chinh id cua tung hang.
	//
	// Khac RoleCodesTheoUser o dung mot cho, va cho do la ly do method nay ton tai: cau kia
	// GROUP BY role_code nen no lam mat id hang gan, ma Data Scope treo vao chinh id do
	// (ADR-0020 muc 1). Duong ky token can tap MA vai tro; man hinh gan pham vi can tap
	// HANG.
	VaiTroTheoUser(ctx context.Context, db sharedDB.DBTX, companyID, userID string) ([]model.UserCompanyRole, error)
```

- [ ] **Bước 2: Thêm câu SQL và cài đặt**

Thêm hằng SQL cạnh `selectRoleCodesTheoUserSQL`:

```go
// selectVaiTroTheoUserSQL doc cac HANG vai tro con hieu luc cua mot nguoi trong mot phan
// vung.
//
// KHONG co GROUP BY, khac han cau ngay tren: o day moi hang la mot don vi rieng - hai hang
// mang cung role_code (mot da thu hoi, mot con song) khong duoc gop, va bo loc soft delete
// da bo hang da thu hoi roi.
//
// KHONG co ORDER BY (R-09): khong index nao trong migration 000022 dat role_code o vi tri
// dan dau, va them mot index chi de sap xep vai dong da loc san la tra gia sai cho (R-07).
// Phep sap xep nam o Go.
const selectVaiTroTheoUserSQL = `
SELECT r.id, r.company_id, r.user_company_id, r.role_code,
       r.created_at, r.updated_at, r.deleted_at, r.created_by, r.updated_by
FROM user_company_roles r
JOIN user_companies c ON c.id = r.user_company_id AND c.deleted_at IS NULL
WHERE r.company_id = $1 AND c.user_id = $2 AND r.deleted_at IS NULL`
```

Và cài đặt, đặt ngay dưới `RoleCodesTheoUser`:

```go
// VaiTroTheoUser tra ve cac hang vai tro con hieu luc, da sap xep theo role_code de mot
// test so sanh duoc ket qua - phep sap xep nam o Go, xem khoi comment cua cau SQL.
func (r *userCompanyRepo) VaiTroTheoUser(ctx context.Context, db sharedDB.DBTX, companyID, userID string) ([]model.UserCompanyRole, error) {
	ra := []model.UserCompanyRole{}
	if err := db.SelectContext(ctx, &ra, selectVaiTroTheoUserSQL, companyID, userID); err != nil {
		return nil, fmt.Errorf("doc hang vai tro cua user %s: %w", userID, err)
	}
	sort.Slice(ra, func(i, j int) bool { return ra[i].RoleCode < ra[j].RoleCode })
	return ra, nil
}
```

- [ ] **Bước 3: Tạo `user_company_role_scope_repository.go`**

```go
package repository

import (
	"context"
	"fmt"
	"sort"

	"erp/modules/auth/internal/model"
	sharedDB "erp/shared/db"
)

// UserCompanyRoleScopeRepository la duong GHI cua bang user_company_role_scopes, va la
// nua con lai cua co che pham vi: scope_repository.go trong cung package doc bang nay de
// tra loi scope.Doc luc chay, file nay ghi no.
//
// # Vi sao khong gop vao scopeRepo cua scope_repository.go
//
// Vi hai duong co hai rang buoc khac han. scopeRepo BUOC phai giu mot handle trong struct
// - chu ky scope.Doc.IDsTheoActor khong co tham so db - va do la mot ngoai le co y thuc
// duoc thu hep den muc chi con doc. Duong ghi thi khong co rang buoc do: no nhan DBTX qua
// tham so nhu moi repository khac (C-GO-03), va phai nhu vay, vi mot lan thay pham vi gom
// nhieu cau lenh phai nam trong CUNG mot transaction cua service.
//
// Gop hai vai vao mot struct nghia la keo ngoai le kia sang ca duong ghi, tuc mo duong cho
// mot repository tu mo transaction sau lung service.
type UserCompanyRoleScopeRepository interface {
	// TheoUser tra moi dong pham vi con hieu luc cua mot nguoi trong mot phan vung, mọi
	// loai, moi hang vai tro. Nguoi goi gom theo UserCompanyRoleID.
	TheoUser(ctx context.Context, db sharedDB.DBTX, companyID, userID string) ([]model.UserCompanyRoleScope, error)

	// ThayPhamVi thay TOAN BO tap id cua MOT cap (hang vai tro, loai) bang tap moi.
	//
	// Ten theo hanh vi that su chu khong theo "Update" chung chung (C-GO-02), y het
	// ThayVaiTro: no khong hop nhat hai tap ma THAY han. Nguoi goi phai truyen tap DAY DU
	// cua cap do, khong phai phan chenh lech.
	//
	// Hai cau SQL cua no phai nam trong CUNG mot transaction cua nguoi goi: giua buoc thu
	// hoi va buoc cap lai, hang vai tro do khong co pham vi nao.
	ThayPhamVi(ctx context.Context, db sharedDB.DBTX, companyID, userCompanyRoleID, actorID, scopeType string, ids []string) error
}

// userCompanyRoleScopeRepo RONG nhu moi repository ghi khac cua package (C-GO-03).
type userCompanyRoleScopeRepo struct{}

// NewUserCompanyRoleScopeRepository tra ve INTERFACE chu khong tra ve con tro cu the
// (C-GO-02).
func NewUserCompanyRoleScopeRepository() UserCompanyRoleScopeRepository {
	return &userCompanyRoleScopeRepo{}
}

// --- Cau SQL ---
// Moi hang duoi day la MOT chuoi don theo C-GO-07: R-02, R-06, R-09 va R-18 deu trich cau
// nay ra bang AST de kiem.

// selectPhamViTheoUserSQL doc moi dong pham vi con hieu luc cua mot nguoi.
//
// Ba menh de `deleted_at IS NULL` deu phai co va khong menh de nao thay duoc menh de nao
// (R-18): mot hang pham vi con hieu luc treo tren mot vai tro da thu hoi, hoac tren mot
// hang gan da bi go, deu khong duoc tinh.
//
// `s.company_id = $1` doc thang tren bang la chu khong JOIN len cha de lay (R-06) - dung
// ly do cot company_id duoc giu lap lai o bang nay.
//
// KHONG co ORDER BY (R-09): index cua migration 000023 khong dat scope_id o vi tri dan
// dau. Phep sap xep nam o Go.
const selectPhamViTheoUserSQL = `
SELECT s.id, s.company_id, s.user_company_role_id, s.scope_type, s.scope_id,
       s.created_at, s.updated_at, s.deleted_at, s.created_by, s.updated_by
FROM user_company_role_scopes s
JOIN user_company_roles r ON r.id = s.user_company_role_id AND r.deleted_at IS NULL
JOIN user_companies     c ON c.id = r.user_company_id      AND c.deleted_at IS NULL
WHERE s.company_id = $1 AND c.user_id = $2 AND s.deleted_at IS NULL`

// softDeletePhamViSQL thu hoi TOAN BO pham vi dang con cua MOT cap (hang vai tro, loai).
//
// Xoa mem chu khong DELETE (R-18): "ai tung duoc cap kho nao" la cau ma mot cuoc ra soat
// quyen phai tra loi duoc, va mot hang bi xoa cung thi khong con cho nao tra loi.
//
// Khong dem RowsAffected: mot cap chua duoc cap gi van la dau vao hop le.
const softDeletePhamViSQL = `
UPDATE user_company_role_scopes SET deleted_at = now(), updated_at = now(), updated_by = $4
WHERE company_id = $1 AND user_company_role_id = $2 AND scope_type = $3 AND deleted_at IS NULL`

// insertPhamViSQL chen ca tap id moi trong DUNG mot cau lenh.
//
// `unnest($5::text[])::uuid` bien mot mang thanh N dong, y het insertVaiTroChoUserCompanySQL.
// Ep sang uuid la TUONG MINH chu khong dua vao ep ngam: cot scope_id la UUID, con tham so
// di xuong driver duoi dang text[].
//
// unnest nam trong mot subquery CO ALIAS chu khong dung thang sau FROM: bo kiem R-02 doc
// ten bang bang cach lay tu ngay sau FROM/JOIN, nen `FROM unnest(...)` bi doc thanh mot
// bang ten "unnest" - mot bang khong ai khai so huu.
//
// company_id lay tu CHINH hang user_company_roles doc lai, va menh de WHERE cua no la mot
// RANG BUOC that su: hang vai tro phai ton tai va con song thi pham vi moi duoc cap. Truyen
// thang $1 vao danh sach gia tri thi mot hang vai tro da bi thu hoi van nhan duoc pham vi
// moi - khoa ngoai chi doi hang TON TAI, no khong biet gi ve soft delete.
//
// Khong co ON CONFLICT: buoc xoa mem ngay truoc do da don sach cac hang con song cua chinh
// cap nay khoi partial unique index.
const insertPhamViSQL = `
INSERT INTO user_company_role_scopes (company_id, user_company_role_id, scope_type, scope_id, created_by, updated_by)
SELECT r.company_id, r.id, $3, moi.scope_id, $4::uuid, $4::uuid
FROM user_company_roles r
CROSS JOIN (SELECT unnest($5::text[])::uuid AS scope_id) AS moi
WHERE r.company_id = $1 AND r.id = $2 AND r.deleted_at IS NULL`

// TheoUser tra ve cac dong pham vi, da sap xep on dinh theo (hang vai tro, loai, id) de
// test so sanh duoc - phep sap xep nam o Go, xem khoi comment cua cau SQL.
func (r *userCompanyRoleScopeRepo) TheoUser(ctx context.Context, db sharedDB.DBTX, companyID, userID string) ([]model.UserCompanyRoleScope, error) {
	ra := []model.UserCompanyRoleScope{}
	if err := db.SelectContext(ctx, &ra, selectPhamViTheoUserSQL, companyID, userID); err != nil {
		return nil, fmt.Errorf("doc pham vi cua user %s: %w", userID, err)
	}
	sort.Slice(ra, func(i, j int) bool {
		if ra[i].UserCompanyRoleID != ra[j].UserCompanyRoleID {
			return ra[i].UserCompanyRoleID < ra[j].UserCompanyRoleID
		}
		if ra[i].ScopeType != ra[j].ScopeType {
			return ra[i].ScopeType < ra[j].ScopeType
		}
		return ra[i].ScopeID < ra[j].ScopeID
	})
	return ra, nil
}

// ThayPhamVi thu hoi het roi cap lai, trong DUNG hai cau lenh.
//
// Nguoi goi phai truyen tx: giua hai cau nay hang vai tro do khong co pham vi nao, va neu
// buoc thu hai hong ma buoc thu nhat da commit thi mot lan sua pham vi that bai vua tuoc
// sach quyen nhin cua mot nguoi.
func (r *userCompanyRoleScopeRepo) ThayPhamVi(ctx context.Context, db sharedDB.DBTX, companyID, userCompanyRoleID, actorID, scopeType string, ids []string) error {
	if _, err := db.ExecContext(ctx, softDeletePhamViSQL,
		companyID, userCompanyRoleID, scopeType, actorID); err != nil {
		return fmt.Errorf("thu hoi pham vi %q cua hang vai tro %s: %w", scopeType, userCompanyRoleID, err)
	}

	// Mang nil di xuong driver thanh NULL, va `unnest(NULL::text[])` cho ra khong hang
	// nao - dung ket qua mong muon. Van chuan hoa ve mang rong de cau lenh nhan mot gia
	// tri co that thay vi dua vao mot chuoi suy dien qua ba tang.
	moi := ids
	if moi == nil {
		moi = []string{}
	}
	if _, err := db.ExecContext(ctx, insertPhamViSQL,
		companyID, userCompanyRoleID, scopeType, actorID, moi); err != nil {
		return fmt.Errorf("cap pham vi %q cho hang vai tro %s: %w", scopeType, userCompanyRoleID, err)
	}
	return nil
}
```

- [ ] **Bước 4: Kiểm dưới máy**

```powershell
go build ./... ; if ($?) { go run ./cmd/dev arch }
```
Mong đợi: build không lỗi; `arch` xanh — đặc biệt R-02 (tên bảng đã khai trong
`modules/auth/module.yaml`), R-06, R-18 và C-GO-07 không được đỏ.

- [ ] **Bước 5: Commit**

```bash
git add modules/auth/internal/repository/
git commit -m "feat(auth): repository doc va thay pham vi cua hang vai tro

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: `ScopeService.PhamViTheoUser` (đường đọc)

**Files:**
- Create: `modules/auth/internal/service/scope_service.go`
- Create: `modules/auth/internal/service/scope_service_test.go`

- [ ] **Bước 1: Viết test trước — file `scope_service_test.go`**

```go
package service_test

import (
	"context"
	"net/http"
	"testing"

	"github.com/google/uuid"
	"github.com/jmoiron/sqlx"

	"erp/internal/testutil"
	"erp/modules/auth/internal/repository"
	"erp/modules/auth/internal/service"
	"erp/shared/audit"
	"erp/shared/auth"
	"erp/shared/authz"
	"erp/shared/scope"
)

// File nay test ScopeService tren PostgreSQL that qua testutil.Connect, dung ly do da ghi
// o dau user_service_test.go: service tu mo transaction bang s.db.BeginTxx va nhan lai
// *sqlx.Tx - mot struct cu the - nen khong co cho nao cam mot fake vao giua.
//
// Thu DUY NHAT duoc gia o day la scope.Nguon: no la mot interface do shared/scope dinh
// nghia, va cai dat that cua no nam trong modules/inventory - thu module auth khong duoc
// import (R-05, allowed_deps: []).

const (
	vaiTroThuKho   = "thu_kho"
	vaiTroXemHetKho = "xem_het_kho"
	vaiTroKhongQuyen = "khong_quyen"

	// permKhoToanPham la ban sao cua inventory.PermWarehouseScopeAll DUNG CHO TEST NAY.
	// Khong import hang that: R-05 cam modules/auth phu thuoc modules/inventory, va chinh
	// viec chuoi nay la THAM SO chu khong phai hang cua auth la dieu dang duoc kiem.
	permKhoToanPham = "inventory.warehouse_scope_all"
)

// nguonGia cai dat scope.Nguon bang mot tap id da biet truoc.
type nguonGia struct{ ids []string }

func (n nguonGia) IDsTrongPhanVung(_ context.Context, _ string, _ scope.Loai) ([]string, error) {
	return n.ids, nil
}

// dungScopeService dung service that voi repository that va mot bang phan quyen nho.
func dungScopeService(db *sqlx.DB, khoTrongPhanVung []string) *service.ScopeService {
	return service.NewScopeService(service.ScopeDeps{
		DB: db,
		Authz: authz.New(authz.Bang{
			vaiTroQuanTri: {
				service.PermUserRead,
				service.PermUserAssignScopes,
			},
			// vaiTroThuKho bi gioi han theo tung kho: no KHONG co permKhoToanPham.
			vaiTroThuKho: {},
			// vaiTroXemHetKho thay moi kho, nen man hinh gan phai bao "toan pham vi".
			vaiTroXemHetKho:  {permKhoToanPham},
			vaiTroKhongQuyen: {},
		}),
		AuditRepo:       audit.NewPostgres(),
		UserCompanyRepo: repository.NewUserCompanyRepository(),
		ScopeRepo:       repository.NewUserCompanyRoleScopeRepository(),
		LoaiPhamVi: []service.LoaiPhamVi{{
			Loai:         scope.Kho,
			Nhan:         "Kho",
			PermToanPham: permKhoToanPham,
			Nguon:        nguonGia{ids: khoTrongPhanVung},
		}},
	})
}

// themNguoiCoVaiTro chen mot user, mot hang gan va cac hang vai tro, roi tra id user.
//
// Chen thang bang SQL chu khong goi UserService: file nay do ScopeService, va di qua mot
// service khac de chuan bi du lieu lam mot loi o ben kia hien ra thanh mot loi o ben nay.
func themNguoiCoVaiTro(t *testing.T, db *sqlx.DB, companyID, email string, vaiTro ...string) string {
	t.Helper()
	userID := uuid.NewString()
	nguoi := uuid.NewString()

	if _, err := db.Exec(`
		INSERT INTO users (id, company_id, email, password_hash, full_name, is_active, created_by, updated_by)
		VALUES ($1, $2, $3, 'x', 'Nguoi test', true, $4, $4)`,
		userID, companyID, email, nguoi); err != nil {
		t.Fatalf("chen user %q: %v", email, err)
	}

	ucID := uuid.NewString()
	if _, err := db.Exec(`
		INSERT INTO user_companies (id, company_id, user_id, created_by, updated_by)
		VALUES ($1, $2, $3, $4, $4)`, ucID, companyID, userID, nguoi); err != nil {
		t.Fatalf("chen hang gan cua %q: %v", email, err)
	}

	if _, err := db.Exec(`
		INSERT INTO user_company_roles (company_id, user_company_id, role_code, created_by, updated_by)
		SELECT $1, $2, moi.role_code, $3, $3 FROM (SELECT unnest($4::text[]) AS role_code) AS moi`,
		companyID, ucID, nguoi, vaiTro); err != nil {
		t.Fatalf("gan vai tro cho %q: %v", email, err)
	}
	return userID
}

func TestScopeService_PhamViTheoUser_ThieuQuyenThiTuChoi(t *testing.T) {
	svc := dungScopeService(nil, nil)

	_, err := svc.PhamViTheoUser(context.Background(),
		auth.Actor{UserID: uuid.NewString(), CompanyID: uuid.NewString(), Roles: []string{vaiTroKhongQuyen}},
		uuid.NewString())
	if err == nil {
		t.Fatal("actor khong co PermUserRead van doc duoc pham vi cua nguoi khac")
	}
	_, status := maLoi(t, err)
	if status != http.StatusForbidden {
		t.Fatalf("status = %d, muon 403", status)
	}
}

func TestScopeService_PhamViTheoUser_NguoiKhongThuocPhanVung_Tra404(t *testing.T) {
	db := testutil.Connect(t)
	congTy := congTyMacDinh(t, db)
	svc := dungScopeService(db, nil)

	_, err := svc.PhamViTheoUser(context.Background(), actorQuanTri(congTy), uuid.NewString())
	if err == nil {
		t.Fatal("doc duoc pham vi cua mot user khong ton tai")
	}
	_, status := maLoi(t, err)
	if status != http.StatusNotFound {
		t.Fatalf("status = %d, muon 404", status)
	}
}

func TestScopeService_PhamViTheoUser_ChuaGanGi_TraDanhSachRong(t *testing.T) {
	db := testutil.Connect(t)
	congTy := congTyMacDinh(t, db)
	kho := uuid.NewString()
	svc := dungScopeService(db, []string{kho})

	userID := themNguoiCoVaiTro(t, db, congTy, "thukho@vidu.com", vaiTroThuKho)

	ra, err := svc.PhamViTheoUser(context.Background(), actorQuanTri(congTy), userID)
	if err != nil {
		t.Fatalf("doc pham vi: %v", err)
	}
	if len(ra.VaiTro) != 1 {
		t.Fatalf("so hang vai tro = %d, muon 1", len(ra.VaiTro))
	}
	if len(ra.VaiTro[0].PhamVi) != 1 {
		t.Fatalf("so loai pham vi = %d, muon 1 - moi loai trong danh muc phai co mat", len(ra.VaiTro[0].PhamVi))
	}
	pv := ra.VaiTro[0].PhamVi[0]
	if pv.ToanPhamVi {
		t.Error("vai tro khong co permission toan pham vi ma bao toan pham vi")
	}
	if len(pv.IDs) != 0 {
		t.Errorf("IDs = %v, muon rong - chua gan gi nghia la KHONG THAY GI", pv.IDs)
	}
	if pv.Nhan != "Kho" {
		t.Errorf("Nhan = %q, muon \"Kho\"", pv.Nhan)
	}
}

func TestScopeService_PhamViTheoUser_VaiTroToanPhamVi_BaoToanPhamVi(t *testing.T) {
	db := testutil.Connect(t)
	congTy := congTyMacDinh(t, db)
	svc := dungScopeService(db, []string{uuid.NewString()})

	userID := themNguoiCoVaiTro(t, db, congTy, "xemhet@vidu.com", vaiTroXemHetKho)

	ra, err := svc.PhamViTheoUser(context.Background(), actorQuanTri(congTy), userID)
	if err != nil {
		t.Fatalf("doc pham vi: %v", err)
	}
	if !ra.VaiTro[0].PhamVi[0].ToanPhamVi {
		t.Fatal("vai tro mang permission toan pham vi ma khong duoc bao la toan pham vi")
	}
}

func TestScopeService_PhamViTheoUser_HaiVaiTro_HaiBoPhamVi(t *testing.T) {
	db := testutil.Connect(t)
	congTy := congTyMacDinh(t, db)
	svc := dungScopeService(db, []string{uuid.NewString()})

	userID := themNguoiCoVaiTro(t, db, congTy, "haivaitro@vidu.com", vaiTroThuKho, vaiTroXemHetKho)

	ra, err := svc.PhamViTheoUser(context.Background(), actorQuanTri(congTy), userID)
	if err != nil {
		t.Fatalf("doc pham vi: %v", err)
	}
	if len(ra.VaiTro) != 2 {
		t.Fatalf("so hang vai tro = %d, muon 2 - mot nguoi hai vai tro co HAI bo pham vi tach biet (ADR-0020 muc 1)", len(ra.VaiTro))
	}
	if ra.VaiTro[0].UserCompanyRoleID == ra.VaiTro[1].UserCompanyRoleID {
		t.Fatal("hai hang vai tro mang cung mot id")
	}
}
```

- [ ] **Bước 2: Chạy test để thấy nó hỏng**

Dưới máy chỉ chạy được bước biên dịch:

```powershell
go vet ./modules/auth/...
```
Mong đợi: LỖI biên dịch — `undefined: service.NewScopeService`, `undefined: service.ScopeDeps`.
Đó đúng là trạng thái "test đỏ" ở bước này.

- [ ] **Bước 3: Viết `scope_service.go` — phần khung và đường đọc**

```go
package service

import (
	"context"
	"sort"

	"github.com/jmoiron/sqlx"

	"erp/modules/auth/internal/repository"
	"erp/shared/audit"
	"erp/shared/auth"
	"erp/shared/authz"
	sharedDB "erp/shared/db"
	"erp/shared/scope"
)

// LoaiPhamVi la MOT loai pham vi ma service nay phuc vu, tiem tu composition root.
//
// Ban sao cua auth.PhamViKhaDung o package goc chu khong dung chung mot kieu, y het cach
// TaoUserInput o module.go la ban sao co chu dich cua CreateUserInput: package goc la hop
// dong voi cmd/**, package nay la chi tiet trien khai, va hai thu do khong duoc dinh vao
// nhau.
type LoaiPhamVi struct {
	Loai         scope.Loai
	Nhan         string
	PermToanPham string
	Nguon        scope.Nguon
}

// ScopeDeps la phu thuoc cua ScopeService.
//
// Ten khong phai Deps vi package nay da co UserDeps, AuthDeps va CompanyDeps - bon struct
// Deps trong cung mot package thi khong cung ton tai duoc.
type ScopeDeps struct {
	DB              *sqlx.DB
	Authz           authz.Checker
	AuditRepo       audit.Repository
	UserCompanyRepo repository.UserCompanyRepository
	ScopeRepo       repository.UserCompanyRoleScopeRepository

	// LoaiPhamVi rong la hop le: he thong khi do khong co loai nao gan duoc, va PhamViTheoUser
	// tra ve moi hang vai tro voi mot danh sach pham vi rong thay vi doan ra mot loai nao.
	LoaiPhamVi []LoaiPhamVi
}

// ScopeService so huu duong GAN pham vi du lieu: no tra loi "hang vai tro nay duoc cham
// toi nhung ban ghi nao" va no la duong duy nhat ghi vao user_company_role_scopes.
//
// Tach khoi UserService chu khong them hai method vao do: hai service khong dung chung
// mot phu thuoc nao ngoai db, authz va audit; UserService da hon chin tram dong; va gan
// vai tro voi gan pham vi la hai thao tac di qua hai permission khac nhau (ADR-0020 muc 4
// tach chung o tang quyen, nen tang service tach theo).
type ScopeService struct {
	db              *sqlx.DB
	authz           authz.Checker
	auditRepo       audit.Repository
	userCompanyRepo repository.UserCompanyRepository
	scopeRepo       repository.UserCompanyRoleScopeRepository
	loaiPhamVi      []LoaiPhamVi
}

// NewScopeService dung ScopeService tu cac phu thuoc da tiem.
func NewScopeService(d ScopeDeps) *ScopeService {
	return &ScopeService{
		db:              d.DB,
		authz:           d.Authz,
		auditRepo:       d.AuditRepo,
		userCompanyRepo: d.UserCompanyRepo,
		scopeRepo:       d.ScopeRepo,
		loaiPhamVi:      d.LoaiPhamVi,
	}
}

// PhamViCuaUser la hinh dang tra ve cua ca hai method: doc va ghi tra ve cung mot buc anh,
// nen man hinh khong phai goi lai sau khi luu.
type PhamViCuaUser struct {
	UserID string
	VaiTro []PhamViTheoVaiTro
}

// PhamViTheoVaiTro la bo pham vi cua DUNG MOT hang user_company_roles.
//
// Khong gom theo nguoi, va do la toan bo diem cua ADR-0020 muc 1: mot nguoi mang hai vai
// tro trong cung mot phan vung co HAI bo pham vi tach biet.
type PhamViTheoVaiTro struct {
	UserCompanyRoleID string
	RoleCode          string
	PhamVi            []PhamViTheoLoai
}

// PhamViTheoLoai la tap id cua MOT loai, trong MOT hang vai tro.
type PhamViTheoLoai struct {
	Loai string
	Nhan string

	// ToanPhamVi la mot TRANG THAI RIENG chu khong phai "da chon tat ca": vai tro nay khong
	// bi gioi han theo tung ban ghi vi no mang permission toan pham vi (ADR-0020 muc 4), nen
	// IDs cua no luon rong va khong gan duoc gi vao.
	ToanPhamVi bool

	// IDs rong nghia la KHONG THAY GI, khong bao gio nghia la tat ca - luat cung cua
	// shared/scope, va cung la mac dinh fail-close cua ADR-0020 muc 3.
	IDs []string
}

// PhamViTheoUser tra ve toan bo buc anh pham vi cua mot nguoi trong phan vung cua actor.
func (s *ScopeService) PhamViTheoUser(ctx context.Context, actor auth.Actor, userID string) (*PhamViCuaUser, error) {
	if err := s.authz.Can(ctx, actor, PermUserRead); err != nil {
		return nil, err
	}
	if !laUUID(userID) {
		return nil, loiKhongTonTai()
	}
	return s.docPhamVi(ctx, s.db, actor, userID)
}

// docPhamVi dung buc anh pham vi tu hai lan doc. Nhan DBTX chu khong dung s.db truc tiep:
// duong ghi goi lai chinh no BEN TRONG transaction de tra ve ket qua vua ghi.
func (s *ScopeService) docPhamVi(ctx context.Context, db sharedDB.DBTX, actor auth.Actor, userID string) (*PhamViCuaUser, error) {
	hangVaiTro, err := s.userCompanyRepo.VaiTroTheoUser(ctx, db, actor.CompanyID, userID)
	if err != nil {
		return nil, err
	}
	if len(hangVaiTro) == 0 {
		// Khong hang vai tro nao co the co hai nghia: nguoi do khong thuoc phan vung, hoac
		// thuoc ma chua duoc gan vai tro nao. Phan biet bang mot lan doc hang gan - man hinh
		// phai noi duoc "chua co vai tro nao, gan vai tro truoc" thay vi mot 404 chung chung.
		if _, err := s.userCompanyRepo.IDTheoUser(ctx, db, actor.CompanyID, userID); err != nil {
			return nil, loiKhongTonTai()
		}
	}

	dong, err := s.scopeRepo.TheoUser(ctx, db, actor.CompanyID, userID)
	if err != nil {
		return nil, err
	}

	// Gom id theo cap (hang vai tro, loai). Khu trung o day chu khong o SQL: tap nho, va mot
	// GROUP BY tren cot khong dan dau index nao khong mua duoc gi.
	theoCap := map[string][]string{}
	for _, d := range dong {
		khoa := d.UserCompanyRoleID + "\x00" + d.ScopeType
		theoCap[khoa] = append(theoCap[khoa], d.ScopeID)
	}

	ra := &PhamViCuaUser{UserID: userID, VaiTro: make([]PhamViTheoVaiTro, 0, len(hangVaiTro))}
	for _, h := range hangVaiTro {
		muc := PhamViTheoVaiTro{
			UserCompanyRoleID: h.ID,
			RoleCode:          h.RoleCode,
			PhamVi:            make([]PhamViTheoLoai, 0, len(s.loaiPhamVi)),
		}
		for _, l := range s.loaiPhamVi {
			toanPham := s.vaiTroToanPhamVi(ctx, actor.CompanyID, h.RoleCode, l.PermToanPham)
			ids := []string{}
			if !toanPham {
				ids = theoCap[h.ID+"\x00"+string(l.Loai)]
				if ids == nil {
					ids = []string{}
				}
				sort.Strings(ids)
			}
			muc.PhamVi = append(muc.PhamVi, PhamViTheoLoai{
				Loai:       string(l.Loai),
				Nhan:       l.Nhan,
				ToanPhamVi: toanPham,
				IDs:        ids,
			})
		}
		ra.VaiTro = append(ra.VaiTro, muc)
	}
	return ra, nil
}

// vaiTroToanPhamVi hoi bang phan quyen: MOT vai tro co mang permission toan pham vi khong.
//
// # Vi sao dung mot auth.Actor dung tai cho
//
// Cau hoi o day khong phai "actor nay co duoc lam gi" ma "cai TEN vai tro nay co quyen gi",
// va authz.Checker chi co mot cua tra loi duoc dieu do la Can - no tra cuu tren truong Roles
// va khong doc gi khac. Them mot method vao shared/authz de hoi thang la mo mot API thu hai
// cho cung mot bang, dung dieu ghi chu dau shared/authz/authz.go da cam.
//
// Gia tri nay KHONG cho phep dieu gi: no chi di vao mot bao cao doc ra man hinh, de nguoi
// gan biet vai tro nao khong can gan pham vi. Moi lan CHO PHEP that su van di qua actor tu
// token, o cau lenh dau tien cua method public (R-15).
func (s *ScopeService) vaiTroToanPhamVi(ctx context.Context, companyID, roleCode, permToanPham string) bool {
	if permToanPham == "" {
		return false
	}
	hoi := auth.Actor{CompanyID: companyID, Roles: []string{roleCode}}
	return s.authz.Can(ctx, hoi, permToanPham) == nil
}
```

- [ ] **Bước 4: Kiểm dưới máy**

```powershell
go build ./... ; if ($?) { go vet ./... }
```
Mong đợi: không lỗi. Ba hằng `actionUserScopeUpdated`, `tranSoIDMoiLoai`, `fieldPhamVi` và
ba import `fmt` / `apperr` / `requestid` **chưa có mặt ở bước này** — Task 5 thêm chúng cùng
lúc với code dùng tới, để không có ký hiệu nào đứng không.

- [ ] **Bước 5: Đẩy nhánh và đọc CI**

```bash
git add modules/auth/internal/service/
git commit -m "feat(auth): ScopeService doc pham vi theo tung hang vai tro

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
git push -u origin feat/gan-data-scope
```
Mong đợi trên CI: năm test `TestScopeService_PhamViTheoUser_*` XANH. Không được tuyên bố
"xong" trước khi nhìn thấy kết quả đó.

---

## Task 5: `ScopeService.ThayPhamVi` (đường ghi)

**Files:**
- Modify: `modules/auth/internal/service/scope_service.go`
- Modify: `modules/auth/internal/service/scope_service_test.go`

- [ ] **Bước 1: Viết test trước — thêm vào cuối `scope_service_test.go`**

```go
// docHangVaiTro tra id cac hang vai tro cua mot nguoi, de test dung duoc dau vao cua
// ThayPhamVi ma khong phai doan.
func docHangVaiTro(t *testing.T, svc *service.ScopeService, actor auth.Actor, userID string) []service.PhamViTheoVaiTro {
	t.Helper()
	ra, err := svc.PhamViTheoUser(context.Background(), actor, userID)
	if err != nil {
		t.Fatalf("chuan bi: doc pham vi: %v", err)
	}
	return ra.VaiTro
}

func TestScopeService_ThayPhamVi_ThieuQuyenThiTuChoi(t *testing.T) {
	svc := dungScopeService(nil, nil)

	_, err := svc.ThayPhamVi(context.Background(),
		auth.Actor{UserID: uuid.NewString(), CompanyID: uuid.NewString(), Roles: []string{vaiTroKhongQuyen}},
		service.ThayPhamViInput{UserID: uuid.NewString()})
	if err == nil {
		t.Fatal("actor khong co PermUserAssignScopes van gan duoc pham vi")
	}
	_, status := maLoi(t, err)
	if status != http.StatusForbidden {
		t.Fatalf("status = %d, muon 403", status)
	}
}

func TestScopeService_ThayPhamVi_GanRoiDocLai(t *testing.T) {
	db := testutil.Connect(t)
	congTy := congTyMacDinh(t, db)
	khoA, khoB := uuid.NewString(), uuid.NewString()
	svc := dungScopeService(db, []string{khoA, khoB})
	actor := actorQuanTri(congTy)

	userID := themNguoiCoVaiTro(t, db, congTy, "gan@vidu.com", vaiTroThuKho)
	hang := docHangVaiTro(t, svc, actor, userID)

	ra, err := svc.ThayPhamVi(context.Background(), actor, service.ThayPhamViInput{
		UserID: userID,
		VaiTro: []service.ThayPhamViVaiTro{{
			UserCompanyRoleID: hang[0].UserCompanyRoleID,
			PhamVi:            []service.ThayPhamViLoai{{Loai: string(scope.Kho), IDs: []string{khoA}}},
		}},
	})
	if err != nil {
		t.Fatalf("gan pham vi: %v", err)
	}
	if got := ra.VaiTro[0].PhamVi[0].IDs; len(got) != 1 || got[0] != khoA {
		t.Fatalf("IDs sau khi gan = %v, muon [%s]", got, khoA)
	}

	// Doc lai bang mot loi goi rieng: gia tri tra ve cua ThayPhamVi phai la thu DA NAM
	// trong database, khong phai thu vua nhan tu request.
	lai, err := svc.PhamViTheoUser(context.Background(), actor, userID)
	if err != nil {
		t.Fatalf("doc lai: %v", err)
	}
	if got := lai.VaiTro[0].PhamVi[0].IDs; len(got) != 1 || got[0] != khoA {
		t.Fatalf("IDs doc lai = %v, muon [%s]", got, khoA)
	}
}

func TestScopeService_ThayPhamVi_ThayHanChuKhongHopNhat(t *testing.T) {
	db := testutil.Connect(t)
	congTy := congTyMacDinh(t, db)
	khoA, khoB := uuid.NewString(), uuid.NewString()
	svc := dungScopeService(db, []string{khoA, khoB})
	actor := actorQuanTri(congTy)

	userID := themNguoiCoVaiTro(t, db, congTy, "thay@vidu.com", vaiTroThuKho)
	hangID := docHangVaiTro(t, svc, actor, userID)[0].UserCompanyRoleID

	gan := func(ids []string) *service.PhamViCuaUser {
		t.Helper()
		ra, err := svc.ThayPhamVi(context.Background(), actor, service.ThayPhamViInput{
			UserID: userID,
			VaiTro: []service.ThayPhamViVaiTro{{
				UserCompanyRoleID: hangID,
				PhamVi:            []service.ThayPhamViLoai{{Loai: string(scope.Kho), IDs: ids}},
			}},
		})
		if err != nil {
			t.Fatalf("gan %v: %v", ids, err)
		}
		return ra
	}

	gan([]string{khoA})
	ra := gan([]string{khoB})
	if got := ra.VaiTro[0].PhamVi[0].IDs; len(got) != 1 || got[0] != khoB {
		t.Fatalf("IDs = %v, muon dung [%s] - PUT THAY han chu khong hop nhat", got, khoB)
	}

	// Tap RONG la dau vao hop le: no thu hoi sach, va nguoi do se thay man hinh trong
	// (ADR-0020 muc 3).
	ra = gan([]string{})
	if got := ra.VaiTro[0].PhamVi[0].IDs; len(got) != 0 {
		t.Fatalf("IDs = %v, muon rong", got)
	}
}

func TestScopeService_ThayPhamVi_ThieuMotHangVaiTro_Tra409(t *testing.T) {
	db := testutil.Connect(t)
	congTy := congTyMacDinh(t, db)
	svc := dungScopeService(db, []string{uuid.NewString()})
	actor := actorQuanTri(congTy)

	userID := themNguoiCoVaiTro(t, db, congTy, "thieu@vidu.com", vaiTroThuKho, vaiTroXemHetKho)
	hang := docHangVaiTro(t, svc, actor, userID)

	// Gui DUY NHAT mot hang trong khi nguoi do co hai.
	_, err := svc.ThayPhamVi(context.Background(), actor, service.ThayPhamViInput{
		UserID: userID,
		VaiTro: []service.ThayPhamViVaiTro{{
			UserCompanyRoleID: hang[0].UserCompanyRoleID,
			PhamVi:            []service.ThayPhamViLoai{{Loai: string(scope.Kho), IDs: []string{}}},
		}},
	})
	if err == nil {
		t.Fatal("gui thieu mot hang vai tro ma van ghi duoc - bo pham vi cua hang con lai bi bo qua im lang")
	}
	_, status := maLoi(t, err)
	if status != http.StatusConflict {
		t.Fatalf("status = %d, muon 409", status)
	}
}

func TestScopeService_ThayPhamVi_HangVaiTroLa_Tra409(t *testing.T) {
	db := testutil.Connect(t)
	congTy := congTyMacDinh(t, db)
	svc := dungScopeService(db, []string{uuid.NewString()})
	actor := actorQuanTri(congTy)

	userID := themNguoiCoVaiTro(t, db, congTy, "hangla@vidu.com", vaiTroThuKho)

	_, err := svc.ThayPhamVi(context.Background(), actor, service.ThayPhamViInput{
		UserID: userID,
		VaiTro: []service.ThayPhamViVaiTro{{
			UserCompanyRoleID: uuid.NewString(), // khong thuoc nguoi nay
			PhamVi:            []service.ThayPhamViLoai{{Loai: string(scope.Kho), IDs: []string{}}},
		}},
	})
	if err == nil {
		t.Fatal("gan duoc pham vi cho mot hang vai tro khong thuoc nguoi nay")
	}
	_, status := maLoi(t, err)
	if status != http.StatusConflict {
		t.Fatalf("status = %d, muon 409", status)
	}
}

func TestScopeService_ThayPhamVi_ThieuMotLoai_Tra422(t *testing.T) {
	db := testutil.Connect(t)
	congTy := congTyMacDinh(t, db)
	svc := dungScopeService(db, []string{uuid.NewString()})
	actor := actorQuanTri(congTy)

	userID := themNguoiCoVaiTro(t, db, congTy, "thieuloai@vidu.com", vaiTroThuKho)
	hangID := docHangVaiTro(t, svc, actor, userID)[0].UserCompanyRoleID

	_, err := svc.ThayPhamVi(context.Background(), actor, service.ThayPhamViInput{
		UserID: userID,
		VaiTro: []service.ThayPhamViVaiTro{{UserCompanyRoleID: hangID, PhamVi: nil}},
	})
	if err == nil {
		t.Fatal("gui thieu mot loai pham vi ma van ghi duoc - loai do bi giu nguyen im lang")
	}
	_, status := maLoi(t, err)
	if status != http.StatusUnprocessableEntity {
		t.Fatalf("status = %d, muon 422", status)
	}
}

func TestScopeService_ThayPhamVi_LoaiLa_Tra422(t *testing.T) {
	db := testutil.Connect(t)
	congTy := congTyMacDinh(t, db)
	svc := dungScopeService(db, []string{uuid.NewString()})
	actor := actorQuanTri(congTy)

	userID := themNguoiCoVaiTro(t, db, congTy, "loaila@vidu.com", vaiTroThuKho)
	hangID := docHangVaiTro(t, svc, actor, userID)[0].UserCompanyRoleID

	_, err := svc.ThayPhamVi(context.Background(), actor, service.ThayPhamViInput{
		UserID: userID,
		VaiTro: []service.ThayPhamViVaiTro{{
			UserCompanyRoleID: hangID,
			PhamVi: []service.ThayPhamViLoai{
				{Loai: string(scope.Kho), IDs: []string{}},
				{Loai: "khach_hang", IDs: []string{}},
			},
		}},
	})
	if err == nil {
		t.Fatal("ghi duoc mot loai pham vi khong co trong danh muc")
	}
	_, status := maLoi(t, err)
	if status != http.StatusUnprocessableEntity {
		t.Fatalf("status = %d, muon 422", status)
	}
}

func TestScopeService_ThayPhamVi_IDKhongCoTrongPhanVung_Tra422(t *testing.T) {
	db := testutil.Connect(t)
	congTy := congTyMacDinh(t, db)
	khoThat := uuid.NewString()
	svc := dungScopeService(db, []string{khoThat})
	actor := actorQuanTri(congTy)

	userID := themNguoiCoVaiTro(t, db, congTy, "idla@vidu.com", vaiTroThuKho)
	hangID := docHangVaiTro(t, svc, actor, userID)[0].UserCompanyRoleID

	_, err := svc.ThayPhamVi(context.Background(), actor, service.ThayPhamViInput{
		UserID: userID,
		VaiTro: []service.ThayPhamViVaiTro{{
			UserCompanyRoleID: hangID,
			PhamVi:            []service.ThayPhamViLoai{{Loai: string(scope.Kho), IDs: []string{uuid.NewString()}}},
		}},
	})
	if err == nil {
		t.Fatal("gan duoc mot id khong ton tai trong phan vung - lop bu duy nhat cho viec scope_id khong co khoa ngoai da mat")
	}
	_, status := maLoi(t, err)
	if status != http.StatusUnprocessableEntity {
		t.Fatalf("status = %d, muon 422", status)
	}
}

func TestScopeService_ThayPhamVi_VaiTroToanPhamViMaGanID_Tra422(t *testing.T) {
	db := testutil.Connect(t)
	congTy := congTyMacDinh(t, db)
	kho := uuid.NewString()
	svc := dungScopeService(db, []string{kho})
	actor := actorQuanTri(congTy)

	userID := themNguoiCoVaiTro(t, db, congTy, "toanpham@vidu.com", vaiTroXemHetKho)
	hangID := docHangVaiTro(t, svc, actor, userID)[0].UserCompanyRoleID

	_, err := svc.ThayPhamVi(context.Background(), actor, service.ThayPhamViInput{
		UserID: userID,
		VaiTro: []service.ThayPhamViVaiTro{{
			UserCompanyRoleID: hangID,
			PhamVi:            []service.ThayPhamViLoai{{Loai: string(scope.Kho), IDs: []string{kho}}},
		}},
	})
	if err == nil {
		t.Fatal("gan duoc pham vi cho mot vai tro von thay tat ca - dong scope do la du lieu chet")
	}
	_, status := maLoi(t, err)
	if status != http.StatusUnprocessableEntity {
		t.Fatalf("status = %d, muon 422", status)
	}
}

func TestScopeService_ThayPhamVi_GhiAuditMotDong(t *testing.T) {
	db := testutil.Connect(t)
	congTy := congTyMacDinh(t, db)
	kho := uuid.NewString()
	svc := dungScopeService(db, []string{kho})
	actor := actorQuanTri(congTy)

	userID := themNguoiCoVaiTro(t, db, congTy, "audit@vidu.com", vaiTroThuKho)
	hangID := docHangVaiTro(t, svc, actor, userID)[0].UserCompanyRoleID

	if _, err := svc.ThayPhamVi(context.Background(), actor, service.ThayPhamViInput{
		UserID: userID,
		VaiTro: []service.ThayPhamViVaiTro{{
			UserCompanyRoleID: hangID,
			PhamVi:            []service.ThayPhamViLoai{{Loai: string(scope.Kho), IDs: []string{kho}}},
		}},
	}); err != nil {
		t.Fatalf("gan pham vi: %v", err)
	}

	var dem int
	if err := db.Get(&dem, `
		SELECT count(*) FROM audit_logs
		WHERE company_id = $1 AND entity_id = $2 AND action = 'user_scope.updated'`,
		congTy, userID); err != nil {
		t.Fatalf("dem audit: %v", err)
	}
	if dem != 1 {
		t.Fatalf("so dong audit = %d, muon 1", dem)
	}
}
```

- [ ] **Bước 2: Chạy để thấy hỏng**

```powershell
go vet ./modules/auth/...
```
Mong đợi: LỖI biên dịch — `undefined: service.ThayPhamViInput`, `service.ThayPhamViVaiTro`,
`service.ThayPhamViLoai`, và `svc.ThayPhamVi`.

- [ ] **Bước 3: Viết đường ghi trong `scope_service.go`**

Thêm import `"github.com/jmoiron/sqlx"`, `"fmt"`, `apperr "erp/shared/errors"`,
`"erp/shared/requestid"` nếu chưa có. Thêm vào cuối file:

```go
// Ten hanh dong ghi vao audit_logs.action, dang `<thuc the>.<hanh dong o the qua khu>` nhu
// user.created / user.updated / user.deleted.
const actionUserScopeUpdated = "user_scope.updated"

// tranSoIDMoiLoai la tran so id gan duoc cho MOT cap (hang vai tro, loai).
//
// ADR-0020 muc 5 chot resolver luon tra ve mot danh sach id CU THE, va ghi ngay o phan No de
// lai rang menh de do "chi dung khi luc luong cua tap nho". Con so nay la hang rao cho dieu
// kien do: no khong phai mot gioi han nghiep vu, no la cho de he thong keu len truoc khi ai
// do gan mot van kho vao mot vai tro.
const tranSoIDMoiLoai = 500

// fieldPhamVi la ten o dung trong loi 422 cua duong nay - form to duoc dung cho.
const fieldPhamVi = "vai_tro"

// ThayPhamViInput la dau vao THO cua ThayPhamVi.
//
// Khong co CompanyID (R-06): phan vung lay tu actor.CompanyID, nen mot field o day la moi
// de nguoi ta lay gia tri tu request thay vi tu token.
type ThayPhamViInput struct {
	UserID string

	// VaiTro phai liet ke DU VA DUNG tap hang vai tro con song cua nguoi do. Xem
	// kiemDuHangVaiTro.
	VaiTro []ThayPhamViVaiTro
}

// ThayPhamViVaiTro la bo pham vi moi cua DUNG MOT hang vai tro.
type ThayPhamViVaiTro struct {
	UserCompanyRoleID string

	// PhamVi phai liet ke DU moi loai trong danh muc. Thieu mot loai la 422 chu khong phai
	// "giu nguyen loai do": mot PUT thay toan bo ma im lang giu lai mot phan la dung kieu
	// hong ve phia MO ma ADR-0020 da tu choi.
	PhamVi []ThayPhamViLoai
}

// ThayPhamViLoai la tap id moi cua mot loai.
type ThayPhamViLoai struct {
	Loai string

	// IDs rong la dau vao HOP LE: no nghia la thu hoi sach, va nguoi do se thay man hinh
	// trong (ADR-0020 muc 3).
	IDs []string
}

// ThayPhamVi thay TOAN BO pham vi cua MOI hang vai tro cua mot nguoi, trong mot transaction.
//
// Trinh tu la khuon C-GO-06 cho moi method ghi: kiem quyen -> chuan bi va kiem du lieu NGOAI
// transaction -> BEGIN -> repository -> audit -> COMMIT.
//
// Vi sao mot lan goi phu ca nguoi thay vi mot hang vai tro: mot nguoi hai vai tro co hai bo
// pham vi, va man hinh sua ca hai cung luc. Hai request rieng se de lai mot trang thai nua
// voi khi request thu hai hong, va khong co gi noi cho nguoi dung biet nua nao da vao.
func (s *ScopeService) ThayPhamVi(ctx context.Context, actor auth.Actor, in ThayPhamViInput) (*PhamViCuaUser, error) {
	if err := s.authz.Can(ctx, actor, PermUserAssignScopes); err != nil {
		return nil, err
	}
	if !laUUID(in.UserID) {
		return nil, loiKhongTonTai()
	}

	hangVaiTro, err := s.userCompanyRepo.VaiTroTheoUser(ctx, s.db, actor.CompanyID, in.UserID)
	if err != nil {
		return nil, err
	}
	if _, err := s.userCompanyRepo.IDTheoUser(ctx, s.db, actor.CompanyID, in.UserID); err != nil {
		return nil, loiKhongTonTai()
	}
	if err := kiemDuHangVaiTro(hangVaiTro, in.VaiTro); err != nil {
		return nil, err
	}

	// Kiem tung bo pham vi TRUOC khi mo transaction: moi lan goi Nguon la mot cau doc rieng,
	// va giu no ngoai transaction lam transaction ngan dung bang phan that su ghi (P-TXN).
	daKiem, err := s.kiemVaChuanHoa(ctx, actor.CompanyID, hangVaiTro, in.VaiTro)
	if err != nil {
		return nil, err
	}

	tx, err := s.db.BeginTxx(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("begin tx thay pham vi cua user %s: %w", in.UserID, err)
	}
	defer tx.Rollback()

	for _, c := range daKiem {
		if err := s.scopeRepo.ThayPhamVi(ctx, tx, actor.CompanyID, c.hangVaiTroID, actor.UserID, c.loai, c.ids); err != nil {
			return nil, err
		}
	}

	ra, err := s.docPhamVi(ctx, tx, actor, in.UserID)
	if err != nil {
		return nil, err
	}

	if err := s.ghiAudit(ctx, tx, actor, actionUserScopeUpdated, in.UserID); err != nil {
		return nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("commit tx thay pham vi cua user %s: %w", in.UserID, err)
	}
	return ra, nil
}

// capDaKiem la mot cap (hang vai tro, loai) da qua moi phep kiem, san sang ghi.
type capDaKiem struct {
	hangVaiTroID string
	loai         string
	ids          []string
}

// kiemDuHangVaiTro doi request liet ke DU VA DUNG tap hang vai tro con song.
//
// Thieu, thua hay trung deu la 409 chu khong 422, va su khac biet do co nghia: 422 noi
// "request nay sai", 409 noi "request nay dung nhung du lieu da doi tu luc man hinh doc" -
// va cau tra loi dung cho no la tai lai man hinh, thu ma frontend da co duong xu san.
func kiemDuHangVaiTro(dangCo []model.UserCompanyRole, guiLen []ThayPhamViVaiTro) error {
	loi := func() error {
		return apperr.Conflict(apperr.CodeVersionConflict,
			"Danh sach vai tro cua nguoi nay da doi. Tai lai man hinh roi gan lai.")
	}
	if len(dangCo) != len(guiLen) {
		return loi()
	}
	con := make(map[string]bool, len(dangCo))
	for _, h := range dangCo {
		con[h.ID] = true
	}
	daThay := make(map[string]bool, len(guiLen))
	for _, g := range guiLen {
		if !con[g.UserCompanyRoleID] || daThay[g.UserCompanyRoleID] {
			return loi()
		}
		daThay[g.UserCompanyRoleID] = true
	}
	return nil
}

// kiemVaChuanHoa chay moi phep kiem 422 va tra ve danh sach cap san sang ghi.
func (s *ScopeService) kiemVaChuanHoa(ctx context.Context, companyID string, hangVaiTro []model.UserCompanyRole, guiLen []ThayPhamViVaiTro) ([]capDaKiem, error) {
	maVaiTro := make(map[string]string, len(hangVaiTro))
	for _, h := range hangVaiTro {
		maVaiTro[h.ID] = h.RoleCode
	}

	// Tap id hop le cua moi loai doc DUNG MOT LAN cho ca request, khong mot lan cho moi
	// hang vai tro: mot nguoi ba vai tro se lam ba lan doc y het nhau.
	hopLe := map[string]map[string]bool{}

	ra := make([]capDaKiem, 0, len(guiLen)*len(s.loaiPhamVi))
	for _, g := range guiLen {
		if len(g.PhamVi) != len(s.loaiPhamVi) {
			return nil, loi422("Phai gui du moi loai pham vi cho tung vai tro.")
		}
		daThayLoai := map[string]bool{}
		for _, p := range g.PhamVi {
			l, co := s.timLoai(p.Loai)
			if !co || daThayLoai[p.Loai] {
				return nil, loi422(fmt.Sprintf("Loai pham vi %q khong hop le.", p.Loai))
			}
			daThayLoai[p.Loai] = true

			if s.vaiTroToanPhamVi(ctx, companyID, maVaiTro[g.UserCompanyRoleID], l.PermToanPham) {
				if len(p.IDs) > 0 {
					return nil, loi422("Vai tro nay da thay toan bo, khong gan pham vi rieng duoc.")
				}
				continue
			}

			ids := khuTrung(p.IDs)
			if len(ids) > tranSoIDMoiLoai {
				return nil, loi422(fmt.Sprintf("Moi vai tro chi gan duoc toi da %d muc cho mot loai.", tranSoIDMoiLoai))
			}
			if len(ids) > 0 {
				if _, co := hopLe[p.Loai]; !co {
					tap, err := l.Nguon.IDsTrongPhanVung(ctx, companyID, l.Loai)
					if err != nil {
						return nil, err
					}
					m := make(map[string]bool, len(tap))
					for _, id := range tap {
						m[id] = true
					}
					hopLe[p.Loai] = m
				}
				for _, id := range ids {
					if !hopLe[p.Loai][id] {
						return nil, loi422("Mot muc duoc chon khong con ton tai trong phan vung nay.")
					}
				}
			}
			ra = append(ra, capDaKiem{hangVaiTroID: g.UserCompanyRoleID, loai: p.Loai, ids: ids})
		}
	}
	return ra, nil
}

// timLoai tra ve mo ta cua mot loai trong danh muc.
func (s *ScopeService) timLoai(ten string) (LoaiPhamVi, bool) {
	for _, l := range s.loaiPhamVi {
		if string(l.Loai) == ten {
			return l, true
		}
	}
	return LoaiPhamVi{}, false
}

// loi422 dung mot loi 422 kem ten o de form to duoc cho sai.
func loi422(thongDiep string) error {
	return apperr.ValidationFailedFields(apperr.CodeValidationFailed, thongDiep,
		apperr.Field{Name: fieldPhamVi, Message: thongDiep})
}

// khuTrung tra ve mot slice MOI khong co phan tu trung va khong co chuoi rong.
//
// Slice moi chu khong sua tai cho: dau vao den tu tang HTTP, va sua no la sua mot thu nguoi
// goi con dang giu.
func khuTrung(ids []string) []string {
	ra := make([]string, 0, len(ids))
	da := make(map[string]bool, len(ids))
	for _, id := range ids {
		if id == "" || da[id] {
			continue
		}
		da[id] = true
		ra = append(ra, id)
	}
	return ra
}

// ghiAudit ghi mot dong audit_logs qua CHINH tx cua thao tac nghiep vu (R-17). Goi TRUOC
// tx.Commit(): audit ghi ngoai transaction khong lam mat du lieu, no lam so sach noi doi.
func (s *ScopeService) ghiAudit(ctx context.Context, tx *sqlx.Tx, actor auth.Actor, hanhDong, entityID string) error {
	return s.auditRepo.Record(ctx, tx, audit.Entry{
		CompanyID: actor.CompanyID,
		ActorID:   actor.UserID,
		RequestID: requestid.FromContext(ctx),
		Action:    hanhDong,
		EntityID:  entityID,
	})
}
```

Thêm import `"erp/modules/auth/internal/model"` (dùng bởi `kiemDuHangVaiTro` và
`kiemVaChuanHoa`).

- [ ] **Bước 4: Kiểm dưới máy**

```powershell
go build ./... ; if ($?) { go vet ./... } ; if ($?) { go run ./cmd/dev arch }
```
Mong đợi: không lỗi; `arch` xanh. Đặc biệt **R-15 phải xanh**: câu lệnh đầu tiên của cả
`PhamViTheoUser` lẫn `ThayPhamVi` là `s.authz.Can`.

- [ ] **Bước 5: Đẩy và đọc CI**

```bash
git add modules/auth/internal/service/
git commit -m "feat(auth): duong ghi pham vi thay toan bo theo tung hang vai tro

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
git push
```
Mong đợi trên CI: toàn bộ `TestScopeService_*` XANH (5 test đọc + 10 test ghi).

---

## Task 6: Handler, route và test đầu-cuối

**Files:**
- Create: `modules/auth/internal/handler/user_scope_handler.go`
- Modify: `modules/auth/internal/handler/user_routes.go`
- Modify: `modules/auth/module.go`
- Modify: `cmd/api/e2e_test.go`

- [ ] **Bước 1: Viết handler**

```go
package handler

import (
	"github.com/gin-gonic/gin"

	"erp/modules/auth/internal/service"
	"erp/shared/auth"
	"erp/shared/response"
)

// UserScopeHandler phuc vu /users/:id/scopes.
//
// Tach khoi UserHandler chu khong them hai method vao do: hai handler goi hai service khac
// nhau, va mot handler giu hai service la mot cho de ai do goi nham service trong mot
// endpoint moi.
type UserScopeHandler struct {
	svc *service.ScopeService
}

// NewUserScopeHandler dung handler tu service da khoi tao o module.go.
func NewUserScopeHandler(svc *service.ScopeService) *UserScopeHandler {
	return &UserScopeHandler{svc: svc}
}

// ThayPhamViRequest la DTO cua lop HTTP, song o package handler chu khong o api/: api/ la
// hop dong voi module khac, cai nay la hop dong voi client HTTP.
//
// KHONG co field company_id (R-06): phan vung lay tu actor da xac thuc. Cung khong co
// user_id: no la path param.
type ThayPhamViRequest struct {
	// VaiTro bat buoc co mat va phai liet ke DU moi hang vai tro con song cua nguoi do -
	// service tra 409 khi thieu. `required` o day chi chan mot body khong co khoa nao;
	// mang RONG van hop le va co nghia: nguoi do chua co vai tro nao.
	VaiTro []ThayPhamViVaiTroRequest `json:"vai_tro" binding:"required,dive"`
}

// ThayPhamViVaiTroRequest la bo pham vi moi cua MOT hang vai tro.
type ThayPhamViVaiTroRequest struct {
	UserCompanyRoleID string                   `json:"user_company_role_id" binding:"required,uuid"`
	PhamVi            []ThayPhamViLoaiRequest  `json:"pham_vi" binding:"required,dive"`
}

// ThayPhamViLoaiRequest la tap id moi cua mot loai.
type ThayPhamViLoaiRequest struct {
	Loai string `json:"loai" binding:"required,max=64"`

	// IDs cho phep mang rong - do la duong THU HOI SACH. `dive,uuid` doi tung phan tu la
	// UUID: mot chuoi khong dung dinh dang di thang vao `unnest($5::text[])::uuid` lam
	// PostgreSQL tra loi 22P02, tuc mot 500 cho mot loi cua nguoi dung.
	IDs []string `json:"ids" binding:"omitempty,max=500,dive,uuid"`
}

// PhamViCuaUserDTO la hinh dang JSON tra ra cho ca GET lan PUT.
type PhamViCuaUserDTO struct {
	UserID string                `json:"user_id"`
	VaiTro []PhamViTheoVaiTroDTO `json:"vai_tro"`
}

// PhamViTheoVaiTroDTO gan pham vi vao DUNG MOT hang vai tro (ADR-0020 muc 1).
type PhamViTheoVaiTroDTO struct {
	UserCompanyRoleID string              `json:"user_company_role_id"`
	RoleCode          string              `json:"role_code"`
	PhamVi            []PhamViTheoLoaiDTO `json:"pham_vi"`
}

// PhamViTheoLoaiDTO la mot loai pham vi trong mot hang vai tro.
type PhamViTheoLoaiDTO struct {
	Loai string `json:"loai"`
	Nhan string `json:"nhan"`

	// ToanPhamVi la mot TRANG THAI RIENG, khong phai "da chon tat ca": man hinh phai hien
	// mot dong giai thich thay vi tich het o chon.
	ToanPhamVi bool `json:"toan_pham_vi"`

	// IDs luon la mang, khong bao gio null (C-API-03).
	IDs []string `json:"ids"`
}

// Get xu ly GET /api/v1/users/:id/scopes.
func (h *UserScopeHandler) Get(c *gin.Context) {
	ctx := c.Request.Context()
	actor := auth.FromContext(ctx)

	ra, err := h.svc.PhamViTheoUser(ctx, actor, c.Param("id"))
	if err != nil {
		response.Error(c, err)
		return
	}
	response.Success(c, toPhamViDTO(ra))
}

// Put xu ly PUT /api/v1/users/:id/scopes.
//
// PUT chu khong PATCH, va do la mot menh de ve NGU NGHIA: request nay mang toan bo buc anh
// pham vi cua nguoi do va thay han buc anh cu. Mot PATCH se hua rang cai khong gui thi giu
// nguyen - dung dieu thiet ke nay tu choi.
func (h *UserScopeHandler) Put(c *gin.Context) {
	var req ThayPhamViRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BindFailed(c, err)
		return
	}

	ctx := c.Request.Context()
	actor := auth.FromContext(ctx)

	in := service.ThayPhamViInput{UserID: c.Param("id")}
	for _, v := range req.VaiTro {
		muc := service.ThayPhamViVaiTro{UserCompanyRoleID: v.UserCompanyRoleID}
		for _, p := range v.PhamVi {
			ids := p.IDs
			if ids == nil {
				ids = []string{}
			}
			muc.PhamVi = append(muc.PhamVi, service.ThayPhamViLoai{Loai: p.Loai, IDs: ids})
		}
		in.VaiTro = append(in.VaiTro, muc)
	}

	ra, err := h.svc.ThayPhamVi(ctx, actor, in)
	if err != nil {
		response.Error(c, err)
		return
	}
	response.Success(c, toPhamViDTO(ra))
}

// toPhamViDTO doi ket qua service sang hinh dang JSON tra ra.
//
// Slice khoi tao san chu khong de nil: mot nguoi chua co vai tro nao phai ra JSON `[]` chu
// khong `null` (C-API-03).
func toPhamViDTO(p *service.PhamViCuaUser) PhamViCuaUserDTO {
	ra := PhamViCuaUserDTO{UserID: p.UserID, VaiTro: make([]PhamViTheoVaiTroDTO, 0, len(p.VaiTro))}
	for _, v := range p.VaiTro {
		muc := PhamViTheoVaiTroDTO{
			UserCompanyRoleID: v.UserCompanyRoleID,
			RoleCode:          v.RoleCode,
			PhamVi:            make([]PhamViTheoLoaiDTO, 0, len(v.PhamVi)),
		}
		for _, l := range v.PhamVi {
			ids := l.IDs
			if ids == nil {
				ids = []string{}
			}
			muc.PhamVi = append(muc.PhamVi, PhamViTheoLoaiDTO{
				Loai: l.Loai, Nhan: l.Nhan, ToanPhamVi: l.ToanPhamVi, IDs: ids,
			})
		}
		ra.VaiTro = append(ra.VaiTro, muc)
	}
	return ra
}
```

- [ ] **Bước 2: Thêm route**

Sửa `user_routes.go` — đổi chữ ký để nhận thêm handler mới và thêm hai dòng:

```go
func RegisterUserRoutes(v1 *gin.RouterGroup, h *UserHandler, hPhamVi *UserScopeHandler, xacThuc gin.HandlerFunc) {
	v1.GET("/users", xacThuc, h.List)
	v1.POST("/users", xacThuc, h.Create)
	v1.GET("/users/:id", xacThuc, h.Get)
	v1.PATCH("/users/:id", xacThuc, h.Update)
	v1.DELETE("/users/:id", xacThuc, h.Delete)

	// Pham vi du lieu treo vao tung hang vai tro cua nguoi nay (ADR-0020). PUT chu khong
	// PATCH: request mang toan bo buc anh va thay han buc anh cu.
	v1.GET("/users/:id/scopes", xacThuc, hPhamVi.Get)
	v1.PUT("/users/:id/scopes", xacThuc, hPhamVi.Put)
}
```

Sửa dòng gọi trong `module.go`: `handler.RegisterUserRoutes(v1, m.users, m.userScopes, xacThuc)`.

- [ ] **Bước 3: Nối dây trong `module.go`**

Thêm field vào `type Module struct`:

```go
	userScopes *handler.UserScopeHandler
```

Trong `New`, sau khi dựng `userSvc`, thêm:

```go
	// scopeSvc doi mot repository RIENG cho duong ghi pham vi: no nhan DBTX qua tham so
	// (C-GO-03), khac scopeRepo chi doc cua ScopeDoc. Xem khoi comment dau
	// user_company_role_scope_repository.go.
	loaiPhamVi := make([]service.LoaiPhamVi, 0, len(d.LoaiPhamVi))
	for _, l := range d.LoaiPhamVi {
		loaiPhamVi = append(loaiPhamVi, service.LoaiPhamVi{
			Loai: l.Loai, Nhan: l.Nhan, PermToanPham: l.PermToanPham, Nguon: l.Nguon,
		})
	}

	scopeSvc := service.NewScopeService(service.ScopeDeps{
		DB:              d.DB,
		Authz:           d.Authz,
		AuditRepo:       d.Audit,
		UserCompanyRepo: userCompanyRepo,
		ScopeRepo:       repository.NewUserCompanyRoleScopeRepository(),
		LoaiPhamVi:      loaiPhamVi,
	})
```

Và trong `return &Module{...}` thêm: `userScopes: handler.NewUserScopeHandler(scopeSvc),`

- [ ] **Bước 4: Viết test đầu-cuối trong `cmd/api/e2e_test.go`**

Thêm vào cuối file. Đây là bằng chứng thật: nó nối đường ghi với đường đọc.

```go
// TestE2EGanPhamViRoiNguoiDoChiThayKhoDuocGan la test noi HAI dau cua co che pham vi lai
// voi nhau: mot admin gan mot kho cho mot nguoi, roi CHINH nguoi do dang nhap va chi thay
// dung mot kho.
//
// Vai tro `member` cua vaitro.Bang() CO warehouse_list nhung KHONG co warehouse_scope_all
// (cmd/internal/vaitro/vaitro.go), nen no di duong theo cap phat - dung nhanh can do.
func TestE2EGanPhamViRoiNguoiDoChiThayKhoDuocGan(t *testing.T) {
	db, r := moiTruongE2E(t)
	congTy := idCongTy(t, db, maCongTySeed)

	// Admin tao hai kho.
	tokenAdmin := dangNhap(t, r, "admin@e2e.test").Access
	khoA := taoKho(t, r, tokenAdmin, "KHO-A")
	taoKho(t, r, tokenAdmin, "KHO-B")

	// Mot nguoi mang vai tro member: thay danh sach kho, nhung bi gioi han theo cap phat.
	themUser(t, db, congTy, "thukho@e2e.test", vaitro.ThanhVien)
	tokenThuKho := dangNhap(t, r, "thukho@e2e.test").Access

	// Chua gan gi: KHONG thay kho nao. Day la mac dinh fail-close cua ADR-0020 muc 3.
	w := goiJSON(t, r, http.MethodGet, "/api/v1/warehouses", tokenThuKho, "")
	if soKho := demItems(t, w); soKho != 0 {
		t.Fatalf("chua gan pham vi ma thay %d kho - mac dinh phai la KHONG THAY GI", soKho)
	}

	// Admin doc buc anh pham vi de lay id hang vai tro.
	idNguoi := idUserTheoEmail(t, db, congTy, "thukho@e2e.test")
	w = goiJSON(t, r, http.MethodGet, "/api/v1/users/"+idNguoi+"/scopes", tokenAdmin, "")
	if w.Code != http.StatusOK {
		t.Fatalf("GET scopes = %d, muon 200 (than: %s)", w.Code, w.Body.String())
	}
	var buc struct {
		VaiTro []struct {
			UserCompanyRoleID string `json:"user_company_role_id"`
			PhamVi            []struct {
				Loai       string `json:"loai"`
				ToanPhamVi bool   `json:"toan_pham_vi"`
			} `json:"pham_vi"`
		} `json:"vai_tro"`
	}
	docData(t, w, &buc)
	if len(buc.VaiTro) != 1 {
		t.Fatalf("so hang vai tro = %d, muon 1", len(buc.VaiTro))
	}
	if buc.VaiTro[0].PhamVi[0].ToanPhamVi {
		t.Fatal("member khong co warehouse_scope_all ma bao toan pham vi")
	}

	// Gan DUNG mot kho.
	than := fmt.Sprintf(`{"vai_tro":[{"user_company_role_id":%q,"pham_vi":[{"loai":"warehouse","ids":[%q]}]}]}`,
		buc.VaiTro[0].UserCompanyRoleID, khoA)
	w = goiJSON(t, r, http.MethodPut, "/api/v1/users/"+idNguoi+"/scopes", tokenAdmin, than)
	if w.Code != http.StatusOK {
		t.Fatalf("PUT scopes = %d, muon 200 (than: %s)", w.Code, w.Body.String())
	}

	// Nguoi do gio thay DUNG mot kho, khong phai hai. Khong dang nhap lai: pham vi khong
	// nam trong token nen no co hieu luc ngay o request ke tiep (ADR-0020 muc 6).
	w = goiJSON(t, r, http.MethodGet, "/api/v1/warehouses", tokenThuKho, "")
	if soKho := demItems(t, w); soKho != 1 {
		t.Fatalf("sau khi gan mot kho, nguoi do thay %d kho - muon 1", soKho)
	}

	// Thu hoi sach: tro lai khong thay gi.
	than = fmt.Sprintf(`{"vai_tro":[{"user_company_role_id":%q,"pham_vi":[{"loai":"warehouse","ids":[]}]}]}`,
		buc.VaiTro[0].UserCompanyRoleID)
	w = goiJSON(t, r, http.MethodPut, "/api/v1/users/"+idNguoi+"/scopes", tokenAdmin, than)
	if w.Code != http.StatusOK {
		t.Fatalf("PUT thu hoi = %d, muon 200 (than: %s)", w.Code, w.Body.String())
	}
	w = goiJSON(t, r, http.MethodGet, "/api/v1/warehouses", tokenThuKho, "")
	if soKho := demItems(t, w); soKho != 0 {
		t.Fatalf("sau khi thu hoi, nguoi do van thay %d kho - muon 0", soKho)
	}
}

// TestE2EVaiTroKhongCoQuyenGanPhamViTra403 do cua chan cua Task 1.
func TestE2EVaiTroKhongCoQuyenGanPhamViTra403(t *testing.T) {
	db, r := moiTruongE2E(t)
	congTy := idCongTy(t, db, maCongTySeed)

	themUser(t, db, congTy, "member@e2e.test", vaitro.ThanhVien)
	token := dangNhap(t, r, "member@e2e.test").Access
	idNguoi := idUserTheoEmail(t, db, congTy, "member@e2e.test")

	w := goiJSON(t, r, http.MethodPut, "/api/v1/users/"+idNguoi+"/scopes", token,
		`{"vai_tro":[]}`)
	if w.Code != http.StatusForbidden {
		t.Fatalf("PUT scopes bang vai tro member = %d, muon 403 (than: %s)", w.Code, w.Body.String())
	}
}

// idUserTheoEmail tra id user theo email trong mot phan vung.
func idUserTheoEmail(t *testing.T, db *sqlx.DB, companyID, email string) string {
	t.Helper()
	var id string
	if err := db.Get(&id,
		`SELECT id FROM users WHERE company_id = $1 AND email = $2 AND deleted_at IS NULL`,
		companyID, email); err != nil {
		t.Fatalf("tra id user %q: %v", email, err)
	}
	return id
}

// demItems dem so phan tu trong khoi data cua mot response danh sach.
func demItems(t *testing.T, w *httptest.ResponseRecorder) int {
	t.Helper()
	if w.Code != http.StatusOK {
		t.Fatalf("response = %d, muon 200 (than: %s)", w.Code, w.Body.String())
	}
	var items []json.RawMessage
	docData(t, w, &items)
	return len(items)
}
```

**Trước khi viết**: kiểm tra trong `e2e_test.go` xem đã có helper `taoKho` chưa (module
inventory đã có test đầu-cuối). Nếu đã có thì dùng lại, **không viết bản thứ hai**; nếu chưa,
viết một helper `taoKho(t, r, token, ma string) string` gọi `POST /api/v1/warehouses` và trả
id, theo đúng khuôn `taoMay` đang có ở dòng 353. Tương tự với `demItems`: nếu đã có helper
đếm danh sách thì dùng lại.

- [ ] **Bước 5: Kiểm dưới máy**

```powershell
go build ./... ; if ($?) { go vet ./... } ; if ($?) { go run ./cmd/dev check }
```
Mong đợi: không lỗi, `check` xanh (bao gồm R-13/C-API-06 cho hai route mới).

- [ ] **Bước 6: Đẩy và đọc CI**

```bash
git add modules/auth/ cmd/api/
git commit -m "feat(auth): hai endpoint GET|PUT /users/:id/scopes

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
git push
```
Mong đợi trên CI: toàn bộ test XANH, gồm hai test đầu-cuối mới. **Đây là mốc "backend xong"**
— không tuyên bố trước khi nhìn thấy CI xanh.

---

## Task 7: Module `user` ở frontend — API và hook

**Files:**
- Create: `src/modules/user/api/user-api.ts`
- Create: `src/modules/user/hooks/user-keys.ts`
- Create: `src/modules/user/hooks/mutation-errors.ts`
- Create: `src/modules/user/hooks/use-user-list.ts`
- Create: `src/modules/user/hooks/use-user-scopes.ts`
- Create: `src/modules/user/hooks/use-update-user-scopes.ts`
- Create: `src/modules/user/components/user-list-params.ts`

Trước khi bắt đầu: `git switch -c feat/man-gan-pham-vi` trong `frontend-erp`.

- [ ] **Bước 1: `api/user-api.ts`**

`GET /users` KHÔNG có tham số lọc `q` — struct bind của backend (`ListUsersQuery`) chỉ có
`page`, `page_size`, `sort`. Đừng thêm ô tìm kiếm rồi gửi một tham số backend bỏ qua.

```ts
import { getList, getOne, send } from '@/shared/api/client';
import type { Page } from '@/shared/api/types';

const USERS_PATH = '/users';

export const DEFAULT_PAGE_SIZE = 20;
export const MAX_PAGE_SIZE = 100;
export const PAGE_SIZE_OPTIONS: readonly number[] = [20, 50, 100];

function duongDanPhamVi(id: string): string {
  return `${USERS_PATH}/${encodeURIComponent(id)}/scopes`;
}

export interface UserDTO {
  id: string;
  email: string;
  full_name: string;
  is_active: boolean;
  roles: string[];
}

// Khong co `q`: GET /users chi nhan page, page_size, sort. Mot o tim o day se gui mot tham
// so backend bo qua, va nguoi dung se thay danh sach khong nhuc nhich.
export interface UserListParams {
  page: number;
  page_size: number;
}

export const DEFAULT_USER_LIST_PARAMS: UserListParams = {
  page: 1,
  page_size: DEFAULT_PAGE_SIZE,
};

// Ba kieu duoi day la hinh dang JSON cua GET|PUT /users/:id/scopes, giu nguyen ten khoa
// tieng Viet cua backend: mot lop dich ten o day chi them mot cho de lech.
export interface PhamViTheoLoaiDTO {
  loai: string;
  nhan: string;
  // Mot TRANG THAI RIENG, khong phai "da chon tat ca": vai tro nay khong bi gioi han theo
  // tung ban ghi, nen `ids` cua no luon rong va man hinh khong duoc hien o chon nao.
  toan_pham_vi: boolean;
  ids: string[];
}

export interface PhamViTheoVaiTroDTO {
  user_company_role_id: string;
  role_code: string;
  pham_vi: PhamViTheoLoaiDTO[];
}

export interface PhamViCuaUserDTO {
  user_id: string;
  vai_tro: PhamViTheoVaiTroDTO[];
}

// ThayPhamViRequest mang TOAN BO buc anh: du moi hang vai tro, va trong moi hang du moi
// loai. Backend tra 409 khi thieu mot hang va 422 khi thieu mot loai - co y, de mot man
// hinh doc du lieu cu khong ghi de mat phan no khong nhin thay.
export interface ThayPhamViRequest {
  vai_tro: Array<{
    user_company_role_id: string;
    pham_vi: Array<{ loai: string; ids: string[] }>;
  }>;
}

export const PHAM_VI_FIELDS: ReadonlySet<string> = new Set(['vai_tro']);

export function listUsers(params: UserListParams): Promise<Page<UserDTO>> {
  return getList<UserDTO>(USERS_PATH, { page: params.page, page_size: params.page_size });
}

export function getUserScopes(id: string): Promise<PhamViCuaUserDTO> {
  return getOne<PhamViCuaUserDTO>(duongDanPhamVi(id));
}

export function updateUserScopes(id: string, input: ThayPhamViRequest): Promise<PhamViCuaUserDTO> {
  return send<PhamViCuaUserDTO>('PUT', duongDanPhamVi(id), input);
}
```

- [ ] **Bước 2: `hooks/user-keys.ts`**

```ts
import type { UserListParams } from '../api/user-api';

export const userKeys = {
  all: ['users'] as const,
  list: (params: UserListParams) => ['users', 'list', params] as const,
  scopes: (id: string) => ['users', 'scopes', id] as const,
};
```

- [ ] **Bước 3: `hooks/mutation-errors.ts`**

Bản sao thứ ba của cùng một file (đã có ở `company` và `inventory`). Chép nguyên, không rút
lên `shared/`: `src/shared/components/` và `src/shared/lib/` đang rỗng có chủ đích, và chặng
này không mở chúng.

```ts
import { ApiError } from '@/shared/api/client';
import { toFormErrors, type FormErrorResult } from '@/shared/api/form-errors';

export interface MutationErrorView {
  errors: FormErrorResult;
  isForbidden: boolean;
  errorCode: string | null;
}

export function toMutationErrors(err: unknown, fields: ReadonlySet<string>): MutationErrorView {
  return {
    errors: toFormErrors(err, fields),
    isForbidden: err instanceof ApiError && err.status === 403,
    errorCode: err instanceof ApiError ? err.code : null,
  };
}
```

- [ ] **Bước 4: Ba hook**

`hooks/use-user-list.ts`:

```ts
import { useQuery } from '@tanstack/react-query';

import { listUsers, type UserListParams } from '../api/user-api';

import { userKeys } from './user-keys';

export function useUserList(params: UserListParams) {
  return useQuery({
    queryKey: userKeys.list(params),
    queryFn: () => listUsers(params),
    placeholderData: (prev) => prev,
  });
}
```

`hooks/use-user-scopes.ts`:

```ts
import { useQuery } from '@tanstack/react-query';

import { getUserScopes } from '../api/user-api';

import { userKeys } from './user-keys';

export function useUserScopes(id: string) {
  return useQuery({
    queryKey: userKeys.scopes(id),
    queryFn: () => getUserScopes(id),
  });
}
```

`hooks/use-update-user-scopes.ts`:

```ts
import { useMutation, useQueryClient } from '@tanstack/react-query';

import { ApiError } from '@/shared/api/client';

import {
  PHAM_VI_FIELDS,
  updateUserScopes,
  type PhamViCuaUserDTO,
  type ThayPhamViRequest,
} from '../api/user-api';

import { toMutationErrors, type MutationErrorView } from './mutation-errors';
import { userKeys } from './user-keys';

export interface UseUpdateUserScopesResult extends MutationErrorView {
  mutate: (input: ThayPhamViRequest) => void;
  reset: () => void;
  isPending: boolean;
  saved: PhamViCuaUserDTO | undefined;
}

export function useUpdateUserScopes(id: string): UseUpdateUserScopesResult {
  const queryClient = useQueryClient();

  const mutation = useMutation({
    mutationFn: (input: ThayPhamViRequest) => updateUserScopes(id, input),
    retry: false,

    // Dung THANG payload tra ve lam du lieu moi: PUT tra ve buc anh vua doc lai TRONG
    // transaction, nen mot lan GET nua chi lam them mot vong mang de nhan cung mot thu.
    onSuccess: (saved) => {
      queryClient.setQueryData(userKeys.scopes(id), saved);
    },

    // 409 nghia la vai tro cua nguoi nay da doi o cho khac. Buc anh dang giu khong con dung,
    // nen phai doc lai truoc khi nguoi dung bam Luu lan nua.
    onError: (err: unknown) => {
      if (err instanceof ApiError && err.status === 409) {
        void queryClient.invalidateQueries({ queryKey: userKeys.scopes(id) });
      }
    },
  });

  return {
    mutate: (input) => mutation.mutate(input),
    reset: mutation.reset,
    isPending: mutation.isPending,
    saved: mutation.data,
    ...toMutationErrors(mutation.error, PHAM_VI_FIELDS),
  };
}
```

- [ ] **Bước 5: `components/user-list-params.ts`**

Rút gọn từ `company-list-params.ts`: chỉ hai tham số, không có `q`, không có `sort`.

```ts
import { useCallback, useMemo, useSyncExternalStore } from 'react';

import { currentPathname, currentSearch, navigate, subscribeUrl } from '@/app/router/navigate';

import { DEFAULT_USER_LIST_PARAMS, MAX_PAGE_SIZE, type UserListParams } from '../api/user-api';

function parsePage(raw: string | null): number {
  const value = Number(raw);
  if (!Number.isInteger(value) || value < 1) return DEFAULT_USER_LIST_PARAMS.page;
  return value;
}

function parsePageSize(raw: string | null): number {
  const value = Number(raw);
  if (!Number.isInteger(value) || value < 1 || value > MAX_PAGE_SIZE) {
    return DEFAULT_USER_LIST_PARAMS.page_size;
  }
  return value;
}

export function parseUserListParams(search: string): UserListParams {
  const qs = new URLSearchParams(search);
  return { page: parsePage(qs.get('page')), page_size: parsePageSize(qs.get('page_size')) };
}

export function buildUserListSearch(params: UserListParams): string {
  const qs = new URLSearchParams();
  if (params.page !== DEFAULT_USER_LIST_PARAMS.page) qs.set('page', String(params.page));
  if (params.page_size !== DEFAULT_USER_LIST_PARAMS.page_size) {
    qs.set('page_size', String(params.page_size));
  }
  const text = qs.toString();
  return text === '' ? '' : `?${text}`;
}

export function mergeUserListParams(
  current: UserListParams,
  patch: Partial<UserListParams>,
): UserListParams {
  const doiThuKhacTrang = Object.keys(patch).some((key) => key !== 'page');
  const next = { ...current, ...patch };
  if (doiThuKhacTrang && patch.page === undefined) next.page = 1;
  return next;
}

function getServerSearchSnapshot(): string {
  return '';
}

export interface UserListParamsControl {
  params: UserListParams;
  setParams: (patch: Partial<UserListParams>) => void;
}

export function useUserListParams(): UserListParamsControl {
  const search = useSyncExternalStore(subscribeUrl, currentSearch, getServerSearchSnapshot);
  const params = useMemo(() => parseUserListParams(search), [search]);

  const setParams = useCallback((patch: Partial<UserListParams>) => {
    const next = mergeUserListParams(parseUserListParams(currentSearch()), patch);
    const nextSearch = buildUserListSearch(next);
    if (nextSearch === currentSearch()) return;
    navigate(`${currentPathname()}${nextSearch}`);
  }, []);

  return { params, setParams };
}
```

- [ ] **Bước 6: Kiểm dưới máy**

```powershell
npm run build ; if ($?) { npm run lint }
```
Mong đợi: `tsc --noEmit` không lỗi; eslint xanh — đặc biệt `c-ts-04-no-raw-http` (không
`fetch` trần) và `c-ts-01-no-deep-relative`.

- [ ] **Bước 7: Commit**

```bash
git add src/modules/user/
git commit -m "feat(user): api va hook cho danh sach nguoi dung va pham vi

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: Màn `/nguoi-dung`

**Files:**
- Create: `src/modules/user/pages/UserListPage.tsx`
- Create: `src/modules/user/pages/UserListPage.test.tsx`

- [ ] **Bước 1: Viết test trước**

Khuôn lấy từ `src/modules/company/pages/CompanyListPage.test.tsx`: `react-dom/client` + `act`,
`fetch` stub bằng `vi.stubGlobal`, QueryClient dựng trong test.

```tsx
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { act, type ReactElement } from 'react';
import { createRoot, type Root } from 'react-dom/client';
import { afterEach, beforeEach, expect, it, vi } from 'vitest';

import { clearAccessToken } from '@/shared/api/client';

import { UserListPage } from './UserListPage';

const NGUOI_A = {
  id: 'u-1',
  email: 'thukho@vidu.com',
  full_name: 'Tran Thu Kho',
  is_active: true,
  roles: ['member'],
};
const NGUOI_CHUA_VAI_TRO = {
  id: 'u-2',
  email: 'moi@vidu.com',
  full_name: 'Nguoi Moi',
  is_active: true,
  roles: [],
};

function makeResponse(status: number, body: unknown): Response {
  return {
    ok: status >= 200 && status < 300,
    status,
    headers: { get: (name: string) => (name === 'X-Request-Id' ? 'rq-test' : null) },
    json: () => Promise.resolve(body),
  } as unknown as Response;
}

function danhSach(items: unknown[]): unknown {
  return { data: items, meta: { total: items.length, page: 1, page_size: 20 }, request_id: 'rq' };
}

function dungMang(nguoi: unknown[]): void {
  vi.stubGlobal(
    'fetch',
    vi.fn((url: string) => {
      if (url.includes('/users')) return Promise.resolve(makeResponse(200, danhSach(nguoi)));
      throw new Error(`loi goi khong duoc mo ta trong test: ${url}`);
    }),
  );
}

function dungMangCam(): void {
  vi.stubGlobal(
    'fetch',
    vi.fn(() =>
      Promise.resolve(
        makeResponse(403, {
          error: { code: 'ERR_AUTH_FORBIDDEN', message: 'Khong du quyen' },
          request_id: 'rq-403',
        }),
      ),
    ),
  );
}

function makeClient(): QueryClient {
  return new QueryClient({
    defaultOptions: { queries: { retry: false, gcTime: 0 }, mutations: { retry: false } },
  });
}

let container: HTMLDivElement;
let root: Root;

beforeEach(() => {
  (globalThis as unknown as { IS_REACT_ACT_ENVIRONMENT: boolean }).IS_REACT_ACT_ENVIRONMENT = true;
  vi.restoreAllMocks();
  clearAccessToken();
  window.history.pushState(null, '', '/nguoi-dung');
  container = document.createElement('div');
  document.body.appendChild(container);
  root = createRoot(container);
});

afterEach(async () => {
  await act(async () => {
    root.unmount();
  });
  container.remove();
  clearAccessToken();
  window.history.pushState(null, '', '/');
});

async function mount(ui: ReactElement): Promise<void> {
  await act(async () => {
    root.render(ui);
  });
  await act(async () => {
    await new Promise((resolve) => setTimeout(resolve, 0));
  });
}

async function moTrang(nguoi: unknown[] = [NGUOI_A, NGUOI_CHUA_VAI_TRO]): Promise<void> {
  dungMang(nguoi);
  await mount(
    <QueryClientProvider client={makeClient()}>
      <UserListPage />
    </QueryClientProvider>,
  );
}

it('hien email va vai tro cua tung nguoi', async () => {
  await moTrang();
  expect(container.textContent).toContain('thukho@vidu.com');
  expect(container.textContent).toContain('member');
});

it('nguoi chua co vai tro nao duoc noi ro chu khong de o trong', async () => {
  await moTrang([NGUOI_CHUA_VAI_TRO]);
  expect(container.textContent).toContain('Chưa có vai trò');
});

it('moi hang co duong sang man pham vi', async () => {
  await moTrang();
  const link = container.querySelector('a[href="/nguoi-dung/u-1/pham-vi"]');
  expect(link).not.toBeNull();
});

it('danh sach rong noi rong chu khong hien bang trong', async () => {
  await moTrang([]);
  expect(container.textContent).toContain('Chưa có người dùng nào');
  expect(container.querySelector('table')).toBeNull();
});

it('403 giu nguyen man hinh va noi dung viec cua endpoint nay', async () => {
  dungMangCam();
  await mount(
    <QueryClientProvider client={makeClient()}>
      <UserListPage />
    </QueryClientProvider>,
  );
  const alert = container.querySelector('[role="alert"]');
  expect(alert?.textContent ?? '').toContain('quyền');
});
```

- [ ] **Bước 2: Chạy test để thấy nó hỏng**

```powershell
npm test -- src/modules/user/pages/UserListPage.test.tsx
```
Mong đợi: FAIL — không import được `./UserListPage`.

- [ ] **Bước 3: Viết `UserListPage.tsx`**

```tsx
import { Link } from '@/app/router/Link';
import { ApiError } from '@/shared/api/client';
import type { Page } from '@/shared/api/types';

import { PAGE_SIZE_OPTIONS, type UserDTO, type UserListParams } from '../api/user-api';
import { useUserListParams } from '../components/user-list-params';
import { useUserList } from '../hooks/use-user-list';

export function UserListPage() {
  const { params, setParams } = useUserListParams();
  const { data, isPending, isFetching, error, refetch } = useUserList(params);

  return (
    <main>
      <h1>Người dùng</h1>

      {/* Khong co duong "Them nguoi": chang nay khong lam man them nguoi vao phan vung.
          Mot link toi mot man chua ton tai con te hon khong co link nao. */}
      {data ? <p>{data.meta.total} người</p> : null}

      <UserListFilters params={params} onChange={setParams} />

      {error ? <UserListError error={error} onRetry={() => void refetch()} /> : null}

      {isPending ? <p>Đang tải...</p> : null}

      {data ? (
        <>
          {isFetching ? <p>Đang cập nhật...</p> : null}
          <UserTable rows={data.items} />
          <UserPager page={data} onChange={setParams} />
        </>
      ) : null}
    </main>
  );
}

function UserListFilters({
  params,
  onChange,
}: {
  params: UserListParams;
  onChange: (patch: Partial<UserListParams>) => void;
}) {
  function handlePageSizeChange(raw: string) {
    const chosen = PAGE_SIZE_OPTIONS.find((one) => String(one) === raw);
    if (chosen === undefined) return;
    onChange({ page_size: chosen });
  }

  // KHONG co o tim: GET /users chi nhan page, page_size, sort - mot o tim o day se gui mot
  // tham so backend bo qua, va danh sach khong nhuc nhich.
  return (
    <div>
      <label>
        Số dòng{' '}
        <select
          name="page_size"
          value={params.page_size}
          onChange={(e) => handlePageSizeChange(e.target.value)}
        >
          {PAGE_SIZE_OPTIONS.map((one) => (
            <option key={one} value={one}>
              {one}
            </option>
          ))}
        </select>
      </label>
    </div>
  );
}

function UserTable({ rows }: { rows: readonly UserDTO[] }) {
  if (rows.length === 0) {
    // MOT nhanh rong, khong hai: man nay khong co bo loc nao nen khong co ca "khong khop
    // bo loc". Va no khong mang duong tao, vi chang nay khong co man them nguoi.
    return <p>Chưa có người dùng nào trong phân vùng này.</p>;
  }

  return (
    <table>
      <thead>
        <tr>
          <th>Email</th>
          <th>Họ tên</th>
          <th>Vai trò</th>
          <th>Thao tác</th>
        </tr>
      </thead>
      <tbody>
        {rows.map((row) => (
          <tr key={row.id}>
            <td>{row.email}</td>
            <td>{row.full_name}</td>
            {/* Vai tro chi de DOC. Khong mot nut nao tren man nay bi an hay khoa theo no -
                xem frontend-erp/docs/Permission.md. */}
            <td>{row.roles.length === 0 ? 'Chưa có vai trò' : row.roles.join(', ')}</td>
            <td>
              <Link to={`/nguoi-dung/${encodeURIComponent(row.id)}/pham-vi`}>Phạm vi</Link>
            </td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}

function UserPager({
  page,
  onChange,
}: {
  page: Page<UserDTO>;
  onChange: (patch: Partial<UserListParams>) => void;
}) {
  // meta.total la nguon DUY NHAT cua so trang: mot phep chia tren page.items.length luon ra
  // "1 trang" va nut sang trang bien mat ngay o trang dau.
  const { total, page: current, page_size: pageSize } = page.meta;
  const totalPages = Math.max(1, Math.ceil(total / pageSize));

  return (
    <nav>
      <button type="button" disabled={current <= 1} onClick={() => onChange({ page: current - 1 })}>
        Trang trước
      </button>
      <span>
        Trang {current}/{totalPages} — {total} người
      </span>
      <button
        type="button"
        disabled={current >= totalPages}
        onClick={() => onChange({ page: current + 1 })}
      >
        Trang sau
      </button>
    </nav>
  );
}

function UserListError({ error, onRetry }: { error: unknown; onRetry: () => void }) {
  // Re nhanh theo `status`, KHONG theo `message` (C-TS-05).
  const apiError = error instanceof ApiError ? error : null;

  if (apiError?.status === 403) {
    return (
      <p role="alert">
        Tài khoản của bạn không có quyền xem danh sách người dùng của phân vùng này. Liên hệ
        quản trị nếu bạn cần nó.
        {apiError.requestId ? ` (mã tra cứu: ${apiError.requestId})` : ''}
      </p>
    );
  }

  const message = apiError ? apiError.message : 'Lỗi không xác định';
  const requestId = apiError?.requestId ?? '';

  return (
    <p role="alert">
      {message}
      {requestId ? ` (mã tra cứu: ${requestId})` : ''}{' '}
      <button type="button" onClick={onRetry}>
        Thử lại
      </button>
    </p>
  );
}
```

- [ ] **Bước 4: Chạy test để thấy nó xanh**

```powershell
npm test -- src/modules/user/pages/UserListPage.test.tsx
```
Mong đợi: 5 test PASS.

- [ ] **Bước 5: Commit**

```bash
git add src/modules/user/pages/
git commit -m "feat(user): man danh sach nguoi dung /nguoi-dung

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 9: Màn `/nguoi-dung/:id/pham-vi`

**Files:**
- Create: `src/modules/user/pages/UserScopePage.tsx`
- Create: `src/modules/user/pages/UserScopePage.test.tsx`

- [ ] **Bước 1: Viết test trước**

```tsx
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { act, type ReactElement } from 'react';
import { createRoot, type Root } from 'react-dom/client';
import { afterEach, beforeEach, expect, it, vi } from 'vitest';

import { clearAccessToken } from '@/shared/api/client';

import { UserScopePage } from './UserScopePage';

const KHO_A = { id: 'kho-1', code: 'KHO-A', name: 'Kho Hải Phòng', address: '' };
const KHO_B = { id: 'kho-2', code: 'KHO-B', name: 'Kho Đà Nẵng', address: '' };

// Mot nguoi HAI vai tro: mot bi gioi han theo kho, mot thay tat ca. Day la ca trung tam cua
// ca man hinh (ADR-0020 muc 1).
const PHAM_VI_HAI_VAI_TRO = {
  user_id: 'u-1',
  vai_tro: [
    {
      user_company_role_id: 'r-1',
      role_code: 'member',
      pham_vi: [{ loai: 'warehouse', nhan: 'Kho', toan_pham_vi: false, ids: ['kho-1'] }],
    },
    {
      user_company_role_id: 'r-2',
      role_code: 'admin',
      pham_vi: [{ loai: 'warehouse', nhan: 'Kho', toan_pham_vi: true, ids: [] }],
    },
  ],
};

function makeResponse(status: number, body: unknown): Response {
  return {
    ok: status >= 200 && status < 300,
    status,
    headers: { get: (name: string) => (name === 'X-Request-Id' ? 'rq-test' : null) },
    json: () => Promise.resolve(body),
  } as unknown as Response;
}

let daGui: Array<{ url: string; body: unknown }> = [];

function dungMang(phamVi: unknown, khoaPut?: { status: number; body: unknown }): void {
  vi.stubGlobal(
    'fetch',
    vi.fn((url: string, init?: RequestInit) => {
      if (url.includes('/warehouses')) {
        return Promise.resolve(
          makeResponse(200, {
            data: [KHO_A, KHO_B],
            meta: { total: 2, page: 1, page_size: 100 },
            request_id: 'rq',
          }),
        );
      }
      if (url.includes('/scopes')) {
        if (init?.method === 'PUT') {
          daGui.push({ url, body: JSON.parse(String(init.body)) });
          if (khoaPut) return Promise.resolve(makeResponse(khoaPut.status, khoaPut.body));
          return Promise.resolve(makeResponse(200, { data: phamVi, request_id: 'rq' }));
        }
        return Promise.resolve(makeResponse(200, { data: phamVi, request_id: 'rq' }));
      }
      throw new Error(`loi goi khong duoc mo ta trong test: ${url}`);
    }),
  );
}

function makeClient(): QueryClient {
  return new QueryClient({
    defaultOptions: { queries: { retry: false, gcTime: 0 }, mutations: { retry: false } },
  });
}

let container: HTMLDivElement;
let root: Root;

beforeEach(() => {
  (globalThis as unknown as { IS_REACT_ACT_ENVIRONMENT: boolean }).IS_REACT_ACT_ENVIRONMENT = true;
  vi.restoreAllMocks();
  clearAccessToken();
  daGui = [];
  window.history.pushState(null, '', '/nguoi-dung/u-1/pham-vi');
  container = document.createElement('div');
  document.body.appendChild(container);
  root = createRoot(container);
});

afterEach(async () => {
  await act(async () => {
    root.unmount();
  });
  container.remove();
  clearAccessToken();
  window.history.pushState(null, '', '/');
});

async function mount(ui: ReactElement): Promise<void> {
  await act(async () => {
    root.render(ui);
  });
  await act(async () => {
    await new Promise((resolve) => setTimeout(resolve, 0));
  });
}

async function moTrang(phamVi: unknown = PHAM_VI_HAI_VAI_TRO, khoaPut?: { status: number; body: unknown }) {
  dungMang(phamVi, khoaPut);
  await mount(
    <QueryClientProvider client={makeClient()}>
      <UserScopePage id="u-1" />
    </QueryClientProvider>,
  );
}

it('moi hang vai tro la mot khoi rieng', async () => {
  await moTrang();
  expect(container.textContent).toContain('member');
  expect(container.textContent).toContain('admin');
});

it('vai tro toan pham vi KHONG hien o chon nao', async () => {
  await moTrang();
  // Chi khoi cua `member` co o chon: hai kho, hai o. Khoi cua `admin` khong co o nao.
  const oChon = container.querySelectorAll('input[type="checkbox"]');
  expect(oChon.length).toBe(2);
  expect(container.textContent).toContain('thấy mọi Kho');
});

it('khoi chua chon gi canh bao nguoi do se khong thay dong nao', async () => {
  await moTrang({
    user_id: 'u-1',
    vai_tro: [
      {
        user_company_role_id: 'r-1',
        role_code: 'member',
        pham_vi: [{ loai: 'warehouse', nhan: 'Kho', toan_pham_vi: false, ids: [] }],
      },
    ],
  });
  expect(container.textContent).toContain('sẽ không thấy');
});

it('luu gui DU moi hang vai tro, ke ca hang khong sua', async () => {
  await moTrang();

  const nut = Array.from(container.querySelectorAll('button')).find(
    (b) => b.textContent?.includes('Lưu'),
  );
  await act(async () => {
    nut?.click();
  });
  await act(async () => {
    await new Promise((resolve) => setTimeout(resolve, 0));
  });

  expect(daGui.length).toBe(1);
  const body = daGui[0].body as { vai_tro: Array<{ user_company_role_id: string }> };
  expect(body.vai_tro.map((v) => v.user_company_role_id).sort()).toEqual(['r-1', 'r-2']);
});

it('nguoi chua co vai tro nao thi khong co nut Luu', async () => {
  await moTrang({ user_id: 'u-1', vai_tro: [] });
  const nut = Array.from(container.querySelectorAll('button')).find(
    (b) => b.textContent?.includes('Lưu'),
  );
  expect(nut).toBeUndefined();
  expect(container.textContent).toContain('chưa có vai trò nào');
});

it('409 hien thong diep va moi tai lai', async () => {
  await moTrang(PHAM_VI_HAI_VAI_TRO, {
    status: 409,
    body: {
      error: { code: 'ERR_COMMON_VERSION_CONFLICT', message: 'Danh sach vai tro da doi.' },
      request_id: 'rq-409',
    },
  });

  const nut = Array.from(container.querySelectorAll('button')).find(
    (b) => b.textContent?.includes('Lưu'),
  );
  await act(async () => {
    nut?.click();
  });
  await act(async () => {
    await new Promise((resolve) => setTimeout(resolve, 0));
  });

  const alert = container.querySelector('[role="alert"]');
  expect(alert?.textContent ?? '').toContain('Danh sach vai tro da doi');
});
```

- [ ] **Bước 2: Chạy test để thấy nó hỏng**

```powershell
npm test -- src/modules/user/pages/UserScopePage.test.tsx
```
Mong đợi: FAIL — không import được `./UserScopePage`.

- [ ] **Bước 3: Viết `UserScopePage.tsx`**

```tsx
import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';

import { Link } from '@/app/router/Link';
import {
  listWarehouses,
  MAX_PAGE_SIZE,
  type WarehouseDTO,
} from '@/modules/inventory/api/inventory-api';
import { ApiError } from '@/shared/api/client';

import type { PhamViCuaUserDTO, ThayPhamViRequest } from '../api/user-api';
import { useUpdateUserScopes } from '../hooks/use-update-user-scopes';
import { useUserScopes } from '../hooks/use-user-scopes';

// Import qua '@/modules/inventory/api' chu khong qua hooks/ cua module do: C-TS-01 cho
// module khac cham DUNG mot cua, va cua do la api/.

// Kho lay MOT trang toi da. Neu phan vung co nhieu hon, man hinh NOI RA thay vi cat im lang -
// mot danh sach chon bi cat ngang la cach chac chan nhat de gan thieu ma khong ai biet.
const KHO_LIST_PARAMS = { page: 1, page_size: MAX_PAGE_SIZE, sort: 'code' } as const;

export function UserScopePage({ id }: { id: string }) {
  const { data, isPending, error, refetch } = useUserScopes(id);

  return (
    <main>
      <h1>Phạm vi dữ liệu</h1>
      <p>
        <Link to="/nguoi-dung">Về danh sách người dùng</Link>
      </p>

      {error ? <ScopeError error={error} onRetry={() => void refetch()} /> : null}
      {isPending ? <p>Đang tải...</p> : null}

      {/* `key` gieo lai form moi khi du lieu tu may chu doi - cung cach o tim khong kiem soat
          cua man danh sach dung `key={params.q}`. Khong co no, mot lan tai lai sau 409 se hien
          du lieu cu tren mot form da co state rieng. */}
      {data ? <PhamViForm key={khoaGieo(data)} userId={id} banDau={data} /> : null}
    </main>
  );
}

// khoaGieo dung mot chuoi doi khi va chi khi buc anh may chu doi.
function khoaGieo(data: PhamViCuaUserDTO): string {
  return data.vai_tro
    .map((v) => `${v.user_company_role_id}:${v.pham_vi.map((p) => p.ids.join(',')).join('|')}`)
    .join(';');
}

// khoaCap la khoa cua mot cap (hang vai tro, loai) trong state dang chon.
function khoaCap(vaiTroId: string, loai: string): string {
  return `${vaiTroId}::${loai}`;
}

function PhamViForm({ userId, banDau }: { userId: string; banDau: PhamViCuaUserDTO }) {
  // State khoi tao LAZY tu du lieu may chu, giong CompanyForm: mot lan tinh, khong dong bo
  // lai o moi lan render.
  const [dangChon, setDangChon] = useState<Record<string, string[]>>(() => {
    const ra: Record<string, string[]> = {};
    for (const v of banDau.vai_tro) {
      for (const p of v.pham_vi) {
        ra[khoaCap(v.user_company_role_id, p.loai)] = [...p.ids];
      }
    }
    return ra;
  });

  const kho = useQuery({
    queryKey: ['warehouses', 'list', KHO_LIST_PARAMS],
    queryFn: () => listWarehouses(KHO_LIST_PARAMS),
  });

  const luu = useUpdateUserScopes(userId);

  if (banDau.vai_tro.length === 0) {
    // Khong co nut Luu: khong co gi de luu, va mot nut Luu o day se gui mot mang rong -
    // dung hinh dang ma backend chap nhan, nen no se "thanh cong" ma khong lam gi.
    return (
      <p>
        Người này chưa có vai trò nào trong phân vùng. Gán vai trò trước rồi mới gán được phạm
        vi.
      </p>
    );
  }

  function doiChon(vaiTroId: string, loai: string, khoId: string, chon: boolean) {
    setDangChon((truoc) => {
      const k = khoaCap(vaiTroId, loai);
      const hienTai = truoc[k] ?? [];
      const sau = chon ? [...hienTai, khoId] : hienTai.filter((one) => one !== khoId);
      return { ...truoc, [k]: sau };
    });
  }

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();

    // Gui DU moi hang vai tro va DU moi loai, ke ca hang khong sua va hang toan pham vi:
    // backend tra 409 khi thieu mot hang va 422 khi thieu mot loai. Day la dieu kien cung
    // cua thiet ke - PUT nay thay toan bo, no khong phai "set scope cho user".
    const than: ThayPhamViRequest = {
      vai_tro: banDau.vai_tro.map((v) => ({
        user_company_role_id: v.user_company_role_id,
        pham_vi: v.pham_vi.map((p) => ({
          loai: p.loai,
          // Vai tro toan pham vi luon gui mang rong: backend tu choi 422 neu gui id.
          ids: p.toan_pham_vi ? [] : (dangChon[khoaCap(v.user_company_role_id, p.loai)] ?? []),
        })),
      })),
    };
    luu.mutate(than);
  }

  return (
    <form onSubmit={handleSubmit} noValidate>
      {luu.errors.formMessage ? (
        <p role="alert">
          {luu.errors.formMessage}
          {luu.errors.shouldReload ? ' Tải lại màn hình rồi gán lại.' : ''}
        </p>
      ) : null}
      {luu.isForbidden ? (
        <p role="alert">Tài khoản của bạn không có quyền gán phạm vi cho người khác.</p>
      ) : null}

      {banDau.vai_tro.map((v) => (
        <section key={v.user_company_role_id}>
          <h2>Vai trò: {v.role_code}</h2>
          {v.pham_vi.map((p) => (
            <fieldset key={p.loai}>
              <legend>{p.nhan}</legend>
              {p.toan_pham_vi ? (
                // TRANG THAI RIENG, khong phai "da chon tat ca" (ADR-0020 muc 4).
                <p>Vai trò này thấy mọi {p.nhan}. Không cần gán phạm vi cho vai trò này.</p>
              ) : (
                <ChonKho
                  danhSach={kho.data?.items ?? []}
                  tong={kho.data?.meta.total ?? 0}
                  dangChon={dangChon[khoaCap(v.user_company_role_id, p.loai)] ?? []}
                  onDoi={(khoId, chon) => doiChon(v.user_company_role_id, p.loai, khoId, chon)}
                  nhan={p.nhan}
                />
              )}
            </fieldset>
          ))}
        </section>
      ))}

      <button type="submit" disabled={luu.isPending}>
        {luu.isPending ? 'Đang lưu...' : 'Lưu'}
      </button>
    </form>
  );
}

function ChonKho({
  danhSach,
  tong,
  dangChon,
  onDoi,
  nhan,
}: {
  danhSach: readonly WarehouseDTO[];
  tong: number;
  dangChon: readonly string[];
  onDoi: (khoId: string, chon: boolean) => void;
  nhan: string;
}) {
  return (
    <>
      {dangChon.length === 0 ? (
        // Hau qua da chon co y thuc cua ADR-0020 muc 3, va no phai duoc noi TRUOC khi luu:
        // khong co dong nay, nguoi bi gan se thay man hinh trong ma khong thong diep nao
        // giai thich vi sao.
        <p>Chưa chọn {nhan.toLowerCase()} nào. Người này sẽ không thấy dòng nào ở màn kho.</p>
      ) : null}

      {danhSach.map((one) => (
        <label key={one.id}>
          <input
            type="checkbox"
            checked={dangChon.includes(one.id)}
            onChange={(e) => onDoi(one.id, e.target.checked)}
          />{' '}
          {one.code} — {one.name}
        </label>
      ))}

      {tong > danhSach.length ? (
        <p>
          Đang hiện {danhSach.length}/{tong} {nhan.toLowerCase()}. Phân vùng này có nhiều hơn
          một trang, phần còn lại chưa chọn được ở màn này.
        </p>
      ) : null}
    </>
  );
}

function ScopeError({ error, onRetry }: { error: unknown; onRetry: () => void }) {
  const apiError = error instanceof ApiError ? error : null;

  if (apiError?.status === 403) {
    return (
      <p role="alert">
        Tài khoản của bạn không có quyền xem phạm vi của người khác.
        {apiError.requestId ? ` (mã tra cứu: ${apiError.requestId})` : ''}
      </p>
    );
  }

  const message = apiError ? apiError.message : 'Lỗi không xác định';
  const requestId = apiError?.requestId ?? '';

  return (
    <p role="alert">
      {message}
      {requestId ? ` (mã tra cứu: ${requestId})` : ''}{' '}
      <button type="button" onClick={onRetry}>
        Thử lại
      </button>
    </p>
  );
}
```

- [ ] **Bước 4: Chạy test**

```powershell
npm test -- src/modules/user/pages/UserScopePage.test.tsx
```
Mong đợi: 6 test PASS.

- [ ] **Bước 5: Chạy lint và xử đúng nếu `c-ts-06` đỏ**

```powershell
npm run lint
```

Luật `c-ts-06-no-role-guess` bắt cặp NGUỒN (`role`/`roles`/`vai_tro`/`quyen`) đi kèm CÔNG TẮC
(`disabled`/`hidden`/nhánh JSX). Màn này rẽ nhánh JSX trên `p.toan_pham_vi` — một trường nằm
trong đối tượng lấy ra từ `v.pham_vi`, nên có khả năng luật đỏ oan.

**Nếu đỏ:** tách một biến trung gian có tên không mang chữ vai trò, ví dụ:

```tsx
const thayTatCa = p.toan_pham_vi;
...
{thayTatCa ? <p>...</p> : <ChonKho ... />}
```

**Không** nới luật, **không** thêm `eslint-disable`. Rẽ theo `toan_pham_vi` không phải đoán
quyền từ role: nó là dữ liệu backend trả về, đúng như `session.quanTriHeThong` đang được dùng
ở `DropdownTaiKhoan.tsx`.

- [ ] **Bước 6: Commit**

```bash
git add src/modules/user/pages/
git commit -m "feat(user): man gan pham vi theo tung hang vai tro

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 10: Nối hai màn vào ứng dụng

**Files:**
- Modify: `src/app/routes.tsx`
- Modify: `src/app/ung-dung.ts`

- [ ] **Bước 1: Thêm hai route**

Trong `ROUTES`, thêm hai dòng. Thứ tự: đoạn cố định trước, tham số sau — cùng bẫy mà
`/phan-vung/moi` vs `/phan-vung/:id` đã có.

```tsx
  { path: '/nguoi-dung', render: () => <UserListPage /> },
  { path: '/nguoi-dung/:id/pham-vi', render: (p) => <UserScopePage id={p.id} /> },
```

Và hai dòng import ở đầu file, giữ đúng thứ tự alphabet của khối `@/modules/...`:

```tsx
import { UserListPage } from '@/modules/user/pages/UserListPage';
import { UserScopePage } from '@/modules/user/pages/UserScopePage';
```

- [ ] **Bước 2: Mở khoá ứng dụng `auth` trong `ung-dung.ts`**

Thay phần tử `auth` hiện tại bằng:

```ts
  {
    id: 'auth',
    ten: 'Quản trị hệ thống',
    mo: 'Người dùng, vai trò, phạm vi dữ liệu.',
    tab: 'he-thong',
    duong: '/nguoi-dung',
    // nhan PHAI la null khi duong khac null - ung-dung.test.ts khoa bat bien do.
    nhan: null,
    // Phan tu dau tien LUON la trang chu, tuc bang chinh `duong` - bat bien thu hai.
    man: [{ duong: '/nguoi-dung', nhan: 'Người dùng', bieuTuong: 'tai-khoan' }],
    duongThuoc: ['/nguoi-dung'],
  },
```

`'tai-khoan'` là khoá đã có trong bảng nét vẽ ở `src/app/BieuTuongDieuHuong.tsx` — không thêm
biểu tượng mới trong chặng này.

- [ ] **Bước 3: Chạy toàn bộ test và lint**

```powershell
npm test ; if ($?) { npm run build } ; if ($?) { npm run lint } ; if ($?) { npm run arch }
```
Mong đợi: tất cả xanh. `routes.test.tsx` và `ung-dung.test.ts` khoá các bất biến ở trên — nếu
một trong hai đỏ thì sửa dữ liệu cho khớp bất biến, **không** sửa test.

- [ ] **Bước 4: Commit và đẩy**

```bash
git add src/app/
git commit -m "feat(app): mo khoa ung dung quan tri va hai route nguoi dung

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
git push -u origin feat/man-gan-pham-vi
```

- [ ] **Bước 5: Xác nhận trên máy dev**

Sau khi CI của cả hai repo xanh, deploy một bản rc lên máy dev rồi đi đúng đường người dùng
sẽ đi: đăng nhập bằng một tài khoản `admin`, vào `/nguoi-dung`, mở phạm vi của một người mang
vai trò `member`, chọn một kho, lưu, rồi đăng nhập bằng chính người đó và xác nhận màn `/kho`
chỉ hiện đúng kho đã gán.

Đây là mốc "xong". Không tuyên bố trước khi đi hết đường này.

---

## Tự soi lại kế hoạch

**Đối chiếu với spec:**

| Mục spec | Task phủ |
|---|---|
| 4.1 Permission | Task 1 |
| 4.2 Danh mục loại phạm vi tiêm từ root | Task 2 |
| 4.3 Hai endpoint + hình dạng JSON | Task 6 (handler), Task 4-5 (hình dạng service) |
| 4.4 Chín luật kiểm | Task 5 (bước 3) + Task 6 (binding tag) |
| 4.5 Tầng service | Task 4, Task 5 |
| 4.6 Tầng repository | Task 3 |
| 4.7 Handler | Task 6 |
| 5.1 `/nguoi-dung` | Task 8 |
| 5.2 `/nguoi-dung/:id/pham-vi` | Task 9 |
| 6 Kiểm chứng | mỗi task có bước kiểm; e2e ở Task 6; xác nhận tay ở Task 10 |

**Ba chỗ kế hoạch lệch spec, có lý do:**

1. Spec 5.1 nói màn danh sách có ô tìm `q` theo khuôn `CompanyListPage`. Backend
   `GET /users` **không nhận** `q` (`ListUsersQuery` chỉ có `page`, `page_size`, `sort`), nên
   Task 8 bỏ ô tìm và bỏ luôn nhánh rỗng "không khớp bộ lọc". Thêm ô tìm sẽ là một ô không
   làm gì.
2. Spec 5.2 nói nguồn kho là `GET /warehouses`; kế hoạch chốt thêm rằng nó lấy **một trang
   tối đa 100** và nói ra khi phân vùng có nhiều hơn. Spec không nói gì về ca đó.
3. Spec 4.5 nói `PhamViTheoUser` trả 404 khi người đó không thuộc phân vùng; kế hoạch phân
   biệt thêm "thuộc phân vùng nhưng chưa có vai trò nào" thành một câu trả lời hợp lệ (mảng
   rỗng) chứ không phải 404, và màn hình nói rõ phải gán vai trò trước.
