# Bàn giao — chặng G, module `inventory` và phép đo của sáu chặng hạ tầng

File này nối tiếp [2026-08-14-ban-giao-chuan-bi-chang-g.md](2026-08-14-ban-giao-chuan-bi-chang-g.md).

---

## 0. Câu trả lời, vì cả chặng tồn tại để trả lời đúng một câu

**Module thứ ba tốn bao nhiêu so với module thứ hai?**

Đo bằng `backend-erp/tools/dem-dong.ps1`, chạy cho **cả hai module ở cùng một thời điểm**
(HEAD cuối chặng G) — đó là phép so duy nhất có nghĩa:

| Hạng mục | `machine` | `inventory` | Chênh |
|---|---|---|---|
| backend `src` | 5.081 | **4.870** | **−211** |
| backend `test` | 4.485 | 4.919 | +434 |
| docs module | 1.214 | 1.213 | −1 |
| migration | 377 | 291 | −86 |
| frontend `src` | 2.423 | 4.400 | +1.977 |
| frontend `test` | 1.500 | 2.895 | +1.395 |
| **Tổng / file** | **15.080 / 76** | **18.588 / 103** | +3.508 |

**Con số thô nói `inventory` đắt hơn 23%. Con số đó đọc sai, và đây là cách đọc đúng.**

**Backend của module thứ ba rẻ hơn module thứ hai.** `4.870` so với `5.081` — và nó rẻ hơn
*trong khi mang nhiều hơn*: một endpoint thứ 15 mà `machine` không có, cộng hợp đồng
`Idempotency-Key` đầu tiên của hệ thống. Cộng cả bốn hạng mục backend (`src` + `test` +
docs + migration): 11.293 so với 11.157, tức **+1,2%** — trong sai số của hai module không
bao giờ giống hệt nhau.

**Toàn bộ phần dôi ra nằm ở frontend, và nó là món `machine` còn nợ chứ không phải phần
`inventory` làm thừa.** `machine` có ba màn và cả ba **thiếu đường tạo**; `inventory` có sáu
màn đủ đường tạo. Chuẩn hóa theo màn: `machine` 1.308 dòng/màn, `inventory` **1.216**
dòng/màn. Tính theo màn thì frontend của module thứ ba cũng rẻ hơn một chút.

Ba khoản spec mục 1 khai là không so sánh được (`shared/idempotency`, lệnh `seed-units`,
số màn) thì hai khoản đầu **đã tự nằm ngoài** phép đếm: công cụ đếm theo thư mục module,
mà cả hai đều ở `shared/` và `cmd/`.

**Phép thử thứ hai, và nó nói nhiều hơn con số: mười bảy task đi qua không phải nới một
rule nào.** Không ADR nào được viết để mở đường cho một luật vướng, không checker nào bị
tắt, không mệnh đề nào bị hạ mức — diff của `arch/LEVELS.md` cuối chặng **chỉ có cột FILE
tăng**. Câu hỏi mà chặng này sinh ra để hỏi là *"bộ khung có làm module thứ ba rẻ hơn
không"*; câu trả lời là **có, ở backend**, và bộ khung không phải nhường một bước nào để
đạt được điều đó.

**Cái phép đo này KHÔNG trả lời:** nó đo số dòng, không đo thời gian. Một module rẻ hơn về
dòng vẫn có thể tốn hơn về số lần phải dừng lại hỏi. Chỉ số đó không ai ghi lại được ở
chặng này.

---

## 1. Sáu điều bộ khung để lọt, đo được chứ không đoán

Mỗi mục dưới đây là một chỗ **checker xanh vì không ai nhìn**, không phải xanh vì hợp lệ.
Không mục nào được vá trong chặng này — đó là chỉ thị của plan, và lý do là một vá vội ở
cuối chặng thì không ai còn sức review.

### 1.1 `allowed_deps` không bị đối chiếu ngược — và nó ăn vào R-04

Thêm `auth` vào `allowed_deps` của `inventory` trong khi module có **0** dòng import
`modules/auth` → `arch` xanh, output giống **byte-for-byte** lần chạy nền.

`arch/checks_import.go:phuThuocNgoaiAllowedDeps` chỉ duyệt theo **dòng import** rồi hỏi
ngược *"đích này có tên trong `allowed_deps` không"*. Chiều kia — mỗi tên trong
`allowed_deps` có một dòng import đỡ nó không — **không ai duyệt**. `C-GO-05` vế 4 đối
chiếu hai chiều cho `internal_methods`, không cho `allowed_deps`.

**Đắt hơn một vùng mù thường:** đồ thị phụ thuộc được dựng **từ** `allowed_deps`, nên một
cạnh bịa ra được `chuTrinhHaiNutTrongAllowedDeps` tính như cạnh thật. Một tên thừa vừa
không bị bắt, vừa có thể làm **đỏ oan** một module khác.

### 1.2 `checkR02` bỏ qua hoàn toàn module chưa có `module.yaml`

`if !coKhai { continue }`. Suốt từ G6 tới G10, R-02 **im lặng** với `inventory` — không phải
xanh. Nó chỉ bắt đầu soi từ khi G11 tạo `module.yaml`.

Hệ quả: một module viết xong bốn tầng mà chưa khai `module.yaml` thì mọi câu SQL của nó
không được canh ranh giới, và không có gì báo điều đó.

### 1.3 Comma join không bị bắt

`bangSauTuKhoa` chỉ khớp định danh **ngay sau** `FROM`/`JOIN`, nên `FROM units, machines`
đi lọt. Comment của hàm liệt kê subquery, CTE, tên trong ngoặc kép làm vùng mù đã biết —
**không** có comma join.

### 1.4 `.gitattributes` — họ bẫy thứ tư, và lần này nó ăn một bước nghiệm thu

`arch/README.md` là file sinh ra bởi `go generate`, và bước 7 của nghiệm thu mỗi chặng là
`go generate` rồi `git diff --exit-code`. Trên máy dev Windows, checkout ghi CRLF còn hàm
sinh ghi LF → bước 7 **đỏ trên máy người, xanh trên CI**, `git status` báo file bị sửa
trong khi `git diff` **rỗng**.

Cùng họ với `LEVELS.md`, `RULES-PIN.md`, `*.go` — nhưng ba cái kia bảo vệ một phép so sánh
hoặc một công cụ, còn cái này làm hỏng **một bước nghiệm thu**. **Đã sửa** ở chặng này
(dòng riêng kèm lý do riêng, đúng luật mà chính file đó đặt ra).

### 1.5 Hai nil pointer mà tầng biên dịch không chặn được

`StockItemDeps.UnitRepo` và `MovementDeps.Claimer`. Cả hai chỉ nổ ở **request đầu tiên**,
và cả hai không có test nào ở tầng biên dịch bắt được. Cái thứ hai đáng chú ý hơn:
`cmd/api` **chưa từng** dựng `shared/idempotency` — nó chỉ sống ở `cmd/relay` — nên chặng G
là lần đầu đường idempotency vào tiến trình HTTP.

**Khuôn chung:** mỗi lần một `Deps` mọc thêm một trường, có đúng một chỗ phải nhớ và không
gì nhắc. Chưa có checker cho việc này.

### 1.6 Mốc `14.700` sai hai chỗ

Sáu hạng mục cộng lại ra **14.680** (dấu `~` là làm tròn), và hàng `migration` ghi 375
trong khi đếm lại ra 377. Công cụ khớp **tuyệt đối** 5/6 hạng mục và khớp tuyệt đối 75 file
khi chạy trên đúng cây code sinh ra mốc — nên hai lệch này là sai số của **mốc**.
`pham-vi-he-thong.md` **đã sửa** thành 14.680; hàng `migration` giữ 375 để câu đó tự nhất
quán.

---

## 2. Mười ba thứ chỉ thấy khi dựng thật — bước 5

463 test frontend xanh, toàn bộ backend xanh, và không cái nào thấy những thứ dưới đây.
Số liệu nghiệp vụ thì **đúng cả bốn mốc**: `100 → 70 → 70 → 0`, xuất quá tồn bị `409` và
tồn không đổi.

### 2.1 Nợ của chặng G — tám món

| # | Món | Vì sao đáng |
|---|---|---|
| **A** | **Xóa kho đang có lịch sử chuyển động: không cảnh báo, `204` luôn.** Sau đó dòng tồn biến mất, còn các dòng sổ vẫn trỏ tới một UUID **không tra ra tên ở bất cứ đâu trên màn hình** | Mất dữ liệu đọc được, không cách nào phục hồi qua giao diện |
| **B** | **Sổ chuyển động in UUID thô** ở cột `Kho` và `Vat tu` — `MovementDTO` chỉ mang hai UUID, khác `StockBalanceDTO` vốn có sẵn bốn field mã/tên | Cộng với A thì mã kho mất vĩnh viễn khỏi UI |
| **D** | **Form không có CSS layout** — nhãn, ô nhập và câu gợi ý dính vào nhau: `…se bao loi khi luu.Ten kho` | Thứ 463 test không thể thấy |
| **E** | **Lỗi validate hiện bằng chữ đen** lẫn vào chữ gợi ý, không `role="alert"`. Có `aria-invalid` nên đúng ngữ nghĩa một nửa | Nhìn mắt thường gần như "bấm xong không có phản hồi gì" |
| **F** | Thiếu dấu chấm câu: `Khong du ton kho de thuc hien chuyen dong nay Ton da duoc doc lai.` — backend không kết câu, frontend nối tiếp | Nhỏ, sửa hai dòng |
| **J** | Ngày giờ **en-US** (`mm/dd/yyyy`, `8/15/2026, 10:15:00 AM`), và `Thoi diem xay ra` bắt buộc mà **không mặc định "bây giờ"** — mỗi lần ghi phải gõ tay đủ ngày+giờ | Ma sát trên chính thao tác lặp nhiều nhất của module |
| **K** | Chuỗi lộ ngôn ngữ lập trình viên: `So luong backend luu: 100` | Sai đối tượng đọc |
| **L** | Sau khi lưu, form tạo **giữ nguyên dữ liệu** và nút `Luu` vẫn bấm được → lần bấm thứ hai ăn `409` trùng mã | Đường dẫn thẳng tới một lỗi mà người dùng không hiểu |

### 2.2 Nợ có sẵn của `machine` — năm món, không phải của chặng này

| # | Món |
|---|---|
| **C** | UUID thô ở `Nguoi phu trach` (danh sách + chi tiết máy), và form **Sửa máy** bắt **gõ tay UUID** vào ô text |
| **G** | Trang `Tong quan` in đường dẫn mã nguồn cho người dùng cuối, và câu đó còn lạc hậu — chỉ kể ba màn máy |
| **H** | Tiền hiện `1500000.0000` — không phân cách nghìn, không đơn vị, thừa 4 số lẻ |
| **I** | **Không tạo được máy bằng chuột.** `Danh sach may` không có nút tạo, `ROUTES` không có `/machines/moi`, trong khi backend có `POST /api/v1/machines`. Hệ quả: `/machines/:id` và `/machines/:id/breakdowns` **không tới được bằng chuột** |
| **M** | Daemon `agent-browser` dùng chung treo vô hạn cho tới khi dùng `--namespace` riêng — cảnh báo của bàn giao trước là **thật** |

**Món I là nợ mà bàn giao chặng F mục 3.2 đã ghi, vẫn còn nguyên**, và spec chặng G mục 2
cố ý không nhận nó. Nó có tên ở đây vì mục 0 dùng nó để giải thích chênh lệch số màn — và
vì giờ đã có bằng chứng chạy thật chứ không còn là suy luận từ code.

### 2.3 Ba lần mới dựng được stack

| # | Lệnh | Kết quả |
|---|---|---|
| 1 | `go run ./cmd/dev dev` | ĐỎ — `Bind for 0.0.0.0:5433 failed: port is already allocated` (đúng bẫy `CLAUDE.md` mục 4) |
| 2 | `docker compose -p backend-erp down` rồi chạy lại | ĐỎ — relay chết ngay: `connectex: ... actively refused` |
| 3 | `docker compose -f infra-erp/compose/dev.yml down && up -d postgres` + `migrate-up` + `dev` | XANH |

Bước 2 đáng ghi: lệnh dọn mà `CLAUDE.md` chỉ dẫn **không đủ** — nó gỡ container cũ nhưng
không dựng lại cái mới, và `dev` chạy tiếp trên một cổng chưa ai lắng nghe.

---

## 3. Bốn quyết định chặng này chốt mà spec không nói

### 3.1 `GET /api/v1/units` — endpoint thứ 15, và nó đổi một tiền đề

Spec mục 3.2 nói `seed-units` gỡ chặn "màn hình nhập vật tư đầu tiên", nhưng **không endpoint
nào đọc `units` qua HTTP**. Màn tạo vật tư phải chọn đơn vị tính, nên hôm nay chỉ còn cách
bắt người dùng dán một UUID. Đây là một lỗ hổng thật trong spec, phát hiện lúc viết api
client.

Đã thêm vào chính module `inventory`, **chỉ đọc**, một permission `inventory.unit_list`, và
`units` **không** được thêm vào `tables` của `module.yaml` — nó là `reference_tables`, không
có module chủ.

**Hệ quả cho phép đo, phải đọc kèm mục 0:** bảng của spec chốt `machine` 15 endpoint /
`inventory` 14, và dùng sự bằng nhau đó làm điều kiện để con số có nghĩa — chính lý do
`stock_takes` bị cắt. Giờ là **14 endpoint nghiệp vụ + 1 đọc danh mục**, và `machine` không
có endpoint danh mục nào để đối ứng.

**Điều kiện chuyển đi là một NGƯỜI ĐỌC THỨ HAI, không phải một ngưỡng khối lượng:** ngày
`purchasing` cần đọc `units`, vai trò của nó sẽ phải được cấp `inventory.unit_list` — đọc ra
như một phụ thuộc mà `allowed_deps: []` từ chối.

### 3.2 Mốc kiểm tồn âm là *bây giờ*, không phải `occurred_at`

Bất biến đáng giá nhất là *tồn hiện tại không bao giờ âm* — con số người giữ kho nhìn.
Truyền `occurred_at` bỏ ngỏ đúng bất biến đó: một lệnh xuất lùi ngày lọt qua (lúc ấy trong
quá khứ hàng vẫn còn) nhưng làm tồn hiện tại âm, và nó vỡ **im lặng**.

**Cái không mua được, ghi ra chứ không giấu:** không đường nào bảo đảm sổ không âm ở **mọi**
mốc quá khứ. Bảo đảm đó đòi quét từng điểm của dãy, và chưa ai đòi.

### 3.3 Không tạo `api/dto.go`

Không module nào khai `inventory` trong `allowed_deps` → không có người gọi → không có câu
hỏi nào để một interface trả lời. `StockItemDTO` khai trong package `handler` đúng C-GO-02.
Một `api.StockItemDTO` hôm nay là bản thứ hai của cùng một hình dạng, bản không request nào
chạy qua và không test nào đọc.

**Spec mục 5 vẽ `api/dto.go` trong cây thư mục** — chỗ lệch này chưa sửa vào spec.

### 3.4 Handler không đổi dấu `quantity`

Hợp đồng dây là số **có dấu**: `xuat` phải gửi số âm. Lý do nặng nhất không phải thẩm mỹ:
`request_hash` băm giá trị **sau** biến đổi, nên nếu handler quy `+8` về `-8` thì hai thân
khác nhau cho ra **cùng** một băm — client gửi nhầm dấu, sửa lại, gửi lại với cùng khóa sẽ
nhận **response cũ phát lại** thay vì `422`. Đúng cái kết cục mà hàng 3 của bảng ba ca tồn
tại để chặn.

---

## 4. Hai khoản nợ mới, có tên

**Hai mã lỗi cho một tình huống.** `C-API-05` có sẵn `ERR_INVENTORY_STOCK_NOT_AVAILABLE` từ
trước (dòng ví dụ cho module chưa tồn tại), trùng nghĩa với `ERR_INVENTORY_INSUFFICIENT_STOCK`
mới. Cả hai đều còn; xóa một mã là breaking change theo C-API-06. Phải chốt trước khi có
người gọi thứ hai.

**Phép chuẩn hóa JSON + băm nằm ở `movement_service.go`.** Nó chỉ đúng cho hình dạng thân
của đúng một endpoint. Ngày có endpoint thứ hai vào bảng 5, hai bản chuẩn hóa khác nhau sẽ
cho hai `request_hash` khác nhau cho cùng một thân — chính khoản nợ mà ADR-0018 giao cho
"chặng nào thêm endpoint thứ hai".

**Nhánh `ErrKhongDocDuocKhoa` chưa có test.** Hai transaction song song cùng khóa, một chưa
commit. Dựng nó cần hai kết nối và dễ thành test chập chờn — cố ý không thêm.

**Nợ `relay` già thêm một chặng.** `cmd/relay` vẫn im lặng hoàn toàn khi chết, và nay có
thêm một module nữa chạy trên nó.

---

## 5. Đề nghị cho chặng H

**Đừng bắt đầu từ `purchasing` ngay.** Ba việc rẻ hơn nhiều nếu làm trước, và cả ba đều do
chặng này đo được:

1. **Tám món ở mục 2.1** — phần lớn là vài dòng mỗi món, và chúng nằm trên đúng lát cắt mà
   người dùng thật sẽ bấm đầu tiên. Món **A** và **B** nên đi cùng nhau: thêm mã/tên vào
   `MovementDTO` và chặn (hoặc cảnh báo) khi xóa kho còn lịch sử.
2. **Món I** — nợ của `machine` từ chặng F, giờ đã có bằng chứng chạy thật. Nó là bằng
   chứng rằng "route tồn tại + test route xanh" **không** kết luận được gì về việc người
   dùng tới được hay không.
3. **Vá 1.1 và 1.2** — hai vùng mù của checker. Chúng rẻ để vá lúc chưa có module nào dựa
   vào chúng, và đắt dần theo mỗi module mới.

Còn `document_counters` thì vẫn đúng hạn: ADR của nó phải xong **trước chặng H**
(bàn giao chuẩn bị mục 3.2), và chặng G không đụng tới vì `stock_movements` cố ý không có
cột `code`.
