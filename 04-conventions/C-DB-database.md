# C-DB — Quy ước Database

Convention nằm **giữa** Rule và Code. Rule nói *"khóa ngoại phải có index"*; file này nói
*"tên index là `idx_<table>_<cols>`"*. Rule trả lời **cái gì bắt buộc đúng**, Convention
trả lời **viết ra như thế nào**, cụ thể tới từng ký tự.

Vì vậy file này **không phải nguồn sự thật** cho bất cứ thứ gì đã được Rule hoặc ADR
quyết. Chỗ nào file này nhắc lại một quyết định, nó nhắc lại kèm địa chỉ của bản gốc.
Khi file này lệch với [../01-rules/RULES.md](../01-rules/RULES.md) hoặc với một ADR,
bản gốc thắng và file này là thứ phải sửa.

**Ngoại lệ đúng một chỗ: mục `C-DB-04`.** Registry nhóm bảng ở đó là **bản gốc**, không
phải bản sao — vì danh sách bảng là *current policy* tiến hóa theo thời gian, còn ADR
thì bất biến. Mỗi entry mang một trường `adr` trỏ về ADR biện minh cho phân loại của
nó, nên phần bảo vệ của tầng Decision vẫn còn nguyên: thêm một bảng vẫn đòi một ADR
mới. Lý do đầy đủ nằm ở khối ghi chú sửa đổi đầu
[../03-decisions/ADR-0003-multi-tenant-ready.md](../03-decisions/ADR-0003-multi-tenant-ready.md).

| Mục | Nội dung | Neo về |
|---|---|---|
| C-DB-01 | Đặt tên bảng, cột, constraint, index | R-08 |
| C-DB-02 | Kiểu dữ liệu chuẩn | R-08 |
| C-DB-03 | Bộ cột bắt buộc theo từng nhóm bảng | R-06, R-08, R-17, R-18 |
| C-DB-04 | Registry nhóm bảng — canonical | R-06 |
| C-DB-05 | Quy tắc index | R-09 |
| C-DB-06 | Cách viết migration | R-07 |
| C-DB-07 | Schema bảng `outbox` | R-05 |

---

### C-DB-01 — Đặt tên bảng, cột, constraint, index

**Implements:** R-08

#### Bảng

- snake_case, chữ thường, **số nhiều**, khớp `^[a-z][a-z0-9_]*s$`: `orders`,
  `order_items`, `work_orders`, `price_lists`.
- Tên không kết thúc bằng `s` chỉ hợp lệ khi đã có ADR bổ sung nó vào danh sách
  `naming_exempt` ở mục `C-DB-04` của chính file này. Hiện danh sách đó có đúng một
  tên: `outbox`. Không ép `inventory` thành `inventorys`; không lách bằng comment
  trong migration — viết ADR trước khi merge.
- Bảng nối đặt tên bằng hai danh từ, danh từ sở hữu đứng trước:
  `order_items`, `order_tags`.
- Không tiền tố module vào tên bảng (`ord_orders` là sai). Ranh giới module do
  `module.yaml` khai, không do tên bảng.

#### Cột

- snake_case, chữ thường.
- Khóa chính: `id UUID PRIMARY KEY DEFAULT gen_random_uuid()`. Đúng một cột, luôn tên
  `id`, luôn kiểu `UUID`.
- Khóa ngoại: `<singular>_id` — cột trỏ tới `orders(id)` tên `order_id`, trỏ tới
  `companies(id)` tên `company_id`. Hai khóa ngoại cùng trỏ tới một bảng thì thêm tiền
  tố vai trò: `ship_to_province_id`, `bill_to_province_id`.
- Không lặp tên bảng vào tên cột: `orders.code`, không phải `orders.order_code`.
- Cột boolean đặt tên khẳng định: `is_active`, không phải `is_not_active`.
- Cột thời điểm kết thúc bằng `_at` (`approved_at`); cột ngày thuần kết thúc bằng
  `_date` (`document_date`); cột số lượng bằng `_qty` hoặc tên đầy đủ `quantity`.

#### Constraint và index

| Đối tượng | Mẫu tên | Ví dụ |
|---|---|---|
| Index thường | `idx_<table>_<cols>` | `idx_orders_company_id_status` |
| Unique index | `uq_<table>_<cols>` | `uq_orders_company_id_code` |
| Khóa ngoại | `fk_<table>_<ref_table>` | `fk_order_items_orders` |
| Check constraint | `ck_<table>_<mo_ta>` | `ck_orders_total_amount_non_negative` |

- `<cols>` là **tên đầy đủ của các cột, nối bằng `_`, đúng thứ tự trong index**. Không
  rút gọn: index trên `(company_id, status)` tên là `idx_orders_company_id_status`, không
  phải `idx_orders_status`. Thứ tự cột là thông tin quan trọng nhất của một index
  composite (R-09), nên nó phải đọc được ra từ tên.
- Hai index cùng bộ cột nhưng khác mệnh đề `WHERE` thì thêm hậu tố mô tả điều kiện:
  `idx_outbox_occurred_at_unpublished`, `uq_users_email_active`.
- Hai khóa ngoại cùng trỏ tới một bảng thì thêm tên cột vào cuối:
  `fk_orders_provinces_ship_to_province_id`.
- `<mo_ta>` của check constraint viết ASCII không dấu, mô tả **điều kiện** chứ không mô
  tả cột: `ck_orders_total_amount_non_negative`, `ck_orders_status`.

Tên constraint không phải chuyện thẩm mỹ: theo
[../02-principles/P-ERR-error-handling.md](../02-principles/P-ERR-error-handling.md),
service dịch lỗi `23505` sang mã lỗi nghiệp vụ **theo tên constraint**, vì mã `23505`
một mình không nói được ràng buộc nào bị vi phạm. Đổi tên một unique index sau khi merge
là đổi một khóa mà code đang so sánh chuỗi.

Khóa ngoại khai kiểu inline (`company_id UUID NOT NULL REFERENCES companies(id)`) vẫn
hợp lệ và là dạng dùng trong ví dụ của R-06 lẫn R-09; nó sinh tên tự động
`<table>_<col>_fkey`. Chọn dạng đó nghĩa là chấp nhận không dịch được lỗi `23503` theo
tên constraint. Khóa ngoại nào cần dịch lỗi ra thông điệp nghiệp vụ phải khai ở mức bảng
với tên tường minh: `CONSTRAINT fk_<table>_<ref_table> FOREIGN KEY (<col>) REFERENCES <ref_table>(id)`.

#### Hai loại tên nằm ngoài quy ước này

Index do `PRIMARY KEY` và do ràng buộc `UNIQUE` sinh ra mang tên do PostgreSQL tự đặt:

- `PRIMARY KEY` → `<table>_pkey`, ví dụ `orders_pkey`.
- `UNIQUE (a, b)` → `<table>_<a>_<b>_key`, ví dụ `outbox_event_id_key`.

Chúng **không** theo mẫu `idx_`/`uq_` ở trên, và đó là đúng: quy ước này chỉ áp cho index
do một câu `CREATE INDEX` tường minh tạo ra. Đổi tên hai loại trên đòi khai constraint
kiểu `CONSTRAINT <ten> UNIQUE (...)`, đổi lấy một cái tên đẹp bằng một dòng dài hơn và
một sự khác biệt so với mọi bảng khác — không đáng.

Lưu ý kèm theo: PostgreSQL cắt mọi identifier ở **63 byte** và cắt **im lặng**. Hai index
có tên dài khác nhau ở 5 ký tự cuối sẽ thành cùng một tên sau khi cắt, và câu `CREATE
INDEX` thứ hai báo trùng tên ở một cái tên không có trong file. Khi tên vượt 63 byte, rút
gọn bằng cách bỏ hậu tố `_id` khỏi phần `<cols>` (`idx_order_items_company_id_product`),
và ghi comment ASCII ngay trên câu lệnh nêu bộ cột đầy đủ.

---

### C-DB-02 — Kiểu dữ liệu chuẩn

**Implements:** R-08

| Loại dữ liệu | Kiểu bắt buộc | Cấm dùng |
|---|---|---|
| Tiền, đơn giá, thành tiền | `NUMERIC(18,4)` | `FLOAT`, `DOUBLE PRECISION`, `REAL`, `MONEY` |
| Số lượng hàng cân đo | `NUMERIC(18,4)` | kiểu dấu phẩy động |
| Số lượng hàng đếm chiếc | `INTEGER` | `NUMERIC` |
| Tỷ lệ (thuế suất, chiết khấu) | `NUMERIC(9,6)` | `FLOAT` |
| Thời điểm | `TIMESTAMPTZ` | `TIMESTAMP` |
| Ngày nghiệp vụ thuần | `DATE` | `TEXT` |
| Định danh | `UUID` | `SERIAL`, `BIGSERIAL`, `BIGINT` |
| Văn bản mọi độ dài | `TEXT` | `VARCHAR(n)`, `CHAR(n)` |
| Trạng thái | `TEXT` + `CHECK`, hoặc bảng tham chiếu | `ENUM` của PostgreSQL |
| Đúng/sai | `BOOLEAN NOT NULL DEFAULT <giá trị an toàn>` | `SMALLINT` 0/1, cột boolean cho phép `NULL` |
| Dữ liệu bán cấu trúc | `JSONB` | `JSON`, `TEXT` chứa JSON |

**Cột boolean: phần bắt buộc là `BOOLEAN NOT NULL` cộng một `DEFAULT` tường minh, không
phải giá trị `false`.** Bắt buộc `NOT NULL` + `DEFAULT` vì một boolean cho phép `NULL` là
một trạng thái ba giá trị, và `WHERE is_active = false` khi đó **bỏ sót** mọi hàng `NULL` —
một loại lỗi im lặng, đọc code không thấy. Còn *giá trị* mặc định thì chọn theo cột: lấy
trạng thái an toàn nhất khi hàng vừa được tạo mà chưa ai gán. `users.is_active DEFAULT true`
là đúng vì hệ thống chưa có luồng kích hoạt tài khoản — mặc định `false` nghĩa là mọi user
vừa tạo đều không đăng nhập được, tức một tính năng chưa tồn tại được bật lên bằng một giá
trị mặc định.

**Tiền là `NUMERIC(18,4)`, không bao giờ là kiểu dấu phẩy động.** `FLOAT` và `DOUBLE
PRECISION` là nhị phân: `0.1` không biểu diễn được chính xác, nên mỗi phép cộng để lại
một sai số nhỏ. Sai số đó **tích lũy** — một bảng kê nghìn dòng cộng lại lệch với tổng
tính theo cách khác, và một sổ kế toán không cân là thứ không có cách nào giải thích với
kế toán trưởng. `NUMERIC` là số thập phân chính xác, cộng bao nhiêu lần cũng không sinh
sai số. Bốn chữ số thập phân là để chứa đơn giá và tỷ giá; làm tròn về đơn vị tiền tệ chỉ
xảy ra **một lần**, lúc xuất chứng từ, và luôn ở backend (R-19).

**Thời điểm là `TIMESTAMPTZ`, không bao giờ là `TIMESTAMP`.** `TIMESTAMP WITHOUT TIME
ZONE` lưu một chuỗi ký tự mô tả giờ mà không lưu nó thuộc múi giờ nào; hai hàng ghi từ hai
nơi khác nhau trở nên không so sánh được, và không có cách nào phục hồi thông tin đã mất.
`TIMESTAMPTZ` lưu mốc thời gian tuyệt đối và quy đổi theo `TimeZone` của session lúc đọc.
Ngày nghiệp vụ thuần — ngày trên chứng từ, ngày đáo hạn — dùng `DATE`: nó cố ý *không* có
múi giờ, vì "ngày 15" trên hóa đơn là ngày 15 ở mọi nơi.

**Văn bản là `TEXT`.** PostgreSQL lưu `TEXT` và `VARCHAR(n)` giống hệt nhau và không nhanh
hơn ở bất kỳ đâu khi có `n`; giới hạn độ dài chỉ đổi lấy một migration `ALTER TABLE` mỗi
lần nghiệp vụ cần dài hơn. Khi thật sự cần chặn độ dài (mã chứng từ in lên form giấy),
dùng check constraint: `CONSTRAINT ck_orders_code_length CHECK (char_length(code) <= 32)`.
`CHAR(n)` bị cấm hẳn vì nó đệm khoảng trắng vào cuối và so sánh chuỗi trở nên khó đoán.

**Trạng thái không dùng `ENUM` của PostgreSQL.** Thêm một giá trị vào `ENUM` là DDL
(`ALTER TYPE ... ADD VALUE`), nó khóa, và ở PostgreSQL trước 12 nó không chạy được trong
transaction block — tức là một migration đổi trạng thái không còn nguyên tử với phần còn
lại của nó; từ 12 trở đi chạy được nhưng giá trị vừa thêm không dùng được ngay trong cùng
transaction. Còn **xóa** một giá trị khỏi `ENUM` thì không có lệnh nào làm được: phải dựng
type mới, chuyển cột, xóa type cũ. Hai lựa chọn thay thế:

- `TEXT` + `CHECK (status IN ('draft', 'approved', 'cancelled'))` — cho tập giá trị đóng,
  do lập trình viên quyết, đổi bằng migration `DROP CONSTRAINT` + `ADD CONSTRAINT`.
- Bảng tham chiếu + khóa ngoại — cho tập giá trị mà **người dùng** thêm được.

Ghi chú tránh nhầm: một số ví dụ trong `01-rules/rules/` viết `NUMERIC(14,2)`. Đó là ví dụ
minh họa cách đặt index, không phải quy ước kiểu dữ liệu. Bảng mới dùng `NUMERIC(18,4)`
theo bảng ở trên.

---

### C-DB-03 — Bộ cột bắt buộc theo từng nhóm bảng

**Implements:** R-06, R-08, R-17, R-18

Bộ cột bắt buộc **khác nhau theo nhóm bảng**, nên việc đầu tiên khi viết migration là xác
định bảng mới thuộc nhóm nào (C-DB-04). Mặc định của một bảng không có tên trong bốn nhóm
khai ở registry là **bảng nghiệp vụ**, và bảng nghiệp vụ không được miễn thứ gì.

| Cột | Bảng nghiệp vụ | `tenant_root` | `reference_tables` | `append_only_tables` | `system_tables` |
|---|---|---|---|---|---|
| `id UUID PRIMARY KEY` | Có | Có | Có | Có | Không bắt buộc |
| `company_id UUID NOT NULL` | Có | **Không** | **Không** | Có | **Không** |
| `created_at TIMESTAMPTZ NOT NULL` | Có | Có | Có | Có | Không bắt buộc |
| `updated_at TIMESTAMPTZ NOT NULL` | Có | Có | Có | **Không** | Không bắt buộc |
| `deleted_at TIMESTAMPTZ` | Có | Có | Có | **Không** | Không bắt buộc |
| `created_by UUID NOT NULL` | Có | Có | Có | Có | Không bắt buộc |
| `updated_by UUID NOT NULL` | Có | Có | Có | **Không** | Không bắt buộc |

Ô "Không" là **miễn trừ**, không phải "tùy chọn": bảng thuộc nhóm đó **không được có** cột
tương ứng. Thêm `deleted_at` vào một bảng trong `append_only_tables` là mâu thuẫn với chính
định nghĩa của nhóm.

Thứ tự khai cột trong `CREATE TABLE`: `id` → `company_id` → khóa ngoại → cột nghiệp vụ →
cột thời gian → cột audit → constraint mức bảng.

#### 1. Bảng nghiệp vụ — bộ đầy đủ

```sql
id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
company_id   UUID        NOT NULL REFERENCES companies(id),
created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
deleted_at   TIMESTAMPTZ,
created_by   UUID        NOT NULL,
updated_by   UUID        NOT NULL
```

`updated_by` là `NOT NULL`: lúc `INSERT` nó nhận đúng giá trị của `created_by`. Cho phép
`NULL` nghĩa là mọi câu truy vấn truy vết phải xử lý hai hình dạng dữ liệu cho cùng một
câu hỏi "ai sửa gần nhất", và câu trả lời "chưa ai sửa" đã đọc được từ
`updated_at = created_at`.

`deleted_at` là cột duy nhất cho `NULL` — `NULL` chính là nghĩa "chưa xóa" (R-18).

#### 2. `tenant_root` — giống bảng nghiệp vụ, trừ `company_id`

```sql
id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
deleted_at   TIMESTAMPTZ,
created_by   UUID        NOT NULL,
updated_by   UUID        NOT NULL
```

Chỗ khác duy nhất về cột so với bảng nghiệp vụ là **không có `company_id`**: `companies`
là bảng **định nghĩa** tenant nên không thể mang khóa trỏ tới chính khái niệm nó định
nghĩa. Mọi thứ còn lại giữ nguyên — đủ ba cột thời gian (R-08), đủ cột audit, **vẫn sinh
bản ghi audit khi ghi** (R-17), **vẫn xóa mềm** (R-18).

Bộ cột của nhóm này trùng với bộ cột của `reference_tables`; hai nhóm vẫn tách rời vì lý
do tồn tại khác nhau — `tenant_root` định nghĩa tenant, `reference_tables` là danh mục
dùng chung giữa các tenant.

#### 3. `reference_tables` — giống hệt trên, trừ `company_id`

```sql
id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
deleted_at   TIMESTAMPTZ,
created_by   UUID        NOT NULL,
updated_by   UUID        NOT NULL
```

Chỗ khác duy nhất về cột là thiếu `company_id`, vì danh mục dùng chung không thuộc tenant
nào. Mọi thứ còn lại giữ nguyên: có đủ ba cột thời gian (R-08), có đủ cột audit và **vẫn
sinh bản ghi audit khi ghi** (R-17), **vẫn xóa mềm** (R-18). Danh mục có người sửa, và sửa
một danh mục dùng chung thì ảnh hưởng mọi công ty cùng lúc — đó là chỗ cần truy vết nhất.

#### 4. `append_only_tables` — chỉ ghi thêm

```sql
id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
company_id   UUID        NOT NULL REFERENCES companies(id),
created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
created_by   UUID        NOT NULL
```

Không có `updated_at`, `updated_by`, `deleted_at` — bảng này không bao giờ bị sửa, nên ba
cột đó sẽ vĩnh viễn mang giá trị lúc tạo và chỉ làm người đọc tưởng có cơ chế cập nhật.
Thao tác ghi vào nhóm này **không** sinh bản ghi audit (R-17), và nhóm này được **hard
delete theo lịch giữ liệu mà không cần ADR riêng** (R-18, ADR-0003).

Hệ quả cài đặt phải chấp nhận, đã nêu ở ADR-0003: vì không có `updated_at`, mọi thứ cần
ghi phải được ghi trong **một lần ghi duy nhất** — không có mẫu "claim trước rồi `UPDATE`
kết quả sau".

#### 5. `system_tables` — không bắt buộc cột nào

Miễn toàn bộ: `company_id`, mọi cột thời gian, mọi cột audit, soft delete, và cả việc sinh
bản ghi audit. `schema_migrations` do `golang-migrate` sở hữu. `companies` **không** thuộc
nhóm này — nó nằm ở `tenant_root` (C-DB-04) và không được miễn thứ gì ngoài `company_id`.

Nhóm này phải giữ nhỏ nhất có thể: mỗi tên thêm vào đây là một bảng nằm ngoài toàn bộ cơ
chế truy vết.

#### DDL mẫu đầy đủ cho một bảng nghiệp vụ

```sql
-- migrations/000042_create_orders.up.sql

CREATE TABLE orders (
    id           UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id   UUID          NOT NULL REFERENCES companies(id),
    customer_id  UUID          NOT NULL,
    code         TEXT          NOT NULL,
    status       TEXT          NOT NULL DEFAULT 'draft',
    total_amount NUMERIC(18,4) NOT NULL DEFAULT 0,
    ordered_at   TIMESTAMPTZ   NOT NULL,
    note         TEXT,
    created_at   TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ   NOT NULL DEFAULT now(),
    deleted_at   TIMESTAMPTZ,
    created_by   UUID          NOT NULL,
    updated_by   UUID          NOT NULL,

    CONSTRAINT fk_orders_customers
        FOREIGN KEY (customer_id) REFERENCES customers(id),
    CONSTRAINT ck_orders_status
        CHECK (status IN ('draft', 'approved', 'cancelled')),
    CONSTRAINT ck_orders_total_amount_non_negative
        CHECK (total_amount >= 0),
    CONSTRAINT ck_orders_code_length
        CHECK (char_length(code) <= 32)
);

-- Ma don khong trung TRONG MOT CONG TY. Partial index vi bang co soft delete: dung
-- UNIQUE thuong thi mot ma da xoa mem van chiem cho vinh vien (R-18).
CREATE UNIQUE INDEX uq_orders_company_id_code
    ON orders(company_id, code) WHERE deleted_at IS NULL;

-- Composite dan dau bang company_id, khop dung hinh dang WHERE that su chay (R-09).
CREATE INDEX idx_orders_company_id_status      ON orders(company_id, status);
CREATE INDEX idx_orders_company_id_customer_id ON orders(company_id, customer_id);
```

```sql
-- migrations/000042_create_orders.down.sql

DROP TABLE IF EXISTS orders;
```

`DROP TABLE` kéo theo mọi index và constraint của bảng, nên phần `down` không cần liệt kê
lại chúng. Ngược lại, migration chỉ thêm index thì phần `down` phải `DROP INDEX` đúng
những index đó (C-DB-06).

#### `created_by` và `updated_by` không mang khóa ngoại

**`created_by` và `updated_by` không bao giờ mang khóa ngoại**, dù R-08 bắt mọi cột
dạng `<singular>_id` là khóa ngoại. Đây là ngoại lệ có lý do: audit phải giữ được dấu
vết kể cả khi user bị xóa, nên ràng buộc cứng tới `users` sai về nghiệp vụ chứ không
chỉ bất tiện.

Khai tường minh ở đây vì nếu không, checker R-09 sẽ đi tìm index cho một khóa ngoại
không tồn tại.

Giá trị của hai cột này khi thao tác **không do người dùng khởi xướng** — seed lúc
bootstrap, job nền, relay — là `system_actor_id` khai ở `C-DB-04`.

---

### C-DB-04 — Registry nhóm bảng

**Implements:** R-06

Đây là **canonical registry** — nguồn sự thật cho việc bảng nào thuộc nhóm nào. Cả
người lẫn checker `arch/` của `backend-erp` đọc từ đây.

**Nghĩa của trường `adr`:** ADR giải thích **lý do kiến trúc khiến entry được xếp vào
nhóm hiện tại**. Nó **không** có nghĩa "ADR gần nhất từng nhắc tới bảng này".

**Invariant:** `adr` phải trỏ tới một ADR ở trạng thái `Accepted`, và ADR đó phải hoặc
**định nghĩa tiêu chí của nhóm** mà entry được xếp vào, hoặc **biện minh riêng cho chính
bảng đó**.

Hai ví dụ cho hai vế:

- `idempotency_keys` trỏ `ADR-0003` vì ADR đó đặt ra tiêu chí của `append_only_tables`
  — *bảng chỉ ghi thêm, không bao giờ sửa* — và bảng này thỏa tiêu chí. ADR-0003 không
  cần gọi đích danh nó.
- `outbox` trỏ `ADR-0006` vì chính ADR đó quyết định nó tồn tại và quyết định nó chỉ
  ghi thêm.

Thêm một bảng vào bất kỳ nhóm nào vẫn đòi một ADR — hoặc một ADR mới biện minh riêng,
hoặc một ADR có sẵn mà bảng đó thỏa tiêu chí. Không sửa ADR cũ, và không thêm lặng lẽ
bằng một PR Convention.

`check-ids.ps1` kiểm được vế "ADR tồn tại và ở trạng thái Accepted". Vế "thỏa tiêu chí"
thì không — đó là việc của reviewer.

```yaml
system_actor_id: 00000000-0000-4000-8000-000000000001

tenant_root:
  - table: companies
    adr: ADR-0003

reference_tables:
  - table: currencies
    adr: ADR-0003
  - table: units
    adr: ADR-0003
  - table: provinces
    adr: ADR-0003

append_only_tables:
  - table: outbox
    adr: ADR-0006
  - table: audit_logs
    adr: ADR-0007
  - table: idempotency_keys
    adr: ADR-0003

system_tables:
  - table: schema_migrations
    adr: ADR-0003

naming_exempt:
  - table: outbox
    adr: ADR-0003
    reason: ket thuc bang x, khong khop regex cua R-08
```

> **`outbox` thuộc `append_only_tables`, KHÔNG thuộc `system_tables`.** Xếp nhầm thì
> `outbox` mất `company_id` (vì `system_tables` miễn cột đó), R-06 không đòi nó nữa,
> và bug chỉ lộ ra khi có khách hàng thứ hai — relay không lọc được theo tenant.

**`system_actor_id`** là actor dùng cho thao tác ghi không do người dùng khởi xướng:
seed lúc bootstrap, job nền, relay. Giá trị này xuất hiện ở bốn nơi và phải khớp nhau —
registry này (canonical), migration bootstrap, hằng trong `shared/auth`, và test
fixture. Có checker kiểm khớp; không hard-code thêm ở bất kỳ đâu khác.

Không dùng nil UUID (`00000000-0000-0000-0000-000000000000`) vì hai lý do: nó là zero
value của `uuid.UUID` trong Go nên "system actor" không phân biệt được với "quên gán";
và version nibble lẫn variant bits đều bằng 0 nên nó không phải UUIDv4 hợp lệ về hình
thức, thư viện validate chặt sẽ từ chối.

---

### C-DB-05 — Quy tắc index

**Implements:** R-09

R-09 quy định **cột nào phải nằm ở vị trí nào**. Mục này quy định phần còn lại: viết ra
như thế nào. Ba quy ước dưới đây không phải suy diễn — mỗi cái sinh ra từ một mâu thuẫn
thật đã gặp.

#### 1. Index composite dẫn đầu bằng `company_id`

Trên hệ multi-tenant, index đơn trên `(company_id)` gần như vô dụng: mọi bảng nghiệp vụ
đều có cột đó, và giá trị của nó lặp lại ở hầu hết mọi dòng, nên độ chọn lọc quá thấp để
planner dùng. Tạo nó ra chỉ được một index rác — tốn chỗ, làm chậm mọi lần ghi, không
giúp lần đọc nào.

Quy ước: **cột lọc thật sự đi sau `company_id` trong cùng một index composite.**

```sql
-- DUNG: khop dung hinh dang WHERE that su chay trong repository
--       (WHERE company_id = $1 AND status = $2)
CREATE INDEX idx_orders_company_id_status ON orders(company_id, status);

-- SAI: index don tren company_id, do chon loc gan bang khong
CREATE INDEX idx_orders_company_id ON orders(company_id);
```

Bảng không có `company_id` — nhóm `reference_tables`, `system_tables` và `tenant_root`
— thì index bắt đầu thẳng từ cột nghiệp vụ:
`CREATE UNIQUE INDEX uq_currencies_code ON currencies(code)`.

Đây cũng là dạng hợp lệ thứ hai cho khóa ngoại theo R-09: khóa ngoại khác `company_id`
hoặc là cột **dẫn đầu** của một index riêng, hoặc là cột **thứ hai** trong index composite
mở đầu bằng `company_id`. Trên bảng nghiệp vụ, dạng thứ hai là dạng gần như luôn dùng.

#### 2. Comment miễn index

Bảng đủ điều kiện miễn theo Ngoại lệ của R-09 — có tên trong `reference_tables` **và**
không có khóa ngoại trỏ tới bảng giao dịch — phải ghi lý do ngay trong file migration đó,
đúng mẫu:

```sql
-- index-exempt: <ly do>
```

Marker `-- index-exempt:` phải là **ASCII thuần**, và phần lý do cũng nên viết ASCII không
dấu. Lý do rất cụ thể: PowerShell 5.1 đọc file `.sql` mã hóa UTF-8 không BOM theo codepage
ANSI, nên một marker hay một chuỗi tiếng Việt có dấu sẽ không khớp khi grep — script kiểm
sẽ báo oan chính file đã ghi lý do miễn. Ví dụ đạt chuẩn:

```sql
-- index-exempt: currencies nam trong danh sach reference_tables va khong co khoa ngoai
-- tro toi bang giao dich - du ca hai dieu kien. Du lieu nap mot lan luc seed (~180 dong
-- ISO 4217) va chi doc qua PRIMARY KEY hoac code; ca hai cot do da co index san.
```

Comment miễn **không** cấp được điều kiện (a): tên bảng nằm trong `reference_tables` là
quyết định của một ADR, không phải một ưu ái xin lẻ lúc viết migration. Comment chỉ ghi
lại rằng cả hai điều kiện đã thỏa.

#### 3. Partial unique index cho bảng có soft delete

Mọi ràng buộc duy nhất trên bảng có `deleted_at` phải là **partial unique index**, không
phải `UNIQUE` thường:

```sql
CREATE UNIQUE INDEX uq_<table>_<cols>
    ON <table>(company_id, <cols>) WHERE deleted_at IS NULL;
```

Dùng `UNIQUE` thường thì hàng đã xóa mềm vẫn chiếm chỗ vĩnh viễn: xóa đơn hàng mã `PO-001`
rồi tạo lại đúng mã đó sẽ báo trùng, và người dùng không hiểu vì sao trùng với một thứ họ
vừa xóa. Vế `WHERE deleted_at IS NULL` khiến index chỉ chứa hàng còn sống.

Bảng trong `reference_tables` **không có `company_id`** nên bỏ cột đó khỏi index:

```sql
CREATE UNIQUE INDEX uq_currencies_code ON currencies(code) WHERE deleted_at IS NULL;
```

Bảng trong `append_only_tables` không có `deleted_at`, nên ràng buộc duy nhất ở đó là
`UNIQUE` thường và điều đó đúng — không có hàng nào bị xóa mềm để phải né.

#### 4. Index của `outbox` cho relay

```sql
CREATE INDEX idx_outbox_occurred_at_unpublished
    ON outbox(occurred_at) WHERE published_at IS NULL;
```

Cột lọc `published_at` nằm ở **mệnh đề `WHERE` của index**, không nằm trong danh sách cột.
Đó là hình dạng đúng: relay chỉ quan tâm hàng chưa gửi, nên index chỉ chứa hàng chưa gửi
và co lại về gần bằng không mỗi khi relay đuổi kịp — trong khi bảng `outbox` vẫn phình
theo toàn bộ lịch sử event cho tới lần dọn kế tiếp. Sắp theo `occurred_at` để relay lấy
event đúng thứ tự xảy ra. Hậu tố `_unpublished` là phần mô tả điều kiện `WHERE` theo quy
ước đặt tên ở C-DB-01.

Ghi chú cho người review: `published_at` xuất hiện trong `WHERE` của repository relay dưới
đúng một dạng `IS NULL`, và nó được phục vụ bởi mệnh đề `WHERE` của partial index chứ
không bởi một vị trí cột. Đưa nó lên làm cột dẫn đầu (`ON outbox(published_at, occurred_at)`)
là tệ hơn ở mọi mặt: index sẽ chứa cả những hàng đã gửi, tức là chứa toàn bộ bảng.

`outbox` không có index dẫn đầu bằng `company_id`, và đó là chủ ý: relay quét theo trạng
thái gửi chứ không lọc theo công ty, nên một index mở đầu bằng `company_id` không khớp câu
truy vấn nào relay thật sự chạy.

#### Chỗ đặt câu `CREATE INDEX`

Index đi **cùng file migration** với cột nó phục vụ, không nằm ở một migration "dọn index"
riêng sau này. Lý do ở R-09: tạo index lúc bảng còn rỗng gần như miễn phí; tạo nó khi bảng
đã vài triệu dòng là một thao tác vận hành có rủi ro, cần `CREATE INDEX CONCURRENTLY`,
cần canh giờ thấp điểm và cần người trực (C-DB-06).

---

### C-DB-06 — Cách viết migration

**Implements:** R-07

#### Đánh số: số tăng dần 6 chữ số, không phải timestamp

```
migrations/000042_create_orders.up.sql
migrations/000042_create_orders.down.sql
```

Định dạng: `<6 chữ số>_<động từ>_<đối tượng>.<up|down>.sql`. Động từ dùng
`create`, `add`, `drop`, `rename`, `backfill`.

Chọn số tăng dần thay vì timestamp `YYYYMMDDHHMMSS` vì hai lý do. Thứ nhất, R-07 nói thẳng
"đánh số tăng dần". Thứ hai — và đây mới là phần đáng giải thích — timestamp **né** xung
đột thay vì phơi nó ra. Hai nhánh phát triển song song sinh hai timestamp khác nhau, git
merge sạch, và hai migration sẽ chạy theo thứ tự đồng hồ treo tường; nếu migration của
nhánh B giả định bảng do nhánh A tạo, thứ tự đồng hồ có thể không phải thứ tự phụ thuộc và
hỏng chỉ lộ ra trên môi trường chạy sau. Với số tăng dần, hai nhánh cùng lấy `000043` sẽ
**đụng nhau ngay lúc merge** — đúng lúc còn người đang nhìn và còn sửa được: rebase, đổi
số file chưa merge, xem lại thứ tự phụ thuộc. Xung đột nhìn thấy được rẻ hơn thứ tự sai
im lặng.

Đổi số một file **chưa merge** không vi phạm R-07 — R-07 cấm sửa migration **đã merge**.

#### Cặp `up`/`down`

Mọi migration có **đủ hai file** theo quy ước của `golang-migrate`: `<version>_<title>.up.sql`
và `<version>_<title>.down.sql`. File `down` chỉ có một việc: đưa schema về đúng trạng
thái trước khi `up` chạy, làm theo **thứ tự ngược** với `up`.

- `up` tạo bảng → `down` là `DROP TABLE IF EXISTS <table>;` (index và constraint của bảng
  bị xóa theo, không cần liệt kê).
- `up` thêm cột → `down` là `ALTER TABLE ... DROP COLUMN ...`.
- `up` thêm index → `down` là `DROP INDEX IF EXISTS <ten_index>;`.
- `down` làm mất dữ liệu không cứu lại được thì ghi comment ASCII ngay đầu file:
  `-- destructive: rollback lam mat du lieu cot <ten cot>`.

Trong `up` **cấm** `IF NOT EXISTS`: nó che giấu việc migration đang chạy trên một schema
lệch với giả định của nó, biến một lỗi rõ ràng thành một no-op im lặng. Trong `down` thì
`IF EXISTS` được dùng, vì `down` phải chạy được cả khi `up` đã hỏng giữa chừng.

#### Cấm sửa migration đã merge

Một file đã merge là một file đã chạy trên môi trường của người khác. Sửa nội dung nó
không làm gì cả ở nơi nó đã chạy — chỉ khiến hai môi trường có schema khác nhau trong khi
`schema_migrations` nói chúng giống nhau. Sai thì viết migration mới với số kế tiếp.

#### Migration chạy trong transaction — và một ngoại lệ

Driver PostgreSQL gửi cả nội dung file như một chuỗi lệnh, và PostgreSQL bọc một chuỗi
nhiều câu lệnh trong **một transaction ngầm**. Nghĩa là mặc định mỗi file migration là
nguyên tử: hỏng ở câu lệnh thứ ba thì hai câu trước cũng không có hiệu lực. Đừng phá tính
chất đó bằng cách tự viết `BEGIN`/`COMMIT` trong file.

Ngoại lệ duy nhất là `CREATE INDEX CONCURRENTLY`, thứ **không chạy được trong transaction
block**. Nó cần thiết khi thêm index lên một bảng đã có dữ liệu ở production, vì
`CREATE INDEX` thường giữ lock chặn ghi suốt thời gian build — vài phút tới vài giờ trên
bảng lớn. Cách xử lý:

1. Đặt câu `CREATE INDEX CONCURRENTLY` **một mình** trong file migration của nó — không
   kèm bất kỳ câu lệnh nào khác. File chỉ có một câu lệnh thì không rơi vào transaction
   ngầm của chuỗi nhiều lệnh, và lệnh chạy được.
2. File `down` tương ứng cũng chỉ có một câu: `DROP INDEX CONCURRENTLY IF EXISTS <ten_index>;`.
3. Ghi comment ASCII nêu lý do phải dùng `CONCURRENTLY`.

```sql
-- migrations/000061_add_orders_ordered_at_index.up.sql
-- concurrently: bang orders da co du lieu production, CREATE INDEX thuong se chan ghi
-- suot thoi gian build. Cau lenh nay dung MOT MINH trong file vi CREATE INDEX
-- CONCURRENTLY khong chay duoc trong transaction block.
CREATE INDEX CONCURRENTLY idx_orders_company_id_ordered_at ON orders(company_id, ordered_at);
```

Cái giá phải biết trước: `CONCURRENTLY` có thể fail giữa chừng và để lại index ở trạng
thái `INVALID`, đồng thời `golang-migrate` đánh cờ `dirty` lên `schema_migrations`. Dọn
tay theo đúng thứ tự: `DROP INDEX CONCURRENTLY IF EXISTS <ten_index>;` rồi
`migrate force <version trước đó>` để gỡ cờ, rồi chạy lại.

Migration tạo bảng mới thì bảng còn rỗng — dùng `CREATE INDEX` thường, rẻ và giữ được tính
nguyên tử của cả file.

#### Một migration làm một việc

Không trộn DDL với backfill dữ liệu lớn trong cùng file: `UPDATE` hàng triệu dòng nằm chung
transaction với `ALTER TABLE` sẽ giữ lock của `ALTER TABLE` suốt thời gian backfill chạy.
Tách thành hai migration: một cho DDL, một cho backfill.

---

### C-DB-07 — Schema bảng `outbox`

**Implements:** R-05

`outbox` là bảng hiện thực hóa quyết định của
[../03-decisions/ADR-0006-event-bus-outbox.md](../03-decisions/ADR-0006-event-bus-outbox.md):
service ghi event vào bảng này **trong cùng transaction** với dữ liệu nghiệp vụ; một relay
nằm ngoài `modules/` đọc bảng và publish ra bus sau khi transaction đã commit. Service
không bao giờ gọi `bus.Publish` (R-05).

Nó có tên trong `append_only_tables` **và** trong danh sách miễn quy tắc đặt tên
(C-DB-04), nên nó vừa không có `updated_at`/`updated_by`/`deleted_at`, vừa được phép mang
một cái tên không kết thúc bằng `s`.

```sql
-- migrations/000003_create_outbox.up.sql

-- outbox nam trong append_only_tables (ADR-0003): chi ghi them, khong bao gio sua.
-- Vi vay bang nay KHONG co updated_at, updated_by, deleted_at. Ghi vao no cung khong
-- sinh ban ghi audit (R-17), va no duoc hard delete theo lich giu lieu ma khong can
-- ADR rieng (R-18).
-- Ten bang khong ket thuc bang 's': da co trong danh sach naming_exempt o C-DB-04.
CREATE TABLE outbox (
    id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id       UUID        NOT NULL UNIQUE,
    company_id     UUID        NOT NULL REFERENCES companies(id),
    aggregate_type TEXT        NOT NULL,
    aggregate_id   UUID        NOT NULL,
    event_type     TEXT        NOT NULL,
    payload        JSONB       NOT NULL,
    occurred_at    TIMESTAMPTZ NOT NULL,
    published_at   TIMESTAMPTZ,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by     UUID        NOT NULL
);

-- Index cho relay: chi chua hang CHUA GUI, sap theo thu tu xay ra. No co lai ve gan
-- bang khong moi khi relay duoi kip, trong khi bang van phinh theo lich su event.
CREATE INDEX idx_outbox_occurred_at_unpublished
    ON outbox(occurred_at) WHERE published_at IS NULL;
```

```sql
-- migrations/000003_create_outbox.down.sql

DROP TABLE IF EXISTS outbox;
```

#### Vì sao có cả `id` lẫn `event_id`

Hai cột này trả lời hai câu hỏi khác nhau và không thay thế nhau được:

- **`id` là khóa chính của một hàng trong bảng**, theo R-08 (khóa chính luôn là `id UUID`).
  Nó phục vụ relay: khóa hàng bằng `SELECT ... FOR UPDATE SKIP LOCKED`, rồi đánh dấu đã gửi
  bằng `UPDATE outbox SET published_at = now() WHERE id = $1`. Nó là chuyện nội bộ của
  bảng, consumer không bao giờ nhìn thấy.
- **`event_id` là danh tính của *sự việc*** đối với thế giới bên ngoài. Consumer dedupe
  theo nó ([../02-principles/P-IDEM-idempotency.md](../02-principles/P-IDEM-idempotency.md)),
  và vì relay là **at-least-once**, `event_id` **phải giữ nguyên qua mọi lần gửi lại**. Nó
  được sinh **đúng một lần**, lúc service ghi hàng vào `outbox`. Relay sinh id mới cho mỗi
  lần gửi là làm vô hiệu toàn bộ cơ chế dedupe phía consumer, và hỏng đó không báo lỗi ở
  đâu cả — nó chỉ hiện ra dưới dạng kho bị trừ hai lần cho một lần duyệt đơn.

Gộp hai vai vào một cột thì cột đó vừa là khóa nội bộ của bảng vừa là hợp đồng công khai
với mọi consumer, và mọi thay đổi ở vai này kéo theo vai kia. Tách ra là để R-08 và P-IDEM
cùng đúng mà không cái nào phải nhượng bộ.

Ràng buộc `UNIQUE` trên `event_id` là dạng `UNIQUE` thường chứ không phải partial unique
index, và điều đó đúng: `outbox` không có `deleted_at` nên không có hàng xóa mềm nào cần
né (C-DB-05). Index nó sinh ra mang tên tự động `outbox_event_id_key`, nằm ngoài quy ước
đặt tên ở C-DB-01 như mọi index do ràng buộc sinh ra.

#### Vài chi tiết dễ làm sai

- **`aggregate_id` cố ý không có `REFERENCES`.** Nó trỏ tới bảng nào là tùy giá trị của
  `aggregate_type`, nên không có một bảng đích cố định để khai khóa ngoại. Nó mang hình
  dạng tên `<singular>_id` của một khóa ngoại (C-DB-01) nhưng không phải khóa ngoại — ghi
  rõ ở đây để người review R-09 không đi tìm một index cho nó.
- **`occurred_at` là thời điểm *sự việc nghiệp vụ* xảy ra; `created_at` là thời điểm *hàng
  này* được ghi.** Hai giá trị thường bằng nhau nhưng không cùng nghĩa, và thứ consumer
  quan tâm là `occurred_at`. Đó cũng là cột relay dùng để sắp thứ tự.
- **`published_at NULL` nghĩa là chưa gửi.** Đây là toàn bộ trạng thái của một hàng
  `outbox`, và nó chỉ đổi đúng một lần theo một chiều. Không thêm cột `status`.
- **Relay phải đọc bằng `SELECT ... FOR UPDATE SKIP LOCKED`** (ADR-0006). Thiếu
  `SKIP LOCKED`, hai instance relay chạy song song đọc trúng cùng những hàng chưa gửi và
  nhân đôi mọi event — kiểu hỏng không lộ ra ở môi trường một instance.
- **Chỉ service được ghi vào bảng này** (R-05). Handler và repository của module không
  chạm tới nó; đường vào là `outboxRepo.Append(ctx, tx, event)` gọi từ service, trong
  chính transaction đang ghi dữ liệu nghiệp vụ.
