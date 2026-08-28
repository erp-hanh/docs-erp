# Kho vận v3 — đợt 1 thi công, và quyết định đóng băng thiết kế

Ngày: 2026-08-29. Mockup: `99-meta/mockups/kho-van-v3.html` (bản v3.6, 16 màn).
Từ điển đã sửa: `CONTEXT.md`. Hai ADR đã viết: **ADR-0042** (tính chất vật tư hàng hoá),
**ADR-0043** (phiếu nhập/xuất thuộc `inventory`).

## Chốt 1 — Đóng băng thiết kế, không vẽ thêm màn nào

Năm vòng duyệt trong hai ngày sinh ra **16 màn và 0 dòng code**. Mỗi vòng đều mở thêm
cửa: phiếu nhiều dòng → đơn vị chuyển đổi → giá vốn → chuyển kho → lệnh sản xuất → tính
giá bán. Mỗi cửa đều mở đúng, nhưng cộng lại thì bản thiết kế đã vượt xa thứ dựng được.

**Từ đây tới khi đợt 1 chạy thật trên dev: không tra MISA thêm, không thêm màn, không mở
câu hỏi mới.** Những câu còn treo (lô/hạn dùng, kiểm kê, tồn đầu kỳ, danh mục đối tác,
nhóm hàng, giá thành thuộc module nào) nằm ở mục cuối văn bản này và **ở yên đó**.

## Chốt 2 — Không viết ADR ranh giới module, vì đã có rồi

[ADR-0017](../../03-decisions/ADR-0017-muoi-hai-module-va-ten-tieng-anh.md) chốt mười hai
module. Viết thêm một ADR nói lại là thủ tục thừa. Việc phải làm là **áp dụng nó**, và
lần áp dụng đầu tiên đã bắt được một lỗi của chính tôi.

**Lỗi:** ngày 28/08 tôi xếp *Lệnh sản xuất* vào `inventory`, lấy căn cứ là MISA đặt nó ở
phân hệ Kho. Sai — hai thứ khác nhau bị lẫn:

| | Là gì | Ai chốt |
|---|---|---|
| **Phân hệ ở giao diện** | Chỗ người dùng bấm vào để tới màn | Tự do, MISA làm mẫu |
| **Module ở code** | Ranh giới sở hữu dữ liệu và đường ghi | ADR-0017, sửa phải có ADR |

ADR-0017 nói thẳng nó **không** chốt "cách gom module thành phân hệ ở giao diện". Nên đặt
lối vào Lệnh sản xuất trong menu Kho vận **vẫn được**, mà dữ liệu lệnh vẫn thuộc
`production`. Hai quyết định rời nhau.

**Bản đồ 16 màn sau khi sửa:**

| Module | Màn |
|---|---|
| `inventory` | Quy trình · Tồn kho · Phiếu nhập · Phiếu xuất · Chuyển kho · Điều chỉnh tồn · Sổ chuyển động · Chi tiết chuyển động · Danh mục VTHH (3 màn) · Kho (2 màn) |
| `production` | Lệnh sản xuất |
| `sales` | Tính giá bán theo định mức |
| *chưa có chủ* | Tính giá thành — xem mục cuối |

Năm màn danh mục thuộc `inventory` chứ không phải "danh mục dùng chung": MISA gom chúng
vào *Quản lý danh mục* là cách gom **phân hệ giao diện**. Một danh mục do `inventory` sở
hữu và `purchasing` đọc là chuyện thường của modular monolith.

## Chốt 3 — Đợt 1 chỉ làm frontend, không chờ backend một thứ gì

Lý do: mọi thứ cần backend (tính chất, phiếu nhiều dòng, đơn vị chuyển đổi, giá vốn, đối
tác) đều là schema, và schema thì phải chốt xong mới chạm. Trong khi đó **có tám việc
frontend thuần** cải thiện thật được màn đang chạy, và deploy được ngay.

| # | Việc | Vì sao làm được ngay | Kiểm bằng |
|---|---|---|---|
| 1 | Tách ba màn ghi: `/nhap-kho`, `/xuat-kho`, `/dieu-chinh`, mỗi màn đặt sẵn `kind` | Backend đã có `MovementKind` ba giá trị và `RecordMovementRequest.kind` | Ghi ba dòng, mỗi màn một loại, sổ hiện đúng loại |
| 2 | Ô kho và vật tư **gõ-để-tìm** dùng tham số `q` | `WarehouseListParams.q` và `StockItemListParams.q` đã có | Gõ mã của mặt hàng thứ 150 và chọn được |
| 3 | Tách **mã và tên thành hai cột** ở 6 bảng | Thuần hiển thị | Mắt |
| 4 | Cột Thao tác thành **nút biểu tượng**, có `aria-label` và `title` nói lý do khoá | Thuần hiển thị | Rê chuột lên nút khoá, đọc được lý do |
| 5 | Bỏ vạch mức tồn dưới cột Tồn | Thuần hiển thị | Mắt |
| 6 | Cột phụ 320px · đầu thẻ có tên · dải chỉ số từ `meta.total` | `meta.total` đã có ở mọi endpoint danh sách | Số trên dải khớp số ở chân bảng |
| 7 | **Sửa mã quyền sai** trên màn 403 | Đang ghi `inventory.balance.read`; mã thật là `inventory.balance_read` | Đối chiếu `permissions.go` |
| 8 | Trạng thái **409** cho màn xuất, và bỏ chặn cứng xuất quá tồn | Luật tồn là của `MovementService`, màn hình chỉ cảnh báo | Xuất quá tồn → nhận 409, màn hiện đúng |

Việc 7 là **lỗi thật đang chạy trên dev**, không phải cải tiến: người dùng đọc mã quyền
đó cho quản trị viên thì quản trị viên tìm không ra.

Việc 1 và 2 là hai thứ đáng giá nhất. Việc 2 chữa lỗi hai phần ba danh mục không chọn
được — lỗi đã ghi trong bàn giao 22/08 và vẫn còn.

**Không làm trong đợt 1:** cột `tinh_chat`, phiếu nhiều dòng, đơn vị chuyển đổi, đơn giá,
giá trị tồn, chuyển kho, lệnh sản xuất, tính giá bán. Tất cả đều cần schema.

## Chốt 4 — Thứ tự các đợt sau, và một câu hỏi chặn

**Đợt 2 — tính chất + trạng thái ngừng theo dõi.** Một cột enum, một cột trạng thái, một
đường cấp mã kế tiếp ở máy chủ. Rẻ nhất trong đám cần schema, và nó mở khoá bộ lọc mà
danh mục 248 mặt hàng đang thiếu.

**Đợt 3 — đơn vị chuyển đổi.** Đặt trước phiếu, và đây là chỗ tôi đổi ý so với 28/08:
đơn vị chuyển đổi **đụng vào mọi con số tồn đã ghi**, nên càng ít dòng sổ lúc làm càng
rẻ. Phiếu thì chỉ thêm bảng mới, không sửa số cũ.

**Đợt 4 — phiếu nhập/xuất nhiều dòng + đối tác** (ADR-0043).

**Đợt 5 — giá vốn.** Chặn bởi một câu chưa ai trả lời: **xưởng đang dùng phương pháp tính
giá xuất kho nào?** Tôi giả định *bình quân tức thời, tính theo từng kho* và đã dựng mockup
theo đó, nhưng đây là thứ duy nhất trong cả bản thiết kế **không sửa được sau** — đổi
phương pháp khi đã có vài nghìn dòng sổ là tính lại toàn bộ giá vốn. Hỏi kế toán của xưởng
trước khi tới đợt này.

## Những câu còn treo, cố ý không trả lời hôm nay

1. **Giá thành thuộc module nào.** ADR-0017 không có `costing`. Hai đường: nhét vào
   `production`, hoặc vào `accounting`. Thêm module thứ mười ba là phải sửa ADR-0017.
2. **Lô và hạn sử dụng.** Xi măng, sơn, dầu đều có hạn. MISA có. Ảnh hưởng cả FIFO lẫn
   đích danh, nên nó gắn với câu giá vốn.
3. **Kiểm kê kho** — CONTEXT.md đã ghi "hệ chưa có". Đường đúng để sửa tồn hàng loạt;
   điều chỉnh một dòng chỉ là chỗ vá.
4. **Nhập tồn đầu kỳ** — khối 6 của kế hoạch gốc, chưa có màn nào.
5. **Danh mục đối tác** và **danh mục nhóm hàng** — hai bảng kéo theo từ đợt 4 và đợt 2.
6. **Xoá một dòng hay cả phiếu** (ADR-0043 để mở).
7. **Một mã hay hai mã** khi vừa mua vừa tự sản xuất cùng một mặt hàng (ADR-0042 để mở).

## Việc tiếp theo, đúng một việc

Thi công đợt 1 theo `superpowers:subagent-driven-development`, tám việc ở bảng trên, một
nhánh `kho-van-v3-dot-1` trên `frontend-erp`. Xong thì tag rc và kiểm chứng trên
`http://103.179.172.110/` bằng tài khoản `qa-thukho` — lúc đó câu "deploy rc rồi đăng nhập
kiểm chứng" mới có nghĩa.
