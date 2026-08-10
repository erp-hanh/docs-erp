# P-TXN — Transaction Boundary

**Câu hỏi nó trả lời:** Ai mở transaction, đóng ở đâu, khi nào cần?
**Rules:** R-03, R-05
**Decisions:** —

## Cách suy luận

Transaction là ranh giới của **một quyết định nghiệp vụ**, không phải ranh giới của
một lời gọi database. Câu hỏi đúng không phải "chỗ này có cần transaction không" mà là
"nếu nửa chừng chết thì phần nào được phép tồn tại một mình". Phần nào không được phép
tồn tại một mình thì nằm chung một transaction.

Từ đó suy ra ai sở hữu ranh giới. Repository chỉ biết một bảng — nó không đủ thông tin
để nói bảng của nó có được commit một mình hay không. Handler biết một request HTTP,
nhưng để mở transaction nó phải cầm `*sqlx.DB`, tức phải import `sqlx`, mà R-03 cấm
đúng điều đó. Còn lại đúng một tầng biết trọn quyết định nghiệp vụ: **service**. Vì
vậy service mở và đóng transaction, còn repository nhận `DBTX` qua tham số — interface
mà cả `*sqlx.DB` lẫn `*sqlx.Tx` đều thỏa. Cùng một method repository dùng được ở cả
hai chỗ: trong transaction thì truyền `tx`, ngoài transaction thì truyền `s.db`. Không
có method nào phải viết hai lần.

**Khi nào cần?** Với đường ghi, câu trả lời gần như luôn là "cần", và không phải vì
sùng bái transaction mà vì hai Rule khác đã ép sẵn: R-17 đòi mỗi thao tác ghi lên bảng
nghiệp vụ sinh một bản ghi audit *trong cùng transaction*, R-05 đòi dòng `outbox` nằm
*trong cùng transaction* với dữ liệu. Nghĩa là một endpoint tưởng như chỉ `UPDATE` một
hàng thực ra luôn ghi từ hai tới ba bảng. Không có "ghi một bảng nên khỏi mở
transaction" — thứ đó không tồn tại trong hệ thống này.

Đường đọc thì ngược lại: mặc định **không** mở transaction. Mở transaction để đọc chỉ
đúng khi nhiều câu truy vấn phải nhìn thấy *cùng một ảnh chụp* dữ liệu — ví dụ báo cáo
đối chiếu tổng phát sinh với số dư cuối kỳ, hai con số lệch nhau là báo cáo sai. Lúc
đó dùng transaction read-only với mức cô lập phù hợp, và phải nói rõ trong comment vì
sao. Mở transaction cho một câu `SELECT` đơn lẻ không thêm gì ngoài một vòng round-trip.

**Giữ transaction ngắn.** Mọi thứ nằm giữa `Begin` và `Commit` đều đang giữ khóa và
đang giữ một snapshot mà autovacuum không dọn qua được. Ba thứ phải đẩy ra ngoài trước
khi mở transaction: đọc/parse request, validate thuần túy, và mọi lời gọi mạng. Việc
tính toán nặng mà không cần dữ liệu vừa khóa cũng nên làm trước.

## Hard check

Bốn mệnh đề, đều kiểm được bằng grep trên một diff:

1. **Chuỗi `BeginTxx(`, `Begin(`, `.Commit()`, `.Rollback()` chỉ được xuất hiện trong
   `*_service.go`.** Xuất hiện trong `*_repository.go` hoặc `*_handler.go` là vi phạm.
   Ngoại lệ duy nhất là relay — package ngoài `modules/` — nó mở transaction riêng trên
   bảng `outbox`, không chứa dữ liệu nghiệp vụ nào.
2. **Repository cấm giữ handle DB làm field.** Struct repository không có field kiểu
   `*sqlx.DB` hay `*pgxpool.Pool`; nguồn kết nối đến qua tham số `DBTX` ngay sau `ctx`.
   Một repository giữ được `*sqlx.DB` là một repository có thể tự chạy ngoài transaction
   của service mà không ai thấy.
3. **Một request ghi = một transaction.** Trong một method service, số lời gọi
   `tx.Commit()` phải bằng một. Nhiều hơn một là ranh giới đã bị cắt vụn và phải giải
   trình được bằng ca "chia lô" ở dưới — cắt lô là quyết định có chủ đích, có ghi tiến
   độ, không phải hệ quả của việc quên.
4. **Handler cấm import `pgx`/`sqlx` (R-03), service cấm import `gin`/`net/http` (R-03).**
   Vế thứ nhất là thứ chặn handler mở transaction; vế thứ hai là thứ chặn service kết
   thúc transaction theo nhịp của HTTP.

```powershell
# 1) Ranh gioi transaction ro ri ra khoi service
Get-ChildItem -Path modules -Recurse -Include *_repository.go, *_handler.go |
    Select-String -Pattern 'BeginTxx\(|\.Commit\(\)|\.Rollback\(\)' |
    ForEach-Object { "{0}:{1}: ranh gioi transaction nam ngoai service" -f $_.Path, $_.LineNumber }

# 2) Repository giu handle DB lam field thay vi nhan DBTX qua tham so
Get-ChildItem -Path modules -Recurse -Filter *_repository.go |
    Select-String -Pattern '^\s+\w+\s+\*(sqlx\.DB|pgxpool\.Pool)\s*$' |
    ForEach-Object { "{0}:{1}: repository giu handle DB -> nhan DBTX qua tham so" -f $_.Path, $_.LineNumber }
```

## Ca khó

### 1. Batch import vài nghìn dòng — chỗ "một transaction" gãy

Người mới đọc hard check số 3 sẽ bọc cả 5000 dòng vào một transaction. Nó chạy được
trên máy dev với 50 dòng, rồi hỏng ở production theo ba đường cùng lúc:

- **Giữ khóa lâu.** Transaction chạy ba phút là ba phút giữ khóa trên mọi hàng nó
  chạm vào, và ba phút giữ một snapshot mà autovacuum không dọn qua được. Mọi request
  bình thường đụng cùng bảng xếp hàng phía sau.
- **WAL phình.** Toàn bộ thay đổi phải nằm trong WAL cho tới lúc commit; replica tụt
  lại, và đĩa có thể đầy trước khi commit tới.
- **Một dòng lỗi làm hỏng cả lô.** Dòng 4873 sai định dạng ngày → rollback → 4872 dòng
  đúng biến mất. Người dùng sửa một ô rồi bấm import lại từ đầu, chạy lại ba phút, và
  gặp dòng lỗi tiếp theo.

Quyết: **chia lô, mỗi lô một transaction, ghi tiến độ trong chính transaction của lô
đó.** Kích thước lô là tham số vận hành (khởi đầu 500), không phải hằng số thiêng.
Điểm mấu chốt không phải việc chia lô mà là chỗ đặt tiến độ: tiến độ nằm cùng
transaction với dữ liệu của lô, nên không bao giờ có chuyện dữ liệu đã vào mà job quên
hay job nhớ mà dữ liệu chưa vào. Nhờ đó lần chạy lại bắt đầu đúng từ lô lỗi.

Điều này **không** phá hard check số 3 mà làm rõ nó: đơn vị "một quyết định nghiệp vụ"
ở đây là *một lô*, không phải *một file*. Đổi lại, phải chấp nhận trạng thái nhìn thấy
được ở giữa chừng — import xong nửa chừng là một trạng thái hợp lệ, và UI phải hiển
thị được nó ("đã xong 6/10 lô, lô 7 lỗi tại dòng 4873"). Nếu nghiệp vụ nói "hoặc vào
hết hoặc không vào gì" thì đừng chia lô — hãy validate toàn bộ file *trước*, ngoài mọi
transaction, rồi mới ghi; và nếu file lớn tới mức một transaction không kham nổi thì
đó là lúc dựng bảng staging, không phải lúc kéo dài transaction.

```go
package service

import (
	"context"
	"fmt"

	"github.com/jmoiron/sqlx"

	"erp/modules/product/internal/model"
	"erp/modules/product/internal/repository"
	"erp/shared/auth"
	"erp/shared/authz"
)

const (
	PermProductImport = "product.import"
	importChunkSize   = 500
)

type ImportService struct {
	db          *sqlx.DB
	authz       authz.Checker
	productRepo repository.ProductRepository
	jobRepo     repository.ImportJobRepository
}

// ImportProducts cắt lô có chủ đích: mỗi lô là MỘT transaction, và tiến độ được ghi
// trong chính transaction đó. Lô thứ 7 hỏng thì 6 lô đầu đã commit và job nhớ
// doneChunks = 6, nên lần chạy lại bắt đầu từ lô 7 chứ không làm lại từ đầu.
func (s *ImportService) ImportProducts(ctx context.Context, actor auth.Actor, jobID string, rows []model.Product) error {
	if err := s.authz.Can(ctx, actor, PermProductImport); err != nil {
		return err
	}

	doneChunks, err := s.jobRepo.DoneChunks(ctx, s.db, actor.CompanyID, jobID)
	if err != nil {
		return err
	}

	for start := doneChunks * importChunkSize; start < len(rows); start += importChunkSize {
		end := start + importChunkSize
		if end > len(rows) {
			end = len(rows)
		}
		idx := start / importChunkSize
		if err := s.importChunk(ctx, actor, jobID, idx, rows[start:end]); err != nil {
			// Dừng ngay, không "bỏ qua lô lỗi rồi chạy tiếp": chạy tiếp nghĩa là
			// doneChunks không còn là một mốc liên tục và lần chạy lại không biết
			// bắt đầu từ đâu.
			return fmt.Errorf("import chunk %d: %w", idx, err)
		}
	}
	return nil
}

// importChunk là một ranh giới transaction trọn vẹn: dữ liệu của lô và tiến độ của
// lô cùng commit hoặc cùng rollback.
func (s *ImportService) importChunk(ctx context.Context, actor auth.Actor, jobID string, idx int, chunk []model.Product) error {
	tx, err := s.db.BeginTxx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	if err := s.productRepo.InsertMany(ctx, tx, actor.CompanyID, chunk); err != nil {
		return err
	}
	if err := s.jobRepo.MarkChunkDone(ctx, tx, actor.CompanyID, jobID, idx); err != nil {
		return err
	}
	return tx.Commit()
}
```

Lưu ý một chi tiết dễ bỏ sót: `DoneChunks` nhận `s.db`, còn `InsertMany` và
`MarkChunkDone` nhận `tx`. Đó chính là lý do repository nhận `DBTX` qua tham số thay vì
giữ handle riêng — cùng một repository, hai ngữ cảnh, không phải viết hai method.

### 2. Thao tác gọi ra ngoài hệ thống — vì sao outbox tồn tại

"Tạo đơn xong thì gửi email cho khách." Cám dỗ là đặt lời gọi SMTP ngay trước
`tx.Commit()` cho chắc chắn. Nó sai theo cả hai chiều và không có chiều nào cứu được:

- Gửi mail **trong** transaction: SMTP treo 30 giây thì transaction giữ khóa 30 giây.
  Tệ hơn, nếu `Commit()` sau đó thất bại thì email đã ra khỏi tiến trình rồi — không
  gọi về được. Khách nhận thư báo về một đơn hàng chưa từng tồn tại.
- Gửi mail **sau** `Commit()`: đúng lúc hơn, nhưng giữa hai dòng lệnh đó có một khoảng
  thời gian mà đơn đã nằm trong DB còn email thì chưa gửi. Process chết đúng lúc đó —
  pod bị kill, panic — thì email mất vĩnh viễn *và không ai biết để gửi bù*, vì bảng
  `orders` không hề ghi lại rằng có việc đang chờ làm.

Quyết: **mọi lời gọi ra ngoài hệ thống nằm ngoài transaction, và cách duy nhất được
phép để lên lịch cho nó là ghi một dòng `outbox` trong transaction** (R-05). Bảng
`outbox` chỉ là một bảng khác trong cùng transaction, nên "có việc cần gửi" trở thành
một sự thật được commit cùng dữ liệu. Relay — package ngoài `modules/` — đọc bảng đó
và thực sự gọi ra ngoài, sau khi transaction đã đóng từ lâu. Đó là toàn bộ lý do outbox
tồn tại: nó biến "ghi DB + gọi ra ngoài" từ hai hệ thống không đồng bộ được thành một
transaction Postgres duy nhất cộng một hàng đợi bền vững.

Cái giá: relay không biết chắc lần gửi trước có tới nơi hay không nên nó gửi lại — đó
là at-least-once, và vì vậy consumer phải idempotent theo `event_id`
([P-IDEM-idempotency.md](P-IDEM-idempotency.md)).

### 3. Nghiệp vụ đòi hai module cùng thành công

"Duyệt đơn thì phải giữ kho; không giữ được kho thì không được duyệt." Đây là đòi hỏi
atomic qua hai module. Không có transaction phân tán ở đây, và cũng không nên có.

Ba đường đi, chọn theo *nghiệp vụ*, không theo cái nào dễ code hơn:

- **Inventory có tên trong `allowed_deps` của Order** → gọi đồng bộ được. Nhưng chú ý:
  gọi service của module khác nghĩa là module đó tự mở transaction của nó, nên bạn có
  **hai** transaction chứ không phải một, và "atomic" là ảo tưởng. Muốn thật sự atomic
  thì lời gọi phải nhận chính `DBTX` đang mở — và ở đây bộ Rule hiện tại chưa có đường
  đi hợp lệ nào: R-01 nói module khác chỉ được import `modules/<A>/api/`, còn ngoại lệ
  của R-15 nói method `Internal*` cấm xuất hiện trong bất kỳ interface nào thuộc
  `api/`. Hai vế đó cộng lại thì một lời gọi liên module chia sẻ `DBTX` không có chỗ
  đứng. **Gặp ca này thì dừng lại và hỏi người** theo `00-START-HERE.md`, đừng tự chọn
  bên — cần một ADR mở đường tường minh trước khi viết dòng code đầu tiên.
- **Không có tên trong `allowed_deps`** → đây không còn là chuyện chọn transaction hay
  event. Nghiệp vụ đang đòi một ràng buộc atomic mà ranh giới module hiện tại không đỡ
  được. Sửa bằng ADR đổi ranh giới, **không** sửa bằng cách "tạm dùng event cho xong"
  rồi tự nhủ sẽ nhất quán sau — vì sẽ có lúc không nhất quán và không ai xử lý.
- **Nghiệp vụ thật ra chấp nhận trễ** ("duyệt trước, thiếu hàng thì mua bổ sung") →
  event, và bài toán biến mất. Cách phân biệt nằm ở
  [P-EVT-events.md](P-EVT-events.md): hỏi người dùng "nếu việc kia hỏng, đơn này còn
  được coi là đã duyệt không?".
