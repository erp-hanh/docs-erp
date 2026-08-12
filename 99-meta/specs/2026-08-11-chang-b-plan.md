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
3. ~~**Đợi CI ba job xanh**~~ — **xong** (`4bf2b5e`): `test`, `lint`, `arch` đều xanh.

**Chặng B đóng ở đây.** Phần bên dưới là bốn món nợ đã ghi từ lượt trước, và ba trong số
đó đã được giải ở lượt ba.

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

## Bốn món nợ — cập nhật 2026-08-12 (lượt ba)

**1. ~~Phân quyền hình thức~~ — ĐÃ GIẢI.** Migration `000005` thêm cột
`users.roles TEXT[] NOT NULL DEFAULT '{}'`; luồng cấp token đọc chính hàng `users` rồi ký
nguyên văn vào claim `roles`. Hằng `RoleMacDinh` biến mất khỏi cả ba chỗ nó từng sống.
Bảng vai trò ở `cmd/api/authz.go` tách thành `admin` (đủ sáu quyền) và `member`
(`user_read`, `user_list`, `change_password`).

Đo được, qua ngăn xếp đầy đủ với database thật: cùng một endpoint `POST /users`, hai token
thật do `/auth/login` cấp — `member` nhận **403** `ERR_AUTH_FORBIDDEN`, `admin` nhận
**201**; và `member` vẫn `GET /users` được **200**, nên cái 403 kia là về quyền chứ không
phải về một token hỏng. Ở tầng service, hai test đo tiếp: token ký ra mang đúng vai trò
của hàng `users` (verify qua **chính** middleware thật, không phải một phép parse thứ hai
— R-14), và thu hồi vai trò có hiệu lực ngay ở lần xoay token kế tiếp.

Ba khoản kèm theo phải biết:

- **`TEXT[]` cần một kiểu cột.** pgx đi qua `database/sql` trả `text[]` về dưới dạng
  **chuỗi literal** `{admin,member}`, không phải `[]string` — nhánh mặc định của
  `stdlib.Rows.Next` biến mọi kiểu lạ thành chuỗi. Nên có `shared/db.MangChuoi`
  (Scanner + Valuer), và `lib/pq` thành phụ thuộc **trực tiếp** cho đúng hai method phân
  tích literal đó. Không kết nối nào đi qua lib/pq.
- **Gán vai trò đi qua `PermUserUpdate`**, chưa có permission riêng. Nghĩa đen: ai sửa
  được user thì tự nâng được quyền cho mình. Chấp nhận được vì chỉ `admin` có
  `PermUserUpdate`, nhưng một `PermUserAssignRoles` tách riêng là bước đúng tiếp theo.
- **Tên vai trò không được kiểm.** `authz.Checker` chỉ trả lời "actor có quyền này không",
  không trả lời "vai trò này có tồn tại không", nên gõ nhầm một tên cho ra user không
  quyền gì — im lặng. Hướng thất bại an toàn (mặc định cấm) và nhìn thấy được (`UserDTO`
  trả `roles`), nhưng lời giải đúng là một câu hỏi thứ hai ở `authz.Checker`.

**2. ~~Không có đường tạo user đầu tiên~~ — ĐÃ GIẢI.** `go run ./cmd/dev bootstrap-user`,
đăng ký trong bảng lệnh của `backend-erp/CLAUDE.md` (test `TestLenhKhopCLAUDEmd` đối chiếu
hai chiều — nó đỏ ngay khi thiếu dòng đó).

Hai quyết định đáng giữ: mật khẩu đi qua **biến môi trường** `BOOTSTRAP_PASSWORD` chứ
không qua cờ dòng lệnh — đối số của một tiến trình đang chạy đọc được từ ngoài; và lệnh
gọi **service thật** (`auth.Module.TaoUser` → `UserService.CreateUser`) chứ không gõ tay
một câu `INSERT`, nên nó vẫn băm bcrypt đúng cost, vẫn chuẩn hóa email theo đúng cách
`uq_users_email_active` đòi, và vẫn ghi một dòng audit trong cùng transaction (R-17).

Nó **không** phải cửa sau: `TaoUser` kiểm quyền như mọi lời gọi khác. Thứ khác là bảng vai
trò — `cmd/dev` là một composition root nên nó tiêm một bảng riêng, hẹp đúng một
permission, cho một vai trò `bootstrap` chỉ tồn tại trong bộ nhớ của lệnh đó.

**3. ~~`ERR_AUTH_EMAIL_DUPLICATED` chưa có ca end-to-end~~ — ĐÃ GIẢI.**
`TestE2ETrungEmailTrongCungCongTyTra409` đo đường `23505` → `409` qua HTTP xuống Postgres,
kèm vế dễ mất nhất: xóa mềm rồi tạo lại cùng email **phải được** — đó là ca mà partial
unique index sinh ra để phục vụ.

**4. ~~Ba mã status sai so với C-API-02~~ — ĐÃ GIẢI.** Mã `ERR_COMMON_MALFORMED_REQUEST`
(`400`) vào bảng C-API-05, và `response.BindFailed` chốt ranh giới `400`/`422` **một lần
cho cả hệ thống** thay vì để mỗi handler tự chọn.

Quy tắc nó dùng là `validator.ValidationErrors` → `422`, **mọi thứ còn lại** → `400` — chứ
không phải một danh sách kiểu lỗi (`*json.SyntaxError`, `io.EOF`, `*strconv.NumError`, …)
phải giữ cho đầy đủ qua từng phiên bản của gin và `encoding/json`. Chiều suy luận đóng:
validator chỉ chạy sau khi request đã đọc xong, nên "lỗi là `ValidationErrors`" tương đương
"đã đọc được request", đúng câu hỏi mà C-API-02 dùng để phân biệt hai mã.

`:id` không phải UUID trả `404` bằng một lần kiểm ở **service**, ngay sau lệnh kiểm quyền
(R-15 đòi kiểm quyền là câu lệnh đầu tiên). Service là tầng sở hữu "không tồn tại", nên nó
là chỗ đúng — handler chỉ chuyển tiếp lỗi.

Đo qua ngăn xếp đầy đủ, tám ca trong một bảng: JSON hỏng / body rỗng / kiểu sai trong JSON
/ `?page=abc` → `400` **không** kèm `error.fields`; thiếu field bắt buộc / `page_size=500`
→ `422` **có** `error.fields`; `:id` không phải UUID ở `GET` và `DELETE` → `404`.

## Hai món nợ mới, cả hai đều đã có ranh giới đúng chỗ

**5. `PermUserAssignRoles` đã tách — còn lại là mở rộng.** Gán vai trò là thao tác duy nhất
trong module có thể nâng quyền của chính người thao tác, nên nó không còn đi chung
`PermUserUpdate`. Hôm nay chỉ `admin` có nó; giá trị nằm ở chỗ ngày mai thêm một vai trò
nhân sự hay hỗ trợ thì không phải nghĩ lại từ đầu.

Thu hồi vai trò (`roles: []`) **cũng** chịu permission này — đó là vế dễ sót nhất, và một
cài đặt "bỏ qua danh sách rỗng cho gọn" sẽ làm đường tước quyền người khác không còn ai
canh.

**6. Một bảng vai trò cho hai composition root — CẦN ADR.** `authz.Checker` nay trả lời
được câu hỏi thứ hai, `VaiTroTonTai(role)`, nên gán một tên gõ nhầm qua API trả `422` thay
vì tạo ra một user không quyền gì trong im lặng.

Nhưng `cmd/dev bootstrap-user` là composition root **thứ hai** và không import được bảng
của `cmd/api` (hai package `main`), nên nó khai mọi tên vai trò được yêu cầu là "có thật" —
tức nó tin chính tả của người chạy. Cái giá hẹp hơn nhiều so với đường API (người chạy đọc
ngay dòng log rồi đăng nhập thử trong một phút), nhưng nó vẫn là một lỗ.

Lời giải đúng là **một** bảng vai trò mà cả hai root cùng đọc. C-GO-08 chỉ nói về `cmd/api`
và không nói gì về ca hai root, nên theo chính `backend-erp/CLAUDE.md` mục 2 đây là ca phải
dừng lại và mở ADR, không phải chỗ tự quyết.

## Hai lỗi thật do chính test mới bắt được

Ghi lại vì cả hai đều là bằng chứng rằng cơ chế đang chạy, không phải chuyện bên lề:

1. **R-16 bắt `TaoUserInput.MatKhau`** thiếu `json:"-"`. Checker đọc **tên field** và
   "MatKhau" khớp y hệt "Password" — nó không bị đánh lừa bởi tiếng Việt.
2. **`tenHienThi` cắt sai** khi `-email " Admin@ViDu.test "`: `full_name` ra `" Admin"` với
   một dấu cách ở đầu mà không ai nhìn thấy trên màn hình. Service chuẩn hóa email của nó
   rồi, nhưng chuỗi đi vào hàm dẫn xuất tên là chuỗi **thô** từ cờ dòng lệnh.

## Ghi chú cho người tiếp tục

Đọc theo thứ tự: `docs-erp/00-START-HERE.md` → `backend-erp/CLAUDE.md` →
`backend-erp/arch/README.md` (bảng mức khai báo) → `backend-erp/arch/LEVELS.md` (bảng mức
**thực tế**, đọc kết quả lần chạy). Chạy `go run ./cmd/dev check` rồi `test`.

Ba cơ chế tự hết hạn đã nổ đúng lúc trong chặng này và sẽ còn nổ tiếp:
`Scope.Optional`, `targetChuaCo`, và `TestCIWorkflowUnverifiableStaysHonest`. Khi một
trong chúng đỏ, thông điệp lỗi nói đích danh việc phải làm — làm đúng thế, đừng nới lỏng.
