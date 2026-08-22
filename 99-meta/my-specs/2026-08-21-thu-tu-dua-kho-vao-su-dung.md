# Thứ tự đưa module kho vào sử dụng

Trạng thái: **đã chốt**, chờ thi công. Quyết định thứ tự do tôi rà rồi tự quyết theo uỷ
quyền của chủ dự án ngày 2026-08-21.

Đích: một thủ kho thật ghi chuyển động thật trên `http://103.179.172.110/`.

## Câu phải quyết

ADR-0023 chuyển ánh xạ vai trò → quyền xuống database. Khối "tài khoản thủ kho thật + cấp
phạm vi kho" thì cần một vai trò được gán **ngay bây giờ**. Làm khối đó trên mô hình cũ rồi
đổi mô hình - có phải làm hai lần không?

## Rà soát

**Không.** Migration nâng cấp của ADR-0023 mục 10 bước 3 backfill `user_company_roles.role_id`
bằng `JOIN roles ON (roles.company_id, roles.code) = (ucr.company_id, ucr.role_code)`, và có
hậu điều kiện chặn `COMMIT` nếu còn hàng sống nào `role_id IS NULL`. Một dòng gán vai trò tạo
hôm nay **đi qua migration nguyên vẹn**.

Ca duy nhất mất dữ liệu trong migration đó là hàng **đã xoá mềm** trỏ tới một `role_code`
ngoài bộ bảy - tên vai trò thời trước ADR-0021. Tài khoản thủ kho tạo mới hôm nay không rơi
vào ca đó.

`user_company_role_scopes` **không đổi** theo ADR-0023, nên phạm vi kho đã cấp cũng nguyên vẹn.

Đường gán đã dùng được hôm nay, không phải dựng thêm: `PermRoleAssign` và `PermScopeAssign`
có thật ở `modules/inventory/module.go:128-129`, và frontend đã có màn người dùng
(`src/modules/user/pages/UserListPage.tsx`, `UserDetailPage.tsx`).

Vậy lo lắng "làm hai lần" mà chính tôi nêu ra là **sai**. Nó dựa trên giả định migration không
mang dữ liệu theo, và giả định đó không đúng với migration đã thiết kế.

## Quyết định

**Khối 2 làm ngay trên mô hình hiện có. Thi công ADR-0023 hoãn tới sau khi kho đã chạy.**

Ba lý do:

1. Không mất gì. Dòng gán vai trò và dòng cấp phạm vi kho đều sống sót qua migration.
2. ADR-0023 là thay đổi lớn: hai bảng mới, đổi khoá ngoại trên một bảng đang có dữ liệu, đổi
   nghĩa claim trong token, thêm một phép đối soát ở CI. Đặt nó **trước** ngày thủ kho ghi
   dòng đầu tiên là đặt một migration phân quyền rủi ro chắn ngang thứ duy nhất có giá trị
   thật lúc này.
3. Hoãn không làm nó đắt thêm. Thứ phình theo thời gian ở hệ này là **chuyển động kho**, không
   phải số dòng gán vai trò - hôm nay một công ty với vài tài khoản, sau khi chạy vài tháng
   vẫn thế. Migration không khó lên vì đợi.

## Thứ tự chốt

| # | Khối | Trạng thái tài liệu |
|---|---|---|
| 1 | Volume đặt tên cho Postgres | xong, đã commit |
| 1b | Giới hạn tốc độ nginx cho `/api/v1/auth/login` | không cần spec, cấu hình nginx |
| 2 | Tài khoản thủ kho thật + cấp phạm vi kho | tạo bằng `bootstrap.sh` trên VPS; gán vai trò và phạm vi qua màn người dùng |
| 3 | Xoá mềm dòng chuyển động | `backend-erp/docs/superpowers/specs/2026-08-21-xoa-mem-chuyen-dong-design.md` |
| 4 | `POST /units` + hộp thoại thêm nhanh | `backend-erp/.../2026-08-21-them-don-vi-tinh-design.md`, ADR-0022 |
| 5 | **Tìm kiếm danh mục** | `backend-erp/.../2026-08-21-tim-kiem-danh-muc-design.md` + bản frontend cùng tên |
| 5b | Seed 14 đơn vị tính lên máy chạy thật | **XONG 2026-08-22** - 14 dòng `units`, 14 dòng audit `unit.created` |
| 6 | Script nạp tồn đầu kỳ | `infra-erp/docs/superpowers/specs/2026-08-21-nap-ton-dau-ky-design.md` |
| 7 | Sổ chuyển động tra được | spec + plan đã có, cả hai repo |
| 8 | Chuyển inventory sang bộ component dùng chung | **spec + plan cũ CHẾT Ở TIỀN ĐỀ, phải viết lại** |
| 9 | Thi công ADR-0023 | **chỉ có ADR, chưa có spec thi công** |
| 10 | Luật chặn sửa mã và xoá vật tư đã dùng | `backend-erp/.../2026-08-21-thu-kho-quan-ly-danh-muc-design.md` |

### Khối 5 thêm vào ngày 2026-08-21, và vì sao nó chặn

`MovementRecordForm.tsx:103-111` nạp danh mục vật tư với `page_size` bằng trần 100 rồi đổ
thẳng vào một thẻ `<select>`. Quy mô đã chốt là **vài trăm mã**. Nên hai phần ba danh mục
không chọn được, và thủ kho không ghi nổi chuyển động cho mã nào sắp sau mã thứ 100 - thao
tác chính của người dùng chính, hỏng ở đúng quy mô thật.

Đây chính là phương án tìm kiếm text đã bị hoãn ở vòng thiết kế đầu, khi nền còn là *chưa ai
dùng*. Nền đổi thì chỗ hoãn hết hiệu lực.

Xếp trước khối 6 vì script nạp sẽ tạo vài trăm mã, và ngay sau lần nạp thì ô chọn kia thành
vô dụng - nghiệm thu bằng tay sau khi nạp cũng cần tìm được mã.

Khối 3 đứng trước khối 6 là cố ý: lần nạp đầu tiên phải có đường lùi nếu file nguồn sai.

Khối 10 có thể chen bất cứ đâu sau khối 4; nó độc lập. Đặt cuối vì nó là luật bảo vệ, không
phải thứ chặn ai làm việc.

## Rủi ro đã chấp nhận, không nhắc lại

1. **HTTP trần qua Internet.** Mật khẩu thủ kho đi dạng chữ đọc được. Chủ dự án nghe rồi vẫn
   chọn đưa thẳng `http://103.179.172.110/`.
2. **Ca sổ kẹt không gỡ được bằng một lần xoá** - nhập thừa mà hàng đã xuất hết. Chốt giữ bất
   biến tồn không âm; lý do và đường mở lại ghi ở spec khối 3 mục 12.

### Sửa ngày 2026-08-22: mục "không sao lưu" đã hết đúng

Bản đầu của file này ghi "Không sao lưu... volume đặt tên nên `down -v` không còn xoá sạch".
**Sai cả hai vế**, và sai ngay hôm viết:

- `docker compose down -v` **vẫn** xoá được volume đặt tên. Chính chú thích trong
  `infra-erp/compose/dev.yml` nói điều đó.
- Trên máy chạy thật thì volume đặt tên **không được dùng**: `compose/dev-vps.yml` ghi đè nó
  bằng bind mount `/srv/erp/postgres`, cố ý, vì `down -v` và `system prune -v` không với tới
  một thư mục dưới `/srv`.
- Và **đã có sao lưu**: `infra-erp/scripts/sao-luu-dev.sh`.

Cái còn lại phải kiểm chứ không được cho là xong: cron gọi script đó đã cài chưa. Việc cài là
một dòng lệnh trong tài liệu, không có gì canh nó đã chạy. Kiểm bằng `crontab -l | grep sao-luu`
trong nghiệm thu ngày đi vào sử dụng.

### Rủi ro mới, chưa từng nêu: gán vai trò toàn phạm vi làm bốc hơi phạm vi đang cấp

Không phải lỗ hổng mô hình - vai trò cộng dồn là cách RBAC này hoạt động, và `inventory.admin`
giữ `warehouse_scope_all` là cố ý (ADR-0021 mục 2): người mở kho phải thấy kho mình vừa mở.

Chỗ đau là **màn hình không báo trước**. `shared/scope/resolver.go:57-60` trả toàn phạm vi ngay
khi `Can` thấy `warehouse_scope_all` ở **bất kỳ** vai trò nào của người đó, và
`modules/auth/internal/repository/scope_repository.go:77-83` join theo `user_id` chứ không lọc
`role_code` - nên phạm vi vốn đã hợp nhất theo người, từ trước ADR-0023. Phía frontend,
`src/modules/user/api/user-api.ts` chỉ có vị ngữ `phamViMatKhiGo` cho chiều **gỡ**; chiều
**thêm** không có vị ngữ nào, nên tick thêm một vai trò mang quyền toàn phạm vi diễn ra trong
im lặng.

Hệ quả cho đợt này: thủ kho được giới hạn kho A mà bị gán kiêm `inventory.admin` là ghi được
mọi kho, không gì báo. **Quyết định Q28 của đợt này không rơi vào bẫy đó** - ba quyền
`item_create` / `item_update` / `unit_create` được thêm vào **chính** vai trò
`inventory.thu_kho`, không kèm `warehouse_scope_all`. Bẫy chỉ sập nếu người thi công đi đường
tắt "gán thêm `inventory.admin` cho xong". Ghi ra đây để đường tắt đó không được chọn trong im
lặng.

Đường thứ ba, nếu sau này cần tách bạch hơn: dựng một vai trò `inventory.vat_tu` mang đúng các
quyền danh mục và **không** mang `warehouse_scope_all`. Trong mô hình vai trò theo module hiện
tại, đó là một khối trong `Bang()`, không migration, không đổi hợp đồng API nào.

## Cửa sổ không lùi được

Nạp tồn đầu kỳ và nghiệm thu phải xong **trước** khi giao máy cho thủ kho. Xoá mềm chịu đúng
phép kiểm tồn âm, nên chỉ lùi sạch được lần nạp khi chưa có dòng xuất nào ăn vào lượng vừa
nạp. Sau dòng ghi đầu tiên của thủ kho thì cửa sổ đó đóng.

## Sửa ngày 2026-08-22: khối 8 chết ở tiền đề

Spec và plan cũ (`frontend-erp/docs/superpowers/specs/2026-08-21-bo-component-dung-chung-design.md`
và plan cùng tên) mở đầu bằng "`src/shared/components/` chỉ có `.gitkeep`". Câu đó **đúng lúc rà
và sai lúc này**: trên `main` thư mục đó đã có **mười** component, dựng trong đợt phân quyền.

```
Bang  BangThongBao  DanhSachChon  KhungXuong  MaBanGhi
ManRong  NhanTrangThai  Nut  PhanTrang  TieuDeTrang
```

Gồm đúng bốn cái kế hoạch định đi rút. Và chữ ký thật khác hẳn thứ spec chốt:

| Component | Spec cũ chốt | Thật trên `main` |
|---|---|---|
| `BangThongBao` | `error: unknown`, tự lấy mã tra cứu, mảng `nhanh` theo status | `sac`, `tieuDe` bắt buộc, `maTraCuu` là prop rời |
| `PhanTrang` | `meta`, `danhTu`, `hauTo` | `trang`, `soTrang`, `onDoiTrang` |
| `ManRong` | `moTa?: ReactNode` | `moTa: string` bắt buộc |
| `KhungXuong` | `dang`, `soLuong`, `soCot`, `nhanManHinh` | `rong`, `cao` - một hộp nguyên thuỷ |

Chỉ module `user` dùng bộ này; `inventory`, `machine`, `company` vẫn dựng tay.

**Việc thật của khối 8 giờ là:** chuyển ba module sang bộ đã có, và quyết định chữ ký hiện tại
có đủ không. Hai chỗ đã biết là chưa đủ: `BangThongBao` không có chỗ khai nhánh theo status, mà
5 màn cần nhánh 404 không nút thử lại; `KhungXuong` là hộp nguyên thuỷ nên "13 chỗ Đang tải
thành khung xương" là ghép hộp ở từng màn, không phải truyền một prop `dang`.

Không sửa vá spec cũ. Viết lại từ đầu, vì tiền đề chết chứ không phải sai chi tiết.

## Bốn chỗ chặn của ADR-0023, cho người thi công khối 9

Hai chỗ đầu đã được vá trong `backend-erp/migrations/000025_vai_tro_xuong_database.up.sql` bởi
phiên đang cầm nhánh `feat/vai-tro-xuong-database` - kiểm lại ngày 2026-08-22, migration không
còn câu `DELETE` nào và lập luận R-18 đã viết đúng. Ghi lại để không ai mở lại:

1. ~~Xoá cứng hàng vai trò cũ đâm khoá ngoại `user_company_role_scopes` (23503).~~ Đã vá bằng
   cách nạp một hàng `roles` đã xoá mềm mang mã cũ làm đích backfill. Ca thật đo được trên máy
   dev: `role_code = 'member'`, đã xoá mềm, còn một hàng phạm vi treo trên nó.
2. ~~Viện dẫn R-18 ngược.~~ Đã sửa.

Hai chỗ **còn nguyên**:

3. **Cửa gán vai trò dựng từ một danh mục biên dịch được.** `quyenGanTheoVaiTro`
   (`modules/auth/internal/service/user_service.go:171-177`) derive một map từ
   `Deps.DanhMucVaiTro`, vốn đến từ `vaitro.DanhMuc()` - hằng trong code. Tập mã vai trò thành
   mở thì vai trò do quản trị tạo không có mục nào trong map, và cửa gán không suy ra nổi module
   sở hữu nó. Vá bằng cách cắt tiền tố mã thì mở đường leo quyền xuyên module: người chỉ có
   `inventory.role_assign` tạo vai trò `inventory.x` chứa `auth.user_delete` rồi tự gán.
4. **Bộ nạp mặc định chỉ chạy cho công ty mới.** Không có đường đưa quyền của module mới vào vai
   trò của công ty đã tồn tại. Với mười hai module của ADR-0017, mỗi lần ra module là một
   migration dữ liệu nhân theo số công ty.

**Và một chỗ thứ năm, do phiên `erp-77` bổ sung:** vai trò xuống database làm **ba** nguồn phải
đổi cùng lúc, không chỉ bảng phân quyền - `GET /api/v1/roles`, hằng `NHAN_VAI_TRO` ở
`frontend-erp/src/app/DropdownTaiKhoan.tsx`, và bảng vai trò. Riêng `/roles` còn kéo theo phần
hình thức: ngoại lệ R-12 của nó đăng ký ở `04-conventions/C-API-07` mục 3 mang sẵn điều kiện tự
huỷ - "ngày danh mục vai trò được đọc từ một bảng thì dòng này phải bị gỡ và endpoint phải nhận
đủ ba tham số". ADR-0023 là đúng cái ngày đó.

## Nhật ký thi công

**2026-08-22 - khối 5b xong.** Trước khi chạy, `units` trên dev có **0 dòng** - đúng cảnh báo
rằng script nạp tồn sẽ dừng ở request đầu tiên. Lệnh chạy:

```
ssh dev-erp 'bash -lc "cd /opt/erp/backend-erp && DATABASE_URL=postgres://erp:erp@127.0.0.1:5433/erp_dev?sslmode=disable go run ./cmd/dev seed-units"'
```

Kết quả `dev: seed-units: them 14 don vi moi, 0 da co san (tong 14)`. Kiểm lại từ database chứ
không tin output: `units` có 14 dòng (`bao bo cai cuon g hop kg l m m2 m3 tam tan thung`), và
`audit_logs` có **14 dòng action `unit.created`**. Dòng audit đó chính là thứ đường vòng `psql`
sẽ đánh mất, nên nó là phép kiểm đáng giá nhất của bước này.

**2026-08-22 - Q32 phải quyết lại.** Khối 1b ghi "giới hạn tốc độ nginx cho `/api/v1/auth/login`"
là **không dùng được**: `infra-erp/docker/web.nginx.conf:4-11` cố ý không có
`location /api/ { proxy_pass ... }`, trình duyệt gọi thẳng api ở cổng 8080, nên lưu lượng đăng
nhập không đi qua nginx. Đường thay thế đề xuất: middleware giới hạn tốc độ trong Go áp cho
riêng route đăng nhập, đếm trong bộ nhớ - đủ vì ADR-0013 chốt `cmd/api` chạy một instance.
Chưa chốt với chủ dự án.
