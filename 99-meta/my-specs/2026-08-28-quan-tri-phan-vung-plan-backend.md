# Kế hoạch thi công backend: màn Quản trị phân vùng chạy số liệu thật

> **Cho agent thi công:** dùng `superpowers:subagent-driven-development`, mỗi task một subagent
> mới. Bước đánh dấu `- [ ]`.

**Mục tiêu:** bốn phần việc P0-P3 của
[thiết kế](2026-08-28-quan-tri-phan-vung-design.md), tất cả ở `backend-erp`.

**Nền:** [ADR-0039](../../03-decisions/ADR-0039-mot-nguoi-quan-tri-moi-phan-vung.md),
[ADR-0040](../../03-decisions/ADR-0040-doc-cheo-phan-vung-neo-vao-companies.md).

**Ngăn xếp:** Go 1.26, Gin, sqlx, golang-migrate, PostgreSQL. Máy dev **không chạy được
Docker** — mọi test cần database lấy bằng chứng từ CI, `go run ./cmd/dev check` thì chạy được
tại chỗ.

**Luật chung cho mọi task:**
- Cây làm việc dùng chung nhiều phiên: **cấm `git add -A`**, liệt kê từng đường dẫn.
- Comment tiếng Việt **có dấu**; định danh Go không dấu.
- Mọi method service public: câu lệnh đầu tiên là kiểm quyền (R-15).
- Mọi thao tác ghi sinh audit trong **cùng** transaction (R-17).
- Sau mỗi task: `go run ./cmd/dev check` phải xanh. **Đừng chạy `cmd/dev test`** (cần Docker).

---

## Task 1 — P0: phép đếm người của phân vùng đang đếm sai

**Files:** sửa `modules/auth/internal/repository/company_repository.go`; test ở
`modules/auth/internal/repository/company_repository_test.go`.

`countActiveUsersOfCompanySQL` lọc `users.company_id` — *nơi tài khoản được tạo ra*. Đúng phải
là *ai đang làm việc ở đó*, tức đi qua `user_companies`. Đính chính ADR-0034 ngày 2026-08-28
đã áp hình dạng này cho `UserRepository`; câu này nằm ở `CompanyRepository` nên lọt khỏi đợt rà.

- [ ] **B1: test đỏ.** Dựng một người thuộc phân vùng A (hàng `users.company_id = A`) rồi gán
  thêm vào phân vùng B qua `user_companies`. Khẳng định `SoNguoiDangHoatDong(B)` trả `1`.
  Test này **đỏ** trước khi sửa vì câu cũ đếm theo `users.company_id`.
- [ ] **B2:** chạy trên CI hoặc máy có Postgres → ĐỎ. Ghi lại output.
- [ ] **B3:** đổi câu SQL sang `JOIN user_companies gan ON ... WHERE gan.company_id = $1 AND
  gan.deleted_at IS NULL AND u.deleted_at IS NULL AND u.is_active`. Bám đúng hình dạng
  `countUsersSQL` của `user_repository.go`.
- [ ] **B4:** test XANH. `go run ./cmd/dev check` xanh.
- [ ] **B5:** commit `fix(auth): dem nguoi cua phan vung theo user_companies, khong theo users.company_id`.

---

## Task 2 — P1a: migration `is_admin` và backfill

**Files:** tạo `migrations/0000NN_user_companies_is_admin.{up,down}.sql`.

- [ ] **B1:** `ALTER TABLE user_companies ADD COLUMN is_admin BOOLEAN NOT NULL DEFAULT false;`
- [ ] **B2:** `CREATE UNIQUE INDEX uq_user_companies_admin ON user_companies(company_id)
  WHERE is_admin AND deleted_at IS NULL;`
- [ ] **B3: backfill, và nó phải KHÔNG đoán.** Đánh dấu `is_admin = true` cho phân vùng có
  **đúng một** người còn sống giữ `auth.role_assign` (đi qua `user_companies` →
  `user_company_roles` → `roles` → `role_permissions`, `deleted_at IS NULL` trên cả bốn).
  Phân vùng có 0 hoặc 2+ người thì **không đụng tới** (ADR-0039 mục 5). Ghi comment nói rõ
  vì sao không đoán.
- [ ] **B4:** in ra số phân vùng được đánh dấu và số phân vùng bỏ qua, theo lối `DO $$` mà
  `000030_email_phone_duy_nhat_toan_he.up.sql` đã dùng — người chạy migration phải thấy có
  bao nhiêu đơn vị đang không có người quản trị.
- [ ] **B5:** file `.down.sql`: drop index rồi drop cột.
- [ ] **B6:** `go run ./cmd/dev check` xanh (R-07 đòi cặp up/down, R-09 đòi index có lý do).
- [ ] **B7:** commit `feat(auth): user_companies.is_admin va rang buoc mot quan tri moi phan vung`.

---

## Task 3 — P1b: đọc và đặt người quản trị

**Files:** `modules/auth/internal/repository/user_company_repository.go`,
`modules/auth/internal/service/company_service.go`,
`modules/auth/internal/handler/company_handler.go`, `company_routes.go`, và test tương ứng.

- [ ] **B1: repository.** Thêm `NguoiQuanTri(ctx, db, companyID) (*model.NguoiQuanTri, error)`
  — trả `nil` khi chưa có — và `DatNguoiQuanTri(ctx, tx, companyID, userCompanyID, actorID)
  error`. Câu đọc dùng lại bộ JOIN của `demNguoiGiuQuyenSQL`; câu ghi hạ cờ cũ rồi dựng cờ
  mới **trong cùng một câu hoặc cùng một transaction**, vì partial unique index sẽ từ chối
  trạng thái trung gian hai cờ.
- [ ] **B2: test bằng chứng của ADR-0039.** Chèn thẳng hai hàng `is_admin = true` cùng một
  `company_id` → phải nhận lỗi `23505` trên `uq_user_companies_admin`. Test này chứng minh
  ràng buộc nằm ở database chứ không ở service; thiếu nó thì cả ADR-0039 chỉ là một lời hứa.
- [ ] **B3: service.** `CompanyService.NguoiQuanTri(ctx, actor, companyID)` gác bằng
  `PermCompanyRead` (ADR-0040 vế 3); `CompanyService.DatNguoiQuanTri(ctx, actor, companyID,
  userID)` gác bằng `PermCompanyUpdate`, rồi kiểm người đó **là thành viên** phân vùng và
  **đang giữ** `auth.role_assign` (ADR-0039 mục 4), rồi ghi audit trong cùng tx.
- [ ] **B4: mã lỗi.** Người được đặt không phải thành viên, hoặc không giữ `auth.role_assign`
  → 422 kèm `error.fields` trỏ vào `user_id`. Thêm mã vào `shared/errors/codes.go` **và** một
  dòng vào bảng C-API-05 của `docs-erp` — hai chỗ đó là một cặp.
- [ ] **B5: handler + route.** `GET /companies/:id/admin`, `PUT /companies/:id/admin`. Param
  tên `:id`, DTO **không** mang field `company_id` (ADR-0040 vế 2, và R-06 vẫn bắt vế này).
- [ ] **B6: test không cần database** cho mọi cửa chặn ở service, dựng bằng fake repo.
- [ ] **B7:** `go run ./cmd/dev check` xanh. Commit.

---

## Task 4 — P1c: cửa "ít nhất một người quản trị"

**Files:** `modules/auth/internal/service/user_service.go` và test.

- [ ] **B1: test đỏ.** Gỡ người quản trị duy nhất khỏi phân vùng → phải 422, không phải 204.
  Hạ vai trò mang `auth.role_assign` của người quản trị duy nhất → cũng 422.
- [ ] **B2:** chạy → ĐỎ.
- [ ] **B3:** thêm cửa chặn vào `GoKhoiPhanVung` và `ThayVaiTro`. Dùng lại
  `DemNguoiGiuQuyen`, vốn đã trả đúng hai con số cần cho phép thử này.
- [ ] **B4:** test XANH, `check` xanh, commit.

---

## Task 5 — P2: danh sách người trong một phân vùng

**Files:** `user_repository.go` (hoặc method mới nhận `companyID` bất kỳ),
`company_service.go`, `company_handler.go`, `company_routes.go`, test.

- [ ] **B1:** `GET /companies/:id/users` — phân trang + whitelist sort theo đúng hình dạng
  `GET /users` (R-12). Service gác **`PermCompanyRead` là câu lệnh đầu tiên** rồi mới tới
  `PermUserList` — thứ tự đó là điều ADR-0040 vế 3 đòi.
- [ ] **B2: test chốt hình dạng ngoại lệ.** Khẳng định DTO query **không** có field
  `company_id` và handler **không** gọi `c.Query("company_id")` — hai vế mà ADR-0040 cố ý
  không nới, và `checkR06` vẫn đang bắt.
- [ ] **B3:** `check` xanh. Commit.

---

## Task 6 — P3: tạo phân vùng kèm người quản trị đầu tiên

**Files:** `company_service.go`, `company_handler.go`, DTO, test.

- [ ] **B1:** `POST /companies` nhận thêm `admin_email`, `admin_full_name`, `admin_password`.
- [ ] **B2:** bcrypt **trước** `BeginTxx` (P-TXN — khuôn có sẵn ở `user_service.go`).
- [ ] **B3:** một transaction, sáu lần ghi: `companies` → bộ vai trò mặc định (đã có) →
  `users` → `user_companies` với `is_admin = true` → `user_company_roles` với `auth.admin` →
  hai dòng audit `company.created` và `user.created`.
- [ ] **B4: ca email đã tồn tại toàn hệ.** `uq_users_email_active` nay là toàn hệ (ADR-0034
  mục 1), nên người quản trị đầu tiên **có thể là người đã có ở phân vùng khác**. Ca đó đi qua
  `ByEmailToanHeRutGon` + `InsertNguoiConSong`, **không** trả 409.
- [ ] **B5: kiểm nợ của ADR-0038.** Bộ 7 vai trò của phân vùng mới có được đặt `is_system =
  true` không? Nếu không thì mục 3 của ADR-0038 rỗng ruột ở đúng phân vùng đó — sửa và nói ra
  trong commit.
- [ ] **B6:** test không cần database cho phép kiểm đầu vào; test cần database cho đường thuận
  và cho ca email đã tồn tại.
- [ ] **B7:** `check` xanh. Commit.

---

## Task 7 — ghim lại băm RULES.md và lấy bằng chứng

- [ ] **B1:** `docs-erp` lên `main` **trước** (job `arch` của backend checkout `docs-erp`
  cùng ref).
- [ ] **B2:** `go run ./cmd/dev arch-pin` rồi commit băm mới — `RULES.md` đã đổi dòng
  `Decisions` của R-06.
- [ ] **B3:** `go run ./cmd/dev check` xanh, `go build ./...` xanh.
- [ ] **B4:** đẩy `backend-erp`, đọc job `test` trên `main` (đường đọc CI ghi ở memory
  `github-account-erp-hanh`).
- [ ] **B5:** viết file bàn giao, **tối đa 120 dòng**, kèm output thật của job `test`.

---

## Xong khi nào

- `go run ./cmd/dev check` xanh.
- Job `test` trên `main` xanh, có log dán vào file bàn giao.
- Test "hai hàng `is_admin` cùng một phân vùng bị database từ chối" xanh — đây là bằng chứng
  của ADR-0039, thiếu nó thì phần còn lại không chứng minh được gì.
- Frontend chưa làm, và nói rõ điều đó: màn hình vẫn còn dữ liệu giả cho tới đợt sau.
