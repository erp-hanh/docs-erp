# ADR-0018: `idempotency_keys` giữ dấu vân payload và response của lần đầu, để phát lại cho `Idempotency-Key` ở tầng HTTP

**Status:** Accepted (2026-08-15)

## Context

Hợp đồng đã có từ trước, ở hai chỗ và cả hai đều ghi thành văn. Mục "Idempotency" của
[../04-conventions/C-API-http.md](../04-conventions/C-API-http.md) chốt ba ca, ba hành vi;
bảng 5 của C-API-07 là sổ liệt kê endpoint chịu nghĩa vụ đó:

| Ca | Phải trả |
|---|---|
| Thiếu header | `422 ERR_COMMON_IDEMPOTENCY_KEY_MISSING` |
| Trùng khóa, **cùng** payload | Chính response của lần đầu — cùng `201`, cùng body, cùng id |
| Trùng khóa, **khác** payload | `422 ERR_COMMON_IDEMPOTENCY_KEY_REUSED` |

Repo tại thời điểm quyết: bảng 5 **rỗng**; không handler sản phẩm nào chứa chuỗi
`Idempotency-Key`; `shared/middleware/cors` cho header đó đi qua kèm một comment nói rõ
backend *chưa* thi hành; chữ ký của `shared/idempotency` là
`Claim(ctx, db, companyID, key string) (bool, error)`, và người dùng duy nhất của nó là
subscriber `auth.user.deleted` — một đường event, không phải một đường HTTP.

**Chữ ký đó không thi hành nổi hai hàng cuối của bảng trên, và lý do không phải cài đặt
thiếu mà là bảng thiếu cột.** `idempotency_keys` không giữ dấu vân của payload nên không
phân biệt được hàng 2 với hàng 3; nó không giữ response nên không phát lại được cái gì.
Một `bool` là toàn bộ thứ hàm đó biết, và ba ca thì cần nhiều hơn hai giá trị.

Đáng nói hơn: doc của chính package đó khai nó phục vụ ca HTTP này và **trỏ đích danh
C-API-07 bảng 5**, kèm bốn câu hỏi mà nó nói phải trả lời trong một ADR — giữ khóa bao
lâu, dọn thế nào, cùng khóa khác payload xử sao, bảng thuộc nhóm nào. Cho tới hôm nay đó
là một comment nói dối: nó mô tả một khả năng package không có.

**Vì sao không hoãn thêm một chặng nữa.** Cho `machine`, một lần gửi lại
`POST /breakdowns` sinh một dòng nhật ký thừa — thấy được, xóa được. Cho `inventory`, một
lần gửi lại `POST /stock-movements` xuất **hai** lần cùng một lô hàng, và dấu vết duy nhất
là tồn kho ít đi đúng bằng số hàng chưa ai lấy. Không màn hình nào đỏ. Đó là ranh giới
giữa một khoản nợ và một lỗi dữ liệu.

Ba ràng buộc của bảng cũ, tại thời điểm quyết, đều đang có hiệu lực và không cái nào được
mở ra: bảng thuộc `append_only_tables` của registry `C-DB-04` nên **không có `updated_at`**
và mọi thứ cần ghi phải ghi trong một lần ghi duy nhất (comment của migration `000010`);
`DBTX` cố ý không có `BeginTxx` nên việc claim buộc phải chạy trong chính transaction của
hiệu ứng; và [../02-principles/P-IDEM-idempotency.md](../02-principles/P-IDEM-idempotency.md)
đòi việc claim là câu lệnh đầu tiên của phần nghiệp vụ.

## Decision

**`idempotency_keys` mang thêm ba cột — `request_hash`, `response_status`, `response_body`
— và `Claim` được thay bằng `ClaimOrLoad`, hàm vừa giành khóa vừa trả lại response của lần
đầu khi khóa đã tồn tại, trong đúng một lần ghi.**

```
migration 000018: ALTER TABLE idempotency_keys
  ADD COLUMN request_hash    TEXT  NOT NULL DEFAULT '',
  ADD COLUMN response_status INT   NOT NULL DEFAULT 0,
  ADD COLUMN response_body   JSONB;

ClaimOrLoad(ctx, db, companyID, key, requestHash string, resp Response) (Ket, error)
  Ket.GianhDuoc   bool    // true: lan dau, nguoi goi chay tiep hieu ung
  Ket.RequestHash string  // cua lan dau, de nguoi goi so sanh
  Ket.Status      int
  Ket.Body        []byte
```

- **`Claim` cũ bị bỏ**, không giữ lại làm lớp mỏng. Subscriber `auth.user.deleted` chuyển
  sang `ClaimOrLoad` với `requestHash` rỗng và response rỗng — đó là lý do ba cột mới đều
  có `DEFAULT`, và là lý do đường event không phải biết gì về response.
- **`request_hash` là SHA-256, hex, của thân JSON đã chuẩn hóa của request.** Không băm
  header, không băm actor: cùng một người gửi lại cùng một thân là ca hàng 2; hai người
  khác nhau trùng khóa trong cùng công ty là ca hàng 3, và `422` là câu trả lời đúng cho
  họ. Băm actor sẽ biến ca hàng 3 thành hai khóa độc lập và giấu mất một lỗi phía client.
- **Phạm vi thi hành: đúng một endpoint** — `POST /api/v1/stock-movements`, dòng đầu tiên
  của bảng 5 ở C-API-07. Quyết định này **không** áp mặc định toàn cục cho mọi `POST`:
  bảng 5 là danh sách nghĩa vụ theo mệnh đề, và mỗi dòng thêm vào nó là một hợp đồng công
  khai với frontend.
- **Bảng vẫn thuộc `append_only_tables`.** Ba cột mới không kéo theo `updated_at`,
  `updated_by`, `deleted_at`, và không có câu `UPDATE` nào lên bảng này. Registry `C-DB-04`
  không đổi một dòng nào.

Ba ràng buộc cũ được giữ nguyên, và mỗi cái ép một điều lên hình dạng trên:

- **Vẫn ghi đúng MỘT lần.** Không có `updated_at` nghĩa là không có mẫu "claim trước rồi
  `UPDATE` kết quả sau". Hệ quả trực tiếp, và đây là phần đắt nhất của quyết định:
  **response phải biết được trước khi ghi**, nên service sinh `id` của chuyển động bằng Go
  và đặt `created_at` bằng đồng hồ ứng dụng thay vì `gen_random_uuid()` và `now()` của
  database. Điều đó chỉ an toàn vì [ADR-0013](ADR-0013-cmd-api-mot-instance.md) chốt hệ
  thống chạy một instance.
- **Vẫn chạy trong CHÍNH transaction của hiệu ứng.** `DBTX` cố ý không có `BeginTxx`, nên
  chữ ký là hàng rào duy nhất và nó được giữ nguyên: `ClaimOrLoad` nhận `DBTX` làm tham số,
  không tự mở transaction.
- **Vẫn là câu lệnh đầu tiên của phần nghiệp vụ** (P-IDEM hard check 2). Băm payload và
  dựng DTO **không phải hiệu ứng** — không chạm database, không đổi gì — nên chúng đứng
  trước mà không phá vế đó. Tiền lệ đã có: bước giải mã payload đứng trước bước claim ở
  subscriber của `machine`.

## Alternatives

**Giữ `Claim`, thêm một hàm `SaveResult` gọi sau hiệu ứng** — loại, dù đây đúng là hình
dạng mà ví dụ trong P-IDEM đang vẽ. Hàng khóa đã được `INSERT` ở đầu transaction, nên ghi
response vào chính hàng đó là một `UPDATE`, tức lần ghi thứ hai lên một bảng
`append_only_tables` không có `updated_at`. Migration `000010` đã chốt bất biến "một lần
ghi duy nhất" bằng văn bản và giải thích lý do tại chỗ; phá nó bằng một hàm thêm vào là
viết lại quyết định đó mà không ai gọi tên — đúng loại thay đổi mà
[ADR-0014](ADR-0014-dead-letter-bang-rieng.md) vừa từ chối cho `outbox` cách đây một chặng.

**Giữ `Claim` và thêm `ClaimOrLoad` bên cạnh, cho hai đường dùng hai hàm** — loại. Hai hàm
cùng đọc một bảng với hai luật khác nhau là chỗ lệch sẽ lớn dần: ngày sửa luật so sánh
`request_hash` hay luật dọn khóa, người sửa phải nhớ có hai bản. Chặng F đã trả giá đúng
kiểu đó với hai bản `compose.dev.yml`. Giá của việc bỏ `Claim` là phải động vào subscriber
`auth.user.deleted` — đường bất đồng bộ duy nhất đang chạy thật — và đó là một chi phí
kiểm được bằng test có sẵn, khác với một khoản lệch không ai canh.

**Lưu response ở bảng thứ hai (`idempotency_responses`), nối bằng khóa** — loại. Nó cho
phép giữ nguyên chữ ký `Claim`, nhưng đổi lại là hai hàng cho một sự việc và hai lần ghi
cho một lần claim, tức quay lại đúng trạng thái thứ ba mà comment của `000010` đã từ chối:
"đã claim mà chưa có response" không phân biệt được "đang chạy" với "đã chết giữa chừng".
Thêm một bảng cũng kéo theo một entry registry `C-DB-04` và một câu hỏi nhóm bảng — chi
phí thật cho một thứ ba cột giải quyết xong.

**Trả `409` cho mọi lần trùng khóa, không lưu response** — loại, và lý do đã ghi sẵn ở
C-API-02: từ phía client, `409` không phân biệt được "trùng với request của chính tôi"
(thành công, đi tiếp) với "trùng mã đơn do người khác tạo" (thất bại, phải sửa input). Một
client retry sau timeout sẽ báo lỗi cho người dùng về một chuyển động kho **đã ghi thành
công**, và người dùng sẽ gửi lại lần thứ ba với khóa mới.

**Không làm gì ở chặng này, hoãn tới khi có endpoint thứ hai** — loại. Nó là phương án rẻ
nhất và nó đã được chọn ba chặng liên tiếp; thứ đổi hôm nay là hậu quả. `POST /stock-movements`
là endpoint đầu tiên của repo khớp mệnh đề "sinh chuyển động kho" của P-IDEM, nên hoãn tiếp
nghĩa là merge một endpoint **có tên trong bảng 5** mà không thi hành nghĩa vụ của bảng đó
— tức tự tạo ra một vi phạm được ghi thành văn, không phải một khoản nợ.

## Consequences

**Được:**

- Ba ca của bảng ở C-API-http trở thành thi hành được, và thi hành bằng **một** câu lệnh
  ghi trong đúng transaction của hiệu ứng — không có cửa sổ nào giữa khóa và hiệu ứng.
- Một đường duy nhất cho cả ba nguồn gọi lặp của P-IDEM (client HTTP, relay outbox, job
  nền): cùng một bảng, cùng một hàm, khác nhau ở chỗ `requestHash` và response có rỗng hay
  không.
- Ba trong bốn câu hỏi mà doc của `shared/idempotency` treo lại được trả lời ở đây: cùng
  khóa khác payload trả `422 ERR_COMMON_IDEMPOTENCY_KEY_REUSED` (so `request_hash`); bảng
  vẫn thuộc `append_only_tables` nên không có entry registry mới; và không có trạng thái
  trung gian nào được thêm vào.

**Mất:**

- **Endpoint trong bảng 5 phải sinh `id` và `created_at` ở Go**, lệch khỏi khuôn mọi bảng
  khác của hệ thống vốn lấy `gen_random_uuid()` và `now()` của database. Lệch này an toàn
  hôm nay chỉ nhờ một điều kiện bên ngoài ADR này — một instance ([ADR-0013](ADR-0013-cmd-api-mot-instance.md)).
- **Hình dạng response của endpoint bị đóng băng theo từng hàng khóa.** `response_body` là
  JSONB chụp lại DTO tại thời điểm ghi; đổi DTO response rồi phát lại một khóa cũ sẽ trả ra
  hình dạng cũ. Điều này không tạo luật mới — C-API-06 vốn đã coi đổi field response là
  breaking change — nhưng nó làm hậu quả xuất hiện sớm hơn và ở một chỗ không ai nhìn.
- Bảng lớn thêm ba cột, trong đó một cột JSONB, và nó vẫn chưa có job dọn nào.
- Mọi lời gọi `Claim` hiện có phải sửa, kể cả đường event không cần gì trong ba cột mới.

**Nợ để lại — và điều kiện mở lại quyết định này:**

- **Hạn giữ khóa và cách dọn vẫn chưa chốt** — hai trong bốn câu hỏi mà doc của
  `shared/idempotency` nêu. Bảng được hard delete theo lịch giữ liệu mà không cần ADR riêng
  ([ADR-0003](ADR-0003-multi-tenant-ready.md), R-18), nhưng "theo lịch" nào thì chưa ai
  viết. Với `response_body` là JSONB, chi phí của việc không dọn tăng theo kích thước
  response chứ không chỉ theo số hàng.
- **Điều kiện mở lại 1 — `cmd/api` chạy instance thứ hai.** Đó cũng chính là điều kiện mở
  lại của ADR-0013. Ngày đó, hai tiến trình đặt `created_at` bằng hai đồng hồ vào cùng một
  sổ, và mệnh đề "response biết được trước khi ghi" mất chỗ dựa. Câu phải hỏi lại lúc đó
  không phải "có nên lưu response không" mà là "`id` và `created_at` sinh ở đâu".
- **Điều kiện mở lại 2 — endpoint thứ hai vào bảng 5 mà response của nó không dựng được
  trước khi ghi**, ví dụ response mang một giá trị chỉ có sau khi database ghi xong (số
  chứng từ do `document_counters` cấp, một cột tính bởi trigger). Lúc đó "ghi đúng một lần"
  và "lưu được response" không còn đứng chung được, và một trong hai phải nhường — bằng một
  ADR mới, không bằng một `UPDATE` thêm vào lặng lẽ.
- **Điều kiện mở lại 3 — ngày một response cần phát lại mà không được phép nằm trong
  database.** R-16 cấm serialize token và secret; hôm nay không endpoint nào trong bảng 5
  trả những thứ đó, nên câu hỏi chưa đặt ra. Endpoint đầu tiên rơi vào ca này phải trả lời
  trước khi có tên trong bảng 5, chứ không phải sau.
- Hình dạng "chuẩn hóa thân JSON" trước khi băm chưa được viết thành quy ước ở tầng
  Convention. Hai bản chuẩn hóa khác nhau giữa hai endpoint sẽ cho hai `request_hash` khác
  nhau cho cùng một thân, và kiểu hỏng đó hiện ra dưới dạng một `422` không ai giải thích
  được. Chặng nào thêm endpoint thứ hai vào bảng 5 phải đóng khoản này.

**Constrains:** —
