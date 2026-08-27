# Decisions — 29 ADR nền

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

## Hai mươi chín ADR hiện có

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
| ADR-0010 | Bảng vai trò ở `cmd/internal/vaitro`, dùng chung cho mọi composition root | Superseded by ADR-0023 | — | [ADR-0010-bang-vai-tro-o-cmd-internal.md](ADR-0010-bang-vai-tro-o-cmd-internal.md) |
| ADR-0011 | TanStack Query v5 là thư viện data-fetching duy nhất cho server state ở frontend | Accepted (2026-08-13) | — | [ADR-0011-tanstack-query-v5.md](ADR-0011-tanstack-query-v5.md) |
| ADR-0012 | `R-19` canh bằng ESLint ở `frontend-erp`, không mở rộng `backend-erp/arch` | Accepted (2026-08-13) | — | [ADR-0012-r19-canh-o-frontend-eslint.md](ADR-0012-r19-canh-o-frontend-eslint.md) |
| ADR-0013 | `cmd/api` chạy đúng một instance | Accepted (2026-08-14) | — | [ADR-0013-cmd-api-mot-instance.md](ADR-0013-cmd-api-mot-instance.md) |
| ADR-0014 | Dead-letter là bảng riêng, không thêm cột vào `outbox` | Accepted (2026-08-14) | — | [ADR-0014-dead-letter-bang-rieng.md](ADR-0014-dead-letter-bang-rieng.md) |
| ADR-0015 | `prometheus/client_golang` cho metric, OTel SDK cho trace | Accepted (2026-08-14) | — | [ADR-0015-thu-vien-quan-trac.md](ADR-0015-thu-vien-quan-trac.md) |
| ADR-0016 | Kalmar dùng chung module `machine`, không có module riêng | Accepted (2026-08-14) | — | [ADR-0016-kalmar-dung-chung-machine.md](ADR-0016-kalmar-dung-chung-machine.md) |
| ADR-0017 | Hệ thống gồm đúng mười hai module, tên thư mục viết bằng tiếng Anh | Accepted (2026-08-14) | — | [ADR-0017-muoi-hai-module-va-ten-tieng-anh.md](ADR-0017-muoi-hai-module-va-ten-tieng-anh.md) |
| ADR-0018 | `idempotency_keys` giữ dấu vân payload và response của lần đầu, để phát lại cho `Idempotency-Key` ở tầng HTTP | Accepted (2026-08-15) | — | [ADR-0018-luu-response-cho-idempotency-key.md](ADR-0018-luu-response-cho-idempotency-key.md) |
| ADR-0019 | Phân vùng là một công ty, vai trò tính theo cặp (người, phân vùng) | Accepted (2026-08-17) | — | [ADR-0019-phan-vung-la-cong-ty.md](ADR-0019-phan-vung-la-cong-ty.md) |
| ADR-0020 | Data Scope là một tập bản ghi treo vào một hàng gán vai trò, giải ở tầng service, không đi vào token | Accepted (2026-08-20) | — | [ADR-0020-data-scope-theo-ban-ghi.md](ADR-0020-data-scope-theo-ban-ghi.md) |
| ADR-0021 | Vai trò mang tên module, quyền gán vai trò và gán phạm vi là permission của module sở hữu | Accepted (2026-08-21) | — | [ADR-0021-vai-tro-theo-module.md](ADR-0021-vai-tro-theo-module.md) |
| ADR-0022 | Bảng `units` có đúng một đường ghi công khai là tạo mới, không sửa và không xoá | Accepted (2026-08-21) | — | [ADR-0022-mo-duong-ghi-cho-bang-units.md](ADR-0022-mo-duong-ghi-cho-bang-units.md) |
| ADR-0023 | Ánh xạ vai trò → quyền xuống database, vai trò là dữ liệu cấp công ty do người quản trị tự khai | Accepted (2026-08-21) | — | [ADR-0023-vai-tro-xuong-database.md](ADR-0023-vai-tro-xuong-database.md) |
| ADR-0024 | Thẩm quyền trên một vai trò tính từ TẬP QUYỀN của nó, không từ tên nó | Accepted (2026-08-22) | — | [ADR-0024-tham-quyen-tren-vai-tro-tinh-tu-tap-quyen.md](ADR-0024-tham-quyen-tren-vai-tro-tinh-tu-tap-quyen.md) |
| ADR-0025 | Nhãn vai trò đi kèm `GET /auth/me`, bỏ bảng nhãn chép tay ở frontend | Accepted (2026-08-22) | — | [ADR-0025-nhan-vai-tro-kem-auth-me.md](ADR-0025-nhan-vai-tro-kem-auth-me.md) |
| ADR-0026 | Toàn phạm vi không còn là một permission, nó là dữ liệu treo cùng chỗ với phạm vi | Accepted (2026-08-22) | — | [ADR-0026-toan-pham-vi-khong-la-mot-permission.md](ADR-0026-toan-pham-vi-khong-la-mot-permission.md) |
| ADR-0027 | Permission của module mới tới công ty đã tồn tại bằng một lệnh tường minh, không ghi đè lựa chọn của tenant | Accepted (2026-08-22) | — | [ADR-0027-permission-module-moi-vao-cong-ty-da-co.md](ADR-0027-permission-module-moi-vao-cong-ty-da-co.md) |
| ADR-0028 | Quyền chỉ tác động lên chính người giữ nó không kéo theo cửa `<module>.role_assign` | Accepted (2026-08-22) | — | [ADR-0028-quyen-tren-chinh-minh-khong-keo-theo-cua-module.md](ADR-0028-quyen-tren-chinh-minh-khong-keo-theo-cua-module.md) |
| ADR-0029 | Nhân bản quản trị trong cùng một module là hợp lệ — hệ thống không đặt luật chống tăng số người giữ một quyền | Accepted (2026-08-24) | — | [ADR-0029-nhan-ban-quan-tri-trong-cung-module.md](ADR-0029-nhan-ban-quan-tri-trong-cung-module.md) |
| ADR-0030 | Phạm vi trả lời "của ai", vòng đời trả lời "còn sống không" — danh sách id của Resolve gồm cả bản ghi đã xoá mềm | Accepted (2026-08-24) | R-18 | [ADR-0030-pham-vi-tra-loi-cua-ai-khong-tra-loi-con-song-khong.md](ADR-0030-pham-vi-tra-loi-cua-ai-khong-tra-loi-con-song-khong.md) |
| ADR-0031 | `quan_tri_he_thong` cầm thêm `auth.user_create`, và chỉ thêm đúng mã đó | Accepted (2026-08-24) | — | [ADR-0031-quan-tri-he-thong-quan-ly-tai-khoan.md](ADR-0031-quan-tri-he-thong-quan-ly-tai-khoan.md) |
| ADR-0032 | Danh mục vai trò lọc theo thẩm quyền của actor, và module suy từ tập quyền chứ không từ mã vai trò | Accepted (2026-08-24) | — | [ADR-0032-danh-muc-vai-tro-loc-theo-tham-quyen-cua-actor.md](ADR-0032-danh-muc-vai-tro-loc-theo-tham-quyen-cua-actor.md) |
| ADR-0033 | Phân vùng thành cây, và ranh giới dữ liệu chỉ mở theo một chiều lên trên | Proposed (2026-08-24) | R-06 | [ADR-0033-phan-vung-thanh-cay-doc-len-mot-chieu.md](ADR-0033-phan-vung-thanh-cay-doc-len-mot-chieu.md) |
| ADR-0034 | Một tài khoản đi được mọi phân vùng, và hai câu truy vấn chạy trước khi có phân vùng | Proposed (2026-08-25) | R-06 | [ADR-0034-mot-tai-khoan-di-duoc-moi-phan-vung.md](ADR-0034-mot-tai-khoan-di-duoc-moi-phan-vung.md) |
| ADR-0035 | Vùng dữ liệu là một loại phạm vi, không phải một cột mới | Accepted (2026-08-24) | R-06, R-18 | [ADR-0035-vung-du-lieu-la-mot-loai-pham-vi.md](ADR-0035-vung-du-lieu-la-mot-loai-pham-vi.md) |
| ADR-0036 | Quản trị hệ thống đi được mọi phân vùng mà không cần là thành viên | Accepted (2026-08-27) | R-06 | [ADR-0036-quan-tri-he-thong-di-duoc-moi-phan-vung.md](ADR-0036-quan-tri-he-thong-di-duoc-moi-phan-vung.md) |
| ADR-0037 | Quản trị hệ thống chỉ bổ nhiệm được người bổ nhiệm được người khác | Accepted (2026-08-27) | R-15 | [ADR-0037-quan-tri-he-thong-chi-bo-nhiem-quan-tri.md](ADR-0037-quan-tri-he-thong-chi-bo-nhiem-quan-tri.md) |

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
