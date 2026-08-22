# Bàn giao: module kho, phiên 2026-08-21 → 22

Đích: một thủ kho thật ghi chuyển động thật trên `http://103.179.172.110/`.
Kế hoạch gốc và bảng 12 khối: `2026-08-21-thu-tu-dua-kho-vao-su-dung.md`.

## Chốt cuối phiên 2026-08-22

**Năm PR đã merge.** frontend #20 (sáu màn kho dùng bộ component chung) · backend #23
(`DELETE /stock-movements/:id`) · backend #24 (`POST /units`) · docs #13 · backend #25 (giới hạn
thử mật khẩu). Thứ tự code-trước-tài-liệu theo ADR-0005.

**Đã chạy thật trên dev:** seed 14 đơn vị tính (14 dòng audit `unit.created`) · dọn 6.7 GB build
cache, đĩa 79% → 45% · nạp hai quyền mới cho `inventory.admin` của cả hai công ty
(`INSERT 0 4`, mỗi công ty 26 quyền, `co_xoa_mem` và `co_them_don_vi` đều `t`).

### Chỗ hở đáng làm tiếp, theo thứ tự

1. **Không có endpoint sửa tập quyền của một vai trò.** ADR-0024 và ADR-0027 đặt tập quyền dưới
   thẩm quyền quản trị công ty, nhưng chỉ có `PUT /users/:id/roles` và `GET /roles`. Nên mọi lần
   thêm một quyền cho công ty đang chạy đều phải qua SQL thô. Việc này sẽ lặp lại ở 9 module còn
   lại.
2. **Khai `LOGIN_RATE_LIMIT` trong `infra-erp`** cho máy dev. Thiếu nó thì mặc định 20 vẫn chạy,
   nhưng người vận hành không có nút nới khi văn phòng sau NAT bị chặn oan.
3. **Khối 5 — tìm kiếm danh mục.** Khối cuối cùng còn chặn ngày đi vào sử dụng: form ghi chuyển
   động nạp danh mục với `page_size` bằng trần 100, quy mô thật là vài trăm mã, nên hai phần ba
   danh mục không chọn được. Spec có đủ ở cả hai repo.
4. Khối 6 nạp tồn đầu kỳ · khối 7 sổ chuyển động tra được · khối 10 luật chặn sửa mã.

### Bốn cái bẫy đã ghi vào memory

Cả bốn cùng một hình dạng: **thông điệp lỗi mô tả hậu quả, không mô tả nguyên nhân.**

| Triệu chứng | Nguyên nhân thật |
|---|---|
| `go: command not found` trên VPS | Go có, ngoài `PATH` của shell không đăng nhập — bọc `bash -lc` |
| chín bài `erp/arch` đỏ | thiếu `docs-erp` bên cạnh — đặt `ERP_DOCS_PATH` |
| ba bài `migrator` đỏ | file cũ còn sót vì `tar` bung đè không xoá — xoá thư mục trước khi bung |
| PR không có check nào | PR xung đột nên GitHub không dựng được commit hợp nhất |

### Chỗ làm việc còn để lại

Ba worktree trong scratchpad (`wt-xoa-mem`, `wt-docs`, `wt-rebase`), dùng vì cây
`d:\My project web\erp\*` chia chung với các phiên khác. Xoá được sau khi đọc bàn giao này.

