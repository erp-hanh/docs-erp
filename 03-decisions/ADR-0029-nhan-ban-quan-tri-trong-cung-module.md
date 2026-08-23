# ADR-0029: Nhân bản quản trị trong cùng một module là hợp lệ — hệ thống không đặt luật chống tăng số người giữ một quyền

**Status:** Accepted (2026-08-24)

## Context

[ADR-0024](ADR-0024-tham-quyen-tren-vai-tro-tinh-tu-tap-quyen.md) chốt rằng thẩm quyền gán
một vai trò tính từ **tập quyền** của vai trò đó, không từ tên nó. Mục Consequences của nó
viết tiếp rằng lỗ *"`<module>.admin` tự nhân bản được"* — nợ [ADR-0021](ADR-0021-vai-tro-theo-module.md)
ghi ở mục Nợ để lại — **đóng lại như một hệ quả**.

Đợt 2a thi hành ADR-0024 đã merge vào `main` cả ba repo ngày 2026-08-22 và đang chạy trên máy
dev ở `v0.1.0-rc.28`. Lúc đi thử bằng tay trên dev, câu trên lộ ra là **đúng hai phần ba**.

Phép kiểm sống ở `kiemGanVaiTro` (`backend-erp/modules/auth/internal/service/user_service.go:1051`):
lấy tập quyền của vai trò được gán, bỏ tập tự tác động ([ADR-0028](ADR-0028-quyen-tren-chinh-minh-khong-keo-theo-cua-module.md)),
gom tiền tố module của phần còn lại, rồi đòi actor có `<module>.role_assign` của **mọi** module
gom được. Đối chiếu với ba vai trò quản trị ứng dụng, tại thời điểm quyết định này:

| Vai trò được gán | Module gom được | Actor cần | Chính nó gán được nó? |
|---|---|---|---|
| `inventory.admin` | `inventory`, `auth` | `inventory.role_assign` + `auth.role_assign` | không — nó không có `auth.role_assign` |
| `machine.admin` | `machine`, `auth` | `machine.role_assign` + `auth.role_assign` | không |
| `auth.admin` | **chỉ `auth`** | `auth.role_assign` | **có** |

Tập quyền của `auth.admin` (`backend-erp/cmd/internal/vaitro/vaitro.go:250`) nằm trọn trong
module `auth`: mười mã `auth.*`, trong đó có `auth.role_assign`. Phép gom vì vậy chỉ ra đúng
một module, và điều kiện duy nhất để gán vai trò ấy là thứ chính nó đang cầm.

Một dữ kiện nữa, và nó là dữ kiện làm đổi cách đọc cả sự việc: hai vai trò kia không nhân bản
được **không phải vì có luật chống nhân bản**. Chúng bị chặn vì tập quyền của chúng mượn bốn
mã của module `auth` (`user_list`, `user_read`, `user_assign_roles`, `user_assign_scopes`) —
một tính chất của **nội dung**, không phải một quyết định. Ngày ai đó bỏ bốn mã ấy khỏi
`inventory.admin`, nó nhân bản được ngay, và không phép kiểm nào đỏ.

Đường ghi tập quyền (CRUD vai trò, đợt 2b) chưa tồn tại tại thời điểm này: đường ghi duy nhất
vào `role_permissions` vẫn là bộ nạp mặc định lúc mở phân vùng (ADR-0023 mục 11). Nên câu hỏi
đang bàn chỉ có đúng một hình dạng — **đường gán một vai trò cho một người**.

## Decision

**Một vai trò mà tập quyền nằm gọn trong một module vẫn gán được bởi actor giữ
`<module>.role_assign` của chính module ấy, kể cả khi đó là vai trò actor đang mang.**

- Bất biến hệ thống **giữ**: *không ai phát ra được quyền mà mình không phát được.*
- Bất biến hệ thống **không hứa**, và đây là chỗ ADR-0024 mục Consequences đã phát biểu rộng
  hơn thứ nó quyết: *số người giữ một quyền không tăng nếu không có người ở tầng trên.*
- Áp cho đường **gán** vai trò. Đường **ghi** tập quyền của một vai trò chưa có code, và ADR
  này không quyết thay cho nó — xem Nợ để lại.
- Không đổi một chữ nào của ADR-0024 mục Decision. ADR-0024 **không** bị thay thế: quyết định
  của nó — thẩm quyền đọc từ nội dung, không đọc từ tên — đứng nguyên, và ADR này chính là một
  hệ quả đọc kỹ của nó. Thứ được đính chính nằm ở một câu trong mục Consequences, và vì ADR
  bất biến nên đính chính đi bằng một ADR mới chứ không bằng một lần sửa tại chỗ.

Nói cho hết: lỗ mà ADR-0021 ghi vào Nợ để lại là lỗ **xuyên module** — một quản trị ứng dụng
phát ra quyền của module khác. Lỗ ấy đã đóng thật, cho cả ba vai trò. Thứ còn lại và được
quyết ở đây là một câu hỏi khác: một quản trị có được tăng số người giữ **chính quyền của
mình** không. Câu trả lời là có.

## Alternatives

**Đóng lỗ: một vai trò mà tập quyền chứa "quyền phát quyền" — `<module>.role_assign`,
`auth.user_assign_roles`, `auth.user_assign_scopes` — thì chỉ `quan_tri_he_thong` gán được** —
loại, dù nó khép mô hình lại gọn hơn và đúng câu ADR-0024 mục 4 đã viết khi giải thích cái giá
của chính nó (*"nhân bản quản trị là việc phải có người ở tầng trên quyết"*).

Ba lý do, xếp theo sức nặng:

1. **Nó không giữ lại được gì mà kẻ xấu chưa phá được.** Một `auth.admin` phản chủ đã cầm
   `auth.user_delete` và `auth.user_assign_roles`: nó xoá được mọi người dùng của phân vùng và
   gỡ được vai trò của họ. Chặn nó tạo thêm một admin nữa không đổi kết cục xấu nhất — nó chỉ
   đổi số người phải dọn sau đó.
2. **Cái giá rơi vào ca thường, không vào ca xấu.** Ca thường là một công ty muốn người thứ
   hai cùng làm quản trị người dùng. Theo phương án này, mỗi lần như vậy phải gọi tới
   `quan_tri_he_thong` — tức nhà cung cấp — cho một việc thuộc nội bộ khách hàng. Với một hệ
   nhiều phân vùng, đó là một việc thủ công lặp lại không có điểm dừng.
3. **Nó phá đường tạo tài khoản đầu tiên.** `cmd/dev bootstrap-user` dựng actor mang
   `vaiTroBootstrap`, không mang `quan_tri_he_thong` (`backend-erp/cmd/dev/bootstrap.go:156`),
   rồi gán `-roles admin`. Theo luật này, lệnh ấy nhận 403 — đúng cái lệnh sinh ra để phá vòng
   "muốn có actor thì phải có user". Chữa được bằng cách cho actor bootstrap mang thêm vai trò
   dẫn xuất, nhưng đó là thêm một ngoại lệ nữa vào đúng chỗ ADR-0019 mục 5 và ADR-0023 mục 3
   đã phải rào kỹ.

Kèm một chi phí về mô hình: nó sẽ là phép kiểm **đầu tiên đọc tên một vai trò để quyết thẩm
quyền** kể từ ADR-0024. Đọc đúng một tên, và là tên hệ thống tự dẫn xuất chứ không do người
quản trị gõ — nên nó không phá bất đối xứng trung tâm của ADR-0024 — nhưng ranh giới ấy mỏng,
và lần sau sẽ có người viện nó cho một ca không mỏng như vậy.

**Đòi actor phải TỰ CÓ mọi permission mà vai trò chứa** — loại, và ở đây nó còn không đạt mục
tiêu: `auth.admin` tự có đủ mười mã của chính nó, nên luật này cho qua đúng ca đang bàn. Nó đã
bị ADR-0024 mục Alternatives loại vì một lý do khác và lý do đó vẫn đứng: nó trộn "ai làm
việc" với "ai phân việc", hai thứ ADR-0021 mục 4 tách ra có chủ đích.

**Thêm một cờ "vai trò quản trị" vào bảng `roles` rồi chặn theo cờ** — loại, cùng lập luận mà
ADR-0024 đã dùng để loại cột `module`: một cột nói về **nội dung** của một bảng khác là một
cột sẽ lệch, và vẫn phải kiểm tập quyền để chặn ca cờ khai sai.

**Không viết ADR, chỉ sửa `modules/auth/docs/Permission.md`** — loại. Tài liệu module đã ghi
đúng hành vi từ đợt 2a, nhưng câu sai nằm ở mục Consequences của một ADR `Accepted`, và tầng
Decision không sửa tại chỗ được. Để nguyên thì người đọc sau này gặp hai câu ngược nhau ở hai
tầng, và tầng cao hơn là tầng sai.

## Consequences

**Được:**

- Một câu hỏi mà ADR-0024 trả lời ngầm nay được trả lời tường minh, và trả lời đúng phạm vi:
  cái đã đóng là phát quyền **xuyên module**, không phải nhân bản người giữ.
- Không dòng code nào phải sửa. Hành vi trên `v0.1.0-rc.28` đã là hành vi được quyết ở đây.
- Một công ty tự dựng được người quản trị người dùng thứ hai mà không phải gọi nhà cung cấp.

**Mất:**

- **Ba vai trò `<module>.admin` không đối xứng nhau, và sự bất đối xứng ấy phải đọc tập quyền
  mới thấy.** `inventory.admin` và `machine.admin` không nhân bản được là **hệ quả của nội
  dung**, không phải một luật — nên nó không bền: đổi tập quyền của chúng là đổi luôn tính
  chất đó, im lặng.
- Hệ thống không có, và từ nay tuyên bố là không định có, một trần cho số người giữ vai trò
  quản trị của một phân vùng. Ai muốn biết con số đó phải đếm ở `user_company_roles`.

**Nợ để lại:**

- **Đợt 2b — đường ghi tập quyền — phải cân lại chính câu hỏi này ở hình dạng khác**, và ADR
  này cố ý không quyết thay: từ lúc có đường ghi, một `auth.admin` **sửa được tập quyền của
  vai trò mình đang mang**. Luật của ADR-0024 mục 2 (hiệu đối xứng giữa tập cũ và tập mới) đã
  chặn việc nó tự thêm quyền của module khác, nhưng chưa ai xét ca nó tự thêm một mã `auth.*`
  mà chính nó đang có — ca ấy qua được mọi phép kiểm hôm nay.
- **`inventory.admin` và `machine.admin` đang bị chặn bởi một tính chất, không bởi một luật.**
  Ngày nào tập quyền của chúng đổi, hành vi đổi theo mà không ai được báo. Một bài test khoá
  tính chất ấy lại — dạng "gán `<module>.admin` đòi cả `auth.role_assign`" — là việc rẻ và
  chưa làm.
- Điều kiện để quyết định này đứng vững: **`auth.admin` không bao giờ được cấp một mã
  `auth.company_*`**. Năm mã ấy hôm nay chỉ thuộc vai trò dẫn xuất (ADR-0019 mục 5, ADR-0021
  mục 2). Cấp một trong năm cho `auth.admin` là biến việc nhân bản trong một phân vùng thành
  đường leo ra khỏi phân vùng, và lúc đó lập luận ở đây không còn đúng.

**Constrains:** —
