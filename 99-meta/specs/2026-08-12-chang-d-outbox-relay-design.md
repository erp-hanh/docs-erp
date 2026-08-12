# Chặng D — outbox, relay, và event đầu tiên có người nghe

**Trạng thái:** Đã duyệt · 2026-08-12
**Tiền đề:** Chặng C đóng với hai module, cạnh `machine → auth` được `checkR05` canh bằng máy, CI ba job xanh trên `ea64743`.

---

## 1. Mục tiêu, đo được

Một sự việc ở module này làm đổi dữ liệu ở module kia, **không** qua một lời gọi nào giữa hai module:

```
auth.DeleteUser  ──ghi outbox trong cùng tx──>  outbox
                                                  │
                                          relay (tiến trình riêng)
                                                  │
                                                  ▼
                          machine: xóa assigned_to của mọi máy user đó phụ trách
```

Ba thứ hôm nay chưa từng chạy, và chặng này là lần đầu chúng gặp code thật:

| Vế | Hôm nay | Sau chặng D |
|---|---|---|
| R-05 vế 3 — `Append` cùng transaction với dữ liệu nghiệp vụ | Chưa có `outbox`, chỉ fixture canh | `DeleteUser` ghi outbox trong chính `tx` của nó |
| `Scope.Optional` cho `relay` | Xanh vì `relay/` rỗng | `TestOptionalRootStaysHonest` **đỏ**, bắt gỡ khai báo ở ba chỗ |
| P-IDEM — handler idempotent theo `event_id` | Không có handler nào | Handler thật, và bảng `idempotency_keys` có hàng thật |

**Phép thử của mục tiêu:** xóa một user đang phụ trách một máy, đợi relay chạy, đọc lại máy — `assigned_to` phải là `null`. Và gửi **lại** đúng event đó lần thứ hai phải không đổi gì thêm.

---

## 2. Phạm vi

**Làm:**

| Thành phần | Lý do bắt buộc |
|---|---|
| `migrations/000009_create_outbox`, `000010_create_idempotency_keys` | Hai bảng đã có tên trong registry C-DB-04 từ chặng A nhưng chưa có migration nào tạo |
| `shared/outbox` — `Event`, `Repository`, hằng `EventType` | P-EVT hard check 4: `EventType` cấm chuỗi literal |
| `shared/bus` — pub/sub trong tiến trình | ADR-0006 cho phép bus in-process ở giai đoạn đầu; đổi bus chỉ đụng relay |
| `shared/idempotency` — claim khóa trong cùng transaction với hiệu ứng | P-IDEM: dedupe là câu lệnh **đầu tiên** của handler |
| `relay/` + `cmd/relay` | ADR-0001: relay là **tiến trình riêng**, vì nó phải sống độc lập với vòng đời request |
| `modules/auth` — `DeleteUser` ghi outbox | Producer |
| `modules/machine` — handler nghe `auth.user.deleted` | Consumer |

**KHÔNG làm, và lý do:**

Bus ngoài tiến trình — Kafka, NATS, Redis Streams. ADR-0006 đã chốt bus in-process cho giai đoạn đầu và nói rõ đổi bus chỉ đụng `relay/`. Dựng một broker lúc này là thêm một tiến trình phải giám sát và một giao thức thứ hai để phục vụ **một** loại event, trong khi cả hệ thống chạy trên một app server.

Dead-letter và giới hạn số lần thử — ADR-0006 ghi đây là nợ chưa quyết. Chặng này giữ nguyên hành vi đã chốt: `Publish` lỗi thì **dừng cả batch**, không `continue`, và hàng vẫn nằm lại trong `outbox` với `published_at IS NULL`. Một event kẹt là một event còn nguyên, không phải một event mất.

Job dọn `outbox` theo hạn giữ liệu — bảng chỉ tăng, và ADR-0006 nói hard delete bảng này không cần ADR riêng. Nhưng một job dọn khi bảng còn vài chục hàng là code không ai đọc được kết quả. Nó vào chặng nào có số liệu thật.

Sửa `assigned_to` khi user bị **khóa** (`is_active = false`) — khác hẳn xóa: một người bị khóa tạm vẫn là người phụ trách máy đó. Chỉ `DeleteUser` phát event.

---

## 3. Vì sao ca này là event chứ không phải một lời gọi đồng bộ

Chặng C đã trả lời câu hỏi ngược lại cho `assigned_to`: `machine` hỏi `auth` xem một user có tồn tại không **trước khi ghi**, và đó là đồng bộ vì nếu `auth` không trả lời được thì việc gán không được coi là đã xong.

Chiều này thì khác, và phép thử của P-EVT cho ra câu trả lời ngược: **nếu `machine` hỏng thì việc xóa user còn được coi là đã xong không?** Có. Người dùng đã bị xóa, quyền đã mất, token đã thu hồi. Việc dọn `assigned_to` là hệ quả, không phải điều kiện — và bắt `DeleteUser` chờ `machine` là bắt một thao tác quản trị người dùng hỏng theo một module nó không cần biết tới.

Đó cũng là lý do cạnh này **không** vào `allowed_deps`: `machine` không gọi `auth`, và `auth` không gọi `machine`. Cả hai chỉ biết một chuỗi `event_type` khai ở `shared/`.

---

## 4. Hợp đồng

### 4.1 `shared/outbox`

```go
type Event struct {
	EventID       string          // sinh DUNG MOT lan, luc service ghi hang nay
	CompanyID     string
	AggregateType string
	AggregateID   string
	EventType     string          // hang khai o shared/outbox/events, cam chuoi literal
	Payload       json.RawMessage // gia tri nguyen thuy, khong nhung model
	OccurredAt    time.Time
	RequestID     string          // lay tu ctx luc ghi; relay CAM sinh moi
	CreatedBy     string
}

type Repository interface {
	Append(ctx context.Context, db sharedDB.DBTX, e Event) error
}
```

`Append` nhận `DBTX` chứ không nhận `*sqlx.DB` — cùng lý do với `audit.Repository`: nó phải chạy được bằng **chính** `tx` của thao tác nghiệp vụ, và một chữ ký nhận `*sqlx.DB` sẽ khiến nó *không thể* làm điều đó dù người viết muốn. Đây là vế 3 của R-05, vế mà checker không kiểm được bằng phân tích cú pháp — nên chữ ký là hàng rào duy nhất.

`EventID` sinh ở service, không ở relay. Nó là danh tính của **sự việc** với thế giới bên ngoài, và relay gửi lại lần thứ hai phải mang đúng chuỗi đó — nếu không, dedupe phía consumer mất tác dụng đúng lúc nó cần nhất.

### 4.2 `shared/outbox/events` — tên event là hằng

```go
const UserDeleted = "auth.user.deleted"
```

Thì **quá khứ**: nó mô tả một việc đã xảy ra và đã commit, không phải một mệnh lệnh. `auth.user.delete_assignee` sẽ là một lời gọi đội lốt event, và nếu thật sự cần ra lệnh thì đó là ca gọi đồng bộ qua `api/`.

Hằng sống ở `shared/` chứ không ở module phát: consumer phải gọi tên nó, mà `machine` không được import `modules/auth` cho việc này — và không nên, vì nghe một event không tạo ra phụ thuộc.

### 4.3 Payload của `auth.user.deleted`

```json
{
  "event_id": "...", "occurred_at": "...", "company_id": "...",
  "request_id": "...",
  "user_id": "9f1c0a6e-4b2d-4f8a-9c33-2b7d8e5a1f04"
}
```

**Năm field, không phải bốn.** Bản đầu của spec này viết bốn và bỏ sót `request_id`; hai
agent thi công phát hiện độc lập với nhau và cùng từ chối tự sửa. Chỗ đúng của nó là
payload chứ không phải một cột: C-DB-07 không cho bảng `outbox` cột `request_id`, còn
P-EVT thì đặt `request_id` cạnh `event_id` và `occurred_at` trong payload — và consumer
chỉ nhận payload qua bus, nó không đọc bảng `outbox`. Chuỗi rỗng là trạng thái **hợp lệ**:
một sự việc sinh ra ngoài đường HTTP không có request nào để trỏ tới.

Không `email`, không `full_name`: consumer duy nhất cần đúng một thứ — id để so với `assigned_to`. Mỗi field thêm vào là một field mọi consumer tương lai được phép dựa vào, và gỡ nó ra là breaking change.

### 4.4 `shared/idempotency`

```go
type Claimer interface {
	// Claim tra false khi khoa da ton tai - tuc event nay da duoc xu ly.
	Claim(ctx context.Context, db sharedDB.DBTX, companyID, key string) (bool, error)
}
```

Cài đặt là một câu `INSERT ... ON CONFLICT DO NOTHING` trên `idempotency_keys`, chạy trong **chính** transaction của hiệu ứng. Tách ra hai transaction là mở đúng cửa sổ mà cơ chế này sinh ra để đóng: claim xong rồi chết trước khi ghi thì event bị coi là đã xử lý trong khi nó chưa.

---

## 5. Schema

```sql
-- 000009_create_outbox.up.sql
outbox(
  id UUID PK, event_id UUID NOT NULL UNIQUE, company_id UUID NOT NULL REFERENCES companies(id),
  aggregate_type TEXT NOT NULL, aggregate_id UUID NOT NULL, event_type TEXT NOT NULL,
  payload JSONB NOT NULL, occurred_at TIMESTAMPTZ NOT NULL,
  published_at TIMESTAMPTZ, created_at TIMESTAMPTZ NOT NULL DEFAULT now(), created_by UUID NOT NULL)

CREATE INDEX idx_outbox_occurred_at_unpublished ON outbox(occurred_at) WHERE published_at IS NULL;
```

`outbox` thuộc `append_only_tables` **và** `naming_exempt` — cả hai đã có trong registry C-DB-04 từ chặng A, nên chặng này không cần ADR nào. Nhóm đó miễn `updated_at`, `updated_by`, `deleted_at`, và miễn sinh bản ghi audit.

Ba điều khác thường, cả ba đều là quy ước đã chốt ở C-DB-07:

**Không có cột `status`.** `published_at IS NULL` là toàn bộ trạng thái. Một cột `status` sẽ là bản thứ hai của cùng một sự thật, và hai bản thì lệch.

**Index không dẫn đầu bằng `company_id`.** Đây là ngoại lệ tường minh của C-DB-05 mục 1: relay đọc **theo thứ tự thời gian trên toàn hệ thống**, không đọc theo công ty. Một index dẫn đầu bằng `company_id` không phục vụ câu nào relay chạy.

**`aggregate_id` không có `REFERENCES`.** Nó trỏ tới bảng nào là tùy `aggregate_type`, nên không có bảng đích cố định. Nó mang *hình dạng* tên của một khóa ngoại nhưng không phải khóa ngoại — ghi rõ để người review R-09 không đi tìm một ràng buộc.

```sql
-- 000010_create_idempotency_keys.up.sql
idempotency_keys(
  id UUID PK, company_id UUID NOT NULL REFERENCES companies(id),
  key TEXT NOT NULL, created_at TIMESTAMPTZ NOT NULL DEFAULT now(), created_by UUID NOT NULL)

CREATE UNIQUE INDEX uq_idempotency_keys_company_id_key ON idempotency_keys(company_id, key);
```

`UNIQUE` thường chứ không partial: bảng này thuộc `append_only_tables` nên nó **không có** `deleted_at`, và vế `WHERE deleted_at IS NULL` sẽ là một câu nói về một cột không tồn tại.

---

## 6. Relay

```text
relay/relay.go          vong lap, drainBatch, xu ly loi
relay/repository.go     FetchUnpublished, MarkPublished
cmd/relay/main.go       tien trinh rieng: doc env, mo DB, chay vong lap
```

`relay/` nằm **ngoài** `modules/` — đó là điều R-05 đòi, và là lý do `checkR05` cấm `.Publish(` ở mọi vị trí dưới `modules/` nhưng không đụng tới đây.

Vòng lặp đọc bằng `SELECT ... WHERE published_at IS NULL ORDER BY occurred_at LIMIT $1 FOR UPDATE SKIP LOCKED` trong **chính transaction của relay** — ngoại lệ duy nhất của "chỉ service mở transaction" (C-GO-03). `FOR UPDATE SKIP LOCKED` là thứ cho phép chạy hai bản relay mà không gửi trùng.

**Xử lý lỗi:** `Publish` lỗi → `break` cả batch, không `continue`. Thứ tự trong một aggregate là thứ consumer dựa vào; bỏ qua một hàng lỗi rồi gửi hàng sau là gửi "đã xóa" trước "đã tạo". `MarkPublished` lỗi → cũng `break`.

**At-least-once, không exactly-once.** Commit transaction rồi mới `Publish` thì có cửa sổ chết giữa hai bước, và gửi lại là hành vi **bình thường** chứ không phải sự cố. Đó là lý do consumer phải idempotent, và là lý do `event_id` sinh một lần duy nhất.

Ngày `relay/` có file `.go` đầu tiên, `TestOptionalRootStaysHonest` sẽ đỏ với thông điệp bảo gỡ `relay` khỏi `Scope.Optional` ở ba chỗ trong `arch/internal/loader/loader.go`. **Làm đúng thế, đừng nới lỏng** — cơ chế đó nổ đúng lúc nó được thiết kế để nổ.

---

### 6.1 Consumer chạy ở tiến trình nào — một hệ quả, không phải một lựa chọn

Hai quyết định đã có nhìn qua thì chạm nhau: ADR-0001 nói relay là **tiến trình riêng**;
ADR-0006 nói bus giai đoạn đầu có thể **in-process**. Nếu bus chỉ sống trong bộ nhớ, thì
publish trong tiến trình relay không đến được consumer nằm trong tiến trình API.

Nhưng đó không phải mâu thuẫn — nó là một **hệ quả chưa ai viết ra**: hai quyết định cộng
lại chỉ còn đúng một hình dạng khả dĩ, là **consumer sống trong chính tiến trình relay**.

```text
cmd/api      HTTP, ghi outbox trong cung tx  ── khong subscriber nao
cmd/relay    doc outbox -> bus in-process -> subscriber cua cac module
```

Hệ quả phải nói ra, vì nó đổi bố cục:

- `cmd/relay` là **composition root thứ ba**, sau `cmd/api` và `cmd/dev`. Nó dựng module
  để *tiêu thụ* event, không để phục vụ HTTP — nên nó tiêm `DB`, `Authz`, `Audit` nhưng
  không đăng ký route nào.
- Bảng vai trò ở `cmd/internal/vaitro` dùng chung cho cả ba root, đúng như ADR-0010 đã mở
  đường. Actor của một handler nghe event là **actor hệ thống** — `system_actor_id` khai ở
  C-DB-04 — chứ không phải người đã bấm nút xóa: người đó không yêu cầu dọn `assigned_to`,
  hệ thống mới là thứ quyết định điều đó xảy ra.
- Ngày bus đi ra ngoài tiến trình, thứ phải sửa là `cmd/relay` và `shared/bus` — không
  module nào phải biết. Đó chính là điều ADR-0006 mua được khi nó nói "đổi bus chỉ đụng
  relay".

Hai đường còn lại và lý do loại. **Bus đi qua database** (`LISTEN`/`NOTIFY` hoặc một bảng
subscription): giải được bài toán nhưng dựng một kênh vận chuyển thứ hai bên cạnh chính
`outbox` — hai cơ chế cho cùng một việc, trong khi cái thứ hai chưa ai cần. **Relay chạy
như goroutine trong `cmd/api`**: đơn giản nhất, và mâu thuẫn thẳng với ADR-0001 — lật nó
cần một ADR mới chứ không phải một dòng trong spec.

## 7. Producer và consumer

**`auth.DeleteUser`** thêm đúng một lời gọi, nằm trong `tx` đã mở, giữa `SoftDelete` và `ghiAudit`:

```go
if err := s.outboxRepo.Append(ctx, tx, outbox.Event{...}); err != nil { return ... }
```

`ctx` cho `RequestID`, `tx` cho tính nguyên tử. Nếu commit hỏng thì cả ba — hàng users, dòng audit, hàng outbox — cùng biến mất. Đó là toàn bộ lý do outbox pattern tồn tại: không có khoảnh khắc nào user đã xóa mà event chưa được ghi, và ngược lại.

**Consumer ở `modules/machine`** — một handler nhận event, và **câu lệnh đầu tiên** của nó là claim khóa idempotency theo `event_id`:

| # | Bước | Ghi chú |
|---|---|---|
| 1 | `BEGIN` | Relay gọi handler ngoài mọi transaction |
| 2 | `Claim(ctx, tx, companyID, event_id)` | `false` → event đã xử lý, `COMMIT` rỗng và trả **thành công** cho bus |
| 3 | `UPDATE machines SET assigned_to = NULL WHERE company_id = $1 AND assigned_to = $2` | Không đọc trước: một câu ghi là đủ, và nó idempotent theo bản chất |
| 4 | Ghi audit | R-17: thao tác ghi lên bảng nghiệp vụ sinh bản ghi audit |
| 5 | `COMMIT` | |

Bước 2 trả **thành công** chứ không phải lỗi khi khóa đã tồn tại: bus nhận lỗi sẽ gửi lại mãi mãi một event đã xử lý xong.

Handler đặt ở `modules/machine/internal/handler/` hay một thư mục riêng? Nó không phải HTTP handler. Spec này chốt: `modules/machine/internal/subscriber/`. Lý do ở mục 9.

---

## 8. Kéo theo ở `docs-erp`

| Thay đổi | Vì sao |
|---|---|
| `modules/auth/docs/Events.md` — mục 1 không còn rỗng | `auth` phát `auth.user.deleted` |
| `modules/machine/docs/Events.md` — mục 2 không còn rỗng | `machine` nghe event đó; phải nêu cơ chế idempotent cụ thể |
| Không đổi C-DB-04 | `outbox` và `idempotency_keys` đã có tên trong registry từ chặng A |
| Không đổi C-API-05 | Không mã lỗi mới: đường event không đi ra client |

---

## 9. Định nghĩa hoàn thành

- Xóa một user đang phụ trách một máy → sau khi relay chạy, `machines.assigned_to` là `NULL`. Đo qua database thật.
- Gửi **lại** đúng event đó → không đổi gì thêm, và không có hàng `idempotency_keys` thứ hai. Đây là ca chứng minh at-least-once được xử đúng.
- `TestOptionalRootStaysHonest` đã đỏ một lần và đã được xử bằng cách gỡ `relay` khỏi `Optional`, **không** bằng cách nới điều kiện.
- Bỏ lời gọi `Append` khỏi `DeleteUser` → có test đỏ. Bỏ bước claim khóa khỏi handler → có test đỏ.
- `go run ./cmd/dev check` và `test` xanh; `arch-update` chỉ cho diff ở cột FILE.

---

## 10. Rủi ro đã biết

**Handler nghe event là tầng thứ năm của module, và nó không có tên trong `CL-NEWMOD-02`.** Checklist liệt kê `api/`, `handler/`, `service/`, `repository/`, `model/`. `subscriber/` là thứ sáu — cùng loại ngoại lệ với `internal/token` của module auth, và như lần đó, nó phải được ghi ra chứ không lặng lẽ tồn tại. Đường sạch hơn là để `subscriber` chỉ là một lớp mỏng gọi xuống service, và mọi nghiệp vụ vẫn ở `service/`.

**Relay là tiến trình thứ hai phải chạy khi dev.** Trước chặng này `go run ./cmd/dev dev` dựng đủ hệ thống; từ nay nó thiếu một nửa của đường event, và một người thử tính năng sẽ thấy `assigned_to` không bao giờ được dọn mà không hiểu vì sao. Lệnh `dev` phải chạy cả hai, hoặc phải nói ra rằng nó không chạy relay.

**Consumer chạy ở đâu — xem mục 6.1.** Câu hỏi này suýt bị bỏ qua khi viết spec, và nó là câu quyết định hình dạng cả chặng.
