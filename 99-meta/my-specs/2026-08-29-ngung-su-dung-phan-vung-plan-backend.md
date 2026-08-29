# Kế hoạch thi công backend: "Ngừng sử dụng" phân vùng

> **Cho người thi công bằng agent:** SKILL BẮT BUỘC: dùng `superpowers:subagent-driven-development`
> để chạy plan này từng task một. Các bước dùng cú pháp checkbox (`- [ ]`) để theo dõi.

**Mục tiêu:** Thêm trạng thái "ngừng sử dụng" cho phân vùng - đảo lại được, tách khỏi `deleted_at` - và nới đường xoá đúng một nấc.

**Kiến trúc:** Một cột `companies.is_active`. Cửa lọc trạng thái đặt tại **chỗ gọi** ở `auth_service.go` chứ không trong SQL của `CompanyRepository.ByID`, vì hàm đó dùng chung giữa đường nghiệp vụ và mặt quản trị. Một method service `DatTrangThaiSuDung` chạy cả hai chiều.

**Nền:** [ADR-0044](../../03-decisions/ADR-0044-ngung-su-dung-phan-vung-tach-khoi-xoa.md) (vì sao), [spec 2026-08-29](2026-08-29-ngung-su-dung-phan-vung-design.md) (làm gì). Frontend là một plan riêng, làm sau khi API đứng.

**Công nghệ:** Go 1.23, `sqlx`, gin, PostgreSQL, `golang-migrate`.

**Chạy test:** toàn bộ chạy trên PostgreSQL thật ở VPS dev, không chạy dưới máy Windows. Bọc `bash -lc` khi gọi qua ssh:

```bash
ssh deploy@103.179.172.110 'bash -lc "cd /tmp/<worktree> && ./cmd/dev test ./modules/auth/..."'
```

---

### Task 1: Migration `000038` - cột `is_active`

**Files:**
- Tạo: `backend-erp/migrations/000038_companies_is_active.up.sql`
- Tạo: `backend-erp/migrations/000038_companies_is_active.down.sql`
- Test: `backend-erp/modules/auth/internal/repository/company_trang_thai_db_test.go`

- [ ] **Bước 1: Viết bài test đỏ**

```go
package repository_test

import (
	"context"
	"testing"
)

// TestRangBuoc000038_IsActive_NotNullVaMacDinhTrue khoá hình dạng cột mà ADR-0044 mục 1
// dựng. Ba vế, và cả ba đều là thứ hỏng im lặng nếu sai:
//
//   - NOT NULL: C-DB cấm boolean cho phép NULL vì `WHERE is_active = false` khi đó BỎ SÓT
//     mọi hàng NULL.
//   - DEFAULT true: một phân vùng vừa tạo phải dùng được ngay. DEFAULT false nghĩa là
//     `POST /companies` sinh ra một phân vùng không ai vào được.
//   - Kiểu boolean: đọc từ information_schema chứ không suy từ việc câu INSERT chạy được.
func TestRangBuoc000038_IsActive_NotNullVaMacDinhTrue(t *testing.T) {
	db := moDB(t)
	ctx := context.Background()

	var kieu, nullDuoc, macDinh string
	err := db.QueryRowContext(ctx, `
SELECT data_type, is_nullable, coalesce(column_default, '')
FROM information_schema.columns
WHERE table_name = 'companies' AND column_name = 'is_active'`).Scan(&kieu, &nullDuoc, &macDinh)
	if err != nil {
		t.Fatalf("doc information_schema: %v", err)
	}
	if kieu != "boolean" {
		t.Errorf("data_type = %q, muon boolean", kieu)
	}
	if nullDuoc != "NO" {
		t.Errorf("is_nullable = %q, muon NO - xem C-DB muc kieu du lieu", nullDuoc)
	}
	if macDinh != "true" {
		t.Errorf("column_default = %q, muon true - phan vung vua tao phai dung duoc ngay", macDinh)
	}
}
```

`moDB(t)` là helper đã có trong package test này - xem `user_company_admin_db_test.go`. Nếu tên khác thì dùng đúng tên nó đang có; **đọc file đó trước, không đoán**.

- [ ] **Bước 2: Chạy test, xác nhận nó đỏ**

Chạy: `./cmd/dev test ./modules/auth/internal/repository/ -run TestRangBuoc000038 -v`
Mong đợi: FAIL - `doc information_schema: sql: no rows in result set`

- [ ] **Bước 3: Viết migration**

`000038_companies_is_active.up.sql`:

```sql
-- ADR-0044 muc 1: ngung su dung tach khoi xoa. Truoc migration nay, deleted_at mang CA
-- HAI nghia va ADR-0019 muc Mat da ghi san mon no do.
--
-- DEFAULT true la trang thai an toan theo C-DB: mot phan vung vua tao phai dung duoc
-- ngay. DEFAULT false nghia la POST /companies sinh ra mot phan vung khong ai vao duoc.
--
-- KHONG danh index, va day la ly do de nguoi ra R-09 khoi di tim: bang nay dem bang chuc
-- hang, cot hai gia tri, va khong cau nao loc RIENG theo no - moi cau deu di kem
-- deleted_at IS NULL von da co uq_companies_code phuc vu.
--
-- Khong backfill: moi phan vung dang song deu dang dung.
ALTER TABLE companies ADD COLUMN is_active BOOLEAN NOT NULL DEFAULT true;
```

`000038_companies_is_active.down.sql`:

```sql
ALTER TABLE companies DROP COLUMN is_active;
```

- [ ] **Bước 4: Chạy migration rồi chạy lại test**

Chạy: `./cmd/dev migrate up` rồi `./cmd/dev test ./modules/auth/internal/repository/ -run TestRangBuoc000038 -v`
Mong đợi: PASS

- [ ] **Bước 5: Commit**

```bash
git add migrations/000038_companies_is_active.up.sql migrations/000038_companies_is_active.down.sql modules/auth/internal/repository/company_trang_thai_db_test.go
git commit -m "feat(auth): migration 000038 them cot companies.is_active"
```

---

### Task 2: `model.Company` mang `IsActive`, ba câu SELECT trả cột đó

**Files:**
- Sửa: `backend-erp/modules/auth/internal/model/company.go:11-22`
- Sửa: `backend-erp/modules/auth/internal/repository/company_repository.go` - `countCompaniesSQL` không đổi; `listCompaniesCodeTangSQL`, `listCompaniesCodeGiamSQL`, `selectCompanyByIDSQL` thêm cột
- Test: `backend-erp/modules/auth/internal/repository/company_trang_thai_db_test.go`

- [ ] **Bước 1: Viết bài test đỏ**

```go
// TestByID_TraIsActive doi ByID doc duoc CA HAI gia tri cua cot moi.
//
// Bai nay phai co truoc moi bai khac cua doi nay: neu ByID khong tra cot do thi moi cua
// chan doc theo no o tang tren deu doc phai gia tri zero cua Go - false - va ca he se
// hanh xu nhu moi phan vung deu da ngung su dung.
func TestByID_TraIsActive(t *testing.T) {
	db := moDB(t)
	ctx := context.Background()
	repo := repository.NewCompanyRepository()

	id := taoPhanVung(t, db, "TEST-ACTIVE-1")

	c, err := repo.ByID(ctx, db, id)
	if err != nil {
		t.Fatalf("ByID: %v", err)
	}
	if !c.IsActive {
		t.Fatalf("phan vung vua tao co IsActive = false, muon true")
	}

	if _, err := db.ExecContext(ctx, `UPDATE companies SET is_active = false WHERE id = $1`, id); err != nil {
		t.Fatalf("tat phan vung: %v", err)
	}

	c, err = repo.ByID(ctx, db, id)
	if err != nil {
		t.Fatalf("ByID lan hai: %v", err)
	}
	if c.IsActive {
		t.Fatalf("phan vung da tat co IsActive = true, muon false")
	}
}
```

`taoPhanVung` là helper của package test này. **Đọc `company_repository_test.go` trước** để lấy đúng tên và chữ ký; nếu chưa có thì viết một helper chèn một hàng `companies` với `code` truyền vào và trả `id`.

- [ ] **Bước 2: Chạy test, xác nhận nó đỏ**

Chạy: `./cmd/dev test ./modules/auth/internal/repository/ -run TestByID_TraIsActive -v`
Mong đợi: FAIL biên dịch - `c.IsActive undefined`

- [ ] **Bước 3: Thêm field và sửa ba câu SQL**

`model/company.go`, thêm ngay dưới `Name`:

```go
	// IsActive false nghia la phan vung DANG NGUNG SU DUNG (ADR-0044 muc 1). No KHONG
	// phai deleted_at doi ten: mot phan vung ngung su dung bat lai duoc, mot phan vung
	// da xoa thi khong.
	IsActive bool `db:"is_active"`
```

Ba câu SQL đổi danh sách cột thành:

```sql
SELECT id, code, name, is_active, created_at, updated_at, deleted_at, created_by, updated_by
```

Áp cho `listCompaniesCodeTangSQL`, `listCompaniesCodeGiamSQL` và `selectCompanyByIDSQL`. **Mệnh đề `WHERE` của cả ba giữ nguyên `deleted_at IS NULL` và KHÔNG thêm `is_active`** - ADR-0044 mục Mất: nhét vào đây thì mặt quản trị không đọc được phân vùng đã ngừng và nút bật lại thành vô dụng.

- [ ] **Bước 4: Chạy test, xác nhận nó xanh**

Chạy: `./cmd/dev test ./modules/auth/internal/repository/ -run TestByID_TraIsActive -v`
Mong đợi: PASS

- [ ] **Bước 5: Commit**

```bash
git add modules/auth/internal/model/company.go modules/auth/internal/repository/company_repository.go modules/auth/internal/repository/company_trang_thai_db_test.go
git commit -m "feat(auth): model.Company mang IsActive, ba cau SELECT tra cot do"
```

---

### Task 3: Hai câu SQL của đường nghiệp vụ lọc `is_active`

**Files:**
- Sửa: `backend-erp/modules/auth/internal/repository/company_repository.go` - `companyConSongSQL`, `selectCompanyIDByCodeSQL`
- Test: `backend-erp/modules/auth/internal/repository/company_trang_thai_db_test.go`

- [ ] **Bước 1: Viết hai bài test đỏ**

```go
// TestConSong_PhanVungNgungSuDung_TraFalse: Refresh dung ConSong de dong cua mot phien
// cua phan vung da tat. Sau ADR-0044 "da tat" co hai nghia, va ca hai phai dong cua.
func TestConSong_PhanVungNgungSuDung_TraFalse(t *testing.T) {
	db := moDB(t)
	ctx := context.Background()
	repo := repository.NewCompanyRepository()

	id := taoPhanVung(t, db, "TEST-CONSONG-1")

	con, err := repo.ConSong(ctx, db, id)
	if err != nil {
		t.Fatalf("ConSong: %v", err)
	}
	if !con {
		t.Fatalf("phan vung dang dung ma ConSong tra false")
	}

	if _, err := db.ExecContext(ctx, `UPDATE companies SET is_active = false WHERE id = $1`, id); err != nil {
		t.Fatalf("tat phan vung: %v", err)
	}

	con, err = repo.ConSong(ctx, db, id)
	if err != nil {
		t.Fatalf("ConSong lan hai: %v", err)
	}
	if con {
		t.Fatalf("phan vung da ngung su dung ma ConSong tra true - phien cua no khong dong lai")
	}
}

// TestIDByCode_PhanVungNgungSuDung_TraErrNoRows: dang nhap va chon phan vung di qua cau
// nay. Mot phan vung da ngung phai khong chon duoc, va no tra dung sentinel ma
// AuthService dang bat.
func TestIDByCode_PhanVungNgungSuDung_TraErrNoRows(t *testing.T) {
	db := moDB(t)
	ctx := context.Background()
	repo := repository.NewCompanyRepository()

	id := taoPhanVung(t, db, "TEST-BYCODE-1")

	if _, err := repo.IDByCode(ctx, db, "TEST-BYCODE-1"); err != nil {
		t.Fatalf("phan vung dang dung ma IDByCode loi: %v", err)
	}

	if _, err := db.ExecContext(ctx, `UPDATE companies SET is_active = false WHERE id = $1`, id); err != nil {
		t.Fatalf("tat phan vung: %v", err)
	}

	if _, err := repo.IDByCode(ctx, db, "TEST-BYCODE-1"); !errors.Is(err, sql.ErrNoRows) {
		t.Fatalf("IDByCode tra %v, muon sql.ErrNoRows", err)
	}
}
```

Thêm `"database/sql"` và `"errors"` vào import của file test.

- [ ] **Bước 2: Chạy hai bài, xác nhận chúng đỏ**

Chạy: `./cmd/dev test ./modules/auth/internal/repository/ -run 'TestConSong_PhanVungNgungSuDung|TestIDByCode_PhanVungNgungSuDung' -v`
Mong đợi: FAIL cả hai - `ConSong tra true`, `IDByCode tra <nil>`

- [ ] **Bước 3: Sửa hai câu SQL**

```go
// AND is_active la ADR-0044 muc 1: sau ADR do, "phan vung nay dung duoc khong" KHONG con
// bang "deleted_at IS NULL". Hai ve khac nhau, va quen ve thu hai la mot loi im lang -
// phien cua mot phan vung vua bi ngung se song tiep.
const companyConSongSQL = `
SELECT EXISTS (SELECT 1 FROM companies WHERE id = $1 AND deleted_at IS NULL AND is_active)`
```

`selectCompanyIDByCodeSQL` thêm `AND is_active` vào mệnh đề `WHERE` của nó, kèm một dòng comment cùng ý. **Đọc câu hiện tại trước khi sửa** - nó có khối comment dài ở trên, giữ nguyên khối đó.

- [ ] **Bước 4: Chạy lại, xác nhận xanh**

Chạy: `./cmd/dev test ./modules/auth/internal/repository/ -run 'TestConSong_PhanVungNgungSuDung|TestIDByCode_PhanVungNgungSuDung' -v`
Mong đợi: PASS cả hai

- [ ] **Bước 5: Commit**

```bash
git add modules/auth/internal/repository/company_repository.go modules/auth/internal/repository/company_trang_thai_db_test.go
git commit -m "feat(auth): ConSong va IDByCode loc is_active"
```

---

### Task 4: Repo - câu ghi `is_active` và câu gỡ mọi hàng gán

**Files:**
- Sửa: `backend-erp/modules/auth/internal/repository/company_repository.go` - thêm `DatTrangThai` vào interface và impl
- Sửa: `backend-erp/modules/auth/internal/repository/user_company_repository.go` - thêm `SoftDeleteMoiHangGan`
- Test: `backend-erp/modules/auth/internal/repository/company_trang_thai_db_test.go`

- [ ] **Bước 1: Viết hai bài test đỏ**

```go
// TestDatTrangThai_DiDuocHaiChieu. Chieu bat lai moi la thu tach "ngung su dung" khoi
// "xoa"; mot bai chi do chieu tat se xanh ca khi cot nay chi la deleted_at doi ten.
func TestDatTrangThai_DiDuocHaiChieu(t *testing.T) {
	db := moDB(t)
	ctx := context.Background()
	repo := repository.NewCompanyRepository()

	id := taoPhanVung(t, db, "TEST-TRANGTHAI-1")
	actor := idNguoiBatKy(t, db)

	if err := repo.DatTrangThai(ctx, db, id, false, actor); err != nil {
		t.Fatalf("tat: %v", err)
	}
	c, _ := repo.ByID(ctx, db, id)
	if c.IsActive {
		t.Fatalf("tat roi ma IsActive van true")
	}

	if err := repo.DatTrangThai(ctx, db, id, true, actor); err != nil {
		t.Fatalf("bat lai: %v", err)
	}
	c, _ = repo.ByID(ctx, db, id)
	if !c.IsActive {
		t.Fatalf("bat lai roi ma IsActive van false")
	}
}

// TestDatTrangThai_PhanVungDaXoa_TraErrNoRows: mot phan vung da xoa mem khong bat lai
// duoc bang duong nay. Xoa la mot chieu (ADR-0044 muc 1).
func TestDatTrangThai_PhanVungDaXoa_TraErrNoRows(t *testing.T) {
	db := moDB(t)
	ctx := context.Background()
	repo := repository.NewCompanyRepository()

	id := taoPhanVung(t, db, "TEST-TRANGTHAI-2")
	actor := idNguoiBatKy(t, db)
	if _, err := db.ExecContext(ctx, `UPDATE companies SET deleted_at = now() WHERE id = $1`, id); err != nil {
		t.Fatalf("xoa mem: %v", err)
	}

	if err := repo.DatTrangThai(ctx, db, id, true, actor); !errors.Is(err, sql.ErrNoRows) {
		t.Fatalf("DatTrangThai tra %v, muon sql.ErrNoRows", err)
	}
}

// TestSoftDeleteMoiHangGan_GoCaHangCuaTaiKhoanDaKhoa.
//
// "Moi hang" chu khong "hang cua nguoi quan tri", va day la ly do: cau dem cua
// DeleteCompany loc users.is_active, nen mot tai khoan bi khoa KHONG duoc dem nhung hang
// gan cua no van con. Dac cach theo nguoi quan tri bo sot dung ca nay va de lai mot hang
// gan tro toi mot phan vung khong con ton tai.
func TestSoftDeleteMoiHangGan_GoCaHangCuaTaiKhoanDaKhoa(t *testing.T) {
	db := moDB(t)
	ctx := context.Background()
	repo := repository.NewUserCompanyRepository()

	congTy := taoPhanVung(t, db, "TEST-GOGAN-1")
	quanTri := taoNguoiTrongPhanVung(t, db, congTy, "quantri@test.local", true)
	biKhoa := taoNguoiTrongPhanVung(t, db, congTy, "bikhoa@test.local", false)
	if _, err := db.ExecContext(ctx, `UPDATE users SET is_active = false WHERE id = $1`, biKhoa); err != nil {
		t.Fatalf("khoa tai khoan: %v", err)
	}

	if err := repo.SoftDeleteMoiHangGan(ctx, db, congTy, quanTri); err != nil {
		t.Fatalf("SoftDeleteMoiHangGan: %v", err)
	}

	var con int
	if err := db.QueryRowContext(ctx,
		`SELECT count(*) FROM user_companies WHERE company_id = $1 AND deleted_at IS NULL`,
		congTy).Scan(&con); err != nil {
		t.Fatalf("dem hang gan con lai: %v", err)
	}
	if con != 0 {
		t.Fatalf("con %d hang gan song, muon 0 - hang cua tai khoan bi khoa bi bo sot", con)
	}
}
```

`idNguoiBatKy` và `taoNguoiTrongPhanVung` là helper phải viết nếu package test chưa có. **Đọc `user_company_admin_db_test.go` trước** - file đó đã dựng người trong phân vùng cho bài ADR-0039, nhiều khả năng helper đã tồn tại dưới tên khác.

- [ ] **Bước 2: Chạy ba bài, xác nhận chúng đỏ**

Chạy: `./cmd/dev test ./modules/auth/internal/repository/ -run 'TestDatTrangThai|TestSoftDeleteMoiHangGan' -v`
Mong đợi: FAIL biên dịch - `repo.DatTrangThai undefined`, `repo.SoftDeleteMoiHangGan undefined`

- [ ] **Bước 3: Thêm hai method**

`company_repository.go` - thêm vào interface `CompanyRepository`, ngay dưới `SoftDelete`:

```go
	// DatTrangThai bat hoac tat mot phan vung (ADR-0044 muc 1). Tra sql.ErrNoRows khi
	// phan vung khong ton tai hoac da bi xoa mem - xoa la mot chieu.
	DatTrangThai(ctx context.Context, db sharedDB.DBTX, id string, dangSuDung bool, actorID string) error
```

Câu SQL, đặt cạnh `softDeleteCompanySQL`:

```go
// datTrangThaiCongTySQL bat hoac tat mot phan vung. deleted_at IS NULL trong WHERE la R-18
// VA la ADR-0044 muc 1 cung luc: mot phan vung da xoa khong bat lai duoc bang duong nay.
const datTrangThaiCongTySQL = `
UPDATE companies SET is_active = $2, updated_at = now(), updated_by = $3
WHERE id = $1 AND deleted_at IS NULL`
```

Impl - **theo đúng khuôn của `SoftDelete` đang có trong file, đọc nó trước**: chạy `ExecContext`, đọc `RowsAffected`, trả `sql.ErrNoRows` khi bằng 0.

`user_company_repository.go` - thêm vào interface, ngay dưới `SoftDeleteTheoUser`:

```go
	// SoftDeleteMoiHangGan xoa mem MOI hang gan con song cua mot phan vung (R-18). Chi
	// duong xoa phan vung goi no.
	//
	// # Day la cau ghi THU HAI di duong ADR-0041, va no duoc ADR-0044 muc 7 ke ten
	//
	// ADR-0041 cap phep theo TUNG CAU chu khong theo hinh dang, va cau duy nhat no ke ten
	// la DatNguoiQuanTri. Cau nay la cau thu hai, va khong co cau thu ba nao duoc cap.
	//
	// "Moi hang" chu khong "hang cua nguoi quan tri": cau dem cua DeleteCompany loc
	// users.is_active, nen mot tai khoan bi khoa khong duoc dem nhung hang gan cua no van
	// con lai.
	//
	// Khong dem hang va khong bao loi khi khong co hang nao: mot phan vung rong nguoi van
	// la dau vao hop le cua duong xoa.
	SoftDeleteMoiHangGan(ctx context.Context, db sharedDB.DBTX, companyID, actorID string) error
```

```go
const softDeleteMoiHangGanSQL = `
UPDATE user_companies
   SET deleted_at = now(), updated_at = now(), updated_by = $2
 WHERE company_id = $1 AND deleted_at IS NULL`
```

- [ ] **Bước 4: Chạy lại ba bài, xác nhận xanh**

Chạy: `./cmd/dev test ./modules/auth/internal/repository/ -run 'TestDatTrangThai|TestSoftDeleteMoiHangGan' -v`
Mong đợi: PASS cả ba

- [ ] **Bước 5: Chạy bộ kiểm kiến trúc**

Chạy: `./cmd/dev check`
Mong đợi: xanh. Nếu `checkR06` đỏ ở `softDeleteMoiHangGanSQL` thì **dừng lại và báo** - câu này có `company_id = $1` trong `WHERE` nên nó phải qua được; đỏ ở đây nghĩa là hiểu sai luật chứ không phải luật cần nới.

- [ ] **Bước 6: Commit**

```bash
git add modules/auth/internal/repository/company_repository.go modules/auth/internal/repository/user_company_repository.go modules/auth/internal/repository/company_trang_thai_db_test.go
git commit -m "feat(auth): repo DatTrangThai va SoftDeleteMoiHangGan"
```

---

### Task 5: Mã lỗi mới `ERR_AUTH_COMPANY_IS_CURRENT`

**Files:**
- Sửa: `backend-erp/shared/errors/codes.go:34` - thêm hằng ngay dưới `CodeAuthCompanyInUse`
- Sửa: `docs-erp/04-conventions/C-API-http.md:586` - thêm một dòng vào bảng C-API-05, và sửa dòng `ERR_AUTH_COMPANY_IN_USE` cho khớp chữ mới
- Test: `backend-erp/modules/auth/module_test.go` nếu file đó khoá danh sách mã; nếu không thì không có test riêng cho task này

- [ ] **Bước 1: Thêm hằng**

```go
	// CodeAuthCompanyIsCurrent - 409. Nguoi bam nut dang lam viec trong chinh phan vung
	// ho vua bam Ngung su dung.
	//
	// 409 chu khong 403: ho CO quyen auth.company_delete, chi la doi tuong ho chon dang o
	// mot trang thai khong cho phep (C-API-05).
	//
	// Cua nay khong co o duong XOA, va do la chu y chu khong bo sot: DeleteCompany dua vao
	// cua "con nguoi dung" bat truoc - actor luon co mot hang users con song trong phan
	// vung cua chinh minh. Duong ngung su dung khong co cua do.
	CodeAuthCompanyIsCurrent = "ERR_AUTH_COMPANY_IS_CURRENT"
```

- [ ] **Bước 2: Sửa bảng C-API-05**

Dòng `ERR_AUTH_COMPANY_IN_USE` hiện viết "không vô hiệu hoá được". Chữ "vô hiệu hoá" biến mất khỏi hệ theo ADR-0044, nên sửa thành:

```
| `ERR_AUTH_COMPANY_IN_USE` | `409` | Phân vùng còn người dùng đang hoạt động, không xoá được | Xoá một phân vùng còn người ngoài chính người quản trị của nó. Từ ADR-0044 mục 5 cửa này cho qua khi phân vùng rỗng người, hoặc còn đúng một người và người đó mang cờ `is_admin` |
| `ERR_AUTH_COMPANY_IS_CURRENT` | `409` | Không ngừng sử dụng được phân vùng bạn đang làm việc | Bấm Ngừng sử dụng lên chính phân vùng của actor (ADR-0044 mục 4). Đường xoá không có cửa này vì cửa "còn người dùng" đã bắt trước |
```

Chữ `ADR-0044` ở dòng thứ hai phải thành **liên kết markdown** khi dán vào `C-API-http.md`, trỏ tới file ADR trong `03-decisions` theo đúng lối của các dòng lân cận trong bảng đó - chép hình dạng liên kết của dòng `ERR_AUTH_ROLE_CODE_DUPLICATED` ngay dưới. Ở đây để trần vì đường dẫn tương đối của bảng tính từ `04-conventions/`, còn file kế hoạch này nằm ở `99-meta/my-specs/`, nên viết sẵn liên kết vào đây là làm `check-ids` đỏ.

- [ ] **Bước 3: Chạy check-ids**

Chạy: `cd docs-erp && pwsh ./tools/check-ids.ps1`
Mong đợi: `check-ids: OK`

- [ ] **Bước 4: Commit**

Hai repo, hai commit.

```bash
cd backend-erp && git add shared/errors/codes.go && git commit -m "feat(auth): ma loi ERR_AUTH_COMPANY_IS_CURRENT"
cd ../docs-erp && git add 04-conventions/C-API-http.md && git commit -m "docs(api): C-API-05 them ERR_AUTH_COMPANY_IS_CURRENT"
```

---

### Task 6: `CompanyService.DatTrangThaiSuDung`

**Files:**
- Sửa: `backend-erp/modules/auth/internal/service/company_service.go` - thêm hằng action, thêm method, thêm hàm lỗi
- Test: `backend-erp/modules/auth/internal/service/company_service_test.go`

- [ ] **Bước 1: Viết ba bài test đỏ**

Trước hết, hai helper mới. Đặt cạnh `actorAdminPhanVung` ở `company_service_test.go:128`:

```go
// actorHeThongTaiPhanVung tra ve mot quan tri he thong DANG DUNG trong mot phan vung.
//
// # Doc ky khoi nay truoc khi viet bai cua ADR-0044 muc 4
//
// actorHeThong() de TRONG CompanyID. Mot bai dung no de do cua "khong ngung su dung duoc
// phan vung dang lam viec" se XANH GIA: phep so `id == actor.CompanyID` khong bao gio
// dung khi mot ve la chuoi rong, nen bai do se bao cua chay dung trong khi no chua bao
// gio chay lan nao.
//
// Trong that thi CompanyID luon co: quan tri he thong dung ngoai moi phan vung nhung ho
// van CHON mot phan vung de lam viec (ADR-0036), va buoc chon do dat CompanyID vao token.
func actorHeThongTaiPhanVung(congTyID string) auth.Actor {
	return auth.Actor{UserID: uuid.NewString(), CompanyID: congTyID, Roles: []string{"quan_tri_he_thong"}}
}

func dangSuDung(t *testing.T, db *sqlx.DB, congTyID string) bool {
	t.Helper()
	var con bool
	if err := db.Get(&con, `SELECT is_active FROM companies WHERE id = $1`, congTyID); err != nil {
		t.Fatalf("doc is_active: %v", err)
	}
	return con
}
```

Rồi ba bài:

```go
// TestCompanyService_DatTrangThaiSuDung_DiDuocHaiChieu.
//
// Chieu DUNG LAI moi la thu tach "ngung su dung" khoi "xoa". Mot bai chi do chieu ngung
// se xanh ca khi cot nay chi la deleted_at doi ten.
func TestCompanyService_DatTrangThaiSuDung_DiDuocHaiChieu(t *testing.T) {
	db := testutil.Connect(t)
	svc := dungCompanyService(t, db)
	ctx := context.Background()

	congTyID := taoCongTy(t, db, "TT-"+uuid.NewString()[:8])

	if err := svc.DatTrangThaiSuDung(ctx, actorHeThong(), congTyID, false); err != nil {
		t.Fatalf("ngung su dung: %v", err)
	}
	if dangSuDung(t, db, congTyID) {
		t.Fatal("ngung roi ma is_active van true")
	}

	if err := svc.DatTrangThaiSuDung(ctx, actorHeThong(), congTyID, true); err != nil {
		t.Fatalf("dung lai: %v", err)
	}
	if !dangSuDung(t, db, congTyID) {
		t.Fatal("dung lai roi ma is_active van false")
	}
}

// TestCompanyService_DatTrangThaiSuDung_PhanVungDangDung_Tra409 do cua ADR-0044 muc 4.
//
// Khong co cua nay thi mot quan tri he thong tu da minh ra ngoai trong toi da mot chu ky
// access token, va khong con duong nao vao lai de bat no len.
func TestCompanyService_DatTrangThaiSuDung_PhanVungDangDung_Tra409(t *testing.T) {
	db := testutil.Connect(t)
	svc := dungCompanyService(t, db)
	ctx := context.Background()

	congTyID := taoCongTy(t, db, "TT-"+uuid.NewString()[:8])

	err := svc.DatTrangThaiSuDung(ctx, actorHeThongTaiPhanVung(congTyID), congTyID, false)
	if err == nil {
		t.Fatal("ngung su dung duoc phan vung dang lam viec - nguoi bam vua tu da minh ra ngoai")
	}
	ma, status := maLoi(t, err)
	if status != http.StatusConflict {
		t.Fatalf("status = %d, muon 409", status)
	}
	if ma != apperr.CodeAuthCompanyIsCurrent {
		t.Errorf("ma loi = %q, muon %q", ma, apperr.CodeAuthCompanyIsCurrent)
	}
	if !dangSuDung(t, db, congTyID) {
		t.Error("is_active da bi tat du thao tac tra loi - cua chan dat sau cau ghi")
	}
}

// TestCompanyService_DatTrangThaiSuDung_DungLaiPhanVungCuaMinh_Xanh.
//
// Cua o bai tren CHI canh chieu ngung. Chieu dung lai khong can no - khong ai dang lam
// viec trong mot phan vung da ngung - va mot cua canh ca hai chieu se chan dung duong
// cuu ho.
func TestCompanyService_DatTrangThaiSuDung_DungLaiPhanVungCuaMinh_Xanh(t *testing.T) {
	db := testutil.Connect(t)
	svc := dungCompanyService(t, db)
	ctx := context.Background()

	congTyID := taoCongTy(t, db, "TT-"+uuid.NewString()[:8])
	if _, err := db.Exec(`UPDATE companies SET is_active = false WHERE id = $1`, congTyID); err != nil {
		t.Fatalf("tat thang: %v", err)
	}

	if err := svc.DatTrangThaiSuDung(ctx, actorHeThongTaiPhanVung(congTyID), congTyID, true); err != nil {
		t.Fatalf("dung lai phan vung cua chinh minh: %v", err)
	}
}
```

- [ ] **Bước 2: Chạy ba bài, xác nhận chúng đỏ**

Chạy: `./cmd/dev test ./modules/auth/internal/service/ -run TestCompanyService_DatTrangThaiSuDung -v`
Mong đợi: FAIL biên dịch - `svc.DatTrangThaiSuDung undefined`

- [ ] **Bước 3: Viết method**

Hằng action, thêm vào khối `action*` ở `company_service.go:33-45`:

```go
	// Hai hanh dong cua ADR-0044. Hai ten rieng chu khong mot ten kem tham so: audit_logs
	// duoc doc bang mat, va "company.deactivated" tra loi ngay cau hoi "ai da tat phan
	// vung nay" ma khong phai mo cot du lieu kem theo.
	actionCompanyDeactivated = "company.deactivated"
	actionCompanyReactivated = "company.reactivated"
```

Hàm lỗi, đặt cạnh `loiPhanVungConNguoiDung`:

```go
func loiPhanVungDangLamViec() error {
	return apperr.Conflict(apperr.CodeAuthCompanyIsCurrent,
		"Không ngừng sử dụng được phân vùng bạn đang làm việc. Chuyển sang phân vùng khác rồi thử lại.")
}
```

Method, đặt ngay sau `DeleteCompany`:

```go
// DatTrangThaiSuDung bat hoac tat mot phan vung (ADR-0044 muc 1). Tat la "ngung su dung":
// dao lai duoc, khong dung deleted_at, khong go mot hang gan nao.
//
// MOT method cho ca hai chieu chu khong hai: cua quyen, phep kiem laUUID, phep kiem ton
// tai va transaction giong het nhau; chi ten hanh dong audit re nhanh.
//
// Quyen la PermCompanyDelete chu khong mot ma moi. Hom nay chi vai tro quan_tri_he_thong
// cam moi ma auth.company_*, nen mot ma moi khong cap them cho ai va khong chan them ai -
// no chi tot hai bai test khoa tap quyen (ADR-0044 phan Alternatives).
//
// Cua chan chi canh CHIEU TAT. Chieu bat khong can no: khong ai dang dung trong mot phan
// vung da ngung, va mot cua canh ca hai chieu se chan dung ca duong cuu ho.
func (s *CompanyService) DatTrangThaiSuDung(ctx context.Context, actor auth.Actor, id string, dangSuDung bool) error {
	if err := s.authz.Can(ctx, actor, PermCompanyDelete); err != nil {
		return err
	}
	if !laUUID(id) {
		return loiPhanVungKhongTonTai()
	}
	if !dangSuDung && id == actor.CompanyID {
		return loiPhanVungDangLamViec()
	}

	tx, err := s.db.BeginTxx(ctx, nil)
	if err != nil {
		return fmt.Errorf("begin tx dat trang thai company: %w", err)
	}
	defer tx.Rollback()

	if err := s.companyRepo.DatTrangThai(ctx, tx, id, dangSuDung, actor.UserID); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return loiPhanVungKhongTonTai()
		}
		return err
	}

	hanhDong := actionCompanyDeactivated
	if dangSuDung {
		hanhDong = actionCompanyReactivated
	}
	if err := s.ghiAuditCongTy(ctx, tx, actor, hanhDong, id); err != nil {
		return err
	}
	if err := tx.Commit(); err != nil {
		return fmt.Errorf("commit tx dat trang thai company %s: %w", id, err)
	}
	return nil
}
```

- [ ] **Bước 4: Chạy ba bài, xác nhận xanh**

Chạy: `./cmd/dev test ./modules/auth/internal/service/ -run TestCompanyService_DatTrangThaiSuDung -v`
Mong đợi: PASS cả ba

- [ ] **Bước 5: Phép thử đột biến**

Gỡ hai dòng `if !dangSuDung && id == actor.CompanyID` rồi chạy lại. Bài `PhanVungDangDung_Tra409` phải **đỏ**. Đổi `!dangSuDung &&` thành bỏ hẳn (canh cả hai chiều) rồi chạy lại: bài `BatLaiPhanVungCuaMinh_Xanh` phải **đỏ**. Khôi phục code sau khi đo xong.

Nếu một trong hai phép thử vẫn xanh thì bài test đó không đo cái nó nói - **dừng và sửa test trước khi đi tiếp**.

- [ ] **Bước 6: Commit**

```bash
git add modules/auth/internal/service/company_service.go modules/auth/internal/service/company_service_test.go
git commit -m "feat(auth): CompanyService.DatTrangThaiSuDung, hai chieu, mot cua chan"
```

---

### Task 7: Nới `DeleteCompany`

**Files:**
- Sửa: `backend-erp/modules/auth/internal/service/company_service.go:618-635`
- Test: `backend-erp/modules/auth/internal/service/company_service_test.go`

- [ ] **Bước 1: Viết bốn bài test đỏ**

Hai helper mới trước, đặt cạnh `dungPhanVungCoNguoiBoNhiem`:

```go
func datCoQuanTri(t *testing.T, db *sqlx.DB, congTyID, userID string) {
	t.Helper()
	if _, err := db.Exec(`
		UPDATE user_companies SET is_admin = true
		 WHERE company_id = $1 AND user_id = $2 AND deleted_at IS NULL`, congTyID, userID); err != nil {
		t.Fatalf("dat co quan tri: %v", err)
	}
}

func soHangGanConSong(t *testing.T, db *sqlx.DB, congTyID string) int {
	t.Helper()
	var n int
	if err := db.Get(&n,
		`SELECT count(*) FROM user_companies WHERE company_id = $1 AND deleted_at IS NULL`,
		congTyID); err != nil {
		t.Fatalf("dem hang gan: %v", err)
	}
	return n
}
```

Rồi bốn bài:

```go
// TestCompanyService_DeleteCompany_HaiNguoi_Tra409: cua cu giu nguyen o ca nay.
func TestCompanyService_DeleteCompany_HaiNguoi_Tra409(t *testing.T) {
	db := testutil.Connect(t)
	svc := dungCompanyService(t, db)
	ctx := context.Background()

	congTyID := taoCongTy(t, db, "XO-"+uuid.NewString()[:8])
	qt := themNguoiCoVaiTro(t, db, congTyID, "qt-"+uuid.NewString()+"@test.local")
	datCoQuanTri(t, db, congTyID, qt)
	themNguoiCoVaiTro(t, db, congTyID, "thu-hai-"+uuid.NewString()+"@test.local")

	err := svc.DeleteCompany(ctx, actorHeThong(), congTyID)
	if err == nil {
		t.Fatal("xoa duoc phan vung con hai nguoi - du lieu cua nguoi thu hai vua bien mat")
	}
	if _, status := maLoi(t, err); status != http.StatusConflict {
		t.Fatalf("status = %d, muon 409", status)
	}
}

// TestCompanyService_DeleteCompany_MotNguoiKhongPhaiQuanTri_Tra409.
//
// Ca nay la ly do cua moi KHONG THE chi la "so nguoi <= 1". Mot phan vung con dung mot
// nguoi KHONG mang co quan tri la mot phan vung da co nguoi vao lam roi nguoi quan tri
// bi go ra - xoa no la mat viec cua nguoi con lai.
func TestCompanyService_DeleteCompany_MotNguoiKhongPhaiQuanTri_Tra409(t *testing.T) {
	db := testutil.Connect(t)
	svc := dungCompanyService(t, db)
	ctx := context.Background()

	congTyID := taoCongTy(t, db, "XO-"+uuid.NewString()[:8])
	themNguoiCoVaiTro(t, db, congTyID, "thuong-"+uuid.NewString()+"@test.local")

	err := svc.DeleteCompany(ctx, actorHeThong(), congTyID)
	if err == nil {
		t.Fatal("xoa duoc phan vung con mot nguoi khong phai quan tri")
	}
	ma, status := maLoi(t, err)
	if status != http.StatusConflict || ma != apperr.CodeAuthCompanyInUse {
		t.Fatalf("ma=%q status=%d, muon %q/409", ma, status, apperr.CodeAuthCompanyInUse)
	}
}

// TestCompanyService_DeleteCompany_ChiNguoiQuanTri_XoaDuoc_VaGoMoiHangGan.
//
// Hai lời khẳng định trong MOT bai, va chung khong tach duoc: xoa xong ma con mot hang
// gan song thi hang do tro toi mot phan vung khong con ton tai.
func TestCompanyService_DeleteCompany_ChiNguoiQuanTri_XoaDuoc_VaGoMoiHangGan(t *testing.T) {
	db := testutil.Connect(t)
	svc := dungCompanyService(t, db)
	ctx := context.Background()

	congTyID := taoCongTy(t, db, "XO-"+uuid.NewString()[:8])
	qt := themNguoiCoVaiTro(t, db, congTyID, "qt-"+uuid.NewString()+"@test.local")
	datCoQuanTri(t, db, congTyID, qt)

	if err := svc.DeleteCompany(ctx, actorHeThong(), congTyID); err != nil {
		t.Fatalf("DeleteCompany: %v", err)
	}
	if n := soHangGanConSong(t, db, congTyID); n != 0 {
		t.Fatalf("con %d hang gan song sau khi xoa - chung tro toi mot phan vung khong con ton tai", n)
	}
}

// TestCompanyService_DeleteCompany_TaiKhoanBiKhoa_HangGanVanBiGo.
//
// Cau dem loc users.is_active nen mot tai khoan bi khoa KHONG duoc dem - phan vung nay
// van qua duoc cua. Neu buoc go hang gan dac cach theo "nguoi quan tri" thi hang cua tai
// khoan bi khoa nam lai, va do la ca ma mot cua "go hang cua nguoi quan tri" bo sot.
func TestCompanyService_DeleteCompany_TaiKhoanBiKhoa_HangGanVanBiGo(t *testing.T) {
	db := testutil.Connect(t)
	svc := dungCompanyService(t, db)
	ctx := context.Background()

	congTyID := taoCongTy(t, db, "XO-"+uuid.NewString()[:8])
	qt := themNguoiCoVaiTro(t, db, congTyID, "qt-"+uuid.NewString()+"@test.local")
	datCoQuanTri(t, db, congTyID, qt)
	biKhoa := themNguoiCoVaiTro(t, db, congTyID, "khoa-"+uuid.NewString()+"@test.local")
	if _, err := db.Exec(`UPDATE users SET is_active = false WHERE id = $1`, biKhoa); err != nil {
		t.Fatalf("khoa tai khoan: %v", err)
	}

	if err := svc.DeleteCompany(ctx, actorHeThong(), congTyID); err != nil {
		t.Fatalf("DeleteCompany: %v", err)
	}
	if n := soHangGanConSong(t, db, congTyID); n != 0 {
		t.Fatalf("con %d hang gan song - hang cua tai khoan bi khoa bi bo sot", n)
	}
}
```

- [ ] **Bước 2: Chạy bốn bài, xác nhận đúng hai bài đỏ**

Chạy: `./cmd/dev test ./modules/auth/internal/service/ -run TestCompanyService_DeleteCompany -v`
Mong đợi: hai bài `Tra409` PASS ngay (cửa cũ đã chặn), hai bài còn lại FAIL.

Nếu bài `ChiNguoiQuanTri_XoaDuoc` PASS trước khi sửa code thì bối cảnh của nó dựng sai - phân vùng đang rỗng người. **Dừng và sửa bối cảnh.**

- [ ] **Bước 3: Sửa cửa chặn**

Thay khối `company_service.go:618-635`:

```go
	so, err := s.companyRepo.SoNguoiDangHoatDong(ctx, tx, id)
	if err != nil {
		return err
	}
	// ADR-0044 muc 5 noi cua nay dung MOT nac: "chua phat sinh du lieu" trong he nay la
	// "chua ai vao ngoai chinh nguoi quan tri ra doi cung phan vung".
	//
	// Truoc ADR-0039 cua "so > 0" du: mot phan vung vua tao la rong nguoi. Tu ADR-0039 moi
	// phan vung mang san mot nguoi, nen cua cu chan MOI phan vung tao qua giao dien.
	if so > 1 {
		return loiPhanVungConNguoiDung()
	}
	if so == 1 {
		nguoi, err := s.userCompanyRepo.NguoiQuanTriCuaPhanVung(ctx, tx, id)
		if err != nil {
			return err
		}
		if nguoi == nil {
			return loiPhanVungConNguoiDung()
		}
	}

	// Go MOI hang gan con song, khong rieng hang cua nguoi quan tri: cau dem tren loc
	// users.is_active nen mot tai khoan bi khoa khong duoc dem nhung hang gan cua no van
	// con. Day la cau ghi thu hai di duong ADR-0041, duoc ADR-0044 muc 7 ke ten.
	//
	// Cua "it nhat mot nguoi quan tri" cua ADR-0039 muc 3 KHONG ap o day, va ADR-0044 muc
	// 6 ghi ro dieu do: ve "it nhat mot" bao ve mot phan vung DANG SONG, con o day phan
	// vung bien mat nen no khong con doi tuong.
	if err := s.userCompanyRepo.SoftDeleteMoiHangGan(ctx, tx, id, actor.UserID); err != nil {
		return err
	}

	if err := s.companyRepo.SoftDelete(ctx, tx, id, actor.UserID); err != nil {
```

**Trước khi viết:** kiểm tên thật của method đọc người quản trị trên `UserCompanyRepository` - trong `user_company_repository.go` câu SQL tên là `nguoiQuanTriCuaPhanVungSQL`, nhưng **tên method có thể khác**. Đọc interface rồi dùng đúng tên; nếu nó trả `(*model.NguoiQuanTri, error)` với `sql.ErrNoRows` thay vì `nil`, sửa nhánh kiểm cho khớp.

Giữ nguyên **toàn bộ** khối comment TOCTOU dài phía trên câu đếm - nó nói về một thứ task này không đụng.

- [ ] **Bước 4: Chạy bốn bài, xác nhận xanh**

Chạy: `./cmd/dev test ./modules/auth/internal/service/ -run TestCompanyService_DeleteCompany -v`
Mong đợi: PASS cả bốn

- [ ] **Bước 5: Phép thử đột biến**

Đổi `if so > 1` thành `if so > 0` - bài `ChiNguoiQuanTri_XoaDuoc` phải đỏ. Gỡ lời gọi `SoftDeleteMoiHangGan` - hai bài cuối phải đỏ. Đổi `SoftDeleteMoiHangGan` thành `SoftDeleteTheoUser` với id người quản trị - bài `TaiKhoanBiKhoa` phải đỏ. Khôi phục sau khi đo.

- [ ] **Bước 6: Chạy cả module rồi commit**

Chạy: `./cmd/dev test ./modules/auth/...`
Mong đợi: `ok` cả bốn package. Bài nào của đợt trước đỏ vì cửa vừa nới thì **đọc nó** - nếu nó khoá đúng hành vi cũ mà ADR-0044 thay, sửa bài và ghi lý do vào commit; nếu nó khoá một hành vi ADR-0044 không nói tới, **dừng và báo**.

```bash
git add modules/auth/internal/service/company_service.go modules/auth/internal/service/company_service_test.go
git commit -m "feat(auth): DeleteCompany cho xoa phan vung chi con nguoi quan tri"
```

---

### Task 8: Cửa `is_active` ở đường đọc hồ sơ

**Files:**
- Sửa: `backend-erp/modules/auth/internal/service/auth_service.go:876` và khối xử lý ngay dưới
- Test: `backend-erp/modules/auth/internal/service/auth_service_test.go`

- [ ] **Bước 1: Viết bài test đỏ**

```go
// TestAuthService_DocHoSo_PhanVungNgungSuDung_Tra401.
//
// Cua nay dat tai CHO GOI chu khong trong SQL cua ByID, va do la ADR-0044 muc Mat: ByID
// dung chung voi mat quan tri, nhet AND is_active vao cau do thi khong bat lai duoc phan
// vung nao.
func TestAuthService_DocHoSo_PhanVungNgungSuDung_Tra401(t *testing.T) {
	// Bam theo bai da co cho ca "phan vung bi xoa mem giua chung mot phien" trong file
	// nay - DOC no truoc, no dung san toan bo boi canh; chi doi buoc tat tu
	// `UPDATE companies SET deleted_at = now()` thanh `SET is_active = false`.
}
```

- [ ] **Bước 2: Chạy bài, xác nhận nó đỏ**

Chạy: `./cmd/dev test ./modules/auth/internal/service/ -run TestAuthService_DocHoSo_PhanVungNgungSuDung -v`
Mong đợi: FAIL - trả về hồ sơ bình thường thay vì 401

- [ ] **Bước 3: Thêm cửa tại chỗ gọi**

Ngay sau khối `switch`/`if` xử lý kết quả `s.companyRepo.ByID` ở `auth_service.go:876`, thêm:

```go
	// Phan vung ngung su dung (ADR-0044 muc 1) dong phien y het phan vung bi xoa mem.
	//
	// Cua o DAY chu khong trong selectCompanyByIDSQL: cau do dung chung voi nam cho goi o
	// company_service.go, va mat quan tri PHAI doc duoc mot phan vung da ngung - khong thi
	// khong co duong bat lai. ADR-0044 phan Mat ghi ro rang buoc nay, va no khong co
	// checker nao ngoai hai bai test di hai chieu.
	if !cty.IsActive {
		log.FromContext(ctx).Warn("auth: doc ho so that bai",
			"ly_do", "phan vung da ngung su dung")
		return nil, loiPhienKhongHopLe()
	}
```

**Đọc đoạn 860-900 trước khi chèn**: tên biến (`cty`), hàm lỗi (`loiPhienKhongHopLe`) và khuôn ghi log phải khớp đúng thứ đang có ở đó. Dòng `ly_do` là một **hằng chuỗi**, không ghép giá trị nào từ request (P-OBS, R-16).

- [ ] **Bước 4: Chạy bài, xác nhận xanh**

Chạy: `./cmd/dev test ./modules/auth/internal/service/ -run TestAuthService_DocHoSo -v`
Mong đợi: PASS, và bài cũ về `deleted_at` vẫn PASS

- [ ] **Bước 5: Viết bài canh chiều ngược lại**

Đây là bài mà ADR-0044 phần Mất gọi tên. Đặt trong `company_service_test.go`:

```go
// TestCompanyService_MatQuanTri_VanDocDuocPhanVungDaNgung.
//
// Bai nay DO neu ai do nhet `AND is_active` vao selectCompanyByIDSQL hay vao hai cau
// liet ke cho gon. Khong co bai nay thi cua o Task 8 chi la mot loi hua: nguoi sua sau
// se thay cach "gon hon" va khong gi can ho lai.
func TestCompanyService_MatQuanTri_VanDocDuocPhanVungDaNgung(t *testing.T) {
	db := testutil.Connect(t)
	svc := dungCompanyService(t, db)
	ctx := context.Background()

	ma := "NG-" + uuid.NewString()[:8]
	congTyID := taoCongTy(t, db, ma)
	if _, err := db.Exec(`UPDATE companies SET is_active = false WHERE id = $1`, congTyID); err != nil {
		t.Fatalf("tat thang: %v", err)
	}

	c, err := svc.GetCompany(ctx, actorHeThong(), congTyID)
	if err != nil {
		t.Fatalf("mat quan tri khong doc duoc phan vung da ngung: %v", err)
	}
	if c.IsActive {
		t.Fatal("GetCompany tra IsActive = true cho mot phan vung da ngung")
	}

	// Loc bang Q theo dung ma vua tao chu khong list tran - cung ly do voi
	// TestCompanyService_ListCompanies_TraSoNguoiDungTheoTungDong: database test co san
	// cong ty DEFAULT va co the co ca cong ty do test khac de lai.
	rows, tong, err := svc.ListCompanies(ctx, actorHeThong(), service.ListCompaniesInput{
		Page: 1, PageSize: 20, Q: ma,
	})
	if err != nil {
		t.Fatalf("ListCompanies: %v", err)
	}
	if tong != 1 || len(rows) != 1 {
		t.Fatalf("tong=%d len=%d, muon 1/1 - phan vung da ngung bien mat khoi danh sach, khong con duong dung lai", tong, len(rows))
	}
	// `rows[0].Company.IsActive` chu khong `rows[0].IsActive`: CompanyRow BOC model.Company
	// trong mot field ten Company chu khong nhung no.
	if rows[0].Company.IsActive {
		t.Error("dong trong danh sach mang IsActive = true - man hinh se hien chip sai")
	}
}
```

- [ ] **Bước 6: Chạy, phép thử đột biến, commit**

Chạy bài mới, xác nhận PASS. Rồi thêm `AND is_active` vào `selectCompanyByIDSQL`, chạy lại - bài này phải **đỏ**. Khôi phục.

```bash
git add modules/auth/internal/service/auth_service.go modules/auth/internal/service/auth_service_test.go modules/auth/internal/service/company_service_test.go
git commit -m "feat(auth): phan vung ngung su dung dong phien, mat quan tri van doc duoc"
```

---

### Task 9: Handler và route `PUT /companies/:id/active`

**Files:**
- Sửa: `backend-erp/modules/auth/internal/handler/company_handler.go` - thêm DTO và handler
- Sửa: `backend-erp/modules/auth/internal/handler/company_routes.go` - thêm route
- Test: `backend-erp/modules/auth/internal/handler/company_handler_test.go`

- [ ] **Bước 1: Viết hai bài test đỏ**

```go
// TestCompanyHandler_DatTrangThai_NgungRoiDungLai_204.
//
// Gui `false` chu khong chi `true`, va do la ve chinh: `binding:"required"` tren mot bool
// TRAN tu choi gia tri false - gin coi zero value la thieu. Neu DTO dung bool tran thi
// bai nay do o ngay lan goi dau.
func TestCompanyHandler_DatTrangThai_NgungRoiDungLai_204(t *testing.T) {
	db := testutil.Connect(t)
	congTyID, _ := dungPhanVungKemUngVienHTTP(t, db)
	r := dungRouterCompany(t, db, auth.Actor{UserID: uuid.NewString(), Roles: []string{"quan_tri_he_thong"}})

	duong := "/api/v1/companies/" + congTyID + "/active"

	w := goi(t, r, http.MethodPut, duong, `{"is_active":false}`)
	if w.Code != http.StatusNoContent {
		t.Fatalf("PUT false status = %d, muon 204. Body: %s", w.Code, w.Body.String())
	}
	if w.Body.Len() != 0 {
		t.Errorf("204 co than %q - R-10 doi mot than rong", w.Body.String())
	}
	var con bool
	if err := db.Get(&con, `SELECT is_active FROM companies WHERE id = $1`, congTyID); err != nil {
		t.Fatalf("doc is_active: %v", err)
	}
	if con {
		t.Fatal("PUT tra 204 ma is_active van true")
	}

	w = goi(t, r, http.MethodPut, duong, `{"is_active":true}`)
	if w.Code != http.StatusNoContent {
		t.Fatalf("PUT true status = %d, muon 204. Body: %s", w.Code, w.Body.String())
	}
	if err := db.Get(&con, `SELECT is_active FROM companies WHERE id = $1`, congTyID); err != nil {
		t.Fatalf("doc lai is_active: %v", err)
	}
	if !con {
		t.Fatal("dung lai roi ma is_active van false")
	}
}

// TestCompanyHandler_DatTrangThai_ThieuField_400 canh chieu con lai cua bai tren: con tro
// khong duoc lam mat phep kiem "phai gui field".
//
// Than rong `{}` khac han `{"is_active":false}`. Neu bo `binding:"required"` di cho tien
// thi than rong se di qua va bi doc thanh false - tuc mot request khong noi gi lai ngung
// su dung mot phan vung.
func TestCompanyHandler_DatTrangThai_ThieuField_400(t *testing.T) {
	db := testutil.Connect(t)
	congTyID, _ := dungPhanVungKemUngVienHTTP(t, db)
	r := dungRouterCompany(t, db, auth.Actor{UserID: uuid.NewString(), Roles: []string{"quan_tri_he_thong"}})

	w := goi(t, r, http.MethodPut, "/api/v1/companies/"+congTyID+"/active", `{}`)
	if w.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, muon 400. Body: %s", w.Code, w.Body.String())
	}
	var con bool
	if err := db.Get(&con, `SELECT is_active FROM companies WHERE id = $1`, congTyID); err != nil {
		t.Fatalf("doc is_active: %v", err)
	}
	if !con {
		t.Fatal("than rong da tat duoc phan vung")
	}
}
```

**Kiểm mã trạng thái thật** mà `response.BindFailed` trả ra trước khi khoá `400` - đọc một bài `*_Tra422*` hay `BindFailed` có sẵn trong package handler. Nếu khuôn của hệ này là 422 thì sửa cả hai chỗ trong bài, đừng sửa `response.BindFailed` cho khớp bài.

- [ ] **Bước 2: Chạy hai bài, xác nhận chúng đỏ**

Chạy: `./cmd/dev test ./modules/auth/internal/handler/ -run TestCompanyHandler_DatTrangThai -v`
Mong đợi: FAIL - 404 vì route chưa có

- [ ] **Bước 3: Viết DTO, handler, route**

```go
// DatTrangThaiRequest la than cua PUT /companies/:id/active.
//
// Con tro chu khong bool tran, va day khong phai tham my: `binding:"required"` tren mot
// bool tran TU CHOI gia tri false - gin coi zero value la thieu. Voi mot co hai gia tri
// thi nua so lan bam nut se an 400. Con tro tach duoc "khong gui field" khoi "gui false".
//
// KHONG co field nao ten `company_id` (checkR06, ADR-0040 muc 2): phan vung di vao qua
// path param `:id`.
type DatTrangThaiRequest struct {
	IsActive *bool `json:"is_active" binding:"required"`
}

// DatTrangThai xu ly PUT /api/v1/companies/:id/active - tra 204 khong body (R-10).
//
// PUT chu khong POST: thao tac DAT mot gia tri, goi hai lan cung mot body cho ra cung mot
// trang thai.
func (h *CompanyHandler) DatTrangThai(c *gin.Context) {
	var req DatTrangThaiRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BindFailed(c, err)
		return
	}

	ctx := c.Request.Context()
	actor := auth.FromContext(ctx)

	if err := h.svc.DatTrangThaiSuDung(ctx, actor, c.Param("id"), *req.IsActive); err != nil {
		response.Error(c, err)
		return
	}
	response.NoContent(c)
}
```

`company_routes.go`, thêm dưới hai route `/admin`:

```go
	// Bat / tat mot phan vung (ADR-0044). Param `:id` chu khong `:company_id`, cung rang
	// buoc gin va cung phep bat cua checkR06 nhu hai route tren.
	v1.PUT("/companies/:id/active", xacThuc, h.DatTrangThai)
```

Sửa dòng comment đầu file: "Cả bảy route" thành "Cả tám route".

- [ ] **Bước 4: Chạy hai bài, xác nhận xanh**

Chạy: `./cmd/dev test ./modules/auth/internal/handler/ -run TestCompanyHandler_DatTrangThai -v`
Mong đợi: PASS cả hai

- [ ] **Bước 5: Commit**

```bash
git add modules/auth/internal/handler/company_handler.go modules/auth/internal/handler/company_routes.go modules/auth/internal/handler/company_handler_test.go
git commit -m "feat(auth): PUT /companies/:id/active"
```

---

### Task 10: `GET /companies` trả `is_active` và lọc được theo nó

**Files:**
- Sửa: `backend-erp/modules/auth/internal/handler/company_handler.go` - DTO trả về của `List` và `Get`
- Sửa: `backend-erp/modules/auth/internal/repository/company_repository.go` - `ListCompanyQuery` thêm trường lọc, ba câu SQL thêm mệnh đề
- Sửa: `backend-erp/modules/auth/internal/service/company_service.go` - truyền trường lọc xuống
- Test: `backend-erp/modules/auth/internal/handler/company_handler_test.go`, `backend-erp/modules/auth/internal/repository/company_trang_thai_db_test.go`

- [ ] **Bước 1: Viết hai bài test đỏ**

```go
// TestCompanyHandler_List_TraIsActive: man Quan tri phai ve duoc chip trang thai.
//
// Doi dung khoa JSON `is_active` chu khong doi kieu Go: client doc khoa do, va doi ten no
// la mot breaking ma bo kiem Go khong thay.
func TestCompanyHandler_List_TraIsActive(t *testing.T) {
	db := testutil.Connect(t)
	ma := "LS-" + uuid.NewString()[:8]
	congTyID := taoCongTyHTTP(t, db, ma)
	if _, err := db.Exec(`UPDATE companies SET is_active = false WHERE id = $1`, congTyID); err != nil {
		t.Fatalf("tat thang: %v", err)
	}
	r := dungRouterCompany(t, db, auth.Actor{UserID: uuid.NewString(), Roles: []string{"quan_tri_he_thong"}})

	w := goi(t, r, http.MethodGet, "/api/v1/companies?q="+ma, "")
	if w.Code != http.StatusOK {
		t.Fatalf("status = %d, muon 200. Body: %s", w.Code, w.Body.String())
	}
	env := docEnvelope(t, w)

	var dong []map[string]any
	if err := json.Unmarshal(env.Data, &dong); err != nil {
		t.Fatalf("data khong doc duoc thanh mang: %v (data=%s)", err, env.Data)
	}
	if len(dong) != 1 {
		t.Fatalf("tra %d dong, muon 1 - q khong loc", len(dong))
	}
	con, co := dong[0]["is_active"]
	if !co {
		t.Fatalf("dong khong co khoa is_active - man hinh khong ve duoc chip trang thai. Dong: %v", dong[0])
	}
	if con != false {
		t.Errorf("is_active = %v, muon false", con)
	}
}

// TestCompanyHandler_List_LocTheoTrangThai: ba ve, va ve thu ba quan trong nhat.
//
// `?trang_thai=ngung` tra dung phan vung da ngung; `?trang_thai=dang_dung` tra dung phan
// vung dang dung; KHONG truyen gi thi tra CA HAI.
//
// Ve thu ba la mac dinh hien ca hai (spec muc 5). Mot mac dinh an di se lam nguoi tao
// nham mot phan vung roi ngung no khong bao gio thay lai no, va do la dung ca ma ca don
// nay sinh ra de chua.
func TestCompanyHandler_List_LocTheoTrangThai(t *testing.T) {
	db := testutil.Connect(t)
	tienTo := "LC-" + uuid.NewString()[:6]
	dangDungID := taoCongTyHTTP(t, db, tienTo+"-A")
	ngungID := taoCongTyHTTP(t, db, tienTo+"-B")
	if _, err := db.Exec(`UPDATE companies SET is_active = false WHERE id = $1`, ngungID); err != nil {
		t.Fatalf("tat thang: %v", err)
	}
	r := dungRouterCompany(t, db, auth.Actor{UserID: uuid.NewString(), Roles: []string{"quan_tri_he_thong"}})

	doc := func(t *testing.T, truyVan string) []string {
		t.Helper()
		w := goi(t, r, http.MethodGet, "/api/v1/companies?q="+tienTo+truyVan, "")
		if w.Code != http.StatusOK {
			t.Fatalf("status = %d, muon 200. Body: %s", w.Code, w.Body.String())
		}
		var dong []struct {
			ID string `json:"id"`
		}
		if err := json.Unmarshal(docEnvelope(t, w).Data, &dong); err != nil {
			t.Fatalf("data khong doc duoc: %v", err)
		}
		ids := make([]string, 0, len(dong))
		for _, d := range dong {
			ids = append(ids, d.ID)
		}
		return ids
	}

	if ids := doc(t, ""); len(ids) != 2 {
		t.Fatalf("khong truyen trang_thai tra %d dong, muon 2 - mac dinh phai hien CA HAI", len(ids))
	}
	if ids := doc(t, "&trang_thai=dang_dung"); len(ids) != 1 || ids[0] != dangDungID {
		t.Fatalf("trang_thai=dang_dung tra %v, muon dung [%s]", ids, dangDungID)
	}
	if ids := doc(t, "&trang_thai=ngung"); len(ids) != 1 || ids[0] != ngungID {
		t.Fatalf("trang_thai=ngung tra %v, muon dung [%s]", ids, ngungID)
	}
}
```

`taoCongTyHTTP` là helper phải viết trong package handler test (bản `taoCongTy` nằm ở package service). **Đọc `dungPhanVungKemUngVienHTTP` ở `company_handler_test.go:142` trước** - nó đã chèn một phân vùng, nhiều khả năng chỉ cần tách phần đó ra.

- [ ] **Bước 2: Chạy hai bài, xác nhận chúng đỏ**

Chạy: `./cmd/dev test ./modules/auth/... -run 'TestCompanyHandler_List_TraIsActive|TestList_LocTheoTrangThai' -v`
Mong đợi: FAIL

- [ ] **Bước 3: Thi công**

Trường lọc phải đi qua **hai** struct, không một: `ListCompanyQuery` của repository và `ListCompaniesInput` của service. Chúng là hai kiểu khác nhau - thêm vào một cái rồi tưởng xong là bộ lọc im lặng không có tác dụng, và bài `LocTheoTrangThai` sẽ đỏ ở vế `dang_dung`.

`ListCompanyQuery` thêm:

```go
	// TrangThai loc theo cot is_active. Ba gia tri: "" (ca hai - MAC DINH), "dang_dung",
	// "ngung".
	//
	// Mac dinh la CA HAI chu khong "dang_dung", va do la lua chon co y (spec muc 5): phan
	// vung dem bang chuc chu khong nghin dong nhu danh muc vat tu, va mot mac dinh an di
	// lam nguoi tao nham mot phan vung roi ngung no khong bao gio thay lai no.
	TrangThai string
```

Ba câu SQL (`countCompaniesSQL`, hai câu `listCompanies*`) thêm vào `WHERE`:

```sql
  AND ($4 = '' OR ($4 = 'dang_dung' AND is_active) OR ($4 = 'ngung' AND NOT is_active))
```

Đánh lại số tham số cho khớp thứ tự thật của từng câu - `countCompaniesSQL` chỉ có `$1` nên tham số mới là `$2`; hai câu liệt kê có `$1..$3` nên là `$4`. **Đếm lại trong từng câu, không chép số từ đây.**

DTO trả về của handler thêm `IsActive bool \`json:"is_active"\`` và điền từ `model.Company`. Struct bind query thêm `TrangThai string \`form:"trang_thai"\`` - **không** đặt tên field là `company_id` dưới bất kỳ hình thức nào.

- [ ] **Bước 4: Chạy hai bài, xác nhận xanh**

Chạy: `./cmd/dev test ./modules/auth/... -run 'TestCompanyHandler_List_TraIsActive|TestList_LocTheoTrangThai' -v`
Mong đợi: PASS

- [ ] **Bước 5: Commit**

```bash
git add modules/auth/internal/repository/company_repository.go modules/auth/internal/service/company_service.go modules/auth/internal/handler/company_handler.go modules/auth/internal/handler/company_handler_test.go modules/auth/internal/repository/company_trang_thai_db_test.go
git commit -m "feat(auth): GET /companies tra is_active va loc theo trang thai"
```

---

### Task 11: Nhãn quyền, và chữ "vô hiệu hoá" biến mất khỏi backend

**Files:**
- Sửa: `backend-erp/cmd/internal/vaitro/nhan_quyen.go:74`
- Sửa: `backend-erp/modules/auth/internal/service/company_service.go:927-930` - thông điệp của `loiPhanVungConNguoiDung`
- Sửa: `backend-erp/modules/auth/internal/repository/company_repository.go` - hai khối comment dùng chữ "vo hieu hoa"

- [ ] **Bước 1: Tìm hết chỗ còn chữ đó**

Chạy: `grep -rn "vo hieu hoa\|vô hiệu hoá\|vô hiệu hóa" --include=*.go .`

Ghi lại danh sách. Chỗ nào nói về `deleted_at` thì đổi thành "xoá"; chỗ nào nói về cột mới thì đổi thành "ngừng sử dụng". **Không đổi chữ trong ADR đã Accepted và trong migration đã chạy** - cả hai đều bất biến.

- [ ] **Bước 2: Sửa nhãn quyền**

```go
		{Ma: auth.PermCompanyDelete, Nhan: "Ngừng sử dụng / xoá phân vùng", Nhom: nhomPhanVung, PhanHe: "auth", NhanPhanHe: nhanPhanHeAuth},
```

- [ ] **Bước 3: Sửa thông điệp lỗi**

```go
func loiPhanVungConNguoiDung() error {
	return apperr.Conflict(apperr.CodeAuthCompanyInUse,
		"Phân vùng còn người dùng đang làm việc nên không xoá được. Ngừng sử dụng nó nếu bạn chỉ muốn tạm dừng.")
}
```

Thông điệp này ra thẳng màn hình nên **phải có dấu** - đó là lỗi đợt trước đã sửa hai lần. Và nó chỉ đường sang thao tác đúng thay vì bỏ người dùng ở ngõ cụt.

- [ ] **Bước 4: Chạy cả bộ**

Chạy: `./cmd/dev check && ./cmd/dev test ./modules/auth/... ./cmd/...`
Mong đợi: xanh hết. Bài nào khoá chuỗi thông điệp cũ thì sửa bài cho khớp chữ mới.

- [ ] **Bước 5: Commit**

```bash
git add cmd/internal/vaitro/nhan_quyen.go modules/auth/internal/service/company_service.go modules/auth/internal/repository/company_repository.go
git commit -m "refactor(auth): bo chu 'vo hieu hoa', tach 'ngung su dung' khoi 'xoa'"
```

---

### Task 12: Chạy trọn bộ và ghi bằng chứng

- [ ] **Bước 1: Chạy toàn bộ module auth trên PostgreSQL thật**

```bash
ssh deploy@103.179.172.110 'bash -lc "cd /tmp/<worktree> && ./cmd/dev test ./modules/auth/... ./cmd/... 2>&1 | tail -20"'
```

Mong đợi: `ok` cho cả bốn package `auth`, `auth/internal/handler`, `auth/internal/repository`, `auth/internal/service`, cộng `cmd/internal/vaitro`.

- [ ] **Bước 2: Chạy bộ kiểm kiến trúc**

Chạy: `./cmd/dev check`
Mong đợi: xanh. `ERP_DOCS_PATH` phải trỏ tới `docs-erp` thật, không thì `arch` và registry đỏ oan.

- [ ] **Bước 3: Đo trạng thái database sau migration**

```sql
SELECT count(*) FILTER (WHERE is_active) AS dang_dung,
       count(*) FILTER (WHERE NOT is_active) AS da_ngung
FROM companies WHERE deleted_at IS NULL;
```

Mong đợi: `da_ngung = 0` ngay sau migration - không backfill nào đặt cờ.

- [ ] **Bước 4: Dán output thật vào bàn giao**

Không viết "test xanh" mà không kèm output. Số dòng `ok` và thời gian chạy là bằng chứng; một câu khẳng định thì không.

---

## Còn lại sau plan này

- **Frontend** - một plan riêng: cột trạng thái và bộ lọc ở `CompanyListPage`, tách khối "Vô hiệu hoá" thành hai ở `CompanyFormPage`, hook `use-dat-trang-thai-company`.
- **Bấm tay trên dev** sau khi frontend xong. Đợt trước 1276 test xanh vẫn để lọt bốn thông điệp câm - bài "mặt quản trị vẫn đọc được phân vùng đã ngừng" ở Task 8 là loại lỗi mà chỉ một lần bấm mới thấy hết.
