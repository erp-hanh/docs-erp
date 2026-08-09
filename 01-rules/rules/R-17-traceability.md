# R-17 — Traceability

Trang này mở rộng entry trong [../RULES.md](../RULES.md). Mệnh đề bắt buộc nằm ở đó,
không lặp lại ở đây.

## Vì sao

Audit ghi ngoài transaction tạo ra một lớp bug đặc biệt xấu: nó không làm mất dữ
liệu, nó làm **sổ sách nói dối**. Nếu service cập nhật đơn hàng trong một transaction
rồi mới gọi `auditRepo.Record(...)` sau khi transaction đã commit, hai tình huống
đều tệ như nhau. Nếu tiến trình chết đúng giữa hai bước — panic, pod bị kill, mất kết
nối DB ngay sau `tx.Commit()` — dữ liệu nghiệp vụ đã đổi thật nhưng audit trail không
hề ghi nhận ai đã làm việc đó, lúc nào, qua request nào. Ngược lại, nếu audit được
ghi vội trước khi biết transaction có thành công hay không, và transaction sau đó
rollback, audit lại khẳng định một hành động chưa từng xảy ra trong dữ liệu thật.

Với hệ thống ERP có yêu cầu kiểm toán, đây là lỗi nghiêm trọng hơn cả mất dữ liệu.
Mất dữ liệu thì biết là đã mất, có thể phát hiện và bù. Audit trail sai lệch thì
không tự lộ ra — nó nằm im, trông có vẻ đầy đủ và đáng tin, cho tới ngày có tranh
chấp hoặc thanh tra cần đối chiếu, lúc đó phát hiện log nói một đằng, dữ liệu nói
một nẻo. Một bản ghi audit sai đã đủ để làm mất giá trị pháp lý của toàn bộ audit
trail, vì không còn cách nào phân biệt bản ghi nào đáng tin, bản ghi nào không.

Cách duy nhất loại bỏ toàn bộ lớp bug này là không coi audit là một bước "thêm vào
sau" — audit là một bảng khác trong cùng transaction, nhận cùng `DBTX` như mọi
repository nghiệp vụ khác. Khi đó audit và dữ liệu nghiệp vụ commit hoặc rollback
cùng nhau theo đúng tính atomic mà Postgres đã đảm bảo sẵn, không cần thêm cơ chế gì.

## Ví dụ SAI

```go
package service

import (
	"context"

	"github.com/jmoiron/sqlx"

	"erp/modules/order/internal/repository"
	"erp/shared/audit"
)

type OrderService struct {
	db        *sqlx.DB
	orderRepo repository.OrderRepository
	auditRepo audit.Repository
}

func (s *OrderService) UpdateStatus(ctx context.Context, orderID, newStatus, actorID string) error {
	tx, err := s.db.BeginTxx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	if err := s.orderRepo.UpdateStatus(ctx, tx, orderID, newStatus, actorID); err != nil {
		return err
	}

	if err := tx.Commit(); err != nil {
		return err
	}

	// SAI: ghi audit SAU khi transaction đã commit, bằng s.db (không phải tx).
	// Nếu tiến trình chết ngay tại dòng này, đơn hàng đã đổi trạng thái thật
	// nhưng audit trail không hề biết chuyện đó xảy ra.
	return s.auditRepo.Record(ctx, s.db, audit.Entry{
		ActorID:  actorID,
		Action:   "order.status_updated",
		EntityID: orderID,
	})
}
```

## Ví dụ ĐÚNG

```go
package service

import (
	"context"

	"github.com/jmoiron/sqlx"

	"erp/modules/order/internal/repository"
	"erp/shared/audit"
)

type OrderService struct {
	db        *sqlx.DB
	orderRepo repository.OrderRepository
	auditRepo audit.Repository
}

// ĐÚNG: auditRepo.Record nhận cùng DBTX (tx) với repository nghiệp vụ, gọi trước
// khi commit. Audit và dữ liệu nghiệp vụ commit hoặc rollback cùng nhau — không thể
// có chuyện một cái tồn tại mà cái kia thì không.
func (s *OrderService) UpdateStatus(ctx context.Context, orderID, newStatus, actorID string) error {
	tx, err := s.db.BeginTxx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	if err := s.orderRepo.UpdateStatus(ctx, tx, orderID, newStatus, actorID); err != nil {
		return err
	}

	if err := s.auditRepo.Record(ctx, tx, audit.Entry{
		ActorID:  actorID,
		Action:   "order.status_updated",
		EntityID: orderID,
	}); err != nil {
		return err
	}

	return tx.Commit()
}
```

## Cách kiểm

```powershell
Get-ChildItem -Path modules -Recurse -Filter *_service*.go | ForEach-Object {
    $raw = Get-Content -Path $_.FullName -Raw
    $hit = $raw | Select-String -Pattern '(?s)tx\.Commit\(\).*\.Record\('
    if ($hit) {
        Write-Host ("{0}: audit co the dang goi SAU tx.Commit() - kiem tra thu cong" -f $_.FullName)
    }
}
```

Lệnh trên đọc toàn bộ nội dung mỗi file `*_service.go` rồi tìm bất kỳ chỗ nào chuỗi
`tx.Commit()` xuất hiện trước một lời gọi `.Record(` ở phía sau trong cùng file —
dấu hiệu audit đang được ghi sau khi transaction đã commit. Đây là heuristic theo
file, không phải theo hàm, nên mọi kết quả khớp cần đọc lại thủ công để xác nhận cả
hai lời gọi thuộc cùng một method trước khi kết luận vi phạm.
