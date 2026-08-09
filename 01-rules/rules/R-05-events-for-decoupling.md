# R-05 — Events for Decoupling

Trang này mở rộng entry trong [../RULES.md](../RULES.md). Mệnh đề bắt buộc nằm ở đó,
không lặp lại ở đây.

## Vì sao

Publish trong transaction là một con bug im lặng: nếu transaction rollback sau khi
`bus.Publish` đã chạy, event đã bay ra khỏi tiến trình rồi — không cách nào gọi nó
về. Consumer (ví dụ module Inventory trừ tồn kho khi nhận `order.created`) xử lý
một sự kiện mô tả một đơn hàng chưa từng tồn tại trong database. Bọc `bus.Publish`
trong `defer` không cứu được gì: `defer` vẫn chạy trong cùng lời gọi hàm đó, không
biết `tx.Commit()` phía dưới có lỗi hay không, và vẫn chạy dù hàm return sớm vì lỗi
ở giữa.

Ngược lại, nếu publish đúng lúc — sau khi transaction đã commit thành công — nhưng
gọi thẳng `bus.Publish` từ code nghiệp vụ thay vì qua outbox, thì lộ ra vấn đề khác:
ghi DB và publish lên message bus là hai hệ thống riêng biệt, không có cơ chế nào
đảm bảo cả hai cùng thành công hoặc cùng thất bại (bài toán "dual write" kinh điển).
Nếu tiến trình chết đúng giữa hai bước đó — pod bị kill, panic, mất kết nối — dữ liệu
đã nằm trong DB nhưng event thì mất vĩnh viễn, không ai biết để gửi lại.

Outbox giải quyết cả hai bằng cách biến "ghi DB + gửi event" thành một transaction
Postgres duy nhất: bảng `outbox` chỉ là một bảng khác trong cùng transaction, cùng
commit hoặc cùng rollback với dữ liệu nghiệp vụ. Việc publish thật sự lên bus được
tách ra cho một relay riêng, chạy sau, đọc `outbox` và gửi đi. Cái giá phải trả là
relay không thể biết chắc một lần gửi trước đó có tới nơi hay không nếu nó chết giữa
chừng — nên nó gửi lại. Đó là lý do publish trở thành **at-least-once**: mọi event
handler phải idempotent theo `event_id`, nếu không một event gửi trùng sẽ tạo ra hai
lần hiệu ứng (trừ kho hai lần, gửi email hai lần) từ một hành động nghiệp vụ chỉ xảy
ra một lần.

## Ví dụ SAI

```go
package service

import (
	"context"

	"github.com/jmoiron/sqlx"

	"erp/modules/order/internal/model"
	"erp/modules/order/internal/repository"
	"erp/shared/bus"
)

type OrderService struct {
	db        *sqlx.DB
	orderRepo repository.OrderRepository
	bus       bus.Publisher
}

// SAI #1: publish ngay trong transaction, trước khi biết tx.Commit() có thành công
// hay không. Nếu Commit() thất bại ở dòng cuối (deadlock, mất kết nối), đơn hàng
// chưa từng tồn tại trong orders nhưng event order.created đã ra tới bus.
func (s *OrderService) CreateOrder(ctx context.Context, o *model.Order) error {
	tx, err := s.db.BeginTxx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	if err := s.orderRepo.Insert(ctx, tx, o); err != nil {
		return err
	}

	evt := bus.OrderCreatedEvent{OrderID: o.ID, CompanyID: o.CompanyID}
	if err := s.bus.Publish(ctx, evt); err != nil { // SAI: publish trong transaction
		return err
	}

	return tx.Commit()
}

// SAI #2: đẩy Publish vào defer không giải quyết được gì — defer vẫn chạy trong
// cùng lời gọi hàm này, không biết tx.Commit() phía dưới có lỗi hay không, và vẫn
// chạy cả khi hàm return sớm vì lỗi ở giữa (ví dụ Insert thất bại).
func (s *OrderService) CreateOrderDeferred(ctx context.Context, o *model.Order) error {
	tx, err := s.db.BeginTxx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	evt := bus.OrderCreatedEvent{OrderID: o.ID, CompanyID: o.CompanyID}
	defer s.bus.Publish(ctx, evt) // SAI: defer bus.Publish vẫn là publish trong transaction

	if err := s.orderRepo.Insert(ctx, tx, o); err != nil {
		return err
	}

	return tx.Commit()
}
```

## Ví dụ ĐÚNG

```go
package service

import (
	"context"
	"encoding/json"

	"github.com/jmoiron/sqlx"

	"erp/modules/order/internal/model"
	"erp/modules/order/internal/repository"
	"erp/shared/outbox"
)

type OrderService struct {
	db         *sqlx.DB
	orderRepo  repository.OrderRepository
	outboxRepo outbox.Repository
}

// ĐÚNG: service mở tx, gọi orderRepo rồi outboxRepo trong CÙNG transaction, commit
// một lần. Không có bus.Publish nào ở đây — service không hề biết event bus tồn tại.
func (s *OrderService) CreateOrder(ctx context.Context, o *model.Order) error {
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
		CompanyID:   o.CompanyID,
		EventType:   "order.created",
		AggregateID: o.ID,
		Payload:     payload,
	}
	if err := s.outboxRepo.Append(ctx, tx, evt); err != nil {
		return err
	}

	return tx.Commit()
}
```

```go
// --- relay: tiến trình riêng, chạy ngoài mọi transaction nghiệp vụ ---
package relay

import (
	"context"
	"time"

	"github.com/jmoiron/sqlx"

	"erp/shared/bus"
	"erp/shared/outbox"
)

type Relay struct {
	db         *sqlx.DB
	outboxRepo outbox.Repository
	bus        bus.Publisher
}

// Run publish diễn ra SAU commit, không nằm trong transaction nghiệp vụ nào cả.
// Nếu Relay chết giữa Publish và MarkPublished, lần chạy sau publish lại cùng
// event_id — đây là lý do handler phía consumer PHẢI idempotent theo event_id.
func (r *Relay) Run(ctx context.Context) error {
	ticker := time.NewTicker(time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-ticker.C:
			events, err := r.outboxRepo.FetchUnpublished(ctx, r.db, 100)
			if err != nil {
				continue
			}
			for _, evt := range events {
				if err := r.bus.Publish(ctx, evt); err != nil {
					continue // thử lại ở vòng sau — at-least-once
				}
				_ = r.outboxRepo.MarkPublished(ctx, r.db, evt.ID)
			}
		}
	}
}
```

## Cách kiểm

```powershell
# Mọi lời gọi Publish trong file service — cần soát thủ công xem có nằm trong tx không
Get-ChildItem -Path modules -Recurse -Filter *_service*.go | Select-String -Pattern '\.Publish\('

# Cờ đỏ tức thời: defer ngay trước một lời gọi Publish
Get-ChildItem -Path modules -Recurse -Filter *_service*.go | Select-String -Pattern 'defer\s+\S+\.Publish\('
```

Bất kỳ dòng nào khớp `\.Publish\(` trong `*_service.go` đều phải bị coi là khả nghi
cho tới khi xác minh nó không nằm trong khối có `tx`/`BeginTxx`. Dòng khớp
`defer\s+\S+\.Publish\(` là vi phạm chắc chắn — không có cách dùng `defer` nào cho
`bus.Publish` là hợp lệ theo rule này.
