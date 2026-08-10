# Module `<ten-module>`

> **Khung tài liệu — xóa mọi dòng trích dẫn `>` sau khi điền xong.**
>
> Copy cả thư mục `module-docs/` sang repo code, đặt tại `modules/<ten-module>/docs/`.
> Theo ADR-0005, tài liệu của module sống trong repo code **cùng module**, không sống ở
> `docs-erp`. Repo `docs-erp` giữ Rule, Principle, Decision, Convention và Checklist —
> những thứ đúng cho mọi module; file này giữ thứ chỉ đúng cho module này.
>
> Năm file bắt buộc của một module: `README.md`, `Database.md`, `Workflow.md`,
> `Permission.md`, `Events.md`. Thiếu một file là module chưa xong.

## 1. Module này làm gì

<2-3 câu. Nói phạm vi nghiệp vụ module chịu trách nhiệm, bằng ngôn ngữ của người dùng
chứ không bằng ngôn ngữ của code.

Câu cuối nói module này **không** làm gì — ranh giới với module lân cận là thứ người đọc
cần nhất và là thứ hay bị hiểu sai nhất. Ví dụ: "Module này quản lý vòng đời đơn hàng từ
lúc tạo tới lúc đóng. Nó **không** giữ tồn kho và **không** tính công nợ; hai việc đó
thuộc `inventory` và `finance`.">

## 2. Bảng module sở hữu

> Danh sách dưới đây phải **khớp từng dòng** với trường `tables` trong `module.yaml`.
> Lệch một tên là bộ kiểm không còn phân biệt được đâu là bảng của module, đâu là truy
> cập chéo module — R-02 báo xanh trên một vi phạm thật.

| Bảng | Vai trò trong module | Chi tiết |
|---|---|---|
| `<bang_1>` | <bảng gốc / bảng con / bảng nối> | `Database.md` |
| `<bang_2>` | <...> | `Database.md` |

Bảng thuộc `system_tables`, `tenant_root` và `reference_tables` không liệt kê ở đây:
chúng không thuộc module nào và mọi module đều đọc được. `outbox` và `audit_logs` cũng
không — module chạm tới chúng qua package dùng chung của `shared/`, không bằng
repository của mình.

## 3. Module phụ thuộc

> Danh sách dưới đây phải **khớp** với trường `allowed_deps` trong `module.yaml`.
> Module không có tên ở đây thì mọi liên lạc phải đi qua event (`Events.md`).

| Module được gọi đồng bộ | Gọi để làm gì | Interface dùng |
|---|---|---|
| `<module_khac>` | <việc cụ thể, không phải "để lấy dữ liệu"> | `modules/<module_khac>/api.<TenInterface>` |

Với mỗi dòng ở trên, câu hỏi phải trả lời được: *nếu module kia hỏng, việc này còn được
coi là đã xong không?* Trả lời "không" thì gọi đồng bộ là đúng; trả lời "có" thì đáng lẽ
phải là event.

Nhắc kèm: quan hệ hai chiều bị cấm. Nếu `<module_khac>` đã có tên module này trong
`allowed_deps` của nó thì dòng trên là vi phạm, không phải một lựa chọn thiết kế.

## 4. Điểm vào chính

| Loại | Đường dẫn | Ghi chú |
|---|---|---|
| Hàm khởi tạo và đăng ký | `modules/<ten-module>/module.go` | Thứ duy nhất `cmd/**` được import |
| Hợp đồng cho module khác | `modules/<ten-module>/api/` | Interface + DTO, giữ ổn định |
| Route HTTP | `modules/<ten-module>/internal/handler/` | Đăng ký dưới `/api/v1` |
| Nghiệp vụ | `modules/<ten-module>/internal/service/` | Sở hữu ranh giới transaction |

Route module cung cấp:

| Method | Path | Mô tả |
|---|---|---|
| `GET` | `/api/v1/<tai-nguyen>` | <...> |
| `POST` | `/api/v1/<tai-nguyen>` | <...> |

## 5. Đọc gì tiếp

| Câu hỏi | File |
|---|---|
| Bảng nào, cột nào, index nào | `Database.md` |
| Luồng nghiệp vụ và trạng thái | `Workflow.md` |
| Ai được làm gì | `Permission.md` |
| Event phát ra và nhận vào | `Events.md` |
| Vì sao có quy tắc đang chặn tôi | `docs-erp/01-rules/RULES.md` |
