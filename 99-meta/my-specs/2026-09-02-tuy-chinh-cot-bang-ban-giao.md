# Bàn giao: tùy chỉnh cột bảng + đợt sửa giao diện Kho vận

Ngày 2026-09-02. Nhánh `fix/bang-cot` (frontend-erp), gốc `feat/ngung-su-dung-phan-vung`.
Kế hoạch gốc: `2026-09-01-tuy-chinh-cot-bang-plan.md`.

## Trạng thái

- 13 commit, **đã push** lên `origin/fix/bang-cot` của cả ba repo (backend-erp và infra-erp
  chỉ là nhánh trỏ vào `v0.1.0-rc.107` để `deploy-dev.sh` có ref cùng tên).
- Máy dev đang chạy **chính nhánh này**, không phải một tag rc.
- Cả bộ: 2171 test xanh, `tsc` / `lint` / `arch` sạch.
- **Chưa merge vào `main`, chưa tag rc.** Đó là việc đầu tiên của phiên sau, sau khi người
  dùng soi xong.

## Đã làm

1. **Lỗi kẻ bảng lệch** (`c012f95`): bề rộng cột khai bằng `nth-child` trong khi số cột thay
   đổi. Đo trên dev: cột Thao tác của /nhap-kho nhận 194px thay vì ~78px; ở chi tiết phiếu
   chuyển thì ngược lại, bị nghiền về ~0px.
2. **Bảng nhận định nghĩa cột** (`668c4a0`, `a29bcd2`, `e738650`): `<BangCot>` +
   `HopTuyChinhCot` + lưu ở localStorage theo `userId` + `maBang`. Bảy bảng Kho vận đã
   chuyển. Cột "Mã kho" đặt `anMacDinh` ở ba bảng có nó, theo yêu cầu người dùng.
3. **Sáu lỗi do soi lại** (`bd5bcaf`, `29c092a`, `2f66605`): nút không đóng được hộp, bảng
   hai hình dạng làm mất lựa chọn đã lưu, ô nhập bề rộng bỏ qua mức sàn, mỗi `pointermove`
   ghi một lần localStorage, đóng hộp mất tiêu điểm, nhãn xoá mềm nằm ở cột tắt được.
4. **Ô tra cứu đóng khi rời ô** (`a2520a9`): trước đó chỉ Escape đóng được, mà chỉ khi tiêu
   điểm còn trong ô.
5. **Nút quay lại** (`b9ea4d1`, `7790960`): lui về đúng địa chỉ vừa rời (kèm bộ lọc, số
   trang) qua `duongLui()` đọc history state; nút nằm TRONG thẻ tiêu đề, chỉ vẽ mũi tên.
6. **Biểu tượng** (`b9ea4d1`): các ký tự `←`, `×`, `⠿`, `↑`, `↓` thành SVG ở
   `src/shared/components/bieu-tuong.tsx`.
7. **Ô ngày có lịch** (`5a3d6da`): nút lịch mở `showPicker()` của một `<input type="date">`
   ẩn. Ô gõ vẫn là `dd/mm/yyyy`.
8. **Màn chi tiết phiếu gọn lại** (`76d1c89`): bỏ uuid cạnh tiêu đề, bỏ cột Thao tác của
   bảng dòng.

## Đang chờ người dùng trả lời

- **Lịch nói tiếng của TRÌNH DUYỆT.** Máy cài tiếng Anh thấy lịch tiếng Anh, tuần bắt đầu
  Chủ nhật (đã chụp được trên dev). Muốn cố định tiếng Việt + tuần bắt đầu Thứ hai thì phải
  tự vẽ một bảng lịch - việc đó chưa ai chốt.
- **Nút quay lại đang có viền vuông.** Nếu người dùng thấy nặng thì bỏ viền, đổi một luật
  trong `TieuDeTrang.module.css`.
- Bảng Tồn kho có 4/8 cột `coDinh` (Tên kho, Mã VTHH, Tên VTHH, Thao tác) nên chỉ tắt được
  4 cột. Chặt như vậy vì cột Tên là chỗ duy nhất nói ra "đã bị xoá".

## Việc chưa làm

- Tám bảng ngoài Kho vận (quản trị, người dùng, vai trò, phân vùng, thiết bị) vẫn dùng API
  cũ của `<Bang>`. Chuyển chúng giờ chỉ là khai một mảng cột mỗi màn.
- `MovementDetailPage` và `StockItemListPage` cũng dựng nhãn xoá mềm theo khuôn cũ - đáng
  soi xem có cùng lỗ hổng "nhãn nằm ở cột tắt được" không.

## Bẫy đã gặp, đừng gặp lại

- Sau `deploy-dev.sh`, **tab agent-browser đang mở vẫn chạy bundle JS cũ**. Đóng phiên rồi mở
  lại trước khi đo. Đã mất 6 lượt đo vì chuyện này.
- `npm run arch` đỏ sau khi thêm file mới là bình thường: chạy `npm run arch:update` rồi
  commit `arch/LEVELS.md`.
- Dự án KHÔNG dùng prettier. Đừng chạy `npx prettier --write` - nó đổi sang nháy đôi và làm
  bẩn diff.
