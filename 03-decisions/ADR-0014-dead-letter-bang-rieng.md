# ADR-0014: Dead-letter là bảng riêng, không thêm cột vào `outbox`

**Status:** Accepted (2026-08-14)

## Context

[ADR-0006](ADR-0006-event-bus-outbox.md) chốt outbox pattern và để lại một khoản nợ
tường minh ở mục Nợ để lại: *"Chưa có xử lý cho event gửi hỏng liên tục: cần giới hạn
số lần thử và một chỗ chứa dead-letter, cùng cách báo người."* Bốn chặng sau, khoản nợ
đó vẫn mở.

Migration `000009_create_outbox.up.sql` — viết sau ADR-0006 — đi xa hơn ADR đó một
bước: nó chốt **có chủ đích** rằng `outbox` là bảng chỉ ghi thêm với đúng MỘT ngoại lệ
ghi lại, và giải thích lý do ngay trong comment của chính nó (dòng 99–108):

> *"KHONG co cot status, va do la quyet dinh chu khong phai thieu sot.
> `published_at IS NULL` la TOAN BO trang thai cua mot hang outbox, va trang thai do
> chi doi dung mot lan theo mot chieu. Mot cot status se la ban THU HAI cua cung mot su
> that - va hai ban thi lech: se co ngay mot hang mang status = 'published' voi
> published_at NULL, va khong ai tra loi duoc hang do da gui hay chua. [...] Day cung
> la ngoai le duy nhat cua "mot lan ghi duy nhat" o tren, va no la ngoai le hep dung
> bang mot cot: relay UPDATE published_at tu NULL sang mot gia tri, khong bao gio
> nguoc lai va khong bao gio dung toi cot nao khac."*

Cùng migration, ở phần đầu file, giải thích vì sao bảng nói chung chỉ chấp nhận một lần
ghi cho mỗi hàng: nó thuộc `append_only_tables` của registry `C-DB-04`, được miễn
`updated_at`/`updated_by`/`deleted_at`, và "vì không có `updated_at`, mọi thứ cần ghi
phải được ghi trong MỘT lần ghi duy nhất."

Một dead-letter đúng nghĩa cần trạng thái **biến thiên nhiều lần** trên cùng một sự
việc: số lần đã thử lại (`attempts`, tăng mỗi lần relay thử publish và thất bại), lỗi
gần nhất (`last_error`, đổi giá trị ở mỗi lần thử), và thời điểm chuyển sang dead-letter.
Đây không phải một lần ghi lại như `published_at` — nó là một chuỗi ghi lại nhiều lần
trên cùng một hàng, đúng hình dạng mà migration `000009` đã cân nhắc dưới tên "cột
status" và từ chối bằng văn bản.

Spec thiết kế chặng này (mục 2, "KHÔNG làm") nêu thêm một lý do cụ thể: job dọn `outbox`
(chặng G, và **phải sau** dead-letter) cần biết trước **tập trạng thái đầy đủ** của một
hàng outbox trước khi viết quy tắc "hàng nào an toàn để xóa cứng". Viết job đó trước khi
dead-letter tồn tại để lại đúng một nhánh (`published_at IS NOT NULL` và đủ cũ); ngày
dead-letter xuất hiện thêm một trạng thái thứ ba mà job viết trước đó không biết, dẫn
tới hoặc xóa nhầm hàng đang chờ xử lý, hoặc để hàng dead-letter kẹt vĩnh viễn.

## Decision

**Dead-letter sống ở một bảng riêng (`outbox_dead_letters`), không thêm cột `attempts`,
`last_error`, hay bất kỳ cột trạng thái biến thiên nào khác vào `outbox`.**

- `outbox` giữ nguyên đúng như migration `000009` đã chốt: append-only, đúng một ngoại
  lệ ghi lại (`published_at`), không có cột status. Quyết định này không mở lại
  migration đó — nó xác nhận và khóa lại.
- Trạng thái "relay đã dùng hết số lần thử cho phép" tiếp tục biểu diễn được **bằng
  chính `published_at`**: relay đặt giá trị đó khi nó không còn xử lý hàng này nữa, bất
  kể lý do là gửi thành công hay đã bỏ cuộc sau khi ghi một hàng vào
  `outbox_dead_letters`. `published_at IS NOT NULL` vẫn đọc đúng nghĩa "relay đã xử lý
  xong hàng này" — nó không còn đồng nghĩa tuyệt đối với "đã gửi thành công", và điều
  đó phải được ghi rõ ở nơi hiện thực hóa (chặng G), không được suy luận ngầm.
- `outbox_dead_letters` là nơi giữ trạng thái biến thiên thật: số lần thử, lỗi gần
  nhất, thời điểm chuyển dead-letter, và (chặng G quyết cụ thể) có thể một cột đánh dấu
  người vận hành đã xử lý xong. Bảng này **được phép** mutable vì bản chất khác
  `outbox`: nó là một hàng đợi công việc vận hành ("việc còn tồn cần người xử lý"),
  không phải một nhật ký sự việc đã xảy ra.
- **Chặng F không hiện thực hóa quyết định này.** Không có migration
  `outbox_dead_letters` nào được tạo trong chặng F. ADR này chỉ chốt hình dạng — bảng
  riêng, không đụng bất biến của `outbox` — để chặng G viết migration mà không phải mở
  lại câu hỏi này, và để job dọn `outbox` (viết sau dead-letter, theo spec mục 2) biết
  trước tập trạng thái nó phải xử lý.
- Nhóm bảng nào trong registry `C-DB-04` mà `outbox_dead_letters` thuộc về **không**
  được quyết ở ADR này — xem mục Nợ để lại.

## Alternatives

**Thêm cột `attempts INT` và `last_error TEXT` vào `outbox`** — loại. Đây là phương án
rẻ nhất về công sức: không bảng mới, không migration thêm ở chặng G, tái dùng đúng hàng
outbox đã có. Và chính vì rẻ nên nó hấp dẫn — nhưng nó phá đúng bất biến mà migration
`000009` đã chốt có chủ đích: `attempts` tăng dần qua nhiều lần `UPDATE` trên cùng một
hàng là "nhiều lần ghi lại", không phải ngoại lệ hẹp một-cột mà `published_at` đang là.
Chấp nhận phương án này tương đương viết lại quyết định của `000009` bằng một thay đổi
sau, mà không ai gọi nó là vậy — đúng loại thay đổi ADR đang tồn tại để buộc phải đi qua
một quyết định tường minh thay vì một PR âm thầm.

**Thêm cột `status ENUM('pending','published','dead_letter')` vào `outbox`, thay thế
cách đọc trạng thái hiện tại bằng `published_at`** — loại, vì đây đúng là phương án mà
`000009` đã cân nhắc và từ chối trong chính comment của nó: một cột status là **bản thứ
hai** của cùng một sự thật mà `published_at` đã biểu diễn, và migration đã chỉ ra hệ
quả cụ thể — sẽ có ngày một hàng mang `status = 'published'` với `published_at NULL`, và
không ai trả lời được hàng đó đã gửi hay chưa. Thêm dead-letter vào enum đó chỉ làm rủi
ro lệch giữa hai bản ghi lớn hơn, không nhỏ đi.

**Giữ trạng thái thử lại trong bộ nhớ của `cmd/relay`, không bền, chỉ log/metric khi bỏ
cuộc** — loại. `cmd/relay` có thể dừng bất kỳ lúc nào — deploy, crash, restart theo lịch
— và ADR-0006 đã chốt relay là **at-least-once**: sau khi tiến trình khởi động lại, một
hàng đang giữa chuỗi thử lại sẽ mất số đếm đã tích lũy và bắt đầu lại từ 0, khiến ngưỡng
"N lần thử" không bao giờ thực sự đạt được, hoặc ngược lại một hàng bị đánh dấu
dead-letter dựa trên state đã mất mà không ai truy lại được vì sao. Đúng kiểu lỗi
"at-least-once nhưng không bền" mà ADR-0006 đã cảnh báo cho việc publish, áp lại cho
việc đếm số lần thử.

## Consequences

**Được:**

- `outbox` giữ nguyên bất biến append-only/một-ngoại-lệ đã ghi thành văn ở `000009`.
  Không ai phải tranh luận lại câu hỏi đó ở chặng G, và không có thay đổi nào "chỉ thêm
  hai cột nhỏ" âm thầm phá một quyết định đã chốt.
- Job dọn `outbox` (chặng G) được viết với đủ ba trạng thái biết trước — chưa gửi, đã
  gửi, đã dead-letter — thay vì viết với hai trạng thái rồi phải sửa lại khi cái thứ ba
  xuất hiện. Đây chính xác là rủi ro mục 2 của spec thiết kế chặng này đã chỉ ra.
- Dữ liệu vận hành (số lần thử, lỗi) tách khỏi dữ liệu sự việc (payload, loại event).
  Truy vấn "những event nào đang kẹt" không phải quét một bảng lớn dần vô hạn theo toàn
  bộ lịch sử event, chỉ quét một bảng nhỏ chứa đúng các ca cần người xử lý.

**Mất:**

- Debug một event bị lỗi cần đọc hai bảng thay vì một — nối bằng `event_id` (hoặc `id`
  của hàng outbox gốc, tùy thiết kế chặng G) — thay vì mọi thứ nằm trên cùng một hàng.
- Thêm một bảng nghĩa là thêm một migration, một registry entry ở `C-DB-04`, và một chỗ
  index phải nghĩ tới, ở chặng G — chi phí bị dời chứ không mất, nhưng vẫn là chi phí
  thật so với phương án "thêm cột".

**Nợ để lại — điều kiện mở lại quyết định này:**

- **Chặng F không hiện thực hóa.** Không có migration `outbox_dead_letters`, không có
  ngưỡng số lần thử cụ thể, không có code relay ghi vào bảng này. Tất cả thuộc chặng G.
  Chặng G viết migration đó phải tuân theo hình dạng đã chốt ở đây (bảng riêng) và
  không được mở lại câu hỏi "hay là thêm cột vào outbox cho gọn" — câu hỏi đó đã đóng.
- **Nhóm bảng của `outbox_dead_letters` trong registry `C-DB-04` chưa được quyết ở ADR
  này.** Nó có khả năng không thuộc `append_only_tables` như `outbox` — một hàng
  dead-letter cần `UPDATE` nhiều lần (mỗi lần thử lại, mỗi lần người vận hành xử lý),
  khác hẳn hình dạng "ghi một lần" mà nhóm đó đòi hỏi. Đây là câu hỏi mở theo đúng cách
  ADR-0003 đã để mở cho `document_counters`: quyết sớm khi chưa có ca dùng thật (chưa
  có migration, chưa biết chính xác cột nào cần `UPDATE`) là quyết trong lúc thiếu dữ
  kiện. Chặng G, lúc viết migration thật, phải tự hỏi câu này và trả lời bằng một ADR
  hoặc một entry registry có trường `adr` trỏ ngược — không phải suy diễn ngầm từ ADR
  này.
- Ngưỡng số lần thử tối đa trước khi dead-letter, và cách báo người khi có hàng mới vào
  bảng này, đều chưa chốt — đúng phần còn lại của khoản nợ mà ADR-0006 để lại. ADR này
  chỉ đóng phần hình dạng lưu trữ.

**Constrains:** —
