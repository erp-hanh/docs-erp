# C-GO — Quy ước Go backend

Convention nằm **giữa** Rule và Code. Rule nói *"service sở hữu ranh giới transaction"*;
file này nói *"chữ ký repository viết ra sao để việc đó grep được"*. Rule trả lời **cái gì
bắt buộc đúng**, Convention trả lời **viết ra như thế nào**, cụ thể tới từng ký tự.

Vì vậy file này **không phải nguồn sự thật** cho bất cứ thứ gì Rule, Principle hay ADR đã
quyết. Khi nó lệch với [../01-rules/RULES.md](../01-rules/RULES.md), bản ở RULES.md thắng
và file này là thứ phải sửa.

Một điểm xuyên suốt cả file, đáng nói ngay từ đầu: **phần lớn bộ kiểm tự động của dự án
này nhận diện tầng bằng hậu tố tên file** (`*_service.go`, `*_repository.go`,
`*_handler.go`) và bằng hình dạng chữ ký hàm. Quy ước đặt tên ở đây không phải chuyện thẩm
mỹ — đặt tên khác là làm mù bộ kiểm, và mọi Rule dựa vào nó vẫn báo xanh trên một file
đang vi phạm.

| Mục | Nội dung | Neo về |
|---|---|---|
| C-GO-01 | Bố cục package của một module | R-01, R-03, R-04 |
| C-GO-02 | Đặt tên file, interface, method, biến | — |
| C-GO-03 | Transaction Ownership | R-03, R-05 |
| C-GO-04 | Wrap error và ánh xạ sang mã lỗi | R-11 |
| C-GO-05 | Nội dung `module.yaml` | R-02, R-05, R-15 |
| C-GO-06 | Chữ ký method service, actor và kiểm quyền | R-15, R-17 |
| C-GO-07 | SQL phải là một hằng chuỗi đơn | R-02, R-06, R-09, R-18 |
| C-GO-08 | Bảng vai trò tới được composition root bằng đường nào | R-15, R-04, R-01 |

---

### C-GO-01 — Bố cục package của một module

**Implements:** R-01, R-03, R-04

Bố cục dưới đây là bản đã chốt ở
[../01-rules/rules/R-01-module-boundary.md](../01-rules/rules/R-01-module-boundary.md),
kèm `module.yaml` mà C-GO-05 mô tả:

```text
modules/<A>/
├── api/          # interface + DTO — thứ duy nhất module khác được import
├── internal/
│   ├── handler/
│   ├── service/
│   ├── repository/
│   └── model/
├── module.go     # hàm New/Register — thứ duy nhất cmd/** được import
└── module.yaml
```

Ba đường đi hợp lệ, không có đường thứ tư: module khác → `api/`; `cmd/**` → `module.go`;
chính module A → mọi thứ của A.

| Thư mục | Chứa gì | Cấm chứa gì |
|---|---|---|
| `api/` | Interface mô tả hành vi A cam kết giữ ổn định, và DTO đi kèm interface đó | Kiểu nội bộ, `sqlx`, `gin`, method mang tiền tố `Internal` (ngoại lệ R-15) |
| `internal/handler/` | Bind request, gọi service, đẩy kết quả qua `shared/response`, DTO của lớp HTTP | `pgx`, `sqlx`, câu SQL, so sánh role, `c.JSON` trực tiếp (R-03, R-11, R-15) |
| `internal/service/` | Nghiệp vụ, kiểm quyền, ranh giới transaction, dịch lỗi | `gin`, `net/http`, `auth.FromContext` (R-03, R-15) |
| `internal/repository/` | Câu SQL, ánh xạ dòng sang model | `BeginTxx`/`Commit`/`Rollback`, field `*sqlx.DB`, `errors.New`, import package `service` (R-03, P-TXN) |
| `internal/model/` | Struct ánh xạ bảng, gắn tag `db` | Tag `json` của DTO response, logic nghiệp vụ |
| `module.go` | `Deps`, `New`, `Register` | Bất cứ thứ gì `cmd/**` không cần biết |
| `module.yaml` | Bốn trường ở C-GO-05 | — |

Vì sao `api/` phải mỏng: mọi thứ trong `internal/` là chi tiết triển khai được đổi bất cứ
lúc nào; mọi thứ trong `api/` là hợp đồng, và đổi nó là làm vỡ build của module khác. Đặt
nhầm một struct từ `internal/model/` lên `api/` nghĩa là mọi lần đổi cột trong bảng của A
trở thành một breaking change liên module.

#### Bố cục cả repo

```text
erp/
├── cmd/
│   └── api/main.go        # composition root — chỉ import "erp/modules/<A>"
├── modules/
│   ├── order/
│   └── customer/
├── shared/
├── relay/                 # đọc outbox, publish ra bus — NGOÀI modules/ (R-05)
└── migrations/
```

`relay/` nằm ngoài `modules/` một cách có chủ đích: R-05 cấm mọi lời gọi `.Publish(` trong
`modules/**`, và relay là package duy nhất được publish. Đặt nó vào `modules/` là tự đưa
nó vào phạm vi quét của rule đó.

#### `shared/` chứa gì

| Package | Chứa gì | Ai gọi | Neo về |
|---|---|---|---|
| `shared/response` | `Envelope`, `Meta`, `ErrorBody`, `FieldError` và các hàm `Success`/`Created`/`List`/`ValidationFailed`/`Error`; là chỗ **duy nhất** trong repo gọi `c.JSON` | handler | R-11, C-API-03 |
| `shared/errors` | Kiểu `Error` mang `Code`/`Message`/`Status`, hằng mã lỗi, hàm dựng `NotFound`/`Conflict`/`Forbidden` | service | R-11, C-API-05 |
| `shared/middleware/auth` | Middleware Gin verify JWT rồi gắn actor vào `ctx`; **nơi duy nhất** được phép có `jwt.Parse` | composition root | R-14 |
| `shared/auth` | Kiểu `Actor` (`UserID`, `CompanyID`, `Roles`) và `FromContext(ctx)` | handler đọc, service nhận qua tham số | R-14, R-15 |
| `shared/authz` | Interface `Checker` với `Can(ctx, actor, perm) error` | service | R-15 |
| `shared/db` | Interface `DBTX` — hợp đồng duy nhất giữa repository và database | repository | R-03, P-TXN |
| `shared/log` | `FromContext(ctx)` trả logger đã gắn sẵn `request_id`; chỉ nhận cặp key-value nguyên thủy | mọi tầng | R-16, R-17 |
| `shared/requestid` | Middleware sinh `request_id`, gắn vào `ctx` và header `X-Request-Id`; `FromContext(ctx)` | middleware, service | R-17 |
| `shared/outbox` | Kiểu `Event` và interface `Repository` với `Append(ctx, db, evt)` | service | R-05 |
| `shared/audit` | Kiểu `Entry` và interface `Repository` với `Record(ctx, db, entry)` | service | R-17 |

`shared/auth` và `shared/middleware/auth` là **hai package khác nhau**, và tách như vậy là
có lý do: `shared/auth` chỉ chứa kiểu dữ liệu và hàm đọc `ctx`, nên mọi tầng import được
mà không kéo theo thư viện JWT; `shared/middleware/auth` chứa phần verify token, và R-14
giữ nó ở đúng một chỗ để `jwt.Parse` không rải ra khắp repo.

#### Vì sao `shared/` cấm import `modules/`

R-04 nói `shared/` cấm import bất kỳ package nào dưới `modules/`. Đây không phải quy ước
sạch sẽ mà là thứ giữ cho `shared/` còn là `shared/`:

- **Chiều phụ thuộc chỉ có một hướng.** Mọi module import `shared/`. Nếu `shared/` import
  ngược lại một module, đồ thị phụ thuộc có chu trình ngay tại nút đông người dùng nhất,
  và Go từ chối biên dịch import cycle — nhưng nó chỉ từ chối khi chu trình khép kín, còn
  `shared → modules/order → shared` thì biên dịch được và chỉ để lại một quả mìn.
- **Một dòng import biến `shared/` thành phụ thuộc của mọi module.** `shared/response`
  import `modules/order/internal/model` nghĩa là module `customer` — vốn không liên quan
  gì tới đơn hàng — vẫn kéo theo toàn bộ cây phụ thuộc của order mỗi lần nó trả một
  response.
- **Nó phá luôn khả năng tách module ra khỏi monolith.** ADR-0001 chọn modular monolith
  với đường lùi là tách module thành service riêng. Một `shared/` biết tên module cụ thể
  thì không tách được gì cả.

Cách làm đúng khi `shared/` cần một thứ mà module có: **đảo chiều bằng interface do
`shared/` định nghĩa và module implement**. `shared/outbox` khai `Repository`, module gọi
nó; `shared/authz` khai `Checker`, composition root cắm bản cài đặt vào. Không có chiều
nào đi từ `shared/` xuống `modules/`.

---

### C-GO-02 — Đặt tên file, interface, method, biến

**Implements:** —

#### Tên file — thứ bộ kiểm dựa vào

| Loại | Mẫu tên | Ví dụ |
|---|---|---|
| Service | `<danh_tu>_service.go` | `order_service.go`, `pricing_service.go` |
| Repository | `<danh_tu>_repository.go` | `order_repository.go`, `order_item_repository.go` |
| Handler | `<danh_tu>_handler.go` | `order_handler.go` |
| Model | `<danh_tu>.go` | `order.go`, `order_item.go` |
| DTO công khai | `<danh_tu>.go` trong `api/` | `api/order.go` |
| Test | `<ten_file>_test.go` | `order_service_test.go` |

`<danh_tu>` là snake_case, **số ít**, khớp tên thực thể chứ không khớp tên bảng: bảng là
`orders` (số nhiều, C-DB-01), file là `order_service.go` (số ít).

**Ba hậu tố `_service.go`, `_repository.go`, `_handler.go` là đầu vào của bộ kiểm tự
động.** Không phải một rule dùng chúng mà là gần như toàn bộ:

| Hậu tố | Rule và Principle quét theo nó |
|---|---|
| `*_service.go` | R-03 (cấm `gin`/`net/http`), R-05 (chỉ service ghi outbox), R-14 (cấm đọc header `Authorization`), R-15 (chữ ký + câu lệnh đầu tiên), R-17 (audit cùng transaction), P-TXN (nơi duy nhất có `BeginTxx`), P-ERR (nơi duy nhất có `sql.ErrNoRows`) |
| `*_repository.go` | R-03 (cấm import `service`, cấm sinh lỗi nghiệp vụ), R-05 (cấm ghi outbox), R-06 (`company_id = $n` trong `WHERE`), R-09 (cột trong `WHERE`/`ORDER BY` phải có index), R-12 (`sort` qua whitelist), R-18 (`deleted_at IS NULL`), P-TXN (cấm ranh giới transaction, cấm field DB) |
| `*_handler.go` | R-03 (cấm `pgx`/`sqlx`), R-05 (cấm ghi outbox), R-06 (cấm nhận `company_id` từ client), R-11 (cấm `c.JSON` với `gin.H`), R-14, R-15 (cấm logic quyền), R-17 (logger dẫn xuất từ `ctx`), P-ERR |

Đặt một service vào `order_svc.go` hay `orders.go` không làm code sai — nó làm **mọi lệnh
quét ở trên không nhìn thấy file đó**. Kết quả tệ hơn một vi phạm bị bắt: một vi phạm
không bị bắt, trên một file mà CI khẳng định là sạch. Vì vậy hậu tố sai là lỗi review
nghiêm trọng hơn phần lớn vi phạm rule.

#### Tên package

- Một từ, chữ thường, không gạch dưới, không số nhiều: `handler`, `service`, `repository`,
  `model`, `api`.
- Tên package **không** lặp lại vào tên kiểu: `service.OrderService` là đúng vì `Service`
  ở đây mô tả vai trò và R-15 quét theo nó; nhưng `model.OrderModel` thì thừa — viết
  `model.Order`.
- Import package trùng tên với package hiện tại hoặc trùng tên stdlib thì đặt alias có ý
  nghĩa: `apperr "erp/shared/errors"`, `customerapi "erp/modules/customer/api"`.

#### Tên interface — theo hành vi, không theo cài đặt

Interface trả lời câu hỏi *"nó làm được gì"*, không phải *"nó được cài bằng gì"*.

| Đúng | Sai | Vì sao |
|---|---|---|
| `CustomerReader` | `CustomerAPIClient` | Tên đúng không đổi khi customer từ module nội bộ thành service HTTP |
| `OrderRepository` | `PostgresOrderRepository`, `SqlxOrderRepo` | Cài đặt nằm ở struct không xuất khẩu, không nằm ở tên hợp đồng |
| `authz.Checker` | `RBACChecker` | Đổi từ RBAC sang ABAC không được kéo theo sửa mọi service |
| `outbox.Repository` | `OutboxTableWriter` | Người gọi quan tâm "ghi được event", không quan tâm nó là bảng |

Quy ước kèm theo:

- **Interface khai ở phía người dùng, không ở phía cài đặt.** `OrderRepository` khai trong
  package `repository` của module order vì service của chính module đó dùng nó; interface
  cho module khác dùng thì khai ở `api/`.
- **Interface giữ nhỏ.** Một interface có 12 method là một interface không ai mock nổi
  trong test (P-TEST). Cắt theo nhóm hành vi: `CustomerReader` tách khỏi `CustomerWriter`.
- **Struct cài đặt không xuất khẩu**, hàm dựng trả về interface:
  `func NewOrderRepository() OrderRepository { return &orderRepo{} }`.

#### Receiver — ngắn, nhất quán, và với service thì bắt buộc

| Loại | Receiver | Bắt buộc? |
|---|---|---|
| Service | `s` | **Có** — R-15 quét bằng regex `^func \(s \*\w+Service\)` |
| Repository | `r` | Quy ước |
| Handler | `h` | Quy ước |
| Module (`module.go`) | `m` | Quy ước |

Receiver của service **phải** là `s` và tên kiểu **phải** kết thúc bằng `Service`. Viết
`func (svc *OrderService) CreateOrder(...)` hay `func (s *OrderSvc) CreateOrder(...)` là
code chạy đúng mà R-15 không nhìn thấy: cả vế "actor là tham số thứ hai" lẫn vế "câu lệnh
đầu tiên là kiểm quyền" đều không được kiểm trên method đó nữa.

Receiver không đặt tên `this` hay `self`, và một kiểu chỉ dùng đúng một chữ receiver ở mọi
method của nó.

#### Tên biến ngữ cảnh — cố định, không sáng tạo

| Biến | Kiểu | Ghi chú |
|---|---|---|
| `ctx` | `context.Context` | Luôn là tham số **thứ nhất** của mọi method service và repository (R-17). Không đặt `c`, không nhét vào struct |
| `c` | `*gin.Context` | Chỉ tồn tại trong `*_handler.go`. Lấy `ctx := c.Request.Context()` rồi truyền xuống |
| `tx` | `*sqlx.Tx` | Chỉ tồn tại trong `*_service.go`, giữa `BeginTxx` và `Commit` |
| `db` | `DBTX` hoặc `*sqlx.DB` | Tham số **thứ hai** của mọi method repository (C-GO-03); field của service |
| `actor` | `auth.Actor` | Tham số **thứ hai** của mọi method service (R-15) |
| `err` | `error` | Không đặt `e`, `er`, `errRepo` |

Tên khác cho những thứ trên không sai về mặt Go, nhưng chúng là mỏ neo mà người đọc dùng
để nhận ra tầng mình đang đứng chỉ bằng cách liếc qua một hàm. Thấy `tx` trong một file
`*_repository.go` là biết ngay có chuyện, không cần đọc tiếp.

#### Vài quy ước nhỏ còn lại

- Hằng quyền đặt tên `Perm<Đối tượng><Hành động>`, giá trị là chuỗi `<module>.<hành động>`:
  `const PermOrderCreate = "order.create"`. Khai ở package `service` của module sở hữu;
  cách bảng vai trò ở composition root chạm tới được những hằng này thì xem C-GO-08.
- Struct đầu vào của service đặt tên `<Method>Input`, đầu ra là `*model.X` hoặc
  `<Method>Output`: `CreateOrderInput`. DTO của lớp HTTP đặt tên `<Method>Request` /
  `<Đối tượng>DTO` và ở lại package `handler`.
- Method public dùng nội bộ giữa các service **trong cùng module** mang tiền tố `Internal`
  và phải có tên trong `internal_methods` của `module.yaml` (C-GO-05, ngoại lệ R-15).
- Câu SQL khai bằng `const q = ` ngay trong method, hoặc hằng cấp package khi dùng lại
  nhiều nơi. Không dựng chuỗi SQL bằng `fmt.Sprintf` trên dữ liệu client (R-12).

---

### C-GO-03 — Transaction Ownership

**Implements:** R-03, R-05

Đây là mục quan trọng nhất của file. Ba mệnh đề dưới đây là bắt buộc, và mọi thứ còn lại
trong mục chỉ là cách viết chúng ra sao để grep bắt được.

1. **Service sở hữu ranh giới transaction.** Chỉ service gọi `BeginTxx`, `Commit`,
   `Rollback`; chỉ service giữ `*sqlx.DB` làm field.
2. **Repository không `Begin`/`Commit`/`Rollback` transaction nghiệp vụ.** Nó không biết
   nó đang ở trong hay ngoài transaction, và đó là điều kiện để nó dùng lại được ở cả hai
   ngữ cảnh.
3. **Repository nhận `DBTX` qua tham số, không lấy từ `context`.** `DBTX` là tham số thứ
   hai, ngay sau `ctx`.

Ngoại lệ duy nhất của mệnh đề 1 là relay — package nằm ngoài `modules/` — nó mở transaction
riêng trên bảng `outbox`, không chứa dữ liệu nghiệp vụ nào
([../01-rules/rules/R-05-events-for-decoupling.md](../01-rules/rules/R-05-events-for-decoupling.md)).

#### Đường đi của một request ghi

```text
Handler
   ↓ c.Request.Context() + auth.FromContext(ctx)
Service
   ├── authz.Can(ctx, actor, ...)
   ├── BEGIN
   ├── Repository A      (nhận DBTX)
   ├── Repository B      (nhận DBTX)
   ├── Audit Repository  (nhận DBTX)
   ├── Outbox Repository (nhận DBTX)
   └── COMMIT
                ↓ (sau commit, tiến trình khác)
        Relay đọc outbox → publish ra bus
```

Đọc sơ đồ này theo chiều dọc thì thấy ngay vì sao ranh giới phải nằm ở service: bốn lời
gọi trong ngoặc đều nhận **cùng một** `DBTX`, và chỉ tầng nhìn thấy cả bốn mới nói được
"cả bốn cùng commit hoặc cùng biến mất". Repository nhìn thấy đúng một bảng; handler không
được cầm `*sqlx.DB` (R-03). Còn lại đúng một tầng
([../02-principles/P-TXN-transaction-boundary.md](../02-principles/P-TXN-transaction-boundary.md)).

Mũi tên cuối cùng cố ý nằm **ngoài** khối service: `bus.Publish` không xuất hiện ở bất kỳ
đâu trong `modules/**` (R-05). Service chỉ ghi một dòng `outbox` trong chính transaction
đó và dừng lại.

#### `DBTX` — hợp đồng duy nhất giữa repository và database

```go
// erp/shared/db/dbtx.go
package db

import (
	"context"
	"database/sql"

	"github.com/jmoiron/sqlx"
)

// DBTX là thứ duy nhất repository nhận để chạm tới database. Nó cố ý KHÔNG có
// BeginTxx, Commit hay Rollback: repository cầm DBTX thì không có cách nào mở hay đóng
// một transaction, kể cả khi người viết muốn.
type DBTX interface {
	GetContext(ctx context.Context, dest interface{}, query string, args ...interface{}) error
	SelectContext(ctx context.Context, dest interface{}, query string, args ...interface{}) error
	QueryRowxContext(ctx context.Context, query string, args ...interface{}) *sqlx.Row
	ExecContext(ctx context.Context, query string, args ...interface{}) (sql.Result, error)
}

// Hai dòng này là hợp đồng do trình biên dịch giữ: cả *sqlx.DB lẫn *sqlx.Tx đều thỏa
// DBTX. Nhờ đó cùng một method repository dùng được ở cả hai ngữ cảnh — trong
// transaction thì service truyền tx, ngoài transaction thì truyền s.db — và repository
// không cần biết mình đang ở ngữ cảnh nào. Không có method nào phải viết hai lần.
//
// Đặt hai dòng này ở đây thay vì để build tự đỏ rải rác: đổi chữ ký một method trong
// DBTX mà sqlx không còn thỏa thì lỗi hiện ngay tại file này, kèm đúng tên method.
var (
	_ DBTX = (*sqlx.DB)(nil)
	_ DBTX = (*sqlx.Tx)(nil)
)
```

Bốn method là đủ cho mọi thứ repository cần: `GetContext` đọc một dòng, `SelectContext`
đọc nhiều dòng, `QueryRowxContext` cho `INSERT ... RETURNING`, `ExecContext` cho ghi.
Thiếu thứ gì thì thêm vào interface này chứ **không** nhận thẳng `*sqlx.DB` ở một
repository cho tiện — thêm một method vào `DBTX` là một quyết định nhìn thấy được trong
diff, còn nhận `*sqlx.DB` thì mở lại đúng cánh cửa mà interface này sinh ra để đóng.

#### Chữ ký repository bắt buộc

```go
// modules/order/internal/repository/repository.go
package repository

import shareddb "erp/shared/db"

// DBTX là alias của erp/shared/db.DBTX, khai một lần cho cả package repository của
// module. Có alias này thì chữ ký method viết được gọn là "db DBTX", và tên tham số db
// không che mất tên package db khi đọc — đây là lý do duy nhất alias tồn tại, không
// phải để thêm một tầng trừu tượng nào.
type DBTX = shareddb.DBTX
```

```go
// modules/order/internal/repository/order_repository.go
package repository

import (
	"context"
	"fmt"

	"erp/modules/order/internal/model"
)

// OrderRepository đặt tên theo hành vi, không theo cài đặt (C-GO-02).
type OrderRepository interface {
	Insert(ctx context.Context, db DBTX, o *model.Order) error
	GetByID(ctx context.Context, db DBTX, companyID, id string) (*model.Order, error)
}

// orderRepo KHÔNG có field nào — đặc biệt không có *sqlx.DB. Struct rỗng là hình dạng
// đúng của một repository: mọi thứ nó cần đến qua tham số.
type orderRepo struct{}

func NewOrderRepository() OrderRepository { return &orderRepo{} }

// Insert là chữ ký chuẩn: ctx thứ nhất, DBTX thứ hai, dữ liệu từ thứ ba trở đi.
func (r *orderRepo) Insert(ctx context.Context, db DBTX, o *model.Order) error {
	const q = `
INSERT INTO orders (id, company_id, customer_id, code, status, total_amount,
                    created_by, updated_by)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`

	// Chỉ BỌC lỗi kỹ thuật, không tạo lỗi nghiệp vụ (R-03): repository không biết một
	// lỗi 23505 ở đây nghĩa là "mã đơn trùng" hay ràng buộc nào khác. Chuỗi định dạng
	// kết thúc bằng ": %w" — đó là hình dạng mà bộ kiểm của R-03 chấp nhận.
	if _, err := db.ExecContext(ctx, q, o.ID, o.CompanyID, o.CustomerID, o.Code,
		o.Status, o.TotalAmount, o.CreatedBy, o.UpdatedBy); err != nil {
		return fmt.Errorf("insert order %s: %w", o.ID, err)
	}
	return nil
}

// GetByID trả sql.ErrNoRows lên NGUYÊN TRẠNG. Bọc nó bằng ": %w" cũng không phá
// errors.Is, nhưng ở một hàm đã tên là GetByID thì dòng "get order by id:" không thêm
// ngữ cảnh nào tầng trên chưa có — và service mới là tầng biết "không có dòng nào" ở
// đây nghĩa là 404 hay là một nhánh hợp lệ (R-03, P-ERR).
func (r *orderRepo) GetByID(ctx context.Context, db DBTX, companyID, id string) (*model.Order, error) {
	const q = `
SELECT id, company_id, customer_id, code, status, total_amount,
       created_at, updated_at, created_by, updated_by
FROM orders
WHERE company_id = $1 AND id = $2 AND deleted_at IS NULL`

	var o model.Order
	if err := db.GetContext(ctx, &o, q, companyID, id); err != nil {
		return nil, err
	}
	return &o, nil
}
```

Ba chi tiết trong đoạn trên là bắt buộc, không phải phong cách:

- **`ctx` thứ nhất, `DBTX` thứ hai.** Thứ tự cố định để một dòng grep trên chữ ký là đủ
  kết luận, không cần đọc thân hàm.
- **`companyID` là tham số tường minh**, đến từ `actor.CompanyID` mà service truyền xuống,
  và có mặt trong `WHERE` (R-06). Không lấy từ `ctx`, không lấy từ request.
- **`deleted_at IS NULL` trong mọi câu đọc** bảng nghiệp vụ (R-18).

#### Repository cấm giữ handle DB làm field

```go
package repository

import (
	"context"

	"github.com/jmoiron/sqlx"

	"erp/modules/order/internal/model"
)

// SAI #1: repository giữ handle DB làm field.
type orderRepoWrong struct {
	db *sqlx.DB
}

// Hệ quả không nằm ở dòng khai báo mà ở đây: method này chạy được, trả nil, và câu
// INSERT của nó nằm NGOÀI transaction mà service đang mở ở tầng trên. Không có lỗi
// biên dịch, không có lỗi runtime, không có dòng log nào. Bản ghi đơn hàng tồn tại
// trong khi phần còn lại của giao dịch đã rollback, và chuyện đó chỉ lộ ra khi có
// người đối chiếu dữ liệu vài tuần sau.
func (r *orderRepoWrong) Insert(ctx context.Context, o *model.Order) error {
	const q = `INSERT INTO orders (id, company_id) VALUES ($1, $2)`
	_, err := r.db.ExecContext(ctx, q, o.ID, o.CompanyID)
	return err
}

// SAI #2: repository tự mở transaction nghiệp vụ. Nó chỉ nhìn thấy một bảng nên không
// đủ thông tin để nói bảng của nó có được commit một mình hay không; ranh giới đặt ở
// đây là ranh giới của một lời gọi database, không phải của một quyết định nghiệp vụ
// (P-TXN). Ngoài ra dòng BeginTxx trong *_repository.go là vi phạm grep được ngay.
func (r *orderRepoWrong) InsertWithItems(ctx context.Context, o *model.Order) error {
	tx, err := r.db.BeginTxx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	const q = `INSERT INTO orders (id, company_id) VALUES ($1, $2)`
	if _, err := tx.ExecContext(ctx, q, o.ID, o.CompanyID); err != nil {
		return err
	}
	return tx.Commit()
}
```

Quy tắc rút ra, và nó là hard check số 2 của P-TXN: **struct repository không có field
kiểu `*sqlx.DB` hay `*pgxpool.Pool`.** Một repository giữ được `*sqlx.DB` là một repository
có thể tự chạy ngoài transaction của service mà không ai thấy. Struct rỗng `struct{}` là
hình dạng mặc định; nếu repository thật sự cần thứ gì đó (ví dụ một `*slog.Logger`), thứ
đó vẫn không bao giờ là một handle database.

#### Vì sao truyền `DBTX` qua tham số chứ không qua `context`

Cám dỗ trông rất gọn: nhét `*sqlx.Tx` vào `ctx` ở service, repository tự moi ra, chữ ký
ngắn lại một tham số. Nó hỏng theo cách tệ nhất có thể — hỏng im lặng.

```go
package repository

import (
	"context"

	"github.com/jmoiron/sqlx"

	"erp/modules/order/internal/model"
)

type txKey struct{}

// SAI #3: DBTX đi qua context.
func WithTx(ctx context.Context, tx *sqlx.Tx) context.Context {
	return context.WithValue(ctx, txKey{}, tx)
}

type orderRepoCtx struct {
	db *sqlx.DB
}

func (r *orderRepoCtx) Insert(ctx context.Context, o *model.Order) error {
	const q = `INSERT INTO orders (id, company_id) VALUES ($1, $2)`

	// Nhánh dưới là toàn bộ vấn đề. Service quên gọi WithTx — hoặc gọi rồi nhưng
	// truyền nhầm ctx gốc xuống một repository — thì code KHÔNG lỗi: nó lặng lẽ rơi
	// về r.db và câu INSERT chạy ngoài transaction. Không có gì để grep, vì chữ ký
	// hàm ở đây giống hệt chữ ký của một lời gọi hoàn toàn đúng.
	if tx, ok := ctx.Value(txKey{}).(*sqlx.Tx); ok {
		_, err := tx.ExecContext(ctx, q, o.ID, o.CompanyID)
		return err
	}
	_, err := r.db.ExecContext(ctx, q, o.ID, o.CompanyID)
	return err
}
```

Ba lý do, xếp theo mức độ quan trọng:

1. **Chữ ký hàm tự tố cáo vi phạm.** Với `DBTX` là tham số, một dòng grep trên chữ ký
   phân biệt được repository đúng với repository sai, và người review thấy ngay tại chỗ
   gọi rằng lời gọi này đang dùng `tx` hay `s.db`. Với `ctx`, cả hai ca viết ra giống hệt
   nhau và sự khác biệt nằm ở một chỗ khác trong file.
2. **Quên truyền thì code vẫn chạy.** Đây là điểm chết người: sai sót không thành lỗi biên
   dịch, không thành lỗi runtime, chỉ thành một câu ghi nằm ngoài transaction. Với tham số
   tường minh, quên truyền là **lỗi biên dịch** — trình biên dịch bắt trước khi CI kịp
   chạy.
3. **`ctx` mất kiểu tĩnh.** `ctx.Value` trả `any`, nên hợp đồng "chỗ này có một `DBTX`"
   trở thành một type assertion kiểm lúc chạy. `context.Context` sinh ra để mang metadata
   phạm vi request — deadline, hủy, `request_id` (R-17) — chứ không mang handle tài
   nguyên.

#### Đường đọc: cùng repository, truyền `s.db`

```go
package service

import (
	"context"

	"erp/modules/order/internal/model"
	"erp/shared/auth"
)

const PermOrderRead = "order.read"

// Đường đọc mặc định KHÔNG mở transaction (P-TXN): mở transaction cho một câu SELECT
// đơn lẻ không thêm gì ngoài một vòng round-trip. Repository vẫn là repository đó, chỉ
// khác giá trị truyền vào tham số thứ hai — đây chính là thứ mà DBTX mua được.
func (s *OrderService) listByCustomer(ctx context.Context, actor auth.Actor, customerID string) ([]model.Order, error) {
	if err := s.authz.Can(ctx, actor, PermOrderRead); err != nil {
		return nil, err
	}
	return s.orderRepo.ListByCustomer(ctx, s.db, actor.CompanyID, customerID)
}
```

Mở transaction để đọc chỉ đúng khi nhiều câu truy vấn phải nhìn thấy **cùng một ảnh chụp**
dữ liệu — ví dụ báo cáo đối chiếu tổng phát sinh với số dư cuối kỳ. Lúc đó dùng transaction
read-only và ghi rõ lý do trong comment ngay tại chỗ.

#### Cách kiểm

```powershell
# 1) Ranh gioi transaction ro ri ra khoi service
Get-ChildItem -Path modules -Recurse -Include *_repository.go, *_handler.go |
    Select-String -Pattern 'BeginTxx\(|\.Commit\(\)|\.Rollback\(\)' |
    ForEach-Object { "{0}:{1}: ranh gioi transaction nam ngoai service" -f $_.Path, $_.LineNumber }

# 2) Repository giu handle DB lam field thay vi nhan DBTX qua tham so
Get-ChildItem -Path modules -Recurse -Filter *_repository.go |
    Select-String -Pattern '^\s+\w+\s+\*(sqlx\.DB|pgxpool\.Pool)\s*$' |
    ForEach-Object { "{0}:{1}: repository giu handle DB -> nhan DBTX qua tham so" -f $_.Path, $_.LineNumber }

# 3) Method repository khong nhan DBTX o tham so thu hai
Get-ChildItem -Path modules -Recurse -Filter *_repository.go |
    Select-String -Pattern '^func \(r \*\w+\) [A-Z]\w*\(ctx context\.Context, ' |
    Where-Object { $_.Line -notmatch '^func \(r \*\w+\) [A-Z]\w*\(ctx context\.Context, db DBTX' } |
    ForEach-Object { "{0}:{1}: DBTX khong phai tham so thu hai -> {2}" -f $_.Path, $_.LineNumber, $_.Line.Trim() }

# 4) DBTX di qua context
Get-ChildItem -Path modules -Recurse -Filter *.go |
    Select-String -Pattern 'context\.WithValue\(.*(tx|Tx|DBTX)' |
    ForEach-Object { "{0}:{1}: handle DB di qua context -> truyen qua tham so" -f $_.Path, $_.LineNumber }
```

---

### C-GO-04 — Wrap error và ánh xạ sang mã lỗi

**Implements:** R-11

Lỗi đi qua ba tầng và mỗi tầng làm đúng một việc. Trộn hai việc vào một tầng là nguồn của
gần hết lỗi xử lý lỗi trong hệ thống này.

| Tầng | Được làm | Cấm làm |
|---|---|---|
| Repository | Trả lỗi driver và `sql.ErrNoRows` nguyên trạng; bọc thêm ngữ cảnh bằng `: %w` | `errors.New(`; `fmt.Errorf(` không kết thúc bằng `: %w`; dịch lỗi sang mã nghiệp vụ (R-03) |
| Service | Dịch `sql.ErrNoRows` và lỗi Postgres sang mã lỗi trong `shared/errors`; bọc lỗi kỹ thuật còn lại bằng `: %w` | Gán mã nghiệp vụ cho lỗi mình không nhận ra |
| Handler | Đẩy lỗi đã nhận qua `shared/response` | Dịch lỗi; đọc `sql.ErrNoRows`; tạo lỗi bằng `errors.New`/`fmt.Errorf` để trả về (P-ERR) |

#### Cách bọc ở repository

Chuỗi định dạng có đúng một hình dạng: `"<động từ> <đối tượng> <định danh>: %w"`, chữ
thường, ASCII không dấu, **luôn** kết thúc bằng `: %w`.

```go
	return fmt.Errorf("insert order %s: %w", o.ID, err)
	return fmt.Errorf("update order status %s: %w", orderID, err)
	return fmt.Errorf("select order items of order %s: %w", orderID, err)
```

- **Luôn `%w`, không bao giờ `%v`.** `%v` cắt đứt chuỗi lỗi và mọi `errors.Is`/`errors.As`
  ở tầng trên mù luôn — kể cả `errors.Is(err, sql.ErrNoRows)` mà service đang dựa vào.
- **Bọc để thêm ngữ cảnh, không để lặp lại thứ đã hiển nhiên.**
  `fmt.Errorf("failed to get order: %w", err)` trong một hàm tên `GetOrder` chỉ thêm một
  dòng nhiễu; bốn tầng cùng làm vậy thì được một chuỗi "failed to ... failed to ..." dài mà
  vẫn không biết id nào hỏng. Thứ đáng thêm là **định danh**.
- **Không bọc `sql.ErrNoRows` ở method đọc một bản ghi.** Tên method đã nói hết, và service
  chỉ cần chính sentinel đó.

#### `shared/errors` — nơi mã lỗi sống

```go
// erp/shared/errors/errors.go
package errors

import "net/http"

// Mã lỗi khai thành hằng ở đây, không viết chuỗi trực tiếp ở service hay handler. Bảng
// đầy đủ — mã, HTTP status, thông điệp mặc định, khi nào dùng — nằm ở C-API-05; file
// này chỉ là nơi các hằng đó sống trong code.
const (
	CodeInternal            = "ERR_INTERNAL"
	CodeForbidden           = "ERR_AUTH_FORBIDDEN"
	CodeNotFound            = "ERR_COMMON_NOT_FOUND"
	CodeValidationFailed    = "ERR_COMMON_VALIDATION_FAILED"
	CodeVersionConflict     = "ERR_COMMON_VERSION_CONFLICT"
	CodeOrderNotFound       = "ERR_ORDER_NOT_FOUND"
	CodeOrderCodeDuplicated = "ERR_ORDER_CODE_DUPLICATED"
)

// Error là lỗi NGHIỆP VỤ: có mã ổn định để client rẽ nhánh (C-API-05), có status HTTP,
// và giữ nguyên lỗi gốc qua Unwrap để log vẫn đọc được nguyên nhân kỹ thuật trong khi
// client chỉ thấy Message.
//
// Trường cause không xuất khẩu: nó là thứ đi vào log, không phải thứ đi ra client —
// thông điệp ra client cấm chứa tên bảng, tên constraint hay câu SQL (C-API-05).
type Error struct {
	Code    string
	Message string
	Status  int
	cause   error
}

func (e *Error) Error() string {
	if e.cause == nil {
		return e.Code + ": " + e.Message
	}
	return e.Code + ": " + e.Message + ": " + e.cause.Error()
}

func (e *Error) Unwrap() error { return e.cause }

func NotFound(code, message string) *Error {
	return &Error{Code: code, Message: message, Status: http.StatusNotFound}
}

func Conflict(code, message string) *Error {
	return &Error{Code: code, Message: message, Status: http.StatusConflict}
}

func Forbidden(message string) *Error {
	return &Error{Code: CodeForbidden, Message: message, Status: http.StatusForbidden}
}

// Wrap gắn mã nghiệp vụ lên một lỗi kỹ thuật đã có, dùng khi cần giữ nguyên nhân gốc
// cho log mà vẫn trả mã ổn định ra client.
func Wrap(cause error, code, message string, status int) *Error {
	return &Error{Code: code, Message: message, Status: status, cause: cause}
}
```

Package này tên `errors`, trùng tên stdlib, nên mọi nơi dùng nó import với alias
`apperr "erp/shared/errors"` (C-GO-02). Nhờ vậy trong cùng một file vẫn gọi được
`errors.Is` và `errors.As` của stdlib.

#### Service dịch lỗi Postgres — theo tên constraint

```go
package service

import (
	"errors"

	"github.com/jackc/pgx/v5/pgconn"

	apperr "erp/shared/errors"
)

// translateWrite dịch lỗi driver sang lỗi nghiệp vụ có mã. Nó dịch theo TÊN
// CONSTRAINT chứ không theo mã lỗi Postgres: một mã 23505 chỉ nói "có ràng buộc duy
// nhất bị vi phạm", nó không nói ràng buộc nào — map thẳng 23505 sang "mã đã tồn tại"
// sẽ báo sai ngay khi bảng có hai unique index (P-ERR).
//
// Bảng ánh xạ đầy đủ tên constraint -> mã lỗi nằm ở C-API-05. Chép lại nó vào đây
// nghĩa là có hai bản và một ngày nào đó chúng lệch nhau; ở đây chỉ có code đọc bảng
// đó, không có bản sao của bảng.
//
// Constraint chưa có trong bảng ánh xạ thì trả lỗi đi tiếp NGUYÊN TRẠNG để nó thành
// ERR_INTERNAL kèm request_id. Đoán bừa cho ra thông điệp sai, và thông điệp sai khó
// gỡ hơn thông điệp chung chung.
func translateWrite(err error) error {
	var pgErr *pgconn.PgError
	if !errors.As(err, &pgErr) {
		return err
	}
	switch {
	case pgErr.Code == "23505" && pgErr.ConstraintName == "uq_orders_company_id_code":
		return apperr.Conflict(apperr.CodeOrderCodeDuplicated, "ma don hang da ton tai")
	default:
		return err
	}
}
```

Ba mã Postgres đáng để ý (P-ERR): `23505` trùng khóa, `23503` vi phạm khóa ngoại —
"bản ghi đang được tham chiếu, không xóa được" — và `40001` serialization failure, ca duy
nhất nên tự retry rồi mới báo. Dịch được `23503` theo tên constraint đòi khóa ngoại phải
được đặt tên tường minh trong migration (C-DB-01); khóa ngoại khai inline mang tên tự sinh
và không dịch được.

#### Handler không dịch gì

```go
	o, err := h.svc.CreateOrder(ctx, actor, in)
	if err != nil {
		// Lỗi đã có mã thì response.Error trả nguyên mã và status đó; lỗi chưa có mã
		// là lỗi kỹ thuật nên ra client dưới đúng một mã ERR_INTERNAL kèm request_id
		// (C-API-03, C-API-05). Handler không thêm nhánh nào ở đây — thêm một nhánh
		// nghĩa là việc dịch lỗi đã trôi lên sai tầng.
		response.Error(c, err)
		return
	}
```

Ba dấu hiệu cho thấy việc dịch lỗi đang xảy ra sai tầng, cả ba đều grep được:
`sql.ErrNoRows` trong `*_handler.go`; `errors.New(` hoặc `fmt.Errorf(` trong `*_handler.go`
để dựng giá trị đem trả về response; và `auth.FromContext(` trong `*_service.go`.

---

### C-GO-05 — Nội dung `module.yaml`

**Implements:** R-02, R-05, R-15

`module.yaml` nằm cạnh `module.go`, tại `modules/<A>/module.yaml`. Nó không được code đọc
lúc chạy — nó là **đầu vào của bộ kiểm**. Ba Rule không có cách nào kiểm bằng máy nếu thiếu
file này.

```yaml
# modules/order/module.yaml
name: order

tables:
  - orders
  - order_items

allowed_deps:
  - customer
  - product

internal_methods:
  - InternalRecalculateTotals
```

| Trường | Nghĩa | Là căn cứ của | Thiếu nó thì sao |
|---|---|---|---|
| `name` | Tên module, **khớp đúng tên thư mục** dưới `modules/` | Mọi lệnh quét định vị module theo tên | Không đối chiếu được `allowed_deps` của module khác với module này |
| `tables` | Danh sách bảng module này được query | R-02 | Không biết một tên bảng trong SQL của repository là hợp lệ hay là truy cập chéo module |
| `allowed_deps` | Danh sách module A được gọi đồng bộ | R-05 (mệnh đề 1), R-04 | Không biết một dòng import module khác là hợp lệ hay phải đi qua event |
| `internal_methods` | Danh sách method `Internal*` được phép tồn tại | Ngoại lệ R-15 | Mọi method `Internal*` đều là một ngoại lệ tự cấp cho mình |

#### `tables` — căn cứ của R-02

`tables` liệt kê **mọi** bảng mà repository của module này được đặt tên trong câu SQL. Một
tên bảng xuất hiện trong `modules/order/**/repository` mà không có trong danh sách này là
vi phạm R-02, kể cả khi nó chỉ nằm trong một mệnh đề `JOIN`.

- Viết đúng tên bảng thật, số nhiều, snake_case (C-DB-01): `orders`, không phải `order`.
- Bảng trong `system_tables`, `tenant_root` và `reference_tables` **không** cần liệt
  kê: mọi module đọc được chúng (ngoại lệ của R-02). Registry ba nhóm đó ở
  [C-DB-database.md](C-DB-database.md) mục `C-DB-04`.
- `outbox` và `audit_logs` **không** liệt kê ở đây: module không có repository nào chạm
  vào chúng. Đường vào duy nhất là `outbox.Repository` và `audit.Repository` của `shared/`,
  gọi từ service (R-05, R-17).
- Một bảng chỉ thuộc **đúng một** module. Hai module cùng khai một tên bảng là dấu hiệu
  ranh giới module đang sai, và sửa nó cần một ADR chứ không phải sửa file này.

#### `allowed_deps` — căn cứ của R-05

`allowed_deps` liệt kê module mà service của A được gọi **đồng bộ**, qua `api/` của module
đó (R-01). Module không có tên ở đây thì A phải đi qua event.

- R-04 cấm quan hệ hai chiều: nếu `customer` có tên trong `allowed_deps` của `order` thì
  `order` **cấm** có tên trong `allowed_deps` của `customer`. Hai file đọc cạnh nhau là đủ
  kết luận, không cần dò cả đồ thị.
- Thêm một tên vào đây là một quyết định kiến trúc, không phải thao tác dọn dẹp để build
  xanh. Câu hỏi phải trả lời trước khi thêm nằm ở
  [../02-principles/P-EVT-events.md](../02-principles/P-EVT-events.md): *"nếu việc kia
  hỏng, việc này còn được coi là đã xong không?"* Trả lời "không" thì mới cần gọi đồng bộ.
- `allowed_deps` **không** cho phép chia sẻ transaction. Gọi service của module khác nghĩa
  là module đó tự mở transaction của nó, nên có **hai** transaction chứ không phải một
  ([../02-principles/P-TXN-transaction-boundary.md](../02-principles/P-TXN-transaction-boundary.md)).

#### `internal_methods` — căn cứ của ngoại lệ R-15

R-15 buộc mọi method public của service mở đầu bằng một lời gọi kiểm quyền. Ngoại lệ duy
nhất là method mang tiền tố `Internal`, và nó chỉ có hiệu lực khi tên method có mặt trong
trường này.

Ba điều kiện, phải đủ cả ba:

1. Tên method mang tiền tố `Internal`.
2. Tên method có trong `internal_methods` của `module.yaml` thuộc chính module đó.
3. Tên method **không** xuất hiện trong bất kỳ interface nào thuộc `modules/*/api/`.

Method `Internal*` vẫn phải nhận `actor auth.Actor` làm tham số thứ hai, và vẫn phải tự
ghi bản ghi audit theo R-17. Thứ duy nhất nó được miễn là vế "câu lệnh đầu tiên là kiểm
quyền" — vì người gọi nó, một service khác trong cùng module, đã kiểm quyền rồi.

**`internal_methods` chỉ dùng cho lời gọi giữa các service trong CÙNG một module. Nó không
phải đường gọi xuyên module.** Điều kiện (3) cộng với R-01 khóa chặt điều này: R-01 chỉ cho
module khác import `modules/<A>/api/`, mà `Internal*` bị cấm có mặt ở đó — module ngoài
không bao giờ chạm tới được. Gặp ca hai module phải cùng commit nguyên tử thì dừng lại và
hỏi người; đó là ca cần một ADR mở đường chứ không phải chỗ lách bằng `Internal*`.

#### Vì sao là YAML cạnh code chứ không phải một file cấu hình trung tâm

Một file duy nhất liệt kê ranh giới của mọi module sẽ thành file bị sửa trong mọi PR, xung
đột merge liên tục, và không ai đọc. Đặt cạnh `module.go` thì diff của một PR tự nó nói
"PR này mở rộng ranh giới của module order", và người review nhìn thấy điều đó ngay trong
danh sách file thay đổi — trước khi đọc một dòng Go nào.

---

### C-GO-06 — Chữ ký method service, actor và kiểm quyền

**Implements:** R-15, R-17

#### Chữ ký chuẩn

```go
func (s *OrderService) CreateOrder(ctx context.Context, actor auth.Actor, in CreateOrderInput) (*model.Order, error)
```

Bốn phần, không phần nào linh động:

| Phần | Quy tắc |
|---|---|
| Receiver | `s`, kiểu `*<Danh từ>Service` — R-15 quét bằng regex `^func \(s \*\w+Service\)` |
| Tham số 1 | `ctx context.Context`, luôn (R-17) |
| Tham số 2 | `actor auth.Actor`, luôn — kể cả với method `Internal*` |
| Tham số 3 trở đi | Dữ liệu nghiệp vụ; nhiều hơn hai tham số thì gom vào `<Method>Input` |

Câu lệnh **đầu tiên** của thân hàm:

```go
	if err := s.authz.Can(ctx, actor, PermOrderCreate); err != nil {
		return nil, err
	}
```

Không có dòng nào đứng trước nó. Không log, không validate, không gán biến, không kể cả
một dòng lấy actor ra.

#### Vì sao nhận actor tường minh thay vì moi từ `ctx`

Đây là câu hỏi hay gặp nhất về R-15, và câu trả lời nằm ngay trong chính mệnh đề của rule.
R-15 đòi kiểm quyền là **câu lệnh đầu tiên** của thân hàm. Nếu actor lấy từ `ctx` thì phải
có một dòng đứng trước:

```go
	actor := auth.FromContext(ctx) // đây mới là câu lệnh đầu tiên
	if err := s.authz.Can(ctx, actor, PermOrderCreate); err != nil {
		return nil, err
	}
```

Kiểm quyền tụt xuống thành câu lệnh **thứ hai**, tự nó vi phạm rule. Và một khi đã chấp nhận
"được phép có một dòng đứng trước", vế đó không còn kiểm được bằng máy nữa: dòng đứng trước
là một dòng hay ba mươi dòng thì grep không phân biệt được.

Ba hệ quả kèm theo, đều đáng giá độc lập với chuyện grep:

- **Chuỗi `auth.FromContext(` trở thành thứ grep được.** Nó chỉ được xuất hiện trong
  `*_handler.go`. Một lần xuất hiện trong `*_service.go` là vi phạm, không cần đọc ngữ
  cảnh.
- **Service test được mà không cần dựng `ctx` giả.** Truyền thẳng `auth.Actor{...}` vào
  tham số; không phải mô phỏng middleware để test một quy tắc nghiệp vụ (P-TEST).
- **Chữ ký nói thật về thứ method cần.** Một method nhận actor là một method có kiểm quyền;
  đọc chữ ký là biết, không phải đọc thân hàm để tìm xem nó có moi gì ra khỏi `ctx` không.

Đối xứng ở phía kia: **handler là nơi duy nhất gọi `auth.FromContext(ctx)`** (R-14, R-15).
Nó lấy actor ra một lần rồi truyền xuống. Handler cũng cấm chứa logic quyền — không
`if user.Role == "admin"`, không `if !user.HasPermission(...)`; ẩn nút ở frontend không
tính là kiểm quyền (C-TS-06).

#### Ví dụ hoàn chỉnh — tham chiếu cho mọi module sau này

Luồng đầy đủ của một request ghi: handler → service → hai repository → audit → outbox →
commit. Đọc theo thứ tự dưới lên: model, repository, service, handler, `module.go`.

```go
// modules/order/internal/model/order.go
package model

import (
	"time"

	"github.com/shopspring/decimal"
)

// Order ánh xạ bảng orders. Tiền là decimal.Decimal vì cột là NUMERIC(18,4)
// (C-DB-02); dùng float64 ở đây là đưa lại đúng sai số mà NUMERIC sinh ra để tránh.
// Struct model chỉ có tag db — tag json thuộc về DTO ở package handler.
type Order struct {
	ID          string          `db:"id"`
	CompanyID   string          `db:"company_id"`
	CustomerID  string          `db:"customer_id"`
	Code        string          `db:"code"`
	Status      string          `db:"status"`
	TotalAmount decimal.Decimal `db:"total_amount"`
	CreatedAt   time.Time       `db:"created_at"`
	UpdatedAt   time.Time       `db:"updated_at"`
	CreatedBy   string          `db:"created_by"`
	UpdatedBy   string          `db:"updated_by"`
}

// OrderItem ánh xạ bảng order_items. Nó có company_id riêng dù đã có order_id: R-06
// đòi mọi bảng nghiệp vụ có company_id và mọi câu truy vấn lọc theo nó, không đi
// đường vòng qua bảng cha.
type OrderItem struct {
	ID        string          `db:"id"`
	CompanyID string          `db:"company_id"`
	OrderID   string          `db:"order_id"`
	ProductID string          `db:"product_id"`
	Quantity  int             `db:"quantity"`
	UnitPrice decimal.Decimal `db:"unit_price"`
	Amount    decimal.Decimal `db:"amount"`
	CreatedBy string          `db:"created_by"`
	UpdatedBy string          `db:"updated_by"`
}
```

```go
// modules/order/internal/repository/order_item_repository.go
package repository

import (
	"context"
	"fmt"

	"erp/modules/order/internal/model"
)

type OrderItemRepository interface {
	InsertMany(ctx context.Context, db DBTX, items []model.OrderItem) error
}

type orderItemRepo struct{}

func NewOrderItemRepository() OrderItemRepository { return &orderItemRepo{} }

// InsertMany nhận cùng DBTX với orderRepo.Insert, nên các dòng order_items và dòng
// orders cùng commit hoặc cùng biến mất. Đây là toàn bộ lý do DBTX là tham số.
func (r *orderItemRepo) InsertMany(ctx context.Context, db DBTX, items []model.OrderItem) error {
	const q = `
INSERT INTO order_items (id, company_id, order_id, product_id, quantity,
                         unit_price, amount, created_by, updated_by)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`

	for _, it := range items {
		if _, err := db.ExecContext(ctx, q, it.ID, it.CompanyID, it.OrderID, it.ProductID,
			it.Quantity, it.UnitPrice, it.Amount, it.CreatedBy, it.UpdatedBy); err != nil {
			return fmt.Errorf("insert order_item %s: %w", it.ID, err)
		}
	}
	return nil
}
```

```go
// modules/order/internal/service/order_service.go
package service

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"

	"github.com/google/uuid"
	"github.com/jmoiron/sqlx"
	"github.com/shopspring/decimal"

	customerapi "erp/modules/customer/api"
	"erp/modules/order/internal/model"
	"erp/modules/order/internal/repository"
	"erp/shared/audit"
	"erp/shared/auth"
	"erp/shared/authz"
	apperr "erp/shared/errors"
	"erp/shared/outbox"
	"erp/shared/requestid"
)

const (
	PermOrderCreate = "order.create"
	PermOrderRead   = "order.read"
)

// OrderService sở hữu ranh giới transaction, nên nó — và chỉ nó — giữ *sqlx.DB
// (C-GO-03). Repository không giữ gì cả; chúng nhận DBTX qua tham số ở từng lời gọi.
type OrderService struct {
	db         *sqlx.DB
	authz      authz.Checker
	orderRepo  repository.OrderRepository
	itemRepo   repository.OrderItemRepository
	auditRepo  audit.Repository
	outboxRepo outbox.Repository
	customers  customerapi.CustomerReader
}

// Deps gom phụ thuộc để chữ ký NewOrderService không dài ra theo thời gian và để chỗ
// gọi ở module.go đọc được tên từng thứ.
type Deps struct {
	DB         *sqlx.DB
	Authz      authz.Checker
	OrderRepo  repository.OrderRepository
	ItemRepo   repository.OrderItemRepository
	AuditRepo  audit.Repository
	OutboxRepo outbox.Repository
	Customers  customerapi.CustomerReader
}

func NewOrderService(d Deps) *OrderService {
	return &OrderService{
		db:         d.DB,
		authz:      d.Authz,
		orderRepo:  d.OrderRepo,
		itemRepo:   d.ItemRepo,
		auditRepo:  d.AuditRepo,
		outboxRepo: d.OutboxRepo,
		customers:  d.Customers,
	}
}

// CreateOrderInput là đầu vào THÔ. Không có TotalAmount: tổng tiền do service tính,
// frontend chỉ gửi quantity và unit_price rồi render lại con số backend trả về
// (R-19, C-TS-05).
type CreateOrderInput struct {
	CustomerID string
	Code       string
	Items      []CreateOrderItemInput
}

type CreateOrderItemInput struct {
	ProductID string
	Quantity  int
	UnitPrice string
}

type orderCreatedPayload struct {
	OrderID   string `json:"order_id"`
	CompanyID string `json:"company_id"`
	Code      string `json:"code"`
}

// CreateOrder là ví dụ tham chiếu cho mọi method ghi của mọi module. Trình tự:
// kiểm quyền -> chuẩn bị dữ liệu NGOÀI transaction -> BEGIN -> repository nghiệp vụ
// -> audit -> outbox -> COMMIT. Không có bus.Publish ở bất kỳ vị trí nào (R-05).
func (s *OrderService) CreateOrder(ctx context.Context, actor auth.Actor, in CreateOrderInput) (*model.Order, error) {
	// Câu lệnh ĐẦU TIÊN của thân hàm là kiểm quyền (R-15).
	if err := s.authz.Can(ctx, actor, PermOrderCreate); err != nil {
		return nil, err
	}

	// Mọi thứ không cần giữ khóa đều làm TRƯỚC khi mở transaction (P-TXN): lời gọi
	// sang module khác, tính toán, dựng struct, marshal payload. customer có tên
	// trong allowed_deps của order nên lời gọi đồng bộ này hợp lệ (C-GO-05), và nó
	// đi qua customerapi chứ không chạm vào package nội bộ nào của customer (R-01).
	cust, err := s.customers.GetByID(ctx, in.CustomerID)
	if err != nil {
		return nil, err
	}

	o := &model.Order{
		ID:         uuid.NewString(),
		CompanyID:  actor.CompanyID,
		CustomerID: cust.ID,
		Code:       in.Code,
		Status:     "draft",
		CreatedBy:  actor.UserID,
		UpdatedBy:  actor.UserID,
	}

	items := make([]model.OrderItem, 0, len(in.Items))
	total := decimal.Zero
	for i, it := range in.Items {
		price, err := decimal.NewFromString(it.UnitPrice)
		if err != nil {
			// Ràng buộc binding ở handler đã chặn chuỗi không phải số, nên tới được
			// đây là lỗi lập trình chứ không phải lỗi người dùng sửa được: bọc ngữ
			// cảnh và để handler trả ERR_INTERNAL (P-ERR).
			return nil, fmt.Errorf("parse unit_price cua item %d: %w", i, err)
		}
		amount := price.Mul(decimal.NewFromInt(int64(it.Quantity)))
		total = total.Add(amount)
		items = append(items, model.OrderItem{
			ID:        uuid.NewString(),
			CompanyID: actor.CompanyID,
			OrderID:   o.ID,
			ProductID: it.ProductID,
			Quantity:  it.Quantity,
			UnitPrice: price,
			Amount:    amount,
			CreatedBy: actor.UserID,
			UpdatedBy: actor.UserID,
		})
	}
	// Tổng tiền tính ở BACKEND, không nhận từ request (R-19, ADR-0009).
	o.TotalAmount = total

	payload, err := json.Marshal(orderCreatedPayload{
		OrderID:   o.ID,
		CompanyID: o.CompanyID,
		Code:      o.Code,
	})
	if err != nil {
		return nil, fmt.Errorf("marshal payload order.created %s: %w", o.ID, err)
	}

	// --- BEGIN: từ đây tới Commit là MỘT quyết định nghiệp vụ ---
	tx, err := s.db.BeginTxx(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("begin tx create order: %w", err)
	}
	// Đây là chỗ duy nhất được bỏ qua lỗi mà không cần giải trình (P-ERR): Rollback
	// sau một Commit thành công trả lỗi vô hại.
	defer tx.Rollback()

	if err := s.orderRepo.Insert(ctx, tx, o); err != nil {
		return nil, translateWrite(err)
	}
	if err := s.itemRepo.InsertMany(ctx, tx, items); err != nil {
		return nil, translateWrite(err)
	}

	// Audit nhận CÙNG tx với repository nghiệp vụ và được gọi TRƯỚC commit (R-17):
	// không thể có chuyện đơn hàng tồn tại mà audit trail không biết.
	if err := s.auditRepo.Record(ctx, tx, audit.Entry{
		CompanyID: actor.CompanyID,
		ActorID:   actor.UserID,
		RequestID: requestid.FromContext(ctx),
		Action:    "order.created",
		EntityID:  o.ID,
	}); err != nil {
		return nil, err
	}

	// Outbox cũng nhận CÙNG tx (R-05). EventID sinh MỘT lần tại đây, bên trong
	// transaction, và giữ nguyên qua mọi lần relay gửi lại — đó là khóa dedupe duy
	// nhất mà consumer có (P-IDEM).
	if err := s.outboxRepo.Append(ctx, tx, outbox.Event{
		EventID:     uuid.NewString(),
		CompanyID:   o.CompanyID,
		EventType:   "order.created",
		AggregateID: o.ID,
		CreatedBy:   actor.UserID,
		Payload:     payload,
	}); err != nil {
		return nil, err
	}

	// --- COMMIT. Sau dòng này service không làm gì thêm: không publish, không gọi
	// mạng, không gửi mail. Relay đọc outbox và publish, ở một tiến trình khác. ---
	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("commit tx create order %s: %w", o.ID, err)
	}
	return o, nil
}

// GetOrder là đường đọc: không mở transaction, truyền s.db vào đúng tham số DBTX mà
// tx vừa đi qua ở trên (C-GO-03). Đây cũng là chỗ sql.ErrNoRows được dịch — và dịch
// theo ENDPOINT đang phục vụ, không theo tên method repository (P-ERR).
func (s *OrderService) GetOrder(ctx context.Context, actor auth.Actor, id string) (*model.Order, error) {
	if err := s.authz.Can(ctx, actor, PermOrderRead); err != nil {
		return nil, err
	}

	o, err := s.orderRepo.GetByID(ctx, s.db, actor.CompanyID, id)
	switch {
	case err == nil:
		return o, nil
	case errors.Is(err, sql.ErrNoRows):
		// "Không tồn tại" và "tồn tại nhưng thuộc công ty khác" cho ra cùng một
		// ErrNoRows, và phải cho ra cùng một câu trả lời 404: trả 403 ở ca thứ hai là
		// xác nhận với người ngoài rằng bản ghi đó có tồn tại (C-API-02).
		return nil, apperr.NotFound(apperr.CodeOrderNotFound, "don hang khong ton tai")
	default:
		return nil, fmt.Errorf("get order %s: %w", id, err)
	}
}
```

```go
// modules/order/internal/handler/order_handler.go
package handler

import (
	"time"

	"github.com/gin-gonic/gin"

	"erp/modules/order/internal/model"
	"erp/modules/order/internal/service"
	"erp/shared/auth"
	"erp/shared/response"
)

// OrderHandler làm đúng bốn việc: bind request, lấy actor, gọi service, đẩy kết quả
// qua shared/response. Không sqlx (R-03), không so sánh role (R-15), không c.JSON
// trực tiếp (R-11), không dịch lỗi (P-ERR).
type OrderHandler struct {
	svc *service.OrderService
}

func New(svc *service.OrderService) *OrderHandler { return &OrderHandler{svc: svc} }

// CreateOrderRequest là DTO của lớp HTTP, sống ở package handler chứ không ở api/:
// api/ là hợp đồng với module khác, cái này là hợp đồng với client HTTP. Gộp hai vai
// vào một struct nghĩa là một thay đổi vì giao diện web kéo theo breaking change cho
// module nội bộ, và ngược lại.
//
// Không có field company_id: công ty lấy từ actor (R-06). Không có field
// total_amount: tiền do backend tính (R-19).
type CreateOrderRequest struct {
	CustomerID string              `json:"customer_id" binding:"required,uuid"`
	Code       string              `json:"code" binding:"required,max=32"`
	Items      []createItemRequest `json:"items" binding:"required,min=1,dive"`
}

type createItemRequest struct {
	ProductID string `json:"product_id" binding:"required,uuid"`
	Quantity  int    `json:"quantity" binding:"required,gt=0"`
	UnitPrice string `json:"unit_price" binding:"required,numeric"`
}

// OrderDTO là hình dạng JSON trả ra. TotalAmount là CHUỖI: cột là NUMERIC(18,4) và
// tuần tự hóa nó thành số JSON là đưa nó qua double của JavaScript (C-API-03).
type OrderDTO struct {
	ID          string `json:"id"`
	Code        string `json:"code"`
	Status      string `json:"status"`
	TotalAmount string `json:"total_amount"`
	CreatedAt   string `json:"created_at"`
}

func toOrderDTO(o *model.Order) OrderDTO {
	return OrderDTO{
		ID:          o.ID,
		Code:        o.Code,
		Status:      o.Status,
		TotalAmount: o.TotalAmount.StringFixed(4),
		CreatedAt:   o.CreatedAt.Format(time.RFC3339),
	}
}

func (h *OrderHandler) Create(c *gin.Context) {
	var req CreateOrderRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		// Sai hình dạng request là 422 kèm danh sách field (R-10, C-API-02).
		// FieldErrors dịch lỗi validator sang []response.FieldError đúng hình dạng
		// C-API-03: đường dẫn field theo tag json, phần tử mảng đánh chỉ số từ 0.
		response.ValidationFailed(c, response.FieldErrors(err))
		return
	}

	// ctx của request đi xuyên suốt xuống service và repository (R-17). Không
	// context.Background(), không context.TODO().
	ctx := c.Request.Context()

	// Handler là NƠI DUY NHẤT gọi auth.FromContext (R-14, R-15).
	actor := auth.FromContext(ctx)

	in := service.CreateOrderInput{
		CustomerID: req.CustomerID,
		Code:       req.Code,
		Items:      make([]service.CreateOrderItemInput, 0, len(req.Items)),
	}
	for _, it := range req.Items {
		in.Items = append(in.Items, service.CreateOrderItemInput{
			ProductID: it.ProductID,
			Quantity:  it.Quantity,
			UnitPrice: it.UnitPrice,
		})
	}

	o, err := h.svc.CreateOrder(ctx, actor, in)
	if err != nil {
		response.Error(c, err)
		return
	}

	// POST tạo mới trả 201 (R-10).
	response.Created(c, toOrderDTO(o))
}

func (h *OrderHandler) Get(c *gin.Context) {
	ctx := c.Request.Context()
	actor := auth.FromContext(ctx)

	o, err := h.svc.GetOrder(ctx, actor, c.Param("id"))
	if err != nil {
		response.Error(c, err)
		return
	}
	response.Success(c, toOrderDTO(o))
}
```

```go
// modules/order/module.go
package order

import (
	"github.com/gin-gonic/gin"
	"github.com/jmoiron/sqlx"

	customerapi "erp/modules/customer/api"
	"erp/modules/order/internal/handler"
	"erp/modules/order/internal/repository"
	"erp/modules/order/internal/service"
	"erp/shared/audit"
	"erp/shared/authz"
	"erp/shared/outbox"
)

type Deps struct {
	DB        *sqlx.DB
	Authz     authz.Checker
	Audit     audit.Repository
	Outbox    outbox.Repository
	Customers customerapi.CustomerReader
}

type Module struct {
	handler *handler.OrderHandler
}

// New là chỗ duy nhất *sqlx.DB được trao tay bên trong module, và nó chỉ đi vào
// service. Hai repository nhận zero phụ thuộc — chúng lấy DBTX qua tham số ở từng
// lời gọi (C-GO-03). Mọi kiểu nội bộ chỉ xuất hiện ở đây, không lọt ra chữ ký hàm mà
// cmd/** nhìn thấy (R-01).
func New(d Deps) *Module {
	svc := service.NewOrderService(service.Deps{
		DB:         d.DB,
		Authz:      d.Authz,
		OrderRepo:  repository.NewOrderRepository(),
		ItemRepo:   repository.NewOrderItemRepository(),
		AuditRepo:  d.Audit,
		OutboxRepo: d.Outbox,
		Customers:  d.Customers,
	})
	return &Module{handler: handler.New(svc)}
}

// Register nhận group /api/v1 do composition root dựng, nên ở đây chỉ khai phần đuôi.
// Tiền tố /api/v1 xuất hiện đúng một lần trong toàn hệ thống (C-API-06).
func (m *Module) Register(r gin.IRouter) {
	g := r.Group("/orders")
	g.POST("", m.handler.Create)
	g.GET("/:id", m.handler.Get)
}
```

#### Đọc lại ví dụ theo checklist

| Điều phải đúng | Ở đâu trong ví dụ |
|---|---|
| `ctx` là tham số thứ nhất ở mọi tầng (R-17) | Mọi method của service và repository |
| `actor` là tham số thứ hai của method service (R-15) | `CreateOrder`, `GetOrder` |
| Câu lệnh đầu tiên là `s.authz.Can` (R-15) | `CreateOrder`, `GetOrder` |
| `auth.FromContext` chỉ ở handler (R-14, R-15) | `Create`, `Get` của `OrderHandler` |
| `company_id` lấy từ actor, không từ request (R-06) | `o.CompanyID = actor.CompanyID`; DTO request không có field đó |
| Ranh giới transaction chỉ ở service (R-03, P-TXN) | `BeginTxx`/`Commit`/`Rollback` chỉ có trong `order_service.go` |
| Repository nhận `DBTX` qua tham số (C-GO-03) | `Insert`, `InsertMany`, `GetByID` |
| Audit trong cùng transaction (R-17) | `auditRepo.Record(ctx, tx, ...)` trước `Commit` |
| Outbox trong cùng transaction (R-05) | `outboxRepo.Append(ctx, tx, ...)` trước `Commit` |
| Không có `bus.Publish` trong `modules/**` (R-05) | Không xuất hiện dòng nào; relay lo việc đó |
| Tiền tính ở backend (R-19) | `o.TotalAmount = total`, không nhận từ `CreateOrderRequest` |
| Response đi qua `shared/response` (R-11) | `response.Created`, `response.Success`, `response.Error` |

---

### C-GO-07 — SQL phải là một hằng chuỗi đơn

**Implements:** R-02, R-06, R-09, R-18

Câu SQL trong `*_repository.go` phải là **một `BasicLit` đơn** khai bằng `const`. Cấm
nối chuỗi — kể cả nối hai hằng — cấm `fmt.Sprintf`, `strings.Builder`, và mọi cách dựng
SQL lúc chạy.

```go
// ĐÚNG: mot BasicLit don
const insertOrderSQL = `
INSERT INTO orders (id, company_id, code)
VALUES ($1, $2, $3)`

// SAI: noi hai hang. Go coi day la constant expression, nhung checker thi phai
// evaluate expression moi biet chuoi cuoi cung la gi - va the la mo lai dung canh cua
// ma quy uoc nay dong.
const badSQL = "SELECT * FROM orders" + " WHERE company_id = $1"

// SAI: dung luc chay, khong phan tich tinh duoc.
q := fmt.Sprintf("SELECT * FROM %s WHERE company_id = $1", table)
```

**Vì sao quy ước nhỏ này quan trọng hơn vẻ ngoài của nó:** bốn Rule — R-02, R-06,
R-09, R-18 — đều cần đọc được câu SQL thật để kiểm. Với SQL là hằng, checker trích ra
bằng AST và parse được. Với SQL dựng lúc chạy, cả bốn mù hoàn toàn. Nói cách khác, bốn
rule đó **chỉ đạt mức FULL khi quy ước này được tuân thủ**; bỏ nó là hạ cả bốn xuống
mức kiểm được một phần.

Nó cũng đóng luôn lỗ SQL injection, và R-12 đã đòi điều tương tự cho `sort` — đây là
mở rộng ra toàn bộ.

**Lọc động thì làm sao:** viết sẵn vài hằng cho từng tổ hợp, hoặc dùng điều kiện bỏ qua
được ngay trong SQL:

```go
const listOrdersSQL = `
SELECT id, code, status FROM orders
WHERE company_id = $1
  AND deleted_at IS NULL
  AND ($2::text IS NULL OR status = $2)
ORDER BY created_at DESC
LIMIT $3 OFFSET $4`
```

Truyền `nil` cho `$2` khi không lọc theo trạng thái. Một hằng phục vụ cả hai trường
hợp, và checker vẫn đọc được nó.

---

### C-GO-08 — Bảng vai trò tới được composition root bằng đường nào

**Implements:** R-15, R-04, R-01

C-GO-02 đã chốt định dạng chuỗi permission và nơi hằng sống: `<module>.<hành động>`, ví dụ
`const PermOrderCreate = "order.create"`, khai ở package `service` của module sở hữu. Mục
này **không** đổi điều đó. Nó chốt thứ C-GO-02 để trống: **bảng vai trò → permission sống ở
đâu, và làm sao nó chạm tới được những hằng kia.**

Câu hỏi nghe nhỏ, nhưng hai đáp án tự nhiên nhất đều vi phạm rule.

#### Hai đường sai, và rule nào chặn chúng

**Sai 1 — để bảng vai trò trong `shared/authz`.** Bảng đó phải nhắc tên từng permission của
từng module, nên `shared/` sẽ phải import `modules/`. Đó là **R-04**, và vi phạm ở đúng chỗ
R-04 sinh ra để chặn: phụ thuộc chạy từ `modules/` xuống `shared/`, không bao giờ ngược lại.

**Sai 2 — để `cmd/api` import thẳng `modules/<A>/api/` hoặc `modules/<A>/internal/service/`
để lấy hằng.** Đây là chỗ dễ sai nhất vì nó *nghe* hợp lý — `api/` vốn là thứ module khác
được import. Nhưng R-01 nói riêng về composition root:

> Composition root `cmd/**` chỉ được import package chứa `modules/<A>/module.go` — cấm
> import bất kỳ package con nào **khác** của module. Dòng import trong `cmd/**` còn nhiều
> hơn một segment sau `modules/` (ví dụ `erp/modules/order/api`) là dấu hiệu vi phạm.

`cmd/**` **không** được import `api/`. Chỉ đúng `erp/modules/order` mới hợp lệ. Và đây là
R-01 — rule duy nhất đang ở mức **FULL** — nên `checkR01` bắt ngay dòng import đầu tiên.

#### Đường đúng: module xuất permission ở package gốc

Package gốc của module — nơi có `module.go` — là mặt tiếp xúc **duy nhất** giữa module và
composition root. Vậy permission đi ra qua đúng cửa đó:

```go
// modules/order/module.go
package order

import "erp/modules/order/internal/service"

// Permission cua module, xuat lai o package goc. Hang that song trong internal/service
// theo C-GO-02; day chi la CUA RA.
//
// Vi sao phai co cua nay: cmd/api dung bang vai tro nen no phai goi ten tung permission,
// ma R-01 cam cmd/** import ca api/ lan internal/service/. Khong co cua nay thi duong
// vong duy nhat con lai la chep tay chuoi "order.create" vao cmd/api - hai ban cua cung
// mot chuoi o hai noi, va mot lan doi ten permission se lam mot vai tro mat quyen trong
// khi build van xanh.
const (
	PermCreate  = service.PermOrderCreate
	PermRead    = service.PermOrderRead
	PermApprove = service.PermOrderApprove
)
```

```go
// cmd/internal/vaitro/vaitro.go
package vaitro

import (
	"erp/modules/order"
	"erp/modules/user"
	"erp/shared/authz"
)

// Bang la DU LIEU, va no song o day vi day la noi duy nhat duoc biet CA HAI phia:
// danh sach vai tro cua he thong, va permission cua tung module.
func Bang() authz.Bang {
	return authz.Bang{
		"admin":  {user.PermCreate, user.PermList, order.PermCreate, order.PermApprove},
		"sale":   {order.PermCreate, order.PermRead},
		"viewer": {user.PermList, order.PermRead},
	}
}
```

**Bảng sống ở `cmd/internal/vaitro`, không ở `cmd/api` ([ADR-0010](../03-decisions/ADR-0010-bang-vai-tro-o-cmd-internal.md)).**
Hệ thống có **nhiều hơn một** composition root — `cmd/api` phục vụ HTTP, `cmd/dev
bootstrap-user` tạo user đầu tiên — và hai `package main` không import được nhau. Mỗi root
một bảng nghĩa là hai bản của cùng một danh sách, và chúng lệch về phía im lặng: root nào
khai lỏng hơn thì chấp nhận mọi tên vai trò mà không bao giờ đỏ.

`cmd/internal/` giải điều đó mà không nới rule nào: quy tắc `internal/` của Go chặn mọi
thứ ngoài cây `cmd/` import nó, còn `checkR01` đọc đường dẫn file nên package này chịu
**đúng** ràng buộc của composition root — chỉ được import package gốc của module, cấm
`api/`, cấm `internal/`.

Một root được phép thêm vai trò **tạm** của riêng nó vào bản nhận về (ví dụ `bootstrap` ở
`cmd/dev`, phạm vi đúng một hai permission). Vai trò tạm không nằm trong bảng chung, không
user nào mang được, và không token nào ký ra nó.

`shared/authz` khai `Checker` với `Can(ctx, actor, perm) error` và một bản cài đặt **nhận
bảng làm dữ liệu**. Nó không biết permission nào tồn tại, và đó chính là điều kiện để nó
không phải import `modules/`.

#### Hệ quả có lợi: mất quyền lộ ra lúc biên dịch

Xóa hoặc đổi tên một hằng permission làm **vỡ build của mọi composition root**. Đó là hành vi mong
muốn: một vai trò mất quyền phải lộ ra lúc biên dịch, không phải lúc một người dùng thật
bấm nút và nhận `403`.

Ngược lại, chép tay chuỗi `"order.create"` vào bảng thì đổi tên permission vẫn build xanh,
và lỗi chỉ hiện ra ở môi trường thật.

Cùng lý do đó áp cho **tên vai trò**: chúng là dữ liệu nằm trong cột `users.roles`, nên
không trình biên dịch nào kiểm được chính tả của chúng. Thứ kiểm được là
`authz.Checker.VaiTroTonTai(role)` — service hỏi nó trước mỗi lần gán, và câu trả lời chỉ
đáng tin khi bảng tiêm vào là bảng thật. Đó là lý do thứ hai khiến bảng phải có đúng một
bản.

#### Cách kiểm

```powershell
# cmd/** - ke ca cmd/internal/** - chi duoc import package goc cua module; R-01 canh san
go test ./arch/ -run TestProductionCode

# Khong root nao duoc khai bang vai tro rieng: chi mot cho goi authz.Bang{
Select-String -Path cmd\*\*.go -Pattern 'authz\.Bang\{' 

# shared/ khong duoc import modules/ - R-04 canh san
Select-String -Path shared\*\*.go -Pattern 'erp/modules/'
```
