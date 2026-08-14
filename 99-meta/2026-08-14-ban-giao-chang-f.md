# Bàn giao — sau chặng F

Nối tiếp `2026-08-13-ban-giao-chang-e.md`. Cùng lý do hẹp: sau chặng F có một bảng kiểm kê
việc chưa làm, một tập vùng mù đã đo được, và vài câu hỏi chưa quyết — tất cả chỉ sống
trong một phiên làm việc.

---

## 0. Đọc dòng này trước mọi dòng khác

Chặng F nằm trên nhánh **`chang-f`**, phân nhánh từ `chang-e`. **Chưa đẩy lên GitHub, chưa
merge.**

| Repo | `main` | Nhánh `chang-f` |
|---|---|---|
| `backend-erp` | `9492397` | 9 commit (6 của chặng E + 3 của F) |
| `docs-erp` | `9335b46` | 11 commit (6 của E + 3 của F + **2 của một phiên khác**) |
| `frontend-erp` | `4f13696` | 9 commit (8 của E + 1 của F) |
| `infra-erp` | `d66dcf7` | 4 commit — **lần đầu repo này có nội dung** |

**Một phiên Claude thứ hai đã chạy song song và commit lên cùng nhánh `chang-f` của
`docs-erp`.** Hai commit của nó: `ADR-0016` (Kalmar dùng chung module `machine`),
`ADR-0017` (mười hai module, tên thư mục tiếng Anh), `99-meta/pham-vi-he-thong.md`, và một
mockup điều hướng. Chúng **không thuộc chặng F** — chúng trả lời câu hỏi mà `ADR-0001` để
ngỏ suốt sáu chặng, và khai phạm vi hệ thống. Phiên chặng F cố ý không commit chúng để
không gán sai nguồn gốc; phiên kia tự commit.

Việc đầu tiên của phiên sau: **đẩy bốn nhánh, mở PR, đợi CI** — `backend-erp` ba job,
`frontend-erp` ba job, `infra-erp` **lần đầu có CI**. Chưa lần nào CI của `infra-erp` chạy
trên máy runner thật.

`gh` hiện đăng nhập bằng `tonghanh106`, tài khoản **không có quyền ghi** trên `erp-hanh`
(`docs-erp` chỉ đọc; ba repo kia trả `404`, tức không thấy). Phải `gh auth login` bằng tài
khoản sở hữu trước khi đẩy.

---

## 1. Hệ thống đang ở đâu

Chặng F đã đóng: **`infra-erp` tồn tại, và P-OBS lần đầu bị hỏi.**

| | `backend-erp` | `frontend-erp` |
|---|---|---|
| build / vet | `0` | `0` |
| `dev check` / `arch` | `0` — **26 rule** | `0` — 9 luật + 5 dòng `N/A` |
| test | 33 package `ok` | 278 test |

Dòng duy nhất không `PASS` trong `arch/LEVELS.md` vẫn là `R-19` với `N/A / chua chay`, và
đó **đúng thiết kế** (ADR-0012): nó được canh bằng chín luật ESLint ở `frontend-erp`, và
`Unverifiable` của nó trỏ đích danh sang đó.

**Sáu hard check của P-OBS, sau chặng F:**

| | Canh bằng |
|---|---|
| HC-01 | `TestMoiRouteV1SinhDungMotSpan` ở `cmd/api` — **test lúc chạy**, cố ý không có ID trong bảng `arch/` |
| HC-02 | **CHƯA CANH** — khoảng trống có tên, không phải một quyết định |
| HC-03 | `checkHC03` — danh sách trắng ở `modules/**`, danh sách đen theo tên ở `shared/**` |
| HC-04 | R-16 + R-17 (`loggerToanCuc`, phạm vi vừa nới ra `modules/**`) — không có dòng riêng |
| HC-05 | `checkHC05` — bốn nhánh dấu hiệu |
| HC-06 | **Không canh được**, và lý do không phải "khó" mà là nó sẽ **bắt oan** đúng ca mà "Ca khó 1" của chính P-OBS nói là đúng |

**Cơ chế giữ cho bảng đó không nói dối là thứ đáng đọc nhất của chặng.** Bốn khoảng trống
(HC-01, 02, 04, 06) không được ghi bằng một câu văn — chúng là **dữ liệu**: `var hardChecks
[]HardCheck` trong `arch/rules.go`, mỗi mục có `CoDongRieng bool` và `CanhBoi string` bắt
buộc, và `TestHardCheckKhaiDungBang` ép song ánh hai chiều với danh sách của P-OBS.
`gen_readme.go` in nó ra `arch/README.md`. Lý do chọn dữ liệu thay vì văn xuôi: chính
`rules.go` đã mang một comment lạc hậu từ ngày `checkCGO07` ra đời, và ghi rằng *"không
test nào bắt được một comment nói dối"*.

**Không có việc nào đang dở.**

## 2. Đọc gì để bắt kịp, theo thứ tự

1. `2026-08-13-ban-giao-chang-e.md` — file này giả định bạn đã đọc nó.
2. `99-meta/specs/2026-08-14-chang-f-van-hanh-design.md` — **mục 3** (vì sao HC-1 không có
   ID trong bảng) và **mục 9** (kèm hai đính chính về chính spec đó).
3. `infra-erp/docs/Limits.md` — bốn giới hạn, cả bốn đo được, không cái nào làm nhẹ đi.
4. `backend-erp/arch/README.md` mục "Hard check cua P-OBS" — bảng tự sinh.
5. `ADR-0013` (một instance), `ADR-0014` (dead-letter bảng riêng), `ADR-0015` (thư viện).
6. **Của phiên khác, không thuộc chặng F nhưng đọc trước khi lên kế hoạch:** `ADR-0016`,
   `ADR-0017`, `99-meta/pham-vi-he-thong.md`.

Chạy `go run ./cmd/dev check` rồi `test`, và `npm run lint && npm run arch && npm test`
trước khi tin bất cứ điều gì ở trên.

## 3. Việc chưa làm

### 3.1 `cmd/relay` hoàn toàn không được quan trắc — nợ lớn nhất, và spec từng nói dối về nó

Bản đầu của spec chặng F hứa rằng tắt `relay` sẽ **quan sát được trên `/metrics`**, và gọi
đó là *"thứ chặng này mua được mà không chặng nào trước có"*. F13 dựng thật rồi tắt nó, và
đo được điều ngược lại:

```
relay co metric nao?          -> 0
relay co cong nao?            -> (rong)
Prometheus scrape may target? -> dung MOT: api
metric nao cham outbox?       -> 0
/ready khi relay da tat       -> 200
GET /api/v1/machines          -> 200
```

Sự kiện nằm lại `published_at IS NULL`, và **không ai kêu**. Thiếu `relay` hôm nay vẫn im
lặng hoàn toàn, y hệt trước chặng F. Chặng này mua quan trắc cho `cmd/api`, **không** cho
`cmd/relay`.

Đường sửa rẻ nhất **không phải** mở cổng cho `relay` mà là một **gauge tồn đọng** trên
`/metrics` của `api`: `api` đã nói chuyện với đúng database đó, và "có bao nhiêu hàng
`published_at IS NULL` cũ hơn N giây" là thuộc tính của **dữ liệu** chứ không của tiến
trình. Nó bắt được cả ca `relay` chết lẫn ca `relay` sống nhưng kẹt.

**Cố ý hoãn sang chặng G, làm cùng lúc với dead-letter và job dọn** — cả ba động vào cùng
bảng `outbox` và cùng câu hỏi *"hàng nào đang ở trạng thái nào"*. Viết gauge trước khi
dead-letter thêm trạng thái thứ ba là viết một thứ phải sửa lại. Ghi ở
`infra-erp/docs/Limits.md` mục 1.

### 3.2 Frontend không có màn tạo máy — giao diện là ngõ cụt trên database trắng

Bảng route có đúng bốn dòng; `api/machine-api.ts` xuất `listMachines`, `getMachine`,
`updateMachine`, **không có** `createMachine`. Backend có `POST /api/v1/machines` từ chặng C.

Cài mới hệ thống, đăng nhập xong, **người dùng không có cách nào thêm cái máy đầu tiên qua
giao diện**. Cùng bài toán con-gà-quả-trứng mà `bootstrap-user` giải cho user, nhưng cho
máy thì chưa ai giải.

Đây **không phải một màn hỏng**: chặng E dựng đúng ba màn spec của nó chốt, và định nghĩa
hoàn thành của chặng đó không hỏi tới màn tạo. 278 test không bắt được, vì mọi test đều
dựng thẳng component cần kiểm nên không test nào hỏi *"làm sao người dùng tới được đây"*.
Ghi ở `frontend-erp/docs/Routing.md` mục 6.

### 3.3 Nợ backend đã ghi thành văn bản

| Việc | Ghi ở | Đổi gì sau chặng F |
|---|---|---|
| Rate limit `/auth/login` | spec chặng B | **Tiền đề đã chốt**: ADR-0013 khai một instance, nên in-process là đúng và không cần Redis. Chỉ còn code |
| Dead-letter + giới hạn số lần thử | ADR-0006 → **ADR-0014** | **Hình dạng đã chốt**: bảng riêng, không thêm cột vào `outbox`. Chưa hiện thực hóa |
| Job dọn `outbox` | ADR-0006 | Phải **sau** dead-letter. Hạn giữ liệu vẫn chưa ai chốt con số |
| Quên mật khẩu / đặt lại | spec chặng B | — |
| `currencies`, `units`, `provinces` — không migration | C-DB-04 | — |
| `document_counters` — chưa phân nhóm bảng | ADR-0003 | — |
| Import CSV/Excel — chưa có quy ước định dạng | ADR-0004 | — |
| `allowed_actions` không tồn tại ở response nào | C-TS-06 | Vẫn hoãn có đường ra: nút cứ hiện, xử `403` tử tế |
| `Idempotency-Key` — frontend gửi, backend chưa thi hành | C-TS-05 | — |
| Kalmar tách module hay không | ADR-0001 | **Đã trả lời** bởi ADR-0016 của phiên khác |
| `/metrics` — R-13 khai ba, mới có hai | `cmd/api/router.go` | **Đã trả** |

### 3.4 Vùng mù đã đo được

**HC-02 chưa canh.** Nửa đọc được tĩnh — cấm `http.Client{}` và `redis.NewClient(` trong
`modules/**` — chưa ai viết. Nửa còn lại (*"wrapper có ghi cả latency histogram lẫn error
counter"*) là câu hỏi về **thân hàm** chứ không về hình dạng lời gọi, và nó ở `Unverifiable`.

**HC-06 sẽ bắt oan nếu viết.** "Ca khó 1" của P-OBS nói `internal_error` **phải** vào
`logger.Error`, mà nó cũng đi qua bảng mã và cũng khớp `errors.As`. Checker tĩnh không phân
biệt được `Code == CodeInternal` với mã khác. Khi bắt oan là **cố hữu** chứ không phải lỗi
hiện thực, câu trả lời trung thực là không viết.

**HC-03 mù cardinality thật.** `WithLabelValues(routePattern)` toàn chuỗi hằng nhìn thì
sạch, nhưng nếu `routePattern` được ghép từ path thật thì nổ y hệt. Thứ canh chỗ đó là
`TestNhanRouteLaRoutePatternChuKhongPhaiPathThat`, không phải checker.

**HC-05 bắt *sinh*, không bắt *ghi đè*.** Một middleware thứ hai đọc `X-Request-Id` rồi đặt
lại giá trị khác không gọi `uuid` lần nào. Và `TraceID` của OTel là họ id thứ ba mà rule
không nhắc tới.

**`TestMoiRouteV1SinhDungMotSpan` không phủ dây nối ở `main.go`.** Nó tiêm provider của
chính nó, nên xóa `voiNhaCungCapSpan(...)` khỏi `main.go` thì test **vẫn xanh**. Ranh giới
thật là *"router có nối middleware không"*, không phải *"tiến trình có nối exporter không"*.
Đóng vế đó cần một test chạy `run()` với collector giả — tức phụ thuộc cổng mạng, đúng loại
chập chờn chặng D đã trả giá. **Cố ý không mở đường đó.**

**Một `return` sớm chỉ bị bắt khi điều kiện của nó đúng với một request bình thường.** Đo
được: nhánh gác bằng một header lạ thì test **vẫn xanh**.

**CI của `infra-erp` chỉ kiểm cú pháp, không kiểm build.** `docker compose config -q` không
build. Đã có tiền lệ thật: `compose/dev.yml` từng khai `build.context` sai và `config -q`
vẫn xanh — chỉ dựng thật mới thấy.

**Không có series `OPTIONS` nào trên `/metrics`.** Preflight bị chặn trước middleware đo,
nên độ trễ và lỗi preflight vô hình.

### 3.5 Quyết định đã chốt, đừng mở lại mà không có lý do mới

**Không xây đường tạo `companies`** (từ chặng D). **`R-19` canh bằng ESLint ở
`frontend-erp`** (ADR-0012). **`VITE_API_ORIGIN` chứ không `server.proxy`** (chặng E).

Chặng F thêm bốn:

**HC-01 không có ID trong bảng `arch/`.** Động từ của mệnh đề là *"chạy qua"* — một sự kiện
lúc thực thi. Một checker tĩnh cho nó *trông* như hoạt động: file có thật, cột FILE khác 0,
`PASS` — trong khi hệ thống sinh 0 span. Tệ hơn bẫy chặng A một bậc: **tập không rỗng,
checker chạy thật, kết luận vẫn giả**.

**`cmd/api` chạy một instance** (ADR-0013). Điều kiện mở lại là một **sự kiện** — có
instance thứ hai — không phải một ngưỡng CPU.

**Dead-letter là bảng riêng** (ADR-0014). Thêm cột vào `outbox` phá nguyên tắc append-only
mà migration `000009` đã ghi thành văn.

**Không có collector OTLP trong `dev.yml`.** `OTEL_EXPORTER_OTLP_*` để trống nghĩa là span
**vẫn được tạo** nhưng không đi đâu — cấu hình được là *nơi span đi tới*, không phải *việc
span có tồn tại*. Một sampler đặt tỷ lệ 0 chính là hình dạng công tắc tắt âm thầm.

### 3.6 Cơ chế tự hết hạn

| Cơ chế | Trạng thái |
|---|---|
| `Scope.Optional`, `targetChuaCo`, `TestCIWorkflowUnverifiableStaysHonest` | Như chặng trước |
| `fixture vi-pham` thiếu → `FAIL` (cả hai repo) | Đã kiểm bằng đột biến |
| **`TestHardCheckKhaiDungBang`** (mới) | Song ánh với danh sách hard check của P-OBS, **và** đối chiếu `CoDongRieng` với `allChecks()` hai chiều. Lật một giá trị → đỏ |
| **`TestMenhDeNguonKhongDoiAmTham`** (đã nổ ở chặng F) | R-11 đổi mệnh đề → nó gọi đích danh rule, đưa **hai** lựa chọn, và nói *"im lặng đi tiếp không phải một lựa chọn"*. Đã ghim lại sau khi chứng minh checker không phải sửa |
| **`.gitattributes eol=lf`** | Cả hai golden file, cả hai repo |

**Một cạm bẫy fixture mới biết:** cơ chế fixture là **theo rule, không theo nhánh**. Xóa
một trong bốn ca vi phạm của `HC-05` vẫn `PASS`. Phép thử đúng là vô hiệu **từng nhánh
một**.

## 4. Cách làm việc — cái gì tự chứng minh ở chặng này

Bốn điều ở bàn giao chặng D và bốn điều ở chặng E vẫn đúng. Chặng F thêm ba, và cả ba đắt.

**Có một lớp lỗi mà chỉ dựng thật mới thấy, và nó không nhỏ.** Ba cái ở chặng này:
`compose/dev.yml` khai `build.context` sai trong khi `docker compose config -q` vẫn xanh —
lệnh đó không build. `cmd/relay` im lặng hoàn toàn khi chết — 33 package test và một CI ba
job không nói gì. Frontend không có màn tạo máy — 278 test không hỏi *"làm sao người dùng
tới được đây"*. **Không cái nào tìm được bằng đọc code hay chạy test.**

**Người điều phối sai năm lần ở chặng này, và cả năm lần agent bắt được.** `Targets:
["modules"]` cho HC-03 (agent đo: 0 cấu trúc để kết luận, và 9/9 bắt oan nếu làm theo chữ
spec). Nghiệm thu tự mâu thuẫn cho F4 (`c.FullPath()` **là** một lời gọi hàm, nên không
hiện thực nào thỏa được cả hai điều kiện). Đường sửa (A) cho E22 (agent **đo** được nó cho
ra bản sửa hình thức). Hàng nghiệm thu của HC-05 (làm theo chữ sẽ làm đỏ code đúng — P-OBS
cấm *đổi tên*, nên dùng đúng tên chuẩn là *tuân thủ*). Và con số "bốn lời gọi
`uuid.NewString()`" — thật ra bảy.

Không lần nào agent đoán. Mỗi lần nó dựng probe, chạy, dán output.

**Chia vùng file sai là lỗi của người điều phối, và nó có giá.** Hai lần: `go.mod` bị hai
agent tranh chấp và **bị hoàn về HEAD giữa chừng**, mất phụ thuộc của cả hai — một kiểu
hỏng không test nào bắt. Rồi `compose/dev.yml` bị giao cho F12 làm đột biến trong khi F11
sở hữu nó. Lần thứ hai agent xử đúng: nó dừng sửa file thật, chuyển sang bản sao, và **ghi
rõ vì sao lệch khỏi kịch bản** thay vì làm cho nhanh. **Ràng buộc cứng đứng trên yêu cầu
nghiệm thu.**

**Từ chối viết một checker cũng là một kết quả.** HC-06 không được viết vì nó sẽ bắt oan cố
hữu. `relay` không có healthcheck vì mọi cách kiểm đều **báo xanh đúng lúc hỏng nặng nhất**
— chính comment trong `cmd/relay/main.go` mô tả một ca deadlock giữ goroutine treo trong
khi process vẫn sống. Một healthcheck luôn xanh còn tệ hơn không có, vì nó nói dối
orchestrator.

## 5. Đề nghị cho phiên tiếp theo

**Việc đầu tiên là đẩy và mở PR.** Bốn nhánh `chang-f`, chồng trên `chang-e`. Đây là lần
đầu CI của `infra-erp` chạy trên runner thật, và là lần đầu `.gitattributes eol=lf` được
thử trên Linux — hai thứ chưa ai biết có xanh hay không.

**Rồi chặng G, và nó có hình dạng rõ hơn năm chặng trước.** Ba món cùng động vào bảng
`outbox` và cùng câu hỏi *"hàng nào đang ở trạng thái nào"*, nên chúng phải đi cùng nhau:

1. **Dead-letter** — hình dạng đã chốt ở ADR-0014, chỉ còn migration và code.
2. **Gauge tồn đọng `outbox`** — mục 3.1, thứ làm `relay` thôi im lặng.
3. **Job dọn** — phải sau (1) để biết có bao nhiêu trạng thái. **Hạn giữ liệu vẫn chưa ai
   chốt**, và cố ý không chốt bằng phỏng đoán — nó cần số liệu thật, mà số liệu thật là thứ
   chặng F vừa bắt đầu thu thập được.

Cộng **rate limit** (tiền đề đã chốt ở ADR-0013, chỉ còn code) và **HC-02 nửa tĩnh** (cấm
client gốc trong `modules/**` — khuôn `checkTestInfraImport` có sẵn).

**Nhưng đọc `99-meta/pham-vi-he-thong.md` của phiên khác trước khi chốt chặng G.** Nó khai
mười hai module và trả lời câu *"còn bao nhiêu chặng nữa"* mà sáu chặng đầu không ai viết
ra. Nếu bản đồ đó đúng, thứ tự ưu tiên của chặng G có thể khác hẳn — một hệ thống còn mười
module chưa dựng thì việc hoàn thiện đường event cho hai module hiện có không chắc là việc
đáng làm trước.

**Câu hỏi phải trả lời trước dòng code đầu tiên của chặng G**, cùng dạng với câu hỏi `R-19`
của chặng E và `P-OBS` của chặng F: *"dead-letter sẽ được canh bằng gì"*. Nếu câu trả lời
là "chưa gì cả" thì đó là lần thứ ba dự án bước vào cùng một cái bẫy — và lần này thì không
còn cớ nào cả.
