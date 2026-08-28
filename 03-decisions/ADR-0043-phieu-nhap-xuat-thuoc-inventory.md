# ADR-0043: Phiếu nhập kho và phiếu xuất kho thuộc `inventory`

**Status:** Accepted (2026-08-28)
**Supersedes:** đoạn cuối mục Consequences của
[ADR-0042](ADR-0042-tinh-chat-vat-tu-hang-hoa-ba-gia-tri.md), viết cùng ngày và chốt ngược lại.

## Context

`CONTEXT.md` trước đợt này đặt **Phiếu** ra ngoài `inventory`: *"Một chứng từ có mã, nhiều dòng
và trạng thái duyệt. Phiếu không thuộc `inventory` — nó là thứ `purchasing` và `sales` mang
tới."* Mục từ **Chuyển động kho** đứng sau nó và nói thẳng: *"Nó không phải một chứng từ:
không có số phiếu, không có trạng thái duyệt."*

Trong cùng ngày 2026-08-28, ranh giới đó bị thử ba lần và lần thứ ba thì gãy.

**Lần một — bản mockup v3.2 vẽ phiếu nhiều dòng mà không đối chiếu từ điển.** Sai quy trình.

**Lần hai — người dùng chọn bỏ phiếu.** Khi được hỏi giữa "bỏ phiếu, mỗi lần ghi một dòng" và
"giữ phiếu, viết ADR đổi luật", người dùng chọn vế đầu. Bản v3.3 dựng theo: hai màn Nhập / Xuất
tách riêng nhưng mỗi lần ghi đúng một dòng, số phiếu giấy nhét vào ô Ghi chú.

**Lần ba — nhìn thấy bản một dòng rồi thì người dùng đảo lại**, và câu chốt là:
*"tạo phiếu xuất, nhập phải có nhiều trường thông tin hơn nữa như nhà cung cấp, khách hàng,
1 phiếu sẽ có nhiều dòng"*. Đây là quyết định của người dùng trên chính thứ họ vừa nhìn thấy,
không phải một lần đổi ý cho vui — và bản một dòng đã bộc lộ đúng chỗ nó thiếu.

**Ba chỗ bản một dòng không đỡ nổi, và cả ba đều là việc thật của thủ kho:**

1. **Số phiếu giấy nằm trong ô ghi chú.** Muốn tra ngược một phiếu thì ô tìm kiếm phải quét cột
   ghi chú — tức tra cứu một khoá nghiệp vụ bằng cách tìm chuỗi tự do. Gõ sai một dấu cách là
   mất dấu.
2. **Không có chỗ cho nhà cung cấp và khách hàng.** Cùng vào ghi chú, cùng một hệ quả, và mất
   luôn khả năng hỏi "tháng này nhà cung cấp nào giao nhiều nhất".
3. **Một lần nhận hàng mười mặt hàng phải gõ mười lần**, mỗi lần gõ lại kho và ngày. Đó là công
   việc thật của thủ kho lúc 7 giờ sáng.

**MISA làm gì** (tra tài liệu chính thức cùng ngày, xem mục Sources): chứng từ nhập kho và xuất
kho của AMIS Kế toán có phần **thông tin chung** gồm *Số chứng từ · Ngày chứng từ · Ngày hạch
toán · Đối tượng · Người giao hàng (hoặc Người nhận hàng) · Diễn giải · Kèm theo chứng từ gốc*,
rồi tới **bảng chi tiết** với các cột *Mã hàng · Tên hàng · ĐVT · Kho · Số lượng · Đơn giá ·
Thành tiền · TK*. Mã và tên là **hai cột rời**, không gộp một ô.

## Decision

**1. `Phiếu nhập kho` và `Phiếu xuất kho` là thực thể của `inventory`.** Một phiếu có số, ngày,
đối tác, và **nhiều dòng hàng**. Mỗi dòng hàng sinh ra đúng một **chuyển động kho**; chuyển động
vẫn là thứ duy nhất tồn được tính ra từ đó.

**2. Ghi một phiếu là một giao dịch nguyên tử.** Dòng thứ ba vi phạm tồn thì **cả phiếu không
vào sổ** — không có chuyện hai dòng đầu đã ghi còn dòng ba thì không. Đây là ràng buộc chính, và
là lý do một endpoint ghi-nhiều-dòng phải có chứ không lặp lời gọi một dòng.

**3. Phiếu KHÔNG có trạng thái duyệt.** Đây là chỗ ADR này *không* mở hết ranh giới cũ: ghi là
vào sổ ngay. Thứ cần duyệt là đơn mua và đơn bán, và chúng vẫn ở ngoài `inventory`. Mở thêm
trạng thái duyệt là một ADR khác, chưa viết.

**4. `Điều chỉnh tồn` KHÔNG đi qua phiếu.** Nó là việc lẻ, một dòng một lần, có lý do bắt buộc.
Gộp lô các dòng điều chỉnh làm mờ trách nhiệm — sáu tháng sau không ai chỉ được ai đã chốt con
số nào.

**5. Trường của phiếu, lấy từ MISA rồi cắt theo thứ hệ này có:**

| Giữ | Bỏ, và vì sao |
|---|---|
| Số phiếu, Ngày phiếu | |
| Đối tác (nhà cung cấp / khách hàng) | |
| Người giao hàng / Người nhận hàng | |
| Diễn giải (lý do nhập, lý do xuất) | |
| Kèm theo *n* chứng từ gốc | |
| Cột dòng: Mã hàng · Tên hàng · ĐVT · Kho · Số lượng | |
| | **Ngày hạch toán** — hệ chưa có sổ kế toán, nên nó không khác Ngày phiếu |
| | **Đơn giá · Thành tiền** — hệ chưa có giá vốn, và R-19 cấm frontend tính tiền |
| | **TK kho · TK chi phí** — chưa có hệ thống tài khoản |

**6. Kho nằm ở TỪNG DÒNG, không ở đầu phiếu**, theo MISA. Đầu phiếu có một ô kho mặc định điền
sẵn cho mọi dòng mới; đổi ở dòng nào thì chỉ dòng đó đổi. Đặt kho ở đầu phiếu là cấm trước một
ca có thật — một chuyến xe giao hàng cho hai kho.

**7. Mã và tên là HAI CỘT RỜI trên mọi bảng của module**, không gộp vào một ô hai dòng. Theo
MISA, và theo câu chốt của người dùng: *"không chung mã và tên trong 1 cột"*. Ô hai dòng của bản
v3 chỉ còn dùng cho cặp *tên + mô tả*, không bao giờ cho cặp *mã + tên*.

## Consequences

**Ranh giới module dịch chỗ, và đây là cái giá thật.** `inventory` giờ giữ một chứng từ. Ngày có
`purchasing`, đơn mua sẽ **sinh ra** phiếu nhập chứ không thay nó — nếu không thì hai đường ghi
vào sổ cùng tồn tại và tồn sẽ lệch. Đó là ràng buộc phải nhớ khi làm `purchasing`, và là chỗ
ADR này đắt nhất.

**Cần một danh mục đối tác.** Nhà cung cấp và khách hàng dùng chung một bảng, khác vai theo loại
phiếu. Chưa có bảng đó thì ô Đối tác là chuỗi tự do — chạy được, nhưng mất khả năng nhóm theo
đối tác, tức mất đúng cái lợi ở mục Context 2. Nên làm bảng ngay, đừng để chuỗi tự do lâu.

**Backend phải có đường ghi nhiều dòng nguyên tử**, cộng bảng phiếu và khoá ngoại từ dòng chuyển
động lên phiếu. Phép kiểm tồn âm chạy **sau khi đã đặt cả phiếu vào transaction**, không phải
từng dòng một — hai dòng cùng một mặt hàng trong một phiếu phải cộng dồn trước khi kiểm.

**Xoá thì xoá cả phiếu hay xoá một dòng?** Chưa chốt, và cố ý để mở. Xoá một dòng làm phiếu giấy
lệch phiếu máy; xoá cả phiếu thì mất luôn những dòng không sai. Câu này phải trả lời trước khi
viết đường xoá, không phải lúc đang viết.

**ADR-0042 vẫn đứng nguyên ở mọi mục khác.** Ba tính chất, tên danh mục `Vật tư hàng hoá`, mã
sinh ở máy chủ — không mục nào bị ADR này đụng tới. Chỉ đoạn cuối phần Consequences của nó, đoạn
nói "mở đường cho phiếu trong `inventory` là một ADR khác, chưa viết", là bị thay: ADR đó chính
là văn bản này.

## Sources

- [Kho – AMIS Kế toán](https://helpact.misa.vn/kb/chtg-kho/)
- [Nhập kho thành phẩm sản xuất – AMIS Kế toán](https://helpact.misa.vn/kb/nhapkho_thanhpham_sanxuat/)
- [Mua hàng nhập khẩu nhập kho – AMIS Kế toán](https://helpact.misa.vn/kb/muahang_nhapkhau_nhapkho/)
