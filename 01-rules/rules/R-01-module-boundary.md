# R-01 — Module Boundary

Trang này mở rộng entry trong [../RULES.md](../RULES.md). Mệnh đề bắt buộc nằm ở đó,
không lặp lại ở đây.

## Vì sao

Vế `internal/` của rule này đã có compiler lo. Quy tắc `internal/` của Go áp theo
**cây thư mục**, không phụ thuộc ranh giới Go module: một package nằm tại
`.../a/internal/...` **chỉ** được import bởi code nằm trong cây gốc `.../a/`. Vì vậy
file thuộc `erp/modules/order/` import `erp/modules/customer/internal/model` là **lỗi
biên dịch** — `go build` từ chối thẳng với thông báo dạng `use of internal package
erp/modules/customer/internal/model not allowed`. Không cần review, không cần grep,
và không lách được bằng cách nào ngoài việc đổi cấu trúc thư mục.

Giá trị thật của R-01 nằm ở vế thứ hai: **module khác chỉ được import
`modules/<A>/api/`**. Đây mới là chỗ compiler không giúp gì. Mọi package của A nằm
**ngoài** `internal/` — package gốc chứa `module.go`, và bất cứ thư mục nào ai đó
thêm sau này ở cấp `modules/customer/util/`, `modules/customer/model/` — đều import
được từ bất kỳ đâu trong repo, `go build` xanh, test xanh, không dòng nào chứa chuỗi
`internal` để mà grep. Chặn đúng nhóm đó là lý do rule này tồn tại.

Hệ quả trực tiếp: **bố cục package không phải chuyện thẩm mỹ, nó là điều kiện để vế
thứ nhất có hiệu lực**. Nếu service của Order nằm ở `modules/order/service/` thay vì
`modules/order/internal/service/`, module khác import thẳng vào service đó được,
compiler im lặng. Đặt mọi thứ trừ `api/` và `module.go` vào trong `internal/` chính
là cách chuyển phần lớn công việc kiểm rule này sang cho `go build`, chỉ để lại phần
nhỏ còn lại cho người và cho lệnh grep.

Với những import mà compiler cho qua, hậu quả không nằm ở chỗ "code chạy sai" — code
vẫn chạy bình thường, và đó chính là vấn đề. Khi team Customer đổi tên field, tách
struct, hay refactor lại cách biểu diễn dữ liệu bên trong module họ, họ có toàn quyền
làm vậy vì đó là chi tiết nội bộ. Nhưng nếu module Order đã bám vào một package ngoài
`api/` của Customer, một refactor nội bộ vô hại bỗng dưng làm vỡ build của team
Order — hai team không hề biết nhau đang phụ thuộc chéo cho tới khi CI đỏ. Càng nhiều
chỗ bám như vậy, chi phí của mỗi refactor nội bộ càng tăng, cho tới khi không ai dám
sửa gì bên trong module của mình nữa vì không biết ai đang bí mật phụ thuộc vào nó.

`api/` tồn tại chính là để hấp thụ cú sốc đó: nó là hợp đồng mà module Customer chủ
động cam kết giữ ổn định, khác với mọi thứ sau `internal/` là chi tiết triển khai có
thể đổi bất cứ lúc nào. Khi mọi phụ thuộc chéo module đều đi qua `api/`, một module
có thể được viết lại hoàn toàn bên trong — kể cả tách thành service riêng sau này —
mà không module nào khác phải đổi một dòng.

Vế thứ ba khóa composition root: `cmd/**` chỉ được import package gốc của module, nơi
đặt `module.go`. Composition root là chỗ duy nhất trong repo được phép biết mọi module
cùng lúc, nên nếu nó cũng được với tay vào từng package con thì việc dựng đối tượng
của module bị rải ra ngoài module, và mỗi lần Order đổi cách khởi tạo service là
`cmd/` phải sửa theo. `module.go` giữ toàn bộ việc đó lại bên trong module: `cmd/`
chỉ gọi `order.New(deps)` rồi `order.Register(router)`. Ở đây compiler cũng chỉ chặn
được nhánh `internal/` (vì `cmd/` nằm ngoài cây `modules/order/`); import
`erp/modules/order/api` từ `cmd/` thì biên dịch bình thường, nên đó là phần phải kiểm
bằng grep.

### Bố cục package chuẩn

```text
modules/<A>/
├── api/          # interface + DTO — thứ duy nhất module khác được import
├── internal/
│   ├── handler/
│   ├── service/
│   ├── repository/
│   └── model/
└── module.go     # hàm New/Register — thứ duy nhất cmd/** được import
```

Ba đường đi hợp lệ, không có đường thứ tư: module khác → `api/`; `cmd/**` →
`module.go`; chính module A → mọi thứ của A.

## Ví dụ SAI

```go
// modules/customer/internal/model/customer.go — chi tiết nội bộ, KHÔNG phải hợp đồng
package model

import "context"

type Customer struct {
	ID              string
	Name            string
	Email           string
	DiscountPercent int
}

type CustomerRepository interface {
	FindByID(ctx context.Context, id string) (*Customer, error)
}
```

```go
// modules/order/internal/service/order_service.go
package service

import (
	"context"

	// SAI: đây là lỗi biên dịch, không phải chuyện quy ước. Package
	// erp/modules/customer/internal/model chỉ import được bởi code nằm trong cây
	// erp/modules/customer/; file này nằm trong cây erp/modules/order/ nên go build
	// từ chối: "use of internal package ... not allowed".
	"erp/modules/customer/internal/model"
	"erp/shared/auth"
	"erp/shared/authz"
)

const PermOrderCreate = "order.create"

type OrderService struct {
	authz        authz.Checker
	customerRepo model.CustomerRepository
}

func (s *OrderService) ValidateCustomer(ctx context.Context, actor auth.Actor, customerID string) (*model.Customer, error) {
	if err := s.authz.Can(ctx, actor, PermOrderCreate); err != nil {
		return nil, err
	}
	return s.customerRepo.FindByID(ctx, customerID)
}
```

```go
// modules/order/internal/service/pricing_service.go
package service

import (
	"context"

	// SAI kiểu nguy hiểm hơn: package gốc của module customer (nơi đặt module.go)
	// KHÔNG nằm trong internal/, nên go build cho qua — không có lỗi biên dịch nào,
	// không có chuỗi "internal" nào để grep. Đây đúng là nhóm mà chỉ R-01 chặn được:
	// module order đang bám vào kiểu khởi tạo của module customer thay vì hợp đồng
	// customer/api.
	"erp/modules/customer"
	"erp/shared/auth"
	"erp/shared/authz"
)

const PermOrderRead = "order.read"

type PricingService struct {
	authz          authz.Checker
	customerModule *customer.Module
}

func (s *PricingService) DiscountFor(ctx context.Context, actor auth.Actor, customerID string) (int, error) {
	if err := s.authz.Can(ctx, actor, PermOrderRead); err != nil {
		return 0, err
	}

	c, err := s.customerModule.Customers().GetByID(ctx, customerID)
	if err != nil {
		return 0, err
	}
	return c.DiscountPercent, nil
}
```

```go
// cmd/api/main.go
package main

import (
	"github.com/gin-gonic/gin"
	"github.com/jmoiron/sqlx"

	// SAI: composition root với tay vào package con của module. Dòng
	// internal/handler là lỗi biên dịch (cmd/ nằm ngoài cây erp/modules/order/);
	// dòng order/api thì biên dịch bình thường nhưng vẫn vi phạm R-01 — cmd/** chỉ
	// được import đúng "erp/modules/order".
	orderapi "erp/modules/order/api"
	orderhandler "erp/modules/order/internal/handler"
)

func main() {
	db := sqlx.MustConnect("pgx", "postgres://localhost:5432/erp")
	r := gin.New()

	// SAI: cmd/ tự dựng handler của module order, nên mỗi lần order đổi cách khởi
	// tạo là file này phải sửa theo.
	h := orderhandler.New(db)
	r.POST("/api/v1/orders", h.Create)

	var _ orderapi.OrderReader = h.Service()

	_ = r.Run(":8080")
}
```

## Ví dụ ĐÚNG

```go
// modules/customer/api/customer.go — hợp đồng công khai module customer cam kết giữ ổn định
package api

import "context"

type CustomerDTO struct {
	ID              string
	Name            string
	Email           string
	DiscountPercent int
}

type CustomerReader interface {
	GetByID(ctx context.Context, id string) (*CustomerDTO, error)
}
```

```go
// modules/order/internal/service/order_service.go
package service

import (
	"context"

	// ĐÚNG: chỉ import api/ — module order không biết và không cần biết customer
	// lưu dữ liệu khách hàng dưới cấu trúc nội bộ nào.
	customerapi "erp/modules/customer/api"
	"erp/shared/auth"
	"erp/shared/authz"
)

const PermOrderCreate = "order.create"

type OrderService struct {
	authz     authz.Checker
	customers customerapi.CustomerReader
}

func (s *OrderService) ValidateCustomer(ctx context.Context, actor auth.Actor, customerID string) (*customerapi.CustomerDTO, error) {
	if err := s.authz.Can(ctx, actor, PermOrderCreate); err != nil {
		return nil, err
	}
	return s.customers.GetByID(ctx, customerID)
}
```

```go
// modules/order/module.go — mặt tiền duy nhất mà cmd/** được nhìn thấy
package order

import (
	"github.com/gin-gonic/gin"
	"github.com/jmoiron/sqlx"

	customerapi "erp/modules/customer/api"
	"erp/modules/order/internal/handler"
	"erp/modules/order/internal/repository"
	"erp/modules/order/internal/service"
)

type Deps struct {
	DB        *sqlx.DB
	Customers customerapi.CustomerReader
}

type Module struct {
	handler *handler.OrderHandler
}

// New dựng toàn bộ cây phụ thuộc bên trong module. Mọi kiểu nội bộ (repository,
// service, handler) chỉ xuất hiện ở đây, không lọt ra ngoài chữ ký hàm.
func New(d Deps) *Module {
	repo := repository.NewOrderRepository()
	svc := service.NewOrderService(d.DB, repo, d.Customers)
	return &Module{handler: handler.New(svc)}
}

// Register nhận group /api/v1 do composition root dựng, nên ở đây chỉ khai phần
// đuôi. Tiền tố /api/v1 xuất hiện đúng một lần trong toàn hệ thống — viết lại nó ở
// đây thì path thật thành /api/v1/api/v1/orders (C-API-06).
func (m *Module) Register(r gin.IRouter) {
	g := r.Group("/orders")
	g.POST("", m.handler.Create)
	g.GET("/:id", m.handler.Get)
}
```

```go
// cmd/api/main.go
package main

import (
	"github.com/gin-gonic/gin"
	"github.com/jmoiron/sqlx"

	// ĐÚNG: composition root chỉ biết đúng package gốc của từng module.
	"erp/modules/customer"
	"erp/modules/order"
)

func main() {
	db := sqlx.MustConnect("pgx", "postgres://localhost:5432/erp")
	r := gin.New()
	v1 := r.Group("/api/v1")

	customerModule := customer.New(customer.Deps{DB: db})
	orderModule := order.New(order.Deps{DB: db, Customers: customerModule.Reader()})

	customerModule.Register(v1)
	orderModule.Register(v1)

	_ = r.Run(":8080")
}
```

`customerModule.Reader()` trả về `customerapi.CustomerReader` — kiểu khai trong
`api/`, nên `cmd/` truyền được nó sang module order mà vẫn không chạm vào package con
nào của customer.

## Cách kiểm

```powershell
# 1) File trong modules/<B>/ import package cua module A khac ma khong phai api/
Get-ChildItem -Path modules -Recurse -Filter *.go | ForEach-Object {
    $file = $_.FullName
    $currentModule = ($file -split '\\modules\\')[1] -split '\\' | Select-Object -First 1
    Select-String -Path $file -Pattern 'erp/modules/([a-zA-Z0-9_]+)((?:/[a-zA-Z0-9_]+)*)' -AllMatches | ForEach-Object {
        $lineNo = $_.LineNumber
        foreach ($m in $_.Matches) {
            $imported = $m.Groups[1].Value
            $rest = $m.Groups[2].Value
            if ($imported -eq $currentModule) { continue }
            if ($rest -eq '/api' -or $rest.StartsWith('/api/')) { continue }
            "{0}:{1}: module '{2}' import '{3}' - module khac chi duoc import api/" -f $file, $lineNo, $currentModule, $m.Value
        }
    }
}

# 2) cmd/** chi duoc import dung 'erp/modules/<A>', khong duoc sau hon mot muc
Get-ChildItem -Path cmd -Recurse -Filter *.go | ForEach-Object {
    Select-String -Path $_.FullName -Pattern 'erp/modules/[a-zA-Z0-9_]+/' | ForEach-Object {
        "{0}:{1}: composition root import sau hon module.go -> {2}" -f $_.Path, $_.LineNumber, $_.Line.Trim()
    }
}
```

Lệnh (1) bắt cả hai nhóm cùng lúc: import `modules/<A>/internal/...` (nhóm compiler
đã chặn, nhưng in ra để thấy sớm ngay trên editor thay vì đợi `go build`) và import
package của A nằm ngoài `internal/` mà không phải `api/` — nhóm compiler không chặn.
Import trong chính module của nó không bị báo vì đó là truy cập nội bộ hợp lệ.

Lệnh (2) dựa trên một dấu hiệu duy nhất: trong file thuộc `cmd/**`, mọi chuỗi
`erp/modules/<tên>/` còn dấu `/` phía sau tên module đều là import sâu hơn
`module.go`, tức vi phạm. Chuỗi `erp/modules/order` không có dấu `/` cuối là dòng hợp
lệ duy nhất.
