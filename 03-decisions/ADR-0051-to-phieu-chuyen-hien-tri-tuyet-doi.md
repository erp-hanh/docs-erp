# ADR-0051: Tờ phiếu chuyển kho hiện trị tuyệt đối — dấu là chuyện của sổ, không của tờ phiếu

**Status:** Accepted (2026-09-03)
**Extends:** [ADR-0048](ADR-0048-phieu-chuyen-kho-mot-dong-hai-chuyen-dong.md) — một dòng hàng
của phiếu chuyển sinh hai dòng `stock_movements` ngược dấu. ADR này không lật lại điều gì của
ADR-0048; nó quyết cách **hiển thị** hai dòng ấy trên tờ phiếu.

## Context

ADR-0048 chốt rằng một dòng hàng của phiếu chuyển sinh **hai** dòng sổ: một `xuat` mang số lượng
âm ở kho nguồn, một `nhap` mang số lượng dương ở kho đích. ADR-0049 gắn `don_gia` và `thanh_tien`
vào từng dòng sổ, nên vế xuất cũng mang một `thanh_tien` âm.

Màn chi tiết phiếu (`VoucherDetailPage`) vẽ thẳng cả hai dòng ấy lên bảng "Hàng hoá" của tờ
phiếu, mỗi hàng một dòng sổ, kèm một cột **Loại** (Nhập / Xuất) chỉ có ở phiếu chuyển. Tại thời
điểm quyết, tờ phiếu chuyển hiện ra như sau:

| Loại | Kho | Số lượng | Đơn giá | Thành tiền |
|---|---|---|---|---|
| Xuất | Kho A | -8 | 20.000 | -160.000 |
| Nhập | Kho B | 8 | 20.000 | 160.000 |
| | | *hai chiều bù nhau* | | *hai chiều bù nhau* |

Hai chỗ hỏng, và cả hai là chuyện người dùng thật gặp:

1. **Số âm trên một tờ phiếu chuyển đọc ra như một khoản lỗ.** Trên sổ, dấu âm là thông tin: nó
   nói giá trị rút khỏi kho. Trên một *tờ phiếu chuyển* thì tiền không mất đi đâu — nó đi từ kho
   này sang kho kia — nên một số âm mời người đọc đi tìm một khoản hụt không tồn tại. Người dùng
   của hệ này không làm kế toán; họ cầm tờ phiếu giấy đối chiếu với màn hình.
2. **Ô tổng không nói được gì.** Cộng cả cột luôn ra 0 — đúng về số học và câm về nghĩa, vì nó
   đọc ra như một tờ phiếu không chuyển gì. Bản trước né bằng một dòng chữ *"hai chiều bù nhau"*
   đứng thay con số, tức tờ phiếu chuyển là tờ duy nhất **không có** tổng lượng và tổng giá trị.

Hai màn đọc **sổ** (`MovementListPage`, `MovementDetailPage`) không nằm trong bài toán này: ở đó
một hàng là một bút toán đứng riêng, không có hàng đối ứng nào bên cạnh, và dấu là thứ duy nhất
nói ra chiều của nó.

## MISA làm gì

Tra cả hai bản, và phải nói thẳng kết quả chính: **không bản nào phát biểu về DẤU của cột thành
tiền trên tờ phiếu chuyển kho.** Ghi lại đây để phiên sau khỏi tra lại đúng con đường này.

Những gì hai bản **có** nói:

- **MISA SME 2023** — chứng từ chuyển kho *có* mang giá trị tiền, và quyền xem nó là một tuỳ chọn
  phân quyền: *"Nếu không tích chọn Được xem giá vốn: ... chương trình không cho phép hiển thị cột
  Tổng tiền trên danh sách chứng từ Nhập, xuất kho; Chuyển kho."* Lưu ý "Tổng tiền" ở đây là cột
  của **danh sách chứng từ**, không phải dòng tổng bên trong một tờ phiếu.
- **MISA AMIS Kế toán** tách hai loại giá trên cùng một chứng từ chuyển kho: *"Đơn giá bán trên
  chứng từ chuyển kho phục vụ cho việc in phiếu xuất kho đi đường, không phải giá trị dùng để hạch
  toán khi chuyển kho"*, còn *"Giá vốn xuất kho: dùng để xác định giá trị hàng xuất kho → chuyển
  từ kho đi sang kho đến."* Bản SME 2023 **không có** đoạn phân biệt này.
- Định khoản, giống nhau ở cả hai bản: *Nợ TK 152, 153, 155, 156 — chi tiết theo kho / Có TK 152,
  153, 155, 156 — chi tiết theo kho.*

Không trang nào ở hai bản nhắc tới dấu âm, dấu dương, hay hình dạng dòng "Tổng cộng" của bảng chi
tiết một phiếu chuyển.

## Decision

**Trên TỜ PHIẾU CHUYỂN, mọi cột số hiện TRỊ TUYỆT ĐỐI, và hai ô tổng cộng MỘT CHIỀU.**

Áp lên đúng màn chi tiết phiếu, khi `kind = 'chuyen'`:

1. **Cột Số lượng và cột Thành tiền bỏ dấu trừ đi.** Cả hai, hoặc không cột nào — một cột mang dấu
   đứng cạnh một cột không mang dấu là hai quy ước đọc trên cùng một tờ giấy.
2. **Chiều đi của mỗi hàng đọc ở cột Loại**, cột mà ADR-0048 đã sinh ra cho phiếu chuyển. Dấu trừ
   không thêm mệnh đề nào cột Loại chưa nói.
3. **Hai ô tổng cộng một chiều — chỉ các dòng `nhap`** — nên chúng là *lượng* và *giá trị hàng đã
   chuyển*, không phải tổng của cả cột. Phép lọc đọc `kind` của dòng, **không** đọc dấu: dấu là
   thứ tờ phiếu này đang cố ý giấu, nên đọc lại nó là dựng một sợi dây đứt ngay lần đầu ai đó đổi
   cách hiển thị.
4. **Mỗi ô tổng ấy treo một câu nói rõ nó cộng một chiều.** Người cộng nhẩm cả cột sẽ ra gấp đôi
   con số này và có quyền biết vì sao trước khi nghĩ màn hình cộng sai.
5. **Chuỗi thô của backend, kèm dấu, còn nguyên ở `title` của từng ô.** Người đi đối chiếu với sổ
   đọc lại được con số thật ở đúng chỗ họ quen tìm.

Quyết định này **không** áp lên: phiếu nhập, phiếu xuất (mỗi tờ chỉ có một chiều, và dấu ở đó nói
đúng thứ nó nói), sổ chuyển động, màn chi tiết một dòng sổ, và bất kỳ con số nào đi vào thân một
request. Nó là phép **định dạng ở lớp trình bày**, không phải một phép tính (R-19).

## Alternatives

**Giữ nguyên dấu ở cả hai cột** — loại vì đó chính là trạng thái đã có, và nó đẻ ra hai câu hỏi ở
trên. Người dùng của hệ này không đọc sổ kế toán; họ đối chiếu tờ phiếu giấy với màn hình, và một
con số âm trên một tờ phiếu chuyển là câu đầu tiên họ hỏi lại.

**Bỏ dấu ở cột Thành tiền thôi, giữ dấu ở cột Số lượng** — đã làm, và đã hỏng: `-8` đứng cạnh
`160.000` trên cùng một hàng khiến người đọc dừng lại hỏi cái nào đúng. Chính lỗ hổng đó là lý do
ADR này tồn tại thay vì một dòng ghi chú trong code.

**Chỉ hiện vế NHẬP, giấu vế xuất đi** — loại vì tờ phiếu sẽ không còn nói ra hàng rời khỏi kho
nào. Kho nguồn nằm ở vế xuất và chỉ ở đó (ADR-0048 mục 2: một dòng sổ mang đúng một
`warehouse_id`), nên giấu vế xuất là giấu mất một nửa nội dung nghiệp vụ của tờ phiếu.

**Gộp hai dòng sổ thành một hàng "Kho A → Kho B"** — loại vì nó dựng một tầng trình bày thứ hai
chỉ tồn tại ở một loại phiếu: bảng này dùng chung định nghĩa cột với hai loại phiếu kia, và một
phép gộp hàng sẽ phải nhớ gộp lại ở mọi cột mới thêm về sau. Cột Loại đã giải xong bài toán "hàng
này là chiều nào" với chi phí bằng không.

**Đổi dấu ở BACKEND cho phiếu chuyển** — loại thẳng. `SUM(quantity)` là cách tính tồn của cả hệ
(ADR-0048 mục 2); đổi dấu ở đó là làm sai tồn kho để một màn hình đỡ phải định dạng.

**Không làm gì và viết một dòng chú thích dưới bảng** — loại vì một dòng chú thích không sửa được
con số người dùng đang nhìn, và nó phải được đọc *trước* con số mới có tác dụng.

## Consequences

**Được:** một tờ phiếu chuyển đọc được bởi người không làm kế toán — mọi con số dương, chiều đi
nằm ở một cột có tên, và hai ô tổng mang con số thật (lượng và giá trị hàng đã chuyển) thay cho
một dòng chữ đứng thay số.

**Mất:**

1. **Cùng một dòng sổ hiện ra hai kiểu ở hai màn.** Mở `mv-2` từ tờ phiếu thấy `8`, mở nó ở sổ
   chuyển động thấy `-8`. Đây là cái giá đã biết và đã cân: tờ phiếu và sổ là hai vật khác nhau,
   trả lời hai câu hỏi khác nhau. `title` của ô giữ chuỗi thô để nối lại hai cách đọc.
2. **Ô tổng của tờ phiếu chuyển không cộng thứ nó đứng dưới.** Nó cộng một nửa cột. Câu giải thích
   treo trên ô là thứ duy nhất chặn hiểu nhầm ấy, và nó chỉ hiện khi người dùng rê chuột.
3. **Một quy ước hiển thị nữa phải nhớ** khi thêm cột số mới vào bảng dòng của tờ phiếu: cột mới
   mang dấu thì lại lệch khỏi hai cột cũ.

**Nợ để lại:**

- Phép cộng một chiều giả định mỗi dòng hàng sinh **đúng một** vế nhập và một vế xuất cân nhau —
  đúng theo ADR-0048 mục 2. Ngày nào phiếu chuyển nhận một hình dạng khác (chuyển một phần, chuyển
  qua kho trung chuyển), con số tổng này phải được xem lại **trước**, không phải sau.
- Quy ước này mới chỉ sống trong code của `VoucherDetailPage` và trong ADR này. Nếu có màn thứ hai
  vẽ một tờ phiếu chuyển (bản in, xuất PDF), nó phải theo cùng quy ước — và chưa có gì canh việc
  đó ngoài một bài test của riêng màn hiện tại.

## Sources

Tra ngày 2026-09-03. Hai bản MISA hay lệch nhau, nên mỗi ý ở mục *MISA làm gì* đã nói rõ nó thuộc
bản nào. **Cả hai đều KHÔNG phát biểu về dấu của cột thành tiền trên tờ phiếu chuyển kho** — đó
là kết quả tra, không phải chỗ tra thiếu.

- MISA AMIS Kế toán — *Chuyển vật tư, hàng hóa giữa các kho nội bộ*:
  https://helpact.misa.vn/kb/chuyenvattu_hanghoa_giuacackhonoibo/
- MISA SME 2023 — *Chuyển vật tư, hàng hóa giữa các kho nội bộ*:
  https://helpsme.misa.vn/2023/kb/chuyenvattu_hanghoa_giuacackhonoibo/
