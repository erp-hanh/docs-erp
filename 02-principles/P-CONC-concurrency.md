# P-CONC — Concurrency

**Câu hỏi nó trả lời:** Chỗ nào có tranh chấp, khóa kiểu nào?
**Rules:** R-09
**Decisions:** —

## Cách suy luận

Tranh chấp chỉ xuất hiện ở một chỗ duy nhất: **hai request cùng đọc, rồi cùng ghi dựa
trên thứ vừa đọc.** Đó là read-modify-write. Nhận ra nó là 80% công việc; phần còn lại
chỉ là chọn công cụ.

Trong một ERP, ba chỗ luôn có và không bao giờ hết: **tồn kho** (trừ đi từ giá trị hiện
tại), **số dư** (cộng vào giá trị hiện tại), **số chứng từ** (lấy số kế tiếp). Cả ba
đều có dạng "đọc giá trị cũ, tính giá trị mới từ nó, ghi lại", và cả ba đều sai âm thầm
khi chạy song song: hai request cùng đọc tồn 10, cùng trừ 8, cùng ghi 2 — bán được 16
món trong khi kho chỉ có 10, và không có lỗi nào được ghi ở đâu cả.

Có một loại tranh chấp thứ hai dễ bỏ sót: giá trị mới **không** phụ thuộc giá trị cũ
(`SET status = 'approved'`) nên dữ liệu cuối vẫn đúng, nhưng **quyết định** thì bị lặp.
Hai người cùng duyệt một phiếu cho ra cùng một trạng thái, và cho ra *hai* bản ghi audit
(R-17) cùng *hai* dòng `outbox` (R-05). Xem ca khó số 1.

**Pessimistic — `SELECT ... FOR UPDATE`.** Khóa trước, người sau chờ. Chọn khi tranh
chấp **cao** và giao dịch **ngắn**: trừ kho cho một SKU đang bán chạy, cấp số chứng từ.
Ưu điểm là không bao giờ phải làm lại việc. Cái giá: người sau chờ thật, nên nếu giao
dịch dài thì hàng đợi dựng lên rất nhanh, và mọi thứ nằm giữa `Begin` và `Commit` đều
kéo dài thời gian giữ khóa ([P-TXN-transaction-boundary.md](P-TXN-transaction-boundary.md)).

**Optimistic — cột `version`.** Đọc kèm `version`, ghi kèm `WHERE version = $n`, rồi
kiểm số dòng ảnh hưởng: bằng 0 nghĩa là có người khác đã ghi trước, việc của mình phải
làm lại hoặc báo cho người dùng. Chọn khi tranh chấp **thấp** và người dùng **có thể
thử lại**: sửa thông tin một đơn hàng trên form. Ưu điểm là không giữ khóa nào cả, nên
một người mở form 10 phút không chặn ai. Cái giá: khi đụng độ thật thì công đã làm bị
bỏ đi, và người dùng phải được báo tử tế chứ không phải nhận một lỗi kỹ thuật.

Cách chọn, viết thành một dòng: **giữ khóa được bao lâu?** Nếu khoảng từ lúc đọc tới
lúc ghi nằm trọn trong một transaction server-side (mili giây) → pessimistic. Nếu
khoảng đó có người dùng ở giữa (giây tới phút) → optimistic bắt buộc, vì giữ khóa
database qua một màn hình đang mở là điều không được phép trong bất kỳ hoàn cảnh nào.

**Đừng khóa cái không cần khóa.** Ba thứ phải nằm ngoài khoảng đang giữ khóa: gọi API
bên ngoài, tính toán nặng không cần dữ liệu vừa khóa, và mọi thao tác chờ I/O khác. Và
khi phải khóa nhiều hàng, **luôn khóa theo cùng một thứ tự** (ví dụ tăng dần theo `id`)
— deadlock hầu hết sinh ra từ hai luồng khóa hai hàng theo hai thứ tự ngược nhau.

**Vì sao R-09 nằm trong trang này.** Câu `SELECT ... FOR UPDATE WHERE company_id = $1
AND product_id = $2` không có index khớp sẽ gây hai chuyện, và dưới mắt người dùng
chúng biểu hiện giống hệt nhau — hai request chẳng liên quan gì tới nhau lại chờ nhau:

- Postgres phải **quét tuần tự** cả bảng để tìm hàng cần khóa, nên thời gian giữ khóa
  dài ra theo kích thước bảng. Cửa sổ tranh chấp rộng ra tương ứng.
- Nếu điều kiện lọc không nằm ở node quét mà nằm **phía trên** node `LockRows` — điển
  hình là join, subquery, hoặc lọc trên kết quả đã sắp xếp — thì các hàng đi qua vẫn
  bị khóa dù cuối cùng không được trả về.

Nói cách khác, với R-09 thì index không chỉ là chuyện hiệu năng: **thiếu index biến một
hàng tranh chấp thành cả bảng tranh chấp.**

Và đừng lẫn với [P-IDEM-idempotency.md](P-IDEM-idempotency.md): khóa hàng không cứu
được một thao tác bị gửi tới hai lần, vì hai lần đó không hề chạy đồng thời.

## Hard check

1. **Mọi câu `UPDATE` lên tồn kho, số dư, hoặc bộ đếm số chứng từ phải thuộc một trong
   ba dạng an toàn:** (a) đứng sau một `SELECT ... FOR UPDATE` trên chính hàng đó trong
   **cùng transaction**; (b) mang `AND version = $n` trong `WHERE` và service kiểm số
   dòng ảnh hưởng; (c) tự cộng dồn ngay trong SQL (`SET qty = qty - $1`). Không thuộc
   dạng nào là vi phạm.
2. **Cấm read-modify-write không khóa.** Trong một method `*_service.go`: một lời gọi
   `repo.Get...` rồi tính toán rồi `repo.Update...` trên **cùng** bản ghi, mà giữa hai
   lời gọi không có `FOR UPDATE` và câu update không có `version = $n`, là vi phạm.
3. **Dạng (c) phải kèm ràng buộc chống giá trị âm.** `SET qty = qty - $1` nguyên tử về
   ghi nhưng không chặn tồn kho âm; phải có `AND qty >= $1` trong `WHERE` **hoặc** một
   `CHECK (qty >= 0)` trên bảng, và service phải kiểm số dòng ảnh hưởng.
4. **Bảng có cột `version` thì mọi câu `UPDATE` lên bảng đó phải tăng `version`.** Sót
   đúng một câu là vô hiệu hóa toàn bộ cơ chế cho mọi câu còn lại, và không có gì báo.
5. **Mọi cột trong `WHERE` của một câu `FOR UPDATE` phải là cột thứ nhất hoặc thứ hai
   của ít nhất một index** (R-09).

```powershell
# 1) Update tren bang tranh chap ma khong co dau hieu khoa nao
$hot = 'inventories|account_balances|document_counters'
Get-ChildItem -Path modules -Recurse -Filter *_repository.go | ForEach-Object {
    $raw = Get-Content -Path $_.FullName -Raw
    foreach ($m in [regex]::Matches($raw, "(?is)UPDATE\s+($hot)\b.*?;")) {
        $sql = $m.Value
        if ($sql -notmatch 'version\s*=\s*\$' -and $sql -notmatch '=\s*\w+\s*[-+]\s*\$') {
            "{0}: UPDATE tren bang tranh chap khong co version lan khong tu cong don" -f $_.FullName
        }
    }
}

# 2) FOR UPDATE co mat nhung khong nam trong transaction cua service
Get-ChildItem -Path modules -Recurse -Filter *_repository.go |
    Select-String -Pattern 'FOR UPDATE' | ForEach-Object {
        "{0}:{1}: kiem tay - method nay phai nhan tx, khong duoc nhan s.db" -f $_.Path, $_.LineNumber
    }

# 3) Bang co cot version nhung co cau UPDATE quen tang no
Get-ChildItem -Path modules -Recurse -Filter *_repository.go | ForEach-Object {
    $raw = Get-Content -Path $_.FullName -Raw
    if ($raw -match 'version\s*=\s*version\s*\+\s*1') {
        foreach ($m in [regex]::Matches($raw, '(?is)UPDATE\s+\w+\s+SET.*?;')) {
            if ($m.Value -notmatch 'version\s*=\s*version\s*\+\s*1') {
                "{0}: mot cau UPDATE quen tang version -> vo hieu hoa optimistic lock" -f $_.FullName
            }
        }
    }
}
```

## Ca khó

### 1. Hai người cùng duyệt một phiếu

"Trạng thái cuối vẫn là `approved`, có sao đâu?" Có, và cái sai nằm ở chỗ không ai nhìn
vào cột `status`: hai bản ghi audit (R-17) nói hai người khác nhau cùng duyệt cùng một
phiếu, và **hai** dòng `outbox` (R-05) nghĩa là khách nhận hai email, kho nhận hai lệnh
giữ hàng.

Quyết: dùng **chính việc chuyển trạng thái làm khóa optimistic**, không cần thêm cột
`version`. Câu update mang luôn trạng thái nguồn vào `WHERE`:

```sql
UPDATE orders
   SET status = 'approved', updated_at = now(), updated_by = $3
 WHERE id = $1 AND company_id = $2 AND status = 'pending' AND deleted_at IS NULL;
```

Số dòng ảnh hưởng bằng 0 nghĩa là người khác đã duyệt trước. Đó là **lỗi nghiệp vụ**
(client sửa được bằng cách tải lại màn hình), không phải lỗi kỹ thuật: có mã, ra tới
client, và log ở mức `Info` chứ không `Error`
([P-ERR-error-handling.md](P-ERR-error-handling.md),
[P-OBS-observability.md](P-OBS-observability.md)).

Điểm mấu chốt về thứ tự: bản ghi audit và dòng `outbox` chỉ được ghi **sau** khi đã có
bằng chứng "chính tôi là người vừa đổi trạng thái". Ghi trước rồi mới update là quay lại
đúng bài toán nhân đôi.

```go
package service

import (
	"context"

	"erp/modules/document/internal/model"
	"erp/shared/auth"
	apperr "erp/shared/errors"
)

const (
	PermDocumentIssue = "document.issue"
	PermOrderApprove  = "order.approve"
)

// Approve dùng chính việc chuyển trạng thái làm khóa optimistic. UpdateStatusIfPending
// chạy câu SQL ở trên và trả về số dòng ảnh hưởng.
func (s *OrderService) Approve(ctx context.Context, actor auth.Actor, orderID string) error {
	if err := s.authz.Can(ctx, actor, PermOrderApprove); err != nil {
		return err
	}

	tx, err := s.db.BeginTxx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	affected, err := s.orderRepo.UpdateStatusIfPending(ctx, tx, actor.CompanyID, orderID, actor.UserID)
	if err != nil {
		return err
	}
	if affected == 0 {
		return apperr.Conflict(apperr.CodeOrderNotPending, "don hang khong con o trang thai cho duyet")
	}

	// Chỉ tới đây mới ghi audit và outbox: chúng nằm sau bằng chứng "chính tôi là
	// người vừa đổi trạng thái", nên không thể nhân đôi.
	if err := s.auditRepo.Record(ctx, tx, s.approveEntry(ctx, actor, orderID)); err != nil {
		return err
	}
	if err := s.outboxRepo.Append(ctx, tx, s.approvedEvent(ctx, actor, orderID)); err != nil {
		return err
	}
	return tx.Commit()
}

// Issue cấp số chứng từ rồi ghi chứng từ trong CÙNG một transaction. Nếu chứng từ
// rollback thì số cũng trả về — đó là điều kiện để dãy số liên tục.
func (s *DocumentService) Issue(ctx context.Context, actor auth.Actor, in IssueInput) (*model.Document, error) {
	if err := s.authz.Can(ctx, actor, PermDocumentIssue); err != nil {
		return nil, err
	}

	tx, err := s.db.BeginTxx(ctx, nil)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()

	// NextNo chạy "UPDATE document_counters SET next_no = next_no + 1 WHERE
	// company_id=$1 AND doc_type=$2 AND period=$3 RETURNING next_no - 1".
	// Một câu UPDATE ... RETURNING đã là read-modify-write nguyên tử và tự lấy khóa
	// hàng: không cần thêm một vòng SELECT ... FOR UPDATE nữa. Chỉ khi phải ĐỌC rồi
	// QUYẾT ĐỊNH rồi mới ghi thứ khác mới cần FOR UPDATE tường minh.
	//
	// Mệnh đề WHERE phải khớp index uq_document_counters(company_id, doc_type,
	// period); không khớp thì Postgres quét tuần tự và giữ khóa lâu hơn cần thiết,
	// biến một hàng tranh chấp thành cả bảng tranh chấp (R-09).
	no, err := s.counterRepo.NextNo(ctx, tx, actor.CompanyID, in.DocType, in.Period)
	if err != nil {
		return nil, err
	}

	doc, err := s.docRepo.Insert(ctx, tx, actor.CompanyID, in, no)
	if err != nil {
		return nil, err
	}

	if err := tx.Commit(); err != nil {
		return nil, err
	}
	return doc, nil
}
```

### 2. Sinh số chứng từ liên tục, không trùng, không lỗ

`SEQUENCE` của Postgres là câu trả lời sai cho bài toán này, dù nó là thứ đầu tiên ai
cũng nghĩ tới. Hai lý do, và lý do thứ nhất mới là lý do giết chết nó:

- **Sequence không rollback.** Đó là tính năng, không phải lỗi — nó cho phép nhiều
  transaction lấy số song song mà không chờ nhau. Nhưng hệ quả là dãy số có lỗ, và một
  dãy số chứng từ kế toán có lỗ thì không giải trình được với cơ quan thuế: "số 1047 đi
  đâu?" là câu hỏi không có câu trả lời tốt.
- **Sequence không phân theo `company_id` và kỳ.** Số chứng từ phải khởi động lại theo
  tháng hoặc năm, và phải độc lập giữa các công ty. Một sequence toàn cục không làm
  được, và tạo một sequence cho mỗi tổ hợp (công ty × loại × kỳ) là con đường tới hàng
  nghìn đối tượng schema mà không ai quản được.

Quyết: bảng `document_counters(company_id, doc_type, period, next_no)`, cấp số bằng
`UPDATE ... RETURNING` trên đúng một hàng, **trong cùng transaction với chứng từ**. Ba
hệ quả phải chấp nhận một cách tỉnh táo:

- Mọi request cùng (công ty, loại, kỳ) bị **tuần tự hóa** tại hàng đó. Đó chính là cái
  giá của yêu cầu "liên tục", không phải một khiếm khuyết cần tối ưu đi. Đổi lại,
  transaction phải cực ngắn — đây là ví dụ điển hình cho câu "đừng để lời gọi mạng nằm
  trong khoảng đang giữ khóa".
- Hàng đó phải được **cấp số cuối cùng** trong transaction, ngay trước khi ghi chứng
  từ, để thời gian giữ khóa ngắn nhất có thể.
- Nếu nghiệp vụ **không** đòi liên tục (số phiếu nội bộ, mã tham chiếu) thì dùng
  sequence và ngủ ngon. Đừng áp cái giá này lên chỗ không cần nó.

### 3. Chọn pessimistic hay optimistic — bảng quyết định

| Tình huống | Xác suất đụng độ | Độ dài giao dịch | Chọn | Vì sao |
|---|---|---|---|---|
| Trừ kho SKU bán chạy | Cao | Mili giây | Pessimistic (`FOR UPDATE`) | Retry liên tục còn tốn hơn chờ; và người dùng không "thử lại" được việc bán hàng |
| Cấp số chứng từ | Cao | Mili giây | Pessimistic (`UPDATE ... RETURNING`) | Yêu cầu liên tục ép phải tuần tự hóa |
| Sửa form đơn hàng, người dùng mở 10 phút | Thấp | Phút | Optimistic (`version`) | Giữ khóa 10 phút là không chấp nhận được, ở bất kỳ hoàn cảnh nào |
| Duyệt phiếu | Thấp | Mili giây | Optimistic qua chính trạng thái | Đã có sẵn cột nguồn để đặt vào `WHERE`, không cần thêm cột `version` |
| Cập nhật hàng loạt theo lô | Cao | Giây | Pessimistic + khóa theo thứ tự `id` tăng dần | Không sắp thứ tự thì hai lô chồng nhau sinh deadlock |

Khi vẫn phân vân: bắt đầu bằng optimistic. Nó không giữ khóa nên hỏng theo cách nhìn
thấy được (số dòng ảnh hưởng bằng 0, có chỗ để xử lý), trong khi pessimistic sai chỗ
hỏng theo cách khó thấy hơn nhiều — hàng đợi dựng lên, latency p99 tăng, và không có
lỗi nào được ghi ở đâu cả.
