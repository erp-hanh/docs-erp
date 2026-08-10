# 19 Architecture Rules

Rule là thứ **bắt buộc** và **kiểm được**: mỗi mệnh đề dưới đây trả lời được Có/Không
khi nhìn một file hoặc một diff, không cần biết ngữ cảnh nghiệp vụ.

Thứ không kiểm được bằng diff thì không nằm ở đây mà nằm ở `02-principles/`.

Khi hai Rule mâu thuẫn nhau: dừng lại, hỏi người. Không tự chọn bên.

---

## Nhóm A — Module Boundary

### R-01 — Module Boundary

**Mệnh đề bắt buộc:** Code trong `modules/<A>/internal/` chỉ được import bởi chính module A. Module khác chỉ được import `modules/<A>/api/` (interface + DTO). Composition root `cmd/**` chỉ được import package chứa `modules/<A>/module.go` — hàm khởi tạo và đăng ký của module — cấm import bất kỳ package con nào khác của module.
**Dấu hiệu vi phạm:** Trong file thuộc `modules/B/`, có dòng import chứa `modules/A/internal`. Dòng import trong file thuộc `cmd/**` chứa `modules/` và còn nhiều hơn một segment sau `modules/`, tức là còn segment đứng sau tên module (ví dụ `erp/modules/order/api`, `erp/modules/order/internal/service`); chỉ đúng `erp/modules/order` mới hợp lệ.
**Cách sửa:** Đưa thứ B cần lên `modules/A/api/` dưới dạng interface hoặc DTO, rồi import qua đó.
**Ngoại lệ:** Không có ngoại lệ.
**Principles:** —
**Decisions:** ADR-0001

Chi tiết và ví dụ code: [rules/R-01-module-boundary.md](rules/R-01-module-boundary.md)

### R-02 — No Cross-Module DB Access

**Mệnh đề bắt buộc:** Repository của module A chỉ được query bảng nằm trong danh sách `tables` khai báo ở `module.yaml` của A. Cấm JOIN sang bảng thuộc module khác.
**Dấu hiệu vi phạm:** Chuỗi SQL trong `modules/A/**/repository` có tên bảng không nằm trong `tables` của `modules/A/module.yaml`.
**Cách sửa:** Gọi service của module sở hữu bảng đó qua `api/` của nó. Nếu cần dữ liệu để lọc hoặc hiển thị, nhận qua tham số hoặc qua event.
**Ngoại lệ:** Bảng trong `system_tables`, bảng trong `tenant_root`, và bảng trong `reference_tables` được đọc bởi mọi module. `tenant_root` chỉ chứa `companies`, chốt ở blockquote "Năm nhóm bảng" dưới R-06; cả ba danh sách liệt kê ở `04-conventions/C-DB-database.md` mục `C-DB-04`.
**Principles:** —
**Decisions:** ADR-0001

### R-03 — Layered Structure

**Mệnh đề bắt buộc:** Handler cấm import `pgx` hoặc `sqlx`. Service cấm import `gin` hoặc `net/http`. Repository cấm import package `service` của bất kỳ module nào, và cấm sinh lỗi nghiệp vụ bằng `errors.New(` hoặc `fmt.Errorf(` — lỗi nghiệp vụ do service sinh, repository chỉ trả lỗi kỹ thuật do driver trả về và `sql.ErrNoRows`.
**Dấu hiệu vi phạm:** `import "github.com/jackc/pgx/v5"` trong file `*_handler.go`; `import "github.com/gin-gonic/gin"` trong file `*_service.go`. Dòng import kết thúc bằng `/service` hoặc `/internal/service` trong file `*_repository.go`. Lời gọi `errors.New(` trong file `*_repository.go`; lời gọi `fmt.Errorf(` trong file `*_repository.go` mà chuỗi định dạng không kết thúc bằng `: %w` — tức là đang tạo lỗi mới chứ không bọc lỗi kỹ thuật.
**Cách sửa:** Chuyển truy cập dữ liệu xuống repository, chuyển thứ phụ thuộc HTTP lên handler. Xóa lời gọi tạo lỗi khỏi repository: trả thẳng lỗi driver hoặc `sql.ErrNoRows` lên, để service dịch thành lỗi nghiệp vụ.
**Ngoại lệ:** Không có ngoại lệ.
**Principles:** P-TXN, P-ERR
**Decisions:** ADR-0001

### R-04 — Dependency Direction

**Mệnh đề bắt buộc:** `shared/` cấm import bất kỳ package nào dưới `modules/`. Module A cấm có tên trong `allowed_deps` của `modules/B/module.yaml` nếu B đã có tên trong `allowed_deps` của `modules/A/module.yaml`. Chu trình dài hơn hai nút do CI dò trên toàn đồ thị, không phải việc của rule này.
**Dấu hiệu vi phạm:** Dòng import chứa `/modules/` trong file thuộc `shared/`. Diff thêm tên module A vào `allowed_deps` của `modules/B/module.yaml` trong khi `modules/A/module.yaml` đã có tên B trong `allowed_deps` — hai file này đọc cạnh nhau là đủ kết luận.
**Cách sửa:** Đưa thứ dùng chung xuống `shared/`, hoặc đảo quan hệ bằng interface do `shared/` định nghĩa và module implement.
**Ngoại lệ:** Không có ngoại lệ.
**Principles:** —
**Decisions:** ADR-0001

### R-05 — Events for Decoupling

**Mệnh đề bắt buộc:** Gồm bốn mệnh đề, tất cả đều bắt buộc:

1. Service của A chỉ gọi đồng bộ sang module có tên trong `allowed_deps` của `module.yaml` thuộc A; ngoài danh sách phải đi qua event.
2. Chỉ service được ghi outbox. Handler và repository cấm.
3. Service ghi event vào bảng `outbox` **trong cùng transaction** với dữ liệu nghiệp vụ.
4. Service cấm gọi `bus.Publish` ở **bất kỳ vị trí nào** — trong transaction, sau `tx.Commit()`, hay qua `defer`. Chỉ relay, là package nằm ngoài `modules/`, được publish ra bus sau khi đọc `outbox`.

**Dấu hiệu vi phạm:** Bất kỳ dòng nào khớp `.Publish(` trong `modules/**` là vi phạm, không cần xét vị trí của dòng đó so với transaction. Lời gọi `outboxRepo.Append(` xuất hiện trong file `*_handler.go` hoặc `*_repository.go` — chỉ service được ghi outbox. Import module không có trong `allowed_deps`.
**Cách sửa:** Thay lời gọi bus bằng `outboxRepo.Append(ctx, tx, event)`. Để relay lo việc publish.
**Ngoại lệ:** Không có ngoại lệ.
**Principles:** P-EVT, P-IDEM, P-TXN
**Decisions:** ADR-0006

> Relay là **at-least-once**. Vì vậy `P-IDEM` không phải tùy chọn mà là điều kiện để
> ADR-0006 đứng vững: mọi event handler phải idempotent theo `event_id`.

Chi tiết và ví dụ code: [rules/R-05-events-for-decoupling.md](rules/R-05-events-for-decoupling.md)

## Nhóm B — Database

### R-06 — Tenant Column Everywhere

**Mệnh đề bắt buộc:** Mọi bảng **trừ** `system_tables`, `tenant_root` và `reference_tables` có `company_id UUID NOT NULL` — bao gồm cả `append_only_tables`; mọi query trong repository có `company_id = $n` trong mệnh đề WHERE. Giá trị truyền vào `company_id` phải lấy từ `actor.CompanyID` — actor mà service nhận qua tham số thứ hai theo R-15 — cấm nhận từ request của client. Handler là nơi duy nhất được đọc actor ra khỏi `ctx` (`auth.FromContext(ctx)`) rồi truyền xuống service. Bảng được miễn phải liệt kê tường minh trong một trong ba nhóm đó: `tenant_root` chỉ chứa `companies` và được chốt ở blockquote dưới rule này; `system_tables` và `reference_tables` liệt kê ở `04-conventions/C-DB-database.md` mục `C-DB-04`.
**Dấu hiệu vi phạm:** Migration có `CREATE TABLE <tên>` nhưng không có dòng `company_id UUID NOT NULL`, và `<tên>` không có trong `system_tables`, `tenant_root` lẫn `reference_tables`. File `*_repository.go` có câu SQL `SELECT`/`UPDATE`/`DELETE` trên bảng nghiệp vụ nhưng không chứa chuỗi `company_id = $` trong mệnh đề `WHERE`. Câu SQL `SELECT` trên bảng nghiệp vụ trong `*_repository.go` không có mệnh đề `WHERE` nào. Struct DTO request có field gắn tag `json:"company_id"` hoặc `form:"company_id"`. Chuỗi `c.Param("company_id")` hoặc `c.Query("company_id")` xuất hiện trong file `*_handler.go`.
**Cách sửa:** Thêm cột `company_id UUID NOT NULL REFERENCES companies(id)` vào migration; bổ sung điều kiện `company_id = $n` vào `WHERE` của câu SQL đang thiếu trong repository; xóa field `company_id` khỏi DTO request, để handler lấy actor từ `ctx` (`auth.FromContext(ctx)`) và truyền vào service làm tham số thứ hai, rồi service dùng `actor.CompanyID` truyền xuống repository.
**Ngoại lệ:** Bảng trong `system_tables`, bảng trong `tenant_root` và bảng trong `reference_tables` đều không có `company_id`. `system_tables` và `reference_tables` không thuộc tenant nào; `tenant_root` thì **là** tenant, nên nó không thể mang khóa trỏ tới chính khái niệm nó định nghĩa. `tenant_root` chỉ chứa `companies`; cả ba danh sách nằm ở `04-conventions/C-DB-database.md` mục `C-DB-04`.
**Principles:** —
**Decisions:** ADR-0003

> **Năm nhóm bảng — dùng chung cho R-02, R-06, R-08, R-09, R-17, R-18:**
>
> | Nhóm | `company_id` | Cột thời gian | Cột audit | Sinh bản ghi audit khi ghi | Soft delete | Mọi module đọc được |
> |---|---|---|---|---|---|---|
> | `system_tables` | Không | Không | Không | Không | Không | Có |
> | `tenant_root` | Không | Có đủ | Có đủ | Có | Có | Có |
> | `reference_tables` | Không | Có đủ | Có đủ | Có | Có | Có |
> | `append_only_tables` | Có | Chỉ `created_at` | Chỉ `created_by` | Không | Không — hard delete theo lịch giữ liệu | Không |
> | Bảng nghiệp vụ | Có | Có đủ | Có đủ | Có | Có | Không |
>
> "Cột thời gian" là `created_at`, `updated_at`, `deleted_at`; "cột audit" là
> `created_by`, `updated_by`; "có đủ" nghĩa là có trọn nhóm cột đó. Ô "Không" là
> **miễn trừ**: bảng thuộc nhóm đó không có cột/hành vi tương ứng, và mọi Rule đòi
> thứ đó đều không áp lên nó.
>
> - **`system_tables`** — bảng hạ tầng, không thuộc tenant nào. Khởi đầu gồm
>   `schema_migrations`.
> - **`tenant_root`** — bảng gốc của cơ chế multi-tenant. Chỉ chứa `companies`.
>   Không có `company_id` vì nó **là** tenant, không thuộc tenant nào. Ngoài điểm đó,
>   nó chịu mọi thứ như bảng nghiệp vụ: đủ ba cột thời gian, đủ cột audit, vẫn sinh
>   bản ghi audit, vẫn soft delete. Nó không nằm trong `system_tables` vì nhóm đó
>   miễn cả audit lẫn soft delete — tạo hay sửa một công ty mà không để lại dấu vết
>   là sai về nghiệp vụ.
> - **`reference_tables`** — danh mục dùng chung toàn hệ thống, không thuộc tenant
>   nào. Khởi đầu gồm `currencies`, `units`, `provinces`. Giống bảng nghiệp vụ ở mọi
>   điểm **trừ hai**: không có `company_id`, và mọi module được đọc. Người ta vẫn sửa
>   danh mục và vẫn cần truy vết ai sửa, nên nó không thể nằm trong `system_tables` —
>   nhóm đó miễn cả audit lẫn soft delete.
> - **`append_only_tables`** — bảng chỉ ghi thêm, không bao giờ sửa. Khởi đầu gồm
>   `outbox`, `audit_logs` và `idempotency_keys`.
> - **Bảng nghiệp vụ** — mọi bảng còn lại, tức là bảng không có tên trong bốn danh
>   sách trên. Không được miễn thứ gì.
>
> **Nguồn sự thật của cả bốn danh sách `system_tables`, `tenant_root`,
> `reference_tables` và `append_only_tables` — cộng danh sách `naming_exempt` miễn quy
> tắc đặt tên — là `04-conventions/C-DB-database.md` mục `C-DB-04`**, nơi giữ chúng
> dưới dạng registry máy đọc được. ADR giữ *why*, `C-DB` giữ *current policy*.
>
> Thêm một tên vào bất kỳ danh sách nào trong số đó vẫn bắt buộc viết ADR mới. Lý do
> giữ nguyên: các danh sách này là công tắc miễn trừ cùng lúc nhiều Rule, nên một PR
> sửa Convention mà nới lỏng được chúng là một PR vô hiệu hóa được Rule, trái thứ tự
> ưu tiên `Rules > Principles > Conventions`. Thứ chặn việc đó **không** còn là chỗ
> đứng của danh sách, mà là **trường `adr` bắt buộc ở mỗi entry**: entry phải trỏ tới
> một ADR `Accepted` biện minh tường minh cho phân loại của nó, nên một entry thêm vào
> mà không có ADR là một entry hỏng, nhìn thấy được ngay trong diff và bắt được bằng
> checker.
>
> `tenant_root` là **danh sách đóng: chỉ `companies`** — thêm tên vào nó cũng bắt buộc
> viết ADR mới.

Chi tiết và ví dụ code: [rules/R-06-tenant-column.md](rules/R-06-tenant-column.md)

### R-07 — Migration Only

**Mệnh đề bắt buộc:** Schema chỉ đổi qua file trong `migrations/`, đánh số tăng dần, có cả `up` và `down`. Cấm sửa migration đã merge — sai thì viết migration mới.
**Dấu hiệu vi phạm:** Trong diff, một file đã tồn tại trong `migrations/` bị sửa nội dung (trạng thái `M` — modified) thay vì chỉ có file mới ở trạng thái thêm (`A` — added). File migration mới chỉ có phần `up`, thiếu phần `down` tương ứng. Có `CREATE TABLE`, `ALTER TABLE`, hoặc `DROP TABLE` trong file nằm ngoài thư mục `migrations/`.
**Cách sửa:** Revert file migration cũ về đúng nội dung đã merge; tạo file migration mới với số thứ tự kế tiếp chứa đúng thay đổi mong muốn, có đủ phần `up` và `down`.
**Ngoại lệ:** Không có ngoại lệ.
**Principles:** —
**Decisions:** —

### R-08 — Naming Convention

**Mệnh đề bắt buộc:** Tên bảng khớp regex `^[a-z][a-z0-9_]*s$`; tên không kết thúc bằng `s` phải nằm trong danh sách `naming_exempt` khai báo ở `04-conventions/C-DB-database.md` mục `C-DB-04`. Khóa chính `id UUID`; khóa ngoại `<singular>_id`; mọi **bảng nghiệp vụ**, mọi bảng trong `tenant_root` và mọi bảng trong `reference_tables` có `created_at`, `updated_at`, `deleted_at`.
**Dấu hiệu vi phạm:** `CREATE TABLE` đặt tên bảng không khớp `^[a-z][a-z0-9_]*s$` (ví dụ `order`, `OrderItem`, `inventory`) và tên đó không có trong danh sách `naming_exempt` ở `04-conventions/C-DB-database.md` mục `C-DB-04`. Cột khóa chính khai báo khác `id UUID` (ví dụ `id SERIAL`, `id BIGINT`). Cột khóa ngoại không theo dạng `<singular>_id` (ví dụ cột trỏ tới `companies.id` nhưng đặt tên `company`). Migration tạo bảng nghiệp vụ, bảng có tên trong `tenant_root`, hoặc bảng có tên trong `reference_tables` mà thiếu cột `created_at`, `updated_at`, hoặc `deleted_at`. Migration tạo bảng có tên trong `append_only_tables` thiếu cột `created_at`.
**Cách sửa:** Sửa tên bảng hoặc cột trong migration cho khớp quy ước trước khi merge; nếu bảng đã merge và có dữ liệu, viết migration mới dùng `RENAME COLUMN` / `RENAME TO` hoặc `ADD COLUMN` để bổ sung. Nếu tên bảng không thể chuyển sang dạng kết thúc bằng `s` (ví dụ `inventory`, `equipment`, `machinery`), viết ADR bổ sung tên đó vào danh sách miễn đặt tên trước khi merge migration.
**Ngoại lệ:** Bảng trong `system_tables` miễn toàn bộ vế cột. Bảng trong `append_only_tables` chỉ có `created_at`, miễn `updated_at` và `deleted_at`. Bảng trong `tenant_root` và bảng trong `reference_tables` **không** được miễn vế cột — cả hai nhóm có đủ ba cột thời gian như bảng nghiệp vụ, chỗ duy nhất chúng khác là thiếu `company_id`, mà `company_id` không phải việc của rule này. Các danh sách nằm ở `04-conventions/C-DB-database.md` mục `C-DB-04`.
**Principles:** —
**Decisions:** —

### R-09 — Index by Design

**Mệnh đề bắt buộc:** Mọi khóa ngoại **trừ `company_id`** phải là cột dẫn đầu của một index, hoặc là cột thứ hai trong index composite bắt đầu bằng `company_id`. Mọi cột xuất hiện trong `WHERE` hoặc `ORDER BY` của repository phải là cột thứ nhất hoặc thứ hai của ít nhất một index; `company_id` và `deleted_at` không tính khi đứng một mình. Cột chỉ xuất hiện dưới dạng một điều kiện cố định — ví dụ `published_at IS NULL` — cũng được coi là đã phục vụ nếu nó nằm trong mệnh đề `WHERE` của một partial index, không cần là cột trong danh sách cột. Tên index theo quy ước ở `04-conventions/C-DB-database.md`, không phải việc của rule này.
**Dấu hiệu vi phạm:** Migration thêm cột khóa ngoại (`<singular>_id ... REFERENCES ...`) khác `company_id` nhưng trong cùng file không có `CREATE INDEX` nào đặt cột đó ở vị trí thứ nhất, cũng không có `CREATE INDEX ... (company_id, <cột đó>...)`, và không có comment miễn. Cột xuất hiện trong `WHERE` hoặc `ORDER BY` của `*_repository.go` — trừ `company_id` và `deleted_at` khi chúng đứng một mình — nhưng không tìm thấy `CREATE INDEX` nào trong `migrations/` đặt cột đó ở vị trí thứ nhất hoặc thứ hai.
**Cách sửa:** Thêm `CREATE INDEX` ngay trong file migration tạo cột: bảng nghiệp vụ dùng composite `ON <table>(company_id, <cols>)`, bảng không có `company_id` dùng `ON <table>(<cols>)`; tên index đặt theo `04-conventions/C-DB-database.md`. Nếu bảng đủ điều kiện miễn theo Ngoại lệ, ghi comment `-- index-exempt: <lý do>` ngay trong file migration đó.
**Ngoại lệ:** Chỉ bảng thỏa **cả hai** điều kiện mới được miễn: (a) có tên trong danh sách `reference_tables` ở `04-conventions/C-DB-database.md` mục `C-DB-04`, và (b) không có khóa ngoại trỏ tới bảng giao dịch. Thiếu một trong hai là không được miễn — bảng nghiệp vụ nhỏ vẫn phải có index, và một bảng danh mục trỏ FK sang bảng giao dịch thì lớn lên theo lượng giao dịch nên cũng vậy. Điều kiện (a) đòi một ADR chứ không cấp lẻ trong migration: quyết định "bảng này là danh mục dùng chung, không thuộc tenant nào" phải có trước, ngoại lệ index chỉ là hệ quả. Comment miễn phải theo đúng mẫu ASCII `-- index-exempt: <lý do>` (dùng ASCII vì PowerShell 5.1 đọc file UTF-8 không BOM theo codepage ANSI, chuỗi tiếng Việt sẽ không khớp khi grep).
**Principles:** P-CONC
**Decisions:** —

Chi tiết và ví dụ code: [rules/R-09-index-by-design.md](rules/R-09-index-by-design.md)

## Nhóm C — API

### R-10 — RESTful Resource

**Mệnh đề bắt buộc:** Path chỉ chứa danh từ số nhiều và id, cấm động từ trong path (`/getUser`, `/createOrder`). POST tạo mới trả 201; DELETE trả 204; lỗi validate trả 422.
**Dấu hiệu vi phạm:** Đăng ký route trong `router.go`/`routes.go` có **một segment nguyên vẹn** của path khớp danh sách động từ đóng `^(get|create|update|delete|list|fetch|save|send|check|do)([A-Z_-]\w*)?$` — khớp phân biệt hoa thường, **không** dùng cờ `(?i)`: có `(?i)` thì `[A-Z_-]` cũng khớp chữ thường và `checklists`, `documents`, `lists` đều bị bắt oan (ví dụ `.POST("/api/v1/createOrder"`, `.GET("/api/v1/getUser"`) hoặc danh từ số ít (`.GET("/api/v1/order/:id"`). Phải khớp theo segment chứ không phải chuỗi con: `/documents`, `/checklists`, `/price-lists` là hợp lệ dù chứa `do`, `check`, `list`. Handler tạo mới (POST) kết thúc bằng `c.JSON(http.StatusOK, ...)` thay vì `http.StatusCreated`. Handler xóa gọi `c.JSON(http.StatusOK, ...)` hoặc `c.Status(http.StatusOK)` thay vì `http.StatusNoContent`. Handler validate thất bại trả `http.StatusBadRequest` thay vì `http.StatusUnprocessableEntity`.
**Cách sửa:** Đổi path về dạng `/<danh-từ-số-nhiều>/:id`; nếu là hành động không map được vào CRUD, dời sang `/orders/:id/actions/<verb>`. Đổi status code: tạo mới dùng `c.JSON(http.StatusCreated, ...)`, xóa dùng `c.Status(http.StatusNoContent)`, lỗi validate dùng `c.JSON(http.StatusUnprocessableEntity, ...)`.
**Ngoại lệ:** Endpoint hành động không map được vào CRUD dùng dạng `POST /orders/{id}/actions/approve`, và phải được ghi vào `04-conventions/C-API-http.md`. Ba endpoint hạ tầng nêu ở R-13 — `/health`, `/ready`, `/metrics` — nằm ngoài phạm vi rule này. Nhóm `/api/v1/auth/*` được dùng path không theo dạng tài nguyên (ví dụ `/api/v1/auth/login`, `/api/v1/auth/refresh`, `/api/v1/auth/logout`).
**Principles:** —
**Decisions:** —

### R-11 — Consistent Response Envelope

**Mệnh đề bắt buộc:** Mọi response đi qua struct envelope trong `shared/response`. Handler và middleware cấm gọi `c.JSON` với map hoặc struct tự chế.
**Dấu hiệu vi phạm:** Bất kỳ file nào dưới `modules/**` hoặc `shared/middleware/**` chứa `c.JSON(`, `c.AbortWithStatusJSON(`, `c.IndentedJSON(`, hoặc `c.PureJSON(` với tham số thứ hai (thân response) là `gin.H{` hoặc một struct literal khai báo tại chỗ (`struct{...}{...}`), thay vì giá trị dựng từ package `shared/response`.
**Cách sửa:** Thay `c.JSON(http.StatusOK, gin.H{...})` và `c.AbortWithStatusJSON(401, gin.H{...})` bằng lời gọi helper của `shared/response` (ví dụ `response.Success(c, data)` / `response.Error(c, err)`); thêm import `shared/response` vào file đó.
**Ngoại lệ:** Chỉ handler gọi `c.File(`, `c.FileAttachment(`, `c.DataFromReader(`, hoặc `c.Stream(` và không gọi `c.JSON(` trong cùng hàm mới được miễn; endpoint đó phải được liệt kê ở `04-conventions/C-API-http.md`.
**Principles:** P-ERR
**Decisions:** —

### R-12 — List Query Standard

**Mệnh đề bắt buộc:** Mọi endpoint list nhận `page`, `page_size`, `sort`; response có `meta.total`, `meta.page`, `meta.page_size`. Cấm trả mảng trần. Giá trị `sort` phải đi qua một map whitelist khai báo tĩnh trong repository (tên field client gửi lên ánh xạ sang tên cột); cấm nội suy chuỗi `sort` do client gửi vào câu SQL.
**Dấu hiệu vi phạm:** Struct bind query param của handler list thiếu field gắn tag `form:"page"`, `form:"page_size"`, hoặc `form:"sort"`. Biến mang giá trị `sort` đi vào câu SQL bằng nối chuỗi hoặc `fmt.Sprintf(` trong `*_repository.go`, thay vì tra qua map whitelist khai báo tĩnh ở cấp package. Handler list kết thúc bằng `c.JSON(http.StatusOK, items)` hoặc `c.JSON(http.StatusOK, []Order{...})` — trả thẳng slice/mảng làm body thay vì object có `data` và `meta`. Struct response list không có field `Meta` chứa `Total`, `Page`, `PageSize`.
**Cách sửa:** Thêm struct `ListQuery` với field `Page`, `PageSize`, `Sort` gắn tag `form:"..."` và bind bằng `c.ShouldBindQuery(&q)`; bọc kết quả trả về trong envelope `shared/response` có `Data` và `Meta{Total, Page, PageSize}` thay vì trả mảng trần; khai báo `var sortable = map[string]string{"created_at": "created_at", ...}` ở cấp package trong repository và chỉ ghép vào `ORDER BY` giá trị lấy ra từ map đó, mọi khóa không có trong map thì rơi về cột mặc định.
**Ngoại lệ:** Chỉ endpoint trả hằng số biên dịch được — enum khai ngay trong code Go, không truy vấn DB — mới được miễn, và phải được ghi vào `04-conventions/C-API-http.md`.
**Principles:** —
**Decisions:** —

### R-13 — API Versioning

**Mệnh đề bắt buộc:** Mọi route nằm dưới `/api/v1`. Xóa field hoặc đổi kiểu dữ liệu của field trong DTO response là breaking change và bắt buộc sang `/api/v2`. Thêm field bắt buộc — field gắn tag `binding:"required"` — vào request DTO của một route `/api/v1` đã tồn tại cũng là breaking change.
**Dấu hiệu vi phạm:** Route đăng ký thẳng trên router gốc hoặc trên một group không có tiền tố `/api/v1` (ví dụ `r.GET("/orders", ...)` thay vì đăng ký trong `router.Group("/api/v1")`). Diff xóa field JSON khỏi struct DTO response, đổi kiểu Go của field đó (ví dụ `Amount int` thành `Amount string`), hoặc đổi tên tag `json:"..."`, trong khi route vẫn còn nằm dưới `/api/v1` và không có route `/api/v2` song song được tạo thêm. Diff thêm vào struct DTO request của một route `/api/v1` đã tồn tại một field mang tag `binding:"required"`.
**Cách sửa:** Đăng ký mọi route qua `router.Group("/api/v1")`. Khi cần breaking change, tạo `router.Group("/api/v2")` với handler/DTO mới, giữ nguyên handler và DTO của `/api/v1` cho tới khi client migrate xong.
**Ngoại lệ:** Endpoint hạ tầng không thuộc API nghiệp vụ — `/health`, `/ready`, `/metrics` — nằm ngoài `/api/v1`. Đây là danh sách đóng; thêm endpoint hạ tầng mới phải sửa chính rule này.
**Principles:** —
**Decisions:** —

## Nhóm D — Security

### R-14 — Auth at Middleware

**Mệnh đề bắt buộc:** JWT verify chỉ tồn tại trong `shared/middleware/auth`. Handler và service cấm đọc header `Authorization` hoặc parse token.
**Dấu hiệu vi phạm:** `c.GetHeader("Authorization")` hoặc `r.Header.Get("Authorization")` xuất hiện trong file `*_handler.go` hoặc `*_service.go` nằm ngoài `shared/middleware/auth`. `jwt.Parse(`, `jwt.ParseWithClaims(`, hoặc `ParseUnverified(` xuất hiện trong file nằm ngoài `shared/middleware/auth`.
**Cách sửa:** Xóa lời gọi đọc header/parse token khỏi handler và service; lấy thông tin user đã xác thực (user id, company id, roles) từ `ctx` do `shared/middleware/auth` gắn sẵn, qua helper `auth.FromContext(ctx)` gọi **ở handler**, rồi truyền `actor` xuống service làm tham số thứ hai theo R-15 — service không tự gọi `auth.FromContext`.
**Ngoại lệ:** Package ký token `modules/auth/internal/token` được phép dùng `jwt.NewWithClaims(` và `SignedString(` để phát hành token; cấm dùng bất kỳ hàm parse hoặc verify nào ở đó.
**Principles:** —
**Decisions:** —

### R-15 — Permission Check in Service

**Mệnh đề bắt buộc:** Mọi method public của service nhận `actor auth.Actor` làm **tham số thứ hai, ngay sau `ctx context.Context`**, và mở đầu bằng một lời gọi kiểm quyền dùng chính actor đó. Handler là nơi duy nhất được gọi `auth.FromContext(ctx)` để lấy actor ra rồi truyền xuống. Handler cấm chứa logic quyền; ẩn nút ở frontend không tính là kiểm quyền.
**Dấu hiệu vi phạm:** Trong file `*_service.go`, hàm khớp `^func \(s \*\w+Service\) [A-Z]` mà tham số thứ hai không phải `actor auth.Actor` — dấu hiệu này áp cho **cả** method `Internal*`. Trong file `*_service.go`, hàm khớp `^func \(s \*\w+Service\) [A-Z]` mà tên không mang tiền tố `Internal` và dòng lệnh đầu tiên của thân hàm không khớp `^\tif err := s\.authz\.(Can|Require)\(`. Chuỗi `auth.FromContext(` xuất hiện trong file `*_service.go` — actor phải đến qua tham số, không phải moi lại từ `ctx`. File `*_handler.go` chứa so sánh role/permission trực tiếp (`if user.Role == "admin"`, `if !user.HasPermission(...)`).
**Cách sửa:** Thêm `actor auth.Actor` làm tham số thứ hai của method service và cho handler truyền `auth.FromContext(ctx)` xuống; thêm lời gọi kiểm quyền làm câu lệnh đầu tiên của method service (`if err := s.authz.Can(ctx, actor, PermissionX); err != nil { return err }`); chuyển mọi so sánh role/permission ra khỏi handler xuống service. Chữ ký nhận actor tường minh là thứ giữ được vế "câu lệnh đầu tiên": nếu actor lấy từ `ctx` thì phải có một dòng `actor := auth.FromContext(ctx)` đứng trước lời gọi kiểm quyền, tự nó đã vi phạm rule này.
**Ngoại lệ:** Method public dùng nội bộ giữa các service **trong cùng một module** phải mang tiền tố `Internal`, phải có tên trong trường `internal_methods` của `module.yaml`, và cấm xuất hiện trong bất kỳ interface nào thuộc `modules/*/api/`. `Internal*` **không** phải đường gọi xuyên module: R-01 chỉ cho module khác import `modules/<A>/api/`, mà `Internal*` bị cấm có mặt ở đó — hai rule cộng lại khiến module ngoài không bao giờ chạm tới được. Nếu gặp ca hai module phải cùng commit nguyên tử, dừng lại và hỏi người; đó là ca cần một ADR mở đường chứ không phải chỗ lách bằng `Internal*`. Method `Internal*` được miễn vế "câu lệnh đầu tiên là kiểm quyền" nhưng **vẫn phải nhận `actor auth.Actor` làm tham số thứ hai** và vẫn phải tự ghi bản ghi audit theo R-17.

Ngoại lệ thứ hai: method phục vụ luồng cấp token — `Login`, `Refresh`, `Logout` của `AuthService` — chạy khi chưa có actor nên vừa không kiểm quyền được, vừa không có actor để nhận; ba method này được miễn cả hai vế của mệnh đề. Đây là danh sách đóng, thêm method vào đó phải sửa chính rule này. Mọi method khác của `AuthService` vẫn phải nhận actor và vẫn phải kiểm quyền.
**Principles:** —
**Decisions:** ADR-0009

### R-16 — Never Expose Secrets

**Mệnh đề bắt buộc:** Cấm log hoặc serialize password hash, token, secret, số CCCD. Struct có field nhạy cảm phải gắn tag `json:"-"`.
**Dấu hiệu vi phạm:** Struct có field mà tên khớp `(?i)(password|passwd|matkhau|secret|token|apikey|api_key|privatekey|cccd|cmnd|otp)` nhưng tag không phải `json:"-"` (ví dụ vẫn còn `json:"password_hash"`). Lời gọi `logger.Info(`, `logger.Error(`, `fmt.Printf(`, `log.Println(` nhận một con trỏ hoặc một struct model làm tham số; logger chỉ được nhận cặp key-value kiểu nguyên thủy (string, số, bool).
**Cách sửa:** Đổi tag field nhạy cảm thành `json:"-"`; nếu client cần biết trạng thái (ví dụ có mật khẩu hay chưa), thêm field boolean riêng ở DTO thay vì lộ giá trị gốc. Sửa lời gọi log thành cặp key-value nguyên thủy (`log.FromContext(ctx).Info("order created", "order_id", o.ID, "status", o.Status)`) thay vì truyền cả struct hay con trỏ.
**Ngoại lệ:** DTO response của endpoint cấp token hoặc làm mới token được phép serialize token, và phải được khai báo trong `04-conventions/C-API-http.md`.
**Principles:** P-OBS
**Decisions:** —

## Nhóm E — Business/Data

### R-17 — Traceability

**Mệnh đề bắt buộc:** Mọi **bảng nghiệp vụ**, mọi bảng trong `tenant_root` và mọi bảng trong `reference_tables` có `created_by` và `updated_by`; mọi thao tác ghi lên ba nhóm bảng đó sinh bản ghi audit trong cùng transaction với thao tác đó; `ctx` truyền xuyên suốt handler → service → repository; `request_id` có mặt trong log và trong response. `request_id` đi qua header `X-Request-Id` cho **mọi** response — bản sao trong envelope chỉ là tiện ích cho client, không thay thế header, để endpoint trả file (ngoại lệ của R-11) vẫn có chỗ mang `request_id`.
**Dấu hiệu vi phạm:** Migration `CREATE TABLE` cho bảng nghiệp vụ, cho bảng có tên trong `tenant_root`, hoặc cho bảng có tên trong `reference_tables` mà thiếu cột `created_by UUID` hoặc `updated_by UUID`. Method trong `*_service.go` gọi `<repo>.Insert(`, `<repo>.Update(`, hoặc `<repo>.Delete(` với tham số `tx` nhưng trong cùng method không có lời gọi `auditRepo.Record(ctx, tx,`. Method của service hoặc của repository có tham số đầu tiên khác `ctx context.Context`, hoặc dùng `context.Background()`/`context.TODO()` thay vì `ctx` được truyền vào. Handler gọi method service mà không truyền `c.Request.Context()` làm tham số đầu. File `*_handler.go` gọi logger toàn cục (`log.Info(`, `logger.Info(`, `slog.Info(`) thay vì logger dẫn xuất từ `ctx`.
**Cách sửa:** Thêm cột `created_by UUID`, `updated_by UUID` vào migration; thêm lời gọi `auditRepo.Record(ctx, tx, ...)` vào chính method service đang mở transaction, ngay cạnh thao tác ghi; sửa signature method service/repository để nhận `ctx context.Context` làm tham số đầu, và ở handler truyền `c.Request.Context()` xuống thay vì tạo context mới; gắn `request_id` vào `ctx` ở middleware, set header `X-Request-Id` cho mọi response, và trong handler lấy logger dẫn xuất từ `ctx` (ví dụ `log.FromContext(ctx).Info(...)`) thay vì gọi logger toàn cục.
**Ngoại lệ:** Bảng trong `system_tables` miễn toàn bộ. Bảng trong `append_only_tables` có `created_by` nhưng miễn `updated_by`, và thao tác ghi vào bảng đó miễn sinh bản ghi audit. Bảng trong `tenant_root` và bảng trong `reference_tables` **không** được miễn gì ở rule này: có đủ `created_by`, `updated_by`, và mọi thao tác ghi lên chúng vẫn sinh bản ghi audit — bản ghi audit đó mang `company_id` của actor đã ghi, vì `audit_logs` luôn có `company_id` dù bảng bị ghi thì không. Các danh sách nằm ở `04-conventions/C-DB-database.md` mục `C-DB-04`.
**Principles:** P-OBS, P-IDEM
**Decisions:** ADR-0007

> **R-17 khác P-OBS chỗ nào:** R-17 truy vết **dữ liệu nghiệp vụ** — ai sửa bản ghi
> nào, lúc nào, qua request nào; phục vụ người dùng cuối và kiểm toán. P-OBS lo
> **sức khỏe hệ thống** — latency, error rate, span; phục vụ người vận hành.
> Điểm giao duy nhất là `request_id`/`trace_id`: R-17 sở hữu nó, P-OBS chỉ tiêu thụ.

Chi tiết và ví dụ code: [rules/R-17-traceability.md](rules/R-17-traceability.md)

### R-18 — Soft Delete by Default

**Mệnh đề bắt buộc:** DELETE nghiệp vụ là set `deleted_at`, không xóa vật lý. Mọi query đọc **bảng nghiệp vụ**, bảng trong `tenant_root`, hoặc bảng trong `reference_tables` có `deleted_at IS NULL`. Hard delete ba nhóm bảng đó phải có ADR riêng.
**Dấu hiệu vi phạm:** Method repository tên `Delete`/`Remove` trên bảng nghiệp vụ, trên bảng trong `tenant_root`, hoặc trên bảng trong `reference_tables` chứa câu SQL `DELETE FROM <table>` thay vì `UPDATE <table> SET deleted_at = `. Câu SQL `SELECT` trong `*_repository.go` đọc ba nhóm bảng đó nhưng mệnh đề `WHERE` không chứa `deleted_at IS NULL`. Có `DELETE FROM` nhắm vào ba nhóm bảng đó trong migration hoặc repository mà không kèm comment theo mẫu `-- hard-delete: ADR-00xx` ngay tại chỗ.
**Cách sửa:** Đổi câu lệnh xóa thành `UPDATE <table> SET deleted_at = now(), updated_by = $n WHERE id = $m AND deleted_at IS NULL`; thêm `AND deleted_at IS NULL` vào mọi câu `SELECT` đọc bảng nghiệp vụ, bảng trong `tenant_root`, hoặc bảng trong `reference_tables`; nếu bắt buộc phải hard delete, viết ADR mới xin phép trước khi thêm `DELETE FROM`. Bảng có ràng buộc duy nhất trên cột nghiệp vụ phải dùng partial unique index `CREATE UNIQUE INDEX ... ON <table>(company_id, <cột>) WHERE deleted_at IS NULL` thay vì `UNIQUE` thường — nếu không, sau khi xóa mềm sẽ không tạo lại được bản ghi cùng mã; bảng trong `tenant_root` và bảng trong `reference_tables` không có `company_id` nên dùng `ON <table>(<cột>) WHERE deleted_at IS NULL`.
**Ngoại lệ:** Bảng trong `system_tables` và bảng trong `append_only_tables` không có cột `deleted_at` nên nằm ngoài phạm vi rule này; riêng `append_only_tables` được hard delete theo lịch giữ liệu, không cần ADR. Bảng trong `tenant_root` và bảng trong `reference_tables` **không** được miễn: cả hai nhóm có `deleted_at` và chịu soft delete y như bảng nghiệp vụ. Các danh sách nằm ở `04-conventions/C-DB-database.md` mục `C-DB-04`. Hard delete bảng nghiệp vụ, bảng trong `tenant_root`, hoặc bảng trong `reference_tables` chỉ được phép khi có ADR riêng cho phép, comment tại chỗ xóa theo mẫu `-- hard-delete: ADR-00xx`, và ADR được trỏ tới phải có mục liệt kê đúng tên bảng được phép hard delete.
**Principles:** —
**Decisions:** ADR-0008

### R-19 — Business Rules Never in UI

**Mệnh đề bắt buộc:** Frontend cấm tính tiền, thuế, tồn kho, và cấm quyết định trạng thái nào là hợp lệ. Mọi validate nghiệp vụ phải có bản backend; validate ở frontend chỉ là UX.
**Dấu hiệu vi phạm:** File `.ts`/`.tsx` ở frontend đưa kết quả một phép tính tiền/thuế/tồn kho (ví dụ `qty * price`, `subtotal + tax`, `quantity - reserved`) vào body của request `POST`/`PUT` — tham số thứ hai của `axios.post(`/`axios.put(`, hoặc `body` của `fetch(`. Hiển thị con số tạm tính đó lên màn hình **không** vi phạm: form nhập đơn hàng hiện `qty * price` cho người dùng thấy là UX chuẩn mực; chỉ việc gửi con số do frontend tính ngược lên server mới là vi phạm. Component frontend chứa bảng chuyển trạng thái hợp lệ hardcode (ví dụ `const nextStatuses = { pending: ['approved', 'rejected'] }`) dùng để quyết định cho phép hành động.
**Cách sửa:** Bỏ giá trị do frontend tính ra khỏi body request — chỉ gửi đầu vào thô (`quantity`, `unit_price`, `product_id`) và render lại con số backend trả về; màn hình vẫn được hiển thị số tạm tính, chỉ là không gửi nó đi. Chuyển bảng chuyển trạng thái hợp lệ vào service backend; frontend chỉ dựa vào field API trả về (ví dụ `allowed_actions`) để biết bật/tắt nút, không tự suy luận.
**Ngoại lệ:** Không có ngoại lệ.
**Principles:** —
**Decisions:** ADR-0009
