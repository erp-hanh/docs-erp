# ADR-0006: Event bus nội bộ với outbox pattern

**Status:** Accepted (2026-08-10)

## Context

[ADR-0001](ADR-0001-modular-monolith.md) chốt rằng module chỉ chạm nhau qua `api/`, và
chỉ những module có tên trong `allowed_deps` mới được gọi thẳng. Phần còn lại — việc
phụ, việc mà bên phát không cần biết ai nghe, việc mà danh sách người quan tâm còn mở
— phải đi qua event. Câu hỏi của ADR này là **cơ chế** phát event đó.

Ràng buộc quyết định tất cả: **dữ liệu nghiệp vụ và event phải cùng sống hoặc cùng
chết.** Duyệt một đơn hàng ghi vào bảng `orders` và phát `order.approved`. Nếu hai
việc đó không nguyên tử với nhau thì có hai kiểu hỏng, và cả hai đều tệ theo cách khó
phát hiện: event bay ra cho một đơn cuối cùng không được duyệt, hoặc đơn được duyệt mà
không ai biết.

Hạ tầng lúc đó: PostgreSQL đã có và đã được tin cậy cho dữ liệu nghiệp vụ. Chưa có
Kafka, chưa có RabbitMQ, chưa có ai vận hành chúng. Lưu lượng event dự kiến ở mức
hàng nghìn mỗi ngày, không phải hàng nghìn mỗi giây.

## Decision

**Service ghi event vào bảng `outbox` trong cùng transaction với dữ liệu nghiệp vụ;
một relay riêng, nằm ngoài `modules/`, đọc `outbox` và publish ra bus sau khi
transaction đã commit.**

Hệ quả trực tiếp về vị trí code: service **không bao giờ** gọi `bus.Publish` — không
trong transaction, không sau `tx.Commit()`, không qua `defer`. Chỉ relay publish. Đó
là R-05, và nó được viết thành mệnh đề grep được chính vì ba biến thể sai ở trên đều
trông hợp lý khi đọc lướt.

## Alternatives

**Publish thẳng trong transaction** — loại. Bus không tham gia transaction của
PostgreSQL, nên `Publish` thành công rồi transaction rollback là ca hoàn toàn bình
thường: một `UPDATE` sau đó vi phạm ràng buộc, hoặc deadlock, hoặc một lỗi nghiệp vụ ở
bước cuối. Kết quả là consumer xử lý một sự việc **chưa từng xảy ra** — đơn hàng chưa
duyệt đã bị trừ kho, và không có gì trong hệ thống mâu thuẫn để phát hiện ra điều đó.

**Publish ngay sau commit, không qua outbox** — loại. Đây là bài toán **dual write**
kinh điển và nó không có lời giải ở dạng này: giữa `tx.Commit()` thành công và lời gọi
`Publish` có một khoảng, và nếu tiến trình chết trong khoảng đó thì event mất **vĩnh
viễn**. Không có gì để thử lại, vì không còn dấu vết nào cho thấy đáng lẽ phải có một
event. Kiểu hỏng này hiếm — nên nó sẽ vượt qua mọi vòng test và xuất hiện lần đầu vào
lúc deploy trùng với giờ cao điểm.

**Message broker có transaction phân tán (XA / two-phase commit)** — loại. Về lý
thuyết nó giải đúng bài toán, nhưng đổi lại một transaction coordinator phải vận hành,
một trạng thái mới phải hiểu (transaction in-doubt khi coordinator chết), và hiệu năng
ghi giảm đáng kể trên mọi thao tác — kể cả những thao tác không phát event nào. Độ
phức tạp không tương xứng với quy mô ở mục Context, và số người trong đội hiểu được
cách gỡ một transaction in-doubt lúc 2 giờ sáng là con số không.

**Change Data Capture đọc WAL của PostgreSQL** — loại. Nó cũng bảo đảm không mất event
và không cần bảng trung gian, nhưng event sinh ra từ WAL là *thay đổi hàng dữ liệu*,
không phải *sự việc nghiệp vụ*: consumer sẽ phải suy ngược từ "cột status đổi từ 1
sang 2" ra "đơn hàng được duyệt", tức là dựng lại ý nghĩa mà bên phát vốn đã biết.
Cộng thêm một hạ tầng nữa phải vận hành.

## Consequences

**Được:**

- **Một transaction duy nhất quyết cả dữ liệu lẫn event.** Rollback thì cả hai cùng
  biến mất; commit thì event chắc chắn có mặt và chắc chắn sẽ được gửi.
- `outbox` là hàng đợi bền. Bus chết thì event nằm chờ trong bảng, không mất; bus sống
  lại thì relay đuổi kịp mà không cần ai can thiệp.
- Không thêm hạ tầng nào ở giai đoạn đầu: bảng `outbox` là một bảng PostgreSQL bình
  thường, kiểm được bằng `SELECT`, gỡ lỗi được bằng cách nhìn vào nó.
- Đổi bus về sau chỉ đụng relay, không đụng bất kỳ dòng nào trong `modules/`.

**Mất:**

- Event tới **trễ hơn** thời điểm commit, trễ đúng bằng chu kỳ quét của relay. Mọi
  luồng dựa trên event là eventual consistency, và UI phải hiển thị được trạng thái
  "đang xử lý" thay vì giả vờ nó không tồn tại.
- Thêm một tiến trình phải triển khai, giám sát và cảnh báo. Relay chết mà không ai
  biết thì hệ thống vẫn nhận request bình thường trong khi mọi việc phụ ngừng chạy —
  kiểu hỏng im lặng, nên độ trễ và độ dài hàng đợi của `outbox` phải có metric.
- `outbox` là điểm ghi nóng dùng chung của mọi module: mọi thao tác phát event đều
  `INSERT` vào cùng một bảng.

**Nợ để lại:**

- **Relay là at-least-once, và đây là điều kiện để quyết định này đứng vững, không
  phải khuyến nghị.** Relay có thể chết sau khi `Publish` thành công nhưng trước khi
  đánh dấu bản ghi đã gửi; lần chạy sau nó gửi lại. Vì vậy **mọi event handler phải
  idempotent theo `event_id`**
  ([P-IDEM-idempotency.md](../02-principles/P-IDEM-idempotency.md)). Bỏ điều kiện này
  thì mô hình **sai**, chứ không phải kém tối ưu: một handler trừ kho không idempotent
  sẽ trừ hai lần cho một lần duyệt đơn, và sổ sách sai mà không có gì báo lỗi. Kéo
  theo: `event_id` sinh **một lần** lúc ghi `outbox` và giữ nguyên qua mọi lần gửi lại
  — relay sinh id mới là làm vô hiệu toàn bộ cơ chế dedupe phía consumer.
- **Relay phải đọc `outbox` bằng `SELECT ... FOR UPDATE SKIP LOCKED`.** Không có nó,
  hai instance relay chạy song song sẽ đọc trúng cùng những hàng chưa gửi và **nhân
  đôi mọi event**. `SKIP LOCKED` là thứ khiến hai instance chia nhau công việc thay vì
  chờ nhau hoặc dẫm lên nhau. Đây là chi tiết cài đặt duy nhất được nâng lên tầng
  Decision, vì bỏ sót nó không gây lỗi ở môi trường một instance — nó chỉ lộ ra khi ai
  đó nhân bản relay lên để "cho chắc".
- `outbox` cần job dọn theo lịch giữ liệu, nếu không bảng phình vô hạn. Nó nằm trong
  `append_only_tables` ([ADR-0003](ADR-0003-multi-tenant-ready.md)) nên được **hard
  delete không cần ADR riêng**; việc còn lại chỉ là chốt hạn giữ và viết job.
- Chưa chọn bus cụ thể. Giai đoạn đầu bus có thể nằm trong tiến trình; đổi sang bus
  ngoài là quyết định của một ADR sau, và nó chỉ đụng relay.
- Chưa có xử lý cho event gửi hỏng liên tục: cần giới hạn số lần thử và một chỗ chứa
  dead-letter, cùng cách báo người.

**Constrains:** R-05
