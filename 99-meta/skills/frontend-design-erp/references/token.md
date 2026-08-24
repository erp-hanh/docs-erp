# Hệ token

Đọc file này **trước khi viết dòng CSS đầu tiên**, và mỗi khi định thêm một giá trị mới.
File chép được ngay: [`../assets/tokens.css`](../assets/tokens.css).

## Mục lục

1. [Luật của hệ token](#1-luật-của-hệ-token)
2. [Màu](#2-màu)
3. [Khoảng cách](#3-khoảng-cách)
4. [Chữ](#4-chữ)
5. [Bo góc, độ nổi, nhịp](#5-bo-góc-độ-nổi-nhịp)
6. [Khung bố cục](#6-khung-bố-cục)
7. [Chế độ tối](#7-chế-độ-tối)
8. [Thêm một token mới](#8-thêm-một-token-mới)
9. [Cài đặt lần đầu](#9-cài-đặt-lần-đầu)

---

## 1. Luật của hệ token

**Một giá trị hình thức chỉ được viết thô đúng một lần, trong `tokens.css`.** Mọi nơi
khác gọi qua biến.

Điều này nghe như quy tắc vệ sinh, nhưng nó là quyết định kỹ thuật có hậu quả đo được:

- Hệ này **sẽ** có chế độ tối. Mỗi `#fff` viết rải rác là một chỗ sáng trắng còn sót lại
  trong màn tối, và không có cách nào tìm hết chúng bằng máy sau khi đã có vài trăm file.
- Nhà xưởng sáng chói cần độ tương phản khác văn phòng. Nếu độ tương phản là một tham số
  của hệ, việc chỉnh là sửa sáu dòng; nếu không, việc chỉnh là không làm được.
- Một màu thô còn là một câu hỏi không ai trả lời được: `#e5e7eb` này là viền hay là nền?
  Token trả lời câu đó bằng chính cái tên.

Ba ngoại lệ, và chỉ ba:

| Được viết thô | Ở đâu |
|---|---|
| Mọi giá trị của hệ | `tokens.css` |
| `1px` của đường viền | Bất cứ đâu — 1px là hằng số vật lý, không phải lựa chọn thiết kế |
| `0`, `100%`, `auto`, `1fr` | Bất cứ đâu — không phải giá trị hình thức |

Script [`../scripts/kiem-giao-dien.mjs`](../scripts/kiem-giao-dien.mjs) canh đúng luật này.

## 2. Màu

### Nền — ba tầng, và thứ tự của chúng là cố ý

| Token | Giá trị | Nghĩa |
|---|---|---|
| `--mau-nen` | `#f6f7f9` | Nền trang. **Không trắng.** |
| `--mau-nen-noi` | `#ffffff` | Thẻ, bảng, hộp thoại — thứ nổi lên trên nền trang |
| `--mau-nen-nhat` | `#f6f8fa` | Ô tô nhẹ: header bảng, dòng đang rê chuột, khối mã |
| `--mau-nen-chim` | `#eceff3` | Vùng thụt vào: khối code, thanh tiến trình |

Nền trang không trắng là quyết định chi phối cảm giác của cả hệ. Nhờ nó, một cái thẻ trắng
**nổi lên được mà không cần bóng đổ** — và bóng đổ giữ lại cho đúng thứ thật sự lơ lửng
(dropdown, hộp thoại). Đây là lý do giao diện này trông nhẹ chứ không trông phẳng lì.

### Chữ

| Token | Giá trị | Dùng cho |
|---|---|---|
| `--mau-chu` | `#1f2328` | Chữ chính. Tương phản 14.8:1 trên nền trang |
| `--mau-chu-mo` | `#57606a` | Chú thích, đơn vị, nhãn cột. 6.4:1 — vẫn đạt AA ở cỡ nhỏ |
| `--mau-chu-nhat` | `#ffffff` | Chữ trên nền đậm (nút chính, nhãn trạng thái đặc) |

**Không có tầng chữ thứ tư.** Một màu xám nhạt hơn `--mau-chu-mo` sẽ tụt xuống dưới 4.5:1
và trở thành thứ ai đó phải đọc bằng cách nghiêng màn hình. Cần chữ trông nhẹ hơn nữa thì
giảm **cỡ** hoặc giảm **độ đậm**, đừng giảm tương phản.

### Thương hiệu

| Token | Giá trị | Dùng cho |
|---|---|---|
| `--mau-chinh` | `#12708c` | Nút chính, link, thanh chỉ báo tab đang chọn |
| `--mau-chinh-dam` | `#0d5a72` | Trạng thái đang nhấn |
| `--mau-chinh-nhat` | `#e6f1f5` | Nền tô nhẹ: dòng đang chọn, tab đang chọn |

Xanh dầu công nghiệp, không phải indigo hay tím. Lý do có hai vế. Vế thứ nhất: hệ này nói
về máy, kho, vật tư — bảng màu nên đọc ra được điều đó. Vế thứ hai thẳng thắn hơn: indigo
`#4F46E5` là màu mặc định của mọi dashboard do AI sinh ra, và dùng nó là tự nguyện trông
giống hàng nghìn sản phẩm khác. Chữ trắng trên `#12708c` đạt 5.9:1, đủ chuẩn AA cho nút.

### Trạng thái

| Token | Nền đi kèm | Nghĩa |
|---|---|---|
| `--mau-loi` `#b3261e` | `--mau-loi-nhat` `#fdecea` | Thao tác thất bại, ô nhập sai |
| `--mau-canh-bao` `#8a5a00` | `--mau-canh-bao-nhat` `#fdf4e3` | Cần chú ý nhưng chưa hỏng |
| `--mau-tot` `#1d7a46` | `--mau-tot-nhat` `#e8f5ed` | Đã lưu, đã duyệt, còn hàng |

Mỗi màu trạng thái đi thành **cặp** với một nền nhạt. Banner luôn dùng cặp đó, không bao
giờ là chữ màu trên nền trắng: chữ màu nhỏ trên nền trắng vừa khó đọc vừa dễ trượt chuẩn
tương phản khi ai đó đổi cỡ chữ.

**Màu không bao giờ là kênh thông tin duy nhất.** Một dòng lỗi phải có chữ; một nhãn trạng
thái phải có chữ; một ô nhập sai dày viền lên 2px chứ không chỉ đổi màu viền. Khoảng 8%
đàn ông không phân biệt được đỏ với lục — và trong một hệ ERP, "không phân biệt được đã
duyệt với bị từ chối" không dừng lại ở khó chịu.

## 3. Khoảng cách

Lưới 4px. `--gian-1` = 4px, `--gian-2` = 8, `--gian-3` = 12, `--gian-4` = 16,
`--gian-5` = 24, `--gian-6` = 32, `--gian-7` = 48, `--gian-8` = 64.

Cách chọn nhanh, theo quan hệ giữa hai thứ đang cách nhau:

| Quan hệ | Token | Ví dụ |
|---|---|---|
| Dính liền nhau | `--gian-1` | Chấm trạng thái với chữ của nó |
| Cùng một nhóm | `--gian-2` | Hai nút cạnh nhau, nhãn với ô nhập |
| Cùng một khối | `--gian-3` | Hai trường trong một form, padding ô bảng |
| Khối với khối | `--gian-5` | Thanh lọc với bảng |
| Vùng lớn với nhau | `--gian-6` | Đầu trang với nội dung |

Một quy tắc phụ nhưng cứu được nhiều bố cục: **khoảng cách bên trong một nhóm phải nhỏ
hơn khoảng cách giữa các nhóm.** Nếu nhãn cách ô nhập 8px thì hai trường phải cách nhau
hơn 8px — nếu không, mắt sẽ gom nhãn của trường dưới vào ô nhập của trường trên.

## 4. Chữ

### Font

```css
--font-chu: system-ui, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
--font-so: ui-monospace, 'Cascadia Mono', 'Consolas', 'Roboto Mono', monospace;
```

Font hệ thống, không tải về. Ba lý do: nó không chặn render, nó không cần Internet (VPS
triển khai có thể không ra ngoài được), và Segoe UI với Roboto đều có bộ dấu tiếng Việt
đầy đủ — nhiều font web đẹp thì thiếu `ẫ`, `ộ`, `ừ` và rơi về font thay thế ngay giữa câu.

Muốn một font riêng cho tiêu đề sau này thì thêm `--font-tieu-de` và đổi ở đúng một chỗ.
Hệ token đã chừa sẵn đường đó; đừng nhúng `@font-face` rải rác.

### Cỡ

| Token | px | Dùng cho |
|---|---|---|
| `--chu-xs` | 12 | Nhãn cột bảng, chú thích, mã tra cứu |
| `--chu-sm` | 13 | Ô bảng, nhãn trường |
| `--chu-md` | 14 | **Mặc định của thân ứng dụng** |
| `--chu-lg` | 16 | Đoạn văn đọc liền, tiêu đề khối nhỏ |
| `--chu-xl` | 20 | Tiêu đề khối |
| `--chu-2xl` | 24 | Tiêu đề trang |
| `--chu-3xl` | 30 | Con số lớn ở màn tổng quan |

Gốc `<html>` giữ 16px để `rem` của người dùng còn nghĩa; thân ứng dụng 14px vì đây là màn
làm việc dày dữ liệu chứ không phải trang đọc. **Sàn dưới 12px không tồn tại** — mọi lần
ai đó muốn 11px, thứ thật sự cần là bớt chữ trên màn, không phải thu nhỏ chữ.

### Chiều cao dòng

`--dong-chat` 1.25 (tiêu đề) · `--dong-vua` 1.45 (giao diện) · `--dong-rong` 1.6 (đoạn văn).

Rộng hơn thông lệ một chút, và đó là cố ý: dấu tiếng Việt ăn vào cả phần trên lẫn phần
dưới của dòng. Ở 1.2, `Nhập kho từ đơn hàng` có dấu sẽ chạm vào dòng bên dưới.

### Độ đậm

Đúng ba mức: `--dam-thuong` 400, `--dam-vua` 500, `--dam-manh` 600. Không dùng 700 — với
font hệ thống ở cỡ 13–14px, 600 và 700 gần như không phân biệt được, và có bốn mức thì
bảng sẽ nhanh chóng trông lộn xộn vì mỗi người chọn một mức.

### Số

Mọi con số trong bảng hoặc trong một khối chỉ số:

```css
text-align: right;
font-variant-numeric: tabular-nums;
```

`tabular-nums` làm mọi chữ số rộng bằng nhau, nên hàng đơn vị của cả cột thẳng hàng. Đó là
thứ cho phép **dò một cột tiền bằng mắt** thay vì phải đọc từng ô. Trong `co-so.css`, đánh
dấu bằng `class="so"` hoặc `data-so` trên `<td>`/`<th>` là đủ.

## 5. Bo góc, độ nổi, nhịp

| Nhóm | Token | Dùng cho |
|---|---|---|
| Bo góc | `--bo-goc` 6px | Nút, ô nhập, nhãn |
| | `--bo-goc-lon` 10px | Thẻ, hộp thoại |
| | `--bo-goc-tron` 999px | Chip, chấm trạng thái |
| Độ nổi | `--do-noi-1` | Thẻ nổi nhẹ |
| | `--do-noi-2` | Dropdown, popover |
| | `--do-noi-3` | Hộp thoại |
| Nhịp | `--nhip-nhanh` 120ms | Hover, nhấn |
| | `--nhip-vua` 180ms | Xuất hiện, biến mất |
| | `--nhip-cho` 1500ms | Nhịp thở của khung xương |
| | `--duong-cong` | Mọi `transition` |
| Biểu tượng | `--co-bieu-tuong` 20px | Mọi SVG nội tuyến |

Hai token cuối bảng nhỏ nhưng có lý do riêng. `--nhip-cho` chậm gấp mười lần `--nhip-vua`
vì khung xương phải **thở, không được đòi chú ý** — một khung xương nhấp nháy nhanh đọc ra
thành lỗi. `--co-bieu-tuong` tồn tại vì biểu tượng 16px cạnh biểu tượng 24px trong cùng một
hàng nút là thứ mắt bắt ra ngay mà không gọi tên được; một cỡ duy nhất cho cả hệ là cách rẻ
nhất để việc đó không xảy ra.

**Bóng đổ là tài nguyên hiếm.** Một giao diện mà mọi thứ đều có bóng là một giao diện không
có tầng lớp. Mặc định của hệ này là viền 1px; bóng chỉ dành cho thứ thật sự lơ lửng bên
trên mặt phẳng và có thể biến mất.

**Chuyển động phục vụ sự hiểu.** Trên 200ms là người dùng bắt đầu chờ; trong một màn nhập
liệu gõ cả ngày, chờ 300ms mỗi lần mở dropdown là một cực hình nhỏ lặp lại vài trăm lần.
Không animation lúc trang vừa tải, không thứ gì tự chuyển động mà người dùng không gây ra.
`co-so.css` đã tắt toàn bộ chuyển động khi hệ điều hành bật `prefers-reduced-motion`.

## 6. Khung bố cục

| Token | Giá trị | Nghĩa |
|---|---|---|
| `--rong-noi-dung` | 1440px | Trần của vùng nội dung |
| `--rong-form` | 640px | Một cột form |
| `--rong-doc` | 72ch | Đoạn văn đọc liền |
| `--cao-thanh-dau` | 56px | Thanh đầu trang |
| `--rong-canh` | 240px | Thanh điều hướng trái |
| `--rong-canh-hep` | 64px | Thanh điều hướng khi thu gọn |
| `--gay-hep` | 768px | Dưới mức này: một cột |
| `--gay-vua` | 1200px | Dưới mức này: thanh điều hướng thu gọn |

Form 640px không phải con số tùy tiện: ô nhập rộng hơn thế thì mắt mất mất đường về đầu
dòng tiếp theo, và một form ERP trên màn 27 inch mà kéo hết chiều ngang là thứ không ai
điền nổi. **Bảng thì ngược lại — bảng được dùng hết chiều ngang**, vì giá trị của nó là
số cột nhìn thấy cùng lúc.

CSS chưa dùng được biến trong `@media`, nên giá trị điểm gãy vẫn phải gõ tay trong media
query. Khai token ở đây để có một chỗ đối chiếu, và để khi đổi thì biết phải sửa những đâu.

## 7. Chế độ tối

Khối `:root[data-theme='toi']` trong `tokens.css` **chỉ định nghĩa lại màu**. Khoảng cách,
cỡ chữ, bo góc, nhịp đều không đổi — đó là lý do khối đó chỉ dài hai chục dòng, và cũng là
phép thử cho thấy hệ token được chia đúng. Nếu một ngày chế độ tối đòi đổi khoảng cách,
nghĩa là khoảng cách đó đang mang một nhiệm vụ không phải của nó.

Hai điều chỉnh riêng của bản tối đáng nhớ:

- **Màu thương hiệu phải sáng lên một bậc.** `#12708c` trên nền `#14171a` chỉ còn 2.9:1 —
  không đọc được. Bản tối dùng `#4fb3cc`.
- **Bóng đổ đậm hơn.** Trên nền tối, bóng nhạt biến mất hoàn toàn.

Ứng dụng **chưa có nút chuyển chế độ**, và đó là trạng thái đúng lúc này: thêm nút là một
quyết định về phiên người dùng và nơi lưu lựa chọn, không phải một quyết định thiết kế.
Phần token đã sẵn sàng cho ngày đó; gắn `data-theme="toi"` lên `<html>` là thử được ngay.

## 8. Thêm một token mới

Cần một giá trị mà hệ chưa có? Đi qua ba câu hỏi, theo thứ tự:

1. **Có token nào gần đúng không?** Cần 20px thì dùng `--gian-5` (24px) hoặc `--gian-4`
   (16px). Chênh 4px không ai thấy; một giá trị lẻ ngoài lưới thì thấy.
2. **Đây là giá trị của cả hệ hay của riêng một component?** Riêng một component thì viết
   trong `*.module.css` của nó bằng cách kết hợp token có sẵn (`calc(var(--gian-4) * 2)`),
   không thêm vào `tokens.css`. `tokens.css` phình ra là hệ token mất tác dụng.
3. **Nếu thật sự là của cả hệ:** thêm vào `tokens.css` kèm một dòng ghi chú nói **khi nào
   dùng**, thêm bản chế độ tối nếu là màu, và cập nhật bảng trong file này. Một token không
   có ghi chú "dùng khi nào" thì lần sau người khác sẽ tạo một token thứ hai trùng nghĩa.

## 9. Cài đặt lần đầu

```
src/shared/styles/
├── tokens.css   <- chép từ assets/tokens.css
└── co-so.css    <- chép từ assets/co-so.css
```

```ts
// src/main.tsx - THU TU nay bat buoc: token phai co truoc khi co-so.css doc no.
import '@/shared/styles/tokens.css';
import '@/shared/styles/co-so.css';
import '@/app/app.css';
```

`src/app/app.css` giữ lại đúng phần **bố cục vỏ ứng dụng** (`.vo-ung-dung`, `.thanh-dau`,
`.noi-dung`). Bốn biến màu và phần tạo dáng cho `button`/`input` trong đó chuyển hết sang
hai file mới — bốn biến ấy giữ **nguyên giá trị**, chỉ đổi chỗ ở, nên diff của bước này là
di chuyển chứ không phải đổi thiết kế.

Cho tới khi bước chuyển này xong, `kiem-giao-dien.mjs` sẽ báo `app.css` — hôm nay là 21
dòng: 6 mã màu, 13 khoảng cách viết bằng `rem`, 2 cỡ chữ. **Đó là danh sách việc phải làm,
không phải lỗi mới phát sinh.** Chuyển hết một lần trong một PR riêng, không lẫn vào PR
tính năng: một diff "di chuyển giá trị" đọc được trong ba phút, còn khi nó nằm giữa một
màn hình mới thì không ai kiểm được là giá trị nào đã đổi.

Class hiện có trong `app.css` viết tiếng Việt không dấu (`thanh-dau`, `noi-dung`,
`lien-ket`). Giữ đúng lối đó cho mọi class mới — trộn tiếng Anh vào giữa là để lại cho
người sau một câu hỏi không có câu trả lời.
