# Chặng B — Implementation Plan

> **Spec:** [2026-08-11-chang-b-auth-user-design.md](2026-08-11-chang-b-auth-user-design.md)
> Plan này ghi ở mức **task**, không mức step. Chi tiết từng bước nằm trong prompt của
> subagent thực thi — cùng cách chặng A đã chạy, nhưng lần này các task độc lập chạy song song.

**Goal:** Bảy dòng `PASS tren tap RONG` trong `arch/LEVELS.md` biến mất; 18/19 rule chạm code sản xuất.

---

## Đồ thị phụ thuộc

```
DOT 1 (song song, 6 agent):
  B1  checker C-GO-05 cho module.yaml       arch/
  B2  shared/auth                            shared/auth/
  B3  shared/authz                           shared/authz/
  B5  shared/audit                           shared/audit/
  B6  migration users/refresh_tokens/audit_logs   migrations/
  B9  ma loi moi + quy uoc permission        docs-erp/ + shared/errors/

DOT 2 (sau B2):
  B4  shared/middleware/auth                 shared/middleware/auth/

DOT 3 (sau B1..B6):
  B7  modules/auth
  B8  modules/user        <- B7 phu thuoc B8 qua api/, xem muc "Thu tu B7/B8"

DOT 4:
  B10 cmd/api ghep lai: bang role->permission, dang ky module, middleware
  B11 docs module (5 file moi module), dang ky C-API-07, chay het checklist
```

**Thứ tự B7/B8:** `modules/auth` gọi `modules/user/api/` để lấy user theo email (spec mục 7),
nên `user/api/` phải có trước. Làm `B8` phần `api/` + `model/` + `repository/` trước, rồi
`B7`, rồi phần còn lại của `B8`. Hoặc đơn giản hơn: một agent làm cả hai module tuần tự.

---

## Ràng buộc chung cho MỌI task

1. **Chỉ build/test package của mình**, không chạy `go build ./...` — các agent khác đang
   viết dở package khác, và một lỗi biên dịch của người khác không phải tín hiệu về việc mình
   làm đúng hay sai.
2. **Không sửa file ngoài phạm vi task**. Trùng file giữa hai agent là hỏng.
3. **Không chạy `go test ./arch -update` hay `arch-pin`** — golden file do người điều phối
   sinh lại một lần ở cuối, sau khi mọi task xong.
4. Comment tiếng Việt **không dấu**, giải thích **vì sao** chứ không mô tả lại code — theo
   đúng mật độ và giọng của code hiện có.
5. Mọi checker mới phải qua phép thử: **vô hiệu hóa nó thì có thứ gì đó đỏ**.

---

## Task

| ID | Nội dung | File chính | Nghiệm thu |
|---|---|---|---|
| **B1** | Checker `C-GO-05` cho `module.yaml` | `arch/checks_module.go`, `arch/testdata/cgo05/` | Fixture hai chiều; `TestFixtures/C-GO-05` xanh; phá checker thì đỏ |
| **B2** | `shared/auth` — `Actor`, `FromContext`, `WithActor` | `shared/auth/auth.go` + test | Không import JWT; test round-trip ctx |
| **B3** | `shared/authz` — `Checker`, `Bang`, `New` | `shared/authz/authz.go` + test | `Can` trả `apperr.Forbidden` khi thiếu quyền |
| **B4** | `shared/middleware/auth` — verify JWT, gắn actor | `shared/middleware/auth/auth.go` + test | Thiếu token → 401 envelope + abort; token hợp lệ → actor trong ctx |
| **B5** | `shared/audit` — `Entry`, `Repository` | `shared/audit/audit.go` + `postgres.go` + test | `Record` nhận `DBTX`; ghi được trong transaction |
| **B6** | Migration ba bảng | `migrations/00000{2,3,4}_*.{up,down}.sql` | `cmd/dev test` xanh; R-06/R-08/R-09/R-17/R-18 xanh trên migration mới |
| **B7** | `modules/auth` | `modules/auth/**` | Bốn method; `token/` chỉ ký, không parse |
| **B8** | `modules/user` | `modules/user/**` | CRUD + list phân trang; mọi method nhận actor + kiểm quyền |
| **B9** | `ERR_AUTH_INVALID_CREDENTIALS` + quy ước tên permission | `docs-erp/04-conventions/*`, `shared/errors/` | `check-ids` xanh; hằng khớp bảng C-API-05 |
| **B10** | `cmd/api` ghép lại | `cmd/api/*.go` | Đăng nhập được thật, end-to-end |
| **B11** | Docs module + đăng ký C-API-07 + chạy checklist | `modules/*/docs/`, `docs-erp/04-conventions/C-API-http.md` | Đủ 5 file mỗi module |

---

## Cuối chặng — người điều phối làm, không giao agent

1. `go run ./cmd/dev arch-update` sinh lại `arch/LEVELS.md`, **đọc diff** — bảy dòng
   `PASS tren tap RONG` phải biến mất, và không dòng nào bị hạ mức ngoài dự kiến.
2. `go generate ./arch/...` + `git diff --exit-code`.
3. `go run ./cmd/dev check` rồi `test`.
4. Chạy `CL-NEWMOD-new-module.md` và `CL-API-new-endpoint.md` **bằng mắt** cho từng module —
   năm mục không có checker nào canh (cây thư mục, chu trình `allowed_deps`, 5 file docs,
   test cho mỗi method public) chỉ có người kiểm được.
5. Đẩy lên GitHub, đợi CI ba job xanh.


---

# Trạng thái chặng B — cập nhật 2026-08-12

## Đã xong

| Task | Commit |
|---|---|
| B1 `C-GO-05` canh `module.yaml` · B2/B3/B4/B5 `shared/{auth,authz,middleware/auth,audit}` · B6 migration ba bảng · B9 `ERR_AUTH_INVALID_CREDENTIALS` + C-GO-08 | `4746187`, `ff35d53` |
| B7a nền móng `modules/auth` (model, repository, `module.yaml`) + hai checker bắt oan được sửa | `86ffcd6` |
| `checkR13` thôi kết luận ở chỗ nó không nhìn thấy | `03592e5` |
| B7 `AuthService` + token · B8 `UserService` + handler · B10 `cmd/api` ghép lại | `608e81f` |

**Mục tiêu đo được đã đạt:** `arch/LEVELS.md` **không còn dòng `PASS tren tap RONG` nào**.
18 rule + 2 convention đều chạm code sản xuất. Năm ca end-to-end chạy qua database thật:
login → 200, gọi endpoint kèm token → 200, không token → 401, bản ghi công ty khác →
**404 chứ không 403**, sai mật khẩu → 401 không lộ token, refresh→logout→refresh lại → 401.

## Còn lại của chặng B — cập nhật 2026-08-12 (lượt hai)

1. ~~**Docs module (CL-NEWMOD-08)**~~ — **xong.** `modules/auth/docs/` có đủ 5 file theo
   `05-templates/module-docs/`. `Database.md` khớp từng dòng với `tables` của
   `module.yaml` (`users`, `refresh_tokens`). Không checker nào canh việc này, nên nó chỉ
   giữ được bằng thói quen sửa docs trong cùng PR với schema.
2. ~~**Chạy hai checklist bằng mắt**~~ — **xong**, kết quả ở mục dưới. `check` và `test`
   xanh sau khi thêm docs; `go generate ./arch/...` không sinh diff.
3. **Đợi CI ba job xanh** sau khi đẩy — **chưa làm**, docs mới còn là thư mục untracked.

## Kết quả chạy hai checklist bằng mắt

`CL-NEWMOD` 15/15 và `CL-API` 17/17 đã đi từng dòng. Mọi mục đạt, trừ ba chỗ dưới đây —
hai trong số đó là lệch thật, đo được, và chúng đứng thành món nợ thứ tư.

**CL-NEWMOD-02 — cây thư mục có package thứ năm.** Ngoài `handler/`, `service/`,
`repository/`, `model/` còn có `modules/auth/internal/token/`. Đây **không** phải vi phạm:
Ngoại lệ của R-14 gọi đích danh package đó — nó được ký token và bị cấm mọi hàm parse, và
`checkR14` quét chính thư mục đó để giữ vế thứ hai. Ghi ra để lần review sau không tick
mục này mà không biết mình đang tick cái gì.

**CL-API-02 — `:id` không phải UUID cho ra `500`.** `c.Param("id")` đi thẳng vào
`WHERE id = $2`; Postgres trả `22P02`, service không dịch mã đó nên nó ra client dưới dạng
`ERR_INTERNAL`. Đo thật, không suy luận:
`GET /api/v1/users/khong-phai-uuid` → `500 ERR_INTERNAL`. Câu trả lời đúng là `404` — cùng
một `404` với "không tồn tại" và "của công ty khác", vì một id sai định dạng thì chắc chắn
không tồn tại nên `404` không lộ gì.

**CL-API-03 — ranh giới `400`/`422` chưa tồn tại.** `shared/response` **không có** hàm nào
trả `400`: mọi lỗi bind đều đi qua `ValidationFailed` → `422`. Hai ca mà C-API-02 chốt là
`400` đang trả `422`, đo thật:

| Request | Hiện tại | C-API-02 đòi |
|---|---|---|
| `POST /auth/login` body `{"company_code": broken` | `422` `ERR_COMMON_VALIDATION_FAILED` | `400` |
| `GET /users?page=abc` | `422` `ERR_COMMON_VALIDATION_FAILED` | `400` |

Cả hai ra cùng `fields: [{"field": "", "message": "Body khong doc duoc"}]` — kể cả ca thứ
hai, nơi lỗi nằm ở query chứ không ở body. Frontend phân biệt hai loại này (`422` giữ
form và highlight ô, `400` thì không có ô nào để highlight), nên đây là hợp đồng lệch chứ
không phải chi tiết trình bày.

## Bốn món nợ, phải giải trước khi gọi phân quyền là có thật

**1. Phân quyền hiện là hình thức.** `users` chưa có cột role, nên `modules/auth` ký một
hằng `RoleMacDinh` cho **mọi** user, và bảng vai trò ở `cmd/api` cấp đủ sáu quyền cho hằng
đó. Hệ quả: **không tồn tại user hạn chế nào**, nên không test nào chứng minh được `authz`
thật sự từ chối ai — `Can` chưa bao giờ trả lỗi trên đường chạy thật.

Đây là hở trong chính spec này: mục 4.3 chốt *"role nằm trong JWT claims, không bảng"*
nhưng **không nói role lấy từ đâu**. Cách sửa gọn nhất: thêm cột `roles TEXT[]` vào `users`
bằng một migration mới (R-07 cấm sửa migration đã merge), đọc nó lúc ký token, và bỏ
`RoleMacDinh`. Ba chỗ đang sống bằng comment: `auth_permissions.go`, `auth_service.go`
(hai lời gọi), `cmd/api/authz.go`.

**2. Không có đường tạo user đầu tiên.** `POST /users` đòi actor có quyền, mà muốn có actor
thì phải đăng nhập, mà muốn đăng nhập thì phải có user. Hiện chỉ vào được bằng SQL tay —
`cmd/api/e2e_test.go` làm đúng việc đó. Cần một lệnh bootstrap ở `cmd/dev` hoặc một
migration seed có kiểm soát.

**3. `ERR_AUTH_EMAIL_DUPLICATED` chưa có ca end-to-end** — mới chốt status/mã ở tầng
`shared/errors`. Đường `23505` → `409` chưa lần nào chạy thật.

**4. Ba mã status sai so với C-API-02**, phát hiện lúc chạy checklist bằng mắt (chi tiết
và số đo ở mục trên): `:id` sai định dạng ra `500` thay vì `404`; JSON hỏng và query sai
kiểu ra `422` thay vì `400`. Món này khác ba món trên ở chỗ nó **không** nằm trong module:
lời giải là một hàm `response.BadRequest` ở `shared/response` cộng với một chỗ phân biệt
lỗi cú pháp JSON (`*json.SyntaxError`, `*json.UnmarshalTypeError`) khỏi
`validator.ValidationErrors` trong `FieldErrors`, và một bước kiểm UUID ở handler. Sửa ở
`shared/` thì mọi module sau đều thừa hưởng; để lại thì mọi module sau đều chép lại đúng
cái lệch này.

## Ghi chú cho người tiếp tục

Đọc theo thứ tự: `docs-erp/00-START-HERE.md` → `backend-erp/CLAUDE.md` →
`backend-erp/arch/README.md` (bảng mức khai báo) → `backend-erp/arch/LEVELS.md` (bảng mức
**thực tế**, đọc kết quả lần chạy). Chạy `go run ./cmd/dev check` rồi `test`.

Ba cơ chế tự hết hạn đã nổ đúng lúc trong chặng này và sẽ còn nổ tiếp:
`Scope.Optional`, `targetChuaCo`, và `TestCIWorkflowUnverifiableStaysHonest`. Khi một
trong chúng đỏ, thông điệp lỗi nói đích danh việc phải làm — làm đúng thế, đừng nới lỏng.
