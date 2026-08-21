# Cờ `gan_duoc` trên danh mục vai trò

Trạng thái: **chưa làm**, và **cố ý gộp vào đợt thi công ADR-0023** chứ không làm riêng.

## Vấn đề

Màn `/phan-quyen/:id` đổ ra **cả tám vai trò** cho mọi người mở được nó. Nhưng ai gán được
vai trò nào lại phụ thuộc quyền của chính người đang gán.

Cụ thể hôm nay (`cmd/internal/vaitro/vaitro.go` hàm `Bang()`):

- `inventory.admin` có `auth.user_list`, `auth.user_read`, `auth.user_assign_roles`,
  `auth.user_assign_scopes` - tức **mở được màn và dùng được màn**.
- Nhưng nó chỉ có `inventory.role_assign`, **không** có `auth.role_assign` hay
  `machine.role_assign`.
- Lúc lưu, `UserService.ThayVaiTro` tính hiệu đối xứng giữa tập cũ và tập mới rồi kiểm
  `<module>.role_assign` trên từng mã đổi (`user_service.go:609`).

Hệ quả: quản trị kho vận nhìn thấy ô "Quản trị người dùng", tick vào, bấm Lưu, **ăn 403**.
Không có gì trên màn nói trước rằng ô đó không dành cho họ.

Đây không phải sơ suất. `GET /roles` **cố ý** không lọc theo quyền của actor, và lý do ghi
ở `user_role_handler.go:59-63`: trả tên permission ra là mời frontend tự đối chiếu rồi tự
ẩn - đúng kiểu suy diễn mà C-TS-06 cấm. Lập luận đó đúng. Nhưng hệ quả là người dùng chỉ
biết mình không được phép **sau khi** đã bấm.

## Đề xuất

R-19 đã có sẵn khuôn: frontend bật/tắt theo **field API trả về**, ví dụ `allowed_actions`.
Áp đúng khuôn đó vào danh mục vai trò:

```json
{ "ma": "auth.admin", "nhan": "Quản trị người dùng", "gan_duoc": false }
```

Backend tự tính từ `<module>.role_assign` của actor. Frontend chỉ đọc một boolean - không
suy diễn, không thấy tên permission nào, không phá C-TS-06.

Màn khoá ô đó lại kèm câu nói được vì sao, ví dụ: *"Vai trò này thuộc Quản trị người dùng,
bạn không cấp được."* Component `Nut` đã có `lyDoKhoa`, và `DanhSachChon` sẽ cần một cờ
khoá theo từng mục - hôm nay `khoa` của nó khoá cả danh sách, không khoá được từng dòng.

## Vì sao KHÔNG làm ngay, mà gộp vào ADR-0023

[ADR-0023](../../03-decisions/ADR-0023-vai-tro-xuong-database.md) đã Accepted 2026-08-21:
ánh xạ vai trò → quyền chuyển xuống database, vai trò thành dữ liệu cấp công ty do quản
trị tự tạo. Khi đó `GET /roles` **bị viết lại toàn bộ** - nó đọc bảng `roles` thay vì đọc
một map hằng.

Làm `gan_duoc` bây giờ là viết nó lên một bảng hằng đã có lịch xoá, rồi viết lại lần thứ
hai. Phép tính `gan_duoc` thì sống sót qua ADR-0023 (khuôn tên `<module>.<vai_trò>` và cơ
chế `<module>.role_assign` đều không đổi), nhưng chỗ đặt nó thì không.

**Cho tới lúc đó, hành vi hiện tại là: nút cứ hiện, bấm vào thì 403 nói tại chỗ.** Đó là
chính sách đã đăng ký của frontend khi chưa có `allowed_actions`, không phải một lỗi để
lại.

## Việc phải làm, khi thi công ADR-0023

- [ ] `GET /roles` trả thêm `gan_duoc` cho từng vai trò, tính từ `<module>.role_assign` của
      actor. Không trả tên permission.
- [ ] Test backend: `inventory.admin` thấy `gan_duoc: true` trên vai trò `inventory.*` và
      `false` trên `auth.*`, `machine.*`. `quan_tri_he_thong` thấy `true` hết.
- [ ] `DanhSachChon` nhận khoá theo TỪNG MỤC, không chỉ khoá cả danh sách. Mục bị khoá phải
      nói được vì sao - một ô xám câm là lỗi giao diện tệ nhất trong ERP.
- [ ] Màn `/phan-quyen/:id` đọc `gan_duoc`, khoá đúng ô, và **vẫn giữ** đường xử lý 403 tại
      chỗ: cờ là để nói trước, không phải để thay lớp chặn thật ở backend (R-19).
- [ ] Test frontend: vai trò `gan_duoc: false` thì ô khoá và mang lý do; bấm vào không gửi
      request nào.

## Liên quan

- ADR-0023 (vai trò xuống database), ADR-0021 (vai trò theo module).
- `2026-08-21-nhan-vai-tro-kem-auth-me-spec.md` - cũng chạm `GET /roles`, nên hai spec này
  nên thi công cùng đợt.
- `2026-08-21-luat-gan-vai-tro-spec.md`, `2026-08-21-tim-kiem-nguoi-dung-spec.md`.
