# 19 Architecture Rules

Rule là thứ **bắt buộc** và **kiểm được**: mỗi mệnh đề dưới đây trả lời được Có/Không
khi nhìn một file hoặc một diff, không cần biết ngữ cảnh nghiệp vụ.

Thứ không kiểm được bằng diff thì không nằm ở đây mà nằm ở `02-principles/`.

Khi hai Rule mâu thuẫn nhau: dừng lại, hỏi người. Không tự chọn bên.

---

## Nhóm A — Module Boundary

### R-01 — Module Boundary

**Mệnh đề bắt buộc:** Code trong `modules/<A>/internal/` chỉ được import bởi chính module A. Module khác chỉ được import `modules/<A>/api/` (interface + DTO).
**Dấu hiệu vi phạm:** Trong file thuộc `modules/B/`, có dòng import chứa `modules/A/internal`.
**Cách sửa:** Đưa thứ B cần lên `modules/A/api/` dưới dạng interface hoặc DTO, rồi import qua đó.
**Ngoại lệ:** Không có ngoại lệ.
**Principles:** —
**Decisions:** ADR-0001

Chi tiết và ví dụ code: [rules/R-01-module-boundary.md](rules/R-01-module-boundary.md)

### R-02 — No Cross-Module DB Access

**Mệnh đề bắt buộc:** Repository của module A chỉ được query bảng nằm trong danh sách `tables` khai báo ở `module.yaml` của A. Cấm JOIN sang bảng thuộc module khác.
**Dấu hiệu vi phạm:** Chuỗi SQL trong `modules/A/**/repository` có tên bảng không nằm trong `tables` của `modules/A/module.yaml`.
**Cách sửa:** Gọi service của module sở hữu bảng đó qua `api/` của nó. Nếu cần dữ liệu để lọc hoặc hiển thị, nhận qua tham số hoặc qua event.
**Ngoại lệ:** Bảng trong `system_tables` (xem `04-conventions/C-DB-database.md`) được đọc bởi mọi module.
**Principles:** —
**Decisions:** ADR-0001

### R-03 — Layered Structure

**Mệnh đề bắt buộc:** Handler cấm import `pgx` hoặc `sqlx`. Service cấm import `gin` hoặc `net/http`. Repository cấm chứa `if` quyết định nghiệp vụ.
**Dấu hiệu vi phạm:** `import "github.com/jackc/pgx/v5"` trong file `*_handler.go`; `import "github.com/gin-gonic/gin"` trong file `*_service.go`.
**Cách sửa:** Chuyển truy cập dữ liệu xuống repository, chuyển thứ phụ thuộc HTTP lên handler.
**Ngoại lệ:** Không có ngoại lệ.
**Principles:** P-TXN, P-ERR
**Decisions:** ADR-0001

### R-04 — Dependency Direction

**Mệnh đề bắt buộc:** `shared/` cấm import bất kỳ package nào dưới `modules/`. Import graph giữa các module không được có chu trình.
**Dấu hiệu vi phạm:** Dòng import chứa `/modules/` trong file thuộc `shared/`.
**Cách sửa:** Đưa thứ dùng chung xuống `shared/`, hoặc đảo quan hệ bằng interface do `shared/` định nghĩa và module implement.
**Ngoại lệ:** Không có ngoại lệ.
**Principles:** —
**Decisions:** ADR-0001

### R-05 — Events for Decoupling

**Mệnh đề bắt buộc:** Gồm bốn mệnh đề, tất cả đều bắt buộc:

1. Service của A chỉ gọi đồng bộ sang module có tên trong `allowed_deps` của `module.yaml` thuộc A; ngoài danh sách phải đi qua event.
2. Chỉ service được ghi outbox. Handler và repository cấm.
3. Service ghi event vào bảng `outbox` **trong cùng transaction** với dữ liệu nghiệp vụ.
4. Service cấm gọi event bus trực tiếp bên trong transaction, kể cả qua `defer`. Publish ra bus xảy ra **sau commit**, do relay riêng đọc `outbox`.

**Dấu hiệu vi phạm:** Lời gọi `bus.Publish(` bên trong khối có `tx`; `defer bus.Publish(`; import module không có trong `allowed_deps`.
**Cách sửa:** Thay lời gọi bus bằng `outboxRepo.Append(ctx, tx, event)`. Để relay lo việc publish.
**Ngoại lệ:** Không có ngoại lệ.
**Principles:** P-EVT, P-IDEM, P-TXN
**Decisions:** ADR-0006

> Relay là **at-least-once**. Vì vậy `P-IDEM` không phải tùy chọn mà là điều kiện để
> ADR-0006 đứng vững: mọi event handler phải idempotent theo `event_id`.

Chi tiết và ví dụ code: [rules/R-05-events-for-decoupling.md](rules/R-05-events-for-decoupling.md)

## Nhóm B — Database

### R-06 — Tenant Column Everywhere

**Mệnh đề bắt buộc:** Mọi bảng nghiệp vụ có `company_id UUID NOT NULL`; mọi query trong repository có `company_id = $n` trong mệnh đề WHERE. Bảng hệ thống được miễn phải liệt kê tường minh trong `04-conventions/C-DB-database.md`.
**Dấu hiệu vi phạm:** Migration có `CREATE TABLE <tên>` nhưng không có dòng `company_id UUID NOT NULL`, và `<tên>` không có trong `system_tables`. File `*_repository.go` có câu SQL `SELECT`/`UPDATE`/`DELETE` trên bảng nghiệp vụ nhưng không chứa chuỗi `company_id = $` trong mệnh đề `WHERE`.
**Cách sửa:** Thêm cột `company_id UUID NOT NULL REFERENCES companies(id)` vào migration; bổ sung điều kiện `company_id = $n` vào `WHERE` của câu SQL đang thiếu trong repository.
**Ngoại lệ:** Bảng trong `system_tables`.
**Principles:** —
**Decisions:** ADR-0003

> **"Bảng nghiệp vụ" nghĩa là gì:** mọi bảng **trừ** những bảng nằm trong danh sách
> `system_tables` khai báo tường minh ở `04-conventions/C-DB-database.md`.
> Khởi đầu `system_tables` gồm `schema_migrations` và `companies` — hai bảng này
> được miễn `company_id`, `deleted_at` và các cột audit của R-17.
> Bảng `outbox` **không** thuộc `system_tables`: nó có `company_id`, nhưng được miễn
> `deleted_at` vì event hết hạn lưu thì xóa cứng.

Chi tiết và ví dụ code: [rules/R-06-tenant-column.md](rules/R-06-tenant-column.md)

### R-07 — Migration Only

**Mệnh đề bắt buộc:** Schema chỉ đổi qua file trong `migrations/`, đánh số tăng dần, có cả `up` và `down`. Cấm sửa migration đã merge — sai thì viết migration mới.
**Dấu hiệu vi phạm:** Trong diff, một file đã tồn tại trong `migrations/` bị sửa nội dung (trạng thái `M` — modified) thay vì chỉ có file mới ở trạng thái thêm (`A` — added). File migration mới chỉ có phần `up`, thiếu phần `down` tương ứng. Có `CREATE TABLE`, `ALTER TABLE`, hoặc `DROP TABLE` trong file nằm ngoài thư mục `migrations/`.
**Cách sửa:** Revert file migration cũ về đúng nội dung đã merge; tạo file migration mới với số thứ tự kế tiếp chứa đúng thay đổi mong muốn, có đủ phần `up` và `down`.
**Ngoại lệ:** Không có ngoại lệ.
**Principles:** —
**Decisions:** —

### R-08 — Naming Convention

**Mệnh đề bắt buộc:** Tên bảng snake_case số nhiều; khóa chính `id UUID`; khóa ngoại `<singular>_id`; mọi bảng nghiệp vụ có `created_at`, `updated_at`, `deleted_at`.
**Dấu hiệu vi phạm:** `CREATE TABLE` đặt tên bảng số ít hoặc không phải snake_case (ví dụ `order`, `OrderItem`). Cột khóa chính khai báo khác `id UUID` (ví dụ `id SERIAL`, `id BIGINT`). Cột khóa ngoại không theo dạng `<singular>_id` (ví dụ cột trỏ tới `companies.id` nhưng đặt tên `company`). Migration tạo bảng nghiệp vụ thiếu cột `created_at` hoặc `updated_at`; hoặc thiếu `deleted_at` ở bảng nghiệp vụ khác `outbox`.
**Cách sửa:** Sửa tên bảng hoặc cột trong migration cho khớp quy ước trước khi merge; nếu bảng đã merge và có dữ liệu, viết migration mới dùng `RENAME COLUMN` / `RENAME TO` hoặc `ADD COLUMN` để bổ sung.
**Ngoại lệ:** Bảng `outbox` được miễn `deleted_at`.
**Principles:** —
**Decisions:** —

### R-09 — Index by Design

**Mệnh đề bắt buộc:** Mọi khóa ngoại có index; mọi cột xuất hiện trong WHERE hoặc ORDER BY của repository có index; tên index theo dạng `idx_<table>_<cols>`.
**Dấu hiệu vi phạm:** Migration thêm cột khóa ngoại (`<singular>_id ... REFERENCES ...`) nhưng không có `CREATE INDEX` tương ứng và không có comment ghi lý do miễn. Cột xuất hiện trong `WHERE` hoặc `ORDER BY` của `*_repository.go` nhưng không tìm thấy `CREATE INDEX` nào chứa cột đó trong `migrations/`. Tên index trong migration không khớp mẫu `idx_<table>_<cols>` (ví dụ `ix_orders_status`).
**Cách sửa:** Thêm `CREATE INDEX idx_<table>_<cols> ON <table>(<cols>);` vào migration; nếu bảng đủ điều kiện miễn theo Ngoại lệ, ghi comment `-- miễn index: <lý do>` ngay trong file migration đó.
**Ngoại lệ:** Bảng dưới 1000 dòng và không tham gia JOIN được miễn, nhưng phải ghi lý do ngay trong file migration.
**Principles:** P-CONC
**Decisions:** —

Chi tiết và ví dụ code: [rules/R-09-index-by-design.md](rules/R-09-index-by-design.md)

## Nhóm C — API

### R-10 — RESTful Resource

**Mệnh đề bắt buộc:** Path chỉ chứa danh từ số nhiều và id, cấm động từ trong path (`/getUser`, `/createOrder`). POST tạo mới trả 201; DELETE trả 204; lỗi validate trả 422.
**Dấu hiệu vi phạm:** Đăng ký route trong `router.go`/`routes.go` có path chứa động từ (ví dụ `.POST("/api/v1/createOrder"`, `.GET("/api/v1/getUser"`) hoặc danh từ số ít (`.GET("/api/v1/order/:id"`). Handler tạo mới (POST) kết thúc bằng `c.JSON(http.StatusOK, ...)` thay vì `http.StatusCreated`. Handler xóa gọi `c.JSON(http.StatusOK, ...)` hoặc `c.Status(http.StatusOK)` thay vì `http.StatusNoContent`. Handler validate thất bại trả `http.StatusBadRequest` thay vì `http.StatusUnprocessableEntity`.
**Cách sửa:** Đổi path về dạng `/<danh-từ-số-nhiều>/:id`; nếu là hành động không map được vào CRUD, dời sang `/orders/:id/actions/<verb>`. Đổi status code: tạo mới dùng `c.JSON(http.StatusCreated, ...)`, xóa dùng `c.Status(http.StatusNoContent)`, lỗi validate dùng `c.JSON(http.StatusUnprocessableEntity, ...)`.
**Ngoại lệ:** Endpoint hành động không map được vào CRUD dùng dạng `POST /orders/{id}/actions/approve`, và phải được ghi vào `04-conventions/C-API-http.md`.
**Principles:** —
**Decisions:** —

### R-11 — Consistent Response Envelope

**Mệnh đề bắt buộc:** Mọi response đi qua struct envelope trong `shared/response`. Handler cấm gọi `c.JSON` với map hoặc struct tự chế.
**Dấu hiệu vi phạm:** `c.JSON(` trong file `*_handler.go` có tham số thứ hai là `gin.H{` hoặc một struct literal khai báo tại chỗ (`struct{...}{...}`), không phải hàm từ package `shared/response`. File `*_handler.go` gọi `c.JSON` nhưng không có dòng import chứa `shared/response`.
**Cách sửa:** Thay `c.JSON(http.StatusOK, gin.H{...})` bằng lời gọi helper của `shared/response` (ví dụ `response.Success(c, data)` / `response.Error(c, err)`); thêm import `shared/response` vào handler.
**Ngoại lệ:** Endpoint trả file hoặc stream.
**Principles:** P-ERR
**Decisions:** —

### R-12 — List Query Standard

**Mệnh đề bắt buộc:** Mọi endpoint list nhận `page`, `page_size`, `sort`; response có `meta.total`, `meta.page`, `meta.page_size`. Cấm trả mảng trần.
**Dấu hiệu vi phạm:** Struct bind query param của handler list thiếu field gắn tag `form:"page"`, `form:"page_size"`, hoặc `form:"sort"`. Handler list kết thúc bằng `c.JSON(http.StatusOK, items)` hoặc `c.JSON(http.StatusOK, []Order{...})` — trả thẳng slice/mảng làm body thay vì object có `data` và `meta`. Struct response list không có field `Meta` chứa `Total`, `Page`, `PageSize`.
**Cách sửa:** Thêm struct `ListQuery` với field `Page`, `PageSize`, `Sort` gắn tag `form:"..."` và bind bằng `c.ShouldBindQuery(&q)`; bọc kết quả trả về trong envelope `shared/response` có `Data` và `Meta{Total, Page, PageSize}` thay vì trả mảng trần.
**Ngoại lệ:** Endpoint trả danh sách cố định dưới 50 dòng (ví dụ enum), và phải được ghi vào `04-conventions/C-API-http.md`.
**Principles:** —
**Decisions:** —

### R-13 — API Versioning

**Mệnh đề bắt buộc:** Mọi route nằm dưới `/api/v1`. Xóa field, đổi kiểu dữ liệu, hoặc đổi ý nghĩa của field là breaking change và bắt buộc sang `/api/v2`.
**Dấu hiệu vi phạm:** Route đăng ký thẳng trên router gốc hoặc trên một group không có tiền tố `/api/v1` (ví dụ `r.GET("/orders", ...)` thay vì đăng ký trong `router.Group("/api/v1")`). Diff xóa field JSON khỏi struct DTO response, đổi kiểu Go của field đó (ví dụ `Amount int` thành `Amount string`), hoặc đổi tên tag `json:"..."`, trong khi route vẫn còn nằm dưới `/api/v1` và không có route `/api/v2` song song được tạo thêm.
**Cách sửa:** Đăng ký mọi route qua `router.Group("/api/v1")`. Khi cần breaking change, tạo `router.Group("/api/v2")` với handler/DTO mới, giữ nguyên handler và DTO của `/api/v1` cho tới khi client migrate xong.
**Ngoại lệ:** Endpoint hạ tầng không thuộc API nghiệp vụ — `/health`, `/ready`, `/metrics` — nằm ngoài `/api/v1`. Đây là danh sách đóng; thêm endpoint mới vào đó phải sửa `04-conventions/C-API-http.md`.
**Principles:** —
**Decisions:** —

## Nhóm D — Security

### R-14 — Auth at Middleware

**Mệnh đề bắt buộc:** JWT verify chỉ tồn tại trong `shared/middleware/auth`. Handler và service cấm đọc header `Authorization` hoặc parse token.
**Dấu hiệu vi phạm:** `c.GetHeader("Authorization")` hoặc `r.Header.Get("Authorization")` xuất hiện trong file `*_handler.go` hoặc `*_service.go` nằm ngoài `shared/middleware/auth`. Có import package JWT (ví dụ `github.com/golang-jwt/jwt`) trong file nằm ngoài `shared/middleware/auth`.
**Cách sửa:** Xóa lời gọi đọc header/parse token khỏi handler và service; lấy thông tin user đã xác thực (user id, company id, roles) từ `ctx` do `shared/middleware/auth` gắn sẵn, ví dụ qua helper `auth.FromContext(ctx)`.
**Ngoại lệ:** Không có ngoại lệ.
**Principles:** —
**Decisions:** —

### R-15 — Permission Check in Service

**Mệnh đề bắt buộc:** Mọi method public của service mở đầu bằng một lời gọi kiểm quyền. Handler cấm chứa logic quyền; ẩn nút ở frontend không tính là kiểm quyền.
**Dấu hiệu vi phạm:** Method tên bắt đầu bằng chữ hoa trong `*_service.go` (không mang tiền tố `Internal`) mà câu lệnh đầu tiên trong thân hàm không phải lời gọi kiểm quyền (ví dụ thiếu `s.authz.Can(ctx, ...)` hoặc tương đương ngay đầu hàm). File `*_handler.go` chứa so sánh role/permission trực tiếp (`if user.Role == "admin"`, `if !user.HasPermission(...)`). Component React ẩn hoặc disable nút bằng điều kiện role (`{user.role === 'admin' && ...}`) trong khi service của API tương ứng không có bước kiểm quyền nào.
**Cách sửa:** Thêm lời gọi kiểm quyền làm câu lệnh đầu tiên của method service (ví dụ `if err := s.authz.Can(ctx, actor, PermissionX); err != nil { return err }`); chuyển mọi so sánh role/permission ra khỏi handler xuống service.
**Ngoại lệ:** Method public dùng nội bộ giữa các service, đặt tên tiền tố `Internal`, và phải khai báo trong `module.yaml`.
**Principles:** —
**Decisions:** ADR-0009

### R-16 — Never Expose Secrets

**Mệnh đề bắt buộc:** Cấm log hoặc serialize password hash, token, secret, số CCCD. Struct có field nhạy cảm phải gắn tag `json:"-"`.
**Dấu hiệu vi phạm:** Struct có field tên gợi ý dữ liệu nhạy cảm (`PasswordHash`, `Token`, `Secret`, `CCCD`, `SoCCCD`) nhưng tag không phải `json:"-"` (ví dụ vẫn còn `json:"password_hash"`). Lời gọi `logger.Info(`, `logger.Error(`, `fmt.Printf(`, `log.Println(` truyền cả struct/biến chứa field nhạy cảm nói trên làm tham số, thay vì chỉ log các field an toàn.
**Cách sửa:** Đổi tag field nhạy cảm thành `json:"-"`; nếu client cần biết trạng thái (ví dụ có mật khẩu hay chưa), thêm field boolean riêng ở DTO thay vì lộ giá trị gốc. Sửa lời gọi log để chỉ truyền các field không nhạy cảm, hoặc log qua DTO đã lọc field.
**Ngoại lệ:** Không có ngoại lệ.
**Principles:** P-OBS
**Decisions:** —

## Nhóm E — Business/Data

### R-17 — Traceability

**Mệnh đề bắt buộc:** Mọi bảng nghiệp vụ có `created_by` và `updated_by`; mọi thao tác ghi sinh bản ghi audit; `request_id` có mặt trong log và trong response; `ctx` truyền xuyên suốt handler → service → repository.
**Dấu hiệu vi phạm:** Migration `CREATE TABLE` cho bảng nghiệp vụ thiếu cột `created_by UUID` hoặc `updated_by UUID`. Method repository thực hiện `INSERT`/`UPDATE`/`DELETE` nhưng không có lời gọi ghi audit (ví dụ `auditRepo.Record(`) trong cùng transaction. Hàm ở handler, service, hoặc repository có tham số đầu tiên khác `ctx context.Context`, hoặc dùng `context.Background()`/`context.TODO()` thay vì `ctx` được truyền vào. Log line trong handler không chứa field `request_id`.
**Cách sửa:** Thêm cột `created_by UUID`, `updated_by UUID` vào migration; thêm lời gọi `auditRepo.Record(ctx, tx, ...)` ngay trong transaction chứa thao tác ghi; sửa signature hàm để nhận `ctx context.Context` làm tham số đầu và truyền tiếp xuống tầng dưới thay vì tạo context mới; gắn `request_id` vào `ctx` ở middleware và field hoá nó trong mọi lời gọi logger.
**Ngoại lệ:** Bảng trong `system_tables`.
**Principles:** P-OBS, P-IDEM
**Decisions:** ADR-0007

> **R-17 khác P-OBS chỗ nào:** R-17 truy vết **dữ liệu nghiệp vụ** — ai sửa bản ghi
> nào, lúc nào, qua request nào; phục vụ người dùng cuối và kiểm toán. P-OBS lo
> **sức khỏe hệ thống** — latency, error rate, span; phục vụ người vận hành.
> Điểm giao duy nhất là `request_id`/`trace_id`: R-17 sở hữu nó, P-OBS chỉ tiêu thụ.

Chi tiết và ví dụ code: [rules/R-17-traceability.md](rules/R-17-traceability.md)

### R-18 — Soft Delete by Default

**Mệnh đề bắt buộc:** DELETE nghiệp vụ là set `deleted_at`, không xóa vật lý. Mọi query đọc có `deleted_at IS NULL`. Hard delete phải có ADR riêng.
**Dấu hiệu vi phạm:** Method repository tên `Delete`/`Remove` trên bảng nghiệp vụ chứa câu SQL `DELETE FROM <table>` thay vì `UPDATE <table> SET deleted_at = `. Câu SQL `SELECT` trong `*_repository.go` đọc bảng nghiệp vụ nhưng mệnh đề `WHERE` không chứa `deleted_at IS NULL`. Có `DELETE FROM` nhắm vào bảng nghiệp vụ trong migration hoặc repository mà không kèm comment trỏ tới số ADR cho phép.
**Cách sửa:** Đổi câu lệnh xóa thành `UPDATE <table> SET deleted_at = now(), updated_by = $n WHERE id = $m AND deleted_at IS NULL`; thêm `AND deleted_at IS NULL` vào mọi câu `SELECT` đọc bảng nghiệp vụ; nếu bắt buộc phải hard delete, viết ADR mới xin phép trước khi thêm `DELETE FROM`.
**Ngoại lệ:** Hard delete được phép khi có ADR riêng cho phép.
**Principles:** —
**Decisions:** ADR-0008

### R-19 — Business Rules Never in UI

**Mệnh đề bắt buộc:** Frontend cấm tính tiền, thuế, tồn kho, và cấm quyết định trạng thái nào là hợp lệ. Mọi validate nghiệp vụ phải có bản backend; validate ở frontend chỉ là UX.
**Dấu hiệu vi phạm:** File `.ts`/`.tsx` ở frontend chứa biểu thức tính toán tiền/thuế/tồn kho (ví dụ `* taxRate`, `subtotal + tax`, `quantity - reserved`) rồi dùng kết quả đó để hiển thị hoặc submit, thay vì hiển thị nguyên giá trị API trả về. Component frontend chứa bảng chuyển trạng thái hợp lệ hardcode (ví dụ `const nextStatuses = { pending: ['approved', 'rejected'] }`) dùng để quyết định cho phép hành động, trong khi service backend tương ứng không có validate transition tương ứng.
**Cách sửa:** Xóa phép tính tiền/thuế/tồn kho khỏi frontend, chỉ render giá trị mà API trả về. Chuyển bảng chuyển trạng thái hợp lệ vào service backend; frontend chỉ dựa vào field API trả về (ví dụ `allowed_actions`) để biết bật/tắt nút, không tự suy luận.
**Ngoại lệ:** Không có ngoại lệ.
**Principles:** —
**Decisions:** ADR-0009
