# ADR-0024: Thẩm quyền trên một vai trò tính từ TẬP QUYỀN của nó, không từ tên nó

**Status:** Accepted (2026-08-22)

## Context

[ADR-0023](ADR-0023-vai-tro-xuong-database.md) chuyển ánh xạ vai trò → quyền xuống database
và cho người quản trị của từng công ty **tự tạo vai trò, tự đặt tên, tự tick quyền**. Đợt 1
của nó đã merge và đang chạy trên dev ở `v0.1.0-rc.27`: hai bảng `roles` và
`role_permissions` đã có, mỗi phân vùng đã có bộ bảy vai trò riêng, `authz.Checker` đã đọc từ
database. Đường ghi thì chưa mở — chưa ai tạo được vai trò mới qua API.

ADR-0023 mục Decision viết rằng nó **không** đổi ADR-0021: *"khuôn tên `<module>.<vai_trò>`,
cơ chế `<module>.role_assign` và `<module>.scope_assign`, hai quyền cửa, và điểm neo của phạm
vi đều đứng nguyên — chỉ chỗ **lưu** ánh xạ là đổi."*

Câu đó đúng cho bảy vai trò mặc định và **không trả lời được** cho vai trò thứ tám do người
quản trị tạo ra. Cụ thể, tại thời điểm quyết định này:

`UserService.kiemGanVaiTro` (`backend-erp/modules/auth/internal/service/user_service.go:963`)
gác đường gán bằng bốn vế theo thứ tự: `Can(auth.user_assign_roles)` là cửa vào chung; vai trò
dẫn xuất thì từ chối; `VaiTroTonTai` hỏi vai trò có thật không; rồi **tra một map tĩnh**
`quyenGanVaiTro[r]` để biết phải kiểm `<module>.role_assign` nào.

Map đó derive một lần lúc dựng service từ `DanhMucVaiTro` mà composition root tiêm xuống
(`user_service.go:177`), và danh mục ấy là bảy dòng cứng trong `cmd/internal/vaitro`. Thiếu
khoá thì hàm trả **500** kèm nguyên văn `"loi noi day o composition root"`.

Nghĩa là: ngày đường ghi mở ra, một vai trò do quản trị tạo sẽ **qua được** vế một, vế hai,
vế ba, rồi **chết ở vế bốn với 500**. Không phải 403, không phải 422 — một lỗi nội tại nói
rằng composition root sai, trong khi composition root không sai.

Hướng chữa hiển nhiên nhất — cắt tiền tố của mã vai trò để suy ra module — được nêu ngay
trong `cmd/internal/vaitro/vaitro.go`, và chính file đó **ghi rõ là nó không làm vậy**:
`PermGan` được viết tay cho từng dòng, không ghép chuỗi. ADR-0023 mục 7 nhắc lại cùng nguyên
tắc cho danh mục permission: *"không ghép chuỗi và không cắt tiền tố"*.

Một dữ kiện nữa, và nó là dữ kiện làm đổi cả câu trả lời: **tên vai trò từ ADR-0023 là chuỗi
do người dùng gõ.** `roles.code` do quản trị của công ty đặt. Còn `role_permissions.permission_code`
thì không — ADR-0023 mục 7 chốt rằng đường ghi chỉ nhận mã quyền nằm trong **danh mục hằng
tiêm từ composition root**, dựng từ chính hằng `Perm*` của module sở hữu, và từ chối 422 với
một mã lạ.

Hai chuỗi trông giống nhau — cùng khuôn `<module>.<gì đó>` — nhưng một cái người dùng gõ tự
do, một cái chỉ nhận giá trị code đã khai. Đó là bất đối xứng trung tâm của quyết định này.

## Decision

**Thẩm quyền cần có để tạo, sửa, hoặc gán một vai trò được tính từ TẬP QUYỀN mà vai trò đó
chứa, không từ mã của nó.**

`roles.code` từ nay là **nhãn định danh**, không mang thẩm quyền. Nó vẫn giữ khuôn
`<module>.<vai_trò>` của ADR-0021 như một quy ước đặt tên, vẫn bất biến sau khi tạo, vẫn đi
vào claim `roles` của token và vào `audit_logs`. Nhưng **không phép kiểm quyền nào được đọc
tiền tố của nó.**

**1. Module sở hữu một permission suy từ chính mã permission.** `permission_code` có khuôn
`<module>.<hành động>`, và tập mã hợp lệ là danh mục hằng tiêm từ composition root (ADR-0023
mục 7). Cắt tiền tố của một chuỗi **đã được đối chiếu với danh mục code** là an toàn, vì
người dùng không đặt được giá trị nào ngoài danh mục ấy. Đây chính là chỗ khác với mã vai
trò, và là lý do quyết định này cho phép cắt tiền tố ở một bên mà cấm ở bên kia.

**2. Ghi tập quyền của một vai trò: mỗi permission bị gác bởi module sở hữu chính nó.** Tạo
một vai trò hoặc sửa tập quyền của nó đòi actor có `<module>.role_assign` cho **mọi module
xuất hiện trong hiệu đối xứng** giữa tập cũ và tập mới — cùng khuôn "hiệu đối xứng" mà
`ThayVaiTro` đã dùng cho việc gán vai trò (ADR-0021 mục 4), và vì cùng lý do: một quyền **bị
gỡ** không xuất hiện trong body request, nên kiểm trên tập gửi lên sẽ cho actor gỡ quyền của
module khác mà không ai hỏi.

**3. Gán một vai trò cho một người: actor phải có `<module>.role_assign` của MỌI module xuất
hiện trong tập quyền của vai trò đó.** Không phải một module suy từ tên — mọi module có mặt
thật trong nội dung.

Hệ quả trực tiếp, và nó là điểm của cả quyết định này: **không ai cấp được thứ mình không
cấp được.** Một `inventory.admin` tạo một vai trò tên `inventory.thu_kho_ca_dem` rồi tick vào
đó `auth.user_delete` sẽ bị từ chối ngay ở bước ghi — vì họ không có `auth.role_assign`.
Không có đường nào để một quản trị module này chế ra một vai trò mang quyền của module kia
rồi gán nó.

**4. Bảy vai trò mặc định không được miễn.** Chúng đi qua đúng phép kiểm ấy. Đối chiếu với
hành vi hôm nay: `inventory.admin` có tập quyền chứa `auth.user_list`, `auth.user_read`,
`auth.user_assign_roles`, `auth.user_assign_scopes` — bốn mã thuộc module `auth`. Theo mục 3,
gán vai trò `inventory.admin` cho ai đó sẽ đòi actor có **cả** `inventory.role_assign` **lẫn**
`auth.role_assign`.

Hôm nay việc đó chỉ đòi `inventory.role_assign`, vì `DanhMuc()` viết tay `PermGan` của
`inventory.admin` là `inventory.role_assign`. **Đây là một thay đổi hành vi, và nó được chọn
có ý thức**: bốn mã `auth.*` kia thực sự là quyền của module `auth`, và việc một
`inventory.admin` phát chúng ra cho người khác mà không cần `auth.role_assign` đúng là lỗ
`<module>.admin tự nhân bản được` mà ADR-0021 đã ghi vào mục Nợ để lại và chưa đóng.

Cái giá phải trả, nói ra chứ không giấu: sau quyết định này, **một `inventory.admin` không
còn tự tạo thêm được một `inventory.admin` nữa**. Người duy nhất làm được việc đó là
`quan_tri_he_thong`, vì nó là vai trò duy nhất giữ mọi `<module>.role_assign`. Đó là kết quả
đúng — nhân bản quản trị là việc phải có người ở tầng trên quyết — nhưng nó sẽ được cảm nhận
như một sự thu hẹp quyền vào ngày triển khai, nên nó phải nằm trong ghi chú phát hành chứ
không để người dùng tự phát hiện.

**5. Danh mục `DanhMuc()` và trường `PermGan` bị bỏ.** Sau quyết định này không còn ai hỏi
"vai trò tên X thì cần quyền gì để gán" — câu hỏi ấy đọc từ tập quyền của X trong database.
`quyenGanVaiTro` ở `UserService` và `VaiTroKhaDung.PermGan` mất lý do tồn tại. `DanhMuc()`
còn một việc khác chưa thay được là cấp **nhãn** cho `GET /roles`, và nhãn ấy từ ADR-0023 là
cột `roles.name` trong database — nên `GET /roles` đọc database, và ngoại lệ R-12 đăng ký cho
endpoint đó ở `C-API-07` mục 3 **hết hiệu lực đúng lúc này**, đúng như điều khoản tự huỷ đã
viết sẵn trong nó.

**6. Vai trò dẫn xuất `quan_tri_he_thong` đứng ngoài, không đổi.** Nó không có hàng trong
`roles`, không ai gán được, và `laVaiTroDanXuat` vẫn chặn nó ở đường gán trước mọi phép kiểm
khác. Tập quyền của nó ở lại trong code (ADR-0023 mục 3, thi hành qua
`vaitro.KemVaiTroDanXuat`).

**7. Đọc thì không đổi.** `authz.Can` vẫn hợp tập quyền của mọi vai trò một người đang mang
(ADR-0023 mục 6). Quyết định này chỉ nói về **ai được phát ra quyền gì**, không nói về ai
**có** quyền gì.

## Alternatives

**Cắt tiền tố của mã vai trò để suy module** — loại, và đây là phương án phải loại rõ ràng
nhất vì nó là phương án ai cũng nghĩ tới đầu tiên.

Nó giao cho **người dùng đặt tên** quyết định ranh giới quyền. Một `inventory.admin` tạo vai
trò tên `inventory.ke_toan` rồi tick vào đó `auth.user_delete`: tên nói module `inventory`,
nội dung mang quyền `auth`, và phép kiểm đọc tên sẽ cho qua. Người nhận vai trò đó xoá được
người dùng. Không dòng log nào bất thường, không phép kiểm nào đỏ — vì mọi phép kiểm đều đã
đồng ý.

Chi phí của nó cũng không nhỏ hơn phương án được chọn: cả hai đều phải duyệt một tập chuỗi
và tra một map; khác nhau ở chỗ duyệt tập nào.

**Thêm cột `module` vào bảng `roles`, do đường ghi đặt** — loại, dù nó chặn được ca lách bằng
tên. Nó chỉ dời câu hỏi đi một bước: cột đó vẫn không ràng buộc **nội dung**, nên một vai trò
khai `module = 'inventory'` vẫn chứa được `auth.user_delete`, và ta lại phải kiểm tập quyền
để chặn — tức vẫn phải làm đúng việc của phương án được chọn, cộng thêm một cột phải giữ cho
khớp với nội dung. Một cột dữ liệu nói về nội dung của một bảng khác là một cột sẽ lệch.

**Đòi actor phải TỰ CÓ mọi permission mà vai trò chứa, thay vì có `<module>.role_assign`** —
loại, dù nó là luật chống leo quyền chặt hơn và quen thuộc hơn.

Nó phá cơ chế mà ADR-0021 mục 4 đã dựng có chủ đích: `<module>.role_assign` là **quyền cửa**,
tách bạch với quyền vận hành. Theo phương án này, muốn phát quyền `machine.plan_execute` cho
người khác thì bản thân phải là người thực thi kế hoạch bảo trì — trộn "ai làm việc" với "ai
phân việc", đúng hai thứ ADR-0021 tách ra. Nó cũng làm `quan_tri_he_thong` không phát được
quyền vận hành nào, vì ADR-0021 mục 2 cố ý **không** cho nó permission vận hành của module
nào.

**Để nguyên và chấp nhận 500** — loại. Một lỗi 500 mang chữ "lỗi nội tại ở composition root"
cho một thao tác người dùng làm đúng là lỗi tệ nhất trong ba loại: nó nói sai chỗ hỏng, nó
không nói được cách sửa, và nó sẽ được báo lên như một sự cố hệ thống.

## Consequences

**Được:**

- Lỗ `<module>.admin tự nhân bản được` — nợ ADR-0021 ghi ở mục Nợ để lại — đóng lại như một
  hệ quả, không phải một việc riêng.
- Đường ghi của đợt 2 có một luật phát biểu được bằng một câu, không cần bảng tra: *thẩm quyền
  đọc từ nội dung, không đọc từ tên.*
- Một chỗ chép tay biến mất: `PermGan` trong `DanhMuc()` là bản thứ hai của quan hệ
  "vai trò thuộc module nào", và nó phải giữ khớp bằng tay với tập quyền của chính vai trò đó.

**Mất:**

- **Một `<module>.admin` không tự tạo thêm được một `<module>.admin`.** Thu hẹp quyền có
  thật, phải vào ghi chú phát hành.
- Phép kiểm khi gán một vai trò từ nay đọc tập quyền của nó, tức một lần đọc `role_permissions`
  thay vì một lần tra map trong bộ nhớ. Cache của `authz.Checker` (ADR-0023 mục 8) đã giữ sẵn
  bảng ấy theo phân vùng nên không thêm vòng tới database, nhưng nó buộc `UserService` phải
  hỏi qua `authz` thay vì tự tra — tức `Checker` cần một câu hỏi thứ ba ngoài `Can` và
  `VaiTroTonTai`.
- Thông điệp từ chối khó viết hơn: "bạn không cấp được vai trò này" phải nói ra **module nào**
  đang thiếu, mà một vai trò có thể thiếu nhiều module cùng lúc.

**Chưa đóng, và cố ý không đóng ở đây:**

- **`inventory.warehouse_scope_all` vẫn là một permission cộng dồn theo người**, trong khi
  phạm vi treo theo từng hàng vai trò. Một người bị giới hạn kho A, được gán thêm một vai trò
  bất kỳ có tick ô đó, là thấy mọi kho. Quyết định này khiến ô ấy **tick được bởi bất cứ ai có
  `inventory.role_assign`**, nên nó làm lỗ đó dễ chạm hơn chứ không sửa nó. Cần một ADR riêng,
  và ADR ấy phải nói cả nửa giao diện: `frontend-erp/src/modules/user/api/user-api.ts` hôm nay
  chỉ có vị ngữ cảnh báo cho chiều **gỡ** vai trò, chiều **thêm** thì im lặng.
- **Không có đường đưa permission của một module mới vào vai trò của công ty đã tồn tại.**
  ADR-0023 mục 11 chỉ nạp bộ mặc định cho công ty **mới**.
