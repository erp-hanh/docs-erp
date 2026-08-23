# Nháp ADR-0029 - lỗ `auth.admin` tự nhân bản

**Đã chọn phương án A ngày 2026-08-24, và quyết định nằm ở
[ADR-0029](../../03-decisions/ADR-0029-nhan-ban-quan-tri-trong-cung-module.md).** File này giữ
lại làm dấu vết của lần cân nhắc; nguồn sự thật là ADR, không phải file này.

File này đặt hai phương án cạnh nhau để chọn; chọn xong mới sinh
`docs-erp/03-decisions/ADR-0029-<slug>.md` với `Status: Accepted (ngày)`, thêm dòng vào bảng
của `03-decisions/README.md`, rồi chạy `tools/check-ids.ps1`. Viết thẳng một ADR `Accepted`
lúc chưa quyết là ghi một quyết định chưa ai quyết, và ADR thì bất biến nên sửa lại không
được.

Việc này là mục 1 của `2026-08-22-ban-giao-vai-tro-dot-2a.md`.

## Sự việc, đã kiểm trên code

ADR-0024 mục Consequences viết: lỗ *"`<module>.admin` tự nhân bản được"* - nợ ADR-0021 để lại
- **đóng lại như một hệ quả**. Câu đó đúng cho hai trong ba vai trò quản trị ứng dụng và sai
cho cái thứ ba.

Phép kiểm sống ở `kiemGanVaiTro` (`modules/auth/internal/service/user_service.go:1051`): lấy
tập quyền của vai trò được gán, bỏ tập tự tác động (ADR-0028), gom tiền tố module của phần
còn lại, rồi đòi actor có `<module>.role_assign` của **mọi** module gom được.

| Vai trò được gán | Module gom được | Actor cần | `auth.admin` gán được? |
|---|---|---|---|
| `inventory.admin` | `inventory`, `auth` | `inventory.role_assign` + `auth.role_assign` | không - thiếu `inventory.role_assign` |
| `machine.admin` | `machine`, `auth` | `machine.role_assign` + `auth.role_assign` | không |
| `auth.admin` | **chỉ `auth`** | `auth.role_assign` | **có - và nó tự có** |

Tập quyền của `auth.admin` (`cmd/internal/vaitro/vaitro.go:250`) nằm trọn trong module `auth`:
mười mã `auth.*`, trong đó có `auth.role_assign`. Nên phép gom chỉ ra đúng `auth`, và điều
kiện duy nhất để gán nó là thứ chính nó đang cầm. `auth.admin` gán được `auth.admin`.

Hai vai trò kia không nhân bản được **không phải vì có luật chống nhân bản**, mà vì tập quyền
của chúng mượn bốn mã của module `auth` - một tình cờ của nội dung, không phải một quyết định.

`modules/auth/docs/Permission.md` đã ghi đúng điều này từ đợt 2a. Đính chính ở `docs-erp` thì
chưa, và vì ADR bất biến nên nó phải là ADR mới chứ không phải một lần sửa ADR-0024.

## Phương án A - giữ nguyên, phát biểu lại bất biến cho đúng (đề xuất)

**Quyết định:** một vai trò mà tập quyền nằm gọn trong một module vẫn gán được bởi actor giữ
`<module>.role_assign` của chính module ấy, **kể cả khi đó là vai trò actor đang mang**. Hệ
thống không đặt luật chống tăng số người giữ một quyền.

Bất biến mà hệ thống **có** giữ: *không ai phát ra được quyền mà mình không phát được.* Bất
biến mà hệ thống **không** hứa, và ADR-0024 đã lỡ đọc thành có: *số người giữ một quyền không
tăng nếu không có người ở tầng trên.*

Lập luận:

1. **Nhân bản không sinh ra quyền mới.** Người được `auth.admin` gán `auth.admin` nhận đúng
   tập quyền người gán đang có, không hơn một mã. Lỗ mà ADR-0021 ghi vào Nợ để lại là lỗ
   **xuyên module** - một quản trị ứng dụng phát ra quyền của module khác - và lỗ ấy đã đóng
   thật.
2. **Ngăn chặn không đổi được kết cục xấu.** Một `auth.admin` phản chủ đã có `auth.user_delete`
   và `auth.user_assign_roles`: nó xoá được mọi người dùng của phân vùng và gỡ được vai trò
   của họ. Chặn nó tạo thêm admin không giữ lại được gì mà nó chưa phá được.
3. **Cái giá của việc đóng rơi vào ca thường, không vào ca xấu.** Ca thường là công ty muốn
   người thứ hai cùng làm quản trị người dùng. Đóng lỗ nghĩa là mỗi lần như vậy phải gọi tới
   `quan_tri_he_thong`, tức nhà cung cấp, cho một việc thuộc nội bộ khách hàng.

**Mất:** ba vai trò `<module>.admin` không đối xứng nhau, và sự bất đối xứng ấy đọc code mới
thấy. Tài liệu phải nói thẳng: `inventory.admin` và `machine.admin` không nhân bản được **là
hệ quả của nội dung tập quyền**, không phải một luật; ngày ai đó bỏ bốn mã `auth.*` khỏi
`inventory.admin` thì nó nhân bản được ngay, và không phép kiểm nào đỏ.

**Nợ để lại:** đợt 2b mở đường ghi tập quyền. Từ lúc đó, một `auth.admin` sửa được tập quyền
của chính vai trò mình đang mang - vẫn trong giới hạn `auth.role_assign` của nó, nhưng đó là
một hình dạng khác của cùng câu hỏi và phải được cân lại tại chỗ, không suy từ ADR này.

## Phương án B - đóng lỗ: quyền phát quyền chỉ tầng trên phát được

**Quyết định:** gán một vai trò mà tập quyền của nó chứa bất kỳ mã nào trong **tập quyền phát
quyền** - `auth.role_assign`, `inventory.role_assign`, `machine.role_assign`,
`auth.user_assign_roles`, `auth.user_assign_scopes` - chỉ `quan_tri_he_thong` làm được.

Nó khép mô hình lại cho gọn: mọi việc nhân bản quản trị đều do tầng trên quyết, đúng câu
ADR-0024 mục 4 đã viết khi giải thích cái giá của chính nó (*"nhân bản quản trị là việc phải
có người ở tầng trên quyết"*).

Ba cái giá, phải nói trước khi chọn:

1. **Nó phá `cmd/dev bootstrap-user`.** Lệnh ấy dựng một actor mang `vaiTroBootstrap` chứ
   không mang `quan_tri_he_thong` (`cmd/dev/bootstrap.go:156`), rồi gán `-roles admin` cho
   tài khoản đầu tiên. Theo luật này, đường tạo tài khoản đầu tiên của hệ thống nhận 403. Chữa
   được - cho actor bootstrap mang thêm vai trò dẫn xuất - nhưng đó là thêm một ngoại lệ nữa
   vào đúng chỗ ADR-0023 và ADR-0019 đã phải rào kỹ.
2. **Nó là phép kiểm đầu tiên đọc TÊN vai trò để quyết thẩm quyền** kể từ ADR-0024, dù chỉ đọc
   đúng một tên và là tên hệ thống tự dẫn xuất chứ không do người gõ. Ranh giới ấy mỏng và
   phải được nói thẳng, vì lần sau sẽ có người viện nó.
3. **Nó biến mọi lần thêm quản trị người dùng thành một việc phải leo lên nhà cung cấp.**

## Khác biệt thi công

| | A | B |
|---|---|---|
| Code | không dòng nào | thêm một vế vào `kiemGanVaiTro`, sửa actor của `bootstrap-user`, hằng tập quyền phát quyền tiêm từ composition root |
| Test | không | ca `auth.admin` gán `auth.admin` -> 403; ca bootstrap còn chạy; ca `inventory.thu_kho` không bị chặn oan |
| Ghi chú phát hành | không | có - thu hẹp quyền lần thứ hai sau đợt 2a |
| Rủi ro để lộ | giữ nguyên hôm nay | thấp hơn về lý thuyết, xem lập luận 2 của A |

## Việc tiếp theo

Chọn A hoặc B. Chọn xong tôi viết ADR-0029 theo `05-templates/ADR-template.md` - phương án
không được chọn vào mục Alternatives kèm đúng lý do loại ở trên - rồi thêm dòng vào bảng
`03-decisions/README.md` (bảng đang ghi "23 ADR" trong khi có 28 dòng, sửa luôn), chạy
`tools/check-ids.ps1`, và mở nhánh trên `docs-erp`.
