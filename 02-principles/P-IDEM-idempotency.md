# P-IDEM — Idempotency

**Câu hỏi nó trả lời:** Thao tác nào bắt buộc idempotent?
**Rules:** R-05, R-17
**Decisions:** ADR-0006

## Cách suy luận

Idempotent nghĩa là **gọi n lần cho ra cùng một kết quả quan sát được như gọi một
lần** — không phải "gọi n lần thì không báo lỗi". Một endpoint tạo phiếu chi, gọi ba
lần tạo ba phiếu, không lần nào lỗi: nó chạy trơn tru và nó sai.

**Ba nguồn gọi lặp, khác nhau ở thứ có sẵn để dedupe.** Chọn nhầm khóa là cách hỏng
phổ biến nhất, nên xác định nguồn trước:

| Nguồn gọi lặp | Vì sao lặp | Khóa dedupe |
|---|---|---|
| Client HTTP | Người dùng bấm hai lần; client retry sau timeout; trình duyệt gửi lại form | `Idempotency-Key` do client sinh |
| Relay outbox | Relay chết giữa `Publish` và `MarkPublished` (ADR-0006) | `event_id`, sinh một lần lúc ghi outbox |
| Job nền | Job chạy lại sau crash, hoặc hai instance cùng chạy | Khóa nghiệp vụ tự nhiên: (công ty, kỳ, loại) |

Nguyên tắc chung cho cả ba: **khóa phải được sinh trước khi hiệu ứng xảy ra và phải
giữ nguyên qua mọi lần thử lại.** Khóa do server sinh tại thời điểm xử lý (một `uuid`
mới mỗi lần) không dedupe được gì — mỗi lần gọi lại là một khóa mới, và mọi thứ dựng
trên nó chỉ là hình thức.

**Dedupe phải là một ràng buộc database, không phải một câu lệnh kiểm tra.** Mẫu
"`SELECT` xem đã xử lý chưa, nếu chưa thì `INSERT`" là hai câu lệnh: hai request song
song đều thấy "chưa có" rồi cùng ghi, và bạn có đúng cái bug định chặn. Thứ duy nhất
phân xử được hai request đồng thời là ràng buộc `UNIQUE` của Postgres, nên việc claim
khóa phải nằm gọn trong một câu `INSERT ... ON CONFLICT DO NOTHING`, và phải nằm
**trong cùng transaction với hiệu ứng** — claim ở transaction riêng rồi hiệu ứng ở
transaction sau nghĩa là có lúc khóa đã claim mà việc chưa làm, và lần thử lại sẽ bị
bỏ qua vĩnh viễn.

**Thao tác nào bắt buộc.** Hỏi: hiệu ứng của nó có *cộng dồn* không?

- Cộng dồn → bắt buộc idempotent. Bút toán tiền, chuyển động kho, cấp số chứng từ,
  gửi thông báo. Chạy hai lần là hai lần hiệu ứng, và không có cách nào nhìn vào dữ
  liệu cuối để biết đã chạy mấy lần.
- Đặt giá trị tuyệt đối (`SET status = 'approved'`) → *dữ liệu* tự nhiên idempotent,
  nhưng **hiệu ứng phụ thì không**: mỗi lần chạy sinh thêm một bản ghi audit (R-17) và
  một dòng `outbox` (R-05), tức thêm một email gửi cho khách. Đây là cái bẫy hay gặp
  nhất — người ta nhìn cột `status` thấy giống nhau rồi kết luận "an toàn".

**Quan hệ với ADR-0006.** Relay outbox là **at-least-once**: nó không biết chắc lần
gửi trước có tới nơi hay không nếu nó chết giữa chừng, nên nó gửi lại. Vì vậy
idempotency **không phải khuyến nghị mà là điều kiện để ADR-0006 đứng vững** — bỏ nó
đi thì mọi lần relay khởi động lại là một lần trừ kho thừa, và toàn bộ mô hình outbox
sụp. Hệ quả thực dụng: nếu một consumer *không thể* làm idempotent, thì lựa chọn đúng
không phải "chấp nhận sai số" mà là **không dùng event cho việc đó** — chuyển sang lời
gọi đồng bộ trong cùng transaction, hoặc đổi thiết kế của consumer.

**Quan hệ với R-17.** Bản ghi audit phải phản ánh đúng số lần dữ liệu *thật sự* thay
đổi. Lần gọi thứ hai với cùng khóa không đổi gì cả, nên nó **không** sinh bản ghi
audit — nếu không, audit trail sẽ nói người dùng chi tiền hai lần trong khi họ chỉ chi
một lần, và một audit trail nói sai thì mất giá trị làm bằng chứng. Ngược lại, lần thử
lại đó vẫn phải để lại dấu vết ở tầng vận hành: log nó ở mức `Info` kèm `request_id`
mới và khóa idempotency, để khi cần vẫn dựng lại được chuyện gì đã xảy ra
([P-OBS-observability.md](P-OBS-observability.md)).

Đừng lẫn với [P-CONC-concurrency.md](P-CONC-concurrency.md): P-CONC lo hai request
**khác nhau** tranh nhau một hàng dữ liệu; P-IDEM lo **cùng một** thao tác tới hai lần.

## Hard check

1. **Mọi handler `POST` sinh bút toán tiền, chuyển động kho, hoặc cấp số chứng từ phải
   đọc header `Idempotency-Key`.** Thiếu header → 422 (R-10), không phải xử lý rồi hy
   vọng. Danh sách endpoint thuộc diện này phải liệt kê tường minh ở
   `04-conventions/C-API-http.md`; endpoint có tên trong danh sách mà handler của nó
   không chứa chuỗi `Idempotency-Key` là vi phạm.
2. **Việc claim khóa là đúng một câu lệnh `INSERT ... ON CONFLICT DO NOTHING`, chạy
   trong cùng transaction với hiệu ứng.** Trong `*_repository.go`, một method claim
   khóa idempotency có cả `SELECT` lẫn `INSERT` là vi phạm.
3. **Bảng khóa idempotency có ràng buộc `UNIQUE (company_id, key)`.** Không có ràng
   buộc này thì toàn bộ ba mục trên chỉ là ước lệ — kiểm trong migration tạo bảng.
4. **Mọi hàm xử lý event dedupe theo `event_id`, và đó là câu lệnh đầu tiên của thân
   hàm.** Hàm nhận `evt outbox.Event` mà dòng lệnh đầu không dùng `evt.EventID` là vi
   phạm. Dedupe theo `aggregate_id` hay theo nội dung payload cũng là vi phạm: hai sự
   việc khác nhau trên cùng aggregate sẽ bị nuốt mất một.
5. **Mỗi hàm xử lý event có một test gọi hai lần cùng `event_id`** và một test gọi hai
   lần với hai `event_id` khác nhau ([P-TEST-testing.md](P-TEST-testing.md)).

```powershell
# 1) Handler tra ve ket qua cho Idempotency-Key nhung khong doc header
Get-ChildItem -Path modules -Recurse -Filter *_handler.go | ForEach-Object {
    $raw = Get-Content -Path $_.FullName -Raw
    if ($raw -match 'idemKey|IdempotencyKey' -and $raw -notmatch 'Idempotency-Key') {
        "{0}: dung khoa idempotency nhung khong doc header Idempotency-Key" -f $_.FullName
    }
}

# 2) Claim khoa bang hai cau lenh thay vi mot
Get-ChildItem -Path modules -Recurse -Filter *_repository.go | ForEach-Object {
    $raw = Get-Content -Path $_.FullName -Raw
    if ($raw -match '(?s)func .*Claim.*\{.*SELECT.*INSERT') {
        "{0}: claim khoa bang SELECT roi INSERT -> dung ON CONFLICT DO NOTHING" -f $_.FullName
    }
}

# 3) Bang khoa idempotency thieu rang buoc UNIQUE
Get-ChildItem -Path migrations -Filter *.up.sql | Select-String -Pattern 'CREATE TABLE\s+idempotency_keys' | ForEach-Object {
    $raw = Get-Content -Path $_.Path -Raw
    if ($raw -notmatch 'UNIQUE\s*\(\s*company_id\s*,\s*key\s*\)') {
        "{0}: idempotency_keys thieu UNIQUE (company_id, key)" -f $_.Path
    }
}
```

```go
package service

import (
	"context"

	"erp/modules/payment/internal/model"
	"erp/shared/audit"
	"erp/shared/auth"
	"erp/shared/requestid"
)

const PermPaymentCreate = "payment.create"

// CreatePayment nhận idemKey do handler đọc từ header Idempotency-Key.
func (s *PaymentService) CreatePayment(ctx context.Context, actor auth.Actor, idemKey string, in CreatePaymentInput) (*model.Payment, error) {
	if err := s.authz.Can(ctx, actor, PermPaymentCreate); err != nil {
		return nil, err
	}

	tx, err := s.db.BeginTxx(ctx, nil)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()

	// Claim khóa TRƯỚC hiệu ứng, trong cùng transaction, bằng ĐÚNG MỘT câu lệnh
	// (INSERT ... ON CONFLICT DO NOTHING). "SELECT xem có chưa rồi mới INSERT" là hai
	// câu: hai request song song đều thấy chưa có rồi cùng ghi. Việc phân xử phải nằm
	// ở ràng buộc UNIQUE của Postgres, chỗ duy nhất phân xử được.
	claimed, err := s.idemRepo.Claim(ctx, tx, actor.CompanyID, idemKey)
	if err != nil {
		return nil, err
	}
	if !claimed {
		// Lần gọi thứ hai với cùng khóa: trả lại KẾT QUẢ ĐÃ LƯU, không phải 409.
		// Client retry sau timeout không phân biệt được "trùng của chính tôi" với
		// "trùng của người khác" nếu ta trả lỗi. Không sinh thêm bản ghi audit ở
		// nhánh này: không có thay đổi dữ liệu nào để truy vết.
		return s.idemRepo.StoredResult(ctx, tx, actor.CompanyID, idemKey)
	}

	p, err := s.paymentRepo.Insert(ctx, tx, actor.CompanyID, in)
	if err != nil {
		return nil, err
	}
	if err := s.auditRepo.Record(ctx, tx, audit.Entry{
		CompanyID: actor.CompanyID,
		ActorID:   actor.UserID,
		RequestID: requestid.FromContext(ctx),
		Action:    "payment.created",
		EntityID:  p.ID,
	}); err != nil {
		return nil, err
	}
	if err := s.idemRepo.SaveResult(ctx, tx, actor.CompanyID, idemKey, p); err != nil {
		return nil, err
	}

	if err := tx.Commit(); err != nil {
		return nil, err
	}
	return p, nil
}
```

## Ca khó

### 1. Người dùng bấm nút hai lần

Chi tiết quyết định thành bại nằm ở **lúc nào client sinh khóa**, không ở phía server.

- Sinh khóa **lúc bấm nút** → mỗi lần bấm một khóa mới → hai khóa khác nhau → server
  tạo hai phiếu chi. Toàn bộ cơ chế idempotency chạy đúng và vô dụng.
- Sinh khóa **lúc mở form** (hoặc lúc bắt đầu một thao tác nghiệp vụ), giữ nguyên qua
  mọi lần bấm và mọi lần retry, chỉ đổi khi người dùng bắt đầu một thao tác mới → đúng.

Nghĩa là `Idempotency-Key` là một phần của hợp đồng API và phải viết vào
`04-conventions/C-API-http.md` kèm đúng câu "sinh lúc mở form" — không thì frontend sẽ
sinh lúc bấm, vì đó là chỗ tự nhiên nhất để đặt `uuid()`. Chặn double-click bằng cách
disable nút là UX tốt nhưng không thay thế được gì: nó không cứu được retry sau timeout,
không cứu được người dùng bấm F5 rồi gửi lại form, và nó là logic frontend nên nó là
thứ đầu tiên hỏng khi mạng chập chờn.

### 2. Relay chết giữa `Publish` và `MarkPublished`

Đây là ca mà ADR-0006 nói thẳng là sẽ xảy ra: event đã ra tới bus nhưng dòng `outbox`
chưa được đánh dấu, nên vòng chạy sau gửi lại cùng `event_id`. Handler thứ hai thấy
`event_id` đã có trong bảng dedupe → bỏ qua hiệu ứng.

Hai chi tiết dễ làm sai ở nhánh "bỏ qua":

- **Phải trả về thành công cho bus**, không phải lỗi. Trả lỗi nghĩa là bus coi như
  chưa xử lý và retry tiếp — vòng lặp vô hạn với một event mà thực ra đã xong từ lâu.
- **Phải bỏ qua toàn bộ hiệu ứng, kể cả hiệu ứng "nhỏ"**: không gửi lại email, không
  ghi lại audit, không ghi thêm dòng `outbox` thứ cấp. Một handler bỏ qua phần trừ kho
  nhưng vẫn gửi email là idempotent một nửa, và nửa còn lại là thứ khách hàng nhìn thấy.

### 3. Client timeout nhưng server đã xử lý xong

Client đặt timeout 10 giây, server xử lý mất 12 giây rồi commit thành công. Client
không nhận được response nên nó retry với **cùng** `Idempotency-Key`. Lúc này server đã
có dữ liệu.

Quyết: **trả lại chính response của lần đầu** — cùng status code (`201`), cùng body,
cùng id. Không trả `409 Conflict`. Lý do: từ phía client, `409` không phân biệt được
"trùng với chính request của tôi vừa gửi" (nghĩa là *thành công*, cứ đi tiếp) với
"trùng mã đơn hàng do người khác tạo" (nghĩa là *thất bại*, phải sửa input). Trả
`409` ở đây ép client đoán, và nó sẽ đoán sai theo hướng hiển thị lỗi cho người dùng
trong khi phiếu chi đã được tạo.

Hệ quả về cài đặt: bảng khóa idempotency phải lưu cả **kết quả**, không chỉ khóa. Và
kết quả đó phải được ghi trong cùng transaction với hiệu ứng — ghi sau khi commit thì
có cửa sổ mà khóa đã tồn tại còn kết quả thì chưa, và lần retry rơi vào đó sẽ nhận
được một response rỗng.

Bốn câu hỏi phải trả lời khi thiết kế bảng này, và trả lời trong ADR chứ không trong
code review: giữ khóa bao lâu (24 giờ là mốc khởi đầu hợp lý), dọn bằng cách nào, xử lý
thế nào khi cùng khóa nhưng **payload khác** (đó là lỗi phía client — trả `422` với mã
riêng chứ không âm thầm trả lại kết quả cũ), và **`idempotency_keys` thuộc nhóm bảng
nào**. Câu cuối không phải chi tiết vụn: theo phân loại hiện hành, bảng không có tên
trong bốn danh sách của `04-conventions/C-DB-database.md` mục `C-DB-04` mặc định là
bảng nghiệp vụ, nên nó phải có `updated_by`, `deleted_at`, phải sinh bản ghi audit cho mỗi
lần claim (R-17), và **không được hard delete nếu không có ADR** (R-18) — tức là job dọn
theo hạn giữ liệu sẽ vi phạm. Bảng này chỉ ghi thêm rồi hết hạn thì bị xóa, đúng hình
dạng của `append_only_tables`; đưa nó vào danh sách đó là việc của một ADR, phải làm
**trước** khi viết migration.
