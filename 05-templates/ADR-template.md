# ADR-00xx: <một câu khẳng định, nói rõ đã chọn cái gì>

**Status:** Accepted (YYYY-MM-DD)

<!--
Status chỉ nhận một trong ba giá trị:

  Accepted (YYYY-MM-DD)          — đang có hiệu lực
  Superseded by ADR-00yy         — đã bị một ADR sau thay thế
  Rejected (YYYY-MM-DD)          — đã cân nhắc và quyết là không làm

ADR là BẤT BIẾN. Đã Accepted thì không sửa nội dung — không sửa Decision, không sửa
Alternatives, không "cập nhật cho khớp thực tế". Muốn đổi thì viết ADR mới và đánh
dấu ADR cũ `Superseded by ADR-00yy`. Sửa tại chỗ là xóa mất lý do người ta đã quyết
như vậy, và đó chính là giá trị duy nhất của tầng này.

Sửa lỗi chính tả, sửa link chết, thêm dòng `Superseded by` — được. Ngoài ra thì không.
-->

## Context

<Bối cảnh và ràng buộc **tại thời điểm quyết**. Viết ở thì quá khứ: "đội ở mức bốn
người", "chưa có khách hàng thứ hai", "PostgreSQL đã có sẵn, Kafka thì chưa".

Đây là mục quan trọng nhất của ADR. Người đọc sau ba năm cần biết bạn *không biết gì*
lúc đó, để phân biệt "quyết định sai" với "quyết định đúng trong hoàn cảnh đã khác".

Cấm viết ở đây: lý do bênh vực quyết định (để ở Consequences), mô tả cách cài đặt
(để ở tầng Convention).>

## Decision

<Quyết cái gì. **Một câu, rõ ràng, ở thể khẳng định chủ động.** Nếu phải viết ba
đoạn mới nói xong thì đây là hai quyết định, tách thành hai ADR.

Sau câu đó được phép thêm vài gạch đầu dòng làm rõ phạm vi: quyết định này áp lên
cái gì, và **không** áp lên cái gì.>

## Alternatives

<Ít nhất một phương án đã thật sự cân nhắc, kèm lý do loại. Mỗi phương án viết theo
mẫu:

**<Tên phương án>** — loại vì <lý do cụ thể, đo được hoặc kiểm chứng được>.

Lý do loại phải là thứ có thể sai. "Phức tạp" không phải lý do; "cần thêm một tiến
trình phải giám sát và một giao thức thứ hai, trong khi đội chưa có người trực" là
lý do. Một phương án bị loại bằng nửa câu là dấu hiệu nó chưa từng được cân nhắc —
và sáu tháng sau sẽ có người mở lại cuộc tranh luận từ đầu.

Phương án "không làm gì" cũng là một phương án, và thường là phương án đúng.>

## Consequences

**Được:** <thứ đổi được nhờ quyết định này. Cụ thể, không phải lời khen.>

**Mất:** <thứ mất đi, viết thành thật. ADR không có mục Mất là ADR chưa cân nhắc gì.>

**Nợ để lại:** <việc phải làm sau, câu hỏi còn mở, và điều kiện để quyết định này
đứng vững. Nếu quyết định chỉ đúng khi một điều kiện khác được giữ (ví dụ "mọi
handler phải idempotent"), ghi ở đây và nói rõ đó là **điều kiện**, không phải
khuyến nghị.>

**Constrains:** <danh sách Rule mà quyết định này là lý do tồn tại, ví dụ `R-06`;
để `—` nếu không ràng buộc Rule nào>

<!--
Trường Constrains được `tools/check-ids.ps1` kiểm KHỚP HAI CHIỀU:

  RULES.md ghi  "R-06 ... Decisions: ADR-0003"
  thì ADR-0003 phải có R-06 trong Constrains, và ngược lại.

Thiếu một chiều là script đỏ. Khi thêm ADR mới ràng buộc một Rule, sửa cả hai chỗ
trong cùng một PR. Nếu ADR không ràng buộc Rule nào thì để dấu — và không sửa
RULES.md.
-->
