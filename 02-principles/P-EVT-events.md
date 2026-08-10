# P-EVT — Events

**Câu hỏi nó trả lời:** Khi nào chọn event thay vì gọi trực tiếp?
**Rules:** R-05
**Decisions:** ADR-0006

## Cách suy luận

### Trang này khác R-05 chỗ nào

Hai thứ này nói về cùng một cơ chế nhưng trả lời hai câu hỏi không giao nhau:

| | R-05 | P-EVT |
|---|---|---|
| Trả lời | **Được phép gọi ai**, và ghi outbox thế nào | **Khi nào nên chọn event** dù gọi trực tiếp vẫn hợp lệ |
| Căn cứ | `allowed_deps` trong `module.yaml`; vị trí lời gọi trong code | Bản chất nghiệp vụ của việc cần làm |
| Kiểm bằng | Máy — đọc một file `module.yaml` và một diff là xong | Người — phải hỏi nghiệp vụ mới trả lời được |
| Sai thì sao | CI đỏ | CI xanh, hệ thống chạy, và ba tháng sau không ai gỡ nổi hai module ra khỏi nhau |

Cụ thể: nếu module Inventory **không** có tên trong `allowed_deps` của Order thì R-05
đã quyết thay bạn — bắt buộc đi qua event, không có gì để cân nhắc. Trang này chỉ có
việc khi Inventory **có** tên trong đó: gọi thẳng không vi phạm Rule nào cả, nhưng vẫn
có thể là lựa chọn sai. R-05 là biên dưới — *không được làm gì*. P-EVT là cách chọn bên
trong phần còn được phép. Hai trang không chồng nhau và không trang nào thay được trang
kia.

### Ba câu hỏi để quyết

1. **Việc này có phải điều kiện để hành động chính được coi là thành công không?**
   Cách hỏi cho ra câu trả lời dứt khoát: *"nếu việc kia hỏng, thao tác này còn được
   coi là đã xong không?"* Có → gọi trực tiếp, trong cùng transaction. Không → event.
   Đây là câu hỏi **nghiệp vụ**, phải hỏi người dùng, không phải câu hỏi kỹ thuật để
   lập trình viên tự quyết trong lúc code.
2. **Người gọi có cần kết quả trả về không?** Cần → gọi trực tiếp. Event không có đường
   trả lời; dựng một event "phản hồi" để chờ nó là đang cài đặt lại RPC bằng hai bảng và
   một vòng lặp, chậm hơn và khó gỡ hơn.
3. **Danh sách người quan tâm có mở không?** Hôm nay một module nghe, mai thêm module
   thứ ba, và bên phát **không cần biết** ai nghe → event. Nếu danh sách đóng và sẽ mãi
   là một người nghe thì event chỉ thêm một tầng gián tiếp không đổi lấy được gì.

### Đặt tên và hình dạng payload

Event là **một sự việc đã xảy ra**, thì quá khứ: `order.approved`, `stock.reserved`.
Không phải mệnh lệnh: `send_email`, `reserve_stock`. Đây không phải chuyện thẩm mỹ —
một cái tên mang động từ mệnh lệnh là bằng chứng bên phát đang biết bên nhận phải làm
gì, tức là nó vừa cài đặt một lời gọi hàm bằng cơ chế đắt hơn nhiều lần. Thử lại bằng
câu hỏi: *nếu ngày mai xóa hết consumer, cái tên này còn nghĩa không?* `order.approved`
còn. `send_email` thì không.

**Payload là hợp đồng.** Mọi field đưa vào là một cam kết giữ lâu dài với những
consumer bạn chưa biết tên. Vì vậy đưa vào ít nhất có thể: id, và đúng những field
consumer *thật sự* cần.

**Vì sao cấm nhét nguyên entity vào payload.** Payload là **hợp đồng**; entity là **chi
tiết nội bộ** của module phát. Nhét cả entity vào là công bố toàn bộ model nội bộ thành
API công khai, và hệ quả rất cụ thể: mọi lần đổi struct nội bộ — đổi tên field, đổi
kiểu, tách bảng, bỏ một cột không ai dùng — đều thành **breaking change cho mọi
consumer**, kể cả những consumer không hề đụng tới field đó. Module phát mất quyền
refactor chính mình. Tệ hơn, nó âm thầm: không ai báo lỗi lúc merge, chỉ có một
consumer nào đó ngừng chạy đúng vào lúc không ai nhìn. Cùng lý do đó, entity thường
mang theo field nhạy cảm (giá vốn, thông tin cá nhân) mà consumer không có quyền thấy,
nên nhét nguyên entity còn kéo theo cả rủi ro R-16.

### Cái giá phải trả

Chọn event là chọn đánh đổi, và ba khoản dưới đây phải trả bằng công sức thật:

- **Nhất quán trở thành eventual.** Có một khoảng thời gian dữ liệu hai bên không khớp,
  và UI phải hiển thị được trạng thái đó ("đang xử lý") thay vì giả vờ nó không tồn tại.
- **At-least-once (ADR-0006).** Relay gửi lại khi nó chết giữa `Publish` và
  `MarkPublished`, nên **mọi** consumer phải idempotent theo `event_id`
  ([P-IDEM-idempotency.md](P-IDEM-idempotency.md)). Đây là điều kiện tiên quyết, không
  phải phần tối ưu làm sau.
- **Gỡ lỗi khó hơn.** Chuỗi nhân quả bị cắt làm hai ở ranh giới bus. Vì vậy `request_id`
  của request đã sinh ra event phải đi kèm event — lấy từ `ctx` lúc ghi outbox, và
  relay **cấm sinh mới** (R-17 sở hữu giá trị này,
  [P-OBS-observability.md](P-OBS-observability.md)).

## Hard check

1. **Payload chỉ chứa giá trị nguyên thủy.** File định nghĩa payload cấm import package
   `model` của bất kỳ module nào; cấm field kiểu `model.X`, `*model.X`, hay `[]model.X`.
   Đây là vế "cấm nhét nguyên entity" viết thành thứ grep được.
2. **Mọi payload có đủ `event_id`, `occurred_at`, `company_id`.** Struct payload thiếu
   một trong ba là vi phạm. `event_id` sinh **một lần** lúc ghi outbox và giữ nguyên qua
   mọi lần relay gửi lại (R-05, ADR-0006) — relay sinh id mới là làm vô hiệu toàn bộ
   dedupe phía consumer.
3. **Payload immutable trên đường đi.** Nó qua ranh giới dưới dạng bytes đã marshal
   (`json.RawMessage` trong `outbox.Event`), không phải con trỏ tới một struct còn sống.
   Cụ thể: cấm field kiểu con trỏ trong struct payload, và cấm method nhận con trỏ
   (`func (e *XPayload)`) làm thay đổi field.
4. **Tên event lấy từ danh sách hằng khai báo tĩnh.** Cấm truyền chuỗi literal vào
   trường `EventType` của `outbox.Event`; giá trị phải là một hằng trong `shared/outbox`.
   Chuỗi literal rải trong service là cách nhanh nhất để có hai cái tên cho cùng một sự
   việc, và không có gì phát hiện được điều đó.
5. **Xóa hoặc đổi kiểu một field của payload đang dùng là breaking change**, xử như đổi
   DTO response ở R-13: thêm phiên bản event mới (`order.approved.v2`) và giữ bản cũ cho
   tới khi mọi consumer chuyển xong. Thêm field mới thì được, vì consumer cũ bỏ qua field
   nó không biết.

```powershell
# 1) Payload nhet nguyen entity
Get-ChildItem -Path shared/outbox -Recurse -Filter *.go |
    Select-String -Pattern '\s\*?\[?\]?model\.\w+' |
    ForEach-Object { "{0}:{1}: payload nhung entity -> chi id va field consumer that su can" -f $_.Path, $_.LineNumber }

# 2) Payload thieu field bat buoc
Get-ChildItem -Path shared/outbox -Recurse -Filter *.go | ForEach-Object {
    $raw = Get-Content -Path $_.FullName -Raw
    foreach ($m in [regex]::Matches($raw, '(?s)type (\w*Payload) struct \{(.*?)\n\}')) {
        foreach ($f in @('event_id', 'occurred_at', 'company_id')) {
            if ($m.Groups[2].Value -notmatch $f) {
                "{0}: {1} thieu {2}" -f $_.FullName, $m.Groups[1].Value, $f
            }
        }
    }
}

# 3) EventType nhan chuoi literal thay vi hang
Get-ChildItem -Path modules -Recurse -Filter *_service.go |
    Select-String -Pattern 'EventType:\s*"' |
    ForEach-Object { "{0}:{1}: ten event la chuoi literal -> dung hang trong shared/outbox" -f $_.Path, $_.LineNumber }
```

```go
// erp/shared/outbox/events/order.go
package events

import "time"

// Danh sách đóng của tên event. Trường EventType của outbox.Event chỉ được nhận giá
// trị từ đây; chuỗi literal rải trong service là cách nhanh nhất để có hai cái tên
// cho cùng một sự việc.
const (
	OrderApproved  = "order.approved"
	OrderCancelled = "order.cancelled"
)

// OrderApprovedPayload là HỢP ĐỒNG với consumer, không phải ảnh chụp của model.Order.
// Chỉ giá trị nguyên thủy: không con trỏ, không nhúng model. Nhúng model nghĩa là mọi
// lần đổi struct nội bộ đều thành breaking change cho mọi consumer.
type OrderApprovedPayload struct {
	// Bốn field bắt buộc của mọi payload.
	EventID    string    `json:"event_id"`
	OccurredAt time.Time `json:"occurred_at"`
	CompanyID  string    `json:"company_id"`
	// RequestID lấy từ ctx lúc ghi outbox — R-17 sở hữu giá trị này, relay cấm sinh
	// mới. Thiếu nó thì không nối được event với request đã sinh ra nó.
	RequestID string `json:"request_id"`

	// Phần riêng của sự việc: id, và đúng những field consumer thật sự cần.
	OrderID    string `json:"order_id"`
	CustomerID string `json:"customer_id"`
	ApprovedBy string `json:"approved_by"`

	// AggregateVersion cho consumer bỏ qua event đến muộn hơn thứ tự: đã xử lý
	// version 5 thì version 4 tới sau là bản cũ, bỏ.
	AggregateVersion int64 `json:"aggregate_version"`
}
```

## Ca khó

### 1. Khi nào việc là "phụ" đủ để dùng event

Duyệt một đơn hàng kéo theo hai việc: **giữ tồn kho** và **gửi email cho khách**. Email
thì rõ — luôn là việc phụ, không ai coi đơn là chưa duyệt vì SMTP treo. Giữ tồn kho mới
là chỗ phải hỏi, và câu trả lời **không nằm trong code**:

- Nghiệp vụ nói *"duyệt xong mà không đủ hàng thì không được duyệt"* → đây là **điều
  kiện**, phải đồng bộ. Kéo theo: Inventory phải có tên trong `allowed_deps` của Order
  (R-05); và nếu còn đòi atomic thật sự thì phải chia sẻ `DBTX` giữa hai module, thứ mà
  bộ Rule hiện tại chưa mở đường —
  [P-TXN-transaction-boundary.md](P-TXN-transaction-boundary.md) ca khó số 3 nói rõ chỗ
  vướng và kết luận là dừng lại hỏi người.
- Nghiệp vụ nói *"duyệt trước, thiếu hàng thì mua bổ sung"* → **phụ**, dùng event, và
  bài toán tan biến.

Ca đáng chú ý nhất là khi câu trả lời là "điều kiện" **nhưng** Inventory không có tên
trong `allowed_deps`. Lúc đó đây không còn là chuyện chọn event hay gọi thẳng: nghiệp
vụ đang đòi một ràng buộc atomic mà ranh giới module hiện tại không đỡ nổi. Sửa bằng
một ADR đổi ranh giới, **không** sửa bằng cách "tạm dùng event rồi tính sau" — vì sẽ có
lúc không nhất quán, và lúc đó không ai xử lý. Đây là chỗ một Principle chỉ ngược lên
tầng Decision thay vì tự quyết.

### 2. Event có nên mang trạng thái trước và sau không

Cám dỗ: nhét cả `old` và `new` vào để consumer khỏi phải hỏi lại. Nó tiện đúng một lần,
rồi thành gánh nặng vĩnh viễn — payload phình gấp đôi, và mỗi field trong `old` cũng là
một cam kết y như trong `new`.

Quyết: **chỉ mang trước-và-sau của những field mà chính sự việc nói về.**
`order.status_changed` mang `from` và `to`; nó không mang toàn bộ ảnh chụp đơn hàng.
Nếu consumer cần nhiều hơn thế, một trong hai điều sau đang đúng và cả hai đều có cách
sửa tốt hơn việc phình payload:

- **Sự việc đang bị đặt tên quá chung.** `order.updated` buộc consumer phải tự đoán cái
  gì đã đổi, nên nó cần cả snapshot. Tách thành các sự việc cụ thể —
  `order.status_changed`, `order.line_items_changed` — thì mỗi consumer chỉ nghe thứ nó
  quan tâm và payload nhỏ lại tự nhiên.
- **Consumer thật sự cần một truy vấn**, không phải một event. Truy vấn thì đi qua
  `api/` của module chủ (R-01), không đi qua payload. Đánh đổi ở đây là rõ ràng: một
  lời gọi thêm, đổi lấy việc không phải giữ hợp đồng cho những field không ai chắc có
  ai dùng.

### 3. Event đến không đúng thứ tự

Relay dừng cả batch khi gặp lỗi để giữ thứ tự trong một aggregate, nhưng đó là bảo đảm
của *một* relay đang chạy. Với nhiều instance, nhiều partition, hoặc consumer xử lý song
song, không có gì bảo đảm tuyệt đối — và một consumer nhận `order.shipped` trước
`order.created` sẽ hỏng theo cách rất khó dò.

Ba mức xử lý, theo thứ tự nên thử:

1. **Thiết kế handler không phụ thuộc thứ tự khi có thể.** Dùng giá trị tuyệt đối thay
   cho delta: `set_reserved_qty = 5` chịu được mọi thứ tự, `reserved_qty += 2` thì không.
   Đây là cách rẻ nhất và bền nhất.
2. **Khi thật sự phụ thuộc thứ tự, mang số thứ tự đơn điệu của aggregate** trong payload
   (`aggregate_version`) và bỏ qua event có version nhỏ hơn hoặc bằng cái đã xử lý. Chú
   ý phân biệt với dedupe theo `event_id`: `event_id` chặn *cùng một* event tới hai lần,
   `aggregate_version` chặn *event cũ* tới sau event mới. Cần cả hai, chúng không thay
   nhau được.
3. **Event đến quá sớm** — `order.shipped` tới trong khi consumer chưa từng thấy
   `order.created`, thường vì consumer mới được bật lên. Xử lý bằng cách nack có chủ
   đích để bus gửi lại sau, kèm giới hạn số lần; hết lần thì đẩy vào dead-letter và báo
   người. Không bao giờ giải bằng `sleep` rồi thử lại trong chính handler: nó giữ một
   worker, làm chậm mọi event phía sau, và biến một sự cố nhỏ thành tắc nghẽn toàn hệ
   thống.
