# Khuôn màn hình

Năm khuôn, không phải bốn — và **khuôn thứ năm không phải lời mời đẻ thêm khuôn**. Bốn
khuôn gốc (Danh sách, Form, Chi tiết, Tổng quan) đứng vững suốt cả hệ; khuôn thứ năm chỉ
ra đời khi một màn **thật, đã dựng** — trang chủ ứng dụng, vẽ sơ đồ quy trình nghiệp vụ —
không chỉ số, không việc cần làm, không cách nào ép vào bốn khuôn kia mà không nói dối về
hình dạng của nó. Nếu một màn không rơi vào khuôn nào, gần như chắc chắn nó đang làm hai
việc và nên tách làm hai màn; chỉ khi điều đó sai — màn chỉ làm một việc, và việc đó thật
sự không giống năm khuôn hiện có — thì mới thêm khuôn thứ sáu, viết luật riêng cho nó như
năm khuôn dưới đây, chứ không lách bằng cách gọi nó là biến thể của một khuôn cũ.

Sự nhàm chán ở đây là tính năng, không phải sự lười. Người dùng mở cùng vài màn hàng trăm
lần mỗi tuần; giá trị nằm ở chỗ họ **không phải học lại** bố cục mỗi lần có màn mới.

## Mục lục

0. [Khối bố cục dùng chung](#0-khối-bố-cục-dùng-chung)
1. [Vỏ ứng dụng](#1-vỏ-ứng-dụng)
2. [Khuôn A — Danh sách](#2-khuôn-a--danh-sách)
3. [Khuôn B — Form](#3-khuôn-b--form)
4. [Khuôn C — Chi tiết](#4-khuôn-c--chi-tiết)
5. [Khuôn D — Tổng quan](#5-khuôn-d--tổng-quan)
6. [Khuôn E — Trang chủ ứng dụng](#6-khuôn-e--trang-chủ-ứng-dụng)
7. [Màn hẹp](#7-màn-hẹp)

---

## 0. Khối bố cục dùng chung

Bảy khối dưới đây đứng **trước** năm khuôn, vì chúng là vật liệu mà cả năm khuôn ráp từ đó.
Chúng được rút ra ngày 2026-08-24 sau khi đặt màn Phân quyền đang chạy cạnh một màn ERP
thương mại và đo từng chỗ lệch: bảng màu không có lỗi, **toàn bộ khoảng cách nằm ở bố cục**.

Bản đối chứng dựng bằng HTML tĩnh ở `mockup-erp/bo-cuc-v2.css` — nó `<link>` thẳng vào
`tokens.css` và `co-so.css` thật, đúng để chứng minh rằng không cần đổi một mã màu nào.

### 0.1 Dải đầu trang

Thứ hay thiếu nhất, và thiếu nó thì mọi màn mở ra bằng khoảng trống.

```
┌──────────────────────────────────────────────────────────────┐
│ [::] Danh sach kho              [Xuat Excel] [+ Tao kho moi] │ ~56px
└──────────────────────────────────────────────────────────────┘
```

- Một thẻ có nền `--mau-nen-noi` và viền 1px. **Không phải một hàng flex trần.** Tiêu đề cần
  một mặt phẳng để đứng; không có nó thì tiêu đề và nút trôi trên nền trang.
- **Hành động chính neo phải, và luôn ở đúng chỗ đó ở mọi màn.** Nó là `<button>` hoặc một
  `<a>` được tạo dáng như nút — **không bao giờ là một dòng chữ link**. Người dùng ERP mở
  cùng một màn hàng trăm lần; giá trị nằm ở chỗ nút Tạo không đổi vị trí.
- **Không mang nhãn phụ.** Tên ứng dụng và mã phân vùng đã nằm ở thanh đầu trang — nhắc lại
  ngay dưới nó là tốn một dòng để nói thứ mắt vừa đọc xong.
- **Mang được một dòng dữ liệu ngắn**, và chỉ thế: tổng số bản ghi (`12 kho trong công ty
  này`), nhãn trạng thái đứng cạnh tiêu đề. Đó là dữ liệu sống, người dùng đọc lại mỗi lần
  mở màn.
- **Không mang câu giải thích nghiệp vụ.** *"Kho là nơi ghi tồn. Mỗi chuyển động nhập, xuất
  hay chuyển đều phải trỏ vào một kho có thật..."* là câu dạy nghề: đọc đúng một lần rồi
  không bao giờ đọc nữa, nhưng chiếm chỗ ở mọi lần mở màn. **Chỗ của lời giải thích là màn
  rỗng** — đúng lúc người ta chưa biết phải làm gì.

  **Ngoại lệ, và nó có thật:** một câu **chống hiểu nhầm về chính dữ liệu đang hiện** thì
  không được đẩy xuống màn rỗng, vì hiểu nhầm ấy xảy ra đúng lúc người ta đang nhìn thấy số.
  Ví dụ có thật ở màn Tồn kho: *"Tồn là số dư tính từ sổ chuyển động, không phải một ô có
  thể sửa"* — người dùng nhìn con số 92 và tưởng bấm vào sửa được.

  Nhưng nó vẫn **không nằm trong dải đầu**: nó không nói về tên màn, nó nói về cột số trong
  bảng. Chỗ đúng là một dòng ghi chú **ngay trên bảng**, nền tô nhạt, cỡ `--chu-sm`. Đặt
  ngoài mọi nhánh lỗi nếu nó mang đường ra duy nhất của màn. Cách này giữ dải đầu ở 74px mà
  không mất câu nào — trước đó nó đẩy dải đầu của màn Tồn kho lên 93px.

  Phép thử để phân biệt hai ca: câu này trả lời *"màn này là gì"* (→ màn rỗng) hay *"con số
  tôi đang nhìn nghĩa là gì"* (→ ghi chú trên bảng)?
- Chiều cao đo thật trên `TieuDeTrang` sau khi sửa (kể cả viền): **74px** khi có dòng dữ
  liệu, **51px** khi không có. Ngưỡng để soi là **80px**. Bản cũ mang nhãn phụ + đoạn giải
  thích ba dòng cao 140px, và phần chênh lệch đó đẩy bảng xuống dưới nếp gấp.
- Cỡ tiêu đề `--chu-xl`, không phải `--chu-2xl`: một tiêu đề 24px trong một dải cao 64px thì
  chạm hai mép. Nó vẫn là chữ đậm nhất trên nền nổi nhất ở góc trên trái, nên không mất vai
  trò.

### 0.2 Dải tab

```
( Ma tran quyen )  ( Nhan su  7 )  ( Pham vi kho  2 )
```

- Chỉ dùng khi các mặt **thuộc cùng một đối tượng**. Ba màn không liên quan nhét vào ba tab
  là điều hướng trá hình — chỗ của chúng là thanh bên.
- **Số đếm trong tab là bắt buộc khi đếm được**: nó trả lời "mặt kia có gì không" mà không
  bắt bấm vào mới biết. Đây là chỗ *đúng* của một con số đếm.
- Tab đang chọn: nền `--mau-chinh` + chữ `--mau-chu-nhat`. Hai kênh, không chỉ mỗi màu.

### 0.3 Băng chọn ngữ cảnh

Một hàng thẻ ngang để chọn "đang thao tác trên ai / cái gì".

- Dùng khi có **4 tới 10 lựa chọn**. Dưới 4 thì thừa; trên 10 thì thành một bức tường, lúc
  đó dùng ô tìm kiếm.
- Hơn hẳn một `<select>` ở chỗ: đọc được cả danh sách trong một cái liếc, và **vẫn nói được
  ai đang được chọn khi mắt rời khỏi ô**.

### 0.4 Thẻ ngữ cảnh

Thẻ nói rõ đang thao tác trên bản ghi nào: ảnh đại diện, tên, nhãn trạng thái, các mẩu phụ
ngăn bằng dấu chấm giữa.

- **Bắt buộc khi bên dưới là một bảng dài.** Cuộn xuống giữa 48 hàng quyền mà không còn gì
  trên màn trả lời "đang sửa quyền của ai" là một lỗi thật.

### 0.5 Nhóm gập được

Thẻ có đầu thẻ mang: nút gập, biểu tượng, tên nhóm, nhãn, và **hàng nút mẫu nhanh bên phải**.

- Dùng khi bảng vượt **quá 20 hàng và các hàng chia thành nhóm tự nhiên**. Đổ 48 hàng ra một
  bảng phẳng là bắt người dùng tự nhóm bằng mắt.
- **Hàng nút mẫu nhanh** ("Toàn quyền", "Nghiệp vụ", "Chỉ xem", "Khoá hết") đặt cả nhóm về
  một trạng thái quen thuộc bằng một cú bấm, thay vì tick hai mươi ô.

### 0.6 Ô bảng hai dòng

```
Danh sach kho  KHO_LIST
Xem va tao kho trong phan vung
```

- Dòng trên: tên + mã. Dòng dưới: `--chu-xs`, `--mau-chu-mo`, một câu ngắn.
- **Đây là chỗ mật độ thật sự đến từ.** Cùng chiều cao hàng, ba mẩu thông tin thay vì một.
  Bảng một dòng để phí nửa chiều cao hàng làm khoảng trắng.
- Đừng dùng cho cột nào cũng vậy — **đúng một cột mỗi bảng**, thường là cột danh tính.

### 0.7 Dải chỉ số

- **Chỉ dựng khi gọi tên được từng con số và mỗi con số lấy từ một endpoint đã có.** Không
  gọi tên được thì đó là trang trí đội lốt thông tin, và nó đẩy bảng xuống 90px.
- **Không lặp lại một con số đã hiện ở chỗ khác.** Một huy hiệu "6 chờ duyệt" ở thanh bên và
  một ô "Chuyển động chờ duyệt 6" ở dải chỉ số là hai chỗ nói cùng một điều — bỏ một.

### 0.8 Ba lỗi bố cục hay gặp, và cách chữa

| Lỗi | Dấu hiệu | Chữa |
|---|---|---|
| Bảng cột nhảy chỗ | Sang trang 2 các cột rộng khác đi | `table-layout: fixed` + `width` trên mọi `<th>` |
| Ô địa chỉ kéo cao cả hàng | Một ô tự xuống bốn dòng | `white-space: nowrap` + `text-overflow: ellipsis` |
| Nút thao tác đứng lơ lửng giữa màn | Cột cuối canh trái | `text-align: right` trên cột thao tác |

Con số đếm **ở thanh điều hướng bên** thì ngược lại với ở tab: chỉ giữ khi nó là **việc cần
làm** (số chờ duyệt, số quá hạn), và lúc đó hiện thành huy hiệu có màu. Tổng số bản ghi thì
bỏ — người dùng không cần biết có bao nhiêu kho trước khi bấm vào, và mỗi con số như vậy là
thêm một lượt gọi API cho mọi lần tải trang.

## 1. Vỏ ứng dụng

```
┌────────────┬──────────────────────────────────────────────────┐
│  ERP       │  [tim kiem]              Nguyen Van A  [Dang xuat]│ 56px
├────────────┼──────────────────────────────────────────────────┤
│ Tong quan  │                                                  │
│            │                                                  │
│ KHO VAN    │              vung noi dung                       │
│  Kho       │              (toi da 1440px)                     │
│  Vat tu    │                                                  │
│  Ton kho   │                                                  │
│  Chuyen dg │                                                  │
│            │                                                  │
│ THIET BI   │                                                  │
│  May moc   │                                                  │
└────────────┴──────────────────────────────────────────────────┘
    240px
```

Hiện tại `AppLayout` để điều hướng nằm ngang trên thanh đầu trang. Đó là lựa chọn đúng lúc
có hai mục, và **sai dần** khi có nhiều hơn năm: hàng ngang không nhóm được, không hiện
được mục con, và hết chỗ trước cả module thứ tư. Hệ này đã có 12 module trong kế hoạch
(ADR-0017), nên **thanh điều hướng dọc bên trái** là hình dạng đúng.

Bốn luật của vỏ:

- **Mục điều hướng nhóm theo miền nghiệp vụ**, tiêu đề nhóm cỡ `--chu-xs`, chữ hoa,
  `--mau-chu-mo`. Nhóm phản ánh cách người dùng nghĩ về công việc, không phản ánh cây thư
  mục của repo.
- **Mục đang mở được đánh dấu bằng hai kênh**: nền `--mau-chinh-nhat` **và** một dải
  `--mau-chinh` 3px bên trái. Chỉ đổi nền là không đủ với mắt kém phân biệt màu.
- **Không ẩn mục theo role.** `allowed_actions` chưa tồn tại ở backend, và C-TS-06 nói rõ
  đường hợp lệ là để đường dẫn hiện rồi xử lý `403` tử tế tại màn đến. Ẩn link theo role là
  **đoán** — thứ bị cấm không phải là "không biết", mà là "đoán".
- **Mục điều hướng là `<a href>` thật** (`router/Link.tsx`), không phải `<button>`: mở tab
  mới, copy địa chỉ và nút Back đều phải chạy. Nút "Đăng xuất" thì đúng là `<button>` — nó
  làm một *việc*, không dẫn tới một địa chỉ.

Chỉ những màn **điểm đầu** mới có mặt trên thanh điều hướng. Màn đi sau một danh sách
(`/kho/moi`, `/vat-tu/:id`) tới được từ chính danh sách đó; thêm chúng vào thanh là làm nó
dài ra mà không trả lời thêm câu nào.

## 2. Khuôn A — Danh sách

Khuôn dùng nhiều nhất: `/kho`, `/vat-tu`, `/ton-kho`, `/machines`.

```
┌──────────────────────────────────────────────────────────────┐
│ [::] Danh sach vat tu                     [+ Tao vat tu moi] │  dai dau trang (0.1)
└──────────────────────────────────────────────────────────────┘
┌──────────────────────────────────────────────────────────────┐
│ [Don vi tinh v] [Sap xep v] [So dong v]        Xoa loc (2)   │  ThanhLoc
├──────────────────────────────────────────────────────────────┤
│ MA        TEN                    DON VI TINH      THAO TAC   │  Bang
│ ┌───────┐                                                    │
│ │VT-001 │ Thep tam 3mm           KG              Sua  Xoa    │
│ └───────┘                                                    │
│ │VT-002 │ Bulong M12             CAI             Sua  Xoa    │
├──────────────────────────────────────────────────────────────┤
│ Hien 1-20 trong 137            [<] Trang 1/7 [>]   20 dong v │  PhanTrang
└──────────────────────────────────────────────────────────────┘
```

Luật riêng của khuôn này:

- **Đường tạo mới có mặt ở hai chỗ**: nút chính ở đầu trang, và trong màn rỗng. Chỉ có một
  chỗ thì một trong hai ca sẽ thành ngõ cụt.
- **Cột mã là cột đầu tiên và là link sang chi tiết.** Không thêm một cột "Xem" riêng —
  nó chiếm chỗ để nói lại thứ cột mã đã nói.
- **Cột thao tác ở cuối, canh phải, nút kiểu `mo`.** Nhiều hơn hai thao tác thì gom vào
  một menu; một dòng bảng có bốn nút là một dòng không đọc được.
- **Số dòng nằm cạnh phân trang**, và giá trị của nó đi vào URL như mọi bộ lọc khác.
- **Bảng chiếm hết chiều ngang.** Đây là chỗ duy nhất trong hệ không có trần độ rộng: giá
  trị của bảng là số cột nhìn thấy cùng lúc.
- **Bảng dùng `table-layout: fixed`, mọi `<th>` khai `width`.** Bố cục tự động cho ra chiều
  rộng cột thay đổi theo dữ liệu của từng trang — nghĩa là cùng một bảng, sang trang 2 các
  cột nhảy chỗ. Người dùng ERP đọc bảng bằng vị trí cột, nên cột nhảy chỗ là lỗi thật.
- **Đúng một cột dùng ô hai dòng** (mục 0.6), thường là cột danh tính. Đó là chỗ mật độ đến
  từ; các cột còn lại một dòng, cắt bằng dấu ba chấm.
- **Thanh lọc không trải các ô ra hết chiều ngang.** Cho mỗi ô một chiều rộng riêng và để
  chúng đứng cạnh nhau; chỉ thứ **thật sự thuộc về phải** mới đẩy sang phải. Hai ô nhập trải
  trên một băng 1200px với 700px trống ở giữa là lỗi bố cục hay gặp nhất của khuôn này.

Đếm tổng lấy từ `meta.total`, và nó phải nói rõ đang đếm cái gì khi có bộ lọc: `137 vat tu`
với `12 vat tu khop bo loc` là hai câu khác nhau. Chỗ của nó là **chân bảng**, cạnh phân
trang — không phải một dòng mô tả dưới tiêu đề, vì dải đầu trang không mang câu mô tả (0.1).

## 3. Khuôn B — Form

`/kho/moi`, `/vat-tu/:id`, `/chuyen-dong/moi`.

```
┌──────────────────────────────────────────────────────────────┐
│ Kho / Tao kho moi                                            │  duong dan
│ Tao kho moi                                                  │
├──────────────────────────────────────────────────────────────┤
│ ┌──────────────────────────────────────────┐                 │
│ │ ⚠ Ma kho da ton tai, chon ma khac        │                 │  BangThongBao
│ │   ma tra cuu: 01HX...                    │                 │  (chi khi co loi)
│ └──────────────────────────────────────────┘                 │
│                                                              │
│ Ma kho *                                                     │
│ [KHO-01                                  ]                   │
│ Toi da 32 ky tu, khong dau cach                              │  goiY
│                                                              │
│ Ten kho *                                                    │
│ [                                        ]                   │
│ ⚠ Ten kho khong duoc de trong                                │  loi cua o
│                                                              │
│                          640px                               │
├──────────────────────────────────────────────────────────────┤
│                                     [Huy]  [Luu kho]         │  chan dinh
└──────────────────────────────────────────────────────────────┘
```

- **Một cột, rộng 640px** (`--rong-form`). Form hai cột làm mắt phải quyết định đọc theo
  chiều nào, và luôn vỡ trên màn hẹp. Ngoại lệ duy nhất là hai ô thật sự thuộc một cặp
  (từ ngày / đến ngày).
- **Chân trang dính đáy màn**, nút chính bên phải cùng. Form dài mà nút Lưu nằm dưới cùng
  nghĩa là phải cuộn hết mới lưu được.
- **Chữ trên nút Lưu nói ra đối tượng**: `Luu kho`, không phải `Gui`. Và tên đó không đổi
  suốt luồng — nút "Lưu kho" thì thông báo sau đó là "Đã lưu kho".
- **Ô nhập không tự khóa theo nghiệp vụ.** Không có `NEXT_STATUSES` ở frontend (R-19,
  C-TS-05). Ô nào backend không cho sửa thì backend trả `422`, và màn hình hiện lỗi đó.
- **Tạm tính hiển thị được, nhưng không đi vào body request.** Đây là vế dễ vi phạm nhất
  của R-19 vì nó trông rất tiện: người nhập cần thấy tiền ngay khi gõ số lượng, nên hiện nó
  là đúng — nhưng con số gửi lên phải là **đầu vào thô**, và con số hiện sau khi lưu là con
  số **backend trả về**.
- **`Idempotency-Key` sinh lúc mở form**, không phải lúc bấm nút (C-TS-05).

### Ca riêng: màn ngoài vỏ ứng dụng

Màn đăng nhập là khuôn B, chỉ khác một điều: **nó nằm ngoài vỏ** — người chưa đăng nhập
thì không có thanh điều hướng nào để hiện. Thẻ 400px căn giữa trên nền trang, không có
đầu trang, không có đường dẫn.

Ba trạng thái của khuôn B đọc lại khác đi ở màn này, và cả ba đều dễ bị bỏ sót:

- **"Đang tải lần đầu" là lúc đang kiểm tra phiên** (`status: 'checking'` trong
  `session.ts`). Vẽ form trong khoảng đó là đẩy người dùng ra khỏi phiên của chính họ mỗi
  lần bấm F5. Khung xương giữ đúng chiều cao của form nên màn hình không nhảy khi câu trả
  lời về.
- **"Rỗng" không tồn tại** — form không đọc danh sách nào. Đừng bịa ra một trạng thái để
  cho đủ năm.
- **`401` ở đây là "sai mật khẩu", không phải "hết phiên"**, nên nó ở lại trên form dưới
  dạng một dòng chữ và **không kèm mã tra cứu**: gõ sai mật khẩu không phải sự cố hệ thống
  để tổng đài tra cứu. Đây là ngoại lệ duy nhất của luật "mọi banner lỗi mang mã tra cứu".

Bản mockup đầy đủ năm trạng thái của màn đăng nhập đã mất cùng thư mục `mockup-erp` cũ,
và không dựng lại. Màn đăng nhập đang chạy là nguồn sự thật cho năm trạng thái này.

Sau khi lưu thành công: điều hướng về màn danh sách kèm một `BangThongBao` loại `tot`, hoặc
ở lại màn chi tiết nếu người dùng còn việc phải làm tiếp. Chọn cái nào thì cả module theo
một lối — trộn hai lối là bắt người dùng đoán mỗi lần.

## 4. Khuôn C — Chi tiết

```
┌──────────────────────────────────────────────────────────────┐
│ Vat tu / VT-001                                              │
│ ┌───────┐                                                    │
│ │VT-001 │ Thep tam 3mm            ● Dang dung                │  ma + trang thai
│ └───────┘                                     [Sua]  [Xoa]   │
├──────────────────────────────────────────────────────────────┤
│ THONG TIN CHUNG                                              │
│ Don vi tinh    KG                                            │
│ Ngay tao       14/08/2026 09:12                              │
│ Nguoi tao      Nguyen Van A                                  │
├──────────────────────────────────────────────────────────────┤
│ TON KHO THEO KHO                                             │
│ (bang)                                                       │
└──────────────────────────────────────────────────────────────┘
```

- **Mã và trạng thái đứng cạnh nhau ở đầu trang.** Đó là hai thứ người dùng kiểm tra đầu
  tiên khi mở một bản ghi.
- **Khối thông tin dùng `<dl>`**, hai cột nhãn/giá trị (mẫu `.ho-so` đã có sẵn trong
  `app.css`). Nhãn `--mau-chu-mo` cỡ `--chu-sm`, giá trị `--mau-chu`.
- **Không hiện field rỗng bằng một ô trống.** Ô trống đọc y hệt "chưa điền", và trong ERP
  hai trạng thái đó khác nhau. `StockItemListPage` đã làm đúng: đơn vị tính bị xóa mềm hiện
  thành **một dòng chữ** ("Don vi tinh da bi xoa"), không phải một ô trống.
- **Ngày giờ theo `dd/MM/yyyy HH:mm`**, múi giờ máy người dùng. Ngày thuần thì không kèm
  giờ — `14/08/2026 00:00` là một câu nói dối nhỏ về độ chính xác.
- **Thao tác trên bản ghi bám `allowed_actions`**, và nút bị khóa mang `lyDoKhoa`.

## 5. Khuôn D — Tổng quan

Màn `/`. Khuôn ít dùng nhất và dễ làm hỏng nhất, vì nó mời gọi trang trí.

```
┌──────────────────────────────────────────────────────────────┐
│ Tong quan                                    Hom nay, 15/08  │
├───────────────┬───────────────┬───────────────┬──────────────┤
│ Vat tu        │ Kho           │ Chuyen dong   │ May dang chay│
│ 137           │ 4             │ 28            │ 6/8          │
│ hom nay +3    │               │ trong 7 ngay  │              │
├───────────────┴───────────────┴───────────────┴──────────────┤
│ VIEC CAN LAM                                                 │
│ • 3 vat tu duoi muc ton toi thieu          -> Xem            │
│ • 1 chuyen dong cho duyet                  -> Xem            │
└──────────────────────────────────────────────────────────────┘
```

- **Mỗi chỉ số phải dẫn tới một hành động.** Một con số không bấm được là một con số không
  ai dùng. Bấm vào ô "137 vật tư" phải sang `/vat-tu`.
- **Con số cỡ `--chu-3xl`, `tabular-nums`, nhãn cỡ `--chu-sm` `--mau-chu-mo` đặt TRÊN con
  số.** Nhãn trên thì mắt biết mình sắp đọc gì; nhãn dưới thì phải đọc ngược.
- **Không màu mè.** Bốn thẻ chỉ số nền trắng viền mảnh, không gradient, không icon lớn,
  không màu nền khác nhau cho từng thẻ. Màu ở đây chỉ dùng khi một chỉ số **thật sự** cần
  chú ý.
- **"Việc cần làm" đáng giá hơn mọi biểu đồ.** Người mở màn tổng quan buổi sáng cần biết
  *hôm nay phải làm gì*, không cần một đường xu hướng.
- **Chưa có thư viện biểu đồ trong `package.json`, và đừng tự thêm.** Cần một biểu đồ thì
  hỏi trước — thêm dependency là quyết định của dự án, không phải của một màn hình. Thứ vẽ
  được ngay bằng CSS thuần: thanh tiến trình, dải phân bố, thanh so sánh ngang.

## 6. Khuôn E — Trang chủ ứng dụng

Trang chủ của một ứng dụng: `/kho-van`, `/thiet-bi`. Khuôn mới nhất và chỉ có mặt vì một
màn thật không chịu nằm yên trong bốn khuôn kia — nó không có chỉ số, không có việc cần
làm, nó là một **sơ đồ quy trình nghiệp vụ**. Màn này không gọi API; nó dựng từ hằng số
(`quy-trinh.ts`), nên không mang năm trạng thái như các khuôn khác.

```
┌──────────────────────────────────────────────────────────────┐
│ Kho van                                                       │
│ Kho khong tu sinh chung tu. Hang vao tu Mua hang, hang ra     │
│ theo Ban hang hoac San xuat; kho chi ghi lai moi lan vao ra.  │
├──────────────────────────────────────────────────────────────┤
│ ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐    │
│ │1 Danh muc│ → │2 Nhap kho│ → │3 Ton kho │ → │4 Xuat kho│    │
│ │stock_items│  │stock_movem│  │tinh tu mv│   │stock_movem│   │
│ │warehouses │  │Chua co man│  │ Ton kho ↗│   │Chua co man│   │
│ │ Vat tu ↗  │  └──────────┘   └──────────┘   └──────────┘    │
│ │ Kho ↗     │                                                │
│ └──────────┘                                                 │
│                                                                │
│ DOI CHIEU DINH KY — khong nam tren luong vao ra               │
│ ┌──────────┐   ┌──────────┐                                  │
│ │ Kiem ke  │   │Dieu chinh│                                  │
│ │Chua co man│  │Chua co man│                                 │
│ └──────────┘   └──────────┘                                  │
└──────────────────────────────────────────────────────────────┘
```

Luật riêng của khuôn này:

- **Số thứ tự trên mỗi ô.** Sơ đồ không vẽ mũi tên khi xuống dòng ở màn hẹp, nên số là thứ
  duy nhất giữ được thứ tự đọc ở mọi bề rộng.
- **Dưới mỗi ô là tên bảng dữ liệu bước đó ghi vào.** Đó là thứ nối sơ đồ với schema thật;
  bỏ nó đi thì sơ đồ thành tranh minh họa.
- **Một bước trỏ được nhiều màn.** Bước "Danh mục" của Kho vận ôm cả Vật tư lẫn Kho. Nếu
  mỗi bước chỉ được một màn thì màn "Kho" biến mất khỏi sơ đồ, và người dùng thấy một toàn
  cảnh thiếu mất một thứ có thật.
- **Bước chưa có màn: viền nét đứt cả thẻ, nhãn "Chưa có màn", `title` nói rõ.** Khác với
  ô ứng dụng khóa ở màn `/` (nét đứt chỉ trên ô biểu tượng), vì ở đây không có ô biểu tượng
  nào để mang dấu hiệu đó. Cùng luật gốc: một ô xám câm là lỗi giao diện tệ nhất trong ERP.
- **Nhánh bên là khối riêng**, có tiêu đề nói vì sao nó tách khỏi luồng chính, và không
  đeo số thứ tự — nó không nằm trên luồng.
- **Không màu riêng cho từng bước.**

## 7. Màn hẹp

Người dùng ERP chủ yếu ngồi máy bàn, nên **màn hẹp không phải mục tiêu chính** — nhưng nó
phải *dùng được*, vì có người mở trên tablet ở kho.

| Dưới `--gay-vua` (1200px) | Dưới `--gay-hep` (768px) |
|---|---|
| Thanh điều hướng thu còn biểu tượng (64px) | Thanh điều hướng thành ngăn kéo, mở bằng nút |
| Bảng bắt đầu cuộn ngang | Thanh lọc xuống một cột |
| | Form dùng hết chiều ngang |
| | Chân trang form bỏ dính đáy |

Ba luật không được vi phạm ở bất cứ độ rộng nào:

1. **Thân trang không bao giờ cuộn ngang.** Thứ rộng quá (bảng, khối code) cuộn trong
   khung riêng của nó, `overflow-x: auto`.
2. **Không tắt zoom.** `user-scalable=no` là thứ cấm tuyệt đối — nó khóa cửa với người mắt
   kém.
3. **Vùng bấm 44×44px trên cảm ứng.** `co-so.css` đã lo qua `@media (pointer: coarse)`;
   đừng ghi đè nó xuống thấp hơn.

Cuối cùng: **cột mã dính bên trái khi bảng cuộn ngang.** Mất cột mã là mất luôn manh mối
dòng đang đọc là dòng nào — và đó đúng là lúc người dùng đang cuộn để tìm một con số ở cột
xa nhất.
