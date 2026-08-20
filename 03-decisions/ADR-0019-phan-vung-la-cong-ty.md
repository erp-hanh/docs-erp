# ADR-0019: Phân vùng là một công ty, vai trò tính theo cặp (người, phân vùng)

**Status:** Accepted (2026-08-17)

## Context

"Phân vùng" là tên tiếng Việt của một công ty trong hệ ERP: mỗi phân vùng là một
`companies`, dữ liệu giữa các phân vùng không lẫn nhau.

Ở thời điểm quyết, khái niệm này chỉ tồn tại ở mockup (`mockup-erp/luong-phan-vung.html`)
và một hằng số triển khai ở frontend (`MA_PHAN_VUNG` đọc từ `VITE_COMPANY_CODE`). Backend
đang là mô hình **một người dùng thuộc đúng một phân vùng**:

- `users` unique theo `(company_id, email)`.
- Access token mang cứng claim `company_id`.
- Refresh token có dạng `<company_id>.<random>`, hàng DB cũng mang `company_id`.
- Đăng nhập bắt buộc gửi `company_code`.

Mockup đòi mô hình khác: một tài khoản vào được nhiều phân vùng, đăng nhập xong mới chọn
phân vùng. Đó là một đổi hướng kiến trúc, không phải một feature - nó chạm luồng đăng
nhập, chạm ràng buộc unique của `users`, và chạm cách vai trò được lưu.

Vì vậy việc được chia hai giai đoạn: giai đoạn một chốt trọn mô hình bằng ADR này rồi thi
công phần không chạm luồng đăng nhập; giai đoạn hai làm hai bảng gán, đăng nhập hai bước
và đổi phân vùng. ADR này **chốt cả phần chỉ thi công ở giai đoạn hai**, để schema của
giai đoạn một không phải làm lại.

## Decision

**Một phân vùng là một hàng `companies`; quyền của một người được tính theo cặp (người,
phân vùng); vai trò cấp hệ thống là một cờ trên `users` và đi vào token dưới dạng một vai
trò dẫn xuất.**

**1. Phân vùng là công ty.** Một phân vùng là một hàng `companies`. Chữ hiển thị trên màn
hình là "phân vùng"; tên bảng, tên cột, tên biến trong code giữ `company` theo C-DB/C-GO.

**2. Một tài khoản toàn hệ thống (giai đoạn hai).** Email là duy nhất toàn hệ thống, một
mật khẩu. `uq_users_email_active(company_id, email)` sẽ bị thay bằng unique trên `email`;
việc bỏ ràng buộc đó thuộc giai đoạn hai. Hệ quả: đổi mật khẩu một lần có tác dụng ở mọi
phân vùng.

Cho tới lúc đó, một email còn xuất hiện được ở nhiều hàng `users` thuộc nhiều phân vùng.
Vì vậy giai đoạn hai phải chốt chính sách gộp **trước khi** viết migration, và migration đó
**dừng lại và báo lỗi** khi gặp một email trùng ở nhiều phân vùng, không tự chọn hàng nào
thắng.

**3. Vai trò tính theo cặp (người, phân vùng) - hai bảng dựng ở giai đoạn hai.** Hai bảng,
thiết kế chuẩn hoá ngay để Data Scope về sau treo được vào một hàng cụ thể:

```
user_companies
  id, company_id, user_id,
  created_at, updated_at, deleted_at, created_by, updated_by
  unique (company_id, user_id) where deleted_at is null

user_company_roles
  id, company_id, user_company_id, role_code TEXT,
  created_at, updated_at, deleted_at, created_by, updated_by
  unique (company_id, user_company_id, role_code) where deleted_at is null
```

Cả hai bảng là bảng nghiệp vụ nên mang `company_id` (R-06), soft delete (R-18) và cột truy
vết (R-17). `user_company_roles` mang `company_id` dù suy ra được từ cha: R-06 không có
ngoại lệ cho suy diễn, và bảng miễn trừ phải vào registry C-DB-04 bằng một ADR - không
đáng.

`users.roles TEXT[]` sẽ bị bỏ ở giai đoạn hai. Ở thời điểm quyết không câu query nào lọc
theo nó, nó chỉ được đọc ra để nhét vào JWT claim, nên việc bỏ là cơ học.

**4. `role_code`, không phải `role_id`.** `role_code` là chuỗi, kiểm với `vaitro.Bang()`
(`backend-erp/cmd/internal/vaitro/vaitro.go`).

Bảng vai trò vẫn sống trong code, vẫn **không** có bảng `roles` trong database, nên ADR này
**không** thay [ADR-0010](ADR-0010-bang-vai-tro-o-cmd-internal.md). Data Scope treo vào
`user_company_roles.id`, dù vai trò còn ở code hay sau này chuyển xuống database.

**5. Vai trò cấp hệ thống là một cờ (giai đoạn một).** `users.is_system_admin BOOLEAN NOT
NULL DEFAULT false`. Đây là **cờ**, không phải một phần tử trong `roles` của phân vùng nào:
quản trị hệ thống đứng ngoài mọi phân vùng.

Chỉ cờ này mở đường tới các thao tác trên chính `companies` - liệt kê, tạo, xem chi tiết,
sửa, vô hiệu hoá. Admin của một phân vùng không thấy phân vùng khác.

Ở giai đoạn một, `users` còn là bảng theo phân vùng, nên một quản trị hệ thống vẫn là một
hàng `users` nằm trong một phân vùng cụ thể. Sau giai đoạn hai khi tài khoản thành toàn hệ
thống, cờ này nằm đúng chỗ mà không phải chuyển.

**Vai trò dẫn xuất.** Cờ trong DB là nguồn sự thật, nhưng thứ đi vào token là một vai trò
suy ra từ nó: lúc cấp token, `is_system_admin = true` thì claim `roles` được thêm
`quan_tri_he_thong`. Trong `vaitro.Bang()`, vai trò này giữ đúng năm quyền
`PermCompanyList`, `PermCompanyCreate`, `PermCompanyRead`, `PermCompanyUpdate`,
`PermCompanyDelete`, và **không bao giờ được gán** trong `user_companies` - nó không phải
vai trò của một phân vùng nào.

Lý do không dùng một claim `sys_admin` riêng: bộ kiểm R-15 (`backend-erp/arch/checks_ast.go`)
bắt câu lệnh **đầu tiên** của mọi method public trên `*Service` phải là một lời gọi
`s.authz.Can(ctx, actor, PermX)`. Một cửa `if !actor.SystemAdmin` không đi qua được luật
đó. Đi bằng vai trò dẫn xuất thì dùng đúng bộ máy authz đang có, và bảng permission nói
thật ai làm được gì; đổi lại phải nhớ rằng vai trò này suy ra chứ không lưu.

**6. `companies` và luật R-06 (giai đoạn một).** `companies` thuộc nhóm `tenant_root` trong
registry C-DB-04, nên nó được miễn `company_id`. Điều ADR này thêm vào là **điều kiện
quyền**: query `companies` **không lọc theo phân vùng nào** là hợp lệ, nhưng chỉ người mang
vai trò dẫn xuất `quan_tri_he_thong` ở mục 5 chạy được nó - vì chỉ vai trò đó giữ năm quyền
`PermCompany*`. Mỗi thao tác đi qua **đúng một** quyền tương ứng của nó, chẳng hạn liệt kê
đi qua `PermCompanyList`. Cửa nằm ở service, dưới dạng một lời gọi `s.authz.Can` theo R-15,
không ở SQL.

R-18 vẫn áp: mọi query đọc `companies` phải có `deleted_at IS NULL`.

**7. Phân vùng bị vô hiệu hoá (giai đoạn một).** Vô hiệu hoá là `deleted_at = now()`. Sau
đó:

- Không đăng nhập được vào phân vùng đó, không chọn được nó (giai đoạn hai).
- Không nhận nghiệp vụ mới.
- Đang làm việc mà phân vùng bị vô hiệu hoá: `POST /auth/refresh` từ chối, người dùng bị
  đá về màn đăng nhập trong tối đa một chu kỳ access token.
- Dữ liệu lịch sử giữ nguyên, không xoá vật lý.

**8. Token danh tính, thi công ở giai đoạn hai.** Luồng giai đoạn hai: đăng nhập -> token
danh tính -> liệt kê phân vùng -> chọn phân vùng -> token gắn phân vùng.

Token danh tính sống **5 phút**, chỉ gọi được hai endpoint: liệt kê phân vùng của mình và
chọn phân vùng. Không gọi được API nghiệp vụ nào.

**9. Thu hồi khi đổi phân vùng.** Đổi phân vùng thì refresh token của phân vùng cũ bị thu
hồi ngay, bằng cơ chế đã có ở bảng `refresh_tokens`: phát refresh token mới cho phân vùng
đích, soft delete hàng của phân vùng cũ. Token không mang `session_id`, không mang
`token_version`.

Access token thì không thu hồi được: nó là JWT stateless, TTL 15 phút, không có blacklist,
và đó là chủ ý đã ghi sẵn thành comment ở `modules/auth/internal/token/token.go`. Sau khi
đổi phân vùng hoặc bị gỡ khỏi một phân vùng, access token cũ còn đọc được phân vùng cũ
**tối đa 15 phút**. Điều đó được chấp nhận: người đó vốn được vào phân vùng cũ, đây là phiên
cũ chưa tắt chứ không phải leo thang quyền. Cắt tức thì cần một ADR riêng dựng blacklist
`jti`.

## Alternatives

**Bảng vai trò thành dữ liệu trong database** (bảng `roles`, `role_permissions`, và
`role_id` thay `role_code`) - loại, vì nó là điều [ADR-0010](ADR-0010-bang-vai-tro-o-cmd-internal.md)
đã cân và đã loại, và ADR này không thay ADR-0010: bảng vai trò vẫn sống trong code, và
`role_code` vẫn là chuỗi kiểm được với `vaitro.Bang()`. Ngày người quản trị cần tự định nghĩa
vai trò lúc chạy thì đó là việc của một ADR mới thay ADR-0010 - ADR đó sẽ thêm bảng `roles`
và đổi `role_code` thành `role_id`, và migration lúc đó nhỏ vì bảng nối đã đứng sẵn.

**Thêm `session_id` hoặc `token_version` vào token để thu hồi khi đổi phân vùng** - loại,
vì `refresh_tokens` đã cho thu hồi theo cặp người dùng + phân vùng, không phải dựng mới:
bảng đã là bảng DB thật với `company_id`, `user_id`, `token_hash` và soft delete; một refresh
token vốn đã gắn đúng một phân vùng; và `SoftDeleteByHash` / `SoftDeleteByUser` đã chạy thật
cho logout và đổi mật khẩu. Dựng thêm một cơ chế nữa là hai nguồn sự thật cho cùng một
việc.

**Blacklist `jti` để cắt access token tức thì** - loại ở ADR này. Nó đổi access token từ
stateless thành có tra cứu, tức đổi một chủ ý đã ghi trong code, nên nó cần một ADR riêng
đứng ra chịu trách nhiệm cho lựa chọn đó.

## Consequences

**Được:**

- Schema của giai đoạn một không phải làm lại: hai bảng gán, cờ `is_system_admin` và cách
  vai trò được tính đã chốt trước khi có migration đầu tiên.
- Một tài khoản, một mật khẩu, cho mọi phân vùng. Đổi mật khẩu một lần là đủ.
- Vai trò cấp hệ thống đi qua đúng bộ máy authz đang có, nên R-15 không phải nới và bảng
  permission vẫn nói thật ai làm được gì.
- Data Scope về sau treo được vào `user_company_roles.id`, cả khi vai trò còn ở code lẫn
  khi nó chuyển xuống database.

**Mất:**

- Vai trò `quan_tri_he_thong` không lưu ở đâu cả - nó suy ra từ một cờ lúc cấp token. Ai
  đọc `user_companies` để trả lời "người này có những vai trò gì" sẽ không thấy nó, và
  phải biết điều đó.
- `user_company_roles.company_id` là dữ liệu suy ra được từ cha. Nó tồn tại để không phải
  xin một miễn trừ trong registry C-DB-04, và cái giá là một cột phải giữ cho khớp.
- Sau khi đổi phân vùng hoặc bị gỡ khỏi một phân vùng, access token cũ còn đọc được phân
  vùng cũ tối đa 15 phút. Đây là điều được chấp nhận có ý thức, không phải chỗ chưa nghĩ
  tới.
- Vô hiệu hoá dùng chính `deleted_at`, nên không có cách nào tách một phân vùng tạm dừng
  khỏi một phân vùng đã bỏ. Giai đoạn một **không có** đường bật lại một phân vùng qua API;
  muốn bật lại thì phải can thiệp trực tiếp vào database. Ngày cần một trạng thái tạm dừng
  thật, phải có cột trạng thái riêng bằng một ADR mới.

**Nợ để lại:**

- Giai đoạn hai phải làm: hai bảng gán ở mục 3, bỏ `uq_users_email_active` và cột
  `users.roles`, đăng nhập hai bước với token danh tính 5 phút, và đường đổi phân vùng.
- Ngày người quản trị cần tự tạo vai trò lúc chạy, quyết định ở mục 4 phải được thay bằng
  một ADR mới thay ADR-0010.
- Ngày cần cắt access token tức thì, phải có một ADR dựng blacklist `jti`.

**Constrains:** —
