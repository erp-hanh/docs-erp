# ADR-0005: Documentation follows Code — tài liệu module nằm trong repo code

**Status:** Accepted (2026-08-10)

## Context

[ADR-0002](ADR-0002-multi-repo.md) đã tách `docs-erp` thành repo riêng cho tài liệu
dùng chung. Câu hỏi còn lại là tài liệu của **từng module** — mô tả bảng, luồng
nghiệp vụ, ma trận quyền, danh sách event — nằm ở đâu.

Kinh nghiệm chung của mọi dự án trước đó ở đội: tài liệu module luôn chết theo cùng
một kịch bản. Nó được viết đầy đủ ở tuần đầu, rồi schema đổi ở tháng thứ ba, và không
ai cập nhật. Sáu tháng sau nó tệ hơn không có tài liệu, vì người mới tin nó.

Nguyên nhân đã nhận diện được không phải là lười, mà là **khoảng cách**: nếu cập nhật
tài liệu là một hành động tách rời — mở một repo khác, hoặc mở một trang wiki — thì nó
nằm ngoài dòng chảy của việc đang làm và ngoài tầm nhìn của người review. Reviewer
không thấy nó thiếu thì không ai nhắc, và không ai nhắc thì nó không được viết.

Ràng buộc thứ hai: bốn nhóm thông tin của một module đã được xác định là cần có, vì
chúng là thứ người ta hỏi nhau nhiều nhất — bảng và quan hệ, luồng trạng thái, quyền,
và event phát ra.

## Decision

**Tài liệu của mỗi module nằm trong repo code của chính module đó**, ở thư mục `docs/`
của module, gồm bốn file: `Database.md`, `Workflow.md`, `Permission.md`, `Events.md`.
`docs-erp` chỉ giữ quy tắc và kiến trúc dùng chung.

Đường phân chia: nếu một thông tin đúng cho **mọi** module thì nó thuộc `docs-erp`;
nếu nó chỉ đúng cho một module thì nó đi cùng code của module đó. Ví dụ: "mọi bảng
nghiệp vụ có `company_id`" thuộc `docs-erp`; "bảng `orders` có mười hai cột và ba
index" thuộc `docs/Database.md` của module Order.

Khuôn của bốn file nằm ở `05-templates/module-docs/`.

## Alternatives

**Gom hết tài liệu module vào `docs-erp`** — loại. Nó cho một chỗ đọc duy nhất, nhưng
trả bằng đúng nguyên nhân đã nhận diện ở mục Context: docs xa code thì không ai cập
nhật. Cụ thể, sửa schema là một PR ở repo `backend-erp`, còn cập nhật `Database.md` là một
PR ở repo khác — và PR thứ hai không bao giờ được viết, vì không có gì trong lần review
thứ nhất cho thấy nó còn thiếu.

**Wiki hoặc Confluence** — loại. Cùng bệnh với phương án trên, cộng thêm hai khoản:
nội dung không nằm trong diff nên không review được cùng code, và lịch sử thay đổi
không gắn với commit nên không trả lời được câu "tài liệu này mô tả phiên bản nào".

**Sinh tài liệu tự động từ code và schema** — loại ở thời điểm này, nhưng loại theo
kiểu khác: nó giải được đúng một phần bài toán, phần *cấu trúc* (danh sách bảng, cột,
endpoint), và không giải được phần đắt hơn là *ý định* (vì sao luồng duyệt có ba bước,
vì sao quyền này tách khỏi quyền kia). Có thể thêm sau như một phần bổ trợ cho
`Database.md`, không thay thế nó.

## Consequences

**Được:**

- Tài liệu sửa trong **cùng một PR** với code, nên reviewer nhìn thấy cả hai và nhắc
  được ngay khi thiếu. Đây là toàn bộ lý do của quyết định này.
- Checklist đòi được thứ kiểm được: "PR đổi schema phải kèm thay đổi ở `Database.md`
  của module đó" là mệnh đề nhìn một diff là kết luận.
- Tài liệu module được branch và revert cùng code, nên nó luôn mô tả đúng nhánh đang
  đọc.

**Mất:**

- Tài liệu module phân tán ở nhiều repo; không có một chỗ đọc hết mọi module cùng lúc.
- Một luồng nghiệp vụ đi qua ba module thì mô tả của nó nằm ở ba chỗ, và không chỗ nào
  kể trọn câu chuyện. Tài liệu luồng xuyên module là khoảng trống có thật.
- Người mới phải biết cấu trúc repo trước khi tìm được tài liệu.

**Nợ để lại:**

- Khuôn ở `05-templates/module-docs/` phải được giữ đồng bộ với thực tế các module.
  Khuôn lạc hậu còn tệ hơn không có khuôn, vì nó được sao chép nguyên vẹn.
- Chưa có cơ chế kiểm tự động rằng mỗi module có đủ bốn file và bốn file đó không rỗng.
  Việc này thuộc CI của repo code, chưa có ADR riêng.
- Chưa chốt chỗ đặt tài liệu cho luồng nghiệp vụ xuyên nhiều module — hiện rơi vào
  khoảng giữa: quá cụ thể cho `docs-erp`, quá rộng cho một module.

**Constrains:** —
