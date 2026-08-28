# Thiết kế - 2026-08-28, trang chi tiết vật tư và bố cục màn thêm vật tư

Phạm vi: chỉ `frontend-erp`. Không đổi schema, không thêm endpoint, không sửa `backend-erp`.

## 1. Vì sao

`/vat-tu/:id` hiện nay mở thẳng form sửa. Bấm vào một mã vật tư nghĩa là bước ngay vào một
màn có thể ghi đè dữ liệu, trong khi việc người dùng làm nhiều nhất là XEM: còn bao nhiêu,
nằm ở kho nào, vừa nhập xuất gì. Ba câu đó hiện phải đi qua hai màn khác (`/ton-kho`,
`/chuyen-dong`) rồi lọc tay.

Ngoài ra hàng trong bảng danh sách chỉ bấm được ở đúng ô Mã - một vùng rộng chừng 60px
trong một hàng rộng cả nghìn.

## 2. Bản đồ đường dẫn sau thay đổi

```
/vat-tu            danh sách   -> bấm cả hàng
/vat-tu/moi        thêm vật tư
/vat-tu/:id        CHI TIẾT    (mới)
/vat-tu/:id/sua    sửa         (form hiện nay dời sang đây)
```

Thứ tự trong `routes.tsx` giữ nguyên luật đã có: `/vat-tu/moi` đứng TRƯỚC `/vat-tu/:id`.
`/vat-tu/:id/sua` ba đoạn nên không tranh chấp với hai route hai đoạn.

Mọi chỗ đang trỏ tới `/vat-tu/:id` với ý "sửa" phải đổi sang `/vat-tu/:id/sua`. Chỗ đã
biết: `StockItemListPage` (link trên ô mã - chỗ này đổi ý nghĩa thành XEM chứ không đổi
đường), `App.test.tsx`, `AppLayout.test.tsx`.

## 3. Khuôn C - trang chi tiết vật tư

```
┌────────────────────────────────────────────────────────────────┐
│ ← Danh sách vật tư                                             │
│ ┌────────┐                                                     │
│ │ VT-001 │ Thép tấm 5mm                      [Xoá]  [Sửa]      │  dải đầu trang
│ └────────┘                                                     │
├────────────────────────────────────────────────────────────────┤
│ THÔNG TIN CHUNG                                                │
│ Đơn vị tính     KG                                             │  <dl> hai cột
│ Mã vật tư       VT-001                                         │
│ Tên vật tư      Thép tấm 5mm                                   │
├────────────────────────────────────────────────────────────────┤
│ TỒN THEO KHO                                    [Xem tồn kho]  │
│ MÃ KHO    TÊN KHO                                      TỒN     │
│ K01       Kho chính                              900,0000      │
│ K02       Kho phụ                                350,0000      │
├────────────────────────────────────────────────────────────────┤
│ CHUYỂN ĐỘNG GẦN ĐÂY                          [Xem tất cả]      │
│ THỜI ĐIỂM         LOẠI    KHO             SỐ LƯỢNG             │
│ 12/08/2026 09:12  Nhập    K01              500,0000            │
│ 10/08/2026 14:03  Xuất    K02              120,0000            │
└────────────────────────────────────────────────────────────────┘
```

### 3.1 Ba khối, ba lượt gọi API, ba nhánh lỗi độc lập

| Khối | Nguồn | Hook |
|---|---|---|
| Thông tin chung | `GET /stock-items/:id` | `useStockItemDetail` (đã có) |
| Tồn theo kho | `GET /stock-balances?stock_item_id=` | `useBalanceList` (đã có) |
| Chuyển động gần đây | `GET /stock-movements?stock_item_id=&page_size=10&sort=-occurred_at` | `useMovementList` (đã có) |

Ba permission RIÊNG bên Go. Một người đọc được vật tư vẫn có thể không đọc được tồn kho.
Nên **một khối 403 chỉ làm câm khối đó**, hai khối kia vẫn hiện - đúng lối
`StockItemListPage` đã làm với danh mục đơn vị tính. Chỉ khối thông tin chung hỏng mới làm
cả trang thành một bảng thông báo, vì hai khối dưới nói về một bản ghi không đọc được.

Tham số của hai hook phụ là **hằng ở cấp module** trộn với `stock_item_id`, không dựng
trong thân component: nó đi thẳng vào cache key của TanStack Query.

### 3.2 KHÔNG có ô "Tổng tồn"

Bỏ có chủ ý. Backend không trả tổng tồn của một vật tư ở endpoint nào; muốn có nó thì phải
cộng các dòng `stock_balances` dưới máy. Hai lý do từ chối:

1. `quantity` là `NUMERIC(18,4)` về dưới dạng **chuỗi**. Cộng nó trong JavaScript là cộng
   bằng `number` dấu phẩy động - sai số ở chữ số thứ tư sau dấu phẩy là chuyện có thật.
2. R-19: frontend không tính tồn kho. Một con số tồn do màn hình tự cộng, đặt cạnh những
   con số backend trả về, là chỗ để hai nguồn sự thật lệch nhau mà không ai biết.

Bảng tồn theo kho đã trả lời được câu "còn bao nhiêu, ở đâu". Cần một tổng thật thì việc
phải làm là mở một endpoint bên backend, không phải cộng ở đây.

### 3.3 Nút Xoá

Xác nhận hai bước ngay trong dải đầu trang, cùng mẫu với `StockItemListPage` - không
`window.confirm`. Câu xác nhận nói hậu quả cụ thể: xoá là xoá mềm (R-18), các dòng chuyển
động trỏ tới vật tư này vẫn còn. Xoá xong thì `navigate('/vat-tu')`.

Nút Sửa và nút Xoá không hỏi quyền, không đoán từ role (C-TS-06): để nút hiện, xử lý 403
tại chỗ khi nó tới.

### 3.4 Năm trạng thái

| Trạng thái | Hiện gì |
|---|---|
| Đang tải lần đầu | Khung xương cho cả ba khối, ghép từ `KhungXuong` |
| Rỗng | Không tồn tại ở khối thông tin. Hai khối bảng có màn rỗng riêng: "Vật tư này chưa có tồn ở kho nào" / "Vật tư này chưa có chuyển động nào" |
| Lỗi | 403 / 404 / còn lại, ba câu khác nhau, đúng khuôn `StockItemFormPage` đang có |
| Có dữ liệu | Ba khối |
| Đang làm mới nền | Giữ nguyên dữ liệu cũ, `role="status"` chỉ đọc màn hình |

Màn rỗng của khối tồn kho mang đường ra là link sang `/chuyen-dong/moi`: vật tư chưa có tồn
thì việc tiếp theo là ghi một phiếu nhập.

## 4. Bấm cả hàng ở bảng danh sách

- `<tr>` nhận `onClick` gọi `navigate('/vat-tu/:id')`, cộng `cursor: pointer` và nền sáng
  lên khi rê chuột.
- Ô Mã **giữ nguyên thẻ `<a>` thật**. Đó là đường của bàn phím và của chuột giữa (mở tab
  mới). Không thêm `role="button"`/`tabIndex` lên `<tr>`: làm vậy là hai điểm dừng tab cho
  cùng một đích, và trình đọc màn hình đọc cả hàng thành một cái nút.
- Không điều hướng khi: bấm trúng một `<a>`, `<button>`, `<input>`, `<select>` bên trong
  hàng (`event.target.closest`), hoặc khi người dùng vừa bôi đen chữ
  (`window.getSelection()?.toString() !== ''`). Ca thứ hai là ca hay bị bỏ sót: bôi đen tên
  vật tư để chép rồi nhả chuột cũng sinh một `click` trên hàng.
- Cùng đối xử với `WarehouseListPage`? **Không, để lần sau.** Đợt này chỉ đụng vật tư; áp
  cho hai màn khác là mở diff ra ngoài phạm vi.

## 5. Màn thêm vật tư - dựng lại bố cục

Nghiệp vụ giữ nguyên **không đụng một dòng**: ba trạng thái của ô đơn vị tính, phép kiểm
cục bộ, cách tô lỗi 422 theo tên ô, nhánh 409 mã trùng.

Đổi đúng phần nhìn thấy được:

- **Thứ tự ô: Mã → Tên → Đơn vị tính.** Hiện nay Đơn vị tính đứng đầu. Người nhập liệu gõ
  mã trước, và ô đầu tiên là ô nhận tiêu điểm - bắt họ mở một `<select>` trước khi gõ được
  chữ nào là ngược thói quen.
- **Form vào trong thẻ**, một cột rộng `--rong-form`, nhãn trên ô, dòng gợi ý dưới ô cùng
  cỡ `--chu-sm` màu `--mau-chu-mo`.
- **Chân thẻ dính đáy**, nút `Huỷ` rồi `Lưu vật tư` bên phải cùng. Chữ trên nút nói ra đối
  tượng, và không đổi suốt luồng: nút "Lưu vật tư" thì thông báo sau đó là "Đã lưu vật tư".
- Bốn dòng ghi chú của ô đơn vị tính (đang tải danh mục / danh mục hỏng / chạm trần một
  trang / danh mục rỗng) giữ nguyên nội dung, chỉ xếp lại cho thẳng cột với ô.

Không thêm token mới. Không đổi bảng màu.

## 6. Test

| File | Ca phải có |
|---|---|
| `StockItemDetailPage.test.tsx` | Ba khối cùng hiện; khối tồn kho 403 mà hai khối kia còn; 404 ở khối thông tin; xoá hai bước rồi điều hướng về danh sách; link Sửa trỏ `/vat-tu/:id/sua` |
| `StockItemListPage.test.tsx` | Bấm giữa hàng thì điều hướng; bấm nút Xoá thì KHÔNG điều hướng; bấm ô Mã đi đúng đường |
| `App.test.tsx` | Đường đi danh sách → chi tiết → sửa |

Test trạng thái hiển thị bám **class**, không bám chữ: `textContent` không thấy được thứ bị
CSS giấu.

## 7. Việc cố ý không làm

- Không đụng `WarehouseListPage` và `MachineListPage`.
- Không thêm ô "Tổng tồn" (mục 3.2).
- Không sửa chỗ `TieuDeTrang` đang mang `moTa` tổng số ở màn danh sách, dù khuôn A nói tổng
  thuộc chân bảng. Đó là một đợt riêng, chạm cả bốn màn danh sách.
