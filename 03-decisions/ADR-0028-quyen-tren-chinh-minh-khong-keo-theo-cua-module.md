# ADR-0028: Quyền chỉ tác động lên CHÍNH NGƯỜI GIỮ nó không kéo theo cửa `<module>.role_assign`

**Status:** Accepted (2026-08-22)

## Context

[ADR-0024](ADR-0024-tham-quyen-tren-vai-tro-tinh-tu-tap-quyen.md) chốt hôm nay rằng thẩm
quyền để gán một vai trò tính từ **tập quyền** vai trò đó chứa, không từ mã của nó. Mục 3
viết:

> Gán một vai trò cho một người: actor phải có `<module>.role_assign` của **MỌI** module xuất
> hiện trong tập quyền của vai trò đó.

Câu đó được viết để đóng lỗ `<module>.admin tự nhân bản được` mà ADR-0021 ghi ở mục Nợ để
lại, và để chặn ca một quản trị module này chế ra một vai trò mang quyền của module kia rồi
gán nó.

Lúc thi công, phép đo trên `backend-erp/cmd/internal/vaitro/vaitro.go` cho ra một hệ quả mà
ADR-0024 không lường:

- `auth.self_read` và `auth.change_password` có mặt trong **cả tám** vai trò. ADR-0021 mục 2
  gọi chúng là **sàn chung**: mọi vai trò đều mang, không vai trò nào không mang.
- `auth.role_assign` chỉ có ở **hai** vai trò: `auth.admin` và `quan_tri_he_thong`.

Ghép hai dữ kiện: mọi vai trò đều chứa hai mã thuộc module `auth`, nên theo câu chữ của
ADR-0024 mục 3, **gán bất cứ vai trò nào cũng đòi `auth.role_assign`**. Hệ quả là
`inventory.admin` và `machine.admin` không gán được vai trò **nào** — kể cả
`inventory.thu_kho`, một vai trò không mang một mã `auth.*` nào ngoài sàn chung.

Điều đó xoá mô hình **mỗi ứng dụng một quản trị** đang chạy. Mô hình ấy không phải một chi
tiết cài đặt: ADR-0021 mục 2 cấp cho ba vai trò `<module>.admin` đúng hai quyền cửa
(`auth.user_assign_roles`, `auth.user_assign_scopes`) chính là để họ tự phân quyền trong
phạm vi ứng dụng mình, và chủ dự án đã nêu nó thành một yêu cầu bằng lời — *"thường mỗi app
sẽ có một admin"*.

Trạng thái tại thời điểm quyết: ADR-0024 đã Accepted, phần thi công của nó đã viết xong trên
nhánh `feat/vai-tro-dot-2a` nhưng **chưa merge**. ADR là bất biến (`05-templates/ADR-template.md`),
nên câu chữ của ADR-0024 mục 3 không sửa tại chỗ được.

## Decision

**Một permission chỉ tác động lên CHÍNH NGƯỜI GIỮ nó thì không kéo theo cửa
`<module>.role_assign` của module sở hữu nó.**

Phép tính của ADR-0024 mục 3 giữ nguyên, chỉ thu hẹp tập đầu vào: trước khi gom module, bỏ
khỏi tập quyền của vai trò những mã thuộc nhóm **tự tác động**.

**1. Tiêu chí, không phải danh sách.** Một permission thuộc nhóm tự tác động khi hai điều
cùng đúng: nó chỉ cho phép đọc hoặc sửa **bản ghi của chính actor**, và cấp nó cho người khác
**không** làm người đó chạm được tới dữ liệu hay tài khoản của bất kỳ ai khác. Hai mã hôm nay
đạt tiêu chí: `auth.self_read` và `auth.change_password`.

Tiêu chí đứng trước danh sách vì danh sách sẽ dài ra, và một mã mới được thêm vào nhóm này
phải qua đúng phép thử ấy chứ không qua cảm giác "quyền này nhỏ".

**2. Nhóm ấy khai ở composition root, cạnh bảng vai trò.** Cùng chỗ, cùng lý do với
`vaitro.Bang()` (ADR-0010 giữ nguyên phần lập luận về **chỗ đặt**, xem ADR-0023 mục 9): đó là
nơi duy nhất biết cả hằng permission của mọi module lẫn hợp đồng của `authz`. `shared/` không
được import `modules/` (R-04).

**3. Vẫn là phép loại trừ ở tầng THẨM QUYỀN, không phải ở tầng quyền.** Người mang một vai
trò vẫn **có** `auth.self_read` và `auth.change_password` như hôm nay; `authz.Can` không đổi
một dòng. Thứ đổi chỉ là: hai mã đó không còn được tính khi hỏi "ai được phát vai trò này ra".

**4. Ý định gốc của ADR-0024 không suy suyển.** Đối chiếu bằng chính hai ca ADR-0024 dựng ra
để chặn:

- `inventory.admin` gán `inventory.admin`: tập quyền sau khi bỏ sàn chung vẫn còn
  `auth.user_list`, `auth.user_read`, `auth.user_assign_roles`, `auth.user_assign_scopes` —
  bốn mã tác động lên **người khác**. Module `auth` vẫn xuất hiện, vẫn đòi `auth.role_assign`,
  vẫn **bị từ chối**. Lỗ tự nhân bản vẫn đóng.
- `inventory.admin` tạo một vai trò tên `inventory.ke_toan` rồi tick `auth.user_delete`:
  `auth.user_delete` không thuộc nhóm tự tác động, nên vẫn đòi `auth.role_assign`, vẫn bị từ
  chối ở bước ghi.

Thứ được mở lại đúng là ca vô hại: `inventory.admin` gán `inventory.thu_kho`, một vai trò
không mang mã `auth.*` nào ngoài sàn chung.

**5. Áp cho cả đường GHI tập quyền.** ADR-0024 mục 2 gác việc sửa tập quyền của một vai trò
bằng cùng phép gom module trên hiệu đối xứng. Phép loại trừ này áp ở đó luôn — nếu không, một
`inventory.admin` sẽ tick được `inventory.item_create` vào một vai trò nhưng không tick được
`auth.self_read`, một sự bất đối xứng không ai giải thích được.

**6. Danh sách hôm nay đúng hai mã, và mở rộng nó cần một ADR.** Thêm một mã vào nhóm tự tác
động là nới một cửa quyền. Nó phải đi qua đúng phép thử ở mục 1 và được ghi ở một ADR, không
phải một PR.

## Alternatives

**Giữ nguyên ADR-0024, chấp nhận chỉ `auth.admin` gán được vai trò** — loại. Nó an toàn nhất
về chống leo quyền và cũng đơn giản nhất để phát biểu, nhưng nó xoá mô hình mỗi ứng dụng một
quản trị, dồn mọi việc phân quyền của cả hệ về một vai trò. Trong một doanh nghiệp có ba
ứng dụng đang chạy và sẽ có mười hai, đó là một cổ chai do chính ta tạo ra — và nó lật một
yêu cầu chủ dự án đã nêu bằng lời chứ không phải một chi tiết ta tự đặt.

**Bỏ sàn chung khỏi bảy vai trò, cho `authz.Can` cấp hai mã đó cho mọi actor đã đăng nhập** —
loại, dù đây là phương án **sạch nhất về mô hình**: hai quyền ấy vốn không phải quyền của một
vai trò nào, và bỏ chúng khỏi bảng sẽ xoá mười bốn dòng lặp lại trong mỗi công ty.

Lý do loại là phạm vi và thời điểm, không phải đúng sai. Nó đụng `authz.Can` — đường chạy ở
**mọi** request — để thêm một nhánh cho qua không đọc vai trò, đúng lúc `Can` vừa đổi từ đọc
map hằng sang đọc database có cache (ADR-0023 mục 8) và chưa có một ngày chạy thật nào trên
dữ liệu thật. Nó cũng cần một migration gỡ mười bốn dòng mỗi công ty, và ADR-0027 vừa chốt
rằng không cơ chế nào của hệ được ghi vào `role_permissions` của một công ty đã tồn tại — nên
migration ấy sẽ là ngoại lệ đầu tiên của một luật ra đời hôm nay.

Quyết định này **không** loại nó vĩnh viễn: nó là hướng đúng cho ngày `Can` đã ổn định, và
ngày đó nó sẽ làm chính quyết định này thành thừa.

**Cấp `auth.role_assign` cho ba `<module>.admin`** — loại, và đây là phương án nguy hiểm
nhất trong bốn. Nó chữa triệu chứng bằng cách trao đúng quyền mà ADR-0024 dựng ra để giữ:
một `inventory.admin` có `auth.role_assign` thì gán được `auth.admin` cho người khác, tức
leo quyền xuyên module qua một bước.

**Loại trừ theo tiền tố: bỏ mọi mã `auth.*` khỏi phép gom** — loại. Nó chặn được ca này bằng
một dòng, nhưng nó bỏ luôn `auth.user_delete`, `auth.user_assign_roles` — đúng những mã
ADR-0024 dựng ra để chặn. Nó cũng lặp lại đúng sai lầm mà ADR-0024 mục Alternatives đã loại:
để một tiền tố quyết định ranh giới quyền thay vì để bản chất của quyền quyết định.

## Consequences

**Được:**

- Mô hình mỗi ứng dụng một quản trị sống tiếp: `inventory.admin` gán được `inventory.thu_kho`,
  `inventory.viewer`, và mọi vai trò không mang quyền lên người khác.
- Lỗ `<module>.admin tự nhân bản được` vẫn đóng — đối chiếu ở mục 4.
- Phép thử ở mục 1 phát biểu được bằng một câu và trả lời được cho một mã bất kỳ, nên nó dùng
  lại được cho mọi module sau.

**Mất:**

- Luật gán vai trò từ nay có **hai** phần: gom module từ tập quyền, và một danh sách loại trừ.
  Một luật hai phần khó giữ đúng hơn một luật một phần, và danh sách loại trừ là chỗ sẽ có
  người muốn thêm vào.
- Nhóm tự tác động là một tập **do người khai**, không có phép kiểm máy nào bảo đảm một mã
  trong đó thật sự chỉ tác động lên chính người giữ. Sai một dòng ở đó là mở một cửa mà không
  gì báo. Đây là khoản đắt nhất của quyết định này.
- Vẫn còn một bất đối xứng nhỏ: một vai trò **chỉ** chứa sàn chung sẽ gán được bởi bất cứ ai
  có `auth.user_assign_roles`, vì sau khi loại trừ nó còn tập rỗng. Chấp nhận được — vai trò
  ấy không cấp quyền nào lên ai.

**Chưa đóng:**

- Ngày `authz.Can` có đủ thời gian chạy thật, phương án "bỏ sàn chung khỏi bảng" ở mục
  Alternatives nên được lật lại. Nó làm quyết định này thành thừa, và một luật một phần luôn
  hơn một luật hai phần.
