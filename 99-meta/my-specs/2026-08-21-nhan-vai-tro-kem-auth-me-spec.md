# Trả nhãn vai trò kèm `GET /auth/me`

Trạng thái: **chưa làm**, cần một ADR mở đường vì nó đổi hợp đồng API.

Nợ này đã được ghi sẵn ở `backend-erp/cmd/internal/vaitro/vaitro.go:405-410` và trong
`2026-08-21-ban-giao.md` mục "Việc tiếp theo". Spec này chốt lại vì sao đường tưởng là dễ
lại không đi được.

## Vấn đề

Hai bảng nhãn vai trò song song, giữ khớp bằng tay, **đã lệch thật một lần ở `rc.18`**:

- backend: `cmd/internal/vaitro/vaitro.go`, hàm `DanhMuc()`
- frontend: hằng `NHAN_VAI_TRO` trong `src/app/DropdownTaiKhoan.tsx:185` (chỗ đọc duy
  nhất trong cả `src/`)

Một bản chép ở frontend lệch im lặng ngay lần đầu backend thêm một vai trò, và nó lệch
theo hướng tệ nhất: một vai trò có thật hiện ra dưới dạng mã thô.

## Đường tưởng là đúng, và vì sao nó sai

Đợt 2026-08-21 chốt "dùng `GET /roles` làm nguồn nhãn duy nhất, xoá `NHAN_VAI_TRO`".
**Quyết định đó sai**, phát hiện lúc thi công:

`GET /roles` **bị chặn quyền**. Route đi qua `xacThuc` (`user_routes.go:56`) rồi service
kiểm `auth.user_assign_roles` (`user_service.go:568`). Bốn trên tám vai trò không có
quyền đó: `inventory.thu_kho`, `inventory.viewer`, `machine.viewer`, `machine.ky_thuat` -
đúng những tài khoản nhà xưởng dùng hệ này hàng ngày.

Hợp đồng đó không phải tình cờ, nó bị khoá bằng e2e:
`cmd/api/e2e_test.go:2364` `TestE2EDanhMucVaiTroThieuQuyenTra403` khẳng định
`inventory.viewer` phải nhận **403**, kèm lý do "câu trả lời đúng là một lần từ chối chứ
không phải một danh sách rỗng".

Nên nếu popover tài khoản đọc nhãn từ `GET /roles`, nhánh "lỗi thì lùi về mã thô" trở
thành nhánh **bình thường** với đa số người dùng.

Ca thứ hai, độc lập: `quan_tri_he_thong` **cố ý vắng mặt** trong `DanhMuc()`
(`vaitro.go:393`) vì nó là vai trò dẫn xuất từ cờ `users.is_system_admin`, không ai gán
được. Quản trị hệ thống có quyền nên nhận 200 sạch, rồi chính vai trò của họ rơi vào
nhánh "mã lạc" và bị mô tả bằng câu "Vai trò không còn trong danh mục" - một câu sai.

`GET /auth/me` hôm nay không lấp được: `CurrentUser`
(`frontend-erp/src/modules/auth/api/auth-api.ts:55`) mang `roles: string[]`, không mang
nhãn.

## Đề xuất

**Trả nhãn kèm `GET /auth/me`.** Đây là đường duy nhất trả lời được cả hai ca:

- Popover đọc nhãn từ phiên nó đã có sẵn: **không thêm một lần gọi mạng**, không có trạng
  thái đang tải, không có nhánh 403. Một popover nháy từ mã thô sang nhãn là thứ người
  dùng thấy mỗi lần mở menu.
- `quan_tri_he_thong` được phủ, vì nơi ký token biết vai trò dẫn xuất đó - còn `DanhMuc()`
  thì cố ý không biết.

Hình dạng gợi ý, giữ `roles` cũ để không phá người đọc hiện có:

```
{
  "roles": ["inventory.thu_kho"],
  "vai_tro": [{ "ma": "inventory.thu_kho", "nhan": "Thủ kho" }]
}
```

Việc chọn có bỏ `roles` đi hay không thuộc về ADR.

## Đường rẻ hơn, và cái giá của nó

Hạ cửa quyền của `GET /roles` xuống chỉ còn `xacThuc`. Danh mục không lộ gì - đã có e2e
khẳng định response không mang tên permission (`e2e_test.go:2355`).

Giá phải trả: xoá `TestE2EDanhMucVaiTroThieuQuyenTra403`, tức là **cố ý gỡ một hợp đồng
đã khoá** - việc đó cũng cần ADR. Và nó vẫn để `quan_tri_he_thong` phải có một ca đặc
biệt viết tay trong popover, tức chưa xoá hết bản chép.

## Việc phải làm

- [ ] ADR: `GET /auth/me` trả nhãn vai trò. Nêu cả hai đường và lý do loại đường rẻ.
- [ ] Backend: `CurrentUser` mang thêm nhãn, lấy từ `vaitro.DanhMuc()` cộng vai trò dẫn
      xuất. Test cho ca `quan_tri_he_thong`.
- [ ] Frontend: `DropdownTaiKhoan` đọc nhãn từ `useCurrentUser`, **xoá `NHAN_VAI_TRO`**.
- [ ] Test: vai trò lạ không có nhãn thì hiện mã thô, không hiện chỗ trống.

## Không đụng tới

Màn quản trị `/nguoi-dung/:id` **vẫn dùng `GET /roles`** và đó là đúng chỗ: người mở màn
đó theo định nghĩa phải có `auth.user_assign_roles`, nếu không họ đã ăn 403 ngay từ
`GET /users`. Spec này chỉ nói về popover tài khoản, thứ mọi người dùng đều mở được.

## Liên quan

- `2026-08-21-ban-giao.md` mục "Việc tiếp theo" số 1.
- ADR-0021 mục "Nợ để lại".
- `2026-08-21-luat-gan-vai-tro-spec.md`, `2026-08-21-tim-kiem-nguoi-dung-spec.md` - hai
  việc còn mở khác của cùng cụm màn.
