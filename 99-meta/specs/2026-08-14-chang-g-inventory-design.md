# Chặng G — module `inventory`, và phép đo của sáu chặng hạ tầng

**Trạng thái:** Đề xuất · 2026-08-14
**Tiền đề:** Chặng E và F đều đã lên `main` của cả bốn repo, CI xanh
([2026-08-14-ban-giao-chuan-bi-chang-g.md](../2026-08-14-ban-giao-chuan-bi-chang-g.md) mục 0).
Ba bảng danh mục `units` `currencies` `provinces` đã có migration (`000012`–`000014`).
Ba câu hỏi hợp đồng treo từ chặng E đã trả lời và đã có code.

---

## 1. Mục tiêu, đo được

Chặng này có **hai** mục tiêu, và mục tiêu thứ hai mới là lý do nó tồn tại.

**Mục tiêu 1 — hệ thống có module nghiệp vụ thứ ba, chạy được end-to-end.**

**Mục tiêu 2 — trả lời một câu hỏi bằng một con số: bộ khung có làm module thứ ba rẻ hơn
module thứ hai không?**

`auth` và `machine` **chính là** cái đẻ ra bộ khung, nên chúng không kiểm chứng được nó —
giống tự chấm bài của mình. `inventory` là module đầu tiên đi qua bộ khung mà không tham
gia thiết kế nó.

Phép đo phải khai **trước** khi viết dòng code đầu tiên, nếu không nó sẽ được chọn sau khi
biết kết quả. Mốc của `machine` (`99-meta/pham-vi-he-thong.md` mục 1) chia theo sáu hạng
mục, và chặng G đo lại **đúng sáu hạng mục đó**:

| Hạng mục | `machine` (mốc, đo ở `1aaa3c6`) | `machine` @HEAD cuối chặng G | `inventory` @HEAD cuối chặng G |
|---|---|---|---|
| backend `src` | 4.925 | 5.081 | **4.870** |
| backend `test` | 4.269 | 4.485 | 4.919 |
| docs module | 1.188 | 1.214 | 1.213 |
| migration | 375 | 377 | 291 |
| frontend `src` | 2.423 | 2.423 | 4.400 |
| frontend `test` | 1.500 | 1.500 | 2.895 |
| **Tổng / số file** | **14.680 / 75** | **15.080 / 76** | **18.588 / 103** |

**Đọc bảng này theo cột thứ hai, không theo cột thứ nhất.** Cột mốc được đo ở một cây code
cũ hơn (commit `51a9d75` sửa `machine` sau khi mốc được ghi), nên so `inventory` @HEAD với
nó là so hai cây khác nhau. `tools/dem-dong.ps1` chạy được cho cả hai module ở cùng một
thời điểm, và đó là phép so duy nhất có nghĩa.

Hai sai số của cột mốc, phát hiện khi viết công cụ: sáu hạng mục cộng lại ra **14.680** chứ
không phải 14.700 (dấu `~` là làm tròn), và hàng `migration` ghi 375 trong khi đếm lại ra
377. Công cụ khớp **tuyệt đối** năm trên sáu hạng mục và khớp tuyệt đối 75 file khi chạy
trên đúng cây code sinh ra mốc.

**Điều kiện để con số đó có nghĩa: hai module phải cùng hình dạng.** Đó là lý do mục 2 cắt
`stock_takes` — không phải để chặng nhẹ đi.

| | `machine` | `inventory` |
|---|---|---|
| Bảng nghiệp vụ | 3 | 3 |
| Service | 3 | 3 |
| Endpoint `/api/v1` | 15 | 14 |
| `internal_methods` | rỗng | rỗng |
| `allowed_deps` | `[auth]` | `[]` |

Ba chỗ hai module **không** so sánh được, ghi ra trước để không ai đọc sai con số cuối
chặng:

1. **Màn hình.** `machine` có ba màn và ba màn đó **thiếu đường tạo** — chặng F đo được là
   người dùng không thêm được cái máy đầu tiên qua giao diện (bàn giao chặng F mục 3.2).
   `inventory` làm đủ đường tạo ngay từ đầu, nên nó có nhiều màn hơn. Phần dôi ra đó là
   **món `machine` còn nợ**, không phải phần `inventory` làm thừa.
2. **`shared/idempotency`.** Chặng này phải sửa một hợp đồng ở `shared/` (mục 4). Đó là chi
   phí hạ tầng, không phải chi phí module — đếm riêng, không cộng vào bảng trên.
3. **Lệnh nạp `units`.** Cùng lý do (mục 3.2).

**Phép thử của chính mục tiêu này không phải "test xanh".** Nó là: cuối chặng, điền bảng
trên bằng số đếm thật từ một lệnh ghi sẵn ở mục 9, rồi trả lời. Nếu `inventory` **nhanh bất
thường**, bộ khung đáng giá. Nếu nó **chậm và phải nới rule liên tục**, thì đó là điều đáng
biết hơn nhiều so với việc canh thêm một mệnh đề nữa — và chặng H phải bắt đầu từ chỗ đó
chứ không từ `purchasing`.

---

## 2. Phạm vi

**Làm:**

| Thành phần | Lý do bắt buộc |
|---|---|
| `migrations/000015..000017` — `warehouses`, `stock_items`, `stock_movements` | Ba bảng của kho, danh mục vật tư, và sổ chuyển động |
| `migrations/000018` — nới `idempotency_keys` | Mục 4. Không có nó thì `POST /stock-movements` **không** thi hành nổi hợp đồng đã ghi ở C-API-07 bảng 5 |
| `shared/idempotency` — hợp đồng mới | Cùng mục 4 |
| `modules/inventory/**` | Module nghiệp vụ thứ ba |
| `shared/errors` — `ERR_INVENTORY_*` | Mã là hợp đồng; khai hằng trước khi service dùng (C-API-05) |
| `cmd/internal/vaitro` — permission mới | Một permission không vai trò nào cấp được là một quyền im lặng (C-GO-08) |
| `cmd/dev seed-units` | Mục 3.2 — không có nó thì không tạo được vật tư đầu tiên |
| `frontend-erp` — sáu màn của `inventory` | Mục 7 |
| `docs-erp` — ADR-0018, bảng mã lỗi, C-API-07 bảng 5, sửa một chỗ C-DB-04 nói sai | Mục 8 |

**KHÔNG làm, và lý do:**

**`stock_takes` / kiểm kê — hoãn, có điều kiện mở lại.** Đây là món bị cắt lớn nhất, và
`pham-vi-he-thong.md` mục 1 có tên nó ở cột "bảng chính dự kiến" của `inventory`. Cột đó
**sửa được không cần ADR** (chính file đó ghi vậy, và ADR-0017 cố ý không khóa nó). Hai lý
do để cắt, xếp theo sức nặng:

- **Nó phá phép đo của mục 1.** Năm bảng, bốn service và hai mươi tư endpoint so với ba
  bảng của `machine` cho ra một con số không đọc được: lớn hơn thì là vì bộ khung tệ, hay
  vì module to hơn? Câu hỏi mà chặng này sinh ra để trả lời sẽ mất câu trả lời.
- **Lỗ nó bịt đã có đường bịt rẻ hơn.** Kiểm kê tồn tại để đưa sổ về khớp thực tế; ở đây
  `kind = 'dieu_chinh'` làm đúng việc đó cho từng dòng. Kiểm kê là **bản gộp, có chứng từ**
  của việc ấy — giá trị thật, nhưng là giá trị cộng thêm chứ không phải điều kiện để module
  dùng được.

**Điều kiện mở lại:** ngày có một kho chạy thật cần đối chiếu định kỳ và người vận hành phải
gõ hơn mười dòng `dieu_chinh` một lần. Ngày đó nó là một chặng riêng hoặc một nửa chặng, và
hình dạng bảng `stock_take_lines` sẽ do chính lần đối chiếu đó chốt — cụ thể là câu *"số tồn
hệ thống được chụp lại lúc nào: lúc mở phiếu hay lúc chốt phiếu"*, câu mà hôm nay không ai
có dữ kiện để trả lời.

**Chuyển kho.** Một lần chuyển là **hai** chuyển động phải nguyên tử và phải gỡ được cùng
nhau, tức một cột nối (`transfer_id` hay tự trỏ) mà hình dạng đúng của nó phụ thuộc một câu
chưa ai hỏi: *chuyển kho có nhận thiếu được không*. Có thì nó là một chứng từ có trạng thái,
không thì nó là hai dòng. Chặng này người dùng xuất ở kho A rồi nhập ở kho B bằng hai thao
tác — thô, nhưng không chốt sai một hợp đồng.

**Giá vốn, giá trị tồn kho.** `stock_movements` **không có cột tiền nào**. Chốt phương pháp
tính giá vốn (bình quân, FIFO, đích danh) hôm nay là chốt bằng phỏng đoán: giá thật vào hệ
thống ở chặng H cùng `purchasing`, và chính module đó là bên biết một con số tiền trên dòng
nhập kho nghĩa là gì. Hệ quả phải chấp nhận và phải nói ra: **màn tồn kho của chặng này hiện
số lượng, không hiện tiền.** Đó là lý do chặng này không đụng `decimal` ở đường tiền — nhưng
vẫn đụng `decimal` ở đường số lượng, xem mục 5.

**Nợ đường event — dead-letter, gauge tồn đọng, job dọn, rate limit, HC-02.** Bàn giao chặng
F mục 5 đề nghị gộp cả năm vào chặng G. Bàn giao chuẩn bị chặng G (viết sau, cùng ngày) đề
nghị `inventory`. Chọn bản sau, và lý do không phải "nó mới hơn": ba món đầu là **hạ tầng
cho hai module hiện có**, còn hệ thống thì còn mười module chưa dựng. `pham-vi-he-thong.md`
mục 4 đã nói thẳng điều đó. Trộn nửa chặng hạ tầng vào chặng đo lường là làm hỏng đúng phép
đo mà chặng này tồn tại để chạy.

Cái giá phải trả, ghi ra chứ không giấu: **`cmd/relay` vẫn im lặng hoàn toàn khi chết**, và
nay có thêm một module nữa chạy trên nó. Nợ này già thêm một chặng.

**Cấp số chứng từ.** `stock_movements` **không có cột `code`**. Một chuyển động kho không
phải chứng từ mà là một dòng sổ; chứng từ (phiếu nhập, phiếu xuất) là thứ `purchasing` và
`sales` mang tới. Nên `document_counters` vẫn chưa cần, và ADR của nó vẫn đúng hạn "trước
chặng H".

**Nạp `currencies` và `provinces`.** `inventory` không trỏ tới bảng nào trong hai bảng đó
(mục 3.1 giải thích vì sao `warehouses` không có `province_id`). Nạp chúng lúc chưa ai đọc
là làm một việc rồi để nguyên đó.

**Màn tạo máy của `machine`** (nợ ở bàn giao chặng F mục 3.2). Nợ của module khác, không
phải của chặng này. Nó có tên ở đây vì mục 1 dùng nó để giải thích chênh lệch số màn.

---

## 3. Schema

Cả ba đều là **bảng nghiệp vụ** — không tên nào có trong bốn danh sách miễn trừ của C-DB-04
— nên cả ba mang đủ `company_id`, ba cột thời gian, hai cột audit, và chịu soft delete
(R-06, R-08, R-17, R-18). Cả ba tên kết thúc bằng `s` nên không cần ADR bổ sung
`naming_exempt` — lưu ý đây là chỗ suýt vấp: C-DB-01 lấy đúng chữ `inventory` làm ví dụ cho
tên **không** khớp regex của R-08. `inventory` ở đây là tên **module**, không phải tên bảng,
và ranh giới module do `module.yaml` khai chứ không do tên bảng (C-DB-01).

### 3.1 `warehouses`

```sql
-- 000015_create_warehouses.up.sql
warehouses(
  id, company_id,
  code TEXT NOT NULL,            -- ma kho, duy nhat trong cong ty
  name TEXT NOT NULL,
  address TEXT NOT NULL DEFAULT '',
  created_at, updated_at, deleted_at, created_by, updated_by)

uq_warehouses_company_id_code       (company_id, code) WHERE deleted_at IS NULL
idx_warehouses_company_id_created_at (company_id, created_at) WHERE deleted_at IS NULL
```

`address` là `TEXT` chứ **không** phải `province_id REFERENCES provinces(id)`, và đó là một
quyết định chứ không phải chỗ làm nhanh: bảng `provinces` đang **rỗng** (bàn giao chuẩn bị
mục 3.1 — chưa ai quyết đường nạp), nên một khóa ngoại trỏ tới nó là một cột không ghi được,
và cả module sẽ bị chặn bởi một câu hỏi không thuộc về nó. Cùng lập luận mà chặng C dùng để
không cho `breakdowns.repair_cost` một `currency_id`.

**Không có `is_active`.** Một kho hoặc tồn tại hoặc đã xóa mềm; "tạm ngưng nhận hàng" là một
trạng thái chưa ai đòi.

### 3.2 `stock_items`

```sql
-- 000016_create_stock_items.up.sql
stock_items(
  id, company_id,
  unit_id UUID NOT NULL REFERENCES units(id),
  code TEXT NOT NULL,            -- ma vat tu, duy nhat trong cong ty
  name TEXT NOT NULL,
  created_at, updated_at, deleted_at, created_by, updated_by)

uq_stock_items_company_id_code    (company_id, code) WHERE deleted_at IS NULL
idx_stock_items_company_id_unit_id (company_id, unit_id) WHERE deleted_at IS NULL
idx_stock_items_company_id_created_at (company_id, created_at) WHERE deleted_at IS NULL
```

`unit_id` là khóa ngoại khác `company_id` nên R-09 đòi nó là cột thứ hai của một index
composite mở đầu bằng `company_id`.

**Đây là lần đầu ngoại lệ `reference_tables` của R-02 được dùng thật.** `units` có tên trong
`reference_tables` ở C-DB-04, nên repository của `inventory` được phép nêu tên nó và được
phép JOIN sang nó để hiện tên đơn vị tính. Cho tới hôm nay ngoại lệ đó là một dòng văn bản
chưa câu SQL nào đi qua.

**Và đây là chỗ chặng G gặp một thứ bị chặn thật.** `units` có bảng nhưng **rỗng** — bàn
giao chuẩn bị mục 3.1 nói nó "không chặn chặng G, chỉ chặn màn hình nhập vật tư đầu tiên".
Chặng G **làm** màn hình đó, nên nó bị chặn. Đường ra rẻ nhất trong hai đường mà mục 3.1 nêu:
một lệnh `cmd/dev seed-units` theo đúng khuôn `bootstrap-user` — mở transaction, ghi `units`,
ghi `audit_logs` trong **cùng** transaction với `system_actor_id` làm actor (R-17), và
**không** dùng câu `INSERT` trong migration. Lý do không chọn đường ADR nới ngoại lệ R-17:
ngoại lệ hiện có được cấp cho `000001_create_companies` bằng một lý do **đã hết hạn**
(`audit_logs` khi đó chưa tồn tại — nó tồn tại từ `000004`), nên mở rộng nó là kéo dài một
ngoại lệ mà tiền đề của nó đã mất.

Lệnh này **không** giải quyết `currencies` và `provinces` — xem mục 2. Nó cũng không phải một
module: `reference_tables` cố ý không có module chủ (`pham-vi-he-thong.md` mục 3), nên nó ghi
qua một repository nhỏ ở `cmd/internal/`, không qua `modules/`.

### 3.3 `stock_movements` — bảng quan trọng nhất của chặng

```sql
-- 000017_create_stock_movements.up.sql
stock_movements(
  id, company_id,
  warehouse_id  UUID NOT NULL REFERENCES warehouses(id),
  stock_item_id UUID NOT NULL REFERENCES stock_items(id),
  kind        TEXT NOT NULL,             -- nhap | xuat | dieu_chinh, CHECK
  quantity    NUMERIC(18,4) NOT NULL,    -- CO DAU: nhap > 0, xuat < 0
  occurred_at TIMESTAMPTZ NOT NULL,      -- thoi diem NGUOI DUNG khai
  note        TEXT NOT NULL DEFAULT '',
  created_at, updated_at, deleted_at, created_by, updated_by)

idx_stock_movements_company_id_stock_item_id_warehouse_id
    (company_id, stock_item_id, warehouse_id) WHERE deleted_at IS NULL
idx_stock_movements_company_id_warehouse_id  (company_id, warehouse_id)  WHERE deleted_at IS NULL
idx_stock_movements_company_id_occurred_at   (company_id, occurred_at)   WHERE deleted_at IS NULL

ck_stock_movements_kind      CHECK (kind IN ('nhap','xuat','dieu_chinh'))
ck_stock_movements_kind_sign CHECK (
     (kind = 'nhap'  AND quantity > 0)
  OR (kind = 'xuat'  AND quantity < 0)
  OR (kind = 'dieu_chinh' AND quantity <> 0))
```

**`quantity` có dấu, và đó là quyết định thiết kế chính của module.** Đường còn lại — số
dương cộng một cột chiều — buộc **mọi** câu tính tồn phải mang một biểu thức
`CASE kind WHEN 'xuat' THEN -qty ELSE qty END`. Một câu quên nó thì tồn kho ra sai mà không
gì đỏ, và số quên đó không lộ ra cho tới khi có người đọc sổ. Cột có dấu dồn toàn bộ luật đó
vào **một** `CHECK` mà database cưỡng chế, và biến câu tính tồn thành `SUM(quantity)` trần —
không còn chỗ nào để quên.

`ck_stock_movements_kind_sign` là ràng buộc đáng giá nhất của chặng: nó làm cho *"một dòng
`xuat` mang số dương"* trở thành thứ **không tồn tại được**, chứ không phải thứ service phải
nhớ kiểm.

**`occurred_at` là bẫy đã có tiền lệ.** `breakdowns.occurred_at` mang nghĩa *thời điểm sự
việc xảy ra do người dùng khai*, khác `created_at` là *lúc dòng được ghi*, và
`machine/docs/Events.md` mục 0 đã ghi ra vì sao hai giá trị đó không được lẫn. Ở đây hệ quả
nặng hơn một bậc: tồn kho **tại một thời điểm** đọc theo `occurred_at`, còn thứ tự ghi sổ đọc
theo `created_at`. Nhập một phiếu lùi ngày làm đổi tồn của quá khứ — và đó là hành vi **đúng**,
không phải lỗi.

### 3.4 Tồn kho là số dư tính ra, không phải một cột được UPDATE

**Không có bảng `stock_balances`.** Tồn của một cặp (kho, vật tư) là
`SUM(quantity)` trên `stock_movements`, lọc theo `company_id`, `deleted_at IS NULL`, và
`occurred_at <= $tinh_den` khi hỏi tồn tại một thời điểm.

Hai đường, và đường kia không sai — nó chỉ đắt sớm:

| | Số dư tính ra | Cột `on_hand` được UPDATE |
|---|---|---|
| Nguồn sự thật | Một | Hai, và chúng lệch được mà không gì đỏ |
| Sửa một dòng ghi sai | Tồn tự đúng | Phải nhớ sửa cả hai, đúng thứ tự |
| Tồn tại một thời điểm quá khứ | Có sẵn | Không có, phải dựng lại |
| Chi phí đọc | `SUM` trên N dòng | Một `SELECT` |
| Chỗ tranh chấp ghi | Không có hàng nào để khóa (mục 3.5) | Chính hàng đó |

Kiểu hỏng của đường thứ hai là kiểu hỏng tệ nhất mà dự án này đã đặt tên nhiều lần: **hai bản
mô tả cùng một thứ, lệch nhau, không báo lỗi ở đâu cả.**

**Điều kiện mở lại — và nó là một con số, không phải một cảm giác:** ngày một câu tính tồn
cho một cặp (kho, vật tư) vượt **200 ms** trên dữ liệu thật. Ngày đó câu trả lời đúng là một
**hình chiếu** (bảng `stock_balances` do chính `stock_movements` sinh ra, có thể dựng lại từ
đầu bất cứ lúc nào), **không** phải một cột `on_hand` do service tự cộng trừ. Sự khác nhau là
thứ giữ cho "một nguồn sự thật" còn nguyên.

### 3.5 Không cho âm tồn, và đây là ca tranh chấp ghi đầu tiên của hệ thống

Một lệnh `xuat` làm tồn xuống dưới 0 bị từ chối `409 ERR_INVENTORY_INSUFFICIENT_STOCK`.

Không có bảng số dư nghĩa là **không có hàng nào để `SELECT ... FOR UPDATE`**, nên hai lệnh
xuất đồng thời cùng đọc tồn 10, cùng xuất 8, cùng thấy hợp lệ, và cùng commit → tồn `-6`.
`CHECK` không cứu được: nó nói về **một hàng**, còn tồn là thuộc tính của một **tập hợp**.

Cách chặng này chọn: mở transaction, rồi

```sql
SELECT id FROM stock_items
 WHERE id = $1 AND company_id = $2 AND deleted_at IS NULL
 FOR UPDATE
```

trước khi tính tồn. Nó tuần tự hóa mọi chuyển động của **một vật tư**, ở mọi kho.

Ba điều phải nói kèm, vì mỗi điều là một chỗ dễ làm sai về sau:

- **Khóa trên `stock_items`, không trên `warehouses`.** Tranh chấp thật nằm ở vật tư: hai
  người xuất cùng một mã hàng. Khóa kho là khóa một thứ mà mọi thao tác đều đi qua — tức tuần
  tự hóa cả kho vì một dòng.
- **Thô hơn mức cần, và cố ý.** Khóa đúng phải là (kho, vật tư). Không có hàng nào mang đúng
  cặp đó, nên đường tinh hơn là `pg_advisory_xact_lock` trên một băm của cặp — đổi lấy một
  khóa **không tra ra được từ schema** và một xác suất đụng băm không ai đo. Chọn thô, ghi lý
  do, và nêu điều kiện mở lại: ngày `stock_balances` ở mục 3.4 ra đời thì khóa đúng chỗ tự
  xuất hiện, vì lúc đó có một hàng mang đúng cặp (kho, vật tư).
- **`dieu_chinh` âm cũng chịu kiểm này.** Điều chỉnh xuống dưới 0 vẫn là tồn âm. Ngoại lệ duy
  nhất không tồn tại — nếu tồn thật sự âm ngoài đời thì sổ đang sai ở chỗ khác, và đường sửa
  là tìm dòng thiếu chứ không phải cho phép sổ âm.

---

## 4. Câu hỏi phải trả lời trước dòng code đầu tiên: `Idempotency-Key`

Cùng dạng với câu hỏi `R-19` của chặng E và `P-OBS` của chặng F. Ở đây nó không phải một câu
hỏi mở — nó là một **hợp đồng đã ghi mà repo không thi hành nổi**, và chặng G là chặng đầu
tiên buộc phải thi hành.

**Hợp đồng đã có, ở C-API-07 bảng 5:** mọi handler `POST` sinh bút toán tiền, **chuyển động
kho**, hoặc cấp số chứng từ phải đọc header `Idempotency-Key`. Ba ca, ba hành vi
(C-API-http.md mục "Idempotency"):

| Ca | Phải trả |
|---|---|
| Thiếu header | `422 ERR_COMMON_IDEMPOTENCY_KEY_MISSING` |
| Trùng khóa, **cùng** payload | **Chính response của lần đầu** — cùng `201`, cùng body, cùng id |
| Trùng khóa, **khác** payload | `422 ERR_COMMON_IDEMPOTENCY_KEY_REUSED` |

**Repo hôm nay:** bảng 5 rỗng; không handler sản phẩm nào chứa chuỗi `Idempotency-Key`;
`shared/middleware/cors` cho header đi qua kèm một comment nói rõ backend *chưa* thi hành;
chữ ký là `Claim(ctx, db, companyID, key string) (bool, error)`.

**Chữ ký đó không thi hành nổi hai hàng cuối của bảng trên**, và không phải vì cài đặt thiếu
mà vì **bảng thiếu cột**: `idempotency_keys` không giữ dấu vân của payload nên không phân
biệt được hàng 2 với hàng 3, và không giữ response nên không phát lại được. Đáng nói hơn:
doc của chính package đó khai nó phục vụ ca HTTP này, **trỏ đích danh C-API-07 bảng 5**. Đây
lại là một comment nói dối — đúng loại mà `arch/rules.go` từng mang và chặng F đã lấy làm lý
do chọn dữ liệu thay vì văn xuôi.

**Vì sao không hoãn tiếp.** Cho `machine`, một lần gửi lại `POST /breakdowns` sinh một dòng
nhật ký thừa — thấy được, xóa được. Cho `inventory`, một lần gửi lại `POST /stock-movements`
xuất **hai** lần cùng một lô hàng, và dấu vết duy nhất là tồn kho ít đi đúng bằng số hàng
chưa ai lấy. Không màn hình nào đỏ. Đó là ranh giới giữa một nợ và một lỗi dữ liệu.

**Hình dạng chọn — `ADR-0018`:**

```
migration 000018: ALTER TABLE idempotency_keys
  ADD COLUMN request_hash    TEXT  NOT NULL DEFAULT '',
  ADD COLUMN response_status INT   NOT NULL DEFAULT 0,
  ADD COLUMN response_body   JSONB;

ClaimOrLoad(ctx, db, companyID, key, requestHash string, resp Response) (Ket, error)
  Ket.GianhDuoc   bool    // true: lan dau, nguoi goi chay tiep hieu ung
  Ket.RequestHash string  // cua lan dau, de so sanh
  Ket.Status      int
  Ket.Body        []byte
```

Ba ràng buộc của bảng cũ được giữ nguyên, và mỗi cái ép một điều lên hình dạng này:

- **Vẫn `append_only_tables`, vẫn ghi đúng MỘT lần.** Comment ở `000010` nói thẳng: không có
  `updated_at` nên không có mẫu "claim trước rồi UPDATE kết quả sau". Hệ quả: **response phải
  biết được trước khi ghi**, nên service sinh `id` của chuyển động bằng Go và đặt `created_at`
  bằng đồng hồ ứng dụng thay vì `gen_random_uuid()` / `now()` của database. Hệ thống chạy một
  instance (ADR-0013) nên không có lệch đồng hồ giữa các tiến trình ghi.
- **Vẫn chạy trong CHÍNH transaction của hiệu ứng.** `DBTX` cố ý không có `BeginTxx`, nên chữ
  ký là hàng rào duy nhất và nó được giữ nguyên.
- **Vẫn là câu lệnh đầu tiên của phần nghiệp vụ (P-IDEM).** Băm payload và dựng DTO **không
  phải hiệu ứng** — không chạm database, không đổi gì — nên chúng đứng trước mà không phá vế
  đó. Tiền lệ đã có và đã viết ra: bước giải mã payload đứng trước bước claim ở subscriber của
  `machine` (`machine/docs/Events.md`).

**`Claim` cũ giữ lại hay bỏ?** Bỏ, và cho subscriber `auth.user.deleted` gọi `ClaimOrLoad` với
`requestHash` rỗng và response rỗng. Hai hàm cùng đọc một bảng với hai luật khác nhau là chỗ
lệch sẽ lớn dần — đúng thứ mà chặng F đã trả giá với hai bản `compose.dev.yml`.

**`request_hash` băm cái gì:** thân JSON đã chuẩn hóa của request, SHA-256, hex. **Không** băm
header, **không** băm actor — cùng một người gửi lại cùng một thân là ca hàng 2; hai người
khác nhau trùng khóa trong cùng công ty là ca hàng 3, và `422` là câu trả lời đúng cho họ.

**Phạm vi thi hành ở chặng này: đúng một endpoint** — `POST /api/v1/stock-movements`. Đó là
endpoint duy nhất của repo khớp mệnh đề "sinh chuyển động kho". Nới ra `POST /machines` hay
`POST /users` **không** phải việc của chặng G: bảng 5 là một danh sách nghĩa vụ theo mệnh đề,
không phải một mặc định toàn cục, và mỗi dòng thêm vào nó là một hợp đồng công khai với
frontend.

---

## 5. Module `inventory`

```text
modules/inventory/
├── api/dto.go                    StockItemDTO - hop dong cho module sau (H, I, K)
├── internal/
│   ├── model/                    warehouse.go, stock_item.go, stock_movement.go
│   ├── repository/               ba repository, SQL hang chuoi don (C-GO-07)
│   ├── service/                  warehouse_service.go, stock_item_service.go,
│   │                             movement_service.go, permissions.go
│   └── handler/                  ba handler + ba file route
├── module.go                     New/Register, xuat lai permission (C-GO-08)
└── module.yaml                   tables, allowed_deps: [], internal_methods: []
```

### 5.1 `allowed_deps: []` — module nghiệp vụ đầu tiên không phụ thuộc module nào

Không thao tác nào của `inventory` cần hỏi một module khác một câu. Không có cột "người phụ
trách" nên không có lời gọi `UserReader` như `machine`; `units` là `reference_tables` nên đọc
nó **không** phải một cạnh phụ thuộc (R-02 ngoại lệ); `shared/authz` không nằm dưới `modules/`.

Rỗng là một **câu trả lời**, và nó là câu trả lời đúng cho câu hỏi mà `CL-NEWMOD-02` bắt hỏi
trước: *nếu việc kia hỏng, việc này còn được coi là đã xong không?* Ở đây không có "việc kia".

`pham-vi-he-thong.md` mục 4 nói `inventory` đi trước vì nó không phụ thuộc module nghiệp vụ
nào; `module.yaml` của nó là chỗ điều đó thành một khai báo máy đọc được.

**Một vùng mù phải đo, không phải đoán** (mục 9): thêm một tên **thừa** vào `allowed_deps` có
bị bắt không? `C-GO-05` vế 4 đối chiếu hai chiều cho `internal_methods`, nhưng `allowed_deps`
thì chưa ai thử. Nếu không bắt, đó là một vùng mù có tên — ghi ra, không tự vá trong chặng này.

### 5.2 `internal_methods: []`, và vì sao `MovementService` không gọi `StockItemService`

`MovementService` cần đọc `stock_items` (để khóa hàng ở mục 3.5 và để kiểm vật tư còn sống),
nên nó giữ `stockItemRepo` **của riêng nó** thay vì gọi `StockItemService`. Lý do y hệt lý do
`MaintenanceService` giữ `machineRepo`: hai repository nhận **cùng** một `*sqlx.Tx` thì hai
lệnh mới là một đơn vị không tách rời; gọi qua một service khác thì service kia tự mở
transaction của nó, và khóa `FOR UPDATE` ở mục 3.5 mất tác dụng ngay tại chỗ — nó sẽ được lấy
rồi nhả **trước** khi lệnh ghi chạy.

### 5.3 Method, kiểm quyền, endpoint

Mọi dòng đều mở đầu bằng `s.authz.Can` (R-15).

| Service | Method | Permission | Endpoint |
|---|---|---|---|
| `WarehouseService` | `ListWarehouses` | `inventory.warehouse_list` | `GET /api/v1/warehouses` |
| | `GetWarehouse` | `inventory.warehouse_read` | `GET /api/v1/warehouses/:id` |
| | `CreateWarehouse` | `inventory.warehouse_create` | `POST /api/v1/warehouses` |
| | `UpdateWarehouse` | `inventory.warehouse_update` | `PATCH /api/v1/warehouses/:id` |
| | `DeleteWarehouse` | `inventory.warehouse_delete` | `DELETE /api/v1/warehouses/:id` |
| `StockItemService` | `ListStockItems` | `inventory.item_list` | `GET /api/v1/stock-items` |
| | `GetStockItem` | `inventory.item_read` | `GET /api/v1/stock-items/:id` |
| | `CreateStockItem` | `inventory.item_create` | `POST /api/v1/stock-items` |
| | `UpdateStockItem` | `inventory.item_update` | `PATCH /api/v1/stock-items/:id` |
| | `DeleteStockItem` | `inventory.item_delete` | `DELETE /api/v1/stock-items/:id` |
| `MovementService` | `ListMovements` | `inventory.movement_list` | `GET /api/v1/stock-movements` |
| | `GetMovement` | `inventory.movement_read` | `GET /api/v1/stock-movements/:id` |
| | `RecordMovement` | `inventory.movement_create` | `POST /api/v1/stock-movements` |
| | `ListBalances` | `inventory.balance_read` | `GET /api/v1/stock-balances` |

Mười bốn endpoint, **không** dòng nào dùng dạng `/actions/<verb>` — module này không có máy
trạng thái, nên sổ đăng ký C-API-07 bảng 1 không có dòng mới. Bảng **5** thì có một dòng, dòng
đầu tiên của nó.

**Không có endpoint sửa hay xóa `stock_movements`.** Một dòng sổ đã ghi là một việc đã xảy ra;
sửa nó là sửa lịch sử. Đường đúng để chữa một dòng ghi sai là một dòng `dieu_chinh` ngược lại,
và đó chính là lý do `kind` có giá trị thứ ba. Bảng vẫn có `deleted_at` vì nó là bảng nghiệp vụ
và R-18 không cấp miễn trừ theo ý muốn — chỉ là chưa có đường nào set cột đó, đúng khuôn
`breakdowns` của chặng C.

**`GET /api/v1/stock-balances`** nhận `warehouse_id` và `stock_item_id` làm bộ lọc tùy chọn,
`tinh_den` (RFC 3339, tùy chọn, mặc định *bây giờ*) làm mốc thời điểm, và chịu R-12 đầy đủ:
`page`, `page_size`, `sort`, `meta.total`. Nó là endpoint list trả **dữ liệu tính ra**, không
phải hàng của một bảng — R-12 không cấp ngoại lệ cho điều đó, và không nên: một danh sách tồn
kho dài hơn một trang là chuyện bình thường.

### 5.4 Số lượng đi qua `decimal`, không bao giờ qua `float64`

`quantity` là `NUMERIC(18,4)` theo C-DB-02 (*"số lượng hàng cân đo"* — cùng hàng với tiền), ở
Go là `decimal.Decimal`, ra JSON dưới dạng **chuỗi** (`"12.5000"`). Kể cả trong test.

Chặng C đã đặt khuôn này cho đường tiền; chặng G là lần đầu nó áp cho đường **số lượng**, và
đó là chỗ dễ trượt nhất: một cân hàng 12,5 kg trông như một con số vô hại, còn `SUM` của một
triệu dòng như thế qua `float64` thì không.

### 5.5 Mã lỗi

| Mã | HTTP | Khi nào |
|---|---|---|
| `ERR_INVENTORY_CODE_DUPLICATED` | `409` | Vi phạm `uq_warehouses_company_id_code` hoặc `uq_stock_items_company_id_code` |
| `ERR_INVENTORY_INSUFFICIENT_STOCK` | `409` | Chuyển động làm tồn của cặp (kho, vật tư) xuống dưới 0 |
| `ERR_INVENTORY_UNIT_INVALID` | `422` | `unit_id` không phải một đơn vị tính còn sống |
| `ERR_INVENTORY_ITEM_OR_WAREHOUSE_INVALID` | `422` | `stock_item_id` hoặc `warehouse_id` không phải bản ghi còn sống **của công ty actor** |

Bốn mã, không hơn. `404`, `403`, `422` hình dạng request, `409` xung đột phiên bản, và cả ba
mã `IDEMPOTENCY` đều dùng mã `COMMON` đã có.

Hàng cuối theo đúng tiền lệ `ERR_MACHINE_ASSIGNEE_INVALID` của chặng C: một id trỏ tới bản ghi
của công ty khác trả **cùng** mã đó, **không** phải `404` — thứ không tồn tại ở đây là một giá
trị trong request chứ không phải tài nguyên trên URL.

---

## 6. Event: module này không phát và không nghe

Mục 1 và mục 2 của `inventory/docs/Events.md` đều **rỗng**, và cả hai rỗng vì cùng một lý do
đã thành luật ở `machine/docs/Events.md`: **chưa có ai nghe.**

`purchasing` (chặng H) và `sales` (chặng I) phụ thuộc `inventory` **qua event**
(`pham-vi-he-thong.md` mục 1), và chiều của cạnh đó là chiều **vào**: một phiếu nhập kho được
xác nhận ở `purchasing` sẽ phát một event mà `inventory` nghe. Bên phát chưa tồn tại, nên bên
nghe cũng chưa viết được — hình dạng payload là thứ **bên phát** quyết.

Ứng viên phát, ghi ở mục 3 của `Events.md` để chặn xu hướng phát event "để sau này dùng":
`inventory.movement.recorded` (consumer tự nhiên là `accounting` ở chặng O và `reporting` ở
chặng P — cả hai chưa tồn tại, và chính chúng sẽ quyết định payload mang gì: chỉ số lượng, hay
cả giá trị mà chặng này cố ý không có).

Hệ quả cho `module.yaml`: **không** có `internal/subscriber/`. `CL-NEWMOD-02` cho phép package
đó nhưng không đòi.

---

## 7. Frontend

Sáu màn, và số này lớn hơn ba màn của `machine` vì một lý do đã nói ở mục 1: `machine` **thiếu**
đường tạo.

| Màn | Đường | Ghi chú |
|---|---|---|
| Danh sách kho | `/kho` | |
| Tạo / sửa kho | `/kho/moi`, `/kho/:id` | |
| Danh sách vật tư | `/vat-tu` | Hiện tên đơn vị tính |
| Tạo / sửa vật tư | `/vat-tu/moi`, `/vat-tu/:id` | Chọn đơn vị tính |
| Tồn kho | `/ton-kho` | Chỉ đọc, lọc theo kho và vật tư |
| Ghi chuyển động | `/chuyen-dong/moi` | Nhập / xuất / điều chỉnh |

**Mọi màn phải có đường dẫn tới được từ giao diện.** Chặng F đo được rằng 278 test không bắt
được ngõ cụt của `machine` vì mọi test đều dựng thẳng component cần kiểm, nên không test nào
hỏi *"làm sao người dùng tới được đây"*. Nghiệm thu của chặng này hỏi câu đó bằng một ca đi từ
màn đăng nhập tới màn ghi chuyển động **chỉ bằng cách bấm** (mục 9).

**`R-19` gặp ca thật đầu tiên của vế "tồn kho".** Mệnh đề của R-19 cấm frontend tính *tiền,
thuế, **tồn kho***, và cho tới hôm nay chỉ vế tiền có code đi qua. Luật ESLint
`r19-no-computed-money-in-body` — dù mang chữ `money` trong tên — phân tích **đường đi của một
giá trị vào thân request**, không lọc theo tên biến, nên nó canh vế tồn kho **bằng cấu trúc**
chứ không bằng một danh sách. Điều đó là một **lời khẳng định phải kiểm bằng đột biến**, không
phải một suy luận được nhận (mục 9).

Hai ràng buộc cụ thể của màn ghi chuyển động:

- Form gửi **đầu vào thô** (`warehouse_id`, `stock_item_id`, `kind`, `quantity`,
  `occurred_at`) và render lại tồn mới do backend trả. Hiện *"tồn sau thao tác ≈ X"* lên màn
  là UX chuẩn mực và **không** vi phạm (C-TS-05); gửi con số đó lên mới là vi phạm.
- **`Idempotency-Key` sinh lúc MỞ form, không phải lúc bấm nút** (C-API-07 bảng 5). Sinh lúc
  bấm thì mỗi lần bấm là một khóa mới và toàn bộ cơ chế chạy đúng mà vô dụng. Đây là nửa
  frontend của mục 4, và không có nó thì nửa backend là một cột `request_hash` không ai ghi.

---

## 8. Kéo theo ở `docs-erp`

| Thay đổi | Vì sao |
|---|---|
| **ADR-0018** — lưu response để phát lại cho `Idempotency-Key` ở tầng HTTP | Đổi một hợp đồng ở `shared/` mà mọi module sau đều gọi. Cùng hạng với ADR-0014 (hình dạng dead-letter) |
| C-API-05: bốn dòng `ERR_INVENTORY_*` | Mã là hợp đồng công khai; hằng ở `shared/errors` phải khớp bảng |
| C-API-05 bảng ánh xạ constraint: `uq_warehouses_company_id_code`, `uq_stock_items_company_id_code`, `ck_stock_movements_kind`, `ck_stock_movements_kind_sign` | Constraint không có dòng thì lỗi của nó ra client dưới dạng `ERR_INTERNAL` |
| C-API-07 **bảng 5**: dòng đầu tiên — `POST /api/v1/stock-movements` | Nghĩa vụ chỉ có hiệu lực khi có dòng trong sổ |
| **C-DB-04, blockquote `outbox_dead_letters`: sửa "chặng G" thành "chặng nào viết migration của nó"** | Blockquote đó viết *"chặng G viết migration và biết chính xác cột nào cần UPDATE"*. Chặng G **không** viết migration đó (mục 2), nên câu ấy thành một dòng nói dối ngay khi chặng này merge — đúng loại lệch `RULES.md` vs `C-TS-04` mà chặng E đã dạy |
| `pham-vi-he-thong.md` mục 1: cột "bảng chính dự kiến" của `inventory` bỏ `stock_takes`, thêm một dòng ghi nó hoãn kèm điều kiện mở lại | File đó cho phép sửa cột này không cần ADR, nhưng **không** cho phép để nguyên một dòng sai rồi lên kế hoạch theo nó (câu cuối của file) |

**Không** đổi: `RULES.md` (không rule nào đổi mệnh đề, nên `arch-pin` không phải chạy),
`ADR-0017` (không thêm bớt module), `mockup-dieu-huong.html` (điều kiện hết hạn của nó gắn với
**danh sách và tên module**, cả hai không đổi).

---

## 9. Định nghĩa hoàn thành

**Phép đo — làm trước, không làm sau khi biết kết quả.** Bảng ở mục 1 được điền bằng
`tools/dem-dong.ps1` (viết ở task G1, cùng lệnh cho cả hai module), rồi trả lời câu hỏi
*"module thứ ba tốn bao nhiêu so với 14.700"* bằng một đoạn văn ở bàn giao chặng G — kèm cả
con số thô lẫn con số đã trừ ba khoản không so sánh được ở mục 1.

Phép thử bằng đột biến, mỗi cái phải **đỏ đúng chỗ** rồi hoàn lại:

- **R-02** — một câu SQL trong `inventory/**/repository` nêu tên bảng `machines` → `checkR02`
  đỏ. Và ca ngược: một câu nêu tên `units` → **vẫn xanh**, vì `units` ở `reference_tables`.
  Ca thứ hai quan trọng hơn ca thứ nhất — một checker đỏ cả hai là một checker sẽ bị tắt.
- **R-09** — bỏ `idx_stock_items_company_id_unit_id` khỏi migration → đỏ.
- **R-19 vế tồn kho** — đưa `tonHienTai - soLuongXuat` vào thân request `POST` ở màn ghi
  chuyển động → ESLint đỏ. Rồi để nguyên phép tính đó **trong JSX** → **xanh**. Đây là thứ
  chứng minh mục 7 nói đúng.
- **`ck_stock_movements_kind_sign`** — `INSERT` một dòng `kind='xuat'` với `quantity > 0` thẳng
  vào database → database từ chối.
- **Vùng mù `allowed_deps`** — thêm `auth` vào `allowed_deps` của `inventory` trong khi module
  không import gì của `auth` → chạy `arch`, **ghi lại kết quả thật**. Đỏ thì tốt; xanh thì đó
  là một vùng mù có tên, ghi vào bàn giao, **không** vá trong chặng này.

Hợp đồng `Idempotency-Key`, ba ca của bảng ở mục 4, chạy qua HTTP thật:

- Thiếu header → `422 ERR_COMMON_IDEMPOTENCY_KEY_MISSING`.
- Cùng khóa, cùng payload, gửi hai lần → **hai response giống hệt nhau**: cùng `201`, cùng
  `id`, cùng `created_at`; và `SELECT count(*) FROM stock_movements` tăng **đúng 1**.
- Cùng khóa, payload khác → `422 ERR_COMMON_IDEMPOTENCY_KEY_REUSED`, và không dòng nào được
  ghi.

Tranh chấp ghi (mục 3.5), chạy thật chứ không suy luận: tồn 10, bắn **hai** `POST` xuất 8 song
song → đúng một cái `201`, cái kia `409 ERR_INVENTORY_INSUFFICIENT_STOCK`, và tồn cuối là `2`.
Không dùng đồng hồ để đồng bộ hai request — dùng một điểm hẹn gọi tên được (bài học chặng D).

Ca end-to-end qua database thật: `seed-units` → tạo kho → tạo vật tư → nhập 100 → tồn `100` →
xuất 30 → tồn `70` → xuất 100 → `409` và tồn **vẫn** `70` → điều chỉnh `-70` → tồn `0`.

Còn lại, theo khuôn năm chặng trước:

- Mỗi method public của ba service có ít nhất một test gọi thẳng nó, truyền `auth.Actor` qua
  tham số (CL-NEWMOD-15).
- `modules/inventory/docs/` đủ năm file; `Database.md` khớp **từng dòng** với `tables` của
  `module.yaml`.
- Một ca frontend đi từ màn đăng nhập tới màn ghi chuyển động **chỉ bằng cách bấm** — không
  gõ URL. Đây là câu hỏi mà 278 test của chặng E không hỏi.
- `go run ./cmd/dev check` rồi `test` xanh; `npm run lint && npm run arch && npm test` xanh.
- `arch-update` cho diff **chỉ** gồm cột FILE tăng, không dòng nào hạ mức.
- `check-ids.ps1` xanh cho `docs-erp`.
- Chạy `CL-NEWMOD`, `CL-SCHEMA`, `CL-API` **bằng mắt**.

---

## 10. Rủi ro đã biết

**`SUM` trên `stock_movements` là chỗ chặng này chọn trả sau.** Mục 3.4 khai điều kiện mở lại
bằng một con số (200 ms), và con số đó **chưa ai đo** vì chưa có dữ liệu thật. Rủi ro thật
không phải câu truy vấn chậm — nó là chuyện đến ngày chậm thì đã có ba module khác đọc tồn
kho, và hình chiếu phải dựng dưới áp lực. Thứ giảm nhẹ nó: mọi đường đọc tồn đi qua **một**
method (`MovementService.ListBalances`), nên ngày thay ruột chỉ có một chỗ phải sửa.

**Khóa `FOR UPDATE` trên `stock_items` tuần tự hóa nhiều hơn mức cần.** Hai kho khác nhau xuất
cùng một mã hàng vẫn phải xếp hàng. Chấp nhận được hôm nay vì chưa có tải; nó xấu đi **theo số
kho**, không theo số dòng — nên dấu hiệu phải canh là "một công ty mở kho thứ ba, thứ tư", chứ
không phải một ngưỡng CPU.

**Sửa `shared/idempotency` động vào một đường đang chạy thật.** Subscriber `auth.user.deleted`
là người dùng duy nhất của `Claim` hôm nay, và nó là thứ giữ cho quan hệ bất đồng bộ đầu tiên
của hệ thống không nhân đôi hiệu ứng. Đổi chữ ký của nó mà làm hỏng nhánh đó thì cái hỏng
**không** lộ ra ở test của `inventory`. Ràng buộc cứng cho chặng: `TestClaimLanDauGianhDuocLanHaiThiKhong`
và `TestClaimCuonNguocCungTransaction` phải **vẫn xanh sau khi đổi**, và nếu chúng phải sửa thì
phải nêu lý do trong PR chứ không sửa cho qua.

**Đặt `created_at` bằng đồng hồ ứng dụng là một lệch khỏi khuôn.** Mọi bảng khác lấy `now()`
của database. Mục 4 giải thích vì sao ở đây không lấy được, và ADR-0013 (một instance) là thứ
làm cho nó an toàn hôm nay. Ngày có instance thứ hai — điều kiện mở lại của chính ADR-0013 —
câu này phải được đọc lại, vì hai tiến trình ghi bằng hai đồng hồ vào cùng một sổ là chỗ thứ
tự dòng sổ ngừng đáng tin.

**Ba bảng, mười bốn endpoint, sáu màn — và một cám dỗ gộp.** Một `InventoryService` làm cả kho,
vật tư và chuyển động sẽ ngắn hơn ở lần viết đầu và không tách ra được ở lần thứ hai. Ba service
tách theo ba bảng, và `internal_methods: []` là thứ giữ điều đó.

**Nợ `relay` già thêm một chặng** (mục 2). Ghi lại ở đây vì đó là cái giá thật của việc chọn
`inventory` thay vì gộp nợ outbox, và người đọc bàn giao chặng G phải thấy nó chứ không phải
tự tìm ra.
