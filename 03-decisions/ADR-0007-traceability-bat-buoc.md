# ADR-0007: Truy vết bắt buộc — audit trong cùng transaction, request_id xuyên suốt

**Status:** Accepted (2026-08-10)

## Context

ERP là hệ thống mà số liệu của nó được dùng để giải trình với bên ngoài: kiểm toán,
cơ quan thuế, và đối tác trong tranh chấp hợp đồng. Khách hàng đầu tiên — doanh nghiệp
cơ khí và cảng — đã nêu ngay ở khảo sát ba câu hỏi mà hệ thống phải trả lời được:

- Ai đổi giá dòng hàng này, lúc nào, từ giá trị nào sang giá trị nào?
- Vì sao phiếu xuất kho này biến mất khỏi báo cáo tháng trước?
- Cùng một thao tác trên màn hình, người dùng báo lỗi — lần chạy đó đã đi qua những
  đâu trong hệ thống?

Hai câu đầu là truy vết **dữ liệu nghiệp vụ**. Câu thứ ba là truy vết **một lần thực
thi**, và nó chỉ trả lời được nếu có một định danh chung xuyên suốt từ lúc request vào
tới log, tới response, và tới cả event phát ra từ request đó.

Ràng buộc thời điểm: schema còn trống. Cột `created_by`/`updated_by` và bảng audit
thêm vào lúc này là gõ thêm vài dòng mỗi migration; thêm vào sau khi có dữ liệu thật
thì phải chấp nhận một khoảng lịch sử không có ai chịu trách nhiệm.

## Decision

**Mọi thao tác ghi lên bảng nghiệp vụ và lên bảng trong `reference_tables` sinh một
bản ghi audit trong CÙNG transaction với thao tác đó; `request_id` đi xuyên suốt từ
middleware tới log và tới response.**

Hai vế, và cả hai đều bắt buộc:

- Vế audit: bản ghi audit và thay đổi dữ liệu cùng nằm trong một `BEGIN ... COMMIT`.
  Không có ngoại lệ cho "thao tác nhỏ" hay "bảng ít quan trọng"; ba nhóm bảng được
  miễn được liệt kê tường minh ở [ADR-0003](ADR-0003-multi-tenant-ready.md), và
  `reference_tables` **không** nằm trong số được miễn.
- Vế `request_id`: sinh ở middleware, gắn vào `ctx`, có mặt trong mọi dòng log của
  request đó, trả về qua header `X-Request-Id` cho **mọi** response, và đi kèm event
  ghi vào `outbox` để nối được nhân quả qua ranh giới bus.

## Alternatives

**Audit bằng trigger database** — loại. Nó hấp dẫn vì không lập trình viên nào quên
được, nhưng hỏng ở hai chỗ. Thứ nhất, **trigger không biết actor ở tầng ứng dụng**:
nó thấy user của kết nối database, không thấy người dùng nào vừa bấm nút. Truyền
actor xuống bằng biến session (`SET LOCAL`) thì lại quay về đúng chỗ ban đầu — vẫn
phải nhớ làm ở tầng ứng dụng, chỉ là ở chỗ khó thấy hơn. Thứ hai, logic ẩn trong
database không nằm trong diff của repo code: nó không được review cùng thay đổi gây ra
nó, và người đọc code không có manh mối nào rằng một `UPDATE` bình thường vừa ghi thêm
ba bảng.

**Audit ghi ngoài transaction** — loại, và đây là phương án nguy hiểm nhất vì nó chạy
đúng trong hầu hết trường hợp. Ghi audit sau khi commit thì transaction rollback mà
bản ghi audit vẫn còn: **sổ sách nói một đằng, dữ liệu một nẻo**. Với một hệ thống có
kiểm toán, đó là lỗi nặng hơn cả mất dữ liệu — mất dữ liệu thì biết là đã mất, còn một
dấu vết audit mô tả việc chưa từng xảy ra sẽ được tin và được dùng làm căn cứ.

**Ghi audit vào log file hoặc hệ thống log ngoài** — loại. Log là hạ tầng có mất mát
được chấp nhận: buffer đầy thì rơi, đĩa đầy thì xoay vòng, và không ai coi một dòng
log bị mất là sự cố. Dấu vết nghiệp vụ thì không được phép mất, và nó phải nằm cùng
chỗ với dữ liệu nó mô tả để còn nối được bằng `JOIN` và bằng chính transaction.

**Chỉ audit những bảng "quan trọng"** — loại. Danh sách "quan trọng" là thứ không ai
duy trì được: bảng ít quan trọng hôm nay là bảng có tranh chấp năm sau, và lúc phát
hiện ra thì đã không có dữ liệu. Một quy tắc áp cho mọi bảng nghiệp vụ thì kiểm được
bằng máy; một danh sách ngoại lệ thì phải xét bằng người ở mỗi PR.

## Consequences

**Được:**

- Ba câu hỏi ở mục Context trả lời được bằng truy vấn, không bằng phỏng đoán.
- Bản ghi audit và dữ liệu **không bao giờ lệch nhau**: cùng transaction nghĩa là cùng
  sống hoặc cùng chết, đúng như event và dữ liệu ở
  [ADR-0006](ADR-0006-event-bus-outbox.md).
- `request_id` nối được một lần bấm nút của người dùng với mọi dòng log, mọi bản ghi
  audit, và mọi event nó sinh ra — kể cả những việc chạy sau đó ở phía consumer.
- Actor là thứ tầng ứng dụng biết rõ nhất, nên bản ghi audit mang đúng người thật chứ
  không mang user của connection pool.

**Mất:**

- **Mỗi thao tác ghi tốn thêm một `INSERT`**, và `INSERT` đó nằm trong transaction nên
  nó kéo dài chính khoảng đang giữ khóa. Với thao tác hàng loạt, chi phí này nhân theo
  số dòng và phải được tính tới khi thiết kế.
- **`audit_logs` lớn nhanh** — nhanh hơn bảng nghiệp vụ mà nó theo dõi, vì một bản ghi
  có thể bị sửa nhiều lần. Nó cần lịch giữ liệu và job dọn; nó nằm trong
  `append_only_tables` ([ADR-0003](ADR-0003-multi-tenant-ready.md)) nên được hard
  delete theo lịch mà không cần ADR riêng.
- Không có đường tắt: kể cả một script sửa dữ liệu chạy tay cũng phải đi qua service
  để sinh audit, hoặc phải tự ghi bản ghi audit tương ứng.
- Mọi chữ ký hàm ở service và repository phải nhận `ctx` làm tham số đầu, kể cả những
  hàm không dùng tới nó. Đó là cái giá của việc `request_id` và actor đi được xuyên
  suốt.

**Nợ để lại:**

- Chưa chốt **hạn giữ** của `audit_logs` và cách lưu trữ nguội phần quá hạn. Xóa thẳng
  dữ liệu audit của kỳ đã quyết toán không phải quyết định kỹ thuật thuần túy.
- Chưa chốt độ chi tiết của bản ghi audit: lưu toàn bộ ảnh chụp bản ghi, hay chỉ lưu
  các field đã đổi. Ảnh chụp thì to nhưng đọc được ngay; chỉ field đã đổi thì gọn
  nhưng phải dựng lại trạng thái khi đọc.
- Chưa có giao diện tra cứu audit cho người dùng cuối; hiện chỉ tra được bằng truy vấn
  trực tiếp.
- Chưa có cơ chế chống sửa `audit_logs` ở mức database (chỉ có quy ước và R-18). Một
  người có quyền ghi trực tiếp vào database vẫn sửa được dấu vết.

**Constrains:** R-17
