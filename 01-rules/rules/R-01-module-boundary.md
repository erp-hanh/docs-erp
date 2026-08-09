# R-01 — Module Boundary

Trang này mở rộng entry trong [../RULES.md](../RULES.md). Mệnh đề bắt buộc nằm ở đó,
không lặp lại ở đây.

## Vì sao

Ranh giới `internal/` là thứ duy nhất giữ một modular monolith khỏi trượt dần thành
big ball of mud. Go không có compiler nào ngăn file trong `modules/order/` import
`modules/customer/internal/model` — hai thư mục đó chỉ là hai package bình thường
trong cùng một module Go, `internal/` chỉ chặn được import xuyên **Go module**, không
chặn được import xuyên **package con trong cùng module**. Nói cách khác, cấu trúc
thư mục `internal/` ở đây là một quy ước kiến trúc, không phải rào chắn kỹ thuật —
nó chỉ đứng vững nếu code review và rule này thực sự chặn nó.

Hậu quả khi vi phạm không nằm ở chỗ "code chạy sai" — code vẫn chạy bình thường, và
đó chính là vấn đề. Khi team Customer đổi tên field, tách struct, hay refactor lại
cách `internal/model` biểu diễn dữ liệu, họ có toàn quyền làm vậy vì đó là chi tiết
nội bộ của module họ. Nhưng nếu module Order đã import thẳng vào đó, một refactor
nội bộ vô hại của team Customer bỗng dưng làm vỡ build của team Order — hai team
không hề biết nhau đang phụ thuộc chéo cho tới khi CI đỏ. Càng nhiều chỗ import xuyên
`internal/`, chi phí của mỗi refactor nội bộ càng tăng, cho tới khi không ai dám sửa
gì bên trong module của mình nữa vì không biết ai đang bí mật phụ thuộc vào nó.

`api/` tồn tại chính là để hấp thụ cú sốc đó: nó là hợp đồng mà module Customer chủ
động cam kết giữ ổn định, khác với `internal/` là chi tiết triển khai có thể đổi bất
cứ lúc nào. Khi mọi phụ thuộc chéo module đều đi qua `api/`, một module có thể được
viết lại hoàn toàn bên trong — kể cả tách thành service riêng sau này — mà không
module nào khác phải đổi một dòng.

## Ví dụ SAI

```go
// modules/customer/internal/model/customer.go — chi tiết nội bộ, KHÔNG phải hợp đồng
package model

import "context"

type Customer struct {
	ID    string
	Name  string
	Email string
}

type CustomerRepository interface {
	FindByID(ctx context.Context, id string) (*Customer, error)
}
```

```go
// modules/order/service/order_service.go
package service

import (
	"context"

	// SAI: modules/customer/internal/model không phải hợp đồng công khai — team
	// customer có thể đổi struct này bất cứ lúc nào mà không cảnh báo module order.
	"erp/modules/customer/internal/model"
)

type OrderService struct {
	customerRepo model.CustomerRepository
}

func (s *OrderService) ValidateCustomer(ctx context.Context, customerID string) (*model.Customer, error) {
	return s.customerRepo.FindByID(ctx, customerID)
}
```

## Ví dụ ĐÚNG

```go
// modules/customer/api/customer.go — hợp đồng công khai module customer cam kết giữ ổn định
package api

import "context"

type CustomerDTO struct {
	ID    string
	Name  string
	Email string
}

type CustomerReader interface {
	GetByID(ctx context.Context, id string) (*CustomerDTO, error)
}
```

```go
// modules/order/service/order_service.go
package service

import (
	"context"

	// ĐÚNG: chỉ import api/ — module order không biết và không cần biết customer
	// lưu dữ liệu khách hàng dưới cấu trúc nội bộ nào.
	customerapi "erp/modules/customer/api"
)

type OrderService struct {
	customers customerapi.CustomerReader
}

func (s *OrderService) ValidateCustomer(ctx context.Context, customerID string) (*customerapi.CustomerDTO, error) {
	return s.customers.GetByID(ctx, customerID)
}
```

## Cách kiểm

```powershell
Get-ChildItem -Path modules -Recurse -Filter *.go | ForEach-Object {
    $file = $_.FullName
    $currentModule = ($file -split '\\modules\\')[1] -split '\\' | Select-Object -First 1
    Select-String -Path $file -Pattern 'modules/([a-zA-Z0-9_]+)/internal' -AllMatches | ForEach-Object {
        foreach ($m in $_.Matches) {
            $importedModule = $m.Groups[1].Value
            if ($importedModule -ne $currentModule) {
                "{0}:{1}: import internal cua module '{2}' tu module '{3}'" -f $file, $_.LineNumber, $importedModule, $currentModule
            }
        }
    }
}
```

Dòng nào in ra là một vi phạm: file thuộc module A nhưng import `modules/<B>/internal/...`
với `B != A`. Import `internal/` trong chính module của nó (ví dụ file trong
`modules/customer/` import `modules/customer/internal/...`) không bị báo vì đó là
truy cập nội bộ hợp lệ.
