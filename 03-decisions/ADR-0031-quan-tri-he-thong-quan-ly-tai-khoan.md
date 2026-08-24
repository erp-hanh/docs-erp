# ADR-0031: `quan_tri_he_thong` cầm thêm `auth.user_create`, và chỉ thêm đúng mã đó

**Status:** Accepted (2026-08-24)

> **Bản này đã được viết lại một lần.** Bản đầu (cùng ngày) dựng trên một dữ kiện sai: nó tin
> câu *"giữ đúng năm quyền `PermCompany*`"* ở [ADR-0019](ADR-0019-phan-vung-la-cong-ty.md) mục
> 5 và đề xuất thêm **bảy** mã `auth.user_*`. Đọc `cmd/internal/vaitro/vaitro.go` thì vai trò
> đó đang có **mười lăm** quyền, trong đó bốn mã `auth.user_*` đã có sẵn. Câu ở ADR-0019 mục 5
> đã lạc hậu.
>
> Bản đầu được nhận rồi hạ lại về `Proposed` trong cùng ngày, trước khi có dòng code nào. Sửa
> tại chỗ chứ không đắp một ADR đính chính: tài liệu chưa từng được dùng để quyết việc gì, và
> lịch sử git giữ đủ dấu vết.

## Context

Người dùng yêu cầu tách màn phân quyền thành hai cấp
(`99-meta/my-specs/2026-08-24-phan-quyen-hai-cap-spec.md`). Câu hỏi thực tế: **quản trị hệ
thống hôm nay làm được gì trên `users`, và thiếu gì?**

**Tập quyền THẬT của `quan_tri_he_thong`**, đọc từ `backend-erp/cmd/internal/vaitro/vaitro.go`
dòng 366-382 - mười lăm mã:

```
auth.company_list   auth.company_create   auth.company_read
auth.company_update auth.company_delete
auth.role_assign    inventory.role_assign  machine.role_assign
inventory.scope_assign
auth.user_list      auth.user_read
auth.user_assign_roles   auth.user_assign_scopes
auth.change_password     auth.self_read
```

Nên bốn mệnh đề hay được nói ra về vai trò này đều **sai**:

| Tưởng | Thật |
|---|---|
| Nó nhận `403` ở màn phân quyền | Nó có `auth.user_list`, mở được màn đó |
| Nó không gán được vai trò | Nó có **cả ba** `<module>.role_assign` cộng hai quyền cửa. Nó gán được vai trò của **mọi** module - rộng hơn `auth.admin`, thứ chỉ có `auth.role_assign` |
| Nó không gán được phạm vi kho | Nó có `inventory.scope_assign` |
| Nó chỉ có năm quyền `company_*` | Câu đó ở ADR-0019 mục 5, và đã lạc hậu |

**Thứ nó thật sự thiếu, đúng ba mã:** `auth.user_create`, `auth.user_update`,
`auth.user_delete`. So với `auth.admin` (`vaitro.go:250-261`) thì đó là toàn bộ khoảng cách
trên bảng `users`.

**Vòng kín còn lại vì vậy hẹp hơn nhiều so với bản đầu của ADR này.** Nó không phải "không đưa
được ai vào phân vùng" - nó là: **không TẠO được người đầu tiên**. Một phân vùng vừa mở chưa
có hàng `users` nào; `POST /users` đòi `auth.user_create`; `quan_tri_he_thong` không có mã đó,
và cũng chưa có `auth.admin` nào của phân vùng ấy để có. Hôm nay vòng đó phá bằng
`go run ./cmd/dev bootstrap-user` - một lệnh chạy trên máy chủ, không phải đường sản phẩm
(`backend-erp/CLAUDE.md` mục 4 mô tả chính nó).

Ngay sau khi có người đầu tiên, `quan_tri_he_thong` **đã** gán được cho người đó vai trò
`auth.admin`, và từ đó phân vùng tự chủ được. Nên khoảng cách cần lấp đúng bằng **một** mã.

## Decision

**`quan_tri_he_thong` cầm thêm đúng `auth.user_create`. Không thêm `user_update`, không thêm
`user_delete`.**

**1. Tập quyền mới: mười sáu mã** - mười lăm mã ở mục Context, cộng `auth.user_create`.

**2. Vì sao chỉ một mã, không phải ba.** `user_create` là mã duy nhất cần để phá vòng kín; hai
mã kia không mở thêm đường nào mà chỉ nới bề mặt. Sửa và xoá một người trong một phân vùng là
việc của quản trị phân vùng ấy - nếu nhà cung cấp cũng làm được, thì mọi lần dọn dẹp sau này
sẽ mặc định chảy về nhà cung cấp thay vì về khách hàng. Ngày có nhu cầu thật (một phân vùng
mất hết quản trị và cần cứu), đó là một ADR riêng và nó phải nói rõ đường cứu hộ chứ không mở
sẵn cửa.

**3. Hàng rào của ADR-0029 giữ nguyên, và nó đi một chiều.**
[ADR-0029](ADR-0029-nhan-ban-quan-tri-trong-cung-module.md) mục "Nợ để lại" đặt điều kiện:
`auth.admin` **không bao giờ** được cấp một mã `auth.company_*`. ADR này đi chiều ngược lại và
không phá điều kiện đó. Bất đối xứng ấy phản ánh bao hàm sẵn có: `quan_tri_he_thong` vốn đã
xoá được cả một phân vùng, nên thêm quyền tạo một hàng `users` trong đó không đưa nó tới chỗ
nào nó chưa tới được.

**4. Không nới R-15.** Đường mới đi qua đúng một lời gọi
`s.authz.Can(ctx, actor, PermUserCreate)` ở câu lệnh đầu tiên của method public. Không có cửa
`if actor.SystemAdmin`.

**5. Hai phép kiểm bắt buộc.**

- **a.** Test khoá tập quyền của `quan_tri_he_thong` đúng bằng mười sáu mã. Thêm hay bớt một mã
  là đỏ. `cmd/internal/vaitro/vaitro_test.go` đã có khuôn để bám vào.
- **b.** Test khẳng định **không vai trò nào ngoài `quan_tri_he_thong`** cầm bất kỳ mã
  `auth.company_*` nào. Đây là hiện thân bằng máy của hàng rào ADR-0029 - hôm nay hàng rào ấy
  **chỉ được giữ bởi nội dung bảng quyền, không bởi một luật nào**, và chính ADR-0029 mục Mất
  đã nói ra chỗ yếu đó.

Phép kiểm thứ ba của bản đầu (đường ghi `role_permissions` từ chối `422` với mã `company_*`)
**rời khỏi ADR này**: đường ghi đó thuộc đợt 2b và chưa tồn tại, nên một test cho nó là một
test cho code chưa có.

**6. Sửa ADR-0019 mục 5.** Câu *"giữ đúng năm quyền `PermCompany*`"* ở đó đã lạc hậu và là
nguồn của cả một ADR sai. ADR-0019 là `Accepted` và tầng Decision không sửa tại chỗ, nên việc
phải làm là **một ADR đính chính riêng** cho chính câu đó - ADR này không làm thay, chỉ ghi
vào Nợ để lại. Cho tới lúc đó, **`vaitro.go` là nguồn sự thật về tập quyền, không phải
ADR-0019**.

## Alternatives

**Thêm cả ba mã `user_create`, `user_update`, `user_delete`** - loại ở mục Decision 2. Tiện
hơn khi dọn dẹp, nhưng nó biến nhà cung cấp thành nơi mặc định xử lý dữ liệu người dùng của
khách hàng.

**Không thêm gì, giữ `bootstrap-user`** - loại. Nó chỉ chạy được từ máy chủ, nên mỗi lần mở
một khách hàng mới là một lần ssh. Với một hệ nhiều phân vùng, đó là việc thủ công không có
điểm dừng.

**Một cờ `can_create_users` riêng** - loại, cùng lập luận ADR-0019 mục 5 đã dùng khi loại
claim `sys_admin` riêng: một cửa không đi qua `authz.Can` thì không qua được R-15, và bảng
permission thôi nói thật ai làm được gì.

**Cho `quan_tri_he_thong` toàn quyền trên mọi module** - loại. Nó xoá ranh giới module mà
ADR-0001 và ADR-0021 dựng lên, và biến một tài khoản của nhà cung cấp thành thứ ghi được
nghiệp vụ của khách hàng.

## Consequences

**Được:**

- Vòng kín "muốn có người thì phải có người" phá bằng một đường sản phẩm, không bằng một lệnh
  trên máy chủ.
- Thay đổi nhỏ: một dòng trong `vaitro.go` cộng hai test. Không migration, không đổi API.
- Hàng rào của ADR-0029 lần đầu có test đứng sau, thay vì chỉ có nội dung bảng.

**Mất:**

- Tài khoản quản trị hệ thống bị chiếm nay còn **tạo** được người, không chỉ gán vai trò cho
  người đã có. Bề mặt rộng thêm một nhịp. Ai cầm cờ `is_system_admin` phải ít, và `audit_logs`
  của đường tạo người phải được soi thật.
- Bất đối xứng ở mục 3 phải **đọc ADR mới hiểu**. Nhìn bảng permission thì không có gì nói vì
  sao chiều này được mà chiều kia không; phép kiểm 5b là chỗ duy nhất mệnh đề ấy sống được
  bằng máy.

**Nợ để lại:**

- ~~Phép kiểm 5b phải viết trước khi ADR này chuyển sang `Accepted`.~~ **Đã viết** -
  `cmd/internal/vaitro/adr0031_test.go`, kèm một bài thứ ba canh chiều ngược lại (`quan_tri_he_thong`
  phải giữ ĐỦ năm mã `company_*`, không thì 5b vẫn xanh trong khi hệ đã hỏng). Cả ba đã được
  thử phá thật và đỏ đúng bài.
- **ADR-0019 mục 5 phải được đính chính bằng một ADR riêng.** Câu ở đó đã làm sai một ADR; nó
  sẽ làm sai cái tiếp theo.
- Chưa quyết: quản trị hệ thống tạo tài khoản thì mật khẩu đầu tiên đi đường nào. Đặt tay rồi
  đọc cho người dùng là rẻ nhất nhưng mật khẩu qua tay người thứ ba; gửi thư mời thì cần hạ
  tầng gửi thư mà hệ chưa có.
- Đợt 2b vẫn phải tự trả lời câu hỏi riêng: từ lúc có đường ghi tập quyền, một `auth.admin`
  sửa được tập quyền của vai trò mình đang mang (ADR-0029 mục Nợ để lại).

**Constrains:** -