# Tùy chỉnh cột trên bảng - kế hoạch thi công

Ngày 2026-09-01. Nhánh `fix/bang-cot` (frontend-erp), nhánh gốc `feat/ngung-su-dung-phan-vung`.

## Vì sao có việc này

Người dùng thấy bảng ở /nhap-kho, /xuat-kho, /chuyen-kho kẻ lệch, và yêu cầu ba thứ:

1. Ẩn cột "Mã kho" ở các bảng.
2. Cho người dùng tự chọn cột nào hiện, cột nào ẩn.
3. Cho đổi thứ tự cột và kéo to nhỏ cột.

Lỗi kẻ lệch đã sửa riêng ở commit `c012f95` (bề rộng gắn vào chính ô thay vì đếm
`nth-child`). Yêu cầu 1 trở thành một giá trị mặc định của bộ tùy chỉnh cột, không phải một
đợt sửa riêng.

## Mẫu để bám: MISA AMIS Kế toán

`helpact.misa.vn/kb/tuy-chinh-giao-dien-danh-sach-co-san-tren-phan-mem/`:

- Nút bánh răng "Tùy chỉnh giao diện" trên chính màn danh sách.
- Tick chọn cột hiện / ẩn.
- Sửa tên cột hiển thị và độ rộng.
- Kéo biểu tượng chín chấm ở đầu mỗi dòng để đổi thứ tự cột.
- Chỉ những cột có trong hộp thoại mới hiện được; không tự thêm cột mới.

Hệ này cắt bớt phần "sửa tên cột hiển thị": tên cột là từ vựng nghiệp vụ đã chốt ở
`docs-erp/CONTEXT.md`, để mỗi người đặt một tên khác nhau là mở đường cho hai người nói về
cùng một cột bằng hai tên. Giữ lại: ẩn/hiện, thứ tự, độ rộng.

Người dùng đã chốt (2026-09-01): kéo được ngay ở mép cột trên bảng, KHÔNG bắt mở hộp thoại
mới chỉnh được độ rộng; hộp thoại vẫn có ô nhập số cho ai muốn gõ chính xác.

## Phạm vi đợt này: bảy bảng của Kho vận

| Màn | Đường | Ghi chú |
|---|---|---|
| Sổ phiếu | /phieu, /nhap-kho, /xuat-kho, /chuyen-kho, /dieu-chinh | Một component, năm đường; số cột đã thay đổi theo `loaiCoDinh` |
| Chi tiết phiếu (bảng dòng) | /phieu/:id | Số cột thay đổi theo phiếu chuyển |
| Sổ chuyển động | /chuyen-dong | Có cột Mã kho |
| Tồn kho | /ton-kho | Có cột Mã kho |
| Vật tư hàng hoá | /vat-tu | |
| Kho | /kho | |
| Đối tác | /doi-tac | |

Tám bảng còn lại (quản trị, người dùng, vai trò, phân vùng, thiết bị) giữ nguyên API cũ của
`<Bang>` - lan sang chúng ở đợt sau.

## Thiết kế

### 1. `<Bang>` nhận ĐỊNH NGHĨA CỘT thay vì các `<th>` viết tay

API cũ (`dauBang` nhận `<th>`, `children` nhận `<tr>`) không có gì để ẩn hay xếp lại: ô của
thân do màn dựng theo thứ tự cứng trong JSX. API mới đi kèm, API cũ giữ nguyên cho tám màn
chưa chuyển.

```ts
export interface CotBang<T> {
  ma: string;            // khoá ổn định, dùng để lưu; KHÔNG đổi khi đổi nhãn
  nhan: string;
  rong: number;          // bề rộng mặc định, tính bằng phần trăm
  ve: (hang: T) => ReactNode;
  so?: boolean;          // căn phải + tabular-nums
  catChu?: boolean;      // một dòng, cắt bằng dấu ba chấm
  coDinh?: boolean;      // không cho ẩn (cột định danh, cột Thao tác)
  anMacDinh?: boolean;   // có trong hộp thoại nhưng mặc định không hiện
  tieuDeDay?: string;    // title của <th> khi nhãn viết tắt (VTHH)
}
```

`<Bang cot={COT} hang={rows} khoa={(h) => h.id} maBang="so-phieu" />`. `maBang` là khoá lưu;
thiếu nó thì bảng chạy như cũ, không có nút tùy chỉnh.

### 2. Ô GỘP (`colSpan`) phải biến mất

Bốn bảng hiện dùng `<td colSpan={2}>` cho cặp mã + tên khi bản ghi bị xoá mềm. Một ô gộp
làm hai việc xấu: nó nuốt vạch kẻ dọc giữa hai cột (`co-so.css` cho
`tbody td:not(:last-child) { border-right }`), và nó khoá cứng hai cột phải đứng cạnh nhau -
tức chống lại chính việc đổi thứ tự cột.

Thay bằng: cột Mã hiện nhãn trạng thái ("Không có đối tác" / "Đối tác đã bị xoá"), cột Tên
hiện dấu gạch mờ. Cùng lượng tin, không ô gộp. Đây là thay đổi NHÌN THẤY ĐƯỢC, cố ý.

### 3. Lưu lựa chọn

localStorage, khoá `erp:cot:<maBang>:<userId>`, theo đúng pattern `src/app/gan-day.ts`
(`userId` trong khoá vì máy ở kho dùng chung; mọi truy cập bọc try/catch vì localStorage ném
thật trong vài ca). Không thêm endpoint nào: đây là tiện lợi, mất không hỏng nghiệp vụ.

Bản ghi lưu:

```ts
{ thuTu: string[], an: string[], rong: Record<string, number> }  // rong tính bằng px
```

Hợp nhất với định nghĩa cột lúc đọc: cột lạ trong bản lưu thì bỏ qua, cột mới của bản cài
mới mà bản lưu chưa biết thì hiện theo `anMacDinh`. Không bao giờ ẩn cột `coDinh`.

### 4. Kéo mép cột

Tay cầm rộng 6px ở mép phải mỗi `<th>`, `cursor: col-resize`. `pointerdown` bắt con trỏ,
`pointermove` đổi bề rộng, `pointerup` lưu. Bề rộng đã kéo tính bằng px và thắng phần trăm
mặc định; sàn 48px để không ai kéo mất một cột.

### 5. Hộp thoại tùy chỉnh

`<HopTuyChinhCot>`: mỗi dòng một cột, gồm ô tick hiện/ẩn, nhãn, ô nhập độ rộng (px), tay
cầm kéo đổi thứ tự, và HAI NÚT lên/xuống - kéo bằng chuột một mình là khoá người dùng bàn
phím ra ngoài. Nút "Khôi phục mặc định" trả cả ba thứ về định nghĩa gốc.

## Các bước

1. **Hạ tầng** - `cot.ts` (kiểu + hợp nhất bản lưu), `luu-cot.ts` (localStorage),
   `HopTuyChinhCot.tsx`, và nhánh mới trong `Bang.tsx` + CSS.
   Verify: test của riêng ba file này xanh; `<Bang>` cũ không đổi hành vi (test cũ xanh).
2. **Màn mẫu: Sổ phiếu** (`VoucherListPage`) - chuyển sang `cot`, bỏ ô gộp.
   Verify: test màn xanh, kể cả bài về ba trạng thái đối tác đã viết lại theo hình mới.
3. **Sáu màn còn lại**, mỗi màn một việc độc lập, chạy song song tối đa ba.
   Verify: từng màn test xanh; cột Mã kho đặt `anMacDinh` ở sổ chuyển động, tồn kho, chi
   tiết phiếu.
4. **Chốt** - cả bộ test + `tsc` + `arch` + `lint` xanh, rồi deploy rc và soi thật trên máy
   dev bằng agent-browser (đo lại bề rộng cột như lần bắt lỗi).

## Đã biết trước, không phải phát hiện muộn

- `table-layout: fixed` lấy bề rộng từ hàng đầu, nên chỉ `<th>` cần lớp bề rộng; `<td>`
  không cần.
- Máy dev chạy HTTP nên mọi API cần secure context đều không có; localStorage KHÔNG thuộc
  nhóm đó, nó vẫn chạy.
- Test đọc `textContent` không thấy thứ bị CSS giấu. Bài test cột ẩn phải kiểm số `<th>` và
  `ma` của cột, không kiểm chuỗi chữ trôi nổi trong container.
