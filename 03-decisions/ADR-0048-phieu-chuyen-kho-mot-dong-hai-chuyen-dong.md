# ADR-0048: Phiếu chuyển kho — một dòng hàng sinh hai chuyển động

**Status:** Accepted (2026-08-30)
**Extends:** [ADR-0043](ADR-0043-phieu-nhap-xuat-thuoc-inventory.md) — phiếu thuộc `inventory`,
ghi một phiếu là một giao dịch nguyên tử. ADR này thêm loại phiếu thứ ba và không lật lại điều
gì của ADR-0043.

## Context

Hệ đã có phiếu nhập và phiếu xuất (rc.82). Còn thiếu **chuyển kho**: hàng rời kho A sang kho B,
tổng tồn của công ty không đổi, chỉ chỗ nằm là đổi.

Hôm nay việc đó làm được bằng cách ghi một phiếu xuất ở kho A rồi một phiếu nhập ở kho B. Ba
chỗ hỏng, và cả ba đều là chuyện thật:

1. **Hai tờ phiếu rời nhau.** Ghi xong tờ xuất, mất điện, tờ nhập không bao giờ được ghi — hàng
   biến mất khỏi sổ. Không dòng nào nói ra điều đó, vì mỗi tờ đứng riêng đều hợp lệ.
2. **Sổ nói sai chuyện đã xảy ra.** Một phiếu xuất nghĩa là hàng ra khỏi công ty. Chuyển kho thì
   không — hàng vẫn là của công ty. Ai đọc sổ sáu tháng sau đếm "tháng này xuất bao nhiêu" sẽ
   đếm cả hàng chưa hề rời kho.
3. **Không có số phiếu chung.** Không tra ngược được cặp xuất-nhập nào thuộc cùng một chuyến xe.

## MISA làm gì

Tra `helpact.misa.vn` mục *Chuyển vật tư, hàng hóa giữa các kho nội bộ* (xem Sources):

- Chuyển kho là **một chứng từ riêng**, không phải hai chứng từ xuất và nhập.
- **Một dòng chi tiết ghi CẢ kho xuất lẫn kho nhập.** Kho đích nằm ở từng dòng, không ở đầu
  chứng từ.
- Mỗi dòng sinh ra **một bút toán kép** — một vế Có ở kho nguồn, một vế Nợ ở kho đích.
- AMIS có ba loại: *Xuất chuyển kho nội bộ*, *Xuất kho kiêm vận chuyển nội bộ*, *Xuất hàng cho
  chi nhánh khác*. Phần đầu chứng từ có thêm **Mã người vận chuyển** và **Lệnh điều động**.

## Decision

**1. `chuyen` là giá trị thứ ba của `stock_vouchers.kind`.** Không một bảng riêng: một phiếu
chuyển có đúng những ô mà phiếu nhập và phiếu xuất đã có — số, ngày, người giao nhận, diễn giải,
số chứng từ gốc — và một bảng thứ hai sẽ chép lại cả mười bốn cột để khác đúng một chỗ.

**2. Một dòng hàng của phiếu chuyển sinh HAI dòng `stock_movements`**, trong cùng một giao dịch:
một dòng `xuat` ở kho nguồn và một dòng `nhap` ở kho đích, cùng `voucher_id`, cùng `occurred_at`,
cùng số lượng. Tồn vẫn là `SUM(quantity)` và không phép tính nào phải biết tới chữ "chuyển".

Vì sao KHÔNG một loại chuyển động thứ tư (`chuyen`): một dòng sổ mang đúng **một** `warehouse_id`
— đó là cột NOT NULL của bảng, và mọi câu tính tồn đều gộp theo nó. Một loại `chuyen` sẽ buộc
thêm cột `warehouse_id_dich`, và cột đó **rỗng ở 99% số dòng**. Tệ hơn: mọi câu tính tồn đang có
sẽ phải nhớ cộng thêm một vế cho cột mới, và câu nào quên thì cho ra một con số tồn sai mà không
gì báo. Hai dòng thì không câu nào phải sửa.

**3. Kho nguồn và kho đích đều nằm ở TỪNG DÒNG**, không ở đầu phiếu — theo đúng MISA, và cùng lý
lẽ mà ADR-0043 đã dùng cho kho của phiếu nhập: một chuyến xe gom hàng từ hai kho về một kho là ca
có thật, và đặt kho ở đầu phiếu là cấm trước ca đó.

**4. Kho nguồn phải KHÁC kho đích trên mỗi dòng.** Một `CHECK` không đỡ được việc này — hai kho
nằm ở hai hàng khác nhau của `stock_movements` — nên nó là phép kiểm của tầng service, trả `422`
kèm tên ô `dong[i].warehouse_dich_id`. Một dòng chuyển từ kho A sang kho A là hai dòng sổ triệt
tiêu nhau: không sai tồn, nhưng để lại hai dòng rác mà người đọc sổ phải tự hiểu.

**5. Phiếu chuyển KHÔNG có đối tác.** `partner_id` phải là `NULL`. Đối tác là bên ngoài công ty;
chuyển kho là chuyện trong nhà. Gửi `partner_id` khác rỗng cho phiếu `chuyen` là `422` kèm tên ô
`partner_id`, chứ không lặng lẽ bỏ qua — lặng lẽ bỏ qua là để người dùng tin họ đã ghi một thứ
mà hệ không lưu.

**6. Kiểm tồn CHỈ ở kho nguồn**, và cộng dồn nhiều dòng cùng (kho nguồn, mặt hàng) trong cùng
phiếu trước khi kiểm — đúng khuôn phiếu xuất. Kho đích không có gì để kiểm: hàng vào thì tồn
tăng.

**7. Ba loại chứng từ của MISA gộp thành MỘT.** Ba loại đó khác nhau ở *tài khoản hạch toán* và
*mẫu in*, mà hệ này chưa có hệ thống tài khoản lẫn đường in. Bịa ra một ô "loại chuyển kho"
không ảnh hưởng gì tới thứ được lưu là bịa ra một câu hỏi cho người dùng. **Mã người vận chuyển**
và **Lệnh điều động** cũng bỏ: người vận chuyển đã có ô `nguoi_giao_nhan`, còn lệnh điều động là
một thực thể chưa tồn tại.

## Consequences

**Được:** hàng không bao giờ rơi giữa hai kho. Sổ phiếu trả lời được "chuyến nào chuyển gì".
Không câu tính tồn nào phải sửa. Không cột nào rỗng 99%.

**Mất:** đọc **một** dòng sổ lẻ thì không biết nó thuộc một lần chuyển kho — nó trông y hệt một
dòng xuất hoặc một dòng nhập thường. Câu trả lời nằm ở `voucher_id` của chính dòng đó: mở tờ
phiếu ra là thấy cặp của nó. Đây cũng đúng cách MISA làm (hai bút toán của một chứng từ), và là
lý do màn chi tiết chuyển động **bắt buộc** phải có đường sang tờ phiếu — đường đó đã dựng ở
rc.82.

**Còn để mở:**

1. **Hàng đang đi đường.** MISA có *Nhập kho hàng mua đang đi đường*; chuyển kho giữa hai tỉnh
   mất ba ngày thì trong ba ngày đó hàng không nằm ở kho nào. Hệ này ghi hai dòng **cùng một
   thời điểm**, tức coi việc chuyển là tức thời. Đúng cho một xưởng có các kho cạnh nhau; sai
   khi có chi nhánh xa. Sửa được sau bằng một kho trung gian "Hàng đang đi đường", không phải
   bằng cách đổi mô hình này.
2. **Giá vốn khi chuyển kho.** Hàng rời kho A theo giá vốn nào và vào kho B theo giá nào — câu
   này thuộc đợt giá vốn và bị chặn bởi cùng một câu chưa ai trả lời: xưởng dùng phương pháp
   tính giá xuất kho nào.

## Sources

- MISA AMIS Kế toán — *Chuyển vật tư, hàng hóa giữa các kho nội bộ*:
  https://helpact.misa.vn/kb/chuyenvattu_hanghoa_giuacackhonoibo/
- MISA AMIS Kế toán — *Lập nhanh các chứng từ chuyển kho*:
  https://helpact.misa.vn/kb/lap_nhanh_cac_chung_tu_chuyen_kho/
