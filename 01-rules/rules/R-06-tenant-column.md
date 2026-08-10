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

Nhưng có điều kiện lọc thôi chưa đủ. Một câu SQL viết đúng đến mấy cũng vô nghĩa nếu
**giá trị** đưa vào `company_id = $1` là do client gửi lên: kẻ tấn công chỉ cần đổi
một field trong JSON body hoặc một tham số trên URL là đọc được dữ liệu công ty khác,
trong khi mọi lệnh grep tìm `company_id =` đều báo xanh. Vì thế giá trị đó bắt buộc
lấy từ `actor.CompanyID` của actor đã xác thực — actor do `shared/middleware/auth`
gắn vào `ctx` sau khi verify token (R-14), handler đọc ra bằng `auth.FromContext(ctx)`
rồi truyền xuống service làm tham số thứ hai theo R-15. Client không có đường nào tác
động tới giá trị đó. DTO request có field `company_id` là dấu hiệu vi phạm ngay cả khi
nó chưa được dùng ở đâu, vì nó mở sẵn đường cho lỗi đó xuất hiện ở lần sửa sau.

Chỗ đọc actor ra khỏi `ctx` được giữ đúng **một**: handler. Service nhận actor qua
tham số nên chữ ký hàm tự nói method này cần actor, test dựng được actor giả mà không
phải nhồi giá trị vào `ctx`, và lời gọi kiểm quyền vẫn giữ được vị trí câu lệnh đầu
tiên mà R-15 đòi — nếu service tự gọi `auth.FromContext(ctx)` thì dòng đó phải đứng
trước `s.authz.Can(...)`, tức là vi phạm R-15 ngay tại chỗ.

### `reference_tables` nằm ngoài phạm vi R-06

Bảng trong `reference_tables` — `currencies`, `units`, `provinces` — là danh mục dùng
chung toàn hệ thống, không thuộc tenant nào, nên **không có `company_id`** và mọi vế
của R-06 không áp lên chúng: không đòi cột, không đòi `company_id = $n` trong `WHERE`,
không có gì để lấy từ actor. Đừng nhầm chúng với bảng nghiệp vụ bị quên cột — khác
biệt nằm ở chỗ tên bảng có trong danh sách `reference_tables` ở
`04-conventions/C-DB-database.md` mục `C-DB-04` hay không, và thêm tên vào danh sách đó
phải viết ADR mới.

Nhưng `reference_tables` chỉ được miễn đúng vế `company_id`. Nó vẫn có đủ
`created_at`, `updated_at`, `deleted_at` (R-08), đủ `created_by`, `updated_by` và vẫn
sinh bản ghi audit khi ghi (R-17), vẫn xóa mềm (R-18). Bản ghi audit sinh ra khi sửa
một danh mục mang `company_id` của actor đã sửa, vì `audit_logs` luôn có `company_id`
kể cả khi bảng bị sửa thì không.

## Ví dụ SAI

### Thiếu điều kiện lọc

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

// SAI nặng hơn: không có mệnh đề WHERE nào cả. Câu này trả về đơn hàng của TẤT CẢ
// các công ty; ở chế độ single-tenant nó vẫn trả đúng kết quả nên không ai để ý.
func (r *orderRepo) ListAll(ctx context.Context, dbtx db.DBTX) ([]Order, error) {
	var out []Order
	query := `SELECT id, company_id, customer_id, total_amount, status, created_at
	          FROM orders
	          ORDER BY created_at DESC`
	if err := dbtx.SelectContext(ctx, &out, query); err != nil {
		return nil, err
	}
	return out, nil
}
```

### `company_id` đến từ client

```go
package handler

import (
	"github.com/gin-gonic/gin"

	"erp/modules/order/internal/service"
	"erp/shared/response"
)

type OrderHandler struct {
	svc *service.OrderService
}

// SAI: DTO request cho phép client tự khai company_id.
type ListOrdersQuery struct {
	CompanyID string `form:"company_id"`
	Page      int    `form:"page"`
	PageSize  int    `form:"page_size"`
	Sort      string `form:"sort"`
}

func (h *OrderHandler) List(c *gin.Context) {
	ctx := c.Request.Context()

	var q ListOrdersQuery
	if err := c.ShouldBindQuery(&q); err != nil {
		response.ValidationFailed(c, err)
		return
	}

	companyID := q.CompanyID
	if companyID == "" {
		companyID = c.Query("company_id") // SAI: cùng một lỗi, viết theo kiểu khác
	}

	// SAI: giá trị do client kiểm soát đi thẳng xuống repository. Câu SQL bên dưới
	// vẫn có "company_id = $1" đầy đủ và mọi lệnh grep vẫn báo xanh — chỉ là tham số
	// truyền vào do kẻ tấn công chọn. Đổi ?company_id=<uuid công ty khác> là xong.
	items, total, err := h.svc.ListOrders(ctx, companyID, q.Page, q.PageSize, q.Sort)
	if err != nil {
		response.Error(c, err)
		return
	}
	response.List(c, items, total, q.Page, q.PageSize)
}
```

## Ví dụ ĐÚNG

### Điều kiện lọc trong mọi câu SQL

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

### `company_id` lấy từ `actor.CompanyID`

```go
package handler

import (
	"github.com/gin-gonic/gin"

	"erp/modules/order/internal/service"
	"erp/shared/auth"
	"erp/shared/response"
)

type OrderHandler struct {
	svc *service.OrderService
}

// ĐÚNG: DTO không có chỗ nào cho company_id — client không được hỏi về nó.
type ListOrdersQuery struct {
	Page     int    `form:"page"`
	PageSize int    `form:"page_size"`
	Sort     string `form:"sort"`
}

func (h *OrderHandler) List(c *gin.Context) {
	ctx := c.Request.Context()

	var q ListOrdersQuery
	if err := c.ShouldBindQuery(&q); err != nil {
		response.ValidationFailed(c, err)
		return
	}

	// ĐÚNG: handler là nơi DUY NHẤT đọc actor ra khỏi ctx (R-15). shared/middleware/auth
	// đã gắn actor vào ctx sau khi verify token (R-14); từ đây trở xuống actor đi bằng
	// tham số, không ai moi lại từ ctx nữa.
	actor := auth.FromContext(ctx)

	items, total, err := h.svc.ListOrders(ctx, actor, service.ListOrdersInput{
		Page:     q.Page,
		PageSize: q.PageSize,
		Sort:     q.Sort,
	})
	if err != nil {
		response.Error(c, err)
		return
	}
	response.List(c, items, total, q.Page, q.PageSize)
}
```

```go
package service

import (
	"context"

	"github.com/jmoiron/sqlx"

	"erp/modules/order/internal/model"
	"erp/modules/order/internal/repository"
	"erp/shared/auth"
	"erp/shared/authz"
)

const PermOrderRead = "order.read"

type OrderService struct {
	db        *sqlx.DB
	authz     authz.Checker
	orderRepo repository.OrderRepository
}

type ListOrdersInput struct {
	Page     int
	PageSize int
	Sort     string
}

// ĐÚNG: actor là tham số thứ hai, ngay sau ctx (R-15), nên câu lệnh đầu tiên của
// method vẫn là lời gọi kiểm quyền — không cần dòng nào moi actor ra khỏi ctx trước
// đó. company_id lấy từ actor.CompanyID; ListOrdersInput không có field company_id,
// nên không có đường cho client chèn giá trị của công ty khác vào.
func (s *OrderService) ListOrders(ctx context.Context, actor auth.Actor, in ListOrdersInput) ([]model.Order, int, error) {
	if err := s.authz.Can(ctx, actor, PermOrderRead); err != nil {
		return nil, 0, err
	}

	return s.orderRepo.List(ctx, s.db, actor.CompanyID, in.Page, in.PageSize, in.Sort)
}
```

## Cách kiểm

```powershell
# 1) Tung cau SQL trong repository: thieu company_id trong WHERE, hoac SELECT khong co WHERE
# Ba nhom bang khong co company_id nen khong bi kiem: system_tables, tenant_root va
# reference_tables. Chep tu 04-conventions/C-DB-database.md muc C-DB-04, khong tu them
# ten o day.
$systemTables    = @('schema_migrations')
$tenantRoot      = @('companies')
$referenceTables = @('currencies', 'units', 'provinces')
$noTenantTables  = $systemTables + $tenantRoot + $referenceTables

Get-ChildItem -Path modules -Recurse -Filter *_repository*.go | ForEach-Object {
    $file = $_.FullName
    $text = Get-Content -Path $file -Raw
    if (-not $text) { return }

    # Tach TUNG chuoi SQL truoc (Go raw string khong chua duoc backtick nen dau
    # backtick la ranh gioi tin cay), roi kiem tung cau doc lap.
    foreach ($lit in [regex]::Matches($text, '(?s)`([^`]*)`')) {
        $sql = ($lit.Groups[1].Value -replace '\s+', ' ').Trim()
        if ($sql -notmatch '(?i)\b(SELECT|UPDATE|DELETE)\b') { continue }

        # Bo qua cau chi dung tren bang khong co company_id
        $tables = @([regex]::Matches($sql, '(?i)\b(?:FROM|JOIN|UPDATE)\s+([a-z_][a-z0-9_]*)') |
                    ForEach-Object { $_.Groups[1].Value.ToLower() })
        if ($tables.Count -gt 0) {
            $tenantScoped = @($tables | Where-Object { $noTenantTables -notcontains $_ })
            if ($tenantScoped.Count -eq 0) { continue }
        }

        if ($sql -notmatch '(?i)\bWHERE\b') {
            if ($sql -match '(?i)^SELECT\b') {
                Write-Host ("{0}: SELECT bang nghiep vu KHONG co WHERE -> {1}" -f $file, $sql)
            }
            continue
        }
        if ($sql -notmatch 'company_id\s*=') {
            Write-Host ("{0}: thieu company_id trong WHERE -> {1}" -f $file, $sql)
        }
    }
}

# 2) company_id den tu client: DTO request hoac handler doc thang tu request
Get-ChildItem -Path modules -Recurse -Include *.go |
    Select-String -Pattern '(json|form|uri):"company_id"', 'c\.(Query|Param|PostForm)\("company_id"\)' |
    ForEach-Object { "{0}:{1}: company_id den tu client -> {2}" -f $_.Path, $_.LineNumber, $_.Line.Trim() }
```

Lệnh (1) tách từng chuỗi SQL **trước**, rồi kiểm từng chuỗi độc lập. Đây là điểm
khác biệt quan trọng so với cách quét cả file bằng một regex `(?s)...WHERE...`: với
`(?s)` thì dấu `.` khớp cả xuống dòng, nên nếu câu SQL đầu tiên trong file không có
`WHERE` — tức là đọc toàn bảng, kịch bản rò rỉ tệ nhất — phần `.*?` sẽ nuốt qua nó để
tìm tới `WHERE` của câu kế tiếp; nếu câu kế tiếp có `company_id` thì script báo "không
vi phạm", và câu thứ hai cũng đã bị tiêu thụ nên không bao giờ được kiểm riêng. Hai
câu SQL, một lần kiểm, cả hai lọt.

Vì vậy lệnh (1) báo riêng hai loại: `SELECT` trên bảng nghiệp vụ **không có mệnh đề
`WHERE`** (nguy hiểm nhất, đọc sạch mọi công ty), và câu có `WHERE` nhưng thiếu
`company_id =`. Câu SQL chỉ đụng tới bảng không có `company_id` — `system_tables`
(`schema_migrations`), `tenant_root` (`companies`) và `reference_tables` (`currencies`,
`units`, `provinces`) — được bỏ qua để không báo oan. Ba danh sách trong script phải
chép từ `04-conventions/C-DB-database.md` mục `C-DB-04`; sửa danh sách ở đây mà không
sửa registry là làm sai lệch nguồn sự thật, không phải sửa lỗi script.

Lệnh (2) bắt vế nguồn của giá trị: mỗi dòng in ra là một chỗ `company_id` do client
gửi lên. Loại này lệnh (1) không thấy được, vì câu SQL tương ứng vẫn có đủ
`company_id = $1`.
