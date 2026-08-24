# Kế hoạch thi công: module quản trị hai màn

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to
> implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Spec:** `docs-erp/99-meta/my-specs/2026-08-24-module-quan-tri-hai-man-spec.md`

**Goal:** Module quản trị hệ thống còn đúng hai mục thanh bên - Phân quyền và Vùng dữ liệu -
với năm mặt, thay cho bốn mục và bảy màn hôm nay.

**Architecture:** Toàn bộ nằm trong `frontend-erp`. Mỗi mặt là một địa chỉ riêng, nối bằng
`DaiTab` (dải liên kết, không phải `role="tablist"`). Hai mặt chạy API thật đang có
(`/companies`, `/users`, `/roles`), ba mặt chạy dữ liệu giả khai trong `components/` của module
và mang dải cảnh báo hai dòng cùng nút ghi khoá mềm. Không chạm `backend-erp` trong đợt này.

**Tech Stack:** React 19, TypeScript, Vite, TanStack Query, CSS Modules, vitest + jsdom +
Testing Library. Router tự viết (`src/app/routes.tsx`, `src/app/router/`).

**Chạy ở đâu:** mọi lệnh trong kế hoạch này chạy tại `d:/My project web/erp/frontend-erp`.
`npm test` chạy được dưới máy. `cmd/dev test` của backend thì không (xem `MEMORY.md`).

**Vệ sinh git:** cây làm việc dùng chung nhiều phiên. **Cấm `git add -A`.** Mỗi commit liệt kê
từng đường dẫn. Làm trên nhánh `feat/module-quan-tri-hai-man`, không commit thẳng vào `main`.

---

## Bảng đường dẫn mới

Thứ tự dòng trong `ROUTES` là thứ tự thử khớp, và `matchSegments` so **số đoạn** trước. Nên
mọi đoạn chữ phải đứng **trên** đoạn tham số cùng số đoạn.

| Đường dẫn | Số đoạn | Màn |
|---|---|---|
| `/quan-tri/phan-quyen` | 2 | `VaiTroListPage` (mặt Vai trò) |
| `/quan-tri/phan-quyen/moi` | 3 | `VaiTroFormPage` |
| `/quan-tri/phan-quyen/gan` | 3 | `UserListPage` (mặt Gán vai trò) |
| `/quan-tri/phan-quyen/:id` | 3 | `VaiTroFormPage` **phải đứng sau hai dòng trên** |
| `/quan-tri/phan-quyen/gan/:id` | 4 | `UserDetailPage` |
| `/quan-tri/vung-du-lieu` | 2 | `VungDuLieuListPage` (mặt Vùng dữ liệu) |
| `/quan-tri/vung-du-lieu/moi` | 3 | `VungDuLieuFormPage` |
| `/quan-tri/vung-du-lieu/phan-vung` | 3 | `CompanyListPage` (mặt Phân vùng) |
| `/quan-tri/vung-du-lieu/gan` | 3 | `GanQuanTriListPage` (mặt Gán quản trị module) |
| `/quan-tri/vung-du-lieu/:id` | 3 | `VungDuLieuFormPage` **phải đứng sau ba dòng trên** |
| `/quan-tri/vung-du-lieu/phan-vung/moi` | 4 | `CompanyFormPage` |
| `/quan-tri/vung-du-lieu/phan-vung/:id` | 4 | `CompanyFormPage` **sau `/moi`** |
| `/quan-tri/vung-du-lieu/gan/moi` | 4 | `GanQuanTriFormPage` |
| `/quan-tri/vung-du-lieu/gan/:id` | 4 | `GanQuanTriFormPage` **sau `/moi`** |

Xoá hẳn: `/phan-quyen`, `/phan-quyen/:id`, `/phan-quyen/:id/ma-tran`, `/phan-vung`,
`/phan-vung/moi`, `/phan-vung/:id`, `/quan-tri/tai-khoan*`, `/quan-tri/bo-nhiem*`,
`/nguoi-dung*`.

## Cấu trúc file

**Tạo mới**

| File | Việc |
|---|---|
| `src/app/mat-phan-quyen.ts` | Hai mặt của màn Phân quyền |
| `src/app/mat-vung-du-lieu.ts` | Ba mặt của màn Vùng dữ liệu |
| `src/modules/user/components/vai-tro-mau.ts` | Kiểu + dữ liệu giả vai trò |
| `src/modules/user/pages/VaiTroListPage.tsx` `.module.css` `.test.tsx` | Mặt Vai trò |
| `src/modules/user/pages/VaiTroFormPage.tsx` `.module.css` `.test.tsx` | Form vai trò |
| `src/modules/company/components/vung-du-lieu-mau.ts` | Kiểu + dữ liệu giả vùng dữ liệu |
| `src/modules/company/components/gan-quan-tri-mau.ts` | Kiểu + dữ liệu giả lượt gán |
| `src/modules/company/pages/GanQuanTriListPage.tsx` `.module.css` `.test.tsx` | Mặt Gán quản trị |
| `src/modules/company/pages/GanQuanTriFormPage.tsx` `.module.css` `.test.tsx` | Form lượt gán |

**Sửa**

`src/app/routes.tsx`, `src/app/routes.test.tsx`, `src/app/ung-dung.ts`,
`src/app/ung-dung.test.ts`, `src/app/AppLayout.test.tsx`, `src/app/quy-trinh.ts:46,61`,
`src/modules/user/pages/UserListPage.tsx` + test,
`src/modules/user/pages/UserDetailPage.tsx` + test,
`src/modules/company/pages/CompanyListPage.tsx` + test,
`src/modules/company/pages/CompanyFormPage.tsx` + test,
`src/modules/company/pages/VungDuLieuListPage.tsx` + test,
`src/modules/company/pages/VungDuLieuFormPage.tsx`.

**Xoá** (kèm `.module.css` và `.test.tsx` của từng file)

`src/modules/user/pages/MaTranQuyenPage.tsx`,
`src/modules/user/pages/TaiKhoanListPage.tsx`,
`src/modules/user/pages/TaiKhoanFormPage.tsx`,
`src/modules/user/pages/BoNhiemListPage.tsx`,
`src/modules/user/pages/BoNhiemFormPage.tsx`,
`src/modules/user/pages/ChuyenHuongChiTiet.tsx`,
`src/modules/user/components/mat-tai-khoan.ts`.

---

## Task 1: Dựng nhánh và chốt vạch xuất phát

**Files:** không sửa file nào.

- [ ] **Bước 1: Dựng nhánh**

```bash
cd "d:/My project web/erp/frontend-erp"
git status --short
git checkout -b feat/module-quan-tri-hai-man
```

Nếu `git status --short` có file lạ của phiên khác thì **dừng lại và báo** - cây làm việc
dùng chung, không được cuốn thay đổi của người khác vào nhánh này.

- [ ] **Bước 2: Chốt vạch xuất phát**

```bash
npm test 2>&1 | tail -20
npm run lint
npm run arch
```

Ghi lại số test xanh. Mọi task sau phải giữ ba lệnh này sạch. Nếu vạch xuất phát đã đỏ thì
báo ngay, đừng sửa - đó là việc của phiên khác.

---

## Task 2: Xoá sáu màn và một danh sách mặt

**Files:**
- Xoá: 6 page kể trên + `.module.css` + `.test.tsx` của từng file, và `mat-tai-khoan.ts` + test
- Sửa: `src/app/routes.tsx`

- [ ] **Bước 1: Xoá file**

```bash
cd "d:/My project web/erp/frontend-erp"
git rm src/modules/user/pages/MaTranQuyenPage.tsx \
       src/modules/user/pages/MaTranQuyenPage.module.css \
       src/modules/user/pages/MaTranQuyenPage.test.tsx \
       src/modules/user/pages/TaiKhoanListPage.tsx \
       src/modules/user/pages/TaiKhoanListPage.module.css \
       src/modules/user/pages/TaiKhoanListPage.test.tsx \
       src/modules/user/pages/TaiKhoanFormPage.tsx \
       src/modules/user/pages/TaiKhoanFormPage.module.css \
       src/modules/user/pages/TaiKhoanFormPage.test.tsx \
       src/modules/user/pages/BoNhiemListPage.tsx \
       src/modules/user/pages/BoNhiemListPage.module.css \
       src/modules/user/pages/BoNhiemListPage.test.tsx \
       src/modules/user/pages/BoNhiemFormPage.tsx \
       src/modules/user/pages/BoNhiemFormPage.module.css \
       src/modules/user/pages/BoNhiemFormPage.test.tsx \
       src/modules/user/pages/ChuyenHuongChiTiet.tsx \
       src/modules/user/pages/ChuyenHuongChiTiet.test.tsx \
       src/modules/user/components/mat-tai-khoan.ts
```

Một vài file `.module.css` có thể không tồn tại. Chạy `git rm` từng nhóm nếu lệnh trên báo
`pathspec did not match`, đừng thêm `-f`.

- [ ] **Bước 2: Gỡ import và dòng route của chúng khỏi `routes.tsx`**

Gỡ 6 dòng `import` và 8 dòng route: `/phan-quyen/:id/ma-tran`, `/quan-tri/tai-khoan`,
`/quan-tri/tai-khoan/moi`, `/quan-tri/tai-khoan/:id`, `/quan-tri/bo-nhiem`,
`/quan-tri/bo-nhiem/moi`, `/quan-tri/bo-nhiem/:id`, và bốn dòng `/nguoi-dung*`. Gỡ luôn khối
ghi chú nói riêng về bốn đường `/nguoi-dung`.

- [ ] **Bước 3: Chạy để thấy nó đỏ đúng chỗ**

```bash
npm test 2>&1 | tail -30
```

Expected: `routes.test.tsx` đỏ ở các ca nhắc `/nguoi-dung` và `/quan-tri/bo-nhiem`;
`UserListPage.test.tsx` đỏ vì `mat-tai-khoan` không còn. Đây là đỏ **mong đợi**, task sau chữa.
Không đỏ ở chỗ khác.

- [ ] **Bước 4: Commit**

```bash
git add src/app/routes.tsx
git commit -m "chore(quan-tri): xoa sau man va danh sach mat tai khoan"
```

---

## Task 3: Bảng route mới

**Files:**
- Sửa: `src/app/routes.tsx`
- Test: `src/app/routes.test.tsx`

- [ ] **Bước 1: Viết test đỏ trước**

Thêm vào `src/app/routes.test.tsx`. Đọc các ca sẵn có trong file để bắt chước cách gọi
`matchRoute` và cách khẳng định của repo.

```tsx
describe('bang route module quan tri', () => {
  const duongCanKhop = [
    '/quan-tri/phan-quyen',
    '/quan-tri/phan-quyen/moi',
    '/quan-tri/phan-quyen/gan',
    '/quan-tri/phan-quyen/vt-01',
    '/quan-tri/phan-quyen/gan/u-01',
    '/quan-tri/vung-du-lieu',
    '/quan-tri/vung-du-lieu/moi',
    '/quan-tri/vung-du-lieu/phan-vung',
    '/quan-tri/vung-du-lieu/gan',
    '/quan-tri/vung-du-lieu/vdl-01',
    '/quan-tri/vung-du-lieu/phan-vung/moi',
    '/quan-tri/vung-du-lieu/phan-vung/c-01',
    '/quan-tri/vung-du-lieu/gan/moi',
    '/quan-tri/vung-du-lieu/gan/g-01',
  ];

  it.each(duongCanKhop)('khop %s', (duong) => {
    expect(matchRoute(duong)).not.toBeNull();
  });

  // Bay so mot: 'moi', 'gan', 'phan-vung' deu ba doan y het mot tham so id, nen dong
  // '/:id' dung tren se nuot ca ba. Khoa THU TU chu khong khoa su ton tai.
  const doanChuTruocThamSo: ReadonlyArray<[string, string]> = [
    ['/quan-tri/phan-quyen/moi', '/quan-tri/phan-quyen/:id'],
    ['/quan-tri/phan-quyen/gan', '/quan-tri/phan-quyen/:id'],
    ['/quan-tri/vung-du-lieu/moi', '/quan-tri/vung-du-lieu/:id'],
    ['/quan-tri/vung-du-lieu/phan-vung', '/quan-tri/vung-du-lieu/:id'],
    ['/quan-tri/vung-du-lieu/gan', '/quan-tri/vung-du-lieu/:id'],
    ['/quan-tri/vung-du-lieu/phan-vung/moi', '/quan-tri/vung-du-lieu/phan-vung/:id'],
    ['/quan-tri/vung-du-lieu/gan/moi', '/quan-tri/vung-du-lieu/gan/:id'],
  ];

  it.each(doanChuTruocThamSo)('%s dung truoc %s', (truoc, sau) => {
    const iTruoc = ROUTES.findIndex((r) => r.path === truoc);
    const iSau = ROUTES.findIndex((r) => r.path === sau);
    expect(iTruoc).toBeGreaterThanOrEqual(0);
    expect(iSau).toBeGreaterThanOrEqual(0);
    expect(iTruoc).toBeLessThan(iSau);
  });

  const duongDaXoa = [
    '/phan-quyen',
    '/phan-quyen/u-01',
    '/phan-vung',
    '/quan-tri/tai-khoan',
    '/quan-tri/bo-nhiem',
    '/nguoi-dung',
  ];

  it.each(duongDaXoa)('khong con %s', (duong) => {
    expect(matchRoute(duong)).toBeNull();
  });
});
```

Sửa luôn các ca cũ trong file nhắc tới `/phan-quyen`, `/phan-vung`, `/nguoi-dung`,
`/quan-tri/bo-nhiem` cho khớp bảng mới.

- [ ] **Bước 2: Chạy để thấy đỏ**

```bash
npx vitest run src/app/routes.test.tsx
```

Expected: FAIL, các ca `khop /quan-tri/...` nhận `null`.

- [ ] **Bước 3: Viết bảng route**

Trong `src/app/routes.tsx`: đổi import `UserListPage`, `UserDetailPage`, `CompanyListPage`,
`CompanyFormPage`, `VungDuLieuListPage`, `VungDuLieuFormPage` giữ nguyên; thêm import
`VaiTroListPage`, `VaiTroFormPage` từ `@/modules/user/pages/`, `GanQuanTriListPage`,
`GanQuanTriFormPage` từ `@/modules/company/pages/`. Thay cụm route quản trị bằng:

```tsx
  // MODULE QUẢN TRỊ - hai màn, năm mặt. Xem spec 2026-08-24-module-quan-tri-hai-man.
  //
  // Bẫy thứ tự ở đây NẶNG hơn cặp '/kho*': ba đoạn chữ 'moi', 'gan', 'phan-vung' đều dài
  // đúng ba đoạn y hệt '/quan-tri/vung-du-lieu/:id', nên một dòng ':id' đặt lên trên sẽ
  // nuốt cả ba mà không báo gì - URL vẫn khớp, chỉ khớp nhầm màn. routes.test.tsx khoá
  // thứ tự này chứ không phải khối ghi chú này.
  { path: '/quan-tri/phan-quyen', render: () => <VaiTroListPage /> },
  { path: '/quan-tri/phan-quyen/moi', render: () => <VaiTroFormPage /> },
  { path: '/quan-tri/phan-quyen/gan', render: () => <UserListPage /> },
  { path: '/quan-tri/phan-quyen/:id', render: (p) => <VaiTroFormPage id={p.id} /> },
  { path: '/quan-tri/phan-quyen/gan/:id', render: (p) => <UserDetailPage id={p.id} /> },
  { path: '/quan-tri/vung-du-lieu', render: () => <VungDuLieuListPage /> },
  { path: '/quan-tri/vung-du-lieu/moi', render: () => <VungDuLieuFormPage /> },
  { path: '/quan-tri/vung-du-lieu/phan-vung', render: () => <CompanyListPage /> },
  { path: '/quan-tri/vung-du-lieu/gan', render: () => <GanQuanTriListPage /> },
  { path: '/quan-tri/vung-du-lieu/:id', render: (p) => <VungDuLieuFormPage id={p.id} /> },
  { path: '/quan-tri/vung-du-lieu/phan-vung/moi', render: () => <CompanyFormPage /> },
  { path: '/quan-tri/vung-du-lieu/phan-vung/:id', render: (p) => <CompanyFormPage id={p.id} /> },
  { path: '/quan-tri/vung-du-lieu/gan/moi', render: () => <GanQuanTriFormPage /> },
  { path: '/quan-tri/vung-du-lieu/gan/:id', render: (p) => <GanQuanTriFormPage id={p.id} /> },
```

Bốn page mới chưa tồn tại. Tạo bốn file rỗng tối thiểu để build chạy được - task 5, 6, 11 sẽ
viết ruột:

```tsx
// src/modules/user/pages/VaiTroListPage.tsx (tạm)
export function VaiTroListPage() {
  return <h1>Phân quyền</h1>;
}
```

Làm tương tự cho `VaiTroFormPage` (nhận `{ id }: { id?: string }`), `GanQuanTriListPage`,
`GanQuanTriFormPage` (nhận `{ id }: { id?: string }`).

- [ ] **Bước 4: Chạy để thấy xanh**

```bash
npx vitest run src/app/routes.test.tsx
```

Expected: PASS toàn bộ.

- [ ] **Bước 5: Commit**

```bash
git add src/app/routes.tsx src/app/routes.test.tsx \
        src/modules/user/pages/VaiTroListPage.tsx \
        src/modules/user/pages/VaiTroFormPage.tsx \
        src/modules/company/pages/GanQuanTriListPage.tsx \
        src/modules/company/pages/GanQuanTriFormPage.tsx
git commit -m "feat(quan-tri): bang route hai man nam mat"
```

---

## Task 4: Thanh bên còn hai mục

**Files:**
- Sửa: `src/app/ung-dung.ts`, `src/app/quy-trinh.ts:46,61`
- Test: `src/app/ung-dung.test.ts`, `src/app/AppLayout.test.tsx`

- [ ] **Bước 1: Viết test đỏ**

Thêm vào `src/app/ung-dung.test.ts`:

```ts
describe('ung dung auth sau dot hai man', () => {
  const auth = UNG_DUNG.find((u) => u.id === 'auth');

  it('co dung hai muc thanh ben', () => {
    expect(auth?.man).toHaveLength(2);
    expect(auth?.man.map((m) => m.duong)).toEqual([
      '/quan-tri/phan-quyen',
      '/quan-tri/vung-du-lieu',
    ]);
  });

  it('trang chu bang muc dau tien', () => {
    expect(auth?.duong).toBe('/quan-tri/phan-quyen');
  });

  it('duongThuoc chi con mot goc', () => {
    expect(auth?.duongThuoc).toEqual(['/quan-tri']);
  });

  it('ca hai muc deu chi danh cho quan tri he thong', () => {
    expect(auth?.man.every((m) => m.chiQuanTriHeThong === true)).toBe(true);
  });
});
```

Trong `AppLayout.test.tsx`, sửa các ca khoá cờ `chiQuanTriHeThong`: người **không** phải quản
trị hệ thống nay thấy **không mục nào** của ứng dụng auth, người là quản trị hệ thống thấy
đúng hai mục.

- [ ] **Bước 2: Chạy để thấy đỏ**

```bash
npx vitest run src/app/ung-dung.test.ts src/app/AppLayout.test.tsx
```

Expected: FAIL, `man` đang có 4 phần tử.

- [ ] **Bước 3: Sửa `ung-dung.ts`**

Thay khối `id: 'auth'` bằng:

```ts
  {
    id: 'auth',
    ten: 'Quản trị hệ thống',
    mo: 'Vai trò và vùng dữ liệu.',
    tab: 'he-thong',
    duong: '/quan-tri/phan-quyen',
    // nhan PHẢI là null khi duong khác null - ung-dung.test.ts khoá bất biến đó.
    nhan: null,
    // Hai mục, đúng hai việc của quản trị hệ thống. Trước 2026-08-24 chỗ này có bốn mục và
    // người dùng đọc ra ngay là chúng trùng nhau: ba trong bốn mục cùng đổ bảng `users`.
    // Nay mỗi mục là một ĐỐI TƯỢNG - vai trò, và phạm vi dữ liệu - còn các mặt của cùng một
    // đối tượng nằm trong dải tab của chính màn đó (`mat-phan-quyen.ts`, `mat-vung-du-lieu.ts`).
    //
    // Cả hai mang `chiQuanTriHeThong`: cờ đó đến từ `is_system_admin` của `GET /auth/me`,
    // là câu trả lời của backend cho "phiên này mở được màn đó không", không phải một role
    // đoán ra (C-TS-06).
    man: [
      {
        duong: '/quan-tri/phan-quyen',
        nhan: 'Phân quyền',
        bieuTuong: 'nguoi-dung',
        chiQuanTriHeThong: true,
      },
      {
        duong: '/quan-tri/vung-du-lieu',
        nhan: 'Vùng dữ liệu',
        bieuTuong: 'vung-du-lieu',
        chiQuanTriHeThong: true,
      },
    ],
    // Một gốc duy nhất, vì cả năm mặt nay nằm dưới '/quan-tri'. Ba gốc cũ ('/phan-quyen',
    // '/phan-vung', '/nguoi-dung') đã hết đường trỏ tới.
    duongThuoc: ['/quan-tri'],
  },
```

Sửa `src/app/quy-trinh.ts` dòng 46 và 61: `duong: '/phan-quyen'` → `'/quan-tri/phan-quyen'`,
`ten: 'Tài khoản'` → `'Phân quyền'`.

- [ ] **Bước 4: Chạy để thấy xanh**

```bash
npx vitest run src/app/ung-dung.test.ts src/app/AppLayout.test.tsx src/app/quy-trinh.test.ts
```

Expected: PASS.

- [ ] **Bước 5: Commit**

```bash
git add src/app/ung-dung.ts src/app/ung-dung.test.ts src/app/AppLayout.test.tsx src/app/quy-trinh.ts
git commit -m "feat(quan-tri): thanh ben con hai muc phan quyen va vung du lieu"
```

---

## Task 5: Hai danh sách mặt

**Files:**
- Create: `src/app/mat-phan-quyen.ts`, `src/app/mat-vung-du-lieu.ts`

Đặt ở `app/` chứ không ở `modules/`: mặt của màn Vùng dữ liệu thuộc hai module khác nhau
(`company` giữ Phân vùng và Vùng dữ liệu, page Gán quản trị cũng ở `company` nhưng nói về
`user`), và không module nào được quyền giữ danh sách của module khác (C-TS-01). Hai danh sách
để riêng hai file vì chúng thuộc hai màn, và ngày một màn đổi mặt thì file kia không bị chạm.

- [ ] **Bước 1: Viết hai file**

```ts
// src/app/mat-phan-quyen.ts
//
// Hai MẶT của màn Phân quyền. Cùng một đối tượng - vai trò - nhìn từ hai đầu: danh mục vai
// trò, và ai đang giữ vai trò nào. Đúng điều kiện dùng dải tab của `khuon-man-hinh.md` mục
// 0.2; ba màn rời nhét vào ba tab thì không.

export interface MatManHinh {
  duong: string;
  nhan: string;
  /** Mặt chưa nối máy chủ. Đeo chip "Xem trước" để một cái tab không đọc ra như một tính năng. */
  xemTruoc?: boolean;
}

export const MAT_PHAN_QUYEN: readonly MatManHinh[] = [
  { duong: '/quan-tri/phan-quyen', nhan: 'Vai trò', xemTruoc: true },
  { duong: '/quan-tri/phan-quyen/gan', nhan: 'Gán vai trò' },
];
```

```ts
// src/app/mat-vung-du-lieu.ts
//
// Ba MẶT của màn Vùng dữ liệu, theo đúng ba bước của một việc: dựng chi nhánh -> gom chi
// nhánh thành vùng -> giao vùng cho một người quản trị phân hệ. Ai mở màn này ra đều đi ba
// bước đó theo thứ tự, nên thứ tự tab là thứ tự làm việc chứ không phải thứ tự bảng chữ cái.

import type { MatManHinh } from './mat-phan-quyen';

export const MAT_VUNG_DU_LIEU: readonly MatManHinh[] = [
  { duong: '/quan-tri/vung-du-lieu/phan-vung', nhan: 'Phân vùng' },
  { duong: '/quan-tri/vung-du-lieu', nhan: 'Vùng dữ liệu', xemTruoc: true },
  { duong: '/quan-tri/vung-du-lieu/gan', nhan: 'Gán quản trị module', xemTruoc: true },
];
```

- [ ] **Bước 2: Kiểm ranh giới module**

```bash
npm run lint
```

Expected: sạch. Nếu `c-ts-01-module-boundary` kêu thì danh sách đang bị đặt sai chỗ - đọc lại
lý do ở đầu task này.

- [ ] **Bước 3: Commit**

```bash
git add src/app/mat-phan-quyen.ts src/app/mat-vung-du-lieu.ts
git commit -m "feat(quan-tri): hai danh sach mat cho dai tab"
```

---

## Task 6: Dữ liệu giả và kiểu

**Files:**
- Create: `src/modules/user/components/vai-tro-mau.ts`
- Create: `src/modules/company/components/vung-du-lieu-mau.ts`
- Create: `src/modules/company/components/gan-quan-tri-mau.ts`

Ba file này là **hợp đồng** mà năm task sau bám vào. Viết trước, viết đủ, không sửa tên trường
ở task sau.

- [ ] **Bước 1: `vai-tro-mau.ts`**

```ts
// Dữ liệu MẪU cho mặt Vai trò. Bảng `roles` đã có trong database (ADR-0023), nhưng đường
// ghi qua HTTP thì chưa: `GET /roles` hôm nay trả đúng hai trường {ma, nhan}, và không có
// POST/PATCH/DELETE nào. Xem spec 2026-08-24-module-quan-tri-hai-man mục 6.
//
// Tên trường giữ snake_case của backend, đúng lối của mọi DTO trong repo này - ngày nối API
// thật thì chỉ đổi nguồn, không đổi chỗ đọc.

export interface VaiTroMau {
  id: string;
  ma: string;
  nhan: string;
  /** Mã phân hệ: 'inventory' | 'machine' | 'auth'. Giữ chuỗi vì backend chưa chốt enum. */
  phan_he: string;
  nhan_phan_he: string;
  mo_ta: string;
  so_nguoi_giu: number;
  is_active: boolean;
}

export const VAI_TRO_MAU: readonly VaiTroMau[] = [
  {
    id: 'vt-01',
    ma: 'inventory.thu_kho',
    nhan: 'Thủ kho',
    phan_he: 'inventory',
    nhan_phan_he: 'Kho vận',
    mo_ta: 'Ghi nhận nhập xuất, kiểm kê tồn kho của các kho được giao.',
    so_nguoi_giu: 12,
    is_active: true,
  },
  {
    id: 'vt-02',
    ma: 'inventory.admin',
    nhan: 'Quản trị Kho vận',
    phan_he: 'inventory',
    nhan_phan_he: 'Kho vận',
    mo_ta: 'Mở quyền cho nhân sự trong phân hệ Kho vận.',
    so_nguoi_giu: 3,
    is_active: true,
  },
  {
    id: 'vt-03',
    ma: 'machine.van_hanh',
    nhan: 'Vận hành thiết bị',
    phan_he: 'machine',
    nhan_phan_he: 'Thiết bị',
    mo_ta: 'Báo sự cố và ghi nhật ký vận hành máy.',
    so_nguoi_giu: 24,
    is_active: true,
  },
  {
    id: 'vt-04',
    ma: 'machine.admin',
    nhan: 'Quản trị Thiết bị',
    phan_he: 'machine',
    nhan_phan_he: 'Thiết bị',
    mo_ta: 'Mở quyền cho nhân sự trong phân hệ Thiết bị.',
    so_nguoi_giu: 2,
    is_active: true,
  },
  {
    id: 'vt-05',
    ma: 'inventory.xem_bao_cao',
    nhan: 'Xem báo cáo kho',
    phan_he: 'inventory',
    nhan_phan_he: 'Kho vận',
    mo_ta: 'Chỉ đọc báo cáo tồn và chuyển động, không ghi.',
    so_nguoi_giu: 0,
    is_active: false,
  },
];

export const PHAN_HE_CHON_DUOC: ReadonlyArray<{ ma: string; nhan: string }> = [
  { ma: 'inventory', nhan: 'Kho vận' },
  { ma: 'machine', nhan: 'Thiết bị' },
  { ma: 'auth', nhan: 'Quản trị hệ thống' },
];
```

- [ ] **Bước 2: `vung-du-lieu-mau.ts`**

```ts
// Dữ liệu MẪU cho mặt Vùng dữ liệu. Một vùng là một NHÓM PHÂN VÙNG có tên - không phải nhóm
// kho. Đây là chốt lại ngày 2026-08-24: phạm vi cấp 1 bám vào chi nhánh, thứ mọi phân hệ đều
// có, còn danh sách kho lùi xuống cấp 2 (`PUT /users/:id/scopes`, vẫn chạy, không bị xoá).
//
// Chưa có bảng và chưa có endpoint. Xem spec mục 6.

export interface PhanVungTomTat {
  id: string;
  code: string;
  name: string;
}

export interface VungDuLieuMau {
  id: string;
  ten: string;
  mo_ta: string;
  phan_vung: readonly PhanVungTomTat[];
  /** Số lượt gán quản trị module đang trỏ vào vùng này. Khoá mềm nút Xoá khi > 0. */
  so_luot_gan: number;
}

export const PHAN_VUNG_MAU: readonly PhanVungTomTat[] = [
  { id: 'c-01', code: 'TS', name: 'Trụ sở' },
  { id: 'c-02', code: 'CN-HN', name: 'Chi nhánh Hà Nội' },
  { id: 'c-03', code: 'CN-HCM', name: 'Chi nhánh Hồ Chí Minh' },
  { id: 'c-04', code: 'NM-TB', name: 'Nhà máy Thái Bình' },
  { id: 'c-05', code: 'CN-DN', name: 'Chi nhánh Đà Nẵng' },
];

export const VUNG_DU_LIEU_MAU: readonly VungDuLieuMau[] = [
  {
    id: 'vdl-01',
    ten: 'Miền Bắc',
    mo_ta: 'Trụ sở và các đơn vị từ Thanh Hoá trở ra.',
    phan_vung: [PHAN_VUNG_MAU[0], PHAN_VUNG_MAU[1], PHAN_VUNG_MAU[3]],
    so_luot_gan: 2,
  },
  {
    id: 'vdl-02',
    ten: 'Miền Nam',
    mo_ta: 'Các đơn vị từ Đà Nẵng trở vào.',
    phan_vung: [PHAN_VUNG_MAU[2], PHAN_VUNG_MAU[4]],
    so_luot_gan: 1,
  },
  {
    id: 'vdl-03',
    ten: 'Toàn công ty',
    mo_ta: 'Mọi phân vùng, kể cả phân vùng mở thêm sau này.',
    phan_vung: PHAN_VUNG_MAU,
    so_luot_gan: 1,
  },
  {
    id: 'vdl-04',
    ten: 'Nhà máy',
    mo_ta: 'Chỉ các đơn vị sản xuất.',
    phan_vung: [PHAN_VUNG_MAU[3]],
    so_luot_gan: 0,
  },
];
```

- [ ] **Bước 3: `gan-quan-tri-mau.ts`**

```ts
// Dữ liệu MẪU cho mặt Gán quản trị module.
//
// Một lượt gán = người × phân hệ × VÙNG DỮ LIỆU. Trục chi nhánh không còn nằm trên một dòng,
// vì vùng dữ liệu đã mang trục đó - đây là chỗ chốt câu bỏ ngỏ ở mục 4e của spec
// 2026-08-24-phan-quyen-hai-cap (tên màn nói theo chi nhánh còn cột nói theo phân hệ).

export type TrangThaiGan = 'hieu-luc' | 'da-thu-hoi';

export interface GanQuanTriMau {
  id: string;
  user_id: string;
  ho_ten: string;
  email: string;
  phan_he: string;
  nhan_phan_he: string;
  vung_id: string;
  ten_vung: string;
  so_phan_vung: number;
  trang_thai: TrangThaiGan;
}

export const GAN_QUAN_TRI_MAU: readonly GanQuanTriMau[] = [
  {
    id: 'g-01',
    user_id: 'u-01',
    ho_ten: 'Trần Văn Hạnh',
    email: 'hanh.tv@erp.test',
    phan_he: 'inventory',
    nhan_phan_he: 'Kho vận',
    vung_id: 'vdl-01',
    ten_vung: 'Miền Bắc',
    so_phan_vung: 3,
    trang_thai: 'hieu-luc',
  },
  {
    id: 'g-02',
    user_id: 'u-02',
    ho_ten: 'Nguyễn Thị Mai',
    email: 'mai.nt@erp.test',
    phan_he: 'inventory',
    nhan_phan_he: 'Kho vận',
    vung_id: 'vdl-02',
    ten_vung: 'Miền Nam',
    so_phan_vung: 2,
    trang_thai: 'hieu-luc',
  },
  {
    id: 'g-03',
    user_id: 'u-03',
    ho_ten: 'Lê Quốc Bảo',
    email: 'bao.lq@erp.test',
    phan_he: 'machine',
    nhan_phan_he: 'Thiết bị',
    vung_id: 'vdl-03',
    ten_vung: 'Toàn công ty',
    so_phan_vung: 5,
    trang_thai: 'hieu-luc',
  },
  {
    id: 'g-04',
    user_id: 'u-04',
    ho_ten: 'Phạm Hồng Sơn',
    email: 'son.ph@erp.test',
    phan_he: 'machine',
    nhan_phan_he: 'Thiết bị',
    vung_id: 'vdl-01',
    ten_vung: 'Miền Bắc',
    so_phan_vung: 3,
    trang_thai: 'da-thu-hoi',
  },
];
```

- [ ] **Bước 4: Kiểm biên dịch**

```bash
npx tsc --noEmit
npm run lint
```

Expected: cả hai sạch.

- [ ] **Bước 5: Commit**

```bash
git add src/modules/user/components/vai-tro-mau.ts \
        src/modules/company/components/vung-du-lieu-mau.ts \
        src/modules/company/components/gan-quan-tri-mau.ts
git commit -m "feat(quan-tri): kieu va du lieu mau cho ba mat chua noi API"
```

---

## Task 7: Mặt Vai trò

**Files:**
- Sửa: `src/modules/user/pages/VaiTroListPage.tsx` (đang là bản tạm của task 3)
- Create: `src/modules/user/pages/VaiTroListPage.module.css`, `VaiTroListPage.test.tsx`

**Trước khi viết:** đọc `src/modules/company/pages/VungDuLieuListPage.tsx` để lấy đúng khuôn
của một mặt chạy dữ liệu mẫu trong repo này (dải cảnh báo, `Bang`, khoá mềm), và đọc
`src/modules/inventory/pages/WarehouseListPage.tsx` để lấy khuôn một màn danh sách chuẩn.

**Bố cục màn:**

1. `TieuDeTrang` tiêu đề `Phân quyền`, mô tả `Vai trò và người giữ vai trò.`, hành động là
   `<Link to="/quan-tri/phan-quyen/moi">` bọc `Nut bien="chinh"` chữ `Tạo vai trò`.
2. `DaiTab nhan="Mặt của phân quyền"` với hai `<Link>` từ `MAT_PHAN_QUYEN`. Mặt đang mở mang
   `aria-current="page"`. Mặt có `xemTruoc` kèm `<NhanXemTruoc />`.
3. `BangThongBao sac="canh-bao"` **tối đa hai dòng**: nói bảng chạy dữ liệu mẫu, nêu hai mã
   `POST /roles` và `PATCH /roles/:id`, và một liên kết về spec.
4. `Bang soCot={6}` với `dauBang` sáu ô: `Mã`, `Tên vai trò`, `Phân hệ`, `Đang giữ`,
   `Trạng thái`, `Thao tác`.

**Nội dung một dòng:**

| Ô | Dựng bằng |
|---|---|
| Mã | `<MaBanGhi>{v.ma}</MaBanGhi>` |
| Tên vai trò | `v.nhan` đậm, dòng dưới `v.mo_ta` chữ nhạt |
| Phân hệ | `<NhanTrangThai sac="trung-tinh">{v.nhan_phan_he}</NhanTrangThai>` |
| Đang giữ | `<td className="so">{v.so_nguoi_giu}</td>` |
| Trạng thái | `<NhanTrangThai sac={v.is_active ? 'tot' : 'tat'}>` `Đang dùng` / `Đã tắt` |
| Thao tác | `<Link to={'/quan-tri/phan-quyen/' + v.id}>Sửa</Link>` |

**Không** thêm phân trang: dữ liệu mẫu 5 dòng, và một `PhanTrang` trên dữ liệu mẫu là nói dối
về một trang thứ hai không tồn tại.

- [ ] **Bước 1: Viết test đỏ**

```tsx
// src/modules/user/pages/VaiTroListPage.test.tsx
import { render, screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';

import { VAI_TRO_MAU } from '../components/vai-tro-mau';

import { VaiTroListPage } from './VaiTroListPage';

describe('VaiTroListPage', () => {
  it('do du mot dong cho moi vai tro mau', () => {
    render(<VaiTroListPage />);
    const dong = screen.getAllByRole('row');
    expect(dong).toHaveLength(VAI_TRO_MAU.length + 1);
  });

  it('noi ro dang chay du lieu mau', () => {
    render(<VaiTroListPage />);
    expect(screen.getByRole('status')).toHaveTextContent('POST /roles');
  });

  it('vai tro da tat mang nhan trang thai tat', () => {
    const { container } = render(<VaiTroListPage />);
    // Kiem bang CLASS chu khong bang chu: textContent khong thay chu bi CSS giau, va
    // bon thong diep trang thai da tung cam ca ngay ma 417 test van xanh.
    expect(container.querySelectorAll('[data-sac="tat"]')).toHaveLength(1);
  });

  it('moi dong co duong sang man sua', () => {
    render(<VaiTroListPage />);
    const lienKet = screen.getAllByRole('link', { name: 'Sửa' });
    expect(lienKet[0]).toHaveAttribute('href', '/quan-tri/phan-quyen/vt-01');
  });

  it('dai tab danh dau mat dang mo', () => {
    render(<VaiTroListPage />);
    const dangMo = screen.getByRole('link', { current: 'page' });
    expect(dangMo).toHaveAttribute('href', '/quan-tri/phan-quyen');
  });

  it('nut tao vai tro tro dung dia chi', () => {
    render(<VaiTroListPage />);
    expect(screen.getByRole('link', { name: /Tạo vai trò/ })).toHaveAttribute(
      'href',
      '/quan-tri/phan-quyen/moi',
    );
  });
});
```

Nếu `NhanTrangThai` chưa phát `data-sac` thì thêm thuộc tính đó vào
`src/shared/components/NhanTrangThai/NhanTrangThai.tsx` - một dòng, và nó là cách duy nhất để
test đọc được trạng thái mà không đi qua `textContent`.

`render` cần đúng bộ provider mà các test page khác dùng. Đọc `VungDuLieuListPage.test.tsx` và
dùng lại y hệt cách nó bọc.

- [ ] **Bước 2: Chạy để thấy đỏ**

```bash
npx vitest run src/modules/user/pages/VaiTroListPage.test.tsx
```

Expected: FAIL, `getAllByRole('row')` không tìm thấy gì (bản tạm chỉ có `<h1>`).

- [ ] **Bước 3: Viết màn theo bố cục ở trên**

Trước khi viết CSS, gọi skill `frontend-design-erp` để lấy đúng token và khuôn màn danh sách.
Không tự đặt màu; mọi màu lấy từ `src/shared/styles/tokens.css`. Chữ tiếng Việt **có dấu**.

- [ ] **Bước 4: Chạy để thấy xanh**

```bash
npx vitest run src/modules/user/pages/VaiTroListPage.test.tsx
npm run lint
```

Expected: 6 ca PASS, lint sạch.

- [ ] **Bước 5: Commit**

```bash
git add src/modules/user/pages/VaiTroListPage.tsx \
        src/modules/user/pages/VaiTroListPage.module.css \
        src/modules/user/pages/VaiTroListPage.test.tsx
git commit -m "feat(quan-tri): mat Vai tro cua man Phan quyen"
```

---

## Task 8: Form vai trò

**Files:**
- Sửa: `src/modules/user/pages/VaiTroFormPage.tsx`
- Create: `VaiTroFormPage.module.css`, `VaiTroFormPage.test.tsx`

**Trước khi viết:** đọc `src/modules/company/pages/CompanyFormPage.tsx` - nó là form gần nhất
về hình dạng (một page cho cả tạo lẫn sửa, phân biệt bằng **sự có mặt của `id`**, không phải
một prop `mode`).

**Bố cục:** `TieuDeTrang` (`Tạo vai trò` / `Sửa vai trò`, `quayLai` về
`/quan-tri/phan-quyen`), dải cảnh báo hai dòng, rồi form rộng `--rong-form`:

| Trường | Kiểu | Ràng buộc |
|---|---|---|
| Mã | text | Bắt buộc. **Chỉ sửa được khi tạo**; khi sửa thì `readOnly` kèm lời giải thích một dòng vì mã đã nằm trong dữ liệu đã ghi |
| Tên vai trò | text | Bắt buộc |
| Phân hệ áp dụng | select từ `PHAN_HE_CHON_DUOC` | Bắt buộc |
| Mô tả | textarea | Không bắt buộc |
| Trạng thái | checkbox `Đang dùng` | Mặc định bật |

Hai nút: `Lưu` (`Nut bien="chinh"`, **khoá mềm** `lyDoKhoa="Chưa có POST /roles và PATCH
/roles/:id. Xem spec 2026-08-24-module-quan-tri-hai-man."`) và `Huỷ` (`<Link>` về
`/quan-tri/phan-quyen`).

**Không có ma trận quyền trên màn này.** Người quyết chốt: tick từng ô Xem/Thêm/Sửa/Xoá/Duyệt
là việc của quản trị module, làm trong phân hệ của họ. Vẽ ma trận ở đây là nói sai ai làm gì.

- [ ] **Bước 1: Viết test đỏ**

```tsx
// src/modules/user/pages/VaiTroFormPage.test.tsx
describe('VaiTroFormPage', () => {
  it('khong co id thi tieu de la Tao vai tro', () => {
    render(<VaiTroFormPage />);
    expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent('Tạo vai trò');
  });

  it('co id thi tieu de la Sua vai tro va do san du lieu', () => {
    render(<VaiTroFormPage id="vt-01" />);
    expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent('Sửa vai trò');
    expect(screen.getByLabelText('Tên vai trò')).toHaveValue('Thủ kho');
  });

  it('ma khoa lai khi sua', () => {
    render(<VaiTroFormPage id="vt-01" />);
    expect(screen.getByLabelText('Mã')).toHaveAttribute('readonly');
  });

  it('ma sua duoc khi tao', () => {
    render(<VaiTroFormPage />);
    expect(screen.getByLabelText('Mã')).not.toHaveAttribute('readonly');
  });

  it('id la khong co trong du lieu mau thi noi ro, khong hien form rong', () => {
    render(<VaiTroFormPage id="vt-khong-co" />);
    expect(screen.getByRole('status')).toHaveTextContent('Không tìm thấy');
    expect(screen.queryByLabelText('Tên vai trò')).toBeNull();
  });

  it('nut Luu khoa mem va noi ra ly do', () => {
    render(<VaiTroFormPage />);
    const luu = screen.getByRole('button', { name: /Lưu/ });
    expect(luu).toBeDisabled();
    // Khoa MEM: van focus duoc de doc duoc ly do. `Nut` cua repo lam viec do qua lyDoKhoa.
    expect(luu).toHaveAccessibleDescription(/POST \/roles/);
  });

  it('co ba phan he chon duoc', () => {
    render(<VaiTroFormPage />);
    expect(screen.getAllByRole('option')).toHaveLength(PHAN_HE_CHON_DUOC.length);
  });
});
```

- [ ] **Bước 2: Chạy để thấy đỏ**

```bash
npx vitest run src/modules/user/pages/VaiTroFormPage.test.tsx
```

Expected: FAIL toàn bộ 7 ca.

- [ ] **Bước 3: Viết form**

- [ ] **Bước 4: Chạy để thấy xanh**

```bash
npx vitest run src/modules/user/pages/VaiTroFormPage.test.tsx
npm run lint
```

Expected: 7 ca PASS, lint sạch.

- [ ] **Bước 5: Commit**

```bash
git add src/modules/user/pages/VaiTroFormPage.tsx \
        src/modules/user/pages/VaiTroFormPage.module.css \
        src/modules/user/pages/VaiTroFormPage.test.tsx
git commit -m "feat(quan-tri): form tao va sua vai tro"
```

---

## Task 9: Mặt Gán vai trò

**Files:**
- Sửa: `src/modules/user/pages/UserListPage.tsx`, `UserListPage.test.tsx`, `.module.css`

Giữ nguyên phần chạy API thật: `useUserList` (`GET /users`), `useVaiTroKhaDung` (`GET /roles`),
và toàn bộ cách xử lỗi 403 / lỗi khác / hai ca rỗng. Bốn thay đổi:

1. Bỏ import `MAT_TAI_KHOAN`, thay bằng `MAT_PHAN_QUYEN` từ `@/app/mat-phan-quyen`.
2. `TieuDeTrang` đổi tiêu đề thành `Phân quyền` (cùng tên với mục thanh bên), mô tả
   `Ai đang giữ vai trò nào.`
3. Thêm cột **Phân vùng** giữa cột Người dùng và cột Vai trò, đọc từ trường phân vùng của
   `UserDTO`. Nếu `UserDTO` chưa có trường đó thì **bỏ cột này** và ghi một dòng lý do ngay
   trên `dauBang` - không bịa ra một cột rỗng.
4. Cột Thao tác trỏ `/quan-tri/phan-quyen/gan/:id` thay cho `/phan-quyen/:id`, chữ trên liên
   kết là `Gán vai trò` (cùng tên với tiêu đề màn đến ở task 10).

- [ ] **Bước 1: Sửa test trước**

Trong `UserListPage.test.tsx`: đổi mọi khẳng định về `MAT_TAI_KHOAN` và hai mặt phạm vi sang
`MAT_PHAN_QUYEN`; đổi mọi `href` mong đợi từ `/phan-quyen/...` sang `/quan-tri/phan-quyen/gan/...`.
Thêm một ca:

```tsx
it('dai tab danh dau mat Gan vai tro dang mo', () => {
  renderManHinh();
  expect(screen.getByRole('link', { current: 'page' })).toHaveAttribute(
    'href',
    '/quan-tri/phan-quyen/gan',
  );
});
```

- [ ] **Bước 2: Chạy để thấy đỏ**

```bash
npx vitest run src/modules/user/pages/UserListPage.test.tsx
```

Expected: FAIL, module `mat-tai-khoan` không tồn tại (đã xoá ở task 2).

- [ ] **Bước 3: Sửa màn**

- [ ] **Bước 4: Chạy để thấy xanh**

```bash
npx vitest run src/modules/user/pages/UserListPage.test.tsx
npm run lint
```

Expected: 18 ca PASS (17 cũ + 1 mới), lint sạch.

- [ ] **Bước 5: Commit**

```bash
git add src/modules/user/pages/UserListPage.tsx \
        src/modules/user/pages/UserListPage.module.css \
        src/modules/user/pages/UserListPage.test.tsx
git commit -m "feat(quan-tri): UserListPage thanh mat Gan vai tro"
```

---

## Task 10: Màn gán vai trò cho một người

**Files:**
- Sửa: `src/modules/user/pages/UserDetailPage.tsx`, `UserDetailPage.test.tsx`, `.module.css`

Màn này 1030 dòng và đang làm **hai việc**: gán vai trò, và gán phạm vi kho. Theo spec mục 6,
phạm vi kho lùi xuống cấp 2 - do quản trị module đặt trong phân hệ của họ - nên nó rời khỏi màn
này. Đây cũng là dịp file co lại còn một trách nhiệm.

Bốn thay đổi:

1. **Gỡ khối gán phạm vi kho**: bỏ `useKhoChonDuoc`, `useUserScopes`, `useUpdateUserScopes`,
   `DanhSachChon` của kho, và mọi state của phần đó.
2. **Giữ** `VE_CANH_BAO_MOC_VONG_DOI` nhưng viết lại một dòng: gỡ vai trò sẽ xoá phạm vi kho
   mà quản trị phân hệ đã cấp qua hàng vai trò đó. Người gán phải biết hệ quả ở phân hệ khác.
3. `TieuDeTrang` tiêu đề `Gán vai trò`, `quayLai` về `/quan-tri/phan-quyen/gan`.
4. Băng chọn người và thẻ ngữ cảnh (khối 0.3 và 0.4, đã dựng ở rc.39) **giữ nguyên** - chúng
   là thứ tốt nhất của màn này, và mọi liên kết trong băng đổi sang tiền tố mới.

**Không xoá** `use-user-scopes.ts`, `use-update-user-scopes.ts`, `use-kho-chon-duoc.ts` và
`getUserScopes` / `updateUserScopes` trong `user-api.ts`: cấp 2 sẽ dùng lại chúng. Chỉ gỡ chỗ
gọi. Nếu lint kêu import thừa thì gỡ import, không gỡ file.

- [ ] **Bước 1: Sửa test trước**

Trong `UserDetailPage.test.tsx` (33 ca): xoá các ca về phạm vi kho, đổi `href` mong đợi sang
tiền tố mới. Thêm hai ca:

```tsx
it('khong con khoi gan pham vi kho', () => {
  renderManHinh();
  expect(screen.queryByText(/Phạm vi kho/)).toBeNull();
});

it('van canh bao moc vong doi khi go vai tro', () => {
  renderManHinh();
  expect(screen.getByRole('status')).toHaveTextContent(/phạm vi/i);
});
```

- [ ] **Bước 2: Chạy để thấy đỏ**

```bash
npx vitest run src/modules/user/pages/UserDetailPage.test.tsx
```

Expected: FAIL ở hai ca mới.

- [ ] **Bước 3: Sửa màn**

- [ ] **Bước 4: Chạy để thấy xanh**

```bash
npx vitest run src/modules/user/pages/UserDetailPage.test.tsx
npm run lint
npx tsc --noEmit
```

Expected: PASS, lint sạch, không lỗi kiểu.

- [ ] **Bước 5: Commit**

```bash
git add src/modules/user/pages/UserDetailPage.tsx \
        src/modules/user/pages/UserDetailPage.module.css \
        src/modules/user/pages/UserDetailPage.test.tsx
git commit -m "feat(quan-tri): man gan vai tro con mot trach nhiem"
```

---

## Task 11: Mặt Phân vùng

**Files:**
- Sửa: `src/modules/company/pages/CompanyListPage.tsx`, `CompanyListPage.test.tsx`
- Create: `src/modules/company/pages/CompanyListPage.module.css`
- Sửa: `src/modules/company/pages/CompanyFormPage.tsx`, `CompanyFormPage.test.tsx`

Đây là món nợ ghi ở mục 4c spec cũ: màn duy nhất trong nhóm quản trị chưa đi qua hệ thiết kế -
vẫn `<h1>` trần và `<table>` trần với một `<Link>` chữ làm đường tạo. Giữ nguyên toàn bộ phần
API và phần tham số ở URL (`page`/`page_size`/`sort`/`q` sống ở URL, không `useState`).

Năm thay đổi:

1. `<h1>` trần → `TieuDeTrang` tiêu đề `Vùng dữ liệu`, mô tả `Chi nhánh và cách gom chúng
   thành vùng.`, hành động là `<Link to="/quan-tri/vung-du-lieu/phan-vung/moi">` bọc
   `Nut bien="chinh"` chữ `Thêm phân vùng`.
2. Thêm `DaiTab nhan="Mặt của vùng dữ liệu"` với ba `<Link>` từ `MAT_VUNG_DU_LIEU`.
3. `<table>` trần → `Bang soCot={5}` với `dangTai`, `dangLamMoi`, `rong`, `dauBang` - cùng
   khuôn với `WarehouseListPage`.
4. Thêm cột **Trạng thái** (`NhanTrangThai` tốt/tắt) giữa Số người dùng và Thao tác. Nếu
   `CompanyDTO` chưa có `is_active` thì **bỏ cột này**, đừng bịa.
5. Mọi `<Link>` trong `CompanyListPage` và `CompanyFormPage` đổi sang tiền tố
   `/quan-tri/vung-du-lieu/phan-vung`. Trong `CompanyFormPage`, cả đường `quayLai` lẫn đường
   `navigate` sau khi lưu thành công.

- [ ] **Bước 1: Sửa test trước**

Trong `CompanyListPage.test.tsx` (14 ca) và `CompanyFormPage.test.tsx` (10 ca): đổi mọi `href`
và mọi `navigate` mong đợi sang tiền tố mới. Thêm vào `CompanyListPage.test.tsx`:

```tsx
it('dai tab danh dau mat Phan vung dang mo', () => {
  renderManHinh();
  expect(screen.getByRole('link', { current: 'page' })).toHaveAttribute(
    'href',
    '/quan-tri/vung-du-lieu/phan-vung',
  );
});

it('co tieu de trang thay cho h1 tran', () => {
  renderManHinh();
  expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent('Vùng dữ liệu');
});
```

- [ ] **Bước 2: Chạy để thấy đỏ**

```bash
npx vitest run src/modules/company/pages/CompanyListPage.test.tsx src/modules/company/pages/CompanyFormPage.test.tsx
```

Expected: FAIL ở các ca `href` và hai ca mới.

- [ ] **Bước 3: Sửa hai màn**

Gọi skill `frontend-design-erp` trước khi viết CSS.

- [ ] **Bước 4: Chạy để thấy xanh**

```bash
npx vitest run src/modules/company/pages/CompanyListPage.test.tsx src/modules/company/pages/CompanyFormPage.test.tsx
npm run lint
```

Expected: 26 ca PASS, lint sạch.

- [ ] **Bước 5: Commit**

```bash
git add src/modules/company/pages/CompanyListPage.tsx \
        src/modules/company/pages/CompanyListPage.module.css \
        src/modules/company/pages/CompanyListPage.test.tsx \
        src/modules/company/pages/CompanyFormPage.tsx \
        src/modules/company/pages/CompanyFormPage.test.tsx
git commit -m "feat(quan-tri): mat Phan vung qua he thiet ke"
```

---

## Task 12: Mặt Vùng dữ liệu

**Files:**
- Sửa: `src/modules/company/pages/VungDuLieuListPage.tsx`, `.test.tsx`, `.module.css`
- Sửa: `src/modules/company/pages/VungDuLieuFormPage.tsx`

Màn hiện có đang hiểu vùng dữ liệu là **nhóm kho**. Viết lại theo mô hình đã chốt: **nhóm phân
vùng**. Bỏ hằng `VUNG_DU_LIEU` khai trong file, đọc `VUNG_DU_LIEU_MAU` từ
`../components/vung-du-lieu-mau`.

**Bố cục:** `TieuDeTrang` (`Vùng dữ liệu`, hành động `Tạo vùng dữ liệu` →
`/quan-tri/vung-du-lieu/moi`), `DaiTab` ba mặt, dải cảnh báo hai dòng nêu
`GET/POST /data-zones`, rồi `Bang soCot={4}`:

| Ô | Dựng bằng |
|---|---|
| Vùng | `v.ten` đậm, dòng dưới `v.mo_ta` chữ nhạt |
| Phân vùng trong vùng | Tối đa 3 `<MaBanGhi>{p.code}</MaBanGhi>`, dư thì `+N chi nhánh` |
| Đang gán cho | `<td className="so">{v.so_luot_gan}</td>` |
| Thao tác | `Sửa` (`<Link>` → `/quan-tri/vung-du-lieu/:id`), `Xoá` (`Nut` khoá mềm) |

Nút Xoá khoá mềm với **hai lý do khác nhau**, và phân biệt được là điểm chính của mặt này:

- `so_luot_gan > 0` → `lyDoKhoa="Còn N lượt gán quản trị module trỏ vào vùng này. Thu hồi
  hết rồi mới xoá được."`
- `so_luot_gan === 0` → `lyDoKhoa="Chưa có DELETE /data-zones/:id."`

`VungDuLieuFormPage` (322 dòng, đang mồ côi) chỉ cần ba sửa: đọc `PHAN_VUNG_MAU` thay cho
danh sách kho, `DanhSachChon` chọn phân vùng, và mọi đường `quayLai` trỏ `/quan-tri/vung-du-lieu`.
Nút Lưu khoá mềm, lý do nêu `POST /data-zones`.

- [ ] **Bước 1: Viết test đỏ**

Viết lại `VungDuLieuListPage.test.tsx` (7 ca cũ nói về kho, không giữ được):

```tsx
describe('VungDuLieuListPage', () => {
  it('do du mot dong cho moi vung mau', () => {
    render(<VungDuLieuListPage />);
    expect(screen.getAllByRole('row')).toHaveLength(VUNG_DU_LIEU_MAU.length + 1);
  });

  it('vung nhieu hon ba phan vung thi gap lai', () => {
    render(<VungDuLieuListPage />);
    // 'Toàn công ty' co 5 phan vung -> 3 chip + '+2 chi nhánh'
    expect(screen.getByText('+2 chi nhánh')).toBeInTheDocument();
  });

  it('vung con luot gan thi nut Xoa khoa vi ly do luot gan', () => {
    render(<VungDuLieuListPage />);
    const nut = screen.getAllByRole('button', { name: 'Xoá' });
    expect(nut[0]).toBeDisabled();
    expect(nut[0]).toHaveAccessibleDescription(/lượt gán/);
  });

  it('vung khong con luot gan thi nut Xoa khoa vi thieu endpoint', () => {
    render(<VungDuLieuListPage />);
    const nut = screen.getAllByRole('button', { name: 'Xoá' });
    expect(nut[3]).toHaveAccessibleDescription(/DELETE \/data-zones/);
  });

  it('noi ro dang chay du lieu mau', () => {
    render(<VungDuLieuListPage />);
    expect(screen.getByRole('status')).toHaveTextContent('/data-zones');
  });

  it('dai tab danh dau mat Vung du lieu dang mo', () => {
    render(<VungDuLieuListPage />);
    expect(screen.getByRole('link', { current: 'page' })).toHaveAttribute(
      'href',
      '/quan-tri/vung-du-lieu',
    );
  });

  it('moi dong co duong sang man sua', () => {
    render(<VungDuLieuListPage />);
    expect(screen.getAllByRole('link', { name: 'Sửa' })[0]).toHaveAttribute(
      'href',
      '/quan-tri/vung-du-lieu/vdl-01',
    );
  });
});
```

Tạo mới `VungDuLieuFormPage.test.tsx`:

```tsx
describe('VungDuLieuFormPage', () => {
  it('khong co id thi tieu de la Tao vung du lieu', () => {
    render(<VungDuLieuFormPage />);
    expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent('Tạo vùng dữ liệu');
  });

  it('co id thi do san ten vung', () => {
    render(<VungDuLieuFormPage id="vdl-01" />);
    expect(screen.getByLabelText('Tên vùng')).toHaveValue('Miền Bắc');
  });

  it('chon duoc dung so phan vung mau', () => {
    render(<VungDuLieuFormPage />);
    expect(screen.getAllByRole('checkbox')).toHaveLength(PHAN_VUNG_MAU.length);
  });

  it('id khong co thi noi ro, khong hien form rong', () => {
    render(<VungDuLieuFormPage id="vdl-khong-co" />);
    expect(screen.getByRole('status')).toHaveTextContent('Không tìm thấy');
  });

  it('nut Luu khoa mem va noi ra ly do', () => {
    render(<VungDuLieuFormPage />);
    const luu = screen.getByRole('button', { name: /Lưu/ });
    expect(luu).toBeDisabled();
    expect(luu).toHaveAccessibleDescription(/POST \/data-zones/);
  });
});
```

- [ ] **Bước 2: Chạy để thấy đỏ**

```bash
npx vitest run src/modules/company/pages/VungDuLieuListPage.test.tsx src/modules/company/pages/VungDuLieuFormPage.test.tsx
```

Expected: FAIL toàn bộ.

- [ ] **Bước 3: Viết lại hai màn**

- [ ] **Bước 4: Chạy để thấy xanh**

```bash
npx vitest run src/modules/company/pages/VungDuLieuListPage.test.tsx src/modules/company/pages/VungDuLieuFormPage.test.tsx
npm run lint
```

Expected: 12 ca PASS, lint sạch.

- [ ] **Bước 5: Commit**

```bash
git add src/modules/company/pages/VungDuLieuListPage.tsx \
        src/modules/company/pages/VungDuLieuListPage.module.css \
        src/modules/company/pages/VungDuLieuListPage.test.tsx \
        src/modules/company/pages/VungDuLieuFormPage.tsx \
        src/modules/company/pages/VungDuLieuFormPage.test.tsx
git commit -m "feat(quan-tri): vung du lieu la nhom phan vung, khong phai nhom kho"
```

---

## Task 13: Mặt Gán quản trị module

**Files:**
- Sửa: `src/modules/company/pages/GanQuanTriListPage.tsx`
- Create: `GanQuanTriListPage.module.css`, `GanQuanTriListPage.test.tsx`

**Bố cục:** `TieuDeTrang` (`Vùng dữ liệu`, hành động `Gán quản trị` →
`/quan-tri/vung-du-lieu/gan/moi`), `DaiTab` ba mặt, dải cảnh báo hai dòng nêu
`GET/POST /module-admins`, rồi `Bang soCot={5}`:

| Ô | Dựng bằng |
|---|---|
| Người dùng | `g.ho_ten` đậm, dòng dưới `g.email` chữ nhạt |
| Phân hệ quản trị | `<NhanTrangThai sac="trung-tinh">{g.nhan_phan_he}</NhanTrangThai>` |
| Vùng dữ liệu | `g.ten_vung`, dòng dưới `{g.so_phan_vung} phân vùng` |
| Trạng thái | `hieu-luc` → `sac="tot"` chữ `Hiệu lực`; `da-thu-hoi` → `sac="tat"` chữ `Đã thu hồi` |
| Thao tác | `Sửa` (`<Link>` → `/quan-tri/vung-du-lieu/gan/:id`), `Thu hồi` (`Nut` khoá mềm) |

Dòng đã thu hồi: nút `Thu hồi` khoá mềm với lý do `Lượt gán này đã thu hồi rồi.` Dòng còn hiệu
lực: lý do `Chưa có DELETE /module-admins/:id.`

- [ ] **Bước 1: Viết test đỏ**

```tsx
describe('GanQuanTriListPage', () => {
  it('do du mot dong cho moi luot gan mau', () => {
    render(<GanQuanTriListPage />);
    expect(screen.getAllByRole('row')).toHaveLength(GAN_QUAN_TRI_MAU.length + 1);
  });

  it('dong da thu hoi mang sac tat', () => {
    const { container } = render(<GanQuanTriListPage />);
    expect(container.querySelectorAll('[data-sac="tat"]')).toHaveLength(1);
  });

  it('dong da thu hoi khoa nut voi ly do khac', () => {
    render(<GanQuanTriListPage />);
    const nut = screen.getAllByRole('button', { name: 'Thu hồi' });
    expect(nut[3]).toHaveAccessibleDescription(/đã thu hồi rồi/);
    expect(nut[0]).toHaveAccessibleDescription(/DELETE \/module-admins/);
  });

  it('moi dong noi ro vung gom bao nhieu phan vung', () => {
    render(<GanQuanTriListPage />);
    expect(screen.getAllByText('3 phân vùng')).toHaveLength(2);
  });

  it('noi ro dang chay du lieu mau', () => {
    render(<GanQuanTriListPage />);
    expect(screen.getByRole('status')).toHaveTextContent('/module-admins');
  });

  it('dai tab danh dau mat Gan quan tri module dang mo', () => {
    render(<GanQuanTriListPage />);
    expect(screen.getByRole('link', { current: 'page' })).toHaveAttribute(
      'href',
      '/quan-tri/vung-du-lieu/gan',
    );
  });
});
```

- [ ] **Bước 2: Chạy để thấy đỏ**

```bash
npx vitest run src/modules/company/pages/GanQuanTriListPage.test.tsx
```

Expected: FAIL toàn bộ 6 ca.

- [ ] **Bước 3: Viết màn**

- [ ] **Bước 4: Chạy để thấy xanh**

```bash
npx vitest run src/modules/company/pages/GanQuanTriListPage.test.tsx
npm run lint
```

Expected: 6 ca PASS, lint sạch.

- [ ] **Bước 5: Commit**

```bash
git add src/modules/company/pages/GanQuanTriListPage.tsx \
        src/modules/company/pages/GanQuanTriListPage.module.css \
        src/modules/company/pages/GanQuanTriListPage.test.tsx
git commit -m "feat(quan-tri): mat Gan quan tri module"
```

---

## Task 14: Form gán quản trị module

**Files:**
- Sửa: `src/modules/company/pages/GanQuanTriFormPage.tsx`
- Create: `GanQuanTriFormPage.module.css`, `GanQuanTriFormPage.test.tsx`

**Bố cục:** `TieuDeTrang` (`Gán quản trị` / `Sửa lượt gán`, `quayLai` về
`/quan-tri/vung-du-lieu/gan`), dải cảnh báo hai dòng, form rộng `--rong-form`:

| Trường | Kiểu | Nguồn |
|---|---|---|
| Người dùng | select | `GAN_QUAN_TRI_MAU` gom theo `user_id` (dữ liệu mẫu; ngày nối API thì là `GET /users`) |
| Phân hệ quản trị | select | `PHAN_HE_CHON_DUOC` từ `@/modules/user/...`? **Không** - import chéo module là phá C-TS-01. Khai lại danh sách hai phần tử `inventory`/`machine` ngay trong `gan-quan-tri-mau.ts` |
| Vùng dữ liệu | select | `VUNG_DU_LIEU_MAU`, nhãn là `ten` kèm `({so phần tử} phân vùng)` |

Nút `Lưu` khoá mềm, lý do nêu `POST /module-admins`. Nút `Huỷ` là `<Link>` về mặt danh sách.

**Việc thêm ở bước này:** thêm hằng `PHAN_HE_QUAN_TRI_DUOC` vào
`src/modules/company/components/gan-quan-tri-mau.ts`:

```ts
// Khai lại ở đây thay vì import từ module `user`: C-TS-01 cấm một module với sang
// `components/` của module khác, và cửa duy nhất là `api/`. Hai phần tử, không phải ba -
// phân hệ 'auth' không có quản trị module, nó CHÍNH LÀ màn này.
export const PHAN_HE_QUAN_TRI_DUOC: ReadonlyArray<{ ma: string; nhan: string }> = [
  { ma: 'inventory', nhan: 'Kho vận' },
  { ma: 'machine', nhan: 'Thiết bị' },
];
```

- [ ] **Bước 1: Viết test đỏ**

```tsx
describe('GanQuanTriFormPage', () => {
  it('khong co id thi tieu de la Gan quan tri', () => {
    render(<GanQuanTriFormPage />);
    expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent('Gán quản trị');
  });

  it('co id thi do san vung da chon', () => {
    render(<GanQuanTriFormPage id="g-01" />);
    expect(screen.getByLabelText('Vùng dữ liệu')).toHaveValue('vdl-01');
  });

  it('chi co hai phan he quan tri duoc', () => {
    render(<GanQuanTriFormPage />);
    const chon = screen.getByLabelText('Phân hệ quản trị');
    expect(chon.querySelectorAll('option')).toHaveLength(PHAN_HE_QUAN_TRI_DUOC.length);
  });

  it('id khong co thi noi ro', () => {
    render(<GanQuanTriFormPage id="g-khong-co" />);
    expect(screen.getByRole('status')).toHaveTextContent('Không tìm thấy');
  });

  it('nut Luu khoa mem va noi ra ly do', () => {
    render(<GanQuanTriFormPage />);
    const luu = screen.getByRole('button', { name: /Lưu/ });
    expect(luu).toBeDisabled();
    expect(luu).toHaveAccessibleDescription(/POST \/module-admins/);
  });
});
```

- [ ] **Bước 2: Chạy để thấy đỏ**

```bash
npx vitest run src/modules/company/pages/GanQuanTriFormPage.test.tsx
```

Expected: FAIL toàn bộ 5 ca.

- [ ] **Bước 3: Viết form và thêm hằng**

- [ ] **Bước 4: Chạy để thấy xanh**

```bash
npx vitest run src/modules/company/pages/GanQuanTriFormPage.test.tsx
npm run lint
```

Expected: 5 ca PASS, lint sạch.

- [ ] **Bước 5: Commit**

```bash
git add src/modules/company/pages/GanQuanTriFormPage.tsx \
        src/modules/company/pages/GanQuanTriFormPage.module.css \
        src/modules/company/pages/GanQuanTriFormPage.test.tsx \
        src/modules/company/components/gan-quan-tri-mau.ts
git commit -m "feat(quan-tri): form gan quan tri module"
```

---

## Task 15: Chốt bằng máy

**Files:** `frontend-erp/arch/LEVELS.md` có thể lệch vì đã thêm và xoá file.

- [ ] **Bước 1: Bốn lệnh phải sạch**

```bash
cd "d:/My project web/erp/frontend-erp"
npm test 2>&1 | tail -20
npm run lint
npm run arch
node kiem-giao-dien.mjs
```

- [ ] **Bước 2: Cập nhật golden nếu `arch` lệch**

```bash
npm run arch:update
git diff --stat arch/LEVELS.md
```

`arch:update` **chạy được** ở `frontend-erp` (khác `backend-erp`, xem `MEMORY.md`). Đọc diff
trước khi thêm: nó phải chỉ chứa các file vừa thêm và vừa xoá, không chứa gì khác.

- [ ] **Bước 3: Không còn tham chiếu đường dẫn cũ**

```bash
grep -rn "'/phan-quyen\|'/phan-vung\|/quan-tri/bo-nhiem\|/quan-tri/tai-khoan\|'/nguoi-dung" src/ --include=*.ts --include=*.tsx
```

Expected: không dòng nào ngoài khối ghi chú. Còn dòng code nào là còn một ngõ cụt.

- [ ] **Bước 4: Commit**

```bash
git add arch/LEVELS.md
git commit -m "chore(quan-tri): cap nhat golden arch sau dot hai man"
```

---

## Task 16: Chốt bằng mắt trên máy dev

Bốn lệnh xanh **không** thay được một lượt soi thật. Lượt soi trước đợt này tìm ra hai lỗi mà
1050 test không bắt được (cột tràn 11px, dải cảnh báo cao 180px).

- [ ] **Bước 1: Đẩy nhánh**

```bash
gh auth switch --user hanhtv106
git push -u origin feat/module-quan-tri-hai-man
```

- [ ] **Bước 2: Deploy nhánh lên dev**

Gọi skill `deploy-rc`. Đợt giao diện **deploy nhánh, không tag rc** - chỉ tag một rc lúc chốt.
Nhánh phải có mặt ở cả ba repo `infra-erp`/`backend-erp`/`frontend-erp`; hai repo kia không đổi
gì nên đẩy nhánh cùng tên từ `main` của chúng.

- [ ] **Bước 3: Soi bằng mắt**

Gọi skill `agent-browser`. Máy dev chạy **HTTP thuần**, nên phải tắt `HttpsFirstBalancedMode`
mới vào được; `--args` tách theo dấu phẩy.

Đăng nhập bằng `qa-admin`. Chín đường phải đi được:

1. Thanh bên ứng dụng Quản trị hệ thống hiện **đúng hai mục**.
2. `/quan-tri/phan-quyen` - bảng vai trò đủ 5 dòng, cột Thao tác **không tràn**.
3. Bấm `Tạo vai trò` → form mở, nút Lưu khoá mềm và **focus được để đọc lý do**.
4. Bấm tab `Gán vai trò` → danh sách người dùng thật hiện.
5. Bấm một dòng → màn gán vai trò, tick một vai trò, `Lưu` chạy thật (đây là mặt chạy API).
6. `/quan-tri/vung-du-lieu/phan-vung` - bảng phân vùng thật, tạo một phân vùng chạy thật.
7. Tab `Vùng dữ liệu` - vùng `Toàn công ty` hiện `+2 chi nhánh`, nút Xoá của `Nhà máy` nói
   lý do khác nút Xoá của `Miền Bắc`.
8. Tab `Gán quản trị module` - dòng `Phạm Hồng Sơn` hiện `Đã thu hồi`.
9. Mọi dải cảnh báo **cao tối đa hai dòng**, bảng không bị đẩy xuống dưới nếp gấp.

`qa-admin` có phải quản trị hệ thống không thì kiểm ngay ở bước 1. Không phải thì hai mục sẽ
ẩn - lúc đó dùng tài khoản khác hoặc cấp cờ, và **ghi lại** là chưa kiểm được nhánh hiện.

- [ ] **Bước 4: Ghi bằng chứng**

Viết `docs-erp/99-meta/my-specs/2026-08-XX-ban-giao-module-quan-tri.md` - dùng ngày thật lúc
làm - gồm: số test xanh, ảnh chụp hoặc mô tả chín đường trên, và mọi lỗi mắt bắt được cùng cách
đã chữa. Commit vào `docs-erp`.

- [ ] **Bước 5: Gộp về `main`**

Gọi skill `superpowers:requesting-code-review` trước. Xong review thì gọi
`superpowers:finishing-a-development-branch`. Nhánh bắt buộc, PR tuỳ chọn; đợt nhỏ gộp dưới
máy rồi chờ CI trên `main` mới tag.

---

## Việc backend còn nợ, không thuộc kế hoạch này

Ba mặt còn chạy dữ liệu giả sau đợt này. Đợt sau cần, theo thứ tự:

1. `GET /roles` trả thêm `phan_he`, `so_nguoi_giu`, `is_active`; thêm `POST`, `PATCH`,
   `DELETE /roles`.
2. Bảng `data_zones` + `data_zone_companies`, kèm `GET/POST/PATCH/DELETE /data-zones`.
3. Bảng `module_admins`, kèm `GET/POST/PATCH/DELETE /module-admins`.

Mỗi việc cần một ADR vì cả ba chạm mô hình quyền. Việc 2 và 3 chạm cả `scope_service.go`.
