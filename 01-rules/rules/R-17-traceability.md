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

Một bản ghi audit chỉ có giá trị nếu trả lời đủ bốn câu: **công ty nào**, **ai**,
**làm gì trên bản ghi nào**, **qua request nào**. `company_id` bắt buộc vì `audit_logs`
cũng chịu R-06 — không có nó thì màn hình tra cứu lịch sử của công ty A đọc được thao
tác của công ty B, đúng lỗ hổng mà R-06 sinh ra để chặn. `request_id` bắt buộc vì đó
là điểm giao duy nhất giữa R-17 và P-OBS: nó nối một dòng trong `audit_logs` với toàn
bộ log kỹ thuật, span, và các bản ghi audit khác sinh ra từ **cùng một** request HTTP.
Thiếu nó, khi cần dựng lại "chuyện gì đã xảy ra lúc 14:03" thì chỉ có các sự kiện rời
rạc, không ghép lại được thành một hành động của người dùng.

### `audit_logs` nằm trong nhóm `append_only_tables`

`audit_logs` không phải bảng nghiệp vụ, không phải `system_tables`, cũng không phải
`reference_tables`; nó thuộc nhóm `append_only_tables`, cùng với `outbox`. Cụ thể với
R-17, điều đó nghĩa là:

- **Có** `company_id` (R-06 áp bình thường), **có** `created_at`, **có** `created_by`
  — chính là actor gây ra thao tác được ghi lại.
- **Miễn** `updated_at`, `updated_by`, `deleted_at`. Một dòng audit đã ghi thì không
  bao giờ được sửa hay xóa mềm; nếu sửa được thì nó mất luôn giá trị làm bằng chứng.
- **Miễn sinh bản ghi audit cho chính thao tác ghi vào nó.** Đây không phải ưu ái mà
  là điều kiện để hệ thống chạy được: nếu mỗi lần ghi `audit_logs` lại sinh thêm một
  bản ghi audit, mỗi thao tác nghiệp vụ sẽ kéo theo một chuỗi đệ quy vô hạn và
  transaction không bao giờ kết thúc. Cùng lý do đó áp cho `outbox`.
- Được **hard delete theo lịch giữ liệu** (R-18), không cần ADR riêng — vì đó là dọn
  dữ liệu hết hạn theo chính sách, không phải xóa một bản ghi cụ thể để che dấu vết.

Nói cách khác, nhóm `append_only_tables` tồn tại chính vì hai bảng này: chúng cần
`company_id` và `created_by` như bảng nghiệp vụ, nhưng phải nằm ngoài vòng
sửa/xóa/audit mà bảng nghiệp vụ phải theo. Nguồn sự thật của danh sách là
`04-conventions/C-DB-database.md` mục `C-DB-04`.

### Bảng trong `reference_tables` vẫn sinh bản ghi audit

`reference_tables` (`currencies`, `units`, `provinces`) không được miễn gì ở R-17: có
đủ `created_by` và `updated_by`, và mọi thao tác ghi lên nó vẫn phải sinh một dòng
`audit_logs` trong cùng transaction. Đó chính là lý do nhóm này tách khỏi
`system_tables` — danh mục có người sửa, và sửa một danh mục dùng chung thì ảnh hưởng
tới mọi tenant, nên càng cần biết ai sửa.

Điểm cần chú ý: bảng bị sửa không có `company_id`, nhưng dòng `audit_logs` sinh ra thì
vẫn có — giá trị lấy từ `actor.CompanyID`, tức công ty của người đã sửa. Không có mâu
thuẫn ở đây: `audit_logs` chịu R-06 như mọi bảng có `company_id` khác, và câu hỏi mà
nó trả lời là "ai đã sửa", chứ không phải "bản ghi bị sửa thuộc công ty nào".

## Ví dụ SAI

```go
package service

import (
	"context"

	"github.com/jmoiron/sqlx"

	"erp/modules/order/internal/repository"
	"erp/shared/audit"
	"erp/shared/auth"
	"erp/shared/authz"
	"erp/shared/requestid"
)

const PermOrderUpdate = "order.update"

type OrderService struct {
	db        *sqlx.DB
	authz     authz.Checker
	orderRepo repository.OrderRepository
	auditRepo audit.Repository
}

func (s *OrderService) UpdateStatus(ctx context.Context, actor auth.Actor, orderID, newStatus string) error {
	if err := s.authz.Can(ctx, actor, PermOrderUpdate); err != nil {
		return err
	}

	tx, err := s.db.BeginTxx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	if err := s.orderRepo.UpdateStatus(ctx, tx, actor.CompanyID, orderID, newStatus, actor.UserID); err != nil {
		return err
	}

	if err := tx.Commit(); err != nil {
		return err
	}

	// SAI: ghi audit SAU khi transaction đã commit, bằng s.db (không phải tx).
	// Nếu tiến trình chết ngay tại dòng này, đơn hàng đã đổi trạng thái thật
	// nhưng audit trail không hề biết chuyện đó xảy ra.
	return s.auditRepo.Record(ctx, s.db, audit.Entry{
		CompanyID: actor.CompanyID,
		ActorID:   actor.UserID,
		RequestID: requestid.FromContext(ctx),
		Action:    "order.status_updated",
		EntityID:  orderID,
	})
}
```

## Ví dụ ĐÚNG

```go
// erp/shared/audit/entry.go
package audit

import "time"

// Entry là một dòng của bảng audit_logs — bảng thuộc nhóm append_only_tables.
//
// CompanyID: audit_logs cũng chịu R-06, thiếu cột này thì màn hình tra cứu lịch sử
// của công ty A đọc được thao tác của công ty B.
// RequestID: điểm giao giữa R-17 và P-OBS, nối bản ghi audit này với log kỹ thuật
// và với mọi bản ghi audit khác sinh ra từ cùng một request HTTP.
// ActorID ánh xạ xuống cột created_by — created_by của một dòng audit chính là
// người đã gây ra thao tác được ghi lại.
type Entry struct {
	CompanyID string    `db:"company_id"`
	ActorID   string    `db:"created_by"`
	RequestID string    `db:"request_id"`
	Action    string    `db:"action"`
	EntityID  string    `db:"entity_id"`
	CreatedAt time.Time `db:"created_at"`
}
```

```go
package service

import (
	"context"

	"github.com/jmoiron/sqlx"

	"erp/modules/order/internal/repository"
	"erp/shared/audit"
	"erp/shared/auth"
	"erp/shared/authz"
	"erp/shared/requestid"
)

const PermOrderUpdate = "order.update"

type OrderService struct {
	db        *sqlx.DB
	authz     authz.Checker
	orderRepo repository.OrderRepository
	auditRepo audit.Repository
}

// ĐÚNG: actor là tham số thứ hai ngay sau ctx, nên câu lệnh đầu tiên của method vẫn
// là kiểm quyền (R-15). Sau đó auditRepo.Record nhận cùng DBTX (tx) với repository
// nghiệp vụ, gọi trước khi commit — audit và dữ liệu nghiệp vụ commit hoặc rollback
// cùng nhau, không thể có chuyện một cái tồn tại mà cái kia thì không. CompanyID lấy
// từ actor mà handler truyền xuống, RequestID lấy từ ctx; không cái nào nhận từ
// tham số client.
func (s *OrderService) UpdateStatus(ctx context.Context, actor auth.Actor, orderID, newStatus string) error {
	if err := s.authz.Can(ctx, actor, PermOrderUpdate); err != nil {
		return err
	}

	tx, err := s.db.BeginTxx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	if err := s.orderRepo.UpdateStatus(ctx, tx, actor.CompanyID, orderID, newStatus, actor.UserID); err != nil {
		return err
	}

	if err := s.auditRepo.Record(ctx, tx, audit.Entry{
		CompanyID: actor.CompanyID,
		ActorID:   actor.UserID,
		RequestID: requestid.FromContext(ctx),
		Action:    "order.status_updated",
		EntityID:  orderID,
	}); err != nil {
		return err
	}

	return tx.Commit()
}
```

```sql
-- migrations/000012_create_audit_logs.up.sql

-- audit_logs thuoc nhom append_only_tables: co company_id, created_at, created_by;
-- KHONG co updated_at, updated_by, deleted_at. Mot dong da ghi thi khong bao gio
-- duoc sua, nen khong co cot nao mo duong cho viec do.
CREATE TABLE audit_logs (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id),
    request_id TEXT NOT NULL,
    action     TEXT NOT NULL,
    entity_id  UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID NOT NULL
);

CREATE INDEX idx_audit_logs_company_id_entity_id ON audit_logs(company_id, entity_id);
CREATE INDEX idx_audit_logs_company_id_request_id ON audit_logs(company_id, request_id);
```

## Cách kiểm

```powershell
# 1) Audit co dang duoc ghi SAU tx.Commit()?
Get-ChildItem -Path modules -Recurse -Filter *_service*.go | ForEach-Object {
    $raw = Get-Content -Path $_.FullName -Raw
    $hit = $raw | Select-String -Pattern '(?s)tx\.Commit\(\).*\.Record\('
    if ($hit) {
        Write-Host ("{0}: audit co the dang goi SAU tx.Commit() - kiem tra thu cong" -f $_.FullName)
    }
}

# 2) Bang nghiep vu moi tao co du created_by / updated_by chua?
# tenant_root (companies) va reference_tables khong xuat hien o day la co y: ca hai
# khong duoc mien gi o R-17 nen roi vao nhanh "moi bang con lai" - doi ca created_by
# lan updated_by, dung nhu bang nghiep vu.
$systemTables     = @('schema_migrations')
$appendOnlyTables = @('outbox', 'audit_logs')

Get-ChildItem -Path migrations -Filter *.up.sql | ForEach-Object {
    $file = $_.Name
    $text = Get-Content -Path $_.FullName -Raw
    if (-not $text) { return }
    foreach ($m in [regex]::Matches($text, '(?is)CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?([a-z_][a-z0-9_]*)\s*\((.*?)\r?\n\s*\)\s*;')) {
        $table = $m.Groups[1].Value.ToLower()
        $body  = $m.Groups[2].Value
        if ($systemTables -contains $table) { continue }

        $need = @('created_by')
        if ($appendOnlyTables -notcontains $table) { $need += 'updated_by' }
        foreach ($col in $need) {
            if ($body -notmatch ('(?im)^\s*' + $col + '\s')) {
                Write-Host ("{0}: bang '{1}' thieu cot {2}" -f $file, $table, $col)
            }
        }
    }
}
```

Lệnh (1) đọc toàn bộ nội dung mỗi file `*_service.go` rồi tìm bất kỳ chỗ nào chuỗi
`tx.Commit()` xuất hiện trước một lời gọi `.Record(` ở phía sau trong cùng file —
dấu hiệu audit đang được ghi sau khi transaction đã commit. Đây là heuristic theo
file, không phải theo hàm, nên mọi kết quả khớp cần đọc lại thủ công để xác nhận cả
hai lời gọi thuộc cùng một method trước khi kết luận vi phạm.

Lệnh (2) kiểm vế cột của R-17 và áp đúng năm nhóm bảng: `system_tables` bỏ qua hoàn
toàn; `append_only_tables` chỉ đòi `created_by`; `tenant_root`, `reference_tables` và
mọi bảng nghiệp vụ đòi cả `created_by` lẫn `updated_by` — vì vậy `tenant_root` và
`reference_tables` không cần một danh sách riêng trong script, chúng rơi đúng vào
nhánh mặc định. Hai danh sách trong script phải được chép từ
`04-conventions/C-DB-database.md` mục `C-DB-04` — sửa danh sách ở đây mà không sửa
registry là làm sai lệch nguồn sự thật, không phải sửa lỗi script. Lệnh này cắt khối
`CREATE TABLE ... );` theo dấu `);` đứng riêng một dòng, nên migration viết dồn tất cả
lên một dòng sẽ không được kiểm — đổi lại nó không cần parser SQL đầy đủ.
