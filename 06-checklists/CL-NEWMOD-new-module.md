# CL-NEWMOD — Thêm module mới

**Dùng khi nào:** PR tạo một thư mục mới dưới `modules/`. Cũng dùng khi tách một module
đang có thành hai, vì phần việc là như nhau — một ranh giới mới xuất hiện và phải khai
báo được.

**Dùng thế nào:** đi từ trên xuống, đánh dấu từng dòng. Mỗi dòng kết thúc bằng một trường
`Verifies` trong ngoặc, trỏ ngược về Rule hoặc Convention cụ thể — mở ID đó ra đọc là
biết chính xác thứ đang bị kiểm và vì sao nó tồn tại. Rule nằm ở
[../01-rules/RULES.md](../01-rules/RULES.md), Convention nằm ở
[../04-conventions/C-GO-backend.md](../04-conventions/C-GO-backend.md) và ba file cùng
thư mục.

**Đánh dấu một dòng nghĩa là đã kiểm thật, không phải đã đọc qua.** Một checklist tick
hết mà không ai mở file ra nhìn thì tệ hơn không có checklist: nó tạo bằng chứng sai rằng
việc đã được kiểm.

---

- [ ] CL-NEWMOD-01 — `modules/<A>/module.yaml` tồn tại và có đủ bốn trường `name`, `tables`, `allowed_deps`, `internal_methods`; `name` khớp đúng tên thư mục dưới `modules/` (Verifies: R-02, R-05, C-GO-05)
- [ ] CL-NEWMOD-02 — Cây thư mục module có đúng `api/`, `internal/handler/`, `internal/service/`, `internal/repository/`, `internal/model/`, `module.go`, `module.yaml`; không có package nào khác ở cấp gốc module (Verifies: R-01, C-GO-01)
- [ ] CL-NEWMOD-03 — Grep toàn repo: không file nào nằm ngoài `modules/<A>/` có dòng import chứa `modules/<A>/internal` (Verifies: R-01)
- [ ] CL-NEWMOD-04 — Mọi dòng import chứa `modules/` trong `cmd/**` dừng ở đúng `erp/modules/<A>`, không có segment nào đứng sau tên module (Verifies: R-01, C-GO-01)
- [ ] CL-NEWMOD-05 — Không file `*_handler.go` nào import `pgx` hoặc `sqlx`; không file `*_service.go` nào import `gin` hoặc `net/http`; không file `*_repository.go` nào import package `service` (Verifies: R-03, C-GO-01)
- [ ] CL-NEWMOD-06 — Với mỗi tên trong `allowed_deps` của A, mở `module.yaml` của module đó và xác nhận A **không** có tên trong `allowed_deps` của nó (Verifies: R-04, C-GO-05)
- [ ] CL-NEWMOD-07 — Không file nào dưới `shared/` có dòng import chứa `/modules/` sau khi thêm module này (Verifies: R-04, C-GO-01)
- [ ] CL-NEWMOD-08 — Thư mục docs của module có đủ năm file `README.md`, `Database.md`, `Workflow.md`, `Permission.md`, `Events.md`, và danh sách bảng trong `Database.md` khớp từng dòng với `tables` của `module.yaml` (Verifies: R-02, C-GO-05)
- [ ] CL-NEWMOD-09 — Mỗi bảng mới đã được xếp vào đúng một trong bốn nhóm bảng và mang đủ bộ cột của nhóm đó; bảng nghiệp vụ có `company_id`, ba cột thời gian và hai cột audit (Verifies: R-06, R-08, R-17, C-DB-03)
- [ ] CL-NEWMOD-10 — Mọi khóa ngoại khác `company_id` trong migration của module là cột dẫn đầu của một index, hoặc cột thứ hai của index composite mở đầu bằng `company_id`, khai trong cùng file migration (Verifies: R-09, C-DB-05)
- [ ] CL-NEWMOD-11 — Mọi câu SQL trong `modules/<A>/**/repository` chỉ nêu tên bảng có trong `tables` của `module.yaml`, hoặc tên bảng thuộc `system_tables`/`reference_tables`; không có `JOIN` sang bảng của module khác (Verifies: R-02, C-GO-05)
- [ ] CL-NEWMOD-12 — Mọi method public trong `*_service.go` nhận `actor auth.Actor` làm tham số thứ hai và có lời gọi kiểm quyền làm câu lệnh đầu tiên; method được miễn mang tiền tố `Internal` và có tên trong `internal_methods` (Verifies: R-15, C-GO-06)
- [ ] CL-NEWMOD-13 — Không dòng nào trong `modules/<A>/**` khớp `.Publish(`; event đi ra bằng `outboxRepo.Append(ctx, tx, ...)` gọi từ service, trong cùng transaction với dữ liệu nghiệp vụ (Verifies: R-05, C-DB-07)
- [ ] CL-NEWMOD-14 — Route của module đăng ký qua group `/api/v1` ở composition root, và mọi đường ra của handler đi qua `shared/response` (Verifies: R-11, R-13, C-API-01)
- [ ] CL-NEWMOD-15 — Mỗi method public của service có ít nhất một test gọi thẳng nó, truyền `auth.Actor` qua tham số chứ không dựng `ctx` giả (Verifies: R-15, C-GO-06)

---

## Ba thứ hay bị bỏ sót nhất ở PR module mới

1. **`module.yaml` viết đủ trường nhưng `tables` thiếu một bảng.** Bộ kiểm không báo gì —
   nó chỉ im lặng coi bảng đó là bảng của module khác, và mọi câu SQL chạm vào nó thành
   vi phạm R-02 không ai thấy. Đối chiếu `tables` với danh sách `CREATE TABLE` trong
   migration của PR, từng dòng một.
2. **`allowed_deps` thêm một tên vì build đỏ.** Thêm một module vào đó là một quyết định
   kiến trúc, không phải thao tác dọn dẹp. Câu hỏi phải trả lời trước:
   [../02-principles/P-EVT-events.md](../02-principles/P-EVT-events.md) — *nếu việc kia
   hỏng, việc này còn được coi là đã xong không?*
3. **Đặt tên file sai hậu tố.** `order_svc.go` thay vì `order_service.go` không làm code
   sai, nó làm mọi lệnh quét không nhìn thấy file đó. Kết quả tệ hơn một vi phạm bị bắt:
   một vi phạm không bị bắt, trên một file mà CI khẳng định là sạch.
