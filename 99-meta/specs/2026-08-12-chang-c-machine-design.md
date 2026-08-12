# Chặng C — module `machine`, quan hệ liên module đầu tiên

**Trạng thái:** Đã duyệt · 2026-08-12
**Tiền đề:** Chặng B đóng với `arch/LEVELS.md` không còn dòng `PASS tren tap RONG`, bốn món nợ đã giải, CI ba job xanh trên `9c933b2`.

---

## 1. Mục tiêu, đo được

Hệ thống có **hai** module, và cạnh nối giữa chúng là một cạnh thật:

```
modules/auth/module.yaml     allowed_deps: []
modules/machine/module.yaml  allowed_deps: [auth]
```

Sáu vế rule dưới đây hôm nay đang `PASS` trên tập không có gì để soi, và chặng này là lần đầu chúng gặp code thật:

| Vế | Hôm nay | Sau chặng C |
|---|---|---|
| R-01 — ba nhánh vi phạm + nhánh `api/` hợp lệ | Chỉ nhánh `fromCmd` từng chạy | `machine` import `erp/modules/auth/api` |
| R-02 — JOIN sang bảng của module khác | Không tồn tại bảng "của module khác" | `machines` và `users` thuộc hai module |
| R-04 vế 2 — chu trình hai nút trong `allowed_deps` | Một nút, không cạnh nào | Hai nút, một cạnh có hướng |
| R-05 vế 1 — gọi đồng bộ ngoài `allowed_deps` | Cần `module.yaml` của cả hai phía | Có cả hai |
| R-15 — đối chiếu `internal_methods` | Một module | Hai, và chỉ một có `Internal*` |
| C-GO-05 vế 1 — module có `module.go` phải có `module.yaml` | Một module | Hai |

**Phép thử của mục tiêu này không phải là "test xanh".** Nó là: đổi `allowed_deps` của `machine` thành `[]` rồi chạy `go run ./cmd/dev arch` — phải có thứ gì đó đỏ. Chặng A đã cho thấy một checker chạy trên tập rỗng thì xanh y hệt một checker đang canh thật, và bảy dòng `PASS tren tap RONG` đã sống sót qua cả một chặng vì không ai hỏi câu đó.

---

## 2. Phạm vi

**Làm:**

| Thành phần | Lý do bắt buộc |
|---|---|
| `migrations/000006..000008` — `machines`, `maintenance_plans`, `breakdowns` | Ba bảng của lý lịch máy, kế hoạch bảo trì, nhật ký sự cố (ADR-0004) |
| `modules/auth/api/` — thêm interface `UserReader` | Đường hợp lệ **duy nhất** để module khác hỏi về một user (R-01) |
| `modules/machine/**` | Module nghiệp vụ thứ hai |
| `shared/errors` — `ERR_MACHINE_*` | Mã là hợp đồng; khai hằng trước khi service dùng (C-API-05) |
| `cmd/internal/vaitro` — permission mới vào bảng vai trò | Một permission không vai trò nào cấp được là một quyền im lặng (C-GO-08) |
| `docs-erp` — bảng mã lỗi, sổ đăng ký C-API-07 bảng 1 | Endpoint `/actions/<verb>` chỉ có hiệu lực khi có dòng trong sổ |

**KHÔNG làm, và lý do:**

`shared/outbox`, `shared/bus`, `relay/` — vẫn hoãn, và lý do đã đổi so với chặng B. Chặng B hoãn vì **không có nhu cầu cross-module nào**; chặng C có nhu cầu đó nhưng nó là nhu cầu **đồng bộ**: `machine` hỏi `auth` xem một user có tồn tại không, và nếu `auth` hỏng thì việc gán người phụ trách **không** được coi là đã xong. Đó đúng là phép thử của P-EVT, và câu trả lời "không" nghĩa là gọi đồng bộ, không phải event. Dựng outbox lúc này vẫn là dựng một đường ống không có nước chảy qua — chỉ khác là giờ ta biết chính xác nước sẽ đến từ đâu: module thứ ba nào cần *nghe* một việc đã xảy ra ở `machine`.

Kalmar — cùng ADR-0004 với Machine, nhưng ADR-0001 ghi rõ chưa ai trả lời được Machine và Kalmar là một miền hay hai. Gộp chúng lúc này là chốt một ranh giới bằng phỏng đoán; tách chúng là dựng hai module cho một tập nghiệp vụ chưa ai dùng thật. Xe nâng ở cảng vào `machines` như một dòng dữ liệu bình thường cho tới khi có nghiệp vụ nào đó **chỉ** đúng cho nó.

Import CSV/Excel — ADR-0004 nói dữ liệu vận hành vào bằng nhập tay hoặc import file, và L109-111 của chính nó thừa nhận **chưa có quy ước định dạng file**. Endpoint import là một hợp đồng công khai; chốt nó khi chưa biết file thật trông thế nào là chốt sai. Chặng này chỉ mở đường nhập tay qua `/api/v1`.

Bảng `currencies` và `units` — có tên trong registry C-DB-04 nhưng **chưa có migration nào tạo**. Chi phí sửa chữa lưu `NUMERIC(18,4)` trần, không kèm `currency_id`: hệ thống hiện chạy một đơn vị tiền tệ, và một khóa ngoại trỏ tới bảng chưa tồn tại là một cột không ghi được. Ngày có đồng tiền thứ hai, thêm cột bằng migration mới (R-07).

Cấp số chứng từ cho phiếu bảo trì — `document_counters` chưa được phân nhóm bảng, và ADR-0003 nói việc đó **đòi một ADR riêng** khi module đầu tiên cần cấp số. `maintenance_plans` dùng mã do người nhập đặt, duy nhất theo công ty; nó không phải số chứng từ liên tục.

---

## 3. Vì sao module thứ hai đi trước hạ tầng event

Lộ trình gốc xếp chặng C là `shared/outbox` + `relay/`. Đảo lại thứ tự đó là một quyết định, nên nó phải có lý do đứng được.

Lý do là **outbox không kiểm được bằng chính nó**. Một bảng `outbox` không ai ghi vào và một `relay/` không có gì để đọc sẽ chạy xanh mọi lần, y hệt cách bảy dòng `PASS tren tap RONG` từng xanh. Ngược lại, `checkR05` vế 3 — "`Append` có cùng transaction với dữ liệu nghiệp vụ hay không" — là vế **không** kiểm được bằng máy (cần data-flow), nên thứ duy nhất chứng minh nó đúng là một service thật ghi outbox trong một transaction thật, cho một consumer thật.

Đổi lại, module thứ hai kiểm được ngay bằng thứ đã có: sáu vế ở mục 1 đều có checker sẵn, đang chờ đúng một hình dạng code chưa từng tồn tại.

Hệ quả phải chấp nhận: `relay` vẫn nằm trong `Scope.Optional` ở ba chỗ của `arch/internal/loader/loader.go`, và `TestOptionalRootStaysHonest` vẫn xanh vì `relay/` vẫn rỗng. Cơ chế đó chưa nổ ở chặng này, và nó **đúng** khi chưa nổ.

---

## 4. Hợp đồng liên module

### 4.1 `modules/auth/api` — `UserReader`

```go
// UserReader la duong DUY NHAT module khac hoi ve mot user.
type UserReader interface {
	GetByID(ctx context.Context, actor auth.Actor, id string) (*UserDTO, error)
}
```

Ba điều nằm ở chữ ký chứ không ở thân hàm.

**Nhận `actor` làm tham số thứ hai, và lời gọi chịu kiểm quyền như mọi lời gọi khác.** Cài đặt của nó là `UserService.GetUser`, method đã mở đầu bằng `s.authz.Can(ctx, actor, PermUserRead)` từ chặng B. Nghĩa đen: ai xem được một `machine` có người phụ trách thì phải có `auth.user_read`. Đó là hệ quả thật và phải nói ra ở `Permission.md` của cả hai module — không phải một chi tiết kỹ thuật.

**Trả `*UserDTO`, không trả `*model.User`.** DTO đã tồn tại từ chặng B và cố ý không mang `password_hash`, `company_id`, `deleted_at`. Đây là lần đầu nó có người dùng thật; nếu hình dạng đó sai thì bây giờ là lúc biết.

**Tên không mang tiền tố `Internal`.** Ngoại lệ `Internal*` của R-15 cấm tên đó xuất hiện trong bất kỳ interface nào dưới `modules/*/api/`, và `C-GO-05` vế 5 canh đúng điều đó.

Cách nó tới tay `machine`: composition root lấy từ `auth.Module` rồi tiêm vào `machine.New` — cùng khuôn C-GO-01 mà `authz.Checker` và `audit.Repository` đã đi.

```go
// cmd/api/main.go
moduleAuth := auth.New(auth.Deps{...})
moduleMachine := machine.New(machine.Deps{
	DB: db, Authz: kiemQuyen, Audit: ghiAudit,
	Users: moduleAuth.UserReader(),
})
```

### 4.2 Vì sao `machines.assigned_to` không có khóa ngoại

Cột trỏ tới một user, nhưng **không** khai `REFERENCES users(id)`. Lý do không phải tiện tay: một khóa ngoại là một quan hệ ở tầng schema, mà R-02 cấm repository của `machine` nêu tên bảng `users` trong bất kỳ câu SQL nào. Khai khóa ngoại rồi không được JOIN qua nó là dựng một quan hệ chỉ database nhìn thấy còn code thì không — và nó sẽ mời người sau viết đúng cái JOIN mà rule cấm.

Ràng buộc "người phụ trách phải là user còn sống trong cùng công ty" được giữ ở **service**, bằng một lời gọi `UserReader.GetByID` trước khi ghi. Nếu `auth` không trả lời được thì việc gán không được coi là đã xong — đó là phép thử của P-EVT cho câu hỏi đồng bộ hay event, và câu trả lời ở đây là đồng bộ.

Cùng lý do đó áp cho `created_by`/`updated_by`, nhưng chúng còn một lý do mạnh hơn đã có sẵn ở C-DB-03: dấu vết audit phải sống sót khi user bị xóa.

---

## 5. Schema

Ba bảng đều là **bảng nghiệp vụ** — không tên nào có trong bốn danh sách miễn trừ của C-DB-04 — nên cả ba mang đủ `company_id`, ba cột thời gian, hai cột audit, và chịu soft delete. Cả ba tên kết thúc bằng `s` nên không cần ADR bổ sung `naming_exempt`.

```sql
-- 000006_create_machines.up.sql
machines(
  id, company_id,
  code TEXT NOT NULL,            -- ma may, duy nhat trong cong ty
  name TEXT NOT NULL,
  kind TEXT NOT NULL,            -- cnc | cat | han | xe_nang, CHECK
  location TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'hoat_dong',   -- CHECK
  assigned_to UUID,              -- user phu trach; KHONG khoa ngoai, xem muc 4.2
  commissioned_date DATE,          -- ngay dua vao su dung
  created_at, updated_at, deleted_at, created_by, updated_by)

uq_machines_company_id_code       (company_id, code) WHERE deleted_at IS NULL
idx_machines_company_id_status    (company_id, status) WHERE deleted_at IS NULL
idx_machines_company_id_created_at (company_id, created_at) WHERE deleted_at IS NULL
ck_machines_status                CHECK (status IN ('hoat_dong','bao_tri','ngung'))
ck_machines_kind                  CHECK (kind IN ('cnc','cat','han','xe_nang'))
```

`kind` là `TEXT` + `CHECK` chứ không phải bảng tham chiếu: tập giá trị do lập trình viên quyết và đổi bằng migration, còn một bảng tham chiếu là thứ **người dùng** thêm được. Chưa có màn hình nào cho người dùng thêm loại máy, nên bảng tham chiếu lúc này là một bảng không ai ghi.

`assigned_to` không có index: không truy vấn nào lọc theo nó ở chặng này. Nó **không** phải khóa ngoại nên R-09 không đòi.

```sql
-- 000007_create_maintenance_plans.up.sql
maintenance_plans(
  id, company_id,
  machine_id UUID NOT NULL REFERENCES machines(id),
  code TEXT NOT NULL,
  planned_date DATE NOT NULL,
  status TEXT NOT NULL DEFAULT 'ke_hoach',    -- CHECK
  note TEXT NOT NULL DEFAULT '',
  started_at TIMESTAMPTZ, completed_at TIMESTAMPTZ,
  created_at, updated_at, deleted_at, created_by, updated_by)

uq_maintenance_plans_company_id_code       (company_id, code) WHERE deleted_at IS NULL
idx_maintenance_plans_company_id_machine_id (company_id, machine_id) WHERE deleted_at IS NULL
idx_maintenance_plans_company_id_planned_date (company_id, planned_date) WHERE deleted_at IS NULL
ck_maintenance_plans_status CHECK (status IN ('ke_hoach','dang_lam','hoan_thanh','huy'))
```

`machine_id` là khóa ngoại khác `company_id` nên R-09 đòi nó là cột thứ hai của một index composite mở đầu bằng `company_id` — `idx_maintenance_plans_company_id_machine_id` phục vụ đúng câu "mọi kế hoạch của một máy".

```sql
-- 000008_create_breakdowns.up.sql
breakdowns(
  id, company_id,
  machine_id UUID NOT NULL REFERENCES machines(id),
  occurred_at TIMESTAMPTZ NOT NULL,
  description TEXT NOT NULL,
  repair_cost NUMERIC(18,4) NOT NULL DEFAULT 0,
  created_at, updated_at, deleted_at, created_by, updated_by)

idx_breakdowns_company_id_machine_id  (company_id, machine_id) WHERE deleted_at IS NULL
idx_breakdowns_company_id_occurred_at (company_id, occurred_at) WHERE deleted_at IS NULL
ck_breakdowns_repair_cost_non_negative CHECK (repair_cost >= 0)
```

`repair_cost` là `NUMERIC(18,4)` theo C-DB-02, đi ra JSON dưới dạng **chuỗi** (`"1500000.0000"`) và ở Go là `decimal.Decimal`. Đây là chỗ chặng C thêm phụ thuộc `github.com/shopspring/decimal` — thư viện mà C-GO-backend đã chốt nhưng repo chưa từng cần tới.

`breakdowns` **không** có `status`: một sự cố đã ghi là một sự việc đã xảy ra, không phải một quy trình. Chi phí sửa chữa là một cột chứ không phải bảng dòng chi phí — tách dòng là việc của một module tài chính chưa tồn tại, và một bảng con chỉ để giữ một con số là một bảng phải giữ mãi.

---

## 6. Module `machine`

```text
modules/machine/
├── api/dto.go                    MachineDTO - hop dong cho module sau
├── internal/
│   ├── model/                    machine.go, maintenance_plan.go, breakdown.go
│   ├── repository/               ba repository, SQL hang chuoi don (C-GO-07)
│   ├── service/                  machine_service.go, maintenance_service.go,
│   │                             breakdown_service.go, permissions.go
│   └── handler/                  ba handler + ba file route
├── module.go                     New/Register, xuat lai permission (C-GO-08)
└── module.yaml                   tables, allowed_deps: [auth], internal_methods: []
```

`internal_methods` **rỗng**: không service nào của `machine` gọi service khác trong cùng module ở chặng này. Khai rỗng chứ không bỏ trường — `C-GO-05` đối chiếu hai chiều, và một tên thừa ở đó cũng là vi phạm y như một tên thiếu.

**Method và kiểm quyền** — mọi dòng đều mở đầu bằng `s.authz.Can` (R-15):

| Service | Method | Permission | Endpoint |
|---|---|---|---|
| `MachineService` | `ListMachines` | `machine.list` | `GET /api/v1/machines` |
| | `GetMachine` | `machine.read` | `GET /api/v1/machines/:id` |
| | `CreateMachine` | `machine.create` | `POST /api/v1/machines` |
| | `UpdateMachine` | `machine.update` | `PATCH /api/v1/machines/:id` |
| | `DeleteMachine` | `machine.delete` | `DELETE /api/v1/machines/:id` |
| `MaintenanceService` | `ListPlans` | `machine.plan_list` | `GET /api/v1/maintenance-plans` |
| | `ListPlansByMachine` | `machine.plan_list` | `GET /api/v1/machines/:id/maintenance-plans` |
| | `GetPlan` | `machine.plan_read` | `GET /api/v1/maintenance-plans/:id` |
| | `CreatePlan` | `machine.plan_create` | `POST /api/v1/maintenance-plans` |
| | `UpdatePlan` | `machine.plan_update` | `PATCH /api/v1/maintenance-plans/:id` |
| | `StartPlan` | `machine.plan_execute` | `POST /api/v1/maintenance-plans/:id/actions/start` |
| | `CompletePlan` | `machine.plan_execute` | `POST /api/v1/maintenance-plans/:id/actions/complete` |
| | `CancelPlan` | `machine.plan_execute` | `POST /api/v1/maintenance-plans/:id/actions/cancel` |
| `BreakdownService` | `ListBreakdowns` | `machine.breakdown_read` | `GET /api/v1/machines/:id/breakdowns` |
| | `ReportBreakdown` | `machine.breakdown_create` | `POST /api/v1/machines/:id/breakdowns` |

Ba endpoint `/actions/<verb>` là ba dòng **đầu tiên** của bảng 1 trong sổ đăng ký C-API-07 — bảng đó hiện rỗng. Chúng dùng dạng đó vì không map được vào CRUD: `start` không tạo tài nguyên nào, `complete` không thay toàn bộ bản ghi, và cả ba là chuyển trạng thái chứ không phải sửa field.

Không có endpoint sửa/xóa `breakdowns`: nhật ký sự cố là sổ ghi việc đã xảy ra. Nó vẫn có `deleted_at` vì nó là bảng nghiệp vụ và R-18 không cấp miễn trừ theo ý muốn — chỉ là chưa có đường nào set cột đó.

### Bảng chuyển trạng thái — sống ở service, không ở frontend

```
              start                 complete
  ke_hoach ──────────> dang_lam ──────────────> hoan_thanh
      │                    │
      │ cancel             │ cancel
      ▼                    ▼
     huy                  huy
```

| Từ | Hành động | Sang | Hiệu ứng kèm theo, cùng transaction |
|---|---|---|---|
| `ke_hoach` | `start` | `dang_lam` | `machines.status` → `bao_tri`; `started_at` = now |
| `dang_lam` | `complete` | `hoan_thanh` | `machines.status` → `hoat_dong`; `completed_at` = now |
| `ke_hoach` | `cancel` | `huy` | Máy **không** đổi — nó chưa từng vào bảo trì |
| `dang_lam` | `cancel` | `huy` | `machines.status` → `hoat_dong` |

Bốn dòng chứ không ba: bản đầu của spec này gộp hai lần `cancel` vào một dòng với chữ
"nếu" ở cột hiệu ứng, và chính chữ "nếu" đó là thứ không sống được trong một bảng — hủy
một kế hoạch đang làm trả máy về `hoat_dong`, hủy một kế hoạch chưa bắt đầu thì không.
Code tách đúng, spec là bản lạc hậu và đã sửa theo.

Cặp `(từ, hành động)` không có dòng ở đây trả `409` với `ERR_MACHINE_STATUS_NOT_ALLOWED`. Bảng này là **bảng trong service**; sơ đồ ở `Workflow.md` là mô tả của nó, không phải bản sao thứ hai được phép lệch (R-19).

Hai bảng đổi trong **một** transaction là điểm đáng giá nhất của chặng này về mặt P-TXN: một kế hoạch `dang_lam` trên một máy `hoat_dong` là sổ sách nói dối, và không có cách nào sửa nó bằng một câu UPDATE thứ hai chạy sau.

### Mã lỗi

| Mã | HTTP | Khi nào |
|---|---|---|
| `ERR_MACHINE_CODE_DUPLICATED` | `409` | Vi phạm `uq_machines_company_id_code` hoặc `uq_maintenance_plans_company_id_code` |
| `ERR_MACHINE_STATUS_NOT_ALLOWED` | `409` | Chuyển trạng thái không có trong bảng trên |
| `ERR_MACHINE_ASSIGNEE_INVALID` | `422` | `assigned_to` không phải user còn sống của công ty |

Ba mã, không hơn. `404`, `403`, `422` hình dạng request, `400` body không đọc được đều dùng mã `COMMON` đã có.

---

## 7. Kéo theo ở `docs-erp`

| Thay đổi | Vì sao |
|---|---|
| C-API-05: thêm ba dòng `ERR_MACHINE_*` | Mã là hợp đồng công khai; hằng ở `shared/errors` phải khớp bảng |
| C-API-05 bảng ánh xạ constraint: thêm `uq_machines_company_id_code`, `uq_maintenance_plans_company_id_code`, `ck_machines_status`, `ck_maintenance_plans_status` | Constraint không có dòng thì lỗi của nó ra client dưới dạng `ERR_INTERNAL` |
| C-API-07 bảng 1: ba endpoint `/actions/{start,complete,cancel}` | Ngoại lệ R-10 chỉ có hiệu lực khi có dòng trong sổ |
| `CL-PR-14` và `CL-API-17`: sửa `C-TS-04` → `C-TS-05`/`C-TS-06` | Đứt traceability tìm thấy khi khảo sát: C-TS-04 nay là "Gọi API và xử lý envelope" (`R-11, R-12`), không còn implement R-19 |

**Không** đổi: `RULES.md` (không rule nào đổi mệnh đề, nên `arch-pin` không phải chạy), `C-DB-04` (không bảng nào xin miễn trừ), `C-GO-08` (ADR-0010 vừa chốt xong ở chặng trước).

---

## 8. Định nghĩa hoàn thành

- `modules/machine/module.yaml` khai `allowed_deps: [auth]`, và **đổi nó thành `[]` thì `go run ./cmd/dev arch` đỏ** — phép thử của chính mục tiêu chặng này.
- `modules/machine/internal/service/` có ít nhất một dòng `import "erp/modules/auth/api"`, và đổi nó thành `erp/modules/auth/internal/service` thì `checkR01` đỏ đúng dòng import đó.
- Một câu SQL trong `machine/**/repository` nêu tên bảng `users` làm `checkR02` đỏ — thử bằng cách sửa tạm rồi hoàn lại.
- Mỗi method public của ba service có ít nhất một test gọi thẳng nó, truyền `auth.Actor` qua tham số (CL-NEWMOD-15).
- Ca end-to-end qua database thật: tạo máy → tạo kế hoạch → `actions/start` trả `200` và `machines.status` thành `bao_tri` → `actions/start` lần hai trả `409` `ERR_MACHINE_STATUS_NOT_ALLOWED` → `actions/complete` trả `200` và máy về `hoat_dong`.
- Ca gán người phụ trách không tồn tại trả `422` `ERR_MACHINE_ASSIGNEE_INVALID`, và ca gán user của công ty khác trả **cùng** mã đó — không phải `404`, vì thứ không tồn tại ở đây là một giá trị trong request chứ không phải tài nguyên trên URL.
- `modules/machine/docs/` đủ năm file, `Database.md` khớp từng dòng với `tables` của `module.yaml`.
- `go run ./cmd/dev check` và `test` xanh; `arch-update` cho diff **chỉ** gồm cột FILE tăng, không dòng nào hạ mức.

---

## 9. Rủi ro đã biết

**Quyền xem máy kéo theo quyền xem người.** `UserReader.GetByID` đi qua `PermUserRead` của module `auth`, nên một vai trò chỉ được xem thiết bị vẫn phải có quyền đọc user để màn hình hiện tên người phụ trách. Chặng này chấp nhận và ghi vào `Permission.md` của cả hai module. Đường ra sạch hơn — một permission hẹp kiểu `auth.user_read_basic` — là một quyết định về mô hình quyền, không phải một chi tiết của module `machine`.

**Ba bảng, ba service, mười bốn method — chặng này to hơn chặng B.** Rủi ro không nằm ở khối lượng mà ở chỗ nó mời gộp: một `MachineService` làm cả bảo trì và sự cố sẽ ngắn hơn ở lần viết đầu và không tách ra được ở lần thứ hai. Ba service tách theo ba bảng, và không service nào gọi service nào — `internal_methods` rỗng là thứ giữ điều đó.

**`decimal.Decimal` là phụ thuộc mới trên đường tiền.** Nó vào repo lần đầu ở chặng này, và mọi lần sau đều sẽ đi qua khuôn nó đặt ra. Điểm phải canh: cột là `NUMERIC(18,4)`, JSON là **chuỗi**, và không có chỗ nào trong hệ thống được đưa một số tiền qua `float64` — kể cả trong test.
