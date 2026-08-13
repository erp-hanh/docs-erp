# Bàn giao — sau chặng E

File này nối tiếp `2026-08-13-ban-giao.md` (viết sau chặng D, cùng ngày). Nó tồn tại vì
cùng một lý do hẹp: sau chặng E có một bảng kiểm kê việc chưa làm, một tập vùng mù đã đo
được, và vài câu hỏi chưa quyết — tất cả chỉ sống trong một phiên làm việc.

Nó **không** thay thế `00-START-HERE.md` hay hai file spec chặng E; nó ghi thứ chúng chưa ghi.

---

## 0. Đọc dòng này trước mọi dòng khác

**Không một dòng nào của chặng E được commit.** Toàn bộ nằm trong working tree:

| Repo | HEAD | Thay đổi chưa commit |
|---|---|---|
| `backend-erp` | `9492397` | **39 file** |
| `docs-erp` | `9335b46` | **8 file** (kể cả chính file này) |
| `frontend-erp` | `4f13696` | **15 file** |
| `infra-erp` | `d66dcf7` | 0 — vẫn trống |

Một lệnh `git checkout .` xóa sạch chặng E. Việc đầu tiên của phiên sau là **đọc diff rồi
commit**, không phải viết thêm gì.

---

## 1. Hệ thống đang ở đâu

Chặng E đã đóng: **frontend tồn tại, và `R-19` có người canh.**

`R-19` từng là rule duy nhất trong 24 rule **chưa từng chạy một lần nào** — không phải
`FAIL`, mà `chua chay`, vì `chayChecks()` bỏ qua mọi rule `NA` ngay ở dòng đầu vòng lặp.

Trạng thái đo được, không phải báo cáo:

| | `backend-erp` | `frontend-erp` |
|---|---|---|
| build / tsc | `0` | `0` |
| vet / lint | `0` | `0` |
| arch | `0` — 24 rule | `0` — **9 luật + 5 dòng `N/A`** |
| test | 31 package `ok`, 0 FAIL | **278 test, 26 file** |

`go generate ./arch/...` + `git diff --exit-code` sạch. `check-ids.ps1`: 135 ID, không
tham chiếu treo.

**Dự án giờ có hai bảng điểm.** `frontend-erp/arch/LEVELS.md` dùng đúng văn phạm sáu cột
của bảng backend, và ba mệnh đề khai báo của `TestRuleDeclaration` đã được dịch sang
runner — trong đó mệnh đề quan trọng nhất: **một luật không có fixture vi phạm là `FAIL`,
không phải `PASS`**. Đó là bản dịch trực tiếp bài học chặng A.

`R-19` trong `backend-erp/arch/LEVELS.md` **vẫn là `N/A / chua chay`, và đó là đúng thiết
kế** (ADR-0012). Cái đổi là `Unverifiable` của nó: từ một lời từ chối (*"thuoc frontend-erp,
khong phai repo nay"*) thành một con trỏ đích danh sang luật ESLint và job CI canh nó.
Một lỗ hổng có chữ ký khác hẳn một lỗ hổng im lặng.

**Không có việc nào đang dở.**

## 2. Đọc gì để bắt kịp, theo thứ tự

1. `2026-08-13-ban-giao.md` — bàn giao sau chặng D. File này giả định bạn đã đọc nó.
2. `99-meta/specs/2026-08-13-chang-e-frontend-design.md` — đặc biệt **mục 3** (vì sao
   `R-19` canh bằng ESLint chứ không mở rộng `arch/`) và **mục 6** (tập sink rộng hơn chữ
   của `RULES.md` — xem 3.3 dưới đây).
3. `99-meta/specs/2026-08-13-chang-e-plan.md` — bảng task, và mục "Cuối chặng".
4. `03-decisions/ADR-0011` (TanStack Query) và `ADR-0012` (R-19 canh ở frontend).
5. `frontend-erp/arch/LEVELS.md` và `frontend-erp/docs/Routing.md` — bảng điểm thứ hai, và
   ba khiếm khuyết chỉ lộ ra khi chạy thật.

Chạy `go run ./cmd/dev check` rồi `test`, và `npm run lint && npm run arch && npm test`
trước khi tin bất cứ điều gì ở trên.

## 3. Việc chưa làm

### 3.1 Vận hành — khối lớn duy nhất còn lại, và nó là chặng F

`infra-erp` vẫn **trống**: bốn thư mục nó tự khai (`compose/`, `config/`, `scripts/`,
`observability/`) đều không tồn tại. Chưa có backup/recovery, metrics, tracing (P-OBS có
6 hard check, chưa checker nào), deploy, security scan.

Hai thứ chặng E làm thay đổi hình dạng của chặng F:

- **CORS đã có và đã được chứng minh trong trình duyệt thật**, nhưng `CORS_ALLOWED_ORIGINS`
  chưa được set ở đâu ngoài lệnh chạy tay. Mặc định là **đóng** — không set thì frontend bị
  chặn. Đây là biến môi trường đầu tiên mà `infra-erp` phải sở hữu.
- **`frontend-erp` giờ có CI ba job** (`lint`, `arch`, `test`). `infra-erp` vẫn không có CI.

### 3.2 Nợ backend đã ghi thành văn bản

| Việc | Ghi ở | Đổi gì sau chặng E |
|---|---|---|
| Rate limit `/auth/login` | spec chặng B | **Hoãn có lý do mới**: repo không có Redis, và câu hỏi "bộ đếm trong tiến trình hay chia sẻ giữa nhiều instance" chưa ADR nào trả lời. Nó thuộc chặng vận hành, cùng với thứ sẽ giữ bộ đếm |
| Quên mật khẩu / đặt lại | spec chặng B | — |
| `currencies`, `units`, `provinces` — có tên trong registry C-DB-04, không migration | C-DB-04 vs `migrations/` | — |
| `document_counters` — chưa phân nhóm bảng, đòi ADR riêng | ADR-0003 | — |
| Job dọn `outbox` theo hạn giữ liệu | ADR-0006 | — |
| Dead-letter + giới hạn số lần thử | ADR-0006, **chưa quyết** | — |
| `/metrics` — R-13 khai ba endpoint, mới có hai | `cmd/api/router.go` | — |
| Import CSV/Excel — chưa có quy ước định dạng | ADR-0004 | — |
| Kalmar tách module hay không | ADR-0001, **chưa quyết** | — |
| `allowed_actions` không tồn tại ở response nào | C-TS-06 | **Hoãn có đường ra**: C-TS-06 dòng ~798 chừa sẵn — nút cứ hiện, xử `403` tử tế. Cái bị cấm là **đoán**, không phải **không biết**. Xây nó đòi thiết kế rò quyền từ `authz.Checker` ra DTO mà không phá R-04/ADR-0010 |
| `Idempotency-Key` — frontend gửi, backend chưa thi hành | C-TS-05 | Nợ **có tên**: `shared/idempotency` chỉ phục vụ consumer outbox nội bộ, không route HTTP nào đòi header đó |

**Đã trả trong chặng E:** hợp đồng `422` mang `fields` ở cả 10 call site service; sai kiểu
thân JSON ra `422` có field; `"  "` trên trường tiền ra `422` thay vì `0` im lặng; `/auth/me`;
CORS; và một lỗi `500` chưa ai biết — `ChangePassword` không dịch `bcrypt.ErrPasswordTooLong`,
nên một mật khẩu tiếng Việt 40 ký tự (80 byte) lọt binding `max=128` **ký tự** rồi ra 500.

### 3.3 Vùng mù của bộ canh frontend — đo được, không phải suy đoán

Đây là mục quan trọng nhất của file này. Chín luật ESLint canh `R-19` và lớp path/import
của C-TS. Chúng canh **thật** — đã bắt một vi phạm có thật trong code sản phẩm. Nhưng
chúng có vùng mù, và mỗi vùng mù dưới đây được tìm ra bằng cách **dựng probe và chạy**,
không phải bằng đọc code.

**Một mâu thuẫn giữa hai văn bản của chính dự án, sống sót bốn chặng.** `RULES.md` khai
dấu hiệu vi phạm `R-19` là *"tham số thứ hai của `axios.post(`, hoặc `body` của `fetch(`"*.
Nhưng C-TS-04 **cấm** `fetch`/`axios` ở mọi nơi ngoài `src/shared/api/`, và C-TS-03 bắt
mọi lệnh ghi đi qua `useMutation` → `api/` → `send()`. Một luật hiện thực **đúng chữ**
`R-19` sẽ không bao giờ khớp một dòng nào trong `src/modules/**` — nó xanh vĩnh viễn.
Tập sink thật rộng hơn: `mutate`/`mutateAsync`, `send('POST'|…)`, hàm ghi import từ `api/`,
và prop callback. **`RULES.md` không đổi một chữ** (nên `arch-pin` không phải chạy); điều
này ghi ở ADR-0012.

**Ba lỗ đã bịt, mỗi lỗ một luật hoặc một mở rộng:**

| Lỗ | Đo được là | Đã bịt bằng |
|---|---|---|
| Thân request dựng ở **file khác** | `lint exit=0` với vi phạm còn nguyên | Luật thứ chín `r19-than-request-phai-dung-tai-cho` — biến hình dạng không soi được thành hình dạng **bất hợp pháp** |
| Chuỗi **prop callback** (`onSubmit({...})`) — khuôn React tự nhiên nhất | `exit=0` | Sink thứ 7, nhận diện qua **khoá `snake_case`** (C-TS-02 buộc DTO giữ snake_case còn JS dùng camelCase — dấu hiệu đặc thù dự án này) cộng chữ ký prop khai trong cùng file |
| **Gán thành viên** (`i.repair_cost = String(a*b)`) | `exit=0` | `memberWriteExpressionsOf`, cổng chặn là **chỗ gọi sink** chứ không phải danh sách loại trừ |

**Vùng mù còn lại, đã có tên trong `arch/rules.mjs`:** aliasing (`const bi = than; bi.total = a*b`);
ghi qua hàm phụ (`function dat(o){o.total=a*b}`); `Object.defineProperty`; chữ ký prop khai
ở **file khác**; và mắt xích **giữa** chuỗi (`update.submit({...})` — `update` là giá trị
trả về của hook, không phải prop, không phải sink cũ).

**Một bắt oan đã chấp nhận, ghi ra chứ không giấu:** một patch bộ lọc/phân trang có khoá
snake_case đọc như một thân request — `onChange({ page_size: base * 2 })` sẽ đỏ. Cách duy
nhất tách được là một danh sách tên prop, tức đúng lối regex-theo-tên mà ADR-0012 từ chối.

### 3.4 Câu hỏi chưa quyết

1. **Định dạng ngày: có nới cho date-only không?** Ba trường ngày (`planned_date`,
   `commissioned_date`, `occurred_at`) đòi RFC3339 **đầy đủ giờ**. Cột của hai trường đầu là
   `DATE` nên `"2026-09-01"` nghe rất hợp lý — nhưng nới là nới một hợp đồng công khai.
   Frontend hiện tự nối `T00:00:00Z` (UTC có chủ đích: offset địa phương sẽ để phần giờ vô
   nghĩa quyết định ngày nào rơi vào cột `DATE`).
2. **`commissioned_date` không có đường gỡ.** Gửi `""` ra `422`, vắng mặt = "không đổi".
   Form chặn tại chỗ kèm thông điệp nói rõ lý do, thay vì âm thầm bỏ field — bỏ field sẽ
   báo lưu thành công trong khi ngày cũ còn nguyên trong database. Đóng nó tử tế cần một
   quyết định hợp đồng ở backend (`null`, hay một cờ xóa riêng).
3. **`PATCH /machines/:id` cho phép làm rỗng `code`/`name`/`location`; `POST` thì không.**
   `binding:"omitempty,max=..."` nên `"name": ""` qua được binding và ghi chuỗi rỗng xuống
   cột. Frontend **không** tự thêm `required` — làm vậy là dựng bản sao thứ hai của một
   quy tắc nghiệp vụ, đúng thứ C-TS-05 cấm. Cần backend trả lời.
4. **Link lùi làm rơi bộ lọc.** Màn chi tiết chỉ nhận `id`, không biết người dùng tới từ bộ
   lọc nào. Nút Back của trình duyệt giữ đúng. Muốn link lùi cũng giữ thì phải mang query
   theo trong link mỗi dòng, hoặc thêm tham số `from` — quyết định về thiết kế URL.
5. **`src/modules/machine` import `@/app/router/navigate`**, ngược chiều "src/app biết mọi
   module" của C-TS-01. Không luật nào bắt, không vòng import. Nếu dự án muốn modules không
   bao giờ import `src/app`, bản sửa đúng là dời router xuống `src/shared/lib` hoặc tiêm qua
   provider — cần một ADR.
6. **Hai văn phạm đường dẫn field.** `FieldErrors` hứa `items.0.quantity` (có chỉ số);
   `encoding/json` cho `items.quantity` (không). Chưa có hậu quả vì chưa DTO nào có
   mảng-của-object với field kiểu chặt — nhưng phải có tên **trước khi** có.
7. **`toFormErrors` shared cố ý không có `isForbidden`**, nên mỗi màn cần hiện `403` khác
   đi phải tự kiểm `status === 403`. Ngày ba màn cùng viết lại ba dòng đó là ngày nâng nó
   lên shared — không phải bây giờ.

### 3.5 Quyết định đã chốt, đừng mở lại mà không có lý do mới

**Không xây đường tạo `companies`** — giữ nguyên từ chặng D, xem `2026-08-13-ban-giao.md` 3.5.

**`R-19` canh bằng ESLint ở `frontend-erp`, không mở rộng `backend-erp/arch`** (ADR-0012).
Thêm `.ts`/`.tsx` vào `rawExts` chỉ là một dòng và fixture machinery tái dùng được — nhưng
`loader.go` cố ý không dùng `go/packages` và Go không có parser TypeScript, nên checker
viết ở đó sẽ là regex. Lõi `R-19` là dataflow: regex không phân biệt nổi `total` render ra
JSX với `total` nhét vào body, mà C-TS-05 dòng 617 nói ranh giới nằm đúng ở đó. Cái giá đã
trả: bảng điểm thành hai file. ADR-0012 ghi ba điều kiện mở lại.

**Frontend gọi backend qua origin cấu hình được (`VITE_API_ORIGIN`), không qua
`server.proxy` của Vite.** Proxy vá được lỗi ngay nhưng biến mọi thứ thành same-origin ở
dev, tức CORS chỉ được thử lần đầu khi lên production — đúng thứ chặng này tồn tại để
tránh. Tên biến là **hợp đồng**, đã ghi vào C-TS-04.

**Không nới định dạng ngày** — xem 3.4 mục 1. Giữ RFC3339 là giữ nguyên hợp đồng `time.Time`
vốn có; nới là một quyết định mới, chưa ai đưa.

**Query param sai kiểu (`page=abc`) vẫn là `400`.** Cố ý ngoài phạm vi chặng E: nó là kiểu
lỗi thứ ba (`*strconv.NumError`) và kéo nó vào là mở rộng một thay đổi hợp đồng đã đủ rộng.

### 3.6 Cơ chế tự hết hạn — cái nào đã nổ, cái nào còn chờ

| Cơ chế | Trạng thái |
|---|---|
| `Scope.Optional` cho `relay` | Đã nổ ở chặng D và xử đúng cách; hiện **không root nào** còn Optional |
| `targetChuaCo` | Map **rỗng** |
| `TestCIWorkflowUnverifiableStaysHonest` | Đã nổ ở chặng A và đã xử |
| **`fixture vi-pham` thiếu → `FAIL`** (mới) | **Đã kiểm bằng phép đột biến** ở cả `fixtures.test.js` lẫn runner. Đây là hàng phòng thủ chính của bảng điểm thứ hai |
| **Ba mệnh đề khai báo của runner frontend** (mới) | `FULL`→`unverifiable` rỗng; `PARTIAL`/`NA`→khác rỗng; luật không fixture = `FAIL`. Cả ba đã kiểm bằng đột biến. **Chưa luật nào đạt `FULL`**, nên mệnh đề đầu chưa có chủ thể thật trong bảng đã commit |
| **`.gitattributes eol=lf`** (mới) | `core.autocrlf=true` trên máy dev, và **cả hai** golden file so sánh từng byte. Đã set cho cả hai repo. Nếu ai gỡ, lần clone sạch tiếp theo `arch` đỏ mà không ai làm gì sai |

Khi một trong chúng đỏ, thông điệp lỗi nói đích danh việc phải làm. **Làm đúng thế, đừng
nới lỏng.**

## 4. Cách làm việc — cái gì tự chứng minh ở chặng này

Bốn điều ở mục 4 của bàn giao chặng D vẫn đúng. Chặng E thêm bốn điều nữa, và cả bốn đến
từ cùng một chỗ: **agent được cho phép nói người giao việc sai.**

**Người điều phối sai bốn lần, và cả bốn lần agent bắt được.** Đếm "chín call site" trong
khi bảng ngay dưới liệt kê mười (agent đếm bằng grep). Lý lẽ CORS sai về kỹ thuật —
`Authorization` do JavaScript tự gán **không** phải "credential" theo chuẩn CORS, nên
`ACAO: *` với nó là hợp lệ; kết luận allowlist vẫn đúng nhưng vì lý do khác. Chữ ký
`toFormErrors` mâu thuẫn C-TS-05. Và đường sửa (A) đề xuất cho E22 — agent **đo** được
rằng chuyển hàm nguyên si vào cùng file vẫn để phép tính vô hình, tức một bản sửa hình
thức, rồi từ chối và chọn đường khác.

Không lần nào agent đoán. Mỗi lần nó dựng probe, chạy, dán output.

**Vùng mù phải đo, không được suy luận.** Ba lỗ của bộ canh đều tìm ra bằng cách viết một
file vi phạm rồi chạy `eslint` — không phải bằng đọc code luật. Hai lần dự đoán từ đọc code
đã **sai**: một agent kết luận màn sửa máy vô hình vì ranh giới file, hóa ra vì tập sink
không biết chuỗi prop callback; người điều phối dự đoán luật mới sẽ làm màn đó đỏ, và nó
đỏ — nhưng vì một lý do khác lý do đã nêu.

**Phép thử ngược quan trọng ngang phép thử thuận.** Với CORS: không chỉ chứng minh nó chạy,
mà tắt `CORS_ALLOWED_ORIGINS` đi và cho thấy trình duyệt chặn thật (`status 0`, backend log
`tu choi preflight`). Với luật `R-19`: không chỉ ca phải đỏ, mà ca **phải không đỏ** —
`<span>{qty * price}</span>` render ra JSX. Một luật đỏ mọi chỗ là một luật sẽ bị tắt trong
tuần đầu, và nó tệ hơn không có luật vì nó cho một dòng PASS.

**Có thứ chỉ lộ ra khi chạy thật.** Ba màn hình `machine` không có đường dẫn nào từ giao
diện — 259 test xanh không bắt được, vì mọi test đều dựng thẳng component cần kiểm nên
không test nào hỏi *"làm sao người dùng tới được đây"*. Và khi vá nó, lộ ra lỗi thứ ba
không ai nêu: `navigate()` chỉ so `pathname`, nên **cái link đầu tiên thêm vào thanh nav
đã hỏng ngay từ lúc thêm**.

## 5. Đề nghị cho phiên tiếp theo

**Việc đầu tiên là commit.** Đọc diff của 62 file rồi commit theo từng nhóm có nghĩa — spec
riêng, hợp đồng lỗi riêng, bộ canh riêng, lát cắt dọc riêng. Commit message của repo này
giải thích **vì sao**, không chỉ **cái gì**. Sau đó đẩy và đợi CI: `backend-erp` ba job,
`frontend-erp` ba job.

**Rồi chọn giữa hai hướng, và chúng khác hẳn nhau về bản chất:**

*Chặng F — vận hành.* Khối lớn cuối cùng chưa động tới. Nó có sẵn một câu hỏi phải trả lời
trước dòng code đầu tiên, cùng dạng với câu hỏi `R-19` của chặng E: **"P-OBS sẽ được canh
bằng gì"** — sáu hard check, chưa checker nào. Nếu câu trả lời là "chưa gì cả" thì chặng đó
lặp lại đúng cái bẫy mà bảy dòng `PASS tren tap RONG` đã dạy, lần thứ ba.

*Hoặc: làm sâu frontend.* Năm dòng `N/A` trong bảng mức là năm mệnh đề C-TS chưa ai canh
— cache key theo dữ liệu hay theo màn hình, `useQuery` chảy vào `useState`, `.data` bóc hai
lần, phân loại validate nào là nghiệp vụ. Chúng khó hơn tám luật đầu và một số có thể
không kiểm được cho tử tế; kết quả trung thực là để chúng ở `N/A` với lý do rõ hơn.

**Khuyến nghị: chặng F.** Frontend hiện đủ để chứng minh hợp đồng và đủ để `R-19` sống;
làm sâu nó là tối ưu một thứ đã đứng vững. Còn `infra-erp` trống nghĩa là hôm nay không ai
triển khai được hệ thống này ngoài máy dev, và `CORS_ALLOWED_ORIGINS` — biến mà thiếu nó
frontend bị chặn hoàn toàn — chưa được set ở bất kỳ đâu ngoài một lệnh gõ tay.
