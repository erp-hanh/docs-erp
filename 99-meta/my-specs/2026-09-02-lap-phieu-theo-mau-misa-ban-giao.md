# Bàn giao: màn lập phiếu dựng lại theo mẫu MISA

Ngày 2026-09-02. Nhánh `fix/bang-cot` (frontend-erp), nối tiếp đợt tùy chỉnh cột bảng.
Kế hoạch: `2026-09-02-lap-phieu-theo-mau-misa-plan.md`.
Bàn giao trước: `2026-09-02-tuy-chinh-cot-bang-ban-giao.md`.

## Trạng thái

- **9 commit mới**, đã push lên `origin/fix/bang-cot`. Đầu nhánh: `6eec558`.
- Máy dev đang chạy **chính nhánh này** (deploy bằng `deploy-dev.sh fix/bang-cot`), không phải tag rc.
- Tự chạy lại lần cuối lúc bàn giao: **147 file / 2216 bài xanh, exit 0**; `tsc --noEmit` exit 0.
  `lint` 0 lỗi (1 warning cũ ở `ONgay.tsx`), `arch` PASS, `kiem-giao-dien.mjs` sạch.
- **Đã ghi được một phiếu thật trên dev**: `PN-2026-0013`, backend trả "1 dòng đã vào sổ".
- **Chưa merge vào `main`, chưa tag rc.** Đó là việc đầu tiên của phiên sau, sau khi người
  dùng soi xong.

## Mockup đã duyệt

`mockup-erp/phieu-form-bo-cuc.html`, tab "A - Theo mẫu MISA".
Đăng ở https://claude.ai/code/artifact/e87e3120-162c-4dc9-9a9f-2661233c326f

**Mockup đã lên code, nên nó HẾT HẠN.** Từ giờ bản chạy được là nguồn sự thật. Đừng sửa
mockup nữa, cũng đừng duyệt lại nó - giữ hai bản song song là một khoản bảo trì không ai trả.

Chỗ bản code cố ý khác mockup:
- **Vùng Đính kèm tệp**: mockup có vẽ, code KHÔNG làm - xem mục "Còn nợ".
- **Cột "Tồn kho" trong bảng xổ**: mockup vẽ ở ô Mã hàng; code làm ở CẢ ô Mã hàng lẫn ô Kho,
  vì ảnh mẫu thứ ba (phiếu xuất XK00725) cho thấy MISA làm ở ô Kho.
- **Công tắc "Chỉ hiện hàng/kho còn tồn"**: mockup có, code không - xem "Còn nợ".

## Chín commit

| SHA | Việc |
|---|---|
| `f15184d` | Dòng trống nằm sẵn trong `values.dong`; bỏ hai khoá kho mặc định |
| `ab17b87` | Xoá `HangThemMoi`; dòng trống hiện ngay trong bảng, đủ mọi ô |
| `3720e42` | `OTraCuu`: cờ `gon`, mũi tên xổ, `data-o-loi` |
| `fb12acf` | Bố cục đầu phiếu và bảng theo mẫu MISA |
| `8b250be` | Cột Tồn kho trong bảng xổ chọn kho và chọn mặt hàng |
| `f4bb66a` | Sáu lỗi bố cục soi được trên dev |
| `3eae806` | Bảng xổ ra portal, không bị khung bảng cắt |
| `6eec558` | Bỏ chữ thừa trong ô bảng; ô mã chỉ hiện mã |

## Hai quyết định gốc, và vì sao

**1. Dòng trống là một dòng THẬT trong `values.dong`.** Trước đây `<HangThemMoi>` là một
`<tr>` riêng giữ state cục bộ, và chỉ khi bấm dấu cộng thì dòng mới vào bảng. Người dùng chê
hàng đó không đủ cột và trông như dòng hỏng. Nay `values.dong` LUÔN kết thúc bằng một dòng
có `stock_item_id === ''`; chọn mặt hàng xong là dòng trống mới tự nối vào sau.

Hàm gác cổng là `dongDaGo(one)` = `stock_item_id !== '' || soLuong !== '' || donGia !== ''`.
**Ba vế chứ không riêng `stock_item_id`**: người gõ số lượng rồi quên chọn hàng phải thấy câu
"Chọn vật tư hàng hoá", không được im lặng nuốt mất dòng đó.

Ba chỗ phải lọc, bỏ sót chỗ nào là một lỗi thật: `validatePhieuForm`, thân request, và phép
đếm cho lỗi "phải có ít nhất một dòng".

**2. Bỏ `khoMacDinh` và `khoDichMacDinh`.** Người dùng chốt "chọn kho cho từng dòng", đúng
như mẫu. Hai ô ở đầu phiếu biến mất, hai khoá biến mất khỏi `PhieuFormValues`, nhãn
`nhanKhoMacDinh` biến mất khỏi `NhanPhieu`.

## Còn nợ

- **Vùng Đính kèm tệp.** Người dùng đã yêu cầu và mockup đã vẽ, nhưng `backend-erp` chưa có
  gì: không endpoint tải lên, không chỗ lưu, không bảng ghi tệp thuộc phiếu nào (grep cả repo
  ngày 2026-09-02, không chỗ nào khớp `attachment|upload|multipart`). **Backend phải làm
  trước**, và đó là một đợt riêng chứ không phải một bổ sung nhỏ.
- **Công tắc "Chỉ hiện hàng/kho còn tồn"** trong bảng xổ. Mẫu có. Chưa làm vì nó cần một luật
  theo loại phiếu mà chưa ai chốt: ở phiếu NHẬP, lọc như vậy là giấu mất hàng mới.
- **"Thêm mới (F9)"** trong bảng xổ - tạo vật tư / tạo kho ngay trong phiếu.
- **Phân trang bảng dòng hàng.** Mẫu có, cố ý bỏ: một tờ phiếu hiếm khi quá 20 dòng, mà cắt
  trang thì người dùng bấm Ghi trong lúc đang nhìn nửa số dòng.
- **`NHAN_PHIEU.ghiChuTon` và `.ghiChuDonGia` không còn chỗ nào vẽ ra** - chúng chỉ sống
  trong khối chú thích xanh đã bỏ. Chưa xoá vì `phieu-form-values.test.ts` còn khoá giá trị.
  Cần một quyết định: bỏ hẳn cả trường lẫn ba bài đó, hay tìm chỗ khác cho chúng.
- **Tám bảng ngoài Kho vận** vẫn dùng API cũ của `<Bang>` - việc còn tồn từ đợt trước.

## Bẫy đã gặp trong đợt này, đừng gặp lại

- **`--reporter=basic` KHÔNG tồn tại ở vitest 4.1.10.** Nó chết lúc khởi động và trả exit 1
  mà không chạy bài nào. Đọc nhầm con số đó thành "test đỏ" là sai hoàn toàn. Dùng
  `--reporter=dot`.
- **Bảng xổ trong một ô bảng bị `overflow` cắt.** `position: absolute` bên trong một khung có
  `overflow-x: auto` là bị cắt, và đó là hành vi đúng của CSS. Chữa bằng portal ra
  `document.body` + `position: fixed`. Kéo theo: `onBlur` phải hỏi CẢ vỏ ô lẫn node danh sách,
  và cần `onMouseDown preventDefault()` vì Firefox/Safari không focus `<button>` lúc bấm chuột.
- **Portal làm đỏ 101 bài / 9 file** vì helper test tra mục bằng `oTraCuu.querySelector(...)`.
  Tra bằng `document.getElementById(oGo.getAttribute('aria-controls'))`.
- **Một bài test có thể xanh giả sau khi mô hình đổi.** Bài cũ dựng dòng bằng `dongMoi('','','')`
  - dòng đó nay là dòng trống nên bị bỏ qua, và bài xanh với 0 khoá lỗi thay vì 4. Đọc từng
  bài rồi mới sửa, đừng sửa mù.
- **Revert một đột biến bằng cách thay một dòng đơn lẻ là không an toàn**: hai selector CSS
  cùng có dòng `background: var(--mau-nen-noi);` và bản vá dán nhầm chỗ. Chép nguyên file ra
  rồi chép lại.
- **Chữ trong một ô bảng rộng 110px không phải gợi ý, nó là một bức tường.** Ba lần trong đợt
  này một câu chú thích làm mọi dòng cao gấp ba đến gấp bốn: ô ĐVT, ô Tên hàng, và nhãn của
  `OTraCuu`. Trong ô bảng thì chuyển sang `title`, và nhớ rằng `title` trên một control
  `disabled` không bao giờ bật - phải đặt lên vỏ.
- **jsdom không đo được bố cục.** 2216 bài xanh không nói được gì về việc dòng có phình hay
  cột Thao tác có nhìn thấy không. Năm trong sáu lỗi của một đợt chỉ soi thật trên dev mới ra.
- Sau `deploy-dev.sh`, **tab agent-browser đang mở vẫn chạy bundle JS cũ**. Đóng phiên rồi mở
  lại. Và refs `@eN` của phiên cũ không dùng lại được ở phiên mới - phải snapshot rồi lấy ref.
- Dự án KHÔNG dùng prettier. Đừng chạy `npx prettier --write`.
