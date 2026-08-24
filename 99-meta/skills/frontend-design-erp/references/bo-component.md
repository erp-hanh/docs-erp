# Bộ component dùng chung

Nơi ở: `src/shared/components/<Ten>/` — một thư mục cho mỗi component, gồm `<Ten>.tsx`,
`<Ten>.module.css` và `<Ten>.test.tsx`.

Hai ràng buộc không đổi:

- **`shared/` cấm import `modules/`** (R-04). Một `Nut` biết tới đơn hàng thì không còn
  dùng chung được, và mọi module kéo theo cây phụ thuộc của order mỗi lần vẽ một cái nút.
- **Component ở đây không mang nghiệp vụ.** Nó không biết trạng thái nào hợp lệ, không
  biết ai được duyệt. Nó nhận prop và vẽ.

## Mục lục

| Component | Việc của nó |
|---|---|
| [`Nut`](#nut) | Một hành động |
| [`TieuDeTrang`](#tieudetrang) | Đầu mỗi màn: tên màn + hành động chính |
| [`MaBanGhi`](#mabanghi) | Mã nghiệp vụ — dấu ấn riêng của hệ này |
| [`NhanTrangThai`](#nhantrangthai) | Trạng thái một bản ghi |
| [`BangThongBao`](#bangthongbao) | Lỗi / cảnh báo / thành công ở cấp màn hình |
| [`TruongNhap`](#truongnhap) | Nhãn + ô nhập + lỗi của ô đó |
| [`ThanhLoc`](#thanhloc) | Khung chứa các ô lọc |
| [`Bang`](#bang) | Khung bảng + năm trạng thái |
| [`PhanTrang`](#phantrang) | Chân bảng |
| [`ManRong`](#manrong) | Không có dữ liệu |
| [`KhungXuong`](#khungxuong) | Đang tải lần đầu |
| [`HopThoaiXacNhan`](#hopthoaixacnhan) | Xác nhận thao tác không lùi được |

**Khi nào tạo component mới:** khi cùng một hình dạng xuất hiện **lần thứ ba**. Hai lần
đầu cứ chép. Trừu tượng hóa sớm ở tầng giao diện luôn đắt hơn chép hai lần, vì lần thứ ba
mới cho biết chỗ nào thật sự cần thay đổi được.

---

## `Nut`

```tsx
export interface NutProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  kieu?: 'chinh' | 'phu' | 'mo' | 'nguy-hiem'; // mac dinh: 'phu'
  dangChay?: boolean; // co mot request dang bay
  lyDoKhoa?: string; // BAT BUOC khi disabled ma khong phai vi dangChay
}
```

| Kiểu | Hình thức | Dùng khi |
|---|---|---|
| `chinh` | Nền `--mau-chinh`, chữ trắng | **Một** hành động chính mỗi màn |
| `phu` | Viền, nền trắng | Mặc định |
| `mo` | Không viền, không nền | Hành động phụ trong một dòng bảng |
| `nguy-hiem` | Viền + chữ `--mau-loi` | Xóa, hủy — và **luôn đi qua `HopThoaiXacNhan`** |

Ba điều quan trọng hơn phần hình thức:

**`lyDoKhoa` là bắt buộc khi nút bị khóa.** Một cái nút xám câm là lỗi giao diện tệ nhất
trong ERP: người dùng không có cách nào tự gỡ, không biết hỏi ai, và thường kết luận là
phần mềm hỏng. `lyDoKhoa` đi vào `title` và vào một `<span class="chi-doc-man-hinh">` để
trình đọc màn hình cũng nhận được.

```tsx
// Khoa vi du lieu noi vay - allowed_actions cua chinh ban ghi (C-TS-06).
<Nut
  kieu="chinh"
  disabled={!don.allowed_actions.includes('approve')}
  lyDoKhoa="Don o trang thai nay khong duyet duoc"
  onClick={onDuyet}
>
  Duyet don
</Nut>
```

**`dangChay` khóa nút và đổi chữ**, không thay chữ bằng một vòng xoay: người dùng cần biết
việc *nào* đang chạy. `Luu` → `Dang luu...`. Đây là cách chống bấm hai lần ở phía giao
diện; nó **không thay thế** `Idempotency-Key` (C-TS-05) — nút bị khóa không cứu được lần
gửi lại sau timeout.

**Không tự suy quyền.** `Nut` không nhận `role`, không nhận `permissions`. Nó nhận
`disabled` mà nơi gọi đã tính từ `allowed_actions`.

## `TieuDeTrang`

```tsx
export interface TieuDeTrangProps {
  tieuDe: string;
  moTa?: string; // mot cau, khong phai mot doan
  hanhDong?: ReactNode; // 0-2 nut, nut chinh ben PHAI cung
  duongDan?: ReactNode; // breadcrumb, chi o man chi tiet va man form
}
```

Đầu trang là chỗ trả lời hai câu, đúng thứ tự người dùng hỏi: *tôi đang ở đâu* và *tôi làm
được gì ở đây*. Tên màn bên trái, hành động bên phải — và **đúng một hành động chính**.
Hai nút `chinh` cạnh nhau nghĩa là màn hình không trả lời được câu "tôi nên bấm gì bây
giờ".

## `MaBanGhi`

Dấu ấn riêng của hệ này. Người dùng ERP gọi tên mọi thứ bằng mã — `PO-001`, mã kho, mã vật
tư — và trong code hiện tại `row.code` đã luôn là đường sang màn chi tiết. Component này
biến thói quen đó thành một thứ nhất quán và nhìn ra ngay.

```tsx
export interface MaBanGhiProps {
  ma: string;
  den?: string; // duong dan man chi tiet; co thi render <Link>, khong thi render <span>
  copyDuoc?: boolean; // mac dinh true
}
```

Hình thức: chữ `--font-so`, cỡ `--chu-sm`, nền `--mau-nen-nhat`, bo `--bo-goc`, padding
`--gian-1`/`--gian-2`. Nút copy hiện khi rê chuột, và **luôn** hiện khi nhận tiêu điểm bàn
phím — một điều khiển chỉ hiện lúc hover là một điều khiển không tồn tại với người dùng
bàn phím.

Chữ đẳng khổ ở đây không phải để trang trí: mã nghiệp vụ được **so sánh bằng mắt** với một
tờ giấy, một tin nhắn, một màn hình khác. Chữ đẳng khổ làm việc đó nhanh hơn hẳn.

Ngoài chỗ này, phần còn lại của giao diện giữ im lặng. Bản sắc tiêu ở một chỗ thì nó mới
là bản sắc.

## `NhanTrangThai`

```tsx
export interface NhanTrangThaiProps {
  chu: string; // NHAN da dich - khong phai ma trang thai tho
  sac: 'trung-tinh' | 'tot' | 'canh-bao' | 'loi' | 'dang-chay';
}
```

Chip bo tròn, chấm màu 6px + chữ. **Chấm và chữ đi cùng nhau, luôn luôn** — màu một mình
không phải kênh thông tin (xem `token.md` §2).

`NhanTrangThai` **không** ánh xạ mã trạng thái sang màu. Bảng ánh xạ đó là kiến thức nghiệp
vụ và sống trong module:

```tsx
// src/modules/inventory/components/trang-thai.ts - trong MODULE, khong o shared/
const SAC_TRANG_THAI: Record<string, NhanTrangThaiProps['sac']> = { ... };
```

Đặt bảng đó vào `shared/` là để một component dùng chung biết tên trạng thái của một
module — đúng thứ R-04 cấm, và nó sẽ phình lên mỗi lần có module mới.

## `BangThongBao`

```tsx
export interface BangThongBaoProps {
  loai: 'loi' | 'canh-bao' | 'tot';
  tieuDe: string;
  chiTiet?: ReactNode;
  maTraCuu?: string; // request_id
  onThuLai?: () => void;
}
```

Nền `--mau-<loai>-nhat`, viền trái 3px `--mau-<loai>`, `role="alert"` khi là lỗi.

**`maTraCuu` là yêu cầu của hệ này, không phải tùy chọn.** R-17 bắt mọi response mang
`request_id`, và nó tồn tại để người dùng đọc cho tổng đài. Một banner lỗi không có mã tra
cứu là một cuộc gọi hỗ trợ không lần ra được. Hiển thị cỡ `--chu-xs`, màu `--mau-chu-mo`,
kèm nút copy.

Ba nhánh lỗi của hệ này, mỗi nhánh một cách hiện — theo đúng C-TS-05:

| Status | Hiện ở đâu | Nút kèm theo |
|---|---|---|
| `422` | Từng ô sai (`TruongNhap`) + banner cho field lạ | Không có — người dùng sửa ô |
| `409` | Banner đầu màn: dữ liệu đã cũ | "Tải lại" |
| `403` | Banner tại chỗ, **giữ nguyên màn hình** | Không có nút thử lại — lần nào cũng 403 |
| Còn lại | Banner + mã tra cứu | "Thử lại" |

Ba lỗi hay gặp ở nhánh `403` và cả ba đều tệ hơn không xử lý gì: **đăng xuất người dùng**
(403 không phải 401 — họ đăng nhập đúng), **tự động thử lại** (chỉ thêm tải cho server), và
**màn hình trắng** vì lỗi lọt lên error boundary gốc.

## `TruongNhap`

```tsx
export interface TruongNhapProps {
  nhan: string;
  batBuoc?: boolean;
  loi?: string; // thong diep tu error.fields cua 422
  goiY?: string; // dinh dang mong doi, don vi, gioi han
  children: ReactNode; // <input>, <select>, <textarea>
}
```

Bố cục dọc: nhãn → ô nhập → gợi ý → lỗi. Bốn quyết định, mỗi cái sửa một lỗi cụ thể:

- **Nhãn trên ô, không bên trái.** Mắt quét một cột dọc nhanh hơn quét zigzag, và nhãn
  bên trái luôn vỡ trên màn hẹp.
- **Placeholder không bao giờ thay nhãn.** Nó biến mất đúng lúc người ta cần nó nhất — khi
  đang gõ và muốn kiểm lại xem ô này là ô gì.
- **Lỗi nằm ngay dưới ô, không gom lên đầu.** Gom lên đầu thì người dùng phải nhớ ô nào
  sai rồi đi tìm.
- **`batBuoc` đánh dấu ô bắt buộc, không đánh dấu ô tùy chọn.** Trong ERP phần lớn ô là
  bắt buộc; đánh dấu số ít thì tín hiệu mới đọc được.

Trợ năng: `loi` phải nối vào ô bằng `aria-describedby`, và ô sai đặt `aria-invalid="true"`
để `co-so.css` dày viền lên. Không có hai thứ đó thì trình đọc màn hình đọc ô sai y hệt ô
đúng.

Nối với `toFormErrors` của C-TS-05: `fieldErrors[].path` là **đường dẫn** theo tên `json`
của backend (`code`, `items.0.quantity`), nên khóa để tra lỗi cho một ô là đường dẫn đó,
không phải tên biến trong React.

## `ThanhLoc`

```tsx
export interface ThanhLocProps {
  children: ReactNode; // cac o loc
  soDieuKien?: number; // so bo loc dang bat -> hien nut "Xoa loc"
}
```

Hàng ngang, `gap: var(--gian-3)`, xuống một cột dưới `--gay-hep`. Nền `--mau-nen-noi`,
viền, bo `--bo-goc-lon`.

**Bộ lọc sống ở URL, không ở `useState`** (C-TS-03). Đây là quyết định thiết kế nhiều hơn
là kỹ thuật: người dùng ERP gửi link màn đã lọc cho đồng nghiệp, và bấm F5 mà mất bộ lọc
là một trong những thứ gây bực nhất trong phần mềm nội bộ. Tên tham số trên URL trùng đúng
tên tham số API (C-API-04) — không có lớp dịch ở giữa.

Khi có bộ lọc đang bật, hiện số điều kiện và một nút **Xóa lọc**. Không có nó, một màn
"rỗng" do lọc sót sẽ bị đọc thành "hệ thống mất dữ liệu".

## `Bang`

```tsx
export interface BangProps<T> {
  cot: Array<{
    khoa: string;
    nhan: string;
    kieu?: 'chu' | 'so' | 'ma' | 'trang-thai' | 'thao-tac';
    ve?: (dong: T) => ReactNode;
  }>;
  dong: readonly T[];
  layKhoa: (dong: T) => string;
  dangTai?: boolean; // lan dau
  dangLamMoi?: boolean; // refetch nen
  loi?: unknown;
  onThuLai?: () => void;
  manRong?: ReactNode; // BAT BUOC neu nguoi dung tao duoc ban ghi moi
}
```

`Bang` lo **khung và năm trạng thái**; nội dung từng cột là chuyện của module. Đó là ranh
giới giữ cho nó không phình thành một thứ biết mọi nghiệp vụ.

Năm trạng thái, và mỗi cái phải trông khác hẳn nhau:

| Trạng thái | Hiện gì |
|---|---|
| Đang tải lần đầu | `KhungXuong` đúng số cột — **không** phải chữ "Đang tải..." |
| Rỗng | `manRong`, kèm đường tạo mới |
| Lỗi | `BangThongBao` + nút thử lại, thay cho cả bảng |
| Có dữ liệu | Bảng |
| Đang làm mới nền | **Giữ nguyên dữ liệu cũ**, thêm một dải mảnh trên đầu bảng |

Trạng thái cuối là chỗ hay bị làm sai nhất: nhấp về rỗng rồi hiện lại khi đổi trang làm màn
hình giật và làm người dùng tưởng mất dữ liệu. TanStack Query đã có sẵn lời giải —
`placeholderData: (prev) => prev` — và `isFetching` là thứ dùng cho dải báo nhẹ, `isPending`
mới là "chưa có gì để hiện".

Kiểu cột quyết định hình thức, không cần nơi gọi tự nhớ: `so` → canh phải + `tabular-nums`;
`ma` → `MaBanGhi`; `trang-thai` → `NhanTrangThai`; `thao-tac` → canh phải, cột cuối, nút
kiểu `mo`.

Trên màn hẹp, bảng cuộn ngang trong khung riêng của nó (`overflow-x: auto`) — **thân trang
không bao giờ cuộn ngang**. Cột mã dính bên trái khi cuộn: mất cột mã là mất luôn manh mối
dòng đang đọc là dòng nào.

## `PhanTrang`

```tsx
export interface PhanTrangProps {
  meta: Meta; // { total, page, page_size } - dung ba field R-12 bat backend tra ve
  onDoiTrang: (trang: number) => void;
  onDoiCoTrang?: (coTrang: number) => void;
}
```

Trái: `Hien 21-40 trong 137 muc`. Phải: trước/sau + ô chọn số dòng.

Tổng số trang tính từ `meta.total`, **không** từ `dong.length` — mảng chỉ chứa một trang,
nên chia trên nó luôn ra "1 trang" (C-TS-04). Nút trước/sau khóa ở hai đầu, và giữ nguyên
chỗ khi khóa: nút nhảy chỗ làm người dùng bấm nhầm.

## `ManRong`

```tsx
export interface ManRongProps {
  tieuDe: string; // "Chua co vat tu nao"
  moTa?: string; // mot cau noi vi sao trong va lam gi tiep
  hanhDong?: ReactNode; // duong ra - gan nhu luon can
}
```

Màn rỗng là **lời mời**, không phải thông báo. Phân biệt hai ca rỗng và nói khác nhau, vì
đường ra của chúng khác nhau: chưa có dữ liệu bao giờ → mời tạo mới; có dữ liệu nhưng bộ
lọc không khớp → mời xóa lọc.

Không dùng minh họa lớn, không dùng emoji. Một dòng tiêu đề, một dòng mô tả, một nút.

## `KhungXuong`

```tsx
export interface KhungXuongProps {
  dang: 'dong-bang' | 'the' | 'dong-chu';
  soLuong?: number;
}
```

Khối nền `--mau-nen-nhat` bo `--bo-goc`, hiệu ứng nhấp nháy chậm **1.5s** và tự tắt khi
`prefers-reduced-motion`.

Khung xương hơn vòng xoay ở một điểm cụ thể: nó giữ nguyên chiều cao của thứ sắp hiện, nên
màn hình không nhảy khi dữ liệu về. Đổi lại, nó chỉ đúng khi ta **biết trước hình dạng** —
cho một danh sách hay một thẻ thì đúng, cho một thao tác không biết trả về gì thì dùng chữ
trong nút (`dangChay`).

## `HopThoaiXacNhan`

```tsx
export interface HopThoaiXacNhanProps {
  moTa: string; // hau qua CU THE, khong phai "Ban chac chu?"
  chuNutXacNhan: string; // dong nghia voi viec se xay ra: "Xoa vat tu"
  nguyHiem?: boolean;
  dangChay?: boolean;
  onXacNhan: () => void;
  onHuy: () => void;
}
```

Dùng `<dialog>` của trình duyệt — nó lo sẵn bẫy tiêu điểm, phím `Esc` và lớp nền, không
cần thư viện. Tiêu điểm vào nút **Hủy** khi mở (an toàn là mặc định), và trả về đúng chỗ
cũ khi đóng.

Chữ trên nút nói **việc sẽ xảy ra**, không phải "OK": người ta đọc nút chứ không đọc câu
hỏi. Mô tả nói hậu quả cụ thể — *"Xóa vật tư VT-001. Các dòng chuyển động trỏ tới vật tư
này vẫn còn."* — vì trong hệ này xóa là xóa mềm (R-18) và người dùng cần biết chính xác
cái gì mất, cái gì ở lại.

Không dùng `window.confirm`: nó chặn cả luồng, không tạo dáng được, và không test được.
Với thao tác nguy hiểm nằm trong một dòng bảng, mẫu xác nhận hai bước ngay trên dòng (đã
dùng ở `StockItemListPage`) là lựa chọn tốt hơn hộp thoại — nó giữ ngữ cảnh dòng đang xóa.
