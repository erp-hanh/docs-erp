# Màn lập phiếu dựng lại theo mẫu MISA - kế hoạch thi công

> **Cho agent thi công:** dùng `superpowers:subagent-driven-development`. Mỗi task một subagent
> mới, soi giữa các task. Bước đánh dấu bằng `- [ ]`.

**Mục tiêu:** Dựng lại màn lập phiếu nhập / xuất / chuyển kho theo mẫu MISA AMIS mà người
dùng đã duyệt, và đổi cách thêm dòng: dòng trống nằm sẵn trong bảng với đủ mọi ô, chọn hàng
xong là dòng thành dòng thật.

**Nhánh:** `fix/bang-cot` (frontend-erp). Worktree đang dùng:
`C:/Users/ACER/AppData/Local/Temp/claude/d--My-project-web-erp/2b2138d9-d20e-4b35-9d09-fdf53e383161/scratchpad/wt-bang`

**Mockup đã duyệt:** `mockup-erp/phieu-form-bo-cuc.html`, tab "A - Theo mẫu MISA".
Đăng ở https://claude.ai/code/artifact/e87e3120-162c-4dc9-9a9f-2661233c326f

**Ảnh mẫu gốc:** ba ảnh chụp AMIS người dùng gửi ngày 2026-09-02 - phiếu nhập NK00429 (bố
cục chung), phiếu nhập NK00429 với bảng chọn hàng đang mở, phiếu xuất XK00725 với bảng chọn
kho đang mở.

---

## Kiến trúc: hai quyết định gốc

### QĐ-1. Dòng trống là một dòng THẬT trong `values.dong`

Hôm nay `<HangThemMoi>` là một `<tr>` riêng giữ state cục bộ (`vatTu`, `soLuong`, `donGia`),
và chỉ khi bấm dấu cộng thì `onThem` mới đẩy một dòng vào `values.dong`. Đó là nguồn của
đúng cái người dùng chê: hàng đó không có đủ ô, không giống dòng trên, và phải bấm thêm một
nút.

Từ nay `values.dong` LUÔN kết thúc bằng một dòng có `stock_item_id === ''`. `<HangThemMoi>`
bị xoá hẳn; `<HangDongPhieu>` vẽ được cả dòng chưa gõ. Chọn mặt hàng cho dòng cuối thì một
dòng trống mới tự nối vào sau.

Hệ quả phải xử lý ở ba chỗ, và bỏ sót chỗ nào là một lỗi thật:
1. `validatePhieuForm` phải bỏ qua dòng chưa gõ, không thì mở màn ra đã có bốn câu lỗi đỏ.
2. Thân request phải lọc dòng chưa gõ ra, không thì mọi tờ phiếu ra 422.
3. Lỗi `dong` ("phải có ít nhất một dòng") phải đếm dòng ĐÃ GÕ, không đếm `values.dong.length`.

**Định nghĩa "đã gõ"** - hàm mới `dongDaGo(one: DongPhieuFormValues): boolean`:

```ts
export function dongDaGo(one: DongPhieuFormValues): boolean {
  return one.stock_item_id !== '' || one.soLuong !== '' || one.donGia !== '';
}
```

Ba vế chứ không riêng `stock_item_id`: người gõ số lượng rồi quên chọn hàng phải thấy câu
"Chọn vật tư hàng hoá", không được im lặng nuốt mất dòng đó.

### QĐ-2. Bỏ `khoMacDinh` và `khoDichMacDinh`

Người dùng chốt "chọn kho cho từng dòng", đúng như mẫu. Hai ô ở đầu phiếu biến mất, hai
khoá biến mất khỏi `PhieuFormValues`, nhãn `nhanKhoMacDinh` biến mất khỏi `NhanPhieu`. Dòng
mới mở ra với `warehouse_id === ''`.

---

## Ngoài phạm vi đợt này

- **Vùng Đính kèm tệp.** Mockup có vẽ, nhưng `backend-erp` chưa có endpoint tải lên, chưa có
  chỗ lưu, chưa có bảng ghi tệp thuộc phiếu nào (đã grep cả repo ngày 2026-09-02, không một
  chỗ nào khớp `attachment|upload|multipart`). Backend phải làm trước. Đợt riêng.
- **"Thêm mới (F9)"** trong bảng xổ - tạo vật tư / tạo kho ngay trong phiếu.
- **Phân trang bảng dòng hàng.** Mẫu có, hệ này bỏ: một tờ phiếu hiếm khi quá 20 dòng, mà
  cắt trang thì người dùng bấm Ghi trong lúc đang nhìn nửa số dòng.
- **Tám bảng ngoài Kho vận** vẫn dùng API cũ của `<Bang>` - việc còn tồn từ đợt trước.

---

## Bản đồ file

| File | Đổi gì |
|---|---|
| `src/modules/inventory/components/phieu-form-values.ts` | bỏ 2 khoá kho mặc định, thêm `dongDaGo`, dòng trống trong `giaTriMoPhieu`/`giaTriPhieuKeTiep`, `validatePhieuForm` bỏ qua dòng chưa gõ |
| `src/modules/inventory/components/phieu-form-values.test.ts` | theo |
| `src/modules/inventory/pages/PhieuFormPage.tsx` | bỏ 2 ô kho, sắp lại đầu phiếu theo mẫu, tổng tiền lên góc phải, `themDong` thành `noiDongTrong`, thân request lọc dòng chưa gõ |
| `src/modules/inventory/pages/PhieuFormPage.module.css` | khuôn đầu phiếu mới: dải nền chìm, lưới trái 2 cột + phải 240px + tổng |
| `src/modules/inventory/pages/PhieuFormPage.test.tsx` | theo |
| `src/modules/inventory/components/BangDongPhieu.tsx` | xoá `HangThemMoi`, `HangDongPhieu` vẽ được dòng chưa gõ, dải nút dưới bảng, hàng tổng trong bảng |
| `src/modules/inventory/components/BangDongPhieu.module.css` | mọi ô có viền, khối có tên khối, dải nút |
| `src/modules/inventory/components/ChonVatTu.tsx` | bảng xổ có cột Tồn kho |
| `src/modules/inventory/components/ChonKho.tsx` | dùng được TRONG một ô bảng, bảng xổ có cột Tồn kho |
| `src/shared/components/OTraCuu/*` (tên thật cần xác minh ở Task 0) | mũi tên xổ hiện khi rê chuột hoặc có tiêu điểm |

---

## Task 0 - ĐÃ XONG, đây là kết quả

Mốc test trước khi sửa: **50/50 file, 1036/1036 bài xanh, exit 0** trên `src/modules/inventory`.
Cây sạch, nên mọi bài đỏ sau này là do đợt này.

`--reporter=basic` KHÔNG tồn tại ở vitest 4.1.10 - nó chết lúc khởi động và trả exit 1 mà
không chạy bài nào. Dùng `--reporter=dot`.

Ba phát hiện đổi phạm vi của Task 3 và Task 4:

1. **`OTraCuu` chưa có chỗ cắm cột thứ ba.** File thật:
   `src/shared/components/OTraCuu/OTraCuu.tsx`. `MucTraCuu` chỉ có `{ id, ma, ten }`; danh
   sách là `<ul role="listbox"> <li role="option"> <button>` với chữ chạy một dòng, CSS
   `display: block` chứ không grid; `OTraCuuProps` không có `renderMuc` hay `cotPhu`. Thêm cột
   Tồn kho phải sửa cả ba chỗ: kiểu `MucTraCuu`, JSX của `<li>`, và CSS `.ds li button`.
   Đây là component DÙNG CHUNG - ba màn khác đang gọi nó, nên cột phụ phải là tuỳ chọn.

2. **Dòng đã gõ hôm nay KHÔNG sửa lại được mặt hàng.** Ô Mã hàng và ô Tên hàng cùng vẽ bằng
   `TenMatHang` (chữ trần trong `<span>`, đọc `useStockItemDetail`). Mẫu MISA để ô mã hàng
   luôn là ô sửa được, nên Task 3 là một đổi HÀNH VI chứ không chỉ đổi hình dạng: gõ nhầm
   mặt hàng thì sửa ngay trên dòng thay vì xoá dòng rồi gõ lại.

3. **`StockBalanceDTO` mang đủ thứ cần.** `warehouse_id`, `warehouse_code`, `warehouse_name`,
   `stock_item_id/code/name`, `quantity` (chuỗi, có thể âm). Bảng chọn kho kèm tồn lấy được
   cả tên kho lẫn số tồn từ MỘT lời gọi `useBalanceList({ stock_item_id })`, không phải ghép
   thêm danh mục kho. Lưu ý `useBalanceList(params, false)` giữ `isPending === true` mãi -
   hỏi `data`, đừng vẽ khung xương theo `isPending`.

## Task 0 (bản gốc): Đọc trước khi sửa

Không sửa gì. Chỉ để subagent đầu tiên nạp đủ ngữ cảnh và báo lại.

- [ ] Đọc `BangDongPhieu.tsx` trọn vẹn (897 dòng) và ghi lại: `HangDongPhieu` nhận props gì,
      cột nào vẽ có điều kiện theo `laChuyen` / `layHangRaKho` / `coODonGia`, `soCot` tính ra sao.
- [ ] Tìm component tra cứu dùng chung mà `ChonVatTu` / `ChonKho` / `ChonDoiTac` cùng gói vào
      (grep `MucTraCuu`), ghi lại đường dẫn thật và chữ ký của nó.
- [ ] Đọc `use-balance-list.ts`: `BalanceListParams` lọc được theo `stock_item_id` không, và
      một mục trả về mang `warehouse_id` không.
- [ ] Chạy `npx vitest run src/modules/inventory --reporter=basic > /tmp/truoc.txt 2>&1; echo $?`
      và ghi lại số bài xanh. **Ghi ra file rồi đọc mã thoát tách khỏi pipe** - `| tail` nuốt
      mã thoát của vitest.
- [ ] Báo lại ba điều trên. KHÔNG sửa file nào.

---

## Task 1: `dongDaGo` và dòng trống trong `phieu-form-values.ts`

**Files:** sửa `components/phieu-form-values.ts`, `components/phieu-form-values.test.ts`

- [ ] **Bước 1 - viết test đỏ trước.** Thêm vào `phieu-form-values.test.ts`:

```ts
describe('dòng trống cuối bảng', () => {
  it('phiếu vừa mở đã có sẵn một dòng trống', () => {
    const v = giaTriMoPhieu(new Date('2026-09-02T10:00:00Z'));
    expect(v.dong).toHaveLength(1);
    expect(v.dong[0]!.stock_item_id).toBe('');
  });

  it('dòng trống KHÔNG sinh lỗi nào', () => {
    const v = giaTriMoPhieu(new Date('2026-09-02T10:00:00Z'));
    const loi = validatePhieuForm({ ...v, ngay_phieu: '2026-09-02T10:00' }, 'nhap');
    expect(loi['dong[0].stock_item_id']).toBeUndefined();
    expect(loi['dong[0].warehouse_id']).toBeUndefined();
    expect(loi['dong[0].quantity']).toBeUndefined();
  });

  it('nhưng phiếu chỉ có dòng trống thì vẫn thiếu dòng hàng', () => {
    const v = giaTriMoPhieu(new Date('2026-09-02T10:00:00Z'));
    const loi = validatePhieuForm({ ...v, ngay_phieu: '2026-09-02T10:00' }, 'nhap');
    expect(loi.dong).toBe('Phiếu phải có ít nhất một dòng hàng');
  });

  it('gõ số lượng mà quên chọn hàng thì dòng đó BỊ kiểm', () => {
    const v = giaTriMoPhieu(new Date('2026-09-02T10:00:00Z'));
    v.dong[0]!.soLuong = '5';
    const loi = validatePhieuForm({ ...v, ngay_phieu: '2026-09-02T10:00' }, 'nhap');
    expect(loi['dong[0].stock_item_id']).toBe('Chọn vật tư hàng hoá');
  });
});
```

- [ ] **Bước 2 - chạy, xác nhận đỏ.**
      `npx vitest run src/modules/inventory/components/phieu-form-values.test.ts > /tmp/r.txt 2>&1; echo $?`
      Chờ: đỏ, `v.dong` có 0 phần tử.

- [ ] **Bước 3 - sửa `phieu-form-values.ts`.**
  - Bỏ `khoMacDinh` và `khoDichMacDinh` khỏi `PhieuFormValues` cùng khối chú thích của chúng.
  - `giaTriMoPhieu`: `dong: [dongMoi('', '', '')]`.
  - `giaTriPhieuKeTiep`: cùng vậy; bỏ hai dòng chép `khoMacDinh` / `khoDichMacDinh`.
  - Thêm `dongDaGo` theo đúng thân đã viết ở mục QĐ-1, kèm một khối chú thích nói ra vì sao
    ba vế chứ không một vế.
  - `validatePhieuForm`: đổi `values.dong.length === 0` thành `values.dong.filter(dongDaGo).length === 0`;
    trần `MAX_DONG_PHIEU` cũng đếm theo dòng đã gõ; vòng `forEach` bọc bằng `if (!dongDaGo(one)) return;`.
    Chỉ số `i` GIỮ NGUYÊN chỉ số trong `values.dong` - tên ô lỗi phải khớp vị trí thật trên
    màn hình, không phải vị trí sau khi lọc.

- [ ] **Bước 4 - chữa các test cũ vừa đỏ theo.** `phieu-form-values.test.ts` dòng 31 và 143
      đang khai / kiểm `khoMacDinh`. Bỏ hai chỗ đó. Mọi test cũ dựng `values` bằng
      `giaTriMoPhieu` rồi `push` dòng phải tính thêm dòng trống ở cuối.

- [ ] **Bước 5 - chạy lại, xác nhận xanh**, rồi commit:
      `git commit -m "refactor(phieu): dong trong nam san trong values.dong, bo kho mac dinh"`

---

## Task 2: `PhieuFormPage` theo mô hình mới

**Files:** sửa `pages/PhieuFormPage.tsx`, `pages/PhieuFormPage.test.tsx`

- [ ] **Bước 1 - test đỏ.** Trong `PhieuFormPage.test.tsx` thêm:

```ts
it('mở màn ra là đã có một dòng trống trong bảng, không có ô nhập rời nào', async () => {
  veMan('nhap');
  expect(await man.findByRole('row', { name: /dòng trống/i })).toBeTruthy();
  expect(man.queryByLabelText('Mặt hàng của dòng mới')).toBeNull();
});

it('chọn mặt hàng cho dòng cuối thì một dòng trống mới nối vào sau', async () => {
  // ... chọn vật tư ở dòng 1, rồi đếm số <tr> trong tbody: phải thành 2
});
```

- [ ] **Bước 2 - chạy, xác nhận đỏ.**

- [ ] **Bước 3 - sửa `PhieuFormPage.tsx`.**
  - Bỏ khối JSX của ô "Kho mặc định" (quanh dòng 445-457) và ô "Kho đích mặc định"
    (quanh dòng 460-485).
  - Bỏ `khoMacDinh` / `khoDichMacDinh` khỏi props truyền xuống `<BangDongPhieu>`.
  - Xoá `themDong`. Thay bằng: `suaDong` tự nối dòng trống khi dòng CUỐI vừa được gán
    `stock_item_id` khác rỗng:

```ts
function suaDong(chiSo: number, patch: Partial<DongPhieuFormValues>) {
  setValues((truoc) => {
    const sau = truoc.dong.map((one, i) => (i === chiSo ? { ...one, ...patch } : one));
    const cuoi = sau[sau.length - 1];
    // Dòng trống ở cuối là chỗ gõ tiếp. Ngay khi nó có mặt hàng, nó thành một dòng thật và
    // bảng phải mọc ra một chỗ gõ mới - không thì người dùng gõ xong dòng cuối là hết đường.
    if (cuoi !== undefined && cuoi.stock_item_id !== '') sau.push(dongMoi('', '', ''));
    return { ...truoc, dong: sau };
  });
  setDangHoiHuy(false);
}
```

  - `boDong`: xoá dòng cuối cùng còn lại thì để lại một dòng trống, bảng không bao giờ rỗng:

```ts
function boDong(chiSo: number) {
  setValues((truoc) => {
    const sau = truoc.dong.filter((_, i) => i !== chiSo);
    return { ...truoc, dong: sau.length === 0 ? [dongMoi('', '', '')] : sau };
  });
}
```

  - Thân request: `dong: values.dong.filter(dongDaGo).map((one) => ({ ... }))`.
  - `soDong` (đếm cho dải tổng và cho câu nhắc ở chân) đổi thành `values.dong.filter(dongDaGo).length`.
  - `tongTienHang` cũng chỉ cộng dòng đã gõ.

- [ ] **Bước 4 - chữa test cũ.** `PhieuFormPage.test.tsx` dòng 478 kiểm thân request không
      chứa `khoMacDinh` - giữ, nó vẫn đúng. Mọi test dựng phiếu qua ô "Mặt hàng của dòng mới"
      rồi bấm "Thêm dòng này vào phiếu" phải viết lại theo lối mới: gõ thẳng vào ô mã hàng
      của dòng cuối.

- [ ] **Bước 5 - xanh rồi commit:**
      `git commit -m "feat(phieu): dong moi hien ngay trong bang, bo hai o kho mac dinh"`

---

## Task 3: `BangDongPhieu` - xoá `HangThemMoi`, dòng chưa gõ vẫn đủ ô

**Files:** sửa `components/BangDongPhieu.tsx`, `components/BangDongPhieu.module.css`

- [ ] **Bước 1 - test đỏ**: một dòng chưa gõ phải có đủ chín ô `<td>` như dòng đã gõ. Đếm
      `row.querySelectorAll('td').length` của dòng đầu và dòng cuối, hai số phải bằng nhau.
      **Đếm ô, không đếm chữ** - test đọc `textContent` không thấy ô rỗng.

- [ ] **Bước 2 - chạy, xác nhận đỏ.**

- [ ] **Bước 3 - sửa.**
  - Xoá hẳn hàm `HangThemMoi` (dòng ~721-897), xoá props `khoMacDinh` / `khoDichMacDinh` /
    `onThem` khỏi `BangDongPhieuProps`, xoá hằng `TEN_O_VAT_TU_MOI` / `ID_O_TIM_VAT_TU_MOI`
    nếu không còn chỗ nào dùng.
  - Xoá nhánh `dong.length === 0` cùng `<ManRong>`: bảng không bao giờ rỗng nữa.
  - `HangDongPhieu` ô Mã hàng: khi `gia.stock_item_id === ''` thì vẽ `<ChonVatTu>`; khi đã có
    thì vẫn vẽ `<ChonVatTu>` với `value` đã chọn - MỘT lối vẽ, không hai. Đổi mặt hàng của
    một dòng đã gõ là việc có thật.
  - Ô Tên hàng và ô Thành tiền: `<input readOnly>` nền chìm thay cho chữ trần, đúng mẫu.
    **Bẫy:** test cũ tìm tên hàng bằng `getByText` sẽ đỏ - đổi sang `getByDisplayValue`.
  - Ô ĐVT giữ nguyên `<ChonDonViGhi>` (mẫu để nó là ô chọn, hệ này cũng vậy).
  - Cột Thao tác: nút xoá dòng ở MỌI dòng, kể cả dòng trống.

- [ ] **Bước 4 - xanh, commit:**
      `git commit -m "refactor(bang-dong): bo HangThemMoi, dong chua go van du cot"`

---

## Task 4: Ô Kho và ô Mã hàng xổ bảng chọn có cột Tồn kho

**Files:** sửa `components/ChonKho.tsx`, `components/ChonVatTu.tsx`, component tra cứu dùng
chung (đường dẫn từ Task 0)

Theo ảnh mẫu XK00725: bấm vào ô Kho thì mũi tên xổ hiện ra và mở một bảng có ba cột
`Mã kho | Tên kho | Số lượng tồn`, dòng đang trỏ bôi nền nhạt, chân bảng có công tắc
"Chỉ hiển thị kho còn tồn".

- [ ] **Bước 1 - test đỏ**: mở bảng chọn kho của một dòng đã có mặt hàng, cột tồn hiện số của
      cặp (kho, mặt hàng) đó.
- [ ] **Bước 2 - chạy, xác nhận đỏ.**
- [ ] **Bước 3 - sửa.** `ChonKho` nhận thêm prop `stockItemId?: string`; khi có thì gọi
      `useBalanceList({ stock_item_id })` và ghép tồn vào từng mục theo `warehouse_id`. Không
      có `stockItemId` (ô kho ở màn khác) thì cột tồn không vẽ - không gọi API thừa.
      `ChonVatTu` làm tương tự nhưng ghép theo `stock_item_id`, và chỉ khi dòng đã có kho.
- [ ] **Bước 4 - công tắc "Chỉ hiện kho còn tồn"**: chỉ vẽ ở phiếu xuất và phiếu chuyển. Ở
      phiếu nhập, lọc như vậy là giấu mất hàng mới - đừng vẽ.
- [ ] **Bước 5 - xanh, commit.**

---

## Task 5: Mũi tên xổ hiện khi bấm vào ô

**Files:** component tra cứu dùng chung + CSS module của nó

- [ ] Mũi tên `opacity: 0` lúc thường, `opacity: 1` khi `:hover` hoặc `:focus-within`; lật
      lên khi bảng đang mở. Nhịp `var(--nhip-nhanh)`.
- [ ] `pointer-events: none` trên mũi tên: nó là dấu hiệu, không phải nút. Bấm vào ô là mở.
- [ ] Không dùng ký tự `▾` - SVG nội tuyến, nét 1.6px, khung 20px, theo
      `src/shared/components/bieu-tuong.tsx`.
- [ ] Test: mũi tên có mặt trong DOM ngay cả lúc mờ (kiểm bằng class, **không bằng
      `textContent`** - chữ bị CSS giấu thì test vẫn thấy).
- [ ] Commit.

---

## Task 6: Bố cục đầu phiếu theo mẫu

**Files:** sửa `pages/PhieuFormPage.tsx`, `pages/PhieuFormPage.module.css`

- [ ] Đầu phiếu thành một **dải nền chìm** (`--mau-nen`), không thẻ trắng, không tiêu đề
      nhóm "Thông tin chung".
- [ ] Lưới ba cột: `minmax(0, 1fr) 240px 180px`.
  - Trái (lưới con 2 cột): Đối tác | Người giao nhận, rồi Diễn giải chiếm cả hàng, rồi
    "Kèm theo [ô] chứng từ gốc" thành một câu nằm ngang.
  - Giữa: Ngày phiếu, Số phiếu (kèm nút xin số kế tiếp).
  - Phải: **Tổng tiền hàng**, chữ số lớn, canh phải. Chỉ ở phiếu nhập.
- [ ] Dưới 900px lưới sập về một cột.
- [ ] Bỏ mọi dòng gợi ý dài dưới ô, thay bằng dấu `?` cạnh nhãn mang `title`. Giữ lại đúng
      hai gợi ý đáng giữ: số phiếu chưa được giữ chỗ, và "Kèm theo" là số đếm không phải tiền.
- [ ] Bỏ khối chú thích xanh ba dòng trên bảng, bỏ đoạn nhắc ba dòng dưới tổng tiền. Câu
      nhắc "sai một dòng thì cả phiếu không vào sổ" GIỮ ở chân - nó nói một mệnh đề của
      backend, không phải một mẹo dùng.
- [ ] Chân phiếu `position: sticky; bottom: 0`.
- [ ] Chạy `node ../.claude/skills/frontend-design-erp/scripts/kiem-giao-dien.mjs` - không
      giá trị màu thô, không `px` ngoài `--gian-*`, không `outline: none` trần, không emoji.
- [ ] Commit.

---

## Task 7: Hàng tổng trong bảng + dải nút dưới bảng

**Files:** sửa `components/BangDongPhieu.tsx`, `.module.css`, `pages/PhieuFormPage.tsx`

- [ ] Hàng tổng thành một `<tr>` cuối `<tbody>`: cộng Số lượng và Thành tiền, canh đúng cột,
      không nhãn - đúng mẫu. Bỏ dải `.tong-phieu` hiện nằm dưới bảng.
- [ ] Dưới bảng: dải `Tổng số: N`, rồi hàng nút **Thêm dòng** / **Xoá hết dòng** có viền và
      icon. "Xoá hết dòng" phải hỏi lại tại chỗ trước khi xoá - cùng lối hai bước mà nút
      "Huỷ phiếu" đang dùng, không `window.confirm`.
- [ ] Commit.

---

## Trước khi nói là xong

- [ ] `npm run lint`
- [ ] `npm run arch` - đỏ vì thêm file mới là bình thường, chạy `npm run arch:update` rồi
      commit `arch/LEVELS.md`. **Chỉ frontend mới chạy được `arch:update` dưới Windows.**
- [ ] `npx vitest run > /tmp/sau.txt 2>&1; echo $?` - ghi ra file rồi đọc mã thoát tách khỏi
      pipe. Đối chiếu với số của Task 0.
- [ ] `superpowers:verification-before-completion` kèm output làm bằng chứng.
- [ ] Deploy nhánh lên dev rồi soi bằng agent-browser. **Đóng phiên browser cũ rồi mở lại** -
      tab đang mở vẫn chạy bundle JS cũ.
- [ ] `superpowers:requesting-code-review` trước khi merge.

## Bẫy đã biết

- Dự án KHÔNG dùng prettier. Đừng chạy `npx prettier --write`.
- Cây làm việc dùng chung nhiều phiên: **cấm `git add -A`**, add từng đường dẫn.
- Chữ hiển thị viết tiếng Việt CÓ DẤU.
- `npx vitest run | tail` báo exit 0 trong khi bài đỏ.
