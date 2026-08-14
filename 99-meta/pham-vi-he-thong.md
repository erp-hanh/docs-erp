# Phạm vi hệ thống — danh sách module

**File này tồn tại vì sáu chặng đầu đã chạy mà không ai viết ra đích đến.** Chặng A–F
xây khung, bộ canh và vận hành; không tài liệu nào nói chúng đang phục vụ bao nhiêu
module. Hệ quả đo được: câu hỏi *"còn bao nhiêu chặng nữa"* không ai trả lời được từ repo.

Nó **không** phải Rule, không phải ADR, và không cưỡng chế điều gì. Nó là bản đồ để lên
kế hoạch, và **nó được phép sửa** — khác hẳn tầng Decision. Mỗi ranh giới module khi
thật sự dựng vẫn phải đi qua `06-checklists/CL-NEWMOD-new-module.md`, và khi ranh giới
đó gây tranh cãi thì qua một ADR riêng.

**Có một bản vẽ của file này:** [mockup-dieu-huong.html](mockup-dieu-huong.html) — mở
bằng trình duyệt, không cần chạy gì. Nó dựng mười hai phân hệ thành giao diện bấm được,
kèm sơ đồ quy trình nghiệp vụ cho tám phân hệ và bốn tài khoản thử để thấy danh sách đổi
theo phân quyền. Dùng nó để **kiểm chứng phạm vi với người dùng thật trước khi viết
migration đầu tiên**: một dòng sai phát hiện ở đó tốn một dòng sửa markdown, phát hiện ở
chặng G tốn một migration đã merge mà R-07 không cho sửa.

File đó có **điều kiện hết hạn ghi ở đầu nó** và phải đổi cùng PR với file này khi danh
sách hoặc tên module đổi — hai bản mô tả cùng một thứ mà lệch nhau là đúng kiểu lỗi
`RULES.md` vs `C-TS-04` đã dạy ở chặng E.

**Trạng thái mỗi dòng, đọc trước khi tin bất cứ dòng nào:**

| Ký hiệu | Nghĩa |
|---|---|
| `CÓ` | Đã tồn tại trong code, chạy được |
| `CHỐT` | Phạm vi đã được người quyết xác nhận, chưa có code |
| `ĐỀ XUẤT` | Suy ra từ phạm vi ERP điển hình, **chưa ai xác nhận từng bảng** |

---

## 1. Danh sách module

| # | Module | Trạng thái | Bảng chính dự kiến | Phụ thuộc | Chặng |
|---|---|---|---|---|---|
| 1 | `auth` | `CÓ` | `users`, `refresh_tokens` | — | B |
| 2 | `machine` | `CÓ` | `machines`, `maintenance_plans`, `breakdowns` | `auth` | C |
| 3 | `inventory` | `CHỐT` | `warehouses`, `stock_items`, `stock_movements`, `stock_takes` | — | G |
| 4 | `purchasing` | `CHỐT` | `suppliers`, `purchase_orders`, `purchase_order_lines`, `goods_receipts` | `inventory` (qua event) | H |
| 5 | `sales` | `CHỐT` | `customers`, `sales_orders`, `sales_order_lines`, `deliveries` | `inventory` (qua event) | I |
| 6 | `yard` | `CHỐT` (phạm vi) | `containers`, `yard_slots`, `service_orders`, `storage_charges` | `machine`, `sales` | J |
| 7 | `production` | `CHỐT` | `production_orders`, `boms`, `bom_lines`, `work_steps` | `inventory`, `machine` | K |
| 8 | `hr` | `CHỐT` | `employees`, `departments`, `positions`, `labor_contracts`, `dependents` | `auth` | L |
| 9 | `attendance` | `CHỐT` | `shifts`, `shift_assignments`, `timesheets`, `overtimes`, `leaves`, `leave_balances`, `holidays` | `hr` | M |
| 10 | `payroll` | `CHỐT` | `payroll_periods`, `salary_components`, `payroll_runs`, `payslips`, `payslip_lines`, `insurance_rates`, `tax_brackets` | `hr`, `attendance` | N |
| 11 | `accounting` | `CHỐT` (phạm vi cơ bản) | `invoices`, `payments`, `receivables`, `payables` | `purchasing`, `sales`, `yard`, `payroll` | O |
| 12 | `reporting` | `ĐỀ XUẤT` | — (chỉ đọc) | mọi module | P |

**Tập mười hai module này và quy tắc đặt tên tiếng Anh được chốt ở
[ADR-0017](../03-decisions/ADR-0017-muoi-hai-module-va-ten-tieng-anh.md).** Thêm hoặc bớt
một module là đổi quyết định đó, tức cần ADR mới. Còn **cột "bảng chính dự kiến", thứ tự
chặng và ước lượng khối lượng trong file này thì sửa được không cần ADR** — ADR-0017 cố ý
không khóa chúng.

Tên tiếng Anh chỉ áp cho thư mục, `module.yaml` và đường import. Giao diện người dùng và
tài liệu vẫn tiếng Việt: `payroll` hiện ra màn hình là "Tính lương", `yard` là "Bãi
container".

**Không có module `kalmar`.** [ADR-0016](../03-decisions/ADR-0016-kalmar-dung-chung-machine.md)
chốt xe nâng container dùng chung `machine`, và ghi rõ hai điều kiện mở lại. Đừng thêm
lại dòng đó vào bảng trên mà không đọc ADR đó trước.

**Ước lượng khối lượng.** Mốc đo được từ `machine` — module nghiệp vụ đầy đủ duy nhất
tới giờ, ba thực thể: **~14.700 dòng / 75 file** (backend 4.925 src + 4.269 test, docs
module 1.188, migration 375, frontend 2.423 src + 1.500 test).

Mười chặng còn lại ≈ **145–185k dòng**, tức gấp 8–10 lần toàn bộ phần mềm chạy thật hiện
có (~17.300 dòng). `payroll` nhân khoảng 1,5 lần mốc trên vì phần lớn khối lượng của
nó là quy tắc tính toán phải đúng tới từng đồng và phải tái lập được, không phải CRUD.
Báo cáo không theo mốc này vì nó cắt ngang, không theo khuôn `CL-NEWMOD`.

## 2. Những module đã chốt phạm vi

### 2.1 `yard` — dịch vụ khai thác cảng là miền kinh doanh, không phải chỗ đặt thiết bị

Doanh nghiệp **kinh doanh** dịch vụ cảng: nâng hạ container, cho thuê bãi, thu cước lưu
bãi. Đây là một nguồn doanh thu, ngang hàng với xưởng cơ khí — không phải một biến thể
của quản lý thiết bị.

Ranh giới với `machine` vì vậy rất rõ và phải giữ: `machine` trả lời *"xe nâng này là
xe nào, bảo trì tới đâu, hỏng lần nào"*; `yard` trả lời *"container này nằm ở ô nào, ai
gửi, nằm bao lâu, tính bao nhiêu tiền"*. Xe Kalmar xuất hiện trong `yard` chỉ như **id
của thiết bị thực hiện một lệnh dịch vụ**, đọc qua `modules/machine/api/`, không JOIN
sang bảng `machines`.

Hai thứ module này mang vào hệ thống mà chưa module nào có:

- **Cước tính theo thời gian trôi.** Cước lưu bãi tăng theo ngày container còn nằm trong
  bãi. Đó là số tiền **không** đến từ một thao tác người dùng — không request nào sinh ra
  nó. Nó cần một việc chạy theo lịch, và đó sẽ là **job theo lịch đầu tiên của hệ thống**
  (`machine/docs/Workflow.md` mục 6 đã ghi trước rằng việc nhắc lịch bảo trì là ứng viên
  đầu tiên; `yard` có thể tới trước). Câu hỏi bắt buộc trả lời trước dòng code đầu tiên:
  **chạy hai lần thì có tính cước hai lần không** — `shared/idempotency` đã tồn tại nhưng
  hôm nay chỉ phục vụ consumer outbox nội bộ.
- **Một dòng tiền vào không đi qua `sales`.** Cước dịch vụ cảng phải ra được hóa đơn,
  nên `accounting` nhận đầu vào từ **ba** nguồn chứ không hai.

### 2.2 `accounting` — phạm vi cơ bản, và ranh giới của "cơ bản" phải viết ra

**Trong phạm vi:** hóa đơn bán ra và mua vào, thu chi, công nợ phải thu và phải trả,
đối chiếu thanh toán với hóa đơn.

**Ngoài phạm vi, ghi ra để không ai coi là thiếu sót:** sổ cái, bút toán kép, hệ thống
tài khoản, báo cáo tài chính theo chuẩn kế toán Việt Nam, kết chuyển cuối kỳ, khấu hao
tài sản cố định.

Nâng từ "cơ bản" lên "đầy đủ" **không** phải mở rộng module này — đó là một chặng riêng
với mô hình dữ liệu khác hẳn (mọi nghiệp vụ phải sinh bút toán cân bằng), và nó sẽ đòi
ADR riêng. Đừng thiết kế `invoices` hôm nay theo hướng "để sau dễ nối sổ cái": đó là
`flexibility` chưa ai đòi.

**Một câu hỏi pháp lý chưa ai trả lời, và nó có thể nằm ngoài "cơ bản":** hóa đơn điện
tử theo quy định thuế Việt Nam là bắt buộc với doanh nghiệp, và nó đòi tích hợp với một
đơn vị phát hành hoặc trực tiếp với cơ quan thuế. Nếu hệ thống này là nơi **phát hành**
hóa đơn cho khách, đó là một khối việc không có trong bảng ở mục 1. Nếu hóa đơn thuế
vẫn phát hành ở một phần mềm khác và ERP chỉ ghi nhận, thì phạm vi hiện tại đủ. **Phải
hỏi kế toán của công ty trước chặng O**, không phải trong chặng O.

### 2.3 `attendance` và `payroll` — hai module, không phải hai mục của `hr`

Bản đầu của file này gộp chấm công vào `hr` và bỏ quên tính lương. Đó là sai, và
phép thử để thấy nó sai là phép thử mà `machine/docs/README.md` đã dùng để biện minh cho
việc **gộp** ba bảng của nó: *có cặp lệnh ghi nào buộc phải nằm trong một transaction
không?*

- `hr` ghi hồ sơ; `attendance` ghi giờ công. Không cặp nào phải nguyên tử.
- `payroll` **đọc** một kỳ chấm công đã chốt rồi **ghi** phiếu lương. Đọc rồi ghi sang
  chỗ khác, không phải hai lệnh ghi cùng transaction.

Nên chúng tách được, và theo R-01 thì tách là đúng. Ranh giới cũng khớp với thực tế người
dùng: người chấm công và người tính lương ở hai bộ phận khác nhau, xem được hai tập dữ
liệu khác nhau.

**Năm thứ khó trong hai module này, xếp theo độ nguy hiểm:**

1. **Phân quyền theo phạm vi — hệ thống hôm nay chưa có, và đây là chỗ chặn thật.** Lương
   cần ít nhất ba mức nhìn: của chính tôi, của phòng tôi, của toàn công ty. Chữ ký hiện
   tại của `shared/authz` là `Can(ctx context.Context, actor auth.Actor, perm string) error`
   với `Bang map[string][]string` — RBAC thuần trên chuỗi, **không có tham số tài nguyên**,
   nên không diễn đạt được mức thứ hai. Dự án đã gặp phiên bản nhẹ của việc này một lần và
   xử bằng cách tách permission riêng (`auth.self_read` khác `auth.user_read`); cách đó đủ
   cho hai mức *của tôi / của người khác* và **không** đủ cho *của phòng tôi*. Xem mục 5.
2. **Kỳ lương phải khóa được.** Một máy trạng thái giống `maintenance_plans`, nhưng có
   tiền: kỳ đã khóa và đã trả rồi thì một lần sửa chấm công của tháng trước **không được**
   âm thầm đổi con số đã trả. Đường sửa đúng là một điều chỉnh ghi vào kỳ **sau**, không
   phải sửa tại chỗ kỳ cũ.
3. **Tỷ lệ pháp luật đổi hàng năm** — mức lương cơ sở, trần đóng BHXH, biểu thuế TNCN lũy
   tiến, tỷ lệ đóng hai chiều. Chúng phải là **dữ liệu có ngày hiệu lực**, không phải hằng
   trong code. Hằng trong code nghĩa là tính lại một kỳ của năm ngoái sẽ ra số của năm
   nay — một con số sai trên một chứng từ đã phát cho người lao động.
4. **Chạy lại bảng lương phải an toàn.** Cùng câu hỏi idempotency với job cước lưu bãi ở
   `yard` (mục 2.1), hậu quả nặng hơn.
5. **`R-19` ở mức khó nhất của cả hệ thống.** Mọi con số trên phiếu lương tính ở backend
   bằng `decimal`, không đi qua `float64` ở bất kỳ bước nào kể cả trong test; frontend chỉ
   hiển thị. Và một phiếu lương phải tái lập được y hệt sau nhiều năm — tức mọi tham số
   dùng để tính nó phải lưu lại được, không chỉ kết quả.

### 2.4 `purchasing` và `sales` là hai module, không phải một

Cùng phép thử của mục 2.3: tạo một đơn mua không ghi bảng nào của bán hàng, và ngược
lại. Không có cặp lệnh ghi nào buộc phải nằm chung một transaction, nên theo R-01 chúng
tách được — và ba lý do dưới đây nói tách là **nên**:

- Hai bảng đối tác khác nhau (`suppliers`, `customers`), hai vòng đời khác nhau.
- Chiều hàng ngược nhau: nhập kho và xuất kho là hai sự kiện khác nhau đổ vào `inventory`.
- Hai bộ phận khác nhau dùng, nên phân quyền và màn hình đều tách sẵn.

Phương án gộp một module bị loại vì hình dạng nó buộc phải mang: một bảng `orders` chung
với một cột chỉ chiều, và từ đó về sau **mọi** câu truy vấn phải nhớ lọc cột đó. Quên một
lần là đơn mua hiện trong danh sách bán — một lỗi không làm gì đỏ, chỉ hiện ra khi có
người đọc sổ.

**Ai sở hữu bảng đối tác:** `sales` sở hữu `customers`, `purchasing` sở hữu `suppliers`.
`yard` và `accounting` đọc qua `api/` của hai module đó, không JOIN sang — đúng khuôn
`machine` đọc `auth.UserReader` đang chạy hôm nay.

Không tách một module `doi-tac` riêng ở thời điểm này: nó sẽ là một module chỉ giữ hai
bảng CRUD, tức trả trước chi phí một ranh giới cho một nhu cầu chưa ai đòi. **Điều kiện
mở lại:** ngày một đối tác vừa là khách hàng vừa là nhà cung cấp và nghiệp vụ đòi hai vai
đó dùng **chung một danh tính** (chung công nợ, chung mã số thuế, chung lịch sử giao
dịch). Ngày đó `doi-tac` là câu trả lời đúng, và hai bảng hiện có gộp vào nó.

### 2.5 Cột "bảng chính" không phải danh sách màn hình, và báo cáo có hai loại

**Cột thứ tư của bảng ở mục 1 liệt kê bảng dữ liệu, không phải trang.** Số màn hình luôn
lớn hơn nhiều. Mốc đo được từ `machine`: **ba bảng → mười lăm endpoint → ba màn hình**,
và ba màn đó còn thiếu (chặng E phát hiện chúng không có đường dẫn nào từ giao diện).
Một module như `payroll` sẽ có màn cấu hình thành phần lương, màn kỳ lương, màn bảng
lương, phiếu lương cá nhân, màn tỷ lệ BHXH/thuế theo ngày hiệu lực, cộng các báo cáo —
nhiều hơn hẳn số bảng của nó.

Ngược lại, một màn hình được phép hiển thị dữ liệu của nhiều module: màn "hồ sơ lương của
một nhân viên" đọc `labor_contracts` (`hr`) và `payslips` (`payroll`). Gộp ở tầng
**giao diện** là bình thường; gộp ở tầng **bảng** là vi phạm R-02.

**Báo cáo có hai loại, và nhầm hai loại này là cách R-02 hay bị phá nhất:**

| Loại | Đọc gì | Thuộc về | Làm ở chặng nào |
|---|---|---|---|
| Trong module | chỉ bảng của chính module đó | chính module đó | cùng chặng của module |
| Xuyên module | bảng của từ hai module trở lên | module `reporting` | P |

Bảng lương kỳ này, tổng quỹ lương theo phòng ban, bảng kê BHXH — tất cả chỉ đọc bảng của
`payroll`, nên chúng thuộc `payroll` và làm ở chặng N. **Không** đợi chặng P.

Còn "chi phí lương so với doanh thu theo tháng" chạm bảng của hai module, và R-02 cấm một
câu SQL làm việc đó. Nó phải gọi `api/` của từng module rồi ghép ở ngoài, hoặc đọc từ một
read model dựng riêng. Chọn đường nào là quyết định của chặng P và cần ADR — nhưng phải
biết trước rằng câu JOIN hai bảng hai module **chạy được trên database**, nên thứ duy nhất
chặn nó là bộ kiểm chứ không phải một lỗi lúc chạy.

## 3. Hai thứ không phải module

**Ba bảng danh mục (`currencies`, `units`, `provinces`)** có tên trong registry `C-DB-04`
nhưng chưa có migration nào. Chúng thuộc `reference_tables`, và `CL-NEWMOD-11` cho phép
SQL của **mọi** module chạm bảng nhóm này — nên chúng **không cần module chủ**, chỉ cần
migration. Làm một lần, trước chặng G.

Cái nào thật sự cần: `units` (kho, sản xuất), `currencies` (mua hàng, bán hàng, cảng,
kế toán), `provinces` (khách hàng, nhà cung cấp).

**`document_counters`** — bảng đánh số chứng từ (`PO-2026-0001`). Cần bởi mua hàng, bán
hàng, kho, cảng và sản xuất, tức không thuộc module nào. Nó **chưa xếp được vào bốn nhóm
bảng** của `C-DB-04`, và đó là câu hỏi mở chứ không phải thiếu sót:

- có `company_id` (mỗi công ty đánh số riêng) → không phải `reference_tables`, không phải
  `system_tables`
- bị **sửa tại chỗ** mỗi lần cấp số → không phải `append_only_tables`
- là bảng nghiệp vụ nhưng không có module chủ → không rơi vào mặc định nào

Phải có ADR riêng trước chặng H. Hai câu hỏi ADR đó trả lời: bảng này thuộc nhóm nào, và
ai được phép cấp số — một hàm trong `shared/`, hay mỗi module tự gọi. Lưu ý thêm: cấp số
là một thao tác **ghi có tranh chấp** (hai request cùng lúc không được nhận cùng một số),
nên nó cũng là ca đầu tiên của hệ thống cần khóa ở tầng database.

## 4. Thứ tự chặng, và vì sao

```text
G  inventory    (khong phu thuoc module nghiep vu nao)
H  purchasing   <- inventory
I  sales        <- inventory
J  yard         <- machine, sales
K  production   <- inventory, machine
L  hr           <- auth
M  attendance   <- hr
N  payroll      <- hr, attendance
O  accounting   <- purchasing, sales, yard, payroll
P  reporting    <- moi module
```

Hai nhánh độc lập nhau: `G → H → I → J/K` là nhánh hàng hóa và dịch vụ; `L → M → N` là
nhánh con người. Chúng chỉ gặp nhau ở `O accounting`. Nếu có hai đội làm song song thì đó là
đường cắt, không phải cắt giữa backend và frontend.

`inventory` đi trước vì nó là module duy nhất **không phụ thuộc module nghiệp vụ nào** — mua
hàng và bán hàng đều đổ vào nó, không ngược lại. Nó cũng là phép thử rẻ nhất cho câu hỏi
thật sự đáng hỏi sau sáu chặng hạ tầng: *bộ khung có làm module thứ ba rẻ hơn module thứ
hai không?* Hai module đầu (`auth`, `machine`) **chính là** cái đẻ ra bộ khung nên chúng
không kiểm chứng được nó — giống như tự chấm bài của mình.

`yard` đặt sau `sales` vì nó cần một khái niệm khách hàng đã tồn tại, và đặt trước
`accounting` vì nó là một trong ba nguồn hóa đơn. Đổi chỗ `yard` với `production` được, nếu
mảng cảng cần chạy thật sớm hơn xưởng — hai nhánh đó không phụ thuộc nhau.

`accounting` gần cuối vì nó tiêu thụ đầu ra của **bốn** module khác — ba nguồn hóa đơn cộng
chi phí lương từ `payroll`; làm sớm là làm trên một tập đầu vào chưa tồn tại.

`payroll` sau `attendance` là hiển nhiên, nhưng `hr` phải đi trước **cả hai** vì
một lý do ít hiển nhiên: `dependents` (người phụ thuộc) là đầu vào bắt buộc của giảm trừ
gia cảnh khi tính thuế TNCN. Đó là một bảng của `hr` mà chỉ `payroll` dùng — dấu
hiệu cho thấy ranh giới giữa hai module này cần kiểm lại một lần ở đầu chặng L, không
phải mặc định đúng.

**Phải xong trước dòng migration đầu tiên của chặng G:**

1. Migration ba bảng danh mục (mục 3)
2. Trả lời ba câu hỏi hợp đồng còn treo từ chặng E — `PATCH` cho phép ghi rỗng, định
   dạng ngày date-only, đường xóa trường ngày (xem
   [2026-08-13-ban-giao-chang-e.md](2026-08-13-ban-giao-chang-e.md) mục 3.4). Chúng
   **không** đặc thù `machine`; bỏ qua là gặp lại y hệt ở mọi module sau.

**Trước chặng H:** ADR cho `document_counters` (mục 3).
**Trước chặng N:** ADR cho phân quyền theo phạm vi (mục 5, câu 1) — nó động vào
`shared/authz`, thứ mọi module đang dùng, nên không phải việc làm trong lúc đang viết
`payroll`.
**Trước chặng O:** trả lời câu hỏi hóa đơn điện tử (mục 2.2).

## 5. Câu hỏi còn mở

1. **Phân quyền theo phạm vi — `shared/authz` hôm nay không diễn đạt được.** Chữ ký là
   `Can(ctx, actor, perm string) error` và bảng vai trò là `map[string][]string`: một
   quyết định chỉ dựa trên *actor có role gì*, không dựa trên *bản ghi nào*. Ba mức mà
   lương cần — của tôi / của phòng tôi / toàn công ty — chỉ có mức thứ nhất và thứ ba
   biểu diễn được bằng cách tách permission, đúng lối `auth.self_read` đã dùng. Mức giữa
   thì không. Đây là câu hỏi **kiến trúc**, không phải câu hỏi của module `payroll`:
   bất cứ đường sửa nào cũng đổi một interface mà cả `auth`, `machine` và mọi module sau
   này đều gọi. Cần ADR trước chặng N. Ba đường đã thấy: thêm tham số tài nguyên vào
   `Can`; giữ `Can` và cho service tự lọc theo phạm vi sau khi đã qua cổng permission;
   hoặc sinh permission theo phòng ban (`luong.read.phong_<id>`) — đường thứ ba rẻ nhất
   để viết và tệ nhất để sống chung, ghi ra để không ai đề xuất lại nó như mới.
2. ~~Ai sở hữu bảng `customers`?~~ **Đã trả lời ở mục 2.4:** `sales` sở hữu, `yard` và
   `accounting` đọc qua `api/`. Giữ dòng này để người đọc biết câu hỏi đã từng mở và đã đóng
   ở đâu, chứ không phải chưa ai nghĩ tới.
3. **Tồn kho ở cảng có phải `inventory` không?** Container trong bãi và vật tư trong kho đều là
   "thứ nằm ở một chỗ, vào rồi ra". Nếu gộp thì `yard` không cần bảng riêng cho vị trí;
   nếu tách thì hai module cùng mô hình hóa một khái niệm. Đây đúng dạng câu hỏi ranh giới
   mà ADR-0001 mục Context nói là chưa chắc chắn — và ADR-0016 vừa là một tiền lệ về cách
   trả lời nó.
4. **Chỉ còn một dòng `ĐỀ XUẤT` ở mục 1: Báo cáo.** Nó ở lại mức đó vì báo cáo không có
   phạm vi riêng — nó là hình chiếu của mười một module kia, và chỉ định nghĩa được sau
   khi biết chúng thật sự chứa gì. Mười một dòng còn lại đã `CÓ` hoặc `CHỐT`; dòng nào sai
   thì sửa thẳng, file này chưa được ADR nào tham chiếu nên sửa không kéo theo gì.

Cái **không** được làm: để nguyên một dòng sai rồi lên kế hoạch chặng theo nó.
