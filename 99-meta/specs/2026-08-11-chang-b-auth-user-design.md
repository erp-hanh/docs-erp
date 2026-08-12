# Chặng B — `shared/` còn thiếu, module `auth` và module `user`

**Trạng thái:** Đã duyệt · 2026-08-11
**Tiền đề:** Chặng A đóng — 18/19 rule có checker, CI ba job xanh trên GitHub Actions.

---

## 1. Mục tiêu, đo được

Bảy dòng `PASS tren tap RONG` trong `arch/LEVELS.md` biến mất. Cụ thể, các rule sau lần đầu
chạm code sản xuất thay vì chỉ chạm fixture:

```
R-02  R-03  R-05  R-10  R-11  R-12  R-15  C-GO-07
```

Đây không phải mục tiêu trang trí. Tám checker đó đã chứng minh được mình trên fixture,
nhưng **chưa cái nào gặp một dòng code sản xuất**. Chặng A đã cho thấy đó là hai chuyện
khác nhau: `R-16` chạy sạch trên mọi fixture rồi bắt oan `response.Error(c, err)` ngay lần
đầu quét code thật.

## 2. Phạm vi

**Làm:**

| Thành phần | Lý do bắt buộc |
|---|---|
| Checker `C-GO-05` cho `module.yaml` | Xem mục 3 |
| `shared/auth` | R-14, R-15 đòi `Actor` + `FromContext` |
| `shared/authz` | R-15 đòi `Checker.Can` |
| `shared/middleware/auth` | R-14: nơi **duy nhất** được `jwt.Parse` |
| `shared/audit` | R-17: **mọi** thao tác ghi sinh audit trong cùng transaction |
| Migration `users`, `refresh_tokens`, `audit_logs` | Ba bảng module cần |
| `modules/auth` | MỘT module, sở hữu `users` + `refresh_tokens`; xem mục 7 |

**KHÔNG làm, và lý do:**

`shared/outbox`, `shared/bus`, `relay/` — chặng B có đúng hai module và **không có nhu cầu
cross-module nào**, nên không có event nào để phát. Dựng ba thành phần đó lúc này là dựng
một đường ống không có nước chảy qua, và một bảng `outbox` không ai ghi vào sẽ mục đúng
cách `make test` đã mục: nó tồn tại, trông như đang hoạt động, và không ai phát hiện ra nó
chưa từng chạy.

R-05 vẫn được enforce: nó chạy trên `modules/` đã có code thật và kết luận đúng — không có
`.Publish(` nào. Đó là một kết luận, không phải một chỗ trống.

Rate limit cho `/auth/login`: để chặng sau. Mã `ERR_COMMON_RATE_LIMITED` đã có chỗ trong
C-API-05, nhưng middleware rate limit là hạ tầng riêng, không thuộc module auth.

## 3. Vì sao `module.yaml` đi trước module đầu tiên

`module.yaml` là **đầu vào** của R-02, R-05 và R-15. Hiện **không checker nào** kiểm nó tồn
tại hay đủ trường. Bằng chứng cụ thể: fixture `arch/testdata/r02/valid_query_bang_cua_minh/module.yaml`
thiếu cả `name` lẫn `internal_methods` mà toàn bộ test vẫn xanh.

Hệ quả nếu để nguyên: quên một bảng trong `tables` thì R-02 **im lặng** coi bảng đó là của
module khác — nó không báo thiếu, nó báo *sai chỗ*. Và `internal_methods` không được đối
chiếu nghĩa là bất kỳ ai đặt tên method bắt đầu bằng `Internal` là **tự cấp cho mình một
miễn trừ R-15**.

Đây đúng hình dạng của `C-GO-07` ở Task 14: một convention nhỏ mà bốn rule dựa lên. Nó phải
được enforce **trước** khi có module đầu tiên, không phải sau.

**Checker `C-GO-05` kiểm:**

1. Mỗi `modules/<A>/` có `module.yaml`.
2. Đủ bốn trường `name`, `tables`, `allowed_deps`, `internal_methods` (được rỗng, không được thiếu khóa).
3. `name` khớp tên thư mục.
4. Mỗi method `Internal*` có thật trong `modules/<A>/internal/service/` phải có tên trong `internal_methods`, và ngược lại.
5. Không tên nào trong `internal_methods` xuất hiện trong `modules/<A>/api/` (R-15 Ngoại lệ).

`Level: PARTIAL`. Vế không kiểm được: `tables` có liệt kê **đủ** bảng module dùng hay không
— thiếu một bảng thì R-02 bắt oan chứ không bỏ sót, nên nó lộ ra chứ không im; nhưng thừa
một bảng thì R-02 mù đúng chỗ bảng đó.

## 4. Hợp đồng của `shared/`

Chữ ký lấy từ `C-GO-backend.md` mục C-GO-01 và ví dụ trong `01-rules/rules/`. Chỗ tài liệu
chỉ nêu tên mà chưa có chữ ký thì spec này chốt.

### 4.1 `shared/auth`

```go
// Actor la nguoi thuc hien thao tac. KHONG import thu vien JWT nao.
type Actor struct {
    UserID    string
    CompanyID string
    Roles     []string
}

func FromContext(ctx context.Context) Actor   // Actor rong khi chua xac thuc
func WithActor(ctx context.Context, a Actor) context.Context
```

Package này **cố ý không phụ thuộc JWT**. Lý do đã ghi ở `C-GO-backend.md`: service import
`auth` để nhận `Actor`, và nếu `auth` kéo theo thư viện JWT thì mọi service kéo theo nó.

`WithActor` không có trong tài liệu; spec này thêm nó vì `middleware/auth` cần một đường
tường minh để gắn actor, và một hàm xuất khẩu kiểm được tốt hơn một biến context dùng chung.

### 4.2 `shared/authz`

```go
type Checker interface {
    Can(ctx context.Context, actor Actor, perm string) error   // nil = duoc phep
}

// Bang la du lieu, khong phai code: role -> danh sach permission.
type Bang map[string][]string

func New(b Bang) Checker
```

Trả `error` chứ không `bool`: `C-GO-backend.md` chốt chữ ký `Can(ctx, actor, perm) error`,
và error cho phép trả thẳng `apperr.Forbidden(...)` lên service mà không cần dịch.

`Require` chỉ được R-15 nhắc tên trong regex, không có chữ ký ở đâu. Spec này **không**
thêm nó — một API thứ hai làm cùng việc là một chỗ để hai nửa codebase làm khác nhau.
Checker R-15 chấp nhận cả hai tên nên bỏ `Require` không làm rule đỏ.

### 4.3 Bảng role→permission sống ở `cmd/api`, và đi qua package gốc của module

> **Sửa sau khi viết.** Bản đầu của mục này nói hằng permission sống ở `modules/<A>/api/permissions.go`
> và `cmd/api` dựng bảng từ đó. **Sai, và sai vào R-01** — rule duy nhất đang ở mức FULL:
> *"Dòng import trong `cmd/**` còn nhiều hơn một segment sau `modules/` — ví dụ
> `erp/modules/order/api` — là dấu hiệu vi phạm."* `cmd/api` không được import `api/`.
>
> Bản đầu cũng nói *"tài liệu chưa chốt định dạng permission"*. Cũng sai: C-GO-02 đã chốt
> `"order.create"` dấu chấm, khai ở package `service`, và tám ví dụ trong docs đang dùng
> đúng vậy. Tôi tin báo cáo khảo sát mà không kiểm lại điều khoản gốc.

**Định dạng và nơi hằng sống: giữ nguyên C-GO-02** — chuỗi `<module>.<hành động>`, hằng
`Perm<Đối tượng><Hành động>` khai ở package `service` của module sở hữu. Chặng B không đổi
một quy ước đã được tám chỗ khác tham chiếu.

**Thứ thật sự còn trống** là đường đi từ hằng đó tới bảng vai trò. Hai đáp án tự nhiên đều
vi phạm rule:

- Bảng ở `shared/authz` → `shared/` phải import `modules/` → **vi phạm R-04**.
- `cmd/api` import `api/` hay `internal/service/` để lấy hằng → **vi phạm R-01**.

**Đường đúng:** package gốc của module (nơi có `module.go`) là mặt tiếp xúc duy nhất giữa
module và composition root, nên permission đi ra qua đúng cửa đó:

```
modules/<A>/internal/service/   hang that: PermOrderCreate = "order.create"  (C-GO-02)
modules/<A>/module.go           xuat lai: const PermCreate = service.PermOrderCreate
shared/authz/                   interface + ban cai dat NHAN bang lam du lieu
cmd/api/authz.go                dung bang tu <module>.PermXxx roi tiem vao
```

Hệ quả có lợi: xóa hoặc đổi tên một hằng permission làm **vỡ build của `cmd/api`**. Một vai
trò mất quyền lộ ra lúc biên dịch, không phải lúc người dùng thật bấm nút và nhận `403`.

Đã chốt thành mục **C-GO-08** trong `C-GO-backend.md`.

### 4.4 `shared/middleware/auth`

```go
func Middleware(bimat []byte) gin.HandlerFunc
```

Nơi **duy nhất** trong repo được gọi `jwt.Parse`/`jwt.ParseWithClaims`. Đọc header
`Authorization: Bearer <token>`, verify, dựng `auth.Actor` từ claims, gắn vào ctx bằng
`auth.WithActor`. Token thiếu hoặc sai → `401` với `ERR_AUTH_UNAUTHENTICATED` qua
`shared/response`, và **abort** — không cho request đi tiếp.

### 4.5 `shared/audit`

```go
type Entry struct {
    CompanyID string    `db:"company_id"`
    ActorID   string    `db:"created_by"`
    RequestID string    `db:"request_id"`
    Action    string    `db:"action"`
    EntityID  string    `db:"entity_id"`
    CreatedAt time.Time `db:"created_at"`
}

type Repository interface {
    Record(ctx context.Context, db sharedDB.DBTX, e Entry) error
}
```

`Entry` chép nguyên từ `01-rules/rules/R-17-traceability.md`. `Record` nhận `DBTX` làm tham
số — đó là cách duy nhất để nó ghi trong **cùng transaction** với thao tác nghiệp vụ, theo
đúng Transaction Ownership của C-GO-03.

## 5. Schema

`users` và `refresh_tokens` **không** có tên trong registry C-DB-04, nên theo C-DB-03 chúng
là **bảng nghiệp vụ** và không được miễn thứ gì. `audit_logs` đã có sẵn trong
`append_only_tables` (ADR-0007).

```sql
-- users: bang nghiep vu, khong mien gi
id, company_id, email, password_hash, full_name, is_active,
created_at, updated_at, deleted_at, created_by, updated_by

CREATE UNIQUE INDEX uq_users_email_active
  ON users(company_id, email) WHERE deleted_at IS NULL;
```

Partial unique index chứ không `UNIQUE` thường: xóa mềm một user rồi tạo lại cùng email phải
được (C-DB-05 mục 3). Tên index lấy đúng ví dụ đã có ở `C-DB-01`.

```sql
-- refresh_tokens: bang nghiep vu
id, company_id, user_id, token_hash, expires_at,
created_at, updated_at, deleted_at, created_by, updated_by
```

Lưu `token_hash`, **không** lưu token trần: rò rỉ database thì kẻ đọc được không dùng lại
được token. Thu hồi bằng `deleted_at` — đúng R-18, và vì nó là bảng nghiệp vụ bình thường
nên **không cần ADR**.

```sql
-- audit_logs: append_only_tables, co company_id + created_at + created_by,
-- KHONG updated_* va KHONG deleted_at
id, company_id, request_id, action, entity_id, created_at, created_by
```

`created_by`/`updated_by` ở mọi bảng **không** mang khóa ngoại tới `users` — C-DB-03 chốt:
audit phải giữ được dấu vết kể cả khi user bị xóa.

## 6. Module `auth`

```
modules/auth/
├── api/          permissions.go, dto.go
├── internal/
│   ├── handler/  auth_handler.go, routes.go
│   ├── service/  auth_service.go
│   ├── repository/ user_repository.go, refresh_token_repository.go
│   ├── model/    user.go, refresh_token.go
│   └── token/    token.go        <- noi DUY NHAT duoc jwt.NewWithClaims
├── module.go
└── module.yaml
```

`modules/auth/internal/token` là ngoại lệ tường minh của R-14: được **ký** token, cấm mọi
hàm parse hoặc verify.

**`AuthService` có đúng bốn method public:**

| Method | Actor | Kiểm quyền |
|---|---|---|
| `Login(ctx, in)` | không | miễn — R-15 Ngoại lệ, danh sách đóng |
| `Refresh(ctx, in)` | không | miễn |
| `Logout(ctx, in)` | không | miễn |
| `ChangePassword(ctx, actor, in)` | **có** | **có** — người dùng đã đăng nhập |

`ChangePassword` cố ý nhận actor và kiểm quyền bình thường, nên **không phải sửa R-15**.
Quên mật khẩu (`ForgotPassword`/`ResetPassword`) để chặng sau: nó cần hạ tầng gửi email chưa
có, và thêm nó vào diện miễn sẽ phải sửa chính R-15.

**Endpoint:** `POST /api/v1/auth/login`, `/refresh`, `/logout`, `POST /api/v1/auth/change-password`.
Ba path đầu đã được R-10 miễn dạng tài nguyên (C-API-01), **không cần đăng ký** ở C-API-07.

**Token:** JWT HS256, khóa từ env, fail-fast nếu thiếu. Access 15 phút, refresh 30 ngày.
Claims: `sub` (user_id), `company_id`, `roles`, `exp`, `iat`, `jti`.
Mật khẩu băm bcrypt cost 12 (`golang.org/x/crypto/bcrypt`).

**DTO trả token phải được đăng ký ở C-API-07 bảng 4** — đó là ngoại lệ R-16, và quy tắc của
C-API-07 nói rõ thêm dòng là việc của chính PR tạo endpoint. Dòng đăng ký nêu cả endpoint
lẫn **tên struct**.

## 7. MỘT module `auth`, không phải hai — sửa sau khi viết

> **Bản đầu của spec này chia hai module** `auth` và `user`, với `auth` gọi `modules/user/api/`
> để tra user theo email. **Không sống được**, và nó lộ ra khi viết hợp đồng giữa hai module.

**Login xảy ra khi chưa có actor.** R-15 bắt *mọi* method public của service nhận `actor`
làm tham số thứ hai và mở đầu bằng một lời gọi kiểm quyền. Ngoại lệ là danh sách **đóng**:
`Login`, `Refresh`, `Logout` của **`AuthService`** — không phải của `UserService`. Nên
`UserService.VerifyCredentials(...)` không có actor nào để nhận và không có quyền nào để
kiểm.

Ba đường ra, hai đường đầu đều tệ:

| Đường | Vấn đề |
|---|---|
| Mở rộng ngoại lệ R-15 sang `UserService` | Phải sửa chính rule — thứ đã cố ý tránh ở mục 6 |
| Cho `auth` query thẳng bảng `users` | Vi phạm R-02: một bảng thuộc đúng một module |
| **Một module `auth` sở hữu cả `users` lẫn `refresh_tokens`** | Không vi phạm gì, không cần ADR |

Đường thứ ba khớp đúng một cơ chế đã có sẵn: `AuthService` gọi
`UserService.InternalByEmail(ctx, actor, ...)` — method `Internal*` dùng nội bộ **giữa các
service trong cùng một module**, chính là ca mà ngoại lệ `Internal*` của R-15 sinh ra để
phục vụ. Nó được miễn kiểm quyền, vẫn nhận `actor`, và bắt buộc có tên trong
`internal_methods` — tức `C-GO-05` vừa viết ở B1 sẽ canh nó.

Thêm một căn cứ độc lập: **R-14 gọi đích danh `modules/auth/internal/token`** trong phần
Ngoại lệ. Tên module đã được rule chốt sẵn.

```
modules/auth/
├── api/              DTO cho module khac (chua module nao dung)
├── internal/
│   ├── handler/      auth_handler.go, user_handler.go, routes.go
│   ├── service/      auth_service.go, user_service.go, permissions.go
│   ├── repository/   user_repository.go, refresh_token_repository.go
│   ├── model/        user.go, refresh_token.go
│   └── token/        ky token - ngoai le tuong minh cua R-14
├── module.go
└── module.yaml       tables: [users, refresh_tokens]
```

**`AuthService`** — `Login`, `Refresh`, `Logout` (miễn theo R-15), `ChangePassword`
(có actor, kiểm quyền bình thường).

**`UserService`** — CRUD đầy đủ cộng một endpoint list có phân trang; mọi method public
nhận `actor` và mở đầu bằng `s.authz.Can(...)`; cộng `InternalByEmail` phục vụ `AuthService`.

```
POST   /api/v1/auth/login  /refresh  /logout          mien dang tai nguyen (C-API-01)
POST   /api/v1/auth/change-password
GET    /api/v1/users        list, co page/page_size/sort
POST   /api/v1/users        tra 201
GET    /api/v1/users/:id
PATCH  /api/v1/users/:id
DELETE /api/v1/users/:id    xoa mem, tra 204
```

**Cái mất khi gộp:** vế *JOIN xuyên module* của R-02 không được thử trên code thật ở chặng
này — chỉ còn fixture canh nó. Chấp nhận được: dựng một module thứ hai chỉ để thử một
checker là dựng thứ không ai dùng, và chặng A đã cho thấy thứ không ai dùng thì mục.

## 8. Kéo theo ở `docs-erp`

| Thay đổi | Vì sao |
|---|---|
| `C-API-05` thêm `ERR_AUTH_INVALID_CREDENTIALS` (401) | Bảng hiện **không có mã cho "sai email/mật khẩu"**; `ERR_AUTH_UNAUTHENTICATED` chỉ mô tả thiếu/sai/hết hạn token |
| `C-API-07` bảng 4 thêm dòng cho DTO trả token | Ngoại lệ R-16, quy tắc của chính C-API-07 |
| `C-GO-backend.md` thêm mục quy ước tên permission | Định dạng `<module>:<action>` chưa được chốt ở đâu |
| 5 file docs cho mỗi module | CL-NEWMOD-08 |

Thông điệp của `ERR_AUTH_INVALID_CREDENTIALS` phải **mờ như nhau** cho cả ca sai email lẫn
sai mật khẩu — P-ERR cấm phân biệt hai ca, vì phân biệt là xác nhận email nào có tồn tại.

**`RULES-PIN.md` không đổi.** Không rule nào bị sửa ở chặng B — đó là hệ quả của việc chọn
"đúng ba method miễn kiểm quyền", và nó là một phần lý do chọn như vậy.

## 9. Định nghĩa hoàn thành

- `arch/LEVELS.md` **không còn dòng nào** mang chú thích `PASS tren tap RONG`.
- `C-GO-05` có checker, fixture hai chiều, và chạy trên `modules/` có code thật.
- Mọi checker mới đều qua phép thử: **vô hiệu hóa nó thì có thứ gì đó đỏ**.
- `go run ./cmd/dev check` và `test` xanh; CI ba job xanh trên GitHub.
- Đăng nhập được thật: `POST /auth/login` trả token, gọi `GET /users` kèm token trả 200,
  gọi không kèm token trả 401, gọi bằng token của công ty khác trả **404** chứ không 403.
- Mọi mục của `CL-NEWMOD-new-module.md` và `CL-API-new-endpoint.md` được kiểm thật.

## 10. Rủi ro đã biết

**Bẫy đặt tên file.** R-03, R-14, R-15, C-GO-07 đều nhận diện tầng qua **hậu tố tên file**
và **segment thư mục**. Đặt `auth_svc.go` thay vì `auth_service.go` **và** để nó ngoài
`internal/service/` thì mọi checker đó mù trên file đó — CI vẫn báo sạch. Chưa checker nào
bắt buộc quy ước đặt tên; đây là chỗ con người phải tự canh ở PR đầu tiên.

**Năm mục checklist không có checker nào canh** (CL-NEWMOD-01 sẽ có sau B1, còn lại):
cây thư mục module, chu trình `allowed_deps` hai nút, 5 file docs, và test cho mỗi method
public của service. Chúng phải được kiểm bằng mắt trong PR.
