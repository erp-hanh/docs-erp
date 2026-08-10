# `<ten-module>` — Permission

> **Khung tài liệu — xóa mọi dòng trích dẫn `>` sau khi điền xong.**
>
> File này liệt kê **toàn bộ permission** của module, ai được làm gì, và method service
> nào kiểm permission nào. Nó là bản đồ để trả lời một câu hỏi hay gặp trong lúc vận
> hành: *"người này bấm nút mà bị chặn, thiếu quyền nào?"*

## 0. Ràng buộc phải giữ khi sửa file này

> **Mọi method public của service phải có đúng một dòng ở mục 2 (R-15).** Không có
> ngoại lệ ngầm: method mang tiền tố `Internal` cũng có dòng, chỉ khác là cột permission
> ghi `— (Internal)` và tên method phải có mặt trong `internal_methods` của
> `module.yaml`.
>
> Một method public không có dòng ở đây thì hoặc là nó thiếu kiểm quyền, hoặc là tài
> liệu đang lạc hậu — cả hai đều phải sửa trước khi merge, và người review không có cách
> nào biết đó là ca nào nếu chỉ nhìn code.
>
> Nhắc kèm hai điều dễ nhầm: kiểm quyền là **câu lệnh đầu tiên** của thân method, không
> có dòng nào đứng trước; và ẩn nút ở frontend **không** tính là kiểm quyền.

## 1. Danh sách permission

> Hằng quyền đặt tên `Perm<Đối tượng><Hành động>`, giá trị là chuỗi
> `<ten-module>.<hành động>`, khai ở package `service` của chính module này.

| Hằng trong code | Giá trị | Cho phép làm gì |
|---|---|---|
| `Perm<DoiTuong>Read` | `<ten-module>.read` | Xem danh sách và chi tiết |
| `Perm<DoiTuong>Create` | `<ten-module>.create` | Tạo mới |
| `Perm<DoiTuong>Update` | `<ten-module>.update` | Sửa bản ghi chưa chốt |
| `Perm<DoiTuong>Delete` | `<ten-module>.delete` | Xóa mềm |
| `Perm<DoiTuong><HanhDong>` | `<ten-module>.<hanh-dong>` | <hành động nghiệp vụ riêng> |

## 2. Method service và permission nó kiểm

> Đây là mục chính của file. Mỗi method public của mỗi service trong module có **đúng
> một** dòng.

| Service | Method | Permission kiểm ở câu lệnh đầu | Endpoint gọi tới |
|---|---|---|---|
| `<DoiTuong>Service` | `List<DoiTuong>` | `Perm<DoiTuong>Read` | `GET /api/v1/<tai-nguyen>` |
| `<DoiTuong>Service` | `Get<DoiTuong>` | `Perm<DoiTuong>Read` | `GET /api/v1/<tai-nguyen>/:id` |
| `<DoiTuong>Service` | `Create<DoiTuong>` | `Perm<DoiTuong>Create` | `POST /api/v1/<tai-nguyen>` |
| `<DoiTuong>Service` | `Update<DoiTuong>` | `Perm<DoiTuong>Update` | `PUT /api/v1/<tai-nguyen>/:id` |
| `<DoiTuong>Service` | `Delete<DoiTuong>` | `Perm<DoiTuong>Delete` | `DELETE /api/v1/<tai-nguyen>/:id` |
| `<DoiTuong>Service` | `Internal<TenMethod>` | `— (Internal)` | không có — gọi từ service cùng module |

**Method mang tiền tố `Internal` trong module này:**

| Method | Ai gọi nó | Vì sao nó không tự kiểm quyền |
|---|---|---|
| `Internal<TenMethod>` | `<TenService>.<TenMethodPublic>` | Người gọi đã kiểm `Perm<...>` ngay câu lệnh đầu |

> Ba điều kiện của một method `Internal`, phải đủ cả ba: tên mang tiền tố `Internal`; tên
> có trong `internal_methods` của `module.yaml`; tên **không** xuất hiện ở bất kỳ
> interface nào trong `modules/*/api/`. Nó vẫn nhận `actor` làm tham số thứ hai và vẫn
> tự ghi bản ghi audit — thứ duy nhất nó được miễn là vế "câu lệnh đầu tiên là kiểm
> quyền".

## 3. Ai có quyền gì

| Vai trò | Permission được cấp | Ghi chú |
|---|---|---|
| `<vai_tro_1>` | tất cả permission của module | <...> |
| `<vai_tro_2>` | `<ten-module>.read`, `<ten-module>.create` | Không duyệt, không xóa |
| `<vai_tro_3>` | `<ten-module>.read` | Chỉ xem |

> Bảng này mô tả cấu hình mặc định lúc khởi tạo hệ thống, không phải nguồn sự thật lúc
> chạy — quyền thật nằm trong dữ liệu và người quản trị đổi được. Ghi ở đây để người mới
> có điểm bắt đầu và để người review thấy được ý định ban đầu.

## 4. Điều file này cố ý KHÔNG mô tả

- **Cách kiểm quyền được cài đặt.** Đó là việc của `shared/authz`; module chỉ gọi.
- **Quyền hiển thị ở frontend.** Frontend ẩn nút theo permission là chuyện trải nghiệm
  người dùng; nó không thay thế và không được phép mâu thuẫn với bảng ở mục 2. Nếu một
  nút hiện ra mà bấm vào bị chặn, thứ sai là frontend, không phải backend.
- **Quyền xem dữ liệu của công ty khác.** Không có quyền nào cấp được điều đó: mọi truy
  vấn lọc theo `company_id` của actor, và bản ghi thuộc công ty khác trả `404` chứ không
  phải `403`.
