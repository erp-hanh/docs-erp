# ADR-0017: Hệ thống gồm đúng mười hai module, tên thư mục viết bằng tiếng Anh

**Status:** Accepted (2026-08-14)

## Context

[ADR-0001](ADR-0001-modular-monolith.md) ghi trong mục Context, ở phần liệt kê những thứ
**chưa biết tại thời điểm quyết**: *"ranh giới miền chưa chắc chắn. Ở thời điểm quyết,
chưa ai trả lời được Sales và Inventory nên là hai thứ tách rời hay một, hay Machine và
Kalmar thực chất là cùng một miền nhìn từ hai phía."*

Vế thứ hai đã được [ADR-0016](ADR-0016-kalmar-dung-chung-machine.md) trả lời. Vế thứ
nhất — và rộng hơn, **bản đồ miền của cả hệ thống** — thì chưa.

Sáu chặng A đến F đã chạy xong mà không văn bản nào nói hệ thống này sẽ có bao nhiêu
module. Hệ quả đo được, không phải suy đoán: câu hỏi *"còn bao nhiêu chặng nữa"* không
trả lời được từ repo. Mỗi chặng được viết spec đúng vào ngày nó bắt đầu; không chặng nào
được lên kế hoạch trước quá một ngày. Registry nhóm bảng `C-DB-04` — nơi lẽ ra thấy được
hình dạng tương lai — chỉ có `companies`, ba bảng danh mục và mấy bảng hạ tầng, **không
một bảng nghiệp vụ nào được dự trù**.

Phạm vi nghiệp vụ được người quyết xác nhận tại thời điểm này:

- Doanh nghiệp cơ khí có xưởng sản xuất **và** kinh doanh dịch vụ bãi container — bãi là
  một nguồn doanh thu, không phải chỗ đặt thiết bị.
- Bãi container **không có cầu tàu**: không xếp dỡ từ tàu, chỉ nhận / lưu / giao bằng
  đường bộ.
- Kế toán ở mức **cơ bản** — hóa đơn, thu chi, công nợ. Không sổ cái, không bút toán kép.
- Chấm công và tính lương nằm trong phạm vi, và mỗi thứ là một khối việc riêng chứ không
  phải vài màn hình của hồ sơ nhân sự.

Về cách đặt tên: hai module đang có là `auth` và `machine` — **tiếng Anh**.
[C-GO-backend.md](../04-conventions/C-GO-backend.md) lấy ví dụ `modules/order/module.yaml`
ở mục C-GO-05 — cũng tiếng Anh. Tên bảng trong mọi migration đã merge cũng tiếng Anh
(`machines`, `maintenance_plans`, `breakdowns`). Nhưng **không Rule hay Convention nào
phát biểu điều đó thành mệnh đề** — nó là quy ước ngầm, đúng được ba lần vì mới có ba ca.
Một bản đồ mười hai module là lần đầu tiên quy ước đó phải được nói ra, vì lần đầu tiên
có mười cái tên cùng lúc chờ được đặt.

Điều **chưa biết** tại thời điểm quyết: chín trên mười hai module chưa có một dòng code
nào. Danh sách bảng của chúng là dự kiến, rút ra từ phạm vi ERP điển hình cho miền này
chứ không từ va chạm thật với nghiệp vụ.

## Decision

**Hệ thống gồm đúng mười hai module dưới đây, và tên thư mục module viết bằng tiếng Anh.**

| Module | Miền nghiệp vụ nó trả lời |
|---|---|
| `auth` | Ai là ai, được làm gì |
| `machine` | Thiết bị có những gì, bảo trì tới đâu, hỏng lần nào |
| `inventory` | Vật tư đang có bao nhiêu, ở kho nào, vào ra thế nào |
| `purchasing` | Mua của ai, đơn nào, nhận hàng chưa |
| `sales` | Bán cho ai, đơn nào, giao hàng chưa |
| `yard` | Container nào nằm ô nào, bao lâu, cước bao nhiêu |
| `production` | Lệnh sản xuất nào đang chạy, cần vật tư gì, qua công đoạn nào |
| `hr` | Nhân viên là ai, thuộc phòng nào, hợp đồng gì |
| `attendance` | Ai đi làm ngày nào, ca nào, tăng ca bao nhiêu, nghỉ khi nào |
| `payroll` | Kỳ này trả bao nhiêu, khấu trừ những gì |
| `accounting` | Hóa đơn nào, thu chi nào, ai nợ ai bao nhiêu |
| `reporting` | Những câu hỏi phải đọc dữ liệu của **từ hai module trở lên** |

Phạm vi của quyết định này:

- Nó chốt **tập ranh giới**: có những module nào, và mỗi module trả lời câu hỏi nghiệp vụ
  nào. Thêm hoặc bớt một module là đổi quyết định này, tức cần một ADR mới.
- Nó **không** chốt: danh sách bảng cụ thể của từng module, thứ tự chặng thực hiện, ước
  lượng khối lượng, hay cách gom module thành phân hệ ở giao diện. Bốn thứ đó sống ở
  [99-meta/pham-vi-he-thong.md](../99-meta/pham-vi-he-thong.md) và **được phép sửa không
  cần ADR** — chúng là dự kiến, và khóa một dự kiến vào một văn bản bất biến là cách chắc
  chắn nhất để văn bản đó bị coi là thủ tục rồi bị lách.
- Quy tắc tên tiếng Anh áp cho **tên thư mục dưới `modules/`, trường `name` của
  `module.yaml`, và đường import**. Nó **không** áp cho giao diện người dùng, tài liệu,
  comment hay commit message — những thứ đó vẫn tiếng Việt như hiện nay.
- `reporting` chỉ giữ báo cáo **xuyên module**. Báo cáo chỉ đọc bảng của một module thuộc
  chính module đó, không thuộc `reporting`.

## Alternatives

**Đặt tên module bằng tiếng Việt không dấu (`kho`, `mua-hang`, `cang`, `tinh-luong`)** —
loại. Hai module đã merge là `auth` và `machine`, ví dụ của chính C-GO-05 là `order`, và
mọi tên bảng đã merge đều tiếng Anh; chọn tiếng Việt bây giờ nghĩa là repo vĩnh viễn mang
hai ngôn ngữ cạnh nhau trong cùng một danh sách import, vì R-07 và tính bất biến của
migration không cho đổi ngược `machines` thành `may_moc`. Riêng `cang` còn sai thêm một
lớp: `machine` đặt theo **thứ nó quản lý**, `auth` đặt theo **việc nó làm**, còn `cang`
đặt theo một **địa điểm** — nó không nói module làm gì, và cùng cái tên đó sẽ đúng y hệt
cho một module cầu tàu hoàn toàn khác sau này.

**Không chốt danh sách, cứ thêm module khi nghiệp vụ đòi** — loại. Đây chính là hiện
trạng sáu chặng qua, và nó là hiện trạng làm không ai trả lời được *"còn bao nhiêu chặng
nữa"*. Im lặng ở đây không phải giữ cho lựa chọn còn mở: nó chuyển quyết định ranh giới
xuống cho người viết migration đầu tiên của mỗi miền, đúng cách mà `xe_nang` lọt vào
`ck_machines_kind` ở chặng C mà không ai giải trình (ADR-0016).

**Chốt luôn cả danh sách bảng và thứ tự chặng vào ADR này** — loại. Chín trên mười hai
module chưa có dòng code nào, nên danh sách bảng của chúng chắc chắn sẽ đổi khi va vào
nghiệp vụ thật. ADR bất biến, nên mỗi lần đổi tên một bảng sẽ phải viết một ADR thay thế
— và một tầng tài liệu đòi ADR cho những việc nhỏ như vậy sẽ bị bỏ qua trong tháng đầu.
Cái đáng khóa là thứ **đắt để đảo**: tên module đi vào đường import ở khắp repo. Cái
không đáng khóa là thứ **rẻ để sửa**: một dòng trong bảng dự kiến.

**Gộp `attendance` và `payroll` vào `hr` cho gọn (mười module thay vì mười hai)** — loại
theo đúng phép thử mà `machine/docs/README.md` dùng để biện minh cho việc **gộp** ba bảng
của nó: *có cặp lệnh ghi nào buộc phải nằm chung một transaction không?* `payroll` đọc một
kỳ chấm công đã chốt rồi ghi phiếu lương — đọc rồi ghi sang chỗ khác, không phải hai lệnh
ghi cùng transaction. Không có cặp nào, nên R-01 nói tách. Ranh giới cũng khớp thực tế:
người chấm công và người tính lương ở hai bộ phận, xem được hai tập dữ liệu khác nhau.

## Consequences

**Được:**

- Câu hỏi bỏ ngỏ trong mục Context của ADR-0001 có câu trả lời cho vế bản đồ miền, và
  *"còn bao nhiêu chặng nữa"* trả lời được: mười.
- Mười hai tên nằm trong một ngôn ngữ. Mọi đường import đọc như nhau, và người mới không
  phải đoán module tiếp theo sẽ đặt tên theo lối nào.
- `yard` nói đúng việc module làm thay vì nói địa điểm, và để dành chỗ cho một module
  cầu tàu về sau mà không phải tranh tên.
- Ba câu hỏi ranh giới đã có câu trả lời có chỗ tra: Kalmar (ADR-0016), mua/bán tách hai,
  nhân sự tách ba.

**Mất:**

- Khóa một tập ranh giới trong khi chín trên mười hai module chưa có code — tức khóa dựa
  trên suy luận, không dựa trên va chạm thật. ADR-0001 mục Context nói thẳng ranh giới
  đặt sai thì sửa rất đắt, và quyết định này nhận rủi ro đó một cách có ý thức để đổi lấy
  khả năng lập kế hoạch.
- Người đọc thuần nghiệp vụ phải bắc một nhịp giữa tài liệu tiếng Việt và thư mục tiếng
  Anh: "tính lương" nằm ở `modules/payroll/`. Đổi lại là nhất quán với hai module đã có
  và với toàn bộ tên bảng.
- `hr`, `attendance`, `payroll` đứng cạnh nhau với ranh giới mảnh. Dấu hiệu đã thấy trước:
  `dependents` (người phụ thuộc) là bảng của `hr` mà **chỉ** `payroll` dùng — nó tồn tại
  chỉ để giảm trừ gia cảnh khi tính thuế.

**Nợ để lại — điều kiện mở lại quyết định này:**

Bốn sự kiện, mỗi cái đủ một mình:

1. **Doanh nghiệp khai thác cầu tàu.** `yard` được chốt trên tiền đề đã xác nhận: chỉ bãi
   container, không xếp dỡ từ tàu. Ngày có tàu vào, miền đó rộng hơn hẳn — kế hoạch tàu,
   xếp dỡ, lệnh giao nhận với hãng tàu — và tên đúng lúc đó là `terminal`. Đó là một
   module mới, không phải một bảng thêm vào `yard`.
2. **Kế toán nâng lên đầy đủ.** `accounting` chốt ở mức cơ bản. Sổ cái với bút toán kép là
   mô hình dữ liệu khác — mọi nghiệp vụ phải sinh bút toán cân bằng — nên nó là một ADR
   mới, không phải mở rộng module này.
3. **ERP trở thành nơi phát hành hóa đơn điện tử thuế.** Câu hỏi này chưa ai trả lời tại
   thời điểm quyết. Nếu câu trả lời là có, nó có thể sinh module thứ mười ba, vì tích hợp
   với đơn vị phát hành hoặc cơ quan thuế là một miền có vòng đời và cách hỏng riêng.
4. **Ranh giới `hr` / `attendance` / `payroll` phải được kiểm lại một lần ở đầu chặng
   dựng `hr`**, không mặc định đúng. Xem mục "Mất" ở trên.

**Constrains:** —
