# `<ten-module>` — Workflow

> **Khung tài liệu — xóa mọi dòng trích dẫn `>` sau khi điền xong.**
>
> File này mô tả **luồng nghiệp vụ** của module: các bước, các trạng thái, và điều kiện
> để đi từ trạng thái này sang trạng thái kia. Nó là thứ người mới đọc để hiểu module
> làm gì, và là thứ người review mở ra khi nghi ngờ một nhánh code đang thiếu.

## 0. Ràng buộc phải giữ khi sửa file này

> **Bảng chuyển trạng thái hợp lệ sống ở backend, không sống ở frontend (R-19).**
> Frontend cấm chứa bảng chuyển trạng thái hardcode để quyết định bật/tắt hành động; nó
> chỉ được dựa vào field mà API trả về (ví dụ `allowed_actions`). Sơ đồ ở file này là
> **mô tả** của bảng nằm trong service, không phải một bản sao thứ hai được phép lệch.
>
> Hệ quả cụ thể khi thêm một trạng thái mới: sửa bảng chuyển trạng thái trong service →
> sửa `CHECK` constraint của cột `status` bằng migration mới → sửa sơ đồ ở đây. Không có
> bước nào sửa frontend, vì frontend không giữ tri thức đó.
>
> Cùng lý do: mọi phép tính tiền, thuế, tồn kho nêu ở file này là phép tính chạy ở
> backend. Frontend được hiển thị con số tạm tính cho người dùng thấy, nhưng không được
> gửi con số nó tự tính lên server.

## 1. Các luồng nghiệp vụ

| Luồng | Ai chạy | Điểm vào | Kết thúc khi |
|---|---|---|---|
| `<Tên luồng 1>` | <vai trò> | `POST /api/v1/<tai-nguyen>` | <trạng thái cuối> |
| `<Tên luồng 2>` | <vai trò> | `POST /api/v1/<tai-nguyen>/:id/actions/<verb>` | <...> |

## 2. `<Tên luồng 1>`

**Mục đích:** <một câu, bằng ngôn ngữ nghiệp vụ>

**Điều kiện tiền đề:** <thứ phải đúng trước khi luồng bắt đầu>

**Các bước:**

| # | Bước | Ở đâu | Ghi chú |
|---|---|---|---|
| 1 | <bind và validate hình dạng request> | `<...>_handler.go` | Sai hình dạng trả `422` |
| 2 | <kiểm quyền> | `<...>_service.go` | Câu lệnh đầu tiên của method |
| 3 | <validate nghiệp vụ, cần đọc DB> | `<...>_service.go` | Sai trạng thái trả `409` |
| 4 | <mở transaction, ghi dữ liệu> | `<...>_service.go` | Ghi audit trong cùng transaction |
| 5 | <ghi event vào outbox> | `<...>_service.go` | Cùng transaction, không gọi bus |
| 6 | <commit> | `<...>_service.go` | |

**Nhánh thất bại và mã lỗi:**

| Tình huống | Status | Mã lỗi | Người dùng thấy gì |
|---|---|---|---|
| <...> | `422` | `ERR_COMMON_VALIDATION_FAILED` | <...> |
| <...> | `409` | `<ERR_...>` | <...> |
| <...> | `404` | `<ERR_..._NOT_FOUND>` | <...> |

**Thứ luồng này cố ý KHÔNG làm:** <ví dụ: không trừ tồn kho — việc đó do module
`inventory` làm khi nhận event; nêu rõ để người đọc không đi tìm một đoạn code không tồn
tại>

## 3. Sơ đồ trạng thái

> Vẽ đúng bảng chuyển trạng thái đang nằm trong service. Mỗi mũi tên ghi **hành động**
> làm nó xảy ra, không chỉ ghi tên trạng thái đích.

```text
                 <hanh_dong_1>              <hanh_dong_2>
  <trang_thai_A> ────────────> <trang_thai_B> ────────────> <trang_thai_C>
        │                            │
        │ <huy>                      │ <huy>
        ▼                            ▼
  <trang_thai_huy>             <trang_thai_huy>
```

**Bảng chuyển trạng thái hợp lệ:**

| Từ | Hành động | Sang | Điều kiện thêm |
|---|---|---|---|
| `<trang_thai_A>` | `<hanh_dong_1>` | `<trang_thai_B>` | <...> |
| `<trang_thai_B>` | `<hanh_dong_2>` | `<trang_thai_C>` | <...> |
| `<trang_thai_A>` | `<huy>` | `<trang_thai_huy>` | <...> |

> Cặp `(từ, hành động)` không có dòng trong bảng này là chuyển trạng thái **không hợp
> lệ**, và service phải trả `409` với mã lỗi trạng thái tương ứng. Danh sách giá trị của
> cột `status` trong bảng dữ liệu phải khớp đúng tập trạng thái ở đây, và nó được ép
> bằng một `CHECK` constraint chứ không bằng quy ước.

**Trạng thái cuối (không đi tiếp được):** `<trang_thai_C>`, `<trang_thai_huy>`

## 4. Việc chạy nền và việc theo lịch

| Việc | Kích hoạt bởi | Làm gì | Chạy lại được không |
|---|---|---|---|
| `<...>` | <event / lịch / thao tác người dùng> | <...> | <có — theo cơ chế nào> |

> Cột cuối không được để trống. Mọi việc nhận event đều có khả năng bị gọi lại với cùng
> một event, nên câu trả lời "không" ở đây là một lỗi thiết kế chưa được sửa, không phải
> một đặc điểm được ghi nhận.
