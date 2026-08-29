# Bàn giao — Kho vận v3, đợt phiếu (rc.82 → rc.85)

Ngày: 2026-08-30. Bản vẽ: `99-meta/mockups/kho-van-v3.html`.
ADR mới trong đợt: **ADR-0048** (phiếu chuyển kho).

## Đã chạy thật trên `http://103.179.172.110/`, kiểm bằng `qa-thukho`

| rc | Nội dung | Bằng chứng trên máy thật |
|---|---|---|
| 82 | Màn phiếu nhập/xuất, sổ phiếu, danh mục đối tác, thanh điều hướng chia nhóm | Ghi `PN-2026-0002` qua giao diện, 2 dòng vào sổ, số kế tiếp tự nhảy |
| 83 | Ba lỗi giao diện của bảng dòng phiếu | Chụp lại màn: hàng cao một dòng, hai nút biểu tượng hiện rõ |
| 84 | Phiếu chuyển kho — backend + màn | Ghi `PC-2026-0001`: kho A `1350 → 1320`, kho B `0 → 30` |
| 85 | Cột Loại cho bảng dòng của phiếu chuyển | Bảng chi tiết `PC-2026-0001` hiện `Nhập kho` / `Xuất kho` |

Migration trên dev đã ở **41**, `ck_stock_vouchers_kind` nhận đủ ba giá trị.

## Ba lỗi thật bắt được trong đợt, và cách chúng lộ ra

**1. `PhieuFormPage` trắng cả màn.** `getNextVoucherCode` nhận một `200` sai hình dạng thì
trả `undefined`, giá trị đó đi thẳng vào state ô "Số phiếu", rồi phép kiểm cục bộ đọc
`values.code.length` ở lượt vẽ kế tiếp. **21 bài test của chính màn đó đều xanh** — chỉ bài
test cấp `App.test.tsx` gặp, vì máy chủ giả ở đó trả thân của một DANH SÁCH cho mọi đường
không khai báo. Chữa ở tầng api: hàm nào trả về giá trị đi thẳng vào ô nhập thì phải kiểm
hình dạng rồi ném lỗi có chữ.

**2. Hai nút biểu tượng của bảng dòng hiện ra là hai ô viền RỖNG.** Các `<svg>` của
`bieu-tuong.tsx` không mang `width`/`height`; `BangDongPhieu.module.css` thiếu luật
`svg { width; height }` mà mọi bảng khác trong module đều có. Không lỗi biên dịch, không
cảnh báo lint, `kiem-giao-dien.mjs` không bắt, jsdom không tính bố cục nên không test nào đỏ.
**Chỉ mở màn thật ra nhìn mới thấy.**

**3. Bảng dòng của phiếu chuyển thiếu cột Loại.** Cột này bị bỏ ở rc.82 với một lý do đúng
vào lúc đó — "mọi dòng của một phiếu mang đúng `kind` của phiếu". ADR-0048 phá đúng tiền đề
ấy. Bài test cũ vẫn xanh vì nó khoá **mệnh đề cũ**.

Cả ba đều thuộc một loại: **thứ chỉ lộ ra khi mở màn thật ra nhìn**. Đợt sau phải giữ
nguyên nhịp `deploy rc → đăng nhập → chụp màn → nhìn`.

## Hai chỗ hạ tầng đã sửa, phiên sau cần biết

**Bản ghim R-06 trên `backend-erp/main` từng khớp nhánh chưa merge.** Nhánh
`spec/ngung-su-dung-phan-vung` của phiên khác thêm ADR-0044 vào dòng *Decisions* của R-06;
lần ghim trước đó ghim theo nhánh ấy, nên `backend-erp/main` **đỏ khi đối chiếu với
`docs-erp/main`** — tức chính thứ CI checkout. Đã ghim lại theo `docs-erp/main`. Khi nhánh
kia merge thì bản ghim lệch lại một lần nữa; đó là cách cơ chế này hoạt động.

**Dòng đăng ký hình dạng "tài nguyên đơn" trong C-API-01** cũng nằm trên nhánh của phiên
khác dù `/api/v1/inventory-summary` đã chạy trên dev từ lâu. Đã cherry-pick về `main`.

**Số ADR:** phiên khác đang giữ 0044-0047 trên nhánh của họ. Số tiếp theo là **0049**.

## Còn lại, theo thứ tự nên làm

**1. Giá vốn — bị CHẶN bởi một câu hỏi nghiệp vụ.** *Xưởng đang dùng phương pháp tính giá
xuất kho nào?* MISA có bốn: bình quân cuối kỳ, bình quân tức thời, FIFO, đích danh; và cho
chọn theo từng kho hoặc chung mọi kho. Tôi giả định **bình quân tức thời, tính theo từng
kho** và bản vẽ dựng theo đó. Đây là **thứ duy nhất trong cả bản thiết kế không sửa được
sau**: đổi phương pháp khi đã có vài nghìn dòng sổ là tính lại toàn bộ giá vốn. Hỏi kế toán
của xưởng trước khi chạm vào đợt này.

Kéo theo hai câu chưa trả lời: **lô và hạn sử dụng** (ảnh hưởng cả FIFO lẫn đích danh), và
**giá vốn khi chuyển kho** (ADR-0048 để mở).

**2. Lệnh sản xuất** — module `production` theo ADR-0017, dù lối vào nằm trong menu Kho vận.
Gắn với đơn hàng, làm theo lệnh.

**3. Tính giá bán theo định mức** — module `sales`.

**4. Tính giá thành thật** — **chưa có chủ module**. ADR-0017 không có `costing`; hai đường
là nhét vào `production` hoặc `accounting`, và thêm module thứ mười ba thì phải sửa ADR-0017.

**Chưa có màn nào:** kiểm kê kho, nhập tồn đầu kỳ, danh mục nhóm hàng.

## Giới hạn đã biết của màn phiếu chuyển

Bảng chín cột đặt `min-width: 1080px` và **cuộn ngang** trong khung của nó. Trên màn rộng
1440px trở lên thì đủ chỗ; dưới đó, cột **Còn lại** — cột cảnh báo vượt tồn — nằm ngoài tầm
nhìn cho tới khi người dùng cuộn. Đã đo trên máy dev ở hai bề rộng. Chữa được bằng cách siết
cột hoặc gộp cặp Tồn/Còn lại, nhưng đó là một quyết định thiết kế chứ không phải một lỗi.

## Việc tiếp theo, đúng một việc

Hỏi kế toán của xưởng **phương pháp tính giá xuất kho**. Mọi thứ còn lại đều làm được ngay,
riêng giá vốn thì làm sai một lần là phải tính lại toàn bộ sổ.
