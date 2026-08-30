# Bàn giao — Kho vận v3: phiếu, chuyển kho, giá vốn (rc.82 → rc.87)

Ngày: 2026-08-30. Bản vẽ: `99-meta/mockups/kho-van-v3.html`.
ADR mới trong đợt: **ADR-0048** (phiếu chuyển kho).

## Đã chạy thật trên `http://103.179.172.110/`, kiểm bằng `qa-thukho`

| rc | Nội dung | Bằng chứng trên máy thật |
|---|---|---|
| 82 | Màn phiếu nhập/xuất, sổ phiếu, danh mục đối tác, thanh điều hướng chia nhóm | Ghi `PN-2026-0002` qua giao diện, 2 dòng vào sổ, số kế tiếp tự nhảy |
| 83 | Ba lỗi giao diện của bảng dòng phiếu | Chụp lại màn: hàng cao một dòng, hai nút biểu tượng hiện rõ |
| 84 | Phiếu chuyển kho — backend + màn | Ghi `PC-2026-0001`: kho A `1350 → 1320`, kho B `0 → 30` |
| 85 | Cột Loại cho bảng dòng của phiếu chuyển | Bảng chi tiết `PC-2026-0001` hiện `Nhập kho` / `Xuất kho` |
| 86 | **Giá vốn** — bình quân tức thời theo từng kho (ADR-0049) | Nhập 100x18.000 + 100x22.000, xuất 150 → đơn giá **20.000**, thành tiền **3.000.000**, tồn 50 = **1.000.000**; cộng lại đúng 4.000.000 đã chi |
| 87 | Cảnh báo ghi ngày tương lai | Ghi một phiếu năm 2027 → `201` kèm `CANH_BAO_GHI_NGAY_TUONG_LAI` |

Migration trên dev đã ở **42**. `ck_stock_vouchers_kind` nhận đủ ba giá trị; `stock_movements`
có `don_gia` và `thanh_tien`.

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

## Giá vốn — đã xong, và câu chặn đã được trả lời

Chủ xưởng trả lời: *"tính giá xuất kho bằng cách lấy giá nhập của đợt gần nhất"*. Tra MISA và
Thông tư 200 trước khi làm cho thấy cách đó **không nằm trong ba nhóm được chấp nhận**, và lý do
bác bỏ không phải lệch chuẩn mà là **sổ không tự cân** — ví dụ bằng số nằm trong ADR-0049.

Ý người dùng vẫn đúng ở một chỗ khác, và họ đã chọn phương án tách hai con số:

- **Giá vốn trên sổ** = bình quân tức thời, theo **từng kho**.
- **Giá nhập gần nhất** = một con số riêng, hiện ở màn vật tư, dùng để **báo giá bán**.

Ba giới hạn đã biết, ghi trong ADR-0049: không truy được lô; cùng một mặt hàng có hai giá vốn ở
hai kho; và **phiếu lùi ngày cho ra giá sai** cho tới khi có đường tính lại hàng loạt (MISA gọi
là *Tính giá xuất kho*).

### Một lỗ im lặng đo được ở rc.86, đã bịt ở rc.87

`/stock-balances` đọc tồn "tính đến **bây giờ**", còn phép kiểm tồn và phép tính giá vốn dùng
**toàn bộ lịch sử**. Một tờ phiếu gõ nhầm năm vào sổ bình thường, tính vào giá vốn bình thường,
nhưng màn Tồn kho **không đổi một số nào** — trông y hệt một lần ghi thất bại, và người dùng sẽ
gõ lại nó lần thứ hai. Nay có `CANH_BAO_GHI_NGAY_TUONG_LAI`.

Đây là loại lỗi khó nhất của đợt: **cả hai đường đều đúng theo cách hiểu của chính nó**, và chỗ
lệch chỉ lộ ra khi so hai màn với nhau.

## Còn lại, theo thứ tự nên làm

**1. Tính lại giá xuất kho hàng loạt** — gỡ giới hạn phiếu lùi ngày của ADR-0049 mục 7.

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

**Lệnh sản xuất** (module `production`). Đó là mắt xích còn thiếu giữa kho và bán hàng: có lệnh
thì mới nói được một sản phẩm ăn hết bao nhiêu nguyên liệu, và có con số đó thì hai màn tính giá
mới có đầu vào thật thay vì một bảng gõ tay.
