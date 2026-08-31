# Kế hoạch thi công - đợt A: ba component dùng chung

> **Cho agent thi công:** BẮT BUỘC dùng `superpowers:subagent-driven-development` (khuyến
> nghị) hoặc `superpowers:executing-plans` để làm từng task một. Các bước dùng ô đánh dấu
> `- [ ]` để theo dõi.

**Mục tiêu:** Dựng `OTraCuu`, `ThanhLoc`, `ONgay` ở `shared/components/` rồi áp cho sáu màn
Kho vận, xoá bỏ hình dạng "hai ô chồng nhau" và thanh lọc chép tay.

**Cách làm:** Component mới ra đời kèm test trước, rồi thay từng chỗ gọi một. Không đổi
đường đi, không đổi tham số API, không đụng backend. Mỗi task một commit.

**Thiết kế nền:** `docs-erp/99-meta/my-specs/2026-08-31-danh-sach-truoc-form-design.md`,
mục 10 và 11.

**Công nghệ:** React 19 + TypeScript + Vite, TanStack Query, CSS Module, không thư viện UI.
Test bằng Vitest với `createRoot` + `act` (khuôn của `src/shared/components/Nut/Nut.test.tsx`),
**không** dùng testing-library.

---

## Phạm vi của plan này, và phần cố ý để lại

Đợt A chỉ dựng và áp ba component. **Hai phần còn lại của spec có plan riêng, viết sau khi
A xong:**

- **Đợt B - điều hướng** (spec mục 3-7): bốn mục nav mở ra danh sách, form lùi về `/moi`.
- **Đợt C - vá bố cục bảng** (spec mục 10 nhóm A số 1, 2 và nhóm B số 10, 11): bảng tràn
  ngang, hàng thêm dòng lệch cột, số bốn chữ số thập phân, cắt cụt chữ.

Thứ tự này không đảo được: B dựng ba màn danh sách mới, và chúng phải dựng lên `ThanhLoc`
của A chứ không phải chép lại thanh lọc cũ rồi sửa hai lần.

---

## Bản đồ file

| File | Trách nhiệm |
|---|---|
| `src/shared/components/OTraCuu/OTraCuu.tsx` | Một ô tra cứu danh mục: gõ lọc, gợi ý thả xuống, chọn một mục |
| `src/shared/components/OTraCuu/OTraCuu.module.css` | Hình dạng của ô đó |
| `src/shared/components/OTraCuu/OTraCuu.test.tsx` | Sáu trạng thái + bàn phím + ARIA |
| `src/shared/components/ThanhLoc/ThanhLoc.tsx` | Khung một hàng ô lọc, neo "Số dòng" và "Xoá lọc" ở đầu phải |
| `src/shared/components/ThanhLoc/ThanhLoc.module.css` | Lưới của hàng đó |
| `src/shared/components/ThanhLoc/ThanhLoc.test.tsx` | Nút xoá lọc chỉ hiện khi có lọc; ô cuối không rơi hàng |
| `src/shared/components/ONgay/ONgay.tsx` | Ô ngày `dd/mm/yyyy` gõ tay được, kèm nút mở lịch |
| `src/shared/components/ONgay/ONgay.module.css` | Hình dạng ô ngày |
| `src/shared/components/ONgay/ONgay.test.tsx` | Đọc và ghi đúng `dd/mm/yyyy`, chặn ngày sai |
| `src/modules/inventory/components/ChonKho.tsx` | Sửa: gọi `OTraCuu` thay `ChonDanhMuc` |
| `src/modules/inventory/components/ChonVatTu.tsx` | Sửa: như trên |
| `src/modules/inventory/components/ChonDanhMuc.tsx` | Xoá sau khi hai file trên hết gọi |
| `src/modules/inventory/pages/BalanceListPage.tsx` | Sửa: thanh lọc dùng `ThanhLoc` |
| `src/modules/inventory/pages/MovementListPage.tsx` | Sửa: `ThanhLoc` + `ONgay` |
| `src/modules/inventory/pages/VoucherListPage.tsx` | Sửa: `ThanhLoc` + `ONgay` |

---

## Task 1: `OTraCuu` - một ô thay hai

**Files:**
- Tạo: `src/shared/components/OTraCuu/OTraCuu.tsx`
- Tạo: `src/shared/components/OTraCuu/OTraCuu.module.css`
- Tạo: `src/shared/components/OTraCuu/OTraCuu.test.tsx`

Đọc trước khi viết: `src/modules/inventory/components/ChonDanhMuc.tsx` - **sáu trạng thái**
trong đó là phần đắt nhất và phải giữ đủ: đang tải, danh mục hỏng, chạm trần một trang,
không khớp chuỗi tìm, vừa bỏ chọn, lỗi của chính ô.

- [ ] **Bước 1: Viết bài test đầu tiên - ô đóng thì không có danh sách**

```tsx
// src/shared/components/OTraCuu/OTraCuu.test.tsx
import { act } from 'react';
import { createRoot, type Root } from 'react-dom/client';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { OTraCuu, type OTraCuuProps } from './OTraCuu';

let container: HTMLDivElement;
let root: Root;

const MUC = [
  { id: 'k1', ma: 'QA-KHO-A', ten: 'Kho QA A' },
  { id: 'k2', ma: 'QA-KHO-B', ten: 'Kho QA B' },
];

function props(them: Partial<OTraCuuProps> = {}): OTraCuuProps {
  return {
    name: 'warehouse_id',
    nhan: 'Kho',
    danhTu: 'kho',
    value: '',
    onChange: vi.fn(),
    q: '',
    onChotTuKhoa: vi.fn(),
    muc: MUC,
    tong: MUC.length,
    dangTai: false,
    loiTai: false,
    vuaBoChon: false,
    ...them,
  };
}

beforeEach(() => {
  (globalThis as unknown as { IS_REACT_ACT_ENVIRONMENT: boolean }).IS_REACT_ACT_ENVIRONMENT =
    true;
  container = document.createElement('div');
  document.body.appendChild(container);
  root = createRoot(container);
});

afterEach(() => {
  act(() => {
    root.unmount();
  });
  container.remove();
});

function render(p: OTraCuuProps): void {
  act(() => {
    root.render(<OTraCuu {...p} />);
  });
}

function oGo(): HTMLInputElement {
  const el = container.querySelector('input[role="combobox"]');
  if (!el) throw new Error('không tìm thấy ô tra cứu');
  return el as HTMLInputElement;
}

describe('OTraCuu', () => {
  it('chỉ có MỘT điều khiển nhập, không phải một ô gõ nằm trên một ô chọn', () => {
    render(props());
    expect(container.querySelectorAll('input').length).toBe(1);
    expect(container.querySelector('select')).toBeNull();
  });

  it('chưa mở thì không vẽ danh sách gợi ý', () => {
    render(props());
    expect(oGo().getAttribute('aria-expanded')).toBe('false');
    expect(container.querySelector('[role="listbox"]')).toBeNull();
  });
});
```

- [ ] **Bước 2: Chạy để thấy nó đỏ**

Chạy: `npx vitest run src/shared/components/OTraCuu/OTraCuu.test.tsx`
Mong đợi: ĐỎ, `Failed to resolve import "./OTraCuu"`.

- [ ] **Bước 3: Viết bản nhỏ nhất cho hai mệnh đề đó**

```tsx
// src/shared/components/OTraCuu/OTraCuu.tsx
import { useId, useState } from 'react';

import styles from './OTraCuu.module.css';

export interface MucTraCuu {
  id: string;
  ma: string;
  ten: string;
}

export interface OTraCuuProps {
  /** Tên tham số API - cũng là `name` của ô ẩn giữ giá trị thật. */
  name: string;
  nhan: string;
  /** Danh từ đi vào câu thông báo: 'kho', 'vật tư'. Viết thường. */
  danhTu: string;
  value: string;
  onChange: (id: string) => void;
  q: string;
  onChotTuKhoa: (raw: string) => void;
  muc: readonly MucTraCuu[];
  /** `meta.total`. `undefined` nghĩa là chưa biết, KHÁC với 0. */
  tong: number | undefined;
  dangTai: boolean;
  loiTai: boolean;
  vuaBoChon: boolean;
  disabled?: boolean;
  loi?: string;
}

export function OTraCuu({ name, nhan, value, muc, disabled = false }: OTraCuuProps) {
  const id = useId();
  const [mo, setMo] = useState(false);
  const daChon = muc.find((one) => one.id === value);

  return (
    <div className={styles.o}>
      <label htmlFor={`${id}-go`}>{nhan}</label>
      <input
        id={`${id}-go`}
        role="combobox"
        type="text"
        className={styles['o-go']}
        aria-expanded={mo}
        aria-controls={`${id}-ds`}
        autoComplete="off"
        disabled={disabled}
        defaultValue={daChon ? `${daChon.ma} - ${daChon.ten}` : ''}
        onFocus={() => setMo(true)}
      />
      <input type="hidden" name={name} value={value} />
    </div>
  );
}
```

- [ ] **Bước 4: Chạy lại để thấy nó xanh**

Chạy: `npx vitest run src/shared/components/OTraCuu/OTraCuu.test.tsx`
Mong đợi: XANH, 2 bài.

- [ ] **Bước 5: Commit**

```bash
git add src/shared/components/OTraCuu
git commit -m "feat(shared): o tra cuu mot dieu khien thay cap o go + o chon"
```

- [ ] **Bước 6: Thêm bài test cho sáu trạng thái**

```tsx
  it('đang tải danh mục thì nói ra, không im lặng', () => {
    render(props({ dangTai: true, muc: [], tong: undefined }));
    act(() => oGo().focus());
    expect(container.textContent).toContain('Đang tải');
  });

  it('danh mục hỏng thì nói ra và KHÔNG nói "không có kho nào"', () => {
    render(props({ loiTai: true, muc: [], tong: undefined }));
    act(() => oGo().focus());
    expect(container.textContent).toContain('Không tải được danh sách kho');
    expect(container.textContent).not.toContain('Không có kho nào khớp');
  });

  it('chuỗi tìm không khớp gì thì nói ra, và đó KHÁC với danh mục rỗng', () => {
    render(props({ q: 'xyz', muc: [], tong: 0 }));
    act(() => oGo().focus());
    expect(container.textContent).toContain('Không có kho nào khớp');
  });

  it('chạm trần một trang thì nói ra để người dùng biết còn nữa', () => {
    render(props({ muc: MUC, tong: 200 }));
    act(() => oGo().focus());
    expect(container.textContent).toContain('gõ thêm để thu hẹp');
  });

  it('vừa bỏ chọn vì chuỗi tìm đổi thì báo, và KHÔNG hiện lỗi của ô', () => {
    render(props({ vuaBoChon: true, loi: 'Chưa chọn kho' }));
    expect(container.textContent).toContain('lựa chọn cũ được bỏ');
    expect(container.textContent).not.toContain('Chưa chọn kho');
  });

  it('lỗi của ô hiện khi KHÔNG phải vừa bỏ chọn, và đánh dấu aria-invalid', () => {
    render(props({ loi: 'Chưa chọn kho' }));
    expect(container.textContent).toContain('Chưa chọn kho');
    expect(oGo().getAttribute('aria-invalid')).toBe('true');
  });
```

- [ ] **Bước 7: Chạy, thấy sáu bài mới đỏ**

Chạy: `npx vitest run src/shared/components/OTraCuu/OTraCuu.test.tsx`
Mong đợi: ĐỎ 6, XANH 2.

- [ ] **Bước 8: Cài sáu trạng thái**

Thêm vào `OTraCuu.tsx`, ngay trước `</div>` cuối, và thêm `loiTai`, `dangTai`, `tong`, `q`,
`vuaBoChon`, `loi`, `danhTu` vào tham số đã huỷ cấu trúc ở đầu hàm:

```tsx
      {mo ? (
        <ul id={`${id}-ds`} role="listbox" className={styles['ds']}>
          {muc.map((one) => (
            <li key={one.id} role="option" aria-selected={one.id === value}>
              <button type="button" onClick={() => { onChange(one.id); setMo(false); }}>
                <span className={styles.ma}>{one.ma}</span> {one.ten}
              </button>
            </li>
          ))}
        </ul>
      ) : null}

      <span className={styles['dong-trang-thai']} role="status">
        {dangTai ? `Đang tải danh sách ${danhTu}...` : null}
        {loiTai ? `Không tải được danh sách ${danhTu}. Thử lại sau.` : null}
        {!dangTai && !loiTai && tong === 0 ? `Không có ${danhTu} nào khớp "${q}".` : null}
        {!dangTai && !loiTai && tong !== undefined && tong > muc.length
          ? `Còn ${tong - muc.length} ${danhTu} nữa - gõ thêm để thu hẹp.`
          : null}
      </span>

      {vuaBoChon ? (
        <span role="status" className={styles['ghi-chu']}>
          Chuỗi tìm đã đổi nên lựa chọn cũ được bỏ - chọn lại trong danh sách.
        </span>
      ) : loi !== undefined ? (
        <span className={styles.loi}>{loi}</span>
      ) : null}
```

Và đặt `aria-invalid={loi !== undefined && !vuaBoChon}` trên ô gõ.

- [ ] **Bước 9: Chạy lại, cả tám bài phải xanh**

Chạy: `npx vitest run src/shared/components/OTraCuu/OTraCuu.test.tsx`
Mong đợi: XANH 8.

- [ ] **Bước 10: Commit**

```bash
git add src/shared/components/OTraCuu
git commit -m "feat(shared): sau trang thai cua o tra cuu"
```

- [ ] **Bước 11: Bàn phím - mũi tên và Esc**

```tsx
  it('mũi tên xuống chuyển tiêu điểm vào mục đầu, Esc đóng danh sách', () => {
    render(props());
    act(() => oGo().focus());
    act(() => {
      oGo().dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowDown', bubbles: true }));
    });
    expect(document.activeElement?.textContent).toContain('QA-KHO-A');
    act(() => {
      document.activeElement?.dispatchEvent(
        new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }),
      );
    });
    expect(container.querySelector('[role="listbox"]')).toBeNull();
  });
```

Cài: trên ô gõ, `onKeyDown` bắt `ArrowDown` thì `setMo(true)` rồi
`(e.currentTarget.parentElement?.querySelector('[role="option"] button') as HTMLButtonElement)?.focus()`;
trên `<ul>`, `onKeyDown` bắt `Escape` thì `setMo(false)` và trả tiêu điểm về ô gõ.

- [ ] **Bước 12: Chạy và commit**

Chạy: `npx vitest run src/shared/components/OTraCuu/OTraCuu.test.tsx`
Mong đợi: XANH 9.

```bash
git add src/shared/components/OTraCuu
git commit -m "feat(shared): ban phim cho o tra cuu"
```

---

## Task 2: `ChonKho` và `ChonVatTu` gọi `OTraCuu`

**Files:**
- Sửa: `src/modules/inventory/components/ChonKho.tsx`
- Sửa: `src/modules/inventory/components/ChonVatTu.tsx`
- Xoá: `src/modules/inventory/components/ChonDanhMuc.tsx` và `.module.css` (sau khi hết chỗ gọi)
- Sửa theo: `src/modules/inventory/components/ChonDanhMuc.test.tsx` chuyển thành bài của
  `OTraCuu` nếu còn mệnh đề chưa có ở Task 1; bài nào trùng thì xoá, đừng giữ hai bản

Luật đắt nhất của hai file này - **"chốt một chuỗi tìm mới thì bỏ chọn"** - nằm ở chính
chúng, sáu dòng mỗi nơi. Task này **không được đụng vào luật đó**, chỉ đổi thứ được vẽ ra.

- [ ] **Bước 1: Chạy bộ test của hai file để có mốc xanh trước khi sửa**

Chạy: `npx vitest run src/modules/inventory/components/ChonKho.test.tsx src/modules/inventory/components/ChonVatTu.test.tsx`
Mong đợi: XANH. Ghi lại số bài - sau khi sửa phải bằng đúng số đó.

- [ ] **Bước 2: Sửa bài test của `ChonKho` để đòi một ô, không hai**

```tsx
  it('vẽ MỘT ô tra cứu, không còn cặp ô gõ + ô chọn', () => {
    render(props());
    expect(container.querySelectorAll('select').length).toBe(0);
    expect(container.querySelectorAll('input[role="combobox"]').length).toBe(1);
  });
```

- [ ] **Bước 3: Chạy, thấy đỏ**

Chạy: `npx vitest run src/modules/inventory/components/ChonKho.test.tsx`
Mong đợi: ĐỎ - vẫn còn `<select>`.

- [ ] **Bước 4: Đổi phần vẽ của `ChonKho`**

Thay khối `<ChonDanhMuc ... />` bằng:

```tsx
      <OTraCuu
        name="warehouse_id"
        nhan={nhan}
        danhTu="kho"
        value={value}
        onChange={onChange}
        q={q}
        onChotTuKhoa={chotTuKhoa}
        muc={danhSach.map((one) => ({ id: one.id, ma: one.code, ten: one.name }))}
        tong={data?.meta.total}
        dangTai={isPending}
        loiTai={isError}
        vuaBoChon={vuaBoChon}
        disabled={disabled}
        loi={loi}
      />
```

Bỏ prop `dang` - `OTraCuu` chỉ có một dáng, và đó là điểm của cả task này.

- [ ] **Bước 5: Chạy lại `ChonKho`**

Chạy: `npx vitest run src/modules/inventory/components/ChonKho.test.tsx`
Mong đợi: XANH, số bài bằng mốc ở Bước 1 cộng 1.

- [ ] **Bước 6: Làm y hệt cho `ChonVatTu`**

Cùng sáu bước trên, khác ba chỗ: `name="stock_item_id"`, `danhTu="vật tư"`, và nhãn một
dòng danh mục mang thêm đơn vị tính - giữ nguyên cách dựng nhãn đang có, chỉ đưa nó vào
trường `ten`.

- [ ] **Bước 7: Xoá `ChonDanhMuc` sau khi không còn ai gọi**

```bash
grep -rn "ChonDanhMuc" src/ | grep -v "ChonDanhMuc.test"
```
Mong đợi: không dòng nào. Rồi:
```bash
git rm src/modules/inventory/components/ChonDanhMuc.tsx \
       src/modules/inventory/components/ChonDanhMuc.module.css \
       src/modules/inventory/components/ChonDanhMuc.test.tsx
```

- [ ] **Bước 8: Chạy cả bộ test**

Chạy: `npx vitest run > /tmp/t.txt 2>&1; echo "TEST=$?"; grep -E "Test Files|Tests " /tmp/t.txt`
Mong đợi: `TEST=0`. **Đừng nối vitest vào `| tail`** - ống nuốt mã thoát và một bộ test đỏ
sẽ đọc ra như xanh.

- [ ] **Bước 9: Commit**

```bash
git add -u src/modules/inventory/components
git commit -m "refactor(inventory): hai o chon danh muc dung OTraCuu, xoa ChonDanhMuc"
```

---

## Task 3: `ThanhLoc` - khung một hàng

**Files:**
- Tạo: `src/shared/components/ThanhLoc/ThanhLoc.tsx`
- Tạo: `src/shared/components/ThanhLoc/ThanhLoc.module.css`
- Tạo: `src/shared/components/ThanhLoc/ThanhLoc.test.tsx`

- [ ] **Bước 1: Viết test**

```tsx
  it('không có ô nào đang lọc thì KHÔNG hiện nút Xoá lọc', () => {
    render({ dangLoc: false, soDong: 20, onDoiSoDong: vi.fn(), onXoaLoc: vi.fn(), children: <input /> });
    expect(container.textContent).not.toContain('Xoá lọc');
  });

  it('có ít nhất một ô đang lọc thì hiện nút Xoá lọc', () => {
    const onXoaLoc = vi.fn();
    render({ dangLoc: true, soDong: 20, onDoiSoDong: vi.fn(), onXoaLoc, children: <input /> });
    const nut = Array.from(container.querySelectorAll('button')).find(
      (b) => (b.textContent ?? '').includes('Xoá lọc'),
    );
    if (!nut) throw new Error('không thấy nút Xoá lọc');
    act(() => nut.click());
    expect(onXoaLoc).toHaveBeenCalledTimes(1);
  });

  it('ô Số dòng nằm CÙNG hàng với các ô lọc, không phải một hàng riêng', () => {
    render({ dangLoc: false, soDong: 20, onDoiSoDong: vi.fn(), onXoaLoc: vi.fn(), children: <input /> });
    const hang = container.querySelector('[data-hang-loc]');
    const soDong = container.querySelector('[data-so-dong]');
    if (!hang || !soDong) throw new Error('thiếu hàng lọc hoặc ô số dòng');
    expect(hang.contains(soDong)).toBe(true);
  });
```

- [ ] **Bước 2: Chạy, thấy đỏ**

Chạy: `npx vitest run src/shared/components/ThanhLoc/ThanhLoc.test.tsx`
Mong đợi: ĐỎ, không resolve được import.

- [ ] **Bước 3: Viết component**

```tsx
// src/shared/components/ThanhLoc/ThanhLoc.tsx
import type { ReactNode } from 'react';

import styles from './ThanhLoc.module.css';

export interface ThanhLocProps {
  /** Các ô lọc của từng màn. Mỗi ô tự mang nhãn của nó. */
  children: ReactNode;
  /** Có ít nhất một ô đang lọc. Quyết định nút "Xoá lọc" hiện hay không. */
  dangLoc: boolean;
  onXoaLoc: () => void;
  soDong: number;
  onDoiSoDong: (n: number) => void;
}

const CO_TRANG = [20, 50, 100] as const;

export function ThanhLoc({ children, dangLoc, onXoaLoc, soDong, onDoiSoDong }: ThanhLocProps) {
  return (
    <div className={styles.hang} data-hang-loc>
      {children}

      <div className={styles.duoi} data-so-dong>
        <label htmlFor="thanh-loc-so-dong">Số dòng</label>
        <select
          id="thanh-loc-so-dong"
          value={soDong}
          onChange={(e) => onDoiSoDong(Number(e.target.value))}
        >
          {CO_TRANG.map((n) => (
            <option key={n} value={n}>
              {n}
            </option>
          ))}
        </select>
        {dangLoc ? (
          <button type="button" className={styles['nut-xoa']} onClick={onXoaLoc}>
            Xoá lọc
          </button>
        ) : null}
      </div>
    </div>
  );
}
```

```css
/* src/shared/components/ThanhLoc/ThanhLoc.module.css */
.hang {
  display: flex;
  flex-wrap: wrap;
  align-items: flex-end;
  gap: var(--gian-3);
  padding: var(--gian-4);
}

/* Khối này ĐẨY sang phải và không bao giờ rơi xuống một mình: `margin-left: auto` giữ nó ở
   đầu phải của hàng, còn `flex-shrink: 0` giữ nó nguyên bề ngang khi hàng chật. */
.duoi {
  display: flex;
  align-items: flex-end;
  gap: var(--gian-2);
  margin-left: auto;
  flex-shrink: 0;
}

.nut-xoa {
  height: 32px;
}
```

- [ ] **Bước 4: Chạy lại**

Chạy: `npx vitest run src/shared/components/ThanhLoc/ThanhLoc.test.tsx`
Mong đợi: XANH 3.

- [ ] **Bước 5: Commit**

```bash
git add src/shared/components/ThanhLoc
git commit -m "feat(shared): ThanhLoc - mot hang o loc, so dong khong roi hang rieng"
```

---

## Task 4: Áp `ThanhLoc` cho `/ton-kho` và `/chuyen-dong`

**Files:**
- Sửa: `src/modules/inventory/pages/BalanceListPage.tsx`
- Sửa: `src/modules/inventory/pages/MovementListPage.tsx`

- [ ] **Bước 1: Bài test cho `/ton-kho`**

Thêm vào `BalanceListPage.test.tsx`:

```tsx
  it('ô Số dòng nằm trong cùng hàng lọc, không đứng riêng một mình', async () => {
    await renderMan();
    const hang = container.querySelector('[data-hang-loc]');
    const soDong = container.querySelector('[data-so-dong]');
    if (!hang || !soDong) throw new Error('thiếu hàng lọc hoặc ô số dòng');
    expect(hang.contains(soDong)).toBe(true);
  });
```

- [ ] **Bước 2: Chạy, thấy đỏ**

Chạy: `npx vitest run src/modules/inventory/pages/BalanceListPage.test.tsx`
Mong đợi: ĐỎ - chưa có `data-hang-loc`.

- [ ] **Bước 3: Bọc thanh lọc hiện có bằng `ThanhLoc`**

Giữ nguyên từng ô lọc đang có; chỉ bỏ khối "Số dòng" viết tay và đưa `soDong`,
`onDoiSoDong`, `dangLoc`, `onXoaLoc` vào `ThanhLoc`. `dangLoc` tính từ chính params đang
dùng, ví dụ ở màn tồn:

```tsx
const dangLoc =
  params.warehouse_id !== '' || params.stock_item_id !== '' || params.q !== '';
```

- [ ] **Bước 4: Chạy lại cả file test của màn**

Chạy: `npx vitest run src/modules/inventory/pages/BalanceListPage.test.tsx`
Mong đợi: XANH, số bài bằng mốc cũ cộng 1.

- [ ] **Bước 5: Làm y hệt cho `MovementListPage`**

`dangLoc` ở màn sổ chuyển động tính thêm hai mốc thời gian:

```tsx
const dangLoc =
  params.warehouse_id !== '' ||
  params.stock_item_id !== '' ||
  params.kind !== '' ||
  params.tu_thoi_diem !== '' ||
  params.den_thoi_diem !== '';
```

- [ ] **Bước 6: Chạy cả bộ và commit**

Chạy: `npx vitest run > /tmp/t.txt 2>&1; echo "TEST=$?"; grep -E "Test Files|Tests " /tmp/t.txt`
Mong đợi: `TEST=0`.

```bash
git add -u src/modules/inventory/pages
git commit -m "refactor(inventory): hai man danh sach dung ThanhLoc"
```

---

## Task 5: `ONgay` - ô ngày `dd/mm/yyyy`

**Files:**
- Tạo: `src/shared/components/ONgay/ONgay.tsx`
- Tạo: `src/shared/components/ONgay/ONgay.module.css`
- Tạo: `src/shared/components/ONgay/ONgay.test.tsx`

Vì sao không dùng `<input type="date">`: nó hiển thị theo locale của **trình duyệt**, không
theo `lang` của trang. Trên máy dev nó ra `mm/dd/yyyy` và không có thuộc tính nào ép được.

- [ ] **Bước 1: Viết test**

```tsx
  it('nhận ISO và hiện ra dd/mm/yyyy', () => {
    render({ value: '2026-08-31', onChange: vi.fn(), nhan: 'Từ ngày' });
    expect(o().value).toBe('31/08/2026');
  });

  it('gõ dd/mm/yyyy hợp lệ thì trả ISO ra ngoài', () => {
    const onChange = vi.fn();
    render({ value: '', onChange, nhan: 'Từ ngày' });
    act(() => {
      o().value = '01/09/2026';
      o().dispatchEvent(new Event('input', { bubbles: true }));
      o().dispatchEvent(new Event('blur', { bubbles: true }));
    });
    expect(onChange).toHaveBeenCalledWith('2026-09-01');
  });

  it('ngày không có thật thì báo tại ô và KHÔNG gọi onChange', () => {
    const onChange = vi.fn();
    render({ value: '', onChange, nhan: 'Từ ngày' });
    act(() => {
      o().value = '31/02/2026';
      o().dispatchEvent(new Event('input', { bubbles: true }));
      o().dispatchEvent(new Event('blur', { bubbles: true }));
    });
    expect(onChange).not.toHaveBeenCalled();
    expect(container.textContent).toContain('Ngày không có thật');
  });
```

- [ ] **Bước 2: Chạy, thấy đỏ**

Chạy: `npx vitest run src/shared/components/ONgay/ONgay.test.tsx`
Mong đợi: ĐỎ.

- [ ] **Bước 3: Viết component**

```tsx
// src/shared/components/ONgay/ONgay.tsx
import { useId, useState } from 'react';

import styles from './ONgay.module.css';

export interface ONgayProps {
  nhan: string;
  /** ISO `yyyy-mm-dd`, hoặc chuỗi rỗng khi chưa chọn. */
  value: string;
  onChange: (iso: string) => void;
  disabled?: boolean;
}

function isoSangHien(iso: string): string {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(iso);
  return m ? `${m[3]}/${m[2]}/${m[1]}` : '';
}

/** Trả ISO nếu chuỗi là một ngày CÓ THẬT, ngược lại trả null. */
export function hienSangIso(raw: string): string | null {
  const m = /^(\d{2})\/(\d{2})\/(\d{4})$/.exec(raw.trim());
  if (!m) return null;
  const [, dd, mm, yyyy] = m;
  const d = new Date(Number(yyyy), Number(mm) - 1, Number(dd));
  // Ngày 31/02 được Date tự đẩy sang tháng 3, nên phải so lại từng phần.
  if (
    d.getFullYear() !== Number(yyyy) ||
    d.getMonth() !== Number(mm) - 1 ||
    d.getDate() !== Number(dd)
  ) {
    return null;
  }
  return `${yyyy}-${mm}-${dd}`;
}

export function ONgay({ nhan, value, onChange, disabled = false }: ONgayProps) {
  const id = useId();
  const [tho, setTho] = useState(isoSangHien(value));
  const [loi, setLoi] = useState<string | undefined>(undefined);

  return (
    <div className={styles.o}>
      <label htmlFor={id}>{nhan}</label>
      <input
        id={id}
        type="text"
        inputMode="numeric"
        className={styles['o-go']}
        value={tho}
        disabled={disabled}
        aria-invalid={loi !== undefined}
        onChange={(e) => setTho(e.target.value)}
        onBlur={() => {
          if (tho.trim() === '') {
            setLoi(undefined);
            onChange('');
            return;
          }
          const iso = hienSangIso(tho);
          if (iso === null) {
            setLoi('Ngày không có thật. Gõ theo dd/mm/yyyy.');
            return;
          }
          setLoi(undefined);
          onChange(iso);
        }}
      />
      {loi !== undefined ? <span className={styles.loi}>{loi}</span> : null}
    </div>
  );
}
```

- [ ] **Bước 4: Chạy lại**

Chạy: `npx vitest run src/shared/components/ONgay/ONgay.test.tsx`
Mong đợi: XANH 3.

- [ ] **Bước 5: Commit**

```bash
git add src/shared/components/ONgay
git commit -m "feat(shared): ONgay hien dd/mm/yyyy thay input type=date"
```

---

## Task 6: Áp `ONgay` cho `/chuyen-dong` và `/phieu`

**Files:**
- Sửa: `src/modules/inventory/pages/MovementListPage.tsx`
- Sửa: `src/modules/inventory/pages/VoucherListPage.tsx`

Hai màn này đang nới một ô ngày trần thành mốc RFC 3339 đầy đủ ở
`components/voucher-list-params.ts` (`noiNgayThanhMoc`). Phép nới đó **giữ nguyên** - `ONgay`
chỉ đổi cách người dùng gõ, không đổi thứ gửi lên.

- [ ] **Bước 1: Bài test đòi không còn `input type="date"`**

```tsx
  it('ô ngày không dùng input type=date, vì nó hiện mm/dd theo locale trình duyệt', async () => {
    await renderMan();
    expect(container.querySelectorAll('input[type="date"]').length).toBe(0);
    expect(container.querySelectorAll('input[type="datetime-local"]').length).toBe(0);
  });
```

- [ ] **Bước 2: Chạy, thấy đỏ**

Chạy: `npx vitest run src/modules/inventory/pages/VoucherListPage.test.tsx`
Mong đợi: ĐỎ.

- [ ] **Bước 3: Thay hai ô ngày**

```tsx
<ONgay nhan="Từ ngày" value={params.tu_ngay} onChange={(iso) => datLoc({ tu_ngay: iso })} />
<ONgay nhan="Đến ngày" value={params.den_ngay} onChange={(iso) => datLoc({ den_ngay: iso })} />
```

- [ ] **Bước 4: Chạy lại hai file test của hai màn**

Chạy: `npx vitest run src/modules/inventory/pages/VoucherListPage.test.tsx src/modules/inventory/pages/MovementListPage.test.tsx`
Mong đợi: XANH.

- [ ] **Bước 5: Chạy toàn bộ cổng kiểm**

```bash
npx vitest run > /tmp/t.txt 2>&1; echo "TEST=$?"
npm run lint > /tmp/l.txt 2>&1; echo "LINT=$?"
npm run arch > /tmp/a.txt 2>&1; echo "ARCH=$?"
node ../.claude/skills/frontend-design-erp/scripts/kiem-giao-dien.mjs
```
Mong đợi: `TEST=0`, `LINT=0`, `ARCH=0`, và `kiem-giao-dien: sach`.

`npm run arch` đứng riêng ngoài `npm test`, và thêm file mới **làm lệch golden
`LEVELS.md`** - chạy `npm run arch:update` rồi commit file golden cùng đợt. Dưới Windows
lệnh này chỉ chạy được ở `frontend-erp`, không chạy ở `backend-erp`.

- [ ] **Bước 6: Commit**

```bash
git add -u src/modules/inventory/pages
git add docs/arch/LEVELS.md
git commit -m "refactor(inventory): hai man danh sach dung ONgay"
```

---

## Task 7: Soi lại bằng mắt trên máy dev

Máy không kiểm được ba thứ: ô tra cứu có đọc ra là MỘT trường không, thanh lọc có đứng
thành một hàng không, và ngày có đọc ra dd/mm không.

- [ ] **Bước 1: Đóng một bản rc và đẩy lên dev** - theo skill `deploy-rc`.

- [ ] **Bước 2: Soi bằng `agent-browser`, tài khoản `qa-admin@erp.test`, phân vùng `DEFAULT`**

Chụp **toàn trang** ở `1366x768` **và** `1920x1080` - lần soi trước chụp `1264x569` và chỉ
nhìn phần đầu, nên bỏ sót toàn bộ lỗi bố cục ở đáy trang:

```bash
agent-browser --session soi open "http://103.179.172.110/" --args "--disable-features=HttpsFirstBalancedMode,HttpsUpgrades"
agent-browser --session soi set viewport 1366 768
agent-browser --session soi screenshot --full ton-kho.png
```

- [ ] **Bước 3: Đối chiếu bốn mệnh đề**

1. `/nhap-kho`, `/dieu-chinh`: mỗi danh mục là **một** ô, không phải một ô gõ nằm trên một
   hộp thả xuống.
2. `/ton-kho`: ô "Số dòng" nằm cùng hàng với các ô lọc, không còn khoảng trắng chết.
3. `/phieu`, `/chuyen-dong`: ô ngày hiện `dd/mm/yyyy`.
4. Không màn nào bị cuộn ngang ở `1366` **do thanh lọc** - bảng tràn ngang là việc của đợt C.

---

## Tự soi kế hoạch

- **Phủ hết spec chưa:** plan này phủ mục 11 (ba component) và mục 10 nhóm A số 3, nhóm B
  số 9. **Chưa phủ** mục 3-7 (điều hướng) và mục 10 nhóm A số 1, 2, nhóm B số 10, 11 - hai
  phần đó có plan riêng, đã nói ở đầu file.
- **Không chỗ nào để trống:** mọi bước có mã thật hoặc lệnh thật kèm kết quả mong đợi.
- **Tên gọi khớp nhau:** `OTraCuu` nhận `muc: readonly MucTraCuu[]` với ba trường
  `id/ma/ten` ở Task 1, và Task 2 dựng đúng ba trường đó từ `code`/`name`. `ThanhLoc` nhận
  `dangLoc/onXoaLoc/soDong/onDoiSoDong` ở Task 3 và Task 4 truyền đúng bốn cái đó. `ONgay`
  nhận `value` ISO ở Task 5 và Task 6 truyền `params.tu_ngay` vốn cũng là ISO.
