# ADR-0015: `prometheus/client_golang` cho metric, OTel SDK cho trace

**Status:** Accepted (2026-08-14)

## Context

Chặng này dựng quan trắc lần đầu cho backend: registry metric, endpoint `/metrics` (R-13
khai ba endpoint hạ tầng, tới đầu chặng F mới có hai), và middleware tracing cho HC-1
của [P-OBS](../02-principles/P-OBS-observability.md). Chưa ADR nào nêu tên một thư viện
cụ thể cho quan trắc.

`P-OBS-observability.md` đã tồn tại từ trước chặng này, và đã viết ví dụ hard check 3
theo đúng dạng gọi `WithLabelValues(` — hình dạng đặc trưng của
`prometheus/client_golang`, khác hẳn API của OTel Metrics
(`Int64Counter.Add(ctx, n, metric.WithAttributes(...))`). Ví dụ đó không phải một lựa
chọn ngẫu nhiên minh họa cho có; nó là văn bản mà hard check 3 của chặng này (checker
AST, spec thiết kế mục 4.3) sẽ đọc và bắt theo đúng hình dạng đó.

Đọc `backend-erp/go.mod` tại thời điểm quyết định này (bắt buộc trước khi viết ADR, xem
xác nhận dưới đây) cho thấy một sự thật cụ thể: gói `go.opentelemetry.io/otel` **đã có
mặt**, cùng `go.opentelemetry.io/otel/metric`, `go.opentelemetry.io/otel/trace`,
`go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp`, và
`go.opentelemetry.io/auto/sdk` — nhưng **toàn bộ nằm trong khối `require ( ... )` đánh
dấu `// indirect`** (dòng 88–92), kéo vào bắc cầu bởi `testcontainers-go` (dùng cho hạ
tầng test, không liên quan quan trắc). Đây là gói **API** của OTel — interface
`TracerProvider`, `Span`, kiểu dữ liệu — không phải SDK triển khai thật: không gọi
`SetTracerProvider` thì mọi `Tracer(...).Start(...)` trả về một no-op span, không ghi
gì, không xuất đi đâu. `go.mod` **không có dòng require nào** — kể cả gián tiếp — cho
`go.opentelemetry.io/otel/sdk` (gói triển khai thật, có bộ xử lý span và bộ lấy mẫu) hay
bất kỳ gói exporter nào (`otlptracegrpc`, `otlptracehttp`, hay tương đương); `go.sum` có
ghi sẵn checksum của `otel/sdk` — dấu vết còn lại từ đồ thị module đầy đủ mà Go giữ để
xác minh — nhưng đó không phải bằng chứng nó đang là phụ thuộc thật của build này: không
có dòng `require`, import nó hôm nay sẽ cần `go mod tidy` thêm dòng mới. Nói cách khác:
có mặt API rỗng, không có SDK, không có exporter — không đủ để tạo một span thật.

Cũng đọc `backend-erp/go.mod`: **không có dòng nào** nhắc tới `prometheus` — gói
`prometheus/client_golang` chưa từng có mặt, kể cả gián tiếp.

## Decision

**Metric dùng `prometheus/client_golang`. Trace dùng OTel SDK Go
(`go.opentelemetry.io/otel/sdk`) cùng một exporter OTLP, và ba gói OTel hiện có chuyển
từ `// indirect` sang phụ thuộc trực tiếp.**

- Registry metric (counter, histogram) sống ở `shared/metrics`, dùng API
  `NewCounterVec`/`NewHistogramVec` + `WithLabelValues(` — đúng hình dạng P-OBS đã viết
  ví dụ, và đúng hình dạng hard check 3 (chặng này) sẽ bắt theo AST.
- Trace dùng OTel SDK: `go.opentelemetry.io/otel/sdk` cho `TracerProvider` thật, cộng
  một exporter OTLP để gửi span ra ngoài tiến trình. Giao thức cụ thể của exporter (gRPC
  hay HTTP) không chốt ở ADR này — đó là chi tiết cấu hình endpoint, không phải chi tiết
  kiến trúc, và thuộc phạm vi hiện thực hóa middleware tracing cùng cấu hình
  `infra-erp`.
- Hai hệ thống không hợp nhất qua một SDK duy nhất: metric không đi qua OTel Metrics
  API, trace không đi qua Prometheus. Đây là lựa chọn có chủ đích, không phải thiếu
  nhất quán — xem Alternatives.
- `go.opentelemetry.io/otel`, `go.opentelemetry.io/otel/trace` chuyển thành phụ thuộc
  trực tiếp; `go.opentelemetry.io/otel/sdk` (gói mới, hiện chưa có trong `go.mod`) được
  thêm làm phụ thuộc trực tiếp. `prometheus/client_golang` là phụ thuộc trực tiếp mới,
  chưa từng có mặt kể cả gián tiếp.

## Alternatives

**Dùng OTel Metrics API (`go.opentelemetry.io/otel/metric`) cho cả metric lẫn trace,
một SDK duy nhất** — loại. Lý do cụ thể, không phải sở thích: `P-OBS-observability.md`
đã viết ví dụ mẫu và mô tả hard check 3 theo đúng API `WithLabelValues(`. Chọn OTel
Metrics nghĩa là viết lại ví dụ đó, viết lại mô tả hard check, và thiết kế lại checker
AST của F8 theo một điểm neo khác — `meter.Int64Counter(...)` rồi
`.Add(ctx, n, metric.WithAttributes(...))`, đối số label không còn nằm gọn trong một lời
gọi tên cố định mà rải qua nhiều bước xây `attribute.KeyValue`, khó bắt bằng AST đơn
giản hơn hẳn `WithLabelValues(`. Chọn khác `client_golang` ở đây là tự tạo khoảng cách
với chính tài liệu nguyên tắc của dự án, không phải chỉ với một dòng ví dụ.

**Dùng OTel SDK cho trace, và OTel Metrics + `otel/exporters/prometheus` (exporter kéo
dữ liệu ra định dạng Prometheus) thay vì `client_golang` trực tiếp** — loại, cùng lý do
phương án trên: API instrumentation vẫn là của OTel Metrics
(`Int64Counter.Add(...)`), không phải `WithLabelValues(`, nên vẫn lệch khỏi P-OBS. Thêm
một tầng exporter chỉ để cuối cùng lộ ra định dạng text Prometheus mà `client_golang`
đã tạo trực tiếp, không đổi lấy gì tương xứng ở quy mô một registry của một tiến trình.

**Tự viết registry metric và tracer riêng, không phụ thuộc thư viện ngoài** — loại. Chi
phí dựng lại đúng hai thứ: một registry chuỗi thời gian kèm định dạng text exposition
đúng chuẩn Prometheus (để Prometheus server scrape được), và một cơ chế context
propagation cho trace xuyên qua middleware và (về sau) client HTTP — cả hai đều là bài
toán đã có lời giải chuẩn công nghiệp, được hàng nghìn dự án kiểm chứng. Cùng loại lý do
ADR-0012 đã dùng để loại "viết TypeScript AST checker bằng Go": dựng lại thứ đã có sẵn,
đã được kiểm chứng, cho một phạm vi hẹp hơn, không có lợi ích tương xứng.

**Hoãn trace sang chặng sau, chỉ làm metric ở chặng này** — loại. HC-1 ("mọi handler
`/api/v1` chạy qua middleware tracing tạo span") là một phần mục tiêu đo được của chính
chặng F (spec thiết kế mục 1), canh bằng `TestMoiRouteV1SinhDungMotSpan`
([P-OBS-observability.md](../02-principles/P-OBS-observability.md) hard check 1). Không
làm trace ở chặng này nghĩa là không đạt goal của chặng, không phải một cách sắp xếp lại
công việc trung lập.

## Consequences

**Được:**

- API metric khớp đúng ví dụ đã viết sẵn trong `P-OBS-observability.md` và đúng hình
  dạng mà checker HC-3 (F8) cần để bắt bằng AST — không phải viết lại tài liệu nguyên
  tắc để khớp thư viện chọn sau.
- Ba gói OTel cốt lõi đã có mặt trong `go.sum` (qua `testcontainers-go`), nên chuyển
  chúng thành trực tiếp là mở rộng một phụ thuộc đã được vetted, không phải giới thiệu
  một cây phụ thuộc hoàn toàn mới vào build.
- `client_golang` và OTel SDK đều là lựa chọn tham chiếu (reference implementation) của
  hệ sinh thái quan trắc Go — tài liệu, ví dụ, và công cụ đi kèm (Grafana dashboard,
  OTLP collector) đều giả định đúng hai thư viện này.

**Mất:**

- **Hai SDK khởi tạo riêng, không hợp nhất.** Registry Prometheus và `TracerProvider`
  của OTel là hai đối tượng sống độc lập trong `shared/`, mỗi cái có vòng đời khởi tạo
  và tắt riêng — không có một điểm cấu hình quan trắc duy nhất.
- Nếu OTel Metrics API sau này đủ trưởng thành để thay được `client_golang` mà không
  mất khả năng bắt bằng AST theo hình dạng tương đương `WithLabelValues(`, việc hợp
  nhất về một SDK là một ADR mới, không phải hệ quả tự nhiên của ADR này.

**Nợ để lại — điều kiện mở lại quyết định này:**

- **`go.mod` phải đổi thật ở chặng hiện thực hóa (F6), không chỉ ở ADR.** Hai gói
  `go.opentelemetry.io/otel`, `go.opentelemetry.io/otel/trace` chuyển từ `// indirect`
  sang phần `require` trực tiếp; `go.opentelemetry.io/otel/sdk` và một gói exporter OTLP
  là phụ thuộc **mới**, hiện chưa có dòng nào trong `go.mod` kể cả gián tiếp. ADR này
  chốt lựa chọn thư viện; nó không tự làm thay việc sửa `go.mod`.
- Nếu về sau có nhiều hơn một tiến trình cần trace (ví dụ một service thứ hai ngoài
  `cmd/api`/`cmd/relay`), cấu hình exporter (endpoint OTLP, tỉ lệ lấy mẫu) nên tập trung
  ở một nơi tại `shared/` — chưa được quyết cụ thể ở ADR này vì chưa có ca dùng thứ hai.

**Constrains:** —
