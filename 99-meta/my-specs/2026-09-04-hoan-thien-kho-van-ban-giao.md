# Bàn giao: hoàn thiện module Kho vận

Ngày 2026-09-04. Nối tiếp `2026-09-03-don-no-ky-thuat-ban-giao.md` (rc.112).
Kế hoạch của đợt: `2026-09-04-hoan-thien-kho-van-plan.md`.

Người dùng giao: "làm hoàn thiện màn kho trước", phạm vi chốt là **cả module Kho vận**; hai màn
`machine` để sau. Phiên này dừng vì người dùng chuyển sang máy khác.

## Trạng thái - đã merge, đã tag `v0.1.0-rc.113`, đang chạy trên dev

| Repo | `main` | Tag rc.113 trỏ vào |
|---|---|---|
| frontend-erp | `6f4b8f7` | `6f4b8f7` |
| docs-erp | `e4ed02d` | (docs không tag) |
| backend-erp | `5dea167` | `5dea167` - không đổi dòng nào ở đợt này |
| infra-erp | `7eb2ed2` | `7eb2ed2` - không đổi dòng nào ở đợt này |

Hai nhánh `fe/hoan-thien-man-kho` và `spec/hoan-thien-kho-van` đã fast-forward vào `main` và
vẫn còn trên remote. Ba nhánh cùng tên ở backend/infra dựng ra để deploy nhánh, xoá lúc nào
cũng được.

**Máy dev đang chạy `v0.1.0-rc.113`**, bundle `assets/index-Cx8GaQfI.js`, đã đối chiếu bằng mục
`5b` của script deploy. Kiểm từ máy ngoài: `/health` và `/ready` 200, web 200, preflight trả
đúng `Allow-Origin`, ba cổng 5433/9090/3000 đều đóng.

**Chưa xác nhận được CI trên `main`** - `gh` không đăng nhập host nào. Tag dựa trên bằng chứng
cục bộ (2772 bài xanh, tsc/lint/arch/kiem-giao-dien sạch) cộng một lượt soi mắt đầu-cuối trên
dev. Xem [[github-account-erp-hanh]]. **Việc đầu tiên của phiên sau: đọc CI của `main` và của
tag rc.113, nếu đỏ thì đó là việc gấp nhất.**

**Số đo:** 2772 bài xanh / 166 file (đầu đợt là 2516). `tsc` 0, `lint` 0 lỗi, `arch` 0,
`kiem-giao-dien.mjs` sạch 369 file.

## Bốn đợt đã xong

**Đợt 1 (`0d350b2`) - thôi mất việc đang gõ, thôi vào ngõ cụt.** Cảnh báo rời trang; Enter đưa
tiêu điểm sang ô kế; số phiếu về muộn không đè số gõ tay; lỗi 422 tắt khi sửa ô và ghim theo khoá
hàng; nhánh 422 của danh sách kho và đối tác có nút bỏ lọc; form có nút Huỷ; trang chủ nói ra khi
`/inventory-summary` hỏng.

**Đợt 2 (`2405952`) - màn hình thôi nói sai.** Ô lọc hết nói "Tất cả kho" khi đang lọc (vá tại
gốc `OTraCuu`); cột mã bấm được; đường đi sau khi ghi phiếu; sổ trống mời lập phiếu; nút nấc thời
gian có trạng thái; dải đếm thôi đếm nhầm; hai màn của một tờ phiếu nói giống nhau.

**Đợt 3 (`2067d3b`) - hai màn xem còn thiếu, gộp mọi bản chép.** `/kho/:id` và `/doi-tac/:id` nay
là màn XEM, sửa lui về `/kho/:id/sua`. Gộp: xác nhận xoá 9 bản còn 1; mã lỗi 7 file về
`ma-loi-kho.ts`; `OThaoTac*` và sáu hộp lỗi về `OThaoTacHang` cùng `LoiDanhMuc`; bốn ô danh mục
về `ODanhMuc`; ba file CSS về `danh-muc.module.css`; khối đầu phiếu về `dau-phieu.module.css`.

**Đợt 4 (`6f4b8f7`) - vá những gì ba lượt review tìm ra.** Xem mục dưới.

**ADR-0052**: tờ phiếu xuất cũng hiện trị tuyệt đối. Quy tắc gọn: **tờ phiếu không mang dấu, sổ
mang dấu.** MISA không phát biểu về dấu trên chứng từ xuất kho - đã ghi vào ADR để khỏi tra lại.

## Ba lượt review, và cái chúng tìm ra

Ba lượt chạy độc lập trên chính công việc của đợt: review đợt 1-2, review đợt 3, và một lượt soi
chất lượng bộ test bằng **28 phép đột biến**.

**Hai lỗi Critical:**

1. **Enter trong hộp thoại "Thêm nhanh (F9)" chết câm** - do chính bản vá Enter của đợt 1:
   `preventDefault()` chạy trước khi hỏi ô có nằm trong vòng tiêu điểm của form không, mà hộp
   thoại vẽ qua portal. Đã tái hiện trên dev trước khi vá, và đã kiểm lại sau khi vá.
2. **Hai mã quyền in ra màn hình không có thật ở backend**: `inventory.balance_list` phải là
   `inventory.balance_read`, `inventory.voucher_list` phải là `inventory.movement_list`. Đã soát
   cả 25 mã của module và thêm một bài canh chính file màn với danh mục mã chép từ backend.

**Bảy lỗi Important** (chi tiết trong thông điệp commit `6f4b8f7`): câu cảnh báo của `OTraCuu`
dùng ngôn ngữ thanh lọc trong khi ô đó còn nằm trong dòng phiếu; báo động nhầm sau khi thêm
nhanh, và ở lại vĩnh viễn với danh mục quá 100 bản ghi; cảnh báo rời trang không đếm tệp đính
kèm; hai màn xem mới tự dựng lại khối xác nhận và bốn hộp lỗi vừa gộp xong; `bamVaoDieuKhien`
còn một bản cục bộ và bộ test của nó không phủ `input/select/textarea`; lưới canh `composes` chỉ
phủ 6 trên 10 lớp; ô ĐVT là một `select` thật nên Enter ở đó ghi cả tờ phiếu.

**Ba phép đột biến từng sống sót, nay đều chết**: hai nút thoát hiểm 409 của màn ghi phiếu, và
guard chống điều hướng khi bấm giữa hàng.

**Một phản hồi review bị bác**: `ma-loi-kho.ts` trích C-TS-04 là ĐÚNG - C-TS-04 là "Gọi API và
xử lý envelope", trong đó có câu "Client rẽ nhánh theo code, không theo message".

**Một việc cố ý KHÔNG làm**: chặn nút Back của trình duyệt. Cần đẩy một mục lịch sử giả, mà
`navigate.ts` tự khai là "CỬA DUY NHẤT ghi vào history" và đã kể một tai nạn khi có hai cơ chế
URL. Khối ghi chú đầu `canh-bao-roi-trang.ts` đã viết lại: ba đường rời trang, canh hai.

## Đã soi mắt trên dev - sáu mục jsdom không khẳng định được

| Mục | Kết quả |
|---|---|
| Enter trong hộp thoại F9 | Trước vá: hộp thoại đứng im. Sau vá: lưu xong, hộp thoại đóng, ô kho nhận `SOI-ENTER-02` |
| Cảnh báo rời trang | Hỏi đúng câu, trả lời không thì ở lại `/nhap-kho/moi` |
| Bố cục hai màn xem ở 1440px | Đứng đúng, cột phụ không đè bảng |
| Ô lọc kho lạ | Ô ghi "kho không đọc được tên" kèm câu cam và mã, thay vì nói dối "Tất cả kho" |
| Tờ phiếu xuất | `150` và `2.205.882,3529` đều dương, có ô Tổng tiền hàng - ADR-0052 đúng |
| Dải đầu phiếu hai màn | Cùng một hình sau khi gộp CSS |

## Việc tiếp theo

1. **Đọc CI** của `main` và của tag `v0.1.0-rc.113` ở cả ba repo - đây là mắt xích duy nhất của
   đợt này chưa ai nhìn thấy.
2. **Hai màn `machine`** (`MachineListPage`, `BreakdownReportPage`) - đợt thiết kế, người dùng
   đã chốt để sau.
3. Kho thử `SOI-ENTER-02` do lượt soi tạo ra **đã xoá** (`DELETE 204`, danh sách trả về rỗng).

## Còn nợ

- **Khoảng 14 bản chép** còn sống trong `src/modules/inventory/`, phần lớn là ô mã và tên danh
  mục xoá mềm rải sáu màn. Không cái nào là lỗi người dùng thấy được.
- **Câu 403 bản thứ tư** ở `src/modules/company/CompanyForm.tsx:182` - ngoài module Kho vận.
- **Tiền hiện 4 chữ số thập phân** (`2.205.882,3529`) - đúng luật R-19 in nguyên văn chuỗi
  NUMERIC(18,4), nhưng MISA cắt còn 2. Đáng một đợt riêng, và phải là ADR vì nó chạm mọi màn tiền.
- **Không có nút In phiếu** ở đâu trong `src/`.
- **Ô chọn đơn vị tính** vẫn trần 100 mục, không có ô tìm.
- **Dữ liệu seed thiếu dấu** - nợ thừa kế, chưa động tới.

## Bài học của đợt

1. **Bàn giao mới nhất không nằm ở nhánh đang checkout.** Phiên này mở đầu bằng việc đọc nhầm một
   bàn giao cũ hơn một ngày và suýt làm lại một việc đã xong. Đọc bàn giao thì
   `git log origin/main` trước, đừng `ls` thư mục. Đã ghi thành memory.
2. **Máy dev có thể đang chạy một nhánh chứ không phải tag.** Màn đăng nhập lúc đầu phiên ghi
   `ma-tran-quyen`, không phải `rc.112`.
3. **Bản vá của đợt này đẻ ra lỗi Critical của đợt này.** Vá Enter ở đợt 1 làm chết Enter trong
   hộp thoại F9 - một đường người dùng đang dùng được. Không bài test nào của đợt 1 bắt được, và
   nó chỉ lộ ra ở lượt review. Ba lượt review tìm thêm 2 Critical và 7 Important sau khi 2737 bài
   đã xanh.
4. **28 phép đột biến: 25 chết, 3 sống.** Ba chỗ sống sót đều là nhánh lỗi hiếm (409 mã trùng,
   khoá đã dùng) và một guard chống điều hướng - đúng loại code không ai nghĩ tới khi viết test.
5. **`composes` của CSS module rơi im lặng.** Đổi tên một lớp trong file dùng chung không làm đỏ
   bài nào và cũng không lỗi biên dịch. Chữa bằng một bài đo vân tay băm của lớp chung.
6. **Chia agent theo FILE thì chín agent chạy song song trong MỘT cây làm việc không đụng nhau.**
   Giá phải trả: mỗi lượt phải tự tay nối phần giáp ranh, và `arch:update` để đến cuối.
