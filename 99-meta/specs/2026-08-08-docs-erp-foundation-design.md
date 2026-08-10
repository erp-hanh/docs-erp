# Design: Repo `docs-erp` — Foundation, ADR, Conventions

> **Đọc sau thì lưu ý:** file này viết lúc ba repo code còn tên `backend`, `frontend`,
> `infra`. Ngày 2026-08-10 chúng đổi thành `backend-erp`, `frontend-erp`, `infra-erp`,
> và thư mục `erp/.specs/` chuyển về `docs-erp/99-meta/specs/`. Mọi đường dẫn và tên
> repo bên dưới giữ nguyên như lúc viết — đây là bản ghi của một thời điểm, không phải
> tài liệu chuẩn mực. Tên hiện hành xem `03-decisions/ADR-0002-multi-repo.md`.

- **Ngày:** 2026-08-08
- **Phạm vi:** Bước 1→3 của lộ trình (Foundation docs → ADR → API/DB convention)
- **Trạng thái:** Chờ duyệt

---

## 1. Mục tiêu

Dựng repo tài liệu gốc `erp/docs-erp/` làm nguồn sự thật duy nhất về quy tắc kiến trúc cho toàn bộ hệ thống ERP, sao cho **AI và người review đều dùng được để phát hiện vi phạm**, không chỉ để đọc tham khảo.

### Trong phạm vi

- `00-START-HERE.md` — index gốc, gộp luôn onboarding
- 19 Architecture Rules ở dạng kiểm được bằng diff
- 7 Architecture Principles, mỗi cái neo xuống ít nhất một hard check
- 6 ADR ghi lại các quyết định đã chốt
- 4 file Conventions (DB, API, Go backend, TS frontend)
- 4 Checklists
- Template docs cho module, template ADR, template migration
- `CLAUDE.md` mẫu cho 3 repo code

### Ngoài phạm vi

| Hạng mục | Lý do hoãn |
|---|---|
| CI enforce rule (import-boundary check, grep rule, migration check) | Cần repo code tồn tại trước — làm ở chặng hạ tầng |
| Testing-Strategy đầy đủ | Chặng này chỉ có `P-TEST`; chiến lược đầy đủ cần biết hình dạng code thật |
| Environment/Config | Thuộc repo `infra` |
| Import-Export, Backup vs Recovery | Chặng vận hành |
| Bất kỳ dòng code Go/TS nào | Chặng này thuần tài liệu |

---

## 2. Các quyết định nền đã chốt

| # | Quyết định |
|---|---|
| 1 | Root là `d:\My project web\erp`. Bốn repo: `docs-erp`, `backend`, `frontend`, `infra` |
| 2 | Docs gốc sống ở repo `docs-erp` trung lập; docs từng module nằm trong repo code tương ứng ("Documentation follows Code") |
| 3 | Cấu trúc numbered sections `00-`..`06-`, có `06-checklists/` |
| 4 | 19 Rules giữ nguyên số lượng; Rule 05 = Events for Decoupling, viết ở dạng binary |
| 5 | Hybrid: `RULES.md` canonical + `rules/` chỉ cho rule cần ví dụ code dài |
| 6 | Stack backend: Gin + pgx/sqlx + golang-migrate |
| 7 | Transaction truyền qua tham số `DBTX`, không qua `context` |
| 8 | Docs viết tiếng Việt, thuật ngữ kỹ thuật giữ tiếng Anh |

---

## 3. Mô hình 5 tầng tài liệu

| Tầng | Vai trò |
|---|---|
| **RULES** | What must be true — bắt buộc, kiểm được |
| **PRINCIPLES** | How we reason — cách suy luận khi áp dụng Rules vào ca phức tạp |
| **DECISIONS** | Why we chose this — quyết định tại một thời điểm, bất biến |
| **CONVENTIONS** | How we consistently implement it — cụ thể đến từng ký tự |
| **CHECKLISTS** | How we verify it |

### Quan hệ

```
        CONVENTIONS ──┐
Code ───┤             ├──> RULES ──> PRINCIPLES ──> DECISIONS
        CHECKLISTS ───┘
```

CONVENTIONS nằm **giữa** Rule và Code, không nối tiếp sau Rule: Rule nói *"FK phải có index"*, Convention nói *"tên index là `idx_<table>_<cols>`"*. CHECKLISTS **cắt ngang**, kiểm cả Rule lẫn Convention.

### Hệ thống ID

Đường truy vết chỉ chạy được nếu mọi thứ có ID ổn định và link ngược tường minh.

| Loại | Định dạng ID | Trường link ngược bắt buộc |
|---|---|---|
| Rule | `R-01`..`R-19` | `Principles:`, `Decisions:` |
| Principle | `P-TXN`, `P-ERR`, ... | `Rules:`, `Decisions:` |
| ADR | `ADR-0001`.. | `Constrains:` (rule nào sinh ra từ nó) |
| Convention | `C-DB-01`, `C-API-01`, ... | `Implements:` |
| Checklist item | `CL-NEWMOD-01`, ... | `Verifies:` |

Khi AI báo vi phạm, output chỉ cần trả `R-05` là tra ngược được toàn chuỗi.

### Ranh giới ADR ↔ Principle

- **ADR bất biến.** Có `Status: Accepted (ngày) | Superseded by ADR-00xx`. Không sửa nội dung đã Accepted — muốn đổi thì viết ADR mới.
- **Principle sống.** Cập nhật tự do.

Sai chỗ này thì người ta sửa ADR cũ và mất sạch giá trị lịch sử.

---

## 4. Cấu trúc thư mục

```
erp/docs-erp/
├── 00-START-HERE.md
├── 01-rules/
│   ├── RULES.md
│   └── rules/
│       ├── R-01-module-boundary.md
│       ├── R-05-events-for-decoupling.md
│       ├── R-06-tenant-column.md
│       ├── R-09-index-by-design.md
│       └── R-17-traceability.md
├── 02-principles/
│   ├── PRINCIPLES.md
│   ├── P-TXN-transaction-boundary.md
│   ├── P-ERR-error-handling.md
│   ├── P-TEST-testing.md
│   ├── P-IDEM-idempotency.md
│   ├── P-OBS-observability.md
│   ├── P-CONC-concurrency.md
│   └── P-EVT-events.md
├── 03-decisions/
│   ├── README.md
│   ├── ADR-0001-modular-monolith.md
│   ├── ADR-0002-multi-repo.md
│   ├── ADR-0003-multi-tenant-ready.md
│   ├── ADR-0004-khong-tich-hop-iot-plc.md
│   ├── ADR-0005-documentation-follows-code.md
│   ├── ADR-0006-event-bus-outbox.md
│   ├── ADR-0007-traceability-bat-buoc.md
│   ├── ADR-0008-soft-delete-by-default.md
│   └── ADR-0009-business-rule-chi-o-backend.md
├── 04-conventions/
│   ├── C-DB-database.md
│   ├── C-API-http.md
│   ├── C-GO-backend.md
│   └── C-TS-frontend.md
├── 05-templates/
│   ├── module-docs/
│   │   ├── README.md
│   │   ├── Database.md
│   │   ├── Workflow.md
│   │   ├── Permission.md
│   │   └── Events.md
│   ├── ADR-template.md
│   ├── migration-template.sql
│   ├── module.yaml.template
│   └── CLAUDE.md.template
├── 06-checklists/
│   ├── CL-NEWMOD-new-module.md
│   ├── CL-SCHEMA-schema-change.md
│   ├── CL-API-new-endpoint.md
│   └── CL-PR-code-review.md
├── tools/
│   └── check-ids.ps1
└── README.md
```

`tools/check-ids.ps1` kiểm chéo hai chiều toàn bộ mạng lưới ID: fail khi có ID được tham chiếu nhưng không tồn tại, hoặc khi một Rule thiếu trường link ngược. Đây là thứ giữ cho hệ thống ID khỏi mục dần — không có nó, mục 12 chỉ là lời hứa.

Chỉ 5 rule được tách file riêng trong `01-rules/rules/` — những rule cần ví dụ code dài. 14 rule còn lại nằm trọn trong `RULES.md`.

---

## 5. 19 Architecture Rules

### Khuôn mỗi entry trong `RULES.md`

```
### R-05 — Events for Decoupling
Mệnh đề bắt buộc: <phát biểu binary, trả lời được Có/Không khi nhìn diff>
Dấu hiệu vi phạm:  <mẫu code/SQL cụ thể để grep>
Cách sửa:          <hành động cụ thể>
Ngoại lệ:          <có, hoặc "Không có ngoại lệ">
Principles: P-EVT
Decisions:  ADR-0006
```

### Nhóm A — Module Boundary

| ID | Mệnh đề bắt buộc | Decisions |
|---|---|---|
| **R-01** Module Boundary | `modules/<A>/internal/` chỉ được import bởi chính A. Module khác chỉ import `modules/<A>/api/` (interface + DTO) | ADR-0001 |
| **R-02** No Cross-Module DB Access | Repository của A chỉ query bảng nằm trong danh sách `tables` khai báo ở `module.yaml` của A. Cấm JOIN sang bảng module khác | ADR-0001 |
| **R-03** Layered Structure | Handler cấm import `pgx`/`sqlx`; service cấm import `gin`/`net/http`; repository cấm chứa `if` nghiệp vụ | ADR-0001 |
| **R-04** Dependency Direction | `shared/` cấm import `modules/`. Import graph giữa các module không có chu trình | ADR-0001 |
| **R-05** Events for Decoupling | (xem dưới) | ADR-0006 |

**R-05 phát biểu đầy đủ** — gồm 4 mệnh đề, đều grep được:

1. Service của A chỉ gọi đồng bộ sang module có tên trong `allowed_deps` của `module.yaml` thuộc A; ngoài danh sách phải đi qua event.
2. Chỉ service được ghi outbox. Handler và repository cấm.
3. Service **ghi event vào bảng `outbox` trong cùng transaction** với dữ liệu nghiệp vụ.
4. Service cấm gọi event bus trực tiếp bên trong transaction, kể cả qua `defer`. Việc **publish ra bus xảy ra sau commit**, do relay riêng đọc `outbox`.

Vì relay là **at-least-once**, `P-IDEM` (handler idempotent theo `event_id`) là điều kiện bắt buộc để ADR-0006 đứng vững, không phải tùy chọn.

### Nhóm B — Database

| ID | Mệnh đề bắt buộc | Decisions |
|---|---|---|
| **R-06** Tenant Column Everywhere | Mọi bảng nghiệp vụ có `company_id UUID NOT NULL`; mọi query repository có `company_id = $n` trong WHERE. Bảng hệ thống được miễn phải liệt kê tường minh trong `C-DB` | ADR-0003 |
| **R-07** Migration Only | Schema chỉ đổi qua file `migrations/` đánh số tăng dần, có `up`+`down`. Cấm sửa migration đã merge — sai thì viết migration mới | — |
| **R-08** Naming Convention | Bảng snake_case số nhiều; PK `id UUID`; FK `<singular>_id`; mọi bảng nghiệp vụ có `created_at`, `updated_at`, `deleted_at` | — |
| **R-09** Index by Design | Mọi FK có index; mọi cột xuất hiện trong WHERE/ORDER BY của repository có index; tên index `idx_<table>_<cols>` | — |

**Định nghĩa "bảng nghiệp vụ"** — cụm này xuất hiện ở R-06, R-08, R-17, R-18 nên phải chốt một lần trong `C-DB`:

> Bảng nghiệp vụ là mọi bảng **trừ** những bảng nằm trong danh sách `system_tables` khai báo tường minh ở `C-DB`.

Danh sách `system_tables` khởi đầu: `schema_migrations`, `companies`. Hai bảng này được miễn `company_id`, `deleted_at`, và các cột audit của R-17.

Bảng `outbox` **không** thuộc `system_tables`: nó có `company_id` (để relay lọc theo tenant) nhưng được miễn `deleted_at` — ghi rõ ngoại lệ này trong `C-DB`, vì event đã publish thì xóa cứng sau khi hết hạn lưu, không soft delete.

### Nhóm C — API

| ID | Mệnh đề bắt buộc |
|---|---|
| **R-10** RESTful Resource | Path chỉ chứa danh từ số nhiều + id, cấm động từ (`/getUser`, `/createOrder`). POST tạo mới → 201, DELETE → 204, lỗi validate → 422 |
| **R-11** Consistent Response Envelope | Mọi response đi qua struct envelope trong `shared/response`. Handler cấm `c.JSON` với map hoặc struct tự chế |
| **R-12** List Query Standard | Endpoint list nhận `page`, `page_size`, `sort`; response có `meta.total`, `meta.page`, `meta.page_size`. Cấm trả mảng trần |
| **R-13** API Versioning | Mọi route dưới `/api/v1`. Xóa field, đổi kiểu, đổi ý nghĩa → bắt buộc `/api/v2` |

### Nhóm D — Security

| ID | Mệnh đề bắt buộc |
|---|---|
| **R-14** Auth at Middleware | JWT verify chỉ tồn tại trong `shared/middleware/auth`. Handler và service cấm đọc header `Authorization` hoặc parse token |
| **R-15** Permission Check in Service | Mọi method public của service mở đầu bằng lời gọi kiểm quyền. Handler cấm chứa logic quyền; ẩn nút ở frontend không tính là kiểm quyền — `Decisions: ADR-0009` |
| **R-16** Never Expose Secrets | Cấm log hoặc serialize password hash, token, secret, CCCD. Struct có field nhạy cảm phải gắn `json:"-"` |

### Nhóm E — Business/Data

| ID | Mệnh đề bắt buộc | Decisions |
|---|---|---|
| **R-17** Traceability | Mọi bảng nghiệp vụ có `created_by`, `updated_by`; mọi thao tác ghi sinh bản ghi audit; `request_id` có mặt trong log và response; `ctx` truyền xuyên suốt handler→service→repository | ADR-0007 |
| **R-18** Soft Delete by Default | DELETE nghiệp vụ = set `deleted_at`. Mọi query đọc có `deleted_at IS NULL`. Hard delete phải có ADR | ADR-0008 |
| **R-19** Business Rules Never in UI | Frontend cấm tính tiền/thuế/tồn kho và cấm quyết định trạng thái hợp lệ. Mọi validate nghiệp vụ phải có bản backend; validate frontend chỉ là UX | ADR-0009 |

### Hai artifact mà Rules phụ thuộc

- **`module.yaml`** — mỗi module có một file, khai báo `tables` và `allowed_deps`. Không có nó thì R-02 và R-05 không kiểm được bằng máy. Template ở `05-templates/module.yaml.template`.
- **Bảng `outbox`** — không có thì event mất khi transaction rollback. Schema chốt trong `C-DB`.

---

## 6. 7 Architecture Principles

| ID | Câu hỏi nó trả lời | Hard check | Neo vào |
|---|---|---|---|
| **P-TXN** Transaction Boundary | Ai mở transaction, đóng ở đâu, khi nào cần? | Service mở/đóng transaction; repository nhận `DBTX` qua tham số, cấm `Begin`/`Commit`/`Rollback`. Một request ghi = một transaction | R-03, R-05 |
| **P-ERR** Error Handling | Lỗi nào wrap, nào trả client, nào chỉ log? | Cấm `_ = err`; cấm `panic` ngoài `main`; lỗi trả client phải đi qua bảng mã lỗi trong `shared/errors` | R-11 |
| **P-TEST** Testing | Test cái gì, mock cái gì, bao nhiêu là đủ? | Mọi method public của service có ≥1 test; repository test chạy trên Postgres thật (testcontainers), cấm mock SQL | skill `unit-test` |
| **P-IDEM** Idempotency | Thao tác nào bắt buộc idempotent? | POST sinh bút toán tiền/kho/chứng từ phải nhận `Idempotency-Key`; mọi event handler idempotent theo `event_id` | R-05, R-17, ADR-0006 |
| **P-OBS** Observability | Đo gì, log mức nào? | Mọi handler có trace span; mọi lời gọi ra ngoài (DB, Redis, HTTP) có metric latency + error count | — |
| **P-CONC** Concurrency | Chỗ nào tranh chấp, khóa kiểu gì? | Update tồn kho / số dư / số chứng từ phải `SELECT FOR UPDATE` hoặc optimistic `version`; cấm read-modify-write không khóa | P-TXN, R-09 |
| **P-EVT** Events | Khi nào chọn event thay vì gọi trực tiếp? | Payload immutable, có `event_id` + `occurred_at` + `company_id`; cấm nhét nguyên entity vào payload | R-05, R-08, ADR-0006 |

### Ranh giới chống trùng lặp

**R-17 ↔ P-OBS**
- R-17 Traceability = truy vết **dữ liệu nghiệp vụ** — ai sửa bản ghi nào, lúc nào, qua request nào. Phục vụ người dùng cuối và kiểm toán.
- P-OBS Observability = sức khỏe **hệ thống** — latency, error rate, span. Phục vụ người vận hành.
- Điểm giao duy nhất là `request_id`/`trace_id`: R-17 sở hữu, P-OBS chỉ tiêu thụ. P-OBS cấm định nghĩa lại.

**R-05 ↔ P-EVT**
- R-05 nói *được phép gọi ai* — kiểm bằng máy.
- P-EVT nói *khi nào nên chọn event* — judgement.

**P-TXN ↔ C-GO**
- P-TXN nói *khi nào cần transaction, phạm vi tới đâu, lỗi giữa chừng xử lý sao*.
- C-GO nói *viết thế nào trong Go* — chữ ký hàm, tên interface.

---

## 7. ADR

### Template

```
# ADR-0003: Multi-tenant-ready bằng shared database + company_id
Status:       Accepted (2026-08-08)
Context:      <bối cảnh và ràng buộc lúc quyết>
Decision:     <quyết cái gì, một câu>
Alternatives: <đã cân nhắc gì, vì sao loại>
Consequences: <được gì, mất gì, nợ kỹ thuật để lại>
Constrains:   R-06
```

### 6 ADR viết ngay

| ID | Quyết định | Constrains |
|---|---|---|
| ADR-0001 | Modular Monolith thay vì microservices | R-01, R-02, R-03, R-04 |
| ADR-0002 | Multi-repo: `docs-erp` / `backend` / `frontend` / `infra` | — |
| ADR-0003 | Multi-tenant-ready: shared DB + `company_id`; chưa làm database-per-tenant | R-06 |
| ADR-0004 | Không tích hợp IoT/PLC — Machine, Kalmar là module CRUD thường | — |
| ADR-0005 | Documentation follows Code — docs module nằm trong repo code, docs gốc chỉ giữ quy tắc chung | — |
| ADR-0006 | Event bus nội bộ + outbox table; publish sau commit, relay at-least-once | R-05 |
| ADR-0007 | Traceability bắt buộc: audit đầy đủ cho mọi thao tác ghi, `request_id` xuyên suốt | R-17 |
| ADR-0008 | Soft Delete by Default: xóa nghiệp vụ là đánh dấu, không xóa vật lý | R-18 |
| ADR-0009 | Backend là nơi duy nhất giữ business rule; frontend không được tin | R-19, R-15 |

ADR-0004 nghe như "không làm gì" nên dễ bị bỏ qua, nhưng chính nó chặn việc sáu tháng nữa có người mở lại cuộc tranh luận tích hợp thiết bị.

ADR-0007, 0008, 0009 tách riêng cho R-17, R-18, R-19 vì đây là ba quyết định độc lập, mỗi cái có phương án thay thế riêng đã bị loại. Không gộp chúng vào ADR-0003 hay vào nhau — gán một Rule vào ADR không thực sự sinh ra nó chỉ để "đủ chuỗi" là làm giả traceability.

ADR-0009 constrains cả R-15 vì kiểm quyền ở service là hệ quả trực tiếp của cùng một quyết định "không tin frontend" — đây là quan hệ thật, không phải gán ép.

**Rule không truy về ADR nào:** R-07, R-08, R-09 (nhóm Database) và R-10..R-14, R-16 (API, Security) ghi `Decisions: —` kèm lý do *"quy ước nền, không phát sinh từ một quyết định có phương án thay thế đáng ghi"*.

Chuỗi của ADR-0006: `ADR-0006 → P-EVT → R-05 → C-GO → implementation`.

---

## 8. Conventions

| File | Chốt những gì |
|---|---|
| `C-DB-database.md` | Tên bảng/cột; kiểu chuẩn (tiền `NUMERIC(18,4)`, thời gian `TIMESTAMPTZ`); bộ cột bắt buộc; quy tắc đặt tên index và constraint; cách viết migration; danh sách bảng miễn `company_id`; schema bảng `outbox` |
| `C-API-http.md` | Cấu trúc URL; mã status theo tình huống; struct envelope; tham số phân trang/sắp xếp/lọc; bảng mã lỗi nghiệp vụ; quy tắc versioning |
| `C-GO-backend.md` | Layout package một module; đặt tên file/interface; wrap error; **Transaction Ownership**; nội dung `module.yaml` |
| `C-TS-frontend.md` | Layout module frontend; đặt tên component/hook; quản lý state; xử lý form và hiển thị lỗi từ envelope; ẩn/hiện theo quyền |

### C-GO — Transaction Ownership (chốt tường minh)

```
Handler
   ↓
Service
   ├── BEGIN
   ├── Repository A   (nhận DBTX)
   ├── Repository B   (nhận DBTX)
   ├── Outbox Repository (nhận DBTX)
   └── COMMIT
                ↓ (sau commit)
        Relay đọc outbox → publish ra bus
```

Ba mệnh đề bắt buộc:

1. **Service owns transaction boundary.**
2. **Repository không `BEGIN`/`COMMIT`/`ROLLBACK`** transaction nghiệp vụ.
3. **Repository nhận `DBTX` qua tham số**, không lấy từ `context`.

`DBTX` là interface gồm các method dùng chung của `*sqlx.DB` và `*sqlx.Tx` (`QueryContext`, `QueryRowContext`, `ExecContext`, `GetContext`, `SelectContext`).

Chọn truyền qua tham số vì chữ ký hàm tự tố cáo vi phạm — grep là biết repository có tự mở transaction hay không. Nếu truyền qua `context`, quên truyền thì code vẫn chạy, chỉ là chạy ngoài transaction mà không báo lỗi.

---

## 9. Checklists

Bốn file, mỗi dòng mang `Verifies: R-xx` hoặc `C-xx-xx`:

| File | Dùng khi |
|---|---|
| `CL-NEWMOD-new-module.md` | Thêm module mới |
| `CL-SCHEMA-schema-change.md` | Đổi schema |
| `CL-API-new-endpoint.md` | Thêm endpoint |
| `CL-PR-code-review.md` | Review PR |

---

## 10. `00-START-HERE.md`

Năm phần, gộp luôn onboarding:

1. **Hệ thống này là gì** — 3 câu, không dài hơn
2. **Bản đồ 5 tầng tài liệu** + sơ đồ truy vết ngược
3. **Bảng định tuyến "tôi cần làm X thì đọc gì"**

| Việc | Đọc |
|---|---|
| Thêm module mới | `CL-NEWMOD` → R-01..R-05 → template `module-docs/` |
| Sửa schema | `CL-SCHEMA` → R-06..R-09 → `C-DB` |
| Thêm endpoint | `CL-API` → R-10..R-13 → `C-API` |
| Review PR | `CL-PR` |
| Không hiểu vì sao có quy tắc này | `03-decisions/` |

4. **Thứ tự ưu tiên khi xung đột**

```
Rules > Principles > Conventions > existing code
```

Kèm hai dòng bắt buộc:

- **Nếu hai Rule mâu thuẫn nhau thì dừng lại hỏi người, không tự chọn bên.** Không có dòng này, AI sẽ tự diễn giải rồi tạo tiền lệ sai.
- **Khi Principle thắng Convention trong một ca cụ thể, bắt buộc mở issue sửa Convention.** Thứ tự ưu tiên là chỉ dẫn tạm thời cho tới khi tầng dưới được sửa cho khớp, không phải giấy phép bỏ qua nó.

5. **30 phút đầu của người mới đọc gì**

---

## 11. Enforcement

| Tầng | Cơ chế | Trong scope |
|---|---|---|
| 1 | `CLAUDE.md` ở mỗi repo code, trỏ về `docs-erp` + liệt kê rule hay bị vi phạm nhất của riêng repo đó | Có |
| 2 | Checklist nhúng vào PR template | Có |
| 3 | CI thật: import-boundary check, grep rule cho R-11/R-14/R-16, migration check R-08/R-09 | Không |

Tầng 1–2 dựa vào con người và AI đọc docs, nên vẫn lọt. Tầng 3 mới là thứ chặn thật, nhưng nó cần repo code đã tồn tại — đây là **nợ kỹ thuật có chủ đích**, ghi vào roadmap chặng hạ tầng.

---

## 12. Định nghĩa hoàn thành

- [ ] `docs-erp` là git repo, có commit đầu
- [ ] Đủ các file trong cây thư mục ở mục 4, không file nào còn placeholder
- [ ] 19 Rule đều có đủ 4 trường (Mệnh đề / Dấu hiệu vi phạm / Cách sửa / Ngoại lệ) + link `Principles:` và `Decisions:`
- [ ] Mọi Rule truy ngược được về ít nhất một ADR, hoặc ghi rõ `Decisions: —` kèm lý do
- [ ] 7 Principle đều có ít nhất một hard check cụ thể
- [ ] 6 ADR đều có `Status` và `Constrains`
- [ ] Mọi dòng checklist đều có `Verifies:` trỏ tới ID có thật
- [ ] Không có ID nào bị trỏ mà không tồn tại (kiểm tra chéo hai chiều)
- [ ] `CLAUDE.md.template` dùng được ngay cho cả 3 repo code

## 13. Rủi ro

| Rủi ro | Giảm thiểu |
|---|---|
| Docs viết xong rồi không ai đọc | Bảng định tuyến ở START-HERE + `CLAUDE.md` ở mỗi repo code là điểm vào bắt buộc |
| Rule không kiểm được bằng máy nên bị bỏ qua | Mọi Rule phát biểu ở dạng binary ngay từ đầu; tầng 3 CI là nợ đã ghi nhận |
| ADR và Principle nói cùng một chuyện | Ranh giới bất biến/sống đã chốt ở mục 3 |
| `module.yaml` không được cập nhật khi module đổi | `CL-NEWMOD` và `CL-PR` đều có dòng kiểm |
| Convention chết dần vì ai cũng viện Principle | Quy tắc bắt buộc mở issue sửa Convention ở mục 10 |
