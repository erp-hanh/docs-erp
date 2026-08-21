# Ba luật khi gán vai trò - cứu từ mockup `quan-tri-phan-quyen.html`

Trạng thái: **chưa làm**. Tách ra trong đợt rà soát mockup 2026-08-21.

Ba luật dưới đây từng bị nhốt trong `mockup-erp/quan-tri-phan-quyen.html`. Chúng là **luật
nghiệp vụ**, không phải thiết kế màn hình, nên chỗ đúng của chúng là ở đây. Mockup đó đã bị
xoá vì phần còn lại của nó dạy sai (bốn mã vai trò không tồn tại, hai câu sai sự thật về
backend, một trường API bịa) - xem "Vì sao bỏ mockup" ở cuối.

Hai màn đang thay thế nó: `mockup-erp/nguoi-dung-danh-sach.html`,
`mockup-erp/nguoi-dung-chi-tiet.html`. **Chưa màn nào phủ ba ca dưới đây.**

## Luật 1 - Bỏ hết vai trò không đồng nghĩa với gỡ khỏi phân vùng

Người bị bỏ hết vai trò **vẫn đăng nhập được, vẫn chọn được phân vùng đó**, nhưng mọi màn
trả 403. Đó là một trạng thái khó hiểu từ phía người dùng.

Màn phải nói ra **trước khi lưu**, và nói cả đường làm đúng nếu ý định thật sự là gỡ hẳn:

> **Người này sẽ không còn vai trò nào trong phân vùng**
> Họ vẫn đăng nhập và vẫn chọn được phân vùng này, nhưng mọi màn sẽ báo không đủ quyền.
> Muốn gỡ hẳn thì dùng "Gỡ khỏi phân vùng".

Ràng buộc: câu cuối chỉ được viết ra **khi đã có** đường "Gỡ khỏi phân vùng". Hôm nay chưa
có (`DELETE /users/:id` là xoá mềm người dùng, khác nghĩa). Chỉ đường tới một nút không tồn
tại còn tệ hơn không chỉ gì cả - nên khi thi công, hoặc làm đường đó trước, hoặc bỏ câu
cuối.

Chỗ hạ cánh: khối vai trò của `/nguoi-dung/:id`, cùng nơi đang hiện cảnh báo
"gỡ vai trò sẽ xoá N kho".

## Luật 2 - Phân vùng phải còn ít nhất một quản trị viên

Quản trị viên duy nhất tự bỏ vai trò admin của mình là khoá cửa rồi vứt chìa vào trong.

**Frontend không được tự quyết điều này** - nó không biết phân vùng còn bao nhiêu quản trị
viên, và có đếm được cũng là suy luận nghiệp vụ ở tầng sai (R-19). Backend trả **409**, màn
hiện câu trả lời đó, đúng như mọi lỗi 409 khác:

> **Phân vùng phải còn ít nhất một quản trị viên**
> Gán vai trò quản trị cho một người khác trước, rồi quay lại bước này.
> Mã tra cứu: ...

Việc phải làm ở backend: `UserService.ThayVaiTro` kiểm trước khi ghi, trả 409 kèm thông
điệp đọc được. Có test cho ca "admin cuối cùng tự hạ quyền" và ca "còn admin khác thì cho
qua".

## Luật 3 - Đổi vai trò của chính mình phải làm mới phiên

Vai trò nằm trong access token (R-14), nên token đang cầm **vẫn mang vai trò cũ** cho tới
lần làm mới tiếp theo. Không làm mới thì người vừa tự đổi quyền vẫn thấy đầy đủ nút cho tới
khi token hết hạn, rồi ăn một loạt 403 khó hiểu.

Frontend: sau khi `PUT /users/:id/roles` thành công **và** `:id` là chính người đang đăng
nhập, gọi làm mới token rồi mới cập nhật giao diện. Không được chỉ invalidate cache người
dùng - cache đúng mà token sai thì màn vẫn nói dối.

## Vì sao bỏ mockup `quan-tri-phan-quyen.html`

Ghi lại để không ai đi tìm nó:

- Nó thiết kế cho **mô hình danh tính tương lai** (bảng `identities`, email unique toàn
  cục). Kiểm 2026-08-21: 24 migration trong `backend-erp/migrations/` không file nào nhắc
  `identities`; `users` không có cột `identity_id`; email unique theo cặp
  `(company_id, email)` (`migrations/000002_create_users.up.sql:50-51`). Thiết kế treo,
  không ADR nào chống lưng.
- Nó hiện **mã vai trò thô** `quan_tri` / `thu_kho` / `ke_toan` / `ky_thuat` làm nhãn. Bốn
  mã đó không tồn tại; mã thật ở `backend-erp/cmd/internal/vaitro/vaitro.go:57-73`.
- Nó vẽ **mô tả từng vai trò** và khẳng định lấy từ `GET /roles`. Endpoint đó chỉ trả
  `{ma, nhan}` và cố ý không trả thêm (`user_role_handler.go:65-68`).
- Nó ghi "backend phải có thêm `GET /roles` và `POST /users`". Cả hai **đã có**.
  `POST /users` còn khác nghĩa: bắt buộc `password` và `full_name`, tức là *tạo người mới*,
  không phải *gắn danh tính đã có vào phân vùng*.
- Nó **không biết đến phạm vi dữ liệu**, trong khi `PUT /users/:id/scopes` và bảng
  `user_company_role_scopes` đã có từ migration 000023.

## Liên quan

- ADR-0019 (phân vùng là công ty), ADR-0020 (data scope theo bản ghi), ADR-0021 (vai trò
  theo module).
- `2026-08-21-tim-kiem-nguoi-dung-spec.md` - việc còn mở khác của cùng cụm màn.
