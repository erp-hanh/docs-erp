# ADR-0052: Tờ phiếu xuất cũng hiện trị tuyệt đối — một cột, một quy ước đọc

**Status:** Accepted (2026-09-04)
**Extends:** [ADR-0051](ADR-0051-to-phieu-chuyen-hien-tri-tuyet-doi.md) — tờ phiếu chuyển hiện
trị tuyệt đối. ADR này giữ nguyên mọi lý lẽ của ADR-0051 và **lật đúng một khoản** của nó: khoản
loại trừ phiếu xuất ra khỏi phạm vi.

## Context

ADR-0051 mang tiêu đề *"dấu là chuyện của sổ, không của tờ phiếu"*, rồi ở mục Decision lại viết:
quyết định này **không** áp lên phiếu nhập và phiếu xuất, vì *"mỗi tờ chỉ có một chiều, và dấu ở
đó nói đúng thứ nó nói"*.

Khoản loại trừ ấy để lại **ba cách đọc cho một cột** trên đúng một bảng dùng chung:

| Màn | Loại phiếu | Cột Số lượng hiện |
|---|---|---|
| Lập phiếu | cả ba | luôn dương (người dùng gõ vào một ô số dương) |
| Chi tiết phiếu | nhập | dương |
| Chi tiết phiếu | **xuất** | **`-8`** |
| Chi tiết phiếu | chuyển | dương (ADR-0051) |

Người dùng gõ `8` ở màn lập một phiếu xuất, ghi phiếu, mở lại tờ vừa ghi và thấy `-8`. Không màn
nào giải thích cho họ chuyện gì vừa xảy ra với con số của mình. Đây không phải một lỗi hiển thị
đơn lẻ: đó là mệnh đề *"dấu ở đó nói đúng thứ nó nói"* đang nói với một người **đã biết** tờ giấy
trong tay là phiếu xuất — cái dấu trừ không thêm thông tin nào tiêu đề tờ phiếu chưa nói.

Chỗ dấu THẬT SỰ mang thông tin là sổ chuyển động: ở đó một hàng đứng một mình, cạnh những hàng
của loại khác, và dấu là thứ duy nhất nói ra chiều của nó. ADR-0051 đã tách đúng ranh giới ấy rồi
— chỉ là chưa kéo nó tới cùng.

## MISA làm gì

Tra ngày 2026-09-04, cả `helpact.misa.vn` (AMIS Kế toán) và `helpsme.misa.vn/2023/`.

**Kết quả chính, nói thẳng: không bản nào phát biểu về DẤU của số lượng trên chứng từ xuất kho.**
Ghi lại đây để phiên sau khỏi đi lại con đường này — giống hệt kết quả tra của ADR-0051, và lần
này đã tra thêm cả nhánh báo cáo kho chứ không chỉ nhánh chứng từ.

Những gì tra được:

- Trang lập phiếu xuất kho của cả hai bản chỉ nói **"nhập số lượng được xuất"** — một số lượng
  người dùng gõ vào, không có dấu trừ nào trong hướng dẫn.
- Nhánh báo cáo kho (*Tổng hợp tồn kho*, *Sổ chi tiết vật tư hàng hoá*) mô tả báo cáo theo dõi
  **chứng từ nhập, chứng từ xuất và tồn** như những phần tách nhau, không mô tả một cột số lượng
  mang dấu. Tài liệu không liệt kê tên từng cột nên đây là mức khẳng định cao nhất rút được từ
  nguồn công khai — **không** phải một phát biểu của MISA về dấu.

Nên phần còn lại của quyết định này là lý lẽ của ta, không phải của MISA. Đúng như ADR-0051.

## Decision

**Trên TỜ PHIẾU, mọi cột số hiện trị tuyệt đối, ở cả ba loại phiếu.**

1. Cột Số lượng, cột Thành tiền, hai ô tổng và ô Tổng tiền hàng của màn chi tiết phiếu đều bỏ dấu
   trừ, không phụ thuộc `kind`.
2. **Chuỗi thô của backend, kèm dấu, còn nguyên ở `title` của từng ô** — y như ADR-0051 mục 5.
   Người đi đối chiếu với sổ đọc lại được con số thật ở đúng chỗ họ quen tìm.
3. **Hai màn đọc SỔ không đổi một dòng nào.** `MovementListPage` và `MovementDetailPage` giữ dấu:
   ở đó một hàng là một bút toán đứng riêng và dấu là thứ duy nhất nói ra chiều.
4. Đây là phép **định dạng ở lớp trình bày**, không phải một phép tính (R-19). Không con số nào
   đi vào thân một request bị đụng tới.

Quy tắc rút gọn cho người viết màn sau này: **tờ phiếu không mang dấu, sổ mang dấu.** Một câu,
không có ngoại lệ nào phải nhớ.

## Alternatives

**Giữ khoản loại trừ của ADR-0051** — loại. Nó chính là trạng thái đang có, và nó đẻ ra ba cách
đọc cho một cột trên một bảng dùng chung. Chi phí không nằm ở lần đọc đầu tiên mà ở mọi cột số
thêm vào bảng ấy về sau: mỗi cột mới lại phải hỏi "cột này theo quy ước nào".

**Đi hướng ngược lại: cho màn LẬP phiếu xuất hiện số âm** — loại. Người dùng gõ số dương vào ô;
đổi dấu con số họ vừa gõ ngay dưới ngón tay họ là thứ khó biện minh nhất trong cả ba lựa chọn.

**Giữ dấu, thêm một câu chú thích dưới bảng** — loại, cùng lý do ADR-0051 đã loại nó: một dòng
chú thích không sửa được con số người dùng đang nhìn, và phải được đọc *trước* con số mới có tác
dụng.

**Đổi dấu ở backend cho phiếu xuất** — loại thẳng, y như ADR-0051. `SUM(quantity)` là cách tính
tồn của cả hệ (ADR-0048 mục 2).

## Consequences

**Được:** một quy ước duy nhất cho tờ phiếu, phát biểu được bằng một câu. Tờ phiếu người dùng mở
lại hiện đúng con số họ đã gõ, ở cả ba loại.

**Mất:**

1. **Cùng một dòng sổ hiện ra hai kiểu ở hai màn**, nay ở cả phiếu xuất chứ không riêng phiếu
   chuyển. Đây là cái giá ADR-0051 đã cân một lần; ADR này chỉ mở rộng phạm vi của nó, `title`
   vẫn là chỗ nối lại hai cách đọc.
2. **Bốn bài test khoá quy ước cũ đã bị đổi chiều**, mỗi bài kèm chú thích nói rõ nó đổi vì quy
   ước đổi chứ không vì code hỏng. Không bài nào bị xoá.

**Nợ để lại:**

- Vẫn chưa có gì canh việc một màn thứ hai vẽ tờ phiếu (bản in, xuất PDF) phải theo cùng quy ước
  — nợ này thừa kế nguyên từ ADR-0051, nay nặng hơn vì phạm vi rộng ra cả ba loại.

## Sources

Tra ngày 2026-09-04. Hai bản MISA hay lệch nhau; ở đây **cả hai đều không phát biểu về dấu của số
lượng trên chứng từ xuất kho**, và đó là kết quả tra chứ không phải chỗ tra thiếu.

- MISA AMIS Kế toán — *Xem tồn kho của vật tư, hàng hóa*:
  https://helpact.misa.vn/kb/html_00000045/
- MISA AMIS Kế toán — *Ghi sổ phiếu xuất kho khi xuất quá số lượng tồn*:
  https://helpact.misa.vn/kb/lam_the_nao_khi_ghi_so_phieu_xuat_kho_phan_mem_canh_bao_xuat_qua_so_luong_ton_trong_kho/
- MISA SME 2023 — *Nhập tồn kho*: https://helpsme.misa.vn/2023/kb/html_27060100/
