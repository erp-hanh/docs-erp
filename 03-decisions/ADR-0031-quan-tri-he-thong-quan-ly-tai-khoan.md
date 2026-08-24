# ADR-0031: Vai trò dẫn xuất `quan_tri_he_thong` cầm thêm tập `auth.user_*`, và hàng rào chỉ đi một chiều

**Status:** Accepted (2026-08-24)

## Context

Người dùng yêu cầu tách màn phân quyền thành hai cấp (spec:
`99-meta/my-specs/2026-08-24-phan-quyen-hai-cap-spec.md`):

- **Cấp 1 — Quản trị hệ thống:** dựng phân vùng, **tạo tài khoản nhân viên**, **bổ nhiệm
  quản trị phân hệ** kèm phạm vi.
- **Cấp 2 — Quản trị phân hệ:** mở quyền Thêm/Sửa/Xoá/Duyệt cho nhân viên trong đúng phân
  hệ mình quản.

Cấp 2 đã chạy được: `inventory.admin`, `machine.admin`, `auth.admin` có thật từ
[ADR-0021](ADR-0021-vai-tro-theo-module.md), và ba vai trò đó cầm sẵn bốn mã `auth.user_list`,
`auth.user_read`, `auth.user_assign_roles`, `auth.user_assign_scopes`
(`backend-erp/migrations/000025_vai_tro_xuong_database.up.sql`).

Cấp 1 thì **không**. [ADR-0019 mục 5](ADR-0019-phan-vung-la-cong-ty.md) chốt rằng vai trò dẫn
xuất `quan_tri_he_thong` giữ **đúng năm** quyền:

```
auth.company_list   auth.company_create   auth.company_read
auth.company_update auth.company_delete
```

Nó không cầm `auth.user_create`, không cầm `auth.user_assign_roles`. Nên hôm nay người quản
trị hệ thống **tạo được một phân vùng rỗng nhưng không đưa được ai vào đó**. Việc tạo tài
khoản và bổ nhiệm đang thuộc `auth.admin` của từng phân vùng — tức thuộc chính khách hàng,
không thuộc nhà cung cấp.

Đó là một vòng kín có thật: một phân vùng mới mở chưa có `auth.admin` nào, mà chỉ `auth.admin`
mới tạo được người, mà tạo `auth.admin` đầu tiên thì cần một người đã có. Hôm nay vòng ấy được
phá bằng `cmd/dev bootstrap-user` — một lệnh CLI chạy trên máy chủ, không phải một đường sản
phẩm.

**Hàng rào phải giữ.** [ADR-0029 mục Nợ để lại](ADR-0029-nhan-ban-quan-tri-trong-cung-module.md)
ghi điều kiện để chính nó đứng vững:

> `auth.admin` không bao giờ được cấp một mã `auth.company_*`. Cấp một trong năm cho
> `auth.admin` là biến việc nhân bản trong một phân vùng thành đường leo ra khỏi phân vùng.

Câu đó nói về chiều **`auth.admin` → `company_*`**. ADR này đi chiều **ngược lại**, và phải
chứng minh chiều ngược lại không mở cùng một lỗ.

## Decision

**Vai trò dẫn xuất `quan_tri_he_thong` cầm thêm bảy mã `auth.user_*`. Hàng rào của ADR-0029
giữ nguyên và chỉ đi một chiều.**

**1. Tập quyền mới.** `quan_tri_he_thong` giữ mười hai mã:

```
auth.company_list    auth.company_create   auth.company_read
auth.company_update  auth.company_delete
auth.user_list       auth.user_read        auth.user_create
auth.user_update     auth.user_delete      auth.user_assign_roles
auth.user_assign_scopes
```

**2. Hàng rào không đối xứng, và đây là mệnh đề trung tâm.**

| Chiều | Cho phép? | Vì sao |
|---|---|---|
| `quan_tri_he_thong` cầm `auth.user_*` | **Có** | Nó vốn đã đứng ngoài mọi phân vùng và đã đọc/sửa/xoá được chính `companies`. Thêm quyền trên `users` không cho nó tới chỗ nào nó chưa tới được. |
| `auth.admin` cầm `auth.company_*` | **Không, mãi mãi** | Đó là đường leo từ trong một phân vùng ra ngoài mọi phân vùng — ADR-0029 đã cân và đã loại. |

Bất đối xứng ấy không phải tuỳ tiện: nó phản ánh đúng bao hàm sẵn có. Ai đã xoá được cả một
phân vùng thì việc chặn họ tạo một tài khoản trong đó không giữ lại được gì.

**3. `quan_tri_he_thong` vẫn KHÔNG BAO GIỜ được gán trong `user_companies`.** Nó suy ra từ cờ
`users.is_system_admin` lúc cấp token, đúng như ADR-0019 mục 5. ADR này không đổi cơ chế, chỉ
đổi tập quyền của vai trò dẫn xuất ấy.

**4. Không nới R-15.** Mọi đường mới đi qua đúng một lời gọi `s.authz.Can(ctx, actor, PermX)`
ở câu lệnh đầu tiên của method public trên `*Service`. Không có cửa `if actor.SystemAdmin`.

**5. Ba phép kiểm bắt buộc, và chúng là phần đắt nhất của ADR này.**

- **a.** Một test khoá tập quyền của `quan_tri_he_thong` đúng bằng mười hai mã ở mục 1 — thêm
  hay bớt một mã là đỏ.
- **b.** Một test khẳng định **không vai trò nào ngoài `quan_tri_he_thong`** cầm bất kỳ mã
  `auth.company_*` nào. Đây là phép kiểm hiện thân của hàng rào ADR-0029, và hôm nay hàng rào
  ấy **chỉ được giữ bởi nội dung của bảng chứ không bởi một luật** — chính ADR-0029 mục Mất đã
  nói ra chỗ yếu đó.
- **c.** Một test khẳng định đường ghi `role_permissions` (đợt 2b) **từ chối 422** khi ai đó
  cố tick một mã `auth.company_*` vào một vai trò thường.

**6. Phạm vi.** ADR này KHÔNG động tới:
- Mô hình một-người-nhiều-phân-vùng (thuộc ADR-0019 giai đoạn hai, chưa thi công).
- Đường ghi tập quyền của một vai trò (đợt 2b).
- Cách tính thẩm quyền gán vai trò ([ADR-0024](ADR-0024-tham-quyen-tren-vai-tro-tinh-tu-tap-quyen.md)
  đứng nguyên: đọc từ tập quyền, không đọc từ tên).

## Alternatives

**Giữ nguyên năm quyền, để việc tạo tài khoản cho `auth.admin` của từng phân vùng** — loại.
Nó giữ nguyên vòng kín ở mục Context: phân vùng mới mở không có ai, mà phải có người mới tạo
được người. Đường phá vòng hiện tại là một lệnh CLI trên máy chủ, và một sản phẩm nhiều phân
vùng không thể mỗi lần mở khách hàng mới lại phải ssh vào máy.

**Thêm một cờ `can_manage_users` riêng cho quản trị hệ thống** — loại, cùng lập luận ADR-0019
mục 5 đã dùng khi loại claim `sys_admin` riêng: một cửa không đi qua `authz.Can` thì không qua
được bộ kiểm R-15, và bảng permission thôi nói thật ai làm được gì.

**Cho `quan_tri_he_thong` toàn quyền trên mọi module (một vai trò siêu người dùng)** — loại.
Nó xoá ranh giới module mà ADR-0001 và ADR-0021 dựng lên, và biến một tài khoản của nhà cung
cấp thành thứ ghi được nghiệp vụ của khách hàng. Quản trị hệ thống dựng **khung** — phân vùng,
tài khoản, bổ nhiệm — chứ không làm nghiệp vụ.

**Tạo tài khoản qua một đường bootstrap riêng chỉ dùng lúc mở phân vùng** — loại. Nó chỉ giải
được lần đầu; lần thứ hai khách hàng cần thêm người thì vẫn tắc, và nó đẻ ra một đường ghi
`users` thứ hai không đi qua `UserService`.

## Consequences

**Được:**

- Vòng kín "muốn có người thì phải có người" được phá bằng một đường sản phẩm, không bằng một
  lệnh CLI trên máy chủ.
- Màn cấp 1 trong spec dựng được: ba tab Phân vùng / Tài khoản / Bổ nhiệm quản trị.
- Hàng rào của ADR-0029 lần đầu có **test** đứng sau, thay vì chỉ có nội dung bảng.

**Mất:**

- **Tài khoản quản trị hệ thống bị chiếm là mất toàn hệ.** Điều đó vốn đã đúng — nó xoá được
  mọi phân vùng — nhưng từ nay nó còn tạo được người và tự gán vai trò, nên đường lạm dụng
  ngắn hơn và ít để lại dấu hơn. Ai cầm cờ `is_system_admin` phải ít, và `audit_logs` cho các
  thao tác này phải được soi thật.
- Bất đối xứng ở mục 2 phải **đọc ADR mới hiểu**. Nhìn vào bảng permission thì `quan_tri_he_thong`
  và `auth.admin` chỉ khác nhau ở năm mã `company_*`, và không có gì trong dữ liệu nói vì sao
  chiều này được mà chiều kia không. Phép kiểm **5b** là chỗ duy nhất mệnh đề ấy sống được
  bằng máy.

**Nợ để lại:**

- **Phép kiểm 5b phải viết trước khi ADR này chuyển sang `Accepted`.** Không có nó, ADR này
  chỉ dời chỗ vấn đề của ADR-0029 chứ không đóng.
- Đợt 2b vẫn phải tự trả lời câu hỏi riêng của nó: một `auth.admin` sửa được tập quyền của vai
  trò mình đang mang, và luật đối xứng của ADR-0024 mục 2 chưa xét ca nó tự thêm một mã
  `auth.*` mà chính nó đang có (ADR-0029 mục Nợ để lại).
- Chưa quyết: quản trị hệ thống tạo tài khoản thì mật khẩu đầu tiên đi đường nào. Đặt tay rồi
  đọc cho người dùng là đường rẻ nhất nhưng để mật khẩu qua tay người thứ ba; gửi thư mời thì
  cần hạ tầng gửi thư mà hệ chưa có. Cần một ADR hoặc một mục spec riêng.

**Constrains:** —
