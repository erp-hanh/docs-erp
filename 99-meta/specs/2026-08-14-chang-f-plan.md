# Chặng F — Implementation Plan

> **Spec:** [2026-08-14-chang-f-van-hanh-design.md](2026-08-14-chang-f-van-hanh-design.md)
> Plan này ghi ở mức **task**, không mức step. Chi tiết từng bước nằm trong prompt của
> subagent thực thi — cùng cách năm chặng trước đã chạy.

**Goal:** Gỡ middleware tracing khỏi `cmd/api/router.go` thì `TestMoiRouteV1SinhDungMotSpan` đỏ, và nó đỏ vì đếm được **0 span** chứ không vì thiếu một chuỗi.

---

## Đồ thị phụ thuộc

Một ràng buộc thứ tự **cứng**, và nó là hàng phòng thủ chính của cả chặng:

> **Checker phải viết SAU code mà nó canh, không trước.**

Repo hôm nay có **0** dòng Prometheus, **0** `WithLabelValues`. Một checker HC-3 viết trước
sẽ sinh ra đã xanh, với cột FILE = 40 trông rất thật — đúng hình dạng `R-19` mà chặng E
vừa trả giá. Cột FILE **không** phát hiện được điều này (nó đếm file trong thư mục đích,
không đếm cấu trúc mà rule thật sự kết luận), nên thứ tự là thứ duy nhất bảo vệ.

```
DOT 1 (song song, 4 agent):
  F1  infra-erp: compose/dev.yml + config/*.env.example + scripts/  infra-erp/
  F2  Dockerfile cho cmd/api va cmd/relay + healthcheck            infra-erp/
  F3  ADR-0013/0014/0015 + keo theo P-OBS                          docs-erp/
  F4  registry Prometheus + /metrics                               backend-erp/shared/, cmd/api/

DOT 2 (sau F4):
  F5  wrapper DB ghi latency histogram + error counter             backend-erp/shared/db/
  F6  OTel SDK + middleware tracing                                backend-erp/shared/, cmd/api/

DOT 3 (sau F6):
  F7  TestMoiRouteV1SinhDungMotSpan - test runtime cho HC-1        backend-erp/cmd/api/

DOT 4 (sau F4 va F5 - CHI khi metric that da ton tai):
  F8  package so dang ky const + checker HC-3                      backend-erp/arch/
  F9  checker HC-5                                                 backend-erp/arch/
  F10 noi HC-4 ra khoi layer=="handler"                            backend-erp/arch/

DOT 5 (sau F1, F2, F6):
  F11 observability/: prometheus.yml + grafana, gan vao compose    infra-erp/
  F12 CI cho infra-erp: docker compose config -q                   infra-erp/.github/

DOT 6 (sau tat ca):
  F13 chay that end-to-end + docs cua infra-erp
```

**F8 phải sau F4/F5, không thương lượng.** Định nghĩa hoàn thành của F8 là một phép đột
biến trên **code sản phẩm thật** (`WithLabelValues(may.CompanyID)` ở một handler có thật),
không phải trên fixture. Không có F4/F5 thì không có handler nào để đột biến.

**F7 phải sau F6** vì hiển nhiên, nhưng ghi ra vì lý do ít hiển nhiên: F7 là thứ **duy
nhất** chứng minh F6 làm đúng việc. Một middleware tracing không có test runtime là một
middleware không ai biết có chạy hay không — và đó chính là mệnh đề HC-1.

**F9 và F10 không phụ thuộc F4.** HC-5 có sẵn dữ liệu thật hôm nay (bảy lời gọi
`uuid.NewString()`, không cái nào là `request_id`), và HC-4 chỉ là nới một dòng trên
checker đã chạy. Chúng ở DOT 4 vì cùng vùng file `arch/`, không vì phụ thuộc.

---

## Ràng buộc chung cho MỌI task

1. **Chỉ build/test phạm vi của mình.** Không `go build ./...`, không `docker compose up`
   toàn stack — agent khác đang viết dở, và lỗi của người khác không phải tín hiệu về việc
   mình đúng hay sai.
2. **Không sửa file ngoài phạm vi task.** `infra-erp/**` chỉ F1, F2, F11, F12, F13;
   `backend-erp/arch/**` chỉ F8, F9, F10; `docs-erp/**` chỉ F3.
3. **Không chạy `go test ./arch -update`, `arch-pin`, hay `npm run arch:update`** — golden
   file do người điều phối sinh lại một lần ở cuối.
4. Comment tiếng Việt **không dấu**, giải thích **vì sao** chứ không mô tả lại code. Tài
   liệu thì tiếng Việt **có dấu**.
5. **Phụ thuộc quan trắc vào `shared/`, KHÔNG vào `modules/**`.** Nếu một module phải
   import thẳng `prometheus` hay `otel`, đó là dấu hiệu wrapper chưa đủ — dừng và báo cáo,
   đừng import.
6. **`cmd/relay` không đọc `JWT_SECRET` và không đọc `PORT`.** Comment trong code giải
   thích: đọc bí mật vào một tiến trình không cần nó là mở rộng phạm vi rò rỉ. Một khối
   `env_file` dùng chung cho cả hai tiến trình phá đúng ranh giới đó — và nó sẽ trông rất
   tiện.
7. **Migration không tự chạy lúc khởi động.** `cmd/api/main.go` cố ý không gọi hàm migrate
   nào. Compose và script không được lén thêm bước đó.
8. **Chạy test cần Postgres**: container `backend-erp-postgres-1` cổng 5433, template
   `erp_template` đã dựng. `export TEST_DATABASE_URL="postgres://erp:erp@localhost:5433/erp_dev?sslmode=disable"`
   rồi `go test ...`. Đừng chạy `go run ./cmd/dev test` (chậm, dựng container riêng).

---

## Task

| ID | Nội dung | File chính | Nghiệm thu |
|---|---|---|---|
| **F1** | `compose/dev.yml` (**chuyển** từ `backend-erp/compose.dev.yml`, không sao chép), `config/{api,relay,frontend}.env.example`, `scripts/up` | `infra-erp/{compose,config,scripts}/` | Postgres giữ map `5433:5432` kèm lý do; `api` và `relay` **không** dùng chung `env_file`; `scripts/up` gọi `cmd/dev migrate-up` **tường minh** sau khi Postgres healthy |
| **F2** | `Dockerfile` cho `cmd/api` và `cmd/relay`, healthcheck container | `infra-erp/` | Multi-stage, ảnh cuối không chứa toolchain Go; healthcheck của `api` gọi `/ready` chứ không `/health` (`/ready` mới kiểm được DB); `relay` không mở cổng nào nên healthcheck của nó **không** dùng HTTP |
| **F3** | ADR-0013 (một instance), ADR-0014 (dead-letter bảng riêng), ADR-0015 (chọn thư viện); kéo theo P-OBS + C-DB-04 | `docs-erp/03-decisions/`, `02-principles/P-OBS-*.md`, `04-conventions/` | `check-ids.ps1` xanh; ADR-0013 ghi **điều kiện mở lại**; P-OBS hard check 5 sửa script để loại `_test.go` (hiện script của nó trả 3 dòng false-positive ở `shared/audit/postgres_db_test.go`); hard check 1 ghi đích danh tên test runtime; hard check 6 ghi rõ vì sao không canh được |
| **F4** | Registry Prometheus + `/metrics` + `pathMetrics` | `backend-erp/shared/metrics/`, `cmd/api/router.go` | `/metrics` trả text Prometheus; `router_test.go` danh sách `haTang` cục bộ cập nhật; ba endpoint hạ tầng **loại khỏi** metric latency/error-rate của API nghiệp vụ nhưng **vẫn** đo riêng (P-OBS ca khó 3) |
| **F5** | Wrapper `DBTX` ghi latency histogram + error counter | `backend-erp/shared/db/` | Mọi repository đi qua wrapper mà **không sửa một dòng nào** trong `modules/**`; label chỉ từ hằng tĩnh — không `company_id`, không id bản ghi |
| **F6** | OTel SDK + exporter + middleware tracing | `backend-erp/shared/middleware/tracing/`, `cmd/api/` | Span name là `{method} c.FullPath()` (route pattern), **không** `c.Request.URL.Path`; `go.mod` chuyển otel từ `// indirect` sang phụ thuộc trực tiếp |
| **F7** | `TestMoiRouteV1SinhDungMotSpan` — test runtime cho HC-1 | `backend-erp/cmd/api/` | Dựng router thật + exporter trong bộ nhớ, lặp qua `r.Routes()`, bắn một request mỗi route dưới `/api/v1`, khẳng định **đúng một** span và `span.Name == route.Method + " " + route.Path`. **Không dùng đồng hồ** — exporter đồng bộ có điểm kết thúc gọi tên được (bài học chặng D) |
| **F8** | Package sổ đăng ký `const` cấp package + checker HC-3 | `backend-erp/arch/internal/consts/`, `arch/checks_*.go`, `rules.go` | Bắt `WithLabelValues` đối số không phải hằng, **và** `prometheus.Labels{}` map form, **và** tên label tại chỗ khai `NewCounterVec(..., []string{...})`. Không dùng `go/packages` (nó giết fixture — xem đầu `loader.go`) |
| **F9** | Checker HC-5 — đúng một chỗ sinh `request_id` | `backend-erp/arch/` | Ba dấu hiệu ở spec mục 4.1. **Bảy lời gọi `uuid.NewString()` đang có trong repo phải VẪN XANH** — đây là phép thử chứng minh checker phân biệt được |
| **F10** | Nới `loggerToanCuc` ra khỏi `layer == "handler"` | `backend-erp/arch/checks_migration.go`, `checks_*.go` | Logger toàn cục trong một **service** bị bắt; trước chặng này nó xanh. `log.FromContext(ctx).Info(...)` vẫn không bị bắt |
| **F11** | `observability/prometheus.yml` + dashboard Grafana tối thiểu, gắn vào compose | `infra-erp/observability/` | Prometheus scrape được `/metrics` của `api` trong compose; dashboard hiện ít nhất latency theo route pattern và error rate theo mã lỗi |
| **F12** | CI cho `infra-erp` | `infra-erp/.github/workflows/ci.yml` | Job lint chạy `docker compose config -q` cho **mọi** file trong `compose/`; đỏ khi một file compose sai cú pháp — thử thật rồi hoàn lại |
| **F13** | Chạy thật end-to-end + docs `infra-erp` | `infra-erp/docs/` | Xem "Cuối chặng" mục 1 |
| **F14** | Chuyển `compose.dev.yml` khỏi `backend-erp`, trỏ `cmd/dev` sang `infra-erp/compose/dev.yml` theo khuôn `arch/internal/registry` (biến `ERP_INFRA_PATH`, mặc định `../infra-erp`) | `backend-erp/cmd/dev/infra.go` | Hai file compose cùng tả một ngăn xếp là hai nguồn sự thật lệch nhau mà không báo lỗi ở đâu cả; không tìm thấy `infra-erp` thì lệnh `dev` phải dừng và nói rõ cách sửa, không lặng lẽ lùi về ngăn xếp khác. **Vì sao tồn tại:** dọn nợ kiến trúc đã ghi nhận từ trước (hai bản compose song song), không phải một agent từ chối quyết — task này là don dẹp có chủ đích |
| **F15** | Sửa bốn nợ tài liệu ở `P-OBS` mà F4 đo được lúc dựng registry Prometheus nhưng không sửa vì ngoài vùng file của nó (`backend-erp/shared/metrics/`, `cmd/api/router.go`) | `docs-erp/02-principles/P-OBS-observability.md` | Bốn chỗ tài liệu khớp lại với hành vi `pathMetrics`/registry thật đã dựng ở F4. **Vì sao tồn tại:** cùng khuôn với F18 này — một agent đo được nợ tài liệu thật trong lúc viết code, báo cáo thay vì tự sửa ngoài vùng file được giao, và nợ đó phải có một task riêng để dọn |
| **F16** | Thêm hình dạng miễn thứ năm của R-11 (`gin.WrapH`/`gin.WrapF` bọc `http.Handler` bên thứ ba, ví dụ `promhttp.Handler()` cho `/metrics`) | `docs-erp/01-rules/RULES.md` (R-11, mục Ngoại lệ) | Endpoint `/metrics` do F4 dựng trả định dạng text của Prometheus — không mang được envelope `shared/response` — nên vi phạm hình dạng R-11 hiện có. **Vì sao tồn tại:** sửa `RULES.md` đòi `arch-pin`, một thao tác ngoài quyền của agent xây dựng bình thường; F4 đúng khi không tự thêm ngoại lệ vào rule nguồn, nên cần một task riêng có quyền chạy `arch-pin` |
| **F17** | Đổi tên span từ `route.Path` trần sang `{method} {route}` (đúng quy ước ngữ nghĩa HTTP của OpenTelemetry) ở cả `shared/middleware/tracing`, `cmd/api`, và ba chỗ `P-OBS` nói sai theo thiết kế gốc | `backend-erp/shared/middleware/tracing/`, `cmd/api/`, `docs-erp/02-principles/P-OBS-observability.md` | Span name đổi đúng quy ước; ba chỗ `P-OBS` sửa: hard check 1 ghi tên span `{method} {route}` kèm ranh giới thật của test, bỏ "exporter chưa cấu hình" khỏi danh sách xanh giả (nó không phải xanh giả), hard check 3 sửa văn xuôi cho khớp hai arm của `HC-03`. **Vì sao tồn tại:** thiết kế gốc của chặng F tự nó sai (`span.Name == route.Path` không theo quy ước OTel); F6/F7 xây đúng theo spec sai đó thay vì tự sửa spec — đúng hành vi, vì lệch spec là ca cần dừng và hỏi chứ không phải tự chọn bên — nên cần một task riêng sửa cả thiết kế lẫn hệ quả của nó |
| **F18** | Gom sáu nợ tài liệu mà F9 và F17 đo được nhưng không sửa vì ngoài vùng file của chúng (hard check 4 và 5 của `P-OBS`, script 1, comment `HC-03` của `rules.go`, mục "Cuối chặng" điều 8, bảng task này) | `docs-erp/**`, `backend-erp/arch/rules.go` (chỉ comment `HC-03`) | Xem báo cáo của chính task này. **Vì sao tồn tại:** cùng khuôn với F15 — hai agent (`F9` viết checker `HC-05`, `F17` đổi tên span) đo được lệch tài liệu thật trong lúc làm việc của mình, nhưng vùng file được giao không cho phép sửa `docs-erp/**`; nêu ra và dừng lại đúng là hành vi được kỳ vọng ở dự án này, không phải một thiếu sót |

> **Hai ô nghiệm thu của F6 và F7 đã được sửa ở F17, và bản gốc của chúng sai.** Bản đầu
> đòi `span.Name == route.Path` — tên span **trần**. F6 làm đúng thế, F7 kiểm đúng thế;
> cả hai làm đúng theo spec, và spec sai: quy ước ngữ nghĩa HTTP của OpenTelemetry nói
> tên span phía server nên là `{method} {route}`, và ví dụ trong chính `P-OBS` hard check
> 1 đã viết theo quy ước đó từ trước. Lý do đầy đủ nằm ở đính chính mục 3 của spec thiết
> kế.

---

## Cuối chặng — người điều phối làm, không giao agent

1. **Phép thử của chính mục tiêu, ba chiều.** Gỡ middleware tracing khỏi `router.go` →
   `TestMoiRouteV1SinhDungMotSpan` đỏ, **và đọc thông điệp**: nó phải nói *0 span*, không
   nói *thiếu một chuỗi*. Rồi ca mà checker tĩnh sẽ bỏ sót: đăng ký một route `/api/v1`
   **trước** lời gọi `.Use(tracing)` → test **vẫn phải đỏ**. Rồi đổi tên span sang
   `c.Request.URL.Path` → đỏ vì tên span chứa id thật. Ba ca này là lý do HC-1 không có ID
   trong bảng `arch/`.
2. **Phép thử chống tập rỗng cho HC-3.** `WithLabelValues(may.CompanyID)` ở một handler
   **thật** → đỏ đúng dòng. `WithLabelValues(labelKindCNC)` với `const labelKindCNC` →
   **không đỏ**. Nếu ca thứ hai cũng đỏ thì checker đang bắt oan và phải sửa checker,
   không lách code.
3. **Phép thử phân biệt cho HC-5.** Thêm `requestID := uuid.NewString()` vào
   `modules/machine` → đỏ. Rồi xác nhận **bảy lời gọi `uuid.NewString()` đang có vẫn
   xanh**. Một checker đỏ cả bốn là một checker sẽ bị tắt trong tuần đầu.
4. **Phép thử cho HC-4.** `logger.Info(...)` với logger toàn cục trong một **service** →
   đỏ. Trước chặng này nó xanh — đó là điều F10 mua được.
5. **Chạy thật cả stack.** `docker compose -f compose/dev.yml up -d` rồi `scripts/up`:
   bốn container healthy, migration chạy, `/health` `/ready` trả `200`, `/metrics` trả text
   Prometheus, Grafana hiện dashboard. Rồi mở **trình duyệt thật**, đăng nhập bằng frontend
   ở `localhost:5173`, đi hết lát cắt.
6. **Phép thử ngược cho relay.** Tắt `cmd/relay` trong compose, tạo một sự kiện, xác nhận
   nó nằm lại `published_at IS NULL`; bật lại → được xử. **Đã chạy ở F13, đạt.**

   > **Vế thứ hai của dòng này từng SAI và đã bị gỡ.** Bản đầu đòi *"và điều đó quan sát
   > được trên `/metrics`"*, và gọi đó là *"thứ chặng này mua được mà không chặng nào
   > trước có"*. F13 đo được điều ngược lại: `relay` không có metric nào, không mở cổng
   > nào, Prometheus scrape đúng một target là `api`, và trong lúc sự kiện nằm kẹt thì
   > `/ready` vẫn `200` còn `/metrics` không nói gì. **Thiếu `relay` vẫn im lặng hoàn
   > toàn.** Nợ có tên, sang chặng G cùng dead-letter và job dọn — ba món cùng động vào
   > bảng `outbox`. Xem đính chính đầy đủ ở mục 9 của spec design.
7. **Phép thử cho F12.** Làm hỏng cú pháp một file compose → CI của `infra-erp` đỏ. Hoàn
   lại.
8. `go run ./cmd/dev arch-update`, **đọc diff** — không dòng nào hạ mức, và hai dòng mới
   trong bảng `rules` (`HC-03`, `HC-05`) có `Unverifiable` khác rỗng, cộng bảng
   `hardChecks` khai đủ sáu mục hard check của P-OBS (`HC-01` … `HC-06`) kèm `CanhBoi`
   khác rỗng cho từng mục — không có dòng `HC-04` riêng trong bảng `rules`, và đó là chủ
   ý chứ không phải thiếu sót (xem ghi chú đầu biến `hardChecks` ở `arch/rules.go`).
9. `go generate ./arch/...` + `git diff --exit-code`.
10. `go run ./cmd/dev check` rồi `test`. `check-ids.ps1` cho `docs-erp`.
11. Xác nhận `arch/README.md` có dòng ghi **HC-1 cố ý sống ngoài bảng**, kèm lý do và tên
    test canh nó. Không có dòng đó thì chặng sau sẽ hỏi lại đúng câu hỏi này.
12. Đẩy bốn repo, đợi CI — `backend-erp` ba job, `frontend-erp` ba job, `infra-erp` **lần
    đầu có CI**.
