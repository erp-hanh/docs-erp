# ADR-0008: Soft Delete mặc định — xóa nghiệp vụ là đánh dấu deleted_at

**Status:** Accepted (2026-08-10)

## Context

Trong ERP, "xóa" gần như không bao giờ có nghĩa là dữ liệu biến mất. Ba tình huống có
thật, được nêu ngay từ khảo sát khách hàng đầu tiên:

- Người dùng xóa nhầm một phiếu nhập kho và cần lấy lại trong ngày. Phục hồi từ backup
  là khôi phục cả database về một thời điểm — không dùng được cho một dòng.
- Báo cáo tháng trước đã in ra và đã gửi đi. Nếu một bản ghi bị xóa vật lý thì chạy lại
  báo cáo đó hôm nay ra con số khác, và không ai giải thích được chênh lệch.
- Kiểm toán hỏi về một chứng từ đã bị hủy. Câu trả lời "không còn trong hệ thống" là
  câu trả lời tệ nhất có thể; điều họ cần biết là ai hủy và lúc nào.

Đồng thời, [ADR-0007](ADR-0007-traceability-bat-buoc.md) đã chốt rằng mọi thao tác ghi
để lại dấu vết. Xóa vật lý làm rỗng một nửa dấu vết đó: bản ghi audit còn nói có một
lần xóa, nhưng thứ bị xóa thì không còn để đối chiếu.

## Decision

**Xóa nghiệp vụ là đánh dấu `deleted_at`, không xóa vật lý. Hard delete phải có một
ADR riêng liệt kê đúng tên bảng được phép.**

Phạm vi:

- Áp cho **bảng nghiệp vụ** và bảng trong `reference_tables`.
- Không áp cho `system_tables` và `append_only_tables` — hai nhóm này không có cột
  `deleted_at`, và riêng `append_only_tables` được hard delete theo lịch giữ liệu mà
  không cần ADR ([ADR-0003](ADR-0003-multi-tenant-ready.md)).
- ADR cho phép hard delete phải nêu **tên bảng cụ thể**, không nêu loại bảng hay điều
  kiện chung. Chỗ xóa trong code phải trỏ ngược về ADR đó bằng comment.

## Alternatives

**Hard delete** — loại. Nó đơn giản nhất và mọi query đọc đều ngắn hơn một điều kiện,
nhưng nó không đáp ứng được cả ba tình huống ở mục Context: không phục hồi được một
dòng, không đối chiếu được số liệu lịch sử, và làm rỗng dấu vết audit đúng ở thời điểm
quan trọng nhất. Với dữ liệu kế toán, mất một dòng không phải sự cố kỹ thuật mà là một
vấn đề với bên ngoài.

**Bảng archive riêng — chuyển bản ghi bị xóa sang bảng song song** — loại. Nó giữ được
dữ liệu và giữ cho bảng chính gọn, nhưng nhân đôi schema: mỗi lần thêm cột phải thêm ở
hai chỗ, và hai chỗ đó sẽ lệch nhau. Nặng hơn là phía đọc: mọi báo cáo cần cả dữ liệu
sống lẫn dữ liệu đã xóa phải `UNION` hai bảng, và mọi khóa ngoại trỏ tới bản ghi đã
chuyển đi đều gãy. Phức tạp hóa mọi query để đổi lấy một bảng chính nhỏ hơn là đánh
đổi sai ở quy mô hiện tại.

**Xóa mềm bằng cột `is_deleted BOOLEAN`** — loại. Nó mất thông tin *lúc nào*, mà lúc
nào chính là thứ hay được hỏi nhất. `deleted_at` mang cả hai nghĩa trong một cột và
dùng được trực tiếp trong điều kiện lọc.

**Sự kiện xóa lưu ở event log, dữ liệu vẫn hard delete** — loại. Event log nói rằng
đã có một lần xóa, nhưng khôi phục từ nó đòi dựng lại trạng thái từ toàn bộ lịch sử —
một mô hình khác hẳn (event sourcing) mà phần còn lại của hệ thống không theo.

## Consequences

**Được:**

- Phục hồi một bản ghi là một `UPDATE`, làm được trong vài phút và không đụng tới
  backup.
- Số liệu lịch sử đối chiếu lại được: báo cáo của kỳ trước vẫn ra đúng con số đã in.
- Khóa ngoại trỏ tới bản ghi đã xóa mềm vẫn hợp lệ, nên không có bản ghi mồ côi và
  không phải xóa dây chuyền.
- Dấu vết audit của [ADR-0007](ADR-0007-traceability-bat-buoc.md) trọn vẹn: có bản ghi
  audit của lần xóa **và** có dữ liệu để đối chiếu với nó.

**Mất:**

- **Mọi query đọc phải mang `deleted_at IS NULL`, và quên là lộ dữ liệu đã xóa.** Đây
  là khoản mất nghiêm trọng nhất và nó hỏng im lặng: câu query vẫn chạy, vẫn trả về
  kết quả, chỉ là nhiều hơn đúng. R-18 tồn tại vì chỗ này, và nó phải được kiểm bằng
  máy chứ không bằng trí nhớ.
- **Ràng buộc duy nhất trên cột nghiệp vụ phải chuyển sang partial unique index**
  `... WHERE deleted_at IS NULL`. Với `UNIQUE` thường, sau khi xóa mềm một bản ghi thì
  **không tạo lại được bản ghi cùng mã** — người dùng xóa mã khách hàng `KH001` rồi
  tạo lại đúng mã đó sẽ nhận lỗi trùng, và lỗi đó không giải thích được cho họ. Bảng
  không có `company_id` (nhóm `reference_tables`) dùng dạng không có cột đó.
- Bảng chỉ lớn lên, không bao giờ nhỏ đi. Index phải tính tới phần dữ liệu đã xóa, và
  tỷ lệ bản ghi chết cao thì kế hoạch thực thi kém dần.
- Bản ghi đã xóa mềm vẫn thỏa mọi khóa ngoại ở tầng database, nên **database không
  chặn** việc tạo liên kết mới trỏ tới một bản ghi đã xóa. Việc kiểm đó phải nằm ở
  service.

**Nợ để lại:**

- Chưa có cách xóa vĩnh viễn theo yêu cầu pháp lý (quyền được quên đối với dữ liệu cá
  nhân). Khi cần, nó đi qua đúng cơ chế đã định: một ADR riêng liệt kê tên bảng được
  phép, và chỗ xóa trong code trỏ ngược về ADR đó.
- Chưa có quy ước hiển thị bản ghi đã xóa cho người có quyền, và chưa có endpoint phục
  hồi. Hiện phục hồi là việc chạy tay trên database — thứ tự nó đã vi phạm
  [ADR-0007](ADR-0007-traceability-bat-buoc.md) vì không sinh bản ghi audit.
- Chưa chốt hành vi dây chuyền: xóa mềm một đơn hàng thì các dòng hàng của nó có được
  đánh dấu theo không, hay chỉ ẩn theo bản ghi cha. Hai cách đều dùng được và phải
  chọn một cách nhất quán ở tầng Convention.

**Constrains:** R-18
