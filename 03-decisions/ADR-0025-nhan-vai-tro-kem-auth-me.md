# ADR-0025: `GET /auth/me` trả kèm nhãn vai trò của phiên, và đó là nguồn nhãn duy nhất của popover tài khoản

**Status:** Accepted (2026-08-22)

## Context

Ở thời điểm quyết, hệ có **hai bảng nhãn vai trò song song**, và không có gì nối chúng lại.

Bảng thứ nhất ở backend: `DanhMuc()` (`backend-erp/cmd/internal/vaitro/vaitro.go:426-438`)
trả bảy dòng `{Ma, Nhan, PermGan}` viết tay. Bảng thứ hai ở frontend: hằng `NHAN_VAI_TRO`
(`frontend-erp/src/app/DropdownTaiKhoan.tsx:36-45`), tám dòng mã → chữ, cũng viết tay, nằm
trong một repo khác và không liên quan gì tới build của repo backend.

Chính file `vaitro.go` ghi ràng buộc ấy thành một khối cảnh báo dài (`vaitro.go:404-422`):
*"hôm nay tồn tại hai bảng nhãn, và chúng phải được giữ khớp bằng tay… Lệch thì không gì báo,
và hình dạng của lỗ hổng là: cùng một người, cùng một vai trò, hai tên khác nhau ở hai màn
hình."* Khối đó không phải phòng xa: nó ghi lại một lần lệch **đã xảy ra thật** — backend viết
"Quản trị kho" / "Chỉ đọc kho" / "Chỉ đọc thiết bị" / "Kỹ thuật viên" trong khi frontend viết
"Quản trị kho vận" / "Xem kho vận" / "Xem thiết bị" / "Kỹ thuật", lệch bốn trên bảy dòng và đi
tới máy dev ở bản `rc.18` trước khi có người nhìn thấy. Bản chép ở frontend thắng lúc sửa, vì
chữ của nó bám theo tên ứng dụng thật trong `frontend-erp/src/app/ung-dung.ts`.

`NHAN_VAI_TRO` có **đúng một chỗ đọc** trong toàn bộ `frontend-erp/src`:
`DropdownTaiKhoan.tsx:185`, biểu thức `{NHAN_VAI_TRO[r] ?? r}` dựng chip vai trò trên popover
tài khoản. Màn gán vai trò `/nguoi-dung/:id` không đọc nó — màn đó lấy nhãn từ
`GET /api/v1/roles` qua `VaiTroKhaDungDTO` (`frontend-erp/src/modules/user/api/user-api.ts:110-113`).

**Đợt 2026-08-21 đã chốt một hướng, và hướng đó bị lật lúc thi công.** Quyết định cũ là "dùng
`GET /roles` làm nguồn nhãn duy nhất, xoá `NHAN_VAI_TRO`". Nó không đi được vì cửa quyền:
route đăng ký `v1.GET("/roles", xacThuc, hVaiTro.DanhMuc)`
(`backend-erp/modules/auth/internal/handler/user_routes.go:56`), rồi service mở đầu bằng
`s.authz.Can(ctx, actor, PermUserAssignRoles)`
(`backend-erp/modules/auth/internal/service/user_service.go:567-570`). Bốn trên tám vai trò
không có `auth.user_assign_roles`: `inventory.thu_kho`, `inventory.viewer`, `machine.viewer`,
`machine.ky_thuat` — đúng những tài khoản nhà xưởng mở hệ này hàng ngày. Popover tài khoản thì
mọi người đăng nhập đều mở được.

Cửa quyền đó không phải tình cờ, nó bị khoá bằng e2e:
`TestE2EDanhMucVaiTroThieuQuyenTra403` (`backend-erp/cmd/api/e2e_test.go:2387-2402`) khẳng định
`inventory.viewer` gọi `GET /roles` phải nhận **403**, kèm lý do viết ngay trên hàm: *"câu trả
lời đúng là một lần từ chối chứ không phải một danh sách rỗng"*. Một e2e thứ hai,
`TestE2EDanhMucVaiTroKhopBangThat` (`e2e_test.go:2352`), khoá cả nội dung danh mục lẫn mệnh đề
"thân response không mang tên permission".

Ca thứ hai, độc lập với cửa quyền: `quan_tri_he_thong` **cố ý vắng mặt** khỏi `DanhMuc()`
(`vaitro.go:392-402`) vì nó là vai trò **dẫn xuất** từ cờ `users.is_system_admin`, không ai gán
được cho ai (`backend-erp/modules/auth/internal/service/permissions.go:91` và `:104`). Nên kể
cả với người **có** quyền đọc `GET /roles`, chính vai trò của họ vẫn không có nhãn ở đó. Đó là
chỗ hai bảng nhãn **được phép** khác nhau, và cũng là chỗ không đường nào đi qua `GET /roles`
lấp được.

`GET /auth/me` hôm nay không lấp được ca nào trong hai ca trên. `MeDTO`
(`backend-erp/modules/auth/internal/handler/auth_handler.go:222-234`) có ba trường: `user`,
`company`, `is_system_admin`. Danh sách vai trò nằm **bên trong** `user`, tức trong
`api.UserDTO.Roles` (`backend-erp/modules/auth/api/dto.go:51`) — một `[]string` mã thô, không
nhãn. Và `api.UserDTO` là **hợp đồng công khai liên module** (`dto.go:1-14`), dùng chung bởi
`GET /users`, `GET /users/:id` và `PUT /users/:id/roles`; phía frontend là `CurrentUser`
(`frontend-erp/src/modules/auth/api/auth-api.ts:55-61`), đi vào `Session.user`
(`frontend-erp/src/modules/auth/api/session.ts:57-65`).

**Bối cảnh vừa đổi hẳn trong hai ngày trước quyết định này, và đó là dữ kiện làm đổi câu trả
lời.**

[ADR-0023](ADR-0023-vai-tro-xuong-database.md) Accepted 2026-08-21, **đợt 1 đã merge**:
migration `000025_vai_tro_xuong_database` đã chạy, hai bảng `roles` và `role_permissions` đã có,
`roles.name` là **cột chữ hiển thị, người quản trị của từng công ty sửa tự do** (ADR-0023 mục 2
và mục 5), và `authz.Checker` đã đọc ánh xạ vai trò → quyền từ database qua
`selectQuyenTheoVaiTroSQL` (`backend-erp/modules/auth/internal/repository/role_repository.go:69-77`).
Bộ vai trò mặc định của một phân vùng mới được nạp kèm nhãn ngay trong câu `INSERT INTO roles
(company_id, code, name, …)` (`role_repository.go:179-184`), lấy từ `vaitro.BoMacDinh()`
(`vaitro.go:466`) — tức nhãn **đã** nằm trong database cho mọi phân vùng.

[ADR-0024](ADR-0024-tham-quyen-tren-vai-tro-tinh-tu-tap-quyen.md) Accepted 2026-08-22, mục 5:
`DanhMuc()` và trường `PermGan` **bị bỏ**, và `GET /roles` **đọc database** để lấy nhãn, kéo
theo ngoại lệ R-12 đăng ký ở `C-API-07` mục 3 hết hiệu lực. ADR đó mới Accepted, **chưa thi
công**: tại thời điểm này `cmd/api/main.go:241` vẫn tiêm `vaitro.DanhMuc()` xuống `UserService`,
và `GET /roles` vẫn trả bảy dòng hằng.

Nghĩa là ở thời điểm quyết, nhãn vai trò đã **thôi là hằng trong code** về mặt định nghĩa —
nó là `roles.name`, dữ liệu cấp công ty — nhưng **chưa có một câu đọc nào** trong backend lấy
cột đó ra: `grep` cả `backend-erp` cho `roles.name` chỉ ra hai comment và một câu `INSERT`. Cả
hai bảng nhãn đang chạy đều là hằng Go, và cả hai đều **không biết** công ty B đã đổi `name`
của `inventory.thu_kho` thành chữ khác.

Vai trò dẫn xuất thì đứng ngoài toàn bộ chuyện đó: ADR-0023 mục 3 chốt `quan_tri_he_thong`
không bao giờ có một hàng trong `roles`, và tập quyền của nó ở lại trong code, ghép vào bảng
đọc từ database tại `vaitro.KemVaiTroDanXuat` (`backend-erp/cmd/internal/vaitro/nguon.go:44-72`).
Nó không có `company_id` để mà thuộc về, nên nó cũng không có `name` để mà đọc.

Cuối cùng, `Actor.Roles` (`backend-erp/shared/auth/auth.go:22-26`) là danh sách **mã** lấy từ
claim của access token. Một mã trong token có thể không còn hàng `roles` sống tương ứng: đường
nâng cấp của ADR-0023 mục 10 nạp các mã vai trò thời trước ADR-0021 thành hàng **đã xoá mềm**
để backfill không mất hàng gán nào, và `roles` cũng xoá mềm được (ADR-0023 mục 5).

## Decision

**`GET /auth/me` trả kèm nhãn hiển thị của từng vai trò trong phiên đang mở, và popover tài
khoản đọc nhãn từ đó; hằng `NHAN_VAI_TRO` ở frontend bị xoá.**

Phạm vi của quyết định này:

**1. Nhãn đi ra ở một trường MỚI của `MeDTO`, ngang hàng `is_system_admin` — không đi vào
`api.UserDTO`.**

```
{
  "user":            { "id": "…", "roles": ["inventory.thu_kho"], … },
  "company":         { … },
  "is_system_admin": false,
  "vai_tro":         [ { "ma": "inventory.thu_kho", "nhan": "Thủ kho" } ]
}
```

`api.UserDTO.Roles` **giữ nguyên** `[]string` mã thô và không đổi một ký tự. Nó là hợp đồng
liên module (`dto.go:1-14`) mà `GET /users` dùng chung; nhét nhãn vào đó là bắt mỗi dòng của
danh sách người dùng mang thêm một mảng object, và là một breaking change cho mọi người đọc
`UserDTO`. Trường mới đi cùng đường mà `is_system_admin` đã đi và vì cùng lý do đã ghi ở
`auth_handler.go:213-221`: thứ mô tả **phiên đang mở** thì nằm ở `MeDTO`, không nằm trong hình
dạng một hàng `users`.

Hình dạng mỗi phần tử là `{ma, nhan}` — **cùng hai tên trường** với `VaiTroKhaDungDTO` của
`GET /roles` (`user_role_handler.go:65-68`), để hai đường nói cùng một thứ bằng cùng một chữ.

**2. Nguồn của `nhan` là cột `roles.name` của phân vùng đang mở**, đọc theo đúng mã trong
`Actor.Roles`. Đây là thứ ADR-0023 mục 2 chốt là "chữ hiển thị, sửa tự do", nên một công ty đổi
`name` thì popover đổi theo trong lượt `GET /auth/me` kế tiếp.

**3. Câu đọc chỉ lấy hàng `roles` CÒN SỐNG**, cùng mệnh đề `deleted_at IS NULL` mà
`selectQuyenTheoVaiTroSQL` (`role_repository.go:69-77`) đang dùng. Nhãn phải nói cùng một sự
thật với quyền: một vai trò đã xoá mềm không cấp quyền nào, nên nó cũng không được có một cái
tên đẹp trên popover. Nó rơi vào mục 5.

**4. Nhãn của vai trò dẫn xuất `quan_tri_he_thong` đến từ composition root, không từ database.**
Nó không có hàng trong `roles` (ADR-0023 mục 3) nên không có `name`; chuỗi "Quản trị hệ thống"
được khai ở `cmd/internal/vaitro` và tiêm xuống module `auth`, đi đúng con đường mà tập quyền
của chính vai trò đó đã đi qua `KemVaiTroDanXuat` (`nguon.go:44-72`). Đây là chỗ duy nhất còn
lại của một nhãn viết tay trong hệ, và mục Consequences nói rõ nó không biến mất.

**5. Vai trò lạ — mã có trong token mà không có hàng `roles` còn sống — trả về `nhan` bằng
CHÍNH mã đó.** Backend không bao giờ trả `nhan` rỗng, và không bao giờ bỏ một phần tử: mọi mã
trong `Actor.Roles` đều có đúng một phần tử trong `vai_tro`, theo đúng thứ tự của token. Giấu
một vai trò người dùng đang mang là nói dối về họ là ai — đúng mệnh đề đang được ghi tại
`DropdownTaiKhoan.tsx:182-184`. Hệ quả là frontend không còn nhánh `?? r` nào, và chỗ quyết
định "hiện gì khi không có nhãn" chỉ còn một, ở backend.

**6. `NHAN_VAI_TRO` bị xoá khỏi `frontend-erp/src`.** Nó có đúng một chỗ đọc
(`DropdownTaiKhoan.tsx:185`) và chỗ đó chuyển sang đọc `vai_tro` từ `Session`. Không còn ca nào
cần nó: màn gán vai trò lấy nhãn từ `GET /roles`, và `khongConTrongDanhMuc`
(`user-api.ts:123-137`) so mã với danh mục của `GET /roles` chứ không tra nhãn.

**7. Quyết định này KHÔNG đụng `GET /roles`.** Cửa quyền `auth.user_assign_roles`
(`user_service.go:567-570`) đứng nguyên, `TestE2EDanhMucVaiTroThieuQuyenTra403`
(`e2e_test.go:2387-2402`) đứng nguyên, và màn quản trị `/nguoi-dung/:id` vẫn dùng đúng endpoint
đó — người mở màn ấy theo định nghĩa phải có quyền gán, nếu không họ đã ăn 403 từ `GET /users`.
Việc `GET /roles` chuyển sang đọc database là chuyện của ADR-0024 mục 5, không phải của ADR này.

**8. Quyết định này KHÔNG chạm hai vấn đề đang được quyết ở nơi khác.** Nó không nói gì về
`inventory.warehouse_scope_all` cộng dồn theo người trong khi phạm vi treo theo hàng vai trò —
đó là một câu hỏi về **quyền**, còn đây là một trường **chữ hiển thị**. Và nó không nói gì về
đường đưa permission của một module mới vào vai trò của công ty đã tồn tại (ADR-0023 mục 11 chỉ
nạp cho công ty mới): nếu một phân vùng thiếu hàng `roles` cho một mã nào đó, ADR này chỉ quy
định hiển thị mã thô theo mục 5, không quy định ai nạp hàng ấy và nạp lúc nào.

## Alternatives

**Popover đọc nhãn từ `GET /roles`** — loại. Đây là quyết định của đợt 2026-08-21 và nó bị lật
bằng số đo, không bằng khẩu vị: endpoint đòi `auth.user_assign_roles`
(`user_service.go:567-570`), và **bốn trên tám** vai trò không có quyền đó —
`inventory.thu_kho`, `inventory.viewer`, `machine.viewer`, `machine.ky_thuat`. Với chúng, nhánh
"gọi lỗi thì lùi về mã thô" không phải nhánh phòng xa mà là **nhánh bình thường**, tức chip vai
trò của phần lớn người dùng nhà xưởng sẽ hiện `inventory.thu_kho` thay vì "Thủ kho" — đúng
triệu chứng mà quyết định này ra đời để chấm dứt. Nó cũng không phủ được `quan_tri_he_thong`:
người có quyền nhận 200 sạch, rồi chính vai trò của họ không có trong danh mục
(`vaitro.go:392-402`) và bị mô tả bằng một câu sai.

**Hạ cửa quyền của `GET /roles` xuống chỉ còn `xacThuc`** — loại, dù đây là đường rẻ nhất và nó
sửa được cả bốn ca 403 bằng một dòng ở `user_service.go`.

Ba lý do, và lý do đầu là lý do quyết. Một: nó đòi **xoá `TestE2EDanhMucVaiTroThieuQuyenTra403`**
(`e2e_test.go:2387-2402`), tức cố ý gỡ một hợp đồng đã khoá — và hợp đồng ấy phát biểu một mệnh
đề còn đúng: câu trả lời cho một người không gán được vai trò là một lần từ chối, không phải một
danh sách. Hai: nó **vẫn không phủ `quan_tri_he_thong`**, nên popover vẫn phải giữ một ca đặc
biệt viết tay — tức chưa xoá hết bản chép, chỉ rút nó từ tám dòng xuống một dòng. Ba: nó thêm
một lần gọi mạng và một trạng thái đang tải vào mỗi lần mở popover, và cái người dùng thấy là
chip nháy từ mã thô sang nhãn mỗi lần bấm avatar. Sau ADR-0024 mục 5, endpoint ấy còn đọc
database, nên "rẻ" cũng thôi đúng.

**Không làm gì: giữ hai bảng nhãn và tiếp tục chép tay** — loại, và điều làm nó hết là ADR-0023
chứ không phải lần lệch ở `rc.18`. Trước ADR-0023, hai bảng hằng còn có thể khớp nhau bằng kỷ
luật, vì nhãn là hằng ở cả hai phía. Sau ADR-0023 mục 5, nhãn là **cột `roles.name` do người
quản trị của từng công ty sửa tự do**, nên một hằng Go hay một hằng TypeScript **không thể**
đúng được nữa: công ty B đổi `name` của `inventory.thu_kho` thì cả hai bảng cùng sai, và không
có kỷ luật nào chữa được điều đó. Phương án này không còn là "chấp nhận một rủi ro", nó là
"cam kết hiển thị sai".

**Đổi `api.UserDTO.Roles` thành `[]{ma, nhan}`** — loại. Nó là hợp đồng công khai của module
`auth` (`dto.go:1-14`), và ba đường dùng chung nó: `GET /users`, `GET /users/:id`,
`PUT /users/:id/roles`. Đổi kiểu của trường đó làm vỡ cả ba, kéo theo `CurrentUser`
(`auth-api.ts:55-61`), `vaiTroDangCo` và `khongConTrongDanhMuc` (`user-api.ts:123-146`) — trong
khi thứ cần thêm chỉ có nghĩa cho **một** người: người đang cầm token. Nhãn là thuộc tính của
phân vùng đang mở, không phải của một hàng `users`; đúng lập luận mà `auth_handler.go:213-221`
đã dùng để không nhét `company` vào `UserDTO`, và nếu bỏ qua nó ở đây thì mỗi dòng của
`GET /users` mang theo một mảng object vô nghĩa.

**Nhét nhãn vào claim của access token** — loại. Nó xoá được cả câu đọc database lẫn trường DTO
mới, nhưng token được ký **một lần lúc đăng nhập**: một quản trị đổi `roles.name` sẽ không thấy
gì đổi cho tới khi mọi access token đang lưu hành hết hạn, và người dùng không có cách nào ép nó
sớm hơn ngoài đăng xuất. Chữ hiển thị là thứ được sửa nhiều nhất trong ba thứ (mã, quyền, nhãn),
nên đóng băng đúng nó vào token là chọn sai thứ để đóng băng. Thêm nữa nó nhồi chữ tiếng Việt có
dấu vào một chuỗi đi kèm **mọi** request, đổi lấy đúng một lần đọc mỗi lượt `GET /auth/me`.

**Mở một endpoint thứ ba, `GET /auth/me/roles`** — loại. Nó tránh được việc đổi hình dạng
`MeDTO`, nhưng đổi lại là một lần gọi mạng thứ hai cho dữ liệu đã có sẵn trong cùng một phiên và
cùng một lượt khôi phục — trong khi `Session` (`session.ts:57-65`) được dựng có chủ đích quanh
mệnh đề "phân vùng và cờ quản trị đến **cùng một lượt** với `user` vì chúng cùng đến từ
`GET /auth/me` — không có request thứ hai". Một endpoint mới còn phải tự trả lời lại các câu về
cửa quyền và về phân trang (R-12, `C-API-07`), tức mở lại đúng cuộc tranh luận vừa khép.

## Consequences

**Được:**

- **Còn một bảng nhãn duy nhất cho vai trò gán được: cột `roles.name`.** Bản chép ở frontend
  biến mất hẳn (mục 6), và lần lệch kiểu `rc.18` — bốn trên bảy dòng, không gì báo — không có
  chỗ để lặp lại nữa vì không còn hai bảng để lệch.
- **Popover đúng cho mọi người đăng nhập, không phân biệt quyền.** Không nhánh 403, không lần
  gọi mạng thứ hai, không trạng thái đang tải, không chip nháy từ mã sang chữ.
- **`quan_tri_he_thong` lần đầu có nhãn đến từ backend.** Nơi ký token biết vai trò dẫn xuất đó
  (`nguon.go:44-72`), còn `DanhMuc()` thì cố ý không biết — nên đây là ca mà chỉ đường này trả
  lời được.
- **Nhãn bám theo dữ liệu của từng công ty.** Một phân vùng đổi `roles.name` thì chip đổi theo,
  đúng thứ ADR-0023 mục 5 hứa và hôm nay chưa có đường nào giữ lời.
- **Đóng một dòng nợ của [ADR-0021](ADR-0021-vai-tro-theo-module.md)**: *"`NHAN_VAI_TRO` ở
  frontend là map mã → chữ chép tay… sẽ lệch tiếp mỗi lần bảng vai trò đổi vì không có gì nối
  hai bên."* Khối cảnh báo ở `vaitro.go:404-422` mất lý do tồn tại cùng lúc.

**Mất:**

- **`GET /auth/me` chạm database thêm một câu đọc, và nó là endpoint chạy nhiều nhất sau
  middleware.** Nó đã đọc `users` và `companies` (`auth_service.go:640-706`); nay thêm một câu
  trên `roles`. Endpoint này chạy mỗi lần tải trang và mỗi lần khôi phục phiên. Cache của
  `authz.Checker` (ADR-0023 mục 8) giữ ánh xạ vai trò → **quyền** theo phân vùng, **không** giữ
  nhãn, nên nó không đỡ hộ được lượt đọc này.
- **Trong khoảng giữa ADR-0025 và lúc ADR-0024 mục 5 được thi công, hệ có hai đường trả nhãn nói
  hai thứ khác nhau.** `GET /auth/me` trả `roles.name` từ database; `GET /roles` vẫn trả nhãn
  hằng của `DanhMuc()` (`main.go:241`). Với một công ty đã sửa `name`, cùng một mã vai trò sẽ
  hiện hai chữ ở hai màn hình — **đúng hình dạng lỗ hổng cũ, chỉ đổi chỗ**. Đây là cái giá thật
  của việc quyết trước khi ADR-0024 được cài, và cách đóng nó là thi công ADR-0024, không phải
  một vá riêng ở đây.
- **Nhãn viết tay không biến mất, nó chỉ còn một dòng và đổi chỗ.** "Quản trị hệ thống" chuyển từ
  `DropdownTaiKhoan.tsx` sang `cmd/internal/vaitro` (mục 4). Bù lại nó về đúng chỗ đã giữ tập
  quyền của chính vai trò ấy, nên nó không còn là bản chép **thứ hai** của một thứ ở nơi khác.
- **Frontend mất khả năng phân biệt "nhãn thật trùng mã" với "không tìm thấy hàng".** Mục 5 làm
  hai ca đó ra cùng một chuỗi. Một quản trị đặt `roles.name` đúng bằng `code` sẽ nhìn giống hệt
  một vai trò đã bị xoá mềm.
- **`MeDTO` và `Session` cùng phình thêm một trường.** `Session` (`session.ts:57-65`) nhận một
  field thứ tư bên cạnh `phanVung` và `quanTriHeThong`, và mọi chỗ dựng `Session` rỗng
  (`session.ts:67`, `:198`, `:238`, `:247`) phải khai giá trị khởi tạo cho nó.

**Nợ để lại:**

- **Điều kiện — không phải khuyến nghị:** quyết định này chỉ cho ra nhãn đúng nếu mọi phân vùng
  thật sự có hàng `roles` cho các mã đang nằm trong token. Hai đường nạp đang giữ điều đó:
  migration `000025` cho phân vùng cũ và `CreateCompany` cho phân vùng mới (ADR-0023 mục 11).
  Ngày có một mã vai trò tồn tại mà không có hàng, triệu chứng là mã thô trên popover chứ không
  phải một lỗi — nên nó sẽ không tự báo.
- Các hàng `roles` **đã xoá mềm** mà migration `000025` nạp cho những mã vai trò thời trước
  ADR-0021 (ADR-0023 mục 10) sẽ cho ra mã thô theo mục 3. Đó là kết quả đúng và nhất quán với
  quyền — người mang chúng cũng không có quyền nào — nhưng nó có nghĩa là danh sách "vai trò
  hiện mã thô" khác rỗng ngay từ ngày đầu trên các phân vùng cũ.
- **Chưa quyết chỗ cache nhãn.** Câu đọc mới có thể đi cùng cache 30 giây theo phân vùng của
  `dbChecker`, hoặc đứng riêng, hoặc không cache. Bỏ ngỏ vì phép đo chưa có; điều kiện để mở lại
  câu hỏi này là `GET /auth/me` lộ ra trong quan trắc như một endpoint tốn thời gian.
- **Chưa quyết cách phân biệt ca "không có nhãn" ở giao diện.** Mục 5 chọn im lặng hiện mã thô.
  Ngày cần đánh dấu nó — một dấu chấm than, một tooltip — sẽ cần một trường thứ ba trong
  `{ma, nhan}`, và đó là một lần đổi hợp đồng nữa.
- `khongConTrongDanhMuc` (`user-api.ts:123-137`) vẫn đối chiếu với `GET /roles` và **không** đổi
  theo quyết định này. Sau khi ADR-0024 mục 5 thi công, cả hai đường cùng đọc database và hai
  phép so đó nói cùng một thứ; trước đó thì không.

**Constrains:** —
