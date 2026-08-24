# Spec: tách màn phân quyền thành hai cấp

**Ngày:** 2026-08-24
**Trạng thái:** đã chốt hướng, **chưa thi công** — hai việc backend phải xong trước.
**Mockup:** `erp/mockup-erp/cap1-quan-tri-he-thong.html`, `erp/mockup-erp/cap2-phan-quyen-phan-he.html`
(mockup nằm ngoài git, xem `MEMORY.md` mục "Skill và mockup nằm ngoài git").

## 1. Vì sao tách

Hôm nay có đúng một màn `/quan-tri/phan-quyen`, và nó trộn hai việc thuộc hai người khác nhau:
việc của quản trị hệ thống (dựng chi nhánh, tạo tài khoản, bổ nhiệm trưởng phòng) và việc của
trưởng phòng (mở quyền Thêm/Sửa/Xoá/Duyệt cho nhân viên của mình). Hai người này không bao giờ
ngồi cùng một lúc, và trộn vào một màn nghĩa là ai mở ra cũng thấy quá nửa màn không phải việc
của mình.

## 2. Hai cấp

### Cấp 1 — Quản trị hệ thống

- **Ai:** người mang cờ `users.is_system_admin` → vai trò dẫn xuất `quan_tri_he_thong`.
- **Vào từ:** ứng dụng "Quản trị hệ thống" trong lưới ứng dụng.
- **Đứng ngoài mọi phân vùng** (ADR-0019 mục 5).
- **Ba tab:** Phân vùng (chi nhánh) · Tài khoản · Bổ nhiệm quản trị phân hệ.
- **Đơn vị một dòng:** một lượt bổ nhiệm = (người × chi nhánh × phân hệ × phạm vi dữ liệu).

### Cấp 2 — Admin phân hệ

- **Ai:** người mang `<module>.admin` của đúng phân hệ đó (`inventory.admin`, `machine.admin`,
  `auth.admin`) — ADR-0021.
- **Vào từ:** **thanh bên của chính phân hệ đó**, nhóm "Quản trị phân hệ" ở dưới cùng. Mục này
  chỉ hiện khi người đăng nhập mang vai trò tương ứng.
- **Ba tab:** Ma trận quyền `<phân hệ>` · Nhân sự phân hệ · Phạm vi kho.
- **Đơn vị một dòng:** một trang chức năng × năm hành động (Xem / Thêm / Sửa / Xoá / Duyệt).

### Ba thứ cấp 2 KHÔNG được vẽ

Vẽ ra là nói dối về quyền, và cả đội sẽ tưởng tính năng đã có:

1. **Chỉ một thẻ phân hệ.** Một `inventory.admin` không cấu hình được phân hệ khác.
2. **Vai trò ngoài phân hệ hiện mờ, không sửa được** — hiện dạng "Xem thiết bị · ngoài phân hệ".
3. **Không có nút "Tạo vai trò".** Bảng `roles` **đã có** (ADR-0023 đưa vai trò xuống
   database, thay ADR-0010), nhưng **đường ghi tập quyền chưa có** — đợt 2b. Đường ghi duy
   nhất vào `role_permissions` hôm nay là bộ nạp mặc định lúc mở phân vùng (ADR-0023 mục 11).

### Ma trận quyền chưa dựng được — đính chính

Bản đầu của spec này viết "màn cấp 2 dựng được ngay". Sai một nửa. Kiểm lại endpoint:

- `GET /roles` trả **đúng hai trường** `{ma, nhan}`. `frontend-erp/src/modules/user/api/user-api.ts:110`
  ghi rõ backend **cố ý** không trả tập permission, để câu hỏi "người xem có gán được vai trò
  này không" do một `403` thật trả lời chứ không do màn hình tự đối chiếu (C-TS-06).
- Không có endpoint nào liệt kê **trang chức năng** của một phân hệ.
- Không có đường ghi `role_permissions`.

Nên ma trận trang × hành động trong mockup cấp 2 là **thứ chờ đợt 2b**, không phải thứ dựng
được hôm nay. Nó cần hai endpoint mới ngoài đợt 2b: liệt kê trang chức năng, và đọc/ghi tập
quyền của một vai trò.

### Thứ dựng được ngay trên endpoint đang chạy

| Việc | Endpoint |
|---|---|
| Danh sách nhân sự | `GET /users` |
| Danh mục vai trò | `GET /roles` |
| Gán vai trò cho một người | `GET \| PUT /users/:id/roles` |
| Gán phạm vi kho cho một người | `GET \| PUT /users/:id/scopes` |

Bốn đường này đủ cho một màn cấp 2 **rút gọn**: băng chọn người (0.3) → thẻ ngữ cảnh (0.4) →
một thẻ "Vai trò trong phân hệ" (danh sách ô chọn) → một thẻ "Phạm vi kho". Không có ma trận.
Đó là màn nên dựng trước.

## 3. Hai quyết định cần ADR

### 3.1 Chi nhánh = phân vùng

**Đã chốt:** mỗi chi nhánh (Trụ sở, CN-HN, CN-HCM, NM-TB) là một hàng `companies`.

**Điều kiện tiên quyết — ADR-0019 giai đoạn hai, chưa thi công:**

- Bỏ `uq_users_email_active(company_id, email)`, email unique toàn hệ thống.
- Dựng `user_companies` và `user_company_roles` (schema đã chốt sẵn ở ADR-0019 mục 3).
- Đăng nhập hai bước: token danh tính 5 phút → liệt kê phân vùng → chọn → token gắn phân vùng.
- Đường đổi phân vùng, kèm thu hồi refresh token của phân vùng cũ.

**Chưa xong bước đó thì:** một người làm cả Hà Nội lẫn HCM phải có **hai tài khoản, hai mật
khẩu**. Đây là hệ quả đã được nêu và người quyết đã chấp nhận.

**Hệ quả nghiệp vụ đã chấp nhận:** dữ liệu giữa các chi nhánh không lẫn nhau, nên không có báo
cáo hợp nhất toàn công ty, và chuyển kho giữa hai chi nhánh không còn là một chuyển động kho
thường. Ngày cần hợp nhất thì đó là một ADR mới.

### 3.2 Mở quyền cho cấp 1

**Đã chốt:** `quan_tri_he_thong` sẽ tạo được tài khoản và bổ nhiệm được admin phân hệ.

Hôm nay nó giữ **đúng năm quyền** `auth.company_*` (ADR-0019 mục 5), nên chưa làm được. ADR mở
đường phải trả lời được rào của ADR-0029 mục "Nợ để lại":

> Điều kiện để ADR-0029 đứng vững: `auth.admin` không bao giờ được cấp một mã `auth.company_*`.

Tức là ADR mới đi **một chiều**: thêm `auth.user_*` cho `quan_tri_he_thong`, và giữ nguyên hàng
rào chiều ngược lại. Phải kèm một test khoá tính chất đó lại, vì hôm nay nó chỉ được giữ bởi nội
dung của bảng quyền chứ không bởi một luật (ADR-0029 mục Mất).

## 4. Thứ tự thi công

1. ADR cho 3.2 (rẻ, không chạm schema) → mở màn cấp 1 với hai tab Phân vùng + Nhật ký.
2. ADR-0019 giai đoạn hai (đắt, chạm luồng đăng nhập) → mở tab Tài khoản và Bổ nhiệm.
3. Màn cấp 2 **rút gọn** (vai trò + phạm vi kho, không ma trận) — không phụ thuộc hai việc
   trên, dựng được ngay trên bốn endpoint đang chạy.
4. Đợt 2b (CRUD `role_permissions`) + hai endpoint mới (liệt kê trang chức năng, đọc/ghi tập
   quyền của một vai trò) → khi đó mới mở được **ma trận trang × hành động**.

Nên bắt đầu bằng **bước 3**: nó là phần duy nhất chạy được hôm nay, và nó là màn mà trưởng kho
dùng hằng ngày.

## 4b. Đã dựng tới đâu (2026-08-24, `v0.1.0-rc.39`)

**Đã vào code:**

- Băng chọn người (khối 0.3) và thẻ ngữ cảnh (khối 0.4) trên `/phan-quyen/:id` — chuyển sang
  cấu hình cho người khác mà không phải quay về danh sách.
- Mục **"Phân quyền phân hệ"** trên thanh bên của ứng dụng Kho vận, **không** mang cờ ẩn theo
  vai trò: luật vỏ ứng dụng cấm ẩn mục theo role vì ẩn là *đoán*. Mục hiện cho mọi người dùng
  Kho vận; ai không có `auth.user_list` nhận `403` và màn đến nói tử tế, có `request_id`.
- Danh tính người rời khỏi dải đầu trang, vì thẻ ngữ cảnh đã nói đủ ba mẩu đó. Dải đầu nay
  mang **tên màn** (`Gán vai trò và phạm vi`) — đúng chữ trên liên kết đã dẫn tới đây, nên
  nút bấm và màn đến gọi cùng một tên cho cùng một việc.

**Lỗ còn lại, và nó chạm đúng mục đích của mục 2 ở trên:** bấm mục mới thì vỏ ứng dụng chuyển
sang "Quản trị hệ thống", tức người dùng **bị đẩy ra khỏi phân hệ đang làm**. Nguyên nhân là
bất biến "đường dẫn của hai ứng dụng không giao nhau" (`src/app/ung-dung.test.ts`): không thể
cho `/phan-quyen` thuộc cả `inventory` lẫn ứng dụng quản trị.

**Đã cân và cố ý KHÔNG chữa bằng một địa chỉ thứ hai** (kiểu `/kho-van/phan-quyen` render cùng
`UserListPage`). Nó chỉ chữa được cú bấm đầu: từ đó bấm một dòng trong bảng vẫn đi tới
`/phan-quyen/:id` và vẫn bị đẩy ra. Hai URL cho cùng một màn, không biết URL nào là chuẩn, mà
chỉ đi được nửa đường — đắt hơn phần thu được.

Đường ra thật cần một trong hai quyết định, và cả hai đều lớn hơn một PR giao diện:

1. **Cấp 2 có màn riêng của phân hệ**, không dùng lại `/phan-quyen`. Lúc đó nó chỉ liệt kê
   nhân sự có vai trò thuộc `inventory` và chỉ sửa được vai trò của phân hệ đó — đúng tinh
   thần cấp 2, nhưng cần endpoint lọc theo module mà `GET /users` chưa có.
2. **Vỏ ứng dụng cho một màn thuộc nhiều ứng dụng**, tức bỏ bất biến hiện tại và thay bằng
   một quy tắc "ứng dụng đang mở" mang theo trạng thái điều hướng.

## 4c. Vỏ giao diện đã dựng trước (2026-08-24, chưa nối API)

Đã dựng **vỏ giao diện** cho ba màn còn chờ backend. Cả ba chạy trên **dữ liệu mẫu khai
trong chính file page**, và cả ba đều mang một dải `BangThongBao` sắc `canh-bao` nói rõ điều
đó cùng tên endpoint còn thiếu. Mọi nút ghi đều khoá mềm kèm `lyDoKhoa` — không có cú bấm nào
bị nuốt im lặng.

| Màn | Đường dẫn | File |
|---|---|---|
| Cấp 1 · Tài khoản | `/quan-tri/tai-khoan` | `modules/user/pages/TaiKhoanListPage.tsx` |
| Cấp 1 · Bổ nhiệm quản trị phân hệ | `/quan-tri/bo-nhiem` | `modules/user/pages/BoNhiemListPage.tsx` |
| Cấp 2 · Ma trận quyền | `/phan-quyen/:id/ma-tran` | `modules/user/pages/MaTranQuyenPage.tsx` |

Kèm theo:

- `shared/components/DaiTab/` — khối 0.2 của `khuon-man-hinh.md`, dải **liên kết** chứ không
  phải `role="tablist"`: mỗi mặt có địa chỉ riêng nên mở tab mới, copy địa chỉ và nút Back
  đều phải chạy. Người gọi truyền `<Link>` vào, cùng lối `quayLai` của `TieuDeTrang`.
- `app/tab-quan-tri.ts` — ba mặt của màn cấp 1. Nằm ở `app/` vì ba mặt thuộc hai module khác
  nhau, không module nào được quyền giữ danh sách (C-TS-01).
- Ma trận cấp 2 lấy **danh tính thật** từ `GET /users/:id` cho thẻ ngữ cảnh; chỉ phần ma trận
  là dữ liệu mẫu. Cuộn giữa bảng quyền vẫn phải trả lời được "đang sửa quyền của ai".
- Hai mục điều hướng mới mang cờ `chiQuanTriHeThong`, và hai nét vẽ mới `the-tai-khoan`,
  `huy-hieu`.

**Đã soi bằng mắt trên máy dev, và lượt soi đó tìm ra hai lỗi mà 1050 test không bắt được** —
đúng chỗ mà mục "Soi trước không thay được chạy thật" đã nói:

1. **Cột thao tác màn Tài khoản tràn 11px**, nút "Vô hiệu hoá" bị khung thẻ cắt mất chữ cuối.
   Hai nút 40px + 88px cộng khe `--gian-2` vừa đúng 136px, tức đúng 14% của bảng 974px. Cả
   hai nút vẫn nằm trong DOM nên mọi test vẫn xanh. Cột lên 18%, `min-width` lên 860px.
2. **Dải cảnh báo cao 120-180px** ở cả hai màn cấp 1, đẩy bảng xuống dưới nếp gấp ở *mọi* lần
   mở màn trong khi nội dung là chuyện đọc đúng một lần. Rút xuống hai dòng, giữ hai mã quan
   trọng nhất và thêm đường tra về chính spec này.

Bằng chứng của máy: `npm test` 1050 xanh, `npm run lint` sạch, `npm run arch` khớp golden,
`kiem-giao-dien.mjs` sạch. Bằng chứng của mắt: `v0.1.0-rc.40` trên `103.179.172.110`, ba màn
mở bằng `qa-admin`, và ba đường bấm đã thử thật trên màn ma trận (mẫu nhanh "Khoá hết" đưa 8
ô tích về 0, "Hoàn tác" đưa lại đúng 8, nút thu gọn đổi `aria-expanded` và tháo bảng khỏi
DOM). Còn nợ: `qa-admin` không phải quản trị hệ thống nên chỉ kiểm được nhánh ẩn của hai mục
điều hướng cấp 1, không kiểm được nhánh hiện.

**Nợ để lại, cố ý:** `CompanyListPage` (mặt `/phan-vung` của cấp 1) chưa mang dải tab, vì nó
là màn duy nhất trong ba mặt còn chưa đi qua hệ thiết kế — vẫn là `<h1>` trần với một `<Link>`
chữ làm đường tạo. Đường về từ mặt đó là thanh điều hướng bên nên không có ngõ cụt.

## 4d. Đính chính bố cục cấp 1: ba tab thành ba mục, và một mặt (2026-08-24, rc.41)

Mục 2 ở trên viết cấp 1 có **ba tab** Phân vùng · Tài khoản · Bổ nhiệm. Dựng ra rồi nhìn thanh
bên thật thì hỏng theo hai đường, và người dùng đọc ra ngay từ ảnh chụp: "bốn trang này có vẻ
đang bị trùng nhau".

1. **"Phân quyền" và "Tài khoản" cùng đổ bảng `users` ra**, chỉ khác cột. Màn "Tài khoản" thực
   ra là *tương lai* của màn Phân quyền sau ADR-0019 giai đoạn hai, không phải một màn thứ hai.
2. **Ba mặt vừa là dải tab vừa là ba mục thanh bên** - điều hướng nói cùng một thứ hai lần.
   `khuon-man-hinh.md` mục 0.2 nói dải tab chỉ dành cho các mặt của CÙNG một đối tượng; chiều
   ngược lại cũng đúng.

Bố cục đã sửa:

- **Thanh bên ba mục**, mỗi mục một đối tượng: Phân quyền (tài khoản của phân vùng đang mở) ·
  Quản trị phân vùng (chi nhánh) · Bổ nhiệm quản trị phân hệ (người × chi nhánh × phân hệ).
- **`/quan-tri/tai-khoan` thành mặt thứ hai của `/phan-quyen`**, vào bằng dải tab trên chính
  màn đó, đeo chip "Xem trước". Hai mặt khác nhau đúng một thứ: phạm vi. Danh sách hai mặt ở
  `modules/user/components/mat-tai-khoan.ts`.
- Màn Bổ nhiệm **bỏ dải tab**: nó là mục thanh bên độc lập, không phải mặt của màn nào.

**Tài khoản đăng nhập không chuyển sang phân hệ Nhân sự**, và đây là lý do để lần sau khỏi bàn
lại: một công nhân xưởng có hồ sơ nhân sự, hợp đồng, lương, mà cả đời không đăng nhập lần nào;
ngược lại tài khoản tích hợp và tài khoản thuê ngoài đăng nhập được mà không ứng với nhân viên
nào. Hai đối tượng khác nhau, chỉ trỏ vào nhau. Ngày dựng phân hệ Nhân sự, màn hồ sơ nhân viên
nằm ở đó và mang một liên kết sang tài khoản của người đó.

## 4e. Tên trên màn hình sau đợt đổi (rc.42)

| Mục bấm | Màn đến | Ghi chú |
|---|---|---|
| Tài khoản | `/phan-quyen`, tiêu đề "Tài khoản" | Hai tab chỉ nói PHẠM VI: "Trong phân vùng này" · "Mọi chi nhánh" (xem trước) |
| Phân vùng | `/phan-vung`, tiêu đề "Phân vùng" | Chữ "quản trị" đã nằm ở tên ứng dụng |
| Bổ nhiệm quản trị phân vùng | `/quan-tri/bo-nhiem` | Đổi theo yêu cầu người quyết |
| Tài khoản người dùng (từ Kho vận) | `/phan-quyen` | Cùng màn, đổi nhãn theo |

Luật rút ra: **mục bấm và tiêu đề màn đến gọi cùng một tên**, còn tab thì nói mặt/phạm vi chứ
không nhắc lại tên màn. Trước đợt này có ba chỗ phá luật đó cùng lúc.

**Một chỗ lệch cố ý để lại, cần quyết dứt điểm:** màn "Bổ nhiệm quản trị phân vùng" có cột
"Phân hệ quản trị" (Kho vận, Thiết bị, Kế toán). Một lượt bổ nhiệm vẫn là **người × chi nhánh
× phân hệ** (ADR-0021: `<module>.admin`), nên tên màn nay nói theo trục chi nhánh còn cột nói
theo trục phân hệ. Hai đường ra: hoặc tên màn quay về "phân hệ", hoặc đổi luôn mô hình để một
lượt bổ nhiệm là quản trị của cả một phân vùng - mà đó là một ADR, không phải một cái nhãn.

## 5. Chưa quyết

- Trạng thái "Chờ nhận" của một lượt bổ nhiệm (thấy trên mockup cấp 1) — chưa có trong mô hình.
  Hoặc bỏ, hoặc cần một cột trạng thái thật.
- Phạm vi dữ liệu của một admin phân hệ ("6 kho — miền Nam") hiện chỉ có dạng danh sách kho.
  Với Kế toán và Bán hàng thì không có "kho" để bám vào — chưa có lời giải.
