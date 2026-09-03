# Bàn giao: dọn nợ kỹ thuật của hai đợt trước

Ngày 2026-09-03. Nối tiếp `2026-09-02-dinh-kem-va-man-chi-tiet-ban-giao.md` và
`2026-09-02-lap-phieu-theo-mau-misa-ban-giao.md`. Đợt này lấy nguyên mục "Còn nợ" của cả hai
bàn giao đó làm danh sách việc, thi công bằng chín subagent chạy song song trên worktree riêng.

## Trạng thái

- **`v0.1.0-rc.112`** đang chạy trên dev. Tag khớp `main` cả ba repo.
- `main`: frontend `29177f6`, backend `5dea167`, infra `7eb2ed2` (infra không đổi dòng nào).
- **2516 bài xanh** (frontend, 154 file). Backend `go run ./cmd/dev test` **xanh trọn bộ trên
  VPS dev** cho cây gộp - 61 gói, gồm mọi gói cần database.
- `tsc`, `lint`, `arch` sạch cả hai repo.
- **Chưa xác nhận được CI**: `gh` không đăng nhập host nào. Bằng chứng thay thế là ba lượt soi
  mắt trên dev cộng bộ test có database chạy thật trên VPS. Xem [[github-account-erp-hanh]].
- ADR mới: **ADR-0051** (tờ phiếu chuyển hiện trị tuyệt đối).

## Mười ba việc, xong cả mười ba

| # | Việc | Kết quả đo được |
|---|---|---|
| 1 | Hiệu năng `/stock-balances` | tờ phiếu 20 dòng: phiếu nhập **21 → 0** lời gọi, phiếu xuất **41 → 20** |
| 2 | Công tắc "Chỉ hiện hàng/kho còn tồn" | bật sẵn ở XUẤT và CHUYỂN, tắt ở NHẬP; lọc thật (9 mục → 5) |
| 3 | "Thêm nhanh (F9)" trong bảng xổ | hộp thoại tạo kho / vật tư ngay trên tờ phiếu |
| 4 | Bỏ tệp ở màn lập gọi `DELETE` | đo được `204` trên dev |
| 5 | Dọn `NHAN_PHIEU.ghiChuTon` / `.ghiChuDonGia` | xoá cả trường lẫn giá trị khoá trong test |
| 6 | Dấu trên tờ phiếu chuyển | Số lượng và Thành tiền hiện trị tuyệt đối; hai ô tổng cộng MỘT chiều |
| 7 | Sáu bảng ngoài Kho vận sang `BangCot` | **sáu**, không phải tám - xem dưới |
| 8 | `title` cho ô cắt ba chấm | 22 cột, bảy màn; `<th>` cũng treo `title` |
| 9 | Ô tra cứu không lọc theo chữ gõ | nhịp gõ 200ms; **lỗi có sẵn trên `main`**, không phải hồi quy |
| 10 | Bẫy tiêu điểm hộp thoại F9 | vòng Tab khép kín, `inert` nền, khoá cuộn, trả tiêu điểm bốn lối ra |
| 11 | Backend: dọn tệp mồ côi | `cmd/dev don-tep-mo-coi [-gio 24] [-thu] [-company MA]` |
| 12 | Backend: 167 thông điệp lỗi có dấu | 232 vị trí chuỗi, cả bốn module |
| 13 | Bốn ca đính kèm chưa thử tay | thử thật trên dev, **cả bốn chạy** |

## Ba con số trong bàn giao cũ hoá ra sai, đã đính chính

1. **"Tám bảng ngoài Kho vận"** thực ra là **sáu**. Hai màn `machine` chưa bao giờ dùng
   `<Bang>` - chúng dựng `<table>` trần, trạng thái tải là `<p>Đang tải...</p>`. Chuyển chúng
   là một đợt **thiết kế lại**, không phải đợt đổi API, nên bị cắt khỏi phạm vi.
2. **"15 cột ô câm"** thực ra là **22**. Đếm dư bốn cột vẽ chuỗi thuần (chúng đã tự có `title`),
   thiếu năm cột ở `VoucherListPage` và `StockItemListPage`.
3. **Băng báo ghi phiếu "thiếu `role="status"`"** - sai. `BangThongBao` tự đặt role theo `sac`
   từ trước. Phép đo bắt đầu từ **lớp bọc** rồi đi lên tổ tiên, trong khi role nằm ở phần tử
   **con**. Lỗi thật thì tinh vi hơn: vùng `role="status"` chỉ gắn vào DOM đúng lúc có tin, mà
   một vùng vừa gắn vào DOM đã có sẵn chữ thì không được đọc lên. Khuôn chữa nằm sẵn trong
   `DanhSachChon.tsx`; `PhieuFormPage` là trang form duy nhất còn thiếu.

## Bốn thứ chỉ trình duyệt thật mới nói được

jsdom khẳng định được thuộc tính, không khẳng định được hành vi. Bốn mục này đều **đạt**, đo
bằng số:

| Mục | Số đo |
|---|---|
| Trang nền đứng yên khi lớp phủ mở | lăn chuột thật: đối chứng `0 → 279`, khi mở `0 → 0` (ba lớp phủ) |
| Escape sau khi Lưu hỏng | `422` thật từ máy chủ, tiêu điểm ở ô lỗi, Esc **một lần** đóng được |
| Nhịp gõ 200ms | gõ nhanh: đúng **một** request ở 469ms; gõ nhịp người: 5 request, không giật |
| Khe đáy chân dính bảng xổ | **1px** (trước vá 5px), 0 dòng lòi ra dưới chân dính |

Cộng một vòng nghiệp vụ đầu-cuối: lập `PN-2026-0015` (2 dòng) và `PN-2026-0016` (1 dòng) hoàn
toàn bằng ô tra cứu, `201`, mở lại màn chi tiết khớp từng số.

## Còn nợ

- **Hai màn `machine`** (`MachineListPage`, `BreakdownReportPage`) chưa qua bộ component chung.
  Phải là đợt **thiết kế**, không phải đợt chuyển API.
- **Bốn bản `OCapDanhMuc` / `OKho` / `OVatTu` trùng nhau** ở ba màn, chỉ khác cái `data-*`. Gộp
  được ~60 dòng. Thêm file mới nên golden `LEVELS.md` sẽ lệch - làm lúc không có agent nào khác
  đụng repo.
- **`inert` nền cho ngăn kéo ứng dụng.** Nó đã có bẫy Tab và tấm nền bấm-để-đóng, nên đường bàn
  phím và chuột đã bịt; khe còn lại chỉ là **cây trợ năng** - người dùng trình đọc màn hình vẫn
  duyệt được nội dung sau lưng bằng con trỏ ảo. Nhẹ hơn hộp thoại nhập liệu nhiều.
- **Băng báo ghi phiếu không có liên kết mở tờ phiếu vừa ghi** - phải quay ra danh sách tìm lại.
- **Byte trên đĩa của tệp người dùng đã xoá mềm**: cố ý không dọn. Cần một ADR chốt thời hạn lưu
  trữ trước, và chính ADR đó mới mở được đường hard delete mà R-18 đang chặn.
- **Dữ liệu seed thiếu dấu**: `Cong sat 2 canh`, `Khung cua so`, và cả danh mục đơn vị tính
  (`Bao`, `Cai`, `Cuon`, `Met`, `Thung`). Là dữ liệu chứ không phải mã nguồn, nhưng người dùng
  nhìn thấy hằng ngày.
- **Bốn tệp mồ côi và hai phiếu thử trên dev** do lượt soi tạo ra: `PN-2026-0015`,
  `PN-2026-0016`, vật tư `KV9-TEST-01`, và khoảng 13 tệp đính kèm chưa gắn phiếu. Lệnh
  `don-tep-mo-coi` dọn được phần tệp.

## Bài học của đợt, đắt nhất là ba cái đầu

1. **Một số đo đúng vẫn có thể sai đề.** Lượt soi thứ hai kết luận khoá cuộn hỏng vì
   `window.scrollBy(0,300)` cho `scrollY` đi từ 0 lên 300. Con số ấy có thật, nhưng
   `overflow: hidden` theo đúng đặc tả CSS **vẫn cho cuộn bằng script** - nó chỉ chặn cuộn của
   người dùng. Phải phát sự kiện chuột thật mới đo được. Suýt nữa một bản vá đúng bị đánh giá
   là hỏng, và một bản vá thứ hai được viết cho một lỗi không tồn tại.
2. **Bài test ghim theo MÃ sống sót qua đợt đổi 167 câu chữ; ghim theo CHUỖI thì không.** Cây
   gộp hai nhánh backend xanh ngay lượt đầu, đúng vì `don_tep_mo_coi_test.go` canh 404 bằng
   `e.Code` và `e.HTTPStatus`, không đọc `Message`. Ngược lại, bài duy nhất đỏ trong cả đợt là
   một bài canh `strings.Contains(msg, "mot trong")` - văn xuôi không dấu.
3. **Ba lượt soi mắt tìm ra 13 lỗi mà 2516 bài test không thấy**, và lượt sau luôn tìm ra lỗi
   lượt trước không đi tới: lượt 1 tìm bẫy tiêu điểm, lượt 2 tìm "lối ra thứ tư" (Lưu hỏng →
   tiêu điểm rơi ra `BODY` → Escape chết hẳn), lượt 3 tìm băng báo câm. Mỗi lượt vá xong lại
   mở ra một đường đi mới chưa ai đi.
4. **Một sự thật chép làm hai bản, lần thứ hai liên tiếp.** Khoá cuộn chép ở hai chỗ - vá một
   chỗ, chỗ kia nằm lại. Sau khi rút thành `useKhoaCuonNen`, một đột biến trong hook làm đỏ 8
   bài trên cả ba bộ test. Ba chuỗi "đã bị xoá" gõ tay ở 13 vị trí trong 10 file, nay khai một
   chỗ.
5. **Agent tự bắt được bài giả của chính mình hai lần**: một bài xanh cả khi gỡ mất dòng nó định
   canh (vì chưa từng mở bảng xổ ra), một bài khẳng định sai trong comment rồi bị chính test
   của nó bác (React chạy effect từ con lên cha, nên lớp phủ trong bắt giá trị trước khi lớp
   ngoài kịp khoá). Cả hai lộ ra nhờ phép đột biến, không nhờ đọc lại.
6. **Tra MISA trả lời được ba câu, không trả lời được hai câu.** Trả lời được: F9 đúng là "thêm
   nhanh danh mục trong giao diện nhập liệu"; MISA chỉ gắn cột tồn vào combo của chứng từ
   xuất/chuyển và bỏ phiếu nhập ra ngoài; lối vào tài liệu hoá là dấu "+" cạnh ô. Không trả lời
   được: **dấu** của cột thành tiền trên phiếu chuyển, và tập trường của form thêm nhanh. Hai
   chỗ đó là giả định của ta, đã ghi vào ADR-0051.
