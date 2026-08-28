# ADR-0042: Vật tư hàng hoá mang một tính chất, và tính chất chỉ có ba giá trị

**Status:** Accepted (2026-08-28)

## Context

Đợt thiết kế lại giao diện module Kho vận
(`99-meta/my-specs/` — mockup ở `99-meta/mockups/kho-van-v3.html`) chạm vào một chỗ trống của
mô hình: danh mục hàng trong `inventory` hôm nay chỉ có mã, tên và đơn vị tính. Không có gì
nói một mã là nguyên liệu đầu vào hay sản phẩm đầu ra.

Người dùng nêu đúng ca thật của xưởng mình ngày 2026-08-28: *"có loại nhập về nó là vật tư, có
loại nhập về nó là thành phẩm ở chỗ khác nhưng là nguyên liệu cho 1 sản phẩm khác của xưởng
mình"*, và yêu cầu tham khảo MISA.

**Ba thứ va nhau trong lúc chốt, và cả ba đều đã được gỡ trong ADR này.**

**Thứ nhất, chữ "hàng hoá" không đủ dùng làm tên cái ô lớn.** Người dùng đề nghị gọi cả danh
mục là "hàng hoá", với lý do hàng hoá bao gồm nguyên vật liệu và thành phẩm. Hình dạng đúng —
có một cái ô lớn bao lấy ba ngăn — nhưng chữ thì kẹt: "hàng hoá" đồng thời là tên của một
trong ba ngăn ấy. Đọc lên thành *"hàng hoá loại hàng hoá"*.

**Thứ hai, MISA đã gặp và đã giải đúng va chạm đó.** Tra tài liệu chính thức ngày 2026-08-28:
danh mục của họ tên là **"Vật tư hàng hóa"**, còn **"Hàng hóa"** là một giá trị bên trong
trường **"Tính chất"**. AMIS Kế toán có sáu giá trị (Hàng hóa · Dịch vụ · Nguyên vật liệu ·
Thành phẩm · Công cụ dụng cụ · Combo sản phẩm); MISA SME 2023 chỉ có bốn (Vật tư hàng hoá ·
Thành phẩm · Dịch vụ · Chỉ là diễn giải). Chữ **"tính chất"** vì vậy không phải phát minh của
đợt này — nó là chữ dân kế toán kho Việt Nam đã quen.

**Thứ ba, `CONTEXT.md` đang cấm đúng chữ người dùng muốn dùng.** Mục từ **Vật tư** ghi
`_Avoid_: hàng hoá, sản phẩm, mặt hàng, SKU`. Bản mockup v3.1 đã đổi sang "Hàng hoá" mà không
đối chiếu từ điển — sai quy trình, và ADR này là chỗ sửa lại cho đúng.

## Decision

**1. Danh mục đổi tên thành `Vật tư hàng hoá`.** Cụm bốn chữ, không rút gọn. Mọi chữ ngắn hơn
đều đã có nghĩa hẹp hơn: "vật tư" đọc ra nguyên liệu đầu vào, "hàng hoá" là tên một tính chất.
`CONTEXT.md` đưa cả `vật tư` lẫn `hàng hoá` vào `_Avoid_` của mục từ này.

**2. Mỗi vật tư hàng hoá mang đúng một `tính chất`, và nó là thuộc tính của MÃ.** Không phải
của từng lần nhập xuất. Thép cây thỉnh thoảng bán lại nguyên trạng vẫn là nguyên vật liệu:
tính chất nói ý định chính của mã. Để nó chạy theo từng lần dùng thì nó không còn là thuộc
tính của mã nữa, và không báo cáo nào nhóm được theo nó.

**3. Ba giá trị, không phải sáu:** `nguyen_vat_lieu` · `thanh_pham` · `hang_hoa`.

**4. `Dịch vụ` bị loại, và lý do là một bất biến chứ không phải sự lười.** `CONTEXT.md` định
nghĩa **Tồn** là "số lượng còn lại của một cặp (kho, vật tư hàng hoá)". Một dịch vụ không nằm
trong kho nào và không sinh chuyển động nào, nên nhận nó vào đây là phá bất biến *mọi mã trong
danh mục này đều có thể có tồn* — màn Tồn kho sẽ phải xử lý những dòng vĩnh viễn không có số.
MISA chứa được `Dịch vụ` vì danh mục của họ phục vụ cả bán hàng và hoá đơn; danh mục ở đây chỉ
phục vụ kho. Khi nào có module `sales`, dịch vụ về đó.

**5. `Combo sản phẩm` bị loại** vì nó là một mã gồm nhiều mã khác, cần định mức. Hệ chưa có
định mức nên nó không có gì để đứng.

**6. `Công cụ dụng cụ` hoãn, không loại.** Nó *có* tồn thật nên hợp bất biến ở mục 4, nhưng nó
chỉ khác nguyên vật liệu ở tài khoản kế toán (153 với 152) mà hệ này chưa có kế toán. Thêm một
giá trị vào enum về sau thì rẻ; bỏ một giá trị đã có dữ liệu trỏ vào thì đắt. Nên bắt đầu ít.

**7. Tính chất SỬA ĐƯỢC bất cứ lúc nào, kể cả khi mã đã có chuyển động.** Đây là chỗ nó khác
hẳn **mã** và **đơn vị tính** — hai cái kia khoá sau chuyển động đầu tiên vì sửa chúng làm sai
số lượng lịch sử. Đổi tính chất không đụng vào một con số nào đã ghi; nó chỉ đổi cách nhóm.
Cái giá phải trả được nêu ở mục Consequences.

**8. Mã tự sinh mang tiền tố đọc ra được chính tính chất:** `NVL0001` · `TP0001` · `HH0001`.
Người dùng gõ đè được — công ty đã có bộ mã riêng thì không bị ép bỏ nó.

## Consequences

**Danh mục là của từng công ty, nên ca người dùng nêu tự tan.** Món xưởng khác làm ra mà mình
mua về làm nguyên liệu: ở công ty họ là một bản ghi mang tính chất `thanh_pham`, ở công ty
mình là một bản ghi khác mang `nguyen_vat_lieu`. Hai bản ghi rời nhau, không có gì phải hoà
giải. Đây là lợi ích rơi ra từ một quyết định đã có từ trước, không phải thứ ADR này thêm vào.

**Báo cáo theo nhóm không tái lập được về quá khứ.** Hệ quả trực tiếp của mục 7: một mã đổi từ
`hang_hoa` sang `nguyen_vat_lieu` hôm nay thì báo cáo tháng trước in lại sẽ khác bản đã in.
Chấp nhận được **chỉ vì hệ chưa có sổ kế toán**. Ngày có sổ, đây là chỗ phải xét lại — hoặc
khoá tính chất sau khi chốt sổ kỳ, hoặc lưu tính chất tại thời điểm ghi lên chính dòng chuyển
động. Đổi tính chất phải để lại dòng audit.

**Một ca chưa chốt, cố ý để mở.** Xưởng vừa mua khung thép A2 từ ngoài, vừa tự sản xuất khung
thép A2 để bán: một mã hay hai mã? MISA tách hai vì giá vốn hai đường khác nhau. Hệ này chưa
có giá vốn nên một mã vẫn chạy, và ADR này **không** ép tách. Ngày có giá vốn thì việc tách sẽ
đau, nên đó là câu phải hỏi lại trước khi làm module giá vốn — không phải câu trả lời hôm nay
bằng cách đoán.

**Ba việc kéo theo ở backend.** Cột `tinh_chat` trên bảng danh mục kèm ràng buộc ba giá trị;
một đường cấp mã kế tiếp theo tính chất (sinh ở **máy chủ**, không ở màn hình — hai người tạo
cùng lúc mà màn hình tự đoán số thì cùng ra `NVL0013` rồi một người ăn 409); và bộ lọc theo
tính chất trên `GET` danh mục.

**Không đụng tới `Phiếu`.** Cùng phiên làm việc có bàn tới phiếu nhập nhiều dòng và đã bỏ, vì
`CONTEXT.md` đặt **Phiếu** ngoài `inventory` — nó là thứ `purchasing` và `sales` mang tới, và
**Chuyển động kho** ghi rõ *"không phải một chứng từ: không có số phiếu, không có trạng thái
duyệt"*. Hai màn Nhập kho và Xuất kho vẫn tách riêng, nhưng mỗi lần ghi đúng một dòng chuyển
động. Mở đường cho phiếu trong `inventory` là một ADR khác, chưa viết.
