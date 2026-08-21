# ADR-0021: Vai trò mang tên module, quyền gán vai trò và gán phạm vi là permission của module sở hữu

**Status:** Accepted (2026-08-21)

## Context

Ở thời điểm quyết, hệ có **ba vai trò gán được** và mỗi cái là một bó quyền trải ngang mọi
module: `admin` mang ba mươi bảy permission của cả `auth`, `machine` lẫn `inventory`; `member`
mang mười bảy; `ky_thuat` mang ba. Tên chúng nằm ở `cmd/internal/vaitro/vaitro.go`, đúng chỗ
[ADR-0010](ADR-0010-bang-vai-tro-o-cmd-internal.md) đã chốt, và được gán theo cặp (người, phân
vùng) vào `user_company_roles` theo [ADR-0019](ADR-0019-phan-vung-la-cong-ty.md) mục 3.

Ba dấu hiệu cho thấy mô hình bó ngang đã hết chỗ:

**Chuỗi permission có tiền tố module, chuỗi tên vai trò thì không.** `C-GO-02` chốt permission
là `<module>.<hành động>` — `inventory.warehouse_list`. Tên vai trò thì trần: `admin`. Hai lối
đặt tên cho hai thứ nằm cạnh nhau trong cùng một bảng.

**`ky_thuat` thực chất đã là một vai trò của module `machine`**, chỉ là mang tên không có tiền
tố. Ba permission của nó gồm hai của `machine` và một `auth.self_read`; khối ghi chú của nó
trong `vaitro.go` viết rằng nó được gán **kèm** `member` chứ không thay thế. Mô hình
vai-trò-theo-module đã lẻn vào bằng cửa sau.

**Không diễn tả được một người ghi được dữ liệu mà chỉ thấy vài bản ghi.** Muốn một thủ kho ghi
được chuyển động nhưng chỉ thấy hai kho, hôm nay phải đẻ một tên vai trò mới **trải ngang mọi
module** — không có nhóm nào để nó thuộc về.

Và với mười hai module của [ADR-0017](ADR-0017-muoi-hai-module-va-ten-tieng-anh.md), bó ngang
phình theo **tổ hợp**: mỗi lần cần "quản kho nhưng không đụng máy" là một tên mới trải ngang,
chứ không phải một dòng trong một nhóm.

Cuối cùng, một khoảng trống về cơ chế: hệ **chưa có khái niệm quyền về quyền**. `authz.Can`
trả lời "được làm loại việc này không"; nó không trả lời "được gán vai trò X cho người khác
không". Cửa duy nhất hôm nay là `auth.user_assign_roles`, và nó là tất-cả-hoặc-không.

## Decision

**Vai trò mang tên module, và thẩm quyền gán vai trò lẫn gán phạm vi là permission của chính
module sở hữu.**

**1. Tên vai trò theo khuôn `<module>.<vai_trò>`.** Cùng hình dạng với chuỗi permission mà
`C-GO-02` đã chốt. `module` là tên thư mục module theo ADR-0017.

**2. Tám vai trò cho ba module đang chạy.**

| Vai trò | Gồm gì |
|---|---|
| `auth.admin` | năm quyền CRUD user, `auth.role_assign`, hai quyền cửa ở mục 4 |
| `inventory.admin` | mười sáu permission của `inventory` (kể cả `inventory.warehouse_scope_all`), `inventory.role_assign`, `inventory.scope_assign`, `auth.user_list`, `auth.user_read`, hai quyền cửa |
| `inventory.thu_kho` | `warehouse_list/read`, `item_list/read`, `movement_list/read/create`, `balance_read`, `unit_list` — **không** có `warehouse_scope_all` |
| `inventory.viewer` | `warehouse_list/read`, `item_list/read`, `movement_list/read`, `balance_read`, `unit_list` |
| `machine.admin` | mười hai permission của `machine`, `machine.role_assign`, `auth.user_list`, `auth.user_read`, hai quyền cửa |
| `machine.viewer` | `machine_list/read`, `plan_list/read`, `breakdown_read` |
| `machine.ky_thuat` | `plan_execute`, `breakdown_create` — gán KÈM `machine.viewer`, xem mục 8 |
| `quan_tri_he_thong` | năm quyền `PermCompany*`, mọi `<module>.role_assign`, mọi `<module>.scope_assign`, `auth.user_list`, `auth.user_read`, hai quyền cửa — dẫn xuất, không ai gán được |

`inventory.admin` **giữ** `warehouse_scope_all`, và giữ có lý do: người mở kho phải thấy kho
mình vừa mở, nếu không thì mỗi lần tạo kho lại phải nhờ người khác cấp phạm vi cho chính mình.

Vì vậy **mô hình này không làm "quản trị kho bị giới hạn" trở nên tự động** — nó làm việc đó
trở nên **rẻ và cục bộ**. Vai trò cần thiết là `inventory.thu_kho`: ghi được chuyển động, chịu
phạm vi. Cái giá của một mức phạm vi mới rơi từ "một tên trải ngang mười hai module" xuống
"một dòng trong một nhóm", không migration và không hợp đồng API nào đổi.

**3. `member` bị bỏ. Ai cần đọc module nào thì mang `<module>.viewer` của module đó.** Một vai
trò "thành viên" chung là chỗ mọi quyền đọc của mọi module dồn vào, và nó lớn dần mà không ai
đứng ra chịu trách nhiệm cho lần lớn tiếp theo.

**4. Gán vai trò đi qua một endpoint RIÊNG, và thẩm quyền là permission `<module>.role_assign`
do composition root khai.**

`PUT /api/v1/users/:id/roles`, câu lệnh **đầu tiên** của method service là
`Can(actor, PermUserAssignRoles)`. Trường `roles` bị bỏ khỏi `PATCH /users/:id` — đây là một
thay đổi **phá hợp đồng API**, và nó chấp nhận được vì chưa màn hình nào gửi trường đó; chỗ duy
nhất dùng là test đầu-cuối.

Đây là chỗ dễ đi sai nhất, và lý do phải tách hẳn một endpoint chứ không dùng lại đường cũ:
`PATCH /users/:id` mở đầu bằng `Can(actor, PermUserUpdate)`, không phải `PermUserAssignRoles`.
Nên nếu để nguyên, một `inventory.admin` — dù có đủ `inventory.role_assign` lẫn quyền cửa — vẫn
ăn 403 ngay dòng đầu, và mọi phép kiểm module phía sau **không bao giờ chạy tới**.

Cách vá hiển nhiên là cấp `auth.user_update` cho mọi module admin, và nó hỏng về phía **mở**:
thân của `PATCH /users/:id` mang trường mật khẩu, nên `inventory.admin` sẽ đặt lại được mật
khẩu của bất kỳ ai trong phân vùng — kể cả `auth.admin` — rồi đăng nhập bằng tài khoản đó.
Không phải leo quyền gián tiếp, mà là mạo danh. Một endpoint riêng cắt hẳn đường đó.

`CreateUser` vẫn nhận `roles`, vì tạo người và gán vai trò đầu tiên là một thao tác; nhưng nó
phải chạy **cùng phép kiểm module** cho từng vai trò trong danh sách. Thiếu chỗ đó thì
`auth.admin` gán được vai trò của mọi module ngay lúc tạo.

Hệ quả cho người vận hành, phải nói trước kẻo nó hiện ra thành một lần 403 khó hiểu:
`auth.admin` **một mình không tạo được** một user kèm vai trò kho, vì nó không có
`inventory.role_assign`. Luồng đúng là tạo người trước với danh sách vai trò rỗng, rồi
`inventory.admin` gán vai trò của module mình. Đó là hệ quả trực tiếp của mệnh đề "không đụng
module khác", không phải một chỗ vướng cần vá.

**Phép kiểm chạy trên HIỆU ĐỐI XỨNG, không trên tập gửi lên.** Đường ghi vai trò là THAY chứ
không phải THÊM — nó xoá mềm sạch rồi chèn lại — nên một vai trò bị **gỡ** không nằm trong thân
request. Kiểm trên tập gửi lên thôi thì một người có `inventory.role_assign` gửi
`{"roles":["inventory.viewer"]}` sẽ xoá luôn `auth.admin` của người kia, mà mọi phần tử trong
thân đều hợp lệ. Phải kiểm cả vai trò **thêm vào** lẫn vai trò **bớt đi**.

**Permission gán của từng vai trò đến từ một danh mục tiêm từ `cmd/internal/vaitro` xuống module
`auth`**, đứng cạnh `Bang()` và dựng từ chính hằng permission của module sở hữu. Module `auth`
tra danh mục; nó không ghép chuỗi và không cắt tiền tố. Ghép `"inventory" + ".role_assign"` lúc
chạy thì rẻ hơn, nhưng đó là **chuỗi chép tay** đúng nghĩa mà `C-GO-08` cấm: đổi tên một
permission vẫn build xanh, lỗi chỉ lộ ra ở môi trường thật dưới dạng một lần từ chối sai hoặc
một lần cho qua sai.

Hệ quả phải nói rõ: tiền tố `<module>.` trong tên vai trò là quy ước cho **người đọc**, không
phải một phép phân tích chuỗi gánh trách nhiệm an ninh. Ai đặt tên lệch khuôn thì hệ vẫn chạy
đúng, chỉ khó đọc hơn.

Đường bị loại là suy thẩm quyền từ chính vai trò của actor: "ai mang `inventory.admin` thì gán
được mọi vai trò tiền tố `inventory.`". Nó bắt tầng service **đọc tên vai trò để suy ra quyền**
— đúng lối mà `C-TS-06` cấm ở frontend và ADR-0019 mục 5 đã từ chối khi chọn vai trò dẫn xuất
thay vì đọc thẳng một cờ.

**Gán PHẠM VI đi cùng khuôn đó**, bằng permission `<module>.scope_assign`. `PUT /users/:id/scopes`
đã mở đầu bằng `Can(actor, PermUserAssignScopes)` từ chặng ADR-0020 nên cửa thứ nhất đã đúng
sẵn; thêm vào đó, với **mỗi loại phạm vi** trong thân, kiểm `Can(actor, "<module>.scope_assign")`.
Module của một loại lấy từ danh mục `LoaiPhamVi` mà `cmd/api` đang tiêm — nó đã mang sẵn
`PermToanPham`, chỉ cần mang thêm tên permission gán.

Thiếu nửa này thì `auth.admin` cấp được kho cho người khác mà không có mẩu thẩm quyền nào ở
`inventory` — đúng thứ quyết định này sinh ra để chặn, chỉ khác là rò qua ngả phạm vi.

**Hai quyền cửa — `auth.user_assign_roles` và `auth.user_assign_scopes` — nằm trong MỌI
`<module>.admin` và trong `quan_tri_he_thong`.** Để riêng trong `auth.admin` thì cửa thành cái
chốt khoá ngoài: module admin đứng một mình không gán nổi cả vai trò lẫn phạm vi của chính
module nó. Với `quan_tri_he_thong` thì nặng hơn — nó là vai trò dẫn xuất, `laVaiTroDanXuat`
chặn mọi lần gán nó cho ai, nên không có cả đường vá bằng cách gán kèm `auth.admin`.

Khi cửa nằm ở mọi admin, nó đổi nghĩa: từ "được gán bất cứ thứ gì" thành "được dùng đường gán
nói chung". Nó vẫn có việc thật — `inventory.viewer` không bao giờ qua nổi câu kiểm thứ nhất —
còn quyết định gán được CÁI GÌ thuộc về permission module.

Nói cho hết: cửa là điều kiện **cần nhưng không đủ**, nên trong một vai trò không có
`<module>.scope_assign` nào đi kèm thì `auth.user_assign_scopes` là một dòng **không dùng
được**. Hôm nay điều đó đúng với cả `auth.admin` lẫn `machine.admin`, vì loại phạm vi duy nhất
đang có thuộc `inventory`. Đó là cái giá của việc giữ một cửa chung để R-15 có câu lệnh đầu
tiên không phụ thuộc thân request.

**5. Module admin mang `auth.user_list` và `auth.user_read`.** Muốn gán vai trò cho ai thì phải
tìm ra người đó, mà hai quyền ấy thuộc `auth`. Ba nhánh trong sơ đồ vì vậy không tách rời: cả
ba đều chạm `auth` ở gốc.

**6. Mọi vai trò mang `auth.self_read` và `auth.change_password`, kể cả vai trò dẫn xuất.** Bảng
ở mục 2 liệt kê phần **cộng thêm** trên sàn này, không phải liệt kê đóng. Một phiên đăng nhập
phải nói được nó thuộc về ai, và một người phải đổi được mật khẩu của chính mình. Quyết định
này vá một khiếm khuyết đang có: `ky_thuat` hôm nay có `self_read` nhưng không có
`change_password`.

**7. `quan_tri_he_thong` quản trị được việc GÁN của mọi module, nhưng không đọc được dữ liệu
nghiệp vụ của module nào.** Nó đứng trên các module admin ở trục *quản trị phân quyền* và đứng
ngoài trục dữ liệu nghiệp vụ. Nó **không** cần `auth.user_update`, vì mục 4 đã tách đường gán
vai trò ra khỏi đường sửa hồ sơ.

Điều này **thay hai mệnh đề của ADR-0019 mục 5**: "giữ đúng năm quyền `PermCompany*`", và "đứng
ngoài mọi phân vùng" — hai quyền đọc user là permission của một module, nên vai trò hành chính
này từ nay có một chân trong dữ liệu **danh tính** của phân vùng đang đăng nhập. Bất biến còn
giữ được là bất biến hẹp hơn: nó không có permission nào của `machine` hay `inventory`, nên nó
không đọc được dữ liệu **vận hành** của phân vùng nào.

Vai trò này vẫn là vai trò **dẫn xuất** từ cờ `users.is_system_admin`, vẫn không bao giờ nằm
trong `user_company_roles`, và `laVaiTroDanXuat` vẫn là chỗ chặn nó ở đường gán.

**8. `machine.ky_thuat` phải gán KÈM `machine.viewer`.** Một mình nó bấm được "hoàn thành" trên
một kế hoạch mà không đọc nổi danh sách kế hoạch, và không chọn được máy để ghi sự cố. `vaitro.go`
hôm nay giữ câu này bằng một khối ghi chú và bằng việc `member` luôn có mặt; mục 3 bỏ `member`
nên câu đó phải được ghi lại thành một điều khoản.

**9. Chuyển dữ liệu bằng migration, và migration tự kiểm trước khi `COMMIT`.** Ánh xạ: `admin` →
`auth.admin` + `machine.admin` + `inventory.admin`; `member` → `machine.viewer` +
`inventory.viewer`; `ky_thuat` → `machine.ky_thuat` + `machine.viewer`.

**Ánh xạ áp cho TẬP vai trò của một cặp (người, phân vùng), không nở từng hàng một.** Đây không
phải chi tiết kỹ thuật mà là điều kiện để migration chạy được: `ky_thuat` vốn được gán **kèm**
`member` — đúng cách dùng mà `vaitro.go` khuyến nghị — nên nở từng hàng sẽ sinh `machine.viewer`
hai lần và đâm vào `uq_user_company_roles_company_id_user_company_id_role_code`. Kết quả phải là
**hợp** của các tập ảnh, đã khử trùng.

Ba hậu điều kiện, thiếu cái nào thì dừng và không commit một nửa:

- Mọi cặp (người, phân vùng) từng có hàng `admin` còn sống phải có **đủ ba** hàng admin mới;
  từng có `member` phải có **đủ hai** hàng viewer; từng có `ky_thuat` phải có `machine.ky_thuat`
  và `machine.viewer`.
- Số hàng phạm vi **CÓ HIỆU LỰC** trước và sau phải bằng nhau — đếm hàng
  `user_company_role_scopes` còn sống mà hàng `user_company_roles` của nó cũng còn sống. Đếm
  riêng hàng phạm vi thì không bắt được ca nó vẫn sống nhưng treo trên một hàng vai trò vừa bị
  xoá mềm; lúc đó nó vô hiệu mà con số vẫn khớp.
- Hàng vai trò **đã xoá mềm** phải giữ nguyên `deleted_at`, không được hồi sinh thành hàng đang
  sống. Partial unique index chỉ áp cho hàng còn sống nên không có gì chặn việc đó, và đây là
  ca duy nhất trong migration hỏng về phía **mở**: một `admin` đã bị thu hồi sống lại thành ba
  hàng admin đang hoạt động.

Một điều phải nói cho đúng, vì bản nháp trước của chính ADR này nói sai: **hàng phạm vi bám vào
hàng vai trò nào không đổi kết quả đọc.** Câu đọc lúc chạy lọc theo người, phân vùng và loại,
không lọc theo `role_code`. Hàng vai trò là **mốc vòng đời** của phạm vi — gỡ vai trò thì phạm
vi cấp qua nó hết hiệu lực, vì câu đọc đòi hàng vai trò còn sống — chứ không phải một ngăn chứa
riêng. Rủi ro thật của migration vì vậy không phải "bám nhầm hàng" mà là **bám vào một hàng bị
xoá mềm**, và hậu điều kiện thứ hai ở trên là thứ bắt nó.

**10. Ra đúng MỘT bản, tên cũ biến mất ngay.** Không giữ tên cũ song song một nhịp.

Cái giá phải nói thẳng: access token sống mười lăm phút và mang tên vai trò cũ, mà bảng vai trò
mới không có khoá `admin`, nên trong cửa sổ đó `authz.Can` **từ chối sạch** với những phiên chưa
làm mới token. Frontend không coi 403 là tín hiệu làm mới phiên, nên người dùng thấy màn hình cũ
phủ thông điệp từ chối.

Nó **tự khỏi**: phiên đăng nhập làm mới token chủ động trước hạn sáu mươi giây, và lần ký lại
đọc vai trò từ database đã đổi. Cửa sổ vì vậy bị chặn trên bởi một chu kỳ access token — không
cần rút TTL, không cần blacklist `jti`.

Còn một cửa sổ ngắn nữa ở chính lệnh triển khai: script dựng container trước rồi mới chạy
`migrate-up`, nên ai đăng nhập giữa hai bước đó nhận một token mang tên cũ. Vài giây, và cùng
đường tự khỏi.

Đường khôi phục nếu hỏng là `UPDATE user_company_roles SET role_code = ...` qua `psql`. Không
dùng `cmd/dev` — máy dev không có Go.

**11. Quyết định này không đổi ADR-0010.** Bảng vai trò vẫn là dữ liệu ở composition root, vẫn
dựng từ hằng permission của module, vẫn không có bảng `roles` trong database.

## Alternatives

**Giữ vai trò bó ngang, thêm tên mới khi cần** — loại vì nó phình theo tổ hợp chứ không theo
module: "quản kho không đụng máy", "đọc máy không đọc kho", "quản kho và đọc máy" là ba tên
riêng, và với mười hai module thì tập tên lớn nhanh hơn tập việc.

**Suy thẩm quyền gán từ tiền tố tên vai trò, không thêm permission** — loại, xem mục 4.

**Cấp `auth.user_update` cho module admin thay vì tách một endpoint riêng** — loại vì nó mở
đường đặt lại mật khẩu của bất kỳ ai trong phân vùng, tức mạo danh. Xem mục 4.

**Cho `quan_tri_he_thong` mọi permission của mọi module** — loại vì nó biến một vai trò **hành
chính** thành cửa sau vào dữ liệu vận hành của mọi phân vùng, và không request nào báo ra điều
đó. Sơ đồ thứ bậc mà quyết định này phục vụ là sơ đồ *ai quản trị việc gán quyền*, không phải
*ai đọc được gì*. Ngày thật sự cần một tài khoản đọc được mọi thứ để soát sự cố, đó là một ADR
riêng với một đường audit riêng.

**Ra hai bản, bản đầu giữ cả tên cũ lẫn tên mới trong bảng vai trò** — loại. Nó xoá được cửa sổ
từ chối sạch ở mục 10, nhưng đổi lại là hai lần triển khai và một khoảng thời gian bảng vai trò
mang hai lối đặt tên cùng lúc — đúng thứ quyết định này sinh ra để dọn. Cửa sổ kia có chặn trên
và tự khỏi, nên nó rẻ hơn.

**Đưa bảng vai trò xuống database để người quản trị tự định nghĩa vai trò** — loại ở ADR này,
vì đó là điều ADR-0010 đã cân và đã loại. Ngày cần, ADR đó sẽ thêm bảng `roles` và đổi
`role_code` thành `role_id`; bảng nối đã đứng sẵn.

**Thêm một cột `module` vào `user_company_roles`** — loại vì tiền tố trong `role_code` đã nói
đủ, đúng như tiền tố trong chuỗi permission đang nói đủ. Một cột thứ hai mang cùng thông tin là
một cột phải giữ cho khớp.

## Consequences

**Được:**

- Một thủ kho ghi được chuyển động mà chỉ thấy vài kho **diễn tả được**, và cái giá là một dòng
  trong nhóm `inventory` chứ không phải một tên trải ngang mười hai module.
- Bảng vai trò lớn theo **module** chứ không theo tổ hợp; người đọc `vaitro.go` thấy chúng nằm
  thành nhóm.
- "Ai được gán vai trò gì" trả lời được bằng chính bộ máy `authz` đang chạy, nên không tầng nào
  phải đọc tên vai trò để suy ra quyền.
- Đường gán vai trò tách khỏi đường sửa hồ sơ, nên quản trị phân quyền không kéo theo quyền đặt
  lại mật khẩu của người khác.

**Mất:**

- Một người đang mang `member` **mất** `auth.user_list` và `auth.user_read`. Siết quyền có chủ
  đích. Kèm theo: ô "Quản trị hệ thống" trong lưới ứng dụng luôn hiện cho mọi người đã đăng
  nhập, nên với `<module>.viewer` nó thành một ô bấm vào là 403.
- `machine.admin` mang quyền cửa `auth.user_assign_scopes` mà **hôm nay không dùng được**: mọi
  request gán phạm vi đều phải liệt kê đủ mọi loại trong danh mục, mà danh mục hiện có đúng một
  loại `warehouse` thuộc `inventory`. Nút "Lưu" ở màn phạm vi vì vậy là một nút chắc chắn 403
  với vai trò đó.
- Frontend **không** nhận permission từ backend và cố ý không ẩn nút theo vai trò, nên mọi khe
  hở trong bảng vai trò đều hiện ra dưới dạng một nút bấm-là-403. Không có đường vá ở frontend;
  chỗ sửa là bảng vai trò.
- `auth.admin` **không còn** cấp được kho cho ai: việc đó từ nay đòi `inventory.scope_assign`.
  Người mang `admin` cũ nhận đủ ba hàng nên họ không mất gì — xem hậu điều kiện ở mục 9.
- Hai quyền cửa có mặt trong mọi `<module>.admin`, nên chúng **không còn** trả lời được câu "ai
  được gán vai trò". Câu đó từ nay do `<module>.role_assign` trả lời. Ai đọc bảng vai trò mà
  dừng ở dòng cửa sẽ đọc ra một kết luận rộng hơn sự thật.
- Người cần đọc nhiều module phải mang nhiều vai trò; claim `roles` trong token dài ra và màn
  quản trị hiện nhiều chip hơn.
- Cửa sổ từ chối sạch tối đa một chu kỳ access token lúc triển khai, xem mục 10.
- Bốn permission mới phải giữ, và mỗi module thêm vào hệ sẽ thêm một `role_assign`.

**Nợ để lại:**

- **ADR-0020 mục 1 phải sửa một câu.** Nó viết "một người hai vai trò có hai bộ phạm vi tách
  biệt"; điều đó đúng ở đường ghi và sai ở đường đọc, vì câu đọc lúc chạy hợp nhất theo người.
  Và **màn gán phạm vi phải vẽ lại** cho khớp: chẻ theo loại phạm vi thay vì theo hàng vai trò.
  Màn hiện tại bày các khối như những bộ tách biệt trong khi chúng cộng vào nhau — người gán
  tick kho ở khối vai trò máy thì người kia vẫn đọc được đúng những kho ấy.
- **`cmd/dev` là composition root thứ hai và cũng phải đổi**: ba hằng tên vai trò thành tám, và
  cờ `-roles` của `bootstrap-user` đang mặc định `"admin"` nên sau quyết định này lệnh chạy mặc
  định sẽ bị `VaiTroTonTai` từ chối. `infra-erp/scripts/bootstrap.sh` mang cùng giá trị.
- **Khuôn tên vai trò chưa có nhà ở tầng Convention.** Phải thêm một dòng vào `C-GO-02` hoặc
  `C-GO-08` chốt `<module>.<vai_trò>`, và ví dụ `Bang()` trong `C-GO-08` trở thành ví dụ lệch
  khuôn, phải sửa theo.
- **Chuỗi vai trò và chuỗi permission từ nay cùng hình dạng**, và không gì trong hệ phân biệt
  được chúng. Hôm nay hai tập sống ở hai chỗ khác nhau nên chưa đụng; ngày có một cửa đọc chung
  thì phải có cách phân biệt.
- `NHAN_VAI_TRO` ở frontend là map mã → chữ chép tay, hôm nay đã thiếu sẵn `quan_tri_he_thong`.
  Nó phải lên tám dòng, và sẽ lệch tiếp mỗi lần bảng vai trò đổi vì không có gì nối hai bên.
- Chưa có màn gán vai trò. Mục 4 mở endpoint cho nó; màn hình là việc của chặng sau.
- Chưa quyết `<module>.admin` có gán được `<module>.admin` của chính module đó không. Mục 4 cho
  phép, vì `<module>.role_assign` không phân biệt vai trò nào trong module.
- Ngày có loại phạm vi **thứ hai**, phải cân lại việc chẻ `PUT /users/:id/scopes` theo loại:
  giữ nguyên hình dạng phủ-cả-người thì một actor thiếu một `<module>.scope_assign` bị chặn
  toàn bộ.
- Mười hai module của ADR-0017 sẽ cần hai đến ba vai trò mỗi cái. Quyết định này chốt **khuôn**,
  không chốt danh sách.

**Constrains:** —
