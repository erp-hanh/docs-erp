# P-TEST — Testing

**Câu hỏi nó trả lời:** Test cái gì, mock cái gì, bao nhiêu là đủ?
**Rules:** —
**Decisions:** —

> Trường link ngược để trống là đúng, không phải thiếu sót: không Rule nào trỏ tới
> P-TEST. Test là thứ chặn *hồi quy* của mọi Rule chứ không phải cách thi hành một Rule
> cụ thể — gán nó vào một Rule bất kỳ chỉ làm chuỗi truy vết kém chính xác đi. Quy
> trình chi tiết (bố cục file, table-driven test, cách viết fake, cách tìm chỗ chưa có
> test) nằm ở skill `unit-test` của dự án; trang này chỉ nói cách *quyết định*.

## Cách suy luận

Test tồn tại để **giữ hành vi khi code đổi**. Một test không thể đỏ khi hành vi sai thì
nó không giữ gì cả, dù nó có làm coverage đẹp lên. Vì vậy câu hỏi trước khi viết một
test luôn là: "nếu tôi cố tình làm hỏng logic này, test nào đỏ?" Không trả lời được thì
đừng viết test đó.

**Ba tầng, ba loại test khác nhau, không thay thế nhau:**

- **Service test — nhiều nhất.** Nghiệp vụ nằm ở service, nên phần lớn giá trị nằm ở
  đây. Repository cắm vào qua interface bằng fake. Riêng ca "actor không đủ quyền" phải
  luôn có một test: kiểm quyền là câu lệnh đầu tiên của mọi method public (R-15), và
  không có gì trong compiler chặn được người ta xóa dòng đó.
- **Repository test — chạy trên PostgreSQL thật qua testcontainers.** Đây là **chỗ duy
  nhất** SQL được kiểm. Bỏ tầng này thì không còn chỗ nào phát hiện SQL sai.
- **Handler test — mỏng.** `httptest` cộng service fake, kiểm đúng ba thứ: status code
  (R-10), hình dạng envelope (R-11), và việc actor được lấy từ `ctx` rồi truyền xuống
  service (R-15). Không kiểm nghiệp vụ ở đây — nghiệp vụ không nằm ở đây.

**Mock cái gì.** Mock thứ bạn *không sở hữu* và *không chạy được trong CI*: SMTP, API
bên thứ ba, đồng hồ hệ thống, bộ sinh UUID. Đừng mock thứ bạn sở hữu và chạy được:
PostgreSQL chạy được trong một container mất vài giây, nên nó không nằm trong danh sách
được mock.

**Vì sao cấm mock SQL.** Một thư viện kiểu `sqlmock` kiểm rằng chuỗi truy vấn khớp với
chuỗi mà *chính người viết test* đã đặt làm kỳ vọng. Khi lập trình viên copy câu SQL từ
code sang test — điều luôn xảy ra — thì test và code cùng sai theo đúng một kiểu, và
màu xanh chỉ chứng minh rằng hai chỗ chép giống nhau. Cụ thể, mock SQL **không** phát
hiện được:

- SQL sai cú pháp, hoặc đúng cú pháp nhưng sai tên cột;
- sai kiểu dữ liệu (`TEXT` so với `UUID`, `NUMERIC` so với `int`);
- **thiếu `company_id = $n` trong `WHERE`** — đúng lỗ hổng mà R-06 sinh ra để chặn,
  và là lỗ hổng khiến công ty A đọc được dữ liệu công ty B;
- **thiếu `deleted_at IS NULL`** — đúng lỗ hổng mà R-18 sinh ra để chặn, bản ghi đã xóa
  mềm lại hiện ra trong danh sách;
- thiếu index nên câu `FOR UPDATE` giữ khóa rộng hơn cần thiết (R-09,
  [P-CONC-concurrency.md](P-CONC-concurrency.md));
- partial unique index không hoạt động như tưởng, nên không tạo lại được bản ghi cùng
  mã sau khi xóa mềm.

Nói cách khác, mock SQL bỏ lọt **đúng loại bug mà R-06 và R-18 sinh ra để chặn**, và
tệ hơn là nó bỏ lọt trong khi vẫn hiện màu xanh — tạo cảm giác an toàn giả. Một
`SELECT` chạy thật trên Postgres bắt được cả sáu loại trên mà không cần ai nghĩ tới
chúng.

**Bao nhiêu là đủ.** Ba mốc, theo thứ tự quan trọng:

1. Mọi method public của service có ít nhất một test.
2. Mọi nhánh sinh ra lỗi nghiệp vụ có một test riêng — mỗi `if` trả về lỗi có mã là một
   quyết định nghiệp vụ, và đó chính là thứ người ta sẽ vô tình đảo ngược khi refactor.
3. Mọi bug đã sửa có một test tái hiện nó, viết **trước** khi sửa.

Coverage là chỉ số phụ để tìm vùng chưa ai đụng tới, không phải mục tiêu. 90% coverage
với toàn assert `err == nil` yếu hơn 60% coverage mà mỗi test đều kiểm giá trị cụ thể.

## Hard check

1. **Mọi method public của service có ít nhất một hàm test.** Với mỗi hàm khớp
   `^func \(s \*\w+Service\) [A-Z]` trong `modules/**`, phải tồn tại ít nhất một
   `func Test...` trong cùng package mà tên chứa tên method đó.
2. **Cấm mock SQL ở mọi nơi trong repo.** Không file `.go` nào được import
   `github.com/DATA-DOG/go-sqlmock` hay bất kỳ package driver giả nào khác; `go.mod`
   không được có chúng trong `require`.
3. **Test của repository chạy trên PostgreSQL thật.** Mọi file `*_repository_test.go`
   phải import `github.com/testcontainers/testcontainers-go` (trực tiếp hoặc qua helper
   dùng chung của repo). Một `*_repository_test.go` không đụng tới container là một
   test không chạm database.
4. **Mỗi method service có kiểm quyền phải có một test cho nhánh bị từ chối.** Với mỗi
   method public không mang tiền tố `Internal`, phải có một test đưa vào một `authz`
   checker từ chối và assert lỗi trả về khác `nil`.
5. **Test của event handler phải gọi handler hai lần với cùng `event_id`** và assert
   hiệu ứng chỉ xảy ra một lần ([P-IDEM-idempotency.md](P-IDEM-idempotency.md)).

```powershell
# 1) Method public cua service chua co test nao nhac ten
$tested = Get-ChildItem -Path modules -Recurse -Filter *_test.go |
    Select-String -Pattern '^func (Test\w+)' | ForEach-Object { $_.Matches[0].Groups[1].Value }
Get-ChildItem -Path modules -Recurse -Filter *_service.go |
    Select-String -Pattern '^func \(s \*\w+Service\) ([A-Z]\w*)' | ForEach-Object {
        $m = $_.Matches[0].Groups[1].Value
        if (-not ($tested | Where-Object { $_ -like "*$m*" })) {
            "{0}:{1}: {2} chua co test nao" -f $_.Path, $_.LineNumber, $m
        }
    }

# 2) Mock SQL o bat ky dau
Get-ChildItem -Path . -Recurse -Include *.go, go.mod |
    Select-String -Pattern 'go-sqlmock|sqlmock\.New' |
    ForEach-Object { "{0}:{1}: mock SQL bi cam -> dung testcontainers" -f $_.Path, $_.LineNumber }

# 3) Repository test khong cham database that
Get-ChildItem -Path modules -Recurse -Filter *_repository_test.go | ForEach-Object {
    $raw = Get-Content -Path $_.FullName -Raw
    if ($raw -notmatch 'testcontainers|testDB\(') {
        "{0}: repository test khong dung PostgreSQL that" -f $_.FullName
    }
}
```

## Ca khó

### 1. Test một service method có transaction

Service tự mở transaction bằng `s.db.BeginTxx(ctx, nil)` và nhận lại `*sqlx.Tx` — một
**struct cụ thể**, không phải interface. Nghĩa là với pattern hiện tại không có chỗ nào
cắm fake vào giữa: **method service có ghi thì phải test trên PostgreSQL thật.**

Đó không phải khiếm khuyết cần vá bằng sqlmock. Đó là cái giá đã trả trước để đổi lấy
việc SQL luôn được kiểm thật, và nó rẻ hơn nhiều so với việc phát hiện thiếu
`company_id` ở production. Ranh giới rút ra: **fake được thứ mình viết ra, không fake
được thứ Postgres làm.** Rollback, unique constraint, `FOR UPDATE`, serialization
failure đều là thứ Postgres làm.

Cách chia việc cho gọn:

- Method **không** mở transaction (đọc, tính toán, kiểm quyền) → fake repository qua
  interface, `s.db` đi xuống như một `DBTX` mà fake bỏ qua. Nhanh, chạy hàng nghìn
  test trong vài giây. Phần lớn nhánh nghiệp vụ nằm ở đây nếu logic được tách ra khỏi
  hàm ghi.
- Method **có** mở transaction → PostgreSQL thật, và chỉ test những gì cần transaction
  mới thấy: dữ liệu sau khi commit, dữ liệu sau khi rollback, bản ghi audit sinh cùng
  transaction (R-17), dòng `outbox` sinh cùng transaction (R-05). Đừng lặp lại ở đây
  mọi nhánh validate đã test ở tầng trên.
- Một container dùng chung cho cả package, mỗi test một transaction rồi rollback ở
  cuối, hoặc `TRUNCATE` giữa các test. Dựng container cho từng test hàm là cách chắc
  chắn nhất để cả bộ test bị bỏ chạy vì chậm.

### 2. Test event handler idempotent

Test một chiều là chưa đủ, và đây là chỗ hầu hết bộ test dừng lại quá sớm. Cần **hai**
test đối xứng:

- Gọi hai lần với **cùng** `event_id` → hiệu ứng đúng một lần. Đây là ca relay chết
  giữa `Publish` và `MarkPublished` viết thành test.
- Gọi hai lần với **hai** `event_id` khác nhau trên cùng aggregate → hiệu ứng hai lần.
  Thiếu test này thì một handler dedupe nhầm theo `order_id` thay vì `event_id` vẫn
  xanh ở test thứ nhất, và ở production nó sẽ nuốt mọi lần giữ kho thứ hai của cùng
  một đơn — một bug im lặng, phát hiện được sau vài tuần khi số tồn không khớp.

```go
package service_test

import (
	"context"
	"testing"

	"erp/shared/auth"
)

// Gọi handler HAI lần với CÙNG event_id: hiệu ứng phải xảy ra đúng một lần.
// Đây là ca relay chết giữa Publish và MarkPublished (ADR-0006) viết thành test.
func TestStockHandler_ApplyOrderApproved_Idempotent(t *testing.T) {
	ctx := context.Background()
	db := testDB(t) // PostgreSQL thật qua testcontainers
	h := newStockHandler(db)
	evt := orderApprovedEvent("evt-1", "order-1", 3)

	if err := h.Handle(ctx, evt); err != nil {
		t.Fatalf("lan 1: %v", err)
	}
	if err := h.Handle(ctx, evt); err != nil {
		t.Fatalf("lan 2: %v", err)
	}

	if got := reservedQty(t, db, "order-1"); got != 3 {
		t.Fatalf("giu kho = %d, muon 3 (event trung da bi tru hai lan)", got)
	}
}

// Nửa còn lại, thường bị bỏ quên: HAI event_id KHÁC nhau trên cùng aggregate phải
// sinh hiệu ứng HAI lần. Thiếu test này thì một handler dedupe nhầm theo order_id
// vẫn xanh ở test trên, và nó sẽ nuốt mọi lần giữ kho thứ hai của cùng một đơn.
func TestStockHandler_ApplyOrderApproved_KhacEventIDThiKhongDedupe(t *testing.T) {
	ctx := context.Background()
	db := testDB(t)
	h := newStockHandler(db)

	if err := h.Handle(ctx, orderApprovedEvent("evt-1", "order-1", 3)); err != nil {
		t.Fatalf("evt-1: %v", err)
	}
	if err := h.Handle(ctx, orderApprovedEvent("evt-2", "order-1", 2)); err != nil {
		t.Fatalf("evt-2: %v", err)
	}

	if got := reservedQty(t, db, "order-1"); got != 5 {
		t.Fatalf("giu kho = %d, muon 5 (dedupe dang bat nham theo order_id)", got)
	}
}

// Method service KHÔNG mở transaction thì fake được bình thường: repository fake cắm
// vào qua interface, s.db đi xuống như một db.DBTX mà fake bỏ qua.
func TestOrderService_GetOrder_ThieuQuyenThiTuChoi(t *testing.T) {
	svc := newOrderService(&fakeOrderRepo{}, denyAllChecker{})

	_, err := svc.GetOrder(context.Background(), auth.Actor{UserID: "u1", CompanyID: "c1"}, "o1")
	if err == nil {
		t.Fatal("muon loi tu choi quyen, nhan nil")
	}
}
```

Cả hai test đầu chạy trên database thật vì dedupe là một ràng buộc `UNIQUE` — thứ
Postgres làm, không fake được.

### 3. "Code này không test nổi"

Câu này gần như luôn là chẩn đoán đúng cho một vấn đề khác. Ba dạng hay gặp và cách sửa
**tối thiểu** — sửa cho test được, không nhân dịp viết lại module:

- **Service tự `new` repository bên trong hàm.** Không cắm fake vào được. Sửa: nhận
  repository qua constructor dưới dạng interface. Đây là thay đổi một dòng, không phải
  refactor kiến trúc.
- **Hàm gọi `time.Now()` giữa logic.** Test không cố định được kết quả nên người ta
  viết assert lỏng, và assert lỏng thì không đỏ khi hành vi sai. Sửa: nhận một
  `clock` qua struct, mặc định là đồng hồ thật.
- **Một method 300 dòng làm bảy việc.** Mỗi test phải dựng cả bảy. Sửa: tách phần
  quyết định thuần túy (tính tiền, kiểm chuyển trạng thái) thành hàm không đụng DB, test
  dày phần đó, rồi để method còn lại chỉ lo trình tự đọc-ghi.

Điểm chung: khó test là *triệu chứng* của phụ thuộc bị chôn cứng, không phải lý do để
bỏ test. Không bao giờ dùng nó làm lý do quay lại mock SQL.
