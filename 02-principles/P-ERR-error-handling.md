# P-ERR — Error Handling

**Câu hỏi nó trả lời:** Lỗi nào wrap, lỗi nào trả client, lỗi nào chỉ log?
**Rules:** R-03, R-11
**Decisions:** —

## Cách suy luận

Phân loại lỗi bằng đúng một câu hỏi: **ai sửa được nó?**

| Loại | Ai sửa được | Ví dụ | Đi tới client | Mức log |
|---|---|---|---|---|
| Lỗi nghiệp vụ | Client, bằng cách đổi input hoặc đổi trạng thái | "đơn đã duyệt không sửa được", "vượt tồn kho" | Mã lỗi ổn định + thông điệp đọc được | `Info` |
| Lỗi kỹ thuật | Người vận hành | mất kết nối DB, deadlock, đĩa đầy | Mã chung `internal_error` + `request_id` | `Error` |
| Lỗi lập trình | Người viết code, ở lần deploy sau | nil deref, invariant vỡ | `internal_error` | `Error` |

Cột "ai sửa được" quyết định mọi thứ còn lại. Lỗi nghiệp vụ phải mang mã ổn định vì
client cần rẽ nhánh theo mã — dùng chuỗi thông điệp làm khóa rẽ nhánh nghĩa là sửa
chính tả tiếng Việt cũng thành breaking change. Lỗi kỹ thuật thì ngược lại: chi tiết
của nó (tên bảng, tên constraint, câu SQL) là thông tin nội bộ, không được ra tới
client; thứ ra tới client là `request_id` để người dùng đọc cho tổng đài, còn chi tiết
nằm trong log tra được theo chính `request_id` đó (R-17).

**Ai dịch, dịch ở đâu.** Repository trả lỗi kỹ thuật nguyên trạng, cùng lắm bọc thêm
ngữ cảnh bằng `: %w`; nó **không** sinh lỗi nghiệp vụ — đây chính là vế thứ ba của
R-03. Lý do không phải hình thức: cùng một `sql.ErrNoRows` có thể là "đơn hàng không
tồn tại" (404), là "hết hàng để giữ" (409), hoặc là một nhánh hoàn toàn hợp lệ (danh
sách rỗng). Repository chỉ biết "câu truy vấn trả về không dòng nào"; nó không có ngữ
cảnh để chọn. **Service là tầng duy nhất dịch lỗi kỹ thuật thành lỗi nghiệp vụ.**
Handler không dịch gì cả — nó nhận lỗi đã có mã, hoặc lỗi chưa có mã thì coi là
`internal_error`, rồi đẩy qua `shared/response` (R-11).

**Wrap hay không wrap.** Wrap khi thêm được ngữ cảnh mà tầng trên không tự biết: id
đang xử lý, thao tác đang làm. Không wrap khi chỉ lặp lại thứ đã hiển nhiên —
`fmt.Errorf("failed to get order: %w", err)` trong hàm tên `GetOrder` không thêm gì
ngoài một dòng nhiễu, và bốn tầng cùng làm vậy thì được một chuỗi "failed to ... failed
to ... failed to ..." dài mà vẫn không biết id nào hỏng. Luôn dùng `%w` chứ không `%v`:
`%v` cắt đứt chuỗi và `errors.Is`/`errors.As` phía trên mù luôn.

**Nuốt lỗi là một quyết định, và quyết định thì phải viết ra.** `_ = err` không nói
được người viết đã cân nhắc hay chỉ muốn compiler im lặng. Nếu thật sự bỏ qua được thì
điều kiện là: bỏ qua không đổi kết quả nghiệp vụ, **và** có comment nêu lý do ngay tại
chỗ. Hai chỗ hay bị nuốt sai nhất là `defer tx.Rollback()` (đúng, vì rollback sau
commit thành công trả lỗi vô hại) và `MarkPublished` trong relay (sai, vì nuốt nó
nghĩa là event bị gửi lại vô hạn mà không có dòng log nào chỉ ra vì sao).

**`panic` không phải cách trả lỗi.** Trong `main` thì panic đúng: thiếu biến môi
trường bắt buộc, không mở được kết nối DB lúc khởi động — chết sớm tốt hơn chạy sai.
Ngoài `main` thì panic là lỗi lập trình lọt ra; middleware recover bắt lấy, log `Error`
kèm stack, trả `internal_error`. Dùng panic để nhảy qua nhiều tầng cho tiện là biến
mọi lời gọi hàm thành một nhánh điều khiển vô hình.

## Hard check

1. **Cấm `_ = err`** và cấm gán lỗi vào `_` dưới mọi dạng (`_, _ = f()` khi giá trị
   thứ hai là `error`) trong `modules/**` và `shared/**`. Miễn trừ duy nhất:
   `defer tx.Rollback()`.
2. **Cấm `panic(` và `log.Fatal` ngoài `cmd/**`.** Trong `cmd/**` chỉ được panic ở
   giai đoạn khởi động, trước khi server bắt đầu nhận request.
3. **Mọi lỗi đi tới client phải dựng từ bảng mã lỗi trong `shared/errors`.** Cụ thể:
   trong `*_handler.go` cấm `errors.New(` và cấm `fmt.Errorf(` để tạo giá trị đem trả
   về response; response luôn đi qua `shared/response` (R-11).
4. **Trong `*_repository.go`: cấm `errors.New(`; `fmt.Errorf(` chỉ hợp lệ khi chuỗi
   định dạng kết thúc bằng `: %w`** (R-03). Đây là vế "repository không sinh lỗi
   nghiệp vụ" viết thành thứ grep được.
5. **`errors.Is(err, sql.ErrNoRows)` chỉ được xuất hiện trong `*_service.go`.** Nó xuất
   hiện trong `*_handler.go` nghĩa là sentinel của tầng dữ liệu đã rò lên tới HTTP và
   việc dịch lỗi đang xảy ra sai tầng.
6. **Cấm `%v` cho lỗi trong `fmt.Errorf`.** Chuỗi định dạng chứa `: %v` với tham số là
   một `error` phải đổi thành `%w`.

```powershell
# 1) Nuot loi
Get-ChildItem -Path modules, shared -Recurse -Filter *.go |
    Select-String -Pattern '^\s*_\s*=\s*\w+' |
    Where-Object { $_.Line -notmatch 'defer\s+tx\.Rollback' } |
    ForEach-Object { "{0}:{1}: {2}" -f $_.Path, $_.LineNumber, $_.Line.Trim() }

# 2) Repository tu sinh loi nghiep vu (R-03)
Get-ChildItem -Path modules -Recurse -Filter *_repository.go |
    Select-String -Pattern 'errors\.New\(|fmt\.Errorf\(' |
    Where-Object { $_.Line -notmatch ': %w"' } |
    ForEach-Object { "{0}:{1}: repository sinh loi nghiep vu -> de service dich" -f $_.Path, $_.LineNumber }

# 3) Sentinel cua tang du lieu ro len handler
Get-ChildItem -Path modules -Recurse -Filter *_handler.go |
    Select-String -Pattern 'sql\.ErrNoRows' |
    ForEach-Object { "{0}:{1}: sql.ErrNoRows o handler -> dich o service" -f $_.Path, $_.LineNumber }
```

## Ca khó

### 1. `sql.ErrNoRows` dịch thành gì, ở tầng nào

Cùng một sentinel, ba nghĩa khác nhau, và chỉ service phân biệt được:

- `GetByID` cho endpoint `GET /orders/:id` → đơn không tồn tại → 404, mã
  `order_not_found`. Chú ý: với R-06, "không tồn tại" và "tồn tại nhưng thuộc công ty
  khác" cho ra cùng một `ErrNoRows`, và **phải** cho ra cùng một câu trả lời 404 — trả
  403 ở ca thứ hai là rò rỉ thông tin rằng bản ghi đó có tồn tại.
- `SELECT ... FOR UPDATE` trên `inventories` để giữ hàng → không có dòng nào để khóa →
  409, mã `stock_not_available`. Đây là lỗi nghiệp vụ, không phải 404.
- `List` trả về không dòng nào → **không phải lỗi**. Danh sách rỗng là kết quả hợp lệ:
  200 với `data: []` và `meta.total: 0` (R-12). Repository dùng `SelectContext` cho ca
  này nên không sinh `ErrNoRows` ngay từ đầu; nếu code đang biến danh sách rỗng thành
  lỗi thì đó là bug, không phải chuyện dịch lỗi.

Quy tắc rút ra: repository giữ nguyên `sql.ErrNoRows`, service dịch **theo endpoint
đang phục vụ, không theo tên method repository**.

```go
package service

import (
	"context"
	"database/sql"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5/pgconn"

	"erp/modules/order/internal/model"
	"erp/shared/auth"
	apperr "erp/shared/errors"
)

const PermOrderRead = "order.read"

// GetOrder dịch sentinel kỹ thuật thành lỗi nghiệp vụ có mã. Repository trả thẳng
// sql.ErrNoRows lên (R-03 cấm nó tự sinh lỗi nghiệp vụ) vì nó không biết "không có
// dòng nào" ở đây nghĩa là 404 hay là một nhánh hợp lệ.
func (s *OrderService) GetOrder(ctx context.Context, actor auth.Actor, id string) (*model.Order, error) {
	if err := s.authz.Can(ctx, actor, PermOrderRead); err != nil {
		return nil, err
	}

	o, err := s.orderRepo.GetByID(ctx, s.db, actor.CompanyID, id)
	switch {
	case err == nil:
		return o, nil
	case errors.Is(err, sql.ErrNoRows):
		// Lỗi nghiệp vụ: client sửa được (gửi id khác). Có mã ổn định, ra tới client.
		return nil, apperr.NotFound(apperr.CodeOrderNotFound, "don hang khong ton tai")
	default:
		// Lỗi kỹ thuật: client không làm gì được. Bọc thêm ngữ cảnh cho log, KHÔNG
		// gán mã nghiệp vụ — handler sẽ trả internal_error kèm request_id.
		return nil, fmt.Errorf("get order %s: %w", id, err)
	}
}

// translateWrite là ca giao thoa: driver trả lỗi KỸ THUẬT nhưng ngữ nghĩa là NGHIỆP
// VỤ. Chỉ service dịch được, vì chỉ nó biết constraint uq_orders_company_id_code ứng
// với quy tắc "mã đơn không trùng trong một công ty". Lỗi 23505 nào không nhận ra
// thì trả nguyên trạng: đoán bừa còn tệ hơn báo internal_error.
func translateWrite(err error) error {
	var pgErr *pgconn.PgError
	if !errors.As(err, &pgErr) {
		return err
	}
	if pgErr.Code == "23505" && pgErr.ConstraintName == "uq_orders_company_id_code" {
		return apperr.Conflict(apperr.CodeOrderCodeDuplicated, "ma don hang da ton tai")
	}
	return err
}
```

### 2. Lỗi kỹ thuật mà client sửa được — ca giao thoa

`23505 unique_violation` là lỗi do driver trả về, đúng định nghĩa lỗi kỹ thuật, nhưng
người dùng sửa được: đổi mã đơn hàng. Trả `internal_error` ở đây là bắt người dùng gọi
tổng đài để nghe câu "anh đổi mã đi".

Quyết: **service dịch, và dịch theo tên constraint, không theo mã lỗi Postgres.** Một
mã `23505` chỉ nói "có ràng buộc duy nhất bị vi phạm", nó không nói ràng buộc nào —
map thẳng `23505 → "mã đã tồn tại"` sẽ báo sai khi bảng có hai unique index. Tên
constraint là thứ duy nhất phân biệt được, nên nó phải được đặt tên có ý nghĩa ngay
trong migration. Constraint nào chưa có trong bảng dịch thì để lỗi đi tiếp nguyên
trạng thành `internal_error`: đoán bừa cho ra thông điệp sai, và thông điệp sai còn
khó gỡ hơn thông điệp chung chung.

Ba mã đáng dịch trong hệ thống này: `23505` (trùng khóa), `23503` (foreign key —
"bản ghi đang được tham chiếu, không xóa được"), `40001` (serialization failure — không
phải lỗi nghiệp vụ, đây là ca duy nhất nên tự retry rồi mới báo).

### 3. Lỗi validate (422) hay lỗi nghiệp vụ (409)

Hai thứ này hay bị gộp làm một vì đều "do client". Phân biệt bằng: **có cần nhìn vào
database mới biết sai hay không.**

- Sai *hình dạng* — thiếu field bắt buộc, `quantity` là chuỗi, ngày sai định dạng, số
  âm ở chỗ không được âm. Biết được chỉ bằng cách nhìn request. → **422** (R-10), lỗi
  gắn vào từng field để form highlight đúng ô.
- Sai *trạng thái* — mã trùng, đơn đã duyệt, vượt hạn mức, hết tồn kho. Phải đọc DB mới
  biết, và cùng một request có thể hợp lệ lúc 10h rồi không hợp lệ lúc 10h01. →
  **409**, lỗi gắn vào cả thao tác chứ không vào field, kèm mã để client rẽ nhánh.

Ranh giới này quan trọng vì phía frontend xử lý hai loại khác hẳn nhau: 422 thì
highlight ô và giữ nguyên form; 409 thì phải tải lại dữ liệu vì thứ nó đang thấy trên
màn hình đã cũ. Trộn hai loại vào một status code là ép frontend đoán.

Và trong cả ba ca trên, lỗi nghiệp vụ **không** được log ở mức `Error` — nó là hành vi
bình thường của hệ thống, xem [P-OBS-observability.md](P-OBS-observability.md).
