# Decisions — 19 ADR nền

Rule trả lời *what must be true*. Principle trả lời *how we reason*. Trang này là tầng
thứ ba: **why we chose this** — lý do một Rule tồn tại, và những phương án đã bị loại
để có nó.

## ADR là bất biến

Mỗi ADR có `Status: Accepted (ngày)`. **Đã Accepted thì không sửa nội dung** — không
sửa mục Decision, không sửa mục Alternatives, không "cập nhật cho khớp thực tế". Muốn
đổi thì viết một ADR mới và đánh dấu ADR cũ `Superseded by ADR-00xx`.

Lý do nghiêm khắc ở chỗ này: giá trị của một ADR không nằm ở chỗ nó mô tả đúng hệ
thống hôm nay — tầng Convention làm việc đó tốt hơn. Nó nằm ở chỗ nó ghi lại **hoàn
cảnh và những thứ chưa biết tại thời điểm quyết**. Sửa một ADR đã Accepted là xóa đúng
phần đó, và thứ còn lại là một trang tài liệu vô hại nhưng vô dụng: người đọc sau ba
năm không phân biệt được "quyết định sai" với "quyết định đúng trong hoàn cảnh đã
khác", nên họ hoặc lặp lại sai lầm cũ, hoặc bỏ đi một quyết định vẫn còn đúng.

Được phép sửa tại chỗ đúng ba thứ: lỗi chính tả, link chết, và dòng `Superseded by`.

Khuôn để viết ADR mới nằm ở `05-templates/ADR-template.md`.

## Mười chín ADR hiện có

| ID | Quyết định | Status | Constrains | File |
|---|---|---|---|---|
| ADR-0001 | Modular Monolith thay vì microservices | Accepted (2026-08-10) | R-01, R-02, R-03, R-04 | [ADR-0001-modular-monolith.md](ADR-0001-modular-monolith.md) |
| ADR-0002 | Bốn repo git độc lập: docs-erp / backend-erp / frontend-erp / infra-erp | Accepted (2026-08-10) | — | [ADR-0002-multi-repo.md](ADR-0002-multi-repo.md) |
| ADR-0003 | Multi-tenant-ready bằng shared database và cột `company_id` | Accepted (2026-08-10) | R-06 | [ADR-0003-multi-tenant-ready.md](ADR-0003-multi-tenant-ready.md) |
| ADR-0004 | Không tích hợp IoT/PLC — Machine và Kalmar là module CRUD | Accepted (2026-08-10) | — | [ADR-0004-khong-tich-hop-iot-plc.md](ADR-0004-khong-tich-hop-iot-plc.md) |
| ADR-0005 | Documentation follows Code — tài liệu module ở repo code | Accepted (2026-08-10) | — | [ADR-0005-documentation-follows-code.md](ADR-0005-documentation-follows-code.md) |
| ADR-0006 | Event bus nội bộ với outbox pattern | Accepted (2026-08-10) | R-05 | [ADR-0006-event-bus-outbox.md](ADR-0006-event-bus-outbox.md) |
| ADR-0007 | Truy vết bắt buộc — audit cùng transaction, `request_id` xuyên suốt | Accepted (2026-08-10) | R-17 | [ADR-0007-traceability-bat-buoc.md](ADR-0007-traceability-bat-buoc.md) |
| ADR-0008 | Soft Delete mặc định — xóa là đánh dấu `deleted_at` | Accepted (2026-08-10) | R-18 | [ADR-0008-soft-delete-by-default.md](ADR-0008-soft-delete-by-default.md) |
| ADR-0009 | Backend là nơi duy nhất giữ business rule | Accepted (2026-08-10) | R-15, R-19 | [ADR-0009-business-rule-chi-o-backend.md](ADR-0009-business-rule-chi-o-backend.md) |
| ADR-0010 | Bảng vai trò ở `cmd/internal/vaitro`, dùng chung cho mọi composition root | Accepted (2026-08-12) | — | [ADR-0010-bang-vai-tro-o-cmd-internal.md](ADR-0010-bang-vai-tro-o-cmd-internal.md) |
| ADR-0011 | TanStack Query v5 là thư viện data-fetching duy nhất cho server state ở frontend | Accepted (2026-08-13) | — | [ADR-0011-tanstack-query-v5.md](ADR-0011-tanstack-query-v5.md) |
| ADR-0012 | `R-19` canh bằng ESLint ở `frontend-erp`, không mở rộng `backend-erp/arch` | Accepted (2026-08-13) | — | [ADR-0012-r19-canh-o-frontend-eslint.md](ADR-0012-r19-canh-o-frontend-eslint.md) |
| ADR-0013 | `cmd/api` chạy đúng một instance | Accepted (2026-08-14) | — | [ADR-0013-cmd-api-mot-instance.md](ADR-0013-cmd-api-mot-instance.md) |
| ADR-0014 | Dead-letter là bảng riêng, không thêm cột vào `outbox` | Accepted (2026-08-14) | — | [ADR-0014-dead-letter-bang-rieng.md](ADR-0014-dead-letter-bang-rieng.md) |
| ADR-0015 | `prometheus/client_golang` cho metric, OTel SDK cho trace | Accepted (2026-08-14) | — | [ADR-0015-thu-vien-quan-trac.md](ADR-0015-thu-vien-quan-trac.md) |
| ADR-0016 | Kalmar dùng chung module `machine`, không có module riêng | Accepted (2026-08-14) | — | [ADR-0016-kalmar-dung-chung-machine.md](ADR-0016-kalmar-dung-chung-machine.md) |
| ADR-0017 | Hệ thống gồm đúng mười hai module, tên thư mục viết bằng tiếng Anh | Accepted (2026-08-14) | — | [ADR-0017-muoi-hai-module-va-ten-tieng-anh.md](ADR-0017-muoi-hai-module-va-ten-tieng-anh.md) |
| ADR-0018 | `idempotency_keys` giữ dấu vân payload và response của lần đầu, để phát lại cho `Idempotency-Key` ở tầng HTTP | Accepted (2026-08-15) | — | [ADR-0018-luu-response-cho-idempotency-key.md](ADR-0018-luu-response-cho-idempotency-key.md) |
| ADR-0019 | Phân vùng là một công ty, vai trò tính theo cặp (người, phân vùng) | Accepted (2026-08-17) | — | [ADR-0019-phan-vung-la-cong-ty.md](ADR-0019-phan-vung-la-cong-ty.md) |

Cột `Constrains` là danh sách Rule mà ADR đó là lý do tồn tại. Nó phải khớp **hai
chiều** với trường `Decisions` của Rule tương ứng trong
[../01-rules/RULES.md](../01-rules/RULES.md): RULES.md ghi `R-18` trỏ tới ADR-0008 thì
ADR-0008 phải nêu `R-18`, và ngược lại. `tools/check-ids.ps1` kiểm cả hai chiều; thiếu
một chiều là chuỗi truy vết bị đứt và script báo đỏ.

ADR không ràng buộc Rule nào — ADR-0002, ADR-0004, ADR-0005 — không kém quan trọng
hơn. Chúng chốt phạm vi và cách tổ chức, những thứ không quy về được một mệnh đề
grep được trên một diff.

## Khi nào cần viết ADR mới

Ba ca dưới đây đã được các tài liệu hiện có chỉ đích danh là **bắt buộc** có ADR trước
khi viết code. Chúng không phải gợi ý:

1. **Thêm một tên vào bất kỳ danh sách nào của registry nhóm bảng ở
   [../04-conventions/C-DB-database.md](../04-conventions/C-DB-database.md) mục
   `C-DB-04`** — `system_tables`, `tenant_root`, `reference_tables`,
   `append_only_tables`, hoặc `naming_exempt`. Năm danh sách đó sống ở tầng
   Convention, không phải tầng Decision — nhưng thứ giữ cho không ai âm thầm mở rộng
   miễn trừ không phải chỗ chúng nằm, mà là **trường `adr` bắt buộc ở mỗi entry**: mỗi
   dòng phải trỏ tới một ADR `Accepted` định nghĩa tiêu chí của nhóm đó, hoặc biện
   minh riêng cho chính bảng đó. `check-ids.ps1` kiểm được vế "ADR tồn tại và ở trạng
   thái Accepted"; vế "thỏa tiêu chí" là việc của reviewer. Ca hay gặp nhất: đặt tên
   bảng là `inventory` hay `equipment` — tên không kết thúc bằng `s`, phải có ADR
   trước khi merge migration.
2. **Cho phép hard delete một bảng nghiệp vụ hoặc một bảng danh mục.** ADR phải liệt
   kê **đúng tên bảng** được phép, và chỗ xóa trong code trỏ ngược về ADR đó bằng
   comment. Bảng trong `append_only_tables` không cần ADR — chúng đã được
   [ADR-0003](ADR-0003-multi-tenant-ready.md) cho phép dọn theo lịch giữ liệu.
3. **Mở đường cho ca hai module phải cùng commit nguyên tử.** Đây là chỗ ranh giới
   module hiện tại không đỡ nổi yêu cầu nghiệp vụ. Bộ Rule cố ý không có đường đi hợp
   lệ cho ca này: R-15 nói dừng lại hỏi người, và câu trả lời là một ADR đổi ranh giới
   — không phải một ngoại lệ cấp lẻ trong một PR.

Ngoài ba ca đó, quy tắc chung: viết ADR khi quyết định **khó đảo ngược** hoặc khi lý
do sẽ bị quên. Chọn thư viện JSON không cần ADR; chọn cách phân trang cho toàn bộ API
thì có. Nếu phân vân, hỏi: *sáu tháng nữa có ai mở lại cuộc tranh luận này không?* Có
thì viết.
