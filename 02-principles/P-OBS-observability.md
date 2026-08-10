# P-OBS — Observability

**Câu hỏi nó trả lời:** Đo gì, log ở mức nào?
**Rules:** R-16, R-17
**Decisions:** —

> **Ranh giới với R-17 — đọc mục này trước khi đọc phần còn lại.** Hai khái niệm này
> chồng nhau nhiều nhất trong cả bộ tài liệu, và mọi lần chúng bị trộn đều dẫn tới cùng
> một kết cục: hai hệ thống định danh song song, không nối được với nhau.
>
> | | R-17 | P-OBS |
> |---|---|---|
> | Truy vết cái gì | **Dữ liệu nghiệp vụ** — ai sửa bản ghi nào, lúc nào | **Sức khỏe hệ thống** — latency, error rate, span, saturation |
> | Ai đọc | Kiểm toán viên, người dùng cuối, bộ phận tranh chấp | Người trực vận hành |
> | Đầu ra ở đâu | Bảng `audit_logs` | Metric, trace, log kỹ thuật |
> | Giữ bao lâu | Theo lịch giữ liệu pháp lý, tính bằng năm | Theo chi phí lưu trữ, tính bằng tuần |
> | Mất nó thì sao | Mất bằng chứng, không xử được tranh chấp | Không biết hệ thống đang ốm ở đâu |
>
> **Điểm giao duy nhất là `request_id`/`trace_id`. R-17 sở hữu nó: middleware của R-17
> sinh giá trị, gắn vào `ctx`, đặt header `X-Request-Id` cho mọi response. P-OBS chỉ
> tiêu thụ — đọc ra khỏi `ctx` để gắn vào log và span. P-OBS cấm định nghĩa lại
> `request_id`:** cấm sinh một id riêng cho tracing, cấm đổi tên trường, cấm dựng thêm
> một middleware ghi đè giá trị đã có. Hai id song song nghĩa là một dòng `audit_logs`
> không nối được với trace của chính request đã sinh ra nó — mất đúng thứ mà cả hai bên
> cần, mà không bên nào báo lỗi.
>
> Quy tắc phân loại nhanh khi phân vân: câu hỏi bắt đầu bằng **"ai"** → R-17. Câu hỏi
> bắt đầu bằng **"bao lâu"** hoặc **"bao nhiêu lần"** → P-OBS.

## Cách suy luận

**Đo ở ranh giới, không đo bên trong.** Đặt instrumentation ở mọi chỗ luồng điều khiển
rời khỏi tiến trình: HTTP vào, truy vấn DB, Redis, HTTP client gọi ra, publish/consume
bus. Với mỗi ranh giới đó, bốn tín hiệu là đủ để bắt đầu: latency, số lượt gọi, số lỗi,
mức bão hòa (kích thước pool, độ dài hàng đợi). Hàm nội bộ không cần metric riêng —
nó đã nằm trong span của lời gọi bao ngoài, và mỗi metric thêm vào là chi phí phải trả
mãi mãi.

**Mức log là câu trả lời cho "ai phải thức dậy", không phải thang đo mức độ nghiêm
trọng cảm tính:**

- `Error` — có người phải xử lý, ngay hoặc sớm. Mất kết nối DB, panic được recover, job
  thất bại sau khi hết lượt retry.
- `Warn` — bất thường nhưng hệ thống tự xoay xở được. Retry lần một thất bại rồi lần
  hai thành công, rơi về giá trị mặc định, gần chạm hạn mức.
- `Info` — mốc đáng lần lại về sau. Đơn được duyệt, job bắt đầu và kết thúc, **lỗi
  nghiệp vụ bị từ chối**.
- `Debug` — tắt ở production; nếu nó cần bật ở production thì nó không phải `Debug`.

**Lỗi nghiệp vụ không phải `Error`.** "Đơn hàng đã duyệt nên không sửa được" là hệ
thống làm **đúng** việc của nó: nó vừa chặn một thao tác sai. Log nó ở mức `Error` gây
ra hai hỏng hóc cùng lúc: dashboard error rate phản ánh hành vi người dùng chứ không
phản ánh sức khỏe hệ thống, và cảnh báo trở thành tiếng ồn nên người trực học cách bỏ
qua nó — tới lúc có `Error` thật thì không ai nhìn nữa. Thứ đúng để đo lỗi nghiệp vụ là
một **counter theo mã lỗi**, không phải mức log
([P-ERR-error-handling.md](P-ERR-error-handling.md)).

**Log gì.** Cặp key-value nguyên thủy, không truyền struct hay con trỏ (R-16) — vì một
struct hôm nay không có gì nhạy cảm, ngày mai ai đó thêm field `password_hash` vào, và
dòng log lặng lẽ bắt đầu rò rỉ. Không log payload request, không log token, không log
số CCCD. Câu hỏi tự kiểm trước khi thêm một dòng log: *"nếu dòng này lọt ra ngoài thì
có mất gì không?"*

**Cardinality là ngân sách, không phải chi tiết kỹ thuật.** Mỗi tổ hợp giá trị label
sinh một chuỗi thời gian riêng, và chi phí là tích của các label chứ không phải tổng.
`company_id`, `user_id`, `order_id`, `request_id` đều là label **sai** — chúng thuộc về
log và trace, nơi chi phí tuyến tính theo số sự kiện, không phải metric, nơi chi phí
tuyến tính theo số *tổ hợp*. Label đúng là thứ có tập giá trị hữu hạn và biết trước:
route pattern, mã lỗi, tên module, method HTTP. Ranh giới thực dụng: nếu bạn không liệt
kê ra được mọi giá trị có thể của một label thì nó không phải label.

**Trace gánh phần metric không gánh được.** Id nghiệp vụ đặt làm span attribute thì rẻ,
vì span không nhân chuỗi thời gian. Vì vậy đường tra đúng khi có sự cố là: metric chỉ
ra *ở đâu* chậm (route nào, p99 bao nhiêu) → trace chỉ ra *request nào* chậm và chậm ở
bước nào → log kèm `request_id` chỉ ra *vì sao* → `audit_logs` cùng `request_id` chỉ ra
*ai* và *dữ liệu nào* đã đổi (R-17). Bốn tầng, nối bằng đúng một giá trị.

## Hard check

1. **Mọi handler dưới `/api/v1` chạy qua middleware tracing tạo span.** Span name là
   **route pattern** (`GET /api/v1/orders/:id`), không phải path đã điền id — path thật
   làm nổ cardinality của mọi hệ thống trace ở phía sau.
2. **Mọi lời gọi ra ngoài tiến trình đi qua wrapper có ghi cả latency histogram lẫn
   error counter.** DB, Redis, HTTP client, bus. Cấm gọi thẳng client gốc trong
   `modules/**`: một `http.Client{}` hoặc `redis.NewClient(` khai báo trong
   `modules/**` là vi phạm.
3. **Label metric chỉ lấy từ danh sách hằng khai báo tĩnh.** Cấm truyền `company_id`,
   `user_id`, hay bất kỳ id bản ghi nào vào `WithLabelValues(`. Kiểm được bằng grep tên
   biến đi vào lời gọi đó.
4. **Log trong `modules/**` lấy logger dẫn xuất từ `ctx`** (`log.FromContext(ctx)`),
   không gọi logger toàn cục (R-17); **tham số log chỉ là cặp key-value nguyên thủy**
   (R-16).
5. **Không nơi nào ngoài middleware của R-17 được sinh `request_id`.** Grep cả repo:
   chuỗi gán giá trị cho `request_id` chỉ được xuất hiện đúng một chỗ. Một
   `uuid.NewString()` cạnh chữ `trace` hay `request` ở bất kỳ file nào khác là dấu hiệu
   của id song song.
6. **Lỗi nghiệp vụ cấm đi vào `logger.Error(`.** Giá trị dựng từ bảng mã lỗi
   `shared/errors` mà xuất hiện làm tham số của `logger.Error(` là vi phạm.

```powershell
# 1) Sinh request_id/trace_id ngoai middleware cua R-17
Get-ChildItem -Path modules, shared -Recurse -Filter *.go |
    Where-Object { $_.FullName -notmatch '\\shared\\requestid\\' } |
    Select-String -Pattern 'uuid\.NewString\(\)|uuid\.New\(\)' |
    Where-Object { $_.Line -match '(?i)request|trace' } |
    ForEach-Object { "{0}:{1}: sinh id truy vet ngoai middleware R-17" -f $_.Path, $_.LineNumber }

# 2) Label metric co cardinality khong chan duoc
Get-ChildItem -Path modules, shared -Recurse -Filter *.go |
    Select-String -Pattern 'WithLabelValues\([^)]*(company_id|CompanyID|user_id|UserID|\w+ID)\b' |
    ForEach-Object { "{0}:{1}: id bien thien lam label metric -> chuyen sang span attribute" -f $_.Path, $_.LineNumber }

# 3) Goi thang client goc, khong qua wrapper co metric
Get-ChildItem -Path modules -Recurse -Filter *.go |
    Select-String -Pattern 'http\.Client\{|redis\.NewClient\(' |
    ForEach-Object { "{0}:{1}: goi ra ngoai khong qua wrapper co metric" -f $_.Path, $_.LineNumber }
```

```go
package handler

import (
	"errors"

	"github.com/gin-gonic/gin"

	"erp/shared/auth"
	apperr "erp/shared/errors"
	"erp/shared/log"
	"erp/shared/response"
)

func (h *OrderHandler) Approve(c *gin.Context) {
	ctx := c.Request.Context()
	// Logger dẫn xuất từ ctx: request_id đi kèm mọi dòng log mà không ai phải nhớ
	// truyền tay (R-17). Handler cấm gọi logger toàn cục.
	logger := log.FromContext(ctx)

	if err := h.svc.Approve(ctx, auth.FromContext(ctx), c.Param("id")); err != nil {
		var appErr *apperr.Error
		if errors.As(err, &appErr) {
			// LỖI NGHIỆP VỤ: hệ thống đang làm đúng việc của nó. Log ở Info và đếm
			// bằng counter theo mã lỗi. Đưa nó vào logger.Error nghĩa là dashboard
			// error rate phản ánh hành vi người dùng, và cảnh báo thành tiếng ồn.
			logger.Info("approve order bi tu choi", "code", appErr.Code, "order_id", c.Param("id"))
			// Label "code" lấy từ tập mã lỗi khai báo tĩnh — hữu hạn, an toàn cho
			// cardinality. order_id thì KHÔNG được làm label, nó chỉ nằm ở log.
			h.metrics.BusinessRejected.WithLabelValues("order.approve", appErr.Code).Inc()
			response.Error(c, err)
			return
		}
		// LỖI KỸ THUẬT: có người phải xử lý. Log Error, đầy đủ ngữ cảnh, và chỉ
		// cặp key-value nguyên thủy — không truyền struct hay con trỏ (R-16).
		logger.Error("approve order that bai", "order_id", c.Param("id"), "err", err.Error())
		response.Error(c, err)
		return
	}

	response.NoContent(c)
}
```

## Ca khó

### 1. Lỗi nghiệp vụ tăng đột biến — thứ này ai lo?

Sáng thứ hai, 40% request tạo đơn bị từ chối với mã `stock_not_available`. Không có
`Error` nào trong log vì đó là lỗi nghiệp vụ và ta đã cố tình để ở `Info`. Vậy ai phát
hiện?

Quyết: **counter theo mã lỗi, cảnh báo theo tỷ lệ, không phải theo mức log.** Đây chính
là lý do lỗi nghiệp vụ vẫn cần metric dù không cần mức `Error`: một mã lỗi tăng vọt là
tín hiệu vận hành thật (đồng bộ tồn kho hỏng, một job không chạy), chỉ là nó không
phải *lỗi kỹ thuật*. Đặt cảnh báo trên `rate(business_rejected{code="..."})` so với
đường nền, và cho nó đi vào kênh của đội nghiệp vụ chứ không phải kênh trực hệ thống —
người trực hệ thống không sửa được chuyện hết hàng.

Trường hợp ranh giới đáng chú ý: mã lỗi `internal_error` **không** phải lỗi nghiệp vụ
dù nó cũng đi qua bảng mã. Nó phải nằm trong cả hai chỗ: counter *và* log `Error`.

### 2. Muốn biết công ty nào đang chậm

Yêu cầu nghe rất hợp lý và cách làm hiển nhiên nhất là sai: thêm `company_id` vào label
của histogram latency. Với 200 công ty × 40 route × 12 bucket, một metric duy nhất sinh
gần một trăm nghìn chuỗi thời gian, và con số đó tăng mỗi lần có khách hàng mới — tức
là hệ thống đo lường đổ vỡ đúng vào lúc hệ thống nghiệp vụ thành công.

Ba đường đi, theo thứ tự nên thử:

1. **Trace trước.** `company_id` là span attribute, và backend trace lọc theo attribute
   được mà không nhân chuỗi thời gian. Trả lời được "công ty X chậm ở bước nào" — thường
   là câu hỏi thật đằng sau.
2. **Log aggregation cho top-N.** Latency đã có trong access log kèm `company_id`; một
   truy vấn top-N chạy theo yêu cầu rẻ hơn nhiều so với một chuỗi thời gian chạy liên
   tục 24/7 để phòng khi cần.
3. **Nếu thật sự phải có metric**, giới hạn tập giá trị: chỉ N công ty lớn nhất được
   giữ label riêng, còn lại gộp vào `other`. Danh sách N đó phải khai báo tĩnh và có
   người chịu trách nhiệm cập nhật — nếu không có ai thì đừng làm đường này.

### 3. Endpoint hạ tầng làm nhiễu số liệu

`/health` và `/ready` (R-13) bị gọi mỗi giây bởi Kubernetes. Chúng nhanh, luôn thành
công, và chiếm phần lớn tổng số request. Để chung với API nghiệp vụ thì p99 tổng thể
bị kéo xuống đẹp giả tạo, và tỷ lệ lỗi trông thấp hơn thực tế cả chục lần vì mẫu số bị
thổi phồng.

Quyết: **loại `/health`, `/ready`, `/metrics` khỏi metric latency và error rate của API
nghiệp vụ, nhưng vẫn đo chúng riêng** — `/ready` trả `503` là tín hiệu vận hành quan
trọng, chỉ là nó không thuộc cùng một biểu đồ. Cùng nguyên tắc áp cho hai chỗ khác hay
bị bỏ sót: request bị middleware auth chặn ở `401` (chưa chạm tới nghiệp vụ nên không
tính vào error rate nghiệp vụ, nhưng `401` tăng vọt lại là tín hiệu bảo mật đáng một
cảnh báo riêng), và các endpoint trả file (ngoại lệ của R-11) vốn có phân bố latency
khác hẳn nên trộn vào cùng histogram sẽ làm hỏng mọi bucket.
