# ADR-0027: Bộ mặc định của một module mới vào công ty đã tồn tại bằng một lệnh nạp bù ở mức VAI TRÒ, và không bao giờ ghi vào tập quyền của một vai trò đã có

**Status:** Accepted (2026-08-22)

## Context

[ADR-0023](ADR-0023-vai-tro-xuong-database.md) chuyển ánh xạ vai trò → quyền xuống database.
Đợt 1 của nó đã merge và đang chạy trên dev ở `v0.1.0-rc.27`: hai bảng `roles` và
`role_permissions` đã có, `authz.Checker` đã đọc từ database, và mỗi phân vùng còn sống đã có
bộ bảy vai trò riêng.

Bộ bảy ấy tới được mọi phân vùng bằng **hai** đường, và cả hai đã thi công xong.

Đường thứ nhất là migration. `migrations/000025_vai_tro_xuong_database.up.sql` phần 3 chèn bảy
hàng `roles` cho **mỗi** công ty còn sống bằng một `CROSS JOIN companies`, phần 4 chèn tập
quyền của chúng, và phần 6 gác lại bằng **năm** khối `RAISE EXCEPTION`: không hàng
`user_company_roles` còn sống nào có `role_id IS NULL` sau backfill; số phép gán còn sống trước
và sau bằng nhau; số hàng `roles` bằng bảy nhân số công ty; số dòng quyền của mỗi cặp
`(company_id, code)` đúng bằng bộ nạp; và không phép gán còn sống nào trỏ tới một hàng `roles`
đã xoá mềm.

Đường thứ hai là `CreateCompany`. `backend-erp/modules/auth/internal/service/company_service.go:222`
gọi `s.roleRepo.NapBoMacDinh(ctx, tx, c.ID, actor.UserID, s.boVaiTroMacDinh)` **trong cùng
transaction** với câu chèn hàng `companies` — đúng ADR-0023 mục 11. `NapBoMacDinh`
(`backend-erp/modules/auth/internal/repository/role_repository.go:213`) chạy hai câu
`INSERT ... SELECT ... unnest(...)` và **đếm** cả hai lần, hụt một hàng là trả lỗi bọc
`sql.ErrNoRows`. Giá trị `boVaiTroMacDinh` do composition root tiêm: `cmd/api/main.go:247` và
`cmd/dev/bootstrap.go:149` cùng truyền `vaitro.BoMacDinh()`, và hàm ấy
(`backend-erp/cmd/internal/vaitro/vaitro.go:466`) không gõ tay dòng nào — nó ghép `DanhMuc()`
lấy mã với nhãn, `Bang()` lấy tập quyền.

Hai đường đó phủ **công ty đã có lúc migration chạy** và **công ty mở ra sau đó**. Không đường
nào phủ ca thứ ba: **một công ty đã tồn tại, vào ngày một module mới lên.**

Hệ có mười hai module theo [ADR-0017](ADR-0017-muoi-hai-module-va-ten-tieng-anh.md) và mới chạy
ba — `auth`, `inventory`, `machine`. Mỗi module khai hằng permission của mình ở
`modules/<module>/internal/service/permissions.go` và đưa ra ngoài qua package gốc, nên module
thứ tư sẽ mang theo một tập hằng mới cùng hai tới ba vai trò mặc định mới, và `Bang()`,
`DanhMuc()`, `BoMacDinh()` sẽ dài ra theo. Từ giây đó, `CreateCompany` phát bộ mới cho mọi công
ty mở sau, còn công ty mở trước **không nhận gì**: không hàng `roles` nào mang mã của module thứ
tư, không ai báo, không phép kiểm nào đỏ. Triệu chứng đo được là hai khách hàng chạy cùng một
bản build cho ra hai hành vi khác nhau, và người thua là khách hàng cũ.

Câu "vậy thì nạp bù" không hiển nhiên, vì [ADR-0024](ADR-0024-tham-quyen-tren-vai-tro-tinh-tu-tap-quyen.md)
— Accepted cùng ngày — vừa đặt tập quyền của một vai trò vào tay **người quản trị của chính công
ty đó**: thẩm quyền tính từ tập quyền, `roles.code` chỉ còn là nhãn định danh. ADR-0023 mục 5 đã
chốt trước đó rằng **tập quyền của mọi vai trò sửa được, kể cả bảy vai trò nạp sẵn**, và một vai
trò nạp sẵn mà công ty không dùng thì **xoá được**. Một công ty đã tồn tại vì vậy có thể đã gỡ
tick, đã thêm tick, hoặc đã xoá mềm một vai trò mang đúng mã với thứ sắp nạp.

Vế thứ hai của cùng bài toán đã được nhìn thấy từ trước: **đổi tên hoặc xoá một hằng permission
trong code.** ADR-0023 mục 7 ghi thẳng rằng dữ liệu do một tenant tự tick nằm ngoài tầm CI,
**chấp nhận** điều đó, và để lại một kỷ luật bằng lời: *"đổi tên một hằng permission từ nay là
một thay đổi phải kèm migration dữ liệu, ngang hàng đổi tên một cột."* Cùng mục ấy mô tả một
phép đối soát trên CI. Phép ấy đã thi công, ở `backend-erp/cmd/dev/vaitrodatabase_test.go` — nó
so hai chiều giữa `vaitro.Bang()` và bộ nạp của migration 000025, đọc dữ liệu thật của công ty
`DEFAULT` trên database dựng từ `erp_template`. Chính ghi chú đầu file nói ra giới hạn của nó:
*"Phép so này KHÔNG phủ được dữ liệu do một tenant tự sửa sau đó."* Database của CI dựng từ chuỗi
migration, nên trong nó không bao giờ có một dòng `role_permissions` nào do người thật tick.

Trạng thái còn lại tại thời điểm quyết, ghi ra vì nó chi phối mục Decision: hệ chạy **một khách
hàng thật** (ADR-0003 mục Context) và `cmd/api` chạy **đúng một instance**
([ADR-0013](ADR-0013-cmd-api-mot-instance.md)); `cmd/api/main.go` cố ý không gọi hàm migrate nào
(ghi chú ở `infra-erp/compose/dev.yml`), migration chạy tường minh ở bước 4 của
`infra-erp/scripts/deploy-dev.sh` bằng `go run ./cmd/dev migrate-up`; bảng lệnh `cmd/dev`
(`backend-erp/cmd/dev/commands.go:31-45`) có mười ba lệnh, trong đó `bootstrap-user`,
`grant-system-admin` và `seed-units` là những thao tác dữ liệu một nhát do người vận hành chạy;
`cmd/dev` đã nhập sẵn `cmd/internal/vaitro` và đã dựng sẵn một module `auth` với
`BoVaiTroMacDinh: vaitro.BoMacDinh()`. Đường ghi vai trò qua API thì **chưa mở** — chưa ai tạo
hay sửa được một vai trò nào qua HTTP.

## Decision

**Bộ mặc định của một module mới tới công ty đã tồn tại bằng một lệnh `cmd/dev seed-roles` chạy
tường minh khi triển khai, và đơn vị nó nạp là MỘT HÀNG `roles`: thiếu vai trò thì tạo cả vai trò
lẫn tập quyền mặc định của nó, còn vai trò đã có thì không chạm tới một dòng `role_permissions`
nào.**

**1. Đơn vị nạp là vai trò, không phải quyền.** Với mỗi công ty và mỗi phần tử của
`vaitro.BoMacDinh()`, lệnh hỏi đúng một câu: *phân vùng này đã có hàng `roles` mang mã đó chưa?*
Chưa thì chèn hàng vai trò cộng đủ tập quyền mặc định của nó. Rồi thì **bỏ qua trọn vẹn** —
không thêm, không bớt, không hợp tập, không so sánh.

**2. KHÔNG ghi đè lựa chọn của tenant, không có ngoại lệ nào.** Đây là câu khó nhất của quyết
định này và nó được trả lời dứt khoát: tập quyền của một hàng `roles` đã tồn tại là **dữ liệu
của công ty đó**, ADR-0024 đã đặt nó dưới thẩm quyền của quản trị công ty ấy, và không cơ chế
nào của hệ được ghi vào nó. Một quản trị đã gỡ `inventory.item_delete` khỏi `inventory.thu_kho`
thì sau mọi lần triển khai, mọi lần nạp bù, mọi module mới, ô đó vẫn không được tick lại.

Ranh giới phân định hai ca không phải cảm tính, nó đo được: **một tập quyền tick thiếu là trạng
thái tenant tự sửa được; một vai trò không tồn tại thì không.** Theo ADR-0024 mục 3, tạo một vai
trò đòi actor có `<module>.role_assign` của **mọi** module xuất hiện trong tập quyền của nó. Ngày
module `purchasing` lên, không vai trò nào trong công ty cũ giữ `purchasing.role_assign`, nên
**không quản trị nào của công ty đó tạo nổi vai trò `purchasing` đầu tiên** — đúng thế bí mà
ADR-0023 mục 11 đã gặp với công ty mới, lặp lại một lần cho mỗi module. Lệnh này sinh ra để phá
đúng thế bí ấy, không phải để giữ tenant "cập nhật".

**3. Vai trò đã xoá mềm thì BỎ QUA, không hồi sinh.** Phép hỏi ở mục 1 tra mã vai trò trong phân
vùng **bất kể `deleted_at`**. ADR-0023 mục 5 cho công ty xoá một vai trò nạp sẵn mà họ không
dùng; hồi sinh nó là lật một quyết định của họ, cùng loại với ghi đè tập quyền. Điều này phải nói
tường minh vì database **không** chặn hộ: `uq_roles_company_id_code` là partial index
`WHERE deleted_at IS NULL`, nên một câu chèn không kiểm sẽ tạo ra một `inventory.thu_kho` còn
sống nằm cạnh một `inventory.thu_kho` bia mộ, và cả hai đều hợp lệ với database. Hàng bia mộ mà
migration 000025 phần 5 nạp cho các mã vai trò thời trước ADR-0021 cũng chịu đúng luật này.

**4. Lệnh idempotent, và tính idempotent đến từ chính mục 1 chứ không từ một sổ ghi.** Chạy lần
thứ hai trên cùng một database không ghi hàng nào, vì mọi mã đều đã có hàng. Chạy nó ngay sau khi
`CreateCompany` vừa mở một phân vùng cũng vô hại vì cùng lý do. Lệnh nhận `--company` để làm một
phân vùng, mặc định là **mọi công ty còn sống**, và in ra số vai trò đã nạp cùng số vai trò bỏ
qua cho từng phân vùng — người chạy phải đọc được nó đã làm gì.

**5. Nguồn giá trị là `vaitro.BoMacDinh()`, đúng một bản, dùng chung với `CreateCompany`.** Đây
là lý do lệnh nằm ở `cmd/dev` chứ không ở một migration: `cmd/dev` là composition root, đã nhập
`cmd/internal/vaitro`, và đã dựng sẵn `BoVaiTroMacDinh: vaitro.BoMacDinh()`
(`cmd/dev/bootstrap.go:149`). Nạp bù và mở phân vùng mới vì vậy đọc **cùng một biểu thức**, nên
hai đường không lệch được nhau — mà lệch chính là cả bài toán của ADR này. Hai cột `created_by`
và `updated_by` (R-17) mang system actor của registry C-DB-04, cùng giá trị migration 000025
dùng, vì không có người thật nào đứng sau nội dung được nạp.

**6. Nó là một bước của quy trình triển khai, không phải việc ai nhớ thì làm.**
`infra-erp/scripts/deploy-dev.sh` chạy `seed-roles` ngay sau bước `migrate-up`. Một đợt mang
module mới mà quên bước này cho ra đúng triệu chứng ADR này sinh ra để diệt, nên chỗ đúng của nó
là trong script, cạnh lệnh đã ở đó.

**7. Đổi tên hoặc xoá một hằng permission được cưỡng chế bằng một PHÉP ĐỐI SOÁT CHẠY TRÊN
DATABASE ĐÍCH, không bằng CI.** Cùng lệnh, mỗi lần chạy, so tập `permission_code` phân biệt của
**toàn bộ** `role_permissions` còn sống với danh mục hằng của composition root:

- Một `permission_code` không khớp hằng nào → **thoát khác 0**. Đó là một dòng `authz.Can` không
  bao giờ cho qua được, và nguyên nhân duy nhất tạo ra nó là một hằng vừa bị đổi tên hoặc bị xoá
  mà không kèm migration dữ liệu — đường ghi từ ADR-0023 mục 7 chỉ nhận mã trong danh mục, nên
  bản thân nó không sinh ra được mã lạ.
- Một hằng permission mà không vai trò nào cấp → **cảnh báo**, không đổi mã thoát, đúng như
  ADR-0023 mục 7 đã phân loại.

Vì lệnh chạy trên chính database đang phục vụ chứ không trên một database dựng từ migration, nó
nhìn thấy **dữ liệu tenant tự tick** — đúng chỗ mù mà ADR-0023 mục 7 nói ra và
`cmd/dev/vaitrodatabase_test.go` không với tới. Phải nói thật hình dạng của nó: đây là **máy dò,
không phải cổng chặn**. Nó chạy sau `migrate-up`, nên lúc nó đỏ thì schema mới đã ở trên database
rồi. Thứ nó đổi là một quyền chết im lặng trong sáu tháng thành một đợt triển khai đỏ ngay hôm
đó, và đó là toàn bộ điều nó hứa.

Bài test đối soát ở `cmd/dev/vaitrodatabase_test.go` **ở lại** và không đổi vai: nó giữ khối
`VALUES` của migration 000025 khớp với `Bang()`. Từ nay không migration nào nữa gõ tay bộ nạp
(mục 5), nên nó là bài test của **một** migration lịch sử, không phải khuôn cho những cái sau.

**8. Không có bảng ghi "công ty này đã nhận bộ mặc định của module nào, tới phiên bản nào".** Câu
hỏi ấy đã trả lời được từ dữ liệu sẵn có: "đã nhận chưa" là "có hàng `roles` mang mã đó chưa",
một câu đọc. Một bảng phiên bản là bản sao thứ hai của một sự thật đã nằm trong `roles`, và nó sẽ
lệch đúng cách mà ADR-0024 mục Alternatives đã bác một cột `module` trên bảng `roles`. Nặng hơn:
một số phiên bản mặc định treo trên từng công ty ngụ ý hệ theo dõi tập quyền của tenant qua thời
gian để biết họ "chậm" bao nhiêu so với bản chuẩn — mà chính quyền theo dõi ấy là thứ ADR-0024 đã
trao đi.

**9. Chiều BỚT không thuộc cơ chế này, và ranh giới đặt ở đây.** Lệnh này chỉ **thêm hàng**; nó
không xoá một hàng `role_permissions` nào và không xoá một hàng `roles` nào. Nếu một ADR sau bỏ
một mã permission khỏi danh mục hằng — ADR-0026 đang cân đúng việc đó với
`inventory.warehouse_scope_all` — thì những dòng `role_permissions` mang mã ấy trở thành mã chết,
và thứ xử lý chúng là **phép đối soát ở mục 7 đỏ lên** cộng một **migration dữ liệu** viết trong
chính đợt đó, đúng kỷ luật ADR-0023 mục 7 đặt ra. Quyết định này không quyết thay ADR-0026 rằng
mã ấy có bị bỏ hay không; nó chỉ chốt rằng ngày mã ấy bị bỏ, hệ **kêu** chứ không im.

## Alternatives

**Mỗi module mới kèm một migration nạp bù, theo khuôn phần 3-4 của 000025** — loại, và đây là
phương án có tiền lệ gần nhất nên phải loại rõ.

Nó bắt bộ mặc định phải được **gõ tay lần nữa** trong một khối `VALUES`. Hôm nay đã có hai bản
của cùng một ánh xạ — `Bang()` trong Go và `VALUES` trong 000025 — và chúng **không còn vỡ build
cùng nhau**, nên phải nuôi riêng một bài test đối soát để giữ chúng khớp
(`cmd/dev/vaitrodatabase_test.go`, ghi chú đầu file nói thẳng nó là "thứ duy nhất giữ chúng
khớp"). Với chín module còn lại của ADR-0017, phương án này là chín bản chép tay nữa và chín bài
đối soát nữa. Phương án được chọn thêm **không bản nào**: nó đọc chính `BoMacDinh()`.

Cái giá thứ hai đo được: một migration chạy đúng một lần trên một database. Hỏng giữa chừng ở
công ty thứ năm trong năm mươi thì phải chữa bằng tay rồi mới đi tiếp được, còn một lệnh
idempotent thì chạy lại. Và một migration không nhận được `--company`, nên không có cách nào nạp
lại cho đúng một phân vùng.

**Một job lúc `cmd/api` khởi động** — loại. Nó biến việc **ghi vào dữ liệu tenant** thành hiệu
ứng phụ của một lần khởi động lại: không actor người thật, không ai đọc output, không mã thoát
nào có người nhìn. Nhánh lỗi của nó cũng không có lời giải: chặn khởi động vì một lần nạp hụt thì
đi ngược ADR-0023 mục 8 — mục ấy đã chốt *"không chặn khởi động `cmd/api` vì một lần đọc phân
quyền hỏng"* — còn nuốt lỗi thì đúng là con bug im lặng mà ADR này sinh ra để diệt, chỉ dời xuống
một tầng. Kèm theo, mọi lần khởi động lại đều trả tiền cho một vòng quét qua mọi công ty nhân mọi
vai trò mặc định, để trong đại đa số lần không ghi gì.

**Không tự động: để quản trị của từng công ty tự tạo vai trò cho module mới** — loại, dù nó là
phương án **nghe** nhất quán nhất với ADR-0024.

Nó bí, và bí một cách kiểm chứng được. ADR-0024 mục 3 đòi actor có `<module>.role_assign` của mọi
module xuất hiện trong tập quyền của vai trò sắp tạo. Ngày `purchasing` lên, không hàng
`role_permissions` nào trong công ty cũ chứa `purchasing.role_assign`, nên không ai trong công ty
đó — kể cả `auth.admin` — tạo được vai trò `purchasing` đầu tiên. Người duy nhất làm được là
`quan_tri_he_thong`, tức nhà cung cấp, bằng tay, cho từng khách hàng, gõ lại từng mã quyền của
một module họ vừa gặp lần đầu. Đó không phải "để tenant tự quyết", đó là một hàng đợi thủ công
đúng loại mà ADR-0023 mục Alternatives đã loại một lần rồi.

**Nạp bù ở mức QUYỀN: hợp tập mặc định vào vai trò cùng mã** — loại. Nó tick lại một ô mà quản
trị đã cố ý gỡ, vào lúc triển khai, không do ai yêu cầu và không actor người thật nào đứng sau.
ADR-0024 đặt tập quyền ấy dưới thẩm quyền của họ, nên đây không phải một lựa chọn kỹ thuật mà là
một lần lấy lại quyền đã trao. Nó cũng **không quan sát được từ phía người dùng**: hợp tập chỉ
thêm, không bớt, nên màn hình không đỏ chỗ nào, không thông báo nào bật lên, và cách duy nhất họ
biết là mở lại màn phân quyền rồi nhớ ra mình từng gỡ ô đó.

**Nạp bù ở mức quyền nhưng CHỈ cho vai trò tenant chưa từng sửa** — loại, dù nó là phương án
trung dung thật sự và nó tránh được lời phê ngay trên.

Nó đòi biết "vai trò này được nạp bằng bộ mặc định **nào**" để so, tức đòi đúng cái bảng phiên
bản mà mục 8 bác, cộng thêm một dấu vân tay tập quyền lưu theo từng hàng `roles`. Không có bảng
ấy thì chỉ so được với bộ mặc định **hôm nay**, và phép so đó sai ngay sau lần thứ hai bộ mặc
định đổi: một vai trò tenant chưa từng chạm sẽ bị đọc thành "đã sửa" chỉ vì bản chuẩn đã đi tiếp,
còn một vai trò tenant đã sửa đúng bằng nội dung bản chuẩn mới thì bị đọc thành "còn nguyên". Chi
phí là hai cấu trúc dữ liệu mới, để mua một hành vi đúng trong ca hẹp và sai âm thầm trong ca
rộng.

## Consequences

**Được:**

- Con bug "khách hàng cũ nhận 403, khách hàng mới dùng được" đóng ở dạng cấu trúc chứ không ở
  dạng quy trình: nạp bù và `CreateCompany` đọc cùng `vaitro.BoMacDinh()`, nên chúng không có chỗ
  để lệch nhau.
- Kỷ luật "đổi tên một hằng permission phải kèm migration dữ liệu" của ADR-0023 mục 7 có lần đầu
  tiên một thứ cưỡng chế nó, và thứ đó nhìn thấy dữ liệu tenant — chỗ mà CI theo định nghĩa không
  tới được.
- Luật phát biểu được bằng một câu người vận hành nhớ nổi: *hệ tạo vai trò còn thiếu, hệ không
  sửa vai trò đã có.*
- Mở module thứ tư tới thứ mười hai không thêm một bản chép tay nào của bảng phân quyền, và không
  thêm một bài test đối soát nào.

**Mất:**

- **Một permission mới thuộc về một vai trò ĐÃ CÓ thì không bao giờ tự tới.** Ngày module
  `inventory` mọc thêm một hằng và bộ mặc định tick nó vào `inventory.admin`, mọi công ty đã tồn
  tại vẫn có một `inventory.admin` thiếu ô đó cho tới khi quản trị của họ tự tick. Nghĩa là
  `inventory.admin` của khách hàng cũ và của khách hàng mới sẽ khác nhau — đúng loại bất đối xứng
  ADR này mở ra để diệt, chỉ hẹp hơn. Nó được chấp nhận vì ca này tenant **sửa được**, còn ca vai
  trò không tồn tại thì không; nhưng nó có thật và nó sẽ quay về dưới dạng một câu hỏi hỗ trợ.
- **Danh sách vai trò của một công ty dài ra theo số module, không theo nhu cầu của họ.** Bảy
  hàng hôm nay, khoảng ba mươi khi đủ mười hai module, phần lớn là vai trò của module công ty đó
  không dùng. Họ xoá mềm được từng cái (ADR-0023 mục 5), và mục 3 bảo đảm lệnh không hồi sinh
  chúng — nhưng đó là việc phải làm bằng tay, một lần cho mỗi vai trò, ở mỗi công ty.
- **Phép đối soát ở mục 7 đỏ SAU khi migration đã chạy.** Nó không ngăn được một đợt triển khai
  làm chết một mã quyền; nó chỉ bảo đảm chuyện đó bị nhìn thấy trong ngày. Ai đọc mục 7 rồi tưởng
  có một cổng chặn sẽ hụt.
- **Một bước nữa trong quy trình triển khai**, và là bước ghi vào dữ liệu tenant. Nó chạy dưới
  system actor nên trong `audit_logs` không có tên người nào để hỏi khi cần truy lại vì sao một
  hàng `roles` xuất hiện.

**Nợ để lại:**

- **Điều kiện để mục 6 đứng vững: máy chạy bước triển khai phải chạy được `cmd/dev`.** Hôm nay
  `deploy-dev.sh` bước 4 đã gọi `go run ./cmd/dev migrate-up` nên điều kiện ấy đang đúng. Ngày
  nào bước migrate đổi sang một đường khác — một image riêng, một binary dựng sẵn — thì
  `seed-roles` phải đi theo cùng đường trong cùng đợt, không thì nó rơi lại lặng lẽ và mọi thứ
  ADR này bảo đảm mất theo.
- **Chưa có màn hình nào cho quản trị công ty thấy "module mới có những vai trò này".** Sau khi
  nạp bù, bảy vai trò thành mười, và người quản trị biết điều đó bằng cách tự mở danh sách. Ghi
  chú phát hành là chỗ bù tạm; đường sạch hơn là một chỉ dấu trên màn quản trị vai trò của đợt 2.
- **Ca "công ty mở ra GIỮA hai lần triển khai" chưa được đối soát bằng máy.** `CreateCompany` và
  `seed-roles` cùng đọc `BoMacDinh()` nên chúng đúng theo lập luận, nhưng không bài test nào hôm
  nay chạy cả hai đường trên cùng một database rồi so kết quả. Đó là bài test đáng viết đầu tiên
  của đợt thi công.
- **Chiều BỚT vẫn hở đúng như mục 9 mô tả.** Máy dò báo được mã chết; nó không tự dọn, và nó
  không phân biệt được mã ấy chết vì một lần đổi tên hay vì một lần xoá có chủ đích. Người đọc kết
  quả vẫn phải quyết.

**Constrains:** —
