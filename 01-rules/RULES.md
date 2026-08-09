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
