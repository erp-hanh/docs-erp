# Bàn giao — 2026-08-21, đợt làm lại cụm màn Phân quyền

Phiên này chạy song song với phiên đã viết `2026-08-21-ban-giao.md`. Đọc **cả hai**; file
kia nói về đợt vai trò theo module, file này nói về đợt giao diện tiếp sau nó.

## Đang ở đâu

`v0.1.0-rc.26` chạy trên dev (103.179.172.110), và nó **đã chứa toàn bộ việc của phiên
này** — kể cả `53c4189`.

Trạng thái ba repo lúc bàn giao:

| Repo | `main` | Có trong `rc.26` |
|---|---|---|
| `frontend-erp` | `53c4189` | có |
| `backend-erp` | `6dcb825` | có |
| `infra-erp` | `bae5b8b` | có |

`docs-erp` **đang ở nhánh `docs/context-tu-dien`, chưa merge về `main`**. Nhánh đó giữ
ADR-0022, ADR-0023, `CONTEXT.md` và sáu spec. Việc merge thuộc về phiên đã tạo nhánh, tôi
không tự làm.

## Đợt vừa xong

Điểm xuất phát: chủ dự án nói giao diện cụm màn quản trị người dùng "không thể chấp nhận
được".

**Gốc rễ không phải thiết kế sai.** `frontend-erp/src/shared/components/` **rỗng hoàn
toàn** — chỉ có một `.gitkeep`. Mọi màn tự viết `<table>`, `<nav>`, `<fieldset>` trần, và
`co-so.css` không có selector nào cho `[role="alert"]`, nên mọi thông điệp lỗi render y hệt
một đoạn văn thường.

Đã làm, đã merge, đã push:

1. **Mười component dùng chung** vào `shared/components/`: `Nut`, `MaBanGhi`,
   `NhanTrangThai`, `KhungXuong`, `TieuDeTrang`, `BangThongBao`, `ManRong`, `Bang`,
   `PhanTrang`, `DanhSachChon`.
2. **Viết lại `UserListPage`**: gộp email và họ tên thành một ô hai dòng, chip vai trò có
   nhãn, thêm cột trạng thái từ `is_active` (trước đó có trong DTO mà bảng không hiện),
   một liên kết thao tác thay hai, thêm ô sắp xếp, khung xương thay chữ "Đang tải...".
3. **Gộp hai màn gán quyền thành `UserDetailPage`** ở `/phan-quyen/:id`. Bốn đường cũ
   chuyển hướng.
4. **Đổi tên màn**: "Người dùng" → "Phân quyền", `/nguoi-dung` → `/phan-quyen`.
5. **Đưa "Quản trị phân vùng"** từ popover tài khoản sang thanh điều hướng ứng dụng Quản
   trị hệ thống.

Mốc lúc bàn giao: **801 test / 79 file pass**, `npm run lint` sạch, `npm run arch` khớp
golden, `kiem-giao-dien.mjs` sạch 157 file.

## Ba lỗi thật đã sửa, cả ba đều là mất dữ liệu im lặng

**1. `GET /warehouses` không đọc `isPending`/`isError`.** Bản cũ dùng `useQuery` inline rồi
`kho.data?.items ?? []`. Kho lỗi hoặc đang tải → mảng rỗng → màn hiện 0 ô chọn kèm câu
"Chưa chọn kho nào. Người này sẽ không thấy dòng nào ở màn kho." Người gán tin lời đó, bấm
Lưu, **xoá sạch phạm vi đang có**. Bản mới khoá nút Lưu và hiện lỗi kèm nút thử lại.

**2. Enter trong ô lọc gửi form bọc ngoài.** `DanhSachChon` nằm trong `<form>` của cả hai
khối. Implicit form submission bắn click lên nút submit đầu tiên. Bỏ tick một vai trò →
nút đổi thành "Lưu và xoá phạm vi" → gõ vài chữ vào ô lọc để tìm vai trò khác → lỡ tay
Enter → PUT ngay, không hỏi lại. **jsdom không mô phỏng ca này**, nên 782 test lúc đó
không nói gì về nó.

**3. Trang vượt quá số trang thành ngõ cụt.** `items.length === 0` gộp hai ca khác hẳn.
Nút Back khôi phục một URL `?page=5` cũ là đủ để rơi vào ca "trang ngoài khoảng", và màn
hiện "Chưa có người dùng nào" trong khi tiêu đề ngay trên ghi "47 người", rồi giấu cả thanh
lọc lẫn thanh phân trang.

## Thứ đã học được, không đọc lại từ code được

### Hai quyết định của tôi bị lật khi thi công

**`GET /roles` bị chặn quyền.** Tôi chốt ở vòng grill rằng nó là nguồn nhãn duy nhất và
`NHAN_VAI_TRO` ở `DropdownTaiKhoan.tsx` sẽ bị xoá. **Sai.** Endpoint đó kiểm
`auth.user_assign_roles` (`user_service.go:568`), và bốn trên tám vai trò không có quyền
đó — đúng các tài khoản nhà xưởng. Hợp đồng ấy còn bị khoá bằng
`TestE2EDanhMucVaiTroThieuQuyenTra403`. Làm theo là thủ kho mở popover của chính mình thấy
chip ghi `inventory.thu_kho`. Đường ra ở `2026-08-21-nhan-vai-tro-kem-auth-me-spec.md`.

Dùng `GET /roles` **trong màn `/phan-quyen`** thì đúng: người mở màn đó theo định nghĩa
phải có quyền ấy.

**"Vai trò là hằng trong code" đã hết đúng.** Tôi viện lý do đó để loại việc tách một màn
Vai trò riêng như MISA. Nhưng **ADR-0023 (Accepted 2026-08-21) đã lật tiền đề đó trước khi
tôi nói**: vai trò xuống database, thành dữ liệu cấp công ty do quản trị tự khai. Sau khi
thi công sẽ có một màn Vai trò thật — và điều đó làm tên "Phân quyền" cho màn hiện tại
đúng hơn, không kém đi.

### Hai lần "test xanh" không có nghĩa là code được canh

Vòng soi cuối chỉ ra hai dòng gánh việc mà không bài nào canh. Tôi **xoá thật rồi chạy**:
194 test vẫn xanh, cả hai lần.

- `ChuyenHuongChiTiet.tsx` phát `popstate`. `replaceState` một mình không đánh thức ai —
  `subscribeUrl` chỉ nghe `popstate`. Chín bài cũ chỉ đọc `location.pathname` và
  `history.length`, mà `replaceState` một mình thoả mãn cả hai.
- `use-update-user-roles.ts` làm mới cache phạm vi sau khi ghi vai trò.

Bài học chung: **một bài test đọc trạng thái cuối không khoá được cơ chế đưa tới trạng thái
đó.** Khi nghi ngờ, gỡ dòng ra và chạy.

### Bẫy vùng bấm tái sinh BA lần trong một ngày

`co-so.css` cấp `min-height` 32px chuột / 44px cảm ứng cho **`button, input, select`** —
không cấp cho `<a>`. Và bất cứ lớp đơn nào đặt `min-height` thấp hơn đều **thắng** vì độ
đặc hiệu cao hơn selector thẻ.

Ba nạn nhân trong ngày: `.nut-quen` ở màn đăng nhập (~19px, đã lên production dev),
`.lien-ket-thao-tac` ở bảng phân quyền (~20px), `.quay-lai` trong `TieuDeTrang` (~20px —
nguy nhất vì nó nằm trong component dùng chung nên sẽ lan ra mọi màn sau).

`kiem-giao-dien.mjs` **không bắt được** nhóm lỗi này. Chỉ mắt người đọc ra.

### Bốn phát hiện về phiên chạy song song

1. **Số rc bị phiên khác lấy mất — hai lần trong một buổi.** Lần đầu: tôi định tag
   `rc.22`, nó đã tồn tại, `rc.23` cũng vậy và họ đã deploy nó; bản của tôi thành `rc.24`.
   Lần hai: tôi tính `rc.25`, đi kiểm CI, quay lại thì cả `rc.25` lẫn `rc.26` đã có chủ —
   may là `rc.26` cuốn luôn commit của tôi nên không phải tag thêm.
   **Luôn `fetch --tags` rồi tính lại NGAY TRƯỚC khi tag**, đừng tính một lần rồi đi làm
   việc khác. Và trước khi tag, kiểm xem bản mới nhất đã chứa commit của mình chưa —
   `git merge-base --is-ancestor <sha> <tag>^{}` — để khỏi tag một bản thừa.
2. **Một thay đổi hạ tầng suýt xoá database dev.** `infra-erp` thêm volume đặt tên cho
   Postgres. Trước đó Postgres chạy trên **volume ẩn danh**, nên về lý thuyết lần đầu
   triển khai là một lần đổi chỗ chứa dữ liệu: database rỗng trên volume mới, dữ liệu cũ
   nằm lại trên volume cũ không còn được gắn. Tôi đếm trước (**7 người / 2 kho / 3 phạm vi
   / 21 dòng gán**), đếm lại sau: **đúng bằng nhau** — vì container đã được gắn sẵn
   `compose_erp_pgdata` từ trước bằng một lệnh chạy tay.
3. **Dữ liệu Postgres đổi chỗ HAI lần trong một ngày, cả hai lần đều nguyên.** Sáng:
   volume ẩn danh → volume đặt tên `compose_erp_pgdata`. Chiều (`rc.26`): volume → bind
   mount `/srv/erp/postgres`, kèm sao lưu định kỳ — trước đó máy dev **không có bản sao lưu
   nào**. Cả hai lần đều là ca "database rỗng trên chỗ chứa mới" nếu làm sai thứ tự. Đếm
   trước và sau mỗi lần: **7 / 2 / 3 / 21**, khớp cả ba lượt đo.
   Lệnh đếm, để lần sau khỏi nghĩ lại:
   ```
   docker exec compose-postgres-1 psql -U erp -d erp_dev -tAc "
     select 'users='||count(*) from users
     union all select 'warehouses='||count(*) from warehouses
     union all select 'scopes='||count(*) from user_company_role_scopes
     union all select 'roles_gan='||count(*) from user_company_roles;"
   ```
   Chú ý tên database là **`erp_dev`**, không phải `erp`.
4. **Container từng lệch với repo.** Lúc tôi kiểm, `/opt/erp/infra-erp` ở `rc.21` (compose
   cũ, không có volume đặt tên) trong khi container lại chạy volume đặt tên. Dấu vết của
   một lệnh chạy tay ngoài script deploy. Nó tự khỏi khi `rc.23` lên, nhưng kiểu lệch này
   làm câu "máy dev đang chạy chính xác cái gì" không trả lời được.

### Rà soát mockup: nhãn hạn sử dụng nói dối

Năm mockup cũ sạch cả bốn nhóm lỗi máy chấm được, nhưng ba trên năm gắn nhãn sai:
`dang-nhap.html` tự nhận "đã lên code" trong khi bản đã code là **v2**; `dang-nhap-v2.html`
— bản đang chạy — vẫn viết thì tương lai và treo hai câu hỏi đã quyết xong;
`luong-phan-vung.html` không có nhãn dù mục 1 đã lên code. Đã sửa cả bốn file.

`quan-tri-phan-quyen.html` đã **xoá** sau khi cứu ba luật nghiệp vụ ra
(`2026-08-21-luat-gan-vai-tro-spec.md`) — nó dạy bốn mã vai trò không tồn tại, hai câu sai
sự thật về backend, và một trường API bịa.

## Việc tiếp theo, theo thứ tự tôi đề nghị

1. ~~Đóng `rc.25`~~ — **xong, không cần làm gì.** Phiên song song tag `rc.25` và `rc.26`
   sau khi tôi push `53c4189`, nên `rc.26` cuốn luôn commit đó vào và đã chạy trên dev.
   Đã kiểm trên máy thật: đường quay lại của `TieuDeTrang` cao **32px** (trước ~20px).
2. **Merge nhánh `docs/context-tu-dien` của `docs-erp` về `main`.** ADR-0023 và sáu spec
   đang nằm ngoài `main`, nên người đọc `main` không thấy quyết định vai trò xuống
   database.
3. **Thi công ADR-0023.** Chưa có plan nào. Khi làm, gộp luôn hai spec cùng chạm
   `GET /roles`: `gan-duoc-tren-danh-muc-vai-tro` và `nhan-vai-tro-kem-auth-me`.
4. **Kiểm nốt nhánh "hiện" của mục Quản trị phân vùng trên máy thật.** Chỉ
   `admin@gmail.com` có `is_system_admin=true` và tôi không có mật khẩu; `qa-admin` không
   phải quản trị hệ thống nên chỉ kiểm được nhánh ẩn.
5. **Thêm luật vùng bấm cho `<a>` vào `kiem-giao-dien.mjs`**, hoặc vào
   `references/checklist.md` nếu máy không bắt được. Ba lần trong một ngày là đủ để nó
   thành một luật.

## Thứ không có trong repo mà phiên mới cần biết

- **Tài khoản thử trên dev**: `qa-admin@erp.test` (ba vai trò admin, **không** phải quản
  trị hệ thống) và `qa-thukho@erp.test`, mật khẩu `QaPhamVi!2026`, phân vùng `DEFAULT`.
  `admin@gmail.com` là quản trị hệ thống duy nhất, không ai biết mật khẩu.
- **Không xem được màn dev từ `localhost`**: backend không cho `localhost:5173` làm origin.
  Gọi curl thì được, từ trình duyệt là `Failed to fetch`. Muốn nhìn màn thật phải deploy
  một bản rc.
- **agent-browser chặn HTTP thuần**: phải mở kèm
  `--args "--disable-features=HttpsFirstBalancedMode,HttpsUpgrades"`.
- **Ba việc còn mở khác của cụm màn này**: `2026-08-21-tim-kiem-nguoi-dung-spec.md`,
  `2026-08-21-luat-gan-vai-tro-spec.md`, và hai spec ở mục 3 phía trên.
- **`mockup-erp/` và `.claude/skills/` không thuộc repo nào.** Gốc `erp/` không phải một
  git repo — mất là mất hẳn.
