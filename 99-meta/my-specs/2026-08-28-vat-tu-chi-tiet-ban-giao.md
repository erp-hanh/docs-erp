# Bàn giao - 2026-08-28, trang chi tiết vật tư

Thiết kế: `2026-08-28-vat-tu-chi-tiet-design.md`. Kế hoạch: `2026-08-28-vat-tu-chi-tiet-plan.md`.
Sáu task xong, nhánh `feat/vat-tu-chi-tiet` có ở **cả bốn** repo (`infra-erp` và `backend-erp`
chỉ trỏ vào `main` để deploy nhánh chạy được).

## Có gì mới

```
/vat-tu            danh sách   -> bấm CẢ HÀNG
/vat-tu/moi        thêm vật tư
/vat-tu/:id        CHI TIẾT    (mới)
/vat-tu/:id/sua    sửa         (form cũ dời sang đây)
```

Trang chi tiết ghép ba khối, mỗi khối một `useQuery` riêng: thông tin chung
(`GET /stock-items/:id`), tồn theo kho (`GET /stock-balances?stock_item_id=`), mười chuyển
động gần nhất (`GET /stock-movements?stock_item_id=&page_size=10`). Ba permission RIÊNG bên
Go, nên **một khối 403 chỉ làm câm khối đó** - chỉ khối thông tin chung hỏng mới làm cả trang
thành một bảng thông báo.

Bấm cả hàng: `<tr onClick>` gọi `navigate`, ô Mã giữ nguyên `<a href>` thật (đường của bàn
phím và của chuột giữa). Ba ca KHÔNG điều hướng: bấm trúng một điều khiển, đang hỏi xoá, và
vừa bôi đen chữ.

Màn thêm/sửa: thứ tự ô đổi thành Mã → Tên → Đơn vị tính, form nằm trong một thẻ rộng
`--rong-form`, chân trang có đường kẻ với Huỷ + "Lưu vật tư". Nhánh SỬA lui về **trang chi
tiết**, không nhảy hai bậc về danh sách.

## Cố ý không có ô "Tổng tồn"

Backend không trả tổng tồn của một vật tư ở endpoint nào. Cộng các dòng `stock_balances` dưới
máy thì vừa sai kiểu - `quantity` là `NUMERIC(18,4)` về dạng chuỗi, cộng bằng `number` là cộng
bằng float64 - vừa đúng thứ R-19 cấm. Cần một tổng thật thì việc phải làm là **mở một endpoint
bên backend**, không phải cộng ở đây.

## Bằng chứng

`npm test`: 103 file, **1209 test xanh**. `npm run lint`, `npx tsc --noEmit`, `npm run arch`,
`kiem-giao-dien.mjs` - đều sạch. Chạy dưới máy, không lấy theo lời báo cáo của subagent.

Đã deploy nhánh (KHÔNG tag rc) lên dev và đi thật bằng `qa-admin@erp.test`, phân vùng
`DEFAULT`: bấm hàng → `/vat-tu/<id>`, ba khối hiện đủ với dữ liệu thật (tồn 92 ở `QA-KHO-A`,
hai chuyển động `-8` và `100` giữ nguyên dấu), nút Sửa trỏ đúng `/vat-tu/<id>/sua`.

## Hai lỗi chỉ mắt người bắt được

1209 test xanh, lint sạch, script soi giao diện sạch - mà ảnh chụp trên dev vẫn ra hai lỗi:

1. **Ba ô nhập trôi thẳng trên nền trang**, không thẻ nào bọc, ngay dưới một dải đầu trang có
   viền. Kế hoạch có ghi "form vào trong thẻ"; người thi công làm hết phần khoảng cách bên
   trong mà bỏ mất cái vỏ, và không lớp kiểm nào thấy.
2. **Tên màn in hai lần** cách nhau năm mươi pixel - một lần ở `<h1>` của `<TieuDeTrang>`, một
   lần ở `<h2>` trong chính form. Lỗi này có SẴN từ trước đợt, nhưng phải tới lúc dải đầu trang
   thành một cái thẻ thật thì nó mới đọc ra là lỗi.

Cả hai đã sửa (commit `3d238bb`) và đã chụp lại để xác nhận. Bài học không mới nhưng vừa được
xác nhận thêm một lần: **bộ kiểm tự động không thấy được bố cục.**

## Việc còn để lại

- `thoiDiemHienThi` in ra `20/08/2026 09:00:00` - có giây, trong khi khuôn màn hình quy định
  `dd/MM/yyyy HH:mm`. Đây là hàm dùng chung của ba màn chuyển động khác, có từ trước đợt này.
  Sửa nó là một đợt riêng chạm cả bốn màn.
- Cùng hình dạng "chỉ ô Mã bấm được" còn nguyên ở `WarehouseListPage`, `MovementListPage`,
  `BalanceListPage`. Bốn màn cùng khuôn mà một màn bấm được cả hàng, ba màn thì không, là chỗ
  người dùng học sai thói quen. Nhân rộng thì lúc đó `bamVaoDieuKhien`/`dangBoiDen` mới đáng
  tách sang `shared/` - bản thứ ba mới tách.
- Khuôn ba hàm bảng lỗi (`403 → canh-bao / còn lại → loi + Thử lại`) đã có ~19 bản khắp
  `src/modules/**/pages/`. Gộp là một đợt riêng, không phải việc của diff này.
- Chưa merge vào `main`. Nhánh đã đẩy lên cả bốn repo, chưa mở PR.

## Việc tiếp theo

Merge `feat/vat-tu-chi-tiet` vào `main` ở `frontend-erp` và `docs-erp`, đợi CI xanh trên
`main`, rồi tag một bản rc cho cả ba repo triển khai. Nhánh đang chạy trên dev là bản đã soi
bằng mắt, nên không còn gì chặn - chỉ thiếu đúng cú merge và một số rc.
