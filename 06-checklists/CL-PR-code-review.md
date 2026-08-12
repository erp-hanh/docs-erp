# CL-PR — Review PR

**Dùng khi nào:** mọi PR, ở cả ba repo code. Đây là bộ tổng hợp — nó phủ những Rule bị vi
phạm nhiều nhất và những thứ ba checklist chuyên biệt không có chỗ nào để đặt. Nếu PR
thêm module, đổi schema, hoặc thêm endpoint thì chạy thêm
[CL-NEWMOD-new-module.md](CL-NEWMOD-new-module.md),
[CL-SCHEMA-schema-change.md](CL-SCHEMA-schema-change.md),
[CL-API-new-endpoint.md](CL-API-new-endpoint.md) — chúng bổ sung, không thay thế file này.

**Dùng thế nào:** reviewer đi từ trên xuống trên diff, không trên toàn repo. Mỗi dòng kết
thúc bằng một trường `Verifies` trong ngoặc, trỏ ngược về Rule hoặc Convention cụ thể —
báo một vi phạm chỉ cần nêu ID đó, tác giả PR tra ngược được toàn chuỗi ở
[../01-rules/RULES.md](../01-rules/RULES.md).

**Đánh dấu một dòng nghĩa là đã kiểm thật, không phải đã đọc qua.** Reviewer tick hết
trong ba mươi giây là reviewer đang ký tên vào một thứ mình chưa nhìn.

---

## Ranh giới module

- [ ] CL-PR-01 — Không file nào ngoài `modules/<A>/` import `modules/<A>/internal`; module khác chỉ chạm tới `modules/<A>/api/` (Verifies: R-01, C-GO-01)
- [ ] CL-PR-02 — Không dòng import nào trong `cmd/**` đi sâu hơn `erp/modules/<A>`, và không dòng import nào trong `shared/` chứa `/modules/` (Verifies: R-01, R-04, C-GO-01)
- [ ] CL-PR-03 — `module.yaml` đã cập nhật nếu PR thêm bảng, bỏ bảng, hoặc thêm phụ thuộc đồng bộ; quan hệ hai chiều đã được kiểm bằng cách mở `module.yaml` của module đối diện (Verifies: R-02, R-04, C-GO-05)

## Tầng và transaction

- [ ] CL-PR-04 — File mới dùng đúng hậu tố `_service.go`, `_repository.go`, `_handler.go`; hậu tố sai làm mù toàn bộ bộ kiểm và phải sửa trước khi merge (Verifies: R-03, C-GO-02)
- [ ] CL-PR-05 — Handler không import `pgx`/`sqlx`; service không import `gin`/`net/http`; repository không import package `service` và không tạo lỗi nghiệp vụ bằng `errors.New(` hay `fmt.Errorf(` thiếu `: %w` (Verifies: R-03, C-GO-04)
- [ ] CL-PR-06 — Chỉ `*_service.go` chứa `BeginTxx`, `Commit`, `Rollback`; không file `*_repository.go` hay `*_handler.go` nào chứa ba lời gọi đó (Verifies: R-03, C-GO-03)
- [ ] CL-PR-07 — Struct repository không có field kiểu `*sqlx.DB` hay `*pgxpool.Pool`; mọi method repository nhận `db DBTX` làm tham số thứ hai thay vì moi handle ra khỏi `ctx` (Verifies: R-03, C-GO-03)
- [ ] CL-PR-08 — Không dòng nào trong `modules/**` khớp `.Publish(`; event đi ra bằng `outboxRepo.Append(ctx, tx, ...)` gọi từ service, trong cùng transaction với dữ liệu nghiệp vụ (Verifies: R-05, C-DB-07)
- [ ] CL-PR-09 — Method service có thao tác ghi lên bảng nghiệp vụ hoặc bảng trong `reference_tables` gọi `auditRepo.Record(ctx, tx, ...)` trong chính transaction đang mở, không sau `Commit` (Verifies: R-17, C-GO-03)

## Quyền và dữ liệu nhạy cảm

- [ ] CL-PR-10 — Mọi method public của service nhận `actor auth.Actor` làm tham số thứ hai và có lời gọi kiểm quyền làm câu lệnh đầu tiên; không có dòng nào — kể cả một dòng gán biến — đứng trước nó (Verifies: R-15, C-GO-06)
- [ ] CL-PR-11 — Chuỗi `auth.FromContext(` chỉ xuất hiện trong `*_handler.go`; không file nào ngoài `shared/middleware/auth` đọc header `Authorization` hoặc gọi `jwt.Parse` (Verifies: R-14, R-15, C-GO-06)
- [ ] CL-PR-12 — Field nhạy cảm (password hash, token, secret, số CCCD) gắn tag `json:"-"`; lời gọi logger chỉ nhận cặp key-value nguyên thủy, không nhận con trỏ hay struct model (Verifies: R-16, C-GO-02)
- [ ] CL-PR-13 — Thông điệp lỗi ra client không chứa tên bảng, tên constraint, câu SQL hay tên file; những thứ đó chỉ đi vào log tra được theo `request_id` (Verifies: R-16, C-API-05)

## Frontend

- [ ] CL-PR-14 — File `.ts`/`.tsx` trong diff không đưa kết quả tính tiền, thuế hay tồn kho vào body của request `POST`/`PUT`; hiển thị con số tạm tính lên màn hình thì được (Verifies: R-19, C-TS-05)
- [ ] CL-PR-15 — Không component nào hardcode bảng chuyển trạng thái hợp lệ để quyết định cho phép hành động; frontend chỉ dựa vào field do API trả về (Verifies: R-19, C-TS-05)
- [ ] CL-PR-16 — Không có quy tắc nghiệp vụ nào chỉ tồn tại ở frontend: mỗi validate ở frontend có bản backend tương ứng, và ẩn nút theo quyền không thay thế kiểm quyền ở service (Verifies: R-15, C-TS-06)

## Truy vết, lỗi, test

- [ ] CL-PR-17 — Mọi method service và repository nhận `ctx context.Context` làm tham số đầu tiên; không có `context.Background()` hay `context.TODO()` trong `modules/**` (Verifies: R-17, C-GO-02)
- [ ] CL-PR-18 — Không có `_ = err`, không có `if err != nil {}` rỗng, không có lời gọi trả lỗi mà giá trị lỗi bị bỏ; lỗi kỹ thuật bọc bằng `: %w`, lỗi nghiệp vụ dịch ở service theo tên constraint (Verifies: R-11, C-GO-04)
- [ ] CL-PR-19 — Diff không sửa nội dung file migration đã merge; schema chỉ đổi qua file mới trong `migrations/` có đủ cặp `up`/`down` (Verifies: R-07, C-DB-06)
- [ ] CL-PR-20 — Mỗi method public mới và mỗi nhánh nghiệp vụ mới có ít nhất một test đi kèm trong cùng PR (Verifies: —)
- [ ] CL-PR-21 — Tài liệu module (`README.md`, `Database.md`, `Workflow.md`, `Permission.md`, `Events.md`) đã cập nhật theo thay đổi của PR; mỗi method public mới có một dòng trong `Permission.md` (Verifies: R-15, C-GO-05)

---

## Rule nào phải phá, và vì sao

Mục này **không phải checkbox**. Nó là chỗ tác giả PR khai báo tường minh nếu buộc phải
vi phạm một Rule. Điền bảng dưới đây trong mô tả PR; để trống nếu PR không phá gì.

| ID rule bị phá | Vi phạm ở đâu | Vì sao không có đường khác | Việc phải làm sau |
|---|---|---|---|
| `<R-xx>` | `<file:dòng>` | `<lý do cụ thể, kiểm chứng được>` | `<ADR cần viết / issue cần mở / hạn dọn>` |

**Reviewer quyết định**, không phải tác giả. Ba câu trả lời hợp lệ: chấp nhận và ghi lại;
từ chối và yêu cầu làm đúng; hoặc — nếu vi phạm là dấu hiệu Rule đang sai chứ không phải
code đang sai — dừng PR lại và mở một ADR.

**Vì sao mục này tồn tại:** không có nó, người ta phá rule **âm thầm** thay vì khai báo.
Áp lực deadline không biến mất vì có một danh sách cấm; thứ biến mất là dấu vết. Một vi
phạm được khai ra thì còn tranh luận được, còn đặt hạn dọn được, và người sau đọc lịch sử
PR sẽ biết vì sao đoạn code đó trông như vậy. Một vi phạm không khai thì sáu tháng sau
thành tiền lệ, và người thứ ba sẽ trích dẫn nó làm lý do để phá tiếp.

Hai ca **không** được xử bằng mục này, mà phải dừng lại hỏi người:

- **Hai Rule mâu thuẫn nhau.** Đây không phải ca "phá một rule để cứu một rule" — nó là
  dấu hiệu tầng Rule có lỗi, và tự chọn bên là tạo tiền lệ sai cho mọi lần sau.
- **Hai module phải cùng commit nguyên tử.** Đó là ca cần một ADR mở đường, không phải
  chỗ lách bằng một method mang tiền tố `Internal`.
