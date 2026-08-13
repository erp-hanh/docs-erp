# Chặng E — frontend, và lần đầu R-19 có người canh

**Trạng thái:** Đã duyệt · 2026-08-13
**Tiền đề:** Chặng D đóng trên `backend-erp@9492397`, `docs-erp@84a9843`, CI ba job xanh. `arch/LEVELS.md` có đúng một dòng không PASS: `R-19`, và nó không phải `FAIL` — nó là `chua chay`.

---

## 1. Mục tiêu, đo được

`R-19` là rule **duy nhất trong 24 rule chưa từng được gọi một lần nào**. Trạng thái của nó trong `arch/rules.go` là `Level: NA`, và `chayChecks()` bỏ qua mọi rule `NA` ngay ở dòng đầu vòng lặp — nên cột LAN CHAY của nó không phải "chưa đạt", mà là "chưa ai hỏi".

Chặng này làm nó bị hỏi.

| Vế của R-19 | Hôm nay | Sau chặng E |
|---|---|---|
| Frontend cấm gửi con số nó tự tính lên server | Không có file `.ts`/`.tsx` nào tồn tại | Một màn hình có trường tiền thật, và một luật đọc AST canh nó |
| Frontend cấm hardcode bảng chuyển trạng thái | Không tồn tại | Luật riêng, fixture hai chiều |
| Validate nghiệp vụ phải có bản backend | Không kiểm được bằng máy | Vẫn không kiểm được — ghi vào `Unverifiable`, không giả vờ |

**Phép thử của mục tiêu này không phải là "CI xanh".** Nó là: mở màn hình báo sự cố, sửa một dòng để gửi `repair_cost` do frontend nhân ra thay vì chuỗi người dùng gõ, rồi chạy bộ canh — **phải có thứ gì đó đỏ, và đỏ đúng dòng đó**. Chặng A đã dạy rằng bảy dòng `PASS tren tap RONG` sống sót trọn một chặng vì không ai hỏi câu này. Một checker `.ts` chạy trên một repo chưa có `.tsx` nào sẽ xanh y hệt một checker đang canh thật — và lần này ta biết trước, nên không có cớ.

---

## 2. Phạm vi

**Làm:**

| Thành phần | Lý do bắt buộc |
|---|---|
| `frontend-erp/**` — khung, `shared/api/`, một lát cắt dọc bốn màn hình | Repo trống; `R-19` không có gì để soi cho tới khi có code thật |
| `frontend-erp/eslint-rules/` — tám luật + fixture hai chiều | Bộ canh của `R-19` và lớp path/import của C-TS |
| `frontend-erp/arch/LEVELS.md` + runner | Bảng mức của repo này, cùng văn phạm với bảng của `backend-erp` |
| `shared/errors`, `shared/response` — 422 mang `fields` | C-TS-05 đã viết dựa trên giả định này; backend hiện không giữ nó |
| `GET /api/v1/auth/me` + permission `auth.self_read` | Login chỉ trả cặp token; không có đường hợp lệ nào để biết ai đang đăng nhập |
| CORS middleware ở `cmd/api` | Không có nó thì frontend bị chặn ở preflight, trước cả request đầu tiên |
| `docs-erp` — ADR-0011, ADR-0012, hợp đồng 422 ở C-API-05 | Hai quyết định mới và một hợp đồng công khai đổi hình dạng |

**KHÔNG làm, và lý do:**

`allowed_actions` — C-TS-06 yêu cầu bật/tắt nút dựa đúng field này, và backend không có nó ở bất kỳ response nào. Nhưng chính C-TS-06 đã chừa sẵn đường ra ở dòng 798: *"khi chưa có dữ liệu quyền cho một thao tác, cách đúng là để nút đó hiện và xử lý `403` cho tử tế, chứ không phải đoán bằng role."* Nghĩa là frontend chạy hợp lệ mà không cần field đó — cái bị cấm là **đoán**, không phải **không biết**. Xây `allowed_actions` bây giờ còn đòi một thiết kế cho việc rò quyền từ `authz.Checker` ra DTO mà không phá R-04 và ADR-0010, vốn cố ý nhốt bảng vai trò trong composition root. Đó là một quyết định về mô hình quyền, không phải một chi tiết của chặng frontend.

Rate limit `/auth/login` — mã `ERR_COMMON_RATE_LIMITED` đã có chỗ từ chặng B, nhưng repo **không có Redis client nào**, và câu hỏi "bộ đếm sống trong tiến trình hay chia sẻ giữa nhiều instance" chưa được trả lời ở bất kỳ ADR nào. Một rate limit in-process là một rate limit nhân lên theo số instance — nó là quyết định hạ tầng, và nó thuộc chặng vận hành cùng với thứ sẽ giữ bộ đếm đó.

Query param sai kiểu (`page=abc`) — quyết định "sai kiểu ra 422 có field" thu hẹp về **thân request JSON**. Query đi qua đường binding khác và sinh `*strconv.NumError`, kiểu thứ ba; kéo nó vào cùng chặng là mở rộng một thay đổi hợp đồng đang đã đủ rộng. `TestE2ERanhGioi400_422_404` case `"query param sai kieu"` giữ nguyên `400`.

Toàn bộ 30+ mệnh đề của C-TS — chặng này viết **tám** luật. Phần còn lại đi vào `Unverifiable` với tên gọi cụ thể, không đi vào im lặng. Xem mục 6.

Idempotency-Key — `shared/idempotency` tồn tại nhưng chỉ phục vụ consumer outbox nội bộ; không route HTTP nào đòi header đó. C-TS-05 nói `Idempotency-Key` sinh lúc mở form; frontend sinh và gửi, backend chặng này vẫn bỏ qua. Ghi thành nợ có tên chứ không sửa convention — vì hình dạng đúng của nó là backend thi hành, không phải frontend thôi gửi.

---

## 3. Vì sao `R-19` canh bằng ESLint, không bằng `arch/`

Bộ máy `arch/` đã có sẵn một dòng cho `R-19`, và thêm `.ts`/`.tsx` vào `rawExts` của `loader.go` là **đúng một dòng**. Cơ chế fixture hai chiều là generic trên `[]RawFile`. Bảng mức, `EffectiveLevels`, `gen_readme`, `TestRuleDeclaration` — tái dùng được hết. Lối đó rẻ, và nó sai.

Nó sai vì `loader.go` cố ý không dùng `go/packages`, và Go không có parser TypeScript. Một checker viết trong `arch/` sẽ là regex, giống hệt `sqlscan` — vốn tự khai "không phải parser đầy đủ". Đối chiếu với bảng phân loại mệnh đề C-TS: lớp đường-dẫn-và-import bắt được bằng regex, nhưng **lõi của R-19 thì không**. "Kết quả một phép nhân đi vào thân của một request `POST`" là dataflow: phải biết biến nào giữ kết quả phép toán, và biết nó chảy tới đối số thứ hai của `axios.post`. Regex không phân biệt nổi `total` được render ra JSX với `total` được nhét vào body — mà C-TS-05 dòng 617 nói thẳng ranh giới nằm đúng ở đó: *"hiển thị tạm tính trên màn hình được phép; gửi con số đó lên server thì không."*

Nếu ta viết checker regex trong `arch/` và để `R-19` chuyển sang `PASS`, ta được một dòng PASS trong khi mệnh đề trung tâm của rule vẫn không ai canh. Đó là cái bẫy của chặng A mặc bộ đồ mới, và lần này nó còn khó phát hiện hơn — vì tập không rỗng, chỉ có luật là rỗng ruột.

`@typescript-eslint` có AST thật với thông tin kiểu. Luật "biểu thức số học chảy vào thân request" viết được ở đó, và **chỉ** viết được ở đó.

Cái giá, nói thẳng: `arch/LEVELS.md` của `backend-erp` sẽ **không bao giờ** hiện `R-19 PASS`. Bảng điểm thành hai file. Ta trả giá đó và mua lại một thứ đắt hơn: `R-19` giữ `Level: NA` nhưng `Unverifiable` của nó được viết lại từ *"thuoc frontend-erp, khong phai repo nay"* — một lời từ chối — thành một con trỏ đích danh:

```go
{
	ID:    "R-19",
	Level: NA,
	Unverifiable: "canh o frontend-erp, khong o repo nay: luat eslint r19-no-computed-money-in-body " +
		"va r19-no-status-table, chay trong job 'arch' cua frontend-erp/.github/workflows/ci.yml. " +
		"Bang muc cua chung o frontend-erp/arch/LEVELS.md",
},
```

Một lỗ hổng có chữ ký khác một lỗ hổng im lặng. Và `RULES.md` không đổi một chữ nào trong mệnh đề R-19 — nên `arch-pin` **không phải chạy**.

---

## 4. Hợp đồng lỗi — bốn thay đổi ở backend

### 4.1 Mọi `422` mang `error.fields`

Hôm nay `422` có hai hình dạng. Từ binding thì có `fields`; từ service thì không, vì `response.Error` chỉ đọc `Code`/`Message`/`HTTPStatus` của `*apperr.Error`, và `apperr.Error` không có chỗ nào để đựng field.

**Mười** chỗ trong repo gọi `apperr.ValidationFailed(code, message)` — không phải hai như bảng kiểm kê chặng D ghi, và không phải chín như bản đầu của chính spec này viết. Bản đầu nói "chín" ở văn xuôi trong khi bảng ngay dưới liệt kê mười; agent làm E1 đếm bằng grep và bắt được. Con số đúng là mười:

| Chỗ | Field lẽ ra phải có |
|---|---|
| `breakdown_service.go` `kiemThoiDiemSuCo` ×2 | `occurred_at` |
| `breakdown_service.go` `kiemChiPhiSuaChua` | `repair_cost` |
| `service/errors.go` `dichViPhamCheck` ×4 | trạng thái máy / loại máy / trạng thái kế hoạch / `repair_cost` |
| `machine_service.go` `kiemNguoiPhuTrach` | `assigned_to` |
| `user_service.go` `bamMatKhau` | `password` — **không phải `new_password`**; xem ghi chú dưới bảng |
| `user_service.go` `kiemGanVaiTro` | `roles` |

Bản đầu của spec này ghi `new_password` cho `bamMatKhau`. Sai: `bamMatKhau` chỉ có hai call site (`CreateUser`, `UpdateUser`), cả hai nhận giá trị từ field mang tag `json:"password"`. Tên `new_password` sống ở đường đổi mật khẩu, mà đường đó gọi thẳng `bcrypt.GenerateFromPassword` và **không chạm `bamMatKhau`**. Gán `new_password` sẽ bảo form tô một ô mà `POST /users` không có. Agent làm E5 đi đọc DTO thật và bắt được.

**Kéo theo — một lỗi 500 chưa ai bịt, tìm thấy khi làm E5.** `AuthService.ChangePassword` không dịch `bcrypt.ErrPasswordTooLong`; nó trả `fmt.Errorf(...)`, tức **500**. Mà `changePasswordRequest.New` chỉ ràng buộc `max=128` **ký tự**, nên một mật khẩu tiếng Việt 40 ký tự (80 byte) lọt binding rồi cho ra 500. Đây đúng là ca mà `bamMatKhau` đã dịch cho đường tạo/sửa user — chỉ khác là đường đổi mật khẩu chưa ai bịt. Nó không phải một trong mười call site nên không thuộc E5. **Đây mới là chỗ tên `new_password` có nghĩa.**

**Điều dễ làm sai nhất nằm ở dòng 1-11 của `shared/errors/errors.go`:** package đó cố ý không import gì ngoài stdlib, đặc biệt không import `gin` và không import `shared/response` — vì service import nó, và R-03 cấm service phụ thuộc HTTP. Nên kiểu đựng field phải là một kiểu **của `shared/errors`**, và `response.Error` tự ánh xạ sang `response.FieldError` khi ghi envelope. Tái dùng thẳng `response.FieldError` là dựng một phụ thuộc ngược mà R-03 sẽ bắt — và nếu nó không bắt thì tệ hơn.

Điểm may mắn duy nhất: chữ ký `Error(c *gin.Context, err error)` không đổi, nên **24 call site của `response.Error` không phải sửa một dòng nào**.

Bốn chỗ trong `dichViPhamCheck` là hàng phòng thủ cuối cho constraint CHECK — không đường chạy bình thường nào chạm tới. Gán tên field cho chúng là gán ước lệ. Ghi điều đó vào comment tại chỗ, đừng để người sau tưởng nó chính xác.

### 4.2 Sai kiểu trong thân JSON ra `422` có field

`BindFailed` hiện phân loại đúng một lần: `validator.ValidationErrors` thì `422`, **mọi thứ khác** thì `400` không field. Comment ở dòng 82-92 giải thích lựa chọn đó có chủ đích — "danh sách đó dài ra theo từng phiên bản của gin và của encoding/json".

Đảo nó là đảo một quyết định có lý lẽ ghi thành văn. Ta vẫn đảo, vì ca người dùng gõ lại được mà không nhận được ô nào để tô là ca form không làm được việc của nó. Nhưng phải biết mua gì:

`"repair_cost": 1500000` sinh `*json.UnmarshalTypeError`, và kiểu đó **mang sẵn** thuộc tính `Field`. Lấy tên ô ra là việc dễ.

`"planned_date": "01/09/2026"` thì không. Nó đi qua `time.Time.UnmarshalJSON` và trả về `*time.ParseError` — một lỗi chỉ biết layout và value, **không biết mình nằm ở field nào của struct cha**. Không có cách nào moi tên ô ra khỏi nó.

Đường ra không phải là dò offset hay bọc thêm một lớp lỗi. Nó đã có tiền lệ trong chính repo này: `repair_cost` bind vào `RepairCostText string` rồi handler tự chuyển. Ngày người dùng gõ đi theo đúng khuôn đó — `planned_date` và `commissioned_date` bind thành `string`, handler parse và tự đặt tên ô khi hỏng.

Cái giá phải ghi vào spec chứ không giấu: **DTO mất kiểu tĩnh ở các trường ngày**, và `time.Time` không còn kiểm hộ định dạng nữa. Đổi lại, tên ô là thứ có thật chứ không phải suy đoán, và hình dạng này đã sống trong repo từ chặng C.

`400` co lại đúng phạm vi nghĩa đen của nó: JSON hỏng cú pháp, body rỗng. Bốn test đang khóa `400` cho sai kiểu sẽ đỏ — chúng **phải** đỏ, và sửa chúng là sửa hợp đồng, không phải sửa test cho vừa.

### 4.3 `repair_cost` toàn khoảng trắng ra `422`

```go
func chiPhiTuChuoi(chuoi string) (decimal.Decimal, error) {
	sach := strings.TrimSpace(chuoi)
	if sach == "" {
		return decimal.Zero, nil
	}
	return decimal.NewFromString(sach)
}
```

`TrimSpace` chạy trước, nên `""` và `"  "` rơi vào cùng nhánh. Trên một trường tiền, biến một lỗi gõ thành `0` im lặng là loại sai sáu tháng sau mới lộ ra trong báo cáo.

Sửa là kiểm `chuoi == ""` **trước** `TrimSpace`, không dùng biến `sach` để so rỗng. Hai ca đang đúng phải tiếp tục đúng: chuỗi rỗng thật và field vắng mặt vẫn là "không khai chi phí" = `0`; `"  1500  "` vẫn là `1500.0000`. Hiện **không có test nào** cho `"  "` — đó là lỗ hổng, không phải hành vi đã chọn.

### 4.4 Hai hình dạng, một bảng

Sau ba thay đổi trên, hợp đồng lỗi đọc được thành một câu: **`422` luôn có `fields`; `400` không bao giờ có.** Hôm nay câu đó sai ở cả hai vế. Đó là thứ C-TS-05 cần để tồn tại.

---

## 5. Hai món backend thiếu mà frontend không chạy được nếu không có

**CORS.** Không có middleware nào, không có chuỗi `Access-Control` nào trong repo. Vite dev server ở cổng khác bị trình duyệt chặn ở preflight `OPTIONS`, trước cả request đầu tiên. Middleware gắn ở gốc cùng `requestid` và `recovery` trong `cmd/api/router.go`, origin đọc từ cấu hình chứ không phải `*`.

Lý do **không** phải "`Authorization` là credential nên không được dùng `*`" — bản đầu của spec này viết vậy và nó sai. Trong chuẩn CORS, "credentials" là cookie, chứng chỉ TLS client và HTTP auth do **trình duyệt** quản lý; một header `Authorization` do JavaScript tự gán không nằm trong đó, và `ACAO: *` với nó là hợp lệ và chạy được. Agent làm E3 bắt được chỗ này.

Lý do đúng: `*` là một lời hứa công khai đã phát hành trong header của **mọi** response, và rút lại nó là một thay đổi phá vỡ tương thích. Một allowlist thì hẹp lại hoặc rộng ra lúc nào cũng được. Kết luận không đổi, chuỗi nhân quả thì đổi.

Hệ quả kéo theo, và nó ràng buộc E8/E11: vì `Authorization` không phải credential theo nghĩa CORS, **không** set `Access-Control-Allow-Credentials`, và frontend **không được** bật `withCredentials: true` / `credentials: 'include'` — nếu bật, trình duyệt chặn dù origin hợp lệ. Ngày refresh token chuyển sang cookie `httpOnly` là ngày điều này phải đổi.

**`GET /api/v1/auth/me`.** `POST /auth/login` trả đúng `access_token`, `refresh_token`, `expires_in` — không `user_id`, không tên, không email, không vai trò. Frontend hoặc phải tự giải mã JWT (biến hình dạng claim thành hợp đồng công khai với client, một thứ ta chưa từng hứa), hoặc có một endpoint.

Điểm phải quyết chứ không lách: R-15 đòi mọi method public của service mở đầu bằng `s.authz.Can`. `/me` không có ngoại lệ nào cấp sẵn, nên nó **không** được đứng ngoài. Đường sạch là một permission mới `auth.self_read`, cấp cho cả ba vai trò trong `cmd/internal/vaitro` — một permission mà mọi vai trò đều có vẫn là một permission, và nó khai ra điều đang xảy ra. Bịa một ngoại lệ trong service để `/me` khỏi phải qua `Can` là lách đúng cái mà mục 4 của bản bàn giao gọi tên.

---

## 6. Bộ canh trong `frontend-erp`

```text
frontend-erp/
├── eslint-rules/
│   ├── <mot-file-mot-luat>.js
│   └── __fixtures__/<ten-luat>/{vi-pham,hop-le}.tsx
├── arch/
│   ├── LEVELS.md              bang muc, sinh tu runner
│   └── rules.mjs              bang khai bao: ma, muc, Unverifiable, fixture
├── scripts/arch.mjs           chay luat tren fixture, sinh LEVELS.md
└── src/{modules,shared}/
```

Bảng mức dùng **cùng văn phạm** với `backend-erp/arch/LEVELS.md`: `RULE | KHAI | THUC TE | LAN CHAY | FILE`. Hai file, một ngôn ngữ. Và ba mệnh đề của `TestRuleDeclaration` được dịch nguyên sang runner, vì chúng là thứ giữ cho bảng không mục:

- `FULL` thì `Unverifiable` phải **rỗng**;
- `PARTIAL` và `NA` thì `Unverifiable` phải **khác rỗng** — trạng thái phải biện minh, không phải chỗ trú ẩn;
- một luật **không có fixture vi phạm** là `FAIL`, không phải `PASS`.

Điều cuối là bản dịch trực tiếp của bài học chặng A, và nó là lý do bộ canh này không lặp lại `PASS tren tap RONG`.

**Tám luật của chặng E:**

| Luật | Mệnh đề | Lớp |
|---|---|---|
| `r19-no-computed-money-in-body` | Kết quả biểu thức số học đi vào thân `POST`/`PUT`/`PATCH` | AST, dataflow |
| `r19-no-status-table` | Object ánh xạ trạng thái→trạng thái dùng để quyết định bật/tắt | AST |
| `c-ts-01-module-boundary` | Module khác chỉ import qua `api/` | import |
| `c-ts-01-shared-no-modules` | `shared/` cấm import `modules/` | import |
| `c-ts-01-no-deep-relative` | Cấm `../../` vượt cấp; dùng alias `@/` | import |
| `c-ts-04-no-raw-http` | Cấm `fetch(`/`axios` ngoài `shared/api/` | định danh |
| `c-ts-04-base-url-once` | Cấm chuỗi `/api/v1` ngoài `client.ts` | chuỗi |
| `c-ts-06-no-role-guess` | Cấm suy quyền từ `role` để ẩn/khóa nút | AST |

**Tập sink của `r19-no-computed-money-in-body` phải rộng hơn chữ của `RULES.md`** — phát hiện quan trọng nhất của chặng, do agent làm E9 tìm ra.

`RULES.md` khai dấu hiệu vi phạm là *"tham số thứ hai của `axios.post(`/`axios.put(`, hoặc `body` của `fetch(`"*. Nhưng C-TS-04 **cấm** `fetch`/`axios` ở mọi nơi ngoài `src/shared/api/`, và C-TS-03 bắt mọi lệnh ghi đi qua `useMutation` → `api/` → `send()`. Nghĩa là một luật hiện thực **đúng chữ** của R-19 sẽ không bao giờ khớp một dòng nào trong `src/modules/**`: nó xanh vĩnh viễn. Đó chính là "luật trang trí cho một dòng PASS giả" mà mục 1 cảnh báo — và nó suýt xảy ra vì hai văn bản của chính dự án mâu thuẫn nhau.

Tập sink thật gồm thêm: `mutate`/`mutateAsync`, `send('POST'|'PUT'|'PATCH', …)`, và hàm ghi import từ `api/`. Phép thử: một form gọi `tao.mutateAsync({ repair_cost: String(soGio * donGia) })` phải đỏ — đã kiểm, đỏ đúng dòng phép tính và gọi tên dòng gửi. Cùng phép tính đó render ra JSX thì không đỏ.

Điều này **không** sửa `RULES.md` — mệnh đề R-19 giữ nguyên, `arch-pin` không phải chạy. Cái phải ghi lại là tập sink rộng hơn danh sách ví dụ trong "Dấu hiệu vi phạm", và chỗ ghi là ADR-0012 cùng bảng mức của `frontend-erp`.

Hướng phân tích cũng là thứ giữ cho ngoại lệ thứ hai dưới đây đúng **theo cấu trúc chứ không theo danh sách loại trừ**: luật chạy ngược **từ sink**, và JSX không nằm trong tập sink — nên không có đường nào từ một sink dẫn tới một node JSX. Thêm một cách hiển thị mới không làm luật bắt oan thêm; chỉ thêm một cách **gửi** mới mới mở đường cho nó.

**Ba ngoại lệ phải tôn trọng, nếu không sẽ bắt oan** — và bắt oan thì sửa checker, không lách code:

1. C-TS-04 chừa đường lên v2: *"Sang v2 từng phần thì phần đó khai đường dẫn đầy đủ."* Luật `base-url-once` cấm `/api/v1`, không cấm mọi đường dẫn đầy đủ.
2. C-TS-05 dòng 617: hiển thị tạm tính ra màn hình **được phép**. Luật `no-computed-money-in-body` chỉ cắn khi con số chảy vào thân request.
3. C-TS-06 dòng 798: một nút **không kiểm gì cả** là hợp lệ. Luật `no-role-guess` chỉ cắn khi có logic suy từ `role` hoặc bảng hardcode để ẩn/khóa. Thiếu kiểm tra không phải vi phạm.

Phần C-TS còn lại — cache key theo dữ liệu hay theo màn hình, `useQuery` chảy vào `useState`, `.data` bóc hai lần, phân loại validate nào là nghiệp vụ — vào `Unverifiable` với tên gọi cụ thể. Chúng không kiểm được ở chặng này; chúng **được ghi tên** ở chặng này.

---

## 7. Lát cắt dọc — và vì sao đúng bốn màn hình này

| Màn hình | Endpoint | Vì sao nó có mặt |
|---|---|---|
| Đăng nhập | `POST /auth/login`, `POST /auth/refresh` | Không có nó thì không màn nào khác gọi được |
| Danh sách máy | `GET /machines` | Phân trang + lọc + sắp xếp — ca của C-TS-03: bộ lọc sống ở URL, không ở `useState` |
| Chi tiết & sửa máy | `GET`, `PATCH /machines/:id` | Form có `422` với `fields` thật — ca nghiệm thu của mục 4.1 |
| **Báo sự cố** | `POST /machines/:id/breakdowns` | **Ca duy nhất trong toàn bộ API có trường tiền** |

Màn thứ tư không được chọn vì nó hữu ích. Nó được chọn vì `repair_cost` là trường tiền duy nhất mà API hiện có, nên nó là **thứ duy nhất `r19-no-computed-money-in-body` có để soi trên code thật**. Bỏ nó đi thì luật lõi của cả chặng chạy trên tập rỗng, và ta quay lại điểm xuất phát với thêm một bộ máy.

Ba điều lát cắt này phải chứng minh, không phải chỉ chạy:

**Tiền không đi qua `number`.** `repair_cost` là chuỗi từ input tới body request. `number` trong JavaScript **là** `float64` — đúng cái mà C-DB-02 cấm ở phía Go. Một số tiền chạm `parseFloat` ở frontend là cùng một lỗi, chỉ khác ngôn ngữ.

**`422` tô đúng ô.** Backend trả `fields`, form tô. Đây là chỗ mục 4.1 được nghiệm thu từ đầu kia của dây.

**`403` được xử tử tế.** Không đăng xuất, không tự thử lại, không màn trắng. Và không nút nào bị ẩn bằng cách đoán từ `role` — vì `allowed_actions` chưa có, và C-TS-06 dòng 798 nói cách đúng là để nút hiện.

---

## 8. Kéo theo ở `docs-erp`

| Thay đổi | Vì sao |
|---|---|
| **ADR-0011** — TanStack Query v5 | C-TS-03 mô tả đúng mô hình đó (tách server state, cache key theo dữ liệu); chọn khác là tự tạo khoảng cách với convention đã viết |
| **ADR-0012** — R-19 canh ở `frontend-erp` bằng ESLint | Bảng điểm thành hai file; một quyết định có giá phải ghi lại, kèm điều kiện mở lại |
| C-API-05: hợp đồng `422`/`400` mới | Hình dạng lỗi là hợp đồng công khai, và nó đang đổi ở cả hai vế |
| C-API-05 bảng ánh xạ constraint: bổ sung tên field cho bốn dòng CHECK | Sau 4.1 mỗi `422` phải có field; bốn dòng đó hiện không có |
| C-TS-04: ghi ngoại lệ v2 vào phần checker | Luật cấm `/api/v1` phải không cấm nhầm v2 |
| C-TS-06: ghi rõ `allowed_actions` chưa tồn tại, đường hợp lệ là để nút hiện + xử `403` | Convention hiện đọc như thể field đó đã có |
| C-TS-05: ghi `Idempotency-Key` frontend gửi, backend chưa thi hành | Nợ có tên |

**Không** đổi `RULES.md` — mệnh đề R-19 giữ nguyên từng chữ, nên `arch-pin` không phải chạy.

---

## 9. Định nghĩa hoàn thành

Mỗi dòng dưới đây là một phép đột biến, không phải một lần chạy xanh.

- Sửa màn báo sự cố để gửi `repair_cost` do frontend nhân ra, chạy bộ canh → **đỏ, đúng dòng đó**. Hoàn lại → xanh.
- Thêm vào một component một object `{ ke_hoach: ['dang_lam','huy'] }` dùng để tính `disabled` → `r19-no-status-table` đỏ.
- Xóa thư mục fixture vi phạm của một luật bất kỳ → runner báo luật đó `FAIL`, **không** phải `PASS`.
- Render một con số tạm tính ra JSX mà không gửi đi → **không luật nào đỏ** (ngoại lệ C-TS-05 dòng 617 còn sống).
- Viết `/api/v2/orders` trong một file `api/` → **không đỏ**; viết `/api/v1/orders` → đỏ.
- Một nút không kiểm quyền gì cả → **không đỏ**; một nút `disabled={role !== 'admin'}` → đỏ.
- Import `@/modules/auth/hooks/use-login` từ `modules/machine` → đỏ; import `@/modules/auth/api` → không đỏ.
- `POST /machines` với `assigned_to` là user không tồn tại → `422` **có** `fields[0].field === "assigned_to"`, và form tô đúng ô đó.
- `POST /machines/:id/breakdowns` với `"repair_cost": 1500000` (số JSON) → `422` có `fields`, **không** còn là `400`.
- `"repair_cost": "  "` → `422`; `"repair_cost": ""` và field vắng mặt → vẫn `0.0000`.
- `GET /auth/me` bằng token hợp lệ trả đúng người đang đăng nhập; gọi không token → `401`.
- Frontend ở cổng khác gọi được `/api/v1/machines` trong trình duyệt thật, không chỉ trong test.
- `go run ./cmd/dev check` và `test` xanh; `arch-update` cho diff **không dòng nào hạ mức**.
- CI của `frontend-erp` có job `arch` chạy bộ luật trên fixture, và nó đỏ khi ta cố tình làm nó đỏ.

---

## 10. Rủi ro đã biết

**Bảng điểm thành hai file, và file thứ hai chưa có ai bảo vệ nó.** `backend-erp/arch/LEVELS.md` đã sống sót qua bốn chặng nhờ một tập test canh chính nó — `TestRuleDeclaration`, `TestFixtures`, `TestOptionalRootStaysHonest`. Bảng của `frontend-erp` sinh ra hôm nay với ba mệnh đề đầu tiên được dịch sang, và không có bốn chặng nào chứng minh chúng đủ. Điểm phải canh ở chặng sau: bảng mới có mục không, hay nó cũng cứng như bảng cũ.

**Luật dataflow là luật khó nhất và nó là luật quan trọng nhất.** `r19-no-computed-money-in-body` phải phân biệt một biến chảy vào JSX với cùng biến đó chảy vào thân request. Viết chặt quá thì bắt oan mọi con số tạm tính; viết lỏng quá thì nó là một luật trang trí — và một luật trang trí ở đây tệ hơn không có luật, vì nó cho một dòng PASS. Phép thử ở mục 9 có **cả hai chiều** vì lý do đó: một ca phải đỏ và một ca phải không đỏ.

**Đảo `BindFailed` là đảo một quyết định đã có lý lẽ.** Comment ở dòng 82-92 cảnh báo chính xác việc ta sắp làm: liệt kê từng kiểu lỗi phân tích là một danh sách dài ra theo phiên bản thư viện. Ta chấp nhận, và giới hạn thiệt hại bằng cách chỉ nhận **một** kiểu (`*json.UnmarshalTypeError`) rồi đẩy ngày sang chuỗi — thay vì mở một bảng phân loại lỗi sẽ phải bảo trì mãi. Nếu chặng sau thấy mình đang thêm kiểu thứ ba vào bảng đó, đó là dấu hiệu hướng này sai chứ không phải chưa đủ.

**Trường ngày mất kiểu tĩnh.** `planned_date` và `commissioned_date` thành `string` trong DTO. Đổi lại tên ô có thật. Nhưng nó mở một cửa: người sau có thể thấy chuỗi là tiện và đẩy thêm trường khác sang chuỗi mà không có lý do tên-ô. Ràng buộc: chỉ trường **người dùng gõ ngày** đi lối này, và mỗi lần thêm phải có dòng giải thích tại chỗ.

**Ba màn hình đầu dễ, màn thứ tư mới là chặng.** Đăng nhập và danh sách là code khuôn. Toàn bộ giá trị của chặng nằm ở màn có trường tiền và ở tám luật canh nó. Rủi ro là thời gian trôi vào ba màn dễ, rồi màn thứ tư và bộ luật bị làm vội ở cuối — đúng chỗ không được làm vội.
