# Thiết kế: đường gán Data Scope (backend + màn hình)

**Ngày:** 2026-08-20
**Trạng thái:** đã chốt với người dùng, chờ viết plan thi công
**Nền:** [ADR-0020](../../03-decisions/ADR-0020-data-scope-theo-ban-ghi.md),
[ADR-0019](../../03-decisions/ADR-0019-phan-vung-la-cong-ty.md),
[ADR-0010](../../03-decisions/ADR-0010-bang-vai-tro-o-cmd-internal.md),
C-GO-09 trong [C-GO-backend.md](../../04-conventions/C-GO-backend.md)

## 1. Vấn đề

Ba bảng gán đã chạy thật từ migration `000021`-`000023`, và đường ĐỌC phạm vi đã chạy thật
cho module `inventory`: `scope.Resolver` giải phạm vi ngay sau `authz.Can`, repository nhận
`scope.Pham`, quên áp phạm vi là lỗi biên dịch.

Chưa có đường GHI nào. Muốn gán một kho cho một người hôm nay phải `INSERT` tay vào
`user_company_role_scopes`. Đây đúng là món nợ ADR-0020 đã ghi: *"Chưa có đường API nào để
gán phạm vi cho một người. Màn hình phân quyền là việc của một chặng riêng."*

Chặng này trả món nợ đó, cho đúng một loại phạm vi đang tồn tại (`warehouse`).

## 2. Kết quả audit trước khi thiết kế

| Thứ | Trạng thái |
|---|---|
| `user_company_role_scopes` | có bảng, có unique index, **không có đường ghi**; đã khai trong `modules/auth/module.yaml` |
| Permission gán phạm vi | **không tồn tại**; gần nhất là `auth.user_assign_roles` (`internal/service/permissions.go:42`) |
| `*_scope_all` | đúng một: `inventory.warehouse_scope_all`, chỉ vai trò `admin` có (`cmd/internal/vaitro/vaitro.go:297`) |
| Đường ghi vai trò | không có route riêng, đi ghép trong `PATCH /users/:id` (`user_service.go:508`) |
| Frontend | **không có màn người dùng nào**; `src/app/ung-dung.ts:187` ghi "Chưa có màn" |
| Mockup | `mockup-erp/quan-tri-phan-quyen.html` có màn gán *vai trò*, chưa có phạm vi — **file đã bị xoá 2026-08-21**, thay bằng `mockup-erp/nguoi-dung-chi-tiet.html`; lý do xoá và ba luật cứu ra ở `2026-08-21-luat-gan-vai-tro-spec.md` |

Hai kết luận có giá trị cho việc thi công:

**Không cần migration mới, không cần index mới.** Unique index
`uq_user_company_role_scopes_company_role_scope_type_scope(company_id, user_company_role_id,
scope_type, scope_id) WHERE deleted_at IS NULL` phục vụ trọn cả câu đọc lẫn câu xoá mềm bằng
tiền tố cột; `uq_user_company_roles(company_id, user_company_id, role_code)` phục vụ bước tra
hàng vai trò; `uq_user_companies(company_id, user_id)` phục vụ bước tra hàng gán. Không câu
SQL nào của chặng này lọc theo một cột không có index dẫn đầu (R-07, R-09).

**Không đụng C-GO-09.** Ba bảng gán không phải "bảng chịu phạm vi" - chúng là bảng *khai báo*
phạm vi, không phải bảng *chịu* nó. Đường ghi mới nhận `scope.Loai` và `[]string`, **không**
nhận `scope.Pham`, nên vế 3 của checker (module nhận `Pham` mà không khai `scoped_tables`)
không đỏ. `modules/auth/module.yaml` không phải sửa một chữ.

## 3. Quyết định đã chốt

1. **Actor được gán phạm vi là admin phân vùng.** Permission mới `auth.user_assign_scopes`,
   cấp cho vai trò `admin`. `quan_tri_he_thong` **không** được cấp trong chặng này: ADR-0019
   mục 5 chốt vai trò đó giữ *đúng năm quyền* `PermCompany*`, và nó cũng không có
   `auth.user_list`/`auth.user_read` nên sẽ có nút Lưu mà không có đường tìm ra người để gán.
   Mở quyền cho nó kéo theo câu hỏi lớn hơn về phạm vi toàn hệ thống - để **ADR-0021** chốt
   riêng.

2. **Giao diện theo NGƯỜI, hiện từng vai trò.** Màn mở theo một người trong phân vùng, bên
   trong tách thành từng khối vai trò, mỗi khối một bộ phạm vi riêng. Mô hình dữ liệu không
   đổi: scope vẫn treo vào từng hàng `user_company_roles`, **không** gom thành scope của user.

3. **`PUT` cập nhật TOÀN BỘ các assignment đang hiển thị**, không phải "set scope cho user".
   Đây là điều kiện cứng: một người mang hai vai trò với hai bộ phạm vi khác nhau phải giữ
   được hai bộ đó sau khi lưu. Body mang danh sách hàng vai trò, mỗi hàng mang bộ phạm vi của
   chính nó.

4. **`toan_pham_vi` là một trạng thái riêng**, không phải một danh sách kho. UI không được
   dịch nó thành "đã chọn tất cả".

5. **403 xử tại chỗ, không suy diễn quyền từ role ở frontend.** Không cache, không thêm
   abstraction hay component dùng chung trong chặng này.

6. **Vertical slice là hai màn**: `/nguoi-dung` và `/nguoi-dung/:id/pham-vi`. Không tách, vì
   không có màn danh sách thì màn phạm vi không có entry point hợp lệ.

## 4. Backend

### 4.1 Permission

`modules/auth/internal/service/permissions.go`:

```go
// PermUserAssignScopes la quyen CAP/THU HOI pham vi du lieu cua nguoi khac.
PermUserAssignScopes = "auth.user_assign_scopes"
```

Tái xuất ở `modules/auth/module.go` (C-GO-08, vì `cmd/**` bị R-01 cấm import
`internal/service`). Cấp cho `admin` trong `cmd/internal/vaitro/vaitro.go`, khối auth
(`:227-234`).

Đường ĐỌC dùng lại `auth.user_read` - không đẻ quyền đọc riêng: ai đọc được hồ sơ một người
thì đọc được phạm vi của người đó, và tập kho vốn nằm sau `inventory.warehouse_list` mà mọi
vai trò trong phân vùng đều có.

### 4.2 Danh mục loại phạm vi tiêm từ composition root

Tập loại phạm vi hợp lệ sống ở `cmd/api` - nơi duy nhất đã biết
`map[scope.Loai]scope.Nguon` (`cmd/api/main.go:184`). Module `auth` nhận nó qua `Deps`, đúng
khuôn `Authz`/`Audit` đang chạy:

```go
// modules/auth/module.go
type PhamViKhaDung struct {
	Loai         scope.Loai  // "warehouse"
	Nhan         string      // "Kho" - chu hien tren man hinh
	PermToanPham string      // "inventory.warehouse_scope_all"
	Nguon        scope.Nguon // de kiem id gan vao co that trong phan vung khong
}

type Deps struct {
	// ...
	LoaiPhamVi []PhamViKhaDung
}
```

Ba lý do phải đi đường này thay vì hằng trong `auth`:

- Tên permission toàn phạm vi thuộc module sở hữu tài nguyên; để nó ở `auth` là kéo `auth`
  phụ thuộc `inventory` (R-05, `allowed_deps: []`).
- `Nguon` là thứ duy nhất trả lời được "kho này có thật trong phân vùng không" mà không phải
  import `modules/inventory`. Đây là chỗ duy nhất bù được việc `scope_id` **không** mang khoá
  ngoại (ADR-0020 mục 2).
- Frontend không được hằng số hoá danh sách loại (cùng lập luận ADR-0010 dùng cho danh sách
  vai trò), nên danh sách phải đi ra từ API.

`cmd/api/main.go` dựng đúng một danh sách và dùng nó cho cả hai chỗ: `scope.New(...)` và
`auth.New(...)`. Hai bản sao của cùng một danh sách là chỗ để chúng lệch nhau.

### 4.3 Hai endpoint

Gắn vào `RegisterUserRoutes` (`internal/handler/user_routes.go`), tiền tố `/api/v1` vẫn dựng
đúng một lần ở router (R-13, C-API-06):

```
GET /api/v1/users/:id/scopes   -> auth.user_read
PUT /api/v1/users/:id/scopes   -> auth.user_assign_scopes
```

**`GET` trả về** (và `PUT` trả về **cùng hình dạng này**, đọc lại trong chính transaction, để
frontend không phải gọi lại - đúng khuôn `CreateUser` đọc ngược vai trò từ bảng):

```json
{
  "data": {
    "user_id": "...",
    "vai_tro": [
      {
        "user_company_role_id": "...",
        "role_code": "member",
        "pham_vi": [
          { "loai": "warehouse", "nhan": "Kho", "toan_pham_vi": false,
            "ids": ["...", "..."] }
        ]
      },
      {
        "user_company_role_id": "...",
        "role_code": "admin",
        "pham_vi": [
          { "loai": "warehouse", "nhan": "Kho", "toan_pham_vi": true, "ids": [] }
        ]
      }
    ]
  }
}
```

- `vai_tro` liệt kê **mọi hàng `user_company_roles` còn sống** của người đó trong phân vùng
  đang mở. Người chưa được gán vai trò nào trả mảng rỗng.
- `pham_vi` liệt kê **mọi loại** trong `LoaiPhamVi`, kể cả loại chưa gán gì (`ids: []`).
  Mảng rỗng nghĩa là **không thấy gì**, không bao giờ nghĩa là tất cả (luật cứng của
  `shared/scope`).
- `toan_pham_vi` tính bằng `s.authz.Can(ctx, actorDungTaiCho, permToanPham)` với một
  `auth.Actor{CompanyID: actor.CompanyID, Roles: []string{roleCode}}`. Không thêm method nào
  vào `shared/authz` - `Can` vốn chỉ tra bảng theo `Roles`. Không có trường này thì người
  dùng gán ba kho cho `admin` rồi không hiểu vì sao `admin` vẫn thấy hết.
- Không trả tên kho. Frontend đã có `GET /api/v1/warehouses`, và người gán vốn phải đọc được
  kho mới gán được kho.

**`PUT` nhận:**

```json
{
  "vai_tro": [
    { "user_company_role_id": "...",
      "pham_vi": [ { "loai": "warehouse", "ids": ["..."] } ] }
  ]
}
```

### 4.4 Luật kiểm, theo đúng thứ tự

1. `s.authz.Can(ctx, actor, PermUserAssignScopes)` - **câu lệnh đầu tiên** của method public
   (R-15).
2. `laUUID(userID)` từ path -> 422 `ERR_COMMON_VALIDATION_FAILED`.
3. Người đó phải có một hàng `user_companies` còn sống trong `actor.CompanyID` -> 404
   `ERR_COMMON_NOT_FOUND`. `company_id` **luôn** lấy từ `actor.CompanyID`, không bao giờ từ
   body (R-06).
4. `vai_tro` phải liệt kê **đủ và đúng** tập hàng vai trò còn sống của người đó - thiếu, thừa,
   hay trùng id đều là 409 `ERR_COMMON_VERSION_CONFLICT` với thông điệp "danh sách vai trò đã
   đổi, tải lại màn hình". Đây là cách phát hiện việc ai đó vừa đổi vai trò của người này ở
   một tab khác. Frontend đã có sẵn đường xử 409 (`shouldReload`,
   `shared/api/form-errors.ts:125`).
5. Mỗi hàng phải liệt kê **đủ mọi loại** trong `LoaiPhamVi`. Thiếu một loại là 422, **không**
   suy diễn "giữ nguyên loại đó" - một `PUT` thay toàn bộ mà im lặng giữ lại một phần là
   đúng loại hỏng về phía mở mà ADR-0020 đã từ chối.
6. `loai` không có trong `LoaiPhamVi` -> 422.
7. Hàng vai trò có `toan_pham_vi = true` mà gửi `ids` không rỗng -> 422 "vai trò này đã thấy
   toàn bộ, không gán phạm vi được". Hỏng ồn ào thay vì cất một mớ dòng chết trong bảng.
8. `ids` phải là tập con của `Nguon.IDsTrongPhanVung(ctx, actor.CompanyID, loai)` -> 422 kèm
   `fields` chỉ đúng id sai. Trùng lặp trong `ids` bị khử trước khi ghi.
9. Trần `len(ids) <= 500` cho mỗi cặp (hàng vai trò, loại) -> 422. Đây là hàng rào cho điều
   kiện ADR-0020 đã ghi: mục 5 (resolver trả danh sách id cụ thể) chỉ đúng khi lực lượng tập
   nhỏ.

`ids` rỗng là **đầu vào hợp lệ**: nó nghĩa là thu hồi sạch, và người đó sẽ thấy màn hình
trống. Đó là mặc định fail-close của ADR-0020 mục 3.

### 4.5 Tầng service

File mới `modules/auth/internal/service/scope_service.go`, kiểu `*ScopeService` -
`user_service.go` đã hơn 900 dòng, và hai method này không dùng chung state nào với nó.

```go
func (s *ScopeService) PhamViTheoUser(ctx, actor, userID) (*PhamViCuaUser, error)
func (s *ScopeService) ThayPhamVi(ctx, actor, in ThayPhamViInput) (*PhamViCuaUser, error)
```

`ThayPhamVi` theo đúng trình tự C-GO-06: kiểm quyền -> chuẩn bị và kiểm dữ liệu **ngoài**
transaction (kể cả lần gọi `Nguon`, vì nó là một câu đọc riêng) -> `BeginTxx` -> với mỗi cặp
(hàng vai trò, loại): xoá mềm rồi chèn lại -> đọc lại toàn bộ để trả về -> `ghiAudit` bằng
**chính `tx`** -> `Commit`. `defer tx.Rollback()` ngay sau `BeginTxx`, như mọi service khác.

Audit: một dòng cho mỗi lần gọi, hằng `actionUserScopeUpdated = "user_scope.updated"`,
`EntityID = userID` - theo khuôn `user.created/updated/deleted` (`user_service.go:54-58`).

Không chặn người tự sửa phạm vi của chính mình. Khác màn vai trò: phạm vi **không** nằm trong
token nên có hiệu lực ngay ở request kế tiếp, không cần làm mới phiên. Việc đó vào audit như
mọi lần gán khác.

### 4.6 Tầng repository

File mới `modules/auth/internal/repository/user_company_role_scope_repository.go`. Struct
**rỗng**, nhận `sharedDB.DBTX` qua tham số (C-GO-03) - khác hẳn `scopeRepo` đang giữ handle,
vì ngoại lệ đó chỉ tồn tại do chữ ký `scope.Doc` không có tham số db, và đó là đường **chỉ
đọc**.

```go
type UserCompanyRoleScopeRepository interface {
	// TheoUser tra moi dong pham vi con hieu luc cua mot nguoi trong mot phan vung,
	// kem id hang vai tro de nguoi goi gom theo vai tro.
	TheoUser(ctx, db, companyID, userID string) ([]model.PhamViHang, error)

	// ThayPhamVi thay TOAN BO tap id cua MOT cap (hang vai tro, loai) bang tap moi.
	// Ten theo hanh vi that su chu khong theo "Update" (C-GO-02), y het ThayVaiTro.
	ThayPhamVi(ctx, db, companyID, userCompanyRoleID, actorID string,
		loai string, ids []string) error
}
```

Thêm vào `UserCompanyRepository` một method: `VaiTroTheoUser(ctx, db, companyID, userID)` trả
`[]model.UserCompanyRole` gồm `(id, role_code)`. Method sẵn có `RoleCodesTheoUser` chỉ trả mã
đã `GROUP BY` nên không dùng được - màn này cần chính `id` của hàng gán.

Ba câu SQL, mỗi câu một hằng chuỗi đơn (C-GO-07):

- **Đọc**: `JOIN` ngược `user_company_role_scopes -> user_company_roles -> user_companies`, ba
  mệnh đề `deleted_at IS NULL` không thay thế được cho nhau (R-18), `s.company_id = $1` đọc
  thẳng trên bảng con chứ không `JOIN` lên cha (R-06) - bê nguyên khuôn
  `selectScopeIDsTheoActorSQL` đang chạy.
- **Xoá mềm**: `UPDATE ... SET deleted_at = now(), updated_at = now(), updated_by = $4
  WHERE company_id = $1 AND user_company_role_id = $2 AND scope_type = $3 AND deleted_at IS
  NULL`. Xoá mềm chứ không `DELETE` (R-18): "ai từng được cấp kho nào" là câu một cuộc rà
  soát quyền phải trả lời được.
- **Chèn lại**: `unnest($5::uuid[])` trong một subquery **có alias** (`FROM unnest(...)` trần
  bị bộ kiểm R-02 đọc thành một bảng tên `unnest`), `SELECT` lấy `company_id` từ chính hàng
  `user_company_roles` với `WHERE ... AND r.deleted_at IS NULL` - hàng vai trò phải còn sống
  thì phạm vi mới được cấp. Khoá ngoại chỉ đòi hàng TỒN TẠI, nó không biết gì về soft delete.
  Bê nguyên khuôn `insertVaiTroChoUserCompanySQL:157`.

Không `ON CONFLICT`: bước xoá mềm ngay trước đó đã dọn sạch mọi hàng còn sống của chính cặp
đó khỏi partial unique index.

### 4.7 Handler

`modules/auth/internal/handler/user_scope_handler.go` + hai dòng route trong `user_routes.go`.
Năm bước cố định như mọi handler auth: `ShouldBindJSON` -> `response.BindFailed` khi lỗi;
`ctx := c.Request.Context()`; `auth.FromContext(ctx)` - handler là nơi **duy nhất** gọi nó
(R-14); gọi service; `response.Success` / `response.Error`.

Struct response và struct binding nằm ngay trong handler, **không** vào `modules/auth/api/`.
Package `api` là hợp đồng liên module và nó giữ mỏng có chủ đích: mở một kiểu ở đó khi chưa
module nào cần đọc là chốt một hợp đồng chưa ai kiểm thử.

## 5. Frontend

Module mới `src/modules/user/` với bố cục `api/ components/ hooks/ pages/` như ba module đang
chạy. Hai route thêm vào `src/app/routes.tsx` - nhớ bẫy thứ tự đoạn: route có đoạn cố định
phải đứng trước route có `:id`.

### 5.1 `/nguoi-dung` - danh sách người dùng

Khuôn `src/modules/company/pages/CompanyListPage.tsx`, sao cấu trúc chứ không trừu tượng hoá:
một component trang + `UserListFilters` + `UserTable` + `UserPager` + `UserListError` trong
cùng file. Bảng HTML thuần trên `co-so.css`, ô tìm `q` không kiểm soát gieo lại bằng
`key={params.q}`, tham số danh sách đọc từ URL qua `useSyncExternalStore`, hai nhánh rỗng
riêng biệt (có lọc -> nút "Xoá bộ lọc"; chưa có gì -> không có link tạo, vì chặng này không
làm màn thêm người).

Cột: Email, Họ tên, Vai trò (chip, nhiều chip một ô), nút "Phạm vi" dẫn sang màn sau. Dữ liệu
từ `GET /api/v1/users` đã chạy sẵn.

### 5.2 `/nguoi-dung/:id/pham-vi` - gán phạm vi

Một khối cho mỗi hàng vai trò, tiêu đề là `role_code`. Trong mỗi khối, một khối con cho mỗi
loại phạm vi, tiêu đề là `nhan` do backend trả.

- `toan_pham_vi = true` -> **không hiện danh sách chọn**, thay bằng một dòng giải thích: "Vai
  trò này thấy mọi kho. Không gán phạm vi cho vai trò này." Đây là trạng thái riêng, không
  phải "đã chọn tất cả".
- `toan_pham_vi = false` -> danh sách checkbox kho, nguồn từ `GET /api/v1/warehouses`.
- Khối chưa chọn gì hiện cảnh báo đúng hệ quả ADR-0020 mục 3: *người này sẽ không thấy dòng
  nào ở màn kho.* Không có cảnh báo này thì người gán không có cách nào biết trước.
- Người chưa có vai trò nào trong phân vùng: trạng thái rỗng nói thẳng phải gán vai trò trước,
  không hiện nút Lưu.

Một nút Lưu cho cả trang, một `PUT` mang **đủ mọi hàng vai trò đang hiển thị** - đúng điều
kiện cứng ở mục 3.3. Sau khi lưu, dùng thẳng payload trả về để cập nhật cache, không gọi lại
`GET`.

Xử lỗi: 422 tô ô + thông điệp; 409 -> banner "dữ liệu đã đổi" + nút tải lại (dùng
`shouldReload` sẵn có); 403 xử tại chỗ theo `frontend-erp/docs/Permission.md` - nút cứ hiện,
gặp 403 thì hiện thông điệp và mã tra cứu. Không đoán quyền từ role (eslint `c-ts-06` chặn).

State: TanStack Query, mỗi thao tác một hook mỏng (`use-user-list`, `use-user-scopes`,
`use-update-user-scopes`), khoá cache tập trung ở `user-keys.ts`. Không store mới, không
component dùng chung mới - `src/shared/components/` vẫn rỗng sau chặng này.

Thêm một dòng vào `src/app/ung-dung.ts` cho ứng dụng `auth` (đang là `duong: null`, "Chưa có
màn").

## 6. Kiểm chứng

**Unit (Go, table-driven, không chạm DB):** `ScopeService` với repository giả, `authz` giả và
`Nguon` giả. Các ca bắt buộc: thiếu quyền -> 403; user không thuộc phân vùng -> 404; thiếu một
hàng vai trò -> 409; thừa một hàng -> 409; loại lạ -> 422; id không có trong phân vùng -> 422
kèm đúng `fields`; vai trò toàn phạm vi mà gửi `ids` -> 422; `ids` rỗng -> chạy được và gọi
đúng một lần xoá mềm, không chèn dòng nào; happy path -> số lần gọi repo đúng, audit ghi đúng
một dòng, và ghi **trước** `Commit`.

**Unit (frontend, vitest):** hook và render hai màn theo khuôn test sẵn có; ca `toan_pham_vi`
không được render checkbox nào.

**E2E (`cmd/api/e2e_test.go`):** đây là bằng chứng thật, vì nó nối đường ghi với đường đọc -
gán một kho cho một `member`, đăng nhập bằng chính người đó, gọi `GET /api/v1/warehouses` và
xác nhận chỉ thấy đúng kho đó; rồi `PUT` lại với `ids` rỗng và xác nhận thấy rỗng.

**Bộ kiểm kiến trúc:** `go run ./cmd/dev check` và `go run ./cmd/dev arch` phải xanh -
C-GO-09 không được đỏ, R-15 không được đỏ ở hai method mới.

Máy dưới không chạy được `cmd/dev test` (không có Docker Desktop), nên bằng chứng test lấy từ
CI; `check` và `arch` chạy được dưới máy.

## 7. Ngoài phạm vi chặng này

- `quan_tri_he_thong` gán phạm vi - để **ADR-0021**.
- Loại phạm vi thứ hai (khách hàng, vật tư, khu vực).
- Màn gán **vai trò** (đã có đường qua `PATCH /users/:id`), màn thêm người vào phân vùng.
- Cache phạm vi (nợ ADR-0020: chưa đo hiệu năng nên chưa quyết được).
- Dọn dòng scope trỏ tới bản ghi đã xoá mềm (nợ ADR-0020, hệ quả của việc không có khoá
  ngoại).
- Phạm vi phân cấp, và phạm vi khác nhau cho đọc với ghi (ADR-0020 đã ghi là không diễn tả
  được).
- Giai đoạn hai ADR-0019: email toàn hệ thống, đăng nhập hai bước, đổi phân vùng.

## 8. Rủi ro đã biết

- **`toan_pham_vi` tính bằng một `auth.Actor` dựng tại chỗ.** `Can` vốn chỉ tra bảng theo
  `Roles` nên kết quả đúng, nhưng đây là lần đầu trong repo một `Actor` không đến từ token.
  Phải có comment nói rõ nó dùng để hỏi *"vai trò này có quyền gì"*, không phải để cho phép
  bất cứ điều gì.
- **Danh sách `LoaiPhamVi` phải dựng đúng một lần ở `cmd/api`** và dùng cho cả `scope.New`
  lẫn `auth.New`. Hai bản sao là chỗ để chúng lệch nhau, và lệch thì màn hình gán một loại mà
  resolver không biết loại đó.
- **eslint `c-ts-06-no-role-guess` có thể đỏ oan ở màn phạm vi.** Luật đó bắt cặp NGUỒN
  (`role/roles/vai_tro/quyen`) đi kèm CÔNG TẮC (`disabled/hidden`, nhánh JSX), mà màn này
  rẽ nhánh JSX trên một trường nằm trong đối tượng `vai_tro`. Nếu đỏ, cách xử đúng là tách
  `toan_pham_vi` ra một biến trung gian có tên không mang chữ vai trò - **không** nới luật.
  Rẽ theo `toan_pham_vi` không phải đoán quyền từ role: nó là dữ liệu backend trả về.
- **Trần 500 id** là một con số chọn tay, chưa đo. Nó là hàng rào cho điều kiện ADR-0020 mục
  5, không phải một giới hạn nghiệp vụ.
