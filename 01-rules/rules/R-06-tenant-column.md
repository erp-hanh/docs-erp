# R-06 — Tenant Column Everywhere

Trang này mở rộng entry trong [../RULES.md](../RULES.md). Mệnh đề bắt buộc nằm ở đó,
không lặp lại ở đây.

## Vì sao

Thiếu `company_id` trong mệnh đề `WHERE` **không phải lỗi hiệu năng — đó là lỗ hổng
rò rỉ dữ liệu giữa các công ty**. Một query như `SELECT * FROM orders WHERE id = $1`
không lọc theo công ty nghĩa là bất kỳ ai đăng nhập hợp lệ, thuộc công ty nào cũng
được, chỉ cần biết (hoặc đoán, hoặc duyệt tuần tự) một UUID đơn hàng, là đọc được
đơn hàng đó — kể cả khi nó thuộc về một công ty hoàn toàn khác. Đây không phải lỗi
kiểu crash hay trả sai định dạng dễ thấy trong test; nó là một endpoint trả **đúng
dữ liệu**, chỉ là dữ liệu của người khác.

Điều nguy hiểm nhất của lớp bug này là nó vô hình ở chế độ vận hành hiện tại. Hệ
thống đang chạy single-tenant — khi chỉ có một `company_id` tồn tại trong toàn bộ
database, một query thiếu điều kiện lọc theo công ty vẫn trả về đúng kết quả mong
đợi, vì "mọi bản ghi" và "bản ghi của công ty duy nhất đang có" tình cờ là cùng một
tập hợp. Test pass, staging pass, demo pass. Bug chỉ phát nổ đúng ngày công ty thứ
hai được onboard lên cùng database — và lúc đó nó không còn là bug nội bộ nữa, mà là
sự cố rò rỉ dữ liệu khách hàng thật, giữa hai khách hàng thật, với đầy đủ hệ quả pháp
lý và uy tín. Rule này tồn tại để bug đó không có cơ hội được viết ra từ đầu, thay vì
để phát hiện nó sau khi đã có khách hàng thứ hai.

Vì vậy điều kiện `company_id = $n` không phải một optimization có thể thêm sau —
nó phải có mặt ở **mọi** câu SQL đọc/sửa/xóa bảng nghiệp vụ, ngay từ dòng code đầu
tiên, bất kể lúc viết ra hệ thống có bao nhiêu tenant.

## Ví dụ SAI

```go
package repository

import (
	"context"

	"erp/shared/db"
)

type orderRepo struct{}

// SAI: không lọc theo company_id. Bất kỳ user nào, thuộc công ty nào, biết được id
// đơn hàng đều đọc được nó — kể cả đơn hàng của công ty khác.
func (r *orderRepo) GetByID(ctx context.Context, dbtx db.DBTX, id string) (*Order, error) {
	var o Order
	query := `SELECT id, company_id, customer_id, total_amount, status, created_at
	          FROM orders
	          WHERE id = $1`
	if err := dbtx.GetContext(ctx, &o, query, id); err != nil {
		return nil, err
	}
	return &o, nil
}
```

## Ví dụ ĐÚNG

```go
package repository

import (
	"context"

	"erp/shared/db"
)

type orderRepo struct{}

// ĐÚNG: company_id giới hạn kết quả về đúng phạm vi công ty của actor đang gọi;
// deleted_at IS NULL theo R-18 để không trả về bản ghi đã xóa mềm.
func (r *orderRepo) GetByID(ctx context.Context, dbtx db.DBTX, companyID, id string) (*Order, error) {
	var o Order
	query := `SELECT id, company_id, customer_id, total_amount, status, created_at
	          FROM orders
	          WHERE company_id = $1 AND id = $2 AND deleted_at IS NULL`
	if err := dbtx.GetContext(ctx, &o, query, companyID, id); err != nil {
		return nil, err
	}
	return &o, nil
}
```

`companyID` ở đây phải đến từ actor đã xác thực (`auth.FromContext(ctx)` ở tầng
service theo R-14/R-15), không bao giờ được đọc từ tham số do client tự gửi lên —
nếu không, cùng một điều kiện `company_id = $1` vẫn có thể bị client thao túng để
truyền `company_id` của công ty khác.

## Cách kiểm

```powershell
Get-ChildItem -Path modules -Recurse -Filter *_repository*.go | ForEach-Object {
    $text = Get-Content -Path $_.FullName -Raw
    $stmts = [regex]::Matches($text, '(?is)(SELECT|UPDATE|DELETE)\b.*?\bWHERE\b[^;`"]*')
    foreach ($m in $stmts) {
        if ($m.Value -notmatch 'company_id\s*=') {
            Write-Host ("{0}: thieu company_id trong WHERE -> {1}" -f $_.FullName, ($m.Value -replace '\s+',' '))
        }
    }
}
```

Lệnh trên trích mọi câu `SELECT`/`UPDATE`/`DELETE` có `WHERE` trong file
`*_repository.go` (kể cả khi câu SQL viết trên nhiều dòng bằng backtick) rồi báo ra
những câu không chứa `company_id =`. Mỗi dòng in ra là một ứng viên rò rỉ dữ liệu
cần soát thủ công ngay, không đợi review theo lịch thường.
