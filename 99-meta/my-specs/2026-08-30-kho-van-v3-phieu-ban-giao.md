# Bàn giao — Kho vận v3: phiếu, chuyển kho, giá vốn, sản xuất (rc.82 → rc.90)

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
| 88 | **Module `production`** — định mức NVL và lệnh sản xuất (ADR-0050) | Định mức 12 kg/cái x 10 cái = **120 kg** tự điền; hai thành phẩm ra **hai bảng riêng** (120 và 225, không cộng thành 345); sửa định mức gốc 7,5 → 99 mà lệnh cũ vẫn 225 |
| 89 | Sinh phiếu từ lệnh và tính giá thành | NVL 2.400.000 + chi phí 1.100.000 = **3.500.000** vào kho thành phẩm; kho A còn 80 kg = 1.600.000; giá vốn thành phẩm **350.000/cái** |
| 90 | Thẻ Giá thành và hai đường sinh phiếu trên màn lệnh | Xuất thêm 10 kg **sau khi** đã nhập kho → `CANH_BAO_XUAT_SAU_KHI_NHAP_KHO`, tiền nằm ở "Chưa ai gánh 200.000", giá thành đã chốt **không đổi**; sửa lệnh đã sinh phiếu → `409` |

Migration trên dev đã ở **44**. `stock_movements` có `don_gia`/`thanh_tien`; module `production`
có `bom_lines`, `production_orders` (hai tầng dòng) và `production_order_vouchers`.

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

**Ba con số phiên sau phải lấy đúng, và cả ba đều có bẫy:**

| | Số tiếp theo | Bẫy |
|---|---|---|
| ADR | **0051** | Phiên khác giữ **0044-0047** trên nhánh chưa merge của họ. Đợt này đã dùng 0048, 0049, 0050. Đếm bằng `ls 03-decisions/` trên `main` sẽ ra số đã có người giữ |
| Migration | **000045** | **Đừng** đọc bằng `ls migrations/` trong cây dùng chung `d:/My project web/erp/backend-erp` - cây đó đứng trên nhánh của phiên khác và từng làm dev hỏng vì chuyện này. Đọc bằng `git show origin/main` hoặc trong một worktree riêng |
| rc | **91** | Tag trên **cả ba** repo: `backend-erp`, `frontend-erp`, `infra-erp` |

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

## Sản xuất — đã xong cả năm mục của ADR-0050

**Định mức khai ngay trên chính thành phẩm**, đúng MISA: mở danh mục vật tư, chọn Tính chất =
Thành phẩm, và tab Định mức hiện ra. Số lượng là cho **MỘT** đơn vị thành phẩm.

**Một lệnh có nhiều thành phẩm, mỗi thành phẩm mang bảng định mức RIÊNG.** Chủ xưởng bác bỏ
phương án gộp ở vòng hỏi đầu và họ đúng: gộp thì xuất thừa 20 kg thép không câu nào nói cổng hay
khung ăn thêm, và giá thành không tách được cho từng sản phẩm. Tài liệu công khai của MISA không
vẽ rõ chỗ này — ADR-0050 mục 2 ghi rõ nó dựa trên suy luận chứ không trích dẫn được.

**Giá thành theo phương pháp giản đơn của MISA:** chi phí NVL + chi phí nhân công + chi phí
chung, phân bổ theo **tỷ lệ chi phí NVL**. Hai ô chi phí gõ bằng **số tiền thật**, không phải phần
trăm. Bất biến đã kiểm trên máy thật: *tiền rời kho NVL + tiền chi phí = tiền vào kho thành phẩm*.

### Ba ca biên, cả ba nói ra thay vì im lặng

| Ca | Cách xử |
|---|---|
| Chưa xuất NVL mà đã nhập kho (mẫu số phân bổ bằng 0) | Chia **đều**, kèm `CANH_BAO_PHAN_BO_CHIA_DEU` |
| Nhập kho nhiều lần | Lô đầu hấp thụ toàn bộ chi phí; lô sau đơn giá 0 kèm `CANH_BAO_GIA_THANH_BANG_KHONG`, cách chữa nằm trong chính câu chữ |
| Xuất thêm **sau khi** đã nhập kho | Giá thành đã chốt **không tính lại** (tiền lệ ADR-0049 mục 7); tiền nằm ở "Chưa ai gánh" |

**Lệnh đã sinh phiếu thì không sửa và không xoá được** (`ERR_PRODUCTION_ORDER_HAS_VOUCHER`).
Đường sửa thay cả cây và cấp id mới cho mọi dòng thành phẩm, mà chi phí neo vào chính id cũ.

### Hai giới hạn của đợt sản xuất

1. **Không có đánh giá dở dang.** Giữa lúc xuất NVL và lúc nhập kho thành phẩm, giá trị nguyên
   liệu đã rời kho mà chưa thành gì cả. Chấp nhận được với lệnh xong trong vài ngày; sai khi một
   lệnh kéo qua kỳ báo cáo.
2. **Hai transaction khi sinh phiếu.** `inventory` commit tờ phiếu trước, `production` ghi mối
   nối sau. Sập nguồn đúng giữa hai bước để lại phiếu mồ côi; vá bằng `Idempotency-Key` bắt buộc
   và `ON CONFLICT DO NOTHING`, nên bấm lại nút là tự lành.

## Còn lại, theo thứ tự nên làm

**1. Tính lại giá xuất kho hàng loạt** — gỡ giới hạn phiếu lùi ngày của ADR-0049 mục 7.

**2. Tính giá bán theo định mức** — module `sales`. Nay đã có đầu vào thật: định mức nguyên
liệu và giá mua gần nhất.

**3. Đánh giá dở dang** và **lệnh sản xuất gắn với đơn hàng** — cả hai chờ `sales` có đơn hàng.

**Chưa có màn nào:** kiểm kê kho, nhập tồn đầu kỳ, danh mục nhóm hàng.

## Giới hạn đã biết của màn phiếu chuyển

Bảng chín cột đặt `min-width: 1080px` và **cuộn ngang** trong khung của nó. Trên màn rộng
1440px trở lên thì đủ chỗ; dưới đó, cột **Còn lại** — cột cảnh báo vượt tồn — nằm ngoài tầm
nhìn cho tới khi người dùng cuộn. Đã đo trên máy dev ở hai bề rộng. Chữa được bằng cách siết
cột hoặc gộp cặp Tồn/Còn lại, nhưng đó là một quyết định thiết kế chứ không phải một lỗi.

## Việc tiếp theo, đúng một việc

**Tính giá bán theo định mức** (module `sales`). Mắt xích cuối của chuỗi: nay đã có định mức
nguyên liệu, giá vốn, giá thành và giá mua gần nhất — bảng tính giá bán cuối cùng có đầu vào thật
thay vì những con số gõ tay.
