# Chặng F — vận hành, và P-OBS lần đầu bị hỏi

**Trạng thái:** Đã duyệt · 2026-08-14
**Tiền đề:** Chặng E đóng trên nhánh `chang-e` ở ba repo. `R-19` có người canh bằng chín luật ESLint; dự án có hai bảng điểm. `infra-erp` vẫn trống.

---

## 1. Mục tiêu, đo được

Chặng E hỏi *"`R-19` sẽ được canh bằng gì"* và mất cả chặng để trả lời. Chặng F hỏi cùng câu đó cho **P-OBS** — nguyên tắc có **sáu hard check và chưa checker nào**.

Nhưng câu trả lời lần này khác, và khác ở một chỗ quan trọng: **không phải sáu cái đều canh được bằng cùng một loại công cụ.** Khảo sát đo được:

| Hard check | Canh bằng | Vì sao |
|---|---|---|
| **HC-1** — mọi handler `/api/v1` chạy qua middleware tracing | **Test lúc chạy** ở `cmd/api` | Động từ là *"chạy qua"* — sự kiện lúc thực thi, không phải hình dạng trong văn bản |
| **HC-2a** — cấm client gốc (`http.Client{}`, `redis.NewClient`) trong `modules/**` | Checker tĩnh | Hình dạng văn bản thuần túy |
| **HC-2b** — wrapper có ghi latency **và** error counter | `Unverifiable` | Đọc thấy lời gọi đi qua `shared/httpx` không nói gì về việc `httpx` quan sát cái gì |
| **HC-3** — label metric chỉ từ hằng tĩnh | Checker tĩnh | Đối số của `WithLabelValues(` đọc được bằng AST |
| **HC-4** — logger dẫn xuất từ `ctx` | Checker tĩnh — **đã có, chỉ cần nới** | `loggerToanCuc` đã chạy nhưng bị chặn ở `layer == "handler"` |
| **HC-5** — đúng một chỗ sinh `request_id` | Checker tĩnh | Và là cái **duy nhất** có sẵn dữ liệu thật để chứng minh nó phân biệt được |
| **HC-6** — lỗi nghiệp vụ cấm vào `logger.Error(` | `Unverifiable` | Xem mục 4.4 — nó sẽ **bắt oan** đúng ca mà P-OBS nói là đúng |

**Phép thử của mục tiêu này không phải là "sáu dòng PASS".** Nó là ba phép đột biến, mỗi cái đánh vào một loại công cụ khác nhau:

1. Gỡ middleware tracing khỏi `cmd/api/router.go` → **test runtime đỏ**, và nó đỏ vì đếm được **0 span** chứ không vì thiếu một chuỗi.
2. Viết `WithLabelValues(machine.CompanyID)` ở một handler → **checker tĩnh đỏ**, đúng dòng.
3. Sinh một `request_id` thứ hai ngoài `shared/requestid` → **checker tĩnh đỏ** — trong khi bảy lời gọi `uuid.NewString()` đang có trong repo (không cái nào là request_id) **vẫn xanh**.

Và một phép thử thứ tư, thuộc loại khác hẳn: **`docker compose -f compose/dev.yml up` dựng được cả hệ thống, và frontend ở cổng khác gọi được backend trong trình duyệt thật.** Hôm nay không ai triển khai được hệ thống này ngoài máy dev với ba terminal mở tay.

---

## 2. Phạm vi

**Làm:**

| Thành phần | Lý do bắt buộc |
|---|---|
| `infra-erp/{compose,config,scripts,observability}/` | Bốn thư mục repo tự khai, **không cái nào tồn tại** |
| `Dockerfile` cho `cmd/api` và `cmd/relay` | Không có Dockerfile nào ở bất kỳ repo nào |
| `backend-erp` — `/metrics` + registry Prometheus | R-13 khai ba endpoint hạ tầng, mới có hai |
| `backend-erp` — middleware tracing + wrapper DB | HC-1 và HC-2 không có gì để canh nếu không có gì tồn tại |
| `arch/` — ba checker (HC-3, HC-4, HC-5) | Ba mệnh đề tĩnh thật |
| `cmd/api` — test runtime cho HC-1 | Xem mục 3 |
| `docs-erp` — ADR-0013, ADR-0014, ADR-0015 | Ba quyết định chặng này chốt |

**KHÔNG làm, và lý do:**

**Rate limit `/auth/login`** — sang chặng G. Chặng này chốt *tiền đề* của nó (ADR-0013: một instance) nhưng không xây. Lý do: rate limit đúng chuẩn P-OBS cần một counter `429`, mà registry metric là thứ chặng này mới dựng. Xây rate limit trước registry là xây một thứ không quan sát được, rồi quay lại vá.

**Job dọn `outbox`** — sang chặng G, và **phải sau dead-letter**. Khảo sát chỉ ra lý do cụ thể: job dọn cần một quy tắc "hàng nào an toàn để xóa cứng". Hôm nay quy tắc đó có một nhánh (`published_at IS NOT NULL` và đủ cũ). Ngày dead-letter tồn tại, có thêm một trạng thái thứ ba mà job dọn viết trước sẽ không biết — dẫn tới hoặc xóa nhầm hàng đang chờ xử lý, hoặc để hàng dead-letter kẹt vĩnh viễn.

**Dead-letter** — sang chặng G, nhưng **hình dạng đã chốt ở ADR-0014**: bảng riêng, không thêm cột vào `outbox`. Chốt bây giờ để chặng G không phải mở lại, và để job dọn biết trước có bao nhiêu trạng thái.

**Hạn giữ `outbox`** — chưa chốt, và **cố ý không chốt bằng phỏng đoán**. ADR-0006 nói *"việc còn lại chỉ là chốt hạn giữ"*; không con số nào tồn tại ở đâu. Một con số rút từ không khí sẽ sống mãi trong migration. Nó cần số liệu thật — mà số liệu thật là thứ chặng này bắt đầu thu thập được, vì đây là chặng có metric.

**TLS/HTTPS** — `http.Server` trần, không `ListenAndServeTLS`. Chặng này dựng compose cho **dev và staging**; TLS thuộc lớp trước nó (reverse proxy / ingress) và thuộc quyết định hạ tầng thật chưa có.

**Backup/recovery** — không có `pg_dump` nào ở đâu. Nó là một chặng riêng: backup không có phép thử phục hồi là backup chưa tồn tại, và phép thử phục hồi cần một môi trường để phục hồi *vào*.

---

## 3. Vì sao HC-1 không có ID trong bảng `arch/`

Đây là quyết định phương pháp quan trọng nhất của chặng, và nó đắt hơn vẻ ngoài.

Mệnh đề HC-1 là: *"Mọi handler dưới `/api/v1` chạy qua middleware tracing tạo span."* Động từ là **"chạy qua"** — một sự kiện lúc thực thi.

Viết checker tĩnh cho nó **rất dễ và rất hấp dẫn**: tìm biến gán từ `.Group("/api/v1")`, đòi có `.Use(` mang `tracing.Middleware()`. Mười lăm dòng. Checker chạy trên một file có thật, cột FILE khác 0, bảng in `PASS`.

Và tất cả những cái đó vẫn đúng nguyên trong khi hệ thống **không sinh một span nào**:

- Gin nối chain lúc **đăng ký**. Một route khai *trước* lời gọi `.Use()` không nhận middleware — mà thứ tự đăng ký nằm rải qua `dangKyModule` sang từng `moduleX.Register`, tức qua nhiều file.
- Middleware `return` sớm trên một nhánh.
- `span.Start` nằm trong `if cfg.TracingEnabled`, và biến đó `false` ở production.
- Exporter không được cấu hình, nên span sinh ra rồi rơi vào hư không.

**Đây tệ hơn bẫy chặng A một bậc.** Chặng A là *checker chạy trên tập rỗng thì xanh y hệt checker đang canh thật*. HC-1 là **tập không rỗng, checker chạy thật, kết luận vẫn giả**. Không cơ chế nào trong `arch/` bắt được loại này: cột FILE, `targetChuaCo`, `Scope.Optional`, fixture hai chiều — tất cả đều hỏi *"checker có gặp code không"*, không hỏi *"điều checker kết luận có đúng không"*.

Tiền lệ đã có sẵn trong repo, và nó nói thẳng ra điều này. `arch/checks_route.go` dòng 141-142:

```go
// Cai gia: route dang ky tren mot bien khong truy duoc VA that su nam ngoai
// /api/v1 thi lot. Bu lai bang TestRouterKhongCoRouteNgoaiV1 o cmd/api - no doc
// r.Routes() luc CHAY nen no thay duong dan DAY DU sau khi group da noi tien to.
```

R-13 đã gặp **đúng bài toán này** — "route có thật sự nằm dưới group đó không" — và lời giải không phải làm checker tĩnh thông minh hơn, mà là một test dựng router thật rồi đọc `r.Routes()`.

HC-1 đi đường đó:

```
TestMoiRouteV1SinhDungMotSpan  (cmd/api)
  dung router that + span exporter trong bo nho
  lap qua r.Routes(), loc cac route duoi /api/v1
  moi route: ban mot request, khang dinh
    - dung MOT span duoc sinh
    - span.Name == route.Method + " " + route.Path
      ("{method} {route pattern}", khong phai path da dien id)
```

Test đó đóng được **cả hai vế** — "mọi handler" và "tên span là `{method} {route pattern}`" — mà không checker tĩnh nào chạm tới.

> **Đính chính, ghi lại vì nó là lỗi của người viết spec này.** Bản đầu của mục này chốt
> `span.Name == route.Path` — tên span **trần**, không method. F6 hiện thực hóa đúng thế
> và F7 kiểm đúng thế; cả hai làm đúng theo spec, và **spec sai**.
>
> Dữ kiện làm lật quyết định: **quy ước ngữ nghĩa HTTP của OpenTelemetry nói tên span
> phía server NÊN là `{method} {target}`** với target là route pattern — và chính ví dụ
> trong `P-OBS` hard check 1 (`GET /api/v1/orders/:id`) đã viết theo quy ước đó từ trước.
> Tức tài liệu nguyên tắc và hệ sinh thái nói cùng một đằng; chỉ mỗi spec này nói khác.
> Tên span là trường hiển thị của mọi backend tracing, nên đặt lệch quy ước nghĩa là span
> của repo này nằm lệch hẳn span do các thư viện có instrument sẵn sinh ra.
>
> Cái giá nhỏ vì F6 đã đặt method làm thuộc tính (`http.request.method`): không mất thông
> tin, chỉ đổi trường hiển thị. `http.route` **giữ nguyên route pattern trần** — nó là
> trường để truy vấn lọc theo, không phải trường để đọc. Sửa ở F17.

**Cái giá, nói thẳng:** HC-1 không có dòng nào trong `arch/LEVELS.md`. Ai đọc bảng đó sẽ không thấy nó. Đổi lại, ta không ghi vào bảng một dòng `PASS` cho một mệnh đề mà bảng đó **không có tư cách kết luận**. Chặng E vừa cho thấy giá của việc ngược lại: `R-19` khai `N/A` bốn chặng liền và không ai hỏi nó canh bằng gì.

Bù lại bằng hai thứ: `P-OBS-observability.md` ghi đích danh tên test đó ở mục hard check 1, và `arch/README.md` có một dòng ghi chú rằng HC-1 cố ý sống ngoài bảng, kèm lý do.

---

## 4. Bốn hard check tĩnh, và cái giá của từng cái

### 4.1 HC-5 — cái duy nhất có dữ liệu thật ngay hôm nay

Mệnh đề: không nơi nào ngoài middleware R-17 được sinh `request_id`.

Đây là hard check **duy nhất** vừa canh được bằng bộ máy hiện có, vừa có sẵn mẫu thật để chứng minh nó **phân biệt được** chứ không chỉ chạy trên tập rỗng. Repo hiện có bảy lời gọi `uuid.NewString()` trong code sản xuất — bốn ở `modules/auth` (`auth_service.go:572`, `user_service.go:201` và `:449`, `token/token.go:127`) và ba ở `modules/machine` (`breakdown_service.go:262`, `machine_service.go:264`, `maintenance_service.go:392`) — và **không cái nào là `request_id`**. Checker phải để cả bảy xanh. Bản đầu của spec này viết "bốn" và bỏ sót ba cái chặng C thêm vào; agent F9 đếm bằng grep và bắt được. Đây là lần thứ tư một con số trong văn xuôi của spec sai và một agent sửa nó bằng cách đếm.

Ba dấu hiệu, độc lập nhau:

- **(a)** `uuid.NewString`/`uuid.New` mà **tên vế trái của phép gán bao ngoài** khớp `(?i)^(request|trace|correlation|span)_?id$`. Dùng LHS của `AssignStmt` chứ không dùng "cùng dòng" như script grep của P-OBS — chặt hơn hẳn.
- **(b)** Chuỗi literal `"request_id"`, `"trace_id"`, `"X-Request-Id"` ngoài `shared/{requestid,log,response}`. Đây mới là dấu hiệu bắt được **định nghĩa lại**, không phụ thuộc thư viện sinh id.
- **(c)** `context.WithValue(` ngoài `shared/requestid` với kiểu key có tên chứa `request`/`trace`.

**Một việc phải làm trước:** script grep trong chính P-OBS **hôm nay không sạch**. Chạy thật, nó trả ba dòng ở `shared/audit/postgres_db_test.go:45,107,139` — `RequestID: uuid.NewString()`, dữ liệu giả cho test audit. Script không loại `_test.go`. Checker mới phải chạy trên `ProductionScope` (vốn đã loại test), và P-OBS phải sửa script của nó cho khớp — nếu không tài liệu tự mâu thuẫn với checker.

**Đường mù, ghi vào `Unverifiable`:** sinh id bằng thứ khác `uuid` (`xid`, `ksuid`, `time.Now().UnixNano()`); một helper `shared/id.New()` gọi khắp nơi thì lời gọi không còn tên `uuid.NewString`; và dấu hiệu bắt **sinh**, không bắt **ghi đè** — một middleware thứ hai đọc `X-Request-Id` rồi đặt lại giá trị khác không gọi `uuid` lần nào.

### 4.2 HC-4 — đã đang canh, chỉ bị chặn phạm vi

`loggerToanCuc` ở `arch/checks_migration.go:769` đã hiện thực hóa đúng mệnh đề: bắt `sel.Sel.Name ∈ logMethods` với `tenNhan(sel.X) ∈ {logger, log, slog, lg, l}`. `log.FromContext(ctx).Info(...)` không bị bắt vì người nhận là `*ast.CallExpr` chứ không phải `Ident`.

Nhưng nó chỉ chạy khi `layer == "handler"` (`checkR17` dòng 716). P-OBS nói `modules/**` — tức **service và repository đang không được canh**. Sửa là nới một dòng.

Nửa "tham số log chỉ là cặp key-value nguyên thủy" đã có ở `checkR16`, và đường mù của nó đã ghi sẵn trong `Unverifiable` của R-16 — chép nguyên sang, đừng viết lại: một biến struct **giá trị** truyền thẳng không phân biệt được với chuỗi khi không có type info. Và chữ "nguyên thủy" về cơ bản không canh được: `logger.Info("user", "password", pwd)` thỏa mọi kiểm tra hình dạng.

### 4.3 HC-3 — checker phải sinh sau code, không trước

Mệnh đề: label metric chỉ lấy từ danh sách hằng khai báo tĩnh.

Dấu hiệu: `*ast.CallExpr` có `Sel.Name == "WithLabelValues"`; mỗi đối số hợp lệ khi là `*ast.BasicLit` STRING hoặc `Ident`/`SelectorExpr` trỏ tới một `const` cấp package. Mọi thứ khác — `*ast.CallExpr`, field selector `x.CompanyID`, biến tham số — là vi phạm.

Hai dấu hiệu mà script của P-OBS bỏ sót và phải có:
- **`prometheus.Labels{...}` map form** — API khác hẳn, grep của tài liệu mù hoàn toàn.
- **Chỗ khai báo**: `NewCounterVec(..., []string{"company_id"})`. Bắt tên label ngay tại nơi khai rẻ hơn và chắc hơn bắt tại chỗ gọi.

**Bộ máy cần học một khả năng mới, và nó khiêm tốn: sổ đăng ký `const` cấp package.** Mọi trợ giúp hiện có đều theo từng file (`tenPackage`, `tenBienConTro`, `packageNamesFor`). Để trả lời "đối số này có phải hằng khai tĩnh không", checker cần gom `*ast.GenDecl` kind `const` của cả package. Đó là một package mới cạnh `internal/imports`, cỡ `graph.go` — không cần type info, không đụng `go/packages`, nên fixture vẫn chạy được.

**Và đây là chỗ chặng này suýt lặp lại `R-19`.** Repo hôm nay có **0** dòng Prometheus, **0** `WithLabelValues`. Một checker HC-3 viết trước code metric sẽ **sinh ra đã xanh**, với `Targets: ["modules"]` cho cột FILE = 40 — trông y hệt R-16 đã quét 76 file và không thấy vi phạm. Chính `LEVELS.md` thú nhận cột đó *"trả lời câu hỏi rule có chạm tới code thật không, KHÔNG trả lời rule đã gặp đúng thứ nó canh chưa"*.

Hệ quả cứng cho plan: **checker HC-3 phải viết SAU khi metric thật tồn tại**, và định nghĩa hoàn thành của nó là một phép đột biến trên code sản phẩm thật, không phải trên fixture.

Đường mù: `const` khai ở package khác; và cardinality **thật** vẫn ngoài tầm — `WithLabelValues(routePattern)` toàn chuỗi hằng nhìn thì sạch, nhưng nếu `routePattern` được ghép từ path thật thì nổ y hệt.

### 4.4 HC-6 — không canh, và lý do là nó sẽ bắt oan

Mệnh đề: lỗi nghiệp vụ cấm đi vào `logger.Error(`.

Hình dạng hẹp bắt được: trong một `if errors.As(err, &appErr)`, thân `if` có lời gọi khớp `laLoiGoiLog` với `.Error`.

**Nhưng chính P-OBS "Ca khó 1" nói `internal_error` PHẢI nằm ở cả counter lẫn `logger.Error`** — mà nó cũng đi qua bảng mã, cũng khớp `errors.As`. Checker không phân biệt được `appErr.Code == CodeInternal` với mã khác lúc tĩnh, nên **nó sẽ bắt oan đúng ca mà tài liệu bảo là đúng.**

Đường mù thứ hai là hình dạng hay gặp nhất: service trả `error` (interface), handler viết `logger.Error("...", "err", err.Error())` không có `errors.As` nào trong tầm nhìn.

Đây là một checker mà bắt oan **chắc chắn** xảy ra và bắt sót cũng chắc chắn xảy ra. Quy tắc của dự án là *"checker bắt oan thì sửa checker, không lách code"* — nhưng khi bắt oan là **cố hữu** chứ không phải lỗi hiện thực, câu trả lời trung thực là không viết nó. HC-6 vào `Unverifiable` của R-16 với tên gọi cụ thể.

---

## 5. Hạ tầng — `infra-erp` lần đầu có nội dung

```text
infra-erp/
├── compose/
│   ├── dev.yml              postgres + api + relay + prometheus + grafana
│   └── staging.yml          nhu dev, khong seed, khong expose postgres ra ngoai
├── config/
│   ├── api.env.example      DATABASE_URL, JWT_SECRET, PORT, LOG_LEVEL,
│   │                        CORS_ALLOWED_ORIGINS, hai bien OTEL_EXPORTER_OTLP_*
│   ├── relay.env.example    DATABASE_URL, LOG_LEVEL
│   └── frontend.env.example VITE_API_ORIGIN
├── observability/
│   ├── prometheus.yml       scrape /metrics cua api
│   └── grafana/             dashboard toi thieu
└── scripts/
    ├── up.ps1 / up.sh       compose up + migrate-up + doi healthcheck
    └── bootstrap.ps1/.sh    tao user dau tien
```

**Bề mặt biến môi trường thật, đo từ code chứ không từ tài liệu:**

| Biến | Tiến trình | Mặc định | Thiếu thì sao |
|---|---|---|---|
| `DATABASE_URL` | `api`, `relay`, `dev` | không | Từ chối khởi động, exit 1 |
| `JWT_SECRET` | `api` | không, phải ≥ 32 byte | Từ chối khởi động |
| `PORT` | `api` | `8080` | Sai định dạng → exit 1, **không** lặng lẽ rơi về mặc định |
| `LOG_LEVEL` | `api`, `relay` | `info` | Sai giá trị → exit 1 |
| `CORS_ALLOWED_ORIGINS` | `api` | rỗng = **đóng hoàn toàn** | Không trình duyệt nào gọi được API |
| `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT` | `api` | rỗng | **Hợp lệ.** Span vẫn được tạo, chỉ không đi đâu. Đã set nhưng sai (thiếu scheme, `grpc://`) → exit 1 |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | `api` | rỗng | Như trên, và biến riêng cho trace **thắng** biến chung khi cả hai cùng set (thứ tự của đặc tả OTLP) |
| `VITE_API_ORIGIN` | frontend | `http://localhost:8080` | Sai origin ở production |

**Hai biến OTLP không phải công tắc bật/tắt tracing** — chúng cấu hình *nơi span đi tới*,
không cấu hình việc span có tồn tại hay không. Thiếu cả hai thì `api` vẫn tạo đúng một
span cho mỗi request dưới `/api/v1`, span vẫn ghi, vẫn có `TraceID` hợp lệ. Ranh giới này
là chủ ý và nó được viết ra ở ba chỗ (`shared/middleware/tracing`, `cmd/api/config.go`,
`config/api.env.example`) vì đó chính là cách hỏng thứ tư ở mục 3 — *"exporter không được
cấu hình nên span rơi vào hư không"* — bị đóng: không phải bằng cách bắt span phụ thuộc
exporter, mà bằng cách tách hẳn hai câu hỏi ra.

Hai biến đó **thiếu trong bản đầu của bảng này và thiếu trong `config/api.env.example`** —
F1 viết file đó *trước khi* F6 tồn tại. Bổ sung ở F17.

`cmd/relay` cố ý **không** đọc `JWT_SECRET` và **không** đọc `PORT` — comment trong code giải thích: đọc bí mật vào một tiến trình không cần nó là mở rộng phạm vi rò rỉ. Compose phải tôn trọng điều đó, không dùng chung một khối `env_file` cho cả hai.

**Ba điều compose phải giữ, và mỗi điều có lý do đọc được từ code:**

1. **Migration không tự chạy lúc khởi động.** `cmd/api/main.go` không gọi hàm migrate nào — nó `db.Open` rồi phục vụ HTTP ngay. Compose không được lén thêm bước đó; script `up` gọi `cmd/dev migrate-up` **tường minh**, sau khi Postgres healthy.
2. **Thiếu `cmd/relay` không báo lỗi ở đâu cả.** API vẫn trả `200`, nhưng nửa đường sự kiện outbox → subscriber không bao giờ chạy. Compose phải chạy cả hai, và `depends_on` phải phản ánh điều đó.
3. **Postgres map cổng `5433:5432`, không phải 5432.** Comment trong `compose.dev.yml` hiện tại giải thích: kiểu hỏng nguy hiểm nhất là **kết nối nhầm** một Postgres khác, không phải không kết nối được. Giữ nguyên khi chuyển sang `infra-erp`.

`backend-erp/compose.dev.yml` **chuyển** sang `infra-erp/compose/dev.yml` chứ không sao chép — hai file compose cho cùng một thứ là hai nguồn sự thật.

---

## 6. Quan trắc — cái gì thêm vào backend

**Metrics: `prometheus/client_golang`.** P-OBS viết ví dụ theo đúng API `WithLabelValues`, nên chọn khác là tự tạo khoảng cách với tài liệu. Ghi thành ADR-0015 vì chưa ADR nào nêu tên thư viện.

**`/metrics` là endpoint thứ ba của R-13, và nó không phải một handler đơn lẻ.** Checker `checks_route.go:33` đã có `/metrics` trong `pathHaTang` từ trước — nghĩa là ngày nó xuất hiện, không rule nào báo vi phạm. `cmd/api/router_test.go` có một danh sách `haTang` cục bộ chưa có `/metrics`, phải cập nhật.

P-OBS "Ca khó 3" đã chốt sẵn một ràng buộc: `/health`, `/ready`, `/metrics` phải bị **loại khỏi** metric latency/error-rate của API nghiệp vụ nhưng **vẫn** được đo riêng.

**Tracing: OTel SDK + exporter OTLP.** `go.mod` hiện có `go.opentelemetry.io/otel` nhưng **toàn bộ ở khối `// indirect`**, kéo vào bởi `testcontainers-go` — đó là package API rỗng, không có SDK, không exporter. Không đủ để tạo span thật. Chặng này thêm chúng thành phụ thuộc trực tiếp.

**Wrapper DB — HC-2 nửa một.** Hôm nay `shared/db/open.go` trả thẳng `*sqlx.DB`, không đo gì. DB là **ranh giới ra-ngoài-tiến-trình duy nhất đang thực sự hoạt động** (không HTTP client, không Redis). Wrapper bọc `DBTX` ghi latency histogram + error counter, và nó là khuôn mẫu cho HTTP client ngày nó xuất hiện.

**Log — mở rộng chứ không đổi.** `shared/log` đã đúng: `slog` JSON, `FromContext(ctx)` lấy `request_id`. Vấn đề là **gần như chưa ai dùng**: toàn bộ `modules/` chỉ có hai file gọi nó. Chặng này không đi thêm log tràn lan; nó chỉ nới checker HC-4 để mọi log **về sau** phải đúng khuôn.

---

## 7. Ba quyết định chặng này chốt

**ADR-0013 — `cmd/api` chạy một instance.** ADR-0001 nói kiến trúc *cho phép* nhiều instance sau load balancer, nhưng chưa ai chốt con số thật. Chốt **một**, khớp ADR-0003 (single-tenant trước) và quy mô thật. Hệ quả: rate limit in-process ở chặng G là đúng, không cần Redis. **Điều kiện mở lại phải ghi rõ**: ngày có instance thứ hai, bộ đếm in-process thành sai — hạn mức thực tế nhân theo số instance — và đó là ngày phải đổi.

**ADR-0014 — dead-letter là bảng riêng, không thêm cột vào `outbox`.** Migration `000009` chốt có chủ đích rằng `outbox` là append-only với **đúng một** ngoại lệ ghi lại (`published_at`), và comment giải thích vì sao. Thêm `attempts`/`last_error` vào đó là phá một nguyên tắc đã ghi thành văn. Chặng F **không hiện thực hóa** — chỉ chốt hình dạng để chặng G không mở lại, và để job dọn biết trước có bao nhiêu trạng thái.

**ADR-0015 — `prometheus/client_golang` cho metric, OTel SDK cho trace.** Kèm lý do và phương án bị loại.

---

## 8. Kéo theo ở `docs-erp`

| Thay đổi | Vì sao |
|---|---|
| **P-OBS**: hard check 1 ghi đích danh tên test runtime canh nó | Một mệnh đề không ai canh và một mệnh đề được canh bởi thứ có tên là hai trạng thái khác nhau |
| **P-OBS**: sửa script grep của hard check 5 để loại `_test.go` | Script hiện tại **không sạch** trên chính repo: 3 dòng ở `shared/audit/postgres_db_test.go` |
| **P-OBS**: hard check 3 bổ sung `prometheus.Labels{}` và chỗ khai `NewCounterVec` | Script hiện tại mù hai hình dạng đó |
| **P-OBS**: hard check 6 ghi rõ nó không canh được bằng máy, kèm lý do bắt oan | Xem mục 4.4 |
| **P-OBS**: hard check 1 ghi tên span là `{method} {route}`, kèm ranh giới của test | Xem đính chính ở mục 3; và test đó **không thể** canh "tiến trình có nối exporter không" — nó tiêm provider của chính nó |
| **P-OBS**: hard check 1 **bỏ** "exporter chưa được cấu hình" khỏi danh sách cách xanh giả | Mục đó lạc hậu so với thiết kế F6: không cấu hình exporter nghĩa là *span vẫn được tạo, chỉ không có nơi đến*, không phải *không có span* |
| **P-OBS**: hard check 3 sửa văn xuôi cho khớp hai arm của checker `HC-03` | Văn xuôi chốt `Targets: ["modules"]` trong khi chính script của nó quét `modules, shared` — tài liệu tự mâu thuẫn. F8 hiện thực hóa theo script: danh sách **trắng** ở `modules/**`, danh sách **đen theo tên** ở `shared/**` |
| **P-OBS**: script `2b` — nói thẳng grep không canh được mệnh đề này | Nó tìm chuỗi literal, code thật khai nhãn bằng **hằng có tên**; nó trả 0 dòng và sẽ mãi trả 0. `HC-03` là thứ canh, script chỉ còn là minh họa |
| ADR-0013, ADR-0014, ADR-0015 | Mục 7 |
| **C-DB-04 / ADR-0003**: `outbox_dead_letters` vào nhóm bảng nào | Một bảng mới phải có nhóm trước khi có migration |

**Không** đổi `RULES.md` — không rule nào đổi mệnh đề, nên `arch-pin` không phải chạy.

---

## 9. Định nghĩa hoàn thành

Mỗi dòng là một phép đột biến hoặc một lần chạy thật, không phải một lần CI xanh.

- Gỡ middleware tracing khỏi `router.go` → `TestMoiRouteV1SinhDungMotSpan` **đỏ**, và thông điệp nói **0 span** chứ không nói thiếu một chuỗi.
- Đăng ký một route `/api/v1` **trước** lời gọi `.Use(tracing)` → test đó **vẫn đỏ**. Đây là ca mà checker tĩnh sẽ bỏ sót, và là lý do test này tồn tại.
- Một request tới `/api/v1/machines/<uuid>` sinh span tên **`GET /api/v1/machines/:id`** — có method, có route pattern, **không** có uuid. Thuộc tính `http.route` của chính span đó là `/api/v1/machines/:id` **trần**, không có `GET ` dính đầu.
- Đổi nửa route của tên span thành `c.Request.URL.Path` → test đỏ vì tên span chứa id thật thay vì route pattern.
- Bỏ `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT` và `OTEL_EXPORTER_OTLP_ENDPOINT` khỏi môi trường → `api` **vẫn khởi động** và **vẫn sinh span**. Đặt một trong hai thành `collector:4318` (thiếu scheme) → `api` **exit 1**, nêu đích danh tên biến sai.
- `WithLabelValues(may.CompanyID)` ở một handler → checker HC-3 đỏ đúng dòng. `WithLabelValues(labelKindCNC)` với `const labelKindCNC` → **không đỏ**.
- Sinh `requestID := uuid.NewString()` ở `modules/machine` → checker HC-5 đỏ. **Bảy lời gọi `uuid.NewString()` đang có trong repo vẫn xanh** — đây là phép thử chứng minh checker phân biệt được chứ không chạy trên tập rỗng.
- Gọi `logger.Info(...)` với logger toàn cục trong một **service** (không phải handler) → checker HC-4 đỏ. Trước chặng này nó xanh.
- `docker compose -f compose/dev.yml up -d` rồi `scripts/up` → cả bốn container healthy, migration chạy, `/health` và `/ready` trả `200`, `/metrics` trả text Prometheus.
- Frontend ở `localhost:5173` gọi được `/api/v1/machines` trong **trình duyệt thật**, với `CORS_ALLOWED_ORIGINS` lấy từ `config/api.env`.
- Tắt `cmd/relay` trong compose → một sự kiện outbox nằm lại `published_at IS NULL`; bật lại → nó được xử. **Đã chạy thật ở F13 và đạt.**

> **Đính chính — vế thứ hai của dòng này SAI, và nó là lỗi của người viết spec.** Bản đầu
> viết *"và điều đó **quan sát được** trên `/metrics` chứ không im lặng như hôm nay"*, kèm
> câu ở plan rằng đây là *"thứ chặng này mua được mà không chặng nào trước có"*.
>
> F13 dựng thật rồi tắt `relay`, và đo được điều ngược lại: `cmd/relay` **không có một
> metric nào** và **không mở cổng nào**, nên Prometheus không thể scrape nó — nó scrape
> đúng một target là `api`. Không metric nào chạm `outbox`. Trong lúc sự kiện nằm kẹt,
> `/ready` vẫn `200`, `GET /api/v1/machines` vẫn `200`, `/metrics` không nói gì.
>
> **Thiếu `relay` hôm nay vẫn im lặng hoàn toàn, y hệt trước chặng F.** Chặng này mua
> được quan trắc cho `cmd/api`, không cho `cmd/relay`.
>
> Không sửa trong chặng F, và lý do là lý do mà chính spec này đã dùng để hoãn job dọn
> `outbox`: gauge tồn đọng, dead-letter và job dọn đều động vào cùng bảng `outbox` và cùng
> câu hỏi *"hàng nào đang ở trạng thái nào"*. Viết gauge trước khi dead-letter thêm trạng
> thái thứ ba là viết một thứ phải sửa lại. **Nợ có tên, sang chặng G, làm cùng lúc với
> hai món kia.** Ghi ở `infra-erp/docs/Limits.md` mục 1.
- `go run ./cmd/dev check` và `test` xanh; `arch-update` cho diff **không dòng nào hạ mức**.
- `arch/README.md` có dòng ghi HC-1 cố ý sống ngoài bảng, kèm lý do.

---

## 10. Rủi ro đã biết

**Ba checker mới sinh ra trên một repo gần rỗng.** HC-3 canh `WithLabelValues` mà hôm nay repo có **0** lời gọi như vậy. Cột FILE sẽ hiện 40 và dòng cảnh báo `PASS tren tap RONG` **không nổ**, vì cột đó đếm file trong thư mục đích chứ không đếm cấu trúc mà rule thật sự kết luận. Đây là hình dạng `R-19` mặc bộ đồ mới. Hàng phòng thủ: **thứ tự trong plan** — metric thật trước, checker sau — và định nghĩa hoàn thành đòi phép đột biến trên code sản phẩm chứ không trên fixture.

**Test runtime là một loại test chưa từng có trong repo này.** `TestRouterKhongCoRouteNgoaiV1` đọc `r.Routes()` nhưng không bắn request nào. Test HC-1 phải dựng span exporter trong bộ nhớ và bắn một request cho mỗi route — nếu nó chập chờn, bài học chặng D áp dụng: **không nới hạn chờ**, bỏ đồng hồ khỏi test bằng cách dùng một exporter đồng bộ có điểm kết thúc gọi tên được.

**Ba phụ thuộc mới trên đường quan trắc.** `client_golang` + OTel SDK + exporter là những thứ đi vào mọi handler về sau. `go.mod` hiện có 14 phụ thuộc trực tiếp và không cái nào liên quan quan trắc. Điểm phải canh: chúng vào `shared/`, không vào `modules/**` — nếu một module import thẳng `prometheus`, đó là dấu hiệu wrapper chưa đủ và HC-2a phải bắt được.

**Compose là nơi bí mật dễ rò nhất.** `JWT_SECRET` phải ≥ 32 byte và `cmd/relay` cố ý không đọc nó. Một khối `env_file` dùng chung cho cả hai tiến trình sẽ phá đúng ranh giới mà code đã dựng — và nó sẽ trông rất tiện.

**`infra-erp` chưa có CI.** Hai repo kia có; repo này thì không. Một compose file sai cú pháp sẽ không ai biết cho tới lúc chạy. `CLAUDE.md` của nó tự khai lệnh lint là `docker compose config -q` — chặng này phải làm lệnh đó chạy trong CI, nếu không `infra-erp` là repo duy nhất không có người canh.
