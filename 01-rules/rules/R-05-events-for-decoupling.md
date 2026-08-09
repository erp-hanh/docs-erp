# R-05 — Events for Decoupling

Trang này mở rộng entry trong [../RULES.md](../RULES.md). Mệnh đề bắt buộc nằm ở đó,
không lặp lại ở đây.

## Vì sao

Publish trong transaction là một con bug im lặng: nếu transaction rollback sau khi
`bus.Publish` đã chạy, event đã bay ra khỏi tiến trình rồi — không cách nào gọi nó
về. Consumer (ví dụ module Inventory trừ tồn kho khi nhận `order.created`) xử lý
một sự kiện mô tả một đơn hàng chưa từng tồn tại trong database.

Bọc `bus.Publish` trong `defer` không cứu được gì, nhưng lý do không phải như thường
bị nói nhầm. Hàm `defer` **không** chạy trong transaction: nó chạy sau khi
`tx.Commit()` đã thực thi xong và sau khi giá trị trả về của method đã được tính (và
trước `defer tx.Rollback()` đăng ký trước đó, vì `defer` chạy theo thứ tự LIFO). Vấn
đề thật là nó chạy **vô điều kiện**: publish cả khi `Commit()` vừa trả lỗi, cả khi
hàm return sớm ở giữa vì `Insert` thất bại, cả khi `Rollback()` sắp hủy sạch mọi thứ.
Thêm nữa, `defer` không có chỗ nhận giá trị trả về nên lỗi của `Publish` bị nuốt luôn.
Kết quả cuối cùng giống hệt publish-trong-transaction: consumer nhận event mô tả một
đơn hàng không tồn tại.

Ngược lại, nếu publish đúng lúc — sau khi transaction đã commit thành công — nhưng
gọi thẳng `bus.Publish` từ code nghiệp vụ thay vì qua outbox, thì lộ ra vấn đề khác:
ghi DB và publish lên message bus là hai hệ thống riêng biệt, không có cơ chế nào
đảm bảo cả hai cùng thành công hoặc cùng thất bại (bài toán "dual write" kinh điển).
Nếu tiến trình chết đúng giữa hai bước đó — pod bị kill, panic, mất kết nối — dữ liệu
đã nằm trong DB nhưng event thì mất vĩnh viễn, không ai biết để gửi lại.

Outbox giải quyết cả hai bằng cách biến "ghi DB + gửi event" thành một transaction
Postgres duy nhất: bảng `outbox` chỉ là một bảng khác trong cùng transaction, cùng
commit hoặc cùng rollback với dữ liệu nghiệp vụ. Việc publish thật sự lên bus được
tách ra cho một relay riêng — package nằm **ngoài** `modules/`, chạy sau, đọc `outbox`
và gửi đi. Cái giá phải trả là relay không thể biết chắc một lần gửi trước đó có tới
nơi hay không nếu nó chết giữa chừng — nên nó gửi lại. Đó là lý do publish trở thành
**at-least-once**: mọi event handler phải idempotent theo `event_id`, nếu không một
event gửi trùng sẽ tạo ra hai lần hiệu ứng (trừ kho hai lần, gửi email hai lần) từ
một hành động nghiệp vụ chỉ xảy ra một lần. Vì vậy `event_id` không phải field trang
trí: nó phải được sinh **một lần** lúc ghi outbox và giữ nguyên qua mọi lần gửi lại.

## Ví dụ SAI

```go
package service

import (
	"context"

	"github.com/jmoiron/sqlx"

	"erp/modules/order/internal/model"
	"erp/modules/order/internal/repository"
	"erp/shared/auth"
	"erp/shared/authz"
	"erp/shared/bus"
)

const PermOrderCreate = "order.create"

type OrderService struct {
	db        *sqlx.DB
	authz     authz.Checker
	orderRepo repository.OrderRepository
	bus       bus.Publisher
}

// SAI #1: publish ngay trong transaction, trước khi biết tx.Commit() có thành công
// hay không. Nếu Commit() thất bại ở dòng cuối (deadlock, mất kết nối), đơn hàng
// chưa từng tồn tại trong orders nhưng event order.created đã ra tới bus.
func (s *OrderService) CreateOrder(ctx context.Context, actor auth.Actor, o *model.Order) error {
	if err := s.authz.Can(ctx, actor, PermOrderCreate); err != nil {
		return err
	}

	tx, err := s.db.BeginTxx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	if err := s.orderRepo.Insert(ctx, tx, o); err != nil {
		return err
	}

	evt := bus.OrderCreatedEvent{OrderID: o.ID, CompanyID: o.CompanyID}
	if err := s.bus.Publish(ctx, evt.OrderID, evt); err != nil { // SAI: publish trong transaction
		return err
	}

	return tx.Commit()
}

// SAI #2: đẩy Publish vào defer không giải quyết được gì. Lời gọi này KHÔNG nằm
// trong transaction — nó chạy sau khi tx.Commit() phía dưới đã thực thi xong và sau
// khi giá trị trả về đã được tính. Cái sai là nó chạy vô điều kiện: publish cả khi
// Commit() vừa trả lỗi, cả khi hàm return sớm vì Insert thất bại, cả khi
// defer tx.Rollback() sắp chạy ngay sau nó. Lỗi của Publish cũng bị nuốt vì defer
// không có chỗ nhận giá trị trả về.
func (s *OrderService) CreateOrderDeferred(ctx context.Context, actor auth.Actor, o *model.Order) error {
	if err := s.authz.Can(ctx, actor, PermOrderCreate); err != nil {
		return err
	}

	tx, err := s.db.BeginTxx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	evt := bus.OrderCreatedEvent{OrderID: o.ID, CompanyID: o.CompanyID}
	defer s.bus.Publish(ctx, evt.OrderID, evt) // SAI: publish vô điều kiện, bất kể commit hay rollback

	if err := s.orderRepo.Insert(ctx, tx, o); err != nil {
		return err
	}

	return tx.Commit()
}

// SAI #3: publish SAU khi tx.Commit() đã thành công. Đây là biến thể được viện dẫn
// nhiều nhất ("thì tôi commit trước rồi mới publish, có gì sai đâu") và vẫn vi phạm:
// R-05 cấm bus.Publish ở mọi vị trí trong modules/**, không xét vị trí so với
// transaction.
func (s *OrderService) CreateOrderAfterCommit(ctx context.Context, actor auth.Actor, o *model.Order) error {
	if err := s.authz.Can(ctx, actor, PermOrderCreate); err != nil {
		return err
	}

	tx, err := s.db.BeginTxx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	if err := s.orderRepo.Insert(ctx, tx, o); err != nil {
		return err
	}

	if err := tx.Commit(); err != nil {
		return err
	}

	// SAI: giữa dòng Commit() phía trên và dòng Publish phía dưới có một khoảng
	// thời gian mà đơn hàng đã nằm trong DB còn event thì chưa ra khỏi tiến trình.
	// Nếu process chết đúng lúc đó — pod bị kill, panic, mất kết nối bus — event
	// mất vĩnh viễn VÀ không có gì phát hiện được: bảng orders không hề ghi lại
	// rằng có một event đang chờ gửi, nên không ai dò ra để gửi bù. Đây đúng là bài
	// toán dual write mà outbox sinh ra để giải.
	evt := bus.OrderCreatedEvent{OrderID: o.ID, CompanyID: o.CompanyID}
	return s.bus.Publish(ctx, evt.OrderID, evt)
}
```

## Ví dụ ĐÚNG

```go
// erp/shared/outbox/event.go — hợp đồng của bảng outbox
package outbox

import (
	"encoding/json"
	"time"
)

// Event là một dòng của bảng outbox. outbox nằm trong nhóm append_only_tables nên
// có company_id, created_at, created_by; không có updated_at/updated_by/deleted_at.
//
// EventID là khóa dedupe phía consumer. Relay là at-least-once nên cùng một event có
// thể tới hai lần, và consumer chỉ phân biệt được "gửi lại" với "sự kiện mới" nhờ
// giá trị này — vì vậy nó phải được sinh MỘT lần lúc ghi outbox và giữ nguyên qua
// mọi lần relay gửi lại.
type Event struct {
	EventID     string          `db:"event_id"`
	CompanyID   string          `db:"company_id"`
	EventType   string          `db:"event_type"`
	AggregateID string          `db:"aggregate_id"`
	Payload     json.RawMessage `db:"payload"`
	CreatedAt   time.Time       `db:"created_at"`
	CreatedBy   string          `db:"created_by"`
	PublishedAt *time.Time      `db:"published_at"`
}
```

```go
package service

import (
	"context"
	"encoding/json"

	"github.com/google/uuid"
	"github.com/jmoiron/sqlx"

	"erp/modules/order/internal/model"
	"erp/modules/order/internal/repository"
	"erp/shared/auth"
	"erp/shared/authz"
	"erp/shared/outbox"
)

const PermOrderCreate = "order.create"

type OrderService struct {
	db         *sqlx.DB
	authz      authz.Checker
	orderRepo  repository.OrderRepository
	outboxRepo outbox.Repository
}

// ĐÚNG: câu lệnh đầu tiên là kiểm quyền (R-15). Sau đó service mở tx, gọi orderRepo
// rồi outboxRepo trong CÙNG transaction, commit một lần. Không có bus.Publish nào ở
// đây — service không hề biết event bus tồn tại.
func (s *OrderService) CreateOrder(ctx context.Context, actor auth.Actor, o *model.Order) error {
	if err := s.authz.Can(ctx, actor, PermOrderCreate); err != nil {
		return err
	}

	tx, err := s.db.BeginTxx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	if err := s.orderRepo.Insert(ctx, tx, o); err != nil {
		return err
	}

	payload, err := json.Marshal(struct {
		OrderID   string `json:"order_id"`
		CompanyID string `json:"company_id"`
	}{OrderID: o.ID, CompanyID: o.CompanyID})
	if err != nil {
		return err
	}

	evt := outbox.Event{
		// EventID sinh ngay tại đây, bên trong transaction: nếu tx rollback thì id
		// này biến mất cùng dòng outbox, không để lại event mồ côi. Relay không được
		// sinh id mới, nếu không mỗi lần gửi lại sẽ thành một event khác dưới mắt
		// consumer và dedupe theo event_id vô hiệu.
		EventID:     uuid.NewString(),
		CompanyID:   o.CompanyID,
		EventType:   "order.created",
		AggregateID: o.ID,
		CreatedBy:   actor.UserID,
		Payload:     payload,
	}
	if err := s.outboxRepo.Append(ctx, tx, evt); err != nil {
		return err
	}

	return tx.Commit()
}
```

```go
// --- relay: package nằm NGOÀI modules/, chạy ngoài mọi transaction nghiệp vụ ---
package relay

import (
	"context"
	"fmt"
	"time"

	"github.com/jmoiron/sqlx"

	"erp/shared/bus"
	"erp/shared/log"
	"erp/shared/outbox"
)

type Relay struct {
	db         *sqlx.DB
	outboxRepo outbox.Repository
	bus        bus.Publisher
}

// Run là vòng lặp của relay. Publish diễn ra ở đây, sau khi transaction nghiệp vụ đã
// commit từ lâu và hoàn toàn nằm ngoài nó. Nếu Relay chết giữa Publish và
// MarkPublished, lần chạy sau publish lại cùng event_id — đây là lý do handler phía
// consumer PHẢI idempotent theo event_id.
func (r *Relay) Run(ctx context.Context) error {
	ticker := time.NewTicker(time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-ticker.C:
			if err := r.drainBatch(ctx); err != nil {
				// Không nuốt lỗi bằng continue: relay chạy mỗi giây, một lỗi im
				// lặng nghĩa là hàng nghìn lần thử lại mỗi giờ mà không ai biết.
				log.FromContext(ctx).Error("outbox relay: batch that bai", "err", err.Error())
			}
		}
	}
}

func (r *Relay) drainBatch(ctx context.Context) error {
	tx, err := r.db.BeginTxx(ctx, nil)
	if err != nil {
		return fmt.Errorf("begin outbox tx: %w", err)
	}
	defer tx.Rollback()

	// FetchUnpublished PHẢI dùng "SELECT ... WHERE published_at IS NULL
	// ORDER BY created_at LIMIT $1 FOR UPDATE SKIP LOCKED" và phải chạy trong chính
	// transaction này. Không có FOR UPDATE SKIP LOCKED thì hai instance relay chạy
	// song song đọc trúng cùng một batch và mọi event bị gửi hai lần — nhân đôi toàn
	// bộ luồng event chứ không phải trùng lặp lẻ tẻ.
	//
	// Transaction ở đây chỉ giữ khóa trên các dòng outbox, không chứa dữ liệu nghiệp
	// vụ nào: nếu nó rollback sau khi đã publish, hậu quả xấu nhất là gửi lại — đúng
	// phần at-least-once mà consumer đã phải chịu sẵn.
	events, err := r.outboxRepo.FetchUnpublished(ctx, tx, 100)
	if err != nil {
		return fmt.Errorf("fetch outbox: %w", err)
	}

	logger := log.FromContext(ctx)
	for _, evt := range events {
		// EventID đi kèm khi publish: đó là thứ duy nhất consumer dùng để dedupe.
		if err := r.bus.Publish(ctx, evt.EventID, evt); err != nil {
			// break chứ không continue. Nhảy sang event kế tiếp và vẫn gửi nó nghĩa
			// là consumer nhận order.shipped trước order.created của cùng một đơn —
			// thứ tự trong một aggregate vỡ, và không cách nào dựng lại. Dừng cả
			// batch, vòng sau lấy lại đúng từ event lỗi trở đi.
			logger.Error("outbox relay: publish that bai, dung batch",
				"event_id", evt.EventID, "event_type", evt.EventType, "err", err.Error())
			break
		}
		// Không dùng "_ =" ở đây: MarkPublished lỗi mà im lặng thì event này được
		// gửi lại mỗi giây, vô hạn, và không có dòng log nào chỉ ra vì sao.
		if err := r.outboxRepo.MarkPublished(ctx, tx, evt.EventID); err != nil {
			logger.Error("outbox relay: mark published that bai, dung batch",
				"event_id", evt.EventID, "err", err.Error())
			break
		}
	}

	return tx.Commit()
}
```

## Cách kiểm

```powershell
# 1) Moi loi goi Publish trong modules/** deu la vi pham, khong xet vi tri so voi tx
Get-ChildItem -Path modules -Recurse -Filter *.go | Select-String -Pattern '\.Publish\(' | ForEach-Object {
    "{0}:{1}: bus.Publish trong modules/** -> ghi outbox va de relay lo" -f $_.Path, $_.LineNumber
}

# 2) Chi service duoc ghi outbox
Get-ChildItem -Path modules -Recurse -Include *_handler.go, *_repository.go | Select-String -Pattern '\.Append\(\s*ctx' | ForEach-Object {
    "{0}:{1}: ghi outbox ngoai service -> {2}" -f $_.Path, $_.LineNumber, $_.Line.Trim()
}
```

Lệnh (1) không cần soát thủ công thêm bước nào: mọi dòng khớp `\.Publish\(` trong
`modules/**` đều là vi phạm, kể cả khi nó nằm sau `tx.Commit()` hay trong `defer`.
Relay là package duy nhất được publish và nó nằm ngoài `modules/` nên không lọt vào
phạm vi quét này.

Lệnh (2) bắt vế "chỉ service được ghi outbox": một lời gọi `Append(ctx, ...)` trong
`*_handler.go` hoặc `*_repository.go` nghĩa là ranh giới transaction đã trôi ra khỏi
service, và không còn gì bảo đảm event nằm cùng transaction với dữ liệu nghiệp vụ.
