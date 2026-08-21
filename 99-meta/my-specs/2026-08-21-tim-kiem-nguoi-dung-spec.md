# Tìm kiếm người dùng trên `GET /users`

Trạng thái: **chưa làm**, tách ra khỏi đợt thiết kế lại màn quản trị người dùng
(2026-08-21). Chốt của đợt đó: không đụng backend, ghi lại thành spec này.

## Vấn đề

`GET /users` hôm nay chỉ nhận `page`, `page_size`, `sort`
(`backend-erp/modules/auth/internal/handler/user_handler.go:115-117`). Không có tham số
lọc hay tìm kiếm nào.

Nên màn `/nguoi-dung` không thể có ô tìm. Người quản trị muốn tìm một người phải sắp xếp
theo email rồi lật trang bằng mắt. Chấp nhận được ở quy mô vài chục tới trăm người dùng
một phân vùng; hỏng ngay khi một phân vùng vượt vài trăm người.

## Đề xuất

Thêm đúng **một** tham số `q` vào `ListUsersQuery`:

- Khớp không phân biệt hoa thường trên `email` **và** `full_name`, kiểu chứa
  (`ILIKE '%' || $n || '%'`).
- Cắt khoảng trắng hai đầu; `q` rỗng coi như không truyền.
- Giới hạn độ dài (gợi ý 100 ký tự) để không nhận chuỗi rác.
- Không thêm tham số lọc thứ hai trong đợt này. `is_active` chưa có nhu cầu lọc; thêm khi
  có người hỏi, không thêm trước.

Vẫn giữ nguyên envelope và `meta` của R-12: `q` chỉ thu hẹp tập, không đổi hình dạng
response.

## Index

`ILIKE '%...%'` không dùng được B-tree. Hai đường:

1. **`pg_trgm` + GIN** trên `lower(email)` và `lower(full_name)`, lọc thêm theo
   `company_id`. Đúng bài, nhưng kéo theo một extension.
2. **Không thêm index**, chấp nhận seq scan trong phạm vi một `company_id`. Ở quy mô vài
   trăm hàng một phân vùng thì rẻ hơn cả việc bảo trì index.

Chọn (2) trước, và chỉ chuyển sang (1) khi đo được truy vấn chậm thật. Ghi lại con số lúc
đo, đừng đoán.

Bất kể chọn đường nào, câu WHERE phải giữ `company_id = $1` **đứng trước** (R-06), để index
phân vùng còn dùng được.

## Việc phải làm

- [ ] `ListUsersQuery` nhận `form:"q"`, cắt khoảng trắng, giới hạn độ dài.
- [ ] `user_repository.go` ghép điều kiện `q` vào câu SELECT và câu COUNT - **cả hai**,
      không thì `meta.total` nói dối.
- [ ] Test repository: có `q` khớp email, khớp tên, không khớp gì, `q` rỗng,
      `q` chứa `%` và `_` (phải được thoát, không thành ký tự đại diện).
- [ ] Test handler: `q` quá dài trả 422 kèm thông điệp đọc được.
- [ ] Frontend: thêm ô tìm vào thanh lọc màn `/nguoi-dung`, ghi `q` lên URL cạnh `page` và
      `page_size` (`user-list-params.ts`), gõ xong chờ một nhịp mới gọi, đổi `q` thì về
      trang 1.
- [ ] Màn rỗng phải phân biệt hai ca: **chưa có người dùng nào** và **không ai khớp
      "abc"**. Ca thứ hai mang đường ra là nút xoá ô tìm.

## Liên quan

- Đợt thiết kế lại màn quản trị người dùng: `mockup-erp/nguoi-dung-danh-sach.html`,
  `mockup-erp/nguoi-dung-chi-tiet.html`.
- Bàn giao gần nhất: `2026-08-21-ban-giao.md`.
