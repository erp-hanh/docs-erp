# ADR-0021: Vai trò mang tên module, quyền gán vai trò là permission của module đó, và quản trị hệ thống không phải siêu quyền

**Status:** Proposed (2026-08-21)

## Context

Ở thời điểm quyết, hệ có **ba vai trò gán được** và mỗi cái là một bó quyền trải ngang mọi
module: `admin` mang ba mươi sáu permission của cả `auth`, `machine` lẫn `inventory`;
`member` mang mười bảy; `ky_thuat` mang ba. Tên chúng nằm ở `cmd/internal/vaitro/vaitro.go`,
đúng chỗ [ADR-0010](ADR-0010-bang-vai-tro-o-cmd-internal.md) đã chốt, và được gán theo cặp
(người, phân vùng) vào `user_company_roles` theo [ADR-0019](ADR-0019-phan-vung-la-cong-ty.md)
mục 3.

Ba dấu hiệu cho thấy mô hình bó ngang đã hết chỗ:

**Chuỗi permission có tiền tố module, chuỗi tên vai trò thì không.** `C-GO-02` chốt permission
là `<module>.<hành động>` — `inventory.warehouse_list`. Tên vai trò thì trần: `admin`. Hai lối
đặt tên cho hai thứ nằm cạnh nhau trong cùng một bảng.

**`ky_thuat` thực chất đã là một vai trò của module `machine`**, chỉ là mang tên không có tiền
tố. Ba permission của nó gồm hai của `machine` và một `auth.self_read` để phiên đăng nhập biết
mình thuộc về ai; khối ghi chú của nó trong `vaitro.go` viết rằng nó được gán **kèm** `member`
chứ không thay thế. Mô hình vai-trò-theo-module đã lẻn vào bằng cửa sau.

**Không diễn tả được một quản trị bị giới hạn.** `admin` mang `inventory.warehouse_scope_all`,
nên không có cách nào có một người quản trị kho chỉ thấy vài kho. Chỗ này lộ ra ngay khi màn
gán phạm vi của [ADR-0020](ADR-0020-data-scope-theo-ban-ghi.md) chạy thật: bức ảnh phạm vi của
một `admin` luôn là "toàn phạm vi", và không ô nào tích được.

Và với mười hai module của [ADR-0017](ADR-0017-muoi-hai-module-va-ten-tieng-anh.md), bó ngang
phình theo **tổ hợp**: mỗi lần cần "quản kho nhưng không đụng máy" là một tên vai trò mới trải
ngang, chứ không phải một dòng trong một nhóm.

Cuối cùng, một khoảng trống về cơ chế: hệ **chưa có khái niệm quyền về quyền**. `authz.Can`
trả lời "được làm loại việc này không"; nó không trả lời "được gán vai trò X cho người khác
không". Cửa duy nhất hôm nay là `auth.user_assign_roles`, và nó là tất-cả-hoặc-không: ai có
nó thì gán được mọi vai trò trong bảng.

## Decision

**Vai trò mang tên module; thẩm quyền gán vai trò VÀ gán phạm vi là permission của chính
module sở hữu; quản trị hệ thống đứng trên ở trục quản trị phân quyền và đứng ngoài ở trục dữ
liệu nghiệp vụ.**

**1. Tên vai trò theo khuôn `<module>.<vai_trò>`.** Cùng hình dạng với chuỗi permission mà
`C-GO-02` đã chốt, và cùng lý do: nhìn một chuỗi là biết nó thuộc về ai. `module` là tên thư
mục module theo ADR-0017.

**2. Bảy vai trò cho ba module đang chạy.**

| Vai trò | Gồm gì |
|---|---|
| `auth.admin` | năm quyền CRUD user, `auth.user_assign_roles`, `auth.user_assign_scopes`, `auth.role_assign` |
| `inventory.admin` | mười sáu permission của `inventory` (kể cả `inventory.warehouse_scope_all`), `inventory.role_assign`, `inventory.scope_assign`, `auth.user_list`, `auth.user_read`, hai quyền cửa ở mục 4 |
| `inventory.viewer` | `warehouse_list/read`, `item_list/read`, `movement_list/read`, `balance_read`, `unit_list` |
| `machine.admin` | mười hai permission của `machine`, `machine.role_assign`, `auth.user_list`, `auth.user_read`, hai quyền cửa ở mục 4 — `machine.scope_assign` chưa có vì `machine` chưa có bảng chịu phạm vi |
| `machine.viewer` | `machine_list/read`, `plan_list/read`, `breakdown_read` |
| `machine.ky_thuat` | `plan_execute`, `breakdown_create` |
| `quan_tri_he_thong` | năm quyền `PermCompany*`, mọi `<module>.role_assign`, mọi `<module>.scope_assign`, `auth.user_list`, `auth.user_read` — dẫn xuất, không ai gán được |

`inventory.viewer` **không** có `warehouse_scope_all`: nó là vai trò chịu phạm vi, và người
mang nó phải được cấp kho ở màn gán phạm vi thì mới thấy gì.

**3. `member` bị bỏ. Ai cần đọc module nào thì mang `<module>.viewer` của module đó.** Một vai
trò "thành viên" chung là chỗ mọi quyền đọc của mọi module dồn vào, và nó lớn dần mà không ai
đứng ra chịu trách nhiệm cho lần lớn tiếp theo.

**4. Thẩm quyền gán vai trò là permission `<module>.role_assign`, không suy từ tên vai trò.**
Đường gán kiểm hai bước, đúng khuôn `UpdateUser` đang chạy: câu lệnh **đầu tiên** vẫn là
`Can(actor, PermUserAssignRoles)` — giữ R-15 nguyên vẹn; rồi với **mỗi** vai trò trong danh
sách gửi lên, kiểm thêm `Can(actor, "<module>.role_assign")` với `module` lấy từ tiền tố của
chính vai trò đó.

Đường bị loại là suy thẩm quyền từ chuỗi: "ai mang `inventory.admin` thì gán được mọi vai trò
tiền tố `inventory.`". Nó rẻ hơn một permission, nhưng nó bắt tầng service **đọc tên vai trò để
suy ra quyền** — đúng lối mà `C-TS-06` cấm ở frontend và ADR-0019 mục 5 đã từ chối khi chọn vai
trò dẫn xuất thay vì đọc thẳng một cờ. Với permission thì bảng vai trò vẫn nói thật ai làm được
gì; với suy diễn thì một lần đổi tên vai trò lặng lẽ đổi thẩm quyền.

**Gán PHẠM VI đi cùng khuôn đó**, bằng permission `<module>.scope_assign`. Cửa chung
`auth.user_assign_scopes` — đã chạy từ chặng ADR-0020 — vẫn là câu kiểm **thứ nhất**, vì R-15
đòi câu lệnh đầu tiên không được phụ thuộc thân request; rồi với **mỗi loại phạm vi** có trong
thân, kiểm thêm `Can(actor, "<module>.scope_assign")`.

Module của một loại phạm vi **không** suy ra bằng cách đọc chuỗi: danh mục `LoaiPhamVi` mà
`cmd/api` tiêm xuống module `auth` đã mang sẵn tên permission toàn phạm vi của module sở hữu
(`inventory.warehouse_scope_all`), nên nó chỉ cần mang thêm tên permission gán. Composition
root **khai** module, service không đoán module — cùng lập luận với đoạn ngay trên.

Nếu không có nửa này thì `auth.admin` cấp được kho cho người khác mà không có một mẩu thẩm
quyền nào ở `inventory`, tức đúng thứ quyết định này sinh ra để chặn, chỉ khác là rò qua ngả
phạm vi thay vì ngả vai trò.

**Hai quyền cửa — `auth.user_assign_roles` và `auth.user_assign_scopes` — nằm trong MỌI
`<module>.admin`, không riêng `auth.admin`.** Đây là điều kiện để cả quyết định này chạy được,
không phải một chi tiết cấp phát.

Khuôn hai bước bê từ `UpdateUser` có một khác biệt dễ bỏ sót: ở đó hai permission nằm trong
**cùng một vai trò**, nên cửa và phép kiểm thật luôn đi cùng nhau. Tách chúng sang hai vai trò
thì cửa thành cái chốt khoá ngoài — `inventory.admin` đứng một mình sẽ không gán nổi
`inventory.viewer` lẫn phạm vi kho của chính module nó, vì nó không qua được câu kiểm thứ nhất.
Muốn nó làm được việc thì phải gán kèm `auth.admin`, mà `auth.admin` là quyền tạo sửa xoá MỌI
user của phân vùng. Như vậy là phá đúng mệnh đề "không đụng module khác".

Khi cửa nằm ở mọi module admin, nó đổi nghĩa: từ "được gán bất cứ thứ gì" thành "được dùng
đường gán nói chung". Nó vẫn có việc thật — `inventory.viewer` không bao giờ qua nổi câu kiểm
thứ nhất — còn quyết định gán được CÁI GÌ thì thuộc về permission module.

**5. Module admin mang `auth.user_list` và `auth.user_read`.** Muốn gán vai trò cho ai thì phải
tìm ra người đó, mà hai quyền ấy thuộc `auth`. Ba nhánh trong sơ đồ vì vậy không tách rời: cả
ba đều chạm `auth` ở gốc. Tiền lệ có sẵn là `ky_thuat` mang `auth.self_read` vì cùng loại lý do.

**6. Mọi vai trò mang `auth.self_read` và `auth.change_password`.** Đây là sàn chung, không phải
phần thưởng: một phiên đăng nhập phải nói được nó thuộc về ai, và một người phải đổi được mật
khẩu của chính mình. Quyết định này **vá một khiếm khuyết đang có**: `ky_thuat` hôm nay có
`self_read` nhưng không có `change_password`, nên một người chỉ mang vai trò kỹ thuật không đổi
được mật khẩu của mình.

**7. `quan_tri_he_thong` quản trị được việc GÁN của mọi module, nhưng không đọc được dữ liệu
nghiệp vụ của module nào.** Nó giữ năm quyền `PermCompany*` và **thêm** mọi
`<module>.role_assign`, mọi `<module>.scope_assign`, cùng `auth.user_list` và `auth.user_read`
— tức nó đứng trên các module admin ở trục *quản trị phân quyền*, và đứng **ngoài** trục dữ
liệu nghiệp vụ. Muốn đọc một cái máy hay một dòng sổ kho thì người đó vẫn phải được gán vai trò
của chính phân vùng đó như mọi người khác.

Hai quyền đọc user có mặt ở đây vì cùng lý do đã cho module admin ở mục 5, và vì thiếu chúng
thì cả mục này vô nghĩa: một vai trò gán được mọi vai trò của mọi module mà không mở nổi màn
danh sách người dùng là một quyền **không dùng được** — đúng loại quyền im lặng mà `vaitro.go`
gọi tên. Đổi lại phải nói thẳng cái giá: quản trị hệ thống đọc được danh sách người và hồ sơ
người trong phân vùng đang đăng nhập. Đó là dữ liệu **danh tính**, không phải dữ liệu vận
hành, và nó là tập nhỏ nhất đủ để làm đúng việc mà mục này giao.

Điều này **thay mệnh đề "giữ đúng năm quyền `PermCompany*`" của ADR-0019 mục 5**, và thay một
cách hẹp nhất có thể: phần bị bỏ là con số năm, phần được giữ nguyên là câu "quản trị hệ thống
KHÔNG phải siêu quyền". Vai trò này vẫn là vai trò **dẫn xuất** từ cờ `users.is_system_admin`,
vẫn không bao giờ nằm trong `user_company_roles`, và `laVaiTroDanXuat` vẫn là chỗ chặn nó ở
đường gán.

**8. Chuyển dữ liệu bằng migration, và migration phải dừng lại khi không chắc.** Ánh xạ:
`admin` → `auth.admin` + `machine.admin` + `inventory.admin`; `member` → `machine.viewer` +
`inventory.viewer`; `ky_thuat` → `machine.ky_thuat`.

Phần khó không phải đổi tên mà là **các hàng `user_company_role_scopes`**: phạm vi treo vào
`user_company_roles.id` (ADR-0020 mục 1), nên khi một hàng vai trò tách thành nhiều hàng, mỗi
hàng phạm vi phải bám vào **hàng kế thừa của module sở hữu tài nguyên đó** — `scope_type =
'warehouse'` theo hàng `inventory.*`. Bám nhầm thì phạm vi biến mất im lặng và người dùng thấy
màn hình trống mà không thông điệp nào giải thích. Gặp một `scope_type` không ánh xạ được về
module nào, migration **dừng lại và báo lỗi**, không đoán — cùng cách ADR-0019 mục 2 bắt
migration gộp email dừng khi gặp một email trùng ở nhiều phân vùng.

**Migration tự kiểm một hậu điều kiện trước khi `COMMIT`: không ai mất khả năng đang có.** Cụ
thể, mọi cặp (người, phân vùng) từng có một hàng `admin` còn sống phải có **đủ ba** hàng admin
mới sau khi đổi; thiếu một cặp thì dừng, không commit một nửa.

Mệnh đề đó kiểm được bằng SQL vì ánh xạ vai trò là cố định và biết trước — khác với "quyền",
thứ sống trong code nên một câu SQL không tính ra được. Và nó cần được kiểm chứ không cần được
hứa: người mang `admin` cũ gán được phạm vi nhờ có ĐỒNG THỜI cửa ở một hàng và
`inventory.scope_assign` ở một hàng khác, nên một migration rút gọn xuống hai hàng "cho gọn"
sẽ cắt mất khả năng đó mà không câu lệnh nào báo.

**9. Quyết định này không đổi ADR-0010.** Bảng vai trò vẫn là dữ liệu ở composition root, vẫn
dựng từ hằng permission của module, vẫn không có bảng `roles` trong database. Thứ đổi là tập
tên và cách đặt tên, không phải nơi bảng sống.

## Alternatives

**Giữ vai trò bó ngang, thêm tên mới khi cần** — loại vì nó phình theo tổ hợp chứ không theo
module: "quản kho không đụng máy", "đọc máy không đọc kho", "quản kho và đọc máy" là ba tên
riêng, và với mười hai module thì tập tên lớn nhanh hơn tập việc. Nó cũng không chữa được chỗ
đau đo được hôm nay: `admin` mang `warehouse_scope_all` nên không có admin bị giới hạn theo kho,
và muốn có thì phải đẻ một tên bó ngang nữa.

**Suy thẩm quyền gán từ tiền tố tên vai trò, không thêm permission** — loại, xem mục 4.

**Cho `quan_tri_he_thong` mọi permission của mọi module** — loại vì nó biến một vai trò **hành
chính** thành một cửa sau vào dữ liệu vận hành của mọi phân vùng, và không request nào báo ra
điều đó. Sơ đồ thứ bậc mà quyết định này phục vụ là sơ đồ *ai quản trị việc gán quyền*, không
phải *ai đọc được gì*; gộp hai trục vào một là cách rẻ nhất để mất dấu lần nới quyền tiếp theo.
Ngày thật sự cần một tài khoản đọc được mọi thứ để đi soát sự cố, đó là một ADR riêng với một
đường audit riêng.

**Đưa bảng vai trò xuống database để người quản trị tự định nghĩa vai trò** — loại ở ADR này,
vì đó là điều ADR-0010 đã cân và đã loại, và không có gì trong quyết định này đòi mở lại nó.
Ngày cần, ADR đó sẽ thêm bảng `roles` và đổi `role_code` thành `role_id`; bảng nối đã đứng sẵn.

**Thêm một cột `module` vào `user_company_roles`** — loại vì tiền tố trong `role_code` đã nói
đủ, đúng như tiền tố trong chuỗi permission đang nói đủ. Một cột thứ hai mang cùng thông tin là
một cột phải giữ cho khớp, và ADR-0019 đã trả giá đó một lần với `company_id` vì có lý do bắt
buộc (R-06); ở đây không có lý do nào tương đương.

## Consequences

**Được:**

- Một người quản trị kho bị giới hạn theo kho **diễn tả được**: `inventory.admin` không kèm
  `warehouse_scope_all` là một dòng trong bảng, không phải một tên vai trò mới.
- Bảng vai trò lớn theo **module** chứ không theo tổ hợp: mỗi module thêm hai đến ba dòng, và
  người đọc `vaitro.go` thấy chúng nằm thành nhóm.
- "Ai được gán vai trò gì" trả lời được bằng chính bộ máy `authz` đang chạy, nên không tầng nào
  phải đọc tên vai trò để suy ra quyền.
- Data Scope hợp hơn với mô hình: phạm vi vốn là phạm vi trên tài nguyên **của một module**, và
  giờ nó treo vào một hàng vai trò cũng thuộc đúng module đó.

**Mất:**

- Một người đang mang `member` **mất** `auth.user_list` và `auth.user_read`: hai vai trò viewer
  mới không có chúng. Đây là siết quyền có chủ đích, không phải hệ quả phụ của việc đổi tên.
- Người cần đọc nhiều module phải mang nhiều vai trò. Claim `roles` trong token dài ra theo số
  module, và màn hình quản trị người dùng hiện nhiều chip hơn.
- Mọi vai trò hôm nay đều phải chuyển, kể cả những hàng chưa ai đụng tới. Migration chạm dữ
  liệu đang sống ở `user_company_roles`, ở cột `users.roles` chưa bỏ, và mọi access token đang
  lưu hành mang tên cũ — tối đa mười lăm phút sau khi triển khai vẫn còn token mang `admin`.
- Ba permission mới `<module>.role_assign` là ba chuỗi nữa phải giữ, và mỗi module thêm vào hệ
  sẽ thêm một chuỗi như vậy. `<module>.scope_assign` thì chỉ module nào có bảng chịu phạm vi
  mới cần — hôm nay đúng một cái, `inventory`.
- `auth.admin` **không còn** cấp được kho cho ai: từ nay việc đó đòi `inventory.scope_assign`.
  Đây là siết quyền so với thứ đang chạy trên dev, nơi `auth.user_assign_scopes` một mình là
  đủ. Người đang làm cả hai việc phải mang cả hai vai trò — và người mang `admin` cũ nhận đủ ba
  hàng nên họ không mất gì, xem hậu điều kiện ở mục 8.
- Hai quyền cửa có mặt trong mọi `<module>.admin`, nên chúng **không còn** trả lời được câu
  "ai được gán vai trò". Câu đó từ nay do `<module>.role_assign` trả lời. Ai đọc bảng vai trò
  mà dừng ở dòng cửa sẽ đọc ra một kết luận rộng hơn sự thật.
- `PUT /users/:id/scopes` phủ cả người trong một transaction, nên nó là **tất cả hoặc không**
  xuyên module: một actor chỉ có `inventory.scope_assign` sẽ không lưu được gì một khi thân
  request mang thêm một loại phạm vi của module khác. Hôm nay chưa cắn vì chỉ có một loại.

**Nợ để lại:**

- Chưa có màn gán vai trò. Màn gán phạm vi của ADR-0020 nói với người dùng "gán vai trò trước",
  mà đường duy nhất để làm việc đó hôm nay là `PATCH /users/:id` gõ tay.
- `NHAN_VAI_TRO` ở `frontend-erp/src/app/DropdownTaiKhoan.tsx` là map mã → chữ chép tay, ba
  dòng. Nó phải lên bảy dòng cùng lúc với quyết định này, và nó sẽ lệch tiếp mỗi lần bảng vai
  trò đổi — vì không có gì nối hai bên.
- Mười hai module của ADR-0017 sẽ cần hai đến ba vai trò mỗi cái. Quyết định này chốt **khuôn**,
  không chốt danh sách; mỗi module mở ra sau này tự khai vai trò của nó theo khuôn đó.
- Ngày có loại phạm vi **thứ hai**, phải cân lại việc chẻ `PUT /users/:id/scopes` theo loại.
  Giữ nguyên hình dạng phủ-cả-người thì một actor thiếu một `<module>.scope_assign` sẽ bị chặn
  toàn bộ; chẻ ra thì mất tính nguyên tử mà ADR-0020 đã chọn có ý thức. Đây là một đánh đổi
  chưa tới hạn, không phải một chỗ quên.
- Chưa quyết `<module>.admin` của module này có gán được `<module>.admin` của chính module đó
  không — tức một quản trị kho có tự nhân bản được quyền quản trị kho cho người khác không.
  Mục 4 cho phép, vì `inventory.role_assign` không phân biệt vai trò nào trong module. Ngày cần
  chặn, đó là một permission thứ hai chứ không phải một điều kiện tại chỗ.

**Constrains:** —
