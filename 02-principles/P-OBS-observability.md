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
   **`{method} {route pattern}`** (`GET /api/v1/orders/:id`), không phải path đã điền id
   — path thật làm nổ cardinality của mọi hệ thống trace ở phía sau. Hình dạng hai phần
   là **quy ước ngữ nghĩa HTTP của OpenTelemetry**, không phải sáng tạo riêng của dự
   án: tên span là trường hiển thị của mọi backend tracing, nên đặt khác quy ước nghĩa
   là span của repo này nằm lệch hẳn span do các thư viện có instrument sẵn chạy cạnh
   nó sinh ra. Method **không** vì thế mà rời khỏi thuộc tính: `http.request.method` vẫn
   được gắn, và `http.route` vẫn là route pattern **trần** — đó là trường để truy vấn
   lọc theo, và một truy vấn `http.route = "/api/v1/orders/:id"` không được phép vấp
   phải chuỗi có `GET ` dính đầu.

   Canh bằng **`TestMoiRouteV1SinhDungMotSpan`** ở `cmd/api` — test dựng router thật
   cộng một exporter span trong bộ nhớ, bắn một request qua từng route đọc được từ
   `r.Routes()` dưới `/api/v1`, và đếm span sinh ra. Không có ID trong bảng `arch/`:
   động từ của mệnh đề là **"chạy qua"** — một sự kiện xảy ra lúc thực thi — trong khi
   mọi checker tĩnh trong `arch/` chỉ đọc được hình dạng khai báo trong văn bản (route
   có `.Use(tracing)` hay không). Hình dạng khai đúng vẫn có thể sinh ra **0 span**
   (route đăng ký trước lời gọi `.Use()`, middleware `return` sớm trên một nhánh) — một
   checker tĩnh xanh trong ca đó là xanh giả, và không cơ chế nào của `arch/` phân biệt
   được "checker có gặp code" với "điều checker kết luận có đúng".

   **Ranh giới của test đó, đọc trước khi tin nó.** Nó tiêm nhà cung cấp span của chính
   nó, nên cái nó canh là *"**router** có nối middleware tracing vào mọi route dưới
   `/api/v1` không"* — **không** phải *"**tiến trình** có nối một exporter vào router
   không"*. Xóa dòng nối exporter khỏi `main.go` thì test này vẫn xanh. Và đó là trạng
   thái đúng chứ không phải một lỗ hổng: middleware cố ý làm "không cấu hình exporter"
   có nghĩa là *span vẫn được tạo, chỉ không có nơi đến* — cấu hình được là **nơi span
   đi tới**, không phải việc span có tồn tại hay không (`shared/middleware/tracing`).
   Vế "tiến trình có nối exporter không" có triệu chứng nhìn thấy được ở phía khác
   (không trace nào tới collector) và hôm nay **không test nào trong repo canh nó**;
   đóng được nó cần một test chạy `run()` thật với một collector OTLP giả, tức một test
   phụ thuộc cổng mạng và môi trường.
2. **Mọi lời gọi ra ngoài tiến trình đi qua wrapper có ghi cả latency histogram lẫn
   error counter.** DB, Redis, HTTP client, bus. Cấm gọi thẳng client gốc trong
   `modules/**`: một `http.Client{}` hoặc `redis.NewClient(` khai báo trong
   `modules/**` là vi phạm.
3. **Label metric chỉ lấy từ danh sách hằng khai báo tĩnh.** Cấm truyền `company_id`,
   `user_id`, hay bất kỳ id bản ghi nào vào `WithLabelValues(` **hoặc** vào dạng map
   `prometheus.Labels{...}` — hai API khác nhau, cùng một cách phá cardinality, nên một
   dấu hiệu chỉ khớp `WithLabelValues(` bỏ sót hoàn toàn nửa còn lại. Hai chỗ phải nhìn:
   chỗ **gọi** (tên biến đi vào lời gọi) và chỗ **khai**
   (`NewCounterVec(..., []string{"company_id"})`) — bắt ở chỗ khai rẻ hơn và chắc hơn
   rải rác bắt tại từng chỗ gọi, vì một giá trị chỉ nổ cardinality khi **có** một nhãn
   để nó đi vào. Cả hai chỗ đều đòi giải hằng, nên cả hai đều là việc của checker
   `HC-03` chứ không của grep — xem ghi chú cuối mục này.

   **Độ chặt khác nhau theo vị trí, và đó là một sự thật kiến trúc chứ không phải một
   thỏa hiệp.** Checker `HC-03` quét **cả `modules/**` lẫn `shared/**`**, nhưng hỏi hai
   câu hỏi khác nhau ở hai nơi — vì mệnh đề "chỉ lấy từ hằng khai báo tĩnh" đúng ở nơi
   này và sai ở nơi kia:

   - **Trong `modules/**` — danh sách trắng.** Mọi đối số phải là hằng chuỗi khai tĩnh;
     `x.CompanyID`, một lời gọi hàm, một biến tham số đều là vi phạm. Ở đây phép thử
     chặt nhất có **đúng 0 khả năng bắt oan**, vì ở đây **không lời gọi dựng nhãn nào
     được phép tồn tại**: module cần đếm thêm thứ gì thì thêm một method vào
     `shared/metrics`, và module không được import `prometheus` (hard check 2).
   - **Trong `shared/**` — danh sách đen theo tên.** Dựng nhãn **là** việc hợp lệ ở
     đây: `shared/metrics` chính là tầng wrapper, chỗ duy nhất được phép dựng nhãn (xem
     đầu `shared/metrics/metrics.go`). Nhãn `route` của nó đến từ `c.FullPath()` — một
     **lời gọi hàm** lúc chạy, không phải hằng đọc được lúc biên dịch. Chạy danh sách
     trắng lên đó cho **9 vi phạm trên 9 đối số**, tức 100% bắt oan đúng dòng code mà
     nó có nhiệm vụ bảo vệ. Nên ở đây checker chỉ hỏi hai câu hẹp hơn và đo được: **tên
     nhãn** không được là tên một id (đọc tại chỗ khai `NewXVec` và tại khóa của
     `prometheus.Labels`), và **giá trị** đi vào nhãn không được mang tên một id bản
     ghi.

   Bất biến **thật** của mệnh đề này không phải "đối số là hằng" — đó chỉ là cách kiểm
   rẻ nhất **khi kiểm được** — mà là **cardinality bị chặn**, và cardinality bị chặn ở
   đúng **một cổng** bên trong `shared/metrics`: hàm `nhanRouteCua()` luôn trả
   `c.FullPath()`, với nhánh mặc định là một **hằng** (`khong_khop`), không bao giờ là
   path thật đã điền id.

   Cái giá phải nói thẳng: arm `shared/**` là danh sách **đen theo tên**, nên một
   `WithLabelValues` sai viết ngay trong `shared/metrics` mà **không mang tên một id**
   sẽ đi qua sạch sẽ — ví dụ lỡ đổi `nhanRouteCua(c)` thành `c.Request.URL.Path`.
   Chuỗi đó nổ cardinality y hệt `company_id` và không tên nào trong nó đọc ra là một
   id. Thứ canh đúng chỗ đó là một test lúc chạy:
   **`TestNhanRouteLaRoutePatternChuKhongPhaiPathThat`** (`shared/metrics`), bắn ba
   request mang ba id khác nhau và khẳng định cả ba gộp vào đúng **một** chuỗi thời
   gian, không phải ba — cùng hình dạng "checker tĩnh xanh nhưng kết luận có thể sai"
   mà mục 3 của spec thiết kế chặng F đã nêu cho HC-1.

   **Script `2b` bên dưới không phải thứ canh mệnh đề này — checker `HC-03` mới là.**
   Nhãn trong code thật khai bằng **hằng có tên**, và trả lời "tên hằng này mang giá trị
   gì" đòi một bước **giải hằng** mà grep không làm được; `HC-03` gom `const` cấp
   package rồi so khớp trên giá trị đã giải, grep thì so khớp trên văn bản dòng code.
   Script giữ lại làm **minh họa** cho hình dạng chuỗi literal, và **0 dòng của nó không
   phải bằng chứng sạch**.
4. **Log trong `modules/**` lấy logger dẫn xuất từ `ctx`** (`log.FromContext(ctx)`),
   không gọi logger toàn cục (R-17); **tham số log chỉ là cặp key-value nguyên thủy**
   (R-16).

   Canh bằng **R-16** (nửa "tham số log chỉ là cặp key-value nguyên thủy") và **R-17**
   (nửa "logger dẫn xuất từ `ctx`" — hàm `loggerToanCuc`, phạm vi nới ra `modules/**` ở
   chặng F). Không có dòng `HC-04` riêng trong bảng `arch/`: bảng `hardChecks` trong
   `arch/rules.go` khai rõ điều đó, và `TestHardCheckKhaiDungBang` canh nó.
5. **Không nơi nào ngoài middleware của R-17 được sinh `request_id`, trong code sản
   xuất.** **Việc SINH** ra giá trị chỉ được xuất hiện đúng một chỗ (`shared/requestid`).
   Chính cái TÊN `request_id` thì ngược lại — nó phải xuất hiện ở mọi tầng tiêu thụ và
   phải giống hệt nhau: `shared/log` đặt nó làm trường log, `shared/middleware/tracing`
   đặt nó làm thuộc tính span, subscriber đọc nó ra khỏi payload event (P-EVT). Dấu hiệu
   vi phạm là một tên THỨ HAI cho cùng một id (`trace_id`, `correlation_id`, `req_id`,
   `X-Trace-Id`), hoặc một chỗ thứ hai GHI header `X-Request-Id` — không phải sự có mặt
   của chính chữ `request_id`. Một `uuid.NewString()` cạnh chữ `trace` hay `request` ở
   bất kỳ file sản xuất nào khác cũng là dấu hiệu của id song song. Dữ liệu giả gán cho
   một trường tên `RequestID` trong fixture test không phải id song song — nó không đi
   vào middleware nào cả — nên script phải loại `_test.go` trước khi kết luận. Canh bằng
   `HC-05` trong `backend-erp/arch/`.
6. **Lỗi nghiệp vụ cấm đi vào `logger.Error(`.** Giá trị dựng từ bảng mã lỗi
   `shared/errors` mà xuất hiện làm tham số của `logger.Error(` là vi phạm.

   **Không canh được bằng máy — cố ý, không phải chưa làm.** Hình dạng hẹp bắt được
   (`errors.As(err, &appErr)` rồi gọi `.Error` trong thân `if`) sẽ **bắt oan** đúng ca
   mà chính Ca khó 1 dưới đây nói là đúng: `internal_error` cũng dựng từ bảng mã lỗi,
   cũng đi qua `errors.As`, và checker tĩnh không phân biệt được lúc đọc code
   `appErr.Code == CodeInternal` với một mã nghiệp vụ khác — cả hai chỉ là cùng một
   hình dạng `errors.As` + `.Error`. Bắt oan ở đây là **cố hữu của mệnh đề**, không
   phải lỗi hiện thực sửa được bằng viết checker khéo hơn, nên câu trả lời trung thực
   là không viết nó. Xét bằng người, đối chiếu với Ca khó 1.

```powershell
# 1) Sinh request_id/trace_id ngoai middleware cua R-17. Loai _test.go: du lieu gia
# gan cho mot truong ten RequestID trong fixture test khong phai id song song - no
# khong di vao middleware nao ca (xem shared/audit/postgres_db_test.go).
Get-ChildItem -Path cmd, modules, shared, relay -Recurse -Filter *.go |
    Where-Object { $_.FullName -notmatch '\\shared\\requestid\\' -and $_.Name -notmatch '_test\.go$' } |
    Select-String -Pattern 'uuid\.NewString\(\)|uuid\.New\(\)' |
    Where-Object { $_.Line -match '(?i)request|trace' } |
    ForEach-Object { "{0}:{1}: sinh id truy vet ngoai middleware R-17" -f $_.Path, $_.LineNumber }

# 2) Label metric co cardinality khong chan duoc - hai hinh dang goi khac nhau:
# WithLabelValues( va dang map prometheus.Labels{...}
Get-ChildItem -Path modules, shared -Recurse -Filter *.go |
    Select-String -Pattern 'WithLabelValues\([^)]*(company_id|CompanyID|user_id|UserID|\w+ID)\b|prometheus\.Labels\{[^}]*(company_id|CompanyID|user_id|UserID|\w+ID)\b' |
    ForEach-Object { "{0}:{1}: id bien thien lam label metric -> chuyen sang span attribute" -f $_.Path, $_.LineNumber }

# 2b) Ten label la id, khai ngay tai cho dung metric: []string{"company_id", ...}.
#
# GIOI HAN - doc truoc khi tin ket qua 0 dong. Script nay chi thay CHUOI LITERAL, va
# grep KHONG the lam hon the: code that cua shared/metrics khai nhan bang HANG CO TEN
# ([]string{nhanMethod, nhanRoute, nhanStatus}), nen tra loi "ten nhan nay co phai ten
# mot id khong" doi mot buoc GIAI HANG ma PowerShell khong lam duoc. Ban truoc cua
# script nay con doi ca "NewXVec(" nam cung dong voi "[]string{" - hai thu do o code
# that cach nhau sau dong - nen no tra 0 dong va se MAI tra 0 du co mot hang
# nhanCongTy = "company_id" nam ngay canh. Dung loai loi ma script 5 da mac.
#
# Thu CANH menh de nay la checker HC-03 (backend-erp/arch/checks_metrics.go): no gom
# const cap package roi so khop tren GIA TRI DA GIAI, o ca cho khai lan cho goi. Script
# duoi day chi con la MINH HOA cho hinh dang literal - hinh dang nguoi moi viet dau
# tien - chu khong phai thu canh menh de.
Get-ChildItem -Path modules, shared -Recurse -Filter *.go |
    Where-Object { $_.Name -notmatch '_test\.go$' } |
    Select-String -Pattern '\[\]string\{[^}]*"(\w+_)?id(_\w+)?"' |
    ForEach-Object { "{0}:{1}: ten label bien thien khai bang chuoi literal -> bo khoi danh sach []string" -f $_.Path, $_.LineNumber }

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
			//
			// GhiNhanTuChoiNghiepVu là một METHOD của shared/metrics (h.metrics có kiểu
			// *metrics.Registry, không phải *prometheus.CounterVec lộ thẳng ra ngoài).
			// Handler KHÔNG được tự gọi WithLabelValues, và module KHÔNG import
			// "github.com/prometheus/client_golang/prometheus": nhãn chỉ được dựng bên
			// trong shared/metrics — nơi DUY NHẤT được phép biết tới prometheus (P-OBS
			// hard check 2 và 3; xem đầu shared/metrics/metrics.go). Module cần đếm
			// thêm thứ gì thì thêm một method vào đó, đúng khuôn wrapper DB và wrapper
			// HTTP client dùng.
			h.metrics.GhiNhanTuChoiNghiepVu("order.approve", appErr.Code)
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
