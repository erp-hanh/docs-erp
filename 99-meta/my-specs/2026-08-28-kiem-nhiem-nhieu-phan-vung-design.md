# Kiêm nhiệm nhiều phân vùng — thiết kế

**Ngày:** 2026-08-28
**Trạng thái:** thiết kế đã chốt, chưa thi công

## Vấn đề

Một người làm cho hai đơn vị — ví dụ một kế toán lo cả Đà Nẵng lẫn Nhà máy Thái Bình — hôm nay
không có đường nào đi qua ứng dụng.

Hạ tầng thì đã sẵn sàng. `user_companies` nói một người làm ở những phân vùng nào, email đã duy
nhất toàn hệ từ migration `000030`, và bước chọn phân vùng sau khi đăng nhập đã chạy. Trên máy
dev `qa-admin@erp.test` đang đi được hai phân vùng và mọi thứ hoạt động.

Thiếu đúng một thứ: **không có cách nào tạo ra hàng `user_companies` thứ hai**. Cả repo chỉ có
một chỗ chèn bảng đó, nằm trong `CreateUser` (`modules/auth/internal/service/user_service.go:374`),
và nó luôn gán vào phân vùng của người đang thao tác. Hàng thứ hai của `qa-admin` phải chèn tay
bằng SQL.

Ba hệ quả đo được:

- Gõ email đã tồn tại ở đơn vị khác thì nhận `409` trùng email (`user_service.go:1642-1646`), không
  có gợi ý nào về việc người đó đã có trong hệ.
- Không có đường gỡ một người khỏi một phân vùng. `DELETE /users/:id` xoá mềm cả con người
  (`user_service.go:861-880`), không đụng `user_companies`.
- Frontend chưa có cả màn thêm người dùng (`UserListPage.tsx:142`).

## Quyết định nghiệp vụ

Quản trị Trụ sở thêm người, gõ email của một người đang làm ở Hà Nội thì màn hình **báo là người
này đã có trong hệ, hiện tên, và mời thêm họ vào Trụ sở bằng một cú bấm**. Người đó giữ nguyên mật
khẩu cũ; lần sau đăng nhập họ chọn đơn vị muốn vào.

Hai phương án bị loại:

- **Tự nối luôn, không hỏi** — gõ nhầm một ký tự là kéo nhầm người vào đơn vị mà không ai kịp cản.
- **Chỉ quản trị hệ thống gắn được người vào nhiều đơn vị** — mọi ca kiêm nhiệm đều phải qua một
  người, trong khi việc này là việc thường ngày của quản trị từng đơn vị.

## Ranh giới không được nới

**Không mở một đường ghi xuyên phân vùng nào.** Quản trị Trụ sở chỉ thêm người **vào Trụ sở**.
Muốn người đó cũng có mặt ở Hà Nội thì quản trị Hà Nội tự làm ở đơn vị mình. Cả hai đường ghi mới
lấy `company_id` từ actor, không bao giờ từ request — đúng cách `CreateUser` đang làm
(`user_service.go:352`).

**Một câu đọc toàn hệ mới, và nó phải được khai tên.** Để nói được "email này đã có người dùng",
service phải đọc `users` không kèm điều kiện phân vùng. ADR-0034 mục 3 chốt rằng chỉ ba câu được
miễn R-06 và danh sách đó đóng, có bộ kiểm canh bằng máy. Đợt này thêm hàng thứ tư, nên nó là một
lần sửa ADR chứ không phải một dòng code.

## Phạm vi

### 1. Hai đường mới

```
POST   /api/v1/users/:id/phan-vung     gán người này vào phân vùng của actor
DELETE /api/v1/users/:id/phan-vung     gỡ người này khỏi phân vùng của actor
```

Thân request rỗng. Phân vùng lấy từ actor.

Quyền: dùng lại `auth.user_create` cho đường gán và `auth.user_delete` cho đường gỡ. Không đẻ
thêm mã quyền mới — hai việc này là hai mặt của cùng một thẩm quyền "ai có mặt trong đơn vị tôi",
và một mã quyền mới sẽ phải gán tay cho mọi vai trò đã tồn tại ở năm phân vùng.

Các ca lỗi:

| Ca | Trả về |
|---|---|
| Người này đã có mặt trong phân vùng của actor | `409`, và nói rõ là đã có, không phải lỗi hệ |
| `:id` không tồn tại trong hệ | `404` |
| Gỡ một người không thuộc phân vùng của actor | `404`, không phải `409` — đứng từ phân vùng này nhìn thì họ không có ở đây |
| Gỡ chính mình khỏi phân vùng đang mở | `422`. Tự khoá mình ra ngoài là một cú không lùi được |
| Gỡ người cuối cùng còn mang vai trò quản trị của phân vùng | `422`. Đơn vị không được rơi vào cảnh không còn ai quản trị |

Hàng `user_companies` bị gỡ là **xoá mềm**, theo R-18. Gán lại người cũ thì hồi sinh hàng đó chứ
không chèn hàng mới — nếu không, ràng buộc duy nhất trên `(company_id, user_id)` sẽ chặn.

Vai trò của người đó **trong phân vùng bị gỡ** cũng xoá mềm theo, vì `user_company_roles` treo vào
hàng gán. Vai trò ở các phân vùng khác không bị đụng.

### 2. `POST /users` khi email đã tồn tại

Giữ nguyên `409` và giữ nguyên mã lỗi `ERR_AUTH_EMAIL_DUPLICATED` — hợp đồng cũ không đổi. Thêm
vào thân lỗi hai trường đủ để màn hình hỏi tiếp:

```json
{ "error": { "code": "ERR_AUTH_EMAIL_DUPLICATED", "message": "...",
             "nguoi_da_co": { "id": "...", "ho_ten": "Nguyễn Văn A" } } }
```

Chỉ id và họ tên. Không trả email đang làm ở đâu, không trả vai trò, không trả số điện thoại —
quản trị Trụ sở không có việc gì phải biết người này đang làm gì ở Hà Nội.

Trường này **chỉ xuất hiện khi trùng email**, tức khi quản trị đã tự gõ đúng địa chỉ đó. Nó không
làm lộ thêm gì so với `409` hiện tại: cả hai đều xác nhận email tồn tại. Khác biệt là bản mới nói
đủ để làm tiếp việc thay vì để người dùng bế tắc.

Chỗ này cần câu đọc mới ở mục 3. Không dùng lại `ByEmailToanHe` của `AuthService`: ADR-0034 mục 3
ràng buộc hàm đó chỉ được gọi từ `AuthService`, và lách ràng buộc bằng cách gọi chéo service là
đúng thứ bộ kiểm sinh ra để chặn.

### 3. Sửa tài liệu và bộ kiểm

Khối đính chính trong `ADR-0034`, thêm hàng (d) vào bảng miễn trừ R-06:

| Câu | Hàm | Vì sao không thể có `company_id` |
|---|---|---|
| (d) tra người theo email để trả lời "đã có trong hệ chưa" | `UserRepository.ByEmailToanHeRutGon` | Câu hỏi tự nó là câu hỏi toàn hệ. Lọc theo phân vùng thì luôn trả "chưa có" cho đúng ca cần phát hiện |

Ràng buộc kèm theo, kiểm được bằng máy y như ba hàng cũ:

- Hàm chỉ được gọi từ `UserService`.
- Hàm **chỉ đọc**, và chỉ trả về `id` với `full_name`. Đặt tên `RutGon` để cái tên tự nói ra rằng
  nó không trả cả hàng — một hàm trả `*model.User` đầy đủ sẽ bị dùng lại cho việc khác trong sáu
  tháng nữa.
- Tên hàm khai vào danh sách cứng trong `arch/checks_migration.go`.

### 4. Frontend

**Màn thêm người dùng** — chưa từng có. Đường dẫn riêng `/quan-tri/phan-quyen/them`, mở từ nút trên
`UserListPage`. Các ô: email, họ tên, số điện thoại, mật khẩu ban đầu.

Khi lưu mà trùng email, màn không báo lỗi đỏ. Nó đổi sang một khối xác nhận:

> **Email này đã có trong hệ thống**
> Nguyễn Văn A
> Thêm người này vào Trụ sở? Họ giữ nguyên mật khẩu đang dùng.
> `[ Thêm vào Trụ sở ]` `[ Huỷ ]`

Tên phân vùng lấy từ phiên đang mở, không gõ cứng.

**Gỡ khỏi đơn vị** — một mục trong `UserDetailPage`, tách khỏi nút xoá người dùng và nói rõ khác
biệt: gỡ khỏi đơn vị thì người đó vẫn làm việc ở nơi khác, xoá người dùng thì họ không đăng nhập
được nữa ở đâu cả.

**Cột phân vùng trong danh sách người dùng** — không làm đợt này. `UserListPage.tsx:165-169` đã
ghi lý do: `UserDTO` không mang trường nào nói người này thuộc những phân vùng nào, và thêm nó vào
là đổi một hợp đồng dùng chung. Danh sách người dùng vốn đã là danh sách của phân vùng đang mở,
nên cột đó không thêm thông tin cho màn này.

## Ngoài phạm vi

Cây phân vùng và báo cáo hợp nhất của ADR-0033 — chi nhánh có mã số thuế riêng, hạch toán độc lập
hay phụ thuộc, Trụ sở đọc số liệu của con. Đó là đợt sau, và nó nới R-06 theo một chiều hoàn toàn
khác: đọc lên trên. Đợt này không chạm một chữ nào vào R-06 ngoài việc thêm một tên hàm vào danh
sách miễn trừ đã có sẵn cơ chế.

## Cách kiểm

Test cho từng ca lỗi trong bảng ở mục 1, chạy với Postgres thật.

Ba bài không được thiếu, vì chúng là chỗ thiết kế này dễ sai nhất:

1. Gán một người vào phân vùng thứ hai, rồi đăng nhập bằng chính người đó và xác nhận họ chọn được
   cả hai đơn vị, mỗi đơn vị ra một bộ vai trò riêng.
2. Gỡ khỏi một phân vùng rồi gán lại, xác nhận hàng cũ được hồi sinh chứ không sinh hàng thứ hai.
3. Gỡ một người khỏi phân vùng A, xác nhận vai trò của họ ở phân vùng B còn nguyên.

Cuối cùng, đi thật trên máy dev bằng hai tài khoản QA: tạo trùng email, bấm thêm vào đơn vị, đăng
nhập lại và đổi qua lại giữa hai đơn vị.
