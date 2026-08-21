# ADR-0023: Ánh xạ vai trò → quyền xuống database, vai trò là dữ liệu cấp công ty do người quản trị tự khai

**Status:** Accepted (2026-08-21)

## Context

Ở thời điểm quyết, ánh xạ vai trò → tập quyền là **dữ liệu trong code**: hàm `Bang()` ở
`backend-erp/cmd/internal/vaitro/vaitro.go:244-363` trả về một `authz.Bang`
(`backend-erp/shared/authz/authz.go:83` — `map[string][]string`), và `authz.New`
(`shared/authz/authz.go:103`) sao lại bảng đó lúc dựng `Checker`. Mọi câu hỏi "người này có
được làm việc kia không" đọc đúng map đó (`shared/authz/authz.go:139`), và mọi câu hỏi "tên
vai trò này có thật không" đọc đúng tập khoá của nó (`shared/authz/authz.go:162`).

Chỗ đó do [ADR-0010](ADR-0010-bang-vai-tro-o-cmd-internal.md) chốt, với một lý lẽ vẫn còn
nguyên giá trị ở phần cơ chế: mọi phần tử trong bảng là một **hằng** lấy từ package gốc của
module, nên xoá hay đổi tên một permission làm **vỡ build** ngay tại composition root chứ
không lộ ra sáu tháng sau dưới dạng một người dùng thật bấm nút và nhận 403
(`cmd/internal/vaitro/vaitro.go:23-26`). Chính ADR-0010 mục Alternatives đã cân đường đưa
bảng xuống database và **loại ở thời điểm đó**, với đúng một lý do: "phải có nhu cầu thật —
hiện chưa có màn hình quản trị vai trò nào, và hệ thống có đúng hai vai trò."

Ba việc từ đó tới nay làm điều kiện ấy hết đúng.

**Thứ nhất, số vai trò đã lên tám.** [ADR-0021](ADR-0021-vai-tro-theo-module.md) mục 2 chốt
tám vai trò cho ba module đang chạy, và chính nó ghi ở mục Nợ để lại rằng mười hai module của
[ADR-0017](ADR-0017-muoi-hai-module-va-ten-tieng-anh.md) "sẽ cần hai đến ba vai trò mỗi cái"
— tức bảng sẽ dài gấp bốn, và mỗi dòng vẫn là một dòng code phải sửa, build lại và triển khai.

**Thứ hai, nhu cầu thật đã tới, và nó tới dưới dạng một câu hỏi cụ thể.** Chủ dự án cần vai
trò `inventory.thu_kho` thêm được và sửa được danh mục vật tư, vì thủ kho là người đầu tiên
chạm vào một mặt hàng mới về và bắt họ gọi một người mang `inventory.admin` giữa ca là một
vòng lặp phải cắt. Nhưng nội dung ba vai trò `inventory` do ADR-0021 mục 2 chốt và ADR là bất
biến, nên một dòng permission cũng đòi một ADR. Câu chủ dự án đặt ra khi nghe điều đó là câu
đúng: *"`item_create`, `item_update` là permission cấu hình được, không gắn cứng vào chức
danh."* Nó không phải một mệnh đề về nghề thủ kho — nó là một mệnh đề về **chỗ đặt** ánh xạ
vai trò → quyền.

**Thứ ba, đối chiếu bên ngoài nói cùng một điều.** MISA để quyền trên danh mục là thứ **cấu
hình được cho từng vai trò**: trong màn phân quyền cho vai trò của họ
(https://helpact.misa.vn/kb/phan-quyen-cho-vai-tro/), nhóm quyền **Danh mục** có dòng "Vật tư,
hàng hóa" với các mức **Thêm / Sửa / Xóa / Xem** tick riêng từng ô. Không mệnh đề nào trong hệ
họ nói "thủ kho thì được thêm vật tư"; người quản trị của từng doanh nghiệp tự khai. Danh mục
vật tư của họ cũng là **cấp công ty**, và họ chặn xoá một dòng danh mục đã dùng bằng một luật
nghiệp vụ chứ không bằng phân quyền — nguyên văn: "không thể xóa dữ liệu danh mục khi dữ liệu
đó đã phát sinh chứng từ"
(https://helpamis.misa.vn/amis-kho-hang/kb/danh-muc-vat-tu-hang-hoa/).

Hai điểm neo đã sẵn sàng đón thay đổi này, và cả hai được đặt ra từ trước với đúng dự liệu đó.
`user_company_roles` (`backend-erp/migrations/000022_create_user_company_roles.up.sql`) mang
`role_code TEXT`, và comment ngay dưới cột giải thích lý do là "ADR-0010 giu bang vai tro song
trong code (`cmd/internal/vaitro/vaitro.go`), khong co bang `roles` nao trong database de tro
toi". `user_company_role_scopes`
(`backend-erp/migrations/000023_create_user_company_role_scopes.up.sql`) treo phạm vi vào
`user_company_roles.id`, và comment đầu file trích ADR-0019 mục 4 nguyên văn: "Data Scope treo
vao user_company_roles.id, **du vai tro con o code hay sau nay chuyen xuong database**". Điểm
neo của cơ chế phạm vi vì vậy không phụ thuộc quyết định này.

Trạng thái còn lại tại thời điểm quyết, ghi ra vì nó chi phối mục Decision: hệ đang chạy
**một khách hàng thật** (ADR-0003 mục Context), `cmd/api` chạy **đúng một instance**
([ADR-0013](ADR-0013-cmd-api-mot-instance.md)), chưa có màn hình quản trị vai trò nào
(ADR-0021 mục Nợ để lại), và vai trò `quan_tri_he_thong` là vai trò **dẫn xuất** không bao giờ
nằm trong `user_company_roles`, chặn bởi `laVaiTroDanXuat`
(`backend-erp/modules/auth/internal/service/permissions.go:104`).

## Decision

**Ánh xạ vai trò → tập quyền chuyển từ code xuống database: một vai trò là một hàng dữ liệu
cấp công ty, do người quản trị của chính công ty đó tạo, đặt tên và tick quyền.**

Quyết định này **thay thế** ADR-0010 (xem mục 9). Nó **không** đổi ADR-0021, ADR-0019 hay
ADR-0020: khuôn tên `<module>.<vai_trò>`, cơ chế `<module>.role_assign` và
`<module>.scope_assign`, hai quyền cửa, và điểm neo của phạm vi đều đứng nguyên — chỉ chỗ
**lưu** ánh xạ là đổi.

**1. Tập mã quyền vẫn là hằng trong code.** `permissions.go` của từng module vẫn là nơi duy
nhất khai chuỗi permission (`modules/inventory/internal/service/permissions.go:28-64` và bản
tương ứng của `auth`, `machine`), và chúng vẫn đi ra ngoài qua `module.go` theo C-GO-08. Lý do
không đổi: một mã quyền không có `authz.Can` nào đọc là một chuỗi vô nghĩa, và tập mã quyền là
hợp đồng **giữa code và code**. Thứ xuống dữ liệu là **ánh xạ vai trò → tập quyền**, không
phải bản thân tập quyền.

**2. Hai bảng mới.**

`roles` — một vai trò gán được:

| Cột | Kiểu | Ghi chú |
|---|---|---|
| `id` | `UUID PK` | |
| `company_id` | `UUID NOT NULL REFERENCES companies(id)` | mục 3 |
| `code` | `TEXT NOT NULL` | khuôn `<module>.<vai_trò>` của ADR-0021, **bất biến sau khi tạo** — mục 5 |
| `name` | `TEXT NOT NULL` | chữ hiển thị, sửa tự do |
| `created_at`/`updated_at`/`deleted_at` | `TIMESTAMPTZ` | R-08, R-18 |
| `created_by`/`updated_by` | `UUID NOT NULL` | R-17 |

`role_permissions` — một dòng là "vai trò này có mã quyền kia":

| Cột | Kiểu |
|---|---|
| `id` | `UUID PK` |
| `company_id` | `UUID NOT NULL REFERENCES companies(id)` |
| `role_id` | `UUID NOT NULL REFERENCES roles(id)` |
| `permission_code` | `TEXT NOT NULL` |
| ba cột thời gian, hai cột audit | theo C-DB-03 |

Cả hai là **bảng nghiệp vụ** theo C-DB-03: không tên nào vào registry C-DB-04, không miễn trừ
gì — có `company_id` (R-06), đủ ba cột thời gian (R-08), đủ hai cột audit (R-17), chịu xoá mềm
(R-18). `company_id` có mặt trên `role_permissions` dù suy ra được từ `roles`, đúng lập luận mà
migration `000022` và `000023` đã dùng cho hai bảng gán: R-06 không có ngoại lệ cho suy diễn,
và mọi câu đọc lọc được theo phân vùng ngay tại bảng lá.

`permission_code` là `TEXT`, **không** khoá ngoại và **không** CHECK liệt kê: tập mã quyền
sống trong code và dài ra theo từng module mới, nên một bảng đích hay một CHECK ở đây bắt mọi
module sau phải kèm một migration — đúng điều C-DB-02 loại bỏ ENUM để tránh. Phép kiểm nằm ở
đường ghi, mục 7.

Hai partial unique index, đều dẫn đầu bằng `company_id` theo C-DB-05:
`uq_roles_company_id_code` trên `roles(company_id, code) WHERE deleted_at IS NULL`, và
`uq_role_permissions_company_id_role_id_permission_code` trên
`role_permissions(company_id, role_id, permission_code) WHERE deleted_at IS NULL`. Partial chứ
không UNIQUE thường vì cùng lý do `000022` đã ghi: bỏ tick một quyền rồi tick lại phải được.

**3. Vai trò là dữ liệu CẤP CÔNG TY.** `roles.company_id` là `NOT NULL`. Mỗi phân vùng có bộ
vai trò của riêng nó; công ty A đổi tập quyền của `inventory.thu_kho` **không** đụng tới công
ty B. Mã vai trò trùng nhau giữa hai công ty là hợp lệ — `uq_roles_company_id_code` dẫn đầu
bằng `company_id`. Giải trình ở mục Alternatives.

Ngoại lệ duy nhất, và nó không phải một hàng: **`quan_tri_he_thong` vẫn là vai trò dẫn xuất**,
suy ra từ cờ `users.is_system_admin` mỗi lần ký token (ADR-0019 mục 5), **không bao giờ** có
một hàng trong `roles` và không bao giờ có một hàng trong `user_company_roles`. Nó đứng ngoài
mọi phân vùng nên nó không có `company_id` để mà thuộc về. Tập quyền của nó ở lại trong code,
đúng chỗ hôm nay, và `laVaiTroDanXuat` (`modules/auth/internal/service/permissions.go:104`)
vẫn là chỗ chặn nó ở đường gán.

**4. `user_company_roles.role_code` đổi thành `role_id UUID NOT NULL REFERENCES roles(id)`.**
Chuỗi mã vai trò từ nay là dữ liệu người quản trị sửa được ở cột `name` và tạo ra ở cột `code`;
một bản sao của chuỗi đó nằm trong bảng gán là một chuỗi phải giữ cho khớp, và R-18 làm nó
lệch trong im lặng. Khoá ngoại cũng trả lại đúng thứ mà `authz.VaiTroTonTai` đang làm bằng tay
ở tầng service (`shared/authz/authz.go:162`) — từ nay database giữ nó.

Kèm theo: `uq_user_company_roles_company_id_user_company_id_role_code` dựng lại thành
`uq_user_company_roles_company_id_user_company_id_role_id`. Tên index là **khoá của phép dịch
23505 sang mã lỗi** (P-ERR, C-API-05) như chính `000022` đã cảnh báo, nên đổi tên index là một
thay đổi code chứ không phải một thay đổi lặng lẽ trong migration.

`user_company_role_scopes` **không đổi một cột nào**: nó treo vào `user_company_roles.id`, và
ADR-0019 mục 4 đã chọn điểm neo đó chính vì tình huống hôm nay.

**5. Vai trò mặc định sửa được, `code` thì không, và xoá bị chặn khi còn người giữ.**

- **Tập quyền của MỌI vai trò sửa được**, kể cả bảy vai trò nạp sẵn. Đó là toàn bộ điểm của
  quyết định này. Không có vai trò nào "chỉ đọc" trong `roles`.
- **`roles.code` bất biến sau khi tạo.** Sửa `name` tự do. Lý do: `code` là chuỗi đi vào claim
  `roles` của token, đi vào bản đồ nhãn `NHAN_VAI_TRO` ở frontend, và đi vào mọi bản ghi
  `audit_logs` đã sinh. Đổi nó sau khi đã dùng là làm hỏng mọi thứ trỏ vào nó, ở đúng nghĩa mà
  hệ này đã áp cho mã vật tư trong cùng đợt.
- **Xoá vai trò là xoá mềm, và bị TỪ CHỐI khi còn ít nhất một hàng `user_company_roles` còn
  sống trỏ tới nó** — 409, cùng lối lập luận và cùng hình dạng câu trả lời với
  `ERR_AUTH_COMPANY_IN_USE` (`backend-erp/shared/errors/codes.go:52-57`): người gọi có đủ
  quyền, chỉ là phải gỡ vai trò khỏi những người đang giữ rồi thử lại. **Không cascade.** Gỡ
  một vai trò khỏi một người là một hành động phải có người quyết, không phải hiệu ứng phụ của
  một lần bấm Xoá ở màn khác.
- Một vai trò nạp sẵn mà công ty không dùng thì **xoá được** như mọi vai trò khác, chừng nào
  không ai giữ nó.

**6. Quyền của nhiều vai trò trên cùng một người là HỢP, không phải giao.** Một người mang hai
vai trò có tập quyền bằng hợp của hai tập. Đây là câu mà tài liệu MISA không phát biểu dứt
khoát, nên nó là câu ta tự quyết và ghi lại ở đây.

Chọn hợp vì ba lẽ, và lẽ thứ hai là lẽ quyết: nó là hành vi hệ đang chạy hôm nay
(`shared/authz/authz.go:139` duyệt mọi vai trò của actor, thấy quyền ở vai trò nào thì cho
qua); ADR-0021 mục 3 bỏ vai trò `member` và bảo "ai cần đọc module nào thì mang
`<module>.viewer` của module đó", tức **cả mô hình vai trò của hệ này chỉ có nghĩa nếu quyền
cộng dồn** — với phép giao, mang thêm một vai trò sẽ **lấy đi** quyền, và một người mang
`inventory.viewer` cộng `machine.viewer` sẽ không đọc được gì cả; và cơ chế phạm vi cũng đã
hợp nhất theo người chứ không theo hàng vai trò (ADR-0021 mục Nợ để lại nói thẳng điều đó).

Hệ quả phải nói ra: **không có cách nào cấm một quyền cụ thể cho một người đã có nó qua một
vai trò khác.** Hệ này không có "vai trò từ chối", và quyết định này cấm thêm nó bằng một PR —
một mô hình vừa cộng vừa trừ là mô hình mà không ai đọc ra được kết quả cuối bằng mắt.

**7. Phép kiểm biên dịch mất đi, và ba thứ thay chỗ nó — không thứ nào thay đủ.** Đây là khoản
đắt nhất của quyết định này và nó được ghi vào chính mục Decision chứ không giấu xuống
Consequences:

- **Ở đường GHI:** endpoint tick quyền chỉ nhận `permission_code` nằm trong **danh mục hằng
  tiêm từ composition root**, và từ chối 422 với một mã lạ. Danh mục đó đi cùng đường mà
  ADR-0021 mục 4 đã mở — `cmd/internal/vaitro` tiêm một danh mục xuống module `auth`, dựng từ
  chính hằng permission của module sở hữu, không ghép chuỗi và không cắt tiền tố. Nghĩa là
  phép kiểm không mất, nó **dời từ lúc biên dịch sang lúc ghi**.
- **Ở CI:** một phép đối soát chạy trên database dựng từ migration cộng bộ nạp mặc định, so
  hai chiều giữa tập hằng permission của ba module và tập `permission_code` phân biệt trong
  `role_permissions`. Mã quyền có trong code mà **không vai trò mặc định nào cấp** → cảnh báo
  (nó có thể là chủ đích, ví dụ `item_delete`). `permission_code` trong dữ liệu **không khớp
  hằng nào** → đỏ, vì đó là một dòng không bao giờ cho qua `authz.Can` được.
- **Cái KHÔNG có gì thay:** dữ liệu do một tenant tự tick nằm ngoài tầm CI. Đổi tên một hằng
  permission trong code từ nay **không** làm gì đỏ đối với những dòng `role_permissions` mà
  khách hàng đã tạo; chúng lặng lẽ thành mã chết, và triệu chứng là một người dùng thật mất
  một quyền họ từng có. Đây là đúng điều ADR-0010 mục Alternatives cảnh báo, và quyết định này
  **chấp nhận** nó, không vá nó. Kỷ luật đi kèm: đổi tên một hằng permission từ nay là một
  thay đổi phải kèm migration dữ liệu, ngang hàng đổi tên một cột.

**8. `authz.Checker` đọc tập quyền từ database, có cache trong tiến trình.** `Can` chạy ở
**mọi** request nên nó không được là một vòng tới database mỗi lần. Cache trong tiến trình là
đủ và không cần Redis vì [ADR-0013](ADR-0013-cmd-api-mot-instance.md) chốt `cmd/api` chạy đúng
một instance — không có bài toán đồng bộ giữa nhiều tiến trình. Cái giá, chấp nhận có chủ
đích: **đổi tập quyền của một vai trò không có hiệu lực tức thì**, nó có hiệu lực sau khi cache
hết hạn. Con số TTL là việc của spec thi công; điều được chốt ở đây là *có cache*, *cache
trong tiến trình*, và *không chặn khởi động `cmd/api` vì một lần đọc phân quyền hỏng*.

Claim `roles` trong token vẫn mang **chuỗi `code`**, không mang `role_id`: token là thứ người
đọc log phải đọc được, và `NHAN_VAI_TRO` ở frontend đang khớp theo chuỗi.

**9. Quan hệ với ADR-0010: THAY THẾ, và đây là phần dễ đọc sai nhất.** Repo này chỉ có một
cách diễn đạt quan hệ giữa hai ADR — trường `Status: Superseded by ADR-00yy`, theo
`docs-erp/05-templates/ADR-template.md` và `docs-erp/03-decisions/README.md` mục "ADR là bất
biến". Không có khái niệm "sửa một phần". Mệnh đề trung tâm của ADR-0010 — "bảng vai trò sống
ở `cmd/internal/vaitro`, và nó là **nguồn sự thật duy nhất** của tập tên vai trò trong toàn hệ
thống" — bị quyết định này lật, nên ADR-0010 mang `Superseded by ADR-0023`.

Nhưng **package `cmd/internal/vaitro` ở lại**, và phải nói rõ nó ở lại làm gì để không ai xoá
nhầm: từ nay nó giữ **bộ giá trị khởi tạo** — bảy vai trò mặc định và tập quyền của từng cái —
cộng danh mục hằng permission mà mục 7 và ADR-0021 mục 4 cần tiêm xuống module `auth`. Toàn bộ
lập luận về **chỗ đặt** của ADR-0010 vẫn đúng nguyên văn cho vai trò mới đó: `shared/` không
được import `modules/` (R-04), quy tắc `internal/` của Go chặn `modules/` với `shared/` chạm
tới nó, và `checkR01` đọc đường dẫn nên package dưới `cmd/` chịu đúng ràng buộc của composition
root mà không checker nào phải sửa. Thứ chết là vai trò "trọng tài lúc chạy" của `Bang()`, không
phải chỗ ngồi của package.

**10. Đường nâng cấp: một migration, tự kiểm trước `COMMIT`.** Cùng khuôn mà ADR-0021 mục 9 đã
dùng và vì cùng lý do — một migration phân quyền hỏng nửa chừng là một hệ không ai đăng nhập
quản trị được:

1. Tạo `roles` và `role_permissions`.
2. Với **mỗi** công ty còn sống trong `companies`, nạp bảy vai trò gán được của ADR-0021 mục 2
   (`auth.admin`, `inventory.admin`, `inventory.thu_kho`, `inventory.viewer`, `machine.admin`,
   `machine.viewer`, `machine.ky_thuat`) cùng tập quyền của chúng. `quan_tri_he_thong` **không**
   được nạp — mục 3.
3. Thêm `user_company_roles.role_id` cho phép `NULL`, backfill bằng `JOIN roles ON
   (roles.company_id, roles.code) = (ucr.company_id, ucr.role_code)`, rồi đặt `NOT NULL`, rồi
   bỏ cột `role_code`, rồi dựng lại partial unique index theo mục 4.
4. Ba hậu điều kiện, thiếu cái nào thì dừng và không commit một nửa: **không** hàng
   `user_company_roles` **còn sống** nào có `role_id IS NULL` sau backfill; số hàng
   `user_company_roles` còn sống trước và sau bằng nhau; và mỗi cặp `(company_id, code)` trong
   `roles` có đúng số dòng `role_permissions` bằng số phần tử của bộ nạp tương ứng.

Hàng `user_company_roles` **đã xoá mềm** trỏ tới một `role_code` không có trong bộ bảy — ví dụ
tên vai trò của thời trước ADR-0021 — không backfill được. Xử lý: để `role_id` của chúng là
`NULL` thì vướng `NOT NULL`; nên chúng bị **xoá cứng** trong chính migration, và điều đó phải
được nói ra chứ không làm lặng lẽ. Đây là ca duy nhất trong migration này mất dữ liệu, nó chỉ
chạm những hàng đã bị thu hồi từ trước, và R-18 nói về đường ghi của ứng dụng chứ không về
migration.

**11. Mở một phân vùng mới sẽ nạp bộ vai trò mặc định trong CÙNG transaction.** Sau quyết định
này, một công ty vừa mở mà chưa có hàng `roles` nào là một phân vùng **không ai gán được vai
trò gì** — kể cả người vừa mở nó. Nên `CreateCompany` của module `auth` nạp bộ mặc định ngay,
lấy từ danh mục mà composition root tiêm xuống (mục 7), không phải từ một bản chép trong
`modules/`.

**12. Ba quyền của thủ kho, là hệ quả áp dụng chứ không phải quyết định riêng.** Trong bộ nạp
mặc định, `inventory.thu_kho` có `inventory.item_create`, `inventory.item_update` và
`inventory.unit_create` — quyền thứ ba do [ADR-0022](ADR-0022-mo-duong-ghi-cho-bang-units.md)
cấp và tới đây mới **dùng được**, vì có `item_create` thì form vật tư mới mở được ở chế độ ghi
và hộp thoại thêm đơn vị tính nằm trong form đó mới hiện ra; dòng chết mà ADR-0022 ghi ở mục
Consequences chấm dứt tại đây. `inventory.item_delete` **không** nằm trong bộ mặc định của vai
trò đó. Cả bốn câu trên là **giá trị khởi tạo**, không phải mệnh đề về nghề thủ kho: một doanh
nghiệp tick khác đi thì hệ chạy đúng theo cái họ tick.

**13. Chặn xoá một vật tư đã phát sinh chuyển động là luật TẦNG NGHIỆP VỤ, không phải chuyện
phân quyền.** Kể cả `inventory.admin` cũng không xoá được một vật tư đã có dòng sổ. Quyền
quyết định ai được **thử**; luật nghiệp vụ quyết định việc có **thành** hay không. Hai thứ nằm
ở hai tầng và quyết định này cấm trộn chúng — đặc biệt cấm cách "giải" bằng việc rút
`item_delete` khỏi một vai trò và coi thế là đã chặn. Luật đó, cùng luật cấm đổi `code` của
một vật tư đã có dòng sổ, thi hành ở service của module `inventory` và áp cho mọi vai trò; chi
tiết thi công ở `backend-erp/docs/superpowers/specs/2026-08-21-thu-kho-quan-ly-danh-muc-design.md`.

## Alternatives

**Giữ nguyên mô hình, chỉ thêm ba permission vào hằng Go của `inventory.thu_kho`** — loại. Đây
là phương án rẻ nhất và nó **giải đúng triệu chứng đã báo**: thủ kho tạo được mã vật tư sau một
PR ba dòng, không migration, không bảng mới, và phép kiểm lúc biên dịch của ADR-0010 còn
nguyên. Loại vì nó trả lời sai câu hỏi. Câu chủ dự án đặt ra không phải "thủ kho có nên tạo
được vật tư không" mà "quyền trên danh mục có phải thứ gắn cứng theo chức danh không", và câu
trả lời là không. Giữ nguyên nghĩa là mỗi lần một doanh nghiệp muốn khác đi thì đó là một ADR,
một PR, một lần build và một lần triển khai — trong khi ở MISA nó là một ô tick. Với mười hai
module của ADR-0017 và hai tới ba vai trò mỗi module, đó là một hàng đợi không bao giờ vơi và
người xếp hàng là khách hàng.

**Vai trò cấp HỆ: một bộ vai trò dùng chung cho mọi công ty, `roles` không có `company_id`** —
loại, và đây là phương án đáng cân nhất.

Lập luận của nó đo được: hệ đang chạy **một** khách hàng thật (ADR-0003 mục Context), nên bảy
hàng cấp hệ so với bảy hàng cấp công ty hôm nay là **cùng một con số**; nó không phải nhân bộ
nạp lên theo số phân vùng ở migration mục 10 bước 2; nó không đòi `CreateCompany` nạp gì (mục
11 biến mất); và nó giữ được một tính chất thật là "cùng một tên vai trò nghĩa giống nhau ở
mọi phân vùng", thứ mà người vận hành nhiều phân vùng sẽ nhớ ơn.

Loại vì cái nó đánh đổi là chính thứ quyết định này sinh ra để mua. Một bảng vai trò cấp hệ mà
người dùng cuối ghi được là **đúng hình dạng đã phải chấp nhận một cách miễn cưỡng cho `units`
ở ADR-0022** — ở đó bảng không có `company_id` nên "một người của phân vùng A gõ một dòng thì
mọi phân vùng thấy nó", và ADR đó ghi thẳng rằng danh mục sẽ bẩn dần và không ai gỡ được. Với
`units` thì cái giá là một ô chọn lộn xộn. Với **phân quyền** thì cái giá là công ty A bỏ tick
`item_create` khỏi `inventory.thu_kho` và thủ kho của công ty B mất quyền — một sự cố an ninh
xuyên tenant do một thao tác hợp lệ của người không liên quan, và không request nào báo ra điều
đó.

Và chi phí đảo ngược thì bất đối xứng đúng như ADR-0022 mục Alternatives đã tính một lần: thêm
`company_id` vào một bảng **đã có dữ liệu người dùng tự khai** buộc phải quyết mỗi hàng thuộc
về ai và đổi khoá duy nhất, trong khi bỏ `company_id` khỏi một bảng chỉ có một tenant là một
migration tầm thường. Chọn cấp công ty hôm nay là trả một khoản nhỏ và biết mình trả; chọn cấp
hệ là hoãn một khoản lớn tới ngày có khách hàng thứ hai — đúng ngày ít có chỗ nhất để chạy một
migration phân quyền.

**Giữ `user_company_roles.role_code TEXT`, đối chiếu theo `(company_id, code)` thay vì thêm
`role_id`** — loại. Nó tránh được bước 3 của mục 10, tức tránh sửa một cột `NOT NULL` trên một
bảng đang chạy và tránh dựng lại một index có tên là khoá của phép dịch lỗi. Loại vì nó để lại
một bản sao chuỗi mà không gì giữ cho khớp: hôm nay `role_code` an toàn vì tập giá trị do lập
trình viên quyết và không đổi lúc chạy; từ mai `code` là dữ liệu người quản trị tạo, và một
hàng gán trỏ tới một vai trò **đã xoá mềm** sẽ đọc ra một chuỗi trông vẫn hợp lệ. Khoá ngoại
biến ca đó thành một lỗi ràng buộc thay vì một quyền lặng lẽ biến mất. ADR-0021 mục Alternatives
cũng đã gọi tên trước đường này: "Ngày cần, ADR đó sẽ thêm bảng `roles` và đổi `role_code`
thành `role_id`; bảng nối đã đứng sẵn."

**Giao thay vì hợp cho người mang nhiều vai trò** — loại vì nó làm vỡ chính mô hình vai-trò-theo-module
mà ADR-0021 dựng: ở đó "ai cần đọc module nào thì mang `<module>.viewer` của module đó", nên
với phép giao, mang `inventory.viewer` cộng `machine.viewer` cho ra tập rỗng. Nó cũng đảo chiều
trực giác của người gán quyền — thêm một vai trò mà người kia **mất** quyền — và không có bảng
nào bày ra được kết quả cuối.

**Thêm khái niệm "vai trò từ chối" (deny) để bù cho việc quyền cộng dồn** — loại. Nó nghe như
thứ giải quyết được khoản mất ở mục 6, nhưng một mô hình vừa cộng vừa trừ đòi một thứ tự ưu
tiên, và thứ tự ưu tiên là thứ không ai đọc ra được từ một màn hình tick. Đường đúng cho ca
"người này không nên có quyền X" là gỡ vai trò mang X ra khỏi họ, hoặc tạo một vai trò hẹp hơn
— cả hai đều rẻ sau quyết định này, vì tạo vai trò từ nay là một thao tác dữ liệu.

**File cấu hình YAML mà cả hai composition root đọc** — loại, và loại vì đúng lý do ADR-0010 đã
nêu: tên permission trong file không được trình biên dịch kiểm nên một lỗi chính tả tạo ra một
vai trò thiếu quyền mà không gì báo. So với database thì nó **tệ hơn ở cả hai đầu**: nó cũng
mất phép kiểm biên dịch, mà lại không mua được thứ database mua — người quản trị vẫn không tự
sửa được lúc chạy, vì sửa file là một lần triển khai.

**Chặn `permission_code` lạ bằng một CHECK hay một bảng `permissions` trong database** — loại.
Nó nghe như đường thay thế phép kiểm biên dịch, nhưng nó chỉ **dời** vấn đề: một bảng
`permissions` cũng phải được nạp từ hằng trong code, nên nó thêm một bản sao thứ ba phải giữ
cho khớp, và ngày một module mới thêm permission thì nó thành một migration bắt buộc cho mỗi
module — đúng điều C-DB-02 đã loại bỏ ENUM để tránh. Phép kiểm ở đường ghi cộng phép đối soát ở
CI (mục 7) mua được cùng thứ mà không sinh bản sao nào.

## Consequences

**Được:**

- Người quản trị của một doanh nghiệp tự khai được vai trò và tự tick được quyền, như MISA.
  "Doanh nghiệp khác có thể muốn khác" từ một câu nói thành một thao tác.
- Bảng vai trò thôi lớn bằng code. Mười hai module của ADR-0017 với hai tới ba vai trò mỗi cái
  không còn là hai tới ba mươi dòng hằng Go và bấy nhiêu lần build.
- Câu "ai đang có quyền gì" trả lời được bằng một câu SQL, trên dữ liệu, không phải bằng cách
  đọc một hàm Go rồi đối chiếu với một cột `TEXT` ở bảng khác.
- Ba quyền của thủ kho tới được đích, và `inventory.unit_create` của ADR-0022 thôi là dòng
  chết — cả chuỗi "thêm đơn vị tính tại chỗ khi đang gõ dở một mã hàng" chạy được đủ từ đầu tới
  cuối với đúng vai trò nó được thiết kế cho.
- Vai trò cấp công ty đóng sẵn một lỗ mà `units` đã phải để ngỏ: một tenant không sửa được
  phân quyền của tenant khác, và điều đó đúng ngay từ hàng đầu tiên chứ không phải sau một
  migration ngày có khách hàng thứ hai.

**Mất:**

- **Phép kiểm lúc biên dịch mất, và không thứ gì thay đủ.** Mục 7 nói hết. Điều còn lại phải
  nhắc: đổi tên một hằng permission từ nay là một thay đổi **kèm migration dữ liệu**, ngang
  hàng đổi tên một cột — chứ không phải một lần đổi tên trong IDE.
- **Đổi phân quyền không có hiệu lực tức thì** (mục 8), nên "tôi vừa bỏ quyền của người đó" và
  "người đó vừa hết quyền" là hai thời điểm khác nhau. Với một lần thu hồi khẩn cấp, đó là một
  cửa sổ thật.
- **Bề mặt tấn công rộng ra một bậc:** trước đây không request nào đổi được ánh xạ vai trò →
  quyền, vì nó là code. Từ nay có một endpoint làm việc đó, và permission canh nó trở thành
  permission nhạy nhất trong hệ.
- **Hai bảng nữa, một migration đụng cột `NOT NULL` của một bảng phân quyền đang chạy**, cộng
  một lần dựng lại index có tên là khoá của phép dịch 23505.
- **`vaitro.Bang()` biến mất khỏi vai trò trọng tài, và cùng nó là thứ đọc-được-bằng-mắt.** Hôm
  nay một người mở `cmd/internal/vaitro/vaitro.go` là thấy toàn bộ phân quyền của hệ trong một
  màn hình, kèm khối ghi chú giải trình từng chỗ lệch. Từ mai thứ đó nằm trong hai bảng, và
  những khối ghi chú kia — vốn là tài liệu thật của mô hình phân quyền — không còn chỗ bám.
- **Mã vai trò trùng giữa hai công ty là hợp lệ nhưng nghĩa có thể khác nhau.** Người vận hành
  nhiều phân vùng đọc `inventory.thu_kho` ở hai chỗ và không được phép giả định chúng giống
  nhau.

**Nợ để lại:**

- **Chưa có màn hình quản trị vai trò, và giờ nó là điều kiện chứ không phải mong muốn.** ADR-0021
  đã ghi khoản nợ "chưa có màn gán vai trò"; quyết định này thêm một màn nữa — màn tạo vai trò và
  tick quyền — và **hai màn đó là thứ duy nhất làm quyết định này có nghĩa**. Cho tới ngày có
  chúng, hệ chạy trên bộ nạp mặc định và mọi thay đổi đi qua `psql`.
- **Spec thi công chưa có, và cố ý chưa có.** Quyết định này chốt hướng; mô hình dữ liệu mới cần
  một vòng thiết kế riêng với chủ dự án trước khi ai chạm vào migration.
- **Khối ghi chú về `role_code` ở `migrations/000022_create_user_company_roles.up.sql` trở thành
  sai** — nó viết "khong co bang `roles` nao trong database de tro toi". Migration cũ là bất biến
  và **không được sửa**; chỗ ghi lại điều đó là ADR này và migration mới.
- **`cmd/dev bootstrap-user` phải đổi:** nó gán vai trò bằng cách tra `vaitro.Bang()`, và từ nay
  phải tra bảng `roles` của đúng phân vùng. `infra-erp/scripts/bootstrap.sh` mang cùng giá trị
  mặc định nên nó lệch theo. ADR-0021 mục Nợ để lại đã cảnh báo đúng chỗ này một lần.
- **`C-GO-08` phải sửa văn bản.** Nó chốt "bảng vai trò sống ở composition root", và mệnh đề đó
  từ nay chỉ còn đúng với **bộ giá trị khởi tạo**. Không sửa trong đợt ra quyết định này — đổi
  một Convention đang được nhiều nơi trích dẫn cần đợt riêng.
- **`NHAN_VAI_TRO` ở frontend là bản đồ mã → chữ chép tay**, và từ nay tập mã là **mở**: người
  quản trị tạo ra một vai trò mới thì frontend không có nhãn cho nó. Đường đúng là đọc `name`
  từ dữ liệu; hôm nay chưa có endpoint trả nó. ADR-0021 đã ghi khoản nợ này khi tập mã còn
  đóng; giờ nó thành một lỗi hiển thị chắc chắn xảy ra.
- **Phép đối soát ở CI (mục 7) chưa tồn tại**, và nó là điều kiện để khoản "Mất" thứ nhất còn ở
  mức chịu được. Nó phải ra cùng đợt thi công, không phải sau.
- **Xoá mềm một vai trò không chặn được việc tạo lại đúng `code` đó**, vì partial unique index
  chỉ áp cho hàng còn sống. Đó là hành vi đúng (bỏ rồi lập lại phải được) nhưng nó nghĩa là
  `code` không phải một định danh vĩnh viễn qua thời gian, và một câu tra cứu lịch sử theo
  `code` có thể gộp hai vai trò khác nhau làm một.

**Constrains:** —
