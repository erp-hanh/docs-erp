# Bàn giao: hoàn thiện module Kho vận (đang dở ở bước soi mắt)

Ngày 2026-09-04. Nối tiếp `2026-09-03-don-no-ky-thuat-ban-giao.md` (rc.112).
Kế hoạch của đợt: `2026-09-04-hoan-thien-kho-van-plan.md`.

Người dùng giao: "làm hoàn thiện màn kho trước", phạm vi chốt là **cả module Kho vận**; hai màn
`machine` để sau. Phiên này dừng vì người dùng chuyển sang máy khác.

## Trạng thái - CHƯA merge vào main, CHƯA tag

| Repo | Nhánh | Commit |
|---|---|---|
| frontend-erp | `fe/hoan-thien-man-kho` | `2067d3b` (3 commit trên `origin/main` 29177f6) |
| docs-erp | `spec/hoan-thien-kho-van` | `0295866` (ADR-0052 + kế hoạch) |
| backend-erp | `fe/hoan-thien-man-kho` | `5dea167` = `origin/main`, không đổi dòng nào |
| infra-erp | `fe/hoan-thien-man-kho` | `7eb2ed2` = `origin/main`, không đổi dòng nào |

Cả bốn nhánh **đã push**. Hai nhánh backend/infra dựng ra chỉ để `deploy-dev.sh` có đủ ba ref
cùng tên - xem [[deploy-nhanh-khong-tag-de-soi-giao-dien]].

**Máy dev đang chạy nhánh này, không phải một tag.** Bundle đang phục vụ:
`assets/index-BWGUuBQ_.js`, đã đối chiếu bằng mục `5b` của script deploy (`4f99d42 → 2067d3b`).
Trước đó dev chạy bản dựng nhánh `ma-tran-quyen`; muốn trả lại thì
`ssh dev-erp "bash /opt/erp/infra-erp/scripts/deploy-dev.sh fe/ma-tran-quyen"`.

**Số đo:** 2737 bài xanh / 166 file (đầu đợt là 2516). `tsc` 0, `lint` 0 lỗi, `arch` 0,
`kiem-giao-dien.mjs` sạch 369 file. Chưa xác nhận được CI: `gh` không đăng nhập host nào
([[github-account-erp-hanh]]).

## Đã xong - năm đợt

**Đợt 1 (`0d350b2`) - người dùng thôi mất việc đang gõ, thôi vào ngõ cụt.** Cảnh báo rời trang
khi tờ phiếu đang dở (hook dùng chung `canh-bao-roi-trang`); Enter đưa tiêu điểm sang ô kế thay
vì ghi cả phiếu; số phiếu về muộn không đè số gõ tay; lỗi 422 cũ tắt khi sửa ô; lỗi 422 ghim
theo khoá hàng nên không tô sang hàng khác; nhánh 422 của danh sách kho/đối tác có nút bỏ lọc;
form kho/đối tác có nút Huỷ; trang chủ Kho vận nói ra khi `/inventory-summary` hỏng và có nút
thử lại; năm dòng chuyển động gần nhất bấm được.

**Đợt 2 (`2405952`) - màn hình thôi nói sai, hai màn của một tờ phiếu nói giống nhau.** Ô lọc
hết nói "Tất cả kho" trong khi bảng đang lọc (vá tại gốc `OTraCuu`); cột mã kho/mã VTHH bấm
sang chi tiết; ghi phiếu xong có đường mở tờ vừa ghi; sổ trống mời lập phiếu; ba nút nấc thời
gian có trạng thái đang chọn; dải đếm thôi đếm nhầm ("gõ 2 dòng, mở lại thấy Tổng số: 4"); cột
số lượng cùng tên ở hai màn; tờ phiếu chuyển thôi tự mâu thuẫn về đối tác.

**Đợt 3 (`2067d3b`) - hai màn xem còn thiếu, và gộp mọi bản chép còn lại.** `/kho/:id` và
`/doi-tac/:id` nay là màn XEM (sửa lui về `/kho/:id/sua`), địa chỉ cũ vẫn mở đúng bản ghi. Màn
xem kho có hai mặt `?mat=` (Tồn theo mặt hàng, Chuyển động) và thẻ "Cần chú ý" cho dòng tồn âm;
màn xem đối tác có khối phiếu gần đây. Backend đã có sẵn `GET /warehouses/:id` và
`GET /partners/:id`. Gộp: khối xác nhận xoá 9 bản → 1 (`XacNhanTaiCho`); mã lỗi backend 7 file →
`ma-loi-kho.ts`; `OThaoTac*` và sáu hộp lỗi → `OThaoTacHang` + `LoiDanhMuc`; `OKho`/`OVatTu`/
`OCapDanhMuc` 4 bản → `ODanhMuc`; ba file CSS danh mục → `danh-muc.module.css`; khối đầu phiếu
chép ở hai file CSS → `dau-phieu.module.css`.

**ADR-0052** (`0295866`): tờ phiếu xuất cũng hiện trị tuyệt đối. Lật đúng một khoản của
ADR-0051 - khoản loại phiếu xuất ra khỏi phạm vi - vì nó để lại ba cách đọc cho một cột. Quy tắc
gọn: **tờ phiếu không mang dấu, sổ mang dấu.** Tra MISA cả hai bản: không bản nào phát biểu về
dấu trên chứng từ xuất kho, đã ghi vào ADR để phiên sau khỏi tra lại.

## Việc tiếp theo, đúng chỗ đang dừng

**1. Soi mắt trên dev - đây là việc đang dở.** Trình duyệt vừa mở thì phiên dừng. Sáu mục jsdom
KHÔNG khẳng định được, đã ghi sẵn trong chú thích đầu các bài test:

- Enter trong ô số lượng có thật sự không ghi phiếu không (jsdom không cài implicit form
  submission, bài test xanh sẵn cả trên code chưa vá - mệnh đề thật ghim bằng `preventDefault` +
  tiêu điểm dịch chuyển).
- Hộp thoại cảnh báo rời trang có hiện ra không, và câu chữ trình duyệt tự thay là gì.
- Bố cục hai màn xem mới ở 1440px, nhất là cột phụ `sticky` cạnh một bảng dài.
- Ô lọc kho khi mở địa chỉ mang `warehouse_id` của một kho ngoài trang đầu danh mục.
- Tờ phiếu xuất hiện số dương (ADR-0052) - mở một phiếu xuất đã ghi.
- Dải đầu phiếu của màn lập và màn chi tiết có ra cùng một hình sau khi gộp CSS không.

Cách vào: `agent-browser --args "--disable-features=HttpsFirstBalancedMode" --session <tên> open
http://103.179.172.110/` rồi `set viewport 1440 900`. Tài khoản `qa-admin@erp.test` /
`QaPhamVi!2026`, phân vùng DEFAULT. Daemon khởi động mất vài phút - gộp nhiều bước vào MỘT lệnh.
Xem [[agent-browser-chan-http-thuan]] và [[agent-browser-cu-phap-screenshot]].

**2. Sau khi soi xong**: merge bốn nhánh về `main`, chờ CI, rồi tag rc.113 trên cả ba repo.

**3. Ba mã quyền do agent SUY RA từ quy ước `<tài nguyên>_<việc>`, chưa đối chiếu backend:**
`inventory.warehouse_delete`, `inventory.partner_delete`, `inventory.voucher_list`. Sai thì câu
403 in ra một mã không có thật.

## Còn nợ

- **16 bản chép còn sống** trong `src/modules/inventory/`: 2 khối xác nhận xoá viết tay và 4 hộp
  lỗi ở hai màn xem MỚI (chúng dựng song song nên chưa kịp dùng bản chung), 1 hộp lỗi của màn tồn
  kho, 9 ô mã/tên danh mục xoá mềm rải sáu màn. Không cái nào là lỗi người dùng thấy được.
- **Câu 403 bản thứ tư** ở `src/modules/company/CompanyForm.tsx:182` - ngoài module Kho vận nên
  cố ý không đụng.
- **Hai màn `machine`** (`MachineListPage`, `BreakdownReportPage`) chưa qua bộ component chung -
  người dùng nói rõ để sau, và đó phải là một đợt **thiết kế**, không phải đợt đổi API.
- **Không có nút In phiếu** ở đâu trong `src/` (`window.print` không xuất hiện). Chưa ai yêu cầu.
- **Ô chọn đơn vị tính** vẫn trần 100 mục, không có ô tìm; chữ hiện cho người dùng còn chỉ ra một
  lệnh backend (`cmd/dev seed-units`).
- **Dữ liệu seed thiếu dấu** - nợ thừa kế từ đợt trước, chưa động tới.

## Bài học của đợt

1. **Bàn giao mới nhất không nằm ở nhánh đang checkout.** Phiên này mở đầu bằng việc đọc nhầm
   một bàn giao cũ hơn một ngày và suýt đi làm lại một việc đã xong (gom lời gọi
   `/stock-balances`). File mới hơn nằm trên `origin/main` của docs-erp. **Đọc bàn giao thì
   `git log origin/main` trước, đừng `ls` thư mục.**
2. **Máy dev có thể đang chạy một nhánh chứ không phải tag.** Màn đăng nhập lúc đó ghi
   `ma-tran-quyen`, không phải `rc.112` - nên mọi kết luận "soi trên dev" trước khi deploy lại
   đều nói về code khác. Đọc số trên màn đăng nhập trước khi tin,
   xem [[so-rc-tren-man-dang-nhap-co-the-cu]].
3. **`composes` của CSS module rơi im lặng.** Đổi tên một lớp trong file dùng chung không làm đỏ
   bài nào và cũng không lỗi biên dịch - một phép đột biến sống sót đã lộ ra chuyện đó. Chữa bằng
   `danh-muc.module.test.ts` đo vân tay băm của lớp chung trên từng màn.
4. **Chia agent theo FILE thì ba con chạy song song trong MỘT cây làm việc vẫn không đụng nhau.**
   Sáu agent, ba lượt, không lần nào phải gỡ xung đột. Giá phải trả: mỗi lượt phải tự tay nối
   phần giáp ranh (CSS `composes` phía màn lập, bảng `NHAN_PHIEU` phía màn chi tiết), và
   `npm run arch:update` phải để đến cuối vì golden đếm số file.
5. **Soi code song song ba vùng bắt được ~60 chỗ dở mà 2516 bài test không thấy** - phần lớn là
   "màn này có, màn anh em thì không", thứ chỉ lộ ra khi đặt ba màn cùng khuôn cạnh nhau.
