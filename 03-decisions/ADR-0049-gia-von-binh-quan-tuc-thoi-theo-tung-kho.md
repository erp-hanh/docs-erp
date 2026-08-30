# ADR-0049: Giá vốn tính theo bình quân tức thời, theo từng kho

**Status:** Accepted (2026-08-30)
**Extends:** [ADR-0043](ADR-0043-phieu-nhap-xuat-thuoc-inventory.md),
[ADR-0048](ADR-0048-phieu-chuyen-kho-mot-dong-hai-chuyen-dong.md).

## Context

Hệ đã ghi được **số lượng** vào ra (rc.85) nhưng chưa ghi **tiền**. Không có giá vốn thì không
trả lời được ba câu mà bất kỳ ai cũng hỏi: *hàng trong kho đang đáng bao nhiêu*, *tháng này bán
lãi bao nhiêu*, *giá thành một sản phẩm là bao nhiêu*.

Đây là **quyết định duy nhất trong cả bản thiết kế không sửa được sau**: đổi phương pháp khi sổ
đã có vài nghìn dòng là tính lại toàn bộ giá vốn của toàn bộ lịch sử.

### Người dùng trả lời gì, và vì sao câu trả lời đó không dùng thẳng được

Khi được hỏi, chủ xưởng nói: *"tính giá xuất kho bằng cách lấy giá nhập của đợt gần nhất"*.

Tra trước khi làm (xem Sources):

- **MISA AMIS** cho chọn đúng **bốn** cách: bình quân cuối kỳ, bình quân tức thời, nhập trước
  xuất trước (FIFO), đích danh. **Không có** "giá nhập lần cuối".
- **Thông tư 200** chấp nhận **ba** nhóm: bình quân, đích danh, FIFO. Cách "nhập sau xuất trước"
  đã bị bỏ.

Nhưng lý do bác bỏ **không phải** là lệch chuẩn — mà là **sổ không tự cân**. Ba phương pháp hợp
lệ đều giữ một đẳng thức: *giá vốn đã xuất + giá trị tồn cuối = giá trị tồn đầu + giá trị đã
nhập*. "Giá nhập lần cuối" phá nó:

```
Nhập 100kg x 18.000 = 1.800.000
Nhập 100kg x 22.000 = 2.200.000      tổng đã chi 4.000.000

Xuất 150kg theo giá nhập cuối:
  150 x 22.000      = 3.300.000
  tồn 50 x 22.000   = 1.100.000
                      ---------
  cộng lại            4.400.000      lệch 400.000, không dòng nào ghi
```

Sáu tháng sau không ai chỉ ra được 400.000 đó ở đâu.

### Ý người dùng vẫn đúng, chỉ đúng ở một chỗ khác

Nhu cầu thật đằng sau câu trả lời: giá thép biến động, và họ không muốn con số bị pha loãng bởi
hàng cũ mua rẻ. Nhu cầu đó có **hai** chỗ đáp ứng, và chúng khác nhau:

- **Giá vốn trên sổ** phải phản ánh tiền đã thực chi. Bình quân **tức thời** đáp ứng đúng phần
  "bám giá hiện tại": nhập một lô giá cao thì giá vốn nhích lên **ngay**, không phải chờ cuối kỳ.
- **Giá để chào bán** thì đúng là phải lấy giá mua gần nhất — không ai báo giá theo giá đã mua
  sáu tháng trước.

Người dùng đã chọn phương án tách hai con số này.

## Decision

**1. Giá vốn xuất kho tính theo BÌNH QUÂN TỨC THỜI, phạm vi TỪNG KHO.**

Đơn giá xuất của một dòng bằng:

```
don_gia_xuat = (giá trị tồn của cặp (kho, mặt hàng) ngay trước dòng này)
             / (số lượng tồn của cặp đó ngay trước dòng này)
```

Phạm vi **từng kho** chứ không chung mọi kho — MISA cho chọn cả hai, và chọn "từng kho" là điều
làm cho **chuyển kho có nghĩa**: giá trị đi theo hàng từ kho này sang kho kia. Nếu tính chung mọi
kho thì một lần chuyển kho không đổi gì cả, và cột "giá trị tồn của kho A" thành một con số không
suy ra được từ đâu.

Hệ quả phải nói ra: **cùng một mặt hàng có giá vốn khác nhau ở hai kho.** Đó là chuyện bình
thường của phương pháp này, không phải lỗi.

**2. Đơn giá của dòng NHẬP là số người dùng gõ; đơn giá của dòng XUẤT là số máy tính.**

Ô đơn giá chỉ hiện ra và chỉ nhận giá trị ở **phiếu nhập**. Phiếu xuất không có ô đơn giá — cho
gõ ở đó là mời người dùng ghi đè một con số mà cả hệ thống suy ra từ lịch sử.

**Đơn giá nhập là giá CHƯA THUẾ.** Thuế GTGT đầu vào được khấu trừ nên nó không nhập vào giá trị
hàng tồn. Cho thuế lên phiếu nhập là chỗ giá trị tồn kho bị thổi lên 8-10% mà không ai thấy.

**3. Đơn giá và thành tiền LƯU trên từng dòng sổ, không tính lại lúc đọc.**

Bình quân tức thời là hàm của **toàn bộ lịch sử trước nó**, nên tính lại lúc đọc là quét lại cả
sổ cho mỗi lần mở màn. Con số được chốt tại thời điểm ghi và nằm lại đó.

Lưu **cả hai** `don_gia` và `thanh_tien` chứ không suy một cái từ cái kia: `thanh_tien` là con số
đi vào mọi phép cộng, và để nó là kết quả của một phép nhân làm tròn ở mỗi lần đọc là để tổng của
n dòng lệch khỏi tổng đã ghi.

**4. Chuyển kho không sinh lãi hay lỗ.** Dòng xuất ở kho nguồn mang giá bình quân của kho nguồn;
dòng nhập ở kho đích mang **đúng con số đó**. Tổng giá trị tồn của công ty không đổi qua một lần
chuyển kho — đó là định nghĩa của việc chuyển kho.

**5. Điều chỉnh tồn:**

- **Giảm** (kiểm kê thiếu): dùng giá bình quân hiện tại, **không cho gõ**. Phần giá trị mất đi là
  hao hụt, và nó phải bằng đúng thứ sổ đang ghi.
- **Tăng** (kiểm kê thừa): **cho gõ đơn giá**, điền sẵn giá bình quân hiện tại của cặp đó. Bắt
  buộc phải cho gõ vì có một ca không có sẵn câu trả lời: tồn đang bằng 0 thì không có giá bình
  quân nào để lấy.

**6. "Giá nhập gần nhất" là một con số RIÊNG, không phải giá vốn.**

Nó là đơn giá của dòng `nhap` mới nhất của mặt hàng, tính trên **toàn công ty** chứ không theo
kho — vì nó trả lời câu "hôm nay mua vào bao nhiêu", và câu đó không phụ thuộc hàng nằm ở kho
nào. Nó hiện ở màn chi tiết vật tư hàng hoá và là số điền sẵn của bảng tính giá bán.

Nó **không** được lưu thành một cột: đọc dòng nhập mới nhất là một truy vấn có index sẵn, còn một
cột lưu sẵn là một con số phải nhớ cập nhật ở ba đường ghi và sẽ lệch ở đường thứ tư.

**7. Phiếu lùi ngày làm sai giá vốn của các dòng sau nó, và ĐỢT NÀY KHÔNG CHỮA.**

Đây là giới hạn thật, nói ra chứ không giấu. Bình quân tức thời chốt con số tại thời điểm ghi;
chèn một phiếu vào **trước** các dòng đã chốt thì các dòng đó mang giá cũ. MISA gặp đúng vấn đề
này và giải bằng một chức năng **"Tính giá xuất kho"** chạy lại hàng loạt.

Đợt này làm phần **tính khi ghi**. Đường tính lại hàng loạt là một đợt riêng. Cho tới lúc đó,
màn hình phải **nói ra** khi một phiếu được ghi lùi ngày trước dòng cuối cùng của cặp (kho, mặt
hàng) — im lặng nhận rồi cho ra một con số sai là điều tệ nhất trong ba lựa chọn.

## Consequences

**Được:** một con số giá trị tồn kho **cân với tiền đã chi**, đúng Thông tư 200, đúng một trong
bốn cách MISA làm, và bám giá thị trường vì nó cập nhật ngay mỗi lần nhập.

**Mất:**

1. **Không truy được lô.** Bình quân trộn mọi lô thành một con số, nên câu "lô hàng tháng 3 còn
   bao nhiêu" không trả lời được. Đó là cái giá của việc không phải khai lô ở mỗi lần nhập, và
   nó cũng là lý do câu **lô và hạn sử dụng** vẫn còn để mở.
2. **Cùng một mặt hàng có hai giá vốn ở hai kho.** Người đọc báo cáo phải biết điều này.
3. **Phiếu lùi ngày cho ra giá sai** cho tới khi có đường tính lại (mục 7).

**Còn để mở:**

- **Chức năng tính lại giá xuất kho** hàng loạt.
- **Nhập tồn đầu kỳ** kèm giá vốn — hiện phải làm bằng một phiếu nhập, và điều đó nói dối rằng
  công ty đã mua lô hàng đó vào ngày bắt đầu dùng phần mềm.
- **Giá thành sản phẩm** — thuộc module nào thì ADR-0017 chưa có chỗ (`costing` không nằm trong
  mười hai module).

## Sources

- MISA AMIS Kế toán — *Tính giá xuất kho*: https://helpact.misa.vn/kb/html_17060000/
- MISA AMIS Kế toán — *Tuỳ chọn hệ thống* (chỗ đặt tuỳ chọn tính theo kho):
  https://helpact.misa.vn/kb/tuy-chon-he-thong/
- Thông tư 200 và VAS 02 — ba nhóm phương pháp được chấp nhận, và việc bỏ "nhập sau xuất trước".
