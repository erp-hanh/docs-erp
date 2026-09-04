# Kế hoạch: hoàn thiện module Kho vận

Ngày 2026-09-04. Nối tiếp `2026-09-03-don-no-ky-thuat-ban-giao.md` (rc.112).
Người dùng giao: "làm hoàn thiện màn kho trước", phạm vi chốt là CẢ module Kho vận.

Nguồn danh sách: ba lượt soi code song song trên `origin/main` (`frontend-erp` 29177f6),
chia theo ba vùng - ba màn chỉ đọc, đường đi tờ phiếu, ba cặp danh mục.

## Năm đợt, xếp theo cái người dùng mất nhiều nhất nếu không sửa

### Đợt 1 - Người dùng mất việc đang gõ, hoặc đi vào ngõ cụt

| # | Chỗ | Người dùng thấy gì |
|---|---|---|
| 1.1 | `PhieuFormPage.tsx:409` | Rời trang khi đang gõ dở 20 dòng hàng: mất sạch, không một câu hỏi |
| 1.2 | `PhieuFormPage.tsx:436` | Enter trong ô số lượng gửi luôn cả tờ phiếu, thay vì sang ô kế |
| 1.3 | `PhieuFormPage.tsx:151` | Số phiếu về muộn ghi đè số người dùng vừa gõ tay |
| 1.4 | `PhieuFormPage.tsx:166` | Lỗi 422 cũ vẫn đỏ trên ô đã sửa xong |
| 1.5 | `PhieuFormPage.tsx:145,285` | Sau 422, xoá/chèn dòng làm câu lỗi tô sang hàng khác |
| 1.6 | `WarehouseListPage.tsx:563`, `PartnerListPage.tsx:614` | Nhánh 422 không có nút bỏ lọc: ngõ cụt, phải gõ lại địa chỉ |
| 1.7 | `WarehouseForm.tsx:254`, `PartnerForm.tsx:295` | Form kho và đối tác không có nút Huỷ |
| 1.8 | `KhoVanHomePage.tsx:271` | `/inventory-summary` hỏng: nửa trang chủ biến mất câm lặng |

### Đợt 2 - Màn hình nói sai, hoặc đường đi bị thiếu

| # | Chỗ | Người dùng thấy gì |
|---|---|---|
| 2.1 | `BalanceListPage.tsx:30`, `MovementListPage.tsx:785` | Bảng đang bị lọc mà ô lọc nói "Tất cả kho" |
| 2.2 | `PhieuFormPage.tsx:486` | "Đã ghi phiếu" không có đường mở tờ vừa ghi |
| 2.3 | `WarehouseFormPage.tsx:297`, `PartnerFormPage.tsx:248` | "Đã lưu" trơ trọi, không đường đi tiếp |
| 2.4 | `KhoVanHomePage.tsx:198` | Năm dòng chuyển động gần nhất không bấm được |
| 2.5 | `BalanceListPage.tsx:216`, `MovementListPage.tsx:417` | Cột Mã kho / Mã VTHH không bấm sang chi tiết |
| 2.6 | `VoucherListPage.tsx:219` | Sổ chưa có phiếu nào mà màn rỗng không có nút Lập phiếu |
| 2.7 | `MovementListPage.tsx:898` | Ba nút nấc thời gian không có trạng thái đang chọn |

### Đợt 3 - Hai màn của cùng tờ phiếu trả lời khác nhau

| # | Chỗ | Người dùng thấy gì |
|---|---|---|
| 3.1 | `VoucherDetailPage.tsx:448` | Gõ 2 dòng, mở lại thấy "Tổng số: 4" |
| 3.2 | `VoucherDetailPage.tsx:624` | Cột "Xuất ra" ở màn lập thành "Số lượng" ở màn chi tiết |
| 3.3 | `VoucherDetailPage.tsx:631,660` | Ba quy ước dấu cho cùng một cột, tuỳ màn |
| 3.4 | `VoucherDetailPage.tsx:218` | Phiếu chuyển: dòng phụ nói "Không có đối tác", thân phiếu giấu ô đó |
| 3.5 | `VoucherListPage.tsx:321` | Cùng một ô có ba tên giữa form và danh sách |
| 3.6 | `VoucherListPage.tsx:327` vs `VoucherDetailPage.tsx:327` | Ô rỗng: "Không ghi" ở đây, "—" ở kia |

### Đợt 4 - Một sự thật chép làm nhiều bản (đã lệch thật, không phải rủi ro suông)

- `PhieuFormPage.module.css:37-79` vs `VoucherDetailPage.module.css:25-58`: chép nguyên khối đầu
  phiếu kể cả comment, và **đã lệch**: nhãn một bên `--mau-chu`, bên kia `--mau-chu-mo`.
- Khối xác nhận hai bước: **9 bản** tự dựng tay, mỗi bản một kiểu.
- Ba mã lỗi backend khai lại ở **7 file**, câu 403 chép nguyên văn ở 4 file.
- `OKho` / `OVatTu` / `OCapDanhMuc`: 4 bản; `*ListError` / `*DetailError`: 6 bản;
  `OThaoTac*`: 3 bản; ba file `.module.css` danh mục chép gần nguyên.
- `LoiXoaChuyenDong` 2 bản, `MA_HET_TON` / `MA_DONG_THUOC_PHIEU` khai hai lần.

Đợt này thêm file mới nên golden `LEVELS.md` sẽ lệch - chạy lúc không agent nào khác đụng repo.

### Đợt 5 - Hai màn xem còn thiếu

- Kho không có màn xem: `/kho/:id` mở thẳng form sửa.
- Đối tác không có `/doi-tac/:id` nào: dán địa chỉ hai đoạn ra trang 404.
- Cùng một hình URL đang mang ba nghĩa ở ba danh mục.

Đây là đợt **thiết kế**, không phải đợt vá - khuôn bám theo `StockItemDetailPage`.

## Việc bị cắt khỏi phạm vi

- Hai màn `machine` (`MachineListPage`, `BreakdownReportPage`) - người dùng nói rõ để sau.
- Nút In phiếu (`window.print` không có ở đâu trong `src/`) - chưa ai yêu cầu.
- Ô tìm trong danh mục đơn vị tính (trần 100 mục) - thuộc màn vật tư, không thuộc Kho vận.

## Luật thi công

1. Mỗi đợt chạy tối đa ba agent song song, chia theo FILE để không đụng nhau.
2. Mỗi bản vá phải kèm bài test đỏ trước - xanh sau, chứng minh bằng một đột biến vào code sản phẩm.
3. Bài test ghim theo MÃ lỗi và theo CLASS, không ghim theo câu chữ và không đọc `textContent`
   của cả hàng - hai bẫy đã đốt hai đợt trước.
4. jsdom không tính bố cục: mọi mục dính khoá cuộn, tiêu điểm, chiều cao phải soi thật trên dev
   sau khi deploy, không được tuyên bố xong bằng test xanh.
5. Máy dev đang chạy bản dựng nhánh `ma-tran-quyen`, KHÔNG phải rc.112 - phải deploy lại từ
   `main` trước khi soi mắt, nếu không là soi nhầm code.
