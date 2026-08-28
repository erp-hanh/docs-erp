# Vai trò đợt 2b - Frontend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to
> execute this plan. Dispatch one subagent per task, in the order below. Each task ends with a
> green test run and a commit; do not start task N+1 before task N is committed.

**Goal**

Thay trạng thái "dữ liệu mẫu" của hai màn vai trò bằng đường thật của backend đợt 2b, và mở
cho admin phân vùng tự tích quyền cho một vai trò. Cụ thể: `DanhSachChon` mọc thêm hai năng
lực dùng chung (checkbox cha ba trạng thái, khoá từng dòng kèm lý do), `VaiTroFormPage` và
`VaiTroListPage` nối `GET /permissions` + `GET /roles` + `POST /roles` + `PATCH /roles/:id`,
hằng `VAI_TRO_MAU` và chip "Xem trước" biến mất, và màn gán vai trò thôi bày ra vai trò đã tắt.

**Architecture**

Ba tầng đã có sẵn trong repo, đợt này không thêm tầng nào:

```
pages/          VaiTroListPage, VaiTroFormPage, UserDetailPage   - chỉ bày và thu phím
hooks/          useVaiTroKhaDung, useDanhMucQuyen,               - TanStack Query
                useTaoVaiTro, useSuaVaiTro
api/user-api.ts DTO + hàm HTTP + vị ngữ thuần trên hình dạng dữ liệu
shared/components/DanhSachChon  component dùng chung, không biết gì về vai trò
```

Ba mệnh đề khoá hình dạng của kế hoạch này:

1. **Frontend không giữ quy tắc nghiệp vụ (R-19).** Mã vai trò chỉ được XEM TRƯỚC, mã thật do
   backend chốt. Quyền nào hợp lệ do `cap_duoc` của backend nói, không do màn hình đoán. Vai
   trò hệ thống khoá được thứ gì do `he_thong_tao` nói, và backend vẫn từ chối độc lập.
2. **`DanhSachChon` không biết chữ "vai trò" hay "quyền".** Hai năng lực mới nhận vào dưới
   dạng dữ liệu chung (`khoaDong` trên một mục, `chonCaNhom` trên cả danh sách). Nhét khái
   niệm `cap_duoc` vào component dùng chung là kéo một luật của module `user` xuống `shared/`.
3. **Một endpoint `GET /roles` phục vụ hai màn.** Màn quản trị đọc nguyên; màn gán tự lọc
   `dang_dung`. Đó là lọc theo DỮ LIỆU backend trả về, không phải suy diễn quyền, nên nó không
   vướng `erp/c-ts-06-no-role-guess` và không vướng R-19 (ADR-0038, mục Consequences).

**Tech Stack**

React 19 + TypeScript + Vite, TanStack Query v5, router tự viết, CSS Module với token ở
`src/shared/styles/tokens.css`. Test: `vitest` + `react-dom/client` + `act`, **không** React
Testing Library - mỗi file test tự dựng `container`/`root`.

Lệnh dùng suốt kế hoạch, gõ ở `d:\My project web\erp\frontend-erp`:

| Việc | Lệnh |
|---|---|
| Cả bộ test | `npm test` |
| Một file test | `npx vitest run src/duong/dan/File.test.tsx` |
| Lint | `npm run lint` |
| Bảng mục kiến trúc | `npm run arch` |
| Ghi lại golden khi thêm file mới | `npm run arch:update` |

`npm run arch` **chạy riêng, KHÔNG nằm trong `npm test`**. Mỗi task thêm hay xoá một file
trong `src/` đều làm `arch/LEVELS.md` lệch, và `npm run arch` sẽ đỏ. Chữa bằng
`npm run arch:update` rồi commit kèm file golden. Ở repo frontend lệnh `arch:update` **dùng
được dưới Windows** - khác `backend-erp`, nơi nó đóng đinh một kết quả đỏ giả.

---

## Hai chỗ spec mục 7 đã lạc hậu - kế hoạch này theo bản mới

**1. KHÔNG viết câu "thay đổi thấy sau tối đa 30 giây" dưới khối quyền.** Spec 7.2 đòi một
dòng cố định như vậy. Nó không còn đúng: `TaoVaiTro` và `SuaVaiTro` gọi `authz.XoaBanChup`
ngay sau `tx.Commit()` (ADR-0038, mục Consequences), nên tạo / sửa / tắt vai trò có hiệu lực
NGAY. Câu 30 giây chỉ còn đúng cho `PUT /users/:id/roles` và `PUT /users/:id/scopes` - đừng
viết nó ở màn vai trò.

**2. Màn GÁN (`UserDetailPage`) phải tự lọc `dang_dung`.** `GET /roles` trả cả vai trò đã tắt
vì nó là MỘT endpoint phục vụ cả hai màn.

## Một lỗ hổng hợp đồng phải biết trước khi gõ dòng đầu tiên

**Không có `GET /roles/:id`, và `GET /roles` không trả trường `quyen`.**

Đã đối chiếu code thật ở nhánh `feat/vai-tro-dot-2b-backend`:
`modules/auth/internal/handler/role_routes.go` chỉ đăng ký `GET /permissions`, `POST /roles`,
`PATCH /roles/:id`; `VaiTroKhaDungDTO` ở `user_role_handler.go` có chín trường và **không** có
`quyen`; chỉ `VaiTroDTO` (thân trả về của hai đường GHI) mới mang `quyen`.

Hệ quả: **màn SỬA không đọc được tập quyền hiện tại của vai trò** để tích sẵn.

Kế hoạch này không bịa ra một đường đọc. Nó làm hai việc:

- Khai `quyen?: string[]` là **tuỳ chọn** trên `VaiTroKhaDungDTO`. Ngày backend thêm trường
  ấy vào `GET /roles`, màn sửa tự sống dậy mà không phải sửa một dòng nào.
- Khi trường vắng mặt, khối quyền ở màn SỬA hiện ở trạng thái **khoá kèm lý do đọc được**, và
  `permissions` **không bao giờ** được đưa vào thân `PATCH`. Không tích sẵn được mà vẫn gửi
  `permissions` lên là gửi một mảng rỗng đè lên tập quyền thật - tức xoá sạch quyền của một
  vai trò bằng một cú bấm Lưu đổi tên.

**Việc phải báo lại cho người điều phối:** thêm `Quyen []string \`json:"quyen"\`` vào
`VaiTroKhaDungDTO` là chỗ sửa rẻ nhất và nó mở khoá trọn vẹn spec mục 7.2 cho màn sửa. Task 5
dưới đây có sẵn một bài test cho nhánh "đọc được" nên không phải viết lại gì khi trường về.

---

## File Structure

| File | Tạo / Sửa | Trách nhiệm |
|---|---|---|
| `src/shared/components/DanhSachChon/DanhSachChon.tsx` | Sửa | Thêm `khoaDong` trên `MucChon`, `chonCaNhom` trên props, hàm thuần `trangThaiNhom` |
| `src/shared/components/DanhSachChon/DanhSachChon.module.css` | Sửa | Lớp `.mo` cho dòng khoá mềm, `.nhom` thành hàng flex, `.o-nhom` cho checkbox cha |
| `src/shared/components/DanhSachChon/DanhSachChon.test.tsx` | Sửa | Thêm ca khoá từng dòng và ca checkbox cha ba trạng thái |
| `src/modules/user/api/user-api.ts` | Sửa | `QuyenDTO`, mở rộng `VaiTroKhaDungDTO`, `VaiTroDTO`, `TaoVaiTroRequest`, `SuaVaiTroRequest`, `listQuyen`, `taoVaiTro`, `suaVaiTro`, các vị ngữ thuần |
| `src/modules/user/api/user-api.test.ts` | Tạo | Test cho các vị ngữ thuần vừa thêm |
| `src/modules/user/components/loi-vai-tro.ts` | Tạo | Bốn mã lỗi của đợt 2b thành câu tiếng Việt có dấu |
| `src/modules/user/components/loi-vai-tro.test.ts` | Tạo | Test cho `cauLoiVaiTro` |
| `src/modules/user/hooks/user-keys.ts` | Sửa | Thêm khoá `danhMucQuyen` |
| `src/modules/user/hooks/use-danh-muc-quyen.ts` | Tạo | `useDanhMucQuyen()` |
| `src/modules/user/hooks/use-tao-vai-tro.ts` | Tạo | `useTaoVaiTro()` |
| `src/modules/user/hooks/use-sua-vai-tro.ts` | Tạo | `useSuaVaiTro()` - nhận `id` trong biến của `mutate` |
| `src/modules/user/pages/VaiTroFormPage.tsx` | Sửa | Nối API thật, khối tích quyền, bốn mã lỗi, vai trò hệ thống |
| `src/modules/user/pages/VaiTroFormPage.module.css` | Sửa | Lớp cho khối quyền và câu hiệu lực ngay |
| `src/modules/user/pages/VaiTroFormPage.test.tsx` | Viết lại | Bộ test mới, chạy trên `fetch` giả |
| `src/modules/user/pages/VaiTroListPage.tsx` | Sửa | Nối API thật, nút Tắt/Bật xác nhận hai bước tại chỗ, xoá dải cảnh báo |
| `src/modules/user/pages/VaiTroListPage.module.css` | Sửa | Lớp cho khối xác nhận trong ô Thao tác |
| `src/modules/user/pages/VaiTroListPage.test.tsx` | Viết lại | Bộ test mới, chạy trên `fetch` giả |
| `src/app/mat-phan-quyen.ts` | Sửa | Bỏ `xemTruoc: true` ở mặt Vai trò |
| `src/modules/user/components/vai-tro-mau.ts` | **Xoá** | Hằng dữ liệu mẫu, hết lý do tồn tại |
| `src/modules/user/pages/UserDetailPage.tsx` | Sửa | Lọc `dang_dung` khỏi danh mục gán, thêm prop `soDaTai` |
| `src/modules/user/pages/UserDetailPage.test.tsx` | Sửa | Thêm ca "vai trò đã tắt không nằm trong ô chọn" |
| `arch/LEVELS.md` | Sửa (sinh) | Golden của `npm run arch`, cập nhật bằng `npm run arch:update` |

Không đụng tới: `src/modules/user/components/sinh-ma-vai-tro.ts` và test của nó (hàm xem
trước mã vẫn đúng vai trò cũ), `src/shared/api/form-errors.ts`,
`src/modules/user/hooks/mutation-errors.ts`.

---

## Task 1: `DanhSachChon` khoá TỪNG DÒNG kèm lý do

Hôm nay component chỉ khoá được TOÀN BỘ danh sách (`khoa`). Đợt này cần khoá một dòng: quyền
`cap_duoc: false` phải hiện mờ, không tích được, và lý do phải tới được người dùng bàn phím.

Khoá **mềm** chứ không `disabled`, đúng lối `Nut.tsx` đã chốt: `disabled` thật gạt ô khỏi thứ
tự tab nên người dùng bàn phím không bao giờ dừng lại được để nghe lý do, và trình đọc màn
hình bỏ qua `aria-describedby` của một control đã disabled.

**Files:**
- `src/shared/components/DanhSachChon/DanhSachChon.test.tsx`
- `src/shared/components/DanhSachChon/DanhSachChon.tsx`
- `src/shared/components/DanhSachChon/DanhSachChon.module.css`

- [ ] **Step 1: Viết test đỏ cho ba mệnh đề của dòng khoá mềm.**

  Thêm vào cuối `DanhSachChon.test.tsx`, dùng lại bộ khung `render` / `oDanhDau` đã có ở đầu
  file:

  ```tsx
  const KHO_KHOA: MucChon[] = [
    { id: 'hn1', nhanChinh: 'Kho tổng Hà Nội', loc: 'KHO-HN-01 Kho tổng Hà Nội' },
    {
      id: 'sg1',
      nhanChinh: 'Kho tổng Sài Gòn',
      loc: 'KHO-HCM-01 Kho tổng Sài Gòn',
      khoaDong: 'Bạn không quản lý kho này.',
    },
  ];

  /** Ô đánh dấu của một mục, tìm qua data-muc chứ không qua chỉ số: chỉ số đổi theo ô lọc. */
  function oCuaMuc(id: string): HTMLInputElement {
    const nhan = container.querySelector(`[data-muc="${id}"]`);
    const o = nhan?.querySelector<HTMLInputElement>('input[type="checkbox"]');
    if (!o) throw new Error(`không tìm thấy ô đánh dấu của mục ${id}`);
    return o;
  }

  describe('khoá từng dòng', () => {
    it('dòng khoá VẪN dừng được bằng Tab và nối tới lý do đọc được', () => {
      // Khoá cứng bằng `disabled` là cách chắc chắn nhất để lý do không bao giờ tới được
      // người dùng bàn phím - và họ là nhóm cần lời giải thích nhất.
      render({ muc: KHO_KHOA });

      const o = oCuaMuc('sg1');
      expect(o.disabled).toBe(false);
      expect(o.getAttribute('aria-disabled')).toBe('true');

      const idLyDo = o.getAttribute('aria-describedby');
      expect(idLyDo).not.toBeNull();
      const lyDo = container.querySelector(`#${CSS.escape(idLyDo as string)}`);
      expect(lyDo?.textContent).toBe('Bạn không quản lý kho này.');
      expect(lyDo?.className).toContain('chi-doc-man-hinh');
    });

    it('dòng khoá mang dấu nhận biết và lớp mờ, dòng thường thì không', () => {
      // Kiểm bằng thuộc tính data-* và class chứ không bằng chữ: một dòng bị CSS giấu vẫn
      // nằm nguyên trong textContent.
      render({ muc: KHO_KHOA });

      const hangKhoa = container.querySelector('[data-muc="sg1"]') as HTMLElement;
      const hangThuong = container.querySelector('[data-muc="hn1"]') as HTMLElement;
      expect(hangKhoa.getAttribute('data-khoa-dong')).toBe('true');
      expect(hangThuong.getAttribute('data-khoa-dong')).toBeNull();
      expect(hangKhoa.className).toContain('mo');
      expect(hangThuong.className).not.toContain('mo');
    });

    it('bấm vào dòng khoá KHÔNG gọi onDoiChon', () => {
      // Mệnh đề đắt nhất: aria-disabled không chặn gì cả, trình duyệt vẫn bắn click. Thiếu
      // phép chặn trong onChange thì "khoá mềm" chỉ là một lớp sơn mờ.
      const daGoi = vi.fn();
      render({ muc: KHO_KHOA, onDoiChon: daGoi });

      act(() => {
        oCuaMuc('sg1').click();
      });

      expect(daGoi).not.toHaveBeenCalled();
    });
  });
  ```

- [ ] **Step 2: Chạy `npx vitest run src/shared/components/DanhSachChon/DanhSachChon.test.tsx` và THẤY ĐỎ.**

  Ba bài phải đỏ vì `khoaDong` chưa tồn tại (TypeScript báo ngay ở `KHO_KHOA`). Đọc lời đỏ
  trước khi sửa: một bài xanh ngay từ lần chạy đầu là một bài không kiểm gì cả.

- [ ] **Step 3: Thêm `khoaDong` vào `MucChon` và dựng dòng khoá mềm.**

  Trong `DanhSachChon.tsx`, thêm trường vào interface đã có:

  ```tsx
  export interface MucChon {
    /** Giá trị thật gửi lên server. */
    id: string;
    /** Dòng trên: tên người đọc được. */
    nhanChinh: ReactNode;
    /** Dòng dưới: mã, địa chỉ, ghi chú. */
    nhanPhu?: ReactNode;
    /** Chuỗi dùng để LỌC. Người gọi tự ghép, vì nhãn là ReactNode nên không đọc chữ ra được. */
    loc: string;
    /** Tên nhóm phụ; các mục cùng `nhom` xếp chung dưới một tiêu đề. */
    nhom?: string;
    /**
     * Lý do dòng NÀY không tích được. Có mặt = khoá MỀM; vắng mặt = tích bình thường.
     *
     * Khoá mềm chứ không `disabled`, cùng lập luận với `Nut.tsx`: `disabled` gạt ô khỏi thứ
     * tự tab nên người dùng bàn phím không dừng lại được để nghe lý do, cảm ứng thì không có
     * rê chuột, và trình đọc màn hình bỏ qua mô tả của một control đã disabled. Ba nhóm đó
     * cộng lại nhiều hơn nhóm dùng chuột trên máy bàn.
     *
     * Khác `khoa` ở cấp props: `khoa` nói cả danh sách chưa dùng được, `khoaDong` nói đúng
     * một dòng nằm ngoài tầm - hai câu khác nhau và người dùng phải phân biệt được.
     */
    khoaDong?: string;
  }
  ```

  Thay thân `veMuc` bằng:

  ```tsx
  function veMuc(m: MucChon) {
    const khoaMem = m.khoaDong !== undefined;
    const idLyDo = `${idGoc}-khoa-${m.id}`;
    return (
      <label
        key={m.id}
        className={[styles.muc, khoaMem ? styles.mo : null].filter(Boolean).join(' ')}
        data-muc={m.id}
        data-khoa-dong={khoaMem || undefined}
      >
        <input
          type="checkbox"
          value={m.id}
          checked={boDaChon.has(m.id)}
          disabled={khoa || dangTai}
          aria-disabled={khoaMem || undefined}
          aria-describedby={khoaMem ? idLyDo : undefined}
          onChange={(su: ChangeEvent<HTMLInputElement>) => {
            // aria-disabled không chặn gì cả - trình duyệt vẫn bắn change như thường. Ba
            // dòng này mới là phép khoá thật; cái mờ chỉ là lời báo trước.
            if (khoaMem) return;
            doiMuc(m.id, su.target.checked);
          }}
        />
        <span className={styles.noi}>
          <span className={styles['nhan-chinh']}>{m.nhanChinh}</span>
          {m.nhanPhu === undefined ? null : (
            <span className={styles['nhan-phu']}>{m.nhanPhu}</span>
          )}
        </span>
        {/* Lý do nằm trong <label> nhưng SAU phần nhãn và ở lớp chỉ-đọc-màn-hình: nó là mô
            tả của ô, không phải tên của ô. Nối bằng aria-describedby chứ không để nó trôi
            vào tên trợ năng. */}
        {khoaMem ? (
          <span id={idLyDo} className="chi-doc-man-hinh">
            {m.khoaDong}
          </span>
        ) : null}
      </label>
    );
  }
  ```

- [ ] **Step 4: Thêm lớp `.mo` vào `DanhSachChon.module.css`.**

  Đặt ngay dưới khối `.muc:hover` đã có:

  ```css
  /* Dòng khoá mềm. Mờ đi để mắt lướt qua, nhưng ô đánh dấu vẫn dừng được bằng Tab - xem
   * khối ghi chú của `khoaDong` trong DanhSachChon.tsx. `cursor: not-allowed` là chỉ báo
   * duy nhất cho người dùng chuột, vì ô không disabled nên trình duyệt không tự đổi con trỏ. */
  .mo {
    background: var(--mau-nen-chim);
    cursor: not-allowed;
  }

  /* Ghi đè `.muc:hover`: một dòng không bấm được mà vẫn sáng lên khi rê chuột là một lời mời
   * bấm, và cú bấm đó không đi tới đâu. */
  .mo:hover {
    background: var(--mau-nen-chim);
  }

  .mo .nhan-chinh {
    color: var(--mau-chu-mo);
  }
  ```

- [ ] **Step 5: Chạy lại file test và THẤY XANH, rồi chạy cả bộ.**

  ```
  npx vitest run src/shared/components/DanhSachChon/DanhSachChon.test.tsx
  npm test
  npm run lint
  npm run arch
  ```

  `npm test` phải xanh nguyên: `UserDetailPage` đang dùng `DanhSachChon` mà không truyền
  `khoaDong`, nên hành vi cũ không được đổi. `npm run arch` xanh vì task này không thêm file.

- [ ] **Step 6: Commit.**

  ```
  feat(shared): DanhSachChon khoá được từng dòng kèm lý do

  Hôm nay component chỉ khoá được toàn bộ danh sách. Khối tích quyền của màn
  vai trò cần khoá đúng những dòng mà actor không giữ mã quyền
  (`cap_duoc: false`), nên năng lực này vào chính component dùng chung.

  Khoá MỀM bằng aria-disabled chứ không disabled, cùng lập luận đã chốt ở
  Nut.tsx: disabled gạt ô khỏi thứ tự tab nên lý do không bao giờ tới được
  người dùng bàn phím.
  ```

---

## Task 2: `DanhSachChon` checkbox cha tích cả nhóm, ba trạng thái

Mỗi tiêu đề nhóm mọc thêm một ô đánh dấu cha với ba trạng thái: trống, một phần, đầy. Nó tác
động lên những dòng TÍCH ĐƯỢC và ĐANG HIỆN của nhóm - dòng `khoaDong` không bao giờ bị nó
đụng tới, và id đang bị ô lọc giấu đi phải còn nguyên (mệnh đề số 3 ở đầu `DanhSachChon.tsx`).

**Files:**
- `src/shared/components/DanhSachChon/DanhSachChon.test.tsx`
- `src/shared/components/DanhSachChon/DanhSachChon.tsx`
- `src/shared/components/DanhSachChon/DanhSachChon.module.css`

- [ ] **Step 1: Viết test đỏ cho bốn mệnh đề của checkbox cha.**

  ```tsx
  const QUYEN: MucChon[] = [
    { id: 'q1', nhanChinh: 'Xem kho', loc: 'xem kho', nhom: 'Kho hàng' },
    { id: 'q2', nhanChinh: 'Thêm kho', loc: 'them kho', nhom: 'Kho hàng' },
    {
      id: 'q3',
      nhanChinh: 'Xoá kho',
      loc: 'xoa kho',
      nhom: 'Kho hàng',
      khoaDong: 'Bạn không giữ mã quyền này.',
    },
    { id: 'q4', nhanChinh: 'Xem vật tư', loc: 'xem vat tu', nhom: 'Danh mục vật tư' },
  ];

  /** Ô đánh dấu cha của một nhóm. Tìm qua data-chon-ca-nhom, không qua thứ tự DOM. */
  function oNhom(ten: string): HTMLInputElement {
    const o = container.querySelector<HTMLInputElement>(
      `[data-chon-ca-nhom="${ten}"]`,
    );
    if (!o) throw new Error(`không tìm thấy ô đánh dấu cha của nhóm ${ten}`);
    return o;
  }

  describe('checkbox cha tích cả nhóm', () => {
    it('KHÔNG mọc ra khi chưa bật chonCaNhom', () => {
      // Năng lực mới không được đổi hình dạng của hai chỗ dùng cũ (màn gán vai trò, màn
      // phạm vi kho) chỉ vì nó tồn tại.
      render({ muc: QUYEN });
      expect(container.querySelector('[data-chon-ca-nhom]')).toBeNull();
    });

    it('ba trạng thái đọc được bằng data-trang-thai và bằng thuộc tính DOM', () => {
      // `indeterminate` KHÔNG phải một attribute, nó là một property của phần tử DOM - nên
      // nó không nằm trong HTML và một bài test đọc outerHTML sẽ không thấy gì cả.
      render({ muc: QUYEN, chonCaNhom: true, daChon: [] });
      expect(oNhom('Kho hàng').getAttribute('data-trang-thai')).toBe('trong');
      expect(oNhom('Kho hàng').indeterminate).toBe(false);
      expect(oNhom('Kho hàng').checked).toBe(false);

      render({ muc: QUYEN, chonCaNhom: true, daChon: ['q1'] });
      expect(oNhom('Kho hàng').getAttribute('data-trang-thai')).toBe('mot-phan');
      expect(oNhom('Kho hàng').indeterminate).toBe(true);

      // ĐẦY tính trên những dòng TÍCH ĐƯỢC: q3 khoá nên nó không bao giờ vào được tập chọn,
      // và một nhóm không bao giờ "đầy" là một ô cha không bao giờ tích được hết.
      render({ muc: QUYEN, chonCaNhom: true, daChon: ['q1', 'q2'] });
      expect(oNhom('Kho hàng').getAttribute('data-trang-thai')).toBe('day');
      expect(oNhom('Kho hàng').checked).toBe(true);
      expect(oNhom('Kho hàng').indeterminate).toBe(false);
    });

    it('tích ô cha KHÔNG kéo theo dòng khoá, và không đụng nhóm khác', () => {
      const daGoi = vi.fn();
      render({ muc: QUYEN, chonCaNhom: true, daChon: ['q4'], onDoiChon: daGoi });

      act(() => {
        oNhom('Kho hàng').click();
      });

      // q3 vắng mặt: khoá thì không cấp được. q4 còn nguyên: nó thuộc nhóm khác.
      expect(daGoi).toHaveBeenCalledWith(['q4', 'q1', 'q2']);
    });

    it('bỏ tích ô cha khi đang lọc KHÔNG đánh rơi id bị ô lọc giấu', () => {
      // Cùng cái bẫy mà mệnh đề số 3 ở đầu DanhSachChon.tsx nói tới, nay ở cấp nhóm: ô cha
      // chỉ được tác động lên những dòng ĐANG HIỆN, và phải xuất phát từ `daChon` ĐẦY ĐỦ.
      const daGoi = vi.fn();
      render({
        muc: QUYEN,
        chonCaNhom: true,
        daChon: ['q1', 'q2', 'q4'],
        onDoiChon: daGoi,
      });
      go('them');

      act(() => {
        oNhom('Kho hàng').click();
      });

      // Chỉ q2 đang hiện, nên chỉ q2 rời đi. q1 bị ô lọc giấu và q4 ở nhóm khác đều còn.
      expect(daGoi).toHaveBeenCalledWith(['q1', 'q4']);
    });
  });
  ```

- [ ] **Step 2: Chạy `npx vitest run src/shared/components/DanhSachChon/DanhSachChon.test.tsx` và THẤY ĐỎ.**

- [ ] **Step 3: Thêm prop `chonCaNhom` và hàm thuần `trangThaiNhom`.**

  Trong `DanhSachChon.tsx`, thêm vào `DanhSachChonProps`:

  ```tsx
    /**
     * Bật ô đánh dấu CHA ở mỗi tiêu đề nhóm. Ba trạng thái: trống / một phần / đầy.
     *
     * Mặc định TẮT: hai chỗ dùng cũ (màn gán vai trò, màn phạm vi kho) có nhóm phụ nhưng
     * không cần tích cả nhóm, và mọc thêm một ô đánh dấu ở đó là đổi hình dạng của một màn
     * đang chạy để phục vụ một màn khác.
     */
    chonCaNhom?: boolean;
  ```

  Khai kiểu và hàm thuần ở cấp module, cạnh `gomNhom` đã có:

  ```tsx
  export type TrangThaiNhom = 'trong' | 'mot-phan' | 'day';

  /**
   * Ba trạng thái của ô đánh dấu cha, tính trên những mục TÍCH ĐƯỢC trong `muc`.
   *
   * Dòng `khoaDong` bị loại khỏi cả tử số lẫn mẫu số. Nếu đếm nó vào mẫu số thì một nhóm có
   * một dòng ngoài tầm sẽ KHÔNG BAO GIỜ đầy, và ô cha đứng mãi ở "một phần" dù người dùng đã
   * tích hết những gì họ tích được - một trạng thái không có cách nào thoát ra.
   *
   * Nhóm không còn dòng nào tích được thì trả 'trong' và người gọi khoá luôn ô cha: "đầy"
   * trên một tập rỗng là một câu vô nghĩa.
   */
  export function trangThaiNhom(
    muc: readonly MucChon[],
    boDaChon: ReadonlySet<string>,
  ): TrangThaiNhom {
    const chonDuoc = muc.filter((m) => m.khoaDong === undefined);
    if (chonDuoc.length === 0) return 'trong';
    const so = chonDuoc.filter((m) => boDaChon.has(m.id)).length;
    if (so === 0) return 'trong';
    return so === chonDuoc.length ? 'day' : 'mot-phan';
  }
  ```

- [ ] **Step 4: Dựng ô cha trong tiêu đề nhóm.**

  Thêm `chonCaNhom = false` vào phần huỷ cấu trúc props của `DanhSachChon`. Thêm hàm
  `doiCaNhom` ngay dưới `doiMuc`:

  ```tsx
  function doiCaNhom(mucTrongNhom: readonly MucChon[], bat: boolean): void {
    // Chỉ những dòng TÍCH ĐƯỢC và ĐANG HIỆN: `mucTrongNhom` tới từ `khoiNhom`, mà `khoiNhom`
    // dựng trên `mucHien`. Cả hai nhánh vẫn xuất phát từ `daChon` ĐẦY ĐỦ, đúng mệnh đề số 3
    // ở đầu file - dựng lại tập chọn từ những gì đang thấy là cách làm mất id bị lọc giấu.
    const chonDuoc = mucTrongNhom.filter((m) => m.khoaDong === undefined).map((m) => m.id);
    if (chonDuoc.length === 0) return;

    if (bat) {
      const them = chonDuoc.filter((id) => !boDaChon.has(id));
      if (them.length === 0) return;
      onDoiChon([...daChon, ...them]);
      return;
    }

    const bo = new Set(chonDuoc);
    onDoiChon(daChon.filter((id) => !bo.has(id)));
  }
  ```

  Thay khối vẽ nhóm trong `than` bằng:

  ```tsx
        {khoiNhom.nhom.map((n, i) => {
          const idNhan = `${idGoc}-nhom-${i}`;
          const trangThai = trangThaiNhom(n.muc, boDaChon);
          const hetKhoa = n.muc.every((m) => m.khoaDong !== undefined);
          // role="group" lồng trong: nhờ nó trình đọc màn hình nói được tên nhóm khi người
          // dùng bước vào, thay vì để tiêu đề nhóm trôi qua như một dòng chữ rời.
          return (
            <div key={n.ten} role="group" aria-labelledby={idNhan}>
              <div className={styles.nhom}>
                {chonCaNhom ? (
                  <input
                    type="checkbox"
                    className={styles['o-nhom']}
                    data-chon-ca-nhom={n.ten}
                    data-trang-thai={trangThai}
                    checked={trangThai === 'day'}
                    // `indeterminate` là PROPERTY của phần tử DOM, không phải attribute -
                    // React không đặt được nó qua JSX, nên nó phải đi qua một ref callback.
                    ref={(el) => {
                      if (el !== null) el.indeterminate = trangThai === 'mot-phan';
                    }}
                    disabled={khoa || dangTai || hetKhoa}
                    aria-label={`Tích cả nhóm ${n.ten}`}
                    onChange={(su: ChangeEvent<HTMLInputElement>) =>
                      doiCaNhom(n.muc, su.target.checked)
                    }
                  />
                ) : null}
                <span id={idNhan}>{n.ten}</span>
              </div>
              {n.muc.map(veMuc)}
            </div>
          );
        })}
  ```

  Tiêu đề nhóm đổi từ `<p id=...>` thành `<div class="nhom"><span id=...></span></div>`:
  `aria-labelledby` vẫn trỏ đúng vào chữ, còn ô cha đứng cạnh nó chứ không nằm trong tên nhóm.

- [ ] **Step 5: Sửa lớp `.nhom` và thêm `.o-nhom` trong `DanhSachChon.module.css`.**

  Thêm ba dòng vào khối `.nhom` đã có, giữ nguyên mọi giá trị khác:

  ```css
  .nhom {
    display: flex;
    align-items: center;
    gap: var(--gian-3);
    margin: 0;
    padding: var(--gian-2) var(--gian-3);
    border-bottom: 1px solid var(--mau-vien);
    background: var(--mau-nen-chim);
    font-size: var(--chu-xs);
    font-weight: var(--dam-manh);
    letter-spacing: 0.04em;
    text-transform: uppercase;
    color: var(--mau-chu-mo);
  }

  /* Cùng cỡ với ô đánh dấu của một dòng thường, để hai cột ô nằm thẳng hàng dọc. KHÔNG khai
   * min-height, cùng lý do đã ghi ở `.muc input[type='checkbox']`. */
  .o-nhom {
    margin: 0;
    width: var(--gian-4);
    height: var(--gian-4);
    flex: none;
    accent-color: var(--mau-chinh);
  }
  ```

- [ ] **Step 6: Chạy test, lint, arch; THẤY XANH.**

  ```
  npx vitest run src/shared/components/DanhSachChon/DanhSachChon.test.tsx
  npm test
  npm run lint
  npm run arch
  ```

- [ ] **Step 7: Commit.**

  ```
  feat(shared): DanhSachChon có ô đánh dấu cha ba trạng thái cho mỗi nhóm

  Khối tích quyền của màn vai trò bày 50 mã gom theo phân hệ rồi theo đối
  tượng, và tích từng ô một là năm mươi cú bấm. Ô cha tính trạng thái trên
  những dòng TÍCH ĐƯỢC, nên một nhóm có dòng ngoài tầm vẫn "đầy" được.

  Mặc định tắt: hai chỗ dùng cũ có nhóm phụ nhưng không cần năng lực này.
  ```

---

## Task 3: DTO và hàm HTTP cho ba endpoint mới

Không tạo file API mới: `ROLES_PATH` đã sống ở `user-api.ts` và `GET /roles` đã được gọi từ
đó. Một `role-api.ts` thứ hai bên cạnh sẽ chia đôi hợp đồng của cùng một tài nguyên.

**Files:**
- `src/modules/user/api/user-api.ts`
- `src/modules/user/api/user-api.test.ts` (tạo)
- `src/modules/user/components/loi-vai-tro.ts` (tạo)
- `src/modules/user/components/loi-vai-tro.test.ts` (tạo)

- [ ] **Step 1: Viết test đỏ cho các vị ngữ thuần.**

  Tạo `src/modules/user/api/user-api.test.ts`:

  ```ts
  // Test cho những vị ngữ THUẦN của user-api.ts - không lời gọi mạng nào ở đây. Chúng nằm
  // cạnh DTO chứ không trong màn hình vì chúng là kiến thức về HÌNH DẠNG DỮ LIỆU, và vì để
  // chúng ở đây thì màn hình không phải viết `.dang_dung` hay `.quyen` cạnh một nhánh JSX.
  import { describe, expect, it } from 'vitest';

  import {
    cungTapQuyen,
    nhomHienThi,
    phanHeChonDuoc,
    vaiTroDangDung,
    type QuyenDTO,
    type VaiTroKhaDungDTO,
  } from './user-api';

  function quyen(them: Partial<QuyenDTO>): QuyenDTO {
    return {
      ma: 'inventory.item_create',
      nhan: 'Thêm vật tư',
      nhom: 'Danh mục vật tư',
      phan_he: 'inventory',
      nhan_phan_he: 'Kho vận',
      cap_duoc: true,
      ...them,
    };
  }

  function vaiTro(them: Partial<VaiTroKhaDungDTO>): VaiTroKhaDungDTO {
    return {
      ma: 'inventory.thu_kho',
      nhan: 'Thủ kho',
      id: 'vt-1',
      mo_ta: '',
      dang_dung: true,
      he_thong_tao: false,
      phan_he: ['inventory'],
      nhan_phan_he: ['Kho vận'],
      so_nguoi_giu: 0,
      ...them,
    };
  }

  describe('vaiTroDangDung', () => {
    it('bỏ vai trò đã tắt, giữ nguyên thứ tự của những vai trò còn lại', () => {
      const ds = [
        vaiTro({ ma: 'a', dang_dung: true }),
        vaiTro({ ma: 'b', dang_dung: false }),
        vaiTro({ ma: 'c', dang_dung: true }),
      ];
      expect(vaiTroDangDung(ds).map((v) => v.ma)).toEqual(['a', 'c']);
    });
  });

  describe('phanHeChonDuoc', () => {
    it('gom cặp mã–nhãn phân hệ, không lặp, giữ thứ tự backend trả về', () => {
      // Thứ tự là thứ tự KHAI của bảng hằng bên Go, và đó chính là thứ tự màn hình vẽ. Sắp
      // lại ở frontend là dựng một thứ tự thứ hai cho cùng một danh mục.
      const ds = [
        quyen({ phan_he: 'inventory', nhan_phan_he: 'Kho vận' }),
        quyen({ phan_he: 'inventory', nhan_phan_he: 'Kho vận' }),
        quyen({ phan_he: 'auth', nhan_phan_he: 'Quản trị hệ thống' }),
      ];
      expect(phanHeChonDuoc(ds)).toEqual([
        { ma: 'inventory', nhan: 'Kho vận' },
        { ma: 'auth', nhan: 'Quản trị hệ thống' },
      ]);
    });
  });

  describe('nhomHienThi', () => {
    it('ghép nhãn phân hệ với tên nhóm', () => {
      expect(nhomHienThi(quyen({ nhan_phan_he: 'Kho vận', nhom: 'Tồn kho' }))).toBe(
        'Kho vận · Tồn kho',
      );
    });
  });

  describe('cungTapQuyen', () => {
    it('không quan tâm thứ tự, nhưng phân biệt được thiếu và thừa', () => {
      expect(cungTapQuyen(['a', 'b'], ['b', 'a'])).toBe(true);
      expect(cungTapQuyen(['a'], ['a', 'b'])).toBe(false);
      expect(cungTapQuyen(['a', 'b'], ['a'])).toBe(false);
      expect(cungTapQuyen([], [])).toBe(true);
    });
  });
  ```

  Tạo `src/modules/user/components/loi-vai-tro.test.ts`:

  ```ts
  import { describe, expect, it } from 'vitest';

  import { cauLoiVaiTro } from './loi-vai-tro';

  describe('cauLoiVaiTro', () => {
    it('đổi bốn mã lỗi của đợt 2b thành câu tiếng Việt CÓ DẤU', () => {
      // Backend trả thông điệp KHÔNG DẤU (role_service.go). Một màn hình nửa câu có dấu nửa
      // không là thứ người dùng thấy ngay, nên chữ hiển thị dựng ở đây theo MÃ lỗi - không
      // theo `message`, vì message sửa lúc nào cũng được mà không tính breaking (C-API-06).
      expect(cauLoiVaiTro('ERR_AUTH_ROLE_CODE_DUPLICATED')).toContain('Mã vai trò');
      expect(cauLoiVaiTro('ERR_AUTH_ROLE_PERMISSION_UNKNOWN')).toContain('không có thật');
      expect(cauLoiVaiTro('ERR_AUTH_ROLE_PERMISSION_FORBIDDEN')).toContain('không giữ');
      expect(cauLoiVaiTro('ERR_AUTH_ROLE_SYSTEM_LOCKED')).toContain('hệ thống');
    });

    it('trả null cho mã lạ và cho null - để chỗ gọi rơi về thông điệp gốc của backend', () => {
      // Nuốt một mã lạ thành một câu chung chung là làm mất thông tin duy nhất còn lại.
      expect(cauLoiVaiTro('ERR_GI_DO_MOI')).toBeNull();
      expect(cauLoiVaiTro(null)).toBeNull();
    });
  });
  ```

- [ ] **Step 2: Chạy hai file test và THẤY ĐỎ.**

  ```
  npx vitest run src/modules/user/api/user-api.test.ts src/modules/user/components/loi-vai-tro.test.ts
  ```

- [ ] **Step 3: Mở rộng `VaiTroKhaDungDTO` và thêm các DTO mới trong `user-api.ts`.**

  Thay khối `VaiTroKhaDungDTO` hiện có (giữ nguyên khối ghi chú ở trên nó, nối thêm đoạn mới):

  ```ts
  // VaiTroKhaDungDTO là một dòng của `GET /roles`. Hai trường đầu là hợp đồng CŨ và chúng
  // không đổi; bảy trường sau là phần thêm của đợt 2b (spec mục 6.3), khớp từng tên với
  // handler.VaiTroKhaDungDTO bên backend.
  //
  // `nhan_phan_he` song song TỪNG PHẦN TỬ với `phan_he` - ghép hai mảng theo chỉ số, nên hai
  // mảng lệch độ dài là dán nhãn của module này cho module kia.
  //
  // `quyen` TUỲ CHỌN, và dấu chấm hỏi đó là một lời khai chứ không phải một chỗ lười: hôm nay
  // `GET /roles` KHÔNG trả trường này và không có `GET /roles/:id` - chỉ thân trả về của
  // POST/PATCH mới mang nó. Màn Sửa vì vậy chưa tích sẵn được tập quyền hiện tại, và nó phải
  // NÓI RA điều đó thay vì gửi lên một mảng rỗng đè lên tập quyền thật. Ngày backend thêm
  // trường này vào `GET /roles`, màn sửa tự sống dậy mà không phải đổi một dòng nào.
  export interface VaiTroKhaDungDTO {
    ma: string;
    nhan: string;

    id: string;
    mo_ta: string;
    dang_dung: boolean;
    he_thong_tao: boolean;
    phan_he: string[];
    nhan_phan_he: string[];
    so_nguoi_giu: number;
    quyen?: string[];
  }

  // VaiTroDTO là thân trả về của CẢ HAI đường ghi. Nó là VaiTroKhaDungDTO cộng đúng một
  // trường bắt buộc: `quyen` luôn có mặt ở đây, đúng như handler.VaiTroDTO khai.
  export interface VaiTroDTO extends VaiTroKhaDungDTO {
    quyen: string[];
  }

  // QuyenDTO là một dòng của `GET /permissions`.
  //
  // `cap_duoc` = actor có đang giữ chính mã quyền đó không. Đây là NGOẠI LỆ có ý thức của lối
  // "không bày mảnh dữ liệu để frontend tự suy quyền": câu hỏi ở đây không phải "actor làm
  // được thao tác này không" mà "actor có giữ đúng mã này không", và màn hình cần câu trả lời
  // đó để vẽ một dòng mờ kèm lý do thay vì một ô tích bấm được rồi 422 (ADR-0038 mục 2).
  //
  // Ẩn ô tích là UX, không phải bảo mật: backend vẫn từ chối một mã `cap_duoc: false` gửi lên.
  export interface QuyenDTO {
    ma: string;
    nhan: string;
    nhom: string;
    phan_he: string;
    nhan_phan_he: string;
    cap_duoc: boolean;
  }

  // TaoVaiTroRequest - thân của `POST /roles`. KHÔNG có `code`: mã do backend sinh từ module
  // và tên, và gửi `code` lên bị từ chối 422 (role_handler.go). Màn hình chỉ XEM TRƯỚC mã.
  export interface TaoVaiTroRequest {
    name: string;
    description: string;
    module: string;
    permissions: string[];
  }

  // SuaVaiTroRequest - thân của `PATCH /roles/:id`, mọi trường TUỲ CHỌN. Không gửi một trường
  // nghĩa là không đụng tới nó; `permissions: []` là một lệnh hợp lệ và rõ ràng - gỡ sạch
  // quyền - nên vắng mặt và mảng rỗng phải phân biệt được.
  //
  // `dang_dung` là tên tiếng Việt cạnh ba tên tiếng Anh, và đó là CHỦ Ý của hợp đồng: nó khớp
  // đúng tên trường `GET /roles` trả về, nên client đọc một tên rồi ghi lại chính tên đó.
  export interface SuaVaiTroRequest {
    name?: string;
    description?: string;
    permissions?: string[];
    dang_dung?: boolean;
  }

  // Tập đường dẫn field mà form vai trò có ô để tô. `code` có mặt dù form KHÔNG có ô mã ở chế
  // độ tạo: backend trả 422 trỏ vào `code` khi client gửi trường đó, và một field không nằm
  // trong tập này sẽ bị `toFormErrors` đẩy lên banner - đúng chỗ nó cần tới.
  export const VAI_TRO_GHI_FIELDS: ReadonlySet<string> = new Set([
    'name',
    'description',
    'module',
    'permissions',
    'dang_dung',
    'code',
  ]);
  ```

- [ ] **Step 4: Thêm bốn vị ngữ thuần và ba hàm HTTP.**

  Đặt các vị ngữ cạnh `khongConTrongDanhMuc` đã có:

  ```ts
  // vaiTroDangDung lọc bỏ vai trò đã tắt khỏi danh mục.
  //
  // `GET /roles` là MỘT endpoint phục vụ cả màn quản trị lẫn màn gán (ADR-0032 mục 1), nên nó
  // trả cả vai trò đã tắt - màn quản trị cần thấy chúng để bật lại, màn gán thì không được cho
  // chọn chúng. Phép lọc nằm ở đây chứ không trong màn hình vì nó là lọc theo DỮ LIỆU BACKEND
  // TRẢ VỀ, không phải suy diễn quyền: để nó ở đây thì màn gán không viết `.dang_dung` cạnh
  // một nhánh JSX, và luật `erp/c-ts-06-no-role-guess` không có gì để báo oan.
  export function vaiTroDangDung(ds: readonly VaiTroKhaDungDTO[]): VaiTroKhaDungDTO[] {
    return ds.filter((v) => v.dang_dung);
  }

  // phanHeChonDuoc rút danh sách phân hệ từ chính danh mục quyền, không từ một mảng hằng gõ
  // tay ở frontend. Một hằng gõ tay là một bản thứ hai của danh sách module, và nó lệch vào
  // đúng ngày backend thêm một phân hệ.
  //
  // Giữ THỨ TỰ backend trả về: đó là thứ tự khai của bảng hằng bên Go, và cũng là thứ tự màn
  // hình vẽ khối quyền - hai chỗ cùng một thứ tự thì mắt không phải nhảy.
  export function phanHeChonDuoc(
    ds: readonly QuyenDTO[],
  ): Array<{ ma: string; nhan: string }> {
    const ra: Array<{ ma: string; nhan: string }> = [];
    const daCo = new Set<string>();
    for (const q of ds) {
      if (daCo.has(q.phan_he)) continue;
      daCo.add(q.phan_he);
      ra.push({ ma: q.phan_he, nhan: q.nhan_phan_he });
    }
    return ra;
  }

  // nhomHienThi ghép tên nhóm hai cấp cho khối tích quyền: phân hệ rồi tới đối tượng.
  //
  // MỘT chuỗi chứ không hai cấp lồng nhau, và đó là một lựa chọn: `DanhSachChon` gom nhóm một
  // cấp, giữ nguyên thứ tự xuất hiện đầu tiên - nên ghép chuỗi cho ra đúng thứ tự phân hệ rồi
  // nhóm mà không phải dựng một cấp lồng thứ hai trong một component dùng chung.
  export function nhomHienThi(q: QuyenDTO): string {
    return `${q.nhan_phan_he} · ${q.nhom}`;
  }

  // cungTapQuyen so hai tập quyền, bỏ qua thứ tự. Màn Sửa dùng nó để quyết có đưa
  // `permissions` vào thân PATCH hay không: gửi một tập không đổi là một lần ghi
  // `role_permissions` và một dòng audit cho việc không làm gì cả.
  export function cungTapQuyen(a: readonly string[], b: readonly string[]): boolean {
    if (a.length !== b.length) return false;
    const bo = new Set(b);
    return a.every((one) => bo.has(one));
  }
  ```

  Ba hàm HTTP, đặt cạnh `listVaiTroKhaDung` đã có:

  ```ts
  // listQuyen đọc CẢ danh mục quyền trong một lời gọi. Hôm nay backend khai 50 mã, dưới trần
  // 100 của `page_size` - `meta.total` vẫn được đọc ra để màn hình cảnh báo nếu danh mục vượt
  // trần, chứ không cắt im lặng. Cùng lối `listVaiTroKhaDung`.
  export function listQuyen(): Promise<Page<QuyenDTO>> {
    return getList<QuyenDTO>(PERMISSIONS_PATH, { page: 1, page_size: MAX_PAGE_SIZE });
  }

  export function taoVaiTro(input: TaoVaiTroRequest): Promise<VaiTroDTO> {
    return send<VaiTroDTO>('POST', ROLES_PATH, input);
  }

  export function suaVaiTro(id: string, input: SuaVaiTroRequest): Promise<VaiTroDTO> {
    return send<VaiTroDTO>('PATCH', `${ROLES_PATH}/${encodeURIComponent(id)}`, input);
  }
  ```

  Và hằng đường dẫn, cạnh `ROLES_PATH`:

  ```ts
  // Danh mục quyền của HỆ THỐNG, không phải quyền của một người - nên nó là /permissions trần
  // chứ không nằm dưới /users/:id, đúng như backend đăng ký route.
  const PERMISSIONS_PATH = '/permissions';
  ```

- [ ] **Step 5: Tạo `src/modules/user/components/loi-vai-tro.ts`.**

  ```ts
  // Bốn mã lỗi của đường ghi vai trò (spec mục 6.6) đổi thành câu tiếng Việt CÓ DẤU.
  //
  // Rẽ nhánh theo `code`, KHÔNG theo `message`: thông điệp là chuỗi backend sửa bất cứ lúc nào
  // mà không tính breaking change (C-API-06), còn mã thì không (C-API-05). Đây là cùng một
  // luật mà `shared/api/form-errors.ts` đã chốt cho cả hệ.
  //
  // Vì sao dựng lại câu thay vì hiện thẳng `message` của backend: thông điệp của
  // `role_service.go` viết KHÔNG DẤU, đồng bộ trong nội bộ đường ghi ấy. Một màn hình nửa câu
  // có dấu nửa không là thứ người dùng thấy ngay - và người dùng của hệ này không làm kỹ
  // thuật, nên "ma quyen khong co that" đọc ra như một lỗi hệ thống chứ không như một lời chỉ
  // dẫn.

  export const MA_LOI_VAI_TRO = {
    trungMa: 'ERR_AUTH_ROLE_CODE_DUPLICATED',
    quyenKhongCoThat: 'ERR_AUTH_ROLE_PERMISSION_UNKNOWN',
    quyenNgoaiTam: 'ERR_AUTH_ROLE_PERMISSION_FORBIDDEN',
    vaiTroHeThong: 'ERR_AUTH_ROLE_SYSTEM_LOCKED',
  } as const;

  const CAU: Record<string, string> = {
    [MA_LOI_VAI_TRO.trungMa]:
      'Mã vai trò hệ thống vừa sinh đã có người dùng. Đổi tên vai trò rồi lưu lại.',
    [MA_LOI_VAI_TRO.quyenKhongCoThat]:
      'Có mã quyền không có thật trong danh mục. Tải lại màn hình rồi tích lại.',
    [MA_LOI_VAI_TRO.quyenNgoaiTam]:
      'Có mã quyền chính bạn không giữ, nên bạn không cấp được. Bỏ tích những dòng đang mờ.',
    [MA_LOI_VAI_TRO.vaiTroHeThong]:
      'Đây là vai trò do hệ thống tạo: tên và mô tả sửa được, tập quyền và trạng thái thì không. Tạo một vai trò riêng nếu cần tập quyền khác.',
  };

  // null cho mã lạ và cho null, để chỗ gọi rơi về thông điệp gốc của backend. Nuốt một mã lạ
  // thành một câu chung chung là làm mất thông tin duy nhất còn lại về chuyện vừa xảy ra.
  export function cauLoiVaiTro(errorCode: string | null): string | null {
    if (errorCode === null) return null;
    return CAU[errorCode] ?? null;
  }
  ```

- [ ] **Step 6: Chạy test, lint, arch.**

  ```
  npx vitest run src/modules/user/api/user-api.test.ts src/modules/user/components/loi-vai-tro.test.ts
  npm test
  npm run lint
  npm run arch
  ```

  `npm run arch` sẽ ĐỎ: hai file mới làm golden `arch/LEVELS.md` lệch. Chạy
  `npm run arch:update` rồi `npm run arch` lại cho xanh, và commit kèm file golden.

- [ ] **Step 7: Commit.**

  ```
  feat(user): DTO và hàm HTTP cho ba endpoint vai trò của đợt 2b

  GET /permissions, POST /roles, PATCH /roles/:id, cộng bảy trường mới của
  GET /roles. Bốn vị ngữ thuần (vaiTroDangDung, phanHeChonDuoc, nhomHienThi,
  cungTapQuyen) nằm cạnh DTO chứ không trong màn hình: chúng là kiến thức về
  hình dạng dữ liệu, và để chúng ở đây thì màn hình không viết `.dang_dung`
  cạnh một nhánh JSX.

  `quyen` khai TUỲ CHỌN trên VaiTroKhaDungDTO: GET /roles hôm nay không trả
  trường đó và không có GET /roles/:id, nên màn Sửa chưa tích sẵn được tập
  quyền hiện tại. Xem khối ghi chú tại chỗ.
  ```

---

## Task 4: Hook cho danh mục quyền và hai đường ghi

**Files:**
- `src/modules/user/hooks/user-keys.ts`
- `src/modules/user/hooks/use-danh-muc-quyen.ts` (tạo)
- `src/modules/user/hooks/use-tao-vai-tro.ts` (tạo)
- `src/modules/user/hooks/use-sua-vai-tro.ts` (tạo)

Không có test riêng cho tầng hook: chúng là lớp mỏng trên TanStack Query và mọi mệnh đề của
chúng đều được khoá qua bộ test màn hình ở Task 5 và Task 6, nơi `fetch` bị thay và số lời gọi
đếm được. Một bài test dựng `QueryClientProvider` chỉ để gọi một hook là một bản sao của bài
test màn hình, kém trung thực hơn.

- [ ] **Step 1: Thêm khoá `danhMucQuyen` vào `user-keys.ts`.**

  ```ts
    // Danh mục vai trò KHÔNG treo dưới 'users': nó là danh mục của hệ thống, không thuộc một
    // người nào, nên một lần invalidate cây 'users' không được phép làm nó tải lại.
    danhMucVaiTro: ['roles'] as const,

    // Danh mục quyền cũng vậy, và nó còn KHÔNG treo dưới 'roles': ghi một vai trò không đổi
    // danh mục 50 mã quyền, nên một lần invalidate sau khi lưu không được kéo theo nó.
    danhMucQuyen: ['permissions'] as const,
  ```

- [ ] **Step 2: Tạo `use-danh-muc-quyen.ts`.**

  ```ts
  import { useQuery } from '@tanstack/react-query';

  import { listQuyen } from '../api/user-api';

  import { userKeys } from './user-keys';

  // Danh mục quyền là một bảng HẰNG bên Go: nó chỉ đổi khi lên bản mới. Cờ `cap_duoc` thì phụ
  // thuộc actor, nhưng actor không đổi giữa chừng một phiên. Năm phút, cùng con số với danh
  // mục vai trò - dài hơn mặc định 30 giây của repo, nhưng vẫn có trần.
  const THOI_GIAN_CON_TUOI = 5 * 60_000;

  export function useDanhMucQuyen() {
    return useQuery({
      queryKey: userKeys.danhMucQuyen,
      queryFn: () => listQuyen(),
      staleTime: THOI_GIAN_CON_TUOI,
    });
  }
  ```

- [ ] **Step 3: Tạo `use-tao-vai-tro.ts`.**

  ```ts
  import { useMutation, useQueryClient } from '@tanstack/react-query';

  import {
    taoVaiTro,
    VAI_TRO_GHI_FIELDS,
    type TaoVaiTroRequest,
    type VaiTroDTO,
  } from '../api/user-api';

  import { toMutationErrors, type MutationErrorView } from './mutation-errors';
  import { userKeys } from './user-keys';

  export interface UseTaoVaiTroResult extends MutationErrorView {
    mutate: (input: TaoVaiTroRequest) => void;
    reset: () => void;
    isPending: boolean;
    saved: VaiTroDTO | undefined;
  }

  export function useTaoVaiTro(): UseTaoVaiTroResult {
    const queryClient = useQueryClient();

    const mutation = useMutation({
      mutationFn: (input: TaoVaiTroRequest) => taoVaiTro(input),
      retry: false,

      onSuccess: () => {
        // Danh mục vai trò có thêm một dòng, nên cả màn quản trị lẫn màn gán đều đã cũ. Một
        // khoá duy nhất phục vụ cả hai màn, nên một lần vô hiệu là đủ.
        //
        // KHÔNG đụng `userKeys.danhMucQuyen`: 50 mã quyền là một bảng hằng bên Go, tạo một vai
        // trò không thêm bớt mã nào.
        void queryClient.invalidateQueries({ queryKey: userKeys.danhMucVaiTro });
      },
    });

    return {
      mutate: (input) => mutation.mutate(input),
      reset: mutation.reset,
      isPending: mutation.isPending,
      saved: mutation.data,
      ...toMutationErrors(mutation.error, VAI_TRO_GHI_FIELDS),
    };
  }
  ```

- [ ] **Step 4: Tạo `use-sua-vai-tro.ts`.**

  ```ts
  import { useMutation, useQueryClient } from '@tanstack/react-query';

  import {
    suaVaiTro,
    VAI_TRO_GHI_FIELDS,
    type SuaVaiTroRequest,
    type VaiTroDTO,
  } from '../api/user-api';

  import { toMutationErrors, type MutationErrorView } from './mutation-errors';
  import { userKeys } from './user-keys';

  // `id` đi trong BIẾN của mutate chứ không trong tham số của hook, và đó không phải chuộng
  // dài dòng: màn danh sách có một nút Tắt trên MỖI hàng, mà hook không gọi được trong một
  // vòng lặp. Một hook duy nhất nhận id lúc bấm phục vụ được cả màn form (một bản ghi) lẫn màn
  // danh sách (một bản ghi bất kỳ trong bảng).
  export interface SuaVaiTroBien {
    id: string;
    than: SuaVaiTroRequest;
  }

  export interface UseSuaVaiTroResult extends MutationErrorView {
    mutate: (bien: SuaVaiTroBien) => void;
    reset: () => void;
    isPending: boolean;
    saved: VaiTroDTO | undefined;
    /** id của bản ghi đang gửi, hoặc null. Màn danh sách cần nó để chỉ quay ĐÚNG một hàng. */
    dangSuaId: string | null;
  }

  export function useSuaVaiTro(): UseSuaVaiTroResult {
    const queryClient = useQueryClient();

    const mutation = useMutation({
      mutationFn: (bien: SuaVaiTroBien) => suaVaiTro(bien.id, bien.than),
      retry: false,

      onSuccess: () => {
        // Không `setQueryData` một dòng vào giữa danh sách: cache đang giữ một `Page` nguyên
        // khối kèm `meta`, và vá một phần tử trong đó là dựng một bản ghép tay của thứ backend
        // vừa trả về nguyên vẹn. Danh mục nhỏ (một lời gọi, page_size 100) nên tải lại rẻ.
        void queryClient.invalidateQueries({ queryKey: userKeys.danhMucVaiTro });
      },
    });

    return {
      mutate: (bien) => mutation.mutate(bien),
      reset: mutation.reset,
      isPending: mutation.isPending,
      saved: mutation.data,
      dangSuaId: mutation.isPending ? (mutation.variables?.id ?? null) : null,
      ...toMutationErrors(mutation.error, VAI_TRO_GHI_FIELDS),
    };
  }
  ```

- [ ] **Step 5: Chạy lint, arch, test.**

  ```
  npm run lint
  npm test
  npm run arch
  ```

  `npm run arch` đỏ vì ba file mới - chạy `npm run arch:update`, rồi `npm run arch` lại.

- [ ] **Step 6: Commit.**

  ```
  feat(user): hook cho danh mục quyền và hai đường ghi vai trò

  useSuaVaiTro nhận id trong biến của mutate chứ không trong tham số của hook:
  màn danh sách có nút Tắt trên mỗi hàng, mà hook không gọi được trong vòng lặp.
  Nó trả thêm dangSuaId để đúng một hàng quay chứ không cả bảng.
  ```

---

## Task 5: `VaiTroFormPage` nối API thật và khối tích quyền

Đây là task nặng nhất. Nó gỡ hằng `LY_DO_CHUA_CO_DUONG_GHI`, gỡ khối ghi chú "KHÔNG có ma
trận quyền" (ADR-0038 đã đảo mệnh đề đó), nối ba lời gọi, và dựng khối tích quyền.

Hai điều KHÔNG làm, ghi ra để người thi công không phải đoán:

- **Không viết câu "thay đổi thấy sau tối đa 30 giây".** Đường ghi vai trò gọi
  `authz.XoaBanChup` ngay sau commit, nên hiệu lực là NGAY. Câu dưới khối quyền là:
  *"Thay đổi có hiệu lực ngay sau khi lưu."*
- **Không tự quyết quyền nào hợp lệ.** `cap_duoc` của backend nói, màn hình chỉ vẽ lại.

**Files:**
- `src/modules/user/pages/VaiTroFormPage.test.tsx` (viết lại)
- `src/modules/user/pages/VaiTroFormPage.tsx`
- `src/modules/user/pages/VaiTroFormPage.module.css`

- [ ] **Step 1: Viết lại `VaiTroFormPage.test.tsx` - bộ khung và ca đỏ.**

  Bộ test cũ dựng thẳng `<VaiTroFormPage />` vì màn chạy trên hằng. Nay màn gọi mạng, nên nó
  cần `QueryClientProvider` và một `fetch` giả, đúng lối `UserDetailPage.test.tsx`.

  ```tsx
  // Test cho VaiTroFormPage.
  //
  // Khẳng định bằng `data-*`, class và thuộc tính ARIA chứ không bằng chữ trên màn: `textContent`
  // vẫn đọc được chữ mà CSS đang giấu, nên một bộ test xanh bằng chữ không nói được gì về thứ
  // người dùng nhìn thấy. Hai chỗ vẫn khoá bằng chữ - lý do khoá của nút Lưu và lý do khoá của
  // một dòng quyền - vì ở đó chính CÂU CHỮ mới là thứ phải tới được người dùng.
  //
  // Chọn phần tử bằng `[class*="ten-lop"]` chứ không `.ten-lop`: CSS Modules băm tên lớp lúc
  // dựng, nên bộ chọn lớp thẳng không khớp gì cả - và nó không khớp một cách IM LẶNG.
  import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
  import { act } from 'react';
  import { createRoot, type Root } from 'react-dom/client';
  import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

  import { clearAccessToken } from '@/shared/api/client';

  import { VaiTroFormPage } from './VaiTroFormPage';

  const QUYEN = [
    {
      ma: 'inventory.item_create',
      nhan: 'Thêm vật tư',
      nhom: 'Danh mục vật tư',
      phan_he: 'inventory',
      nhan_phan_he: 'Kho vận',
      cap_duoc: true,
    },
    {
      ma: 'inventory.item_delete',
      nhan: 'Xoá vật tư',
      nhom: 'Danh mục vật tư',
      phan_he: 'inventory',
      nhan_phan_he: 'Kho vận',
      cap_duoc: false,
    },
    {
      ma: 'machine.equipment_read',
      nhan: 'Xem thiết bị',
      nhom: 'Thiết bị',
      phan_he: 'machine',
      nhan_phan_he: 'Thiết bị',
      cap_duoc: true,
    },
  ];

  const VAI_TRO_THUONG = {
    ma: 'inventory.thu_kho',
    nhan: 'Thủ kho',
    id: 'vt-1',
    mo_ta: 'Ghi nhận nhập xuất.',
    dang_dung: true,
    he_thong_tao: false,
    phan_he: ['inventory'],
    nhan_phan_he: ['Kho vận'],
    so_nguoi_giu: 12,
  };

  const VAI_TRO_HE_THONG = {
    ...VAI_TRO_THUONG,
    id: 'vt-2',
    ma: 'auth.admin',
    nhan: 'Quản trị phân vùng',
    he_thong_tao: true,
  };

  function makeResponse(status: number, body: unknown, requestId = 'rq-test'): Response {
    return {
      ok: status >= 200 && status < 300,
      status,
      headers: new Headers({ 'X-Request-ID': requestId }),
      json: () => Promise.resolve(body),
    } as unknown as Response;
  }

  interface KichBan {
    vaiTro?: unknown[];
    quyen?: unknown[];
    ghi?: () => Response;
  }

  /** Số lần màn gọi từng đường, để khoá mệnh đề bằng HÀNH VI chứ không bằng chữ trên màn. */
  let soLanGhi: number;
  let thanGhiCuoi: unknown;

  function datFetch(kb: KichBan = {}): void {
    soLanGhi = 0;
    thanGhiCuoi = undefined;
    vi.stubGlobal(
      'fetch',
      vi.fn((duong: string, init?: RequestInit) => {
        const method = init?.method ?? 'GET';
        if (method !== 'GET') {
          soLanGhi += 1;
          thanGhiCuoi = JSON.parse(String(init?.body ?? '{}'));
          return Promise.resolve(
            kb.ghi?.() ??
              makeResponse(method === 'POST' ? 201 : 200, {
                data: { ...VAI_TRO_THUONG, quyen: [] },
              }),
          );
        }
        if (duong.includes('/permissions')) {
          return Promise.resolve(
            makeResponse(200, {
              data: kb.quyen ?? QUYEN,
              meta: { total: (kb.quyen ?? QUYEN).length, page: 1, page_size: 100 },
            }),
          );
        }
        return Promise.resolve(
          makeResponse(200, {
            data: kb.vaiTro ?? [VAI_TRO_THUONG, VAI_TRO_HE_THONG],
            meta: {
              total: (kb.vaiTro ?? [VAI_TRO_THUONG, VAI_TRO_HE_THONG]).length,
              page: 1,
              page_size: 100,
            },
          }),
        );
      }),
    );
  }

  let container: HTMLDivElement;
  let root: Root;

  beforeEach(() => {
    (globalThis as unknown as { IS_REACT_ACT_ENVIRONMENT: boolean }).IS_REACT_ACT_ENVIRONMENT =
      true;
    container = document.createElement('div');
    document.body.appendChild(container);
    root = createRoot(container);
    clearAccessToken();
  });

  afterEach(() => {
    act(() => {
      root.unmount();
    });
    container.remove();
    vi.unstubAllGlobals();
  });

  /** Dựng màn rồi để mọi promise đang treo chạy hết - hai lời gọi song song, hai nhịp. */
  async function render(id?: string): Promise<void> {
    const qc = new QueryClient({
      defaultOptions: { queries: { retry: false }, mutations: { retry: false } },
    });
    await act(async () => {
      root.render(
        <QueryClientProvider client={qc}>
          <VaiTroFormPage id={id} />
        </QueryClientProvider>,
      );
    });
    await act(async () => {
      await Promise.resolve();
    });
  }

  function oTheoNhan(nhan: string): HTMLElement | null {
    for (const label of container.querySelectorAll('label')) {
      if (!(label.textContent ?? '').trim().startsWith(nhan)) continue;
      const dich = label.getAttribute('for');
      if (dich === null) continue;
      return container.querySelector(`#${CSS.escape(dich)}`);
    }
    return null;
  }

  function nutLuu(): HTMLButtonElement {
    return container.querySelector('button[type="submit"]') as HTMLButtonElement;
  }

  function lyDoKhoaLuu(): string {
    const id = nutLuu().getAttribute('aria-describedby');
    if (id === null) throw new Error('nút Lưu không nối với lý do khoá nào');
    return container.querySelector(`#${CSS.escape(id)}`)?.textContent ?? '';
  }

  function oQuyen(ma: string): HTMLInputElement | null {
    const hang = container.querySelector(`[data-muc="${ma}"]`);
    return hang?.querySelector<HTMLInputElement>('input[type="checkbox"]') ?? null;
  }

  function go(o: HTMLInputElement | HTMLTextAreaElement, chu: string): void {
    const proto =
      o instanceof HTMLTextAreaElement
        ? window.HTMLTextAreaElement.prototype
        : window.HTMLInputElement.prototype;
    const setter = Object.getOwnPropertyDescriptor(proto, 'value')?.set;
    act(() => {
      setter?.call(o, chu);
      o.dispatchEvent(new Event('input', { bubbles: true }));
    });
  }

  function chon(o: HTMLSelectElement, gia: string): void {
    const setter = Object.getOwnPropertyDescriptor(window.HTMLSelectElement.prototype, 'value')?.set;
    act(() => {
      setter?.call(o, gia);
      o.dispatchEvent(new Event('change', { bubbles: true }));
    });
  }
  ```

- [ ] **Step 2: Viết các ca test đỏ cho tám mệnh đề của màn.**

  ```tsx
  describe('VaiTroFormPage - khối tích quyền', () => {
    it('vẽ đủ 3 dòng quyền, gom nhóm theo phân hệ rồi theo đối tượng', async () => {
      datFetch();
      await render();

      expect(container.querySelectorAll('[data-muc]')).toHaveLength(3);
      expect(
        container.querySelector('[data-chon-ca-nhom="Kho vận · Danh mục vật tư"]'),
      ).not.toBeNull();
      expect(container.querySelector('[data-chon-ca-nhom="Thiết bị · Thiết bị"]')).not.toBeNull();
    });

    it('dòng cap_duoc: false hiện mờ, khoá, và lý do đọc được bằng bàn phím', async () => {
      // Đây là điểm 3 người dùng chốt và là mục 2 của ADR-0038. Một ô tích bấm được rồi 422
      // là một vòng mạng để nhận một câu trả lời đã biết trước.
      datFetch();
      await render();

      const o = oQuyen('inventory.item_delete') as HTMLInputElement;
      expect(o.getAttribute('aria-disabled')).toBe('true');
      expect(o.disabled).toBe(false);

      const idLyDo = o.getAttribute('aria-describedby') as string;
      expect(container.querySelector(`#${CSS.escape(idLyDo)}`)?.textContent).toContain(
        'không giữ',
      );
      expect(
        (container.querySelector('[data-muc="inventory.item_delete"]') as HTMLElement).className,
      ).toContain('mo');
    });

    it('KHÔNG có câu 30 giây dưới khối quyền', async () => {
      // Đường ghi vai trò gọi authz.XoaBanChup ngay sau commit (ADR-0038), nên hiệu lực là
      // NGAY. Câu 30 giây chỉ còn đúng cho PUT /users/:id/roles và PUT /users/:id/scopes.
      datFetch();
      await render();

      const cau = container.querySelector('[data-hieu-luc]');
      expect(cau).not.toBeNull();
      expect(cau?.textContent).not.toContain('30 giây');
    });
  });

  describe('VaiTroFormPage - màn tạo', () => {
    it('gửi POST không kèm `code`, và kèm đúng những mã đã tích', async () => {
      // `code` gửi lên bị backend từ chối 422. Frontend chỉ XEM TRƯỚC mã (R-19).
      datFetch();
      await render();

      go(oTheoNhan('Tên vai trò') as HTMLInputElement, 'Thủ kho ca đêm');
      chon(oTheoNhan('Phân hệ áp dụng') as HTMLSelectElement, 'inventory');
      act(() => {
        (oQuyen('inventory.item_create') as HTMLInputElement).click();
      });
      await act(async () => {
        nutLuu().click();
      });

      expect(soLanGhi).toBe(1);
      expect(thanGhiCuoi).toEqual({
        name: 'Thủ kho ca đêm',
        description: '',
        module: 'inventory',
        permissions: ['inventory.item_create'],
      });
    });

    it('mã chỉ là XEM TRƯỚC và màn nói rõ mã cuối do hệ thống chốt', async () => {
      datFetch();
      await render();

      go(oTheoNhan('Tên vai trò') as HTMLInputElement, 'Thủ kho ca đêm');
      chon(oTheoNhan('Phân hệ áp dụng') as HTMLSelectElement, 'inventory');

      const khoi = container.querySelector('[data-ma-sinh]');
      expect(khoi).not.toBeNull();
      expect(khoi?.textContent).toContain('hệ thống chốt');
    });

    it('lỗi 422 trỏ vào `permissions` hiện NGAY DƯỚI khối quyền', async () => {
      datFetch({
        ghi: () =>
          makeResponse(422, {
            error: {
              code: 'ERR_AUTH_ROLE_PERMISSION_FORBIDDEN',
              message: 'ma quyen ngoai tam actor',
              fields: [{ field: 'permissions', message: 'ma quyen ngoai tam actor' }],
            },
          }),
      });
      await render();

      go(oTheoNhan('Tên vai trò') as HTMLInputElement, 'Thủ kho ca đêm');
      chon(oTheoNhan('Phân hệ áp dụng') as HTMLSelectElement, 'inventory');
      await act(async () => {
        nutLuu().click();
      });

      const loi = container.querySelector('[data-loi-truong="permissions"]');
      expect(loi).not.toBeNull();
      expect(loi?.getAttribute('role')).toBe('alert');
    });
  });

  describe('VaiTroFormPage - vai trò hệ thống', () => {
    it('khoá tập quyền và ô Đang dùng, MỞ tên và mô tả', async () => {
      // Ba thứ khoá, hai thứ mở - đúng ADR-0038 mục 3. Kiểm bằng thuộc tính chứ không bằng
      // chữ: một khối bị CSS giấu vẫn nằm nguyên trong textContent.
      datFetch();
      await render('vt-2');

      expect((oTheoNhan('Tên vai trò') as HTMLInputElement).readOnly).toBe(false);
      expect((oTheoNhan('Mô tả') as HTMLTextAreaElement).readOnly).toBe(false);

      const oDangDung = oTheoNhan('Đang dùng') as HTMLInputElement;
      expect(oDangDung.getAttribute('aria-disabled')).toBe('true');

      const khoiQuyen = container.querySelector('[data-khoi-quyen]') as HTMLElement;
      expect(khoiQuyen.getAttribute('data-khoa')).toBe('vai-tro-he-thong');
    });

    it('PATCH của vai trò hệ thống KHÔNG mang permissions lẫn dang_dung', async () => {
      // Mệnh đề đắt nhất của nhánh này: gửi hai trường đó lên là chắc chắn ăn 422, và người
      // dùng chỉ đổi tên thì không đáng nhận một lỗi nào.
      datFetch();
      await render('vt-2');

      go(oTheoNhan('Tên vai trò') as HTMLInputElement, 'Quản trị nhà máy');
      await act(async () => {
        nutLuu().click();
      });

      expect(thanGhiCuoi).toEqual({ name: 'Quản trị nhà máy' });
    });
  });

  describe('VaiTroFormPage - màn sửa khi GET /roles chưa trả `quyen`', () => {
    it('khối quyền khoá kèm lý do, và PATCH KHÔNG mang permissions', async () => {
      // Hôm nay GET /roles không trả trường `quyen` và không có GET /roles/:id. Tích sẵn một
      // tập rỗng rồi gửi lên là XOÁ SẠCH quyền của vai trò bằng một cú bấm đổi tên.
      datFetch();
      await render('vt-1');

      const khoiQuyen = container.querySelector('[data-khoi-quyen]') as HTMLElement;
      expect(khoiQuyen.getAttribute('data-khoa')).toBe('chua-doc-duoc-tap-quyen');

      go(oTheoNhan('Tên vai trò') as HTMLInputElement, 'Thủ kho chính');
      await act(async () => {
        nutLuu().click();
      });

      expect(thanGhiCuoi).toEqual({ name: 'Thủ kho chính' });
    });

    it('khi backend TRẢ `quyen`, khối mở ra và tích sẵn đúng những mã đó', async () => {
      // Bài này chốt lời hứa "tự sống dậy": không một dòng code nào phải đổi vào ngày backend
      // thêm trường ấy vào GET /roles.
      datFetch({
        vaiTro: [{ ...VAI_TRO_THUONG, quyen: ['machine.equipment_read'] }],
      });
      await render('vt-1');

      const khoiQuyen = container.querySelector('[data-khoi-quyen]') as HTMLElement;
      expect(khoiQuyen.getAttribute('data-khoa')).toBeNull();
      expect((oQuyen('machine.equipment_read') as HTMLInputElement).checked).toBe(true);
      expect((oQuyen('inventory.item_create') as HTMLInputElement).checked).toBe(false);
    });
  });

  describe('VaiTroFormPage - nút Lưu', () => {
    it('khoá MỀM kèm lý do khi thiếu tên, và lý do nói đúng chướng ngại gần nhất', async () => {
      datFetch();
      await render();

      expect(nutLuu().getAttribute('aria-disabled')).toBe('true');
      expect(lyDoKhoaLuu()).toContain('Tên vai trò');
    });
  });
  ```

- [ ] **Step 3: Chạy `npx vitest run src/modules/user/pages/VaiTroFormPage.test.tsx` và THẤY ĐỎ.**

- [ ] **Step 4: Viết lại phần vỏ của `VaiTroFormPage.tsx`.**

  Gỡ hằng `LY_DO_CHUA_CO_DUONG_GHI`, gỡ khối ghi chú "KHÔNG có ma trận quyền" (thay bằng một
  khối trỏ tới ADR-0038), gỡ import `VAI_TRO_MAU` và `PHAN_HE_CHON_DUOC`.

  ```tsx
  // # Có ma trận quyền trên màn này, từ đợt 2b
  //
  // Khối ghi chú cũ ở đây nói ngược lại: "tick từng ô quyền là việc của quản trị module". Nó
  // sai vì một lý do đọc được từ luật đã có - theo ADR-0024 mục 2 một `inventory.admin` không
  // giữ `auth.role_assign`, mà mọi tập quyền đều chạm sàn chung `auth.self_read`, nên quản trị
  // module không ghi nổi một vai trò nào. ADR-0038 đảo mệnh đề đó và đặt cửa ở `auth.*`.
  //
  // Tập quyền bày ra bị cắt theo `cap_duoc` mà backend trả về. Đó KHÔNG phải một phép suy quyền
  // ở frontend: màn hình không tính gì cả, nó vẽ lại một cờ boolean. Và ẩn ô tích là UX, không
  // phải bảo mật - backend vẫn từ chối một mã `cap_duoc: false` gửi lên.
  import { useId, useState } from 'react';
  import type { ChangeEvent, FormEvent } from 'react';

  import { Link } from '@/app/router/Link';
  import { BangThongBao } from '@/shared/components/BangThongBao/BangThongBao';
  import { DanhSachChon, type MucChon } from '@/shared/components/DanhSachChon/DanhSachChon';
  import { MaBanGhi } from '@/shared/components/MaBanGhi/MaBanGhi';
  import { Nut } from '@/shared/components/Nut/Nut';
  import { TieuDeTrang } from '@/shared/components/TieuDeTrang/TieuDeTrang';

  import {
    cungTapQuyen,
    nhomHienThi,
    phanHeChonDuoc,
    type QuyenDTO,
    type SuaVaiTroRequest,
    type VaiTroKhaDungDTO,
  } from '../api/user-api';
  import { cauLoiVaiTro } from '../components/loi-vai-tro';
  import { sinhMaVaiTro } from '../components/sinh-ma-vai-tro';
  import { useDanhMucQuyen } from '../hooks/use-danh-muc-quyen';
  import { useSuaVaiTro } from '../hooks/use-sua-vai-tro';
  import { useTaoVaiTro } from '../hooks/use-tao-vai-tro';
  import { useVaiTroKhaDung } from '../hooks/use-vai-tro-kha-dung';

  import styles from './VaiTroFormPage.module.css';

  const DUONG_DANH_SACH = '/quan-tri/phan-quyen';

  // Ba lý do khoá khối quyền, mỗi cái một CA khác hẳn nhau. Gộp chúng thành một câu chung là
  // nói cho người dùng biết có gì đó hỏng mà không nói được họ làm gì tiếp.
  const LY_DO_VAI_TRO_HE_THONG =
    'Vai trò do hệ thống tạo: tập quyền khoá. Tạo một vai trò riêng nếu cần tập quyền khác.';
  const LY_DO_CHUA_DOC_DUOC_TAP_QUYEN =
    'Chưa đọc được tập quyền hiện tại của vai trò này, nên màn không tích sẵn và không ghi đè. ' +
    'Sửa được tên, mô tả và trạng thái.';

  export interface VaiTroFormPageProps {
    id?: string;
  }

  export function VaiTroFormPage({ id }: VaiTroFormPageProps) {
    const danhMuc = useVaiTroKhaDung();
    const danhMucQuyen = useDanhMucQuyen();

    // Màn SỬA đọc bản ghi từ chính danh mục đã tải: không có `GET /roles/:id` để hỏi riêng.
    const muc = id === undefined ? undefined : danhMuc.data?.items.find((one) => one.id === id);

    const dangTai = danhMuc.isPending || danhMucQuyen.isPending;
    const loi = danhMuc.error ?? danhMucQuyen.error;

    return (
      <main className={styles.man}>
        <TieuDeTrang
          tieuDe={id === undefined ? 'Tạo vai trò' : 'Sửa vai trò'}
          quayLai={<Link to={DUONG_DANH_SACH}>Phân quyền</Link>}
        />

        {loi ? <LoiTaiTrang onThuLai={() => { void danhMuc.refetch(); void danhMucQuyen.refetch(); }} /> : null}

        {dangTai ? (
          <p role="status">Đang tải...</p>
        ) : id !== undefined && muc === undefined ? (
          <KhongTimThay id={id} />
        ) : (
          // `key` đổi theo bản ghi: điều hướng thẳng từ vai trò này sang vai trò khác phải
          // khởi tạo lại các ô nhập từ bản ghi mới, chứ không giữ thứ đang gõ dở của cái cũ.
          <FormVaiTro
            key={muc?.id ?? 'moi'}
            muc={muc}
            danhMucQuyen={danhMucQuyen.data?.items ?? []}
          />
        )}
      </main>
    );
  }
  ```

  Hai component phụ của file, cùng cấp module:

  ```tsx
  // Lỗi TẢI TRANG - khác hẳn lỗi LƯU. Cái này nói "chưa dựng được cái form", cái kia nói "form
  // đúng nhưng máy chủ từ chối". Vẽ chung một banner là bắt người dùng tự đoán mình đang ở ca
  // nào, và hai ca đó có hai hành động khác nhau: thử lại, hay sửa ô.
  function LoiTaiTrang({ onThuLai }: { onThuLai: () => void }) {
    return (
      <BangThongBao
        sac="loi"
        tieuDe="Chưa tải được dữ liệu của màn"
        hanhDong={
          <Nut co="nho" onClick={onThuLai}>
            Thử lại
          </Nut>
        }
      >
        Danh mục vai trò hoặc danh mục quyền chưa về. Không có chúng thì form không dựng đúng
        được, nên màn không đoán bừa một danh sách rỗng.
      </BangThongBao>
    );
  }

  // `id` lạ thì màn hình nói KHÔNG TÌM THẤY, không dựng một form trống: một form trống ở chế độ
  // sửa trông y hệt một vai trò vừa bị xoá sạch dữ liệu, và người dùng sẽ bấm Lưu để "chữa" nó.
  //
  // Câu chữ đổi so với bản cũ: không còn "dữ liệu mẫu", và nó nói ra CẢ HAI nguyên nhân có thể.
  // `GET /roles` lọc theo thẩm quyền (ADR-0032), nên vắng mặt khỏi danh mục không có nghĩa là
  // vai trò đã bị xoá - và frontend không phân biệt được hai ca ấy, nên nó không được đoán.
  function KhongTimThay({ id }: { id: string }) {
    return (
      <BangThongBao
        sac="loi"
        tieuDe="Không tìm thấy vai trò này"
        hanhDong={<Link to={DUONG_DANH_SACH}>Về danh sách vai trò</Link>}
      >
        Mã <MaBanGhi ma={id} /> không có trong danh mục vai trò bạn đọc được. Đường dẫn có thể
        gõ nhầm, hoặc vai trò đó nằm ngoài thẩm quyền của bạn.
      </BangThongBao>
    );
  }
  ```

- [ ] **Step 5: Viết `FormVaiTro` - state, thân request, và khối tích quyền.**

  ```tsx
  // Tham số tên `muc` chứ không `vaiTro`: luật eslint erp/c-ts-06-no-role-guess bắt mọi biến
  // tên `vai_tro` mà quyết định một nhánh JSX, vì đó là hình dạng của việc suy quyền từ role.
  // Ở đây không có quyền nào bị suy - đây là một MỤC của danh mục vai trò.
  function FormVaiTro({
    muc,
    danhMucQuyen,
  }: {
    muc?: VaiTroKhaDungDTO;
    danhMucQuyen: readonly QuyenDTO[];
  }) {
    const idGoc = useId();
    const idMa = `${idGoc}-ma`;
    const idGoiYMa = `${idGoc}-goi-y-ma`;
    const idMaSinh = `${idGoc}-ma-sinh`;
    const idTen = `${idGoc}-ten`;
    const idLoiTen = `${idGoc}-loi-ten`;
    const idPhanHe = `${idGoc}-phan-he`;
    const idLoiPhanHe = `${idGoc}-loi-phan-he`;
    const idMoTa = `${idGoc}-mo-ta`;
    const idGoiYMoTa = `${idGoc}-goi-y-mo-ta`;
    const idDangDung = `${idGoc}-dang-dung`;
    const idGoiYDangDung = `${idGoc}-goi-y-dang-dung`;
    const idKhoaQuyen = `${idGoc}-khoa-quyen`;

    const dangSua = muc !== undefined;
    const heThongTao = muc?.he_thong_tao === true;
    // Tập quyền hiện tại đọc được hay không - xem khối ghi chú của `quyen?` ở user-api.ts.
    const quyenGoc = muc?.quyen;
    const docDuocTapQuyen = !dangSua || quyenGoc !== undefined;

    const tao = useTaoVaiTro();
    const sua = useSuaVaiTro();
    const luu = dangSua ? sua : tao;

    const [ten, datTen] = useState(muc?.nhan ?? '');
    const [phanHe, datPhanHe] = useState('');
    const [moTa, datMoTa] = useState(muc?.mo_ta ?? '');
    const [dangDung, datDangDung] = useState(muc?.dang_dung ?? true);
    const [quyenDaChon, datQuyenDaChon] = useState<string[]>([...(quyenGoc ?? [])]);

    const [daRoiOTen, datDaRoiOTen] = useState(false);
    const [daRoiOPhanHe, datDaRoiOPhanHe] = useState(false);

    const tenRong = ten.trim() === '';
    // Phân hệ CHỈ bắt buộc ở màn tạo: nó là đầu vào để backend sinh mã, và mã bất biến sau khi
    // tạo nên đường PATCH không nhận trường `module` nào cả.
    const phanHeRong = !dangSua && phanHe === '';

    const ketQuaMa = dangSua
      ? ({ trangThai: 'chua-du-dau-vao' } as const)
      : sinhMaVaiTro(phanHe, ten);
    const tenKhongDatDuocMa = ketQuaMa.trangThai === 'ten-khong-dung-duoc';

    const hienLoiTen = tenRong && daRoiOTen;
    const hienLoiPhanHe = phanHeRong && daRoiOPhanHe;

    const moTaTen = hienLoiTen ? idLoiTen : ketQuaMa.trangThai === 'co-ma' ? idMaSinh : undefined;

    // Khối quyền khoá vì đâu, hoặc null khi nó mở. Thứ tự KHÔNG tuỳ tiện: vai trò hệ thống là
    // một luật của hệ, còn "chưa đọc được" là một lỗ hợp đồng tạm thời - nói luật trước.
    const khoaQuyen: string | null = heThongTao
      ? 'vai-tro-he-thong'
      : !docDuocTapQuyen
        ? 'chua-doc-duoc-tap-quyen'
        : null;
    const lyDoKhoaQuyen =
      khoaQuyen === 'vai-tro-he-thong'
        ? LY_DO_VAI_TRO_HE_THONG
        : khoaQuyen === 'chua-doc-duoc-tap-quyen'
          ? LY_DO_CHUA_DOC_DUOC_TAP_QUYEN
          : null;

    const mucQuyen: MucChon[] = danhMucQuyen.map((q) => ({
      id: q.ma,
      nhanChinh: q.nhan,
      nhanPhu: <MaBanGhi ma={q.ma} />,
      loc: `${q.nhan} ${q.ma} ${q.nhom}`,
      nhom: nhomHienThi(q),
      // Câu này là câu người dùng đọc, nên nó nói RA HẬU QUẢ chứ không nói tên cờ:
      // "cap_duoc: false" không giúp ai làm gì tiếp.
      khoaDong: q.cap_duoc
        ? undefined
        : 'Bạn không giữ mã quyền này nên không cấp cho ai được.',
    }));

    // Lỗi của một trường, tra theo `path` mà backend trả về. Mảng chứ không Record, nên tra
    // bằng find - và giữ đúng thứ tự backend trả, ô đầu tiên là ô đáng được đọc trước.
    function loiTruong(path: string): string | undefined {
      return luu.errors.fieldErrors.find((one) => one.path === path)?.message;
    }

    const conThieu = tenRong
      ? 'Tên vai trò chưa điền. '
      : tenKhongDatDuocMa
        ? 'Tên vai trò chưa đặt được mã. '
        : phanHeRong
          ? 'Chưa chọn phân hệ áp dụng. '
          : '';
    const khoaLuu = conThieu !== '';

    function guiForm(su: FormEvent<HTMLFormElement>): void {
      su.preventDefault();
      datDaRoiOTen(true);
      datDaRoiOPhanHe(true);
      if (khoaLuu) return;

      if (!dangSua) {
        tao.mutate({
          name: ten.trim(),
          description: moTa,
          module: phanHe,
          // Màn tạo luôn gửi `permissions`, kể cả mảng rỗng: một vai trò không quyền nào là
          // một lệnh hợp lệ, và POST không có khái niệm "không đụng tới trường này".
          permissions: quyenDaChon,
        });
        return;
      }

      // PATCH chỉ mang những trường THẬT SỰ đổi. Gửi một trường không đổi vẫn là một lần ghi
      // và một dòng audit cho việc không làm gì cả - và với vai trò hệ thống thì `permissions`
      // hay `dang_dung` gửi lên là chắc chắn ăn 422.
      const than: SuaVaiTroRequest = {};
      if (ten.trim() !== muc.nhan) than.name = ten.trim();
      if (moTa !== muc.mo_ta) than.description = moTa;
      if (!heThongTao && dangDung !== muc.dang_dung) than.dang_dung = dangDung;
      if (
        !heThongTao &&
        docDuocTapQuyen &&
        !cungTapQuyen(quyenDaChon, quyenGoc ?? [])
      ) {
        than.permissions = quyenDaChon;
      }
      sua.mutate({ id: muc.id, than });
    }
  ```

- [ ] **Step 6: Viết phần JSX của `FormVaiTro`.**

  Giữ nguyên bốn ô trên (Mã chỉ đọc, Tên, Phân hệ, Mô tả, Đang dùng) với ba chỗ đổi, rồi thêm
  khối quyền và chân trang:

  ```tsx
    return (
      <form className={styles.form} onSubmit={guiForm} noValidate>
        {/* Banner lỗi ở ĐẦU form, và câu của nó dựng theo MÃ lỗi chứ không theo message của
            backend - message viết không dấu. Mã tra cứu vào ô riêng của BangThongBao, không
            dính đuôi câu văn (R-17). */}
        {luu.errors.formMessage !== null || luu.errorCode !== null ? (
          <BangThongBao
            sac="loi"
            tieuDe="Chưa lưu được vai trò"
            maTraCuu={luu.maTraCuu ?? undefined}
            className={styles.bao}
          >
            {cauLoiVaiTro(luu.errorCode) ?? luu.thongDiep ?? luu.errors.formMessage}
          </BangThongBao>
        ) : null}

        {luu.saved !== undefined ? (
          <p role="status" data-da-luu>
            Đã lưu vai trò <MaBanGhi ma={luu.saved.ma} />.{' '}
            <Link to={DUONG_DANH_SACH}>Về danh sách vai trò</Link>
          </p>
        ) : null}

        <div className={`the ${styles.than}`}>
          {/* Ô Mã chỉ có ở màn SỬA, và nó CHỈ ĐỌC. `readOnly` chứ không `disabled`: ô readOnly
              vẫn dừng được bằng Tab và vẫn bôi đen copy được, còn ô disabled thì người dùng
              bàn phím không bao giờ tới được để đọc mã của chính bản ghi mình đang sửa. */}
          {muc === undefined ? null : (
            <div className={styles.truong}>
              <label htmlFor={idMa}>Mã</label>
              <input
                id={idMa}
                type="text"
                value={muc.ma}
                readOnly
                aria-describedby={idGoiYMa}
                onChange={() => undefined}
              />
              <p id={idGoiYMa} className={styles['goi-y']}>
                Mã không đổi được: nó đã nằm trong dữ liệu đã ghi. Cần mã khác thì tạo vai trò
                mới rồi tắt vai trò này.
              </p>
              {loiTruong('code') === undefined ? null : (
                <p className={styles.loi} role="alert" data-loi-truong="code">
                  {loiTruong('code')}
                </p>
              )}
            </div>
          )}

          <div className={styles.truong}>
            <label htmlFor={idTen}>
              Tên vai trò{' '}
              <span className={styles['bat-buoc']} aria-hidden="true">
                *
              </span>
            </label>
            <input
              id={idTen}
              type="text"
              value={ten}
              aria-required="true"
              aria-invalid={hienLoiTen || undefined}
              aria-describedby={moTaTen}
              onChange={(su: ChangeEvent<HTMLInputElement>) => datTen(su.target.value)}
              onBlur={() => datDaRoiOTen(true)}
            />
            {hienLoiTen ? (
              <p id={idLoiTen} className={styles.loi} role="alert">
                Tên vai trò không được để trống.
              </p>
            ) : null}

            {/* Mã hệ thống XEM TRƯỚC, ngay dưới ô Tên và cập nhật theo từng phím. Câu thứ hai
                là bắt buộc theo R-19: frontend không giữ quy tắc nghiệp vụ, nên nó phải nói ra
                rằng mã cuối do backend chốt - backend thêm hậu tố `_2` khi mã đã có người dùng,
                và một màn hình hứa chắc một mã là một màn hình nói dối một phần thời gian. */}
            {ketQuaMa.trangThai === 'co-ma' ? (
              <p id={idMaSinh} className={styles['goi-y']} data-ma-sinh>
                Mã xem trước: <MaBanGhi ma={ketQuaMa.ma} />. Mã cuối cùng do hệ thống chốt lúc
                lưu - mã này đã có người dùng thì hệ thống thêm hậu tố.
              </p>
            ) : null}

            {tenKhongDatDuocMa ? (
              <p className={styles.loi} role="alert" data-ten-khong-dung-duoc>
                Tên này chưa đặt được mã: bỏ dấu xong không còn chữ hay số nào. Dùng chữ và số
                trong tên vai trò.
              </p>
            ) : null}

            {loiTruong('name') === undefined ? null : (
              <p className={styles.loi} role="alert" data-loi-truong="name">
                {loiTruong('name')}
              </p>
            )}
          </div>

          {/* Ô Phân hệ CHỈ có ở màn TẠO: nó là đầu vào để backend sinh mã, mà mã bất biến sau
              khi tạo (ADR-0023 mục 5) nên đường PATCH không nhận trường `module` nào cả. Bày
              một ô sửa được mà không gửi đi đâu là mời người dùng đổi một thứ không đổi được.
              Danh sách phân hệ rút từ chính danh mục quyền, không từ một mảng hằng gõ tay -
              một hằng gõ tay là bản thứ hai của danh sách module và nó lệch vào đúng ngày
              backend thêm một phân hệ. */}
          {dangSua ? null : (
            <div className={styles.truong}>
              <label htmlFor={idPhanHe}>
                Phân hệ áp dụng{' '}
                <span className={styles['bat-buoc']} aria-hidden="true">
                  *
                </span>
              </label>
              <select
                id={idPhanHe}
                value={phanHe}
                aria-required="true"
                aria-invalid={hienLoiPhanHe || undefined}
                aria-describedby={hienLoiPhanHe ? idLoiPhanHe : undefined}
                onChange={(su: ChangeEvent<HTMLSelectElement>) => datPhanHe(su.target.value)}
                onBlur={() => datDaRoiOPhanHe(true)}
              >
                {/* Ô mời chọn mang value rỗng, không chọn sẵn phân hệ đầu danh sách: phân hệ
                    đi vào mã vai trò, nên nó phải là một lần chọn CỐ Ý. */}
                <option value="">Chọn phân hệ</option>
                {phanHeChonDuoc(danhMucQuyen).map((one) => (
                  <option key={one.ma} value={one.ma}>
                    {one.nhan}
                  </option>
                ))}
              </select>
              {hienLoiPhanHe ? (
                <p id={idLoiPhanHe} className={styles.loi} role="alert">
                  Chọn phân hệ mà vai trò này áp dụng.
                </p>
              ) : null}
              {loiTruong('module') === undefined ? null : (
                <p className={styles.loi} role="alert" data-loi-truong="module">
                  {loiTruong('module')}
                </p>
              )}
            </div>
          )}

          <div className={styles.truong}>
            <label htmlFor={idMoTa}>Mô tả</label>
            <textarea
              id={idMoTa}
              rows={3}
              value={moTa}
              aria-describedby={idGoiYMoTa}
              onChange={(su: ChangeEvent<HTMLTextAreaElement>) => datMoTa(su.target.value)}
            />
            <p id={idGoiYMoTa} className={styles['goi-y']}>
              Không bắt buộc. Một câu, hiện ngay dưới tên vai trò ở màn danh sách.
            </p>
            {loiTruong('description') === undefined ? null : (
              <p className={styles.loi} role="alert" data-loi-truong="description">
                {loiTruong('description')}
              </p>
            )}
          </div>

          {/* Ô đánh dấu đứng TRƯỚC nhãn và cùng một hàng - hình dạng người dùng đã quen từ
              trước khi có ứng dụng này. */}
          <div className={styles.truong}>
            <div className={styles['hang-danh-dau']}>
              <input
                id={idDangDung}
                type="checkbox"
                checked={dangDung}
                // Khoá MỀM cho vai trò hệ thống: ô vẫn dừng được bằng Tab để nghe lý do.
                aria-disabled={heThongTao || undefined}
                aria-describedby={heThongTao ? idKhoaQuyen : idGoiYDangDung}
                onChange={(su: ChangeEvent<HTMLInputElement>) => {
                  if (heThongTao) return;
                  datDangDung(su.target.checked);
                }}
              />
              <label htmlFor={idDangDung}>Đang dùng</label>
            </div>
            <p id={idGoiYDangDung} className={styles['goi-y']}>
              Vai trò đã tắt vẫn giữ nguyên người đang giữ nó, nhưng họ mất quyền và không ai
              được gán thêm.
            </p>
            {loiTruong('dang_dung') === undefined ? null : (
              <p className={styles.loi} role="alert" data-loi-truong="dang_dung">
                {loiTruong('dang_dung')}
              </p>
            )}
          </div>
        </div>

        {/* Khối quyền là một THẺ RIÊNG, không nhét vào thẻ trên: nó cao bằng cả form còn lại,
            và gộp chung làm ô Tên trôi lên mất khỏi tầm mắt ngay khi người dùng cuộn xuống
            tích quyền. */}
        <section
          className={`the ${styles['khoi-quyen']}`}
          data-khoi-quyen
          data-khoa={khoaQuyen ?? undefined}
          aria-labelledby={`${idGoc}-tieu-de-quyen`}
        >
          <h2 id={`${idGoc}-tieu-de-quyen`}>Quyền của vai trò</h2>

          {lyDoKhoaQuyen === null ? null : (
            <p id={idKhoaQuyen} className={styles['goi-y']} data-ly-do-khoa-quyen>
              {lyDoKhoaQuyen}
            </p>
          )}

          <DanhSachChon
            muc={mucQuyen}
            daChon={quyenDaChon}
            onDoiChon={datQuyenDaChon}
            nhanLoc="Lọc quyền theo tên hoặc mã"
            danhTu="quyền"
            chonCaNhom
            khoa={khoaQuyen !== null}
          />

          {loiTruong('permissions') === undefined ? null : (
            <p className={styles.loi} role="alert" data-loi-truong="permissions">
              {loiTruong('permissions')}
            </p>
          )}

          {/* KHÔNG phải câu "sau tối đa 30 giây": đường ghi vai trò vứt bản chụp phân quyền
              ngay sau commit (ADR-0038 mục Consequences), nên hiệu lực là NGAY. Câu 30 giây
              chỉ còn đúng cho đường gán vai trò cho người dùng và đường gán phạm vi. */}
          <p className={styles['goi-y']} data-hieu-luc>
            Thay đổi có hiệu lực ngay sau khi lưu, với cả những người đang giữ vai trò này.
          </p>
        </section>

        <div className={styles.chan}>
          <Link to={DUONG_DANH_SACH} className={styles.huy}>
            Huỷ
          </Link>
          <Nut
            bien="chinh"
            type="submit"
            disabled={khoaLuu}
            dangChay={luu.isPending}
            lyDoKhoa={khoaLuu ? `${conThieu}Điền đủ rồi mới lưu được.` : undefined}
          >
            {luu.isPending ? 'Đang lưu...' : 'Lưu vai trò'}
          </Nut>
        </div>
      </form>
    );
  }
  ```

- [ ] **Step 7: Thêm lớp CSS vào `VaiTroFormPage.module.css`.**

  ```css
  /* Khối quyền là một thẻ riêng đứng dưới thẻ thông tin, không phải một mục bên trong nó:
   * nó cao bằng cả form còn lại, và gộp chung làm ô Tên trôi khỏi tầm mắt ngay khi người
   * dùng cuộn xuống tích quyền. */
  .khoi-quyen {
    display: flex;
    flex-direction: column;
    gap: var(--gian-3);
    margin-top: var(--gian-4);
  }

  .khoi-quyen h2 {
    margin: 0;
    font-size: var(--chu-lg);
    font-weight: var(--dam-manh);
    color: var(--mau-chu);
  }
  ```

- [ ] **Step 8: Chạy test, lint, arch; THẤY XANH.**

  ```
  npx vitest run src/modules/user/pages/VaiTroFormPage.test.tsx
  npm test
  npm run lint
  npm run arch
  ```

  Nếu `npm run lint` báo `erp/c-ts-06-no-role-guess`, chỗ sai gần như chắc chắn là một biến vừa
  đặt tên `vaiTro`. Đổi về `muc`, đừng tắt luật.

- [ ] **Step 9: Commit.**

  ```
  feat(user): VaiTroFormPage nối API thật và có khối tích quyền

  Gỡ LY_DO_CHUA_CO_DUONG_GHI và khối ghi chú "không có ma trận quyền" -
  ADR-0038 đã đảo mệnh đề đó. Khối quyền dựng trên DanhSachChon với ô cha
  ba trạng thái và dòng khoá theo cap_duoc.

  Ba điều đáng đọc kỹ:
  - PATCH chỉ mang trường THẬT SỰ đổi; vai trò hệ thống không bao giờ mang
    permissions lẫn dang_dung.
  - GET /roles chưa trả `quyen`, nên màn sửa khoá khối quyền kèm lý do và
    không ghi đè - thay vì tích sẵn một tập rỗng rồi xoá sạch quyền.
  - KHÔNG có câu "30 giây": đường ghi vai trò vứt bản chụp ngay sau commit.
  ```

---

## Task 6: `VaiTroListPage` nối API thật và nút Tắt/Bật

**Files:**
- `src/modules/user/pages/VaiTroListPage.test.tsx` (viết lại)
- `src/modules/user/pages/VaiTroListPage.tsx`
- `src/modules/user/pages/VaiTroListPage.module.css`

- [ ] **Step 1: Viết lại `VaiTroListPage.test.tsx`.**

  Chép sang bộ khung của Task 5: `makeResponse`, `KichBan`, `datFetch`, `soLanGhi`,
  `thanGhiCuoi`, hai hằng `VAI_TRO_THUONG` / `VAI_TRO_HE_THONG`, và khối
  `beforeEach` / `afterEach`. Hai file test không chia sẻ helper - repo không có thư mục
  test-utils, và dựng một cái cho đúng hai chỗ là một đợt riêng. `render()` ở file này không
  nhận tham số, phần còn lại giữ nguyên.

  ```tsx
  async function render(): Promise<void> {
    const qc = new QueryClient({
      defaultOptions: { queries: { retry: false }, mutations: { retry: false } },
    });
    await act(async () => {
      root.render(
        <QueryClientProvider client={qc}>
          <VaiTroListPage />
        </QueryClientProvider>,
      );
    });
    await act(async () => {
      await Promise.resolve();
    });
  }
  ```

  ```tsx
  function hangTheoMa(ma: string): HTMLElement {
    const hang = container.querySelector(`[data-vai-tro="${ma}"]`);
    if (hang === null) throw new Error(`không tìm thấy hàng của vai trò ${ma}`);
    return hang as HTMLElement;
  }

  function nutTrongHang(ma: string, chu: string): HTMLButtonElement {
    const nut = [...hangTheoMa(ma).querySelectorAll('button')].find(
      (b) => (b.textContent ?? '').trim() === chu,
    );
    if (nut === undefined) throw new Error(`hàng ${ma} không có nút "${chu}"`);
    return nut as HTMLButtonElement;
  }

  describe('VaiTroListPage', () => {
    it('một dòng cho mỗi vai trò backend trả về, hàng tiêu đề vẫn còn', async () => {
      datFetch();
      await render();

      expect(container.querySelectorAll('tbody tr')).toHaveLength(2);
      expect(container.querySelectorAll('thead tr')).toHaveLength(1);
    });

    it('KHÔNG còn dải cảnh báo dữ liệu mẫu và KHÔNG còn chip Xem trước', async () => {
      // Hai thứ này là lời khai "màn chưa thật". Để lại một trong hai sau khi nối API là nói
      // dối theo chiều ngược lại. Kiểm bằng class chứ không bằng chữ.
      datFetch();
      await render();

      // Dải cảnh báo là một <BangThongBao sac="canh-bao">, và component đó đặt lớp `canh-bao`
      // lên thẻ gốc. Chip là <NhanXemTruoc> với lớp `xem-truoc`. Tìm bằng `[class*="..."]` chứ
      // không `.canh-bao`: CSS Modules băm tên lớp lúc dựng, nên bộ chọn lớp thẳng không khớp
      // gì cả - và nó không khớp một cách IM LẶNG.
      expect(container.querySelector('[class*="canh-bao"]')).toBeNull();
      expect(container.querySelector('[class*="xem-truoc"]')).toBeNull();
    });

    it('vai trò hệ thống: nút Tắt khoá MỀM kèm lý do đọc được', async () => {
      datFetch();
      await render();

      const nut = nutTrongHang('auth.admin', 'Tắt');
      expect(nut.getAttribute('aria-disabled')).toBe('true');
      expect(nut.disabled).toBe(false);

      const idLyDo = nut.getAttribute('aria-describedby') as string;
      expect(container.querySelector(`#${CSS.escape(idLyDo)}`)?.textContent).toContain(
        'Vai trò hệ thống',
      );
    });

    it('tắt một vai trò đi qua xác nhận HAI BƯỚC tại chỗ, không window.confirm', async () => {
      // window.confirm chặn cả luồng và không test được. Bước một chỉ đổi giao diện: KHÔNG
      // một lời gọi ghi nào được bắn ra trước khi người dùng bấm nút thứ hai.
      const confirmGia = vi.fn();
      vi.stubGlobal('confirm', confirmGia);
      datFetch();
      await render();

      act(() => {
        nutTrongHang('inventory.thu_kho', 'Tắt').click();
      });
      expect(confirmGia).not.toHaveBeenCalled();
      expect(soLanGhi).toBe(0);
      expect(hangTheoMa('inventory.thu_kho').querySelector('[data-hoi-tat]')).not.toBeNull();

      await act(async () => {
        nutTrongHang('inventory.thu_kho', 'Tắt thật').click();
      });
      expect(soLanGhi).toBe(1);
      expect(thanGhiCuoi).toEqual({ dang_dung: false });
    });

    it('câu hỏi xác nhận nói ĐÚNG số người đang giữ', async () => {
      // Con số là thứ duy nhất biến câu hỏi này từ một thủ tục thành một quyết định. Đọc
      // trong khối data-hoi-tat, không đọc textContent cả hàng.
      datFetch();
      await render();

      act(() => {
        nutTrongHang('inventory.thu_kho', 'Tắt').click();
      });

      const hoi = hangTheoMa('inventory.thu_kho').querySelector('[data-hoi-tat]');
      expect(hoi?.textContent).toContain('12');
    });

    it('bấm Thôi đóng khối xác nhận, không gửi gì', async () => {
      datFetch();
      await render();

      act(() => {
        nutTrongHang('inventory.thu_kho', 'Tắt').click();
      });
      act(() => {
        nutTrongHang('inventory.thu_kho', 'Thôi').click();
      });

      expect(hangTheoMa('inventory.thu_kho').querySelector('[data-hoi-tat]')).toBeNull();
      expect(soLanGhi).toBe(0);
    });

    it('vai trò đã tắt hiện nút Bật, và bật thì KHÔNG hỏi lại', async () => {
      // Bật lại một vai trò không mất gì của ai, nên bắt xác nhận là bắt thêm một cú bấm cho
      // một thao tác không có hậu quả.
      datFetch({ vaiTro: [{ ...VAI_TRO_THUONG, dang_dung: false }] });
      await render();

      await act(async () => {
        nutTrongHang('inventory.thu_kho', 'Bật').click();
      });

      expect(soLanGhi).toBe(1);
      expect(thanGhiCuoi).toEqual({ dang_dung: true });
    });

    it('lỗi từ đường ghi hiện thành một bảng thông báo có mã tra cứu', async () => {
      datFetch({
        ghi: () =>
          makeResponse(
            422,
            {
              error: {
                code: 'ERR_AUTH_ROLE_SYSTEM_LOCKED',
                message: 'vai tro he thong khoa',
                fields: [{ field: 'dang_dung', message: 'vai tro he thong khoa' }],
              },
            },
            'rq-loi',
          ),
      });
      await render();

      act(() => {
        nutTrongHang('inventory.thu_kho', 'Tắt').click();
      });
      await act(async () => {
        nutTrongHang('inventory.thu_kho', 'Tắt thật').click();
      });

      // `BangThongBao` không nhận prop `data-*` nào, nên dấu nhận biết nằm trên thẻ BỌC nó.
      // `role="alert"` là thứ component tự đặt cho sắc `loi` - kiểm nó là kiểm rằng lời báo
      // tới được trình đọc màn hình, chứ không chỉ tới được con mắt.
      const bao = container.querySelector('[data-loi-bat-tat]');
      expect(bao).not.toBeNull();
      expect(bao?.querySelector('[role="alert"]')).not.toBeNull();
      expect(bao?.textContent).toContain('vai trò do hệ thống tạo');
    });
  });
  ```

- [ ] **Step 2: Chạy `npx vitest run src/modules/user/pages/VaiTroListPage.test.tsx` và THẤY ĐỎ.**

- [ ] **Step 3: Viết lại `VaiTroListPage.tsx`.**

  Gỡ khối ghi chú "màn này là VỎ", gỡ `BangThongBao` cảnh báo dữ liệu mẫu, gỡ import
  `VAI_TRO_MAU`, gỡ `NhanXemTruoc`. Hàm `LienKetTaoVaiTro` ở cuối file **giữ nguyên không sửa
  một ký tự** - nó là một `<Link>` tới màn tạo và không dính gì tới dữ liệu mẫu.

  ```tsx
  // Mặt "Vai trò" của màn Phân quyền, đường dẫn `/quan-tri/phan-quyen`.
  //
  // Hai mặt của cùng một đối tượng - xem `app/mat-phan-quyen.ts`. Mặt này là danh mục vai
  // trò; mặt kia là ai đang giữ vai trò nào.
  //
  // # Một lời gọi, không phân trang
  //
  // `GET /roles` có `meta`, nhưng màn này đọc CẢ danh mục trong một lời gọi với `page_size`
  // lấy trần của backend - đúng lối `listVaiTroKhaDung` đã dùng cho màn gán, và hai màn vì
  // vậy dùng chung một khoá cache. Danh mục vượt trần thì `meta.total` nói ra và màn cảnh
  // báo, chứ không cắt im lặng. Dựng một `PhanTrang` cho một bảng dưới trăm dòng là thêm ba
  // tham số vào URL để phục vụ một trang thứ hai gần như không bao giờ tồn tại.
  //
  // # Nút Tắt không kiểm quyền gì cả
  //
  // Backend chưa trả `allowed_actions` cho vai trò, nên theo C-TS-06 nút HIỆN và cú 403 được
  // xử lý tử tế tại chỗ. Đoán quyền từ role ở đây là đúng thứ `erp/c-ts-06-no-role-guess`
  // cấm. Cái khoá duy nhất là `he_thong_tao` - và đó là một trường của chính BẢN GHI, không
  // phải một suy diễn về người đang xem.
  import { useState } from 'react';

  import { MAT_PHAN_QUYEN } from '@/app/mat-phan-quyen';
  import { Link } from '@/app/router/Link';
  import { Bang } from '@/shared/components/Bang/Bang';
  import { BangThongBao } from '@/shared/components/BangThongBao/BangThongBao';
  import { DaiTab } from '@/shared/components/DaiTab/DaiTab';
  import { MaBanGhi } from '@/shared/components/MaBanGhi/MaBanGhi';
  import { NhanTrangThai } from '@/shared/components/NhanTrangThai/NhanTrangThai';
  import { Nut } from '@/shared/components/Nut/Nut';
  import { TieuDeTrang } from '@/shared/components/TieuDeTrang/TieuDeTrang';

  import type { VaiTroKhaDungDTO } from '../api/user-api';
  import { cauLoiVaiTro } from '../components/loi-vai-tro';
  import { useSuaVaiTro } from '../hooks/use-sua-vai-tro';
  import { useVaiTroKhaDung } from '../hooks/use-vai-tro-kha-dung';

  import styles from './VaiTroListPage.module.css';

  const SO = new Intl.NumberFormat('vi-VN');
  const DUONG_PHAN_QUYEN = '/quan-tri/phan-quyen';

  const LY_DO_VAI_TRO_HE_THONG =
    'Vai trò hệ thống, không tắt được. Tạo một vai trò riêng nếu cần tập quyền khác.';

  export function VaiTroListPage() {
    const danhSach = useVaiTroKhaDung();
    const batTat = useSuaVaiTro();

    // useState duy nhất của file này giữ đúng một thứ của GIAO DIỆN: hàng nào đang chờ xác
    // nhận tắt. Cùng lối WarehouseListPage.
    const [choXacNhan, datChoXacNhan] = useState<string | null>(null);

    function tat(id: string): void {
      batTat.mutate(
        { id, than: { dang_dung: false } },
        { onSuccess: () => datChoXacNhan(null) },
      );
    }

    function bat(id: string): void {
      // Bật lại không mất gì của ai, nên không hỏi lại: một cú bấm xác nhận cho một thao tác
      // không có hậu quả chỉ dạy người dùng bấm qua mọi câu hỏi xác nhận.
      batTat.mutate({ id, than: { dang_dung: true } });
    }

    return (
      <main>
        <TieuDeTrang
          tieuDe="Phân quyền"
          moTa="Vai trò và người giữ vai trò."
          hanhDong={<LienKetTaoVaiTro />}
        />

        <DaiTab nhan="Mặt của phân quyền" className={styles.tab}>
          {MAT_PHAN_QUYEN.map((mat) => {
            const dangMo = mat.duong === DUONG_PHAN_QUYEN;
            return (
              <Link key={mat.duong} to={mat.duong} aria-current={dangMo ? 'page' : undefined}>
                {mat.nhan}
              </Link>
            );
          })}
        </DaiTab>

        {/* Thẻ BỌC mang dấu nhận biết, không phải BangThongBao: component đó khai đúng bảy
            prop và không nhận `data-*` nào. Bọc ngoài rẻ hơn nới hợp đồng của một component
            dùng chung cho một bài test. */}
        {batTat.errors.formMessage !== null || batTat.errorCode !== null ? (
          <div data-loi-bat-tat>
            <BangThongBao
              sac="loi"
              tieuDe="Chưa đổi được trạng thái vai trò"
              maTraCuu={batTat.maTraCuu ?? undefined}
            >
              {cauLoiVaiTro(batTat.errorCode) ?? batTat.thongDiep ?? batTat.errors.formMessage}
            </BangThongBao>
          </div>
        ) : null}

        <section className="the">
          {/* Bốn trạng thái của khuôn danh sách đi qua chính prop của <Bang>: `dangTai` vẽ
              khung xương, `loi` và `rong` thay CẢ cái bảng, `dangLamMoi` giữ dữ liệu cũ và
              chỉ báo nhẹ. Dựng lại bốn nhánh ấy ở đây là dựng một bản thứ hai của thứ
              component đã có, và bản thứ hai luôn thiếu một nhánh. */}
          <Bang
            className={styles.bang}
            soCot={6}
            dangTai={danhSach.isPending}
            dangLamMoi={danhSach.isFetching && !danhSach.isPending}
            loi={
              danhSach.error ? (
                <BangThongBao
                  sac="loi"
                  tieuDe="Chưa tải được danh mục vai trò"
                  hanhDong={
                    <Nut co="nho" onClick={() => void danhSach.refetch()}>
                      Thử lại
                    </Nut>
                  }
                >
                  Danh mục vai trò chưa về. Bảng dưới đây vì vậy để trống chứ không đoán bừa.
                </BangThongBao>
              ) : undefined
            }
            rong={
              // Trạng thái rỗng BẮT BUỘC mang đúng một đường ra: một màn rỗng không lối ra là
              // một ngõ cụt. Ở đây đường ra là chính màn tạo vai trò.
              danhSach.data?.items.length === 0 ? (
                <BangThongBao
                  sac="tin"
                  tieuDe="Chưa có vai trò nào bạn đọc được"
                  hanhDong={<Link to={`${DUONG_PHAN_QUYEN}/moi`}>Tạo vai trò đầu tiên</Link>}
                >
                  Danh mục này lọc theo thẩm quyền của bạn, nên nó rỗng khi bạn chưa gán được
                  vai trò nào - không nhất thiết vì hệ thống chưa có vai trò nào.
                </BangThongBao>
              ) : undefined
            }
            dauBang={
              <>
                <th scope="col">Mã</th>
                <th scope="col">Tên vai trò</th>
                <th scope="col">Phân hệ</th>
                <th scope="col" className="so">
                  Đang giữ
                </th>
                <th scope="col">Trạng thái</th>
                <th scope="col" className={styles['dau-thao-tac']}>
                  Thao tác
                </th>
              </>
            }
          >
            {danhSach.data?.items.map((muc) => (
              <HangVaiTro
                key={muc.id}
                muc={muc}
                dangHoiTat={choXacNhan === muc.id}
                dangGui={batTat.dangSuaId === muc.id}
                onHoiTat={datChoXacNhan}
                onTat={tat}
                onBat={bat}
              />
            ))}
          </Bang>
        </section>
      </main>
    );
  }
  ```

  Danh mục vượt trần `page_size` thì nói ra chứ không cắt im lặng - đặt ngay dưới `</Bang>`,
  trong cùng `<section className="the">`:

  ```tsx
          {danhSach.data !== undefined &&
          danhSach.data.meta.total > danhSach.data.items.length ? (
            <p className={styles['doc-them']} data-danh-muc-thieu>
              Hệ thống có {SO.format(danhSach.data.meta.total)} vai trò, màn này chỉ đọc được{' '}
              {SO.format(danhSach.data.items.length)} đầu tiên.
            </p>
          ) : null}
  ```

  Thêm lớp `.doc-them` vào `VaiTroListPage.module.css` nếu file chưa có nó - chép nguyên khối
  cùng tên từ `UserDetailPage.module.css`, đừng đặt giá trị mới.

- [ ] **Step 4: Viết `HangVaiTro` với xác nhận hai bước trong ô Thao tác.**

  ```tsx
  // Tham số tên `muc` chứ không `vaiTro`: luật eslint erp/c-ts-06-no-role-guess bắt mọi biến
  // tên `vai_tro` mà quyết định một nhánh JSX. Ở đây không có quyền nào bị suy - đây là một
  // MỤC của danh mục vai trò.
  function HangVaiTro({
    muc,
    dangHoiTat,
    dangGui,
    onHoiTat,
    onTat,
    onBat,
  }: {
    muc: VaiTroKhaDungDTO;
    dangHoiTat: boolean;
    dangGui: boolean;
    onHoiTat: (id: string | null) => void;
    onTat: (id: string) => void;
    onBat: (id: string) => void;
  }) {
    return (
      <tr data-vai-tro={muc.ma}>
        <td>
          <MaBanGhi ma={muc.ma} />
        </td>

        <td className={styles['o-ten']}>
          <span className={styles.ten}>{muc.nhan}</span>
          <span className={styles['mo-ta']}>{muc.mo_ta}</span>
        </td>

        {/* Nhiều phân hệ thì nhiều chip: module suy từ `role_permissions` (ADR-0024), nên một
            vai trò chạm hai module là chuyện bình thường chứ không phải dữ liệu hỏng.
            `nhan_phan_he` song song TỪNG PHẦN TỬ với `phan_he`, nên khoá lấy từ `phan_he` và
            chữ lấy từ `nhan_phan_he` cùng chỉ số. */}
        <td>
          {muc.phan_he.map((maPhanHe, i) => (
            <span key={maPhanHe} className={styles['chip-phan-he']}>
              {muc.nhan_phan_he[i] ?? maPhanHe}
            </span>
          ))}
        </td>

        <td className={`so ${styles['o-giu']}`}>
          {muc.so_nguoi_giu === 0 ? (
            <span className={styles['chua-giu']}>Chưa ai giữ</span>
          ) : (
            `${SO.format(muc.so_nguoi_giu)} người`
          )}
        </td>

        <td>
          <NhanTrangThai sac={muc.dang_dung ? 'tot' : 'tat'}>
            {muc.dang_dung ? 'Đang dùng' : 'Đã tắt'}
          </NhanTrangThai>
        </td>

        <td className={styles['o-thao-tac']}>
          {dangHoiTat ? (
            <>
              {/* Xác nhận hai bước TẠI CHỖ thay vì window.confirm: một hộp thoại của trình
                  duyệt chặn cả luồng và không test được. Câu hỏi nói ĐÚNG con số - đó là thứ
                  duy nhất biến nó từ một thủ tục thành một quyết định.
                  KHÔNG có chữ "trong vòng 30 giây": đường ghi vai trò vứt bản chụp phân quyền
                  ngay sau commit (ADR-0038), nên người đang giữ mất quyền NGAY. */}
              <span className={styles['cau-hoi']} data-hoi-tat>
                Tắt vai trò {muc.ma}?{' '}
                {muc.so_nguoi_giu === 0
                  ? 'Chưa ai giữ vai trò này.'
                  : `${SO.format(muc.so_nguoi_giu)} người đang giữ sẽ mất quyền ngay.`}
              </span>
              <Nut bien="canh-bao" co="nho" dangChay={dangGui} onClick={() => onTat(muc.id)}>
                {dangGui ? 'Đang tắt...' : 'Tắt thật'}
              </Nut>
              <Nut
                co="nho"
                disabled={dangGui}
                lyDoKhoa={dangGui ? 'Đang gửi lệnh tắt, chờ nó xong đã.' : undefined}
                onClick={() => onHoiTat(null)}
              >
                Thôi
              </Nut>
            </>
          ) : (
            <>
              <Link
                to={`${DUONG_PHAN_QUYEN}/${encodeURIComponent(muc.id)}`}
                className={styles['nut-hang']}
              >
                Sửa
              </Link>
              {muc.dang_dung ? (
                <Nut
                  co="nho"
                  disabled={muc.he_thong_tao}
                  lyDoKhoa={muc.he_thong_tao ? LY_DO_VAI_TRO_HE_THONG : undefined}
                  onClick={() => onHoiTat(muc.id)}
                >
                  Tắt
                </Nut>
              ) : (
                <Nut
                  co="nho"
                  dangChay={dangGui}
                  disabled={muc.he_thong_tao}
                  lyDoKhoa={muc.he_thong_tao ? LY_DO_VAI_TRO_HE_THONG : undefined}
                  onClick={() => onBat(muc.id)}
                >
                  {dangGui ? 'Đang bật...' : 'Bật'}
                </Nut>
              )}
            </>
          )}
        </td>
      </tr>
    );
  }
  ```

- [ ] **Step 5: Thêm lớp `.cau-hoi` vào `VaiTroListPage.module.css`.**

  ```css
  /* Câu hỏi xác nhận nằm CÙNG HÀNG với hai nút, bên trái chúng: đọc từ trái sang là "hỏi -
   * đồng ý - thôi", đúng thứ tự người ta ra quyết định. Không xuống dòng, vì một ô thao tác
   * cao gấp đôi các hàng khác làm cả bảng nhảy khi người dùng bấm Tắt. */
  .cau-hoi {
    font-size: var(--chu-xs);
    color: var(--mau-chu-mo);
    white-space: nowrap;
  }
  ```

  Xoá lớp `.bao` khỏi file này nếu không còn ai dùng - nó là lớp của dải cảnh báo dữ liệu mẫu.

- [ ] **Step 6: Chạy test, lint, arch; THẤY XANH.**

  ```
  npx vitest run src/modules/user/pages/VaiTroListPage.test.tsx
  npm test
  npm run lint
  npm run arch
  ```

- [ ] **Step 7: Commit.**

  ```
  feat(user): VaiTroListPage nối API thật, thêm nút Tắt/Bật

  Xác nhận hai bước TẠI CHỖ trong ô Thao tác, đúng lối WarehouseListPage -
  không window.confirm, không modal. Câu hỏi nói đúng số người đang giữ.

  Vai trò he_thong_tao khoá mềm nút Tắt kèm lý do: khoá cứng thì lý do không
  bao giờ tới được người dùng bàn phím.

  Xoá dải cảnh báo "dữ liệu mẫu": nó là lời khai màn chưa thật, và để lại sau
  khi nối API là nói dối theo chiều ngược lại.
  ```

---

## Task 7: Gỡ `VAI_TRO_MAU` và chip "Xem trước"

Sau Task 5 và Task 6 thì không file nào còn import `vai-tro-mau.ts`. Task này dọn nó đi và gỡ
lời khai "màn chưa thật" cuối cùng.

**Files:**
- `src/modules/user/components/vai-tro-mau.ts` (xoá)
- `src/app/mat-phan-quyen.ts`

- [ ] **Step 1: Kiểm chứng không còn ai import, rồi xoá file.**

  ```
  npx tsc --noEmit
  ```

  Trước khi xoá, chạy `grep -rn "vai-tro-mau\|VAI_TRO_MAU\|PHAN_HE_CHON_DUOC" src/` và xác nhận
  kết quả rỗng ngoài chính file sắp xoá. Còn một chỗ nào là Task 5 hoặc Task 6 chưa xong.

  ```
  rm src/modules/user/components/vai-tro-mau.ts
  ```

- [ ] **Step 2: Gỡ `xemTruoc: true` ở `src/app/mat-phan-quyen.ts`.**

  ```ts
  export const MAT_PHAN_QUYEN: readonly MatManHinh[] = [
    { duong: '/quan-tri/phan-quyen', nhan: 'Vai trò' },
    { duong: '/quan-tri/phan-quyen/gan', nhan: 'Gán vai trò' },
  ];
  ```

  **Giữ nguyên** trường `xemTruoc` trong interface `MatManHinh`: `mat-phan-vung.ts` vẫn dùng
  nó cho mặt "Quản trị". Gỡ trường khỏi interface là làm đỏ một màn không liên quan.

- [ ] **Step 3: Chạy cả bộ và sửa mọi bài test còn khoá vào chip.**

  ```
  npm test
  ```

  Bài test nào còn khẳng định mặt "Vai trò" có chip "Xem trước" thì sửa thành khẳng định
  NGƯỢC LẠI - chip đã đi rồi, và một bài test bị xoá là một mệnh đề không ai canh nữa.

- [ ] **Step 4: Chạy lint và arch.**

  ```
  npm run lint
  npm run arch
  ```

  `npm run arch` đỏ vì một file bị xoá - `npm run arch:update`, rồi `npm run arch` lại.

- [ ] **Step 5: Commit.**

  ```
  refactor(user): gỡ VAI_TRO_MAU và chip "Xem trước" của mặt Vai trò

  Cả hai màn vai trò nay chạy trên API thật, nên năm dòng bịa và một cái chip
  nói "chưa nối máy chủ" đều đã sai. Trường `xemTruoc` ở lại trong interface
  MatManHinh: mat-phan-vung.ts vẫn dùng nó.
  ```

---

## Task 8: `UserDetailPage` lọc vai trò đã tắt

`GET /roles` là MỘT endpoint phục vụ cả màn quản trị lẫn màn gán, và nó trả cả vai trò đã tắt
(ADR-0038, mục Consequences). Màn gán không được cho chọn chúng.

Đây là lọc theo **dữ liệu backend trả về**, không phải suy diễn quyền - và phép lọc đã nằm ở
`vaiTroDangDung` trong `user-api.ts` từ Task 3, nên màn hình không viết `.dang_dung` cạnh một
nhánh JSX và `erp/c-ts-06-no-role-guess` không có gì để báo oan.

**Files:**
- `src/modules/user/pages/UserDetailPage.test.tsx`
- `src/modules/user/pages/UserDetailPage.tsx`

- [ ] **Step 1: Viết test đỏ.**

  `DANH_MUC` của file hiện chỉ có `{ma, nhan}` - đúng hợp đồng cũ. Nay `GET /roles` trả chín
  trường, và bài test phải chạy trên hình dạng thật. Thêm một khuôn dựng và một hàm render nhận
  danh mục, đặt cạnh `DANH_MUC` đã có; **giữ nguyên `DANH_MUC`** vì các bài cũ đang dùng nó.

  ```tsx
  // Khuôn một dòng `GET /roles` sau đợt 2b. Mặc định `dang_dung: true` để mỗi bài chỉ phải nói
  // ra đúng thứ nó quan tâm.
  const vaiTroMau = {
    ma: 'inventory.thu_kho',
    nhan: 'Thủ kho',
    id: 'vt-1',
    mo_ta: '',
    dang_dung: true,
    he_thong_tao: false,
    phan_he: ['inventory'],
    nhan_phan_he: ['Kho vận'],
    so_nguoi_giu: 0,
  };

  /** Dựng màn với một danh mục vai trò cho trước. `meta.total` khớp độ dài, để bài về cảnh
   *  báo "vượt trần" chỉ hỏng khi phép so thật sự sai chứ không vì một con số dựng lệch. */
  async function renderVoiDanhMuc(danhMuc: unknown[]): Promise<void> {
    datFetchVoiVaiTro(danhMuc);
    await renderMan();
  }
  ```

  `datFetchVoiVaiTro` là bản mở rộng của `fetch` giả đã có trong file: khi đường gọi kết thúc
  bằng `/roles` thì trả `{ data: danhMuc, meta: { total: danhMuc.length, page: 1, page_size:
  100 } }`, mọi đường khác giữ nguyên hành vi cũ. `renderMan` là hàm dựng màn đã có trong file,
  đổi tên nếu cần để không đụng `render` của bài khác.

  ```tsx
  it('vai trò đã tắt KHÔNG xuất hiện trong danh sách chọn', async () => {
    // GET /roles trả cả vai trò đã tắt vì nó phục vụ cả màn quản trị lẫn màn này. Gán một vai
    // trò đã tắt thì backend từ chối bằng câu "vai trò không tồn tại" - một câu không ai chẩn
    // đoán ra được, nên màn này không bày ra lựa chọn ấy ngay từ đầu.
    await renderVoiDanhMuc([
      { ...vaiTroMau, ma: 'inventory.thu_kho', dang_dung: true },
      { ...vaiTroMau, ma: 'inventory.da_tat', dang_dung: false },
    ]);

    expect(container.querySelector('[data-muc="inventory.thu_kho"]')).not.toBeNull();
    expect(container.querySelector('[data-muc="inventory.da_tat"]')).toBeNull();
  });

  it('cảnh báo "danh mục vượt trần" đọc số ĐÃ TẢI, không đọc số sau khi lọc', async () => {
    // Nếu so `meta.total` với độ dài danh sách ĐÃ LỌC thì mọi vai trò bị tắt đều biến thành
    // một lời cảnh báo rằng màn hình đang đọc thiếu - một lời báo động sai, mỗi lần mở màn.
    await renderVoiDanhMuc([
      { ...vaiTroMau, ma: 'inventory.thu_kho', dang_dung: true },
      { ...vaiTroMau, ma: 'inventory.da_tat', dang_dung: false },
    ]);

    expect(container.querySelector('[data-danh-muc-thieu]')).toBeNull();
  });
  ```

- [ ] **Step 2: Chạy `npx vitest run src/modules/user/pages/UserDetailPage.test.tsx` và THẤY ĐỎ.**

- [ ] **Step 3: Lọc ở chỗ gọi, và tách con số đã tải khỏi con số đã lọc.**

  Trong `UserDetailPage.tsx`, chỗ dựng `<KhoiVaiTro>`:

  ```tsx
          <KhoiVaiTro
            userId={id}
            nguoi={nguoi.data}
            // Lọc vai trò đã tắt: gán một vai trò đã tắt bị backend từ chối bằng câu "vai trò
            // không tồn tại" (ADR-0038), một câu không ai chẩn đoán ra được. Phép lọc sống ở
            // user-api.ts nên màn hình không viết `.dang_dung` cạnh một nhánh JSX.
            danhMuc={vaiTroDangDung(danhMuc.data.items)}
            danhMucTong={danhMuc.data.meta.total}
            // Số dòng THỰC SỰ TẢI VỀ, trước khi lọc. Cảnh báo "danh mục vượt trần" phải so
            // trần với con số này: so với danh sách đã lọc thì mọi vai trò bị tắt đều biến
            // thành một lời báo động sai.
            soDaTai={danhMuc.data.items.length}
          />
  ```

  Trong `KhoiVaiTro`, thêm prop `soDaTai: number` và đổi điều kiện cảnh báo:

  ```tsx
        {danhMucTong > soDaTai ? (
          <p className={styles['doc-them']} data-danh-muc-thieu>
            Hệ thống có {danhMucTong} vai trò, màn này chỉ đọc được {soDaTai} đầu tiên.
          </p>
        ) : null}
  ```

  Thêm `import { vaiTroDangDung } from '../api/user-api';` vào khối import đã có.

- [ ] **Step 4: Chạy test, lint, arch; THẤY XANH.**

  ```
  npx vitest run src/modules/user/pages/UserDetailPage.test.tsx
  npm test
  npm run lint
  npm run arch
  ```

- [ ] **Step 5: Commit.**

  ```
  fix(user): màn gán vai trò lọc bỏ vai trò đã tắt

  GET /roles là MỘT endpoint phục vụ cả màn quản trị lẫn màn gán, nên nó trả
  cả vai trò đã tắt (ADR-0038). Gán một vai trò đã tắt bị backend từ chối bằng
  câu "vai trò không tồn tại" - không ai chẩn đoán ra được, nên không bày ra
  lựa chọn ấy ngay từ đầu.

  Cảnh báo "danh mục vượt trần" so trần với số dòng ĐÃ TẢI chứ không với số
  dòng sau khi lọc: so nhầm thì mọi vai trò bị tắt thành một báo động sai.
  ```

---

## Task 9: Soi lại cả đợt trước khi giao

Không viết code mới. Task này là phép kiểm chứng cuối, và nó phải để lại BẰNG CHỨNG là output
thật của lệnh, không phải một câu khẳng định.

**Files:** không sửa file nào trừ khi một bước dưới đây bắt lỗi.

- [ ] **Step 1: Chạy đủ bốn lệnh, dán output vào phần mô tả đợt việc.**

  ```
  npm test
  npm run lint
  npm run arch
  npx tsc --noEmit
  ```

  Cả bốn phải xanh. `npm run arch` đỏ ở bước này nghĩa là một task trước đó quên
  `npm run arch:update` - chạy nó rồi commit riêng file golden.

- [ ] **Step 2: Đối chiếu từng dòng của spec mục 7.**

  | Câu của spec | Chỗ thực hiện |
  |---|---|
  | 7.1 bỏ `VAI_TRO_MAU`, đọc `GET /roles` | Task 6 Step 3, Task 7 Step 1 |
  | 7.1 sáu cột giữ nguyên | Task 6 Step 3 (`soCot={6}`) |
  | 7.1 nút Tắt/Bật trong ô Thao tác | Task 6 Step 4 |
  | 7.1 xác nhận hai bước tại chỗ, nói đúng con số | Task 6 Step 4, test Step 1 |
  | 7.1 `he_thong_tao` khoá mềm nút Tắt kèm lý do | Task 6 Step 4 |
  | 7.1 xoá dải cảnh báo dữ liệu mẫu | Task 6 Step 3 |
  | 7.1 xoá `xemTruoc: true`, sửa test đang khoá chip | Task 7 Step 2, Step 3 |
  | 7.2 khối quyền nhóm theo phân hệ rồi đối tượng | Task 3 (`nhomHienThi`), Task 5 Step 5 |
  | 7.2 checkbox cha ba trạng thái vào chính `DanhSachChon` | Task 2 |
  | 7.2 khoá từng dòng kèm lý do vào chính `DanhSachChon` | Task 1 |
  | 7.2 nút Lưu giữ khuôn khoá mềm kèm lý do | Task 5 Step 6 |
  | 7.2 gỡ `LY_DO_CHUA_CO_DUONG_GHI` và khối ghi chú | Task 5 Step 4 |
  | 7.2 giữ tên biến `muc` | Task 5 Step 5, Task 6 Step 4 |
  | 7.2 câu cố định dưới khối quyền | **Đổi**: "có hiệu lực ngay", xem đầu file |
  | 7.3 viết lại bộ test của hai màn | Task 5 Step 1-2, Task 6 Step 1 |
  | 7.3 kiểm bằng `data-*` và class | Mọi bài test của Task 1, 2, 5, 6, 8 |
  | 7.3 ca `cap_duoc` | Task 1 Step 1, Task 5 Step 2 |
  | 7.3 ca checkbox cha ba trạng thái | Task 2 Step 1 |
  | 7.3 ca xác nhận hai bước khi tắt vai trò có người giữ | Task 6 Step 1 |
  | 7.3 ca vai trò hệ thống | Task 5 Step 2, Task 6 Step 1 |
  | 7.3 ca lỗi 422 tố đúng trường | Task 5 Step 2, Task 6 Step 1 |
  | 6bis điểm 2: màn gán lọc `dang_dung` | Task 8 |

  Spec 7.3 viết *"vai trò hệ thống khoá đúng BA thứ và mở đúng hai thứ"*, còn backend chỉ khoá
  HAI trường (`permissions`, `dang_dung`). Ba thứ ấy là: tập quyền và ô Đang dùng ở màn form,
  cộng nút Tắt ở màn danh sách - mà nút Tắt chính là `dang_dung` nhìn từ màn kia. Kế hoạch phủ
  cả ba chỗ, nên hai cách đếm đều đúng.

- [ ] **Step 3: Chạy checklist review của repo.**

  `docs-erp/06-checklists/CL-PR-code-review.md`. Đánh dấu một dòng nghĩa là ĐÃ KIỂM THẬT.

- [ ] **Step 4: Mở màn thật trên máy dev và đi một vòng.**

  `npm run dev` không đủ để kết luận: bộ test chạy trên jsdom, và dev là HTTP nên mất mọi
  secure-context API. Đi đúng năm đường bằng tài khoản `qa-admin` trên máy dev:

  1. Tạo một vai trò mới, tích vài quyền, Lưu - và kiểm rằng nó xuất hiện NGAY ở màn gán
     (`XoaBanChup` phải làm việc; nếu vai trò biến mất một lúc thì lỗi ở backend, không ở đây).
  2. Sửa tên một vai trò hệ thống - phải qua.
  3. Thử tắt một vai trò hệ thống - nút phải khoá mềm và đọc được lý do bằng phím Tab.
  4. Tắt một vai trò thường đang có người giữ - phải hỏi lại kèm đúng con số.
  5. Mở màn gán và xác nhận vai trò vừa tắt KHÔNG còn trong ô chọn.

- [ ] **Step 5: `superpowers:requesting-code-review` rồi mới merge.**

---

## Ghi chú cho người thi công

**Task chạy song song được:** Task 1 và Task 2 phải nối tiếp (cùng file). Task 3 độc lập với
Task 1-2, chạy song song được. Task 4 cần Task 3. Task 5 và Task 6 cần cả Task 2 lẫn Task 4;
hai task này đụng hai cặp file khác nhau nên chạy song song được, nhưng chúng cùng chạm
`arch/LEVELS.md` - để một trong hai chạy `arch:update`, task kia rebase lên. Task 7 cần cả 5 và
6. Task 8 độc lập với 5-7, chỉ cần Task 3.

**Luật của repo, đừng để phải tra lại:**

- Frontend KHÔNG giữ quy tắc nghiệp vụ (R-19): mã vai trò chỉ XEM TRƯỚC, mã cuối do backend
  chốt; quyền nào hợp lệ do `cap_duoc` nói.
- Kiểm test bằng `data-*` và class, KHÔNG bằng chữ. Một dòng chữ bị CSS giấu vẫn nằm trong
  `textContent`, nên test đọc chữ sẽ xanh trên một màn hình câm. Ngoại lệ: câu lý do khoá và
  câu hỏi xác nhận, vì ở đó chính câu chữ mới là thứ phải tới được người dùng.
- Test dùng vitest + `react-dom/client` + `act`, **không** React Testing Library. Mỗi file tự
  dựng `container`/`root`. File mẫu: `VaiTroFormPage.test.tsx`, `DanhSachChon.test.tsx`,
  `UserDetailPage.test.tsx`.
- CSS Module, tên class tiếng Việt KHÔNG dấu nối gạch ngang. Giá trị thô chỉ được viết ở
  `tokens.css`; mọi chỗ khác gọi qua `var(--...)`.
- Chữ hiển thị cho người dùng: tiếng Việt CÓ DẤU. Luật này thắng lối viết không dấu của code
  cũ và của thông điệp backend.
- `erp/c-ts-06-no-role-guess` cấm biến tên `vai_tro` / `.roles` rẽ nhánh JSX. Hai màn đặt tên
  tham số là `muc` - giữ lối đó, đừng tắt luật.
- `npm run arch` chạy RIÊNG, không nằm trong `npm test`. Thêm hay xoá file làm golden
  `arch/LEVELS.md` lệch. Dưới Windows, `npm run arch:update` **dùng được** ở repo frontend
  (khác `backend-erp`, nơi nó đóng đinh một kết quả đỏ giả).
</content>
</invoke>
