# ADR-0050: Lệnh sản xuất và định mức nguyên vật liệu

**Status:** Accepted (2026-08-30)
**Extends:** [ADR-0017](ADR-0017-muoi-hai-module-va-ten-tieng-anh.md) (module `production` đã có
tên, đây là lần đầu nó có dữ liệu), [ADR-0049](ADR-0049-gia-von-binh-quan-tuc-thoi-theo-tung-kho.md)
(giá vốn — giá thành thành phẩm dựng trên nó).

## Context

Kho đã ghi được số lượng và tiền (rc.87). Thiếu mắt xích giữa kho và bán hàng: **không con số nào
nói một sản phẩm ăn hết bao nhiêu nguyên liệu**. Thiếu nó thì không tính được giá thành, và không
có giá thành thì bảng tính giá bán chỉ là một tờ giấy nháp.

Đây là lần đầu module `production` có dữ liệu. ADR-0017 đã cấp tên cho nó, nên không cần ADR
ranh giới module.

## MISA làm gì

Tra `helpact.misa.vn` và `helpsme.misa.vn` (xem Sources):

**Định mức khai trên CHÍNH THÀNH PHẨM, không ở một màn riêng.** Mở danh mục *Vật tư hàng hoá*,
thêm một mặt hàng, chọn Tính chất = **Thành phẩm**, và lúc đó hiện thêm tab **Định mức nguyên vật
liệu**. Mỗi dòng: *Mã nguyên vật liệu · Đơn vị tính · Số lượng cần dùng để tạo ra **1 đơn vị**
thành phẩm*.

**Lệnh sản xuất** nằm ở phân hệ Kho, có hai tab: **Thành phẩm** và **Định mức xuất NVL cho thành
phẩm**. Sau khi nhập *Số lượng thành phẩm cần sản xuất*, chương trình **tự động tính ra Số lượng
NVL cần sử dụng**. Từ lệnh lập được **phiếu xuất kho NVL** và **phiếu nhập kho thành phẩm**. Báo
cáo *Tổng hợp xuất kho theo lệnh sản xuất* có cột **Chênh lệch NVL**.

**Giá thành, phương pháp giản đơn:** *Chi phí NVL + Chi phí lương + Chi phí sản xuất chung + Chi
phí khác*, tập hợp theo **đối tượng tập hợp chi phí — một đối tượng là một sản phẩm**, và chi phí
chung **phân bổ theo tiêu thức** (định mức, khối lượng).

**Chỗ tài liệu công khai KHÔNG trả lời:** khi một lệnh có nhiều thành phẩm, tab định mức có tách
theo từng thành phẩm hay gộp chung. Đã tra bốn trang, cả bản AMIS lẫn SME2023, không trang nào vẽ
ra cột. Quyết định ở mục 2 dưới đây vì vậy dựa trên suy luận chứ không trích dẫn được.

## Decision

**1. Định mức nguyên vật liệu khai trên chính thành phẩm.**

Bảng `bom_lines` thuộc module **`production`**, khoá ngoại tới `stock_items` của `inventory`. Một
danh mục do module này sở hữu và module kia đọc là chuyện thường của modular monolith — cùng lập
luận mà ADR-0043 đã dùng cho danh mục đối tác.

Chỉ mặt hàng có `tinh_chat = 'thanh_pham'` mới khai được định mức. Số lượng là **cho MỘT đơn vị**
thành phẩm, và dòng định mức mang **đơn vị tính** riêng — hệ đã có đơn vị chuyển đổi, nên bắt khai
định mức theo đơn vị tính chính là bắt người dùng tự quy đổi trong đầu.

Một thành phẩm **không được** có mặt trong chính định mức của nó, dù qua bao nhiêu tầng. Vòng lặp
định mức làm phép nhân "định mức × số lượng" chạy vô hạn.

**2. Một lệnh sản xuất có NHIỀU thành phẩm, và mỗi thành phẩm mang bảng định mức RIÊNG của nó.**

Cấu trúc **hai tầng**, không phải một danh sách phẳng:

```
Lệnh LSX-2026-0001
├── Thành phẩm 1: Cổng sắt 2 cánh   x 10
│     ├── Thép hộp 40x80   120 kg
│     └── Sơn chống rỉ       8 kg
└── Thành phẩm 2: Khung cửa sổ      x 30
      ├── Thép hộp 40x80   225 kg
      └── Sơn chống rỉ      13 kg
```

Vì sao **không** gộp thành một bảng nguyên liệu chung của cả lệnh — cách đó gọn hơn và có vẻ đủ:
xuất thừa 20 kg thép thì **không câu nào nói cổng hay khung ăn thêm**, và lúc đó cột *Chênh lệch
NVL* của MISA mất hết ý nghĩa. Nặng hơn: giá thành của MISA tập hợp theo **từng sản phẩm**, và một
bảng nguyên liệu trộn chung thì không tài nào tách chi phí NVL cho từng sản phẩm được. Gộp là đóng
cửa trước cả hai thứ mà lệnh sản xuất sinh ra để làm.

**3. Định mức được SAO CHÉP vào lệnh lúc lập, và sửa được ngay trên lệnh.**

Lệnh giữ con số của chính nó. Sửa định mức gốc của một thành phẩm **không** làm đổi lệnh đã lập —
một tờ lệnh in ra đưa xuống xưởng mà tự đổi số sau lưng là một tờ giấy không ai tin được nữa.

Chiều ngược lại cũng không: sửa định mức trên một lệnh **không** cập nhật ngược về danh mục.

**4. Xuất thừa hoặc thiếu so với định mức VẪN cho xuất.** Định mức là **dự kiến**, không phải hạn
mức. Thợ cắt hụt một thanh thép là chuyện có thật, và một hệ thống chặn tay ở đó chỉ dạy người ta
sửa định mức cho khớp thực tế — tức phá luôn con số dùng để so sánh. Chênh lệch được **ghi ra**,
đúng cột *Chênh lệch NVL* mà MISA có.

**5. Lệnh sản xuất có trạng thái TIẾN ĐỘ, không có bước duyệt.**

Bốn giá trị: `moi` · `dang_lam` · `xong` · `huy`. Trạng thái chỉ nói việc đang tới đâu; nó **không**
gác đường ghi — xuất nguyên liệu cho một lệnh `moi` vẫn được, và chính lần xuất đầu tiên là thứ
đẩy lệnh sang `dang_lam`. Bước duyệt là chuyện của đơn hàng, và đơn hàng vẫn ở ngoài
(cùng lằn ranh mà ADR-0043 mục 3 đã đặt cho phiếu).

Huỷ một lệnh **không** xoá các phiếu đã sinh ra từ nó. Hàng đã rời kho thì đã rời kho.

**6. `production` gọi `inventory`, KHÔNG có chiều ngược lại.**

Phiếu xuất NVL và phiếu nhập thành phẩm là **phiếu của `inventory`** — cùng bảng, cùng đường ghi,
cùng phép kiểm tồn, cùng phép tính giá vốn. `production` gọi sang service của `inventory` để ghi
chúng.

Mối nối lưu ở bảng **`production_order_vouchers`** thuộc `production`, không phải một cột
`production_order_id` trên `stock_vouchers`. Một cột như thế bắt `inventory` biết đến sự tồn tại
của `production`, và lúc đó hai module cùng phụ thuộc nhau — thứ mà ranh giới module dựng lên để
tránh.

**7. Giá thành = chi phí NVL + chi phí nhân công + chi phí chung, phân bổ theo chi phí NVL.**

Theo đúng phương pháp giản đơn của MISA, cắt bớt phần hệ này chưa có:

- **Chi phí NVL** của một thành phẩm: tổng `thanh_tien` của các dòng xuất thuộc lệnh và thuộc
  thành phẩm đó. Có sẵn nhờ mục 2 — đây chính là thứ cấu trúc hai tầng mua được.
- **Chi phí nhân công** và **chi phí chung**: hai ô người dùng gõ trên lệnh, bằng **số tiền thật
  đã chi**, không phải phần trăm. Chúng là tiền có thật — công thợ, điện, que hàn — nên cộng chúng
  vào giá trị hàng tồn là đúng kế toán, không phải bịa ra tiền.
- **Phân bổ** cho từng thành phẩm **theo tỷ lệ chi phí NVL** của thành phẩm đó. Đây là tiêu thức
  "theo định mức" của MISA, và nó là tiêu thức duy nhất hệ này có dữ liệu để tính: chưa có giờ
  công, chưa có khối lượng.

**Giá nhập kho một đơn vị thành phẩm** = (chi phí NVL của nó + phần chi phí chung được phân bổ) /
số lượng thành phẩm **thực nhập**. Chia cho số **thực nhập** chứ không số **cần sản xuất**: làm ra
8 cái trên một lệnh đặt 10 cái thì 8 cái đó gánh toàn bộ chi phí đã bỏ ra.

**8. Sổ vẫn cân.** Tiền rời kho nguyên liệu + tiền chi phí gõ tay = tiền vào kho thành phẩm. Đây
là bất biến phải có một bài test canh, cùng loại với bất biến của ADR-0049.

## Consequences

**Được:** một con số giá thành có gốc gác, truy ngược được tới từng dòng nguyên liệu đã xuất. Cột
chênh lệch định mức trả lời được "sản phẩm nào ăn thịt". Và bảng tính giá bán cuối cùng có đầu vào
thật.

**Mất:**

1. **Gõ thêm hai con số mỗi lệnh.** Bỏ trống thì giá thành chỉ còn nguyên liệu — chạy được, nhưng
   giá thành thấp hơn sự thật, và màn hình phải nói ra điều đó chứ không im lặng.
2. **Không có dở dang.** Một lệnh chưa xong thì nguyên liệu đã xuất nằm ở đâu trên sổ? Hệ này coi
   giá thành chỉ được chốt lúc **nhập kho thành phẩm**, nên giữa hai mốc đó giá trị nguyên liệu đã
   rời kho mà chưa thành gì cả. MISA gọi phần này là *đánh giá dở dang* và nó là một bước riêng.
   Chấp nhận được với lệnh làm xong trong vài ngày; sai khi một lệnh kéo qua kỳ báo cáo.
3. **Phân bổ theo chi phí NVL thiên vị sản phẩm dùng nguyên liệu đắt.** Một sản phẩm ít nguyên
   liệu nhưng tốn nhiều công sẽ gánh quá ít chi phí chung. Sửa được sau bằng một tiêu thức khác
   khi có dữ liệu giờ công.

**Còn để mở:**

- **Đánh giá dở dang** (mục Mất 2).
- **Lệnh sản xuất gắn với đơn hàng** — `sales` chưa có đơn hàng nào.
- **Định mức nhiều tầng**: bán thành phẩm là nguyên liệu của thành phẩm khác. Cấu trúc bảng chịu
  được, nhưng phép tính "định mức × số lượng" ở đợt này chỉ chạy **một tầng**.

## Sources

- MISA AMIS Kế toán — *Khai báo định mức giá thành thành phẩm*:
  https://helpact.misa.vn/kb/thiet_lap_dinh_muc_gia_thanh_thanh_pham/
- MISA SME2023 — *Quản lý định mức nguyên vật liệu và tình hình xuất kho nguyên vật liệu theo từng
  lệnh sản xuất*:
  https://helpsme.misa.vn/2023/kb/quan_ly_dinh_muc_nguyen_vat_lieu_va_tinh_hinh_xuat_kho_nguyen_vat_lieu_theo_tung_lenh_san_xuat/
- MISA AMIS Kế toán — *Lập lệnh sản xuất*: https://helpact.misa.vn/kb/html_17030100/
- MISA AMIS Kế toán — *Doanh nghiệp tính giá thành theo Phương pháp giản đơn*:
  https://helpact.misa.vn/kb/doanh-nghiep-tinh-gia-thanh-theo-phuong-phap-gian-don/
- MISA AMIS Kế toán — *Xuất kho nguyên vật liệu cho hoạt động sản xuất*:
  https://helpact.misa.vn/kb/xuatkho_nguyenvatlieu_chohoatdongsanxuat/
