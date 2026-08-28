# Trang chi tiết vật tư - Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tách `/vat-tu/:id` thành một trang XEM (thông tin + tồn theo kho + chuyển động gần
đây), dời form sửa sang `/vat-tu/:id/sua`, cho bấm cả hàng ở bảng danh sách, và dựng lại bố
cục màn thêm vật tư.

**Architecture:** Một page mới `StockItemDetailPage` ghép ba khối độc lập, mỗi khối một
`useQuery` riêng và một nhánh lỗi riêng - một khối 403 không làm câm hai khối kia. Không đụng
`backend-erp`, không thêm endpoint, không thêm token CSS.

**Tech Stack:** React 19 + TypeScript + Vite + TanStack Query, router tự viết
(`src/app/router/`), CSS Modules, Vitest + `react-dom/client` (không testing-library).

**Spec:** `docs-erp/99-meta/my-specs/2026-08-28-vat-tu-chi-tiet-design.md`

---

## Quy ước chung cho mọi task

- Chữ hiển thị **tiếng Việt có dấu**. Ghi chú trong code viết theo lối của file đang sửa.
- Không giá trị màu thô, không `px` rời rạc - mọi khoảng cách qua `--gian-*`.
- Không `toLocaleString`/`Number()` trên `quantity`: đó là `NUMERIC(18,4)` về dưới dạng
  chuỗi, hiện **nguyên văn** (R-19, C-DB-02). `Intl.NumberFormat` chỉ được chạm `meta.total`.
- Test bám **class** hoặc thẻ, không bám `textContent` của thứ có thể bị CSS giấu.
- Lệnh test một file: `npm test -- src/modules/inventory/pages/StockItemDetailPage.test.tsx`
- Nhánh đã tạo sẵn ở cả hai repo: `feat/vat-tu-chi-tiet`. **Không** `git add -A` - cây làm
  việc dùng chung nhiều phiên, chỉ `git add` đúng đường dẫn của task.

---

### Task 1: Khung trang chi tiết + tách đường dẫn

Trang mới hiện khối thông tin chung, đường lui, nút Sửa và nút Xoá. Hai khối bảng để Task 2
và Task 3.

**Files:**
- Create: `frontend-erp/src/modules/inventory/pages/StockItemDetailPage.tsx`
- Create: `frontend-erp/src/modules/inventory/pages/StockItemDetailPage.module.css`
- Create: `frontend-erp/src/modules/inventory/pages/StockItemDetailPage.test.tsx`
- Modify: `frontend-erp/src/app/routes.tsx:224-226`

- [ ] **Step 1: Đọc hai file mẫu trước khi viết dòng nào**

`frontend-erp/src/modules/inventory/pages/StockItemFormPage.tsx` - lấy nguyên khuôn
`StockItemDetailError` (ba nhánh 403 / 404 / còn lại, `maTraCuu` vào ô riêng của
`BangThongBao`), khuôn `KhungXuongFormVatTu`, và hằng `DUONG_LUI`.

`frontend-erp/src/modules/inventory/pages/MovementDetailPage.tsx` - lấy khuôn `<dl>` của khối
thông tin và cách nó KHÔNG dùng class toàn cục `so` trên một `<dd>`.

- [ ] **Step 2: Viết test đỏ**

Tạo `StockItemDetailPage.test.tsx`. Chép nguyên khối hạ tầng của
`StockItemFormPage.test.tsx:6-70` (`makeResponse`, `dungMang`, `makeClient`, `container`,
`root`, `render`) rồi đổi phần trả lời của `fetch`. Ba mệnh đề của task này:

```tsx
it('hien ma, ten va don vi tinh cua vat tu', async () => {
  await render(<StockItemDetailPage id="si-1" />);
  expect(container.textContent).toContain('VT-1');
  expect(container.textContent).toContain('Thep tam');
  expect(container.textContent).toContain('Ki lo gam');
});

it('nut Sua tro toi duong sua', async () => {
  await render(<StockItemDetailPage id="si-1" />);
  const link = Array.from(container.querySelectorAll('a')).map((a) => a.getAttribute('href'));
  expect(link).toContain('/vat-tu/si-1/sua');
});

it('404 thi khong hien khoi thong tin, nhung duong lui van con', async () => {
  phanHoiVatTu = { status: 404, body: { error: { message: 'khong thay' }, request_id: 'rq' } };
  await render(<StockItemDetailPage id="si-1" />);
  expect(container.textContent).toContain('Không tìm thấy vật tư này');
  const link = Array.from(container.querySelectorAll('a')).map((a) => a.getAttribute('href'));
  expect(link).toContain('/vat-tu');
});
```

- [ ] **Step 3: Chạy test cho chắc là đỏ**

Run: `npm test -- src/modules/inventory/pages/StockItemDetailPage.test.tsx`
Expected: FAIL - `Failed to resolve import "./StockItemDetailPage"`

- [ ] **Step 4: Viết `StockItemDetailPage.tsx`**

Cấu trúc bắt buộc:

```tsx
export interface StockItemDetailPageProps {
  id: string;
}

export function StockItemDetailPage({ id }: StockItemDetailPageProps) {
  const { data, isPending, isFetching, error, refetch } = useStockItemDetail(id);
  const xoa = useDeleteStockItem();
  const [dangHoiXoa, setDangHoiXoa] = useState(false);

  return (
    <main>
      <TieuDeTrang
        tieuDe={data === undefined ? 'Chi tiết vật tư' : data.name}
        quayLai={<Link to="/vat-tu">&larr; Danh sách vật tư</Link>}
        canhTieuDe={data === undefined ? undefined : <MaBanGhi ma={data.code} />}
        hanhDong={data === undefined ? undefined : (/* nut Xoa hai buoc + link Sua */)}
      />
      {/* ... */}
    </main>
  );
}
```

Ba điều phải giữ đúng:

1. `<TieuDeTrang>` dựng **vô điều kiện**, trước cả phép kiểm lỗi - khi 404 hay 403 mà không
   có đường lui thì người dùng phải bấm Back của trình duyệt.
2. Nút Sửa là `<Link to={'/vat-tu/' + encodeURIComponent(id) + '/sua'}>`, KHÔNG kiểm quyền,
   KHÔNG đọc role (C-TS-06). 403 xử lý tại màn đến.
3. Nút Xoá xác nhận **hai bước ngay tại chỗ**, cùng mẫu `StockItemListPage.tsx:392-415`.
   Câu xác nhận nói hậu quả cụ thể vì xoá là xoá mềm (R-18):
   `Xoá vật tư {code}? Các dòng chuyển động trỏ tới vật tư này vẫn còn.`
   Xoá xong: `xoa.mutate(id, { onSuccess: () => navigate('/vat-tu') })` - `navigate` từ
   `@/app/router/navigate`.

Khối thông tin chung là một `<dl>` trong `<section className="the">`:

```tsx
<section className="the">
  <h2>Thông tin chung</h2>
  <dl className={styles['ho-so']}>
    <dt>Mã vật tư</dt>
    <dd><MaBanGhi ma={data.code} /></dd>
    <dt>Tên vật tư</dt>
    <dd>{data.name}</dd>
    <dt>Đơn vị tính</dt>
    <dd>
      {donViDaXoa(data) ? (
        <NhanTrangThai sac="canh-bao">Đơn vị tính đã bị xoá</NhanTrangThai>
      ) : (
        <>{data.unit_code} - {data.unit_name}</>
      )}
    </dd>
  </dl>
</section>
```

Ô đơn vị tính **không bao giờ để trống**: rỗng đọc y hệt "chưa điền", mà `unit_id` là
NOT NULL nên trạng thái đó không tồn tại được. Đây là cùng phép phân biệt `donViDaXoa()` mà
`StockItemListPage.tsx:383` đang dùng.

Nhánh lỗi: chép nguyên `StockItemDetailError` từ `StockItemFormPage.tsx:233-291`. Nhánh
`isPending` dùng khung xương ghép tay từ `<KhungXuong>` - ba dòng `<dt>/<dd>` cộng một câu
`chi-doc-man-hinh` `role="status"` "Đang tải vật tư." (mọi `<KhungXuong>` mang `aria-hidden`,
thiếu câu đó thì cả vùng câm với trình đọc màn hình). Nhánh `isFetching` thêm
`<p role="status" className="chi-doc-man-hinh">Đang cập nhật vật tư.</p>`.

- [ ] **Step 5: Viết `StockItemDetailPage.module.css`**

```css
.ho-so {
  display: grid;
  grid-template-columns: 12rem 1fr;
  gap: var(--gian-3) var(--gian-4);
  margin: 0;
}

.ho-so dt {
  color: var(--mau-chu-mo);
  font-size: var(--chu-sm);
}

.ho-so dd {
  margin: 0;
}

.bao-loi {
  margin-bottom: var(--gian-4);
}
```

Trên màn hẹp (`@media (max-width: 640px)`) đổi `grid-template-columns: 1fr` và `gap` còn
`var(--gian-1) 0`.

- [ ] **Step 6: Nối route**

Trong `frontend-erp/src/app/routes.tsx`, thay ba dòng `/vat-tu*` hiện có bằng:

```tsx
  { path: '/vat-tu', render: () => <StockItemListPage /> },
  { path: '/vat-tu/moi', render: () => <StockItemFormPage /> },
  { path: '/vat-tu/:id', render: (p) => <StockItemDetailPage id={p.id} /> },
  { path: '/vat-tu/:id/sua', render: (p) => <StockItemFormPage id={p.id} /> },
```

Thêm `import { StockItemDetailPage } from '@/modules/inventory/pages/StockItemDetailPage';`
cạnh các import page khác. Sửa khối ghi chú ngay trên đó (`routes.tsx:211-220`): luật "'moi'
phải đứng trước ':id'" vẫn đúng và vẫn phải giữ; thêm một câu nói `/vat-tu/:id/sua` ba đoạn
nên không tranh chấp với hai route hai đoạn.

- [ ] **Step 7: Chạy test cho chắc là xanh**

Run: `npm test -- src/modules/inventory/pages/StockItemDetailPage.test.tsx`
Expected: PASS, 3 test

- [ ] **Step 8: Commit**

```bash
git add src/modules/inventory/pages/StockItemDetailPage.tsx \
        src/modules/inventory/pages/StockItemDetailPage.module.css \
        src/modules/inventory/pages/StockItemDetailPage.test.tsx \
        src/app/routes.tsx
git commit -m "feat(vat-tu): trang chi tiet vat tu, form sua doi sang /vat-tu/:id/sua"
```

---

### Task 2: Khối "Tồn theo kho"

**Files:**
- Modify: `frontend-erp/src/modules/inventory/pages/StockItemDetailPage.tsx`
- Modify: `frontend-erp/src/modules/inventory/pages/StockItemDetailPage.module.css`
- Modify: `frontend-erp/src/modules/inventory/pages/StockItemDetailPage.test.tsx`

- [ ] **Step 1: Viết test đỏ**

Thêm vào `dungMang` một nhánh trả lời `url.includes('/stock-balances')`, và hai test:

```tsx
it('hien ton theo tung kho, nguyen van chuoi backend tra ve', async () => {
  await render(<StockItemDetailPage id="si-1" />);
  expect(container.textContent).toContain('K01');
  expect(container.textContent).toContain('900.5');
});

it('ton kho 403 thi khoi do cam, khoi thong tin chung van con', async () => {
  phanHoiTon = { status: 403, body: { error: { message: 'khong du quyen' }, request_id: 'rq' } };
  await render(<StockItemDetailPage id="si-1" />);
  expect(container.textContent).toContain('Thep tam');
  expect(container.textContent).toContain('Bạn không có quyền xem tồn kho');
});
```

Mệnh đề thứ hai là mệnh đề quan trọng nhất của cả task: đọc tồn kho là một permission RIÊNG
bên Go, nên một người xem được vật tư vẫn có thể không xem được tồn của nó.

- [ ] **Step 2: Chạy test cho chắc là đỏ**

Run: `npm test -- src/modules/inventory/pages/StockItemDetailPage.test.tsx`
Expected: FAIL - `expected '' to contain 'K01'`

- [ ] **Step 3: Viết khối**

Tham số là hằng ở **cấp module** trộn với id, không dựng trong thân component - nó đi thẳng
vào cache key của TanStack Query:

```tsx
const TON_CUA_VAT_TU = {
  ...DEFAULT_BALANCE_LIST_PARAMS,
  page_size: MAX_PAGE_SIZE,
};

function KhoiTonTheoKho({ item }: { item: StockItemDTO }) {
  const { data, isPending, isFetching, error } = useBalanceList({
    ...TON_CUA_VAT_TU,
    stock_item_id: item.id,
  });
  // ...
}
```

`page_size: MAX_PAGE_SIZE` (100) là **mức trần của backend**, không phải "tất cả". Một công
ty có hơn 100 kho sẽ không thấy hết - khối phải NÓI RA điều đó khi
`data.meta.total > data.items.length`, cùng lối `StockItemForm.tsx:245-250` đã làm với danh
mục đơn vị tính. Không phân trang ở đây: một khối phụ trong trang chi tiết mà có phân trang
riêng là một màn hình thứ hai lồng vào màn hình thứ nhất.

Bảng dùng `<Bang soCot={3}>` với ba `<th scope="col">`: Mã kho, Tên kho, Tồn. Cột Tồn mang
`className="so"` (canh phải + `tabular-nums` của `co-so.css`) và hiện **nguyên văn**
`row.quantity` - không `toLocaleString`, không `Number()`. Số âm không bị kẹp về 0: chặng này
từ chối mọi chuyển động làm tồn xuống dưới 0, nên một số âm là tín hiệu đọc được rằng số đang
sai ở chỗ khác.

Màn rỗng:

```tsx
<ManRong
  tieuDe="Vật tư này chưa có tồn ở kho nào"
  moTa="Tồn được tính từ sổ chuyển động. Ghi một phiếu nhập để vật tư này có tồn."
  hanhDong={<Link to="/chuyen-dong/moi">Ghi chuyển động</Link>}
/>
```

Nhánh lỗi: hàm riêng `LoiTonKho`, 403 ra `<BangThongBao sac="canh-bao" tieuDe="Bạn không có
quyền xem tồn kho">` không nút thử lại; còn lại ra `sac="loi"` kèm nút Thử lại. **Không**
để lỗi này làm trắng cả trang - nó đi vào prop `loi` của chính `<Bang>` của khối này.

Đầu khối có link sang màn tồn kho mang sẵn bộ lọc:
`<Link to={'/ton-kho?stock_item_id=' + encodeURIComponent(item.id)}>Xem tồn kho</Link>`.
Kiểm lại `BalanceListPage.tsx` đọc đúng tên tham số đó trên URL trước khi viết link - nếu tên
khác thì dùng tên của nó, đừng bịa.

- [ ] **Step 4: Chạy test cho chắc là xanh**

Run: `npm test -- src/modules/inventory/pages/StockItemDetailPage.test.tsx`
Expected: PASS, 5 test

- [ ] **Step 5: Commit**

```bash
git add src/modules/inventory/pages/StockItemDetailPage.tsx \
        src/modules/inventory/pages/StockItemDetailPage.module.css \
        src/modules/inventory/pages/StockItemDetailPage.test.tsx
git commit -m "feat(vat-tu): khoi ton theo kho trong trang chi tiet"
```

---

### Task 3: Khối "Chuyển động gần đây"

**Files:**
- Modify: `frontend-erp/src/modules/inventory/pages/StockItemDetailPage.tsx`
- Modify: `frontend-erp/src/modules/inventory/pages/StockItemDetailPage.test.tsx`

- [ ] **Step 1: Viết test đỏ**

Thêm nhánh `url.includes('/stock-movements')` vào `dungMang`, và:

```tsx
it('hien 10 chuyen dong gan nhat kem duong xem tat ca', async () => {
  await render(<StockItemDetailPage id="si-1" />);
  expect(container.textContent).toContain('Nhập');
  const link = Array.from(container.querySelectorAll('a')).map((a) => a.getAttribute('href'));
  expect(link).toContain('/chuyen-dong?stock_item_id=si-1');
});

it('chuyen dong 403 thi khoi do cam, hai khoi kia van con', async () => {
  phanHoiChuyenDong = {
    status: 403,
    body: { error: { message: 'khong du quyen' }, request_id: 'rq' },
  };
  await render(<StockItemDetailPage id="si-1" />);
  expect(container.textContent).toContain('Thep tam');
  expect(container.textContent).toContain('K01');
  expect(container.textContent).toContain('Bạn không có quyền xem sổ chuyển động');
});
```

- [ ] **Step 2: Chạy test cho chắc là đỏ**

Run: `npm test -- src/modules/inventory/pages/StockItemDetailPage.test.tsx`
Expected: FAIL - `expected [ '/vat-tu', ... ] to include '/chuyen-dong?stock_item_id=si-1'`

- [ ] **Step 3: Viết khối**

```tsx
const CHUYEN_DONG_GAN_DAY = {
  ...DEFAULT_MOVEMENT_LIST_PARAMS,
  page_size: 10,
  sort: '-occurred_at' as const,
};
```

`<Bang soCot={4}>`, bốn cột: **Thời điểm xảy ra**, Loại, Kho, Số lượng.

- Cột thời điểm là `occurred_at` chứ không `created_at`, và nhãn cột ghi đúng "Thời điểm xảy
  ra": đó là mốc NGƯỜI DÙNG khai. Định dạng bằng `thoiDiemHienThi` của
  `../components/movement-form-values` - đã có sẵn, đừng viết hàm thứ hai.
- Cột Loại: `movementKindLabel(row.kind)` của `../api/inventory-api`.
- Cột Kho: `khoDaXoa(row) ? <NhanTrangThai sac="canh-bao">Kho đã bị xoá</NhanTrangThai> :
  row.warehouse_code`. Không để ô trống - chuỗi mã rỗng nghĩa là dòng `warehouses` không còn,
  không phải "chưa chọn kho".
- Cột Số lượng: `className="so"`, **nguyên văn có dấu** `row.quantity`. Một lần xuất 8 hiện
  là `-8`; dấu chính là thứ phân biệt một dòng nhập với một dòng xuất.

Màn rỗng: `tieuDe="Vật tư này chưa có chuyển động nào"`, `moTa="Mọi lần nhập, xuất hay điều
chỉnh của vật tư này sẽ hiện ở đây."`, `hanhDong={<Link to="/chuyen-dong/moi">Ghi chuyển
động</Link>}`.

Nhánh lỗi: hàm riêng `LoiChuyenDong`, 403 ra `tieuDe="Bạn không có quyền xem sổ chuyển
động"`, cùng khuôn với `LoiTonKho` của Task 2.

Link "Xem tất cả" ở đầu khối: `/chuyen-dong?stock_item_id=<id>`. Kiểm `MovementListPage.tsx`
đọc đúng tên tham số đó trên URL trước khi viết - nếu tên khác thì dùng tên của nó.

- [ ] **Step 4: Chạy test cho chắc là xanh**

Run: `npm test -- src/modules/inventory/pages/StockItemDetailPage.test.tsx`
Expected: PASS, 7 test

- [ ] **Step 5: Commit**

```bash
git add src/modules/inventory/pages/StockItemDetailPage.tsx \
        src/modules/inventory/pages/StockItemDetailPage.test.tsx
git commit -m "feat(vat-tu): khoi chuyen dong gan day trong trang chi tiet"
```

---

### Task 4: Bấm cả hàng ở bảng danh sách vật tư

**Files:**
- Modify: `frontend-erp/src/modules/inventory/pages/StockItemListPage.tsx:357-419`
- Modify: `frontend-erp/src/modules/inventory/pages/StockItemListPage.module.css`
- Modify: `frontend-erp/src/modules/inventory/pages/StockItemListPage.test.tsx`

- [ ] **Step 1: Viết test đỏ**

```tsx
it('bam giua hang thi sang trang chi tiet', async () => {
  await render(<StockItemListPage />);
  const o = container.querySelectorAll('tbody tr td')[1] as HTMLElement; // o Ten
  act(() => { o.click(); });
  expect(window.location.pathname).toBe('/vat-tu/si-1');
});

it('bam nut Xoa trong hang thi KHONG dieu huong', async () => {
  await render(<StockItemListPage />);
  const nut = Array.from(container.querySelectorAll('tbody button'))
    .find((b) => b.textContent === 'Xoá') as HTMLElement;
  act(() => { nut.click(); });
  expect(window.location.pathname).toBe('/vat-tu');
});
```

Test thứ hai là ca hay hỏng nhất: `click` nổi bọt từ `<button>` lên `<tr>`, nên thiếu chốt
chặn thì bấm Xoá vừa mở khối xác nhận vừa rời khỏi màn.

- [ ] **Step 2: Chạy test cho chắc là đỏ**

Run: `npm test -- src/modules/inventory/pages/StockItemListPage.test.tsx`
Expected: FAIL - `expected '/vat-tu' to be '/vat-tu/si-1'`

- [ ] **Step 3: Sửa `HangVatTu`**

```tsx
function bamVaoDieuKhien(target: EventTarget | null): boolean {
  return target instanceof Element && target.closest('a, button, input, select, textarea') !== null;
}

function dangBoiDen(): boolean {
  return (window.getSelection()?.toString() ?? '') !== '';
}
```

Rồi trên `<tr>`:

```tsx
<tr
  className={styles['hang-bam-duoc']}
  onClick={(e) => {
    // Ba ca KHONG dieu huong, va ca thu ba la ca hay bi bo sot: boi den ten vat tu de chep
    // roi nha chuot cung sinh mot `click` tren hang.
    if (bamVaoDieuKhien(e.target)) return;
    if (dangHoiXoa) return;
    if (dangBoiDen()) return;
    navigate(`/vat-tu/${encodeURIComponent(row.id)}`);
  }}
>
```

**Giữ nguyên** `<Link>` bọc `<MaBanGhi>` ở ô Mã: đó là đường của bàn phím và của chuột giữa
(mở tab mới). **Không** thêm `role="button"` hay `tabIndex` lên `<tr>` - làm vậy là hai điểm
dừng tab cho cùng một đích, và trình đọc màn hình đọc cả hàng thành một cái nút.

- [ ] **Step 4: Thêm CSS**

```css
.hang-bam-duoc {
  cursor: pointer;
}

.hang-bam-duoc:hover {
  background: var(--mau-nen-nhat);
}
```

- [ ] **Step 5: Chạy test cho chắc là xanh**

Run: `npm test -- src/modules/inventory/pages/StockItemListPage.test.tsx`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add src/modules/inventory/pages/StockItemListPage.tsx \
        src/modules/inventory/pages/StockItemListPage.module.css \
        src/modules/inventory/pages/StockItemListPage.test.tsx
git commit -m "feat(vat-tu): bam ca hang trong bang danh sach de sang chi tiet"
```

---

### Task 5: Dựng lại bố cục màn thêm / sửa vật tư

**Chỉ đổi phần nhìn thấy được.** Không đụng một dòng nghiệp vụ nào: ba trạng thái của ô đơn
vị tính, `validateStockItemForm`, cách tô lỗi 422 theo tên ô, nhánh 409 mã trùng - giữ y
nguyên. Bộ test hiện có của `StockItemForm.test.tsx` phải xanh mà **không sửa một assert
nào**; nếu nó đỏ thì bạn vừa đổi nghiệp vụ, không phải đổi bố cục.

**Files:**
- Modify: `frontend-erp/src/modules/inventory/components/StockItemForm.tsx:196-313`
- Modify: `frontend-erp/src/modules/inventory/components/StockItemForm.module.css`
- Modify: `frontend-erp/src/modules/inventory/pages/StockItemFormPage.tsx:207` (một chuỗi)
- Modify: `frontend-erp/src/modules/inventory/pages/StockItemFormPage.module.css`

- [ ] **Step 1: Chạy bộ test hiện có để có mốc so sánh**

Run: `npm test -- src/modules/inventory/components/StockItemForm.test.tsx`
Expected: PASS. Ghi lại số test - sau khi sửa phải đúng con số đó.

- [ ] **Step 2: Đảo thứ tự ba ô**

Trong `StockItemForm.tsx`, chuyển khối `<label>Mã vật tư</label>` và `<label>Tên vật
tư</label>` lên **trước** khối `<label>Đơn vị tính</label>`. Thứ tự mới: Mã → Tên → Đơn vị
tính.

Lý do phải giữ đúng thứ tự đó: ô đầu tiên là ô nhận tiêu điểm, và người nhập liệu gõ mã
trước - bắt họ mở một `<select>` trước khi gõ được chữ nào là ngược thói quen.

`<BangThongBao>` "Đơn vị tính của vật tư này đã bị xoá khỏi danh mục" đi **theo** khối đơn vị
tính xuống dưới: nó nói về ô đó, nên nó phải đứng cạnh ô đó.

- [ ] **Step 3: Bọc form vào thẻ và dựng chân dính**

Thân form vào `<div className={styles.than}>`, hàng nút vào
`<div className={styles['chan-dinh']}>`. Thêm nút Huỷ đứng trước nút Lưu:

```tsx
<div className={styles['chan-dinh']}>
  <Link to="/vat-tu">Huỷ</Link>
  <Nut type="submit" bien="chinh" dangChay={isPending}>
    {isPending ? 'Đang lưu...' : 'Lưu vật tư'}
  </Nut>
</div>
```

Chữ trên nút nói ra đối tượng: `Lưu vật tư`, không phải `Lưu`. Và tên đó không đổi suốt
luồng - nên đổi luôn tiêu đề `<BangThongBao sac="tot">` ở `StockItemFormPage.tsx:115` từ
"Đã tạo vật tư" giữ nguyên, còn ở dòng 207 từ "Đã lưu" thành "Đã lưu vật tư".

- [ ] **Step 4: Viết CSS**

Trong `StockItemForm.module.css`:

```css
.than {
  display: flex;
  flex-direction: column;
  gap: var(--gian-4);
  max-width: var(--rong-form);
}

.than label {
  display: flex;
  flex-direction: column;
  gap: var(--gian-1);
}

.chan-dinh {
  display: flex;
  justify-content: flex-end;
  align-items: center;
  gap: var(--gian-3);
  margin-top: var(--gian-5);
  padding-top: var(--gian-4);
  border-top: 1px solid var(--mau-vien);
}
```

Bốn dòng ghi chú của ô đơn vị tính (đang tải danh mục / danh mục hỏng / chạm trần một trang /
danh mục rỗng) giữ nguyên **nội dung**, chỉ cho chúng cỡ `--chu-sm` màu `--mau-chu-mo` để
thẳng cột với ô. Dòng "danh mục hỏng" giữ màu `--mau-loi`.

Không thêm token mới. Không đổi bảng màu.

- [ ] **Step 5: Chạy lại bộ test cũ**

Run: `npm test -- src/modules/inventory/components/StockItemForm.test.tsx src/modules/inventory/pages/StockItemFormPage.test.tsx`
Expected: PASS, đúng số test của Step 1. Một assert phải sửa nghĩa là bạn vừa đổi nghiệp vụ -
quay lại, đừng sửa test.

- [ ] **Step 6: Commit**

```bash
git add src/modules/inventory/components/StockItemForm.tsx \
        src/modules/inventory/components/StockItemForm.module.css \
        src/modules/inventory/pages/StockItemFormPage.tsx \
        src/modules/inventory/pages/StockItemFormPage.module.css
git commit -m "style(vat-tu): dung lai bo cuc man them va sua vat tu"
```

---

### Task 6: Vá test điều hướng và soi lại cả đợt

**Files:**
- Modify: `frontend-erp/src/app/App.test.tsx:36-37,349-397`
- Modify: `frontend-erp/src/app/AppLayout.test.tsx:99`

- [ ] **Step 1: Chạy cả bộ test để thấy chỗ đỏ**

Run: `npm test`
Expected: FAIL ở `App.test.tsx` - đường `/vat-tu/:id` giờ ra trang chi tiết chứ không ra form.

- [ ] **Step 2: Vá `App.test.tsx`**

Sửa khối ghi chú ở dòng 36-37 cho khớp đường đi mới:

```
//   /kho-van --(nav "Vật tư")--> /vat-tu --("Tạo vật tư mới")--> /vat-tu/moi
//                                        --(bấm hàng)--> /vat-tu/:id --("Sửa")--> /vat-tu/:id/sua
```

Rồi nối thêm một chặng vào test điều hướng: từ `/vat-tu/:id` bấm link "Sửa" và kỳ vọng
`window.location.pathname` là `/vat-tu/<id>/sua`. Thêm nhánh trả lời cho `/stock-balances` và
`/stock-movements` vào phần stub `fetch` của file đó, nếu chưa có.

`AppLayout.test.tsx:99` đẩy URL `/vat-tu/abc-123` chỉ để kiểm ứng dụng nào đang sáng ở thanh
điều hướng - đường đó vẫn hợp lệ, nên **kiểm rồi để yên** nếu nó xanh.

- [ ] **Step 3: Chạy cả bộ test**

Run: `npm test`
Expected: PASS toàn bộ

- [ ] **Step 4: Lint và soi giao diện bằng máy**

```bash
npm run lint
node ../.claude/skills/frontend-design-erp/scripts/kiem-giao-dien.mjs
npm run arch
```

Cả ba phải xanh. `npm run arch` **không** nằm trong `npm test`, và thêm file mới làm golden
`arch/LEVELS.md` lệch - lệch thì chạy `npm run arch:update` (dưới Windows lệnh này chạy được
ở `frontend-erp`, khác `backend-erp`).

- [ ] **Step 5: Đi hết `references/checklist.md` của skill `frontend-design-erp`**

Đánh dấu một dòng nghĩa là đã kiểm thật. Trợ năng, năm trạng thái và chất lượng chữ chỉ có
mắt người đọc ra - script không thay được.

- [ ] **Step 6: Commit**

```bash
git add src/app/App.test.tsx src/app/AppLayout.test.tsx arch/LEVELS.md
git commit -m "test(app): duong di danh sach - chi tiet - sua vat tu"
```

---

## Sau khi hết sáu task

1. `git push -u origin feat/vat-tu-chi-tiet` ở **cả hai** repo (`frontend-erp` và `docs-erp`).
2. Chạy `superpowers:requesting-code-review` trước khi merge.
3. Đi qua `docs-erp/06-checklists/CL-PR-code-review.md`.
4. Bằng chứng phải kèm khi nói "xong": output của `npm test`, `npm run lint`,
   `kiem-giao-dien.mjs`, và một lần đi thật trên máy dev bằng tài khoản `qa-thukho`.
