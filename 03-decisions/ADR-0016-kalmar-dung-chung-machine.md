# ADR-0016: Kalmar dùng chung module `machine`, không có module riêng

**Status:** Accepted (2026-08-14)

## Context

[ADR-0001](ADR-0001-modular-monolith.md) ghi trong mục Context, ở phần liệt kê những
thứ **chưa biết tại thời điểm quyết**: *"chưa ai trả lời được Sales và Inventory nên là
hai thứ tách rời hay một, hay Machine và Kalmar thực chất là cùng một miền nhìn từ hai
phía."* Sáu chặng sau (A đến F), không ai quay lại trả lời vế thứ hai.

[ADR-0004](ADR-0004-khong-tich-hop-iot-plc.md) chốt cả hai nhóm thiết bị — máy cơ khí
trong xưởng và xe nâng container Kalmar ở cảng — là **module CRUD thường**, không tích
hợp PLC. Nhưng "module CRUD" nói về *cách* làm, không nói *một hay hai* module. Câu hỏi
ranh giới vẫn để mở sau ADR đó.

Ghi chú bàn giao sau chặng E liệt kê "Kalmar tách module hay không" trong bảng nợ đã
thành văn bản, đánh dấu **chưa quyết**, trỏ về ADR-0001.

**Trong lúc đó, câu hỏi đã được trả lời bằng code — không qua ADR nào.** Migration
`000006_create_machines.up.sql`, merge ngày 2026-08-12 ở chặng C, mang ràng buộc:

```sql
CONSTRAINT ck_machines_kind
    CHECK (kind IN ('cnc', 'cat', 'han', 'xe_nang'))
```

`xe_nang` là loại thiết bị của Kalmar. Tức từ chặng C, một xe nâng container đã nhập
được vào bảng `machines` và dùng chung kế hoạch bảo trì lẫn nhật ký sự cố với một máy
CNC trong xưởng. Quyết định ranh giới nằm trong một `CHECK` constraint, và
[R-07](../01-rules/RULES.md) cấm sửa migration đã merge — nên mỗi ngày trôi qua nó càng
khó đảo, trong khi ADR-0001 vẫn ghi câu hỏi là mở.

Trạng thái đo được tại thời điểm quyết ADR này:

- `modules/machine` có ba bảng — `machines`, `maintenance_plans`, `breakdowns` — và
  **không cột nào trong chúng đặc thù cơ khí**. Bảng gốc giữ mã, tên, loại, vị trí,
  trạng thái, người phụ trách, ngày đưa vào dùng: một sổ tài sản tổng quát.
- Chưa có bản ghi Kalmar thật nào: hệ thống chưa được triển khai ở đâu ngoài máy dev,
  và `infra-erp` mới đang dựng ở chặng F.

Điều **chưa biết** tại thời điểm quyết, và nó là lý do mục "Nợ để lại" của ADR này dài
hơn thường lệ: nghiệp vụ chưa xác nhận thiết bị nâng hạ ở cảng có đòi mô hình bảo trì
**theo giờ vận hành** hay chu kỳ **kiểm định an toàn bắt buộc** hay không. Cả hai đều
là chuẩn ngành cho nhóm thiết bị này, nhưng không ai ở đây đã hỏi người vận hành cảng.

## Decision

**Xe nâng container Kalmar dùng chung module `machine`; hệ thống không có module
`kalmar` riêng.**

- Áp lên **ranh giới module**: không có thư mục `modules/kalmar/`, không có `module.yaml`
  thứ ba cho nhóm thiết bị này, và không bảng nào tách ra khỏi ba bảng hiện có vì lý do
  "đây là thiết bị cảng".
- **Không** áp lên việc mở rộng chính `machine`: thêm cột, thêm bảng, hay thêm giá trị
  vào tập `kind` để phục vụ thiết bị nâng là thay đổi **bên trong** ranh giới, đi theo
  `CL-SCHEMA-schema-change.md` và R-07 như mọi thay đổi schema khác. Quyết định này
  không chặn chúng.
- **Không** áp lên module thiết bị cảng ở nghĩa nghiệp vụ khác — nếu doanh nghiệp kinh
  doanh dịch vụ khai thác cảng (nâng hạ container tính cước, cho thuê bãi, lưu bãi), đó
  là một miền khác hẳn và không phải thứ ADR này nói tới. Ở đây chỉ có **lý lịch và bảo
  trì thiết bị**.

## Alternatives

**Tách `modules/kalmar` thành module thứ ba** — loại. Ba bảng của `machine` không có
cột nào đặc thù cơ khí, nên module tách ra sẽ lặp lại gần đúng ba bảng đó với một tập
cột gần trùng; chi phí theo mốc đo được của chính `machine` là khoảng 14.700 dòng và 75
file cho một module ba thực thể. Đắt hơn phần đó là hệ quả kiến trúc: một màn hình
*"toàn bộ thiết bị của công ty"* sẽ phải hỏi hai module rồi ghép kết quả ở tầng gọi, vì
[R-02](../01-rules/RULES.md) cấm một câu SQL chạm bảng của module khác và R-01 cấm import
`internal/` của nhau — nghĩa là phân trang và sắp xếp trên tập hợp nhất phải tự dựng lại
ở ngoài, đúng loại chi phí mà ADR-0001 chọn modular monolith để tránh.

**Giữ nguyên hiện trạng, không viết ADR** — loại. Đây chính là trạng thái hôm nay, và
nó không phải "trung lập": quyết định **đã** được đưa ra ở chặng C, chỉ là nằm trong một
`CHECK` constraint mà không ai giải trình. Hệ quả đo được là hai văn bản của chính dự án
nói hai điều khác nhau — `ck_machines_kind` nói *đã gộp*, ADR-0001 nói *chưa ai trả lời*
— và tình trạng đó đã sống qua ba chặng. Đó cũng chính là hình dạng mà mâu thuẫn `R-19`
giữa `RULES.md` và C-TS-04 đã dạy ở chặng E: một mâu thuẫn giữa hai tài liệu không tự
lộ ra, nó chỉ lộ khi có người đi đối chiếu.

**Hoãn tới khi có dữ liệu Kalmar thật để nhìn** — loại. Dữ liệu thật chỉ đến sau khi hệ
thống được triển khai, mà triển khai đang chờ chính chặng F chưa xong — nên "hoãn" ở đây
là hoãn không có mốc. Trong khi đó bản đồ phạm vi hệ thống cần biết số module để ước
lượng số chặng còn lại, và một dòng "kalmar?" chưa quyết làm mọi ước lượng dựa trên nó
mất nghĩa. Quan trọng hơn: hoãn **không** giữ cho lựa chọn còn mở — `ck_machines_kind`
đã merge, nên trạng thái mặc định của việc không quyết là *gộp*, chỉ là gộp mà không ai
chịu trách nhiệm.

## Consequences

**Được:**

- Câu hỏi bỏ ngỏ trong mục Context của ADR-0001 có câu trả lời, và hai văn bản của dự án
  hết nói ngược nhau. Quyết định ngầm trong một `CHECK` constraint thành một quyết định
  đọc được, có lý do và có điều kiện mở lại.
- Một sổ thiết bị duy nhất cho cả xưởng lẫn cảng: một màn hình danh sách, một luồng bảo
  trì, một nhật ký sự cố, một bộ permission. Người vận hành không phải học hai chỗ làm
  cùng một việc.
- Bản đồ phạm vi hệ thống bớt một dòng module, tức bớt một chặng khỏi ước lượng còn lại.

**Mất:**

- Một bảng `machines` giữ hai nhóm thiết bị có hồ sơ khác nhau. Ngày một nhóm cần một
  cột mà nhóm kia không bao giờ dùng — giờ chạy tích lũy, số khung, hạn kiểm định — cột
  đó vẫn nằm trên **mọi** hàng và `NULL` trên một nửa số hàng.
- `kind` trở thành trục phân loại gánh nhiều nghĩa hơn thiết kế ban đầu của nó: nó đang
  vừa nói *loại máy* (`cnc`, `cat`, `han`) vừa nói *nhóm thiết bị thuộc miền nào*
  (`xe_nang`). Hai trục khác nhau nằm trên một cột, và không có gì trong schema nói ra
  điều đó.
- Ranh giới này đã nằm sau một hợp đồng API công khai (`GET /api/v1/machines` trả cả hai
  nhóm). ADR-0001 mục Context cảnh báo đúng ca này: *"ranh giới đặt sai mà đã nằm sau
  ranh giới mạng thì sửa rất đắt"*. Ở đây chưa phải ranh giới mạng, nhưng đã là ranh giới
  hợp đồng.

**Nợ để lại — điều kiện mở lại quyết định này:**

Hai sự kiện, **mỗi cái đủ một mình** để mở lại. Cả hai đều là *sự kiện nghiệp vụ xác
nhận*, không phải ngưỡng số lượng bản ghi:

1. **Bảo trì tính theo giờ vận hành.** `maintenance_plans.planned_date` là kiểu `DATE`,
   nên toàn bộ mô hình lập lịch của module hôm nay là **theo ngày**. Thiết bị nâng hạ
   thường bảo trì theo mốc giờ chạy tích lũy (250h, 500h, 1000h). Đó là một quy tắc lập
   lịch **thứ hai**, và nó không nhét được vào `bangChuyenTrangThai` hiện tại mà không
   thêm một chữ "nếu" vào bảng — đúng thứ mà `machine/docs/Workflow.md` mục 4.2 đã từ
   chối khi tách một dòng `cancel` thành hai.
2. **Kiểm định an toàn định kỳ bắt buộc.** Thiết bị nâng thuộc diện phải kiểm định theo
   quy định. Đó là một loại "kế hoạch" khác hẳn bảo trì: nó có ngày hiệu lực, có giấy
   chứng nhận, và quá hạn thì thiết bị **bị cấm vận hành** — một trạng thái mà
   `ck_machines_status` (`hoat_dong`, `bao_tri`, `ngung`) không biểu diễn được.

**Mở lại quyết định này KHÔNG tự động có nghĩa là tách module.** Khi một trong hai sự
kiện xảy ra, thứ tự xét bắt buộc là: (a) thêm một bảng `inspections` vào chính `machine`,
hoặc thêm một trục lập lịch thứ hai vào `maintenance_plans`; (b) chỉ khi (a) buộc phải
dựng một bảng chuyển trạng thái thứ hai không dùng chung được với bảng hiện có, thì tách
module mới là câu trả lời. Ghi thứ tự này ra vì phản xạ tự nhiên khi gặp một nhu cầu mới
là tách một thứ mới, và ADR-0001 đã trả giá để nói rằng ranh giới sai đắt hơn một bảng
thừa.

**Constrains:** —
